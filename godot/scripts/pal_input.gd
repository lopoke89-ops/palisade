class_name PalInput
extends Node
## Controller and touch (08-input.js, 08b-pad.js). The keyboard and mouse go through Godot's InputMap (pal_* actions);
## a controller is read here every frame in the browser's button numbering and its own remappable table; touch gets
## two thumb sticks (left half moves, right half aims and fires) and on-screen buttons. Whatever was used last is
## the mode: "mouse", "pad" or "touch". In menus the controller drives Godot's focus (d-pad or left stick, A, B).

const SR := 56.0   # a touch stick's reach in pixels

var m   # the main node
var mode := "mouse"
var pad_kind := "xbox"
var pad_dev := -1
var prev: Array = []
var cur: Array = []
var mv := Vector2.ZERO   # left stick, deadzoned
var aim := Vector2.ZERO   # right stick
var amag := 0.0
var fire := false
var build_t := 0.0
var nav_dir := ""
var nav_t := 0.0
var bind_act := ""   # waiting for a controller button for this action (Settings)
var bind_t := 0.0
var on_bound: Callable
## touch
var stick_move := {"id": -1, "o": Vector2.ZERO, "v": Vector2.ZERO, "mag": 0.0}
var stick_aim := {"id": -1, "o": Vector2.ZERO, "v": Vector2.ZERO, "mag": 0.0}
var buttons: Array = []   # [Rect2, id] drawn by the main node this frame (touch mode)
var held_btn := {}   # touch index -> button id
var last_mouse := Vector2(-1, -1)


func _ready() -> void:
	Input.joy_connection_changed.connect(_joy_changed)
	for d in Input.get_connected_joypads():
		_joy_changed(d, true)


func _joy_changed(device: int, connected: bool) -> void:
	if connected and pad_dev < 0:
		pad_dev = device
		var nm := Input.get_joy_name(device).to_lower()
		pad_kind = "ps" if (nm.contains("playstation") or nm.contains("dualshock") or nm.contains("dualsense") or nm.contains("ps4") or nm.contains("ps5") or nm.contains("054c")) else "xbox"
	elif not connected and device == pad_dev:
		pad_dev = -1
		var others := Input.get_connected_joypads()
		if not others.is_empty():
			_joy_changed(others[0], true)
		elif mode == "pad":
			set_mode("mouse")


func set_mode(md: String) -> void:
	if mode == md:
		return
	mode = md
	fire = false
	if md != "touch":
		_free_sticks()


static func deadzone(v: Vector2, d: float) -> Array:
	var l := v.length()
	if l < d:
		return [Vector2.ZERO, 0.0]
	var mg := minf(1.0, (l - d) / (1 - d))
	return [v / l * mg, mg]


## the controller in browser numbering: 17 buttons, the triggers past 0.35 count as pressed
func _read_pad() -> Array:
	var out: Array = []
	out.resize(17)
	out.fill(false)
	if pad_dev < 0:
		return out
	var d := pad_dev
	var J := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, -1, -1,
		JOY_BUTTON_BACK, JOY_BUTTON_START, JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN,
		JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_GUIDE]
	for i in 17:
		if J[i] >= 0:
			out[i] = Input.is_joy_button_pressed(d, J[i])
	out[6] = Input.get_joy_axis(d, JOY_AXIS_TRIGGER_LEFT) > 0.35
	out[7] = Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT) > 0.35
	return out


func hit(i: int) -> bool:
	return i >= 0 and i < cur.size() and cur[i] and not (i < prev.size() and prev[i])


## called every frame by the main node before the sim runs
func tick(dt: float, in_menu: bool) -> void:
	if pad_dev < 0:
		fire = false
		mv = Vector2.ZERO
		aim = Vector2.ZERO
		amag = 0.0
		return
	cur = _read_pad()
	var d := pad_dev
	var L := Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y))
	var R := Vector2(Input.get_joy_axis(d, JOY_AXIS_RIGHT_X), Input.get_joy_axis(d, JOY_AXIS_RIGHT_Y))
	mv = deadzone(L, 0.2)[0]
	var ra := deadzone(R, 0.25)
	aim = ra[0]
	amag = ra[1]
	if bind_act != "":   # Settings is waiting for a button: whichever is pressed, from any mode
		_bind_tick()
		prev = cur
		return
	if mode != "pad" and (cur.any(func(b): return b) or L.length() > 0.5 or R.length() > 0.5):
		set_mode("pad")   # the first touch only wakes it
		prev = cur
		return
	if mode == "pad":
		if in_menu:
			fire = false
			_menu_pad(dt, L)
		else:
			_game_pad()
	prev = cur


func _game_pad() -> void:
	var M: Dictionary = m.settings.data.pad
	fire = cur[M.fire] if M.fire >= 0 else false
	if hit(M.fire):
		m.mouse_pulls = (m.mouse_pulls + 1) & 255   # one pull per trigger press, like a click
	if hit(PalSettings.PB.MENU):
		fire = false
		m.do_action("pause")
		return
	var now := Time.get_ticks_msec() / 1000.0
	for id in ["nade", "special", "armory", "piece", "matPrev", "matNext", "start", "reload", "delgado", "sprint", "skills", "mat1", "mat2", "mat3"]:
		if M.get(id, -1) >= 0 and hit(M[id]):
			m.do_action(id)
	if M.build >= 0:   # hold to keep building
		if hit(M.build):
			m.do_action("build")
			build_t = now + 0.35
		elif cur[M.build] and now >= build_t:
			m.do_action("build")
			build_t = now + 0.2


## menus: the d-pad or left stick moves Godot's focus, A presses, B goes back
func _menu_pad(dt: float, L: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if hit(PalSettings.PB.MENU):
		m.do_action("pause")
		return
	var dir := "up" if cur[12] or L.y < -0.5 else ("down" if cur[13] or L.y > 0.5 else ("left" if cur[14] or L.x < -0.5 else ("right" if cur[15] or L.x > 0.5 else "")))
	if dir == "":
		nav_dir = ""
	elif dir != nav_dir:
		nav_dir = dir
		nav_t = now + 0.38
		m.menu_nav(dir)
	elif now >= nav_t:
		nav_t = now + 0.11
		m.menu_nav(dir)
	if hit(0):
		m.menu_nav("accept")
	if hit(1):
		m.menu_nav("back")
	if hit(4) or hit(5):
		m.menu_nav("next" if hit(5) else "prev")


func start_bind(act: String, cb: Callable) -> void:
	bind_act = act
	bind_t = Time.get_ticks_msec() / 1000.0 + 6.0
	on_bound = cb
	prev = _read_pad()


func _bind_tick() -> void:
	if Time.get_ticks_msec() / 1000.0 > bind_t:
		bind_act = ""
		on_bound.call(-2)
		return
	for i in 17:
		if hit(i):
			var a := bind_act
			bind_act = ""
			if i == PalSettings.PB.MENU:   # the menu button stays the pause button
				on_bound.call(-2)
				return
			for k in m.settings.data.pad:   # a button does one thing: whoever had it gives it up
				if m.settings.data.pad[k] == i and k != a:
					m.settings.data.pad[k] = -1
			m.settings.data.pad[a] = i
			on_bound.call(i)
			return


func rumble(ms: float) -> void:
	if mode != "pad" or pad_dev < 0 or not m.settings.data.haptics:
		return
	Input.start_joy_vibration(pad_dev, minf(1.0, 0.3 + ms / 120.0), minf(1.0, ms / 90.0), clampf(ms * 1.5, 60, 400) / 1000.0)


# ---------------------------------------------------------------- touch

func _free_sticks() -> void:
	for s in [stick_move, stick_aim]:
		s.id = -1
		s.v = Vector2.ZERO
		s.mag = 0.0
	held_btn.clear()


func _stick_set(s: Dictionary, p: Vector2) -> void:
	var d: Vector2 = p - s.o
	var l: float = d.length()
	if l > SR:
		d *= SR / l
	s.v = d / SR
	s.mag = minf(1.0, l / SR)


## touch and mouse events reach the game here (after the menus have had theirs)
func handle(e: InputEvent) -> bool:
	if e is InputEventScreenTouch:
		set_mode("touch")
		if e.pressed:
			for b in buttons:
				if b[0].has_point(e.position):
					held_btn[e.index] = b[1]
					m.do_action(b[1])
					return true
			var W: float = m.v.W
			var s: Dictionary = stick_move if e.position.x < W * 0.45 else stick_aim
			if s.id < 0:
				s.id = e.index
				s.o = e.position
				s.v = Vector2.ZERO
				s.mag = 0.0
		else:
			held_btn.erase(e.index)
			for s in [stick_move, stick_aim]:
				if s.id == e.index:
					s.id = -1
					s.v = Vector2.ZERO
					s.mag = 0.0
		return true
	if e is InputEventScreenDrag:
		for s in [stick_move, stick_aim]:
			if s.id == e.index:
				_stick_set(s, e.position)
		return true
	if (e is InputEventMouseButton or e is InputEventMouseMotion) and e.device == InputEvent.DEVICE_ID_EMULATION:
		return true   # a finger's copy as a mouse: the touch above already handled it
	if e is InputEventMouseMotion:
		if mode == "pad" and last_mouse.x >= 0 and (e.position - last_mouse).length() > 6:
			set_mode("mouse")   # the mouse takes over once it really moves, not when a desk bump nudges it
		last_mouse = e.position
		if mode == "touch":
			set_mode("mouse")
	if e is InputEventMouseButton and e.pressed:
		set_mode("mouse")
	if e is InputEventKey and e.pressed and mode == "pad":
		set_mode("mouse")
	return false
