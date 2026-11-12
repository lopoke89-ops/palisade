extends SceneTree
## Real PeerJS/WebRTC connection: join an already-running high-seed Understrip game,
## survive longer than the twelve-second disconnect timeout, then rejoin it.
## Run bench/join-fix-peer-server.cjs first (port 9011).
var h: PalNet
var g: PalNet
var failures=0
var leaves=[]
func check(value: bool, label: String):
	print(("ok " if value else "FAIL ")+label)
	if not value: failures+=1
func make_net(name_: String) -> PalNet:
	var n=PalNet.new()
	n.sim=Sim.new()
	n.opts={"host":"127.0.0.1","port":9011,"path":"/","secure":false,"ice":[]}
	n.me={"name":name_,"cls":"soldier","cos":"std|class|std|none","sk":"","uid":""}
	root.add_child(n)
	return n
func _initialize():
	call_deferred("run")
func tick():
	var dt=1.0/60.0
	if h.mode=="host":
		if h.in_game: h.sim.update(dt,{})
		h.host_frame(dt)
		h.sim.events.clear()
	if g.mode=="guest":
		g.guest_frame(dt,{})
		g.sim.events.clear()
func wait_for(predicate: Callable, seconds: float) -> bool:
	var end=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end:
		if predicate.call(): return true
		tick()
		await process_frame
	return predicate.call()
func run():
	Engine.max_fps=60
	PalNet.keep_session=false
	h=make_net("Host")
	g=make_net("Guest")
	g.left.connect(func(message): leaves.append(message))
	h.host_room()
	if not await wait_for(func(): return h.mode=="host",10):
		check(false,"local host opens")
		finish()
		return
	h.pick.mode="understrip"
	var opt=h.start_opt("")
	opt.us_seed=4294967295
	h.sim.new_game(1,"normal",{},opt)
	h.host_started()
	g.join_room(h.code)
	if not await wait_for(func(): return g.in_game and h.sim.players.size()==2,12):
		check(false,"guest enters already-running Understrip match")
		finish()
		return
	check(true,"guest enters already-running Understrip match")
	var pid=g.my_id
	check(h.sim.players[pid].has("ripT") and h.sim.players[pid].uj==3,"host initializes joining player's run kit")
	check(not h.sim.collides(h.sim.players[pid].x,h.sim.players[pid].y,.27,true),"guest appears on tunnel floor")
	var initial=g._last_n
	var end=Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<end and g.mode=="guest":
		tick()
		await process_frame
	check(g.mode=="guest" and leaves.is_empty() and h.sim.players.has(pid),"guest stays connected beyond twelve-second timeout")
	check(g._last_n>initial+100,"host snapshots keep arriving")
	# Carry the connected guest to the finale and replicate the Visitor's support encounter.
	h.sim.us.change_level(9)
	h.sim.enemies.clear()
	var arena=h.sim.lay.arena
	for p in h.sim.players.values():
		p.x=arena.x+arena.w/2.0
		p.y=arena.y+arena.h/2.0+3
		p.hp=1e7
		p.max=1e7
	UsDeep.wake(h.sim)
	h.sim.game.us.gate=2
	var visitor=h.sim.enemies[0]
	visitor.hp=visitor.max*.66
	UsDeep.think_visitor(h.sim,visitor,.05)
	UsDeep.think_visitor(h.sim,visitor,3.1)
	var add_key=UsDeep.add_key(h.sim.game.us.seed)
	check(await wait_for(func(): return g.sim.game.us.level==9 and g.sim.enemies.any(func(e): return e.type=="boss" and e.boss=="visitor") and g.sim.enemies.any(func(e): return e.type=="boss" and e.boss==add_key),5),"connected guest sees the Visitor and the same seeded support boss")
	check(g.sim.game.us.bossStage==1,"guest receives the Visitor stage transition")
	check(await wait_for(func(): return h._wl_sent.size()==h.wall_bytes().size(),1),"changing level sizes replaces the host wall snapshot cache")
	var support=g.sim.enemies.filter(func(e): return e.type=="boss" and e.boss==add_key)
	check(not support.is_empty() and UsDeep.boss_frac(g.sim,support[0])>.99,"guest support bar uses its full health")
	g.leave()
	check(await wait_for(func(): return h.sim.players.size()==1,5),"host removes intentional leave")
	leaves.clear()
	g.join_room(h.code)
	check(await wait_for(func(): return g.in_game and h.sim.players.size()==2,12),"guest can rejoin the same running match")
	check(leaves.is_empty(),"rejoining does not trigger a forced leave")
	finish()
func finish():
	g.leave()
	h.leave()
	h.sim.dispose()
	g.sim.dispose()
	g.queue_free()
	h.queue_free()
	print("PASS understrip_connection" if failures==0 else "FAILED understrip_connection: %d" % failures)
	quit(0 if failures==0 else 1)
