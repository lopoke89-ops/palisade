class_name CosArt
extends RefCounted
## The browser's cosmetic artwork on a Ctx2D (20a-cosmetic-art.js, 20b-winter-effects.js, 20c-hybrid-effects.js):
## tracer stamps (paintTracer), the painted kill finishers (paintFinish) and the cosmetic particle shapes.

const INK := "#0b1111"


static func trail(key: String) -> Dictionary:
	var T: Dictionary = PalLocker.catalog().get("TRAILS", {})
	return T.get(key, T.get("std", {}))


static func mix(a, b, t: float) -> Color:
	return CosFx.col(a).lerp(CosFx.col(b), clampf(t, 0, 1))


# ---------------------------------------------------------------- tracers

## the stamp's alpha along its 192 units: solid to 64%, clear at the tail (the stamp's destination-in fade)
static func _fade(o: float) -> float:
	return 1.0 if o <= 0.64 else maxf(0.0, 1.0 - (o - 0.64) / 0.36)


## a colour or a gradient across the stamp, with the tail fade multiplied in
static func _faded(x: Ctx2D, style) -> Ctx2D.Grad:
	var g := x.create_linear_gradient(0, 0, 192, 0)
	var offs := {0.0: true, 0.64: true, 1.0: true}
	var src: Ctx2D.Grad = style if style is Ctx2D.Grad else null
	if src:
		for s in src.stops:
			offs[s[0]] = true
		for i in 13:
			offs[i / 12.0] = true
	var ks := offs.keys()
	ks.sort()
	for o in ks:
		var c: Color = src.at(o) if src else CosFx.col(style)
		c.a *= _fade(o)
		g.add_color_stop(o, c)
	return g


static var _glow: ImageTexture


## the stamp's shadowBlur(6) as a soft mask over its 192x48 frame: a Gaussian falloff from the outline, faded to the tail
static func _glow_tex() -> ImageTexture:
	if _glow:
		return _glow
	var img := Image.create(96, 24, false, Image.FORMAT_RGBA8)
	var sig := 6.0
	for py in 24:
		for px in 96:
			var u := (px + 0.5) * 2
			var v := (py + 0.5) * 2
			var h := 0.0
			if u < 7:
				h = u
			elif u < 35:
				h = 7 - (u - 7) / 28
			else:
				h = maxf(0, 6 - (u - 35) / 155 * 6)
			var y := absf(v - 24)
			var a := (_phi((h - y) / sig) - _phi((-h - y) / sig)) * _fade(u / 192.0)
			img.set_pixel(px, py, Color(1, 1, 1, a))
	_glow = ImageTexture.create_from_image(img)
	return _glow


## the standard normal CDF (Abramowitz and Stegun 7.1.26)
static func _phi(z: float) -> float:
	var t := 1.0 / (1.0 + 0.3275911 * absf(z) / sqrt(2.0))
	var e := 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-z * z / 2)
	return 0.5 * (1.0 + (e if z >= 0 else -e))


static func _shape(x: Ctx2D, k: float = 1.0) -> void:
	x.begin_path()
	for q in [[0, 24], [7, 17], [35, 18], [190, 24], [35, 30], [7, 31]]:
		var yy: float = 24 + (q[1] - 24) * k
		if q[0] == 0:
			x.move_to(q[0], yy)
		else:
			x.line_to(q[0], yy)
	x.close_path()


## tracerStamp: the 192x48 artwork of a tracer, drawn in place
static func stamp(x: Ctx2D, key: String, st: Dictionary, t: float, ci: int = 0) -> void:
	var phase := floori(fposmod(t * 2, 12)) if st.get("rgrad") or st.get("rainbow") else 0
	var cyc: Array = st.get("cycle", [])
	var cycle_col = cyc[maxi(0, ci) % cyc.size()] if not cyc.is_empty() else null
	var colors: Array
	if cycle_col != null:
		colors = [cycle_col, cycle_col]
	elif st.get("rgrad") or st.get("rainbow"):
		colors = []
		for i in 5:
			colors.append(CosFx.hsl(phase * 30 + i * 65, 1, 0.7))
	elif st.has("grad"):
		colors = st.grad
	else:
		colors = [st.get("c", st.get("head", "#ffecaa")), st.get("c", "#ffb44a")]
	var gr := x.create_linear_gradient(0, 0, 192, 0)
	if st.has("bands"):
		var B: Array = st.bands
		var n := B.size()
		var L := 0.64
		for i in n:
			gr.add_color_stop(float(i) / n * L, B[i])
			gr.add_color_stop(minf(1, float(i + 1) / n * L - 0.001), B[i])
		gr.add_color_stop(1, B[n - 1])
	else:
		for i in colors.size():
			gr.add_color_stop(float(i) / (colors.size() - 1), colors[i])
	var edge = st.get("edge")
	x.draw_image(_glow_tex(), 0, 0, 192, 48, CosFx.col(edge if edge else colors[0]))   # the canvas shadow blur
	_shape(x)
	x.fill(_faded(x, gr))
	var sk = "#a6aaa5" if cycle_col != null and (cycle_col == "#000000" or cycle_col == "#2c2c2c") else (edge if edge else "rgba(7,10,8,.55)")
	x.line_width = 4.0 if edge else (2.5 if cycle_col != null else 1.3)
	x.stroke(_faded(x, sk))
	x.fill(_faded(x, "#10071c" if edge else gr) if edge else _faded(x, gr))
	if not edge and cycle_col == null:
		x.begin_path()
		x.move_to(0, 24)
		x.line_to(10, 22.7)
		x.line_to(145, 24)
		x.line_to(10, 25.3)
		x.close_path()
		x.fill(_faded(x, "#fff4b2" if st.get("rgrad") else "#f8ffff"))
	elif edge:
		x.begin_path()
		x.move_to(1, 23)
		x.line_to(45, 19)
		x.line_to(140, 23)
		x.line_width = 1
		x.stroke(_faded(x, "#e1bbff"))
	# small marks on the cached frame
	if st.get("winter"):
		for i in 3:
			winter_flake(x, 20 + i * 38, 24, 5.0 if i == 0 else 3.0, st.c, i * 0.3)
		if st.winter == "auroralance" or st.winter == "solsticecomet":
			x.stroke_style = "#c1a9f1" if st.winter == "auroralance" else "#a4e7ff"
			x.line_width = 2
			x.begin_path()
			x.move_to(0, 25)
			x.bezier_curve_to(32, 13, 80, 33, 150, 24)
			x.stroke()
	if st.get("pulse") or key == "plasma" or key == "aurora":
		x.stroke_style = "#fff2fb" if st.get("pulse") else "#deffff"
		x.line_width = 1.4
		x.begin_path()
		for i in range(1, 4):
			var px := i * 32.0
			x.move_to(px, 19)
			x.line_to(px + 3, 24)
			x.line_to(px, 29)
		x.stroke()
	var pk: String = st.get("pk", "")
	if pk == "star" or pk == "cosmic" or st.get("rgrad"):
		x.fill_style = "#fff1ac" if st.get("rgrad") else "#f4edff"
		x.begin_path()
		for i in range(1, 4):
			var px := i * 35.0
			var py := 24.0 + (2 if i % 2 else -2)
			var r := 5.0 if i == 1 else 3.0
			x.move_to(px - r, py)
			x.line_to(px, py - r)
			x.line_to(px + r, py)
			x.line_to(px, py + r)
			x.close_path()
		x.fill()
	if st.get("arc"):
		for q in [[7, "rgba(40,200,220,.45)"], [3.2, st.c], [1.2, "#eaffff"]]:
			x.stroke_style = q[1]
			x.line_width = q[0]
			x.begin_path()
			x.arc(-14, 24, 26, -0.62, 0.62)
			x.stroke()
	if st.get("chain"):
		x.stroke_style = "#1a0604"
		x.line_width = 2
		for i in 5:
			x.begin_path()
			x.ellipse(18 + i * 22, 24, 8, 4.2, 0, 0, TAU)
			x.stroke()
	if pk == "rock":
		x.fill_style = "#d2b8a0"
		x.stroke_style = "#292322"
		x.line_width = 1.5
		x.begin_path()
		for i in range(1, 4):
			var px := i * 34.0
			var py := 24.0 + (4 if i % 2 else -4)
			x.move_to(px - 4, py)
			x.line_to(px, py - 4)
			x.line_to(px + 4, py)
			x.line_to(px, py + 5)
			x.close_path()
		x.fill()
		x.stroke()


static func _stamp_at(x: Ctx2D, key: String, st: Dictionary, t: float, ci: int, y0: float, len: float, h: float) -> void:
	x.save()
	x.translate(0, y0)
	x.scale(len / 192.0, h / 48.0)
	stamp(x, key, st, t, ci)
	x.restore()


## a channel copy of the glitch stamp in one colour (glitchChannel)
static func _channel(x: Ctx2D, col: String, y0: float, len: float, h: float, dx: float) -> void:
	x.save()
	x.translate(dx, y0)
	x.scale(len / 192.0, h / 48.0)
	_shape(x)
	x.fill(_faded(x, col))
	x.restore()


## paintTracer: a round from (x1, y1) (its head) back to (x2, y2), w its width in pixels, ci a flag tracer's colour
static func paint_tracer(x: Ctx2D, x1: float, y1: float, x2: float, y2: float, key: String, w: float, t: float, heavy: bool = false, ci: int = 0) -> void:
	var len := minf(Vector2(x2 - x1, y2 - y1).length(), w * 22)
	if len < 0.01:
		return
	var st := trail(key)
	x.save()
	x.translate(x1, y1)
	x.rotate(atan2(y2 - y1, x2 - x1))
	var cyc: Array = st.get("cycle", [])
	if not cyc.is_empty():
		var col: String = cyc[maxi(0, ci) % cyc.size()]
		_stamp_at(x, key, st, t, ci, -w * 3.25, len, w * 6.5)
		if st.get("premium"):
			x.fill_style = col
			x.stroke_style = "#a6aaa5" if col == "#000000" or col == "#2c2c2c" else "#20251f"
			x.line_width = maxf(0.4, w * 0.2)
			for i in (3 if st.premium == "g" else 2):
				x.begin_path()
				x.arc(len * (0.6 + i * 0.16), (1 if i % 2 else -1) * w * 0.6, w * 0.22, 0, TAU)
				x.fill()
				x.stroke()
		x.restore()
		return
	var width := w * (1 + 0.16 * sin(t * 28) if st.get("pulse") else 1.0)
	var height := width * 6.5
	if st.get("glitch"):
		var tear := floori(t * 13) % 7 == 0
		var split := width * (0.06 + 0.008 * sin(t * 19) + (0.008 if tear else 0.0))
		var drift := minf(width * 0.05, len * 0.005)
		x.save()
		x.composite = "lighter"
		x.global_alpha *= 0.88
		_channel(x, "#ff285b", -height / 2 - split, len, height, drift)
		_channel(x, "#24eaff", -height / 2 + split, len, height, -drift)
		x.restore()
		_stamp_at(x, key, st, t, 0, -height / 2, len, height)
		if tear:
			for i in 2:
				x.fill_style = "#24eaff" if i else "#ff285b"
				x.fill_rect(len * (0.28 + i * 0.28), (1 if i else -1) * split, minf(len * 0.17, width * 5), width * 0.42)
	else:
		_stamp_at(x, key, st, t, 0, -height / 2, len, height)
	if st.get("winter") == "solsticecomet":
		var cs := ["#ef5462", "#65c780", "#ffe09a", "#a6e8ff"]
		for i in 4:
			var px := len * (0.45 + i * 0.15)
			x.stroke_style = "#41644d"
			x.line_width = maxf(0.4, w * 0.22)
			x.begin_path()
			x.move_to(px, 0)
			x.line_to(px, w * 0.7)
			x.stroke()
			x.fill_style = cs[i]
			x.begin_path()
			x.ellipse(px, w * 0.9, w * 0.32, w * 0.48, 0, 0, TAU)
			x.fill()
	if st.get("winter") == "auroralance":
		x.fill_style = "#e2f5fa"
		x.global_alpha *= 0.5
		for i in 4:
			x.begin_path()
			x.arc(len * (0.55 + i * 0.12), (1 if i % 2 else -1) * w * 0.5, w * 0.18, 0, TAU)
			x.fill()
	x.restore()


static func winter_flake(x: Ctx2D, cx: float, cy: float, r: float, col, rotation: float = 0.0) -> void:
	x.save()
	x.translate(cx, cy)
	x.rotate(rotation)
	x.stroke_style = col
	x.line_width = maxf(0.5, r * 0.075)
	x.begin_path()
	for i in 6:
		var a := i * PI / 3
		var dx := cos(a)
		var dy := sin(a)
		x.move_to(0, 0)
		x.line_to(dx * r, dy * r)
		for side in [-1, 1]:
			var b: float = a + side * 0.7
			x.move_to(dx * r * 0.65, dy * r * 0.65)
			x.line_to(dx * r * 0.65 - cos(b) * r * 0.28, dy * r * 0.65 - sin(b) * r * 0.28)
	x.stroke()
	x.restore()


# ---------------------------------------------------------------- kill finishers

static func _path(x: Ctx2D, pts: Array, col, line = INK, w: float = 0.7) -> void:
	x.begin_path()
	for i in pts.size():
		if i:
			x.line_to(pts[i][0], pts[i][1])
		else:
			x.move_to(pts[i][0], pts[i][1])
	x.close_path()
	x.fill_style = col
	x.fill()
	if line != null:
		x.stroke_style = line
		x.line_width = w
		x.stroke()


static func _line(x: Ctx2D, pts: Array, col, w: float = 1.0) -> void:
	x.begin_path()
	for i in pts.size():
		if i:
			x.line_to(pts[i][0], pts[i][1])
		else:
			x.move_to(pts[i][0], pts[i][1])
	x.stroke_style = col
	x.line_width = w
	x.stroke()


static func _ring(x: Ctx2D, r: float, col, w: float = 1.0, flat: float = 1.0) -> void:
	x.stroke_style = col
	x.line_width = w
	x.begin_path()
	x.ellipse(0, 0, maxf(r, 0.01), maxf(r * flat, 0.01), 0, 0, TAU)
	x.stroke()


static func _star(x: Ctx2D, xx: float, yy: float, r: float, col, rot: float = 0.0) -> void:
	var pts: Array = []
	for i in 8:
		var a := i * PI / 4 + rot
		var rr := r * 0.25 if i % 2 else r
		pts.append([xx + cos(a) * rr, yy + sin(a) * rr])
	_path(x, pts, col, INK, 0.45)


static func _shard(x: Ctx2D, xx: float, yy: float, r: float, col, a: float = 0.0) -> void:
	x.save()
	x.translate(xx, yy)
	x.rotate(a)
	_path(x, [[0, -r], [r * 0.42, 0], [0, r], [-r * 0.42, 0]], col)
	_line(x, [[0, -r * 0.65], [0, r * 0.4]], "#fffbea", 0.45)
	x.restore()


static func _circle(x: Ctx2D, cx: float, cy: float, r: float, col) -> void:
	x.fill_style = col
	x.begin_path()
	x.arc(cx, cy, maxf(r, 0.01), 0, TAU)
	x.fill()


static func life(key: String) -> float:
	return PalLocker.catalog().get("FINISH_LIFE", {}).get(key, 0.0)


## paintFinish: the painted part of a kill effect at progress 0..1, scale pixels per unit, at (X, Y)
static func paint_finish(x: Ctx2D, key: String, p: float, scale: float, X: float, Y: float) -> void:
	if p < 0 or p >= 1:
		return
	var C := PalLocker.catalog()
	for f in C.get("WINTER_FX", []):
		if f[0] == key:
			_winter_finish(x, C.WINTER_FX.find(f), p, scale, X, Y)
			return
	if key in ["leaf", "bands", "swish", "nuke", "poop", "demon", "hundo", "fire", "eight", "sixty", "zzz"]:
		_hybrid_finish(x, key, p, scale, X, Y)
		return
	if life(key) <= 0:
		return
	var e := 1 - pow(1 - p, 3)
	var fade := minf(1, (1 - p) * 2.8)
	var pop := minf(1, p * 12)
	x.save()
	x.translate(X, Y)
	x.scale(scale, scale)
	x.global_alpha *= fade * pop
	var A0 := x.global_alpha
	x.line_join = "round"
	x.line_cap = "round"
	var gold := "#ffd566"
	var ice := "#c7f6ff"
	var violet := "#ac8dff"
	var radial := func(n: int, fn: Callable) -> void:
		for i in n:
			var a := i * TAU / n + 0.28
			var r := (6 + e * 19) * (1 + (i % 3) * 0.12)
			fn.call(cos(a) * r, sin(a) * r, a, i)
	match key:
		"sparks":
			x.glow(0, 0, 20, gold, 0.4)
			radial.call(10, func(xx, yy, a, i):
				var r := 1.5 + (1 - p) * 4
				_line(x, [[xx - cos(a) * r * 2, yy - sin(a) * r * 2], [xx, yy]], "#ffac4f", 2)
				_line(x, [[xx - cos(a) * r, yy - sin(a) * r], [xx, yy]], "#fff4c8", 0.8))
			_star(x, 0, 0, 7 * (1 - p), "#fff5cd")
		"smoke":
			var cs := ["#444b47", "#636d65", "#919b8d"]
			for i in 7:
				var a := i * 2.4
				var r := (7 + e * 14) * (1 - i * 0.045)
				var xx := cos(a) * e * 10
				var yy := sin(a) * e * 5 - e * 17
				x.global_alpha = A0 * (0.28 + i * 0.035)
				_circle(x, xx, yy, r, cs[i % 3])
				x.stroke_style = "#b7bfaa"
				x.line_width = 0.45
				x.begin_path()
				x.arc(xx, yy, r * 0.83, 3.5, 4.8)
				x.stroke()
		"confetti":
			x.glow(0, 0, 22, "#ff9dcd", 0.18)
			radial.call(14, func(xx, yy, a, i):
				var col: String = ["#ff6197", "#ffda6b", "#66e8ff", "#a3f471", "#c09aff"][i % 5]
				x.save()
				x.translate(xx, yy + p * p * 13)
				x.rotate(a + p * 5)
				_path(x, [[-1.6, -4], [1.6, -3], [2, 3], [-1, 4]], col, INK, 0.5)
				x.restore())
		"embers":
			x.glow(0, 0, 27, "#ff792f", 0.55)
			for i in 8:
				var xx := sin(i * 2.4) * e * 18
				var yy := -e * (12 + i * 3) + p * p * 6
				var r := (1 - p) * 6 + 1
				_path(x, [[xx, yy - r * 2], [xx + r * 0.6, yy], [xx, yy + r * 0.7], [xx - r * 0.65, yy]], "#ffbb49" if i % 2 else "#f26b36", INK, 0.45)
				_line(x, [[xx, yy], [xx, yy - r]], "#fff3aa", 0.7)
		"glint":
			x.glow(0, 0, 26, ice, 0.35)
			radial.call(7, func(xx, yy, a, i): _star(x, xx, yy, 2.8 + (1 - p) * 2.8, "#e6fbff" if i % 2 else "#8de9ff", p))
			_star(x, 0, 0, 9 * (1 - p), "#ffffff", PI / 4)
		"bolt":
			x.glow(0, 0, 32, "#79ccff", 0.5)
			var j := 1 if floori(p * 12) % 2 else -1
			var pts := [[5, -43], [-3 + j, -27], [5, -24], [-4, -9], [3, -11], [-2, 8]]
			_line(x, pts, "#3479d8", 7)
			_line(x, pts, "#98e8ff", 3)
			_line(x, pts, "#f0ffff", 1.2)
			_line(x, [[-3, -27], [-14, -22], [-10, -13], [-19, -7]], "#b5f4ff", 1.5)
			_line(x, [[-4, -9], [12, -14], [17, -7]], "#82dfff", 1.4)
			_ring(x, 6 + e * 17, "#88dfff", 1.1, 0.4)
		"skull":   # the browser floats a ☠ glyph; drawn here so no font is needed
			x.translate(0, -e * 18)
			_circle(x, 0, -2, 8, "#efe6d2")
			x.fill_style = "#efe6d2"
			x.fill_rect(-5, 2, 10, 6)
			for sx in [-3.2, 3.2]:
				_circle(x, sx, -2, 2.4, "#1a1410")
			_path(x, [[0, 1], [1.2, 3.2], [-1.2, 3.2]], "#1a1410", null)
			for k in 3:
				x.fill_style = "#1a1410"
				x.fill_rect(-3.4 + k * 2.6, 5.5, 0.8, 2.5)
		"pixel":
			x.glow(0, 0, 22, "#d884ff", 0.3)
			radial.call(12, func(xx, yy, a, i):
				var rr: float = (i % 3 + 2) * (1 - p * 0.55)
				var col: String = ["#ff567e", "#50f4d5", "#ffe77a", "#839dff"][i % 4]
				var rx: float = roundf(xx)
				var ry: float = roundf(yy)
				x.fill_style = INK
				x.fill_rect(rx - rr - 1, ry - rr - 1, rr * 2 + 2, rr * 2 + 2)
				x.fill_style = col
				x.fill_rect(rx - rr, ry - rr, rr * 2, rr * 2)
				x.fill_style = "#f2faff"
				x.fill_rect(rx - rr, ry - rr, rr, 0.7))
		"frost":
			x.glow(0, 0, 30, ice, 0.45)
			for i in 6:
				var a := i * PI / 3
				var rr := 9 + e * 17
				_line(x, [[0, 0], [cos(a) * rr, sin(a) * rr]], "#a7e8f9", 1)
				_shard(x, cos(a) * rr, sin(a) * rr, 5 * (1 - p) + 2, "#d6f9ff", a + PI / 2)
			_star(x, 0, 0, 8 * (1 - p), "#f2ffff", PI / 4)
		"gradburst", "sunburst":
			var warm := key == "sunburst"
			var ca := "#ff759f" if warm else "#c79bff"
			var cb := "#ffc36b" if warm else "#658bff"
			x.glow(0, 0, 32, ca, 0.48)
			_ring(x, 5 + e * 23, cb, 1.2)
			radial.call(8 if warm else 10, func(xx, yy, aa, i): _shard(x, xx, yy, (1 - p) * 5 + 1, ca if i % 2 else cb, aa + PI / 2))
			_star(x, 0, 0, 11 * (1 - p), "#fff3ea", PI / 4 if warm else 0.0)
		"toxic":
			x.glow(0, 0, 29, "#a7ff46", 0.32)
			for i in 8:
				var a := i * 0.79
				var r := e * (12 + i % 3 * 5)
				var xx := cos(a) * r
				var yy := sin(a) * r
				x.fill_style = "#a9ec42" if i % 2 else "#4ea546"
				x.stroke_style = INK
				x.line_width = 0.65
				x.begin_path()
				x.ellipse(xx, yy, 3 + (1 - p) * 2, 2.4 + (1 - p) * 2, 0, 0, TAU)
				x.fill()
				x.stroke()
				_line(x, [[xx, yy + 2], [xx, yy + 4 + p * 9]], "#b5f653", 1.5)
				x.fill_style = "#eeffd0"
				x.fill_rect(xx - 1, yy - 1, 1.5, 1)
		"supernova":
			x.glow(0, 0, 40, "#9189ff", 0.55)
			_ring(x, 7 + e * 25, "#a5b9ff", 1.3)
			_ring(x, 5 + e * 20, "#f5edff", 0.65, 0.52)
			_star(x, 0, 0, 19 * (1 - p) + 3, "#fff8dd", p * 0.2)
			radial.call(9, func(xx, yy, a, i): _star(x, xx, yy, 2.8 * (1 - p) + 0.7, "#e2d7ff" if i % 2 else "#fff4c1", a))
		"glitchout":
			x.glow(0, 0, 24, "#57edce", 0.2)
			var cs := ["#ff467c", "#53f4d5", "#8a99ff", "#f1faff"]
			for i in 11:
				var yy := (i - 5) * 4.0
				var xx := sin(i * 9 + floorf(p * 10)) * e * 17
				var ww := (6 + i % 4 * 4) * (1 - p * 0.55)
				x.fill_style = cs[i % 4]
				x.fill_rect(xx - ww / 2, yy, ww, 2 if i % 3 else 4)
				x.fill_style = INK
				x.fill_rect(xx + 1, yy + 0.7, ww * 0.3, 0.6)
		"singularity":
			var rr := 15 * (1 - p) + 3
			x.glow(0, 0, 36, violet, 0.5)
			_circle(x, 0, 0, rr, "#090710")
			_ring(x, rr + 2, "#c29fff", 1.3, 0.45)
			x.save()
			x.rotate(-0.35)
			_ring(x, rr + 5, "#8165dc", 1, 0.35)
			x.restore()
			for i in 9:
				var a := i * 0.7 + p * 5
				var r := (1 - e) * 30 + rr + 3
				_shard(x, cos(a) * r, sin(a) * r * 0.6, 2.5, "#bc8dff", a + p)
		"shockwave":
			x.glow(0, 0, 31, "#5df1ff", 0.3)
			_ring(x, 4 + e * 28, "#52edff", 2, 0.58)
			_ring(x, 2 + e * 21, "#fd7cda", 1.3, 0.58)
			_ring(x, 3 + e * 26, "#e2ffff", 0.5, 0.58)
			for i in 8:
				var a := i * PI / 4
				var r := 8 + e * 28
				_line(x, [[cos(a) * r, sin(a) * r * 0.58], [cos(a) * (r + 3), sin(a) * (r + 3) * 0.58]], "#fe8ddf" if i % 2 else "#b4ffff", 1)
		"bats":
			x.glow(0, 0, 26, "#6a3a9a", 0.35)
			for i in 6:
				var a := i * 1.05 + 0.4
				var r := 4 + e * 24
				var xx := cos(a) * r
				var yy := sin(a) * r * 0.6 - e * 14
				var f := sin(p * 40 + i * 2) * 0.8
				var s := 4 + (i % 2) * 1.5
				_line(x, [[xx - s * 1.4, yy - s * f], [xx - s * 0.5, yy], [xx, yy - s * 0.35], [xx + s * 0.5, yy], [xx + s * 1.4, yy - s * f]], INK, 1.6)
				_circle(x, xx, yy, s * 0.35, "#1a1020")
				x.fill_style = "#ff4a4a"
				x.fill_rect(xx - 0.6, yy - 0.4, 1.2, 1)
		"spider":
			x.glow(0, 0, 22, "#c8c8d8", 0.18)
			for i in 8:
				var a := i * PI / 4
				_line(x, [[0, 0], [cos(a) * (8 + e * 16), sin(a) * (8 + e * 16) * 0.7]], "rgba(235,235,245,.75)", 0.6)
			for r in [6, 11, 16]:
				_ring(x, r * (0.4 + e * 0.6), "rgba(235,235,245,.6)", 0.5, 0.7)
			var sy := -30 + e * 26
			_line(x, [[0, -34], [0, sy]], "rgba(235,235,245,.85)", 0.6)
			_circle(x, 0, sy + 3, 3.4, "#15101a")
			_circle(x, 0, sy - 0.8, 2.2, "#15101a")
			x.fill_style = "#b8261e"
			x.fill_rect(-1.2, sy + 2, 2.4, 2)
			for k in 4:
				var yy := sy + 1 + k * 1.2
				_line(x, [[-5, yy - 2], [-2, yy], [2, yy], [5, yy - 2]], "#15101a", 0.7)
		"souls":
			x.glow(0, 0, 30, "#40ff90", 0.35)
			for i in 3:
				var xx := (i - 1) * 9 + sin(p * 9 + i) * 2
				var yy := -e * (18 + i * 6) + 4
				var s := 4.5 - i * 0.6
				x.fill_style = "#d8ffe8"
				x.global_alpha = A0 * 0.85
				x.begin_path()
				x.arc(xx, yy - s * 0.4, s, PI, 0)
				x.line_to(xx + s, yy + s)
				x.line_to(xx + s * 0.4, yy + s * 0.6)
				x.line_to(xx - s * 0.2, yy + s)
				x.line_to(xx - s * 0.7, yy + s * 0.6)
				x.line_to(xx - s, yy + s)
				x.close_path()
				x.fill()
				x.fill_style = "#0e3a26"
				x.fill_rect(xx - s * 0.5, yy - s * 0.55, s * 0.3, s * 0.38)
				x.fill_rect(xx + s * 0.2, yy - s * 0.55, s * 0.3, s * 0.38)
		"rocketburst":
			x.glow(0, 0, 34, "#ff8a2a", 0.55)
			_ring(x, 6 + e * 22, "#ffb040", 1.6, 0.55)
			radial.call(10, func(xx, yy, a, i): _shard(x, xx, yy, (1 - p) * 5 + 1.2, "#ffd24a" if i % 2 else "#ff6a1a", a + PI / 2))
			for i in 4:
				var a := i * 1.6 + 0.4
				var r := e * 14
				x.global_alpha = A0 * 0.4
				_circle(x, cos(a) * r, sin(a) * r * 0.6 - e * 10, 4 + e * 6, "#5a5550" if i % 2 else "#7a746c")
			x.global_alpha = A0
			_star(x, 0, 0, 12 * (1 - p), "#fff4d0", p)
		"reticle":
			var r := 22 * (1 - e) + 6
			var rr := r * 0.55
			x.glow(0, 0, 20, "#ff4040", 0.25)
			_ring(x, r, "#ff4a4a", 1.4)
			_ring(x, r + 2.5, "#ffd0d0", 0.5)
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				_line(x, [[d[0] * rr, d[1] * rr], [d[0] * (r + 6), d[1] * (r + 6)]], "#ff4a4a", 1.3)
			_circle(x, 0, 0, 1.6, "#ff2a2a")
			_star(x, r * 0.7, -r * 0.7, 5 * (1 - p) + 1, "#ffffff", p * 2)
		"frag":
			x.glow(0, 0, 28, "#ffb040", 0.45 * (1 - p))
			_ring(x, 4 + e * 20, "#8a8680", 2, 0.5)
			radial.call(14, func(xx, yy, a, i):
				x.save()
				x.translate(xx * 1.2, yy * 1.2)
				x.rotate(a + p * 8)
				_path(x, [[0, -2.2], [1.9, 1.3], [-1.7, 1.5]], "#5a5e58" if i % 3 else "#9a9e96", INK, 0.4)
				x.restore())
			_star(x, 0, 0, 9 * (1 - p), "#fff0c0", 0)
		"salvage":
			x.glow(0, 0, 24, "#9fe8b0", 0.3)
			for i in 8:
				var a := -PI / 2 + (i - 3.5) * 0.42
				var r := 6 + e * 20
				x.save()
				x.translate(cos(a) * r, sin(a) * r + p * p * 16)
				x.rotate(p * 6 + i)
				if i % 3 == 0:
					x.fill_style = "#b8bcb4"
					x.stroke_style = INK
					x.line_width = 0.5
					x.begin_path()
					for k in 6:
						var aa := k * PI / 3
						if k:
							x.line_to(cos(aa) * 2.6, sin(aa) * 2.6)
						else:
							x.move_to(2.6, 0)
					x.close_path()
					x.fill()
					x.stroke()
					_circle(x, 0, 0, 1, "#2a2e2a")
				elif i % 3 == 1:
					_path(x, [[-2.4, -0.9], [2.4, -0.9], [2.4, 0.9], [-2.4, 0.9]], "#d8b25a")
				else:
					_path(x, [[-1.4, -1.4], [1.4, -1.4], [1.4, 1.4], [-1.4, 1.4]], "#8a8e86")
				x.restore()
			x.fill_style = "#8fe0a0"
			x.fill_rect(-1, -14 - e * 10, 2, 7)
			x.fill_rect(-3.5, -11.5 - e * 10, 7, 2)
		"hellportal":
			var open := minf(1, p / 0.18) if p < 0.72 else maxf(0, 1 - (p - 0.72) / 0.16)
			var R := 24 * open
			var fl := 0.42
			x.glow(0, 0, 34, "#ff3a0a", 0.55 * open + 0.1)
			x.save()
			x.scale(1, fl)
			_circle(x, 0, 0, R, "#0a0204")
			for i in 3:
				x.stroke_style = ["#ff3a0a", "#ff8a2a", "#7a0c06"][i]
				x.line_width = [2.6, 1.2, 1.6][i]
				x.begin_path()
				x.arc(0, 0, maxf(R * (1 - i * 0.22), 0.01), p * 9 + i * 2, p * 9 + i * 2 + 4.4)
				x.stroke()
			x.stroke_style = "#ffb040"
			x.line_width = 1.6
			x.begin_path()
			x.arc(0, 0, maxf(R, 0.01), 0, TAU)
			x.stroke()
			x.restore()
			if p < 0.7:
				var k := minf(1, p / 0.7)
				var h := 26 * (1 - k)
				var w := 6 * (1 - k * 0.4)
				x.save()
				x.begin_path()
				x.rect(-40, -60, 80, 60)
				x.clip()
				x.fill_style = "#120608"
				x.begin_path()
				x.ellipse(0, -h * 0.5 + k * 10, w, h * 0.5 + 2, 0, 0, TAU)
				x.fill()
				x.begin_path()
				x.arc(0, -h - 2 + k * 10, w * 0.75, 0, TAU)
				x.fill()
				x.restore()
			if open >= 0.05:
				for i in 10:
					var a := i * 0.63 + p * 3
					var r := R * (0.9 + 0.2 * sin(i + p * 20))
					_line(x, [[cos(a) * r, sin(a) * r * fl], [cos(a) * r * 1.15, sin(a) * r * fl - 4 - i % 3 * 2]], "#ff8a2a" if i % 2 else "#ffd070", 1.2)
			if p > 0.72:
				var k := (p - 0.72) / 0.28
				for i in 5:
					x.global_alpha = A0 / maxf(pop, 0.001) * (1 - k) * 0.45
					_circle(x, sin(i * 2.3) * 10 * k, -k * 18 - i * 3, 4 + k * 8, "#2a1a18")
				x.global_alpha = A0
				_star(x, 0, -2, 9 * (1 - k), "#ffe0a0", k)
		"orbital":
			var k := minf(1, p / 0.25)
			var b := 1.0 if p < 0.45 else maxf(0, 1 - (p - 0.45) / 0.3)
			var R := 6 + e * 22
			x.glow(0, 0, 30, "#ff6a2a", 0.5 * b + 0.1)
			x.global_alpha = A0 / maxf(pop, 0.001) * b
			x.fill_style = "rgba(255,140,80,.5)"
			x.fill_rect(-7 * k, -60, 14 * k, 60)
			x.fill_style = "#fff0e0"
			x.fill_rect(-3 * k, -60, 6 * k, 60)
			x.global_alpha = A0 / maxf(pop, 0.001)
			x.save()
			x.scale(1, 0.42)
			x.stroke_style = "#ff6a2a"
			x.line_width = 2
			x.begin_path()
			x.arc(0, 0, R, 0, TAU)
			x.stroke()
			x.stroke_style = "#ffffff"
			x.line_width = 1
			x.begin_path()
			x.arc(0, 0, R * 0.5, 0, TAU)
			x.stroke()
			x.restore()
			_star(x, 0, 0, 10 * (1 - p), "#fff0c0", 0)
		"cinder":
			x.glow(0, 0, 26, "#ff7a1a", 0.45)
			for i in 14:
				var a := i * 0.9 + 0.3
				var r := e * (8 + i % 4 * 5)
				var xx := cos(a) * r
				var yy := sin(a) * r * 0.6 - e * 10 + p * p * 16
				var s := (1 - p) * 2.6 + 0.8
				x.fill_style = mix("#ffd070", "#3a1a10", minf(1, p * 1.4 + (i % 3) * 0.1))
				x.fill_rect(xx - s / 2, yy - s / 2, s, s)
			_star(x, 0, 0, 8 * (1 - p), "#ffe0a0", p)
		"tealslash":
			x.glow(0, 0, 26, "#3ae0e0", 0.4 * (1 - p))
			var sw := -1.9 + p * 2.6
			for q in [[7, "rgba(40,200,220,.35)"], [3.4, "#5af0ff"], [1.2, "#eaffff"]]:
				x.stroke_style = q[1]
				x.line_width = q[0]
				x.begin_path()
				x.arc(0, -6, 20, sw, sw + 1.7)
				x.stroke()
			for i in 9:
				var a := sw + i * 0.19
				var r := 20 + sin(i * 3) * 3
				x.fill_style = "#b8fbff" if i % 2 else "#5af0ff"
				x.fill_rect(cos(a) * r - 1, sin(a) * r - 6 - 1 + p * 6, 2, 2)
		"ashbrand":
			var k := minf(1, p * 4)
			var R := 17 * k
			x.save()
			x.scale(1, 0.45)
			x.glow(0, 0, 28, "#ff4a0a", 0.5 * (1 - p) + 0.1)
			var sc := mix("#ffd070", "#5a1a0a", p)
			_ring(x, R, sc, 2)
			_ring(x, R * 0.72, sc, 1)
			x.begin_path()
			for i in 3:
				var a := -PI / 2 + i * TAU / 3
				x.line_to(cos(a) * R * 0.72, sin(a) * R * 0.72)
			x.close_path()
			x.stroke()
			for i in 6:
				var a := i * TAU / 6 + 0.5
				_line(x, [[cos(a) * R * 0.8, sin(a) * R * 0.8], [cos(a) * R * 0.95, sin(a) * R * 0.95]], sc, 1.6)
			x.restore()
			for i in 7:
				var xx := sin(i * 2.1) * 9
				var yy := -p * (18 + i * 4)
				var s := 1.6 + (i % 2)
				x.global_alpha = A0 * minf(1, p * 3) * 0.8
				x.fill_style = "#8a8480" if i % 2 else "#c8c0b8"
				x.fill_rect(xx, yy, s, s * 0.6)
			x.global_alpha = A0
		"demonclaw":
			var rise := minf(1, p / 0.35)
			var close := minf(1, (p - 0.35) / 0.35) if p > 0.35 else 0.0
			var sink := (p - 0.7) / 0.3 if p > 0.7 else 0.0
			x.glow(0, 0, 30, "#c8102e", 0.45)
			x.save()
			x.scale(1, 0.42)
			_circle(x, 0, 0, 22, "rgba(20,4,6,.75)")
			x.restore()
			for i in 4:
				var side := -1.0 if i < 2 else 1.0
				var off := (9.0 if i % 2 else 15.0) * side * (1 - close * 0.55)
				var h := 30 * rise * (1 - sink)
				var bend := side * (-6 - close * 6)
				x.fill_style = "#3a0a0e" if i % 2 else "#5a1016"
				x.stroke_style = INK
				x.line_width = 0.8
				x.begin_path()
				x.move_to(off - 2.6 * side, 2)
				x.quadratic_curve_to(off, -h * 0.6, off + bend, -h)
				x.quadratic_curve_to(off + 1.4 * side, -h * 0.55, off + 2.6 * side, 2)
				x.close_path()
				x.fill()
				x.stroke()
				_line(x, [[off, -h * 0.4], [off + bend * 0.7, -h * 0.9]], "#ff5a3a", 0.7)
		"bubbles":
			x.glow(0, 0, 33, gold, 0.3)
			for i in 9:
				var a := i * 2.4
				var r := e * (9 + i % 3 * 6)
				var xx := cos(a) * r
				var yy := sin(a) * r * 0.6 - e * (i % 4) * 6
				var rr := (3 + i % 4) * (1 - p * 0.3)
				x.fill_style = "rgba(255,214,92,.13)"
				x.stroke_style = "#ffe598"
				x.line_width = 0.9
				x.begin_path()
				x.arc(xx, yy, rr, 0, TAU)
				x.fill()
				x.stroke()
				x.stroke_style = "#a4faff" if i % 2 else "#ffb4dc"
				x.line_width = 0.5
				x.begin_path()
				x.arc(xx, yy, rr * 0.8, 0.3, 2)
				x.stroke()
				_line(x, [[xx - rr * 0.5, yy - rr * 0.25], [xx - rr * 0.25, yy - rr * 0.5]], "#fffce9", 1.2)
			for i in 4:
				_star(x, cos(i * 1.7) * e * 24, sin(i * 1.7) * e * 16, 2.2, "#fff1b6", p)
	x.restore()


static func _winter_finish(x: Ctx2D, n: int, p: float, s: float, X: float, Y: float) -> void:
	var e := 1 - pow(1 - p, 3)
	var fade := minf(1, minf(p * 12, (1 - p) * 3))
	var ice := "#d9f8ff"
	var gold := "#ffdc89"
	x.save()
	x.translate(X, Y)
	x.scale(s, s)
	x.global_alpha *= fade
	if n == 0:
		for i in 7:
			var a := i * 2.4
			_circle(x, cos(a) * e * 12, sin(a) * e * 7 - e * 8, 4 + e * 5, "#d9ecf2" if i % 2 else "#98bdcc")
	if n == 1 or n == 2:
		for i in 10:
			var a := i * PI / 5
			var r := 5 + e * 22
			x.save()
			x.translate(cos(a) * r, sin(a) * r + p * p * 10)
			x.rotate(a + p * 2)
			x.fill_style = ("#91d7eb" if i % 2 else ice) if n == 1 else ["#cf5364", "#d4b66b", "#7ca797"][i % 3]
			x.stroke_style = "#244957"
			x.line_width = 0.6
			x.begin_path()
			if n == 1:
				x.move_to(0, -5)
				x.line_to(2, 0)
				x.line_to(0, 5)
				x.line_to(-2, 0)
			else:
				x.arc(0, 0, 3, 0, TAU)
			x.close_path()
			x.fill()
			x.stroke()
			x.fill_style = "#effaff"
			x.fill_rect(-1, -3, 1, 2)
			x.restore()
	if n >= 3:
		var r := 31 * (1 - e) + e * 12 if n == 4 else 6 + e * 29
		x.glow(0, 0, 35, gold if n == 5 else "#92e8dc", 0.25)
		winter_flake(x, 0, 0, r, gold if n == 5 else ice, p * 0.4)
		x.stroke_style = gold if n == 5 else "#89dfdb"
		x.line_width = 1.2
		x.begin_path()
		x.ellipse(0, 0, 5 + e * 29, (5 + e * 29) * 0.55, 0, 0, TAU)
		x.stroke()
		if n == 4:
			for j in 3:
				x.stroke_style = ["#93efd5", "#ae96ee", "#8ecde9"][j]
				x.begin_path()
				x.ellipse(0, 0, 11 + e * 17, 5 + e * 7, p * 3 + j, 0, PI * 1.65)
				x.stroke()
		for i in 8:
			var a := i * PI / 4 + 0.2
			var rr := 10 + e * 29
			winter_flake(x, cos(a) * rr, sin(a) * rr, 2 + (1 - p) * 3, ((ice if i % 2 else gold) if n == 5 else ice), a)
	x.restore()


static func _block(x: Ctx2D, txt: String, xx: float, yy: float, size: float, col, rot: float = 0.0) -> void:
	x.save()
	x.translate(xx, yy)
	x.rotate(rot)
	x.font = "900 %dpx \"Big Shoulders Stencil Display\", sans-serif" % maxi(1, roundi(size))
	x.text_align = "center"
	x.text_baseline = "middle"
	x.line_width = size * 0.18
	x.stroke_style = INK
	x.stroke_text(txt, 0, 0)
	x.fill_style = col
	x.fill_text(txt, 0, 0)
	x.restore()


static func _hybrid_finish(x: Ctx2D, key: String, p: float, s: float, X: float, Y: float) -> void:
	var e := 1 - pow(1 - p, 3)
	var fade := minf(1, minf(p * 12, (1 - p) * 3))
	x.save()
	x.translate(X, Y)
	x.scale(s, s)
	x.global_alpha *= fade
	var A0 := x.global_alpha
	x.line_join = "round"
	x.line_cap = "round"
	var ground := func(col: String, r: float) -> void:
		x.global_alpha *= 0.35
		x.fill_style = col
		x.begin_path()
		x.ellipse(0, 6, r, r * 0.35, 0, 0, TAU)
		x.fill()
		x.global_alpha /= 0.35
	match key:
		"leaf":
			ground.call("#3FAE49", 8 + e * 10)
			for i in 8:
				var a := i * TAU / 8 + 0.3
				var r := 4 + e * 18
				x.save()
				x.translate(cos(a) * r, sin(a) * r * 0.6 - e * 10 + p * p * 14)
				x.rotate(a + p * 3)
				x.fill_style = "#C1D32F" if i % 2 else "#3FAE49"
				x.stroke_style = "#1f5a26"
				x.line_width = 0.6
				for k in range(-2, 3):
					x.save()
					x.rotate(k * 0.42)
					x.begin_path()
					x.ellipse(0, -3.2, 1.1, 3.4, 0, 0, TAU)
					x.fill()
					x.stroke()
					x.restore()
				x.restore()
		"bands":
			ground.call("#85BB65", 8 + e * 8)
			for i in 9:
				var a := i * TAU / 9
				var r := 3 + e * 17
				x.save()
				x.translate(cos(a) * r + sin(p * 9 + i) * 2, sin(a) * r * 0.5 - e * 14 + p * p * 22)
				x.rotate(sin(p * 7 + i) * 0.8)
				if i % 3 == 2:
					_circle(x, 0, 0, 2.2, "#FDB927")
					x.stroke_style = "#8a6410"
					x.line_width = 0.5
					x.stroke()
				else:
					x.fill_style = "#85BB65"
					x.fill_rect(-4, -2.2, 8, 4.4)
					x.stroke_style = "#2f5a22"
					x.line_width = 0.6
					x.stroke_rect(-4, -2.2, 8, 4.4)
					_circle(x, 0, 0, 1.1, "#d8edc8")
				x.restore()
		"swish":
			var rimY := -22.0
			x.stroke_style = "#F58426"
			x.line_width = 2
			x.begin_path()
			x.ellipse(0, rimY, 9, 3, 0, 0, TAU)
			x.stroke()
			var kick := sin((p - 0.45) / 0.25 * PI) * 2 if p > 0.45 and p < 0.7 else 0.0
			x.stroke_style = "#ffffff"
			x.line_width = 0.7
			for i in range(-3, 4):
				x.begin_path()
				x.move_to(i * 2.6, rimY + 1)
				x.line_to(i * 1.4 + (kick if i % 2 else -kick), rimY + 11 + kick)
				x.stroke()
			for j in range(1, 3):
				x.begin_path()
				x.ellipse(0, rimY + j * 4, 9 - j * 2, 2.4 - j * 0.5, 0, 0, TAU)
				x.stroke()
			var by := -40 + minf(1, p * 1.6) * 44
			_circle(x, 0, by, 4.2, "#e8702a")
			x.stroke_style = INK
			x.line_width = 0.7
			x.begin_path()
			x.arc(0, by, 4.2, 0, TAU)
			x.move_to(-4.2, by)
			x.line_to(4.2, by)
			x.move_to(0, by - 4.2)
			x.line_to(0, by + 4.2)
			x.stroke()
			ground.call("#F58426", 6 + e * 6)
		"nuke":
			if p < 0.18:
				x.global_alpha *= 1 - p / 0.18
				_circle(x, 0, -6, 30 * (p / 0.18 + 0.2), "#ffffff")
				x.global_alpha = A0
			ground.call("#9a9a9a", 10 + e * 22)
			x.stroke_style = "#bfbfbf"
			x.line_width = 2
			x.global_alpha *= 0.7
			x.begin_path()
			x.ellipse(0, 6, 8 + e * 26, (8 + e * 26) * 0.35, 0, 0, TAU)
			x.stroke()
			x.global_alpha = A0
			var top := -10 - e * 22
			x.fill_style = "#b55a22"
			x.fill_rect(-3, top + 6, 6, 16 + e * 4)
			_circle(x, 0, top, 9 + e * 5, "#EF3B24")
			_circle(x, -6, top + 2, 6 + e * 3, "#f26a2a")
			_circle(x, 6, top + 2, 6 + e * 3, "#f26a2a")
			_circle(x, 0, top - 3, 6 + e * 3, "#ffb04a")
		"poop":
			ground.call("#6B4A32", 7 + e * 7)
			var yy := -6 - e * 6
			for k in 3:
				x.fill_style = "#7d5a3e" if k % 2 else "#6B4A32"
				x.begin_path()
				x.ellipse(0, yy - k * 4, 7 - k * 2, 3, 0, 0, TAU)
				x.fill()
				x.stroke_style = "#3e2a1c"
				x.line_width = 0.6
				x.stroke()
			for i in 4:
				var a := i * TAU / 4 + p * 2
				var r := 8 + e * 10
				x.global_alpha = A0 * 0.5
				_circle(x, cos(a) * r, yy - 8 - e * 10 + sin(a) * 3, 2 + e * 2, "#9fb35a")
		"demon":
			ground.call("#552583", 9 + e * 9)
			x.stroke_style = "#ff8a2a"
			x.line_width = 1.4
			for i in 10:
				var a := i * TAU / 10
				var r := 9 + e * 7
				var h := 3 + sin(p * 14 + i) * 1.5
				x.begin_path()
				x.move_to(cos(a) * r, 6 + sin(a) * r * 0.35)
				x.line_to(cos(a) * r, 6 + sin(a) * r * 0.35 - h)
				x.stroke()
			var yy := -14 - e * 6
			for sd in [-1, 1]:
				x.fill_style = "#552583"
				x.stroke_style = INK
				x.line_width = 0.7
				x.begin_path()
				x.move_to(sd * 4, yy)
				x.quadratic_curve_to(sd * 9, yy - 4, sd * 8, yy - 11)
				x.line_to(sd * 6, yy - 2)
				x.close_path()
				x.fill()
				x.stroke()
				_circle(x, sd * 3, yy + 5, 1.6, "#c7a0ff")
		"hundo":
			for i in 3:
				var a := i * TAU / 3 + 0.5
				var r := e * 14 * (1 if i else 0)
				var k := 0.6 + e * 0.7
				x.global_alpha = A0 * (1 - i * 0.15)
				_block(x, "100", cos(a) * r, -12 - e * 8 + sin(a) * r * 0.5, 9 * k, "#ffffff", sin(a) * 0.3)
		"fire":
			ground.call("#ff6a1a", 7 + e * 7)
			for i in 6:
				var xx := (i - 2.5) * 3.2
				var h := 6 + e * 14 * (1 - absf(i - 2.5) / 3.5) + sin(p * 20 + i) * 2
				x.fill_style = "#ffd24a" if i % 2 else "#ff7a1a"
				x.begin_path()
				x.move_to(xx - 2.4, 4)
				x.quadratic_curve_to(xx - 1.6, 4 - h * 0.6, xx, 4 - h)
				x.quadratic_curve_to(xx + 1.6, 4 - h * 0.6, xx + 2.4, 4)
				x.close_path()
				x.fill()
			if p > 0.5:
				for i in 5:
					var a := i * 1.3
					var r := (p - 0.5) * 30
					_circle(x, cos(a) * r * 0.5, -4 - r + sin(a) * 2, 1, "#ffb04a")
		"eight":
			if p < 0.65:
				var k := minf(1, p * 5)
				_circle(x, -5 * k, -8, 3.2 * k, "#e8b48c")
				_circle(x, 5 * k, -8, 3.2 * k, "#e8b48c")
				x.fill_style = "#e8b48c"
				x.stroke_style = INK
				x.line_width = 0.8
				x.fill_rect(-2.4 * k, -24 * k - 6, 4.8 * k, 18 * k)
				x.stroke_rect(-2.4 * k, -24 * k - 6, 4.8 * k, 18 * k)
				_circle(x, 0, -24 * k - 6, 2.6 * k, "#e8b48c")
			else:
				x.global_alpha = A0 * (0.4 + 0.6 * (1 - (p - 0.65) / 0.35))
				_circle(x, 0, -12, 8 + (p - 0.65) * 40, "#ffffff")
				ground.call("#e8b48c", 10)
		"sixty":
			var crack := (p - 0.6) / 0.4 if p > 0.6 else 0.0
			_block(x, "6", -6 - crack * 6, -14 - e * 6 + crack * 8, 16, "#ffffff", -crack * 0.5)
			_block(x, "7", 6 + crack * 6, -14 - e * 6 + crack * 8, 16, "#C1D32F", crack * 0.5)
			if crack > 0:
				x.stroke_style = INK
				x.line_width = 0.8
				x.begin_path()
				x.move_to(-8, -22)
				x.line_to(-5, -15)
				x.line_to(-8, -9)
				x.move_to(6, -22)
				x.line_to(9, -15)
				x.line_to(5, -9)
				x.stroke()
		"zzz":
			ground.call("#7BA3C9", 8)
			x.fill_style = "#d9d4c4"
			x.fill_rect(-9, -2, 18, 5)
			x.fill_style = "#7BA3C9"
			x.fill_rect(-9, -4, 7, 3)
			x.fill_style = "#5b4a3a"
			x.fill_rect(-10, -5, 2, 9)
			x.fill_rect(8, -2, 2, 6)
			for i in 3:
				var q := clampf(p * 1.6 - i * 0.25, 0, 1)
				if q <= 0:
					continue
				x.global_alpha = A0 * (1 - q * 0.6)
				_block(x, "Z", 4 + i * 4 + q * 4, -8 - q * 18 - i * 3, 7 + i * 2, "#cfe2f2")
	x.restore()


# ---------------------------------------------------------------- particles

const SPARKLE := ["star", "cosmic", "goldsp", "glint", "ice", "rock", "confetti", "pix", "glitch", "nova", "grad1", "grad2", "neon", "spark", "ember", "bolt"]


## the cosmetic particle kinds (paintSceneParticle / paintCosmeticParticle): false when q is not one of them
static func paint_particle(x: Ctx2D, q: Dictionary, px: float, py: float, u: float, time: float) -> bool:
	var a := maxf(0, q.life / q.max)
	var k: String = q.kind
	match k:
		"bubble":
			var r: float = q.size * u * (1.25 - a * 0.25)
			var cx: float = px + sin(time * 4 + q.h) * 2 * u
			x.save()
			x.global_alpha *= minf(1, a * 1.8)
			x.fill_style = "rgba(255,226,130,.16)"
			x.begin_path()
			x.arc(cx, py, r, 0, TAU)
			x.fill()
			x.line_width = 1.3 * u
			x.stroke_style = "#ffd24a"
			x.stroke()
			x.line_width = 0.8 * u
			x.stroke_style = CosFx.hsl(fmod(time * 220 + q.h, 360), 0.95, 0.78)
			x.begin_path()
			x.arc(cx, py, r * 0.8, -2.4, -0.6)
			x.stroke()
			x.fill_style = "#fffbe8"
			x.fill_rect(cx - r * 0.45, py - r * 0.55, 1.4 * u, 1.4 * u)
			x.restore()
			return true
		"bat":
			var s: float = q.size * u
			var f: float = sin(time * 34 + q.h) * 0.9
			x.save()
			x.global_alpha *= minf(1, a * 2)
			x.stroke_style = "#120c16"
			x.line_width = 1.3 * u
			x.begin_path()
			x.move_to(px - s * 1.3, py - s * f * 0.8)
			x.line_to(px - s * 0.5, py - s * 0.1)
			x.line_to(px, py - s * 0.3)
			x.line_to(px + s * 0.5, py - s * 0.1)
			x.line_to(px + s * 1.3, py - s * f * 0.8)
			x.stroke()
			_circle(x, px, py, s * 0.32, "#120c16")
			x.fill_style = "#ff3a3a"
			x.fill_rect(px - s * 0.2, py - s * 0.12, u * 0.8, u * 0.8)
			x.restore()
			return true
		"spider":   # q.top: where its thread hangs from on screen
			var s: float = q.size * u
			var sw: float = sin(time * 3 + q.h) * 1.5 * u
			x.save()
			x.global_alpha *= minf(1, a * 2.5)
			x.stroke_style = "rgba(235,235,245,.8)"
			x.line_width = 0.7 * u
			x.begin_path()
			x.move_to(px, q.get("top", py - 60 * u))
			x.line_to(px + sw, py - s)
			x.stroke()
			x.stroke_style = "#15101a"
			x.line_width = 0.9 * u
			for kk in 4:
				var yy := py - s * 0.4 + kk * s * 0.35
				var wv := sin(time * 12 + kk) * s * 0.15
				x.begin_path()
				x.move_to(px + sw - s * 1.5, yy - s * 0.5 + wv)
				x.line_to(px + sw - s * 0.8, yy - s * 0.9)
				x.line_to(px + sw, yy)
				x.line_to(px + sw + s * 0.8, yy - s * 0.9)
				x.line_to(px + sw + s * 1.5, yy - s * 0.5 - wv)
				x.stroke()
			_circle(x, px + sw, py, s * 0.75, "#15101a")
			_circle(x, px + sw, py - s * 0.8, s * 0.45, "#15101a")
			x.fill_style = "#b8261e"
			x.fill_rect(px + sw - s * 0.3, py - s * 0.1, s * 0.6, s * 0.5)
			x.restore()
			return true
		"soul":
			var cx: float = px + sin(time * 2.4 + q.h) * 3 * u
			var s: float = q.size * u
			x.save()
			x.global_alpha *= minf(0.85, a * 1.4)
			x.fill_style = "#d8ffe8"
			x.begin_path()
			x.arc(cx, py - s * 0.4, s, PI, 0)
			x.line_to(cx + s, py + s * 0.9)
			for kk in range(3, -1, -1):
				var xx := cx - s + kk * s * 0.5
				var yy := py + s * 0.9 + (s * 0.35 if (kk + floori(time * 8)) % 2 else 0.0)
				x.line_to(xx + s * 0.5, yy)
				x.line_to(xx, py + s * 0.9)
			x.close_path()
			x.fill()
			x.fill_style = "#0e3a26"
			x.fill_rect(cx - s * 0.5, py - s * 0.55, s * 0.3, s * 0.38)
			x.fill_rect(cx + s * 0.2, py - s * 0.55, s * 0.3, s * 0.38)
			x.restore()
			return true
	var r: float = q.size * u
	var col = mix(q.c1, q.c2, roundf((1 - a) * 16) / 16) if q.has("c1") else q.col
	if k == "snowdust" or k == "yulelight" or k == "flagmote":
		x.save()
		x.global_alpha *= a
		x.fill_style = col
		x.stroke_style = "#a6aaa5" if col is String and (col == "#000000" or col == "#2c2c2c") else "#293a35"
		x.line_width = maxf(0.35, u * 0.35)
		x.begin_path()
		x.ellipse(px, py, r * 0.7, r * (1.0 if k == "yulelight" else 0.7), 0, 0, TAU)
		x.fill()
		if k != "snowdust":
			x.stroke()
		if k == "yulelight":
			x.fill_style = "#5c785d"
			x.fill_rect(px - r * 0.35, py - r * 1.4, r * 0.7, r * 0.45)
		x.restore()
		return true
	if k == "rune":
		x.save()
		x.global_alpha *= minf(1, a * 1.6)
		x.translate(px, py)
		x.rotate(q.get("h", 0.0))
		x.glow(0, 0, r * 2.4, "#ff5a1a", 0.5)
		x.stroke_style = "#ffe0a0" if a > 0.5 else "#ff7a2a"
		x.line_width = maxf(0.6, r * 0.28)
		x.begin_path()
		x.arc(0, 0, r, 0, TAU)
		x.move_to(0, -r)
		x.line_to(r * 0.62, r * 0.5)
		x.line_to(-r * 0.62, r * 0.5)
		x.close_path()
		x.stroke()
		x.restore()
		return true
	if not (k in SPARKLE):
		return false
	x.save()
	x.global_alpha *= minf(1, a * 1.5)
	x.translate(px, py)
	x.fill_style = col
	x.stroke_style = "#101810"
	x.line_width = maxf(0.35, u * 0.3)
	x.line_join = "round"
	if k == "spark" or k == "ember" or k == "bolt":
		x.stroke_style = col
		x.line_width = maxf(0.7, r * 0.55)
		x.begin_path()
		x.move_to(0, 0)
		x.line_to(-q.vx * u * 0.65, q.vz * u * 0.025)
		x.stroke()
		x.fill_style = "#fff4d6"
		x.fill_rect(-r * 0.16, -r * 0.16, r * 0.32, r * 0.32)
	elif k == "confetti" or k == "glitch" or k == "pix":
		x.rotate((q.x + q.y) * 5 + (1 - a) * 4)
		var w := r * 2 if k == "glitch" else r
		x.fill_rect(-w / 2, -r / 2, w, r)
		x.stroke_rect(-w / 2, -r / 2, w, r)
		x.fill_style = "#ffffff"
		x.global_alpha *= 0.45
		x.fill_rect(-w / 2, -r / 2, w, 0.5 * u)
	else:
		var star: bool = k in ["star", "cosmic", "goldsp", "glint", "nova"]
		x.rotate((q.x + q.y) * 3 + time * 0.7)
		x.begin_path()
		if star:
			for i in 8:
				var ang := i * PI / 4
				var rr := r * 0.25 if i % 2 else r
				if i:
					x.line_to(cos(ang) * rr, sin(ang) * rr)
				else:
					x.move_to(rr, 0)
		else:
			x.move_to(0, -r * 1.25)
			x.line_to(r * 0.65, 0)
			x.line_to(0, r)
			x.line_to(-r * 0.55, 0)
		x.close_path()
		x.fill()
		x.stroke()
		x.fill_style = "#f8ffed"
		x.fill_rect(-r * 0.12, -r * 0.12, r * 0.24, r * 0.24)
	x.restore()
	return true
