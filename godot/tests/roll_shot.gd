extends SceneTree
## The back roll on screen, mid-tumble: xvfb-run godot --path godot --rendering-driver opengl3 --script res://tests/roll_shot.gd -- out.png

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://roll.png"
	PalAccount.offline = true
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	for n in 5:
		await process_frame
	main.locker.persist = false
	main.profile.persist = false
	main.start_game()
	for n in 20:
		await process_frame
	main.sim.player.aim = Vector2(1, 0)
	main.do_action("roll")
	var end := Time.get_ticks_msec() + 220
	while Time.get_ticks_msec() < end:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("wrote ", out, " rolling=", main.sim.rolling(main.sim.player), " e=", main.sim.player.dgE)
	quit()
