extends RefCounted
## The model library's lobby layout recipe (art/3d/docs/godot/recipes/lobby_layout.gd): the captured Blender layouts
## in Godot, the camera's lens shift included.

static func blender_point(raw: Array) -> Vector3:
	return Vector3(float(raw[0]), float(raw[2]), -float(raw[1]))

static func configure_camera(camera: Camera3D, entry: Dictionary) -> Error:
	var rotation: Array = entry.rotation
	# All six current layouts have an X rotation only. Reject unknown rotations.
	if absf(rotation[1]) > 0.00001 or absf(rotation[2]) > 0.00001:
		return ERR_UNAVAILABLE
	var p: Array = entry.projection
	var near := float(p[14])/(float(p[10])-1.0)
	var far := float(p[14])/(float(p[10])+1.0)
	var height := 2.0*near/float(p[5])
	var offset := Vector2(float(p[8])*near/float(p[0]), float(p[9])*near/float(p[5]))
	camera.position = blender_point(entry.position)
	camera.basis = Basis(Vector3.RIGHT, -PI/2.0)*Basis(Vector3.RIGHT, float(rotation[0]))
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.set_frustum(height, offset, near, far)
	return OK

static func screen_anchor(camera: Camera3D, world_point: Vector3) -> Vector2:
	return camera.unproject_position(world_point)
