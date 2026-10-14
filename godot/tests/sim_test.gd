extends SceneTree
## Headless checks for the ported sim: godot --headless --path godot --script res://tests/sim_test.gd
## Exit code 0 = all passed.

var fails := 0
var sims: Array = []


func _mk() -> Sim:
	var s := Sim.new()
	sims.append(s)
	return s


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		fails += 1


func _init() -> void:
	print("the client scripts load")
	var main_script = load("res://scripts/main.gd")
	check(main_script != null and main_script.can_instantiate(), "main.gd parses")

	print("hash parity with the browser (values from node)")
	var ref := [[0, 0, 0], [1, 0, 0.5081244610501743], [0, 1, 0.7682745544631674], [4, 11, 0.28116835986291255], [15, 15, 0.6118243966744804],
		[400, 77, 0.9309408012616776], [-6, -6, 0.18195412777875414], [407, 93, 0.121274691801815], [12345, 678, 0.7270846461707458], [-3, 9, 0.02733767848167049]]
	for r in ref:
		check(absf(Pal.hash2(r[0], r[1]) - r[2]) < 1e-12, "hash(%d,%d) = %f" % [r[0], r[1], r[2]])

	print("new game: the Yard on Normal")
	var s := _mk()
	s.new_game(7)
	var ruins := 0
	for w in s.walls:
		if w != null:
			ruins += 1
	check(ruins == 6, "six ruin walls")
	check(s.core.hp == 500.0, "stake 500 hp")
	check(s.game.timer == 40.0, "40 s to build")
	check(Vector2(s.player.x, s.player.y) == Vector2(5.5, 11.5), "soldier at 5.5,11.5")
	check(s.player.mats == [24, 0, 0], "24 wood")
	check(s.dist[s.core_k] == 0.0 and s.dist[s.idx(15, 0)] < 1e6, "flow field reaches the stake")

	print("projection")
	var v := IsoView.new()
	v.resize(1280, 720)
	check(is_equal_approx(v.S, 1.35) and is_equal_approx(v.TW2, 54.0), "S clamps to 1.35, TW2=54 at 1280x720")
	v.cam_snap(5.5, 11.5)
	var sp := v.iso(7.25, 3.5)
	var back := v.screen_to_world(sp.x, sp.y)
	check(back.distance_to(Vector2(7.25, 3.5)) < 1e-4, "screen_to_world inverts iso (Vector2 is 32-bit)")

	print("building")
	s.local_build()
	var k := s.idx(6, 11)
	check(s.walls[k] != null and s.walls[k].mat == 0 and s.walls[k].hp == 60.0, "wood wall raised at 6,11")
	check(s.player.mats[0] == 20, "cost 4 wood")
	check(is_equal_approx(s.player.bcd, 0.22 * 0.6), "build cooldown .22 x .6")
	s.local_build()
	check(s.player.mats[0] == 20, "cooldown blocks a second build")
	s.player.bcd = 0.0
	var t := s.build_target(s.player, 0, false)
	check(not t.ok and t.reason == "At full strength", "full wall: At full strength")
	s.game.piece = "door"
	t = s.build_target(s.player, 0, true)
	check(t.ok and t.act == "MAKE DOOR" and t.cost == 4, "make door costs 4")
	s.game.piece = "wall"

	print("gathering")
	var g := _mk()
	g.new_game(1)
	g.player.x = 2.5
	g.player.y = 8.3   # beside the wood pile at 2,7
	for n in 60:
		g.update(1.0 / 60.0, {})
	check(g.player.mats[0] > 24, "walking into wood gathers (%d)" % g.player.mats[0])

	print("explosions")
	var e := _mk()
	e.new_game(3)
	var rk := e.idx(4, 9)
	var hp0: float = e.walls[rk].hp
	e.explode(4.5, 9.5, 1.65, 1.0, 0)
	check(e.walls[rk] == null, "a grenade on a weakened wood ruin (%.1f hp) knocks it down" % hp0)
	check(e.debris[rk] == 1, "leaves wood debris")
	check(e.walls[e.idx(3, 9)] == null and e.walls[e.idx(5, 9)] == null, "the blast also takes both neighbouring ruins (f=.68 x 80 x 2.2)")
	check(e.player.sal == 15, "three wood ruins pay 5 salvage each (%d)" % e.player.sal)

	print("a raid, played by a simple bot")
	var r := _mk()
	r.new_game(11)
	r.start_raid()
	check(r.game.queue.size() == 3, "raid 1 sends 3 riflemen")
	var shots_back := 0
	var time := 0.0
	while time < 240.0 and r.game.phase == "raid":
		var ctl := {}
		var p: Dictionary = r.player
		var best = null
		var bd := 1e9
		for en in r.enemies:
			var d := Vector2(en.x - p.x, en.y - p.y).length()
			if d < bd:
				bd = d
				best = en
		if best != null and bd < 5.5:   # inside a rifleman's 7-tile sight, so both sides trade fire
			ctl = {"aim": Vector2(best.x - p.x, best.y - p.y), "fire": true}
		r.update(1.0 / 60.0, ctl)
		for bl in r.bullets:
			if bl.team == 1:
				shots_back += 1
		time += 1.0 / 60.0
	check(r.game.stats.dropped >= 3, "the bot dropped the raid (%d) in %.0f s" % [r.game.stats.dropped, time])
	check(r.game.phase == "build" and r.game.wave == 1, "raid 1 broken, back to building")
	check(r.player.sal == 9, "8 + raid salvage paid")
	check(shots_back > 0, "raiders shot back")

	print("raid mix matches the browser's waveMix (values from node)")
	var mix_ref := [[1,1,{"rifle":3,"gren":0,"breach":0,"fire":0,"shield":0,"medic":0,"spotter":0}],[2,1,{"rifle":3,"gren":1,"breach":0,"fire":1,"shield":0,"medic":0,"spotter":0}],[3,1,{"rifle":3,"gren":2,"breach":1,"fire":1,"shield":1,"medic":0,"spotter":0}],[4,1,{"rifle":3,"gren":3,"breach":2,"fire":1,"shield":1,"medic":1,"spotter":0}],[5,1,{"rifle":3,"gren":4,"breach":3,"fire":2,"shield":1,"medic":1,"spotter":0}],[6,1,{"rifle":3,"gren":5,"breach":4,"fire":2,"shield":2,"medic":1,"spotter":1}],[7,1,{"rifle":4,"gren":6,"breach":5,"fire":2,"shield":2,"medic":1,"spotter":1}],[1,2,{"rifle":5,"gren":0,"breach":0,"fire":0,"shield":0,"medic":0,"spotter":0}],[3,2,{"rifle":6,"gren":2,"breach":1,"fire":1,"shield":1,"medic":0,"spotter":0}],[5,2,{"rifle":7,"gren":4,"breach":3,"fire":2,"shield":1,"medic":1,"spotter":0}],[7,2,{"rifle":8,"gren":6,"breach":5,"fire":2,"shield":2,"medic":1,"spotter":1}],[2,4,{"rifle":9,"gren":2,"breach":0,"fire":2,"shield":0,"medic":0,"spotter":0}],[4,4,{"rifle":11,"gren":4,"breach":3,"fire":2,"shield":2,"medic":1,"spotter":0}],[6,4,{"rifle":13,"gren":6,"breach":5,"fire":3,"shield":3,"medic":1,"spotter":1}],[7,4,{"rifle":15,"gren":7,"breach":6,"fire":3,"shield":3,"medic":1,"spotter":1}]]
	var mix_ok := true
	for m in mix_ref:
		var got := s.wave_mix(m[0], m[1], 0)
		for key in m[2]:
			if got[key] != m[2][key]:
				mix_ok = false
				print("    raid %d crew %d %s: %d, browser %d" % [m[0], m[1], key, got[key], m[2][key]])
	check(mix_ok, "15 raid/crew combinations identical")

	print("raider types")
	var sh := _mk()
	sh.new_game(5)
	sh.game.phase = "raid"
	var se := sh.spawn_enemy_at("shield", 9.5, 11.5)
	se.aim = Vector2(-1, 0)   # facing the soldier at 5.5,11.5
	var hp_s: float = se.hp
	sh.player.aim = Vector2(1, 0)
	for n in 5:
		sh.fire(sh.player, 0.0, 0, Pal.SOLDIER.gun)
	for n in 20:
		sh.update_bullets(1.0 / 60.0)
	check(se.hp == hp_s and se.shieldHitsLeft == 15, "a riot shield stops 5 rounds from the front (%d of 20 hits left)" % se.shieldHitsLeft)
	se.aim = Vector2(1, 0)   # turned away
	sh.fire(sh.player, 0.0, 0, Pal.SOLDIER.gun)
	for n in 20:
		sh.update_bullets(1.0 / 60.0)
	check(se.hp < hp_s, "but not from behind")

	var br := _mk()
	br.new_game(6)
	br.game.phase = "raid"
	for j in 16:   # a full wall line across the yard, so there is no way round
		br.walls[br.idx(8, j)] = Pal.make_wall(0, false)
	br.compute_flow()
	br.spawn_enemy_at("breach", 10.5, 11.5)
	var boom := false
	for n in 600:
		br.update_enemies(1.0 / 60.0)
		br.update_charges(1.0 / 60.0)
		if br.walls[br.idx(8, 11)] == null or br.walls[br.idx(8, 10)] == null or br.walls[br.idx(8, 12)] == null:
			boom = true
			break
	check(boom, "a breacher's satchel takes out the wall in his way")

	var fb := _mk()
	fb.new_game(8)
	fb.game.phase = "raid"
	for j in 16:   # a full wall line across the yard, so there is no way round
		fb.walls[fb.idx(8, j)] = Pal.make_wall(0, false)
	fb.compute_flow()
	fb.player.x = 1.5
	fb.player.y = 2.5
	fb.qm.alive = false   # keep the two of them out of it
	fb.spawn_enemy_at("fire", 12.5, 11.5)
	var lit := false
	for n in 600:
		fb.update_enemies(1.0 / 60.0)
		fb.update_lobs(1.0 / 60.0)
		fb.update_fires(1.0 / 60.0)
		var w = fb.walls[fb.idx(8, 11)]
		if w != null and w.fire > 0:
			lit = true
			break
	check(lit, "a firebrand sets the wooden wall in his way alight")

	var md := _mk()
	md.new_game(9)
	md.game.phase = "raid"
	var hurt := md.spawn_enemy_at("rifle", 14.5, 2.5)
	hurt.hp = 10.0
	md.spawn_enemy_at("medic", 14.5, 3.5)
	for n in 120:
		md.update_enemies(1.0 / 60.0)
	check(hurt.hp > 10.0, "a field medic patches up the raider next to him (%.1f)" % hurt.hp)

	var spt := _mk()
	spt.new_game(10)
	spt.game.phase = "raid"
	spt.qm.alive = false
	spt.spawn_enemy_at("spotter", 12.5, 13.5)   # clear line of sight (the kiln at 11,11 blocks 11.5)
	for n in 90:
		spt.update_enemies(1.0 / 60.0)
	check(spt.player.markT > 0, "a spotter marks the soldier after 0.8 s in sight")

	print("Delgado")
	var dg := _mk()
	dg.new_game(12)
	for n in 60 * 30:
		dg.update(1.0 / 60.0, {})
	var ring := 0
	for lt in dg.qm_layout():
		if dg.walls[lt.k] != null:
			ring += 1
	check(ring >= 4, "builds the perimeter round the stake in 30 s of build time (%d walls, %s)" % [ring, dg.qm.status])
	var dv := _mk()
	dv.new_game(13)
	dv.player.x = 7.5
	dv.player.y = 11.5
	dv.hurt_player(dv.player, 999)
	var up := false
	for n in 60 * 8:
		dv.update(1.0 / 60.0, {})
		if dv.player.alive:
			up = true
			break
	check(up and dv.game.stats.revives == 1, "walks over and revives the downed soldier")

	print("a whole game, played by the bot with Delgado")
	var full := _mk()
	full.new_game(21)
	var tt := 0.0
	while tt < 1200.0 and full.game.phase != "over":
		var ctl := {}
		var p: Dictionary = full.player
		var best = null
		var bd := 1e9
		for en in full.enemies:
			var d := Vector2(en.x - p.x, en.y - p.y).length()
			if d < bd:
				bd = d
				best = en
		if best != null and bd < 9:
			ctl = {"aim": Vector2(best.x - p.x, best.y - p.y), "fire": true}
		full.update(1.0 / 30.0, ctl)
		tt += 1.0 / 30.0
	var fs: Dictionary = full.game.stats
	print("    %s after raid %d at %.0f s: stake %.0f, dropped %d, walls built %d lost %d, Delgado repairs %d" % ["WON" if full.game.won else ("LOST" if full.game.phase == "over" else "STILL GOING"), full.game.wave, tt, full.core.hp, fs.dropped, fs.built, fs.lost, fs.repairs])
	check(full.game.phase == "over", "the game reaches an end")
	check(fs.dropped >= 10, "raiders were dropped")

	print("determinism: same seed, same inputs, same yard")
	var a := _mk()
	var b := _mk()
	a.new_game(42)
	b.new_game(42)
	a.start_raid()
	b.start_raid()
	for n in 1800:
		a.update(1.0 / 60.0, {})
		b.update(1.0 / 60.0, {})
	check(a.core.hp == b.core.hp and a.enemies.size() == b.enemies.size(), "identical after 30 s (stake %.1f)" % a.core.hp)
	check(a.core.hp < 500.0 or a.player.hp < a.player.max or a.qm.hp < a.qm.max, "undefended, the raid does damage")

	print("")
	print("FAILED %d" % fails if fails else "ALL PASSED")
	for x in sims:
		x.dispose()
	sims.clear()
	quit(1 if fails else 0)
