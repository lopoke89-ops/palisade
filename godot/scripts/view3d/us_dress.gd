class_name UsDress
extends RefCounted
## THE UNDERSTRIP's set dressing (the Living World work order's Stage 3), all three regions: the Flood Tunnels' pipes
## and casino junk, Shelter 7's ducts, bunks and stores, Area 67's cable trunks, monitors and breached glass.
## Visual only. The sim never reads any of it and nothing here is solid: collision, sight, bullets, paths and the
## network state are untouched. Three parts, kept apart:
##   plan()      recipes -> placement records, from the level's rooms (sim.lay.us.rooms), its tiles and a hash of its
##               own (h): never the game's random numbers, so one seed is dressed the same on every machine
##   wall_geo()  a wall tile's pieces, into that wall's paint (UsView3D.tags): they come and go with the paint, so a
##               wall that lowers in front of a soldier takes its pipes and signs with it
##   junk_geo(), floor_geo()   the props that stand on the level's own cover tiles (same footprint, same height as
##               the box they replace) and the flat wear on the floor, built once
##   frame()     the drips' rings, only those on screen; none under Reduce Motion
## Where things may go: wall pieces hang on the two faces the camera sees and stay within 0.12 of the wall. Standing
## props only on T_JUNK tiles, which are solid already. Everything else is flat on the floor and keeps off start
## spots, the lift's ring, shrines, traders, chests, ambush tiles, doors, the boss gate and hazard floors.
## Quality3D.life: 0 off (the tunnels as they were), 1 wall systems and props, 2 + floor wear and drips,
## 3 + brackets, labels and the small stuff.

const H := 1.25   # a tunnel wall's height
const NS := 0x44524553   # the dressing's own hash namespace

const PIPES := ["#6b4a36", "#4b5642", "#5b6063"]   # rust, service green, bare steel
const DARK := "#24272a"
const STEEL := "#5b6063"
const WOOD := "#6a5236"
const SILT := "#3d3a30"
const WET := "#20272a"
const CREAM := "#c9c2a4"
## each region's kit: the run high on the walls (0 a pipe, 1 a duct, 2 a cable trunk) and its colours, the board and
## ink of its signs, the words by room, what stands on the cover tiles, and how much silt gathers
const REGION := {
	1: {"run": 0, "cols": ["#6b4a36", "#4b5642", "#5b6063"], "board": "#2b2f2a", "ink": "#c9c2a4", "pre": "T-", "silt": "#3d3a30", "siltp": 0.42,
		"exit": "LIFT", "shortcut": "SERVICE", "ante": "COUNT", "slots": "SLOTS", "pump": "PUMP 2", "water": "DRAIN", "junk": {"pump": "pump", "slots": "slot", "": "crate"}},
	2: {"run": 1, "cols": ["#565c4c", "#5f6468", "#4f5546"], "board": "#8a4f1e", "ink": "#e6dcc0", "pre": "B-", "silt": "#3a392f", "siltp": 0.2,
		"exit": "LIFT", "shortcut": "STORES", "ante": "MAIN HALL", "slots": "BUNKS", "pump": "GEN 2", "water": "WATER", "junk": {"pump": "gen", "slots": "cot", "": "ration"}},
	3: {"run": 2, "cols": ["#737b82", "#6a727a", "#7d858c"], "board": "#c4ccd2", "ink": "#1c2227", "pre": "L-", "silt": "#3a3f44", "siltp": 0.0,
		"exit": "LIFT", "shortcut": "ACCESS", "ante": "BAY 2", "slots": "SPECIMEN", "pump": "LAB 4", "water": "COOLANT", "junk": {"pump": "cargo", "slots": "cargo", "": "cargo"}},
}
const JUNCTION_NO := ["12", "14", "17", "20", "21", "24", "27", "40", "41", "42", "47", "70", "71", "72", "74"]

var s: Sim
var N := 0
var reg := 1
var level := 0
var life := 0
var run_seed := 0
var wall := {}   # wall tile -> [piece, ...] (see _add)
var mute := {}   # wall tile -> true: its graffiti gives way to a piece
var solid := {}   # cover tile -> [kind, variant 0..1]
var flat: Array = []   # floor pieces: [kind, ...]
var drips: Array = []   # [x, z, height it falls from, phase 0..1]
var rings := {}   # drip -> its six ring shapes
var keep := {}   # floor tiles the wear stays off
var taken := {}   # wall tile * 2 + face -> true: its middle band holds a piece
var count := {}   # what the plan made, by kind
var K: Dictionary = {}   # the region's kit
var skipped: Array = []   # what a recipe wanted and couldn't place: [what, room id, why]


func _init(sim: Sim) -> void:
	s = sim
	N = s.N
	level = clampi(int(s.game.us.level), 0, 9)
	reg = PalUnderstrip.PLAN[level][0]
	life = Quality3D.life
	run_seed = int(s.lay.us.get("seed", 0))
	K = REGION[reg]
	if life > 0:
		plan()


## 0..1 from the level's seed, a tile and a salt: order never matters, and the game's own draws are never touched
func h(k: int, salt: int) -> float:
	return float(PalUnderstripGen.mix([run_seed, NS, k, salt])) / 4294967296.0


func _t(x: int, y: int) -> int:
	return s.terr[y * N + x] if x >= 0 and y >= 0 and x < N and y < N else PalMaps.T_CONC


func _open(x: int, y: int) -> bool:
	return _t(x, y) in [PalMaps.T_GROUND, PalMaps.T_LOW, PalMaps.T_BRIDGE, PalMaps.T_WATER]


## does this wall tile's south (0) or east (1) face look onto floor?
func _face(x: int, y: int, f: int) -> bool:
	if _t(x, y) != PalMaps.T_CONC or x < 0 or y < 0 or x >= N or y >= N:
		return false
	return _open(x, y + 1) if f == 0 else _open(x + 1, y)


## a face's frame: origin, the direction that runs left to right on screen, the normal
static func frame_of(x: int, y: int, f: int) -> Array:
	if f == 0:
		return [Vector3(x, 0, y + 1), Vector3(1, 0, 0), Vector3(0, 0, 1)]
	return [Vector3(x + 1, 0, y + 1), Vector3(0, 0, -1), Vector3(1, 0, 0)]


static func _pt(F: Array, u: float, y: float, d: float) -> Vector3:
	return F[0] + F[1] * u + Vector3(0, y, 0) + F[2] * d


# ---------------------------------------------------------------- the plan

func plan() -> void:
	var L: Dictionary = s.lay.us
	for c in "PESMCABKG":
		for p in L.marks.get(c, []):
			keep[int(p[1]) * N + int(p[0])] = true
	var clear: Array = [[s.lay.exit[0], s.lay.exit[1], 1.8]]
	for p in s.lay.shrines:
		clear.append([p.x, p.y, 1.0])
	for p in s.lay.merchants:
		clear.append([p.x, p.y, 1.0])
	for p in s.lay.chests:
		clear.append([p.x, p.y, 0.8])
	for c in clear:
		for y in range(floori(c[1] - c[2]), ceili(c[1] + c[2]) + 1):
			for x in range(floori(c[0] - c[2]), ceili(c[0] + c[2]) + 1):
				if x >= 0 and y >= 0 and x < N and y < N and Vector2(x + 0.5 - c[0], y + 0.5 - c[1]).length() < c[2] + 0.5:
					keep[y * N + x] = true
	for n in L.rooms.size():
		_room(L.rooms[n])


func _add(k: int, P: Dictionary) -> void:
	if not wall.has(k):
		wall[k] = []
	wall[k].append(P)
	count[P.t] = int(count.get(P.t, 0)) + 1


## the free face nearest a point, among a room's faces ([k, f]); it takes the face's middle band and its graffiti
func _take(faces: Array, px: float, py: float, far: float, only_f: int = -1) -> Array:
	var best: Array = []
	var bd := far
	for q in faces:
		var k: int = q[0]
		var f: int = q[1]
		if taken.has(k * 2 + f) or (only_f >= 0 and f != only_f):
			continue
		var x := k % N
		var y := k / N
		var d := Vector2((x + 0.5 if f == 0 else x + 1.0) - px, (y + 1.0 if f == 0 else y + 0.5) - py).length()
		if d < bd:
			bd = d
			best = q
	if not best.is_empty():
		taken[int(best[0]) * 2 + int(best[1])] = true
		mute[best[0]] = true
	return best


## the face next along the same wall (left or right of one just taken), if it is free
func _beside(faces: Array, q: Array) -> Array:
	var k: int = q[0]
	var f: int = q[1]
	for step in ([1, -1] if f == 0 else [-N, N]):
		for o in faces:
			if o[0] == k + step and o[1] == f and not taken.has(int(o[0]) * 2 + f):
				taken[int(o[0]) * 2 + f] = true
				mute[o[0]] = true
				return o
	return []


func _in(p, R: Dictionary) -> bool:
	return p[0] >= R.x and p[0] < R.x + R.w and p[1] >= R.y and p[1] < R.y + R.h


func _room(R: Dictionary) -> void:
	var role: String = R.role
	var id: String = R.id
	var x0: int = R.x
	var y0: int = R.y
	var ww: int = R.w
	var hh: int = R.h
	var L: Dictionary = s.lay.us
	var arena := role == "boss_arena"
	# the wall faces the camera sees, as runs in left-to-right order
	var runs: Array = []
	for y in range(y0, y0 + hh):
		var run: Array = []
		for x in range(x0, x0 + ww + 1):
			if x < x0 + ww and _face(x, y, 0):
				run.append(y * N + x)
			elif not run.is_empty():
				runs.append([0, run])
				run = []
	for x in range(x0, x0 + ww):
		var run: Array = []
		for y in range(y0 + hh - 1, y0 - 2, -1):
			if y >= y0 and _face(x, y, 1):
				run.append(y * N + x)
			elif not run.is_empty():
				runs.append([1, run])
				run = []
	var faces: Array = []
	for r in runs:
		for k in r[1]:
			faces.append([k, r[0]])
	# building systems: a pipe run high on a wall, into the wall at both ends, a valve on some
	var want := 0.35 if arena else (0.85 if role in ["corridor", "junction", "shortcut"] else 0.7)
	for r in runs:
		var f: int = r[0]
		var ks: Array = r[1]
		if ks.size() < 2 or h(ks[0], 1 + f) >= want:
			continue
		var col: String = K.cols[mini(2, floori(h(ks[0], 3) * 3))]
		var two := h(ks[0], 4) < 0.45
		var vi := -1
		if ks.size() >= 3 and not arena and reg == 1 and h(ks[0], 5) < 0.55:
			vi = 1 + mini(ks.size() - 3, floori(h(ks[0], 6) * (ks.size() - 2)))
		for i in ks.size():
			_add(ks[i], {"t": "pipe", "f": f, "a": i == 0, "b": i == ks.size() - 1, "col": col, "two": two, "valve": i == vi, "k": K.run, "grow": reg == 3 and level >= 7 and h(ks[i], 16) < 0.5})
		if vi >= 0:
			var k: int = ks[vi]
			var p := _pt(frame_of(k % N, k / N, f), 0.5, 0, 0.17)
			flat.append(["stain", p.x, p.z, 0.2, 0.14])
			drips.append([p.x, p.z, 0.9, h(k, 7)])
	if arena:   # the perimeter's pipes and nothing else: the floor is the fight's
		return
	# a lamp's cable: across the floor to the nearest wall, up into a junction box
	for p in L.marks.get("L", []):
		if not _in(p, R):
			continue
		var q := _take(faces, p[0] + 0.5, p[1] + 0.5, 3.6)
		if q.is_empty():
			skipped.append(["lamp cable", id, "no free wall face in reach"])
			continue
		var k: int = q[0]
		var base := _pt(frame_of(k % N, k / N, q[1]), 0.5, 0, 0.03)
		var lamp := Vector2(p[0] + 0.5, p[1] + 0.5)
		var corner := Vector2(base.x, lamp.y) if q[1] == 0 else Vector2(lamp.x, base.z)
		if not _open(floori(corner.x), floori(corner.y)):
			corner = lamp
		flat.append(["cable", [lamp, corner, Vector2(base.x, base.z)]])
		_add(k, {"t": "box", "f": q[1]})
	# what the room is for
	var words: Array = []   # [word, near x, near y, board colour, letter colour, hazard stripe]
	match role:
		"merchant":
			for p in L.marks.get("M", []):
				if not _in(p, R):
					continue
				var q := _take(faces, p[0] + 0.5, p[1] + 0.5, 3.0)
				if q.is_empty():
					skipped.append(["trader's shelves", id, "no free wall face in reach"])
					continue
				_add(q[0], {"t": "shelf", "f": q[1], "v": h(q[0], 8)})
				var o := _beside(faces, q)
				if not o.is_empty():
					_add(o[0], {"t": "sign", "f": o[1], "word": "STAFF", "board": K.board, "ink": K.ink, "stripe": false})
		"breather":
			for p in L.marks.get("S", []):
				if not _in(p, R):
					continue
				var q := _take(faces, p[0] + 0.5, p[1] + 0.5, 4.5)
				if q.is_empty():
					skipped.append(["break corner", id, "no free wall face in reach"])
					continue
				_add(q[0], {"t": "board", "f": q[1], "v": h(q[0], 8)})
				var F := frame_of(int(q[0]) % N, int(q[0]) / N, q[1])
				var a := _pt(F, 0.12, 0, 0.1)
				var b := _pt(F, 0.88, 0, 0.5)
				if not keep.has(floori(b.z) * N + floori(b.x)) and _open(floori(b.x), floori(b.z)):
					flat.append(["mat", minf(a.x, b.x), minf(a.z, b.z), maxf(a.x, b.x), maxf(a.z, b.z)])
		"exit":
			words.append([K.exit, s.lay.exit[0], s.lay.exit[1], K.board, "#c8a03a" if reg == 1 else K.ink, true])
		"shortcut":
			var KD: Array = L.marks.get("K", []).filter(func(p): return _in(p, R))
			if not KD.is_empty():
				words.append([K.shortcut, KD[0][0] + 0.5, KD[0][1] + 0.5, K.board, K.ink, true])
		"boss_ante":
			var S: Array = L.marks.get("S", []).filter(func(p): return _in(p, R))
			var at := Vector2(S[0][0] + 0.5, S[0][1] + 0.5) if not S.is_empty() else Vector2(x0 + ww * 0.5, y0 + hh * 0.5)
			var q := _take(faces, at.x, at.y, 5.0)
			if q.is_empty():
				skipped.append(["count room shutter", id, "no free wall face in reach"])
			else:
				_add(q[0], {"t": "status" if level == 5 else "shutter", "f": q[1], "v": h(q[0], 8)})
				var o := _beside(faces, q)
				if not o.is_empty():
					_add(o[0], {"t": "shutter", "f": o[1]})
				words.append([K.ante, at.x, at.y, "#3a1830" if reg == 1 else K.board, "#d6a84a" if reg == 1 else K.ink, false])
		"junction":
			if reg == 2 and life >= 3:   # a wall phone at every crossing
				var q := _take(faces, x0 + ww * 0.5, y0 + hh * 0.5, 6.0)
				if not q.is_empty():
					_add(q[0], {"t": "phone", "f": q[1]})
			words.append([str(K.pre) + JUNCTION_NO[mini(JUNCTION_NO.size() - 1, floori(h(y0 * N + x0, 9) * JUNCTION_NO.size()))], x0 + ww * 0.5, y0 + hh * 0.5, K.board, K.ink, false])
		"corridor":
			if reg == 3 and h(y0 * N + x0, 17) < 0.6:   # a monitor, still on or long dead
				var q := _take(faces, x0 + ww * 0.5, y0 + hh * 0.5, 6.0)
				if not q.is_empty():
					_add(q[0], {"t": "monitor", "f": q[1], "v": h(q[0], 8)})
		"entrance":
			var mark: Array = {3: ["shutter", "CHECK IN"], 4: ["filter", "FILTER"], 6: ["decon", "DECON"], 7: ["breach", "CELL 4"]}.get(level, [])
			if not mark.is_empty():   # the level's landmark, where the lift lets the squad out
				var q := _take(faces, x0 + ww * 0.5, y0 + 1.0, 6.0, 0)
				if q.is_empty():
					q = _take(faces, x0 + ww * 0.5, y0 + hh * 0.5, 6.0)
				if q.is_empty():
					skipped.append([mark[0], id, "no free wall face"])
				else:
					_add(q[0], {"t": mark[0], "f": q[1], "v": h(q[0], 8)})
					var F := frame_of(int(q[0]) % N, int(q[0]) / N, q[1])
					var o := _beside(faces, q)
					if not o.is_empty():
						_add(o[0], {"t": "sign", "f": o[1], "word": mark[1], "board": K.board, "ink": K.ink, "stripe": false})
					if mark[0] == "decon":
						var a := _pt(F, 0.1, 0, 0.08)
						var b := _pt(F, 0.9, 0, 0.7)
						flat.append(["pad", minf(a.x, b.x), minf(a.z, b.z), maxf(a.x, b.x), maxf(a.z, b.z)])
			if level == 0:   # the level's landmark: the storm outfall the squad came down beside
				var q := _take(faces, x0 + ww * 0.5, y0 + 1.0, 6.0, 0)
				if q.is_empty():
					q = _take(faces, x0 + ww * 0.5, y0 + hh * 0.5, 6.0)
				if q.is_empty():
					skipped.append(["outfall", id, "no free wall face"])
				else:
					_add(q[0], {"t": "outfall", "f": q[1]})
					var p := _pt(frame_of(int(q[0]) % N, int(q[0]) / N, q[1]), 0.5, 0, 0.3)
					flat.append(["stain", p.x, p.z, 0.46, 0.3])
		"room":
			if id.contains("slots"):
				words.append([K.slots, x0 + ww * 0.5, y0 + hh * 0.5, "#3a1830" if reg == 1 else K.board, "#d86aa8" if reg == 1 else K.ink, false])
			elif id.contains("pump"):
				words.append([K.pump, x0 + ww * 0.5, y0 + hh * 0.5, K.board, K.ink, reg == 1])
			elif id.contains("overflow") or id.contains("cistern"):
				words.append([K.water, x0 + ww * 0.5, y0 + hh * 0.3, K.board, K.ink, reg == 1])
			if reg == 3 and h(y0 * N + x0, 17) < 0.7:
				var q := _take(faces, x0 + ww * 0.5, y0 + hh * 0.5, 6.0)
				if not q.is_empty():
					_add(q[0], {"t": "monitor", "f": q[1], "v": h(q[0], 8)})
	for w in words:
		var q := _take(faces, w[1], w[2], 6.0)
		if q.is_empty():
			skipped.append(["sign " + str(w[0]), id, "no free wall face in reach"])
			continue
		_add(q[0], {"t": "sign", "f": q[1], "word": w[0], "board": w[3], "ink": w[4], "stripe": w[5]})
	# the cover tiles: what was dumped or bolted down here
	var kind: String = K.junk["pump" if id.contains("pump") else ("slots" if id.contains("slots") else "")]
	for y in range(y0, y0 + hh):
		for x in range(x0, x0 + ww):
			if _t(x, y) == PalMaps.T_JUNK:
				solid[y * N + x] = [kind, h(y * N + x, 10)]
				count[kind] = int(count.get(kind, 0)) + 1
	if life < 2:
		return
	# wear on the floor: silt along the wall foot, a drain across a passage
	var has_haz: bool = s.lay.has("haz")
	var passage := role in ["corridor", "junction", "shortcut", "cache"]
	for y in range(y0, y0 + hh):
		for x in range(x0, x0 + ww):
			var k := y * N + x
			var t := _t(x, y)
			if not (t == PalMaps.T_GROUND or t == PalMaps.T_LOW) or keep.has(k) or (has_haz and int(s.lay.haz[k]) != 0):
				continue
			var lowp: float = (0.7 if t == PalMaps.T_LOW else 0.42) * float(K.siltp) / 0.42
			if _t(x, y - 1) == PalMaps.T_CONC and h(k, 11) < lowp:
				flat.append(["silt", x, y, 0, 0.05 + 0.11 * h(y * N + x, 12), 0.05 + 0.11 * h(y * N + x + 1, 12)])
			if _t(x - 1, y) == PalMaps.T_CONC and h(k, 13) < lowp:
				flat.append(["silt", x, y, 1, 0.05 + 0.11 * h(y * N + x, 14), 0.05 + 0.11 * h((y + 1) * N + x, 14)])
			var gh := Pal.hash2(x, y)   # the floor's own marks (a crack, a puddle, spilt paint) keep their tiles
			if passage and t == PalMaps.T_GROUND and h(k, 15) < 0.2 and not (gh > 0.9 or gh < 0.06 or (gh > 0.8 and gh < 0.83)):
				var ns := _open(x, y - 1) and _open(x, y + 1)
				var ew := _open(x - 1, y) and _open(x + 1, y)
				if ns != ew:
					flat.append(["grate", x, y, ns])


# ---------------------------------------------------------------- geometry

func _fq(g: V3Mesh, F: Array, u0: float, u1: float, y0: float, y1: float, d: float, col: Color) -> void:
	g.quad(_pt(F, u0, y0, d), _pt(F, u1, y0, d), _pt(F, u1, y1, d), _pt(F, u0, y1, d), col)


func _fbox(g: V3Mesh, F: Array, u0: float, u1: float, y0: float, y1: float, d0: float, d1: float, col: Color) -> void:
	var a := _pt(F, u0, y0, d0)
	var b := _pt(F, u1, y1, d1)
	g.box(minf(a.x, b.x), minf(a.z, b.z), maxf(a.x, b.x), maxf(a.z, b.z), y0, y1, col.lightened(0.1), col, col.darkened(0.15))


## a flat many-sided plate standing on a face (a valve's wheel, a pipe's mouth): radius r0 to r1 round (u, y)
func _fring(g: V3Mesh, F: Array, u: float, y: float, d: float, r0: float, r1: float, col: Color, n: int) -> void:
	var c := _pt(F, u, y, d)
	var ax: Vector3 = F[1]
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := ax * cos(a0) + Vector3.UP * sin(a0)
		var p1 := ax * cos(a1) + Vector3.UP * sin(a1)
		if r0 <= 0.0:
			g.tri(c, c + p0 * r1, c + p1 * r1, col, F[2])
		else:
			g.quad(c + p0 * r0, c + p0 * r1, c + p1 * r1, c + p1 * r0, col)
			for q in 6:   # quad() works its own normal out; a face piece's is the face's
				g.norms[g.norms.size() - 1 - q] = F[2]


func _word(g: V3Mesh, F: Array, word: String, uc: float, y0: float, cell: float, d: float, col: Color) -> void:
	var u := uc - (4 * word.length() - 1) * cell * 0.5
	for ch in word:
		var G: Array = CityDress.GLYPH.get(ch, CityDress.GLYPH[" "])
		for r in 5:
			var bits: int = G[r]
			for q in 3:
				if bits & (4 >> q):
					_fq(g, F, u + q * cell, u + (q + 1) * cell, y0 + (4 - r) * cell, y0 + (5 - r) * cell, d, col)
		u += 4 * cell


## a wall tile's pieces, into its paint
func wall_geo(g: V3Mesh, x: int, y: int, k: int) -> void:
	if not wall.has(k):
		return
	for P in wall[k]:
		var F := frame_of(x, y, P.f)
		match P.t:
			"pipe":
				var col := Color(P.col)
				var u0 := 0.14 if P.a else 0.0
				var u1 := 0.86 if P.b else 1.0
				if P.k == 1:   # Shelter 7: a sheet-metal duct, a seam every tile, a grille where it ends
					_fbox(g, F, u0, u1, 0.93, 1.11, 0.0, 0.11, col)
					_fq(g, F, u0 + 0.01, u0 + 0.03, 0.93, 1.11, 0.112, col.darkened(0.25))
					for e in ([u0] if P.a else []) + ([u1] if P.b else []):
						var e2: float = e + (0.1 if e < 0.5 else -0.1)
						for i in 4:
							_fq(g, F, minf(e, e2) + 0.01, maxf(e, e2) - 0.01, 0.95 + i * 0.04, 0.97 + i * 0.04, 0.113, Color(DARK))
					if P.two:
						g.bar(_pt(F, 0.0, 0.87, 0.02), _pt(F, 1.0, 0.87, 0.02), 0.011, Color("#a8642a"))
					continue
				if P.k == 2:   # Area 67: a cable trunk, three runs on a tray; growth follows the warm ones deeper down
					_fbox(g, F, u0, u1, 0.97, 0.99, 0.0, 0.1, col)
					for i in 3:
						g.bar(_pt(F, u0, 1.005, 0.025 + i * 0.03), _pt(F, u1, 1.005, 0.025 + i * 0.03), 0.011, Color(["#1c2227", "#2a3b4a", "#3a2f2a"][i]))
					for e in ([u0] if P.a else []) + ([u1] if P.b else []):
						_fbox(g, F, e - 0.04, e + 0.04, 0.9, 1.06, 0.0, 0.11, col.darkened(0.2))
					if life >= 3:
						g.bar(_pt(F, 0.5, 0.86, 0.0), _pt(F, 0.5, 0.97, 0.09), 0.01, Color(DARK))
					if P.grow:
						g.bar(_pt(F, 0.2, 1.02, 0.07), _pt(F, 0.55, 1.05, 0.09), 0.016, Color("#4f8a46"))
						g.bar(_pt(F, 0.55, 1.05, 0.09), _pt(F, 0.8, 0.9, 0.02), 0.012, Color("#5aa050"))
						g.bar(_pt(F, 0.36, 1.03, 0.08), _pt(F, 0.3, 0.8, 0.01), 0.01, Color("#3a2a44"))
					continue
				for line in ([[1.0, 0.07, 0.035, col], [1.13, 0.045, 0.017, Color(STEEL)]] if P.two else [[1.0, 0.07, 0.035, col]]):
					var py: float = line[0]
					var pd: float = line[1]
					var pr: float = line[2]
					g.bar(_pt(F, u0, py, pd), _pt(F, u1, py, pd), pr, line[3])
					for e in ([u0] if P.a else []) + ([u1] if P.b else []):   # an elbow into the wall, on a flange
						g.bar(_pt(F, e, py, pd + pr), _pt(F, e, py, 0), pr, line[3])
						_fq(g, F, e - pr * 1.7, e + pr * 1.7, py - pr * 1.7, py + pr * 1.7, 0.004, Color(line[3]).darkened(0.35))
				if P.valve:
					g.bar(_pt(F, 0.5, 1.0, 0.07), _pt(F, 0.5, 1.0, 0.15), 0.012, Color(DARK))
					_fring(g, F, 0.5, 1.0, 0.15, 0.05, 0.078, Color("#8a3a2c"), 8)
					_fq(g, F, 0.49, 0.51, 0.93, 1.07, 0.151, Color("#8a3a2c"))
					_fq(g, F, 0.43, 0.57, 0.99, 1.01, 0.151, Color("#8a3a2c"))
					_fq(g, F, 0.46, 0.54, 0.0, 0.93, 0.003, Color(WET))   # where it has wept down the wall
				elif life >= 3:   # a bracket
					_fq(g, F, 0.47, 0.53, 0.9, 1.1, 0.005, Color(DARK))
					g.bar(_pt(F, 0.5, 0.96, 0), _pt(F, 0.5, 0.96, 0.07), 0.012, Color(DARK))
			"box":
				var c := Color("#4d5348")
				_fbox(g, F, 0.38, 0.62, 0.42, 0.72, 0.0, 0.06, c)
				_fq(g, F, 0.4, 0.6, 0.44, 0.7, 0.062, c.lightened(0.07))
				_fq(g, F, 0.575, 0.59, 0.54, 0.6, 0.064, Color(DARK))
				g.bar(_pt(F, 0.5, 0.72, 0.03), _pt(F, 0.5, H, 0.03), 0.014, Color(STEEL))
				g.bar(_pt(F, 0.5, 0.42, 0.03), _pt(F, 0.5, 0, 0.03), 0.014, Color(DARK))
				if life >= 3:
					_fq(g, F, 0.43, 0.53, 0.61, 0.67, 0.064, Color("#b89a3a"))
			"sign":
				var word: String = P.word
				var n := word.length()
				var cell := minf(0.8 / (4 * n - 1), 0.05)
				var w := (4 * n - 1) * cell
				var yc := 0.76
				var hb := 5 * cell
				_fq(g, F, 0.5 - w * 0.5 - 0.05, 0.5 + w * 0.5 + 0.05, yc - hb * 0.5 - 0.04, yc + hb * 0.5 + 0.04, 0.006, Color(P.board))
				_word(g, F, word, 0.5, yc - hb * 0.5, cell, 0.01, Color(P.ink))
				if P.stripe:   # a hazard band under the board
					var y1 := yc - hb * 0.5 - 0.05
					var ua := 0.5 - w * 0.5 - 0.05
					var ub := 0.5 + w * 0.5 + 0.05
					for i in 8:
						_fq(g, F, ua + (ub - ua) * i / 8.0, ua + (ub - ua) * (i + 1) / 8.0, y1 - 0.04, y1, 0.006, Color("#b89a3a") if i % 2 == 0 else Color("#1a1a16"))
				for e in [0.5 - w * 0.5 - 0.03, 0.5 + w * 0.5 + 0.03]:   # its fixings
					_fq(g, F, e - 0.008, e + 0.008, yc - 0.008, yc + 0.008, 0.011, Color(DARK))
			"shelf":
				var v: float = P.v
				_fq(g, F, 0.08, 0.92, 0.56, 0.8, 0.004, Color("#3b3a33"))   # a board of hooks behind
				for i in 5:
					_fq(g, F, 0.16 + i * 0.16, 0.18 + i * 0.16, 0.66, 0.74, 0.008, Color("#b08a3a") if (i + int(v * 5)) % 3 else Color(STEEL))
				for sy in [0.5, 0.83]:
					_fbox(g, F, 0.08, 0.92, sy, sy + 0.03, 0.0, 0.11, Color(WOOD))
					for e in [0.14, 0.86]:
						g.bar(_pt(F, e, sy - 0.1, 0.005), _pt(F, e, sy, 0.1), 0.01, Color(DARK))
				var cols := ["#8a8f96", "#7a4a30", "#4f6a8a", "#b08a3a", "#5a6a4a"]
				for i in 4:   # tins and boxes on the lower shelf, jars on the upper
					var u := 0.16 + i * 0.19 + 0.03 * fposmod(v * (i + 3), 1.0)
					var hgt := 0.07 + 0.05 * fposmod(v * 7.0 + i * 0.37, 1.0)
					_fbox(g, F, u, u + 0.11, 0.53, 0.53 + hgt, 0.015, 0.095, Color(cols[(i + int(v * 5)) % 5]))
				for i in 3:
					var p := _pt(F, 0.24 + i * 0.26, 0, 0.055)
					g.prism(p.x, p.z, 0.032, 0.86, 0.95, Color("#6a7a70"), Color("#3a3c38"), 6)
			"board":
				var v: float = P.v
				_fq(g, F, 0.1, 0.6, 0.48, 0.92, 0.006, Color("#5a4a32"))
				for e in [[0.1, 0.6, 0.48, 0.5], [0.1, 0.6, 0.9, 0.92], [0.1, 0.12, 0.48, 0.92], [0.58, 0.6, 0.48, 0.92]]:
					_fq(g, F, e[0], e[1], e[2], e[3], 0.009, Color("#3a3024"))
				var paper := ["#c9c2a4", "#b8b089", "#a88a8a", "#9aa7a0"]
				for i in 4:   # rotas and notices, pinned over years
					var u := 0.15 + (i % 2) * 0.22 + 0.03 * fposmod(v * (i + 2), 1.0)
					var py := 0.53 + (i / 2) * 0.19 + 0.02 * fposmod(v * (i + 5), 1.0)
					_fq(g, F, u, u + 0.15, py, py + 0.14, 0.011, Color(paper[(i + int(v * 4)) % 4]))
					if life >= 3:
						_fq(g, F, u + 0.065, u + 0.085, py + 0.115, py + 0.135, 0.013, Color("#8a3a2c"))
				_fbox(g, F, 0.66, 0.94, 0.5, 0.53, 0.0, 0.1, Color(STEEL))   # a shelf: a flask and a mug
				var p := _pt(F, 0.74, 0, 0.05)
				g.prism(p.x, p.z, 0.028, 0.53, 0.66, Color("#3f6a58"), Color("#c8c8c0"), 6)
				p = _pt(F, 0.86, 0, 0.05)
				g.prism(p.x, p.z, 0.022, 0.53, 0.58, Color("#b8b0a0"), Color("#3a2a20"), 6)
				g.bar(_pt(F, 0.8, 0.78, 0), _pt(F, 0.8, 0.78, 0.05), 0.01, Color(DARK))   # a hook, and the jacket left on it
				_fbox(g, F, 0.74, 0.86, 0.58, 0.78, 0.02, 0.05, Color("#5a5236"))
			"shutter":
				_fbox(g, F, 0.03, 0.97, 0.0, 0.06, 0.0, 0.05, Color(DARK))
				_fq(g, F, 0.03, 0.97, 0.06, 0.96, 0.004, Color("#34373a"))
				for i in 9:
					_fq(g, F, 0.07, 0.93, 0.1 + i * 0.092, 0.17 + i * 0.092, 0.009, Color("#5c605a") if i % 2 == 0 else Color("#51554f"))
				_fq(g, F, 0.44, 0.56, 0.11, 0.14, 0.013, Color(DARK))
			"filter":   # Shelter 7's air: a filter housing, its intake grille, the duct up through the ceiling
				var c := Color("#565c4c")
				_fbox(g, F, 0.12, 0.88, 0.2, 0.9, 0.0, 0.11, c)
				_fring(g, F, 0.5, 0.55, 0.112, 0.0, 0.2, Color("#101312"), 10)
				_fring(g, F, 0.5, 0.55, 0.114, 0.2, 0.24, Color(STEEL), 10)
				for e in [0.4, 0.5, 0.6]:
					_fq(g, F, e - 0.012, e + 0.012, 0.37, 0.73, 0.116, Color(STEEL).darkened(0.2))
				_fbox(g, F, 0.38, 0.62, 0.9, H, 0.0, 0.1, c.darkened(0.12))
				_fq(g, F, 0.16, 0.34, 0.78, 0.85, 0.112, Color("#a8642a"))
				_fq(g, F, 0.7, 0.84, 0.24, 0.3, 0.112, Color(CREAM))
			"status":   # the Main Hall's board: one lamp for each of the shelter's systems, most of them out
				_fq(g, F, 0.05, 0.95, 0.38, 1.0, 0.006, Color("#1d201d"))
				_fq(g, F, 0.05, 0.95, 0.92, 1.0, 0.009, Color("#8a4f1e"))
				for i in 12:
					var hv := fposmod(float(P.v) * (i + 3) * 1.37, 1.0)
					var lc := Color("#3d6a3a") if hv < 0.25 else (Color("#a8842a") if hv < 0.4 else (Color("#8a2f24") if hv < 0.6 else Color("#2a2d2a")))
					var u := 0.13 + (i % 4) * 0.2
					var py := 0.46 + (i / 4) * 0.15
					_fq(g, F, u, u + 0.07, py, py + 0.07, 0.01, lc)
					_fq(g, F, u + 0.09, u + 0.16, py + 0.02, py + 0.05, 0.01, Color("#55594f"))
			"decon":   # Area 67's way in: a spray bar over a wash-down pad
				for e in [0.12, 0.88]:
					g.bar(_pt(F, e, 0.0, 0.03), _pt(F, e, 1.1, 0.03), 0.018, Color("#7d858c"))
					g.bar(_pt(F, e, 1.1, 0.03), _pt(F, e, 1.1, 0.11), 0.018, Color("#7d858c"))
				g.bar(_pt(F, 0.12, 1.1, 0.11), _pt(F, 0.88, 1.1, 0.11), 0.018, Color("#7d858c"))
				for i in 4:
					g.bar(_pt(F, 0.24 + i * 0.173, 1.1, 0.11), _pt(F, 0.24 + i * 0.173, 1.03, 0.11), 0.012, Color(DARK))
				_fq(g, F, 0.2, 0.8, 0.25, 0.95, 0.004, Color("#aab4ba"))
				_fq(g, F, 0.2, 0.8, 0.25, 0.3, 0.006, Color("#55626a"))
			"breach":   # a cell's window, cracked from inside, and what came through it
				_fq(g, F, 0.07, 0.93, 0.28, 0.97, 0.004, Color("#7d858c"))
				_fq(g, F, 0.12, 0.88, 0.33, 0.92, 0.008, Color("#0a1216"))
				var c := _pt(F, 0.58, 0.66, 0.011)
				for q in [[0.2, 0.9], [0.86, 0.84], [0.8, 0.4], [0.36, 0.36], [0.5, 0.9], [0.14, 0.6]]:
					g.bar(c, _pt(F, q[0], q[1], 0.011), 0.005, Color("#9fb4bc"))
				g.bar(_pt(F, 0.58, 0.66, 0.012), _pt(F, 0.4, 0.4, 0.03), 0.02, Color("#4f8a46"))
				g.bar(_pt(F, 0.4, 0.4, 0.03), _pt(F, 0.3, 0.0, 0.06), 0.024, Color("#4f8a46"))
				g.bar(_pt(F, 0.4, 0.4, 0.03), _pt(F, 0.2, 0.3, 0.02), 0.014, Color("#3a2a44"))
				g.bar(_pt(F, 0.58, 0.66, 0.012), _pt(F, 0.76, 0.5, 0.03), 0.012, Color("#5aa050"))
			"phone":
				_fbox(g, F, 0.42, 0.58, 0.58, 0.84, 0.0, 0.05, Color("#3a3d38"))
				_fq(g, F, 0.44, 0.49, 0.6, 0.82, 0.052, Color("#151716"))
				_fq(g, F, 0.51, 0.56, 0.62, 0.72, 0.052, Color("#6a6e64"))
				g.bar(_pt(F, 0.465, 0.6, 0.05), _pt(F, 0.5, 0.42, 0.02), 0.006, Color("#151716"))
			"monitor":
				var on: bool = P.v < 0.55
				_fbox(g, F, 0.28, 0.72, 0.58, 0.92, 0.0, 0.06, Color("#2c3136"))
				_fq(g, F, 0.31, 0.69, 0.62, 0.89, 0.062, Color("#1c4a52") if on else Color("#0b0e10"))
				if on:
					for i in 3:
						_fq(g, F, 0.34, 0.5 + 0.05 * i, 0.66 + i * 0.07, 0.68 + i * 0.07, 0.064, Color("#4a8a92"))
				g.bar(_pt(F, 0.5, 0.92, 0.03), _pt(F, 0.5, 0.97, 0.03), 0.01, Color(DARK))
			"outfall":
				_fring(g, F, 0.5, 0.52, 0.004, 0.0, 0.33, Color("#0c0f10"), 14)
				_fring(g, F, 0.5, 0.52, 0.035, 0.31, 0.41, Color("#6b6f6a"), 14)
				_fring(g, F, 0.5, 0.52, 0.004, 0.41, 0.45, Color("#3d4140"), 14)
				for e in [0.34, 0.5, 0.66]:
					var half := sqrt(maxf(0.0, 0.33 * 0.33 - (e - 0.5) * (e - 0.5)))
					g.bar(_pt(F, e, 0.52 - half, 0.03), _pt(F, e, 0.52 + half, 0.03), 0.014, Color("#4a3a2e"))
				g.bar(_pt(F, 0.19, 0.52, 0.045), _pt(F, 0.81, 0.52, 0.045), 0.014, Color("#4a3a2e"))
				_fq(g, F, 0.36, 0.64, 0.0, 0.2, 0.006, Color(WET))


## the prop on a cover tile, in place of the plain box (false: none planned here). Same tile, no taller than 0.56.
func junk_geo(g: V3Mesh, x: int, y: int) -> bool:
	var k := y * N + x
	if not solid.has(k):
		return false
	var v: float = solid[k][1]
	match solid[k][0]:
		"pump":
			g.box(x + 0.1, y + 0.18, x + 0.9, y + 0.82, 0, 0.06, Color("#2c2f2e"), Color("#232625"), Color("#1d201f"))
			var c := Color("#4b5642")
			g.box(x + 0.15, y + 0.3, x + 0.52, y + 0.7, 0.06, 0.38, c.lightened(0.1), c, c.darkened(0.15))
			for i in 4:   # the motor's fins
				g.box(x + 0.19 + i * 0.08, y + 0.28, x + 0.22 + i * 0.08, y + 0.72, 0.1, 0.4, c.darkened(0.2), c.darkened(0.28), c.darkened(0.35))
			g.box(x + 0.52, y + 0.44, x + 0.58, y + 0.56, 0.16, 0.28, Color(STEEL), Color(STEEL), Color(STEEL).darkened(0.15))
			g.prism(x + 0.7, y + 0.5, 0.18, 0.06, 0.36, Color(STEEL), Color("#4a4f52"), 10)
			g.prism(x + 0.7, y + 0.5, 0.065, 0.36, 0.52, Color(PIPES[0]), Color("#1a1c1d"), 8)
			g.prism(x + 0.7, y + 0.5, 0.095, 0.5, 0.54, Color(PIPES[0]).darkened(0.2), Color("#1a1c1d"), 8)
			if life >= 3:
				g.box(x + 0.28, y + 0.7, x + 0.38, y + 0.715, 0.24, 0.32, Color(CREAM), Color(CREAM), Color(CREAM))
		"slot":
			var body := Color("#4a2f48") if v < 0.6 else Color("#2f3a4a")
			var trim := Color("#a8527e") if v < 0.6 else Color("#b08a3a")
			if fposmod(v * 3.0, 1.0) < 0.6:   # standing, its glass dark
				g.box(x + 0.2, y + 0.22, x + 0.8, y + 0.78, 0, 0.54, body.lightened(0.08), body, body.darkened(0.18))
				g.box(x + 0.26, y + 0.78, x + 0.74, y + 0.785, 0.24, 0.42, Color("#0f1316"), Color("#0f1316"), Color("#0f1316"))
				for i in 3:
					g.box(x + 0.3 + i * 0.14, y + 0.785, x + 0.4 + i * 0.14, y + 0.79, 0.28, 0.38, Color("#8a8672"), Color("#8a8672"), Color("#8a8672"))
				g.box(x + 0.22, y + 0.78, x + 0.78, y + 0.79, 0.45, 0.52, trim, trim, trim.darkened(0.2))
				g.box(x + 0.28, y + 0.78, x + 0.72, y + 0.84, 0.12, 0.16, Color(STEEL), Color(STEEL).darkened(0.1), Color(STEEL).darkened(0.25))
				g.box(x + 0.8, y + 0.4, x + 0.83, y + 0.46, 0.3, 0.46, Color(STEEL), Color(STEEL), Color(STEEL))   # the arm
			else:   # on its back
				g.box(x + 0.12, y + 0.24, x + 0.88, y + 0.76, 0, 0.3, body.lightened(0.08), body, body.darkened(0.18))
				g.box(x + 0.42, y + 0.3, x + 0.72, y + 0.7, 0.3, 0.305, Color("#0f1316"), Color("#0f1316"), Color("#0f1316"))
				g.box(x + 0.76, y + 0.26, x + 0.86, y + 0.74, 0.3, 0.305, trim, trim, trim)
				g.box(x + 0.16, y + 0.34, x + 0.3, y + 0.66, 0.3, 0.34, Color(STEEL), Color(STEEL).darkened(0.1), Color(STEEL).darkened(0.25))
		"gen":   # a generator set on its skid: engine, alternator, exhaust, a fuel can
			g.box(x + 0.1, y + 0.18, x + 0.9, y + 0.82, 0, 0.06, Color("#2c2f2e"), Color("#232625"), Color("#1d201f"))
			var c := Color("#565c4c")
			g.box(x + 0.14, y + 0.28, x + 0.56, y + 0.72, 0.06, 0.42, c.lightened(0.1), c, c.darkened(0.15))
			g.box(x + 0.2, y + 0.72, x + 0.5, y + 0.725, 0.14, 0.34, Color(DARK), Color(DARK), Color(DARK))
			g.prism(x + 0.72, y + 0.5, 0.16, 0.06, 0.34, Color(STEEL), Color("#4a4f52"), 10)
			g.prism(x + 0.3, y + 0.4, 0.035, 0.42, 0.56, Color("#3a3d3a"), Color("#111312"), 6)
			g.box(x + 0.62, y + 0.7, x + 0.78, y + 0.8, 0.06, 0.24, Color("#a8642a"), Color("#a8642a"), Color("#8a4f1e"))
		"cot":   # a numbered bunk and its foot locker
			var bl := Color("#55604a") if v < 0.5 else Color("#5a5648")
			g.box(x + 0.1, y + 0.2, x + 0.9, y + 0.68, 0.14, 0.2, Color("#3a3d3a"), Color("#2c2f2c"), Color("#262926"))
			for q in [[0.1, 0.2], [0.86, 0.2], [0.1, 0.64], [0.86, 0.64]]:
				g.box(x + q[0], y + q[1], x + q[0] + 0.04, y + q[1] + 0.04, 0, 0.3, Color(STEEL), Color(STEEL).darkened(0.1), Color(STEEL).darkened(0.25))
			g.box(x + 0.12, y + 0.22, x + 0.88, y + 0.66, 0.2, 0.26, Color("#8a8672"), Color("#77735f"), Color("#66624f"))
			g.box(x + 0.34, y + 0.21, x + 0.89, y + 0.67, 0.26, 0.285, bl.lightened(0.08), bl, bl.darkened(0.15))
			g.box(x + 0.14, y + 0.3, x + 0.3, y + 0.58, 0.26, 0.31, Color("#b8b29a"), Color("#a59f88"), Color("#928c76"))
			g.box(x + 0.5, y + 0.72, x + 0.9, y + 0.9, 0, 0.26, Color("#4f5546"), Color("#454b3d"), Color("#3a4034"))
			g.box(x + 0.64, y + 0.9, x + 0.76, y + 0.905, 0.14, 0.2, Color("#a8642a"), Color("#a8642a"), Color("#a8642a"))
		"ration":   # the stores: olive cases, an orange band, one prised open
			var c := Color("#4f5546")
			g.box(x + 0.12, y + 0.12, x + 0.88, y + 0.88, 0, 0.3, c.lightened(0.1), c, c.darkened(0.18))
			g.box(x + 0.12, y + 0.88, x + 0.88, y + 0.885, 0.12, 0.18, Color("#a8642a"), Color("#a8642a"), Color("#a8642a"))
			g.box(x + 0.88, y + 0.12, x + 0.885, y + 0.88, 0.12, 0.18, Color("#8a4f1e"), Color("#8a4f1e"), Color("#8a4f1e"))
			var ox := 0.14 + 0.2 * v
			g.box(x + ox, y + 0.2, x + ox + 0.46, y + 0.66, 0.3, 0.54, c.lightened(0.14) if v < 0.5 else Color("#191b18"), c.lightened(0.04), c.darkened(0.14))
			if life >= 3:
				g.box(x + ox + 0.14, y + 0.66, x + ox + 0.32, y + 0.665, 0.38, 0.46, Color(CREAM), Color(CREAM), Color(CREAM))
		"cargo":   # a lab freight case: pale, banded, capped at the corners
			var c := Color("#7d858c")
			g.box(x + 0.12, y + 0.12, x + 0.88, y + 0.88, 0, 0.54, c.lightened(0.08), c, c.darkened(0.18))
			for e in [0.12, 0.82]:
				g.box(x + e, y + 0.88, x + e + 0.06, y + 0.887, 0, 0.54, Color("#3a3f44"), Color("#3a3f44"), Color("#3a3f44"))
				g.box(x + 0.88, y + e, x + 0.887, y + e + 0.06, 0, 0.54, Color("#2f3338"), Color("#2f3338"), Color("#2f3338"))
			g.box(x + 0.18, y + 0.88, x + 0.82, y + 0.887, 0.3, 0.38, Color("#3f6a8a"), Color("#3f6a8a"), Color("#3f6a8a"))
			g.box(x + 0.88, y + 0.18, x + 0.887, y + 0.82, 0.3, 0.38, Color("#335a76"), Color("#335a76"), Color("#335a76"))
			if v < 0.4:
				g.box(x + 0.3, y + 0.3, x + 0.7, y + 0.7, 0.54, 0.56, Color("#3a3f44"), Color("#3a3f44"), Color("#2f3338"))
		_:
			var c := Color("#6a5236") if v < 0.5 else Color("#5a5a44")
			for i in 4:   # a pallet
				g.box(x + 0.1, y + 0.12 + i * 0.2, x + 0.9, y + 0.26 + i * 0.2, 0, 0.05, Color("#5a4630"), Color("#49392a"), Color("#3d3024"))
			g.box(x + 0.14, y + 0.14, x + 0.86, y + 0.86, 0.05, 0.38, c.lightened(0.1), c, c.darkened(0.18))
			for e in [0.14, 0.8]:   # its battens
				g.box(x + e, y + 0.86, x + e + 0.06, y + 0.867, 0.05, 0.38, c.darkened(0.25), c.darkened(0.25), c.darkened(0.25))
				g.box(x + 0.86, y + e, x + 0.867, y + e + 0.06, 0.05, 0.38, c.darkened(0.35), c.darkened(0.35), c.darkened(0.35))
			var ox := 0.18 + 0.22 * v
			var c2 := Color("#5a5a44") if v < 0.5 else Color("#6a5236")
			g.box(x + ox, y + 0.24, x + ox + 0.4, y + 0.62, 0.38, 0.56, c2.lightened(0.1), c2, c2.darkened(0.18))
			if life >= 3:   # a stencilled mark
				g.box(x + 0.4, y + 0.867, x + 0.6, y + 0.87, 0.16, 0.26, Color("#2a2622"), Color("#2a2622"), Color("#2a2622"))
	return true


## the flat wear, once
func floor_geo(g: V3Mesh) -> void:
	for P in flat:
		match P[0]:
			"stain":
				g.disc(P[1], P[2], P[3], P[4], 0.0052, Color(WET), 12)
				g.disc(P[1] + 0.03, P[2], P[3] * 0.55, P[4] * 0.5, 0.0056, Color("#2a3a40"), 10)
			"cable":
				var pts: Array = P[1]
				for i in pts.size() - 1:
					if pts[i].distance_to(pts[i + 1]) > 0.01:
						UsView3D.flat_line(g, Vector3(pts[i].x, 0.0055, pts[i].y), Vector3(pts[i + 1].x, 0.0055, pts[i + 1].y), 0.014, Color("#15171a"))
			"mat":
				g.quad(Vector3(P[1], 0.0052, P[2]), Vector3(P[1], 0.0052, P[4]), Vector3(P[3], 0.0052, P[4]), Vector3(P[3], 0.0052, P[2]), Color("#1d1f21"))
				for i in 4:
					var z: float = P[2] + (P[4] - P[2]) * (i + 0.5) / 4.0
					UsView3D.flat_line(g, Vector3(P[1] + 0.03, 0.0056, z), Vector3(P[3] - 0.03, 0.0056, z), 0.008, Color("#2a2d30"))
			"pad":   # a wash-down pad: pale bars, nothing like a warning's colours
				g.quad(Vector3(P[1], 0.0052, P[2]), Vector3(P[1], 0.0052, P[4]), Vector3(P[3], 0.0052, P[4]), Vector3(P[3], 0.0052, P[2]), Color("#2b3338"))
				for i in 5:
					var z: float = P[2] + (P[4] - P[2]) * (i + 0.5) / 5.0
					UsView3D.flat_line(g, Vector3(P[1] + 0.04, 0.0056, z), Vector3(P[3] - 0.04, 0.0056, z), 0.012, Color("#55626a"))
			"silt":
				var x: float = P[1]
				var y: float = P[2]
				if P[3] == 0:
					g.quad(Vector3(x, 0.0048, y), Vector3(x, 0.0048, y + P[4]), Vector3(x + 1, 0.0048, y + P[5]), Vector3(x + 1, 0.0048, y), Color(K.silt))
				else:
					g.quad(Vector3(x, 0.0048, y), Vector3(x, 0.0048, y + 1), Vector3(x + P[5], 0.0048, y + 1), Vector3(x + P[4], 0.0048, y), Color(K.silt))
			"grate":
				var cx: float = P[1] + 0.5
				var cy: float = P[2] + 0.5
				var a := Vector3(0.36, 0, 0) if P[3] else Vector3(0, 0, 0.36)   # it lies across the way through
				var b := Vector3(0, 0, 0.1) if P[3] else Vector3(0.1, 0, 0)
				var c := Vector3(cx, 0.005, cy)
				g.quad(c - a - b, c - a + b, c + a + b, c + a - b, Color("#3d4140"))
				g.quad(c - a * 0.93 - b * 0.72 + Vector3(0, 0.0005, 0), c - a * 0.93 + b * 0.72 + Vector3(0, 0.0005, 0), c + a * 0.93 + b * 0.72 + Vector3(0, 0.0005, 0), c + a * 0.93 - b * 0.72 + Vector3(0, 0.0005, 0), Color("#0e1011"))
				for i in 6:
					var o := a * (-0.78 + i * 0.312)
					UsView3D.flat_line(g, c + o - b * 0.72 + Vector3(0, 0.001, 0), c + o + b * 0.72 + Vector3(0, 0.001, 0), 0.012, Color("#4a4f4e"))


## the drips on screen: a ring spreads on the stain under a valve, in six steps (the shapes are made once and only
## recoloured; nothing moves under Reduce Motion)
func frame(g: V3Mesh, t: float, view) -> void:
	if life < 2 or PalSettings.reduce_motion:
		return
	for n in drips.size():
		var d: Array = drips[n]
		if not view.near(d[0], d[1], 0.4):
			continue
		var u := fposmod(t / 2.6 + d[3], 1.0)
		if u >= 0.45:
			continue
		var f := u / 0.45
		var step := mini(5, int(f * 6.0))
		if not rings.has(n):
			var made: Array = []
			for q in 6:
				var m := V3Mesh.new()
				UsView3D.arc(m, d[0], d[1], 0.03 + 0.15 * (q + 0.5) / 6.0, 0.006, 0, TAU, 0.007, Color.WHITE, 8)
				made.append(m)
			rings[n] = made
		var shape: V3Mesh = rings[n][step]
		UsView3D.tinted(g, shape, 0, shape.size(), UsView3D.dim(Color("#7f9aa0"), 0.6 * (1.0 - f)))


## what the plan made, for the coverage sheet and the tests
func report() -> Dictionary:
	return {"level": level, "walls": wall.size(), "pieces": count, "flat": flat.size(), "drips": drips.size(), "muted_tags": mute.size(), "skipped": skipped}
