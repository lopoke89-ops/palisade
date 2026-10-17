class_name CityView
extends RefCounted
## City Black Out's look (dev/src/js/06e-city.js and 16f-blackout-hud.js): the ground, ruined buildings, the eight POI
## structures, streetlamps and the mini-map. Everything draws through the main node `m` during its _draw.

const WALL := [["#3e4246", "#303438", "#26292c"], ["#4b4239", "#3b342d", "#2e2924"], ["#4a4744", "#3a3735", "#2d2b29"]]


static func ground_col(m, i: int, j: int, h: float) -> Color:
	var t: int = m.sim.terr[m.sim.idx(i, j)]
	if t == PalMaps.T_ROAD:
		return m.c("#1e2023") if h < 0.5 else m.c("#202226")
	if t == PalMaps.T_WALK:
		return m.c("#3a3a38") if h < 0.5 else m.c("#363634")
	if t == PalMaps.T_RUBBLE:
		return m.c("#3b342c") if h < 0.5 else m.c("#352f28")
	if t == PalMaps.T_BLDG:
		return m.c("#1a1a1c")
	if PalMaps.city_plaza(i, j, m.sim.lay.city, m.sim.lay.pois):   # concrete pads under Main Command and the POIs
		return m.c("#3d3f42") if h < 0.5 else m.c("#393b3e")
	return m.c("#2c2a26") if h < 0.2 else (m.c("#282622") if h < 0.75 else m.c("#24221f"))


static func ground_detail(m, i: int, j: int) -> void:
	var sim: Sim = m.sim
	var v: IsoView = m.v
	var u := v.u
	var t: int = sim.terr[sim.idx(i, j)]
	if t == PalMaps.T_ROAD:   # dashed centre lines where two road lanes meet
		var col := Color(220 / 255.0, 190 / 255.0, 90 / 255.0, 0.32)
		if sim.t_at(i + 1, j) == PalMaps.T_ROAD and sim.t_at(i - 1, j) != PalMaps.T_ROAD and j % 2 == 0:
			m.cv.draw_line(v.iso(i + 1, j + 0.2), v.iso(i + 1, j + 0.8), col, 1.2 * u)
		if sim.t_at(i, j + 1) == PalMaps.T_ROAD and sim.t_at(i, j - 1) != PalMaps.T_ROAD and i % 2 == 0:
			m.cv.draw_line(v.iso(i + 0.2, j + 1), v.iso(i + 0.8, j + 1), col, 1.2 * u)
	elif t == PalMaps.T_RUBBLE:
		for q in 3:
			var cc := v.iso(i + 0.2 + Pal.hash2(i + q, j) * 0.6, j + 0.2 + Pal.hash2(i, j + q) * 0.6)
			m.oval(cc.x, cc.y, (2 + q) * u, (1 + q * 0.5) * u, m.c("#5a5048") if q % 2 else m.c("#4a423a"))
	elif t == PalMaps.T_WALK:
		m.cv.draw_line(v.iso(i, j + 0.5), v.iso(i + 1, j + 0.5), Color(0, 0, 0, 0.18), u)


## a ruined building tile: walls only where the block ends, a few windows on the south face
static func building(m, i: int, j: int, baked: bool) -> void:
	var sim: Sim = m.sim
	var v: IsoView = m.v
	var u := v.u
	var hbv := Pal.hash2((i / 4) * 7 + 3, (j / 4) * 13 + 5)
	var hb := maxi(0, mini(4, floori(hbv * 5)) - (1 if Pal.hash2(i * 3 + 1, j * 5 + 2) > 0.8 else 0))
	var mask := (1 if sim.t_at(i, j + 1) != PalMaps.T_BLDG else 0) | (2 if sim.t_at(i + 1, j) != PalMaps.T_BLDG else 0)
	var pal := 2 if hbv > 0.7 else (1 if hbv > 0.5 else 0)
	var win := floori(Pal.hash2(i * 5, j * 7) * 4)
	var p: Dictionary = sim.player
	var dd: float = i + j + 1 - (p.x + p.y)
	var lat: float = (i - j) - (p.x - p.y)
	var fade := not baked and dd > 0 and dd < 4.5 and absf(lat) < 2.6   # see-through when it stands in front of you
	if fade:
		m.draw_alpha = 0.32
	var H := v.WH * (0.85 + hb * 0.225)
	var A := v.iso(i, j + 1)
	var B := v.iso(i + 1, j + 1)
	var C := v.iso(i + 1, j)
	var D := v.iso(i, j)
	var W: Array = WALL[pal]
	if mask & 1:
		m.quad(A, B, m.up(B, H), m.up(A, H), m.c(W[1]))
	if mask & 2:
		m.quad(B, C, m.up(C, H), m.up(B, H), m.c(W[2]))
	m.quad(m.up(D, H), m.up(C, H), m.up(B, H), m.up(A, H), m.c(W[0]))
	if mask & 1:
		for r in 2:
			for q in 2:
				var lit := ((win >> (r * 2 + q)) & 1) != 0 and win == 3
				var x := A.x + (B.x - A.x) * (0.2 + q * 0.45)
				var y := A.y + (B.y - A.y) * (0.2 + q * 0.45) - H * (0.35 + r * 0.3)
				var col := Color(1, 210 / 255.0, 120 / 255.0, 0.55) if lit else Color(10 / 255.0, 10 / 255.0, 12 / 255.0, 0.75)
				col.a *= m.draw_alpha
				m.cv.draw_rect(Rect2(x, y, 4 * u, 4 * u), col)
	m.draw_alpha = 1.0


static func _pole(m, x: float, y: float, h: float, col: Color, w: float = 1.6) -> Vector2:
	var a: Vector2 = m.v.iso(x, y)
	m.cv.draw_line(a, Vector2(a.x, a.y - h), col, w * m.v.u)
	return Vector2(a.x, a.y - h)


static func poi_bar(m, c: Dictionary, x: float, y: float) -> void:
	if c.get("lost", false):
		return
	var u: float = m.v.u
	var p: Dictionary = m.sim.player
	var near := Vector2(p.x - c.i - 0.5, p.y - c.j - 0.5).length() < 8
	var hurt: bool = c.hp < c.max
	if c.get("attack", false) or near:
		m.label(c.poi.name if c.has("poi") else "MAIN COMMAND", x, y - 10 * u, m.c("#ff8a6a") if c.get("attack", false) else m.c("#d8cfb8"), 10)
	if c.get("attack", false) or hurt:
		var w := 38 * u
		var hb := 4 * u
		m.cv.draw_rect(Rect2(x - w / 2 - 1, y - 6 * u - 1, w + 2, hb + 2), Color(10 / 255.0, 8 / 255.0, 6 / 255.0, 0.85))
		m.cv.draw_rect(Rect2(x - w / 2, y - 6 * u, w * maxf(0, c.hp / c.max), hb), m.c("#e8573a") if c.get("attack", false) else m.c("#e2b436"))


## each POI is a stake with its own look; a lost one is a burnt-out shell
static func poi(m, c: Dictionary) -> void:
	var v: IsoView = m.v
	var u := v.u
	var WH := v.WH
	var i: float = c.i
	var j: float = c.j
	var id: String = c.poi.id
	var f: bool = c.flash > 0
	var t: float = m.sim.game.time
	var T := func(col: String, hot: String = "#8a4a34") -> Color: return m.c(hot) if f else m.c(col)
	if c.lost:
		m.box_r(i + 0.1, j + 0.15, i + 0.9, j + 0.85, 0, WH * 0.35, m.c("#2a2622"), m.c("#1d1a17"), m.c("#151311"))
		m.box_r(i + 0.2, j + 0.25, i + 0.55, j + 0.6, WH * 0.35, WH * 0.3, m.c("#332d27"), m.c("#231f1b"), m.c("#1a1714"))
		if randf() < 0.04:
			m._emit(i + 0.5, j + 0.5, "smoke", 0)
		return
	var top: Vector2
	match id:
		"radio":   # a lattice mast on a block, with a blinking light
			m.box_r(i + 0.15, j + 0.15, i + 0.85, j + 0.85, 0, WH * 0.5, T.call("#5a5f63"), T.call("#43474a"), T.call("#33363a"))
			var b := v.iso(i + 0.5, j + 0.5)
			var H := WH * 3.4
			var by := b.y - WH * 0.5
			var col: Color = T.call("#8a8f93", "#a05a40")
			for s in [-1, 1]:
				m.cv.draw_line(Vector2(b.x + s * 9 * u, by), Vector2(b.x + s * 1.5 * u, by - H), col, 1.4 * u)
			for q in 7:
				var y0 := by - H * q / 7.0
				var y1 := by - H * (q + 1) / 7.0
				var w0 := 9 * u * (1 - q / 7.0) + 1.5 * u * q / 7.0
				var w1 := 9 * u * (1 - (q + 1) / 7.0) + 1.5 * u * (q + 1) / 7.0
				m.cv.draw_line(Vector2(b.x - w0, y0), Vector2(b.x + w1, y1), col, 1.4 * u)
				m.cv.draw_line(Vector2(b.x + w0, y0), Vector2(b.x - w1, y1), col, 1.4 * u)
			top = Vector2(b.x, by - H)
			if sin(t * 4) > 0:
				m.cv.draw_circle(top, 2.6 * u, m.c("#ff4a3a"))
		"power":   # transformer block, a cooling stack, and sparks
			m.box_r(i - 0.15, j + 0.2, i + 0.6, j + 0.95, 0, WH * 0.9, T.call("#4d5a52"), T.call("#38423c"), T.call("#2b332e"))
			for q in 3:
				m.box_r(i + 0.62, j + 0.1 + q * 0.28, i + 0.88, j + 0.3 + q * 0.28, 0, WH * 0.55, T.call("#6b6f5a"), T.call("#505442"), T.call("#3d4033"))
			var s := v.iso(i + 0.25, j + 0.15)
			for q in 5:
				var r := (9 - q * 0.6) * u
				m.oval(s.x, s.y - q * WH * 0.4, r, r * 0.45, T.call("#7a7c78" if q % 2 else "#6a6c68"))
			m.oval(s.x, s.y - WH * 2, 8 * u, 3.6 * u, m.c("#2a2b2a"))
			top = Vector2(s.x, s.y - WH * 2.1)
			if randf() < 0.08:
				var p := v.iso(i + 0.75, j + 0.5)
				m.cv.draw_polyline(PackedVector2Array([Vector2(p.x, p.y - WH * 0.6), Vector2(p.x + 4 * u, p.y - WH * 0.8), Vector2(p.x - 2 * u, p.y - WH * 0.95)]), m.c("#bfe6ff"), 1.2 * u)
		"hospital":   # a white block with a red cross on the roof
			var bx: Dictionary = m.box_r(i - 0.25, j - 0.25, i + 1.15, j + 1.15, 0, WH * 1.5, T.call("#d9dad4"), T.call("#b9bbb4"), T.call("#9c9e98"))
			var mid: Vector2 = (bx.A.lerp(bx.C, 0.5)).lerp(bx.B.lerp(bx.D, 0.5), 0.5)
			var cy := mid.y - WH * 1.5
			var k := 6 * u
			m.cv.draw_rect(Rect2(mid.x - k * 1.6, cy - k * 0.3, k * 3.2, k * 0.6), m.c("#d23a32"))
			m.cv.draw_rect(Rect2(mid.x - k * 0.4, cy - k * 0.9, k * 0.8, k * 1.8), m.c("#d23a32"))
			for q in 3:
				var p: Vector2 = bx.D.lerp(bx.C, 0.2 + q * 0.3)
				m.cv.draw_rect(Rect2(p.x - 2 * u, p.y - WH * 1.05, 4 * u, 5 * u), Color(120 / 255.0, 190 / 255.0, 220 / 255.0, 0.7))
			top = Vector2(mid.x, cy)
		"armory":   # fenced compound with crate stacks
			for b in [[0.1, 0.15, 0.5], [0.5, 0.15, 0.8], [0.1, 0.55, 0.8], [0.5, 0.55, 0.5], [0.3, 0.35, 1.2]]:
				m.box_r(i + b[0], j + b[1], i + b[0] + 0.38, j + b[1] + 0.36, 0, WH * b[2], T.call("#59633d"), T.call("#434b2e"), T.call("#343a24"))
			for q in [[-0.2, -0.2], [1.2, -0.2], [1.2, 1.2], [-0.2, 1.2]]:
				_pole(m, i + q[0], j + q[1], WH * 0.9, T.call("#77736a"), 1.2)
			var c0 := v.iso(i + 0.5, j + 0.5)
			top = Vector2(c0.x, c0.y - WH * 1.3)
			m.cv.draw_rect(Rect2(top.x - 5 * u, top.y + WH * 0.2, 10 * u, 3 * u), m.c("#e2b436"))
		"gas":   # canopy on posts over a pump, and a little shop
			m.box_r(i + 0.45, j - 0.2, i + 1.1, j + 0.45, 0, WH * 0.8, T.call("#6a5f52"), T.call("#524a40"), T.call("#3f3931"))
			m.box_r(i + 0.2, j + 0.4, i + 0.38, j + 0.6, 0, WH * 0.6, T.call("#c64a36"), T.call("#9e3a2a"), T.call("#7a2d20"))
			for q in [[-0.1, 0.2], [0.7, 0.2], [0.7, 1], [-0.1, 1]]:
				_pole(m, i + q[0], j + q[1], WH * 1.25, T.call("#9a9890"), 1.4)
			m.box_r(i - 0.15, j + 0.15, i + 0.75, j + 1.05, WH * 1.25, WH * 0.15, T.call("#e8e2d0"), T.call("#c63a2e"), T.call("#a02e24"))
			var c0 := v.iso(i + 0.3, j + 0.6)
			top = Vector2(c0.x, c0.y - WH * 1.45)
		"hardware":   # big-box store with an orange band and a lumber stack
			var bx: Dictionary = m.box_r(i - 0.2, j - 0.2, i + 0.9, j + 0.75, 0, WH * 1.1, T.call("#5b5953"), T.call("#47453f"), T.call("#383631"))
			m.quad(m.up(bx.D, WH * 0.8), m.up(bx.C, WH * 0.8), m.up(bx.C, WH), m.up(bx.D, WH), m.c("#d8752a"))
			for q in 3:
				m.box_r(i + 0.1, j + 0.8, i + 0.9, j + 0.95, q * WH * 0.12, WH * 0.11, T.call("#a8834f"), T.call("#87683d"), T.call("#6b5230"))
			var c0 := v.iso(i + 0.35, j + 0.3)
			top = Vector2(c0.x, c0.y - WH * 1.1)
		"brick":   # a kiln yard: a squat kiln and a tall chimney with a glow
			m.box_r(i + 0.05, j + 0.25, i + 0.8, j + 0.95, 0, WH * 0.8, T.call("#8a4a34"), T.call("#6e3a28"), T.call("#55301f"))
			m.box_r(i + 0.5, j + 0.05, i + 0.75, j + 0.3, 0, WH * 2.4, T.call("#7a3e2c"), T.call("#5e3022"), T.call("#4a261b"))
			var c0 := v.iso(i + 0.62, j + 0.18)
			m.oval(c0.x, c0.y - WH * 2.4, 3 * u, 1.4 * u, Color(1, 140 / 255.0, 60 / 255.0, 0.8))
			top = Vector2(c0.x, c0.y - WH * 2.5)
			var mm := v.iso(i + 0.4, j + 0.6)
			m.cv.draw_rect(Rect2(mm.x - 3 * u, mm.y - WH * 0.4, 6 * u, 4 * u), Color(1, 150 / 255.0, 70 / 255.0, 0.7))
		_:   # parking garage: three concrete decks on pillars
			for q in 3:
				var z := q * WH * 0.75
				m.box_r(i - 0.2, j - 0.2, i + 1.2, j + 1.2, z + WH * 0.6, WH * 0.15, T.call("#6f716e"), T.call("#585a57"), T.call("#474946"))
				if q < 2:
					for pp in [[-0.1, 1.1], [1.1, 1.1], [1.1, -0.1], [0.5, 1.1], [1.1, 0.5]]:
						m.box_r(i + pp[0] - 0.05, j + pp[1] - 0.05, i + pp[0] + 0.05, j + pp[1] + 0.05, z + WH * 0.75, WH * 0.6, m.c("#5a5c59"), m.c("#4a4c49"), m.c("#3c3e3b"))
			var c0 := v.iso(i + 0.5, j + 0.5)
			top = Vector2(c0.x, c0.y - WH * 2.3)
			m.label("P", top.x, top.y + WH * 0.2, m.c("#e2b436"), int(9 * u))
	poi_bar(m, c, top.x, top.y - 4 * u)


## a streetlamp leaning out over the road; lit while the Power Station holds
static func lamp(m, l: Array) -> void:
	var v: IsoView = m.v
	var u := v.u
	var on: bool = not m.sim.game.get("dark", false)
	var x: float = l[0] + 0.5 + l[2] * 0.38
	var y: float = l[1] + 0.5 + l[3] * 0.38
	var p := _pole(m, x, y, v.WH * 1.7, m.c("#3e4245"), 1.6)
	var q := v.iso(x + l[2] * 0.3, y + l[3] * 0.3)
	var h := Vector2(q.x, q.y - v.WH * 1.75)
	m.cv.draw_line(p, h, m.c("#3e4245"), 1.4 * u)
	if on:
		m.cv.draw_circle(Vector2(h.x, h.y + 1.5 * u), v.TW2 * 0.3, Color(1, 0.9, 0.6, 0.12))
		m.cv.draw_circle(Vector2(h.x, h.y + 1.5 * u), v.TW2 * 0.14, Color(1, 0.9, 0.6, 0.18))
		var g := v.iso(l[0] + 0.5 + l[2] * 0.7, l[1] + 0.5 + l[3] * 0.7)
		m.oval(g.x, g.y, v.TW2 * 1.6, v.TH2 * 1.6, Color(1, 0.8, 0.45, 0.06))   # a pool of sodium light on the road
	m.oval(h.x, h.y + 1.5 * u, 3 * u, 1.6 * u, m.c("#ffe7a8") if on else m.c("#2a2c2e"))


## the city drawn once, small (one pixel a tile), for the mini-map
static func map_image(sim: Sim) -> ImageTexture:
	var n: int = sim.N
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(12 / 255.0, 12 / 255.0, 14 / 255.0, 0.82))
	for j in n:
		for i in n:
			var t: int = sim.terr[sim.idx(i, j)]
			if t == PalMaps.T_ROAD:
				img.set_pixel(i, j, Color.html("#5a5c60"))
			elif t == PalMaps.T_BLDG:
				img.set_pixel(i, j, Color.html("#26272a"))
			elif t == PalMaps.T_RUBBLE:
				img.set_pixel(i, j, Color.html("#3a342c"))
	return ImageTexture.create_from_image(img)


## the mini-map: the city in the same diamond the screen shows, the POIs by state, raiders and you
static func minimap(m, tex: ImageTexture, x: float, y: float, w: float) -> void:
	var sim: Sim = m.sim
	var n: int = sim.N
	var k := w / (2.0 * n)
	var P := func(i: float, j: float) -> Vector2: return Vector2(x + (i - j) * k + w / 2, y + (i + j) * k * 0.5)
	# the map texture through the iso transform: x' = (i - j) k, y' = (i + j) k/2
	m.cv.draw_set_transform_matrix(Transform2D(Vector2(k, k * 0.5), Vector2(-k, k * 0.5), Vector2(x + w / 2, y)))
	m.cv.draw_texture(tex, Vector2.ZERO)
	m.cv.draw_set_transform_matrix(Transform2D.IDENTITY)
	var pulse := 0.5 + 0.5 * sin(sim.game.time * 6)
	for c in sim.cores:
		var q: Vector2 = P.call(c.i + 0.5, c.j + 0.5)
		var col: Color
		if not c.has("poi"):
			col = Color.html("#e2b436")
		elif c.lost:
			col = Color.html("#5a4038")
		elif c.get("attack", false):
			col = Color.html("#ff5a3a").lerp(Color.WHITE, pulse * 0.4)
		elif c.get("next", false):
			col = Color.html("#ffb03a")
		else:
			col = Color.html("#8fe0a0")
		m.cv.draw_rect(Rect2(q.x - 3, q.y - 2, 6, 4), col)
	for e in sim.enemies:
		if not e.dead:
			var q: Vector2 = P.call(e.x, e.y)
			m.cv.draw_rect(Rect2(q.x - (2 if e.type == "boss" else 1), q.y - 1, 4 if e.type == "boss" else 2, 2), Color.html("#ff4a3a"))
	var pq: Vector2 = P.call(sim.player.x, sim.player.y)
	m.cv.draw_circle(pq, 2.5, Color.html("#ffffff"))


static func phase_text(sim: Sim) -> String:
	var B = sim.game.get("bo")
	var clock := func(t: float) -> String:
		var s := maxi(0, ceili(t))
		return "%d:%02d" % [s / 60, s % 60]
	var nxt = null
	for c in sim.cores:
		if c.has("poi") and c.get("next", false):
			nxt = c
	if sim.game.phase == "build":
		return "GATHER · %s · %s   (ENTER: start now)" % [clock.call(sim.game.timer), ("first: " + nxt.poi.name) if nxt != null else "first attack"]
	if B == null:
		return ""
	if B.stage == "ready":
		return "READY UP · %s   (ENTER: ready)" % clock.call(B.t)
	if B.stage == "attack" and B.cur != null:
		return "POI ATTACK · %s · %s" % [sim.cores[B.cur.ci].poi.name, clock.call(Sim.BO.cap - B.t)]
	if B.stage == "push" or (B.stage == "done" and B.push != null):
		var F: Dictionary = B.push
		return "FINAL PUSH · %s · %s" % [clock.call(F.t), "THE DESTROYER" if F.dest else "boss %d/6" % mini(6, F.n)]
	var held := sim.cores.filter(func(c): return c.has("poi") and not c.lost).size()
	return "QUIET · %s · %s" % [clock.call(B.t), ("next: " + nxt.poi.name) if nxt != null else "%d/8 held" % held]
