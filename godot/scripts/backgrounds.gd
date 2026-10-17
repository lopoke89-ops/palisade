class_name Backgrounds
extends RefCounted
## The lobby backgrounds (18b-backgrounds.js, 18c-background-depth.js, 18d-winter-scenes.js, 18f-hybrid-scenes.js), painted
## on a Ctx2D: draw(x, id, w, h, t). Stills (the catalog's "still" time) are painted at that moment; a caller that wants
## them once can cache the result.

const REFINE := {
	"campfire": ["terrain", "#55331f", "#211a16", "#100e0c"], "nightwatch": ["terrain", "#263448", "#141f30", "#080e18"],
	"dawn": ["terrain", "#784756", "#4a3045", "#211927"], "aurora": ["terrain", "#193f49", "#142a38", "#070f18"],
	"emberfield": ["terrain", "#5a2419", "#301612", "#150c0b"], "harvestmoon": ["terrain", "#422735", "#271726", "#100b14"],
	"hauntedfog": ["terrain", "#393346", "#221f31", "#100e1c"], "watchtower": ["terrain", "#243041", "#151f2d", "#090e18"],
	"searchlight": ["terrain", "#1c2a3a", "#121e2a", "#070d15"], "bloodmoon": ["terrain", "#41131c", "#240a12", "#0e050b"],
	"graveyard": ["ground", "#2a303a", "#161d26", "#0c1018"], "witchbrew": ["ground", "#1b2c25", "#101b18", "#090e13"],
	"sunsetfade": ["terrain", "#57234e", "#321330", "#160b24"], "lagoonwaves": ["water"],
	"fieldmap": ["paper"], "sandbags": ["canvas"], "dogtags": ["metal"], "crimson": ["smoke"],
	"nebula": ["cosmic"], "eventhorizon": ["lens"], "neongrid": ["horizon"], "neonpulse": ["city"], "goldrush": ["gold"], "goldaurora": ["goldsky"]}
## a cached layer key -> the scene whose scenic detail is baked into it
const DEPTH := {"campfire": "campfire", "nightwatch": "nightwatch", "dawnfg": "dawn", "aurorafg": "aurora", "ember": "emberfield", "neon": "neongrid",
	"gold": "goldrush", "searchfg": "searchlight", "blood": "bloodmoon", "gaur": "goldaurora", "neonp": "neonpulse", "horizon": "eventhorizon"}
const WINTER := ["summitcommand", "frozenriver", "snowquarry", "skistation", "winterdepot", "lanternoutpost", "aurorafrostpeak", "whiteouttower", "yulehangar", "midnightevac"]
const HYBRID := {"yardneon": ["#0E2240", "#FEC524", "#3a5a8c"], "voltgrid": ["#0a0a0a", "#C1D32F", "#E03A3E"], "viceblock": ["#0a0a0a", "#FF4FA3", "#5ED0F5"],
	"crowncity": ["#2a1446", "#FDB927", "#552583"], "peachwire": ["#0a0a0a", "#E39A6A", "#f3e6d4"], "lakeblocks": ["#0C2340", "#78BE20", "#4fd3b8"],
	"fiestastrip": ["#0a0a0a", "#F26B8A", "#2EC4B6"], "oaknight": ["#1d140c", "#F3E6D4", "#c9a13a"]}


## the browser's hash(i, j), fractional inputs included (JS multiplies first, then truncates to 32 bits)
static func H(i, j) -> float:
	if (i is float and i != floorf(i)) or (j is float and j != floorf(j)):
		var v := float(i) * 374761393.0 + float(j) * 668265263.0
		var hh: int = Pal._i32(int(fmod(v, 4294967296.0)))
		hh = Pal._imul(hh ^ Pal._ushr(hh, 13), 1274126177)
		return float(Pal._u32(hh ^ Pal._ushr(hh, 16))) / 4294967295.0
	return Pal.hash2(int(i), int(j))


static func ids() -> Array:
	return PalLocker.catalog().get("BGS", {}).keys()


static func is_still(id: String) -> bool:
	return PalLocker.catalog().get("BGS", {}).get(id, {}).has("still")


## the one call the lobby and the Locker use
static func draw(x: Ctx2D, id: String, w: float, h: float, t: float) -> void:
	var B: Dictionary = PalLocker.catalog().get("BGS", {}).get(id, {})
	if B.is_empty():
		id = "campfire"
		B = PalLocker.catalog().BGS.campfire
	if B.has("still"):
		t = B.still
	x.save()
	_scene(x, id, w, h, t)
	x.restore()
	if REFINE.has(id) and not (id in DEPTH.values()):
		x.save()
		scenic(x, id, w, h)
		x.restore()


## bgLayer: the still part of a scene, with that scene's scenic finish when the layer carries one
static func layer(x: Ctx2D, key: String, w: float, h: float, paint: Callable) -> void:
	x.save()
	paint.call()
	x.restore()
	if DEPTH.has(key):
		x.save()
		scenic(x, DEPTH[key], w, h)
		x.restore()


static func vgrad(x: Ctx2D, w: float, h: float, stops: Array) -> void:
	var g := x.create_linear_gradient(0, 0, 0, h)
	for s in stops:
		g.add_color_stop(s[0], s[1])
	x.fill_style = g
	x.fill_rect(0, 0, w, h)


static func blob(x: Ctx2D, col: String, bx: float, by: float, bw: float, bh: float) -> void:
	x.draw_image(Ctx2D.blob(col), bx, by, bw, bh)


static func poly(x: Ctx2D, pts: Array, col) -> void:
	x.fill_style = col
	x.begin_path()
	for i in pts.size():
		if i:
			x.line_to(pts[i][0], pts[i][1])
		else:
			x.move_to(pts[i][0], pts[i][1])
	x.close_path()
	x.fill()


static func trees(x: Ctx2D, w: float, h: float, base: float, col: String, seed: int) -> void:
	x.fill_style = col
	for i in ceili(w / 26) + 2:
		var tx := i * 26 - 10 + H(i, seed) * 14
		var th := 40 + H(i, seed + 1) * 70
		var tw := 16 + H(i, seed + 2) * 10
		var y0 := base + H(i, seed + 3) * 10
		x.begin_path()
		x.move_to(tx, y0 - th)
		x.line_to(tx - tw / 2, y0)
		x.line_to(tx + tw / 2, y0)
		x.close_path()
		x.fill()
	x.fill_rect(0, base + 8, w, h - base)


static func fence(x: Ctx2D, w: float, base: float, col: String) -> void:
	x.stroke_style = col
	x.line_width = 3
	x.begin_path()
	x.move_to(0, base - 18)
	x.line_to(w, base - 22)
	x.move_to(0, base - 8)
	x.line_to(w, base - 11)
	x.stroke()
	x.line_width = 4
	var px := 8.0
	while px < w:
		x.begin_path()
		x.move_to(px, base + 2)
		x.line_to(px, base - 28)
		x.stroke()
		px += 34


static func bats_line(x: Ctx2D, bx: float, by: float, f: float, s: float = 1.0) -> void:
	x.begin_path()
	x.move_to(bx - 9 * s, by - f)
	x.line_to(bx - 3 * s, by)
	x.line_to(bx, by - 2 * s)
	x.line_to(bx + 3 * s, by)
	x.line_to(bx + 9 * s, by - f)
	x.stroke()


# ---------------------------------------------------------------- the scenic finishing layers (18c)

static func scenic(x: Ctx2D, id: String, w: float, h: float) -> void:
	var R: Array = REFINE[id]
	var kind: String = R[0]
	var u := minf(w, h)
	var seed := id.length() * 37
	var ridge := func(base: float, amp: float, col: String, s: int) -> void:
		var pts := [[0, h]]
		for i in 17:
			pts.append([w * i / 16.0, h * (base - amp * H(i, s))])
		pts.append([w, h])
		poly(x, pts, col)
	var glow := func(cx: float, cy: float, rx: float, ry: float, col: String) -> void: blob(x, col, cx - rx, cy - ry, rx * 2, ry * 2)
	match kind:
		"terrain", "ground":
			var far: String = R[1]
			var mid: String = R[2]
			var near: String = R[3]
			var base := 0.94 if kind == "ground" else (0.91 if id == "hauntedfog" else 0.84)
			ridge.call(base, 0.065, far, seed)
			ridge.call(base + 0.045, 0.035, mid, seed + 1)
			ridge.call(0.982, 0.045, near, seed + 2)
			if id in ["campfire", "dawn", "nightwatch", "hauntedfog", "watchtower", "aurora", "sunsetfade"]:
				var warm := id == "campfire" or id == "dawn"
				poly(x, [[w * 0.61, h * (base - 0.015)], [w * 0.66, h * (base + 0.015)], [w * 0.52, h * 0.94], [w * 0.69, h], [w * 0.38, h], [w * 0.43, h * 0.94]], "rgba(232,159,101,.16)" if warm else "rgba(153,190,218,.13)")
				for i in 14:
					var y := h * (base + 0.02 + i * 0.01)
					var width := (i + 1) * w * 0.003
					x.fill_style = "rgba(244,187,121,.16)" if warm else "rgba(174,213,230,.14)"
					x.fill_rect(w * (0.565 + 0.02 * sin(i)) - width, y, width * 2, maxf(1, u * 0.001))
			if id == "campfire" or id == "emberfield":
				glow.call(w * 0.5, h * 1.03, w * 0.55, h * 0.18, "rgba(255,126,42,.3)")
			if id == "hauntedfog" or id == "graveyard" or id == "bloodmoon":
				glow.call(w * 0.35, h * 0.91, w * 0.7, h * 0.05, "rgba(181,54,66,.17)" if id == "bloodmoon" else "rgba(171,177,205,.16)")
			for i in 20:
				var left := i % 2 == 0
				var px := w * (H(i, seed + 3) * 0.24 if left else 0.78 + H(i, seed + 3) * 0.22)
				var py := h * (0.91 + 0.09 * H(i, seed + 4))
				var r := u * (0.003 + 0.013 * H(i, seed + 5))
				poly(x, [[px - r, py], [px - r * 0.5, py - r * 0.6], [px + r * 0.6, py - r * 0.45], [px + r, py]], mid)
				x.stroke_style = far
				x.line_width = maxf(0.7, u * 0.001)
				x.begin_path()
				x.move_to(px - r * 0.5, py - r * 0.6)
				x.line_to(px + r * 0.6, py - r * 0.45)
				x.stroke()
				if i % 3 == 0:
					x.stroke_style = near
					x.begin_path()
					x.move_to(px, py)
					x.line_to(px - r * 0.2, py - r * 1.8)
					x.move_to(px, py)
					x.line_to(px + r * 0.6, py - r * 1.1)
					x.stroke()
			if id == "nightwatch":
				glow.call(w * 0.77, h * 0.23, u * 0.14, u * 0.14, "rgba(135,181,229,.15)")
				x.fill_style = "#b1c6d5"
				x.begin_path()
				x.arc(w * 0.77, h * 0.23, u * 0.023, 0, TAU)
				x.fill()
				x.fill_style = "#101a2b"
				x.begin_path()
				x.arc(w * 0.77 + u * 0.01, h * 0.23 - u * 0.007, u * 0.022, 0, TAU)
				x.fill()
		"water":
			for k in 9:
				x.stroke_style = "rgba(173,255,233,%s)" % (0.13 + k * 0.014)
				x.line_width = 1 + k * 0.2
				x.begin_path()
				var px := 0.0
				while px <= w + 10:
					var y := h * (0.25 + k * 0.09) + sin(px * 0.025 + k * 1.3) * 12 + sin(px * 0.06 + k) * 4
					if px > 0:
						x.line_to(px, y)
					else:
						x.move_to(px, y)
					px += 10
				x.stroke()
			for i in 80:
				x.fill_style = "rgba(166,255,232,.12)"
				x.fill_rect(H(i, 112) * w, h * (0.3 + 0.7 * H(i, 113)), u * (0.003 + 0.02 * H(i, 114)), maxf(1, u * 0.0015))
		"paper":
			for f in [0.33, 0.66]:
				var g := x.create_linear_gradient(w * f - 9, 0, w * f + 9, 0)
				g.add_color_stop(0, "#38280e00")
				g.add_color_stop(0.45, "#38280e22")
				g.add_color_stop(0.55, "#fff6da33")
				g.add_color_stop(1, "#fff6da00")
				x.fill_style = g
				x.fill_rect(w * f - 9, 0, 18, h)
			x.stroke_style = "rgba(59,54,33,.4)"
			x.line_width = 1
			var cx := w * 0.88
			var cy := h * 0.17
			var r := u * 0.06
			x.begin_path()
			x.arc(cx, cy, r, 0, TAU)
			x.move_to(cx - r * 1.2, cy)
			x.line_to(cx + r * 1.2, cy)
			x.move_to(cx, cy - r * 1.2)
			x.line_to(cx, cy + r * 1.2)
			x.stroke()
			poly(x, [[cx, cy - r], [cx - r * 0.18, cy + r * 0.4], [cx + r * 0.18, cy + r * 0.4]], "#625638")
			x.fill_style = "rgba(64,47,22,.075)"
			for i in 280:
				x.fill_rect(H(i, 116) * w, H(i, 117) * h, 1 + H(i, 118) * 3, 1)
		"canvas":
			for row in ceili(h * 0.34 / 26):
				for i in range(-1, int(w / 58) + 1):
					var bx := i * 58 + (29 if row % 2 else 0)
					var by := h * 0.66 + row * 26
					x.stroke_style = "rgba(250,223,170,.32)"
					x.line_width = 1
					x.begin_path()
					x.move_to(bx + 12, by + 5)
					x.line_to(bx + 45, by + 5)
					x.stroke()
					x.fill_style = "rgba(35,29,20,.18)"
					x.fill_rect(bx + 10, by + 20, 38, 2)
					x.fill_style = "rgba(52,40,22,.15)"
					for k in 6:
						x.fill_rect(bx + 10 + k * 6, by + 9, 1, 5)
			var g := x.create_linear_gradient(0, h * 0.66, 0, h)
			g.add_color_stop(0, "#18130d00")
			g.add_color_stop(1, "#18130d88")
			x.fill_style = g
			x.fill_rect(0, h * 0.66, w, h * 0.34)
		"metal":
			var g := x.create_linear_gradient(0, 0, w, h)
			g.add_color_stop(0, "#d5e6eb00")
			g.add_color_stop(0.25, "#d5e6eb12")
			g.add_color_stop(0.45, "#d5e6eb00")
			g.add_color_stop(1, "#030a1144")
			x.fill_style = g
			x.fill_rect(0, 0, w, h)
			x.stroke_style = "rgba(190,210,217,.045)"
			x.line_width = 1
			for i in 45:
				var px := H(i, 120) * w
				var py := H(i, 121) * h
				x.begin_path()
				x.move_to(px, py)
				x.line_to(px + u * 0.03, py - u * 0.02)
				x.stroke()
		"smoke":
			for i in 8:
				var px := w * (0.08 + 0.84 * H(i, 125))
				var py := h * (0.1 + 0.8 * H(i, 126))
				glow.call(px, py, w * 0.24, h * 0.18, "rgba(131,30,46,.10)")
				glow.call(px + w * 0.035, py + h * 0.03, w * 0.18, h * 0.14, "rgba(7,4,12,.30)")
		"cosmic", "goldsky":
			var gold := kind == "goldsky"
			for i in 42:
				var px := H(i, 130) * w
				var py := H(i, 131) * h
				var r := u * 0.015 if i % 9 == 0 else u * 0.002
				if i % 9 == 0:
					glow.call(px, py, r * 3, r * 3, "rgba(255,210,110,.17)" if gold else "rgba(131,161,255,.24)")
				x.fill_style = "#eee0b199" if gold else "#d7e5ffbb"
				x.fill_rect(px, py, maxf(1, r * 0.25), maxf(1, r * 0.25))
			if not gold:
				for i in 7:
					glow.call(w * (0.13 + i * 0.12), h * (0.28 + i * 0.064), w * 0.11, h * 0.13, "rgba(6,4,19,.42)")
			else:
				ridge.call(0.96, 0.06, "#1d1c20", 137)
				ridge.call(1, 0.055, "#0a0d12", 138)
		"lens":
			var cx := w * 0.5
			var cy := h * 0.42
			var Rr := minf(w, h) * 0.42
			var g := x.create_radial_gradient(cx, cy, Rr * 0.63, cx, cy, Rr * 1.35)
			g.add_color_stop(0, "#ffb17000")
			g.add_color_stop(0.28, "#ffa2660b")
			g.add_color_stop(0.55, "#b681ff10")
			g.add_color_stop(1, "#b681ff00")
			x.fill_style = g
			x.fill_rect(0, 0, w, h)
		"horizon":
			glow.call(w * 0.5, h * 0.55, w * 0.52, h * 0.1, "rgba(221,65,226,.17)")
			for side in [-1, 1]:
				poly(x, [[w * (0.5 + side * 0.26), h * 0.55], [w * (0.5 + side * 0.4), h * 0.49], [w * (0.5 + side * 0.48), h * 0.53], [w * (0.5 + side * 0.5), h * 0.46], [w * (0.5 + side * 0.5), h * 0.55]], "#170d2b")
		"city":
			for i in 30:
				x.fill_style = "rgba(208,61,203,.18)" if i % 2 else "rgba(67,172,223,.16)"
				x.fill_rect(H(i, 150) * w, h * (0.89 + H(i, 151) * 0.1), 5 + H(i, 152) * w * 0.03, maxf(1, u * 0.0015))
		"gold":
			for i in 12:
				var px := w * (0.88 + 0.12 * H(i, 155) if i % 2 else 0.12 * H(i, 155))
				var py := h * (0.4 + 0.7 * H(i, 156))
				var r := u * (0.025 + 0.06 * H(i, 157))
				poly(x, [[px, py - r], [px + r * 0.5, py], [px, py + r], [px - r * 0.55, py]], "rgba(239,192,89,.14)")
				poly(x, [[px, py - r], [px, py + r], [px - r * 0.55, py]], "rgba(66,40,17,.25)")


# ---------------------------------------------------------------- the scenes (18b)

static func _scene(x: Ctx2D, id: String, w: float, h: float, t: float) -> void:
	if id.begins_with("f_"):
		var meta: Dictionary = PalLocker.catalog().BGS.get(id, {})
		flag_scene(x, w, h, t, id.substr(2), meta.get("r", "c") == "l" or meta.get("r", "c") == "g")
		return
	if id in WINTER:
		var n := WINTER.find(id)
		var animated: bool = PalLocker.catalog().BGS.get(id, {}).get("animated", false)
		winter(x, w, h, t if animated else 0.0, n, animated)
		return
	if HYBRID.has(id):
		hybrid(x, w, h, t, HYBRID.keys().find(id), HYBRID[id], true)
		return
	match id:
		"campfire":
			layer(x, "campfire", w, h, func():
				vgrad(x, w, h, [[0, "#140f0c"], [0.55, "#2a1a10"], [1, "#5a2a12"]])
				var gr := x.create_radial_gradient(w / 2, h * 1.02, 0, w / 2, h * 1.02, h * 0.55)
				gr.add_color_stop(0, "rgba(255,140,50,.45)")
				gr.add_color_stop(1, "rgba(255,140,50,0)")
				x.fill_style = gr
				x.fill_rect(0, 0, w, h)
				trees(x, w, h, h * 0.86, "#0c0907", 11))
			for i in 26:
				var ph := fmod(t * 0.09 * (0.6 + H(i, 2)) + H(i, 1), 1.0)
				x.global_alpha = sin(ph * PI) * 0.9
				x.fill_style = "#ffb04a" if i % 3 else "#ffe08a"
				x.fill_rect(w * (0.3 + 0.4 * H(i, 3)) + sin(t * 1.3 + i) * 14, h * (1 - ph * 0.85), 2, 2)
			x.global_alpha = 1
		"nightwatch":
			layer(x, "nightwatch", w, h, func():
				vgrad(x, w, h, [[0, "#05070f"], [0.7, "#0d1426"], [1, "#162038"]])
				trees(x, w, h, h * 0.9, "#04050a", 21))
			for i in 70:
				x.global_alpha = 0.35 + 0.65 * absf(sin(t * (0.6 + H(i, 7)) + i))
				x.fill_style = "#e8eeff" if i % 9 else "#ffe9b0"
				var s := 1.0 if i % 7 else 1.6
				x.fill_rect(H(i, 5) * w, H(i, 6) * h * 0.75, s, s)
			var sp := fmod(t, 11) / 11
			if sp < 0.12:
				var k := sp / 0.12
				var x0 := w * (0.15 + 0.5 * k)
				var y0 := h * (0.1 + 0.18 * k)
				x.global_alpha = 1 - k
				x.stroke_style = "#ffffff"
				x.line_width = 1.4
				x.begin_path()
				x.move_to(x0, y0)
				x.line_to(x0 - 40, y0 - 14)
				x.stroke()
			x.global_alpha = 1
		"skyline":
			layer(x, "skyline", w, h, func(): skyline_scene(x, w, h))
			for i in 40:
				if not (sin(t * (0.3 + H(i, 71)) + i * 3) > -0.2):
					continue
				x.fill_style = "rgba(255,214,130,.85)" if i % 4 else "rgba(190,220,255,.8)"
				x.fill_rect(H(i, 72) * w, h * (0.42 + H(i, 73) * 0.4), 2, 3)
			var a := sin(t * 0.35) * 0.5
			x.save()
			x.translate(w * 0.72, h * 0.82)
			x.rotate(-PI / 2 + a)
			var gr := x.create_linear_gradient(0, 0, h * 0.9, 0)
			gr.add_color_stop(0, "rgba(255,240,200,.28)")
			gr.add_color_stop(1, "rgba(255,240,200,0)")
			x.fill_style = gr
			x.begin_path()
			x.move_to(0, 0)
			x.line_to(h * 0.9, -30)
			x.line_to(h * 0.9, 30)
			x.close_path()
			x.fill()
			x.restore()
		"dawn":
			var k := 0.5 + 0.5 * sin(t * 0.12)
			vgrad(x, w, h, [[0, CosFx.hsl(250 - 20 * k, 0.4, (14 + 6 * k) / 100)], [0.55, CosFx.hsl(340 + 10 * k, 0.55, (38 + 8 * k) / 100)], [1, "#ffb070"]])
			x.fill_style = "rgba(255,230,170,.9)"
			x.begin_path()
			x.arc(w * 0.62, h * (0.74 - 0.06 * k), 34, 0, TAU)
			x.fill()
			for i in 5:
				var cx := fmod(t * 6 * (1 + i * 0.3) + i * 170, w + 260) - 130
				x.global_alpha = 0.35
				blob(x, "rgba(255,210,220,.9)", cx - 90, h * (0.2 + 0.1 * i) - 20, 180, 40)
			x.global_alpha = 1
			layer(x, "dawnfg", w, h, func(): trees(x, w, h, h * 0.9, "#1a0f18", 31))
		"aurora":
			layer(x, "aurora", w, h, func():
				vgrad(x, w, h, [[0, "#02040a"], [1, "#0a1a24"]])
				x.fill_style = "#dfe8ff"
				for i in 60:
					x.global_alpha = 0.3 + 0.5 * H(i, 9)
					x.fill_rect(H(i, 8) * w, H(i, 10) * h * 0.8, 1, 1)
				x.global_alpha = 1)
			x.composite = "lighter"
			for cur in [[0, "60,255,160", 0.26, 0.5], [1, "150,90,255", 0.34, 0.4], [2, "60,220,255", 0.2, 0.35]]:
				var ci: int = cur[0]
				var yb: float = cur[2]
				var depth := h * 0.2
				var top := func(s: float) -> float: return h * yb + sin(s * 0.009 + t * 0.45 + ci * 2) * h * 0.05 + sin(s * 0.023 + t * 0.8) * h * 0.015
				var gr := x.create_linear_gradient(0, h * yb - h * 0.07, 0, h * yb + depth)
				gr.add_color_stop(0, "rgba(%s,0)" % cur[1])
				gr.add_color_stop(0.25, "rgba(%s,%s)" % [cur[1], cur[3]])
				gr.add_color_stop(1, "rgba(%s,0)" % cur[1])
				x.fill_style = gr
				x.begin_path()
				x.move_to(0, top.call(0))
				var s := 8.0
				while s <= w + 8:
					x.line_to(s, top.call(s))
					s += 8
				s = w + 8
				while s >= 0:
					x.line_to(s, top.call(s) + depth * (0.7 + 0.3 * sin(s * 0.02 + t * 0.6 + ci)))
					s -= 8
				x.close_path()
				x.fill()
			x.composite = "source-over"
			layer(x, "aurorafg", w, h, func(): trees(x, w, h, h * 0.9, "#010204", 41))
		"emberfield":
			layer(x, "ember", w, h, func(): vgrad(x, w, h, [[0, "#0e0606"], [0.6, "#2a0c08"], [1, "#6a1c0c"]]))
			x.global_alpha = 0.35 + 0.1 * sin(t * 1.7)
			blob(x, "rgba(255,90,30,.6)", w * 0.5 - w * 0.9, h * 0.82, w * 1.8, h * 0.5)
			for i in 50:
				var ph := fmod(t * 0.12 * (0.5 + H(i, 12)) + H(i, 13), 1.0)
				x.global_alpha = sin(ph * PI)
				x.fill_style = "#ff8a3a" if i % 4 else "#ffd06a"
				var s := 1.6 if i % 5 else 2.4
				x.fill_rect(H(i, 14) * w + sin(t * 2 + i) * 10, h * (1.02 - ph), s, s)
			x.global_alpha = 1
		"crimson":
			vgrad(x, w, h, [[0, "#0a0506"], [1, "#1c080a"]])
			for i in 9:
				var cx := fmod(H(i, 15) * w + t * (8 + H(i, 16) * 10), w + 300) - 150
				var cy := h * (0.15 + 0.8 * H(i, 17)) + sin(t * 0.3 + i) * 20
				var r := 120 + 90 * H(i, 18)
				x.global_alpha = 0.55
				blob(x, "rgba(170,30,34,.55)" if i % 3 else "rgba(40,8,10,.8)", cx - r, cy - r * 0.7, r * 2, r * 1.4)
			x.global_alpha = 1
		"neongrid":
			var hz := h * 0.55
			layer(x, "neon", w, h, func():
				vgrad(x, w, h, [[0, "#07021a"], [0.55, "#2a0a4a"], [0.551, "#0a0214"], [1, "#12032a"]])
				var sx := w / 2
				var sy := h * 0.55 - 60
				for i in 9:
					var hh := 6 - i * 0.5
					if hh <= 0:
						continue
					x.fill_style = "#ff5ad8" if i % 2 else "#ffb03a"
					x.save()
					x.begin_path()
					x.arc(sx, sy, 60, PI, 0)
					x.clip()
					x.fill_rect(sx - 60, sy - 40 + i * 9, 120, hh)
					x.restore())
			x.stroke_style = "rgba(255,90,216,.7)"
			x.line_width = 1.2
			for i in range(-10, 11):
				x.begin_path()
				x.move_to(w / 2 + i * 14, hz)
				x.line_to(w / 2 + i * 120, h)
				x.stroke()
			x.stroke_style = "rgba(42,245,255,.65)"
			for k in 12:
				var f := fmod(k + t * 0.8, 12) / 12
				var y := hz + (h - hz) * f * f
				x.global_alpha = f
				x.begin_path()
				x.move_to(0, y)
				x.line_to(w, y)
				x.stroke()
			x.global_alpha = 1
		"goldrush":
			layer(x, "gold", w, h, func():
				vgrad(x, w, h, [[0, "#1a1206"], [0.6, "#4a3410"], [1, "#8a6420"]])
				var gr := x.create_radial_gradient(w / 2, h * 0.45, 0, w / 2, h * 0.45, h * 0.6)
				gr.add_color_stop(0, "rgba(255,220,120,.35)")
				gr.add_color_stop(1, "rgba(255,220,120,0)")
				x.fill_style = gr
				x.fill_rect(0, 0, w, h))
			x.composite = "lighter"
			for i in 6:
				var a := PI / 2 + (i - 2.5) * 0.28 + sin(t * 0.25 + i) * 0.06
				var L := h * 1.1
				x.global_alpha = 0.07 + 0.04 * sin(t * 0.8 + i * 1.7)
				x.fill_style = "#ffe6a0"
				x.begin_path()
				x.move_to(w / 2, -h * 0.05)
				x.line_to(w / 2 + cos(a - 0.06) * L, -h * 0.05 + sin(a - 0.06) * L)
				x.line_to(w / 2 + cos(a + 0.06) * L, -h * 0.05 + sin(a + 0.06) * L)
				x.close_path()
				x.fill()
			x.global_alpha = 1
			x.composite = "source-over"
			x.fill_style = "#ffe08a"
			for i in 40:
				var ph := fmod(t * 0.04 * (1 + H(i, 26)) + H(i, 27), 1.0)
				x.global_alpha = sin(ph * PI) * 0.8
				x.fill_rect(H(i, 28) * w + sin(t + i) * 8, h * (1 - ph), 1.4, 1.4)
			x.global_alpha = 1
			x.stroke_style = "#fff6c8"
			x.line_width = 1
			for i in 30:
				var ph := fmod(t * 0.7 + H(i, 19) * 3, 3.0)
				if ph > 0.5:
					continue
				var s := sin(ph / 0.5 * PI) * 4
				var px := H(i, 20) * w
				var py := H(i, 21) * h
				x.begin_path()
				x.move_to(px - s, py)
				x.line_to(px + s, py)
				x.move_to(px, py - s)
				x.line_to(px, py + s)
				x.stroke()
		"harvestmoon":
			layer(x, "harvest", w, h, func():
				vgrad(x, w, h, [[0, "#0c0612"], [0.6, "#2a1420"], [1, "#3a1a10"]])
				var mx := w * 0.64
				var my := h * 0.3
				var gr := x.create_radial_gradient(mx, my, 40, mx, my, 170)
				gr.add_color_stop(0, "rgba(255,150,60,.35)")
				gr.add_color_stop(1, "rgba(255,150,60,0)")
				x.fill_style = gr
				x.fill_rect(0, 0, w, h)
				x.fill_style = "#ff9a3a"
				x.begin_path()
				x.arc(mx, my, 58, 0, TAU)
				x.fill()
				x.fill_style = "rgba(200,90,30,.35)"
				for c in [[-18, -10, 12], [14, 8, 9], [-4, 22, 7]]:
					x.begin_path()
					x.arc(mx + c[0], my + c[1], c[2], 0, TAU)
					x.fill()
				fence(x, w, h * 0.86, "#0a0508")
				x.fill_style = "#0a0508"
				x.fill_rect(0, h * 0.86, w, h)
				x.stroke_style = "#0a0508"
				x.line_cap = "round"
				var tx := w * 0.18
				for br in [[9, [[tx, h * 0.87], [tx + 4, h * 0.55]]], [5, [[tx + 3, h * 0.64], [tx + 46, h * 0.5]]], [4, [[tx + 2, h * 0.6], [tx - 30, h * 0.47]]], [3, [[tx + 30, h * 0.55], [tx + 44, h * 0.43]]], [3, [[tx - 18, h * 0.51], [tx - 34, h * 0.54]]]]:
					x.line_width = br[0]
					x.begin_path()
					x.move_to(br[1][0][0], br[1][0][1])
					x.line_to(br[1][1][0], br[1][1][1])
					x.stroke())
			for i in 3:
				var cx := fmod(t * 10 * (1 + i * 0.4) + i * 220, w + 300) - 150
				x.global_alpha = 0.45
				blob(x, "rgba(30,14,24,.95)", cx - 110, h * (0.22 + 0.1 * i) - 22, 220, 44)
			x.global_alpha = 1
			x.stroke_style = "#0a0508"
			x.line_width = 2
			for i in 4:
				var ph := fmod(t * 0.07 + H(i, 22), 1.0)
				bats_line(x, w * (1.1 - ph * 1.3), h * (0.18 + 0.2 * H(i, 23)) + sin(t * 3 + i) * 10, sin(t * 22 + i * 2) * 5)
		"hauntedfog":
			layer(x, "haunt", w, h, func():
				vgrad(x, w, h, [[0, "#05040c"], [0.6, "#15122a"], [1, "#221a34"]])
				var hx := w * 0.5
				var hy := h * 0.62
				x.fill_style = "#07060e"
				x.fill_rect(hx - 70, hy - 60, 140, 70)
				x.begin_path()
				x.move_to(hx - 80, hy - 58)
				x.line_to(hx, hy - 110)
				x.line_to(hx + 80, hy - 58)
				x.fill()
				x.fill_rect(hx + 36, hy - 120, 14, 40)
				trees(x, w, h, h * 0.72, "#07060e", 51))
			var f := 0.6 + 0.4 * sin(t * 9) * sin(t * 3.1)
			x.fill_style = "rgba(255,200,110,%s)" % (0.5 + 0.4 * f)
			x.fill_rect(w * 0.5 - 24, h * 0.62 - 44, 12, 14)
			x.fill_style = "rgba(255,200,110,.25)"
			x.fill_rect(w * 0.5 + 14, h * 0.62 - 44, 12, 14)
			for L in 3:
				for i in 5:
					var cx := fmod(t * (6 + L * 6) + i * 160 + L * 70, w + 320) - 160
					var cy := h * (0.66 + L * 0.1) + sin(t * 0.4 + i + L) * 8
					x.global_alpha = 0.55 - L * 0.08
					blob(x, "rgba(170,160,210,.35)", cx - 150, cy - 35, 300, 70)
			x.fill_style = "#d8ffe8"
			for i in 3:
				var ph := fmod(t * 0.05 + H(i, 24), 1.0)
				var sx := w * H(i, 25) + sin(t + i) * 20
				var sy := h * (0.7 - ph * 0.5)
				var s := 8.0
				x.global_alpha = sin(ph * PI) * 0.5
				x.begin_path()
				x.arc(sx, sy, s, PI, 0)
				x.line_to(sx + s, sy + s * 1.3)
				x.line_to(sx, sy + s * 0.9)
				x.line_to(sx - s, sy + s * 1.3)
				x.close_path()
				x.fill()
			x.global_alpha = 1
		_:
			_scene2(x, id, w, h, t)


static func skyline_scene(x: Ctx2D, w: float, h: float) -> void:
	vgrad(x, w, h, [[0, "#05070f"], [0.6, "#121a30"], [1, "#3a2a20"]])
	x.fill_style = "#dfe8ff"
	for i in 50:
		x.global_alpha = 0.25 + 0.5 * H(i, 61)
		x.fill_rect(H(i, 62) * w, H(i, 63) * h * 0.4, 1, 1)
	x.global_alpha = 1
	var gr := x.create_radial_gradient(w / 2, h, 0, w / 2, h, h * 0.8)
	gr.add_color_stop(0, "rgba(255,170,80,.35)")
	gr.add_color_stop(1, "rgba(255,170,80,0)")
	x.fill_style = gr
	x.fill_rect(0, 0, w, h)
	for rowd in [[0, "#141a26", 0.78, 0.3, 0.35], [1, "#0e121b", 0.86, 0.42, 0.5], [2, "#080a10", 0.95, 0.6, 0.6]]:
		var row: int = rowd[0]
		var base: float = rowd[2]
		var top: float = rowd[3]
		var win: float = rowd[4]
		var px := -10.0
		var n := 0
		while px < w:
			var bw := 28 + H(n, row * 9 + 1) * 46
			var bh := h * (top + H(n, row * 9 + 2) * (base - top) * 0.6)
			var y0 := h * base - bh
			x.fill_style = rowd[1]
			x.fill_rect(px, y0, bw, h - y0)
			var wy := y0 + 6
			while wy < h * base - 6:
				var wx := px + 5
				while wx < px + bw - 5:
					if H(int(wx), int(wy)) < win:
						x.fill_style = "rgba(255,210,120,.8)" if H(int(wy), int(wx)) < 0.8 else "rgba(180,215,255,.7)"
						x.fill_rect(wx, wy, 3, 4)
					wx += 8
				wy += 9
			px += bw + 2 + H(n, row * 9 + 3) * 8
			n += 1
	x.fill_style = "#050608"
	x.fill_rect(0, h * 0.95, w, h * 0.05)
	var lx := 20.0
	while lx < w:
		x.fill_style = "#22252a"
		x.fill_rect(lx, h * 0.88, 2, h * 0.07)
		x.fill_style = "#ffe0a0"
		x.fill_rect(lx - 2, h * 0.875, 6, 3)
		x.global_alpha = 0.35
		blob(x, "rgba(255,200,110,.8)", lx - 26, h * 0.86, 54, 40)
		x.global_alpha = 1
		lx += 70


static func round_rect(x: Ctx2D, X: float, Y: float, W: float, Hh: float, r: float) -> void:
	x.begin_path()
	x.move_to(X + r, Y)
	x.arc_to(X + W, Y, X + W, Y + Hh, r)
	x.arc_to(X + W, Y + Hh, X, Y + Hh, r)
	x.arc_to(X, Y + Hh, X, Y, r)
	x.arc_to(X, Y, X + W, Y, r)
	x.close_path()


static func _scene2(x: Ctx2D, id: String, w: float, h: float, t: float) -> void:
	match id:
		"fieldmap":
			vgrad(x, w, h, [[0, "#b9a77a"], [1, "#9c8a5e"]])
			x.stroke_style = "rgba(60,50,30,.18)"
			x.line_width = 1
			var gx := 0.0
			while gx < w:
				x.begin_path()
				x.move_to(gx, 0)
				x.line_to(gx, h)
				x.stroke()
				gx += 40
			var gy := 0.0
			while gy < h:
				x.begin_path()
				x.move_to(0, gy)
				x.line_to(w, gy)
				x.stroke()
				gy += 40
			for c in [[w * 0.3, h * 0.3, 7], [w * 0.75, h * 0.62, 6]]:
				for k in range(1, c[2] + 1):
					x.stroke_style = "rgba(90,60,30,%s)" % (0.2 + 0.04 * k)
					x.line_width = 1.2
					x.begin_path()
					for a in 65:
						var an := a / 64.0 * TAU
						var r: float = k * 18 * (1 + 0.18 * sin(an * 3 + k) + 0.08 * sin(an * 5))
						x.line_to(c[0] + cos(an) * r, c[1] + sin(an) * r * 0.8)
					x.close_path()
					x.stroke()
			x.stroke_style = "#a8342a"
			x.line_width = 3
			x.set_line_dash([10, 8])
			x.begin_path()
			x.move_to(w * 0.1, h * 0.85)
			x.bezier_curve_to(w * 0.4, h * 0.7, w * 0.2, h * 0.45, w * 0.62, h * 0.38)
			x.stroke()
			x.set_line_dash([])
			x.line_width = 4
			var a := w * 0.62
			var b := h * 0.38
			x.begin_path()
			x.move_to(a - 9, b - 9)
			x.line_to(a + 9, b + 9)
			x.move_to(a + 9, b - 9)
			x.line_to(a - 9, b + 9)
			x.stroke()
			for q in [[w * 0.28, h * 0.3], [w * 0.78, h * 0.64]]:
				x.fill_style = "#2a3a22"
				x.begin_path()
				x.arc(q[0], q[1], 6, 0, TAU)
				x.fill()
			var gr := x.create_radial_gradient(w / 2, h / 2, minf(w, h) * 0.3, w / 2, h / 2, maxf(w, h) * 0.75)
			gr.add_color_stop(0, "rgba(40,30,15,0)")
			gr.add_color_stop(1, "rgba(40,30,15,.55)")
			x.fill_style = gr
			x.fill_rect(0, 0, w, h)
		"sandbags":
			vgrad(x, w, h, [[0, "#2a3448"], [0.55, "#8a6a52"], [0.7, "#d9a060"]])
			x.fill_style = "rgba(255,240,200,.9)"
			x.fill_rect(w * 0.8, h * 0.12, 2, 2)
			x.stroke_style = "#1c1812"
			x.line_width = 1.5
			x.begin_path()
			var px := 0.0
			while px <= w:
				x.line_to(px, h * 0.6 + (-5 if int(px / 12) % 2 else 5))
				px += 12
			x.stroke()
			px = 6
			while px < w:
				x.begin_path()
				x.move_to(px, h * 0.6 - 10)
				x.line_to(px, h * 0.66)
				x.stroke()
				px += 36
			var top := h * 0.66
			x.fill_style = "#2a241a"
			x.fill_rect(0, top, w, h - top)
			for row in ceili((h - top) / 26):
				for i in range(-1, int(w / 58) + 1):
					var bx := i * 58 + (29 if row % 2 else 0)
					var by := top + row * 26
					x.fill_style = "#9a8660" if row % 2 else "#a8946c"
					x.stroke_style = "#3a3024"
					x.line_width = 2
					round_rect(x, bx + 2, by + 2, 54, 23, 10)
					x.fill()
					x.stroke()
					x.stroke_style = "rgba(58,48,36,.5)"
					x.line_width = 1
					x.begin_path()
					x.move_to(bx + 10, by + 12)
					x.line_to(bx + 46, by + 12)
					x.stroke()
		"dogtags":
			vgrad(x, w, h, [[0, "#2b2e31"], [1, "#17191b"]])
			var yy := 0
			while yy < h:
				x.fill_style = "rgba(255,255,255,%s)" % (0.012 + 0.012 * H(yy, 3))
				x.fill_rect(0, yy, w, 1)
				yy += 3
			var k := minf(w / 390, h / 760) * 1.9
			x.save()
			x.translate(w * 0.5, h * 0.5)
			x.scale(k, k)
			x.fill_style = "#9aa0a6"
			for c in [[-8, -62, -2], [8, 48, 16]]:
				for n in 41:
					var f := n / 40.0
					x.begin_path()
					x.arc(c[0] + (c[1] - c[0]) * f, -150 + (c[2] + 150) * f + sin(f * PI) * -10, 1.7, 0, TAU)
					x.fill()
			for tg in [[-26, 0, -0.12], [24, 18, 0.1]]:
				x.save()
				x.translate(tg[0], tg[1])
				x.rotate(tg[2])
				var gr := x.create_linear_gradient(-45, -28, 45, 28)
				gr.add_color_stop(0, "#cfd4d8")
				gr.add_color_stop(0.5, "#8e959b")
				gr.add_color_stop(1, "#bfc5ca")
				x.fill_style = gr
				x.stroke_style = "#3a3f44"
				x.line_width = 2
				round_rect(x, -46, -28, 92, 56, 14)
				x.fill()
				x.stroke()
				x.fill_style = "#2b2e31"
				x.begin_path()
				x.arc(-36, 0, 3, 0, TAU)
				x.fill()
				x.fill_style = "rgba(40,44,48,.75)"
				x.font = "600 10px \"IBM Plex Mono\", monospace"
				var left: bool = tg[0] < 0
				x.fill_text("PALISADE", -26, -10)
				x.fill_text("CLAIM HELD" if left else "NO. 0001", -26, 4)
				x.fill_text("O POS" if left else "YARD 16", -26, 18)
				x.restore()
			x.restore()
		"watchtower":
			vgrad(x, w, h, [[0, "#04060c"], [1, "#141c2c"]])
			x.fill_style = "#e8eeff"
			for i in 60:
				x.global_alpha = 0.3 + 0.6 * H(i, 31)
				x.fill_rect(H(i, 32) * w, H(i, 33) * h * 0.6, 1, 1)
			x.global_alpha = 1
			var tx := w * 0.34
			var base := h * 0.82
			x.composite = "lighter"
			var gr := x.create_linear_gradient(tx, h * 0.36, w, h * 0.2)
			gr.add_color_stop(0, "rgba(255,240,190,.35)")
			gr.add_color_stop(1, "rgba(255,240,190,0)")
			x.fill_style = gr
			x.begin_path()
			x.move_to(tx + 8, h * 0.37)
			x.line_to(w * 1.1, h * 0.1)
			x.line_to(w * 1.1, h * 0.34)
			x.close_path()
			x.fill()
			x.composite = "source-over"
			x.stroke_style = "#07090e"
			x.line_width = 5
			x.begin_path()
			x.move_to(tx - 30, base)
			x.line_to(tx - 16, h * 0.4)
			x.move_to(tx + 30, base)
			x.line_to(tx + 16, h * 0.4)
			x.stroke()
			x.line_width = 2.5
			for k in 4:
				var y0 := base - k * (base - h * 0.42) / 4
				var y1 := y0 - (base - h * 0.42) / 4
				x.begin_path()
				x.move_to(tx - 30 + k * 3.5, y0)
				x.line_to(tx + 26 - k * 3.5, y1)
				x.stroke()
			x.fill_style = "#07090e"
			x.fill_rect(tx - 26, h * 0.34, 52, 26)
			x.begin_path()
			x.move_to(tx - 32, h * 0.34)
			x.line_to(tx, h * 0.29)
			x.line_to(tx + 32, h * 0.34)
			x.fill()
			x.fill_style = "#ffd88a"
			x.fill_rect(tx - 8, h * 0.35, 10, 8)
			trees(x, w, h, h * 0.88, "#050709", 61)
		"searchlight":
			layer(x, "search", w, h, func():
				vgrad(x, w, h, [[0, "#03050a"], [1, "#10182a"]])
				x.fill_style = "#e8eeff"
				for i in 70:
					x.global_alpha = 0.3 + 0.6 * H(i, 34)
					x.fill_rect(H(i, 35) * w, H(i, 36) * h * 0.7, 1, 1)
				x.global_alpha = 1)
			x.composite = "lighter"
			for sl in [[w * 0.2, 0.0, 0.5], [w * 0.8, 2.1, 0.37]]:
				var ox: float = sl[0]
				var a: float = -PI / 2 + sin(t * sl[2] + sl[1]) * 0.7
				var L := h * 1.2
				var oy := h * 0.8
				var gr := x.create_radial_gradient(ox, oy, 0, ox, oy, L)
				gr.add_color_stop(0, "rgba(255,245,210,.45)")
				gr.add_color_stop(1, "rgba(255,245,210,0)")
				x.fill_style = gr
				x.begin_path()
				x.move_to(ox, oy)
				x.line_to(ox + cos(a - 0.09) * L, oy + sin(a - 0.09) * L)
				x.line_to(ox + cos(a + 0.09) * L, oy + sin(a + 0.09) * L)
				x.close_path()
				x.fill()
				x.fill_style = "#fff6d8"
				for i in 14:
					var d := fmod(H(i, int(37 + ox)) * L * 0.8 + t * 20, L * 0.8)
					var sp2 := (H(i, 38) - 0.5) * 0.14
					x.global_alpha = 0.6 * (1 - d / L)
					x.fill_rect(ox + cos(a + sp2) * d, oy + sin(a + sp2) * d, 1.5, 1.5)
				x.global_alpha = 1
			x.composite = "source-over"
			layer(x, "searchfg", w, h, func():
				fence(x, w, h * 0.84, "#05070b")
				x.fill_style = "#05070b"
				x.fill_rect(0, h * 0.84, w, h)
				for lpx in [w * 0.2, w * 0.8]:
					x.fill_rect(lpx - 6, h * 0.78, 12, h * 0.06)
					x.begin_path()
					x.arc(lpx, h * 0.8, 9, PI, 0)
					x.fill())
		"sunsetfade":
			vgrad(x, w, h, [[0, "#2a0a3a"], [0.45, "#ff5ad8"], [0.72, "#ffa03a"], [0.721, "#3a0a3a"], [1, "#1a0520"]])
			var cx := w / 2
			var cy := h * 0.6
			var r := minf(w * 0.35, 120)
			x.save()
			x.begin_path()
			x.arc(cx, cy, r, PI, 0)
			x.clip()
			var gr := x.create_linear_gradient(0, cy - r, 0, cy)
			gr.add_color_stop(0, "#fff0a0")
			gr.add_color_stop(1, "#ff6a4a")
			x.fill_style = gr
			x.fill_rect(cx - r, cy - r, r * 2, r)
			x.fill_style = "rgba(42,10,58,.9)"
			for k in 7:
				x.fill_rect(cx - r, cy - r * 0.55 + k * r * 0.08, r * 2, 2 + k * 1.2)
			x.restore()
			x.fill_style = "#2a0830"
			x.begin_path()
			x.move_to(0, h * 0.72)
			var px := 0.0
			while px <= w + 0.01:
				x.line_to(px, h * 0.72 - (sin(px * 0.03) + 1) * h * 0.05 - H(int(px), 2) * h * 0.03)
				px += w / 8
			x.line_to(w, h)
			x.line_to(0, h)
			x.fill()
		"lagoonwaves":
			vgrad(x, w, h, [[0, "#0a2a3a"], [1, "#062038"]])
			for k in 9:
				var y0 := h * (0.25 + k * 0.09)
				x.fill_style = CosFx.hsl(160 + k * 6, 0.9, (55 - k * 3) / 100.0, 0.9)
				x.begin_path()
				x.move_to(0, h)
				var px := 0.0
				while px <= w + 10:
					x.line_to(px, y0 + sin(px * 0.025 + k * 1.3) * 12 + sin(px * 0.06 + k) * 4)
					px += 10
				x.line_to(w, h)
				x.close_path()
				x.global_alpha = 0.35 + k * 0.05
				x.fill()
			x.global_alpha = 1
		"nebula":
			vgrad(x, w, h, [[0, "#07031a"], [1, "#12062a"]])
			x.composite = "lighter"
			for i in 14:
				var r := 80 + H(i, 40) * 140
				blob(x, ["rgba(192,122,255,.5)", "rgba(58,106,255,.45)", "rgba(255,138,216,.4)"][i % 3], w * (0.1 + 0.8 * H(i, 41)) - r, h * (0.15 + 0.7 * H(i, 42)) - r * 0.7, r * 2, r * 1.4)
			x.composite = "source-over"
			for i in 120:
				x.global_alpha = 0.4 + 0.6 * H(i, 43)
				x.fill_style = "#ffffff" if i % 11 else "#ffd8f0"
				var s := 1.0 if i % 13 else 2.0
				x.fill_rect(H(i, 44) * w, H(i, 45) * h, s, s)
			x.global_alpha = 1
		"arcade":
			vgrad(x, w, h, [[0, "#0a0620"], [1, "#140a30"]])
			var px := maxf(4, roundf(w / 60))
			var inv := ["0010000100", "0001001000", "0011111100", "0110110110", "1111111111", "1011111101", "1010000101", "0001101100"]
			var cols := ["#3affd8", "#ff3ad0", "#ffe03a", "#6a8aff"]
			for r in 4:
				for c in 3:
					var ox := w * (0.12 + c * 0.3)
					var oy := h * (0.14 + r * 0.13)
					x.fill_style = cols[(r + c) % 4]
					for j in inv.size():
						for i in inv[j].length():
							if inv[j][i] == "1":
								x.fill_rect(ox + i * px * 0.7, oy + j * px * 0.7, px * 0.7, px * 0.7)
			x.fill_style = "#ffe03a"
			x.font = "700 %dpx \"IBM Plex Mono\", monospace" % roundi(w / 14)
			x.text_align = "center"
			x.fill_text("INSERT COIN", w / 2, h * 0.8)
			x.text_align = "left"
			x.fill_style = "rgba(0,0,0,.28)"
			var yy := 0.0
			while yy < h:
				x.fill_rect(0, yy, w, 1)
				yy += 3
		"neonpulse":
			layer(x, "neonp", w, h, func():
				vgrad(x, w, h, [[0, "#0a0412"], [1, "#1a0624"]])
				x.fill_style = "#07030c"
				for i in 14:
					var bw := w / 10
					var bh := h * (0.12 + 0.3 * H(i, 46))
					x.fill_rect(i * bw * 0.8 - 10, h * 0.85 - bh, bw * 0.7, bh + h))
			x.composite = "lighter"
			for k in 3:
				var ph := fmod(t * 0.35 + k / 3.0, 1.0)
				x.global_alpha = (1 - ph) * 0.7
				x.stroke_style = "#2af5ff" if k % 2 else "#ff3ad0"
				x.line_width = 3
				x.begin_path()
				x.arc(w / 2, h * 0.4, maxf(0.01, ph * maxf(w, h) * 0.7), 0, TAU)
				x.stroke()
			x.global_alpha = 0.6 + 0.4 * sin(t * 6)
			x.stroke_style = "#ff3ad0"
			x.line_width = 2
			for i in 14:
				if i % 3:
					continue
				var bw := w / 10
				var bh := h * (0.12 + 0.3 * H(i, 46))
				x.stroke_rect(i * bw * 0.8 - 10, h * 0.85 - bh, bw * 0.7, bh)
			x.global_alpha = 1
			x.composite = "source-over"
		"eventhorizon":
			layer(x, "horizon", w, h, func():
				vgrad(x, w, h, [[0, "#030208"], [1, "#0a0414"]])
				x.fill_style = "#ffffff"
				for i in 120:
					x.global_alpha = 0.3 + 0.6 * H(i, 47)
					x.fill_rect(H(i, 48) * w, H(i, 49) * h, 1, 1)
				x.global_alpha = 1)
			var cx := w / 2
			var cy := h * 0.42
			var R := minf(w, h) * 0.42
			x.composite = "lighter"
			for k in 26:
				var a0 := t * (0.6 + k * 0.02) + k * 0.9
				var rr := R * (1 + 0.05 * (k % 5))
				x.stroke_style = "rgba(176,106,255,%s)" % (0.18 + 0.1 * (k % 4)) if k % 3 else "rgba(255,160,80,.25)"
				x.line_width = 2 + k % 3
				x.begin_path()
				x.ellipse(cx, cy, rr, rr * 0.32, -0.2, a0, a0 + 1.4)
				x.stroke()
			for k in 5:
				x.stroke_style = "rgba(255,170,90,%s)" % (0.22 - k * 0.03) if k % 2 else "rgba(255,120,200,%s)" % (0.2 - k * 0.03)
				x.line_width = 6 - k
				var rr := R * (0.7 + k * 0.03)
				var sp := sin(t * 1.3 + k) * 0.05
				x.begin_path()
				x.ellipse(cx, cy, rr, rr * 0.92, 0, PI * (1.05 + sp), PI * (1.95 - sp))
				x.stroke()
				x.begin_path()
				x.ellipse(cx, cy, rr, rr * 0.55, 0, PI * (0.12 + sp), PI * (0.88 - sp))
				x.stroke()
			x.composite = "source-over"
			var gr := x.create_radial_gradient(cx, cy, R * 0.3, cx, cy, R * 0.62)
			gr.add_color_stop(0, "#000")
			gr.add_color_stop(0.85, "#000")
			gr.add_color_stop(1, "rgba(255,150,90,.7)")
			x.fill_style = gr
			x.begin_path()
			x.arc(cx, cy, R * 0.62, 0, TAU)
			x.fill()
			x.composite = "lighter"
			for k in 10:
				var a0 := t * (0.6 + k * 0.02) + k * 0.9
				x.stroke_style = "rgba(255,170,90,.25)" if k % 3 else "rgba(176,106,255,.3)"
				x.line_width = 2 + k % 3
				var st := maxf(fmod(a0, TAU), 0.1)
				x.begin_path()
				x.ellipse(cx, cy, R * (1 + 0.04 * (k % 5)), R * (1 + 0.04 * (k % 5)) * 0.32, -0.2, st, st + 0.9)
				x.stroke()
			x.composite = "source-over"
		"goldaurora":
			layer(x, "gaur", w, h, func(): vgrad(x, w, h, [[0, "#0a0804"], [1, "#1a1408"]]))
			x.composite = "lighter"
			for ci in 4:
				var top := func(s: float) -> float: return h * (0.2 + ci * 0.07) + sin(s * 0.009 + t * 0.5 + ci * 1.7) * h * 0.05
				var depth := h * 0.24
				var hue := fmod(t * 30 + ci * 60, 360)
				var gr := x.create_linear_gradient(0, h * 0.15, 0, h * 0.6)
				gr.add_color_stop(0, "rgba(0,0,0,0)")
				gr.add_color_stop(0.3, CosFx.hsl(hue, 0.9, 0.65, 0.28) if ci else CosFx.col("rgba(255,215,110,.45)"))
				gr.add_color_stop(1, "rgba(0,0,0,0)")
				x.fill_style = gr
				x.begin_path()
				x.move_to(0, top.call(0))
				var s := 8.0
				while s <= w + 8:
					x.line_to(s, top.call(s))
					s += 8
				s = w + 8
				while s >= 0:
					x.line_to(s, top.call(s) + depth)
					s -= 8
				x.close_path()
				x.fill()
			x.composite = "source-over"
			x.stroke_style = "#fff6c8"
			x.line_width = 1.1
			for i in 34:
				var ph := fmod(t * 0.8 + H(i, 50) * 3, 3.0)
				if ph > 0.45:
					continue
				var s := sin(ph / 0.45 * PI) * 4.5
				var px := H(i, 51) * w
				var py := H(i, 52) * h
				x.begin_path()
				x.move_to(px - s, py)
				x.line_to(px + s, py)
				x.move_to(px, py - s)
				x.line_to(px, py + s)
				x.stroke()
		"graveyard":
			vgrad(x, w, h, [[0, "#0a0c14"], [0.7, "#1c2230"], [1, "#12141a"]])
			x.fill_style = "rgba(230,235,210,.85)"
			x.begin_path()
			x.arc(w * 0.78, h * 0.18, 26, 0, TAU)
			x.fill()
			for row in 3:
				for i in 6:
					var gx := w * (0.05 + i * 0.18) + row * 18 + H(i, row + 60) * 12
					var base := h * (0.66 + row * 0.1)
					var gh := 34 + row * 10 + H(i, row + 61) * 14
					var gw := 22.0 + row * 6
					x.fill_style = ["#2a2e38", "#20242c", "#161a20"][row]
					if (i + row) % 4 == 2:
						x.fill_rect(gx - 3, base - gh, 6, gh)
						x.fill_rect(gx - 12, base - gh * 0.75, 24, 6)
					else:
						x.begin_path()
						x.move_to(gx - gw / 2, base)
						x.line_to(gx - gw / 2, base - gh + gw / 2)
						x.arc(gx, base - gh + gw / 2, gw / 2, PI, 0)
						x.line_to(gx + gw / 2, base)
						x.fill()
			x.fill_style = "#0c0e12"
			x.fill_rect(0, h * 0.9, w, h)
			for i in 6:
				x.global_alpha = 0.5
				blob(x, "rgba(190,200,220,.4)", i * w / 5 - 90, h * (0.74 + 0.06 * (i % 2)), 200, 60)
			x.global_alpha = 1
		"witchbrew":
			vgrad(x, w, h, [[0, "#07050c"], [1, "#141022"]])
			trees(x, w, h, h * 0.7, "#050409", 71)
			var cx := w / 2
			var cy := h * 0.76
			x.composite = "lighter"
			blob(x, "rgba(60,255,120,.55)", cx - 160, cy - 260, 320, 300)
			x.composite = "source-over"
			x.fill_style = "#0e0c10"
			x.begin_path()
			x.ellipse(cx, cy, 78, 52, 0, 0, TAU)
			x.fill()
			x.fill_style = "#2aff6a"
			x.begin_path()
			x.ellipse(cx, cy - 40, 66, 12, 0, 0, TAU)
			x.fill()
			x.fill_style = "#b8ff8a"
			for c in [[-20, -44, 6], [14, -46, 4], [34, -42, 3], [-2, -60, 5], [8, -82, 3], [-14, -100, 2]]:
				x.global_alpha = 0.8
				x.begin_path()
				x.arc(cx + c[0], cy + c[1], c[2], 0, TAU)
				x.fill()
			x.global_alpha = 1
			x.stroke_style = "#0e0c10"
			x.line_width = 6
			for d in [-50, 50]:
				x.begin_path()
				x.move_to(cx + d, cy + 30)
				x.line_to(cx + d * 1.3, cy + 62)
				x.stroke()
			x.fill_style = "#ff7a1a"
			x.global_alpha = 0.8
			x.begin_path()
			x.move_to(cx - 40, cy + 64)
			x.quadratic_curve_to(cx, cy + 30, cx + 40, cy + 64)
			x.fill()
			x.global_alpha = 1
		"bloodmoon":
			layer(x, "blood", w, h, func():
				vgrad(x, w, h, [[0, "#0c0204"], [0.6, "#2a060a"], [1, "#140306"]])
				var mx := w * 0.5
				var my := h * 0.32
				var gr := x.create_radial_gradient(mx, my, 50, mx, my, 220)
				gr.add_color_stop(0, "rgba(255,40,40,.35)")
				gr.add_color_stop(1, "rgba(255,40,40,0)")
				x.fill_style = gr
				x.fill_rect(0, 0, w, h)
				x.fill_style = "#c41e24"
				x.begin_path()
				x.arc(mx, my, 70, 0, TAU)
				x.fill()
				x.fill_style = "rgba(90,0,8,.45)"
				for c in [[-24, -12, 15], [18, 14, 11], [-6, 28, 8], [26, -26, 7]]:
					x.begin_path()
					x.arc(mx + c[0], my + c[1], c[2], 0, TAU)
					x.fill()
				trees(x, w, h, h * 0.84, "#070103", 81))
			x.stroke_style = "#070103"
			x.line_width = 2
			for i in 9:
				var an := t * (0.8 + i * 0.07) + i * 0.7
				var rx := w * 0.5 + cos(an) * (90 + i * 9)
				var ry := h * 0.32 + sin(an * 1.3) * (40 + i * 5)
				var f := sin(t * 20 + i * 2) * 4
				x.begin_path()
				x.move_to(rx - 8, ry - f)
				x.line_to(rx - 3, ry)
				x.line_to(rx, ry - 2)
				x.line_to(rx + 3, ry)
				x.line_to(rx + 8, ry - f)
				x.stroke()
			for i in 5:
				var cx := fmod(t * 12 + i * 170, w + 320) - 160
				x.global_alpha = 0.6
				blob(x, "rgba(160,20,30,.4)", cx - 150, h * (0.78 + 0.05 * (i % 2)) - 35, 300, 70)
			x.global_alpha = 1
		"scorched":
			vgrad(x, w, h, [[0, "#1a0f10"], [0.42, "#5a2414"], [0.62, "#c0561e"], [0.66, "#3a1a12"], [1, "#120a08"]])
			for i in 5:
				var cx := w * (0.12 + 0.2 * i + H(i, 91) * 0.06)
				var by := h * 0.64
				for k in 6:
					x.global_alpha = 0.5 - k * 0.06
					blob(x, "rgba(30,20,20,.85)", cx - 40 - k * 14 + sin(k + i) * 10, by - 60 - k * 48, 80 + k * 28, 70 + k * 20)
			x.global_alpha = 1
			x.fill_style = "#0d0806"
			x.begin_path()
			x.move_to(0, h * 0.66)
			var px := 0.0
			while px <= w + 0.01:
				var q := px / w
				var mid := q > 0.28 and q < 0.72
				var hh := (h * 0.12 if mid else h * 0.05) * (1.25 if mid and floori(q * 24) % 2 else 1.0) + H(floori(q * 24), 92) * h * 0.03
				x.line_to(px, h * 0.66 - hh)
				px += w / 24
			x.line_to(w, h)
			x.line_to(0, h)
			x.close_path()
			x.fill()
			for i in 9:
				var fx := w * H(i, 93)
				var fy := h * (0.6 + 0.06 * H(i, 94))
				x.global_alpha = 0.7
				blob(x, "rgba(255,120,40,.7)", fx - 30, fy - 24, 60, 40)
				x.global_alpha = 1
				x.fill_style = "#ffb040" if i % 2 else "#ff6a1a"
				x.begin_path()
				x.move_to(fx - 5, fy + 4)
				x.quadratic_curve_to(fx, fy - 14 - H(i, 95) * 10, fx + 5, fy + 4)
				x.fill()
			x.fill_style = "rgba(255,140,60,.08)"
			for k in 6:
				x.fill_rect(0, h * 0.57 + k * 5, w, 2)
			for i in 60:
				x.global_alpha = 0.3 + 0.6 * H(i, 96)
				x.fill_style = "#ff8a3a" if i % 3 else "#ffd06a"
				x.fill_rect(H(i, 97) * w, H(i, 98) * h * 0.8, 1.6, 1.6)
			x.global_alpha = 1
		"hellgate":
			hellgate(x, w, h, t)


# ---------------------------------------------------------------- Hellgate

static func hellgate(x: Ctx2D, w: float, h: float, t: float) -> void:
	var gx := w * 0.5
	var gy := h * 0.5
	var G := minf(w * 0.5, h * 0.86)
	layer(x, "hellgate", w, h, func(): hellgate_scene(x, w, h))
	var pulse := 0.5 + 0.5 * sin(t * 1.7)
	var vr := G * 0.3
	var vy := gy - G * 0.06
	x.save()
	x.composite = "lighter"
	x.global_alpha = 0.5 + 0.3 * pulse
	blob(x, "rgba(255,60,20,.8)", gx - vr * 1.9, vy - vr * 1.9, vr * 3.8, vr * 3.8)
	for k in 3:
		x.save()
		x.global_alpha = 0.55 - 0.12 * k
		x.translate(gx, vy)
		x.rotate(t * (0.35 + k * 0.22) * (-1 if k % 2 else 1))
		x.scale(1, 0.92)
		x.scale(vr / 96, vr / 96)
		hell_spiral(x, k)
		x.restore()
	x.restore()
	var ph := fmod(t, 7) / 7
	if ph > 0.62 and ph < 0.78:
		var k := (ph - 0.62) / 0.16
		x.global_alpha = sin(k * PI) * 0.55
		hell_silhouette(x, gx, vy + vr * 0.35, vr * 0.62, floori(t / 7) % 5)
		x.global_alpha = 1
	var sw := fmod(t, 6) / 6
	if sw < 0.32:
		var k := sw / 0.32
		var ax := -w * 0.1 + w * 1.2 * k
		var ay := h * (0.18 + 0.1 * sin(k * PI))
		x.save()
		x.composite = "lighter"
		for q in [[16, "rgba(40,200,220,.25)"], [7, "rgba(90,240,255,.8)"], [2.4, "#eaffff"]]:
			x.stroke_style = q[1]
			x.line_width = q[0]
			x.begin_path()
			x.arc(ax - 40, ay, 70, -0.75, 0.75)
			x.stroke()
		x.global_alpha = 0.8
		x.stroke_style = "rgba(90,240,255,.6)"
		x.line_width = 2
		x.begin_path()
		x.move_to(-w * 0.1, h * 0.2)
		var q := 0.0
		while q <= k:
			x.line_to(-w * 0.1 + w * 1.2 * q, h * (0.18 + 0.1 * sin(q * PI)))
			q += 0.05
		x.stroke()
		x.restore()
	elif sw < 0.5:
		var k := (sw - 0.32) / 0.18
		x.save()
		x.composite = "lighter"
		x.global_alpha = (1 - k) * 0.7
		x.stroke_style = "rgba(90,240,255,.7)"
		x.line_width = 3 * (1 - k) + 0.5
		x.begin_path()
		var q := 0.0
		while q <= 1.0001:
			var px := -w * 0.1 + w * 1.2 * q
			var py := h * (0.18 + 0.1 * sin(q * PI)) + sin(q * 40 + t * 9) * 2 * (1 - k)
			if q > 0:
				x.line_to(px, py)
			else:
				x.move_to(px, py)
			q += 0.04
		x.stroke()
		x.restore()
	for i in 40:
		var p2 := fmod(t * 0.1 * (0.5 + H(i, 101)) + H(i, 102), 1.0)
		x.global_alpha = sin(p2 * PI) * 0.9
		x.fill_style = "#bdb4ac" if i % 5 == 0 else ("#ff7a2a" if i % 3 else "#ffd070")
		var s := 1.6 if i % 4 else 2.4
		x.fill_rect(H(i, 103) * w + sin(t * 1.6 + i) * 12, h * (1.02 - p2 * 0.95), s, s)
	x.global_alpha = 1


static func hellgate_scene(x: Ctx2D, w: float, h: float) -> void:
	vgrad(x, w, h, [[0, "#050103"], [0.45, "#2a0608"], [0.6, "#6a1a0c"], [0.64, "#1a0606"], [1, "#080203"]])
	var gx := w * 0.5
	var gy := h * 0.5
	var G := minf(w * 0.5, h * 0.86)
	var hz := h * 0.62
	x.fill_style = "#120406"
	x.begin_path()
	x.move_to(0, hz)
	var px := 0.0
	while px <= w + 0.01:
		x.line_to(px, hz - h * (0.05 + 0.09 * H(roundi(px / w * 30), 111)) - (0.0 if absf(px - gx) < G * 0.7 else h * 0.03))
		px += w / 30
	x.line_to(w, hz + 2)
	x.line_to(0, hz + 2)
	x.close_path()
	x.fill()
	var vr := G * 0.3
	var vy := gy - G * 0.06
	var gr := x.create_radial_gradient(gx, vy, 0, gx, vy, vr)
	gr.add_color_stop(0, "#ffb040")
	gr.add_color_stop(0.35, "#c8200a")
	gr.add_color_stop(1, "#1a0204")
	x.fill_style = gr
	x.begin_path()
	x.arc(gx, vy, vr, 0, TAU)
	x.fill()
	var pw := G * 0.13
	var px0 := gx - vr - pw * 0.75
	var px1 := gx + vr - pw * 0.25
	var top := vy - vr * 1.25
	x.fill_style = "#231012"
	for p in [px0, px1]:
		x.fill_rect(p, top, pw, hz - top + h * 0.03)
		x.begin_path()
		x.move_to(p - pw * 0.2, top)
		x.line_to(p + pw * 0.5, top - G * 0.12)
		x.line_to(p + pw * 1.2, top)
		x.close_path()
		x.fill()
	x.begin_path()
	x.move_to(px0, top + G * 0.04)
	x.quadratic_curve_to(gx, vy - vr * 2.1, px1 + pw, top + G * 0.04)
	x.line_to(px1 + pw, top + G * 0.14)
	x.quadratic_curve_to(gx, vy - vr * 1.55, px0, top + G * 0.14)
	x.close_path()
	x.fill()
	for sd in [-1, 1]:
		x.begin_path()
		x.move_to(gx + sd * vr * 0.3, vy - vr * 1.45)
		x.quadratic_curve_to(gx + sd * vr * 0.9, vy - vr * 2.1, gx + sd * vr * 1.3, vy - vr * 1.95)
		x.quadratic_curve_to(gx + sd * vr * 0.8, vy - vr * 1.8, gx + sd * vr * 0.5, vy - vr * 1.36)
		x.close_path()
		x.fill()
	x.fill_style = "rgba(255,90,40,.18)"
	for p in [px0, px1]:
		x.fill_rect(p + pw * 0.82, top, pw * 0.18, hz - top)
	x.stroke_style = "rgba(255,110,30,.75)"
	x.line_width = 1.4
	x.line_join = "round"
	for i in 14:
		var pl := px0 if i % 2 else px1
		var sx := pl + pw * (0.2 + 0.6 * H(i, 112))
		var sy := top + (hz - top) * H(i, 113)
		x.begin_path()
		x.move_to(sx, sy)
		var cx := sx
		var cy := sy
		for k in 4:
			cx += (H(i * 7 + k, 114) - 0.5) * pw * 0.5
			cy += G * 0.05 * (H(i * 7 + k, 115) + 0.3)
			x.line_to(clampf(cx, pl + 2, pl + pw - 2), cy)
		x.stroke()
	x.stroke_style = "rgba(255,150,60,.5)"
	x.line_width = 2.2
	x.begin_path()
	x.arc(gx, vy, vr + 2, 0, TAU)
	x.stroke()
	x.fill_style = "#050203"
	for b in [[0.0, w * 0.24, h * 0.2], [w * 0.78, w * 0.22, h * 0.23]]:
		var sx: float = b[0]
		var sw2: float = b[1]
		var sh: float = b[2]
		x.begin_path()
		x.move_to(sx, h)
		x.line_to(sx, h - sh)
		for q in 6:
			var qx := sx + sw2 * q / 6
			x.line_to(qx, h - sh - (0.0 if q % 2 else h * 0.035) - H(q + sx, 116) * h * 0.02)
			x.line_to(qx + sw2 / 6, h - sh - (0.0 if q % 2 else h * 0.035))
		x.line_to(sx + sw2, h - sh * 0.6 + H(sx, 117) * h * 0.05)
		x.line_to(sx + sw2, h)
		x.close_path()
		x.fill()
	x.stroke_style = "rgba(255,90,20,.45)"
	x.line_width = 1.3
	for i in 8:
		var sx := w * H(i, 118)
		var sy := h * (0.72 + 0.22 * H(i, 119))
		x.begin_path()
		x.move_to(sx, sy)
		x.line_to(sx + (H(i, 120) - 0.5) * 60, sy + 8 + H(i, 121) * 14)
		x.stroke()


## one of the vortex's three hellfire spirals, in a 192-unit frame centred on the origin
static func hell_spiral(x: Ctx2D, k: int) -> void:
	var cols: Array = [["rgba(255,190,80,.9)", "rgba(255,90,20,.7)"], ["rgba(255,120,40,.8)", "rgba(180,20,10,.6)"], ["rgba(255,220,140,.7)", "rgba(255,70,20,.5)"]][k]
	x.line_cap = "round"
	for arm in 3:
		x.begin_path()
		for q in 61:
			var a := arm * TAU / 3 + q * 0.09 + k
			var r := 4 + q * 1.45
			if q:
				x.line_to(cos(a) * r, sin(a) * r)
			else:
				x.move_to(cos(a) * r, sin(a) * r)
		x.stroke_style = cols[arm % 2]
		x.line_width = 5 - k
		x.stroke()


static func hell_silhouette(x: Ctx2D, cx: float, by: float, s: float, i: int) -> void:
	x.fill_style = "#0a0204"
	x.begin_path()
	x.ellipse(cx, by - s * 0.62, s * 0.16, s * 0.16, 0, 0, TAU)
	x.fill()
	x.begin_path()
	x.move_to(cx - s * 0.24, by - s * 0.46)
	x.line_to(cx + s * 0.24, by - s * 0.46)
	x.line_to(cx + s * 0.18, by)
	x.line_to(cx - s * 0.18, by)
	x.close_path()
	x.fill()
	x.stroke_style = "#0a0204"
	x.line_width = s * 0.07
	x.line_cap = "round"
	x.begin_path()
	if i == 0:
		x.move_to(cx + s * 0.2, by - s * 0.4)
		x.line_to(cx + s * 0.62, by - s * 0.95)
	elif i == 1 or i == 3:
		x.move_to(cx - s * 0.1, by - s * 0.5)
		x.line_to(cx + s * 0.6, by - s * 0.6)
	elif i == 2:
		x.move_to(cx + s * 0.1, by - s * 0.3)
		x.line_to(cx + s * 0.62, by - s * 0.42)
	else:
		x.move_to(cx + s * 0.2, by - s * 0.28)
		x.line_to(cx + s * 0.55, by - s * 0.2)
	x.stroke()


# ---------------------------------------------------------------- flags

static func star5(x: Ctx2D, cx: float, cy: float, r: float, col, rot: float = -PI / 2) -> void:
	x.fill_style = col
	x.begin_path()
	for i in 10:
		var a := rot + i * PI / 5
		var rr := r * 0.382 if i % 2 else r
		if i:
			x.line_to(cx + cos(a) * rr, cy + sin(a) * rr)
		else:
			x.move_to(cx + cos(a) * rr, cy + sin(a) * rr)
	x.close_path()
	x.fill()


static func draw_flag(x: Ctx2D, id: String, W: float, Hh: float) -> void:
	var U := minf(Hh, W / 1.5)
	var tri := minf(Hh * 0.866, W * 0.56)
	var hw := func(pairs: Array) -> void:
		var tot := 0.0
		for p in pairs:
			tot += p[1]
		var y := 0.0
		for p in pairs:
			x.fill_style = p[0]
			x.fill_rect(0, floorf(y), W, ceilf(Hh * p[1] / tot) + 1)
			y += Hh * p[1] / tot
	var hs := func(cols: Array) -> void: hw.call(cols.map(func(c): return [c, 1.0]))
	var vs := func(cols: Array, wt: Array = []) -> void:
		var ww: Array = wt if not wt.is_empty() else cols.map(func(_c): return 1.0)
		var tot := 0.0
		for v in ww:
			tot += v
		var px := 0.0
		for i in cols.size():
			x.fill_style = cols[i]
			x.fill_rect(floorf(px), 0, ceilf(W * ww[i] / tot) + 1, Hh)
			px += W * ww[i] / tot
	var disc := func(cx: float, cy: float, r: float, c: String) -> void:
		x.fill_style = c
		x.begin_path()
		x.arc(cx, cy, r, 0, TAU)
		x.fill()
	var B: Array = []
	for f in PalLocker.catalog().get("FLAGS", []):
		if f[0] == id:
			B = f[3]
	match id:
		"progress":
			hs.call(["#e40303", "#ff8c00", "#ffed00", "#008026", "#004dff", "#750787"])
			var b := W * 0.062
			for ck in [["#000000", 4], ["#613915", 3], ["#5bcefa", 2], ["#f5a9b8", 1], ["#ffffff", 0]]:
				var d: float = b * ck[1]
				poly(x, [[0, 0], [d, 0], [d + minf(Hh / 2, W * 0.32), Hh / 2], [d, Hh], [0, Hh]], ck[0])
		"bi":
			hw.call([["#d60270", 2.0], ["#9b4f96", 1.0], ["#0038a8", 2.0]])
		"intersex":
			x.fill_style = "#ffd800"
			x.fill_rect(0, 0, W, Hh)
			x.stroke_style = "#7902aa"
			x.line_width = U * 0.075
			x.begin_path()
			x.arc(W / 2, Hh / 2, U * 0.22, 0, TAU)
			x.stroke()
		"usa":
			for i in 13:
				x.fill_style = "#ffffff" if i % 2 else "#b22234"
				x.fill_rect(0, floorf(i * Hh / 13), W, ceilf(Hh / 13) + 1)
			var cw := W * 0.4
			var ch := Hh * 7 / 13
			x.fill_style = "#3c3b6e"
			x.fill_rect(0, 0, cw, ch)
			for r in 9:
				var n := 5 if r % 2 else 6
				for k in n:
					star5(x, cw * ((2 if r % 2 else 1) + k * 2) / 12, ch * (r + 1) / 10, minf(ch * 0.042, cw * 0.035), "#ffffff")
		"mexico":
			vs.call(B)
			x.fill_style = "#8a5a2a"
			x.begin_path()
			x.ellipse(W / 2, Hh * 0.5 - U * 0.03, U * 0.09, U * 0.12, 0, 0, TAU)
			x.fill()
			x.stroke_style = "#2e7a3a"
			x.line_width = U * 0.025
			x.begin_path()
			x.arc(W / 2, Hh * 0.5, U * 0.15, PI * 0.15, PI * 0.85)
			x.stroke()
			x.fill_style = "#5a3a1a"
			x.begin_path()
			x.ellipse(W / 2 - U * 0.05, Hh * 0.5 - U * 0.1, U * 0.035, U * 0.05, -0.5, 0, TAU)
			x.fill()
		"brazil":
			x.fill_style = "#009c3b"
			x.fill_rect(0, 0, W, Hh)
			poly(x, [[W / 2 - U * 0.6225, Hh / 2], [W / 2, Hh / 2 - U * 0.415], [W / 2 + U * 0.6225, Hh / 2], [W / 2, Hh / 2 + U * 0.415]], "#ffdf00")
			var r := U * 0.25
			disc.call(W / 2, Hh / 2, r, "#002776")
			x.save()
			x.begin_path()
			x.arc(W / 2, Hh / 2, r, 0, TAU)
			x.clip()
			x.stroke_style = "#ffffff"
			x.line_width = r * 0.16
			x.begin_path()
			x.arc(W / 2 - r * 0.3, Hh / 2 + r * 1.6, r * 1.9, -PI * 0.68, -PI * 0.28)
			x.stroke()
			x.restore()
			for i in 9:
				disc.call(W / 2 + (H(i, 71) - 0.5) * r * 1.3, Hh / 2 + r * 0.15 + H(i, 72) * r * 0.6, r * 0.03, "#ffffff")
		"japan":
			x.fill_style = "#ffffff"
			x.fill_rect(0, 0, W, Hh)
			disc.call(W / 2, Hh / 2, U * 0.3, "#bc002d")
		"skorea":
			x.fill_style = "#ffffff"
			x.fill_rect(0, 0, W, Hh)
			var R := U / 4
			var th := atan2(1, 1.5)
			x.save()
			x.translate(W / 2, Hh / 2)
			x.rotate(th)
			x.fill_style = "#cd2e3a"
			x.begin_path()
			x.arc(0, 0, R, PI, 0)
			x.fill()
			x.fill_style = "#0047a0"
			x.begin_path()
			x.arc(0, 0, R, 0, PI)
			x.fill()
			x.fill_style = "#cd2e3a"
			x.begin_path()
			x.arc(R / 2, 0, R / 2, 0, PI)
			x.fill()
			x.fill_style = "#0047a0"
			x.begin_path()
			x.arc(-R / 2, 0, R / 2, PI, 0)
			x.fill()
			x.restore()
			for ap in [[PI + th, [1, 1, 1]], [-th, [0, 1, 0]], [th, [0, 0, 0]], [PI - th, [1, 0, 1]]]:
				var ang: float = ap[0]
				x.save()
				x.translate(W / 2 + cos(ang) * R * 1.8, Hh / 2 + sin(ang) * R * 1.8)
				x.rotate(ang + PI / 2)
				x.fill_style = "#000000"
				for k in 3:
					x.save()
					x.translate(0, (k - 1) * R * 0.2 - R * 0.06)
					if ap[1][k]:
						x.fill_rect(-R * 0.5, 0, R, R * 0.12)
					else:
						x.fill_rect(-R * 0.5, 0, R * 0.44, R * 0.12)
						x.fill_rect(R * 0.06, 0, R * 0.44, R * 0.12)
					x.restore()
				x.restore()
		"puertorico":
			for i in 5:
				x.fill_style = "#ffffff" if i % 2 else "#ed0000"
				x.fill_rect(0, floorf(i * Hh / 5), W, ceilf(Hh / 5) + 1)
			poly(x, [[0, 0], [tri, Hh / 2], [0, Hh]], "#0050f0")
			star5(x, tri / 3, Hh / 2, minf(U * 0.13, tri * 0.2), "#ffffff")
		"canada":
			vs.call(B, [1.0, 2.0, 1.0])
			x.save()
			x.translate(W / 2, Hh * 0.55)
			var k := U * 0.0065
			x.scale(k, k)
			poly(x, [[0, -48], [8, -32], [16, -38], [12, -16], [26, -26], [30, -18], [44, -22], [38, -6], [46, -2], [22, 14], [26, 24], [3, 20], [3, 40], [-3, 40], [-3, 20], [-26, 24], [-22, 14], [-46, -2], [-38, -6], [-44, -22], [-30, -18], [-26, -26], [-12, -16], [-16, -38], [-8, -32]], "#d52b1e")
			x.restore()
		"uk":
			x.fill_style = "#012169"
			x.fill_rect(0, 0, W, Hh)
			x.line_cap = "butt"
			var ln := func(lw: float, c: String, a: Array, b: Array) -> void:
				x.stroke_style = c
				x.line_width = lw
				x.begin_path()
				x.move_to(a[0], a[1])
				x.line_to(b[0], b[1])
				x.stroke()
			for ab in [[[0, 0], [W, Hh]], [[W, 0], [0, Hh]]]:
				ln.call(U * 0.2, "#ffffff", ab[0], ab[1])
				ln.call(U * 0.067, "#c8102e", ab[0], ab[1])
			ln.call(U / 3, "#ffffff", [W / 2, 0], [W / 2, Hh])
			ln.call(U / 3, "#ffffff", [0, Hh / 2], [W, Hh / 2])
			ln.call(U * 0.2, "#c8102e", [W / 2, 0], [W / 2, Hh])
			ln.call(U * 0.2, "#c8102e", [0, Hh / 2], [W, Hh / 2])
		"france", "italy", "ireland":
			vs.call(B)
		"spain":
			hw.call([["#aa151b", 1.0], ["#f1bf00", 2.0], ["#aa151b", 1.0]])
			var cx := W * 0.31
			var cy := Hh * 0.5
			x.fill_style = "#aa151b"
			x.fill_rect(cx - U * 0.0675, cy - U * 0.13, U * 0.135, U * 0.26)
			x.fill_style = "#f1bf00"
			x.fill_rect(cx - U * 0.045, cy - U * 0.11, U * 0.045, U * 0.1)
			x.fill_style = "#c8b8a0"
			x.fill_rect(cx - U * 0.105, cy - U * 0.15, U * 0.0225, U * 0.3)
			x.fill_rect(cx + U * 0.0825, cy - U * 0.15, U * 0.0225, U * 0.3)
		"argentina":
			hs.call(B)
			x.stroke_style = "#f6b40e"
			x.line_width = U * 0.012
			for i in 16:
				var a := i * PI / 8
				x.begin_path()
				x.move_to(W / 2 + cos(a) * U * 0.085, Hh / 2 + sin(a) * U * 0.085)
				x.line_to(W / 2 + cos(a) * U * 0.14, Hh / 2 + sin(a) * U * 0.14)
				x.stroke()
			disc.call(W / 2, Hh / 2, U * 0.08, "#f6b40e")
		"philippines":
			hs.call(["#0038a8", "#ce1126"])
			poly(x, [[0, 0], [tri, Hh / 2], [0, Hh]], "#ffffff")
			var sx := tri / 3
			var sy := Hh / 2
			x.stroke_style = "#fcd116"
			x.line_width = U * 0.02
			for i in 8:
				var a := i * PI / 4
				x.begin_path()
				x.move_to(sx + cos(a) * U * 0.07, sy + sin(a) * U * 0.07)
				x.line_to(sx + cos(a) * U * 0.13, sy + sin(a) * U * 0.13)
				x.stroke()
			disc.call(sx, sy, U * 0.065, "#fcd116")
			for q in [[tri * 0.08, Hh * 0.09], [tri * 0.08, Hh * 0.91], [tri * 0.85, Hh / 2]]:
				star5(x, q[0], q[1], U * 0.04, "#fcd116")
		"india":
			hs.call(B)
			x.stroke_style = "#000080"
			x.line_width = U * 0.012
			x.begin_path()
			x.arc(W / 2, Hh / 2, U * 0.14, 0, TAU)
			x.stroke()
			for i in 24:
				var a := i * PI / 12
				x.begin_path()
				x.move_to(W / 2, Hh / 2)
				x.line_to(W / 2 + cos(a) * U * 0.14, Hh / 2 + sin(a) * U * 0.14)
				x.stroke()
			disc.call(W / 2, Hh / 2, U * 0.025, "#000080")
		"israel":
			x.fill_style = "#ffffff"
			x.fill_rect(0, 0, W, Hh)
			x.fill_style = "#0038b8"
			x.fill_rect(0, Hh * 0.1, W, Hh * 0.15)
			x.fill_rect(0, Hh * 0.75, W, Hh * 0.15)
			x.stroke_style = "#0038b8"
			x.line_width = U * 0.03
			x.line_join = "miter"
			for rot in [-PI / 2, PI / 2]:
				x.begin_path()
				for i in 3:
					var a: float = rot + i * TAU / 3
					if i:
						x.line_to(W / 2 + cos(a) * U * 0.19, Hh / 2 + sin(a) * U * 0.19)
					else:
						x.move_to(W / 2 + cos(a) * U * 0.19, Hh / 2 + sin(a) * U * 0.19)
				x.close_path()
				x.stroke()
		"nkorea":
			hw.call([["#024fa2", 6.0], ["#ffffff", 1.0], ["#ed1c27", 15.0], ["#ffffff", 1.0], ["#024fa2", 6.0]])
			disc.call(W * 0.36, Hh / 2, U * 0.19, "#ffffff")
			star5(x, W * 0.36, Hh / 2, U * 0.18, "#ed1c27")
		_:
			hs.call(B if not B.is_empty() else ["#888888"])


static func flag_scene(x: Ctx2D, w: float, h: float, t: float, id: String, moving: bool) -> void:
	layer(x, "flag:" + id, w, h, func():
		draw_flag(x, id, w, h)
		var shade := x.create_linear_gradient(0, 0, 0, h)
		shade.add_color_stop(0, "rgba(5,10,18,.13)")
		shade.add_color_stop(0.45, "rgba(5,10,18,.03)")
		shade.add_color_stop(1, "rgba(5,10,18,.22)")
		x.fill_style = shade
		x.fill_rect(0, 0, w, h))
	var phase := t * 0.48 if moving else 0.0
	var band := w * 0.24
	for i in range(-1, 6):
		var px := (fmod(i / 5.0 + phase * 0.07, 1.4) - 0.2) * w
		var gr := x.create_linear_gradient(px, 0, px + band, 0)
		gr.add_color_stop(0, "rgba(0,0,0,0)")
		gr.add_color_stop(0.35, "rgba(0,0,0,.075)")
		gr.add_color_stop(0.65, "rgba(255,255,255,.055)")
		gr.add_color_stop(1, "rgba(255,255,255,0)")
		x.fill_style = gr
		x.fill_rect(px, 0, band, h)


# ---------------------------------------------------------------- winter (18d)

static func winter(c: Ctx2D, w: float, h: float, t: float, n: int, moving: bool) -> void:
	var x := c
	layer(x, "winter%d" % n, w, h, func():
		var night := n == 5 or n >= 6
		vgrad(x, w, h, [[0, "#102332" if night else "#355d73"], [0.65, "#304b5f" if night else "#8bb9cd"], [1, "#bccfda"]])
		var P := func(p: Array, col: String) -> void: poly(x, p.map(func(q): return [q[0] * w, q[1] * h]), col)
		for j in 3:
			var y := 0.45 + j * 0.13
			P.call([[0, y + 0.12], [0.16, y - 0.08], [0.29, y + 0.06], [0.47, y - 0.19], [0.68, y + 0.03], [0.82, y - 0.1], [1, y + 0.1], [1, 1], [0, 1]], ["#587b91", "#7396a9", "#aecbd8"][j])
			P.call([[0.4, y - 0.105], [0.47, y - 0.19], [0.55, y - 0.075], [0.48, y - 0.095], [0.45, y - 0.07]], "#eaf3f6")
		trees(x, w, h, h * 0.81, "#294958", 84 + n)
		P.call([[0, 0.88], [0.35, 0.8], [0.64, 0.87], [1, 0.78], [1, 1], [0, 1]], "#bed6e0")
		var hut := func(a: float, b: float, ww: float, hh: float, col: String) -> void:
			x.fill_style = col
			x.fill_rect(a * w, b * h, ww * w, hh * h)
			P.call([[a - 0.015, b], [a + ww * 0.5, b - 0.06], [a + ww + 0.015, b], [a + ww, b + 0.018], [a, b + 0.018]], "#dfedf2")
			x.fill_style = "#e9b868" if night else "#426b7e"
			for i in 3:
				x.fill_rect((a + 0.02 + i * ww * 0.27) * w, (b + 0.035) * h, ww * w * 0.16, hh * h * 0.28)
			x.fill_style = "#274553"
			x.fill_rect((a + ww * 0.68) * w, (b + hh * 0.42) * h, ww * w * 0.2, hh * h * 0.58)
		if n == 0 or n == 5 or n == 6:
			hut.call(0.12, 0.66, 0.25, 0.18, "#3b5663")
			hut.call(0.71, 0.71, 0.15, 0.12, "#455c68")
			x.stroke_style = "#4c626a"
			x.line_width = 3
			x.begin_path()
			x.move_to(w * 0.48, h * 0.8)
			x.line_to(w * 0.48, h * 0.51)
			x.stroke()
			P.call([[0.48, 0.53], [0.58, 0.55], [0.48, 0.58]], "#b2504b")
		if n == 1:
			P.call([[0, 0.87], [0.33, 0.7], [0.44, 0.73], [1, 0.87], [1, 0.94], [0.43, 0.79], [0.34, 0.77], [0, 0.95]], "#6599ad")
			x.stroke_style = "#c5e6ee"
			x.line_width = 2
			for i in 8:
				x.begin_path()
				x.move_to(w * (i / 8.0), h * 0.88)
				x.line_to(w * (i / 8.0 + 0.12), h * 0.87)
				x.stroke()
			hut.call(0.74, 0.65, 0.19, 0.16, "#4b626e")
		if n == 2:
			for i in 4:
				P.call([[0.03 + i * 0.12, 0.78 - i * 0.03], [0.38 + i * 0.1, 0.73 - i * 0.035], [0.47 + i * 0.1, 0.77 - i * 0.035], [0.07 + i * 0.12, 0.83 - i * 0.03]], "#8198a5" if i % 2 else "#526d7d")
			hut.call(0.71, 0.7, 0.19, 0.15, "#536670")
			x.stroke_style = "#344c5c"
			x.line_width = 5
			x.begin_path()
			x.move_to(w * 0.16, h * 0.7)
			x.line_to(w * 0.16, h * 0.36)
			x.line_to(w * 0.63, h * 0.5)
			x.stroke()
		if n == 3:
			hut.call(0.12, 0.69, 0.34, 0.18, "#5b665e")
			x.stroke_style = "#324a5a"
			x.line_width = 2
			x.begin_path()
			x.move_to(0, h * 0.39)
			x.line_to(w, h * 0.55)
			x.stroke()
			for i in 4:
				var a := 0.14 + i * 0.21
				var b := 0.41 + i * 0.03
				x.fill_style = "#496274"
				x.fill_rect(a * w, b * h, w * 0.055, h * 0.06)
				x.stroke_rect(a * w, b * h, w * 0.055, h * 0.06)
		if n == 4:
			hut.call(0.65, 0.63, 0.23, 0.22, "#546676")
			for i in 5:
				x.fill_style = "#6e806f" if i % 2 else "#637281"
				x.fill_rect(w * (0.1 + i * 0.08), h * (0.82 - i % 2 * 0.04), w * 0.07, h * 0.075)
				x.fill_style = "#d9e9ef"
				x.fill_rect(w * (0.1 + i * 0.08), h * (0.82 - i % 2 * 0.04), w * 0.07, 3)
		if n == 7:
			x.fill_style = "#334e5f"
			x.fill_rect(w * 0.2, h * 0.43, w * 0.14, h * 0.34)
			P.call([[0.15, 0.43], [0.39, 0.43], [0.35, 0.4], [0.19, 0.4]], "#d7e9f1")
			x.fill_style = "#99c1cf"
			x.fill_rect(w * 0.225, h * 0.45, w * 0.09, h * 0.09)
			hut.call(0.69, 0.75, 0.15, 0.12, "#536674")
		if n == 8:
			hut.call(0.09, 0.58, 0.38, 0.29, "#5d5056")
			P.call([[0.12, 0.85], [0.44, 0.85], [0.44, 0.67], [0.12, 0.67]], "#1a303b")
			x.fill_style = "#6c9c91"
			x.fill_rect(w * 0.76, h * 0.69, w * 0.1, h * 0.18)
			P.call([[0.72, 0.74], [0.81, 0.59], [0.9, 0.74]], "#467f6b")
			x.stroke_style = "#bd6860"
			x.line_width = 3
			x.begin_path()
			x.move_to(w * 0.12, h * 0.65)
			x.line_to(w * 0.44, h * 0.65)
			x.stroke()
		if n == 9:
			hut.call(0.73, 0.7, 0.17, 0.15, "#3b4e60")
			x.stroke_style = "#e2bd65"
			x.line_width = 2
			x.begin_path()
			x.ellipse(w * 0.33, h * 0.87, w * 0.13, h * 0.025, 0, 0, TAU)
			x.stroke()
			x.fill_style = "#30434e"
			x.fill_rect(w * 0.65, h * 0.36, w * 0.13, h * 0.03)
			x.stroke_style = "#6e8c9b"
			x.begin_path()
			x.move_to(w * 0.6, h * 0.345)
			x.line_to(w * 0.83, h * 0.345)
			x.stroke()
		vgrad(x, w, h, [[0, "rgba(7,18,29,0)"], [0.6, "rgba(7,18,29,.05)"], [1, "rgba(7,18,29,.72)"]]))
	if not moving:
		return
	c.save()
	if n == 6:
		for j in 3:
			c.stroke_style = ["#83e8c1", "#73cddf", "#ad9ce8"][j]
			c.global_alpha = 0.2
			c.line_width = h * 0.045
			c.begin_path()
			for q in 21:
				var xx := q / 20.0 * w
				var yy := h * (0.18 + j * 0.045) + sin(q * 0.25 + t * 0.2 + j) * h * 0.045
				if q:
					c.line_to(xx, yy)
				else:
					c.move_to(xx, yy)
			c.stroke()
	if n == 7 or n == 9:
		c.global_alpha = 0.12
		c.fill_style = "#e6f7ff"
		var xx := w * (0.27 if n == 7 else 0.73)
		var yy := h * (0.47 if n == 7 else 0.74)
		var a := sin(t * 0.25) * 0.7
		c.begin_path()
		c.move_to(xx, yy)
		c.line_to(xx + cos(a) * w * 0.65, yy + sin(a) * h * 0.35 - h * 0.35)
		c.line_to(xx + cos(a + 0.22) * w * 0.65, yy + sin(a + 0.22) * h * 0.35 - h * 0.35)
		c.fill()
	if n == 8:
		for i in 9:
			c.global_alpha = 0.6 + 0.2 * sin(t * 0.8 + i)
			c.glow(w * (0.13 + i * 0.038), h * 0.65, 5, ["#ffb96d", "#9de5d5", "#dd849d"][i % 3], 0.6)
		for i in 4:
			c.global_alpha = 0.12
			c.fill_style = "#e5edf1"
			c.begin_path()
			c.ellipse(w * (0.2 + i * 0.025) + sin(t + i) * 3, h * (0.64 - fmod(t * 0.03 + i * 0.1, 0.2)), w * 0.03, h * 0.04, 0, 0, TAU)
			c.fill()
	c.global_alpha = 0.45
	c.fill_style = "#dcf5ff"
	for i in 24:
		var xx := fmod(H(i, n + 30) * w + t * (32 if n == 7 else 7), w + 12) - 6
		var yy := fmod(H(i, n + 51) * h + t * (18 if n == 7 else 11), h)
		c.fill_rect(xx, yy, 1.5 if i % 5 else 2.5, 1.5)
	c.restore()


# ---------------------------------------------------------------- Hybrid Theory (18f)

static func tone(c: String, k: float) -> Color:
	return CosArt.mix(c, "#ffffff", minf(1, (k - 1) * 0.45)) if k > 1 else CosArt.mix(c, "#000000", 1 - k)


static func hybrid(c: Ctx2D, w: float, h: float, t: float, n: int, pal: Array, moving: bool) -> void:
	var x := c
	var ground: String = pal[0]
	var acc: String = pal[1]
	var acc2: String = pal[2]
	layer(x, "hybrid%d" % n, w, h, func():
		var night := n != 7
		vgrad(x, w, h, [[0, ground], [0.62, tone(ground, 1.5) if night else CosFx.col("#3a2a1c")], [1, tone(ground, 0.8)]])
		var Bk := maxf(4, roundf(h / 90))
		var snap := func(v: float) -> float: return roundf(v / Bk) * Bk
		for i in 14:
			var bw: float = snap.call(w * (0.05 + H(i, n + 3) * 0.06))
			var bx: float = snap.call(i * w / 13 - w * 0.03)
			var bh: float = snap.call(h * (0.18 + H(i, n + 7) * 0.22))
			x.fill_style = tone(ground, 1.35)
			x.fill_rect(bx, snap.call(h * 0.62) - bh, bw, bh)
		for i in 9:
			var bw: float = snap.call(w * (0.07 + H(i, n + 11) * 0.07))
			var bx: float = snap.call(i * w / 8.5 - w * 0.02)
			var bh: float = snap.call(h * (0.28 + H(i, n + 13) * 0.34))
			var by: float = snap.call(h * 0.78) - bh
			x.fill_style = "#6B4A32" if n == 7 else tone(ground, 1.7)
			x.fill_rect(bx, by, bw, bh)
			x.fill_style = "rgba(0,0,0,.35)"
			x.fill_rect(bx + bw - Bk, by, Bk, bh)
			var yy := by + Bk
			while yy < by + bh - Bk:
				var xx := bx + Bk
				while xx < bx + bw - Bk * 1.5:
					if H(xx * 7 + yy, n + i) > 0.45:
						x.fill_style = acc2 if H(xx + yy * 3, n) > 0.7 else acc
						x.global_alpha = 0.55 + H(xx, yy) * 0.45
						x.fill_rect(xx, yy, Bk, Bk)
					xx += Bk * 2
				yy += Bk * 2
			x.global_alpha = 1
			if i % 3 == 1:
				x.fill_style = acc
				x.fill_rect(bx, by - Bk, bw, Bk)
		x.fill_style = tone(ground, 0.7)
		x.fill_rect(0, snap.call(h * 0.78), w, h)
		x.fill_style = acc
		x.fill_rect(0, snap.call(h * 0.78), w, maxf(2, Bk / 2))
		if n == 4:
			x.stroke_style = acc
			x.line_width = maxf(1, Bk / 3)
			for i in 4:
				x.begin_path()
				x.move_to(0, h * (0.3 + i * 0.06))
				x.quadratic_curve_to(w * 0.5, h * (0.38 + i * 0.06), w, h * (0.3 + i * 0.06))
				x.stroke()
		if n == 3:
			x.fill_style = acc
			for i in 5:
				var cx: float = snap.call(w * (0.18 + i * 0.16))
				var cy: float = snap.call(h * 0.2)
				x.fill_rect(cx - Bk * 2, cy, Bk * 4, Bk)
				for k in [-2, 0, 2]:
					x.fill_rect(cx + k * Bk, cy - Bk * 2, Bk, Bk * 2)
		vgrad(x, w, h, [[0, "rgba(5,8,14,0)"], [0.6, "rgba(5,8,14,.08)"], [1, "rgba(5,8,14,.7)"]]))
	if not moving:
		return
	c.save()
	c.composite = "lighter"
	for i in 4:
		var y := h * (0.12 + i * 0.13 + (0.4 if i == 3 else 0.0))
		var len := w * 0.22
		var xx := fmod(t * w * 0.05 * (1 + i * 0.3) + H(i, n) * w, w + len) - len
		c.global_alpha = 0.35
		c.fill_style = pal[2] if i % 2 else pal[1]
		c.fill_rect(xx, y, len, maxf(2, h / 160))
		c.global_alpha = 0.15
		c.fill_rect(xx - len * 0.3, y - 1, len * 1.6, maxf(4, h / 80))
	if n == 5:
		c.global_alpha = 0.16
		for j in 3:
			c.stroke_style = ["#78BE20", "#4fd3b8", "#9fe7a0"][j]
			c.line_width = h * 0.035
			c.begin_path()
			for q in 17:
				var xx := q / 16.0 * w
				var yy := h * (0.14 + j * 0.04) + sin(q * 0.4 + t * 0.25 + j) * h * 0.03
				if q:
					c.line_to(xx, yy)
				else:
					c.move_to(xx, yy)
			c.stroke()
	c.restore()
