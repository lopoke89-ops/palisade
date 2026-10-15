class_name CosFx
extends RefCounted
## Cosmetic effects drawn straight from the clock: the outfit auras (16b-auras.js) and the soft glow stamp they share
## with tracers and kill effects (cosmeticGlow, 20a-cosmetic-art.js). Everything draws on a CanvasItem in screen pixels.

static var _glow_tex: Texture2D
static var _cols := {}


## a CSS colour: #rgb, #rrggbb, rgba(), rgb(), hsl()
static func col(s) -> Color:
	if s is Color:
		return s
	var k: String = s
	if _cols.has(k):
		return _cols[k]
	var c := Color.WHITE
	if k.begins_with("#"):
		c = Color.html(k)
	elif k.begins_with("rgb"):
		var p := k.substr(k.find("(") + 1).trim_suffix(")").split(",")
		c = Color(float(p[0]) / 255, float(p[1]) / 255, float(p[2]) / 255, float(p[3]) if p.size() > 3 else 1.0)
	elif k.begins_with("hsl"):
		var p := k.substr(k.find("(") + 1).trim_suffix(")").replace("%", "").split(",")
		c = hsl(float(p[0]), float(p[1]) / 100, float(p[2]) / 100, float(p[3]) if p.size() > 3 else 1.0)
	elif k == "transparent":
		c = Color(0, 0, 0, 0)
	_cols[k] = c
	return c


static func hsl(h: float, s: float, l: float, a: float = 1.0) -> Color:
	h = fposmod(h, 360) / 360
	var q := l * (1 + s) if l < 0.5 else l + s - l * s
	var p := 2 * l - q
	var f := func(t: float) -> float:
		t = fposmod(t, 1.0)
		if t < 1.0 / 6:
			return p + (q - p) * 6 * t
		if t < 0.5:
			return q
		if t < 2.0 / 3:
			return p + (q - p) * (2.0 / 3 - t) * 6
		return p
	return Color(f.call(h + 1.0 / 3), f.call(h), f.call(h - 1.0 / 3), a)


static func glow_tex() -> Texture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
		g.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(0, 0, 0, 0)])   # to transparent black, as the canvas fades it
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_glow_tex = t
	return _glow_tex


## the soft round light every cosmetic uses: solid to a fifth of r, fading out to r
static func glow(cv: CanvasItem, x: float, y: float, r: float, c, alpha: float = 1.0) -> void:
	var k := col(c)
	k.a *= alpha
	if k.a <= 0.003 or r <= 0:
		return
	cv.draw_texture_rect(glow_tex(), Rect2(x - r, y - r, r * 2, r * 2), false, k)


static func ellipse_pts(cx: float, cy: float, rx: float, ry: float, n: int = 40) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var a := TAU * i / n
		out.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return out


static func _a(c, a: float) -> Color:
	var k := col(c)
	k.a *= a
	return k


static func shape(cv: CanvasItem, kind: String, x: float, y: float, r: float, c, a: float, rot: float = 0.0) -> void:
	var k := _a(c, a)
	if k.a <= 0.003:
		return
	match kind:
		"dot":
			cv.draw_rect(Rect2(x - r * 0.5, y - r * 0.5, r, r), k)
		"diamond":
			cv.draw_colored_polygon(PackedVector2Array([Vector2(x, y - r * 1.3), Vector2(x + r * 0.6, y), Vector2(x, y + r * 0.8), Vector2(x - r * 0.6, y)]), k)
		"star":
			var p := PackedVector2Array()
			for i in 8:
				var an := i * PI / 4 + rot
				var rr := r * 0.28 if i % 2 else r
				p.append(Vector2(x + cos(an) * rr, y + sin(an) * rr))
			cv.draw_colored_polygon(p, k)
		"drop":   # two quadratic curves from the tip
			var p := PackedVector2Array()
			var A := Vector2(x, y - r * 1.4)
			var B := Vector2(x, y + r * 0.6)
			for side in [1.0, -1.0]:
				var C := Vector2(x + side * r * 0.8, y + r * 0.1)
				for i in 7:
					var t := i / 6.0
					var s: Vector2 = A.lerp(C, t).lerp(C.lerp(B, t), t) if side > 0 else B.lerp(C, t).lerp(C.lerp(A, t), t)
					p.append(s)
			cv.draw_colored_polygon(p, k)
		"flake":
			cv.draw_rect(Rect2(x - r * 0.6, y - r * 0.25, r * 1.2, r * 0.5), k)
		"leaf":
			var p := PackedVector2Array()
			for i in 12:
				var an := TAU * i / 12
				var v := Vector2(cos(an) * r * 0.9, sin(an) * r * 0.4).rotated(rot)
				p.append(Vector2(x, y) + v)
			cv.draw_colored_polygon(p, k)


const AURA_GROUND := ["pool", "ring", "pulse", "mist"]
const AURA_STILL := ["pool", "ring", "glow"]


static func _pick(part: String, p: String) -> bool:
	match part:
		"ground":
			return p in AURA_GROUND
		"top":
			return not (p in AURA_GROUND)
		"sground":
			return p == "pool" or p == "ring"
		"stop":
			return p == "glow"
		"moving":
			return not (p in AURA_STILL)
	return true


## an outfit's moving effect at the feet (x, y), s pixels per model unit, t seconds. part: "ground" (under the figure),
## "top" (over it) or "" for all.
static func paint_aura(cv: CanvasItem, kind: String, x: float, y: float, s: float, t: float, alpha: float = 1.0, part: String = "") -> void:
	var L: Array = PalLocker.catalog().get("AURAS", {}).get(kind, [])
	for o in L:
		if part != "" and not _pick(part, o.p):
			continue
		_part(cv, o, x, y, s, t, alpha)


static func _part(cv: CanvasItem, o: Dictionary, x: float, y: float, s: float, t: float, A: float) -> void:
	var H := func(i: int, j: int) -> float: return Pal.hash2(i, j)
	match String(o.p):
		"glow":
			glow(cv, x, y - o.get("y", 18) * s, o.get("r", 16) * s, o.col, A * o.get("a", 0.2) * (1 + 0.12 * sin(t * 2.3)))
		"pool":
			cv.draw_set_transform(Vector2(x, y), 0, Vector2(1, 0.38))
			glow(cv, 0, 0, o.get("r", 15) * s, o.col, A * o.get("a", 0.3) * (1 + 0.15 * sin(t * 3.1)))
			cv.draw_set_transform(Vector2.ZERO)
		"ring":
			var k := 1 + 0.06 * sin(t * 2.4)
			cv.draw_polyline(ellipse_pts(x, y + 0.6 * s, 12.5 * s * k, 4.7 * s * k), _a(o.col, A * 0.75), maxf(1, 0.9 * s), true)
			cv.draw_polyline(ellipse_pts(x, y + 0.6 * s, 14.5 * s * k, 5.5 * s * k), _a(o.col, A * 0.375), maxf(0.5, 0.35 * s), true)
		"pulse":
			var ph: float = fmod(t / o.get("every", 1.8), 1.0)
			if ph > 0.45:
				return
			var k := ph / 0.45
			cv.draw_polyline(ellipse_pts(x, y + 0.6 * s, (8 + 18 * k) * s, (3 + 6.8 * k) * s), _a(o.col, A * (1 - k) * 0.8), maxf(1, 1.4 * s * (1 - k)), true)
		"rise":
			var cols: Array = o.cols
			for i in int(o.get("n", 6)):
				var ph: float = fmod(t * o.get("sp", 0.5) * (0.7 + 0.6 * H.call(i, 1)) + H.call(i, 2), 1.0)
				var px: float = x + ((H.call(i, 3) - 0.5) * 18 + sin(t * 1.7 + i * 2.3) * 2) * s
				var py := y - (ph * 44 + 2) * s
				shape(cv, o.get("shape", "diamond"), px, py, o.get("size", 1.2) * s, cols[i % cols.size()], A * sin(ph * PI), t * 2 + i)
		"fall":
			var cols: Array = o.cols
			var top: float = o.get("top", 40)
			for i in int(o.get("n", 6)):
				var ph: float = fmod(t * o.get("sp", 0.7) * (0.8 + 0.4 * H.call(i, 5)) + H.call(i, 6), 1.0)
				var px: float = x + ((H.call(i, 7) - 0.5) * o.get("w", 20) + (sin(t + i) * 2 if o.get("drift") else 0.0)) * s
				var py := y - (top - ph * top) * s
				if ph < 0.94:
					shape(cv, o.get("shape", "drop"), px, py, o.get("size", 1) * s, cols[i % cols.size()], A * minf(1, ph * 6) * 0.9, t + i)
				elif o.get("ripple"):
					var k := (ph - 0.94) / 0.06
					cv.draw_polyline(ellipse_pts(px, y, (1 + 3 * k) * s, (0.4 + 1.2 * k) * s, 16), _a(cols[i % cols.size()], A * (1 - k) * 0.8), maxf(0.5, 0.3 * s), true)
		"sparks":
			var cols: Array = o.cols
			var cx: float = x + o.get("x", 0) * s
			var cy: float = y - o.get("y", 15) * s
			for i in int(o.get("n", 6)):
				var ph: float = fmod(t * o.get("sp", 2.2) + H.call(i, 11), 1.0)
				var a: float = o.get("dir", -PI / 2) + (H.call(i, 12) - 0.5) * o.get("spread", 2.4)
				var d: float = (2 + ph * o.get("len", 9)) * s
				var g := ph * ph * 6 * s
				cv.draw_line(Vector2(cx + cos(a) * d * 0.55, cy + sin(a) * d * 0.55 + g * 0.5), Vector2(cx + cos(a) * d, cy + sin(a) * d + g), _a(cols[i % cols.size()], A * (1 - ph)), maxf(0.6, 0.45 * s), true)
			glow(cv, cx, cy, 4 * s, cols[0], A * (0.5 + 0.3 * sin(t * 30)))
		"smoke":
			var n: float = int(o.get("n", 3))
			for i in n:
				var ph := fmod(t * 0.45 + float(i) / n, 1.0)
				var px: float = x + (o.get("x", 5) + sin(t + i) * 1.5) * s
				var py: float = y - (o.get("y", 26) + ph * 14) * s
				cv.draw_circle(Vector2(px, py), (1.5 + ph * 3.5) * s, _a(o.get("col", "#6a6560"), A * (1 - ph) * 0.35))
		"arcs":
			for i in int(o.get("n", 2)):
				var f := floori(t * 9 + i * 3.7)
				if H.call(f, i + 20) >= 0.45:
					continue
				var x0: float = x + (H.call(f, 1 + i) - 0.5) * 16 * s
				var y0: float = y - (10 + H.call(f, 2 + i) * 24) * s
				var x1: float = x0 + (H.call(f, 3 + i) - 0.5) * 14 * s
				var y1: float = y0 + (H.call(f, 4 + i) - 0.5) * 12 * s
				var pts := PackedVector2Array([Vector2(x0, y0)])
				for k in range(1, 4):
					pts.append(Vector2(x0 + (x1 - x0) * k / 4 + (H.call(f + k, 5 + i) - 0.5) * 4 * s, y0 + (y1 - y0) * k / 4 + (H.call(f + k, 6 + i) - 0.5) * 4 * s))
				pts.append(Vector2(x1, y1))
				cv.draw_polyline(pts, _a(o.col, A * 0.35), maxf(0.5, 1.6 * s), true)
				cv.draw_polyline(pts, _a("#ffffff", A), maxf(0.5, 0.55 * s), true)
		"orbit":
			var n: float = int(o.get("n", 3))
			for i in n:
				var a: float = t * o.get("sp", 1.2) + i * TAU / n
				var px: float = x + cos(a) * o.get("r", 12) * s
				var py: float = y - (o.get("y", 16) - sin(a) * 4) * s
				var k := A * (1.0 if sin(a) > 0 else 0.45)
				if o.get("glow"):
					glow(cv, px, py, 3 * s, o.col, k * 0.6)
				shape(cv, o.get("shape", "star"), px, py, o.get("size", 1.3) * s, o.col, k, t * 3)
		"flies":
			for i in int(o.get("n", 6)):
				var px: float = x + sin(t * 0.9 * (1 + H.call(i, 31)) + i * 2) * 14 * s
				var py: float = y - (8 + H.call(i, 32) * 26 + sin(t * 1.3 + i) * 5) * s
				var b := pow((sin(t * 2.6 + i * 1.9) + 1) / 2, 2)
				if b < 0.05:
					continue
				glow(cv, px, py, 3.2 * s, o.col, A * b * 0.8)
				cv.draw_rect(Rect2(px - 0.4 * s, py - 0.4 * s, 0.8 * s, 0.8 * s), _a("#fffbe0", A * b))
		"mist":
			for i in int(o.get("n", 3)):
				glow(cv, x + sin(t * 0.5 + i * 2.1) * 10 * s, y - (1 + i % 2) * s, (8 + 2 * sin(t + i)) * s, o.col, A * o.get("a", 0.28))
		"bats":
			var n: float = int(o.get("n", 3))
			for i in n:
				var a := t * 1.4 + i * TAU / n
				var px := x + cos(a) * 12 * s
				var py := y - (36 + sin(a * 2) * 2 - sin(a) * 3) * s
				var f := sin(t * 16 + i * 2) * 0.9
				var w := 2.2 * s
				var k := A * (1.0 if sin(a) > 0 else 0.55)
				var ink := _a("#0c0a10", k)
				cv.draw_polyline(PackedVector2Array([Vector2(px - w * 1.4, py - w * f), Vector2(px - w * 0.5, py), Vector2(px, py - w * 0.35), Vector2(px + w * 0.5, py), Vector2(px + w * 1.4, py - w * f)]), ink, maxf(0.8, 0.55 * s), true)
				cv.draw_circle(Vector2(px, py), w * 0.35, ink)
				cv.draw_rect(Rect2(px - 0.3 * s, py - 0.3 * s, 0.6 * s, 0.5 * s), _a("#ff3a3a", k))
		"twinkle":
			for i in int(o.get("n", 4)):
				var ph: float = fmod(t * 0.8 + H.call(i, 41), 1.0)
				if ph > 0.35:
					continue
				var k := sin(ph / 0.35 * PI)
				shape(cv, "star", x + (H.call(i, 42) - 0.5) * 20 * s, y - (6 + H.call(i, 43) * 32) * s, (1.2 + k * 1.3) * s, o.get("col", "#fffbe0"), A * k, 0)
