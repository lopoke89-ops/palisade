class_name Hud
extends Control
## The in-game HUD, built as the browser builds it (page.html #top, #tip; style.css; hud() in 11-hud-chat.js), not
## painted: the phase box at the top right (the phase, its clock, the core or stake meters, Delgado's button, salvage,
## START, the Free-for-all board, pause and chat) and the tip under it. Sizes are the browser's desktop CSS pixels
## (body.desk), one CSS pixel to a screen pixel up to 1600x900 and scaled up past it, as a browser on a bigger screen.
## The world-anchored parts (nameplates, prompts, the crosshair, floating text) stay painted in main.gd.

const INK := Color("#17140f")
const BONE := Color("#dcd2ba")
const DIM := Color("#9a8f7a")
const WARN := Color("#e2b436")
const RUST := Color("#b0512f")
const LINE := Color("#3a3228")
const EVAC := Color("#8aff9a")
const BTNBG := Color(27 / 255.0, 24 / 255.0, 20 / 255.0, 0.8)
const QMBG := Color("#6b6b6b")   # Delgado's button keeps the browser's own button look (no style of its own)
const TOAST_PHASE := "RAID|BROKEN|UNDER ATTACK|HELD|LOST|NEXT ·|FIRST TARGET|FINAL|READY UP|BLITZ|EVAC|DESTROYER|POWER IS OUT|IS DOWN|CHAPTER|GAUNTLET|BOSS|BATTLE|TRUCE|LEFT BEHIND|CLAIM"

var m   # main.gd
var s := 1.0   # screen pixels per CSS pixel
var box := Rect2()   # the phase box (#top .phase), in screen pixels
var tip := ""
var tip_stage := 0   # the browser's game.tip: 0 at the start, 1 after gathering, 2 after building, 9 in PvP
var note := ""   # #phaseNote: the last phase message's title
var chat_seen := 0

var lab: Label
var val: Label
var note_l: Label
var salv: Label
var core_m: Meter
var core2_m: Meter
var qm_b: Button
var skip_b: Button
var skip_l: Label
var skip_kc: Label
var pause_b: Button
var chat_b: Button
var board: VBoxContainer
var tip_p: PanelContainer
var tip_l: Label
var _rx := RegEx.new()
var _fonts := {}
var _ls := {}
var _sig := ""


## a CORE / STAKE / COMMAND / ENEMY meter (.meter.coreBar): the label, the track and the number
class Meter extends Control:
	var h: Hud
	var lab: Label
	var num: Label
	var frac := 1.0
	var fill := Hud.WARN
	var alarm := false

	func _init(hud: Hud) -> void:
		h = hud
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab = h.label("s8", 16, Hud.DIM, 0.08)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT   # the phase box is text-align: right
		num = h.label("m6", 13, Hud.DIM)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(lab)
		add_child(num)

	func layout() -> void:
		var s := h.s
		size = Vector2(234, 19) * s
		lab.position = Vector2.ZERO
		lab.size = Vector2(66, 19) * s
		num.position = Vector2(190 * s, 1 * s)
		num.size = Vector2(44, 17) * s
		queue_redraw()

	func _draw() -> void:
		var s := h.s
		var r := Rect2(72 * s, 5 * s, 112 * s, 9 * s)
		draw_rect(r, Color("#0c0b09"))
		var bw := maxf(1.0, roundf(s))
		var c := Hud.RUST if alarm else fill
		draw_rect(Rect2(r.position + Vector2(bw, bw), Vector2((r.size.x - 2 * bw) * clampf(frac, 0, 1), r.size.y - 2 * bw)), c)
		draw_rect(r.grow(-bw / 2), Hud.RUST if alarm else Hud.LINE, false, bw)


func _init(main) -> void:
	m = main
	_rx.compile(TOAST_PHASE)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab = label("s9", 32, BONE, 0.06, 1.0)   # #phaseLab: line-height 1
	val = label("m4", 14, DIM)
	note_l = label("m4", 11, DIM)
	note_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	salv = label("m4", 14, WARN, 0.04)
	core_m = Meter.new(self)
	core2_m = Meter.new(self)
	core2_m.lab.text = "ENEMY"
	qm_b = _button(func(): m.do_action("delgado"))
	qm_b.text = "DELGADO · FOLLOW"
	skip_b = _button(func(): m.do_action("start"))
	skip_l = label("s8", 16, WARN, 0.1)
	skip_kc = label("m6", 10, INK)
	skip_kc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_kc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skip_b.add_child(skip_l)
	skip_b.add_child(skip_kc)
	pause_b = _button(func(): m.do_action("pause"))
	pause_b.text = "II"
	chat_b = _button(func(): m.toggle_chat())
	chat_b.draw.connect(_draw_chat_icon)
	board = VBoxContainer.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_p = PanelContainer.new()
	tip_p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_l = label("m4", 14, BONE)
	tip_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_p.add_child(tip_l)
	for c in [lab, val, note_l, salv, core_m, core2_m, qm_b, skip_b, pause_b, chat_b, board, tip_p]:
		add_child(c)
	_restyle()


# ---------------------------------------------------------------- fonts and boxes

## a face at a CSS size with letter-spacing (em) and, if given, a CSS line-height (em): the difference from the
## font's own line goes half above, half below
func font(f: String, size: float, em: float = 0.0, lh: float = 0.0) -> Font:
	var sp := roundi(em * size * s)
	var top := 0
	var bottom := 0
	if lh > 0:
		var d := roundi(lh * size * s - UiKit.face(f).get_height(maxi(6, roundi(size * s))))
		top = floori(d / 2.0)
		bottom = d - top
	var key := "%s|%d|%d|%d" % [f, sp, top, bottom]
	if not _fonts.has(key):
		var v := FontVariation.new()
		v.base_font = UiKit.face(f)
		v.spacing_glyph = sp
		v.spacing_top = top
		v.spacing_bottom = bottom
		_fonts[key] = v
	return _fonts[key]


func ls(f: String, size: float, col: Color, em: float = 0.0, shadow: bool = false, lh: float = 0.0) -> LabelSettings:
	var key := "%s|%s|%s|%s|%s|%s" % [f, size, col.to_html(), em, shadow, lh]
	if not _ls.has(key):
		var l := LabelSettings.new()
		l.font = font(f, size, em, lh)
		l.font_size = maxi(6, roundi(size * s))
		l.font_color = col
		l.line_spacing = 0.0
		if shadow:   # text-shadow: 0 1px 0 #000
			l.shadow_color = Color.BLACK
			l.shadow_offset = Vector2(0, maxf(1.0, roundf(s)))
			l.shadow_size = 0
		_ls[key] = l
	return _ls[key]


func label(f: String, size: float, col: Color, em: float = 0.0, lh: float = 0.0) -> Label:
	var l := Label.new()
	l.set_meta("st", [f, size, col, em, lh])
	l.label_settings = ls(f, size, col, em, false, lh)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## a label's look changed (colour), keeping its face and size
func recolor(l: Label, col: Color) -> void:
	var st: Array = l.get_meta("st")
	if st[2] != col:
		st[2] = col
		l.label_settings = ls(st[0], st[1], col, st[3], false, st[4])


func _sb(bg: Color, border: Color = Color(0, 0, 0, 0), bw: float = 0.0, radius: float = 0.0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(int(maxf(1.0, roundf(bw * s))) if bw > 0 else 0)
	b.set_corner_radius_all(roundi(radius * s))
	b.anti_aliasing = radius > 0
	return b


func _button(cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	return b


func _style_btn(b: Button, bg: Color, border: Color, bw: float, f: String, size: float, col: Color, em: float, radius: float = 0.0, hover: Color = Color(0, 0, 0, 0)) -> void:
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var c := hover if st in ["hover", "pressed"] and hover.a > 0 else bg
		b.add_theme_stylebox_override(st, _sb(c, border, bw, radius))
	b.add_theme_font_override("font", font(f, size, em))
	b.add_theme_font_size_override("font_size", maxi(6, roundi(size * s)))
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, col)


## (re)build every look for the current scale
func _restyle() -> void:
	_fonts.clear()
	_ls.clear()
	for l in [lab, val, note_l, salv, skip_l, skip_kc, tip_l, core_m.lab, core_m.num, core2_m.lab, core2_m.num]:
		var st: Array = l.get_meta("st")
		l.label_settings = ls(st[0], st[1], st[2], st[3], l == tip_l, st[4])
	_style_btn(pause_b, BTNBG, LINE, 1, "s9", 14, BONE, 0.1, 0, Color(BTNBG.lightened(0.15), 0.9))
	_style_btn(chat_b, BTNBG, WARN if chat_b.get_meta("new", false) else LINE, 1, "m4", 13, BONE, 0, 0, Color(BTNBG.lightened(0.15), 0.9))
	_style_btn(qm_b, QMBG, QMBG, 2, "m4", 10, BONE, 0, 4, QMBG.lightened(0.12))
	_style_btn(skip_b, Color(0, 0, 0, 0), WARN, 1, "s8", 16, WARN, 0.1, 0, Color(WARN, 0.12))
	var kc := _sb(WARN, Color(0, 0, 0, 0), 0, 2)
	skip_kc.add_theme_stylebox_override("normal", kc)
	var tb := _sb(Color(20 / 255.0, 18 / 255.0, 16 / 255.0, 0.78))
	tb.border_color = WARN
	tb.border_width_left = int(maxf(1.0, roundf(3 * s)))
	tb.content_margin_left = roundf(12 * s) + tb.border_width_left
	tb.content_margin_right = roundf(12 * s)
	tb.content_margin_top = roundf(7 * s)
	tb.content_margin_bottom = roundf(7 * s)
	tip_p.add_theme_stylebox_override("panel", tb)
	_sig = ""
	_board_rows([])


func _draw_chat_icon() -> void:
	# the speech bubble: M2 3h12v8H7l-3 3v-3H2z in a 16-unit box, 15 px across, stroked 1.6
	var k := 15.0 / 16.0 * s
	var o := (chat_b.size - Vector2(15, 15) * s) / 2
	var pts := PackedVector2Array()
	for q in [[2, 3], [14, 3], [14, 11], [7, 11], [4, 14], [4, 11], [2, 11], [2, 3]]:
		pts.append(o + Vector2(q[0], q[1]) * k)
	chat_b.draw_polyline(pts, WARN if chat_b.get_meta("new", false) else BONE, 1.6 * k, true)


# ---------------------------------------------------------------- state

## a new game: the browser's toastClear and the opening tip (newGame in 04-state-armory.js)
func reset() -> void:
	note = ""
	tip_stage = 0
	var sim: Sim = m.sim
	var pv := sim.pvp()
	if pv == "base":
		var me: Dictionary = Pal.TEAMS[sim.player.team]
		var them: Dictionary = Pal.TEAMS["b" if sim.player.team == "a" else "a"]
		tip_stage = 9
		set_tip("You're %s. Truce for %d seconds: gather and wall in your stake. Then knock down the %s stake. %s at your stake spends salvage." % [me.name, int(Pal.PVP.truce), them.name, _ctl("ARMORY", "E", _pad("armory"))])
	elif pv == "ffa":
		tip_stage = 9
		set_tip("Free-for-all. First to %d drops wins. The cover can't be broken." % int(Pal.PVP.ffaGoal))
	elif sim.campaign():
		set_tip("CHAPTER 1 · THE YARD. %s Three raids here, then your kit travels onward. Prepare at the core." % Sim.CAMPAIGN.story[0])
	elif sim.casino():
		set_tip("Walk up to a free seat or a machine and tap SIT or PLAY." if _touch() else "Walk up to a free seat or a machine and press E.")
	else:
		set_tip("Stand next to a wood pile to gather. Delgado is gathering too." if _touch() else "Walk next to a wood pile to gather. Delgado is gathering too.")


func set_tip(t: String) -> void:
	tip = t if m.settings.data.get("tips", true) else ""


## a message banner went up: phase messages (not the minor ones) stay as the line under the clock
func toasted(title: String) -> void:
	if _rx.search(title.to_upper()) != null:
		note = title


func _touch() -> bool:
	return m.inp.mode == "touch"


func _pad(id: String) -> String:
	return PalSettings.glyph(m.settings.data.pad.get(id, -1), m.inp.pad_kind)


## the browser's ctl(): the touch, keyboard or controller wording
func _ctl(touch: String, keys: String, pad: String) -> String:
	return pad if m.inp.mode == "pad" else (touch if _touch() else keys)


## the play buttons' key caps: the desktop's key, the controller's button, none on touch
func _kc(key: String, id: String) -> String:
	if _touch():
		return ""
	if m.inp.mode == "pad":
		var g := _pad(id)
		return "" if g == "—" else g
	return key


static func clock(t: float) -> String:
	var sec := maxi(0, ceili(t))
	return "%d:%02d" % [sec / 60, sec % 60]


# ---------------------------------------------------------------- every frame (hud() in 11-hud-chat.js)

func _process(_dt: float) -> void:
	visible = not m.demo
	if not visible:
		return
	position = Vector2.ZERO   # a Control under the game's Node2D: it takes the window's size itself
	size = get_viewport_rect().size
	var ns := maxf(1.0, minf(size.x / 1600.0, size.y / 900.0))
	if not is_equal_approx(ns, s):
		s = ns
		_restyle()
	var sim: Sim = m.sim
	var g: Dictionary = sim.game
	var p: Dictionary = sim.player
	var pv := sim.pvp()
	var host: bool = not m.net.guest()
	# the tips (12-players.js, 09-actions.js, 10-phases-bosses.js): gathered, built, then gone once the fighting starts
	if tip_stage == 0 and g.get("gathered", 0) >= 4:
		tip_stage = 1
		set_tip(_ctl("Face a tile and tap BUILD to raise a wall.", "Face a tile with the mouse and press Space to raise a wall.", "Aim at a tile and press %s to raise a wall." % _pad("build")))
	elif tip_stage == 1 and g.stats.built >= 3:
		tip_stage = 2
		set_tip("Ring the CORE. Make one tile a DOOR so your crew and Delgado can get in and out. Raiders treat doors like walls.")
	if tip != "" and ((g.phase == "raid" and pv != "ffa") or (pv == "ffa" and g.time > 9)):
		tip = ""
	var on := {"core": pv != "ffa" and not sim.casino(), "core2": pv == "base" and not sim.casino(), "salv": pv != "ffa" and not sim.casino(),
		"qm": pv == "" and not sim.qm.get("gone", false) and g.phase != "over" and host and not sim.casino(), "skip": false, "board": pv == "ffa", "chat": m.net.is_online() and m.net.in_game}
	var lt := ""
	var vt := ""
	var lc := BONE
	var skip := "START RAID"
	var W := size.x / s
	if sim.casino():
		lt = "CASINO" if W < 700 else "PALISADE FALLS CASINO"
		vt = ("ROOM %s · " % m.net.code if m.net.is_online() and m.net.code != "" else "") + "◆ %d" % (m.locker.shards if m.locker != null else 0) + (" · seated" if p.get("seat", 0) else "")
	elif pv == "base":
		var mine := 0
		var theirs := 0
		for o in sim.players.values():
			if o.team == p.team:
				mine += o.kills
			else:
				theirs += o.kills
		if g.phase == "build":
			lt = "TRUCE"
			vt = "%s until the battle" % clock(g.timer)
			on.skip = host
			skip = "START BATTLE"
		else:
			lt = "BATTLE"
			lc = RUST
			vt = "%s %d · %s %d drops" % [Pal.TEAMS[p.team].name, mine, Pal.TEAMS["b" if p.team == "a" else "a"].name, theirs]
	elif pv == "ffa":
		lt = "FFA" if W < 700 else "FREE-FOR-ALL"
		lc = RUST
		vt = "%s left · first to %d" % [clock(g.timer), g.goal]
	elif sim.blackout():
		var r := _bo_phase(sim, host)
		lt = r[0]
		vt = r[1]
		lc = r[2]
		on.skip = r[3]
		skip = r[4]
	elif g.phase == "build":
		lt = "CH %d · BUILD" % (g.chapter + 1) if sim.campaign() else "BUILD"
		vt = ("%s · %s · %s" % [clock(g.timer), sim.map_def.short, "final evacuation" if g.wave == 12 else "raid %d/3" % (g.wave % 3 + 1)]) if sim.campaign() else "%s until raid %d" % [clock(g.timer), g.wave + 1]
		on.skip = host
	elif g.get("fb") != null and not g.fb.done:
		var F: Dictionary = g.fb
		var ev: bool = F.evac != null
		lt = ("CH %d · EVAC" % (F.ch + 1)) if F.get("mapEvac", false) else ("EVACUATE" if ev else (("WAVE %d/6" if W < 700 else "GAUNTLET · WAVE %d/6") % F.wave if F.get("gauntlet", false) else ("BLITZ" if W < 700 else "FINAL BLITZ")))
		lc = EVAC if ev else RUST
		if ev:
			vt = "%s · you're out" % clock(F.t) if p.get("out", false) else "%s · get to the green ring" % clock(F.t)
		elif F.get("gauntlet", false):
			vt = "%s to the evac · %d up" % [clock(maxf(0, F.t - Sim.GAUNTLET.evac)), sim.live_bosses()]
		else:
			vt = "%s · boss %d/%d" % [clock(F.t), mini(F.n, F.max), F.max]
	else:
		lc = RUST
		if sim.campaign():
			lt = "CH %d · RAID %d/3" % [g.chapter + 1, (g.wave - 1) % 3 + 1]
		elif is_finite(float(g.waves)):
			lt = "RAID %d/%d" % [g.wave, g.waves]
		else:
			lt = "RAID %d" % g.wave
		vt = ("%s · " % sim.map_def.short if sim.campaign() else "") + "%d raiders left" % (sim.enemies.size() + (int(g.get("qn", 0)) if m.net.guest() else g.queue.size()))
	lab.text = lt
	recolor(lab, lc)
	val.text = vt
	note_l.text = note
	salv.text = "SALVAGE %d" % int(p.sal)
	skip_l.text = skip
	skip_kc.text = _kc("ENTER", "start")
	var c: Dictionary = sim.core
	if on.core:
		core_m.lab.text = "STAKE" if pv != "" else ("COMMAND" if sim.map_id == "city" else "CORE")
		core_m.frac = c.hp / c.max
		core_m.num.text = str(maxi(0, ceili(c.hp)))
		core_m.alarm = c.get("flash", 0.0) > 0 or c.hp / c.max < 0.3
		core_m.fill = Color(Pal.TEAMS.get(p.team, Pal.TEAMS.a).col) if pv != "" else WARN
	if on.core2:
		var ec: Dictionary = sim.cores[1 if p.team == "a" else 0]
		core2_m.frac = ec.hp / ec.max
		core2_m.num.text = str(maxi(0, ceili(ec.hp)))
		core2_m.fill = Color(Pal.TEAMS.get(ec.team, Pal.TEAMS.b).col)
	if on.qm:
		qm_b.text = "DELGADO · " + ("FOLLOW" if sim.qm.mode == "follow" else "DEFEND")   # Godot's sim keeps defending as ""
	if on.board:
		var rows: Array = sim.players.values()
		rows.sort_custom(func(a, b): return a.kills > b.kills or (a.kills == b.kills and a.get("deaths", 0) < b.get("deaths", 0)))
		_board_rows(rows.slice(0, 6))
	# the chat button lights up for a line someone else sent while the chat was closed
	var chat_open: bool = m.chat_box != null and m.chat_box.visible
	if chat_open or not on.chat:
		chat_seen = m.net.chat.size()
	var fresh := false
	for i in range(chat_seen, m.net.chat.size()):
		if m.net.chat[i].id != m.net.my_id:
			fresh = true
	if fresh != chat_b.get_meta("new", false):
		chat_b.set_meta("new", fresh)
		_style_btn(chat_b, BTNBG, WARN if fresh else LINE, 1, "m4", 13, BONE, 0, 0, Color(BTNBG.lightened(0.15), 0.9))
		chat_b.queue_redraw()
	for k in on:
		var n: Control = {"core": core_m, "core2": core2_m, "salv": salv, "qm": qm_b, "skip": skip_b, "board": board, "chat": chat_b}[k]
		n.visible = on[k]
	_layout()


## the Black Out phase (boHudPhase): [label, value, colour, START shown, START's label]
func _bo_phase(sim: Sim, host: bool) -> Array:
	var g: Dictionary = sim.game
	var B = g.get("bo")
	var nxt = null
	for c in sim.cores:
		if c.has("poi") and c.get("next", false):
			nxt = c
	var narrow := size.x / s < 700
	if g.phase == "build":
		return ["GATHER", "%s · %s" % [clock(g.timer), ("first: " + str(nxt.poi.name).to_lower()) if nxt != null else "first attack"], BONE, host, "START NOW"]
	if B == null:
		return ["GATHER", "", BONE, false, ""]
	if B.stage == "ready":
		var r := 0
		var n := 0
		for o in sim.players.values():
			if o.alive or o.get("downed", false):
				n += 1
				if o.get("boReady", false):
					r += 1
		return ["READY UP", "%s · ready %d/%d" % [clock(B.t), r, n], BONE, true, "READY ✓" if sim.player.get("boReady", false) else "READY"]
	if B.stage == "attack" and B.cur != null:
		var c: Dictionary = sim.cores[B.cur.ci]
		return ["ATTACK" if narrow else "POI ATTACK", "%s · %s" % [str(c.poi.name).to_lower() if c.has("poi") else "", clock(Sim.BO.cap - B.t)], RUST, false, ""]
	if B.stage == "push" or (B.stage == "done" and B.get("push") != null):
		var F: Dictionary = B.push if B.get("push") != null else {"t": 0.0, "n": 0, "dest": false}
		return ["PUSH" if narrow else "FINAL PUSH", "%s · %s" % [clock(F.t), "the destroyer" if F.get("dest", false) else "boss %d/6" % mini(6, F.n)], EVAC if F.get("dest", false) else RUST, false, ""]
	var held := sim.cores.filter(func(c): return c.has("poi") and not c.lost).size()
	return ["QUIET", "%s · %s" % [clock(B.t), ("next: " + str(nxt.poi.name).to_lower()) if nxt != null else "%d/8 held" % held], BONE, false, ""]


## the Free-for-all board (#board): up to six rows, you in yellow
func _board_rows(rows: Array) -> void:
	var sig := ",".join(rows.map(func(o): return "%s%d" % [o.id, o.kills]))
	if sig == _sig:
		return
	_sig = sig
	for ch in board.get_children():
		ch.queue_free()
	board.add_theme_constant_override("separation", roundi(2 * s))
	for o in rows:
		var me: bool = is_same(o, m.sim.player)
		var row := PanelContainer.new()
		var b := _sb(Color(14 / 255.0, 12 / 255.0, 10 / 255.0, 0.7))
		b.content_margin_left = roundf(8 * s)
		b.content_margin_right = roundf(8 * s)
		b.content_margin_top = roundf(2 * s)
		b.content_margin_bottom = roundf(2 * s)
		row.add_theme_stylebox_override("panel", b)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", roundi(12 * s))
		var n := label("s8", 16, WARN if me else DIM, 0.05)
		n.text = "YOU" if me else str(o.name).to_upper()
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var k := label("s8", 16, BONE, 0.05)
		k.text = str(o.kills)
		hb.add_child(n)
		hb.add_child(k)
		row.add_child(hb)
		board.add_child(row)


# ---------------------------------------------------------------- layout (the desktop grid: body.desk #top .phase)

## a label's natural width in CSS pixels
func _w(l: Label) -> float:
	if l.text == "":
		return 0.0
	var st := l.label_settings
	return st.font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, st.font_size).x / s


func _btn_w(b: Button, pad: float, bw: float) -> float:
	var f: Font = b.get_theme_font("font")
	return f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x / s + 2 * pad + 2 * bw


func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.position = Vector2(x, y) * s
	c.size = Vector2(w, h) * s


func _layout() -> void:
	var W := size.x / s
	var R := (W + minf(W, 1680.0)) / 2 - 24   # #top: at most 1680 wide, centred, 24 px in from each side
	var top := 12.0
	# column 2 (right): the clock, the note line (it keeps its room), salvage, START, the board
	var skip_w := 0.0
	if skip_b.visible:
		var kw := _w(skip_kc) + 8 if skip_kc.text != "" else 0.0
		skip_w = 12 + _w(skip_l) + (6 + kw if kw > 0 else 0.0) + 12 + 2
	var board_w := 0.0
	if board.visible:
		board_w = maxf(150, board.get_combined_minimum_size().x / s)
	var c2 := maxf(maxf(_w(val), minf(240, _w(note_l))), maxf(_w(salv) if salv.visible else 0.0, maxf(skip_w, board_w)))
	# column 1 (left): the meters and Delgado's button
	var qm_w := _btn_w(qm_b, 8, 2) if qm_b.visible else 0.0
	var c1 := maxf(234.0 if (core_m.visible or core2_m.visible) else 0.0, qm_w)
	var gap := 14.0 if c1 > 0 else 0.0
	# row 1: the phase label, chat and pause, right-aligned across both columns
	var x := R - 30
	_place(pause_b, x, top + 1, 30, 30)
	if chat_b.visible:
		x -= 40
		_place(chat_b, x, top + 1, 30, 30)
	var lw := _w(lab)
	x -= 10 + lw
	_place(lab, x, top, lw, 32)
	var row_w := R - x
	var y := top + 32 + 2
	# row 2: the clock | CORE (6 px above it, 2 below: .coreBar's margins)
	var h2 := 18.0
	_place(val, R - _w(val), y, _w(val), 18)
	var c1r := R - c2 - gap
	if core_m.visible:
		_place(core_m, c1r - 234, y + 6, 234, 19)
		core_m.layout()
		h2 = 27.0
	y += h2 + 2
	# row 3: the note line (2 px down; it keeps its room, empty or not) | ENEMY, or Delgado
	_place(note_l, R - minf(240, _w(note_l)), y + 2, minf(240, _w(note_l)), 14.85)
	var h3 := 16.85
	var qm_row := 3
	if core2_m.visible:
		_place(core2_m, c1r - 234, y + 2, 234, 19)
		core2_m.layout()
		h3 = maxf(h3, 23)
		qm_row = 4
	if qm_b.visible and qm_row == 3:
		_place(qm_b, c1r - qm_w, y, qm_w, 24)
		h3 = maxf(h3, 24)
	y += h3 + 2
	# row 4: salvage | Delgado (Base Battle has no Delgado, so this is only ever salvage)
	if salv.visible:
		_place(salv, R - _w(salv), y, _w(salv), 18)
		y += 18 + 2
	if skip_b.visible:
		y += 6
		_place(skip_b, R - skip_w, y, skip_w, 35)
		_place(skip_l, 13, 8, _w(skip_l), 19)
		var kw := _w(skip_kc) + 8
		_place(skip_kc, 13 + _w(skip_l) + 6, 10.5, kw, 14)
		skip_kc.visible = skip_kc.text != ""
		y += 35 + 2
	if board.visible:
		y += 6
		var bh := board.get_combined_minimum_size().y / s
		_place(board, R - board_w, y, board_w, bh)
		y += bh + 2
	if not m.sim.blackout():
		y += 6   # #feed's margin (an empty feed still adds its row; Black Out moves the feed beside the mini-map)
	var bw := maxf(row_w, c1 + gap + c2)
	box = Rect2((R - bw) * s, top * s, bw * s, (y - top) * s)
	# the tip: centred, 10 px under the box. Its box is the text's own width, at most 48 characters; the lines inside
	# are balanced (text-wrap: balance) and centred
	tip_p.visible = tip != ""
	if tip_p.visible:
		var st := tip_l.label_settings
		var f: Font = st.font
		var fz := st.font_size
		var mw := 48 * f.get_char_size(ord("0"), fz).x
		var tw := minf(mw, f.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, fz).x)
		var lines := _wrap(tip, f, fz, tw)
		var lo := tw / 4
		var hi := tw
		while hi - lo > 1:   # the narrowest width that keeps the same number of lines
			var mid := (lo + hi) / 2
			if _wrap(tip, f, fz, mid).size() > lines.size():
				lo = mid
			else:
				hi = mid
		tip_l.text = "\n".join(_wrap(tip, f, fz, hi))
		tip_l.custom_minimum_size = Vector2(ceilf(tw), 0)
		tip_p.reset_size()
		var ps := tip_p.get_combined_minimum_size()
		tip_p.size = ps
		tip_p.position = Vector2(roundf((size.x - ps.x) / 2), box.end.y + roundf(10 * s))


## words into lines no wider than w (the browser's line breaking)
static func _wrap(text: String, f: Font, fz: int, w: float) -> Array:
	var out: Array = []
	var cur := ""
	for word in text.split(" ", false):
		var t := word if cur == "" else cur + " " + word
		if cur != "" and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fz).x > w + 0.5:
			out.append(cur)
			cur = word
		else:
			cur = t
	if cur != "":
		out.append(cur)
	return out


## the Black Out mini-map's box (boMapBox, desktop): under the phase box and its note line, right-aligned
func bo_map_box() -> Rect2:
	var w := roundf(minf(170, size.x / s * 0.3))
	var y := box.end.y / s + 10 + 8
	return Rect2(Vector2(box.end.x / s - w, roundf(y)) * s, Vector2(w, roundf(w / 2)) * s)


## the mouse (or a finger, at pos) is on one of the HUD's buttons: a click there isn't a shot, a touch there isn't a stick
func has_pointer(pos = null) -> bool:
	if not visible:
		return false
	var mp: Vector2 = get_local_mouse_position() if pos == null else pos
	for b in [qm_b, skip_b, pause_b, chat_b]:
		if b.visible and Rect2(b.position, b.size).has_point(mp):
			return true
	return false
