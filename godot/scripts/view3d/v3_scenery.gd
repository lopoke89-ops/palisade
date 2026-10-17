class_name V3Scenery
extends RefCounted
## The static 3D scenery, built once a map from the same numbers the 2D paints with (scenery.gd, city_view.gd,
## casino_view.gd): the land outside the fence (the forest, the river running on, the quarry spoil, Frostpeak's
## snow), the fence or the quarry's rock rim, Frostpeak's caches, beacon, handrails and route flags; the city's ruined
## buildings (in 8x8 pieces, see-through in front of the soldiers), streetlamps and POI structures; the casino's room,
## tables, slots, bar, cage, pillars and its live tables (cards, chips, the wheel). Heights in the 2D's base pixels
## become PXV units, widths across the screen PXH.

const V3 = preload("res://scripts/view3d/view3d.gd")

var W   # V3World
var sim: Sim
var m
var lamp_heads: Array = []   # [Vector3] (lit while the Power Station holds)
var lamp_mi: MeshInstance3D
var lamp_on := -1
var wheel: Node3D   # the roulette wheel (turns)
var felt_mesh: ImmediateMesh
var felt_mi: MeshInstance3D
var felt_mat: StandardMaterial3D
var people: Dictionary = {}   # casino staff and seated bots: key -> Node3D
var root: Node3D


func _init(world) -> void:
	W = world
	sim = world.sim
	m = world.m


func c(h: String) -> Color:
	return Color.html(h)


static func mixc(a: String, b: String, t: float) -> Color:
	return Color.html(a).lerp(Color.html(b), clampf(t, 0, 1))


func build_map(r: Node3D) -> void:
	root = r
	lamp_heads.clear()
	lamp_mi = null
	lamp_on = -1
	wheel = null
	felt_mi = null
	people.clear()
	if sim.casino():
		_casino()
		return
	_outside()
	if sim.map_id == "city":
		_city()


func frame(_dt: float) -> void:
	if sim.map_id == "city" and lamp_mi != null:
		var on := 0 if sim.game.get("dark", false) else 1
		if on != lamp_on:
			lamp_on = on
			var g := V3Mesh.new()
			g.anchor = Vector2(-9999, -9999)
			for p in lamp_heads:
				var col := c("#ffe7a8") if on else c("#2a2c2e")
				if on:
					col.a = 0.05
				g.box(p.x - 0.05, p.z - 0.04, p.x + 0.05, p.z + 0.04, p.y - 0.03, p.y + 0.01, col, col, col)
			lamp_mi.mesh = g.commit()
	if sim.casino():
		_casino_live()


# ---------------------------------------------------------------- outside the yard

## paintBack and the forest: the ground band outside the fence, its trees (the near side's fade), the fence or rim
func _outside() -> void:
	var N: int = sim.N
	var B := Scenery.BAND
	var Q: bool = sim.map_id == "quarry"
	var F := sim.is_frost()
	var g := V3Mesh.new()
	g.anchor = Vector2(-9999, -9999)
	var wv := V3Mesh.new()
	wv.anchor = g.anchor
	var far := c("#161412") if Q else (c("#7c96a3") if F else c("#151a12"))
	var E := 40.0
	g.quad(Vector3(-B - E, -0.02, -B - E), Vector3(-B - E, -0.02, N + B + E), Vector3(N + B + E, -0.02, N + B + E), Vector3(N + B + E, -0.02, -B - E), far)
	for i in range(-B, N + B):
		for j in range(-B, N + B):
			if i >= 0 and j >= 0 and i < N and j < N:
				continue
			var dx := -i if i < 0 else (i - N + 1 if i >= N else 0)
			var dy := -j if j < 0 else (j - N + 1 if j >= N else 0)
			var d := maxi(dx, dy)
			var h := Pal.hash2(i + 400, j + 77)
			if Scenery.out_water(sim, i, j):
				wv.quad(Vector3(i, -0.04, j), Vector3(i + 1, -0.04, j), Vector3(i + 1, -0.04, j + 1), Vector3(i, -0.04, j + 1), c("#1d3848") if h < 0.5 else c("#1b3544"))
				g.quad(Vector3(i, -0.3, j), Vector3(i, -0.3, j + 1), Vector3(i + 1, -0.3, j + 1), Vector3(i + 1, -0.3, j), c("#10202a"))
				continue
			var col: Color
			if F:
				col = mixc("#adc6d1", "#405966", d / 8.0)
			elif Q:
				col = (c("#4a4238") if h < 0.5 else c("#453e35")) if Scenery.ramp_near(sim, i, j) else mixc("#2e2a25", "#35302a", h).lerp(c("#1a1816"), clampf((d - 2) / 6.0, 0, 1))
			elif d == 1:
				col = c("#342d21") if h < 0.5 else c("#2f2a1e")
			else:
				col = mixc("#1f2518", "#262c1b", h).lerp(c("#171c13"), clampf((d - 2) / 6.0, 0, 1))
			g.quad(Vector3(i, 0, j), Vector3(i, 0, j + 1), Vector3(i + 1, 0, j + 1), Vector3(i + 1, 0, j), col)
			if Q and h > 0.7:
				g.disc(i + 0.3 + h * 0.4, j + 0.5, 3 * V3.PXH * 1.4, 1.6 * V3.PXH * 1.4, 0.003, col.lerp(Color8(140, 130, 115), 0.25), 7)
			elif not Q and d >= 2 and h > 0.55:
				W._line(g, Vector2(i + 0.3 + h * 0.4, j + 0.5), Vector2(i + 0.3 + h * 0.4 + 0.09, j + 0.5 - 0.02), 0.02, col.lerp(Color8(107, 84, 51), 0.35))
			elif not Q and d == 1 and h > 0.7:
				g.disc(i + 0.5, j + 0.5, 7 * V3.PXH, 5 * V3.PXH, 0.003, col.lerp(Color8(84, 104, 64), 0.35), 9)
	var gm: MeshInstance3D = W.mesh_node(root, g.commit(), W.mat_ground)
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if wv.size() > 0:
		W.mesh_node(root, wv.commit(), W.mat_water, false)
	var forest := Scenery.gen_forest(sim)
	var back := V3Mesh.new()
	back.anchor = Vector2(-9999, -9999)
	var front := V3Mesh.new()
	for tr in forest[0]:
		_tree(back, tr)
	for tr in forest[1]:
		front.anchor = Vector2(tr.x, tr.y) if tr.kind < 2 else Vector2(-9999, -9999)
		_tree(front, tr)
	for q in N:
		for side in ["n", "w"]:
			_edge(back, side, q)
		for side in ["s", "e"]:
			front.anchor = Vector2(-9999, -9999)
			_edge(front, side, q)
	if F:
		_frost_props(back)
	if back.size() > 0:
		W.mesh_node(root, back.commit(), W.mat_props)
	if front.size() > 0:
		W.mesh_node(root, front.commit(), W.mat_front)


## drawTreeAt in 3D: a pine of three tiers (snow-capped on Frostpeak), a dead tree, a bush, a boulder or a stump
func _tree(g: V3Mesh, t: Dictionary) -> void:
	var x: float = t.x
	var z: float = t.y
	var P := V3.PXV
	var H := V3.PXH
	match int(t.kind):
		0:
			g.prism(x, z, 2.6 * H, 0, 13 * P, c("#45301f"), c("#45301f"), 5)
			var light := mixc("#3d5a35", "#4b5d34", t.v)
			var dk := mixc("#223620", "#2a3a22", t.v)
			for k in 3:
				var by: float = 9 + k * t.h * 0.2
				var w: float = (19 - k * 4.8) * (0.9 + t.v * 0.3)
				var ty: float = by + t.h * 0.44
				g.cone(x, z, w * H, by * P, ty * P, light, dk, 7)
				if t.snow:
					g.cone(x, z, w * 0.68 * H, (by + t.h * 0.12) * P, (ty + 0.5) * P, c("#d9ebef") if k % 2 else c("#b8d5e1"), c("#9fbccb"), 7)
		1:
			var top := Vector3(x, t.h * 0.8 * P, z)
			g.bar(Vector3(x, 0, z), top, 1.9 * H, c("#3d3326"))
			for b in [[0.45, -1, 10], [0.6, 1, 8], [0.72, -1, 6]]:
				var p0 := Vector3(x, t.h * 0.8 * b[0] * P, z)
				var p1: Vector3 = p0 + V3.CAM_R * b[1] * b[2] * H + Vector3(0, b[2] * 0.7 * P, 0)
				g.bar(p0, p1, 1.0 * H, c("#3d3326"))
		2:
			var g1 := mixc("#2c4127", "#394a2a", t.v)
			for b in [[-4, 4, 6], [4, 3.5, 5.5], [0, 7, 6]]:
				var bx: Vector3 = Vector3(x, 0, z) + V3.CAM_R * b[0] * H
				g.prism(bx.x, bx.z, b[2] * H, maxf(0.0, (b[1] - b[2]) * P), (b[1] + b[2] * 0.8) * P, g1, g1.lerp(Color.WHITE, 0.1), 6, b[2] * H * 0.55)
		4:
			var r: float = 8 + t.v * 7
			g.prism(x, z, r * H, 0, r * 1.15 * P, mixc("#5e584f", "#6b645a", t.v), c("#7a7368"), 5, r * 0.45 * H)
		_:
			g.prism(x, z, 5 * H, 0, 6 * P, c("#3a2b1c"), c("#806645"), 7)


## one tile of the yard's edge: the fence (two rails on posts), a gap where the river runs out, or the quarry's rim
func _edge(g: V3Mesh, side: String, s: int) -> void:
	var N: int = sim.N
	var A: Array = [s, 0] if side == "n" else ([0, s] if side == "w" else ([s, N] if side == "s" else [N, s]))
	var B: Array = [A[0] + 1, A[1]] if side == "n" or side == "s" else [A[0], A[1] + 1]
	var out: Array = [s, -1] if side == "n" else ([-1, s] if side == "w" else ([s, N] if side == "s" else [N, s]))
	var in_t: Array = [s, 0] if side == "n" else ([0, s] if side == "w" else ([s, N - 1] if side == "s" else [N - 1, s]))
	if sim.map_id == "river" and (Scenery.out_water(sim, out[0], out[1]) or sim.t_at(in_t[0], in_t[1]) == PalMaps.T_WATER):
		return
	var WH := V3.WALL_H
	if sim.map_id == "city":
		pass
	if sim.map_id == "quarry":
		if Scenery.is_ramp(sim, in_t[0], in_t[1]):
			return
		var h: float = WH * (0.9 + Pal.hash2(s * 3 + (1 if side == "n" else (2 if side == "e" else 3)), 7) * 0.5)
		var col := c("#4a453e") if side == "n" or side == "s" else c("#3c3833")
		var th := 0.12
		if side == "n" or side == "s":
			var z0: float = A[1] - (th if side == "n" else 0.0)
			g.box(A[0], z0, B[0], z0 + th, 0, h, col.lightened(0.08), col, col.darkened(0.15))
		else:
			var x0: float = A[0] - (th if side == "w" else 0.0)
			g.box(x0, A[1], x0 + th, B[1], 0, h, col.lightened(0.08), col.darkened(0.1), col)
		return
	var post := c("#4a3a28")
	var rail := c("#5d4832")
	var pw := 1.6 * V3.PXH
	for p in [A, B]:
		g.box(p[0] - pw, p[1] - pw, p[0] + pw, p[1] + pw, 0, WH * 0.85, post.lightened(0.1), post, post.darkened(0.2))
	for hh in [WH * 0.32, WH * 0.62]:
		g.bar(Vector3(A[0], hh, A[1]), Vector3(B[0], hh, B[1]), 1.1 * V3.PXH, rail)


## Frostpeak's expedition caches, the summit beacon, the stair handrails and the route flags
func _frost_props(g: V3Mesh) -> void:
	var N: int = sim.N
	var WH := V3.WALL_H
	for q in [[-0.6, 3], [N + 0.6, N - 4], [-0.6, N - 3]]:
		var x: float = q[0]
		var y: float = q[1]
		g.box(x - 0.32, y - 0.32, x + 0.32, y + 0.32, 0, WH * 0.3, c("#456571"), c("#203e4c"), c("#304f5a"))
		g.box(x - 0.26, y - 0.06, x + 0.26, y + 0.06, WH * 0.3, WH * 0.3 + 0.02, c("#dfedf0"), c("#dfedf0"), c("#c8d8dc"))
	var b := Vector3(sim.core.i + 2.1, 0, 0.8)
	g.bar(b, b + Vector3(0, WH * 1.5, 0), 0.03, c("#405969"))
	var lit := c("#ffd882")
	lit.a = 0.2
	g.box(b.x - 0.06, b.z - 0.06, b.x + 0.06, b.z + 0.06, WH * 1.45, WH * 1.58, lit, lit, lit)
	var ft := b + Vector3(0, WH * 1.35, 0)
	g.tri(ft + Vector3(0.03, 0, 0), ft + V3.CAM_R * 15 * V3.PXH + Vector3(0, 0.07, 0), ft + Vector3(0.03, 0.18, 0), c("#bd5450"), V3.CAM_B)
	var R := 11 * V3.PXV
	var T := V3.TER
	for j in N:
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
				var P: Array = [0.0, 0.5, 1.0].map(func(f): return Vector3(x, (z + 1 - f) * T, j + f))
				for p in P:
					g.bar(p, p + Vector3(0, R, 0), 0.012, c("#33505f"))
				for n in 2:
					g.bar(P[n] + Vector3(0, R, 0), P[n + 1] + Vector3(0, R, 0), 0.014, c("#486a7c"))
			i += 1
	for k in N * N:
		if sim.connectors[k] != 0 and (not sim.inb(k % N - 1, k / N) or sim.connectors[k - 1] == 0):
			var z: float = sim.heights[k] * T + T * 0.5
			var p := Vector3(k % N + 0.08, z, k / N + 0.5)
			g.bar(p, p + Vector3(0, WH * 0.55, 0), 0.012, c("#486a7c"))
			g.box(p.x, p.z - 0.01, p.x + 7 * V3.PXH * 1.4, p.z + 0.01, p.y + WH * 0.42, p.y + WH * 0.55, c("#efa568"), c("#efa568"), c("#d08a50"))


# ---------------------------------------------------------------- the city

## ground details: road centre dashes, rubble, the sidewalk seam
func city_ground_detail(g: V3Mesh, i: int, j: int, col: Color) -> void:
	var tt: int = sim.terr[sim.idx(i, j)]
	if tt == PalMaps.T_ROAD:
		var dash := col.lerp(Color8(220, 190, 90), 0.32)
		if sim.t_at(i + 1, j) == PalMaps.T_ROAD and sim.t_at(i - 1, j) != PalMaps.T_ROAD and j % 2 == 0:
			W._line(g, Vector2(i + 1, j + 0.2), Vector2(i + 1, j + 0.8), 0.03, dash)
		if sim.t_at(i, j + 1) == PalMaps.T_ROAD and sim.t_at(i, j - 1) != PalMaps.T_ROAD and i % 2 == 0:
			W._line(g, Vector2(i + 0.2, j + 1), Vector2(i + 0.8, j + 1), 0.03, dash)
	elif tt == PalMaps.T_RUBBLE:
		for q in 3:
			var x := i + 0.2 + Pal.hash2(i + q, j) * 0.6
			var y := j + 0.2 + Pal.hash2(i, j + q) * 0.6
			var r := (2 + q) * V3.PXH * 1.4
			g.prism(x, y, r, 0, r * 0.6, c("#5a5048") if q % 2 else c("#4a423a"), c("#5a5048") if q % 2 else c("#4a423a"), 5, r * 0.5)
	elif tt == PalMaps.T_WALK:
		W._line(g, Vector2(i, j + 0.5), Vector2(i + 1, j + 0.5), 0.02, col.darkened(0.18))


## the ruined blocks (by 8x8 pieces), the streetlamps
func _city() -> void:
	var N: int = sim.N
	var lamps := V3Mesh.new()
	lamps.anchor = Vector2(-9999, -9999)
	for cj in range(0, N, 8):
		for ci in range(0, N, 8):
			var g := V3Mesh.new()
			for j in range(cj, mini(N, cj + 8)):
				for i in range(ci, mini(N, ci + 8)):
					if sim.terr[sim.idx(i, j)] == PalMaps.T_BLDG:
						_building(g, i, j)
			if g.size() > 0:
				W.mesh_node(root, g.commit(), W.mat_bldg)
	for l in sim.lay.get("lamps", []):
		var x: float = l[0] + 0.5 + l[2] * 0.38
		var y: float = l[1] + 0.5 + l[3] * 0.38
		var top := Vector3(x, V3.WALL_H * 1.7, y)
		lamps.bar(Vector3(x, 0, y), top, 0.02, c("#3e4245"))
		var hd := Vector3(x + l[2] * 0.3, V3.WALL_H * 1.75, y + l[3] * 0.3)
		lamps.bar(top, hd, 0.016, c("#3e4245"))
		lamp_heads.append(hd)
	if lamps.size() > 0:
		W.mesh_node(root, lamps.commit(), W.mat_props)
	lamp_mi = W.mesh_node(root, ArrayMesh.new(), W.mat_props, false)


## a ruined building tile: its height from its block, walls in the block's palette, a few windows on the south face
func _building(g: V3Mesh, i: int, j: int) -> void:
	var hbv := Pal.hash2((i / 4) * 7 + 3, (j / 4) * 13 + 5)
	var hb := maxi(0, mini(4, floori(hbv * 5)) - (1 if Pal.hash2(i * 3 + 1, j * 5 + 2) > 0.8 else 0))
	var pal := 2 if hbv > 0.7 else (1 if hbv > 0.5 else 0)
	var win := floori(Pal.hash2(i * 5, j * 7) * 4)
	var H := V3.WALL_H * (0.85 + hb * 0.225)
	var Wc: Array = CityView.WALL[pal]
	g.anchor = Vector2(i + 0.5, j + 0.5)
	g.box(i, j, i + 1, j + 1, 0, H, c(Wc[0]), c(Wc[1]), c(Wc[2]))
	if sim.t_at(i, j + 1) != PalMaps.T_BLDG:
		for r in 2:
			for q in 2:
				var lit := ((win >> (r * 2 + q)) & 1) != 0 and win == 3
				var col := c("#ffd278") if lit else c("#0a0a0c")
				if lit:
					col.a = 0.2
				var x0 := i + 0.2 + q * 0.45
				var y0 := H * (0.35 + r * 0.3) - 0.1
				g.quad(Vector3(x0, y0, j + 1.004), Vector3(x0 + 0.13, y0, j + 1.004), Vector3(x0 + 0.13, y0 + 0.1, j + 1.004), Vector3(x0, y0 + 0.1, j + 1.004), col)


## a POI structure (CityView.poi in 3D): the radio mast, the power station, the hospital, the armory compound, the
## gas station, the hardware store, the brickworks, the parking garage; a burnt-out shell once it's lost
func poi(g: V3Mesh, co: Dictionary) -> void:
	var i: float = co.i
	var j: float = co.j
	var WH := V3.WALL_H
	var P := V3.PXV
	var f: bool = co.flash > 0
	var T := func(col: String, hot: String = "#8a4a34") -> Color: return c(hot) if f else c(col)
	if co.lost:
		g.box(i + 0.1, j + 0.15, i + 0.9, j + 0.85, 0, WH * 0.35, c("#2a2622"), c("#1d1a17"), c("#151311"))
		g.box(i + 0.2, j + 0.25, i + 0.55, j + 0.6, WH * 0.35, WH * 0.65, c("#332d27"), c("#231f1b"), c("#1a1714"))
		return
	match str(co.poi.id):
		"radio":
			g.box(i + 0.15, j + 0.15, i + 0.85, j + 0.85, 0, WH * 0.5, T.call("#5a5f63"), T.call("#43474a"), T.call("#33363a"))
			var b := Vector3(i + 0.5, WH * 0.5, j + 0.5)
			var H := WH * 3.4
			var col: Color = T.call("#8a8f93", "#a05a40")
			var leg := 9 * V3.PXH
			var tip := 1.5 * V3.PXH
			for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				g.bar(b + Vector3(s.x * leg, 0, s.y * leg), b + Vector3(s.x * tip, H, s.y * tip), 0.012, col)
			for q in 7:
				var y0 := H * q / 7.0
				var y1 := H * (q + 1) / 7.0
				var w0 := leg * (1 - q / 7.0) + tip * q / 7.0
				var w1 := leg * (1 - (q + 1) / 7.0) + tip * (q + 1) / 7.0
				g.bar(b + Vector3(-w0, y0, w0), b + Vector3(w1, y1, w1), 0.008, col)
				g.bar(b + Vector3(w0, y0, -w0), b + Vector3(w1, y1, w1), 0.008, col)
			var red := c("#ff4a3a")
			red.a = 0.1
			g.box(b.x - 0.04, b.z - 0.04, b.x + 0.04, b.z + 0.04, b.y + H, b.y + H + 0.07, red, red, red)
		"power":
			g.box(i - 0.15, j + 0.2, i + 0.6, j + 0.95, 0, WH * 0.9, T.call("#4d5a52"), T.call("#38423c"), T.call("#2b332e"))
			for q in 3:
				g.box(i + 0.62, j + 0.1 + q * 0.28, i + 0.88, j + 0.3 + q * 0.28, 0, WH * 0.55, T.call("#6b6f5a"), T.call("#505442"), T.call("#3d4033"))
			for q in 5:
				var r := (9 - q * 0.6) * V3.PXH * 1.3
				g.prism(i + 0.25, j + 0.15, r, q * WH * 0.4, (q + 1) * WH * 0.4, T.call("#7a7c78" if q % 2 else "#6a6c68"), c("#2a2b2a"), 10, (9 - (q + 1) * 0.6) * V3.PXH * 1.3)
		"hospital":
			g.box(i - 0.25, j - 0.25, i + 1.15, j + 1.15, 0, WH * 1.5, T.call("#d9dad4"), T.call("#b9bbb4"), T.call("#9c9e98"))
			var cx := i + 0.45
			var cz := j + 0.45
			var y := WH * 1.5 + 0.004
			var red := c("#d23a32")
			g.quad(Vector3(cx - 0.3, y, cz - 0.08), Vector3(cx - 0.3, y, cz + 0.08), Vector3(cx + 0.3, y, cz + 0.08), Vector3(cx + 0.3, y, cz - 0.08), red)
			g.quad(Vector3(cx - 0.08, y, cz - 0.3), Vector3(cx - 0.08, y, cz + 0.3), Vector3(cx + 0.08, y, cz + 0.3), Vector3(cx + 0.08, y, cz - 0.3), red)
			for q in 3:
				var x := i - 0.25 + 1.4 * (0.2 + q * 0.3)
				var gl := Color8(120, 190, 220)
				gl.a = 0.6
				g.quad(Vector3(x - 0.06, WH * 1.0, j + 1.154), Vector3(x + 0.06, WH * 1.0, j + 1.154), Vector3(x + 0.06, WH * 1.18, j + 1.154), Vector3(x - 0.06, WH * 1.18, j + 1.154), gl)
		"armory":
			for b in [[0.1, 0.15, 0.5], [0.5, 0.15, 0.8], [0.1, 0.55, 0.8], [0.5, 0.55, 0.5], [0.3, 0.35, 1.2]]:
				g.box(i + b[0], j + b[1], i + b[0] + 0.38, j + b[1] + 0.36, 0, WH * b[2], T.call("#59633d"), T.call("#434b2e"), T.call("#343a24"))
			for q in [[-0.2, -0.2], [1.2, -0.2], [1.2, 1.2], [-0.2, 1.2]]:
				g.bar(Vector3(i + q[0], 0, j + q[1]), Vector3(i + q[0], WH * 0.9, j + q[1]), 0.015, T.call("#77736a"))
			for e in [[[-0.2, -0.2], [1.2, -0.2]], [[1.2, -0.2], [1.2, 1.2]], [[1.2, 1.2], [-0.2, 1.2]], [[-0.2, 1.2], [-0.2, -0.2]]]:
				g.bar(Vector3(i + e[0][0], WH * 0.8, j + e[0][1]), Vector3(i + e[1][0], WH * 0.8, j + e[1][1]), 0.008, T.call("#77736a"))
			g.box(i + 0.35, j + 0.45, i + 0.65, j + 0.55, WH * 1.2, WH * 1.24, c("#e2b436"), c("#e2b436"), c("#b08a28"))
		"gas":
			g.box(i + 0.45, j - 0.2, i + 1.1, j + 0.45, 0, WH * 0.8, T.call("#6a5f52"), T.call("#524a40"), T.call("#3f3931"))
			g.box(i + 0.2, j + 0.4, i + 0.38, j + 0.6, 0, WH * 0.6, T.call("#c64a36"), T.call("#9e3a2a"), T.call("#7a2d20"))
			for q in [[-0.1, 0.2], [0.7, 0.2], [0.7, 1], [-0.1, 1]]:
				g.bar(Vector3(i + q[0], 0, j + q[1]), Vector3(i + q[0], WH * 1.25, j + q[1]), 0.016, T.call("#9a9890"))
			g.box(i - 0.15, j + 0.15, i + 0.75, j + 1.05, WH * 1.25, WH * 1.4, T.call("#e8e2d0"), T.call("#c63a2e"), T.call("#a02e24"))
		"hardware":
			g.box(i - 0.2, j - 0.2, i + 0.9, j + 0.75, 0, WH * 1.1, T.call("#5b5953"), T.call("#47453f"), T.call("#383631"))
			g.box(i - 0.205, j + 0.745, i + 0.905, j + 0.755, WH * 0.8, WH, c("#d8752a"), c("#d8752a"), c("#b0601f"))
			for q in 3:
				g.box(i + 0.1, j + 0.8, i + 0.9, j + 0.95, q * WH * 0.12, q * WH * 0.12 + WH * 0.11, T.call("#a8834f"), T.call("#87683d"), T.call("#6b5230"))
		"brick":
			g.box(i + 0.05, j + 0.25, i + 0.8, j + 0.95, 0, WH * 0.8, T.call("#8a4a34"), T.call("#6e3a28"), T.call("#55301f"))
			g.box(i + 0.5, j + 0.05, i + 0.75, j + 0.3, 0, WH * 2.4, T.call("#7a3e2c"), T.call("#5e3022"), T.call("#4a261b"))
			var gl := Color8(255, 140, 60)
			gl.a = 0.1
			g.disc(i + 0.625, j + 0.175, 0.07, 0.05, WH * 2.4 + 0.003, gl, 8)
			var mo := Color8(255, 150, 70)
			mo.a = 0.2
			g.quad(Vector3(i + 0.33, WH * 0.3, j + 0.954), Vector3(i + 0.47, WH * 0.3, j + 0.954), Vector3(i + 0.47, WH * 0.4, j + 0.954), Vector3(i + 0.33, WH * 0.4, j + 0.954), mo)
		_:
			for q in 3:
				var z := q * WH * 0.75
				g.box(i - 0.2, j - 0.2, i + 1.2, j + 1.2, z + WH * 0.6, z + WH * 0.75, T.call("#6f716e"), T.call("#585a57"), T.call("#474946"))
				if q < 2:
					for pp in [[-0.1, 1.1], [1.1, 1.1], [1.1, -0.1], [0.5, 1.1], [1.1, 0.5]]:
						g.box(i + pp[0] - 0.05, j + pp[1] - 0.05, i + pp[0] + 0.05, j + pp[1] + 0.05, z + WH * 0.75, z + WH * 1.35, c("#5a5c59"), c("#4a4c49"), c("#3c3e3b"))
			g.box(i + 0.4, j + 0.4, i + 0.6, j + 0.6, WH * 0.75 * 2 + WH * 0.75, WH * 0.75 * 2 + WH * 0.95, c("#e2b436"), c("#e2b436"), c("#b08a28"))


## where each POI's bar and name sit (the top of its structure, as CityView.poi finds it)
func paint_poi_bars() -> void:
	var WH: float = m.v.WH
	var u: float = m.v.u
	for co in sim.cores:
		if not co.has("poi") or co.lost:
			continue
		var i: float = co.i
		var j: float = co.j
		var top: Vector2
		match str(co.poi.id):
			"radio":
				var b: Vector2 = m.iso(i + 0.5, j + 0.5)
				top = Vector2(b.x, b.y - WH * 0.5 - WH * 3.4)
			"power":
				var s: Vector2 = m.iso(i + 0.25, j + 0.15)
				top = Vector2(s.x, s.y - WH * 2.1)
			"hospital":
				var cc: Vector2 = m.iso(i + 0.45, j + 0.45)
				top = Vector2(cc.x, cc.y - WH * 1.5)
			"armory":
				var cc: Vector2 = m.iso(i + 0.5, j + 0.5)
				top = Vector2(cc.x, cc.y - WH * 1.3)
			"gas":
				var cc: Vector2 = m.iso(i + 0.3, j + 0.6)
				top = Vector2(cc.x, cc.y - WH * 1.45)
			"hardware":
				var cc: Vector2 = m.iso(i + 0.35, j + 0.3)
				top = Vector2(cc.x, cc.y - WH * 1.1)
			"brick":
				var cc: Vector2 = m.iso(i + 0.62, j + 0.18)
				top = Vector2(cc.x, cc.y - WH * 2.5)
			_:
				var cc: Vector2 = m.iso(i + 0.5, j + 0.5)
				top = Vector2(cc.x, cc.y - WH * 2.3)
				m.label("P", top.x, top.y + WH * 0.2, m.c("#e2b436"), int(9 * u))
		CityView.poi_bar(m, co, top.x, top.y - 4 * u)


# ---------------------------------------------------------------- the casino

func casino_floor_detail(g: V3Mesh, i: int, j: int, col: Color) -> void:
	if CasinoView._runner(i, j):
		var y := j + (0.08 if j == 9 else 0.92)
		W._line(g, Vector2(i, y), Vector2(i + 1, y), 0.03, col.lerp(Color8(226, 180, 54), 0.55))
		return
	if i >= 12 and j <= 3:
		for f in [0.33, 0.66]:
			W._line(g, Vector2(i, j + f), Vector2(i + 1, j + f), 0.02, col.darkened(0.25))
		return
	if i <= 2 and j >= 12:
		return
	var gold := col.lerp(Color8(214, 170, 70), 0.32)
	var pts := [Vector2(i + 0.5, j + 0.22), Vector2(i + 0.78, j + 0.5), Vector2(i + 0.5, j + 0.78), Vector2(i + 0.22, j + 0.5)]
	for q in 4:
		W._line(g, pts[q], pts[(q + 1) % 4], 0.018, gold)
	g.disc(i + 0.5, j + 0.5, 1.6 * V3.PXH * 1.4, 0.8 * V3.PXH * 1.4 * 2, 0.004, col.lerp(Color8(214, 170, 70), 0.45), 6)
	if (i + j) % 2 == 0:
		g.disc(i, j, 1.2 * V3.PXH * 1.4, 1.2 * V3.PXH * 1.4, 0.004, col.lerp(Color8(60, 170, 160), 0.35), 6)


## the room: the two back walls with the wainscot, trim and the door; the furniture
func _casino() -> void:
	var g := V3Mesh.new()
	g.anchor = Vector2(-9999, -9999)
	var N := 16
	var WH := V3.WALL_H
	var H := WH * 3.4
	var gold := c("#d6aa46")
	var floor_far := V3Mesh.new()
	floor_far.anchor = g.anchor
	floor_far.quad(Vector3(-30, -0.02, -30), Vector3(-30, -0.02, 46), Vector3(46, -0.02, 46), Vector3(46, -0.02, -30), c("#0c0a0a"))
	W.mesh_node(root, floor_far.commit(), W.mat_ground, false)
	for i in N:   # the north wall (its face toward the room, +Z)
		var face := c("#3a0d16") if i % 2 else c("#360c14")
		g.box(i, -0.15, i + 1, 0.0, 0, H, face.darkened(0.2), face, face)
		g.quad(Vector3(i, 0, 0.003), Vector3(i + 1, 0, 0.003), Vector3(i + 1, H * 0.32, 0.003), Vector3(i, H * 0.32, 0.003), c("#24130d"))
		for f in [0.32, 0.34, 0.97]:
			g.bar(Vector3(i, H * f, 0.006), Vector3(i + 1, H * f, 0.006), 0.008, gold)
		g.bar(Vector3(i + 0.5, H * 0.36, 0.006), Vector3(i + 0.5, H * 0.95, 0.006), 0.004, face.lerp(gold, 0.18))
	for j in N:   # the west wall (its face toward the room, +X)
		var face := c("#300a12") if j % 2 else c("#2c0910")
		if j == 9 or j == 10:
			g.box(-0.15, j, 0.0, j + 1, 0, H, c("#2a0a10"), c("#2a0a10"), c("#2a0a10"))
			g.quad(Vector3(0.004, 0, j + 0.06), Vector3(0.004, 0, j + 0.94), Vector3(0.004, H * 0.72, j + 0.94), Vector3(0.004, H * 0.72, j + 0.06), c("#0c1622"))
			for f in [0.06, 0.5, 0.94]:
				g.bar(Vector3(0.008, 0, j + f), Vector3(0.008, H * 0.72, j + f), 0.01, gold)
			g.bar(Vector3(0.008, H * 0.72, j + 0.06), Vector3(0.008, H * 0.72, j + 0.94), 0.01, gold)
			continue
		g.box(-0.15, j, 0.0, j + 1, 0, H, face.darkened(0.2), face, face)
		g.quad(Vector3(0.003, 0, j), Vector3(0.003, 0, j + 1), Vector3(0.003, H * 0.32, j + 1), Vector3(0.003, H * 0.32, j), c("#24130d"))
		for f in [0.32, 0.34, 0.97]:
			g.bar(Vector3(0.006, H * f, j), Vector3(0.006, H * f, j + 1), 0.008, gold.darkened(0.1))
	g.bar(Vector3(0, 0, 0), Vector3(0, H, 0), 0.05, c("#b58a2e"))
	_casino_furniture(g)
	W.mesh_node(root, g.commit(), W.mat_props)
	# the wheel: turned every frame
	CasinoView._ready_data()
	for tb in CasinoView.TABLES:
		if tb.has("wheel"):
			var wg := V3Mesh.new()
			wg.anchor = Vector2(-9999, -9999)
			var rx := 0.62 / V3.SQ2 * 1.25
			for k in 38:
				var a0 := k / 38.0 * TAU
				var a1 := (k + 1) / 38.0 * TAU
				var n: int = CasinoView.RL_WHEEL[k]
				var col := c("#0e7a3a") if n == 0 or n == 37 else (c("#b8202c") if CasinoView.RL_RED.has(n) else c("#141214"))
				wg.tri(Vector3.ZERO, Vector3(cos(a1) * rx, 0, sin(a1) * rx), Vector3(cos(a0) * rx, 0, sin(a0) * rx), col, Vector3.UP)
			wg.disc(0, 0, rx * 0.45, rx * 0.45, 0.004, c("#5a3a14"), 12)
			wg.disc(0, 0, rx * 0.12, rx * 0.12, 0.008, c("#d6aa46"), 8)
			wheel = Node3D.new()
			wheel.position = Vector3(tb.wheel[0], WH * 0.55 + 0.03, tb.wheel[1])
			root.add_child(wheel)
			W.mesh_node(wheel, wg.commit(), W.mat_props, false)
			var rim := V3Mesh.new()
			rim.anchor = Vector2(-9999, -9999)
			rim.prism(tb.wheel[0], tb.wheel[1], rx + 0.05, WH * 0.5, WH * 0.55 + 0.025, c("#3a220f"), c("#3a220f"), 16)
			W.mesh_node(root, rim.commit(), W.mat_props)
	felt_mesh = ImmediateMesh.new()
	felt_mi = MeshInstance3D.new()
	felt_mi.mesh = felt_mesh
	felt_mat = StandardMaterial3D.new()
	felt_mat.vertex_color_use_as_albedo = true
	felt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	felt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	felt_mi.material_override = felt_mat
	felt_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(felt_mi)


func _casino_furniture(g: V3Mesh) -> void:
	CasinoView._ready_data()
	var WH := V3.WALL_H
	var z := WH * 0.55
	var wood := [c("#1d120b"), c("#2a1a10"), c("#22150d")]
	for k in CasinoView.MACHINES.size():   # slot cabinets with their screens and lights
		var mc: Dictionary = CasinoView.MACHINES[k]
		if mc.game != "sl":
			continue
		var x: float = mc.at[0]
		var y: float = mc.at[1]
		var w := 0.36
		var s: bool = mc.face == "s"
		var fx: Array = [x - w, y - 0.3, x + w, y + 0.25] if s else [x - 0.3, y - w, x + 0.25, y + w]
		g.box(fx[0], fx[1], fx[2], fx[3], 0, WH * 1.35, c("#2b2a30"), c("#1c1b20"), c("#151418"))
		var hue: String = ["#ff4a6a", "#3ae0ff", "#ffd24a", "#9a6aff", "#4aff9a"][k % 5]
		var scr := c(hue)
		scr.a = 0.3
		var sy := WH * 0.92
		if s:
			g.quad(Vector3(x - 0.14, sy - 0.07, fx[3] + 0.004), Vector3(x + 0.14, sy - 0.07, fx[3] + 0.004), Vector3(x + 0.14, sy + 0.08, fx[3] + 0.004), Vector3(x - 0.14, sy + 0.08, fx[3] + 0.004), scr)
		else:
			g.quad(Vector3(fx[2] + 0.004, sy - 0.07, y + 0.14), Vector3(fx[2] + 0.004, sy - 0.07, y - 0.14), Vector3(fx[2] + 0.004, sy + 0.08, y - 0.14), Vector3(fx[2] + 0.004, sy + 0.08, y + 0.14), scr)
		var lamp := c(hue)
		lamp.a = 0.15
		g.prism((fx[0] + fx[2]) / 2, (fx[1] + fx[3]) / 2, 0.09, WH * 1.35, WH * 1.35 + 0.05, lamp, lamp, 8)
	for q in CasinoView.BAR.back:
		g.box(q[0] + 0.05, q[1] + 0.05, q[0] + 0.95, q[1] + 0.7, 0, WH * 1.6, c("#2a1a10"), c("#3a2414"), c("#2e1c10"))
	for q in 9:
		var bc := c(["#3ae08a", "#d6aa46", "#9a2a2a", "#5ab0ff"][q % 4])
		g.prism(13.2 + q * 0.3, 0.75, 0.03, WH * 1.6, WH * 1.6 + 0.12, bc, bc, 5)
	g.box(12.05, 2.15, 16, 2.85, 0, WH * 0.85, c("#5a3418"), c("#3a2212"), c("#2e1a0e"))
	g.box(12, 2.1, 16, 2.9, WH * 0.85, WH * 0.91, c("#d6aa46"), c("#a8832f"), c("#8a6a26"))
	for st in CasinoView.BAR.stools:
		_stool(g, st[0], st[1], "#7a1020")
	# the cashier's cage
	g.box(0.05, 13.05, 2, 16, 0, WH * 1.1, c("#4a3a26"), c("#3a2c1c"), c("#2e2316"))
	for q in 9:
		g.bar(Vector3(2, WH * 1.1, 13.15 + q * 0.32), Vector3(2, WH * 1.85, 13.15 + q * 0.32), 0.008, c("#d6aa46"))
	g.box(0.05, 13.05, 2, 16, WH * 1.85, WH * 1.97, c("#d6aa46"), c("#a8832f"), c("#8a6a26"))
	for q in CasinoView.PILLARS:
		g.box(q[0] + 0.18, q[1] + 0.18, q[0] + 0.82, q[1] + 0.82, 0, WH * 0.25, c("#b58a2e"), c("#7e6222"), c("#66501c"))
		g.box(q[0] + 0.25, q[1] + 0.25, q[0] + 0.75, q[1] + 0.75, WH * 0.25, WH * 3.2, c("#d6aa46"), c("#9c7a2a"), c("#7e6222"))
	g.box(12.1, 14.15, 13.9, 14.85, 0, WH * 0.35, c("#6a1424"), c("#4a0e19"), c("#3c0b14"))
	g.box(12.1, 14.6, 13.9, 14.85, WH * 0.35, WH * 0.75, c("#7a1828"), c("#5a1220"), c("#4a0e19"))
	for q in 5:   # the velvet ropes along the entrance
		for y in [8.75, 11.25]:
			var x := 1.4 + q * 1.1
			g.prism(x, y, 0.025, 0, WH * 0.75, c("#d6aa46"), c("#e8c86a"), 6)
			if q < 4:
				var a := Vector3(x, WH * 0.62, y)
				var b := Vector3(x + 1.1, WH * 0.62, y)
				var mid := (a + b) / 2 - Vector3(0, WH * 0.12, 0)
				var prev := a
				for s in range(1, 9):
					var f := s / 8.0
					var p := a.lerp(mid, f).lerp(mid.lerp(b, f), f)
					g.bar(prev, p, 0.012, c("#8a1020"))
					prev = p
	# Plinko: the stand and the board
	var px: float = CasinoView.PLINKO.at[0]
	var py: float = CasinoView.PLINKO.at[1]
	g.box(px - 0.45, py - 0.45, px + 0.45, py + 0.45, 0, WH * 0.2, c("#2a1a10"), c("#3a2414"), c("#2e1c10"))
	var bw := 0.62 / V3.SQ2 * 1.2
	var y0 := WH * 0.2
	var y1 := y0 + WH * 2.6
	g.box(px - 0.04, py - bw, px + 0.04, py + bw, y0, y1, c("#121018"), c("#121018"), c("#121018"))
	for e in [[y0, y0 + 0.015], [y1 - 0.015, y1]]:
		g.box(px - 0.05, py - bw, px + 0.05, py + bw, e[0], e[1], c("#d6aa46"), c("#d6aa46"), c("#d6aa46"))
	for r in 12:
		for k in r + 1:
			var zz := py + (k - r / 2.0) * bw * 1.7 / 12
			var yy := y1 - (y1 - y0) * (0.06 + 0.8 * (r + 1) / 13.0)
			g.box(px - 0.06, zz - 0.006, px - 0.04, zz + 0.006, yy - 0.006, yy + 0.006, c("#e8e0cf"), c("#e8e0cf"), c("#e8e0cf"))
	for k in 13:
		var mv: float = CasinoView.PK_MULT[k] / 10.0
		var col := c("#ff4a6a" if mv >= 9 else ("#ffb43a" if mv >= 3 else ("#4aff9a" if mv >= 1 else "#3a8aff")))
		col.a = 0.4
		var zz := py - bw * 0.85 + (k + 0.5) * bw * 1.7 / 13
		g.box(px - 0.06, zz - bw * 0.055, px - 0.045, zz + bw * 0.055, y0 + (y1 - y0) * 0.03, y0 + (y1 - y0) * 0.1, col, col, col)
	# the tables
	for tb in CasinoView.TABLES:
		_table(g, tb, z, wood)
		for k in tb.seats.size():
			var sp: Array = tb.seats[k]
			if tb.game == "he":
				g.box(sp[0] - 0.17, sp[1] - 0.17, sp[0] + 0.17, sp[1] + 0.17, WH * 0.22, WH * 0.3, c("#7a1020"), c("#5a0c18"), c("#4a0a14"))
				g.prism(sp[0], sp[1], 0.03, 0, WH * 0.22, c("#2a1b10"), c("#2a1b10"), 5)
			else:
				_stool(g, sp[0], sp[1], "#a01830")


func _stool(g: V3Mesh, x: float, y: float, top: String) -> void:
	g.prism(x, y, 0.025, 0, 7 * V3.PXV, c("#2a1b10"), c("#2a1b10"), 5)
	g.prism(x, y, 4.6 * V3.PXH * 1.4, 7 * V3.PXV, 8.5 * V3.PXV, c(top).darkened(0.2), c(top), 10)


func _table(g: V3Mesh, tb: Dictionary, z: float, wood: Array) -> void:
	var WH := V3.WALL_H
	var rail := c("#4a2a14")
	match tb.game:
		"bj", "ba":
			var cx: float = tb.c[0]
			var cy: float = 3.8 if tb.game == "bj" else 7.0
			var ry: float = 1.15 if tb.game == "bj" else 1.1
			g.box(cx - 1.4, cy - 0.05, cx + 1.4, cy + (1.15 if tb.game == "bj" else 0.95), 0, z * 0.9, wood[0], wood[1], wood[2])
			var felt := c("#0f5a34") if tb.game == "bj" else c("#3a1450")
			var n := 20
			for q in n:
				var a0 := PI * q / n
				var a1 := PI * (q + 1) / n
				g.tri(Vector3(cx, z, cy), Vector3(cx + cos(a1) * 1.45, z, cy + sin(a1) * ry), Vector3(cx + cos(a0) * 1.45, z, cy + sin(a0) * ry), felt, Vector3.UP)
				g.bar(Vector3(cx + cos(a0) * 1.45, z + 0.01, cy + sin(a0) * ry), Vector3(cx + cos(a1) * 1.45, z + 0.01, cy + sin(a1) * ry), 0.03, rail)
				if tb.game == "bj":
					var cr := felt.lerp(Color8(226, 200, 120), 0.45)
					g.bar(Vector3(cx + cos(a0) * 0.95, z + 0.003, cy + sin(a0) * 0.72), Vector3(cx + cos(a1) * 0.95, z + 0.003, cy + sin(a1) * 0.72), 0.006, cr)
			g.bar(Vector3(cx - 1.45, z + 0.01, cy), Vector3(cx + 1.45, z + 0.01, cy), 0.03, rail)
			if tb.game == "bj":
				g.box(5.45, 3.85, 5.75, 4.1, z, z + WH * 0.12, c("#d8cfb8"), c("#a99e86"), c("#8c826c"))
			else:
				for q in [[0, Color(90 / 255.0, 170 / 255.0, 1)], [1, Color(1, 90 / 255.0, 90 / 255.0)], [2, Color(120 / 255.0, 230 / 255.0, 140 / 255.0)]]:
					g.disc(7.85 + q[0] * 0.65, 7.75, 0.16, 0.16, z + 0.004, felt.lerp(q[1], 0.5), 10)
		"he":
			g.box(7.1, 3.2, 9.9, 4.8, 0, z * 0.88, wood[0], wood[1], wood[2])
			g.disc(8.5, 4.0, 1.45, 0.95, z, c("#0f5a34"), 28)
			for q in 28:
				var a0 := TAU * q / 28
				var a1 := TAU * (q + 1) / 28
				g.bar(Vector3(8.5 + cos(a0) * 1.45, z + 0.01, 4.0 + sin(a0) * 0.95), Vector3(8.5 + cos(a1) * 1.45, z + 0.01, 4.0 + sin(a1) * 0.95), 0.03, c("#5a3412"))
		"cr":
			g.box(4.05, 12.05, 7.95, 13.95, 0, z * 0.9, wood[0], wood[1], wood[2])
			g.box(4.15, 12.15, 7.85, 13.85, z * 0.9, z * 0.9 + WH * 0.03, c("#0f5a34"), c("#0b4528"), c("#0a3d24"))
			var lc := c("#0f5a34").lerp(Color8(240, 230, 200), 0.55)
			var zz := z * 0.9 + WH * 0.03 + 0.003
			for y in [12.45, 13.55]:
				g.bar(Vector3(4.35, zz, y), Vector3(7.65, zz, y), 0.005, lc)
			for q in 7:
				var x := 4.6 + q * 0.45
				g.bar(Vector3(x, zz, 12.6), Vector3(x, zz, 13.0), 0.005, lc)
			for e in [[4.05, 12.05, 7.95, 12.05], [7.95, 12.05, 7.95, 13.95], [7.95, 13.95, 4.05, 13.95], [4.05, 13.95, 4.05, 12.05]]:
				g.bar(Vector3(e[0], z + 0.03, e[1]), Vector3(e[2], z + 0.03, e[3]), 0.03, rail)
		_:
			g.box(11.05, 7.15, 14.0, 8.85, 0, z * 0.88, wood[0], wood[1], wood[2])
			g.box(11.05, 7.15, 13.0, 8.85, z * 0.88, z * 0.88 + WH * 0.04, c("#0f5a34"), c("#0b4528"), c("#0a3d24"))
			var lc := c("#0f5a34").lerp(Color8(240, 230, 200), 0.5)
			var zz := z * 0.88 + WH * 0.04 + 0.003
			for q in 13:
				var x := 11.15 + q * 0.15
				g.bar(Vector3(x, zz, 7.35), Vector3(x, zz, 8.65), 0.004, lc)
			for r in 4:
				var y := 7.35 + r * 1.3 / 3
				g.bar(Vector3(11.15, zz, y), Vector3(12.95, zz, y), 0.004, lc)
			for q in 12:
				for r in 3:
					var nn := q * 3 + (3 - r)
					if CasinoView.RL_RED.has(nn):
						g.disc(11.15 + q * 0.15 + 0.075, 7.35 + r * 1.3 / 3 + 0.21, 0.04, 0.04, zz + 0.002, c("#0f5a34").lerp(Color8(200, 30, 40), 0.6), 6)


## the casino's moving parts: the wheel's turn, and what's on the tables (cards, chips) from the tables' views
func _casino_live() -> void:
	var ui = m.get("casino_ui")
	if wheel != null:
		var S: Dictionary = ui.wheel_state() if ui != null and ui.has_method("wheel_state") else {"rot": Time.get_ticks_msec() / 1000.0 * 0.25, "ball": null}
		wheel.rotation = Vector3(0, -float(S.get("rot", 0.0)), 0)
	if felt_mesh == null:
		return
	felt_mesh.clear_surfaces()
	var quads: Array = []   # [corners..., colour]
	var z := V3.WALL_H * 0.55 + 0.012
	var card := func(x: float, y: float, cd) -> void:
		var col := c("#3a5ab0") if cd == null else c("#f4efe4")
		quads.append([Vector3(x - 0.07, z, y - 0.1), Vector3(x + 0.07, z, y - 0.1), Vector3(x + 0.07, z, y + 0.1), Vector3(x - 0.07, z, y + 0.1), col])
		if cd != null:
			var suit := (int(cd) % 52) / 13
			var sc := c("#c02030") if suit == 1 or suit == 2 else c("#141214")
			quads.append([Vector3(x - 0.03, z + 0.002, y - 0.03), Vector3(x + 0.03, z + 0.002, y - 0.03), Vector3(x + 0.03, z + 0.002, y + 0.03), Vector3(x - 0.03, z + 0.002, y + 0.03), sc])
	var chips := func(x: float, y: float, n: float) -> void:
		if not (n > 0):
			return
		var h := mini(8, 1 + floori(log(n + 1) / log(2)))
		for q in h:
			var col := c("#d6aa46") if q % 2 else c("#b8202c")
			var yy := z + q * 0.025
			quads.append([Vector3(x - 0.05, yy, y - 0.05), Vector3(x + 0.05, yy, y - 0.05), Vector3(x + 0.05, yy, y + 0.05), Vector3(x - 0.05, yy, y + 0.05), col])
	for tb in CasinoView.TABLES:
		var view = ui.view_for(tb.game) if ui != null and ui.has_method("view_for") else null
		if not (view is Dictionary) or view.is_empty():
			continue
		match tb.game:
			"bj":
				var dl: Array = view.get("dealer", []) if view.get("dealer") is Array else []
				for q in dl.size():
					card.call(4.1 + q * 0.22, 3.95, dl[q])
				for p in view.get("players", []):
					if not (p is Dictionary) or int(p.get("seat", -1)) >= tb.seats.size() or int(p.get("seat", -1)) < 0:
						continue
					var s: Array = tb.seats[int(p.seat)]
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
					if not (p is Dictionary) or p.get("folded", false) or int(p.get("seat", -1)) < 0 or int(p.get("seat", -1)) >= tb.seats.size():
						continue
					var s: Array = tb.seats[int(p.seat)]
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
	if quads.is_empty():
		return
	felt_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in quads:
		var col: Color = q[4]
		for v in [q[0], q[1], q[2], q[0], q[2], q[3]]:
			felt_mesh.surface_set_color(col)
			felt_mesh.surface_add_vertex(v)
	felt_mesh.surface_end()
