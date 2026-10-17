class_name LockerUI
extends Control
## The Locker (20-locker-ui.js): the equipped outfit on show, the case boxes (open one or five, buy with shards or
## three skill points), and tabs of every skin, headgear, tracer, kill effect, background and milestone ladder.
## Owned items equip on a click. Case openings play in CaseOpen.

const TABS := [["skin", "SKINS"], ["hat", "HEADGEAR"], ["trail", "TRACERS"], ["fx", "KILL FX"], ["bg", "BACKGROUNDS"], ["ms", "MILESTONES"]]
const THUMB_ANG := 0.55
const GOLD := Color("#e2b436")
const PAPER := Color("#e8dcc0")
const DIM := Color("#9a8f7a")

static var cat := "skin"
static var open_sections := {}

var menus
var m
var L: PalLocker
var grid: VBoxContainer
var scroll: ScrollContainer
var boxes: VBoxContainer
var msg: Label
var hint: Label
var shard_txt: Label
var tab_buttons := {}
var tiles: Array = []   # [Button, item]
var sp_armed := -10.0
var busy := false   # waiting for the account server


# ---------------------------------------------------------------- icons

## one item's picture, drawn once at its size (drawIcon)
class Icon extends Control:
	var c: Dictionary
	var eq: Dictionary
	var cls := "soldier"
	var pool: Array = []

	func _init(item: Dictionary, size_px: float, equipped: Dictionary, klass: String) -> void:
		c = item
		eq = equipped
		cls = klass
		custom_minimum_size = Vector2(size_px, size_px)
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _exit_tree() -> void:
		Ctx2D.free_pool(pool)

	func _draw() -> void:
		LockerUI.paint_icon(self, c, size.x, eq, cls, pool)


static func paint_icon(ci: CanvasItem, c: Dictionary, S: float, eq: Dictionary, cls: String, pool: Array) -> void:
	var dark := Color("#0c0b09")
	match String(c.cat):
		"skin", "hat":
			var skin_id: String = c.key if c.cat == "skin" else (eq.get("skin", "std") if Wardrobe.headwear_allowed(eq.get("skin", "std"), c.key) else "std")
			var look := Wardrobe.look_for({"skin": skin_id, "hat": eq.get("hat", "class") if c.cat == "skin" else c.key}, cls)
			var f := Wardrobe.frame(look, THUMB_ANG, c.cat)
			var pad := (1.32 if look.get("sahur") else 1.18) if c.cat == "hat" else 1.1
			var sc: float = S / (f.s * pad)
			var ox: float = S / 2 - f.cx * sc
			var oy: float = S / 2 - f.cy * sc
			var aura = look.get("aura") if c.cat == "skin" else null
			if aura:
				CosFx.paint_aura(ci, aura, ox, oy, sc, 1.3, 1, "ground")
			Wardrobe.draw(ci, look, THUMB_ANG, 0, sc, ox, oy, false)
			if aura:
				CosFx.paint_aura(ci, aura, ox, oy, sc, 1.3, 1, "top")
		"bg":   # painted wide (16:9, like a screen) and cropped to the middle
			var w := roundf(S * 16 / 9)
			var x := Ctx2D.new(ci).layered(pool)
			x.translate(-(w - S) / 2, 0)
			Backgrounds.draw(x, c.key, w, S, 3)
		"trail":
			ci.draw_rect(Rect2(0, 0, S, S), dark)
			var x := Ctx2D.new(ci)
			var st := CosArt.trail(c.key)
			var cyc: Array = st.get("cycle", [])
			if not cyc.is_empty():
				for k in mini(3, cyc.size()):
					CosArt.paint_tracer(x, S * (0.12 + k * 0.27), S * 0.72, S * (0.28 + k * 0.27), S * 0.33, c.key, S * 0.04, 0, false, k)
			else:
				for k in 2:
					CosArt.paint_tracer(x, S * (0.2 + k * 0.2), S * (0.8 - k * 0.12), S * (0.62 + k * 0.2), S * (0.3 - k * 0.12), c.key, S * 0.05 * st.get("w", 1.0), k * 0.4)
		_:
			ci.draw_rect(Rect2(0, 0, S, S), dark)
			if c.key == "none":
				ci.draw_arc(Vector2(S / 2, S / 2), S * 0.2, 0, TAU, 32, Color("#6e7568"), S * 0.025, true)
				ci.draw_line(Vector2(S * 0.36, S * 0.64), Vector2(S * 0.64, S * 0.36), Color("#6e7568"), S * 0.025, true)
			else:
				CosArt.paint_finish(Ctx2D.new(ci), c.key, 0.3, S / 92, S / 2, S * 0.58)


## a small crate in the case's colour (drawCaseIcon), centred at (cx, cy), S across
static func paint_case(x: Ctx2D, id: String, cx: float, cy: float, S: float) -> void:
	var C: Dictionary = PalLocker.catalog().CASES.get(id, PalLocker.catalog().CASES.supply)
	x.save()
	x.translate(cx, cy + S * 0.06)
	x.scale(S / 100, S / 100)
	var face := func(pts: Array, col) -> void:
		x.begin_path()
		for i in pts.size():
			if i:
				x.line_to(pts[i][0], pts[i][1])
			else:
				x.move_to(pts[i][0], pts[i][1])
		x.close_path()
		x.fill_style = col
		x.fill()
		x.stroke_style = "#0b0a08"
		x.line_width = 2.4
		x.stroke()
	face.call([[-34, -12], [0, -28], [34, -12], [0, 4]], CosArt.mix(C.col, "#ffffff", 0.18))
	face.call([[-34, -12], [0, 4], [0, 38], [-34, 22]], CosArt.mix(C.col, "#000000", 0.28))
	face.call([[0, 4], [34, -12], [34, 22], [0, 38]], CosArt.mix(C.col, "#000000", 0.45))
	x.stroke_style = "#1a1510"
	x.line_width = 3
	x.begin_path()
	x.move_to(-17, -4)
	x.line_to(-17, 30)
	x.move_to(17, -4)
	x.line_to(17, 30)
	x.stroke()
	x.fill_style = "#f3e9d6"
	x.begin_path()
	x.arc(0, -12, 4, 0, TAU)
	x.fill()
	x.restore()


class CaseIcon extends Control:
	var id := ""

	func _init(case_id: String, size_px: float) -> void:
		id = case_id
		custom_minimum_size = Vector2(size_px, size_px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		LockerUI.paint_case(Ctx2D.new(self), id, size.x / 2, size.y / 2, size.x)


## the lobby background behind the menus, moving at 30 fps when it moves
class BgView extends Control:
	var pool: Array = []
	var id := ""
	var t0 := 0.0
	var acc := 0.0

	func _init(bg_id: String) -> void:
		id = bg_id
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		t0 = Time.get_ticks_msec() / 1000.0

	func _exit_tree() -> void:
		Ctx2D.free_pool(pool)

	func _process(dt: float) -> void:
		if Backgrounds.is_still(id) or PalSettings.reduce_motion:
			return
		acc += dt
		if acc >= 1.0 / 30:
			acc = 0.0
			queue_redraw()

	func _draw() -> void:
		Backgrounds.draw(Ctx2D.new(self).layered(pool), id, size.x, size.y, Time.get_ticks_msec() / 1000.0 - t0)


## the equipped outfit, turning slowly, with its outfit effect
class Preview extends Control:
	var ui

	func _init(owner_ui) -> void:
		ui = owner_ui
		custom_minimum_size = Vector2(220, 240)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var look := Wardrobe.look_for(ui.L.eq, ui.cls())
		var sc := minf(size.x / 34.0, size.y / 52.0)
		var ox := size.x / 2
		var oy := size.y - 14 * sc
		var ang := THUMB_ANG + sin(t * 0.5) * 0.9
		if look.get("aura"):
			CosFx.paint_aura(self, look.aura, ox, oy, sc, t, 1, "ground")
		Wardrobe.draw(self, look, ang, t, sc, ox, oy, false)
		if look.get("aura"):
			CosFx.paint_aura(self, look.aura, ox, oy, sc, t, 1, "top")


# ---------------------------------------------------------------- the screen

func _init(menus_node) -> void:
	menus = menus_node
	m = menus.m
	L = m.locker
	set_anchors_preset(Control.PRESET_FULL_RECT)


func cls() -> String:
	return m.settings.data.setup.get("cls", "soldier")


func _lbl(text: String, size_px: int = 15, col: Color = PAPER, wrap: bool = false) -> Label:
	return menus._label(text, size_px, col, wrap)


func _ready() -> void:
	var W: float = m.v.W
	var H: float = m.v.H
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, 12 if W < 760 else 22)
	add_child(outer)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)
	outer.add_child(main)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	main.add_child(top)
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(func(): menus.show_main())
	top.add_child(back)
	top.add_child(_lbl("LOCKER", 28, GOLD))
	shard_txt = _lbl("", 13, DIM)
	shard_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shard_txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(shard_txt)
	var body: BoxContainer = HBoxContainer.new() if W >= 760 else VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	main.add_child(body)
	# left: the outfit and the cases
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(clampf(W * 0.3, 240, 340) if W >= 760 else 0, 0)
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)
	if W >= 760:
		var pv := Preview.new(self)
		pv.custom_minimum_size = Vector2(0, clampf(H * 0.34, 160, 300))
		left.add_child(pv)
	var cs := ScrollContainer.new()
	cs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cs.custom_minimum_size = Vector2(0, 120)
	left.add_child(cs)
	boxes = VBoxContainer.new()
	boxes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boxes.add_theme_constant_override("separation", 6)
	cs.add_child(boxes)
	# right: tabs and the items
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 2.4
	body.add_child(right)
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	right.add_child(tabs)
	for tdef in TABS:
		var b := Button.new()
		b.text = tdef[1]
		b.toggle_mode = true
		var id: String = tdef[0]
		b.pressed.connect(func():
			cat = id
			_render_grid())
		tabs.add_child(b)
		tab_buttons[id] = b
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	right.add_child(scroll)
	grid = VBoxContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("separation", 8)
	scroll.add_child(grid)
	msg = _lbl("", 13, Color("#ff9a6a"), true)
	right.add_child(msg)
	hint = _lbl("", 12, DIM, true)
	right.add_child(hint)
	render()
	await get_tree().process_frame
	if tab_buttons.has(cat):
		tab_buttons[cat].grab_focus()


func render() -> void:
	_render_boxes()
	_render_grid()


## one panel per case: how many you hold, OPEN, OPEN 5, and BUY where it has a price (renderCaseBoxes)
func _render_boxes() -> void:
	for ch in boxes.get_children():
		ch.queue_free()
	var C: Dictionary = PalLocker.catalog().CASES
	var ids: Array = C.keys()
	ids.sort_custom(func(a, b): return int(L.case_count(a) > 0) > int(L.case_count(b) > 0))
	for id in ids:
		var D: Dictionary = C[id]
		var n := L.case_count(id)
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(14 / 255.0, 12 / 255.0, 10 / 255.0, 0.88)
		sb.border_color = Color(D.col) if n > 0 else Color(D.col).darkened(0.55)
		sb.set_border_width_all(1)
		sb.border_width_left = 4
		sb.set_content_margin_all(8)
		pc.add_theme_stylebox_override("panel", sb)
		boxes.add_child(pc)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		pc.add_child(v)
		var head := HBoxContainer.new()
		v.add_child(head)
		if n > 0:
			head.add_child(CaseIcon.new(id, 34))
		var nm := _lbl(D.name, 14, Color(D.col) if n > 0 else DIM)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head.add_child(nm)
		head.add_child(_lbl(str(n), 22 if n > 0 else 15, PAPER if n > 0 else DIM))
		var how := _lbl(D.how, 11, DIM, true)
		how.custom_minimum_size = Vector2(150, 0)
		v.add_child(how)
		var bt := HFlowContainer.new()
		bt.add_theme_constant_override("h_separation", 6)
		bt.add_theme_constant_override("v_separation", 6)
		v.add_child(bt)
		var op: Button = menus._button("OPEN", func(): open_cases(id, 1), bt)
		op.disabled = n < 1
		var five: Button = menus._button("OPEN 5", func(): open_cases(id, 5), bt)
		five.disabled = n < 5
		if not L.cloud.is_empty() and L.account != null and L.account.pending_opening().get("case") == id:
			menus._button("RESUME OPENING", func(): resume_opening(), bt)
		if D.get("cost") != null:
			var buy: Button = menus._button("BUY · %d SHARDS" % int(D.cost), func():
				_buy(id), bt)
			buy.disabled = L.shards < int(D.cost)
		if id == "supply":
			var sp: int = m.profile.sp
			var armed := Time.get_ticks_msec() / 1000.0 - sp_armed < 3
			var sb2: Button = menus._button(("TAP AGAIN · SPEND %d SKILL POINTS" % PalLocker.SP_CASE) if armed else ("BUY · %d SKILL POINTS (%d)" % [PalLocker.SP_CASE, sp]), func(): _buy_sp(), bt)
			sb2.disabled = sp < PalLocker.SP_CASE
			sb2.tooltip_text = "You have %d skill point%s. Earn them by holding raids (1 per 5) and beating bosses." % [sp, "" if sp == 1 else "s"] if sp < PalLocker.SP_CASE else "Trade %d unspent skill points for a Supply Case" % PalLocker.SP_CASE
	shard_txt.text = "%d shard%s · duplicates and leftover run salvage turn into shards" % [L.shards, "" if L.shards == 1 else "s"]
	var st: Dictionary = L.st
	hint.text = "Earn a supply case every 3 raids you survive and for every win. Duplicates turn into shards. So far: %d raids held, %d win%s, %d raiders dropped." % [st.get("raids", 0), st.get("wins", 0), "" if st.get("wins", 0) == 1 else "s", st.get("drops", 0)]


## 3 unspent skill points buy a Supply Case; the first press arms it for 3 s
func _buy_sp() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - sp_armed >= 3:
		sp_armed = now
		_render_boxes()
		get_tree().create_timer(3.05).timeout.connect(func():
			if is_instance_valid(self) and Time.get_ticks_msec() / 1000.0 - sp_armed >= 3:
				_render_boxes())
		return
	sp_armed = -10.0
	if not L.cloud.is_empty():
		_wait(true)
		var e: String = await L.account.buy_case_sp()
		_wait(false)
		if e == "":
			m.audio.play("restock")
		msg.text = e
	elif L.buy_case_sp():
		m.audio.play("restock")
	render()


func _buy(id: String) -> void:
	if not L.cloud.is_empty():
		_wait(true)
		var e: String = await L.account.buy_case(id)
		_wait(false)
		if e == "":
			m.audio.play("restock")
		msg.text = e
	elif L.buy_case(id):
		m.audio.play("restock")
	render()


func _wait(on: bool) -> void:
	busy = on
	msg.text = "Talking to the quartermaster…" if on else ""


func _section(title: String, sub: String = "") -> void:
	var h := HBoxContainer.new()
	h.add_child(_lbl(title, 13, GOLD))
	if sub != "":
		var s := _lbl(sub, 11, DIM)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(s)
	grid.add_child(h)


func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 8)
	grid.add_child(f)
	return f


func _render_grid() -> void:
	for b in tab_buttons:
		tab_buttons[b].button_pressed = b == cat
	for ch in grid.get_children():
		grid.remove_child(ch)
		ch.queue_free()
	tiles.clear()
	var C := PalLocker.catalog()
	if cat == "ms":   # one strip per ladder: its unlocks side by side
		for Ld in C.LADDERS:
			var got := 0
			for it in Ld.items:
				if L.owns(it[0] + ":" + it[1]):
					got += 1
			var sub := ""
			if Ld.get("sts"):
				sub = "%d points held · %d win%s · %d Destroyer%s · %d / %d unlocked" % [L.st.get("bo_pois", 0), L.st.get("bo_wins", 0), "" if L.st.get("bo_wins", 0) == 1 else "s", L.st.get("bo_dest", 0), "" if L.st.get("bo_dest", 0) == 1 else "s", got, Ld.items.size()]
			else:
				sub = "%d %s · %d / %d unlocked" % [L.st.get(Ld.st, 0), Ld.unit, got, Ld.items.size()]
			_section(Ld.title, sub)
			var row := _flow()
			for it in Ld.items:
				var c := PalLocker.item(it[0] + ":" + it[1])
				if not c.is_empty():
					row.add_child(_tile(c))
		return
	var items: Array = C.COS.filter(func(c): return c.cat == cat and not c.get("ladder"))
	var plain: Array = items.filter(func(c): return not c.get("box"))
	if not plain.is_empty():
		_section("STANDARD & UNLOCKS")
		var row := _flow()
		for c in plain:
			row.add_child(_tile(c))
	for id in C.CASES:
		var group: Array = items.filter(func(c): return c.get("box") == id)
		if group.is_empty():
			continue
		var key: String = cat + ":" + id
		var own := group.filter(func(c): return L.owns(c.id)).size()
		var is_open: bool = open_sections.get(key, false)
		var tb := Button.new()
		tb.text = "%s   %d / %d owned   %s" % [C.CASES[id].name, own, group.size(), "−" if is_open else "+"]
		tb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tb.add_theme_color_override("font_color", Color(C.CASES[id].col))
		tb.pressed.connect(func():
			open_sections[key] = not open_sections.get(key, false)
			var y := scroll.scroll_vertical
			_render_grid()
			scroll.scroll_vertical = y)
		grid.add_child(tb)
		if is_open:
			var row := _flow()
			for c in group:
				row.add_child(_tile(c))


## an item's tile: its picture, name, and what it is to you (equipped, rarity, or how to get it)
func _tile(c: Dictionary) -> Button:
	var R: Dictionary = PalLocker.catalog().RAR[c.r]
	var own := L.owns(c.id)
	var blocked: bool = c.cat == "hat" and not Wardrobe.headwear_allowed(L.eq.get("skin", "std"), c.key)
	var eq: bool = not blocked and (L.eq.get(c.cat) == c.key or (c.cat == "hat" and c.key == "class" and not Wardrobe.headwear_allowed(L.eq.get("skin", "std"), L.eq.get("hat", "class"))))
	var b := Button.new()
	b.custom_minimum_size = Vector2(116, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(14 / 255.0, 12 / 255.0, 10 / 255.0, 0.9)
	sb.border_color = GOLD if eq else Color(R.col)
	sb.set_border_width_all(3 if eq else 1)
	sb.border_width_bottom = 3
	sb.set_content_margin_all(6)
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Color(40 / 255.0, 34 / 255.0, 26 / 255.0, 0.95)
	sbh.border_color = PAPER
	for st in ["hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sbh)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var ic := Icon.new(c, 104, L.eq.duplicate(), cls())
	ic.modulate = Color(1, 1, 1, 1.0 if own else 0.45)
	v.add_child(ic)
	var nm := _lbl(c.name, 12, PAPER if own else DIM)
	nm.custom_minimum_size = Vector2(104, 0)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var status: String = "DOES NOT FIT THIS SKIN" if blocked else ("EQUIPPED" if eq else (R.n if own else c.get("how", "")))
	var sl := _lbl(status, 10, GOLD if eq else (Color(R.col) if own else DIM))
	sl.custom_minimum_size = Vector2(104, 0)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)
	if not own and c.src == "unlock" and c.get("need") is Dictionary and not c.need.is_empty():
		var k: String = c.need.keys()[0]
		var need := int(c.need[k])
		var have := mini(need, int(L.st.get(k, 0)))
		var pb := ProgressBar.new()
		pb.max_value = need
		pb.value = have
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(104, 6)
		v.add_child(pb)
		v.add_child(_lbl("%d / %d" % [have, need], 10, DIM))
	if c.get("description"):
		b.tooltip_text = c.description
	b.pressed.connect(func(): _equip(c))
	b.custom_minimum_size.y = v.get_combined_minimum_size().y + 12
	b.resized.connect(func(): v.size = b.size - Vector2(12, 12), CONNECT_DEFERRED)
	v.position = Vector2(6, 6)
	tiles.append([b, c])
	return b


func _equip(c: Dictionary) -> void:
	if not L.owns(c.id):
		msg.text = "%s: %s" % [c.name, c.get("how", "not owned yet")]
		return
	if c.cat == "hat" and not Wardrobe.headwear_allowed(L.eq.get("skin", "std"), c.key):
		msg.text = "HEADGEAR DOES NOT FIT · Choose a skin with a standard head shape."
		return
	msg.text = ""
	L.equip(c.id)
	if not L.cloud.is_empty():
		L.account.equip(c.id)
	m.audio.play("place0")
	if c.cat == "bg":
		menus.refresh_bg()
	var y := scroll.scroll_vertical
	_render_grid()
	scroll.scroll_vertical = y


func open_cases(id: String, n: int) -> void:
	if L.case_count(id) < n or busy:
		return
	if not L.cloud.is_empty():
		if not L.account.pending_opening().is_empty():
			msg.text = "Resume the saved opening before starting another."
			return
		_cloud_open(id, n, {})
		return
	var results: Array = []
	for i in n:   # the rewards are in the locker before the animation starts
		var r := L.open_case(id)
		if not r.is_empty():
			r.shards = int(PalLocker.catalog().RAR[r.it.r].sh) if r.dup else 0
			results.append(r)
	if results.is_empty():
		return
	var ov := CaseOpen.new(self, id, results)
	add_child(ov)


## an account's opening: the crate shakes while the server rolls; an answer that never came back stays saved
func _cloud_open(id: String, n: int, resume: Dictionary) -> void:
	busy = true
	var ov := CaseOpen.new(self, id, [])
	add_child(ov)
	var res: Dictionary = await L.account.open_cases(id, n, resume)
	busy = false
	if not is_instance_valid(ov):
		return
	if res.ok:
		ov.set_results(res.results)
	else:
		ov.fail(res.err, res.uncertain)


func resume_opening() -> void:
	var p: Dictionary = L.account.pending_opening()
	if not p.is_empty() and not busy:
		_cloud_open(p.case, int(p.quantity), p)


## after an opening closes: the counts and tiles change
func refresh() -> void:
	var y := scroll.scroll_vertical
	render()
	scroll.scroll_vertical = y
