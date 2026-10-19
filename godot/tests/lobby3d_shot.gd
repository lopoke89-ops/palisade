extends SceneTree
## The 3D crew on screen: the main menu (solo), a full room of six, the Locker, and a smaller window.
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1600x900 --script res://tests/lobby3d_shot.gd -- out_prefix
## Prints OK/FAIL lines: the stage is up over the painted background, every slot of a six-player room has a dressed
## character, hats and weapons fit, and everyone stands on the browser's spots inside the page's hero box.

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
	main.settings.data.setup.cls = "soldier"   # whatever the machine's own settings say
	main.menus.show_main()
	var st: Lobby3D = main.menus.stage
	check(st != null and st.is_inside_tree() and main.menus.root.get_child(0) is LockerUI.BgView, "the 3D crew stands over the painted background, behind the main menu")
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
	main.menus.show_online("")
	for n in 3:
		await process_frame
	st.set_crew("party", crew, main.menus._stage_hero.get_global_rect())
	main.menus._hero2d.set_people(crew, "party", false)   # the page draws the same room's "+" and name plates
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
	_on_spots(st, main.menus._stage_hero.get_global_rect(), 6)
	# animated skins: their motion on the body (not the face), their aura and ground glow painted around the model
	var ov := func(skin: String, slot: String) -> bool:
		var M := st.lib.build("soldier", {"skin": skin, "hat": "class"})
		var n := ArtLibrary.named(M, slot) as GeometryInstance3D
		var on: bool = n != null and n.material_overlay != null
		M.free()
		return on
	check(ov.call("galaxy", "Body") and not ov.call("galaxy", "DefaultFace") and ov.call("holo", "Body") and ov.call("gknight", "Body") and not ov.call("std", "Body"), "Galaxy, Holo and the gold skins move on the body; a plain skin doesn't")
	st.set_crew("party", [{"name": "Hana", "cls": "soldier", "cos": {"skin": "gsoldier", "hat": "class"}, "ready": true, "slot": 0},
		{"name": "Gus", "cls": "sniper", "cos": {"skin": "galaxy", "hat": "class"}, "ready": true, "slot": 1}], main.menus._stage_hero.get_global_rect())
	check(st.slots[0].look.get("aura") == "gsoldier" and st.slots[1].look.get("glow") != null and st.under.get_parent() == main.menus.root and st.under.get_index() == st.get_index() - 1, "the gold Soldier's aura and the Galaxy's glow are painted, the ground part just under the crew")
	await _shot(pre + "_auras.png")
	# the Locker
	main.menus.show_locker()
	for n in 3:
		await process_frame
	await _shot(pre + "_locker.png")
	_on_spots(st, main.menus._stage_hero.get_global_rect(), 1)
	# a smaller window: the page is built again and the crew follows its hero box
	root.get_window().size = Vector2i(1280, 720)
	for n in 4:
		await process_frame
	main.menus.show_main()
	for n in 4:
		await process_frame
	await _shot(pre + "_small.png")
	_on_spots(st, main.menus._stage_hero.get_global_rect(), 1)
	print("RESULT " + ("PASS" if fails == 0 else "FAIL %d" % fails))
	quit(1 if fails else 0)


## each standing figure's feet land on its browser spot in the hero box (within 3 px)
func _on_spots(st: Lobby3D, box: Rect2, n: int) -> void:
	var xf := Lobby3D.canvas_xf(box)
	var spots: Array = [Lobby3D.me_spot(st.mode == "locker")] + Menus.STAGE2D.others
	var ok := 0
	for i in n:
		var feet := st.cam.unproject_position(st.slots[i].node.global_position) + st.global_position
		var want: Vector2 = xf[1] + Vector2(spots[i][0], spots[i][1] - 4.0) * xf[0]
		if st.slots[i].node.visible and feet.distance_to(want) < 3.0:
			ok += 1
	check(ok == n, "%s: %d of %d on their spots in the hero box" % [st.mode, ok, n])
