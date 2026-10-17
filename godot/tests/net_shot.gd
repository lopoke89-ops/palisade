extends SceneTree
## Online play on screen: the lobby and a match with a second soldier who joined through the local PeerJS server.
##   xvfb-run godot --path godot --rendering-driver opengl3 --script res://tests/net_shot.gd -- out_prefix [base|ffa|coop]
## (needs dev/test/peer-server.js running; nothing is saved)

var main


func _wait(cond: Callable, sec: float, also: Array = []) -> bool:
	var end := Time.get_ticks_msec() + sec * 1000
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		for n in also:
			if n.mode == "guest":
				n.guest_frame(1.0 / 60.0, {})
				n.sim.events.clear()
		await process_frame
	return cond.call()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("wrote ", path)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var pre: String = a[0] if a.size() > 0 else "user://net"
	var pv: String = a[1] if a.size() > 1 else "base"
	PalAccount.offline = true
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	for n in 5:
		await process_frame
	main.locker.persist = false
	main.profile.persist = false
	main.locker.cloud = {}
	main.settings.data.name = "Hana"
	var opts := {"host": "127.0.0.1", "port": 9000, "path": "/", "secure": false, "ice": []}
	main.net.opts = opts
	main.menus.show_online("")
	for n in 3:
		await process_frame
	await _shot(pre + "_online.png")
	main.net_host()
	await _wait(func(): return main.net.mode == "host", 10)
	var G := PalNet.new()
	G.sim = Sim.new()
	G.opts = opts
	G.me = {"name": "Gus", "cls": "grenadier", "cos": "neonops|crown|rainbow|supernova", "sk": "", "uid": ""}
	root.add_child(G)
	G.join_room(main.net.code)
	await _wait(func(): return main.net.roster.size() == 2, 15, [G])
	main.net.pick.pvp = pv
	main.net.pick.map = "quarry" if pv == "ffa" else "yard"
	main.net.broadcast_lobby()
	G.set_ready(true)
	G.send_chat("ready when you are")
	await _wait(func(): return main.net.start_block() == "" and not main.net.chat.is_empty(), 5, [G])
	main.menus.show_lobby()
	for n in 3:
		await process_frame
	await _shot(pre + "_lobby.png")
	main.net_start()
	await _wait(func(): return G.in_game, 5, [G])
	var gp: Dictionary = main.sim.players.g1
	if pv == "base":
		main.sim.game.timer = 0.5
	var t := 0.0
	while t < 4.0:
		G.sim.control_local(1.0 / 60.0, {"move": Vector2(0.7, -0.7) if pv != "coop" else Vector2(1, 0)})
		G.guest_frame(1.0 / 60.0, {})
		G.sim.events.clear()
		await process_frame
		t += 1.0 / 60.0
	if pv == "coop":
		main.sim.start_raid()
		await _wait(func(): return false, 3.0, [G])
	else:
		main.sim.player.x = gp.x - 2.5
		main.sim.player.y = gp.y + 0.5
		main.sim.fire(main.sim.player, Vector2(gp.x - main.sim.player.x, gp.y - main.sim.player.y).angle(), 0, main.sim.player.gun)
		await _wait(func(): return false, 0.4, [G])
	await _shot(pre + "_match.png")
	G.leave()
	main.net.leave()
	await process_frame
	quit()
