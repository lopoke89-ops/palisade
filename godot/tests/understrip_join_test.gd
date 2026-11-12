extends SceneTree
## Start messages go through JSON just as they do over PeerNet. A run seed is uint32,
## including its upper half; entering or rejoining must not kick a valid guest.
var failures=0
class CapturePeer:
	extends Node
	var sent=[]
	func send(_id: String, message: Dictionary, _channel: String="r"):
		sent.append(message)
func check(value: bool, label: String):
	print(("ok " if value else "FAIL ")+label)
	if not value: failures+=1
func _initialize():
	PalNet.keep_session=false
	var h=PalNet.new()
	h.sim=Sim.new()
	h.mode="host"
	h.in_game=true
	h.roster=[{"id":"host","name":"Host","cls":"soldier","cos":"std|class|std|none","sk":"","team":""},
		{"id":"g1","name":"Guest","cls":"soldier","cos":"std|class|std|none","sk":"","team":""}]
	h.sim.new_game(1,"normal",{}, {"mode":"understrip","roster":h.roster,"my_id":"host","us_seed":0})
	for seed in [0,2147483647,2147483648,4294967295]:
		for level in [0,1,2]:
			# Rebuild the host using the exact run seed before producing its actual start message.
			h.sim.new_game(1,"normal",{}, {"mode":"understrip","roster":h.roster,"my_id":"host","us_seed":seed,"us_level":level})
			var msg=JSON.parse_string(JSON.stringify(h._start_msg()))
			var g=PalNet.new()
			g.sim=Sim.new()
			g.mode="guest"
			g.my_id="g1"
			g._guest_data(msg)
			check(g.mode=="guest" and g.in_game,"seed %d level %d enters match" % [seed,level])
			if g.in_game:
				check(g.sim.game.us.seed==seed and g.sim.game.us.level==level,"guest retains seed and level")
				check(PalUnderstripGen.tile_hash(g.sim.lay.us)==PalUnderstripGen.tile_hash(h.sim.lay.us),"guest and host build identical tunnels")
			g.sim.dispose()
			g.free()
	for seed in [-1,4294967296,1.5,"4294967295"]:
		var msg=JSON.parse_string(JSON.stringify(h._start_msg()))
		msg.us[0]=seed
		var g=PalNet.new()
		g.sim=Sim.new()
		g.mode="guest"
		g.my_id="g1"
		g._guest_data(msg)
		check(g.mode=="solo" and not g.in_game,"invalid seed %s is still rejected" % str(seed))
		g.sim.dispose()
		g.free()
	h.sim.dispose()
	h.free()
	# Exercise the actual hello handler after the host has already started a run.
	var late=PalNet.new()
	late.sim=Sim.new()
	late.mode="host"
	late.in_game=true
	late.roster=[{"id":"host","name":"Host","cls":"soldier","cos":"std|class|std|none","sk":"","team":""}]
	late.sim.new_game(1,"normal",{}, {"mode":"understrip","roster":late.roster,"my_id":"host","us_seed":4294967295})
	var capture=CapturePeer.new()
	late.peer=capture
	late._conns["friend"]={"pid":"","heard":0.0}
	late._host_data("friend",{"t":"hello","name":"Friend","cls":"soldier","cos":"std|class|std|none","sk":"","uid":"","v":PalNet.PROTO,"session":"0123456789abcdef01234567"})
	var p=late.sim.players.g1
	var initialized=p.has("ujT") and p.has("ripT") and p.has("wSel")
	check(initialized,"late guest has Understrip kit before host tick")
	check(not late.sim.collides(p.x,p.y,.27,true),"late guest spawns on walkable tunnel floor")
	if initialized:
		late.sim.update(.05)
		check(late.sim.game.time>.0,"host continues simulating after late join")
	late.sim.dispose()
	late.peer=null
	capture.free()
	late.free()
	print("PASS understrip_join" if failures==0 else "FAILED understrip_join: %d" % failures)
	quit(0 if failures==0 else 1)
