extends SceneTree
## THE UNDERSTRIP on screen (G2): the PLAY page with the mode picked, region 1's first level, and the Pit Boss in both
## stages (his jacket, then without it). Settings and saves are changed in memory only, never saved.
##   godot --path godot --rendering-driver opengl3 --resolution 1600x900 --script res://tests/understrip_shot.gd -- out_prefix

func _initialize():
	call_deferred("run")

func shot(path: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

func run():
	var pre: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://understrip"
	PalAccount.offline = true
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.locker.persist = false
	main.profile.persist = false
	for i in 5: await process_frame
	var S = main.settings.data.setup
	var was = S.mode
	S.mode = "understrip"
	main.menus.show_main()
	for i in 15: await process_frame
	await shot(pre + "_play.png")
	S.mode = was
	# region 1, the first level
	main.demo = false
	main.menus.close()
	main.game_n += 1
	main.sim.new_game(1234, "normal", {}, {"mode": "understrip"})
	main.run_sp = 0
	main.draft_wave = 1
	var p = main.sim.player
	p.hp = 1e6
	p.max = 1e6
	main.v.cam_snap(p.x, p.y)
	for i in 40:
		main.sim.update(.02)
		await process_frame
	await shot(pre + "_level1.png")
	# the Pit Boss's arena
	main.sim.new_game(1234, "normal", {}, {"mode": "understrip", "us_level": 2})
	p = main.sim.player
	p.hp = 1e6
	p.max = 1e6
	var at = main.sim.lay.bossAt[0]
	p.x = at[0] + .5
	p.y = at[1] + 3.5
	main.v.cam_snap(p.x, p.y)
	for i in 30:
		main.sim.update(.02)
		await process_frame
	await shot(pre + "_boss1.png")
	var boss = main.sim.enemies.filter(func(e): return e.type == "boss")[0]
	for i in 400:   # until the gate has sealed and his intro is over
		if main.sim.game.us.gate == 2 and boss.hp < boss.max * .99: break
		main.sim.update(.02)
		if main.sim.game.us.gate == 2: main.sim.hurt_enemy(boss, boss.max * .51, p.id)
		await process_frame
	print("after the hit: gate %d, hp %.0f/%.0f, stage %d, in play %s" % [main.sim.game.us.gate, boss.hp, boss.max, main.sim.game.us.bossStage, main.sim.enemies.has(boss)])
	for i in 200:
		main.sim.update(.02)
		await process_frame
	print("stage 2 shot: hp %.0f, stage %d" % [boss.hp, main.sim.game.us.bossStage])
	await shot(pre + "_boss2.png")
	main.queue_free()
	for i in 10: await process_frame
	quit()
