extends SceneTree
## The 3D lobby on screen: the main menu (solo), a full room of six, the Locker, and a phone held upright.
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1600x900 --script res://tests/lobby3d_shot.gd -- out_prefix
## Prints OK/FAIL lines: the stage is up, every slot of a six-player room has a dressed character, hats and weapons fit.

var fails := 0


func check(cond: bool, what: String) -> void:
	print(("OK " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _shot(path: String) -> void:
	for n in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("wrote ", path)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pre: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://lobby3d"
	PalAccount.offline = true
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	for n in 5:
		await process_frame
	main.locker.persist = false
	main.profile.persist = false
	main.locker.cloud = {}
	main.settings.data.name = "Hana"
	main.locker.eq.skin = "std"
	main.locker.eq.hat = "jackolantern"
	main.locker.eq.bg = "campfire"
	main.menus.show_main()
	var st: Lobby3D = main.menus.stage
	check(st != null and st.is_inside_tree(), "the 3D stage is behind the main menu")
	await _shot(pre + "_main.png")
	check(st.slots.size() >= 1 and st.slots[0].model != null and st.slots[0].model.get_meta("char_id") == "player:soldier", "this player stands on it, as the soldier")
	# a full room: six players, every class, skins and hats, two of them ready
	var crew := [
		{"name": "Hana", "cls": "soldier", "cos": {"skin": "std", "hat": "jackolantern"}, "ready": true, "slot": 0},
		{"name": "Gus", "cls": "sniper", "cos": {"skin": "sahur", "hat": "headband"}, "ready": true, "slot": 1},
		{"name": "Ivy", "cls": "grenadier", "cos": {"skin": "desert", "hat": "crown"}, "ready": false, "slot": 2},
		{"name": "Rook", "cls": "quartermaster", "cos": {"skin": "arctic", "hat": "class"}, "ready": false, "slot": 3},
		{"name": "Moe", "cls": "sniper", "cos": {"skin": "std", "hat": "beret"}, "ready": false, "slot": 4},
		{"name": "Zed", "cls": "grenadier", "cos": {"skin": "sheetghost", "hat": "dunce"}, "ready": false, "slot": 5}]
	st.set_crew("party", crew)
	await _shot(pre + "_party.png")
	var built := 0
	var guns := 0
	for i in 6:
		var M = st.slots[i].model
		if M != null:
			built += 1
			var g := ArtLibrary.named(M, "ClassWeapon")
			if g != null or ArtLibrary.CLASS_WEAPON[crew[i].cls] == st.lib.attach.get(M.get_meta("char_id"), {}).get("default_weapon", ""):
				guns += 1
	check(built == 6, "six dressed characters (%d)" % built)
	check(guns == 6, "each holds its class's weapon (%d)" % guns)
	check(ArtLibrary.named(st.slots[1].model, "ClassWeapon") != null, "the sniper in the Sahur skin swapped its carbine for the bolt rifle")
	check(ArtLibrary.named(st.slots[0].model, "EquippedCosmetic") != null, "the pumpkin head is on")
	check(st.slots[1].label.visible and st.slots[1].label.text.begins_with("GUS") and not st.slots[0].label.visible, "names over the rest of the crew (this player has the plate over the stage)")
	# the Locker
	main.menus.show_locker()
	for n in 3:
		await process_frame
	await _shot(pre + "_locker.png")
	# a phone held upright: the portrait layouts
	root.get_window().size = Vector2i(540, 960)
	main.menus.show_main()
	st.set_crew("party", crew)
	await _shot(pre + "_tall.png")
	check(st._tall, "the portrait layout on a tall screen")
	print("RESULT " + ("PASS" if fails == 0 else "FAIL %d" % fails))
	quit(1 if fails else 0)
