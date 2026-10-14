class_name Scenery
extends RefCounted
## The land round the yard (17-scenery.js): the forest (boulders and dead trees round the quarry, snowy pines on
## Frostpeak), the fence or the quarry's rock rim, the river running on past the fence, and Frostpeak's props.
## Behind-the-yard pieces are painted into the ground's back chunk; the near side (south and east edges and their
## trees) is painted into front chunks drawn over the action, and a tree fades while someone stands behind it.

const BAND := 7
const OUT := Color(14 / 255.0, 12 / 255.0, 10 / 255.0, 0.95)


static func mixc(a: String, b: String, t: float) -> Color:
	return Color.html(a).lerp(Color.html(b), clampf(t, 0, 1))


## the river carries on outside the fence (Riverbend only)
static func out_water(sim: Sim, i: int, j: int) -> bool:
	if sim.map_id != "river" or i < 0 or i >= sim.N:
		return false
	return absf(i + 0.5 - PalMaps.river_c(j, sim.lay.o)) < 1


static func ramp_near(sim: Sim, i: int, j: int) -> bool:
	var N: int = sim.N
	for r in sim.lay.get("ramps", []):
		var a: int = r[0]
		var b: int = r[1]
		if b == 0 and j < 0 and absi(i - a) <= 1 and j > -5:
			return true
		if a == N - 1 and i >= N and absi(j - b) <= 1 and i < N + 4:
			return true
		if b == N - 1 and j >= N and absi(i - a) <= 1 and j < N + 4:
			return true
		if a == 0 and i < 0 and absi(j - b) <= 1 and i > -5:
			return true
	return false


static func is_ramp(sim: Sim, i: int, j: int) -> bool:
	for r in sim.lay.get("ramps", []):
		if r[0] == i and r[1] == j:
			return true
	return false


## genForest: [back trees, front trees], each sorted back to front
static func gen_forest(sim: Sim) -> Array:
	var back: Array = []
	var front_t: Array = []
	var N: int = sim.N
	var Q := sim.map_id == "quarry"
	for j in range(-BAND, N + BAND):
		for i in range(-BAND, N + BAND):
			if i >= 0 and j >= 0 and i < N and j < N:
				continue
			if out_water(sim, i, j):
				continue
			var dx := -i if i < 0 else (i - N + 1 if i >= N else 0)
			var dy := -j if j < 0 else (j - N + 1 if j >= N else 0)
			var d := maxi(dx, dy)
			var front := i >= N or j >= N
			if Q and ramp_near(sim, i, j):
				continue
			var h := Pal.hash2(i * 3 + 101, j * 7 + 13)
			var v := Pal.hash2(i + 57, j + 211)
			var x := i + 0.2 + Pal.hash2(i + 5, j + 9) * 0.6
			var y := j + 0.2 + Pal.hash2(i + 17, j + 3) * 0.6
			var t = null
			if Q:
				if d >= 2 and h > 0.72:
					t = {"x": x, "y": y, "kind": 1 if v > 0.7 else 4, "v": v, "h": 40 + v * 26}
				elif d >= 1 and h > 0.86:
					t = {"x": x, "y": y, "kind": 4, "v": v, "h": 0.0}
			elif d >= (3 if front else 2) and h > 0.3:
				t = {"x": x, "y": y, "kind": 1 if v > 0.93 else 0, "v": v, "h": 56 + v * 30 + (d - 2) * 2}
			elif d >= 1 and h > 0.8:
				t = {"x": x, "y": y, "kind": 2 if v > 0.35 else 3, "v": v, "h": 0.0}
			if t != null:
				t.a = 1.0
				t.snow = sim.map_id == "frost"
				if t.snow and t.kind == 1:
					t.kind = 0
				(front_t if front else back).append(t)
	var by_depth := func(a, b): return a.x + a.y < b.x + b.y
	back.sort_custom(by_depth)
	front_t.sort_custom(by_depth)
	return [back, front_t]


static func _P(cv: CanvasItem, pts: Array, col: Color, outline: bool, a: float) -> void:
	var q := PackedVector2Array()
	for p in pts:
		q.append(Vector2(p[0], p[1]))
	cv.draw_colored_polygon(q, Color(col, col.a * a))
	if outline:
		q.append(q[0])
		cv.draw_polyline(q, Color(OUT, OUT.a * a), 1.1)


static func _seg(cv: CanvasItem, a: Array, b: Array, col: Color, w: float, al: float) -> void:
	cv.draw_line(Vector2(a[0], a[1]), Vector2(b[0], b[1]), Color(col, col.a * al), w)


static func _oval(cv: CanvasItem, xf: Transform2D, x: float, y: float, rx: float, ry: float, col: Color) -> void:
	cv.draw_set_transform_matrix(xf * Transform2D(0, Vector2(1, ry / rx), 0, Vector2(x, y)))
	cv.draw_circle(Vector2.ZERO, rx, col)
	cv.draw_set_transform_matrix(xf)


## drawTreeAt: in base pixels round the tree's foot, scaled by u
static func tree(m, t: Dictionary) -> void:
	var cv: CanvasItem = m.cv
	var c: Vector2 = m.iso(t.x, t.y)
	var u: float = m.v.u
	var a: float = t.a
	var xf := Transform2D(0, Vector2(u, u), 0, c)
	cv.draw_set_transform_matrix(xf)
	match t.kind:
		0:   # a pine: three tiers, lit and shaded halves, snow on Frostpeak
			_oval(cv, xf, 5, 1, 17, 7, Color(0, 0, 0, 0.3 * a))
			cv.draw_rect(Rect2(-3.2, -13, 6.4, 13), Color(Color.html("#120d0a"), a))
			cv.draw_rect(Rect2(-2.4, -13, 4.8, 12.4), Color(Color.html("#45301f"), a))
			var light := mixc("#3d5a35", "#4b5d34", t.v)
			var dk := mixc("#223620", "#2a3a22", t.v)
			for k in 3:
				var by: float = -9 - k * t.h * 0.2
				var w: float = (19 - k * 4.8) * (0.9 + t.v * 0.3)
				var ty: float = by - t.h * 0.44
				var L := [-w, by]
				var R := [w, by]
				var A := [0, ty]
				var M := [0, by + 3.5]
				_P(cv, [L, A, M], light, false, a)
				_P(cv, [M, A, R], dk, false, a)
				if t.snow:
					_P(cv, [[-w * 0.68, by - t.h * 0.14], A, [w * 0.68, by - t.h * 0.14], [0, by - t.h * 0.07]], Color.html("#d9ebef" if k % 2 else "#b8d5e1"), false, a)
				var ol := PackedVector2Array([Vector2(L[0], L[1]), Vector2(A[0], A[1]), Vector2(R[0], R[1]), Vector2(M[0], M[1]), Vector2(L[0], L[1])])
				cv.draw_polyline(ol, Color(OUT, OUT.a * a), 1.1)
		1:   # a dead tree
			var top := [0, -t.h * 0.8]
			_seg(cv, [0, 0], top, OUT, 5, a)
			_seg(cv, [0, 0], top, Color.html("#3d3326"), 3.4, a)
			for b in [[0.45, -1, 10], [0.6, 1, 8], [0.72, -1, 6]]:
				var p0 := [0, -t.h * 0.8 * b[0]]
				var p1 := [p0[0] + b[1] * b[2], p0[1] - b[2] * 0.7]
				_seg(cv, p0, p1, OUT, 3.2, a)
				_seg(cv, p0, p1, Color.html("#3d3326"), 1.8, a)
		2:   # a bush
			var g1 := mixc("#2c4127", "#394a2a", t.v)
			var blobs := [[-4, -4, 6], [4, -3.5, 5.5], [0, -7, 6]]
			for b in blobs:
				cv.draw_circle(Vector2(b[0], b[1]), b[2] + 0.9, Color(OUT, OUT.a * a))
			for b in blobs:
				cv.draw_circle(Vector2(b[0], b[1]), b[2], Color(g1, a))
			cv.draw_circle(Vector2(-2, -9), 2.5, Color(g1.lerp(Color.WHITE, 0.12), a))
		4:   # a quarry boulder
			var r: float = 8 + t.v * 7
			_oval(cv, xf, 0, 1, r * 1.2, r * 0.5, Color(0, 0, 0, 0.3 * a))
			_P(cv, [[-r, 0], [-r * 0.7, -r * 0.9], [r * 0.1, -r * 1.2], [r * 0.9, -r * 0.6], [r, 0]], mixc("#5e584f", "#6b645a", t.v), true, a)
			_P(cv, [[-r * 0.7, -r * 0.9], [r * 0.1, -r * 1.2], [r * 0.9, -r * 0.6], [r * 0.1, -r * 0.5]], Color.html("#7a7368"), false, a)
		_:   # a stump
			cv.draw_rect(Rect2(-5, -6, 10, 6), Color(Color.html("#3a2b1c"), a))
			_oval(cv, xf, 0, -6, 5, 2.4, Color(Color.html("#806645"), a))
			_oval(cv, xf, 0, 0, 5, 2.4, Color(Color.html("#3a2b1c"), a))
	cv.draw_set_transform_matrix(Transform2D.IDENTITY)


static func fence(m, a: Array, b: Array) -> void:
	var cv: CanvasItem = m.cv
	var u: float = m.v.u
	var WH: float = m.v.WH
	var pa: Vector2 = m.iso(a[0], a[1])
	var pb: Vector2 = m.iso(b[0], b[1])
	for h in [WH * 0.32, WH * 0.62]:
		cv.draw_line(pa - Vector2(0, h), pb - Vector2(0, h), OUT, 3.4 * u)
		cv.draw_line(pa - Vector2(0, h), pb - Vector2(0, h), Color.html("#5d4832"), 2 * u)
	for p in [pa, pb]:
		cv.draw_rect(Rect2(p.x - 2.2 * u, p.y - WH * 0.85, 4.4 * u, WH * 0.85), OUT)
		cv.draw_rect(Rect2(p.x - 1.4 * u, p.y - WH * 0.82, 2.8 * u, WH * 0.82), Color.html("#4a3a28"))


## one tile of the yard's edge: the fence, a gap where the river runs out, or the quarry's rim with its ramps.
## n and w are behind the yard, s and e in front.
static func edge(m, side: String, s: int) -> void:
	var sim: Sim = m.sim
	var N: int = sim.N
	var A: Array = [s, 0] if side == "n" else ([0, s] if side == "w" else ([s, N] if side == "s" else [N, s]))
	var B: Array = [A[0] + 1, A[1]] if side == "n" or side == "s" else [A[0], A[1] + 1]
	var out: Array = [s, -1] if side == "n" else ([-1, s] if side == "w" else ([s, N] if side == "s" else [N, s]))
	var in_t: Array = [s, 0] if side == "n" else ([0, s] if side == "w" else ([s, N - 1] if side == "s" else [N - 1, s]))
	if sim.map_id == "river" and (out_water(sim, out[0], out[1]) or sim.t_at(in_t[0], in_t[1]) == PalMaps.T_WATER):
		return
	if sim.map_id == "quarry":
		if is_ramp(sim, in_t[0], in_t[1]):
			return
		var pa: Vector2 = m.iso(A[0], A[1])
		var pb: Vector2 = m.iso(B[0], B[1])
		var h: float = m.v.WH * (0.9 + Pal.hash2(s * 3 + (1 if side == "n" else (2 if side == "e" else 3)), 7) * 0.5)
		m.cv.draw_colored_polygon(PackedVector2Array([pa, pb, pb - Vector2(0, h), pa - Vector2(0, h)]), Color.html("#4a453e" if side == "n" or side == "s" else "#3c3833"))
		m.cv.draw_line(pa - Vector2(0, h), pb - Vector2(0, h), Color(0, 0, 0, 0.35), m.v.u)
		return
	fence(m, A, B)


## paintBack: the ground outside the fence, each map its own (snow, the quarry's spoil, the river carrying on)
static func paint_outside(m) -> void:
	var sim: Sim = m.sim
	var N: int = sim.N
	var v: IsoView = m.v
	var cv: CanvasItem = m.cv
	var u := v.u
	var Q := sim.map_id == "quarry"
	var F := sim.map_id == "frost"
	cv.draw_colored_polygon(PackedVector2Array([v.iso(-BAND - 6, -BAND - 6), v.iso(N + BAND + 6, -BAND - 6), v.iso(N + BAND + 6, N + BAND + 6), v.iso(-BAND - 6, N + BAND + 6)]), Color.html("#161412" if Q else "#151a12"))
	for i in range(-BAND, N + BAND):
		for j in range(-BAND, N + BAND):
			if i >= 0 and j >= 0 and i < N and j < N:
				continue
			var dx := -i if i < 0 else (i - N + 1 if i >= N else 0)
			var dy := -j if j < 0 else (j - N + 1 if j >= N else 0)
			var d := maxi(dx, dy)
			var h := Pal.hash2(i + 400, j + 77)
			var q := PackedVector2Array([v.iso(i, j), v.iso(i + 1, j), v.iso(i + 1, j + 1), v.iso(i, j + 1)])
			if out_water(sim, i, j):
				cv.draw_colored_polygon(q, Color.html("#1d3848" if h < 0.5 else "#1b3544"))
				continue
			var col: Color
			if F:
				col = mixc("#adc6d1", "#405966", d / 8.0)
			elif Q:
				col = Color.html("#4a4238" if h < 0.5 else "#453e35") if ramp_near(sim, i, j) else mixc("#2e2a25", "#35302a", h).lerp(Color.html("#1a1816"), clampf((d - 2) / 6.0, 0, 1))
			elif d == 1:
				col = Color.html("#342d21" if h < 0.5 else "#2f2a1e")
			else:
				col = mixc("#1f2518", "#262c1b", h).lerp(Color.html("#171c13"), clampf((d - 2) / 6.0, 0, 1))
			cv.draw_colored_polygon(q, col)
			if Q:
				if h > 0.7:
					var cc := v.iso(i + 0.3 + h * 0.4, j + 0.5)
					m.oval(cc.x, cc.y, 3 * u, 1.4 * u, Color(140 / 255.0, 130 / 255.0, 115 / 255.0, 0.25))
				continue
			if d >= 2 and h > 0.55:
				var cc := v.iso(i + 0.3 + h * 0.4, j + 0.5)
				cv.draw_line(cc, cc + Vector2(4 * u, -u), Color(107 / 255.0, 84 / 255.0, 51 / 255.0, 0.35), u)
			elif d == 1 and h > 0.7:
				var cc := v.iso(i + 0.5, j + 0.5)
				m.oval(cc.x, cc.y, 7 * u, 2.6 * u, Color(84 / 255.0, 104 / 255.0, 64 / 255.0, 0.35))


## Frostpeak's props: expedition caches past the edge, the summit beacon, stair handrails, route flags
static func frost_props(m) -> void:
	var sim: Sim = m.sim
	var N: int = sim.N
	var v: IsoView = m.v
	var cv: CanvasItem = m.cv
	var u := v.u
	var WH := v.WH
	for q in [[-0.6, 3], [N + 0.6, N - 4], [-0.6, N - 3]]:
		var x: float = q[0]
		var y: float = q[1]
		var c := v.iso(x, y)
		var w := 0.7 * v.TW2
		cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-w, 0), c + Vector2(0, v.TH2 * 0.5), c + Vector2(0, v.TH2 * 0.5 - WH * 0.3), c + Vector2(-w, -WH * 0.3)]), Color.html("#203e4c"))
		cv.draw_colored_polygon(PackedVector2Array([c + Vector2(0, v.TH2 * 0.5), c + Vector2(w, 0), c + Vector2(w, -WH * 0.3), c + Vector2(0, v.TH2 * 0.5 - WH * 0.3)]), Color.html("#304f5a"))
		cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-w, -WH * 0.3), c + Vector2(0, -v.TH2 * 0.5 - WH * 0.3), c + Vector2(w, -WH * 0.3), c + Vector2(0, v.TH2 * 0.5 - WH * 0.3)]), Color.html("#456571"))
		cv.draw_rect(Rect2(c.x - 12 * u, c.y - WH * 0.3, 24 * u, 3 * u), Color.html("#dfedf0"))
		cv.draw_line(Vector2(c.x - 15 * u, c.y + 3 * u), Vector2(c.x + 15 * u, c.y + 3 * u), Color.html("#9bb5be"), 2 * u)
	var b: Vector2 = m.iso(sim.core.i + 2.1, 0.8)
	cv.draw_line(b, b - Vector2(0, WH * 1.5), Color.html("#405969"), 3 * u)
	cv.draw_rect(Rect2(b.x - 3 * u, b.y - WH * 1.55, 6 * u, 5 * u), Color.html("#ffd882"))
	cv.draw_colored_polygon(PackedVector2Array([Vector2(b.x + 2 * u, b.y - WH * 1.35), Vector2(b.x + 17 * u, b.y - WH * 1.25), Vector2(b.x + 2 * u, b.y - WH * 1.1)]), Color.html("#bd5450"))
	var R := 11 * u
	for j in N:   # handrails down both sides of every staircase and ramp
		var i := 0
		while i < N:
			if sim.connectors[sim.idx(i, j)] == 0:
				i += 1
				continue
			var i0 := i
			while i + 1 < N and sim.connectors[sim.idx(i + 1, j)] != 0:
				i += 1
			var z: int = sim.heights[sim.idx(i0, j)]
			for x in [i0 + 0.04, i + 0.96]:
				var P: Array = [0.0, 0.5, 1.0].map(func(t): return v.iso(x, j + t, z + 1 - t))
				for p in P:
					cv.draw_line(p, p - Vector2(0, R), Color.html("#33505f"), 2 * u)
				cv.draw_polyline(PackedVector2Array(P.map(func(p): return p - Vector2(0, R))), Color.html("#486a7c"), 2.4 * u)
				cv.draw_polyline(PackedVector2Array(P.map(func(p): return p - Vector2(0, R + u))), Color.html("#a9c7d3"), 0.8 * u)
			i += 1
	for k in N * N:   # a route flag at the foot of each stair run
		if sim.connectors[k] != 0 and (not sim.inb(k % N - 1, k / N) or sim.connectors[k - 1] == 0):
			var p: Vector2 = m.iso(k % N + 0.08, k / N + 0.5)
			cv.draw_line(p, p - Vector2(0, WH * 0.55), Color.html("#486a7c"), 2 * u)
			cv.draw_rect(Rect2(p.x, p.y - WH * 0.55, 7 * u, 3 * u), Color.html("#efa568"))
