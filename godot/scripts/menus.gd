class_name Menus
extends CanvasLayer
## The menus, laid out as the browser's desktop lobby (page.html, style.css's #menu.partyMenu and .cardMenu rules,
## 19c-home.js, 19b-social-lobby.js, 22-loop-menus.js): one framed shell with the top bar (PALISADE, the page tabs,
## FRIENDS, the profile chip and the shards), and the pages inside it. PLAY, MULTIPLAYER, the room, LOCKER and INDEX
## stand the crew on the 3D stage (Lobby3D) between their columns; SKILLS, SETTINGS and ACCOUNT are cards; TABLES is
## the old narrow panel. The setup sheet, the friends list, pause, the after-action screen and the save backup are
## overlays. Every control is a Godot control, so the mouse, keys and a controller (through focus) all work them.
## The card pages (settings, account, index, skills, tables) are built by MenuPages (menu_pages.gd).

const VERSION := "v0.11.0"
const NAV := [["main", "PLAY"], ["online", "MULTIPLAYER"], ["locker", "LOCKER"], ["skills", "SKILLS"], ["tables", "TABLES"], ["index", "INDEX"], ["settings", "SETTINGS"]]
const MODES := [["5", "5 RAIDS"], ["10", "10 RAIDS"], ["endless", "ENDLESS"], ["blitz", "BLITZKRIEG"], ["campaign", "CAMPAIGN"], ["blackout", "BLACK OUT"]]
const LEN_NAME := {"5": "5 RAIDS", "10": "10 RAIDS", "endless": "ENDLESS", "blitz": "BLITZKRIEG RUSH", "campaign": "OPERATION WHITEOUT", "blackout": "CITY BLACK OUT", "casino": "THE CASINO"}
const MODE_HINT := {
	"5": "Five raids. A boss on raid 5, at night.",
	"10": "Ten raids. Bosses on raids 5 and 10; golden hour from raid 6, night from raid 9.",
	"endless": "Raids until the stake falls. Each one a notch harder, with a boss every fifth raid and nights in between.",
	"blitz": "15 hard raids, then the Final Blitz: 5 minutes with a new boss every 30 seconds. The last minute is the evacuation: reach the evac site yourself, or leave with half your cases and shards.",
	"campaign": "Operation Whiteout: travel all four maps. Carry upgrades and supplies through 12 raids, then survive the Whiteout Gauntlet and a summit evacuation.",
	"blackout": "City Black Out: a night city. Hold eight points as bosses hit them one by one, then defend Main Command against the Supreme Destroyer.",
}
const CLASS_TEXT := {
	"soldier": ["the door problem", "Burst carbine: 3 rounds a pull, up to 9 with DAMAGE upgrades. Builds 40% faster and takes more hits."],
	"sniper": ["the angle problem", "Bolt-action rifle. Heavy rounds straight through wood. Moves 10% faster."],
	"grenadier": ["the doorway problem", "Pump shotgun: huge up close, tight spread, fires as fast as you click (holding fires every half second), six shells. Three grenades a round. Moves 10% slower."],
	"quartermaster": ["the rescue problem", "Walk over a downed teammate to get them up instantly. Carries 96 of everything, gathers faster, repairs for half. SMG. The only one who can SPRINT."],
}
const PVP_MODES := [["coop", "CO-OP"], ["base", "BASE BATTLE"], ["ffa", "FREE-FOR-ALL"]]
const MODE_NAME := {"coop": "CO-OP", "base": "BASE BATTLE", "ffa": "FREE-FOR-ALL"}
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
## the browser's STAGE.wide: where the party stands on the stage (x, y, scale in a 1000x780 picture); the 3D models
## stand on the same spots (Lobby3D), the painted figures when they aren't in this build (Hero2D)
const STAGE2D := {"me": [500, 722, 13.4], "others": [[250, 660, 8.2], [762, 660, 8.2], [88, 612, 7.4], [918, 612, 7.4], [395, 568, 6.8]]}

var m   # the main node
var root: Control
var screen := ""
var came_from := ""   # where BACK goes from settings, the index and the skill tree (the main menu or the pause menu)
var binding := ""   # Settings: an action waiting for a key
var stage: Lobby3D   # the 3D crew over the painted background, kept across screens (null: the painted figures)
var pages: MenuPages
var armory: ArmoryUI   # the armory over the game (it shows itself while the main node's armory is open)
var sheet := ""   # the open tab of the setup sheet, "" while it's closed
var sheet_kind := "home"   # home (PLAY), host (MULTIPLAYER, before hosting) or room (the room, host only)
var friends_tab := "friends"
var acct_busy := false
var how_open := false   # PLAY: HOW TO PLAY unfolded
var _under := ""   # the page the friends list was opened over
var _redo: Callable   # builds the open page again (a window resize)
var _focus: Control   # where a controller lands first on the open page
var _stage_hero: Control   # the stage column's hero box (the browser's partyHero): the stage canvas is fitted into it
var _hero2d: Hero2D
var _online_msg: Label
var _code_in: LineEdit
var _friends_btn: UiKit.Btn
var _friends_dot: Label
var _sheet_node: Control
var _drop: Control
var _size := Vector2.ZERO
var _cas_modal := false   # a casino modal (hand history, house rules) is up over TABLES


func _init(main) -> void:
	m = main
	layer = 5


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_size = _vs()
	UiKit.fit(_size.x, _size.y)
	pages = MenuPages.new(self)
	armory = ArmoryUI.new(m)
	add_child(armory)
	get_viewport().size_changed.connect(_on_resize)


func _vs() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(m.v.W, m.v.H)


func _on_resize() -> void:
	var s := _vs()
	if s == _size:
		return
	_size = s
	UiKit.fit(s.x, s.y)
	if screen != "" and _redo.is_valid():
		var tab := sheet
		var kind := sheet_kind
		var fr := screen == "friends"
		_redo.call()
		if tab != "":
			_open_sheet(tab, kind)
		if fr:
			show_friends()


## focus rings show for keys and the controller, not the mouse (:focus-visible)
func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton or (e is InputEventMouseMotion and e.relative.length() > 2):
		if not UiKit.mouse_ui:
			UiKit.set_mouse_ui(true)
	elif (e is InputEventKey and e.pressed) or e is InputEventJoypadButton or (e is InputEventJoypadMotion and absf(e.axis_value) > 0.5):
		if UiKit.mouse_ui:
			UiKit.set_mouse_ui(false)


func _process(_dt: float) -> void:
	if _cas_modal and m.casino_ui != null and not m.casino_ui.modal_open():
		_cas_modal = false
		m.casino_ui.layer = 4


func active() -> bool:
	return screen != ""


func close() -> void:
	screen = ""
	binding = ""
	sheet = ""
	_redo = Callable()
	for ch in root.get_children():
		if ch == stage or (stage != null and ch == stage.under):   # kept for the next time the menus open: its models stay loaded
			root.remove_child(ch)
			continue
		ch.queue_free()


func _clear() -> void:
	for ch in root.get_children():
		root.remove_child(ch)
		if ch != stage and (stage == null or ch != stage.under):
			ch.queue_free()
	sheet = ""
	_sheet_node = null
	_drop = null
	_focus = null
	_stage_hero = null
	_hero2d = null
	_online_msg = null
	_friends_btn = null
	_friends_dot = null
	if m.demo and m.locker != null:   # outside a game the menus sit on the lobby: the painted background, the 3D crew over it
		root.add_child(LockerUI.BgView.new(lobby_bg()))
		if stage == null and Lobby3D.available():
			stage = Lobby3D.new()
		if stage != null:
			root.add_child(stage.under)   # the auras' ground part, under the crew
			root.add_child(stage)


func _begin(name: String, redo: Callable) -> void:
	_clear()
	screen = name
	_redo = redo


func lobby_bg() -> String:
	var id: String = m.locker.eq.get("bg", "campfire") if m.locker != null else "campfire"
	return id if PalLocker.catalog().BGS.has(id) else "campfire"


## the equipped background changed: swap the one behind the menus
func refresh_bg() -> void:
	if stage != null:
		_stage_crew()
	for ch in root.get_children():
		if ch is LockerUI.BgView:
			var nb := LockerUI.BgView.new(lobby_bg())
			root.add_child(nb)
			root.move_child(nb, ch.get_index())
			root.remove_child(ch)
			ch.queue_free()
			return


func _me() -> Dictionary:
	return {"name": my_name(), "cls": str(m.settings.data.setup.cls), "cos": m.locker.eq.duplicate(), "ready": false, "slot": 0}


func my_name() -> String:
	var A: PalAccount = m.account
	if A != null and A.state == "full" and A.name_ != "":
		return A.name_
	var n := str(m.settings.data.get("name", "")).strip_edges()
	return n if n != "" else "Big U"


## who stands on the stage, and where: the page's middle column. The room stands everyone (this player in front);
## the other stage pages this player alone; the card pages nobody.
func _stage_crew() -> void:
	if screen == "" or not is_inside_tree():
		return
	var box := Rect2()
	if is_instance_valid(_stage_hero) and _stage_hero.is_inside_tree():
		box = _stage_hero.get_global_rect()
	var crew: Array = []
	var mode := "solo"
	var who := screen if screen != "friends" else _under
	if who == "lobby" and m.net.is_online():
		mode = "party"
		var rest: Array = []
		for i in m.net.roster.size():
			var r: Dictionary = m.net.roster[i]
			var p := {"name": str(r.get("name", "")), "cls": str(r.get("cls", "soldier")), "cos": PalLocker.parse_cos(str(r.get("cos", ""))),
				"ready": bool(r.get("ready", false)) or r.get("id", "") == "host", "slot": i}
			if r.get("id", "") == m.net.my_id:
				crew.append(p)
			else:
				rest.append(p)
		crew.append_array(rest)
	elif who == "online":
		mode = "party"
		crew = [_me()]
	elif who in ["main", "locker", "index"]:
		mode = "locker" if who == "locker" else "solo"
		crew = [_me()]
	if stage != null and stage.is_inside_tree():
		stage.set_crew(mode, crew, box)
	if is_instance_valid(_hero2d):
		_hero2d.set_people(crew, mode, stage == null)


## after a page is built: the layout settles, then the crew takes its place and the controller its first stop
func _settle() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_stage_crew()
	_focus_first()


func _focus_first() -> void:
	if not is_inside_tree():
		return
	var f: Control = _focus if is_instance_valid(_focus) and _focus.is_visible_in_tree() else _first_focusable(root)
	if f != null and f.is_inside_tree():
		f.grab_focus()


func _first_focusable(n: Node) -> Control:
	for ch in n.get_children():
		if ch is BaseButton and not ch.disabled and ch.is_visible_in_tree() and ch.focus_mode != Control.FOCUS_NONE:
			return ch
		var r := _first_focusable(ch)
		if r != null:
			return r
	return null


## a node with a focus id, so a rebuilt page puts the focus back where it was
func _fid(c: Control, id: String) -> Control:
	c.set_meta("fid", id)
	return c


func _refocus(id: String) -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var n := _find_fid(root, id)
	if n != null and n.is_visible_in_tree():
		n.grab_focus()


func _find_fid(n: Node, id: String) -> Control:
	for ch in n.get_children():
		if ch is Control and str(ch.get_meta("fid", "")) == id:
			return ch
		var r := _find_fid(ch, id)
		if r != null:
			return r
	return null


func _focused_fid() -> String:
	var f := get_viewport().gui_get_focus_owner()
	return str(f.get_meta("fid", "")) if f != null else ""


## LB / RB on a controller: the next or the previous page tab
func page_step(d: int) -> void:
	var cur := _nav_of(screen if screen != "friends" else _under)
	if cur == "" or not m.demo:
		return
	var i := 0
	for k in NAV.size():
		if NAV[k][0] == cur:
			i = k
	_go_nav(NAV[(i + d + NAV.size()) % NAV.size()][0])


# ---------------------------------------------------------------- small builders

func _l(text: String, f: String, size: float, col: Color, em: float = 0.0, lh: float = 0.0, wrap: bool = false) -> Label:
	return UiKit.lbl(text, f, size, col, em, lh, wrap)


## the old helpers other screens still use (the casino sheet, the case opening)
func _label(text: String, size: int = 15, col: Color = UiKit.OBONE, wrap: bool = false) -> Label:
	return UiKit.lbl(text, "m4", size, col, 0.0, 0.0, wrap)


func _button(text: String, cb: Callable, row: Container = null) -> UiKit.Btn:
	var b := UiKit.btn(text, "oghost", 15, cb, {"h": 40, "pad": [0, 14, 0, 14]})
	if row != null:
		row.add_child(b)
	return b


## .pt: the column's title, underlined
func _pt(text: String, size: float = 23.0, col: Color = UiKit.WARN) -> VBoxContainer:
	var v := UiKit.vbox(0)
	v.add_child(_l(text, "s9", size, col, 0.08))
	v.add_child(UiKit.spacer(10))
	v.add_child(UiKit.rule())
	return v


## h2 in the lobby columns: a small stencil caption
func _h2(text: String, col: Color = UiKit.DIM, size: float = 13.0) -> Label:
	return _l(text, "s8", size, col, 0.16)


func _lede(text: String, col: Color = UiKit.SUB, size: float = 11.0) -> Label:
	return _l(text, "m4", size, col, 0.0, 1.55, true)


## the side columns' panel (.partyControls / .lockPanel): returns [panel, the column inside it]
func _side_panel(width: float, scroll: bool = true, pad: float = 16.0) -> Array:
	var p := UiKit.panel(UiKit.PANEL, UiKit.PLINE, 1, pad)
	p.custom_minimum_size.x = UiKit.px(width)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := UiKit.vbox(10)
	if scroll:
		var sc := UiKit.scroller(col)
		p.add_child(sc)
	else:
		p.add_child(col)
	return [p, col]


## a box with something drawn behind it (the campaign card's wash): a container that fills both
func _layered(back: Control, front: Control) -> Container:
	var c := MarginContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(back)
	c.add_child(front)
	return c


# ---------------------------------------------------------------- the shell

func _nav_of(s: String) -> String:
	match s:
		"main", "setup":
			return "main"
		"online", "lobby":
			return "online"
		"settings", "controls", "backup":
			return "settings"
		"locker", "skills", "tables", "index":
			return s
	return ""


func _go_nav(id: String) -> void:
	came_from = "main"
	match id:
		"main":
			show_main()
		"online":
			show_online("")
		"locker":
			show_locker()
		"skills":
			show_skills()
		"tables":
			show_tables()
		"index":
			show_index("classes")
		"settings":
			show_settings()


## The frame a menu page sits in, with the top bar; returns the area under the bar. kind: "party" (PLAY, MULTIPLAYER,
## the room, LOCKER, INDEX: 1560 wide and the full height), "card" (SKILLS, SETTINGS, ACCOUNT: 1180 wide, as tall as
## what's in it, scrolling past the screen) or "plain" (TABLES: the old 760-wide panel).
func _shell(kind: String) -> Control:
	var vs := _vs()
	var vig_col := Color(8 / 255.0, 14 / 255.0, 18 / 255.0)
	var vig: TextureRect
	match kind:
		"party":
			vig = UiKit.gradient_rect([Color(vig_col, 0.0), Color(vig_col, 0.0), Color(vig_col, 0.55)], [0.0, 0.3, 1.0], true, Vector2(0.5, 0.55), Vector2(1.05, 1.1))
		"card":
			vig = UiKit.gradient_rect([Color(vig_col, 0.25), Color(vig_col, 0.25), Color(vig_col, 0.7)], [0.0, 0.3, 1.0], true, Vector2(0.5, 0.55), Vector2(1.05, 1.1))
		_:
			var ink := Color(12 / 255.0, 11 / 255.0, 9 / 255.0)
			vig = UiKit.gradient_rect([Color(ink, 0.12), Color(ink, 0.55)], [0.0, 1.0], true, Vector2(0.5, 0.5), Vector2(1.05, 1.05))
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(vig)
	if kind == "party":
		var pad := UiKit.px(16)
		var w := minf(vs.x - 2 * pad, UiKit.px(1560))
		var frame := Control.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.position = Vector2(roundf((vs.x - w) / 2), pad)
		frame.size = Vector2(w, vs.y - 2 * pad)
		root.add_child(frame)
		var c0 := Color(10 / 255.0, 20 / 255.0, 27 / 255.0)
		var wash := UiKit.gradient_rect([Color(c0, 0.72), Color(c0, 0.18), Color(c0, 0.18), Color(c0, 0.6)], [0.0, 0.22, 0.78, 1.0])
		wash.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.add_child(wash)
		var border := Panel.new()
		border.add_theme_stylebox_override("panel", UiKit.sb(Color(0, 0, 0, 0), UiKit.FRAME, 1))
		border.set_anchors_preset(Control.PRESET_FULL_RECT)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(border)
		var mc := UiKit.margin(19, 23, 19, 23)
		mc.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.add_child(mc)
		var col := UiKit.vbox(18)
		mc.add_child(col)
		col.add_child(_header(false))
		var body := Control.new()
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(body)
		return body
	var card := kind == "card"
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cc)
	var st: StyleBoxFlat
	if card:
		st = UiKit.sb(Color(10 / 255.0, 20 / 255.0, 27 / 255.0, 0.9), UiKit.FRAME, 1, [18, 22, 18, 22])
	else:
		st = UiKit.sb(Color(12 / 255.0, 11 / 255.0, 9 / 255.0, 0.94), Color(154 / 255.0, 143 / 255.0, 122 / 255.0, 0.28), 1, [32, 40, 32, 40])
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", st)
	pc.custom_minimum_size.x = minf(vs.x - UiKit.px(32), UiKit.px(1180 if card else 760))
	cc.add_child(pc)
	var col2 := UiKit.vbox(16 if card else 14)
	var gutter := UiKit.margin(0, 15 if card else 0, 0, 15 if card else 0)   # scrollbar-gutter: stable both-edges
	gutter.add_child(col2)
	var sc := UiKit.scroller(gutter)
	pc.add_child(sc)
	if not card:   # the gold top edge of the old panel
		var top := ColorRect.new()
		top.color = UiKit.OWARN
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(top)
		pc.add_child(holder)
		var place := func() -> void:
			top.position = Vector2(-st.content_margin_left - UiKit.bw(1), -st.content_margin_top - UiKit.bw(1))
			top.size = Vector2(pc.size.x, UiKit.bw(2))
		pc.resized.connect(place)
	col2.add_child(_header(not card))
	var body2 := UiKit.vbox(12)
	col2.add_child(body2)
	_fit_scroll(sc, gutter, vs.y - UiKit.px(32) - st.content_margin_top - st.content_margin_bottom)
	return body2


## a card frame is as tall as its content, up to the screen
func _fit_scroll(sc: ScrollContainer, content: Control, maxh: float) -> void:
	var f := func() -> void:
		if is_instance_valid(sc) and is_instance_valid(content):
			sc.custom_minimum_size.y = minf(maxh, content.get_combined_minimum_size().y)
	content.minimum_size_changed.connect(f)
	f.call_deferred()


## the top bar: PALISADE and the page tabs on the left; FRIENDS, the profile chip and the shards on the right.
## compact (the narrow TABLES panel): the chips on a first row, the tabs under them
func _header(compact: bool) -> Control:
	var cur := _nav_of(screen if screen != "friends" else _under)
	var nav := UiKit.hbox(4 if compact else 5)
	nav.add_child(_wordmark(24 if compact else 27))
	nav.add_child(UiKit.spacer(0, 0 if compact else 13))
	if compact:
		var gap := UiKit.spacer()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_child(gap)
	for it in NAV:
		var id: String = it[0]
		var sel: bool = id == cur
		var b: UiKit.Btn
		var fsz := 15.0 if compact else 17.0
		var pad := [8, 10, 8, 10] if compact else [10, 12, 10, 12]
		var n := 0
		if id == "locker" and m.locker != null:
			n = m.locker.all_cases()
		elif id == "skills" and m.profile != null and m.profile.cloud:
			n = m.profile.sp
		if n > 0:
			var hb := UiKit.hbox(6)
			hb.alignment = BoxContainer.ALIGNMENT_CENTER
			var tl := _l(it[1], "s8", fsz, Color.WHITE, 0.07)
			tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hb.add_child(tl)
			hb.add_child(_badge("99+" if n > 99 else str(n)))
			var K := UiKit.kind("nav", sel)
			var box := {}
			for s in K.box:
				var bx: StyleBoxFlat = K.box[s].duplicate()
				bx.content_margin_top = UiKit.px(pad[0])
				bx.content_margin_right = UiKit.px(pad[1])
				bx.content_margin_bottom = UiKit.px(pad[2])
				bx.content_margin_left = UiKit.px(pad[3])
				box[s] = bx
			b = UiKit.Btn.new(hb, box, K.tint)
			b.label = tl
			b.text = it[1]
			b.pressed.connect(func(): _go_nav(id))
		else:
			b = UiKit.btn(it[1], "nav", fsz, func(): _go_nav(id), {"sel": sel, "pad": pad})
		b.custom_minimum_size.y = UiKit.px(40 if compact else 44)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_fid(b, "nav:" + id)
		if sel and _focus == null:
			_focus = b
		nav.add_child(b)
	var chips := UiKit.hbox(12)
	var pair := UiKit.hbox(0)
	pair.add_child(_friends_button())
	pair.add_child(_identity_button())
	chips.add_child(pair)
	chips.add_child(_shard_chip())
	if compact:
		var v := UiKit.vbox(12)
		var r1 := UiKit.hbox(0)
		r1.alignment = BoxContainer.ALIGNMENT_END
		r1.add_child(chips)
		v.add_child(r1)
		v.add_child(nav)
		return v
	var row := UiKit.hbox(12)
	nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(nav)
	row.add_child(chips)
	return row


## PALI in bone, SADE cut out (outlined)
func _wordmark(size: float) -> Control:
	var h := UiKit.hbox(0)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_l("PALI", "s9", size, UiKit.BONE, 0.05))
	var cut := Label.new()
	cut.text = "SADE"
	cut.label_settings = UiKit.ls("s9", size, Color(UiKit.BONE, 0.0), 0.05, 0.0, 1.0, UiKit.BONE)
	cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(cut)
	return h


func _badge(t: String) -> Control:
	var p := UiKit.panel(Color("#e8c547"), Color(0, 0, 0, 0), 0, [1, 5, 1, 5])
	var s: StyleBoxFlat = p.get_theme_stylebox("panel")
	s.set_corner_radius_all(int(UiKit.px(9)))
	var l := _l(t, "m6", 11, Color("#12161b"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = UiKit.px(8)
	p.add_child(l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func _chip_box(bg: Color, hover: Color, pad: Array, widths = 1) -> Dictionary:
	return {"normal": UiKit.sb(bg, UiKit.LINE, widths, pad), "hover": UiKit.sb(hover, UiKit.LINE, widths, pad),
		"pressed": UiKit.sb(UiKit.NAVSEL, UiKit.NAVSEL, widths, pad), "disabled": UiKit.sb(bg, UiKit.LINE, widths, pad)}


func _friends_button() -> Control:
	var h := UiKit.hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := PeopleIcon.new()
	ic.custom_minimum_size = Vector2(UiKit.px(20), UiKit.px(16))
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var t := _l("FRIENDS", "s8", 14, Color.WHITE, 0.08)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(t)
	var open := screen == "friends"
	var bg := Color(31 / 255.0, 40 / 255.0, 38 / 255.0, 0.8)
	var box := _chip_box(UiKit.NAVSEL if open else bg, UiKit.NAVSEL, [0, 12, 0, 12], [1, 0, 1, 1])
	var b := UiKit.Btn.new(h, box, {"normal": UiKit.NAVINK if open else UiKit.BONE, "hover": UiKit.NAVINK, "pressed": UiKit.NAVINK, "disabled": UiKit.DIM})
	b.label = t
	b.tinted = [ic]
	b.text = "FRIENDS"
	b.size_flags_vertical = Control.SIZE_FILL
	b.pressed.connect(func(): toggle_friends())
	_fid(b, "friends")
	_friends_btn = b
	var dot := _l("", "m6", 11, Color.WHITE)
	dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ds := UiKit.sb(Color("#e0412f"), Color("#0d1b22"), 2, [0, 5, 0, 5])
	ds.set_corner_radius_all(int(UiKit.px(10)))
	dot.add_theme_stylebox_override("normal", ds)
	dot.custom_minimum_size = Vector2(UiKit.px(19), UiKit.px(19))
	b.add_child(dot)
	_friends_dot = dot
	b.resized.connect(func(): dot.position = Vector2(b.size.x - dot.size.x + UiKit.px(7), -UiKit.px(7)))
	refresh_friends_badge()
	return b


func _identity_button() -> Control:
	var A: PalAccount = m.account
	var full: bool = A != null and A.state == "full" and not A.is_guest()
	var h := UiKit.hbox(10)
	h.add_child(Avatar.new(m.locker.eq.duplicate(), str(m.settings.data.setup.cls), 44))
	var v := UiKit.vbox(4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_l("SET USERNAME" if full and A.name_ == "" else my_name(), "s8", 19, UiKit.BONE, 0.06))
	v.add_child(_l(identity_state(), "m4", 9, Color("#a2e7c6") if full else UiKit.DIM))
	h.add_child(v)
	var dot := Dot.new()
	dot.col = Color("#84dfb1") if full else UiKit.DIM
	dot.custom_minimum_size = Vector2(UiKit.px(7), UiKit.px(7))
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(UiKit.spacer(0, 8))
	h.add_child(dot)
	var bg := Color(31 / 255.0, 40 / 255.0, 38 / 255.0, 0.8)
	var b := UiKit.card_btn(h, _chip_box(bg, Color(46 / 255.0, 60 / 255.0, 57 / 255.0, 0.9), [4, 10, 4, 4]), func(): show_account())
	_fid(b, "account")
	return b


## the profile chip's second line (renderIdentity)
func identity_state() -> String:
	var A: PalAccount = m.account
	if A == null:
		return "LOCAL PROFILE"
	match A.state:
		"full":
			return "SIGNED IN · LOCKER SYNCED" if not m.locker.cloud.is_empty() else "SIGNED IN · LOCKER SYNC PENDING"
		"wait":
			return "CONNECTING TO ACCOUNT"
		"guest":
			return "GUEST · SAVE YOUR ACCOUNT"
		"down":
			return "ACCOUNT OFFLINE"
	return "LOCAL PROFILE"


func _shard_chip() -> Control:
	var h := UiKit.hbox(6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var gold := Color("#f0d16b")
	for it in [["◆", "m4", 13], [str(m.locker.shards if m.locker != null else 0), "m6", 15], ["SHARDS", "m4", 9]]:
		var l := _l(it[0], it[1], it[2], gold)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
	var b := UiKit.card_btn(h, _chip_box(Color("#191e20"), Color("#252d30"), [8, 12, 8, 12]), func(): show_locker())
	_fid(b, "shards")
	return b


# ---------------------------------------------------------------- PLAY (19c-home.js)

func show_main() -> void:
	if m.net.is_online() and not m.net.in_game:   # in a room, PLAY and MULTIPLAYER both mean the room
		show_lobby()
		return
	_begin("main", show_main)
	var body := _shell("party")
	var row := UiKit.hbox(18)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_child(row)
	# the left column: what you're about to play
	var lp := _side_panel(320)
	row.add_child(lp[0])
	var col: VBoxContainer = lp[1]
	col.add_child(_pt("SOLO RUN"))
	col.add_child(_lede("You and Delgado hold the stake. Tap a line to change it."))
	col.add_child(_setup_rows("home", true))
	var best := PalSaves.best_line(m.settings.data.setup)
	if best != "":
		col.add_child(_l(best, "m4", 11, UiKit.DIM, 0.0, 1.5, true))
	var play := UiKit.btn("PLAY", "go", 34, func(): m.start_game(), {"h": 66, "em": 0.14})
	_fid(play, "play")
	_focus = play
	col.add_child(play)
	col.add_child(_how_to_play())
	col.add_child(_l("%s · phone, desktop and controller · online co-op and PvP for up to six" % VERSION, "m4", 11, UiKit.DIM, 0.0, 1.3, true))
	# the middle: the title over the stage
	var S: Dictionary = m.settings.data.setup
	var M: Dictionary = PalMaps.MAPS.get(S.map, PalMaps.MAPS.yard)
	var city: bool = S.mode == "blackout"
	var eyebrow := "SOLO · %s%s" % ["THE CITY" if city else M.name, " XL" if S.size == "xl" and not city else ""]
	var sub := "%s · %s · %s" % [LEN_NAME.get(S.mode, "5 RAIDS"), Pal.DIFF[S.diff].name, Pal.CLASSES[S.cls].name]
	var mods := Sim.clean_mods(S.mods, S.mode)
	var blurb: String = "A night city. Hold eight points, then Main Command." if city else M.blurb
	row.add_child(_stage_column(eyebrow, "HOLD THE CITY." if city else "HOLD THE STAKE.", sub, mods, my_name(), "READY", blurb))
	# the right column: what's waiting
	row.add_child(_home_side())
	_settle()


## a mods line under the stage title (partyMods)
func _mods_line(mods: Array) -> String:
	return ("MODIFIERS · " + " · ".join(mods.map(func(id): return _mod(id).name))) if not mods.is_empty() else ""


## the middle column of a stage page: the heading, the name plate, the crew behind (the stage, or the 2D figures),
## and the line at the bottom. extra: something between the stage and the line (the party cards)
func _stage_column(eyebrow: String, title: String, sub: String, mods: Array, name: String, state: String, hint_text: String, extra: Control = null) -> Control:
	var c := UiKit.vbox(0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UiKit.vbox(0)
	head.add_child(UiKit.spacer(16))
	var e := _l(eyebrow, "s8", 13, UiKit.WARN, 0.22)
	e.label_settings = _shadowed(e.label_settings)
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(e)
	head.add_child(UiKit.spacer(8))
	var t := _l(title, "s9", 36, UiKit.TITLE, 0.025)
	t.label_settings = _shadowed(t.label_settings)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(t)
	head.add_child(UiKit.spacer(6))
	var s := _l(sub, "m4", 11, Color("#aabfc5"))
	s.label_settings = _shadowed(s.label_settings)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(s)
	var ml := _mods_line(mods)
	if ml != "":
		head.add_child(UiKit.spacer(6))
		var mm := _l(ml, "m6", 12, UiKit.WARN, 0.04, 0.0, true)
		mm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_child(mm)
	c.add_child(head)
	var hero := Control.new()
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.add_child(hero)
	_stage_hero = hero
	var plate := UiKit.panel(Color("#12222bbb"), Color("#718b8f"), 1, [8, 16, 8, 16])
	var pv := UiKit.vbox(5)
	var pn := _l(name, "s8", 21, UiKit.BONE, 0.04)
	pn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(pn)
	var ps := _l(state, "m4", 9, Color("#ecd347"))
	ps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(ps)
	plate.add_child(pv)
	var pc := CenterContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(plate)
	if m.demo:   # the pads, the empty spots and the others' name plates (and the painted figures, without the 3D models)
		var h2 := Hero2D.new()
		h2.set_anchors_preset(Control.PRESET_FULL_RECT)
		hero.add_child(h2)
		_hero2d = h2
	hero.add_child(pc)
	hero.resized.connect(func():
		pc.position = Vector2(0, UiKit.px(16))
		pc.size = Vector2(hero.size.x, pc.get_combined_minimum_size().y)
		if stage != null:   # the crew follows the box
			_stage_crew.call_deferred())
	if extra != null:
		c.add_child(extra)
	var hl := _l(hint_text, "m4", 10, Color("#a6bdc3"), 0.0, 1.5, true)
	hl.label_settings = _shadowed(hl.label_settings)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(UiKit.spacer(10))
	c.add_child(hl)
	c.add_child(UiKit.spacer(2))
	return c


func _shadowed(s: LabelSettings) -> LabelSettings:
	var d: LabelSettings = s.duplicate()
	d.shadow_color = Color(0, 0, 0, 0.6)
	d.shadow_size = int(UiKit.px(6))
	d.shadow_offset = Vector2(0, UiKit.px(2))
	return d


func _clear_box() -> Dictionary:
	var c := Color(0, 0, 0, 0)
	return {"normal": UiKit.sb(c), "hover": UiKit.sb(c), "pressed": UiKit.sb(c), "disabled": UiKit.sb(c)}


## HOW TO PLAY, folded under PLAY (details.how)
func _how_to_play() -> Control:
	var v := UiKit.vbox(8)
	v.add_child(UiKit.rule())
	var t := UiKit.btn("HOW TO PLAY", "nav", 13, func():
		how_open = not how_open
		show_main()
		_refocus("how"), {"align": HORIZONTAL_ALIGNMENT_LEFT, "pad": [0, 0, 0, 0], "h": 32, "em": 0.16, "box": _clear_box(),
			"tint": {"normal": UiKit.DIM, "hover": UiKit.BONE, "pressed": UiKit.BONE, "disabled": UiKit.DIM}})
	_fid(t, "how")
	v.add_child(t)
	if how_open:
		var g := UiKit.grid(2, 14)
		var st: PalSettings = m.settings
		var keys := "WASD move · mouse aim\nHold click to fire (soldier: bursts) · %s build\n1 2 3 material · %s wall/door\n%s grenade · %s armory at the stake\n%s sprint (quartermaster) · %s rocket (soldier) or stealth (sniper), co-op · %s roll · %s start raid · Esc pause" % [
			st.keys_label("build"), st.keys_label("piece"), st.keys_label("nade"), st.keys_label("armory"), st.keys_label("sprint"), st.keys_label("special"), st.keys_label("roll"), st.keys_label("start")]
		var cols := [["TOUCH", "Left thumb: move\nRight thumb: aim, push far to fire\nROCKET / STEALTH: the soldier's and sniper's ability (co-op)\nBUILD: place, upgrade or repair the tile you face. DOOR lets you and Delgado walk through."],
			["KEYBOARD", keys],
			["CONTROLLER", "Left stick move · right stick aim · RT fire\nLT grenade · A build (hold to keep building)\nB ability, or sprint if your class has no ability · X armory at the stake\nY wall/door · d-pad left/right material\nView start raid · Menu pause. Change any button in Settings."]]
		for i in cols.size():
			var cv := UiKit.vbox(4)
			cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cv.add_child(_l(cols[i][0], "s8", 13, UiKit.BONE, 0.14))
			cv.add_child(_l(cols[i][1], "m4", 11, UiKit.DIM, 0.0, 1.6, true))
			g.add_child(cv)
		v.add_child(g)
	return v


## the lines that say what you're about to play; each opens the setup sheet at its tab (setupRowsFor)
func _setup_rows(kind: String, edit: bool) -> VBoxContainer:
	var box := UiKit.vbox(6)
	for r in _rows_for(kind):
		var id: String = r[0]
		box.add_child(_setup_row(r[1], r[2], r[3] if kind != "host" else "", edit, func(): _open_sheet(id, kind), "row:%s:%s" % [kind, id]))
	return box


func _rows_for(kind: String) -> Array:
	var P := _pick(kind)
	var pv: bool = kind != "home" and P.get("pvp", "coop") != "coop"
	var M: Dictionary = PalMaps.MAPS.get(P.map, PalMaps.MAPS.yard)
	var cls: String = str(m.settings.data.setup.cls)
	var mods: Array = _mods_of(kind)
	var bo: bool = P.mode == "blackout" and not pv
	var rows: Array = []
	if bo:
		rows.append(["map", "MAP", "THE CITY", "64×64 night city · random bosses · the Supreme Destroyer"])
	else:
		var bosses: Array = M.bosses.map(func(k): return str(Sim.boss_def(k).get("name", k)).replace("THE ", "").to_lower())
		rows.append(["map", "MAP", "ALL FOUR MAPS" if P.mode == "campaign" and not pv else M.name, "16×16 arena" if pv else "%s · bosses: %s" % ["XL · 24×24" if P.size == "xl" else "16×16", ", ".join(bosses)]])
	if not pv:
		var extra: String = {"campaign": " · 4 chapters, 12 raids + five-minute evac", "blitz": " · the Final Blitz and the evacuation", "blackout": " · hold 8 points, then the final push"}.get(P.mode, "")
		rows.append(["rules", "LENGTH", LEN_NAME.get(P.mode, "5 RAIDS"), "Threat: %s%s" % [str(Pal.DIFF[P.diff].name).to_lower(), extra]])
	if kind != "room":
		rows.append(["job", "CLASS", Pal.CLASSES[cls].name, CLASS_TEXT[cls][0]])
	var pct := 0 if pv else PalLocker.mod_bonus(mods, "blitz" if P.mode == "blitz" else "")
	rows.append(["mods", "MODIFIERS", " · ".join(mods.map(func(id): return _mod(id).name)) if not mods.is_empty() else "NONE",
		("%d on%s" % [mods.size(), (" · rewards %s%d%%" % ["+" if pct > 0 else "", pct]) if pct != 0 else ""]) if not mods.is_empty() else "Harder rules pay more"])
	return rows


func _setup_row(key: String, val: String, small: String, edit: bool, cb: Callable, fid: String) -> Control:
	var h := UiKit.hbox(10)
	var v := UiKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_l(key, "m6", 10, UiKit.DIM, 0.16))
	v.add_child(_l(val, "s8", 19, UiKit.BONE, 0.05, 1.1, true))
	if small != "":
		v.add_child(_l(small, "m4", 11, UiKit.SUB, 0.0, 1.35, true))
	h.add_child(v)
	if edit:
		var go := Chevron.new()
		go.custom_minimum_size = Vector2(UiKit.px(9), UiKit.px(30))
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(go)
	var pad := [9, 12, 9, 12]
	var hov := Color(40 / 255.0, 56 / 255.0, 52 / 255.0, 0.95)
	var box := {"normal": UiKit.sb(UiKit.ROWBG, UiKit.ROWLINE, 1, pad), "hover": UiKit.sb(hov, UiKit.WARN, 1, pad),
		"pressed": UiKit.sb(hov, UiKit.WARN, 1, pad), "disabled": UiKit.sb(Color(16 / 255.0, 28 / 255.0, 36 / 255.0, 0.8), UiKit.ROWLINE, 1, pad)}
	var b := UiKit.card_btn(h, box, cb)
	b.custom_minimum_size.y = UiKit.px(48 if small == "" else 62)
	b.disabled = not edit
	if not edit:
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_fid(b, fid)
	return b


## the right column of PLAY: the new mode, cases to open, the next unlock, skill points (renderHomeSide)
func _home_side() -> Control:
	var v := UiKit.vbox(10)
	v.custom_minimum_size.x = UiKit.px(300)
	var S: Dictionary = m.settings.data.setup
	match S.mode:
		"blackout":
			v.add_child(_home_card(true, "SELECTED", "CITY BLACK OUT", "A night city. Hold eight points as bosses hit them one by one, then defend Main Command against the Supreme Destroyer."))
		"campaign":
			v.add_child(_home_card(true, "SELECTED", "OPERATION WHITEOUT", "Travel all four maps. Carry upgrades and supplies through 12 raids, then survive a five-minute summit evacuation."))
		"blitz":
			v.add_child(_home_card(true, "SELECTED", "BLITZKRIEG RUSH", "15 hard raids, then the Final Blitz: a boss every 30 seconds for five minutes. Reach the evac in the last minute or keep only half your cases and shards."))
		_:
			v.add_child(_home_card(true, "NEW CAMPAIGN", "OPERATION WHITEOUT", "Four connected maps, revamped bosses and a summit evacuation. Frostpeak adds ramps, stairs and the Rime Colossus.", "TRY IT", func():
				S.mode = "campaign"
				S.mods = Sim.clean_mods(S.mods, "campaign")
				m.settings.save()
				show_main()))
	var L: PalLocker = m.locker
	var C: Dictionary = PalLocker.catalog().CASES
	var n := L.all_cases()
	if n > 0:
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", int(UiKit.px(6)))
		chips.add_theme_constant_override("v_separation", int(UiKit.px(6)))
		chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for id in C:
			var c := L.case_count(id)
			if c <= 0:
				continue
			var col := Color(C[id].col)
			var chip := UiKit.panel(Color(0, 0, 0, 0), col, 1, [4, 7, 4, 7])
			chip.add_child(_l("%d %s" % [c, str(C[id].get("short", C[id].name)).replace(" Cases", "").to_upper()], "m6", 11, col, 0.06))
			chips.add_child(chip)
		v.add_child(_home_card(false, "READY TO OPEN", "%d CASE%s" % [n, "S" if n > 1 else ""], chips, "OPEN IN LOCKER", func(): show_locker()))
	else:
		v.add_child(_home_card(false, "CASES", "NONE WAITING", "You earn a Supply Case every 3 raids you hold, and bosses drop their own."))
	var nu := next_unlock()
	if not nu.is_empty():
		var Ld: Dictionary = nu.L
		var it := PalLocker.item(Ld.items[nu.i][0] + ":" + Ld.items[nu.i][1])
		var w := UiKit.vbox(6)
		w.add_child(UiKit.spacer(2))
		w.add_child(UiKit.bar(float(nu.have) / Ld.steps[nu.i], 10))
		w.add_child(_l("%d / %d %s" % [nu.have, Ld.steps[nu.i], Ld.units[nu.i] if Ld.get("units") else Ld.unit], "m4", 12, UiKit.SUB))
		v.add_child(_home_card(false, "NEXT UNLOCK · " + str(Ld.title), it.get("name", ""), w, "MILESTONES", func():
			LockerUI.cat = "ms"
			show_locker()))
	var sp: int = m.profile.sp
	if sp > 0:
		v.add_child(_home_card(false, "SKILL POINTS", "%d TO SPEND" % sp, "Spend them on the skill tree, or trade 3 for a Supply Case in the Locker.", "SKILL TREE", func(): show_skills()))
	return v


## nextUnlock: the milestone ladder this player is closest to finishing a step of
func next_unlock() -> Dictionary:
	var L: PalLocker = m.locker
	var best := {}
	for Ld in PalLocker.catalog().LADDERS:
		var i := -1
		for k in Ld.items.size():
			if not L.owns(Ld.items[k][0] + ":" + Ld.items[k][1]):
				i = k
				break
		if i < 0:
			continue
		var have := int(L.st.get(Ld.sts[i] if Ld.get("sts") else Ld.st, 0))
		var f: float = float(have) / Ld.steps[i]
		if best.is_empty() or f > best.f:
			best = {"L": Ld, "i": i, "f": f, "have": have}
	return best


func _home_card(mode: bool, kicker: String, title: String, body = null, btn_text: String = "", act: Callable = Callable()) -> Control:
	var p := UiKit.panel(Color(0, 0, 0, 0) if mode else UiKit.PANEL, UiKit.PLINE, 1, 14)
	var v := UiKit.vbox(6)
	v.add_child(_l(kicker, "m6", 10, Color("#ff8a6a") if mode else UiKit.WARN, 0.16))
	v.add_child(_l(title, "s8", 22, Color("#eef3ed"), 0.05, 1.15, true))
	if body is String:
		v.add_child(_l(body, "m4", 12, UiKit.SUB, 0.0, 1.5, true))
	elif body is Control:
		v.add_child(body)
	if btn_text != "":
		v.add_child(UiKit.spacer(4))
		var b := UiKit.btn(btn_text, "ghost", 14, act, {"h": 44})
		_fid(b, "card:" + btn_text)
		v.add_child(b)
	p.add_child(v)
	if not mode:
		return p
	# the new mode's card: a red edge and a dark red wash from the corner
	var wash := UiKit.gradient_rect([Color(70 / 255.0, 16 / 255.0, 14 / 255.0, 0.8), UiKit.PANEL, UiKit.PANEL], [0.0, 0.7, 1.0], false, Vector2(0, 0), Vector2(1, 1))
	var lay := _layered(wash, p)
	var e2 := Control.new()
	e2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge := ColorRect.new()
	edge.color = Color("#e0433a")
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	e2.add_child(edge)
	e2.resized.connect(func(): edge.size = Vector2(UiKit.bw(3), e2.size.y))
	lay.add_child(e2)
	return lay


func setup_line() -> String:
	var S: Dictionary = m.settings.data.setup
	var mp: String = "THE CITY" if S.mode == "blackout" else ("ALL FOUR MAPS" if S.mode == "campaign" else PalMaps.MAPS[S.map].name)
	var line := "%s · %s · %s · %s · %s" % [LEN_NAME.get(S.mode, "5 RAIDS"), mp, "XL" if S.size == "xl" else "STANDARD", Pal.DIFF[S.diff].name, Pal.CLASSES[S.cls].name]
	var mods := Sim.clean_mods(S.mods, S.mode)
	if not mods.is_empty():
		line += " · " + " + ".join(mods.map(func(id): return _mod(id).name))
	return line


static func _mod(id: String) -> Dictionary:
	for M in Sim.MODS:
		if M.id == id:
			return M
	return {"id": id, "name": id.to_upper(), "what": ""}


# ---------------------------------------------------------------- the setup sheet (19c-home.js openSetup)

## the match the sheet is changing: the solo setup (which also holds the PvP choice for hosting), or the room's picks
func _pick(kind: String) -> Dictionary:
	if kind == "room" and m.net.is_online():
		return m.net.pick
	var S: Dictionary = m.settings.data.setup
	if not S.has("pvp"):
		S.pvp = "coop"
	return S


func _mode_m(kind: String) -> String:
	var P := _pick(kind)
	var pv: String = P.get("pvp", "coop") if kind != "home" else "coop"
	return pv if pv != "coop" else str(P.mode)


func _mods_of(kind: String) -> Array:
	return Sim.clean_mods(_pick(kind).get("mods", []), _mode_m(kind))


func _set_pick(kind: String, k: String, val) -> void:
	var P := _pick(kind)
	P[k] = val
	if k == "mode" or k == "pvp":
		P.mods = Sim.clean_mods(P.get("mods", []), _mode_m(kind))
	if kind == "room":
		m.net.broadcast_lobby()
	else:
		m.settings.save()


func show_setup() -> void:
	show_main()
	_open_sheet("map", "home")


func _open_sheet(tab: String, kind: String) -> void:
	if kind == "room" and m.net.mode == "guest":
		return
	sheet_kind = kind
	var pv: bool = kind != "home" and _pick(kind).get("pvp", "coop") != "coop"
	if pv and tab == "rules":
		tab = "map"
	if kind == "room" and tab == "job":
		tab = "map"
	sheet = tab
	if is_instance_valid(_sheet_node):
		_sheet_node.queue_free()
	_sheet_node = _build_sheet(tab, kind, pv)
	root.add_child(_sheet_node)
	_refocus("sst:" + tab)


func close_sheet() -> void:
	if sheet == "":
		return
	var kind := sheet_kind
	sheet = ""
	if is_instance_valid(_sheet_node):
		_sheet_node.queue_free()
	_sheet_node = null
	if kind == "room":
		show_lobby()
	elif kind == "host":
		show_online("")
	else:
		show_main()
	_refocus("row:%s:map" % kind)


## a change inside the sheet: the sheet is drawn again on the same tab, the focus where it was
func _sheet_change(kind: String, k: String, val) -> void:
	var fid := _focused_fid()
	_set_pick(kind, k, val)
	_open_sheet(sheet, kind)
	if fid != "":
		_refocus(fid)


func _build_sheet(tab: String, kind: String, pv: bool) -> Control:
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(4 / 255.0, 8 / 255.0, 11 / 255.0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: close_sheet())
	ov.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(cc)
	var card := UiKit.panel(Color("#0d1b24"), UiKit.FRAME, 1, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.custom_minimum_size.x = minf(_vs().x - UiKit.px(48), UiKit.px(822))
	cc.add_child(card)
	var v := UiKit.vbox(0)
	card.add_child(v)
	var head := UiKit.margin(14, 16, 10, 16)
	var hr := UiKit.hbox(12)
	var title := _l({"home": "SOLO RUN SETUP", "room": "ROOM SETUP"}.get(kind, "HOST SETUP"), "s9", 26, UiKit.WARN, 0.06)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hr.add_child(title)
	var done := UiKit.btn("DONE", "go", 20, func(): close_sheet(), {"w": 130, "h": 56})
	_fid(done, "sheet:done")
	hr.add_child(done)
	head.add_child(hr)
	v.add_child(head)
	var tabs := UiKit.hbox(4)
	var tm := UiKit.margin(0, 16, 0, 16)
	tm.add_child(tabs)
	v.add_child(tm)
	for t in [["map", "MAP"], ["rules", "LENGTH"], ["job", "CLASSES"], ["mods", "MODIFIERS"]]:
		if (t[0] == "rules" and pv) or (t[0] == "job" and kind == "room"):
			continue
		var id: String = t[0]
		var b := UiKit.btn(t[1], "tab", 14, func(): _open_sheet(id, kind), {"sel": id == tab, "h": 44})
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_fid(b, "sst:" + id)
		tabs.add_child(b)
	var body := UiKit.vbox(10)
	var bm := UiKit.margin(14, 16, 18, 16)
	bm.add_child(body)
	var sc := UiKit.scroller(bm)
	v.add_child(sc)
	match tab:
		"map":
			_sheet_map(body, kind, pv)
		"rules":
			_sheet_rules(body, kind)
		"job":
			_sheet_jobs(body, kind)
		_:
			_sheet_mods(body, kind)
	var maxh := _vs().y - UiKit.px(48)
	var f := func() -> void:
		if is_instance_valid(sc) and is_instance_valid(bm):
			var used := v.get_combined_minimum_size().y - sc.custom_minimum_size.y
			sc.custom_minimum_size.y = minf(maxh - used - UiKit.px(2), bm.get_combined_minimum_size().y)
	bm.minimum_size_changed.connect(f)
	f.call_deferred()
	return ov


func _sheet_h2(text: String) -> Label:
	return _l(text, "s8", 13, UiKit.KEYC, 0.16)


func _sheet_map(body: VBoxContainer, kind: String, pv: bool) -> void:
	var P := _pick(kind)
	var guest: bool = kind == "room" and m.net.mode == "guest"
	var size: String = "std" if pv else str(P.size)
	var hr := UiKit.hbox(8)
	var h := _sheet_h2("MAP")
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hr.add_child(h)
	var tag := UiKit.panel(Color("#304653"), Color(0, 0, 0, 0), 0, [4, 8, 4, 8])
	tag.add_child(_l("24×24" if size == "xl" else "16×16", "m6", 13, UiKit.BONE))
	hr.add_child(tag)
	body.add_child(hr)
	var g := UiKit.grid(3, 10)
	body.add_child(g)
	var fixed: bool = (P.mode == "campaign" or P.mode == "blackout") and not pv
	for id in PalMaps.MAP_IDS:
		if pv and not PalMaps.PVP_BLURB.has(id):
			continue
		var M: Dictionary = PalMaps.MAPS[id]
		var sel: bool = P.map == id
		var cv := UiKit.vbox(6)
		var th := MapThumb.new(id, size, str(P.get("pvp", "coop")) if pv else "")
		cv.add_child(th)
		cv.add_child(_l(M.name, "s8", 17, UiKit.BONE, 0.05))
		var blurb: String = PalMaps.PVP_BLURB.get(id, {}).get(P.pvp, M.blurb) if pv else M.blurb
		cv.add_child(_l(blurb, "m4", 10, UiKit.SUB, 0.0, 1.5, true))
		var bosses: String = ("BASE BATTLE LAYOUT" if P.pvp == "base" else "FREE-FOR-ALL ARENA") if pv else "BOSSES · " + " · ".join(M.bosses.map(func(k): return str(Sim.boss_def(k).get("name", k)).replace("THE ", "")))
		cv.add_child(_l(bosses, "m4", 9, UiKit.WARN, 0.04, 1.3, true))
		var pad := [8, 8, 8, 8]
		var bg := Color("#1b303e")
		var on := Color("#27404c")
		var box := {"normal": UiKit.sb(on if sel else bg, UiKit.WARN if sel else UiKit.ROWLINE, [1, 1, 1, 3] if sel else 1, pad),
			"hover": UiKit.sb(on if sel else bg, UiKit.WARN if sel else Color("#7e98a5"), [1, 1, 1, 3] if sel else 1, pad),
			"pressed": UiKit.sb(on, UiKit.WARN, [1, 1, 1, 3], pad),
			"disabled": UiKit.sb(on if sel else Color(bg, 0.45), UiKit.WARN if sel else Color(UiKit.ROWLINE, 0.45), [1, 1, 1, 3] if sel else 1, pad)}
		var mid: String = id
		var b := UiKit.card_btn(cv, box, func(): _sheet_change(kind, "map", mid))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = fixed or (guest and not sel)
		if b.disabled and not sel:
			cv.modulate.a = 0.45
		_fid(b, "map:" + id)
		g.add_child(b)
	if fixed:
		body.add_child(_lede("The campaign travels all four maps; Black Out has its own city.", Color("#aec0c5"), 10))
	if pv:
		body.add_child(_lede("PvP is always 16×16.", Color("#aec0c5"), 10))
		return
	body.add_child(UiKit.spacer(6))
	body.add_child(_l("SIZE", "s8", 12, UiKit.KEYC, 0.12))
	var sg := UiKit.seg([["std", "STANDARD · 16×16"], ["xl", "XL · 24×24"]], P.size, func(id): _sheet_change(kind, "size", id),
		{"size": 14, "h": 48, "disabled": ["std", "xl"] if P.mode == "blackout" or guest else []})
	_tag_seg(sg, "size")
	body.add_child(sg)
	body.add_child(_lede("XL: a bigger yard and about 40% more raiders.", Color("#aec0c5"), 10))


## give a segmented picker's buttons focus ids
func _tag_seg(sg: Control, pre: String) -> void:
	for b in sg.get_child(0).get_children():
		if b is UiKit.Btn:
			_fid(b, "%s:%s" % [pre, b.text])


func _sheet_rules(body: VBoxContainer, kind: String) -> void:
	var P := _pick(kind)
	body.add_child(_sheet_h2("LENGTH"))
	var modes: Array = MODES.duplicate()
	if kind == "room":
		modes.append(["casino", "THE CASINO"])
	var sg := UiKit.seg(modes, P.mode, func(id): _sheet_change(kind, "mode", id), {"cols": 3, "size": 14, "h": 48})
	_tag_seg(sg, "mode")
	body.add_child(sg)
	if P.mode in ["blitz", "campaign", "blackout"]:
		body.add_child(_lede(MODE_HINT[P.mode], UiKit.DIM))
	body.add_child(UiKit.spacer(4))
	body.add_child(_sheet_h2("THREAT"))
	var dg := UiKit.seg([["easy", "EASY"], ["normal", "NORMAL"], ["hard", "HARD"]], P.diff, func(id): _sheet_change(kind, "diff", id), {"size": 14, "h": 48})
	_tag_seg(dg, "diff")
	body.add_child(dg)


func _sheet_jobs(body: VBoxContainer, kind: String) -> void:
	var cls: String = str(m.settings.data.setup.cls)
	var hr := UiKit.hbox(8)
	var h := _sheet_h2("YOUR CLASS")
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(h)
	var link := UiKit.btn("OPEN THE INDEX", "nav", 10, func():
		close_sheet()
		show_index("classes"), {"face": "m6", "em": 0.0, "pad": [0, 0, 2, 0], "box": _clear_box(),
			"tint": {"normal": Color("#9ec3cb"), "hover": UiKit.BONE, "pressed": UiKit.BONE, "disabled": Color("#9ec3cb")}})
	var ul := Underline.new()
	ul.set_anchors_preset(Control.PRESET_FULL_RECT)
	link.add_child(ul)
	hr.add_child(link)
	body.add_child(hr)
	var sg := UiKit.seg(Pal.CLASS_IDS.map(func(id): return [id, Pal.CLASSES[id].name]), cls, func(id): _set_class(id, kind), {"cols": 2, "size": 14, "h": 48})
	_tag_seg(sg, "cls")
	body.add_child(sg)
	var g := UiKit.grid(4, 6)
	body.add_child(g)
	for id in Pal.CLASS_IDS:
		var sel: bool = id == cls
		var p := UiKit.panel(Color(10 / 255.0, 20 / 255.0, 27 / 255.0, 0.6), UiKit.WARN if sel else Color("#2e434e"), 1, [8, 10, 8, 10])
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UiKit.vbox(3)
		v.add_child(_l(Pal.CLASSES[id].name, "s8", 14, UiKit.BONE, 0.06))
		v.add_child(_l(CLASS_TEXT[id][1], "m4", 11, UiKit.SUB, 0.0, 1.4, true))
		p.add_child(v)
		g.add_child(p)


func _set_class(id: String, kind: String) -> void:
	var fid := _focused_fid()
	m.settings.data.setup.cls = id
	m.settings.save()
	if m.net.is_online() and not m.net.in_game:
		var me: Dictionary = m.net_me()
		m.net.set_loadout(id, me.cos, me.name, me.sk)
	if sheet != "":
		_open_sheet(sheet, kind)
		if fid != "":
			_refocus(fid)


func _sheet_mods(body: VBoxContainer, kind: String) -> void:
	var P := _pick(kind)
	var mm := _mode_m(kind)
	var on := _mods_of(kind)
	var hr := UiKit.hbox(6)
	hr.add_child(_sheet_h2("MODIFIERS"))
	var pct := PalLocker.mod_bonus(on, "blitz" if mm == "blitz" else "")
	if not on.is_empty():
		var t := _l("%d ON%s" % [on.size(), (" · REWARDS %s%d%%" % ["+" if pct > 0 else "", pct]) if pct != 0 and mm not in ["base", "ffa"] else ""], "m6", 11, UiKit.WARN)
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hr.add_child(t)
	body.add_child(hr)
	body.add_child(_lede("Harder rules pay more rewards. The host's picks apply to everyone in a room.", UiKit.BONE))
	var g := UiKit.grid(3, 6)
	body.add_child(g)
	var any := false
	for M in Sim.MODS:
		if Sim.clean_mods([M.id], mm).is_empty():
			continue
		any = true
		var id: String = M.id
		var b := _mod_chip(M, on.has(id), mm not in ["base", "ffa"], func(): _toggle_mod(kind, id))
		_fid(b, "mod:" + id)
		g.add_child(b)
	if not any:
		body.add_child(_lede("No modifiers for this mode.", UiKit.DIM))
	if kind == "room" and on.has("onejob"):
		body.add_child(_sheet_h2("ONE CLASS · EVERYONE PLAYS"))
		var jg := UiKit.seg(Pal.CLASS_IDS.map(func(c): return [c, Pal.CLASSES[c].name]), P.job if str(P.get("job", "")) != "" else "soldier", func(c): _sheet_change(kind, "job", c), {"cols": 2, "size": 13, "h": 40})
		body.add_child(jg)


func _toggle_mod(kind: String, id: String) -> void:
	var fid := _focused_fid()
	var P := _pick(kind)
	var list: Array = P.get("mods", []).duplicate()
	if list.has(id):
		list.erase(id)
	else:
		list.append(id)
	_set_pick(kind, "mods", Sim.clean_mods(list, _mode_m(kind)))
	_open_sheet(sheet, kind)
	_refocus(fid)


## .modChip: a modifier, what it does and what it pays
func _mod_chip(M: Dictionary, sel: bool, show_pct: bool, cb: Callable, edit: bool = true) -> UiKit.Btn:
	var v := UiKit.vbox(2)
	var h := UiKit.hbox(10)
	var n := _l(M.name, "s8", 15, UiKit.BONE, 0.06)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	var bonus := int(M.get("bonus", 0))
	if show_pct and bonus != 0:
		h.add_child(_l(("+" if bonus > 0 else "") + str(bonus) + "%", "m6", 11, Color("#9fd6ae") if bonus > 0 else Color("#e5a06a")))
	v.add_child(h)
	v.add_child(_l(M.what, "m4", 11, Color("#d8cfb6") if sel else UiKit.DIM, 0.0, 1.35, true))
	var pad := [8, 10, 8, 10]
	var bg := Color(10 / 255.0, 18 / 255.0, 24 / 255.0, 0.72)
	var on := Color(58 / 255.0, 48 / 255.0, 18 / 255.0, 0.82)
	var box := {"normal": UiKit.sb(on if sel else bg, UiKit.WARN if sel else Color("#3b4f59"), [1, 1, 1, 3] if sel else 1, pad),
		"hover": UiKit.sb(on if sel else Color("#14222c"), UiKit.WARN, [1, 1, 1, 3] if sel else 1, pad),
		"pressed": UiKit.sb(on, UiKit.WARN, [1, 1, 1, 3], pad),
		"disabled": UiKit.sb(on if sel else bg, UiKit.WARN if sel else Color("#3b4f59"), [1, 1, 1, 3] if sel else 1, pad)}
	var b := UiKit.card_btn(v, box, cb)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = UiKit.px(44)
	b.disabled = not edit
	if not edit:
		b.focus_mode = Control.FOCUS_NONE
	return b


# ---------------------------------------------------------------- MULTIPLAYER (21-online.js, 19-accounts.js)

func online_status(text: String) -> void:
	if is_instance_valid(_online_msg):
		_online_msg.text = text
		_online_msg.visible = text != ""


## host a room, or join one with its code; the open games
func show_online(msg: String) -> void:
	if m.net.is_online() and not m.net.in_game:
		show_lobby()
		return
	_begin("online", func(): show_online(""))
	var body := _shell("party")
	var row := UiKit.hbox(18)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_child(row)
	var lp := _side_panel(340)
	row.add_child(lp[0])
	var col: VBoxContainer = lp[1]
	col.add_child(_pt("MULTIPLAYER"))
	col.add_child(_h2("OPEN GAMES"))
	var games := UiKit.vbox(6)
	col.add_child(games)
	var note := _l("Loading…", "m4", 11, UiKit.SUB, 0.0, 1.6, true)
	games.add_child(note)
	col.add_child(_h2("YOUR NAME"))
	var A: PalAccount = m.account
	var named: bool = A != null and A.state == "full" and A.name_ != ""
	var nm := UiKit.field(my_name() if named else str(m.settings.data.get("name", "")), "Big U", {"size": 14})
	nm.max_length = 12
	nm.editable = not named
	nm.text_changed.connect(func(t: String):
		m.settings.data.name = t.substr(0, 12)
		m.settings.save())
	_fid(nm, "name")
	col.add_child(nm)
	# join a crew
	var jc := _mp_card("JOIN A CREW")
	var jr := UiKit.hbox(8)
	_code_in = UiKit.field("", "CODE", {"face": "s9", "size": 26, "em": 0.12, "h": 56, "align": HORIZONTAL_ALIGNMENT_CENTER})
	_code_in.max_length = 6
	_code_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_in.text_changed.connect(_upper_code)
	_code_in.text_submitted.connect(func(t: String): m.net_join(t))
	_fid(_code_in, "code")
	jr.add_child(_code_in)
	var jb := UiKit.btn("JOIN", "go", 18, func(): m.net_join(_code_in.text), {"w": 74, "h": 56})
	_fid(jb, "join")
	jr.add_child(jb)
	jc[1].add_child(jr)
	_online_msg = _l(msg, "m4", 12, UiKit.WARN, 0.0, 1.5, true)
	_online_msg.visible = msg != ""
	jc[1].add_child(_online_msg)
	col.add_child(jc[0])
	# host a room
	var S := _pick("host")
	var hc := _mp_card("HOST A ROOM")
	var pg := UiKit.seg(PVP_MODES, S.pvp, func(id):
		_set_pick("host", "pvp", id)
		show_online("")
		_refocus("pvp:" + str(MODE_NAME.get(id, ""))), {"size": 13, "em": 0.02, "h": 40})
	_tag_seg(pg, "pvp")
	hc[1].add_child(pg)
	hc[1].add_child(_lede(pvp_desc(S.pvp)))
	hc[1].add_child(_setup_rows("host", true))
	if A != null and A.state != "off":
		hc[1].add_child(UiKit.toggle("List my game in Open Games", m.settings.data.get("listGame", true), func(on: bool):
			m.settings.data.listGame = on
			m.settings.save(), 11))
	var host := UiKit.btn("HOST", "go", 23, func(): m.net_host(), {"h": 54})
	_fid(host, "host")
	hc[1].add_child(host)
	col.add_child(hc[0])
	col.add_child(_details("IF IT WON'T CONNECT", "Players connect straight to each other. Most home networks are fine; some cellular networks and strict firewalls block it. If a join hangs, put the host (or everyone) on a home network. Keep the host's game open: if it closes, the game ends for everyone.", "wont"))
	# the stage: you, and five free places
	var cards := _party_cards([{"name": my_name(), "cls": m.settings.data.setup.cls, "me": true}])
	row.add_child(_stage_column(MODE_NAME.get(S.pvp, "CO-OP"), "YOUR CREW. YOUR CLAIM.", "Choose your job. Bring your crew.", [], my_name(), "CHOOSING A LOADOUT", "Up to six players · desktop and mobile", cards))
	_settle()
	_fill_games(games, note)


func _upper_code(t: String) -> void:
	var up := t.to_upper()
	if up != t and is_instance_valid(_code_in):
		var c := _code_in.caret_column
		_code_in.text = up
		_code_in.caret_column = c


func pvp_desc(pv: String) -> String:
	match pv:
		"base":
			return "Two crews, two stakes. %d seconds of truce to gather and wall in, then knock down theirs. Kills pay salvage for the armory. No raiders, no Delgado." % int(Pal.PVP.truce)
		"ffa":
			return "Everyone for themselves in a designed arena whose cover can't be broken. First to %d drops, or the most after %d minutes. No building." % [int(Pal.PVP.ffaGoal), int(Pal.PVP.get("ffaTime", 300)) / 60]
	return "Everyone against the raiders, with Delgado. Pick how long and how hard."


## .mpCard: a boxed step on the MULTIPLAYER page; returns [card, its column]
func _mp_card(title: String) -> Array:
	var p := UiKit.panel(Color(12 / 255.0, 24 / 255.0, 32 / 255.0, 0.7), UiKit.ROWLINE, 1, 12)
	var v := UiKit.vbox(10)
	v.add_child(_l(title, "s8", 14, UiKit.WARN, 0.16))
	p.add_child(v)
	return [p, v]


## details.how: a caption that unfolds a paragraph
func _details(title: String, text: String, id: String) -> Control:
	var v := UiKit.vbox(8)
	v.add_child(UiKit.rule())
	var lede := _lede(text)
	lede.visible = false
	var t := UiKit.btn(title, "nav", 13, func(): lede.visible = not lede.visible, {"align": HORIZONTAL_ALIGNMENT_LEFT, "pad": [0, 0, 0, 0], "h": 32, "em": 0.16, "box": _clear_box(),
		"tint": {"normal": UiKit.DIM, "hover": UiKit.BONE, "pressed": UiKit.BONE, "disabled": UiKit.DIM}})
	_fid(t, "details:" + id)
	v.add_child(t)
	v.add_child(lede)
	return v


func _fill_games(box: VBoxContainer, note: Label) -> void:
	var why: String = await m.social.refresh_open_games()
	if not is_instance_valid(box):
		return
	for ch in box.get_children():
		if ch != note:
			ch.queue_free()
	note.text = why
	note.visible = why != ""
	for g in m.social.open_games:
		var h := UiKit.hbox(10)
		var v := UiKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(_l(str(g.get("name", "Open game")), "s8", 17, UiKit.BONE, 0.04))
		v.add_child(_l(PalSocial.game_line(g), "m4", 11, UiKit.DIM))
		h.add_child(v)
		var n := _l("%d/6" % int(g.get("players", 0)), "s9", 18, UiKit.WARN)
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(n)
		var pad := [8, 12, 8, 12]
		var bg := Color(27 / 255.0, 24 / 255.0, 20 / 255.0, 0.8)
		var b := UiKit.card_btn(h, {"normal": UiKit.sb(bg, UiKit.LINE, 1, pad), "hover": UiKit.sb(bg, UiKit.WARN, 1, pad), "pressed": UiKit.sb(bg, UiKit.WARN, 1, pad), "disabled": UiKit.sb(Color(bg, 0.45), Color(UiKit.LINE, 0.45), 1, pad)})
		b.custom_minimum_size.y = UiKit.px(54)
		b.disabled = int(g.get("players", 6)) >= 6 or m.net.mode != "solo"
		var code: String = g.get("code", "")
		b.pressed.connect(func(): m.net_join(code))
		box.add_child(b)


## the six places at the bottom of the stage: who's in, or INVITE (partySlots)
func _party_cards(rows: Array) -> Control:
	var h := UiKit.hbox(7)
	var mc := UiKit.margin(0, 6, 0, 6)
	mc.add_child(h)
	for i in 6:
		var r: Dictionary = rows[i] if i < rows.size() else {}
		var v := UiKit.vbox(4)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		if not r.is_empty():
			var nl := _l(str(r.name), "s8", 15, Color("#eef6ef"), 0.04)
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(nl)
			var sl := _l(("YOU · " if r.get("me", false) else "") + str(Pal.CLASSES.get(str(r.cls), Pal.SOLDIER).name), "m4", 8, Color("#eef6ef"))
			sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(sl)
			var p := UiKit.panel(Color(52 / 255.0, 81 / 255.0, 88 / 255.0, 0.4), Color("#93bec0"), 1, [9, 4, 9, 4])
			p.custom_minimum_size.y = UiKit.px(55)
			p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			p.add_child(v)
			h.add_child(p)
		else:
			var plus := PlusIcon.new()
			plus.custom_minimum_size = Vector2(UiKit.px(18), UiKit.px(18))
			plus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(plus)
			var il := _l("INVITE", "m4", 8, Color.WHITE)
			il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(il)
			var pad := [9, 4, 9, 4]
			var fill := Color(32 / 255.0, 55 / 255.0, 65 / 255.0, 0.4)
			var box := {"normal": DashBox.make(fill, Color("#66818b"), pad), "hover": DashBox.make(fill, UiKit.WARN, pad),
				"pressed": DashBox.make(fill, UiKit.WARN, pad), "disabled": DashBox.make(fill, Color("#66818b"), pad)}
			var b := UiKit.Btn.new(v, box, {"normal": Color("#9db6bd"), "hover": UiKit.WARN, "pressed": UiKit.WARN, "disabled": Color("#9db6bd")})
			b.label = il
			b.tinted = [plus]
			b.custom_minimum_size.y = UiKit.px(55)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func(): _invite_slot())
			_fid(b, "slot:%d" % i)
			h.add_child(b)
	return mc


## an empty place: in a room, the invite link goes on the clipboard; before one, HOST is where to start
func _invite_slot() -> void:
	if m.net.is_online() and m.net.code != "":
		_share_link()
	else:
		online_status("Create a room with HOST, then copy its invite link for your crew.")
		var h := _find_fid(root, "host")
		if h != null:
			h.grab_focus()


func _share_link() -> void:
	DisplayServer.clipboard_set(PalAccount.SITE_URL + "?room=" + str(m.net.code))
	online_status("Invite link copied. Paste it to your crew (room %s)." % m.net.code)


# ---------------------------------------------------------------- the room (19b-social-lobby.js renderLobby)

## the room: its code, start or ready, the host's settings, your class, the crew, chat; the crew on the stage
func show_lobby() -> void:
	var n: PalNet = m.net
	if n.mode != "host" and n.mode != "guest":
		show_online("")
		return
	_begin("lobby", show_lobby)
	var host: bool = n.mode == "host"
	var pv: String = n.pick.pvp
	var body := _shell("party")
	var row := UiKit.hbox(18)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_child(row)
	var lp := _side_panel(340)
	row.add_child(lp[0])
	var col: VBoxContainer = lp[1]
	col.add_child(_pt("ROOM"))
	var code := UiKit.panel(Color(27 / 255.0, 24 / 255.0, 20 / 255.0, 0.8), UiKit.LINE, 1, [12, 14, 12, 14])
	var cv := UiKit.vbox(2)
	cv.add_child(_l("ROOM CODE", "s8", 13, UiKit.DIM, 0.16))
	cv.add_child(_l(n.code if n.code != "" else "····", "s9", 46, UiKit.WARN, 0.2))
	code.add_child(cv)
	col.add_child(code)
	col.add_child(_fid(UiKit.btn("SHARE INVITE LINK", "ghost", 14, func(): _share_link(), {"h": 46}), "share"))
	var me: Dictionary = {}
	for r in n.roster:
		if r.id == n.my_id:
			me = r
	var gs: Array = n.roster.filter(func(r): return r.id != "host")
	var rn := gs.filter(func(r): return r.get("ready", false)).size()
	var all_ready := rn == gs.size()
	if host:
		var st := UiKit.btn("START" if pv == "coop" else "START THE FIGHT", "go", 34, func(): m.net_start(), {"h": 66, "em": 0.14})
		if not all_ready:
			st.modulate.a = 0.45
		_fid(st, "start")
		_focus = st
		col.add_child(st)
	else:
		var rd: bool = me.get("ready", false)
		var rb := UiKit.btn("READY ✓" if rd else "READY", "go", 34, func(): n.set_ready(not me.get("ready", false)), {"h": 66, "em": 0.14})
		_fid(rb, "ready")
		_focus = rb
		col.add_child(rb)
	_online_msg = _l("", "m4", 12, UiKit.WARN, 0.0, 1.5, true)
	_online_msg.visible = false
	col.add_child(_online_msg)
	var M: Dictionary = PalMaps.MAPS.get(n.pick.map, PalMaps.MAPS.yard)
	var mode: String = n.pick.mode
	var lenw: String = {"endless": "endless", "campaign": "Operation Whiteout", "blitz": "Blitzkrieg Rush", "blackout": "City Black Out", "casino": "the casino"}.get(mode, mode + " raids")
	var what: String = "Base battle" if pv == "base" else ("Free-for-all" if pv == "ffa" else "Co-op · %s%s · %s · threat: %s" % [M.name, " XL" if n.pick.size == "xl" else "", lenw, str(Pal.DIFF[n.pick.diff].name).to_lower()])
	var rd2 := (" · %d / %d READY" % [rn, gs.size()]) if not gs.is_empty() else ""
	var note := ""
	if host:
		var block := n.start_block()
		note = "%d of 6 in the room%s · %s. %s" % [n.roster.size(), rd2, what, block if block != "" else ("Everyone has to ready up before you can start." if not gs.is_empty() and not all_ready else "Share the code, then start when everyone is in.")]
	else:
		note = "%s%s · %s." % ["You are ready" if me.get("ready", false) else "Press READY when you are set", rd2, what]
	col.add_child(_l(note, "m4", 11, UiKit.BONE, 0.0, 1.55, true))
	col.add_child(_setup_rows("room", host))
	var onejob: bool = n.pick.mods.has("onejob")
	col.add_child(_h2("YOUR CLASS"))
	var cls: String = me.get("cls", m.settings.data.setup.cls)
	var jg := UiKit.seg(Pal.CLASS_IDS.map(func(id): return [id, Pal.CLASSES[id].name]), cls, func(id):
		_set_class(id, "room")
		show_lobby()
		_refocus("lcls:" + str(Pal.CLASSES[id].name)), {"cols": 2, "size": 12, "em": 0.06, "h": 40})
	_tag_seg(jg, "lcls")
	if onejob:
		jg.modulate.a = 0.4
		for b in jg.get_child(0).get_children():
			b.disabled = true
	col.add_child(jg)
	if onejob:
		col.add_child(_h2("ONE CLASS · EVERYONE PLAYS"))
		var oj := UiKit.seg(Pal.CLASS_IDS.map(func(id): return [id, Pal.CLASSES[id].name]), n.pick.job if str(n.pick.get("job", "")) != "" else "soldier", func(id):
			n.pick.job = id
			n.broadcast_lobby()
			show_lobby(), {"cols": 2, "size": 12, "em": 0.06, "h": 40, "disabled": [] if host else Pal.CLASS_IDS})
		col.add_child(oj)
	col.add_child(_h2("CREW"))
	var crew := UiKit.vbox(4)
	for i in n.roster.size():
		var r: Dictionary = n.roster[i]
		var tm: Dictionary = Pal.TEAMS.get(r.get("team", "a"), Pal.TEAMS.a)
		var txt := "%s · %s%s%s%s" % [str(r.name).to_upper(), Pal.CLASSES.get(r.get("cls", "soldier"), Pal.SOLDIER).name, (" · " + tm.name) if pv == "base" else "",
			" · HOST" if r.id == "host" else (" · READY ✓" if r.get("ready", false) else " · NOT READY"), " · YOU" if r.id == n.my_id else ""]
		var edge := Color(tm.col) if pv == "base" else (Color("#e0664a") if pv == "ffa" else (Color("#8fe0a0") if r.id != "host" and r.get("ready", false) else Color("#5b7a52")))
		var rid: String = r.id
		crew.add_child(_roster_row(txt, edge, UiKit.BONE, (func(): n.kick(rid)) if host and r.id != "host" else Callable()))
	if pv == "coop":
		crew.add_child(_roster_row("DELGADO · SUPPLY RUNNER · AI", Color("#6f8594"), Color("#a9bccb")))
	col.add_child(crew)
	if pv == "base":
		col.add_child(_fid(UiKit.btn("SWITCH SIDES", "ghost", 14, func(): n.switch_team(), {"h": 46}), "team"))
	if host:
		col.add_child(_fid(UiKit.btn("UNLOCK ROOM" if n.locked else "LOCK ROOM", "ghost", 14, func():
			n.set_locked(not n.locked)
			show_lobby()
			_refocus("lock"), {"h": 46}), "lock"))
	else:
		var mods: Array = Sim.clean_mods(n.pick.mods, pv if pv != "coop" else mode)
		col.add_child(_h2("MODIFIERS"))
		if mods.is_empty():
			col.add_child(_lede("No modifiers. The host picks them."))
		for id in mods:
			col.add_child(_mod_chip(_mod(id), true, pv == "coop", Callable(), false))
	if host and m.social.active() and not m.social.friends.is_empty():
		col.add_child(_h2("INVITE A FRIEND"))
		var fr := HFlowContainer.new()
		fr.add_theme_constant_override("h_separation", int(UiKit.px(6)))
		fr.add_theme_constant_override("v_separation", int(UiKit.px(6)))
		col.add_child(fr)
		for f in m.social.friends:
			var ff: Dictionary = f
			var b := UiKit.btn(str(f.get("username", "PLAYER")).to_upper(), "ghost", 13, func(): m.social.invite(ff), {"h": 36})
			b.disabled = not m.social.can_invite() or m.social.busy
			fr.add_child(b)
		if m.social.msg != "":
			col.add_child(_l(m.social.msg, "m4", 12, UiKit.WARN, 0.0, 1.5, true))
	col.add_child(_h2("CHAT"))
	var logp := UiKit.panel(Color(12 / 255.0, 11 / 255.0, 9 / 255.0, 0.6), UiKit.LINE, 1, [6, 8, 6, 8])
	logp.custom_minimum_size.y = UiKit.px(56)
	var lv := UiKit.vbox(3)
	logp.add_child(lv)
	if n.chat.is_empty():
		lv.add_child(_l("No messages yet.", "m4", 12, UiKit.DIM))
	for line in n.chat.slice(maxi(0, n.chat.size() - 8)):
		var rl := RichTextLabel.new()
		rl.bbcode_enabled = true
		rl.fit_content = true
		rl.scroll_active = false
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.add_theme_font_override("normal_font", UiKit.face("m4"))
		rl.add_theme_font_override("bold_font", UiKit.font("s8", 13, 0.05))
		rl.add_theme_font_size_override("normal_font_size", UiKit.fs(12))
		rl.add_theme_font_size_override("bold_font_size", UiKit.fs(13))
		rl.add_theme_color_override("default_color", UiKit.BONE)
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rl.text = "[b][color=#%s]%s[/color][/b]  %s" % [Color(line.col).to_html(false), str(line.name).to_upper(), str(line.text).replace("[", "[lb]")]
		lv.add_child(rl)
	col.add_child(logp)
	var chat_in := UiKit.field("", "Say hi", {"size": 16, "h": 40, "face": "m4"})
	chat_in.max_length = 120
	var send := func() -> void:
		if chat_in.text.strip_edges() != "":
			n.send_chat(chat_in.text)
		chat_in.text = ""
	chat_in.text_submitted.connect(func(_t): send.call())
	_fid(chat_in, "chat")
	col.add_child(chat_in)
	col.add_child(_fid(UiKit.btn("SEND", "go", 18, send, {"h": 54}), "send"))
	col.add_child(_fid(UiKit.btn("LEAVE", "ghost", 14, func(): m.net_leave(), {"h": 46}), "leave"))
	# the stage
	var rows: Array = []
	for r in n.roster:
		rows.append({"name": str(r.name), "cls": r.get("cls", "soldier"), "me": r.id == n.my_id})
	rows.sort_custom(func(a, b): return a.me and not b.me)
	var sub := "ROOM %s · %d / 6 PLAYERS%s" % [n.code, n.roster.size(), (" · " + M.name + (" XL" if n.pick.size == "xl" else "")) if pv == "coop" else ""]
	var mods2: Array = Sim.clean_mods(n.pick.mods, pv if pv != "coop" else mode)
	row.add_child(_stage_column(MODE_NAME.get(pv, "CO-OP"), "PARTY LOBBY", sub, mods2, str(me.get("name", my_name())), "PARTY LEADER" if host else "WAITING FOR HOST", "Share your room link. Your host starts the match.", _party_cards(rows)))
	_settle()


func _roster_row(text: String, edge: Color, col: Color, kick: Callable = Callable()) -> Control:
	var p := UiKit.panel(Color(27 / 255.0, 24 / 255.0, 20 / 255.0, 0.7), edge, [0, 0, 0, 3], [6, 10, 6, 10])
	var h := UiKit.hbox(8)
	var l := _l(text, "s8", 13, col, 0.06, 0.0, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	if kick.is_valid():
		h.add_child(UiKit.btn("REMOVE", "ghost", 10, kick, {"h": 30, "pad": [4, 9, 4, 9]}))
	p.add_child(h)
	return p


# ---------------------------------------------------------------- the pages built by MenuPages

func show_settings() -> void:
	pages.show_settings()


func show_controls() -> void:
	pages.show_settings()


func show_backup(msg: String = "") -> void:
	pages.show_backup("export", msg)


func show_account() -> void:
	pages.show_account()


func show_index(tab: String) -> void:
	pages.show_index(tab)


func show_skills() -> void:
	pages.show_skills()


func show_tables() -> void:
	pages.show_tables()


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
	if screen == "settings":
		pages.show_settings()
		_refocus("key:" + id)
	return true


func _go(from: String, to: String) -> void:
	came_from = from
	if to == "index":
		show_index("classes")
	elif to == "skills":
		show_skills()
	else:
		show_settings()


## B, Esc: back out of whatever is open
func back() -> void:
	if sheet != "":
		close_sheet()
		return
	if pages.overlay_open():
		pages.close_overlay()
		return
	match screen:
		"friends":
			close_friends()
		"setup", "locker", "account", "online", "tables":
			show_main()
		"lobby":
			m.net_leave()
		"settings", "index", "controls", "backup", "skills":
			if came_from == "pause":
				show_pause()
			elif came_from == "results":
				show_results()
			else:
				show_main()
		"pause":
			m.do_action("pause")


# ---------------------------------------------------------------- pause (page.html #pause, togglePause)

func show_pause() -> void:
	_begin("pause", show_pause)
	came_from = "pause"
	var s: Sim = m.sim
	var col := _overlay(470)
	var eb := "PAUSED · BUILD PHASE"
	if m.net.is_online():
		eb = "THE FIGHT DOESN’T PAUSE" if s.pvp() != "" else "THE RAID DOESN’T PAUSE ONLINE"
	elif s.game.phase != "build":
		eb = "PAUSED · RAID %d" % int(s.game.wave)
	col.add_child(_l(eb, "s8", 13, UiKit.OWARN, 0.22))
	col.add_child(_l("HOLD UP", "s9", 84, UiKit.OBONE, 0.02, 0.82))
	var res := UiKit.btn("BACK TO IT", "ogo", 22, func(): m.do_action("pause"), {"h": 56})
	_fid(res, "resume")
	_focus = res
	col.add_child(res)
	var q: Dictionary = s.qm
	if s.pvp() == "" and not q.get("gone", false) and not s.casino() and m.net.mode != "guest":
		var v := UiKit.vbox(6)
		v.add_child(_l("DELGADO ORDERS", "m4", 13, UiKit.OBONE))
		var follow: bool = q.get("mode", "") == "follow"
		var sg := UiKit.seg([["follow", "FOLLOW HOST"], ["defend", "DEFEND BASE"]], "follow" if follow else "defend", func(id):
			s.set_qm_mode("follow" if id == "follow" else "")
			show_pause()
			_refocus("qm:" + ("FOLLOW HOST" if id == "follow" else "DEFEND BASE")), {"palette": "o", "size": 15, "h": 40})
		_tag_seg(sg, "qm")
		v.add_child(sg)
		v.add_child(_l("Following host" if follow else "Holding the base", "m4", 11, Color("#a9bccb")))
		col.add_child(v)
	if m.net.mode == "host" and m.net.in_game:
		var cv := UiKit.vbox(4)
		cv.add_child(_l("CREW · HOST CONTROLS", "s8", 13, UiKit.OWARN, 0.22))
		for r in m.net.roster:
			var rid: String = r.id
			cv.add_child(_roster_row("%s · %s" % [str(r.name).to_upper(), Pal.CLASSES.get(r.get("cls", "soldier"), Pal.SOLDIER).name], Color("#5b7a52"), UiKit.OBONE, (func(): m.net.kick(rid)) if r.id != "host" else Callable()))
		col.add_child(cv)
	col.add_child(_fid(UiKit.btn("SETTINGS", "oghost", 16, func(): _go("pause", "settings"), {"h": 46}), "p:settings"))
	if m.social != null and m.social.active():
		col.add_child(_fid(UiKit.btn(_friends_label(), "oghost", 16, func(): show_friends(), {"h": 46}), "p:friends"))
	var more := UiKit.hbox(8)
	if not m.net.is_online():
		more.add_child(UiKit.expand(_fid(UiKit.btn("RESTART", "oghost", 14, func(): m.start_game(), {"h": 40}), "p:restart")))
	more.add_child(UiKit.expand(_fid(UiKit.btn("SKILL TREE", "oghost", 14, func(): _go("pause", "skills"), {"h": 40}), "p:skills")))
	more.add_child(UiKit.expand(_fid(UiKit.btn("INDEX", "oghost", 14, func(): _go("pause", "index"), {"h": 40}), "p:index")))
	col.add_child(more)
	col.add_child(_fid(UiKit.btn("ABANDON THE CLAIM", "oghost", 16, func(): m.to_menu(), {"h": 46}), "p:quit"))
	_settle()


## .overlay .card: a centred column over the dimmed game; returns the column
func _overlay(width: float, bg: float = -1.0) -> VBoxContainer:
	var dim: Control
	if bg < 0:
		var ink := Color(12 / 255.0, 11 / 255.0, 9 / 255.0)
		dim = UiKit.gradient_rect([Color(20 / 255.0, 18 / 255.0, 16 / 255.0, 0.6), Color(ink, 0.95)], [0.0, 1.0], true, Vector2(0.5, 0.3), Vector2(1.1, 1.0))
	else:
		var cr := ColorRect.new()
		cr.color = Color(12 / 255.0, 11 / 255.0, 9 / 255.0, bg)
		dim = cr
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cc)
	var col := UiKit.vbox(16)
	var w := minf(_vs().x - UiKit.px(32), UiKit.px(width))
	col.custom_minimum_size.x = w
	var gm := UiKit.margin(0, 14, 0, 14)   # room for the scrollbar either side, so the column stays centred
	gm.add_child(col)
	var sc := UiKit.scroller(gm)
	sc.custom_minimum_size.x = w + UiKit.px(28)
	cc.add_child(sc)
	_fit_scroll(sc, gm, _vs().y - UiKit.px(40))
	return col


# ---------------------------------------------------------------- the after-action screen (showOver)

func show_results() -> void:
	_begin("results", show_results)
	var s: Sim = m.sim
	var g: Dictionary = s.game
	var p: Dictionary = s.player
	var win: bool = g.won
	var W: float = g.waves
	var endless := is_inf(W)
	var mods: Array = s.mods.map(func(id): return _mod(id).name)
	var modt := (" · " + " + ".join(mods)) if not mods.is_empty() else ""
	var crew := (" · CREW OF %d" % s.players.size()) if s.players.size() > 1 else ""
	var mode_n: String = "OPERATION WHITEOUT" if s.campaign() else ("ENDLESS" if endless else "%d RAIDS" % int(W))
	var held: int = s.bo_stages() if s.blackout() else (int(W) if win or g.end_reason in ["evac", "left"] else (g.wave if g.end_reason == "evacfail" else maxi(0, g.wave - 1)))
	var title := "CLAIM HELD" if win else "CLAIM LOST"
	var eyebrow := "%s · %s · %s%s · %s%s" % [p.C.name, s.Df.name, mode_n, crew, ("ALL %d RAIDS BROKEN" % int(W)) if win else ("%d RAIDS HELD" % held if endless else "STAKE FELL IN RAID %d" % g.wave), modt]
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
		eyebrow = "%s · %s · CITY BLACK OUT%s · %d OF 8 POINTS HELD%s%s" % [p.C.name, s.Df.name, crew, B.held, " · THE DESTROYER IS DOWN" if B.destroyer else "", modt]
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
	var col := _overlay(470, 0.9)
	col.add_child(_l(eyebrow, "s8", 13, UiKit.OWARN, 0.22, 1.3, true))
	col.add_child(_l(title, "s9", 88, UiKit.OBONE if win or g.end_reason == "evac" else UiKit.RUST, 0.02, 0.82, true))
	col.add_child(_l(lede, "m4", 13, UiKit.OBONE, 0.0, 1.55, true))
	var st: Dictionary = g.stats
	var rows: Array = [["Raids survived", held], ["Raiders dropped", st.dropped], ["Walls raised", st.built], ["Walls lost", st.lost], ["Repairs by Delgado", st.get("repairs", 0)], ["Revives", st.get("revives", 0)]]
	if s.pvp() != "":
		rows = [["Your drops", p.kills], ["Times you fell", p.deaths], ["Walls raised", st.built], ["Walls lost", st.lost]]
	var grid := UiKit.grid(2, 16, 10)
	for r in rows:
		var v := UiKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UiKit.rule(UiKit.OLINE))
		v.add_child(UiKit.spacer(6))
		v.add_child(_l(r[0], "m4", 11, UiKit.ODIM))
		v.add_child(_l(str(r[1]), "s9", 30, UiKit.OBONE))
		grid.add_child(v)
	col.add_child(grid)
	if not m.last_reward.is_empty():
		col.add_child(reward_cards(m.last_reward))
	if m.net.mode == "host":
		var b := UiKit.btn("BACK TO THE LOBBY", "ogo", 22, func(): m.net_back_to_lobby(), {"h": 56})
		_focus = b
		col.add_child(_fid(b, "again"))
	elif m.net.mode == "guest":
		col.add_child(_l("Waiting on the host to run it back.", "m4", 13, UiKit.ODIM, 0.0, 1.55, true))
	else:
		var b := UiKit.btn("RUN IT BACK", "ogo", 22, func(): m.start_game(), {"h": 56})
		_focus = b
		col.add_child(_fid(b, "again"))
	col.add_child(_fid(UiKit.btn("LEAVE" if m.net.is_online() else "MAIN MENU", "oghost", 16, func(): m.to_menu(), {"h": 46}), "menu"))
	_settle()


## showRewards: cards for what the run paid (cases, shards, skill points, new items), the nearest milestone and the
## way to the next Supply Case. They come in one after another.
func reward_cards(R: Dictionary) -> HFlowContainer:
	var C := PalLocker.catalog()
	var L: PalLocker = m.locker
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("h_separation", int(UiKit.px(8)))
	row.add_theme_constant_override("v_separation", int(UiKit.px(8)))
	var cards: Array = []
	var wide_w := minf(UiKit.px(470), _vs().x - UiKit.px(32))
	var card := func(border: Color, wide: bool = false, bottom: bool = false) -> VBoxContainer:
		var s := UiKit.sb(Color(21 / 255.0, 19 / 255.0, 15 / 255.0, 0.8), border, 1, [10, 12, 10, 12] if wide else [8, 8, 10, 8])
		if bottom:
			s.border_width_bottom = UiKit.bw(3)
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", s)
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.custom_minimum_size = Vector2(wide_w, 0) if wide else Vector2(UiKit.px(86), UiKit.px(112))
		var v := UiKit.vbox(4)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		pc.add_child(v)
		row.add_child(pc)
		cards.append(pc)
		return v
	var centred := func(l: Label) -> Label:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return l
	if R.get("pending"):
		var v: VBoxContainer = card.call(UiKit.OLINE)
		v.add_child(centred.call(_l("SAVING", "s9", 15, UiKit.OBONE, 0.04)))
		v.add_child(centred.call(_l("Sending your result to your account…", "m4", 9, UiKit.ODIM, 0.04, 1.35, true)))
		return row
	for id in R.cases:
		if R.cases[id] > 0 and C.CASES.has(id):
			var col := Color(C.CASES[id].col)
			var v: VBoxContainer = card.call(col)
			var ic := LockerUI.CaseIcon.new(id, UiKit.px(58))
			ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(ic)
			v.add_child(centred.call(_l("×%d" % R.cases[id], "s9", 20, col, 0.04)))
			v.add_child(centred.call(_l(C.CASES[id].name, "m4", 9, UiKit.ODIM, 0.04, 1.35, true)))
	if R.shards > 0:
		var v: VBoxContainer = card.call(UiKit.OLINE)
		v.add_child(centred.call(_l("◆", "m4", 22, Color("#f0d16b"))))
		v.add_child(centred.call(_l("+%d" % R.shards, "s9", 20, Color("#f0d16b"), 0.04)))
		v.add_child(centred.call(_l("SHARDS", "m4", 9, UiKit.ODIM, 0.04)))
	if R.sp > 0:
		var v: VBoxContainer = card.call(UiKit.OLINE)
		v.add_child(centred.call(_l("✦", "m4", 22, Color("#f0d16b"))))
		v.add_child(centred.call(_l("+%d" % R.sp, "s9", 20, Color("#9fd6ae"), 0.04)))
		v.add_child(centred.call(_l("SKILL POINT" if R.sp == 1 else "SKILL POINTS", "m4", 9, UiKit.ODIM, 0.04)))
	for uid in R.unlocked:
		var c := PalLocker.item(uid)
		if c.is_empty():
			continue
		var rc := Color(C.RAR[c.r].col)
		var v: VBoxContainer = card.call(rc, false, true)
		v.add_child(centred.call(_l("UNLOCKED", "s8", 10, rc, 0.16)))
		var ic := LockerUI.Icon.new(c, UiKit.px(64), L.eq.duplicate(), m.settings.data.setup.get("cls", "soldier"))
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		v.add_child(centred.call(_l(c.name, "s9", 14, UiKit.OBONE, 0.04, 1.1, true)))
	if R.get("kind") == "run":
		var best := next_unlock()
		if not best.is_empty() and best.have > 0:
			var Ld: Dictionary = best.L
			var it := PalLocker.item(Ld.items[best.i][0] + ":" + Ld.items[best.i][1])
			var v: VBoxContainer = card.call(UiKit.OLINE, true)
			v.add_child(centred.call(_l(Ld.title, "s9", 13, UiKit.OWARN, 0.14)))
			var b1 := UiKit.bar(float(best.have) / Ld.steps[best.i], 10)
			b1.line = UiKit.OLINE
			v.add_child(b1)
			v.add_child(centred.call(_l("%d / %d %s · next: %s" % [best.have, Ld.steps[best.i], Ld.units[best.i] if Ld.get("units") else Ld.unit, it.get("name", "")], "m4", 9, UiKit.ODIM, 0.04, 1.35, true)))
		var v2: VBoxContainer = card.call(UiKit.OLINE, true)
		v2.add_child(centred.call(_l("SUPPLY CASE", "s9", 13, UiKit.OWARN, 0.14)))
		var b2 := UiKit.bar(float(R.get("prog", 0)) / 3.0, 10, 3)
		b2.line = UiKit.OLINE
		v2.add_child(b2)
		v2.add_child(centred.call(_l("1 more raid to the next case" if R.get("toNext", 3) == 1 else "%d more raids to the next case" % R.get("toNext", 3), "m4", 9, UiKit.ODIM, 0.04)))
	if cards.is_empty():
		var v: VBoxContainer = card.call(UiKit.OLINE)
		v.add_child(centred.call(_l("NO REWARDS", "s9", 15, UiKit.ODIM, 0.04)))
		v.add_child(centred.call(_l("Hold a raid or win to earn cases.", "m4", 9, UiKit.ODIM, 0.04, 1.35, true)))
	for i in cards.size():   # one after another over about 1.5 s
		var pc: Control = cards[i]
		pc.modulate.a = 0.0
		var tw := pc.create_tween()
		tw.tween_interval(i * minf(0.32, 1.5 / cards.size()))
		tw.tween_property(pc, "modulate:a", 1.0, 0.25)
	return row


## the account told us something changed: redraw what shows it
func on_account_changed() -> void:
	match screen:
		"account":
			if not acct_busy:
				show_account()
		"locker":
			for ui in _lockers(root):
				if not ui.busy and not ui.get_children().any(func(n): return n is CaseOpen):
					ui.refresh()
		"main":
			if sheet == "":
				show_main()


func _lockers(n: Node) -> Array:
	var out: Array = []
	for ch in n.get_children():
		if ch is LockerUI:
			out.append(ch)
		out.append_array(_lockers(ch))
	return out


# ---------------------------------------------------------------- LOCKER (20-locker-ui.js, in locker_ui.gd)

func show_locker() -> void:
	_begin("locker", show_locker)
	var body := _shell("party")
	var ui := LockerUI.new(self)
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_child(ui)
	_settle()


# ---------------------------------------------------------------- friends (19b-social-lobby.js)

func _friends_label() -> String:
	var n: int = m.social.unseen if m.social != null and m.social.active() else 0
	return "FRIENDS" + (" · %s NEW" % ("9+" if n > 9 else str(n)) if n > 0 else "")


func refresh_friends_badge() -> void:
	if not is_instance_valid(_friends_dot):
		return
	var n: int = m.social.unseen if m.social != null and m.social.active() and m.social.ok else 0
	_friends_dot.text = "9+" if n > 9 else str(n)
	_friends_dot.visible = n > 0


func toggle_friends() -> void:
	if screen == "friends":
		close_friends()
	else:
		show_friends()


## the friends list: a dropdown under FRIENDS on the menu pages, a panel over the game from the pause menu
func show_friends() -> void:
	var S: PalSocial = m.social
	if screen != "friends":
		if screen in ["", "results"]:
			return
		_under = screen
		screen = "friends"
		if S.active():
			S.poll()
			if friends_tab == "mail":
				S.mark_seen()
	if is_instance_valid(_drop):
		_drop.queue_free()
	var in_game: bool = _under == "pause"
	var on: bool = S.active()
	var panel := UiKit.panel(Color("#0b1820"), Color("#4f6a74"), 1, [12, 14, 16, 14])
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size.x = UiKit.px(410)
	var col := UiKit.vbox(8)
	panel.add_child(col)
	_drop = Control.new()
	_drop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var catcher := Control.new()   # a click outside closes it
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: close_friends())
	_drop.add_child(catcher)
	_drop.add_child(panel)
	root.add_child(_drop)
	var fb := _friends_btn
	if in_game or not is_instance_valid(fb):
		panel.position = Vector2((_vs().x - panel.custom_minimum_size.x) / 2, UiKit.px(20))
	else:
		var r := fb.get_global_rect()
		panel.position = Vector2(r.end.x - panel.custom_minimum_size.x, r.end.y + UiKit.px(8))
		fb.restyle(_chip_box(UiKit.NAVSEL, UiKit.NAVSEL, [0, 12, 0, 12], [1, 0, 1, 1]), {"normal": UiKit.NAVINK, "hover": UiKit.NAVINK, "pressed": UiKit.NAVINK, "disabled": UiKit.DIM})
	var maxh := _vs().y - panel.position.y - UiKit.px(20)
	# the tabs and CLOSE
	var top := UiKit.hbox(4)
	for t in [["friends", "FRIENDS", str(S.friends.size() if on else 0), false], ["requests", "REQUESTS", str(S.incoming.size()), on and not S.incoming.is_empty()], ["mail", "MAILBOX", str(S.unseen), on and S.unseen > 0]]:
		var id: String = t[0]
		var h := UiKit.hbox(5)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		var tl := _l(t[1], "s8", 12, Color.WHITE, 0.06)
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(tl)
		var extra: Array = []
		if id == "friends":
			var cl := _l(t[2], "m6", 10, Color.WHITE)
			cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			h.add_child(cl)
			extra = [cl]
		elif t[3]:
			var cnt := _l(t[2], "m6", 10, Color.WHITE)
			var cs := UiKit.sb(Color("#e0412f"), Color(0, 0, 0, 0), 0, [0, 4, 0, 4])
			cs.set_corner_radius_all(int(UiKit.px(9)))
			cnt.add_theme_stylebox_override("normal", cs)
			cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cnt.custom_minimum_size = Vector2(UiKit.px(17), UiKit.px(17))
			cnt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(cnt)
		var K := UiKit.kind("tab", id == friends_tab)
		var box := {}
		for s in K.box:
			var bx: StyleBoxFlat = K.box[s].duplicate()
			bx.content_margin_left = UiKit.px(2)
			bx.content_margin_right = UiKit.px(2)
			box[s] = bx
		var b := UiKit.Btn.new(h, box, K.tint)
		b.label = tl
		b.tinted = extra
		b.custom_minimum_size.y = UiKit.px(40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _friends_tab(id))
		_fid(b, "ft:" + id)
		top.add_child(b)
	top.add_child(_fid(UiKit.btn("CLOSE", "ghost", 11, func(): close_friends(), {"w": 44, "h": 44, "pad": [6, 6, 6, 6]}), "ft:close"))
	col.add_child(top)
	var A: PalAccount = m.account
	var status := ""
	if A == null or A.state == "off":
		status = "Friends need a connection to your account."
	elif A.state == "wait":
		status = "Connecting to your account…"
	elif not on:
		status = "Sign in with a saved account to add friends."
	elif S.msg != "":
		status = S.msg
	if status != "":
		col.add_child(_l(status, "m4", 11, UiKit.WARN, 0.0, 1.5, true))
	var body := UiKit.vbox(8)
	var sc := UiKit.scroller(body)
	col.add_child(sc)
	match friends_tab:
		"friends":
			_friends_page(body, on)
		"requests":
			body.add_child(_social_section("INCOMING", "", false, Callable()))
			if not on:
				_social_empty(body, "Sign in with a saved account to get friend requests.", true)
			else:
				if S.incoming.is_empty():
					_social_empty(body, "No requests waiting.", false)
				for r in S.incoming:
					var rr: Dictionary = r
					body.add_child(_person(r.user, "Sent " + PalSocial.ago(str(r.get("at", ""))), [["ACCEPT", func(): S.answer(rr, true)], ["DECLINE", func(): S.answer(rr, false)]]))
			body.add_child(_social_section("SENT", "", false, Callable()))
			if on:
				if S.outgoing.is_empty():
					_social_empty(body, "No requests sent.", false)
				for r in S.outgoing:
					var rr: Dictionary = r
					body.add_child(_person(r.user, "Waiting · sent " + PalSocial.ago(str(r.get("at", ""))), [["CANCEL", func(): S.cancel(rr)]]))
		"mail":
			if not on:
				_social_empty(body, "Sign in to get your mail.", true)
			else:
				for i in S.invites:
					var ii: Dictionary = i
					var ok: bool = Time.get_unix_time_from_datetime_string(str(i.get("expires_at", "")).substr(0, 19)) > Time.get_unix_time_from_system()
					body.add_child(_person(i.get("user", {"username": "Your friend"}), PalSocial.invite_line(i), [["ACCEPT", func(): S.answer_invite(ii, true), not ok], ["DECLINE", func(): S.answer_invite(ii, false)]]))
				if S.notes.is_empty() and S.invites.is_empty():
					_social_empty(body, "Nothing here yet.", false)
				for n in S.notes:
					var who: String = n.user.username if n.get("user") is Dictionary and n.user.get("username") else "A player"
					var t: String = ("%s sent you a friend request" % who) if n.get("kind") == "friend_request" else (("%s accepted your friend request" % who) if n.get("kind") == "friend_accepted" else (str(n.get("data", {}).get("text", "Message")) if n.get("data") is Dictionary else "Message"))
					var unseen: bool = not n.get("seen_at")
					var mp := UiKit.panel(Color(22 / 255.0, 40 / 255.0, 50 / 255.0, 0.6), UiKit.WARN if unseen else UiKit.ROWLINE, [1, 1, 1, 3] if unseen else 1, [9, 10, 9, 10])
					var mv := UiKit.vbox(3)
					mv.add_child(_l(t, "m6", 12, Color("#e3ecea"), 0.0, 1.4, true))
					mv.add_child(_l(PalSocial.ago(str(n.get("created_at", ""))), "m4", 9, Color("#8fa8ae")))
					mp.add_child(mv)
					body.add_child(mp)
	var fit := func() -> void:
		if is_instance_valid(sc) and is_instance_valid(body):
			sc.custom_minimum_size.y = minf(maxh - UiKit.px(110), body.get_combined_minimum_size().y)
	body.minimum_size_changed.connect(fit)
	fit.call_deferred()
	_refocus("ft:" + friends_tab)


func _friends_tab(id: String) -> void:
	var S: PalSocial = m.social
	friends_tab = id
	S.msg = ""
	if id == "mail":
		S.mark_seen()
	if id == "friends":
		S.refresh_saved()
	show_friends()


func _social_empty(box: VBoxContainer, text: String, with_acct: bool) -> void:
	box.add_child(_l(text, "m4", 11, Color("#a5bcc3"), 0.0, 1.7, true))
	if with_acct and m.account != null and m.account.state != "off":
		box.add_child(_fid(UiKit.btn("OPEN ACCOUNT", "ghost", 16, func():
			close_friends()
			show_account(), {"h": 46}), "f:acct"))


func _friends_page(body: VBoxContainer, on: bool) -> void:
	var S: PalSocial = m.social
	body.add_child(_l("FIND A PLAYER", "s8", 12, UiKit.KEYC, 0.12))
	var fr := UiKit.hbox(6)
	var find := UiKit.field("", "Exact username", {"size": 12, "h": 42})
	find.max_length = 16
	find.editable = on and not S.busy
	find.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	find.text_submitted.connect(func(t: String): S.find(t))
	fr.add_child(find)
	var fbtn := UiKit.btn("FIND", "go", 16, func(): S.find(find.text), {"w": 58, "h": 42})
	fbtn.disabled = not on or S.busy
	fr.add_child(fbtn)
	body.add_child(fr)
	if on and S.result != null:
		var r: Dictionary = S.result
		var isf := S.friends.any(func(f): return f.id == r.id)
		var sent := S.outgoing.any(func(q): return q.user.id == r.id)
		var mine: bool = r.id == S._me()
		var acts: Array = []
		if not isf:
			acts.append(["REQUESTED" if sent else "ADD FRIEND", func(): S.send_request(r), sent or mine])
		acts.append(["SAVED" if S.saved.has(r.id) else "SAVE", func(): S.save_player(r.id, true), S.saved.has(r.id) or mine])
		body.add_child(_person(r, "Already your friend" if isf else ("In your Recent list" if S.saved.has(r.id) else "Player found"), acts))
	body.add_child(_social_section("FRIENDS", "", on, func(): S.poll()))
	var fl := UiKit.vbox(10)
	body.add_child(fl)
	if not on:
		_social_empty(fl, "Your crew starts here. Sign in with a saved account, then find a player by username.", true)
	elif not S.loaded:
		_social_empty(fl, "Loading your friends…", false)
	elif not S.ok:
		_social_empty(fl, "Friends could not be loaded right now. Try Refresh.", false)
	elif S.friends.is_empty():
		_social_empty(fl, "No friends yet. Find someone above and send a request.", false)
	for f in (S.friends if on else []):
		var ff: Dictionary = f
		var acts: Array = []
		var room: Dictionary = S.room_of(f.id)
		if not room.is_empty():
			var code: String = room.code
			acts.append(["FULL" if int(room.get("players", 0)) >= 6 else "JOIN", func(): m.net_join(code), int(room.get("players", 0)) >= 6 or m.net.mode != "solo"])
		if m.net.mode == "host":
			acts.append(["INVITE", func(): S.invite(ff), not S.can_invite()])
		acts.append(["REMOVE", func(): S.remove_friend(ff)])
		fl.add_child(_person(f, S.room_text(f.id), acts))
	body.add_child(_social_section("RECENT", str(S.saved.size() if on else 0), false, Callable()))
	var rl := UiKit.vbox(10)
	body.add_child(rl)
	if on and S.profiles.is_empty():
		_social_empty(rl, "Players you save show up here." if S.saved.is_empty() else "Loading…", false)
	for pr in (S.profiles if on else []):
		var pp: Dictionary = pr
		var acts: Array = []
		var room: Dictionary = S.room_of(pr.id)
		if not room.is_empty():
			var code: String = room.code
			acts.append(["JOIN", func(): m.net_join(code), m.net.mode != "solo"])
		if not S.friends.any(func(f): return f.id == pp.id):
			acts.append(["ADD", func(): S.send_request(pp), S.outgoing.any(func(q): return q.user.id == pp.id)])
		acts.append(["REMOVE", func(): S.save_player(pp.id, false)])
		rl.add_child(_person(pr, S.room_text(pr.id), acts))
	body.add_child(UiKit.spacer(10))
	body.add_child(_l("JOIN shows when a friend has a listed room. Players without one may still be playing privately.", "m4", 9, Color("#839ba5"), 0.0, 1.7, true))


func close_friends() -> void:
	if screen != "friends":
		return
	screen = _under
	if is_instance_valid(_drop):
		_drop.queue_free()
	_drop = null
	if is_instance_valid(_friends_btn):
		var bg := Color(31 / 255.0, 40 / 255.0, 38 / 255.0, 0.8)
		_friends_btn.restyle(_chip_box(bg, UiKit.NAVSEL, [0, 12, 0, 12], [1, 0, 1, 1]), {"normal": UiKit.BONE, "hover": UiKit.NAVINK, "pressed": UiKit.NAVINK, "disabled": UiKit.DIM})
		_friends_btn.grab_focus()
	elif screen == "pause":
		_refocus("p:friends")


func _social_section(title: String, count: String, refresh: bool, cb: Callable) -> Control:
	var v := UiKit.vbox(0)
	v.add_child(UiKit.spacer(6))
	v.add_child(UiKit.rule(UiKit.PLINE))
	v.add_child(UiKit.spacer(10))
	var h := UiKit.hbox(4)
	h.add_child(_l(title, "s8", 12, UiKit.KEYC, 0.12))
	if count != "":
		h.add_child(_l(count, "m6", 10, UiKit.DIM))
	var sp := UiKit.spacer()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	if cb.is_valid():
		var r := UiKit.btn("REFRESH", "nav", 10, cb, {"face": "m4", "em": 0.0, "pad": [6, 6, 6, 6],
			"box": {"normal": UiKit.sb(Color(0, 0, 0, 0)), "hover": UiKit.sb(Color(1, 1, 1, 0.06)), "pressed": UiKit.sb(Color(1, 1, 1, 0.1)), "disabled": UiKit.sb(Color(0, 0, 0, 0))},
			"tint": {"normal": Color("#d1e1e6"), "hover": Color.WHITE, "pressed": Color.WHITE, "disabled": Color("#d1e1e6", 0.45)}})
		r.disabled = not refresh
		h.add_child(r)
	v.add_child(h)
	v.add_child(UiKit.spacer(8))
	return v


## .friendRow: a player, a line about them, and what you can do
func _person(prof: Dictionary, status: String, actions: Array) -> Control:
	var p := UiKit.panel(Color("#1b303e"), UiKit.ROWLINE, 1, [10, 8, 10, 8])
	var v := UiKit.vbox(8)
	var top := UiKit.hbox(8)
	top.add_child(Avatar.new(PalLocker.parse_cos(str(prof.get("cos", ""))), "soldier", 40))
	var tv := UiKit.vbox(5)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(_l(str(prof.get("username", "PLAYER")), "s8", 17, UiKit.BONE))
	tv.add_child(_l(status, "m4", 8, Color("#add5d0"), 0.0, 1.6, true))
	top.add_child(tv)
	v.add_child(top)
	var acts := UiKit.hbox(6)
	acts.alignment = BoxContainer.ALIGNMENT_END
	for i in actions.size():
		var a: Array = actions[i]
		var main_btn: bool = i == 0 and actions.size() > 1
		var pad := [5, 9, 5, 9]
		var bg := UiKit.WARN if main_btn else Color("#355465")
		var bd := UiKit.WARN if main_btn else Color("#698690")
		var box := {"normal": UiKit.sb(bg, bd, 1, pad), "hover": UiKit.sb(bg.lightened(0.12), bd, 1, pad), "pressed": UiKit.sb(bg.darkened(0.1), bd, 1, pad), "disabled": UiKit.sb(Color(bg, 0.45), Color(bd, 0.45), 1, pad)}
		var fg := Color("#152832") if main_btn else Color("#eaf3ec")
		var b := UiKit.btn(a[0], "ghost", 12, a[1], {"h": 32, "pad": pad, "em": 0.06, "box": box, "tint": {"normal": fg, "hover": fg, "pressed": fg, "disabled": Color(fg, 0.45)}})
		b.disabled = (a.size() > 2 and a[2]) or m.social.busy
		acts.add_child(b)
	v.add_child(acts)
	p.add_child(v)
	return p


# ---------------------------------------------------------------- drawn bits

## the two-person outline on FRIENDS
class PeopleIcon extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size.x / 20.0
		var w := maxf(1.2, 1.7 * s)
		draw_arc(Vector2(7, 5) * s, 3 * s, 0, TAU, 20, Color.WHITE, w, true)
		draw_arc(Vector2(7, 15.5) * s, 5.5 * s, PI, TAU, 16, Color.WHITE, w, true)
		draw_arc(Vector2(14.2, 4.6) * s, 2.4 * s, 0, TAU, 16, Color.WHITE, w * 0.9, true)
		draw_arc(Vector2(14.6, 14.5) * s, 4.2 * s, PI * 1.3, TAU, 12, Color.WHITE, w * 0.9, true)


class PlusIcon extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) / 2
		var w := maxf(1.0, r * 0.16)
		draw_line(Vector2(c.x - r, c.y), Vector2(c.x + r, c.y), Color.WHITE, w, true)
		draw_line(Vector2(c.x, c.y - r), Vector2(c.x, c.y + r), Color.WHITE, w, true)


## the gold › at the end of a setup line
class Chevron extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var h := size.y * 0.36
		var w := h * 0.6
		var c := size / 2
		var lw := maxf(1.5, size.y * 0.075)
		draw_polyline(PackedVector2Array([c + Vector2(-w / 2, -h / 2), c + Vector2(w / 2, 0), c + Vector2(-w / 2, h / 2)]), UiKit.WARN, lw, true)


class Underline extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var p: Node = get_parent()
		var l: Label = p.label if p is UiKit.Btn else null
		if l == null:
			return
		draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), l.self_modulate, 1.0)


class Dot extends Control:
	var col := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size / 2, minf(size.x, size.y) / 2, col, true, -1.0, true)


## the profile picture: the equipped outfit on a dark round wash (identityAvatar)
class Avatar extends Control:
	var eq: Dictionary
	var cls := "soldier"

	func _init(equipped: Dictionary, klass: String, css: float) -> void:
		eq = equipped
		cls = klass
		custom_minimum_size = Vector2(UiKit.px(css), UiKit.px(css))
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _draw() -> void:
		var S := size.x
		var c := size / 2
		var steps := 12
		for i in steps:   # radial-gradient(circle,#43534a,#172125)
			var f := 1.0 - float(i) / steps
			draw_circle(c, S * 0.72 * f, Color("#172125").lerp(Color("#43534a"), 1.0 - f), true, -1.0, false)
		var look := Wardrobe.look_for(eq, cls)
		var fr := Wardrobe.frame(look, LockerUI.THUMB_ANG, "skin")
		var sc: float = S / (fr.s * 1.08)
		Wardrobe.draw(self, look, LockerUI.THUMB_ANG, 0, sc, S / 2 - fr.cx * sc, S / 2 - fr.cy * sc, false)


## a map's layout as a tiny diamond (mapThumb in 19b-social-lobby.js)
class MapThumb extends Control:
	static var cache := {}
	var id := ""
	var sz := "std"
	var pvp := ""

	func _init(map_id: String, size_id: String, pv: String) -> void:
		id = map_id
		sz = size_id
		pvp = pv
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, UiKit.px(100))
		resized.connect(func():
			var h := roundf(size.x * 116.0 / 172.0)
			if absf(custom_minimum_size.y - h) > 1:
				custom_minimum_size.y = h)

	func _lay() -> Dictionary:
		var key := "%s|%s|%s" % [id, sz, pvp]
		if not cache.has(key):
			cache[key] = PalMaps.lay_pvp(id, pvp) if pvp != "" else PalMaps.lay(id, sz)
		return cache[key]

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#10181c"))
		var L := _lay()
		var n: int = L.get("N", 16)
		var k := minf(size.x / 172.0, size.y / 116.0)
		var off := Vector2((size.x - 172 * k) / 2, (size.y - 116 * k) / 2)
		var tw := 172.0 / (n + 2) / 1.02
		var th := tw * 0.5
		var ox := 86.0
		var oy := 6.0
		var terr: PackedByteArray = L.get("terr", PackedByteArray())
		var hts: PackedByteArray = L.get("heights", PackedByteArray())
		var conn: PackedByteArray = L.get("connectors", PackedByteArray())
		var base := Color("#403a33") if id == "quarry" else (Color("#394a2c") if id == "river" else Color("#4a4030"))
		var cols := {PalMaps.T_WATER: Color("#2a5a74"), PalMaps.T_BRIDGE: Color("#7a5a38"), PalMaps.T_LOW: Color("#3e4a30"), PalMaps.T_CRACK: Color("#5a4838"), PalMaps.T_ROCK: Color("#7c776d"), PalMaps.T_DRUM: Color("#ff8a2a")}
		for j in n:
			for i in n:
				var kk := j * n + i
				var t: int = terr[kk] if kk < terr.size() else 0
				var h: int = hts[kk] if kk < hts.size() else 0
				var sx := ox + (i - j) * tw / 2
				var sy := oy + (i + j) * th / 2 - h * 4
				var col: Color
				if id == "frost":
					col = Color("#749baa") if kk < conn.size() and conn[kk] else [Color("#bcd7e4"), Color("#dceaf0"), Color("#eef7fb")][clampi(h, 0, 2)]
				else:
					col = cols.get(t, base)
				var pts := PackedVector2Array([Vector2(sx, sy), Vector2(sx + tw / 2, sy + th / 2), Vector2(sx, sy + th), Vector2(sx - tw / 2, sy + th / 2)])
				for q in pts.size():
					pts[q] = off + pts[q] * k
				draw_colored_polygon(pts, col)
		var dot := func(i: float, j: float, c: Color, r: float) -> void:
			var sx := ox + (i - j) * tw / 2
			var sy := oy + (i + j) * th / 2 + th / 2
			draw_circle(off + Vector2(sx, sy) * k, r * k, c, true, -1.0, true)
		for cv in L.get("cover", []):
			dot.call(cv[0], cv[1], Color("#b8b4aa"), 1.5)
		for nd in L.get("nodes", []):
			dot.call(nd.i, nd.j, [Color("#c09058"), Color("#a0533c"), Color("#a3a9a8")][clampi(int(nd.get("type", 0)), 0, 2)], 1.6)
		for s in L.get("spawns", []):
			for t in s.get("tiles", []):
				dot.call(t[0], t[1], Color("#d65a3a"), 1.2)
		var cores: Array = L.get("cores", [L.core] if L.get("core") != null else [])
		for c in cores:
			dot.call(c[0], c[1], Color("#e2b436"), 3)
		for t in L.get("pspawns", []):
			dot.call(t[0], t[1], Color("#6fd0e0"), 1.8)


## a dashed outline (the empty party places)
class DashBox extends StyleBox:
	var bg := Color(0, 0, 0, 0)
	var line := Color.WHITE

	static func make(fill: Color, col: Color, pad: Array) -> DashBox:
		var d := DashBox.new()
		d.bg = fill
		d.line = col
		d.content_margin_top = UiKit.px(pad[0])
		d.content_margin_right = UiKit.px(pad[1])
		d.content_margin_bottom = UiKit.px(pad[2])
		d.content_margin_left = UiKit.px(pad[3])
		return d

	func _draw(ci: RID, rect: Rect2) -> void:
		RenderingServer.canvas_item_add_rect(ci, rect, bg)
		var w := float(UiKit.bw(1))
		var dash := UiKit.px(3)
		var gap := UiKit.px(2)
		var x := rect.position.x
		while x < rect.end.x:
			var e := minf(rect.end.x, x + dash)
			RenderingServer.canvas_item_add_rect(ci, Rect2(x, rect.position.y, e - x, w), line)
			RenderingServer.canvas_item_add_rect(ci, Rect2(x, rect.end.y - w, e - x, w), line)
			x += dash + gap
		var y := rect.position.y
		while y < rect.end.y:
			var e := minf(rect.end.y, y + dash)
			RenderingServer.canvas_item_add_rect(ci, Rect2(rect.position.x, y, w, e - y), line)
			RenderingServer.canvas_item_add_rect(ci, Rect2(rect.end.x - w, y, w, e - y), line)
			y += dash + gap


## The browser's stage picture (drawPartyPreview's back and front layers, a 1000x780 canvas) over the page's hero box:
## the empty spots' "+" and the others' name plates; with no 3D models in this build, the pads and painted figures too.
class Hero2D extends Control:
	var people: Array = []
	var party := false
	var locker := false
	var figures := true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_people(p: Array, mode: String, paint: bool) -> void:
		people = p
		party = mode == "party"
		locker = mode == "locker"
		figures = paint
		queue_redraw()

	func _process(_dt: float) -> void:
		if figures and not people.is_empty():
			queue_redraw()

	func _pad(c: Vector2, r: float, on: bool) -> void:
		var pts := PackedVector2Array()
		for i in 40:
			var a := TAU * i / 40
			pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.22))
		draw_colored_polygon(pts, Color(170 / 255.0, 239 / 255.0, 239 / 255.0, 0.12) if on else Color(122 / 255.0, 171 / 255.0, 192 / 255.0, 0.06))
		pts.append(pts[0])
		draw_polyline(pts, Color("#b4edee") if on else Color("#597386"), 3.0 if on else 2.0, true)

	## a name plate under someone's feet (stagePlate)
	func _plate(px: float, py: float, name: String, sub: String, sc: float) -> void:
		var f := roundf(sc * 2.9)
		var big := UiKit.face("s8")
		var small := UiKit.face("m6")
		var w := maxf(big.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(f)).x, f * 3.2) + f * 1.1
		var r := Rect2(px - w / 2, py, w, f * 1.9)
		draw_rect(r, Color("#12222bd8"))
		draw_rect(r, Color("#718b8f"), false, 2.0)
		draw_string(big, Vector2(r.position.x, py + f * 0.2 + big.get_ascent(int(f))), name, HORIZONTAL_ALIGNMENT_CENTER, w, int(f), Color("#eef3ed"))
		var fs := int(roundf(f * 0.52))
		draw_string(small, Vector2(r.position.x, py + f * 1.25 + small.get_ascent(fs)), sub, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color("#ecd347"))

	func _draw() -> void:
		if people.is_empty():
			return
		var xf := Lobby3D.canvas_xf(Rect2(Vector2.ZERO, size))
		var k: float = xf[0]
		var off: Vector2 = xf[1]
		if k < 0.05:   # the page is still laying out: no room to draw yet
			return
		var t := Time.get_ticks_msec() / 1000.0
		var me := Lobby3D.me_spot(locker)
		if figures:
			_pad(off + Vector2(me[0], me[1]) * k, me[2] * 11.5 * k, true)
		if party:
			var order := range(5)
			order.sort_custom(func(a, b): return Menus.STAGE2D.others[a][1] < Menus.STAGE2D.others[b][1])
			for i in order:
				var s: Array = Menus.STAGE2D.others[i]
				var who: Dictionary = people[i + 1] if i + 1 < people.size() else {}
				var at := off + Vector2(s[0], s[1]) * k
				if figures:
					_pad(at, s[2] * 9.5 * k, not who.is_empty())
				if not who.is_empty():
					if figures:
						Wardrobe.draw(self, Wardrobe.look_for(who.cos, who.cls), [0.62, -0.62, 0.5, -0.5, 0.1][i], 0, s[2] * k, at.x, at.y, false)
				elif i < 4:
					draw_string(UiKit.face("m4"), at + Vector2(-24 * k, -28 * k), "+", HORIZONTAL_ALIGNMENT_CENTER, 48 * k, int(48 * k), Color("#7e98a5"))
			for i in order:
				var s: Array = Menus.STAGE2D.others[i]
				var who: Dictionary = people[i + 1] if i + 1 < people.size() else {}
				if not who.is_empty():
					_plate(off.x + s[0] * k, off.y + (s[1] + s[2] * 2.4) * k, str(who.get("name", "PLAYER")).to_upper(), Pal.CLASSES.get(who.cls, {}).get("name", "PLAYER"), s[2] * k)
		if not figures:
			return
		var p: Dictionary = people[0]
		var look := Wardrobe.look_for(p.cos, p.cls)
		var ang := 0.35 + (0.0 if PalSettings.reduce_motion else sin(t / 4.5) * 0.09)
		var at := Vector2(off.x + me[0] * k, off.y + (me[1] - 4) * k)
		if look.get("aura"):
			CosFx.paint_aura(self, look.aura, at.x, at.y, me[2] * k, t, 1, "ground")
		Wardrobe.draw(self, look, ang, t, me[2] * k, at.x, at.y, false)
		if look.get("aura"):
			CosFx.paint_aura(self, look.aura, at.x, at.y, me[2] * k, t, 1, "top")
