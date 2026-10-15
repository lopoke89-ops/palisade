class_name Ctx2D
extends RefCounted
## A small HTML canvas 2D context over a Godot CanvasItem, so the browser's procedural cosmetic art (backgrounds,
## tracers, kill effects) ports nearly line for line. Paths (lines, arcs, ellipses, quadratic and cubic curves, arcTo),
## fill and stroke with colours or linear/radial gradients (sampled from cached gradient textures, so they are exact
## per pixel), save/restore, translate/rotate/scale, rectangular or path clips, dashes, text, and a soft stand-in for
## shadowBlur. 'lighter' compositing goes to add_cv (an additive layer) when one is given.
##   var x := Ctx2D.new(canvas_item)      # draws in the item's local coordinates
##   x.fill_style = "#ffcc00"; x.fill_rect(0, 0, 20, 10)

var cv: CanvasItem
var add_cv: CanvasItem   # where 'lighter' draws go (an additive-blend item); null draws them normally
var fill_style = Color.BLACK   # Color, a CSS colour string or a Grad
var stroke_style = Color.BLACK
var line_width := 1.0
var line_cap := "butt"
var line_join := "miter"
var global_alpha := 1.0
var composite := "source-over"
var shadow_blur := 0.0
var shadow_color = Color(0, 0, 0, 0)
var font := "10px sans-serif"
var text_align := "left"
var text_baseline := "alphabetic"
var xf := Transform2D.IDENTITY
var clip_polys: Array = []   # device-space polygons every fill and stroke is cut to (empty: no clip)
var dash := PackedFloat32Array()

var _subs: Array = []   # [PackedVector2Array (device space), closed]
var _cur := PackedVector2Array()
var _closed := false
var _stack: Array = []

static var _tex_cache := {}
static var _fonts := {}


class Grad:
	var kind := "linear"
	var p0 := Vector2.ZERO
	var p1 := Vector2.ZERO
	var r0 := 0.0
	var r1 := 0.0
	var stops: Array = []   # [offset, Color], in the order added

	func add_color_stop(o: float, c) -> void:
		stops.append([clampf(o, 0, 1), CosFx.col(c)])

	## the colour at t (0..1 along the gradient)
	func at(t: float) -> Color:
		if stops.is_empty():
			return Color(0, 0, 0, 0)
		var s: Array = stops.duplicate()
		s.sort_custom(func(a, b): return a[0] < b[0])
		if t <= s[0][0]:
			return s[0][1]
		for i in range(1, s.size()):
			if t <= s[i][0]:
				var span: float = s[i][0] - s[i - 1][0]
				return s[i - 1][1] if span <= 0 else s[i - 1][1].lerp(s[i][1], (t - s[i - 1][0]) / span)
		return s[-1][1]

	func key() -> String:
		var k := kind
		if kind == "radial":
			k += ":%.4f" % (r0 / r1 if r1 > 0 else 0.0)
		for s in stops:
			k += "|%.4f,%s" % [s[0], s[1].to_html()]
		return k


func _init(item: CanvasItem = null, additive: CanvasItem = null) -> void:
	cv = item
	add_cv = additive


# ---------------------------------------------------------------- state

func save() -> void:
	_stack.append({"fill_style": fill_style, "stroke_style": stroke_style, "line_width": line_width, "line_cap": line_cap, "line_join": line_join,
		"global_alpha": global_alpha, "composite": composite, "shadow_blur": shadow_blur, "shadow_color": shadow_color, "font": font,
		"text_align": text_align, "text_baseline": text_baseline, "xf": xf, "clip_polys": clip_polys, "dash": dash})


func restore() -> void:
	if _stack.is_empty():
		return
	var s: Dictionary = _stack.pop_back()
	for k in s:
		set(k, s[k])


func translate(x: float, y: float) -> void:
	xf = xf * Transform2D(0, Vector2(x, y))


func rotate(a: float) -> void:
	xf = xf * Transform2D(a, Vector2.ZERO)


func scale(x: float, y: float) -> void:
	xf = xf * Transform2D(0, Vector2(x, y), 0, Vector2.ZERO)


## canvas setTransform(a, b, c, d, e, f)
func set_transform(a: float, b: float, c: float, d: float, e: float, f: float) -> void:
	xf = Transform2D(Vector2(a, b), Vector2(c, d), Vector2(e, f))


func set_line_dash(d: Array) -> void:
	dash = PackedFloat32Array(d)


func create_linear_gradient(x0: float, y0: float, x1: float, y1: float) -> Grad:
	var g := Grad.new()
	g.p0 = Vector2(x0, y0)
	g.p1 = Vector2(x1, y1)
	return g


func create_radial_gradient(x0: float, y0: float, r0: float, x1: float, y1: float, r1: float) -> Grad:
	var g := Grad.new()
	g.kind = "radial"
	g.p0 = Vector2(x0, y0)
	g.p1 = Vector2(x1, y1)
	g.r0 = r0
	g.r1 = r1
	return g


# ---------------------------------------------------------------- paths

func begin_path() -> void:
	_subs = []
	_cur = PackedVector2Array()
	_closed = false


func _flush() -> void:
	if _cur.size() > 0:
		_subs.append([_cur, _closed])
	_cur = PackedVector2Array()
	_closed = false


func move_to(x: float, y: float) -> void:
	_flush()
	_cur.append(xf * Vector2(x, y))


func line_to(x: float, y: float) -> void:
	if _closed:
		var start := _cur[0]
		_flush()
		_cur.append(start)
	_cur.append(xf * Vector2(x, y))


func close_path() -> void:
	if _cur.size() > 0:
		_closed = true


func _segs(len_px: float) -> int:
	return clampi(int(len_px / 3.0), 4, 48)


func quadratic_curve_to(cx: float, cy: float, x: float, y: float) -> void:
	if _cur.is_empty():
		move_to(cx, cy)
	var a := _cur[-1]
	var c := xf * Vector2(cx, cy)
	var b := xf * Vector2(x, y)
	var n := _segs(a.distance_to(c) + c.distance_to(b))
	for i in range(1, n + 1):
		var t := float(i) / n
		_cur.append(a.lerp(c, t).lerp(c.lerp(b, t), t))


func bezier_curve_to(c1x: float, c1y: float, c2x: float, c2y: float, x: float, y: float) -> void:
	if _cur.is_empty():
		move_to(c1x, c1y)
	var a := _cur[-1]
	var c1 := xf * Vector2(c1x, c1y)
	var c2 := xf * Vector2(c2x, c2y)
	var b := xf * Vector2(x, y)
	var n := _segs(a.distance_to(c1) + c1.distance_to(c2) + c2.distance_to(b))
	for i in range(1, n + 1):
		var t := float(i) / n
		_cur.append(a.bezier_interpolate(c1, c2, b, t))


## an elliptical arc in user space (canvas arc/ellipse), joined to the current point by a line
func ellipse(cx: float, cy: float, rx: float, ry: float, rot: float, a0: float, a1: float, ccw: bool = false) -> void:
	var sweep := a1 - a0
	if not ccw:
		if sweep >= TAU:
			sweep = TAU
		else:
			sweep = fposmod(sweep, TAU)
			if sweep == 0 and a1 != a0:
				sweep = TAU
	else:
		if -sweep >= TAU:
			sweep = -TAU
		else:
			sweep = -fposmod(-sweep, TAU)
			if sweep == 0 and a1 != a0:
				sweep = -TAU
	var sc := (xf.x.length() + xf.y.length()) / 2
	var n := clampi(int(absf(sweep) * maxf(rx, ry) * sc / 2.5), 6, 96)
	var cr := cos(rot)
	var sr := sin(rot)
	for i in n + 1:
		var a := a0 + sweep * i / n
		var px := cos(a) * rx
		var py := sin(a) * ry
		var p := xf * Vector2(cx + px * cr - py * sr, cy + px * sr + py * cr)
		if i == 0 and _cur.is_empty():
			_cur.append(p)
		elif i == 0:
			if _closed:
				var start := _cur[0]
				_flush()
				_cur.append(start)
			_cur.append(p)
		else:
			_cur.append(p)


func arc(cx: float, cy: float, r: float, a0: float, a1: float, ccw: bool = false) -> void:
	ellipse(cx, cy, r, r, 0, a0, a1, ccw)


func arc_to(x1: float, y1: float, x2: float, y2: float, r: float) -> void:
	if _cur.is_empty():
		move_to(x1, y1)
	var inv := xf.affine_inverse()
	var p0: Vector2 = inv * _cur[-1]
	var p1 := Vector2(x1, y1)
	var p2 := Vector2(x2, y2)
	var d0 := (p0 - p1).normalized()
	var d2 := (p2 - p1).normalized()
	var ang := d0.angle_to(d2)
	if r == 0 or absf(sin(ang)) < 1e-6:
		line_to(x1, y1)
		return
	var t := r / tan(absf(ang) / 2)
	var s0 := p1 + d0 * t
	var s2 := p1 + d2 * t
	var bis := (d0 + d2).normalized()
	var c := p1 + bis * (r / sin(absf(ang) / 2))
	line_to(s0.x, s0.y)
	var a0 := (s0 - c).angle()
	var a1 := (s2 - c).angle()
	var ccw := fposmod(a1 - a0, TAU) > PI
	ellipse(c.x, c.y, r, r, 0, a0, a1, ccw)


func rect(x: float, y: float, w: float, h: float) -> void:
	_flush()
	_cur = PackedVector2Array([xf * Vector2(x, y), xf * Vector2(x + w, y), xf * Vector2(x + w, y + h), xf * Vector2(x, y + h)])
	_closed = true
	_flush()


func round_rect(x: float, y: float, w: float, h: float, r: float) -> void:
	r = minf(r, minf(w, h) / 2)
	move_to(x + r, y)
	arc_to(x + w, y, x + w, y + h, r)
	arc_to(x + w, y + h, x, y + h, r)
	arc_to(x, y + h, x, y, r)
	arc_to(x, y, x + w, y, r)
	close_path()


func _all() -> Array:
	var out: Array = _subs.duplicate()
	if _cur.size() > 0:
		out.append([_cur, _closed])
	return out


## cut later drawing to the current path
func clip() -> void:
	var polys: Array = []
	for s in _all():
		if s[0].size() >= 3:
			polys.append(s[0])
	if clip_polys.is_empty():
		clip_polys = polys
	else:
		var out: Array = []
		for a in clip_polys:
			for b in polys:
				out.append_array(Geometry2D.intersect_polygons(a, b))
		clip_polys = out


# ---------------------------------------------------------------- painting

func _target() -> CanvasItem:
	return add_cv if composite == "lighter" and add_cv != null else cv


func _solid(style) -> Color:
	var k: Color = CosFx.col(style) if not (style is Grad) else Color.WHITE
	k.a *= global_alpha
	return k


func _grad_tex(g: Grad) -> Texture2D:
	var key := g.key()
	if _tex_cache.has(key):
		return _tex_cache[key]
	var gr := Gradient.new()
	var s: Array = g.stops.duplicate()
	s.sort_custom(func(a, b): return a[0] < b[0])
	if s.is_empty():
		s = [[0.0, Color(0, 0, 0, 0)]]
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for st in s:
		var o: float = st[0]
		if g.kind == "radial" and g.r1 > 0:
			o = (g.r0 + o * (g.r1 - g.r0)) / g.r1
		offs.append(o)
		cols.append(st[1])
	if g.kind == "radial" and g.r0 > 0:   # inside r0 the first stop holds
		offs.insert(0, 0.0)
		cols.insert(0, cols[0])
	gr.offsets = offs
	gr.colors = cols
	var t := GradientTexture2D.new()
	t.gradient = gr
	if g.kind == "radial":
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
	else:
		t.fill_from = Vector2(0, 0)
		t.fill_to = Vector2(1, 0)
		t.width = 256
		t.height = 1
	if _tex_cache.size() > 256:
		_tex_cache.clear()
	_tex_cache[key] = t
	return t


## UVs into the gradient's texture for device-space points
func _grad_uv(g: Grad, pts: PackedVector2Array) -> PackedVector2Array:
	var inv := xf.affine_inverse()
	var uv := PackedVector2Array()
	if g.kind == "radial":
		var r: float = maxf(g.r1, 0.0001)
		for p in pts:
			var q: Vector2 = inv * p
			uv.append(Vector2(0.5, 0.5) + (q - g.p1) / (2 * r))
	else:
		var d := g.p1 - g.p0
		var l2 := maxf(d.length_squared(), 1e-9)
		for p in pts:
			var q: Vector2 = inv * p
			uv.append(Vector2(clampf((q - g.p0).dot(d) / l2, 0.002, 0.998), 0.5))
	return uv


func _tris(pts: PackedVector2Array) -> PackedInt32Array:
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty() and pts.size() >= 3:
		for i in range(1, pts.size() - 1):
			idx.append_array([0, i, i + 1])
	return idx


func _fill_poly(target: CanvasItem, pts: PackedVector2Array, style) -> void:
	if pts.size() < 3:
		return
	var idx := _tris(pts)
	if idx.is_empty():
		return
	var rid := target.get_canvas_item()
	if style is Grad:
		var uv := _grad_uv(style, pts)
		var cols := PackedColorArray()
		cols.resize(pts.size())
		cols.fill(Color(1, 1, 1, global_alpha))
		RenderingServer.canvas_item_add_triangle_array(rid, idx, pts, cols, uv, PackedInt32Array(), PackedFloat32Array(), _grad_tex(style).get_rid())
	else:
		var k := _solid(style)
		if k.a <= 0.002:
			return
		var cols := PackedColorArray()
		cols.resize(pts.size())
		cols.fill(k)
		RenderingServer.canvas_item_add_triangle_array(rid, idx, pts, cols)


func _clipped(pts: PackedVector2Array) -> Array:
	if clip_polys.is_empty():
		return [pts]
	var out: Array = []
	for c in clip_polys:
		out.append_array(Geometry2D.intersect_polygons(pts, c))
	return out


func _shadow_fill(target: CanvasItem, pts: PackedVector2Array) -> void:
	var sc := CosFx.col(shadow_color)
	if shadow_blur <= 0 or sc.a <= 0:
		return
	var b := shadow_blur * 0.5
	for g in [[b, 0.22], [b * 0.45, 0.32]]:
		for q in Geometry2D.offset_polygon(pts, g[0], Geometry2D.JOIN_ROUND):
			_fill_poly(target, q, Color(sc, sc.a * g[1]))


func fill(style = null) -> void:
	var st = fill_style if style == null else style
	var target := _target()
	for s in _all():
		for pts in _clipped(s[0]):
			_shadow_fill(target, pts)
			_fill_poly(target, pts, st)


func fill_rect(x: float, y: float, w: float, h: float) -> void:
	var pts := PackedVector2Array([xf * Vector2(x, y), xf * Vector2(x + w, y), xf * Vector2(x + w, y + h), xf * Vector2(x, y + h)])
	var target := _target()
	for q in _clipped(pts):
		_shadow_fill(target, q)
		_fill_poly(target, q, fill_style)


func stroke_rect(x: float, y: float, w: float, h: float) -> void:
	var keep := [_subs, _cur, _closed]
	begin_path()
	rect(x, y, w, h)
	stroke()
	_subs = keep[0]
	_cur = keep[1]
	_closed = keep[2]


func clear_rect(_x: float, _y: float, _w: float, _h: float) -> void:
	pass   # every surface here is drawn fresh each time


func _dashed(pts: PackedVector2Array) -> Array:
	if dash.is_empty():
		return [pts]
	var sc := (xf.x.length() + xf.y.length()) / 2
	var out: Array = []
	var di := 0
	var left := dash[0] * sc
	var on := true
	var cur := PackedVector2Array([pts[0]])
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var l := a.distance_to(b)
		var pos := 0.0
		while l - pos > left:
			pos += left
			var p := a.lerp(b, pos / l)
			if on:
				cur.append(p)
				out.append(cur)
			cur = PackedVector2Array([p])
			on = not on
			di = (di + 1) % dash.size()
			left = dash[di] * sc
		left -= l - pos
		if on:
			cur.append(b)
		else:
			cur = PackedVector2Array([b])
	if on and cur.size() > 1:
		out.append(cur)
	return out


func stroke(style = null) -> void:
	var st = stroke_style if style == null else style
	var target := _target()
	var sc := (xf.x.length() + xf.y.length()) / 2
	var w := maxf(line_width * sc, 0.0)
	if w <= 0:
		return
	for s in _all():
		var pts: PackedVector2Array = s[0]
		if pts.size() < 2:
			continue
		if s[1]:
			pts = pts.duplicate()
			pts.append(pts[0])
		var pieces: Array = _dashed(pts)
		if not clip_polys.is_empty():
			var cut: Array = []
			for p in pieces:
				for c in clip_polys:
					cut.append_array(Geometry2D.intersect_polyline_with_polygon(p, c))
			pieces = cut
		for p in pieces:
			_stroke_line(target, p, w, st)


func _stroke_line(target: CanvasItem, pts: PackedVector2Array, w: float, st) -> void:
	if pts.size() < 2:
		return
	if line_cap != "butt" and pts.size() >= 2:   # round and square caps reach half the width past the ends
		var e0 := (pts[0] - pts[1]).normalized() * w / 2
		var e1 := (pts[-1] - pts[-2]).normalized() * w / 2
		pts = pts.duplicate()
		if line_cap == "round":
			target.draw_circle(pts[0], w / 2, _solid(st) if not (st is Grad) else st.at(0.0))
			target.draw_circle(pts[-1], w / 2, _solid(st) if not (st is Grad) else st.at(1.0))
		else:
			pts[0] += e0
			pts[-1] += e1
	var sc := CosFx.col(shadow_color)
	if shadow_blur > 0 and sc.a > 0:
		target.draw_polyline(pts, Color(sc, sc.a * 0.25), w + shadow_blur, true)
	if st is Grad:
		var inv := xf.affine_inverse()
		var cols := PackedColorArray()
		for p in pts:
			var q: Vector2 = inv * p
			var t: float
			if st.kind == "radial":
				t = clampf(((q - st.p1).length() - st.r0) / maxf(st.r1 - st.r0, 1e-6), 0, 1)
			else:
				var d: Vector2 = st.p1 - st.p0
				t = clampf((q - st.p0).dot(d) / maxf(d.length_squared(), 1e-9), 0, 1)
			var k: Color = st.at(t)
			k.a *= global_alpha
			cols.append(k)
		target.draw_polyline_colors(pts, cols, w, true)
	else:
		var k := _solid(st)
		if k.a > 0.002:
			target.draw_polyline(pts, k, w, w >= 1.5 or w < 1)


## a texture (or a Ctx2D blob, see blob()) stretched over (x, y, w, h) in user space
func draw_image(tex: Texture2D, x: float, y: float, w: float, h: float, tint: Color = Color.WHITE) -> void:
	if tex == null:
		return
	var pts := PackedVector2Array([xf * Vector2(x, y), xf * Vector2(x + w, y), xf * Vector2(x + w, y + h), xf * Vector2(x, y + h)])
	var uv := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var k := Color(tint, tint.a * global_alpha)
	var cols := PackedColorArray([k, k, k, k])
	RenderingServer.canvas_item_add_triangle_array(_target().get_canvas_item(), PackedInt32Array([0, 1, 2, 0, 2, 3]), pts, cols, uv, PackedInt32Array(), PackedFloat32Array(), tex.get_rid())


## cosmeticGlow: the shared soft light, solid to a fifth of r
func glow(cx: float, cy: float, r: float, col, alpha: float = 1.0) -> void:
	var k := CosFx.col(col)
	k.a *= alpha
	if k.a > 0.003 and r > 0:
		draw_image(CosFx.glow_tex(), cx - r, cy - r, r * 2, r * 2, k)


## a soft round stamp in a colour, full at the middle and clear at the edge (bgBlob)
static func blob(col: String) -> Texture2D:
	var key := "blob:" + col
	if _tex_cache.has(key):
		return _tex_cache[key]
	var c := CosFx.col(col)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([c, Color(c, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	_tex_cache[key] = t
	return t


## the site's own faces (godot/fonts): Big Shoulders Stencil Display and IBM Plex Mono, by the spec's weight
static func font_for(spec: String) -> Font:
	var m := RegEx.create_from_string("^\\s*(\\d{3})").search(spec)
	var wgt := int(m.get_string(1)) if m else 400
	var path := ""
	if spec.contains("Mono") or spec.contains("monospace"):
		path = "res://fonts/ibm-plex-mono-%d.woff2" % (600 if wgt >= 600 else 400)
	elif spec.contains("Stencil") or spec.contains("Big Shoulders"):
		path = "res://fonts/big-shoulders-stencil-display-%d.woff2" % (900 if wgt >= 900 else (800 if wgt >= 700 else 600))
	if _fonts.has(path):
		return _fonts[path]
	var f: Font = ThemeDB.fallback_font
	if path != "" and ResourceLoader.exists(path):
		f = load(path)
	_fonts[path] = f
	return f


func _font_size() -> int:
	var m := RegEx.create_from_string("(\\d+(?:\\.\\d+)?)px").search(font)
	return maxi(1, roundi(float(m.get_string(1)))) if m else 10


func measure_text(s: String) -> float:
	return font_for(font).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size()).x


func _text(s: String, x: float, y: float, st, outline: float) -> void:
	var f := font_for(font)
	var size := _font_size()
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var ox := -w / 2 if text_align == "center" else (-w if text_align == "right" or text_align == "end" else 0.0)
	var oy := 0.0
	if text_baseline == "middle":
		oy = (f.get_ascent(size) - f.get_descent(size)) / 2
	elif text_baseline == "top":
		oy = f.get_ascent(size)
	elif text_baseline == "bottom":
		oy = -f.get_descent(size)
	var target := _target()
	target.draw_set_transform_matrix(xf)
	var k: Color = _solid(st) if not (st is Grad) else st.at(0.5)
	if outline > 0:
		target.draw_string_outline(f, Vector2(x + ox, y + oy), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(outline), k)
	else:
		target.draw_string(f, Vector2(x + ox, y + oy), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, k)
	target.draw_set_transform_matrix(Transform2D.IDENTITY)


func fill_text(s: String, x: float, y: float) -> void:
	_text(s, x, y, fill_style, 0)


func stroke_text(s: String, x: float, y: float) -> void:
	_text(s, x, y, stroke_style, line_width)
