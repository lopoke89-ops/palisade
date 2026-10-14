extends SceneTree
## Renders a few seconds of play and saves a PNG: xvfb-run godot --path godot --script res://tests/shot.gd -- out.png

func _init() -> void:
	var out := "user://shot.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
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
	s.game.wave = 3
	s.start_raid()
	for n in 30 * 9:
		s.update(1.0 / 30.0, {})
	for n in 30:
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
