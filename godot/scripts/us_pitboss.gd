class_name UsPitBoss
extends RefCounted
## 10i-understrip-bosses.js: the Pit Boss's two stages and timed attacks.
static func think(s, e: Dictionary, dt: float) -> Array:
	if not e.has("pb"): e.pb={"stage":1,"calls":0,"toss":2.2,"swing":0.0,"rush":3.0,"spray":1.5}
	var state=e.pb
	for timer in ["toss","swing","rush","spray"]: state[timer]-=dt
	e.inv=maxf(0,e.get("inv",0.0)-dt)
	if state.stage==1 and e.hp<=e.max*.5:
		e.hp=e.max*.5
		state.stage=2
		e.st=60
		e.stT=3.0
		e.stM=3.0
		e.inv=3.0
		s.game.us.bossStage=1
		s.game.us.floodOn=true
		s.flood_on=true
		s.toast("THE PIT BOSS: JACKET OFF","The floor floods. Watch his charge lane and card spray.")
		s.sfx("horn",e.x,e.y)
		return [true,null]
	if e.st==60:
		e.stT-=dt
		if e.stT<=0:
			e.st=0
			e.speed=2.1
		return [true,null]
	if state.calls==0 and e.hp<=e.max*.75:
		state.calls=1
		call_raiders(s,e,["rifle","rifle"])
	if state.calls==1 and state.stage==2 and e.hp<=e.max*.25:
		state.calls=2
		call_raiders(s,e,["rifle","shield"])
	if e.st==1:
		e.stT-=dt
		if e.foe!=null: s._aim_at(e,e.foe.x,e.foe.y)
		if e.stT<=0:
			e.st=0
			for p in s.allies():
				if p.alive and Vector2(p.x-e.x,p.y-e.y).length()<=1.8 and absf(angle_difference(e.aim.angle(),atan2(p.y-e.y,p.x-e.x)))<.9:
					s.hurt_ally(p,22*s.Df.dmg)
					s._knock(p,e.x,e.y,1.0)
			s.sfx("slash",e.x,e.y)
		return [true,null]
	if e.st==61:
		e.stT-=dt
		s._aim_at(e,e.lx,e.ly)
		if e.stT<=0:
			e.st=0
			var angle=atan2(e.ly-e.y,e.lx-e.x)
			for k in 6: s.fire(e,angle+(k/5.0-.5)*.9,1,{"dmg":8*s.Df.dmg,"speed":15.0,"range":5.0},0)
			s.sfx("cas_card",e.x,e.y)
		return [true,null]
	if e.st==2:
		e.stT-=dt
		s._aim_at(e,e.lx,e.ly)
		if e.stT<=0:
			var delta=Vector2(e.lx-e.x,e.ly-e.y)
			e.st=3
			e.stT=delta.length()/8.0+.05
			e.stM=e.stT
			e.velocity=delta.normalized()*8.0
			e.hit=[]
			s.sfx("charge",e.x,e.y)
		return [true,null]
	if e.st==3:
		e.stT-=dt
		var stop=e.stT<=0
		for substep in 3:
			if stop: break
			var nx=e.x+e.velocity.x*dt/3.0
			var ny=e.y+e.velocity.y*dt/3.0
			if not s.inb(int(nx),int(ny)) or PalMaps.terr_solid(s.terr[s.idx(int(nx),int(ny))]):
				stop=true
				break
			var k=s.idx(int(nx),int(ny))
			if s.walls[k]!=null:
				s.damage_wall(k,150)
				if s.walls[k]!=null:
					stop=true
					break
			e.x=nx
			e.y=ny
			for p in s.allies():
				if p.alive and p.id not in e.hit and Vector2(p.x-e.x,p.y-e.y).length()<.65:
					e.hit.append(p.id)
					s.hurt_ally(p,32*s.Df.dmg)
					s._knock(p,e.x,e.y,1.5)
		e.walk+=dt*18
		if stop:
			e.st=62
			e.stT=1.0
			e.stM=1.0
			s.sfx("hit2",e.x,e.y)
		return [true,null]
	if e.st==62:
		e.stT-=dt
		if e.stT<=0: e.st=0
		return [true,null]
	var foe=e.foe
	if foe==null:
		var nearest=1e9
		for p in s.allies():
			var d=Vector2(p.x-e.x,p.y-e.y).length()
			if p.alive and d<nearest:
				nearest=d
				foe=p
	if foe==null: return [false,null]
	var distance=Vector2(foe.x-e.x,foe.y-e.y).length()
	s._aim_at(e,foe.x,foe.y)
	if distance<2 and state.swing<=0:
		set_state(e,1,.7)
		state.swing=2.5
		s.sfx("lock",e.x,e.y)
		return [true,null]
	if state.stage==2 and distance>2.4 and distance<10 and state.rush<=0 and s.los_clear(e.x,e.y,foe.x,foe.y):
		var direction=Vector2(foe.x-e.x,foe.y-e.y).normalized()
		var length=0.0
		while length<14:
			var p=Vector2(e.x,e.y)+direction*(length+.5)
			if not s.inb(int(p.x),int(p.y)) or PalMaps.terr_solid(s.terr[s.idx(int(p.x),int(p.y))]): break
			length+=.5
		set_state(e,2,.9)
		e.lx=e.x+direction.x*length
		e.ly=e.y+direction.y*length
		state.rush=6.0
		s.sfx("charge",e.x,e.y)
		return [true,null]
	if state.stage==2 and distance<5 and state.spray<=0:
		set_state(e,61,.7)
		e.lx=foe.x
		e.ly=foe.y
		state.spray=3.0
		s.sfx("lock",e.x,e.y)
		return [true,null]
	if state.toss<=0 and distance<8:
		for k in (2 if state.stage==1 else 3):
			var x=clampf(foe.x+((s.rnd()-.5)*3 if k else 0),.5,s.N-.5)
			var y=clampf(foe.y+((s.rnd()-.5)*3 if k else 0),.5,s.N-.5)
			var d=Vector2(x-e.x,y-e.y).length()
			s.lobs.append({"x0":e.x,"y0":e.y,"x1":x,"y1":y,"t":0.0,"T":maxf(.9,.55+d*.08),"R":1.4,"power":.9*s.Df.dmg,"k":3,"own":null})
		state.toss=3.5 if state.stage==1 else 3.0
		s.sfx("lob",e.x,e.y)
		return [true,null]
	return [false,Vector2(foe.x,foe.y) if distance>=1.2 else null]

static func set_state(e: Dictionary, state: int, duration: float):
	e.st=state
	e.stT=duration
	e.stM=duration

static func call_raiders(s, boss: Dictionary, types: Array):
	var arena=s.lay.arena
	s.toast("SECURITY!","He called two of the casino's guards in.")
	s.sfx("siren",boss.x,boss.y)
	for i in types.size():
		var x=arena.x+2+(arena.w-4)*(i+.5)/types.size()
		var y=arena.y+2.5
		if s.solid_tile(int(x),int(y)): continue
		var e=s.spawn_enemy_at(types[i],x,y)
		e.us={"home":[x,y],"st":"hunt","sid":-e.id,"look":0.0,"call":true}
		e.foe=boss.foe
