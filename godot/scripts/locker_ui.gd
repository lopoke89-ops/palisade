class_name LockerUI
extends Control
## The Locker (20-locker-ui.js), laid out as the browser's desktop lobby page: the case boxes on the left (open one or
## five, buy with shards or three skill points), your kit on the stage in the middle, and on the right the tabs of every
## skin, headgear, tracer, kill effect, background and milestone ladder. Owned items equip on a click. Case openings
## play in CaseOpen.

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

	var three: Preview3D   # the 3D model, when the model library is in this build

	func _ready() -> void:
		if Lobby3D.available():
			three = Preview3D.new()
			add_child(three)

	func _process(_dt: float) -> void:
		if three != null:
			three.show_outfit(ui.cls(), ui.L.eq)
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
		if three == null:   # the painted figure when the 3D models aren't in this build
			Wardrobe.draw(self, look, ang, t, sc, ox, oy, false)
		if look.get("aura") and three == null:
			CosFx.paint_aura(self, look.aura, ox, oy, sc, t, 1, "top")


## the Locker's outfit in 3D: the dressed model (class, skin, headgear, the class's weapon), turning slowly
class Preview3D extends SubViewportContainer:
	var vp: SubViewport
	var pivot: Node3D
	var model: Node3D
	var key := ""

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		stretch = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		vp = SubViewport.new()
		vp.transparent_bg = true
		vp.own_world_3d = true
		vp.msaa_3d = Viewport.MSAA_4X
		add_child(vp)
		var cam := Camera3D.new()
		cam.fov = 30
		vp.add_child(cam)
		cam.look_at_from_position(Vector3(0, 1.15, 4.6), Vector3(0, 0.95, 0))
		var we := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_CLEAR_COLOR
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.66, 0.64, 0.66)
		we.environment = e
		vp.add_child(we)
		var key_l := DirectionalLight3D.new()
		key_l.rotation_degrees = Vector3(-35, 30, 0)
		key_l.light_energy = 1.1
		vp.add_child(key_l)
		var rim := DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-15, 200, 0)
		rim.light_energy = 0.6
		vp.add_child(rim)
		pivot = Node3D.new()
		vp.add_child(pivot)

	func show_outfit(cls: String, eq: Dictionary) -> void:
		var k := "%s|%s|%s" % [cls, eq.get("skin", "std"), eq.get("hat", "class")]
		if k != key:
			key = k
			if model != null:
				pivot.remove_child(model)
				model.queue_free()
			model = ArtLibrary.get_lib().build(cls, eq)
			if model != null:
				pivot.add_child(model)
		var t := Time.get_ticks_msec() / 1000.0
		pivot.rotation.y = -0.45 + (0.0 if PalSettings.reduce_motion else sin(t * 0.5) * 0.9)


# ---------------------------------------------------------------- the screen

func _init(menus_node) -> void:
	menus = menus_node
	m = menus.m
	L = m.locker
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func cls() -> String:
	return m.settings.data.setup.get("cls", "soldier")


func _lbl(text: String, size_px: int = 15, col: Color = PAPER, wrap: bool = false) -> Label:
	return menus._label(text, size_px, col, wrap)


func _l(text: String, f: String, size: float, col: Color, em: float = 0.0, lh: float = 0.0, wrap: bool = false) -> Label:
	return UiKit.lbl(text, f, size, col, em, lh, wrap)


## The Locker in the lobby shell (#menu[data-page=locker]): the cases on the left, your kit on the stage in the
## middle, the tabs and the items on the right
func _ready() -> void:
	var row := UiKit.hbox(18)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(row)
	# left: the cases
	var lp: Array = menus._side_panel(280)
	row.add_child(lp[0])
	var col: VBoxContainer = lp[1]
	col.add_child(menus._pt("LOCKER"))
	boxes = UiKit.vbox(8)
	col.add_child(boxes)
	shard_txt = _l("", "m4", 10, UiKit.DIM, 0.0, 1.4, true)
	col.add_child(shard_txt)
	msg = _l("", "m4", 12, UiKit.WARN, 0.0, 1.5, true)
	col.add_child(msg)
	hint = _l("", "m4", 11, UiKit.DIM, 0.0, 1.55, true)
	col.add_child(hint)
	# the middle: your kit
	var eq: Dictionary = L.eq
	var nm := func(c: String, k: String) -> String: return str(PalLocker.item(c + ":" + k).get("name", k))
	var trail: String = nm.call("trail", eq.get("trail", "std"))
	var sub := "%s · %s · %s%s · %s" % [nm.call("skin", eq.get("skin", "std")), nm.call("hat", eq.get("hat", "class")), trail, "" if trail.to_lower().contains("tracer") else " tracer", nm.call("fx", eq.get("fx", "none"))]
	row.add_child(menus._stage_column("LOCKER", "YOUR KIT", sub, [], menus.my_name(), "EQUIPPED", "Tap an item you own to wear it."))
	# right: the tabs and the items
	var rp := UiKit.panel(UiKit.PANEL, UiKit.PLINE, 1, 14)
	rp.custom_minimum_size.x = UiKit.px(520)
	rp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(rp)
	var rv := UiKit.vbox(10)
	rp.add_child(rv)
	tab_holder = UiKit.vbox(0)
	rv.add_child(tab_holder)
	grid = UiKit.vbox(8)
	scroll = UiKit.scroller(grid)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(scroll)
	render()


var tab_holder: VBoxContainer


func render() -> void:
	_render_boxes()
	_render_grid()


func _render_tabs() -> void:
	for ch in tab_holder.get_children():
		tab_holder.remove_child(ch)
		ch.queue_free()
	var sg := UiKit.seg(TABS, cat, func(id):
		cat = id
		_render_grid()
		menus._refocus("ltab:" + id), {"cols": 3, "size": 12, "em": 0.04, "h": 44, "tabs": true})
	for b in sg.get_child(0).get_children():
		for t in TABS:
			if t[1] == b.text:
				menus._fid(b, "ltab:" + t[0])
				tab_buttons[t[0]] = b
				if t[0] == cat and menus._focus == null:
					menus._focus = b
	tab_holder.add_child(sg)


## one panel per case: how many you hold, OPEN, OPEN 5, and BUY where it has a price (renderCaseBoxes)
func _render_boxes() -> void:
	for ch in boxes.get_children():
		boxes.remove_child(ch)
		ch.queue_free()
	var C: Dictionary = PalLocker.catalog().CASES
	var ids: Array = C.keys()
	ids.sort_custom(func(a, b): return int(L.case_count(a) > 0) > int(L.case_count(b) > 0))
	for id in ids:
		var D: Dictionary = C[id]
		var n := L.case_count(id)
		var empty := n < 1
		var cc := Color(D.col)
		var p := UiKit.panel(Color(20 / 255.0, 20 / 255.0, 19 / 255.0, 0.55) if empty else Color(27 / 255.0, 24 / 255.0, 20 / 255.0, 0.7), UiKit.LINE, [1, 1, 1, 3], [6, 8, 6, 8] if empty else [7, 8, 7, 8])
		var s: StyleBoxFlat = p.get_theme_stylebox("panel")
		s.border_color = UiKit.LINE
		var edge := ColorRect.new()
		edge.color = cc
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boxes.add_child(p)
		var v := UiKit.vbox(4)
		p.add_child(v)
		var head := UiKit.hbox(8)
		var nl := _l(D.name, "s8", 13, cc, 0.1)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head.add_child(nl)
		head.add_child(_l(str(n), "m6", 15 if empty else 20, UiKit.DIM if empty else UiKit.BONE))
		v.add_child(head)
		var how := _l(D.how, "m4", 10.5, UiKit.DIM, 0.0, 1.35, not empty)
		if empty:
			how.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			how.clip_text = true
			how.custom_minimum_size.x = UiKit.px(40)
		v.add_child(how)
		var bt := UiKit.hbox(6)
		v.add_child(bt)
		var h := 32 if empty else 36
		var fsz := 12.0 if empty else 14.0
		var go_box := _go_box()
		if not empty:
			var op := UiKit.btn("OPEN", "go", fsz, func(): open_cases(id, 1), {"h": h, "box": go_box, "pad": [0, 10, 0, 10]})
			op.disabled = busy
			menus._fid(op, "open:" + id)
			bt.add_child(UiKit.expand(op))
		var five := UiKit.btn("OPEN 5", "go", fsz, func(): open_cases(id, 5), {"h": h, "box": go_box, "pad": [0, 10, 0, 10]})
		five.disabled = n < 5 or busy
		menus._fid(five, "open5:" + id)
		bt.add_child(five if empty else UiKit.expand(five))
		if not L.cloud.is_empty() and L.account != null and L.account.pending_opening().get("case") == id:
			bt.add_child(UiKit.btn("RESUME OPENING", "ghost", fsz, func(): resume_opening(), {"h": h}))
		if D.get("cost") != null:
			var buy := UiKit.btn("BUY · %d SHARDS" % int(D.cost), "ghost", fsz, func(): _buy(id), {"h": h, "pad": [0, 12, 0, 12]})
			buy.disabled = L.shards < int(D.cost) or busy
			menus._fid(buy, "buy:" + id)
			bt.add_child(buy if empty else UiKit.expand(buy))
		if id == "supply":
			var sp: int = m.profile.sp
			var armed := Time.get_ticks_msec() / 1000.0 - sp_armed < 3
			var sb2 := UiKit.btn(("TAP AGAIN · SPEND %d SKILL POINTS" % PalLocker.SP_CASE) if armed else ("BUY · %d SKILL POINTS (%d)" % [PalLocker.SP_CASE, sp]), "ghost", fsz, func(): _buy_sp(), {"h": h, "pad": [2, 6, 2, 6]})
			sb2.label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sb2.label.custom_minimum_size.x = UiKit.px(50)
			sb2.disabled = sp < PalLocker.SP_CASE or busy
			sb2.tooltip_text = "You have %d skill point%s. Earn them by holding raids (1 per 5) and beating bosses." % [sp, "" if sp == 1 else "s"] if sp < PalLocker.SP_CASE else "Trade %d unspent skill points for a Supply Case" % PalLocker.SP_CASE
			menus._fid(sb2, "buysp")
			bt.add_child(sb2 if empty else UiKit.expand(sb2))
		# the case's colour down the left edge
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(holder)
		holder.add_child(edge)
		p.resized.connect(func():
			edge.position = Vector2(-s.content_margin_left, -s.content_margin_top)
			edge.size = Vector2(UiKit.bw(3), p.size.y))
	shard_txt.text = "%d shard%s · duplicates and leftover run salvage turn into shards" % [L.shards, "" if L.shards == 1 else "s"]
	var st: Dictionary = L.st
	hint.text = "Earn a supply case every 3 raids you survive and for every win. Duplicates turn into shards. So far: %d raids held, %d win%s, %d raiders dropped." % [st.get("raids", 0), st.get("wins", 0), "" if st.get("wins", 0) == 1 else "s", st.get("drops", 0)]


## the locker's yellow buttons stay yellow when they can't be pressed (as the browser's do)
func _go_box() -> Dictionary:
	var K := UiKit.kind("go")
	var box: Dictionary = K.box.duplicate()
	box.disabled = UiKit.sb(Color(UiKit.WARN, 0.75))
	return box


## 3 unspent skill points buy a Supply Case; the first press arms it for 3 s
func _buy_sp() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - sp_armed >= 3:
		sp_armed = now
		_render_boxes()
		menus._refocus("buysp")
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
	menus._refocus("buy:" + id)


func _wait(on: bool) -> void:
	busy = on
	msg.text = "Talking to the quartermaster…" if on else ""


## .gsec: a section heading over the tiles, with a line under it
func _section(title: String, sub: String = "", col: Color = UiKit.DIM) -> void:
	var v := UiKit.vbox(2)
	v.add_child(UiKit.spacer(4))
	var h := UiKit.hbox(8)
	h.add_child(_l(title, "s8", 12, col, 0.14))
	if sub != "":
		var s := _l(sub, "m6", 10, UiKit.DIM, 0.04)
		s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(s)
	v.add_child(h)
	v.add_child(UiKit.spacer(1))
	v.add_child(UiKit.rule())
	grid.add_child(v)


func _flow() -> GridContainer:
	var g := UiKit.grid(4, 8)
	grid.add_child(g)
	return g


func _render_grid() -> void:
	_render_tabs()
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
			var v := UiKit.vbox(2)
			v.add_child(UiKit.spacer(4))
			v.add_child(_l(Ld.title, "s8", 12, UiKit.DIM, 0.14))
			v.add_child(_l("  " + sub, "m6", 10, UiKit.DIM, 0.04))
			grid.add_child(v)
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
		grid.add_child(_collection(id, group))


## .lockerCollection: a case's items, folded under its name until opened
func _collection(id: String, group: Array) -> Control:
	var C := PalLocker.catalog()
	var cc := Color(C.CASES[id].col)
	var key: String = cat + ":" + id
	var own := group.filter(func(c): return L.owns(c.id)).size()
	var is_open: bool = open_sections.get(key, false)
	var p := UiKit.panel(Color(6 / 255.0, 15 / 255.0, 23 / 255.0, 0.5), UiKit.LINE, [1, 1, 1, 3], 0)
	var edge := ColorRect.new()
	edge.color = cc
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UiKit.vbox(0)
	p.add_child(v)
	var h := UiKit.hbox(10)
	var tv := UiKit.vbox(4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(_l(C.CASES[id].name, "s8", 16, cc, 0.06))
	tv.add_child(_l("%d / %d owned" % [own, group.size()], "m4", 10, UiKit.DIM, 0.02))
	h.add_child(tv)
	var ar := _l("−" if is_open else "+", "m4", 24, cc)
	ar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(ar)
	var pad := [10, 12, 10, 12]
	var box := {"normal": UiKit.sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, pad), "hover": UiKit.sb(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, pad),
		"pressed": UiKit.sb(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 0, pad), "disabled": UiKit.sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, pad)}
	var tb := UiKit.card_btn(h, box, func():
		open_sections[key] = not open_sections.get(key, false)
		var y := scroll.scroll_vertical
		_render_grid()
		scroll.scroll_vertical = y
		menus._refocus("coll:" + key))
	tb.custom_minimum_size.y = UiKit.px(52)
	menus._fid(tb, "coll:" + key)
	v.add_child(tb)
	if is_open:
		v.add_child(UiKit.rule())
		var mc := UiKit.margin(8, 8, 8, 8)
		var g := UiKit.grid(4, 8)
		mc.add_child(g)
		v.add_child(mc)
		for c in group:
			g.add_child(_tile(c))
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(holder)
	holder.add_child(edge)
	p.resized.connect(func():
		edge.position = Vector2(0, 0)
		edge.size = Vector2(UiKit.bw(3), p.size.y))
	return p


## .item: an item's tile: its picture, name, and what it is to you (equipped, rarity, or how to get it)
func _tile(c: Dictionary) -> Control:
	var R: Dictionary = PalLocker.catalog().RAR[c.r]
	var rc := Color(R.col)
	var own := L.owns(c.id)
	var blocked: bool = c.cat == "hat" and not Wardrobe.headwear_allowed(L.eq.get("skin", "std"), c.key)
	var eq: bool = not blocked and (L.eq.get(c.cat) == c.key or (c.cat == "hat" and c.key == "class" and not Wardrobe.headwear_allowed(L.eq.get("skin", "std"), L.eq.get("hat", "class"))))
	var v := UiKit.vbox(4)
	var art := TileArt.new(c, L.eq.duplicate(), cls())
	art.modulate.a = 1.0 if own else 0.35
	v.add_child(art)
	var nm := _l(c.name, "s8", 14, UiKit.BONE, 0.04, 1.05, true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.modulate.a = 1.0 if own else 0.35
	v.add_child(nm)
	var status: String = "DOES NOT FIT THIS SKIN" if blocked else ("EQUIPPED" if eq else (R.n if own else c.get("how", "")))
	var sl := _l(status, "m4", 9.5, UiKit.DIM, 0.0, 1.3, true)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sl)
	if not own and c.src == "unlock" and c.get("need") is Dictionary and not c.need.is_empty():
		var k: String = c.need.keys()[0]
		var need := int(c.need[k])
		var have := mini(need, int(L.st.get(k, 0)))
		var pb := ProgBar.new()
		pb.frac = float(have) / need
		pb.col = rc
		pb.text = "%d / %d" % [have, need]
		pb.custom_minimum_size.y = UiKit.px(12)
		v.add_child(pb)
	var pad := [6, 6, 9, 6]
	var line: Color = UiKit.WARN if eq else (Color("#ffe27a") if c.r == "g" else (Color("#ff9260") if c.r == "u" else UiKit.LINE))
	var bg := Color(27 / 255.0, 24 / 255.0, 20 / 255.0, 0.85)
	var mk := func(b: Color, ln: Color) -> StyleBoxFlat:
		var s := UiKit.sb(b, ln, 2 if eq else 1, pad)
		return s
	var box := {"normal": mk.call(bg, line), "hover": mk.call(Color(40 / 255.0, 36 / 255.0, 30 / 255.0, 0.95), UiKit.BONE if not eq else UiKit.WARN), "pressed": mk.call(bg, UiKit.WARN), "disabled": mk.call(bg, line)}
	var b := UiKit.card_btn(v, box, func(): _equip(c))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if c.get("description"):
		b.tooltip_text = c.description
	var bar := ColorRect.new()   # the rarity strip along the bottom
	bar.color = rc
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(bar)
	b.resized.connect(func():
		bar.position = Vector2(0, b.size.y - UiKit.bw(3))
		bar.size = Vector2(b.size.x, UiKit.bw(3)))
	menus._fid(b, "item:" + str(c.id))
	tiles.append([b, c])
	return b


## a tile's picture: square, the tile's own width
class TileArt extends Control:
	var c: Dictionary
	var eq: Dictionary
	var klass := "soldier"
	var pool: Array = []

	func _init(item: Dictionary, equipped: Dictionary, k: String) -> void:
		c = item
		eq = equipped
		klass = k
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		custom_minimum_size = Vector2(UiKit.px(60), UiKit.px(100))
		resized.connect(func():
			if absf(custom_minimum_size.y - size.x) > 1:
				custom_minimum_size.y = size.x)

	func _exit_tree() -> void:
		Ctx2D.free_pool(pool)

	func _draw() -> void:
		var S := minf(size.x, size.y)
		draw_set_transform(Vector2((size.x - S) / 2, 0))
		LockerUI.paint_icon(self, c, S, eq, klass, pool)
		draw_set_transform(Vector2.ZERO)


## .iprog: how far along an unlock is, the count over the bar
class ProgBar extends Control:
	var frac := 0.0
	var col := Color.WHITE
	var text := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.45))
		draw_rect(Rect2(0, 0, size.x * frac, size.y), Color(col, 0.55))
		draw_rect(r, UiKit.LINE, false, UiKit.bw(1))
		var f := UiKit.face("m4")
		var fsz := UiKit.fs(8.5)
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		draw_string(f, Vector2((size.x - w) / 2, (size.y + f.get_ascent(fsz) - f.get_descent(fsz)) / 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, UiKit.BONE)


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
	else:
		menus._stage_crew()
	var y := scroll.scroll_vertical
	_render_grid()
	scroll.scroll_vertical = y
	menus._refocus("item:" + str(c.id))


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


## after an opening closes: the counts and tiles change, and the kit on the stage
func refresh() -> void:
	var y := scroll.scroll_vertical
	render()
	scroll.scroll_vertical = y
	menus._stage_crew()
