extends SceneTree
## Renders a few seconds of play and saves a PNG: xvfb-run godot --path godot --script res://tests/shot.gd -- out.png

func _init() -> void:
	var out := "user://shot.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var mode: String = args[1] if args.size() > 1 else "raid"
	var main: Node2D = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var s: Sim = main.sim
	# a short wall line east of the stake, one brick, and a door
	s.player.mats = [40, 8, 0]
	for j in [10, 11, 12]:
		s.player.bcd = 0.0
		s.do_build(s.player, 6, j, 0, j == 12)
	s.player.bcd = 0.0
	s.do_build(s.player, 6, 9, 1, false)
	# let Delgado work through the build phase, then send raid 4 (every raider type but the spotter)
	for n in 30 * 25:
		s.update(1.0 / 30.0, {})
	s.events.clear()
	if mode == "zoo":
		s.game.wave = 4
		s.start_raid()
		s.game.queue = []
		var spots := [[11.5, 8.5, "destroyer"], [9.5, 13.5, "tempest"], [12.5, 12.5, "arsonist"], [8.5, 5.5, "foreman"]]
		for sp in spots:
			var b := s.spawn_boss(sp[2])
			b.x = sp[0]
			b.y = sp[1]
		s.player.x = 6.5
		s.player.y = 10.5
		for n in 30 * 5:
			s.player.hp = s.player.max
			s.update(1.0 / 30.0, {})
	elif mode == "skills":
		main.profile.persist = false
		main.profile.sp = 6
		main.profile.sp_total = 12
		main.profile.skills = {"dmg": 2, "hp": 1, "ammo_shock": 1}
		s.game.paused = true
		main.skills_open = true
	elif mode == "armory":
		s.player.sal = 140
		s.player.x = 5.5
		s.player.y = 12.5
		main._try_armory()
	elif mode == "boss":
		s.game.wave = 4
		s.start_raid()
		s.game.queue = []
		var b := s.spawn_boss("butcher")
		b.x = 9.5
		b.y = 12.5
		b.ab = 0.0
		s.player.x = 6.5
		s.player.y = 13.5
		s.qm.alive = false
		for n in 30 * 6:
			s.update(1.0 / 30.0, {})
			if b.st == 2:
				break
	else:
		s.game.wave = 3
		s.start_raid()
		for n in 30 * 9:
			s.update(1.0 / 30.0, {})
	for n in (1 if mode in ["boss", "zoo"] else 30):
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out)
	var playing := 0
	for pl in main.audio.players:
		if pl.playing:
			playing += 1
	print("audio: ", main.audio.streams.size(), " effects loaded, ", playing, " playing; music ", main.audio.mus_token, " ", main.audio.mus_cur != null and main.audio.mus_cur.playing)
	print("saved ", out, " ", img.get_size(), " raiders ", s.enemies.size(), " stake ", s.core.hp)
	quit()
