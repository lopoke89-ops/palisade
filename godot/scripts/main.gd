extends Node2D
## The client: input, camera, procedural drawing (ported from 15-render.js / 16-characters.js / 17-scenery.js) and the HUD.
## Everything is drawn with CanvasItem calls in _draw, the same shapes the browser paints on its Canvas2D.

const FIG := 1.18
const PART_CAP := 600

var sim := Sim.new()
var profile := PalProfile.new()
var skills_open := false
var sk_buttons: Array = []
var sk_reset := Rect2()
var run_sp := -1
var mouse_pulls := 0   # left-button presses so far (the bolt and pump guns buffer a click)
var draw_alpha := 1.0   # people drawn faded (stealth) multiply their colours by this
var next_cls := "soldier"   # the next game's setup (C class, M map, X size, V mode, D difficulty on the pause or end screen, until the menus are ported)
var next_opt := {"map": "yard", "size": "std", "mode": "5", "diff": "normal", "mods": []}   # skill points this run earned (shown on the end screen), -1 until the run ends
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
	profile.load_file()
	sim.new_game(-1, next_opt.diff, profile.perk_mods(), _game_opt())
	audio.sim = sim
	add_child(audio)
	_resize()
	v.cam_snap(sim.player.x, sim.player.y, sim.height_at(sim.player.x, sim.player.y))
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
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		mouse_seen = true
		mouse_pulls = (mouse_pulls + 1) & 255
	if armory_open:
		_armory_input(e)
		return
	if skills_open:
		_skills_input(e)
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
			elif k == KEY_K:
				skills_open = true
			elif k == KEY_C:
				next_cls = Pal.CLASS_IDS[(Pal.CLASS_IDS.find(next_cls) + 1) % Pal.CLASS_IDS.size()]
			elif k == KEY_M:
				next_opt.map = PalMaps.MAP_IDS[(PalMaps.MAP_IDS.find(next_opt.map) + 1) % PalMaps.MAP_IDS.size()]
			elif k == KEY_X:
				next_opt.size = "xl" if next_opt.size == "std" else "std"
			elif k == KEY_V:
				var modes := ["5", "10", "endless", "blitz", "campaign"]
				next_opt.mode = modes[(modes.find(next_opt.mode) + 1) % modes.size()]
			elif k == KEY_D:
				var ds := ["easy", "normal", "hard"]
				next_opt.diff = ds[(ds.find(next_opt.diff) + 1) % ds.size()]
			return
		if k == KEY_F8 and OS.is_debug_build():   # developer: bring in the next boss (any boss, any map), editor runs only
			_dev_boss()
			return
		match k:
			KEY_SPACE:
				sim.local_build()
			KEY_1, KEY_2, KEY_3:
				sim.game.sel = k - KEY_1
			KEY_F:
				sim.game.piece = "door" if sim.game.piece == "wall" else "wall"
			KEY_G, KEY_Q:
				var w := _mouse_world() if mouse_seen else Vector2(sim.player.x + sim.player.aim.x * 6, sim.player.y + sim.player.aim.y * 6)
				if k == KEY_Q and sim.player.cls in ["soldier", "sniper"]:   # Q is the class ability where there is one, else a grenade
					sim.use_ability(sim.player, w.x, w.y)
				else:
					sim.throw_nade(sim.player, w.x, w.y)
			KEY_SHIFT:
				sim.local_sprint()
			KEY_R:
				sim.local_reload()
			KEY_E, KEY_U:
				_try_armory()
			KEY_H:
				sim.set_qm_mode("" if sim.qm.mode == "follow" else "follow")
			KEY_ENTER, KEY_KP_ENTER:
				if sim.game.phase == "build":
					sim.start_raid()


func _game_opt() -> Dictionary:
	var o := next_opt.duplicate()
	o.cls = next_cls
	return o


func _setup_line() -> String:
	var mode_names := {"5": "5 RAIDS", "10": "10 RAIDS", "endless": "ENDLESS", "blitz": "BLITZKRIEG RUSH", "campaign": "OPERATION WHITEOUT"}
	return "NEXT GAME · C %s · M %s · X %s · V %s · D %s" % [Pal.CLASSES[next_cls].name, PalMaps.MAPS[next_opt.map].name, next_opt.size.to_upper(), mode_names[next_opt.mode], next_opt.diff.to_upper()]


func _restart() -> void:
	sim.new_game(-1, next_opt.diff, profile.perk_mods(), _game_opt())
	run_sp = -1
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
	var body = _body_under(m.x, m.y)
	return body if body != null else _screen_to_world(m.x, m.y + v.WH * 0.55)


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
	return {"move": mv, "aim": aim, "fire": mouse_seen and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "pulls": mouse_pulls, "auto": not mouse_seen}


# ---------------------------------------------------------------- frame

func _process(dt: float) -> void:
	sim.update(dt, _controls())
	if sim.game.phase == "over" and run_sp < 0:
		run_sp = profile.award_run(sim.qm.completedRaids, sim.game.get("bosses", 0))
	_drain_events()
	_update_fx(minf(dt, 0.05))
	var sh := Vector2.ZERO
	if shake > 0.1:
		shake_t += dt
		sh = Vector2(sin(shake_t * 71.0), cos(shake_t * 57.0)) * shake * v.u
		shake *= pow(0.02, dt)
	v.cam_follow(sim.player.x, sim.player.y, sh, sim.height_at(sim.player.x, sim.player.y))
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
			"map":   # a campaign chapter moved everyone to the next map
				parts.clear()
				rings.clear()
				v.cam_snap(sim.player.x, sim.player.y, sim.height_at(sim.player.x, sim.player.y))
			"shake":
				var d := Vector2(e.x - sim.player.x, e.y - sim.player.y).length()
				shake = maxf(shake, e.amt * clampf(1.0 - d / 14.0, 0.2, 1.0))
	sim.events.clear()


const PCOL := {"blood": ["#8a1c14", "#b0281c"], "dust": ["#8a7a62", "#a69276"], "splinter": ["#b8894f", "#8b6236"], "spark": ["#ffd27a", "#fff2c4"],
	"chunk": ["#6b4a28", "#4f361d"], "fire": ["#ff9a3a", "#ffd27a"], "smoke": ["#3a3530", "#4a443c"], "tealdust": ["#3ae0e0", "#bff4ff"]}


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

## a world point on screen, at the ground's height there (Frostpeak's terraces; flat elsewhere)
func iso(x: float, y: float) -> Vector2:
	return v.iso(x, y, sim.height_at(x, y))


func c(h: String) -> Color:
	var col := Color.html(h)
	col.a *= draw_alpha
	return col


func quad(a: Vector2, b: Vector2, cc: Vector2, d: Vector2, fill: Color) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, cc, d]), fill)


func up(p: Vector2, h: float) -> Vector2:
	return Vector2(p.x, p.y - h)


## boxR: an iso box from (x0,y0) to (x1,y1) on the ground, z pixels up, h pixels tall. Returns its base corners.
func box_r(x0: float, y0: float, x1: float, y1: float, z: float, h: float, top: Color, l: Color, r: Color) -> Dictionary:
	var hz := sim.height_at((x0 + x1) / 2, (y0 + y1) / 2)   # boxR: the whole box stands at its centre's height
	var A := v.iso(x0, y0, hz)
	var B := v.iso(x1, y0, hz)
	var C := v.iso(x1, y1, hz)
	var D := v.iso(x0, y1, hz)
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
			quad(iso(i, j), iso(i + 1, j), iso(i + 1, j + 1), iso(i, j + 1), col)
	_paint_ground()
	_draw_terrain_live()
	# debris lies flat under everything
	for k in N * N:
		if sim.debris[k] != 0 and sim.walls[k] == null:
			_draw_debris(k % N, k / N, sim.debris[k] - 1)
	for fr in sim.frost_fields:
		var qc := iso(fr.x, fr.y)
		oval(qc.x, qc.y, fr.r * v.TW2, fr.r * v.TH2, Color(0.7, 0.95, 1.0, 0.3 * clampf(fr.t / 2.0, 0, 1)))
	# burning ground from a firebrand's bottle (napalm, gas and mines live here too)
	for f in sim.fires:
		var fc := iso(f.x, f.y)
		if f.get("nap", 0) == 2:
			var ga := minf(1.0, f.t) * 0.32
			for n in 5:
				var ox := sin(sim.game.time * 0.7 + n * 1.7) * v.TW2 * 0.5
				var oy := cos(sim.game.time * 0.6 + n * 2.1) * v.TH2 * 0.5
				oval(fc.x + ox, fc.y + oy - n * 2 * v.u, v.TW2 * f.r * (0.55 + 0.1 * n), v.TH2 * f.r * (0.55 + 0.1 * n), Color(120 / 255.0, 200 / 255.0, 70 / 255.0, ga * (0.5 + 0.1 * n)))
			continue
		if f.get("nap", 0) == 3:
			var armed: bool = f.get("arm", 0.0) <= 0
			var blink := sin(sim.game.time * (14.0 if armed else 5.0) + f.x * 7) > 0
			oval(fc.x, fc.y, 5 * v.u, 2.6 * v.u, c("#1a1b1c"))
			oval(fc.x, fc.y - 1.5 * v.u, 4 * v.u, 2 * v.u, c("#3a3c3e"))
			oval(fc.x, fc.y - 2.4 * v.u, 1.6 * v.u, 1 * v.u, (c("#ff3a2a") if armed else c("#ffb03a")) if blink else c("#5a2a1a"))
			continue
		var a: float = clampf(f.t / 1.0, 0, 1)
		var flick := 0.9 + 0.1 * sin(sim.game.time * 17.0 + f.x * 3.0)
		oval(fc.x, fc.y, f.r * v.TW2 * flick, f.r * v.TH2 * flick, Color(1, 0.45, 0.12, 0.35 * a))
		oval(fc.x, fc.y, f.r * v.TW2 * 0.55, f.r * v.TH2 * 0.55, Color(1, 0.75, 0.3, 0.45 * a))
	for r in rings:
		var rc := iso(r.x, r.y)
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
	for k in N * N:
		var t: int = sim.terr[k]
		if t == PalMaps.T_ROCK or t == PalMaps.T_DRUM:
			items.append([k % N + k / N + 1.0, 8, k])
		if sim.is_frost() and sim.heights[k] > 0 and sim.connectors[k] == 0:
			var i := k % N
			var j := k / N
			if (j + 1 < N and sim.heights[k] > sim.heights[k + N] + (1 if sim.connectors[k + N] != 0 else 0)) or (i + 1 < N and sim.heights[k] > sim.heights[k + 1]):
				items.append([i + j + 2.0, 9, k])
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
				var o: Dictionary = (Sim.boss_def(e.boss).look if e.type == "boss" else LOOK.get(e.type, LOOK.rifle)).duplicate()
				o.merge({"aim": e.aim, "walk": e.walk, "flash": e.flash > 0, "hp": e.hp / e.max}, true)
				if e.get("raft", false):
					_draw_raft(e)
				if e.type == "boss" and e.get("burrow", false):
					_draw_mound(e)
					continue
				if e.type == "boss":
					o.big = Sim.boss_def(e.boss).get("big", 1.45)
					o.erase("hp")   # bosses have the bar at the top of the screen
					o.tag = Sim.boss_def(e.boss).name
					o.tag_col = Sim.boss_def(e.boss).col
				if e.type == "breach":
					o.satchel = not e.planted
				if e.type == "shield":
					o.shield_wear = 1.0 - float(e.shieldHitsLeft) / e.shieldHitsMax
					if e.shieldBroken:
						o.weapon = "pistol"
				if e.type == "medic" and sim.game.phase == "raid":
					var mc := iso(e.x, e.y)
					draw_set_transform(mc, 0, Vector2(1, v.TH2 / v.TW2))
					draw_arc(Vector2.ZERO, v.TW2 * 2.6, 0, TAU, 48, Color(143 / 255.0, 224 / 255.0, 160 / 255.0, 0.35), 1.2 * v.u)
					draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
				_draw_person(e.x, e.y, o)
				if e.type == "boss" and e.st == 6:   # dazed
					var sc := iso(e.x, e.y)
					for n in 3:
						var a: float = sim.game.time * 4.0 + n * TAU / 3
						draw_circle(Vector2(sc.x + cos(a) * 10 * v.u, sc.y - v.WH * 2.3 + sin(a) * 4 * v.u), 2.2 * v.u, c("#ffd23a"))
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
					var o: Dictionary = class_look(p.cls)
					o.merge({"aim": p.aim, "walk": p.walk, "flash": p.flash > 0, "ring": "#e2b436"}, true)
					if p.markT > 0:
						o.ring = "#ff5a4a"   # spotted
					if p.bolt > 0:
						o.bolt = 1.0 - p.bolt / p.boltT
					draw_alpha = 0.5 if p.stl > 0 else 1.0   # stealth: see-through
					_draw_person(p.x, p.y, o)
					draw_alpha = 1.0
				elif p.downed:
					_draw_downed(p.x, p.y, "DOWN · %ds" % ceili(p.rt), p.revive / 2.2)
			6:
				var s: Dictionary = it[2]
				var sc := iso(s.x, s.y)
				oval(sc.x, sc.y, 6 * u, 3 * u, Color(0, 0, 0, 0.35))
				oval(sc.x, sc.y - 4 * u, 5 * u, 5 * u, c("#cbbf9f"))
			8:
				_draw_terr_item(it[2] % N, it[2] / N, sim.terr[it[2]])
			9:
				_draw_frost_cliff(it[2])
			7:
				var ch: Dictionary = it[2]
				var cs := iso(ch.x, ch.y)
				draw_rect(Rect2(cs.x - 5 * u, cs.y - 5 * u, 10 * u, 6 * u), c("#1a1510"))
				if sin(sim.game.time * (20.0 - ch.fuse * 5.0)) > 0:
					draw_circle(Vector2(cs.x, cs.y - 6 * u), 2 * u, c("#ff5a3a"))
	_draw_boss_fx()
	for chn in sim.chains:   # the Ferryman's harpoon chain
		draw_dashed_line(iso(chn.x0, chn.y0) - Vector2(0, v.WH * 0.55), iso(chn.x1, chn.y1) - Vector2(0, v.WH * 0.44), Color(200 / 255.0, 205 / 255.0, 200 / 255.0, chn.life / chn.max), 2.2 * v.u, 4 * v.u)
	if sim.game.get("fb") != null and sim.game.fb.evac != null:   # the evac site
		var E: Dictionary = sim.game.fb.evac
		var pulse := 0.55 + 0.45 * sin(sim.game.time * 6.0)
		_disc(E.x, E.y, E.r, Color(138 / 255.0, 1, 154 / 255.0, 0.12 + 0.08 * pulse))
		_ring(E.x, E.y, E.r, Color(138 / 255.0, 1, 154 / 255.0, 0.7 + 0.3 * pulse), 2.4)
		var ev_p: float = sim.player.get("ev", 0.0)
		if ev_p > 0 and not sim.player.get("out", false):
			_ring(E.x, E.y, E.r * clampf(ev_p / Sim.BLITZ.hold, 0, 1), c("#ffffff"), 3.0)
	for r in sim.rockets:
		var rp := iso(r.x, r.y)
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
			var p0 := iso(z.pts[n].x, z.pts[n].y) - Vector2(0, v.WH * 0.6)
			var p1 := iso(z.pts[n + 1].x, z.pts[n + 1].y) - Vector2(0, v.WH * 0.6)
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
		var sp := iso(sl.x, sl.y)
		var a: float = sl.life / sl.max
		var a0 := v.world_dir_to_screen(Vector2(sl.ax, sl.ay)).angle()
		draw_set_transform(Vector2(sp.x, sp.y - v.WH * 0.6), 0, Vector2(1, 0.6))
		draw_arc(Vector2.ZERO, v.TW2 * 1.2, a0 - 1.1, a0 + 1.1, 18, Color(1, 0.9, 0.85, 0.8 * a), 3 * v.u)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for r in sim.arcs:
		var rp := iso(r.x, r.y)
		var dir := v.world_dir_to_screen(Vector2(r.vx, r.vy))
		var nrm := dir.orthogonal()
		var cpt := Vector2(rp.x, rp.y - v.WH * 0.5)
		draw_polyline(PackedVector2Array([cpt - nrm * 12 * v.u - dir * 4 * v.u, cpt + dir * 3 * v.u, cpt + nrm * 12 * v.u - dir * 4 * v.u]), Color(c("#3ae0e0"), 0.5), 6 * v.u)
		draw_polyline(PackedVector2Array([cpt - nrm * 12 * v.u - dir * 4 * v.u, cpt + dir * 3 * v.u, cpt + nrm * 12 * v.u - dir * 4 * v.u]), c("#dffcff"), 2 * v.u)
	# grenades in the air
	for l in sim.lobs:
		if l.get("k", 0) == 3:   # a boss missile shows a ring where it lands for its whole flight
			var lr := iso(l.x1, l.y1)
			draw_set_transform(lr, 0, Vector2(1, 0.5))
			draw_arc(Vector2.ZERO, v.TW2 * l.R, 0, TAU, 40, Color(1, 70 / 255.0, 50 / 255.0, 0.55 + 0.35 * sin(sim.game.time * 22.0)), 2.0 * v.u)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		var t: float = clampf(l.t / l.T, 0, 1)
		var x: float = lerpf(l.x0, l.x1, t)
		var y: float = lerpf(l.y0, l.y1, t)
		var g := iso(x, y)
		var arc := sin(t * PI) * WH * 2.2
		oval(g.x, g.y, 3 * u, 1.5 * u, Color(0, 0, 0, 0.3))
		draw_circle(Vector2(g.x, g.y - WH * 0.5 - arc), 2.6 * u, c("#3d4a2a"))
	# tracers
	for b in sim.bullets:
		var p0 := iso(b.x, b.y)
		var p1 := iso(b.x - b.vx * 0.02, b.y - b.vy * 0.02)
		var col := c("#ffe9a8") if b.team == 0 else c("#ff8a5a")
		draw_line(Vector2(p0.x, p0.y - WH * 0.62), Vector2(p1.x, p1.y - WH * 0.62), col, maxf(1.0, 1.6 * u))
	# particles
	for q in parts:
		var pp := iso(q.x, q.y)
		var a: float = clampf(q.life / q.max, 0, 1)
		var col: Color = q.col
		col.a = a
		draw_rect(Rect2(pp.x - 1.2 * u * q.s, pp.y - q.z * u - 1.2 * u * q.s, 2.4 * u * q.s, 2.4 * u * q.s), col)
	for f in flashes:
		var fp := iso(f.x, f.y)
		var a: float = f.life / f.max
		draw_circle(Vector2(fp.x, fp.y - WH * 0.5), f.r * v.TW2 * (0.5 if f.muzzle else 0.9) * (0.6 + 0.4 * a), Color(1, 0.85, 0.5, 0.45 * a))
	for f in floats:
		var fp := iso(f.x, f.y)
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
	if w.get("slab", false):   # the Foreman's rock slab: a rough grey block, lower as it cracks
		var sst := Pal.wall_state(w)
		var sh := v.WH * (0.45 if sst == 2 else (0.6 if sst == 1 else 0.72))
		var hs := Pal.hash2(i + 7, j + 3)
		box_r(i + 0.1, j + 0.14, i + 0.9, j + 0.86, 0, sh, c("#9a948a") if w.flash > 0 else c("#6f695f"), c("#524d46"), c("#403c37"))
		box_r(i + 0.22 + hs * 0.2, j + 0.24, i + 0.62 + hs * 0.2, j + 0.6, sh, v.WH * 0.18, c("#7d766b"), c("#5c5750"), c("#4a4640"))
		return
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
		var cc := iso(i + 0.5, j + 0.5)
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
		var cc := iso(i + 0.5, j + 0.5)
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
	var top := iso(i + 0.5, j + 0.5)
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
	quad(iso(t.i, t.j), iso(t.i + 1, t.j), iso(t.i + 1, t.j + 1), iso(t.i, t.j + 1), col)
	var line := Color(col, 0.8)
	var pts := PackedVector2Array([iso(t.i, t.j), iso(t.i + 1, t.j), iso(t.i + 1, t.j + 1), iso(t.i, t.j + 1), iso(t.i, t.j)])
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
## buildLook (16-characters.js) on the default "std" skin: each class's kit and headgear
static func class_look(cls: String) -> Dictionary:
	var o := {"body": "#b9aa82", "vest": "#4d6b47", "pants": "#4a4636", "head": "#c19a78"}
	match cls:
		"sniper":
			o.boonie = "#5b5a3c"
			o.weapon = "rifle"
		"grenadier":
			o.pack = "#4a3a26"
			o.bandolier = true
			o.weapon = "sg"
			o.helmet = "#4a5238"
		"quartermaster":
			o.pack = "#5a4a30"
			o.cross = true
			o.cap = "#4a5238"
			o.weapon = "smg"
		_:
			o.helmet = "#4a5238"
	return o


## A cut-down drawPerson (16-characters.js): shadow, legs, body, vest, head and headgear, the weapon on the aim side,
## and each raider's one tell (riot shield, satchel, medic kit, red boonie, lit bottle, grenade strap). No cosmetics yet.
func _draw_person(x: float, y: float, o: Dictionary) -> void:
	var s := iso(x, y)
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
		elif weapon == "swordb":
			draw_line(hand, hand + sd * 13.0 + Vector2(0, -3), c("#9ff4ff"), 2.0)
			draw_line(hand, hand + sd * 13.0 + Vector2(0, -3), Color(c("#3ae0e0"), 0.4), 4.0)
		elif weapon == "drill":
			var tip := hand + sd * 12.0
			draw_colored_polygon(PackedVector2Array([hand + Vector2(sd.y, -sd.x) * 3, hand - Vector2(sd.y, -sd.x) * 3, tip]), c("#8a8f90"))
			draw_line(hand - sd * 2, hand + sd * 3, c("#3a3326"), 4.0)
		elif weapon == "rifle":
			draw_line(hand - sd * 3.0, hand + sd * 16.0, dark, 2.2)
			draw_line(hand + sd * 2.0 + Vector2(0, -2), hand + sd * 6.0 + Vector2(0, -2), dark, 2.6)   # scope
		elif weapon == "smg":
			draw_line(hand, hand + sd * 7.0, dark, 2.6)
			draw_line(hand + sd * 2.0, hand + sd * 2.0 + Vector2(0, 3), dark, 1.6)
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
	var s := iso(x, y)
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
	if g.phase == "build" and sim.campaign():
		phase_txt = "CH %d · BUILD · %s · %s IN %ds   (ENTER: start now)" % [g.chapter + 1, sim.map_def.name, "FINAL EVACUATION" if g.wave == 12 else "RAID %d/3" % (g.wave % 3 + 1), ceili(g.timer)]
	elif g.phase == "build":
		phase_txt = "BUILD · RAID %d IN %ds   (ENTER: start now)" % [g.wave + 1, ceili(g.timer)]
	elif g.phase == "raid":
		phase_txt = "%s · %d RAIDERS LEFT" % [sim.raid_name(g.wave), sim.enemies.size() + g.queue.size()]
		if g.get("fb") != null:
			var ft: float = g.fb.t
			var fbn := "MAP EVAC" if g.fb.get("mapEvac", false) else ("GAUNTLET · WAVE %d/6" % g.fb.wave if g.fb.get("gauntlet", false) else "FINAL BLITZ")
			phase_txt = "%s · %d:%02d · %s" % [fbn, floori(ft / 60), floori(fmod(ft, 60)), "GET TO THE EVAC" if g.fb.evac != null else "%d BOSSES UP" % sim.live_bosses()]
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
	draw_string(font, Vector2(20, y0 + 10), p.C.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, dim)
	draw_rect(Rect2(86, y0, 150, 10), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(86, y0, 150 * maxf(0, p.hp / p.max), 10), c("#8fe0a0") if p.hp / p.max > 0.35 else c("#d65a3a"))
	var kit := "NADES %d" % p.nades
	match p.cls:
		"soldier":
			kit += " · RKT %d" % p.rk
		"sniper":
			kit += (" · HIDDEN %ds" % ceili(p.stl)) if p.stl > 0 else (" · STEALTH %ds" % ceili(p.stlCd) if p.stlCd > 0 else " · STEALTH (Q)")
		"grenadier":
			kit += " · SHELLS %d/%d" % [p.ammo, p.gun.mag]
		"quartermaster":
			kit += " · SPRINT %ds" % ceili(p.sprCd) if p.sprCd > 0 else " · SPRINT (SHIFT)"
	draw_string(font, Vector2(246, y0 + 10), kit, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, paper)
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
		var tc := iso(t.i + 0.5, t.j + 0.5)
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
	elif skills_open:
		_draw_skills()
	elif g.paused or g.phase == "over":
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
		if g.paused:
			label("PAUSED", W / 2, H / 2 - 20, gold, 30)
			label("ESC / P to resume · R to restart · K skill tree", W / 2, H / 2 + 14, paper, 14)
			label(_setup_line(), W / 2, H / 2 + 40, dim, 13)
		else:
			label("VICTORY" if g.won else "DEFEAT", W / 2, H / 2 - 30, gold if g.won else c("#d65a3a"), 34)
			var why := {"evacfail": "Nobody made the convoy out of %s. The campaign ends here." % sim.map_def.name, "deadend": "The crew could not recover. No one left could get them back up.",
				"left": "Left behind at the evac.", "evac": "Out on the last convoy."}
			if why.has(g.end_reason):
				label(why[g.end_reason], W / 2, H / 2 - 8, dim, 13)
			var st: Dictionary = g.stats
			label("Raids survived %d · Raiders dropped %d · Walls raised %d · Walls lost %d" % [g.wave - (0 if g.won else 1), st.dropped, st.built, st.lost], W / 2, H / 2 + 6, paper, 14)
			label("ENTER to play again · K skill tree", W / 2, H / 2 + 34, dim, 13)
			label(_setup_line(), W / 2, H / 2 + 84, dim, 12)
			if run_sp >= 0:
				label("+%d SKILL POINT%s · %d to spend · next in %d raids" % [run_sp, "" if run_sp == 1 else "S", profile.sp, 5 - profile.sp_prog], W / 2, H / 2 + 60, c("#8fe0a0"), 13)


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
		var b0 := iso(e.x, e.y)
		if _draw_new_fx(e, f, pulse, ch):
			continue
		var kb: String = Sim.boss_def(e.boss).get("base", e.boss)
		if e.boss == "demolisher":
			var a := atan2(e.ly - e.y, e.lx - e.x)
			var L := Vector2(e.lx - e.x, e.ly - e.y).length()
			var col := Color(1, 60 / 255.0, 40 / 255.0, 0.5 + 0.45 * pulse)
			for o in ([-0.3, 0.0, 0.3] if e.st == 2 else [0.0]):
				var q := iso(e.x + cos(a + o) * L, e.y + sin(a + o) * L)
				draw_dashed_line(b0 - Vector2(0, ch * 1.2), q - Vector2(0, ch * 1.2), col, 2.2 * u, 7 * u)
				draw_set_transform(q, 0, Vector2(1, 0.5))
				draw_arc(Vector2.ZERO, v.TW2 * 1.5 * (1.15 - f * 0.15), 0, TAU, 40, col, 2.2 * u)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		elif kb == "butcher" and e.st == 1:
			var a0 := atan2(e.aim.y, e.aim.x)
			var pts := PackedVector2Array([b0])
			for k in 11:
				var a := a0 + (k / 10.0 - 0.5) * 2.4
				pts.append(iso(e.x + cos(a) * 1.5, e.y + sin(a) * 1.5))
			draw_colored_polygon(pts, Color(1, 50 / 255.0, 40 / 255.0, 0.18 + 0.2 * pulse))
		elif kb == "butcher" and e.st == 2:
			var dx: float = e.lx - e.x
			var dy: float = e.ly - e.y
			var l := maxf(0.001, Vector2(dx, dy).length())
			var nx := -dy / l * 0.45
			var ny := dx / l * 0.45
			var P := PackedVector2Array([iso(e.x + nx, e.y + ny), iso(e.lx + nx, e.ly + ny), iso(e.lx - nx, e.ly - ny), iso(e.x - nx, e.y - ny)])
			draw_colored_polygon(P, Color(1, 50 / 255.0, 40 / 255.0, 0.16 + 0.22 * pulse))
			P.append(P[0])
			draw_polyline(P, Color(1, 80 / 255.0, 60 / 255.0, 0.6 + 0.3 * pulse), 1.6 * u)
		elif kb == "storm" and e.boss == "tempest" and e.st == 1:
			var a := atan2(e.ly - e.y, e.lx - e.x)
			for sgn in [-1.0, 1.0]:
				var ox: float = -sin(a) * Sim.TWIN_GAP * sgn
				var oy: float = cos(a) * Sim.TWIN_GAP * sgn
				var q := iso(clampf(e.x + ox + cos(a) * 12, 0, sim.N), clampf(e.y + oy + sin(a) * 12, 0, sim.N))
				var p0 := iso(e.x + ox, e.y + oy)
				var col := Color(191 / 255.0, 244 / 255.0, 1, (0.75 + 0.25 * pulse) if f < 0.36 else (0.35 + 0.3 * pulse))
				draw_dashed_line(p0 - Vector2(0, ch), q - Vector2(0, ch), col, 1.6 * u, 6 * u)
		elif kb == "storm":
			var dx: float = e.lx - e.x
			var dy: float = e.ly - e.y
			var l := maxf(0.001, Vector2(dx, dy).length())
			var q := iso(clampf(e.x + dx / l * 12, 0, sim.N), clampf(e.y + dy / l * 12, 0, sim.N))
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
		var B: Dictionary = Sim.boss_def(e.boss)
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


func _ring(x: float, y: float, r: float, col: Color, w: float = 2.0) -> void:
	var q := iso(x, y)
	draw_set_transform(q, 0, Vector2(1, 0.5))
	draw_arc(Vector2.ZERO, v.TW2 * r, 0, TAU, 44, col, w * v.u)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _disc(x: float, y: float, r: float, col: Color) -> void:
	var q := iso(x, y)
	oval(q.x, q.y, v.TW2 * r, v.TH2 * r, col)


func _lane(x0: float, y0: float, x1: float, y1: float, w: float, fill: Color, line: Color) -> void:
	var dx := x1 - x0
	var dy := y1 - y0
	var l := maxf(0.001, Vector2(dx, dy).length())
	var nx := -dy / l * w
	var ny := dx / l * w
	var P := PackedVector2Array([iso(x0 + nx, y0 + ny), iso(x1 + nx, y1 + ny), iso(x1 - nx, y1 - ny), iso(x0 - nx, y0 - ny)])
	draw_colored_polygon(P, fill)
	P.append(P[0])
	draw_polyline(P, line, 1.6 * v.u)


func _wedge(e: Dictionary, range_: float, half: float, fill: Color) -> void:
	var a0 := atan2(e.ly - e.y, e.lx - e.x)
	var pts := PackedVector2Array([iso(e.x, e.y)])
	for n in 11:
		var a := a0 + (n / 10.0 - 0.5) * half * 2
		pts.append(iso(e.x + cos(a) * range_, e.y + sin(a) * range_))
	draw_colored_polygon(pts, fill)


## the warnings for the moves (drawBossMove), the Blitz variants, the Foreman, winter and the Destroyer
func _draw_new_fx(e: Dictionary, f: float, pulse: float, ch: float) -> bool:
	var st: int = e.st
	var M: Dictionary = Sim.MOVE
	var D: Dictionary = Sim.DEST
	match st:
		20:
			for p in Sim.strike_pts(e.x, e.y, e.lx, e.ly):
				_disc(p.x, p.y, M.strike.r, Color(127 / 255.0, 224 / 255.0, 1, 0.12 + 0.18 * pulse))
				_ring(p.x, p.y, M.strike.r * (1.3 - 0.3 * (1 - f)), Color(200 / 255.0, 245 / 255.0, 1, 0.6 + 0.35 * pulse))
		21:
			_disc(e.x, e.y, M.pulse.r * (1 - f), Color(127 / 255.0, 224 / 255.0, 1, 0.12 + 0.12 * pulse))
			_ring(e.x, e.y, M.pulse.r, Color(127 / 255.0, 224 / 255.0, 1, 0.55 + 0.4 * pulse), 2.2)
		22:
			_lane(e.x, e.y, e.lx, e.ly, M.cyclone.r, Color(191 / 255.0, 244 / 255.0, 1, 0.12 + 0.16 * pulse), Color(191 / 255.0, 244 / 255.0, 1, 0.55 + 0.35 * pulse))
		23:
			var cp := Sim.cyclone_pos(e, f)
			var q := iso(cp.x, cp.y)
			for n in 4:
				var r: float = (0.35 + n * 0.18) * M.cyclone.r
				var a: float = sim.game.time * 8 + n
				draw_set_transform(Vector2(q.x, q.y - n * 6 * v.u), 0, Vector2(1, 0.5))
				draw_arc(Vector2.ZERO, v.TW2 * r, a, a + 4.2, 20, Color(220 / 255.0, 248 / 255.0, 1, 0.75), 1.6 * v.u)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		24:
			_disc(e.lx, e.ly, M.cage.r, Color(191 / 255.0, 244 / 255.0, 1, 0.08 + 0.14 * (1 - f)))
			var gap := atan2(e.ly - e.y, e.lx - e.x)
			for n in 14:
				var a := n * TAU / 14
				var da := fmod(absf(a - gap), TAU)
				if da > PI:
					da = TAU - da
				if da < 0.4:
					continue
				var bar := iso(e.lx + cos(a) * M.cage.r, e.ly + sin(a) * M.cage.r)
				draw_line(bar, bar - Vector2(0, ch * (1.2 - f * 0.6)), Color(230 / 255.0, 250 / 255.0, 1, 0.6 + 0.35 * pulse), 2 * v.u)
		25:
			_wedge(e, M.flame.range, M.flame.half, Color(1, 140 / 255.0, 40 / 255.0, 0.16 + 0.2 * pulse))
		26:
			_wedge(e, M.flame.range * (0.85 + 0.15 * sin(sim.game.time * 30)), M.flame.half, Color(1, (120 + 60 * pulse) / 255.0, 40 / 255.0, 0.42))
		27:
			_ring(e.lx, e.ly, M.firering.r, Color(1, 110 / 255.0, 40 / 255.0, 0.5 + 0.4 * pulse), 2.2)
			for n in M.firering.n:
				var a: float = n * TAU / M.firering.n
				_ring(e.lx + cos(a) * M.firering.r, e.ly + sin(a) * M.firering.r, 0.7 * (1.2 - 0.2 * (1 - f)), Color(1, 150 / 255.0, 60 / 255.0, 0.45 + 0.4 * pulse), 1.4)
		28:
			_disc(e.x, e.y, M.slam.r, Color(1, 210 / 255.0, 58 / 255.0, 0.1 + 0.16 * pulse))
			_ring(e.x, e.y, M.slam.r * (1.15 - 0.15 * (1 - f)), Color(1, 210 / 255.0, 58 / 255.0, 0.6 + 0.35 * pulse), 2.4)
		29:
			var P: Array = sim.overdrive_pts(e.x, e.y, e.lx, e.ly)
			var shown := mini(3, floori((1 - f) * 3) + 1)
			var x0: float = e.x
			var y0: float = e.y
			for n in shown:
				_lane(x0, y0, P[n].x, P[n].y, 0.45, Color(1, 210 / 255.0, 58 / 255.0, 0.14 + 0.2 * pulse), Color(1, 220 / 255.0, 90 / 255.0, 0.6 + 0.3 * pulse))
				x0 = P[n].x
				y0 = P[n].y
		30:
			pass
		5:   # the Blue Butcher's arc lane
			_lane(e.x, e.y, e.lx, e.ly, 0.5, Color(58 / 255.0, 224 / 255.0, 224 / 255.0, 0.16 + 0.22 * pulse), Color(58 / 255.0, 224 / 255.0, 224 / 255.0, 0.6 + 0.3 * pulse))
		101:   # ice rupture
			var r := 3.4 if e.boss == "rime" else 2.3
			_disc(e.lx, e.ly, r, Color(120 / 255.0, 1, 220 / 255.0, 0.2 + 0.1 * pulse))
			_ring(e.lx, e.ly, r, c("#d2fff0"), 1.4)
			var lq := iso(e.lx, e.ly)
			label("ICE RUPTURE", lq.x, lq.y - v.WH, c("#d8fff3"), 12)
		102:
			draw_dashed_line(iso(e.x, e.y), iso(e.lx, e.ly), c("#d5fff0"), 5 * v.u, 6 * v.u)
		40:
			for p in sim.rocket_pts(e.x, e.y, e.lx, e.ly):
				_disc(p.x, p.y, D.rockets.R * 0.8, Color(1, 60 / 255.0, 40 / 255.0, 0.1 + 0.15 * pulse))
				_ring(p.x, p.y, D.rockets.R * (1.2 - 0.2 * (1 - f)), Color(1, 70 / 255.0, 50 / 255.0, 0.6 + 0.35 * pulse))
		41, 42:
			var fe: Vector2 = sim.fire_end(e)
			_lane(e.x, e.y, fe.x, fe.y, D.fire.w, Color(1, 120 / 255.0, 40 / 255.0, (0.16 + 0.22 * pulse) if st == 41 else 0.35), Color(1, 150 / 255.0, 60 / 255.0, 0.6 + 0.3 * pulse))
		43:
			var dx: float = e.lx - e.x
			var dy: float = e.ly - e.y
			var l := maxf(0.001, Vector2(dx, dy).length())
			var q := iso(clampf(e.x + dx / l * 12, 0, sim.N), clampf(e.y + dy / l * 12, 0, sim.N))
			draw_line(iso(e.x, e.y) - Vector2(0, ch), q - Vector2(0, ch), Color(127 / 255.0, 224 / 255.0, 1, (0.8 if f < 0.32 else 0.4 + 0.3 * pulse)), (2.6 if f < 0.32 else 1.4) * v.u)
		44:
			_disc(e.x, e.y, D.gas.r * (1 - f), Color(120 / 255.0, 200 / 255.0, 70 / 255.0, 0.14 + 0.1 * pulse))
			_ring(e.x, e.y, D.gas.r, Color(160 / 255.0, 240 / 255.0, 90 / 255.0, 0.55 + 0.35 * pulse), 2.2)
		45:
			_disc(e.lx, e.ly, D.mines.r, Color(1, 176 / 255.0, 58 / 255.0, 0.1 + 0.14 * pulse))
			_ring(e.lx, e.ly, D.mines.r, Color(1, 176 / 255.0, 58 / 255.0, 0.6 + 0.3 * pulse))
		46, 47:
			var col := Color(1, 106 / 255.0, 42 / 255.0, (0.85 + 0.15 * pulse) if st == 47 else (0.45 + 0.35 * pulse))
			_ring(e.lx, e.ly, D.orb.r, col, 2.6 if st == 47 else 1.8)
			_disc(e.lx, e.ly, D.orb.r * (1 - f if st == 47 else 0.3), Color(1, 106 / 255.0, 42 / 255.0, 0.18))
		_:
			var kb: String = Sim.boss_def(e.boss).get("base", e.boss)
			if e.boss == "arsonist" and st == 1:
				draw_dashed_line(iso(e.x, e.y) - Vector2(0, ch), iso(e.lx, e.ly) - Vector2(0, ch), Color(1, 90 / 255.0, 26 / 255.0, 0.5 + 0.45 * pulse), 2 * v.u, 7 * v.u)
				for n in 4:
					var t := 0.5 + n * 0.18
					_ring(e.x + (e.lx - e.x) * t, e.y + (e.ly - e.y) * t, 1.0, Color(1, 90 / 255.0, 26 / 255.0, 0.55 + 0.35 * pulse), 1.6)
				return true
			if e.boss == "harbinger" and st == 1:
				_ring(e.lx, e.ly, 2.0, Color(1, 122 / 255.0, 58 / 255.0, 0.45 + 0.35 * pulse), 1.6)
				return true
			if (e.boss == "bulldozer" or e.boss == "whiteforeman") and st == 1:
				_lane(e.x, e.y, e.lx, e.ly, 0.5, Color(1, 210 / 255.0, 58 / 255.0, 0.16 + 0.22 * pulse), Color(1, 210 / 255.0, 58 / 255.0, 0.6 + 0.3 * pulse))
				return true
			if kb == "foreman" and e.boss == "foreman":
				if st == 1:
					_ring(e.lx, e.ly, 0.95 * (1.2 - f * 0.2), Color(1, 177 / 255.0, 58 / 255.0, 0.55 + 0.4 * pulse))
				elif st == 3:
					_lane(e.x, e.y, e.lx, e.ly, 0.5, Color(1, 150 / 255.0, 40 / 255.0, 0.16 + 0.22 * pulse), Color(1, 177 / 255.0, 58 / 255.0, 0.6 + 0.3 * pulse))
				elif st == 4:
					_ring(e.x, e.y, 1.4, Color(1, 70 / 255.0, 40 / 255.0, 0.6 + 0.4 * pulse), 2.4)
				return true
			return false
	return true


## the Foreman underground: a moving dust mound
func _draw_mound(e: Dictionary) -> void:
	var q := iso(e.x, e.y)
	var sw := (1.35 + sin(sim.game.time * 40) * 0.08) if e.st == 4 else 1.0
	oval(q.x, q.y, 14 * v.u * sw, 6 * v.u * sw, c("#4a4030"))
	oval(q.x, q.y - 3 * v.u, 10 * v.u * sw, 4.5 * v.u * sw, c("#6a5a44"))
	label(Sim.boss_def(e.boss).name, q.x, q.y - 22 * v.u, c(Sim.boss_def(e.boss).col), 11)


var dev_boss_i := 0


## developer only (F8 in editor/debug runs): the next boss in Sim.BOSS_LIST walks in now
func _dev_boss() -> void:
	var k: String = Sim.BOSS_LIST[dev_boss_i % Sim.BOSS_LIST.size()]
	dev_boss_i += 1
	if sim.game.phase == "build":
		sim.start_raid()
		sim.game.queue = []
	sim.spawn_boss(k)


# ---------------------------------------------------------------- skill tree (19b-social-lobby.js)

func _skills_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode in [KEY_ESCAPE, KEY_K, KEY_P]:
			skills_open = false
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for b in sk_buttons:
			if b[0].has_point(e.position):
				audio.play("restock" if profile.buy(b[1]) else "deny")
				return
		if sk_reset.has_point(e.position):
			profile.respec()
			audio.play("restock")


func _draw_skills() -> void:
	sk_buttons.clear()
	var gold := c("#e2b436")
	var paper := c("#e8dcc0")
	var dim := c("#9a8f7a")
	draw_rect(Rect2(0, 0, v.W, v.H), Color(0, 0, 0, 0.6))
	var w := minf(760.0, v.W - 24)
	var rh := 25.0
	var rows: Array = PalProfile.SKILLS
	var h := 84.0 + rows.size() * rh + 40
	var x0 := (v.W - w) / 2
	var y0 := maxf(6.0, (v.H - h) / 2)
	draw_rect(Rect2(x0, y0, w, h), c("#16130f"))
	draw_rect(Rect2(x0, y0, w, h), Color(gold, 0.5), false, 1.5)
	draw_string(font, Vector2(x0 + 16, y0 + 24), "SKILL TREE · CHANGES APPLY FROM YOUR NEXT GAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, dim)
	draw_string(font, Vector2(x0 + 16, y0 + 50), "%d SP TO SPEND · %d EARNED IN ALL · NEXT POINT IN %d RAIDS HELD (OR A BOSS)" % [profile.sp, profile.sp_total, 5 - profile.sp_prog], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gold)
	var y := y0 + 66
	var br_last := ""
	for S in rows:
		if S.br != br_last:
			br_last = S.br
			draw_line(Vector2(x0 + 10, y + 1), Vector2(x0 + w - 10, y + 1), Color(dim, 0.25), 1.0)
		var lv := profile.level(S.id)
		var off: bool = S.has("cls") and S.cls != "soldier"
		var col := Color(paper, 0.45) if off else paper
		draw_string(font, Vector2(x0 + 16, y + 17), S.br, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, dim)
		draw_string(font, Vector2(x0 + 112, y + 17), S.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		for k in S.max:
			draw_rect(Rect2(x0 + 268 + k * 10, y + 9, 7, 7), gold if k < lv else Color(dim, 0.35))
		var what: String = S.what + ("  (other class)" if off else "")
		draw_string(font, Vector2(x0 + 312, y + 17), what, HORIZONTAL_ALIGNMENT_LEFT, w - 430, 10, dim)
		var reason := profile.block_reason(S.id)
		var label_txt: String = ("%d SP" % S.cost[lv]) if reason == "" else ("LOCKED" if reason.begins_with("Needs") else reason)
		var b := Rect2(x0 + w - 106, y + 2, 92, 20)
		draw_rect(b, Color(gold, 0.12) if reason == "" else Color(0.2, 0.2, 0.2, 0.4))
		draw_rect(b, Color(gold, 0.8) if reason == "" else Color(dim, 0.4), false, 1.0)
		var lw := font.get_string_size(label_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(font, Vector2(b.position.x + (b.size.x - lw) / 2, y + 16), label_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, gold if reason == "" else dim)
		sk_buttons.append([b, S.id])
		y += rh
	sk_reset = Rect2(x0 + 16, y + 8, 150, 24)
	draw_rect(sk_reset, Color(paper, 0.08))
	draw_rect(sk_reset, Color(paper, 0.5), false, 1.0)
	draw_string(font, Vector2(sk_reset.position.x + 14, y + 25), "RESET ALL POINTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, paper)
	draw_string(font, Vector2(x0 + w - 220, y + 25), "K / Esc closes", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, dim)


# ---------------------------------------------------------------- terrain (06b-maps.js, 06d-elevation.js)

## groundCol: each map's ground, water and banks
func _ground_col(i: int, j: int, h: float) -> Color:
	var t: int = sim.terr[sim.idx(i, j)]
	if t == PalMaps.T_WATER or t == PalMaps.T_BRIDGE:
		return c("#1d3848") if h < 0.33 else (c("#1f3b4c") if h < 0.66 else c("#1b3544"))
	match sim.map_id:
		"river":
			if t == PalMaps.T_LOW:
				return c("#343423") if h < 0.5 else c("#2f3021")
			return c("#35402a") if h < 0.2 else (c("#303a26") if h < 0.75 else c("#2b3322"))
		"quarry":
			return c("#3b3731") if h < 0.2 else (c("#35312c") if h < 0.75 else c("#2f2b27"))
	return c("#3d3528") if h < 0.2 else (c("#352e23") if h < 0.75 else c("#2f291f"))


func _paint_ground() -> void:
	var N: int = sim.N
	var u := v.u
	if sim.is_frost():
		for j in N:
			for i in N:
				_paint_frost_tile(i, j)
		return
	for i in N:
		for j in N:
			var h := Pal.hash2(i, j)
			quad(v.iso(i, j), v.iso(i + 1, j), v.iso(i + 1, j + 1), v.iso(i, j + 1), _ground_col(i, j, h))
			var t: int = sim.terr[sim.idx(i, j)]
			if t == PalMaps.T_WATER or t == PalMaps.T_BRIDGE:   # a soft bank line where water meets land
				for e in [[1, 0, [i + 1, j], [i + 1, j + 1]], [-1, 0, [i, j], [i, j + 1]], [0, 1, [i, j + 1], [i + 1, j + 1]], [0, -1, [i, j], [i + 1, j]]]:
					var nt := sim.t_at(i + e[0], j + e[1])
					if sim.inb(i + e[0], j + e[1]) and nt != PalMaps.T_WATER and nt != PalMaps.T_BRIDGE:
						draw_line(v.iso(e[2][0], e[2][1]), v.iso(e[3][0], e[3][1]), Color(120 / 255.0, 150 / 255.0, 120 / 255.0, 0.25), 1.2 * u)
				continue
			if t == PalMaps.T_CRACK:
				var pts := PackedVector2Array()
				var p := Vector2(i + 0.2 + Pal.hash2(i, j + 3) * 0.2, j + 0.25 + Pal.hash2(i + 9, j) * 0.2)
				pts.append(v.iso(p.x, p.y))
				for s in 4:
					p += Vector2(0.14 + Pal.hash2(i + s, j * 3) * 0.1, 0.1 + Pal.hash2(i * 7, j + s) * 0.12)
					pts.append(v.iso(p.x, p.y))
				draw_polyline(pts, Color(14 / 255.0, 11 / 255.0, 9 / 255.0, 0.7), 1.1 * u)
				draw_line(v.iso(i + 0.5, j + 0.5), v.iso(i + 0.3, j + 0.8), Color(14 / 255.0, 11 / 255.0, 9 / 255.0, 0.7), 1.1 * u)
				draw_polyline(pts, Color(1, 140 / 255.0, 60 / 255.0, 0.12), 0.8 * u)
				continue
			if sim.map_id == "quarry":
				if h > 0.8:
					var g := v.iso(i + 0.3 + h * 0.4, j + 0.5)
					oval(g.x, g.y, 2.4 * u, 1.2 * u, Color(150 / 255.0, 140 / 255.0, 120 / 255.0, 0.3))
			elif h > 0.86:
				var cc := v.iso(i + 0.5, j + 0.5)
				oval(cc.x + (h - 0.9) * 40 * u, cc.y, 6 * u, 2.5 * u, Color(84 / 255.0, 104 / 255.0, 64 / 255.0, 0.35))
	for s in N + 1:
		draw_line(v.iso(s, 0), v.iso(s, N), Color(0, 0, 0, 0.22), 1.0)
		draw_line(v.iso(0, s), v.iso(N, s), Color(0, 0, 0, 0.22), 1.0)


## paintFrostTile: a terrace top (snow), its south and east faces where it drops, and the treads of stairs and ramps
func _paint_frost_tile(i: int, j: int) -> void:
	var N: int = sim.N
	var u := v.u
	var k := sim.idx(i, j)
	var z: int = sim.heights[k]
	var r: int = sim.connectors[k]
	var h := Pal.hash2(i + 6, j + 31)
	var A := v.iso(i, j, z + (1 if r else 0))
	var B := v.iso(i + 1, j, z + (1 if r else 0))
	var C := v.iso(i + 1, j + 1, z)
	var D := v.iso(i, j + 1, z)
	var lowS: int = (sim.heights[k + N] + (1 if sim.connectors[k + N] != 0 else 0)) if j + 1 < N else 0
	var lowE: int = sim.heights[k + 1] if i + 1 < N else 0
	if z > lowS:
		quad(D, C, v.iso(i + 1, j + 1, lowS), v.iso(i, j + 1, lowS), c("#435b6a"))
	if z > lowE:
		quad(B, C, v.iso(i + 1, j + 1, lowE), v.iso(i + 1, j, lowE), c("#304858"))
	quad(A, B, C, D, c("#acc9d8") if r else (c("#dceaf0") if h > 0.55 else c("#c8dee8")))
	draw_line(D, C, Color(68 / 255.0, 109 / 255.0, 134 / 255.0, 0.2), u)
	if r:
		var n := 5 if r == 2 else 2
		for q in range(1, n + 1):
			var t := float(q) / (n + 1)
			draw_line(v.iso(i, j + t, z + 1 - t), v.iso(i + 1, j + t, z + 1 - t), c("#547b90") if r == 2 else c("#e7f5fa"), (2.0 if r == 2 else 1.0) * u)
	elif h > 0.83:
		var p := v.iso(i + 0.5, j + 0.5, z)
		draw_rect(Rect2(p.x - 2 * u, p.y, 4 * u, u), Color(1, 1, 1, 0.55))


## a terrace's cliff face, depth-sorted so people behind the lip are hidden by it
func _draw_frost_cliff(k: int) -> void:
	var N: int = sim.N
	var u := v.u
	var i := k % N
	var j := k / N
	var z: int = sim.heights[k]
	var s: int = (sim.heights[k + N] + (1 if sim.connectors[k + N] != 0 else 0)) if j + 1 < N else 0
	var e: int = sim.heights[k + 1] if i + 1 < N else 0
	if z > s:
		quad(v.iso(i, j + 1, z), v.iso(i + 1, j + 1, z), v.iso(i + 1, j + 1, s), v.iso(i, j + 1, s), c("#435b6a"))
		draw_line(v.iso(i + 0.2, j + 1, z), v.iso(i + 0.35, j + 1, s), c("#719aaa"), u)
		draw_line(v.iso(i, j + 1, z) + Vector2(0, u), v.iso(i + 1, j + 1, z) + Vector2(0, u), c("#dcebf1"), 2 * u)
	if z > e:
		quad(v.iso(i + 1, j, z), v.iso(i + 1, j + 1, z), v.iso(i + 1, j + 1, e), v.iso(i + 1, j, e), c("#304858"))
		draw_line(v.iso(i + 1, j, z) + Vector2(0, u), v.iso(i + 1, j + 1, z) + Vector2(0, u), c("#b9d0da"), 2 * u)


## drawTerrainLive: water glints drifting downstream, flooded banks, bridges, pits, ripples round anyone wading
func _draw_terrain_live() -> void:
	var N: int = sim.N
	var u := v.u
	var t0: float = sim.game.time
	if sim.map_id == "river":
		for k in N * N:
			if sim.terr[k] != PalMaps.T_WATER:
				continue
			var i := k % N
			var j := k / N
			var h := Pal.hash2(i + 31, j + 7)
			var y := j + fmod(t0 * 0.35 + h, 1.0)
			draw_line(v.iso(i + 0.25 + h * 0.4, y), v.iso(i + 0.45 + h * 0.4, y), Color(150 / 255.0, 200 / 255.0, 220 / 255.0, 0.28), 1.2 * u)
		flood_lv += ((1.0 if sim.flood_on else 0.0) - flood_lv) * minf(1.0, get_process_delta_time() * 1.2)
		if flood_lv > 0.02:
			for k in N * N:
				if sim.terr[k] == PalMaps.T_LOW:
					var i := k % N
					var j := k / N
					quad(v.iso(i, j), v.iso(i + 1, j), v.iso(i + 1, j + 1), v.iso(i, j + 1), Color(c("#23475a"), flood_lv * 0.7))
		for k in N * N:
			if sim.terr[k] == PalMaps.T_BRIDGE:
				var i := k % N
				var j := k / N
				quad(v.iso(i, j + 0.08), v.iso(i + 1, j + 0.08), v.iso(i + 1, j + 0.92), v.iso(i, j + 0.92), c("#5a4330"))
				for s in range(1, 6):
					draw_line(v.iso(i + s / 6.0, j + 0.08), v.iso(i + s / 6.0, j + 0.92), Color(20 / 255.0, 14 / 255.0, 8 / 255.0, 0.6), u)
				for yy in [j + 0.08, j + 0.92]:
					draw_line(v.iso(i, yy) - Vector2(0, 3 * u), v.iso(i + 1, yy) - Vector2(0, 3 * u), c("#2c2016"), 2 * u)
	for k in sim.terr_log:
		if sim.terr[k] == PalMaps.T_PIT:
			var i: int = k % N
			var j: int = k / N
			var a := v.iso(i + 0.04, j + 0.04)
			var b := v.iso(i + 0.96, j + 0.04)
			var d := v.iso(i + 0.04, j + 0.96)
			quad(a, b, v.iso(i + 0.96, j + 0.96), d, c("#0b0908"))
			quad(a, b, b + Vector2(0, v.WH * 0.35), a + Vector2(0, v.WH * 0.35), c("#1c1713"))
			quad(a, d, d + Vector2(0, v.WH * 0.35), a + Vector2(0, v.WH * 0.35), c("#241d18"))
	if sim.map_id == "river":
		var wading: Array = sim.enemies.filter(func(e): return not e.get("burrow", false))
		if sim.player.alive:
			wading.append(sim.player)
		if sim.qm.alive:
			wading.append(sim.qm)
		for e in wading:
			var tt := sim.t_at(floori(e.x), floori(e.y))
			if tt == PalMaps.T_WATER or (tt == PalMaps.T_LOW and sim.flood_on):
				var cc := iso(e.x, e.y)
				var r := (7 + sin(t0 * 6 + e.x * 3) * 1.5) * u
				draw_set_transform(cc, 0, Vector2(1, 0.5))
				draw_arc(Vector2.ZERO, r, 0, TAU, 24, Color(170 / 255.0, 210 / 255.0, 230 / 255.0, 0.45), u)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


## rock outcrops and oil drums (terrShape): rock stands, a drum burns
func _draw_terr_item(i: int, j: int, t: int) -> void:
	var u := v.u
	var WH := v.WH
	var h := Pal.hash2(i + 3, j + 17)
	if t == PalMaps.T_ROCK:
		box_r(i + 0.08, j + 0.12, i + 0.9, j + 0.88, 0, WH * (0.75 + h * 0.3), c("#6b655b"), c("#4e4a43"), c("#3c3934"))
		box_r(i + 0.2 + h * 0.2, j + 0.2, i + 0.7 + h * 0.2, j + 0.62, WH * (0.75 + h * 0.3), WH * (0.25 + h * 0.2), c("#787166"), c("#58534b"), c("#45413b"))
		return
	var cc := iso(i + 0.5, j + 0.5)
	var w := v.TW2 * 0.34
	var hh := WH * 0.9
	oval(cc.x, cc.y, w * 1.2, w * 0.6, Color(0, 0, 0, 0.35))
	draw_rect(Rect2(cc.x - w, cc.y - hh, w * 2, hh), c("#3b2f24"))
	draw_rect(Rect2(cc.x - w * 0.35, cc.y - hh, w * 0.7, hh), c("#4d3d2e"))
	draw_rect(Rect2(cc.x - w, cc.y - hh * 0.66, w * 2, 2 * u), c("#2a211a"))
	draw_rect(Rect2(cc.x - w, cc.y - hh * 0.33, w * 2, 2 * u), c("#2a211a"))
	oval(cc.x, cc.y - hh, w, w * 0.45, c("#1a1411"))
	var t0: float = sim.game.time * 9 + h * 20
	for q in 3:   # the flame on top: three flickering tongues
		var fx := cc.x + (q - 1) * w * 0.45
		var fh := (9 + sin(t0 + q * 2.1) * 3 + (q % 2) * 2) * u
		draw_colored_polygon(PackedVector2Array([Vector2(fx - w * 0.28, cc.y - hh), Vector2(fx + sin(t0 * 1.3 + q) * 2 * u, cc.y - hh - fh * 1.2), Vector2(fx + w * 0.28, cc.y - hh)]), c("#ffd070") if q == 1 else c("#ff8a2a"))


## the Ferryman's raft under him
func _draw_raft(e: Dictionary) -> void:
	var u := v.u
	var cc := iso(e.x, e.y)
	var bob := sin(sim.game.time * 2.2 + e.id) * 1.5 * u
	draw_set_transform(Vector2(cc.x, cc.y + bob), 0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 20 * u, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	box_r(e.x - 0.55, e.y - 0.45, e.x + 0.55, e.y + 0.45, -2 * u + bob, 4 * u, c("#6a4c30"), c("#4f3822"), c("#3e2c1a"))
	for s in range(1, 4):
		draw_line(iso(e.x - 0.55 + s * 0.275, e.y - 0.45) - Vector2(0, 2 * u - bob), iso(e.x - 0.55 + s * 0.275, e.y + 0.45) - Vector2(0, 2 * u - bob), c("#2c2016"), u)


var flood_lv := 0.0


## screenToWorld: the viewing ray against each terrace's plane and the connector slopes; the front-most ground wins
func _screen_to_world(sx: float, sy: float) -> Vector2:
	var a := (sx - v.cam_x) / v.TW2
	var best = null
	var hp := v.height_px()
	for z in 3:
		var b := (sy - v.cam_y + z * hp) / v.TH2
		var x := (a + b) / 2
		var y := (b - a) / 2
		if absf(sim.height_at(x, y) - z) < 0.00001 and sim.inb(floori(x), floori(y)) and (best == null or x + y > best.x + best.y):
			best = Vector2(x, y)
	if sim.is_frost():
		var N: int = sim.N
		for k in N * N:
			if sim.connectors[k] != 0:
				var j := k / N
				var y := (sy - v.cam_y - a * v.TH2 + hp * (sim.heights[k] + 1 + j)) / (2 * v.TH2 + hp)
				var x := y + a
				if floori(x) == k % N and floori(y) == j and (best == null or x + y > best.x + best.y):
					best = Vector2(x, y)
	if best != null:
		return best
	return v.screen_to_world(sx, sy)


## bodyUnder: a cursor on a drawn raider (feet to helmet) aims at that raider's feet
func _body_under(sx: float, sy: float):
	var best = null
	var by := -1e9
	for e in sim.enemies:
		if e.dead or e.get("burrow", false):
			continue
		var p := iso(e.x, e.y)
		var k := v.u * FIG * (1.45 if e.get("big", false) else 1.0)
		if absf(sx - p.x) <= 9 * k and sy <= p.y + 4 * k and sy >= p.y - 37 * k and p.y > by:
			by = p.y
			best = Vector2(e.x, e.y)
	return best
