extends SceneTree
## The client around the sim: settings, key and controller bindings, the menu flow, touch sticks.
##   godot --headless --path godot --script res://tests/client_test.gd     (exit 0 = pass)

var fails := 0


func _find(n: Node, cls: String) -> Node:
	for ch in n.get_children():
		if ch.get_class() == cls:
			return ch
		var r := _find(ch, cls)
		if r != null:
			return r
	return null


func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _init() -> void:
	var keep := FileAccess.get_file_as_string(PalSettings.PATH) if FileAccess.file_exists(PalSettings.PATH) else ""   # put the player's settings back after
	var keep_l := FileAccess.get_file_as_string(PalLocker.PATH) if FileAccess.file_exists(PalLocker.PATH) else ""
	var keep_p := FileAccess.get_file_as_string(PalProfile.PATH) if FileAccess.file_exists(PalProfile.PATH) else ""
	print("settings")
	var st := PalSettings.new()
	check(st.data.keys.build == [KEY_SPACE] and st.data.pad.fire == 7 and st.data.pad.build == 0, "browser defaults: SPACE builds; RT fires, A builds")
	st.apply_keys()
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	check(InputMap.has_action("pal_build") and ev.is_action_pressed("pal_build"), "keys go into the InputMap as pal_ actions")
	check(PalSettings.glyph(7, "ps") == "R2" and PalSettings.glyph(0, "xbox") == "A", "button names follow the controller in hand")
	print("locker: the browser's run payouts (tests/locker_ref.json, from tools/locker_ref.js)")
	var ref: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/locker_ref.json"))
	for r in ref:
		var prof := PalProfile.new()
		prof.persist = false
		var L := PalLocker.new(prof)
		L.persist = false
		L.fixed_r = 0.99
		L.cases = 0
		var c: Dictionary = r.claim
		var R := L.local_run(c, int(r.shards))
		var o: Dictionary = r.out
		var st_ok := true
		for k in o.st:
			if int(L.st.get(k, 0)) != int(o.st[k]):
				st_ok = false
				print("    st ", k, " godot ", L.st.get(k, 0), " browser ", o.st[k])
		var bag_ok := true
		for k in o.bag:
			if int(L.bag.get(k, 0)) != int(o.bag[k]):
				bag_ok = false
				print("    bag ", k, " godot ", L.bag.get(k, 0), " browser ", o.bag[k])
		var unl: Array = R.unlocked.duplicate()
		unl.sort()
		var unl2: Array = o.unlocked.duplicate()
		unl2.sort()
		var same: bool = L.cases == int(o.cases) and L.shards == int(o.shards) and L.prog == int(o.prog) and prof.sp == int(o.sp) and st_ok and bag_ok and unl == unl2 and R.text == o.text
		if not same:
			print("    godot:   ", L.cases, " ", L.shards, " ", L.prog, " ", prof.sp, " ", R.text)
			print("    browser: ", o.cases, " ", o.shards, " ", o.prog, " ", o.sp, " ", o.text)
		check(same, "%s: cases, shards, milestones, skill points and unlocks match" % r.name)
	print("controller")
	var dz: Array = PalInput.deadzone(Vector2(0.1, 0), 0.2)
	var full: Array = PalInput.deadzone(Vector2(1, 0), 0.2)
	check(dz[1] == 0.0 and is_equal_approx(full[1], 1.0), "stick deadzone: the middle is ignored, the rest stretched to 0..1")
	var main: Node2D = load("res://main.tscn").instantiate()
	root.add_child(main)
	for n in 5:
		await process_frame
	print("menus")
	check(main.demo and main.menus.screen == "main", "it opens on the main menu over the demo yard")
	check(main._controls().is_empty(), "nobody plays the demo")
	main.settings.data.setup = {"mode": "blitz", "map": "river", "size": "std", "diff": "hard", "cls": "sniper", "mods": ["elite", "bossrush"]}
	main.start_game()
	check(not main.demo and main.sim.game.mode == "blitz" and main.sim.map_id == "river" and main.sim.player.cls == "sniper" and main.sim.mods == ["elite"], "PLAY starts Match Setup's game (Blitz drops modifiers it doesn't allow)")
	main.do_action("pause")
	check(main.sim.game.paused and main.menus.screen == "pause", "pause opens the pause menu")
	main.do_action("pause")
	check(not main.sim.game.paused and not main.menus.active(), "and closes it")
	print("cosmetics in play")
	main.locker.eq.trail = "f_pride"
	main.locker.eq.fx = "supernova"
	main._dress(main.sim.player)
	var sp: Dictionary = main.sim.player
	check(sp.trail == "f_pride" and sp.tsnd == "ts_grainbow" and sp.tcyc == 6 and sp.kfx == "supernova", "the soldier wears the locker's tracer and kill effect")
	var nb: int = main.sim.bullets.size()
	main.sim.shoot(sp, sp.gun, 0.0)
	main.sim.shoot(sp, sp.gun, 0.0)
	check(main.sim.bullets.size() > nb and main.sim.bullets[-1].tr == "f_pride" and main.sim.bullets[-1].tc == 1, "rounds carry the tracer, a flag tracer one colour per round")
	main.cparts.clear()
	main.kill_fx(sp.x + 2, sp.y, "supernova")
	check(main.cparts.any(func(q): return q.kind == "finish:supernova") and main.cparts.size() > 10, "a kill paints its finisher and throws its particles")
	main.sim.bullets.resize(nb)
	main.locker.eq.trail = "std"
	main.locker.eq.fx = "none"
	main.do_action("mat2")
	check(main.sim.game.sel == 1, "actions reach the game: brick picked")
	main.menus.came_from = "main"
	main.menus.show_controls()
	main.menus.binding = "k:build"
	var k := InputEventKey.new()
	k.keycode = KEY_B
	k.pressed = true
	main.menus.bind_key(k)
	var k2 := InputEventKey.new()
	k2.keycode = KEY_B
	k2.pressed = true
	check(main.settings.data.keys.build == [KEY_B] and k2.is_action_pressed("pal_build"), "rebinding a key: BUILD on B")
	main.menus.binding = "k:nade"
	main.menus.bind_key(k)
	check(main.settings.data.keys.nade == [KEY_B] and main.settings.data.keys.build.is_empty(), "a key does one thing: GRENADE takes B from BUILD")
	main.settings.reset_keys()
	main.settings.apply_keys()
	main.menus.close()
	print("touch")
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = Vector2(main.v.W * 0.1, 500)
	t.pressed = true
	main.inp.handle(t)
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = Vector2(main.v.W * 0.1 + 56, 500)
	main.inp.handle(d)
	check(main.inp.mode == "touch" and is_equal_approx(main.inp.stick_move.v.x, 1.0), "the left thumb is a move stick")
	var c: Dictionary = main._controls()
	check(c.move.length() > 0.9, "and it walks the soldier (%.2f)" % c.move.length())
	main.sim.game.phase = "over"
	await create_timer(1.3).timeout
	check(main.menus.screen == "results", "the after-action screen comes up at the end")
	check(not main.last_reward.is_empty() and main.last_reward.text.ends_with("."), "and the run is paid into the locker (%s)" % main.last_reward.get("text", ""))
	check(_find(main.menus.root, "HFlowContainer") != null, "the rewards come as cards")
	main.to_menu()
	check(main.demo and main.menus.screen == "main", "MAIN MENU goes back to the demo yard")
	check(main.menus.root.get_child(0) is LockerUI.BgView, "outside a game the menus sit on the lobby background")
	print("locker screen")
	var L: PalLocker = main.locker
	L.cases = 2
	L.bag = {"halloween": 0}
	L.shards = 30
	main.profile.sp = 5
	main.menus.show_locker()
	await process_frame
	var ui: LockerUI = main.menus.root.get_children().filter(func(n): return n is LockerUI)[0]
	check(main.menus.screen == "locker" and ui.tiles.size() > 0, "the Locker opens on its tiles (%d)" % ui.tiles.size())
	var before := L.owned.size() + L.shards
	ui.open_cases("supply", 1)
	check(L.cases == 1 and L.owned.size() + L.shards > before, "OPEN takes a case and pays out before the show")
	var ov: CaseOpen = ui.get_children().filter(func(n): return n is CaseOpen)[0]
	ov.reveal()
	check(ov.phase == "reveal" and ov.done_b.visible, "SKIP goes straight to what it gave")
	ov.close()
	await process_frame
	ui = main.menus.root.get_children().filter(func(n): return n is LockerUI)[0]
	var halloween := L.case_count("halloween")
	ui._render_boxes()
	check(L.buy_case("halloween") and L.case_count("halloween") == halloween + 1 and L.shards == 18, "BUY trades 12 shards for a Halloween Case")
	ui._buy_sp()
	check(main.profile.sp == 5 and L.cases == 1, "the skill-point buy needs a second press")
	ui._buy_sp()
	check(main.profile.sp == 2 and L.cases == 2, "and then trades 3 skill points for a Supply Case")
	L.grant("bg:aurora")
	ui._equip(PalLocker.item("bg:aurora"))
	await process_frame
	check(L.eq.bg == "aurora" and main.menus.root.get_children().any(func(n): return n is LockerUI.BgView and n.id == "aurora"), "equipping a background puts it behind the menus")
	ui._equip(PalLocker.item("hat:witch"))
	check(L.eq.hat != "witch" and ui.msg.text != "", "locked items say how to get them")
	main.menus.show_main()
	if keep != "":
		var f := FileAccess.open(PalSettings.PATH, FileAccess.WRITE)
		f.store_string(keep)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PalSettings.PATH))
	for kp in [[PalLocker.PATH, keep_l], [PalProfile.PATH, keep_p]]:
		if kp[1] != "":
			var f2 := FileAccess.open(kp[0], FileAccess.WRITE)
			f2.store_string(kp[1])
		elif FileAccess.file_exists(kp[0]):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(kp[0]))
	print("\nALL PASSED" if fails == 0 else "\nFAILED %d" % fails)
	quit(1 if fails else 0)
