class_name PalUnderstripGen
extends RefCounted
## Native port of 06g-understrip.js. Array order and random draws are protocol data.
const CELL = 8
const SIDES = ["N", "E", "S", "W"]
const OPP = {"N":"S", "S":"N", "E":"W", "W":"E"}
const STEP = {"N":[0,-1], "S":[0,1], "E":[1,0], "W":[-1,0]}

static func imul(a: int, b: int) -> int:
	return ((a & 65535) * (b & 65535) + (((a >> 16) * (b & 65535) + (b >> 16) * (a & 65535)) << 16)) & 0xffffffff

static func mix(values: Array) -> int:
	var h = 0x9e3779b9
	for x in values:
		h = imul(h ^ int(x), 0x85ebca6b)
		h ^= h >> 13
		h = imul(h, 0xc2b2ae35)
		h ^= h >> 16
	return h

class Rng:
	var state: int
	func _init(seed: int):
		state = seed & 0xffffffff
	func next() -> float:
		state = (state + 0x6d2b79f5) & 0xffffffff
		var t = PalUnderstripGen.imul(state ^ (state >> 15), 1 | state)
		t = ((t + PalUnderstripGen.imul(t ^ (t >> 7), 61 | t)) & 0xffffffff) ^ t
		return float((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0
	func pick(a: Array):
		return a[int(floor(next() * a.size()))]
	func weighted(a: Array, weight: Callable):
		var total = 0.0
		for x in a:
			total += weight.call(x)
		var value = next() * total
		for x in a:
			value -= weight.call(x)
			if value < 0:
				return x
		return a.back()
	func shuffle(a: Array) -> Array:
		for i in range(a.size()-1, 0, -1):
			var j = int(floor(next() * (i+1)))
			var t = a[i]
			a[i] = a[j]
			a[j] = t
		return a

static func variants(p: Dictionary) -> Array:
	var out = []
	var seen = {}
	for mirror in range(2 if p.rotate else 1):
		for turn in range(4 if p.rotate else 1):
			var rows = p.grid.duplicate()
			if mirror:
				for y in rows.size():
					rows[y] = rows[y].reverse()
			var side = p.get("opensFrom", "")
			if mirror and side in ["E", "W"]:
				side = OPP[side]
			for k in turn:
				var rotated = []
				for x in rows[0].length():
					var row = ""
					for y in range(rows.size()-1, -1, -1):
						row += rows[y][x]
					rotated.append(row)
				rows = rotated
				if side != "":
					side = {"N":"E","E":"S","S":"W","W":"N"}[side]
			var key = "/".join(rows)
			if seen.has(key):
				continue
			seen[key] = true
			var h = rows.size()
			var w = rows[0].length()
			var cw = int(w / CELL)
			var ch = int(h / CELL)
			var doors = []
			for c in cw:
				for edge in [["N", rows[0][c*CELL+3]], ["S", rows[h-1][c*CELL+3]]]:
					if edge[1] in ["D","G"]:
						doors.append({"side":edge[0],"cell":c,"gate":edge[1]=="G"})
			for c in ch:
				for edge in [["W",rows[c*CELL+3][0]], ["E",rows[c*CELL+3][w-1]]]:
					if edge[1] in ["D","G"]:
						doors.append({"side":edge[0],"cell":c,"gate":edge[1]=="G"})
			out.append({"rows":rows,"cw":cw,"ch":ch,"doors":doors,"opensFrom":side})
	return out

static func door_cells(v: Dictionary, cx: int, cy: int, d: Dictionary) -> Dictionary:
	var x = cx + (d.cell if d.side in ["N","S"] else (v.cw-1 if d.side=="E" else 0))
	var y = cy + (d.cell if d.side in ["W","E"] else (v.ch-1 if d.side=="S" else 0))
	return {"x":x,"y":y,"ox":x+STEP[d.side][0],"oy":y+STEP[d.side][1]}

static func generate(kit: Dictionary, seed: int, kind: String = "normal", boss: String = "") -> Dictionary:
	var entries = []
	for p in kit.pieces:
		if p.role != "boss_arena" or boss == "" or p.get("boss", "") == "" or p.boss == boss:
			entries.append({"p":p,"vars":variants(p)})
	for a in 120:
		var attempt = Attempt.new(kit, entries, (seed+a)&0xffffffff, kind)
		var level = attempt.run()
		if not level.is_empty():
			level.seed = seed & 0xffffffff
			level.attempts = a+1
			return level
	return {"ok":false,"seed":seed&0xffffffff,"attempts":120}

static func load_kit(region: int) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/understrip/rooms-r%d.json" % region))

static func tile_hash(level: Dictionary) -> int:
	var h = 0x811c9dc5
	for row in level.tiles:
		for i in row.length():
			h = imul(h ^ row.unicode_at(i), 0x01000193)
	return h

class Attempt:
	var kit: Dictionary
	var entries: Array
	var rng: Rng
	var kind: String
	var grid: int
	var occ = []
	var pieces = []
	var links = []
	var used = {}
	var one = []
	var path_len: int
	var breather_at: int
	var branches = 0
	var merchants = 0
	func _init(k: Dictionary, e: Array, seed: int, type: String):
		kit=k
		entries=e
		rng=Rng.new(seed)
		kind=type
		grid=8 if kind=="boss" else 7
		occ.resize(grid*grid)
		occ.fill(-1)
		one=entries.filter(func(x): return x.p.role in ["corridor","junction","room"] and x.vars[0].cw==1 and x.vars[0].ch==1)
	func by_role(role: String) -> Array:
		return entries.filter(func(x): return x.p.role==role)
	func inside(x: int, y: int) -> bool:
		return x>=0 and y>=0 and x<grid and y<grid
	func cells_free(v: Dictionary, x: int, y: int) -> bool:
		if x<0 or y<0 or x+v.cw>grid or y+v.ch>grid:
			return false
		for b in v.ch:
			for a in v.cw:
				if occ[(y+b)*grid+x+a]>=0:
					return false
		return true
	func place(e: Dictionary, v: Dictionary, x: int, y: int, tag: String) -> int:
		var n=pieces.size()
		pieces.append({"id":e.p.id,"role":e.p.role,"v":v,"cx":x,"cy":y,"tag":tag,"ls":links.size()})
		used[e.p.id]=used.get(e.p.id,0)+1
		for b in v.ch:
			for a in v.cw:
				occ[(y+b)*grid+x+a]=n
		return n
	func unplace():
		var p=pieces.pop_back()
		used[p.id]-=1
		for y in p.v.ch:
			for x in p.v.cw:
				occ[(p.cy+y)*grid+p.cx+x]=-1
		links.resize(p.ls)
	func link(a: int, da: Dictionary, b: int, db: Dictionary, tag: String):
		links.append({"a":a,"da":da,"b":b,"db":db,"kind":tag})
	func linked(n: int, d: Dictionary) -> bool:
		for l in links:
			if (l.a==n and is_same(l.da,d)) or (l.b==n and is_same(l.db,d)):
				return true
		return false
	func open_doors(n: int) -> Array:
		var p=pieces[n]
		var out=[]
		for d in p.v.doors:
			var c=PalUnderstripGen.door_cells(p.v,p.cx,p.cy,d)
			if inside(c.ox,c.oy) and occ[c.oy*grid+c.ox]<0 and not linked(n,d):
				out.append({"n":n,"d":d,"c":c})
		return out
	func fits(pool: Array, o: Dictionary, more: bool) -> Array:
		var out=[]
		var arena_open=pieces[o.n].role=="boss_arena"
		for e in pool:
			if used.get(e.p.id,0)>=e.p.max:
				continue
			var arena=e.p.role=="boss_arena"
			for v in e.vars:
				for d in v.doors:
					if d.side!=OPP[o.d.side]:
						continue
					if not ((o.d.gate and arena and not d.gate) or (d.gate and arena_open and not o.d.gate) or (not o.d.gate and not d.gate and not arena_open and not arena)):
						continue
					var x=o.c.ox-d.cell if d.side in ["N","S"] else (o.c.ox if d.side=="W" else o.c.ox-v.cw+1)
					var y=o.c.oy-d.cell if d.side in ["W","E"] else (o.c.oy if d.side=="N" else o.c.oy-v.ch+1)
					if cells_free(v,x,y) and (not more or v.doors.size()>=2):
						out.append({"e":e,"v":v,"cx":x,"cy":y,"d":d,"o":o})
		return out
	func at(s: int) -> int:
		return path_len-1-s if kind=="boss" else s
	func role_at(i: int) -> Array:
		if i==0: return by_role("entrance")
		if i==breather_at: return by_role("breather")
		if kind=="boss" and i==path_len-2: return by_role("boss_ante")
		if i==path_len-1: return by_role("boss_arena" if kind=="boss" else "exit")
		return entries.filter(func(x): return x.p.role in (["corridor","junction"] if i<=2 else ["corridor","junction","room"]))
	func has_sides(v: Dictionary, sides: Array) -> bool:
		for side in sides:
			if not v.doors.any(func(d): return d.side==side and d.cell==0): return false
		return true
	func upgrade(n: int, side: String) -> Array:
		var p=pieces[n]
		if p.v.cw!=1 or p.v.ch!=1 or p.role not in ["corridor","junction","room"]: return []
		var sides=[]
		for l in links:
			if l.a==n or l.b==n: sides.append(l.da.side if l.a==n else l.db.side)
		sides.append(side)
		var out=[]
		for e in one:
			if e.p.id==p.id or used.get(e.p.id,0)<e.p.max:
				for v in e.vars:
					if has_sides(v,sides): out.append({"e":e,"v":v})
		return out
	func ports(predicate: Callable) -> Array:
		var out=[]
		for n in pieces.size():
			if not predicate.call(n): continue
			var p=pieces[n]
			for o in open_doors(n): out.append({"n":n,"side":o.d.side,"ox":o.c.ox,"oy":o.c.oy,"d":o.d})
			if p.v.cw==1 and p.v.ch==1:
				for side in SIDES:
					if p.v.doors.any(func(d): return d.side==side): continue
					var x=p.cx+STEP[side][0]
					var y=p.cy+STEP[side][1]
					if inside(x,y) and occ[y*grid+x]<0 and not upgrade(n,side).is_empty(): out.append({"n":n,"side":side,"ox":x,"oy":y,"up":true})
		return out
	func door(v: Dictionary, side: String) -> Dictionary:
		for d in v.doors:
			if d.side==side: return d
		return {}
	func apply_up(pt: Dictionary) -> Dictionary:
		if not pt.get("up",false): return pt.d
		var p=pieces[pt.n]
		var f=rng.weighted(upgrade(pt.n,pt.side),func(o): return 4 if o.e.p.id==p.id else o.e.p.weight)
		used[p.id]-=1
		used[f.e.p.id]=used.get(f.e.p.id,0)+1
		p.id=f.e.p.id
		p.role=f.e.p.role
		p.v=f.v
		for l in links:
			if l.a==pt.n: l.da=door(f.v,l.da.side)
			if l.b==pt.n: l.db=door(f.v,l.db.side)
		return door(f.v,pt.side)
	func side_to(a: int, b: int) -> String:
		var dx=b%grid-a%grid
		var dy=int(b/grid)-int(a/grid)
		return "E" if dx==1 else ("W" if dx==-1 else ("S" if dy==1 else "N"))
	func shortcut() -> bool:
		var late_from=maxi(breather_at+2,int(ceil(path_len*2.0/3.0)))
		var early={}
		for pt in ports(func(n): return pieces[n].tag=="path" and pieces[n].at>0 and pieces[n].at<=breather_at):
			var k=pt.oy*grid+pt.ox
			if not early.has(k): early[k]=[]
			early[k].append(pt)
		var late=ports(func(n): return pieces[n].tag=="path" and pieces[n].at>=late_from and pieces[n].role not in ["boss_arena","boss_ante","exit"])
		for lo in rng.shuffle(late):
			var start=lo.oy*grid+lo.ox
			var prev=[]
			prev.resize(grid*grid)
			prev.fill(-2)
			var depth=[]
			depth.resize(grid*grid)
			depth.fill(0)
			prev[start]=-1
			var q=[start]
			var goals=[]
			var head=0
			while head<q.size():
				var k=q[head]
				head+=1
				for e in early.get(k,[]):
					if e.n==lo.n: continue
					var gain=pieces[lo.n].at-(pieces[e.n].at+depth[k]+2)
					if gain>=2: goals.append({"k":k,"e":e,"gain":gain})
				if depth[k]>=(5 if kind=="boss" else 4): continue
				for side in SIDES:
					var x=k%grid+STEP[side][0]
					var y=int(k/grid)+STEP[side][1]
					if not inside(x,y): continue
					var kk=y*grid+x
					if prev[kk]!=-2 or occ[kk]>=0: continue
					prev[kk]=k
					depth[kk]=depth[k]+1
					q.append(kk)
			if goals.is_empty(): continue
			var best=0
			for g in goals: best=maxi(best,g.gain)
			var goal=rng.pick(goals.filter(func(g): return g.gain==best))
			var eo=goal.e
			var route=[]
			var kk=goal.k
			while kk!=-1:
				route.push_front(kk)
				kk=prev[kk]
			var need=[]
			var straight=[]
			for i in route.size():
				var back=OPP[lo.side] if i==0 else side_to(route[i],route[i-1])
				var onward=OPP[eo.side] if i==route.size()-1 else side_to(route[i],route[i+1])
				need.append([back,onward])
				if OPP[back]==onward: straight.append(i)
			if straight.is_empty(): continue
			var si=rng.pick(straight)
			var plan=[]
			for i in route.size():
				var opts=[]
				for e in (by_role("shortcut") if i==si else one):
					var count=used.get(e.p.id,0)
					if i!=si:
						for o in plan:
							if is_same(o.e,e): count+=1
					if count>=e.p.max: continue
					for v in e.vars:
						if has_sides(v,need[i]) and (i!=si or v.opensFrom==need[i][0]): opts.append({"e":e,"v":v,"x":1 if i==si else (3 if v.doors.size()==2 else 1)})
				if opts.is_empty():
					plan.clear()
					break
				plan.append(rng.weighted(opts,func(o): return o.e.p.weight*o.x))
			if plan.size()!=route.size(): continue
			var dl=apply_up(lo)
			var de=apply_up(eo)
			var pn=lo.n
			var pd=dl
			for i in route.size():
				var f=plan[i]
				var n=place(f.e,f.v,route[i]%grid,int(route[i]/grid),"shortcut")
				link(pn,pd,n,door(f.v,need[i][0]),"shortcut")
				pn=n
				pd=door(f.v,need[i][1])
			link(pn,pd,eo.n,de,"shortcut")
			return true
		return false
	func root_ok(n: int) -> bool:
		return pieces[n].tag in ["path","branch"] and pieces[n].role not in ["boss_arena","boss_ante","exit","merchant","cache","entrance"]
	func virtual_port(pt: Dictionary) -> Dictionary:
		return {"n":pt.n,"d":pt.get("d",{"side":pt.side,"cell":0,"gate":false}),"c":{"ox":pt.ox,"oy":pt.oy}}
	func attach(pt: Dictionary, pool: Array, more: bool) -> int:
		var fs=fits(pool,virtual_port(pt),more)
		if fs.is_empty(): return -1
		var real=apply_up(pt)
		var f=rng.weighted(fs,func(x): return x.e.p.weight)
		var b=place(f.e,f.v,f.cx,f.cy,"branch")
		link(pt.n,real,b,f.d,"branch")
		branches+=1
		if f.e.p.role=="merchant": merchants+=1
		return b
	func run() -> Dictionary:
		path_len=8+int(floor(rng.next()*5))
		var bmin=maxi(2,int(ceil(.4*(path_len-1))))
		var bmax=mini(path_len-3,int(floor(.7*(path_len-1))))
		breather_at=bmin+int(floor(rng.next()*(bmax-bmin+1)))
		var e=rng.pick(role_at(at(0)))
		var v=rng.pick(e.vars)
		var ok=false
		for t in 80:
			var x=int(floor(rng.next()*(grid-v.cw+1)))
			var y=int(floor(rng.next()*(grid-v.ch+1)))
			var c=PalUnderstripGen.door_cells(v,x,y,v.doors[0])
			var step=STEP[v.doors[0].side]
			if inside(c.ox,c.oy) and inside(c.ox+step[0],c.oy+step[1]):
				place(e,v,x,y,"path")
				ok=true
				break
		if not ok: return {}
		pieces[0].at=at(0)
		var cand={}
		var s=1
		var tries=0
		while s<path_len:
			tries+=1
			if tries>1500: return {}
			if not cand.has(s):
				var all=[]
				for o in open_doors(s-1): all.append_array(fits(role_at(at(s)),o,s!=path_len-1))
				if kind=="boss" and s==1: all=all.filter(func(f): return f.d.gate)
				cand[s]=all
			if cand[s].is_empty():
				cand.erase(s)
				if s==1: return {}
				unplace()
				s-=1
				continue
			var f=rng.weighted(cand[s],func(x): return x.e.p.weight)
			cand[s].erase(f)
			var n=place(f.e,f.v,f.cx,f.cy,"path")
			link(s-1,f.o.d,n,f.d,"path")
			pieces[n].at=at(s)
			s+=1
			cand.erase(s)
		if not shortcut(): return {}
		var nbmin=int(ceil(.3*path_len/(1-.3)))
		var nbmax=int(floor(.4*path_len/(1-.4)))
		var target=nbmin+int(floor(rng.next()*(nbmax-nbmin+1)))
		var inner=entries.filter(func(x): return x.p.role in ["corridor","junction","room"])
		var merchant=by_role("merchant")
		var cache=by_role("cache")
		for pt in rng.shuffle(ports(root_ok)):
			if attach(pt,merchant,false)>=0: break
		if merchants==0:
			for pt in rng.shuffle(ports(root_ok)):
				if merchants>0: break
				if fits(inner,virtual_port(pt),true).is_empty(): continue
				var b=attach(pt,inner,true)
				for p2 in ports(func(n): return n==b):
					if attach(p2,merchant,false)>=0: break
				if merchants==0: break
		for guard in 120:
			if branches>=target: break
			var opts=ports(root_ok)
			if opts.is_empty(): break
			var pt=rng.pick(opts)
			var length=mini(target-branches,1+int(floor(rng.next()*3)))
			for k in length:
				var last=k==length-1
				var pool=(merchant if rng.next()<.25 else cache) if last else inner
				var b=attach(pt,pool,not last)
				if b<0 and last: b=attach(pt,inner,false)
				if b<0 or last: break
				var nx=ports(func(n): return n==b)
				if nx.is_empty(): break
				pt=rng.pick(nx)
		if branches<nbmin or branches>nbmax or merchants==0: return {}
		return build()
	func build() -> Dictionary:
		var size=grid*CELL
		var tiles=[]
		for y in size: tiles.append("#".repeat(size))
		var rooms=[]
		for n in pieces.size():
			var p=pieces[n]
			var ox=p.cx*CELL
			var oy=p.cy*CELL
			for y in p.v.rows.size():
				for x in p.v.rows[0].length(): tiles[oy+y][ox+x]=p.v.rows[y][x]
			for d in p.v.doors:
				if linked(n,d): continue
				var c=PalUnderstripGen.door_cells(p.v,p.cx,p.cy,d)
				var lx=(c.x-p.cx)*CELL
				var ly=(c.y-p.cy)*CELL
				var cells={"N":[[3,0],[4,0]],"S":[[3,7],[4,7]],"W":[[0,3],[0,4]],"E":[[7,3],[7,4]]}[d.side]
				for xy in cells: tiles[oy+ly+xy[1]][ox+lx+xy[0]]="#"
			var light=0
			for item in kit.pieces:
				if item.id==p.id: light=item.light
			rooms.append({"id":p.id,"role":p.role,"tag":p.tag,"at":p.get("at",-1),"x":ox,"y":oy,"w":p.v.rows[0].length(),"h":p.v.rows.size(),"light":light,"opensFrom":p.v.opensFrom})
		var marks={}
		for y in size:
			for x in size:
				var c=tiles[y][x]
				if c in "PESMCABLnKG":
					if not marks.has(c): marks[c]=[]
					marks[c].append([x,y])
		return {"ok":true,"kind":kind,"G":grid,"T":size,"tiles":tiles,"rooms":rooms,"marks":marks,"links":links.map(func(l): return {"a":l.a,"b":l.b,"kind":l.kind}),"pathN":path_len,"branchN":branches,"breatherAt":breather_at,"pathLen":path_len}
