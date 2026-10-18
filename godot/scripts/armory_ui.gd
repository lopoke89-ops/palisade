class_name ArmoryUI
extends Control
## The armory between raids, as the browser draws it (page.html #armory, 20-locker-ui.js renderArmory, the desktop
## rules in style.css): SALVAGE in the corner, UPGRADES and AMMO tabs, the upgrades in two columns with their pips and
## what the next level does, Delgado and the core repair, the special ammo (two slots for the sniper), and BACK TO THE
## FENCE. It shows itself while the main node's armory is open and is rebuilt only when what it shows changes.
## Buying goes through the main node (_arm_buy), so keys, the controller and a host's rules stay as they were: every
## button's rectangle is handed to main.arm_buttons, which its keyboard and controller navigation walk.

static var tab := "upgrades"
static var slot := 0

var m
var sig := ""
var col: VBoxContainer
var keys: Array = []   # [Btn, key] in the order main walks them
var ring: Control


func _init(main) -> void:
	m = main
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _process(_dt: float) -> void:
	var open: bool = m.armory_open and not m.demo
	if open != visible:
		visible = open
		sig = ""
		if not open:
			for ch in get_children():
				ch.queue_free()
			keys.clear()
	if not open:
		return
	var s := _sig()
	if s != sig:
		sig = s
		_build()
	_sync_buttons()


func _sig() -> String:
	var p: Dictionary = m.sim.player
	var c: Dictionary = m.sim.core
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [p.sal, m.sim.up_str(p), ",".join(p.ammoEq), p.cls, m.sim.game.get("dellLv", 0), ceili(c.hp) if c != null else 0,
		tab, slot, UiKit.k, m.sim.shop_open(p)]


## every buy button's place, for main's arrow-key and controller walk; and the gold ring on the one it has picked
func _sync_buttons() -> void:
	var list: Array = []
	for kv in keys:
		if is_instance_valid(kv[0]) and kv[0].is_visible_in_tree():
			list.append([kv[0].get_global_rect(), kv[1]])
	m.arm_buttons = list
	if ring != null:
		var sel: int = clampi(m.arm_sel, 0, maxi(0, list.size() - 1))
		ring.visible = m.inp.mode != "mouse" and not list.is_empty()
		if ring.visible:
			var r: Rect2 = list[sel][0]
			ring.position = r.position - Vector2(UiKit.px(4), UiKit.px(4)) - global_position
			ring.size = r.size + Vector2(UiKit.px(8), UiKit.px(8))


## UPGRADES / AMMO, a sniper's ammo slot, BACK TO THE FENCE (from a click, a key or the controller)
func press(key: String) -> void:
	if key == "close":
		m._close_armory()
	elif key.begins_with("tab:"):
		tab = key.substr(4)
		m.arm_sel = 0
	elif key.begins_with("slot:"):
		slot = int(key.substr(5))


func _l(text: String, f: String, size: float, col_: Color, em: float = 0.0, lh: float = 0.0, wrap: bool = false) -> Label:
	return UiKit.lbl(text, f, size, col_, em, lh, wrap)


func _build() -> void:
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	keys.clear()
	var s: Sim = m.sim
	var p: Dictionary = s.player
	if not s.ammo_mode():
		tab = "upgrades"
	if p.cls != "sniper":
		slot = 0
	var dim := ColorRect.new()
	dim.color = Color(12 / 255.0, 11 / 255.0, 9 / 255.0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	col = UiKit.vbox(8)
	col.custom_minimum_size.x = minf(UiKit.px(760), get_viewport().get_visible_rect().size.x - UiKit.px(24))
	cc.add_child(col)
	var top := UiKit.hbox(12)
	var eb := _l("ARMORY · AT YOUR STAKE" if s.pvp() != "" else "ARMORY · BETWEEN RAIDS", "s8", 10, UiKit.OWARN, 0.12)
	eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(eb)
	top.add_child(_l("SALVAGE %d" % int(p.sal), "s9", 22, UiKit.OWARN, 0.04))
	col.add_child(top)
	var tabs := UiKit.grid(2 if s.ammo_mode() else 1, 6)
	var tab_keys: Array = []
	for t in ([["upgrades", "UPGRADES"], ["ammo", "AMMO"]] if s.ammo_mode() else [["upgrades", "UPGRADES"]]):
		var b := _tab_btn(t[1], t[0] == tab)
		b.pressed.connect(func(): m._arm_buy("tab:" + t[0]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		tab_keys.append([b, "tab:" + t[0]])
	col.add_child(tabs)
	var shop: bool = s.shop_open(p)
	if tab == "ammo":
		if p.cls == "sniper":
			var sl := UiKit.grid(2, 6)
			for k in 2:
				var id: String = p.ammoEq[k]
				var nm: String = "EMPTY"
				for A in Sim.AMMO:
					if A.id == id:
						nm = A.name
				var b := _tab_btn("%d: %s" % [k + 1, nm], k == slot, 13)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b.pressed.connect(func(): m._arm_buy("slot:%d" % k))
				sl.add_child(b)
				tab_keys.append([b, "slot:%d" % k])
			col.add_child(sl)
		var rows := UiKit.grid(2, 20, 4)
		col.add_child(rows)
		for A in Sim.AMMO:
			var rank: int = p.perk.ammo.get(A.id, 0) if p.has("perk") and p.perk.has("ammo") else 0
			var same: bool = p.ammoEq[slot] == A.id
			var other: bool = p.ammoEq.has(A.id) and not same
			var cost := 75 if p.ammoEq[slot] != "" else 150
			var label: String = "EQUIPPED" if same else ("OTHER SLOT" if other else "%d SAL" % cost)
			rows.add_child(_row(A.name, -1, _ammo_short(A.id, rank), label, same or other or p.sal < cost or not shop, "ammo:%s:%d" % [A.id, slot], Color(A.col)))
	else:
		var rows := UiKit.grid(2, 20, 4)
		col.add_child(rows)
		for U in Sim.UPG:
			var t: int = p.up[U.k]
			rows.add_child(_row(U.name, t, m._arm_summary(U.k, t), "MAXED" if t >= Sim.ARM_MAX else "%d SAL" % U.cost[t], t >= Sim.ARM_MAX or p.sal < U.cost[t] or not shop, U.k))
		if s.pvp() == "":
			var L: int = s.game.get("dellLv", 0)
			if not s.qm.get("gone", false):
				rows.add_child(_row(Sim.DELL_UP.name, L, m._arm_summary("dell", L), "MAXED" if L >= Sim.ARM_MAX else "%d SAL" % Sim.DELL_UP.cost[L], L >= Sim.ARM_MAX or p.sal < Sim.DELL_UP.cost[L] or not shop, "dell"))
			if not s.has_mod("nopatch") and s.core != null:
				var full: bool = s.core.hp >= s.core.max
				var cost := s.core_fix_cost(p)
				rows.add_child(_row("REPAIR CORE", -1, "%d/%d HP · repairs +%d" % [maxi(0, ceili(s.core.hp)), int(s.core.max), int(Sim.CORE_FIX.hp)], "FULL" if full else "%d SAL" % cost, full or s.core.hp <= 0 or p.sal < cost or not shop, "core"))
	var close := UiKit.btn("BACK TO THE FENCE", "oghost", 16, func(): m._arm_buy("close"), {"h": 44})
	close.focus_mode = Control.FOCUS_NONE
	col.add_child(close)
	keys.append_array(tab_keys)
	keys.append([close, "close"])
	var hint := _l("%s or %s closes the armory." % ["X" if m.inp.mode == "pad" else m.settings.keys_label("armory").split(" / ")[0], "B" if m.inp.mode == "pad" else "Esc"], "m4", 12, UiKit.ODIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	ring = Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rs := UiKit.sb(Color(0, 0, 0, 0), Color("#f3e9d6"), 2)
	ring.add_theme_stylebox_override("panel", rs)
	ring.visible = false
	add_child(ring)


func _tab_btn(text: String, sel: bool, size: float = 15.0) -> UiKit.Btn:
	var bg := Color("#3d3119") if sel else Color("#211d17")
	var ln := UiKit.OWARN if sel else UiKit.OLINE
	var fg := UiKit.OWARN if sel else UiKit.ODIM
	var box := {"normal": UiKit.sb(bg, ln, 1, [4, 6, 4, 6]), "hover": UiKit.sb(bg.lightened(0.05), UiKit.OWARN, 1, [4, 6, 4, 6]), "pressed": UiKit.sb(Color("#3d3119"), UiKit.OWARN, 1, [4, 6, 4, 6]), "disabled": UiKit.sb(bg, ln, 1, [4, 6, 4, 6])}
	var b := UiKit.btn(text, "oghost", size, Callable(), {"h": 44, "em": 0.05, "box": box, "tint": {"normal": fg, "hover": UiKit.OWARN, "pressed": UiKit.OWARN, "disabled": fg}})
	b.focus_mode = Control.FOCUS_NONE
	return b


## .arow: the name and its level, the pips, what the next level does; the price on the right
func _row(name: String, lvl: int, what: String, label: String, dis: bool, key: String, ncol: Color = UiKit.OBONE) -> Control:
	var v := UiKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UiKit.rule(UiKit.OLINE))
	v.add_child(UiKit.spacer(4))
	var h := UiKit.hbox(8)
	var left := UiKit.vbox(2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	var nr := UiKit.hbox(8)
	nr.add_child(_l(name, "s9", 16, ncol, 0.025))
	if lvl >= 0:
		var lv := _l("%d/%d" % [lvl, Sim.ARM_MAX], "m4", 10, UiKit.ODIM)
		lv.size_flags_vertical = Control.SIZE_SHRINK_END
		nr.add_child(lv)
	left.add_child(nr)
	if lvl >= 0:
		var pips := UiKit.Pips.new(Sim.ARM_MAX, lvl, 8, 4, 3)
		pips.col = UiKit.OWARN
		pips.line = UiKit.OLINE
		left.add_child(pips)
	left.add_child(_l(what, "m4", 10, UiKit.ODIM, 0.0, 1.2, true))
	h.add_child(left)
	var b := UiKit.btn(label, "ogo", 13, func(): m._arm_buy(key), {"w": 74, "h": 44, "em": 0.03, "pad": [0, 4, 0, 4]})
	b.disabled = dis
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	v.add_child(h)
	v.add_child(UiKit.spacer(4))
	keys.append([b, key])
	return v


## ammoEffectShort: what an ammo does at the skill tree's rank for it
static func _ammo_short(id: String, rank: int) -> String:
	var e := ""
	match id:
		"ap":
			e = "%d%% frontal shield damage" % [50, 60, 70, 85, 100][clampi(rank, 0, 4)]
		"fire":
			e = "10 HP/s · %ss burn" % str(3 + 0.5 * rank)
		"blast":
			e = "%d dmg · 1.25-block blast" % (8 + 2 * rank)
		_:
			e = "%d%% slow · 2s · 3 nearby/3 blocks" % (25 + 5 * rank)
	return e + " · skill %d/4" % rank
