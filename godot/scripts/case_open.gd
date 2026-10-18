class_name CaseOpen
extends Control
## Opening one or five cases (20b-case-openings.js, caseIntro in 20-locker-ui.js). The results are already in the
## locker; this is the show: the crate shakes harder and harder and bursts (3 s), then a reel per case slides to the
## item it gave (4.2 s, ticking at each tile in that tile's rarity), then the reveal. SKIP jumps to the end.

const TW := 94.0
const INTRO := 3.0
const REEL := 4.2

var ui
var m
var id := ""
var results: Array = []
var phase := "intro"
var want_reveal := false   # SKIP pressed before the server answered
var t0 := 0.0
var stage: Control
var reels: VBoxContainer
var strips: Array = []
var fillers: Array = []
var win_i := 29
var target := 0.0
var last_idx := -1
var last_tick := -1
var boomed := false
var bits: Array = []
var eye: Label
var tap_l: Label
var name_l: Label
var sub_l: Label
var list: VBoxContainer
var skip_b: UiKit.Btn
var equip_b: UiKit.Btn
var done_b: UiKit.Btn


func _init(locker_ui, case_id: String, res: Array) -> void:
	ui = locker_ui
	m = ui.m
	id = case_id
	results = res
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for i in 46:
		var a := TAU * i / 46 + randf() * 0.3
		var sp := 120 + randf() * 260
		bits.append({"vx": cos(a) * sp, "vy": sin(a) * sp - 120, "r": 2 + randf() * 5, "c": i % 3, "rot": randf() * 6})


func _C() -> Dictionary:
	return PalLocker.catalog().CASES.get(id, PalLocker.catalog().CASES.supply)


func _ready() -> void:
	top_level = true   # over the whole screen, not just the Locker's columns
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(func(): size = get_viewport().get_visible_rect().size)
	var dim := ColorRect.new()
	dim.color = Color(12 / 255.0, 11 / 255.0, 9 / 255.0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var col := UiKit.vbox(16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.custom_minimum_size.x = minf(UiKit.px(420), size.x - UiKit.px(32))
	cc.add_child(col)
	eye = UiKit.lbl(_C().name, "s8", 13, Color(_C().col), 0.22)
	col.add_child(eye)
	var sc: float = col.custom_minimum_size.x / 480
	stage = Control.new()
	stage.custom_minimum_size = Vector2(480, 300) * sc
	stage.draw.connect(_draw_intro)
	col.add_child(stage)
	tap_l = UiKit.lbl("TAP TO SKIP", "m4", 9, UiKit.ODIM, 0.14)
	tap_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tap_l)
	stage.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: reveal())
	reels = UiKit.vbox(6)
	reels.visible = false
	col.add_child(reels)
	var res := UiKit.vbox(4)
	name_l = UiKit.lbl("", "s9", 28, UiKit.OBONE, 0.04)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res.add_child(name_l)
	sub_l = UiKit.lbl("", "m4", 12, UiKit.ODIM, 0.0, 1.5, true)
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res.add_child(sub_l)
	col.add_child(res)
	list = UiKit.vbox(5)
	col.add_child(list)
	skip_b = UiKit.btn("SKIP ANIMATION", "oghost", 16, func(): reveal(), {"h": 46})
	col.add_child(skip_b)
	equip_b = UiKit.btn("EQUIP IT", "ogo", 22, func(): _equip_close(), {"h": 56})
	col.add_child(equip_b)
	done_b = UiKit.btn("DONE", "oghost", 16, func(): close(), {"h": 46})
	col.add_child(done_b)
	equip_b.visible = false
	done_b.visible = false
	t0 = _now()
	await get_tree().process_frame
	skip_b.grab_focus()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(_dt: float) -> void:
	var t := _now() - t0
	if phase == "intro":
		var k := minf(1, t / 1.8)
		if t < 2:
			var tick := floori(t * (4 + k * 10))
			if tick != last_tick:
				last_tick = tick
				m.audio.play("tick_e" if k > 0.6 else "tick_r")
		elif not boomed:
			boomed = true
			m.audio.play("kx_confetti")
		stage.queue_redraw()
		if results.is_empty() and t > 1.9:   # the server is still rolling: keep shaking
			t0 = _now() - 1.2
		elif t >= INTRO and not results.is_empty():
			_start_reels()
	elif phase == "reel":
		var p := minf(1, t / REEL)
		var y := _ease(p)
		for s in strips:
			s.position.x = -target * y
		var width: float = strips[0].get_parent().size.x
		var idx := floori((target * y + width / 2) / (UiKit.px(TW) * (0.55 if results.size() == 5 else 1.0)))
		if idx != last_idx:
			last_idx = idx
			var it: Dictionary = results[0].it if idx == win_i else (fillers[idx] if idx >= 0 and idx < fillers.size() else {})
			if not it.is_empty():
				m.audio.play("tick_" + it.r)
		if p >= 1 and t > REEL + 0.12:
			reveal()


## cubic-bezier(.08,.72,.16,1): the reel's slide, fast then a long slow settle
static func _ease(p: float) -> float:
	var q := p
	for i in 4:
		var u := 1 - q
		var xq := 3 * 0.08 * u * u * q + 3 * 0.16 * u * q * q + q * q * q
		var dx := 3 * 0.08 * u * u + 6 * (0.16 - 0.08) * u * q + 3 * (1 - 0.16) * q * q
		if dx == 0:
			break
		q = clampf(q - (xq - p) / dx, 0, 1)
	return 3 * 0.72 * (1 - q) * (1 - q) * q + 3 * (1 - q) * q * q + q * q * q


func _draw_intro() -> void:
	var t := _now() - t0
	var x := Ctx2D.new(stage)
	var s: float = stage.size.x / 480
	x.scale(s, s)
	var C := _C()
	var cx := 240.0
	var cy := 160.0
	if t < 2:   # the shake, harder and faster, glowing in the case's colour
		var k := minf(1, t / 1.8)
		var amp := 2 + k * 9
		var f := 10 + k * 26
		x.save()
		x.translate(cx + sin(t * f) * amp, cy)
		x.rotate(sin(t * f * 1.3) * 0.06 * k)
		x.glow(0, 0, 70 + k * 40, C.col, 0.25 + k * 0.45)
		LockerUI.paint_case(x, id, 0, 0, 162)
		x.restore()
	else:   # it breaks: sparks fly out and fade
		var u := t - 2
		x.save()
		x.global_alpha = maxf(0, 1 - u * 3)
		x.translate(cx, cy)
		x.scale(1 + u * 1.2, 1 + u * 1.2)
		LockerUI.paint_case(x, id, 0, 0, 162)
		x.restore()
		for b in bits:
			x.save()
			x.global_alpha = maxf(0, 1 - u)
			x.fill_style = C.col if b.c else "#f3e9d6"
			x.translate(cx + b.vx * u, cy + b.vy * u + 260 * u * u)
			x.rotate(b.rot + u * 6)
			x.fill_rect(-b.r, -b.r * 0.6, b.r * 2, b.r * 1.2)
			x.restore()


func _tile(it: Dictionary) -> Control:
	var R: Dictionary = PalLocker.catalog().RAR[it.r]
	var rc := Color(R.col)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(UiKit.px(88), UiKit.px(98))
	var st := UiKit.sb(Color(27 / 255.0, 24 / 255.0, 20 / 255.0, 0.85), UiKit.OLINE, [1, 1, 4, 1], [4, 4, 4, 4])
	st.border_color = UiKit.OLINE
	pc.add_theme_stylebox_override("panel", st)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UiKit.vbox(3)
	pc.add_child(v)
	var ic := LockerUI.Icon.new(it, UiKit.px(52), ui.L.eq.duplicate(), ui.cls())
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var b := UiKit.lbl(it.name, "s8", 12, UiKit.OBONE, 0.0)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.custom_minimum_size.x = UiKit.px(78)
	v.add_child(b)
	var r := UiKit.lbl(R.n, "m6", 9.5, rc, 0.06)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(r)
	var bar := ColorRect.new()
	bar.color = rc
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bar)
	pc.add_child(holder)
	pc.resized.connect(func():
		bar.position = Vector2(-st.content_margin_left - UiKit.bw(1), pc.size.y - st.content_margin_top - UiKit.bw(4))
		bar.size = Vector2(pc.size.x, UiKit.bw(4)))
	return pc


func _start_reels() -> void:
	phase = "reel"
	t0 = _now()
	stage.visible = false
	reels.visible = true
	var batch := results.size() == 5
	win_i = 9 if batch else 29
	var count := 13 if batch else 34
	fillers = []
	for i in count:
		fillers.append(ui.L.roll_case(id))
	tap_l.visible = false
	var width: float = minf(UiKit.px(420), size.x - UiKit.px(32))
	var tw := UiKit.px(TW)
	var hh := UiKit.px(112 if not batch else 64)
	for r in results:
		var clip := Panel.new()
		clip.add_theme_stylebox_override("panel", UiKit.sb(Color("#0c0b09"), UiKit.OLINE, 1))
		clip.clip_contents = true
		clip.custom_minimum_size = Vector2(width, hh)
		reels.add_child(clip)
		var strip := Control.new()
		clip.add_child(strip)
		for i in count:
			var tl := _tile(r.it if i == win_i else fillers[i])
			tl.position = Vector2(i * tw + UiKit.px(6), UiKit.px(6))
			if batch:
				tl.scale = Vector2.ONE * 0.55
				tl.position = Vector2(i * tw * 0.55 + UiKit.px(3), UiKit.px(3))
			strip.add_child(tl)
		var mark := ColorRect.new()   # the line the winner stops under
		mark.color = UiKit.OWARN
		mark.size = Vector2(UiKit.bw(2), hh)
		mark.position = Vector2(width / 2 - UiKit.bw(1), 0)
		clip.add_child(mark)
		strips.append(strip)
	target = (win_i * tw + UiKit.px(6) + UiKit.px(44)) * (0.55 if batch else 1.0) - width / 2


## the account's server answered with what the cases gave
func set_results(res: Array) -> void:
	results = res
	if want_reveal:
		reveal()


## it didn't: say why; an opening that may have gone through stays saved to resume
func fail(err: String, uncertain: bool) -> void:
	phase = "failed"
	stage.visible = false
	tap_l.visible = false
	eye.text = "OPENING SAVED" if uncertain else "NOT OPENED"
	sub_l.text = err
	skip_b.visible = false
	done_b.visible = true
	done_b.grab_focus()


func reveal() -> void:
	if phase == "reveal" or phase == "failed":
		return
	if results.is_empty():
		want_reveal = true
		return
	if phase == "intro":
		_start_reels()
	phase = "reveal"
	for s in strips:
		s.position.x = -target
	skip_b.visible = false
	done_b.visible = true
	var RAR: Dictionary = PalLocker.catalog().RAR
	if results.size() == 1:
		var res: Dictionary = results[0]
		var it: Dictionary = res.it
		name_l.text = it.name
		name_l.label_settings = UiKit.ls("s9", 28, Color(RAR[it.r].col), 0.04)
		sub_l.text = "%s %s%s" % [RAR[it.r].n, PalLocker.CATN[it.cat], (" · already owned, +%d shards" % res.shards) if res.dup else " · new"]
		equip_b.visible = _can_equip(res)
	else:
		reels.visible = false   # five rows of results take the reels' place
		for res in results:
			var it: Dictionary = res.it
			var row := UiKit.hbox(8)   # .caseResultRow
			var rv := UiKit.vbox(3)
			rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rv.add_child(UiKit.lbl(it.name, "s9", 15, Color(RAR[it.r].col)))
			rv.add_child(UiKit.lbl(RAR[it.r].n + ((" · DUPLICATE · +%d SHARDS" % res.shards) if res.dup else " · NEW"), "m4", 10, UiKit.ODIM))
			row.add_child(rv)
			var rw := UiKit.vbox(0)
			rw.add_child(row)
			rw.add_child(UiKit.spacer(4))
			rw.add_child(UiKit.rule(UiKit.OLINE))
			list.add_child(rw)
			if _can_equip(res):
				var e := UiKit.btn("EQUIP", "oghost", 14, Callable(), {"h": 44})
				e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				row.add_child(e)
				e.pressed.connect(func():
					ui.L.equip(it.id)
					if not ui.L.cloud.is_empty():
						ui.L.account.equip(it.id)
					e.disabled = true
					e.label.text = "EQUIPPED")
	var best: Dictionary = results[0].it
	for res in results:
		if int(RAR[res.it.r].sh) > int(RAR[best.r].sh):
			best = res.it
	m.audio.play("win" if best.r in ["l", "e", "g", "u"] else "restock")
	m.inp.rumble(120 if best.r in ["g", "u"] else 40)
	done_b.grab_focus()


func _can_equip(res: Dictionary) -> bool:
	var it: Dictionary = res.it
	return not res.dup and ui.L.owns(it.id) and ui.L.eq.get(it.cat) != it.key and (it.cat != "hat" or Wardrobe.headwear_allowed(ui.L.eq.get("skin", "std"), it.key))


func _equip_close() -> void:
	var it: Dictionary = results[0].it
	ui.L.equip(it.id)
	if not ui.L.cloud.is_empty():
		ui.L.account.equip(it.id)
	LockerUI.cat = "ms" if it.get("ladder") else it.cat
	if it.get("box"):
		LockerUI.open_sections[LockerUI.cat + ":" + it.box] = true
	if it.cat == "bg":
		m.menus.refresh_bg()
	close()


func close() -> void:
	if phase == "reveal" and not ui.L.cloud.is_empty():   # seen: the saved opening is done with
		ui.L.account.clear_opening()
	ui.refresh()
	queue_free()
