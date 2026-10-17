class_name V3Fx
extends Node3D
## Effects in 3D, read from the sim and the main node's effect lists every frame:
## - bullets: the library's tracer rounds (models/tracers, nose first along the flight) with a ribbon per
##   tracer_profiles.json (palette mode, width, fade, glitch/void/arc/chain/pulse kinds; flag tracers take the shot's
##   colour from b.tc, so each round advances the cycle) and the motes they shed; raiders' rounds a plain orange line
## - kill effects: the library's models/kill_effects split into their pieces once, played with the approved motion
##   (previews/motion/preview.js: birth over 0.32 s, drift from 1.1 s, fade 1.65..2.45 s, per-family moves), with a halo
##   and a ground ring; the browser's cosmetic particles stay painted by the 2D code over the 3D view (CosArt)
## - particles (main.parts: blood, dust, splinters, sparks, chunks, fire, smoke) as camera-facing quads in MultiMeshes
## - fire on the ground, napalm gas, mines, frost, burning walls and oil drums, explosion rings, Molotov fires
## - rockets, lobbed grenades, bottles, slabs, missiles and shells in flight (with the landing ring for missiles),
##   the Blue Butcher's arcs, breaching charges, dropped sacks, the Foreman's mound, the dazed Bulldozer's stars,
##   the medic's reach, burning and slowed raiders, ripples round anyone wading.
## Budgets: Quality3D.max_tracers bullet models (ribbons for the rest), Quality3D.max_kill_fx live kill effects,
## Quality3D.effects thins the particles.

const V3 = preload("res://scripts/view3d/view3d.gd")
const ORANGE := Color(1, 140 / 255.0, 90 / 255.0, 0.95)

var V
var sim: Sim
var m
var lib: ArtLibrary
var profiles := {}   # tracer key -> profile
var t := 0.0
var quad: ArrayMesh
var mm_sq: MultiMesh   # alpha-blended squares (dust, blood, chunks)
var mm_smoke: MultiMesh   # soft alpha (smoke)
var mm_add: MultiMesh   # soft additive (sparks, fire, flames, glows)
var buf_sq := PackedFloat32Array()
var buf_smoke := PackedFloat32Array()
var buf_add := PackedFloat32Array()
var rib: ArrayMesh   # additive ribbons (tracers, arcs), refilled every frame in one upload
var rib_mix: ArrayMesh   # normal-blended ribbons (void cores, flag rounds)
var decal: ArrayMesh   # on the ground: rings, fire, gas, frost, shadows
var rib_v := []   # [verts, cols] batched before committing
var mix_v := []
var dec_v := []
var bullets := {}   # bullet id -> {node, key}
var bpool := {}   # tracer key -> [Node3D]
var kills: Array = []   # live kill effects: {node, key, x, y, age, pieces}
var kpool := {}   # kill key -> [Node3D]
var kpieces := {}   # kill key -> [{mesh, home}] (or [] when it has no model)
var props := {}   # small things (rockets, lobs, charges, sacks, mounds): id -> Node3D
var prop_seen := {}
var meshes := {}   # shared little meshes
var mat_prop: ShaderMaterial
var frame_n := 0


func _init(view) -> void:
	V = view
	sim = view.sim
	m = view.m
	lib = view.lib
	name = "Fx"
	var tp = JSON.parse_string(FileAccess.get_file_as_string(ArtLibrary.ROOT + "/tracer_profiles.json")) if FileAccess.file_exists(ArtLibrary.ROOT + "/tracer_profiles.json") else null
	if tp is Dictionary:
		for p in tp.get("profiles", []):
			profiles[str(p.key)] = p
	quad = ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	var R: Vector3 = V3.CAM_R
	var U: Vector3 = V3.CAM_U
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([(-R - U) * 0.5, (R - U) * 0.5, (R + U) * 0.5, (-R - U) * 0.5, (R + U) * 0.5, (-R + U) * 0.5])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(0, 0)])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var soft := _radial()
	mm_sq = _mm(_mat(false, null))
	mm_smoke = _mm(_mat(false, soft))
	mm_add = _mm(_mat(true, soft))
	rib = _imm(_mat(true, null))
	rib_mix = _imm(_mat(false, null))
	decal = _imm(_mat(false, null))
	mat_prop = V.world.mat_props


static func _radial() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.45))
	var tx := GradientTexture2D.new()
	tx.gradient = g
	tx.fill = GradientTexture2D.FILL_RADIAL
	tx.fill_from = Vector2(0.5, 0.5)
	tx.fill_to = Vector2(1.0, 0.5)
	tx.width = 64
	tx.height = 64
	return tx


func _mat(add: bool, tex: Texture2D) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.vertex_color_use_as_albedo = true
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	mt.disable_receive_shadows = true
	if add:
		mt.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if tex != null:
		mt.albedo_texture = tex
	return mt


func _mm(mt: Material) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mt
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mm


func _imm(mt: Material) -> ArrayMesh:
	var im := ArrayMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = mt
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return im


func clear() -> void:
	for k in bullets.keys():
		_park_bullet(k)
	for kf in kills:
		_park_kill(kf)
	kills.clear()
	for k in props.keys():
		props[k].queue_free()
	props.clear()


func on_flash(_e: Dictionary) -> void:
	pass


# ---------------------------------------------------------------- the frame

func frame(dt: float) -> void:
	t += dt
	frame_n += 1
	buf_sq.clear()
	buf_smoke.clear()
	buf_add.clear()
	rib_v = [PackedVector3Array(), PackedColorArray()]
	mix_v = [PackedVector3Array(), PackedColorArray()]
	dec_v = [PackedVector3Array(), PackedColorArray()]
	prop_seen.clear()
	_particles()
	_bullets()
	_kills(dt)
	_ground()
	_flames()
	_flying(dt)
	_smalls()
	_commit_mm(mm_sq, buf_sq)
	_commit_mm(mm_smoke, buf_smoke)
	_commit_mm(mm_add, buf_add)
	_commit_imm(rib, rib_v)
	_commit_imm(rib_mix, mix_v)
	_commit_imm(decal, dec_v)
	for k in props.keys():
		if not prop_seen.has(k):
			props[k].queue_free()
			props.erase(k)


func _commit_mm(mm: MultiMesh, buf: PackedFloat32Array) -> void:
	var n := buf.size() / 16
	if mm.instance_count != n:
		mm.instance_count = n
	if n > 0:
		mm.buffer = buf


func _commit_imm(im: ArrayMesh, v: Array) -> void:
	im.clear_surfaces()
	var vs: PackedVector3Array = v[0]
	if vs.is_empty():
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_COLOR] = v[1]
	im.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)


## a camera-facing quad of size s at p into one of the particle MultiMeshes
func _q(buf: PackedFloat32Array, p: Vector3, s: float, col: Color) -> void:
	buf.append_array([s, 0.0, 0.0, p.x, 0.0, s, 0.0, p.y, 0.0, 0.0, s, p.z, col.r, col.g, col.b, col.a])


func _tri(v: Array, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	v[0].append_array([a, b, c])
	v[1].append_array([ca, cb, cc])


func _quad4(v: Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_tri(v, a, b, c, ca, cb, cc)
	_tri(v, a, c, d, ca, cc, cd)


func _on(x: float, y: float, pad: float = 2.0) -> bool:
	var vis: Array = V.world.vis
	return x >= vis[0] - pad and x <= vis[1] + 1 + pad and y >= vis[2] - pad and y <= vis[3] + 1 + pad


# ---------------------------------------------------------------- particles (main.parts)

func _particles() -> void:
	var keep: float = Quality3D.effects
	var n := 0
	for q in m.parts:
		n += 1
		if keep < 1.0 and fmod(n * 0.618, 1.0) > keep:
			continue
		var a: float = clampf(q.life / q.max, 0, 1)
		var p := Vector3(q.x, sim.height_at(q.x, q.y) * V3.TER + q.z * V3.PXV, q.y)
		var col: Color = q.col
		match q.kind:
			"smoke":
				col.a = a * 0.5
				_q(buf_smoke, p, 0.12 * (1.6 - a * 0.6) * q.s, col)
			"spark", "fire":
				col.a = a
				_q(buf_add, p, 0.07 * q.s, col)
			_:
				col.a = a
				_q(buf_sq, p, 0.053 * q.s, col)


# ---------------------------------------------------------------- bullets and tracers

func _shade(P: Dictionary, f: float, tc: int) -> Color:
	var pal: Dictionary = P.palette
	var cols: Array = pal.colors
	match str(pal.mode):
		"shot_cycle":
			return Color.html(cols[posmod(tc, cols.size())])
		"spectrum":
			return Color.from_hsv(fmod(t * 0.2 + f * 0.78, 1.0), 0.5, 1.0)
	if cols.size() == 1:
		return Color.html(cols[0])
	var u := clampf(f, 0, 0.999999) * (cols.size() if pal.mode == "bands" else cols.size() - 1)
	var i := floori(u)
	if pal.mode == "bands":
		return Color.html(cols[i])
	return Color.html(cols[i]).lerp(Color.html(cols[mini(i + 1, cols.size() - 1)]), u - i)


func _bullet_y(b: Dictionary) -> float:
	if b.has("z0"):
		return (sim.bullet_z(b) - 0.7) * V3.TER + V3.WALL_H * 0.62
	return sim.height_at(b.x, b.y) * V3.TER + V3.WALL_H * 0.62


func _bullets() -> void:
	var models := 0
	var live := {}
	var cap: int = Quality3D.max_tracers
	for b in sim.bullets:
		if b.get("dead", false) or not _on(b.x, b.y, 1.0):
			continue
		var sp := Vector2(b.vx, b.vy).length()
		if sp < 0.01:
			continue
		var d2 := Vector2(b.vx, b.vy) / sp
		var head := Vector3(b.x, _bullet_y(b), b.y)
		var dir := Vector3(d2.x, b.get("zSlope", 0.0) * V3.TER, d2.y).normalized()
		var travelled: float = maxf(0.0, b.get("dist", 0.0)) + 0.33
		if b.team != 0:   # a raider's round: a plain orange line
			_ribbon_line(head, dir, minf(0.018 * sp, travelled), 0.024 * (1.4 if b.get("heavy", false) else 1.0), ORANGE)
			continue
		var key: String = str(b.get("tr", "std"))
		var P: Dictionary = profiles.get(key, profiles.get("std", {}))
		if P.is_empty():
			_ribbon_line(head, dir, minf(0.018 * sp, travelled), 0.02, Color(1, 0.92, 0.67, 0.95))
			continue
		var st: Dictionary = P.get("source_style", {})
		var L: float = 0.018 * clampf(float(st.get("len", 1.0)), 0.6, 2.0) * sp
		var w: float = 0.04 * float(st.get("w", 1.0)) * (1.45 if b.get("heavy", false) else 1.0)
		var tc := int(b.get("tc", 0))
		var scale := 0.62
		var emit := head - dir * 0.42 * scale
		_tracer_ribbon(P, emit, dir, minf(L, travelled), w, tc)
		if models < cap:
			models += 1
			var node := _bullet_node(int(b.id), key)
			if node != null:
				node.position = head
				var x := dir
				var y := Vector3.UP if absf(x.y) < 0.95 else Vector3.RIGHT
				var z := x.cross(y).normalized()
				y = z.cross(x).normalized()
				node.basis = Basis(x, y, z).scaled(Vector3.ONE * scale)
				node.visible = true
				live[int(b.id)] = true
		_shed(b, P, emit, dir)
		# the rear compound's halo
		var gc := Color.html(str(P.palette.glow)) if P.palette.mode != "shot_cycle" and P.palette.mode != "spectrum" else _shade(P, 0.0, tc)
		gc.a = float(P.glow.strength) * 0.9
		_q(buf_add, emit, float(P.glow.radius) * 2.6, gc)
	for id in bullets.keys():
		if not live.has(id):
			_park_bullet(id)


func _bullet_node(id: int, key: String) -> Node3D:
	if bullets.has(id):
		var B: Dictionary = bullets[id]
		if B.key == key:
			return B.node
		_park_bullet(id)
	var free: Array = bpool.get(key, [])
	var n: Node3D = free.pop_back() if not free.is_empty() else null
	if n == null:
		n = lib.instantiate_file("models/tracers/%s.glb" % key)
		if n == null:
			n = lib.instantiate_file("models/tracers/std.glb")
		if n == null:
			return null
		for g in ArtLibrary._all(n):
			if g is GeometryInstance3D:
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(n)
	bullets[id] = {"node": n, "key": key}
	return n


func _park_bullet(id) -> void:
	var B: Dictionary = bullets.get(id, {})
	bullets.erase(id)
	if B.is_empty() or not is_instance_valid(B.node):
		return
	B.node.visible = false
	if not bpool.has(B.key):
		bpool[B.key] = []
	bpool[B.key].append(B.node)


## a tapering ribbon behind a round: two crossed strips (flat and upright) and a narrow core, coloured by the
## profile's palette from head to tail, fading as (1 - f)^1.7 (tracer-effects.js update())
func _tracer_ribbon(P: Dictionary, base: Vector3, dir: Vector3, L: float, w: float, tc: int) -> void:
	if L < 0.01:
		return
	var tr: Dictionary = P.trail
	var kind := str(tr.kind)
	var mode := str(P.palette.mode)
	var n := 12 if Quality3D.effects >= 0.7 else 6
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.001:
		side = Vector3.FORWARD
	side = side.normalized()
	var vert := side.cross(dir).normalized()
	var pulse := 0.88 + 0.12 * sin(t * 18.0) if kind == "pulse" else 1.0
	var op: float = float(tr.opacity) * pulse
	var void_k := kind == "void"
	var outer: Array = mix_v if mode == "shot_cycle" else rib_v
	var core_target: Array = mix_v if void_k or mode == "shot_cycle" else rib_v
	var pts: Array = []
	for i in n + 1:
		var f := float(i) / n
		var off := 0.0
		if kind == "arc":
			off = sin(i * 2.4 * 2.0 + t * 32.0) * 0.03
		elif kind == "chain":
			off = sin(i * 1.9 * 2.0 - t * 15.0) * 0.03
		var p := base - dir * L * f + vert * off * f
		var col := Color.html(str(P.palette.glow)) if void_k else _shade(P, f, tc)
		if mode == "shot_cycle" and maxf(col.r, maxf(col.g, col.b)) < 0.03:
			col = Color.html("#a6aaa5")
		var broken := 0.08 if kind == "glitch" and i % 5 == 3 else 1.0
		col.a = pow(1.0 - f, 1.7) * op * broken
		pts.append([p, col, w * pow(1.0 - f, 0.7)])
	for i in n:
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		for ax in [side, vert]:
			_quad4(outer, a[0] - ax * a[2], a[0] + ax * a[2], b[0] + ax * b[2], b[0] - ax * b[2], a[1], a[1], b[1], b[1])
		var ga := Color(a[1], a[1].a * 0.22)   # the soft glow round the streak (the 2D's 1.9x outline)
		var gb := Color(b[1], b[1].a * 0.22)
		_quad4(rib_v, a[0] - side * a[2] * 1.9, a[0] + side * a[2] * 1.9, b[0] + side * b[2] * 1.9, b[0] - side * b[2] * 1.9, ga, ga, gb, gb)
		var cc := Color(0.97, 1, 1) if not void_k else Color.html(str(P.palette.colors[0]))
		if P.palette.get("gold_core", false):
			cc = Color.html("#fff4b2")
		var ca := Color(cc, a[1].a * 0.55)
		var cb := Color(cc, b[1].a * 0.55)
		var cw: float = 0.3
		_quad4(core_target, a[0] - side * a[2] * cw, a[0] + side * a[2] * cw, b[0] + side * b[2] * cw, b[0] - side * b[2] * cw, ca, ca, cb, cb)


func _ribbon_line(head: Vector3, dir: Vector3, L: float, w: float, col: Color) -> void:
	if L < 0.01:
		return
	var side := dir.cross(Vector3.UP).normalized()
	var vert := side.cross(dir).normalized()
	var tail := head - dir * L
	var ct := Color(col, 0.0)
	for ax in [side, vert]:
		_quad4(rib_v, head - ax * w, head + ax * w, tail + ax * w * 0.5, tail - ax * w * 0.5, col, col, ct, ct)


## a tracer that sheds motes leaves one now and then partway back along its streak (main._shed's rule, as cparts)
func _shed(b: Dictionary, _P: Dictionary, emit: Vector3, dir: Vector3) -> void:
	var st := CosArt.trail(str(b.get("tr", "std")))
	var pk: String = st.get("pk", "")
	if pk == "" or sim.game.time < b.get("nextTrailFx", 0.0) or m.cparts.size() >= 520 or Quality3D.effects < 0.5:
		return
	b.nextTrailFx = sim.game.time + (0.16 if m.settings.data.fpsMode == "30" else 0.08)
	if randf() >= st.get("pr", 0.0):
		return
	var p := emit - dir * 0.15
	var q: Dictionary = m.cemit(p.x, p.z, (p.y - sim.height_at(p.x, p.z) * V3.TER) / V3.PXV, pk)
	if q.is_empty():
		return
	var cyc: Array = st.get("cycle", [])
	if not cyc.is_empty():
		q.col = cyc[int(b.get("tc", 0)) % cyc.size()]


# ---------------------------------------------------------------- kill effects

## the effect's pieces: each connected part of its meshes on its own (preview.js splitPieces), centred on itself
func _pieces(key: String) -> Array:
	if kpieces.has(key):
		return kpieces[key]
	var out: Array = []
	var root := lib.instantiate_file("models/kill_effects/%s.glb" % key)
	if root == null:
		kpieces[key] = out
		return out
	var list: Array = []
	_collect(root, Transform3D.IDENTITY, list)
	var all_aabb := AABB()
	var first := true
	for e in list:
		var mi: MeshInstance3D = e[0]
		var xf: Transform3D = e[1]
		for s in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var mat: Material = mi.get_active_material(s)
			for piece in _split(arrays, xf):
				piece.mat = mat
				out.append(piece)
				var bb := AABB(piece.home - piece.half, piece.half * 2)
				all_aabb = bb if first else all_aabb.merge(bb)
				first = false
	root.free()
	var size := maxf(all_aabb.size.x, maxf(all_aabb.size.y, all_aabb.size.z))
	var k := 1.0 / maxf(size, 0.001)
	var c := all_aabb.get_center()
	for p in out:
		p.home = (p.home - c) * k
		p.k = k
	kpieces[key] = out
	return out


func _collect(n: Node, xf: Transform3D, list: Array) -> void:
	var tt := xf
	if n is Node3D:
		tt = xf * (n as Node3D).transform
	if n is MeshInstance3D and n.mesh != null:
		list.append([n, tt])
	for ch in n.get_children():
		_collect(ch, tt, list)


## union-find over a surface's vertices (shared positions and shared triangles): one mesh per connected piece
func _split(arrays: Array, xf: Transform3D) -> Array:
	var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx = arrays[Mesh.ARRAY_INDEX]
	var nv := vs.size()
	if nv == 0:
		return []
	var ids: PackedInt32Array = idx if idx != null and idx.size() > 0 else PackedInt32Array(range(nv))
	var root := PackedInt32Array(range(nv))
	var find := func(i: int) -> int:
		while root[i] != i:
			root[i] = root[root[i]]
			i = root[i]
		return i
	var bypos := {}
	for i in nv:
		var key := Vector3i(roundi(vs[i].x * 1e4), roundi(vs[i].y * 1e4), roundi(vs[i].z * 1e4))
		if bypos.has(key):
			root[find.call(i)] = find.call(bypos[key])
		else:
			bypos[key] = i
	for i in range(0, ids.size(), 3):
		var a: int = find.call(ids[i])
		root[find.call(ids[i + 1])] = a
		root[find.call(ids[i + 2])] = a
	var groups := {}
	for i in range(0, ids.size(), 3):
		var r: int = find.call(ids[i])
		if not groups.has(r):
			groups[r] = PackedInt32Array()
		groups[r].append_array([ids[i], ids[i + 1], ids[i + 2]])
	var keys := groups.keys()
	if keys.size() > 64:   # a budget of pieces: the small ones ride with a neighbour
		var merged := {}
		for q in keys.size():
			var g: int = q % 64
			if not merged.has(g):
				merged[g] = PackedInt32Array()
			merged[g].append_array(groups[keys[q]])
		groups = merged
	var out: Array = []
	var nrm = arrays[Mesh.ARRAY_NORMAL]
	var uv = arrays[Mesh.ARRAY_TEX_UV]
	var col = arrays[Mesh.ARRAY_COLOR]
	var tan = arrays[Mesh.ARRAY_TANGENT]
	for g in groups.values():
		var remap := {}
		var pv := PackedVector3Array()
		var pn := PackedVector3Array()
		var pu := PackedVector2Array()
		var pc := PackedColorArray()
		var pt := PackedFloat32Array()
		var pi := PackedInt32Array()
		for i in g:
			if not remap.has(i):
				remap[i] = pv.size()
				pv.append(xf * vs[i])
				if nrm != null and nrm.size() == nv:
					pn.append((xf.basis * nrm[i]).normalized())
				if uv != null and uv.size() == nv:
					pu.append(uv[i])
				if col != null and col.size() == nv:
					pc.append(col[i])
				if tan != null and tan.size() == nv * 4:
					pt.append_array([tan[i * 4], tan[i * 4 + 1], tan[i * 4 + 2], tan[i * 4 + 3]])
			pi.append(remap[i])
		var bb := AABB(pv[0], Vector3.ZERO)
		for p in pv:
			bb = bb.expand(p)
		var c := bb.get_center()
		for q in pv.size():
			pv[q] -= c
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = pv
		if pn.size() == pv.size():
			a[Mesh.ARRAY_NORMAL] = pn
		if pu.size() == pv.size():
			a[Mesh.ARRAY_TEX_UV] = pu
		if pc.size() == pv.size():
			a[Mesh.ARRAY_COLOR] = pc
		if pt.size() == pv.size() * 4:
			a[Mesh.ARRAY_TANGENT] = pt
		a[Mesh.ARRAY_INDEX] = pi
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		out.append({"mesh": am, "home": c, "half": bb.size / 2})
	return out


func kill_effect(x: float, y: float, id: String) -> void:
	if id == "" or id == "none":
		return
	var ps := _pieces(id)
	if ps.is_empty():
		return
	while kills.size() >= Quality3D.max_kill_fx:
		_park_kill(kills.pop_front())
	var free: Array = kpool.get(id, [])
	var node: Node3D = free.pop_back() if not free.is_empty() else null
	if node == null:
		node = Node3D.new()
		for p in ps:
			var mi := MeshInstance3D.new()
			mi.mesh = p.mesh
			mi.material_override = p.mat
			mi.scale = Vector3.ONE * p.k
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(mi)
		add_child(node)
	node.visible = true
	node.position = Vector3(x, sim.height_at(x, y) * V3.TER + 0.62, y)
	kills.append({"node": node, "key": id, "x": x, "y": y, "age": -0.06})


func _park_kill(kf: Dictionary) -> void:
	if not is_instance_valid(kf.node):
		return
	kf.node.visible = false
	if not kpool.has(kf.key):
		kpool[kf.key] = []
	kpool[kf.key].append(kf.node)


static func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0, 1), 3)


## preview.js animatePanel for the kill effects: birth, drift and fade, and each family's own move
func _kills(dt: float) -> void:
	for i in range(kills.size() - 1, -1, -1):
		var kf: Dictionary = kills[i]
		kf.age += dt
		var age: float = maxf(0.0, kf.age)
		if age >= 2.45:
			_park_kill(kf)
			kills.remove_at(i)
			continue
		var birth := _ease(age / 0.32)
		var fade := 1.0 - smoothstep(1.65, 2.45, age)
		var drift := _ease((age - 1.1) / 1.2)
		var node: Node3D = kf.node
		var key: String = kf.key
		node.scale = Vector3.ONE * maxf(0.015, birth)
		node.rotation = Vector3(0, (sin(age * 1.5) * 0.28) if key == "hellportal" else sin(age * 1.2) * 0.1, 0)
		var ps: Array = kpieces[key]
		var ch := node.get_children()
		for q in ch.size():
			var part: MeshInstance3D = ch[q]
			var home: Vector3 = ps[q].home
			var pos := home
			var rot := Vector3.ZERO
			match key:
				"swish":
					if home.y > 0.18 * 0.55:
						pos.y += (1.5 * (1 - _ease(age / 0.9)) - 0.8 * _ease((age - 0.85) / 0.9)) * 0.55
					else:
						rot.z = sin(age * 10) * 0.025 * exp(-age * 2)
				"hellportal":
					rot.z = age * 0.25 * (1.0 if q % 2 else -1.0)
					pos += home * drift * 0.15
				"skull":
					pos.y += sin(age * 2) * 0.12 * 0.55
					pos += home * drift * 0.4
				"bolt":
					pos += home * drift * 0.55
					pos.y += (1 - birth) * 0.6 * 0.55
				_:
					var d := home.normalized() if home.length() > 0.01 else Vector3(sin(q * 2.4), 0.4, cos(q * 2.4))
					pos += d * drift * (0.6 if key == "nuke" else 0.8) * 0.55
					pos.y += drift * (0.65 if key == "nuke" else 0.18) * 0.55
					rot.z = drift * sin(q * 2.4) * 0.35
			part.position = pos
			part.rotation = rot
			part.transparency = 1.0 - fade
		# the halo and the ground ring
		var hc := Color(0.53, 0.88, 0.92, exp(-age * 4) * birth * 0.85 * fade)
		_q(buf_add, node.position, (2 + age * 2) * 0.55, hc)
		var gy: float = sim.height_at(kf.x, kf.y) * V3.TER + 0.02
		_ring(kf.x, kf.y, gy, 0.5 * 0.55 * (0.7 + birth * 0.6 + drift * 0.25), 0.012, Color(0.36, 0.47, 0.52, 0.45 * fade))


# ---------------------------------------------------------------- on the ground

## a ring on the ground: centre, height, radius and half-width in tiles
func _ring(x: float, y: float, gy: float, r: float, w: float, col: Color, n: int = 36, v: Array = []) -> void:
	var tv: Array = dec_v if v.is_empty() else v
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var c0 := Vector2(cos(a0), sin(a0))
		var c1 := Vector2(cos(a1), sin(a1))
		_quad4(tv, Vector3(x + c0.x * (r - w), gy, y + c0.y * (r - w)), Vector3(x + c1.x * (r - w), gy, y + c1.y * (r - w)),
			Vector3(x + c1.x * (r + w), gy, y + c1.y * (r + w)), Vector3(x + c0.x * (r + w), gy, y + c0.y * (r + w)), col, col, col, col)


func _disc(x: float, y: float, gy: float, r: float, col: Color, n: int = 24, rz: float = -1.0) -> void:
	var c := Vector3(x, gy, y)
	var ry := r if rz < 0 else rz
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		_tri(dec_v, c, Vector3(x + cos(a0) * r, gy, y + sin(a0) * ry), Vector3(x + cos(a1) * r, gy, y + sin(a1) * ry), col, col, col)


func _gy(x: float, y: float) -> float:
	return sim.height_at(x, y) * V3.TER + 0.015


func _ground() -> void:
	var gt: float = sim.game.time
	var u2 := 1.0 / V3.SQ2   # the 2D's ovals of TW2 * r are rings of r / sqrt 2 on the ground
	for fr in sim.frost_fields:
		if _on(fr.x, fr.y):
			_disc(fr.x, fr.y, _gy(fr.x, fr.y), fr.r * u2, Color(0.7, 0.95, 1.0, 0.3 * clampf(fr.t / 2.0, 0, 1)))
	for f in sim.fires:
		if not _on(f.x, f.y):
			continue
		var gy := _gy(f.x, f.y)
		var nap: int = int(f.get("nap", 0))
		if nap == 2:   # the Destroyer's poison gas
			var ga := minf(1.0, f.t) * 0.32
			for n in 5:
				var ox := sin(gt * 0.7 + n * 1.7) * 0.35
				var oy := cos(gt * 0.6 + n * 2.1) * 0.35
				_disc(f.x + ox, f.y + oy, gy + n * 0.01, f.r * u2 * (0.55 + 0.1 * n), Color(120 / 255.0, 200 / 255.0, 70 / 255.0, ga * (0.5 + 0.1 * n)), 16)
				_q(buf_smoke, Vector3(f.x + ox, gy + 0.15 + n * 0.08, f.y + oy), 0.45 + n * 0.08, Color(0.45, 0.75, 0.3, ga * 0.6))
			continue
		if nap == 3:   # a mine: a dark disc and its light, faster once armed
			var armed: bool = f.get("arm", 0.0) <= 0
			var blink := sin(gt * (14.0 if armed else 5.0) + f.x * 7) > 0
			_disc(f.x, f.y, gy, 0.11, Color.html("#1a1b1c"), 10)
			_disc(f.x, f.y, gy + 0.03, 0.085, Color.html("#3a3c3e"), 10)
			if blink:
				_q(buf_add, Vector3(f.x, gy + 0.06, f.y), 0.12, Color.html("#ff3a2a") if armed else Color.html("#ffb03a"))
			continue
		var a: float = clampf(f.t / 1.0, 0, 1)
		var flick := 0.9 + 0.1 * sin(gt * 17.0 + f.x * 3.0)
		_disc(f.x, f.y, gy, f.r * u2 * flick, Color(1, 0.45, 0.12, 0.35 * a))
		_disc(f.x, f.y, gy + 0.004, f.r * u2 * 0.55, Color(1, 0.75, 0.3, 0.45 * a))
		for n in 3:   # tongues of flame over it
			var h := Pal.hash2(int(f.x * 10) + n, int(f.y * 10))
			var ph := fmod(gt * (1.4 + h) + h * 7, 1.0)
			var p := Vector3(f.x + (h - 0.5) * f.r * 0.6, gy + 0.05 + ph * 0.35, f.y + (Pal.hash2(n, int(f.x * 7)) - 0.5) * f.r * 0.6)
			_q(buf_add, p, (0.28 - ph * 0.15) * f.r, Color(1, 0.55 + 0.3 * (1 - ph), 0.2, a * (1 - ph) * 0.9))
	for r in m.rings:
		var tt: float = 1.0 - r.life / r.max
		var rr: float = lerpf(r.r0, r.r1, tt)
		var rc: Color = Color.html(r.c1).lerp(Color.html(r.c2), tt) if r.has("c2") else Color.html(r.c1)
		rc.a = 1.0 - tt
		_ring(r.x, r.y, _gy(r.x, r.y) + 0.01, rr * u2, r.w * 0.012, rc)
	for e in sim.enemies:
		if e.dead or not _on(e.x, e.y):
			continue
		var gy := _gy(e.x, e.y)
		if e.type == "medic" and sim.game.phase == "raid":   # his healing reach
			_ring(e.x, e.y, gy, 2.6 * u2, 0.012, Color(143 / 255.0, 224 / 255.0, 160 / 255.0, 0.35), 40)
		if e.get("burnT", 0.0) > 0:
			_ring(e.x, e.y, gy + 0.02, 0.22, 0.02, Color.html("#ff8244"), 24)
		if e.get("slowT", 0.0) > 0:
			_ring(e.x, e.y, gy + 0.01, 0.29, 0.02, Color.html("#81dafa"), 24)
	if sim.map_id == "river":   # ripples round anyone wading
		var wading: Array = sim.enemies.filter(func(e): return not e.get("burrow", false) and not e.dead)
		for pl in sim.players.values():
			if pl.alive:
				wading.append(pl)
		if sim.qm.alive:
			wading.append(sim.qm)
		for e in wading:
			var tt := sim.t_at(floori(e.x), floori(e.y))
			if tt == PalMaps.T_WATER or (tt == PalMaps.T_LOW and sim.flood_on):
				_ring(e.x, e.y, 0.0, (7 + sin(gt * 6 + e.x * 3) * 1.5) * V3.PXH, 0.01, Color(170 / 255.0, 210 / 255.0, 230 / 255.0, 0.45), 24)


## flames over burning walls and oil drums
func _flames() -> void:
	var gt: float = sim.game.time
	for b in V.world.burning:
		for n in 3:
			var h := Pal.hash2(int(b[0] * 3) + n, int(b[1] * 5))
			var ph := fmod(gt * (1.6 + h) + h * 5, 1.0)
			_q(buf_add, Vector3(b[0] + (h - 0.5) * 0.5, b[2] + 0.04 + ph * 0.4, b[1] + (Pal.hash2(n, int(b[0] * 9)) - 0.5) * 0.5), 0.42 - ph * 0.22, Color(1, 0.5 + 0.35 * (1 - ph), 0.18, 0.85 * (1 - ph)))
		_q(buf_add, Vector3(b[0], b[2] + 0.1, b[1]), 0.9 + 0.08 * sin(gt * 13.0 + b[0]), Color(1, 0.55, 0.2, 0.35))
		if randf() < 0.04:
			m._emit(b[0], b[1], "smoke", 0)
	for d in V.world.drums:
		if not _on(d[0], d[1]):
			continue
		var t0: float = gt * 9 + Pal.hash2(int(d[0]) + 3, int(d[1]) + 17) * 20
		for q in 3:
			var fh := (9 + sin(t0 + q * 2.1) * 3 + (q % 2) * 2) * V3.PXV
			var col := Color.html("#ffd070") if q == 1 else Color.html("#ff8a2a")
			_q(buf_add, Vector3(d[0] + (q - 1) * 0.06, d[2] + fh * 0.6, d[1] - (q - 1) * 0.06), 0.16 + fh * 0.8, col)
		_q(buf_add, Vector3(d[0], d[2] + 0.1, d[1]), 0.8, Color(1, 0.6, 0.25, 0.3))


# ---------------------------------------------------------------- things in flight and small things

func _mesh(key: String) -> ArrayMesh:
	if meshes.has(key):
		return meshes[key]
	var g := V3Mesh.new()
	g.anchor = Vector2(-9999, -9999)
	match key:
		"rocket":   # along +Z: a dark tube with a nose and fins
			var b := V3Mesh.new()
			b.prism(0, 0, 0.035, -0.16, 0.12, Color.html("#4a4a3a"), Color.html("#4a4a3a"), 6)
			b.cone(0, 0, 0.035, 0.12, 0.2, Color.html("#8a3a2a"), Color.html("#6a2a1e"), 6)
			for i in b.verts.size():   # stand it on its side: its axis from Y to Z
				var p := b.verts[i]
				b.verts[i] = Vector3(p.x, -p.z, p.y)
			g = b
			g.box(-0.06, -0.16, 0.06, -0.12, -0.005, 0.005, Color.html("#3a3a2e"), Color.html("#3a3a2e"), Color.html("#3a3a2e"))
		"shell":
			var b := V3Mesh.new()
			b.prism(0, 0, 0.04, -0.07, 0.06, Color.html("#2a2a26"), Color.html("#2a2a26"), 7, 0.02)
			for i in b.verts.size():
				var p := b.verts[i]
				b.verts[i] = Vector3(p.x, -p.z, p.y)
			g = b
		"slab":
			g.box(-0.13, -0.11, 0.13, 0.11, -0.07, 0.07, Color.html("#6f695f"), Color.html("#524d46"), Color.html("#403c37"))
		"charge":
			g.box(-0.08, -0.06, 0.08, 0.06, 0, 0.08, Color.html("#2a241c"), Color.html("#1a1510"), Color.html("#14110c"))
		"sack":
			g.prism(0, 0, 0.11, 0, 0.12, Color.html("#cbbf9f"), Color.html("#ddd3b6"), 8, 0.05)
		"mound":
			g.prism(0, 0, 0.3, -0.02, 0.07, Color.html("#4a4030"), Color.html("#6a5a44"), 10, 0.21)
			g.prism(0, 0, 0.21, 0.07, 0.12, Color.html("#6a5a44"), Color.html("#7a6a52"), 10, 0.08)
	meshes[key] = g.commit()
	return meshes[key]


func _prop(id: String, kind: String) -> Node3D:
	prop_seen[id] = true
	if props.has(id):
		return props[id]
	var n: Node3D
	if kind.begins_with("weapon:"):
		n = lib.instantiate_id(kind)
		if n != null:
			var holder := Node3D.new()
			holder.add_child(n)
			n.scale = Vector3.ONE * (1.4 if kind == "weapon:molotov" else 2.6) * V3.CHAR
			n = holder
	if n == null:
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh(kind if not kind.begins_with("weapon:") else "slab")
		mi.material_override = mat_prop
		n = mi
	add_child(n)
	props[id] = n
	return n


## rockets, lobs (frags, bottles, slabs, missiles, napalm, shells) and the Blue Butcher's arcs
func _flying(_dt: float) -> void:
	var WH := V3.WALL_H
	var gt: float = sim.game.time
	var n := 0
	for r in sim.rockets:
		n += 1
		var sp := Vector2(r.vx, r.vy)
		if sp.length() < 0.001 or not _on(r.x, r.y):
			continue
		var d := sp.normalized()
		var p := Vector3(r.x, sim.height_at(r.x, r.y) * V3.TER + WH * 0.6, r.y)
		var node := _prop("rk%d" % n, "rocket")
		node.position = p
		node.basis = Basis.looking_at(-Vector3(d.x, 0, d.y), Vector3.UP).scaled(Vector3.ONE * 1.3)
		var back := p - Vector3(d.x, 0, d.y) * 0.26
		_q(buf_add, back, 0.16 + randf() * 0.08, Color.html("#ffb04a"))
		_q(buf_add, back, 0.4, Color(1, 0.6, 0.2, 0.35))
		if randf() < 0.6:
			m._emit(r.x - d.x * 0.25, r.y - d.y * 0.25, "smoke", 0)
	n = 0
	for l in sim.lobs:
		n += 1
		var k: int = int(l.get("k", 0))
		var tt: float = clampf(l.t / l.T, 0, 1)
		var x: float = lerpf(l.x0, l.x1, tt)
		var y: float = lerpf(l.y0, l.y1, tt)
		if k == 3:   # a boss missile: its landing ring all through the flight
			_ring(l.x1, l.y1, _gy(l.x1, l.y1) + 0.01, l.R / V3.SQ2, 0.018, Color(1, 70 / 255.0, 50 / 255.0, 0.55 + 0.35 * sin(gt * 22.0)), 40)
		if not _on(x, y):
			continue
		var arc := sin(tt * PI) * WH * 2.2
		var gy := sim.height_at(x, y) * V3.TER
		var p := Vector3(x, gy + WH * 0.5 + arc, y)
		_disc(x, y, gy + 0.012, 0.07, Color(0, 0, 0, 0.3), 10, 0.07)
		var kind := "weapon:frag"
		match k:
			1:
				kind = "weapon:molotov"
			2:
				kind = "slab"
			3:
				kind = "rocket"
			4:
				kind = ""
			5:
				kind = "shell"
			_:
				var own = sim.players.get(str(l.get("own", "")))
				if own is Dictionary and own.cls == "grenadier" and own.get("perk", {}).get("molotov", false) and sim.pvp() == "":
					kind = "weapon:molotov"
		if kind == "":   # napalm: a ball of fire
			_q(buf_add, p, 0.3, Color(1, 0.55, 0.15, 0.95))
			_q(buf_add, p, 0.55, Color(1, 0.4, 0.1, 0.35))
			continue
		var node := _prop("lob%d" % n, kind)
		node.position = p
		var dir := Vector3(l.x1 - l.x0, 0, l.y1 - l.y0)
		if kind == "rocket" or kind == "shell":   # nose along the arc
			var vy := cos(tt * PI) * WH * 2.2 * PI / maxf(l.T, 0.1)
			var hv := dir / maxf(l.T, 0.1)
			var v3 := Vector3(hv.x, vy, hv.z)
			if v3.length() > 0.01:
				node.basis = Basis.looking_at(-v3.normalized(), Vector3.UP if absf(v3.normalized().y) < 0.98 else Vector3.RIGHT).scaled(Vector3.ONE * 1.3)
			if kind == "rocket":
				_q(buf_add, p - v3.normalized() * 0.26, 0.2, Color.html("#ffb04a"))
		else:
			node.rotation = Vector3(tt * TAU * 1.5, atan2(dir.x, dir.z), 0)
		if kind == "weapon:molotov":   # the lit rag
			_q(buf_add, p + Vector3(0, 0.12, 0), 0.12 + 0.04 * sin(gt * 30), Color(1, 0.6, 0.2, 0.9))
	for r in sim.arcs:
		var sp := Vector2(r.vx, r.vy)
		if sp.length() < 0.001 or not _on(r.x, r.y):
			continue
		var d := sp.normalized()
		var nr := d.orthogonal()
		var c := Vector3(r.x, sim.height_at(r.x, r.y) * V3.TER + WH * 0.5, r.y)
		var D := Vector3(d.x, 0, d.y)
		var Nn := Vector3(nr.x, 0, nr.y)
		var a := c - Nn * 0.26 - D * 0.09
		var b := c + D * 0.07
		var e := c + Nn * 0.26 - D * 0.09
		for seg in [[a, b], [b, e]]:
			var s0: Vector3 = seg[0]
			var s1: Vector3 = seg[1]
			var up := Vector3(0, 0.07, 0)
			var col := Color(58 / 255.0, 224 / 255.0, 224 / 255.0, 0.5)
			_quad4(rib_v, s0 - up, s1 - up, s1 + up, s0 + up, col, col, col, col)
			var core := Color(0.87, 0.99, 1, 1)
			var cu := Vector3(0, 0.022, 0)
			_quad4(rib_v, s0 - cu, s1 - cu, s1 + cu, s0 + cu, core, core, core, core)


## breaching charges (blinking), dropped sacks, the Foreman's mound, the dazed Bulldozer's stars
func _smalls() -> void:
	var gt: float = sim.game.time
	var n := 0
	for ch in sim.charges:
		n += 1
		var node := _prop("ch%d" % n, "charge")
		var gy := sim.height_at(ch.x, ch.y) * V3.TER
		node.position = Vector3(ch.x, gy, ch.y)
		if sin(gt * (20.0 - ch.fuse * 5.0)) > 0:
			_q(buf_add, Vector3(ch.x, gy + 0.13, ch.y), 0.14, Color.html("#ff5a3a"))
	n = 0
	for s in sim.sacks:
		n += 1
		var node := _prop("sk%d" % n, "sack")
		var gy := sim.height_at(s.x, s.y) * V3.TER
		node.position = Vector3(s.x, gy, s.y)
		_disc(s.x, s.y, gy + 0.01, 0.13, Color(0, 0, 0, 0.35), 12, 0.13)
	for e in sim.enemies:
		if e.dead or e.type != "boss":
			continue
		var under: bool = e.get("burrow", false) or (e.boss in ["foreman", "whiteforeman"] and int(e.get("st", 0)) in [2, 4])
		if under:
			var node := _prop("mound%d" % int(e.id), "mound")
			var sw := (1.35 + sin(gt * 40) * 0.08) if int(e.st) == 4 else 1.0
			node.position = Vector3(e.x, sim.height_at(e.x, e.y) * V3.TER, e.y)
			node.scale = Vector3(sw, 1.0, sw)
		if e.boss == "bulldozer" and int(e.get("st", 0)) == 6:   # dazed
			var top := sim.height_at(e.x, e.y) * V3.TER + V3.WALL_H * 2.3 * 0.9
			for q in 3:
				var a: float = gt * 4.0 + q * TAU / 3
				_q(buf_add, Vector3(e.x + cos(a) * 0.25, top, e.y + sin(a) * 0.25), 0.11, Color.html("#ffd23a"))
