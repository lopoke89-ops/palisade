class_name CasinoView
extends RefCounted
## THE PALISADE FALLS CASINO's floor (dev/src/js/06f-casino.js): a 16x16 room with blackjack, poker, roulette, craps
## and baccarat tables you walk up to, sixteen slot cabinets, a Plinko board, the bar and the cashier cage, lit by
## chandeliers and neon. No raiders, no building, no weapons. Everything is laid out from fixed numbers so the host
## and every guest build the same room. The tables themselves (cards, wheel, every shard) are the server's
## (pal_tables.gd and casino_ui.gd); here is the room, the seats and how it all looks.

const NAME := "THE PALISADE FALLS CASINO"
const MAP := {"name": NAME, "short": "Casino", "casino": true, "night": true, "hp": 1.0, "col": "#c2203a", "from": "", "bosses": [],
	"blurb": "Blackjack, poker, roulette, craps, baccarat, slots and Plinko for shards."}
const SPAWN := [[1.6, 9.4], [1.6, 10.6], [2.5, 9.5], [2.5, 10.5], [3.4, 9.4], [3.4, 10.6]]
const SLOTS_N := [2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
const SLOTS_W := [2, 3, 4, 5, 6, 7]
const PLINKO := {"tile": [15, 10], "at": [15.5, 10.5], "stand": [14.4, 10.5]}
const BAR := {"back": [[13, 0], [14, 0], [15, 0]], "counter": [[12, 2], [13, 2], [14, 2], [15, 2]], "stools": [[12.5, 3.25], [13.5, 3.25], [14.5, 3.25], [15.4, 3.25]], "keep": [14.0, 1.2]}
const CAGE := [[0, 13], [1, 13], [0, 14], [1, 14], [0, 15], [1, 15]]
const PILLARS := [[6, 8], [10, 11], [14, 12]]
const COUCH := [[12, 14], [13, 14]]
const LAMPS := [[4.5, 4.5], [8.5, 4], [12.5, 8], [4.5, 10], [9, 8.3], [8.6, 12.6], [4, 13.2], [13.2, 12.4], [13.8, 2.8]]
## the dealers, built like player looks
const LOOKS := {"vinnie": {"body": "#f1ede2", "vest": "#18161a", "pants": "#1c1b1f", "head": "#d9a77c", "hat": "#2a2420", "gl": 14, "nogun": true},
	"rosa": {"body": "#f4efe6", "vest": "#5a0f1c", "pants": "#1c1b1f", "head": "#b8805a", "hat": "#1a1210", "gl": 14, "nogun": true},
	"marco": {"body": "#efeadf", "vest": "#13261c", "pants": "#1c1b1f", "head": "#e2b996", "hat": "#5a4632", "gl": 14, "nogun": true},
	"keep": {"body": "#e9e2d2", "vest": "#2a1a12", "pants": "#1c1b1f", "head": "#c99a72", "hat": "#1a1210", "gl": 14, "nogun": true},
	"duke": {"body": "#ece6d8", "vest": "#1d3a24", "pants": "#1c1b1f", "head": "#8a5a3c", "hat": "#2a2420", "gl": 14, "nogun": true},
	"lena": {"body": "#f2ede4", "vest": "#3a1a4a", "pants": "#1c1b1f", "head": "#e8c4a0", "hat": "#3a2614", "gl": 14, "nogun": true}}
## a bot in a Hold'em seat (SLIM): drawn sitting there in a dealer's waistcoat
const BOT := {"body": "#d8d2c4", "vest": "#2a2a33", "pants": "#1c1b1f", "head": "#9a9aa6", "hat": "#33333c", "gl": 14, "nogun": true}
const RL_RED := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const RL_WHEEL := [0, 28, 9, 26, 30, 11, 7, 20, 32, 17, 5, 22, 34, 15, 3, 24, 36, 13, 1, 37, 27, 10, 25, 29, 12, 8, 19, 31, 18, 6, 21, 33, 16, 4, 23, 35, 14, 2]
const PK_MULT := [300, 90, 30, 15, 12, 6, 5, 6, 12, 15, 30, 90, 300]

static var TABLES: Array = []
static var MACHINES: Array = []
static var SEATS: Dictionary = {}   # seat code -> {t, k, pos, game, station} or {m, k, pos, game, station}: the registry


static func _ready_data() -> void:
	if not TABLES.is_empty():
		return
	var ring := func(cx: float, cy: float, rx: float, ry: float, angles: Array) -> Array:
		return angles.map(func(a): return [cx + rx * cos(deg_to_rad(a)), cy + ry * sin(deg_to_rad(a))])
	TABLES = [
		{"n": 1, "game": "bj", "name": "BLACKJACK", "col": "#ff4a6a", "solid": [[3, 4], [4, 4], [5, 4], [3, 3], [4, 3], [5, 3]], "c": [4.5, 4.55], "sign": [4.5, 4.2],
			"dealer": {"x": 4.5, "y": 3.55, "face": Vector2(0, 1), "name": "VINNIE", "look": "vinnie"}, "seats": [[2.7, 5.15], [3.55, 5.6], [4.5, 5.8], [5.45, 5.6], [6.3, 5.15]]},
		{"n": 2, "game": "he", "name": "POKER", "col": "#3ae0ff", "solid": [[7, 3], [8, 3], [9, 3], [7, 4], [8, 4], [9, 4], [8, 2]], "c": [8.5, 4.0], "sign": [8.5, 3.6],
			"dealer": {"x": 8.5, "y": 2.5, "face": Vector2(0, 1), "name": "ROSA", "look": "rosa"}, "seats": ring.call(8.5, 4.0, 2.05, 1.55, [20, 70, 110, 160, 200, 340])},
		{"n": 3, "game": "rl", "name": "ROULETTE", "col": "#ffb43a", "solid": [[11, 7], [12, 7], [13, 7], [11, 8], [12, 8], [13, 8], [14, 8], [14, 7]], "c": [12.5, 8.0], "sign": [12.3, 7.6], "wheel": [13.45, 8.0],
			"dealer": {"x": 14.5, "y": 7.9, "face": Vector2(-1, 0), "name": "MARCO", "look": "marco"}, "seats": [[11.2, 6.4], [12.2, 6.4], [13.2, 6.4], [11.2, 9.6], [12.2, 9.6], [13.2, 9.6]]},
		{"n": 4, "game": "cr", "name": "CRAPS", "col": "#4aff9a", "solid": [[4, 12], [5, 12], [6, 12], [7, 12], [4, 13], [5, 13], [6, 13], [7, 13]], "c": [6.0, 13.0], "sign": [6.0, 12.5],
			"dealer": {"x": 8.45, "y": 13.0, "face": Vector2(-1, 0), "name": "DUKE", "look": "duke"}, "seats": [[4.5, 11.55], [5.7, 11.55], [6.9, 11.55], [4.5, 14.45], [5.7, 14.45], [6.9, 14.45]]},
		{"n": 5, "game": "ba", "name": "BACCARAT", "col": "#c98aff", "solid": [[7, 7], [8, 7], [9, 7], [8, 6]], "c": [8.5, 7.3], "sign": [8.5, 6.95],
			"dealer": {"x": 8.5, "y": 6.55, "face": Vector2(0, 1), "name": "LENA", "look": "lena"}, "seats": ring.call(8.5, 7.25, 2.0, 1.25, [165, 135, 105, 75, 45, 15])}]
	MACHINES = []
	for k in SLOTS_N.size():
		var i: int = SLOTS_N[k]
		MACHINES.append({"id": "s%d" % (k + 1), "game": "sl", "name": "SLOTS", "at": [i + 0.5, 0.55], "face": "s", "stand": [i + 0.5, 1.4]})
	for k in SLOTS_W.size():
		var j: int = SLOTS_W[k]
		MACHINES.append({"id": "s%d" % (11 + k), "game": "sl", "name": "SLOTS", "at": [0.55, j + 0.5], "face": "e", "stand": [1.4, j + 0.5]})
	MACHINES.append({"id": "p1", "game": "pk", "name": "PLINKO", "at": PLINKO.at, "face": "w", "stand": PLINKO.stand})
	for k in MACHINES.size():
		MACHINES[k].code = 101 + k
	# seat codes (also on the wire): 0 standing, table n seat k -> n*10+k+1, machine k -> 101+k
	SEATS = {}
	for t in TABLES:
		for k in t.seats.size():
			SEATS[t.n * 10 + k + 1] = {"t": t, "k": k, "pos": t.seats[k], "game": t.game, "station": ""}
	for mc in MACHINES:
		SEATS[mc.code] = {"m": mc, "k": 0, "pos": mc.stand, "game": mc.game, "station": mc.id}


static func seat_of(code: int) -> Dictionary:
	_ready_data()
	return SEATS.get(code, {})


## the room as a map layout: solid furniture on a 16x16 floor; no stake, no piles, no raiders
static func lay() -> Dictionary:
	_ready_data()
	var N := 16
	var terr := PackedByteArray()
	terr.resize(N * N)
	var heights := PackedByteArray()
	heights.resize(N * N)
	var conn := PackedByteArray()
	conn.resize(N * N)
	var solid := func(q: Array) -> void:
		if q[0] >= 0 and q[1] >= 0 and q[0] < N and q[1] < N:
			terr[q[1] * N + q[0]] = PalMaps.T_BLDG
	for i in SLOTS_N:
		solid.call([i, 0])
	for j in SLOTS_W:
		solid.call([0, j])
	for q in BAR.back + BAR.counter + CAGE + PILLARS + COUCH:
		solid.call(q)
	for t in TABLES:
		for q in t.solid:
			solid.call(q)
	solid.call(PLINKO.tile)
	return {"N": N, "id": "casino", "map": MAP, "casino": true, "core": [-9, -9], "nodes": [], "ruins": [], "spawns": [], "raftAt": [], "ramps": [], "lamps": [],
		"o": {"ox": 0, "oy": 0, "xl": false}, "terr": terr, "heights": heights, "connectors": conn}


## who is in which seat, from every player's seat code; SLIM in a Hold'em seat counts too (from the table's view)
static func taken(sim: Sim, code: int, ui = null):
	for o in sim.players.values():
		if int(o.get("seat", 0)) == code:
			return o
	var q := seat_of(code)
	if q.has("t") and ui != null and ui.has_method("bot_at") and ui.bot_at(q.t.game, q.k):
		return {"bot": true}
	return null


## the free seat or machine you're standing next to, if any
static func seat_near(sim: Sim, p: Dictionary, ui = null) -> Dictionary:
	_ready_data()
	var best := {}
	var bd := 0.75
	for code in SEATS:
		var q: Dictionary = SEATS[code]
		var d := Vector2(p.x - q.pos[0], p.y - q.pos[1]).length()
		if d < bd and taken(sim, code, ui) == null:
			bd = d
			best = q.duplicate()
			best.code = code
	return best


# ---------------------------------------------------------------- the floor (painted once with the ground)

static func _runner(i: int, j: int) -> bool:
	return i <= 5 and (j == 9 or j == 10)


static func ground_col(m, i: int, j: int, h: float) -> Color:
	_ready_data()
	if _runner(i, j):
		return m.c("#8f1622")
	if i >= 12 and j <= 3:
		return m.c("#3b2617") if h < 0.5 else m.c("#352214")
	if i <= 2 and j >= 12:
		return m.c("#7d776c") if h < 0.5 else m.c("#77716a")
	for t in TABLES:
		if Vector2(i + 0.5 - t.c[0], j + 0.5 - t.c[1]).length() < 2.6:
			return m.c("#3a0a12") if h < 0.5 else m.c("#360910")
	return m.c("#4a0f17") if (i + j) % 2 else m.c("#450e15")


static func ground_detail(m, i: int, j: int) -> void:
	var v: IsoView = m.v
	var u := v.u
	if _runner(i, j):
		var y := j + (0.08 if j == 9 else 0.92)
		m.cv.draw_line(v.iso(i, y), v.iso(i + 1, y), Color(226 / 255.0, 180 / 255.0, 54 / 255.0, 0.55), 1.2 * u)
		return
	if i >= 12 and j <= 3:
		for t in [0.33, 0.66]:
			m.cv.draw_line(v.iso(i, j + t), v.iso(i + 1, j + t), Color(0, 0, 0, 0.25), u)
		return
	if i <= 2 and j >= 12:
		return
	# the casino carpet: a gold diamond on every tile, a small teal star where four tiles meet
	var pts := PackedVector2Array([v.iso(i + 0.5, j + 0.22), v.iso(i + 0.78, j + 0.5), v.iso(i + 0.5, j + 0.78), v.iso(i + 0.22, j + 0.5), v.iso(i + 0.5, j + 0.22)])
	m.cv.draw_polyline(pts, Color(214 / 255.0, 170 / 255.0, 70 / 255.0, 0.32), u)
	var mc := v.iso(i + 0.5, j + 0.5)
	m.oval(mc.x, mc.y, 1.6 * u, 0.8 * u, Color(214 / 255.0, 170 / 255.0, 70 / 255.0, 0.45))
	if (i + j) % 2 == 0:
		var k := v.iso(i, j)
		m.oval(k.x, k.y, 1.2 * u, 0.6 * u, Color(60 / 255.0, 170 / 255.0, 160 / 255.0, 0.35))


## the two back walls (north and west), the door, wainscot and gold trim
static func walls(m) -> void:
	var v: IsoView = m.v
	var u := v.u
	var N := 16
	var H := v.WH * 3.4
	var wall := func(P: Vector2, Q: Vector2, face: Color, trim: Color) -> void:
		m.quad(P, Q, m.up(Q, H), m.up(P, H), face)
		m.quad(P, Q, m.up(Q, H * 0.32), m.up(P, H * 0.32), m.c("#24130d"))
		for f in [0.32, 0.34, 0.97]:
			m.cv.draw_line(m.up(P, H * f), m.up(Q, H * f), trim, 1.6 * u)
	for i in N:
		var P := v.iso(i, 0)
		var Q := v.iso(i + 1, 0)
		wall.call(P, Q, m.c("#3a0d16") if i % 2 else m.c("#360c14"), Color(214 / 255.0, 170 / 255.0, 70 / 255.0, 0.7))
		var mid := P.lerp(Q, 0.5)
		m.cv.draw_line(Vector2(mid.x, mid.y - H * 0.36), Vector2(mid.x, mid.y - H * 0.95), Color(214 / 255.0, 170 / 255.0, 70 / 255.0, 0.18), u)
	for j in N:
		var P := v.iso(0, j)
		var Q := v.iso(0, j + 1)
		if j == 9 or j == 10:   # the door
			m.quad(P, Q, m.up(Q, H), m.up(P, H), m.c("#2a0a10"))
			m.quad(P.lerp(Q, 0.06), P.lerp(Q, 0.94), m.up(P.lerp(Q, 0.94), H * 0.72), m.up(P.lerp(Q, 0.06), H * 0.72), m.c("#0c1622"))
			for t in [0.06, 0.5, 0.94]:
				var a := P.lerp(Q, t)
				m.cv.draw_line(a, Vector2(a.x, a.y - H * 0.72), m.c("#d6aa46"), 1.8 * u)
			m.cv.draw_line(m.up(P.lerp(Q, 0.06), H * 0.72), m.up(P.lerp(Q, 0.94), H * 0.72), m.c("#d6aa46"), 1.8 * u)
			continue
		wall.call(P, Q, m.c("#300a12") if j % 2 else m.c("#2c0910"), Color(214 / 255.0, 170 / 255.0, 70 / 255.0, 0.6))
	var c0 := v.iso(0, 0)
	m.cv.draw_rect(Rect2(c0.x - 2 * u, c0.y - H, 4 * u, H), m.c("#b58a2e"))


# ---------------------------------------------------------------- the furniture (depth-sorted with the players)

## [depth, Callable] for everything in the room; the main draw list sorts them with people
static func items(m) -> Array:
	_ready_data()
	var out: Array = []
	var glow: Array = []
	m.cas_glow = glow
	for k in MACHINES.size():
		var mc: Dictionary = MACHINES[k]
		if mc.game == "sl":
			var kk := k
			out.append([mc.at[0] + mc.at[1] + 0.45, func(): slot(m, mc.at[0], mc.at[1], mc.face, kk, glow)])
	out.append([13 + 2 + 1.5, func(): bar(m)])
	out.append([BAR.keep[0] + BAR.keep[1], func(): Figure.person(m, BAR.keep[0], BAR.keep[1], _look("keep", Vector2(0, 1)))])
	for st in BAR.stools:
		out.append([st[0] + st[1], func(): stool(m, st[0], st[1])])
	out.append([PLINKO.at[0] + PLINKO.at[1] + 0.4, func(): plinko(m)])
	out.append([1 + 13 + 2, func(): cage(m)])
	for q in PILLARS:
		out.append([q[0] + q[1] + 1, func(): pillar(m, q[0], q[1])])
	out.append([12 + 14 + 1.2, func(): couch(m)])
	out.append([1.4 + 9, func(): ropes(m)])
	for t in TABLES:
		out.append([t.dealer.x + t.dealer.y, func(): Figure.person(m, t.dealer.x, t.dealer.y, _look(t.dealer.look, t.dealer.face))])
		out.append([t.c[0] + t.c[1] + 0.6, func(): table_body(m, t)])
		out.append([t.c[0] + t.c[1] + 0.65, func(): felt(m, t)])
		for k in t.seats.size():
			var sp: Array = t.seats[k]
			var code: int = t.n * 10 + k + 1
			var who = taken(m.sim, code, m.get("casino_ui"))
			out.append([sp[0] + sp[1] - 0.05, func(): chair(m, sp[0], sp[1]) if t.game == "he" else stool(m, sp[0], sp[1], "#7a1020" if who != null else "#a01830")])
			if who is Dictionary and who.get("bot", false):
				var d := Vector2(t.c[0] - sp[0], t.c[1] - sp[1]).normalized()
				var o: Dictionary = BOT.duplicate()
				o.merge({"aim": d, "walk": 0.0, "flash": false}, true)
				out.append([sp[0] + sp[1], func(): seated(m, sp[0], sp[1], func(): Figure.person(m, sp[0], sp[1], o))])
		glow.append(["sign", t.sign[0], t.sign[1], t.name, t.col, m.v.WH * 2.7])
	glow.append(["sign", 1.0, 14.5, "CASHIER", "#4aff9a", m.v.WH * 2.3])
	glow.append(["sign", 14.0, 1.4, "BAR ▽", "#ff6ad0", m.v.WH * 2.6])
	glow.append(["sign", 15.2, 10.5, "PLINKO", "#ffd24a", m.v.WH * 3.2])
	glow.append(["sign", 6.5, 0.6, "SLOTS", "#ff4a6a", m.v.WH * 3.6])
	return out


static func _look(id: String, face: Vector2) -> Dictionary:
	var o: Dictionary = LOOKS[id].duplicate()
	o.merge({"aim": face, "walk": 0.0, "flash": false}, true)
	return o


## a seated player: the lower half tucked behind the stool, a little lower
static func seated(m, x: float, y: float, draw: Callable) -> void:
	var c: Vector2 = m.iso(x, y)
	var u: float = m.v.u
	m.cv.draw_set_transform(Vector2(0, 5 * u))
	draw.call()
	m.cv.draw_set_transform(Vector2.ZERO)
	# the stool's seat drawn again in front hides the legs
	m.oval(c.x, c.y - 7 * u + 5 * u, 4.6 * u, 2.2 * u, m.c("#7a1020"))


static func slot(m, x: float, y: float, face: String, k: int, glow: Array) -> void:
	var v: IsoView = m.v
	var u := v.u
	var WH := v.WH
	var mc: Dictionary = MACHINES[k]
	var busy = taken(m.sim, mc.code)
	var t: float = m.sim.game.time
	var w := 0.36
	var fx: Array = [x - w, y - 0.3, x + w, y + 0.25] if face == "s" else [x - 0.3, y - w, x + 0.25, y + w]
	var B: Dictionary = m.box_r(fx[0], fx[1], fx[2], fx[3], 0, WH * 1.35, m.c("#2b2a30"), m.c("#1c1b20"), m.c("#151418"))
	var fr: Array = [B.D, B.C] if face == "s" else [B.B, B.C]
	var mid: Vector2 = fr[0].lerp(fr[1], 0.5)
	var scr: Vector2 = m.up(mid, WH * 0.92)
	var hue: String = ["#ff4a6a", "#3ae0ff", "#ffd24a", "#9a6aff", "#4aff9a"][k % 5]
	var on: bool = busy != null or sin(t * 3 + k * 1.7) > -0.2
	m.cv.draw_rect(Rect2(scr.x - 5 * u, scr.y - 4 * u, 10 * u, 7 * u), m.c("#0a0a10"))
	var line = m.casino_ui.slot_line(mc.id) if m.get("casino_ui") != null and m.casino_ui.has_method("slot_line") else null
	if line is Array and line.size() >= 3:
		var syms := ["#ff4a6a", "#ffd24a", "#3ae0ff", "#4aff9a", "#c98aff", "#f4f0e6", "#ff8a2a", "#d6aa46"]
		for r in 3:
			m.cv.draw_rect(Rect2(scr.x - 4 * u + r * 3 * u, scr.y - 1.5 * u, 2.4 * u, 2.4 * u), m.c(syms[int(line[r]) % syms.size()]))
	elif on:
		for r in 3:
			m.cv.draw_rect(Rect2(scr.x - 4 * u + r * 3 * u, scr.y - 3 * u + (int(floorf(t * (14.0 if busy != null else 6.0) + k + r * 2)) % 3) * 1.4 * u, 2.2 * u, 1.6 * u), m.c(hue))
	var top: Vector2 = m.up(mid, WH * 1.35)
	m.oval(top.x, top.y + u, 4.5 * u, 1.8 * u, m.c(hue))
	glow.append(["dot", scr.x, scr.y, v.TW2 * 0.45, hue, 0.5 if on else 0.25])
	m.cv.draw_rect(Rect2(scr.x + 5.5 * u, scr.y - 2 * u, 1.2 * u, 6 * u), m.c("#c9b27a"))


static func stool(m, x: float, y: float, top: String = "#7a1020") -> void:
	var u: float = m.v.u
	var c: Vector2 = m.iso(x, y)
	m.cv.draw_rect(Rect2(c.x - 0.8 * u, c.y - 7 * u, 1.6 * u, 7 * u), m.c("#2a1b10"))
	m.oval(c.x, c.y - 7 * u, 4.6 * u, 2.2 * u, m.c(top))
	m.oval(c.x, c.y, 3 * u, 1.2 * u, Color(0, 0, 0, 0.35))


static func chair(m, x: float, y: float) -> void:
	var u: float = m.v.u
	var c: Vector2 = m.iso(x, y)
	m.oval(c.x, c.y, 4 * u, 1.8 * u, Color(0, 0, 0, 0.35))
	m.box_r(x - 0.17, y - 0.17, x + 0.17, y + 0.17, m.v.WH * 0.22, m.v.WH * 0.08, m.c("#7a1020"), m.c("#5a0c18"), m.c("#4a0a14"))


static func _ellipse(m, cx: float, cy: float, rx: float, ry: float, z: float, a0: float = 0.0, a1: float = TAU, n: int = 28, closed: bool = true) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n + 1:
		var a := a0 + (a1 - a0) * k / n
		var p: Vector2 = m.iso(cx + cos(a) * rx, cy + sin(a) * ry)
		pts.append(Vector2(p.x, p.y - z))
	return pts


static func table_body(m, t: Dictionary) -> void:
	var v: IsoView = m.v
	var u := v.u
	var WH := v.WH
	var z := WH * 0.55
	var wood := [m.c("#1d120b"), m.c("#2a1a10"), m.c("#22150d")]
	var cream := Color(226 / 255.0, 200 / 255.0, 120 / 255.0, 0.45)
	match t.game:
		"bj", "ba":   # a half-moon: flat edge to the dealer (north), the curve to the players
			var cx: float = t.c[0]
			var cy: float = 3.8 if t.game == "bj" else 7.0
			m.box_r(cx - 1.4, cy - 0.05, cx + 1.4, cy + (1.15 if t.game == "bj" else 0.95), 0, z * 0.9, wood[0], wood[1], wood[2])
			var pts := _ellipse(m, cx, cy, 1.45, 1.15 if t.game == "bj" else 1.1, z, 0.0, PI, 20)
			m.cv.draw_colored_polygon(pts, m.c("#0f5a34" if t.game == "bj" else "#3a1450"))
			pts.append(pts[0])
			m.cv.draw_polyline(pts, m.c("#4a2a14"), 3.2 * u)
			if t.game == "bj":
				m.cv.draw_polyline(_ellipse(m, cx, cy, 0.95, 0.72, z, 0.0, PI, 20), cream, u)
				m.box_r(5.45, 3.85, 5.75, 4.1, z, WH * 0.12, m.c("#d8cfb8"), m.c("#a99e86"), m.c("#8c826c"))   # the shoe
			else:
				for q in [[0, Color(90 / 255.0, 170 / 255.0, 1, 0.5)], [1, Color(1, 90 / 255.0, 90 / 255.0, 0.5)], [2, Color(120 / 255.0, 230 / 255.0, 140 / 255.0, 0.5)]]:
					var cc: Vector2 = m.iso(7.85 + q[0] * 0.65, 7.75)
					m.oval(cc.x, cc.y - z, 3.2 * u, 1.6 * u, q[1])
		"he":
			m.box_r(7.1, 3.2, 9.9, 4.8, 0, z * 0.88, wood[0], wood[1], wood[2])
			var pts := _ellipse(m, 8.5, 4.0, 1.45, 0.95, z)
			m.cv.draw_colored_polygon(pts, m.c("#0f5a34"))
			m.cv.draw_polyline(pts, m.c("#5a3412"), 3 * u)
			m.cv.draw_polyline(_ellipse(m, 8.5, 4.0, 0.9 * v.TW2 / v.TW2 * 0.62, 0.6 * 0.62, z), Color(226 / 255.0, 200 / 255.0, 120 / 255.0, 0.4), u)
		"cr":   # a long tub: wooden rail, green felt, the pass line and the point boxes
			m.box_r(4.05, 12.05, 7.95, 13.95, 0, z * 0.9, wood[0], wood[1], wood[2])
			m.box_r(4.15, 12.15, 7.85, 13.85, z * 0.9, WH * 0.03, m.c("#0f5a34"), m.c("#0b4528"), m.c("#0a3d24"))
			var lc := Color(240 / 255.0, 230 / 255.0, 200 / 255.0, 0.55)
			for y in [12.45, 13.55]:
				m.cv.draw_line(m.up(m.iso(4.35, y), z), m.up(m.iso(7.65, y), z), lc, 0.9 * u)
			for q in 7:
				var x := 4.6 + q * 0.45
				m.cv.draw_line(m.up(m.iso(x, 12.6), z), m.up(m.iso(x, 13.0), z), lc, 0.9 * u)
			for e in [[4.05, 12.05, 7.95, 12.05], [7.95, 12.05, 7.95, 13.95], [7.95, 13.95, 4.05, 13.95], [4.05, 13.95, 4.05, 12.05]]:
				m.cv.draw_line(m.up(m.iso(e[0], e[1]), z + 2 * u), m.up(m.iso(e[2], e[3]), z + 2 * u), m.c("#4a2a14"), 2.4 * u)
		_:   # roulette: the layout's grid of numbers, the zero box at the wheel end, the wheel
			m.box_r(11.05, 7.15, 14.0, 8.85, 0, z * 0.88, wood[0], wood[1], wood[2])
			m.box_r(11.05, 7.15, 13.0, 8.85, z * 0.88, WH * 0.04, m.c("#0f5a34"), m.c("#0b4528"), m.c("#0a3d24"))
			var lc := Color(240 / 255.0, 230 / 255.0, 200 / 255.0, 0.5)
			for q in 13:
				var x := 11.15 + q * 0.15
				m.cv.draw_line(m.up(m.iso(x, 7.35), z), m.up(m.iso(x, 8.65), z), lc, 0.8 * u)
			for r in 4:
				var y := 7.35 + r * 1.3 / 3
				m.cv.draw_line(m.up(m.iso(11.15, y), z), m.up(m.iso(12.95, y), z), lc, 0.8 * u)
			for q in 12:
				for r in 3:
					var n := q * 3 + (3 - r)
					if RL_RED.has(n):
						var cc: Vector2 = m.iso(11.15 + q * 0.15 + 0.075, 7.35 + r * 1.3 / 3 + 0.21)
						m.oval(cc.x, cc.y - z, 1.3 * u, 0.7 * u, Color(200 / 255.0, 30 / 255.0, 40 / 255.0, 0.6))
			wheel(m, t, z)


## the roulette wheel: turns slowly when idle; spins and lands on the server's number (CasinoUI.wheel_state)
static func wheel(m, t: Dictionary, z: float) -> void:
	var v: IsoView = m.v
	var u := v.u
	var c: Vector2 = m.iso(t.wheel[0], t.wheel[1])
	var rx := v.TW2 * 0.62
	var ry := v.TH2 * 0.62
	var S: Dictionary = m.casino_ui.wheel_state() if m.get("casino_ui") != null and m.casino_ui.has_method("wheel_state") else {"rot": Time.get_ticks_msec() / 1000.0 * 0.25, "ball": null}
	m.oval(c.x, c.y - z - u, rx + 3 * u, ry + 2 * u, m.c("#3a220f"))
	var cz := Vector2(c.x, c.y - z - 2 * u)
	for k in 38:
		var a0: float = S.rot + k / 38.0 * TAU
		var pts := PackedVector2Array([cz])
		for s in 3:
			var a := a0 + TAU / 38.0 * s / 2.0
			pts.append(cz + Vector2(cos(a) * rx, sin(a) * ry))
		var n: int = RL_WHEEL[k]
		m.cv.draw_colored_polygon(pts, m.c("#0e7a3a" if n == 0 or n == 37 else ("#b8202c" if RL_RED.has(n) else "#141214")))
	m.oval(cz.x, cz.y, rx * 0.45, ry * 0.45, m.c("#5a3a14"))
	m.oval(cz.x, cz.y - u, rx * 0.12, ry * 0.12, m.c("#d6aa46"))
	if S.get("ball") != null:
		var b: Dictionary = S.ball
		m.cv.draw_circle(cz + Vector2(cos(b.a) * rx * b.r, sin(b.a) * ry * b.r), 1.5 * u, m.c("#f4f0e6"))


## what's on a table you can see: cards, chips, dice and the puck, from the table's view when there is one
static func felt(m, t: Dictionary) -> void:
	var view = m.casino_ui.view_for(t.game) if m.get("casino_ui") != null and m.casino_ui.has_method("view_for") else null
	if not (view is Dictionary) or view.is_empty():
		return
	var v: IsoView = m.v
	var u := v.u
	var z := v.WH * 0.55
	var card := func(x: float, y: float, cd) -> void:
		var p: Vector2 = m.iso(x, y)
		var r := Rect2(p.x - 2.4 * u, p.y - z - 6 * u, 4.8 * u, 6.6 * u)
		m.cv.draw_rect(r, m.c("#3a5ab0") if cd == null else m.c("#f4efe4"))
		m.cv.draw_rect(r, Color(0, 0, 0, 0.5), false, 0.6 * u)
		if cd != null:
			var suit := (int(cd) % 52) / 13
			m.cv.draw_rect(Rect2(p.x - 1.2 * u, p.y - z - 4.5 * u, 2.4 * u, 2.4 * u), m.c("#c02030") if suit == 1 or suit == 2 else m.c("#141214"))
	var chips := func(x: float, y: float, n: float) -> void:
		if not (n > 0):
			return
		var p: Vector2 = m.iso(x, y)
		var h := mini(8, 1 + floori(log(n + 1) / log(2)))
		for q in h:
			m.oval(p.x, p.y - z - q * 1.1 * u, 2.4 * u, 1.1 * u, m.c("#d6aa46") if q % 2 else m.c("#b8202c"))
	match t.game:
		"bj":
			var dl: Array = view.get("dealer", []) if view.get("dealer") is Array else []
			for q in dl.size():
				card.call(4.1 + q * 0.22, 3.95, dl[q])
			for p in view.get("players", []):
				if not (p is Dictionary) or int(p.get("seat", -1)) >= t.seats.size() or int(p.get("seat", -1)) < 0:
					continue
				var s: Array = t.seats[int(p.seat)]
				var cx: float = 4.5 + (s[0] - 4.5) * 0.62
				var cy: float = 3.85 + (s[1] - 3.85) * 0.62
				var tot := 0.0
				var hands: Array = p.get("hands", [])
				for hi in hands.size():
					var cards: Array = hands[hi].get("cards", [])
					for q in cards.size():
						card.call(cx - 0.1 + q * 0.16 + hi * 0.4, cy, cards[q])
					tot += float(hands[hi].get("bet", 0))
				chips.call(cx + 0.25, cy + 0.18, tot)
		"he":
			var bd: Array = view.get("board", []) if view.get("board") is Array else []
			for q in bd.size():
				card.call(8.05 + q * 0.22, 3.95, bd[q])
			chips.call(8.5, 4.35, float(view.get("pot", 0)))
			for p in view.get("players", []):
				if not (p is Dictionary) or p.get("folded", false) or int(p.get("seat", -1)) < 0 or int(p.get("seat", -1)) >= t.seats.size():
					continue
				var s: Array = t.seats[int(p.seat)]
				var cx: float = 8.5 + (s[0] - 8.5) * 0.55
				var cy: float = 4.0 + (s[1] - 4.0) * 0.55
				var cards: Array = p.get("cards", []) if p.get("cards") is Array else []
				for q in cards.size():
					card.call(cx - 0.08 + q * 0.16, cy, cards[q])
				chips.call(cx + 0.2, cy + 0.15, float(p.get("bet", 0)))
		"ba":
			for k in ["P", "B"]:
				var cards: Array = view.get(k, []) if view.get(k) is Array else []
				for q in cards.size():
					card.call((7.75 if k == "P" else 8.85) + q * 0.2, 7.25, cards[q])


static func plinko(m) -> void:
	var v: IsoView = m.v
	var u := v.u
	var x: float = PLINKO.at[0]
	var y: float = PLINKO.at[1]
	var z0 := v.WH * 0.2
	var H := v.WH * 2.6
	m.box_r(x - 0.45, y - 0.45, x + 0.45, y + 0.45, 0, z0, m.c("#2a1a10"), m.c("#3a2414"), m.c("#2e1c10"))
	var c: Vector2 = m.iso(x, y)
	var w := v.TW2 * 0.62
	var top := c.y - z0 - H
	m.cv.draw_rect(Rect2(c.x - w, top, w * 2, H), m.c("#121018"))
	m.cv.draw_rect(Rect2(c.x - w, top, w * 2, H), m.c("#d6aa46"), false, 1.6 * u)
	var rows := 12
	var dy := H * 0.8 / (rows + 1)
	for r in rows:
		for k in r + 1:
			m.cv.draw_rect(Rect2(c.x + (k - r / 2.0) * w * 1.7 / 12 - 0.5 * u, top + H * 0.06 + dy * (r + 1) - 0.5 * u, u, u), m.c("#e8e0cf"))
	var pw := w * 1.7 / 13
	for k in 13:
		var mv: float = PK_MULT[k] / 10.0
		m.cv.draw_rect(Rect2(c.x - w * 0.85 + k * pw + 0.3 * u, top + H * 0.9, pw - 0.6 * u, H * 0.07), m.c("#ff4a6a" if mv >= 9 else ("#ffb43a" if mv >= 3 else ("#4aff9a" if mv >= 1 else "#3a8aff"))))
	var ball = m.casino_ui.plinko_ball() if m.get("casino_ui") != null and m.casino_ui.has_method("plinko_ball") else null
	if ball is Dictionary and ball.get("path") is Array:
		var q: Array = ball.path
		var f := minf(rows, float(ball.get("step", 0.0)))
		var r := floori(f)
		var fr := f - r
		var col := 0
		for i in mini(r, q.size()):
			col += int(q[i])
		var nx := col + (int(q[r]) if r < q.size() else 0)
		var peg_x := func(rr: int, kk: int) -> float: return c.x + (kk - rr / 2.0) * w * 1.7 / 12
		var peg_y := func(rr: int) -> float: return top + H * 0.06 + dy * (rr + 1)
		var px: float = (c.x - w * 0.85 + (col + 0.5) * pw) if r >= rows else peg_x.call(r, col) + (peg_x.call(r + 1, nx) - peg_x.call(r, col)) * fr
		var py: float = (top + H * 0.92) if r >= rows else peg_y.call(r) + (peg_y.call(r + 1) - peg_y.call(r)) * fr - dy * 0.4 * sin(fr * PI)
		m.cv.draw_circle(Vector2(px, py), 1.6 * u, m.c("#fff3d6"))


static func bar(m) -> void:
	var v: IsoView = m.v
	var u := v.u
	var WH := v.WH
	for q in BAR.back:
		m.box_r(q[0] + 0.05, q[1] + 0.05, q[0] + 0.95, q[1] + 0.7, 0, WH * 1.6, m.c("#2a1a10"), m.c("#3a2414"), m.c("#2e1c10"))
	for q in 9:
		var c: Vector2 = m.iso(13.2 + q * 0.3, 0.45)
		m.cv.draw_rect(Rect2(c.x - u, c.y - WH * 1.25, 2 * u, 5 * u), m.c(["#3ae08a", "#d6aa46", "#9a2a2a", "#5ab0ff"][q % 4]))
	m.box_r(12.05, 2.15, 16, 2.85, 0, WH * 0.85, m.c("#5a3418"), m.c("#3a2212"), m.c("#2e1a0e"))
	m.box_r(12, 2.1, 16, 2.9, WH * 0.85, WH * 0.06, m.c("#d6aa46"), m.c("#a8832f"), m.c("#8a6a26"))


static func cage(m) -> void:
	var v: IsoView = m.v
	var u := v.u
	var WH := v.WH
	m.box_r(0.05, 13.05, 2, 16, 0, WH * 1.1, m.c("#4a3a26"), m.c("#3a2c1c"), m.c("#2e2316"))
	for q in 9:
		var a: Vector2 = m.iso(2, 13.15 + q * 0.32)
		m.cv.draw_line(Vector2(a.x, a.y - WH * 1.1), Vector2(a.x, a.y - WH * 1.85), Color(214 / 255.0, 170 / 255.0, 70 / 255.0, 0.8), 1.1 * u)
	m.box_r(0.05, 13.05, 2, 16, WH * 1.85, WH * 0.12, m.c("#d6aa46"), m.c("#a8832f"), m.c("#8a6a26"))


static func pillar(m, i: int, j: int) -> void:
	var WH: float = m.v.WH
	m.box_r(i + 0.18, j + 0.18, i + 0.82, j + 0.82, 0, WH * 0.25, m.c("#b58a2e"), m.c("#7e6222"), m.c("#66501c"))
	m.box_r(i + 0.25, j + 0.25, i + 0.75, j + 0.75, WH * 0.25, WH * 2.95, m.c("#d6aa46"), m.c("#9c7a2a"), m.c("#7e6222"))


static func couch(m) -> void:
	var WH: float = m.v.WH
	m.box_r(12.1, 14.15, 13.9, 14.85, 0, WH * 0.35, m.c("#6a1424"), m.c("#4a0e19"), m.c("#3c0b14"))
	m.box_r(12.1, 14.6, 13.9, 14.85, WH * 0.35, WH * 0.4, m.c("#7a1828"), m.c("#5a1220"), m.c("#4a0e19"))


static func ropes(m) -> void:
	var v: IsoView = m.v
	var u := v.u
	var WH := v.WH
	for q in 5:
		for y in [8.75, 11.25]:
			var x := 1.4 + q * 1.1
			var c: Vector2 = m.iso(x, y)
			m.cv.draw_rect(Rect2(c.x - 0.8 * u, c.y - WH * 0.75, 1.6 * u, WH * 0.75), m.c("#d6aa46"))
			m.oval(c.x, c.y - WH * 0.75, 1.6 * u, u, m.c("#e8c86a"))
			if q < 4:
				var d: Vector2 = m.iso(x + 1.1, y)
				var a := Vector2(c.x, c.y - WH * 0.62)
				var b := Vector2(d.x, d.y - WH * 0.62)
				var mid := Vector2((a.x + b.x) / 2, (c.y + d.y) / 2 - WH * 0.4 + WH * 0.31)
				var pts := PackedVector2Array()
				for s in 9:
					var f := s / 8.0
					pts.append(a.lerp(mid, f).lerp(mid.lerp(b, f), f))
				m.cv.draw_polyline(pts, m.c("#8a1020"), 1.8 * u)


# ---------------------------------------------------------------- light: neon and bulbs after the lighting, light pools

static var _dots := {}


static func _dot(col: String) -> Texture2D:
	if _dots.has(col):
		return _dots[col]
	var g := Gradient.new()
	var c := Color(col)
	g.set_color(0, Color(c, 0.85))
	g.set_color(1, Color(c, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	_dots[col] = t
	return t


static var _sign_font: Font


## neon signs over the tables, bulbs and slot screens, and the marquee: drawn on top so the dark room makes them glow
static func glow(m, cv: CanvasItem) -> void:
	var v: IsoView = m.v
	var u := v.u
	var t: float = m.sim.game.time
	if _sign_font == null:
		_sign_font = load("res://fonts/big-shoulders-stencil-display-900.woff2")
	for q in m.get("cas_glow") if m.get("cas_glow") is Array else []:
		if q[0] == "dot":
			cv.draw_texture_rect(_dot(q[4]), Rect2(q[1] - q[3], q[2] - q[3], q[3] * 2, q[3] * 2), false, Color(1, 1, 1, q[5]))
			continue
		var c: Vector2 = m.iso(q[1], q[2])
		var y: float = c.y - q[5]
		var fl := 0.35 if sin(t * 23 + q[1] * 3) > 0.985 else 1.0   # a flicker now and then
		cv.draw_texture_rect(_dot(q[4]), Rect2(c.x - v.TW2 * 1.6, y - v.TW2 * 0.8, v.TW2 * 3.2, v.TW2 * 1.6), false, Color(1, 1, 1, 0.55 * fl))
		var fs := roundi(9 * u)
		var tw := _sign_font.get_string_size(q[3], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		cv.draw_string(_sign_font, Vector2(c.x - tw / 2, y + 3 * u), q[3], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(q[4], fl))
		cv.draw_string(_sign_font, Vector2(c.x - tw / 2, y + 3 * u - 0.4 * u), q[3], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Color("#fff6e8"), 0.9 * fl))
	# the marquee on the north wall: the casino's name in lights, bulbs chasing round it
	var A := v.iso(4.2, 0)
	var B := v.iso(11.8, 0)
	var H := v.WH * 3.4
	var mid := A.lerp(B, 0.5)
	var top := mid.y - H * 0.86
	var hw := (B.x - A.x) * 0.5
	cv.draw_texture_rect(_dot("#ffb43a"), Rect2(mid.x - hw * 1.1, top - v.WH * 0.9, hw * 2.2, v.WH * 2.2), false, Color(1, 1, 1, 0.35))
	var put := func(text: String, size: int, yy: float, col: String) -> void:
		var w := _sign_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		cv.draw_string(_sign_font, Vector2(mid.x - w / 2, yy), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col))
	put.call("THE PALISADE FALLS", roundi(10.5 * u), top + v.WH * 0.15, "#ff8a2a")
	put.call("THE PALISADE FALLS", roundi(10.5 * u), top + v.WH * 0.15 - 0.5 * u, "#fff3d6")
	put.call("★ CASINO ★", roundi(8 * u), top + v.WH * 0.62, "#ff4a6a")
	var n := 28
	var ph := floori(t * 10)
	for k in n:
		var f := float(k) / n
		var on := (k + ph) % 4 == 0
		cv.draw_circle(Vector2(A.x + (B.x - A.x) * f, A.y + (B.y - A.y) * f - H * 0.97), 1.3 * u, Color(Color("#fff0b0") if on else Color("#c8902a"), 1.0 if on else 0.35))


## light pools: chandeliers, a lamp over every table, the slots, the bar and the cage
static func lights(m, hole: Callable) -> void:
	_ready_data()
	var v: IsoView = m.v
	for q in LAMPS:
		hole.call(q[0], q[1], 0.0, v.TW2 * 3.1, 0.88)
	for t in TABLES:
		hole.call(t.c[0], t.c[1], 0.0, v.TW2 * 2.4, 0.95)
	for i in SLOTS_N:
		hole.call(i + 0.5, 0.9, 0.0, v.TW2 * 1.1, 0.5)
	for j in SLOTS_W:
		hole.call(0.9, j + 0.5, 0.0, v.TW2 * 1.1, 0.5)
	hole.call(1.0, 14.5, 0.0, v.TW2 * 2.0, 0.7)
	hole.call(PLINKO.at[0] - 0.4, PLINKO.at[1], 0.0, v.TW2 * 1.6, 0.8)
	hole.call(8.0, 0.6, v.WH * 2.4, v.TW2 * 3.6, 0.7)
