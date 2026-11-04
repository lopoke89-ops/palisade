class_name UsModels
extends RefCounted
## v0.12 THE UNDERSTRIP CASE (16i-understrip-models.js): the ten skins' own models and the five hats, drawn on the wardrobe
## painter's frame through the same four hooks as the browser (usModelLeg, usModelBody, usModelArm, usModelHead) and its
## hat painter (usHatPaint). K is the Wardrobe being built; its box, column, beam, dome, brim, ball and mesh are the
## browser's K primitives, with the same arguments. LEGAL (work order 3): the King of the Strip is a lounge singer in a
## jumpsuit, never anyone's name or face; the Generalissimo's medals, sash and badge are invented.

const HATS := ["tinfoil", "eyeshade", "antennae", "plumecrest", "neonhalo"]


static func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


## a flat shape: pts [[x, y]] at depth z, raised by the bob
static func flat(K: Wardrobe, pts: Array, z: float, col: String, bias: float = 1.2) -> void:
	var v: Array = []
	var ids: Array = []
	for i in pts.size():
		v.append(Vector3(pts[i][0], pts[i][1] + K.bob, z))
		ids.append(i)
	K.mesh(v, [ids], col, 0.08, bias)


static func star(K: Wardrobe, cx: float, cy: float, z: float, r: float, col: String) -> void:
	var p: Array = []
	for i in 10:
		var a := PI / 2 + i * PI / 5
		var rr := r * 0.45 if i % 2 else r
		p.append([cx + cos(a) * rr, cy + sin(a) * rr])
	flat(K, p, z, col, 1.3)


## an egg: rings round a vertical axis, narrower toward the chin (taper < 1)
static func egg(K: Wardrobe, cx: float, cy: float, cz: float, rx: float, ry: float, rz: float, col: String, taper: float = 1.0) -> void:
	var SEG := 10 if K.compact else 18
	var RINGS := 5 if K.compact else 9
	var v: Array = []
	var ff: Array = []
	for r in RINGS + 1:
		var a := -PI / 2 + PI * r / RINGS
		var y := sin(a) * ry
		var k := cos(a) * (0.2 if r == 0 or r == RINGS else 1.0) * (1 - (1 - taper) * (-sin(a)) if a < 0 else 1.0)
		for q in SEG:
			var t := TAU * q / SEG
			v.append(Vector3(cx + cos(t) * rx * k, cy + y + K.bob, cz + sin(t) * rz * k))
	for r in RINGS:
		for q in SEG:
			var a0 := r * SEG + q
			var a1 := r * SEG + (q + 1) % SEG
			ff.append([a0, a1, a1 + SEG, a0 + SEG])
	var top: Array = []
	var bottom: Array = []
	for q in SEG:
		top.append(RINGS * SEG + SEG - 1 - q)
		bottom.append(q)
	ff.append(top)
	ff.append(bottom)
	var rev: Array = []
	for f in ff:
		var g: Array = f.duplicate()
		g.reverse()
		rev.append(g)
	K.mesh(v, rev, col, 0.55)


static func oval(K: Wardrobe, cx: float, cy: float, rx: float, ry: float, z: float, col: String, bias: float = 1.3) -> void:
	var p: Array = []
	for i in 12:
		var a := i * PI / 6
		p.append([cx + cos(a) * rx, cy + sin(a) * ry])
	flat(K, p, z, col, bias)


## a leg: true when the model drew it
static func leg(K: Wardrobe, L: Dictionary, side: float) -> bool:
	var m: String = K.o.get("usModel", "")
	var x: float = L.x
	var z: float = L.z
	var lift: float = L.lift
	var ankle: Vector3 = L.ankle
	var knee: Vector3 = L.knee
	var hip: Vector3 = L.hip
	var T := K.T
	match m:
		"visitor":
			K.column(x, 1.2 + lift, z + 1.2, 2.4, 1.6, 3.4, K.B, 0.9, 0.3)
			K.beam(ankle, knee, 0.85, K.B, 0.95, 0.3)
			K.beam(knee, hip, 0.95, K.B, 1.15, 0.3)
			return true
		"custodian":
			K.column(x, 2 + lift, 1.2 + z, 5, 3.4, 6.6, "#3a3f2c", 0.9, 0.4)
			K.box(x, 0.7 + lift, 1.3 + z, 5.2, 0.9, 6.8, "#2a2c22", 0.3)
			K.beam(ankle, knee, 2.2, T, 2.4, 0.4)
			K.beam(knee, hip, 2.4, T, 2.7, 0.4)
			K.box(x, 8.8 + lift * 0.5, z + 2.2, 2.6, 2.2, 0.8, "#d0782a", 0.2)
			return true
		"stripking":   # bell-bottoms flare to the boot
			K.column(x, 1.8 + lift, 1.1 + z, 4.1, 2.6, 5.8, "#f4f0e6", 0.87)
			K.beam(ankle, knee, 2.45, T, 2, 0.4)
			K.beam(knee, hip, 2.05, T, 2.35, 0.4)
			K.column(ankle.x, ankle.y + 1.4, ankle.z, 5.2, 2.2, 5.2, T, 1.25, 0.3)
			for k in 3:
				K.box(ankle.x + side * 2.55, ankle.y + 2 + k * 2.2, ankle.z, 0.3, 0.5, 0.5, "#e2c25a", 0.05)
			return true
		"highroller":   # white spats, black toe caps
			K.column(x, 2 + lift, 1.05 + z, 4.3, 3.1, 6.1, "#f0ece0", 0.87)
			K.box(x, 2.4 + lift, 3.3 + z, 4.4, 2.2, 1.6, "#141414", 0.25)
			K.box(x, 0.7 + lift, 1.2 + z, 4.35, 0.85, 6.25, "#202020", 0.3)
			K.beam(ankle, knee, 1.7, T, 2)
			K.beam(knee, hip, 2.05, T, 2.35)
			return true
		"generalissimo":   # a red stripe down the outside
			K.column(x, 4 + lift, 1.05 + z, 4.4, 7, 5.8, "#151515", 0.9, 0.45)
			K.box(x, 0.7 + lift, 1.3 + z, 4.5, 0.9, 6.3, "#0c0c0c", 0.3)
			K.beam(ankle, knee, 1.8, T, 2.05)
			K.beam(knee, hip, 2.1, T, 2.4)
			var mid := knee + (hip - knee) * 0.5
			K.box(mid.x + side * 2.2, mid.y, mid.z, 0.35, 6.5, 0.9, "#c42a3a", 0.05)
			return true
		"gunslinger", "sheriff":   # boots and a spur
			K.column(x, 2.6 + lift, 1.05 + z, 4.2, 4.4, 6.1, "#4a3020" if m == "sheriff" else "#5a3a22", 0.9, 0.45)
			K.box(x, 0.7 + lift, 1.2 + z, 4.3, 0.9, 6.6, "#2a1a10", 0.3)
			K.box(x, 3.4 + lift, -2.2 + z, 1.3, 1.3, 0.8, "#c8b070", 0.1)
			K.beam(ankle, knee, 1.7, T, 2)
			K.beam(knee, hip, 2.05, T, 2.35)
			return true
	return false


## the body (hips to neck): true when the model drew it
static func body(K: Wardrobe) -> bool:
	var m: String = K.o.get("usModel", "")
	var b := K.bob
	var B := K.B
	var V := K.V
	var T := K.T
	var skin := K.skin
	var neck := func() -> void: K.column(0, 27 + b, 0, 4.5, 2.8, 3.6, skin, 1, 0.32)
	match m:
		"highroller":
			K.column(0, 15 + b, 0, 9.1, 3.8, 5.2, T, 1.06)
			K.column(0, 21.2 + b, 0, 10.2, 10.8, 5.6, B, 1.15)
			for i in 5:   # the checkerboard, front and back
				for j in 6:
					if (i + j) % 2:
						var x := -3.6 + i * 1.8
						var y := 16.9 + j * 1.75
						K.box(x, y + b, 2.98, 1.75, 1.7, 0.16, "#ecebe4", 0.04, 1)
						K.box(x, y + b, -2.98, 1.75, 1.7, 0.16, "#ecebe4", 0.04, 1)
			flat(K, [[-2.2, 26.3], [2.2, 26.3], [0, 21.6]], 3.06, "#f4f2ea")   # shirt, the checked tie
			K.box(0, 23.4 + b, 3.18, 1.05, 4.4, 0.22, "#141416", 0.05, 1.4)
			for y in [22.4, 24.4]:
				K.box(0, y + b, 3.3, 1.05, 1, 0.1, "#ecebe4", 0.02, 1.5)
			K.box(-3.4, 24.6 + b, 3.1, 1.5, 1, 0.25, "#d42a2a", 0.05, 1.3)
			neck.call()
			K.box(0, 26.6 + b, 1.8, 5, 1, 2.4, "#f4f2ea", 0.2)
			return true
		"pitboss":
			K.column(0, 15 + b, 0, 9.1, 3.8, 5.2, T, 1.06)
			K.column(0, 21.2 + b, 0, 10.2, 10.8, 5.6, B, 1.15)
			flat(K, [[-2, 26.3], [2, 26.3], [0, 21.8]], 3.06, "#e8e2d0")   # white shirt, red tie
			K.box(0, 23.6 + b, 3.18, 1, 4, 0.22, "#a8202a", 0.05, 1.4)
			for q in [[3.2, 24.6, "#c42a3a"], [3.6, 24.9, "#2a5ac4"], [2.8, 24.9, "#2fa04a"]]:   # chips in the breast pocket
				K.column(q[0], q[1] + b, 3.2, 1.1, 0.4, 0.4, q[2], 1, 0.08)
			for q in [[-4.4, 16.4], [-3.4, 15.9], [4.6, 16.6]]:   # torn hem
				flat(K, [[q[0] - 0.7, q[1] + 0.9], [q[0] + 0.7, q[1] + 0.9], [q[0], q[1] - 0.6]], 2.95, "#48485a")
			neck.call()
			return true
		"shelterdweller":
			K.column(0, 15 + b, 0, 9.1, 3.8, 5.2, B, 1.06)
			K.column(0, 21.2 + b, 0, 10.2, 10.8, 5.6, B, 1.15)
			K.box(0, 21.5 + b, 2.95, 0.6, 9.4, 0.2, "#d0782a", 0.04, 1)   # zip, collar, the 7 patch
			K.box(0, 26.3 + b, 2.6, 6.4, 1.2, 1.8, "#d0782a", 0.2)
			K.box(-2.9, 24 + b, 3.02, 2.4, 2.4, 0.18, "#d0782a", 0.05, 1.2)
			K.box(-2.9, 24 + b, 3.12, 1.4, 1.5, 0.1, "#2e3020", 0.02, 1.4)
			K.column(0, 16.3 + b, 0, 9.7, 1.5, 6, "#3a3a2a", 1, 0.25)   # the ration-pack belt
			for q in [[-3.2, 3], [0, 3.1], [3.2, 3], [-4.8, 0], [4.8, 0], [0, -3]]:
				var side_pack: bool = q[0] != 0 and q[1] == 0
				K.box(q[0], 16.4 + b, q[1], 1.4 if side_pack else 2.0, 2, 2.2 if side_pack else 1.2, "#7a6a44", 0.25)
			neck.call()
			return true
		"cardsharp":
			K.column(0, 15 + b, 0, 9.1, 3.8, 5.2, T, 1.06)
			K.column(0, 21.2 + b, 0, 10.2, 10.8, 5.6, B, 1.15)
			K.column(0, 21.4 + b, 0.15, 10.3, 9, 6.1, V, 1.02, 0.45)
			for i in 4:   # the brocade
				for j in 4:
					K.box(-3.2 + i * 2.1 + (j % 2) * 1, 17.5 + j * 2.2 + b, 3.1, 0.55, 0.55, 0.12, "#e2c25a", 0.02, 1.2)
			flat(K, [[-1.6, 26.3], [1.6, 26.3], [0, 23.2]], 3.12, "#efe9dc")   # string tie
			K.beam(Vector3(-0.2, 26 + b, 3.3), Vector3(-0.6, 23.6 + b, 3.4), 0.12, "#141414", 0.12, 0.03)
			K.beam(Vector3(0.2, 26 + b, 3.3), Vector3(0.6, 23.6 + b, 3.4), 0.12, "#141414", 0.12, 0.03)
			K.box(-2.8, 18.6 + b, 3.2, 1.4, 0.3, 0.15, "#e2c25a", 0.02, 1.2)
			neck.call()
			return true
		"sheriff":
			K.column(0, 15 + b, 0, 9.1, 3.8, 5.2, T, 1.06)
			K.column(0, 21.2 + b, 0, 10.2, 10.8, 5.6, B, 1.15)
			K.column(0, 21.4 + b, 0.1, 10.3, 9.4, 6.2, V, 1.02, 0.45)
			flat(K, [[-1.8, 26.3], [1.8, 26.3], [0, 22.4]], 3.12, B)
			star(K, -2.7, 23.2, 3.22, 1.5, "#e2c25a")
			K.column(0, 16.3 + b, 0, 9.7, 1.4, 6, "#4a3020", 1, 0.25)   # gun belt, buckle, holster
			K.box(0, 16.3 + b, 3.05, 1.8, 1.3, 0.3, "#c8b070", 0.12)
			K.box(4.4, 15 + b, 0.8, 1.6, 4.6, 2.6, "#3a2414", 0.3)
			neck.call()
			K.box(0, 26.6 + b, 2.2, 3.4, 0.8, 0.3, "#a8202a", 0.08)
			return true
		"gunslinger":
			K.column(0, 15 + b, 0, 9.1, 3.8, 5.2, T, 1.06)
			K.column(0, 21.2 + b, 0, 10.6, 10.8, 6, B, 1.15)
			K.column(0, 11.4 + b, -0.2, 11.2, 9.6, 6.6, B, 1.12, 0.5)   # the long coat's skirt, open at the front
			K.box(0, 11.4 + b, 3.2, 2.2, 9.6, 0.3, T, 0.05, 1)
			K.column(0, 25.4 + b, 0, 11.6, 2.6, 6.8, Wardrobe.tint(B, 0.85), 1, 0.35)   # the shoulder cape
			K.beam(Vector3(-4.4, 26 + b, 3.25), Vector3(4.6, 15.6 + b, 3.35), 0.6, "#4a3020", 0.6, 0.2)   # the bandolier
			for k in 6:
				var f := k / 5.0
				K.box(-4 + f * 8.2, 25.2 - f * 9 + b, 3.75, 0.45, 0.9, 0.45, "#d8b45a", 0.05, 1.3)
			neck.call()
			K.box(0, 26.8 + b, 2, 4.4, 1.3, 2, "#a8202a", 0.2)
			return true
		"generalissimo":
			K.column(0, 15 + b, 0, 9.1, 3.8, 5.2, T, 1.06)
			K.column(0, 21.2 + b, 0, 10.4, 10.8, 5.8, B, 1.15)
			K.box(0, 21.5 + b, 3, 0.5, 9.5, 0.15, "#3a3820", 0.03, 1)   # buttons
			for k in 4:
				K.box(0.6, 18 + k * 2.2 + b, 3.1, 0.45, 0.45, 0.15, "#e2c25a", 0.02, 1.2)
			K.beam(Vector3(-4.6, 26.2 + b, 3.05), Vector3(4.7, 16.5 + b, 3.25), 0.65, "#c42a3a", 0.6, 0.15)   # the sash
			K.beam(Vector3(-4.6, 26.2 + b, -3.05), Vector3(4.7, 16.5 + b, -3.25), 0.65, "#c42a3a", 0.6, 0.15)
			var med := ["#e2c25a", "#c8ccd0", "#c42a3a", "#2a5ac4", "#2fa04a", "#e2c25a"]
			for i in 3:   # the invented medals
				for j in 2:
					var x := -1.6 - i * 1.15
					var y := 24.4 - j * 1.9
					K.box(x, y + b, 3.12, 0.9, 0.5, 0.12, med[(i + j * 2) % 6], 0.02, 1.3)
					K.column(x, y - 0.75 + b, 3.18, 0.7, 0.55, 0.25, "#c8ccd0" if j else "#e2c25a", 1, 0.05)
			for s in [-1, 1]:   # epaulettes
				K.box(s * 5.5, 26.4 + b, 0, 3, 1, 3.8, "#e2c25a", 0.25)
				for k in 3:
					K.beam(Vector3(s * (4.5 + k * 0.9), 25.9 + b, 1.4 - k * 1.4), Vector3(s * (4.6 + k * 0.9), 24.6 + b, 1.4 - k * 1.4), 0.16, "#e2c25a", 0.12, 0.03)
			K.column(0, 16.3 + b, 0, 9.7, 1.3, 6, "#3a2414", 1, 0.25)
			K.box(0, 16.3 + b, 3.05, 1.6, 1.1, 0.3, "#e2c25a", 0.1)
			neck.call()
			K.box(0, 26.5 + b, 1.8, 5, 1.2, 2.4, B, 0.2)
			return true
		"stripking":
			K.column(0, 15 + b, 0, 9.1, 3.8, 5.2, T, 1.06)
			K.column(0, 21.2 + b, 0, 10.2, 10.8, 5.6, B, 1.15)
			flat(K, [[-2.4, 26.4], [2.4, 26.4], [0, 20.4]], 3.02, skin)   # the deep V, sewn with rhinestones
			for k in 6:
				var f := k / 5.0
				for s in [-1, 1]:
					K.box(s * (2.6 - f * 2.3), 26 - f * 5.4 + b, 3.1, 0.42, 0.42, 0.12, "#e2c25a" if k % 2 else "#e6f0ff", 0.02, 1.3)
			for i in 5:
				K.box(-3.6 + i * 1.8, 18.3 + b, 3.05, 0.5, 0.5, 0.12, "#e6f0ff" if i % 2 else "#e2c25a", 0.02, 1.3)
			K.column(0, 16.3 + b, 0, 9.8, 1.8, 6, "#e2c25a", 1, 0.3)   # the belt and its buckle
			K.box(0, 16.3 + b, 3.15, 3.2, 2.4, 0.4, "#f4dc7a", 0.15)
			K.column(0, 27.9 + b, -0.8, 7.8, 3.2, 5.2, B, 1.18, 0.35)   # the high collar
			K.box(0, 19.4 + b, -3.7, 11.4, 13.4, 0.45, B, 0.3)   # the cape, lined red
			K.box(0, 19.4 + b, -3.4, 10.6, 12.6, 0.2, "#c42a3a", 0.06)
			for k in 4:
				K.box(-3.6 + k * 2.4, 14 + b, -3.95, 0.45, 0.45, 0.12, "#e2c25a", 0.02, 1.2)
			return true
		"custodian":
			K.box(0, 15.4 + b, 0, 9.6, 4, 6.4, "#5e6a44", 0.4)
			K.box(0, 21.6 + b, 0, 11.6, 11.4, 7.2, B, 0.5)
			K.box(4.2, 21.6 + b, 0, 2.6, 11.6, 7.3, "#6a7650", 0.3)
			K.box(0, 19.4 + b, 3.7, 11.8, 1.4, 0.2, "#d0782a", 0.05, 1)   # stripe, vents, a lamp
			for q in [[-3, 24.6], [0, 24.6], [3, 24.6]]:
				K.box(q[0], q[1] + b, 3.7, 1.8, 1.6, 0.2, "#3a3f2c", 0.05, 1)
			K.box(-3.6, 17.2 + b, 3.7, 1.4, 0.8, 0.2, "#ffd23a", 0.03, 1.2)
			for s in [-1, 1]:   # shoulder caps
				K.box(s * 6, 25.6 + b, 0, 2.4, 2.4, 6, "#5e6a44", 0.35)
			K.beam(Vector3(-2.4, 12 + b, -4.1), Vector3(3, 33.4 + b, -4.1), 0.42, "#8a7a5a", 0.42, 0.15)   # the mop, holstered on the back
			K.box(3.3, 34.2 + b, -4.1, 3.2, 1.5, 1.8, "#c8c0a0", 0.25)
			K.box(0, 26.6 + b, 0, 4, 1.6, 4, "#3a3f2c", 0.3)
			return true
		"visitor":
			K.column(0, 15.4 + b, 0, 6, 3, 4, B, 0.95)
			K.column(0, 21.4 + b, 0, 7, 12, 4.4, B, 0.82)
			K.column(0, 27.6 + b, 0, 2.2, 3.2, 2.2, B, 1, 0.3)
			for s in [-1, 1]:   # a thin frame, faint ribs
				K.beam(Vector3(s * 2, 25.6 + b, 1.6), Vector3(s * 1.2, 17 + b, 2), 0.12, Wardrobe.tint(B, 0.8), 0.12, 0.03)
			return true
	return false


## an arm, after it's drawn: garters, the card fan, the robot's plates
static func arm(K: Wardrobe, sh: Vector3, el: Vector3, ha: Vector3, left: bool) -> void:
	var m: String = K.o.get("usModel", "")
	if m == "cardsharp":
		K.beam(sh + (el - sh) * 0.55, sh + (el - sh) * 0.68, 2.25, "#c42a3a", 2.25, 0.15)
		if left:
			for k in 5:
				var a := -0.7 + k * 0.35
				var cx := ha.x - 0.4
				var cy := ha.y + 1.2
				var cz := ha.z + 0.4
				var dx := sin(a)
				var dy := cos(a)
				var W := 1.1
				var H := 2.6
				var v := [Vector3(cx - dy * W * 0.5, cy + dx * W * 0.5, cz + k * 0.02), Vector3(cx + dy * W * 0.5, cy - dx * W * 0.5, cz + k * 0.02),
					Vector3(cx + dy * W * 0.5 + dx * H, cy - dx * W * 0.5 + dy * H, cz + k * 0.02), Vector3(cx - dy * W * 0.5 + dx * H, cy + dx * W * 0.5 + dy * H, cz + k * 0.02)]
				K.mesh(v, [[0, 1, 2, 3], [3, 2, 1, 0]], "#f4f0e6" if k == 2 else "#ece6d8", 0.25, 0.4)
	elif m == "custodian":
		var mid := (sh + el) / 2
		K.column(mid.x, mid.y, mid.z, 3.2, 3, 3.2, "#5e6a44", 1, 0.3)


## the head: true when the model replaced it (no ordinary face); its own hats and hair are drawn here too
static func head(K: Wardrobe) -> bool:
	var m: String = K.o.get("usModel", "")
	var b := K.bob
	var skin := K.skin
	var o := K.o
	var hair := func(c: String) -> void: K.dome(c, 32.7, 4.2, 3.6, 1.65)
	match m:
		"visitor":
			egg(K, 0, 32.4, 0.3, 4.9, 5.6, 4.6, skin, 0.55)   # the big head, narrowing to the chin
			for s in [-1, 1]:
				var p: Array = []
				for i in 12:
					var a := i * PI / 6
					p.append([s * 1.95 + cos(a) * 1.25 * cos(s * 0.5) - sin(a) * 2.05 * sin(s * 0.5), 31.6 + sin(a) * 2.05 * cos(s * 0.5) + cos(a) * 1.25 * sin(s * 0.5)])
				flat(K, p, 4.55, "#08080c", 1.4)
				oval(K, s * 1.6, 32.4, 0.3, 0.35, 4.62, "#f4f4ff", 1.6)
			K.box(0, 29.4 + b, 4.05, 1.2, 0.18, 0.12, "#6a6a78", 0.02, 1.4)
			return true
		"custodian":
			K.column(0, 28.6 + b, 0, 4.6, 2.4, 4.2, "#3a3f2c", 1, 0.3)
			K.dome(skin, 29.6, 5.6, 5, 5.2)
			K.box(0, 31.4 + b, 4.75, 2.8, 2.8, 0.6, "#2a2c22", 0.2, 1.2)   # the one lens
			K.box(0, 31.4 + b, 5.1, 2, 2, 0.2, "#ffd23a", 0.04, 1.4)
			K.beam(Vector3(-0.8, 32.4 + b, 5.25), Vector3(0.7, 30.2 + b, 5.25), 0.1, "#1a1a12", 0.1, 0.02)   # its crack
			K.beam(Vector3(0.7, 30.2 + b, 5.25), Vector3(0.2, 29.9 + b, 5.25), 0.08, "#1a1a12", 0.08, 0.02)
			K.beam(Vector3(2.4, 34.2 + b, 0), Vector3(3.4, 37.2 + b, -0.6), 0.18, "#2a2c22", 0.18, 0.05)
			K.ball(3.4, 37.4 + b, -0.6, 0.45, "#ff3a2a")
			return true
		"stripking":   # the pompadour, sideburns, gold shades
			K.dome("#1a1410", 32.4, 4.5, 4, 2.4)
			K.beam(Vector3(0, 34.2 + b, 0.6), Vector3(0, 34.8 + b, 4.4), 1.9, "#1a1410", 1.3, 0.3)
			K.beam(Vector3(-1.4, 34 + b, 1), Vector3(-0.6, 34.6 + b, 4.1), 1.1, "#2a2018", 0.9, 0.2)
			for s in [-1, 1]:
				K.box(s * 3.75, 29.6 + b, 1.4, 0.7, 3, 1.4, "#1a1410", 0.12)
			K.box(0, 30.9 + b, 4.02, 6.6, 1.35, 0.4, "#e2c25a", 0.15, 1.3)
			for s in [-1, 1]:
				K.box(s * 1.55, 30.8 + b, 4.22, 2.3, 0.95, 0.15, "#2a1a08", 0.03, 1.5)
			return false
		"generalissimo":   # the peaked cap and its band, an invented badge, a moustache
			K.column(0, 34 + b, 0, 9.2, 2.6, 8.2, "#4a4a30", 1.32, 0.45)
			K.column(0, 32.7 + b, 0, 9, 1, 8.1, "#c8a040", 1, 0.2)
			K.box(0, 32.4 + b, 4.4, 6.6, 0.45, 2.8, "#141414", 0.3)
			star(K, 0, 34.1, 4.9, 1.1, "#e2c25a")
			K.box(0, 29.1 + b, 3.62, 3.2, 0.8, 0.42, "#2a1e14", 0.05, 1.5)
			return false
		"gunslinger":   # the flat brim, the neckerchief pulled up
			K.brim(32.5 + b, 13.6, 0.55, 11.6, "#4a3424", 0.4, 4.7, 4.1)
			K.column(0, 34.1 + b, 0, 8.4, 3.1, 7.4, "#4a3424", 0.9, 0.45)
			K.column(0, 33.1 + b, 0, 8.5, 0.7, 7.5, "#2a1a10", 1, 0.15)
			K.box(0, 28.4 + b, 3.2, 5.4, 1.6, 1.4, "#a8202a", 0.12, 1.1)
			return false
		"sheriff":   # the tall hat, its band and crease, the moustache
			K.brim(32.6 + b, 12.6, 0.55, 10.8, "#d8c8a0", 0.4, 4.6, 4.1)
			K.column(0, 35.6 + b, 0, 8, 6.2, 7, "#d8c8a0", 0.88, 0.45)
			K.column(0, 33.3 + b, 0, 8.2, 0.8, 7.2, "#3a2414", 1, 0.15)
			K.box(0, 37.6 + b, 0, 0.8, 1.2, 6, Wardrobe.tint("#d8c8a0", 0.85), 0.1)
			K.box(0, 29.15 + b, 3.62, 3.8, 0.85, 0.45, "#4a3020", 0.05, 1.5)
			for s in [-1, 1]:
				K.beam(Vector3(s * 1.8, 29 + b, 3.6), Vector3(s * 2.2, 27.9 + b, 3.5), 0.3, "#4a3020", 0.2, 0.05)
			return false
		"pitboss":   # the earpiece and its coil
			K.beam(Vector3(4.1, 30.3 + b, 0.4), Vector3(3.4, 27.2 + b, 1.6), 0.12, "#1a1a1a", 0.12, 0.03)
			K.box(4.3, 30.5 + b, 0.6, 0.6, 0.9, 0.7, "#1a1a1a", 0.08)
			if o.get("usHair"):
				hair.call("#2a2018")
			return false
		"highroller":
			if o.get("usHair"):
				hair.call("#1a1410")
			return false
		"shelterdweller":
			if o.get("usHair"):
				hair.call("#6a4a2a")
			return false
		"cardsharp":
			if o.get("usHair"):
				hair.call("#2a1e14")
				K.box(0, 29.2 + b, 3.6, 2.8, 0.6, 0.4, "#2a1e14", 0.05, 1.5)
			return false
	return false


## the five hats (look_for sets o.usHat)
static func hat(K: Wardrobe, h: String) -> void:
	var b := K.bob
	var time := K.time
	var o := K.o
	var hair := func() -> void:
		if not (o.get("bones") or o.get("wraps") or o.get("phantom")):
			K.dome("#433b2b", 32.7, 4.2, 3.6, 1.65)
	match h:
		"tinfoil":
			K.column(0, 33 + b, 0, 10.2, 1.4, 8.8, "#c8ccd0", 1, 0.3)
			K.column(0, 35 + b, 0, 8.4, 3, 7.4, "#d8dce0", 0.75, 0.4)
			K.column(0, 37.6 + b, -0.2, 5.4, 2.4, 4.8, "#c0c4c8", 0.6, 0.35)
			K.beam(Vector3(0, 38.6 + b, -0.3), Vector3(0.6, 40.6 + b, -0.8), 1.2, "#e4e8ec", 0.15, 0.25)
			for k in 6:   # facets catching the light
				var a := k * 1.05 + 0.3
				K.box(cos(a) * 3.6, 34.4 + (k % 3) * 1.1 + b, sin(a) * 3.1, 1.3, 0.9, 0.3, "#f4f8ff" if k % 2 else "#a8acb0", 0.05, 0.6)
		"eyeshade":
			hair.call()
			K.column(0, 32.5 + b, 0, 10.1, 1.1, 8.6, "#1a1a1a", 1, 0.2)
			K.box(0, 32.3 + b, 5.4, 7.6, 0.35, 3.8, "#3f9a5a", 0.25, 1)
			K.box(0, 32.25 + b, 7.2, 7.6, 0.3, 0.35, "#2a6a3e", 0.05, 1)
		"antennae":
			hair.call()
			K.column(0, 32.6 + b, 0, 10.1, 1, 8.6, "#1a1a1a", 1, 0.2)
			for s in [-1, 1]:
				var sw := sin(time * 5 + s) * 0.6
				K.beam(Vector3(s * 2.2, 33.6 + b, 0), Vector3(s * 3.6 + sw, 39.4 + b, -0.4), 0.22, "#2a2a2a", 0.2, 0.06)
				K.ball(s * 3.6 + sw, 39.7 + b, -0.4, 0.75, "#7cff6b")
		"plumecrest":
			hair.call()
			K.column(0, 33.1 + b, 0, 10.4, 1.5, 8.9, "#ff5ad8", 1, 0.25)
			for k in 6:
				K.box(-3.6 + k * 1.45, 33.1 + b, 4.3, 0.6, 0.6, 0.2, "#ffe39a" if k % 2 else "#e6f0ff", 0.02, 1.2)
			K.box(0, 33.6 + b, 4.5, 1.6, 1.6, 0.4, "#ffe39a", 0.12, 1.3)
			for k in 5:
				var a := (k - 2) * 0.32
				var sw := sin(time * 2.2 + k) * 0.4
				K.beam(Vector3(sin(a) * 2.2, 34 + b, 1.6), Vector3(sin(a) * 6 + sw, 44.5 - absi(k - 2) * 1.4 + b, -1), 1.35, "#ffd0f0" if k % 2 else "#ff8ad8", 0.25, 0.3)
		"neonhalo":   # one tube or two flickers
			hair.call()
			var y := 39.2 + b + sin(time * 2.4) * 0.3
			for i in 16:
				var a := i * PI / 8
				var a2 := (i + 1) * PI / 8
				var off := sin(time * 9 + i * 7) > 0.92 and i % 5 == 2
				K.beam(Vector3(cos(a) * 6, y, sin(a) * 4.8), Vector3(cos(a2) * 6, y, sin(a2) * 4.8), 0.32, "#5a2048" if off else "#ff5ad8", 0.32, 0.04)
