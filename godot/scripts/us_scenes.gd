class_name UsScenes
extends RefCounted
## v0.12 THE UNDERSTRIP CASE backgrounds (18h-understrip-scenes.js): each a still layer and a light animated layer:
## drips, a light through the vault door, two searchlights and a hovering light, chasing neon, glowing tanks. Generic
## retro neon only: no real casino's sign, no real seal or insignia (work order 3).

const IDS := ["floodtunnels", "vaultdoor", "area67", "stripnight", "specimenhall"]


static func _h(i, j) -> float:
	return Backgrounds.H(i, j)


## paintUnderstripBackground
static func draw(x: Ctx2D, id: String, w: float, h: float, t: float, moving: bool) -> void:
	match id:
		"floodtunnels":
			Backgrounds.layer(x, "us:" + id, w, h, func(): _flood_base(x, w, h))
			if moving:
				_flood_live(x, w, h, t)
		"vaultdoor":
			Backgrounds.layer(x, "us:" + id, w, h, func(): _vault_base(x, w, h))
			if moving:
				_vault_live(x, w, h, t)
		"area67":
			Backgrounds.layer(x, "us:" + id, w, h, func(): _area_base(x, w, h))
			if moving:
				_area_live(x, w, h, t)
		"stripnight":
			Backgrounds.layer(x, "us:" + id, w, h, func(): _strip_base(x, w, h))
			if moving:
				_strip_live(x, w, h, t)
		"specimenhall":
			Backgrounds.layer(x, "us:" + id, w, h, func(): _tank_base(x, w, h))
			if moving:
				_tank_live(x, w, h, t)


## usGlow: a radial glow; sets the alpha to a, then back to 1 (as the browser does)
static func glow(x: Ctx2D, X: float, Y: float, r: float, col: String, a: float = 1.0) -> void:
	var gr := x.create_radial_gradient(X, Y, 0, X, Y, r)
	gr.add_color_stop(0, col)
	gr.add_color_stop(1, "rgba(0,0,0,0)")
	x.global_alpha = a
	x.fill_style = gr
	x.fill_rect(X - r, Y - r, r * 2, r * 2)
	x.global_alpha = 1


static func strip_signs(w: float, h: float) -> Array:
	return [{"x": w * 0.08, "y": h * 0.22, "w": w * 0.14, "h": h * 0.12, "col": "#ff5ad8", "glyph": "star"},
		{"x": w * 0.42, "y": h * 0.12, "w": w * 0.12, "h": h * 0.2, "col": "#ffd24a", "glyph": "7"},
		{"x": w * 0.7, "y": h * 0.26, "w": w * 0.18, "h": h * 0.1, "col": "#5ab0ff", "glyph": "arrow"}]


static func tanks(w: float, h: float) -> Array:
	var n := 5 if w > 700 else 3
	var out: Array = []
	for i in n:
		var tw := minf(w / (n * 2.2), 90)
		out.append({"x": w * (i + 0.5) / n, "y": h * 0.3, "w": tw, "h": h * 0.46})
	return out


# ---- the flood tunnels: a concrete barrel vault, a lit grate high up, a drain channel, dripping
static func _flood_base(x: Ctx2D, w: float, h: float) -> void:
	Backgrounds.vgrad(x, w, h, [[0, "#0d100e"], [0.55, "#1b211d"], [1, "#0a0c0b"]])
	var cx := w / 2
	var top := h * 0.18
	x.fill_style = "#232a25"
	x.begin_path()
	x.move_to(0, h)
	x.line_to(0, h * 0.42)
	x.quadratic_curve_to(cx, -h * 0.12, w, h * 0.42)
	x.line_to(w, h)
	x.fill()
	for i in 9:   # the vault's courses
		x.stroke_style = "rgba(0,0,0,.35)"
		x.line_width = 2
		x.begin_path()
		var k := i / 8.0
		x.move_to(k * w, h)
		x.line_to(cx + (k - 0.5) * w * 0.3, h * 0.5)
		x.stroke()
	x.fill_style = "#141815"
	for i in 5:
		x.fill_rect(0, h * (0.46 + i * 0.1), w, 2)
	# the grate and its light
	glow(x, cx, top + h * 0.1, h * 0.55, "rgba(255,214,140,.35)")
	x.fill_style = "#3a3426"
	x.fill_rect(cx - w * 0.08, top, w * 0.16, h * 0.06)
	x.fill_style = "rgba(255,226,160,.85)"
	for i in 7:
		x.fill_rect(cx - w * 0.075 + i * w * 0.022, top + h * 0.008, w * 0.012, h * 0.044)
	# light falling in a shaft
	var gr := x.create_linear_gradient(0, top, 0, h)
	gr.add_color_stop(0, "rgba(255,220,150,.22)")
	gr.add_color_stop(1, "rgba(255,220,150,0)")
	x.fill_style = gr
	x.begin_path()
	x.move_to(cx - w * 0.08, top + h * 0.06)
	x.line_to(cx + w * 0.08, top + h * 0.06)
	x.line_to(cx + w * 0.2, h)
	x.line_to(cx - w * 0.2, h)
	x.fill()
	# the channel and graffiti on the walls (no words)
	x.fill_style = "#16303c"
	x.fill_rect(0, h * 0.86, w, h * 0.07)
	x.fill_style = "rgba(120,190,210,.25)"
	x.fill_rect(0, h * 0.86, w, 2)
	for i in 6:
		x.stroke_style = ["#ff5ad8", "#5ab0ff", "#e2b436"][i % 3]
		x.global_alpha = 0.35
		x.line_width = 4
		x.begin_path()
		var X := w * (0.08 + i * 0.16)
		var Y := h * (0.6 + _h(i, 4) * 0.12)
		x.move_to(X, Y)
		x.bezier_curve_to(X + 20, Y - 30, X + 40, Y + 20, X + 60, Y - 10)
		x.stroke()
	x.global_alpha = 1
	Backgrounds.vgrad(x, w, h, [[0, "rgba(0,0,0,.25)"], [0.6, "rgba(0,0,0,0)"], [1, "rgba(0,0,0,.6)"]])


static func _flood_live(c: Ctx2D, w: float, h: float, t: float) -> void:
	c.save()
	for i in 7:
		var X := w * (0.12 + _h(i, 8) * 0.76)
		var per := 1.6 + _h(i, 9) * 1.4
		var k := fmod(t + _h(i, 10) * per, per) / per
		var y0 := h * (0.2 + _h(i, 11) * 0.2)
		var y := y0 + (h * 0.86 - y0) * k * k
		c.fill_style = "rgba(180,220,230,.7)"
		c.fill_rect(X, y, 2, 6)
		if k > 0.94:
			c.stroke_style = "rgba(180,220,230,.5)"
			c.line_width = 1
			c.begin_path()
			c.ellipse(X, h * 0.875, 10 * (k - 0.94) * 20, 3, 0, 0, TAU)
			c.stroke()
	c.global_alpha = 0.08 + 0.05 * sin(t * 1.3)
	c.fill_style = "#ffe0a0"
	c.fill_rect(0, 0, w, h)
	c.restore()


# ---- the vault door: a huge round door ajar, gold light through it and across the floor
static func _vault_base(x: Ctx2D, w: float, h: float) -> void:
	Backgrounds.vgrad(x, w, h, [[0, "#0e0c08"], [0.6, "#1d1810"], [1, "#0a0806"]])
	var cx := w * 0.52
	var cy := h * 0.5
	var R := minf(w, h) * 0.36
	glow(x, cx, cy, R * 1.7, "rgba(255,200,90,.35)")
	x.fill_style = "#2a2418"   # the opening, full of light
	x.begin_path()
	x.arc(cx, cy, R * 1.12, 0, TAU)
	x.fill()
	x.fill_style = "#ffd57a"
	x.begin_path()
	x.arc(cx, cy, R, 0, TAU)
	x.fill()
	x.fill_style = "#6a5a3a"   # the door, swung open
	x.begin_path()
	x.ellipse(cx + R * 0.62, cy, R * 0.42, R, 0, 0, TAU)
	x.fill()
	x.stroke_style = "#3a3020"
	x.line_width = R * 0.05
	for k in [0.7, 0.5, 0.3]:
		x.begin_path()
		x.ellipse(cx + R * 0.62, cy, R * 0.42 * k, R * k, 0, 0, TAU)
		x.stroke()
	for i in 8:
		var a := i * PI / 4
		x.fill_style = "#8a7650"
		x.fill_rect(cx + R * 0.62 + cos(a) * R * 0.25 - 4, cy + sin(a) * R * 0.6 - 4, 8, 8)
	var gr := x.create_linear_gradient(0, cy, 0, h)
	gr.add_color_stop(0, "rgba(255,210,110,.4)")
	gr.add_color_stop(1, "rgba(255,210,110,0)")
	x.fill_style = gr
	x.begin_path()
	x.move_to(cx - R, cy + R * 0.5)
	x.line_to(cx + R * 0.3, cy + R * 0.5)
	x.line_to(cx + R * 1.4, h)
	x.line_to(cx - R * 1.6, h)
	x.fill()
	for i in 5:   # stacked bars in silhouette
		x.fill_style = "rgba(40,30,15,.8)"
		x.fill_rect(cx - R * 0.6 + i * R * 0.3, cy - R * 0.05 + (i % 2) * R * 0.2, R * 0.2, R * 0.5)
	Backgrounds.vgrad(x, w, h, [[0, "rgba(0,0,0,.3)"], [0.55, "rgba(0,0,0,0)"], [1, "rgba(0,0,0,.65)"]])


static func _vault_live(c: Ctx2D, w: float, h: float, t: float) -> void:
	var cx := w * 0.52
	var cy := h * 0.5
	var R := minf(w, h) * 0.36
	c.save()
	c.composite = "lighter"
	for i in 14:
		var k := fmod(t * 0.12 + _h(i, 3), 1)
		var X := cx - R * 0.8 + _h(i, 5) * R * 1.4
		var Y := cy + R * 0.2 - k * R * 1.2
		c.global_alpha = 0.6 * sin(k * PI)
		c.fill_style = "#fff0b8"
		c.fill_rect(X, Y, 2, 2)
	c.global_alpha = 0.1 + 0.06 * sin(t * 0.9)
	glow(c, cx, cy, R * 1.2, "rgba(255,210,110,.9)", c.global_alpha)
	c.restore()


# ---- Area 67's fence at dusk: a wire fence, a guard tower, two searchlights sweeping and a light that hovers
static func _area_base(x: Ctx2D, w: float, h: float) -> void:
	Backgrounds.vgrad(x, w, h, [[0, "#1b1430"], [0.45, "#5a3448"], [0.62, "#c06a4a"], [0.7, "#2a2026"], [1, "#120e12"]])
	x.fill_style = "#2a2026"   # the desert ridge
	x.begin_path()
	x.move_to(0, h * 0.66)
	for i in 11:
		x.line_to(i * w / 10, h * (0.62 + _h(i, 2) * 0.05))
	x.line_to(w, h)
	x.line_to(0, h)
	x.fill()
	x.fill_style = "#0e0b10"
	x.fill_rect(0, h * 0.74, w, h * 0.26)
	x.stroke_style = "rgba(20,16,22,.9)"   # posts
	x.line_width = 2
	var X := 0.0
	while X < w:
		x.begin_path()
		x.move_to(X, h * 0.56)
		x.line_to(X, h * 0.8)
		x.stroke()
		X += w / 14
	x.line_width = 1   # the mesh
	x.stroke_style = "rgba(40,34,44,.8)"
	X = -h
	while X < w:
		x.begin_path()
		x.move_to(X, h * 0.8)
		x.line_to(X + h * 0.24, h * 0.56)
		x.stroke()
		x.begin_path()
		x.move_to(X + h * 0.24, h * 0.8)
		x.line_to(X, h * 0.56)
		x.stroke()
		X += 14
	X = 0.0
	while X < w:   # wire on top
		x.stroke_style = "#1a141c"
		x.begin_path()
		x.arc(X, h * 0.555, 4, 0, TAU)
		x.stroke()
		X += 10
	x.fill_style = "#0c090e"   # the tower
	x.fill_rect(w * 0.78, h * 0.3, w * 0.06, h * 0.46)
	x.fill_rect(w * 0.75, h * 0.27, w * 0.12, h * 0.05)
	x.fill_style = "#e8e2d0"   # a blank warning sign
	x.global_alpha = 0.7
	x.fill_rect(w * 0.04, h * 0.68, w * 0.16, h * 0.04)
	x.global_alpha = 1
	x.fill_style = "#c42a2a"
	x.fill_rect(w * 0.04, h * 0.68, w * 0.16, h * 0.008)
	for i in 30:
		x.fill_style = "#f4e8ff"
		x.global_alpha = 0.2 + 0.4 * _h(i, 7)
		x.fill_rect(_h(i, 8) * w, _h(i, 9) * h * 0.3, 1, 1)
	x.global_alpha = 1


static func _area_live(c: Ctx2D, w: float, h: float, t: float) -> void:
	c.save()
	c.composite = "lighter"
	for q in [[w * 0.81, 0.0], [w * 0.2, 2.2]]:
		var X: float = q[0]
		var a := -PI / 2 + sin(t * 0.4 + q[1]) * 0.7
		var L := h * 0.9
		var gr := c.create_linear_gradient(X, h * 0.3, X + cos(a) * L, h * 0.3 + sin(a) * L)
		gr.add_color_stop(0, "rgba(255,250,220,.35)")
		gr.add_color_stop(1, "rgba(255,250,220,0)")
		c.fill_style = gr
		c.begin_path()
		c.move_to(X, h * 0.3)
		c.line_to(X + cos(a - 0.08) * L, h * 0.3 + sin(a - 0.08) * L)
		c.line_to(X + cos(a + 0.08) * L, h * 0.3 + sin(a + 0.08) * L)
		c.fill()
	var hx := w * (0.42 + 0.06 * sin(t * 0.3))
	var hy := h * (0.2 + 0.03 * sin(t * 0.7))
	glow(c, hx, hy, h * 0.12, "rgba(160,255,140,.8)", 0.6 + 0.2 * sin(t * 3))
	c.fill_style = "#f0fff0"
	c.global_alpha = 0.9
	c.begin_path()
	c.ellipse(hx, hy, 8, 3, 0, 0, TAU)
	c.fill()
	c.restore()


# ---- the Strip at night: a retro neon skyline (invented signs: stars, arrows, a big 7), its bulbs chasing
static func _strip_base(x: Ctx2D, w: float, h: float) -> void:
	Backgrounds.vgrad(x, w, h, [[0, "#06040e"], [0.55, "#1a0e2a"], [1, "#2a1020"]])
	for i in 60:
		x.fill_style = "#f0e8ff"
		x.global_alpha = 0.15 + 0.4 * _h(i, 21)
		x.fill_rect(_h(i, 22) * w, _h(i, 23) * h * 0.45, 1, 1)
	x.global_alpha = 1
	glow(x, w / 2, h, h * 0.9, "rgba(255,90,216,.25)")
	var px := -10.0
	var n := 0
	while px < w:
		var bw := w * (0.07 + _h(n, 31) * 0.07)
		var bh := h * (0.22 + _h(n, 32) * 0.32)
		var y0 := h * 0.8 - bh
		x.fill_style = "#120a1c" if n % 2 else "#0e0816"
		x.fill_rect(px, y0, bw, h - y0)
		var wy := y0 + 8
		while wy < h * 0.8 - 6:
			var wx := px + 5
			while wx < px + bw - 5:
				if _h(int(wx), int(wy)) < 0.3:
					x.fill_style = "rgba(255,210,150,.55)"
					x.fill_rect(wx, wy, 3, 4)
				wx += 9
			wy += 10
		px += bw + 3
		n += 1
	x.fill_style = "#08060c"
	x.fill_rect(0, h * 0.8, w, h * 0.2)
	for s in strip_signs(w, h):   # the signs' frames (their tubes are the live layer)
		x.fill_style = "#14101e"
		x.fill_rect(s.x - 4, s.y - 4, s.w + 8, s.h + 8)


static func _strip_live(c: Ctx2D, w: float, h: float, t: float) -> void:
	c.save()
	c.composite = "lighter"
	var S := strip_signs(w, h)
	for i in S.size():
		var s: Dictionary = S[i]
		var col: String = s.col
		var on := 0.55 + 0.45 * sin(t * 2 + i)
		c.stroke_style = col
		c.global_alpha = on
		c.line_width = 3
		c.stroke_rect(s.x, s.y, s.w, s.h)
		c.global_alpha = on * 0.3
		c.line_width = 9
		c.stroke_rect(s.x, s.y, s.w, s.h)
		c.global_alpha = 1
		var n := floori((s.w + s.h) * 2 / 14)
		var k := floori(t * 8)
		for q in n:   # chasing bulbs
			if (q + k) % 3:
				continue
			var d: float = float(q) / n * (s.w + s.h) * 2
			var X: float
			var Y: float
			if d < s.w:
				X = s.x + d
				Y = s.y
			elif d < s.w + s.h:
				X = s.x + s.w
				Y = s.y + d - s.w
			elif d < 2 * s.w + s.h:
				X = s.x + s.w - (d - s.w - s.h)
				Y = s.y + s.h
			else:
				X = s.x
				Y = s.y + s.h - (d - 2 * s.w - s.h)
			c.fill_style = "#fff6c8"
			c.fill_rect(X - 1.5, Y - 1.5, 3, 3)
		if s.glyph == "7":
			c.fill_style = col
			c.global_alpha = on
			c.font = "900 %spx \"Big Shoulders Stencil Display\",sans-serif" % str(s.h * 0.8)
			c.text_align = "center"
			c.text_baseline = "middle"
			c.fill_text("7", s.x + s.w / 2, s.y + s.h / 2)
		elif s.glyph == "star":
			c.fill_style = col
			c.global_alpha = on
			c.begin_path()
			for k2 in 10:
				var a := -PI / 2 + k2 * PI / 5
				var r: float = s.h * 0.18 if k2 % 2 else s.h * 0.4
				c.line_to(s.x + s.w / 2 + cos(a) * r, s.y + s.h / 2 + sin(a) * r)
			c.fill()
		else:
			c.stroke_style = col
			c.global_alpha = on
			c.line_width = 4
			c.begin_path()
			c.move_to(s.x + s.w * 0.2, s.y + s.h / 2)
			c.line_to(s.x + s.w * 0.8, s.y + s.h / 2)
			c.line_to(s.x + s.w * 0.6, s.y + s.h * 0.25)
			c.move_to(s.x + s.w * 0.8, s.y + s.h / 2)
			c.line_to(s.x + s.w * 0.6, s.y + s.h * 0.75)
			c.stroke()
	c.restore()


# ---- the specimen hall: a dark lab, a row of tanks glowing, something turning in the middle one
static func _tank_base(x: Ctx2D, w: float, h: float) -> void:
	Backgrounds.vgrad(x, w, h, [[0, "#04080a"], [0.6, "#0a1418"], [1, "#030506"]])
	x.fill_style = "#0c161a"
	x.fill_rect(0, h * 0.78, w, h * 0.22)
	x.stroke_style = "rgba(120,200,220,.08)"
	x.line_width = 1
	var X := 0.0
	while X < w:
		x.begin_path()
		x.move_to(X, h * 0.78)
		x.line_to(w / 2 + (X - w / 2) * 1.8, h)
		x.stroke()
		X += w / 16
	for T in tanks(w, h):
		glow(x, T.x, T.y + T.h * 0.5, T.w * 1.6, "rgba(90,220,170,.25)")
		x.fill_style = "#1c2a2e"
		x.fill_rect(T.x - T.w / 2 - 4, T.y - 8, T.w + 8, 10)
		x.fill_rect(T.x - T.w / 2 - 4, T.y + T.h, T.w + 8, 12)
		var gr := x.create_linear_gradient(T.x - T.w / 2, 0, T.x + T.w / 2, 0)
		gr.add_color_stop(0, "rgba(60,170,140,.55)")
		gr.add_color_stop(0.5, "rgba(120,240,200,.7)")
		gr.add_color_stop(1, "rgba(40,140,120,.55)")
		x.fill_style = gr
		x.fill_rect(T.x - T.w / 2, T.y, T.w, T.h)
		x.stroke_style = "rgba(220,255,240,.35)"
		x.stroke_rect(T.x - T.w / 2, T.y, T.w, T.h)
	Backgrounds.vgrad(x, w, h, [[0, "rgba(0,0,0,.35)"], [0.5, "rgba(0,0,0,0)"], [1, "rgba(0,0,0,.6)"]])


static func _tank_live(c: Ctx2D, w: float, h: float, t: float) -> void:
	var S := tanks(w, h)
	c.save()
	for i in S.size():
		var T: Dictionary = S[i]
		for k in 4:
			var q := fmod(t * 0.25 + _h(i, k), 1)
			var bx: float = T.x - T.w * 0.3 + _h(k, i + 3) * T.w * 0.6
			var by: float = T.y + T.h * (1 - q)
			c.global_alpha = 0.6 * (1 - q)
			c.stroke_style = "#d8fff0"
			c.line_width = 1
			c.begin_path()
			c.arc(bx, by, 2 + _h(k, i) * 2, 0, TAU)
			c.stroke()
		if i == floori(S.size() / 2.0):
			var sw: float = sin(t * 0.6) * T.w * 0.12
			c.global_alpha = 0.85
			c.fill_style = "#0a1a16"
			c.begin_path()
			c.ellipse(T.x + sw, T.y + T.h * 0.38, T.w * 0.18, T.h * 0.16, 0, 0, TAU)
			c.fill()
			c.begin_path()
			c.ellipse(T.x + sw * 0.8, T.y + T.h * 0.62, T.w * 0.1, T.h * 0.22, 0, 0, TAU)
			c.fill()
			c.fill_style = "rgba(200,255,220,.8)"   # its eyes
			c.global_alpha = 0.5 + 0.5 * sin(t * 1.7)
			c.fill_rect(T.x + sw - 3, T.y + T.h * 0.36, 2, 2)
			c.fill_rect(T.x + sw + 2, T.y + T.h * 0.36, 2, 2)
	c.global_alpha = 0.05 + 0.04 * sin(t * 2.1)
	c.fill_style = "#7cffd0"
	c.fill_rect(0, 0, w, h)
	c.restore()
