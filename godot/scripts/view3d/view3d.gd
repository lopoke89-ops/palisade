class_name View3D
extends Node3D
## The game drawn in 3D: the world, the people and the effects from the model library, under the 2D HUD.
## The simulation stays the authority: this only reads sim state (and the main node's effect lists) every frame.
## The camera reproduces the 2D isometric projection exactly (iso_view.gd: x' = (x - y) TW2, y' = (x + y) TH2 - z h),
## an orthographic camera pitched 30 degrees and turned 45, so everything the HUD places through iso() (nameplates,
## prompts, the crosshair, boss warnings, the night's light pools) lines up with the 3D view without changes.
##
## World units: one tile is one unit on X (the sim's x) and Z (the sim's y); Y is up. A 2D "base pixel" of height
## (multiplied by u on screen) is PXV units of Y, so a terrace (24 px) is TER and a wall (WH) is WALL_H.

const SQ2 := 1.4142135623730951
const COS30 := 0.8660254037844386
const PXV := 1.0 / (32.0 * SQ2 * COS30)   # Y units per base pixel of 2D height
const PXH := 1.0 / (32.0 * SQ2)   # ground units per base pixel across the screen
const TER := 24.0 * PXV   # one Frostpeak terrace
const WALL_H := 27.2 * PXV   # WH: a wall's height
const CHAR := 0.52   # the library's metres to tiles: a soldier stands as tall as the 2D figure (37 px at FIG)
## the camera's axes: screen right, screen up, and back toward the viewer
const CAM_R := Vector3(1.0 / SQ2, 0.0, -1.0 / SQ2)
const CAM_U := Vector3(-0.5 / SQ2, COS30, -0.5 / SQ2)
const CAM_B := Vector3(COS30 / SQ2, 0.5, COS30 / SQ2)

var m   # main.gd
var sim: Sim
var lib: ArtLibrary
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var actors: V3Actors
var world: V3World
var fx: V3Fx
var fill: DirectionalLight3D   # a soft front light on the people only (layer 2), as the lobby lights them
var parts_us := [0, 0, 0]   # world, people, effects
var frame_us := 0   # how long the last frame's 3D update took on the CPU (the screenshot test reports it)
var on := true   # drawing (the settings switch; the view also pauses behind the menus' own 3D lobby)
const AMBIENT := 0.45   # the shadowed share of a face's colour; the sun (world shaders' sun_k) brings lit faces to it


static func available() -> bool:
	return ArtLibrary.get_lib() != null and ResourceLoader.exists("res://palisade_art/models/players/soldier.glb")


func _init(main) -> void:
	m = main
	sim = main.sim
	lib = ArtLibrary.get_lib()
	name = "View3D"
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 0.5
	cam.far = 260.0
	cam.basis = Basis(CAM_R, CAM_U, CAM_B)
	add_child(cam)
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.html("#151a12")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.62, 0.66)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	sun.basis = Basis.looking_at(Vector3(0.42, -1.0, -0.62), Vector3.UP)
	fill = DirectionalLight3D.new()
	fill.light_cull_mask = 2
	fill.light_energy = 0.9
	fill.shadow_enabled = false
	add_child(fill)
	fill.basis = Basis.looking_at(-CAM_B + Vector3(0.3, -0.4, 0.0), Vector3.UP)
	world = V3World.new(self)
	add_child(world)
	actors = V3Actors.new(self)
	add_child(actors)
	fx = V3Fx.new(self)
	add_child(fx)
	Quality3D.apply_viewport(main.get_viewport())


## 3D position of a sim point on the ground (z: extra height in Y units)
func at(x: float, y: float, z: float = 0.0) -> Vector3:
	return Vector3(x, sim.height_at(x, y) * TER + z, y)


## the camera that shows what iso_view shows: same centre, same scale (and so the same shake and zoom)
func sync_camera() -> void:
	var v: IsoView = m.v
	var k := v.TW2 * SQ2   # screen pixels per unit across the screen
	cam.size = v.H / k
	var g := v.screen_to_world(v.W / 2.0, v.H / 2.0)
	cam.position = Vector3(g.x, 0.0, g.y) + CAM_B * 90.0


## where a 3D point lands on screen (what iso() gives for ground points)
func screen_of(p: Vector3) -> Vector2:
	var v: IsoView = m.v
	return Vector2((p.x - p.z) * v.TW2 + v.cam_x, (p.x + p.z) * v.TH2 + v.cam_y - p.y / PXV * v.u)


## the frame: after the sim and the camera have moved
func frame(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_frame(dt)
	frame_us = Time.get_ticks_usec() - t0


func _frame(dt: float) -> void:
	var hide: bool = m.demo and m.menus.stage != null and m.menus.stage.is_inside_tree() and m.menus.active()
	visible = on and not hide
	cam.current = visible
	if not visible:
		return
	sync_camera()
	_light(dt)
	if sim.casino():   # the neon signs and slot screens glow on the 2D glow layer, as in the 2D
		CasinoView.items(m)
		var glow: Array = m.cas_glow
		for k in CasinoView.MACHINES.size():
			var mc: Dictionary = CasinoView.MACHINES[k]
			if mc.game == "sl":
				var p := screen_of(Vector3(mc.at[0] + (0.0 if mc.face == "s" else 0.25), WALL_H * 0.92, mc.at[1] + (0.25 if mc.face == "s" else 0.0)))
				var on: bool = CasinoView.taken(sim, mc.code) != null or sin(sim.game.time * 3 + k * 1.7) > -0.2
				glow.append(["dot", p.x, p.y, m.v.TW2 * 0.45, ["#ff4a6a", "#3ae0ff", "#ffd24a", "#9a6aff", "#4aff9a"][k % 5], 0.5 if on else 0.25])
	var t1 := Time.get_ticks_usec()
	world.frame(dt)
	var t2 := Time.get_ticks_usec()
	actors.frame(dt)
	var t3 := Time.get_ticks_usec()
	fx.frame(dt)
	parts_us = [t2 - t1, t3 - t2, Time.get_ticks_usec() - t3]


## the sim's events this frame, before the main node drains them (muzzle flashes tell who fired, kills, blasts)
func events(list: Array) -> void:
	if not visible:
		return
	for e in list:
		match e.k:
			"flash":
				actors.on_flash(e)
				fx.on_flash(e)
			"sfx":
				actors.on_sfx(e)
			"killfx":
				fx.kill_effect(e.x, e.y, str(e.fx))
			"map":
				world.dirty = true
				actors.clear()
				fx.clear()


## the time of day: the 2D night shade with its light pools (light.gdshader, from main's eased `light`) lies over the
## 3D picture as over the 2D one, so the 3D light stays neutral (lit faces show the 2D colours, shadowed ones
## AMBIENT of them); golden hour warms the sun a little and lengthens the shadows.
func _light(_dt: float) -> void:
	var L: Dictionary = m.light
	var warm := clampf(L.warm / 0.07, 0, 1)
	sun.light_color = Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.86, 0.7), warm)
	sun.light_energy = 1.0
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = AMBIENT
	var tilt := lerpf(-1.0, -0.6, warm)   # golden hour: a lower sun and longer shadows
	sun.basis = Basis.looking_at(Vector3(0.42, tilt, -0.62), Vector3.UP)
	sun.shadow_enabled = Quality3D.shadows > 0
	fill.light_energy = 0.9


## the world's labels in 3D mode, on the main canvas under the night shade (as the 2D draws them in the scene):
## boss names, the downed count and revive ring, locked kilns and scrap, POI bars, the PvP stake labels
func paint_labels() -> void:
	if not visible:
		return
	actors.paint_labels()
	world.paint_labels()
