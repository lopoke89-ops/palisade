class_name OutDress
extends RefCounted
## The co-op maps' set dressing (the Living World work order): one landmark and a few story clusters for the Yard,
## Riverbend, Ashfall Quarry and Frostpeak. Visual only, and all of it stands in the one-tile strip just outside the
## fence on the far (north and west) sides: nothing there can be walked on, built on, shot through or pathed over,
## so the build cells, the stake, the piles, the spawn edges and Delgado's routes are untouched. A piece only goes
## where the forest left the strip empty (no bush or boulder, no river, no quarry ramp), from a hash of its own.
## The geometry joins the back scenery's mesh: no extra draws, nothing per frame. PvP layouts are left as they are
## (their dressing has to mirror or turn with the layout, which is its own job).
## Quality3D.life: 0 off (the maps as they were), 1 the landmark, 2 + the clusters, 3 + the small stuff.

const V3 = preload("res://scripts/view3d/view3d.gd")

var sim: Sim
var N := 0
var life := 0
var S   # V3World (a node: holding the scenery itself would be a reference cycle, and leak)
var free_n: Array = []   # the north strip's tiles (i, -1) a piece may stand on
var free_w: Array = []   # the west strip's (-1, j)
var placed: Array = []   # [kind, side, start tile, tiles]
var skipped: Array = []   # [kind, why]


func _init(scn) -> void:
	S = scn.W
	sim = scn.sim
	N = sim.N
	life = Quality3D.life


static func vh(i: int, j: int, salt: int) -> float:
	return Pal.hash2(i * 29 + salt * 6151 + 7001, j * 19 + salt * 92821 + 311)


## is the strip tile empty: no river, no quarry ramp, and the forest put no bush or boulder on it?
func _empty(i: int, j: int) -> bool:
	if Scenery.out_water(sim, i, j):
		return false
	var Q := sim.map_id == "quarry"
	if Q and Scenery.ramp_near(sim, i, j):
		return false
	return Pal.hash2(i * 3 + 101, j * 7 + 13) <= (0.86 if Q else 0.8)


## n empty tiles in a row on a strip (0 north, 1 west), nearest `prefer`; they are taken, with a tile's gap after
func _fit(side: int, n: int, prefer: float) -> int:
	var F: Array = free_n if side == 0 else free_w
	var best := -1
	var bd := 1e9
	for a in range(0, N - n + 1):
		var ok := true
		for q in n:
			if not F[a + q]:
				ok = false
				break
		if ok and absf(a + n * 0.5 - prefer) < bd:
			bd = absf(a + n * 0.5 - prefer)
			best = a
	if best >= 0:
		for q in range(maxi(0, best - 1), mini(N, best + n + 1)):
			F[q] = false
	return best


## a strip's frame at a tile: origin on the fence line, the direction along it, the direction away from the yard
func _frame(side: int, a: int) -> Array:
	if side == 0:
		return [Vector3(a, S.scenery.oh(a, -1), 0), Vector3(1, 0, 0), Vector3(0, 0, -1)]
	return [Vector3(0, S.scenery.oh(-1, a), a), Vector3(0, 0, 1), Vector3(-1, 0, 0)]


static func _p(F: Array, u: float, d: float, y: float) -> Vector3:
	return F[0] + F[1] * u + F[2] * d + Vector3(0, y, 0)


func _box(g: V3Mesh, F: Array, u0: float, u1: float, d0: float, d1: float, y0: float, y1: float, col: Color) -> void:
	var a := _p(F, u0, d0, y0)
	var b := _p(F, u1, d1, y1)
	g.box(minf(a.x, b.x), minf(a.z, b.z), maxf(a.x, b.x), maxf(a.z, b.z), a.y, b.y, col.lightened(0.1), col, col.darkened(0.18))


func _post(g: V3Mesh, F: Array, u: float, d: float, y0: float, y1: float, w: float, col: Color) -> void:
	g.bar(_p(F, u, d, y0), _p(F, u, d, y1), w, col)


func _want(g: V3Mesh, kind: String, side: int, n: int, prefer: float, at_least: int = 1) -> Array:
	if life < at_least:
		return []
	var a := _fit(side, n, prefer)
	if a < 0:
		a = _fit(1 - side, n, prefer)   # the other strip, rather than nothing
		side = 1 - side
	if a < 0:
		skipped.append([kind, "no %d empty tiles in a row outside the fence" % n])
		return []
	placed.append([kind, "north" if side == 0 else "west", a, n])
	return _frame(side, a)


## everything, into the back scenery's mesh
func build(g: V3Mesh) -> void:
	if life <= 0 or sim.lay.get("pvp", false) or not sim.map_id in ["yard", "river", "quarry", "frost"]:
		return
	free_n.clear()
	free_w.clear()
	for q in N:
		free_n.append(_empty(q, -1))
		free_w.append(_empty(-1, q))
	var cx: float = sim.core.i + 0.5
	var cy: float = sim.core.j + 0.5
	g.anchor = Vector2(-9999, -9999)
	var F: Array
	match sim.map_id:
		"yard":
			F = _want(g, "camp bench and flag", 0, 3, cx)
			if not F.is_empty():
				_bench(g, F)
				_flag(g, F, 2.5, Color("#b8502e"))
			F = _want(g, "tarp shelter", 0, 2, cx + 5.0, 2)
			if not F.is_empty():
				_tarp(g, F, Color("#4f5a3c"))
				_stack(g, F, 0.35, vh(int(F[0].x), 0, 1))
			F = _want(g, "supply stacks", 1, 2, cy, 2)
			if not F.is_empty():
				_stack(g, F, 0.2, vh(0, int(F[0].z), 2))
				_stack(g, F, 1.1, vh(0, int(F[0].z), 3))
			F = _want(g, "fence repair", 0, 1, cx - 5.0, 2)
			if not F.is_empty():
				_repair(g, F)
			F = _want(g, "hand cart", 1, 2, cy + 5.0, 2)
			if not F.is_empty():
				_cart(g, F)
		"river":
			var rc: float = PalMaps.river_c(-1, sim.lay.o)
			F = _want(g, "flood gauge and winch", 0, 2, rc + 2.5)
			if not F.is_empty():
				_gauge(g, F, 0.3)
				_winch(g, F, 1.3)
			F = _want(g, "sandbag line", 0, 2, rc - 3.0, 2)
			if not F.is_empty():
				_sandbags(g, F, 2.0)
				_reeds(g, F, 1.7, 5)
			F = _want(g, "abandoned cart", 1, 2, cy, 2)
			if not F.is_empty():
				_cart(g, F)
			F = _want(g, "bridge timber", 0, 2, rc + 6.0, 2)
			if not F.is_empty():
				_planks(g, F)
				_reeds(g, F, 0.2, 4)
		"quarry":
			F = _want(g, "headframe", 0, 2, cx)
			if not F.is_empty():
				_headframe(g, F)
			F = _want(g, "site hut and warning board", 0, 3, cx + 5.0, 2)
			if not F.is_empty():
				_hut(g, F, Color("#5a5348"), Color("#3a3631"))
				_board(g, F, 2.5)
			F = _want(g, "ore staging", 1, 2, cy, 2)
			if not F.is_empty():
				_ore(g, F)
			F = _want(g, "ore staging", 0, 2, cx - 5.0, 2)
			if not F.is_empty():
				_ore(g, F)
		"frost":
			F = _want(g, "expedition shelter", 0, 2, cx + 4.0)
			if not F.is_empty():
				_tent(g, F)
			F = _want(g, "rope cache", 1, 2, cy, 2)
			if not F.is_empty():
				_stack(g, F, 0.2, 0.9, true)
				_flag(g, F, 1.5, Color("#efa568"))
			F = _want(g, "second shelter", 1, 2, cy + 6.0, 2)
			if not F.is_empty():
				_tent(g, F)
			_antenna(g)


# ---------------------------------------------------------------- the pieces (u along the fence, d away from it)

## a repair bench: a top on four legs, a vice, a toolbox, a plank waiting; a rack of tools behind it
func _bench(g: V3Mesh, F: Array) -> void:
	var wood := Color("#6a5236")
	_box(g, F, 0.2, 1.7, 0.3, 0.72, 0.3, 0.34, wood)
	for q in [[0.24, 0.34], [1.62, 0.34], [0.24, 0.66], [1.62, 0.66]]:
		_post(g, F, q[0], q[1], 0, 0.3, 0.025, wood.darkened(0.25))
	_box(g, F, 0.3, 0.42, 0.36, 0.5, 0.34, 0.43, Color("#5b6063"))
	_box(g, F, 1.2, 1.5, 0.4, 0.6, 0.34, 0.44, Color("#8a3a2c"))
	g.bar(_p(F, 0.55, 0.38, 0.36), _p(F, 1.1, 0.62, 0.36), 0.02, Color("#8a7350"))
	for u in [0.25, 1.65]:
		_post(g, F, u, 0.88, 0, 0.78, 0.025, wood.darkened(0.25))
	_box(g, F, 0.25, 1.65, 0.86, 0.9, 0.4, 0.76, Color("#4a3b2a"))
	if life >= 3:
		for i in 5:   # what hangs on it
			var u := 0.42 + i * 0.26
			g.bar(_p(F, u, 0.85, 0.7), _p(F, u, 0.85, 0.48 + 0.06 * (i % 2)), 0.012, Color("#5b6063") if i % 2 else Color("#8a7350"))


## a pole and a flag, hanging still
func _flag(g: V3Mesh, F: Array, u: float, col: Color) -> void:
	_post(g, F, u, 0.5, 0, 1.35, 0.02, Color("#4a3a28"))
	var top := _p(F, u, 0.5, 1.32)
	g.quad(top, top + V3.CAM_R * 0.34 + Vector3(0, -0.05, 0), top + V3.CAM_R * 0.3 + Vector3(0, -0.27, 0), top + Vector3(0, -0.22, 0), col)
	g.disc(_p(F, u, 0.5, 0).x, _p(F, u, 0.5, 0).z, 0.1, 0.08, F[0].y + 0.004, Color("#2a241a"), 7)


## a tarp on four poles, sloping away from the yard
func _tarp(g: V3Mesh, F: Array, col: Color) -> void:
	for q in [[0.15, 0.2, 0.66], [1.85, 0.2, 0.66], [0.15, 0.9, 0.42], [1.85, 0.9, 0.42]]:
		_post(g, F, q[0], q[1], 0, q[2], 0.02, Color("#4a3a28"))
	g.quad(_p(F, 0.08, 0.14, 0.67), _p(F, 1.92, 0.14, 0.67), _p(F, 1.92, 0.96, 0.43), _p(F, 0.08, 0.96, 0.43), col)
	g.quad(_p(F, 0.08, 0.14, 0.67), _p(F, 1.92, 0.14, 0.67), _p(F, 1.92, 0.14, 0.6), _p(F, 0.08, 0.14, 0.6), col.darkened(0.2))


## sorted stores: cases, a sack or two, a barrel (snow: an expedition's teal cases, roped)
func _stack(g: V3Mesh, F: Array, u: float, v: float, snow: bool = false) -> void:
	var c1 := Color("#456571") if snow else Color("#6a5236")
	var c2 := Color("#304f5a") if snow else Color("#5a5a44")
	_box(g, F, u, u + 0.4, 0.3, 0.7, 0, 0.3, c1)
	_box(g, F, u + 0.42, u + 0.74, 0.34, 0.66, 0, 0.24, c2)
	_box(g, F, u + 0.06 + 0.1 * v, u + 0.36 + 0.1 * v, 0.36, 0.64, 0.3, 0.5, c2)
	if snow:
		_box(g, F, u, u + 0.4, 0.3, 0.7, 0.3, 0.315, Color("#dfedf0"))
		g.bar(_p(F, u + 0.5, 0.3, 0.26), _p(F, u + 0.72, 0.2, 0.0), 0.012, Color("#c8a03a"))
		return
	var p := _p(F, u + 0.6, 0.82, 0)
	g.prism(p.x, p.z, 0.13, p.y, p.y + 0.34, Color("#5d4a39"), Color("#3a2f24"), 8)
	if life >= 3:
		p = _p(F, u + 0.2, 0.86, 0)
		g.prism(p.x, p.z, 0.14, p.y, p.y + 0.16, Color("#b8ac8c"), Color("#a89c7c"), 7, 0.09)


## a fence panel half mended: new rails leant against the fence, a saw-horse
func _repair(g: V3Mesh, F: Array) -> void:
	for i in 3:
		g.bar(_p(F, 0.2 + i * 0.22, 0.5, 0), _p(F, 0.24 + i * 0.22, 0.04, V3.WALL_H * 0.8), 0.018, Color("#8a7350"))
	g.bar(_p(F, 0.1, 0.75, 0.24), _p(F, 0.9, 0.75, 0.24), 0.025, Color("#6a5236"))
	for u in [0.18, 0.82]:
		g.bar(_p(F, u, 0.66, 0), _p(F, u, 0.75, 0.24), 0.016, Color("#4a3a28"))
		g.bar(_p(F, u, 0.84, 0), _p(F, u, 0.75, 0.24), 0.016, Color("#4a3a28"))


## a hand cart, its shafts on the ground
func _cart(g: V3Mesh, F: Array) -> void:
	var wood := Color("#5d4832")
	_box(g, F, 0.4, 1.3, 0.3, 0.74, 0.2, 0.26, wood)
	_box(g, F, 0.4, 1.3, 0.3, 0.33, 0.26, 0.38, wood.darkened(0.12))
	_box(g, F, 0.4, 1.3, 0.71, 0.74, 0.26, 0.38, wood.darkened(0.12))
	_box(g, F, 0.4, 0.43, 0.3, 0.74, 0.26, 0.38, wood.darkened(0.2))
	for d in [0.25, 0.79]:   # the wheels
		_box(g, F, 0.72, 0.98, d - 0.02, d + 0.02, 0, 0.26, Color("#2f2a22"))
	for d in [0.36, 0.68]:
		g.bar(_p(F, 1.3, d, 0.22), _p(F, 1.85, d, 0.02), 0.014, wood)
	if life >= 3:
		_box(g, F, 0.5, 0.8, 0.4, 0.62, 0.26, 0.4, Color("#b8ac8c"))


## a flood gauge: a tall post banded light and dark, a red mark where the last flood came to
func _gauge(g: V3Mesh, F: Array, u: float) -> void:
	for i in 8:
		_box(g, F, u - 0.04, u + 0.04, 0.36, 0.44, i * 0.13, (i + 1) * 0.13, Color("#d8d2bc") if i % 2 == 0 else Color("#2a2c2e"))
	_box(g, F, u - 0.06, u + 0.06, 0.34, 0.46, 0.62, 0.65, Color("#b8402e"))
	_box(g, F, u - 0.06, u + 0.06, 0.34, 0.46, 1.04, 1.08, Color("#4a3a28"))


## a hand winch on a frame, its rope run toward the bridge
func _winch(g: V3Mesh, F: Array, u: float) -> void:
	for d in [0.3, 0.7]:
		g.bar(_p(F, u - 0.16, d, 0), _p(F, u, d, 0.4), 0.022, Color("#4a3a28"))
		g.bar(_p(F, u + 0.16, d, 0), _p(F, u, d, 0.4), 0.022, Color("#4a3a28"))
	g.bar(_p(F, u, 0.26, 0.4), _p(F, u, 0.74, 0.4), 0.06, Color("#8a7350"))
	g.bar(_p(F, u, 0.74, 0.4), _p(F, u, 0.84, 0.4), 0.014, Color("#5b6063"))
	g.bar(_p(F, u, 0.84, 0.4), _p(F, u, 0.84, 0.26), 0.014, Color("#5b6063"))
	g.bar(_p(F, u, 0.5, 0.42), _p(F, u - 0.5, 0.06, 0.05), 0.008, Color("#b8ac8c"))


## sandbags, two courses, the far end slumped where the water got through
func _sandbags(g: V3Mesh, F: Array, n: float) -> void:
	var k := 0
	var u := 0.1
	while u < n - 0.3:
		var c := Color("#8a7d5c") if k % 2 == 0 else Color("#7d7153")
		_box(g, F, u, u + 0.26, 0.3, 0.5, 0, 0.09, c)
		if u < n * 0.62:
			_box(g, F, u + 0.13, u + 0.39, 0.31, 0.49, 0.09, 0.18, c.darkened(0.08))
		u += 0.28
		k += 1
	_box(g, F, n - 0.34, n - 0.08, 0.5, 0.72, 0, 0.08, Color("#7d7153"))


func _reeds(g: V3Mesh, F: Array, u: float, n: int) -> void:
	for i in n:
		var a := vh(int(F[0].x) + i, int(F[0].z), 20 + i)
		var p := _p(F, u + a * 0.25, 0.75 + 0.2 * fposmod(a * 7.0, 1.0), 0)
		g.bar(p, p + Vector3((a - 0.5) * 0.08, 0.3 + a * 0.2, 0.02), 0.01, Color("#4f6a3a") if i % 2 else Color("#6a7a44"))


## bridge timber: a stack of planks on bearers, one end cut fresh
func _planks(g: V3Mesh, F: Array) -> void:
	for u in [0.7, 1.5]:
		_box(g, F, u, u + 0.08, 0.3, 0.74, 0, 0.06, Color("#4a3a28"))
	for i in 3:
		_box(g, F, 0.5, 1.8 - i * 0.1, 0.32 + i * 0.03, 0.72 - i * 0.03, 0.06 + i * 0.05, 0.11 + i * 0.05, Color("#8a7350") if i % 2 == 0 else Color("#7d6846"))


## the pit's headframe: four legs to a crown, braces, the sheave and its cable
func _headframe(g: V3Mesh, F: Array) -> void:
	var st := Color("#4a453e")
	var top := 1.7
	for q in [[0.3, 0.2], [1.7, 0.2], [0.3, 0.9], [1.7, 0.9]]:
		g.bar(_p(F, q[0], q[1], 0), _p(F, 1.0 + (q[0] - 1.0) * 0.3, 0.55 + (q[1] - 0.55) * 0.3, top), 0.03, st)
	for y in [0.55, 1.1]:
		var k: float = 1.0 - 0.7 * y / top
		for d in [0.55 - 0.35 * k, 0.55 + 0.35 * k]:
			g.bar(_p(F, 1.0 - 0.7 * k, d, y), _p(F, 1.0 + 0.7 * k, d, y), 0.02, st.darkened(0.15))
	_box(g, F, 0.72, 1.28, 0.4, 0.7, top, top + 0.06, st.darkened(0.2))
	_box(g, F, 0.84, 1.16, 0.53, 0.57, top + 0.06, top + 0.38, Color("#6b4a36"))   # the sheave, edge on
	g.bar(_p(F, 1.0, 0.55, top + 0.2), _p(F, 1.0, 0.55, 0.0), 0.008, Color("#1c1c1a"))
	_box(g, F, 0.82, 1.18, 0.4, 0.7, 0, 0.1, Color("#2a2622"))


## a site hut: a box under a flat roof, a door and a dark window toward the yard
func _hut(g: V3Mesh, F: Array, wall: Color, roof: Color) -> void:
	_box(g, F, 0.2, 1.9, 0.28, 0.9, 0, 0.56, wall)
	_box(g, F, 0.12, 1.98, 0.2, 0.96, 0.56, 0.61, roof)
	_box(g, F, 0.4, 0.72, 0.265, 0.28, 0, 0.44, Color("#2a2622"))
	_box(g, F, 1.0, 1.6, 0.265, 0.28, 0.24, 0.44, Color("#0f1316"))
	if life >= 3:
		_box(g, F, 1.28, 1.32, 0.26, 0.28, 0.24, 0.44, wall.darkened(0.2))
		_box(g, F, 1.64, 1.86, 0.3, 0.5, 0.61, 0.82, Color("#3a3631"))


## a warning board on a post
func _board(g: V3Mesh, F: Array, u: float) -> void:
	_post(g, F, u, 0.4, 0, 0.5, 0.02, Color("#4a3a28"))
	_box(g, F, u - 0.2, u + 0.2, 0.38, 0.42, 0.5, 0.78, Color("#b89a3a"))
	_box(g, F, u - 0.03, u + 0.03, 0.365, 0.38, 0.6, 0.72, Color("#1a1a16"))
	_box(g, F, u - 0.03, u + 0.03, 0.365, 0.38, 0.54, 0.57, Color("#1a1a16"))


## ore waiting for the lift: heaps sorted by grade, a barrow
func _ore(g: V3Mesh, F: Array) -> void:
	for q in [[0.4, 0.55, 0.3, "#5e584f"], [1.0, 0.5, 0.36, "#6b5a48"], [1.55, 0.6, 0.26, "#4a453e"]]:
		var p := _p(F, q[0], q[1], 0)
		g.prism(p.x, p.z, q[2], p.y, p.y + q[2] * 0.75, Color(q[3]), Color(q[3]).lightened(0.1), 7, q[2] * 0.25)
	if life >= 3:
		_box(g, F, 0.1, 0.34, 0.16, 0.3, 0.06, 0.16, Color("#3a3631"))
		g.bar(_p(F, 0.34, 0.2, 0.12), _p(F, 0.56, 0.2, 0.02), 0.01, Color("#4a3a28"))


## an expedition tent: two slopes to a ridge, a dark mouth toward the yard, guy ropes to pegs, snow on the ridge
func _tent(g: V3Mesh, F: Array) -> void:
	var col := Color("#c8683a")
	var a0 := _p(F, 0.3, 0.25, 0)
	var a1 := _p(F, 1.7, 0.25, 0)
	var b0 := _p(F, 0.3, 0.95, 0)
	var b1 := _p(F, 1.7, 0.95, 0)
	var r0 := _p(F, 0.3, 0.6, 0.52)
	var r1 := _p(F, 1.7, 0.6, 0.52)
	g.quad(a0, a1, r1, r0, col)
	g.quad(b1, b0, r0, r1, col.darkened(0.25))
	g.tri(a0, r0, b0, col.darkened(0.12))
	g.tri(a1, b1, r1, col.darkened(0.3))
	g.quad(_p(F, 0.8, 0.245, 0), _p(F, 1.2, 0.245, 0), _p(F, 1.1, 0.33, 0.3), _p(F, 0.9, 0.33, 0.3), Color("#1a1512"))
	g.quad(_p(F, 0.3, 0.52, 0.47), _p(F, 1.7, 0.52, 0.47), r1 + Vector3(0, 0.004, 0), r0 + Vector3(0, 0.004, 0), Color("#dfedf0"))
	for u in [0.3, 1.7]:
		g.bar(_p(F, u, 0.6, 0.52), _p(F, u + (0.22 if u > 1.0 else -0.22), 0.1, 0.0), 0.007, Color("#c8a03a"))
	if life >= 3:
		_box(g, F, 0.06, 0.22, 0.4, 0.62, 0, 0.16, Color("#456571"))


## the summit beacon's aerial: cross arms and a small dish, high on the pole that is already there
func _antenna(g: V3Mesh) -> void:
	if life < 2:
		return
	var WH := V3.WALL_H
	var b := Vector3(sim.core.i + 2.1, sim.height_at(sim.core.i + 2.1, 0.8) * V3.TER, 0.8)
	for q in [[1.12, 0.2], [0.98, 0.14]]:
		g.bar(b + Vector3(-q[1], WH * q[0], 0), b + Vector3(q[1], WH * q[0], 0), 0.012, Color("#486a7c"))
	g.box(b.x - 0.07, b.z - 0.02, b.x + 0.07, b.z + 0.02, b.y + WH * 0.72, b.y + WH * 0.86, Color("#c8d8dc"), Color("#c8d8dc"), Color("#9fbccb"))
	placed.append(["beacon aerial", "summit", sim.core.i + 2, 1])


func report() -> Dictionary:
	return {"map": sim.map_id, "placed": placed, "skipped": skipped}
