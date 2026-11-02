extends SceneTree
## The casino floor and its tables together: walk up to a table, sit with E, play, stand up with Esc.
## Against the local tables server (tests/tables_server.js; never the real project).
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --script res://tests/casino_play_shot.gd -- out_prefix

const PORT := 18799
const A := "a0000000-0000-4000-8000-00000000000b"

var pid := -1
var fails := 0
var main


func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func transport(method: String, path: String, body, headers: PackedStringArray) -> Dictionary:
	var req := HTTPRequest.new()
	root.add_child(req)
	req.request("http://127.0.0.1:%d%s" % [PORT, path], headers, HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_GET, JSON.stringify(body) if body != null else "")
	var res: Array = await req.request_completed
	req.queue_free()
	var t: String = (res[3] as PackedByteArray).get_string_from_utf8()
	return {"ok": res[1] >= 200 and res[1] < 300, "status": res[1], "j": JSON.parse_string(t) if t != "" else null}


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("wrote ", path)


func _wait(cond: Callable, sec: float) -> bool:
	var end := Time.get_ticks_msec() + sec * 1000
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pre: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://cplay"
	PalAccount.offline = true
	pid = OS.create_process("node", [ProjectSettings.globalize_path("res://tests/tables_server.js"), str(PORT)])
	for i in 80:
		await create_timer(0.25).timeout
		var r := await transport("POST", "/test/ping", {}, PackedStringArray())
		if r.ok:
			break
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	for n in 5:
		await process_frame
	main.locker.persist = false
	main.locker.cloud = {}
	main.profile.persist = false
	var acct: PalAccount = main.account
	acct.transport = transport
	acct.s = {"access_token": "tok-b", "refresh_token": "r", "expires_at": 9e9, "user": {"id": A, "is_anonymous": false}}
	acct.state = "full"
	check(main.casino_ui != null, "the game has the table sheets")
	main.casino_ui.persist_seed = false
	main.casino_ui.sync_locker = false
	main.casino_alone()
	var s: Sim = main.sim
	check(s.casino() and not main.demo, "THE CASINO opens")
	var q := CasinoView.seat_of(31)   # roulette, seat 1
	s.player.x = q.pos[0] + 0.4
	s.player.y = q.pos[1] + 0.4
	for n in 3:
		await process_frame
	await _shot(pre + "_floor.png")
	main.do_action("armory")   # E: sit
	check(int(s.player.seat) == 31, "E sits at the roulette table (%s)" % s.player.get("seat", 0))
	var ui = main.casino_ui
	check(await _wait(func(): return ui.is_open() and ui.tables.id != 0, 15), "the sheet opens and the server seats us")
	for n in 30:
		await process_frame
	await _shot(pre + "_table.png")
	check(main.audio.music_route()[0] == "casino", "the casino playlist plays")
	main.do_action("pause")   # Esc: stand up
	check(int(s.player.seat) == 0 and not ui.is_open(), "Esc stands up and hides the sheet")
	check(await _wait(func(): return ui.tables.id == 0, 10), "and the server gives the seat back")
	main.to_menu()
	check(main.demo and main.audio.music_route()[0] == "menu", "back to the menu and its music")
	OS.kill(pid)
	print("ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
