extends SceneTree
## Settings › WINDOW on a real window: the display mode, the window size and the frame limit take effect, and the card
## shows each state.
##   xvfb-run -a -s "-screen 0 1920x1080x24" sh -c 'openbox & sleep 1; godot --path godot --rendering-driver opengl3 --script res://tests/display_shot.gd -- out_prefix'
## (fullscreen on X11 needs a window manager: under a bare xvfb the fullscreen checks fail)
## Prints OK/FAIL lines and writes <prefix>_windowed.png and <prefix>_fullscreen.png (Settings, at the WINDOW card).

var fails := 0


func check(cond: bool, what: String) -> void:
	print(("OK " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(path: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("wrote ", path)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pre: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://display"
	var keep := FileAccess.get_file_as_string(PalSettings.PATH) if FileAccess.file_exists(PalSettings.PATH) else ""
	PalAccount.offline = true
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	main.locker.persist = false
	main.profile.persist = false
	var D: Dictionary = main.settings.data
	var scr := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	# a window size from the card
	D.windowMode = "windowed"
	D.winSize = "1600x900"
	main.apply_settings()
	await _frames(10)
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED and root.get_window().size == Vector2i(1600, 900), "WINDOW SIZE 1600×900 sizes the window (%s)" % root.get_window().size)
	var pos := DisplayServer.window_get_position()
	check(absi(pos.x - (scr.x - 1600) / 2) <= 2 and absi(pos.y - (scr.y - 900) / 2) <= 40, "and centres it on the screen (%s)" % pos)
	main.menus.pages.show_settings()
	await _shot(pre + "_windowed.png")
	var labels := _texts(main.menus.root)
	check("WINDOWED" in labels and "1280×720" in labels and "1920×1080" in labels and "144" in labels, "the card offers the modes, the sizes that fit and the limits")
	# a size the player drags to is left alone when another setting changes
	root.get_window().size = Vector2i(1500, 800)
	await _frames(4)
	D.shake = 0.5
	main.apply_settings()
	await _frames(4)
	check(root.get_window().size == Vector2i(1500, 800), "another setting doesn't undo a resize by hand")
	# fullscreen, and back
	D.windowMode = "fullscreen"
	main.apply_settings()
	await _frames(20)
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN and root.get_window().size == scr, "FULLSCREEN fills the display (%s)" % root.get_window().size)
	main.menus.pages.show_settings()
	await _shot(pre + "_fullscreen.png")
	D.windowMode = "exclusive"
	main.apply_settings()
	await _frames(20)
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN and root.get_window().size == scr, "EXCLUSIVE takes the display (%s)" % root.get_window().size)
	D.windowMode = "windowed"
	main.apply_settings()
	await _frames(20)
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED and root.get_window().size == Vector2i(1600, 900), "WINDOWED comes back at the chosen size (%s)" % root.get_window().size)
	# the frame limit
	D.fpsMode = "auto"
	D.fpsCap = "60"
	main.apply_settings()
	check(Engine.max_fps == 60, "FPS LIMIT 60 caps the frames")
	D.fpsCap = "off"
	main.apply_settings()
	check(Engine.max_fps == 0, "OFF lifts it")
	if keep != "":
		var f := FileAccess.open(PalSettings.PATH, FileAccess.WRITE)
		f.store_string(keep)
	elif FileAccess.file_exists(PalSettings.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PalSettings.PATH))
	print("RESULT " + ("PASS" if fails == 0 else "FAIL %d" % fails))
	quit(1 if fails else 0)


## every button and label's text on the page
func _texts(n: Node, out: Array = []) -> Array:
	if n is Label:
		out.append(n.text)
	elif n is UiKit.Btn:
		out.append(n.text)
	for c in n.get_children():
		_texts(c, out)
	return out
