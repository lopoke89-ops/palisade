class_name CasinoDress
extends RefCounted
## The casino's set dressing (the Living World work order): a lit sign over the cashier's cage (the room's landmark),
## signs over the bar and the west slot bank, a working bar and cashier's counter, a staff door, sconces and posters.
## Visual only, and nothing new stands or lies on the floor: every piece hangs on the two walls or sits on top of
## furniture that is solid already (the cage, the bar's counter and back shelf). Seats, tables, cards, bets, the red
## carpet and the way in are left alone. All of it joins the room's own mesh: no extra draws, nothing
## per frame. Every name is made up for PALISADE.
## Quality3D.life: 0 off (the room as it was), 1 the lit signs, 2 + the counters, door, sconces and posters,
## 3 + the small stuff.

const V3 = preload("res://scripts/view3d/view3d.gd")
const GOLD := "#d6aa46"


static func _pt(F: Array, u: float, y: float, d: float) -> Vector3:
	return F[0] + F[1] * u + Vector3(0, y, 0) + F[2] * d


static func _fq(g: V3Mesh, F: Array, u0: float, u1: float, y0: float, y1: float, d: float, col: Color) -> void:
	g.quad(_pt(F, u0, y0, d), _pt(F, u1, y0, d), _pt(F, u1, y1, d), _pt(F, u0, y1, d), col)


## a lit tube's colour (the world shader reads the alpha as glow)
static func tube(h: String) -> Color:
	var col := Color(h)
	return Color(col.r, col.g, col.b, 0.45)


## a word in 3x5 block letters, centred on uc, its foot at y0
static func _word(g: V3Mesh, F: Array, word: String, uc: float, y0: float, cell: float, d: float, col: Color) -> void:
	var u := uc - (4 * word.length() - 1) * cell * 0.5
	for ch in word:
		var G: Array = CityDress.GLYPH.get(ch, CityDress.GLYPH[" "])
		for r in 5:
			var bits: int = G[r]
			for q in 3:
				if bits & (4 >> q):
					_fq(g, F, u + q * cell, u + (q + 1) * cell, y0 + (4 - r) * cell, y0 + (5 - r) * cell, d, col)
		u += 4 * cell


## a sign on a wall: a dark board, the word in tubes, a tube under it
static func _sign(g: V3Mesh, F: Array, word: String, uc: float, yc: float, cell: float, ink: String, line: String) -> void:
	var w := (4 * word.length() - 1) * cell
	var hb := 5 * cell
	_fq(g, F, uc - w * 0.5 - 0.1, uc + w * 0.5 + 0.1, yc - hb * 0.5 - 0.1, yc + hb * 0.5 + 0.08, 0.012, Color("#120a0c"))
	for e in [yc - hb * 0.5 - 0.1, yc + hb * 0.5 + 0.07]:
		_fq(g, F, uc - w * 0.5 - 0.1, uc + w * 0.5 + 0.1, e, e + 0.012, 0.016, Color(GOLD))
	_word(g, F, word, uc, yc - hb * 0.5, cell, 0.018, tube(ink))
	_fq(g, F, uc - w * 0.5, uc + w * 0.5, yc - hb * 0.5 - 0.06, yc - hb * 0.5 - 0.035, 0.018, tube(line))


static func _sconce(g: V3Mesh, F: Array, u: float, y: float) -> void:
	g.bar(_pt(F, u, y - 0.08, 0.0), _pt(F, u, y - 0.02, 0.07), 0.01, Color(GOLD))
	var a := _pt(F, u - 0.045, y, 0.03)
	var b := _pt(F, u + 0.045, y + 0.13, 0.11)
	var lit := Color(1.0, 0.86, 0.6, 0.25)
	g.box(minf(a.x, b.x), minf(a.z, b.z), maxf(a.x, b.x), maxf(a.z, b.z), a.y, b.y, lit, lit, lit)


static func _poster(g: V3Mesh, F: Array, u0: float, u1: float, y0: float, y1: float, back: String, mark: String, suit: int) -> void:
	_fq(g, F, u0 - 0.03, u1 + 0.03, y0 - 0.03, y1 + 0.03, 0.01, Color(GOLD).darkened(0.15))
	_fq(g, F, u0, u1, y0, y1, 0.014, Color(back))
	var c := _pt(F, (u0 + u1) * 0.5, (y0 + y1) * 0.5, 0.018)
	var ax: Vector3 = F[1]
	var r := (u1 - u0) * 0.3
	var col := Color(mark)
	if suit == 0:   # a diamond
		g.tri(c + Vector3(0, r * 1.3, 0), c + ax * r, c - ax * r, col, F[2])
		g.tri(c - Vector3(0, r * 1.3, 0), c - ax * r, c + ax * r, col, F[2])
	else:   # a spade: a point over a bar
		g.tri(c + Vector3(0, r * 1.3, 0), c + ax * r - Vector3(0, r * 0.3, 0), c - ax * r - Vector3(0, r * 0.3, 0), col, F[2])
		g.tri(c - Vector3(0, r * 0.2, 0), c + ax * r * 0.35 - Vector3(0, r * 1.2, 0), c - ax * r * 0.35 - Vector3(0, r * 1.2, 0), col, F[2])


## everything, into the room's mesh
static func build(g: V3Mesh, life: int) -> void:
	if life <= 0:
		return
	var WH := V3.WALL_H
	var H := WH * 3.4
	var north := [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)]   # u = x
	var west := [Vector3(0, 0, 16), Vector3(0, 0, -1), Vector3(1, 0, 0)]   # u = 16 - z: left to right on screen
	g.anchor = Vector2(-9999, -9999)
	# the landmark: CHIPS in gold tubes on the cage's canopy (the room's own floating labels already name each place)
	var top := WH * 1.97
	g.box(1.88, 13.3, 2.0, 15.7, top, top + WH * 0.5, Color("#1c1210"), Color("#120a0c"), Color("#120a0c"))
	var cage := [Vector3(2.0, 0, 15.7), Vector3(0, 0, -1), Vector3(1, 0, 0)]
	_word(g, cage, "CHIPS", 1.2, top + WH * 0.5 * 0.5 - 0.14, 0.056, 0.006, tube("#ffd24a"))
	_fq(g, cage, 0.1, 2.3, top + 0.02, top + 0.04, 0.006, tube("#ff4a8a"))
	_sign(g, north, "BAR", 14.5, H * 0.66, 0.085, "#3ae0ff", "#ff4a8a")
	_sign(g, west, "LUCKY 7", 11.0, H * 0.66, 0.08, "#ffd24a", "#3ae0ff")
	# more words where the room's floating labels leave the walls bare
	_sign(g, north, "JACKPOT", 3.2, H * 0.66, 0.062, "#ff4a8a", "#ffd24a")
	_sign(g, north, "777", 11.4, H * 0.66, 0.08, "#ffd24a", "#ff4a8a")
	_sign(g, north, "WIN", 1.0, H * 0.84, 0.06, "#4aff9a", "#ffd24a")
	_sign(g, west, "WELCOME", 6.0, H * 0.85, 0.055, "#3ae0ff", "#ff4a8a")
	_sign(g, west, "OPEN LATE", 15.0, H * 0.8, 0.045, "#ff4a8a", "#3ae0ff")
	for k in 4:   # a row of tube diamonds over the cage
		var dc := _pt(west, 0.9 + k * 0.42, H * 0.84, 0.02)
		var dcol := tube("#ff4a8a" if k % 2 == 0 else "#3ae0ff")
		var pts := [dc + Vector3(0, 0.15, 0), dc + Vector3(0, 0, -0.11), dc - Vector3(0, 0.15, 0), dc + Vector3(0, 0, 0.11)]
		for q in 4:
			g.bar(pts[q], pts[(q + 1) % 4], 0.011, dcol)
	for e in [5.03, 6.97]:   # the way in, outlined in tube
		g.bar(_pt(west, e, 0, 0.02), _pt(west, e, H * 0.74, 0.02), 0.012, tube("#3ae0ff"))
	g.bar(_pt(west, 5.03, H * 0.74, 0.02), _pt(west, 6.97, H * 0.74, 0.02), 0.012, tube("#3ae0ff"))
	for n in CasinoView.PILLARS.size():   # a band of tube round each pillar, high and low
		var pq: Array = CasinoView.PILLARS[n]
		for py in [WH * 0.42, WH * 2.75]:
			var pc := tube("#ff4a8a" if n % 2 == 0 else "#3ae0ff")
			g.box(pq[0] + 0.235, pq[1] + 0.235, pq[0] + 0.765, pq[1] + 0.765, py, py + 0.035, pc, pc, pc)
	# each table glows underneath in its own colour (the body's two near sides)
	CasinoView._ready_data()
	for tb in CasinoView.TABLES:
		var B: Array = _body(tb)
		var uc := tube(str(tb.col))
		g.quad(Vector3(B[0] + 0.08, 0.05, B[3] + 0.004), Vector3(B[2] - 0.08, 0.05, B[3] + 0.004), Vector3(B[2] - 0.08, 0.085, B[3] + 0.004), Vector3(B[0] + 0.08, 0.085, B[3] + 0.004), uc)
		g.quad(Vector3(B[2] + 0.004, 0.05, B[3] - 0.08), Vector3(B[2] + 0.004, 0.05, B[1] + 0.08), Vector3(B[2] + 0.004, 0.085, B[1] + 0.08), Vector3(B[2] + 0.004, 0.085, B[3] - 0.08), uc)
	if life < 2:
		return
	_tables(g, life)
	# the cashier's counter: chip racks, a cash tray, a green lamp
	var cy := WH * 1.1
	var chips := ["#e8e0cf", "#b8202c", "#2a6a3a", "#1c2a5a", "#141214"]
	for q in 4:
		var z := 13.35 + q * 0.6
		g.box(1.5, z, 1.92, z + 0.34, cy, cy + 0.025, Color("#3a2414"), Color("#2a1a10"), Color("#22150d"))
		if life >= 3:
			for k in 5:
				g.box(1.54 + k * 0.075, z + 0.04, 1.6 + k * 0.075, z + 0.3, cy + 0.025, cy + 0.06, Color(chips[(k + q) % 5]), Color(chips[(k + q) % 5]).darkened(0.2), Color(chips[(k + q) % 5]).darkened(0.3))
	g.prism(1.2, 13.55, 0.03, cy, cy + 0.14, Color(GOLD), Color(GOLD), 6)
	var shade := Color(0.2, 0.62, 0.38, 0.2)
	g.box(1.08, 13.47, 1.32, 13.63, cy + 0.14, cy + 0.19, shade, shade, shade)
	g.box(0.5, 14.2, 1.1, 14.7, cy, cy + 0.05, Color("#2a2c2e"), Color("#1c1e20"), Color("#151718"))
	# the bar: a mirror behind the bottles, a till, taps, glasses and a mat on the counter
	_fq(g, north, 13.1, 15.9, WH * 1.85, H * 0.5, 0.008, Color("#17222b"))
	for e in [WH * 1.85, H * 0.5]:
		g.bar(_pt(north, 13.1, e, 0.012), _pt(north, 15.9, e, 0.012), 0.012, Color(GOLD))
	var by := WH * 0.91
	g.box(12.25, 2.3, 12.6, 2.62, by, by + 0.17, Color("#2a2c2e"), Color("#1c1e20"), Color("#151718"))
	g.box(12.28, 2.62, 12.57, 2.63, by + 0.09, by + 0.15, Color("#3ae08a"), Color("#3ae08a"), Color("#3ae08a"))
	g.box(13.3, 2.42, 13.9, 2.58, by, by + 0.05, Color("#5b6063"), Color("#4a4f52"), Color("#3d4144"))
	for k in 3:
		g.bar(Vector3(13.42 + k * 0.18, by + 0.05, 2.5), Vector3(13.42 + k * 0.18, by + 0.2, 2.56), 0.012, Color(GOLD))
		g.box(13.4 + k * 0.18, 2.54, 13.44 + k * 0.18, 2.58, by + 0.2, by + 0.27, Color(["#b8202c", "#e8e0cf", "#1c2a5a"][k]), Color(["#b8202c", "#e8e0cf", "#1c2a5a"][k]), Color(["#b8202c", "#e8e0cf", "#1c2a5a"][k]).darkened(0.2))
	g.quad(Vector3(14.8, by + 0.003, 2.3), Vector3(14.8, by + 0.003, 2.7), Vector3(15.6, by + 0.003, 2.7), Vector3(15.6, by + 0.003, 2.3), Color("#5a0f1c"))
	for k in 6:
		g.prism(14.2 + (k % 3) * 0.09, 2.36 + (k / 3) * 0.09, 0.028, by, by + 0.075, Color("#b8c8d0"), Color("#dfe8ec"), 6)
	if life >= 3:   # two shelves of bottles on the back bar's face, a bowl of lemons
		var back := [Vector3(13.0, 0, 0.7), Vector3(1, 0, 0), Vector3(0, 0, 1)]
		var glass := ["#3ae08a", "#d6aa46", "#9a2a2a", "#5ab0ff", "#e8e0cf"]
		for row in 2:
			var sy := WH * (0.55 + row * 0.5)
			g.bar(_pt(back, 0.1, sy, 0.02), _pt(back, 2.9, sy, 0.02), 0.012, Color(GOLD))
			for k in 12:
				var u := 0.2 + k * 0.225
				var a := _pt(back, u, sy + 0.012, 0.004)
				g.box(a.x, a.z, a.x + 0.05, a.z + 0.035, a.y, a.y + 0.11 + 0.03 * ((k + row) % 3), Color(glass[(k * 2 + row) % 5]), Color(glass[(k * 2 + row) % 5]), Color(glass[(k * 2 + row) % 5]).darkened(0.25))
		g.prism(15.2, 2.5, 0.07, by + 0.003, by + 0.05, Color("#3a2414"), Color("#d8c84a"), 8)
	# the staff door, between the slots and the bar
	_fq(g, north, 12.2, 12.8, 0, H * 0.3, 0.008, Color("#1a0d0a"))
	for e in [12.2, 12.8]:
		g.bar(_pt(north, e, 0, 0.012), _pt(north, e, H * 0.3, 0.012), 0.012, Color(GOLD))
	g.bar(_pt(north, 12.2, H * 0.3, 0.012), _pt(north, 12.8, H * 0.3, 0.012), 0.012, Color(GOLD))
	_fq(g, north, 12.42, 12.58, H * 0.2, H * 0.26, 0.012, Color("#0c1622"))
	_fq(g, north, 12.7, 12.74, H * 0.13, H * 0.15, 0.014, Color(GOLD))
	_fq(g, north, 12.28, 12.72, H * 0.37, H * 0.37 + 0.13, 0.012, Color("#e8e0cf"))
	_word(g, north, "STAFF", 12.5, H * 0.37 + 0.02, 0.018, 0.016, Color("#1a0d0a"))
	# sconces in the corners and by the door; posters either side of the way in
	for u in [0.5, 1.5, 12.5]:
		_sconce(g, north, u, H * 0.52)
	for u in [3.5, 4.5, 14.5, 15.5]:
		_sconce(g, west, u, H * 0.52)
	_poster(g, west, 3.75, 4.25, H * 0.38, H * 0.62, "#3a0d16", "#d6aa46", 0)
	_poster(g, west, 7.25, 7.75, H * 0.38, H * 0.62, "#10202a", "#e8e0cf", 1)
	_poster(g, north, 0.75, 1.25, H * 0.38, H * 0.62, "#1f2a14", "#d6aa46", 1)


## a table's body on the floor, as V3Scenery._table builds it: [x0, z0, x1, z1]
static func _body(tb: Dictionary) -> Array:
	match str(tb.game):
		"bj":
			return [float(tb.c[0]) - 1.4, 3.75, float(tb.c[0]) + 1.4, 4.95]
		"ba":
			return [float(tb.c[0]) - 1.4, 6.95, float(tb.c[0]) + 1.4, 7.95]
		"he":
			return [7.1, 3.2, 9.9, 4.8]
		"cr":
			return [4.05, 12.05, 7.95, 13.95]
	return [11.05, 7.15, 14.0, 8.85]


## a stack of chips
static func _chips(g: V3Mesh, x: float, z: float, y: float, n: int, col: Color) -> void:
	g.prism(x, z, 0.034, y, y + n * 0.012, col.darkened(0.15), col.lightened(0.15), 8)
	g.prism(x, z, 0.0345, y + n * 0.006 - 0.002, y + n * 0.006 + 0.002, Color("#e8e0cf"), Color("#e8e0cf"), 8)


## what a dealer works with, on the dealer's side of each table: the trays, shoes and stacks stay off the felt where
## cards and bets are laid, and the craps table gets its padded wall
static func _tables(g: V3Mesh, life: int) -> void:
	var WH := V3.WALL_H
	var z := WH * 0.55
	var cols := [Color("#e8e0cf"), Color("#b8202c"), Color("#2a6a3a"), Color("#1c2a5a"), Color("#141214"), Color("#c98aff")]
	var tray := func(x0: float, z0: float, x1: float, y: float) -> void:   # a dealer's chip tray along a table's edge
		g.box(x0, z0, x1, z0 + 0.15, y, y + 0.022, Color("#2a1a10"), Color("#1d120b"), Color("#1d120b"))
		if life >= 3:
			var n := int((x1 - x0 - 0.04) / 0.075)
			for k in n:
				var cc: Color = cols[k % 5]
				g.box(x0 + 0.03 + k * 0.075, z0 + 0.025, x0 + 0.09 + k * 0.075, z0 + 0.125, y + 0.022, y + 0.05, cc, cc.darkened(0.2), cc.darkened(0.3))
	for tb in CasinoView.TABLES:
		match str(tb.game):
			"bj":
				tray.call(4.1, 3.84, 4.9, z)
				g.box(3.28, 3.86, 3.5, 4.08, z, z + 0.07, Color("#8a1424"), Color("#6a1020"), Color("#560d1a"))   # the discard holder
			"ba":
				tray.call(8.1, 7.04, 8.9, z)
				g.box(9.45, 7.05, 9.75, 7.3, z, z + WH * 0.12, Color("#d8cfb8"), Color("#a99e86"), Color("#8c826c"))   # the shoe
				g.box(7.25, 7.05, 7.47, 7.27, z, z + 0.07, Color("#8a1424"), Color("#6a1020"), Color("#560d1a"))
			"he":
				tray.call(8.15, 3.12, 8.85, z)
				var line := Color("#0f5a34").lerp(Color("#e8dcb8"), 0.4)
				for q in 28:   # the betting line, printed on the felt
					var a0 := TAU * q / 28
					var a1 := TAU * (q + 1) / 28
					g.bar(Vector3(8.5 + cos(a0) * 1.05, z + 0.003, 4.0 + sin(a0) * 0.62), Vector3(8.5 + cos(a1) * 1.05, z + 0.003, 4.0 + sin(a1) * 0.62), 0.005, line)
			"cr":
				var zt := z * 0.9 + WH * 0.03
				var pad := Color("#3a2212")
				for e in [[4.05, 12.05, 7.95, 12.13], [4.05, 13.87, 7.95, 13.95], [4.05, 12.13, 4.13, 13.87], [7.87, 12.13, 7.95, 13.87]]:
					g.box(e[0], e[1], e[2], e[3], zt, z + 0.07, pad.lightened(0.12), pad, pad.darkened(0.15))
				for q in 12:   # the far wall's diamond rubber, where the dice have to hit
					var x := 4.3 + q * 0.3
					g.quad(Vector3(x, zt + 0.02, 12.134), Vector3(x + 0.1, zt + 0.045, 12.134), Vector3(x, zt + 0.07, 12.134), Vector3(x - 0.1, zt + 0.045, 12.134), Color("#0b4528"))
				g.box(7.56, 12.62, 7.84, 13.38, zt, zt + 0.02, Color("#2a1a10"), Color("#1d120b"), Color("#1d120b"))   # the bank
				for k in 5:
					_chips(g, 7.7, 12.72 + k * 0.14, zt + 0.02, 4 + (k * 3) % 5, cols[k % 6])
			_:
				var zr := z * 0.88
				for k in 6:   # the croupier's stacks, either side of the wheel
					_chips(g, 13.14 + (k % 3) * 0.085, 7.27 + (k / 3) * 0.085, zr, 4 + (k * 2) % 5, cols[k])
					_chips(g, 13.14 + (k % 3) * 0.085, 8.64 + (k / 3) * 0.085, zr, 3 + (k * 3) % 6, cols[(k + 2) % 6])
				g.prism(13.8, 7.32, 0.03, zr, zr + 0.09, Color("#e8e0cf"), Color("#d6aa46"), 6)   # the marker


## the signs' light on the walls and the tables' glow on the floor: holes in the room's shade, after its own lights
static func lights(m, hole: Callable) -> void:
	if Quality3D.life <= 0:
		return
	var v: IsoView = m.v
	var hp: float = v.WH * 3.4
	for q in [[14.5, 0.15, 0.66], [3.2, 0.15, 0.66], [11.4, 0.15, 0.66], [1.0, 0.15, 0.84], [0.15, 5.0, 0.66], [0.15, 10.0, 0.85], [0.15, 1.0, 0.8], [0.15, 14.5, 0.84], [2.1, 14.5, 0.68]]:
		hole.call(q[0], q[1], hp * q[2], v.TW2 * 1.7, 0.6)
