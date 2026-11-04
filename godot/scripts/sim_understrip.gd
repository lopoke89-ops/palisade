class_name SimUnderstrip
extends RefCounted
## The host's crawl lifecycle. State uses the browser's field names for later yard-31 snapshots.
var _sim: WeakRef
var s:
	get: return _sim.get_ref()
var flows = {}
var flow_time = -1.0
var source = []

func _init(sim):
	_sim = weakref(sim)

static func in_room(p: Array, room: Dictionary) -> bool:
	return p[0]>=room.x and p[0]<room.x+room.w and p[1]>=room.y and p[1]<room.y+room.h

static func floor_in(l: Dictionary, q: Dictionary, predicate: Callable) -> Array:
	var out=[]
	for y in range(q.y+1,q.y+q.h-1):
		for x in range(q.x+1,q.x+q.w-1):
			if l.tiles[y][x]=="." and predicate.call(x,y): out.append([x,y])
	return out

static func nearest(floor_tiles: Array, x: float, y: float) -> Array:
	floor_tiles.sort_custom(func(a,b):
		var da=Vector2(a[0]-x,a[1]-y).length()
		var db=Vector2(b[0]-x,b[1]-y).length()
		return da<db if da!=db else (a[1]<b[1] if a[1]!=b[1] else a[0]<b[0]))
	return floor_tiles[0] if not floor_tiles.is_empty() else []

static func layout(seed: int, index: int) -> Dictionary:
	var l = PalUnderstrip.level(seed,index)
	if not l.ok: return {}
	var out = PalUnderstrip.terrain(l)
	var zero = PackedByteArray()
	zero.resize(l.T*l.T)
	var arena = {}
	var doors = []
	for room in l.rooms:
		if room.role=="boss_arena": arena=room
		if room.role=="shortcut":
			doors.append({"tiles":l.marks.get("K",[]).filter(func(p): return in_room(p,room)),"side":room.opensFrom})
	var names = ["THE FLOOD TUNNELS","SHELTER 7","AREA 67"]
	var reg = PalUnderstrip.PLAN[index][0]
	out.run_seed=seed
	out.merge({"id":"understrip","under":true,"map":{"name":names[reg-1],"short":names[reg-1],"under":true,"night":true,"hp":1.0/1.1,"col":"#7cff6b","from":"out of the dark","bosses":["pitboss","custodian","gatekeeper","visitor"]},
		"heights":zero,"connectors":zero.duplicate(),"core":l.marks.P[0],"starts":l.marks.P.map(func(p): return [p[0]+.5,p[1]+.5]),"nodes":[],"ruins":[],
		"spawns":[{"w":1,"tiles":l.marks.P.duplicate()}],"bossAt":l.marks.get("B",[]),"raftAt":[],"ramps":[],
		"lamps":l.marks.get("L",[]).map(func(p): return [p[0]+.5,p[1]+.5]),"neon":l.marks.get("n",[]).map(func(p): return [p[0]+.5,p[1]+.5]),
		"exit":[l.marks.E[0][0]+.5,l.marks.E[0][1]+.5],"arena":arena,"gate":l.marks.get("G",[]),"doors":doors,
		"shrines":l.marks.S.map(func(p): return {"x":p[0]+.5,"y":p[1]+.5,"arena":not arena.is_empty() and in_room(p,arena)}),
		"chests":l.marks.get("C",[]).map(func(p): return {"x":p[0]+.5,"y":p[1]+.5}),"merchants":[]},true)
	for i in l.marks.get("M",[]).size():
		var p=l.marks.M[i]
		out.merchants.append({"x":p[0]+.5,"y":p[1]+.5,"kind":"trader","stock":UsLoot.stock(PalUnderstripGen.Rng.new(PalUnderstripGen.mix([l.seed,500+i])),reg)})
	if index>0:
		var q=l.rooms.filter(func(room): return room.role=="entrance")[0]
		var f=floor_in(l,q,func(x,y): return l.marks.P.all(func(p): return Vector2(p[0]-x,p[1]-y).length()>=1.9))
		var p=nearest(f,q.x+q.w/2.0,q.y+q.h/2.0)
		if not p.is_empty(): out.merchants.append({"x":p[0]+.5,"y":p[1]+.5,"kind":"lift","stock":UsLoot.lift_stock(PalUnderstripGen.Rng.new(PalUnderstripGen.mix([l.seed,560])),reg)})
	var breather=l.rooms.filter(func(room): return room.role=="breather")[0]
	var shrine=l.marks.S.filter(func(p): return in_room(p,breather))[0]
	var f=floor_in(l,breather,func(x,y):
		var d=Vector2(shrine[0]-x,shrine[1]-y).length()
		return d>=3 and d<=4.2)
	var keeper=nearest(f,shrine[0]+3,shrine[1])
	if not keeper.is_empty(): out.merchants.append({"x":keeper[0]+.5,"y":keeper[1]+.5,"kind":"keeper","stock":[]})
	var first=0 if reg==1 else (3 if reg==2 else 6)
	out.guards=[]
	if index-first==PalUnderstripGen.mix([seed,reg,33])%3:
		var rng=PalUnderstripGen.Rng.new(PalUnderstripGen.mix([l.seed,570]))
		var caches=l.rooms.filter(func(room): return room.role=="cache" and room.tag=="branch")
		if not caches.is_empty():
			var q=rng.pick(caches)
			var chests=l.marks.get("C",[]).filter(func(p): return in_room(p,q))
			if not chests.is_empty():
				var c=chests[0]
				out.merchants.append({"x":c[0]+.5,"y":c[1]+.5,"kind":"collector","stock":UsLoot.collector_stock(rng,reg)})
				out.chests=out.chests.filter(func(chest): return chest.x!=c[0]+.5 or chest.y!=c[1]+.5)
				var floor_tiles=floor_in(l,q,func(x,y): return Vector2(x-c[0],y-c[1]).length()>=1.5)
				floor_tiles.sort_custom(func(a,b): return a[1]<b[1] if a[1]!=b[1] else a[0]<b[0])
				for k in 2:
					if floor_tiles.is_empty(): break
					var pos=floor_tiles[(k*5+3)%floor_tiles.size()]
					out.guards.append({"id":8000+k,"type":"shield" if k==0 else "rifle","x":pos[0]+.5,"y":pos[1]+.5,"amb":0,"elite":1 if k==0 else 0})
	return out

func begin(seed: int, index: int, lives: int):
	s.game.phase="raid"
	s.game.timer=0.0
	s.game.wave=1
	s.game.waves=10.0
	s.game.us={"seed":seed,"level":index,"lives":lives,"exitT":0.0,"lift":0.0,"wipe":0.0,"gate":0,"gateT":0.0,"bossSpawned":false,"bossDown":false,"bossStage":0,
		"rest":{"x":s.lay.starts[0][0],"y":s.lay.starts[0][1],"ix":-1},"lit":0,"opened":0,"chests":0,"drops":[],"flares":[],"loot":[],"eliteDown":[],
		"stats":{"kills":0,"time":0.0,"falls":0,"rests":0,"found":0},"log":[],"flood":50.0+s.rnd()*30.0,"floodOn":false,"floodWarned":false}
	shop_reset()
	s.cores.clear()
	s.core_ks.clear()
	s.core={"team":"","i":-9,"j":-9,"hp":1.0,"max":1.0,"flash":0.0}
	s.core_k=-1
	s.qm.alive=false
	s.qm.gone=true
	s.qm.x=-9.0
	s.qm.y=-9.0
	var n=0
	for p in s.players.values():
		var at=s.lay.starts[n%s.lay.starts.size()]
		n+=1
		p.x=at[0]
		p.y=at[1]
		p.mats=[0,0,0]
		p.uj=3
		p.ujm=3
		p.ujT=0.0
		p.ui={"bar":0,"flare":0}
		p.uSel="bar"
		p.usDead=false
		p.w2=null
		p.wSel=0
		p.uPerks=[]
		p.uRelic=""
		p.breakUsed=false
		p.ripT=0.0
	source=populate(s.lay.us,PalUnderstrip.PLAN[index][0])+s.lay.guards
	spawn_raiders()

static func populate(l: Dictionary, region: int) -> Array:
	var r=PalUnderstripGen.Rng.new(PalUnderstripGen.mix([l.seed,77]))
	var out=[]
	var taken={}
	var mix_types=[["rifle",48],["shield",12],["gren",12],["breach",9],["medic",7],["fire",7],["spotter",5]]
	for q in l.rooms:
		if q.role in ["entrance","breather","exit","merchant","boss_ante","boss_arena"]: continue
		for a in l.marks.get("A",[]):
			if in_room(a,q) and r.next()<.75:
				taken[a[1]*l.T+a[0]]=true
				out.append({"id":out.size(),"type":"rifle" if r.next()<.8 else "shield","x":a[0]+.5,"y":a[1]+.5,"amb":1})
		var count=0
		if q.role=="room": count=(3+int(floor(r.next()*3))) if q.w>8 or q.h>8 else (1+int(floor(r.next()*3)))
		elif q.role=="cache": count=1 if r.next()<.5 else 0
		elif q.role=="junction": count=1 if r.next()<.7 else 0
		else: count=1 if r.next()<.4 else 0
		var floor_tiles=[]
		for y in range(q.y+1,q.y+q.h-1):
			for x in range(q.x+1,q.x+q.w-1):
				if l.tiles[y][x] in [".",","] and not taken.has(y*l.T+x): floor_tiles.append([x,y])
		var first=out.size()
		for k in count:
			if floor_tiles.is_empty(): break
			var at=int(floor(r.next()*floor_tiles.size()))
			var p=floor_tiles[at]
			floor_tiles.remove_at(at)
			taken[p[1]*l.T+p[0]]=true
			out.append({"id":out.size(),"type":r.weighted(mix_types,func(m): return m[1])[0],"x":p[0]+.5,"y":p[1]+.5,"amb":0})
		if q.role=="room" and out.size()-first>=2 and r.next()<.6:
			var elite=out[first]
			for j in range(first,out.size()):
				if out[j].type in ["shield","spotter"]:
					elite=out[j]
					break
			if elite.type not in ["shield","spotter"]: elite.type="shield" if r.next()<.6 else "spotter"
			elite.elite=1
		if region==3 and q.role=="room" and r.next()<.4:
			for k in 3:
				if floor_tiles.is_empty(): break
				var at=int(floor(r.next()*floor_tiles.size()))
				var p=floor_tiles[at]
				floor_tiles.remove_at(at)
				taken[p[1]*l.T+p[0]]=true
				out.append({"id":out.size(),"type":"drone","x":p[0]+.5,"y":p[1]+.5,"amb":0})
	return out.slice(0,40)

func spawn_raiders():
	s.enemies=s.enemies.filter(func(e): return not e.has("us") or e.type=="boss")
	for spawn in source:
		if spawn.get("elite",0) and spawn.id in s.game.us.eliteDown: continue
		# Deeper-region drones are wired with G3, before those levels are offered to players.
		if spawn.type=="drone": continue
		var e=s.spawn_enemy_at(spawn.type,spawn.x,spawn.y)
		e.us={"home":[spawn.x,spawn.y],"st":"ambush" if spawn.amb else "idle","sid":spawn.id,"t":0.0,"look":s.rnd()*6.28}
		e.elite=spawn.get("elite",0)
		if e.elite:
			e.elite="caller" if e.type=="spotter" else "charger"
			e.hp*=2.5
			e.max=e.hp
			e.eab=2+PalUnderstripGen.Rng.new(PalUnderstripGen.mix([s.lay.us.seed,6000+spawn.id])).next()*2
			e.est=0
			e.estT=0.0
	flows.clear()
	flow_time=-1.0

func down(p: Dictionary):
	p.dgE=-1.0
	p.alive=false
	p.downed=true
	p.hp=0.0
	p.revive=0.0
	p.ujT=0.0
	p.rt=20.0 if s.players.values().any(func(o): return not is_same(o,p) and o.alive) else 1e6
	p.deaths+=1
	if UsLoot.relic(p,"x_hand"):
		for e in s.enemies:
			if not e.dead and Vector2(e.x-p.x,e.y-p.y).length()<2: s.hurt_enemy(e,60,p.id)
		s.explode(p.x,p.y,2,.6,p.id,true)
	if UsLoot.has(p,"p_break") and not p.breakUsed:
		p.breakUsed=true
		p.breakT=1.5
	s.sfx("drop",p.x,p.y)
	s.toast_to(p,"DOWN","A teammate can get you up. The squad returns to its last shrine if everyone falls.")

func bleed(p: Dictionary, dt: float):
	if p.get("usDead",false): return
	if p.get("breakT",0.0)>0:
		p.breakT-=dt
		if p.breakT<=0:
			p.alive=true
			p.downed=false
			p.hp=p.max*.2
			p.revive=0.0
			s.sfx("revive",p.x,p.y)
		return
	p.rt-=dt
	if p.rt<=0:
		p.usDead=true
		p.downed=false
		drop(p)

func drop(p: Dictionary):
	var u=s.game.us
	u.drops=u.drops.filter(func(d): return d.id!=p.id)
	var lost=int(ceil(p.sal/2.0)) if UsLoot.has(p,"p_insure") else int(p.sal)
	if lost>0: u.drops.append({"id":p.id,"slot":p.slot,"x":p.x,"y":p.y,"sal":lost})
	p.sal-=lost

func drink(p: Dictionary) -> bool:
	if not p.alive or p.ujT>0 or p.uj<=0 or p.hp>=p.max: return false
	p.uj-=1
	p.ujT=.5 if UsLoot.has(p,"p_sip") else .8
	s.sfx("medic",p.x,p.y)
	return true

func rest(p: Dictionary, index: int) -> bool:
	if not p.alive or index<0 or index>=s.lay.shrines.size(): return false
	var shrine=s.lay.shrines[index]
	if shrine.arena and not s.game.us.bossDown: return false
	if Vector2(p.x-shrine.x,p.y-shrine.y).length()>=1.4: return false
	for e in s.enemies:
		if not e.dead and Vector2(e.x-shrine.x,e.y-shrine.y).length()<8 and (e.type=="boss" or e.get("us",{}).get("st","")=="hunt"): return false
	var u=s.game.us
	u.rest={"x":shrine.x,"y":shrine.y,"ix":index}
	u.lit|=1<<index
	u.stats.rests+=1
	for o in s.players.values():
		if not o.alive:
			o.x=shrine.x+(s.rnd()-.5)
			o.y=shrine.y+.6
			o.tp+=1
		o.alive=true
		o.downed=false
		o.usDead=false
		o.hp=o.max
		o.uj=o.ujm
		o.ujT=0.0
		o.revive=0.0
		if o.w2!=null:
			o.w2.res=UsLoot.reserve(o.w2,o)
			if o.wSel==1: o.ammo=o.gun.mag
			else: o.w2.ammo=UsLoot.gun(o.w2).mag
	spawn_raiders()
	s.sfx("revive",shrine.x,shrine.y)
	return true

func interact(p: Dictionary) -> bool:
	if not p.alive: return false
	for item in s.game.us.loot.duplicate():
		if Vector2(p.x-item.x,p.y-item.y).length()<1.0 and take_loot(p,item.n): return true
	for i in s.lay.shrines.size():
		if rest(p,i): return true
	for i in s.lay.doors.size():
		if s.game.us.opened & (1<<i): continue
		var d=s.lay.doors[i]
		var near=false
		var center=Vector2.ZERO
		for xy in d.tiles:
			center+=Vector2(xy[0]+.5,xy[1]+.5)
			if Vector2(p.x-xy[0]-.5,p.y-xy[1]-.5).length()<1.5: near=true
		if not near or d.tiles.is_empty(): continue
		center/=d.tiles.size()
		var step=PalUnderstripGen.STEP[d.side]
		if (p.x-center.x)*step[0]+(p.y-center.y)*step[1]<=0: return false
		s.game.us.opened|=1<<i
		for xy in d.tiles: s.set_terr(s.idx(xy[0],xy[1]),PalMaps.T_GROUND)
		flows.clear()
		s.sfx("collapse",center.x,center.y)
		return true
	return false

func wipe():
	var u=s.game.us
	u.wipe=0.0
	u.stats.falls+=1
	for p in s.players.values():
		if not p.usDead: drop(p)
		p.usDead=false
	u.lives-=1
	if u.lives<0:
		s.end_game(false,"understrip-lost")
		return
	var n=0
	for p in s.players.values():
		var a=n*2.1
		n+=1
		p.x=u.rest.x+cos(a)*.6*(1 if n>1 else 0)
		p.y=u.rest.y+sin(a)*.6*(1 if n>1 else 0)
		if s.solid_tile(int(p.x),int(p.y)):
			p.x=u.rest.x
			p.y=u.rest.y
		p.tp+=1
		p.alive=true
		p.downed=false
		p.hp=p.max
		p.revive=0.0
		p.uj=p.ujm
		p.ujT=0.0
		p.breakUsed=false
		p.stun=0.0
	s.bullets.clear()
	s.lobs.clear()
	s.charges.clear()
	s.rockets.clear()
	s.fires.clear()
	s.enemies=s.enemies.filter(func(e): return e.type!="boss")
	u.bossSpawned=false
	u.bossStage=0
	u.floodOn=false
	s.flood_on=false
	gate_open()
	spawn_raiders()
	s.toast("THE TUNNELS TAKE YOU","%d lives left. Your salvage is where you fell." % u.lives)
	s.sfx("lose")

func change_level(index: int):
	var u=s.game.us
	var l=layout(u.seed,index)
	if l.is_empty():
		s.end_game(false,"understrip-generation")
		return
	s.dispose()
	s.lay=l
	s.N=l.N
	s.terr=l.terr
	s.heights=l.heights
	s.connectors=l.connectors
	s.map_def=l.map
	s.terr_log.clear()
	s.walls.clear()
	s.walls.resize(s.N*s.N)
	s.debris.resize(s.N*s.N)
	s.debris.fill(0)
	s.dist.resize(s.N*s.N)
	s.nodes.clear()
	s.node_ix.clear()
	s.enemies.clear()
	for list in [s.bullets,s.lobs,s.charges,s.rockets,s.fires,s.arcs,s.sacks,s.frost_fields,s.chains]: list.clear()
	s.poi_flows.clear()
	s.flow_dirty=false
	s.flood_on=false
	var n=0
	for p in s.players.values():
		var at=l.starts[n%l.starts.size()]
		n+=1
		p.x=at[0]
		p.y=at[1]
		p.tx=p.x
		p.ty=p.y
		p.tp+=1
		if not p.alive: p.hp=p.max*(1.0 if p.usDead else .25)
		p.alive=true
		p.downed=false
		p.usDead=false
		p.ujT=0.0
	u.merge({"level":index,"exitT":0.0,"lift":0.0,"wipe":0.0,"gate":0,"bossDown":false,"bossSpawned":false,"bossStage":0,"rest":{"x":l.starts[0][0],"y":l.starts[0][1],"ix":-1},"lit":0,"opened":0,"chests":0,"drops":[],"flares":[],"loot":[],"eliteDown":[],"flood":50.0+s.rnd()*30.0,"floodOn":false,"floodWarned":false},true)
	shop_reset()
	source=populate(l.us,PalUnderstrip.PLAN[index][0])+l.guards
	spawn_raiders()

func flow_tick():
	if s.flow_dirty:
		flows.clear()
		s.flow_dirty=false
	var old=s.core_k
	var built=0
	for p in s.players.values():
		if not p.alive: continue
		var goal=s.idx(clampi(int(p.x),0,s.N-1),clampi(int(p.y),0,s.N-1))
		var previous=flows.get(p.id,{"k":-1,"t":-1.0})
		if built>=2 or (previous.k==goal and previous.has("f")) or s.game.time-previous.t<=.25: continue
		var field=PackedFloat64Array()
		field.resize(s.N*s.N)
		s.core_k=goal
		s.flow_to(goal,field)
		flows[p.id]={"f":field,"k":goal,"t":s.game.time}
		built+=1
	s.core_k=old

func idle(e: Dictionary, dt: float) -> bool:
	if not e.has("us"): return false
	if e.us.st in ["hunt","regroup"]: return false
	var alert=e.hp<e.max
	for p in s.players.values():
		if not p.alive: continue
		var d=Vector2(e.x-p.x,e.y-p.y).length()
		if (d<2.6 if e.us.st=="ambush" else (d<3.2 or (d<7.5 and s.los_clear(e.x,e.y,p.x,p.y)))): alert=true
	if alert:
		alert_raider(e)
		return false
	e.us.look+=dt*.35
	e.aim=Vector2(cos(e.us.look),sin(e.us.look))
	e.cd=maxf(e.cd,.6)
	return true

## usAlert: this raider starts hunting with the alert beep, and calls in every other raider within 6 tiles who can see it
func alert_raider(e: Dictionary):
	if not e.has("us") or e.us.st=="hunt": return
	e.us.st="hunt"
	s.sfx("mark",e.x,e.y)
	for other in s.enemies:
		if not is_same(other,e) and other.has("us") and other.us.st!="hunt" and not other.dead and Vector2(e.x-other.x,e.y-other.y).length()<6 and s.los_clear(other.x,other.y,e.x,e.y): other.us.st="hunt"

## usNoise: shots fired; idle raiders who hear them (within r) are alerted
func noise(x: float, y: float, r: float):
	for e in s.enemies:
		if e.has("us") and e.us.st=="idle" and not e.dead and Vector2(e.x-x,e.y-y).length()<r: alert_raider(e)

## usSteps: hunting raiders' footsteps, at most three a frame, each raider every 0.42-0.54 s while it walks
func steps(dt: float):
	var n=0
	for e in s.enemies:
		if not e.has("us") or e.dead or e.us.st!="hunt": continue
		var st=e.us
		st.stepT=st.get("stepT",0.0)-dt
		if st.stepT<=0 and n<3 and e.walk!=st.get("lastWalk",-1.0):
			st.stepT=.42+s.rnd()*.12
			st.lastWalk=e.walk
			n+=1
			s.sfx("step",e.x,e.y)

func aim(e: Dictionary) -> bool:
	if not e.has("us"): return false
	var state=e.us
	if state.st=="regroup":
		if s.game.time>=state.until: state.st="hunt"
	elif e.hp<e.max*.3 and e.type not in ["medic","boss"] and not state.get("regrouped",false):
		state.regrouped=true
		state.st="regroup"
		state.until=s.game.time+4.0
	var best=null
	var bd=1e9
	for p in s.players.values():
		if not p.alive or not flows.has(p.id): continue
		var field=flows[p.id]
		var k=s.idx(clampi(int(e.x),0,s.N-1),clampi(int(e.y),0,s.N-1))
		if field.f[k]<bd:
			bd=field.f[k]
			best=p
	if best==null: return false
	s._aim_save=[s.core,s.dist,s.core_k]
	if state.st=="regroup":
		var mate=null
		var distance=1e9
		for other in s.enemies:
			if is_same(other,e) or other.dead or not other.has("us") or other.us.st!="hunt": continue
			var d=Vector2(other.x-e.x,other.y-e.y).length()
			if d<distance:
				distance=d
				mate=other
		if mate!=null and distance>1.5:
			var key="rg"+str(e.id)
			var field=flows.get(key,{"f":PackedFloat64Array(),"k":-1,"t":0.0})
			var goal=s.idx(int(mate.x),int(mate.y))
			if field.f.size()!=s.N*s.N: field.f.resize(s.N*s.N)
			if field.k!=goal and s.game.time-field.t>.6:
				s.core_k=goal
				s.flow_to(goal,field.f)
				field.k=goal
				field.t=s.game.time
			flows[key]=field
			if field.k>=0:
				s.core={"team":"","i":int(mate.x),"j":int(mate.y),"hp":1.0,"max":1.0,"flash":0.0}
				s.core_k=goal
				s.dist=field.f
				return true
	s.core={"team":"","i":int(best.x),"j":int(best.y),"hp":1.0,"max":1.0,"flash":0.0}
	s.core_k=flows[best.id].k
	s.dist=flows[best.id].f
	return true

func elite_tick(e: Dictionary, dt: float) -> bool:
	if not e.get("elite",false) or not e.has("us") or e.us.st!="hunt": return false
	e.eab-=dt
	var foe=e.foe
	if e.elite=="charger":
		if e.est==1:
			e.estT-=dt
			e.aim=Vector2(cos(e.ea),sin(e.ea))
			if e.estT<=0:
				e.est=2
				e.estT=1.0
				e.hitSet=[]
				s.sfx("charge",e.x,e.y)
			return true
		if e.est==2:
			e.estT-=dt
			var nx=e.x+cos(e.ea)*6*dt
			var ny=e.y+sin(e.ea)*6*dt
			if e.estT<=0 or not s.inb(int(nx),int(ny)) or s.solid_tile(int(nx),int(ny)):
				e.est=0
				e.eab=5.0
				return true
			e.x=nx
			e.y=ny
			for p in s.allies():
				if p.alive and p.id not in e.hitSet and Vector2(p.x-e.x,p.y-e.y).length()<.6:
					e.hitSet.append(p.id)
					s.hurt_ally(p,24*s.Df.dmg)
					s._knock(p,e.x,e.y,1.2)
			return true
		if foe!=null and e.eab<=0 and Vector2(foe.x-e.x,foe.y-e.y).length()<7:
			e.est=1
			e.estT=.8
			e.ea=atan2(foe.y-e.y,foe.x-e.x)
			e.lx=e.x+cos(e.ea)*6
			e.ly=e.y+sin(e.ea)*6
			s.sfx("lock",e.x,e.y)
			return true
	else:
		if e.est==1:
			e.estT-=dt
			if foe!=null:
				e.lx=foe.x
				e.ly=foe.y
			if e.estT<=0:
				e.est=2
				e.estT=1.2
				s.sfx("lock",e.lx,e.ly)
			return true
		if e.est==2:
			e.estT-=dt
			if e.estT<=0:
				e.est=0
				e.eab=7.0
				s.explode(e.lx,e.ly,1.5,.9*s.Df.dmg,null,true)
			return false
		if foe!=null and e.eab<=0:
			e.est=1
			e.estT=1.5
			e.lx=foe.x
			e.ly=foe.y
	return false

func tick(dt: float) -> bool:
	var u=s.game.us
	u.stats.time+=dt
	if u.lift>0:
		u.lift-=dt
		if u.lift<=0: change_level(u.level+1)
		return true
	flow_tick()
	steps(dt)
	if PalUnderstrip.PLAN[u.level][0]==1:
		flood_tick(dt)
	if not s.lay.arena.is_empty():
		gate_tick(dt)
	for p in s.players.values():
		p.ripT=maxf(0.0,p.ripT-dt)
		if p.has("compM") and merchant_at(p)!=p.compM:
			p.uPerks.erase("p_comped")
			p.erase("compM")
		if p.ujT>0:
			p.ujT=maxf(0,p.ujT-dt)
			if p.ujT==0 and p.alive: p.hp=minf(p.max,p.hp+p.max*.45*(1.25 if UsLoot.has(p,"p_gulp") else 1)*(.5 if UsLoot.relic(p,"x_chip") else 1)*(.7 if UsLoot.relic(p,"x_hand") else 1))
		if p.alive:
			for item in u.loot.duplicate():
				if item.kind=="consumable" and item.k=="c_ammop" and Vector2(p.x-item.x,p.y-item.y).length()<.85 and UsLoot.can_apply(p,item): take_loot(p,item.n)
			for i in range(u.drops.size()-1,-1,-1):
				var drop_item=u.drops[i]
				if drop_item.id==p.id and Vector2(p.x-drop_item.x,p.y-drop_item.y).length()<.85:
					p.sal+=drop_item.sal
					u.drops.remove_at(i)
	for i in s.lay.chests.size():
		if u.chests & (1<<i): continue
		var chest=s.lay.chests[i]
		if s.players.values().any(func(p): return p.alive and Vector2(p.x-chest.x,p.y-chest.y).length()<1.1):
			u.chests|=1<<i
			drop_loot(chest.x,chest.y+.6,UsLoot.roll(PalUnderstripGen.Rng.new(PalUnderstripGen.mix([s.lay.us.seed,950+i])),"chest",PalUnderstrip.PLAN[u.level][0]))
			s.sfx("gather",chest.x,chest.y)
	for flare in u.flares: flare.t-=dt
	u.flares=u.flares.filter(func(f): return f.t>0)
	if not s.players.values().any(func(p): return p.alive):
		u.wipe+=dt
		if u.wipe>=2.6: wipe()
		return false
	u.wipe=0.0
	var exit_open=PalUnderstrip.PLAN[u.level][1]!="boss" or u.bossDown
	var up=s.players.values().filter(func(p): return p.alive)
	if exit_open and up.all(func(p): return Vector2(p.x-s.lay.exit[0],p.y-s.lay.exit[1]).length()<1.6):
		u.exitT+=dt
		if u.exitT>=3:
			u.exitT=0.0
			if u.level==9: s.end_game(true,"understrip")
			else:
				u.lift=5.0
				s.sfx("horn")
				if u.level in [2,5,8]: u.lives+=1
	else: u.exitT=maxf(0,u.exitT-dt*2)
	return false

func flood_tick(dt: float):
	var u=s.game.us
	if u.gate==2: return
	u.flood-=dt
	if not u.floodOn and u.flood<=5 and not u.floodWarned:
		u.floodWarned=true
		s.toast("FLASH FLOOD","Water is coming down the tunnels. Get off the low ground.")
		s.sfx("flood")
	if u.flood<=0:
		u.floodOn=not u.floodOn
		u.flood=18.0 if u.floodOn else 75.0+s.rnd()*40.0
		u.floodWarned=false
		s.flood_on=u.floodOn
		flows.clear()

func gate_open():
	s.game.us.gate=0
	for xy in s.lay.gate: s.set_terr(s.idx(xy[0],xy[1]),PalMaps.T_GROUND)
	flows.clear()

func gate_tick(dt: float):
	var u=s.game.us
	if u.bossDown: return
	var a=s.lay.arena
	var inside_arena=func(p): return p.x>=a.x+1 and p.x<a.x+a.w-1 and p.y>=a.y+1 and p.y<a.y+a.h-1
	if u.gate==0 and s.players.values().any(func(p): return p.alive and inside_arena.call(p)):
		u.gate=1
		u.gateT=4.0
		s.toast("THE GATE IS CLOSING","Four seconds: everyone through.")
		s.sfx("horn")
		# G2's Pit Boss. Deeper bosses are added by G3.
		if PalUnderstrip.PLAN[u.level][2]=="pitboss":
			u.bossSpawned=true
			var boss=s.spawn_boss("pitboss")
			boss.us={"home":[boss.x,boss.y],"st":"hunt","sid":-boss.id,"look":0.0}
			boss.hp=960.0*(1+.35*maxi(0,s.players.size()-1))*s.Df.hp
			boss.max=boss.hp
	elif u.gate==1:
		u.gateT-=dt
		if u.gateT<=0:
			u.gate=2
			for xy in s.lay.gate: s.set_terr(s.idx(xy[0],xy[1]),PalMaps.T_SHUT)
			for p in s.players.values():
				if p.alive and not inside_arena.call(p):
					p.x=a.x+a.w/2.0-.5+s.rnd()
					p.y=a.y+a.h-2.5
					p.tp+=1
			flows.clear()
	if u.bossSpawned and not s.enemies.any(func(e): return e.type=="boss" and not e.dead):
		u.bossDown=true
		u.bossStage=0
		u.floodOn=false
		u.flood=75.0
		s.flood_on=false
		gate_open()
		s.toast("THE PIT BOSS IS DOWN","The shrine is lit and the lift is running.")
		var at=s.lay.bossAt[0]
		var n=0
		for p in s.players.values():
			drop_loot(at[0]+.5+(n%3-1)*.8,at[1]+2,UsLoot.roll(PalUnderstripGen.Rng.new(PalUnderstripGen.mix([u.seed,u.level,7000+n])),"boss",PalUnderstrip.PLAN[u.level][0]))
			n+=1
		drop_loot(at[0]+.5,at[1]+3.2,{"kind":"perk","k":"p_tiepin"})

func drop_loot(x: float, y: float, item: Dictionary):
	var u=s.game.us
	u.lootN=u.get("lootN",0)+1
	var l=item.duplicate(true)
	l.merge({"n":u.lootN,"x":x,"y":y},true)
	u.loot.append(l)
	s.sfx("restock",x,y)

func enemy_died(e: Dictionary, own):
	var u=s.game.us
	if e.get("elite",false) and e.has("us"):
		drop_loot(e.x,e.y,UsLoot.roll(PalUnderstripGen.Rng.new(PalUnderstripGen.mix([u.seed,u.level,4000+e.us.sid])),"elite",PalUnderstrip.PLAN[u.level][0]))
		var p=s.players.get(own)
		if p!=null: p.sal+=20
	elif e.type!="boss" and s.rnd()<.15 and s.players.values().any(func(p): return p.w2!=null and p.w2.res<UsLoot.reserve(p.w2,p)) and u.loot.filter(func(l): return l.kind=="consumable" and l.k=="c_ammop").size()<3:
		drop_loot(e.x,e.y,{"kind":"consumable","k":"c_ammop"})

func take_loot(p: Dictionary, n: int) -> bool:
	if not p.alive: return false
	for item in s.game.us.loot:
		if item.n!=n or Vector2(p.x-item.x,p.y-item.y).length()>1.2: continue
		if not UsLoot.apply(s,p,item): return false
		s.game.us.loot.erase(item)
		s.game.us.stats.found+=1
		s.toast_to(p,UsLoot.label(item),"Added to your run kit.")
		return true
	return false

func shop_reset():
	s.game.us.left=s.lay.merchants.map(func(m): return m.stock.map(func(item): return int(item.n)))
	s.game.us.got=s.lay.merchants.map(func(m): return m.stock.map(func(_item): return 0))

func merchant_at(p: Dictionary) -> int:
	for i in s.lay.merchants.size():
		var m=s.lay.merchants[i]
		if Vector2(p.x-m.x,p.y-m.y).length()<1.7: return i
	return -1

func buy(p: Dictionary, merchant: int, row: int) -> bool:
	if not p.alive or merchant_at(p)!=merchant or row<0 or row>=s.lay.merchants[merchant].stock.size(): return false
	var item=s.lay.merchants[merchant].stock[row]
	var price=int(floor(item.price*(1.25 if UsLoot.relic(p,"x_deck") else 1)*(.75 if UsLoot.has(p,"p_comped") else 1)+.5))
	var u=s.game.us
	if p.sal<price: return false
	if item.has("gear"):
		if u.got[merchant][row] & (1<<p.slot) or not UsLoot.apply(s,p,item.gear): return false
		u.got[merchant][row]|=1<<p.slot
	else:
		if u.left[merchant][row]<=0 and not UsLoot.relic(p,"x_deck"): return false
		if not UsLoot.apply(s,p,{"kind":"consumable","k":item.k}): return false
		if not UsLoot.relic(p,"x_deck"): u.left[merchant][row]-=1
	p.sal-=price
	if UsLoot.has(p,"p_comped"): p.compM=merchant
	return true

func use_item(p: Dictionary) -> bool:
	if not p.alive or p.ui[p.uSel]<=0: return false
	var at=Vector2(p.x,p.y)+p.aim*2.4
	if not s.inb(int(at.x),int(at.y)): return false
	if p.uSel=="flare":
		s.game.us.flares.append({"x":at.x,"y":at.y,"t":15.0})
		s.sfx("lob",at.x,at.y)
	else:
		var target=s.build_target(p,0,false)
		if not s.inb(target.i,target.j) or s.solid_tile(target.i,target.j) or s.walls[s.idx(target.i,target.j)]!=null: return false
		var w=Pal.make_wall(0,true)
		w.hp=120.0
		w.max=120.0
		w.bar=true
		s.sfx("place0",target.i+.5,target.j+.5)
		s.walls[s.idx(target.i,target.j)]=w
		flows.clear()
	p.ui[p.uSel]-=1
	return true
