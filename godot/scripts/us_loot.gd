class_name UsLoot
extends RefCounted
## Browser tables are exported unchanged; all rolls use the same isolated RNG.
static var data: Dictionary = {}
const RAR = ["c","r","e","l","g"]

static func tables() -> Dictionary:
	if data.is_empty(): data=JSON.parse_string(FileAccess.get_file_as_string("res://data/understrip/loot.json"))
	return data

static func has(p: Dictionary, id: String) -> bool:
	return id in p.get("uPerks",[])

static func relic(p: Dictionary, id: String) -> bool:
	return p.get("uRelic","")==id

static func weighted(r, weights: Dictionary):
	return r.weighted(weights.keys(),func(k): return weights[k])

static func roll_weapon(r, region: int, rarity: String) -> Dictionary:
	var t=tables()
	var pool=t.weapons.keys().filter(func(k): return t.weapons[k].region<=region)
	var local=pool.filter(func(k): return t.weapons[k].region==region)
	var id=r.pick(local+pool)
	var mods=[]
	var available=t.mods.keys().filter(func(k): return RAR.find(t.mods[k].min)<=RAR.find(rarity))
	for i in int(t.tier[rarity].mods):
		var left=available.filter(func(k): return k not in mods)
		if left.is_empty(): break
		mods.append(r.weighted(left,func(k): return t.mods[k].w))
	return {"id":id,"r":rarity,"mods":mods}

static func roll(r, source: String, region: int) -> Dictionary:
	var t=tables()
	var source_table=t.loot[source]
	var what=r.weighted(source_table.what,func(x): return x[1])[0]
	var rarity=weighted(r,source_table.rar[str(region)])
	match what:
		"salvage": return {"kind":"salvage","sal":15+int(floor(r.next()*16))}
		"consumable": return {"kind":"consumable","k":r.pick(["c_nade","c_flare","c_bar","c_juice"])}
		"weapon": return {"kind":"weapon","w":roll_weapon(r,region,rarity)}
		"perk":
			var pool=t.perks.keys().filter(func(k): return k!="p_tiepin" and t.perks[k].get("from",1)<=region)
			var near=pool.filter(func(k): return t.perks[k].r==rarity)
			return {"kind":"perk","k":r.pick(near if not near.is_empty() else pool)}
	var pool=t.relics.keys().filter(func(k): return t.relics[k].get("from",1)<=region)
	return {"kind":"relic","k":r.pick(pool)}

static func gun(w: Dictionary) -> Dictionary:
	var t=tables()
	var weapon=t.weapons[w.id]
	var tier=t.tier[w.r]
	var g=weapon.gun.duplicate(true)
	g.dmg*=tier.x*(1.15 if "m_dmg" in w.mods else 1)
	if "m_rate" in w.mods: g.cd/=1.12
	if "m_mag" in w.mods: g.mag=int(floor(g.mag*1.4+.5))
	if "m_range" in w.mods:
		g.range*=1.2
		g.speed*=1.2
	if "m_steady" in w.mods: g.spread*=.7
	if "m_pierce" in w.mods: g.pierce=g.get("pierce",0)+1
	if tier.get("sig",false):
		match w.id:
			"w_sawnoff": g.pellets=18
			"w_smg": g.mag=64
			"w_riot":
				g.pellets=1
				g.dmg=70*tier.x
				g.pierce=3
				g.spread=.02
			"w_flare":
				g.pellets=3
				g.spread=.5
			"w_laser": g.prism=true
			"w_taser": g.arc=3
			"w_nailgun": g.rivets=true
			"w_antigrav": g.well=true
			"w_alien": g.chargeT=.7
	if weapon.fx=="charge":
		g.chargeT=g.get("chargeT",1.2)
		g.chargeDmg=64*tier.x*(1.15 if "m_dmg" in w.mods else 1)
	g.reload=weapon.magReload*(.75 if "m_reload" in w.mods else 1)/g.mag
	g.bolt=g.cd>=.5
	g.snd="us_"+w.id.trim_prefix("w_")
	g.us=w.id
	g.usFx=weapon.fx
	g.crit=.08 if "m_crit" in w.mods else 0
	g.vamp="m_vamp" in w.mods
	return g

static func reserve(w: Dictionary, p: Dictionary) -> int:
	return int(floor(tables().weapons[w.id].reserve*(1.5 if "m_ammo" in w.mods else 1)*(1.5 if has(p,"p_pockets") else 1)+.5))

static func refit(s, p: Dictionary):
	s.refit(p)
	if p.wSel==1 and p.w2!=null:
		var g=gun(p.w2)
		g.dmg*=(1.0+s.arm_boost(p.up.d,.2,.05))*p.perk.dmg
		g.cd*=(1.0-s.arm_boost(p.up.r,.1,.025))/p.perk.rate
		g.range*=(1.0+s.arm_boost(p.up.g,.12,.03))*p.perk.range
		g.speed*=1.0+s.arm_boost(p.up.g,.1,.025)
		g.reload*=p.perk.reload
		p.gun=g
		p.ammo=clampi(int(p.w2.ammo),0,int(g.mag))
	if has(p,"p_steady"): p.gun.spread*=.75
	if relic(p,"x_chip"): p.gun.dmg*=1.3
	if relic(p,"x_crown"):
		p.gun.cd/=1.25
		p.max=int(floor(p.max*.75+.5))
		p.hp=minf(p.hp,p.max)
	p.ujm=4 if has(p,"p_house") else 3

## Weapon-local actions must never survive a swap, pickup or a menu transition.
static func cancel_fire(p: Dictionary):
	p.bLeft=0
	p.chg=0.0
	p.fire_in=false
	p.pullUsed=p.pullIn
	p.bolt=0.0
	p.rl=0.0

static func swap(s, p: Dictionary, to: int) -> bool:
	if not p.alive or p.w2==null or to==p.wSel: return false
	if p.wSel==1: p.w2.ammo=p.ammo
	cancel_fire(p)
	p.wSel=to
	refit(s,p)
	p.cd=maxf(p.cd,.25)
	p.rl=0.0
	s.sfx("rack",p.x,p.y)
	return true

static func can_apply(p: Dictionary, item: Dictionary) -> bool:
	if item.kind=="perk": return not has(p,item.k)
	if item.kind!="consumable": return true
	match item.k:
		"c_nade": return p.nades<p.maxN
		"c_juice": return p.uj<p.ujm
		"c_ammo", "c_ammop": return p.w2!=null and p.w2.res<reserve(p.w2,p)
	return p.ui["bar" if item.k=="c_bar" else "flare"]<tables().items[item.k].max

static func apply(s, p: Dictionary, item: Dictionary) -> bool:
	if not can_apply(p,item): return false
	match item.kind:
		"weapon":
			var old=p.w2
			cancel_fire(p)
			p.cd=maxf(p.cd,.25)
			p.w2=item.w.duplicate(true)
			p.w2.ammo=gun(p.w2).mag
			p.w2.res=reserve(p.w2,p)
			p.wSel=1
			refit(s,p)
			if old!=null: s.us.drop_loot(p.x+.3,p.y+.3,{"kind":"weapon","w":{"id":old.id,"r":old.r,"mods":old.mods}})
		"perk":
			p.uPerks.append(item.k)
			refit(s,p)
		"relic":
			var old=p.uRelic
			p.uRelic=item.k
			if old!="" and old!=item.k: s.us.drop_loot(p.x+.3,p.y+.3,{"kind":"relic","k":old})
			refit(s,p)
		"consumable":
			match item.k:
				"c_nade": p.nades+=1
				"c_juice": p.uj+=1
				"c_ammo", "c_ammop": p.w2.res=mini(reserve(p.w2,p),p.w2.res+int(ceil(reserve(p.w2,p)*(.4 if item.k=="c_ammop" else 1))))
				_: p.ui["bar" if item.k=="c_bar" else "flare"]+=1
		_: p.sal+=item.sal
	return true

static func gear_price(item: Dictionary) -> int:
	if item.kind=="weapon": return int(tables().tier[item.w.r].price)
	if item.kind=="perk": return {"c":40,"r":70,"e":110,"l":160,"g":240}[tables().perks[item.k].r]
	return 180

static func stock(r, region: int) -> Array:
	var out=[{"k":"c_nade","n":2+int(floor(r.next()*3))},{"k":"c_juice","n":1}]
	for k in r.shuffle(["c_bar","c_flare"]):
		if r.next()<.8: out.append({"k":k,"n":1+int(floor(r.next()*2))})
	for item in out: item.price=tables().items[item.k].price
	var n=1+(1 if r.next()<.5 else 0)
	for i in n:
		var gear={"kind":"weapon","w":roll_weapon(r,region,"r" if r.next()<.35 else "c")}
		out.append({"gear":gear,"n":1,"price":gear_price(gear)})
	out.append({"k":"c_ammo","n":2,"price":tables().items.c_ammo.price})
	return out

static func perk_of(r, region: int, rarities: Array) -> Dictionary:
	var perks=tables().perks
	var pool=perks.keys().filter(func(k): return k!="p_tiepin" and perks[k].get("from",1)<=region)
	var near=pool.filter(func(k): return perks[k].r in rarities)
	return {"kind":"perk","k":r.pick(near if not near.is_empty() else pool)}

static func gear(item: Dictionary) -> Dictionary:
	return {"gear":item,"n":1,"price":gear_price(item)}

static func lift_stock(r, region: int) -> Array:
	var key="c_nade" if r.next()<.5 else "c_juice"
	return [{"k":key,"n":1,"price":tables().items[key].price},gear({"kind":"weapon","w":roll_weapon(r,region,r.pick(["c","r","r","e"]))}),gear(perk_of(r,region,["c","r"])),{"k":"c_ammo","n":1,"price":tables().items.c_ammo.price}]

static func collector_stock(r, region: int) -> Array:
	var out=[]
	for i in 2: out.append(gear({"kind":"weapon","w":roll_weapon(r,region,"g" if r.next()<.2 else ("l" if r.next()<.55 else "e"))}))
	var count=1+int(floor(r.next()*2))
	var seen=[]
	for i in count:
		var perk=perk_of(r,region,["e","l"])
		if perk.k not in seen:
			seen.append(perk.k)
			out.append(gear(perk))
	var pool=tables().relics.keys().filter(func(k): return k!="x_eye" and tables().relics[k].get("from",1)<=region)
	out.append(gear({"kind":"relic","k":r.pick(pool)}))
	return out

static func cone(p: Dictionary) -> float:
	return (1.4 if has(p,"p_owl") else 1)*(.6 if relic(p,"x_lens") else 1)*(.7 if relic(p,"x_eye") else 1)*(1.3 if p.wSel==1 and p.w2!=null and "m_light" in p.w2.mods else 1)

static func shot_mul(s, p: Dictionary) -> float:
	var mult=1.0
	if p.gun.get("rivets",false):
		p.rivet=(p.get("rivet",0)+1)%5
		if p.rivet==0: mult*=3
	if has(p,"p_loaded") and s.rnd()<.1: mult*=2
	if has(p,"p_stack") and p.sal>=150: mult*=1.2
	if p.ripT>0: mult*=1.3
	if p.gun.get("crit",0)>0 and s.rnd()<p.gun.crit: mult*=2
	return mult

static func bullet_hit(s, e: Dictionary, b: Dictionary):
	if e.dead: return
	match b.get("usFx",""):
		"stun":
			if e.type=="boss":
				e.slowT=maxf(e.get("slowT",0.0),1.0)
				e.slowPct=.4
			else: e.stunT=maxf(e.get("stunT",0.0),.25 if e.get("elite",false) else .5)
			var from=e
			var hit=[e.id]
			for i in maxi(1,int(b.get("arc",0))):
				var next=null
				for other in s.enemies:
					if other.id not in hit and not other.dead and Vector2(other.x-from.x,other.y-from.y).length()<2:
						next=other
						break
				if next==null: break
				hit.append(next.id)
				s.hurt_enemy(next,b.dmg*.5,b.own)
				next.stunT=maxf(next.get("stunT",0.0),.3)
				s.chains.append({"x0":from.x,"y0":from.y,"x1":next.x,"y1":next.y,"life":.18,"max":.18})
				from=next
		"pin": e.stunT=maxf(e.get("stunT",0.0),.2)
		"knock":
			if e.type!="boss": s._knock(e,e.x-b.vx,e.y-b.vy,.4)
		"flare":
			e.burnT=maxf(e.get("burnT",0.0),4)
			e.burnOwn=b.own
			s.game.us.flares.append({"x":e.x,"y":e.y,"t":10.0,"r":5})
		"lift":
			if b.get("well",false):
				for other in s.enemies:
					if not is_same(other,e) and not other.dead and other.type!="boss" and Vector2(other.x-e.x,other.y-e.y).length()<2.5:
						s._knock(other,other.x+(other.x-e.x),other.y+(other.y-e.y),.8)
						other.stunT=maxf(other.get("stunT",0.0),1.0)
			for other in s.enemies:
				if other.dead or Vector2(other.x-e.x,other.y-e.y).length()>=1.6: continue
				if not is_same(other,e): s.hurt_enemy(other,b.dmg*.6,b.own)
				if other.type=="boss":
					other.slowT=maxf(other.get("slowT",0.0),.5)
					other.slowPct=.6
				else:
					other.stunT=2.0
					other.lifted=2.0
	var p=s.players.get(b.own)
	if p!=null and b.get("vamp",false): p.hp=minf(p.max,p.hp+minf(5.0/30.0,b.dmg*.02))
	if p!=null and relic(p,"x_lens") and not e.dead:
		var delta=Vector2(e.x-p.x,e.y-p.y)
		if delta.length()<5.4*cone(p)+.5 and delta.normalized().dot(p.aim)>.82: s.hurt_enemy(e,b.dmg*.25,b.own,true)

static func charge_tick(s, p: Dictionary, dt: float):
	var g=p.gun
	if not g.has("chargeT") or not p.alive: return
	if p.fire_in:
		p.chgSeen=s.game.time
		p.chg=minf(g.chargeT,p.get("chg",0.0)+dt)
		p.fire_in=false
		return
	if p.get("chg",0.0)>0 and s.game.time-p.get("chgSeen",0.0)>(0.0 if is_same(p,s.player) else .12):
		if p.ammo>0 and p.cd<=0 and not s.rolling(p):
			var fraction=p.chg/g.chargeT
			var full=fraction>=.999
			var gun=g.duplicate()
			gun.dmg=g.dmg+(g.chargeDmg-g.dmg)*fraction
			gun.pierce=3 if full else 0
			gun.speed=g.speed*(1.4 if full else 1)
			s.shoot(p,gun,0)
			s.sfx(gun.snd,p.x,p.y)
			p.pullUsed=p.pullIn
			p.ammo-=1
			p.cd=g.cd
			p.sinceShot=0.0
			p.rl=0.0
		p.chg=0.0

static func bounce(s, bullet: Dictionary, step: float) -> bool:
	var px=bullet.x-bullet.vx*step
	var py=bullet.y-bullet.vy*step
	var ci=int(floor(bullet.x))!=int(floor(px))
	var cj=int(floor(bullet.y))!=int(floor(py))
	bullet.x=px
	bullet.y=py
	if ci or not cj: bullet.vx=-bullet.vx
	if cj: bullet.vy=-bullet.vy
	bullet.bnc=bullet.get("bnc",0)+1
	bullet.last=-1
	if bullet.get("prism",false) and bullet.bnc==1:
		var angle=atan2(bullet.vy,bullet.vx)
		var speed=Vector2(bullet.vx,bullet.vy).length()
		for offset in [-.35,.35]:
			var copy=bullet.duplicate(true)
			s.bullet_seq+=1
			copy.id=s.bullet_seq
			copy.vx=cos(angle+offset)*speed
			copy.vy=sin(angle+offset)*speed
			copy.prism=false
			s.bullets.append(copy)
	return true

static func label(item: Dictionary) -> String:
	if item.kind=="weapon": return tables().weapons[item.w.id].name+" ("+str(item.w.r).to_upper()+")"
	if item.kind=="perk": return tables().perks[item.k].name
	if item.kind=="relic": return tables().relics[item.k].name
	if item.kind=="consumable": return tables().items[item.k].name
	return "%d SALVAGE" % item.sal

static func description(item: Dictionary) -> String:
	var t=tables()
	if item.kind=="weapon":
		var w=item.w
		var g=gun(w)
		var text=UsWeapons.DESCRIPTION.get(w.id,"")
		text+="\n%.1f damage%s · %d rounds · %.2f s reload" % [g.dmg," × %d pellets" % int(g.pellets) if g.get("pellets",1)>1 else "",g.mag,t.weapons[w.id].magReload*(.75 if "m_reload" in w.mods else 1)]
		for id in w.mods: text+="\n%s: %s" % [t.mods[id].name,t.mods[id].what]
		if t.tier[w.r].get("sig",false): text+="\n"+t.weapons[w.id].sig
		return text
	var group={"consumable":"items","perk":"perks","relic":"relics"}.get(item.kind,"")
	return t[group][item.k].get("what","") if group!="" else "Salvage for supplies and upgrades."
