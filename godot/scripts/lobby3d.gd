class_name Lobby3D
extends SubViewportContainer
## The lobby stage in 3D: the equipped lobby environment, and the crew standing on it in the model library's captured
## layouts (lobby_layouts.json: the camera with its lens shift, six party slots, solo, locker; desktop and portrait).
## Slot 0 is this screen's player, in front; the others keep their slots as people join and leave. Under each one a
## slim ring in their slot colour (brighter when ready); their name floats above them in the overlay.
## Sits behind the menus in place of the painted background (menus.gd); the menus stay on top.

const LAYOUT := {"solo": "02 - Peach Wire - solo", "party": "01 - Peach Wire - full party", "locker": "03 - Peach Wire - locker",
	"solo_tall": "05 - Peach Wire - mobile solo", "party_tall": "04 - Peach Wire - mobile party"}
const LobbyLayout = preload("res://scripts/lobby_layout.gd")

var lib: ArtLibrary
var vp: SubViewport
var world: Node3D
var cam: Camera3D
var env_root: Node3D
var party_root: Node3D
var names: Control
var layouts := {}
var bg := ""
var mode := "solo"
var crew: Array = []   # [{name, cls, cos: Dictionary, ready, slot}] (slot 0 first)
var slots: Array = []   # per slot: {node, ring, ring_mat, model, key, label}
var aim_x := -1.0   # where on screen (0..1 across) slot 0 should stand; -1 keeps the captured framing
var _tall := false
var _size := Vector2.ZERO


static func available() -> bool:
	return ArtLibrary.get_lib() != null and ResourceLoader.exists("res://palisade_art/models/utilities/player_ring.glb")


func _init() -> void:
	lib = ArtLibrary.get_lib()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp = SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	vp.msaa_3d = Viewport.MSAA_2X
	vp.own_world_3d = true
	add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	cam = Camera3D.new()
	world.add_child(cam)
	cam.current = true
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.045, 0.04)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.6, 0.62)
	e.ambient_light_energy = 0.9
	we.environment = e
	world.add_child(we)
	var key := DirectionalLight3D.new()   # a restrained key with soft shadows, and an opposing rim
	key.rotation_degrees = Vector3(-42, 28, 0)
	key.light_energy = 1.05
	key.shadow_enabled = true
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18, 205, 0)
	rim.light_energy = 0.55
	world.add_child(rim)
	env_root = Node3D.new()
	world.add_child(env_root)
	party_root = Node3D.new()
	world.add_child(party_root)
	names = Control.new()
	names.set_anchors_preset(Control.PRESET_FULL_RECT)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(names)
	var d = JSON.parse_string(FileAccess.get_file_as_string(ArtLibrary.ROOT + "/lobby_layouts.json"))
	layouts = d.get("layouts", {}) if d is Dictionary else {}


## the lobby environment behind everyone (falls back to Campfire Dusk if this one isn't in the library)
func set_bg(id: String) -> void:
	if id == bg:
		return
	bg = id
	for c in env_root.get_children():
		env_root.remove_child(c)
		c.queue_free()
	var n := lib.instantiate_id("bg:" + id)
	if n == null:
		n = lib.instantiate_id("bg:campfire")
	if n == null:
		return
	env_root.add_child(n)
	var ap := lib.animation_player(n)   # the environments' own motion (40 of them have some)
	if ap != null and not ap.get_animation_list().is_empty():
		var a: String = ap.get_animation_list()[0]
		ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		ap.play(a)
		if PalSettings.reduce_motion:
			ap.pause()


## who stands on the stage: mode "solo" (this player), "party" (the room, this player in slot 0) or "locker"
func set_crew(m: String, people: Array, slot0_x: float = -1.0) -> void:
	mode = m
	aim_x = slot0_x
	crew = people
	_layout()


func _layout() -> void:
	_tall = size.y > size.x
	var key := (mode + "_tall") if _tall and LAYOUT.has(mode + "_tall") else mode
	var L: Dictionary = layouts.get(LAYOUT.get(key, LAYOUT.solo), {})
	if L.is_empty():
		return
	LobbyLayout.configure_camera(cam, L.camera)
	var recs: Array = L.slots
	if aim_x >= 0 and not _tall and size.y > 0:   # slide the framing sideways (the lens shift), so the crew clears the menus
		cam.frustum_offset.x -= (aim_x - float(recs[0].screen_uv[0])) * cam.size * size.x / size.y
	var want := 1 if mode != "party" else 6
	while slots.size() < want:
		var node := Node3D.new()
		party_root.add_child(node)
		var ring := lib.instantiate_file("models/utilities/player_ring.glb")
		var mats: Array = []
		if ring != null:
			node.add_child(ring)
			for mi in ArtLibrary._all(ring):   # a copy of the ring's material each, so tinting one doesn't tint all
				if mi is MeshInstance3D:
					for s in mi.mesh.get_surface_count():
						var mat = mi.get_active_material(s)
						if mat is BaseMaterial3D:
							mat = mat.duplicate()
							mi.set_surface_override_material(s, mat)
							mats.append(mat)
		var lab := Label.new()
		lab.add_theme_font_size_override("font_size", 14)
		lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		lab.add_theme_constant_override("outline_size", 5)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		names.add_child(lab)
		slots.append({"node": node, "ring": ring, "mats": mats, "model": null, "key": "", "label": lab, "top": 2.0})
	for i in slots.size():
		var S: Dictionary = slots[i]
		var used := i < want and i < recs.size()
		S.node.visible = used
		S.label.visible = false
		if not used:
			continue
		var r: Dictionary = recs[i]
		S.node.position = LobbyLayout.blender_point(r.position)
		if S.ring != null:
			S.ring.scale = Vector3(float(r.ring_radius), 1, float(r.ring_radius))
		var who: Dictionary = crew[i] if i < crew.size() else {}
		if who.is_empty() and mode != "party":   # solo and the Locker: no empty ring, just the place
			S.node.visible = false
		var k := "" if who.is_empty() else "%s|%s|%s|%s" % [who.cls, who.cos.get("skin", "std"), who.cos.get("hat", "class"), r.scale]
		if k != S.key:   # rebuild only the slot that changed
			if S.model != null:
				S.node.remove_child(S.model)
				S.model.queue_free()
				S.model = null
			S.key = k
			if not who.is_empty():
				S.model = lib.build(who.cls, who.cos, 0.37 * i)
				if S.model != null:
					S.model.scale = Vector3.ONE * float(r.scale)
					S.node.add_child(S.model)
					S.top = _top(S.model) - S.node.global_position.y
		var col: Color = Color(Pal.SLOTCOL[int(who.get("slot", i)) % Pal.SLOTCOL.size()]) if not who.is_empty() else Color(0.55, 0.52, 0.46)
		var lit: float = 1.6 if who.get("ready", false) else (0.9 if not who.is_empty() else 0.25)
		for mat in S.mats:
			mat.albedo_color = col
			mat.emission_enabled = true
			mat.emission = col
			mat.emission_energy_multiplier = lit
		if not who.is_empty() and mode == "party":
			S.label.text = str(who.name).to_upper() + ("  ✓" if who.get("ready", false) else "")
			S.label.add_theme_color_override("font_color", col.lightened(0.25))
			S.label.visible = true
	_place_names()


## the top of a dressed model (its hat included), in world height
static func _top(model: Node3D) -> float:
	var top := -INF
	for n in ArtLibrary._all(model):
		if n is MeshInstance3D and n.is_visible_in_tree():
			var b: AABB = n.global_transform * n.get_aabb()
			top = maxf(top, b.end.y)
	return top if top > -INF else model.global_position.y + 2.0


## names float above the heads: project each slot's head height into the overlay
func _place_names() -> void:
	for i in slots.size():
		var S: Dictionary = slots[i]
		if not S.label.visible:
			continue
		var head: Vector3 = S.node.global_position + Vector3(0, S.top + 0.12, 0)
		if cam.is_position_behind(head):
			S.label.visible = false
			continue
		var p := cam.unproject_position(head) * (size / Vector2(vp.size)) if vp.size.x > 0 else Vector2.ZERO
		S.label.reset_size()
		S.label.position = p - Vector2(S.label.size.x / 2, S.label.size.y)


func _process(_dt: float) -> void:
	if not is_visible_in_tree():
		return
	if size != _size or (size.y > size.x) != _tall:
		_size = size
		_layout()
	else:
		_place_names()
