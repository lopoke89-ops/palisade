class_name Wardrobe
extends RefCounted
## The player figure (16-characters.js paintWardrobeCharacter): a small 3D model built from boxes, eight-sided
## columns, beams and domes, turned to the aim, lit, depth-sorted and painted as outlined flat faces. Every skin,
## headgear and kit detail the browser builds is built here the same way, in the same order, with the same numbers.
## build() returns the posed faces; paint() draws them; poses are cached the way the browser caches its sprites.

const WEAPON_TABLE := {
	"carbine": {"x": 5.9, "y": 21.9, "butt": 4.3, "stock": [4.2, 2.4, 1.8, "#3e4336"], "recv": [5.2, 2.3, 1.85, "#303b3b"], "grip": 5.3, "mag": [1.6, 3, 1.3], "magZ": 6.6, "fore": 9.6, "foreL": 3.8, "foreC": "#4a5040", "barrel": 0.55},
	"rifle": {"x": 5.9, "y": 21.9, "butt": 4.3, "stock": [4.6, 2.5, 1.75, "#4d3a26"], "stockY": -0.1, "recv": [5.4, 2.1, 1.75, "#2e3431"], "grip": 5.6, "fore": 10.2, "foreL": 4.4, "foreC": "#5a4430", "barrel": 0.5, "scope": true},
	"sg": {"x": 6.3, "y": 19.6, "butt": 4.6, "stock": [4.6, 2.5, 1.9, "#6a4526"], "stockY": -0.15, "recv": [4.4, 2.4, 1.85, "#2e3534"], "grip": 5.6, "fore": 9.6, "foreL": 4.6, "foreC": "#8a603a", "foreW": 1.9, "foreH": 1.6, "foreY": -1.2, "barrel": 0.6, "tube": true, "pump": true},
	"smg": {"x": 5.9, "y": 21.9, "butt": 4.3, "stock": [2.8, 1.5, 1.3, "#2a2e2b"], "recv": [5, 2.5, 1.9, "#303836"], "grip": 4, "mag": [1.2, 3.8, 1.2], "magZ": 6.2, "magC": "#262b28", "fore": 7.9, "foreL": 2.8, "foreC": "#3a403a", "barrel": 0.5},
}
const BOX_FACES := [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [1, 2, 6, 5], [0, 4, 7, 3]]
const BOX_V := [[-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1], [-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]]
const RING8 := [[-0.72, -1], [0.72, -1], [1, -0.6], [1, 0.6], [0.72, 1], [-0.72, 1], [-1, 0.6], [-1, -0.6]]

# the pose being built
var o: Dictionary
var time := 0.0
var compact := false
var ca := 1.0
var sa := 0.0
var phase := 0.0
var weight := 0.0
var dirg := 0.0
var bob := 0.0
var faces: Array = []
var emit := {}
var sahur_lift := 0.0
var solid_hat := false
var B := ""
var V := ""
var T := ""
var skin := ""
var tip := Vector3.ZERO   # the gun's muzzle and butt on screen (model units), for tracers
var root := Vector3.ZERO
var measure_only := false

static var cache := {}   # pose key -> {faces, bounds}
static var cache_order: Array = []


static func weapon_kind(look: Dictionary) -> String:
	if look.get("weapon", "") == "sg":
		return "sg"
	var gl: float = look.get("gl", 14)
	return "rifle" if gl > 17 else ("smg" if gl <= 11 else "carbine")


## two-bone reach: the elbow for a shoulder, a hand, the two bone lengths and which way the elbow bends
static func reach(S: Vector3, Hh: Vector3, L1: float, L2: float, pole: Vector3) -> Vector3:
	var d0 := Hh - S
	var D := d0.length()
	if D == 0:
		D = 1
	var dr := d0 / D
	var d := minf(D, (L1 + L2) * 0.999)
	var a := (L1 * L1 - L2 * L2 + d * d) / (2 * d)
	var h := sqrt(maxf(0, L1 * L1 - a * a))
	var p := pole - dr * pole.dot(dr)
	var pl := p.length()
	if pl == 0:
		pl = 1
	p /= pl
	return S + dr * a + p * h


## 60% planted travel / 40% lifted recovery; the foot never sinks below its resting sole
static func step(ph: float, side: float, w: float = 1.0, dir: float = 0.0) -> Dictionary:
	var f := fposmod(ph / TAU + (0.5 if side < 0 else 0.0), 1.0)
	var stance := f < 0.6
	var q := f / 0.6 if stance else (f - 0.6) / 0.4
	var stride := (1 - 2 * q if stance else -1 + 2 * q * q * (3 - 2 * q)) * 2.15 * w
	var lift := 0.0 if stance else pow(sin(q * PI), 2) * 1.35 * w
	return {"x": side * 3.1 + sin(dir) * stride, "z": cos(dir) * stride, "lift": lift, "stance": stance}


static func hex(c) -> Array:
	var s: String = c if c is String else ""
	if s.length() == 7 and s[0] == "#" and s.substr(1).is_valid_hex_number():
		return [s.substr(1, 2).hex_to_int(), s.substr(3, 2).hex_to_int(), s.substr(5, 2).hex_to_int()]
	return [90, 95, 75]


static func tint(c, k: float) -> String:
	var v := hex(c)
	return "#" + "".join(v.map(func(x): return "%02x" % clampi(roundi(x * k), 0, 255)))


func leg(side: float) -> Dictionary:
	var st := step(phase, side, weight, dirg)
	var ankle := Vector3(st.x, 3.2 + st.lift, st.z)
	var hip := Vector3(side * 2.6, 14.4 + bob, 0)
	st.ankle = ankle
	st.hip = hip
	st.knee = reach(hip, ankle, 6, 6, Vector3(0, 0, 1))
	return st


func project(p: Vector3) -> Vector3:
	var d := -p.x * sa + p.z * ca
	return Vector3(p.x * ca + p.z * sa, -p.y + d * 0.32, d + p.y * 0.32)


## a mesh of vertices and faces: back faces dropped, each face lit by its normal, outlined on its open edges
func mesh(v: Array, ff: Array, col: String, outline: float = 0.55, bias: float = 0.0) -> void:
	if sahur_lift != 0:
		v = v.map(func(q): return q + Vector3(0, sahur_lift, 0))
	if o.get("downed", false):
		v = v.map(func(q): return Vector3(q.y * 0.8 - 14, q.z * 0.8 + 4, q.x * 0.8))
	var pr: Array = v.map(project)
	var vis: Array = []
	for ids in ff:
		var A: Vector3 = v[ids[0]]
		var Bv: Vector3 = v[ids[1]]
		var C: Vector3 = v[ids[2]]
		var n: Vector3 = (Bv - A).cross(C - A)
		var l := n.length()
		if l == 0:
			l = 1
		var nx := (n.x * ca + n.z * sa) / l
		var ny := n.y / l
		var nz := (-n.x * sa + n.z * ca) / l
		if nz + ny * 0.32 <= 0.001:
			continue
		var pts: Array = ids.map(func(i): return pr[i])
		var light := 0.73 + maxf(0, -nx * 0.48 + ny * 0.7 + nz * 0.42) * 0.35
		var dep := 0.0
		for p in pts:
			dep += p.z
		vis.append({"solid": solid_hat, "ids": ids, "pts": pts, "emission": col if not o.get("flash", false) and emit.has(col) else "",
			"col": "#f3e9d6" if o.get("flash", false) else tint(col, light), "depth": dep / pts.size() + bias, "edges": [], "outline": outline})
	var counts := {}
	for f in vis:
		for i in f.ids.size():
			var a: int = f.ids[i]
			var b: int = f.ids[(i + 1) % f.ids.size()]
			var key: int = a * 256 + b if a < b else b * 256 + a
			counts[key] = counts.get(key, 0) + 1
	for f in vis:
		for i in f.ids.size():
			var a: int = f.ids[i]
			var b: int = f.ids[(i + 1) % f.ids.size()]
			var key: int = a * 256 + b if a < b else b * 256 + a
			if counts[key] == 1:
				f.edges.append([pr[a], pr[b]])
		faces.append(f)


func box(x: float, y: float, z: float, w: float, h: float, d: float, col: String, outline: float = 0.48, bias: float = 0.0) -> void:
	var v: Array = BOX_V.map(func(p): return Vector3(x + p[0] * w / 2, y + p[1] * h / 2, z + p[2] * d / 2))
	mesh(v, BOX_FACES, col, outline, bias)


## rounded eight-sided sections keep the silhouette compact and avoid square toy limbs
func column(x: float, y: float, z: float, w: float, h: float, d: float, col: String, top: float = 1.0, outline: float = 0.55) -> void:
	if compact and w < 6:
		box(x, y, z, w, h, d, col, outline)
		return
	var v: Array = []
	for p in RING8:
		v.append(Vector3(x + p[0] * w / 2, y - h / 2, z + p[1] * d / 2))
	for p in RING8:
		v.append(Vector3(x + p[0] * w / 2 * top, y + h / 2, z + p[1] * d / 2 * top))
	var ff: Array = [[7, 6, 5, 4, 3, 2, 1, 0], [8, 9, 10, 11, 12, 13, 14, 15]]
	for i in 8:
		ff.append([i, (i + 1) % 8, (i + 1) % 8 + 8, i + 8])
	for f in ff:
		f.reverse()
	mesh(v, ff, col, outline)


func beam(a: Vector3, b: Vector3, r: float, col: String, r2: float = -1.0, outline: float = 0.48) -> void:
	if r2 < 0:
		r2 = r
	var axis := b - a
	var L := axis.length()
	if L == 0:
		return
	var upv := Vector3(0, 0, 1) if absf(axis.y / L) > 0.9 else Vector3(0, 1, 0)
	var U := axis.cross(upv).normalized()
	var Vv := axis.cross(U).normalized()
	var v: Array = []
	var sides := 4 if compact else 8
	for pr in [[a, r], [b, r2]]:
		for i in sides:
			var t := TAU * i / sides
			v.append(pr[0] + (U * cos(t) + Vv * sin(t)) * pr[1])
	var f0: Array = []
	var f1: Array = []
	for i in sides:
		f0.append(sides - 1 - i)
		f1.append(i + sides)
	var ff: Array = [f0, f1]
	for i in sides:
		ff.append([i, (i + 1) % sides, (i + 1) % sides + sides, i + sides])
	mesh(v, ff, col, outline)


func dome(col: String, base: float = 32, rx: float = 5.3, rz: float = 4.5, height: float = 4.7) -> void:
	var v: Array = []
	var n := 8 if compact else 12
	var rings := [[base, rx * 0.94, rz], [base + height * 0.24, rx, rz], [base + height * 0.66, rx * 0.85, rz * 0.84], [base + height * 0.94, rx * 0.45, rz * 0.49], [base + height, 0.08, 0.08]]
	for rg in rings:
		for i in n:
			var t := TAU * i / n
			v.append(Vector3(cos(t) * rg[1], rg[0] + bob, sin(t) * rg[2]))
	var top: Array = []
	for i in n:
		top.append((rings.size() - 1) * n + i)
	# the browser reverses every face's winding: (a, a+1, up+1, up) reversed is (up, up+1, a+1, a)
	var rev: Array = []
	for j in rings.size() - 1:
		for i in n:
			rev.append([(j + 1) * n + i, (j + 1) * n + (i + 1) % n, j * n + (i + 1) % n, j * n + i])
	top.reverse()
	rev.append(top)
	mesh(v, rev, col, 0.6)


## a wide brim: the outlined disk plus 12 unoutlined ring slices that each sort by their own position, so the
## front of the brim paints over the face
func brim(y: float, w: float, h: float, d: float, col: String, outline: float, ix: float, iz: float) -> void:
	column(0, y, 0, w, h, d, col, 1, outline)
	var n := 12
	var rx := w / 2 * 0.985
	var rz := d / 2 * 0.985
	var yb := y - h / 2
	var yt := y + h / 2
	var P := func(t: float, out: bool, yy: float) -> Vector3: return Vector3(cos(t) * (rx if out else ix), yy, sin(t) * (rz if out else iz))
	for k in n:
		var t0 := k * TAU / n
		var t1 := (k + 1) * TAU / n
		var v := [P.call(t0, false, yb), P.call(t0, true, yb), P.call(t1, true, yb), P.call(t1, false, yb), P.call(t0, false, yt), P.call(t0, true, yt), P.call(t1, true, yt), P.call(t1, false, yt)]
		mesh(v, [[6, 5, 4, 7], [1, 2, 3, 0], [5, 6, 2, 1]], col, 0.001)


func ball(x: float, y: float, z: float, r: float, c: String) -> void:
	column(x, y, z, r * 1.8, r * 1.65, r * 1.8, c, 0.75, 0.35)


func dunce_cone(base: float) -> void:
	column(0, base + bob, 0, 9, 1, 7.8, "#c43a3a", 1, 0.25)
	column(0, base + 2.2 + bob, 0, 7.6, 3.4, 6.6, "#efe6cf", 0.7, 0.45)
	column(0, base + 5.4 + bob, 0, 5.3, 3.2, 4.6, "#efe6cf", 0.55, 0.4)
	beam(Vector3(0, base + 6.8 + bob, 0), Vector3(0, base + 11 + bob, 0), 1.5, "#efe6cf", 0.08, 0.3)


## a flat shape on the clothing: pts in local space, raised by the bob
func decal(pts: Array, col: String, bias: float = 0.7) -> void:
	var v: Array = pts.map(func(p): return Vector3(p[0], p[1] + bob, p[2]))
	var ids: Array = []
	for i in v.size():
		ids.append(i)
	mesh(v, [ids], col, 0.06, bias)


func chest(x: float, y: float, w: float, h: float, col: String, z: float = 4.06) -> void:
	box(x, y + bob, z, w, h, 0.15, col, 0.035, 0.65)


func strip(a: Array, b: Array, w: float, z: float, col: String, bias: float = 0.75) -> void:
	var dx: float = b[0] - a[0]
	var dy: float = b[1] - a[1]
	var l := Vector2(dx, dy).length()
	if l == 0:
		l = 1
	var nx := -dy / l * w / 2
	var ny := dx / l * w / 2
	var p := [[a[0] + nx, a[1] + ny, z], [b[0] + nx, b[1] + ny, z], [b[0] - nx, b[1] - ny, z], [a[0] - nx, a[1] - ny, z]]
	if z > 0:
		p.reverse()
	decal(p, col, bias)


func poly(v: Array, col: String, outline: float, bias: float = 0.0, reverse: bool = false) -> void:
	var ids: Array = []
	for i in v.size():
		ids.append(v.size() - 1 - i if reverse else i)
	mesh(v, [ids], col, outline, bias)


static func V3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


## paintWardrobeCharacter's model: everything the figure wears, as posed faces. walking: a gait phase (a number) or
## false. Returns {faces, ground, kick-free gun tip and root} like the browser's measuring call.
func build(look: Dictionary, angle: float, t: float, scale: float, walking) -> void:
	o = look
	time = t
	compact = scale <= 6
	faces = []
	var gold_clown: bool = o.get("glitter") and o.get("dots")
	var gold_police: bool = o.get("glitter") and o.get("badge")
	var gold_knight: bool = o.get("glitter") and o.get("plate")
	emit = {}
	for k in [o.get("neon"), o.get("hneon"), o.get("halo"), o.get("visor"), o.get("mask"), o.get("frost"), o.get("spots"), o.get("reaper"), o.get("phantom"), o.get("lamp")]:
		if k is String:
			emit[k] = true
	if o.get("stars"):
		emit["#f3eaff"] = true
		emit["#b2b5ff"] = true
	if o.get("holo"):
		emit["#b5f5ff"] = true
	if o.get("shine") or o.get("chrome"):
		emit["#fff1c1"] = true
		emit["#ffffff"] = true
	if o.get("glitter"):
		emit["#fffbe0"] = true
	if o.get("halloweenHat") == "batcirclet":
		emit["#ff4a5a"] = true
	if o.get("halloweenHat") == "skullseal":
		emit["#ffe39a"] = true
		emit["#b48cff"] = true
	if o.get("pumpkin"):
		emit["#ffb040" if o.get("pking") else "#ffd35a"] = true
		emit["#ff7a1a"] = true
	if o.get("wraps"):
		emit["#ffc94a"] = true
	if o.get("demon"):
		emit[o.demon] = true
		emit["#ffd070"] = true
	ca = cos(angle)
	sa = sin(angle)
	phase = float(walking) if (walking is float or walking is int) and not (walking is bool) else (t * 7 if walking == true else 0.0)
	weight = 0.0 if o.get("downed") else (o.gaitWeight if o.has("gaitWeight") else (1.0 if walking else 0.0))
	dirg = o.get("gaitDir", 0.0)
	bob = -(1 - cos(phase * 2)) * 0.14 * weight + (0.0 if o.get("downed") else o.get("breath", 0.0) * 0.16)
	sahur_lift = 0.0
	solid_hat = false
	B = "#26334b" if gold_police else ("#454039" if gold_knight else o.body)
	V = "#67293b" if gold_clown else o.vest
	T = "#202b40" if gold_police else ("#393630" if gold_knight else o.get("pants", "#3b372c"))
	skin = o.head
	var bp: float = o.get("bolt", -1.0) if o.get("bolt") != null else -1.0
	var kick := (1 - bp / 0.2) * 0.65 if bp >= 0 and bp < 0.2 else 0.0
	var pull := sin((bp - 0.24) / 0.66 * PI) if bp > 0.24 and bp < 0.9 else 0.0
	var sniper: bool = o.get("gl", 14) > 17
	var W: Dictionary = WEAPON_TABLE[weapon_kind(o)]
	var gunX: float = W.x
	var gunY: float = W.y
	var gunZ: float = W.butt
	var gl: float = o.get("gl", 14)
	tip = project(Vector3(gunX, gunY + bob, gunZ + gl + 2.4 - kick))
	root = project(Vector3(gunX, gunY + bob, 0))
	if measure_only:
		return
	# a planted stance, shaped thighs, separate knees and substantial boots
	for side in [-1.0, 1.0]:
		var L := leg(side)
		var x: float = L.x
		var z: float = L.z
		var lift: float = L.lift
		var ankle: Vector3 = L.ankle
		var knee: Vector3 = L.knee
		var hip: Vector3 = L.hip
		if o.get("sahur"):
			column(x, 1.5 + lift, 1.05 + z, 3.4, 2.2, 5.3, "#9a6033", 0.85, 0.4)
			beam(ankle, knee, 0.95, B, 1.05, 0.3)
			beam(knee, hip, 1.05, B, 1.2, 0.3)
			continue
		if o.get("winterModel"):
			var monster: bool = o.winterModel == "yulemaw"
			var deer: bool = o.winterModel == "rednosedemolisher"
			var r := 2.6 if monster else (1.4 if deer else 1.15)
			beam(ankle, knee, r, T, r * 1.1)
			beam(knee, hip, r * 1.1, T, r * 1.3)
			if deer:
				for s in [-1, 1]:
					box(x + s * 0.8, 1.8 + lift, z + 1, 1.45, 2.6, 4, "#292b27", 0.3)
			else:
				column(x, 1.8 + lift, z + 1, 6.0 if monster else 3.2, 2.8, 6.0 if monster else 4.6, "#427d37" if monster else "#d6f4fa", 0.8, 0.35)
			continue
		if o.get("jersey"):   # sneakers, bare calves, shorts with a trim hem
			var mm := knee + (hip - knee) * 0.3
			column(x, 1.7 + lift, 1.15 + z, 3.7, 2.5, 5.6, "#efefea", 0.87)
			box(x, 0.55 + lift, 1.25 + z, 3.8, 0.7, 5.8, o.jtrim, 0.25)
			beam(ankle, knee, 1.25, skin, 1.5)
			beam(knee, mm, 1.5, skin, 1.75)
			column(mm.x, mm.y, mm.z, 4.9, 0.65, 4.9, o.jtrim, 1, 0.2)
			beam(mm, hip, 2.35, T, 2.6)
			continue
		column(x, 2 + lift, 1.05 + z, 4.3, 3.1, 6.1, "#35362e", 0.87)
		box(x, 0.7 + lift, 1.2 + z, 4.35, 0.85, 6.25, "#202722", 0.3)
		beam(ankle, knee, 1.7, T, 2)
		beam(knee, hip, 2.05, T, 2.35)
		column(knee.x, knee.y, knee.z + 1.75, 2.8, 3.2, 1.25, tint(T, 0.75), 0.88, 0.32)
		box(side * 4.7, 11.7 + bob, 0, 1.5, 3.3, 2.75, tint(T, 1.1), 0.3)
	_torso()
	_winter_clothes()
	if o.get("winterBoss"):
		column(0, 24 + bob, -5.4, 10, 12, 5, "#34525f", 0.8, 0.4)
		box(0, 24 + bob, -8, 5.8, 7, 1, "#8be1ad", 0.3)
		for side in [-1, 1]:
			column(side * 6.3, 26 + bob, 0, 5.5, 6, 7.5, "#a0cfdf", 0.4, 0.5)
			beam(Vector3(side * 6, 28 + bob, 0), Vector3(side * 8, 35 + bob, -1), 1.2, "#c5edf2", 0.05, 0.3)
			column(side * 3, 7 + bob, 2, 4, 5, 4.5, "#8aaabd", 0.8, 0.3)
		box(0, 23 + bob, 4.4, 7, 5, 1.4, "#89b9c9", 0.5)
		beam(Vector3(-3, 26 + bob, 5.2), Vector3(2, 20 + bob, 5.2), 0.17, "#d6ffef", 0.17, 0.06)
	# arms: a two-bone reach from each shoulder to where the hand holds the gun, elbows bent down and out
	var shL := Vector3(-6.3, 24.7 + bob, 1)
	var shR := Vector3(6.3, 24.7 + bob, 1)
	var frost_lift := (5.0 if o.get("winterSt") == 101 else (2.0 if o.get("winterSt") == 102 else 0.0)) if o.get("winterBoss") else 0.0
	var nogun: bool = o.get("nogun", false)
	var haL := Vector3(-6.3, 16 + bob + frost_lift, 1) if nogun else Vector3(gunX - 0.3, gunY - 1.1 + bob, gunZ + W.fore + W.foreL * 0.35 - kick - (pull * 2 if W.get("pump") else 0.0))
	var haR := Vector3(6.3, 16 + bob + frost_lift, 1) if nogun else Vector3(gunX + 0.2 + (pull * 1.6 if sniper else 0.0), gunY - 1.6 + bob + (pull if sniper else 0.0), gunZ + W.grip - kick - (pull * 1.5 if sniper else 0.0))
	var elL := Vector3(-6.8, 20.4 + bob, 2.2) if nogun else reach(shL, haL, 8.2, 12.6, Vector3(-0.75, -1, 0.1))
	var elR := Vector3(7.1, 20.8 + bob, 2.6) if nogun else reach(shR, haR, 7.4, 7.8, Vector3(0.8, -1, -0.35))
	for arm in [[shL, elL, haL], [shR, elR, haR]]:
		var sh: Vector3 = arm[0]
		var el: Vector3 = arm[1]
		var ha: Vector3 = arm[2]
		var aw := 2.8 if o.get("winterModel") == "yulemaw" else (1.25 if o.get("winterModel") == "gildedfrostborn" else 2.0)
		var AC: String = skin if o.get("jersey") else B
		beam(sh, el, 1.1 if o.get("sahur") else aw, AC, 1.0 if o.get("sahur") else aw * 0.85)
		beam(el, ha, 1.0 if o.get("sahur") else aw * 0.82, AC, 0.9 if o.get("sahur") else aw * 0.71)
		if o.get("reaper"):
			beam(sh, el, 2.7, B, 2.5, 0.4)
			beam(el, ha + (el - ha) * 0.3, 2.5, B, 2.6, 0.4)
		var glove: String = "#bf834b" if o.get("sahur") else (B if o.get("winterModel") else (tint(skin, 0.9) if o.get("jersey") else "#363b2b"))
		beam(ha + (el - ha) * 0.13, ha, 1.1 if o.get("sahur") else (2.6 if o.get("winterModel") == "yulemaw" else 1.5), glove, 1.05 if o.get("sahur") else (2.2 if o.get("winterModel") == "yulemaw" else 1.48), 0.35)
	if o.get("winterBoss"):
		var y := 26 + bob + frost_lift
		beam(Vector3(6.3, 10 + bob + frost_lift, 1), Vector3(7.8, y, 2), 0.65, "#3c5966", 0.8, 0.3)
		column(7.8, y, 2, 8, 5, 7, "#91cbdc", 0.7, 0.5)
		beam(Vector3(5, y + 1, 5.4), Vector3(8.8, y - 1, 5.4), 0.15, "#e0fff4", 0.12, 0.03)
		for x in [5.5, 9.5]:
			beam(Vector3(x, y + 2, 2), Vector3(x, y + 5, 1), 0.8, "#b8e9ed", 0.05, 0.2)
	if o.get("cross"):
		box(-8, 24 + bob, 0, 0.25, 2.6, 2.4, "#eee7d6", 0.2)
		box(-8.2, 24 + bob, 0, 0.2, 1.8, 0.6, "#c43a3a", 0.05)
		box(-8.2, 24 + bob, 0, 0.2, 0.6, 1.8, "#c43a3a", 0.05)
	if not nogun:
		_gun(W, gunX, gunY, gunZ, gl, kick, pull)
	_head(W)
	_addons(elL, elR, haL, haR, gold_clown, gold_police, gold_knight)


func _wb(W: Dictionary, gunX: float, gunY: float, z0: float, y: float, z: float, w: float, h: float, d: float, c: String, l: float = 0.3) -> void:
	box(gunX, gunY + y + bob, z0 + z, w, h, d, c, l)


## every gun from the weapon table: stock, receiver, grip, magazine, fore-end, barrel, sights
func _gun(W: Dictionary, gunX: float, gunY: float, gunZ: float, gl: float, kick: float, pull: float) -> void:
	var z0 := gunZ - kick
	var stk: Array = W.stock
	var sl: float = stk[0]
	var sh: float = stk[1]
	var sw: float = stk[2]
	_wb(W, gunX, gunY, z0, W.get("stockY", 0.0), sl / 2, sw, sh, sl, stk[3], 0.36)
	var rv: Array = W.recv
	var rl: float = rv[0]
	var rh: float = rv[1]
	var rw: float = rv[2]
	_wb(W, gunX, gunY, z0, 0, sl + rl / 2, rw, rh, rl, rv[3], 0.38)
	_wb(W, gunX, gunY, z0, rh / 2 + 0.25, sl + rl / 2 + 0.2, rw * 0.55, 0.5, rl * 0.9, "#67716b", 0.2)
	_wb(W, gunX, gunY, z0, -rh / 2 - 0.9, W.grip, 1.25, 2, 1.3, tint(rv[3], 0.9), 0.3)
	if W.has("mag"):
		_wb(W, gunX, gunY, z0, -rh / 2 - W.mag[1] / 2 + 0.3, W.magZ, W.mag[2], W.mag[1], W.mag[0], W.get("magC", "#333c33"), 0.32)
	var fz: float = W.fore - (pull * 2 if W.get("pump") else 0.0)
	_wb(W, gunX, gunY, z0, W.get("foreY", 0.0), fz + W.foreL / 2, W.get("foreW", 1.6), W.get("foreH", 1.9), W.foreL, W.foreC, 0.3)
	if W.get("pump"):
		for i in 3:
			_wb(W, gunX, gunY, z0, W.get("foreY", 0.0) - W.get("foreH", 1.9) / 2 - 0.05, fz + 0.8 + i * 1.2, W.get("foreW", 1.6) * 1.05, 0.25, 0.45, tint(W.foreC, 0.7), 0.05)
	# the barrel in three pieces, so the depth order stays right when it points at or away from you
	var bz0 := gunZ + sl + rl - 0.4 - kick
	var bz1 := gunZ + gl + 2.4 - kick
	for i in 3:
		beam(Vector3(gunX, gunY + bob, bz0 + (bz1 - bz0) * i / 3.0), Vector3(gunX, gunY + bob, bz0 + (bz1 - bz0) * (i + 1) / 3.0), W.barrel, "#333c3b", W.barrel * 0.88, 0.28)
	_wb(W, gunX, gunY, z0, 0.7, gl + 1.3, 0.75, 1.5, 0.65, "#303835", 0.22)
	if W.get("tube"):
		beam(Vector3(gunX, gunY - 1.2 + bob, gunZ + sl + rl - kick), Vector3(gunX, gunY - 1.2 + bob, gunZ + gl + 0.6 - kick), W.barrel * 1.05, "#434b43", W.barrel, 0.23)
	if W.get("scope"):
		beam(Vector3(gunX, gunY + 2.6 + bob, gunZ + sl + 0.4 - kick), Vector3(gunX, gunY + 2.6 + bob, gunZ + sl + rl + 2.2 - kick), 0.9, "#344038", 1, 0.3)
		_wb(W, gunX, gunY, z0, 1.8, sl + rl / 2 + 0.5, 0.6, 1, 1.6, "#282f2a", 0.2)
		beam(Vector3(gunX + 0.3, gunY + bob, gunZ + sl + 0.8 - kick), Vector3(gunX + 1.6, gunY + bob + pull * 2, gunZ + sl + 0.8 - kick - pull * 1.5), 0.25, "#9caa9c", 0.25, 0.1)


func _torso() -> void:
	if o.get("sahur"):   # one continuous wooden silhouette, kept inside the pose frame
		column(0, 24.7 + bob, 0, 9.5, 22.6, 7.6, B, 0.98, 0.5)
		for q in [[-2.6, 24, 8], [1.7, 20.4, 9], [-0.3, 28, 5], [3.3, 27, 10]]:
			beam(Vector3(q[0], q[1] - q[2] / 2.0 + bob, 3.84), Vector3(q[0] + 0.25, q[1] + q[2] / 2.0 + bob, 3.84), 0.09, "#8b552f", 0.07, 0.03)
		for side in [-1, 1]:
			beam(Vector3(side * 4.77, 17 + bob, -1), Vector3(side * 4.77, 32 + bob, -0.7), 0.1, "#8b552f", 0.08, 0.03)
		beam(Vector3(-5, 15 + bob, -2.8), Vector3(-6.5, 27 + bob, -2.8), 0.5, "#734724", 0.9, 0.25)   # a stowed wooden beater
	elif o.get("winterModel"):
		if o.winterModel == "yulemaw":
			column(0, 18.8 + bob, -0.7, 13.5, 13.5, 9, B, 0.95)
			column(0, 23 + bob, -1.6, 15, 9, 10, V, 1.1)
			column(0, 26 + bob, -1.2, 16.4, 2.7, 10.7, "#efe5cb", 1, 0.4)
			column(0, 14.7 + bob, -0.2, 13.8, 2.5, 9, "#eee4cc", 1, 0.35)
			for side in [-1, 1]:
				for n in 3:
					beam(Vector3(side * (5 + n), 25 + bob, -3), Vector3(side * (6 + n), 21 - n + bob, -4), 1.2, B, 0.15, 0.3)
			for y in [19, 22]:
				box(0, y + bob, 4.3, 1.5, 1.5, 0.6, "#d2b257", 0.2)
		elif o.winterModel == "rednosedemolisher":
			column(0, 20 + bob, 0, 8.7, 14, 6.4, B, 1.25)
			column(0, 22 + bob, -0.1, 9.2, 7.5, 7, V, 1)
			beam(Vector3(-4, 26 + bob, 3.5), Vector3(3, 15 + bob, 3.8), 0.4, "#4c3b28", 0.4, 0.15)
			box(0, 16 + bob, 0, 9.6, 1.3, 7, "#2e3328")
			for side in [-1, 1]:
				column(side * 5.7, 13.3 + bob, 0.6, 3, 4.3, 3, "#657947", 0.8, 0.4)
				for y in [12.3, 13.4, 14.5]:
					column(side * 5.7, y + bob, 0.6, 3.1, 0.28, 3.1, "#33412a", 1, 0.1)
				box(side * 5.7, 15.9 + bob, 0.6, 1.5, 0.8, 1.5, "#9a9f78", 0.2)
				beam(Vector3(side * 5.4, 16.5 + bob, 0.6), Vector3(side * 6.5, 16.5 + bob, 0.6), 0.22, "#e0ce87", 0.22, 0.08)
			beam(Vector3(0, 15 + bob, -3), Vector3(0, 17 + bob, -5.5), 1.3, "#dac3a0", 0.4, 0.25)
		else:
			column(0, 21 + bob, 0, 7.7, 12.8, 5.5, V, 1.2)
			column(0, 14.7 + bob, -0.3, 10.5, 5.2, 6.6, "#a4d3e5", 0.7, 0.35)
			for side in [-1, 1]:
				beam(Vector3(side * 4.1, 25 + bob, -2), Vector3(side * 6.2, 29 + bob, -2), 1.5, "#d7f6fc", 0.06, 0.3)
				beam(Vector3(side * 3.2, 25 + bob, 3), Vector3(side * 2.7, 15 + bob, 3.5), 0.22, "#e0b857", 0.22, 0.06)
			box(0, 22 + bob, 3.1, 2.5, 3.8, 0.8, "#e7bc5e", 0.25)
			beam(Vector3(0, 23 + bob, 3.8), Vector3(0, 21 + bob, 3.8), 0.6, "#ebfaff", 0.06, 0.12)
	elif o.get("jersey"):   # a sleeveless jersey over the shorts: trim on the neck, arm holes, sides and hem, a band and a number
		column(0, 15.2 + bob, 0, 9.7, 3.6, 5.7, T, 1.06)
		box(0, 17 + bob, 0, 9.8, 0.8, 5.9, o.jtrim, 0.25)
		column(0, 22 + bob, 0, 9.7, 10.4, 5.3, B, 1.1)
		box(0, 17.6 + bob, 0, 9.9, 0.55, 5.5, tint(B, 0.8), 0.15)
		for side in [-1, 1]:
			box(side * 4.95, 21.5 + bob, 0, 0.35, 8.6, 4.4, o.jtrim, 0.1)
			box(side * 3.4, 26.6 + bob, 0, 2.2, 0.9, 4.4, B, 0.25)
			box(side * 4.5, 25.9 + bob, 0, 0.5, 1.6, 4.6, o.jtrim, 0.08)
		box(0, 24.6 + bob, 2.8, 6.4, 1.1, 0.3, o.jtrim, 0.08, 1)
		for x in [-1.25, 1.25]:
			box(x, 20.9 + bob, 2.85, 1.6, 3.2, 0.3, o.jtrim, 0.12, 1)
		column(0, 27 + bob, 0, 4.5, 2.8, 3.6, skin, 1, 0.32)
		column(0, 27.6 + bob, 0, 5.1, 0.7, 4.1, o.jtrim, 1, 0.18)
	else:
		column(0, 15 + bob, 0, 9.1, 3.8, 5.2, B, 1.06)
		column(0, 21.2 + bob, 0, 10.2, 10.8, 5.6, B, 1.15)
		# the plate carrier: its own thickness, shoulder straps and three magazine pouches
		column(0, 21.7 + bob, 0.1, 10.3, 8.8, 6.35, V, 1.02, 0.48)
		box(0, 23.5 + bob, 3.36, 6.6, 3.2, 0.7, tint(V, 1.1), 0.28)
		for x in [-3.8, 3.8]:
			box(x, 23.8 + bob, 3.35, 1.25, 5.6, 0.8, tint(V, 0.72), 0.22)
		for x in [-2.9, 0, 2.9]:
			box(x, 19.1 + bob, 3.75, 2.35, 3.65, 1.55, tint(V, 0.94), 0.35)
			box(x, 20.2 + bob, 4.6, 2.35, 0.75, 0.22, tint(V, 1.15), 0.12)
		box(0, 15.8 + bob, 0, 9.35, 1.35, 5.8, "#35372b", 0.28)
		box(0, 15.8 + bob, 3.03, 1.6, 1.25, 0.45, "#b6ac7c", 0.22)
		column(0, 27 + bob, 0, 4.5, 2.8, 3.6, skin, 1, 0.32)   # a small collar between the head and the vest
		box(-1.65, 26.1 + bob, 2, 2, 1.7, 2, tint(B, 0.85), 0.3)
		box(1.65, 26.1 + bob, 2, 2, 1.7, 2, tint(B, 0.85), 0.3)


## winter clothing shares the class weapon rig while keeping its own construction
func _winter_clothes() -> void:
	if not o.get("winter") or o.get("sahur"):
		return
	var trim: String = o.winterTrim
	var brass := "#ceb777"
	var ice := "#b9e6f0"
	for side in [-1, 1]:
		box(side * 3.1, 5.4 + bob, 1.7, 4.5, 1.1, 4.1, trim, 0.2)
		box(side * 5.2, 25 + bob, 0, 2.1, 2.2, 5, tint(B, 0.85), 0.3)
	match o.winter:
		"snowline":
			beam(Vector3(-4, 26 + bob, 3.8), Vector3(2, 16 + bob, 4.3), 0.3, "#8c7961", 0.3, 0.1)
			box(-6, 18 + bob, -2, 2, 5, 2.3, "#96b0bd", 0.25)
		"summitranger":
			column(0, 26 + bob, 0, 11.5, 1.7, 7.5, trim, 1, 0.3)
			for i in 3:
				beam(Vector3(-4 + i * 0.7, 22 + bob, -4), Vector3(-4 + i * 0.7, 15 + bob, -4), 0.24, "#b9a888", 0.24, 0.1)
		"glacierengineer":
			box(0, 23 + bob, -4.2, 7.5, 8, 2.8, "#617c8c", 0.4)
			box(-6.1, 18 + bob, 2, 2.5, 4.5, 2, ice, 0.25)
			beam(Vector3(-6, 21 + bob, 3.1), Vector3(-6, 25 + bob, 3.1), 0.32, brass, 0.32, 0.1)
		"polarrescue":
			box(0, 17 + bob, 4.7, 8.8, 0.85, 0.3, "#e3eadd", 0.15)
			box(-6, 20 + bob, -1, 3.3, 5, 3, "#e6e8d9", 0.35)
			box(-7.75, 20 + bob, -1, 0.25, 2.6, 0.75, "#cd4e43", 0.08)
			box(-7.75, 20 + bob, -1, 0.25, 0.75, 2.6, "#cd4e43", 0.08)
		"evergreen":
			for side in [-1, 1]:
				beam(Vector3(side * 4.5, 20 + bob, -2), Vector3(side * 7, 27 + bob, -2), 0.65, "#5d6948", 0.1, 0.2)
				box(side * 4.5, 22 + bob, 3.5, 1.5, 5, 0.8, "#879f76", 0.2)
		"yuletideqm":
			column(0, 14.5 + bob, 0, 11.3, 4, 6.7, B, 1, 0.4)
			for x in [-5.4, 5.4]:
				box(x, 17.2 + bob, 1, 3.4, 4, 3, "#714e46", 0.3)
			for i in 3:
				box(0, 19 + i * 2 + bob, 4.7, 0.75, 0.75, 0.4, brass, 0.08)
		"gingergren":
			for x in [-4, 4]:
				beam(Vector3(x, 25 + bob, 3.9), Vector3(x, 17 + bob, 4.7), 0.28, "#f3dfba", 0.28, 0.08)
			for i in 3:
				box(-3 + i * 3, 23 + bob, 4, 1, 1, 0.6, "#cc6658" if i % 2 else "#79a48a", 0.1)
		"nutcracker":
			for i in 3:
				box(0, 19 + i * 2.1 + bob, 4.7, 5.5, 0.55, 0.4, brass, 0.15)
				for x in [-3, 3]:
					box(x, 19 + i * 2.1 + bob, 4.7, 0.8, 0.9, 0.4, brass, 0.1)
			for x in [-5.5, 5.5]:
				box(x, 26 + bob, 0, 3.1, 0.9, 6, brass, 0.25)
		"rimewarden":
			for side in [-1, 1]:
				column(side * 5.5, 25 + bob, -0.5, 3.5, 4.5, 6, ice, 0.4, 0.35)
				beam(Vector3(side * 5.5, 26 + bob, -1), Vector3(side * 7.5, 30 + bob, -1), 0.85, ice, 0.05, 0.2)
			box(0, 23 + bob, 4, 6, 3, 0.8, "#86c4d8", 0.3)
		"aurorasovereign":
			for side in [-1, 1]:
				beam(Vector3(side * 4.5, 26 + bob, 3.5), Vector3(side * 4, 17 + bob, 4.5), 0.25, trim, 0.25, 0.05)
			column(0, 14.7 + bob, 0, 10.8, 3.2, 6.7, "#455f72", 1, 0.35)
			box(0, 23.6 + bob, 4, 4, 2, 0.5, "#a7ded8", 0.2)


func _eye(x: float, y: float, rx: float, ry: float, z: float, col: String, bias: float = 1.2) -> void:
	var v: Array = []
	for i in 12:
		var a := i * PI / 6
		v.append(Vector3(x + cos(a) * rx, y + sin(a) * ry + bob, z))
	poly(v, col, 0.08, bias)


func _hair() -> void:
	dome("#433b2b", 32.7, 4.2, 3.6, 1.65)


## a flat cartoon bone wrapped round the band at angle th (the Bone-Button Wrap)
func _bone(th: float, y: float, ln: float, w: float = 0.42) -> void:
	var r := w * 0.95
	var hx := ln / 2 - r
	var pts: Array = []
	var arc := func(cx: float, cy: float, a0: float, a1: float) -> void:
		for k in 7:
			var a := a0 + (a1 - a0) * k / 6.0
			pts.append([cx + cos(a) * r, cy + sin(a) * r])
	arc.call(hx, r * 0.78, PI * 0.95, -PI * 0.35)
	arc.call(hx, -r * 0.78, PI * 0.35, -PI * 0.95)
	arc.call(-hx, -r * 0.78, -PI * 0.05, -PI * 1.35 + TAU)
	arc.call(-hx, r * 0.78, PI * 0.65, PI * 0.05)
	var v: Array = pts.map(func(q): var f: float = th + q[0] / 5.1; return Vector3(sin(f) * 5.46, y + bob + q[1], cos(f) * 4.78))
	poly(v, "#e9dfc5", 0.16, 1.2, true)


func _head(W: Dictionary) -> void:
	# opaque face pieces replace facial detail; eyes and nose behind them would break through when the head turns
	var face_covered: bool = o.get("hood") or o.get("sheet") or o.get("pumpkin") or o.get("glitchm") or o.get("mask") or o.get("visor") or o.get("hockey") or o.get("sack") or o.get("facewrap") or o.get("khelm") or o.get("bomb") or o.get("clownface") or o.get("hybridHat") == "skullhelm"
	if not o.get("pumpkin") and not o.get("sheet") and not o.get("sahur") and not o.get("winterModel"):
		column(0, 30.1 + bob, 0.2, 7.2, 6.4, 6.3, skin, 1.13, 0.6)
		column(-4.05, 30.5 + bob, 0.15, 1.15, 2.25, 2, skin, 1, 0.3)
		column(4.05, 30.5 + bob, 0.15, 1.15, 2.25, 2, skin, 1, 0.3)
		if not face_covered:
			box(-1.45, 30.75 + bob, 3.85, 0.7, 0.72, 0.18, "#34392c", 0.08, 1.5)
			box(1.45, 30.75 + bob, 3.85, 0.7, 0.72, 0.18, "#34392c", 0.08, 1.5)
			box(0, 29.9 + bob, 3.6, 0.75, 1.4, 0.7, tint(skin, 1.03), 0.08, 1.2)
			box(0, 28.55 + bob, 3.45, 1.75, 0.28, 0.18, tint(skin, 0.64), 0.05, 1.5)
	if o.get("sahur"):
		for x in [-1.9, 1.9]:
			_eye(x, 31.1, 1.2, 1.48, 4.32, "#efe7ce")
			_eye(x + 0.18, 31.05, 0.48, 0.83, 4.42, "#281b13", 1.4)
			_eye(x - 0.04, 31.48, 0.16, 0.23, 4.52, "#fff9e8", 1.6)
			beam(Vector3(x - 1.1, 33.02 + bob, 3.94), Vector3(x + 0.9, 33.25 + bob, 3.94), 0.17, "#604021", 0.13, 0.06)
		column(0, 29.6 + bob, 4.05, 1.1, 2.3, 1.35, "#ba8047", 0.8, 0.13)
		box(0, 27.9 + bob, 3.94, 3.5, 0.8, 0.22, "#4c2c19", 0.08, 1)
		box(0, 28.16 + bob, 4.08, 2.6, 0.22, 0.12, "#ead5af", 0.02, 1)
	# Sahur's log reaches y=36: its worn headgear moves to that crown
	sahur_lift = (0.0 if o.get("visor") else ((5.0 if o.get("downed") else 1.5) if o.get("headband") else (0.0 if o.get("halo") else 3.5))) if o.get("sahur") else 0.0
	solid_hat = true if o.get("phantom") else false
	if o.get("winterModel"):
		_winter_model_head()
	elif o.get("winterHat"):
		_winter_hat()
	elif o.get("hybridHat") and not o.get("sheet"):
		_hybrid_hat()
	elif o.get("pumpkin"):
		_pumpkin()
	elif o.get("witch"):   # a wide brim, a cone in three pieces that bends back, a purple band with a gold buckle
		brim(32.5 + bob, 15.5, 0.8, 13.5, o.witch, 0.4, 4.65, 4.15)
		column(0, 34.45 + bob, 0, 8.6, 3.7, 7.8, o.witch, 0.72, 0.45)
		column(0, 37.4 + bob, -0.6, 6, 2.6, 5.4, o.witch, 0.62, 0.4)
		beam(Vector3(0, 38.6 + bob, -1), Vector3(-0.6, 41.2 + bob, -3.4), 1.7, o.witch, 0.25, 0.35)
		column(0, 33.45 + bob, 0, 8.8, 1.1, 8, "#6a2a8a", 1, 0.2)
		box(0, 33.45 + bob, 4.05, 1.8, 1.3, 0.3, "#e2c25a", 0.15, 1)
		box(0, 33.45 + bob, 4.2, 0.8, 0.6, 0.2, "#6a2a8a", 0.02, 1.2)
	elif o.get("hood"):   # a deep hood, the face lost in shadow, two glowing eyes
		dome(o.hood, 29.2, 5.4, 5.1, 7.2)
		column(0, 29.4 + bob, -0.6, 11, 4.6, 10, o.hood, 0.95, 0.45)
		box(0, 28.4 + bob, -4.4, 8.6, 6.4, 1, o.hood, 0.35)
		box(0, 30.6 + bob, 4.35, 5.2, 5.4, 0.35, "#050407", 0.08, 1.3)
		for x in [-1.3, 1.3]:
			box(x, 31 + bob, 4.6, 0.9, 0.6, 0.2, o.get("reaper") if o.get("reaper") else "#8fe0ff", 0.02, 1.6)
	elif o.get("sheet"):   # the sheet comes up over the head, with two cut-out eyes
		dome(o.sheet, 26.3, 5.9, 5.2, 9.4)
		for x in [-1.5, 1.5]:
			box(x, 31.4 + bob, 4.72, 1.25, 1.9, 0.3, "#121014", 0.02, 1.6)
	elif o.get("halloweenHat"):
		_halloween_hat()
	elif o.get("hardhat"):
		dome(o.hardhat, 32, 5.1, 4.6, 4.4)
		column(0, 32.1 + bob, 0.5, 11.2, 0.45, 10.4, tint(o.hardhat, 0.88), 1, 0.4)
		beam(Vector3(0, 36.2 + bob, -3.3), Vector3(0, 36.2 + bob, 3.3), 0.55, tint(o.hardhat, 1.12), 0.55, 0.3)
	elif o.get("straw"):
		column(0, 32.4 + bob, 0, 15.2, 0.8, 13.8, o.straw, 1, 0.4)
		column(0, 34.2 + bob, 0, 8.4, 3.8, 7.4, tint(o.straw, 0.95), 0.82, 0.45)
		column(0, 33.1 + bob, 0, 8.6, 1, 7.6, "#7a3a1a", 1, 0.2)
	elif o.get("ghood"):
		dome(o.ghood, 31.4, 5.7, 5.1, 5.4)
		for i in 14:
			var a := i * TAU / 14
			if sin(a) > 0.5:
				continue
			beam(Vector3(cos(a) * 5.2, 32 + bob, sin(a) * 4.7), Vector3(cos(a) * 6.3, 27.4 + bob - (i % 3), sin(a) * 5.7), 0.42, o.ghood if i % 2 else tint(o.ghood, 0.72), 0.15, 0.15)
	elif o.get("bomb"):
		dome(o.bomb, 31.4, 5.9, 5.3, 5.6)
		box(0, 30.9 + bob, 4.35, 7, 3.6, 0.5, "#23303a", 0.3, 1.2)
		box(-1.6, 31.9 + bob, 4.62, 1.8, 0.35, 0.08, "#bfe6ff", 0.02, 1.4)
	elif o.get("slick"):
		dome(o.slick, 31.2, 4.35, 3.85, 2.8)
		mesh([Vector3(-1.4, 32.6 + bob, 3.72), Vector3(0, 31.5 + bob, 3.76), Vector3(1.4, 32.6 + bob, 3.72)], [[0, 1, 2]], o.slick, 0.06, 1.4)
		for x in [-3.55, 3.55]:
			box(x, 30.4 + bob, 0.9, 0.5, 2, 1.2, o.slick, 0.1)
	elif o.get("mop"):
		for q in [[-3.7, 31.6, -0.9, 2.1], [3.7, 31.6, -0.9, 2.1], [0, 33.7, -0.4, 2.7], [-2, 33.9, 1.6, 1.7], [2, 33.9, 1.5, 1.7], [0, 31.3, -3.3, 2.5], [-3, 29.6, -2.6, 1.9], [3, 29.6, -2.6, 1.9], [0, 28.6, -3.4, 2]]:
			ball(q[0], q[1] + bob, q[2], q[3], o.mop)
		for x in [-2, -0.6, 0.8, 2]:
			box(x, 32.3 + bob, 3.4, 0.5, 1.7, 0.3, o.mop, 0.08, 1)
	elif o.get("helmet"):
		dome(o.helmet)
		column(0, 32.1 + bob, 0.05, 10.6, 0.75, 9.1, tint(o.helmet, 0.73), 1, 0.28)
		box(-4.15, 30.5 + bob, 0.8, 0.55, 3.5, 1.2, tint(o.helmet, 0.53), 0.22)
		box(4.15, 30.5 + bob, 0.8, 0.55, 3.5, 1.2, tint(o.helmet, 0.53), 0.22)
		box(0, 34 + bob, 4.13, 1.75, 1.6, 0.5, tint(o.helmet, 0.62), 0.22)
		if o.get("hneon"):   # the band follows the helmet's curve
			for k in 6:
				var a0 := -0.72 + k * 0.24
				var a1 := a0 + 0.24
				beam(Vector3(sin(a0) * 5.36, 33.3 + bob, cos(a0) * 4.56), Vector3(sin(a1) * 5.36, 33.3 + bob, cos(a1) * 4.56), 0.26, o.hneon, 0.26, 0.04)
			box(0, 35 + bob, 3.7, 0.55, 2.6, 0.25, o.hneon, 0.04, 1)
	elif o.get("cap"):
		dome(o.cap, 32, 4.8, 4.2, 3.3)
		box(0, 32 + bob, 4.7, 8, 0.5, 4.4, tint(o.cap, 0.85), 0.4)
		if o.get("capPix"):
			box(0, 33.45 + bob, 3.95, 1.6, 1.4, 0.3, o.capPix, 0.03, 1)
			box(1.2, 32.95 + bob, 4.05, 0.6, 0.6, 0.2, o.capPix, 0.03, 1)
	elif o.get("boonie"):
		brim(32.1 + bob, 14, 0.9, 12, o.boonie, 0.45, 4.9, 4.3)
		dome(tint(o.boonie, 0.9), 32.2, 4.7, 4.1, 3.1)
		column(0, 33 + bob, 0.1, 9.6, 0.85, 8.4, tint(o.boonie, 0.64), 1, 0.2)
	elif o.get("beanie"):
		dome(o.beanie, 31.9, 5.1, 4.3, 4.7)
		column(0, 32.3 + bob, 0, 10.3, 1.5, 8.8, tint(o.beanie, 0.75), 1, 0.32)
		ball(0, 37.1 + bob, 0, 1.3, o.beanie)
	elif o.get("beret"):
		column(0, 32.2 + bob, 0, 9.6, 0.8, 8, "#28291f", 1, 0.25)
		column(1, 34 + bob, 0, 11, 3, 8.8, o.beret, 0.66, 0.5)
		box(-2, 33.5 + bob, 4.1, 1.4, 1.5, 0.3, "#d4be73", 0.2, 1)
	elif o.get("wrap"):
		dome(o.wrap, 31.8, 4.9, 4.1, 3.4)
		column(0, 32 + bob, 0, 10, 1.2, 8.5, tint(o.wrap, 0.74), 1, 0.2)
		beam(Vector3(-4.4, 32 + bob, -1), Vector3(-5.6, 28.4 + bob, -4), 0.5, o.wrap, 0.3)
	elif o.get("tophat"):
		column(0, 32.4 + bob, 0, 12, 0.9, 10, o.tophat, 1, 0.4)
		column(0, 33.8 + bob, 0, 8.6, 2.5, 7.6, "#be303b", 1, 0.24)
		column(0, 37.8 + bob, 0, 8.6, 6.1, 7.6, o.tophat, 1, 0.5)
	elif o.get("crown"):
		column(0, 32.7 + bob, 0, 10, 1.7, 8.6, o.crown, 1, 0.4)
		for i in 8:
			var a := i * PI / 4
			beam(Vector3(cos(a) * 4.6, 33 + bob, sin(a) * 4), Vector3(cos(a) * 5, 37 + bob, sin(a) * 4.3), 0.9, o.crown, 0.1, 0.3)
		box(0, 33 + bob, 4.45, 1.5, 1.4, 0.4, "#c43a4a", 0.15, 1)
	elif o.get("pcap"):
		column(0, 33.8 + bob, 0, 10.7, 3.7, 8.4, o.pcap, 1.12, 0.5)
		box(0, 32 + bob, 4.4, 8, 0.8, 3.8, tint(o.pcap, 0.55), 0.35)
		box(0, 34 + bob, 4.35, 1.6, 1.8, 0.4, "#e2c25a", 0.2, 1)
	elif o.get("khelm"):
		dome(o.khelm, 31.5, 5.5, 4.6, 5)
		column(0, 30 + bob, 0.7, 9.5, 4.8, 8.9, o.khelm, 1.04, 0.4)
		box(0, 31 + bob, 5.3, 7.6, 0.9, 0.3, "#111510", 0.08, 1)
		for x in [-1.5, 0, 1.5]:
			box(x, 29 + bob, 5.3, 0.45, 1.5, 0.3, "#252820", 0.06, 1)
		beam(Vector3(0, 36.4 + bob, -3), Vector3(0, 36.4 + bob, 3), 0.65, tint(o.khelm, 0.82), 0.65, 0.3)
	elif o.get("hair"):   # one rounded afro cap, clear of the eyes
		var seg := 12 if compact else 20
		var rings := 6 if compact else 10
		var v: Array = []
		var ff: Array = []
		for r in rings + 1:
			var a := -PI / 2 + PI * r / rings
			var y := 36 + sin(a) * 4.7
			var k := cos(a)
			for q in seg:
				var tt := TAU * q / seg
				v.append(Vector3(cos(tt) * 5.5 * k, y + bob, sin(tt) * 4.9 * k - 0.3))
		for r in rings:
			for q in seg:
				var a2 := r * seg + q
				var b2 := r * seg + (q + 1) % seg
				ff.append([a2 + seg, b2 + seg, b2, a2])
		mesh(v, ff, o.hair, 0.55)
		if o.get("hairGold"):
			for x in [-3, 1, 4]:
				box(x, 35.5 + bob, 1.7, 0.5, 0.7, 0.5, "#fff1b0", 0.03, 1)
	elif o.get("horns") or o.get("demonHorns"):
		var big: bool = true if o.get("demonHorns") else false
		if not big and not o.get("sahur"):
			dome("#2a1a14", 32.7, 4.2, 3.6, 1.65)
		var P: Array = [[2.1, 32.5, 0.4], [3.7, 34.6, -0.4], [5, 35.9, -2.3], [5, 36.8, -4.4], [4.1, 37.1, -5.9]] if big else [[2, 32.7, 0.7], [3.3, 34.4, 1], [4.3, 36, 0.7], [4.7, 37.6, 0], [4.5, 39, -0.8]]
		var R: Array = [1.35, 1.1, 0.85, 0.55, 0.14] if big else [1.05, 0.86, 0.64, 0.4, 0.08]
		var C: Array = [o.get("demonHorns"), "#2e1c14", "#3e2818", "#5a3a22"] if big else [o.get("horns"), "#5e0e0c", "#3a0a08", "#1c0606"]
		for sd in [-1, 1]:
			for i in 4:
				beam(Vector3(sd * P[i][0], P[i][1] + bob, P[i][2]), Vector3(sd * P[i + 1][0], P[i + 1][1] + bob, P[i + 1][2]), R[i], C[i], R[i + 1], 0.42)
			beam(Vector3(sd * (P[0][0] - 0.3), P[0][1] + 0.35 + bob, P[0][2]), Vector3(sd * (P[0][0] + 0.45), P[0][1] + 0.95 + bob, P[0][2] + 0.05), R[0] * 1.12, tint(C[0], 0.7), R[0] * 1.05, 0.3)
	else:
		if not (o.get("bones") or o.get("wraps") or o.get("phantom") or o.get("sahur")):
			dome("#433b2b", 32.7, 4.2, 3.6, 1.65)
		if o.get("mask"):
			column(0, 30.4 + bob, 1, 8.6, 5.4, 7.5, "#15151a", 1, 0.4)
			for x in [-1.8, 1.8]:
				box(x, 31 + bob, 4.9, 1.5, 0.85, 0.3, o.mask, 0.03, 1)
		if o.get("visor"):
			if o.get("sahur"):
				box(0, 32 + bob, 4.34, 8.8, 0.85, 0.65, "#593447", 0.22, 1)
				box(0, 32 + bob, 4.72, 7.8, 0.32, 0.15, o.visor, 0.03, 1)
			else:
				box(0, 31.2 + bob, 4.3, 8.8, 2.5, 0.9, "#101014", 0.32, 1)
				box(0, 31.2 + bob, 4.82, 7.8, 0.65, 0.15, o.visor, 0.03, 1)
		if o.get("headband"):
			column(0, 32.2 + bob, 0, 9, 0.65, 7.8, o.headband, 1, 0.15)
			beam(Vector3(-4.2, 32.2 + bob, -1), Vector3(-5.7, 28.7 + bob, -3.6), 0.35, o.headband, 0.2, 0.15)
		if o.get("glitchm"):
			var cs := ["#ff3a6a", "#3affd8", "#6a8aff", "#ffe03a", "#f3f0ff"]
			var f := floori(time * 10)
			box(0, 31.5 + bob, 0.2, 9.4, 9.4, 9.4, "#161923", 0.65)
			for y in 3:
				for x in 3:
					var a := (x - 1) * 3.0
					var b := 28.5 + y * 3 + bob
					box(a, b, 4.98, 2.72, 2.72, 0.18, cs[(f + x * 3 + y * 7) % 5], 0.06, 0.1)
					box(a, b, -4.58, 2.72, 2.72, 0.18, cs[(f + x + y * 2 + 1) % 5], 0.06, 0.1)
					box(-4.78, b, a + 0.2, 0.18, 2.72, 2.72, cs[(f + x * 2 + y + 2) % 5], 0.06, 0.1)
					box(4.78, b, a + 0.2, 0.18, 2.72, 2.72, cs[(f + x + y + 3) % 5], 0.06, 0.1)
					box(a, 36.28 + bob, (y - 1) * 3 + 0.2, 2.72, 0.18, 2.72, cs[(f + x + y * 3) % 5], 0.06, 0.1)
	sahur_lift = 0.0
	solid_hat = false
	if o.get("sheet") and o.get("hybridHat") == "dunce":   # the cone sits on the sheet's crown
		dunce_cone(35.1)
	if o.get("halo"):
		for i in 16:
			var a := i * PI / 8
			var b := (i + 1) * PI / 8
			var y: float = (43.0 if o.get("sheet") else (42.0 if o.get("sahur") else 39.0)) + bob + sin(time * 2.4) * 0.35
			beam(Vector3(cos(a) * 6, y, sin(a) * 4.8), Vector3(cos(b) * 6, y, sin(b) * 4.8), 0.22, o.halo, 0.22, 0.04)
	if o.get("demon"):   # burning eyes under a heavy brow, pointed ears
		box(0, 31.45 + bob, 3.7, 5.2, 0.7, 0.9, tint(skin, 0.55), 0.2, 1.1)
		for x in [-1.45, 1.45]:
			box(x, 30.75 + bob, 3.98, 1, 0.62, 0.16, "#ffd070", 0.02, 1.7)
		for sd in [-1, 1]:
			beam(Vector3(sd * 4.3, 30.9 + bob, 0.1), Vector3(sd * 5.9, 33 + bob, -0.6), 0.62, skin, 0.06, 0.3)
	if o.get("pbraid") and o.get("pcap"):
		box(0, 32.75 + bob, 4.52, 7.6, 0.35, 0.25, o.pbraid, 0.05, 1.1)
	if o.get("lamp") and o.get("cap"):
		box(0, 33.6 + bob, 4.5, 1.7, 1.3, 0.7, "#2a2a28", 0.2, 1)
		box(0, 33.6 + bob, 4.9, 1.2, 0.9, 0.15, o.lamp, 0.03, 1.3)
	if o.get("headset"):
		for x in [-4.9, 4.9]:
			box(x, 30.7 + bob, 0.3, 1.1, 2.5, 2.5, "#1e2022", 0.3)
		beam(Vector3(-4.9, 32.4 + bob, 0.3), Vector3(0, 36.2 + bob, 0.3), 0.35, "#1e2022", 0.35, 0.2)
		beam(Vector3(0, 36.2 + bob, 0.3), Vector3(4.9, 32.4 + bob, 0.3), 0.35, "#1e2022", 0.35, 0.2)
		beam(Vector3(4.9, 29.8 + bob, 1.2), Vector3(2, 28.6 + bob, 3.9), 0.18, "#1e2022", 0.18, 0.1)
		ball(1.8, 28.6 + bob, 4, 0.4, "#2a2c2e")
	if not o.get("pumpkin") and not o.get("sheet") and not o.get("sahur"):
		if o.get("facewrap"):
			box(0, 29.2 + bob, 0.35, 7.9, 2.5, 7.4, o.facewrap, 0.3, 0.8)
			box(0, 29.3 + bob, -3.55, 1.2, 1, 0.6, o.facewrap, 0.2, 0.9)
			beam(Vector3(0, 29.3 + bob, -3.6), Vector3(-0.8, 26.8 + bob, -4.2), 0.3, o.facewrap, 0.2, 0.15)
			beam(Vector3(0, 29.3 + bob, -3.6), Vector3(0.9, 27 + bob, -4.3), 0.3, o.facewrap, 0.2, 0.15)
		if o.get("hockey"):
			box(0, 30.5 + bob, 3.85, 6.2, 5.8, 0.55, o.hockey, 0.25, 1.2)
			column(0, 31.2 + bob, 0.2, 7.7, 0.35, 6.8, "#26221c", 1, 0.1)
			for x in [-1.45, 1.45]:
				box(x, 31.2 + bob, 4.14, 1.3, 0.9, 0.08, "#15110e", 0.02, 1.8)
			for q in [[-1.2, 29.2], [0, 29.2], [1.2, 29.2], [-0.6, 28.3], [0.6, 28.3], [-1.5, 32.4], [-0.5, 32.4], [0.5, 32.4], [1.5, 32.4]]:
				box(q[0], q[1] + bob, 4.14, 0.35, 0.35, 0.08, "#15110e", 0.02, 1.8)
		if o.get("clownface"):
			ball(0, 29.9 + bob, 3.95, 0.65, "#e02a2a")
			for x in [-1.45, 1.45]:
				mesh([Vector3(x + 0.8, 31.05 + bob, 3.9), Vector3(x, 32.1 + bob, 3.9), Vector3(x - 0.8, 31.05 + bob, 3.9), Vector3(x, 30 + bob, 3.9)], [[0, 1, 2, 3]], "#2a1a3a", 0.04, 1.5)
			box(0, 28.45 + bob, 3.62, 3.6, 0.45, 0.15, "#c01a2a", 0.02, 1.6)
			for x in [-1.9, 1.9]:
				box(x, 28.9 + bob, 3.6, 0.45, 0.9, 0.15, "#c01a2a", 0.02, 1.6)
		if o.get("stitches"):
			box(0, 32.3 + bob, 3.55, 4.6, 0.2, 0.12, o.stitches, 0.02, 1.6)
			for x in [-1.8, -0.6, 0.6, 1.8]:
				box(x, 32.3 + bob, 3.57, 0.18, 0.8, 0.1, o.stitches, 0.02, 1.7)
			box(2.4, 29.6 + bob, 3.42, 0.2, 1.8, 0.12, o.stitches, 0.02, 1.6)
			column(0, 27 + bob, 0, 4.8, 0.35, 3.9, o.stitches, 1, 0.05)
			box(0, 28.55 + bob, 3.52, 1.9, 0.35, 0.15, "#1c1416", 0.02, 1.6)
		if o.get("sack"):
			for x in [-1.45, 1.45]:
				box(x, 30.9 + bob, 3.95, 1.2, 1.2, 0.2, "#1a1410", 0.03, 1.6)
			box(0, 28.7 + bob, 3.62, 3.8, 0.25, 0.15, "#2a1a10", 0.02, 1.6)
			for k in range(-2, 3):
				box(k * 0.8, 28.7 + bob, 3.64, 0.18, 0.8, 0.12, "#2a1a10", 0.02, 1.7)
			column(0, 27.3 + bob, 0, 4.9, 0.5, 4, "#8a6a3a", 1, 0.15)
	box(0, 23 + bob, -3.3, 6.5, 5.7, 0.7, tint(V, 0.92), 0.3)
	box(0, 26.1 + bob, -3.8, 3.1, 0.65, 0.7, tint(V, 0.65), 0.2)


func _winter_model_head() -> void:
	var wm: String = o.winterModel
	if wm == "yulemaw":
		column(0, 30.3 + bob, 1, 10, 7.8, 8.5, B, 1.1, 0.6)
		for side in [-1, 1]:
			beam(Vector3(side * 4, 32 + bob, 0), Vector3(side * 7, 34 + bob, -1), 1.3, B, 0.06, 0.3)
			box(side * 2, 31.5 + bob, 5.1, 1.3, 0.85, 0.3, "#f5d365", 0.12, 1.4)
			beam(Vector3(side * 0.8, 32.2 + bob, 5.2), Vector3(side * 3, 32.8 + bob, 4.8), 0.25, "#2e4a25", 0.25, 0.08)
		column(0, 29.3 + bob, 5, 3.7, 2, 2.3, "#6baa4a", 0.85, 0.3)
		box(0, 27.7 + bob, 4.8, 4.3, 0.6, 0.4, "#263923", 0.1, 1.4)
		dome("#a33740", 33, 5.2, 4.5, 3.4)
		column(0, 33 + bob, 0, 10.8, 1.6, 9.3, "#eee4cc", 1, 0.3)
		beam(Vector3(0, 36 + bob, 0), Vector3(3.8, 37 + bob, -2), 1.8, V, 0.35, 0.3)
		ball(3.8, 37 + bob, -2, 1.2, "#eee4cc")
	elif wm == "rednosedemolisher":
		column(0, 30.8 + bob, 0, 6.7, 7.6, 6.3, B, 1.15, 0.5)
		column(0, 29.1 + bob, 4.4, 5, 3.4, 5, "#c1986c", 0.85, 0.4)
		ball(0, 29.8 + bob, 7.2, 1.45, "#ff4147")
		for side in [-1, 1]:
			beam(Vector3(side * 2.5, 33 + bob, 0), Vector3(side * 6, 34 + bob, -1), 1.4, B, 0.12, 0.3)
			box(side * 1.8, 32 + bob, 3.5, 0.7, 0.9, 0.3, "#242820", 0.08, 1.5)
			beam(Vector3(side * 2.2, 34 + bob, -0.7), Vector3(side * 3.3, 41 + bob, -1.7), 0.55, "#d0b58a", 0.25, 0.2)
			for i in 3:
				beam(Vector3(side * (2.7 + i * 0.2), 36 + i * 1.6 + bob, -1), Vector3(side * (5 + i * 0.2), 38 + i * 1.8 + bob, -1.5), 0.33, "#d0b58a", 0.06, 0.13)
	else:
		column(0, 30.7 + bob, 0, 6.2, 7, 5.7, "#d9f0f5", 1.1, 0.5)
		for side in [-1, 1]:
			box(side * 1.25, 31.1 + bob, 3.05, 0.7, 0.8, 0.25, "#547cba", 0.06, 1.4)
			beam(Vector3(side * 3, 32 + bob, -0.4), Vector3(side * 5, 36 + bob, -2), 0.9, "#b6e8f5", 0.04, 0.2)
		for q in [[-2.7, 38, -1], [0, 40, -1.7], [2.2, 37, -0.4], [-1, 37, 2]]:
			beam(Vector3(q[0], 33 + bob, q[2]), Vector3(q[0] * 0.8, q[1] + bob, q[2] - 1.5), 1.1, "#d6f6fc", 0.04, 0.25)
		column(0, 33.1 + bob, 0, 6.7, 0.7, 6.1, "#e0b857", 1, 0.2)
		box(0, 28.7 + bob, 3.05, 1.4, 0.25, 0.2, "#638caa", 0.05, 1.3)


func _winter_hat() -> void:
	var iv := "#e5e7d3"
	match String(o.winterHat):
		"snowgoggles":
			dome("#aebfc4", 32, 4.6, 4, 2)
			box(0, 31.8 + bob, 4.3, 7.8, 2.1, 0.9, "#454d48", 0.3)
			box(0, 31.8 + bob, 4.85, 6.5, 1.4, 0.25, "#d7a252", 0.1)
			for side in [-1, 1]:
				box(side * 4.5, 31.8 + bob, 0, 0.6, 1.4, 7, "#625c4b", 0.15)
		"ushanka":
			column(0, 33.4 + bob, 0, 10, 3.1, 8, "#365949", 0.85, 0.5)
			column(0, 32 + bob, 0, 10.5, 1.3, 8.5, iv, 1, 0.3)
			for side in [-1, 1]:
				box(side * 4.3, 30.5 + bob, -0.5, 2, 4, 5, iv, 0.4)
		"surveyhelm":
			dome("#8aaabd", 32, 5.2, 4.5, 3.8)
			box(0, 34 + bob, 4.3, 2.9, 2.2, 1.5, "#384f61", 0.3)
			box(0, 34 + bob, 5.1, 1.8, 1.5, 0.2, "#f1e9b4", 0.1)
		"rescuehood":
			dome("#b96743", 31.5, 5.5, 4.8, 4.6)
			for side in [-1, 1]:
				column(side * 4.3, 29.9 + bob, 0, 2.3, 5.5, 6.3, iv, 0.85, 0.3)
			box(0, 28 + bob, -3.8, 9, 3, 2, "#be704a", 0.3)
		"pinecrown":
			dome("#405744", 32.5, 4.5, 4, 1.9)
			for side in [-1, 1]:
				beam(Vector3(side * 3.5, 33 + bob, 0), Vector3(side * 6, 37 + bob, 0), 0.4, "#7c7250", 0.13, 0.2)
				beam(Vector3(side * 4.8, 35 + bob, 0), Vector3(side * 7, 35.5 + bob, 1), 0.32, "#628e6a", 0.08, 0.15)
		"yulecap":
			dome("#773b49", 32, 5, 4.4, 3)
			column(0, 32.7 + bob, 0, 10.4, 1.3, 8.9, iv, 1, 0.3)
			beam(Vector3(0, 35 + bob, -0.5), Vector3(3, 36 + bob, -2), 1.6, "#9a4954", 0.4, 0.25)
			column(3, 36 + bob, -2, 1.6, 1.6, 1.6, iv, 1, 0.2)
		"icinghelm":
			dome("#ad7d51", 32, 5.2, 4.5, 4.2)
			for x in [-3, 0, 3]:
				beam(Vector3(x, 32 + bob, 4.3), Vector3(x * 0.7, 35 + bob, 2), 0.25, "#f2dfbf", 0.25, 0.08)
			box(0, 34 + bob, 4.1, 1.3, 1.3, 0.5, "#bb5960", 0.12)
		"shako":
			column(0, 35 + bob, 0, 8.7, 6, 7.7, "#263a54", 0.93, 0.5)
			column(0, 32.7 + bob, 0, 9.1, 1.3, 8.1, "#c1ac6d", 1, 0.2)
			brim(32.2 + bob, 10, 0.8, 8, "#30415a", 0.35, 3.8, 3)
			box(0, 35 + bob, 4, 2, 2.5, 0.5, "#d7be74", 0.15)
			beam(Vector3(0, 38 + bob, 0), Vector3(0.5, 41 + bob, -0.3), 0.8, "#bd4d55", 0.2, 0.2)
		"rimecrest":
			dome("#7cabbf", 32, 5, 4.3, 3.6)
			for x in [-2.8, 0, 2.8]:
				beam(Vector3(x, 34 + bob, 0), Vector3(x * 0.7, 39 - absf(x) * 0.6 + bob, -0.4), 0.85, "#c2eefa", 0.04, 0.25)
		"aurorahalo":
			dome("#3d5d73", 32, 4.7, 4.1, 3)
			for i in 8:
				var a := i * PI / 4
				var b := a + PI / 4
				var r := 6.1
				beam(Vector3(cos(a) * r, 38 + bob + sin(time * 0.8 + i) * 0.25, sin(a) * r), Vector3(cos(b) * r, 38 + bob + sin(time * 0.8 + i + 1) * 0.25, sin(b) * r), 0.18, "#b4a0e9" if i % 2 else "#8ae8d2", 0.18, 0.04)


func _hybrid_hat() -> void:
	var h: String = o.hybridHat
	if (h == "shades" or h == "yamaka" or h == "dunce") and not (o.get("bones") or o.get("wraps") or o.get("phantom")):
		_hair()
	match h:
		"shades":
			box(0, 31.3 + bob, 4.35, 8.4, 1.7, 0.7, "#0b0b0d", 0.3, 1)
			for x in [-2, 2]:
				box(x, 31.3 + bob, 4.75, 2.9, 1.3, 0.2, "#1d2226", 0.05, 1.2)
			box(-2.7, 31.7 + bob, 4.9, 0.7, 0.4, 0.12, "#ffffff", 0.01, 1.5)
			for side in [-1, 1]:
				box(side * 4.5, 31.5 + bob, 1.4, 0.4, 0.5, 5.6, "#0b0b0d", 0.12)
		"yamaka":
			dome("#141414", 33.7, 2.7, 2.4, 0.9)
		"ballhelm":
			dome("#e8702a", 31.7, 5.5, 4.7, 4.8)
			column(0, 31.9 + bob, 0, 11, 0.5, 9.4, "#1a1a1a", 1, 0.15)
			var top := Vector3(0, 36.4 + bob, 0)
			for p in [Vector3(0, 31.9 + bob, 4.7), Vector3(0, 31.9 + bob, -4.7), Vector3(-5.4, 31.9 + bob, 0), Vector3(5.4, 31.9 + bob, 0)]:
				beam(p, top, 0.2, "#1a1a1a", 0.2, 0.05)
		"gridhelm":
			dome("#1d2b4a", 31.4, 5.7, 5, 5.1)
			for side in [-1, 1]:
				box(side * 4.6, 29.9 + bob, 0.6, 0.9, 3.6, 3.6, "#1d2b4a", 0.25)
			for y in [28.6, 30.2]:
				box(0, y + bob, 4.95, 7.6, 0.45, 0.45, "#9aa3ab", 0.1, 1.2)
			for x in [-2.6, 0, 2.6]:
				box(x, 29.4 + bob, 4.95, 0.45, 2.4, 0.45, "#9aa3ab", 0.1, 1.2)
			box(0, 35.4 + bob, 0, 0.9, 1.4, 8.6, "#c4ced4", 0.15)
		"dunce":
			dunce_cone(32.8)
		"prop":
			dome("#2a6fd1", 31.9, 5.1, 4.3, 4.4)
			column(0, 32.2 + bob, 0, 10.3, 1.3, 8.8, "#ffd23a", 1, 0.3)
			beam(Vector3(0, 36.2 + bob, 0), Vector3(0, 37.6 + bob, 0), 0.25, "#2a2a2a", 0.25, 0.05)
			var a := time * 9
			for k in [0.0, PI]:
				beam(Vector3(0, 37.7 + bob, 0), Vector3(cos(a + k) * 3.6, 37.7 + bob, sin(a + k) * 3.6), 0.55, "#e03a3e" if k else "#3fae49", 0.25, 0.12)
			ball(0, 37.8 + bob, 0, 0.45, "#ffd23a")
		"conductor":
			column(0, 33.4 + bob, 0, 9.8, 2.8, 8.6, "#1b2a4a", 1.05, 0.45)
			column(0, 33.9 + bob, 0, 10.1, 0.7, 8.9, "#d4b24a", 1, 0.15)
			box(0, 32.4 + bob, 4.9, 7.2, 0.45, 2.6, "#121c33", 0.3)
			box(0, 33.9 + bob, 4.5, 1.6, 1.2, 0.3, "#d4b24a", 0.1, 1.1)
		"skullhelm":
			dome("#e9e2cc", 30.6, 5.8, 5.1, 6.2)
			for x in [-1.7, 1.7]:
				box(x, 31.3 + bob, 4.95, 2, 1.7, 0.3, "#18140f", 0.04, 1.4)
			box(0, 29.4 + bob, 5.05, 0.9, 1, 0.3, "#18140f", 0.04, 1.4)
			for x in [-1.8, -0.6, 0.6, 1.8]:
				box(x, 27.8 + bob, 4.75, 0.7, 1.1, 0.35, "#d8d0b8", 0.12, 1.2)


## a ribbed pumpkin replaces the head; the carved face glows (the Pumpkin King's flames flicker)
func _pumpkin() -> void:
	var pc: String = o.pumpkin
	var glow := "#ffb040" if o.get("pking") else "#ffd35a"
	var cy := 30.3
	var RX := 5.2
	var RY := 4.1
	var RZ := 4.8
	var SEG := 12 if compact else 24
	var RINGS := 5 if compact else 8
	var v: Array = []
	var ff: Array = []
	for r in RINGS + 1:
		var a := -PI / 2 + PI * r / RINGS
		var y := sin(a) * RY
		var k := cos(a) * (0.25 if r == 0 or r == RINGS else 1.0)
		for q in SEG:
			var t := TAU * q / SEG
			var rib := 1 - 0.085 * (1 - cos(8 * t)) / 2
			v.append(Vector3(cos(t) * RX * k * rib, cy + y + bob - (0.5 if r == RINGS else 0.0), sin(t) * RZ * k * rib))
	for r in RINGS:
		for q in SEG:
			var a0 := r * SEG + q
			var a1 := r * SEG + (q + 1) % SEG
			ff.append([a0 + SEG, a1 + SEG, a1, a0])
	var top: Array = []
	var bot: Array = []
	for q in SEG:
		top.append(q)   # reversed of RINGS*SEG+SEG-1-q
		bot.append(SEG - 1 - q)
	ff.append(top.map(func(q): return RINGS * SEG + q))
	ff.append(bot)
	mesh(v, ff, pc, 0.55)
	beam(Vector3(0, cy + RY - 0.7 + bob, 0), Vector3(0.5, cy + RY + 1.3 + bob, 0.35), 0.55, "#4a6a22", 0.4, 0.35)
	var fz := RZ * 0.985
	for pts in [[[-2.9, 31.5], [-1.4, 33.3], [-0.5, 31.5]], [[0.5, 31.5], [1.4, 33.3], [2.9, 31.5]],
			[[-3.1, 29.9], [-2, 28.7], [-1, 29.5], [0, 28.5], [1, 29.5], [2, 28.7], [3.1, 29.9], [2.2, 28], [-2.2, 28]]]:
		var q: Array = pts.map(func(p): return Vector3(p[0] * 0.9, cy + (p[1] - 31) * 0.9 + bob, fz - pow(p[0] / RX, 2) * 1.3))
		q.reverse()
		poly(q, glow, 0.06, 1.2)
	if o.get("pking"):
		for e in [[0, -1.8, 0.6], [1, 0, -0.2], [2, 1.8, 0.5]]:
			var f := 1.6 + 1.3 * absf(sin((time + e[0] * 0.7) * 1.9))
			beam(Vector3(e[1], cy + RY - 0.3 + bob, e[2]), Vector3(e[1] * 0.8, cy + RY - 0.3 + bob + f, e[2]), 0.8, "#ffd24a" if e[0] == 1 else "#ff7a1a", 0.05, 0.1)


## the six Halloween Case pieces as full headwear
func _halloween_hat() -> void:
	var h: String = o.halloweenHat
	var ivory := "#e9dfc5"
	if h == "gravecap":
		dome("#3a3843", 32, 5.1, 4.5, 3.9)
		column(0, 32.45 + bob, 0, 10.5, 1.1, 9.1, "#2a2830", 1, 0.32)
		box(0, 32.05 + bob, 4.55, 7, 0.42, 2.9, "#26242b", 0.35)
		for k in range(-3, 4):
			box(k * 1.25, 32.45 + bob, 4.52 - absi(k) * 0.18, 0.35, 0.12, 0.1, "#6d6a74", 0.01, 1.2)
		box(0, 35.3 + bob, 3.05, 3.1, 3.3, 0.95, "#9d9f99", 0.32)
		column(0, 37.05 + bob, 3.05, 3.1, 0.95, 0.95, "#9d9f99", 0.5, 0.32)
		box(0, 35.65 + bob, 3.56, 0.38, 2, 0.1, "#4a4a52", 0.02, 1.3)
		box(0, 36.1 + bob, 3.56, 1.35, 0.38, 0.1, "#4a4a52", 0.02, 1.3)
		beam(Vector3(-1.1, 34.2 + bob, 3.5), Vector3(-0.6, 34.9 + bob, 3.55), 0.07, "#5b5b62", 0.05, 0.02)
		ball(-1.15, 33.85 + bob, 3.35, 0.45, "#5e7a3a")
		ball(1.25, 33.9 + bob, 3.3, 0.36, "#6f8c45")
		ball(-0.5, 33.7 + bob, 3.5, 0.3, "#78964b")
	elif h == "stemband":
		_hair()
		column(0, 32.9 + bob, 0, 9.5, 1.55, 8.6, "#e07a24", 1, 0.36)
		column(0, 33.72 + bob, 0, 9.3, 0.24, 8.4, "#f3a24c", 1, 0.1)
		for k in 10:
			var a := k * PI / 5
			beam(Vector3(cos(a) * 4.78, 32.2 + bob, sin(a) * 4.34), Vector3(cos(a) * 4.72, 33.6 + bob, sin(a) * 4.28), 0.2, "#b8561a", 0.2, 0.06)
		column(0.2, 34.9 + bob, -0.3, 1.35, 1.5, 1.35, "#586a2a", 0.78, 0.32)
		beam(Vector3(0.2, 35.5 + bob, -0.3), Vector3(0.65, 36.6 + bob, -0.55), 0.44, "#6b7a33", 0.36, 0.3)
		beam(Vector3(0.65, 36.6 + bob, -0.55), Vector3(1.45, 37.05 + bob, -0.85), 0.36, "#6b7a33", 0.24, 0.3)
		beam(Vector3(-0.2, 35.2 + bob, -0.1), Vector3(-2.3, 35.9 + bob, 0.7), 0.62, "#6f9a42", 0.22, 0.3)
		beam(Vector3(-0.4, 35.3 + bob, -0.1), Vector3(-2.1, 35.8 + bob, 0.6), 0.08, "#9cc46a", 0.05, 0.02)
		beam(Vector3(0.5, 35.1 + bob, 0.1), Vector3(2.2, 35.5 + bob, 1.5), 0.5, "#6f9a42", 0.18, 0.3)
		beam(Vector3(1.45, 37.05 + bob, -0.85), Vector3(2, 36.6 + bob, -0.6), 0.1, "#8aaa4a", 0.1, 0.04)
		beam(Vector3(2, 36.6 + bob, -0.6), Vector3(1.75, 36.15 + bob, -0.2), 0.1, "#8aaa4a", 0.1, 0.04)
		beam(Vector3(1.75, 36.15 + bob, -0.2), Vector3(1.35, 36.45 + bob, -0.1), 0.1, "#8aaa4a", 0.08, 0.04)
	elif h == "batcirclet":
		_hair()
		column(0, 33 + bob, 0, 9.25, 0.95, 8.45, "#3a3346", 1, 0.32)
		column(0, 33.52 + bob, 0, 9.3, 0.2, 8.5, "#8b7ba8", 1, 0.08)
		for x in [-4.62, 4.62]:
			column(x, 33 + bob, 0, 0.5, 0.7, 0.9, "#9a6ad6", 0.8, 0.1)
		for sd in [-1, 1]:
			var P: Array = [[0.35, 34.45, 3.99], [1.45, 35.55, 3.86], [1.75, 34.95, 3.82], [2.5, 35.35, 3.64], [2.75, 34.7, 3.54], [3.45, 35.15, 3.24], [3.25, 34.05, 3.4], [1.25, 33.8, 3.9]].map(func(q): return Vector3(q[0] * sd, q[1] + bob, q[2] + 0.08))
			poly(P, "#221c2c", 0.28, 1.1, sd > 0)
		ball(0, 34.2 + bob, 4.02, 0.58, "#1d1824")
		ball(0, 34.8 + bob, 4.05, 0.4, "#1d1824")
		for sd in [-1, 1]:
			beam(Vector3(sd * 0.2, 35 + bob, 4.05), Vector3(sd * 0.34, 35.55 + bob, 4), 0.13, "#1d1824", 0.04, 0.12)
		for sd in [-1, 1]:
			box(sd * 0.17, 34.85 + bob, 4.42, 0.13, 0.11, 0.08, "#ff4a5a", 0.01, 0.6)
	elif h == "bonewrap":
		dome("#7a2d3a", 31.9, 5.25, 4.55, 3.5)
		column(0, 32.4 + bob, 0, 10.6, 1.3, 9.2, "#6a2230", 1, 0.32)
		column(0, 33.85 + bob, -0.25, 9.7, 1, 8.5, "#8a3444", 0.9, 0.26)
		ball(0, 33.2 + bob, -4.45, 0.9, "#6a2230")
		beam(Vector3(-0.3, 32.8 + bob, -4.65), Vector3(-1.15, 30.2 + bob, -5.35), 0.55, "#7a2d3a", 0.3, 0.3)
		beam(Vector3(0.4, 32.8 + bob, -4.6), Vector3(1.35, 30.7 + bob, -5.15), 0.5, "#7a2d3a", 0.28, 0.3)
		_bone(0, 32.7, 5, 0.7)
	elif h == "webpin":
		_hair()
		column(1.9, 34.35 + bob, 0.5, 4.3, 1.35, 3.7, "#1f1b24", 0.9, 0.36)
		column(1.9, 33.9 + bob, 0.5, 4.4, 0.36, 3.8, "#6b1f2e", 1, 0.1)
		var pin := Vector3(2.95, 33.55 + bob, 3.92)
		var T2: Array = [[-2.55, 32.2, 3.95], [-1.2, 31.85, 4.28], [0.3, 31.8, 4.4], [1.7, 32, 4.2], [0.15, 34.55, 3.72], [-1.5, 34.2, 3.86]].map(func(q): return Vector3(q[0], q[1] + bob, q[2] + 0.06))
		for q in T2:
			beam(pin, q, 0.075, ivory, 0.05, 0.02)
		for f in [0.38, 0.7, 1.0]:
			for k in T2.size() - 1:
				if k == 3:
					continue
				beam(pin.lerp(T2[k], f), pin.lerp(T2[k + 1], f), 0.055, ivory, 0.055, 0.02)
		ball(pin.x, pin.y, pin.z + 0.12, 0.4, "#df853a")
		ball(pin.x + 0.35, pin.y + 0.5, pin.z, 0.52, "#1a1418")
		for sd in [-1, 1]:
			for k in 4:
				var a := (k - 1.5) * 0.45
				beam(Vector3(pin.x + sd * 0.25, pin.y + a * 0.3, pin.z + 0.1), Vector3(pin.x + sd * (0.95 - absf(k - 1.5) * 0.12), pin.y + a * 0.9 - 0.1, pin.z + 0.05), 0.06, "#1a1418", 0.04, 0.02)
	elif h == "skullseal":
		_hair()
		column(0, 33 + bob, 0, 9.6, 1.4, 8.7, "#2b1f38", 1, 0.36)
		column(0, 32.3 + bob, 0, 9.66, 0.14, 8.76, "#b8943a", 1, 0.06)
		for k in 7:
			var a0 := PI * (0.12 + k * 0.76 / 7)
			var a1 := PI * (0.12 + (k + 1) * 0.76 / 7)
			var r := 2.65
			var t := 1 - absf(k - 3) / 3.5
			beam(Vector3(cos(a0) * r, 35.45 + sin(a0) * r * 0.95 + bob, 3.2), Vector3(cos(a1) * r, 35.45 + sin(a1) * r * 0.95 + bob, 3.2), 0.14 + 0.3 * t, "#ffe39a", 0.14 + 0.3 * (1 - absf(k + 1 - 3) / 3.5), 0.12)
		ball(0, 34.45 + bob, 4.3, 1.24, ivory)
		box(0, 33.25 + bob, 4.42, 1.45, 0.62, 0.92, ivory, 0.12)
		for sd in [-1, 1]:
			box(sd * 0.46, 34.4 + bob, 5.4, 0.48, 0.46, 0.1, "#1b1520", 0.02, 1.6)
		box(0, 33.82 + bob, 5.42, 0.2, 0.26, 0.08, "#1b1520", 0.02, 1.6)
		box(0, 33.22 + bob, 4.9, 1.15, 0.08, 0.05, "#1b1520", 0.02, 1.6)
		for sd in [-1, 1]:
			column(sd * 3.35, 33 + bob, 3.15, 0.75, 0.75, 0.45, "#b48cff", 0.8, 0.12)
			beam(Vector3(sd * 1.3, 33 + bob, 4.3), Vector3(sd * 2.9, 33 + bob, 3.5), 0.16, "#d9b44a", 0.16, 0.1)


func _diamond(x: float, y: float, z: float, rx: float, ry: float, col: String, bias: float) -> void:
	var p := [[x, y + ry, z], [x + rx, y, z], [x, y - ry, z], [x - rx, y, z]]
	if z > 0:
		p.reverse()
	decal(p, col, bias)


func _addons(elL: Vector3, elR: Vector3, haL: Vector3, haR: Vector3, gold_clown: bool, gold_police: bool, gold_knight: bool) -> void:
	if o.get("demon"):   # folded wings, a tail, shoulder spikes, claws and ember cracks
		var M := "#2a0808"
		var bone := "#160404"
		var root := Vector3(3, 27, -3)
		var tips := [Vector3(12.5, 33.5, -7), Vector3(14, 25, -8), Vector3(10, 17.5, -6.2)]
		for sd in [-1.0, 1.0]:
			var S := Vector3(sd, 1, 1)
			var wing := func(pts: Array) -> void:
				var v: Array = pts.map(func(q): return q * S + Vector3(0, bob, 0))
				mesh(v, [[0, 1, 2], [2, 1, 0]], M, 0.4)
			for i in 2:
				wing.call([root, tips[i], tips[i + 1]])
			wing.call([root, tips[2], Vector3(4, 19, -4.2)])
			for q in tips:
				beam(root * S + Vector3(0, bob, 0), q * S + Vector3(0, bob, 0), 0.45, bone, 0.12, 0.25)
			beam(Vector3(sd * 6.3, 26.4 + bob, 0.2), Vector3(sd * 7.9, 29.8 + bob, -0.5), 0.78, tint(B, 0.6), 0.05, 0.3)
			beam(Vector3(sd * 5.6, 25.4 + bob, 1.4), Vector3(sd * 6.9, 27.9 + bob, 1.2), 0.5, tint(B, 0.6), 0.04, 0.25)
		var tl := [Vector3(0, 15.4, -3), Vector3(0, 11.5, -7), Vector3(1.6, 7.2, -9.3), Vector3(3.4, 5.2, -8.8)]
		var tr := [1.0, 0.8, 0.55, 0.35]
		for i in 3:
			beam(tl[i] + Vector3(0, bob, 0), tl[i + 1] + Vector3(0, bob, 0), tr[i], B, tr[i + 1], 0.35)
		var e: Vector3 = tl[3]
		mesh([Vector3(e.x + 1.4, e.y + bob, e.z + 0.3), Vector3(e.x, e.y + 1.3 + bob, e.z), Vector3(e.x - 1.2, e.y + bob, e.z - 0.3), Vector3(e.x, e.y - 1.8 + bob, e.z)], [[0, 1, 2, 3], [3, 2, 1, 0]], tint(B, 0.7), 0.35)
		for ha in [haL, haR]:
			for k in range(-1, 2):
				beam(Vector3(ha.x + k * 0.55, ha.y - 0.5, ha.z + 0.4), Vector3(ha.x + k * 0.8, ha.y - 1.9, ha.z + 1.6), 0.26, "#e8d8c0", 0.03, 0.12)
		for q in [[-2.4, 25.3, 0.28, 2.2], [-2, 24.1, 1.1, 0.28], [1.8, 25.6, 0.28, 1.7], [2.4, 24.6, 1.3, 0.26], [0.3, 26.2, 0.26, 1.2], [-3.6, 17.5, 0.28, 1.8], [3.4, 18.2, 0.28, 1.5]]:
			box(q[0], q[1] + bob, 3.78 if q[1] > 20 else 3.32, q[2], q[3], 0.14, o.demon, 0.02, 1.1)
	if o.get("pack"):
		column(0, 21 + bob, -4.8, 9, 8.7, 4.2, o.pack, 0.96, 0.5)
		box(0, 23.9 + bob, -7, 7.6, 0.8, 0.5, tint(o.pack, 0.65), 0.2)
		box(0, 19 + bob, -7.1, 5, 3.6, 0.7, tint(o.pack, 1.06), 0.25)
	if o.get("bandolier"):   # a chest belt of five grenades on a strap, and a smaller row on the waist belt
		beam(Vector3(-4.3, 26 + bob, 3.9), Vector3(4.3, 17 + bob, 4.75), 0.6, "#3a3020", 0.6, 0.2)
		for i in 5:
			var t := (i + 0.5) / 5
			var x := -4.3 + 8.6 * t
			var y := 26 - 9 * t + bob
			var z := 4.75 + 0.85 * t
			column(x, y, z, 1.75, 2.05, 1.7, "#8aa83f", 0.8, 0.4)
			box(x, y + 1.15, z, 0.55, 0.45, 0.55, "#8f9486", 0.1)
			box(x + 0.45, y + 0.9, z + 0.35, 0.18, 0.7, 0.18, "#c9c2a2", 0.05, 0.6)
		for x in [-3.2, -1.6, 0]:
			column(x, 15.9 + bob, 3.95, 1.3, 1.55, 1.3, "#8aa83f", 0.8, 0.3)
	if o.get("stripe"):
		for z in [4.04, -3.6]:
			for x in [-3.6, 0, 3.4]:
				var p := [[x - 1, 25, z], [x + 0.4, 25, z], [x + 2, 21, z], [x + 0.4, 21, z]]
				if z > 0:
					p.reverse()
				decal(p, o.stripe)
		for side in [-1, 1]:
			box(side * 6.9, 23 + bob, 1.8, 1.6, 0.75, 0.4, o.stripe, 0.03, 0.5)
			box(side * 3.1, 10.7 + bob, 2, 2.8, 0.65, 0.3, o.stripe, 0.03, 0.5)
	if o.get("plate"):
		for x in [-6.4, 6.4]:
			column(x, 25 + bob, 0.1, 5.3, 3.1, 5.3, o.plate, 0.9, 0.5)
		chest(0, 23.7, 6.8, 3.4, o.plate)
		chest(0, 23.7, 0.5, 3.6, tint(o.plate, 0.55), 4.22)
		for y in [17.7, 19, 20.3]:
			chest(0, y, 7.7, 0.5, o.plate, 4.72)
	if o.get("neon"):
		for x in [-3.8, 3.8]:
			chest(x, 23.5, 0.4, 4.4, o.neon, 4.35)
		for x in [-4.55, 4.55]:
			beam(Vector3(x, 25.5 + bob, 3.65), Vector3(x * 0.9, 17.4 + bob, 4.5), 0.18, o.neon, 0.18, 0.015)
			beam(Vector3(x, 25.5 + bob, -3.4), Vector3(x * 0.9, 18 + bob, -3.4), 0.17, o.neon, 0.17, 0.015)
		chest(0, 16.5, 8.7, 0.35, o.neon, 3.9)
		for side in [-1, 1]:
			box(side * 3.1, 3.3, 3.7, 3, 0.3, 0.2, o.neon, 0.01)
	if o.get("badge"):
		var bx := -2.5
		var bz := 4.35
		var bp := [[bx, 25.5, bz], [bx + 1.25, 24.8, bz], [bx + 0.8, 22.9, bz], [bx, 22.4, bz], [bx - 0.8, 22.9, bz], [bx - 1.25, 24.8, bz]]
		bp.reverse()
		decal(bp, o.badge, 0.9)
		chest(bx, 24.3, 0.35, 1.1, tint(o.badge, 0.58), 4.5)
	if o.get("ruff"):
		for i in 10:
			var a := i * PI / 5
			var b := (i + 1) * PI / 5
			var p := [[cos(a) * 4.7, 26, sin(a) * 3.8], [cos((a + b) / 2) * 4.3, 27.8, sin((a + b) / 2) * 3.7], [cos(b) * 4.7, 26, sin(b) * 3.8]]
			decal(p, o.ruff, 0.15)
			var r := p.duplicate()
			r.reverse()
			decal(r, o.ruff, 0.15)
	if o.get("dots"):
		for z in [4.33, -3.7]:
			for q in [[-2.7, 24.6], [2.8, 21.8], [-0.6, 22.5], [0.7, 25.1]]:
				var p: Array = []
				for i in 8:
					p.append([q[0] + cos(i * PI / 4) * 0.8, q[1] + sin(i * PI / 4) * 0.8, z])
				if z < 0:
					p.reverse()
				decal(p, o.dots, 0.8)
	if o.get("spots"):
		for z in [4.15, -3.7]:
			for q in [[-2.7, 23.7, 2.4], [1.2, 24.1, 3.1], [3, 21.5, 1.8]]:
				box(q[0], q[1] + bob, z, 0.8, q[2], 0.2, o.spots, 0.03, 0.7)
				box(q[0] + 0.35, q[1] + q[2] / 2 + bob, z, 1.5, 0.65, 0.2, o.spots, 0.03, 0.7)
		box(-6.9, 24 + bob, 1.8, 1.25, 1.5, 0.35, o.spots, 0.03, 0.5)
	if o.get("frost"):
		for z in [4.2, -3.7]:
			for q in [[-3, 24], [3, 23], [0, 19.5]]:
				box(q[0], q[1] + bob, z, 1.7, 0.35, 0.2, o.frost, 0.015, 0.7)
				box(q[0], q[1] + bob, z, 0.35, 1.7, 0.2, o.frost, 0.015, 0.7)
	if o.get("stars"):
		for i in 14:
			var x := -4 + ((i * 37) % 79) / 10.0
			var y := 18 + ((i * 23) % 70) / 10.0
			var z := 4.22 if i % 2 else -3.72
			var k := 0.32 + absf(sin(time * 2.2 + i * 1.9)) * 0.65
			box(x, y + bob, z, 0.3 + k * 0.3, 0.3 + k * 0.3, 0.15, "#f3eaff" if i % 3 else "#b2b5ff", 0.02, 0.7)
	if o.get("shine") or o.get("chrome"):
		chest(-2.8, 23.4, 0.55, 3.7, "#fff1c1", 4.27)
		if o.get("chrome"):
			chest(2.8, 23.4, 0.4, 3.7, "#ffffff", 4.27)
	if o.get("holo"):
		var y := 17.0
		while y <= 26:
			for z in [4.8, -3.9]:
				box(0, y + bob, z, 8.9, 0.14, 0.15, "#b5f5ff", 0.01, 0.8)
			y += 1.4
	# gold editions have their own garment construction, not just a gold tint
	if gold_clown:   # ivory pleated collar, plum panels, gold diamonds, oversized cuff buttons
		for i in 12:
			var a := i * PI / 6
			var b := (i + 1) * PI / 6
			var p := [[cos(a) * 5.4, 26.2, sin(a) * 4.2], [cos((a + b) / 2) * 5.6, 28, sin((a + b) / 2) * 4.5], [cos(b) * 5.4, 26.2, sin(b) * 4.2]]
			decal(p, "#fff1c9", 0.3)
			var r := p.duplicate()
			r.reverse()
			decal(r, "#fff1c9", 0.3)
		for z in [4.95, -3.95]:
			for q in [[-2.7, 24.3], [2.7, 24.3], [0, 21.6], [-2.7, 18.8], [2.7, 18.8]]:
				_diamond(q[0], q[1], z, 1.1, 1.3, "#f3d677", 0.85)
		for side in [-1.0, 1.0]:
			var L := leg(side)
			var st: float = L.z
			column(L.ankle.x + (L.knee.x - L.ankle.x) * 0.3, 5.3 + L.lift * 0.7, st + (L.knee.z - st) * 0.3, 4.25, 1.6, 4.15, "#fff1c9", 1, 0.3)
			for z in [-2.4, 2.6]:
				for y in [10.3, 12.8]:
					var f: float = (y - 8) / 6
					var x: float = L.knee.x + (L.hip.x - L.knee.x) * f
					var zz: float = z + L.knee.z * (1 - f)
					var p := [[x, y + 1.1, zz], [x + 0.95, y, zz], [x, y - 1.1, zz], [x - 0.95, y, zz]]
					if z > 0:
						p.reverse()
					decal(p, "#67293b", 0.8)
			box(side * 6.85, 23.4 + bob, 2, 1.7, 2.8, 0.45, "#67293b", 0.25)
			ball(side * 6.85, 23.5 + bob, 2.5, 0.65, "#fff1c9")
	if gold_police:   # navy sleeves and trousers frame a gold dress vest, ivory shirt and shield
		chest(0, 24.5, 2.8, 3.8, "#f1e8ce", 4.45)
		var tie := [[-0.5, 26.2, 4.65], [0.5, 26.2, 4.65], [0.75, 23.2, 4.65], [0, 22.5, 4.65], [-0.75, 23.2, 4.65]]
		tie.reverse()
		decal(tie, "#202b40", 0.9)
		for x in [-6.2, 6.2]:
			box(x, 26.5 + bob, 0, 3.6, 0.8, 3.8, "#f0cf5c", 0.35)
			box(x, 27 + bob, 0.2, 1.9, 0.2, 2.6, "#fff1c1", 0.1)
		var shield := [[-4.1, 25.4, 4.7], [-1, 25.4, 4.7], [-1.25, 23.3, 4.7], [-2.55, 22.6, 4.7], [-3.85, 23.3, 4.7]]
		shield.reverse()
		decal(shield, "#202b40", 1)
		chest(-2.55, 24.1, 1.25, 1.5, "#fff1c1", 4.87)
		chest(2.5, 24.7, 1.8, 0.55, "#fff1c1", 4.8)
		for side in [-1.0, 1.0]:
			var L := leg(side)
			beam(L.knee + Vector3(side * 1.9, 0, 0), L.hip + Vector3(side * 1.9, 0, 0), 0.2, "#e6c65c", 0.2, 0.12)
			box(L.x, 3.5 + L.lift, 2.6 + L.z, 3.3, 1.2, 1.7, "#202b40", 0.25)
		box(0, 15.8 + bob, 3.45, 9, 1.4, 0.55, "#202b40", 0.3)
		box(0, 15.8 + bob, 3.8, 1.6, 1.1, 0.25, "#fff1c1", 0.2)
		for x in [-2.8, 2.8]:
			box(x, 14.7 + bob, 3.2, 1.8, 2.2, 1.3, "#202b40", 0.3)
		box(0, 23 + bob, -3.9, 6.2, 3.8, 0.35, "#26334b", 0.3)
		box(0, 23 + bob, -4.15, 3.8, 0.6, 0.2, "#f0cf5c", 0.1)
	if gold_knight:   # articulated gold plate over dark mail, an ivory heraldic centre
		for side in [-1.0, 1.0]:
			var L := leg(side)
			column(side * 6.5, 26 + bob, 0, 5.7, 2.8, 5.2, "#f0cf5c", 0.72, 0.55)
			box(side * 6.5, 25.2 + bob, 2.7, 4, 0.8, 0.35, "#8a6a1c", 0.2)
			beam(L.ankle, L.knee, 2.2, "#d4ae45", 2, 0.45)
			column(L.knee.x, L.knee.y + 0.7, L.knee.z + 1.65, 4.2, 2.6, 2.2, "#f0cf5c", 0.7, 0.4)
			beam(L.ankle + Vector3(0, 0.6, 2.25), L.knee + Vector3(0, -0.8, 2.1), 0.18, "#fff1c1", 0.18, 0.06)
			for z in [-3.25, 3.3]:
				column(side * 2.8, 13.5 + bob, z, 4.35, 3.4, 1, "#e2bd52", 0.85, 0.4)
		chest(0, 23.6, 6.8, 4.4, "#d4ae45", 4.65)
		var sh := [[-1.3, 25.6, 4.87], [1.3, 25.6, 4.87], [1, 23.3, 4.87], [0, 22.4, 4.87], [-1, 23.3, 4.87]]
		sh.reverse()
		decal(sh, "#fff1c9", 0.9)
		var dm := [[0, 25.1, 5.02], [0.65, 24.3, 5.02], [0, 23.5, 5.02], [-0.65, 24.3, 5.02]]
		dm.reverse()
		decal(dm, "#67293b", 1)
		for arm in [[elL, haL], [elR, haR]]:
			beam(arm[0].lerp(arm[1], 0.45), arm[0].lerp(arm[1], 0.83), 1.87, "#d4ae45", 1.7, 0.4)
		column(0, 22.5 + bob, -3.85, 8.2, 6.6, 1.1, "#d4ae45", 0.88, 0.4)
		box(0, 22.6 + bob, -4.5, 0.55, 5.8, 0.25, "#fff1c1", 0.08)
	# Halloween outfits: chest details sit just in front of the vest (z 4.85) and behind the back plate (z -4.2)
	if o.get("ribs"):
		for z in [4.85, -4.2]:
			for x in [-3.1, 0, 3.1]:
				strip([x, 26], [x * 0.85, 16.6], 0.9, z, o.ribs)
	if o.get("web"):
		for z in [4.85, -4.2]:
			var c := [-1.0, 22.5]
			for k in 6:
				var a := k * PI / 3
				strip(c, [c[0] + cos(a) * 5, c[1] + sin(a) * 4.4], 0.34, z, o.web)
			for r in [1.8, 3.6]:
				for k in 6:
					var a0 := k * PI / 3
					var a1 := a0 + PI / 3
					strip([c[0] + cos(a0) * r, c[1] + sin(a0) * r * 0.88], [c[0] + cos(a1) * r, c[1] + sin(a1) * r * 0.88], 0.28, z, o.web)
	if o.get("bones"):
		for z in [4.85, -4.2]:
			strip([0, 26.2], [0, 16.4], 0.8, z, o.bones)
			for q in [[24.6, 4.2], [23, 4.5], [21.4, 4.3], [19.9, 3.6]]:
				for s in [-1, 1]:
					strip([s * 0.4, q[0]], [s * q[1], q[0] - 0.9], 0.6, z, o.bones)
		strip([-2.4, 16.2], [2.4, 16.2], 1, 4.85, o.bones)
		for side in [-1.0, 1.0]:
			var L := leg(side)
			for ab in [[L.ankle, L.knee], [L.knee, L.hip]]:
				beam(ab[0] + Vector3(0, 0.5, 1.9), ab[1] + Vector3(0, -0.5, 1.9), 0.33, o.bones, 0.33, 0.02)
		for x in [-1.45, 1.45]:
			box(x, 30.8 + bob, 3.95, 1.6, 1.4, 0.25, "#15110e", 0.02, 1.6)
		box(0, 29.6 + bob, 3.95, 0.6, 0.8, 0.25, "#15110e", 0.02, 1.6)
		for k in range(-2, 3):
			box(k * 0.7, 28.4 + bob, 3.95, 0.35, 0.9, 0.25, "#15110e", 0.02, 1.6)
	if o.get("wraps"):
		var y := 15.2
		while y <= 26:
			column(0, y + bob, 0.1, 10.9, 0.55, 6.9, o.wraps, 1, 0.18)
			y += 1.9
		for side in [-1.0, 1.0]:
			var L := leg(side)
			for ab in [[L.ankle, L.knee], [L.knee, L.hip]]:
				for f in [0.3, 0.7]:
					var p: Vector3 = ab[0].lerp(ab[1], f)
					column(p.x, p.y, p.z + 0.6, 4.6, 0.5, 4.4, o.wraps, 1, 0.14)
		for yy in [29, 30.3, 32.6]:
			column(0, yy + bob, 0.2, 7.8, 0.55, 6.9, o.wraps, 1, 0.16)
		for x in [-1.45, 1.45]:
			box(x, 31.4 + bob, 3.95, 0.9, 0.45, 0.2, "#ffc94a", 0.02, 1.6)
	if o.get("reaper"):
		column(0, 7.6, 0, 13.6, 13.6, 8.6, B, 0.62, 0.5)
		column(0, 1.3, 0, 14, 0.8, 9, tint(B, 0.7), 1, 0.3)
	if o.get("phantom"):
		for q in [[0, -3], [1, 0], [2, 3]]:
			var sw := sin(q[0] * 2.1) * 1.6
			var x: float = q[1]
			beam(Vector3(x, 14.4 + bob, 0), Vector3(x + sw, 8, 1), 1.6, o.phantom, 0.9, 0.2)
			beam(Vector3(x + sw, 8, 1), Vector3(x - sw * 0.6, 2.5, -0.5), 0.9, o.phantom, 0.15, 0.15)
		for x in [-1.45, 1.45]:
			box(x, 30.8 + bob, 3.9, 1, 1, 0.2, "#0e3a26", 0.02, 1.6)
	# v0.9.3 outfits
	if o.get("apron"):
		box(0, 15.2 + bob, 4.95, 7.8, 14, 0.3, o.apron, 0.3, 0.4)
		box(0, 12.8 + bob, 5.18, 3.6, 2, 0.14, tint(o.apron, 1.25), 0.12, 0.5)
		for s in [-1, 1]:
			beam(Vector3(s * 2.8, 22 + bob, 4.9), Vector3(s * 2.2, 26.8 + bob, 3.4), 0.3, o.apron, 0.3, 0.15)
			beam(Vector3(s * 3.9, 15.5 + bob, 4.8), Vector3(s * 4.9, 15.5 + bob, 1), 0.25, o.apron, 0.25, 0.15)
	if o.get("coat"):
		column(0, 9.2, 0, 11.8, 10, 7.6, o.coat, 0.8, 0.5)
		for s in [-1, 1]:
			box(s * 3.6, 22 + bob, 3.95, 1.1, 8, 0.3, tint(o.coat, 1.15), 0.2, 0.4)
	if o.get("cape"):
		box(0, 15.6 + bob, -4.35, 11.6, 22, 0.4, o.cape, 0.35)
		box(0, 26.2 + bob, -2.2, 12.4, 1, 5, o.cape, 0.35)
		if o.get("collar"):
			box(0, 30.8 + bob, -3.5, 9.4, 5.4, 0.45, o.cape, 0.35)
			box(0, 30.6 + bob, -3.2, 8.6, 4.8, 0.2, o.lining if o.get("lining") else tint(o.cape, 1.4), 0.1)
	if o.get("reflect"):
		for y in [18.2, 21.8]:
			column(0, y + bob, 0.1, 10.9, 0.7, 6.9, o.reflect, 1, 0.15)
	if o.get("waders"):
		column(0, 17.2 + bob, 0, 9.7, 4.8, 5.9, o.waders, 1.02, 0.45)
		for s in [-1, 1]:
			for z in [3.1, -2.9]:
				beam(Vector3(s * 2.6, 19.4 + bob, z), Vector3(s * 3.4, 26 + bob, z * 0.93), 0.35, o.waders, 0.35, 0.15)
	if o.get("charges"):
		for x in [-2.9, 0, 2.9]:
			box(x, 14.9 + bob, 3.55, 2.2, 2, 1.1, o.charges, 0.3, 0.6)
		beam(Vector3(-2.9, 15.9 + bob, 4.15), Vector3(2.9, 15.9 + bob, 4.15), 0.12, "#1a1a1a", 0.12, 0.05)
		box(0, 15.2 + bob, 4.15, 0.9, 0.5, 0.1, "#7affb0", 0.02, 1)
	if o.get("medals"):
		var mc := ["#b83a3a", "#3a6ab8", "#e2c25a"]
		for i in 3:
			chest(-3.6 + i * 0.95, 25.1, 0.8, 1.1, mc[i], 4.95)
		for x in [-3.6, -1.7]:
			ball(x, 23.6 + bob, 4.95, 0.45, "#f0cf5c")
	if o.get("medal"):
		for s in [-1, 1]:
			beam(Vector3(s * 1.8, 26.5 + bob, 3.2), Vector3(0, 24.6 + bob, 4.6), 0.12, o.medal, 0.12, 0.05)
		ball(0, 24 + bob, 4.7, 0.8, o.medal)
		box(0, 24 + bob, 5.4, 0.5, 0.5, 0.2, "#c01a2a", 0.02, 1.2)
	if o.get("ghillie"):
		for i in 12:
			var x := -5.5 + i
			beam(Vector3(x, 26 + bob, -3.2 - (i % 2) * 0.3), Vector3(x + sin(i * 1.7) * 1.2, 15.5 + (i % 3), -4.6), 0.35, o.ghillie if i % 2 else tint(o.ghillie, 0.7), 0.2, 0.15)
		for s in [-1, 1]:
			for k in 3:
				beam(Vector3(s * (5.2 + k * 0.5), 26.3 + bob, 1 - k), Vector3(s * (6.6 + k * 0.4), 21 + bob, 1.5 - k), 0.3, o.ghillie if k % 2 else tint(o.ghillie, 0.75), 0.2, 0.15)
	if o.get("sheet"):
		column(0, 14.2 + bob * 0.5, 0, 12.6, 24.6, 9.2, o.sheet, 0.85, 0.45)
	if o.get("patches"):
		chest(-2.3, 23.8, 2.3, 2.3, "#6a4a8a", 4.98)
		chest(2.5, 19.4, 2, 2.1, "#8a3a2a", 4.98)
		chest(-2.3, 23.8, 2.6, 0.18, "#2a2014", 5.05)
		chest(2.5, 19.4, 0.18, 2.4, "#2a2014", 5.05)
		box(0, 21 + bob, -3.95, 2.4, 2.4, 0.15, "#5a6a3a", 0.035, 0.65)
	if o.get("straws"):
		for i in 6:
			var a := i * PI / 3
			beam(Vector3(cos(a) * 2.4, 27.4 + bob, sin(a) * 2), Vector3(cos(a) * 3.6, 26.4 + bob, sin(a) * 3), 0.2, o.straws, 0.05, 0.05)
		for arm in [[elL, haL], [elR, haR]]:
			var w: Vector3 = arm[1].lerp(arm[0], 0.16)
			for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0)]:
				beam(w, w + d * 1.4, 0.18, o.straws, 0.05, 0.05)
		for s in [-1.0, 1.0]:
			var L := leg(s)
			for d in [-1, 1]:
				beam(Vector3(L.x, 3.6 + L.lift, L.z), Vector3(L.x + d * 1.3, 2.8 + L.lift, L.z + d * 0.6), 0.2, o.straws, 0.05, 0.05)
	if o.get("glitter"):
		for i in 4:
			var ph := fmod(time * 1.1 + i * 0.29 + i * 0.13, 1.0)
			if ph > 0.3:
				continue
			var r := sin(ph / 0.3 * PI) * 1.2
			var x := -3.0 + i * 2
			var y := 22.0 + (i % 2) * 3
			chest(x, y, r * 2, 0.17, "#fffbe0", 4.9)
			chest(x, y, 0.17, r * 2, "#fffbe0", 4.9)


# ---------------------------------------------------------------- looks (buildLook / playerLook)

const SKIN_FX := ["neon", "dots", "ruff", "badge", "plate", "stars", "holo", "spots", "frost", "glitter", "chrome", "ribs", "web", "bones", "wraps", "reaper", "phantom",
	"apron", "facewrap", "coat", "cape", "lining", "collar", "reflect", "waders", "charges", "medals", "ghillie", "sheet", "stitches", "clownface", "hockey", "sack", "patches", "straws", "medal", "aura", "sahur", "demon", "jersey", "jtrim"]
const HYBRID_HATS := ["shades", "yamaka", "ballhelm", "gridhelm", "dunce", "prop", "conductor", "skullhelm"]
const SLOTCOL := ["#8fb58a", "#a9bccb", "#d0b077", "#c29ac4", "#86c0b8", "#d08f78"]
const OMIT := ["aim", "walk", "tag", "tag_col", "hp", "big", "detail", "syncRender", "aura"]
## simple hats: the look field each sets and its colour
const HAT_FIELDS := {"beanie": {"beanie": "#6b2f2a"}, "beret": {"beret": "#7a1f24"}, "wrap": {"wrap": "#a8342a"}, "tophat": {"tophat": "#1c1a1a"},
	"crown": {"crown": "#e2c25a"}, "headband": {"headband": "#ff3a6a"}, "acap": {"cap": "#e2427f", "capPix": "#ffe03a"}, "nhelm": {"helmet": "#1b1e26", "hneon": "#2af5ff"},
	"pcap": {"pcap": "#1a2240"}, "ledmask": {"mask": "#ff3a3a"}, "visor": {"visor": "#ff2a8a"}, "clownhair": {"hair": "#ff3ad0"}, "halo": {"halo": "#fff0a0"},
	"glitch": {"glitchm": true}, "gclownhair": {"hair": "#f0cf5c", "hairGold": true}, "ghelm": {"khelm": "#e6c65c"}, "jackolantern": {"pumpkin": "#e8771e"},
	"pumpkinking": {"pumpkin": "#c9561a", "pking": true}, "witch": {"witch": "#241a30"}, "officer": {"pcap": "#34402c", "pbraid": "#e2c25a"}, "ghood": {"ghood": "#55642e"},
	"bombhelm": {"bomb": "#3e4a38"}, "qmset": {"cap": "#3d4a52", "headset": true}, "devilhorns": {"horns": "#7a1410"}, "blackout": {"helmet": "#1d2024", "hneon": "#ffc860"}}
const CLASS_NAMES := {"soldier": "SOLDIER", "sniper": "SNIPER", "grenadier": "GRENADIER", "quartermaster": "QUARTERMASTER"}


static func headwear_allowed(skin_id: String, hat: String) -> bool:
	var allowed: Dictionary = PalLocker.catalog().get("hatsAllowed", {})
	return hat == "class" or hat in allowed.get(skin_id, [])


static func _winter_hat_keys() -> Dictionary:
	var out := {}
	for p in PalLocker.catalog().get("WINTER_PAIRS", []):
		out[p[2]] = true
	return out


## the wardrobe look for an outfit (skin and headgear ids) on a class; slot >= 0 colours the player's mark
static func look_for(cos: Dictionary, cls: String, slot: int = -1) -> Dictionary:
	var SK: Dictionary = PalLocker.catalog().get("SKINS", {})
	var skin_id: String = cos.get("skin", "std")
	var S: Dictionary = SK.get(skin_id, SK.get("std", {}))
	var o := {"body": S.body, "vest": S.vest, "pants": S.pants, "head": S.get("head", "#c19a78"), "mark": "#e2b436", "gl": 14}
	for k in ["stripe", "glow", "shine"]:
		if S.has(k):
			o[k] = S[k]
	for k in SKIN_FX:
		if S.has(k):
			o[k] = S[k]
	if S.has("winter"):
		o.winter = S.winter
		o.winterTrim = S.get("winterTrim")
	if S.has("winterModel"):
		o.winterModel = S.winterModel
		o.aura = S.get("aura")
	var C: String = CLASS_NAMES.get(cls, "SOLDIER")
	if C == "SNIPER":
		o.gl = 19
	elif C == "GRENADIER":
		o.pack = "#4a3a26"
		o.bandolier = true
		o.gl = 15
		o.weapon = "sg"
	elif C == "QUARTERMASTER":
		o.pack = "#5a4a30"
		o.cross = true
		o.gl = 11
	var hat: String = cos.get("hat", "class")
	var H := hat if headwear_allowed(skin_id, hat) else "class"
	var boonie: String = S.get("boonie", "#5b5a3c")
	if H == "class":
		if C == "SNIPER":
			o.boonie = boonie
		elif C == "QUARTERMASTER":
			o.cap = S.hat
		else:
			o.helmet = S.hat
	elif H == "cap":
		o.cap = S.hat
	elif H == "boonie":
		o.boonie = boonie
	elif HAT_FIELDS.has(H):
		o.merge(HAT_FIELDS[H], true)
	elif _winter_hat_keys().has(H):
		o.winterHat = H
	elif PalLocker.catalog().get("HALLOWEEN_HATS", {}).has(H):
		o.halloweenHat = H
	elif H in HYBRID_HATS:
		o.hybridHat = H
	else:
		o.helmet = S.hat
	var strip_hats := func() -> void:
		o.erase("helmet")
		o.erase("cap")
		o.erase("boonie")
	if S.get("headwear") is Dictionary and H == "class":
		strip_hats.call()
		o.merge(S.headwear, true)
	if S.get("jersey") and H == "class":
		strip_hats.call()
		o.headband = S.jtrim
	if S.get("reaper") and H == "class":
		strip_hats.call()
		o.hood = S.body
	elif (S.get("bones") or S.get("wraps") or S.get("phantom")) and H == "class":
		strip_hats.call()
	if slot >= 0:
		o.mark = SLOTCOL[slot % 6]
	if S.has("winterModel"):
		strip_hats.call()
	return o


## the model's heading for a screen-space aim, undoing the flattened depth
static func aim_angle(sd: Vector2) -> float:
	return atan2(sd.x, sd.y / 0.32)


## where the gun's muzzle and butt sit (model units, from the feet) for a look, heading and gait
static func barrel(look: Dictionary, angle: float, walk: float = 0.0) -> Dictionary:
	var w := Wardrobe.new()
	w.measure_only = true
	var pose := look.duplicate()
	if pose.has("bolt") and pose.bolt != null:
		pose.bolt = round(pose.bolt * 24) / 24.0
	w.build(pose, round(rad_to_deg(angle)) * PI / 180, 0, 1, round(walk * 24 / TAU) * TAU / 24)
	return {"tip": Vector2(w.tip.x, w.tip.y), "root": Vector2(w.root.x, w.root.y)}


# ---------------------------------------------------------------- painting

## the figure at (cx, cy) on the canvas, scale pixels per model unit. Each pose is baked once into a vertex-coloured mesh
## (sorted faces, seams, ink edges, glows, the ground light and shadow) and kept in a cache, so a frame is one draw call.
static func draw(cv: CanvasItem, look: Dictionary, angle: float, t: float, scale: float, cx: float, cy: float, walking = false, alpha: float = 1.0) -> void:
	var step := 8 if scale > 3 else 5
	var heading := roundi(rad_to_deg(angle) / step) * step
	var ph: float = float(walking) if (walking is float or walking is int) and not (walking is bool) else (t * 7 if walking == true else 0.0)
	var gait := roundi(fposmod(ph, TAU) * 24 / TAU)
	var animated: bool = look.get("stars") or look.get("holo") or look.get("glitter") or look.get("halo") or look.get("glitchm") or look.get("winterHat") == "aurorahalo" or look.get("hybridHat") == "prop"
	var tick: float = floorf(t * 20) / 20 if animated else (float(floori(t * 6) % 4) if look.get("pking") else 0.0)
	var pose := look.duplicate()
	if pose.has("bolt") and pose.bolt != null:
		pose.bolt = round(pose.bolt * 24) / 24.0
	var ks: Array = pose.keys().filter(func(k): return not (k in OMIT))
	ks.sort()
	var key := ";".join(ks.map(func(k): return "%s:%s" % [k, pose[k]])) + "|%d|%d|%s|%d" % [heading, gait, tick, 1 if scale <= 6 else 0]
	var mesh_: ArrayMesh = cache.get(key)
	if mesh_ == null:
		var w := Wardrobe.new()
		w.build(pose, heading * PI / 180, tick, scale, gait * TAU / 24)
		mesh_ = w.bake()
		cache[key] = mesh_
		cache_order.append(key)
		if cache_order.size() > 900:
			for k in cache_order.slice(0, 150):
				cache.erase(k)
			cache_order = cache_order.slice(150)
	var a := alpha
	if look.get("faded"):
		a *= 0.5
	if look.get("holo"):
		a *= 0.74 + 0.15 * sin(t * 9)
	cv.draw_mesh(mesh_, null, Transform2D(0, Vector2(scale, scale), 0, Vector2(cx, cy)), Color(1, 1, 1, a))


var _vx := PackedVector2Array()
var _vc := PackedColorArray()


func _tri_fan(pts: PackedVector2Array, col: Color) -> void:
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		for i in range(1, pts.size() - 1):
			idx.append_array([0, i, i + 1])
	for i in idx:
		_vx.append(pts[i])
		_vc.append(col)


func _seg(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var d := b - a
	var l := d.length()
	if l < 1e-5:
		return
	d /= l
	var n := Vector2(-d.y, d.x) * w / 2
	var e := d * w / 2   # square caps stand in for the browser's round joins
	var p := [a - e + n, b + e + n, b + e - n, a - e - n]
	for i in [0, 1, 2, 0, 2, 3]:
		_vx.append(p[i])
		_vc.append(col)


func _ellipse(c: Vector2, rx: float, ry: float, n: int = 32) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


func _ring_line(c: Vector2, rx: float, ry: float, w: float, col: Color) -> void:
	var e := _ellipse(c, rx, ry, 40)
	for i in e.size():
		_seg(e[i], e[(i + 1) % e.size()], w, col)


static func _col(h: String, a: float = 1.0) -> Color:
	var k := Color.html(h)
	k.a *= a
	return k


## the built faces as one mesh, in model units with the feet at the origin
func bake() -> ArrayMesh:
	_vx = PackedVector2Array()
	_vc = PackedColorArray()
	var body_a := 0.62 if o.get("phantom") else 1.0
	var ground = o.get("ring") if o.get("ring") else o.get("glow")
	if ground:
		var rgb := Color.html(ground)
		var stops := [[0.0, 0.04], [3.0, 0.04], [11.64, 0.23], [21.0, 0.0]]
		var N := 28
		for s in 3:
			var r0: float = stops[s][0]
			var r1: float = stops[s + 1][0]
			var c0 := Color(rgb, stops[s][1] * body_a)
			var c1 := Color(rgb, stops[s + 1][1] * body_a)
			for i in N:
				var a0 := TAU * i / N
				var a1 := TAU * (i + 1) / N
				var p := [Vector2(cos(a0) * r0, 1 + sin(a0) * r0 * 0.4), Vector2(cos(a0) * r1, 1 + sin(a0) * r1 * 0.4), Vector2(cos(a1) * r1, 1 + sin(a1) * r1 * 0.4), Vector2(cos(a1) * r0, 1 + sin(a1) * r0 * 0.4)]
				var cc := [c0, c1, c1, c0]
				for j in [0, 1, 2, 0, 2, 3]:
					_vx.append(p[j])
					_vc.append(cc[j])
		for rg in [[o.get("glow"), 12.0, 4.7], [o.get("ring"), 11.0, 4.5]]:
			if not rg[0]:
				continue
			var col := Color.html(rg[0])
			_ring_line(Vector2(0, 1), rg[1], rg[2], 4.5, Color(col, 0.16 * body_a))   # stands in for the canvas shadow blur
			_ring_line(Vector2(0, 1), rg[1], rg[2], 2.5, Color(col, 0.55 * body_a))
			_ring_line(Vector2(0, 1), rg[1], rg[2], 1.1, Color(col, 0.95 * body_a))
			_ring_line(Vector2(0, 1), rg[1], rg[2], 0.28, Color(_col("#f4fff4"), 0.85 * body_a))
	_tri_fan(_ellipse(Vector2(0, 1.1), 10.5, 4, 28), Color(0, 0, 0, 0.23 * body_a))
	var order: Array = range(faces.size())
	order.sort_custom(func(i, j): return faces[i].depth < faces[j].depth or (faces[i].depth == faces[j].depth and i < j))
	var ink := _col("#070a08")
	for i in order:
		var f: Dictionary = faces[i]
		var fa := 1.0 if f.solid else body_a
		var pts := PackedVector2Array()
		for p in f.pts:
			pts.append(Vector2(p.x, p.y))
		var col := _col(f.col, fa)
		if f.emission != "":
			var ec := _col(f.emission)
			# a canvas shadow blur spreads a small face's light thin: the halo shrinks and fades with the face
			var bb := Rect2(pts[0], Vector2.ZERO)
			for p in pts:
				bb = bb.expand(p)
			var sz := maxf(bb.size.x, bb.size.y)
			var k := clampf(sz / 2.5, 0.15, 1.0)
			for g in [[1.5, 0.09], [0.75, 0.2]]:
				for poly2 in Geometry2D.offset_polygon(pts, minf(g[0], sz * 0.6)):
					_tri_fan(poly2, Color(ec, g[1] * fa * k))
		_tri_fan(pts, col)
		for k in pts.size():
			_seg(pts[k], pts[(k + 1) % pts.size()], 0.13, col)
		var ic := Color(ink, fa)
		for e in f.edges:
			_seg(Vector2(e[0].x, e[0].y), Vector2(e[1].x, e[1].y), f.outline, ic)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _vx
	arr[Mesh.ARRAY_COLOR] = _vc
	var m := ArrayMesh.new()
	if _vx.size() > 0:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## figFrame: where a look sits at a heading (model units from the feet): the whole body for "skin", the head and what
## sits on it for "hat". {cx, cy, s}: the middle and the larger side, for framing a thumbnail.
static func frame(look: Dictionary, angle: float, part: String = "skin") -> Dictionary:
	var w := Wardrobe.new()
	w.build(look, angle, 0, 3, false)
	var r := Rect2()
	var first := true
	for f in w.faces:
		for p in f.pts:
			if part == "hat" and p.y > -25:
				continue
			if first:
				r = Rect2(p.x, p.y, 0, 0)
				first = false
			else:
				r = r.expand(Vector2(p.x, p.y))
	if first:
		return {"cx": 0.0, "cy": -20.0, "s": 44.0}
	if part == "hat":
		r = r.expand(Vector2(r.position.x, -25))
	else:
		r = r.expand(Vector2(r.position.x, 12 if look.get("ring") or look.get("glow") else 6))
	return {"cx": r.get_center().x, "cy": r.get_center().y, "s": maxf(r.size.x, r.size.y)}
