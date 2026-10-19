extends SceneTree
## The real game (main.tscn) pressing ENTER THE CASINO: it opens a casino lobby on the relay and walks straight in, and a
## browser joins by its code; run by tests/relay_cross.js (scenario 4).
##   godot --headless --path godot --script res://tests/relay_host_driver.gd -- RELAY_URL TOKEN DIR
## Prints "OK ..." / "FAIL ...", writes DIR/code.txt (the room code), DIR/watching.txt (it has the browser's player) and
## DIR/walked.txt; walks when DIR/go.txt appears and leaves when DIR/done.txt does.

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


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var url: String = a[0]
	var token: String = a[1]
	var dir: String = a[2]
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
	n.relay_opts = {"url": url, "token_fn": func(): return token, "uid_fn": func(): return ""}
	main.start_casino()   # ENTER THE CASINO
	check(n.relay and n.mode == "opening", "ENTER THE CASINO opens a room on the relay, not a solo game")
	check(await _wait(func(): return n.mode == "host" and n.in_game and not main.demo, 20), "the room opens and the game walks straight into the casino")
	var s: Sim = main.sim
	check(s.casino() and CasinoRelay.is_code(n.code) and main.cas_room() == n.peer.room_id(), "a casino in the relay's room (%s)" % main.cas_room())
	_write(dir + "/code.txt", n.code)
	check(await _wait(func(): return s.players.size() == 2, 30), "a browser drops in by the code")
	var guest := ""
	for id in s.players:
		if id != n.my_id:
			guest = id
	var x0: float = s.players[guest].x if guest != "" else 0.0
	_write(dir + "/watching.txt", "1")   # the browser walks once the game is watching
	check(await _wait(func(): return guest != "" and s.players[guest].x > x0 + 0.5, 15), "the browser walks on the game's casino floor")
	check(await _wait(func(): return FileAccess.file_exists(dir + "/go.txt"), 20), "the browser is watching the game")
	Input.action_press("pal_left")
	await _wait(func(): return false, 1.4)
	Input.action_release("pal_left")
	_write(dir + "/walked.txt", "%.2f" % s.player.x)
	n.send_chat("hi from the game")
	check(await _wait(func(): return n.chat.any(func(l): return l.text == "hi from the browser"), 15), "the browser's chat arrives")
	check(await _wait(func(): return FileAccess.file_exists(dir + "/done.txt"), 30), "the browser has seen it all")
	main.net_leave()
	check(await _wait(func(): return main.demo and n.mode == "solo", 10), "the game closes its casino")
	await _wait(func(): return false, 1.0)
	print("DRIVER %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	quit(1 if fails else 0)
