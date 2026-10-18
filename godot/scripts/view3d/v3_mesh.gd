class_name V3Mesh
extends RefCounted
## Builds the blocky low-poly world pieces: vertex-coloured boxes, prisms, discs and quads in one surface, so a whole
## yard's ground or a prop is a single draw. Colours are the 2D game's (sRGB, as Color.html gives them; the world
## shader converts them). UV2 carries each piece's anchor on the ground: the see-through rule (a wall or tree in front
## of someone fades) is decided per anchor in the shader. Also takes the 2D drawing's boxes (main.box_r) while a
## prop is captured, turning the iso box's ground rectangle, lift and height into a real box.

const V3 = preload("res://scripts/view3d/view3d.gd")

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var uv2 := PackedVector2Array()
var anchor := Vector2.ZERO
var base_y := 0.0   # captured boxes: the ground height under them is added by the capture (box_r's hz)
var sim: Sim


func size() -> int:
	return verts.size()


func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, n = null) -> void:
	var nn: Vector3 = n if n != null else (b - a).cross(c - a).normalized()
	verts.append_array([a, b, c])
	norms.append_array([nn, nn, nn])
	cols.append_array([col, col, col])
	uv2.append_array([anchor, anchor, anchor])


## a quad a-b-c-d, counter-clockwise seen from the side it faces (its normal by the right-hand rule; the world
## shader draws both sides, so the winding only decides the normal)
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	var n := (b - a).cross(d - a).normalized()
	if n.length() < 0.5:
		n = Vector3.UP
	verts.append_array([a, b, c, a, c, d])
	norms.append_array([n, n, n, n, n, n])
	cols.append_array([col, col, col, col, col, col])
	uv2.append_array([anchor, anchor, anchor, anchor, anchor, anchor])


## an axis-aligned box: x0..x1 (sim x), z0..z1 (sim y), y0..y1 up. top, south (+Z, the 2D "left" face) and east
## (+X, "right") take the 2D colours; the hidden north and west faces get them darker (they only show in shadows).
func box(x0: float, z0: float, x1: float, z1: float, y0: float, y1: float, top: Color, south: Color, east: Color) -> void:
	var a := Vector3(x0, y1, z0)
	var b := Vector3(x1, y1, z0)
	var c := Vector3(x1, y1, z1)
	var d := Vector3(x0, y1, z1)
	quad(a, d, c, b, top)   # top: faces up
	quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), c, d, south)
	quad(Vector3(x1, y0, z1), Vector3(x1, y0, z0), b, c, east)
	quad(Vector3(x1, y0, z0), Vector3(x0, y0, z0), a, b, south.darkened(0.3))
	quad(Vector3(x0, y0, z0), Vector3(x0, y0, z1), d, a, east.darkened(0.3))


## a ground-level flat polygon (an oval on the ground): n sides round (cx, cz) at height y
func disc(cx: float, cz: float, rx: float, rz: float, y: float, col: Color, n: int = 10) -> void:
	var c := Vector3(cx, y, cz)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		tri(c, Vector3(cx + cos(a1) * rx, y, cz + sin(a1) * rz), Vector3(cx + cos(a0) * rx, y, cz + sin(a0) * rz), col, Vector3.UP)


## an upright prism (a post, a drum, a trunk): n sides, radius r, from y0 to y1, its top coloured top
func prism(cx: float, cz: float, r: float, y0: float, y1: float, side: Color, top: Color, n: int = 6, r_top: float = -1.0) -> void:
	var rt := r if r_top < 0 else r_top
	for i in n:
		var a0 := TAU * i / n + 0.3
		var a1 := TAU * (i + 1) / n + 0.3
		var p0 := Vector3(cx + cos(a0) * r, y0, cz + sin(a0) * r)
		var p1 := Vector3(cx + cos(a1) * r, y0, cz + sin(a1) * r)
		var q0 := Vector3(cx + cos(a0) * rt, y1, cz + sin(a0) * rt)
		var q1 := Vector3(cx + cos(a1) * rt, y1, cz + sin(a1) * rt)
		var shade := 0.82 + 0.18 * cos((a0 + a1) / 2 - 0.9)   # baked side shading, lit from the south-west like the 2D
		quad(p1, p0, q0, q1, side * Color(shade, shade, shade, 1))
		if rt > 0.001:
			tri(Vector3(cx, y1, cz), q1, q0, top, Vector3.UP)


## a cone (a pine tier, a spike): base radius r at y0 to a point at y1
func cone(cx: float, cz: float, r: float, y0: float, y1: float, light: Color, dark: Color, n: int = 7) -> void:
	var tip := Vector3(cx, y1, cz)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cx + cos(a0) * r, y0, cz + sin(a0) * r)
		var p1 := Vector3(cx + cos(a1) * r, y0, cz + sin(a1) * r)
		var mid := (a0 + a1) / 2
		var lit := cos(mid - 2.3) > 0   # the 2D pine: the left half lit, the right half in shade
		tri(p1, p0, tip, light if lit else dark)
		tri(Vector3(cx, y0, cz), p0, p1, dark.darkened(0.3), Vector3.DOWN)


## a thin bar between two points (a rail, a strut, a lattice member): a square section of half-width w
func bar(a: Vector3, b: Vector3, w: float, col: Color) -> void:
	var d := (b - a)
	if d.length() < 0.0001:
		return
	var f := d.normalized()
	var s := f.cross(Vector3.UP)
	if s.length() < 0.01:
		s = f.cross(Vector3.RIGHT)
	s = s.normalized() * w
	var t := f.cross(s).normalized() * w
	var c := [a + s + t, a - s + t, a - s - t, a + s - t]
	var e := [b + s + t, b - s + t, b - s - t, b + s - t]
	for i in 4:
		var j := (i + 1) % 4
		var shade := 0.75 + 0.25 * float(i % 2)
		quad(c[i], c[j], e[j], e[i], col * Color(shade, shade, shade, 1))


## main.box_r while a prop is captured: z and h are base pixels (the 2D's px / u), the box stands at its centre's height
func box_r(x0: float, y0: float, x1: float, y1: float, z: float, h: float, top: Color, l: Color, r: Color) -> void:
	var hz := sim.height_at((x0 + x1) / 2, (y0 + y1) / 2) * V3.TER if sim != null else 0.0
	var ya := hz + z * V3.PXV
	var yb := ya + maxf(h, 0.3) * V3.PXV
	box(minf(x0, x1), minf(y0, y1), maxf(x0, x1), maxf(y0, y1), ya, yb, top, l, r)


func commit(mesh: ArrayMesh = null, material: Material = null) -> ArrayMesh:
	var am := mesh if mesh != null else ArrayMesh.new()
	if verts.is_empty():
		return am
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if material != null:
		am.surface_set_material(am.get_surface_count() - 1, material)
	return am


func clear() -> void:
	verts = PackedVector3Array()
	norms = PackedVector3Array()
	cols = PackedColorArray()
	uv2 = PackedVector2Array()
