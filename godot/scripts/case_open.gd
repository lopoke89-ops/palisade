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
var name_l: Label
var sub_l: Label
var list: VBoxContainer
var skip_b: Button
var equip_b: Button
var done_b: Button


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
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.025, 0.02, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	cc.add_child(col)
	eye = ui._lbl(_C().name, 16, Color(_C().col))
	eye.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(eye)
	var W: float = m.v.W
	var sc := minf(1.0, maxf(320, roundf(W * 0.92)) / 480)
	stage = Control.new()
	stage.custom_minimum_size = Vector2(480, 300) * sc
	stage.draw.connect(_draw_intro)
	col.add_child(stage)
	reels = VBoxContainer.new()
	reels.add_theme_constant_override("separation", 6)
	reels.visible = false
	col.add_child(reels)
	name_l = ui._lbl("", 26, ui.GOLD)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_l)
	sub_l = ui._lbl("", 14, ui.DIM)
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub_l)
	list = VBoxContainer.new()
	col.add_child(list)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	skip_b = m.menus._button("SKIP ANIMATION", func(): reveal(), row)
	equip_b = m.menus._button("EQUIP", func(): _equip_close(), row)
	done_b = m.menus._button("DONE", func(): close(), row)
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
		if t >= INTRO:
			_start_reels()
	elif phase == "reel":
		var p := minf(1, t / REEL)
		var y := _ease(p)
		for s in strips:
			s.position.x = -target * y
		var width: float = strips[0].get_parent().size.x
		var idx := floori((target * y + width / 2) / TW)
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
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(TW - 6, 104)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(14 / 255.0, 12 / 255.0, 10 / 255.0, 0.95)
	sb.border_color = Color(R.col)
	sb.set_border_width_all(1)
	sb.border_width_bottom = 4
	sb.set_content_margin_all(3)
	pc.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pc.add_child(v)
	var ic := LockerUI.Icon.new(it, 52, ui.L.eq.duplicate(), ui.cls())
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var b: Label = ui._lbl(it.name, 10, ui.PAPER)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.clip_text = true
	b.custom_minimum_size = Vector2(TW - 14, 0)
	v.add_child(b)
	var r: Label = ui._lbl(R.n, 9, Color(R.col))
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(r)
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
	var width := minf(m.v.W - 40, 760.0)
	for r in results:
		var clip := Control.new()
		clip.clip_contents = true
		clip.custom_minimum_size = Vector2(width, 108)
		reels.add_child(clip)
		var strip := Control.new()
		clip.add_child(strip)
		for i in count:
			var tl := _tile(r.it if i == win_i else fillers[i])
			tl.position = Vector2(i * TW, 2)
			strip.add_child(tl)
		var mark := ColorRect.new()   # the line the winner stops under
		mark.color = Color("#e2b436")
		mark.size = Vector2(2, 108)
		mark.position = Vector2(width / 2 - 1, 0)
		clip.add_child(mark)
		strips.append(strip)
	target = win_i * TW + 44 - width / 2


func reveal() -> void:
	if phase == "reveal":
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
		name_l.add_theme_color_override("font_color", Color(RAR[it.r].col))
		sub_l.text = "%s %s%s" % [RAR[it.r].n, PalLocker.CATN[it.cat], (" · already owned, +%d shards" % res.shards) if res.dup else " · new"]
		equip_b.visible = _can_equip(res)
	else:
		reels.visible = false   # five rows of results take the reels' place
		for res in results:
			var it: Dictionary = res.it
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			list.add_child(row)
			var b: Label = ui._lbl(it.name, 15, Color(RAR[it.r].col))
			b.custom_minimum_size = Vector2(220, 0)
			row.add_child(b)
			row.add_child(ui._lbl(RAR[it.r].n + ((" · DUPLICATE · +%d SHARDS" % res.shards) if res.dup else " · NEW"), 12, ui.DIM))
			if _can_equip(res):
				var e: Button = m.menus._button("EQUIP", func(): pass, row)
				e.pressed.connect(func():
					ui.L.equip(it.id)
					e.disabled = true
					e.text = "EQUIPPED")
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
	LockerUI.cat = "ms" if it.get("ladder") else it.cat
	if it.get("box"):
		LockerUI.open_sections[LockerUI.cat + ":" + it.box] = true
	if it.cat == "bg":
		m.menus.refresh_bg()
	close()


func close() -> void:
	ui.refresh()
	queue_free()
