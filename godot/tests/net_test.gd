extends SceneTree
## Online play between two Godot screens in one process, through the local PeerJS server
## (cd dev/test && node peer-server.js). A host and a guest: lobby, ready, start, movement, building, a raid's
## state, chat, the armory, leaving.

var fails := 0
var opts := {"host": "127.0.0.1", "port": 9000, "path": "/", "secure": false, "ice": []}


func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _mk(nm: String, cls: String) -> PalNet:
	var n := PalNet.new()
	n.sim = Sim.new()
	n.opts = opts
	n.me = {"name": nm, "cls": cls, "cos": "std|class|std|none", "sk": "", "uid": ""}
	root.add_child(n)
	return n


func _wait(cond: Callable, sec: float, nets: Array = []) -> bool:
	var end := Time.get_ticks_msec() + sec * 1000
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		for n in nets:
			_tick(n, 1.0 / 60.0)
		await process_frame
	return cond.call()


func _tick(n: PalNet, dt: float) -> void:
	if n.mode == "host":
		if n.in_game:
			n.sim.update(dt, {})
		n.host_frame(dt)
		n.sim.events.clear()
	elif n.mode == "guest":
		n.guest_frame(dt, {})
		n.sim.events.clear()


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	PalNet.keep_session = false
	print("online: a Godot host and a Godot guest")
	var H := _mk("Hana", "soldier")
	var G := _mk("Gus", "quartermaster")
	H.host_room()
	check(await _wait(func(): return H.mode == "host", 10), "the room opens (%s)" % H.code)
	G.join_room(H.code)
	check(await _wait(func(): return G.mode == "guest" and H.roster.size() == 2, 15, [H, G]), "the guest joins: roster of two")
	check(await _wait(func(): return G.roster.size() == 2, 5, [H, G]), "the guest sees the lobby")
	check(G.my_id == "g1" and H.roster[1].name == "Gus" and H.roster[1].cls == "quartermaster", "named g1, Gus the quartermaster")
	check(H.start_block().begins_with("Everyone has to ready up"), "the host waits for ready (%s)" % H.start_block())
	G.set_ready(true)
	check(await _wait(func(): return H.start_block() == "", 5, [H, G]), "ready: the host can start")
	G.send_chat("hello​  there")
	check(await _wait(func(): return not G.chat.is_empty() and not H.chat.is_empty(), 5, [H, G]), "chat reaches both")
	check(H.chat[-1].text == "hello there" and H.chat[-1].name == "Gus", "cleaned and named (%s)" % H.chat[-1].text)

	H.sim.new_game(-1, "normal", {}, H.start_opt(""))
	H.host_started()
	check(await _wait(func(): return G.in_game, 5, [H, G]), "the match starts on the guest")
	check(G.sim.players.size() == 2 and G.sim.player.id == "g1" and G.sim.player.cls == "quartermaster", "the guest's sim has the crew, and is Gus")
	check(await _wait(func(): return G._last_n > 3, 5, [H, G]), "state packets arrive (%d)" % G._last_n)
	var gp: Dictionary = G.sim.player
	var hp: Dictionary = H.sim.players.g1
	var x0: float = hp.x
	for n in 30:
		G.sim.control_local(1.0 / 60.0, {"move": Vector2(1, 0)})
		_tick(H, 1.0 / 60.0)
		_tick(G, 1.0 / 60.0)
		await process_frame
	check(await _wait(func(): return hp.x > x0 + 0.3, 3, [H, G]), "the guest walks; the host sees it (%.2f -> %.2f)" % [x0, hp.x])
	var hgp: Dictionary = G.sim.players.host
	H.sim.player.x += 1.0
	check(await _wait(func(): return absf(hgp.x - H.sim.player.x) < 0.05, 3, [H, G]), "the host moves; the guest sees it")
	# a wall, built by the guest through the host's rules
	var t := {}
	for d in [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]:
		gp.face = d
		t = G.sim.build_target(gp, 0, false)
		if t.ok:
			break
	var k := G.sim.idx(t.i, t.j)
	G.send_build(t.i, t.j, 0, false)
	check(await _wait(func(): return H.sim.walls[k] != null, 3, [H, G]), "the guest's wall stands on the host (%d,%d)" % [t.i, t.j])
	check(await _wait(func(): return G.sim.walls[k] != null, 3, [H, G]), "and comes back to the guest")
	check(await _wait(func(): return gp.mats[0] == hp.mats[0] and hp.mats[0] < 24, 3, [H, G]), "wood paid on both (%d)" % gp.mats[0])
	# the raid: raiders on the guest's screen
	H.sim.start_raid()
	check(await _wait(func(): return G.sim.game.phase == "raid" and not G.sim.enemies.is_empty(), 8, [H, G]), "raiders show up on the guest (%d)" % G.sim.enemies.size())
	var he: Dictionary = H.sim.enemies[0]
	var ge
	for e in G.sim.enemies:
		if e.id == he.id:
			ge = e
	check(ge != null and ge.type == he.type, "same raider, same type (%s)" % he.type)
	he.hp = he.max * 0.5
	check(await _wait(func(): return ge != null and absf(ge.hp - 0.5) < 0.02, 3, [H, G]), "its health as a share (%.2f)" % (ge.hp if ge != null else -1.0))
	# the host's shot reaches the guest's screen as a bullet
	H.sim.fire(H.sim.player, 0.0, 0, H.sim.player.gun)
	check(await _wait(func(): return G.sim.bullets.size() > 0, 3, [H, G]), "a shot appears on the guest")
	# toasts and personal sounds
	H.sim.toast("TEST", "a toast for everyone")
	var seen_t := [false]
	var keep: Callable = func():
		for e in G.sim.events:
			if e.k == "toast" and e.title == "TEST":
				seen_t[0] = true
		return seen_t[0]
	var end := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < end and not seen_t[0]:
		_tick(H, 1.0 / 60.0)
		G.guest_frame(1.0 / 60.0, {})
		keep.call()
		G.sim.events.clear()
		await process_frame
	check(seen_t[0], "a toast reaches the guest")
	# the armory: the guest's purchase goes through the host
	H.sim.game.phase = "build"
	gp_to_stake(H.sim, hp)
	hp.sal = 100
	G.send_upgrade("d")
	check(await _wait(func(): return hp.up.d == 1 and hp.sal == 80, 3, [H, G]), "the guest buys DAMAGE on the host (sal %d)" % hp.sal)
	check(await _wait(func(): return gp.up.d == 1 and gp.sal == 80, 3, [H, G]), "and sees it (upS %d, sal %d)" % [gp.up.d, gp.sal])
	# leaving
	G.leave()
	check(await _wait(func(): return not H.sim.players.has("g1"), 5, [H, G]), "the host sees the guest leave")
	H.leave()
	print("")
	print("FAILED %d" % fails if fails else "ALL PASSED")
	H.sim.dispose()
	G.sim.dispose()
	quit(1 if fails else 0)


func gp_to_stake(s: Sim, p: Dictionary) -> void:
	var at := s.spawn_near_core()
	p.x = at.x
	p.y = at.y
	p.tp += 1
