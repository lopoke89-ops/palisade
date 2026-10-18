extends Node2D
## The client: input, camera, procedural drawing (ported from 15-render.js / 16-characters.js / 17-scenery.js) and the HUD.
## Everything is drawn with CanvasItem calls in _draw, the same shapes the browser paints on its Canvas2D.

const FIG := 1.18
const PART_CAP := 600

var sim := Sim.new()
var profile := PalProfile.new()
var skills_open := false
var sk_buttons: Array = []
var sk_reset := Rect2()
var run_sp := -1
var locker: PalLocker   # cosmetics, cases and shards (18-cosmetics.js)
var last_reward := {}   # what the run that just ended paid
var looks := {}   # outfit|class -> wardrobe look
var pmotion := {}   # player id -> presentation motion
var mouse_pulls := 0   # left-button presses so far (the bolt and pump guns buffer a click)
var draw_alpha := 1.0   # people drawn faded (stealth) multiply their colours by this
var next_cls := "soldier"   # the next game's setup (from Match Setup)
var next_opt := {"map": "yard", "size": "std", "mode": "5", "diff": "normal", "mods": []}   # skill points this run earned (shown on the end screen), -1 until the run ends
var audio := PalAudio.new()
var v := IsoView.new()
var parts: Array = []
var cparts: Array = []   # kill-effect and tracer particles (the browser's emit kinds) and painted finishers
var flashes: Array = []
var rings: Array = []
var zaps: Array = []
var slashes: Array = []
var armory_open := false
var arm_buttons: Array = []   # [Rect2, key] drawn this frame, clicked in _unhandled_input
var floats: Array = []
var toasts: Array = []
var shake := 0.0
var shake_t := 0.0
var font: Font
var mouse_seen := false
var vb := [0, 0, 0, 0]   # this frame's visible tiles (i0, i1, j0, j1), so the 64x64 city only draws what's on screen
var city_map: ImageTexture = null   # Black Out's mini-map, drawn once a game
var draw_us := 0   # how long the last _draw took (the screenshot test reports it)
var cv: CanvasItem = self   # what the drawing helpers draw on: this node, or a ground chunk while it paints
var ground: Node2D   # the ground chunks' parent, drawn behind everything and moved with the camera
var ground_key := ""
var game_n := 0   # counts new games and chapter changes (the ground repaints)
var trees_back: Array = []
var trees_front: Array = []
var front_root: Node2D   # the near side's fence and trees, over the action, moved with the camera
var front_groups := {}   # front chunk key -> {node, edges, trees}
var fade_t := 0.0
var light := {"L": 0.12, "r": 28.0, "g": 34.0, "b": 44.0, "warm": 0.0}   # time of day, eased toward the raid's
var light_rect: ColorRect   # night: a shade with holes round every light
var post_rect: ColorRect   # storm tint, vignette, low-health edge
var fx_layer: PaintLayer   # boss warnings and the evac ring, over the night
var glow_layer: PaintLayer   # muzzle flashes and lamp glows, added on
var ui_layer: PaintLayer   # nameplates, prompts, crosshair, floating text and the HUD
var wx_a := 0.0   # the storm fading in and out
var glow_tex: GradientTexture2D
var settings := PalSettings.new()
var inp: PalInput
var menus: Menus
var account: PalAccount   # the Supabase account and the cloud locker (19-accounts.js)
var net: PalNet   # online play (21-online.js): hosting, joining, the lobby
var social: PalSocial   # friends, invitations, the open games list
var feed: Array = []   # the kill feed: {text, col, t}
var draft_wave := -1   # the raid the run draft was last saved at
var casino_ui   # CasinoUI: the table sheets (scripts/casino_ui.gd)
var cas_glow: Array = []   # this frame's neon and bulbs (CasinoView.items fills it)
var sk_msg := ""   # the skill tree's last answer from the server
var demo := true   # the main menu's yard: Delgado builds, the camera circles the stake, nobody plays
var over_t := 0.0   # the after-action screen comes up a moment after the end
var arm_sel := 0   # the armory and skill tree rows a key or controller has picked
var sk_sel := 0
var fps_label := ""
var v3: View3D = null   # the 3D view (scripts/view3d): the world drawn with the model library under the 2D HUD
var fps_n := 0
var fps_t := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	RenderingServer.set_default_clear_color(Color.html("#151a12"))
	ground = Node2D.new()
	ground.show_behind_parent = true
	add_child(ground)
	front_root = Node2D.new()
	add_child(front_root)
	light_rect = ColorRect.new()
	light_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light_rect.material = ShaderMaterial.new()
	light_rect.material.shader = load("res://shaders/light.gdshader")
	add_child(light_rect)
	fx_layer = PaintLayer.new()
	fx_layer.painter = _paint_fx
	add_child(fx_layer)
	glow_layer = PaintLayer.new()
	glow_layer.painter = _paint_glow
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = add
	add_child(glow_layer)
	post_rect = ColorRect.new()
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_rect.material = ShaderMaterial.new()
	post_rect.material.shader = load("res://shaders/post.gdshader")
	add_child(post_rect)
	ui_layer = PaintLayer.new()
	ui_layer.painter = _paint_ui
	add_child(ui_layer)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 210 / 255.0, 130 / 255.0, 0.55))
	gr.set_color(1, Color(1, 150 / 255.0, 60 / 255.0, 0))
	glow_tex = GradientTexture2D.new()
	glow_tex.gradient = gr
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	glow_tex.width = 64
	glow_tex.height = 64
	profile.load_file()
	locker = PalLocker.new(profile)
	locker.load_file()
	settings.load_file()
	settings.apply_keys()
	for a in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_cancel", "ui_select", "ui_focus_next", "ui_focus_prev"]:
		for ev in InputMap.action_get_events(a):   # the controller drives the menus through PalInput (with hold-to-repeat)
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				InputMap.action_erase_event(a, ev)
	inp = PalInput.new()
	inp.m = self
	add_child(inp)
	menus = Menus.new(self)
	add_child(menus)
	_demo_game()
	audio.sim = sim
	audio.main = self
	add_child(audio)
	_resize()
	v.cam_snap(sim.player.x, sim.player.y, sim.height_at(sim.player.x, sim.player.y))
	get_viewport().size_changed.connect(_resize)
	apply_settings()
	setup_3d()
	account = PalAccount.new(self)
	add_child(account)
	locker.account = account
	account.changed.connect(func(): menus.on_account_changed())
	account.claim_done.connect(_on_claim_done)
	net = PalNet.new()
	net.sim = sim
	net.main_ref = self
	add_child(net)
	net.started.connect(_net_started)
	net.left.connect(_net_left)
	net.lobby_changed.connect(_net_lobby)
	net.status.connect(func(t: String): menus.online_status(t))
	net.chat_line.connect(func(_l): if menus.screen == "lobby": menus.show_lobby())
	net.skills_check.connect(_check_guest_skills)
	social = PalSocial.new(self)
	add_child(social)
	if ResourceLoader.exists("res://scripts/casino_ui.gd"):
		casino_ui = load("res://scripts/casino_ui.gd").new(self)
		add_child(casino_ui)
		casino_ui.stood_up.connect(func(): sim.player.seat = 0)
		casino_ui.shards_changed.connect(func(n: int):
			if locker != null:
				locker.shards = n)
	net.room_closed.connect(func(inc: String): social.unpublish(inc))
	social.changed.connect(func():
		if menus.screen == "friends":
			menus.show_friends()
		elif menus.screen == "main":
			menus.refresh_friends_badge())
	menus.show_main()
	await account.boot()
	var R := locker.recover_draft()   # a run cut short last time pays now
	if R.has("text"):
		toasts = [{"title": "RUN SAVED", "body": "Your last run ended early. " + R.text, "t": 8.0}]


# ---------------------------------------------------------------- the casino

## ENTER THE CASINO alone (online, the room's host picks the casino in the lobby)
func start_casino() -> void:
	next_opt = {"map": "casino", "size": "std", "mode": "casino", "diff": "normal", "mods": []}
	next_cls = settings.data.setup.cls
	demo = false
	menus.close()
	skills_open = false
	_restart()
	over_t = 0.0
	sim.game.casRoom = "SOLO:%s:%s" % [str(account.uid() if account != null and account.uid() != null else "x").substr(0, 8), PalLocker._b36(int(Time.get_unix_time_from_system() * 1000))]


## the casino room id the server keys the tables by (casRoom)
func cas_room() -> String:
	if net.mode == "host" and net.code != "" and net.incarnation != "":
		return "R:%s:%s" % [net.code, net.incarnation]
	if net.mode == "guest" and net.cas_room != "":
		return net.cas_room
	if not sim.game.has("casRoom"):
		sim.game.casRoom = "SOLO:%s:%s" % [str(account.uid() if account != null and account.uid() != null else "x").substr(0, 8), PalLocker._b36(int(Time.get_unix_time_from_system() * 1000))]
	return sim.game.casRoom


## E next to a free seat: snap onto it, face the table, open its sheet; seated: open the sheet again
func cas_sit() -> void:
	var p: Dictionary = sim.player
	if not p.alive:
		return
	if p.get("seat", 0):
		if casino_ui != null and not casino_ui.is_open():
			casino_ui.open(p.seat, cas_room())
		return
	var sn := CasinoView.seat_near(sim, p, casino_ui)
	if sn.is_empty():
		return
	p.x = sn.pos[0]
	p.y = sn.pos[1]
	p.seat = sn.code
	var to: Array = sn.t.c if sn.has("t") else sn.m.at
	p.aim = Vector2(to[0] - p.x, to[1] - p.y).normalized()
	p.face = p.aim
	if casino_ui != null:
		casino_ui.open(sn.code, cas_room())
	else:
		toasts = [{"title": "TABLES", "body": "The tables aren't in this build yet.", "t": 3.0}]


## casStand: off the seat, and the server gives the seat (and the shards on it) back
func cas_stand() -> void:
	sim.player.seat = 0
	if casino_ui != null:
		casino_ui.stand()


# ---------------------------------------------------------------- online play

## what this screen tells a room about itself: name, class, outfit, skill tree, account id
func net_me() -> Dictionary:
	var nm: String = account.name_ if account != null and account.state == "full" and account.name_ != "" else str(settings.data.get("name", ""))
	if nm.strip_edges() == "":
		nm = "Big U"
	return {"name": nm.substr(0, 12), "cls": settings.data.setup.cls, "cos": PalLocker.cos_str(locker.eq) if locker != null else "std|class|std|none",
		"sk": profile.skill_str_mine(), "uid": str(locker.cloud.get("id", "")) if locker != null and not locker.cloud.is_empty() else ""}


func net_host() -> void:
	net.me = net_me()
	var S: Dictionary = settings.data.setup
	net.pick = {"diff": S.diff, "mode": S.mode, "pvp": S.get("pvp", "coop"), "map": S.map, "size": S.size, "mods": S.mods.duplicate(), "job": S.get("job", "")}
	social.list_game = settings.data.get("listGame", true)
	net.host_room()


func net_join(code: String) -> void:
	net.me = net_me()
	net.relay_opts = {"token_fn": _relay_token, "uid_fn": func(): return account.uid() if account != null else ""}
	net.join_room(code)


## the relay checks the account's token on hello and on every heartbeat
func _relay_token() -> String:
	if account == null or account.s.is_empty() or not await account.fresh_token():
		return ""
	return str(account.s.get("access_token", ""))


## the host's START: everyone's ready, the settings are the room's
func net_start() -> void:
	var why := net.start_block()
	if why != "":
		menus.online_status(why)
		return
	var pv: String = net.pick.pvp if net.pick.pvp in ["base", "ffa"] else ""
	demo = false
	menus.close()
	skills_open = false
	city_map = null
	game_n += 1
	sim.new_game(-1, net.pick.diff, profile.perk_mods(pv != ""), net.start_opt(pv))
	net.host_started()
	_after_start()


func _net_started() -> void:   # a guest's match began
	demo = false
	menus.close()
	skills_open = false
	city_map = null
	game_n += 1
	_after_start()


func _after_start() -> void:
	run_sp = -1
	last_reward = {}
	parts.clear()
	cparts.clear()
	flashes.clear()
	rings.clear()
	zaps.clear()
	slashes.clear()
	feed.clear()
	armory_open = false
	floats.clear()
	toasts.clear()
	over_t = 0.0
	v.cam_snap(sim.player.x, sim.player.y)


func _net_left(msg: String) -> void:
	_demo_game()
	menus.show_online(msg)


func _net_lobby() -> void:
	if net.mode == "guest" and not net.in_game and not demo and sim.game.phase == "over":
		_demo_game()   # the host went back to the lobby
	if demo and (net.mode == "host" or net.mode == "guest") and menus.screen in ["online", "lobby", "results", ""]:
		menus.show_lobby()


func net_back_to_lobby() -> void:
	if net.mode == "host":
		net.host_back_to_lobby()
	_demo_game()
	menus.show_lobby()


func net_leave() -> void:
	net.leave()


## the host checks a guest's claimed skill tree against their account (skills_of): only what they really own counts
func _check_guest_skills(pid: String, uid: String, claimed: String) -> void:
	if uid == "" or claimed == "" or account == null or account.s.is_empty():
		return
	var want := PalProfile.parse_skills(claimed)
	var r: Dictionary = await account.rpc_call("skills_of", {"p_uid": uid})
	if not r.ok or not (r.get("j") is Dictionary):
		return
	var t := {}
	for S in PalProfile.SKILLS:
		t[S.id] = mini(int(want.get(S.id, 0)), int(r.j.get(S.id, 0)))
	net.set_guest_skills(pid, PalProfile.skill_str(PalProfile.parse_skills(PalProfile.skill_str(t)), want.get("molOff", false)))


## the skill tree: an account's goes through the server (skill_buy, skill_respec), a local one changes here
func skill_buy(id: String) -> void:
	if not profile.cloud:
		audio.play("restock" if profile.buy(id) else "deny")
		return
	if profile.block_reason(id) != "":
		audio.play("deny")
		return
	var r := await account.rpc_call("skill_buy", {"p_node": id})
	if r.ok:
		account.take_locker(r.j)
		audio.play("restock")
	else:
		audio.play("deny")
		sk_msg = PalAccount.err_text(r) if r.status else "Buying a skill needs a connection."


func skill_respec() -> void:
	if not profile.cloud:
		profile.respec()
		audio.play("restock")
		return
	var r := await account.rpc_call("skill_respec")
	if r.ok:
		account.take_locker(r.j)
		audio.play("restock")
		sk_msg = "Your points are back. Spend them again."
	else:
		audio.play("deny")
		sk_msg = PalAccount.err_text(r) if r.status else "Resetting needs a connection."


## a queued run reached the account: its rewards replace "sending…" on the after-action screen, or show as a toast
func _on_claim_done(_c: Dictionary, R, big: String) -> void:
	if R is Dictionary and last_reward.get("pending") and last_reward.get("claim_at") == R.get("claim_at"):
		last_reward = R
		if menus.screen == "results":
			menus.show_results()
		return
	if last_reward.get("pending") and not (R is Dictionary) and menus.screen == "results":
		last_reward = {"kind": "run", "cases": {}, "shards": 0, "sp": 0, "unlocked": [], "text": R}
		menus.show_results()
		return
	toasts = [{"title": big, "body": R.text if R is Dictionary else R, "t": 4.5 * settings.data.msgTime}]


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and account != null:
		account.resume()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not demo and locker != null:
		locker.save_draft(sim)
		# alone, the game waits for you (online it can't: the crew keeps playing)
		if net.mode == "solo" and sim.game.phase != "over" and not sim.game.paused and not menus.active() and not armory_open and not skills_open:
			do_action("pause")
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not demo and locker != null:
		leave_run()


func _exit_tree() -> void:
	sim.dispose()


func _resize() -> void:
	var s := get_viewport_rect().size
	v.resize(s.x, s.y)
	for r in [light_rect, post_rect]:
		if r != null:
			r.position = Vector2.ZERO
			r.size = s


# ---------------------------------------------------------------- input

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and menus.bind_key(e):
		return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ENTER and net.is_online() and net.in_game and not menus.active() and not demo:
		_open_chat()
		get_viewport().set_input_as_handled()
		return
	if inp.handle(e):
		return
	if e is InputEventMouseMotion:
		mouse_seen = true
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		mouse_seen = true
		mouse_pulls = (mouse_pulls + 1) & 255
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT and not armory_open and not skills_open:
		do_action("roll")   # the right button rolls
	if e is InputEventMouseButton and e.pressed and not demo and DisplayServer.get_name() != "headless":
		if e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN:   # the wheel zooms, as on desktop in the browser
			settings.data.zoom = clampf(snappedf(settings.data.zoom + (0.05 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -0.05), 0.05), 0.7, 1.4)
			apply_settings()
			settings.save()
	if armory_open:
		_armory_input(e)
		return
	if skills_open:
		_skills_input(e)
		return
	if menus.active():
		if e.is_action_pressed("ui_cancel") or (e is InputEventKey and e.pressed and e.keycode == KEY_P and menus.screen == "pause"):
			menus.back()
			get_viewport().set_input_as_handled()
		return
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if e.keycode == KEY_F9:   # graphics: the 3D models on or off (Settings data "models3d"; the settings page can show it)
		settings.data.models3d = not bool(settings.data.get("models3d", true))
		settings.save()
		setup_3d()
		return
	if e.keycode == KEY_F8 and OS.is_debug_build():   # developer: bring in the next boss (any boss, any map), editor runs only
		_dev_boss()
		return
	for a in PalSettings.ACTIONS:
		if a[0] in ["up", "down", "left", "right"]:
			continue
		if e.is_action_pressed("pal_" + a[0]):
			do_action(a[0])
			return


## every in-game action, from a key, a controller button or a touch button
func do_action(id: String) -> void:
	if id == "pause" and casino_ui != null and casino_ui.is_open():   # Esc at a table: close the sheet and stand up
		cas_stand()
		return
	if sim.casino() and not demo and id in ["build", "nade", "special", "reload", "delgado", "start", "piece", "mat1", "mat2", "mat3", "matPrev", "matNext"]:
		return   # no weapons and no building in the casino
	if id == "pause":
		if armory_open:
			_close_armory()
		elif skills_open:
			_close_skills()
		elif demo or sim.game.phase == "over":
			return
		elif menus.screen == "pause":
			menus.close()
			sim.game.paused = false
		elif not menus.active():
			sim.game.paused = not net.is_online()   # online the match keeps running
			menus.show_pause()
		else:
			menus.back()
		return
	if id == "skills" and (menus.screen in ["main", "pause", "results"]):
		open_skills()
		return
	if demo or menus.active() or sim.game.phase == "over" or sim.game.paused:
		if id == "armory" and armory_open:
			_close_armory()
		return
	var p: Dictionary = sim.player
	if id == "roll":   # the back roll: this screen moves its own soldier; a guest tells the host, which keeps the cooldown
		if sim.local_roll() and net.guest():
			net.send_roll(p.dgX, p.dgY)
		return
	if sim.rolling(p) and id in ["build", "nade", "special", "sprint"]:
		return   # no building, throwing or sprinting mid-roll
	if net.guest():   # a guest's actions go to the host, which runs them through the same rules
		match id:
			"build":
				if p.alive and settings.data.get("build", true) and sim.pvp() != "ffa":
					var t := sim.build_target(p, sim.game.sel, sim.game.piece == "door")
					if t.ok:
						net.send_build(t.i, t.j, sim.game.sel, sim.game.piece == "door")
					else:
						audio.play("deny")
				return
			"nade", "special":
				var w := _throw_target(id == "special" and p.cls == "soldier")
				if id == "special" and p.cls in ["soldier", "sniper"]:
					if (p.cls == "soldier" and p.ab <= 0) or (p.cls == "sniper" and p.ab != 0) or sim.pvp() != "":
						audio.play("deny")
					else:
						net.send_ability(w.x, w.y)
				elif id == "special" and p.cls == "quartermaster":
					sim.local_sprint()
				elif p.nades <= 0:
					audio.play("deny")
				else:
					net.send_nade(w.x, w.y)
				return
			"reload":
				if p.alive and p.gun.has("mag") and p.ammo < p.gun.mag:
					net.send_reload()
				return
			"delgado":
				return
			"start":
				if sim.blackout() and sim.game.get("bo") != null and sim.game.bo.stage == "ready":
					net.send_bo_ready(not p.get("boReady", false))
				return
	match id:
		"build":
			sim.local_build()
		"mat1", "mat2", "mat3":
			sim.game.sel = int(id.substr(3)) - 1
		"matPrev":
			sim.game.sel = (sim.game.sel + 2) % 3
		"matNext":
			sim.game.sel = (sim.game.sel + 1) % 3
		"piece":
			sim.game.piece = "door" if sim.game.piece == "wall" else "wall"
		"nade", "special":
			var w := _throw_target(id == "special" and p.cls == "soldier")
			if id == "special" and p.cls in ["soldier", "sniper"]:   # the class ability where there is one
				sim.use_ability(p, w.x, w.y)
			elif id == "special" and p.cls == "quartermaster":
				sim.local_sprint()
			else:
				sim.throw_nade(p, w.x, w.y)
		"sprint":
			sim.local_sprint()
		"reload":
			sim.local_reload()
		"armory":
			if sim.casino():
				cas_sit()
			else:
				_try_armory()
		"delgado":
			sim.set_qm_mode("" if sim.qm.mode == "follow" else "follow")
		"start":
			if sim.blackout() and sim.game.phase == "raid":
				sim.bo_ready(not p.get("boReady", false))
			elif sim.game.phase == "build" and sim.pvp() == "":
				sim.start_raid()
			elif sim.pvp() == "base" and sim.game.phase == "build":
				sim.start_battle()
		"skills":
			pass


## where a grenade or rocket goes: the touch lock-on, the mouse, or 5 tiles ahead
func _throw_target(rocket: bool) -> Vector2:
	var p: Dictionary = sim.player
	if inp.mode == "touch":
		var L = _touch_lock(p, 12.0 if rocket else 8.0)
		if L != null:
			return Vector2(L.x, L.y)
	if inp.mode == "mouse" and mouse_seen:
		var m := get_viewport().get_mouse_position()
		return _screen_to_world(m.x, m.y + v.WH * 0.55)
	return Vector2(p.x + p.face.x * 5, p.y + p.face.y * 5)


## touchLock (09-actions.js): the nearest raider 6 tiles out or more, up to the throw's reach, in clear sight
func _touch_lock(p: Dictionary, mx: float):
	var best = null
	var bd := 1e9
	for e in sim.enemies:
		if e.dead or e.get("burrow", false):
			continue
		var d := sim.hdist(e.x, e.y, p.x, p.y)
		if d < 6 or d > mx or d >= bd:
			continue
		if sim.los_clear(p.x, p.y, e.x, e.y):
			best = e
			bd = d
	return best


## a controller in the menus: Godot's focus moves; A presses; B backs out
func menu_nav(dir: String) -> void:
	if skills_open or armory_open:
		_panel_nav(dir)
		return
	if not menus.active():
		return
	var act: String = {"up": "ui_up", "down": "ui_down", "left": "ui_left", "right": "ui_right", "accept": "ui_accept"}.get(dir, "")
	if dir == "back":
		menus.back()
		return
	if dir == "next" or dir == "prev":   # LB / RB: the next or previous page tab
		menus.page_step(1 if dir == "next" else -1)
		return
	if act == "":
		return
	var f := get_viewport().gui_get_focus_owner()
	if f == null:
		menus._focus_first()
		return
	if act == "ui_accept" and f is BaseButton:
		if f.toggle_mode:
			f.button_pressed = not f.button_pressed
		f.emit_signal("pressed")
		return
	var ev := InputEventAction.new()
	ev.action = act
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = act
	up.pressed = false
	Input.parse_input_event(up)


func start_game() -> void:
	leave_run()   # RESTART mid-run counts as leaving it
	var S: Dictionary = settings.data.setup
	next_opt = {"map": S.map, "size": S.size, "mode": S.mode, "diff": S.diff, "mods": S.mods.duplicate()}
	next_cls = S.cls
	demo = false
	menus.close()
	skills_open = false
	_restart()
	over_t = 0.0
	if settings.data.tips:
		toasts = [{"title": "GOOD LUCK", "body": "Gather wood (walk into a pile), %s to build, %s grenade, %s armory at the stake, %s to start the raid early." % [settings.keys_label("build"), settings.keys_label("nade"), settings.keys_label("armory"), settings.keys_label("start")], "t": 7.0 * settings.data.msgTime}]


## leaveRun: leaving a run still going pays what's held so far (an early leave); the casino stands you up
func leave_run() -> void:
	if demo:
		return
	if sim.casino():
		cas_stand()
		return
	if run_sp >= 0 or sim.game.phase == "over" or sim.pvp() != "" or not PalLocker.draft_due(sim):
		return
	run_sp = 0
	var R := locker.pay_run(sim, true)
	if locker.cloud.is_empty() and R.has("text"):
		toasts = [{"title": "RUN SAVED", "body": R.text, "t": 6.0}]


func to_menu() -> void:
	leave_run()
	if net.mode != "solo":
		net.leave()
		return
	_demo_game()
	menus.show_main()


## the menu's yard: a fresh Yard where Delgado builds his ring and nobody fights
func _demo_game() -> void:
	demo = true
	skills_open = false
	armory_open = false
	sim.new_game(-1, "normal", profile.perk_mods(), {"mode": "5", "map": "yard"})
	sim.set_qm_mode("")
	sim.player.x = -40.0
	sim.player.y = -40.0
	game_n += 1
	parts.clear()
	cparts.clear()
	floats.clear()
	toasts.clear()
	city_map = null
	v.cam_snap(sim.core.i + 2.5, sim.core.j - 2)


## the skill tree is a menu page (menu_pages.gd): from the menus, the pause menu or the after-action screen
func open_skills() -> void:
	skills_open = false
	menus.came_from = "main" if demo else ("results" if sim.game.phase == "over" else "pause")
	menus.show_skills()


func _close_skills() -> void:
	skills_open = false
	menus.back()


## the 3D view on or off (Settings: "models3d"; on by default when the model library is in this build), and its
## quality knobs (Settings: "gfx3d", see Quality3D). Off, or without the library, the 2D drawing is the world.
func setup_3d() -> void:
	Quality3D.load_from(settings.data.get("gfx3d", {}))
	var want: bool = bool(settings.data.get("models3d", true)) and View3D.available()
	if want and v3 == null:
		v3 = View3D.new(self)
		add_child(v3)
		ground_key = ""
	elif not want and v3 != null:
		v3.queue_free()
		v3 = null
		ground_key = ""
	if v3 != null:
		Quality3D.apply_viewport(get_viewport())
	ground.visible = v3 == null
	front_root.visible = v3 == null


func apply_settings() -> void:
	var D: Dictionary = settings.data
	if v3 != null or D.get("models3d", true) == false:
		setup_3d()
	PalSettings.reduce_motion = D.get("reduceMotion", false)
	audio.volume = D.volume
	audio.music_vol = D.music
	if absf(v.ZOOM - D.zoom) > 0.001:
		v.ZOOM = D.zoom
		_resize()
	Engine.max_fps = 30 if D.fpsMode == "30" else (60 if D.fpsMode == "60" else 0)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if D.vsync else DisplayServer.VSYNC_DISABLED)
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if D.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and (D.fullscreen or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_mode(want)


func _game_opt() -> Dictionary:
	var o := next_opt.duplicate()
	o.cls = next_cls
	return o


func _restart() -> void:
	city_map = null
	game_n += 1
	sim.new_game(-1, next_opt.diff, profile.perk_mods(), _game_opt())
	run_sp = -1
	last_reward = {}
	parts.clear()
	cparts.clear()
	flashes.clear()
	rings.clear()
	zaps.clear()
	slashes.clear()
	armory_open = false
	floats.clear()
	toasts.clear()
	v.cam_snap(sim.player.x, sim.player.y)


func _mouse_world() -> Vector2:
	var m := get_viewport().get_mouse_position()
	var body = _body_under(m.x, m.y)
	return body if body != null else _screen_to_world(m.x, m.y + v.WH * 0.55)


## this frame's controls (controlLocal): keys and the left stick or left thumb move; the mouse, the right stick or the
## right thumb aim (sticks get the browser's aim assist); the left button, right trigger or a hard right thumb fire
func _controls() -> Dictionary:
	if demo or menus.active() or armory_open or skills_open:
		return {}
	var mx := (1.0 if Input.is_action_pressed("pal_right") else 0.0) - (1.0 if Input.is_action_pressed("pal_left") else 0.0)
	var my := (1.0 if Input.is_action_pressed("pal_down") else 0.0) - (1.0 if Input.is_action_pressed("pal_up") else 0.0)
	var sm: Dictionary = inp.stick_move
	if sm.id >= 0:
		mx += sm.v.x
		my += sm.v.y
	if inp.mode == "pad":
		mx += inp.mv.x
		my += inp.mv.y
	var mag := minf(1.0, Vector2(mx, my).length())
	var mv := v.sdir_to_world(mx, my) * mag
	var aim := Vector2.ZERO
	var fire := false
	var p: Dictionary = sim.player
	var sa: Dictionary = inp.stick_aim
	if inp.mode == "pad":
		if inp.amag > 0.2:
			aim = _assist(v.sdir_to_world(inp.aim.x, inp.aim.y))
		fire = inp.fire
	elif inp.mode == "touch":
		if sa.id >= 0 and sa.mag > 0.2:
			aim = _assist(v.sdir_to_world(sa.v.x, sa.v.y))
			fire = sa.mag > 0.5
	elif mouse_seen:
		var w := _mouse_world()
		var d := Vector2(w.x - p.x, w.y - p.y)
		aim = d.normalized() if d.length() > 0 else Vector2(1, 0)
		fire = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	return {"move": mv, "aim": aim, "fire": fire, "pulls": mouse_pulls, "auto": inp.mode == "touch" or (inp.mode == "mouse" and not mouse_seen)}


## the camera follows you; once you're out (evacuated), it watches a teammate still in the fight
func _cam_target() -> Dictionary:
	var p: Dictionary = sim.player
	if not p.get("out", false):
		return p
	var best = null
	for o in sim.players.values():
		if not is_same(o, p) and not o.get("out", false) and (o.alive or o.downed):
			if best == null or (o.alive and not best.alive):
				best = o
	return best if best != null else p


## aim assist: a stick's aim snaps to the raider closest to it within about 18 degrees, in range and in sight
func _assist(d: Vector2) -> Vector2:
	var p: Dictionary = sim.player
	var best := d
	var ba := 0.32
	var a0 := d.angle()
	for e in sim.enemies:
		if e.dead:
			continue
		var dv := Vector2(e.x - p.x, e.y - p.y)
		if sim.hdist(p.x, p.y, e.x, e.y) > p.gun.range or not sim.height_ray_clear(p.x, p.y, e.x, e.y):
			continue
		var da := absf(angle_difference(a0, dv.angle()))
		if da < ba:
			ba = da
			best = dv.normalized()
	return best


# ---------------------------------------------------------------- frame

func _process(dt: float) -> void:
	inp.tick(dt, demo or menus.active() or armory_open or skills_open or sim.game.phase == "over")
	if demo:
		sim.game.timer = maxf(sim.game.timer, 30.0)   # the menu's yard never raids
		sim.player.hp = sim.player.max
	for pl in sim.players.values():
		_dress(pl)
	if net.guest():
		net.guest_frame(dt, _controls())
	else:
		sim.update(dt, _controls())
	if net.mode == "host":
		net.host_frame(dt)   # before the events drain: they go to the guests too
	elif net.mode == "guest" and not net.in_game:
		net.guest_frame(dt, {})
	if not demo and sim.game.wave != draft_wave:
		draft_wave = sim.game.wave
		locker.save_draft(sim)
	if not demo and sim.game.phase == "over":
		if run_sp < 0:
			if sim.pvp() == "" and not sim.casino() and net.mode == "solo":   # this PC's best runs (solo only, as in the browser)
				var g: Dictionary = sim.game
				PalSaves.save_best(sim, sim.bo_stages() if sim.blackout() else (int(g.waves) if g.won or g.end_reason in ["evac", "left"] else (g.wave if g.end_reason == "evacfail" else maxi(0, g.wave - 1))), int(g.stats.dropped))
			last_reward = locker.pay_pvp(sim) if sim.pvp() != "" else locker.pay_run(sim)
			run_sp = last_reward.get("sp", 0)
		if menus.screen == "pause":
			menus.close()
		over_t += dt
		if over_t > (0.6 if sim.game.won else 0.9) and not menus.active() and not skills_open:
			armory_open = false
			menus.show_results()
	fps_n += 1
	fps_t += dt
	if fps_t >= 1.0:
		fps_label = "%d FPS" % roundi(fps_n / fps_t)
		fps_n = 0
		fps_t = 0.0
	_drain_events()
	_update_fx(minf(dt, 0.05))
	var sh := Vector2.ZERO
	if shake > 0.1:
		shake_t += dt
		sh = Vector2(sin(shake_t * 71.0), cos(shake_t * 57.0)) * shake * v.u
		shake *= pow(0.02, dt)
	if demo:   # the menu: the camera drifts round the stake
		var t: float = sim.game.time * 0.07
		var fx: float = sim.core.i + 2.5 + cos(t) * 2.5
		var fy: float = sim.core.j - 2 + sin(t) * 2
		v.cam_follow(fx, fy, sh, 0.0)
	else:
		var fol: Dictionary = _cam_target()
		v.cam_follow(fol.x, fol.y, sh, sim.height_at(fol.x, fol.y))
	if v3 != null:
		v3.frame(dt)
	else:
		_sync_ground()
	_update_light(dt)
	_update_post(dt)
	fade_t -= dt
	if fade_t <= 0:
		fade_t = 0.1
		_update_fades()
	queue_redraw()
	fx_layer.queue_redraw()
	glow_layer.queue_redraw()
	ui_layer.queue_redraw()
	var want := Input.MOUSE_MODE_HIDDEN if not demo and not menus.active() and inp.mode == "mouse" and sim.game.phase != "over" and not sim.game.paused and not armory_open and not skills_open and sim.player.alive else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want and DisplayServer.get_name() != "headless":
		Input.mouse_mode = want


func _drain_events() -> void:
	if v3 != null:
		v3.events(sim.events)
	for e in sim.events:
		match e.k:
			"sfx":
				audio.play(e.name, e.x, e.y)
			"emit":
				for n in e.n:
					_emit(e.x, e.y, e.kind, e.mat)
			"flt":
				floats.append({"x": e.x, "y": e.y, "text": e.text, "col": Color.html(e.col), "t": 1.4})
			"toast":
				if not demo:
					toasts = [{"title": e.title, "body": e.body, "t": 4.5 * settings.data.msgTime}]
			"killfx":
				kill_fx(e.x, e.y, e.fx, e.get("quiet", false))
			"flash":
				flashes.append({"x": e.x, "y": e.y, "life": e.life, "max": e.life, "r": e.r, "muzzle": e.get("muzzle", false)})
			"ring":
				rings.append({"x": e.x, "y": e.y, "r0": e.r0, "r1": e.r1, "life": e.life, "max": e.life, "c1": e.c1, "w": 2.0})
			"zap":
				zaps.append({"pts": e.pts, "life": 0.38, "max": 0.38})
			"slash":
				slashes.append({"x": e.x, "y": e.y, "ax": e.ax, "ay": e.ay, "life": 0.28, "max": 0.28})
			"map":   # a campaign chapter moved everyone to the next map
				game_n += 1
				parts.clear()
				cparts.clear()
				rings.clear()
				v.cam_snap(sim.player.x, sim.player.y, sim.height_at(sim.player.x, sim.player.y))
			"personal":   # a sound (or, for ~names, a feel) only this soldier's screen gets
				if e.id == sim.player.id:
					if e.name == "hurt":
						inp.rumble(80)
					if not e.name.begins_with("~"):
						audio.play(e.name)
			"toast_to":
				if e.id == sim.player.id:
					toasts = [{"title": e.title, "body": e.body, "t": 4.5 * settings.data.msgTime}]
			"feed":
				feed.push_front({"text": e.text, "col": e.col, "t": 5.7})
				if feed.size() > 4:
					feed.pop_back()
			"shake":
				var d := Vector2(e.x - sim.player.x, e.y - sim.player.y).length()
				shake = maxf(shake, e.amt * clampf(1.0 - d / 14.0, 0.2, 1.0) * settings.data.shake)
				if d < 8:
					inp.rumble(e.amt * 6)
	sim.events.clear()


const PCOL := {"blood": ["#8a1c14", "#b0281c"], "dust": ["#8a7a62", "#a69276"], "splinter": ["#b8894f", "#8b6236"], "spark": ["#ffd27a", "#fff2c4"],
	"chunk": ["#6b4a28", "#4f361d"], "fire": ["#ff9a3a", "#ffd27a"], "smoke": ["#3a3530", "#4a443c"], "tealdust": ["#3ae0e0", "#bff4ff"]}


func _emit(x: float, y: float, kind: String, mat: int) -> void:
	if parts.size() >= PART_CAP:
		return
	var cols: Array = PCOL.get(kind, PCOL.dust)
	if kind == "chunk" or kind == "dust":
		cols = [Pal.MAT[mat].top, Pal.MAT[mat].l]
	var a := randf() * TAU
	var sp := randf_range(0.5, 2.2) * (2.0 if kind == "spark" or kind == "fire" else 1.0)
	var life := randf_range(0.3, 0.8) * (2.0 if kind == "smoke" else 1.0)
	parts.append({"x": x, "y": y, "vx": cos(a) * sp, "vy": sin(a) * sp, "z": 10.0, "vz": randf_range(20, 70) * (-0.3 if kind == "smoke" else 1.0),
		"life": life, "max": life, "col": Color.html(cols[randi() % cols.size()]), "kind": kind, "s": 1.6 if kind == "chunk" else 1.0})


var chat_box: LineEdit


## online text chat in a match: Enter opens the line, Enter sends it, Esc closes it
func _open_chat() -> void:
	if chat_box == null:
		chat_box = LineEdit.new()
		chat_box.max_length = 120
		chat_box.placeholder_text = "Say something to the room"
		var layer := CanvasLayer.new()
		layer.layer = 5
		add_child(layer)
		layer.add_child(chat_box)
		chat_box.text_submitted.connect(func(t: String):
			if t.strip_edges() != "":
				net.send_chat(t)
			chat_box.text = ""
			chat_box.visible = false
			chat_box.release_focus())
		chat_box.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
				chat_box.visible = false
				chat_box.release_focus()
				chat_box.accept_event())
	chat_box.position = Vector2(14, v.H - 130)
	chat_box.size = Vector2(minf(420, v.W - 28), 30)
	chat_box.visible = true
	chat_box.grab_focus()


func _update_fx(dt: float) -> void:
	for f in feed:
		f.t -= dt
	feed = feed.filter(func(f): return f.t > 0)
	for q in parts:
		q.life -= dt
		q.x += q.vx * dt
		q.y += q.vy * dt
		q.z += q.vz * dt
		if q.kind == "smoke":
			q.vz = -15.0
		else:
			q.vz -= 160.0 * dt
		if q.z < 0:
			q.z = 0.0
			q.vx *= 0.5
			q.vy *= 0.5
			q.vz = 0.0
	parts = parts.filter(func(q): return q.life > 0)
	for q in cparts:   # the cosmetic particles move as the browser's do: z in base units over the ground
		q.life -= dt
		q.x += q.vx * dt * 0.6
		q.y += q.vy * dt * 0.6
		q.vz -= q.grav * dt
		q.z += q.vz * dt
		if q.get("floor", -1.0) >= 0 and q.z < q.floor:   # the spider stops at the end of its thread
			q.z = q.floor
			q.vz = 0.0
		if q.z < 0:
			q.z = 0.0
			q.vz *= -0.3
			q.vx *= 0.5
			q.vy *= 0.5
	cparts = cparts.filter(func(q): return q.life > 0)
	for z in zaps:
		z.life -= dt
	zaps = zaps.filter(func(z): return z.life > 0)
	for sl in slashes:
		sl.life -= dt
	slashes = slashes.filter(func(sl): return sl.life > 0)
	for r in rings:
		r.life -= dt
	rings = rings.filter(func(r): return r.life > 0)
	for f in flashes:
		f.life -= dt
	flashes = flashes.filter(func(f): return f.life > 0)
	for f in floats:
		f.t -= dt
	floats = floats.filter(func(f): return f.t > 0)
	for t in toasts:
		t.t -= dt
	toasts = toasts.filter(func(t): return t.t > 0)


# ---------------------------------------------------------------- drawing helpers (15-render.js)

## a world point on screen, at the ground's height there (Frostpeak's terraces; flat elsewhere)
func iso(x: float, y: float) -> Vector2:
	return v.iso(x, y, sim.height_at(x, y))


func c(h: String) -> Color:
	var col := Color.html(h)
	col.a *= draw_alpha
	return col


func quad(a: Vector2, b: Vector2, cc: Vector2, d: Vector2, fill: Color) -> void:
	cv.draw_colored_polygon(PackedVector2Array([a, b, cc, d]), fill)


func up(p: Vector2, h: float) -> Vector2:
	return Vector2(p.x, p.y - h)


## boxR: an iso box from (x0,y0) to (x1,y1) on the ground, z pixels up, h pixels tall. Returns its base corners.
func box_r(x0: float, y0: float, x1: float, y1: float, z: float, h: float, top: Color, l: Color, r: Color) -> Dictionary:
	var hz := sim.height_at((x0 + x1) / 2, (y0 + y1) / 2)   # boxR: the whole box stands at its centre's height
	var A := v.iso(x0, y0, hz)
	var B := v.iso(x1, y0, hz)
	var C := v.iso(x1, y1, hz)
	var D := v.iso(x0, y1, hz)
	quad(up(D, z), up(C, z), up(C, z + h), up(D, z + h), l)
	quad(up(C, z), up(B, z), up(B, z + h), up(C, z + h), r)
	quad(up(A, z + h), up(B, z + h), up(C, z + h), up(D, z + h), top)
	return {"A": A, "B": B, "C": C, "D": D}


func oval(cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	cv.draw_set_transform(Vector2(cx, cy), 0, Vector2(1, ry / rx))
	cv.draw_circle(Vector2.ZERO, rx, col)
	cv.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func label(text: String, x: float, y: float, col: Color, size: int = 11) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	cv.draw_string(font, Vector2(x - w / 2 + 1, y + 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.7))
	cv.draw_string(font, Vector2(x - w / 2, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func mixc(a: String, b: String, t: float) -> Color:
	return c(a).lerp(c(b), t)


# ---------------------------------------------------------------- the scene

func _draw() -> void:
	var t_draw := Time.get_ticks_usec()
	if v3 != null and v3.visible:
		v3.paint_labels()   # the world is the 3D view's; its labels and the cosmetic particles draw here
		_draw_cparts()
	else:
		_draw_scene()
	draw_us = Time.get_ticks_usec() - t_draw


func _draw_scene() -> void:
	var N: int = sim.N
	var u := v.u
	var WH := v.WH
	_vis_bounds()
	_draw_terrain_live()
	# debris lies flat under everything
	for j in range(vb[2], vb[3] + 1):
		for i in range(vb[0], vb[1] + 1):
			var k := j * N + i
			if sim.debris[k] != 0 and sim.walls[k] == null:
				_draw_debris(i, j, sim.debris[k] - 1)
	for fr in sim.frost_fields:
		var qc := iso(fr.x, fr.y)
		oval(qc.x, qc.y, fr.r * v.TW2, fr.r * v.TH2, Color(0.7, 0.95, 1.0, 0.3 * clampf(fr.t / 2.0, 0, 1)))
	# burning ground from a firebrand's bottle (napalm, gas and mines live here too)
	for f in sim.fires:
		var fc := iso(f.x, f.y)
		if f.get("nap", 0) == 2:
			var ga := minf(1.0, f.t) * 0.32
			for n in 5:
				var ox := sin(sim.game.time * 0.7 + n * 1.7) * v.TW2 * 0.5
				var oy := cos(sim.game.time * 0.6 + n * 2.1) * v.TH2 * 0.5
				oval(fc.x + ox, fc.y + oy - n * 2 * v.u, v.TW2 * f.r * (0.55 + 0.1 * n), v.TH2 * f.r * (0.55 + 0.1 * n), Color(120 / 255.0, 200 / 255.0, 70 / 255.0, ga * (0.5 + 0.1 * n)))
			continue
		if f.get("nap", 0) == 3:
			var armed: bool = f.get("arm", 0.0) <= 0
			var blink := sin(sim.game.time * (14.0 if armed else 5.0) + f.x * 7) > 0
			oval(fc.x, fc.y, 5 * v.u, 2.6 * v.u, c("#1a1b1c"))
			oval(fc.x, fc.y - 1.5 * v.u, 4 * v.u, 2 * v.u, c("#3a3c3e"))
			oval(fc.x, fc.y - 2.4 * v.u, 1.6 * v.u, 1 * v.u, (c("#ff3a2a") if armed else c("#ffb03a")) if blink else c("#5a2a1a"))
			continue
		var a: float = clampf(f.t / 1.0, 0, 1)
		var flick := 0.9 + 0.1 * sin(sim.game.time * 17.0 + f.x * 3.0)
		oval(fc.x, fc.y, f.r * v.TW2 * flick, f.r * v.TH2 * flick, Color(1, 0.45, 0.12, 0.35 * a))
		oval(fc.x, fc.y, f.r * v.TW2 * 0.55, f.r * v.TH2 * 0.55, Color(1, 0.75, 0.3, 0.45 * a))
	for r in rings:
		var rc := iso(r.x, r.y)
		var t: float = 1.0 - r.life / r.max
		var rr: float = lerpf(r.r0, r.r1, t)
		cv.draw_set_transform(rc, 0, Vector2(1, v.TH2 / v.TW2))
		var rcol: Color = c(r.c1).lerp(c(r.c2), t) if r.has("c2") else c(r.c1)
		cv.draw_arc(Vector2.ZERO, rr * v.TW2, 0, TAU, 48, Color(rcol, 1.0 - t), r.w * u)
		cv.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# the build ghost
	_draw_ghost()
	# depth-sorted items: walls/nodes/stake key i+j+1, people x+y
	var items: Array = []
	var city: bool = sim.map_id == "city"
	for j in range(vb[2], vb[3] + 1):
		for i in range(vb[0], vb[1] + 1):
			var k := j * N + i
			if sim.walls[k] != null:
				items.append([i + j + 1.0, 0, k])
			var t: int = sim.terr[k]
			if t == PalMaps.T_ROCK or t == PalMaps.T_DRUM:
				items.append([i + j + 1.0, 8, k])

			if sim.is_frost() and sim.heights[k] > 0 and sim.connectors[k] == 0:
				if (j + 1 < N and sim.heights[k] > sim.heights[k + N] + (1 if sim.connectors[k + N] != 0 else 0)) or (i + 1 < N and sim.heights[k] > sim.heights[k + 1]):
					items.append([i + j + 2.0, 9, k])
	for n in sim.nodes:
		if _tile_on(n.i, n.j):
			items.append([n.i + n.j + 1.0, 1, n])
	if sim.pvp() == "base":
		for co in sim.cores:
			items.append([co.i + co.j + 1.0, 2, co])
	elif sim.casino():
		for q in CasinoView.items(self):
			items.append([q[0], 20, q[1]])
	elif sim.pvp() == "":
		items.append([sim.core.i + sim.core.j + 1.0, 2, null])
	if city:
		for k in _city_occluders():
			items.append([k % N + k / N + 1.0, 10, k])
		for co in sim.cores:
			if co.has("poi") and _tile_on(co.i, co.j, 3):
				items.append([co.i + co.j + 1.0, 11, co])
		for l in sim.lay.lamps:
			if _tile_on(l[0], l[1]):
				items.append([l[0] + l[1] + 1.0, 12, l])
	for e in sim.enemies:
		items.append([e.x + e.y, 3, e])
	items.append([sim.qm.x + sim.qm.y, 4, sim.qm])
	for pl in sim.players.values():
		if not pl.get("out", false):
			items.append([pl.x + pl.y, 5, pl])
	for s in sim.sacks:
		items.append([s.x + s.y, 6, s])
	for ch in sim.charges:
		items.append([ch.x + ch.y, 7, ch])
	items.sort_custom(func(a, b): return a[0] < b[0])
	for it in items:
		match it[1]:
			0:
				var wi: int = it[2] % N
				var wj: int = it[2] / N
				var dd: float = wi + wj + 1 - (sim.player.x + sim.player.y)
				var lat: float = (wi - wj) - (sim.player.x - sim.player.y)
				if dd > 0 and dd < 3.2 and absf(lat) < 1.7:   # a wall in front of you goes see-through
					draw_alpha = 0.3
				_draw_wall(wi, wj, sim.walls[it[2]])
				draw_alpha = 1.0
			1:
				_draw_node(it[2])
			2:
				_draw_stake(it[2])
			3:
				var e: Dictionary = it[2]
				var o: Dictionary = (Sim.boss_def(e.boss).look if e.type == "boss" else LOOK.get(e.type, LOOK.rifle)).duplicate()
				o.merge({"aim": e.aim, "walk": e.walk, "flash": e.flash > 0, "hp": e.hp / e.max}, true)
				if e.type == "boss":
					var B: Dictionary = Sim.boss_def(e.boss)
					if e.get("burrow", false) or (e.boss == "foreman" and (e.st == 2 or e.st == 4)):
						_draw_mound(e)
						continue
					if e.get("raft", false):
						_draw_raft(e)
						o.walk = 0.0
					o.big = B.get("big", 1.45)
					o.tag = B.name
					o.tag_col = B.col
					var kb: String = B.get("base", e.boss)
					o.swing = (e.st if e.st < 5 else 0) if kb == "butcher" else (1 if e.boss == "bluebutcher" and e.st == 5 else 0)
				if e.type == "breach":
					o.satchel = not e.planted
				if e.type == "shield":
					o.shield_wear = 1.0 - float(e.shieldHitsLeft) / e.shieldHitsMax
					if e.shieldBroken:
						o.weapon = "pistol"
				Figure.person(self, e.x, e.y, o)
				_draw_ammo_status(e)
				if e.type == "medic" and sim.game.phase == "raid":   # his healing reach
					var mc := iso(e.x, e.y)
					cv.draw_set_transform(mc, 0, Vector2(1, v.TH2 / v.TW2))
					cv.draw_arc(Vector2.ZERO, v.TW2 * 2.6, 0, TAU, 48, c("#8fe0a059"), 1.2 * v.u)
					cv.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
				if e.type == "boss" and e.boss == "bulldozer" and e.st == 6:   # dazed
					var sc := iso(e.x, e.y)
					for n in 3:
						var a: float = sim.game.time * 4.0 + n * TAU / 3
						cv.draw_circle(Vector2(sc.x + cos(a) * 10 * v.u, sc.y - v.WH * 2.3 + sin(a) * 4 * v.u), 2.2 * v.u, c("#ffd23a"))
			4:
				var q: Dictionary = it[2]
				if q.alive:
					var o: Dictionary = QM_LOOK.duplicate()
					o.merge({"aim": q.aim, "walk": q.walk, "flash": q.flash > 0}, true)
					Figure.person(self, q.x, q.y, o)
				elif not q.get("gone", false):
					Figure.downed(self, q.x, q.y, QM_LOOK, q.revive / 2.0, "DELGADO · DOWN")
			5:
				var p: Dictionary = it[2]
				var o: Dictionary = player_look(p)
				if p.alive:
					o.merge({"aim": p.aim, "flash": p.flash > 0, "faded": p.stl > 0}, true)
					o.merge(_motion(p), true)
					if p.bolt > 0:
						o.bolt = 1.0 - p.bolt / p.boltT
					if sim.casino():
						o.nogun = true
					if p.get("seat", 0):
						CasinoView.seated(self, p.x, p.y, func(): draw_wardrobe(p.x, p.y, o))
					elif sim.rolling(p):   # the back roll: tucked, head over heels, away from the aim
						var sc := iso(p.x, p.y)
						var cy: float = sc.y - 17 * v.u * Figure.FIG / 2.2
						var a: float = Sim.roll_pos(p.dgE) * TAU * (-1.0 if v.world_dir_to_screen(p.aim).x >= 0 else 1.0)
						cv.draw_set_transform_matrix(Transform2D(0, Vector2(sc.x, cy)) * Transform2D(a, Vector2(1, 0.86), 0, Vector2.ZERO) * Transform2D(0, Vector2(-sc.x, -cy)))
						draw_wardrobe(p.x, p.y, o)
						cv.draw_set_transform_matrix(Transform2D.IDENTITY)
					else:
						draw_wardrobe(p.x, p.y, o)
				elif p.downed:
					var tag := "DOWN · UNTIL THE RAID IS BROKEN" if p.rt > 1e5 else "DOWN · %d" % ceili(p.rt)
					var sc := iso(p.x, p.y)
					o.merge({"downed": true, "nogun": true}, true)
					Wardrobe.draw(cv, o, 0.7, sim.game.time, v.u * Figure.FIG, sc.x, sc.y, 0, draw_alpha)
					label(tag, sc.x, sc.y - 20 * v.u, c("#d65a3a"), 10)
					if p.revive > 0:
						cv.draw_arc(Vector2(sc.x, sc.y - 10 * v.u), 10 * v.u, -PI / 2, -PI / 2 + TAU * clampf(p.revive / 2.2, 0, 1), 32, c("#a9bccb"), 3 * v.u)
			6:
				var s: Dictionary = it[2]
				var sc := iso(s.x, s.y)
				oval(sc.x, sc.y, 6 * u, 3 * u, Color(0, 0, 0, 0.35))
				oval(sc.x, sc.y - 4 * u, 5 * u, 5 * u, c("#cbbf9f"))
			8:
				_draw_terr_item(it[2] % N, it[2] / N, sim.terr[it[2]])
			20:
				it[2].call()
			9:
				_draw_frost_cliff(it[2])
			10:
				CityView.building(self, it[2] % N, it[2] / N, false)
			11:
				CityView.poi(self, it[2])
			12:
				CityView.lamp(self, it[2])
			7:
				var ch: Dictionary = it[2]
				var cs := iso(ch.x, ch.y)
				cv.draw_rect(Rect2(cs.x - 5 * u, cs.y - 5 * u, 10 * u, 6 * u), c("#1a1510"))
				if sin(sim.game.time * (20.0 - ch.fuse * 5.0)) > 0:
					cv.draw_circle(Vector2(cs.x, cs.y - 6 * u), 2 * u, c("#ff5a3a"))
	for r in sim.rockets:
		var rp := iso(r.x, r.y)
		var dir := v.world_dir_to_screen(Vector2(r.vx, r.vy))
		var hpx := v.WH * 0.6
		cv.draw_line(Vector2(rp.x, rp.y - hpx) - dir * 7 * v.u, Vector2(rp.x, rp.y - hpx) + dir * 4 * v.u, c("#4a4a3a"), 3.2 * v.u)
		cv.draw_circle(Vector2(rp.x, rp.y - hpx) - dir * 8 * v.u, (2.2 + randf()) * v.u, c("#ffb04a"))
		if randf() < 0.6:
			_emit(r.x, r.y, "smoke", 0)
	for r in sim.arcs:
		var rp := iso(r.x, r.y)
		var dir := v.world_dir_to_screen(Vector2(r.vx, r.vy))
		var nrm := dir.orthogonal()
		var cpt := Vector2(rp.x, rp.y - v.WH * 0.5)
		cv.draw_polyline(PackedVector2Array([cpt - nrm * 12 * v.u - dir * 4 * v.u, cpt + dir * 3 * v.u, cpt + nrm * 12 * v.u - dir * 4 * v.u]), Color(c("#3ae0e0"), 0.5), 6 * v.u)
		cv.draw_polyline(PackedVector2Array([cpt - nrm * 12 * v.u - dir * 4 * v.u, cpt + dir * 3 * v.u, cpt + nrm * 12 * v.u - dir * 4 * v.u]), c("#dffcff"), 2 * v.u)
	# grenades in the air
	for l in sim.lobs:
		if l.get("k", 0) == 3:   # a boss missile shows a ring where it lands for its whole flight
			var lr := iso(l.x1, l.y1)
			cv.draw_set_transform(lr, 0, Vector2(1, 0.5))
			cv.draw_arc(Vector2.ZERO, v.TW2 * l.R, 0, TAU, 40, Color(1, 70 / 255.0, 50 / 255.0, 0.55 + 0.35 * sin(sim.game.time * 22.0)), 2.0 * v.u)
			cv.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		var t: float = clampf(l.t / l.T, 0, 1)
		var x: float = lerpf(l.x0, l.x1, t)
		var y: float = lerpf(l.y0, l.y1, t)
		var g := iso(x, y)
		var arc := sin(t * PI) * WH * 2.2
		oval(g.x, g.y, 3 * u, 1.5 * u, Color(0, 0, 0, 0.3))
		cv.draw_circle(Vector2(g.x, g.y - WH * 0.5 - arc), 2.6 * u, c("#3d4a2a"))
	# tracers
	for b in sim.bullets:
		_draw_tracer(b)
	# particles
	for q in parts:
		var pp := iso(q.x, q.y)
		var a: float = clampf(q.life / q.max, 0, 1)
		var col: Color = q.col
		col.a = a
		cv.draw_rect(Rect2(pp.x - 1.2 * u * q.s, pp.y - q.z * u - 1.2 * u * q.s, 2.4 * u * q.s, 2.4 * u * q.s), col)
	_draw_cparts()


# ---------------------------------------------------------------- layers over the world

## boss warnings, the harpoon chain, the evac ring, lightning and blade arcs: over the night so they always read
func _paint_fx(layer: CanvasItem) -> void:
	cv = layer
	var u := v.u
	var WH := v.WH
	var pulse_s := 0.55 + 0.45 * sin(sim.game.time * 22.0)
	for e in sim.enemies:   # spotters: a red laser while they line up, solid with a mark over the soldier once they have them
		if e.type != "spotter" or e.get("st", 0) == 0:
			continue
		var a := iso(e.x, e.y) - Vector2(0, v.WH * 0.55)
		var b := iso(e.lx, e.ly)
		cv.draw_line(a, b - Vector2(0, v.WH * 0.55), Color(1, 60 / 255.0, 50 / 255.0, 0.75 if e.st == 2 else 0.25 + 0.3 * pulse_s), (1.3 if e.st == 2 else 0.9) * u)
		if e.st == 2:
			var y := b.y - v.WH * 1.9
			var sz := 5 * u
			cv.draw_colored_polygon(PackedVector2Array([Vector2(b.x, y - sz), Vector2(b.x + sz * 0.7, y), Vector2(b.x, y + sz), Vector2(b.x - sz * 0.7, y)]), c("#ff4a3a"))
	_draw_boss_fx()
	for chn in sim.chains:   # the Ferryman's harpoon chain
		cv.draw_dashed_line(iso(chn.x0, chn.y0) - Vector2(0, v.WH * 0.55), iso(chn.x1, chn.y1) - Vector2(0, v.WH * 0.44), Color(200 / 255.0, 205 / 255.0, 200 / 255.0, chn.life / chn.max), 2.2 * v.u, 4 * v.u)
	if sim.game.get("fb") != null and sim.game.fb.evac != null:   # the evac site
		var E: Dictionary = sim.game.fb.evac
		var pulse := 0.55 + 0.45 * sin(sim.game.time * 6.0)
		_disc(E.x, E.y, E.r, Color(138 / 255.0, 1, 154 / 255.0, 0.12 + 0.08 * pulse))
		_ring(E.x, E.y, E.r, Color(138 / 255.0, 1, 154 / 255.0, 0.7 + 0.3 * pulse), 2.4)
		var ev_p: float = sim.player.get("ev", 0.0)
		if ev_p > 0 and not sim.player.get("out", false):
			_ring(E.x, E.y, E.r * clampf(ev_p / Sim.BLITZ.hold, 0, 1), c("#ffffff"), 3.0)
	for z in zaps:
		var a: float = z.life / z.max
		var pts := PackedVector2Array()
		for n in z.pts.size() - 1:
			var p0 := iso(z.pts[n].x, z.pts[n].y) - Vector2(0, v.WH * 0.6)
			var p1 := iso(z.pts[n + 1].x, z.pts[n + 1].y) - Vector2(0, v.WH * 0.6)
			pts.append(p0)
			for q in 6:
				var t := (q + 1) / 7.0
				var nrm := (p1 - p0).orthogonal().normalized()
				pts.append(p0.lerp(p1, t) + nrm * randf_range(-6, 6) * v.u)
			pts.append(p1)
		if pts.size() > 1:
			cv.draw_polyline(pts, Color(c("#7fe0ff"), 0.5 * a), 5 * v.u)
			cv.draw_polyline(pts, Color(1, 1, 1, a), 1.6 * v.u)
	for sl in slashes:
		var sp := iso(sl.x, sl.y)
		var a: float = sl.life / sl.max
		var a0 := v.world_dir_to_screen(Vector2(sl.ax, sl.ay)).angle()
		cv.draw_set_transform(Vector2(sp.x, sp.y - v.WH * 0.6), 0, Vector2(1, 0.6))
		cv.draw_arc(Vector2.ZERO, v.TW2 * 1.2, a0 - 1.1, a0 + 1.1, 18, Color(1, 0.9, 0.85, 0.8 * a), 3 * v.u)
		cv.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	cv = self


## muzzle and blast flashes, and the city's lamp glow, added onto the frame (the browser's 'lighter')
func _paint_glow(layer: CanvasItem) -> void:
	cv = layer
	for f in flashes:
		var fp := iso(f.x, f.y) - Vector2(0, v.WH * 0.5)
		var a: float = f.life / f.max
		var r: float = v.TW2 * f.r * (1.0 if f.muzzle else 2.2) * (1.0 if f.muzzle else 1.4 - a * 0.4)
		cv.draw_texture_rect(glow_tex, Rect2(fp.x - r, fp.y - r, r * 2, r * 2), false, Color(1, 1, 1, a))
	if sim.casino():
		CasinoView.glow(self, layer)
	if sim.map_id == "city" and not sim.game.get("dark", false) and light.L > 0.25:
		var r := v.TW2 * 3.5 * 0.9
		for l in sim.lay.lamps:
			var cc := iso(l[0] + 0.5 + l[2] * 0.7, l[1] + 0.5 + l[3] * 0.7)
			if cc.x < -r or cc.x > v.W + r or cc.y < -r or cc.y > v.H + r:
				continue
			cv.draw_texture_rect(glow_tex, Rect2(cc.x - r, cc.y - r, r * 2, r * 2), false, Color(1, 1, 1, 0.18))
	cv = self


## storm streaks, nameplates, floating text, prompts, the crosshair, edge arrows, then the HUD
func _paint_ui(layer: CanvasItem) -> void:
	cv = layer
	var u := v.u
	inp.buttons.clear()
	if demo:
		if skills_open:
			_draw_skills()
		cv = self
		return
	_draw_storm()
	_draw_nameplates()
	for f in floats:
		var fp := iso(f.x, f.y)
		var col: Color = f.col
		col.a = clampf(f.t / 0.5, 0, 1)
		label(f.text, fp.x, fp.y - v.WH * 1.6 - (1.4 - f.t) * 18 * u, col, 11)
	var p: Dictionary = sim.player
	var playing: bool = sim.game.phase != "over" and not sim.game.paused and not armory_open and not skills_open
	if playing:
		_draw_prompts(p)
		if p.alive:
			_draw_crosshair(p)
			_draw_shells(p)
	_draw_edge_arrows()
	if inp.mode == "touch" and playing:
		_draw_touch()
	_draw_hud()
	cv = self


## touch: the two thumb sticks while held, and the buttons (BUILD, GRENADE, the ability or SPRINT, ARMORY, the
## materials, WALL/DOOR, START, PAUSE)
func _draw_touch() -> void:
	var W := v.W
	var H := v.H
	var p: Dictionary = sim.player
	var g: Dictionary = sim.game
	for s in [inp.stick_move, inp.stick_aim]:
		if s.id >= 0:
			cv.draw_arc(s.o, PalInput.SR, 0, TAU, 40, Color(220 / 255.0, 210 / 255.0, 186 / 255.0, 0.35), 2)
			cv.draw_arc(s.o, PalInput.SR * 0.5, 0, TAU, 32, Color(226 / 255.0, 180 / 255.0, 54 / 255.0, 0.25), 2)
			var hot: bool = s == inp.stick_aim and s.mag > 0.5
			cv.draw_circle(s.o + s.v * PalInput.SR, 20, Color(226 / 255.0, 180 / 255.0, 54 / 255.0, 0.8) if hot else Color(220 / 255.0, 210 / 255.0, 186 / 255.0, 0.55))
	var btn := func(r: Rect2, id: String, text: String, on: bool = false) -> void:
		cv.draw_rect(r, Color(226 / 255.0, 180 / 255.0, 54 / 255.0, 0.85) if on else Color(14 / 255.0, 12 / 255.0, 10 / 255.0, 0.7))
		cv.draw_rect(r, Color(226 / 255.0, 180 / 255.0, 54 / 255.0, 0.7), false, 1.5)
		var fs := 12
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		cv.draw_string(font, Vector2(r.position.x + r.size.x / 2 - tw / 2, r.position.y + r.size.y / 2 + 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c("#17140f") if on else c("#e8dcc0"))
		inp.buttons.append([r, id])
	var bx := W - 96
	btn.call(Rect2(bx, H - 250, 84, 64), "build", "BUILD")
	btn.call(Rect2(bx - 92, H - 210, 84, 48), "nade", "GRENADE %d" % p.nades)
	var ab := "ROCKET %d" % p.rk if p.cls == "soldier" else ("STEALTH" if p.cls == "sniper" else ("SPRINT" if p.cls == "quartermaster" else ""))
	if ab != "":
		btn.call(Rect2(bx - 92, H - 270, 84, 48), "special", ab)
	if not sim.casino():
		btn.call(Rect2(bx - 92, H - 154, 84, 48), "roll", "ROLL" if p.dgCd <= 0 else "ROLL %ds" % ceili(p.dgCd), sim.rolling(p))
	if sim.can_shop(p):
		btn.call(Rect2(bx, H - 320, 84, 48), "armory", "ARMORY")
	for k in 3:
		btn.call(Rect2(W / 2 - 150 + k * 76, H - 56, 70, 44), "mat%d" % (k + 1), Pal.MAT[k].name, g.sel == k)
	btn.call(Rect2(W / 2 + 84, H - 56, 70, 44), "piece", g.piece.to_upper())
	btn.call(Rect2(W - 64, 42, 52, 40), "pause", "II")
	if g.phase == "build" or (g.get("bo") != null and g.bo.stage == "ready"):
		btn.call(Rect2(W / 2 - 70, 40, 140, 36), "start", "READY" if g.phase == "raid" else "START NOW")


## drawTracer: the standard tracer, a tapered streak with a hot core that fades toward its tail; raiders' rounds are a
## plain orange line. It sits at the bullet's height on the firing line.
func _draw_tracer(b: Dictionary) -> void:
	var u := v.u
	var L := 0.018 * (minf(CosArt.trail(b.get("tr", "std")).get("len", 1.0), 2.0) if b.team == 0 else 1.0)
	var a := iso(b.x, b.y)
	var hz: float = ((sim.bullet_z(b) - 0.7) if b.has("z0") else sim.height_at(b.x, b.y)) * v.height_px() - sim.height_at(b.x, b.y) * v.height_px()
	a.y -= hz + v.WH * 0.62
	var sp := Vector2(b.vx, b.vy).length()
	var tail := Vector2(a.x - (b.vx - b.vy) * L * v.TW2, a.y - (b.vx + b.vy) * L * v.TH2 + b.get("zSlope", 0.0) * sp * L * v.height_px())
	var pad := 24 * u
	if maxf(a.x, tail.x) < -pad or minf(a.x, tail.x) > v.W + pad or maxf(a.y, tail.y) < -pad or minf(a.y, tail.y) > v.H + pad:
		return
	var w: float = (2.6 if b.get("heavy", false) else 1.8) * u
	if b.team != 0:
		cv.draw_line(a, tail, Color(1, 140 / 255.0, 90 / 255.0, 0.95), w)
		cv.draw_circle(a, w / 2, Color(1, 140 / 255.0, 90 / 255.0, 0.95))
		return
	var tr: String = b.get("tr", "std")
	if tr != "std":
		CosArt.paint_tracer(Ctx2D.new(cv), a.x, a.y, tail.x, tail.y, tr, w * CosArt.trail(tr).get("w", 1.0), sim.game.time, b.get("heavy", false), b.get("tc", 0))
		_shed(b, a, tail)
		return
	var ln := minf(a.distance_to(tail), w * 22)
	if ln < 0.01:
		return
	var dir := (tail - a) / a.distance_to(tail)
	var nrm := dir.orthogonal()
	var hgt := w * 6.5
	var P := func(px: float, py: float) -> Vector2: return a + dir * (px / 192.0 * ln) + nrm * ((py - 24.0) / 48.0 * hgt)
	var fade := func(px: float) -> float: return 1.0 if px / 192.0 <= 0.64 else maxf(0.0, 1.0 - (px / 192.0 - 0.64) / 0.36)
	var shape := [[0, 24], [7, 17], [35, 18], [190, 24], [35, 30], [7, 31]]
	var glow := PackedVector2Array()
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var gcol := PackedColorArray()
	var col := Color(1, 236 / 255.0, 170 / 255.0, 0.95)
	for q in shape:
		pts.append(P.call(q[0], q[1]))
		cols.append(Color(col, col.a * fade.call(q[0])))
		glow.append(P.call(q[0], 24 + (q[1] - 24) * 1.9))
		gcol.append(Color(col, 0.22 * fade.call(q[0])))
	cv.draw_polygon(glow, gcol)
	cv.draw_polygon(pts, cols)
	var core := [[0, 24], [10, 22.7], [145, 24], [10, 25.3]]
	var cp := PackedVector2Array()
	var cc := PackedColorArray()
	for q in core:
		cp.append(P.call(q[0], q[1]))
		cc.append(Color(248 / 255.0, 1, 1, fade.call(q[0])))
	cv.draw_polygon(cp, cc)


## the storm over the yard: rain streaks, blowing dust or falling ash, in screen space
func _draw_storm() -> void:
	if wx_a < 0.01:
		return
	var L: Dictionary = Sim.STORM.look.get(sim.map_id, Sim.STORM.look.yard)
	var kind: String = STORM_KIND.get(sim.map_id, "dust")
	var t: float = sim.game.time
	var W := v.W
	var H := v.H
	var n := 36 if W < 760 else 72
	if kind == "rain":
		var col := Color(200 / 255.0, 220 / 255.0, 235 / 255.0, 0.45 * wx_a)
		for i in int(n * 1.5):
			var h1 := Pal.hash2(i, 7)
			var h2 := Pal.hash2(i, 13)
			var sp := 0.8 + h2 * 0.6
			var y := fposmod(h2 * H + t * 620 * sp, H + 60) - 30
			var x := fposmod(h1 * W * 1.2 - t * 90 * sp, W * 1.2) - W * 0.1
			cv.draw_line(Vector2(x, y), Vector2(x - 5, y + 16), col, 1.1)
	elif kind == "dust":
		var col := Color(226 / 255.0, 196 / 255.0, 140 / 255.0, 0.38 * wx_a)
		for i in n:
			var h1 := Pal.hash2(i, 7)
			var h2 := Pal.hash2(i, 13)
			var sp := 0.7 + h2 * 0.7
			var x := fmod(h1 * W * 1.4 + t * 300 * sp, W * 1.4) - W * 0.2
			var y := h2 * H + sin(t * 2 + i) * 6
			cv.draw_line(Vector2(x, y), Vector2(x + 26 + h1 * 20, y + 3), col, 1.6)
	else:
		var col := Color(190 / 255.0, 180 / 255.0, 168 / 255.0, 0.55 * wx_a)
		for i in n:
			var h1 := Pal.hash2(i, 7)
			var h2 := Pal.hash2(i, 13)
			var sp := 0.5 + h2 * 0.6
			var y := fposmod(h2 * H + t * 40 * sp, H + 20) - 10
			var x := h1 * W + sin(t * 1.3 + i) * 14
			cv.draw_rect(Rect2(x, y, 2.2, 2.2), col)


func _plate_bar(x: float, y: float, w: float, h: float, frac: float, col: Color, pulse: bool) -> void:
	cv.draw_rect(Rect2(x - w / 2 - 1, y - 1, w + 2, h + 2), Color(10 / 255.0, 8 / 255.0, 6 / 255.0, 0.82))
	var cc := (c("#ff5a3a") if pulse else c("#d6402a")) if frac < 0.3 else col
	cv.draw_rect(Rect2(x - w / 2, y, w * clampf(frac, 0, 1), h), cc)


## nameplates: your health above your head, Delgado's name and bar above his (drawn after the lighting)
func _draw_nameplates() -> void:
	var u := v.u
	var p: Dictionary = sim.player
	if sim.casino():   # names only (nobody gets hurt in here), and the dealers in gold
		for o in sim.players.values():
			var cc := iso(o.x, o.y)
			label(("YOU" if is_same(o, p) else str(o.name)).to_upper(), cc.x, cc.y - 48 * u + (5 * u if o.get("seat", 0) else 0.0), c(Pal.SLOTCOL[int(o.slot) % 6]), 9)
		for t in CasinoView.TABLES:
			var dc := iso(t.dealer.x, t.dealer.y)
			label(t.dealer.name + " · DEALER", dc.x, dc.y - 48 * u, c("#d6aa46"), 8)
		return
	var pulse := sin(sim.game.time * 9) > 0
	var W1 := clampf(34 * u, 26, 44)
	var W0 := clampf(40 * u, 30, 50)
	var BH := clampf(4.4 * u, 3.5, 6)
	var ready: bool = sim.game.get("bo") != null and sim.game.bo.get("stage", "") == "ready"
	var friend := func(o: Dictionary) -> bool: return sim.pvp() == "" or (sim.pvp() == "base" and o.team == p.team) or is_same(o, p)
	for o in sim.players.values():
		if not o.alive:
			continue
		var me := is_same(o, p)
		var fr: bool = friend.call(o)
		if not me and not fr and o.get("stl", 0.0) > 0 and sim.pvp() == "":
			continue
		var cc := iso(o.x, o.y)
		var top := cc.y - 46 * u
		var tick := " ✓" if ready and o.get("boReady", false) else ""
		var al := 0.55 if o.get("prot", 0.0) > 0 or o.get("stl", 0.0) > 0 else 1.0
		if me:
			_plate_bar(cc.x, top - 2 * u, W0, BH * 1.2, o.hp / o.max, c("#e8dcc0"), pulse)
			label(str(ceili(o.hp)) + tick, cc.x, top - 7 * u, c("#ff8a6a") if o.hp / o.max < 0.3 else c("#f2ead6"), 10)
		else:
			var col := c(sim.team_col(o) if sim.pvp() != "" else Pal.SLOTCOL[int(o.slot) % 6])
			col.a = al
			label(str(o.name).to_upper() + tick, cc.x, top - (7 if fr else 2) * u, col, 9)
			if fr:
				_plate_bar(cc.x, top - 2 * u, W1, BH, o.hp / o.max, col, pulse)
	# teammates off screen: an arrow on the edge with their name; downed ones blink red
	var mg := 26.0
	var topM := 110.0
	for o in sim.players.values():
		if is_same(o, p) or not friend.call(o) or o.get("out", false):
			continue
		var cc := iso(o.x, o.y)
		if cc.x > mg and cc.x < v.W - mg and cc.y > topM and cc.y < v.H - mg:
			continue
		var ex := clampf(cc.x, mg, v.W - mg)
		var ey := clampf(cc.y, topM + 10, v.H - mg)
		var a := atan2(cc.y - v.H / 2, cc.x - v.W / 2)
		var down: bool = not o.alive
		var col := c(("#ff4a3a" if pulse else "#7a2218") if down else Pal.SLOTCOL[int(o.slot) % 6])
		var tr := Transform2D(a, Vector2(ex, ey))
		var pts := PackedVector2Array([tr * Vector2(11, 0), tr * Vector2(-6, -8), tr * Vector2(-2, 0), tr * Vector2(-6, 8)])
		cv.draw_colored_polygon(pts, col)
		label(str(o.name).to_upper() + (" · DOWN" if down else ""), ex, ey + (-14.0 if ey > v.H / 2 else 18.0), col, 9)
	var q: Dictionary = sim.qm
	if q.alive and not q.get("gone", false):
		var cc := iso(q.x, q.y)
		var top := cc.y - 46 * u
		label("DELGADO", cc.x, top - 7 * u, c("#d6c47a"), 9)
		_plate_bar(cc.x, top - 2 * u, W1, BH, q.hp / q.max, c("#d6c47a"), pulse)


## keyCap: a key in a box and what it does
func _key_cap(x: float, y: float, key: String, text: String, col: Color) -> void:
	var u := v.u
	var fs := int(round(12 * u))
	var kw := maxf(18 * u, font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10 * u) if key != "" else 0.0
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var h := 20 * u
	var w := kw + (6 * u if key != "" else 0.0) + tw + 16 * u
	var x0: float = round(x - w / 2)
	var y0: float = round(y - h / 2)
	cv.draw_rect(Rect2(x0, y0, w, h), Color(14 / 255.0, 12 / 255.0, 10 / 255.0, 0.86))
	cv.draw_rect(Rect2(x0 + 0.5, y0 + 0.5, w - 1, h - 1), col, false, 1.0)
	var cx := x0 + 8 * u
	var base := y0 + h / 2 + fs * 0.36
	if key != "":
		cv.draw_rect(Rect2(cx, y0 + 3 * u, kw, h - 6 * u), col)
		var kws := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		cv.draw_string(font, Vector2(cx + kw / 2 - kws / 2, base), key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c("#17140f"))
		cx += kw + 6 * u
	cv.draw_string(font, Vector2(cx, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c("#f3e9d6"))


func _draw_prompts(p: Dictionary) -> void:
	if not p.alive:
		return
	var u := v.u
	if sim.casino():
		var key := settings.keys_label("armory")
		if p.get("seat", 0):
			if casino_ui == null or not casino_ui.is_open():
				var cc := iso(p.x, p.y)
				_key_cap(cc.x, cc.y - 50 * u, key, "OPEN THE TABLE", c("#d6aa46"))
			return
		var sn := CasinoView.seat_near(sim, p, casino_ui)
		if not sn.is_empty():
			var sc := iso(sn.pos[0], sn.pos[1])
			_key_cap(sc.x, sc.y - 34 * u, key, ("PLAY · " if sn.has("m") else "SIT · ") + (sn.m.name if sn.has("m") else sn.t.name), c("#d6aa46"))
		return
	if sim.can_shop(p):
		var co: Dictionary = sim.core
		if sim.blackout():   # the nearest held POI
			for k in sim.cores:
				if Vector2(p.x - k.i - 0.5, p.y - k.j - 0.5).length() < 2.7 and not k.get("lost", false):
					co = k
		var sc := iso(co.i + 0.5, co.j + 0.5)
		_key_cap(sc.x, sc.y - v.WH * 1.15 - 52 * u, "E", "ARMORY", c("#e2b436"))
	var q: Dictionary = sim.qm
	if not q.get("gone", false) and not q.alive:
		var d := Vector2(q.x - p.x, q.y - p.y).length()
		if d < 2.2:
			var sc := iso(q.x, q.y)
			_key_cap(sc.x, sc.y - 34 * u, "", "REVIVING DELGADO" if d < 1 else "STAND CLOSE TO REVIVE DELGADO", c("#a9bccb"))


func _draw_crosshair(p: Dictionary) -> void:
	var m := Vector2.ZERO
	var hot := false
	var faint := false
	if inp.mode == "mouse":
		if not mouse_seen:
			return
		m = get_viewport().get_mouse_position()
		var w := _screen_to_world(m.x, m.y + v.WH * 0.55)
		for e in sim.enemies:
			if not e.dead and Vector2(e.x - w.x, e.y - w.y).length() < 0.45:
				hot = true
				break
	else:   # a stick: a mark along the aim, on the raider it would hit
		var active: bool = inp.amag > 0.2 if inp.mode == "pad" else (inp.stick_aim.id >= 0 and inp.stick_aim.mag > 0.2)
		var a: Vector2 = p.aim
		var d: float = minf(p.gun.range, 4.2) if active else 2.4
		faint = not active
		if active:
			var best := 1e9
			for e in sim.enemies:
				var dv := Vector2(e.x - p.x, e.y - p.y)
				var dd := dv.length()
				if not e.dead and dd < p.gun.range and dd > 0.3 and dv.dot(a) / dd > 0.992 and dd < best:
					best = dd
					hot = true
			if hot:
				d = best
		m = iso(p.x + a.x * d, p.y + a.y * d) - Vector2(0, v.WH * 0.55)
	if faint:
		draw_alpha = 0.4
	var r := (6.0 if hot else 8.0) * maxf(1.0, v.u * 0.9)
	var col := c("#ff6a4a") if hot else c("#f3e9d6")
	for pz in [[3.4, Color(12 / 255.0, 10 / 255.0, 8 / 255.0, 0.75)], [1.6, col]]:
		cv.draw_arc(m, r, 0, TAU, 32, pz[1], pz[0])
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			cv.draw_line(m + d * (r + 2), m + d * (r + 7), pz[1], pz[0])
	cv.draw_rect(Rect2(m.x - 1, m.y - 1, 2, 2), col)
	draw_alpha = 1.0


## the Grenadier's tube: a shell for each round, red for loaded
func _draw_shells(p: Dictionary) -> void:
	var G: Dictionary = p.gun
	if not G.has("mag") or not p.has("ammo"):
		return
	var u := v.u
	var cc := iso(p.x, p.y)
	var n: int = G.mag
	var sw := 4 * u
	var gap := 2 * u
	var x0 := cc.x - (n * sw + (n - 1) * gap) / 2
	var y0 := cc.y + 9 * u
	for i in n:
		var x := x0 + i * (sw + gap)
		cv.draw_rect(Rect2(x - 1, y0 - 1, sw + 2, 8 * u + 2), Color(12 / 255.0, 10 / 255.0, 8 / 255.0, 0.75))
		if i < p.ammo:
			cv.draw_rect(Rect2(x, y0, sw, 5.4 * u), c("#c23a2e"))
			cv.draw_rect(Rect2(x, y0 + 5.4 * u, sw, 2.6 * u), c("#d8b25a"))
	if p.get("rl", 0.0) > 0 and p.ammo < n:
		label("RELOADING" if p.ammo <= 0 else "LOADING", cc.x, y0 + 19 * u, c("#ff6a4a") if p.ammo <= 0 else c("#dcd2ba"), 9)


const ECOL := {"rifle": "#d65a3a", "gren": "#e2b436", "breach": "#ff8a5a", "shield": "#9aa4ae", "medic": "#8fe0a0", "spotter": "#ff5a4a", "fire": "#ff9a2a"}


## raiders off screen: an arrow on the edge pointing at each, bigger for a boss
func _draw_edge_arrows() -> void:
	var top := 110.0
	for e in sim.enemies:
		if e.dead:
			continue
		var cc := iso(e.x, e.y)
		if cc.x > 14 and cc.x < v.W - 14 and cc.y > top and cc.y < v.H - 14:
			continue
		var ex := clampf(cc.x, 18, v.W - 18)
		var ey := clampf(cc.y, top + 8, v.H - 18)
		var a := atan2(cc.y - v.H / 2, cc.x - v.W / 2)
		var k := 1.6 if e.type == "boss" else 1.0
		var col: Color = c(Sim.boss_def(e.boss).col) if e.type == "boss" else c(ECOL.get(e.type, "#ff8a5a"))
		var xf := Transform2D(a, Vector2(k, k), 0, Vector2(ex, ey))
		cv.draw_set_transform_matrix(xf)
		cv.draw_colored_polygon(PackedVector2Array([Vector2(8, 0), Vector2(-5, -6), Vector2(-5, 6)]), col)
		cv.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_debris(i: int, j: int, mat: int) -> void:
	var m: Dictionary = Pal.MAT[mat]
	for n in 4:
		var hs := Pal.hash2(i * 5 + n, j * 3 + n)
		var hs2 := Pal.hash2(i * 3 + n, j * 7 + n)
		box_r(i + 0.15 + hs * 0.55, j + 0.15 + hs2 * 0.55, i + 0.3 + hs * 0.55, j + 0.3 + hs2 * 0.55, 0, 3 * v.u, c(m.top).darkened(0.25), c(m.l).darkened(0.25), c(m.r).darkened(0.25))


## drawWallShape for ordinary walls and doors (15-render.js)
func _draw_wall(i: int, j: int, w: Dictionary) -> void:
	if w.get("slab", false):   # the Foreman's rock slab: a rough grey block, lower as it cracks
		var sst := Pal.wall_state(w)
		var sh := v.WH * (0.45 if sst == 2 else (0.6 if sst == 1 else 0.72))
		var hs := Pal.hash2(i + 7, j + 3)
		box_r(i + 0.1, j + 0.14, i + 0.9, j + 0.86, 0, sh, c("#9a948a") if w.flash > 0 else c("#6f695f"), c("#524d46"), c("#403c37"))
		box_r(i + 0.22 + hs * 0.2, j + 0.24, i + 0.62 + hs * 0.2, j + 0.6, sh, v.WH * 0.18, c("#7d766b"), c("#5c5750"), c("#4a4640"))
		return
	var u := v.u
	var m: Dictionary = Pal.MAT[w.mat]
	var st := Pal.wall_state(w)
	var h := v.WH * (0.58 if st == 2 else 1.0)
	var top := c(m.top)
	var l := c(m.l)
	var r := c(m.r)
	if w.char > 0:
		top = top.lerp(c("#241b15"), w.char * 0.85)
		l = l.lerp(c("#1d1612"), w.char * 0.85)
		r = r.lerp(c("#18120f"), w.char * 0.85)
	if w.flash > 0:
		top = c(m.top).lerp(Color.WHITE, 0.35)
	var bx := box_r(i + 0.03, j + 0.03, i + 0.97, j + 0.97, 0, h, top, l, r)
	var B: Vector2 = bx.B
	var C: Vector2 = bx.C
	var D: Vector2 = bx.D
	var lw := maxf(1.0, u * 0.9)
	var line: Color = m.line
	if w.mat == 2:
		for t in [0.2, 0.4, 0.6, 0.8]:
			for pq in [[D, C], [C, B]]:
				var a: Vector2 = pq[0].lerp(pq[1], t)
				cv.draw_line(a, Vector2(a.x, a.y - h), line, lw)
	else:
		for vv in [0.33, 0.66]:
			for pq in [[D, C], [C, B]]:
				cv.draw_line(up(pq[0], h * vv), up(pq[1], h * vv), line, lw)
		if w.mat == 1:
			for pq in [[D, C], [C, B]]:
				for tv in [[0.3, 0.0], [0.7, 0.0], [0.5, 0.33], [0.15, 0.66], [0.85, 0.66]]:
					var a := up(pq[0].lerp(pq[1], tv[0]), h * tv[1])
					cv.draw_line(a, Vector2(a.x, a.y - h * 0.33), line, lw)
	if w.door:
		var dc := c("#3b4142") if w.mat == 2 else (c("#3a2418") if w.mat == 1 else c("#3d2a17"))
		for pq in [[D, C], [C, B]]:
			var a: Vector2 = pq[0].lerp(pq[1], 0.3)
			var b: Vector2 = pq[0].lerp(pq[1], 0.7)
			quad(a, b, up(b, h * 0.82), up(a, h * 0.82), dc)
			var hd := up(pq[0].lerp(pq[1], 0.62), h * 0.42)
			cv.draw_rect(Rect2(hd.x - u, hd.y - u, 2 * u, 2 * u), c("#e2b436"))
	if st > 0:
		var n := 2 if st == 1 else 3
		var col := Color(40 / 255.0, 44 / 255.0, 45 / 255.0, 0.75) if w.mat == 2 and st == 1 else c("#0e0b09")
		for pqs in [[D, C, 1], [C, B, 2]]:
			for q in n:
				var hu := 0.2 + Pal.hash2(i * 7 + q + pqs[2] * 13, j * 5) * 0.6
				var hv := 0.25 + Pal.hash2(i * 3 + q, j * 11 + pqs[2]) * 0.5
				var pt := up(pqs[0].lerp(pqs[1], hu), h * hv)
				oval(pt.x, pt.y, (2.2 + st) * u, (2.8 + st) * u, col)
	if w.fire > 0:
		var cc := iso(i + 0.5, j + 0.5)
		var t := Time.get_ticks_msec() / 1000.0
		cv.draw_circle(Vector2(cc.x, cc.y - h), v.TW2 * (0.55 + 0.08 * sin(t * 13.0 + i)), Color(1, 0.55, 0.2, 0.35))
		cv.draw_circle(Vector2(cc.x, cc.y - h - 4 * u), v.TW2 * 0.25, Color(1, 0.8, 0.4, 0.5))


func _draw_node(n: Dictionary) -> void:
	var u := v.u
	var WH := v.WH
	var i: int = n.i
	var j: int = n.j
	if n.type == 0:
		var layers := ceili(n.amt / 16.0)
		if layers == 0:
			box_r(i + 0.3, j + 0.4, i + 0.7, j + 0.55, 0, 2 * u, c("#6b4a28"), c("#4f361d"), c("#3e2a16"))
			return
		for s in layers:
			box_r(i + 0.18, j + 0.22, i + 0.82, j + 0.48, s * 5 * u, 5 * u, c("#c09058"), c("#8b6236"), c("#6b4a28"))
			box_r(i + 0.18, j + 0.52, i + 0.82, j + 0.78, s * 5 * u, 5 * u, c("#b8894f"), c("#86603a"), c("#654626"))
	elif n.type == 1:
		var lk: bool = n.locked
		var cs := [c("#6a5048"), c("#4c3a34"), c("#3a2c28")] if lk else [c(Pal.MAT[1].top), c(Pal.MAT[1].l), c(Pal.MAT[1].r)]
		var bx := box_r(i + 0.1, j + 0.1, i + 0.9, j + 0.9, 0, WH * 1.05, cs[0], cs[1], cs[2])
		var m: Vector2 = bx.D.lerp(bx.C, 0.5)
		oval(m.x, m.y - WH * 0.3, 5 * u, 7 * u, c("#1a1412") if lk else c("#2a0f06"))
		if not lk:
			oval(m.x, m.y - WH * 0.25, 3.4 * u, 4.5 * u, Color(1, (140 + sin(sim.game.time * 6) * 30) / 255.0, 50 / 255.0, 0.8))
		box_r(i + 0.55, j + 0.15, i + 0.8, j + 0.4, WH * 1.05, WH * 0.9, cs[0], cs[1], cs[2])
	else:
		var cs := [c("#5d6262"), c("#454a4a"), c("#353939")] if n.locked else [c(Pal.MAT[2].top), c(Pal.MAT[2].l), c(Pal.MAT[2].r)]
		box_r(i + 0.12, j + 0.2, i + 0.62, j + 0.7, 0, WH * 0.5, cs[0], cs[1], cs[2])
		box_r(i + 0.45, j + 0.1, i + 0.9, j + 0.55, 0, WH * 0.8, cs[0], cs[1], cs[2])
		box_r(i + 0.3, j + 0.55, i + 0.85, j + 0.9, 0, WH * 0.3, cs[0], cs[1], cs[2])
	if n.locked:
		var cc := iso(i + 0.5, j + 0.5)
		label("%s · OPENS RAID %d" % ["KILN" if n.type == 1 else "SCRAP", n.unlock], cc.x, cc.y - WH * 2.1, c("#9a8f7a"), 10)


func _draw_stake(which = null) -> void:
	var u := v.u
	var WH := v.WH
	var co: Dictionary = which if which != null else sim.core
	var i: int = co.i
	var j: int = co.j
	var f: bool = co.flash > 0
	var band := c(Pal.TEAMS[co.team].col if Pal.TEAMS.has(co.get("team", "")) else "#e2b436")
	var bx := box_r(i + 0.14, j + 0.14, i + 0.86, j + 0.86, 0, WH * 1.15, c("#8a4a34") if f else c("#4d5c40"), c("#6a3424") if f else c("#38452e"), c("#50281c") if f else c("#2a3421"))
	for pq in [[bx.D, bx.C], [bx.C, bx.B]]:
		quad(up(pq[0], WH * 0.62), up(pq[1], WH * 0.62), up(pq[1], WH * 0.8), up(pq[0], WH * 0.8), band)
	var top := iso(i + 0.5, j + 0.5)
	var px := top.x
	var py := top.y - WH * 1.15
	cv.draw_line(Vector2(px, py), Vector2(px, py - 28 * u), c("#1b1812"), 2 * u)
	var fl := sin(sim.game.time * 5) * 2 * u
	cv.draw_colored_polygon(PackedVector2Array([Vector2(px, py - 28 * u), Vector2(px + 15 * u, py - 24 * u + fl), Vector2(px, py - 19 * u)]), band)
	if sim.pvp() == "base":
		label("YOUR STAKE" if co.team == sim.player.team else "ENEMY STAKE", px, py - 36 * u, band, 10)


func _draw_ghost() -> void:
	var p: Dictionary = sim.player
	if not p.alive or sim.game.phase == "over" or sim.casino():
		return
	var t := sim.build_target(p, sim.game.sel, sim.game.piece == "door")
	if not sim.inb(t.i, t.j):
		return
	var col := Color(0.56, 0.88, 0.63, 0.28) if t.ok else Color(0.84, 0.35, 0.23, 0.25)
	quad(iso(t.i, t.j), iso(t.i + 1, t.j), iso(t.i + 1, t.j + 1), iso(t.i, t.j + 1), col)
	var line := Color(col, 0.8)
	var pts := PackedVector2Array([iso(t.i, t.j), iso(t.i + 1, t.j), iso(t.i + 1, t.j + 1), iso(t.i, t.j + 1), iso(t.i, t.j)])
	cv.draw_polyline(pts, line, maxf(1.0, v.u))


## The browser's LOOK table (16-characters.js) for raiders, and QM_LOOK for Delgado
const LOOK := {
	"rifle": {"body": "#7e3a2a", "vest": "#3f231a", "pants": "#2b2420", "head": "#b08868", "helmet": "#2f2820", "bandana": "#a8342a"},
	"gren": {"body": "#6c5738", "vest": "#2f261b", "pants": "#2b2420", "head": "#a98262", "helmet": "#241f19", "pack": "#3a2e1f", "bandolier": true, "bandana": "#a8342a", "gl": 17},
	"breach": {"body": "#5a2a22", "vest": "#1f1512", "pants": "#231c19", "head": "#a07a5c", "cap": "#1a1512", "bandana": "#a8342a", "nogun": true},
	"shield": {"body": "#3f4048", "vest": "#23242a", "pants": "#26262b", "head": "#a98262", "helmet": "#2a2b30", "bandana": "#a8342a", "weapon": "shield", "big": 1.1, "gl": 8},
	"medic": {"body": "#6a5a48", "vest": "#e8e2d0", "pants": "#2b2420", "head": "#b08868", "helmet": "#e8e2d0", "pack": "#e8e2d0", "cross": true, "gl": 8},
	"spotter": {"body": "#4a4a36", "vest": "#2a2a1e", "pants": "#2b2420", "head": "#a98262", "boonie": "#8a2a22", "bandana": "#a8342a", "gl": 8},
	"fire": {"body": "#6a3a1e", "vest": "#2a1a10", "pants": "#231c19", "head": "#a07a5c", "wrap": "#d06a1e", "pack": "#3a2a1a", "weapon": "bottle"},
}
const QM_LOOK := {"body": "#9e9a78", "vest": "#3d4a52", "pants": "#3a3a33", "head": "#b58f6e", "cap": "#3d4a52", "pack": "#5a4a30", "gl": 14, "weapon": "sg"}
## buildLook (16-characters.js) on the default "std" skin: each class's kit and headgear
## the player's outfit (the locker's equipped skin and headgear) on their class, as a wardrobe look
func player_look(p: Dictionary) -> Dictionary:
	var eq: Dictionary = (locker.eq if locker else PalLocker.DEFAULT_COS) if p.id == sim.player.id else PalLocker.parse_cos(p.get("cosS", ""))
	var key := "%s|%s|%s" % [eq.get("skin", "std"), eq.get("hat", "class"), p.cls]
	if not looks.has(key):
		looks[key] = Wardrobe.look_for(eq, p.cls)
	return looks[key].duplicate()


## render-only gait from how far the soldier actually moved (presentationMotion): phase, weight and lean
func _motion(p: Dictionary) -> Dictionary:
	var now: float = sim.game.time
	var m: Dictionary = pmotion.get(p.id, {})
	if m.is_empty() or now < m.at or now - m.at > 1:
		m = {"x": p.x, "y": p.y, "at": now, "moved": now - 1, "weight": 0.0, "strength": 0.0, "phase": 0.0, "dx": 0.0, "dy": 1.0}
		pmotion[p.id] = m
	var dt: float = now - m.at
	if dt > 0:
		var dx: float = p.x - m.x
		var dy: float = p.y - m.y
		var d := sqrt(dx * dx + dy * dy)
		if d > maxf(0.0001, dt * 0.12) and d < 2:
			m.phase = fmod(m.phase + d * 3, TAU)
			m.moved = now
			m.strength = minf(1, d / dt / 1.4)
			m.dx = dx / d
			m.dy = dy / d
		var target: float = 0.0 if p.downed or not p.alive else (m.strength if now - m.moved < 0.085 else 0.0)
		m.weight += (target - m.weight) * (1 - exp(-dt / (0.075 if target > 0 else 0.085)))
		m.x = p.x
		m.y = p.y
		m.at = now
	var dir := Wardrobe.aim_angle(v.world_dir_to_screen(Vector2(m.dx, m.dy))) - Wardrobe.aim_angle(v.world_dir_to_screen(p.aim))
	return {"walk": m.phase, "gaitWeight": roundf(m.weight * 4) / 4, "gaitDir": roundf(dir / (PI / 4)) * PI / 4}


## a figure in the 3D-shaded wardrobe style (players, and anyone wearing a cosmetic), with its outfit effect
func draw_wardrobe(x: float, y: float, o: Dictionary) -> void:
	var sc := iso(x, y)
	var k: float = v.u * Figure.FIG * o.get("big", 1.0)
	var t: float = sim.game.time
	var fa := (0.5 if o.get("faded") else 1.0) * draw_alpha
	if o.get("aura"):
		CosFx.paint_aura(cv, o.aura, sc.x, sc.y, k, t, fa, "ground")
	Wardrobe.draw(cv, o, Wardrobe.aim_angle(v.world_dir_to_screen(o.aim)), t, k, sc.x, sc.y, o.get("walk", 0.0), draw_alpha)
	if o.get("aura"):
		CosFx.paint_aura(cv, o.aura, sc.x, sc.y, k, t, fa, "top")
	if o.has("tag"):
		label(o.tag, sc.x, sc.y - 46 * v.u * o.get("big", 1.0), c(o.get("tag_col", "#a9bccb")), 11 if o.get("big", 1.0) > 1 else 9)


static func class_look(cls: String) -> Dictionary:
	var o := {"body": "#b9aa82", "vest": "#4d6b47", "pants": "#4a4636", "head": "#c19a78", "gl": 14}
	match cls:
		"sniper":
			o.gl = 19
			o.boonie = "#5b5a3c"
		"grenadier":
			o.pack = "#4a3a26"
			o.bandolier = true
			o.gl = 15
			o.weapon = "sg"
			o.helmet = "#4a5238"
		"quartermaster":
			o.pack = "#5a4a30"
			o.cross = true
			o.gl = 11
			o.cap = "#4a5238"
		_:
			o.helmet = "#4a5238"
	return o


## enemies under an ammo effect: an orange ring while they burn, a blue one while they're slowed
func _draw_ammo_status(e: Dictionary) -> void:
	if not (e.get("burnT", 0.0) > 0 or e.get("slowT", 0.0) > 0):
		return
	var cc := iso(e.x, e.y)
	if e.get("burnT", 0.0) > 0:
		cv.draw_set_transform(Vector2(cc.x, cc.y - 2 * v.u), 0, Vector2(1, 0.4))
		cv.draw_arc(Vector2.ZERO, 10 * v.u, 0, TAU, 32, c("#ff8244"), 1.8 * v.u)
	if e.get("slowT", 0.0) > 0:
		cv.draw_set_transform(Vector2(cc.x, cc.y + 2 * v.u), 0, Vector2(1, 5.0 / 13))
		cv.draw_arc(Vector2.ZERO, 13 * v.u, 0, TAU, 32, c("#81dafa"), 1.8 * v.u)
	cv.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


# ---------------------------------------------------------------- HUD

func _draw_hud() -> void:
	var g: Dictionary = sim.game
	var p: Dictionary = sim.player
	var W := v.W
	var H := v.H
	# the kill feed (top right) and the room's chat (bottom left), online
	for i in feed.size():
		var f: Dictionary = feed[i]
		var fc := c(f.col)
		fc.a = clampf(f.t / 0.7, 0.0, 1.0)
		var fw := font.get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		cv.draw_string(font, Vector2(W - 14 - fw, 56 + i * 17), f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, fc)
	if net.is_online() and net.in_game:
		var now := Time.get_ticks_msec()
		var lines: Array = net.chat.filter(func(l): return now - l.get("at", now) < 9000 or (chat_box != null and chat_box.visible))
		lines = lines.slice(maxi(0, lines.size() - 5))
		for i in lines.size():
			var l: Dictionary = lines[i]
			cv.draw_string(font, Vector2(14, H - 140 - (lines.size() - 1 - i) * 17), "%s: %s" % [str(l.name).to_upper(), l.text], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c(l.col))
	var gold := c("#e2b436")
	var paper := c("#e8dcc0")
	var dim := c("#9a8f7a")
	# top bar: phase, clock, stake
	cv.draw_rect(Rect2(0, 0, W, 34), Color(10 / 255.0, 8 / 255.0, 6 / 255.0, 0.72))
	var phase_txt: String
	var clock := func(t: float) -> String:
		var sec := maxi(0, ceili(t))
		return "%d:%02d" % [sec / 60, sec % 60]
	if sim.casino():
		phase_txt = "PALISADE FALLS CASINO · %s◆ %d%s" % [("ROOM %s · " % net.code) if net.is_online() and net.code != "" else "", locker.shards if locker != null else 0, " · seated" if p.get("seat", 0) else ""]
	elif sim.pvp() == "base" and g.phase != "over":
		var mine := 0
		var theirs := 0
		for o in sim.players.values():
			if o.team == p.team:
				mine += o.kills
			else:
				theirs += o.kills
		var other := "b" if p.team == "a" else "a"
		phase_txt = ("TRUCE · %s until the battle%s" % [clock.call(g.timer), "   (ENTER: start the battle)" if not net.guest() else ""]) if g.phase == "build" else "BATTLE · %s %d · %s %d drops" % [Pal.TEAMS[p.team].name, mine, Pal.TEAMS[other].name, theirs]
	elif sim.pvp() == "ffa" and g.phase != "over":
		var rank: Array = sim.players.values()
		rank.sort_custom(func(a, b): return a.kills > b.kills or (a.kills == b.kills and a.deaths < b.deaths))
		phase_txt = "FREE-FOR-ALL · %s left · first to %d   %s" % [clock.call(g.timer), g.goal, "  ".join(rank.slice(0, 6).map(func(o): return "%s %d" % ["YOU" if is_same(o, p) else str(o.name).to_upper(), o.kills]))]
	elif sim.blackout() and g.phase != "over":
		phase_txt = CityView.phase_text(sim)
	elif g.phase == "build" and sim.campaign():
		phase_txt = "CH %d · BUILD · %s · %s IN %ds   (ENTER: start now)" % [g.chapter + 1, sim.map_def.name, "FINAL EVACUATION" if g.wave == 12 else "RAID %d/3" % (g.wave % 3 + 1), ceili(g.timer)]
	elif g.phase == "build":
		phase_txt = "BUILD · RAID %d IN %ds   (ENTER: start now)" % [g.wave + 1, ceili(g.timer)]
	elif g.phase == "raid":
		phase_txt = "%s · %d RAIDERS LEFT" % [sim.raid_name(g.wave), sim.enemies.size() + g.queue.size()]
		if g.get("fb") != null:
			var ft: float = g.fb.t
			var fbn := "MAP EVAC" if g.fb.get("mapEvac", false) else ("GAUNTLET · WAVE %d/6" % g.fb.wave if g.fb.get("gauntlet", false) else "FINAL BLITZ")
			phase_txt = "%s · %d:%02d · %s" % [fbn, floori(ft / 60), floori(fmod(ft, 60)), "GET TO THE EVAC" if g.fb.evac != null else "%d BOSSES UP" % sim.live_bosses()]
	else:
		phase_txt = "GAME OVER"
	cv.draw_string(font, Vector2(14, 22), phase_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, paper)
	var bw := 220.0
	var bx := W - bw - 16
	if sim.pvp() != "ffa" and not sim.casino():
		cv.draw_string(font, Vector2(bx - 80, 22), "COMMAND" if sim.map_id == "city" else ("STAKES" if sim.pvp() == "base" else "STAKE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, dim)
	if sim.map_id == "city":
		if city_map == null:
			city_map = CityView.map_image(sim)
		CityView.minimap(self, city_map, W - 186, 44, 170)
	if sim.pvp() == "base":   # yours over theirs, in the sides' colours
		var mc: Dictionary = sim.stake_of(p)
		var ec: Dictionary = sim.cores[1 if p.team == "a" else 0]
		cv.draw_rect(Rect2(bx, 6, bw, 9), Color(0, 0, 0, 0.6))
		cv.draw_rect(Rect2(bx, 6, bw * maxf(0, mc.hp / mc.max), 9), c(Pal.TEAMS[mc.team].col))
		cv.draw_rect(Rect2(bx, 19, bw, 9), Color(0, 0, 0, 0.6))
		cv.draw_rect(Rect2(bx, 19, bw * maxf(0, ec.hp / ec.max), 9), c(Pal.TEAMS[ec.team].col))
	elif sim.pvp() == "" and not sim.casino():
		cv.draw_rect(Rect2(bx, 11, bw, 12), Color(0, 0, 0, 0.6))
		cv.draw_rect(Rect2(bx, 11, bw * maxf(0, sim.core.hp / sim.core.max), 12), gold)
	if sim.casino():   # no kit, no building, no Delgado in here
		return
	# bottom-left: health, materials, grenades
	var y0 := H - 74
	cv.draw_rect(Rect2(10, y0 - 8, 330, 72), Color(10 / 255.0, 8 / 255.0, 6 / 255.0, 0.72))
	cv.draw_string(font, Vector2(20, y0 + 10), p.C.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, dim)
	cv.draw_rect(Rect2(86, y0, 150, 10), Color(0, 0, 0, 0.6))
	cv.draw_rect(Rect2(86, y0, 150 * maxf(0, p.hp / p.max), 10), c("#8fe0a0") if p.hp / p.max > 0.35 else c("#d65a3a"))
	var kit := "NADES %d" % p.nades
	match p.cls:
		"soldier":
			kit += " · RKT %d" % p.rk
		"sniper":
			kit += (" · HIDDEN %ds" % ceili(p.stl)) if p.stl > 0 else (" · STEALTH %ds" % ceili(p.stlCd) if p.stlCd > 0 else " · STEALTH (Q)")
		"grenadier":
			kit += " · SHELLS %d/%d" % [p.ammo, p.gun.mag]
		"quartermaster":
			kit += " · SPRINT %ds" % ceili(p.sprCd) if p.sprCd > 0 else " · SPRINT (SHIFT)"
	cv.draw_string(font, Vector2(246, y0 + 10), kit, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, paper)
	if p.ammoEq[0] != "":
		for A in Sim.AMMO:
			if A.id == p.ammoEq[0]:
				cv.draw_string(font, Vector2(20, y0 - 44), "AMMO · " + A.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c(A.col))
	_draw_boss_bar()
	for m in 3:
		var x := 20 + m * 100
		var sel: bool = g.sel == m
		var col := c(Pal.MAT[m].top)
		if sel:
			cv.draw_rect(Rect2(x - 4, y0 + 18, 94, 26), Color(col, 0.25))
			cv.draw_rect(Rect2(x - 4, y0 + 18, 94, 26), col, false, 1.5)
		cv.draw_rect(Rect2(x, y0 + 24, 12, 12), col)
		cv.draw_string(font, Vector2(x + 18, y0 + 36), "%d %s %d" % [m + 1, Pal.MAT[m].name, p.mats[m]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, paper if sel else dim)
	cv.draw_string(font, Vector2(20, y0 + 58), "PIECE: %s (F)   SALVAGE %d   DROPS %d" % [g.piece.to_upper(), p.sal, p.kills], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, dim)
	var q: Dictionary = sim.qm
	if not q.get("gone", false):   # On Your Own: no Delgado line
		var qtxt: String = ("DELGADO · %s · %s   (H)" % ["FOLLOW" if q.mode == "follow" else "DEFEND", q.status]) if q.alive else "DELGADO IS DOWN · stand over him"
		cv.draw_rect(Rect2(10, y0 - 34, 330, 22), Color(10 / 255.0, 8 / 255.0, 6 / 255.0, 0.72))
		cv.draw_string(font, Vector2(20, y0 - 18), qtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c("#a9bccb") if q.alive else c("#d65a3a"))
	# what SPACE would do
	if p.alive and g.phase != "over":
		var t := sim.build_target(p, g.sel, g.piece == "door")
		var tc := iso(t.i + 0.5, t.j + 0.5)
		var msg: String = ("%s · %d %s" % [t.act, t.cost, Pal.MAT[t.mat].name]) if t.ok else t.reason
		if msg != "":
			label(msg, tc.x, tc.y - v.WH * 1.4, c("#8fe0a0") if t.ok else c("#d65a3a"), 10)
	# toast
	for tt in ([] if menus.active() else toasts):
		var a: float = clampf(tt.t / 0.6, 0, 1)
		label(tt.title, W / 2, 78, Color(gold, a), 22)
		label(tt.body, W / 2, 102, Color(paper, a), 13)
	if armory_open:
		_draw_armory()
	elif skills_open:
		_draw_skills()
	if settings.data.fps:
		cv.draw_string(font, Vector2(W - 70, H - 10), fps_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, dim)


## boss warnings (drawBossFx in 16-characters.js): the Demolisher's red line and landing ring, the Butcher's wedge and
## charge lane, the Stormcaller's blue line (dashed while it tracks you, solid once it locks)
func _draw_boss_fx() -> void:
	var u := v.u
	var ch := v.WH * 0.55
	var pulse := 0.55 + 0.45 * sin(sim.game.time * 22.0)
	for e in sim.enemies:
		if e.type != "boss" or e.st == 0:
			continue
		var f: float = maxf(0.0, e.stT / e.stM)
		var b0 := iso(e.x, e.y)
		if _draw_new_fx(e, f, pulse, ch):
			continue
		var kb: String = Sim.boss_def(e.boss).get("base", e.boss)
		if e.boss == "demolisher":
			var a := atan2(e.ly - e.y, e.lx - e.x)
			var L := Vector2(e.lx - e.x, e.ly - e.y).length()
			var col := Color(1, 60 / 255.0, 40 / 255.0, 0.5 + 0.45 * pulse)
			for o in ([-0.3, 0.0, 0.3] if e.st == 2 else [0.0]):
				var q := iso(e.x + cos(a + o) * L, e.y + sin(a + o) * L)
				cv.draw_dashed_line(b0 - Vector2(0, ch * 1.2), q - Vector2(0, ch * 1.2), col, 2.2 * u, 7 * u)
				cv.draw_set_transform(q, 0, Vector2(1, 0.5))
				cv.draw_arc(Vector2.ZERO, v.TW2 * 1.5 * (1.15 - f * 0.15), 0, TAU, 40, col, 2.2 * u)
				cv.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		elif kb == "butcher" and e.st == 1:
			var a0 := atan2(e.aim.y, e.aim.x)
			var pts := PackedVector2Array([b0])
			for k in 11:
				var a := a0 + (k / 10.0 - 0.5) * 2.4
				pts.append(iso(e.x + cos(a) * 1.5, e.y + sin(a) * 1.5))
			cv.draw_colored_polygon(pts, Color(1, 50 / 255.0, 40 / 255.0, 0.18 + 0.2 * pulse))
		elif kb == "butcher" and e.st == 2:
			var dx: float = e.lx - e.x
			var dy: float = e.ly - e.y
			var l := maxf(0.001, Vector2(dx, dy).length())
			var nx := -dy / l * 0.45
			var ny := dx / l * 0.45
			var P := PackedVector2Array([iso(e.x + nx, e.y + ny), iso(e.lx + nx, e.ly + ny), iso(e.lx - nx, e.ly - ny), iso(e.x - nx, e.y - ny)])
			cv.draw_colored_polygon(P, Color(1, 50 / 255.0, 40 / 255.0, 0.16 + 0.22 * pulse))
			P.append(P[0])
			cv.draw_polyline(P, Color(1, 80 / 255.0, 60 / 255.0, 0.6 + 0.3 * pulse), 1.6 * u)
		elif kb == "storm" and e.boss == "tempest" and e.st == 1:
			var a := atan2(e.ly - e.y, e.lx - e.x)
			for sgn in [-1.0, 1.0]:
				var ox: float = -sin(a) * Sim.TWIN_GAP * sgn
				var oy: float = cos(a) * Sim.TWIN_GAP * sgn
				var q := iso(clampf(e.x + ox + cos(a) * 12, 0, sim.N), clampf(e.y + oy + sin(a) * 12, 0, sim.N))
				var p0 := iso(e.x + ox, e.y + oy)
				var col := Color(191 / 255.0, 244 / 255.0, 1, (0.75 + 0.25 * pulse) if f < 0.36 else (0.35 + 0.3 * pulse))
				cv.draw_dashed_line(p0 - Vector2(0, ch), q - Vector2(0, ch), col, 1.6 * u, 6 * u)
		elif kb == "storm":
			var dx: float = e.lx - e.x
			var dy: float = e.ly - e.y
			var l := maxf(0.001, Vector2(dx, dy).length())
			var q := iso(clampf(e.x + dx / l * 12, 0, sim.N), clampf(e.y + dy / l * 12, 0, sim.N))
			var locked := f < 0.36
			var col := Color(127 / 255.0, 224 / 255.0, 1, (0.75 + 0.25 * pulse) if locked else (0.35 + 0.3 * pulse))
			if locked:
				cv.draw_line(b0 - Vector2(0, ch), q - Vector2(0, ch), col, 2.4 * u)
			else:
				cv.draw_dashed_line(b0 - Vector2(0, ch), q - Vector2(0, ch), col, 1.4 * u, 6 * u)


func _draw_boss_bar() -> void:
	for e in sim.enemies:
		if e.type != "boss":
			continue
		var B: Dictionary = Sim.boss_def(e.boss)
		var w := minf(420.0, v.W - 40)
		var x := (v.W - w) / 2
		cv.draw_rect(Rect2(x - 2, 114, w + 4, 26), Color(10 / 255.0, 8 / 255.0, 6 / 255.0, 0.8))
		cv.draw_rect(Rect2(x, 128, w * maxf(0, e.hp / e.max), 9), c(B.col))
		label(B.name + (" · ENRAGED" if e.get("rage", false) else ""), v.W / 2, 125, c(B.col), 12)
		return


# ---------------------------------------------------------------- armory (20-locker-ui.js)

func _try_armory() -> void:
	var p: Dictionary = sim.player
	if not sim.shop_open(p):
		return
	if not sim.near_stake(p):
		toasts = [{"title": "ARMORY", "body": "Walk back to the stake to spend salvage.", "t": 3.0}]
		return
	armory_open = true
	sim.game.paused = not net.is_online()


func _close_armory() -> void:
	armory_open = false
	sim.game.paused = false


## keys and the controller in the armory and the skill tree: move between the rows (nearest one that way), buy
func _panel_nav(dir: String) -> void:
	var list: Array = arm_buttons if armory_open else sk_buttons
	if dir == "back":
		if armory_open:
			_close_armory()
		else:
			_close_skills()
		return
	if list.is_empty():
		return
	var sel := clampi(arm_sel if armory_open else sk_sel, 0, list.size() - 1)
	if dir == "accept":
		if armory_open:
			_arm_buy(list[sel][1])
		else:
			skill_buy(list[sel][1])
		return
	var cur_r: Rect2 = list[sel][0]
	var cc := cur_r.get_center()
	var dv: Vector2 = {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}.get(dir, Vector2.ZERO)
	var best := -1
	var bs := 1e9
	for i in list.size():
		if i == sel:
			continue
		var q: Vector2 = list[i][0].get_center() - cc
		var along := q.dot(dv)
		if along <= 2:
			continue
		var off := absf(q.dot(dv.orthogonal()))
		var sc := along + off * 2
		if sc < bs:
			bs = sc
			best = i
	if best >= 0:
		if armory_open:
			arm_sel = best
		else:
			sk_sel = best


func _armory_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		if e.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			_panel_nav({KEY_UP: "up", KEY_DOWN: "down", KEY_LEFT: "left", KEY_RIGHT: "right"}[e.keycode])
		elif e.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and not e.echo:
			_panel_nav("accept")
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_ESCAPE or e.is_action_pressed("pal_armory") or e.is_action_pressed("pal_pause"):
			_close_armory()
		elif e.keycode >= KEY_1 and e.keycode <= KEY_9:
			var n: int = e.keycode - KEY_1
			if n < arm_buttons.size():
				_arm_buy(arm_buttons[n][1])
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for b in arm_buttons:
			if b[0].has_point(e.position):
				_arm_buy(b[1])
				return
		if b_close.has_point(e.position):
			_close_armory()


var b_close := Rect2()


func _arm_buy(key: String) -> void:
	var p: Dictionary = sim.player
	var ok: bool
	if key == "close" or key.begins_with("tab:") or key.begins_with("slot:"):   # the armory's own buttons (ArmoryUI)
		menus.armory.press(key)
		return
	var am := key.substr(5).split(":")   # ammo:<id>[:<slot>]
	if net.guest():
		if key.begins_with("ammo:"):
			net.send_ammo(am[0], int(am[1]) if am.size() > 1 else 0)
		else:
			net.send_upgrade(key)
		return
	if key.begins_with("ammo:"):
		ok = sim.buy_ammo(p, am[0], int(am[1]) if am.size() > 1 else 0)
	else:
		ok = sim.buy_upgrade(p, key)
	if ok:
		audio.play("restock")
	else:
		audio.play("deny")


## armUpgradeSummary
func _arm_summary(k: String, lv: int) -> String:
	var n := mini(Sim.ARM_MAX, lv + 1)
	var pct := func(x: float) -> String: return str(snappedf(100.0 * x, 0.01))
	if k == "n":
		return "+5 stock · +40% blast" if lv >= Sim.ARM_MAX else "Next: +%d stock · +%s%% blast" % [mini(n, 4) + (1 if n >= 8 else 0), pct.call(Sim.arm_boost(n, 0.08, 0.02))]
	var steps := {"d": [0.2, 0.05, "Damage"], "r": [0.1, 0.025, "Cooldown"], "g": [0.12, 0.03, "Reach"], "a": [0.15, 0.0375, "HP"], "dell": [0.15, 0.0375, "Power"]}
	var st: Array = steps[k]
	var sign := "−" if k == "r" else "+"
	var out := "%s %s%s%%" % [st[2], sign, pct.call(Sim.arm_boost(lv, st[0], st[1]))]
	if lv < Sim.ARM_MAX:
		out += " → %s%s%%" % [sign, pct.call(Sim.arm_boost(n, st[0], st[1]))]
	return out


## the armory is drawn by ArmoryUI (armory_ui.gd) over the game; it keeps arm_buttons up to date for the keys and the
## controller
func _draw_armory() -> void:
	pass


func _ring(x: float, y: float, r: float, col: Color, w: float = 2.0) -> void:
	var q := iso(x, y)
	cv.draw_set_transform(q, 0, Vector2(1, 0.5))
	cv.draw_arc(Vector2.ZERO, v.TW2 * r, 0, TAU, 44, col, w * v.u)
	cv.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _disc(x: float, y: float, r: float, col: Color) -> void:
	var q := iso(x, y)
	oval(q.x, q.y, v.TW2 * r, v.TH2 * r, col)


func _lane(x0: float, y0: float, x1: float, y1: float, w: float, fill: Color, line: Color) -> void:
	var dx := x1 - x0
	var dy := y1 - y0
	var l := maxf(0.001, Vector2(dx, dy).length())
	var nx := -dy / l * w
	var ny := dx / l * w
	var P := PackedVector2Array([iso(x0 + nx, y0 + ny), iso(x1 + nx, y1 + ny), iso(x1 - nx, y1 - ny), iso(x0 - nx, y0 - ny)])
	cv.draw_colored_polygon(P, fill)
	P.append(P[0])
	cv.draw_polyline(P, line, 1.6 * v.u)


func _wedge(e: Dictionary, range_: float, half: float, fill: Color) -> void:
	var a0 := atan2(e.ly - e.y, e.lx - e.x)
	var pts := PackedVector2Array([iso(e.x, e.y)])
	for n in 11:
		var a := a0 + (n / 10.0 - 0.5) * half * 2
		pts.append(iso(e.x + cos(a) * range_, e.y + sin(a) * range_))
	cv.draw_colored_polygon(pts, fill)


## the warnings for the moves (drawBossMove), the Blitz variants, the Foreman, winter and the Destroyer
func _draw_new_fx(e: Dictionary, f: float, pulse: float, ch: float) -> bool:
	var st: int = e.st
	var M: Dictionary = Sim.MOVE
	var D: Dictionary = Sim.DEST
	match st:
		20:
			for p in Sim.strike_pts(e.x, e.y, e.lx, e.ly):
				_disc(p.x, p.y, M.strike.r, Color(127 / 255.0, 224 / 255.0, 1, 0.12 + 0.18 * pulse))
				_ring(p.x, p.y, M.strike.r * (1.3 - 0.3 * (1 - f)), Color(200 / 255.0, 245 / 255.0, 1, 0.6 + 0.35 * pulse))
		21:
			_disc(e.x, e.y, M.pulse.r * (1 - f), Color(127 / 255.0, 224 / 255.0, 1, 0.12 + 0.12 * pulse))
			_ring(e.x, e.y, M.pulse.r, Color(127 / 255.0, 224 / 255.0, 1, 0.55 + 0.4 * pulse), 2.2)
		22:
			_lane(e.x, e.y, e.lx, e.ly, M.cyclone.r, Color(191 / 255.0, 244 / 255.0, 1, 0.12 + 0.16 * pulse), Color(191 / 255.0, 244 / 255.0, 1, 0.55 + 0.35 * pulse))
		23:
			var cp := Sim.cyclone_pos(e, f)
			var q := iso(cp.x, cp.y)
			for n in 4:
				var r: float = (0.35 + n * 0.18) * M.cyclone.r
				var a: float = sim.game.time * 8 + n
				cv.draw_set_transform(Vector2(q.x, q.y - n * 6 * v.u), 0, Vector2(1, 0.5))
				cv.draw_arc(Vector2.ZERO, v.TW2 * r, a, a + 4.2, 20, Color(220 / 255.0, 248 / 255.0, 1, 0.75), 1.6 * v.u)
				cv.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		24:
			_disc(e.lx, e.ly, M.cage.r, Color(191 / 255.0, 244 / 255.0, 1, 0.08 + 0.14 * (1 - f)))
			var gap := atan2(e.ly - e.y, e.lx - e.x)
			for n in 14:
				var a := n * TAU / 14
				var da := fmod(absf(a - gap), TAU)
				if da > PI:
					da = TAU - da
				if da < 0.4:
					continue
				var bar := iso(e.lx + cos(a) * M.cage.r, e.ly + sin(a) * M.cage.r)
				cv.draw_line(bar, bar - Vector2(0, ch * (1.2 - f * 0.6)), Color(230 / 255.0, 250 / 255.0, 1, 0.6 + 0.35 * pulse), 2 * v.u)
		25:
			_wedge(e, M.flame.range, M.flame.half, Color(1, 140 / 255.0, 40 / 255.0, 0.16 + 0.2 * pulse))
		26:
			_wedge(e, M.flame.range * (0.85 + 0.15 * sin(sim.game.time * 30)), M.flame.half, Color(1, (120 + 60 * pulse) / 255.0, 40 / 255.0, 0.42))
		27:
			_ring(e.lx, e.ly, M.firering.r, Color(1, 110 / 255.0, 40 / 255.0, 0.5 + 0.4 * pulse), 2.2)
			for n in M.firering.n:
				var a: float = n * TAU / M.firering.n
				_ring(e.lx + cos(a) * M.firering.r, e.ly + sin(a) * M.firering.r, 0.7 * (1.2 - 0.2 * (1 - f)), Color(1, 150 / 255.0, 60 / 255.0, 0.45 + 0.4 * pulse), 1.4)
		28:
			_disc(e.x, e.y, M.slam.r, Color(1, 210 / 255.0, 58 / 255.0, 0.1 + 0.16 * pulse))
			_ring(e.x, e.y, M.slam.r * (1.15 - 0.15 * (1 - f)), Color(1, 210 / 255.0, 58 / 255.0, 0.6 + 0.35 * pulse), 2.4)
		29:
			var P: Array = sim.overdrive_pts(e.x, e.y, e.lx, e.ly)
			var shown := mini(3, floori((1 - f) * 3) + 1)
			var x0: float = e.x
			var y0: float = e.y
			for n in shown:
				_lane(x0, y0, P[n].x, P[n].y, 0.45, Color(1, 210 / 255.0, 58 / 255.0, 0.14 + 0.2 * pulse), Color(1, 220 / 255.0, 90 / 255.0, 0.6 + 0.3 * pulse))
				x0 = P[n].x
				y0 = P[n].y
		30:
			pass
		5:   # the Blue Butcher's arc lane
			_lane(e.x, e.y, e.lx, e.ly, 0.5, Color(58 / 255.0, 224 / 255.0, 224 / 255.0, 0.16 + 0.22 * pulse), Color(58 / 255.0, 224 / 255.0, 224 / 255.0, 0.6 + 0.3 * pulse))
		101:   # ice rupture
			var r := 3.4 if e.boss == "rime" else 2.3
			_disc(e.lx, e.ly, r, Color(120 / 255.0, 1, 220 / 255.0, 0.2 + 0.1 * pulse))
			_ring(e.lx, e.ly, r, c("#d2fff0"), 1.4)
			var lq := iso(e.lx, e.ly)
			label("ICE RUPTURE", lq.x, lq.y - v.WH, c("#d8fff3"), 12)
		102:
			cv.draw_dashed_line(iso(e.x, e.y), iso(e.lx, e.ly), c("#d5fff0"), 5 * v.u, 6 * v.u)
		40:
			for p in sim.rocket_pts(e.x, e.y, e.lx, e.ly):
				_disc(p.x, p.y, D.rockets.R * 0.8, Color(1, 60 / 255.0, 40 / 255.0, 0.1 + 0.15 * pulse))
				_ring(p.x, p.y, D.rockets.R * (1.2 - 0.2 * (1 - f)), Color(1, 70 / 255.0, 50 / 255.0, 0.6 + 0.35 * pulse))
		41, 42:
			var fe: Vector2 = sim.fire_end(e)
			_lane(e.x, e.y, fe.x, fe.y, D.fire.w, Color(1, 120 / 255.0, 40 / 255.0, (0.16 + 0.22 * pulse) if st == 41 else 0.35), Color(1, 150 / 255.0, 60 / 255.0, 0.6 + 0.3 * pulse))
		43:
			var dx: float = e.lx - e.x
			var dy: float = e.ly - e.y
			var l := maxf(0.001, Vector2(dx, dy).length())
			var q := iso(clampf(e.x + dx / l * 12, 0, sim.N), clampf(e.y + dy / l * 12, 0, sim.N))
			cv.draw_line(iso(e.x, e.y) - Vector2(0, ch), q - Vector2(0, ch), Color(127 / 255.0, 224 / 255.0, 1, (0.8 if f < 0.32 else 0.4 + 0.3 * pulse)), (2.6 if f < 0.32 else 1.4) * v.u)
		44:
			_disc(e.x, e.y, D.gas.r * (1 - f), Color(120 / 255.0, 200 / 255.0, 70 / 255.0, 0.14 + 0.1 * pulse))
			_ring(e.x, e.y, D.gas.r, Color(160 / 255.0, 240 / 255.0, 90 / 255.0, 0.55 + 0.35 * pulse), 2.2)
		45:
			_disc(e.lx, e.ly, D.mines.r, Color(1, 176 / 255.0, 58 / 255.0, 0.1 + 0.14 * pulse))
			_ring(e.lx, e.ly, D.mines.r, Color(1, 176 / 255.0, 58 / 255.0, 0.6 + 0.3 * pulse))
		46, 47:
			var col := Color(1, 106 / 255.0, 42 / 255.0, (0.85 + 0.15 * pulse) if st == 47 else (0.45 + 0.35 * pulse))
			_ring(e.lx, e.ly, D.orb.r, col, 2.6 if st == 47 else 1.8)
			_disc(e.lx, e.ly, D.orb.r * (1 - f if st == 47 else 0.3), Color(1, 106 / 255.0, 42 / 255.0, 0.18))
		_:
			var kb: String = Sim.boss_def(e.boss).get("base", e.boss)
			if e.boss == "arsonist" and st == 1:
				cv.draw_dashed_line(iso(e.x, e.y) - Vector2(0, ch), iso(e.lx, e.ly) - Vector2(0, ch), Color(1, 90 / 255.0, 26 / 255.0, 0.5 + 0.45 * pulse), 2 * v.u, 7 * v.u)
				for n in 4:
					var t := 0.5 + n * 0.18
					_ring(e.x + (e.lx - e.x) * t, e.y + (e.ly - e.y) * t, 1.0, Color(1, 90 / 255.0, 26 / 255.0, 0.55 + 0.35 * pulse), 1.6)
				return true
			if e.boss == "harbinger" and st == 1:
				_ring(e.lx, e.ly, 2.0, Color(1, 122 / 255.0, 58 / 255.0, 0.45 + 0.35 * pulse), 1.6)
				return true
			if (e.boss == "bulldozer" or e.boss == "whiteforeman") and st == 1:
				_lane(e.x, e.y, e.lx, e.ly, 0.5, Color(1, 210 / 255.0, 58 / 255.0, 0.16 + 0.22 * pulse), Color(1, 210 / 255.0, 58 / 255.0, 0.6 + 0.3 * pulse))
				return true
			if kb == "foreman" and e.boss == "foreman":
				if st == 1:
					_ring(e.lx, e.ly, 0.95 * (1.2 - f * 0.2), Color(1, 177 / 255.0, 58 / 255.0, 0.55 + 0.4 * pulse))
				elif st == 3:
					_lane(e.x, e.y, e.lx, e.ly, 0.5, Color(1, 150 / 255.0, 40 / 255.0, 0.16 + 0.22 * pulse), Color(1, 177 / 255.0, 58 / 255.0, 0.6 + 0.3 * pulse))
				elif st == 4:
					_ring(e.x, e.y, 1.4, Color(1, 70 / 255.0, 40 / 255.0, 0.6 + 0.4 * pulse), 2.4)
				return true
			return false
	return true


## the Foreman underground: a moving dust mound
func _draw_mound(e: Dictionary) -> void:
	var q := iso(e.x, e.y)
	var sw := (1.35 + sin(sim.game.time * 40) * 0.08) if e.st == 4 else 1.0
	oval(q.x, q.y, 14 * v.u * sw, 6 * v.u * sw, c("#4a4030"))
	oval(q.x, q.y - 3 * v.u, 10 * v.u * sw, 4.5 * v.u * sw, c("#6a5a44"))
	label(Sim.boss_def(e.boss).name, q.x, q.y - 22 * v.u, c(Sim.boss_def(e.boss).col), 11)


var dev_boss_i := 0


## developer only (F8 in editor/debug runs): the next boss in Sim.BOSS_LIST walks in now
func _dev_boss() -> void:
	var k: String = Sim.BOSS_LIST[dev_boss_i % Sim.BOSS_LIST.size()]
	dev_boss_i += 1
	if sim.game.phase == "build":
		sim.start_raid()
		sim.game.queue = []
	sim.spawn_boss(k)


# ---------------------------------------------------------------- skill tree (19b-social-lobby.js)

func _skills_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		if e.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			_panel_nav({KEY_UP: "up", KEY_DOWN: "down", KEY_LEFT: "left", KEY_RIGHT: "right"}[e.keycode])
		elif e.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and not e.echo:
			_panel_nav("accept")
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_ESCAPE or e.is_action_pressed("pal_skills") or e.is_action_pressed("pal_pause"):
			_close_skills()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for b in sk_buttons:
			if b[0].has_point(e.position):
				skill_buy(b[1])
				return
		if sk_reset.has_point(e.position):
			skill_respec()


## the skill tree is a menu page now (menu_pages.gd)
func _draw_skills() -> void:
	pass


# ---------------------------------------------------------------- terrain (06b-maps.js, 06d-elevation.js)

## groundCol: each map's ground, water and banks
func _ground_col(i: int, j: int, h: float) -> Color:
	var t: int = sim.terr[sim.idx(i, j)]
	if t == PalMaps.T_WATER or t == PalMaps.T_BRIDGE:
		return c("#1d3848") if h < 0.33 else (c("#1f3b4c") if h < 0.66 else c("#1b3544"))
	match sim.map_id:
		"river":
			if t == PalMaps.T_LOW:
				return c("#343423") if h < 0.5 else c("#2f3021")
			return c("#35402a") if h < 0.2 else (c("#303a26") if h < 0.75 else c("#2b3322"))
		"quarry":
			return c("#3b3731") if h < 0.2 else (c("#35312c") if h < 0.75 else c("#2f2b27"))
	return c("#3d3528") if h < 0.2 else (c("#352e23") if h < 0.75 else c("#2f291f"))


## which tiles are on screen this frame: the bounds of the screen's corners on the ground, with room for tall things
## standing below the bottom edge (buildings, the radio mast)
## a ground chunk paints at camera (0, 0); its parent follows the camera
func paint_chunk(ch: GroundChunk) -> void:
	var cx := v.cam_x
	var cy := v.cam_y
	v.cam_x = 0.0
	v.cam_y = 0.0
	cv = ch
	if ch.back and sim.casino():
		pass   # the casino is a room: nothing outside its walls
	elif ch.back:
		Scenery.paint_outside(self)
		for t in trees_back:
			Scenery.tree(self, t)
		if sim.map_id == "city":   # flat: its fence can go in behind the ground
			for q in sim.N:
				Scenery.edge(self, "n", q)
				Scenery.edge(self, "w", q)
	else:
		_paint_ground(ch.i0, mini(sim.N, ch.i0 + ch.n), ch.j0, mini(sim.N, ch.j0 + ch.n))
		if ch.n >= sim.N and sim.casino():
			CasinoView.walls(self)
		elif ch.n >= sim.N:   # the whole yard in one piece: the far fence and Frostpeak's props go over its ground
			for q in sim.N:
				Scenery.edge(self, "n", q)
				Scenery.edge(self, "w", q)
			if sim.is_frost():
				Scenery.frost_props(self)
	cv = self
	v.cam_x = cx
	v.cam_y = cy


## rebuild the ground chunks when the map, the zoom or the terrain changes; every frame they follow the camera
func _sync_ground() -> void:
	var key := "%s|%d|%.3f|%d|%d" % [sim.map_id, sim.N, v.S, sim.terr_log.size(), game_n]
	if key != ground_key:
		ground_key = key
		for ch in ground.get_children():
			ch.queue_free()
			ground.remove_child(ch)
		var n: int = 8 if sim.map_id == "city" else sim.N
		var list: Array = [[-1, -1]]
		for a in range(0, sim.N, n):
			for b in range(0, sim.N, n):
				list.append([a, b])
		list.sort_custom(func(x, y): return x[0] + x[1] < y[0] + y[1])   # back to front: a chunk's buildings only overhang the ones behind it
		for q in list:
			var ch := GroundChunk.new()
			ch.m = self
			ch.back = q[0] < 0
			ch.i0 = q[0]
			ch.j0 = q[1]
			ch.n = n
			ground.add_child(ch)
		_build_front()
	ground.position = Vector2(v.cam_x, v.cam_y)
	front_root.position = ground.position


## the near side: the south and east edges and the trees past them, in pieces along the edge so a fading tree only
## repaints its own piece
func _build_front() -> void:
	if sim.casino():   # four walls, no forest or fence in front
		trees_back = []
		trees_front = []
		for ch in front_root.get_children():
			ch.queue_free()
			front_root.remove_child(ch)
		front_groups.clear()
		return
	var forest := Scenery.gen_forest(sim)
	trees_back = forest[0]
	trees_front = forest[1]
	for ch in front_root.get_children():
		ch.queue_free()
		front_root.remove_child(ch)
	front_groups.clear()
	var N: int = sim.N
	var group := func(lat: float) -> Dictionary:
		var key := floori(lat / 6.0)
		if not front_groups.has(key):
			front_groups[key] = {"edges": [], "trees": [], "key": key}
		return front_groups[key]
	for q in N:
		group.call(q - N).edges.append(["s", q])
		group.call(N - q).edges.append(["e", q])
	for t in trees_front:
		group.call(t.x - t.y).trees.append(t)
	var keys := front_groups.keys()
	keys.sort()
	for key in keys:
		var G: Dictionary = front_groups[key]
		var node := PaintLayer.new()
		node.painter = _paint_front.bind(G)
		G.node = node
		front_root.add_child(node)


func _paint_front(layer: CanvasItem, G: Dictionary) -> void:
	var cx := v.cam_x
	var cy := v.cam_y
	v.cam_x = 0.0
	v.cam_y = 0.0
	cv = layer
	for e in G.edges:
		Scenery.edge(self, e[0], e[1])
	for t in G.trees:
		Scenery.tree(self, t)
	cv = self
	v.cam_x = cx
	v.cam_y = cy


## updateFades: a near tree goes see-through while anyone stands behind it
func _update_fades() -> void:
	var who: Array = sim.enemies.filter(func(e): return not e.dead)
	for pl in sim.players.values():
		if pl.alive or pl.downed:
			who.append(pl)
	if sim.qm.alive:
		who.append(sim.qm)
	for key in front_groups:
		var G: Dictionary = front_groups[key]
		var changed := false
		for t in G.trees:
			if t.kind >= 2:
				continue
			var td: float = t.x + t.y
			var tl: float = t.x - t.y
			var f := false
			for p in who:
				var dd: float = td - (p.x + p.y)
				if dd > 0 and dd < 5.5 and absf((p.x - p.y) - tl) < 1.6:
					f = true
					break
			var a := 0.32 if f else 1.0
			if t.a != a:
				t.a = a
				changed = true
		if changed and G.has("node"):
			G.node.queue_redraw()


## the time of day eases toward the raid's (overcast, golden hour, night); at night every light punches a hole
func _update_light(dt: float) -> void:
	var g: Dictionary = sim.game
	var tod := sim.tod_stage(g.wave if g.phase == "raid" else g.wave + 0.5)
	var T: Dictionary
	if tod == 2:
		T = {"L": 0.8 if sim.map_id == "city" and g.get("dark", false) else 0.7, "r": 5.0, "g": 8.0, "b": 22.0, "warm": 0.0}
	elif tod == 1:
		T = {"L": 0.2, "r": 60.0, "g": 30.0, "b": 10.0, "warm": 0.07}
	else:
		T = {"L": 0.12, "r": 28.0, "g": 34.0, "b": 44.0, "warm": 0.0}
	var k := minf(1.0, dt * 0.8)
	for key in T:
		light[key] += (T[key] - light[key]) * k
	var warm: float = light.warm
	var shade := Color((light.r + warm * 428) / 255.0, (light.g + warm * 214) / 255.0, light.b / 255.0, light.L + warm * 0.57)
	var holes := PackedVector4Array()
	if light.L > 0.25:
		var TW2 := v.TW2
		var WH := v.WH
		var hole := func(x: float, y: float, z: float, r: float, st: float) -> void:
			var cc := iso(x, y) - Vector2(0, z)
			if cc.x < -r or cc.x > v.W + r or cc.y < -r or cc.y > v.H + r or holes.size() >= 96:
				return
			holes.append(Vector4(cc.x, cc.y, r, minf(1.0, st)))
		for p in sim.players.values():
			if p.alive or p.downed:
				hole.call(p.x, p.y, WH * 0.5, TW2 * 3.4, 0.95)
		if sim.qm.alive:
			hole.call(sim.qm.x, sim.qm.y, WH * 0.5, TW2 * 1.8, 0.7)
		if sim.casino():
			CasinoView.lights(self, hole)
		if sim.map_id == "city":
			for co in sim.cores:
				if not co.has("poi"):
					hole.call(co.i + 0.5, co.j + 0.5, WH, TW2 * 4.4, 0.95)
					continue
				var st := 0.9 if co.poi.major else 0.8
				if co.lost:
					var d: float = g.time - co.get("lostAt", -9.0)
					if d > 1.6:
						continue
					st *= (1 - d / 1.6) * (1.0 if sin(d * 40) > 0 else 0.15)
				hole.call(co.i + 0.5, co.j + 0.5, WH, TW2 * (3.8 if co.poi.major else 3.0), st)
			if not g.get("dark", false):
				for l in sim.lay.lamps:
					hole.call(l[0] + 0.5 + l[2] * 0.7, l[1] + 0.5 + l[3] * 0.7, 0, TW2 * 3.5, 0.85)
		else:
			for co in sim.cores:
				hole.call(co.i + 0.5, co.j + 0.5, WH, TW2 * 3, 0.85)
		for e in sim.enemies:
			hole.call(e.x, e.y, WH * 0.5, TW2 * 0.9, 0.45)
		for j in range(vb[2], vb[3] + 1):
			for i in range(vb[0], vb[1] + 1):
				var w = sim.walls[j * sim.N + i]
				if w != null and w.get("fire", 0.0) > 0:
					hole.call(i + 0.5, j + 0.5, WH, TW2 * 2, 0.8)
				if sim.map_id == "quarry" and sim.terr[j * sim.N + i] == PalMaps.T_DRUM:
					hole.call(i + 0.5, j + 0.5, WH, TW2 * (2.6 + 0.12 * sin(g.time * 7 + j * sim.N + i)), 0.9)
		for n in sim.nodes:
			if n.type == 1 and not n.locked:
				hole.call(n.i + 0.5, n.j + 0.5, WH * 0.3, TW2 * 1.6, 0.6)
		for ch in sim.charges:
			hole.call(ch.x, ch.y, 0, TW2 * 0.7, 0.7)
		for f in flashes:
			hole.call(f.x, f.y, WH * 0.5, TW2 * (2.0 if f.muzzle else 4.5) * f.r * 0.6, f.life / f.max)
	var mat: ShaderMaterial = light_rect.material
	mat.set_shader_parameter("size", Vector2(v.W, v.H))
	mat.set_shader_parameter("shade", Vector4(shade.r, shade.g, shade.b, shade.a))
	mat.set_shader_parameter("count", holes.size())
	var arr: Array = []
	for h in holes:
		arr.append(h)
	while arr.size() < 96:
		arr.append(Vector4.ZERO)
	mat.set_shader_parameter("holes", arr)


const STORM_KIND := {"yard": "dust", "river": "rain", "quarry": "ash"}


func _update_post(dt: float) -> void:
	var g: Dictionary = sim.game
	wx_a += ((1.0 if g.get("wx", 0) and g.phase == "raid" else 0.0) - wx_a) * minf(1.0, dt * 1.5)
	var L: Dictionary = Sim.STORM.look.get(sim.map_id, Sim.STORM.look.yard)
	var kind: String = STORM_KIND.get(sim.map_id, "dust")
	var mat: ShaderMaterial = post_rect.material
	mat.set_shader_parameter("size", Vector2(v.W, v.H))
	mat.set_shader_parameter("storm", Vector4(L.col[0] / 255.0, L.col[1] / 255.0, L.col[2] / 255.0, (0.2 if kind == "rain" else 0.16) * wx_a) if wx_a > 0.01 else Vector4.ZERO)
	mat.set_shader_parameter("vig_c", Vector2(v.W * (0.4 if v.W < 760 else 0.5), v.H * 0.52))
	mat.set_shader_parameter("vig_r", Vector2(minf(v.W, v.H) * 0.25, maxf(v.W, v.H) * 0.8))
	var p: Dictionary = sim.player
	var low := 0.0
	if p.alive and p.hp / p.max < 0.3 and g.phase != "over":
		var kk: float = (0.3 - p.hp / p.max) / 0.3
		low = (0.18 + 0.12 * sin(g.time * 6)) * minf(1.0, kk * 1.6 + 0.3)
	mat.set_shader_parameter("low", low)


func _vis_bounds() -> void:
	var N: int = sim.N
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for q in [Vector2(0, 0), Vector2(v.W, 0), Vector2(0, v.H + v.WH * 4), Vector2(v.W, v.H + v.WH * 4)]:
		var w := v.screen_to_world(q.x, q.y)
		lo = Vector2(minf(lo.x, w.x), minf(lo.y, w.y))
		hi = Vector2(maxf(hi.x, w.x), maxf(hi.y, w.y))
	vb = [clampi(floori(lo.x) - 2, 0, N - 1), clampi(ceili(hi.x) + 2, 0, N - 1), clampi(floori(lo.y) - 2, 0, N - 1), clampi(ceili(hi.y) + 2, 0, N - 1)]


## the building tiles standing in front of anyone on screen: drawn again over them, at the right depth
func _city_occluders() -> Dictionary:
	var occ := {}
	var who: Array = sim.enemies.filter(func(e): return not e.dead)
	for pl in sim.players.values():
		if pl.alive or pl.downed:
			who.append(pl)
	if sim.qm.alive:
		who.append(sim.qm)
	who.append_array(sim.sacks)
	for e in who:
		var p := iso(e.x, e.y)
		if p.x < -60 or p.x > v.W + 60 or p.y < -80 or p.y > v.H + 80:
			continue
		var ci := floori(e.x)
		var cj := floori(e.y)
		for a in 4:
			for b in 4:
				var i := ci + a
				var j := cj + b
				if not sim.inb(i, j):
					continue
				var k := sim.idx(i, j)
				if sim.terr[k] != PalMaps.T_BLDG or occ.has(k):
					continue
				var dd: float = i + j + 1 - (e.x + e.y)
				var lat: float = (i - j) - (e.x - e.y)
				if dd > 0 and dd < 3.8 and absf(lat) < 1.8:
					occ[k] = true
	return occ


func _tile_on(i: int, j: int, m: float = 1.5) -> bool:
	var p := v.iso(i + 0.5, j + 0.5)
	return p.x > -v.TW2 * m and p.x < v.W + v.TW2 * m and p.y > -v.TH2 * m and p.y < v.H + v.WH * 4 + v.TH2 * m


## the ground of tiles [i0, i1) x [j0, j1); the whole map paints in one piece except the city
func _paint_ground(i0: int, i1: int, j0: int, j1: int) -> void:
	var N: int = sim.N
	var u := v.u
	if sim.casino():
		for j in range(j0, j1):
			for i in range(i0, i1):
				quad(v.iso(i, j), v.iso(i + 1, j), v.iso(i + 1, j + 1), v.iso(i, j + 1), CasinoView.ground_col(self, i, j, Pal.hash2(i, j)))
				CasinoView.ground_detail(self, i, j)
		return
	if sim.map_id == "city":
		for j in range(j0, j1):
			for i in range(i0, i1):
				quad(v.iso(i, j), v.iso(i + 1, j), v.iso(i + 1, j + 1), v.iso(i, j + 1), CityView.ground_col(self, i, j, Pal.hash2(i, j)))
				CityView.ground_detail(self, i, j)
		for d in range(i0 + j0, i1 + j1 - 1):   # its buildings, back to front (the ones in front of someone are drawn again over them)
			for i in range(maxi(i0, d - j1 + 1), mini(i1, d - j0 + 1)):
				if sim.terr[sim.idx(i, d - i)] == PalMaps.T_BLDG:
					CityView.building(self, i, d - i, true)
		return
	if sim.is_frost():
		for j in range(j0, j1):
			for i in range(i0, i1):
				_paint_frost_tile(i, j)
		return
	for i in range(i0, i1):
		for j in range(j0, j1):
			var h := Pal.hash2(i, j)
			quad(v.iso(i, j), v.iso(i + 1, j), v.iso(i + 1, j + 1), v.iso(i, j + 1), _ground_col(i, j, h))
			var t: int = sim.terr[sim.idx(i, j)]
			if t == PalMaps.T_WATER or t == PalMaps.T_BRIDGE:   # a soft bank line where water meets land
				for e in [[1, 0, [i + 1, j], [i + 1, j + 1]], [-1, 0, [i, j], [i, j + 1]], [0, 1, [i, j + 1], [i + 1, j + 1]], [0, -1, [i, j], [i + 1, j]]]:
					var nt := sim.t_at(i + e[0], j + e[1])
					if sim.inb(i + e[0], j + e[1]) and nt != PalMaps.T_WATER and nt != PalMaps.T_BRIDGE:
						cv.draw_line(v.iso(e[2][0], e[2][1]), v.iso(e[3][0], e[3][1]), Color(120 / 255.0, 150 / 255.0, 120 / 255.0, 0.25), 1.2 * u)
				continue
			if t == PalMaps.T_CRACK:
				var pts := PackedVector2Array()
				var p := Vector2(i + 0.2 + Pal.hash2(i, j + 3) * 0.2, j + 0.25 + Pal.hash2(i + 9, j) * 0.2)
				pts.append(v.iso(p.x, p.y))
				for s in 4:
					p += Vector2(0.14 + Pal.hash2(i + s, j * 3) * 0.1, 0.1 + Pal.hash2(i * 7, j + s) * 0.12)
					pts.append(v.iso(p.x, p.y))
				cv.draw_polyline(pts, Color(14 / 255.0, 11 / 255.0, 9 / 255.0, 0.7), 1.1 * u)
				cv.draw_line(v.iso(i + 0.5, j + 0.5), v.iso(i + 0.3, j + 0.8), Color(14 / 255.0, 11 / 255.0, 9 / 255.0, 0.7), 1.1 * u)
				cv.draw_polyline(pts, Color(1, 140 / 255.0, 60 / 255.0, 0.12), 0.8 * u)
				continue
			if sim.map_id == "quarry":
				if h > 0.8:
					var g := v.iso(i + 0.3 + h * 0.4, j + 0.5)
					oval(g.x, g.y, 2.4 * u, 1.2 * u, Color(150 / 255.0, 140 / 255.0, 120 / 255.0, 0.3))
			elif h > 0.86:
				var cc := v.iso(i + 0.5, j + 0.5)
				oval(cc.x + (h - 0.9) * 40 * u, cc.y, 6 * u, 2.5 * u, Color(84 / 255.0, 104 / 255.0, 64 / 255.0, 0.35))
	for s in N + 1:   # (the city has no grid: its roads and sidewalks are the grid)
		cv.draw_line(v.iso(s, 0), v.iso(s, N), Color(0, 0, 0, 0.22), 1.0)
		cv.draw_line(v.iso(0, s), v.iso(N, s), Color(0, 0, 0, 0.22), 1.0)


## paintFrostTile: a terrace top (snow), its south and east faces where it drops, and the treads of stairs and ramps
func _paint_frost_tile(i: int, j: int) -> void:
	var N: int = sim.N
	var u := v.u
	var k := sim.idx(i, j)
	var z: int = sim.heights[k]
	var r: int = sim.connectors[k]
	var h := Pal.hash2(i + 6, j + 31)
	var A := v.iso(i, j, z + (1 if r else 0))
	var B := v.iso(i + 1, j, z + (1 if r else 0))
	var C := v.iso(i + 1, j + 1, z)
	var D := v.iso(i, j + 1, z)
	var lowS: int = (sim.heights[k + N] + (1 if sim.connectors[k + N] != 0 else 0)) if j + 1 < N else 0
	var lowE: int = sim.heights[k + 1] if i + 1 < N else 0
	if z > lowS:
		quad(D, C, v.iso(i + 1, j + 1, lowS), v.iso(i, j + 1, lowS), c("#435b6a"))
	if z > lowE:
		quad(B, C, v.iso(i + 1, j + 1, lowE), v.iso(i + 1, j, lowE), c("#304858"))
	quad(A, B, C, D, c("#acc9d8") if r else (c("#dceaf0") if h > 0.55 else c("#c8dee8")))
	cv.draw_line(D, C, Color(68 / 255.0, 109 / 255.0, 134 / 255.0, 0.2), u)
	if r:
		var n := 5 if r == 2 else 2
		for q in range(1, n + 1):
			var t := float(q) / (n + 1)
			cv.draw_line(v.iso(i, j + t, z + 1 - t), v.iso(i + 1, j + t, z + 1 - t), c("#547b90") if r == 2 else c("#e7f5fa"), (2.0 if r == 2 else 1.0) * u)
	elif h > 0.83:
		var p := v.iso(i + 0.5, j + 0.5, z)
		cv.draw_rect(Rect2(p.x - 2 * u, p.y, 4 * u, u), Color(1, 1, 1, 0.55))


## a terrace's cliff face, depth-sorted so people behind the lip are hidden by it
func _draw_frost_cliff(k: int) -> void:
	var N: int = sim.N
	var u := v.u
	var i := k % N
	var j := k / N
	var z: int = sim.heights[k]
	var s: int = (sim.heights[k + N] + (1 if sim.connectors[k + N] != 0 else 0)) if j + 1 < N else 0
	var e: int = sim.heights[k + 1] if i + 1 < N else 0
	if z > s:
		quad(v.iso(i, j + 1, z), v.iso(i + 1, j + 1, z), v.iso(i + 1, j + 1, s), v.iso(i, j + 1, s), c("#435b6a"))
		cv.draw_line(v.iso(i + 0.2, j + 1, z), v.iso(i + 0.35, j + 1, s), c("#719aaa"), u)
		cv.draw_line(v.iso(i, j + 1, z) + Vector2(0, u), v.iso(i + 1, j + 1, z) + Vector2(0, u), c("#dcebf1"), 2 * u)
	if z > e:
		quad(v.iso(i + 1, j, z), v.iso(i + 1, j + 1, z), v.iso(i + 1, j + 1, e), v.iso(i + 1, j, e), c("#304858"))
		cv.draw_line(v.iso(i + 1, j, z) + Vector2(0, u), v.iso(i + 1, j + 1, z) + Vector2(0, u), c("#b9d0da"), 2 * u)


## drawTerrainLive: water glints drifting downstream, flooded banks, bridges, pits, ripples round anyone wading
func _draw_terrain_live() -> void:
	var N: int = sim.N
	var u := v.u
	var t0: float = sim.game.time
	if sim.map_id == "river":
		for k in N * N:
			if sim.terr[k] != PalMaps.T_WATER:
				continue
			var i := k % N
			var j := k / N
			var h := Pal.hash2(i + 31, j + 7)
			var y := j + fmod(t0 * 0.35 + h, 1.0)
			cv.draw_line(v.iso(i + 0.25 + h * 0.4, y), v.iso(i + 0.45 + h * 0.4, y), Color(150 / 255.0, 200 / 255.0, 220 / 255.0, 0.28), 1.2 * u)
		flood_lv += ((1.0 if sim.flood_on else 0.0) - flood_lv) * minf(1.0, get_process_delta_time() * 1.2)
		if flood_lv > 0.02:
			for k in N * N:
				if sim.terr[k] == PalMaps.T_LOW:
					var i := k % N
					var j := k / N
					quad(v.iso(i, j), v.iso(i + 1, j), v.iso(i + 1, j + 1), v.iso(i, j + 1), Color(c("#23475a"), flood_lv * 0.7))
		for k in N * N:
			if sim.terr[k] == PalMaps.T_BRIDGE:
				var i := k % N
				var j := k / N
				quad(v.iso(i, j + 0.08), v.iso(i + 1, j + 0.08), v.iso(i + 1, j + 0.92), v.iso(i, j + 0.92), c("#5a4330"))
				for s in range(1, 6):
					cv.draw_line(v.iso(i + s / 6.0, j + 0.08), v.iso(i + s / 6.0, j + 0.92), Color(20 / 255.0, 14 / 255.0, 8 / 255.0, 0.6), u)
				for yy in [j + 0.08, j + 0.92]:
					cv.draw_line(v.iso(i, yy) - Vector2(0, 3 * u), v.iso(i + 1, yy) - Vector2(0, 3 * u), c("#2c2016"), 2 * u)
	for k in sim.terr_log:
		if sim.terr[k] == PalMaps.T_PIT:
			var i: int = k % N
			var j: int = k / N
			var a := v.iso(i + 0.04, j + 0.04)
			var b := v.iso(i + 0.96, j + 0.04)
			var d := v.iso(i + 0.04, j + 0.96)
			quad(a, b, v.iso(i + 0.96, j + 0.96), d, c("#0b0908"))
			quad(a, b, b + Vector2(0, v.WH * 0.35), a + Vector2(0, v.WH * 0.35), c("#1c1713"))
			quad(a, d, d + Vector2(0, v.WH * 0.35), a + Vector2(0, v.WH * 0.35), c("#241d18"))
	if sim.map_id == "river":
		var wading: Array = sim.enemies.filter(func(e): return not e.get("burrow", false))
		for pl in sim.players.values():
			if pl.alive:
				wading.append(pl)
		if sim.qm.alive:
			wading.append(sim.qm)
		for e in wading:
			var tt := sim.t_at(floori(e.x), floori(e.y))
			if tt == PalMaps.T_WATER or (tt == PalMaps.T_LOW and sim.flood_on):
				var cc := iso(e.x, e.y)
				var r := (7 + sin(t0 * 6 + e.x * 3) * 1.5) * u
				cv.draw_set_transform(cc, 0, Vector2(1, 0.5))
				cv.draw_arc(Vector2.ZERO, r, 0, TAU, 24, Color(170 / 255.0, 210 / 255.0, 230 / 255.0, 0.45), u)
				cv.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


## rock outcrops and oil drums (terrShape): rock stands, a drum burns
func _draw_terr_item(i: int, j: int, t: int) -> void:
	var u := v.u
	var WH := v.WH
	var h := Pal.hash2(i + 3, j + 17)
	if t == PalMaps.T_ROCK:
		box_r(i + 0.08, j + 0.12, i + 0.9, j + 0.88, 0, WH * (0.75 + h * 0.3), c("#6b655b"), c("#4e4a43"), c("#3c3934"))
		box_r(i + 0.2 + h * 0.2, j + 0.2, i + 0.7 + h * 0.2, j + 0.62, WH * (0.75 + h * 0.3), WH * (0.25 + h * 0.2), c("#787166"), c("#58534b"), c("#45413b"))
		return
	var cc := iso(i + 0.5, j + 0.5)
	var w := v.TW2 * 0.34
	var hh := WH * 0.9
	oval(cc.x, cc.y, w * 1.2, w * 0.6, Color(0, 0, 0, 0.35))
	cv.draw_rect(Rect2(cc.x - w, cc.y - hh, w * 2, hh), c("#3b2f24"))
	cv.draw_rect(Rect2(cc.x - w * 0.35, cc.y - hh, w * 0.7, hh), c("#4d3d2e"))
	cv.draw_rect(Rect2(cc.x - w, cc.y - hh * 0.66, w * 2, 2 * u), c("#2a211a"))
	cv.draw_rect(Rect2(cc.x - w, cc.y - hh * 0.33, w * 2, 2 * u), c("#2a211a"))
	oval(cc.x, cc.y - hh, w, w * 0.45, c("#1a1411"))
	var t0: float = sim.game.time * 9 + h * 20
	for q in 3:   # the flame on top: three flickering tongues
		var fx := cc.x + (q - 1) * w * 0.45
		var fh := (9 + sin(t0 + q * 2.1) * 3 + (q % 2) * 2) * u
		cv.draw_colored_polygon(PackedVector2Array([Vector2(fx - w * 0.28, cc.y - hh), Vector2(fx + sin(t0 * 1.3 + q) * 2 * u, cc.y - hh - fh * 1.2), Vector2(fx + w * 0.28, cc.y - hh)]), c("#ffd070") if q == 1 else c("#ff8a2a"))


## the Ferryman's raft under him
func _draw_raft(e: Dictionary) -> void:
	var u := v.u
	var cc := iso(e.x, e.y)
	var bob := sin(sim.game.time * 2.2 + e.id) * 1.5 * u
	cv.draw_set_transform(Vector2(cc.x, cc.y + bob), 0, Vector2(1, 0.5))
	cv.draw_circle(Vector2.ZERO, 20 * u, Color(0, 0, 0, 0.3))
	cv.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	box_r(e.x - 0.55, e.y - 0.45, e.x + 0.55, e.y + 0.45, -2 * u + bob, 4 * u, c("#6a4c30"), c("#4f3822"), c("#3e2c1a"))
	for s in range(1, 4):
		cv.draw_line(iso(e.x - 0.55 + s * 0.275, e.y - 0.45) - Vector2(0, 2 * u - bob), iso(e.x - 0.55 + s * 0.275, e.y + 0.45) - Vector2(0, 2 * u - bob), c("#2c2016"), u)


var flood_lv := 0.0


## screenToWorld: the viewing ray against each terrace's plane and the connector slopes; the front-most ground wins
func _screen_to_world(sx: float, sy: float) -> Vector2:
	var a := (sx - v.cam_x) / v.TW2
	var best = null
	var hp := v.height_px()
	for z in 3:
		var b := (sy - v.cam_y + z * hp) / v.TH2
		var x := (a + b) / 2
		var y := (b - a) / 2
		if absf(sim.height_at(x, y) - z) < 0.00001 and sim.inb(floori(x), floori(y)) and (best == null or x + y > best.x + best.y):
			best = Vector2(x, y)
	if sim.is_frost():
		var N: int = sim.N
		for k in N * N:
			if sim.connectors[k] != 0:
				var j := k / N
				var y := (sy - v.cam_y - a * v.TH2 + hp * (sim.heights[k] + 1 + j)) / (2 * v.TH2 + hp)
				var x := y + a
				if floori(x) == k % N and floori(y) == j and (best == null or x + y > best.x + best.y):
					best = Vector2(x, y)
	if best != null:
		return best
	return v.screen_to_world(sx, sy)


## bodyUnder: a cursor on a drawn raider (feet to helmet) aims at that raider's feet
func _body_under(sx: float, sy: float):
	var best = null
	var by := -1e9
	for e in sim.enemies:
		if e.dead or e.get("burrow", false):
			continue
		var p := iso(e.x, e.y)
		var k := v.u * FIG * (1.45 if e.get("big", false) else 1.0)
		if absf(sx - p.x) <= 9 * k and sy <= p.y + 4 * k and sy >= p.y - 37 * k and p.y > by:
			by = p.y
			best = Vector2(e.x, e.y)
	return best


# ---------------------------------------------------------------- cosmetics in play (20-locker-ui.js, 07-effects.js)

## the soldier wears what the locker has equipped: tracer, its sound and colour cycle, and kill effect (read by the sim)
func _dress(p: Dictionary) -> void:
	if locker == null or demo:
		return
	var eq: Dictionary = locker.eq if p.id == sim.player.id else PalLocker.parse_cos(p.get("cosS", ""))
	var tr: String = eq.get("trail", "std")
	if p.get("trail", "") != tr:
		var st := CosArt.trail(tr)
		p.trail = tr
		p.tsnd = st.get("snd", "")
		p.tcyc = st.get("cycle", []).size()
		p.tcn = 0
	p.kfx = eq.get("fx", "none")


## emit: one particle of a kind, as the browser makes it (z, vz and gravity in base units, positions in tiles)
func cemit(x: float, y: float, z: float, kind: String, thin: float = 1.0) -> Dictionary:
	if thin < 1 and randf() > thin and not kind.begins_with("finish:"):
		return {}
	var R := func() -> float: return randf()
	var p := {"x": x, "y": y, "z": z, "vx": (randf() - 0.5) * 2, "vy": (randf() - 0.5) * 2, "vz": randf() * 60, "life": 0.5, "max": 0.5, "kind": kind,
		"size": 2.0, "col": "#ffffff", "grav": 220.0}
	var pick := func(a: Array) -> String: return a[randi() % a.size()]
	if kind.begins_with("finish:"):
		p.vx = 0.0
		p.vy = 0.0
		p.vz = 0.0
		p.grav = 0.0
		p.life = CosArt.life(kind.substr(7))
		p.max = p.life
		var fin := cparts.filter(func(q): return q.kind.begins_with("finish:"))
		if fin.size() >= 24:
			cparts.erase(fin[0])
	match kind:
		"snowdust":
			p.merge({"col": "#e2f5fa", "vx": p.vx * 0.12, "vy": p.vy * 0.12, "vz": 3.0, "grav": 0.0, "life": 0.32, "max": 0.32, "size": 1.4}, true)
		"yulelight":
			p.merge({"col": "#ffe09a", "vx": p.vx * 0.1, "vy": p.vy * 0.1, "vz": 0.0, "grav": 15.0, "life": 0.38, "max": 0.38, "size": 2.0}, true)
		"flagmote":
			p.merge({"vx": p.vx * 0.15, "vy": p.vy * 0.15, "vz": 4.0, "grav": 0.0, "life": 0.3, "max": 0.3, "size": 1.5}, true)
		"spark":
			p.merge({"col": pick.call(["#ffe39a", "#ffb14a"]), "vx": p.vx * 3, "vy": p.vy * 3, "vz": 40 + R.call() * 90, "life": 0.3, "max": 0.3, "size": 1.6}, true)
		"fire":
			var l: float = 0.5 + R.call() * 0.3
			p.merge({"col": pick.call(["#ffcf6a", "#e8662d"]), "vx": p.vx * 2.4, "vy": p.vy * 2.4, "vz": 30 + R.call() * 120, "grav": 60.0, "life": l, "max": l, "size": 3.5}, true)
		"flame":
			var l: float = 0.5 + R.call() * 0.3
			p.merge({"col": pick.call(["#ffb347", "#e8552a"]), "vx": p.vx * 0.3, "vy": p.vy * 0.3, "vz": 25 + R.call() * 25, "grav": -30.0, "life": l, "max": l, "size": 3.0}, true)
		"smoke":
			var l: float = 1.4 + R.call()
			p.merge({"col": "#3c3832", "vx": p.vx * 0.5, "vy": p.vy * 0.5, "vz": 15 + R.call() * 15, "grav": -12.0, "life": l, "max": l, "size": 9.0}, true)
		"confetti":
			p.merge({"col": pick.call(["#ff5a8a", "#ffd24a", "#5ad8ff", "#8aff6a", "#c78aff"]), "vx": p.vx * 1.8, "vy": p.vy * 1.8, "vz": 70 + R.call() * 80, "grav": 110.0, "life": 1.1, "max": 1.1, "size": 2.6}, true)
		"ember":
			var l: float = 0.9 + R.call() * 0.4
			p.merge({"col": pick.call(["#ff8a3a", "#ffd06a"]), "vx": p.vx * 0.8, "vy": p.vy * 0.8, "vz": 20 + R.call() * 30, "grav": -25.0, "life": l, "max": l, "size": 2.0}, true)
		"bolt":
			p.merge({"col": pick.call(["#e8f6ff", "#8fd4ff"]), "vx": (R.call() - 0.5) * 0.3, "vy": (R.call() - 0.5) * 0.3, "vz": 0.0, "grav": 0.0, "life": 0.32, "max": 0.32, "size": 3.2}, true)
		"glint":
			p.merge({"col": pick.call(["#bfe9ff", "#ffffff"]), "vx": p.vx * 3.2, "vy": p.vy * 3.2, "vz": 60 + R.call() * 90, "life": 0.4, "max": 0.4, "size": 1.8}, true)
		"rune":
			var l: float = 0.75 + R.call() * 0.2
			p.merge({"col": "#ffb040", "vx": p.vx * 0.25, "vy": p.vy * 0.25, "vz": 4 + R.call() * 8, "grav": -6.0, "life": l, "max": l, "size": 2.6, "h": R.call() * 6.28}, true)
		"tealdust":
			var l: float = 0.4 + R.call() * 0.12
			p.merge({"col": pick.call(["#5af0ff", "#b8fbff"]), "vx": p.vx * 0.35, "vy": p.vy * 0.35, "vz": 6 + R.call() * 14, "grav": -12.0, "life": l, "max": l, "size": 2.6}, true)
		"star":
			var l: float = 0.55 + R.call() * 0.3
			p.merge({"col": "#fffbe8" if R.call() < 0.6 else "#ffe9a0", "vx": p.vx * 0.4, "vy": p.vy * 0.4, "vz": 8 + R.call() * 10, "grav": 0.0, "life": l, "max": l, "size": 2.0}, true)
		"cosmic":
			p.merge({"col": pick.call(["#c07aff", "#6a8aff", "#ff8ad8", "#ffffff"]), "vx": p.vx * 0.5, "vy": p.vy * 0.5, "vz": 4 + R.call() * 10, "grav": -6.0, "life": 0.7, "max": 0.7, "size": 1.8}, true)
		"rock":
			p.merge({"col": pick.call(["#8a7e70", "#6a5e52"]), "vx": p.vx * 1.2, "vy": p.vy * 1.2, "vz": 18 + R.call() * 20, "grav": 160.0, "life": 0.6, "max": 0.6, "size": 2.4}, true)
		"goldsp":
			p.merge({"col": pick.call(["#ffe066", "#fff6c8", "#ffd24a"]), "vx": p.vx * 1.4, "vy": p.vy * 1.4, "vz": 25 + R.call() * 40, "grav": 45.0, "life": 0.7, "max": 0.7, "size": 2.0}, true)
		"pix":
			p.merge({"col": pick.call(["#ff3a6a", "#3affd8", "#ffe03a", "#6a8aff"]), "vx": p.vx * 2.2, "vy": p.vy * 2.2, "vz": 60 + R.call() * 70, "grav": 190.0, "life": 0.8, "max": 0.8, "size": 3.4}, true)
		"ice":
			p.merge({"col": pick.call(["#f2fbff", "#9fd8f0"]), "vx": p.vx * 2.6, "vy": p.vy * 2.6, "vz": 40 + R.call() * 70, "grav": 210.0, "life": 0.6, "max": 0.6, "size": 2.2}, true)
		"grad1", "grad2":
			p.merge({"c1": "#e0a0ff" if kind == "grad1" else "#ff5ad8", "c2": "#3a6aff" if kind == "grad1" else "#ffb03a", "vx": p.vx * 2.4, "vy": p.vy * 2.4, "vz": 40 + R.call() * 70, "grav": 80.0, "life": 0.95, "max": 0.95, "size": 3.0}, true)
		"toxic":
			p.merge({"col": pick.call(["#b6ff3a", "#7adf2a"]), "vx": p.vx * 1.6, "vy": p.vy * 1.6, "vz": 50 + R.call() * 50, "grav": 230.0, "life": 0.8, "max": 0.8, "size": 3.0}, true)
		"nova":
			p.merge({"c1": "#ffffff", "c2": "#6a8aff", "vx": p.vx * 3.6, "vy": p.vy * 3.6, "vz": 15 + R.call() * 50, "grav": 0.0, "life": 0.75, "max": 0.75, "size": 2.4}, true)
		"glitch":
			var l: float = 0.25 + R.call() * 0.25
			p.merge({"col": pick.call(["#ff3a6a", "#3affd8", "#6a8aff", "#ffffff"]), "vx": p.vx * 1.2, "vy": p.vy * 1.2, "vz": 10 + R.call() * 40, "grav": 0.0, "life": l, "max": l, "size": 3 + R.call() * 4}, true)
		"void":
			var an: float = R.call() * 6.283
			var r: float = 0.5 + R.call() * 0.45
			p.merge({"x": x + cos(an) * r, "y": y + sin(an) * r, "vx": -cos(an) * r * 3.2, "vy": -sin(an) * r * 3.2, "vz": 0.0, "grav": 0.0, "col": pick.call(["#b06aff", "#3a1060"]), "life": 0.42, "max": 0.42, "size": 2.4}, true)
		"neon":
			p.merge({"col": pick.call(["#2af5ff", "#ff3ad0"]), "vx": p.vx * 3, "vy": p.vy * 3, "vz": 30 + R.call() * 50, "grav": 60.0, "life": 0.6, "max": 0.6, "size": 2.2}, true)
		"bubble":
			var l: float = 1.2 + R.call() * 0.7
			p.merge({"vx": p.vx * 0.55, "vy": p.vy * 0.55, "vz": 15 + R.call() * 35, "grav": -38.0, "life": l, "max": l, "size": 2.4 + R.call() * 4.2, "h": R.call() * 360}, true)
		"heal":
			p.merge({"col": pick.call(["#8fe0a0", "#e8fff0"]), "vx": p.vx * 0.6, "vy": p.vy * 0.6, "vz": 30 + R.call() * 30, "grav": -40.0, "life": 0.8, "max": 0.8, "size": 2.4}, true)
		"gflame":
			var l: float = 0.5 + R.call() * 0.3
			p.merge({"col": pick.call(["#b8ff8a", "#2ae86a"]), "vx": p.vx * 0.3, "vy": p.vy * 0.3, "vz": 25 + R.call() * 25, "grav": -30.0, "life": l, "max": l, "size": 3.0}, true)
		"bat":
			var l: float = 1 + R.call() * 0.5
			p.merge({"vx": p.vx * 1.6, "vy": p.vy * 1.6, "vz": 45 + R.call() * 45, "grav": -15.0, "life": l, "max": l, "size": 5 + R.call() * 2.2, "h": R.call() * 9}, true)
		"spider":
			var wh: float = v.WH / v.u
			p.merge({"vx": 0.0, "vy": 0.0, "z": wh * 2.6, "vz": -wh * 3.2, "grav": 0.0, "life": 1.6, "max": 1.6, "size": 7.0, "h": R.call() * 9, "floor": wh * 0.25}, true)
		"soul":
			var l: float = 1.5 + R.call() * 0.5
			p.merge({"vx": p.vx * 0.35, "vy": p.vy * 0.35, "vz": 26 + R.call() * 18, "grav": -4.0, "life": l, "max": l, "size": 6.5 + R.call() * 2, "h": R.call() * 9}, true)
	cparts.append(p)
	if cparts.size() > 600:
		cparts = cparts.slice(cparts.size() - 600)
	return p


## killFx: a kill effect where a raider dropped (its sound, the painted finisher, its particles, rings and flashes)
func kill_fx(x: float, y: float, id: String, quiet: bool = false) -> void:
	if id == "" or id == "none":
		return
	if not quiet:
		audio.play("kx_" + id, x, y)
	var thin := 0.3 if cparts.size() > 480 else (0.6 if cparts.size() > 320 else 1.0)
	var wh: float = v.WH / v.u
	if id != "skull" and CosArt.life(id) > 0:
		cemit(x, y, wh * 0.6, "finish:" + id)
	var E := func(n: int, k: String, z: float = 0.6) -> void:
		for i in ceili(n * 0.65):
			cemit(x, y, wh * z, k, thin)
	var ring := func(r0: float, r1: float, life: float, c1: String, c2: String, w: float) -> void:
		rings.append({"x": x, "y": y, "r0": r0, "r1": r1, "life": life, "max": life, "c1": c1, "c2": c2, "w": w})
	var flash := func(life: float, r: float) -> void:
		flashes.append({"x": x, "y": y, "life": life, "max": life, "r": r, "muzzle": false})
	match id:
		"pixel":
			E.call(14, "pix")
		"frost":
			E.call(12, "ice")
			ring.call(0, 0.8, 0.35, "#ffffff", "#9fd8f0", 1.6)
		"gradburst":
			E.call(16, "grad1")
			ring.call(0, 1.1, 0.5, "#e0a0ff", "#3a6aff", 2)
		"sunburst":
			E.call(16, "grad2")
			ring.call(0, 1.1, 0.5, "#ff5ad8", "#ffb03a", 2)
		"toxic":
			E.call(12, "toxic", 0.5)
			ring.call(0, 0.7, 0.45, "#b6ff3a", "#3a6a10", 2.4)
		"supernova":
			E.call(18, "nova")
			E.call(8, "star", 0.8)
			ring.call(0, 1.7, 0.6, "#ffffff", "#6a8aff", 2.6)
			flash.call(0.25, 1.2)
		"glitchout":
			E.call(16, "glitch")
		"singularity":
			E.call(18, "void")
			ring.call(1.3, 0, 0.42, "#b06aff", "#1a0630", 2.4)
			E.call(8, "nova", 0.6)
		"shockwave":
			E.call(12, "neon")
			ring.call(0, 1.8, 0.55, "#2af5ff", "#1a4aff", 2.4)
			ring.call(0, 1.2, 0.45, "#ff3ad0", "#6a1aff", 2)
		"bubbles":
			for i in 12:
				cemit(x + (randf() - 0.5) * 0.4, y + (randf() - 0.5) * 0.4, wh * (0.3 + 0.6 * randf()), "bubble", thin)
			E.call(12, "goldsp", 0.7)
			E.call(6, "glint", 0.7)
			ring.call(0, 1.5, 0.6, "#fff6c8", "#e2b436", 2.6)
			ring.call(0, 0.9, 0.4, "#ffffff", "#ffd24a", 1.6)
			flash.call(0.22, 1.1)
		"sparks":
			for n in 10:
				cemit(x, y, wh * 0.6, "spark", thin)
		"smoke":
			for n in 5:
				cemit(x, y, wh * 0.4, "smoke", thin)
		"confetti":
			for n in 16:
				cemit(x, y, wh * 0.8, "confetti", thin)
		"embers":
			for n in 12:
				cemit(x, y, wh * 0.4, "ember", thin)
		"glint":
			for n in 10:
				cemit(x, y, wh * 0.6, "glint", thin)
		"bolt":
			for n in 9:
				cemit(x + (randf() - 0.5) * 0.15, y + (randf() - 0.5) * 0.15, wh * (0.2 + n * 0.3), "bolt", thin)
			flash.call(0.22, 1.1)
		"skull":
			floats.append({"x": x, "y": y, "text": "☠", "col": Color.html("#efe6d2"), "t": 1.4})
			for n in 6:
				cemit(x, y, wh * 0.6, "spark", thin)
		"bats":
			E.call(11, "bat", 0.55)
			E.call(3, "smoke", 0.3)
		"hellportal":
			E.call(10, "ember", 0.3)
			E.call(4, "smoke", 0.25)
			ring.call(0, 1.1, 0.5, "#ffb040", "#7a0c06", 2.4)
			ring.call(1.2, 0, 0.9, "#ff3a0a", "#1a0204", 2)
		"cinder":
			E.call(12, "ember", 0.5)
			E.call(3, "smoke", 0.4)
		"orbital":
			flash.call(0.3, 2)
			ring.call(0, 1.4, 0.5, "#ffffff", "#ff6a2a", 3)
			E.call(10, "spark", 0.5)
			E.call(4, "smoke", 0.3)
		"tealslash":
			E.call(12, "tealdust", 0.6)
		"ashbrand":
			E.call(6, "ember", 0.3)
			E.call(5, "smoke", 0.3)
			ring.call(0, 0.9, 0.45, "#ffd070", "#5a1a0a", 1.8)
		"demonclaw":
			E.call(8, "ember", 0.4)
			ring.call(1, 0, 0.6, "#c8102e", "#1a0204", 2.2)
			shake = maxf(shake, 3 * settings.data.shake)
		"spider":
			E.call(1, "spider", 0)
			ring.call(0, 0.75, 0.7, "#f0f0f8", "#8a8aa0", 1.1)
			ring.call(0, 0.45, 0.55, "#f0f0f8", "#8a8aa0", 0.8)
		"souls":
			E.call(4, "soul", 0.35)
			E.call(10, "gflame", 0.25)
			ring.call(0, 1.3, 0.7, "#c8ffe0", "#1ee860", 2.2)
			flash.call(0.2, 0.9)
		"rocketburst":
			E.call(10, "fire", 0.5)
			E.call(5, "smoke", 0.5)
			ring.call(0, 1.3, 0.5, "#ffd070", "#ff6a1a", 2.4)
			flash.call(0.2, 1)
		"reticle":
			E.call(6, "glint", 0.7)
			ring.call(1.1, 0, 0.4, "#ff6a6a", "#ff2a2a", 1.6)
		"frag":
			E.call(10, "rock", 0.5)
			E.call(8, "spark")
			ring.call(0, 1.2, 0.45, "#fff0c0", "#8a8680", 2)
			flash.call(0.16, 0.8)
		"salvage":
			E.call(10, "rock", 0.6)
			E.call(6, "heal", 0.5)


## a tracer that sheds motes (st.pk) leaves one now and then at its tail, every 80 ms at most
func _shed(b: Dictionary, a: Vector2, tail: Vector2) -> void:
	var st := CosArt.trail(b.get("tr", "std"))
	var pk: String = st.get("pk", "")
	if pk == "" or sim.game.time < b.get("nextTrailFx", 0.0) or cparts.size() >= 520:
		return
	b.nextTrailFx = sim.game.time + (0.16 if settings.data.fpsMode == "30" else 0.08)
	if randf() >= st.get("pr", 0.0):
		return
	var g := iso(b.x, b.y)
	var f := 0.5   # partway back along the visible streak
	var q := cemit(b.x - b.vx * 0.018 * f, b.y - b.vy * 0.018 * f, (g.y - a.lerp(tail, f).y) / v.u, pk)
	if q.is_empty():
		return
	var cyc: Array = st.get("cycle", [])
	if not cyc.is_empty():
		q.col = cyc[b.get("tc", 0) % cyc.size()]
	if pk == "yulelight":
		var n: int = b.get("trailLightNext", 0)
		q.col = ["#ef5462", "#65c780", "#ffe09a", "#a6e8ff"][n % 4]
		b.trailLightNext = n + 1


## the cosmetic particles and the painted kill finishers, at their place in the world
func _draw_cparts() -> void:
	if cparts.is_empty():
		return
	var x := Ctx2D.new(cv)
	var u := v.u
	var t: float = sim.game.time
	for q in cparts:
		var g := iso(q.x, q.y)
		if q.kind.begins_with("finish:"):
			if v3 == null:   # in 3D the kill effect's model is the finisher
				CosArt.paint_finish(x, q.kind.substr(7), 1.0 - q.life / q.max, u, g.x, g.y - q.z * u)
			continue
		if q.kind == "spider":
			q.top = g.y - v.WH * 2.6
		var py: float = g.y - q.z * u
		if CosArt.paint_particle(x, q, g.x, py, u, t):
			continue
		var a: float = clampf(q.life / q.max, 0, 1)
		if q.kind == "smoke":
			cv.draw_circle(Vector2(g.x, py), q.size * u * (1.6 - a * 0.6), Color(CosFx.col(q.col), a * 0.5))
		else:
			var col := CosFx.col(q.col)
			col.a *= minf(1, a * 1.5)
			cv.draw_rect(Rect2(g.x - q.size * u / 2, py - q.size * u / 2, q.size * u, q.size * u), col)
