extends SceneTree
## The exported game, checked from its own pack: the model library, the hub (painted background, the 3D player),
## Settings (WINDOW and GRAPHICS), a quality preset and a 3D raid all come up with nothing but the pack. Exports leave
## tools/ out, so this runs from the folder, against the .exe (WebRTC's Linux library missing is expected):
##   xvfb-run -a godot --main-pack export/palisade/Palisade.exe --rendering-driver opengl3 --resolution 1600x900 \
##     --script "$PWD/godot/tools/check_export.gd" -- /tmp/pack      (prints RESULT PASS; writes /tmp/pack_<page>.png)
## Godot 4.7.2 can then abort while freeing the GL renderer at exit (as the menu screenshot tests do): read RESULT.

var fails := 0


func check(c: bool, w: String) -> void:
	print(("OK " if c else "FAIL ") + w)
	if not c:
		fails += 1


func _init() -> void:
	_run.call_deferred()


func _shot(p: String, n: int = 10) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(p)


func _texts(n: Node, out: Array = []) -> Array:
	if n is Label:
		out.append(n.text)
	elif n is UiKit.Btn:
		out.append(n.text)
	for c in n.get_children():
		_texts(c, out)
	return out


func _run() -> void:
	var pre: String = OS.get_cmdline_user_args()[0]
	check(not FileAccess.file_exists("res://tests/client_test.gd"), "this is the exported pack (no tests inside)")
	check(ArtLibrary.get_lib() != null and Lobby3D.available() and View3D.available(), "the model library loads from the pack")
	check(FileAccess.file_exists("res://palisade_art/catalog.json") and ResourceLoader.exists("res://palisade_art/models/players/soldier.glb") and ResourceLoader.exists("res://palisade_art/models/bosses/butcher.glb"), "catalog, players and bosses are in it")
	PalAccount.offline = true
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	main.locker.persist = false
	main.profile.persist = false
	var D: Dictionary = main.settings.data
	check(D.has("windowMode") and D.has("fpsCap") and D.has("gfx3d"), "the new display and graphics settings are there")
	main.menus.show_main()
	await _shot(pre + "_home.png", 20)
	check(main.menus.root.get_child(0) is LockerUI.BgView and main.menus.stage != null and main.menus.stage.slots.size() > 0 and main.menus.stage.slots[0].model != null, "the hub: painted background and the 3D player on the stage")
	for pg in ["online", "locker", "index"]:
		match pg:
			"online": main.menus.show_online("")
			"locker": main.menus.show_locker()
			"index": main.menus.show_index("classes")
		await _shot(pre + "_" + pg + ".png", 14)
	main.menus.pages.show_settings()
	await _shot(pre + "_settings.png", 8)
	var t := _texts(main.menus.root)
	check("GRAPHICS" in t and "WINDOW" in t and "FPS LIMIT" in t and "RENDER SCALE" in t, "Settings has WINDOW and GRAPHICS")
	D.gfx3d = Quality3D.preset("low")
	main.apply_settings()
	check(Quality3D.shadows == 0 and is_equal_approx(main.get_viewport().scaling_3d_scale, 0.75), "QUALITY LOW applies")
	D.gfx3d = Quality3D.preset("high")
	main.apply_settings()
	main.start_game()
	for i in 90:
		await process_frame
	await _shot(pre + "_raid.png", 4)
	check(main.v3 != null and main.v3.visible and not main.demo, "a game starts in 3D")
	print("RESULT " + ("PASS" if fails == 0 else "FAIL %d" % fails))
	quit(1 if fails else 0)
