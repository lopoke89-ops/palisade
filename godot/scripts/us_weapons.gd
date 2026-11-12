class_name UsWeapons
extends RefCounted
## Authored mode-specific silhouettes, shared by equipped guns, floor loot and shop renders.
## Metres, grip at the origin, muzzle along +Z: the library's WeaponSocket convention.
const IDS := ["w_sawnoff","w_taser","w_nailgun","w_smg","w_flare","w_riot","w_laser","w_alien","w_antigrav"]
const DESCRIPTION := {
	"w_sawnoff":"A cut-down double barrel. Nine pellets per shell; devastating up close, with only two shots before reloading.",
	"w_taser":"Security's compact stun gun. Stuns ordinary raiders and slows bosses; the shock can jump to nearby targets.",
	"w_nailgun":"A salvaged construction tool. Rapid nails pierce a target and can pin raiders against walls.",
	"w_smg":"Shelter 7's compact automatic. Fast fire, a deep magazine and a wide spread at long range.",
	"w_flare":"An emergency flare projector. Its slow projectile lights the tunnel and burns the target.",
	"w_riot":"A pump-action riot gun. Seven tight pellets knock raiders back and clear a crowded passage.",
	"w_laser":"A laboratory beam carbine. Fast, accurate shots ricochet off walls. Watch your angles.",
	"w_alien":"A living sidearm. Hold fire to charge, then release; a full charge hits harder and pierces targets.",
	"w_antigrav":"An experimental gravity projector. Slow pulses lift ordinary raiders and damage nearby targets."
}
static var meshes := {}
static var icons := {}
static var material: StandardMaterial3D

# Parts: shape (box or cylinder), position, dimensions, colour. Cylinders point along the barrel.
static func box(p: Vector3, size: Vector3, col: String) -> Array:
	return [0,p,size,Color(col)]
static func tube(p: Vector3, radius: float, length: float, col: String) -> Array:
	return [1,p,Vector3(radius,length,radius),Color(col)]
static func parts(id: String) -> Array:
	var steel="#48515b"
	var dark="#1c232b"
	var silver="#a9b8bd"
	var out: Array=[]
	match id:
		"w_sawnoff":
			out=[box(Vector3(0,-.075,-.025),Vector3(.085,.17,.16),"#78472d"),box(Vector3(0,.015,.07),Vector3(.17,.10,.20),steel)]
			for x in [-.047,.047]:
				out.append(tube(Vector3(x,.055,.28),.041,.30,steel))
				out.append(tube(Vector3(x,.055,.435),.028,.008,dark))
			out.append(box(Vector3(0,-.015,.22),Vector3(.14,.05,.16),"#9b6035"))
		"w_taser":
			out=[box(Vector3(0,-.075,0),Vector3(.08,.17,.10),dark),box(Vector3(0,.035,.09),Vector3(.14,.13,.25),"#d9b330"),box(Vector3(0,.06,.12),Vector3(.145,.055,.12),dark)]
			for x in [-.045,.045]:
				out.append(tube(Vector3(x,.025,.25),.016,.12,silver))
				out.append(tube(Vector3(x,.025,.315),.012,.025,"#9efff0"))
			out.append(box(Vector3(.072,.04,.06),Vector3(.006,.04,.065),"#53d8eb"))
		"w_nailgun":
			out=[box(Vector3(0,0,.10),Vector3(.15,.16,.30),"#cf7833"),box(Vector3(0,-.095,-.02),Vector3(.075,.18,.10),dark),tube(Vector3(0,.035,.33),.027,.22,silver),tube(Vector3(0,-.10,.13),.105,.13,dark),box(Vector3(0,.11,.08),Vector3(.16,.045,.20),steel)]
			for z in [.02,.08,.14]: out.append(box(Vector3(.079,.025,z),Vector3(.008,.065,.025),silver))
		"w_smg":
			out=[box(Vector3(0,.025,.14),Vector3(.11,.13,.35),"#65715b"),box(Vector3(0,-.08,.015),Vector3(.075,.18,.10),dark),box(Vector3(0,-.14,.18),Vector3(.07,.24,.085),steel),tube(Vector3(0,.04,.39),.025,.17,dark),box(Vector3(0,.12,.15),Vector3(.025,.035,.29),dark)]
			for x in [-.043,.043]: out.append(box(Vector3(x,.015,-.15),Vector3(.018,.025,.27),silver))
			out.append(box(Vector3(0,0,-.28),Vector3(.11,.13,.025),dark))
		"w_flare":
			out=[box(Vector3(0,-.085,0),Vector3(.085,.17,.12),dark),box(Vector3(0,.015,.08),Vector3(.15,.12,.20),"#c74d30"),tube(Vector3(0,.045,.27),.08,.25,"#d75b36"),tube(Vector3(0,.045,.40),.055,.012,dark),box(Vector3(0,.13,.06),Vector3(.06,.035,.12),silver),box(Vector3(.079,.01,.08),Vector3(.008,.07,.055),"#f5df9b")]
		"w_riot":
			out=[box(Vector3(0,-.075,-.02),Vector3(.075,.17,.12),dark),box(Vector3(0,.025,.12),Vector3(.12,.13,.30),steel),tube(Vector3(0,.055,.45),.034,.47,steel),tube(Vector3(0,-.025,.39),.028,.35,dark),box(Vector3(0,-.015,.37),Vector3(.14,.09,.19),"#4b5660"),box(Vector3(0,-.005,-.20),Vector3(.095,.10,.28),dark),box(Vector3(0,-.01,-.34),Vector3(.12,.17,.03),dark)]
			for z in [.31,.35,.39,.43]: out.append(box(Vector3(0,.034,z),Vector3(.145,.012,.012),silver))
		"w_laser":
			out=[box(Vector3(0,.02,.16),Vector3(.13,.14,.36),"#d6dcd5"),box(Vector3(0,-.09,0),Vector3(.07,.18,.11),dark),box(Vector3(0,.04,.45),Vector3(.10,.09,.24),steel),box(Vector3(0,-.09,.19),Vector3(.10,.13,.13),"#417d95"),box(Vector3(0,.13,.16),Vector3(.06,.07,.14),dark),box(Vector3(0,.04,.58),Vector3(.06,.045,.018),"#66f5ea")]
			for z in [.05,.13,.21,.29]: out.append(box(Vector3(.069,.03,z),Vector3(.009,.045,.035),"#68e8dd"))
		"w_alien":
			out=[box(Vector3(0,-.08,-.015),Vector3(.07,.17,.105),"#625473"),tube(Vector3(0,.035,.14),.075,.27,"#716185"),tube(Vector3(0,.035,.31),.04,.12,"#a2a878"),tube(Vector3(0,.035,.38),.025,.02,"#b7ff71")]
			for z in [.03,.10,.17,.24]:
				out.append(tube(Vector3(0,.035,z),.085,.018,"#9c8cb5"))
			for x in [-.078,.078]: out.append(box(Vector3(x,.04,.15),Vector3(.022,.035,.13),"#c0f080"))
		"w_antigrav":
			out=[box(Vector3(0,-.09,0),Vector3(.09,.19,.12),dark),box(Vector3(0,.02,.14),Vector3(.19,.19,.35),"#ccc8d6"),tube(Vector3(0,.04,.36),.11,.24,steel),tube(Vector3(0,.04,.48),.07,.018,"#af8cff"),tube(Vector3(0,.04,.495),.042,.021,dark),box(Vector3(0,-.09,.20),Vector3(.12,.12,.19),"#675686")]
			for z in [.28,.35,.42]: out.append(tube(Vector3(0,.04,z),.125,.022,"#9674d6"))
			for x in [-.12,.12]: out.append(box(Vector3(x,.04,.42),Vector3(.035,.065,.26),silver))
	return out

static func mesh_for(id: String) -> ArrayMesh:
	if meshes.has(id): return meshes[id]
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts(id):
		var primitive: PrimitiveMesh
		var basis=Basis.IDENTITY
		if part[0]==0:
			var b=BoxMesh.new()
			b.size=part[2]
			primitive=b
		else:
			var c=CylinderMesh.new()
			c.top_radius=part[2].x
			c.bottom_radius=part[2].x
			c.height=part[2].y
			c.radial_segments=12
			primitive=c
			basis=Basis(Vector3.RIGHT,PI/2)
		var a=primitive.get_mesh_arrays()
		for index in a[Mesh.ARRAY_INDEX]:
			st.set_color(part[3])
			st.set_normal(basis*a[Mesh.ARRAY_NORMAL][index])
			st.add_vertex(basis*a[Mesh.ARRAY_VERTEX][index]+part[1])
	meshes[id]=st.commit()
	return meshes[id]

static func build(id: String) -> Node3D:
	var n=MeshInstance3D.new()
	n.name="UnderstripWeapon"
	n.mesh=mesh_for(id)
	if material==null:
		material=StandardMaterial3D.new()
		material.vertex_color_use_as_albedo=true
		material.roughness=.57
		material.metallic=.35
	n.material_override=material
	n.set_meta("weapon_id",id)
	return n

static func icon(id: String) -> Texture2D:
	if not icons.has(id): icons[id]=load("res://art/understrip/weapons/%s.png" % id)
	return icons[id]
