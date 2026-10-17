extends SceneTree
## Cosmetics in play: tracers in flight and kill effects going off round the soldier (the sim held still).
##   xvfb-run godot --path godot --rendering-driver opengl3 --script res://tests/cos_shot.gd -- out.png [trail fx...]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://cos.png"
	PalAccount.offline = true   # tests never make or touch real accounts
	var main: Node2D = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.settings.data.setup = PalSettings.new().data.setup
	main.locker.persist = false
	main.locker.eq.skin = "gsoldier"
	main.locker.eq.trail = args[1] if args.size() > 1 else "rainbow"
	main.start_game()
	var s: Sim = main.sim
	for n in 10:
		await process_frame
	s.game.paused = true
	var p: Dictionary = s.player
	var trails := ["rainbow", "plasma", "hellchain", "sigil", "f_pride", "glitch", "solsticecomet", "bluearc"]
	for i in trails.size():
		var a := -0.9 + i * 0.25
		s.bullets.append({"id": 9000 + i, "x": p.x + cos(a) * (2.0 + i * 0.3), "y": p.y + sin(a) * (2.0 + i * 0.3), "vx": cos(a) * 30, "vy": sin(a) * 30, "team": 0,
			"tr": trails[i], "tc": i, "heavy": false, "z0": 1.0, "zSlope": 0.0, "dist": 1.0})
	var fx := ["supernova", "bubbles", "hellportal", "souls", "bats", "nuke", "winterbloom", "sixty"]
	for i in fx.size():
		var a := 2.0 + i * 0.5
		main.kill_fx(p.x + cos(a) * 3.2, p.y + sin(a) * 3.2, fx[i])
	for n in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("cparts ", main.cparts.size())
	quit()
