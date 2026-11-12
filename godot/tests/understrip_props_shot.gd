extends SceneTree
## THE UNDERSTRIP's props and tracers on screen: a neon shrine with its Keeper, a trader, the lift, a chest, loot of each
## kind with salvage and a burning flare, then the five Understrip tracers firing. In memory only, nothing is saved.
##   godot --path godot --rendering-driver opengl3 --resolution 1600x900 --script res://tests/understrip_props_shot.gd -- out_prefix

func _initialize():
	call_deferred("run")

func shot(path: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

func at(main, x: float, y: float, frames: int = 25, ctl: Dictionary = {}):
	var p = main.sim.player
	p.x = x
	p.y = y
	main.v.cam_snap(x, y)
	for i in frames:
		p.x = x
		p.y = y
		main.sim.update(.02, ctl)
		await process_frame

## walkable floor (not rock, a shut door, junk or a tank)
func walkable(s, x: float, y: float) -> bool:
	var i := int(x)
	var j := int(y)
	if i < 1 or j < 1 or i >= s.N - 1 or j >= s.N - 1: return false
	return not (s.terr[j * s.N + i] in [PalMaps.T_CONC, PalMaps.T_SHUT, PalMaps.T_JUNK, PalMaps.T_TANK])

## stand beside a prop, not in front of it (in front, toward the camera, the soldier hides it): the first free spot of
## a few to its left and right on screen, else just below it
func beside(main, x: float, y: float):
	var s = main.sim
	for o in [[-1.3, 1.3], [1.3, -1.3], [-1.0, 1.6], [1.6, -1.0], [-2.0, 2.0], [2.0, -2.0], [-1.0, 0.6], [0.6, -1.0]]:
		if walkable(s, x + o[0], y + o[1]):
			await at(main, x + o[0], y + o[1])
			main.v.cam_snap(x, y)
			for i in 3: await process_frame
			return
	await at(main, x + 1.0, y + 1.6)

## the longest open line from (x, y), of eight directions
func open_dir(s, x: float, y: float) -> Vector2:
	var best := Vector2(1, 0)
	var run := 0
	for k in 8:
		var d := Vector2.from_angle(k * PI / 4)
		var n := 0
		while n < 40 and walkable(s, x + d.x * (n + 1) * .5, y + d.y * (n + 1) * .5): n += 1
		if n > run:
			run = n
			best = d
	return best

func run():
	var pre: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://understrip_props"
	PalAccount.offline = true
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.locker.persist = false
	main.profile.persist = false
	for i in 5: await process_frame
	main.demo = false
	var tips_file := FileAccess.file_exists("user://us_tips.json")
	main.settings.data.tips = true   # in memory: the first-time tips show (settings are not saved here)
	main.us_tip_seen = {}
	main.menus.close()
	main.game_n += 1
	main.sim.new_game(1234, "normal", {}, {"mode": "understrip"})
	var s = main.sim
	var p = s.player
	p.hp = 1e6
	p.max = 1e6
	s.enemies = s.enemies.filter(func(e): return e.type == "boss")   # an empty level, so nothing hides the props
	var sh = s.lay.shrines[0]
	s.game.us.lit = 1
	s.game.us.rest.ix = 0
	await beside(main, sh.x, sh.y)
	await shot(pre + "_shrine.png")
	print("merchants: ", s.lay.merchants.map(func(m): return m.kind))
	for m in s.lay.merchants:
		if m.kind != "keeper":
			await beside(main, m.x, m.y)
			await shot(pre + "_trader.png")
			break
	await at(main, s.lay.exit[0] + 1.8, s.lay.exit[1] + 1.8)
	await shot(pre + "_lift.png")
	if s.lay.chests.size() > 0:
		var c = s.lay.chests[0]
		await beside(main, c.x, c.y)
		await shot(pre + "_chest.png")
	# loot of each kind, a sack of salvage and a lit flare round the start
	var o = s.lay.starts[0]
	var x0: float = o[0]
	var y0: float = o[1]
	var T = UsLoot.tables()
	s.us.drop_loot(x0 - 1.0, y0 + .4, {"kind": "weapon", "w": {"id": T.weapons.keys()[0], "r": "e", "mods": []}})
	s.us.drop_loot(x0, y0 + .9, {"kind": "perk", "k": T.perks.keys()[0]})
	s.us.drop_loot(x0 + 1.0, y0 + .4, {"kind": "relic", "k": T.relics.keys()[0]})
	s.us.drop_loot(x0 - .6, y0 - .8, {"kind": "consumable", "k": T.items.keys()[0]})
	s.game.us.drops.append({"id": str(p.id) + "x", "slot": 9, "x": x0 + .7, "y": y0 - .7, "sal": 20})
	s.game.us.flares.append({"x": x0 + 1.4, "y": y0 + 1.2, "t": 15.0})
	await at(main, x0 + .2, y0 + 2.2)
	await shot(pre + "_loot.png")
	await at(main, x0 - 1.0, y0 + .4, 6)   # on the gun: its name, line and TAKE
	await shot(pre + "_prompt.png")
	s.game.us.log.append([0, 12, 95, 3])   # the results card while the lift goes down (no level change: the sim isn't run)
	s.game.us.lift = 3.0
	for i in 3: await process_frame
	await shot(pre + "_card.png")
	s.game.us.lift = 0.0
	s.game.us.loot.clear()
	s.game.us.drops.clear()
	var d := open_dir(s, x0, y0)
	print("firing along ", d)
	for tr in ["chips", "neontube", "jackpotcoins", "tractorbeam", "saucerbolt"]:
		main.locker.eq.trail = tr   # in memory: the locker is not persisted here
		s.bullets.clear()
		p.x = x0
		p.y = y0
		p.aim = d
		main.v.cam_snap(x0 + d.x * 2.5, y0 + d.y * 2.5)
		for i in 14:
			p.x = x0
			p.y = y0
			p.aim = d
			if i % 4 == 0: s.shoot(p, Pal.SOLDIER.gun, 0.0)
			s.update_bullets(.02)
			s.game.time += .02
			await process_frame
		main.v.cam_snap(x0 + d.x * 2.5, y0 + d.y * 2.5)
		print(tr, ": ", s.bullets.size(), " rounds in the air")
		await shot(pre + "_tr_" + tr + ".png")
	main.queue_free()
	for i in 10: await process_frame
	if not tips_file and FileAccess.file_exists("user://us_tips.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://us_tips.json"))
	quit()
