extends SceneTree
## The real game (main.tscn) joining a browser-hosted casino over the relay; run by tests/relay_cross.js (scenario 3).
##   godot --headless --path godot --script res://tests/relay_game_driver.gd -- RELAY_URL TOKEN CODE DIR
## Prints "OK ..." / "FAIL ...", writes DIR/id.txt (its player id) and DIR/walked.txt; quits when DIR/done.txt appears.

var fails := 0
var main


func check(cond: bool, what: String) -> void:
	print(("OK " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


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
	var a := OS.get_cmdline_user_args()
	var url: String = a[0]
	var token: String = a[1]
	var code: String = a[2]
	var dir: String = a[3]
	PalAccount.offline = true
	PalNet.keep_session = false
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	for n in 5:
		await process_frame
	main.locker.cloud = {}
	main.locker.persist = false
	main.profile.cloud = false
	main.profile.persist = false
	main.settings.data.name = "Godot"
	var n: PalNet = main.net
	n.relay_opts = {"url": url, "token": token}
	n.join_room(code)
	check(n.relay, "a casino code goes through the relay (%s)" % code)
	check(await _wait(func(): return n.in_game and not main.demo, 20), "the game joins the browser's casino and starts")
	var s: Sim = main.sim
	check(s.casino() and s.players.size() == 2 and s.players.has(n.my_id), "a casino sim with both players (%s)" % n.my_id)
	check(main.cas_room() != "", "in the browser's casino room (%s)" % main.cas_room())
	check(await _wait(func(): return s.players.values().any(func(p): return p.id != n.my_id and p.get("tx") != null), 10), "the browser host's state arrives")
	var f := FileAccess.open(dir + "/id.txt", FileAccess.WRITE)
	f.store_string(n.my_id)
	f.close()
	Input.action_press("pal_right")
	await _wait(func(): return false, 1.4)
	Input.action_release("pal_right")
	f = FileAccess.open(dir + "/walked.txt", FileAccess.WRITE)
	f.store_string("%.2f,%.2f" % [s.player.x, s.player.y])
	f.close()
	n.send_chat("hi from the game")
	check(await _wait(func(): return n.chat.any(func(l): return l.text == "hi from the browser"), 15), "the browser host's chat arrives")
	check(await _wait(func(): return FileAccess.file_exists(dir + "/done.txt") or not n.in_game, 30), "the browser host closes the casino")
	check(await _wait(func(): return main.demo or not n.in_game, 10), "and the game leaves it")
	print("DRIVER %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	quit(1 if fails else 0)
