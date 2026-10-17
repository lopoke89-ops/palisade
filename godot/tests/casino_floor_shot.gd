extends SceneTree
## The casino floor on screen: xvfb-run godot --path godot --rendering-driver opengl3 --script res://tests/casino_floor_shot.gd -- out_prefix


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("wrote ", path)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var pre: String = a[0] if a.size() > 0 else "user://cas"
	PalAccount.offline = true
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	for n in 5:
		await process_frame
	main.locker.persist = false
	main.profile.persist = false
	main.start_casino()
	var p: Dictionary = main.sim.player
	p.x = 6.0
	p.y = 7.0
	for n in 90:
		await process_frame
	await _shot(pre + "_floor.png")
	p.x = 3.6
	p.y = 5.5
	for n in 30:
		await process_frame
	await _shot(pre + "_seat.png")
	main.cas_sit()
	for n in 20:
		await process_frame
	print("seat ", p.get("seat", 0), " sheet ", main.casino_ui != null and main.casino_ui.is_open())
	await _shot(pre + "_sat.png")
	quit()
