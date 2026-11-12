extends SceneTree
var failures=0
func check(value: bool,label: String):
	print(("ok " if value else "FAIL ")+label)
	if not value: failures+=1
func setup(seed: int=1234, difficulty: String="normal") -> Sim:
	var s=Sim.new()
	s.new_game(1234,difficulty,{},{"mode":"understrip","us_seed":seed,"us_level":9})
	s.enemies.clear()
	var a=s.lay.arena
	s.player.x=a.x+a.w/2.0
	s.player.y=a.y+a.h/2.0
	s.player.hp=1e7
	s.player.max=1e7
	UsDeep.wake(s)
	s.game.us.gate=2
	return s
func _initialize():
	var args=OS.get_cmdline_user_args()
	var fixture_path=args[0] if not args.is_empty() else "res://tests/understrip_visitor_seeds.json"
	var fixture=JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	var seeds={}
	var matches=true
	for row in fixture:
		matches=matches and UsDeep.add_key(int(row[0]))==row[1]
		seeds[row[1]]=int(row[0])
	check(matches,"259 summon choices match the browser, including unsigned seed boundaries")
	check(seeds.size()==8,"all eight eligible bosses appear in the seed fixture")
	for key in seeds:
		var s=setup(seeds[key])
		var v=s.enemies[0]
		check(v.boss=="visitor" and is_equal_approx(v.max,62500),"%s seed keeps the Visitor finale" % key)
		v.hp=v.max*.8
		UsDeep.think_visitor(s,v,.05)
		check(s.game.us.bossStage==0 and s.enemies.size()==1,"no summon before the first third is gone")
		v.hp=v.max*.66
		UsDeep.think_visitor(s,v,.05)
		check(v.st==82 and is_equal_approx(v.hp/v.max,2.0/3.0) and is_equal_approx(UsDeep.boss_frac(s,v),1),"two-thirds transition and stage-two bar")
		UsDeep.think_visitor(s,v,2.9)
		check(s.enemies.size()==1,"summon waits until the transition ends")
		UsDeep.think_visitor(s,v,.2)
		var add=s.enemies.filter(func(e): return e.get("usAdd",false))[0]
		var b=Sim.boss_def(key)
		check(add.boss==key and is_equal_approx(add.max,b.hp*Sim.BOSS_HP*2) and is_equal_approx(add.speed,b.speed*2) and add.us.st=="hunt","%s summon has matching doubled health/speed and hunts players" % key)
		UsDeep.visitor_add(s,v)
		check(s.enemies.filter(func(e): return e.get("usAdd",false)).size()==1,"a Visitor summons only once")
		add.hp=add.max*.5
		check(is_equal_approx(UsDeep.boss_frac(s,add),.5),"support bar uses its full health")
		add.hp=add.max
		if key=="demolisher":
			var damage_before=s.Df.dmg
			add.st=1
			add.stT=.001
			add.lx=s.player.x
			add.ly=s.player.y
			s._enemy_tick(add,.02)
			check(s.rockets.any(func(r): return is_equal_approx(r.pw,2.3*s.Df.dmg)),"summon rocket deals double damage")
			check(is_equal_approx(s.Df.dmg,damage_before),"summon damage cannot change global difficulty")
		if key=="butcher":
			add.hp=add.max*.3
			s._enemy_tick(add,.02)
			check(is_equal_approx(add.speed,b.speed*1.25*2),"enraged support keeps doubled speed")
		var sal=s.player.sal
		var credit=s.game.bossLog.size()
		s.hurt_enemy(add,1e9,s.player.id)
		check(s.player.sal==sal and s.game.bossLog.size()==credit,"support death grants no salvage or boss credit")
		UsDeep.boss_tick(s,.01)
		check(not s.game.us.bossDown,"support death cannot finish the encounter")
		s.dispose()
		s=setup(seeds[key])
		v=s.enemies[0]
		v.hp=v.max*.66
		UsDeep.think_visitor(s,v,.05)
		UsDeep.think_visitor(s,v,3.1)
		add=s.enemies.filter(func(e): return e.get("usAdd",false))[0]
		v.inv=0
		s.hurt_enemy(v,1e9,s.player.id)
		for i in 3: s.update(.05,{})
		check(add.dead and s.game.us.bossDown and s.game.us.loot.any(func(l): return l.kind=="relic" and l.k=="x_eye"),"Visitor death removes %s and preserves the final reward" % key)
		s.player.x=s.lay.exit[0]
		s.player.y=s.lay.exit[1]
		for i in 65: s.update(.05,{})
		check(s.game.won,"final lift still completes the run")
		s.dispose()
	for difficulty in ["easy","normal","hard"]:
		var s=setup(7,difficulty)
		check(is_equal_approx(s.enemies[0].max,62500*s.Df.hp),"Visitor health scales on "+difficulty)
		var other=s.make_player("friend","soldier",1)
		SimUnderstrip.kit_out(other)
		s.players[other.id]=other
		UsDeep.visitor_add(s,s.enemies[0])
		var add=s.enemies[1]
		check(is_equal_approx(add.max,Sim.boss_def(add.boss).hp*Sim.BOSS_HP*s.Df.hp*1.35*2),"summon health scales for difficulty and two players")
		s.dispose()
	print("PASS understrip_visitor" if failures==0 else "FAIL understrip_visitor")
	quit(1 if failures else 0)
