class_name V3Actors
extends Node3D
## The people in 3D: the soldiers in their class or skin with their headgear and class weapon (ArtLibrary.build),
## Delgado, the seven raider types and the bosses, placed from the sim every frame and facing their aim. Their clip is
## chosen from sim state (blueprint 08: death and downed, then the roll and action locks, then combat, then walking):
## idle or aiming, walking/strafing/running by how fast and which way they actually moved, firing (from the sim's
## muzzle flashes), the Grenadier's shell insert and the Sniper's bolt, throws, the Soldier's rocket, building,
## gathering, downed and revived, hit, death, and the roll (Dodge_Forward_IP or Dodge_Backward_IP scrubbed to p.dgE).
## Bosses play their Tell, Execute and Recover clips from their state (e.st and its timer). Models are pooled by look
## and reused.

const V3 = preload("res://scripts/view3d/view3d.gd")
const RAIDERS := ["rifle", "gren", "fire", "breach", "shield", "medic", "spotter"]
## the casino's staff in 3D: a skin from the library each (no weapons), the 2D dealers' looks as near as it has
const STAFF := {"vinnie": "skin:dracula", "rosa": "skin:redcoat", "marco": "skin:nightshift", "duke": "skin:gnightshift",
	"lena": "skin:night", "keep": "skin:yard2", "bot": "skin:gpolice"}
## boss state -> the clip family it shows: "Name" is a tell (wind-up, timed to the state), "Name!" is the move itself
const BOSS_ST := {
	"pitboss": {1: "CashBoxSwing", 2: "FloorRush", 3: "FloorRush!", 61: "CardSpray"},
	"custodian": {63: "MopArc"},
	"gatekeeper": {71: "Stomp", 76: "ShieldWall"},
	"gatekeeper_pilot": {74: "Sidearm", 75: "Dive!"},
	"visitor": {83: "Blink"},
	"demolisher": {1: "Rocket", 2: "RocketFan"},
	"arsonist": {1: "NapalmChain", 25: "Flamethrower", 26: "Flamethrower!", 27: "RingOfFire"},
	"butcher": {1: "Blade", 2: "Charge", 3: "Charge!"},
	"pumpkin": {1: "Blade", 2: "Charge", 3: "Charge!"},
	"bluebutcher": {1: "Blade", 2: "Charge", 3: "Charge!", 5: "BlueArc"},
	"whitebutcher": {1: "Blade", 2: "Charge", 3: "Charge!", 5: "IceArc", 101: "FrostRupture"},
	"storm": {1: "ChainLightning", 20: "Thunderstrike", 21: "StaticPulse"},
	"tempest": {1: "TwinLightning", 22: "Cyclone", 23: "Cyclone!", 24: "StormCage"},
	"foreman": {1: "RockSlab", 3: "Rockfall"},
	"bulldozer": {1: "Charge", 2: "Charge!", 28: "SeismicSlam", 29: "Overdrive", 30: "Overdrive!"},
	"whiteforeman": {1: "Charge", 2: "Charge!", 101: "FrostRupture"},
	"ferryman": {1: "Harpoon", 3: "BridgeRam!"},
	"whiteferryman": {1: "Harpoon", 3: "BridgeRam!", 101: "FrostRupture"},
	"harbinger": {1: "MissileBarrage"},
	"rime": {101: "FrostRupture", 102: "FrostDash", 103: "FrostDash!"},
	"destroyer": {40: "BackRockets", 41: "FireBarrel", 42: "FireBarrel!", 43: "LightningBarrel", 44: "PoisonGas", 45: "Minefield", 46: "OrbitalCannon", 47: "OrbitalCannon!"},
}

var V   # View3D
var sim: Sim
var lib: ArtLibrary
var recs := {}   # actor key -> record
var pool := {}   # model key -> [Node3D]
var corpses: Array = []   # {node, mkey, t}
var shots: Array = []   # this frame's muzzle flashes: [x, y]
var throws: Array = []   # this frame's lobs and launches: [x, y, kind]
var clipsets := {}   # character id -> {clip name: duration}
var ring_mats := {}
var ring_scene: PackedScene
var frame_n := 0
var time := 0.0
var anim_us := 0   # the last frame's animation updates (the profile the screenshot test prints)
var merges := {}   # model key -> [pieces' signature, ArrayMesh, Skin]: one merged body per look, shared by its copies
## slots shown and hidden in play (lib.show_slot below) and the props switched in hand (_arm, _prop): never merged
const LIVE_SLOTS := ["Weapon", "Equipment_ArmL", "Equipment_Back", "Equipment_Jacket", "Equipment_Damage", "Equipment_Pilot"]   # the last three: THE UNDERSTRIP bosses' stage pieces
const LIVE_PROPS := ["HandR", "frag", "molotov", "rocket", "ClassWeapon", "UnderstripWeapon"]


func _init(view) -> void:
	V = view
	sim = view.sim
	lib = view.lib
	name = "Actors"
	var rp := "res://palisade_art/models/utilities/player_ring.glb"
	if ResourceLoader.exists(rp):
		ring_scene = load(rp)


func clear() -> void:
	for k in recs.keys():
		_release(recs[k])
	recs.clear()
	for c in corpses:
		_park(c.node, c.mkey)
	corpses.clear()


# ---------------------------------------------------------------- models

func _clips(cid: String) -> Dictionary:
	if not clipsets.has(cid):
		var d := {}
		for c in lib.characters.get(cid, {}).get("clips", []):
			d[c.name] = float(c.get("duration", 1.0))
		clipsets[cid] = d
	return clipsets[cid]


## a model with its AnimationPlayer under manual updates, its loops set from the manifest, and its meshes listed
func _prep(model: Node3D, cid: String) -> Dictionary:
	var ap := lib.animation_player(model)
	if ap != null:
		for c in lib.characters.get(cid, {}).get("clips", []):
			if ap.has_animation(c.name):
				ap.get_animation(c.name).loop_mode = Animation.LOOP_LINEAR if c.get("loop", false) else Animation.LOOP_NONE
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var geoms: Array = []
	for n in ArtLibrary._all(model):
		if n is GeometryInstance3D:
			geoms.append(n)
	var skel: Skeleton3D = null
	for n in ArtLibrary._all(model):
		if n is Skeleton3D:
			skel = n
			break
	return {"ap": ap, "geoms": geoms, "skel": skel}


## the pivot (position, facing, the tile scale) holding a model; from the pool when one of this look is free
func _take(mkey: String, build: Callable) -> Node3D:
	var free: Array = pool.get(mkey, [])
	while not free.is_empty():
		var n: Node3D = free.pop_back()
		if is_instance_valid(n):
			n.visible = true
			return n
	var model: Node3D = build.call()
	if model == null:
		return null
	_merge(model, mkey)
	var pivot := Node3D.new()
	pivot.name = mkey.replace(":", "_").replace("|", "_")
	pivot.scale = Vector3.ONE * V3.CHAR
	pivot.add_child(model)
	for g in ArtLibrary._all(model):
		if g is VisualInstance3D:
			g.layers = 3   # the world's light and the people's fill light
	var info := _prep(model, str(model.get_meta("char_id", "")))
	info.model = model
	info.cid = str(model.get_meta("char_id", ""))
	pivot.set_meta("info", info)
	add_child(pivot)
	return pivot


## The body's skinned pieces as one mesh, a surface per material, their Skins joined: the Compatibility renderer pays
## per skinned mesh (a raider is ~6), so a push of 40 drew 230 of them and now 40. Only pieces straight under the
## skeleton, shown, at its origin, plain (no overlay, fade, range or blend shapes) and outside LIVE_SLOTS / LIVE_PROPS;
## the rest stay as built. The merged mesh has no LODs, so its shadow is cast by the full mesh, not a coarser LOD.
func _merge(model: Node3D, mkey: String) -> void:
	var skel: Skeleton3D = null
	for n in ArtLibrary._all(model):
		if n is Skeleton3D:
			skel = n
			break
	if skel == null:
		return
	var pieces: Array = []
	for n in skel.get_children():
		if n is MeshInstance3D and _mergeable(n, skel) and (pieces.is_empty() or n.cast_shadow == pieces[0].cast_shadow):
			pieces.append(n)
	if pieces.size() < 2:
		return
	var sig := ""
	for p in pieces:
		sig += "%d:%d|" % [p.mesh.get_instance_id(), p.skin.get_instance_id()]
		for si in p.mesh.get_surface_count():
			var mat: Material = p.get_active_material(si)
			sig += "%d," % (mat.get_instance_id() if mat != null else 0)
	var M: Array = merges.get(mkey, [])
	if M.is_empty() or M[0] != sig:
		M = [sig] + _joined(pieces)
		M[1] = _layered(M[1])
		merges[mkey] = M
	var body := MeshInstance3D.new()
	body.name = "MergedBody"
	body.mesh = M[1]
	body.skin = M[2]
	body.cast_shadow = pieces[0].cast_shadow
	skel.add_child(body)
	body.skeleton = NodePath("..")
	for p in pieces:
		skel.remove_child(p)
		p.free()


func _mergeable(n: MeshInstance3D, skel: Skeleton3D) -> bool:
	if not n.visible or n.get_child_count() > 0 or n.skin == null or not (n.mesh is ArrayMesh):
		return false
	if n.mesh.get_blend_shape_count() > 0 or n.material_overlay != null or n.transparency != 0.0 or n.visibility_range_end != 0.0:
		return false
	if n.get_node_or_null(n.skeleton) != skel or not n.transform.is_equal_approx(Transform3D.IDENTITY):
		return false
	var nm := String(n.name)
	if nm in LIVE_PROPS:
		return false
	for slot in LIVE_SLOTS:   # as lib.show_slot matches them
		if nm == slot or nm.begins_with("Fur_" + slot + "_") or n.get_meta("modular_owner", "") == slot:
			return false
	return true


## The merged body's surfaces drawn over texture arrays: the surfaces whose standard materials compile to the same
## shader (most of a look's 5-11; they differ in textures, metallic, roughness, normal depth, emission) become one
## surface, each vertex carrying its material's layer in UV2.x, under one ShaderMaterial that is BaseMaterial3D's shader
## for these settings reading each value from its layer. The textures tile (UVs run past 0..1), which an array layer
## does as the texture did; an atlas tile couldn't. A push draws ~400 fewer surfaces. Colours go in as the material
## holds them: the Compatibility renderer doesn't convert source_color to linear.
func _layered(am: ArrayMesh) -> ArrayMesh:
	var groups := {}
	var order: Array = []
	for si in am.get_surface_count():
		var m = am.surface_get_material(si)
		var gk := "keep%d" % si
		if m is BaseMaterial3D and am.surface_get_format(si) & Mesh.ARRAY_FORMAT_TEX_UV2 == 0:
			gk = _layer_key(m)
		if not groups.has(gk):
			groups[gk] = []
			order.append(gk)
		groups[gk].append(si)
	var out := ArrayMesh.new()
	for gk in order:
		var sis: Array = groups[gk]
		if sis.size() < 2 or sis.size() > LAYERS:
			for si in sis:
				out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, am.surface_get_arrays(si), [], {}, am.surface_get_format(si) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
				out.surface_set_material(out.get_surface_count() - 1, am.surface_get_material(si))
			continue
		var m0: BaseMaterial3D = am.surface_get_material(sis[0])
		var alb: Array = []
		var nrm: Array = []
		var P := {"albedo_l": [], "metallic_l": PackedFloat32Array(), "roughness_l": PackedFloat32Array(), "specular_l": PackedFloat32Array(),
			"normal_scale_l": PackedFloat32Array(), "emission_l": [], "emission_energy_l": PackedFloat32Array()}
		var layer_of := {}
		var acc := []
		acc.resize(Mesh.ARRAY_MAX)
		var nv := 0
		for si in sis:
			var m: BaseMaterial3D = am.surface_get_material(si)
			if not layer_of.has(m):
				layer_of[m] = alb.size()
				alb.append(_layer_img(m.albedo_texture, Color.WHITE, null if alb.is_empty() else alb[0]))
				if m.normal_enabled:
					nrm.append(_layer_img(m.normal_texture, Color(0.5, 0.5, 1.0), null if nrm.is_empty() else nrm[0]))
				P.albedo_l.append(m.albedo_color)
				P.metallic_l.append(m.metallic)
				P.roughness_l.append(m.roughness)
				P.specular_l.append(m.metallic_specular)
				P.normal_scale_l.append(m.normal_scale)
				P.emission_l.append(m.emission if m.emission_enabled else Color(0, 0, 0, 0))
				P.emission_energy_l.append(m.emission_energy_multiplier if m.emission_enabled else 0.0)
			var arr := am.surface_get_arrays(si)
			var vc: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var uv2 := PackedVector2Array()
			uv2.resize(vc)
			uv2.fill(Vector2(layer_of[m], 0))
			arr[Mesh.ARRAY_TEX_UV2] = uv2
			for k in Mesh.ARRAY_MAX:
				if k == Mesh.ARRAY_INDEX or arr[k] == null:
					continue
				acc[k] = arr[k].duplicate() if acc[k] == null else acc[k] + arr[k]
			var ind: PackedInt32Array = PackedInt32Array(range(vc)) if arr[Mesh.ARRAY_INDEX] == null else (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).duplicate()
			for q in ind.size():
				ind[q] += nv
			acc[Mesh.ARRAY_INDEX] = ind if acc[Mesh.ARRAY_INDEX] == null else acc[Mesh.ARRAY_INDEX] + ind
			nv += vc
		var sm := ShaderMaterial.new()
		sm.shader = _layer_shader(m0.normal_enabled, m0.cull_mode)
		sm.set_meta("layer", [m0.normal_enabled, m0.cull_mode])   # for its faded copy (fade)
		var ta := Texture2DArray.new()
		ta.create_from_images(alb)
		sm.set_shader_parameter("texture_albedo", ta)
		if m0.normal_enabled:
			var tn := Texture2DArray.new()
			tn.create_from_images(nrm)
			sm.set_shader_parameter("texture_normal", tn)
		for k in P:
			var v = P[k]
			while v.size() < LAYERS:
				v.append(Color(0, 0, 0, 0) if v is Array else 0.0)
			sm.set_shader_parameter(k, v)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, acc, [], {}, am.surface_get_format(sis[0]) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.surface_set_material(out.get_surface_count() - 1, sm)
	return out


## materials that compile to the same shader: everything but the per-layer values alike
func _layer_key(m: BaseMaterial3D) -> String:
	return "%d|%d|%d|%d|%d|%d|%d|%d|%s|%s|%d|%d|%d|%d|%d|%d" % [int(m.normal_enabled), m.cull_mode, m.transparency, m.shading_mode,
		m.diffuse_mode, m.specular_mode, int(m.vertex_color_use_as_albedo), int(m.vertex_color_is_srgb), str(m.uv1_scale), str(m.uv1_offset),
		m.texture_filter, int(m.uv1_triplanar), int(m.rim_enabled), int(m.ao_enabled), int(m.metallic_texture != null or m.roughness_texture != null or m.emission_texture != null), int(m.emission_operator)]


## a layer's image: the texture's, or one colour where the material has none (what its shader samples then), made to
## match the first layer's size and format, which an array needs
func _layer_img(t: Texture2D, fill: Color, like: Image) -> Image:
	var im: Image
	if t != null:
		im = t.get_image()
	else:
		im = Image.create(256 if like == null else like.get_width(), 256 if like == null else like.get_height(), false, Image.FORMAT_RGB8)
		im.fill(fill)
	if like != null and (im.get_format() != like.get_format() or im.get_size() != like.get_size() or im.has_mipmaps() != like.has_mipmaps()):
		im = im.duplicate()
		if im.is_compressed():
			im.decompress()
		im.convert(like.get_format())
		im.resize(like.get_width(), like.get_height())
		if like.has_mipmaps():
			im.generate_mipmaps()
		else:
			im.clear_mipmaps()
	return im


const LAYERS := 16
static var layer_shaders := {}   # "normal|cull" -> Shader


## BaseMaterial3D's shader (base_material_3d.cpp) for what these materials turn on, each value from the layer's slot;
## faded: its alpha-with-depth-pre-pass form, the whole surface at the fade uniform (fade)
static func _layer_shader(normal: bool, cull: int, faded: bool = false) -> Shader:
	var k := "%s|%d|%s" % [normal, cull, faded]
	if layer_shaders.has(k):
		return layer_shaders[k]
	var c := "shader_type spatial;\nrender_mode blend_mix, %s, %s, diffuse_burley, specular_schlick_ggx;\n" % ["depth_prepass_alpha" if faded else "depth_draw_opaque", ["cull_back", "cull_front", "cull_disabled"][cull]]
	if faded:
		c += "uniform float fade = 1.0;\n"
	c += "uniform sampler2DArray texture_albedo : source_color, filter_linear_mipmap, repeat_enable;\n"
	if normal:
		c += "uniform sampler2DArray texture_normal : hint_normal, filter_linear_mipmap, repeat_enable;\n"
	for u in ["vec4 albedo_l", "float metallic_l", "float roughness_l", "float specular_l", "float normal_scale_l", "vec4 emission_l", "float emission_energy_l"]:
		c += "uniform %s[%d];\n" % [u, LAYERS]
	c += "varying flat int layer;\nvoid vertex() {\n\tlayer = int(UV2.x + 0.5);\n}\n"
	c += "void fragment() {\n\tvec2 base_uv = UV;\n"
	c += "\tvec4 albedo_tex = texture(texture_albedo, vec3(base_uv, float(layer)));\n\talbedo_tex *= COLOR;\n"
	c += "\tALBEDO = albedo_l[layer].rgb * albedo_tex.rgb;\n"
	c += "\tfloat metallic_tex = dot(vec4(1.0), vec4(1.0, 0.0, 0.0, 0.0));\n\tMETALLIC = metallic_tex * metallic_l[layer];\n"
	c += "\tSPECULAR = specular_l[layer];\n"
	c += "\tfloat roughness_tex = dot(vec4(1.0), vec4(1.0, 0.0, 0.0, 0.0));\n\tROUGHNESS = roughness_tex * roughness_l[layer];\n"
	if normal:
		c += "\tNORMAL_MAP = texture(texture_normal, vec3(base_uv, float(layer))).rgb;\n\tNORMAL_MAP_DEPTH = normal_scale_l[layer];\n"
	c += "\tEMISSION = (emission_l[layer].rgb + vec3(0.0)) * emission_energy_l[layer];\n"
	if faded:
		c += "\tALPHA = albedo_l[layer].a * albedo_tex.a * fade;\n"
	c += "}\n"
	var sh := Shader.new()
	sh.code = c
	layer_shaders[k] = sh
	return sh


## GeometryInstance3D.transparency does nothing in the Compatibility renderer (a lone cube at 0.5 draws as at 0), so a
## fade gives each surface a see-through copy of its material, made the first time this instance fades and kept for
## the next, and puts the instance's own materials back when the fade ends. With a depth pre-pass, so a faded body
## reads as one figure rather than showing its insides. Surfaces of other material kinds are left as they are.
static func fade(g: GeometryInstance3D, alpha: float) -> void:
	var mi := g as MeshInstance3D
	if mi == null or mi.mesh == null:
		return
	var F: Dictionary = mi.get_meta("fade", {})
	if alpha >= 0.999:
		if F.get("on", false):
			if F.over != null:
				mi.material_override = F.base_over
			else:
				for si in F.surf.size():
					mi.set_surface_override_material(si, F.base_surf[si])
			F.on = false
		return
	if F.is_empty() or F.mesh != mi.mesh:
		F = {"mesh": mi.mesh, "on": false, "base_over": mi.material_override, "over": null, "surf": [], "base_surf": []}
		if mi.material_override != null:
			F.over = _faded(mi.material_override)
		else:
			for si in mi.mesh.get_surface_count():
				F.base_surf.append(mi.get_surface_override_material(si))
				F.surf.append(_faded(mi.get_active_material(si)))
		mi.set_meta("fade", F)
	if not F.on:
		if F.over != null:
			mi.material_override = F.over
		else:
			for si in F.surf.size():
				if F.surf[si] != null:
					mi.set_surface_override_material(si, F.surf[si])
		F.on = true
	for m in ([F.over] if F.over != null else F.surf):
		if m is BaseMaterial3D:
			m.albedo_color.a = m.get_meta("a0") * alpha
		elif m is ShaderMaterial:
			m.set_shader_parameter("fade", alpha)


static func _faded(m: Material) -> Material:
	if m is BaseMaterial3D:
		var c: BaseMaterial3D = m.duplicate()
		c.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		c.set_meta("a0", (m as BaseMaterial3D).albedo_color.a)
		return c
	if m is ShaderMaterial and m.has_meta("layer"):
		var c: ShaderMaterial = m.duplicate()
		c.shader = _layer_shader(m.get_meta("layer")[0], m.get_meta("layer")[1], true)
		return c
	return null


## [ArrayMesh, Skin] from the pieces: their binds one after another (each piece's bone indices moved past the binds
## before it) and their surfaces gathered by material and vertex format, indices moved past the vertices before
func _joined(pieces: Array) -> Array:
	var skin := Skin.new()
	var groups := {}
	var order: Array = []
	for p in pieces:
		var mi: MeshInstance3D = p
		var boff := skin.get_bind_count()
		for bi in mi.skin.get_bind_count():
			var bn: StringName = mi.skin.get_bind_name(bi)
			if bn != &"":
				skin.add_named_bind(bn, mi.skin.get_bind_pose(bi))
			else:
				skin.add_bind(mi.skin.get_bind_bone(bi), mi.skin.get_bind_pose(bi))
		for si in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(si)
			var fmt: int = mi.mesh.surface_get_format(si) & (Mesh.ARRAY_FORMAT_VERTEX | Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT
				| Mesh.ARRAY_FORMAT_COLOR | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_TEX_UV2 | Mesh.ARRAY_FORMAT_BONES
				| Mesh.ARRAY_FORMAT_WEIGHTS | Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			var gk := "%d|%d" % [mat.get_instance_id() if mat != null else 0, fmt]
			if not groups.has(gk):
				groups[gk] = {"mat": mat, "fmt": fmt, "parts": []}
				order.append(gk)
			groups[gk].parts.append([mi.mesh.surface_get_arrays(si), boff])
	var am := ArrayMesh.new()
	for gk in order:
		var G: Dictionary = groups[gk]
		var out := []
		out.resize(Mesh.ARRAY_MAX)
		var nv := 0
		for part in G.parts:
			var arr: Array = part[0]
			var vc: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			for k in Mesh.ARRAY_MAX:
				if k == Mesh.ARRAY_INDEX or arr[k] == null:
					continue
				var src = arr[k]
				if k == Mesh.ARRAY_BONES:
					var b: PackedInt32Array = (src as PackedInt32Array).duplicate()
					for q in b.size():
						b[q] += part[1]
					src = b
				out[k] = src.duplicate() if out[k] == null else out[k] + src
			var ind: PackedInt32Array = PackedInt32Array(range(vc)) if arr[Mesh.ARRAY_INDEX] == null else (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).duplicate()
			for q in ind.size():
				ind[q] += nv
			out[Mesh.ARRAY_INDEX] = ind if out[Mesh.ARRAY_INDEX] == null else out[Mesh.ARRAY_INDEX] + ind
			nv += vc
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out, [], {}, G.fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		am.surface_set_material(am.get_surface_count() - 1, G.mat)
	return [am, skin]


func _park(n: Node3D, mkey: String) -> void:
	if not is_instance_valid(n):
		return
	n.visible = false
	var info: Dictionary = n.get_meta("info")
	for g in info.geoms:
		fade(g, 1.0)
	if info.has("ring"):
		info.ring.visible = false
	if not pool.has(mkey):
		pool[mkey] = []
	pool[mkey].append(n)


func _release(r: Dictionary) -> void:
	_park(r.node, r.mkey)


func _player_model(p: Dictionary) -> Array:
	var eq: Dictionary = (V.m.locker.eq if V.m.locker != null else PalLocker.DEFAULT_COS) if p.id == sim.player.id else PalLocker.parse_cos(str(p.get("cosS", "")))
	var cls: String = p.cls
	var cid := lib.character_id(cls, str(eq.get("skin", "std")))
	var hat := str(eq.get("hat", "class"))
	var usgun: String=p.w2.id if sim.understrip() and p.get("wSel",0)==1 and p.get("w2")!=null else ""
	var mkey := "p|%s|%s|%s|%s" % [cid, hat, cls, usgun]
	var off := float(hash(str(p.id)) % 100) / 37.0
	return [mkey, func() -> Node3D:
		var mdl := lib.build(cls, eq, off)
		if mdl != null:
			_arm(mdl, cls)
			if usgun!="":
				var socket=ArtLibrary.named(mdl,str(lib.attach.get(cid,{}).get("socket","WeaponSocket")))
				if socket!=null:
					var gun=UsWeapons.build(usgun)
					var fit=lib.attach.get(cid,{}).get("long_gun",{})
					var tr=fit.get("translation",[0,0,0])
					var ro=fit.get("rotation",[0,0,0,1])
					gun.transform=Transform3D(Basis(Quaternion(ro[0],ro[1],ro[2],ro[3])),Vector3(tr[0],tr[1],tr[2]))
					lib.show_slot(mdl,"Weapon",false)
					var base=ArtLibrary.named(mdl,"ClassWeapon")
					if base!=null: base.visible=false
					socket.add_child(gun)
		return mdl]


func _id_model(cid: String) -> Array:
	return [cid, func() -> Node3D:
		var mdl := lib.instantiate_id(cid)
		if mdl != null:
			mdl.set_meta("char_id", cid)
		return mdl]


## a soldier's extra props, hidden until used: the grenade and the Molotov in the right hand, the rocket launcher on
## the weapon socket (weapon_profiles.json: throwables on Hand.R, launchers as a long gun)
func _arm(model: Node3D, cls: String) -> void:
	var cid := str(model.get_meta("char_id", ""))
	var a: Dictionary = lib.attach.get(cid, {})
	var skel: Skeleton3D = null
	for n in ArtLibrary._all(model):
		if n is Skeleton3D:
			skel = n
			break
	if skel == null:
		return
	var thr: Dictionary = a.get("throwable", {})
	if skel.find_bone("Hand.R") >= 0:
		var hand := BoneAttachment3D.new()
		hand.bone_name = "Hand.R"
		hand.name = "HandR"
		skel.add_child(hand)
		for wid in ["weapon:frag", "weapon:molotov"]:
			var w := lib.instantiate_id(wid)
			if w == null:
				continue
			var t: Dictionary = thr.get(wid, {"translation": [0, 0, 0.06], "rotation": [0, 0.707107, 0.707107, 0]})
			var tr: Array = t.get("translation", [0, 0, 0])
			var ro: Array = t.get("rotation", [0, 0, 0, 1])
			w.transform = Transform3D(Basis(Quaternion(ro[0], ro[1], ro[2], ro[3])), Vector3(tr[0], tr[1], tr[2]))
			w.name = wid.substr(7)
			w.visible = false
			hand.add_child(w)
	if cls == "soldier":
		var sock := ArtLibrary.named(model, String(a.get("socket", "WeaponSocket"))) as Node3D
		var rk := lib.instantiate_id("weapon:rocket")
		if sock != null and rk != null:
			rk.name = "rocket"
			rk.visible = false
			sock.add_child(rk)
		elif rk != null:
			rk.free()


func _prop(r: Dictionary, wanted: String) -> Node3D:
	var info: Dictionary = r.node.get_meta("info")
	if not info.has("props"):
		var props := {}
		for n in ArtLibrary._all(info.model):
			if String(n.name) in ["frag", "molotov", "rocket", "ClassWeapon", "UnderstripWeapon"]:
				props[String(n.name)] = n
		info.props = props
	return info.props.get(wanted)


# ---------------------------------------------------------------- records

## model: [key, build] (_player_model), or a library id, whose builder (_id_model) is made only for a new record
func _rec(key: String, model, kind: String) -> Dictionary:
	var mk: String = model if model is String else model[0]
	var r: Dictionary = recs.get(key, {})
	if not r.is_empty() and r.mkey != mk:   # changed class or outfit
		_release(r)
		r = {}
	if r.is_empty():
		if model is String:
			model = _id_model(model)
		var n := _take(model[0], model[1])
		if n == null:
			return {}
		var info: Dictionary = n.get_meta("info")
		r = {"key": key, "mkey": model[0], "node": n, "info": info, "ap": info.ap, "cid": info.cid, "kind": kind, "clip": "", "once": "",
			"once_end": 0.0, "lx": INF, "ly": 0.0, "spd": 0.0, "vx": 0.0, "vy": 0.0, "ang": 0.0, "acc": 0.0, "fired": -9.0, "seen": 0,
			"prev": {}, "st": 0, "bfam": "", "flash_t": 0.0, "alpha": 1.0, "fresh": true}
		recs[key] = r
	r.seen = frame_n
	return r


func on_flash(e: Dictionary) -> void:
	shots.append([float(e.x), float(e.y)])


func on_sfx(e: Dictionary) -> void:
	var nm := str(e.get("name", ""))
	if nm in ["lob", "rocket"] and e.get("x", -1.0) >= 0:
		throws.append([float(e.x), float(e.y), nm])


func _near(list: Array, x: float, y: float, r: float) -> int:
	for i in list.size():
		if absf(list[i][0] - x) < r and absf(list[i][1] - y) < r:
			return i
	return -1


# ---------------------------------------------------------------- the frame

func frame(dt: float) -> void:
	frame_n += 1
	time += dt
	var marg: float = Quality3D.draw_margin
	var mid: Vector2 = V.m.v.screen_to_world(V.m.v.W / 2.0, V.m.v.H / 2.0)   # the ground at the screen's centre
	var cx: float = mid.x
	var cz: float = mid.y
	for p in sim.players.values():
		if p.get("out", false):
			continue
		var r := _rec("p:" + str(p.id), _player_model(p), "player")
		if not r.is_empty():
			_player(r, p, dt)
	var q: Dictionary = sim.qm
	if not q.get("gone", false) and not q.is_empty() and lib.has("npc:delgado"):
		var r := _rec("qm", "npc:delgado", "qm")
		if not r.is_empty():
			_delgado(r, q, dt)
	if sim.casino():
		_casino_staff(dt)
	for e in sim.enemies:
		if e.get("dead", false) or e.type == "drone":
			continue
		var cid: String = "enemy:" + (str(e.boss) + ("_pilot" if e.get("pilot", false) else "") if e.type == "boss" else str(e.type))
		if not lib.has(cid):
			cid = "enemy:rifle"
		var r := _rec("e:" + str(e.id), cid, "boss" if e.type == "boss" else "enemy")
		if not r.is_empty():
			_enemy(r, e, dt)
	for k in recs.keys():
		var r: Dictionary = recs[k]
		if r.seen != frame_n:
			recs.erase(k)
			if r.kind == "enemy" or r.kind == "boss":   # the body stays a moment, falling, then fades
				_play(r, "Death", 1.0, 0.08)
				corpses.append({"node": r.node, "mkey": r.mkey, "t": 0.0, "ap": r.ap})
			else:
				_release(r)
	for i in range(corpses.size() - 1, -1, -1):
		var c: Dictionary = corpses[i]
		c.t += dt
		if c.ap != null:
			c.ap.advance(dt)
		if c.t > 1.3:
			var a := clampf((c.t - 1.3) / 0.5, 0, 1)
			for g in c.node.get_meta("info").geoms:
				fade(g, 1.0 - a)
		if c.t > 1.8:
			_park(c.node, c.mkey)
			corpses.remove_at(i)
	var ta := Time.get_ticks_usec()
	# the animation clocks: near the camera centre at full rate, far and off-screen ones slower
	for k in recs:
		var r: Dictionary = recs[k]
		if r.ap == null or not r.node.visible:
			continue
		var d := Vector2(r.node.position.x - cx, r.node.position.z - cz).length()
		var on_screen := _on_screen(r.node.position, marg)
		var rate: float = Quality3D.anim_rate if on_screen and d < Quality3D.anim_near else Quality3D.anim_far
		r.acc += dt
		if r.acc >= 1.0 / rate - 0.0001:
			r.ap.advance(r.acc)
			r.acc = 0.0
	anim_us = Time.get_ticks_usec() - ta
	shots.clear()
	throws.clear()


func _on_screen(p: Vector3, marg: float) -> bool:
	var s: Vector2 = V.screen_of(p)
	var pad: float = marg * V.m.v.TW2 + 60.0
	return s.x > -pad and s.x < V.m.v.W + pad and s.y > -pad and s.y < V.m.v.H + pad * 1.5


## position, facing (smoothly, toward the aim), measured speed and direction of travel
func _place(r: Dictionary, x: float, y: float, aim: Vector2, dt: float, lift: float = 0.0) -> void:
	var pos: Vector3 = V.at(x, y, lift)
	if r.lx == INF:
		r.lx = x
		r.ly = y
	var vx: float = (x - r.lx) / maxf(dt, 0.001)
	var vy: float = (y - r.ly) / maxf(dt, 0.001)
	if absf(x - r.lx) > 2.0 or absf(y - r.ly) > 2.0:   # a teleport (respawn, a new map)
		vx = 0.0
		vy = 0.0
	var k := 1.0 - exp(-dt * 10.0)
	r.vx += (vx - r.vx) * k
	r.vy += (vy - r.vy) * k
	r.spd = Vector2(r.vx, r.vy).length()
	r.lx = x
	r.ly = y
	r.node.position = pos
	if aim.length() > 0.01:
		var want := atan2(aim.x, aim.y)
		r.ang = want if r.fresh else lerp_angle(r.ang, want, 1.0 - exp(-dt * 16.0))
	r.node.rotation = Vector3(0, r.ang, 0)
	r.fresh = false
	r.node.visible = _on_screen(pos, Quality3D.draw_margin)


## the walking clip for how fast and which way (relative to the facing) the body travels
func _gait(r: Dictionary, run_at: float) -> Array:
	var sp: float = r.spd
	if sp < 0.25:
		return ["Idle_Loop", 1.0]
	var C := _clips(r.cid)
	var f := Vector2(sin(r.ang), cos(r.ang))
	var v := Vector2(r.vx, r.vy) / maxf(sp, 0.001)
	var fwd := f.dot(v)
	var side := f.x * v.y - f.y * v.x
	if sp > run_at and fwd > 0.5 and C.has("Run_Forward_Loop"):
		return ["Run_Forward_Loop", clampf(sp / run_at * 0.9, 0.8, 2.0)]
	var rate := clampf(sp / 1.25, 0.6, 2.4)
	if fwd > 0.6 or not C.has("Walk_Backward_Loop"):
		return ["Walk_Forward_Loop", rate]
	if fwd < -0.6:
		return ["Walk_Backward_Loop", rate]
	if C.has("Strafe_Left_Loop"):
		return ["Strafe_Right_Loop" if side > 0 else "Strafe_Left_Loop", rate]
	return ["Walk_Forward_Loop", rate]


func _play(r: Dictionary, clip: String, speed: float = 1.0, blend: float = 0.12) -> void:
	var ap: AnimationPlayer = r.ap
	if ap == null:
		return
	if not ap.has_animation(clip):
		clip = "Idle_Loop"
		if not ap.has_animation(clip):
			return
	ap.speed_scale = speed
	if r.clip != clip or not ap.is_playing():
		ap.play(clip, blend)
		r.clip = clip


## a one-shot that holds the body for its length (unless something stronger comes)
func _once(r: Dictionary, clip: String, speed: float = 1.0) -> void:
	var C := _clips(r.cid)
	if not C.has(clip):
		return
	r.once = clip
	r.once_end = time + C[clip] / maxf(speed, 0.05)
	r.once_speed = speed
	if r.ap != null and r.ap.has_animation(clip):
		r.ap.speed_scale = speed
		r.ap.play(clip, 0.06)
		r.ap.seek(0.0, true)
		r.clip = clip


func _once_on(r: Dictionary) -> bool:
	return r.once != "" and time < r.once_end


## hit: the body kicks (a short swell; an overlay pass reads as see-through in the Compatibility renderer); faded
## (stealth) through see-through copies of its materials (fade)
func _flash(r: Dictionary, on: bool, alpha: float = 1.0) -> void:
	var k := 1.0 + (0.06 if on else 0.0)
	r.node.scale = Vector3.ONE * V3.CHAR * k
	if is_equal_approx(r.alpha, alpha):
		return
	r.alpha = alpha
	for g in r.info.geoms:
		fade(g, alpha)


## a slim ring under a soldier in their team colour (PvP) or slot colour (the online crew)
func _ring(r: Dictionary, col_html: String) -> void:
	if ring_scene == null:
		return
	var info: Dictionary = r.info
	if not info.has("ring"):
		var rn: Node3D = ring_scene.instantiate()
		rn.scale = Vector3(0.62, 1.0, 0.62) / V3.CHAR * 0.62
		r.node.add_child(rn)
		info.ring = rn
		info.ring_col = ""
	var rn: Node3D = info.ring
	if col_html == "":
		rn.visible = false
		return
	rn.visible = true
	if info.ring_col != col_html:
		info.ring_col = col_html
		if not ring_mats.has(col_html):
			var mt := StandardMaterial3D.new()
			mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mt.albedo_color = Color.html(col_html)
			ring_mats[col_html] = mt
		for g in ArtLibrary._all(rn):
			if g is GeometryInstance3D:
				g.material_override = ring_mats[col_html]


func _player(r: Dictionary, p: Dictionary, dt: float) -> void:
	var seat: int = int(p.get("seat", 0))
	var pos := Vector2(p.x, p.y)
	if seat and sim.casino():
		var S: Dictionary = CasinoView.seat_of(seat)
		if S.has("pos"):
			pos = Vector2(S.pos[0], S.pos[1])
	var water := _wading(p.x, p.y)
	var face: Vector2 = p.aim
	if sim.rolling(p) and _roll_forward(p):   # a forward roll faces the way it goes
		face = Vector2(p.dgX, p.dgY)
	_place(r, pos.x, pos.y, face, dt, -0.08 if water else 0.0)
	var team_col := ""
	if sim.pvp() == "base" and Pal.TEAMS.has(str(p.get("team", ""))):
		team_col = Pal.TEAMS[p.team].col
	elif sim.pvp() == "ffa" or (V.m.net.is_online() and sim.players.size() > 1):
		team_col = Pal.SLOTCOL[int(p.slot) % 6]
	_ring(r, team_col if p.alive or p.downed else "")
	var pr: Dictionary = r.prev
	var C := _clips(r.cid)
	# events this frame: a shot from here, a throw, the rocket, a wall placed
	if _near(shots, p.x + p.aim.x * 0.4, p.y + p.aim.y * 0.4, 0.5) >= 0 or (p.get("sinceShot", 9.0) < pr.get("since", 9.0) and p.get("sinceShot", 9.0) < 0.05):
		r.fired = time
	var ti := _near(throws, p.x, p.y, 0.3)
	if ti >= 0 and p.alive:
		if throws[ti][2] == "rocket":
			_once(r, "Ability_Rocket", 1.6)
			r.prop = "rocket"
		else:
			_once(r, "Throw_Grenade", 1.5)
			r.prop = "molotov" if p.cls == "grenadier" and p.get("perk", {}).get("molotov", false) and sim.pvp() == "" else "frag"
		r.prop_end = time + 0.38
	if p.get("bcd", 0.0) > pr.get("bcd", 0.0) + 0.05 and p.alive:
		_once(r, "Interact_Build", 1.6)
	var hurt: bool = p.get("hurt", 9.0) < 0.12 or p.get("flash", 0.0) > 0.0
	# the clip
	var alive: bool = p.alive
	var rolling: bool = sim.rolling(p)
	if not alive and p.downed:
		_play(r, "Downed_Loop")
		r.once = ""
	elif not alive:
		if r.clip != "Death":
			_play(r, "Death", 1.0, 0.06)
	elif pr.get("downed", false) and alive:
		_once(r, "Revive", 1.4)
	if alive:
		if rolling:
			_roll(r, p)
		elif seat:
			_play(r, "Idle_Loop")
		elif _once_on(r):
			pass
		elif p.get("rl", 0.0) > 0 and C.has("Reload_Shell"):
			_play(r, "Reload_Shell", 1.3)
		elif (p.get("bolt", 0.0) > 0 or p.get("boltF", 0.0) > 0) and (C.has("Cycle_Bolt") or C.has("Cycle_Pump")) and time - r.fired > 0.08:
			_play(r, "Cycle_Bolt" if C.has("Cycle_Bolt") else "Cycle_Pump", 1.4)
		elif time - r.fired < 0.16 and r.spd < 0.4:
			if r.clip != "Attack_Primary" or r.ap.current_animation_position > 0.12:
				_play(r, "Attack_Primary", 1.6, 0.04)
				r.ap.seek(0.0, true)
		elif hurt and r.spd < 0.4 and C.has("Hit_Front") and r.clip != "Hit_Front":
			_once(r, "Hit_Front", 1.0)
		else:
			var g := _gait(r, 2.2)
			if g[0] == "Idle_Loop" and time - r.fired < 2.0 and C.has("Aim_Loop"):
				g[0] = "Aim_Loop"
			_play(r, g[0], g[1])
	# the props in hand
	for nm in ["frag", "molotov", "rocket"]:
		var pn := _prop(r, nm)
		if pn != null:
			pn.visible = r.get("prop", "") == nm and _once_on(r) and (nm == "rocket" or time < r.get("prop_end", 0.0))
	var ug := _prop(r,"UnderstripWeapon")
	if ug!=null: ug.visible=not (r.get("prop","")=="rocket" and _once_on(r)) and not sim.casino()
	var cw := _prop(r, "ClassWeapon")
	if cw != null:
		cw.visible = ug==null and not (r.get("prop", "") == "rocket" and _once_on(r)) and not sim.casino()
	if sim.casino():
		lib.show_slot(r.info.model, "Weapon", false)
	# faded in stealth, flashed when hit
	var a := 0.5 if p.get("stl", 0.0) > 0 else 1.0
	_flash(r, hurt and alive, a)
	r.prev = {"since": p.get("sinceShot", 9.0), "bcd": p.get("bcd", 0.0), "downed": p.downed, "alive": p.alive}


## a roll within 60° of straight back from the aim is the back roll, facing the aim; any other way is a forward roll,
## facing where it goes (the library's left and right dodges are sidesteps, not rolls)
func _roll_forward(p: Dictionary) -> bool:
	return Vector2(p.dgX, p.dgY).dot(p.aim) > -0.5


## the roll: Dodge_Backward_IP or Dodge_Forward_IP scrubbed to the sim's roll clock, its anticipation, travel and
## recovery lined up with the sim's (Pal.ROLL go/end/dur against both clips' 0.12 / 0.65 / 0.833 s). In-place clips:
## the sim alone moves the body.
func _roll(r: Dictionary, p: Dictionary) -> void:
	var e: float = p.dgE
	var R: Dictionary = Pal.ROLL
	var t: float
	if e < R.go:
		t = e / R.go * 0.12
	elif e < R.end:
		t = 0.12 + (e - R.go) / (R.end - R.go) * 0.53
	else:
		t = 0.65 + (e - R.end) / (R.dur - R.end) * 0.1833
	var clip := "Dodge_Forward_IP" if _roll_forward(p) else "Dodge_Backward_IP"
	if r.ap == null or not r.ap.has_animation(clip):
		return
	if r.clip != clip:
		r.ap.play(clip, 0.03)
		r.clip = clip
	r.ap.speed_scale = 1.0
	r.ap.seek(minf(t, 0.83), true)
	r.once = ""


func _wading(x: float, y: float) -> bool:
	if sim.map_id != "river":
		return false
	var t := sim.t_at(floori(x), floori(y))
	return t == PalMaps.T_WATER or (t == PalMaps.T_LOW and sim.flood_on)


func _delgado(r: Dictionary, q: Dictionary, dt: float) -> void:
	_place(r, q.x, q.y, q.get("aim", Vector2(1, 0)), dt, -0.08 if _wading(q.x, q.y) else 0.0)
	var pr: Dictionary = r.prev
	if _near(shots, q.x + q.aim.x * 0.4, q.y + q.aim.y * 0.4, 0.5) >= 0:
		r.fired = time
	var hurt: bool = q.get("flash", 0.0) > 0
	if not q.alive:
		_play(r, "Downed_Loop")
	elif pr.get("down", false):
		_once(r, "Revive", 1.4)
	elif _once_on(r):
		pass
	elif time - r.fired < 0.18 and r.spd < 0.4:
		if r.clip != "Attack_Primary" or r.ap.current_animation_position > 0.2:
			_play(r, "Attack_Primary", 1.4, 0.04)
			r.ap.seek(0.0, true)
	elif r.spd < 0.25 and q.get("job", "") in ["construct", "repair"]:
		_play(r, "Interact_Build", 1.2)
	elif r.spd < 0.25 and q.get("job", "") == "gather" and q.get("gt", 0.0) > 0:
		_play(r, "Gather", 1.2)
	elif r.spd < 0.25 and q.get("job", "") == "revive":
		_play(r, "Support_Revive", 1.0)
	else:
		var g := _gait(r, 2.0)
		if g[0] == "Idle_Loop" and time - r.fired < 2.0:
			g[0] = "Aim_Loop"
		_play(r, g[0], g[1])
	_flash(r, hurt and q.alive)
	r.prev = {"down": not q.alive}


func _enemy(r: Dictionary, e: Dictionary, dt: float) -> void:
	var boss: bool = e.type == "boss"
	var raft: bool = e.get("raft", false)
	var lift := 0.0
	if raft:
		lift = -0.06 + sin(time * 2.2 + float(e.id)) * 0.03
	elif _wading(e.x, e.y):
		lift = -0.08
	# the Foreman underground: the body sinks away as he digs in and climbs back out when he bursts up
	var under: bool = e.get("burrow", false) or (str(e.get("boss", "")) in ["foreman", "whiteforeman"] and int(e.get("st", 0)) in [2, 4])
	r.sink = clampf(r.get("sink", 0.0) + (dt / 0.45 if under else -dt / 0.3), 0.0, 1.0)
	lift -= r.sink * 1.9
	_place(r, e.x, e.y, e.aim, dt, lift)
	if r.sink >= 1.0:
		r.node.visible = false
		return
	var C := _clips(r.cid)
	if boss:
		_boss_clip(r, e, C)
	else:
		_raider_clip(r, e, C)
	# the shieldbearer's shield goes when it breaks; the breacher's satchel once it's planted
	if e.type == "shield" and e.get("shieldBroken", false) != r.prev.get("broken", false):
		lib.show_slot(r.info.model, "Equipment_ArmL", not e.shieldBroken)
		lib.show_slot(r.info.model, "Weapon", not e.shieldBroken)
	if e.type == "breach" and e.get("planted", false) != r.prev.get("planted", false):
		lib.show_slot(r.info.model, "Equipment_Back", not e.planted)
	# THE UNDERSTRIP: the Pit Boss tears his jacket off for stage 2 (its own modular slot in the library's model)
	if boss and str(e.boss) == "pitboss" and sim.understrip():
		var jacket: bool = int(sim.game.us.get("bossStage", 0)) == 0
		if r.get("jacket", true) != jacket:
			lib.show_slot(r.info.model, "Equipment_Jacket", jacket)
			r.jacket = jacket
	# the Custodian's casing cracks for stage 2; the Gatekeeper's cab is empty once the pilot is out
	if boss and str(e.boss) == "custodian" and sim.understrip():
		var cracked: bool = int(sim.game.us.get("bossStage", 0)) > 0
		if r.get("cracked", null) != cracked:
			lib.show_slot(r.info.model, "Equipment_Damage", cracked)
			r.cracked = cracked
	if boss and str(e.boss) == "gatekeeper" and not e.get("pilot", false) and sim.understrip():
		var crewed: bool = not (e.get("gk2", false) and int(e.get("st", 0)) != 72)
		if r.get("crewed", null) != crewed:
			lib.show_slot(r.info.model, "Equipment_Pilot", crewed)
			r.crewed = crewed
	_flash(r, e.get("flash", 0.0) > 0)
	r.prev = {"broken": e.get("shieldBroken", false), "planted": e.get("planted", false)}


func _raider_clip(r: Dictionary, e: Dictionary, C: Dictionary) -> void:
	if _near(shots, e.x + e.aim.x * 0.4, e.y + e.aim.y * 0.4, 0.55) >= 0:
		_once(r, "Execute_Shoot", 1.3)
	var ti := _near(throws, e.x, e.y, 0.3)
	if ti >= 0:
		_once(r, "Execute_ThrowBottle" if C.has("Execute_ThrowBottle") else "Execute_ThrowGrenade", 1.2)
	if e.get("planted", false) and not r.prev.get("planted", false):
		_once(r, "Execute_PlantCharge", 1.0)
	if e.type == "spotter" and int(e.get("st", 0)) > 0:
		_play(r, "Execute_MarkTarget" if int(e.st) == 2 else "Tell_MarkTarget", 0.6)
		return
	if _once_on(r):
		return
	var g := _gait(r, 2.6)
	_play(r, g[0], g[1])


## a boss: the tell timed to the state (it ends when the move goes off), the move, then its recovery; walking otherwise
func _boss_clip(r: Dictionary, e: Dictionary, C: Dictionary) -> void:
	var st: int = int(e.get("st", 0))
	var table: Dictionary = BOSS_ST.get(str(e.boss) + ("_pilot" if e.get("pilot", false) else ""), {})
	var fam: String = table.get(st, "")
	if st != r.st:
		var was: String = r.bfam
		if was != "" and fam != was:   # the move went off (or the tell ran into it): Execute, then Recover
			var base := was.trim_suffix("!")
			if not was.ends_with("!") and fam != base + "!":
				_once(r, "Execute_" + base, 1.0)
				r.after = "Recover_" + base
			elif was.ends_with("!") and fam == "":
				_once(r, "Recover_" + base, 1.0)
				r.after = ""
		if fam != "":
			var base := fam.trim_suffix("!")
			if fam.ends_with("!"):
				if C.has("Execute_" + base):
					_play(r, "Execute_" + base, 0.8, 0.05)
			else:
				var tl: float = C.get("Tell_" + base, 0.8)
				var dur: float = e.get("stT", 1.0) if e.get("stM", 0.0) > 1.01 or e.get("stT", 0.0) > 1.0 else maxf(0.2, float(e.get("stT", 0.0)) * float(e.get("stM", 1.0)))
				_play(r, "Tell_" + base, clampf(tl / maxf(dur, 0.15), 0.3, 3.0), 0.08)
				r.ap.seek(0.0, true)
		r.st = st
		r.bfam = fam
	if fam != "":
		return
	if _once_on(r):
		return
	if r.get("after", "") != "" and C.has(r.after):
		_once(r, r.after, 1.0)
		r.after = ""
		return
	if st == 6:   # the Bulldozer dazed
		_play(r, "Hit_Front", 0.4)
		return
	if e.get("raft", false) and C.has("Sail_Loop"):
		_play(r, "Sail_Loop" if r.spd > 0.2 else "Idle_Loop", 1.0)
		return
	var g := _gait(r, 2.6)
	_play(r, g[0], g[1])


## the dealers at their tables, the barkeep, and the bots sitting in at Hold'em
func _casino_staff(dt: float) -> void:
	CasinoView._ready_data()
	var who: Array = []
	for t in CasinoView.TABLES:
		who.append(["cas:" + str(t.dealer.name), t.dealer.look, t.dealer.x, t.dealer.y, t.dealer.face, false])
		for k in t.seats.size():
			var w = CasinoView.taken(sim, t.n * 10 + k + 1, V.m.get("casino_ui"))
			if w is Dictionary and w.get("bot", false):
				var sp: Array = t.seats[k]
				who.append(["bot:%d" % (t.n * 10 + k), "bot", sp[0], sp[1], Vector2(t.c[0] - sp[0], t.c[1] - sp[1]).normalized(), true])
	who.append(["cas:keep", "keep", CasinoView.BAR.keep[0], CasinoView.BAR.keep[1], Vector2(0, 1), false])
	for q in who:
		var cid: String = STAFF.get(q[1], "npc:delgado")
		if not lib.has(cid):
			cid = "npc:delgado"
		var r := _rec(q[0], cid, "staff")
		if r.is_empty():
			continue
		_place(r, q[2], q[3], q[4], dt, -0.12 if q[5] else 0.0)
		lib.show_slot(r.info.model, "Weapon", false)
		_play(r, "Idle_Loop")


# ---------------------------------------------------------------- labels over the 3D people (main canvas)

func paint_labels() -> void:
	var m = V.m
	var u: float = m.v.u
	for p in sim.players.values():   # outfit auras (16b-auras.js) and glowing ground rings: the models don't carry them, so the 2D's own draw over
		if p.get("out", false) or not p.alive:
			continue
		var o: Dictionary = m.player_look(p)
		if o.get("aura") or o.get("glow") or o.get("ring"):
			var sc: Vector2 = m.iso(p.x, p.y)
			var fa: float = 0.5 if p.stl > 0 else 1.0
			Wardrobe.ground_glow(m.cv, o, sc.x, sc.y, u * Figure.FIG, fa)
			if o.get("aura"):
				CosFx.paint_aura(m.cv, o.aura, sc.x, sc.y, u * Figure.FIG, sim.game.time, fa, "ground")
				CosFx.paint_aura(m.cv, o.aura, sc.x, sc.y, u * Figure.FIG, sim.game.time, fa, "top")
	for e in sim.enemies:
		if e.dead or e.type != "boss":
			continue
		var B: Dictionary = Sim.boss_def(e.boss)
		var big: float = B.get("big", 1.45)
		var under: bool = e.get("burrow", false) or (e.boss in ["foreman", "whiteforeman"] and int(e.get("st", 0)) in [2, 4])
		var sc: Vector2 = m.iso(e.x, e.y)
		if under:
			m.label(B.name, sc.x, sc.y - 22 * u, m.c(B.col), 11)
		else:
			m.label(B.name, sc.x, sc.y - 46 * u * big, m.c(B.col), 11)
	var q: Dictionary = sim.qm
	if not q.get("gone", false) and not q.alive:
		var sc: Vector2 = m.iso(q.x, q.y)
		m.label("DELGADO · DOWN", sc.x, sc.y - 20 * u, m.c("#d65a3a"), 10)
		if q.get("revive", 0.0) > 0:
			m.cv.draw_arc(Vector2(sc.x, sc.y - 10 * u), 10 * u, -PI / 2, -PI / 2 + TAU * clampf(q.revive / 2.0, 0, 1), 32, m.c("#a9bccb"), 3 * u)
	for p in sim.players.values():
		if p.get("out", false) or p.alive or not p.downed:
			continue
		var tag := "DOWN · UNTIL THE RAID IS BROKEN" if p.rt > 1e5 else "DOWN · %d" % ceili(p.rt)
		var sc: Vector2 = m.iso(p.x, p.y)
		m.label(tag, sc.x, sc.y - 20 * u, m.c("#d65a3a"), 10)
		if p.revive > 0:
			m.cv.draw_arc(Vector2(sc.x, sc.y - 10 * u), 10 * u, -PI / 2, -PI / 2 + TAU * clampf(p.revive / 2.2, 0, 1), 32, m.c("#a9bccb"), 3 * u)
