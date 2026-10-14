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
	var k := s.idx(6, 10)   # a new soldier faces up and to the right (0.7, -0.7), so the faced tile is the diagonal
	check(s.walls[k] != null and s.walls[k].mat == 0 and s.walls[k].hp == 60.0, "wood wall raised at 6,10")
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
	var by_bot: int = r.player.kills
	check(r.player.sal == 9 + 4 * by_bot + (3 - by_bot), "8 + raid salvage, 4 per rifleman you drop, 1 each for Delgado's (%d)" % r.player.sal)
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

	print("bosses")
	var bm := _mk()
	bm.new_game(30)
	var w5 := bm.wave_mix(5, 1, 0, true)
	check(w5.rifle == 2 and w5.gren == 4 and w5.breach == 3 and w5.fire == 2 and w5.shield == 1 and w5.medic == 1, "raid 5 mix with a boss matches the browser")
	var w10 := bm.wave_mix(10, 1, 0, true)
	check(w10.rifle == 4 and w10.gren == 9 and w10.breach == 8 and w10.spotter == 1, "raid 10 mix with a boss matches the browser")
	check(bm.boss_of(5) == "butcher" and bm.boss_of(10) == "demolisher" and bm.boss_of(15) == "storm" and bm.boss_of(4) == "", "the Yard's boss order: Butcher, Demolisher, Stormcaller")
	bm.game.wave = 4
	bm.start_raid()
	check(bm.game.queue.has("boss:butcher"), "raid 5 brings the Butcher")
	var bt := _mk()
	bt.new_game(31)
	bt.game.phase = "raid"
	bt.game.wave = 5
	bt.qm.alive = false
	var bu := bt.spawn_boss("butcher")
	check(is_equal_approx(bu.hp, 760.0 * 1.25), "the Butcher has 950 health on Normal")
	bu.x = 9.5
	bu.y = 11.5
	bu.ab = 0.0   # charge ready (he spawns with 3 s on it)
	var charged := false
	var php0: float = bt.player.hp
	for n in 60 * 6:
		bt.update_enemies(1.0 / 60.0)
		if bu.st == 3:
			charged = true
		if bt.player.hp < php0:
			break
	check(charged, "he charges down a red lane from range")
	check(bt.player.hp < php0, "and it lands (%.0f health left)" % bt.player.hp)
	var dm := _mk()
	dm.new_game(32)
	dm.game.phase = "raid"
	dm.qm.alive = false
	var de := dm.spawn_boss("demolisher")
	de.x = 12.5
	de.y = 11.5
	var fired := false
	for n in 60 * 5:
		dm.update_enemies(1.0 / 60.0)
		dm.update_rockets(1.0 / 60.0)
		if not dm.rockets.is_empty():
			fired = true
	check(fired, "the Demolisher fires rockets after his red line")
	var sm := _mk()
	sm.new_game(33)
	sm.game.phase = "raid"
	var se2 := sm.spawn_boss("storm")
	se2.x = 12.5
	se2.y = 13.5
	sm.player.hp = 115.0
	sm.qm.x = 6.5
	sm.qm.y = 12.0
	var zapped := false
	for n in 60 * 5:
		sm.update_enemies(1.0 / 60.0)
		if sm.player.stun > 0:
			zapped = true
			break
		sm.player.stun = maxf(0.0, sm.player.stun - 1.0 / 60.0)
	check(zapped, "the Stormcaller's bolt hits and stuns")
	var bds := _mk()
	bds.new_game(34)
	bds.game.phase = "raid"
	var bb := bds.spawn_boss("butcher")
	bds.hurt_enemy(bb, 9999.0, bds.player.id)
	check(bds.player.sal == 40, "landing the kill on a boss pays 40 salvage")

	print("every other boss: each one fights, using its own moves")
	for key in Sim.BOSS_LIST:
		if key.ends_with("ferryman"):   # river bosses: tested on Riverbend below
			continue
		var bs := _mk()
		bs.new_game(60 + Sim.BOSS_LIST.find(key))
		bs.game.phase = "raid"
		bs.game.wave = 5
		bs.player.x = 6.5
		bs.player.y = 13.5
		var bo := bs.spawn_boss(key)
		bo.x = 12.5
		bo.y = 12.5
		var seen := {}
		var hurt0: float = bs.player.hp + bs.qm.hp + bs.core.hp
		var extra := {"arcs": false, "napalm": false, "missile": false, "frost": false, "gas": false, "mines": false, "slab": false, "burrow": false}
		var t_end := 0.0
		for n in 60 * 30:
			bs.player.hp = bs.player.max   # keep the soldier up so the boss keeps working
			bs.player.alive = true
			bs.player.downed = false
			# the soldier keeps moving in and out (2 to 7 tiles), so melee and ranged moves both come up
			var want_d := 4.5 + 2.5 * sin(t_end * 0.8)
			var nx := clampf(bo.x - 0.96 * want_d, 0.5, 15.5)
			var ny := clampf(bo.y + 0.28 * want_d, 0.5, 15.5)
			if not bs.collides(nx, ny, 0.27, true):
				bs.player.x = nx
				bs.player.y = ny
			bs.update(1.0 / 60.0, {})
			t_end += 1.0 / 60.0
			seen[bo.st] = true
			if not bs.arcs.is_empty(): extra.arcs = true
			if bo.get("burrow", false): extra.burrow = true
			if not bs.frost_fields.is_empty(): extra.frost = true
			for l in bs.lobs:
				if l.get("k", 0) == 3: extra.missile = true
			for f in bs.fires:
				match f.get("nap", 0):
					1: extra.napalm = true
					2: extra.gas = true
					3: extra.mines = true
			for w in bs.walls:
				if w != null and w.get("slab", false): extra.slab = true
			if bo.dead or bs.game.phase == "over":
				break
		var states: Array = seen.keys()
		states.sort()
		var want: Array = {"butcher": [1, 2], "demolisher": [1], "storm": [1, 20, 21], "foreman": [1, 2, 4], "bluebutcher": [5], "arsonist": [1], "tempest": [1], "bulldozer": [1, 2], "harbinger": [1], "rime": [101], "whitebutcher": [101], "whiteforeman": [101], "destroyer": [40, 41, 44, 45]}[key]
		var missing: Array = want.filter(func(st): return not seen.has(st))
		var sign_ok := true
		match key:
			"foreman": sign_ok = extra.burrow and extra.slab
			"bluebutcher", "whitebutcher": sign_ok = extra.arcs
			"arsonist": sign_ok = extra.napalm
			"harbinger": sign_ok = extra.missile
			"destroyer": sign_ok = extra.gas and extra.mines
		check(missing.is_empty() and sign_ok, "%s: warnings/attacks seen %s%s" % [key, str(states), "" if missing.is_empty() else " · MISSING " + str(missing)])
	var rf := _mk()
	rf.new_game(80)
	rf.game.phase = "raid"
	rf.add_frost(8.5, 11.5)
	check(is_equal_approx(rf.slow_at(8.5, 11.5), 0.7) and rf.slow_at(2.5, 2.5) == 1.0, "the Rime Colossus's frost slows movement to 70%")
	var fb2 := _mk()
	fb2.new_game(81)
	fb2.game.phase = "raid"
	var fo := fb2.spawn_boss("foreman")
	fo.burrow = true
	fo.x = 8.5
	fo.y = 11.5
	var fhp: float = fo.hp
	fb2.fire(fb2.player, 0.0, 0, {"dmg": 20.0, "speed": 22.0, "range": 11.0})
	for n in 20:
		fb2.update_bullets(1.0 / 60.0)
	check(fo.hp == fhp, "the Foreman underground can't be shot")

	print("skill tree")
	var pr := PalProfile.new()
	pr.persist = false
	check(pr.award_run(7, 1) == 2 and pr.sp_prog == 2 and pr.sp == 2, "7 raids held and a boss: 2 points, 2 raids carried toward the next")
	check(pr.award_run(3, 0) == 1 and pr.sp_prog == 0, "3 more raids complete the next point")
	check(pr.block_reason("ammo_ap") == "5 lifetime SP", "ammo tiers are gated by lifetime points (5, 10, 15, 20)")
	pr.sp_total = 5
	check(pr.buy("ammo_ap") and pr.level("ammo_ap") == 1, "rank 1 armor piercing once 5 points have been earned")
	check(pr.block_reason("molotov") == "Needs EXTRA POUCH", "Molotovs need Extra Pouch first")
	pr.sp = 20
	pr.buy("dmg")
	pr.buy("dmg")
	pr.buy("hp")
	pr.buy("rockets")
	pr.buy("vest")
	check(pr.level("dmg") == 2 and pr.sp == 20 - 3 - 1 - 1 - 2, "point costs follow the tree (Hot Loads 1 then 2)")
	var sk := _mk()
	sk.new_game(82, "normal", pr.perk_mods())
	check(is_equal_approx(sk.player.gun.dmg, 12.0 * 1.08) and sk.player.max == roundf(115 * 1.06) and sk.player.rk == 6, "perks: +8% damage, +6% health, +1 rocket")
	var hp_before: float = sk.player.hp
	sk.hurt_player(sk.player, 10.0)
	check(is_equal_approx(hp_before - sk.player.hp, 9.6), "Kevlar 1: 4% less damage taken")
	pr.skills["ammo_ap"] = 4
	var ap := _mk()
	ap.new_game(83, "normal", pr.perk_mods())
	ap.game.phase = "raid"
	ap.player.ammoEq[0] = "ap"
	var sb := ap.spawn_enemy_at("shield", 9.5, 11.5)
	sb.aim = Vector2(-1, 0)
	var shp: float = sb.hp
	ap.player.aim = Vector2(1, 0)
	ap.shoot(ap.player, {"spread": 0.0, "dmg": 10.0, "speed": 22.0, "range": 11.0}, 0.0)
	for n in 20:
		ap.update_bullets(1.0 / 60.0)
	check(is_equal_approx(shp - sb.hp, 10.0), "armor piercing rank 4: full damage through a riot shield")
	pr.respec()
	check(pr.skills.is_empty() and pr.sp == 30, "reset hands every point back (13 unspent + 17 spent)")

	print("classes")
	var cs := _mk()
	cs.new_game(90, "normal", {}, {"cls": "sniper"})
	var sn: Dictionary = cs.player
	check(sn.max == 90.0 and is_equal_approx(sn.gun.dmg, 47.0) and sn.rk == 0, "Sniper: 90 health, 47-damage bolt, no rockets")
	cs.game.phase = "raid"
	sn.aim = Vector2(1, 0)
	var shots := 0
	for n in 60 * 3:
		var before := cs.bullets.size()
		cs.update(1.0 / 60.0, {"aim": Vector2(1, 0), "fire": true, "pulls": 0})
		if cs.bullets.size() > before:
			shots += 1
	check(shots >= 4 and shots <= 5, "the bolt fires every 0.7 s while held (%d in 3 s)" % shots)
	var pw := _mk()
	pw.new_game(91, "normal", {}, {"cls": "sniper"})
	pw.game.phase = "raid"
	pw.walls[pw.idx(8, 11)] = Pal.make_wall(0, false)   # not the adjacent tile: shots go over a wall right next to you
	var tgt := pw.spawn_enemy_at("rifle", 9.5, 11.5)
	tgt.hp = 999.0
	pw.player.aim = Vector2(1, 0)
	pw.shoot(pw.player, {"spread": 0.0, "dmg": 47.0, "speed": 34.0, "range": 16.0, "pierce": 2}, 0.0)
	for n in 30:
		pw.update_bullets(1.0 / 60.0)
	check(tgt.hp < 999.0 and absf((999.0 - tgt.hp) - 47.0 * 0.8) < 0.01, "a sniper round goes through a wood wall and hits for 80%% (%.1f)" % (999.0 - tgt.hp))
	var gr := _mk()
	gr.new_game(92, "normal", {}, {"cls": "grenadier"})
	gr.game.phase = "raid"
	check(gr.player.nades == 3 and gr.player.ammo == 6, "Grenadier: 3 grenades, 6 shells")
	var before_b := gr.bullets.size()
	gr.update(1.0 / 60.0, {"aim": Vector2(1, 0), "fire": true, "pulls": 0})
	check(gr.bullets.size() - before_b == 7, "the pump throws 7 pellets")
	for n in 60 * 4:
		gr.update(1.0 / 60.0, {"aim": Vector2(1, 0), "fire": true, "pulls": 0})
	check(gr.player.ammo <= 1, "holding the trigger empties the tube (%d left)" % gr.player.ammo)
	for n in 60 * 4:
		gr.update(1.0 / 60.0, {"aim": Vector2(1, 0), "fire": false, "pulls": 0})
	check(gr.player.ammo == 6, "and it loads back one shell at a time, 0.42 s each (6 after 4 s)")
	var qmc := _mk()
	qmc.new_game(93, "normal", {}, {"cls": "quartermaster"})
	check(qmc.player.cap[0] == 96 and qmc.core_fix_cost(qmc.player) == 13, "Quartermaster: packs of 96, stake repair for 13")
	qmc.local_sprint()
	var x0: float = qmc.player.x
	qmc.player.y = 3.5
	qmc.player.x = 2.5
	x0 = qmc.player.x
	for n in 60:
		qmc.update(1.0 / 60.0, {"move": Vector2(1, 0), "fire": true})
	check(absf((qmc.player.x - x0) - 3.3 * 1.4) < 0.15 and qmc.bullets.is_empty(), "sprint: 1.4x speed and no shooting (%.2f tiles in 1 s)" % (qmc.player.x - x0))
	qmc.qm.alive = false
	qmc.qm.x = qmc.player.x + 0.3
	qmc.qm.y = qmc.player.y
	qmc.update(1.0 / 60.0, {})
	check(qmc.qm.alive, "touching Delgado gets him straight up")
	var st := _mk()
	st.new_game(94, "normal", {}, {"cls": "sniper"})
	st.game.phase = "raid"
	st.qm.alive = false
	var ri := st.spawn_enemy_at("rifle", 10.5, 11.5)
	for n in 30:
		st.update_enemies(1.0 / 60.0)
	check(ri.foe != null, "a rifleman sees the sniper")
	st.use_ability(st.player, 0, 0)
	for n in 30:
		st.update_enemies(1.0 / 60.0)
	check(ri.foe == null and st.player.stl > 11, "stealth (Q): raiders lose him for 12 s")
	var mp := PalProfile.new()
	mp.persist = false
	mp.skills = {"pouch": 1, "molotov": 1}
	var ml := _mk()
	ml.new_game(95, "normal", mp.perk_mods(), {"cls": "grenadier"})
	ml.game.phase = "raid"
	check(ml.player.maxN == 4, "Extra Pouch: a 4th grenade")
	ml.throw_nade(ml.player, 9.5, 11.5)
	for n in 60:
		ml.update_lobs(1.0 / 60.0)
	check(ml.fires.any(func(f): return f.get("pl", false)), "Molotovs: the grenade leaves burning ground")

	_maps_and_modes()

	print("armory")
	var ar := _mk()
	ar.new_game(40)
	ar.player.sal = 5000
	check(ar.buy_upgrade(ar.player, "d") and is_equal_approx(ar.player.gun.dmg, 14.4) and ar.player.sal == 4980, "DAMAGE 1: 12 -> 14.4 for 20 salvage")
	check(Pal.burst_n(ar.player.up_d) == 5, "and the burst grows to 5 rounds")
	ar.buy_upgrade(ar.player, "r")
	check(is_equal_approx(ar.player.gun.cd, 0.081), "FIRE RATE 1: 0.09 -> 0.081")
	ar.buy_upgrade(ar.player, "g")
	check(is_equal_approx(ar.player.gun.range, 12.32) and is_equal_approx(ar.player.gun.speed, 24.2), "RANGE 1: 11 -> 12.32 tiles, 22 -> 24.2 speed")
	ar.buy_upgrade(ar.player, "a")
	check(ar.player.max == 132.0 and ar.player.hp == 132.0, "ARMOR 1: 115 -> 132 health")
	ar.buy_upgrade(ar.player, "n")
	check(ar.player.maxN == 3 and ar.player.nades == 3 and is_equal_approx(ar.player.blast, 1.08), "GRENADES 1: 3 grenades, blast x1.08")
	for n in 7:
		ar.buy_upgrade(ar.player, "d")
	check(ar.player.up.d == 8 and is_equal_approx(ar.player.gun.dmg, 24.0) and not ar.buy_upgrade(ar.player, "d"), "DAMAGE 8 is +100% and the cap")
	check(ar.buy_upgrade(ar.player, "dell") and ar.dell_gun().dmg > 6.0, "Delgado level 1: his shotgun hits harder")
	ar.core.hp = 400.0
	var sal0: int = ar.player.sal
	check(ar.buy_upgrade(ar.player, "core") and ar.core.hp == 450.0 and ar.player.sal == sal0 - 25, "stake repair: +50 for 25")
	check(ar.buy_ammo(ar.player, "shock") and ar.player.ammoEq[0] == "shock", "lightning rounds")
	ar.player.x = 12.5
	check(not ar.buy_upgrade(ar.player, "r"), "away from the stake: nothing for sale")
	ar.player.x = 5.5
	ar.game.phase = "raid"
	check(not ar.buy_upgrade(ar.player, "r"), "during a raid: nothing for sale")
	var am := _mk()
	am.new_game(41)
	am.game.phase = "raid"
	am.player.ammoEq[0] = "shock"
	am.player.aim = Vector2(1, 0)
	var t1 := am.spawn_enemy_at("rifle", 8.5, 11.5)
	var t2 := am.spawn_enemy_at("rifle", 9.0, 12.5)
	am.shoot(am.player, {"spread": 0.0, "dmg": 1.0, "speed": 22.0, "range": 11.0}, 0.0)
	for n in 20:
		am.update_bullets(1.0 / 60.0)
	check(t1.get("slowT", 0.0) > 0 and t2.get("slowT", 0.0) > 0, "lightning rounds slow the target and the raider next to him")
	am.player.ammoEq[0] = "fire"
	var t3 := am.spawn_enemy_at("rifle", 8.5, 10.5)
	am.player.aim = Vector2(3.0, -1.0).normalized()
	am.shoot(am.player, {"spread": 0.0, "dmg": 1.0, "speed": 22.0, "range": 11.0}, 0.0)
	for n in 20:
		am.update_bullets(1.0 / 60.0)
	var h3: float = t3.hp
	for n in 60:
		am.update_enemies(1.0 / 60.0)
	check(t3.get("burnT", 0.0) >= 0 and t3.hp < h3 - 5, "incendiary rounds burn (%.1f health lost in 1 s)" % (h3 - t3.hp))
	var kb := _mk()
	kb.new_game(42)
	kb.game.phase = "raid"
	var kr := kb.spawn_enemy_at("rifle", 8.5, 11.5)
	kb.hurt_enemy(kr, 999.0, kb.player.id)
	check(kb.player.sal == 4 and kb.player.kills == 1, "a rifleman pays 4 salvage")
	var rkt := _mk()
	rkt.new_game(43)
	rkt.game.phase = "raid"
	var rt := rkt.spawn_enemy_at("gren", 10.5, 11.5)
	rkt.use_rocket(rkt.player, 10.5, 11.5)
	for n in 60:
		rkt.update_rockets(1.0 / 60.0)
	check(rt.dead and rkt.player.rk == 4, "a rocket (Q) drops a grenadier; 4 left")

	print("Delgado")
	var dg := _mk()
	dg.new_game(12)
	dg.set_qm_mode("")   # defend: he builds the ring round the stake (he starts on follow, as in the browser)
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

	_games_on_every_map()

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
			if best.type == "boss" and p.rk > 0 and p.rkCd <= 0:
				full.use_rocket(p, best.x, best.y)
		if full.game.phase == "build":
			for uk in ["d", "a", "r", "core", "dell", "g", "n"]:
				full.buy_upgrade(p, uk)
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


func _maps_and_modes() -> void:
	print("maps: every map and size laid out tile for tile as the browser does (tests/maps_ref.json, from tools/maps_ref.js)")
	var mref = JSON.parse_string(FileAccess.get_file_as_string("res://tests/maps_ref.json"))
	for key in mref:
		var r: Dictionary = mref[key]
		var parts: PackedStringArray = key.split("_")
		var L := PalMaps.lay(parts[0], parts[1])
		var ts := ""
		var hs := ""
		var cs := ""
		for k in L.N * L.N:
			ts += str(L.terr[k])
			hs += str(L.heights[k])
			cs += str(L.connectors[k])
		var nodes_ok: bool = L.nodes.size() == r.nodes.size()
		if nodes_ok:
			for n in L.nodes.size():
				var a: Dictionary = L.nodes[n]
				var b: Array = r.nodes[n]
				if a.i != int(b[0]) or a.j != int(b[1]) or a.type != int(b[2]) or (a.unlock if a.locked else 0) != int(b[3]):
					nodes_ok = false
		var spawns_ok: bool = L.spawns.size() == r.spawns.size()
		for n in mini(L.spawns.size(), r.spawns.size()):
			if L.spawns[n].tiles.size() != int(r.spawns[n][1]) or absf(L.spawns[n].w - r.spawns[n][0]) > 1e-9:
				spawns_ok = false
		check(ts == r.terr and hs == r.heights and cs == r.conn and L.core[0] == int(r.core[0]) and L.core[1] == int(r.core[1]) and nodes_ok and spawns_ok and L.bossAt.size() == int(r.bossAt) and L.raftAt.size() == int(r.raftAt),
			"%s: terrain, heights, stake, piles, spawns and boss spots match" % key)
	for key in mref:
		var parts: PackedStringArray = key.split("_")
		var ms := _mk()
		ms.new_game(100, "normal", {}, {"map": parts[0], "size": parts[1]})
		var reach := true
		for g in ms.lay.spawns:
			for t in g.tiles:
				if not ms.solid_tile(t[0], t[1], false) and ms.dist[ms.idx(t[0], t[1])] >= 1e6:
					reach = false
		check(reach and not ms.collides(ms.player.x, ms.player.y, 0.27, true), "%s: every spawn tile has a path to the stake; the soldier starts on open ground" % key)
	var fp := _mk()
	fp.new_game(101, "normal", {}, {"map": "frost"})
	check(fp.height_at(3.5, 2.5) == 2.0 and fp.height_at(3.5, 12.5) == 0.0 and not fp.height_link(1, 4, 1, 5) and fp.height_link(4, 4, 4, 5), "Frostpeak: three terraces, cliffs between them, a lane of stairs or ramp joins them")
	var rv := _mk()
	rv.new_game(102, "normal", {}, {"map": "river"})
	var wk := -1
	for k in rv.N * rv.N:
		if rv.terr[k] == PalMaps.T_WATER:
			wk = k
			break
	check(is_equal_approx(rv.slow_at(wk % 16 + 0.5, wk / 16 + 0.5), 0.5) and rv.build_eval(rv.player, wk % 16, wk / 16, 0, false).reason == "Can't build on water", "Riverbend: wading is half speed, and you can't build on water")
	rv.game.wave = 3
	rv.game.phase = "raid"
	for n in 60 * 15:
		rv.update_flood(1.0 / 60.0)
	check(rv.flood_on, "from raid 3 the low banks flood after 14 s")
	var fy := _mk()
	fy.new_game(103, "normal", {}, {"map": "river"})
	fy.game.phase = "raid"
	var fe := fy.spawn_boss("ferryman")
	check(fe.boss == "ferryman" and fe.get("raft", false) and fy.terr[fy.idx(int(fe.x), int(fe.y))] == PalMaps.T_WATER, "the Ferryman comes down the river on his raft")
	var seen_h := false
	var crews := 0
	for n in 60 * 25:
		fy.player.hp = fy.player.max
		fy.update(1.0 / 60.0, {})
		if fe.st == 1:
			seen_h = true
		crews = maxi(crews, fe.get("crews", 0))
		if fe.dead:
			break
	check(seen_h and crews >= 1, "he harpoons and puts a boarding crew ashore")
	var qp := _mk()
	qp.new_game(104, "normal", {}, {"map": "quarry"})
	var ck := -1
	for k in qp.N * qp.N:
		if qp.terr[k] == PalMaps.T_CRACK:
			ck = k
			break
	qp.explode(ck % 16 + 0.5, ck / 16 + 0.5, 1.7, 1.3)
	check(qp.terr[ck] == PalMaps.T_PIT, "Quarry: a heavy blast breaks cracked ground into a pit")
	var xl := _mk()
	xl.new_game(105, "normal", {}, {"size": "xl"})
	check(xl.N == 24 and xl.core.i == 6 and xl.core.j == 17, "XL: 24x24, the yard two tiles in from the south-west corner")

	print("modes and modifiers")
	var md5 := _mk()
	md5.new_game(110)
	check(md5.tod_stage(3) == 1 and md5.tod_stage(5) == 2 and md5.tod_stage(2) == 0, "5 raids: raids 3-4 at golden hour, raid 5 at night")
	var en := _mk()
	en.new_game(111, "normal", {}, {"mode": "endless"})
	en.game.wave = 3
	check(is_inf(en.game.waves) and is_equal_approx(en.wave_eff(), 2.1) and en.tod_stage(6) == 2, "Endless: no last raid, raids climb 0.55 a time, day and night cycle")
	var hd := _mk()
	hd.new_game(112, "hard")
	check(hd.core.max == 420.0 and is_equal_approx(hd.game.timer, 34.0), "Hard: a 420-health stake and 34 s to build")
	var el := _mk()
	el.new_game(113, "normal", {}, {"mods": ["elite"]})
	var W := el.mod_wave_mix(el.wave_mix(1, 1, 0), 1)
	check(W.rifle == 0 and W.shield + W.gren + W.fire >= 3, "Elite Raid: no riflemen")
	var al := _mk()
	al.new_game(114, "normal", {}, {"mods": ["alone"]})
	check(not al.qm.alive and al.allies().size() == 1, "On Your Own: no Delgado")
	var np := _mk()
	np.new_game(115, "normal", {}, {"mods": ["nopatch", "laststand"]})
	np.player.sal = 100
	np.core.hp = 300.0
	check(not np.repair_core(np.player), "No Patch-Ups: no stake repair")
	np.game.phase = "raid"
	np.hurt_player(np.player, 999)
	check(np.player.rt >= 1e6, "Last Stand: down until the raid is broken")
	var bz := _mk()
	bz.new_game(116, "normal", {}, {"mode": "blitz"})
	check(bz.game.waves == 15 and bz.boss_of(5) == "bluebutcher" and bz.boss_of(10) == "arsonist" and bz.boss_of(15) == "", "Blitzkrieg Rush: 15 raids, the Blue Butcher on 5, the Arsonist on 10")
	bz.game.wave = 14
	bz.start_raid()
	check(bz.game.fb != null and is_equal_approx(bz.game.fb.t, 300.0), "raid 15 is the Final Blitz: five minutes")
	bz.qm.alive = false
	bz.qm.gone = true
	for n in 60 * 241:
		bz.player.hp = bz.player.max
		bz.core.hp = bz.core.max   # nobody's defending in this test: keep the stake up so the clock runs out
		bz.update(1.0 / 60.0, {})
	check(bz.game.fb.evac != null and bz.live_bosses() >= 1, "bosses keep coming, and with a minute left the evac opens")
	if bz.game.fb.evac == null:
		return
	bz.player.x = bz.game.fb.evac.x
	bz.player.y = bz.game.fb.evac.y
	for n in 60 * 4:
		bz.player.hp = bz.player.max
		bz.update(1.0 / 60.0, {})
	check(bz.game.phase == "over" and bz.game.won and bz.game.end_reason == "evac", "3 s in the green ring gets you out: victory")


func _games_on_every_map() -> void:
	print("whole games on every map, played by the bot")
	for mp in [["river", "std"], ["quarry", "std"], ["frost", "std"], ["yard", "xl"]]:
		var gm := _mk()
		gm.new_game(130, "normal", {}, {"map": mp[0], "size": mp[1]})
		var tt2 := 0.0
		while tt2 < 900.0 and gm.game.phase != "over":
			var ctl2 := {}
			var p2: Dictionary = gm.player
			var best2 = null
			var bd2 := 1e9
			for en2 in gm.enemies:
				var d := Vector2(en2.x - p2.x, en2.y - p2.y).length()
				if d < bd2 and not en2.get("burrow", false):
					bd2 = d
					best2 = en2
			if best2 != null and bd2 < 9:
				ctl2 = {"aim": Vector2(best2.x - p2.x, best2.y - p2.y), "fire": true}
				if best2.type == "boss" and p2.rk > 0 and p2.rkCd <= 0:
					gm.use_rocket(p2, best2.x, best2.y)
			if gm.game.phase == "build":
				for uk2 in ["d", "a", "r", "core", "dell", "g", "n"]:
					gm.buy_upgrade(p2, uk2)
			gm.update(1.0 / 20.0, ctl2)
			tt2 += 1.0 / 20.0
		print("    %s %s: %s after raid %d at %.0f s, stake %.0f, dropped %d" % [mp[0], mp[1], "WON" if gm.game.won else ("LOST" if gm.game.phase == "over" else "STILL GOING"), gm.game.wave, tt2, gm.core.hp, gm.game.stats.dropped])
		check(gm.game.phase == "over" and gm.game.stats.dropped >= 10, "%s %s: the game runs to an end" % [mp[0], mp[1]])
