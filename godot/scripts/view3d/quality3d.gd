class_name Quality3D
extends RefCounted
## The 3D view's quality knobs, in one place, for the settings pass to expose. Every one is read live each frame
## (except the viewport ones, applied by apply_viewport). PalSettings.data["gfx3d"] can hold any of these keys; main
## calls load_from() after the settings load and whenever they change.

## shadows: 0 off, 1 low (1024 map), 2 high (2048 map, soft edges)
static var shadows := 2
## effects density 0.25..1: particles kept, tracer ribbons drawn, kill-effect pieces (1 = everything the 2D shows)
static var effects := 1.0
## how far past the screen's edges (in tiles) actors, props and effects are still updated and drawn
static var draw_margin := 3.0
## animation updates a second for actors near the player (far ones and anything off screen get anim_far)
static var anim_rate := 60.0
static var anim_far := 20.0
## tiles from the camera centre where anim_far takes over
static var anim_near := 14.0
## multisampling for the 3D view: 0 off, 2, 4
static var msaa := 2
## at most this many live kill effects and tracer trails (blueprint 21: 4-8 kill effects, 24-48 tracers)
static var max_kill_fx := 8
static var max_tracers := 48
## the 3D view's resolution as a share of the window (bilinear upscale): 0.5..1
static var render_scale := 1.0

const KEYS := ["shadows", "effects", "draw_margin", "anim_rate", "anim_far", "anim_near", "msaa", "max_kill_fx", "max_tracers", "render_scale"]


static func load_from(d) -> void:
	if not d is Dictionary:
		return
	if d.has("shadows"):
		shadows = clampi(int(d.shadows), 0, 2)
	if d.has("effects"):
		effects = clampf(float(d.effects), 0.25, 1.0)
	if d.has("draw_margin"):
		draw_margin = clampf(float(d.draw_margin), 0.0, 12.0)
	if d.has("anim_rate"):
		anim_rate = clampf(float(d.anim_rate), 10.0, 120.0)
	if d.has("anim_far"):
		anim_far = clampf(float(d.anim_far), 5.0, 60.0)
	if d.has("anim_near"):
		anim_near = clampf(float(d.anim_near), 4.0, 64.0)
	if d.has("msaa"):
		msaa = int(d.msaa) if int(d.msaa) in [0, 2, 4] else 2
	if d.has("max_kill_fx"):
		max_kill_fx = clampi(int(d.max_kill_fx), 1, 24)
	if d.has("max_tracers"):
		max_tracers = clampi(int(d.max_tracers), 8, 160)
	if d.has("render_scale"):
		render_scale = clampf(float(d.render_scale), 0.5, 1.0)


static func to_dict() -> Dictionary:
	return {"shadows": shadows, "effects": effects, "draw_margin": draw_margin, "anim_rate": anim_rate, "anim_far": anim_far,
		"anim_near": anim_near, "msaa": msaa, "max_kill_fx": max_kill_fx, "max_tracers": max_tracers, "render_scale": render_scale}


## the presets a settings page can offer
static func preset(name: String) -> Dictionary:
	match name:
		"low":
			return {"shadows": 0, "effects": 0.4, "draw_margin": 1.0, "anim_rate": 30.0, "anim_far": 12.0, "msaa": 0, "max_kill_fx": 4, "max_tracers": 24, "render_scale": 0.75}
		"medium":
			return {"shadows": 1, "effects": 0.7, "draw_margin": 2.0, "anim_rate": 45.0, "anim_far": 15.0, "msaa": 2, "max_kill_fx": 6, "max_tracers": 36, "render_scale": 1.0}
	return {"shadows": 2, "effects": 1.0, "draw_margin": 3.0, "anim_rate": 60.0, "anim_far": 20.0, "msaa": 2, "max_kill_fx": 8, "max_tracers": 48, "render_scale": 1.0}


static func apply_viewport(vp: Viewport) -> void:
	if vp == null:
		return
	vp.msaa_3d = Viewport.MSAA_DISABLED if msaa == 0 else (Viewport.MSAA_2X if msaa == 2 else Viewport.MSAA_4X)
	vp.scaling_3d_scale = render_scale
	RenderingServer.directional_shadow_atlas_set_size(1024 if shadows <= 1 else 2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW if shadows >= 2 else RenderingServer.SHADOW_QUALITY_HARD)
