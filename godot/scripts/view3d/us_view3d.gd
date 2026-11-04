class_name UsView3D
extends Node3D
## Native tunnel geometry. Only exposed walls on screen are instanced each frame;
## walls between the camera and a soldier lower visually without changing collision.
var world
var wall_instances: MultiMesh
var wall_node: MultiMeshInstance3D
var warning: MeshInstance3D
var water: MeshInstance3D

func _init(w):
	world=w
	name="Understrip"

func material(unshaded: bool=false) -> StandardMaterial3D:
	var mat=StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.roughness=1.0
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	if unshaded: mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
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
	for y in s.N:
		for x in s.N:
			var tile=s.terr[y*s.N+x]
			if tile==PalMaps.T_CONC: continue
			var shade=.9+Pal.hash2(x,y)*.16
			var col=Color("#34383b")*Color(shade,shade,shade)
			if tile in [PalMaps.T_WATER,PalMaps.T_LOW]: col=Color("#173a3b")
			if tile==PalMaps.T_BRIDGE: col=Color("#665646")
			floor_mesh.quad(Vector3(x,0,y),Vector3(x,0,y+1),Vector3(x+1,0,y+1),Vector3(x+1,0,y),col)
			if tile==PalMaps.T_LOW: flooded.quad(Vector3(x,.06,y),Vector3(x,.06,y+1),Vector3(x+1,.06,y+1),Vector3(x+1,.06,y),Color("#276f7b"))
			if tile==PalMaps.T_JUNK: props.box(x+.1,y+.1,x+.9,y+.9,0,.5,Color("#584e42"),Color("#3b3932"),Color("#43423a"))
			if tile==PalMaps.T_TANK:
				props.box(x+.1,y+.1,x+.9,y+.9,0,1.4,Color("#486960"),Color("#28453f"),Color("#305047"))
	for p in s.lay.lamps:
		props.box(p[0]-.08,p[1]-.08,p[0]+.08,p[1]+.08,0,1.0,Color("#55574c"),Color("#343831"),Color("#343831"))
		glow.box(p[0]-.12,p[1]-.12,p[0]+.12,p[1]+.12,1.0,1.15,Color("#ffca72"),Color("#ffca72"),Color("#ffca72"))
	for p in s.lay.shrines:
		props.box(p.x-.35,p.y-.25,p.x+.35,p.y+.25,0,.65,Color("#42484b"),Color("#252d30"),Color("#283337"))
		glow.disc(p.x,p.y,.7,.7,.02,Color("#5ac27c"),24)
		glow.box(p.x-.27,p.y-.08,p.x+.27,p.y+.08,.65,.78,Color("#7cff6b"),Color("#7cff6b"),Color("#7cff6b"))
	var exit=s.lay.exit
	glow.disc(exit[0],exit[1],1.6,1.6,.012,Color("#29634f"),32)
	for c in s.lay.chests: props.box(c.x-.3,c.y-.22,c.x+.3,c.y+.22,0,.35,Color("#8d693c"),Color("#543f29"),Color("#67502e"))
	for merchant in s.lay.merchants:
		props.box(merchant.x-.45,merchant.y-.25,merchant.x+.45,merchant.y+.25,0,.65,Color("#554754"),Color("#37303b"),Color("#3e3441"))
		glow.box(merchant.x-.4,merchant.y-.26,merchant.x+.4,merchant.y-.22,.4,.5,Color("#c78bff"),Color("#c78bff"),Color("#c78bff"))
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

func frame():
	var s=world.sim
	var count=0
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
			wall_instances.set_instance_color(count,Color("#665b3d") if tile==PalMaps.T_SHUT else Color("#55595b"))
			count+=1
	wall_instances.visible_instance_count=count
	if water!=null: water.visible=s.flood_on
	var g=V3Mesh.new()
	for item in s.game.us.loot:
		g.disc(item.x,item.y,.3,.3,.03,Color("#e2b436"),12)
		g.box(item.x-.1,item.y-.1,item.x+.1,item.y+.1,.1,.28,Color("#ffcf64"),Color("#ffcf64"),Color("#ffcf64"))
	for drop in s.game.us.drops: g.disc(drop.x,drop.y,.3,.3,.04,Color("#e2b436"),12)
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
	warning.mesh=g.commit() if g.size()>0 else null
