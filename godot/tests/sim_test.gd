extends SceneTree
## Headless checks for the ported sim: godot --headless --path godot --script res://tests/sim_test.gd
## Exit code 0 = all passed.

var fails := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		fails += 1


func _init() -> void:
	print("hash parity with the browser (values from node)")
	var ref := [[0, 0, 0], [1, 0, 0.5081244610501743], [0, 1, 0.7682745544631674], [4, 11, 0.28116835986291255], [15, 15, 0.6118243966744804],
		[400, 77, 0.9309408012616776], [-6, -6, 0.18195412777875414], [407, 93, 0.121274691801815], [12345, 678, 0.7270846461707458], [-3, 9, 0.02733767848167049]]
	for r in ref:
		check(absf(Pal.hash2(r[0], r[1]) - r[2]) < 1e-12, "hash(%d,%d) = %f" % [r[0], r[1], r[2]])

	print("new game: the Yard on Normal")
	var s := Sim.new()
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
	var g := Sim.new()
	g.new_game(1)
	g.player.x = 2.5
	g.player.y = 8.3   # beside the wood pile at 2,7
	for n in 60:
		g.update(1.0 / 60.0, {})
	check(g.player.mats[0] > 24, "walking into wood gathers (%d)" % g.player.mats[0])

	print("explosions")
	var e := Sim.new()
	e.new_game(3)
	var rk := e.idx(4, 9)
	var hp0: float = e.walls[rk].hp
	e.explode(4.5, 9.5, 1.65, 1.0, 0)
	check(e.walls[rk] == null, "a grenade on a weakened wood ruin (%.1f hp) knocks it down" % hp0)
	check(e.debris[rk] == 1, "leaves wood debris")
	check(e.walls[e.idx(3, 9)] == null and e.walls[e.idx(5, 9)] == null, "the blast also takes both neighbouring ruins (f=.68 x 80 x 2.2)")
	check(e.player.sal == 15, "three wood ruins pay 5 salvage each (%d)" % e.player.sal)

	print("a raid, played by a simple bot")
	var r := Sim.new()
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

	print("determinism: same seed, same inputs, same yard")
	var a := Sim.new()
	var b := Sim.new()
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
	quit(1 if fails else 0)
