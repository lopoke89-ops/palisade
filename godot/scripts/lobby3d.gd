class_name Lobby3D
extends SubViewportContainer
## The lobby stage in 3D: the crew from the model library, standing where the browser paints them. The painted lobby
## background stays behind the menus (as in the browser); this layer is see-through and holds only the people and
## their pads. Each one stands on the browser's stage canvas (19b-social-lobby.js STAGE, Menus.STAGE2D: a 1000x780
## canvas fitted into the page's hero box), at its scale, turned as the browser turns them; the camera is
## orthographic and pitched so the pads lie at the browser's 0.22 squash. Slot 0 is this screen's player, in front.
## The empty spots' "+" and the others' name plates are drawn over it by the page (Menus.Hero2D). Outfit auras
## (16b-auras.js) are the browser's own drawing: their ground part on `under`, which the menus put just below this
## layer, the rest on `over`, above the models; yours moves, the others' hold still, as in the browser.

const PITCH := 12.7   # degrees down: sin(12.7°) = 0.22, the browser's pad ellipse
const FIG := 39.2   # the browser's figure is this many canvas units tall per unit of stage scale
const CAM_SIZE := 10.0   # world units across the viewport's height
const PAD := Color("#b4edee")   # the pads' outline and fill, someone on it or not (drawPartyPreview's pad)
const PAD_EMPTY := Color("#597386")
const FILL := Color(170 / 255.0, 239 / 255.0, 239 / 255.0, 0.12)
const FILL_EMPTY := Color(122 / 255.0, 171 / 255.0, 192 / 255.0, 0.06)

var lib: ArtLibrary
var vp: SubViewport
var world: Node3D
var cam: Camera3D
var party_root: Node3D
var mode := "solo"
var crew: Array = []   # [{name, cls, cos: Dictionary, ready, slot}] (slot 0 first)
var hero := Rect2()   # the page's hero box, in this control's coordinates
var slots: Array = []   # per slot: {node, ring, mats, fill, model, key, at, k, look}
var under := Control.new()
var over := Control.new()
var _ref_h := 0.0   # the standard Soldier's height at scale 1: every outfit is scaled by it, not by its own hat
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
	vp.transparent_bg = true
	add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CAM_SIZE
	cam.near = 0.05
	cam.far = 200.0
	cam.rotation_degrees = Vector3(-PITCH, 0, 0)
	world.add_child(cam)
	cam.current = true
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
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
	party_root = Node3D.new()
	world.add_child(party_root)
	for c in [under, over]:
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	under.draw.connect(func(): _paint_auras(under, "ground"))
	over.draw.connect(func(): _paint_auras(over, "top"))
	add_child(over)


## who stands on the stage: mode "solo" (this player), "party" (the room, this player in slot 0) or "locker"; box: the
## page's hero box in global coordinates (the browser's partyHero)
func set_crew(m: String, people: Array, box: Rect2) -> void:
	mode = m
	crew = people
	hero = Rect2(box.position - global_position, box.size)
	_layout()


## where the browser's canvas puts a point of the stage, on this control (object-fit: contain, centred)
static func canvas_xf(box: Rect2) -> Array:
	var k := minf(box.size.x / 1000.0, box.size.y / 780.0)
	return [k, box.position + Vector2((box.size.x - 1000 * k) / 2, (box.size.y - 780 * k) / 2)]


## this player's spot: the Locker lifts it to leave room below the feet for glowing rings and other skin effects
static func me_spot(locker: bool) -> Array:
	var me: Array = Menus.STAGE2D.me
	return [me[0], minf(me[1], 780 - me[2] * 11 - 8), me[2]] if locker else me


func _layout() -> void:
	if hero.size.x <= 0 or hero.size.y <= 0 or vp.size.y <= 0:
		for S in slots:
			S.node.visible = false
		return
	if _ref_h <= 0:
		var ref := lib.build("soldier", {"skin": "std", "hat": "class"})
		if ref != null:
			party_root.add_child(ref)
			_ref_h = maxf(0.5, _top(ref) - ref.global_position.y)
			party_root.remove_child(ref)
			ref.queue_free()
	var xf := canvas_xf(hero)
	var k: float = xf[0]
	var off: Vector2 = xf[1]
	var ppu := vp.size.y / CAM_SIZE   # pixels per world unit
	var spots: Array = [me_spot(mode == "locker")]
	if mode == "party":
		spots.append_array(Menus.STAGE2D.others)
	while slots.size() < spots.size():
		var node := Node3D.new()
		party_root.add_child(node)
		var ring := lib.instantiate_file("models/utilities/player_ring.glb")
		var mats: Array = []
		if ring != null:
			node.add_child(ring)
			for mi in ArtLibrary._all(ring):   # a copy of the ring's material each, flat in the pad's colour
				if mi is MeshInstance3D:
					for s in mi.mesh.get_surface_count():
						var mat = mi.get_active_material(s)
						if mat is BaseMaterial3D:
							mat = mat.duplicate()
							mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
							mat.emission_enabled = false
							mi.set_surface_override_material(s, mat)
							mats.append(mat)
		var fill := MeshInstance3D.new()   # the pad's faint fill inside the ring
		var disc := CylinderMesh.new()
		disc.top_radius = 1.0
		disc.bottom_radius = 1.0
		disc.height = 0.002
		disc.radial_segments = 48
		fill.mesh = disc
		fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fill.material_override = fm
		node.add_child(fill)
		slots.append({"node": node, "ring": ring, "mats": mats, "fill": fill, "model": null, "key": "", "look": {}})
	for i in slots.size():
		var S: Dictionary = slots[i]
		var who: Dictionary = crew[i] if i < crew.size() else {}
		S.node.visible = i < spots.size() and (not who.is_empty() or mode == "party")
		if not S.node.visible:
			continue
		var sp: Array = spots[i]
		# the feet on the canvas point (the browser paints the figure 4 units up), back rows further from the camera
		var at := off + Vector2(float(sp[0]), float(sp[1]) - 4.0) * k
		S.at = at
		S.k = float(sp[2]) * k
		S.node.position = cam.project_position(at, 40.0 + (780.0 - float(sp[1])) * 0.05)
		S.node.rotation.y = 0.0 if i == 0 else [0.62, -0.62, 0.5, -0.5, 0.1][i - 1]   # slot 0 turns in _process
		var sc := float(sp[2]) * k / ppu   # one canvas unit of this figure, in world units
		var r := (9.5 if i > 0 else 11.5) * sc   # the pad's radius
		S.fill.scale = Vector3(r, 1, r)
		if S.ring != null:
			S.ring.scale = Vector3(r / 1.011, 1, r / 1.011)   # the ring model is 1.011 across
		var key := "" if who.is_empty() else "%s|%s|%s" % [who.cls, who.cos.get("skin", "std"), who.cos.get("hat", "class")]
		if key != S.key:   # rebuild only the slot that changed
			if S.model != null:
				S.node.remove_child(S.model)
				S.model.queue_free()
				S.model = null
			S.key = key
			S.look = {} if who.is_empty() else Wardrobe.look_for(who.cos, who.cls)
			if not who.is_empty():
				S.model = lib.build(who.cls, who.cos, 0.37 * i, "Aim_Loop")
				if S.model != null:
					S.node.add_child(S.model)
		if S.model != null:
			S.model.scale = Vector3.ONE * (FIG * sc / cos(deg_to_rad(PITCH)) / maxf(0.5, _ref_h))
		for mat in S.mats:
			mat.albedo_color = PAD if not who.is_empty() else PAD_EMPTY
		S.fill.material_override.albedo_color = FILL if not who.is_empty() else FILL_EMPTY
	under.queue_redraw()
	over.queue_redraw()


## the auras of everyone standing here (this player's moving, as stageMe; the others' held at one moment), and under
## them the skins' glowing ground rings
func _paint_auras(ci: CanvasItem, part: String) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in slots.size():
		var S: Dictionary = slots[i]
		if S.look.is_empty() or not S.node.visible or S.model == null:
			continue
		if part == "ground":
			Wardrobe.ground_glow(ci, S.look, S.at.x, S.at.y, S.k)
		if S.look.get("aura"):
			CosFx.paint_aura(ci, S.look.aura, S.at.x, S.at.y, S.k, t if i == 0 and not PalSettings.reduce_motion else 1.3, 1, part)


## the top of a dressed model (its hat included), in world height
static func _top(model: Node3D) -> float:
	var top := -INF
	for n in ArtLibrary._all(model):
		if n is MeshInstance3D:
			var b: AABB = n.global_transform * n.get_aabb()
			top = maxf(top, b.end.y)
	return top if top > -INF else model.global_position.y + 2.0


func _process(_dt: float) -> void:
	if not is_visible_in_tree():
		return
	if size != _size:
		_size = size
		_layout()
	if not slots.is_empty():   # this player turns slowly, as in the browser (stageAngle)
		var t := Time.get_ticks_msec() / 1000.0
		slots[0].node.rotation.y = 0.35 + (0.0 if PalSettings.reduce_motion else sin(t / 4.5) * 0.09)
		if slots[0].look.get("aura"):
			under.queue_redraw()
			over.queue_redraw()
