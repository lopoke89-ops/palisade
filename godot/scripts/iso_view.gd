class_name IsoView
extends RefCounted
## The browser's isometric projection (dev/src/js/02-view.js), flat ground only for now (the Yard has no height).

var W := 1280.0
var H := 720.0
var ZOOM := 1.0
var S := 1.0
var TW2 := 32.0
var TH2 := 16.0
var WH := 27.2
var u := 1.0
var cam_x := 0.0
var cam_y := 0.0
var cam_sx := 0.0   # smoothed camera, before snapping
var cam_sy := 0.0


func resize(w: float, h: float) -> void:
	W = w
	H = h
	S = round(clampf(minf(W, H * 1.15) / 560.0, 0.72, 1.35) * ZOOM * 20.0) / 20.0
	TW2 = 40.0 * S
	TH2 = TW2 / 2.0
	WH = TH2 * 1.7
	u = TW2 / 32.0


func iso(x: float, y: float) -> Vector2:
	return Vector2((x - y) * TW2 + cam_x, (x + y) * TH2 + cam_y)


## Screen point back to the ground plane (z = 0).
func screen_to_world(sx: float, sy: float) -> Vector2:
	var a := (sx - cam_x) / TW2
	var b := (sy - cam_y) / TH2
	return Vector2((a + b) / 2.0, (b - a) / 2.0)


## A screen-space stick or WASD direction turned into a world direction (sdirToWorld).
func sdir_to_world(sx: float, sy: float) -> Vector2:
	var a := sx / TW2
	var b := sy / TH2
	var v := Vector2((a + b) / 2.0, (b - a) / 2.0)
	var l := v.length()
	return v / l if l > 0.0 else Vector2.ZERO


func world_dir_to_screen(d: Vector2) -> Vector2:
	var v := Vector2((d.x - d.y) * TW2, (d.x + d.y) * TH2)
	var l := v.length()
	return v / l if l > 0.0 else Vector2(1, 0)


func cam_target(fx: float, fy: float) -> Vector2:
	var cx := 0.4 if W < 760.0 else 0.5
	return Vector2(W * cx - (fx - fy) * TW2, H * 0.52 - (fx + fy) * TH2)


func cam_snap(fx: float, fy: float) -> void:
	var t := cam_target(fx, fy)
	cam_sx = t.x
	cam_sy = t.y
	cam_x = cam_sx
	cam_y = cam_sy


## The browser eases 14% of the way each rendered frame (render() in 17-scenery.js).
func cam_follow(fx: float, fy: float, shake: Vector2) -> void:
	var t := cam_target(fx, fy)
	cam_sx += (t.x - cam_sx) * 0.14
	cam_sy += (t.y - cam_sy) * 0.14
	cam_x = round(cam_sx + shake.x)
	cam_y = round(cam_sy + shake.y)
