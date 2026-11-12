class_name Hud
extends Control
## The in-game HUD, built as the browser builds it (page.html #top, #tip, #kit; style.css; hud() in 11-hud-chat.js), not
## painted: the phase box at the top right (the phase, its clock, the core or stake meters, Delgado's button, salvage,
## START, the Free-for-all board, pause and chat), the tip under it, and the build kit down the right (BUILD ON/OFF,
## WALL/DOOR, the materials, PLACE, ARMORY, NADE, SPRINT, ROLL, the class ability), every button pressable; and the
## messages: the banner (#toast) with its queue, the kill feed (#feed), the key bar (#keys, or the controller's buttons)
## and the boss bars, which the browser paints on its canvas (drawBossBars) and this paints too; and the rest: the
## Black Out mini-map (boMapDraw) and its arrow to a POI under attack, the room's chat (#chat, #chatBar), the
## Free-for-all respawn picker (#respawnJobs) and the casino's SIT button on touch (#casSitBtn). Sizes are the browser's desktop CSS pixels
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
var kit := {}   # the build kit's buttons (#kit): bm, wall, door, c0-c2, build, arm, nade, spr, roll, ab; and pk, its F
var kit_box := Rect2()   # the kit column, in screen pixels
var kit_sig: Array = []   # what the kit column was last laid out from (_kit_sig)
var toast_sig: Array = []   # what the banner's small line was last wrapped from
var _kcs: Array = []   # [label, background] of every key cap, restyled with the scale
var toast_q: Array = []   # TOAST_Q: waiting messages {big, small, kind}
var toast_cur = null   # the message up now
var toast_t := 0.0   # its time left
var toast_a := 0.0   # its opacity (0.25 s in and out)
var toast_p: PanelContainer
var toast_big: Label
var toast_small: Label
var feed_ls: Array = []   # the kill feed's four lines
var keys_c: Control   # the key bar, painted (its items are only text)
var keys_items: Array = []   # [[key, what], ...]
var keys_rect := Rect2()   # CSS pixels
var keys_boxes: Array = []   # each item's box (CSS pixels, on screen) and its [key, what]
var keys_at := Vector3()   # the window (CSS pixels) and the scale the key bar was laid out for
var key_sb: StyleBoxFlat   # the key caps' box, made at key_sb_s
var key_sb_s := 0.0
var boss_c: Control   # the boss bars, painted under everything else
var map_c: Control   # the Black Out mini-map and the arrow to a POI under attack, painted
var bo_fade := 1.0   # BO_FADE: the mini-map fades out under a banner that covers it
var arrow_c: Control   # the arrow to a POI under attack off screen (it doesn't fade with the map)
var chat_ls: Array = []   # the chat log's eight lines (#chatLog li)
var chat_bar: PanelContainer   # #chatBar: the line, SEND and the quick lines
var chat_in: LineEdit
var rj_p: PanelContainer   # #respawnJobs: NEXT LIFE AS
var rj_b: Dictionary = {}   # class -> its button
var sit_b: Button   # #casSitBtn
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


## a kit button: the browser's box (background, solid or dashed border, the picked chip's yellow edge) round its own
## parts, which the kit lays out; it fires as the browser's tapBtn does, on the press
class KitBtn extends Button:
	var h: Hud
	var bg := Color(27 / 255.0, 24 / 255.0, 20 / 255.0, 0.86)
	var line := Hud.LINE
	var dashed := false
	var bar := false   # .chip.sel::before: 3 px of yellow down the left edge
	var parts := {}

	func _init(hud: Hud, cb: Callable) -> void:
		h = hud
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		pressed.connect(cb)

	func part(key: String, l: Label) -> Label:
		parts[key] = l
		add_child(l)
		return l

	func look(nbg: Color, nline: Color, ndash: bool = false, nbar: bool = false) -> void:
		if nbg != bg or nline != line or ndash != dashed or nbar != bar:
			bg = nbg
			line = nline
			dashed = ndash
			bar = nbar
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, bg)
		var bw := maxf(1.0, roundf(h.s))
		if line.a > 0:
			if dashed:
				var q := [Vector2(bw / 2, bw / 2), Vector2(size.x - bw / 2, bw / 2), Vector2(size.x - bw / 2, size.y - bw / 2), Vector2(bw / 2, size.y - bw / 2)]
				for k in 4:
					draw_dashed_line(q[k], q[(k + 1) % 4], line, bw, 3 * h.s)
			else:
				draw_rect(r.grow(-bw / 2), line, false, bw)
		if bar:
			draw_rect(Rect2(0, 0, roundf(3 * h.s), size.y), Hud.WARN)


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
	_make_kit()
	_make_messages()
	_make_rest()
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
	for b in kit.values():
		if b is KitBtn:
			for l in b.parts.values():
				var st: Array = l.get_meta("st")
				l.label_settings = ls(st[0], st[1], st[2], st[3], false, st[4])
			b.queue_redraw()
	var pst: Array = kit.pk.get_meta("st")
	kit.pk.label_settings = ls(pst[0], pst[1], pst[2], pst[3], false, pst[4])
	for k in _kcs:
		k[0].add_theme_stylebox_override("normal", _sb(k[1], Color(0, 0, 0, 0), 0, 2))
	for l in [toast_big, toast_small] + feed_ls:
		var mst: Array = l.get_meta("st")
		l.label_settings = ls(mst[0], mst[1], mst[2], mst[3], l == toast_big, mst[4])
	if toast_cur != null:
		_toast_style()
	_rest_style()
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
	toast_clear()
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

func _process(dt: float) -> void:
	visible = not m.demo
	if not visible:
		return
	_toast_tick(dt)
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
	if tip != "" and not sim.understrip() and ((g.phase == "raid" and pv != "ffa") or (pv == "ffa" and g.time > 9)):   # THE UNDERSTRIP's tips time out by themselves (main._us_tips)
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
	if sim.understrip():
		lt = "%s %d/10" % [sim.map_def.short, g.us.level + 1]
		vt = "%d LIVES · C: JUICE %d/%d · E: INTERACT" % [g.us.lives, p.uj, p.ujm]
		lc = Color("#7cff6b")
		on.core = false
	lab.text = lt
	recolor(lab, lc)
	val.text = vt
	note_l.text = note
	note_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if _w(note_l) > 240 else TextServer.OVERRUN_NO_TRIMMING   # max-width 240, ellipsis
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
	_feed_update()
	_layout()
	_kit_update(sim, p, pv)
	_kit_layout()
	_keys_update(sim, p, pv)
	_toast_place()
	boss_c.queue_redraw()
	_rest_update(dt)


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

## a label's natural width in CSS pixels, as the browser lays it out: the letters, then the letter-spacing exactly
## (Godot draws it rounded to whole pixels), and for bold (<b>) Chrome's synthetic bold, size/30 a letter wider
func _w(l: Label) -> float:
	if l.text == "":
		return 0.0
	var st: Array = l.get_meta("st")
	var n := l.text.length()
	var w: float = _mono_w(l.text, st[1]) if str(st[0]).begins_with("m") else _text_w(st[0], l.text, st[1])
	return w + st[3] * st[1] * n + (st[1] / 30.0 * n if l.get_meta("bold", false) else 0.0)


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
	var feed_w := 0.0
	if not m.sim.blackout():
		for l in feed_ls:
			if l.visible:
				feed_w = maxf(feed_w, _w(l) + 17)
	var c2 := maxf(maxf(maxf(_w(val), minf(240, _w(note_l))), feed_w), maxf(_w(salv) if salv.visible else 0.0, maxf(skip_w, board_w)))
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
	if not m.sim.blackout():   # the kill feed: its row under the rest (6 px down; an empty one still keeps the 6)
		y += 6
		var n := 0
		for l in feed_ls:
			if l.visible:
				var fw := _w(l) + 17
				_place(l, R - fw, y, fw, 22)
				y += 22 + 3
				n += 1
		if n > 0:
			y -= 3
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


## the Black Out mini-map's box (boMapBox, desktop): under the phase box and its note line, right-aligned; it steps
## below the boss bars while they'd cover it. The kill feed sits beside it there.
func bo_map_box() -> Rect2:
	var w := roundf(minf(170, size.x / s * 0.3))
	var y := box.end.y / s + 10 + 8
	var b := Rect2(Vector2(box.end.x / s - w, roundf(y)), Vector2(w, roundf(w / 2)))
	var bb := boss_box()
	if bb.size.x > 0 and bb.intersects(b):
		b.position.y = roundf(bb.end.y + 6)
	return Rect2(b.position * s, b.size * s)


## the mouse (or a finger, at pos) is on one of the HUD's buttons: a click there isn't a shot, a touch there isn't a stick
func has_pointer(pos = null) -> bool:
	if not visible:
		return false
	var mp: Vector2 = get_local_mouse_position() if pos == null else pos
	for b in [qm_b, skip_b, pause_b, chat_b, toast_p, chat_bar, rj_p, sit_b] + kit.values().filter(func(k): return k is KitBtn):
		if b.is_visible_in_tree() and Rect2(b.global_position - global_position, b.size).has_point(mp):
			return true
	return false


# ---------------------------------------------------------------- the build kit (#kit, style.css body.desk sizes)

const KIT_BG := Color(27 / 255.0, 24 / 255.0, 20 / 255.0, 0.86)
const ACT := {   # the action buttons: border, text and key-cap colour, and the "on" look
	"nade": {"line": Color("#b0512f"), "col": Color("#e58a64")},
	"spr": {"line": Color("#6f9a7c"), "col": Color("#9fd6ae"), "on": Color(60 / 255.0, 98 / 255.0, 70 / 255.0, 0.92)},
	"roll": {"line": Color("#8a8fa8"), "col": Color("#c9cde0"), "on": Color(70 / 255.0, 74 / 255.0, 98 / 255.0, 0.92)},
	"ab": {"line": Color("#c9a05a"), "col": Color("#f0cf8a"), "on": Color(70 / 255.0, 90 / 255.0, 110 / 255.0, 0.92), "onl": Color("#9fc3e0"), "onc": Color("#cfe6f6")},
}
const CHIP_COL := [Color("#c99a5e"), Color("#c46a4c"), Color("#b9c0bf")]
const US_KIT := {"wpn": Color("#d8d2c4"), "itm": Color("#e2b436"), "oth": Color("#a89f8c")}
const US_RAR := {"c": "#9a958a", "r": "#4f95e0", "e": "#b168e0", "l": "#e2b436", "g": "#ffe27a", "u": "#ff9260"}


## a key cap (.kc): small mono letters on a coloured tab
func _kc_label(bg: Color, fg: Color) -> Label:
	var l := label("m6", 10, fg)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_kcs.append([l, bg])
	return l


## a press from the kit counts only while playing, with nothing open over the game (live() in 08-input.js)
func _live(f: Callable) -> Callable:
	return func():
		if m.demo or m.menus.active() or m.armory_open or m.skills_open or m.sim.game.phase == "over":
			return
		f.call()


func _make_kit() -> void:
	var act := func(id: String) -> Callable: return _live(func(): m.do_action(id))
	var bm := KitBtn.new(self, act.call("kit"))
	bm.part("lab", label("s8", 14, BONE, 0.08))
	bm.part("kc", _kc_label(BONE, INK))
	kit.bm = bm
	for pc in ["wall", "door"]:
		var b := KitBtn.new(self, _live(func(): m.sim.game.piece = pc))
		var l := b.part("lab", label("s8", 14, DIM, 0.08))
		l.text = pc.to_upper()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kit[pc] = b
	kit.pk = _kc_label(BONE, INK)
	for mi in 3:
		var b := KitBtn.new(self, act.call("mat%d" % (mi + 1)))
		var k := b.part("k", label("s9", 18, CHIP_COL[mi], 0.04))
		k.text = Pal.MAT[mi].name
		b.part("kc", _kc_label(BONE, INK))
		var n := b.part("n", label("m4", 11, DIM))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		kit["c%d" % mi] = b
	var bb := KitBtn.new(self, act.call("build"))
	for pt in [["act", label("s9", 22, INK, 0.05, 1.0)], ["sub", label("m4", 10, INK, 0.0, 1.2)]]:
		var l: Label = bb.part(pt[0], pt[1])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bb.part("kc", _kc_label(INK, WARN))
	kit.build = bb
	var arm := KitBtn.new(self, act.call("armory"))
	var al := arm.part("lab", label("s9", 17, WARN, 0.08))
	al.text = "ARMORY"
	arm.part("kc", _kc_label(WARN, INK))
	kit.arm = arm
	for k in ["nade", "spr", "roll", "ab"]:
		var A: Dictionary = ACT[k]
		var b := KitBtn.new(self, act.call({"nade": "nade", "spr": "sprint", "roll": "roll", "ab": "special"}[k]))
		var bl := b.part("lab", label("s8", 17, A.col, 0.08))
		bl.text = {"nade": "NADE", "spr": "SPRINT", "roll": "ROLL", "ab": "ROCKET"}[k]
		b.part("kc", _kc_label(A.col, INK))
		var n := b.part("n", label("m6", 12, BONE, 0.08))   # <b>: the button's letter-spacing carries into it
		n.set_meta("bold", true)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.line = A.line
		kit[k] = b
	for k in ["wpn", "itm", "oth"]:   # THE UNDERSTRIP's
		var b := KitBtn.new(self, act.call({"wpn": "matNext", "itm": "build", "oth": "piece"}[k]))
		b.part("lab", label("s8", {"wpn": 16, "itm": 15, "oth": 13}[k], US_KIT[k], 0.06))
		b.part("kc", _kc_label(US_KIT[k], INK))
		var n := b.part("n", label("m6", 12 if k != "oth" else 11, BONE, 0.08))
		n.set_meta("bold", true)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.line = US_KIT[k].darkened(0.3)
		kit[k] = b
	for b in kit.values():
		add_child(b)


## THE UNDERSTRIP's kit: the gun in hand (the class gun, or the found one with its magazine and reserve, bordered in its
## rarity's colour), the item SPACE places, the other one F swaps to
func _us_kit(sim: Sim, p: Dictionary) -> void:
	var on := sim.understrip()
	kit.wpn.visible = on and p.get("w2") != null
	kit.itm.visible = on
	kit.oth.visible = on
	if not on:
		return
	if kit.wpn.visible:
		var W: Dictionary = UsLoot.tables().weapons.get(p.w2.id, {"name": "?"})
		var mine: bool = int(p.get("wSel", 0)) == 1
		kit.wpn.parts.lab.text = W.name if mine else str(p.cls).to_upper().substr(0, 4) + " GUN"
		kit.wpn.parts.n.text = ("%d/%d" % [int(p.get("ammo", 0)), int(p.w2.get("res", 0))]) if mine else "INF"
		kit.wpn.parts.kc.text = _kc("1 / 2", "mat2")
		var rc := Color(US_RAR.get(str(p.w2.r), "#9a958a"))
		kit.wpn.look(KIT_BG, rc)
		recolor(kit.wpn.parts.lab, rc.lerp(BONE, 0.35))
	var bar: bool = str(p.get("uSel", "bar")) == "bar"
	var ui: Dictionary = p.get("ui", {})
	var n := int(ui.get("bar" if bar else "flare", 0))
	kit.itm.parts.lab.text = "BARRICADE" if bar else "FLARE"
	kit.itm.parts.n.text = str(n)
	kit.itm.parts.kc.text = _kc("SPACE", "build")
	kit.itm.modulate.a = 1.0 if n > 0 else 0.45
	kit.oth.parts.lab.text = "FLARE" if bar else "BARRICADE"
	kit.oth.parts.n.text = str(int(ui.get("flare" if bar else "bar", 0)))
	kit.oth.parts.kc.text = _kc("F", "piece")
	kit.oth.modulate.a = 0.7


## the kit's state, as hud() sets it: what each button says, which are picked, empty, on, locked, far or pulsing
func _kit_update(sim: Sim, p: Dictionary, pv: String) -> void:
	var g: Dictionary = sim.game
	var build_on: bool = m.settings.data.get("build", true) and not sim.understrip()
	var ffa := pv == "ffa"
	var show_kit := not sim.casino()
	for b in kit.values():
		b.visible = show_kit
	if not show_kit:
		return
	var bm: KitBtn = kit.bm
	bm.visible = not ffa
	bm.parts.lab.text = "BUILD ON" if build_on else "BUILD OFF"
	recolor(bm.parts.lab, BONE if build_on else DIM)
	bm.look(KIT_BG, LINE, not build_on)
	bm.parts.kc.text = _kc("B", "kit")
	_us_kit(sim, p)
	if sim.understrip():
		bm.parts.lab.text = "JUICE %d/%d" % [p.uj, p.ujm]
		bm.parts.kc.text = _kc("C", "drink")
	var kit_on := build_on and not ffa
	for k in ["wall", "door", "pk", "c0", "c1", "c2", "build"]:
		kit[k].visible = kit_on
	kit.pk.text = _kc("F", "piece")
	for pc in ["wall", "door"]:
		var sel: bool = g.piece == pc
		recolor(kit[pc].parts.lab, BONE if sel else DIM)
		kit[pc].look(KIT_BG, BONE if sel else LINE)
	for mi in 3:
		var c: KitBtn = kit["c%d" % mi]
		var locked := false
		if mi > 0 and p.mats[mi] == 0:
			for nd in sim.nodes:
				if nd.type == mi and nd.locked:
					locked = true
					break
		c.parts.n.text = ("R2" if mi == 1 else "R4") if locked else str(p.mats[mi])
		c.parts.kc.text = _kc(str(mi + 1), "")
		var sel: bool = g.sel == mi
		c.look(Color(58 / 255.0, 50 / 255.0, 40 / 255.0, 0.92) if sel else KIT_BG, BONE if sel else LINE, false, sel)
		c.modulate.a = 0.45 if locked else 1.0
	if kit_on:
		var t := sim.build_target(p, g.sel, g.piece == "door")
		var bb: KitBtn = kit.build
		bb.parts.act.text = t.act if t.ok else ("SOLID" if t.act == "SOLID" else "BUILD")
		bb.parts.sub.text = ("%s · %d" % [Pal.MAT[t.mat].name, t.cost]) if t.ok else t.reason
		bb.parts.kc.text = _kc("SPACE", "build")
		var fg := INK if t.ok else BONE
		recolor(bb.parts.act, fg)
		recolor(bb.parts.sub, fg)
		bb.look(WARN if t.ok else Color("#4a4234"), Color(0, 0, 0, 0))
		_kc_colors(bb.parts.kc, INK if t.ok else BONE, WARN if t.ok else INK)
	# ARMORY: shown while the shop's open; faint and dashed away from the stake; pulsing when something's affordable
	var arm: KitBtn = kit.arm
	arm.visible = sim.shop_open(p)
	arm.parts.kc.text = _kc("E", "armory")
	if arm.visible:
		var near := sim.near_stake(p)
		var afford := false
		for U in Sim.UPG:
			var lv: int = p.up.get(U.k, 0)
			if lv < Sim.ARM_MAX and p.sal >= U.cost[lv]:
				afford = true
		if pv == "":
			var dl: int = g.get("dellLv", 0)
			if (dl < Sim.ARM_MAX and p.sal >= Sim.DELL_UP.cost[dl]) or (sim.ammo_mode() and p.sal >= (75 if p.ammoEq.any(func(a): return a != "") else 150)):
				afford = true
		var bg := Color(58 / 255.0, 48 / 255.0, 28 / 255.0, 0.92)
		if near and afford and not PalSettings.reduce_motion:   # @keyframes pulse: 1.2 s, half way rgba(226,180,54,.28)
			var f := 0.5 - 0.5 * cos(Time.get_ticks_msec() / 1000.0 / 1.2 * TAU)
			bg = bg.lerp(Color(226 / 255.0, 180 / 255.0, 54 / 255.0, 0.28), f)
		arm.look(bg, WARN, not near)
		arm.modulate.a = 1.0 if near else 0.55
	# NADE, SPRINT, ROLL and the class ability, with their counts and cooldowns
	var nade: KitBtn = kit.nade
	nade.parts.n.text = str(p.nades)
	nade.parts.kc.text = _kc("G", "nade")
	nade.modulate.a = 0.4 if p.nades <= 0 else 1.0
	var spr: KitBtn = kit.spr
	spr.visible = p.C.get("sprint", false)
	if spr.visible:
		var on: bool = p.get("sprT", 0.0) > 0
		var cd: float = p.get("sprCd", 0.0)
		spr.parts.n.text = "GO" if on else ("%ds" % ceili(cd) if cd > 0 else "READY")
		spr.parts.kc.text = _kc("SHIFT", "special")
		spr.look(ACT.spr.on if on else KIT_BG, ACT.spr.line)
		spr.modulate.a = 0.45 if not on and cd > 0 else 1.0
	var roll: KitBtn = kit.roll
	var rolling := sim.rolling(p)
	var rcd: float = p.get("dgCd", 0.0)
	roll.parts.n.text = "GO" if rolling else ("%ds" % ceili(rcd) if rcd > 0 else "READY")
	roll.parts.kc.text = _kc("V", "")
	roll.look(ACT.roll.on if rolling else KIT_BG, ACT.roll.line)
	roll.modulate.a = 0.45 if not rolling and rcd > 0 else 1.0
	var ab: KitBtn = kit.ab
	ab.visible = pv == "" and p.cls in ["soldier", "sniper"]   # hasAbility: rockets and stealth are co-op only
	if ab.visible:
		# the browser's p.ab: rockets left, or stealth's time (hidden) and cooldown; Godot's sim keeps rk, stl and stlCd
		var snipe: bool = p.cls == "sniper"
		var stl: float = p.get("stl", 0.0)
		var scd: float = p.get("stlCd", 0.0)
		var rk: int = p.get("rk", 0)
		ab.parts.lab.text = "STEALTH" if snipe else "ROCKET"
		ab.parts.n.text = (("%ds" % ceili(stl)) if stl > 0 else ("%ds" % ceili(scd) if scd > 0 else "READY")) if snipe else str(maxi(0, rk))
		ab.parts.kc.text = _kc("Q", "special")
		var on := snipe and stl > 0
		ab.look(ACT.ab.on if on else KIT_BG, ACT.ab.onl if on else ACT.ab.line)
		recolor(ab.parts.lab, ACT.ab.onc if on else ACT.ab.col)
		ab.modulate.a = 0.45 if ((not on and scd > 0) if snipe else rk <= 0) else 1.0


func _kc_colors(l: Label, bg: Color, fg: Color) -> void:
	for k in _kcs:
		if k[0] == l and k[1] != bg:
			k[1] = bg
			l.add_theme_stylebox_override("normal", _sb(bg, Color(0, 0, 0, 0), 0, 2))
	recolor(l, fg)


## a key cap's width (its text and 4 px either side), 0 when it's hidden
func _kcw(l: Label) -> float:
	l.visible = l.text != ""
	return _w(l) + 8 if l.visible else 0.0


## the kit column: 136 px wide, its right edge 24 px in (centred 1632 px on wide screens), its foot 64 px up, the
## buttons stacked with 7 px between them (6 inside the build kit); a button whose parts need more room widens it
## (the browser's grid does the same, past the right edge)
func _kit_layout() -> void:
	if _kit_sig() == kit_sig:
		return
	var W := size.x / s
	var H := size.y / s
	var order := ["bm", "wpn", "itm", "oth", "pieces", "c0", "c1", "c2", "build", "arm", "nade", "spr", "roll", "ab"]
	var hgt := {"bm": 30.0, "wpn": 44.0, "itm": 44.0, "oth": 30.0, "pieces": 32.0, "c0": 40.0, "c1": 40.0, "c2": 40.0, "build": 70.0, "arm": 44.0, "nade": 44.0, "spr": 44.0, "roll": 44.0, "ab": 44.0}
	# the widest button's own needs
	var cw := 136.0
	for k in ["wpn", "itm", "oth", "nade", "spr", "roll", "ab"]:
		var b: KitBtn = kit[k]
		if b.visible:
			var kw := _kcw(b.parts.kc)
			cw = maxf(cw, 11 + _w(b.parts.lab) + (6 if k == "roll" else 0.0) + (kw + 8 + (6 if k == "roll" else 0.0) if kw > 0 else 0.0) + _w(b.parts.n) + 11)
	for mi in 3:
		var c: KitBtn = kit["c%d" % mi]
		if c.visible:
			var kw := _kcw(c.parts.kc)
			cw = maxf(cw, 10 + _w(c.parts.k) + (kw + 8 if kw > 0 else 0.0) + _w(c.parts.n) + 10)
	var x0 := W - maxf(24, (W - 1632) / 2) - 136
	var shown := order.filter(func(k): return kit.wall.visible if k == "pieces" else kit[k].visible)
	var total := 0.0
	for i in shown.size():
		total += hgt[shown[i]]
		if i > 0:
			total += 6.0 if shown[i] in ["c0", "c1", "c2", "build"] else 7.0   # 6 inside the build kit, 7 between
	var y := H - 64 - total
	var top := y
	for i in shown.size():
		var k: String = shown[i]
		if i > 0:
			y += 6.0 if k in ["c0", "c1", "c2", "build"] else 7.0
		var bh: float = hgt[k]
		match k:
			"bm":
				_place(kit.bm, x0, y, cw, bh)
				_center_row(kit.bm.parts.lab, kit.bm.parts.kc, cw, bh, 6)
			"pieces":
				var pw := (cw - 4) / 2
				_place(kit.wall, x0, y, pw, bh)
				_place(kit.door, x0 + pw + 4, y, pw, bh)
				for pc in ["wall", "door"]:
					_place(kit[pc].parts.lab, 0, (bh - _lh(kit[pc].parts.lab)) / 2, pw, _lh(kit[pc].parts.lab))
				var pkw := _kcw(kit.pk)
				_place(kit.pk, x0 + cw + 4 - pkw, y - 7, pkw, 14)
			"c0", "c1", "c2":
				var c: KitBtn = kit[k]
				_place(c, x0, y, cw, bh)
				var nw := _w(c.parts.n)
				_place(c.parts.k, 10, (bh - 22) / 2, _w(c.parts.k), 22)
				_place(c.parts.n, cw - 10 - nw, (bh - 14) / 2, nw, 14)
				var kw := _kcw(c.parts.kc)
				_place(c.parts.kc, cw - 10 - nw - 8 - kw, (bh - 14) / 2, kw, 14)
			"build":
				var bb: KitBtn = kit.build
				_place(bb, x0, y, cw, bh)
				var kw := _kcw(bb.parts.kc)
				var ch: float = 22 + 1 + 12 + (1 + 3 + 14 if kw > 0 else 0.0)
				var cy: float = (bh - ch) / 2
				_place(bb.parts.act, 6, cy, cw - 12, 22)
				_place(bb.parts.sub, 6, cy + 23, cw - 12, 12)
				_place(bb.parts.kc, (cw - kw) / 2, cy + 39, kw, 14)
			"arm":
				_place(kit.arm, x0, y, cw, bh)
				_center_row(kit.arm.parts.lab, kit.arm.parts.kc, cw, bh, 6)
			_:
				var b: KitBtn = kit[k]
				_place(b, x0, y, cw, bh)
				var lab_l: Label = b.parts.lab
				var nw := _w(b.parts.n)
				_place(lab_l, 11, (bh - _lh(lab_l)) / 2, _w(lab_l), _lh(lab_l))
				_place(b.parts.n, cw - 11 - nw, (bh - 15) / 2, nw, 15)
				var kw := _kcw(b.parts.kc)
				_place(b.parts.kc, cw - 11 - nw - 8 - (6 if k == "roll" else 0.0) - kw, (bh - 14) / 2, kw, 14)
		y += bh
	kit_box = Rect2(Vector2(x0, top) * s, Vector2(136, y - top) * s)   # #kit itself stays 136 wide; wider buttons overhang it
	kit_sig = _kit_sig()


## all _kit_layout reads: the HUD's size and scale, and each kit control's visibility, text, style and minimum size (the
## key caps' visibility too, which it sets itself); the column is laid out again only when one of them changed. The
## minimum size clamps what _place sets, and after a restyle it's the old one until the next frame
func _kit_sig() -> Array:
	var a := [size, s]
	for k in kit:
		var b: Control = kit[k]
		a.append_array([b.visible, b.get_combined_minimum_size()])
		if b is Label:
			a.append_array([b.text, b.label_settings])
		elif b is KitBtn:
			a.append(b.text)
			for l in b.parts.values():
				if l is Label:
					a.append_array([l.visible, l.text, l.label_settings, l.get_combined_minimum_size()])
	return a


## a label's line height in CSS pixels
func _lh(l: Label) -> float:
	var st := l.label_settings
	return st.font.get_height(st.font_size) / s


## a label and its key cap side by side, centred in a button (#bmBtn, #armBtn: flex, centred)
func _center_row(l: Label, kc: Label, w: float, h: float, gap: float) -> void:
	var kw := _kcw(kc)
	var lw := _w(l)
	var gw := lw + (gap + kw if kw > 0 else 0.0)
	var x := (w - gw) / 2
	_place(l, x, (h - _lh(l)) / 2, lw, _lh(l))
	_place(kc, x + lw + gap, (h - 14) / 2, kw, 14)


# ---------------------------------------------------------------- messages: the banner, the kill feed, the key bar, the boss bars

func _make_messages() -> void:
	boss_c = Control.new()
	boss_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	boss_c.draw.connect(_draw_boss_bars)
	add_child(boss_c)
	move_child(boss_c, 0)   # the browser paints them on its canvas, under the HUD
	for i in 4:
		var l := label("s8", 15, BONE, 0.06)
		l.visible = false
		feed_ls.append(l)
		add_child(l)
	keys_c = Control.new()
	keys_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys_c.draw.connect(_draw_keys)
	add_child(keys_c)
	toast_p = PanelContainer.new()
	toast_p.mouse_filter = Control.MOUSE_FILTER_STOP
	toast_p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toast_p.gui_input.connect(func(e: InputEvent):   # tap the message to dismiss it
		if e is InputEventMouseButton and e.pressed and toast_cur != null:
			toast_t = 0.0
			accept_event())
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_big = label("s9", 28, BONE, 0.06, 1.0)
	toast_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_small = label("m4", 14, BONE, 0.0, 1.25)
	toast_small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_small.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(toast_big)
	vb.add_child(toast_small)
	toast_p.add_child(vb)
	toast_p.visible = false
	add_child(toast_p)


## a message (toast() in 11-hud-chat.js): phase messages go before the minor ones still waiting; at most three wait
func toast(big: String, small: String = "") -> void:
	if m.demo:
		return
	var b := big.to_upper()
	var kind := "minor"
	if _rx.search(b) != null:
		kind = "bad" if RegEx.create_from_string("LOST|FELL|LEFT BEHIND|POWER IS OUT").search(b) != null else ("good" if RegEx.create_from_string("HELD|BROKEN|IS DOWN|EVACUATED").search(b) != null else "threat")
	var msg := {"big": big, "small": small, "kind": kind}
	if toast_cur == null:
		_toast_show(msg)
		return
	if kind != "minor":
		var i := -1
		for k in toast_q.size():
			if toast_q[k].kind == "minor":
				i = k
				break
		if i >= 0:
			toast_q.insert(i, msg)
		else:
			toast_q.append(msg)
	else:
		toast_q.append(msg)
	while toast_q.size() > 3:
		var i := -1
		for k in toast_q.size():
			if toast_q[k].kind == "minor":
				i = k
				break
		if i < 0:
			break
		toast_q.remove_at(i)


func toast_clear() -> void:
	toast_q.clear()
	toast_cur = null
	toast_t = 0.0
	toast_a = 0.0
	toast_p.visible = false
	note = ""


func _toast_show(msg: Dictionary) -> void:
	toast_cur = msg
	toast_t = (3.0 if msg.kind == "minor" else 4.5) * float(m.settings.data.get("msgTime", 1.0))
	if msg.kind != "minor":
		note = msg.big
	_toast_style()


func _toast_style() -> void:
	var msg: Dictionary = toast_cur
	var b := _sb(Color(10 / 255.0, 9 / 255.0, 7 / 255.0, 0.82), Color(0, 0, 0, 0), 0, 3)
	var bw := 0 if msg.kind == "minor" else int(maxf(1.0, roundf(3 * s)))
	if bw > 0:
		b.border_color = {"threat": Color("#ff8a3a"), "good": Color("#8fe0a0"), "bad": Color("#e8573a")}[msg.kind]
		b.border_width_top = bw
		b.border_width_bottom = bw
	b.content_margin_left = roundf(12 * s)
	b.content_margin_right = roundf(12 * s)
	b.content_margin_top = roundf(6 * s) + bw
	b.content_margin_bottom = roundf(7 * s) + bw
	toast_p.add_theme_stylebox_override("panel", b)
	toast_big.text = msg.big


func _toast_tick(dt: float) -> void:
	if toast_cur != null:
		toast_t -= dt
		if toast_t <= 0:
			toast_cur = null
			if not toast_q.is_empty():
				_toast_show(toast_q.pop_front())
	toast_a = clampf(toast_a + (dt if toast_cur != null else -dt) / 0.25, 0.0, 1.0)


## where the banner goes (toastPlace): on a wide screen the top row left of the phase box, at most 640 wide and
## centred in it; below the boss bars wherever they'd overlap
func _toast_place() -> void:
	toast_p.visible = toast_a > 0 and (toast_cur != null or toast_p.visible)
	if not toast_p.visible:
		return
	toast_p.modulate.a = toast_a
	var W := size.x / s
	var H := size.y / s
	var ph := Rect2(box.position / s, box.size / s)
	var land := H <= 500 and W > H
	var left := 12.0
	var right := W - 12
	var top := maxf(ph.end.y, (tip_p.position.y + tip_p.size.y) / s if tip_p.visible else 0.0) + 8
	if not land and ph.position.x > 360:
		left = 16
		right = ph.position.x - 16
		top = 12
	elif land:
		left = 16
		right = (bo_map_box().position.x / s if m.sim.blackout() else ph.position.x) - 8
		top = 12
	var w := minf(640, maxf(200, right - left))
	var x := roundf(left + (right - left - w) / 2)
	# the message: its small line at most 62 characters wide, two lines at most, balanced
	if toast_cur != null:
		var sm: String = toast_cur.small
		toast_small.visible = sm != ""
		if sm != "":
			var st := toast_small.label_settings
			var f: Font = st.font
			var mw := minf(62 * f.get_char_size(ord("0"), st.font_size).x, (w - 24) * s)
			var sig := [sm, mw, f, st.font_size]
			if sig != toast_sig:   # wrapped again only when the line or its room changed
				toast_sig = sig
				var lines := _wrap(sm, f, st.font_size, mw)
				var lo := mw / 4
				var hi := mw
				while hi - lo > 1:
					var mid := (lo + hi) / 2
					if _wrap(sm, f, st.font_size, mid).size() > lines.size():
						lo = mid
					else:
						hi = mid
				lines = _wrap(sm, f, st.font_size, hi)
				if lines.size() > 2:   # -webkit-line-clamp: 2
					lines = [lines[0], lines[1].substr(0, maxi(0, lines[1].length() - 1)) + "…"]
				toast_small.text = "\n".join(lines)
				toast_small.custom_minimum_size = Vector2(ceilf(mw), 0)
		(toast_p.get_child(0) as VBoxContainer).add_theme_constant_override("separation", roundi(4 * s))   # small's margin-top
	var hh := toast_p.get_combined_minimum_size().y / s
	var bb := boss_box()
	if bb.size.x > 0 and bb.position.x < x + w and bb.end.x > x and top < bb.end.y and top + hh > bb.position.y:
		top = bb.end.y + 6
	toast_p.position = Vector2(x, roundf(top)) * s
	toast_p.size = Vector2(w * s, 0)
	toast_p.reset_size()
	toast_p.size.x = w * s


## the banner's box (toastRect), in CSS pixels; empty when none is up
func toast_box() -> Rect2:
	return Rect2(toast_p.position / s, toast_p.size / s) if toast_p.visible and toast_cur != null else Rect2()


# the kill feed (#feed span): the newest first, four at most, each fading out in its last 0.6 s
func _feed_update() -> void:
	var F: Array = m.feed
	var bo: bool = m.sim.blackout()
	for i in feed_ls.size():
		var l: Label = feed_ls[i]
		l.visible = i < F.size()
		if not l.visible:
			continue
		var f: Dictionary = F[i]
		var col: Color = Color(f.col) if f.col is String else f.col
		l.text = f.text
		recolor(l, col)
		var sb := _sb(Color(14 / 255.0, 12 / 255.0, 10 / 255.0, 0.72))
		sb.border_color = col
		sb.border_width_right = int(maxf(1.0, roundf(3 * s)))
		sb.content_margin_left = roundf(7 * s)
		sb.content_margin_right = roundf(7 * s) + sb.border_width_right
		sb.content_margin_top = roundf(2 * s)
		sb.content_margin_bottom = roundf(2 * s)
		l.add_theme_stylebox_override("normal", sb)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.modulate.a = clampf((f.t - 0.1) / 0.6, 0.0, 1.0)
	if bo:   # Black Out: beside the mini-map, its top lines up with the map's
		var mb := bo_map_box()
		var y := mb.position.y / s
		for l in feed_ls:
			if l.visible:
				var fw := _w(l) + 17
				_place(l, mb.position.x / s - 8 - fw, y, fw, 22)
				y += 25


# ---- the key bar (keyBar / padBar): every key this soldier has right now, in key caps, centred along the bottom

func _keys_update(sim: Sim, p: Dictionary, pv: String) -> void:
	var on := not _touch() and not sim.casino()
	keys_c.visible = on
	if not on:
		return
	var a: Array = []
	var build_on: bool = m.settings.data.get("build", true)
	var start: bool = sim.game.phase == "build" and not m.net.guest()
	if m.inp.mode == "pad":
		var P := func(id: String) -> String: return _pad(id)
		a = [[PalSettings.glyph(PalSettings.PB.LS, m.inp.pad_kind), "move"], [PalSettings.glyph(PalSettings.PB.RS, m.inp.pad_kind), "aim"], [P.call("fire"), "fire"], [P.call("nade"), "grenade"], [P.call("roll"), "roll"]]
		if _has_ability(p, pv):
			a.append([P.call("special"), "stealth" if p.cls == "sniper" else "rocket"])
		elif p.C.get("sprint", false):
			a.append([P.call("special"), "sprint"])
		if pv != "ffa" and build_on:
			a += [[P.call("build"), "build"], [P.call("matPrev") + " " + P.call("matNext"), "material"], [P.call("piece"), "door"]]
		if pv != "ffa":
			a.append([P.call("kit"), "build kit"])
		if sim.shop_open(p):
			a.append([P.call("armory"), "armory"])
		if start:
			a.append([P.call("start"), "start battle" if pv != "" else "start raid"])
		a.append([PalSettings.glyph(PalSettings.PB.MENU, m.inp.pad_kind), "pause"])
		a = a.filter(func(k): return k[0] != "—")
	else:
		var G: Dictionary = p.gun
		a = [["WASD", "move"], ["MOUSE", "aim, click or hold to fire" if G.has("clickCd") else ("aim, hold to fire bursts" if G.get("burst", false) else "aim, hold to fire")], ["G", "grenade"], ["V", "roll"]]
		if p.C.get("sprint", false):
			a.append(["SHIFT", "sprint"])
		if G.has("mag"):
			a.append(["R", "reload"])
		if pv != "ffa" and build_on:
			a += [["SPACE", "build"], ["1 2 3", "material"], ["F", "door"]]
		if pv != "ffa":
			a.append(["B", "build kit"])
		if sim.shop_open(p):
			a.append(["E", "armory"])
		if start:
			a.append(["ENTER", "start battle" if pv != "" else "start raid"])
		if m.net.is_online():
			a.append(["T", "chat"])
		a.append(["ESC", "pause"])
	if sim.understrip():
		a = [["WASD", "move"], ["MOUSE", "aim / fire"], ["V", "roll"], ["C", "juice"], ["E", "interact"], ["1 / 2", "weapon"], ["F", "item"], ["SPACE", "use item"], ["G", "grenade"], ["ESC", "pause"]]
		if _has_ability(p, pv):
			a.insert(3, ["Q", "stealth" if p.cls == "sniper" else "rocket"])
	var W := size.x / s
	var H := size.y / s
	# the same items in the same window: the bar as laid out and drawn last frame
	if a == keys_items and Vector3(W, H, s) == keys_at:
		return
	keys_items = a
	keys_at = Vector3(W, H, s)
	# the box: as wide as its items, at most the window less 360 (plus 12 padding and a border each side); the items
	# wrap as inline blocks, each line centred, 26 px a line; its foot 14 px up, centred across
	var maxw := W - 360
	var lines: Array = [[]]
	var lw := 0.0
	var widest := 0.0
	for it in a:
		var iw := _key_w(it) + 14
		if lw > 0 and lw + iw > maxw:
			lines.append([])
			lw = 0.0
		lines[-1].append(it)
		lw += iw
		widest = maxf(widest, lw)
	var total := 0.0
	for it in a:
		total += _key_w(it) + 14
	var cw := minf(total, maxw)   # width: max-content, up to max-width (a wrapped bar is the full max-width)
	var h := lines.size() * 26 + 12 + 2
	keys_rect = Rect2(roundf((W - cw - 26) / 2), H - 14 - h, cw + 26, h)
	keys_boxes.clear()
	for li in lines.size():
		var lw2 := 0.0
		for it in lines[li]:
			lw2 += _key_w(it) + 14
		var x := keys_rect.position.x + 13 + (cw - lw2) / 2
		for it in lines[li]:
			keys_boxes.append({"r": Rect2(x, keys_rect.position.y + 7 + li * 26, _key_w(it), 26), "it": it})
			x += _key_w(it) + 14
	keys_c.position = keys_rect.position * s
	keys_c.size = keys_rect.size * s
	keys_c.queue_redraw()


func _has_ability(p: Dictionary, pv: String) -> bool:
	return pv == "" and p.cls in ["soldier", "sniper"]


## a text's width in CSS pixels as the browser lays it out: measured ten times the size, since at small sizes Godot's
## hinting rounds every letter's advance
static func _text_w(f: String, t: String, size: float) -> float:
	return UiKit.face(f).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(size * 10)).x / 10.0


## IBM Plex Mono is monospaced: every letter 0.6 em, as the browser lays it out (Godot's hinting rounds each advance)
static func _mono_w(t: String, size: float) -> float:
	return t.length() * 0.6 * size


## one key-bar item's width: the key cap (its text and 5 px either side), 5 px, the words
func _key_w(it: Array) -> float:
	return _mono_w(it[0], 11) + 10 + 5 + _mono_w(it[1], 13)


func _draw_keys() -> void:
	var r := Rect2(Vector2.ZERO, keys_c.size)
	keys_c.draw_rect(r, Color(14 / 255.0, 12 / 255.0, 10 / 255.0, 0.78))
	var bw := maxf(1.0, roundf(s))
	keys_c.draw_rect(r.grow(-bw / 2), LINE, false, bw)
	var fk := UiKit.face("m6")
	var fw := UiKit.face("m4")
	var zk := roundi(11 * s)
	var zw := roundi(13 * s)
	if key_sb == null or key_sb_s != s:
		key_sb = _sb(BONE, Color(0, 0, 0, 0), 0, 2)
		key_sb_s = s
	for kb in keys_boxes:
		var r0: Rect2 = kb.r
		var it: Array = kb.it
		var x: float = r0.position.x - keys_rect.position.x
		var y: float = r0.position.y - keys_rect.position.y
		var kw: float = _mono_w(it[0], 11) + 10
		keys_c.draw_style_box(key_sb, Rect2(Vector2(x, y + 5) * s, Vector2(kw, 16) * s))
		keys_c.draw_string(fk, Vector2((x + 5) * s, (y + 13) * s + (fk.get_ascent(zk) - fk.get_descent(zk)) / 2), it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, zk, INK)
		keys_c.draw_string(fw, Vector2((x + kw + 5) * s, (y + 13) * s + (fw.get_ascent(zw) - fw.get_descent(zw)) / 2), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, zw, BONE)


# ---- the boss bars (drawBossBars, drawBossCombined in 16-characters.js): centred under the tip; one bar a boss,
# slim rows for three, one shared bar (and the nearest) for four or more

func _bosses() -> Array:
	if m.demo or m.sim.pvp() != "":
		return []
	return m.sim.enemies.filter(func(e): return e.type == "boss")


func _boss_y() -> float:
	var tip_b := (tip_p.position.y + tip_p.size.y) / s if tip_p.visible else 0.0
	var W := size.x / s
	return maxf((box.end.y / s + 10) if W < 700 else 120.0, tip_b + 10)


## the bars' box (bossBarsBox), CSS pixels; empty with no boss up
func boss_box() -> Rect2:
	var n := _bosses().size()
	if n == 0:
		return Rect2()
	var W := size.x / s
	var y := _boss_y()
	var w := minf(440, W - 48)
	var h := 40.0 if n >= 4 else (23.0 * n if n > 2 else 32.0 * n)
	return Rect2((W - w) / 2 - 3, y - 3, w + 6, h)


func _draw_boss_bars() -> void:
	var list := _bosses()
	if list.is_empty():
		return
	var W := size.x / s
	var w := minf(440, W - 48)
	var x := (W - w) / 2
	var y := _boss_y()
	var st := UiKit.face("s8")
	var mo := UiKit.face("m6")
	var txt := func(f: Font, t: String, px: float, py: float, sz: float, col: Color, right: bool = false) -> void:
		var z := roundi(sz * s)
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, z).x
		boss_c.draw_string(f, Vector2(px * s - (tw if right else 0.0), py * s), t, HORIZONTAL_ALIGNMENT_LEFT, -1, z, col)
	var bar := func(px: float, py: float, bw: float, bh: float, f: float, col: Color, flash: bool) -> void:
		boss_c.draw_rect(Rect2(Vector2(px, py) * s, Vector2(bw, bh) * s), Color("#2a2520"))
		boss_c.draw_rect(Rect2(Vector2(px, py) * s, Vector2(bw * f, bh) * s), col)
		if flash:
			boss_c.draw_rect(Rect2(Vector2(px, py) * s, Vector2(bw * f, bh) * s), Color(1, 1, 1, 0.5))
	if list.size() >= 4:   # drawBossCombined: the summed health, and the nearest one
		var hp := 0.0
		var mx := 0.0
		var me: Dictionary = m.sim.player
		var near: Dictionary = list[0]
		for e in list:
			hp += maxf(0, e.hp)
			mx += e.max
			if Vector2(e.x - me.x, e.y - me.y).length() < Vector2(near.x - me.x, near.y - me.y).length():
				near = e
		var f := hp / mx if mx > 0 else 0.0
		var B := Sim.boss_def(near.boss)
		var nf := maxf(0, near.hp / near.max)
		boss_c.draw_rect(Rect2(Vector2(x - 3, y - 3) * s, Vector2(w + 6, 40) * s), Color(12 / 255.0, 10 / 255.0, 8 / 255.0, 0.8))
		txt.call(st, "%s · %d BOSSES" % ["FINAL PUSH" if m.sim.blackout() else "GAUNTLET", list.size()], x + 2, y + 9, 12, Color("#d8fff3"))
		txt.call(mo, "%d%%" % ceili(f * 100), x + w - 2, y + 9, 10, BONE, true)
		bar.call(x, y + 13, w, 6, f, Color("#9cebdc"), false)
		txt.call(st, "NEAREST · " + B.name, x + 2, y + 29, 10, Color(B.col))
		txt.call(mo, "%d%%" % ceili(nf * 100), x + w - 2, y + 29, 9, BONE, true)
		bar.call(x, y + 32, w, 3, nf, Color(B.col), near.get("flash", 0.0) > 0)
		return
	var slim := list.size() > 2
	for e in list:
		var B := Sim.boss_def(e.boss)
		var f := maxf(0, e.hp / e.max)
		if m.sim.understrip():   # each stage's own bar (usBossFrac); the Gatekeeper's pilot is his own bar
			f = UsDeep.boss_frac(m.sim, e)
		var col := Color("#7cff6b") if e.get("pilot", false) else Color(B.col)
		if e.get("pilot", false):
			B = B.duplicate()
			B.name = B.name + " · THE PILOT"
		if slim:   # three at once: slim rows
			boss_c.draw_rect(Rect2(Vector2(x - 3, y - 3) * s, Vector2(w + 6, 20) * s), Color(12 / 255.0, 10 / 255.0, 8 / 255.0, 0.78))
			txt.call(st, B.name, x + 2, y + 8, 11, col)
			txt.call(mo, "%d%%" % ceili(f * 100), x + w - 2, y + 8, 9, BONE, true)
			bar.call(x, y + 11, w, 4, f, col, e.get("flash", 0.0) > 0)
			y += 23
			continue
		boss_c.draw_rect(Rect2(Vector2(x - 3, y - 3) * s, Vector2(w + 6, 26) * s), Color(12 / 255.0, 10 / 255.0, 8 / 255.0, 0.8))
		txt.call(st, B.name, x + 2, y + 10, 13, col)
		txt.call(mo, "%d%%" % ceili(f * 100), x + w - 2, y + 10, 11, BONE, true)
		var wk: String = Sim.BOSS_WEAK.get(e.boss, Sim.BOSS_WEAK2.get(e.boss, ""))
		if m.sim.ammo_mode() and wk != "" and w > 300:
			for A in Sim.AMMO:
				if A.id == wk:
					txt.call(mo, "WEAK: " + A.name, x + w - 44, y + 10, 9, Color(A.col), true)
		bar.call(x, y + 14, w, 6, f, col, e.get("flash", 0.0) > 0)
		y += 32


# ---------------------------------------------------------------- the rest: the mini-map, chat, NEXT LIFE AS, SIT

const QUICK := ["NICE", "HELP!", "ON MY WAY", "WALL DOWN", "NEED MATS", "GG"]


func _make_rest() -> void:
	map_c = Control.new()
	map_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_c.draw.connect(_draw_bo)
	add_child(map_c)
	move_child(map_c, 1)
	arrow_c = Control.new()
	arrow_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	arrow_c.draw.connect(_draw_poi_arrow)
	add_child(arrow_c)
	move_child(arrow_c, 2)
	for i in 8:
		var r := RichTextLabel.new()
		r.fit_content = true
		r.scroll_active = false
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.visible = false
		chat_ls.append(r)
		add_child(r)
	chat_bar = PanelContainer.new()
	chat_bar.visible = false
	var vb := VBoxContainer.new()
	var row := HBoxContainer.new()
	chat_in = LineEdit.new()
	chat_in.max_length = 120
	chat_in.placeholder_text = "Say something · Enter sends · Esc closes"
	chat_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_in.text_submitted.connect(func(t: String): _send_chat(t))
	chat_in.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
			close_chat()
			chat_in.accept_event())
	var send := Button.new()
	send.text = "SEND"
	send.focus_mode = Control.FOCUS_NONE
	send.pressed.connect(func(): _send_chat(chat_in.text))
	send.set_meta("kind", "send")
	row.add_child(chat_in)
	row.add_child(send)
	var quick := HFlowContainer.new()
	for q in QUICK:
		var b := Button.new()
		b.text = q
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("kind", "quick")
		b.pressed.connect(func(): _send_chat(q))
		quick.add_child(b)
	vb.add_child(row)
	vb.add_child(quick)
	chat_bar.add_child(vb)
	add_child(chat_bar)
	rj_p = PanelContainer.new()
	rj_p.visible = false
	var rv := VBoxContainer.new()
	var rl := label("s8", 12, DIM, 0.14)
	rl.text = "NEXT LIFE AS"
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rl.set_meta("rj", true)
	var seg := PanelContainer.new()
	var hb := HBoxContainer.new()
	for cl in ["soldier", "sniper", "grenadier", "quartermaster"]:
		var b := Button.new()
		b.text = cl.to_upper()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 1.0
		b.clip_text = true
		b.pressed.connect(func(): _next_job(cl))
		rj_b[cl] = b
		hb.add_child(b)
	seg.add_child(hb)
	rv.add_child(rl)
	rv.add_child(seg)
	rj_p.add_child(rv)
	add_child(rj_p)
	sit_b = Button.new()
	sit_b.focus_mode = Control.FOCUS_NONE
	sit_b.visible = false
	sit_b.pressed.connect(func(): m.cas_sit())
	add_child(sit_b)


func _rest_style() -> void:
	for r in chat_ls:
		r.add_theme_font_override("normal_font", font("m4", 13))
		r.add_theme_font_size_override("normal_font_size", roundi(13 * s))
		r.add_theme_constant_override("line_separation", roundi(17.55 * s - UiKit.face("m4").get_height(roundi(13 * s))))
	var bar := _sb(Color(14 / 255.0, 12 / 255.0, 10 / 255.0, 0.92), WARN, 1)
	for k in ["left", "right", "top", "bottom"]:
		bar.set("content_margin_" + k, roundf(8 * s) + bar.border_width_left)
	chat_bar.add_theme_stylebox_override("panel", bar)
	var vb: VBoxContainer = chat_bar.get_child(0)
	vb.add_theme_constant_override("separation", roundi(6 * s))
	var row: HBoxContainer = vb.get_child(0)
	row.add_theme_constant_override("separation", roundi(6 * s))
	var flow: HFlowContainer = vb.get_child(1)
	flow.add_theme_constant_override("h_separation", roundi(5 * s))
	flow.add_theme_constant_override("v_separation", roundi(5 * s))
	var ib := _sb(Color("#0c0b09"), LINE, 1)
	ib.content_margin_left = roundf(10 * s) + ib.border_width_left
	ib.content_margin_right = roundf(10 * s) + ib.border_width_left
	for st in ["normal", "focus", "read_only"]:
		chat_in.add_theme_stylebox_override(st, ib)
	chat_in.add_theme_font_override("font", font("m6", 16))
	chat_in.add_theme_font_size_override("font_size", roundi(16 * s))
	chat_in.add_theme_color_override("font_color", BONE)
	chat_in.add_theme_color_override("font_placeholder_color", DIM)
	chat_in.custom_minimum_size.y = 40 * s
	for b in row.get_children() + flow.get_children():
		if not b is Button:
			continue
		if b.get_meta("kind") == "send":   # .go
			_style_btn(b, WARN, Color(0, 0, 0, 0), 0, "s9", 16, INK, 0.1, 0, WARN.lightened(0.12))
			b.custom_minimum_size = Vector2(0, 40 * s)
			for st in ["normal", "hover", "pressed", "focus", "disabled"]:
				var sb: StyleBoxFlat = b.get_theme_stylebox(st)
				sb.content_margin_left = roundf(14 * s)
				sb.content_margin_right = roundf(14 * s)
		else:
			_style_btn(b, Color(27 / 255.0, 24 / 255.0, 20 / 255.0, 0.9), LINE, 1, "s8", 13, BONE, 0.06, 0, Color(BTNBG.lightened(0.15), 0.9))
			# the browser's width (its letter-spacing exactly; Godot's rounds up a pixel a letter), the text centred in it
			b.add_theme_font_override("font", font("s8", 13))   # drawn without the rounded-up spacing, so it fits the browser's box
			b.clip_text = true
			b.custom_minimum_size = Vector2((_text_w("s8", b.text, 13) + 0.06 * 13 * b.text.length() + 20) * s, 30 * s)
			for st in ["normal", "hover", "pressed", "focus", "disabled"]:
				var sb: StyleBoxFlat = b.get_theme_stylebox(st)
				sb.content_margin_left = roundf(9 * s) + sb.border_width_left
				sb.content_margin_right = roundf(9 * s) + sb.border_width_left
	var rp := _sb(Color(12 / 255.0, 11 / 255.0, 9 / 255.0, 0.88), LINE, 1)
	rp.content_margin_left = roundf(12 * s) + rp.border_width_left
	rp.content_margin_right = roundf(12 * s) + rp.border_width_left
	rp.content_margin_top = roundf(10 * s) + rp.border_width_top
	rp.content_margin_bottom = roundf(10 * s) + rp.border_width_top
	rj_p.add_theme_stylebox_override("panel", rp)
	var rv: VBoxContainer = rj_p.get_child(0)
	rv.add_theme_constant_override("separation", roundi(6 * s))
	var rl: Label = rv.get_child(0)
	var rst: Array = rl.get_meta("st")
	rl.label_settings = ls(rst[0], rst[1], rst[2], rst[3], false, rst[4])
	var seg: PanelContainer = rv.get_child(1)
	seg.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0), LINE, 1))
	(seg.get_child(0) as HBoxContainer).add_theme_constant_override("separation", 0)
	_style_btn(sit_b, Color("#d6aa46"), Color(0, 0, 0, 0), 0, "s9", 22, INK, 0.1, 0, Color("#d6aa46").lightened(0.1))
	sit_b.custom_minimum_size = Vector2(140, 54) * s
	_sel_jobs("")


## the respawn picker's buttons: the picked one bone, the rest outlined (.seg)
func _sel_jobs(want: String) -> void:
	var first := true
	for cl in rj_b:
		var b: Button = rj_b[cl]
		var on: bool = cl == want
		var sb := _sb(BONE if on else Color(0, 0, 0, 0))
		if not first:   # border-left between them
			sb.border_color = LINE
			sb.border_width_left = int(maxf(1.0, roundf(s)))
		first = false
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_font_override("font", font("s8", 12, 0.06))
		b.add_theme_font_size_override("font_size", roundi(12 * s))
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(st, INK if on else DIM)
		b.custom_minimum_size = Vector2(0, 40 * s)
		b.set_meta("on", on)


## nextJob: the class for the next life in a Free-for-all (the host keeps it; a guest asks the host)
func _next_job(cls: String) -> void:
	var p: Dictionary = m.sim.player
	if m.sim.pvp() != "ffa":
		return
	if m.net.guest():
		m.net.send_next_class(cls)
	else:
		p.nextCls = "" if cls == p.cls else cls
	p.nextShow = cls


func open_chat() -> void:
	if not m.net.is_online() or m.demo:
		return
	chat_bar.visible = true
	chat_in.text = ""
	chat_in.grab_focus()
	chat_seen = m.net.chat.size()


func close_chat() -> void:
	chat_bar.visible = false
	chat_in.release_focus()


func toggle_chat() -> void:
	if chat_bar.visible:
		close_chat()
	else:
		open_chat()


func _send_chat(t: String) -> void:
	var text := t.strip_edges()
	if text != "" and m.net.is_online():
		m.net.send_chat(text.substr(0, 120))
	close_chat()


func _rest_update(_dt: float) -> void:
	var W := size.x / s
	var H := size.y / s
	var sim: Sim = m.sim
	var p: Dictionary = sim.player
	var city: bool = sim.map_id == "city" and sim.game.phase != "over"
	if city:
		var mb := bo_map_box()
		var M := Rect2(mb.position / s, mb.size / s)
		var tb := toast_box()
		var hit := tb.size.x > 0 and tb.intersects(M)
		bo_fade = clampf(bo_fade + (-1.0 if hit else 1.0) * _dt * 7.2, 0.0, 1.0)   # 0.12 a frame at 60
		map_c.modulate.a = bo_fade
	map_c.visible = city
	arrow_c.visible = city
	map_c.queue_redraw()
	arrow_c.queue_redraw()
	# the chat log: bottom left, 380 wide, eight lines at most, each fading out 9 s after it came (all back while typing)
	var online: bool = m.net.is_online() and m.net.in_game
	var lines: Array = m.net.chat.slice(maxi(0, m.net.chat.size() - 8)) if online else []
	var x0 := maxf(24, (W - 1632) / 2)
	var cw := minf(380, W * 0.58)
	var now := Time.get_ticks_msec()
	var y := H - 64
	for i in range(chat_ls.size() - 1, -1, -1):
		var r: RichTextLabel = chat_ls[i]
		var k := i - (chat_ls.size() - lines.size())
		r.visible = k >= 0
		if not r.visible:
			continue
		var l: Dictionary = lines[k]
		var col: Color = Color(l.col) if l.col is String else l.col
		var key := "%s|%s|%s|%s" % [l.id, l.name, l.text, s]
		if r.get_meta("key", "") != key:
			r.set_meta("key", key)
			r.clear()
			r.push_font(font("s8", 13, 0.05), roundi(13 * s))
			r.push_color(col)
			r.add_text(("YOU" if l.id == m.net.my_id else str(l.name).to_upper()) + " ")
			r.pop()
			r.pop()
			r.push_color(BONE)
			r.add_text(str(l.text))
			r.pop()
			var sb := _sb(Color(14 / 255.0, 12 / 255.0, 10 / 255.0, 0.72))
			sb.border_color = col
			sb.border_width_left = int(maxf(1.0, roundf(3 * s)))
			sb.content_margin_left = roundf(8 * s) + sb.border_width_left
			sb.content_margin_right = roundf(8 * s)
			sb.content_margin_top = roundf(3 * s)
			sb.content_margin_bottom = roundf(3 * s)
			r.add_theme_stylebox_override("normal", sb)
		r.size = Vector2(cw * s, 0)
		r.reset_size()
		r.size.x = cw * s
		var hh: float = r.get_combined_minimum_size().y / s
		y -= hh
		r.position = Vector2(x0, y) * s
		y -= 3
		var old: bool = now - int(l.get("at", now)) > 9000 and not chat_bar.visible
		r.modulate.a = move_toward(r.modulate.a, 0.0 if old else 1.0, _dt / 0.8)
	# the chat bar: top centre, 560 wide
	if chat_bar.visible:
		if not online:
			close_chat()
		var bw := minf(560, W - 24) + 18
		chat_bar.size = Vector2(bw * s, 0)
		chat_bar.reset_size()
		chat_bar.size.x = bw * s
		chat_bar.position = Vector2(roundf((W - bw) / 2), 12) * s
	# NEXT LIFE AS: down in a Free-for-all where the class isn't fixed
	var rj: bool = sim.pvp() == "ffa" and sim.game.get("job", "") == "" and not p.alive and sim.game.phase != "over"
	rj_p.visible = rj
	if rj:
		var want: String = str(p.get("nextShow", "")) if p.get("nextShow", "") != "" else (p.nextCls if p.get("nextCls", "") != "" else p.cls)
		if not rj_b[want].get_meta("on", false):
			_sel_jobs(want)
		var rw := minf(520, W - 24) + 26
		rj_p.size = Vector2(rw * s, 0)
		rj_p.reset_size()
		rj_p.size.x = rw * s
		rj_p.position = Vector2(roundf((W - rw) / 2), H - 22) * s - Vector2(0, rj_p.size.y)
	# SIT / PLAY / TABLE: the casino's seat button, on touch
	var sit := ""
	if sim.casino() and _touch() and p.alive:
		if p.get("seat", 0):
			if m.casino_ui != null and not m.casino_ui.is_open():
				sit = "MACHINE" if p.seat > 100 else "TABLE"
		else:
			var sn := CasinoView.seat_near(sim, p, m.casino_ui)
			if not sn.is_empty():
				sit = "PLAY" if sn.has("m") else "SIT"
	sit_b.visible = sit != ""
	if sit_b.visible:
		sit_b.text = sit
		sit_b.reset_size()
		sit_b.position = Vector2(roundf((W * s - sit_b.size.x) / 2), (H - 120) * s - sit_b.size.y)


const MAP_LOST := Color("#3a3a3a")   # the mini-map's marks: a POI lost, under attack (blinking), standing
const MAP_HIT := Color("#ff4a3a")
const MAP_HIT_DIM := Color("#8a2a20")
const MAP_POI := Color("#ffd88a")
const MAP_CROSS := Color("#777777")
const MAP_DESTROYER := Color("#ff6a2a")   # a boss (the Destroyer bigger and redder-orange), a crewmate, one down
const MAP_BOSS := Color("#ff3a2a")
const MAP_MATE := Color("#8fd0ff")
const MAP_DOWN := Color("#d65a3a")


## the Black Out mini-map (boMapDraw: POIs lit while held, red while attacked, dark once lost, the next one pulsing;
## bosses, the crew and you), fading under a banner that covers it; and the arrow to a POI under attack off screen
func _draw_bo() -> void:
	var sim: Sim = m.sim
	if sim.map_id != "city" or sim.game.phase == "over" or m.demo:
		return
	var mb := bo_map_box()
	var M := Rect2(mb.position / s, mb.size / s)
	var t: float = sim.game.time
	var c := map_c
	if bo_fade > 0:
		var n: int = sim.N
		var k := M.size.x / (2.0 * n)
		var P := func(i: float, j: float) -> Vector2: return Vector2(M.position.x + (i - j) * k + M.size.x / 2, M.position.y + (i + j) * k * 0.5) * s
		if m.city_map == null:
			m.city_map = CityView.map_image(sim)
		c.draw_set_transform_matrix(Transform2D(Vector2(k, k * 0.5) * s, Vector2(-k, k * 0.5) * s, (M.position + Vector2(M.size.x / 2, 0)) * s))
		c.draw_texture(m.city_map, Vector2.ZERO)
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
		var edge := PackedVector2Array([P.call(0, 0), P.call(n, 0), P.call(n, n), P.call(0, n), P.call(0, 0)])
		c.draw_polyline(edge, Color(226 / 255.0, 180 / 255.0, 54 / 255.0, 0.35), maxf(1.0, s))
		var blink := sin(t * 8) > 0
		for co in sim.cores:
			var q: Vector2 = P.call(co.i + 0.5, co.j + 0.5)
			if not co.has("poi"):
				var r := 4 * s
				c.draw_rect(Rect2(q - Vector2(r, r), Vector2(r, r) * 2), WARN)
				continue
			var r: float = (3.4 if co.poi.get("major", false) else 2.6) * s
			var col := MAP_LOST if co.lost else (MAP_HIT if blink else MAP_HIT_DIM) if co.get("attack", false) else MAP_POI
			c.draw_circle(q, r, col)
			if co.lost:
				c.draw_line(q - Vector2(r, r), q + Vector2(r, r), MAP_CROSS, maxf(1.0, s))
				c.draw_line(q + Vector2(r, -r), q + Vector2(-r, r), MAP_CROSS, maxf(1.0, s))
			if co.get("next", false) and not co.get("attack", false):
				c.draw_arc(q, r + 3 * s, 0, TAU, 24, Color(1, 120 / 255.0, 80 / 255.0, 0.5 + 0.5 * sin(t * 6)), 1.5 * s)
		for e in sim.enemies:
			if e.type == "boss":
				var q: Vector2 = P.call(e.x, e.y)
				var z := (5.0 if e.boss == "destroyer" else 3.5) * s
				c.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -z), q + Vector2(z, 0), q + Vector2(0, z), q + Vector2(-z, 0)]), MAP_DESTROYER if e.boss == "destroyer" else MAP_BOSS)
		for o in sim.players.values():
			if not is_same(o, sim.player) and (o.alive or o.get("downed", false)):
				c.draw_circle(P.call(o.x, o.y), 2 * s, MAP_MATE if o.alive else MAP_DOWN)
		var me: Vector2 = P.call(sim.player.x, sim.player.y)
		c.draw_circle(me, 2.6 * s + 1, Color.BLACK)
		c.draw_circle(me, 2.6 * s, Color.WHITE)


## a POI under attack off screen: a pulsing arrow at the edge, and its name
func _draw_poi_arrow() -> void:
	var sim: Sim = m.sim
	if sim.map_id != "city" or sim.game.phase == "over" or m.demo:
		return
	var t: float = sim.game.time
	var c := arrow_c
	for co in sim.cores:
		if not (co.get("attack", false) and co.has("poi")):
			continue
		var q: Vector2 = m.iso(co.i + 0.5, co.j + 0.5)
		var Wp := size.x
		var Hp := size.y
		var top := 110.0 * s
		if q.x > 20 and q.x < Wp - 20 and q.y > top and q.y < Hp - 20:
			break
		var ex := clampf(q.x, 26, Wp - 26)
		var ey := clampf(q.y, top + 14, Hp - 26)
		var a := atan2(q.y - Hp / 2, q.x - Wp / 2)
		var pz := (0.8 + 0.2 * sin(t * 6)) * 1.9
		var xf := Transform2D(a, Vector2(ex, ey)).scaled_local(Vector2(pz, pz))
		var arrow := PackedVector2Array()
		for v in [Vector2(9, 0), Vector2(-5, -7), Vector2(-2, 0), Vector2(-5, 7)]:
			arrow.append(xf * v)
		c.draw_colored_polygon(arrow, Color("#ff5a3a"))
		arrow.append(arrow[0])
		c.draw_polyline(arrow, Color(12 / 255.0, 10 / 255.0, 8 / 255.0, 0.8), 1.5)
		var f := font("s8", 10 * m.v.u / s)
		var z := roundi(10 * m.v.u)
		var nm: String = co.poi.name
		var w := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, z).x
		c.draw_string(f, Vector2(ex - w / 2, ey + (-20.0 if ey > Hp / 2 else 24.0)), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, z, Color("#ff8a6a"))
		break
