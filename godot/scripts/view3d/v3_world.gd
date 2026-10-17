class_name V3World
extends Node3D
## The world in 3D, read from the sim: the ground and its terrain (Frostpeak's terraces, ramps and stairs, Riverbend's
## water, bridges and floods, the quarry's pits, cracks, rocks and burning drums), the scenery round the yard
## (V3Scenery: the forest, the fence or the quarry rim, Frostpeak's props, the city's buildings, POIs and lamps, the
## casino room), the walls and doors (one MultiMesh, wall.gdshader), debris, resource piles, kilns and scrap, the
## stake(s) and the build ghost. Static pieces are built once a map (and again when the terrain changes); walls are
## refilled every frame from the tiles on screen; props are cached meshes keyed by their look and only rebuilt when
## that changes.

const V3 = preload("res://scripts/view3d/view3d.gd")
const WORLD_SH := preload("res://shaders/v3/world.gdshader")
const WALL_SH := preload("res://shaders/v3/wall.gdshader")
const WATER_SH := preload("res://shaders/v3/water.gdshader")
const FLOOD_SH := preload("res://shaders/v3/flood.gdshader")
const SUN_K := 0.2   # with the ambient (View3D.AMBIENT) a lit face shows its 2D colour

var V
var sim: Sim
var m
var dirty := true
var map_key := ""
var terr_key := ""
var mat_ground: ShaderMaterial
var mat_props: ShaderMaterial
var mat_front: ShaderMaterial   # trees and fences in front of the yard: fade when someone stands behind
var mat_bldg: ShaderMaterial   # the city's buildings: fade in front of the soldiers
var mat_wall: ShaderMaterial
var mat_water: ShaderMaterial
var mat_flood: ShaderMaterial
var map_root: Node3D   # rebuilt with the map
var terr_root: Node3D   # rebuilt with the terrain
var wall_mm: MultiMesh
var wall_mi: MultiMeshInstance3D
var props_root: Node3D
var props := {}   # prop id -> {mi, skey, seen}
var cache := {}   # look key -> ArrayMesh
var debris_mi: MeshInstance3D
var debris_sig := PackedInt32Array()
var ghost: MeshInstance3D
var ghost_mesh: ImmediateMesh
var ghost_mat: StandardMaterial3D
var flood_mi: MeshInstance3D
var flood_lv := 0.0
var t := 0.0
var frame_n := 0
var burning: Array = []   # [x, y, top y] of every burning wall on screen (the effects layer puts flames there)
var drums: Array = []   # [x, y, top y] of every oil drum (flames)
var scenery: V3Scenery
var vis := [0, 0, 0, 0]   # tiles on screen: i0, i1, j0, j1


func _init(view) -> void:
	V = view
	sim = view.sim
	m = view.m
	name = "World"
	mat_ground = _world_mat(0.0, 0.0)
	mat_props = _world_mat(0.0, 0.0)
	mat_front = _world_mat(5.5, 1.6)
	mat_bldg = _world_mat(4.5, 2.6)
	mat_wall = ShaderMaterial.new()
	mat_wall.shader = WALL_SH
	var tops: Array = []
	var ls: Array = []
	var rs: Array = []
	var lines: Array = []
	for k in 4:
		var M: Dictionary = Pal.MAT[k]
		tops.append(_v4(Color.html(M.top)))
		ls.append(_v4(Color.html(M.l)))
		rs.append(_v4(Color.html(M.r)))
		lines.append(_v4(M.line))
	tops.append(_v4(Color.html("#6f695f")))   # the Foreman's rock slab
	ls.append(_v4(Color.html("#524d46")))
	rs.append(_v4(Color.html("#403c37")))
	lines.append(Vector4(0, 0, 0, 0))
	mat_wall.set_shader_parameter("top_c", tops)
	mat_wall.set_shader_parameter("left_c", ls)
	mat_wall.set_shader_parameter("right_c", rs)
	mat_wall.set_shader_parameter("line_c", lines)
	mat_wall.set_shader_parameter("door_c", [_v4(Color.html("#3d2a17")), _v4(Color.html("#3a2418")), _v4(Color.html("#3b4142")), _v4(Color.html("#3b4142")), _v4(Color.html("#403c37"))])
	mat_wall.set_shader_parameter("sun_k", SUN_K)
	mat_water = ShaderMaterial.new()
	mat_water.shader = WATER_SH
	mat_water.set_shader_parameter("sun_k", SUN_K)
	mat_flood = ShaderMaterial.new()
	mat_flood.shader = FLOOD_SH
	mat_flood.set_shader_parameter("sun_k", SUN_K)
	mat_flood.set_shader_parameter("alpha", 0.0)
	map_root = Node3D.new()
	add_child(map_root)
	terr_root = Node3D.new()
	add_child(terr_root)
	props_root = Node3D.new()
	add_child(props_root)
	wall_mm = MultiMesh.new()
	wall_mm.transform_format = MultiMesh.TRANSFORM_3D
	wall_mm.use_custom_data = true
	var cube := V3Mesh.new()
	cube.box(0, 0, 1, 1, 0, 1, Color.WHITE, Color.WHITE, Color.WHITE)
	wall_mm.mesh = cube.commit()
	wall_mi = MultiMeshInstance3D.new()
	wall_mi.multimesh = wall_mm
	wall_mi.material_override = mat_wall
	add_child(wall_mi)
	debris_mi = MeshInstance3D.new()
	debris_mi.material_override = mat_props
	add_child(debris_mi)
	ghost_mesh = ImmediateMesh.new()
	ghost = MeshInstance3D.new()
	ghost.mesh = ghost_mesh
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost_mat = StandardMaterial3D.new()
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.vertex_color_use_as_albedo = true
	ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost_mat.no_depth_test = false
	ghost.material_override = ghost_mat
	add_child(ghost)
	scenery = V3Scenery.new(self)


static func _v4(c: Color) -> Vector4:
	return Vector4(c.r, c.g, c.b, c.a)


func _world_mat(fade_d: float, fade_w: float) -> ShaderMaterial:
	var mt := ShaderMaterial.new()
	mt.shader = WORLD_SH
	mt.set_shader_parameter("fade", Vector3(fade_d, fade_w, 0.32))
	mt.set_shader_parameter("sun_k", SUN_K)
	return mt


func mesh_node(parent: Node3D, mesh: ArrayMesh, mat: Material, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func c(h: String) -> Color:
	return Color.html(h)


# ---------------------------------------------------------------- the frame

func frame(dt: float) -> void:
	t += dt
	frame_n += 1
	_vis()
	var mk := "%s|%d|%d|%d" % [sim.map_id, sim.N, m.game_n, 1 if sim.casino() else 0]
	if mk != map_key or dirty:
		map_key = mk
		dirty = false
		terr_key = ""
		for ch in map_root.get_children():
			ch.queue_free()
		for k in props.keys():
			props[k].mi.queue_free()
		props.clear()
		cache.clear()
		scenery.build_map(map_root)
	var tk := "%s|%d|%d" % [mk, sim.terr_log.size(), sim.terr.size()]
	if tk != terr_key:
		terr_key = tk
		for ch in terr_root.get_children():
			ch.queue_free()
		_build_terrain()
	_who()
	_walls()
	_debris()
	_props()
	_ghost()
	flood_lv += ((1.0 if sim.flood_on else 0.0) - flood_lv) * minf(1.0, dt * 1.2)
	mat_flood.set_shader_parameter("alpha", flood_lv * 0.7)
	mat_flood.set_shader_parameter("t", t)
	mat_water.set_shader_parameter("t", t)
	if flood_mi != null:
		flood_mi.visible = flood_lv > 0.02
	scenery.frame(dt)


## the tiles on screen (with the margin the quality knobs give), as _vis_bounds does for the 2D
func _vis() -> void:
	var v: IsoView = m.v
	var N: int = sim.N
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for q in [Vector2(0, 0), Vector2(v.W, 0), Vector2(0, v.H + v.WH * 4), Vector2(v.W, v.H + v.WH * 4)]:
		var w := v.screen_to_world(q.x, q.y)
		lo = Vector2(minf(lo.x, w.x), minf(lo.y, w.y))
		hi = Vector2(maxf(hi.x, w.x), maxf(hi.y, w.y))
	var mg := int(ceil(Quality3D.draw_margin)) + 2
	vis = [clampi(floori(lo.x) - mg, 0, N - 1), clampi(ceili(hi.x) + mg, 0, N - 1), clampi(floori(lo.y) - mg, 0, N - 1), clampi(ceili(hi.y) + mg, 0, N - 1)]


## who the see-through rules watch: trees fade for anyone behind them, buildings and walls for the soldiers
func _who() -> void:
	var all: Array = []
	var mine: Array = []
	for p in sim.players.values():
		if (p.alive or p.downed) and not p.get("out", false):
			all.append(Vector4(p.x, p.y, 0, 0))
			mine.append(Vector4(p.x, p.y, 0, 0))
	if sim.qm.get("alive", false):
		all.append(Vector4(sim.qm.x, sim.qm.y, 0, 0))
	for e in sim.enemies:
		if all.size() >= 24:
			break
		if not e.dead:
			all.append(Vector4(e.x, e.y, 0, 0))
	for mt in [[mat_front, all], [mat_bldg, mine]]:
		var arr: Array = mt[1].slice(0, 24)
		var n := arr.size()
		while arr.size() < 24:
			arr.append(Vector4.ZERO)
		mt[0].set_shader_parameter("who", arr)
		mt[0].set_shader_parameter("who_n", n)
	var p: Dictionary = sim.player
	mat_wall.set_shader_parameter("me", Vector2(p.x, p.y) if p.alive else Vector2(-99, -99))


# ---------------------------------------------------------------- terrain

## the ground of the yard (each map its own), its water and flood, bridges, pits, cracks, rocks and drums
func _build_terrain() -> void:
	var N: int = sim.N
	var g := V3Mesh.new()
	g.sim = sim
	g.anchor = Vector2(-9999, -9999)
	var w := V3Mesh.new()
	w.anchor = g.anchor
	var fl := V3Mesh.new()
	fl.anchor = g.anchor
	var pr := V3Mesh.new()
	pr.sim = sim
	pr.anchor = g.anchor
	var frost := sim.is_frost()
	var city: bool = sim.map_id == "city"
	var cas := sim.casino()
	drums.clear()
	for j in N:
		for i in N:
			var k := j * N + i
			var tt: int = sim.terr[k]
			var h := Pal.hash2(i, j)
			if frost:
				_frost_tile(g, pr, i, j)
				if tt == PalMaps.T_ROCK or tt == PalMaps.T_DRUM:
					_terr_item(pr, i, j, tt)
				continue
			if tt == PalMaps.T_WATER or tt == PalMaps.T_BRIDGE:
				w.quad(Vector3(i, -0.04, j), Vector3(i + 1, -0.04, j), Vector3(i + 1, -0.04, j + 1), Vector3(i, -0.04, j + 1), m._ground_col(i, j, h))
				g.quad(Vector3(i, -0.3, j), Vector3(i + 1, -0.3, j), Vector3(i + 1, -0.3, j + 1), Vector3(i, -0.3, j + 1), c("#10202a"))
				if tt == PalMaps.T_BRIDGE:
					_bridge(pr, i, j)
				continue
			var col: Color
			if cas:
				col = CasinoView.ground_col(m, i, j, h)
			elif city:
				col = CityView.ground_col(m, i, j, h)
			else:
				col = m._ground_col(i, j, h)
			if tt == PalMaps.T_PIT:
				_pit(g, i, j, col)
				continue
			g.quad(Vector3(i, 0, j), Vector3(i, 0, j + 1), Vector3(i + 1, 0, j + 1), Vector3(i + 1, 0, j), col)
			if tt == PalMaps.T_LOW:
				fl.quad(Vector3(i, 0.025, j), Vector3(i, 0.025, j + 1), Vector3(i + 1, 0.025, j + 1), Vector3(i + 1, 0.025, j), c("#23475a"))
			if cas:
				scenery.casino_floor_detail(g, i, j, col)
				continue
			if city:
				scenery.city_ground_detail(g, i, j, col)
				continue
			if tt == PalMaps.T_CRACK:
				_crack(g, i, j)
			elif tt == PalMaps.T_ROCK or tt == PalMaps.T_DRUM:
				_terr_item(pr, i, j, tt)
			elif sim.map_id == "quarry":
				if h > 0.8:
					g.disc(i + 0.3 + h * 0.4, j + 0.5, 2.4 * V3.PXH * 1.4, 1.4 * V3.PXH * 1.4, 0.003, col.lerp(Color8(150, 140, 120), 0.3), 8)
			elif h > 0.86:
				var off := (h - 0.9) * 40 * V3.PXH
				g.disc(i + 0.5 + off * 0.7, j + 0.5 - off * 0.7, 6 * V3.PXH, 4.4 * V3.PXH, 0.003, col.lerp(Color8(84, 104, 64), 0.35), 9)
	var am := g.commit()
	var gmi := mesh_node(terr_root, am, mat_ground)
	gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if frost else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mat_ground.set_shader_parameter("grid", 0.0 if city or cas else 0.2)
	if w.size() > 0:
		mesh_node(terr_root, w.commit(), mat_water, false)
	if pr.size() > 0:
		mesh_node(terr_root, pr.commit(), mat_props)
	flood_mi = null
	if fl.size() > 0:
		flood_mi = mesh_node(terr_root, fl.commit(), mat_flood, false)


func _bridge(pr: V3Mesh, i: int, j: int) -> void:
	pr.box(i, j + 0.08, i + 1, j + 0.92, -0.05, 0.02, c("#5a4330"), c("#4a3626"), c("#3e2c1e"))
	for s in range(1, 6):
		var x := i + s / 6.0
		pr.box(x - 0.012, j + 0.08, x + 0.012, j + 0.92, 0.02, 0.024, c("#2a1d12"), c("#2a1d12"), c("#2a1d12"))
	for yy in [j + 0.08, j + 0.92]:
		pr.box(i, yy - 0.02, i + 1, yy + 0.02, 0.02, 0.02 + 3 * V3.PXV * 1.4, c("#3a2a1c"), c("#2c2016"), c("#241a12"))


## a pit blown in the quarry floor: a dark hole with its far walls showing (the 2D's north and west faces)
func _pit(g: V3Mesh, i: int, j: int, col: Color) -> void:
	var d := -V3.WALL_H * 0.35
	var a := 0.04
	var b := 0.96
	g.quad(Vector3(i, 0, j), Vector3(i, 0, j + a), Vector3(i + 1, 0, j + a), Vector3(i + 1, 0, j), col)
	g.quad(Vector3(i, 0, j + b), Vector3(i, 0, j + 1), Vector3(i + 1, 0, j + 1), Vector3(i + 1, 0, j + b), col)
	g.quad(Vector3(i, 0, j + a), Vector3(i, 0, j + b), Vector3(i + a, 0, j + b), Vector3(i + a, 0, j + a), col)
	g.quad(Vector3(i + b, 0, j + a), Vector3(i + b, 0, j + b), Vector3(i + 1, 0, j + b), Vector3(i + 1, 0, j + a), col)
	g.quad(Vector3(i + a, d, j + a), Vector3(i + a, d, j + b), Vector3(i + b, d, j + b), Vector3(i + b, d, j + a), c("#0b0908"))
	g.quad(Vector3(i + a, d, j + a), Vector3(i + b, d, j + a), Vector3(i + b, 0, j + a), Vector3(i + a, 0, j + a), c("#1c1713"))
	g.quad(Vector3(i + a, d, j + b), Vector3(i + a, d, j + a), Vector3(i + a, 0, j + a), Vector3(i + a, 0, j + b), c("#241d18"))
	g.quad(Vector3(i + b, d, j + a), Vector3(i + b, d, j + b), Vector3(i + b, 0, j + b), Vector3(i + b, 0, j + a), c("#120e0c"))
	g.quad(Vector3(i + b, d, j + b), Vector3(i + a, d, j + b), Vector3(i + a, 0, j + b), Vector3(i + b, 0, j + b), c("#100c0a"))


func _crack(g: V3Mesh, i: int, j: int) -> void:
	var p := Vector2(i + 0.2 + Pal.hash2(i, j + 3) * 0.2, j + 0.25 + Pal.hash2(i + 9, j) * 0.2)
	var dark := Color8(30, 24, 20)
	for s in 4:
		var q := p + Vector2(0.14 + Pal.hash2(i + s, j * 3) * 0.1, 0.1 + Pal.hash2(i * 7, j + s) * 0.12)
		_line(g, p, q, 0.022, dark)
		p = q
	_line(g, Vector2(i + 0.5, j + 0.5), Vector2(i + 0.3, j + 0.8), 0.022, dark)


func _line(g: V3Mesh, a: Vector2, b: Vector2, w: float, col: Color, y: float = 0.004) -> void:
	var d := (b - a).normalized().orthogonal() * w * 0.5
	g.quad(Vector3(a.x - d.x, y, a.y - d.y), Vector3(a.x + d.x, y, a.y + d.y), Vector3(b.x + d.x, y, b.y + d.y), Vector3(b.x - d.x, y, b.y - d.y), col)


## rock outcrops and oil drums (terrShape): a rock stands, a drum burns (its flames are the effects layer's)
func _terr_item(pr: V3Mesh, i: int, j: int, tt: int) -> void:
	var b := sim.height_at(i + 0.5, j + 0.5) * V3.TER
	if tt == PalMaps.T_ROCK:
		var hr := Pal.hash2(i + 3, j + 17)
		var h0 := b + V3.WALL_H * (0.75 + hr * 0.3)
		pr.box(i + 0.08, j + 0.12, i + 0.9, j + 0.88, b, h0, c("#6b655b"), c("#4e4a43"), c("#3c3934"))
		pr.box(i + 0.2 + hr * 0.2, j + 0.2, i + 0.7 + hr * 0.2, j + 0.62, h0, h0 + V3.WALL_H * (0.25 + hr * 0.2), c("#787166"), c("#58534b"), c("#45413b"))
		return
	var r := 0.34 / V3.SQ2
	var hh := V3.WALL_H * 0.9
	var cx := i + 0.5
	var cz := j + 0.5
	pr.prism(cx, cz, r, b, b + hh, c("#3b2f24"), c("#1a1411"), 10)
	for f in [0.33, 0.66]:
		pr.prism(cx, cz, r + 0.006, b + hh * f - 0.02, b + hh * f + 0.02, c("#2a211a"), c("#2a211a"), 10)
	drums.append([cx, cz, b + hh])


## paintFrostTile: the terrace's snowy top (sloped on a ramp or stair), its cliff faces where it drops, the treads
func _frost_tile(g: V3Mesh, pr: V3Mesh, i: int, j: int) -> void:
	var N: int = sim.N
	var k := sim.idx(i, j)
	var z: int = sim.heights[k]
	var r: int = sim.connectors[k]
	var h := Pal.hash2(i + 6, j + 31)
	var T := V3.TER
	var yn := (z + (1 if r else 0)) * T
	var ys := z * T
	var top := c("#acc9d8") if r else (c("#dceaf0") if h > 0.55 else c("#c8dee8"))
	g.quad(Vector3(i, yn, j), Vector3(i, ys, j + 1), Vector3(i + 1, ys, j + 1), Vector3(i + 1, yn, j), top)
	var lowS: int = (sim.heights[k + N] + (1 if sim.connectors[k + N] != 0 else 0)) if j + 1 < N else 0
	var lowE: int = sim.heights[k + 1] if i + 1 < N else 0
	var lowW: int = sim.heights[k - 1] if i > 0 else 0
	var lowN: int = sim.heights[k - N] if j > 0 else 0
	if z > lowS:
		g.quad(Vector3(i, lowS * T, j + 1), Vector3(i + 1, lowS * T, j + 1), Vector3(i + 1, ys, j + 1), Vector3(i, ys, j + 1), c("#435b6a"))
		_bar_edge(pr, Vector3(i, ys + 0.008, j + 1), Vector3(i + 1, ys + 0.008, j + 1), c("#dcebf1"))
		pr.bar(Vector3(i + 0.2, ys, j + 1.004), Vector3(i + 0.35, lowS * T, j + 1.004), 0.006, c("#719aaa"))
	if z > lowE:
		g.quad(Vector3(i + 1, lowE * T, j + 1), Vector3(i + 1, lowE * T, j), Vector3(i + 1, yn, j), Vector3(i + 1, ys, j + 1), c("#304858"))
		_bar_edge(pr, Vector3(i + 1, yn + 0.008, j), Vector3(i + 1, ys + 0.008, j + 1), c("#b9d0da"))
	if z > lowW and not r:
		g.quad(Vector3(i, lowW * T, j), Vector3(i, lowW * T, j + 1), Vector3(i, ys, j + 1), Vector3(i, yn, j), c("#3a5260"))
	if z > lowN:
		g.quad(Vector3(i + 1, lowN * T, j), Vector3(i, lowN * T, j), Vector3(i, yn, j), Vector3(i + 1, yn, j), c("#3a5260"))
	if r:
		var n := 5 if r == 2 else 2
		for q in range(1, n + 1):
			var f := float(q) / (n + 1)
			var y := (z + 1 - f) * T + 0.01
			pr.bar(Vector3(i, y, j + f), Vector3(i + 1, y, j + f), 0.012 if r == 2 else 0.007, c("#547b90") if r == 2 else c("#e7f5fa"))
	elif h > 0.83:
		g.disc(i + 0.5, j + 0.5, 0.05, 0.02, ys + 0.004, c("#ffffff").lerp(top, 0.45), 6)


func _bar_edge(pr: V3Mesh, a: Vector3, b: Vector3, col: Color) -> void:
	pr.bar(a, b, 0.012, col)


# ---------------------------------------------------------------- walls

## every wall and door on screen into the MultiMesh: its material and door, its damage state (lower when wrecked),
## the char from burning and the hit flash; the Foreman's slabs are rough grey blocks with a cap
func _walls() -> void:
	var N: int = sim.N
	var buf := PackedFloat32Array()
	var n := 0
	burning.clear()
	var WH := V3.WALL_H
	for j in range(vis[2], vis[3] + 1):
		for i in range(vis[0], vis[1] + 1):
			var w = sim.walls[j * N + i]
			if w == null:
				continue
			var hz := sim.height_at(i + 0.5, j + 0.5) * V3.TER
			if w.get("slab", false):
				var sst := Pal.wall_state(w)
				var sh := WH * (0.45 if sst == 2 else (0.6 if sst == 1 else 0.72))
				var hs := Pal.hash2(i + 7, j + 3)
				_inst(buf, i + 0.1, j + 0.14, 0.8, 0.72, hz, sh, 4, 0, 0.0, 1.0 if w.flash > 0 else 0.0)
				_inst(buf, i + 0.22 + hs * 0.2, j + 0.24, 0.4, 0.36, hz + sh, WH * 0.18, 4, 0, 0.0, 0.0)
				n += 2
				continue
			var st := Pal.wall_state(w)
			var h := WH * (0.58 if st == 2 else 1.0)
			var code: int = int(w.mat) + (8 if w.get("door", false) else 0)
			_inst(buf, i + 0.03, j + 0.03, 0.94, 0.94, hz, h, code, st, float(w.get("char", 0.0)), 1.0 if w.get("flash", 0.0) > 0 else 0.0)
			n += 1
			if w.get("fire", 0.0) > 0:
				burning.append([i + 0.5, j + 0.5, hz + h])
	if wall_mm.instance_count != n:
		wall_mm.instance_count = n
	if n > 0:
		wall_mm.buffer = buf
	wall_mi.visible = n > 0


func _inst(buf: PackedFloat32Array, x: float, z: float, sx: float, sz: float, y: float, sy: float, code: int, st: int, ch: float, fl: float) -> void:
	# a 3x4 transform, row by row (basis rows with the origin last), then the custom data
	buf.append_array([sx, 0.0, 0.0, x, 0.0, sy, 0.0, y, 0.0, 0.0, sz, z, float(code), float(st), ch, fl])


## wrecked walls leave debris: four low chips per tile in the wall's colours
func _debris() -> void:
	if sim.debris == debris_sig:
		return
	debris_sig = sim.debris.duplicate()
	var g := V3Mesh.new()
	g.anchor = Vector2(-9999, -9999)
	var N: int = sim.N
	for k in sim.debris.size():
		if sim.debris[k] == 0:
			continue
		var i := k % N
		var j := k / N
		var M: Dictionary = Pal.MAT[sim.debris[k] - 1]
		var hz := sim.height_at(i + 0.5, j + 0.5) * V3.TER
		for q in 4:
			var hs := Pal.hash2(i * 5 + q, j * 3 + q)
			var hs2 := Pal.hash2(i * 3 + q, j * 7 + q)
			g.box(i + 0.15 + hs * 0.55, j + 0.15 + hs2 * 0.55, i + 0.3 + hs * 0.55, j + 0.3 + hs2 * 0.55, hz, hz + 3 * V3.PXV, c(M.top).darkened(0.25), c(M.l).darkened(0.25), c(M.r).darkened(0.25))
	debris_mi.mesh = g.commit() if g.size() > 0 else null


# ---------------------------------------------------------------- props: piles, kilns, scrap, stakes, POIs

func _tile_on(i: float, j: float, mg: float = 2.0) -> bool:
	return i >= vis[0] - mg and i <= vis[1] + mg and j >= vis[2] - mg and j <= vis[3] + mg


## a prop drawn from a cached mesh: built the first time its look key comes up
func _prop(id: String, skey: String, build: Callable, mat: Material = null) -> void:
	var P: Dictionary = props.get(id, {})
	if P.is_empty():
		var mi := MeshInstance3D.new()
		mi.material_override = mat if mat != null else mat_props
		props_root.add_child(mi)
		P = {"mi": mi, "skey": ""}
		props[id] = P
	if P.skey != skey:
		if not cache.has(skey):
			var g := V3Mesh.new()
			g.sim = sim
			g.anchor = Vector2(-9999, -9999)
			build.call(g)
			cache[skey] = g.commit()
		P.mi.mesh = cache[skey]
		P.skey = skey
	P.seen = frame_n
	P.mi.visible = true


func _props() -> void:
	for n in sim.nodes:
		if not _tile_on(n.i, n.j):
			continue
		var layers := ceili(n.amt / 16.0) if n.type == 0 else 0
		var sk := "n|%d|%d|%d|%d|%d" % [n.i, n.j, n.type, layers, 1 if n.locked else 0]
		_prop("n%d_%d" % [n.i, n.j], sk, _node.bind(n, layers))
	if sim.pvp() == "base":
		for co in sim.cores:
			_stake_prop(co)
	elif sim.map_id == "city":
		for co in sim.cores:
			if co.has("poi"):
				if _tile_on(co.i, co.j, 4):
					var sk := "poi|%s|%d|%d|%d|%d" % [co.poi.id, co.i, co.j, 1 if co.lost else 0, 1 if co.flash > 0 else 0]
					_prop("poi%d_%d" % [co.i, co.j], sk, scenery.poi.bind(co))
			else:
				_stake_prop(co)
	elif sim.pvp() == "" and not sim.casino():
		_stake_prop(sim.core)
	for k in props.keys():
		var P: Dictionary = props[k]
		if P.get("seen", -1) != frame_n:
			P.mi.visible = false


func _stake_prop(co: Dictionary) -> void:
	if co.is_empty() or not _tile_on(co.i, co.j, 3):
		return
	var band: String = Pal.TEAMS[co.team].col if Pal.TEAMS.has(str(co.get("team", ""))) else "#e2b436"
	var f: bool = co.flash > 0
	var sk := "stake|%d|%d|%s|%d" % [co.i, co.j, band, 1 if f else 0]
	_prop("s%d_%d" % [co.i, co.j], sk, _stake.bind(co, band, f))


## the stake: a dark green post with a band round it and a flag on a pole (the band in the team's colour in PvP)
func _stake(g: V3Mesh, co: Dictionary, band: String, f: bool) -> void:
	var i: int = co.i
	var j: int = co.j
	var hz := sim.height_at(i + 0.5, j + 0.5) * V3.TER
	var WH := V3.WALL_H
	g.box(i + 0.14, j + 0.14, i + 0.86, j + 0.86, hz, hz + WH * 1.15, c("#8a4a34") if f else c("#4d5c40"), c("#6a3424") if f else c("#38452e"), c("#50281c") if f else c("#2a3421"))
	var bc := c(band)
	g.box(i + 0.13, j + 0.13, i + 0.87, j + 0.87, hz + WH * 0.62, hz + WH * 0.8, bc, bc, bc.darkened(0.15))
	var top := Vector3(i + 0.5, hz + WH * 1.15, j + 0.5)
	var ptop := top + Vector3(0, 28 * V3.PXV, 0)
	g.bar(top, ptop, 0.018, c("#1b1812"))
	var tip := ptop + V3.CAM_R * 15 * V3.PXH - Vector3(0, 4 * V3.PXV, 0)
	g.tri(ptop, tip, ptop - Vector3(0, 9 * V3.PXV, 0), bc, V3.CAM_B)


## a resource pile (wood stacked in layers as it's used up), a kiln with its glowing mouth and chimney, or scrap
func _node(g: V3Mesh, n: Dictionary, layers: int) -> void:
	var i: int = n.i
	var j: int = n.j
	var hz := sim.height_at(i + 0.5, j + 0.5) * V3.TER
	var WH := V3.WALL_H
	var P := V3.PXV
	if n.type == 0:
		if layers == 0:
			g.box(i + 0.3, j + 0.4, i + 0.7, j + 0.55, hz, hz + 2 * P, c("#6b4a28"), c("#4f361d"), c("#3e2a16"))
			return
		for s in layers:
			var y0 := hz + s * 5 * P
			g.box(i + 0.18, j + 0.22, i + 0.82, j + 0.48, y0, y0 + 5 * P, c("#c09058"), c("#8b6236"), c("#6b4a28"))
			g.box(i + 0.18, j + 0.52, i + 0.82, j + 0.78, y0, y0 + 5 * P, c("#b8894f"), c("#86603a"), c("#654626"))
	elif n.type == 1:
		var lk: bool = n.locked
		var cs := [c("#6a5048"), c("#4c3a34"), c("#3a2c28")] if lk else [c(Pal.MAT[1].top), c(Pal.MAT[1].l), c(Pal.MAT[1].r)]
		g.box(i + 0.1, j + 0.1, i + 0.9, j + 0.9, hz, hz + WH * 1.05, cs[0], cs[1], cs[2])
		# the mouth on the south face, glowing while the kiln burns
		var mouth := c("#1a1412") if lk else c("#2a0f06")
		_face_oval(g, i + 0.5, j + 0.903, hz + WH * 0.3, 5 * V3.PXH * 1.5, 7 * P, mouth)
		if not lk:
			var glow := c("#ff8c32")
			glow.a = 0.6   # lit: the world shader makes it glow
			_face_oval(g, i + 0.5, j + 0.906, hz + WH * 0.27, 3.4 * V3.PXH * 1.5, 4.5 * P, glow)
		g.box(i + 0.55, j + 0.15, i + 0.8, j + 0.4, hz + WH * 1.05, hz + WH * 1.95, cs[0], cs[1], cs[2])
	else:
		var cs := [c("#5d6262"), c("#454a4a"), c("#353939")] if n.locked else [c(Pal.MAT[2].top), c(Pal.MAT[2].l), c(Pal.MAT[2].r)]
		g.box(i + 0.12, j + 0.2, i + 0.62, j + 0.7, hz, hz + WH * 0.5, cs[0], cs[1], cs[2])
		g.box(i + 0.45, j + 0.1, i + 0.9, j + 0.55, hz, hz + WH * 0.8, cs[0], cs[1], cs[2])
		g.box(i + 0.3, j + 0.55, i + 0.85, j + 0.9, hz, hz + WH * 0.3, cs[0], cs[1], cs[2])


## an oval painted on a south-facing (+Z) wall: centre x, the face's z, centre height y, half-width rx, half-height ry
func _face_oval(g: V3Mesh, x: float, z: float, y: float, rx: float, ry: float, col: Color) -> void:
	var cc := Vector3(x, y, z)
	var n := 10
	for q in n:
		var a0 := TAU * q / n
		var a1 := TAU * (q + 1) / n
		g.tri(cc, Vector3(x + cos(a0) * rx, y + sin(a0) * ry, z), Vector3(x + cos(a1) * rx, y + sin(a1) * ry, z), col, Vector3.BACK)


# ---------------------------------------------------------------- the build ghost

func _ghost() -> void:
	ghost_mesh.clear_surfaces()
	var p: Dictionary = sim.player
	if not p.alive or sim.game.phase == "over" or sim.casino() or m.demo:
		return
	var tg := sim.build_target(p, sim.game.sel, sim.game.piece == "door")
	if not sim.inb(tg.i, tg.j):
		return
	var col := Color(0.56, 0.88, 0.63, 0.28) if tg.ok else Color(0.84, 0.35, 0.23, 0.25)
	var y := sim.height_at(tg.i + 0.5, tg.j + 0.5) * V3.TER + 0.012
	var i: float = tg.i
	var j: float = tg.j
	ghost_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(i, y, j), Vector3(i + 1, y, j), Vector3(i + 1, y, j + 1), Vector3(i, y, j), Vector3(i + 1, y, j + 1), Vector3(i, y, j + 1)]:
		ghost_mesh.surface_set_color(col)
		ghost_mesh.surface_add_vertex(v)
	var lc := Color(col, 0.8)
	var e := 0.025
	for s in [[Vector3(i, y, j), Vector3(i + 1, y, j), Vector3(0, 0, e)], [Vector3(i, y, j + 1), Vector3(i + 1, y, j + 1), Vector3(0, 0, -e)], [Vector3(i, y, j), Vector3(i, y, j + 1), Vector3(e, 0, 0)], [Vector3(i + 1, y, j), Vector3(i + 1, y, j + 1), Vector3(-e, 0, 0)]]:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var d: Vector3 = s[2]
		for v in [a, b, b + d, a, b + d, a + d]:
			ghost_mesh.surface_set_color(lc)
			ghost_mesh.surface_add_vertex(v + Vector3(0, 0.002, 0))
	ghost_mesh.surface_end()


# ---------------------------------------------------------------- labels (main canvas)

func paint_labels() -> void:
	var u: float = m.v.u
	var WH: float = m.v.WH
	for n in sim.nodes:
		if n.locked and _tile_on(n.i, n.j, 0):
			var cc: Vector2 = m.iso(n.i + 0.5, n.j + 0.5)
			m.label("%s · OPENS RAID %d" % ["KILN" if n.type == 1 else "SCRAP", n.unlock], cc.x, cc.y - WH * 2.1, m.c("#9a8f7a"), 10)
	if sim.pvp() == "base":
		for co in sim.cores:
			var band: String = Pal.TEAMS[co.team].col if Pal.TEAMS.has(str(co.get("team", ""))) else "#e2b436"
			var top: Vector2 = m.iso(co.i + 0.5, co.j + 0.5)
			m.label("YOUR STAKE" if co.team == sim.player.team else "ENEMY STAKE", top.x, top.y - WH * 1.15 - 36 * u, m.c(band), 10)
	if sim.map_id == "city":
		scenery.paint_poi_bars()
