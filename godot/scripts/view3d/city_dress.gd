class_name CityDress
extends RefCounted
## City Black Out's storefronts, rooftops and neon: the first slice of the Living World work order
## (dev/plans/palisade-living-world-graphics-work-order.md). Visual only: the sim never reads any of it, and nothing
## here is solid, so collision, sight, paths and the network state are untouched. Three parts, kept apart:
##   plan()   recipes -> placement records, from the map's tiles and a hash of its own (vh): never the game's random
##            numbers, so the same city is dressed the same on every machine and at every quality setting
##   chunk() and lit_meshes()   records -> geometry. Unlit pieces join the 8x8 building chunks (no extra draws). Lit
##            pieces are one mesh per district and power state, shown or hidden in play and never rebuilt
##   frame(), glow(), holes()   the lit signs on screen: an additive halo on the 2D glow layer (over the night
##            shade) and a capped number of holes in the shade, added after every gameplay light
## Power: a district's signs are lit while the Power Station holds and the district's own POI stands. A few signs
## are battery-backed (they stay on, dimmer), a few are dead, a few fail (they flicker; steady under Reduce Motion).
## Quality3D.life: 0 off (the city as it was), 1 signs and storefronts, 2 + rooftops, street spill and flicker,
## 3 + roofline tubes and more holes.

const V3 = preload("res://scripts/view3d/view3d.gd")

## how many holes in the night shade the signs may take at once, by Quality3D.life (a ceiling, after the game's own)
const HOLES := [0, 2, 5, 8]
## how many signs get a halo at once
const HALOS := [0, 14, 28, 44]
const FLIP := 1.1   # seconds a district takes to go dark or come back

## each district (the nearest POI, or Main Command's plaza): its two tube colours, its shop words (short ones fit
## one tile), its landmark's name and its tower words. Every name is made up for PALISADE.
const DISTRICT := {
	"radio": {"cols": ["#3ae0ff", "#ff4a8a"], "words": ["RADIO", "HIFI", "TV", "FILM", "TUBES", "RECORDS", "DISCS", "LENS"], "hero": "MOTH RADIO", "tower": ["FILM", "HIFI"]},
	"power": {"cols": ["#ffd24a", "#ff8a2a"], "words": ["VOLT", "LAMPS", "WIRE", "FUSE", "TOOLS", "COILS", "AMPS", "METERS"], "hero": "AMP WORKS", "tower": ["VOLT", "FUSE"]},
	"hospital": {"cols": ["#4aff9a", "#e6fff0"], "words": ["CLINIC", "DRUGS", "OPTIC", "DENTAL", "+", "24H", "LAB", "XRAY"], "hero": "ST ELM +", "tower": ["+", "24H"]},
	"armory": {"cols": ["#ff4a3a", "#ffb03a"], "words": ["PAWN", "SURPLUS", "LOANS", "LOCKS", "BOOTS", "GYM", "GOLD", "SAFES"], "hero": "IRON PAWN", "tower": ["PAWN", "GYM"]},
	"gas": {"cols": ["#ff8a2a", "#3ae0ff"], "words": ["DINER", "MOTEL", "TIRES", "EATS", "COFFEE", "PIES", "OIL", "MAPS"], "hero": "OWL DINER", "tower": ["EATS", "MOTEL"]},
	"hardware": {"cols": ["#ffd24a", "#4aff9a"], "words": ["PAINT", "KEYS", "NAILS", "LUMBER", "TOOLS", "PIPES", "ROPE", "SAWS"], "hero": "NAIL + KEY", "tower": ["KEYS", "PAINT"]},
	"brick": {"cols": ["#ff6a3a", "#ffd24a"], "words": ["KILN", "TILE", "STONE", "BAR", "POOL", "DARTS", "ALES", "CLAY"], "hero": "RED KILN", "tower": ["BAR", "POOL"]},
	"garage": {"cols": ["#9a6aff", "#ff4a8a"], "words": ["ARCADE", "NOODLE", "PARK", "HOTEL", "BAR", "KARAOKE", "TAXI", "DELI"], "hero": "KITE HOTEL", "tower": ["HOTEL", "PARK"]},
	"command": {"cols": ["#3ae0ff", "#f2f6ff"], "words": ["BANK", "HOTEL", "CAFE", "NEWS", "BOOKS", "POST", "LAW", "TEA"], "hero": "CITY BANK", "tower": ["NEWS", "CAFE"]},
}
## 3x5 block letters: five rows, the left cell the high bit
const GLYPH := {
	"A": [2, 5, 7, 5, 5], "B": [6, 5, 6, 5, 6], "C": [3, 4, 4, 4, 3], "D": [6, 5, 5, 5, 6], "E": [7, 4, 6, 4, 7], "F": [7, 4, 6, 4, 4],
	"G": [3, 4, 5, 5, 3], "H": [5, 5, 7, 5, 5], "I": [7, 2, 2, 2, 7], "J": [1, 1, 1, 5, 2], "K": [5, 5, 6, 5, 5], "L": [4, 4, 4, 4, 7],
	"M": [5, 7, 7, 5, 5], "N": [6, 5, 5, 5, 5], "O": [7, 5, 5, 5, 7], "P": [6, 5, 6, 4, 4], "Q": [2, 5, 5, 7, 3], "R": [6, 5, 6, 5, 5],
	"S": [3, 4, 2, 1, 6], "T": [7, 2, 2, 2, 2], "U": [5, 5, 5, 5, 7], "V": [5, 5, 5, 5, 2], "W": [5, 5, 7, 7, 5], "X": [5, 5, 2, 5, 5],
	"Y": [5, 5, 2, 2, 2], "Z": [7, 1, 2, 4, 7], "0": [7, 5, 5, 5, 7], "1": [2, 6, 2, 2, 7], "2": [6, 1, 2, 4, 7], "4": [5, 5, 7, 1, 1],
	"7": [7, 1, 2, 2, 2], "+": [0, 2, 7, 2, 0], "-": [0, 0, 7, 0, 0], " ": [0, 0, 0, 0, 0],
}
const BOARD := "#121416"
const METAL := "#474c51"
const GLASS := "#0b0d10"

var W   # V3World (a node: holding the scenery itself would be a reference cycle, and leak)
var sim: Sim
var m
var life := 0
var signs: Array = []   # placement records (see _sign)
var roofs: Array = []   # rooftop plant: [kind, i, j, variant 0..1]
var skipped: Array = []   # placements a recipe wanted and couldn't make: [what, block x, block y, why]
var used := {}   # roof tiles a sign stands on (no plant there)
var by_chunk := {}   # 8x8 chunk key -> [sign ids]
var dist := {}   # district -> {on, off: MeshInstance3D, want, lit, flip, ph}
var seen: Array = []   # the signs on screen that can light (refreshed every fourth frame)
var seen_dim := PackedFloat32Array()   # 0.3 for one whose building is see-through just now, else 1
var hole_s := {}   # sign id -> its hole's eased strength
var hole_keep := {}   # the signs picked to hold a hole
var glow_tex: GradientTexture2D
var tick := 0
var flipping := false   # a district is mid stutter


func _init(scn) -> void:
	W = scn.W
	sim = scn.sim
	m = scn.m
	life = Quality3D.life
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 0.6))
	gr.set_color(1, Color(1, 1, 1, 0))
	glow_tex = GradientTexture2D.new()
	glow_tex.gradient = gr
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	glow_tex.width = 64
	glow_tex.height = 64
	plan()


## the dressing's own hash: a namespace apart from the map's (Pal.hash2 with other multipliers and a salt)
static func vh(i: int, j: int, salt: int) -> float:
	return Pal.hash2(i * 31 + salt * 7919 + 101, j * 17 + salt * 104729 + 53)


## a building tile's height, as V3Scenery._building has it
static func height(i: int, j: int) -> float:
	var hbv := Pal.hash2((i / 4) * 7 + 3, (j / 4) * 13 + 5)
	var hb := maxi(0, mini(4, floori(hbv * 5)) - (1 if Pal.hash2(i * 3 + 1, j * 5 + 2) > 0.8 else 0))
	return V3.WALL_H * (0.85 + hb * 0.225)


func _b(i: int, j: int) -> bool:
	return sim.t_at(i, j) == PalMaps.T_BLDG


func _street(i: int, j: int) -> bool:
	var t: int = sim.t_at(i, j)
	return t == PalMaps.T_ROAD or t == PalMaps.T_WALK


## does this building tile's south (0) or east (1) face look onto a street, with nothing standing in front of it?
func _front(i: int, j: int, f: int) -> bool:
	if _b(i + 1, j + 1):
		return false
	return _street(i, j + 1) if f == 0 else _street(i + 1, j)


## a face's frame: origin, the direction that runs left to right on screen, the normal
static func frame_of(i: int, j: int, f: int) -> Array:
	if f == 0:
		return [Vector3(i, 0, j + 1), Vector3(1, 0, 0), Vector3(0, 0, 1)]
	return [Vector3(i + 1, 0, j + 1), Vector3(0, 0, -1), Vector3(1, 0, 0)]


# ---------------------------------------------------------------- the plan

## every block of the city: its district, its shop front, its roof sign, its rooftop plant
func plan() -> void:
	var N: int = sim.N
	var pois: Array = []
	for co in sim.cores:
		if co.has("poi"):
			pois.append([str(co.poi.id), co.i + 0.5, co.j + 0.5])
	var C := N * 0.5
	var blocks: Array = []
	var hero := {}   # district -> [score, block index]
	for by in N / 4:
		for bx in N / 4:
			var tiles := 0
			for j in range(by * 4, by * 4 + 4):
				for i in range(bx * 4, bx * 4 + 4):
					if _b(i, j):
						tiles += 1
			if tiles == 0:
				continue
			var cx := bx * 4 + 1.5
			var cy := by * 4 + 1.5
			var did := "command"
			var best := Vector2(cx - C, cy - C).length() if Vector2(cx - C, cy - C).length() < N * 0.17 else 1e9
			var near := 1e9
			for p in pois:
				var d := Vector2(cx - p[1], cy - p[2]).length()
				near = minf(near, d)
				if d < best:
					best = d
					did = p[0]
			if not DISTRICT.has(did):
				did = "command"
			var B := {"bx": bx, "by": by, "did": did, "front": _runs(bx, by, true), "roof": _runs(bx, by, false)}
			blocks.append(B)
			if not B.roof.is_empty():   # the landmark: the roof run nearest the district's POI (a longer run wins a tie)
				var score: float = (near if did != "command" else Vector2(cx - C, cy - C).length()) - 1.5 * B.roof[1].size()
				if not hero.has(did) or score < hero[did][0]:
					hero[did] = [score, blocks.size() - 1]
	for bi in blocks.size():
		var B: Dictionary = blocks[bi]
		var bx: int = B.bx
		var by: int = B.by
		var D: Dictionary = DISTRICT[B.did]
		var is_hero: bool = hero.has(B.did) and hero[B.did][1] == bi
		var comm := vh(bx, by, 1) > 0.42 or is_hero
		var roof_sign := false
		if is_hero or (comm and vh(bx, by, 3) > 0.74):
			if B.roof.is_empty():
				skipped.append(["marquee", bx, by, "no roof run of two tiles"])
			else:
				var word: String = D.hero if is_hero else _word(D.words, vh(bx, by, 6), 6 if B.roof[1].size() < 3 else 9)
				_sign("marquee", B, B.roof[0], B.roof[1], word, is_hero)
				roof_sign = true
		elif comm and vh(bx, by, 4) > 0.8:
			var ci := bx * 4 + 2
			var cj := by * 4 + 2
			if _b(ci, cj) and not _b(ci + 1, cj) and not _b(ci, cj + 1):
				_sign("tower", B, 0, [[ci, cj]], _word(D.tower, vh(bx, by, 6), 5), false)
			else:
				skipped.append(["tower", bx, by, "no free corner"])
		if comm:
			if B.front.is_empty():
				if not roof_sign:
					skipped.append(["shop", bx, by, "no face on a street"])
			else:
				var n: int = B.front[1].size()
				var word: String = ("OPEN" if vh(bx, by, 14) < 0.7 else "24H") if roof_sign else _word(D.words, vh(bx, by, 6), 4 if n == 1 else 7)
				_sign("shop", B, B.front[0], B.front[1], word, false)
	for j in N:   # rooftop plant, on any building that carries no sign
		for i in N:
			if not _b(i, j) or used.has(j * N + i):
				continue
			var r := vh(i, j, 5)
			var kind := ""
			if r < 0.09:
				kind = "ac"
			elif r < 0.13:
				kind = "tank"
			elif r < 0.19:
				kind = "vent"
			elif r < 0.23:
				kind = "sky"
			elif r < 0.26:
				kind = "mast"
			elif r < 0.30:
				kind = "hut"
			if kind != "":
				roofs.append([kind, i, j, vh(i, j, 11)])


## the block's best run of building tiles for a shop front (front: faces on a street) or a roof sign (two or more
## tiles along its south or east edge): [face, [[i, j]...] in left-to-right order], or [] with none
func _runs(bx: int, by: int, front: bool) -> Array:
	var best: Array = []
	for f in 2:
		for a in range(3, -1, -1):   # the block's southmost row or eastmost column first
			var run: Array = []
			for q in 5:
				var i: int = (bx * 4 + q) if f == 0 else (bx * 4 + a)
				var j: int = (by * 4 + a) if f == 0 else (by * 4 + 3 - q)
				var ok := q < 4 and _b(i, j) and (_front(i, j, f) if front else not (_b(i, j + 1) if f == 0 else _b(i + 1, j)))
				if ok:
					run.append([i, j])
					continue
				if run.size() > (best[1].size() if not best.is_empty() else (0 if front else 1)):
					best = [f, run]
				run = []
	return best


func _word(list: Array, h: float, most: int) -> String:
	var fit: Array = list.filter(func(w): return w.length() <= most)
	if fit.is_empty():
		return "OPEN" if most >= 4 else "BAR"
	return fit[mini(fit.size() - 1, floori(h * fit.size()))]


## one sign's placement record: what it is, which tiles and face it sits on, its word, colours and power class,
## and where its light is (centre, span, the ground it spills on). No gameplay state.
func _sign(kind: String, B: Dictionary, f: int, tiles: Array, word: String, is_hero: bool) -> void:
	var D: Dictionary = DISTRICT[B.did]
	var bx: int = B.bx
	var by: int = B.by
	var n := tiles.size()
	var hs: Array = []
	for t in tiles:
		hs.append(height(t[0], t[1]))
	var F := frame_of(tiles[0][0], tiles[0][1], f)
	var pick := vh(bx, by, 7)
	var col := Color.html(D.cols[0] if pick < 0.62 else D.cols[1])
	var col2 := Color.html(D.cols[1] if pick < 0.62 else D.cols[0])
	var power := 0   # 0 the grid, 1 battery-backed, 2 dead
	if word in ["+", "24H"] or (is_hero and B.did == "hospital"):
		power = 1
	elif not is_hero and vh(bx, by, 8) < 0.08:
		power = 2
	var R := {"id": signs.size(), "kind": kind, "did": B.did, "bx": bx, "by": by, "face": f, "tiles": tiles, "hs": hs, "word": word,
		"col": col, "col2": col2, "power": power, "hero": is_hero, "fail": power == 0 and not is_hero and vh(bx, by, 9) < 0.14,
		"gone": (floori(vh(bx, by, 10) * word.length()) if vh(bx, by, 12) < 0.2 and word.length() > 2 and not is_hero else -1),
		"ph": vh(bx, by, 13) * TAU, "F": F, "anchor": Vector2(tiles[0][0] + 0.5, tiles[0][1] + 0.5), "mute": false}
	var chars := word.length()
	match kind:
		"shop":
			var hmin: float = hs.min()
			var hmax: float = hs.max()
			var u0 := 0.08 if n == 1 else (0.15 if n == 2 else 0.5)
			var u1 := n - u0
			var hb := 0.2 if n == 1 else 0.25
			var roof := hmin < 0.36 + hb + 0.05   # too low for a board over the shop window: it stands on the parapet
			R.roof = roof
			if roof:   # a roof sign already stands here: the shop keeps its door and windows and goes without a board
				for t in tiles:
					if used.has(t[1] * sim.N + t[0]):
						R.mute = true
			R.y0 = (hmax + 0.02) if roof else (hmin - 0.05 - hb)
			R.y1 = R.y0 + hb
			R.u0 = u0
			R.u1 = u1
			R.cell = minf((u1 - u0 - 0.08) / (4 * chars - 1), (hb - 0.07) / 5.0)
			R.c = F[0] + F[1] * (n * 0.5) + Vector3(0, (R.y0 + R.y1) * 0.5, 0)
			R.span = F[1] * ((4 * chars - 1) * R.cell)
			R.ground = F[0] + F[1] * (n * 0.5) + F[2] * 0.7
			if roof:
				for t in tiles:
					used[t[1] * sim.N + t[0]] = true
		"marquee":
			var hmax: float = hs.max()
			var hb := 0.42 if is_hero else 0.34
			F = [F[0] - F[2] * 0.3, F[1], F[2]]
			R.F = F
			R.y0 = hmax + 0.1
			R.y1 = R.y0 + hb
			R.u0 = 0.1
			R.u1 = n - 0.1
			R.cell = minf((n - 0.32) / (4 * chars - 1), (hb - 0.1) / 5.0)
			R.c = F[0] + F[1] * (n * 0.5) + Vector3(0, (R.y0 + R.y1) * 0.5, 0)
			R.span = F[1] * ((4 * chars - 1) * R.cell)
			R.ground = F[0] + F[1] * (n * 0.5) + F[2] * 0.2 + Vector3(0, hmax, 0)
			for t in tiles:
				used[t[1] * sim.N + t[0]] = true
		"tower":
			var cell := 0.036
			var h0: float = hs[0]
			R.cell = cell
			R.y0 = h0
			R.y1 = h0 + chars * (5 * cell) + (chars + 1) * 0.03
			R.c = Vector3(tiles[0][0] + 0.88, (R.y0 + R.y1) * 0.5, tiles[0][1] + 0.88)
			R.span = Vector3(0, R.y1 - R.y0 - 0.06, 0)
			R.ground = Vector3(tiles[0][0] + 0.7, h0, tiles[0][1] + 0.7)
			used[tiles[0][1] * sim.N + tiles[0][0]] = true
	signs.append(R)
	var key: int = (tiles[0][1] / 8) * 64 + tiles[0][0] / 8   # the chunk its first tile is in
	if not by_chunk.has(key):
		by_chunk[key] = []
	by_chunk[key].append(R.id)


# ---------------------------------------------------------------- geometry

func _pt(F: Array, u: float, y: float, d: float) -> Vector3:
	return F[0] + F[1] * u + Vector3(0, y, 0) + F[2] * d


## a flat piece on a face, d out from it
func _fq(g: V3Mesh, F: Array, u0: float, u1: float, y0: float, y1: float, d: float, col: Color) -> void:
	g.quad(_pt(F, u0, y0, d), _pt(F, u1, y0, d), _pt(F, u1, y1, d), _pt(F, u0, y1, d), col)


## a box on a face, from d0 to d1 out of it (the south side takes the colour, the east side its shade, as buildings do)
func _fbox(g: V3Mesh, F: Array, u0: float, u1: float, y0: float, y1: float, d0: float, d1: float, col: Color, top = null) -> void:
	var a := _pt(F, u0, y0, d0)
	var b := _pt(F, u1, y1, d1)
	g.box(minf(a.x, b.x), minf(a.z, b.z), maxf(a.x, b.x), maxf(a.z, b.z), y0, y1, top if top != null else col.lightened(0.12), col, col.darkened(0.22))


## an unlit colour on a face: the east side in shade
func _sh(F: Array, col: Color) -> Color:
	return col.darkened(0.22) if F[2].x > 0.5 else col


func _glyph(g: V3Mesh, F: Array, ch: String, u: float, y0: float, cell: float, d: float, col: Color) -> void:
	var G: Array = GLYPH.get(ch, GLYPH[" "])
	for r in 5:
		var bits: int = G[r]
		var q := 0
		while q < 3:
			if bits & (4 >> q) == 0:
				q += 1
				continue
			var q1 := q
			while q1 + 1 < 3 and bits & (4 >> (q1 + 1)) != 0:
				q1 += 1
			_fq(g, F, u + q * cell, u + (q1 + 1) * cell, y0 + (4 - r) * cell, y0 + (5 - r) * cell, d, col)
			q = q1 + 1


## a tube's colour lit (it glows: the world shader reads the alpha) and out
static func tube(col: Color, on: bool) -> Color:
	if on:
		return Color(col.r, col.g, col.b, 0.45)
	return Color(0.1, 0.11, 0.12).lerp(col, 0.14)


## a sign's word: lit into `on`, its dark tubes into `off` (a battery sign is lit in both, a dead one in neither;
## a failed letter stays dark)
func _word_geo(on: V3Mesh, off: V3Mesh, R: Dictionary, F: Array, uc: float, y0: float, d: float) -> void:
	var word: String = R.word
	var cell: float = R.cell
	var u := uc - (4 * word.length() - 1) * cell * 0.5
	for k in word.length():
		var dead: bool = R.power == 2 or k == R.gone
		_glyph(on, F, word[k], u, y0, cell, d, tube(R.col, not dead))
		_glyph(off, F, word[k], u, y0, cell, d, tube(R.col, R.power == 1 and not dead))
		u += 4 * cell


## the unlit pieces of the signs and rooftops in one 8x8 chunk, into that chunk's building mesh
func chunk(g: V3Mesh, ci: int, cj: int) -> void:
	for id in by_chunk.get((cj / 8) * 64 + ci / 8, []):
		var R: Dictionary = signs[id]
		var F: Array = R.F
		g.anchor = R.anchor
		var board := Color.html(BOARD)
		var metal := Color.html(METAL)
		match R.kind:
			"shop":
				for k in R.tiles.size():
					var w0: float = k + (0.36 if k == 0 else 0.1)
					_fbox(g, F, w0 - 0.025, k + 0.925, 0.05, 0.29, 0.0, 0.012, metal)
					_fq(g, F, (w0 + k + 0.9) * 0.5 - 0.008, (w0 + k + 0.9) * 0.5 + 0.008, 0.07, 0.27, 0.02, _sh(F, metal))
				_fbox(g, F, 0.08, 0.3, 0.0, 0.33, 0.0, 0.01, metal)
				_fq(g, F, 0.1, 0.28, 0.0, 0.31, 0.014, _sh(F, Color.html("#1b1d21")))
				_fq(g, F, 0.245, 0.262, 0.14, 0.17, 0.018, _sh(F, Color.html("#8a8f94")))
				if R.mute:
					pass
				elif R.roof:
					_fbox(g, F, R.u0, R.u1, R.y0, R.y1, -0.035, 0.0, board, Color.html("#1c1f22"))
				else:
					_fbox(g, F, R.u0, R.u1, R.y0, R.y1, 0.0, 0.025, board, Color.html("#1c1f22"))
			"marquee":
				var n: int = R.tiles.size()
				for e in [0.22, n - 0.22]:
					var hk: float = R.hs[clampi(floori(e), 0, n - 1)]
					_fbox(g, F, e - 0.02, e + 0.02, hk, R.y0, -0.05, -0.01, metal)
					g.bar(_pt(F, e, hk, -0.32), _pt(F, e, R.y0 + 0.16, -0.035), 0.012, metal)
				_fbox(g, F, R.u0, R.u1, R.y0, R.y1, -0.04, 0.0, board, Color.html("#1c1f22"))
				for e in [[R.u0, R.u0 + 0.025], [R.u1 - 0.025, R.u1]]:
					_fq(g, F, e[0], e[1], R.y0, R.y1, 0.004, _sh(F, metal))
			"tower":
				var t: Array = R.tiles[0]
				g.box(t[0] + 0.8, t[1] + 0.8, t[0] + 0.96, t[1] + 0.96, R.y0, R.y1, Color.html("#1c1f22"), board, board.darkened(0.22))
	if life < 2:
		return
	for r in roofs:
		if r[1] / 8 != ci / 8 or r[2] / 8 != cj / 8:
			continue
		_roof(g, r)


## a rooftop piece: an AC unit, a water tank, vent stacks, a skylight, an antenna mast, a stair hut
func _roof(g: V3Mesh, r: Array) -> void:
	var i: int = r[1]
	var j: int = r[2]
	var v: float = r[3]
	var h := height(i, j)
	var x := i + 0.3 + v * 0.36
	var z := j + 0.3 + fposmod(v * 7.0, 1.0) * 0.36
	g.anchor = Vector2(i + 0.5, j + 0.5)
	match r[0]:
		"ac":
			g.box(x - 0.16, z - 0.12, x + 0.16, z + 0.12, h, h + 0.13, W.c("#5a6065"), W.c("#474c51"), W.c("#383c40"))
			g.disc(x, z, 0.085, 0.085, h + 0.132, W.c("#23262a"), 8)
			g.box(x - 0.15, z + 0.121, x + 0.15, z + 0.124, h + 0.03, h + 0.1, W.c("#2c3034"), W.c("#2c3034"), W.c("#2c3034"))
		"tank":
			for a in 3:
				var an := TAU * a / 3.0 + 0.5
				g.bar(Vector3(x + cos(an) * 0.13, h, z + sin(an) * 0.13), Vector3(x + cos(an) * 0.11, h + 0.14, z + sin(an) * 0.11), 0.012, W.c("#3a3d40"))
			g.prism(x, z, 0.15, h + 0.14, h + 0.4, W.c("#5d4a39"), W.c("#4a3b2e"), 8)
			g.prism(x, z, 0.16, h + 0.4, h + 0.5, W.c("#3d4347"), W.c("#3d4347"), 8, 0.02)
			g.prism(x, z, 0.155, h + 0.24, h + 0.26, W.c("#2b2e31"), W.c("#2b2e31"), 8)
		"vent":
			for q in 2:
				var vx := x - 0.08 + q * 0.17
				g.prism(vx, z, 0.04, h, h + 0.15 + q * 0.05, W.c("#52585d"), W.c("#1d2023"), 6)
				g.prism(vx, z, 0.058, h + 0.15 + q * 0.05, h + 0.175 + q * 0.05, W.c("#3f4449"), W.c("#3f4449"), 6)
		"sky":
			g.box(x - 0.2, z - 0.14, x + 0.2, z + 0.14, h, h + 0.035, W.c("#1d2a33"), W.c("#454a4e"), W.c("#383c40"))
			W_line(g, Vector3(x, h + 0.037, z - 0.14), Vector3(x, h + 0.037, z + 0.14), W.c("#454a4e"))
		"mast":
			g.bar(Vector3(x, h, z), Vector3(x, h + 0.62, z), 0.01, W.c("#4a4f54"))
			g.bar(Vector3(x - 0.1, h + 0.5, z + 0.1), Vector3(x + 0.1, h + 0.5, z - 0.1), 0.007, W.c("#4a4f54"))
			g.bar(Vector3(x - 0.07, h + 0.4, z + 0.07), Vector3(x + 0.07, h + 0.4, z - 0.07), 0.007, W.c("#4a4f54"))
			g.box(x - 0.03, z - 0.03, x + 0.03, z + 0.03, h, h + 0.05, W.c("#3a3d40"), W.c("#33363a"), W.c("#2a2d30"))
		"hut":
			g.box(x - 0.17, z - 0.15, x + 0.17, z + 0.15, h, h + 0.27, W.c("#4b4f53"), W.c("#3c4044"), W.c("#2f3235"))
			g.quad(Vector3(x - 0.06, h, z + 0.153), Vector3(x + 0.06, h, z + 0.153), Vector3(x + 0.06, h + 0.2, z + 0.153), Vector3(x - 0.06, h + 0.2, z + 0.153), W.c("#16181b"))


## a thin flat strip on a roof
func W_line(g: V3Mesh, a: Vector3, b: Vector3, col: Color) -> void:
	var s := (b - a).normalized().cross(Vector3.UP) * 0.008
	g.quad(a - s, a + s, b + s, b - s, col)


## the lit pieces: for each district one mesh with its signs lit and one with them out. Shown by frame().
func lit_meshes(root: Node3D) -> void:
	var gs := {}
	for R in signs:
		if not gs.has(R.did):
			gs[R.did] = [V3Mesh.new(), V3Mesh.new()]
		var on: V3Mesh = gs[R.did][0]
		var off: V3Mesh = gs[R.did][1]
		on.anchor = R.anchor
		off.anchor = R.anchor
		var F: Array = R.F
		var n: int = R.tiles.size()
		var live: bool = R.power != 2
		var warm := Color(0.85, 0.72, 0.47, 0.55).lerp(Color(R.col.r, R.col.g, R.col.b, 0.55), 0.25)
		match R.kind:
			"shop":
				if not R.mute:
					_word_geo(on, off, R, F, n * 0.5, R.y0 + (R.y1 - R.y0 - 5 * R.cell) * 0.5, 0.004 if R.roof else 0.03)
				for k in n:   # the shop windows: lit while the block has power
					var w0: float = k + (0.36 if k == 0 else 0.1)
					_fq(on, F, w0, k + 0.9, 0.07, 0.27, 0.016, warm if live else Color.html(GLASS))
					_fq(off, F, w0, k + 0.9, 0.07, 0.27, 0.016, Color.html(GLASS))
					if life >= 3:   # a tube along the roofline
						var hk: float = R.hs[k]
						_fq(on, F, k + 0.04, k + 0.96, hk - 0.04, hk - 0.015, 0.006, tube(R.col2, live))
						_fq(off, F, k + 0.04, k + 0.96, hk - 0.04, hk - 0.015, 0.006, tube(R.col2, false))
			"marquee":
				_word_geo(on, off, R, F, n * 0.5, R.y0 + (R.y1 - R.y0 - 5 * R.cell) * 0.5 + 0.015, 0.006)
				_fq(on, F, R.u0 + 0.06, R.u1 - 0.06, R.y0 + 0.025, R.y0 + 0.045, 0.006, tube(R.col2, live))
				_fq(off, F, R.u0 + 0.06, R.u1 - 0.06, R.y0 + 0.025, R.y0 + 0.045, 0.006, tube(R.col2, R.power == 1))
			"tower":
				var t: Array = R.tiles[0]
				var word: String = R.word
				for f in 2:
					var TF: Array = [Vector3(t[0] + 0.8, 0, t[1] + 0.96), Vector3(1, 0, 0), Vector3(0, 0, 1)] if f == 0 else [Vector3(t[0] + 0.96, 0, t[1] + 0.96), Vector3(0, 0, -1), Vector3(1, 0, 0)]
					for k in word.length():
						var y: float = R.y1 - 0.03 - (k + 1) * 5 * R.cell - k * 0.03
						var dead: bool = R.power == 2 or k == R.gone
						_glyph(on, TF, word[k], 0.08 - 1.5 * R.cell, y, R.cell, 0.004, tube(R.col, not dead))
						_glyph(off, TF, word[k], 0.08 - 1.5 * R.cell, y, R.cell, 0.004, tube(R.col, R.power == 1 and not dead))
				on.box(t[0] + 0.79, t[1] + 0.79, t[0] + 0.97, t[1] + 0.97, R.y1, R.y1 + 0.025, tube(R.col2, live), tube(R.col2, live), tube(R.col2, live))
				off.box(t[0] + 0.79, t[1] + 0.79, t[0] + 0.97, t[1] + 0.97, R.y1, R.y1 + 0.025, tube(R.col2, false), tube(R.col2, false), tube(R.col2, false))
	for did in gs:
		var a: MeshInstance3D = W.mesh_node(root, gs[did][0].commit(), W.mat_bldg, false)
		var b: MeshInstance3D = W.mesh_node(root, gs[did][1].commit(), W.mat_bldg, false)
		var p: bool = not sim.game.get("dark", false)   # a city built in the dark starts dark
		for co in sim.cores:
			if co.has("poi") and str(co.poi.id) == did and co.get("lost", false):
				p = false
		a.visible = p
		b.visible = not p
		dist[did] = {"on": a, "off": b, "want": p, "lit": p, "flip": -99.0}
	var wide := life >= 2
	for R in signs:   # each sign's district, and its halo's size on screen in half-tile widths (IsoView.TW2)
		R.D = dist[R.did]
		var sp: Vector3 = R.span
		var r := maxf(0.22, (R.y1 - R.y0) / (V3.PXV * 32.0) * (0.9 if R.kind != "tower" else 0.16)) * (1.5 if wide else 1.0)
		R.kx = absf(sp.x - sp.z) * 0.5 + r
		R.ky = absf((sp.x + sp.z) * 0.5 - sp.y / (V3.PXV * 32.0)) * 0.5 + r
		R.kg = 0.9 + sp.length() * 0.5


# ---------------------------------------------------------------- in play

## a lit sign's strength this moment: steady, a failing tube's stutter, or a short sputter now and then (each sign
## on its own clock; no motion under Reduce Motion or at life 1)
func flick(R: Dictionary, t: float) -> float:
	if PalSettings.reduce_motion or life < 2:
		return 0.85 if R.fail else 1.0
	if R.fail:
		return 1.0 if sin(t * 2.3 + R.ph) * sin(t * 5.7 + R.ph * 3.0) > -0.25 else 0.4
	var w: float = t / 9.0 + R.ph
	var k := fposmod(w, 1.0) * 9.0
	if k < 0.36 and Pal.hash2(floori(w) + R.id * 7, R.id) > 0.8:
		return 0.55 if fmod(k, 0.18) < 0.09 else 1.0
	return 1.0


## how strongly a sign shines now: its district lit, or its battery, or nothing
func strength(R: Dictionary, t: float) -> float:
	if R.D.lit:
		return flick(R, t)
	return 0.55 if R.power == 1 else 0.0


## each frame: a district going dark or coming back stutters over FLIP seconds, and the holes ease. Every fourth
## frame: the power itself (a district is lit while the Power Station holds and its own POI stands), which signs are
## on screen, which stand on a see-through building, and which of them hold a hole in the night shade.
func frame(dt: float) -> void:
	var t: float = sim.game.time
	tick += 1
	var scan := tick % 4 == 1
	if scan or flipping:
		var dark: bool = sim.game.get("dark", false)
		var lost := {}
		for co in sim.cores:
			if co.get("lost", false) and co.has("poi"):
				lost[str(co.poi.id)] = true
		flipping = false
		for did in dist:
			var D: Dictionary = dist[did]
			var want := not dark and not lost.has(did)
			if want != D.want:
				D.want = want
				D.flip = t
			var on: bool = D.want
			var k: float = (t - D.flip) / FLIP
			if k < 1.0 and not PalSettings.reduce_motion:   # two dips on the way out, two blinks on the way back
				var dip := (k > 0.12 and k < 0.3) or (k > 0.52 and k < 0.64)
				on = dip if D.want else (not dip and k < 0.86)
				flipping = true
			if on != D.lit:
				D.lit = on
				D.on.visible = on
				D.off.visible = not on
	if scan:
		seen.clear()
		seen_dim.clear()
		var v: IsoView = m.v
		var vis: Array = W.vis
		var p: Dictionary = sim.player
		var edge := v.TW2 * 4.0   # a few tiles past the screen: the camera moves before the next scan
		var ky := v.u / V3.PXV
		var cand: Array = []
		for cj in range(vis[2] / 8, vis[3] / 8 + 1):
			for ci in range(vis[0] / 8, vis[1] / 8 + 1):
				for id in by_chunk.get(cj * 64 + ci, []):
					var R: Dictionary = signs[id]
					if R.power == 2 or R.mute:
						continue
					var c: Vector3 = R.c
					var x := (c.x - c.z) * v.TW2 + v.cam_x
					var y := (c.x + c.z) * v.TH2 + v.cam_y - c.y * ky
					if x < -edge or x > v.W + edge or y < -edge or y > v.H + edge:
						continue
					seen.append(R)
					seen_dim.append(0.3 if _faded(R) else 1.0)
					if R.D.lit or R.power == 1:   # the nearest to the soldier hold the holes; the ones that have one, and landmarks, first
						cand.append([Vector2(c.x - p.x, c.z - p.y).length_squared() - (9.0 if hole_keep.has(id) else 0.0) - (6.0 if R.hero else 0.0), id])
		cand.sort()
		hole_keep.clear()
		for q in mini(HOLES[life], cand.size()):
			hole_keep[cand[q][1]] = true
			if not hole_s.has(cand[q][1]):
				hole_s[cand[q][1]] = 0.0
	for id in hole_s.keys():   # holes ease in and out, so the pick changing never pops
		var hv: float = hole_s[id] + (dt if hole_keep.has(id) else -dt) * 2.5
		if hv <= 0.0:
			hole_s.erase(id)
		else:
			hole_s[id] = minf(1.0, hv)


## a world point on screen (the 2D layers' pixels)
func _scr(p: Vector3) -> Vector2:
	var v: IsoView = m.v
	return Vector2((p.x - p.z) * v.TW2 + v.cam_x, (p.x + p.z) * v.TH2 + v.cam_y - p.y / V3.PXV * v.u)


## is the sign's building see-through now (a soldier behind it)? The world shader's rule for the buildings.
func _faded(R: Dictionary) -> bool:
	var a: Vector2 = R.anchor
	for p in sim.players.values():
		if not (p.alive or p.downed):
			continue
		var dd: float = a.x + a.y - (p.x + p.y)
		if dd > 0.0 and dd < 4.5 and absf((a.x - a.y) - (p.x - p.y)) < 2.6:
			return true
	return false


## the halos, added on over the night (one texture, so the layer draws them in one batch): a glow hugging each lit
## sign and, from life 2, its spill on the street. Sizes are in half-tile widths, worked out once (lit_meshes).
func glow(cv: CanvasItem) -> void:
	var v: IsoView = m.v
	var night := clampf((float(m.light.L) - 0.2) / 0.4, 0.0, 1.0)
	if night <= 0.0:
		return
	var t: float = sim.game.time
	var n := 0
	var cap: int = HALOS[life]
	var wide := life >= 2
	var tw := v.TW2
	var th := v.TH2
	var ky := v.u / V3.PXV
	var ox := v.cam_x
	var oy := v.cam_y
	for q in seen.size():
		if n >= cap:
			break
		var R: Dictionary = seen[q]
		var s: float = (flick(R, t) if R.D.lit else (0.55 if R.power == 1 else 0.0)) * night * seen_dim[q]
		if s <= 0.0:
			continue
		n += 1
		var c: Vector3 = R.c
		var hx: float = R.kx * tw
		var hy: float = R.ky * tw
		var col: Color = R.col
		cv.draw_texture_rect(glow_tex, Rect2((c.x - c.z) * tw + ox - hx, (c.x + c.z) * th + oy - c.y * ky - hy, hx * 2, hy * 2), false, Color(col.r, col.g, col.b, 0.5 * s))
		if wide:
			var g: Vector3 = R.ground
			var gw: float = R.kg * tw
			cv.draw_texture_rect(glow_tex, Rect2((g.x - g.z) * tw + ox - gw, (g.x + g.z) * th + oy - g.y * ky - gw * 0.5, gw * 2, gw), false, Color(col.r, col.g, col.b, 0.22 * s))


## the signs' holes in the night shade: main's _update_light calls this last, so every gameplay light is in before
## them and the 96-hole limit cuts decoration first
func holes(hole: Callable) -> void:
	var v: IsoView = m.v
	var t: float = sim.game.time
	for id in hole_s:
		var R: Dictionary = signs[id]
		var s := strength(R, t)
		if s > 0.0:
			hole.call(R.c.x, R.c.z, R.c.y / V3.PXV * v.u, v.TW2 * (0.9 + R.span.length() * 0.4), 0.55 * s * float(hole_s[id]))


## what the plan made, for the coverage sheet and the tests
func report() -> Dictionary:
	var kinds := {}
	var per := {}
	var power := [0, 0, 0]
	for R in signs:
		kinds[R.kind if not R.mute else "shop, no board"] = int(kinds.get(R.kind if not R.mute else "shop, no board", 0)) + 1
		per[R.did] = int(per.get(R.did, 0)) + 1
		power[R.power] += 1
	var rk := {}
	for r in roofs:
		rk[r[0]] = int(rk.get(r[0], 0)) + 1
	return {"signs": signs.size(), "kinds": kinds, "districts": per, "grid": power[0], "battery": power[1], "dead": power[2],
		"failing": signs.filter(func(R): return R.fail).size(), "heroes": signs.filter(func(R): return R.hero).map(func(R): return [R.did, R.word, R.tiles[0]]),
		"roofs": roofs.size(), "roof_kinds": rk, "skipped": skipped}
