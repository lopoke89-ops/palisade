extends Node2D
## The client: input, camera, procedural drawing (ported from 15-render.js / 16-characters.js / 17-scenery.js) and the HUD.
## Everything is drawn with CanvasItem calls in _draw, the same shapes the browser paints on its Canvas2D.

const FIG := 1.18
const PART_CAP := 600

var sim := Sim.new()
var audio := PalAudio.new()
var v := IsoView.new()
var parts: Array = []
var flashes: Array = []
var rings: Array = []
var zaps: Array = []
var slashes: Array = []
var armory_open := false
var arm_buttons: Array = []   # [Rect2, key] drawn this frame, clicked in _unhandled_input
var floats: Array = []
var toasts: Array = []
var shake := 0.0
var shake_t := 0.0
var font: Font
var mouse_seen := false


func _ready() -> void:
	font = ThemeDB.fallback_font
	sim.new_game()
	audio.sim = sim
	add_child(audio)
	_resize()
	v.cam_snap(sim.player.x, sim.player.y)
	get_viewport().size_changed.connect(_resize)
	toasts.append({"title": "THE YARD", "body": "Gather wood (walk into a pile), SPACE to build, 1-3 material, F door, G grenade, Q rocket, E armory at the stake, H Delgado follow/defend, ENTER to start the raid early.", "t": 7.0})


func _exit_tree() -> void:
	sim.dispose()


func _resize() -> void:
	var s := get_viewport_rect().size
	v.resize(s.x, s.y)


# ---------------------------------------------------------------- input

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		mouse_seen = true
	if armory_open:
		_armory_input(e)
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.keycode
		if k == KEY_ESCAPE or k == KEY_P:
			if sim.game.phase != "over":
				sim.game.paused = not sim.game.paused
			return
		if sim.game.phase == "over" or sim.game.paused:
			if k == KEY_ENTER or k == KEY_R:
				_restart()
			return
		match k:
			KEY_SPACE:
				sim.local_build()
			KEY_1, KEY_2, KEY_3:
				sim.game.sel = k - KEY_1
			KEY_F:
				sim.game.piece = "door" if sim.game.piece == "wall" else "wall"
			KEY_G:
				var w := _mouse_world()
				sim.throw_nade(sim.player, w.x, w.y)
			KEY_Q:
				var w := _mouse_world() if mouse_seen else Vector2(sim.player.x + sim.player.aim.x * 6, sim.player.y + sim.player.aim.y * 6)
				sim.use_rocket(sim.player, w.x, w.y)
			KEY_E, KEY_U:
				_try_armory()
			KEY_H:
				sim.set_qm_mode("" if sim.qm.mode == "follow" else "follow")
			KEY_ENTER, KEY_KP_ENTER:
				if sim.game.phase == "build":
					sim.start_raid()


func _restart() -> void:
	sim.new_game()
	parts.clear()
	flashes.clear()
	rings.clear()
	zaps.clear()
	slashes.clear()
	armory_open = false
	floats.clear()
	toasts.clear()
	v.cam_snap(sim.player.x, sim.player.y)


func _mouse_world() -> Vector2:
	var m := get_viewport().get_mouse_position()
	return v.screen_to_world(m.x, m.y + v.WH * 0.55)


func _controls() -> Dictionary:
	var mx := (1.0 if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) else 0.0)
	var my := (1.0 if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) else 0.0) - (1.0 if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) else 0.0)
	var mag := minf(1.0, Vector2(mx, my).length())
	var mv := v.sdir_to_world(mx, my) * mag
	var aim := Vector2.ZERO
	var p: Dictionary = sim.player
	if mouse_seen:
		var w := _mouse_world()
		var d := Vector2(w.x - p.x, w.y - p.y)
		aim = d.normalized() if d.length() > 0 else Vector2(1, 0)
	return {"move": mv, "aim": aim, "fire": mouse_seen and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)}


# ---------------------------------------------------------------- frame

func _process(dt: float) -> void:
	sim.update(dt, _controls())
	_drain_events()
	_update_fx(minf(dt, 0.05))
	var sh := Vector2.ZERO
	if shake > 0.1:
		shake_t += dt
		sh = Vector2(sin(shake_t * 71.0), cos(shake_t * 57.0)) * shake * v.u
		shake *= pow(0.02, dt)
	v.cam_follow(sim.player.x, sim.player.y, sh)
	queue_redraw()


func _drain_events() -> void:
	for e in sim.events:
		match e.k:
			"sfx":
				audio.play(e.name, e.x, e.y)
			"emit":
				for n in e.n:
					_emit(e.x, e.y, e.kind, e.mat)
			"flt":
				floats.append({"x": e.x, "y": e.y, "text": e.text, "col": Color.html(e.col), "t": 1.4})
			"toast":
				toasts = [{"title": e.title, "body": e.body, "t": 4.5}]
			"flash":
				flashes.append({"x": e.x, "y": e.y, "life": e.life, "max": e.life, "r": e.r, "muzzle": e.get("muzzle", false)})
			"ring":
				rings.append({"x": e.x, "y": e.y, "r0": e.r0, "r1": e.r1, "life": e.life, "max": e.life, "c1": e.c1, "w": 2.0})
			"zap":
				zaps.append({"pts": e.pts, "life": 0.38, "max": 0.38})
			"slash":
				slashes.append({"x": e.x, "y": e.y, "ax": e.ax, "ay": e.ay, "life": 0.28, "max": 0.28})
			"shake":
				var d := Vector2(e.x - sim.player.x, e.y - sim.player.y).length()
				shake = maxf(shake, e.amt * clampf(1.0 - d / 14.0, 0.2, 1.0))
	sim.events.clear()


const PCOL := {"blood": ["#8a1c14", "#b0281c"], "dust": ["#8a7a62", "#a69276"], "splinter": ["#b8894f", "#8b6236"], "spark": ["#ffd27a", "#fff2c4"],
	"chunk": ["#6b4a28", "#4f361d"], "fire": ["#ff9a3a", "#ffd27a"], "smoke": ["#3a3530", "#4a443c"]}


func _emit(x: float, y: float, kind: String, mat: int) -> void:
	if parts.size() >= PART_CAP:
		return
	var cols: Array = PCOL.get(kind, PCOL.dust)
	if kind == "chunk" or kind == "dust":
		cols = [Pal.MAT[mat].top, Pal.MAT[mat].l]
	var a := randf() * TAU
	var sp := randf_range(0.5, 2.2) * (2.0 if kind == "spark" or kind == "fire" else 1.0)
	var life := randf_range(0.3, 0.8) * (2.0 if kind == "smoke" else 1.0)
	parts.append({"x": x, "y": y, "vx": cos(a) * sp, "vy": sin(a) * sp, "z": 10.0, "vz": randf_range(20, 70) * (-0.3 if kind == "smoke" else 1.0),
		"life": life, "max": life, "col": Color.html(cols[randi() % cols.size()]), "kind": kind, "s": 1.6 if kind == "chunk" else 1.0})


func _update_fx(dt: float) -> void:
	for q in parts:
		q.life -= dt
		q.x += q.vx * dt
		q.y += q.vy * dt
		q.z += q.vz * dt
		if q.kind == "smoke":
			q.vz = -15.0
		else:
			q.vz -= 160.0 * dt
		if q.z < 0:
			q.z = 0.0
			q.vx *= 0.5
			q.vy *= 0.5
			q.vz = 0.0
	parts = parts.filter(func(q): return q.life > 0)
	for z in zaps:
		z.life -= dt
	zaps = zaps.filter(func(z): return z.life > 0)
	for sl in slashes:
		sl.life -= dt
	slashes = slashes.filter(func(sl): return sl.life > 0)
	for r in rings:
		r.life -= dt
	rings = rings.filter(func(r): return r.life > 0)
	for f in flashes:
		f.life -= dt
	flashes = flashes.filter(func(f): return f.life > 0)
	for f in floats:
		f.t -= dt
	floats = floats.filter(func(f): return f.t > 0)
	for t in toasts:
		t.t -= dt
	toasts = toasts.filter(func(t): return t.t > 0)


# ---------------------------------------------------------------- drawing helpers (15-render.js)

func c(h: String) -> Color:
	return Color.html(h)


func quad(a: Vector2, b: Vector2, cc: Vector2, d: Vector2, fill: Color) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, cc, d]), fill)


func up(p: Vector2, h: float) -> Vector2:
	return Vector2(p.x, p.y - h)


## boxR: an iso box from (x0,y0) to (x1,y1) on the ground, z pixels up, h pixels tall. Returns its base corners.
func box_r(x0: float, y0: float, x1: float, y1: float, z: float, h: float, top: Color, l: Color, r: Color) -> Dictionary:
	var A := v.iso(x0, y0)
	var B := v.iso(x1, y0)
	var C := v.iso(x1, y1)
	var D := v.iso(x0, y1)
	quad(up(D, z), up(C, z), up(C, z + h), up(D, z + h), l)
	quad(up(C, z), up(B, z), up(B, z + h), up(C, z + h), r)
	quad(up(A, z + h), up(B, z + h), up(C, z + h), up(D, z + h), top)
	return {"A": A, "B": B, "C": C, "D": D}


func oval(cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	draw_set_transform(Vector2(cx, cy), 0, Vector2(1, ry / rx))
	draw_circle(Vector2.ZERO, rx, col)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func label(text: String, x: float, y: float, col: Color, size: int = 11) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(x - w / 2 + 1, y + 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(x - w / 2, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func mixc(a: String, b: String, t: float) -> Color:
	return c(a).lerp(c(b), t)


# ---------------------------------------------------------------- the scene

func _draw() -> void:
	var N: int = sim.N
	var u := v.u
	var WH := v.WH
	draw_rect(Rect2(Vector2.ZERO, Vector2(v.W, v.H)), c("#151a12"))
	# the land outside the fence (paintBack)
	for i in range(-6, N + 6):
		for j in range(-6, N + 6):
			if i >= 0 and j >= 0 and i < N and j < N:
				continue
			var dx := -i if i < 0 else (i - N + 1 if i >= N else 0)
			var dy := -j if j < 0 else (j - N + 1 if j >= N else 0)
			var d := maxi(dx, dy)
			var h := Pal.hash2(i + 400, j + 77)
			var col: Color
			if d == 1:
				col = c("#342d21") if h < 0.5 else c("#2f2a1e")
			else:
				col = mixc("#1f2518", "#262c1b", h).lerp(c("#171c13"), clampf((d - 2) / 6.0, 0, 1))
			quad(v.iso(i, j), v.iso(i + 1, j), v.iso(i + 1, j + 1), v.iso(i, j + 1), col)
	# the yard's ground (groundCol for the Yard)
	for i in N:
		for j in N:
			var h := Pal.hash2(i, j)
			var col := c("#3d3528") if h < 0.2 else (c("#352e23") if h < 0.75 else c("#2f291f"))
			quad(v.iso(i, j), v.iso(i + 1, j), v.iso(i + 1, j + 1), v.iso(i, j + 1), col)
			if h > 0.86:
				var cc := v.iso(i + 0.5, j + 0.5)
				oval(cc.x + (h - 0.9) * 40 * u, cc.y, 6 * u, 2.5 * u, Color(84 / 255.0, 104 / 255.0, 64 / 255.0, 0.35))
	for s in N + 1:
		draw_line(v.iso(s, 0), v.iso(s, N), Color(0, 0, 0, 0.22), 1.0)
		draw_line(v.iso(0, s), v.iso(N, s), Color(0, 0, 0, 0.22), 1.0)
	# debris lies flat under everything
	for k in N * N:
		if sim.debris[k] != 0 and sim.walls[k] == null:
			_draw_debris(k % N, k / N, sim.debris[k] - 1)
	# burning ground from a firebrand's bottle
	for f in sim.fires:
		var fc := v.iso(f.x, f.y)
		var a: float = clampf(f.t / 1.0, 0, 1)
		var flick := 0.9 + 0.1 * sin(sim.game.time * 17.0 + f.x * 3.0)
		oval(fc.x, fc.y, f.r * v.TW2 * flick, f.r * v.TH2 * flick, Color(1, 0.45, 0.12, 0.35 * a))
		oval(fc.x, fc.y, f.r * v.TW2 * 0.55, f.r * v.TH2 * 0.55, Color(1, 0.75, 0.3, 0.45 * a))
	for r in rings:
		var rc := v.iso(r.x, r.y)
		var t: float = 1.0 - r.life / r.max
		var rr: float = lerpf(r.r0, r.r1, t)
		draw_set_transform(rc, 0, Vector2(1, v.TH2 / v.TW2))
		draw_arc(Vector2.ZERO, rr * v.TW2, 0, TAU, 48, Color(c(r.c1), 1.0 - t), r.w * u)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# the build ghost
	_draw_ghost()
	# depth-sorted items: walls/nodes/stake key i+j+1, people x+y
	var items: Array = []
	for k in N * N:
		if sim.walls[k] != null:
			items.append([k % N + k / N + 1.0, 0, k])
	for n in sim.nodes:
		items.append([n.i + n.j + 1.0, 1, n])
	items.append([sim.core.i + sim.core.j + 1.0, 2, null])
	for e in sim.enemies:
		items.append([e.x + e.y, 3, e])
	items.append([sim.qm.x + sim.qm.y, 4, sim.qm])
	items.append([sim.player.x + sim.player.y, 5, sim.player])
	for s in sim.sacks:
		items.append([s.x + s.y, 6, s])
	for ch in sim.charges:
		items.append([ch.x + ch.y, 7, ch])
	items.sort_custom(func(a, b): return a[0] < b[0])
	for it in items:
		match it[1]:
			0:
				_draw_wall(it[2] % N, it[2] / N, sim.walls[it[2]])
			1:
				_draw_node(it[2])
			2:
				_draw_stake()
			3:
				var e: Dictionary = it[2]
				var o: Dictionary = (Sim.BOSSES[e.boss].look if e.type == "boss" else LOOK.get(e.type, LOOK.rifle)).duplicate()
				o.merge({"aim": e.aim, "walk": e.walk, "flash": e.flash > 0, "hp": e.hp / e.max}, true)
				if e.type == "boss":
					o.big = 1.45
					o.erase("hp")   # bosses have the bar at the top of the screen
					o.tag = Sim.BOSSES[e.boss].name
					o.tag_col = Sim.BOSSES[e.boss].col
				if e.type == "breach":
					o.satchel = not e.planted
				if e.type == "shield":
					o.shield_wear = 1.0 - float(e.shieldHitsLeft) / e.shieldHitsMax
					if e.shieldBroken:
						o.weapon = "pistol"
				if e.type == "medic" and sim.game.phase == "raid":
					var mc := v.iso(e.x, e.y)
					draw_set_transform(mc, 0, Vector2(1, v.TH2 / v.TW2))
					draw_arc(Vector2.ZERO, v.TW2 * 2.6, 0, TAU, 48, Color(143 / 255.0, 224 / 255.0, 160 / 255.0, 0.35), 1.2 * v.u)
					draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
				_draw_person(e.x, e.y, o)
			4:
				var q: Dictionary = it[2]
				if q.alive:
					var o: Dictionary = QM_LOOK.duplicate()
					o.merge({"aim": q.aim, "walk": q.walk, "flash": q.flash > 0, "hp": q.hp / q.max, "tag": "DELGADO"}, true)
					_draw_person(q.x, q.y, o)
				else:
					_draw_downed(q.x, q.y, "DELGADO · DOWN", q.revive / 2.2)
			5:
				var p: Dictionary = it[2]
				if p.alive:
					var o: Dictionary = SOLDIER_LOOK.duplicate()
					o.merge({"aim": p.aim, "walk": p.walk, "flash": p.flash > 0, "ring": "#e2b436"}, true)
					if p.markT > 0:
						o.ring = "#ff5a4a"   # spotted
					_draw_person(p.x, p.y, o)
				elif p.downed:
					_draw_downed(p.x, p.y, "DOWN · %ds" % ceili(p.rt), p.revive / 2.2)
			6:
				var s: Dictionary = it[2]
				var sc := v.iso(s.x, s.y)
				oval(sc.x, sc.y, 6 * u, 3 * u, Color(0, 0, 0, 0.35))
				oval(sc.x, sc.y - 4 * u, 5 * u, 5 * u, c("#cbbf9f"))
			7:
				var ch: Dictionary = it[2]
				var cs := v.iso(ch.x, ch.y)
				draw_rect(Rect2(cs.x - 5 * u, cs.y - 5 * u, 10 * u, 6 * u), c("#1a1510"))
				if sin(sim.game.time * (20.0 - ch.fuse * 5.0)) > 0:
					draw_circle(Vector2(cs.x, cs.y - 6 * u), 2 * u, c("#ff5a3a"))
	_draw_boss_fx()
	for r in sim.rockets:
		var rp := v.iso(r.x, r.y)
		var dir := v.world_dir_to_screen(Vector2(r.vx, r.vy))
		var hpx := v.WH * 0.6
		draw_line(Vector2(rp.x, rp.y - hpx) - dir * 7 * v.u, Vector2(rp.x, rp.y - hpx) + dir * 4 * v.u, c("#4a4a3a"), 3.2 * v.u)
		draw_circle(Vector2(rp.x, rp.y - hpx) - dir * 8 * v.u, (2.2 + randf()) * v.u, c("#ffb04a"))
		if randf() < 0.6:
			_emit(r.x, r.y, "smoke", 0)
	for z in zaps:
		var a: float = z.life / z.max
		var pts := PackedVector2Array()
		for n in z.pts.size() - 1:
			var p0 := v.iso(z.pts[n].x, z.pts[n].y) - Vector2(0, v.WH * 0.6)
			var p1 := v.iso(z.pts[n + 1].x, z.pts[n + 1].y) - Vector2(0, v.WH * 0.6)
			pts.append(p0)
			for q in 6:
				var t := (q + 1) / 7.0
				var nrm := (p1 - p0).orthogonal().normalized()
				pts.append(p0.lerp(p1, t) + nrm * randf_range(-6, 6) * v.u)
			pts.append(p1)
		if pts.size() > 1:
			draw_polyline(pts, Color(c("#7fe0ff"), 0.5 * a), 5 * v.u)
			draw_polyline(pts, Color(1, 1, 1, a), 1.6 * v.u)
	for sl in slashes:
		var sp := v.iso(sl.x, sl.y)
		var a: float = sl.life / sl.max
		var a0 := v.world_dir_to_screen(Vector2(sl.ax, sl.ay)).angle()
		draw_set_transform(Vector2(sp.x, sp.y - v.WH * 0.6), 0, Vector2(1, 0.6))
		draw_arc(Vector2.ZERO, v.TW2 * 1.2, a0 - 1.1, a0 + 1.1, 18, Color(1, 0.9, 0.85, 0.8 * a), 3 * v.u)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# grenades in the air
	for l in sim.lobs:
		var t: float = clampf(l.t / l.T, 0, 1)
		var x: float = lerpf(l.x0, l.x1, t)
		var y: float = lerpf(l.y0, l.y1, t)
		var g := v.iso(x, y)
		var arc := sin(t * PI) * WH * 2.2
		oval(g.x, g.y, 3 * u, 1.5 * u, Color(0, 0, 0, 0.3))
		draw_circle(Vector2(g.x, g.y - WH * 0.5 - arc), 2.6 * u, c("#3d4a2a"))
	# tracers
	for b in sim.bullets:
		var p0 := v.iso(b.x, b.y)
		var p1 := v.iso(b.x - b.vx * 0.02, b.y - b.vy * 0.02)
		var col := c("#ffe9a8") if b.team == 0 else c("#ff8a5a")
		draw_line(Vector2(p0.x, p0.y - WH * 0.62), Vector2(p1.x, p1.y - WH * 0.62), col, maxf(1.0, 1.6 * u))
	# particles
	for q in parts:
		var pp := v.iso(q.x, q.y)
		var a: float = clampf(q.life / q.max, 0, 1)
		var col: Color = q.col
		col.a = a
		draw_rect(Rect2(pp.x - 1.2 * u * q.s, pp.y - q.z * u - 1.2 * u * q.s, 2.4 * u * q.s, 2.4 * u * q.s), col)
	for f in flashes:
		var fp := v.iso(f.x, f.y)
		var a: float = f.life / f.max
		draw_circle(Vector2(fp.x, fp.y - WH * 0.5), f.r * v.TW2 * (0.5 if f.muzzle else 0.9) * (0.6 + 0.4 * a), Color(1, 0.85, 0.5, 0.45 * a))
	for f in floats:
		var fp := v.iso(f.x, f.y)
		var col: Color = f.col
		col.a = clampf(f.t / 0.5, 0, 1)
		label(f.text, fp.x, fp.y - WH * 1.6 - (1.4 - f.t) * 18 * u, col, 11)
	_draw_hud()


func _draw_debris(i: int, j: int, mat: int) -> void:
	var m: Dictionary = Pal.MAT[mat]
	for n in 4:
		var hs := Pal.hash2(i * 5 + n, j * 3 + n)
		var hs2 := Pal.hash2(i * 3 + n, j * 7 + n)
		box_r(i + 0.15 + hs * 0.55, j + 0.15 + hs2 * 0.55, i + 0.3 + hs * 0.55, j + 0.3 + hs2 * 0.55, 0, 3 * v.u, c(m.top).darkened(0.25), c(m.l).darkened(0.25), c(m.r).darkened(0.25))


## drawWallShape for ordinary walls and doors (15-render.js)
func _draw_wall(i: int, j: int, w: Dictionary) -> void:
	var u := v.u
	var m: Dictionary = Pal.MAT[w.mat]
	var st := Pal.wall_state(w)
	var h := v.WH * (0.58 if st == 2 else 1.0)
	var top := c(m.top)
	var l := c(m.l)
	var r := c(m.r)
	if w.char > 0:
		top = top.lerp(c("#241b15"), w.char * 0.85)
		l = l.lerp(c("#1d1612"), w.char * 0.85)
		r = r.lerp(c("#18120f"), w.char * 0.85)
	if w.flash > 0:
		top = c(m.top).lerp(Color.WHITE, 0.35)
	var bx := box_r(i + 0.03, j + 0.03, i + 0.97, j + 0.97, 0, h, top, l, r)
	var B: Vector2 = bx.B
	var C: Vector2 = bx.C
	var D: Vector2 = bx.D
	var lw := maxf(1.0, u * 0.9)
	var line: Color = m.line
	if w.mat == 2:
		for t in [0.2, 0.4, 0.6, 0.8]:
			for pq in [[D, C], [C, B]]:
				var a: Vector2 = pq[0].lerp(pq[1], t)
				draw_line(a, Vector2(a.x, a.y - h), line, lw)
	else:
		for vv in [0.33, 0.66]:
			for pq in [[D, C], [C, B]]:
				draw_line(up(pq[0], h * vv), up(pq[1], h * vv), line, lw)
		if w.mat == 1:
			for pq in [[D, C], [C, B]]:
				for tv in [[0.3, 0.0], [0.7, 0.0], [0.5, 0.33], [0.15, 0.66], [0.85, 0.66]]:
					var a := up(pq[0].lerp(pq[1], tv[0]), h * tv[1])
					draw_line(a, Vector2(a.x, a.y - h * 0.33), line, lw)
	if w.door:
		var dc := c("#3b4142") if w.mat == 2 else (c("#3a2418") if w.mat == 1 else c("#3d2a17"))
		for pq in [[D, C], [C, B]]:
			var a: Vector2 = pq[0].lerp(pq[1], 0.3)
			var b: Vector2 = pq[0].lerp(pq[1], 0.7)
			quad(a, b, up(b, h * 0.82), up(a, h * 0.82), dc)
			var hd := up(pq[0].lerp(pq[1], 0.62), h * 0.42)
			draw_rect(Rect2(hd.x - u, hd.y - u, 2 * u, 2 * u), c("#e2b436"))
	if st > 0:
		var n := 2 if st == 1 else 3
		var col := Color(40 / 255.0, 44 / 255.0, 45 / 255.0, 0.75) if w.mat == 2 and st == 1 else c("#0e0b09")
		for pqs in [[D, C, 1], [C, B, 2]]:
			for q in n:
				var hu := 0.2 + Pal.hash2(i * 7 + q + pqs[2] * 13, j * 5) * 0.6
				var hv := 0.25 + Pal.hash2(i * 3 + q, j * 11 + pqs[2]) * 0.5
				var pt := up(pqs[0].lerp(pqs[1], hu), h * hv)
				oval(pt.x, pt.y, (2.2 + st) * u, (2.8 + st) * u, col)
	if w.fire > 0:
		var cc := v.iso(i + 0.5, j + 0.5)
		var t := Time.get_ticks_msec() / 1000.0
		draw_circle(Vector2(cc.x, cc.y - h), v.TW2 * (0.55 + 0.08 * sin(t * 13.0 + i)), Color(1, 0.55, 0.2, 0.35))
		draw_circle(Vector2(cc.x, cc.y - h - 4 * u), v.TW2 * 0.25, Color(1, 0.8, 0.4, 0.5))


func _draw_node(n: Dictionary) -> void:
	var u := v.u
	var WH := v.WH
	var i: int = n.i
	var j: int = n.j
	if n.type == 0:
		var layers := ceili(n.amt / 16.0)
		if layers == 0:
			box_r(i + 0.3, j + 0.4, i + 0.7, j + 0.55, 0, 2 * u, c("#6b4a28"), c("#4f361d"), c("#3e2a16"))
			return
		for s in layers:
			box_r(i + 0.18, j + 0.22, i + 0.82, j + 0.48, s * 5 * u, 5 * u, c("#c09058"), c("#8b6236"), c("#6b4a28"))
			box_r(i + 0.18, j + 0.52, i + 0.82, j + 0.78, s * 5 * u, 5 * u, c("#b8894f"), c("#86603a"), c("#654626"))
	elif n.type == 1:
		var lk: bool = n.locked
		var cs := [c("#6a5048"), c("#4c3a34"), c("#3a2c28")] if lk else [c(Pal.MAT[1].top), c(Pal.MAT[1].l), c(Pal.MAT[1].r)]
		var bx := box_r(i + 0.1, j + 0.1, i + 0.9, j + 0.9, 0, WH * 1.05, cs[0], cs[1], cs[2])
		var m: Vector2 = bx.D.lerp(bx.C, 0.5)
		oval(m.x, m.y - WH * 0.3, 5 * u, 7 * u, c("#1a1412") if lk else c("#2a0f06"))
		if not lk:
			oval(m.x, m.y - WH * 0.25, 3.4 * u, 4.5 * u, Color(1, (140 + sin(sim.game.time * 6) * 30) / 255.0, 50 / 255.0, 0.8))
		box_r(i + 0.55, j + 0.15, i + 0.8, j + 0.4, WH * 1.05, WH * 0.9, cs[0], cs[1], cs[2])
	else:
		var cs := [c("#5d6262"), c("#454a4a"), c("#353939")] if n.locked else [c(Pal.MAT[2].top), c(Pal.MAT[2].l), c(Pal.MAT[2].r)]
		box_r(i + 0.12, j + 0.2, i + 0.62, j + 0.7, 0, WH * 0.5, cs[0], cs[1], cs[2])
		box_r(i + 0.45, j + 0.1, i + 0.9, j + 0.55, 0, WH * 0.8, cs[0], cs[1], cs[2])
		box_r(i + 0.3, j + 0.55, i + 0.85, j + 0.9, 0, WH * 0.3, cs[0], cs[1], cs[2])
	if n.locked:
		var cc := v.iso(i + 0.5, j + 0.5)
		label("%s · OPENS RAID %d" % ["KILN" if n.type == 1 else "SCRAP", n.unlock], cc.x, cc.y - WH * 2.1, c("#9a8f7a"), 10)


func _draw_stake() -> void:
	var u := v.u
	var WH := v.WH
	var co: Dictionary = sim.core
	var i: int = co.i
	var j: int = co.j
	var f: bool = co.flash > 0
	var band := c("#e2b436")
	var bx := box_r(i + 0.14, j + 0.14, i + 0.86, j + 0.86, 0, WH * 1.15, c("#8a4a34") if f else c("#4d5c40"), c("#6a3424") if f else c("#38452e"), c("#50281c") if f else c("#2a3421"))
	for pq in [[bx.D, bx.C], [bx.C, bx.B]]:
		quad(up(pq[0], WH * 0.62), up(pq[1], WH * 0.62), up(pq[1], WH * 0.8), up(pq[0], WH * 0.8), band)
	var top := v.iso(i + 0.5, j + 0.5)
	var px := top.x
	var py := top.y - WH * 1.15
	draw_line(Vector2(px, py), Vector2(px, py - 28 * u), c("#1b1812"), 2 * u)
	var fl := sin(sim.game.time * 5) * 2 * u
	draw_colored_polygon(PackedVector2Array([Vector2(px, py - 28 * u), Vector2(px + 15 * u, py - 24 * u + fl), Vector2(px, py - 19 * u)]), band)


func _draw_ghost() -> void:
	var p: Dictionary = sim.player
	if not p.alive or sim.game.phase == "over":
		return
	var t := sim.build_target(p, sim.game.sel, sim.game.piece == "door")
	if not sim.inb(t.i, t.j):
		return
	var col := Color(0.56, 0.88, 0.63, 0.28) if t.ok else Color(0.84, 0.35, 0.23, 0.25)
	quad(v.iso(t.i, t.j), v.iso(t.i + 1, t.j), v.iso(t.i + 1, t.j + 1), v.iso(t.i, t.j + 1), col)
	var line := Color(col, 0.8)
	var pts := PackedVector2Array([v.iso(t.i, t.j), v.iso(t.i + 1, t.j), v.iso(t.i + 1, t.j + 1), v.iso(t.i, t.j + 1), v.iso(t.i, t.j)])
	draw_polyline(pts, line, maxf(1.0, v.u))


## The browser's LOOK table (16-characters.js) for raiders, and QM_LOOK for Delgado
const LOOK := {
	"rifle": {"body": "#7e3a2a", "vest": "#3f231a", "pants": "#2b2420", "head": "#b08868", "helmet": "#2f2820", "bandana": "#a8342a"},
	"gren": {"body": "#6c5738", "vest": "#2f261b", "pants": "#2b2420", "head": "#a98262", "helmet": "#241f19", "pack": "#3a2e1f", "bandolier": true, "bandana": "#a8342a"},
	"breach": {"body": "#5a2a22", "vest": "#1f1512", "pants": "#231c19", "head": "#a07a5c", "cap": "#1a1512", "bandana": "#a8342a", "nogun": true},
	"shield": {"body": "#3f4048", "vest": "#23242a", "pants": "#26262b", "head": "#a98262", "helmet": "#2a2b30", "bandana": "#a8342a", "weapon": "shield", "big": 1.1},
	"medic": {"body": "#6a5a48", "vest": "#e8e2d0", "pants": "#2b2420", "head": "#b08868", "helmet": "#e8e2d0", "pack": "#e8e2d0", "cross": true},
	"spotter": {"body": "#4a4a36", "vest": "#2a2a1e", "pants": "#2b2420", "head": "#a98262", "boonie": "#8a2a22", "bandana": "#a8342a"},
	"fire": {"body": "#6a3a1e", "vest": "#2a1a10", "pants": "#231c19", "head": "#a07a5c", "wrap": "#d06a1e", "pack": "#3a2a1a", "weapon": "bottle", "nogun": true},
}
const QM_LOOK := {"body": "#9e9a78", "vest": "#3d4a52", "pants": "#3a3a33", "head": "#b58f6e", "cap": "#3d4a52", "pack": "#5a4a30", "weapon": "sg"}
const SOLDIER_LOOK := {"body": "#4d5c40", "vest": "#38452e", "pants": "#3b372c", "head": "#d8a882", "helmet": "#3a4630"}


## A cut-down drawPerson (16-characters.js): shadow, legs, body, vest, head and headgear, the weapon on the aim side,
## and each raider's one tell (riot shield, satchel, medic kit, red boonie, lit bottle, grenade strap). No cosmetics yet.
func _draw_person(x: float, y: float, o: Dictionary) -> void:
	var s := v.iso(x, y)
	var k: float = v.u * FIG * o.get("big", 1.0)
	var walk: float = o.walk
	var bob := -absf(sin(walk)) * 1.1
	var sd := v.world_dir_to_screen(o.aim)
	var side := 1.0 if sd.x >= 0 else -1.0
	var front := sd.y >= -0.15
	var lit: bool = o.flash
	var body := Color.WHITE if lit else c(o.body)
	var vest := c(o.vest)
	var skin := Color.WHITE if lit else c(o.head)
	var pants := c(o.get("pants", "#3b372c"))
	var dark := c("#1d1a16")
	oval(s.x, s.y, 10 * k, 4.8 * k, Color(0, 0, 0, 0.38))
	draw_set_transform(s, 0, Vector2(k, k))
	if o.has("ring"):
		draw_arc(Vector2.ZERO, 10.5, 0, TAU, 24, c(o.ring), 1.2)
	var sw := sin(walk) * 2.6
	var hy := -12 + bob
	draw_line(Vector2(-2.5, hy), Vector2(-2.8 + sw, -2), pants, 3.2)
	draw_line(Vector2(2.5, hy), Vector2(2.8 - sw, -2), pants, 3.2)
	draw_rect(Rect2(-2.8 + sw + side * 0.8 - 2.3, -2 + 0.6 - 1.3, 4.6, 2.6), c("#1a1612"))
	draw_rect(Rect2(2.8 - sw + side * 0.8 - 2.3, -2 + 0.6 - 1.3, 4.6, 2.6), c("#1a1612"))
	var hand := Vector2(sd.x * 6, -17 + bob + sd.y * 3)
	var weapon: String = o.get("weapon", "")
	var nogun: bool = o.get("nogun", false)
	var held := func() -> void:
		if weapon == "shield":
			# a riot shield held out toward the aim, scuffed as it takes hits
			var cc := Vector2(sd.x * 8, -16 + bob + sd.y * 3)
			var wear: float = o.get("shield_wear", 0.0)
			var sc := c("#9fb3b8").lerp(c("#5d6466"), wear)
			draw_colored_polygon(PackedVector2Array([cc + Vector2(-4.5, -9), cc + Vector2(4.5, -9), cc + Vector2(4.5, 7), cc + Vector2(-4.5, 7)]), Color(sc, 0.9))
			draw_polyline(PackedVector2Array([cc + Vector2(-4.5, -9), cc + Vector2(4.5, -9), cc + Vector2(4.5, 7), cc + Vector2(-4.5, 7), cc + Vector2(-4.5, -9)]), c("#2a2b30"), 0.9)
			draw_rect(Rect2(cc.x - 3, cc.y - 6, 6, 1.6), c("#1c2a30"))
		elif weapon == "bottle":
			var bt := hand + Vector2(0, -3)
			draw_rect(Rect2(bt.x - 1.3, bt.y - 2, 2.6, 5), c("#5a8a4a"))
			var fl := sin(sim.game.time * 20.0) * 0.6
			draw_circle(bt + Vector2(fl, -3.5), 1.6, c("#ffb04a"))
		elif weapon == "rpg":
			var tube := hand + sd * 4.0
			draw_line(tube - sd * 8.0 + Vector2(0, -2), tube + sd * 8.0 + Vector2(0, -2), c("#3d4030"), 4.2)
			draw_circle(tube + sd * 8.0 + Vector2(0, -2), 2.4, c("#6a6e52"))
		elif weapon == "sword":
			draw_line(hand, hand + sd * 13.0 + Vector2(0, -3), c("#d8dcd8"), 1.8)
			draw_line(hand - Vector2(sd.y, -sd.x) * 2.0, hand + Vector2(sd.y, -sd.x) * 2.0, c("#3a2a1a"), 1.6)
		elif weapon == "zap":
			draw_line(hand, hand + sd * 11.0, dark, 2.8)
			draw_circle(hand + sd * 11.0, 1.8, Color(c("#7fe0ff"), 0.6 + 0.4 * sin(sim.game.time * 14.0)))
		elif not nogun:
			var ln := 11.0 if weapon == "sg" else 9.0
			draw_line(hand, hand + sd * ln, dark, 2.6 if weapon == "sg" else 2.4)
	if o.has("pack") and front:
		draw_rect(Rect2(-side * 1.2 - 6.5, -19.5 + bob - 5.5, 13, 11), c(o.pack))
	if not front:
		held.call()
	draw_colored_polygon(PackedVector2Array([Vector2(-6.2, -24.5 + bob), Vector2(6.2, -24.5 + bob), Vector2(4.8, -11.5 + bob), Vector2(-4.8, -11.5 + bob)]), body)
	draw_colored_polygon(PackedVector2Array([Vector2(-5, -23 + bob), Vector2(5, -23 + bob), Vector2(4.3, -14.5 + bob), Vector2(-4.3, -14.5 + bob)]), vest)
	if o.get("cross", false):
		draw_rect(Rect2(-0.8, -21 + bob, 1.6, 5), c("#c8322a"))
		draw_rect(Rect2(-2.5, -19.3 + bob, 5, 1.6), c("#c8322a"))
	if o.get("bandolier", false):
		draw_line(Vector2(-5.2 * side, -23.5 + bob), Vector2(4.6 * side, -13 + bob), c("#8a6a36"), 1.8)
		if front:
			for n in 4:
				var t := (n + 0.6) / 4.4
				draw_circle(Vector2(-5.2 * side + 9.8 * side * t, -23.5 + 10.5 * t + bob), 1.05, c("#8aa83f"))
	if o.has("wrap"):
		draw_rect(Rect2(-6.2, -15 + bob, 12.4, 2), c(o.wrap))
	if o.get("satchel", false):
		draw_rect(Rect2(side * 3, -15 + bob, 5, 4.5), c("#5a4630"))
		draw_rect(Rect2(side * 3 + 1, -14 + bob, 3, 1), c("#d65a3a"))
	draw_circle(Vector2(side * 0.6, -29 + bob), 4.6, skin)
	if o.has("bandana"):
		draw_rect(Rect2(side * 0.6 - 4.4, -28 + bob, 8.8, 2.2), c(o.bandana))
	if o.has("helmet"):
		draw_circle(Vector2(side * 0.3, -31 + bob), 4.4, c(o.helmet))
	elif o.has("cap"):
		draw_circle(Vector2(side * 0.3, -31.5 + bob), 3.9, c(o.cap))
		draw_rect(Rect2(side * 2.2 - 2.5 + side * 1.5, -30.5 + bob, 5, 1.4), c(o.cap))
	elif o.has("boonie"):
		draw_set_transform(s + Vector2(side * 0.3, -31.5 + bob) * k, 0, Vector2(k, k * 0.45))
		draw_circle(Vector2.ZERO, 7.0, c(o.boonie))
		draw_set_transform(s, 0, Vector2(k, k))
		draw_circle(Vector2(side * 0.3, -32.5 + bob), 3.6, c(o.boonie))
		if sin(sim.game.time * 3.0 + x) > 0.7:
			draw_circle(Vector2(side * 4.5, -28 + bob), 1.1, c("#fff6c8"))   # scope glint
	if front:
		if not nogun or weapon == "bottle":
			draw_line(Vector2(side * 5, -22.5 + bob), hand, body, 2.6)
		held.call()
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if o.has("hp") and o.hp < 1:
		draw_rect(Rect2(s.x - 8 * v.u, s.y - 43 * v.u, 16 * v.u, 2.6 * v.u), Color(10 / 255.0, 8 / 255.0, 6 / 255.0, 0.8))
		draw_rect(Rect2(s.x - 8 * v.u, s.y - 43 * v.u, 16 * v.u * maxf(0, o.hp), 2.6 * v.u), c("#d65a3a"))
	if o.has("tag"):
		label(o.tag, s.x, s.y - 46 * v.u * o.get("big", 1.0), c(o.get("tag_col", "#a9bccb")), 11 if o.has("big") else 9)


func _draw_downed(x: float, y: float, text: String, prog: float) -> void:
	var s := v.iso(x, y)
	var u := v.u
	oval(s.x, s.y, 11 * u, 5 * u, Color(0, 0, 0, 0.38))
	oval(s.x, s.y - 3 * u, 10 * u, 4 * u, c("#5a5240"))
	label(text, s.x, s.y - 18 * u, c("#d65a3a"), 10)
	if prog > 0:
		draw_rect(Rect2(s.x - 10 * u, s.y - 14 * u, 20 * u * clampf(prog, 0, 1), 2.5 * u), c("#8fe0a0"))


# ---------------------------------------------------------------- HUD

func _draw_hud() -> void:
	var g: Dictionary = sim.game
	var p: Dictionary = sim.player
	var W := v.W
	var H := v.H
	var gold := c("#e2b436")
	var paper := c("#e8dcc0")
	var dim := c("#9a8f7a")
	# top bar: phase, clock, stake
	draw_rect(Rect2(0, 0, W, 34), Color(10 / 255.0, 8 / 255.0, 6 / 255.0, 0.72))
	var phase_txt: String
	if g.phase == "build":
		phase_txt = "BUILD · RAID %d IN %ds   (ENTER: start now)" % [g.wave + 1, ceili(g.timer)]
	elif g.phase == "raid":
		phase_txt = "RAID %d/%d · %d RAIDERS LEFT" % [g.wave, g.waves, sim.enemies.size() + g.queue.size()]
	else:
		phase_txt = "GAME OVER"
	draw_string(font, Vector2(14, 22), phase_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, paper)
	var bw := 220.0
	var bx := W - bw - 16
	draw_string(font, Vector2(bx - 54, 22), "STAKE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, dim)
	draw_rect(Rect2(bx, 11, bw, 12), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bx, 11, bw * maxf(0, sim.core.hp / sim.core.max), 12), gold)
	# bottom-left: health, materials, grenades
	var y0 := H - 74
	draw_rect(Rect2(10, y0 - 8, 330, 72), Color(10 / 255.0, 8 / 255.0, 6 / 255.0, 0.72))
	draw_string(font, Vector2(20, y0 + 10), "SOLDIER", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, dim)
	draw_rect(Rect2(86, y0, 150, 10), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(86, y0, 150 * maxf(0, p.hp / p.max), 10), c("#8fe0a0") if p.hp / p.max > 0.35 else c("#d65a3a"))
	draw_string(font, Vector2(246, y0 + 10), "NADES %d · RKT %d" % [p.nades, p.rk], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, paper)
	if p.ammoEq[0] != "":
		for A in Sim.AMMO:
			if A.id == p.ammoEq[0]:
				draw_string(font, Vector2(20, y0 - 44), "AMMO · " + A.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c(A.col))
	if sim.can_shop(p) and not armory_open:
		label("E · ARMORY  (%d salvage)" % p.sal, v.W / 2, H - 24, gold, 14)
	_draw_boss_bar()
	for m in 3:
		var x := 20 + m * 100
		var sel: bool = g.sel == m
		var col := c(Pal.MAT[m].top)
		if sel:
			draw_rect(Rect2(x - 4, y0 + 18, 94, 26), Color(col, 0.25))
			draw_rect(Rect2(x - 4, y0 + 18, 94, 26), col, false, 1.5)
		draw_rect(Rect2(x, y0 + 24, 12, 12), col)
		draw_string(font, Vector2(x + 18, y0 + 36), "%d %s %d" % [m + 1, Pal.MAT[m].name, p.mats[m]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, paper if sel else dim)
	draw_string(font, Vector2(20, y0 + 58), "PIECE: %s (F)   SALVAGE %d   DROPS %d" % [g.piece.to_upper(), p.sal, p.kills], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, dim)
	var q: Dictionary = sim.qm
	var qtxt: String = ("DELGADO · %s · %s   (H)" % ["FOLLOW" if q.mode == "follow" else "DEFEND", q.status]) if q.alive else "DELGADO IS DOWN · stand over him"
	draw_rect(Rect2(10, y0 - 34, 330, 22), Color(10 / 255.0, 8 / 255.0, 6 / 255.0, 0.72))
	draw_string(font, Vector2(20, y0 - 18), qtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c("#a9bccb") if q.alive else c("#d65a3a"))
	# what SPACE would do
	if p.alive and g.phase != "over":
		var t := sim.build_target(p, g.sel, g.piece == "door")
		var tc := v.iso(t.i + 0.5, t.j + 0.5)
		var msg: String = ("%s · %d %s" % [t.act, t.cost, Pal.MAT[t.mat].name]) if t.ok else t.reason
		if msg != "":
			label(msg, tc.x, tc.y - v.WH * 1.4, c("#8fe0a0") if t.ok else c("#d65a3a"), 10)
	# toast
	for tt in toasts:
		var a: float = clampf(tt.t / 0.6, 0, 1)
		label(tt.title, W / 2, 78, Color(gold, a), 22)
		label(tt.body, W / 2, 102, Color(paper, a), 13)
	if armory_open:
		_draw_armory()
	elif g.paused or g.phase == "over":
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
		if g.paused:
			label("PAUSED", W / 2, H / 2 - 20, gold, 30)
			label("ESC / P to resume · R to restart", W / 2, H / 2 + 14, paper, 14)
		else:
			label("VICTORY" if g.won else "DEFEAT", W / 2, H / 2 - 30, gold if g.won else c("#d65a3a"), 34)
			var st: Dictionary = g.stats
			label("Raids survived %d · Raiders dropped %d · Walls raised %d · Walls lost %d" % [g.wave - (0 if g.won else 1), st.dropped, st.built, st.lost], W / 2, H / 2 + 6, paper, 14)
			label("ENTER to play again", W / 2, H / 2 + 34, dim, 13)


## boss warnings (drawBossFx in 16-characters.js): the Demolisher's red line and landing ring, the Butcher's wedge and
## charge lane, the Stormcaller's blue line (dashed while it tracks you, solid once it locks)
func _draw_boss_fx() -> void:
	var u := v.u
	var ch := v.WH * 0.55
	var pulse := 0.55 + 0.45 * sin(sim.game.time * 22.0)
	for e in sim.enemies:
		if e.type != "boss" or e.st == 0:
			continue
		var f: float = maxf(0.0, e.stT / e.stM)
		var b0 := v.iso(e.x, e.y)
		if e.boss == "demolisher":
			var a := atan2(e.ly - e.y, e.lx - e.x)
			var L := Vector2(e.lx - e.x, e.ly - e.y).length()
			var col := Color(1, 60 / 255.0, 40 / 255.0, 0.5 + 0.45 * pulse)
			for o in ([-0.3, 0.0, 0.3] if e.st == 2 else [0.0]):
				var q := v.iso(e.x + cos(a + o) * L, e.y + sin(a + o) * L)
				draw_dashed_line(b0 - Vector2(0, ch * 1.2), q - Vector2(0, ch * 1.2), col, 2.2 * u, 7 * u)
				draw_set_transform(q, 0, Vector2(1, 0.5))
				draw_arc(Vector2.ZERO, v.TW2 * 1.5 * (1.15 - f * 0.15), 0, TAU, 40, col, 2.2 * u)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		elif e.boss == "butcher" and e.st == 1:
			var a0 := atan2(e.aim.y, e.aim.x)
			var pts := PackedVector2Array([b0])
			for k in 11:
				var a := a0 + (k / 10.0 - 0.5) * 2.4
				pts.append(v.iso(e.x + cos(a) * 1.5, e.y + sin(a) * 1.5))
			draw_colored_polygon(pts, Color(1, 50 / 255.0, 40 / 255.0, 0.18 + 0.2 * pulse))
		elif e.boss == "butcher" and e.st == 2:
			var dx: float = e.lx - e.x
			var dy: float = e.ly - e.y
			var l := maxf(0.001, Vector2(dx, dy).length())
			var nx := -dy / l * 0.45
			var ny := dx / l * 0.45
			var P := PackedVector2Array([v.iso(e.x + nx, e.y + ny), v.iso(e.lx + nx, e.ly + ny), v.iso(e.lx - nx, e.ly - ny), v.iso(e.x - nx, e.y - ny)])
			draw_colored_polygon(P, Color(1, 50 / 255.0, 40 / 255.0, 0.16 + 0.22 * pulse))
			P.append(P[0])
			draw_polyline(P, Color(1, 80 / 255.0, 60 / 255.0, 0.6 + 0.3 * pulse), 1.6 * u)
		elif e.boss == "storm":
			var dx: float = e.lx - e.x
			var dy: float = e.ly - e.y
			var l := maxf(0.001, Vector2(dx, dy).length())
			var q := v.iso(clampf(e.x + dx / l * 12, 0, sim.N), clampf(e.y + dy / l * 12, 0, sim.N))
			var locked := f < 0.36
			var col := Color(127 / 255.0, 224 / 255.0, 1, (0.75 + 0.25 * pulse) if locked else (0.35 + 0.3 * pulse))
			if locked:
				draw_line(b0 - Vector2(0, ch), q - Vector2(0, ch), col, 2.4 * u)
			else:
				draw_dashed_line(b0 - Vector2(0, ch), q - Vector2(0, ch), col, 1.4 * u, 6 * u)


func _draw_boss_bar() -> void:
	for e in sim.enemies:
		if e.type != "boss":
			continue
		var B: Dictionary = Sim.BOSSES[e.boss]
		var w := minf(420.0, v.W - 40)
		var x := (v.W - w) / 2
		draw_rect(Rect2(x - 2, 114, w + 4, 26), Color(10 / 255.0, 8 / 255.0, 6 / 255.0, 0.8))
		draw_rect(Rect2(x, 128, w * maxf(0, e.hp / e.max), 9), c(B.col))
		label(B.name + (" · ENRAGED" if e.get("rage", false) else ""), v.W / 2, 125, c(B.col), 12)
		return


# ---------------------------------------------------------------- armory (20-locker-ui.js)

func _try_armory() -> void:
	var p: Dictionary = sim.player
	if not sim.shop_open(p):
		return
	if not sim.near_stake(p):
		toasts = [{"title": "ARMORY", "body": "Walk back to the stake to spend salvage.", "t": 3.0}]
		return
	armory_open = true
	sim.game.paused = true


func _close_armory() -> void:
	armory_open = false
	sim.game.paused = false


func _armory_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode in [KEY_ESCAPE, KEY_E, KEY_U, KEY_P]:
			_close_armory()
		elif e.keycode >= KEY_1 and e.keycode <= KEY_9:
			var n: int = e.keycode - KEY_1
			if n < arm_buttons.size():
				_arm_buy(arm_buttons[n][1])
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for b in arm_buttons:
			if b[0].has_point(e.position):
				_arm_buy(b[1])
				return
		if b_close.has_point(e.position):
			_close_armory()


var b_close := Rect2()


func _arm_buy(key: String) -> void:
	var p: Dictionary = sim.player
	var ok: bool
	if key.begins_with("ammo:"):
		ok = sim.buy_ammo(p, key.substr(5))
	else:
		ok = sim.buy_upgrade(p, key)
	if ok:
		audio.play("restock")
	else:
		audio.play("deny")


## armUpgradeSummary
func _arm_summary(k: String, lv: int) -> String:
	var n := mini(Sim.ARM_MAX, lv + 1)
	var pct := func(x: float) -> String: return str(snappedf(100.0 * x, 0.01))
	if k == "n":
		return "+5 stock · +40% blast" if lv >= Sim.ARM_MAX else "Next: +%d stock · +%s%% blast" % [mini(n, 4) + (1 if n >= 8 else 0), pct.call(Sim.arm_boost(n, 0.08, 0.02))]
	var steps := {"d": [0.2, 0.05, "Damage"], "r": [0.1, 0.025, "Cooldown"], "g": [0.12, 0.03, "Reach"], "a": [0.15, 0.0375, "HP"], "dell": [0.15, 0.0375, "Power"]}
	var st: Array = steps[k]
	var sign := "−" if k == "r" else "+"
	var out := "%s %s%s%%" % [st[2], sign, pct.call(Sim.arm_boost(lv, st[0], st[1]))]
	if lv < Sim.ARM_MAX:
		out += " → %s%s%%" % [sign, pct.call(Sim.arm_boost(n, st[0], st[1]))]
	return out


func _draw_armory() -> void:
	arm_buttons.clear()
	var p: Dictionary = sim.player
	var gold := c("#e2b436")
	var paper := c("#e8dcc0")
	var dim := c("#9a8f7a")
	draw_rect(Rect2(0, 0, v.W, v.H), Color(0, 0, 0, 0.55))
	var w := minf(640.0, v.W - 32)
	var rows: Array = []
	for U in Sim.UPG:
		var t: int = p.up[U.k]
		rows.append({"name": U.name, "lvl": t, "what": _arm_summary(U.k, t), "label": "MAXED" if t >= Sim.ARM_MAX else "%d SAL" % U.cost[t], "dis": t >= Sim.ARM_MAX or p.sal < U.cost[t], "key": U.k})
	var L: int = sim.game.get("dellLv", 0)
	rows.append({"name": Sim.DELL_UP.name, "lvl": L, "what": _arm_summary("dell", L), "label": "MAXED" if L >= Sim.ARM_MAX else "%d SAL" % Sim.DELL_UP.cost[L], "dis": L >= Sim.ARM_MAX or p.sal < Sim.DELL_UP.cost[L], "key": "dell"})
	var full: bool = sim.core.hp >= sim.core.max
	var cost := sim.core_fix_cost(p)
	rows.append({"name": "STAKE", "lvl": -1, "what": "%d / %d · +%d health" % [ceili(sim.core.hp), int(sim.core.max), int(Sim.CORE_FIX.hp)], "label": "FULL" if full else "%d SAL" % cost, "dis": full or p.sal < cost, "key": "core"})
	for A in Sim.AMMO:
		var eq: bool = p.ammoEq[0] == A.id
		var ac := 75 if p.ammoEq[0] != "" else 150
		rows.append({"name": A.name, "lvl": -1, "what": A.what, "label": "EQUIPPED" if eq else "%d SAL" % ac, "dis": eq or p.sal < ac, "key": "ammo:" + A.id, "col": A.col})
	var rh := 34.0
	var h := 74.0 + rows.size() * rh + 36
	var x0 := (v.W - w) / 2
	var y0 := maxf(10.0, (v.H - h) / 2)
	draw_rect(Rect2(x0, y0, w, h), c("#16130f"))
	draw_rect(Rect2(x0, y0, w, h), Color(gold, 0.5), false, 1.5)
	draw_string(font, Vector2(x0 + 18, y0 + 26), "ARMORY · BETWEEN RAIDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, dim)
	draw_string(font, Vector2(x0 + 18, y0 + 52), "SALVAGE %d" % p.sal, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, gold)
	draw_string(font, Vector2(x0 + w - 230, y0 + 26), "click or 1-9 · E / Esc closes", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, dim)
	var y := y0 + 70
	for n in rows.size():
		var r: Dictionary = rows[n]
		if n == 5 or n == 7:
			draw_line(Vector2(x0 + 12, y + 1), Vector2(x0 + w - 12, y + 1), Color(dim, 0.3), 1.0)
		var namecol: Color = c(r.col) if r.has("col") else paper
		draw_string(font, Vector2(x0 + 18, y + 22), ("%d " % (n + 1) if n < 9 else "") + r.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, namecol)
		if r.lvl >= 0:
			for k in Sim.ARM_MAX:
				draw_rect(Rect2(x0 + 190 + k * 11, y + 13, 8, 8), gold if k < r.lvl else Color(dim, 0.35))
		draw_string(font, Vector2(x0 + (290 if r.lvl >= 0 else 190), y + 22), r.what, HORIZONTAL_ALIGNMENT_LEFT, w - 420 if r.lvl >= 0 else w - 320, 11, dim)
		var br := Rect2(x0 + w - 116, y + 5, 100, 24)
		draw_rect(br, Color(gold, 0.12) if not r.dis else Color(0.2, 0.2, 0.2, 0.4))
		draw_rect(br, Color(gold, 0.8) if not r.dis else Color(dim, 0.4), false, 1.2)
		var lw := font.get_string_size(r.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2(br.position.x + (br.size.x - lw) / 2, y + 22), r.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, gold if not r.dis else dim)
		arm_buttons.append([br, r.key])
		y += rh
	b_close = Rect2(x0 + w / 2 - 60, y + 4, 120, 26)
	draw_rect(b_close, Color(paper, 0.1))
	draw_rect(b_close, Color(paper, 0.6), false, 1.2)
	label("CLOSE", v.W / 2, y + 22, paper, 12)
