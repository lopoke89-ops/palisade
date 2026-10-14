extends SceneTree
## The client around the sim: settings, key and controller bindings, the menu flow, touch sticks.
##   godot --headless --path godot --script res://tests/client_test.gd     (exit 0 = pass)

var fails := 0


func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _init() -> void:
	var keep := FileAccess.get_file_as_string(PalSettings.PATH) if FileAccess.file_exists(PalSettings.PATH) else ""   # put the player's settings back after
	print("settings")
	var st := PalSettings.new()
	check(st.data.keys.build == [KEY_SPACE] and st.data.pad.fire == 7 and st.data.pad.build == 0, "browser defaults: SPACE builds; RT fires, A builds")
	st.apply_keys()
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	check(InputMap.has_action("pal_build") and ev.is_action_pressed("pal_build"), "keys go into the InputMap as pal_ actions")
	check(PalSettings.glyph(7, "ps") == "R2" and PalSettings.glyph(0, "xbox") == "A", "button names follow the controller in hand")
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
	main.to_menu()
	check(main.demo and main.menus.screen == "main", "MAIN MENU goes back to the demo yard")
	if keep != "":
		var f := FileAccess.open(PalSettings.PATH, FileAccess.WRITE)
		f.store_string(keep)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PalSettings.PATH))
	print("\nALL PASSED" if fails == 0 else "\nFAILED %d" % fails)
	quit(1 if fails else 0)
