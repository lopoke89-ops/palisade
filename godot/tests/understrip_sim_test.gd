extends SceneTree
var fails=0
func check(value: bool, label: String):
	print(("ok " if value else "FAIL ")+label)
	if not value: fails+=1
func _initialize():
	var s=Sim.new()
	s.new_game(1234,"normal",{}, {"mode":"understrip"})
	var p=s.player
	check(s.understrip() and s.N==56 and s.game.phase=="raid","generated crawl starts in raid phase")
	check(s.cores.is_empty() and s.qm.gone and not s.qm.alive,"no stake or Delgado")
	check(p.x==s.lay.starts[0][0] and p.y==s.lay.starts[0][1] and not s.collides(p.x,p.y,.27,true),"player starts on generated floor")
	check(not s.build_eval(p,int(p.x),int(p.y),0,false).ok,"normal construction is disabled")
	check(not s.enemies.is_empty() and s.enemies.size()<=40,"seeded waiting raiders populate tunnels")
	check(s.enemies.all(func(e): return e.us.st in ["idle","ambush"]),"raiders wait rather than marching to a nonexistent stake")
	s.enemies.clear()
	p.hp=p.max*.25
	var hp=p.hp
	for i in 120: s.update(.05)
	check(p.hp==hp and s.game.phase=="raid","no passive healing or automatic raid completion")
	check(s.us.drink(p) and p.uj==2,"Lucky Juice consumes one charge")
	check(not s.us.drink(p),"cannot stack drinks")
	for i in 17: s.update(.05)
	check(is_equal_approx(p.hp,hp+p.max*.45),"juice heals 45 percent after drinking finishes")
	var shrine=s.lay.shrines[0]
	p.x=shrine.x
	p.y=shrine.y
	check(s.us.rest(p,0) and p.hp==p.max and p.uj==3 and s.game.us.rest.ix==0,"shrine heals, refills and sets checkpoint")
	check(not s.enemies.is_empty(),"rest respawns raiders")
	s.enemies.clear()
	p.x=s.lay.starts[0][0]
	p.y=s.lay.starts[0][1]
	p.sal=60
	s.hurt_player(p,100000)
	check(not p.alive and p.downed,"lethal damage downs the player")
	for i in 54: s.update(.05)
	check(p.alive and s.game.us.lives==2 and p.hp==p.max and p.uj==3,"squad wipe spends one shared life and restores checkpoint")
	check(s.game.us.drops.size()==1 and p.sal==0,"salvage remains where the player fell")
	s.enemies.clear()
	var drop=s.game.us.drops[0]
	p.x=drop.x
	p.y=drop.y
	s.update(.05)
	check(p.sal==60 and s.game.us.drops.is_empty(),"owner recovers dropped salvage")
	p.x=s.lay.exit[0]
	p.y=s.lay.exit[1]
	for i in 61: s.update(.05)
	check(s.game.us.lift>0 and s.game.us.level==0,"lift requires three seconds in its ring")
	var lg=s.game.us.log
	check(lg.size()==1 and lg[0][0]==0 and lg[0][2]>0 and lg[0].size()==4,"the lift logs the level: its number, raiders, time and finds (the results card and rewards read it)")
	check(UsView3D.tag_of(1)==2 and UsView3D.tag_of(65535)==1 and UsView3D.tag_of(0)==0,"the Flood Tunnels' graffiti picks the browser's walls")
	for i in 102: s.update(.05)
	check(s.game.us.level==1 and s.game.us.lift<=0 and s.N==56,"lift changes map after its five-second ride")
	check(p.sal==60 and p.uj==3 and p.x==s.lay.starts[0][0],"level transition retains kit and moves player to generated start")
	s.enemies.clear()
	s.game.us.lives=0
	s.hurt_player(p,100000)
	for i in 54: s.update(.05)
	check(s.game.phase=="over" and not s.game.won and s.game.end_reason=="understrip-lost","exhausted lives end the crawl")
	s.new_game(1234,"normal",{}, {"mode":"understrip","us_level":2})
	p=s.player
	s.enemies.clear()
	var at=s.lay.bossAt[0]
	p.x=at[0]+.5
	p.y=at[1]+.5
	s.update(.05)
	check(s.game.us.bossSpawned and s.game.us.gate==1,"entering arena wakes the Pit Boss and warns of closing gate")
	var boss=s.enemies.filter(func(e): return e.type=="boss")[0]
	check(boss.boss=="pitboss" and boss.max==960,"Pit Boss uses browser solo health")
	s.hurt_enemy(boss,boss.max*.51,p.id)
	s.update(.05)
	check(s.game.us.bossStage==1 and boss.st==60 and boss.inv>0 and s.flood_on,"half health starts protected jacket-off transition and arena flood")
	var before=boss.hp
	s.hurt_enemy(boss,100,p.id)
	check(boss.hp==before,"stage transition rejects damage")
	p.hp=10000
	for i in 82: s.update(.05)
	check(s.game.us.gate==2 and s.lay.gate.all(func(xy): return s.terr[s.idx(xy[0],xy[1])]==PalMaps.T_SHUT),"gate seals after four seconds")
	check(boss.inv<=0 and boss.pb.stage==2,"boss resumes in second stage")
	s.hurt_enemy(boss,10000,p.id)
	s.update(.05)
	check(s.game.us.bossDown and s.game.us.gate==0 and not s.flood_on,"boss death drains arena and reopens gate")
	check(s.lay.gate.all(func(xy): return s.terr[s.idx(xy[0],xy[1])]==PalMaps.T_GROUND),"reopened gate restores terrain collision")
	# usNoise and usAlert: a shot wakes idle raiders within earshot (8 tiles), and each calls in raiders within 6 who can see it
	s.new_game(4321,"normal",{}, {"mode":"understrip"})
	p=s.player
	var far=Vector2(clampf(p.x+30,1,s.N-2),clampf(p.y+30,1,s.N-2))
	for e in s.enemies:
		e.us.st="idle"
		e.x=far.x
		e.y=far.y
	var r1=s.enemies[0]
	var r2=s.enemies[1]
	var r3=s.enemies[2]
	var dir=1.0 if p.x<s.N/2.0 else -1.0
	r1.x=p.x+7.4*dir
	r1.y=p.y
	r2.x=p.x+8.6*dir
	r2.y=p.y
	var heard_far=Vector2(far.x-p.x,far.y-p.y).length()<8
	s.us.noise(p.x,p.y,8.0)
	check(r1.us.st=="hunt" and (r3.us.st=="idle" or heard_far),"a shot wakes the raiders within earshot only")
	check(r2.us.st==("hunt" if s.los_clear(r2.x,r2.y,r1.x,r1.y) else "idle"),"a woken raider calls in a raider who can see it")
	check("step" in PalAudio.NAMES and FileAccess.file_exists("res://sfx/step.wav"),"hunting raiders' footsteps have their sound")
	var art=JSON.parse_string(FileAccess.get_file_as_string("res://palisade_art/catalog.json"))
	var pit=art.assets.filter(func(a): return a.id=="enemy:pitboss")
	check(pit.size()==1 and "Equipment_Jacket" in pit[0].modular_slots,"the library's Pit Boss has the jacket he tears off in stage 2")
	s.dispose()
	print("PASS understrip_sim" if fails==0 else "FAIL understrip_sim: %d" % fails)
	quit(0 if fails==0 else 1)
