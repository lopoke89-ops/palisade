class_name Menus
extends CanvasLayer
## The menus (page.html, 19c-home.js, 19e-index.js, 22-loop-menus.js): the main menu over the demo yard, match setup,
## settings with the key and controller tables, the index, the pause menu and the after-action screen. Built from
## Godot controls so the mouse, keys and a controller (through focus) all work them.

const GOLD := Color("#e2b436")
const PAPER := Color("#e8dcc0")
const DIM := Color("#9a8f7a")
const RED := Color("#d65a3a")
const INK := Color(14 / 255.0, 12 / 255.0, 10 / 255.0, 0.92)

const MODES := [["5", "5 RAIDS"], ["10", "10 RAIDS"], ["endless", "ENDLESS"], ["blitz", "BLITZKRIEG"], ["campaign", "CAMPAIGN"], ["blackout", "BLACK OUT"]]
const MODE_HINT := {
	"5": "Five raids. A boss on raid 5, at night.",
	"10": "Ten raids. Bosses on raids 5 and 10; golden hour from raid 6, night from raid 9.",
	"endless": "Raids until the stake falls. Each one a notch harder, with a boss every fifth raid and nights in between.",
	"blitz": "15 hard raids, then the Final Blitz: 5 minutes with a new boss every 30 seconds. The last minute is the evacuation: reach the evac site yourself, or leave with half your cases and shards.",
	"campaign": "Operation Whiteout: travel all four maps. Carry upgrades and supplies through 12 raids, then survive the Whiteout Gauntlet and a summit evacuation.",
	"blackout": "City Black Out: a night city. Hold eight points as bosses hit them one by one, then defend Main Command against the Supreme Destroyer.",
}
const CLASS_TEXT := {
	"soldier": ["the door problem", "Burst carbine: 3 rounds a pull, up to 9 with DAMAGE upgrades. Builds 40% faster and takes more hits. Q fires a rocket."],
	"sniper": ["the angle problem", "Bolt-action rifle. Heavy rounds straight through wood. Moves 10% faster. Q: stealth, raiders lose you for 12 s."],
	"grenadier": ["the doorway problem", "Pump shotgun: huge up close, tight spread, fires as fast as you click (holding fires every half second), six shells. Three grenades a round. Moves 10% slower."],
	"quartermaster": ["the rescue problem", "Walk over a downed teammate to get them up instantly. Carries 96 of everything, gathers faster, repairs for half. SMG. The only one who can SPRINT."],
}
const IDX_RAIDERS := [
	["rifle", 1, "The backbone of every raid. Walks the path and shoots whoever is closest."],
	["gren", 2, "Lobs grenades over your walls at you and your defenses."],
	["fire", 2, "Throws fire bottles at wooden walls, or at people close by. The glass bursts into burning ground and sets wood alight."],
	["breach", 3, "Runs a satchel charge up to a wall and blows it open."],
	["shield", 3, "Turns a riot shield toward whoever is shooting. Rounds from the front spark off: flank him, or use Armor Piercing or explosives."],
	["medic", 4, "Hangs back behind other raiders and patches up everyone near him every 1.6 s. Take him out first."],
	["spotter", 6, "Sits back 6 to 9 tiles and marks a soldier with a red laser. Riflemen aim far better at whoever is marked."]]
const IDX_BOSSES := [
	["STANDARD RAIDS", [
		["demolisher", "", ["Rocket: a red line shows where it goes. Step out of it.", "Rocket fan: every third volley is three rockets in a spread."], ""],
		["butcher", "", ["Blade: a red wedge up close, then a cut.", "Charge: a red lane, then he runs it down, knocking people aside and smashing wood."], "Below 40%: enraged, faster, cuts sooner."],
		["storm", "", ["Chain lightning: a blue line tracks you, then locks. The bolt stuns and jumps to two more people.", "Thunderstrike: three blue rings around you, then lightning drops into each one.", "Static Pulse: get within 4 tiles and he crackles, then blasts everyone back."], "Below 50%: fires his bolt twice."],
		["ferryman", "", ["Harpoon: a chain line. Whoever it hits, or a wall, is dragged toward the water.", "Boarding crews: lands two or three raiders on the bank.", "Bridge ram: smashes a bridge into the river."], "After a bridge falls: harpoons faster."],
		["foreman", "", ["Rock slab: a ring shows where it lands. It stays as a stone block.", "Burrow: drills underground where bullets can't reach, then bursts up through the wall above.", "Rockfall: a marked lane of falling rock."], "Rockfall only below 50%."]]],
	["BLITZKRIEG RUSH", [
		["harbinger", "Blitzkrieg Rush", ["Missile barrage: three arcing missiles, each with a red landing ring. Keep moving.", "Boarding crews: lands raiders on the bank."], "Below 50%: four missiles at a time."],
		["bluebutcher", "Blitzkrieg Rush", ["Blue arc: a teal lane, then a crescent that breaks wood and brick walls.", "Blade: a close cut.", "Charge: a lane charge, less often than the Butcher's."], "Enraged: arcs more often."],
		["arsonist", "Blitzkrieg Rush", ["Napalm chain: a line of four rings, then burning napalm on each one for 10 s.", "Flamethrower: an orange wedge up close, then a sweep of flame that lights wood.", "Ring of Fire: napalm lands in a circle around you. Get out, or wait in the safe middle."], ""],
		["tempest", "Blitzkrieg Rush", ["Twin lightning: two blue lines side by side. Caught by both, it hurts twice.", "Cyclone: a marked path, then a whirlwind that shoves you along and rips out wood walls.", "Storm Cage: a ring of lightning posts around you. Get out through the gap before it closes."], "Below 50%: fires twice."],
		["bulldozer", "Blitzkrieg Rush", ["Charge: a lane, then a fast charge. Hitting a wall dazes him for 3 s.", "Seismic Slam: a yellow ring around him, then a shockwave that knocks you back.", "Overdrive: three lanes in a zig-zag, then three rams in a row."], ""]]],
	["WINTER", [
		["rime", "Frostpeak boss raids · Campaign finale", ["Frost rupture: cracking ice marks a huge ring. Step clear.", "Frost dash: a marked dash that leaves slowing frost behind."], "His attacks come faster as his health drops."],
		["whitebutcher", "Campaign · chapter 1", ["Ice arc: a lane, then a crescent through wood and brick.", "Blade: a close cut.", "Charge: a lane charge.", "Frost rupture: a marked ring of cracking ice."], "Enraged below 40%."],
		["whiteferryman", "Campaign · chapter 2", ["Harpoon: a chain line that drags you toward the water.", "Boarding crews: raiders landed on the bank.", "Bridge ram: a bridge goes into the river.", "Frost rupture: a marked ring of cracking ice."], "After a bridge falls: harpoons faster."],
		["whiteforeman", "Campaign · chapter 3", ["Charge: a fast marked charge. Bait him into a wall to daze him.", "Frost rupture: a marked ring of cracking ice."], ""]]],
	["CITY BLACK OUT", [
		["destroyer", "City Black Out · the last 2 minutes of the final push", ["Back Rockets: six red landing rings round you, then missiles arc in. They break wood.", "Fire barrel: an orange lane, then a stream of fire down it that burns and lights wood.", "Lightning barrel: a blue line tracks you, then a heavy bolt that stuns and jumps to two more people.", "Poison Gas: a green ring grows round him, then a gas cloud fills it for 8 s. Fight him from range.", "Minefield: a marked area, then ten mines. Shoot one, or throw a grenade, to set them off safely.", "Orbital Cannon: a targeting circle follows you for 3 s, stops, then a beam hits. It wrecks walls."], "Below 40%: the Orbital Cannon, every 20 s."]]]]

var m   # the main node
var root: Control
var screen := ""
var came_from := ""   # where BACK goes from settings and the index (the main menu or the pause menu)
var theme_: Theme
var hint: Label   # setup: the line under the modifiers that says what the last one does
var binding := ""   # Settings: an action waiting for a key
var _sc: ScrollContainer   # the open card's scroller: as tall as its content, up to the screen
var _col: VBoxContainer


func _init(main) -> void:
	m = main
	layer = 5


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	theme_ = _make_theme()
	root.theme = theme_


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = ThemeDB.fallback_font
	t.default_font_size = 15
	var sb := func(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = bg
		s.border_color = border
		s.set_border_width_all(bw)
		s.set_content_margin_all(8)
		s.content_margin_left = 14
		s.content_margin_right = 14
		return s
	t.set_stylebox("normal", "Button", sb.call(Color(28 / 255.0, 24 / 255.0, 19 / 255.0, 0.94), Color("#4a4030"), 1))
	t.set_stylebox("hover", "Button", sb.call(Color(42 / 255.0, 36 / 255.0, 27 / 255.0, 0.96), GOLD, 1))
	t.set_stylebox("pressed", "Button", sb.call(GOLD, GOLD, 1))
	t.set_stylebox("hover_pressed", "Button", sb.call(GOLD.lightened(0.1), PAPER, 1))
	t.set_stylebox("focus", "Button", sb.call(Color(0, 0, 0, 0), PAPER, 2))
	t.set_stylebox("disabled", "Button", sb.call(Color(20 / 255.0, 18 / 255.0, 14 / 255.0, 0.7), Color("#2a251c"), 1))
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color("#17140f"))
	t.set_color("font_hover_pressed_color", "Button", Color("#17140f"))
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("#5a5244"))
	t.set_color("font_color", "Label", PAPER)
	t.set_stylebox("panel", "PanelContainer", sb.call(INK, Color("#3a3226"), 1))
	t.set_stylebox("focus", "HSlider", sb.call(Color(0, 0, 0, 0), PAPER, 1))
	t.set_stylebox("focus", "CheckBox", sb.call(Color(0, 0, 0, 0), PAPER, 1))
	t.set_color("font_color", "CheckBox", PAPER)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color("#2a251c")
	var bar_fg := StyleBoxFlat.new()
	bar_fg.bg_color = GOLD
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fg)
	return t


func active() -> bool:
	return screen != ""


func close() -> void:
	screen = ""
	binding = ""
	for ch in root.get_children():
		ch.queue_free()


func _clear() -> void:
	for ch in root.get_children():
		root.remove_child(ch)
		ch.queue_free()
	if m.demo and m.locker != null:   # outside a game the menus sit on the lobby background (drawLobbyBg)
		root.add_child(LockerUI.BgView.new(lobby_bg()))


func lobby_bg() -> String:
	var id: String = m.locker.eq.get("bg", "campfire") if m.locker != null else "campfire"
	return id if PalLocker.catalog().BGS.has(id) else "campfire"


## the equipped background changed: swap the one behind the menus
func refresh_bg() -> void:
	for ch in root.get_children():
		if ch is LockerUI.BgView:
			var nb := LockerUI.BgView.new(lobby_bg())
			root.add_child(nb)
			root.move_child(nb, ch.get_index())
			root.remove_child(ch)
			ch.queue_free()
			return


func show_locker() -> void:
	_clear()
	_sc = null
	screen = "locker"
	root.add_child(LockerUI.new(self))


## a centred card holding a column; returns the column
func _card(width: float, title: String, kicker: String = "") -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(minf(width, m.v.W - 24), 0)
	cc.add_child(pc)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 80)
	sc.follow_focus = true
	_sc = sc
	pc.add_child(sc)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	sc.add_child(col)
	_col = col
	if kicker != "":
		col.add_child(_label(kicker, 12, DIM))
	if title != "":
		col.add_child(_label(title, 26, GOLD))
	return col


func _label(text: String, size: int = 15, col: Color = PAPER, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(200, 0)
	return l


func _button(text: String, cb: Callable, row: Container = null) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	if row != null:
		row.add_child(b)
	return b


## a row of toggle buttons for one choice; returns the row
func _choice(col: VBoxContainer, title: String, opts: Array, cur: String, cb: Callable, disabled: Array = []) -> HFlowContainer:
	col.add_child(_label(title, 12, DIM))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	col.add_child(row)
	for o in opts:
		var b := Button.new()
		b.text = o[1]
		b.toggle_mode = true
		b.button_pressed = o[0] == cur
		b.disabled = disabled.has(o[0])
		var id: String = o[0]
		b.pressed.connect(func(): cb.call(id))
		row.add_child(b)
	return row


func _focus_first() -> void:
	await get_tree().process_frame
	if is_instance_valid(_sc) and is_instance_valid(_col) and _sc.is_inside_tree():
		_sc.custom_minimum_size.y = minf(m.v.H - 60, _col.get_combined_minimum_size().y + 4)
	var f := _first_focusable(root)
	if f != null:
		f.grab_focus()


func _first_focusable(n: Node) -> Control:
	for ch in n.get_children():
		if ch is Button and not ch.disabled and ch.is_visible_in_tree():
			if ch.button_pressed or not ch.toggle_mode:
				return ch
		var r := _first_focusable(ch)
		if r != null:
			return r
	return null


# ---------------------------------------------------------------- main menu

func show_main() -> void:
	_clear()
	_sc = null
	screen = "main"
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.25)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var box := VBoxContainer.new()
	box.position = Vector2(clampf(m.v.W * 0.08, 16, 120), clampf(m.v.H * 0.14, 16, 140))
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)
	box.add_child(_label("FIELD TEST 03 · LUMBER YARD", 12, DIM))
	var t := HBoxContainer.new()
	t.add_theme_constant_override("separation", 0)
	t.add_child(_label("PALI", 64, PAPER))
	t.add_child(_label("SADE", 64, GOLD))
	box.add_child(t)
	box.add_child(_label("Neighbors with rifles and a deadline.", 16, DIM))
	box.add_child(_label(setup_line(), 13, GOLD))
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(300, 0)
	col.add_theme_constant_override("separation", 6)
	box.add_child(col)
	_button("PLAY", func(): m.start_game(), col)
	_button("PLAY ONLINE", func(): show_online(""), col)
	_button("MATCH SETUP", func(): show_setup(), col)
	_button("LOCKER" + (" · %d CASE%s" % [m.locker.all_cases(), "" if m.locker.all_cases() == 1 else "S"] if m.locker != null and m.locker.all_cases() > 0 else ""), func(): show_locker(), col)
	_button("SKILL TREE", func(): m.open_skills(), col)
	if m.account != null and m.account.state != "off":
		_button("ACCOUNT · " + _acct_tag(), func(): show_account(), col)
	_button("INDEX", func(): _go("main", "index"), col)
	_button("SETTINGS", func(): _go("main", "settings"), col)
	_button("QUIT", func(): get_tree().quit(), col)
	var S: Dictionary = m.settings.data.setup
	var note := _label(MODE_HINT.get(S.mode, ""), 13, PAPER, true)
	note.custom_minimum_size = Vector2(minf(420, m.v.W - 60), 0)
	box.add_child(note)
	_focus_first()


func setup_line() -> String:
	var S: Dictionary = m.settings.data.setup
	var mn := ""
	for md in MODES:
		if md[0] == S.mode:
			mn = md[1]
	var mp: String = "THE CITY" if S.mode == "blackout" else ("ALL FOUR MAPS" if S.mode == "campaign" else PalMaps.MAPS[S.map].name)
	var line := "%s · %s · %s · %s · %s" % [mn, mp, "XL" if S.size == "xl" else "STANDARD", Pal.DIFF[S.diff].name, Pal.CLASSES[S.cls].name]
	var mods := Sim.clean_mods(S.mods, S.mode)
	if not mods.is_empty():
		line += " · " + " + ".join(mods.map(func(id): return _mod(id).name))
	return line


static func _mod(id: String) -> Dictionary:
	for M in Sim.MODS:
		if M.id == id:
			return M
	return {"id": id, "name": id.to_upper(), "what": ""}


# ---------------------------------------------------------------- match setup

func show_setup() -> void:
	_clear()
	screen = "setup"
	var S: Dictionary = m.settings.data.setup
	var col := _card(760, "MATCH SETUP")
	var set_and := func(k: String, val) -> void:
		S[k] = val
		if k == "mode":
			S.mods = Sim.clean_mods(S.mods, val)
		m.settings.save()
		var f := get_viewport().gui_get_focus_owner()
		var fp := f.get_path() if f != null else NodePath()
		show_setup()
		if not fp.is_empty():
			await get_tree().process_frame
			var n := get_node_or_null(fp)
			if n is Control:
				n.grab_focus()
	_choice(col, "LENGTH", MODES, S.mode, func(id): set_and.call("mode", id))
	col.add_child(_label(MODE_HINT.get(S.mode, ""), 13, DIM, true))
	var fixed: bool = S.mode == "campaign" or S.mode == "blackout"
	var maps: Array = PalMaps.MAP_IDS.map(func(id): return [id, PalMaps.MAPS[id].name])
	_choice(col, "MAP", maps, S.map, func(id): set_and.call("map", id), PalMaps.MAP_IDS if fixed else [])
	col.add_child(_label("The campaign travels all four maps; Black Out has its own city." if fixed else PalMaps.MAPS[S.map].blurb, 13, DIM, true))
	_choice(col, "SIZE", [["std", "STANDARD · 16×16"], ["xl", "XL · 24×24"]], S.size, func(id): set_and.call("size", id), ["std", "xl"] if S.mode == "blackout" else [])
	col.add_child(_label("XL: a bigger yard and about 40% more raiders.", 13, DIM))
	_choice(col, "THREAT", [["easy", "EASY"], ["normal", "NORMAL"], ["hard", "HARD"]], S.diff, func(id): set_and.call("diff", id))
	var cls: Array = Pal.CLASS_IDS.map(func(id): return [id, Pal.CLASSES[id].name])
	_choice(col, "YOUR CLASS", cls, S.cls, func(id): set_and.call("cls", id))
	col.add_child(_label("%s · %s" % [Pal.CLASSES[S.cls].name, CLASS_TEXT[S.cls][0]], 13, GOLD))
	col.add_child(_label(CLASS_TEXT[S.cls][1], 13, DIM, true))
	col.add_child(_label("MODIFIERS", 12, DIM))
	col.add_child(_label("Harder rules pay more rewards.", 13, DIM))
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	var allowed := Sim.clean_mods(Sim.MODS.map(func(M): return M.id), S.mode)
	hint = _label("Pick a modifier to see what it does.", 13, DIM, true)
	for M in Sim.MODS:
		if not allowed.has(M.id):
			continue
		var b := Button.new()
		b.text = M.name
		b.toggle_mode = true
		b.button_pressed = S.mods.has(M.id)
		var id: String = M.id
		var what: String = M.what
		b.toggled.connect(func(on: bool):
			if on and not S.mods.has(id):
				S.mods.append(id)
			elif not on:
				S.mods.erase(id)
			S.mods = Sim.clean_mods(S.mods, S.mode)
			m.settings.save()
			hint.text = what)
		b.focus_entered.connect(func(): hint.text = what)
		b.mouse_entered.connect(func(): hint.text = what)
		grid.add_child(b)
	col.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	_button("PLAY", func(): m.start_game(), row)
	_button("DONE", func(): show_main(), row)
	_focus_first()


# ---------------------------------------------------------------- settings

func show_settings() -> void:
	_clear()
	screen = "settings"
	var D: Dictionary = m.settings.data
	var col := _card(620, "SETTINGS")
	col.add_child(_label("SOUND", 12, DIM))
	_slider(col, "MASTER VOLUME", D.volume, 0, 1, func(x): D.volume = x)
	_slider(col, "MUSIC", D.music, 0, 1, func(x): D.music = x)
	col.add_child(_label("SCREEN", 12, DIM))
	_slider(col, "SCREEN SHAKE", D.shake, 0, 1, func(x): D.shake = x)
	_slider(col, "ZOOM", D.zoom, 0.7, 1.4, func(x): D.zoom = x)
	_choice(col, "MESSAGE TIME", [["1", "NORMAL"], ["1.5", "LONG"], ["2", "VERY LONG"]], str(D.msgTime).trim_suffix(".0"), func(id):
		D.msgTime = float(id)
		_apply()
		show_settings())
	_choice(col, "FRAME RATE", [["auto", "AUTO"], ["30", "30 FPS"], ["60", "60 FPS"]], D.fpsMode, func(id):
		D.fpsMode = id
		_apply()
		show_settings())
	col.add_child(_label("Auto follows your display. 30 FPS keeps laptops coolest.", 13, DIM, true))
	_check(col, "Fullscreen", D.fullscreen, func(on): D.fullscreen = on)
	_check(col, "VSync", D.vsync, func(on): D.vsync = on)
	_check(col, "Show frame rate", D.fps, func(on): D.fps = on)
	_check(col, "Show tips during games", D.tips, func(on): D.tips = on)
	col.add_child(_label("FEEL", 12, DIM))
	_check(col, "Controller rumble on hits and blasts", D.haptics, func(on): D.haptics = on)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	_button("CONTROLS", func(): show_controls(), row)
	_button("BACK", func(): back(), row)
	_focus_first()


func _apply() -> void:
	m.apply_settings()
	m.settings.save()


func _slider(col: VBoxContainer, title: String, val: float, lo: float, hi: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var l := _label(title, 14)
	l.custom_minimum_size = Vector2(170, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = val
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_ALL
	row.add_child(s)
	var v := _label("%d%%" % roundi(val * 100), 14, GOLD)
	v.custom_minimum_size = Vector2(56, 0)
	row.add_child(v)
	s.value_changed.connect(func(x: float):
		v.text = "%d%%" % roundi(x * 100)
		cb.call(x)
		_apply())


func _check(col: VBoxContainer, title: String, val: bool, cb: Callable) -> void:
	var c := CheckBox.new()
	c.text = title
	c.button_pressed = val
	c.toggled.connect(func(on: bool):
		cb.call(on)
		_apply())
	col.add_child(c)


# ---------------------------------------------------------------- controls: keys and controller buttons

func show_controls() -> void:
	_clear()
	screen = "controls"
	var st: PalSettings = m.settings
	var col := _card(700, "CONTROLS")
	var inp: PalInput = m.inp
	col.add_child(_label(("Controller connected (%s buttons). " % ("PlayStation" if inp.pad_kind == "ps" else "Xbox-style")) if inp.pad_dev >= 0 else "No controller found. Plug one in or pair it, then press any button on it. ", 13, DIM, true))
	col.add_child(_label("Pick an action, then press the key (or controller button) you want for it. Esc cancels.", 13, DIM, true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	col.add_child(grid)
	grid.add_child(_label("ACTION", 12, DIM))
	grid.add_child(_label("KEYBOARD", 12, DIM))
	grid.add_child(_label("CONTROLLER", 12, DIM))
	for a in PalSettings.ACTIONS:
		var id: String = a[0]
		var l := _label(a[1], 14)
		l.custom_minimum_size = Vector2(200, 0)
		grid.add_child(l)
		var kb := Button.new()
		kb.text = "PRESS A KEY" if binding == "k:" + id else st.keys_label(id)
		kb.custom_minimum_size = Vector2(170, 0)
		kb.pressed.connect(func():
			binding = "k:" + id
			kb.text = "PRESS A KEY")
		grid.add_child(kb)
		var pb := Button.new()
		var fixed := id == "pause" or id in ["up", "down", "left", "right"]
		pb.text = ("LEFT STICK" if id in ["up", "down", "left", "right"] else PalSettings.glyph(st.data.pad.get(id, -1), inp.pad_kind))
		pb.disabled = fixed
		pb.custom_minimum_size = Vector2(130, 0)
		pb.pressed.connect(func():
			pb.text = "PRESS A BUTTON"
			inp.start_bind(id, func(_b):
				m.settings.save()
				show_controls()))
		grid.add_child(pb)
	col.add_child(_label("Fixed: aim with the mouse or the right stick; the menu button pauses.", 13, DIM, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	_button("RESET KEYS", func():
		st.reset_keys()
		st.apply_keys()
		st.save()
		show_controls(), row)
	_button("RESET BUTTONS", func():
		st.reset_pad()
		st.save()
		show_controls(), row)
	_button("BACK", func(): show_settings(), row)
	_focus_first()


## a key pressed while an action waits for one; true when it was taken
func bind_key(e: InputEventKey) -> bool:
	if not binding.begins_with("k:"):
		return false
	var id := binding.substr(2)
	binding = ""
	if e.keycode != KEY_ESCAPE:
		var st: PalSettings = m.settings
		for k in st.data.keys:   # a key does one thing: whoever had it gives it up
			if k != id:
				st.data.keys[k] = st.data.keys[k].filter(func(x): return x != e.keycode)
		st.data.keys[id] = [e.keycode]
		st.apply_keys()
		st.save()
	show_controls()
	return true


# ---------------------------------------------------------------- the index

func show_index(tab: String) -> void:
	_clear()
	screen = "index"
	var col := _card(760, "INDEX")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	col.add_child(tabs)
	for t in [["classes", "CLASSES"], ["raiders", "RAIDERS"], ["bosses", "BOSSES"], ["keys", "HOW TO PLAY"]]:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.button_pressed = t[0] == tab
		var id: String = t[0]
		b.pressed.connect(func(): show_index(id))
		tabs.add_child(b)
	match tab:
		"classes":
			col.add_child(_label("Pick your class in Match Setup.", 13, DIM))
			for id in Pal.CLASS_IDS:
				col.add_child(_label("%s · %s" % [Pal.CLASSES[id].name, CLASS_TEXT[id][0]], 16, GOLD))
				col.add_child(_label(CLASS_TEXT[id][1], 13, PAPER, true))
		"raiders":
			col.add_child(_label("Who comes over the fence, and when.", 13, DIM))
			for r in IDX_RAIDERS:
				var E: Dictionary = Pal.ETYPES[r[0]]
				col.add_child(_label(Sim.ENAMES[r[0]][0].to_upper(), 16, GOLD))
				col.add_child(_label("%d health · speed %s · from raid %d" % [int(E.hp), str(E.speed), r[1]], 12, DIM))
				col.add_child(_label(r[2], 13, PAPER, true))
		"bosses":
			col.add_child(_label("Every boss, every attack and its warning, and the ammo that hurts him most.", 13, DIM, true))
			for grp in IDX_BOSSES:
				col.add_child(_label(grp[0], 12, DIM))
				for bd in grp[1]:
					var B: Dictionary = Sim.boss_def(bd[0])
					col.add_child(_label(B.name, 16, Color(B.col)))
					var where: String = bd[1]
					if where == "":
						var ms: Array = PalMaps.MAP_IDS.filter(func(k): return PalMaps.MAPS[k].bosses.has(bd[0])).map(func(k): return PalMaps.MAPS[k].short)
						where = (", ".join(ms) + " · every 5th raid") if not ms.is_empty() else "Boss raids"
					col.add_child(_label("%d base health · %s" % [roundi(B.hp * Sim.BOSS_HP), where], 12, DIM))
					for s in bd[2]:
						col.add_child(_label("· " + s, 13, PAPER, true))
					if bd[3] != "":
						col.add_child(_label(bd[3], 13, Color("#e0a050"), true))
					var wk: String = Sim.BOSS_WEAK.get(bd[0], Sim.BOSS_WEAK2.get(bd[0], ""))
					for A in Sim.AMMO:
						if A.id == wk:
							col.add_child(_label("WEAK TO %s (+35%% bullet damage)" % A.name, 12, Color(A.col)))
				if grp[0] == "CITY BLACK OUT":
					col.add_child(_label("THE EIGHT POINTS", 16, GOLD))
					col.add_child(_label("Each point gives a perk while it holds. A lost major point adds a squad to every final-push wave; a lost minor point gives final-push bosses +5% health.", 13, DIM, true))
					for P in PalMaps.CITY_POIS:
						col.add_child(_label("· %s%s: %s" % [P[1], " (major)" if P[2] else "", P[4]], 13, PAPER, true))
		_:
			var st: PalSettings = m.settings
			col.add_child(_label("Hold the stake. Build walls between it and the raiders, gather between raids, and spend salvage at the armory.", 13, PAPER, true))
			for a in PalSettings.ACTIONS:
				col.add_child(_label("%s · %s%s" % [a[1], st.keys_label(a[0]), ("  ·  pad " + PalSettings.glyph(st.data.pad.get(a[0], -1), m.inp.pad_kind)) if st.data.pad.get(a[0], -1) >= 0 else ""], 13, PAPER))
			col.add_child(_label("Aim with the mouse and hold the left button to fire, or use the right stick and the right trigger. On a touch screen the left thumb moves, the right one aims and fires.", 13, DIM, true))
			col.add_child(_label("Walk into a wood pile, kiln or scrap heap to gather. Walls go on the tile you face; SPACE on a wall upgrades or repairs it. Doors let your crew through, not raiders.", 13, DIM, true))
	_button("DONE", func(): back(), col)
	_focus_first()


# ---------------------------------------------------------------- pause and results

func show_pause() -> void:
	_clear()
	screen = "pause"
	var col := _card(380, "PAUSED")
	col.add_child(_label(setup_line(), 12, DIM, true))
	_button("RESUME", func(): m.do_action("pause"), col)
	if m.net.is_online():
		col.add_child(_label("Online: the match keeps going while this menu is open.", 12, DIM, true))
	else:
		_button("RESTART", func(): m.start_game(), col)
	_button("SKILL TREE", func(): m.open_skills(), col)
	_button("INDEX", func(): _go("pause", "index"), col)
	_button("SETTINGS", func(): _go("pause", "settings"), col)
	_button("LEAVE THE GAME" if m.net.is_online() else "QUIT TO MENU", func(): m.to_menu(), col)
	_focus_first()


func show_results() -> void:
	_clear()
	screen = "results"
	var s: Sim = m.sim
	var g: Dictionary = s.game
	var p: Dictionary = s.player
	var win: bool = g.won
	var W: float = g.waves
	var endless := is_inf(W)
	var mods: Array = s.mods.map(func(id): return _mod(id).name)
	var modt := (" · " + " + ".join(mods)) if not mods.is_empty() else ""
	var mode_n: String = "OPERATION WHITEOUT" if s.campaign() else ("ENDLESS" if endless else "%d RAIDS" % int(W))
	var held: int = s.bo_stages() if s.blackout() else (int(W) if win or g.end_reason in ["evac", "left"] else (g.wave if g.end_reason == "evacfail" else maxi(0, g.wave - 1)))
	var title := "CLAIM HELD" if win else "CLAIM LOST"
	var eyebrow := "%s · %s · %s · %s%s" % [p.C.name, s.Df.name, mode_n, ("ALL %d RAIDS BROKEN" % int(W)) if win else ("%d RAIDS HELD" % held if endless else "STAKE FELL IN RAID %d" % g.wave), modt]
	var lede := "The stake is still standing. Try it with less wood and more nerve, or turn the threat up." if win else ("Endless only ends one way. %d raids is the number to beat." % held if endless else "They got to the core. Look at where they broke in. That hole is the lesson.")
	match g.end_reason:
		"evacfail":
			eyebrow = eyebrow.replace("STAKE FELL IN RAID %d" % g.wave, "EVAC FAILED · CHAPTER %d" % (g.chapter + 1))
			lede = "Nobody made the convoy out of %s. The campaign ends here." % s.map_def.name
		"deadend":
			eyebrow = eyebrow.replace("STAKE FELL IN RAID %d" % g.wave, "CREW LOST IN RAID %d" % g.wave)
			lede = "The crew could not recover. No one left could get them back up."
		"evac", "left":
			var ok: bool = g.end_reason == "evac"
			title = "EVACUATED" if ok else "LEFT BEHIND"
			eyebrow = "%s · %s · %s · %s%s" % [p.C.name, s.Df.name, "OPERATION WHITEOUT" if s.campaign() else "BLITZKRIEG RUSH", "VICTORY" if ok else "HALF REWARDS", modt]
			lede = "You made it out of the Final Blitz." if ok else "The evac left without you: half your cases and shards this time. Raids, boss kills and skill points still count in full."
	if s.blackout():
		var B: Dictionary = g.bo if g.bo != null else {"held": 0, "destroyer": false, "push": null}
		title = "THE CITY HELD" if win else "COMMAND FELL"
		eyebrow = "%s · %s · CITY BLACK OUT · %d OF 8 POINTS HELD%s%s" % [p.C.name, s.Df.name, B.held, " · THE DESTROYER IS DOWN" if B.destroyer else "", modt]
		lede = ("The Supreme Destroyer is scrap and the lights are coming back on." if B.destroyer else "Main Command stood until the clock ran out.") if win else ("Main Command fell in the final push. Hold more points next time: every one lost makes the push harder." if B.push != null else "Main Command fell before the final push.")
	if s.pvp() != "":
		var P: Array = s.players.values()
		if s.pvp() == "base":
			var wT: Dictionary = Pal.TEAMS.get(g.winner, Pal.TEAMS.a)
			var na := P.filter(func(o): return o.team == "a").size()
			title = "YOUR SIDE WON" if win else "YOUR SIDE LOST"
			eyebrow = "BASE BATTLE · %dV%d · %s TOOK THE %s STAKE%s" % [na, P.size() - na, wT.name, "EAST" if g.winner == "a" else "WEST", modt]
			lede = "Their stake is splinters. Run it back and swap sides if it was lopsided." if win else "They got through. Look at which wall went first; that's where to put metal next time."
		else:
			var rank := P.duplicate()
			rank.sort_custom(func(a, b): return a.kills > b.kills or (a.kills == b.kills and a.deaths < b.deaths))
			title = "YOU WIN" if win else "%s WINS" % str(rank[0].name).to_upper()
			eyebrow = "FREE-FOR-ALL · %d PLAYERS%s" % [P.size(), modt]
			lede = "   ".join(range(rank.size()).map(func(i): return "%d. %s %d" % [i + 1, "YOU" if is_same(rank[i], p) else str(rank[i].name).to_upper(), rank[i].kills]))
	var col := _card(640, "", eyebrow)
	col.add_child(_label(title, 40, GOLD if win or g.end_reason == "evac" else RED))
	col.add_child(_label(lede, 14, PAPER, true))
	var st: Dictionary = g.stats
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	col.add_child(grid)
	var rows: Array = [["RAIDS HELD", held], ["RAIDERS DROPPED", st.dropped], ["WALLS RAISED", st.built], ["WALLS LOST", st.lost], ["REPAIRS", st.get("repairs", 0)], ["REVIVES", st.get("revives", 0)]]
	if s.pvp() != "":
		rows = [["YOUR DROPS", p.kills], ["TIMES YOU FELL", p.deaths], ["WALLS RAISED", st.built], ["WALLS LOST", st.lost]]
	for row in rows:
		var v := VBoxContainer.new()
		v.add_child(_label(str(row[1]), 24, PAPER))
		v.add_child(_label(row[0], 11, DIM))
		grid.add_child(v)
	if not m.last_reward.is_empty():
		col.add_child(_label("REWARDS", 12, DIM))
		col.add_child(reward_cards(m.last_reward))
		col.add_child(_label(m.last_reward.text, 13, DIM, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	if m.net.mode == "host":
		_button("BACK TO THE LOBBY", func(): m.net_back_to_lobby(), row)
	elif m.net.mode == "guest":
		col.add_child(_label("Waiting for the host to go back to the lobby.", 13, DIM, true))
	else:
		_button("PLAY AGAIN", func(): m.start_game(), row)
	_button("SKILL TREE", func(): m.open_skills(), row)
	_button("LEAVE" if m.net.is_online() else "MAIN MENU", func(): m.to_menu(), row)
	_focus_first()


func _go(from: String, to: String) -> void:
	came_from = from
	if to == "index":
		show_index("classes")
	else:
		show_settings()


## B, Esc: back out of the current screen
func back() -> void:
	match screen:
		"setup", "locker", "account", "online":
			show_main()
		"lobby":
			m.net_leave()
		"settings", "index":
			if came_from == "pause":
				show_pause()
			else:
				show_main()
		"controls":
			show_settings()
		"pause":
			m.do_action("pause")


## showRewards: cards for what the run paid, cases, shards, skill points, new items, the nearest milestone and
## the way to the next Supply Case. They come in one after another.
func reward_cards(R: Dictionary) -> HFlowContainer:
	var C := PalLocker.catalog()
	var L: PalLocker = m.locker
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	var cards: Array = []
	if R.get("pending"):
		var pc := PanelContainer.new()
		row.add_child(pc)
		var v := VBoxContainer.new()
		pc.add_child(v)
		v.add_child(_label("SAVING", 13, GOLD))
		v.add_child(_label("Sending your result to your account…", 11, DIM, true))
		return row
	var card := func(border: Color) -> VBoxContainer:
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(20 / 255.0, 17 / 255.0, 13 / 255.0, 0.95)
		sb.border_color = border
		sb.set_border_width_all(1)
		sb.border_width_top = 3
		sb.set_content_margin_all(8)
		pc.add_theme_stylebox_override("panel", sb)
		pc.custom_minimum_size = Vector2(112, 0)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		pc.add_child(v)
		row.add_child(pc)
		cards.append(pc)
		return v
	for id in R.cases:
		if R.cases[id] > 0 and C.CASES.has(id):
			var v: VBoxContainer = card.call(Color(C.CASES[id].col))
			var ic := LockerUI.CaseIcon.new(id, 64)
			ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(ic)
			v.add_child(_label("×%d" % R.cases[id], 20, PAPER))
			v.add_child(_label(C.CASES[id].name, 10, DIM))
	if R.shards > 0:
		var v: VBoxContainer = card.call(Color("#8fd8ff"))
		v.add_child(_label("◆ +%d" % R.shards, 22, Color("#bfe9ff")))
		v.add_child(_label("SHARDS", 10, DIM))
	if R.sp > 0:
		var v: VBoxContainer = card.call(GOLD)
		v.add_child(_label("✦ +%d" % R.sp, 22, GOLD))
		v.add_child(_label("SKILL POINT" if R.sp == 1 else "SKILL POINTS", 10, DIM))
	for uid in R.unlocked:
		var c := PalLocker.item(uid)
		if c.is_empty():
			continue
		var v: VBoxContainer = card.call(Color(C.RAR[c.r].col))
		v.add_child(_label("UNLOCKED", 10, Color(C.RAR[c.r].col)))
		var ic := LockerUI.Icon.new(c, 72, L.eq.duplicate(), m.settings.data.setup.get("cls", "soldier"))
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		v.add_child(_label(c.name, 11, PAPER))
	if R.get("kind") == "run":
		var best = null   # the ladder this player is closest to finishing a step of
		for Ld in C.LADDERS:
			var i := -1
			for k in Ld.items.size():
				if not L.owns(Ld.items[k][0] + ":" + Ld.items[k][1]):
					i = k
					break
			if i < 0:
				continue
			var have := int(L.st.get(Ld.sts[i] if Ld.get("sts") else Ld.st, 0))
			if have <= 0:
				continue
			var f: float = float(have) / Ld.steps[i]
			if best == null or f > best.f:
				best = {"L": Ld, "i": i, "f": f, "have": have}
		if best != null:
			var Ld: Dictionary = best.L
			var it := PalLocker.item(Ld.items[best.i][0] + ":" + Ld.items[best.i][1])
			var v: VBoxContainer = card.call(GOLD)
			v.add_child(_label(Ld.title, 11, GOLD))
			var pb := ProgressBar.new()
			pb.max_value = Ld.steps[best.i]
			pb.value = best.have
			pb.show_percentage = false
			pb.custom_minimum_size = Vector2(140, 8)
			v.add_child(pb)
			v.add_child(_label("%d / %d %s · next: %s" % [best.have, Ld.steps[best.i], Ld.units[best.i] if Ld.get("units") else Ld.unit, it.get("name", "")], 10, DIM, true))
		var v: VBoxContainer = card.call(Color("#e2b436"))
		v.add_child(_label("SUPPLY CASE", 11, GOLD))
		var pb := ProgressBar.new()
		pb.max_value = 3
		pb.value = R.get("prog", 0)
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(140, 8)
		v.add_child(pb)
		v.add_child(_label("1 more raid to the next case" if R.get("toNext", 3) == 1 else "%d more raids to the next case" % R.get("toNext", 3), 10, DIM, true))
	if cards.is_empty():
		var v: VBoxContainer = card.call(Color("#4a4030"))
		v.add_child(_label("NO REWARDS", 13, DIM))
		v.add_child(_label("Hold a raid or win to earn cases.", 10, DIM, true))
	for i in cards.size():   # one after another over about 1.5 s
		var pc: Control = cards[i]
		pc.modulate.a = 0.0
		var tw := pc.create_tween()
		tw.tween_interval(i * minf(0.32, 1.5 / cards.size()))
		tw.tween_property(pc, "modulate:a", 1.0, 0.25)
	return row


# ---------------------------------------------------------------- the account page (19-accounts.js renderAcct)

func _acct_tag() -> String:
	var A: PalAccount = m.account
	match A.state:
		"wait":
			return "CONNECTING"
		"guest":
			return "GUEST"
		"full":
			return A.name_.to_upper() if A.name_ != "" else "SIGNED IN"
	return "OFFLINE"


## the account told us something changed: redraw what shows it
func on_account_changed() -> void:
	match screen:
		"account":
			if not acct_busy:
				show_account()
		"locker":
			for ch in root.get_children():
				if ch is LockerUI and not ch.busy and not ch.get_children().any(func(n): return n is CaseOpen):
					ch.refresh()
		"main":
			pass


var acct_busy := false


func _acct_do(fn: Callable) -> void:
	if acct_busy:
		return
	acct_busy = true
	m.account.msg = ""
	show_account()
	var out = await fn.call()
	m.account.msg = out if out is String else ""
	acct_busy = false
	show_account()


func _field(col: VBoxContainer, title: String, value: String = "", secret: bool = false, hint_text: String = "") -> LineEdit:
	col.add_child(_label(title, 12, DIM))
	var e := LineEdit.new()
	e.text = value
	e.secret = secret
	e.placeholder_text = hint_text
	e.custom_minimum_size = Vector2(280, 0)
	col.add_child(e)
	return e


func show_account() -> void:
	_clear()
	screen = "account"
	var A: PalAccount = m.account
	var st := A.state
	var g := A.is_guest()
	var live := st == "guest" or st == "full"
	var u: Dictionary = A.s.get("user") if A.s.get("user") is Dictionary else {}
	var title := (A.name_ if A.name_ != "" else ("GUEST" if g else "SIGNED IN")) if live else ("CONNECTING" if st == "wait" else "NO ACCOUNT")
	var col := _card(520, title, "ACCOUNT")
	var lede := ""
	match st:
		"off":
			lede = "This build is playing offline. Your locker is saved on this PC."
		"wait":
			lede = "Connecting to your account…"
		"down":
			lede = "Can't reach the account server right now. You can still play: finished runs are sent when you're back online, and opening cases waits for a connection." if A.signed_in() else "No account yet. Your locker is saved on this PC, and it moves into your account once one is made."
		_:
			lede = "You're playing as a guest. Your locker is backed up online, but only this PC can get back into it. Add an email to keep it on any device, or sign in to an account you already have." if g else "Signed in%s%s. Your locker is saved to your account and follows you to any device you sign in on, the browser game included." % [(" as " + A.name_) if A.name_ != "" else "", (" · " + u.email) if u.get("email") else ""]
	col.add_child(_label(lede, 14, PAPER, true))
	if A.msg != "":
		col.add_child(_label(A.msg, 13, GOLD, true))
	var dis := acct_busy or st == "wait"
	if st == "down":
		_button("TRY AGAIN", func():
			A.msg = ""
			A.boot(), col).disabled = dis
	if live:
		var un := _field(col, "USERNAME (3 TO 16 LETTERS, NUMBERS OR _)", A.name_)
		_button("SAVE NAME", func():
			var n := un.text.strip_edges()
			if not RegEx.create_from_string("^[A-Za-z0-9_]{3,16}$").search(n):
				A.msg = "Usernames are 3 to 16 letters, numbers or _."
				show_account()
				return
			_acct_do(func(): return await A.set_username(n)), col).disabled = dis
	if live and g:
		var mail := _field(col, "ADD AN EMAIL TO KEEP THIS LOCKER ON ANY DEVICE", "", false, "you@example.com")
		_button("SEND LINK", func():
			var mm := mail.text.strip_edges()
			if not RegEx.create_from_string("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$").search(mm):
				A.msg = "That doesn't look like an email address."
				show_account()
				return
			_acct_do(func(): return await A.link_email(mm)), col).disabled = dis
	if live and not g and A.needs_password():
		var pw := _field(col, "SET A PASSWORD (AT LEAST 8 CHARACTERS)", "", true)
		_button("SAVE PASSWORD", func():
			if pw.text.length() < 8:
				A.msg = "Pick a longer password: at least 8 characters."
				show_account()
				return
			_acct_do(func(): return await A.set_password(pw.text)), col).disabled = dis
	if st == "guest" or (st == "down" and not A.signed_in()):
		col.add_child(_label("SIGN IN TO AN ACCOUNT YOU ALREADY HAVE", 12, GOLD))
		var im := _field(col, "EMAIL", "", false, "you@example.com")
		var ip := _field(col, "PASSWORD", "", true)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		col.add_child(row)
		_button("SIGN IN", func():
			var mm := im.text.strip_edges()
			if mm == "" or ip.text == "":
				A.msg = "Enter your email and password."
				show_account()
				return
			_acct_do(func(): return await A.sign_in(mm, ip.text)), row).disabled = dis
		_button("FORGOT PASSWORD", func():
			var mm := im.text.strip_edges()
			if not mm.contains("@"):
				A.msg = "Type your email above first, then press Forgot password."
				show_account()
				return
			_acct_do(func(): return await A.forgot(mm)), row).disabled = dis
	if live and not g:
		_button("SIGN OUT", func(): _acct_do(func(): return await A.sign_out()), col).disabled = dis
	_button("BACK", func(): show_main(), col)
	_focus_first()


# ---------------------------------------------------------------- online (21-online.js, 19b-social-lobby.js)

var _online_msg: Label
var _code_in: LineEdit


func online_status(text: String) -> void:
	if is_instance_valid(_online_msg):
		_online_msg.text = text


## host a room, or join one with its 4-character code
func show_online(msg: String) -> void:
	_clear()
	screen = "online"
	var col := _card(520, "PLAY ONLINE", "CO-OP AND PVP · UP TO 6 PLAYERS")
	col.add_child(_label("Host a room and share its code, or type a friend's code to join. Browser players and this game share rooms.", 14, PAPER, true))
	_button("HOST A ROOM", func(): m.net_host(), col)
	_code_in = _field(col, "ROOM CODE", "", false, "4 letters and numbers")
	_code_in.max_length = 4
	_code_in.text_submitted.connect(func(t: String): m.net_join(t))
	_button("JOIN", func(): m.net_join(_code_in.text), col)
	_online_msg = _label(msg, 13, RED if msg != "" else DIM, true)
	col.add_child(_online_msg)
	_button("BACK", func(): show_main(), col)
	_focus_first()


const PVP_MODES := [["coop", "CO-OP"], ["base", "BASE BATTLE"], ["ffa", "FREE-FOR-ALL"]]


## the room: who is in it, the host's settings, ready, sides, start, chat
func show_lobby() -> void:
	var n: PalNet = m.net
	if n.mode != "host" and n.mode != "guest":
		show_online("")
		return
	_clear()
	screen = "lobby"
	var host: bool = n.mode == "host"
	var col := _card(720, "ROOM %s" % n.code, "LOBBY · %d OF 6%s" % [n.roster.size(), " · LOCKED" if n.locked else ""])
	col.add_child(_label("Share the code. Everyone readies up, then the host starts.", 13, DIM, true))
	var pv: String = n.pick.pvp
	for i in n.roster.size():
		var r: Dictionary = n.roster[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		col.add_child(row)
		var colr := Color(Pal.TEAMS[r.get("team", "a")].col) if pv == "base" else Color(Pal.SLOTCOL[i % 6])
		var nm := _label(("%s%s" % [str(r.name).to_upper(), " (YOU)" if r.id == n.my_id else ""]), 15, colr)
		nm.custom_minimum_size = Vector2(220, 0)
		row.add_child(nm)
		row.add_child(_label(Pal.CLASSES.get(r.get("cls", "soldier"), Pal.SOLDIER).name, 13, PAPER))
		if pv == "base":
			row.add_child(_label(Pal.TEAMS[r.get("team", "a")].name, 13, colr))
		row.add_child(_label("HOST" if r.id == "host" else ("READY ✓" if r.get("ready", false) else "NOT READY"), 12, GOLD if r.id == "host" or r.get("ready", false) else DIM))
		if host and r.id != "host":
			var rid: String = r.id
			_button("REMOVE", func(): n.kick(rid), row)
	var me: Dictionary = {}
	for r in n.roster:
		if r.id == n.my_id:
			me = r
	var cls: Array = Pal.CLASS_IDS.map(func(id): return [id, Pal.CLASSES[id].name])
	_choice(col, "YOUR CLASS", cls, me.get("cls", m.settings.data.setup.cls), func(id):
		m.settings.data.setup.cls = id
		m.settings.save()
		var nm2: Dictionary = m.net_me()
		n.set_loadout(id, nm2.cos, nm2.name, nm2.sk)
		show_lobby())
	if host:
		var redo := func(k: String, val) -> void:
			n.pick[k] = val
			if k == "mode" or k == "pvp":
				n.pick.mods = Sim.clean_mods(n.pick.mods, n.pick.pvp if n.pick.pvp != "coop" else n.pick.mode)
			n.broadcast_lobby()
			show_lobby()
		_choice(col, "GAME", PVP_MODES, pv, func(id): redo.call("pvp", id))
		if pv == "coop":
			_choice(col, "LENGTH", MODES, n.pick.mode, func(id): redo.call("mode", id))
		var fixed: bool = pv == "coop" and n.pick.mode in ["campaign", "blackout"]
		var maps: Array = PalMaps.MAP_IDS.map(func(id): return [id, PalMaps.MAPS[id].name])
		_choice(col, "MAP", maps, n.pick.map, func(id): redo.call("map", id), PalMaps.MAP_IDS if fixed else (["frost"] if pv != "coop" else []))
		if pv != "coop":
			col.add_child(_label(PalMaps.PVP_BLURB.get(n.pick.map, PalMaps.PVP_BLURB.yard)[pv], 13, DIM, true))
		else:
			_choice(col, "SIZE", [["std", "STANDARD"], ["xl", "XL"]], n.pick.size, func(id): redo.call("size", id))
			_choice(col, "THREAT", [["easy", "EASY"], ["normal", "NORMAL"], ["hard", "HARD"]], n.pick.diff, func(id): redo.call("diff", id))
		var mode_m: String = pv if pv != "coop" else n.pick.mode
		var grid := HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 6)
		col.add_child(_label("MODIFIERS", 12, DIM))
		col.add_child(grid)
		for M in Sim.MODS:
			if not Sim.clean_mods([M.id], mode_m).has(M.id):
				continue
			var b := Button.new()
			b.text = M.name
			b.toggle_mode = true
			b.button_pressed = n.pick.mods.has(M.id)
			b.tooltip_text = M.what
			var id: String = M.id
			b.toggled.connect(func(on: bool):
				if on and not n.pick.mods.has(id):
					n.pick.mods.append(id)
				elif not on:
					n.pick.mods.erase(id)
				n.broadcast_lobby())
			grid.add_child(b)
		if n.pick.mods.has("onejob"):
			_choice(col, "ONE JOB FOR EVERYONE", cls, n.pick.job if n.pick.job != "" else "soldier", func(id): redo.call("job", id))
	else:
		var what: String = PVP_MODES.filter(func(x): return x[0] == pv)[0][1] if pv in ["coop", "base", "ffa"] else "CO-OP"
		col.add_child(_label("%s · %s%s" % [what, PalMaps.MAPS.get(n.pick.map, PalMaps.MAPS.yard).name, (" · " + " + ".join(n.pick.mods.map(func(id): return _mod(id).name))) if not n.pick.mods.is_empty() else ""], 13, GOLD, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	if host:
		_button("START", func(): m.net_start(), row)
		_button("UNLOCK" if n.locked else "LOCK ROOM", func():
			n.set_locked(not n.locked)
			show_lobby(), row)
	else:
		_button("NOT READY" if me.get("ready", false) else "READY", func(): n.set_ready(not me.get("ready", false)), row)
	if pv == "base":
		_button("SWITCH SIDES", func(): n.switch_team(), row)
	_button("LEAVE", func(): m.net_leave(), row)
	_online_msg = _label(n.start_block() if host else "", 13, DIM, true)
	col.add_child(_online_msg)
	col.add_child(_label("CHAT", 12, DIM))
	for line in n.chat.slice(maxi(0, n.chat.size() - 8)):
		col.add_child(_label("%s: %s" % [str(line.name).to_upper(), line.text], 13, Color(line.col), true))
	var chat_in := LineEdit.new()
	chat_in.placeholder_text = "Say something (Enter)"
	chat_in.max_length = 120
	chat_in.text_submitted.connect(func(t: String):
		if t.strip_edges() != "":
			n.send_chat(t)
		chat_in.text = "")
	col.add_child(chat_in)
	_focus_first()
