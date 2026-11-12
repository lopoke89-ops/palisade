extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var output=ProjectSettings.globalize_path("res://art/understrip/weapons")
	DirAccess.make_dir_recursive_absolute(output)
	var viewport=SubViewport.new()
	viewport.size=Vector2i(384,256)
	viewport.own_world_3d=true
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(0,0,0,0)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("#c7d8e8")
	env.environment.ambient_light_energy=.65
	viewport.add_child(env)
	var light=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-40,-25,0)
	light.light_energy=1.6
	viewport.add_child(light)
	var camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=1.05
	camera.position=Vector3(1.2,.65,1.15)
	viewport.add_child(camera)
	camera.look_at(Vector3(0,0,.15))
	for id in UsWeapons.IDS:
		var gun=UsWeapons.build(id)
		viewport.add_child(gun)
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		var image=viewport.get_texture().get_image()
		var err=image.save_png(output.path_join(id+".png"))
		print("render ",id," ",error_string(err))
		viewport.remove_child(gun)
		gun.free()
	viewport.queue_free()
	for i in 3: await process_frame
	quit()
