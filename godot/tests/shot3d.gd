extends SceneTree
## The 3D view against the 2D drawing: renders a scene and saves <prefix>_3d.png and <prefix>_2d.png of the same
## moment (the 2D one with the 3D view switched off), plus the frame time of each.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 \
##     --script res://tests/shot3d.gd -- <prefix> <scene> [args]
## scenes: raid (every raider type on the Yard), boss <key>, river (flood and the Ferryman), quarry, frost, city,
## base (PvP Base Battle), casino, roll (a soldier mid back roll), tracers, killfx, blitz (a Final Blitz boss fight),
## push (a crowded Black Out final push). PAL_ONLY=3d or 2d renders just one; PAL_FRAMES=n measures n frames.

var main: Node2D
var s: Sim


func step(n: int, keep_alive: bool = true) -> void:
	for k in n:
		if keep_alive:
			for p in s.players.values():
				p.hp = p.max
		s.update(1.0 / 30.0, {})


func frames(n: int) -> void:
	for k in n:
		await process_frame


## mean and worst frame time over n rendered frames (the sim frozen so both renderers draw the same thing)
func measure(n: int) -> Array:
	var tot := 0.0
	var worst := 0.0
	await frames(3)
	for k in n:
		var t0 := Time.get_ticks_usec()
		await process_frame
		RenderingServer.force_draw(false)
		var dt := (Time.get_ticks_usec() - t0) / 1000.0
		tot += dt
		worst = maxf(worst, dt)
	return [tot / n, worst]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "user://shot3d"
	var scene: String = args[1] if args.size() > 1 else "raid"
	PalAccount.offline = true
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.settings.data.setup = PalSettings.new().data.setup
	main.settings.data.models3d = true
	main.setup_3d()
	main.start_game()
	s = main.sim
	var wear := OS.get_environment("PAL_COS")
	if wear != "":
		main.locker.persist = false
		main.locker.eq.skin = wear.get_slice(",", 0)
		main.locker.eq.hat = wear.get_slice(",", 1)
		if wear.get_slice_count(",") > 2:
			main.locker.eq.trail = wear.get_slice(",", 2)
		if wear.get_slice_count(",") > 3:
			main.locker.eq.fx = wear.get_slice(",", 3)
	await _scene(scene, args.slice(2))
	var only := OS.get_environment("PAL_ONLY")
	var nf := int(OS.get_environment("PAL_FRAMES")) if OS.get_environment("PAL_FRAMES") != "" else 30
	main._update_light(100.0)   # the time of day reached (it eases over seconds of real frames)
	var ct: Dictionary = main._cam_target()
	main.v.cam_snap(ct.x, ct.y, s.height_at(ct.x, ct.y))
	main._update_light(100.0)   # again: the light pools follow the camera
	if main.v3 != null:
		main.v3.frame(0.0)
	for l in [main, main.fx_layer, main.glow_layer, main.ui_layer]:
		l.queue_redraw()
	if OS.get_environment("PAL_DEBUG") != "":
		print("light ", main.light, " rect ", main.light_rect.size, " vis ", main.light_rect.visible, " shade ", main.light_rect.material.get_shader_parameter("shade"))
	main.set_process(false)   # hold the moment: both pictures show the same frame
	s.events.clear()
	if only != "2d":
		await frames(4)
		var t3: Array = await measure(nf)
		root.get_texture().get_image().save_png(prefix + "_3d.png")
		print("3d %s: %.2f ms/frame mean, %.2f worst (%d frames)" % [scene, t3[0], t3[1], nf])
	if only != "3d":
		main.settings.data.models3d = false
		main.setup_3d()
		main.ground_key = ""
		main.set_process(true)
		await process_frame   # the 2D ground repaints
		main.set_process(false)
		main.v.cam_snap(ct.x, ct.y, s.height_at(ct.x, ct.y))
		main._update_light(100.0)
		for l in [main, main.fx_layer, main.glow_layer, main.ui_layer]:
			l.queue_redraw()
		await frames(4)
		var t2: Array = await measure(nf)
		root.get_texture().get_image().save_png(prefix + "_2d.png")
		print("2d %s: %.2f ms/frame mean, %.2f worst" % [scene, t2[0], t2[1]])
	quit()


func _scene(scene: String, a: Array) -> void:
	match scene:
		"raid":
			s.player.mats = [40, 8, 8]
			for j in [10, 11, 12]:
				s.player.bcd = 0.0
				s.do_build(s.player, 6, j, 0, j == 12)
			s.player.bcd = 0.0
			s.do_build(s.player, 6, 9, 1, false)
			s.player.bcd = 0.0
			s.do_build(s.player, 9, 13, 2, false)
			step(30 * 20)
			s.game.wave = 4
			s.start_raid()
			s.game.queue = []
			var types := ["rifle", "gren", "fire", "breach", "shield", "medic", "spotter"]
			for n in types.size():
				var e := s.spawn_enemy_at(types[n], 9.5 + (n % 4) * 1.2, 7.0 + (n / 4) * 1.6)
			s.player.x = 7.5
			s.player.y = 10.5
			step(30 * 2)
			s.walls[s.idx(6, 11)].hp *= 0.5
			s.walls[s.idx(6, 10)].fire = 3.0
		"boss":
			var key: String = a[0] if a.size() > 0 else "butcher"
			if key in ["ferryman", "whiteferryman", "harbinger"]:
				main.next_opt.map = "river"
				main._restart()
				s = main.sim
			step(30 * 5)
			s.game.wave = 4
			s.start_raid()
			s.game.queue = []
			var b := s.spawn_boss(key)
			if not b.get("raft", false):
				b.x = s.player.x + 3.0
				b.y = s.player.y - 1.5
			b.cd = 0.0
			b.ab = 0.0
			var want := int(a[1]) if a.size() > 1 else -1
			for n in 30 * 12:
				step(1)
				if (want < 0 and b.st != 0 and b.st != 2 and not b.get("burrow", false)) or (want >= 0 and b.st == want):
					break
			step(int(a[2]) if a.size() > 2 else 4)
		"river", "quarry", "frost":
			main.next_opt.map = scene
			main._restart()
			s = main.sim
			step(30 * 10)
			s.game.wave = 3 if scene == "river" else 2
			s.start_raid()
			if scene == "river":
				s.spawn_boss("ferryman")
			if scene == "quarry":
				for k in 6:
					var kk: int = s.idx(4 + k, 5 + (k % 2))
					if s.terr[kk] == PalMaps.T_GROUND:
						s.make_pit(kk)
			step(30 * 10)
			if scene == "river":
				s.flood_on = true
				main.v3.world.flood_lv = 1.0 if main.v3 != null else 0.0
		"city", "push":
			main.next_opt.mode = "blackout"
			main._restart()
			s = main.sim
			s.qm.alive = false
			s.qm.gone = true
			step(30 * 46)
			var ci: int = s.game.bo.cur.ci
			var c: Dictionary = s.cores[ci]
			for n in 30 * (14 if scene == "city" else 6):
				s.player.x = c.i + 0.5 + 3.5
				s.player.y = c.j + 3.5
				step(1)
			if scene == "push":   # a crowded final push: bosses and squads round the stake
				s.game.bo.stage = "push"
				for k in ["bluebutcher", "arsonist", "tempest", "bulldozer"]:
					var b := s.spawn_boss(k)
					b.x = s.player.x + randf_range(-4, 4)
					b.y = s.player.y + randf_range(-4, 2)
				for n in 40:
					var e := s.spawn_enemy_at(["rifle", "gren", "fire", "breach", "shield", "medic", "spotter"][n % 7], s.player.x + randf_range(-7, 7), s.player.y + randf_range(-7, 3))
				step(30 * 3)
		"base":   # a Base Battle: two stakes, WEST against EAST
			main.next_opt.pvp = "base"
			main._restart()
			s = main.sim
			var foe := s.make_player("g1", "grenadier", 1, "b")
			foe.name = "EAST"
			s.players["g1"] = foe
			step(30 * 4)
			s.start_battle()
			step(30 * 2)
			var east: Dictionary = s.cores[1] if s.cores.size() > 1 else s.core
			foe.x = s.player.x + 3.5
			foe.y = s.player.y - 0.5
			s.player.aim = Vector2(1, -0.1).normalized()
			step(10)
		"casino":
			main.start_casino()
			s = main.sim
			step(30 * 3)
		"roll":
			step(30 * 3)
			s.player.dgE = float(a[0]) if a.size() > 0 else 0.22
			s.player.dgX = -s.player.aim.x
			s.player.dgY = -s.player.aim.y
		"tracers", "killfx":
			step(30 * 3)
			s.game.wave = 2
			s.start_raid()
			s.game.queue = []
			for n in 6:
				s.spawn_enemy_at("rifle", s.player.x + 4 + n * 0.6, s.player.y - 2 + n * 0.7)
			step(30 * 1)
		"blitz":
			main.next_opt.mode = "blitz"
			main._restart()
			s = main.sim
			step(30 * 5)
			s.game.wave = 15
			s.start_raid()
			s.game.queue = []
			for k in ["bluebutcher", "arsonist", "tempest", "bulldozer"]:
				var b := s.spawn_boss(k)
				b.x = s.player.x + randf_range(-5, 5)
				b.y = s.player.y + randf_range(-5, 3)
			for n in 14:
				s.spawn_enemy_at(["rifle", "gren", "fire", "shield"][n % 4], s.player.x + randf_range(-6, 6), s.player.y + randf_range(-6, 3))
			step(30 * 3)
	await frames(2)
