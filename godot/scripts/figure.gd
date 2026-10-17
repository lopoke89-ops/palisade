class_name Figure
extends RefCounted
## The character painter (16-characters.js drawPerson, gunArms, drawDowned): outlined figures in base pixels, scaled by
## u * FIG. Every look field the raiders, bosses, Delgado and the four classes use is drawn here; the cosmetic
## wardrobe (skins, the 3D-shaded locker figure, hats from cases) comes with the cosmetics port.

const OUT := Color(14 / 255.0, 12 / 255.0, 10 / 255.0, 0.95)
const LIT := "#f3e9d6"
const FIG := 1.18

static var cv: CanvasItem
static var m   # the main node: its draw_alpha and game time


static func _c(col) -> Color:
	var k: Color = col if col is Color else Color.html(col)
	k.a *= m.draw_alpha
	return k


static func dark(col, f: float) -> Color:
	var k: Color = col if col is Color else Color.html(col)
	return Color(k.r * (1 - f), k.g * (1 - f), k.b * (1 - f), k.a)


static func P(pts: Array, col, outline: bool = true) -> void:
	var a := PackedVector2Array()
	for q in pts:
		a.append(Vector2(q[0], q[1]))
	cv.draw_colored_polygon(a, _c(col))
	if outline:
		a.append(a[0])
		cv.draw_polyline(a, _c(OUT), 1.1)


static func seg(a: Array, b: Array, col, w: float) -> void:
	cv.draw_line(Vector2(a[0], a[1]), Vector2(b[0], b[1]), _c(col), w)


## a limb: an outlined line with round ends
static func limb(a: Array, b: Array, col, w: float) -> void:
	var A := Vector2(a[0], a[1])
	var B := Vector2(b[0], b[1])
	var o := _c(OUT)
	cv.draw_line(A, B, o, w + 1.8)
	cv.draw_circle(A, (w + 1.8) / 2, o)
	cv.draw_circle(B, (w + 1.8) / 2, o)
	var k := _c(col)
	cv.draw_line(A, B, k, w)
	cv.draw_circle(A, w / 2, k)
	cv.draw_circle(B, w / 2, k)


static func rectP(cx: float, cy: float, w: float, h: float) -> Array:
	return [[cx - w / 2, cy - h / 2], [cx + w / 2, cy - h / 2], [cx + w / 2, cy + h / 2], [cx - w / 2, cy + h / 2]]


static func domeP(cx: float, cy: float, r: float) -> Array:
	var p: Array = []
	for k in 9:
		var a := PI + PI * k / 8.0
		p.append([cx + cos(a) * r, cy + sin(a) * r])
	return p


static func disc(x: float, y: float, r: float, col) -> void:
	cv.draw_circle(Vector2(x, y), r, _c(col))


static func oval(x: float, y: float, rx: float, ry: float, col, xf: Transform2D) -> void:
	cv.draw_set_transform_matrix(xf * Transform2D(0, Vector2(1, ry / rx), 0, Vector2(x, y)))
	cv.draw_circle(Vector2.ZERO, rx, _c(col))
	cv.draw_set_transform_matrix(xf)


static func neon(a: Array, b: Array, col) -> void:
	var k := _c(col)
	cv.draw_line(Vector2(a[0], a[1]), Vector2(b[0], b[1]), Color(k, k.a * 0.32), 3.4)
	cv.draw_line(Vector2(a[0], a[1]), Vector2(b[0], b[1]), k, 1.15)


static func _xy(v: Vector2) -> Array:
	return [v.x, v.y]


## bp: bolt-action phase after a shot (0 just fired, 1 bolt home), or -1; kind: the weapon; swing: the Butcher's wind-up
static func gun_arms(hand: Array, sd: Vector2, gl: float, shB: Array, shF: Array, sleeve, nogun: bool, bob: float, bp: float = -1, kind: String = "", swing: int = 0, wear: float = 0.0) -> void:
	var t: float = m.sim.game.time
	if nogun:
		limb(shB, [shB[0], -13.5 + bob], sleeve, 2.6)
		limb(shF, [shF[0], -13.5 + bob], sleeve, 2.6)
		return
	if kind == "sword" or kind == "swordp" or kind == "swordb":
		var pk := kind == "swordp"
		var bl := kind == "swordb"
		var sx := 1.0 if sd.x >= 0 else -1.0
		var a := atan2(-1, sx * 0.35) if swing == 1 else (atan2(-0.35, sx) if swing == 2 else (atan2(sd.y, sd.x) if swing == 3 else atan2(sd.y + 0.7, sd.x)))
		var c := cos(a)
		var n := sin(a)
		limb(shB, hand, sleeve, 2.6)
		limb(shF, hand, sleeve, 2.6)
		var tip := [hand[0] + c * 25, hand[1] + n * 25]
		var base := [hand[0] + c * 2, hand[1] + n * 2]
		if swing == 1 or swing == 2:
			seg(base, tip, Color(Color.html("#3ae0e0" if bl else ("#ff8a2a" if pk else "#ff4a32")), 0.55), 6)
		if pk or bl:
			seg(base, tip, Color(Color.html("#5af0ff" if bl else "#ff9a3a"), 0.3 + 0.15 * sin(t * 11)), 5)
		seg([hand[0] - c * 4, hand[1] - n * 4], base, OUT, 3.4)
		seg([hand[0] - c * 4, hand[1] - n * 4], base, "#3a2a1a", 2)
		seg(base, tip, OUT, 3.8)
		seg(base, tip, "#7af4ff" if bl else ("#ffb070" if pk else "#d9dee0"), 2.2)
		seg([base[0] + c * 6, base[1] + n * 6], tip, "#e8ffff" if bl else ("#fff0c8" if pk else "#ffffff"), 0.7)
		seg([base[0] - n * 4, base[1] + c * 4], [base[0] + n * 4, base[1] - c * 4], OUT, 2.8)
		seg([base[0] - n * 3.4, base[1] + c * 3.4], [base[0] + n * 3.4, base[1] - c * 3.4], "#8a6a36", 1.6)
		return
	if kind == "shield":   # riot shield on the front arm, pistol in the other hand
		limb(shB, hand, sleeve, 2.6)
		var pm := [hand[0] + sd.x * 6, hand[1] + sd.y * 6]
		seg(hand, pm, OUT, 3.6)
		seg(hand, pm, "#2b2823", 2.2)
		var cx: float = hand[0] + sd.x * 5
		var cy: float = hand[1] + sd.y * 3 - 4
		var w := 4 + 9 * minf(1, absf(sd.y) * 1.7)
		var h := 22.0
		limb(shF, [cx, cy + 2], sleeve, 2.6)
		cv.draw_rect(Rect2(cx - w / 2 - 1, cy - h / 2 - 1, w + 2, h + 2), _c(OUT))
		cv.draw_rect(Rect2(cx - w / 2, cy - h / 2, w, h), _c("#4a5358"))
		cv.draw_rect(Rect2(cx - w / 2, cy - h / 2, w * 0.35, h), _c("#6b767c"))
		cv.draw_rect(Rect2(cx - w * 0.32, cy - h * 0.34, w * 0.64, 2.2), _c(Color(160 / 255.0, 200 / 255.0, 220 / 255.0, 0.6)))
		cv.draw_rect(Rect2(cx - w / 2, cy + h * 0.28, w, 1.6), _c("#e2b436"))
		if wear > 0.25:
			seg([cx - w * 0.3, cy - 5], [cx + w * 0.1, cy + 1], "#17252a", 1)
			seg([cx + w * 0.1, cy + 1], [cx - w * 0.2, cy + 5], "#afc1c2", 0.6)
		if wear > 0.65:
			seg([cx + w * 0.3, cy - 8], [cx - w * 0.1, cy - 2], "#101c22", 1.2)
			seg([cx - w * 0.1, cy - 2], [cx + w * 0.2, cy + 8], "#101c22", 1.1)
		return
	if kind == "bottle":   # a lit fire bottle held up, ready to throw
		limb(shB, [shB[0], -13.5 + bob], sleeve, 2.6)
		var b := [shF[0] + sd.x * 3, shF[1] - 7]
		limb(shF, b, sleeve, 2.6)
		cv.draw_rect(Rect2(b[0] - 2.2, b[1] - 6, 4.4, 7), _c(OUT))
		cv.draw_rect(Rect2(b[0] - 1.6, b[1] - 5.4, 3.2, 6), _c("#3f7a4a"))
		cv.draw_rect(Rect2(b[0] - 0.8, b[1] - 8, 1.6, 2.6), _c("#e8dcc0"))
		var f := sin(t * 20) * 0.8
		cv.draw_colored_polygon(PackedVector2Array([Vector2(b[0] - 1.8, b[1] - 8), Vector2(b[0] + f, b[1] - 13), Vector2(b[0] + 1.8, b[1] - 8)]), _c("#ff8a2a"))
		cv.draw_colored_polygon(PackedVector2Array([Vector2(b[0] - 0.9, b[1] - 8), Vector2(b[0] + f * 0.5, b[1] - 11), Vector2(b[0] + 0.9, b[1] - 8)]), _c("#ffd070"))
		return
	if kind == "drill":   # the Foreman's rock drill, pointed at the ground
		var d0 := [hand[0] + sd.x * 2, hand[1] - 2]
		var d1 := [d0[0] + sd.x * 6, d0[1] + 12]
		limb(shB, d0, sleeve, 2.6)
		limb(shF, [d0[0] + sd.x * 3, d0[1] + 1], sleeve, 2.6)
		seg(d0, d1, OUT, 6.4)
		seg(d0, d1, "#e0a030", 4.6)
		seg([d0[0] - 3, d0[1]], [d0[0] + 3, d0[1]], OUT, 3)
		var jit := sin(t * 60) * 0.6
		var tip := [d1[0] + sd.x + jit, d1[1] + 6]
		seg(d1, tip, OUT, 2.6)
		seg(d1, tip, "#b9bcb8", 1.4)
		return
	var kb := 0.0
	var pull := 0.0
	if bp >= 0:
		kb = (1 - bp / 0.2) * 2.6 if bp < 0.2 else 0.0
		if bp > 0.24 and bp < 0.9:
			pull = sin((bp - 0.24) / 0.66 * PI)
	var lift := kb * 0.5 if kind == "sg" else pull * 2.4 + kb * 0.5
	var at := func(k: float) -> Array: return [hand[0] + sd.x * (k - kb), hand[1] + sd.y * (k - kb) - lift * maxf(0, k + 5) / (gl + 5)]
	var stock: Array = at.call(-5)
	var muz: Array = at.call(gl)
	var mid: Array = at.call(gl * 0.55)
	var mg: Array = at.call(2.2)
	if kind == "harpoon":   # the Ferryman's harpoon gun: long, with a barbed head
		limb(shB, hand, sleeve, 2.6)
		var a0: Array = at.call(-6)
		var a1: Array = at.call(gl)
		seg(a0, a1, OUT, 4.6)
		seg(a0, a1, "#5a4630", 3)
		var t0: Array = at.call(gl)
		var t1: Array = at.call(gl + 5)
		seg(t0, t1, OUT, 3)
		seg(t0, t1, "#c9ccc8", 1.6)
		var bb: Array = at.call(gl + 2.4)
		seg(bb, [bb[0] - sd.y * 3 - sd.x * 2, bb[1] + sd.x * 3 - sd.y * 2], "#c9ccc8", 1.2)
		seg(bb, [bb[0] + sd.y * 3 - sd.x * 2, bb[1] - sd.x * 3 - sd.y * 2], "#c9ccc8", 1.2)
		limb(shF, at.call(gl * 0.4), sleeve, 2.6)
		return
	if kind == "rpg":
		limb(shB, hand, sleeve, 2.6)
		var a0: Array = at.call(-8)
		var a1: Array = at.call(gl)
		seg(a0, a1, OUT, 7.4)
		seg(a0, a1, "#4d5638", 5.4)
		seg(at.call(gl * 0.28), at.call(gl * 0.36), "#2c3122", 5.6)
		var w: Array = at.call(gl + 2.6)
		disc(w[0], w[1], 3.8, OUT)
		disc(w[0], w[1], 3, "#7a6f58")
		disc(w[0] + sd.x * 1.6, w[1] + sd.y * 1.6, 1.6, "#9a8c6c")
		seg(mg, [mg[0], mg[1] + 4], OUT, 3)
		seg(mg, [mg[0], mg[1] + 3.6], "#2b2823", 1.7)
		limb(shF, at.call(gl * 0.38), sleeve, 2.6)
		return
	if kind == "sg":
		limb(shB, hand, sleeve, 2.6)
		seg(stock, muz, OUT, 5.2)
		seg(stock, at.call(gl * 0.18), "#6a4526", 3.8)
		seg(at.call(gl * 0.18), muz, "#34312b", 2.6)
		var sl := pull * 3.6
		var f0: Array = at.call(gl * 0.46 - sl)
		var f1: Array = at.call(gl * 0.76 - sl)
		seg(f0, f1, OUT, 5.4)
		seg(f0, f1, "#7a5230", 3.6)
		seg(mg, [mg[0], mg[1] + 3.8], OUT, 3)
		seg(mg, [mg[0], mg[1] + 3.4], "#2b2823", 1.7)
		limb(shF, at.call(gl * 0.62 - sl), sleeve, 2.6)
		return
	if bp >= 0:   # a bolt rifle working its bolt
		var kn: Array = at.call(3.2 - pull * 6)
		var upv := pull * 2.6
		limb(shB, [kn[0], kn[1] - upv], sleeve, 2.6)
		seg(stock, muz, OUT, 4.4)
		seg(stock, mid, "#2b2823", 3)
		seg(mid, muz, "#45423b", 1.8)
		seg(mg, [mg[0], mg[1] + 3.8], OUT, 3)
		seg(mg, [mg[0], mg[1] + 3.4], "#2b2823", 1.7)
		seg(at.call(1.6), [kn[0], kn[1] - upv], OUT, 2.2)
		seg(at.call(1.6), [kn[0], kn[1] - upv], "#8d887b", 1.1)
		disc(kn[0], kn[1] - upv, 1.3, OUT)
		disc(kn[0], kn[1] - upv, 0.8, "#b7b1a2")
	else:
		limb(shB, hand, sleeve, 2.6)
		seg(stock, muz, OUT, 4.4)
		seg(stock, mid, "#2b2823", 3)
		seg(mid, muz, "#45423b", 1.8)
		seg(mg, [mg[0], mg[1] + 3.8], OUT, 3)
		seg(mg, [mg[0], mg[1] + 3.4], "#2b2823", 1.7)
	if kind == "zap":
		for k in [0.62, 0.74, 0.86]:
			var c: Array = at.call(gl * k)
			disc(c[0], c[1], 1.5, "#7fe0ff")
		disc(muz[0], muz[1], 2.4, Color(Color.html("#bff3ff"), 0.8))
	limb(shF, at.call(gl * 0.42), sleeve, 2.6)


## A soldier, raider, boss or Delgado standing at (x, y), facing o.aim
static func person(main, x: float, y: float, o: Dictionary) -> void:
	m = main
	cv = main.cv
	var v: IsoView = main.v
	var s: Vector2 = main.iso(x, y)
	var BG: float = o.get("big", 1.0)
	var k: float = v.u * FIG * BG
	var xf := Transform2D(0, Vector2(k, k), 0, s)
	var keep_alpha: float = main.draw_alpha
	if o.get("faded", false):
		main.draw_alpha = keep_alpha * 0.5
	cv.draw_set_transform_matrix(xf)
	var walk: float = o.get("walk", 0.0)
	var bob := -absf(sin(walk)) * 1.1
	var sd: Vector2 = v.world_dir_to_screen(o.aim)
	var side := 1.0 if sd.x >= 0 else -1.0
	var front := sd.y >= -0.15
	var lit: bool = o.get("flash", false)
	var skin = LIT if lit else o.head
	var body = LIT if lit else o.body
	var vest = o.vest
	var pants = o.get("pants", "#3b372c")
	var gl: float = o.get("gl", 14)
	var nogun: bool = o.get("nogun", false)
	var weapon: String = o.get("weapon", "")
	if o.has("glow"):
		oval(0, 0, 13, 6, Color(Color.html(o.glow), 0.4), xf)
	oval(0, 0, 10, 4.8, Color(0, 0, 0, 0.38), xf)
	if o.has("ring"):
		cv.draw_set_transform_matrix(xf * Transform2D(0, Vector2(1, 5.0 / 10.5), 0, Vector2.ZERO))
		cv.draw_arc(Vector2.ZERO, 10.5, 0, TAU, 28, _c(o.ring), 1.6)
		cv.draw_set_transform_matrix(xf)
	var sw := sin(walk) * 2.6
	var hy := -12 + bob
	var lf := [-2.8 + sw, -2]
	var rf := [2.8 - sw, -2]
	limb([-2.5, hy], lf, pants, 3.2)
	limb([2.5, hy], rf, pants, 3.2)
	for f in [lf, rf]:
		P(rectP(f[0] + side * 0.8, f[1] + 0.6, 4.6, 2.6), "#1a1612")
	var hand := [sd.x * 6, -17 + bob + sd.y * 3]
	var shB := [-side * 5, -22.5 + bob]
	var shF := [side * 5, -22.5 + bob]
	if o.has("pack") and front:
		P(rectP(-side * 1.2, -19.5 + bob, 13, 11), o.pack)
	var bp: float = o.get("bolt", -1.0)
	var swing: int = o.get("swing", 0)
	var wear: float = o.get("shield_wear", 0.0)
	if not front:
		gun_arms(hand, sd, gl, shB, shF, body, nogun, bob, bp, weapon, swing, wear)
	P([[-6.2, -24.5 + bob], [6.2, -24.5 + bob], [4.8, -11.5 + bob], [-4.8, -11.5 + bob]], body)
	P([[-5, -23 + bob], [5, -23 + bob], [4.3, -14.5 + bob], [-4.3, -14.5 + bob]], vest, false)
	if front:
		for px in [-4, -1.2, 1.6]:
			cv.draw_rect(Rect2(px, -17.2 + bob, 2.4, 2.6), _c(dark(vest, 0.3)))
	if o.has("stripe"):
		for q in [[-5, -7], [-1, -2.5], [3, 1.5]]:
			seg([q[0], -23.5 + bob], [q[1] + 2, -13 + bob], o.stripe, 1.3)
	if o.get("bandolier", false):
		seg([-5.2 * side, -23.5 + bob], [4.6 * side, -13 + bob], "#1d1914", 2.6)
		seg([-5.2 * side, -23.5 + bob], [4.6 * side, -13 + bob], "#8a6a36", 1.6)
		if front:   # green grenades on the strap
			for n in 4:
				var tt := (n + 0.6) / 4.4
				disc(-5.2 * side + 9.8 * side * tt, -23.5 + 10.5 * tt + bob, 1.45, OUT)
				disc(-5.2 * side + 9.8 * side * tt, -23.5 + 10.5 * tt + bob, 1.05, "#8aa83f")
	if o.has("plate"):
		P(domeP(-5.8, -21.4 + bob, 3.1), o.plate)
		P(domeP(5.8, -21.4 + bob, 3.1), o.plate)
		seg([0, -23 + bob], [0, -14.6 + bob], dark(o.plate, 0.35), 1.2)
	seg([-4.8, -12.2 + bob], [4.8, -12.2 + bob], "#1d1914", 1.8)
	if o.get("satchel", false):
		var cc := [side * 5.5, -14 + bob]
		P(rectP(cc[0], cc[1], 6, 5), "#1a1510")
		cv.draw_rect(Rect2(cc[0] - 1, cc[1] - 1, 2, 1.5), _c("#d65a3a"))
	if o.has("pack") and not front:
		P(rectP(0, -18.5 + bob, 11, 10), o.pack)
		seg([-5.5, -21.5 + bob], [5.5, -21.5 + bob], OUT, 1)
	var hx := side * 0.4
	var hy2 := -28.8 + bob
	disc(hx, hy2, 5.3, OUT)
	disc(hx, hy2, 4.5, skin if front else dark(skin, 0.3))
	if front:
		cv.draw_rect(Rect2(hx - 1.9 + side * 1.2, hy2 - 0.9, 1.1, 1.3), _c(OUT))
		cv.draw_rect(Rect2(hx + 0.9 + side * 1.2, hy2 - 0.9, 1.1, 1.3), _c(OUT))
		if o.has("bandana"):
			P(rectP(hx + side * 0.4, hy2 + 2.3, 8.2, 3.6), o.bandana)
	if o.has("helmet"):
		P(domeP(hx, hy2 - 0.4, 5.4), o.helmet)
		seg([hx - 6.2, hy2 - 0.3], [hx + 6.2, hy2 - 0.3], OUT, 1.6)
		if o.has("hneon"):
			neon([hx - 4.8, hy2 - 2.6], [hx + 4.8, hy2 - 2.6], o.hneon)
			neon([hx, hy2 - 5.6], [hx, hy2 - 2.6], o.hneon)
	elif o.has("beanie"):
		P(domeP(hx, hy2 - 0.2, 5.2), o.beanie)
		cv.draw_rect(Rect2(hx - 5.2, hy2 - 1.6, 10.4, 2.2), _c(dark(o.beanie, 0.3)))
		disc(hx, hy2 - 6, 1.7, OUT)
		disc(hx, hy2 - 6, 1.2, o.beanie)
	elif o.has("beret"):
		P([[hx - 5.6, hy2 - 1.6], [hx - 2, hy2 - 5], [hx + 4.6, hy2 - 4.4], [hx + 6.6, hy2 - 2.2], [hx + 4.8, hy2 - 1]], o.beret)
	elif o.has("wrap"):
		P(domeP(hx, hy2 - 0.3, 5), o.wrap)
		seg([hx - side * 4.4, hy2 - 0.6], [hx - side * 7.4, hy2 + 2.8], OUT, 2.6)
		seg([hx - side * 4.4, hy2 - 0.6], [hx - side * 7.4, hy2 + 2.8], o.wrap, 1.4)
	elif o.has("cap"):
		P(domeP(hx, hy2 - 0.8, 4.9), o.cap)
		P([[hx + side * 2, hy2 - 1.6], [hx + side * 7.6, hy2 - 0.9], [hx + side * 7, hy2 + 0.5], [hx + side * 1.6, hy2]], dark(o.cap, 0.25))
	elif o.has("boonie"):
		oval(hx, hy2 - 1.6, 8.2, 2.6, OUT, xf)
		oval(hx, hy2 - 1.6, 7.4, 2, o.boonie, xf)
		P(domeP(hx, hy2 - 1.8, 4.4), dark(o.boonie, 0.12))
	elif o.has("pcap"):
		P(rectP(hx, hy2 - 3.9, 10.6, 3.8), o.pcap)
		P([[hx - 5.4, hy2 - 2.2], [hx + 5.4, hy2 - 2.2], [hx + side * 7.4, hy2 - 0.4], [hx - side * 0.8, hy2 - 0.8]], dark(o.pcap, 0.35))
		disc(hx + side * 1.6, hy2 - 4, 1.3, OUT)
		disc(hx + side * 1.6, hy2 - 4, 0.9, "#e2c25a")
	elif o.has("hair"):
		disc(hx, hy2 - 5.6, 6.1, OUT)
		disc(hx, hy2 - 5.6, 5.5, o.hair)
	elif o.has("headband"):
		neon([hx - 5, hy2 - 2.2], [hx + 5, hy2 - 2.2], o.headband)
	if o.get("cross", false):   # the medic's (and Quartermaster's) red cross on the back shoulder
		var cc := [shB[0], shB[1] + 2.2]
		cv.draw_rect(Rect2(cc[0] - 1.9, cc[1] - 1.3, 3.8, 3.6), _c("#efe6d2"))
		cv.draw_rect(Rect2(cc[0] - 0.5, cc[1] - 0.9, 1, 2.8), _c("#c43a3a"))
		cv.draw_rect(Rect2(cc[0] - 1.4, cc[1] + 0.05, 2.8, 1), _c("#c43a3a"))
	if front:
		gun_arms(hand, sd, gl, shB, shF, body, nogun, bob, bp, weapon, swing, wear)
	if o.has("hp") and o.hp < 1:
		cv.draw_rect(Rect2(-8, -41, 16, 2.6), _c(Color(10 / 255.0, 8 / 255.0, 6 / 255.0, 0.8)))
		cv.draw_rect(Rect2(-8, -41, 16 * maxf(0, o.hp), 2.6), _c("#d65a3a"))
	cv.draw_set_transform_matrix(Transform2D.IDENTITY)
	main.draw_alpha = keep_alpha
	if o.has("tag"):
		main.label(o.tag, s.x, s.y - 46 * v.u * BG, main.c(o.get("tag_col", "#a9bccb")), 11 if BG > 1 else 9)


## someone down: lying on their side, a revive ring filling round them
static func downed(main, x: float, y: float, o: Dictionary, prog: float, tag: String) -> void:
	m = main
	cv = main.cv
	var v: IsoView = main.v
	var s: Vector2 = main.iso(x, y)
	var k: float = v.u * FIG
	var xf := Transform2D(0, Vector2(k, k), 0, s)
	cv.draw_set_transform_matrix(xf)
	oval(0, 0, 13, 5.5, Color(0, 0, 0, 0.38), xf)
	var ax := Vector2(0.944, 0.33)
	var pr := Vector2(-0.33, 0.944)
	var at := func(a: float, p: float) -> Array: return [ax.x * a + pr.x * p, -3 + ax.y * a + pr.y * p]
	var pants = o.get("pants", "#3b372c")
	limb(at.call(-3, 2), at.call(-10, 2.6), pants, 3.2)
	limb(at.call(-3, -2), at.call(-10, -1.6), pants, 3.2)
	P([at.call(-3, 5), at.call(7, 5.8), at.call(7, -5.8), at.call(-3, -5)], o.body)
	P([at.call(-1, 4), at.call(6, 4.6), at.call(6, -4.6), at.call(-1, -4)], o.vest, false)
	var hc: Array = at.call(11.5, 0)
	disc(hc[0], hc[1], 5.1, OUT)
	disc(hc[0], hc[1], 4.3, o.head)
	if o.has("helmet"):
		P(domeP(hc[0], hc[1] - 0.4, 5.2), o.helmet)
	cv.draw_set_transform_matrix(Transform2D.IDENTITY)
	main.label(tag, s.x, s.y - 20 * v.u, main.c("#d65a3a"), 10)
	if prog > 0:
		cv.draw_arc(Vector2(s.x, s.y - 10 * v.u), 10 * v.u, -PI / 2, -PI / 2 + TAU * clampf(prog, 0, 1), 32, main.c("#a9bccb"), 3 * v.u)
