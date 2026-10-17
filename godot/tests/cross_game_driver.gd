extends SceneTree
## The Godot half of tests/cross_game.js: the real game (main.tscn) in a room with the browser game.
##   godot --headless --path godot --script res://tests/cross_game_driver.gd -- --role host|guest --dir DIR
## Host: opens a room, writes its code to DIR/code.txt, waits for the browser guest, starts, checks what comes back.
## Guest: reads the browser host's code from DIR/code.txt, joins, readies, plays. Prints "OK ..." / "FAIL ...";
## exits when DIR/done.txt appears (or after 120 s).

var role := "host"
var dir := ""
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
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		if a[i] == "--role":
			role = a[i + 1]
		if a[i] == "--dir":
			dir = a[i + 1]
	_run.call_deferred()


func _run() -> void:
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
	main.settings.data.setup.cls = "soldier" if role == "host" else "sniper"
	main.net.opts = {"host": "127.0.0.1", "port": 9000, "path": "/", "secure": false, "ice": []}
	if role == "host":
		await _as_host()
	else:
		await _as_guest()
	print("DRIVER %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	await _wait(func(): return FileAccess.file_exists(dir + "/done.txt"), 60)
	main.net.leave()
	await process_frame
	quit(1 if fails else 0)


func _put(name: String, text: String) -> void:
	var f := FileAccess.open(dir + "/" + name, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _as_host() -> void:
	var n: PalNet = main.net
	main.net_host()
	check(await _wait(func(): return n.mode == "host", 15), "the Godot room opens (%s)" % n.code)
	_put("code.txt", n.code)
	check(await _wait(func(): return n.roster.size() == 2, 30), "the browser guest joins")
	if n.roster.size() < 2:
		return
	check(n.roster[1].name == "Rook" and n.roster[1].cls == "grenadier", "named Rook, a grenadier (%s, %s)" % [n.roster[1].name, n.roster[1].cls])
	check(await _wait(func(): return n.start_block() == "", 20), "the browser readies up")
	main.net_start()
	check(n.in_game and not main.demo and main.sim.players.size() == 2, "the match starts with both")
	var g: Dictionary = main.sim.players.get("g1", {})
	var x0: float = g.get("x", 0.0)
	var y0: float = g.get("y", 0.0)
	check(await _wait(func(): return Vector2(g.x - x0, g.y - y0).length() > 0.6, 20), "the browser guest walks; the Godot host sees it (%.2f,%.2f -> %.2f,%.2f)" % [x0, y0, g.x, g.y])
	_put("moved.txt", "1")
	var b0: int = main.sim.game.stats.built
	check(await _wait(func(): return main.sim.game.stats.built > b0, 20), "the browser guest builds a wall on the host")
	# a wall of the host's own, for the browser to see
	var p: Dictionary = main.sim.player
	var put := ""
	for d in [[0, 1], [1, 0], [0, -1], [-1, 0], [1, 1], [-1, -1]]:
		var t: Dictionary = main.sim.build_eval(p, floori(p.x) + d[0], floori(p.y) + d[1], 0, false)
		if t.ok:
			p.bcd = 0.0
			main.sim.do_build(p, t.i, t.j, 0, false)
			if main.sim.walls[main.sim.idx(t.i, t.j)] != null:
				put = "%d,%d" % [t.i, t.j]
				break
	check(put != "", "the Godot host builds a wall (%s)" % put)
	_put("hostwall.txt", put)
	main.sim.start_raid()
	check(await _wait(func(): return not main.sim.enemies.is_empty(), 10), "a raid starts on the host")
	_put("raid.txt", "1")
	n.send_chat("hello from godot")
	check(await _wait(func(): return n.chat.any(func(l): return l.text == "hello from browser" and l.name == "Rook"), 20), "the browser's chat line arrives")
	# the guest goes down on the host; the browser should show it
	main.sim.hurt_player(g, 9999.0)
	_put("hurt.txt", "1")
	check(await _wait(func(): return FileAccess.file_exists(dir + "/sawdown.txt"), 20), "the browser saw itself go down")


func _as_guest() -> void:
	var n: PalNet = main.net
	check(await _wait(func(): return FileAccess.file_exists(dir + "/code.txt"), 40), "the browser room's code arrives")
	var code := FileAccess.get_file_as_string(dir + "/code.txt").strip_edges()
	main.net_join(code)
	check(await _wait(func(): return n.mode == "guest" and n.roster.size() == 2, 20), "Godot joins the browser's room (%s)" % code)
	if n.mode != "guest":
		return
	check(n.my_id == "g1" and n.roster[0].name == "Big U", "named g1; the host is Big U (%s)" % (n.roster[0].name if n.roster.size() > 0 else "?"))
	n.set_ready(true)
	_put("ready.txt", "1")
	check(await _wait(func(): return n.in_game and not main.demo, 30), "the browser host starts the match")
	var s: Sim = main.sim
	check(s.players.size() == 2 and s.player.id == "g1" and s.player.cls == "sniper" and s.players.has("host"), "Godot's sim has both; it is the sniper (%s)" % s.player.get("cls", "?"))
	check(await _wait(func(): return s.players.host.get("tx") != null, 10), "state packets arrive from the browser")
	var cq: String = s.players.host.cls
	check(cq == "quartermaster", "the host's class came through (%s)" % cq)
	# walk east with the real controls
	Input.action_press("pal_right")
	await _wait(func(): return false, 1.4)
	Input.action_release("pal_right")
	_put("moved.txt", "%.2f,%.2f" % [s.player.x, s.player.y])
	check(await _wait(func(): return FileAccess.file_exists(dir + "/hostsaw.txt"), 20), "the browser host saw Godot walk")
	# build next to us through the real action
	var built := false
	for d in [Vector2(0, 1), Vector2(1, 0), Vector2(0, -1), Vector2(-1, 0)]:
		s.player.face = d
		var t := s.build_target(s.player, 0, false)
		if t.ok:
			main.do_action("build")
			built = true
			_put("built.txt", "%d,%d" % [t.i, t.j])
			break
	check(built, "Godot asks the browser host to build")
	check(await _wait(func(): return FileAccess.file_exists(dir + "/wallok.txt"), 20), "the wall stands on the browser host")
	check(await _wait(func(): return s.walls[s.idx(int(FileAccess.get_file_as_string(dir + "/built.txt").split(",")[0]), int(FileAccess.get_file_as_string(dir + "/built.txt").split(",")[1]))] != null, 10), "and comes back to Godot")
	# a raid and a boss
	check(await _wait(func(): return not s.enemies.is_empty(), 30), "raiders from the browser show up in Godot (%d)" % s.enemies.size())
	var states := {}
	var boss_seen := [""]
	var end := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < end:
		for e in s.enemies:
			if e.type == "boss":
				boss_seen[0] = e.boss
				states[e.st] = true
		if states.size() >= 2:
			break
		await process_frame
	check(boss_seen[0] == "butcher", "the browser's Butcher shows up as a Butcher (%s)" % boss_seen[0])
	check(states.size() >= 2, "his attack states come through (%s)" % str(states.keys()))
	n.send_chat("hello from browser")   # the host side expects this line from the guest in the other scenario only
	check(await _wait(func(): return n.chat.any(func(l): return l.text == "hello from godot"), 20), "the browser host's chat arrives")
	check(await _wait(func(): return s.player.downed or not s.player.alive, 20), "the browser host knocks Godot down; Godot sees it")
	_put("sawdown.txt", "1")
