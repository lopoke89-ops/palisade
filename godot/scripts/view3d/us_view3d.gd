class_name UsView3D
extends Node3D
## Native tunnel geometry. Only exposed walls on screen are instanced each frame;
## walls between the camera and a soldier lower visually without changing collision.
## The props are the browser's (15b-understrip-look.js: usDrawShrine, usDrawMerchant, usDrawKeeper, usDrawChest,
## usDrawLift, usDrawDrop, usDrawFlare; 10j: usDrawLoot) built as low-poly pieces. What never changes (the shrines'
## cabinets, the traders, the lift's plate) is built once; what moves or lights up is rebuilt every frame.
const V3 = preload("res://scripts/view3d/view3d.gd")
const PX := V3.PXV   # one base pixel of the 2D's height
const RAR_COL := {"c": "#9a958a", "r": "#4f95e0", "e": "#b168e0", "l": "#e2b436", "g": "#ffe27a", "u": "#ff9260"}
var world
var weapon_loot := {}
var wall_instances: MultiMesh
var wall_node: MultiMeshInstance3D
var warning: MeshInstance3D
var live: MeshInstance3D   # the shaded props that change (chests, the Keeper, drops, flares, loot)
var walls_live: MeshInstance3D   # what's painted on the standing walls on screen
var haze: MeshInstance3D   # see-through: gas, water, acid, rings, wells, flashes
const WALL_COL := {1: "#55595b", 2: "#4e5140", 3: "#8a9298"}
var water: MeshInstance3D
var reg := 1   # the region: 1 the Flood Tunnels, 2 Shelter 7, 3 Area 67
var tags: Dictionary = {}   # wall tile -> its graffiti (built once, shown while the wall stands full height)

func _init(w):
	world=w
	name="Understrip"

func material(unshaded: bool=false, see_through: bool=false) -> StandardMaterial3D:
	var mat=StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.roughness=1.0
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	if unshaded: mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	if see_through:   # clouds and floor effects: the vertex colour's alpha, drawn after the solid world, no depth written
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
	return mat

func mesh(g: V3Mesh, mat: Material) -> MeshInstance3D:
	var node=MeshInstance3D.new()
	node.mesh=g.commit()
	node.material_override=mat
	add_child(node)
	return node

func build():
	var s=world.sim
	var floor_mesh=V3Mesh.new()
	var props=V3Mesh.new()
	var glow=V3Mesh.new()
	var flooded=V3Mesh.new()
	reg=PalUnderstrip.PLAN[clampi(int(s.game.us.level),0,9)][0]
	for y in s.N:
		for x in s.N:
			var tile=s.terr[y*s.N+x]
			if tile==PalMaps.T_CONC: continue
			var shade=.9+Pal.hash2(x,y)*.16
			var col=Color("#34383b")*Color(shade,shade,shade)
			if tile in [PalMaps.T_WATER,PalMaps.T_LOW]: col=Color("#173a3b")
			if tile==PalMaps.T_BRIDGE: col=Color("#665646")
			var hz: int=s.lay.haz[y*s.N+x] if s.lay.has("haz") else 0
			if reg==1 and hz==0: col=ground_col(tile,Pal.hash2(x,y))
			else: col=reg_ground(tile,hz,x,y,Pal.hash2(x,y))
			floor_mesh.quad(Vector3(x,0,y),Vector3(x,0,y+1),Vector3(x+1,0,y+1),Vector3(x+1,0,y),col)
			if tile in [PalMaps.T_GROUND,PalMaps.T_LOW]:
				if reg==1 and hz==0: ground_detail(floor_mesh,x,y,Pal.hash2(x,y))
				else: reg_detail(floor_mesh,hz,x,y,Pal.hash2(x,y))
			if tile==PalMaps.T_LOW: flooded.quad(Vector3(x,.06,y),Vector3(x,.06,y+1),Vector3(x+1,.06,y+1),Vector3(x+1,.06,y),Color("#276f7b"))
			if tile==PalMaps.T_JUNK: props.box(x+.1,y+.1,x+.9,y+.9,0,.5,Color("#584e42"),Color("#3b3932"),Color("#43423a"))
			if tile==PalMaps.T_TANK:
				props.prism(x+.5,y+.5,.42,0,.12,Color("#3a444c"),Color("#3a444c"),12)
				glow.prism(x+.5,y+.5,.36,.12,1.3,Color("#3f9c7c"),Color("#3f9c7c"),12)
				props.prism(x+.5,y+.5,.12,.5,.95,Color("#142828"),Color("#142828"),8,.08)
				props.prism(x+.5,y+.5,.42,1.3,1.42,Color("#3a444c"),Color("#4a545c"),12)
	for p in s.lay.lamps:
		props.box(p[0]-.08,p[1]-.08,p[0]+.08,p[1]+.08,0,1.0,Color("#55574c"),Color("#343831"),Color("#343831"))
		glow.box(p[0]-.12,p[1]-.12,p[0]+.12,p[1]+.12,1.0,1.15,Color("#ffca72"),Color("#ffca72"),Color("#ffca72"))
	for p in s.lay.shrines: shrine_cabinet(props,p)
	lift_plate(props,s.lay.exit)
	for merchant in s.lay.merchants:
		if merchant.kind!="keeper": trader(props,merchant)
	mesh(floor_mesh,material())
	mesh(props,material())
	mesh(glow,material(true))
	if flooded.size()>0: water=mesh(flooded,material(true))
	wall_instances=MultiMesh.new()
	wall_instances.transform_format=MultiMesh.TRANSFORM_3D
	wall_instances.use_colors=true
	wall_instances.mesh=BoxMesh.new()
	wall_instances.instance_count=s.N*s.N
	wall_node=MultiMeshInstance3D.new()
	wall_node.multimesh=wall_instances
	wall_node.material_override=material()
	add_child(wall_node)
	warning=MeshInstance3D.new()
	warning.material_override=material(true)
	add_child(warning)
	live=MeshInstance3D.new()
	live.material_override=material()
	add_child(live)
	walls_live=MeshInstance3D.new()
	walls_live.material_override=material()
	add_child(walls_live)
	haze=MeshInstance3D.new()
	haze.material_override=material(true,true)
	haze.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(haze)

# ---------------------------------------------------------------- the pieces that never change

## a neon shrine: a dark cabinet on a plinth (the browser's 22x20 px box); its neon frame and "7" light up in frame()
func shrine_cabinet(g: V3Mesh, p):
	g.box(p.x-.4,p.y-.2,p.x+.4,p.y+.2,0,.08,Color("#2a2926"),Color("#1f1e1c"),Color("#1a1918"))
	g.box(p.x-.33,p.y-.14,p.x+.33,p.y+.14,.08,.62,Color("#24231f"),Color("#1d1c1a"),Color("#171614"))
	g.box(p.x-.36,p.y-.17,p.x+.36,p.y+.17,.62,.68,Color("#34322d"),Color("#26241f"),Color("#201e1a"))

## the lift: a steel deck the size of its hold ring's middle, hazard stripes on the edge, a post at each corner
func lift_plate(g: V3Mesh, e):
	var x=e[0]
	var y=e[1]
	g.box(x-.85,y-.85,x+.85,y+.85,0,.03,Color("#3d4240"),Color("#2c302e"),Color("#262a28"))
	for i in 6:   # the deck's grating
		var k=-.65+i*.26
		g.box(x-.75,y+k-.02,x+.75,y+k+.02,.03,.035,Color("#2a2e2c"),Color("#2a2e2c"),Color("#2a2e2c"))
	for i in 8:   # black-and-yellow edge, south and east (the sides the camera sees)
		var a=-.85+i*.2125
		var c=Color("#c8a03a") if i%2==0 else Color("#1a1a16")
		g.box(x+a,y+.78,x+a+.2125,y+.85,.03,.04,c,c,c)
		g.box(x+.78,y+a,x+.85,y+a+.2125,.03,.04,c,c,c)
	for q in [[-1,-1],[1,-1],[-1,1],[1,1]]:
		g.prism(x+q[0]*.8,y+q[1]*.8,.05,0,.9,Color("#4a4f4c"),Color("#c8a03a"),6)
		g.box(x+q[0]*.8-.06,y+q[1]*.8-.06,x+q[0]*.8+.06,y+q[1]*.8+.06,.9,.96,Color("#c8a03a"),Color("#9a7a2a"),Color("#8a6a22"))

## a trader, the lift man or the Collector, standing facing the camera; a mat of wares in front (no mat for the Collector)
func trader(g: V3Mesh, m):
	var look={"body":"#5a4a6a","vest":"#2a2233","pants":"#2c2a30","head":"#b08a6a","hat":"#1a1620"}
	if m.kind=="collector": look={"body":"#141418","vest":"#e8e2d0","pants":"#141418","head":"#c8b8a8","hat":"#0e0e12"}
	elif m.kind=="lift": look={"body":"#4a5a3a","vest":"#2e3a24","pants":"#2a3024","head":"#a98262","cap":"#c8a03a"}
	var x=m.x
	var y=m.y
	var c=func(k): return Color(look[k])
	g.box(x-.13,y-.06,x-.02,y+.06,0,.36,c.call("pants"),c.call("pants"),c.call("pants").darkened(.15))   # legs
	g.box(x+.02,y-.06,x+.13,y+.06,0,.36,c.call("pants"),c.call("pants"),c.call("pants").darkened(.15))
	g.box(x-.15,y-.08,x+.15,y+.08,.36,.7,c.call("body"),c.call("body"),c.call("body").darkened(.15))   # coat
	g.box(x-.09,y+.08,x+.09,y+.09,.4,.68,c.call("vest"),c.call("vest"),c.call("vest"))   # vest or shirt front
	g.box(x-.21,y-.05,x-.15,y+.05,.42,.68,c.call("body"),c.call("body"),c.call("body").darkened(.15))   # arms
	g.box(x+.15,y-.05,x+.21,y+.05,.42,.68,c.call("body"),c.call("body"),c.call("body").darkened(.15))
	g.box(x-.08,y-.08,x+.08,y+.08,.7,.88,c.call("head"),c.call("head"),c.call("head").darkened(.12))   # head
	g.box(x-.05,y+.08,x-.02,y+.085,.8,.83,Color("#1a1410"),Color("#1a1410"),Color("#1a1410"))   # eyes
	g.box(x+.02,y+.08,x+.05,y+.085,.8,.83,Color("#1a1410"),Color("#1a1410"),Color("#1a1410"))
	if look.has("cap"):
		g.box(x-.09,y-.09,x+.09,y+.09,.86,.94,c.call("cap"),c.call("cap"),c.call("cap").darkened(.15))
		g.box(x-.08,y+.09,x+.08,y+.17,.86,.88,c.call("cap"),c.call("cap"),c.call("cap").darkened(.15))   # the peak
	else:
		g.box(x-.14,y-.14,x+.14,y+.14,.86,.88,c.call("hat"),c.call("hat"),c.call("hat"))   # brim
		g.box(x-.08,y-.08,x+.08,y+.08,.88,1.02,c.call("hat"),c.call("hat"),c.call("hat").lightened(.06))
	if m.kind=="collector":
		g.box(x-.04,y+.085,x+.04,y+.095,.66,.7,Color("#c42a3a"),Color("#c42a3a"),Color("#c42a3a"))   # the red bow tie
		return
	g.box(x-.32,y+.22,x+.32,y+.42,0,.03,Color("#3a2a20"),Color("#2c2018"),Color("#241a12"))   # the mat, and what's on it
	for i in 4:
		var wx=x-.24+i*.16
		var col=Color(["#8a8f96","#e2b436","#6a4a30","#4f95e0"][i])
		g.box(wx-.05,y+.27,wx+.05,y+.37,.03,.08+.03*(i%2),col,col.darkened(.2),col.darkened(.3))

# ---------------------------------------------------------------- every frame

func frame():
	var s=world.sim
	var count=0
	var lv_walls=V3Mesh.new()
	for y in range(world.vis[2],world.vis[3]+1):
		for x in range(world.vis[0],world.vis[1]+1):
			var k=y*s.N+x
			var tile=s.terr[k]
			if tile!=PalMaps.T_SHUT and not (tile==PalMaps.T_CONC and s.lay.edges[k]): continue
			var height=1.25
			for p in s.players.values():
				var dd=x+y+1-(p.x+p.y)
				var lat=(x-y)-(p.x-p.y)
				if (p.alive or p.downed) and dd>0 and dd<3.5 and absf(lat)<1.8: height=.28
			var xf=Transform3D(Basis.from_scale(Vector3(1,height,1)),Vector3(x+.5,height*.5,y+.5))
			wall_instances.set_instance_transform(count,xf)
			var wc=Color(WALL_COL[reg])
			if tile==PalMaps.T_SHUT:
				var hz2: int=s.lay.haz[k] if s.lay.has("haz") else 0
				wc=Color("#5a5c50") if hz2==UsDeep.HZ_BLAST else (Color("#5a1c16") if [x,y] in s.lay.gate else Color("#665b3d"))
			wall_instances.set_instance_color(count,wc)
			count+=1
			if tile==PalMaps.T_CONC and height>1:   # its paint, built the first time the wall is on screen
				var paint: V3Mesh=tags.get(k)
				if paint==null:
					paint=V3Mesh.new()
					wall_face(paint,x,y,k)
					tags[k]=paint
				lv_walls.verts.append_array(paint.verts)
				lv_walls.norms.append_array(paint.norms)
				lv_walls.cols.append_array(paint.cols)
				lv_walls.uv2.append_array(paint.uv2)
	wall_instances.visible_instance_count=count
	walls_live.mesh=lv_walls.commit() if lv_walls.size()>0 else null
	if water!=null: water.visible=s.flood_on
	var U=s.game.us
	var t: float=s.game.time
	var g=V3Mesh.new()   # unshaded: neon, rings, flames, telegraphs
	var lv=V3Mesh.new()   # shaded props
	for n in s.lay.shrines.size(): shrine_neon(g,s.lay.shrines[n],n,U,t)
	lift_ring(g,s.lay.exit,U,t)
	for n in s.lay.chests.size():
		if not (int(U.chests)&(1<<n)): chest(lv,s.lay.chests[n])
	for m in s.lay.merchants:
		if m.kind=="keeper": keeper(lv,g,m,t)
	var loot_alive={}
	for item in U.loot:
		loot(lv,g,item,t)
		if item.kind=="weapon": loot_alive[item.n]=true
	for id in weapon_loot.keys():
		if not loot_alive.has(id):
			weapon_loot[id].queue_free()
			weapon_loot.erase(id)
	for drop in U.drops: salvage(lv,drop,t)
	for f in U.flares: flare(lv,g,f,t)
	for e in s.enemies:
		if not e.dead and e.get("elite",false):
			if e.elite=="charger" and e.est==1:
				var side=Vector2(e.lx-e.x,e.ly-e.y).normalized().orthogonal()*.5
				g.quad(Vector3(e.x+side.x,.04,e.y+side.y),Vector3(e.lx+side.x,.04,e.ly+side.y),Vector3(e.lx-side.x,.04,e.ly-side.y),Vector3(e.x-side.x,.04,e.y-side.y),Color("#f29942"))
			elif e.elite=="caller" and e.est in [1,2]:
				g.disc(e.lx,e.ly,1.5,1.5,.045,Color("#e45434") if e.est==2 else Color("#b49434"),32)
		if e.dead or e.get("boss","")!="pitboss": continue
		var col=Color("#ea5639")
		if e.st in [1,61]:
			var radius=1.8 if e.st==1 else 5.0
			var half=.9 if e.st==1 else .45
			var a=e.aim.angle() if e.st==1 else atan2(e.ly-e.y,e.lx-e.x)
			for i in 16:
				var aa=a+(i/16.0*2-1)*half
				var bb=a+((i+1)/16.0*2-1)*half
				g.tri(Vector3(e.x,.04,e.y),Vector3(e.x+cos(aa)*radius,.04,e.y+sin(aa)*radius),Vector3(e.x+cos(bb)*radius,.04,e.y+sin(bb)*radius),col,Vector3.UP)
		elif e.st==2:
			var side=Vector2(e.lx-e.x,e.ly-e.y).normalized().orthogonal()*.6
			g.quad(Vector3(e.x+side.x,.04,e.y+side.y),Vector3(e.lx+side.x,.04,e.ly+side.y),Vector3(e.lx-side.x,.04,e.ly-side.y),Vector3(e.x-side.x,.04,e.y-side.y),col)
	var hz=V3Mesh.new()
	deep(g,hz,lv,s,U,t)
	if int(world.m.settings.data.get("usBright",0))>=3: bright_marks(g,s)
	warning.mesh=g.commit() if g.size()>0 else null
	live.mesh=lv.commit() if lv.size()>0 else null
	haze.mesh=hz.commit() if hz.size()>0 else null

## dark to full: how a light at strength f shows on the unshaded layer (no blending there, so it dims toward the dark)
static func dim(col: Color, f: float) -> Color:
	return Color("#141312").lerp(col,clampf(f,0,1))

## the shrine's pink neon frame and yellow "7": flickering until you rest there, steady (with a hum) once lit,
## barely on in a boss arena until the boss is down; a pink ring on the floor round the one you last rested at
func shrine_neon(g: V3Mesh, p, n: int, U, t: float):
	var on=bool(int(U.lit)&(1<<n))
	var sleep=p.arena and not U.bossDown
	var fl=.15 if sleep else (.85+.15*sin(t*9+n) if on else .35+.3*maxf(0,sin(t*3.1+n*2)*sin(t*7.3)))
	var pink=dim(Color("#ff5ad8"),fl)
	var yel=dim(Color("#ffe278"),fl)
	var z=p.y+.145
	var x0=p.x-.28
	var x1=p.x+.28
	g.bar(Vector3(x0,.14,z),Vector3(x1,.14,z),.022,pink)
	g.bar(Vector3(x0,.56,z),Vector3(x1,.56,z),.022,pink)
	g.bar(Vector3(x0,.14,z),Vector3(x0,.56,z),.022,pink)
	g.bar(Vector3(x1,.14,z),Vector3(x1,.56,z),.022,pink)
	g.bar(Vector3(p.x-.1,.47,z+.01),Vector3(p.x+.1,.47,z+.01),.025,yel)   # the 7
	g.bar(Vector3(p.x+.1,.47,z+.01),Vector3(p.x-.03,.22,z+.01),.025,yel)
	var xe=p.x+.335   # the side panel's strip
	g.bar(Vector3(xe,.14,p.y-.1),Vector3(xe,.56,p.y-.1),.016,pink)
	g.bar(Vector3(xe,.14,p.y+.1),Vector3(xe,.56,p.y+.1),.016,pink)
	if int(U.rest.ix)==n: ring(g,p.x,p.y,.9,.035,.012,Color("#ff5ad8").darkened(.35),40)

## the lift's hold ring (1.6 tiles: everyone inside for three seconds): dashed, green and breathing when it's open,
## grey while a boss stands; a solid green arc fills round it as the hold counts up
func lift_ring(g: V3Mesh, e, U, t: float):
	var open=PalUnderstrip.PLAN[int(U.level)][1]!="boss" or U.bossDown
	var col=dim(Color("#7cff6b"),.45+.25*sin(t*3)) if open else Color("#3a3a36")
	var R=1.6
	var segs=24
	for i in segs:
		var a0=TAU*i/segs
		var a1=a0+TAU/segs*.55
		arc(g,e[0],e[1],R,.05,a0,a1,.015,col,3)
	var f=float(U.exitT)/3.0
	if f>0: arc(g,e[0],e[1],R,.09,-PI/2,-PI/2+f*TAU,.02,Color("#7cff6b"),maxi(3,int(f*48)))

static func ring(g: V3Mesh, cx: float, cy: float, R: float, w: float, y: float, col: Color, n: int):
	arc(g,cx,cy,R,w,0,TAU,y,col,n)

static func arc(g: V3Mesh, cx: float, cy: float, R: float, w: float, a0: float, a1: float, y: float, col: Color, n: int):
	for i in n:
		var p=a0+(a1-a0)*i/n
		var q=a0+(a1-a0)*(i+1)/n
		g.quad(Vector3(cx+cos(p)*(R-w),y,cy+sin(p)*(R-w)),Vector3(cx+cos(p)*(R+w),y,cy+sin(p)*(R+w)),Vector3(cx+cos(q)*(R+w),y,cy+sin(q)*(R+w)),Vector3(cx+cos(q)*(R-w),y,cy+sin(q)*(R-w)),col)

## a strongbox: a wooden chest with iron bands and a brass latch (the browser's box, WH*.38 tall), gone once opened
func chest(g: V3Mesh, k):
	var h=V3.WALL_H*.38
	g.box(k.x-.3,k.y-.2,k.x+.3,k.y+.2,0,h*.62,Color("#7a5a30"),Color("#5a4224"),Color("#4a361c"))
	g.box(k.x-.32,k.y-.22,k.x+.32,k.y+.22,h*.62,h,Color("#86643a"),Color("#634a28"),Color("#523d20"))   # the lid
	for bx in [-.2,.2]:
		g.box(k.x+bx-.03,k.y-.225,k.x+bx+.03,k.y+.225,0,h+.005,Color("#3a3a36"),Color("#2e2e2a"),Color("#262622"))
	g.box(k.x-.05,k.y+.22,k.x+.05,k.y+.235,h*.45,h*.8,Color("#e2b436"),Color("#e2b436"),Color("#b88c22"))

## the Shrine Keeper: a squat cleaning robot with one lamp eye and a mop on an arm, bobbing as it idles
func keeper(g: V3Mesh, glow: V3Mesh, m, t: float):
	var b=sin(t*2)*.025
	var x=m.x
	var y=m.y
	g.disc(x,y,.26,.18,.01,Color("#151515"),12)
	g.prism(x,y,.2,.02+b,.12+b,Color("#5c6268"),Color("#5c6268"),8)
	g.box(x-.2,y-.16,x+.2,y+.16,.12+b,.46+b,Color("#9aa0a8"),Color("#8a9098"),Color("#727880"))
	g.box(x-.13,y+.16,x+.13,y+.17,.3+b,.42+b,Color("#2a2e32"),Color("#2a2e32"),Color("#2a2e32"))   # the visor
	var eye=dim(Color("#7cd8ff"),.7+.3*sin(t*5))
	glow.box(x-.04,y+.17,x+.04,y+.18,.33+b,.39+b,eye,eye,eye)
	g.prism(x,y,.03,.46+b,.56+b,Color("#5c6268"),Color("#e45434"),5)   # the antenna and its tip
	var sh=Vector3(x+.2,.32+b,y)
	var hand=Vector3(x+.42,.04,y+.22)
	g.bar(sh,hand,.022,Color("#6a5a40"))
	g.box(hand.x-.11,hand.z-.05,hand.x+.11,hand.z+.05,0,.05,Color("#c8c0a0"),Color("#a8a080"),Color("#989070"))

## salvage a raider dropped: a sack with a gold tag, bobbing over a gold glow
func salvage(g: V3Mesh, d, t: float):
	var b=sin(t*4)*.04
	g.disc(d.x,d.y,.28,.2,.012,Color("#5a4a1e"),14)
	g.prism(d.x,d.y,.13,.04+b,.2+b,Color("#cbbf9f"),Color("#b8ac8c"),8,.1)
	g.prism(d.x,d.y,.1,.2+b,.26+b,Color("#b8ac8c"),Color("#a89c7c"),8,.04)
	g.box(d.x-.04,d.y+.1,d.x+.04,d.y+.13,.2+b,.27+b,Color("#e2b436"),Color("#e2b436"),Color("#b88c22"))

## a road flare: a red stick standing in the floor, its tip spitting while it burns
func flare(g: V3Mesh, glow: V3Mesh, f, t: float):
	g.box(f.x-.03,f.y-.03,f.x+.03,f.y+.03,0,.2,Color("#c42a1a"),Color("#a82416"),Color("#8a1e12"))
	if f.t>0:
		var c=Color(1,(120+randf()*80)/255.0,80/255.0)
		var r=.06+.015*sin(t*40+f.x)
		glow.prism(f.x,f.y,r,.2,.28,c,c,6,.01)
		glow.disc(f.x,f.y,.5,.5,.01,dim(Color("#c42a1a"),.35+.1*sin(t*20+f.x)),16)

## loot on the floor: a ring in its rarity's colour round a shadow, the piece bobbing over it (a gun, a perk's orb,
## a relic's diamond, a crate for anything else)
func loot(g: V3Mesh, glow: V3Mesh, l, t: float):
	var col=Color(loot_col(l))
	var b=sin(t*3+float(l.get("n",0)))*.05
	g.disc(l.x,l.y,.24,.17,.012,Color("#111110"),12)
	ring(glow,l.x,l.y,.32+b*.4,.025,.02,col,28)
	var y=.18+b
	if l.kind=="weapon":
		var node: Node3D=weapon_loot.get(l.n)
		if node==null or node.get_meta("weapon_id","")!=l.w.id:
			if node!=null: node.queue_free()
			node=UsWeapons.build(l.w.id)
			node.scale=Vector3.ONE*.7
			add_child(node)
			weapon_loot[l.n]=node
		node.position=Vector3(l.x,y+.12,l.y-.12)
		node.rotation=Vector3(0,t*.25+float(l.n),-.25)
	elif l.kind=="perk":
		glow.prism(l.x,l.y,.1,y,y+.12,col,col,10,.1)
		glow.prism(l.x,l.y,.1,y+.12,y+.2,col,col,10,.02)
		glow.prism(l.x,l.y,.02,y-.06,y,col,col,10,.1)
	elif l.kind=="relic":
		glow.prism(l.x,l.y,.12,y+.12,y+.28,col,col,4,.0)
		glow.prism(l.x,l.y,.0,y-.02,y+.12,col,col,4,.12)
	else:
		g.box(l.x-.12,l.y-.09,l.x+.12,l.y+.09,y,y+.16,col,col.darkened(.2),col.darkened(.3))

# ---------------------------------------------------------------- Shelter 7 and Area 67 (10k)

## usRegGround: the hazard floors, the door tracks, then the region's three shades
func reg_ground(tile: int, hz: int, x: int, y: int, h: float) -> Color:
	if tile==PalMaps.T_WATER: return Color("#16303c") if h<.5 else Color("#142b36")
	if tile==PalMaps.T_BRIDGE: return Color("#4a463c")
	if hz==UsDeep.HZ_ACID: return Color("#2f5a1e") if h<.5 else Color("#2a5219")
	if hz==UsDeep.HZ_RAD: return Color("#3a3a1e") if h<.5 else Color("#36361c")
	if hz==UsDeep.HZ_GRAV: return Color("#2a3448") if h<.5 else Color("#283244")
	if hz==UsDeep.HZ_GAS: return Color("#26281f")
	if hz==UsDeep.HZ_BLAST: return Color("#3a2a14") if (x+y)&1 else Color("#1e1a14")
	var F=[["#30322d","#2c2e29","#292b26"],["#30312a","#2d2e27","#2a2b24"],["#363b40","#33383d","#30353a"]][reg-1]
	return Color(F[0 if h<.2 else (1 if h<.75 else 2)])

## usRegDetail: radiation trefoils, vent grates, low-gravity rings, alien growth, lab tiles, painted lines
func reg_detail(g: V3Mesh, hz: int, x: int, y: int, h: float):
	var cx=x+.5
	var cy=y+.5
	if hz==UsDeep.HZ_RAD and h>.82:
		for k in 3:
			var a=k*2.094+.5
			for i in 4:
				var p=a+i*.225
				var q=a+(i+1)*.225
				g.tri(Vector3(cx,.004,cy),Vector3(cx+cos(q)*.22,.004,cy+sin(q)*.22),Vector3(cx+cos(p)*.22,.004,cy+sin(p)*.22),Color("#6a6424"),Vector3.UP)
	elif hz==UsDeep.HZ_GAS:   # a grate
		for k in range(-2,3):
			flat_line(g,Vector3(x+.15,.004,cy+k*.12),Vector3(x+.85,.004,cy+k*.12),.018,Color("#141612"))
	elif hz==UsDeep.HZ_GRAV and h>.7:
		arc(g,cx,cy,.4,.012,0,TAU,.004,Color("#3a4a6a"),20)
	elif reg==3 and h>.93:   # alien growth through the floor
		g.disc(cx+.1,cy,.24,.16,.004,Color("#3a2a44"),10)
		g.disc(cx-.06,cy+.04,.13,.08,.006,Color("#2e5a2c"),8)
	elif reg==3 and h<.5 and (x+y)%4==0:   # lab floor tiles
		flat_line(g,Vector3(x,.003,y+1),Vector3(x+1,.003,y+1),.008,Color("#3a3f44"))
	elif reg==2 and h>.9:   # a painted line
		flat_line(g,Vector3(cx-.18,.004,cy),Vector3(cx+.18,.004,cy),.035,Color("#5a3a1e"))

## what a boss leaves on the floor and how his moves are telegraphed (see-through fills in hz, strokes in g), the
## vents' gas and the blast doors' warnings, Area 67's drones (in lv)
func deep(g: V3Mesh, hz: V3Mesh, lv: V3Mesh, s, U, t: float):
	var pulse=.5+.5*sin(t*14)
	if s.lay.has("vents") and U.has("vents"):
		for n in s.lay.vents.size():
			var st=int(U.vents[n].s)
			if st==0: continue
			var v=s.lay.vents[n]
			for k in v.cloud:
				if (k*7)%3: continue
				var x=k%s.N+.5
				var y=int(k/s.N)+.5
				var a=.22 if st==2 else .08+.06*sin(t*8)
				var col=Color(150/255.0,210/255.0,70/255.0,a)
				var bob=.03*sin(t*1.7+k)
				hz.prism(x+sin(t+k)*.08,y,.62,.04,.22+bob,col,col,10,.5)   # a low, flat cloud hugging the floor
				hz.prism(x+sin(t+k)*.08,y,.5,.22+bob,.34+bob,col,col,10,.22)
	if s.lay.has("blast") and U.has("blast"):
		for n in s.lay.blast.size():
			if int(U.blast[n])!=1: continue
			for tt in s.lay.blast[n].tiles:
				hz.disc(tt[0]+.5,tt[1]+.5,.45,.45,.03,Color(1,170/255.0,40/255.0,.25+.25*sin(t*14)),12)
	for f in U.get("bfx",[]):
		var w=minf(1.0,f.t/f.warn) if f.warn>0 else 1.0
		var live: bool=f.t>=f.warn
		match f.k:
			"water":
				wedge(hz,f.x,f.y,f.a,f.r,f.half,Color(90/255.0,170/255.0,1,.16+.08*sin(t*30)),.03)
				for i in 3:
					var a=f.a+(randf()-.5)*2*f.half
					var d=randf()*f.r
					g.box(f.x+cos(a)*d-.03,f.y+sin(a)*d-.03,f.x+cos(a)*d+.03,f.y+sin(a)*d+.03,.03,.06,Color("#c8ebff"),Color("#c8ebff"),Color("#c8ebff"))
			"gas":
				var col=Color(150/255.0,210/255.0,70/255.0,.26 if live else .06+.16*w)
				hz.quad(Vector3(f.x,.05,f.y),Vector3(f.x,.05,f.y1),Vector3(f.x1,.05,f.y1),Vector3(f.x1,.05,f.y),col)
				if live:
					for i in 10:
						var px=f.x+(f.x1-f.x)*fmod(i*.37+.1,1.0)
						var py=f.y+(f.y1-f.y)*fmod(i*.61+.3,1.0)
						hz.prism(px+sin(t+i)*.1,py,.6,.05,.3,Color(150/255.0,210/255.0,70/255.0,.14),Color(150/255.0,210/255.0,70/255.0,.14),10,.35)
				for e in [[f.x,f.y,f.x1,f.y],[f.x1,f.y,f.x1,f.y1],[f.x1,f.y1,f.x,f.y1],[f.x,f.y1,f.x,f.y]]:
					flat_line(g,Vector3(e[0],.06,e[1]),Vector3(e[2],.06,e[3]),.025,dim(Color("#b4e65a"),.5+.4*pulse if not live else .5))
			"ring":
				if not live:
					arc(g,f.x,f.y,.9,.05,0,TAU,.05,dim(Color("#b8a8ff"),.4+.5*pulse),32)
				else:
					var R=(f.t-f.warn)*UsDeep.VIS.pulse.speed
					arc(hz,f.x,f.y,R,UsDeep.VIS.pulse.w,0,TAU,.06,Color(184/255.0,168/255.0,1,.55),48)
					arc(g,f.x,f.y,R,.02,0,TAU,.07,Color("#e8e2ff"),48)
			"acid":
				if live:
					hz.disc(f.x,f.y,f.r,f.r,.04,Color(124/255.0,1,107/255.0,.3),24)
					for i in 3:
						var a=t*2+i*2.1
						g.prism(f.x+cos(a)*f.r*.5,f.y+sin(a*1.3)*f.r*.5,.05,.04,.08,Color("#c8ffa0"),Color("#c8ffa0"),6)
			"circle":
				if not live:
					arc(g,f.x,f.y,f.r,.035,0,TAU,.05,dim(Color("#ff3c28"),.55+.35*pulse),40)
					hz.disc(f.x,f.y,f.r*w,f.r*w,.045,Color(10/255.0,20/255.0,20/255.0,.2+.4*w) if f.get("tank",false) else Color(1,60/255.0,40/255.0,.12+.18*w),32)
			"well":
				var R2=UsDeep.VIS.well.r
				for i in 24:
					var a0=TAU*i/24-t*1.2
					arc(g,f.x,f.y,R2,.03,a0,a0+TAU/24*.55,.05,dim(Color("#b8a8ff"),.6 if live else .3+.4*pulse),2)
				if live:
					for i in 6:
						var r2=R2*(1-fmod(t*.6+i/6.0,1.0))
						var a=t*3+i*1.05
						arc(hz,f.x,f.y,r2,.04,a,a+1.2,.05,Color(184/255.0,168/255.0,1,.35),8)
					hz.disc(f.x,f.y,UsDeep.VIS.well.core,UsDeep.VIS.well.core,.05,Color(120/255.0,90/255.0,1,.35),24)
			"turret":
				if not live:
					g.bar(Vector3(f.x,.6,f.y),Vector3(f.x1,.6,f.y1),.02,dim(Color("#ff3c28"),.45+.4*pulse))
			"blink":
				var R3=UsDeep.VIS.blink.r
				hz.disc(f.x,f.y,R3*w,R3*w,.05,Color(1,1,1,.25+.55*w),32)
				arc(g,f.x,f.y,R3,.03,0,TAU,.06,Color("#ffffff"),40)
	for e in s.enemies:
		if e.dead: continue
		if e.type=="drone":
			drone(lv,g,e,s)
			continue
		if e.type!="boss" or e.get("boss","")=="pitboss": continue
		var st=int(e.get("st",0))
		if st==63:   # the mop arc
			wedge(hz,e.x,e.y,atan2(e.ly-e.y,e.lx-e.x),UsDeep.CUS.mop.r,UsDeep.CUS.mop.half,Color(120/255.0,200/255.0,1,.16+.2*pulse),.04)
		elif st in [64,72,82]:   # a stage change
			var f2=1.0-e.stT/maxf(.01,e.stM)
			arc(g,e.x,e.y,1.2+f2*.6,.04,0,TAU,.05,dim(Color({64:"#ff3a2a",72:"#7cff6b",82:"#b8a8ff"}[st]),.4+.4*pulse),40)
		elif st==71:   # the stomp
			var f3=1.0-e.stT/maxf(.01,e.stM)
			arc(g,e.x,e.y,UsDeep.GK.stomp.r,.035,0,TAU,.05,dim(Color("#ff3c28"),.55+.3*pulse),40)
			arc(g,e.x,e.y,UsDeep.GK.stomp.r*(1-f3*.6),.025,0,TAU,.05,dim(Color("#ff3c28"),.3),40)
		elif st==74:   # the pilot's sidearm line
			g.bar(Vector3(e.x,.5,e.y),Vector3(e.lx,.5,e.ly),.012,dim(Color("#ff3c28"),.5+.3*pulse))
		if int(e.get("ub",0))&1:   # the Gatekeeper's raised shield: a pale arc in front of him
			var a=e.aim.angle()
			arc(hz,e.x,e.y,.85,.06,a-.8,a+.8,.4,Color(154/255.0,216/255.0,1,.35),12)

## a wedge on the floor: a fan from (x, y) along a0, radius r, half-angle half
static func wedge(g: V3Mesh, x: float, y: float, a0: float, r: float, half: float, col: Color, h: float):
	for i in 12:
		var a=a0+(i/12.0-.5)*2*half
		var b=a0+((i+1)/12.0-.5)*2*half
		g.tri(Vector3(x,h,y),Vector3(x+cos(b)*r,h,y+sin(b)*r),Vector3(x+cos(a)*r,h,y+sin(a)*r),col,Vector3.UP)

## a drone: a dark lens hovering over its own shadow, a green ring round it (pale in your light), its eye on you
func drone(g: V3Mesh, glow: V3Mesh, e, s):
	var h=V3.WALL_H*(.55+.08*sin(e.walk))*1.6
	var lit: bool=e.get("lit",false)
	g.disc(e.x,e.y,.2,.14,.01,Color("#111110"),10)
	var body=Color("#e8ffe0") if e.flash>0 else Color("#1c2620")
	g.prism(e.x,e.y,.17,h-.06,h+.06,body,body.lightened(.1),10,.12)
	arc(glow,e.x,e.y,.24,.025,0,TAU,h,Color("#d8ff9a") if lit else Color("#7cff6b"),16)
	glow.prism(e.x+e.aim.x*.12,e.y+e.aim.y*.12,.04,h-.02,h+.04,Color("#b8ff7a"),Color("#b8ff7a"),6)

# ---------------------------------------------------------------- the Flood Tunnels' look

## usGroundCol: the floor's three shades, the low ground's, water, bridges
static func ground_col(tile: int, h: float) -> Color:
	if tile==PalMaps.T_WATER: return Color("#16303c") if h<.5 else Color("#142b36")
	if tile==PalMaps.T_BRIDGE: return Color("#4a463c")
	if tile==PalMaps.T_LOW: return Color("#2c3532") if h<.33 else (Color("#2a322f") if h<.66 else Color("#28302d"))
	return Color("#30322d") if h<.2 else (Color("#2c2e29") if h<.75 else Color("#292b26"))

## usGroundDetail: a crack, a puddle (catching the grates' neon), or spilt paint, by the tile's hash
static func ground_detail(g: V3Mesh, x: int, y: int, h: float):
	if h>.9:
		var cx=x+.3+h*.4
		var cy=y+.5
		var a=Vector3(cx-.18,.004,cy+.06)
		var b=Vector3(cx+.04,.004,cy-.04)
		var c=Vector3(cx+.2,.004,cy+.05)
		flat_line(g,a,b,.012,Color("#1c1c1a"))
		flat_line(g,b,c,.012,Color("#1c1c1a"))
	elif h<.06:
		g.disc(x+.5,y+.5,.3,.22,.004,Color("#22343a"),14)
		if h<.03: g.disc(x+.53,y+.5,.18,.07,.006,Color("#5a3150") if h<.015 else Color("#244a58"),12)
	elif h>.8 and h<.83:
		g.disc(x+.5,y+.5,.26,.18,.004,[Color("#4a2a42"),Color("#4a4226"),Color("#2e4a2a")][(x+y)%3],12)

static func flat_line(g: V3Mesh, a: Vector3, b: Vector3, w: float, col: Color):
	var d=(b-a).normalized()
	var n=Vector3(-d.z,0,d.x)*w
	g.quad(a-n,a+n,b+n,b-n,col)

## usTagOf: which walls carry a tag, about 3 in 5, a style from the tile's own hash (0: none)
static func tag_of(k: int) -> int:
	var h:=mul32(k,2654435761)
	h^=h>>15
	h=mul32(h,2246822519)
	h^=h>>13
	var n:=h%5
	return 0 if n<2 else n-1

## a*b mod 2^32 without overflowing GDScript's 64-bit ints (Math.imul's low bits)
static func mul32(a: int, b: int) -> int:
	a&=0xffffffff
	var lo:=(a*(b&0xffff))&0xffffffff
	var hi:=((a*((b>>16)&0xffff))&0xffff)<<16
	return (lo+hi)&0xffffffff

## a standing tunnel wall's paint: concrete courses and a flood line on both faces the camera sees, and its tag
func wall_face(g: V3Mesh, x: int, y: int, k: int):
	var H=1.25
	var L=func(s: float,f: float) -> Vector3: return Vector3(x+s,f*H,y+1.003)   # the south face, west to east
	var R=func(s: float,f: float) -> Vector3: return Vector3(x+1.003,f*H,y+1-s)   # the east face, south to north
	var dark=Color(WALL_COL[reg]).darkened(.35)
	for F in [L,R]:
		for f in [.35,.7]: face_line(g,F,[[0,f],[1,f]],.008,dark)
		face_line(g,F,[[0,.1],[1,.1]],.008,Color(WALL_COL[reg]).lightened(.08))
		if reg==2: face_line(g,F,[[0,.5],[1,.5]],.025,Color("#a8642a"),.001)   # Shelter 7's orange band
	if reg==3:   # growth up the lab wall
		face_line(g,L,[[.2,.2],[.28,.42],[.38,.62],[.5,.8]],.018,Color("#5aa050"),.001)
	if reg!=1: return
	var v=tag_of(k)
	if v==1:   # a bubble tag: a fat pink loop with a cyan outline and a highlight
		var P=[[.14,.32],[.24,.62],[.36,.34],[.46,.6],[.58,.3],[.7,.58],[.84,.36]]
		face_line(g,L,P,.07,Color("#3f8faa"),.001)
		face_line(g,L,P,.044,Color("#c2489f"),.002)
		face_line(g,L,P.slice(1,4).map(func(q): return [q[0],q[1]+.04]),.012,Color("#e8c8dc"),.003)
	elif v==2:   # a yellow zigzag with drips, and an orange underline
		var P=[[.12,.62],[.26,.42],[.4,.66],[.54,.4],[.68,.64],[.84,.44]]
		face_line(g,R,P,.034,Color("#c8a63a"),.002)
		for q in [P[1],P[3],P[5]]: face_line(g,R,[q,[q[0],q[1]-.2-q[0]*.12]],.016,Color("#c8a63a"),.002)
		face_line(g,R,[[.1,.3],[.88,.3]],.024,Color("#c2703a"),.002)
	elif v==3:   # a green star and a violet scrawl across both faces
		var c: Vector3=L.call(.3,.5)
		var r=H*.16
		for i in 10:
			var a0=-PI/2+i*PI/5
			var a1=-PI/2+(i+1)*PI/5
			var r0=r*(.45 if i%2 else 1.0)
			var r1=r*(.45 if (i+1)%2 else 1.0)
			g.tri(c+Vector3(cos(a0)*r0*1.3*.8,-sin(a0)*r0,.002),c+Vector3(cos(a1)*r1*1.3*.8,-sin(a1)*r1,.002),c+Vector3(0,0,.002),Color("#62b450"),Vector3(0,0,1))
		face_line(g,L,[[.55,.62],[.66,.38],[.78,.6],[.9,.4]],.03,Color("#8a6ac2"),.002)
		face_line(g,R,[[.06,.42],[.2,.62],[.34,.36],[.5,.56]],.03,Color("#8a6ac2"),.002)

## a painted stroke along a wall face: F maps (along, up) to the face; quads in the face's plane, lifted off it a hair
static func face_line(g: V3Mesh, F: Callable, pts: Array, w: float, col: Color, lift: float = 0.0):
	for i in pts.size()-1:
		var a: Vector3=F.call(pts[i][0],pts[i][1])
		var b: Vector3=F.call(pts[i+1][0],pts[i+1][1])
		var along=(F.call(1,0)-F.call(0,0)).normalized()
		var nrm=along.cross(Vector3.UP).normalized()
		if nrm.dot(Vector3(1,0,1))<0: nrm=-nrm   # out of the wall, toward the camera
		a+=nrm*lift
		b+=nrm*lift
		var d=(b-a).normalized()
		var side=nrm.cross(d).normalized()*w
		g.quad(a-side,a+side,b+side,b-side,col)

## DUNGEON BRIGHTNESS on BRIGHT: every raider marked over the dark, a ring at the feet and a point over the head
func bright_marks(g: V3Mesh, s):
	for e in s.enemies:
		if e.dead: continue
		var col=Color("#ffd65a") if e.type=="boss" else Color("#ff785a")
		ring(g,e.x,e.y,.42,.02,.03,col,24)
		g.prism(e.x,e.y,0.0,1.05,1.17,col,col,3,.09)

static func loot_col(l) -> String:
	var T=UsLoot.tables()
	if l.kind=="weapon": return RAR_COL.get(str(l.w.r),"#9a958a")
	if l.kind=="perk":
		var P=T.perks.get(l.k,T.get("sig_perks",{}).get(l.k,{}))
		return RAR_COL.get(str(P.get("r","c")),"#9a958a")
	if l.kind=="relic": return RAR_COL.get(str(T.relics.get(l.k,{}).get("r","c")),"#9a958a")
	return "#c8c3b8"
