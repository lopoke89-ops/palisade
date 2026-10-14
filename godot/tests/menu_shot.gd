extends SceneTree
## Renders the menus: xvfb-run godot --path godot --script res://tests/menu_shot.gd -- out_prefix
func _init() -> void:
	var pre: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://menu"
	var main: Node2D = load("res://main.tscn").instantiate()
	root.add_child(main)
	for n in 40:
		await process_frame
	await _save(pre + "_main.png")
	main.menus.show_setup()
	for n in 6:
		await process_frame
	await _save(pre + "_setup.png")
	main.menus.came_from = "main"
	main.menus.show_controls()
	for n in 6:
		await process_frame
	await _save(pre + "_controls.png")
	main.start_game()
	for n in 30:
		await process_frame
	main.sim.game.phase = "over"
	main.sim.game.won = false
	for n in 70:
		await process_frame
	await _save(pre + "_results.png")
	quit()


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
