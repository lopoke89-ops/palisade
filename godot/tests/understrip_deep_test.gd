extends SceneTree
## G3: Shelter 7, Area 67 and the three deeper bosses, headless. Each boss level is started on its own (opts.us_level),
## the squad walks into the arena, the gate closes, the boss wakes, is beaten through his stages, and goes down.
##   godot --headless --path godot --script res://tests/understrip_deep_test.gd
var fails := 0

func check(value: bool, label: String):
	print(("ok " if value else "FAIL ") + label)
	if not value:
		fails += 1

func level(n: int) -> Sim:
	var s := Sim.new()
	s.new_game(1234, "normal", {}, {"mode": "understrip", "us_level": n})
	s.player.hp = 1e6
	s.player.max = 1e6
	return s

## into the arena: the gate closes behind and the boss wakes
func fight(s: Sim) -> Dictionary:
	s.enemies = s.enemies.filter(func(e): return e.type == "boss")
	var A: Dictionary = s.lay.arena
	var p = s.player
	p.x = A.x + A.w / 2.0
	p.y = A.y + A.h - 2.5
	for i in 120:
		p.hp = p.max
		s.update(0.05)
		if s.game.us.gate == 2:
			break
	var B: Array = s.enemies.filter(func(e): return e.type == "boss" and not e.dead)
	return B[0] if not B.is_empty() else {}

## a while of the fight, the player kept alive and standing near the boss, every move allowed to go off
func run(s: Sim, secs: float, e: Dictionary) -> void:
	var p = s.player
	for i in int(secs / 0.05):
		p.hp = p.max
		p.alive = true
		p.downed = false
		if not e.dead and Vector2(p.x - e.x, p.y - e.y).length() > 3.0:
			p.x = e.x + 1.5
			p.y = e.y + 1.0
			if s.solid_tile(int(p.x), int(p.y)):
				p.x = e.x
				p.y = e.y + 0.6
		s.update(0.05)

func _initialize():
	# ---- the layouts
	for n in range(3, 10):
		var s := level(n)
		var reg: int = PalUnderstrip.PLAN[n][0]
		check(s.lay.has("haz") and s.lay.haz.size() == s.N * s.N and s.game.us.has("vents") and s.game.us.has("bfx"), "level %d has its hazard map and clocks" % (n + 1))
		if reg == 2:
			var z := 0
			for k in s.lay.haz.size():
				if s.lay.haz[k] in [UsDeep.HZ_RAD, UsDeep.HZ_GAS, UsDeep.HZ_BLAST]:
					z += 1
			check(z > 0, "Shelter 7 level %d has radiation, vents or blast doors" % (n + 1))
		s.dispose()
	# ---- hazards: radiation hurts, vents leak on their timer
	var s2 := level(3)
	var rad := -1
	for k in s2.lay.haz.size():
		if s2.lay.haz[k] == UsDeep.HZ_RAD:
			rad = k
			break
	if rad >= 0:
		s2.enemies.clear()
		var p2 = s2.player
		p2.hp = 100.0
		p2.max = 100.0
		p2.x = rad % s2.N + 0.5
		p2.y = rad / s2.N + 0.5
		for i in 20:
			p2.x = rad % s2.N + 0.5
			p2.y = rad / s2.N + 0.5
			s2.update(0.05)
		check(p2.hp < 100.0, "the yellow floor is radiation: standing on it hurts")
	else:
		print("(no radiation on level 4 of this seed)")
	if not s2.lay.vents.is_empty():
		var seen := {}
		s2.player.hp = 1e6
		s2.player.max = 1e6
		for i in 600:
			s2.update(0.05)
			seen[int(s2.game.us.vents[0].s)] = true
		check(seen.has(1) and seen.has(2) and seen.has(0), "a gas vent hisses, leaks and goes quiet on its timer")
	s2.dispose()
	# ---- Area 67: drones, low gravity
	var s3 := level(6)
	var drones: Array = s3.enemies.filter(func(e): return e.type == "drone")
	print("level 7 drones waiting: %d" % drones.size())
	s3.enemies.clear()
	UsDeep.drone_pack(s3, s3.player.x + 3, s3.player.y, 4)
	var d0: Dictionary = s3.enemies[0] if not s3.enemies.is_empty() else {}
	check(not d0.is_empty() and d0.type == "drone" and d0.us.st == "hunt", "an alarm's drone pack comes in hunting")
	if not d0.is_empty():
		var far := Vector2(d0.x - s3.player.x, d0.y - s3.player.y).length()
		s3.player.hp = 1e6
		s3.player.max = 1e6
		for i in 20:
			s3.update(0.05)
		check(d0.dead or Vector2(d0.x - s3.player.x, d0.y - s3.player.y).length() < far, "drones fly at you")
		var e2: Dictionary = s3.spawn_enemy_at("drone", s3.player.x + 0.5, s3.player.y)
		e2.hp = 100.0
		s3.player.aim = Vector2(1, 0)
		s3.hurt_enemy(e2, 10.0)
		check(is_equal_approx(e2.hp, 80.0), "a drone in your light takes double damage")
	var grav := -1
	for k in s3.lay.haz.size():
		if s3.lay.haz[k] == UsDeep.HZ_GRAV:
			grav = k
			break
	if grav >= 0:
		check(UsDeep.grav_at(s3, grav % s3.N + 0.5, grav / s3.N + 0.5) == 0.6, "shots slow to 60% over the blue floor")
	s3.dispose()
	# ---- the Custodian
	var c := level(5)
	var cu := fight(c)
	check(not cu.is_empty() and cu.boss == "custodian", "the Custodian wakes as the gate closes")
	if not cu.is_empty():
		check(is_equal_approx(cu.max, 10000.0 * c.Df.hp), "the second boss starts at the former finale's 10,000 HP")
		run(c, 8.0, cu)
		var shut: bool = c.game.us.blast.any(func(b): return b == 2) or c.game.us.blast.size() == 0
		check(shut, "the hall's blast doors slam on their rhythm")
		c.hurt_enemy(cu, cu.hp - cu.max * 0.49, c.player.id)
		run(c, 0.2, cu)
		check(c.game.us.bossStage == 1 and cu.get("inv", 0.0) > 0, "half health: the casing cracks and he can't be hurt for the change")
		var kinds := {}
		for i in 400:
			run(c, 0.05, cu)
			for f in c.game.us.bfx:
				kinds[f.k] = true
		check(kinds.has("gas") and kinds.has("turret"), "stage 2 floods a quarter with gas and the ceiling turret fires (%s)" % ", ".join(kinds.keys()))
		c.hurt_enemy(cu, cu.hp + 1, c.player.id)
		run(c, 0.2, cu)
		check(c.game.us.bossDown and c.game.us.loot.any(func(l): return l.kind == "weapon" and l.w.id == "w_flare"), "the Custodian goes down and leaves his flare launcher")
		check(c.game.us.blast.all(func(b): return b == 0), "the doors stand open after him")
	c.dispose()
	# ---- the Gatekeeper and his pilot
	var g := level(8)
	var gk := fight(g)
	check(not gk.is_empty() and gk.boss == "gatekeeper", "the Gatekeeper wakes")
	if not gk.is_empty():
		run(g, 6.0, gk)
		g.hurt_enemy(gk, gk.hp - gk.max * 0.49, g.player.id)
		run(g, 3.4, gk)
		var pilot: Array = g.enemies.filter(func(e): return e.type == "boss" and e.get("pilot", false))
		check(pilot.size() == 1 and g.game.us.bossStage == 1, "half health: the pilot ejects and runs as a second body")
		if pilot.size() == 1:
			run(g, 6.0, gk)
			g.hurt_enemy(pilot[0], pilot[0].hp + 1, g.player.id)
			run(g, 0.2, gk)
			check(g.game.us.bossDown and gk.dead, "bringing down the pilot ends the fight")
			check(g.game.us.loot.any(func(l): return l.kind == "weapon" and l.w.id == "w_antigrav"), "he leaves the anti-grav launcher")
	g.dispose()
	# ---- the Visitor, and the way out
	var v := level(9)
	var vi := fight(v)
	check(not vi.is_empty() and vi.boss == "visitor", "the Visitor wakes")
	if not vi.is_empty():
		var kinds := {}
		for i in 160:
			run(v, 0.05, vi)
			for f in v.game.us.bfx:
				kinds[f.k] = true
		check(kinds.has("ring"), "psychic rings come off it")
		v.hurt_enemy(vi, vi.hp - vi.max * 0.66, v.player.id)
		for i in 400:
			run(v, 0.05, vi)
			for f in v.game.us.bfx:
				kinds[f.k] = true
		check(v.game.us.bossStage == 1, "top third gone: the field fails")
		check(kinds.has("blink") and kinds.has("well"), "it blinks and pulls with gravity wells (%s)" % ", ".join(kinds.keys()))
		check(v.enemies.any(func(e): return e.type == "drone"), "it calls a drone swarm")
		v.hurt_enemy(vi, vi.hp - vi.max * 0.09, v.player.id)
		run(v, 0.1, vi)
		check(v.game.us.bossStage == 2, "under 10%: desperate")
		v.hurt_enemy(vi, vi.hp + 1, v.player.id)
		run(v, 0.2, vi)
		check(v.game.us.bossDown and not v.enemies.any(func(e): return e.type == "drone" and not e.dead), "the Visitor goes down and its drones drop")
		var p = v.player
		p.x = v.lay.exit[0]
		p.y = v.lay.exit[1]
		v.enemies.clear()
		for i in 70:
			p.hp = p.max
			p.x = v.lay.exit[0]
			p.y = v.lay.exit[1]
			v.update(0.05)
		check(v.game.phase == "over" and v.game.won and v.game.end_reason == "understrip", "the last lift: OUT OF AREA 67")
		var cl := PalLocker.run_claim(v)
		check(cl.mode == "understrip" and cl.cv == 6 and cl.map == "understrip" and cl.raid_to == v.game.us.log.size() and cl.win and cl.boss_keys.is_empty() and cl.shard_bosses == 0,
			"the account claim is the browser's: cv 6, the levels finished (%d), the server counts the regions" % cl.raid_to)
	v.dispose()
	print("PASS understrip_deep" if fails == 0 else "FAIL understrip_deep: %d" % fails)
	quit(0 if fails == 0 else 1)
