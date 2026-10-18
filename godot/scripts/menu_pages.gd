class_name MenuPages
extends RefCounted
## The menu pages that are cards and lists, built into the Menus shell: SETTINGS (page.html #pg-settings, 08b-pad.js
## renderPadSet, and a KEYBOARD card for this game's key bindings), the save backup (#saveOv), ACCOUNT
## (19-accounts.js renderAcct), INDEX (19e-index.js), SKILLS (01b-mods-skills.js renderSkills) and TABLES
## (21b-tables.js, the casino's front door).

var mn   # the Menus
var m    # the main node
var _ov: Control   # the save backup overlay
var _sk_sure := -10.0   # RESET TREE asks twice
var _sk_msg := ""


func _init(menus) -> void:
	mn = menus
	m = menus.m


func _l(text: String, f: String, size: float, col: Color, em: float = 0.0, lh: float = 0.0, wrap: bool = false) -> Label:
	return UiKit.lbl(text, f, size, col, em, lh, wrap)


## .setCard: a titled card; returns [card, its column]
func _card(title: String, gap: float = 10.0) -> Array:
	var p := UiKit.panel(UiKit.PANEL, UiKit.PLINE, 1, 16)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(gap)
	if title != "":
		v.add_child(_l(title, "s8", 14, UiKit.WARN, 0.16))
	p.add_child(v)
	return [p, v]


func _set_label(text: String) -> Label:
	return _l(text, "s8", 13, UiKit.DIM, 0.16)


func _in_game() -> bool:
	return not m.demo


## the page frame: the card shell from the menu, or an overlay card over the game
func _frame(name: String, redo: Callable, in_game_title: String) -> VBoxContainer:
	mn._begin(name, redo)
	if _in_game():
		var col: VBoxContainer = mn._overlay(720)
		col.add_child(_l(in_game_title, "s8", 13, UiKit.OWARN, 0.22))
		return col
	var body: VBoxContainer = mn._shell("card")
	return body


# ---------------------------------------------------------------- SETTINGS

func show_settings() -> void:
	var D: Dictionary = m.settings.data
	var body := _frame("settings", show_settings, "SETTINGS · IN GAME")
	var ig := _in_game()
	if ig:
		body.add_child(_l("The game is paused." if not m.net.is_online() else "The raid keeps going for everyone else while you change settings.", "m4", 12, UiKit.ODIM, 0.0, 1.5, true))
	else:
		body.add_child(mn._pt("SETTINGS", 28))
	var cols := UiKit.hbox(12)
	body.add_child(cols)
	var c1 := UiKit.vbox(12)
	var c2 := UiKit.vbox(12)
	var c3 := UiKit.vbox(12)
	for c in [c1, c2] + ([] if ig else [c3]):
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(c)
	if ig:
		c3 = c2
	# SOUND
	var snd := _card("SOUND")
	snd[1].add_child(_slider("MASTER VOLUME", D.volume, 0, 1, func(x): D.volume = x, "vol"))
	snd[1].add_child(_slider("MUSIC", D.music, 0, 1, func(x): D.music = x, "mus"))
	c1.add_child(snd[0])
	# SCREEN
	var scr := _card("SCREEN")
	scr[1].add_child(_slider("SCREEN SHAKE", D.shake, 0, 1, func(x): D.shake = x, "shake"))
	scr[1].add_child(_slider("ZOOM", D.zoom, 0.7, 1.4, func(x): D.zoom = x, "zoom"))
	scr[1].add_child(_set_label("MESSAGE TIME"))
	var mt := UiKit.seg([["1", "NORMAL"], ["1.5", "LONG"], ["2", "VERY LONG"]], str(D.msgTime).trim_suffix(".0"), func(id):
		D.msgTime = float(id)
		_apply()
		show_settings()
		mn._refocus("msg:" + {"1": "NORMAL", "1.5": "LONG", "2": "VERY LONG"}[id]), {"size": 15, "h": 40})
	mn._tag_seg(mt, "msg")
	scr[1].add_child(mt)
	scr[1].add_child(_set_label("FRAME RATE"))
	var fr := UiKit.seg([["auto", "AUTO"], ["30", "30 FPS"], ["60", "60 FPS"]], D.fpsMode, func(id):
		D.fpsMode = id
		_apply()
		show_settings()
		mn._refocus("fps:" + {"auto": "AUTO", "30": "30 FPS", "60": "60 FPS"}[id]), {"size": 15, "h": 40})
	mn._tag_seg(fr, "fps")
	scr[1].add_child(fr)
	scr[1].add_child(_l("Auto follows your display. 30 FPS keeps laptops coolest.", "m4", 11, UiKit.DIM, 0.0, 1.55, true))
	scr[1].add_child(_tog("Show frame rate", D.fps, func(on): D.fps = on))
	scr[1].add_child(_tog("Show tips during games", D.tips, func(on): D.tips = on))
	c1.add_child(scr[0])
	# FEEL
	var feel := _card("FEEL")
	feel[1].add_child(_tog("Vibration and controller rumble on hits and blasts", D.haptics, func(on): D.haptics = on))
	c2.add_child(feel[0])
	# CONTROLLER
	c2.add_child(_pad_card())
	# SAVE BACKUP (not mid-run: importing a save mid-run makes no sense)
	if not ig:
		var sv := _card("SAVE BACKUP")
		sv[1].add_child(_l("Your locker is saved on this computer and stays through game updates. Export a backup to move it to another device or the browser game, or to restore it if this computer's data is cleared.", "m4", 11, UiKit.DIM, 0.0, 1.55, true))
		var sr := UiKit.hbox(8)
		sr.add_child(UiKit.expand(mn._fid(UiKit.btn("EXPORT SAVE", "ghost", 16, func(): show_backup("export"), {"h": 46}), "save:export")))
		sr.add_child(UiKit.expand(mn._fid(UiKit.btn("IMPORT SAVE", "ghost", 16, func(): show_backup("import"), {"h": 46}), "save:import")))
		sv[1].add_child(sr)
		c3.add_child(sv[0])
	# WINDOW: this game's own display settings
	c3.add_child(_window_card(D))
	# KEYBOARD
	c3.add_child(_key_card())
	if ig:
		var b := UiKit.btn("BACK TO THE PAUSE MENU", "ogo", 22, func(): mn.show_pause(), {"h": 56})
		mn._focus = b
		body.add_child(mn._fid(b, "set:done"))
	else:
		var row := UiKit.hbox(0)
		var b := UiKit.btn("DONE", "go", 22, func(): mn.back(), {"h": 56, "w": 220})
		row.add_child(mn._fid(b, "set:done"))
		body.add_child(UiKit.spacer(8))
		body.add_child(row)
	mn._settle()


## the display (PC only, kept out of the save backup): the window's mode and size, VSync and the frame limit
func _window_card(D: Dictionary) -> Control:
	var win := _card("WINDOW")
	var full: bool = D.windowMode != "windowed"
	win[1].add_child(_set_label("DISPLAY MODE"))
	win[1].add_child(_disp_seg([["windowed", "WINDOWED"], ["fullscreen", "FULLSCREEN"], ["exclusive", "EXCLUSIVE"]], D.windowMode, "windowMode", "mode", {}))
	win[1].add_child(_note("FULLSCREEN is borderless. EXCLUSIVE takes the display over, which can run smoother on some PCs."))
	var scr := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var sizes := PalSettings.sizes_for(scr)
	if not sizes.is_empty():
		win[1].add_child(_set_label("WINDOW SIZE"))
		var now := "%dx%d" % [m.get_window().size.x, m.get_window().size.y]
		var items := sizes.map(func(id): return [id, id.replace("x", "×")])
		var cur: String = D.winSize if full or not now in sizes else now   # in fullscreen: the size the window comes back at
		win[1].add_child(_disp_seg(items, cur, "winSize", "size", {"cols": mini(3, items.size()), "disabled": sizes if full else []}))
		win[1].add_child(_note(("Fullscreen uses your display's own resolution, %d×%d." % [scr.x, scr.y]) if full else "You can also drag the window's edges to any size."))
	win[1].add_child(_tog("VSync", D.vsync, func(on): D.vsync = on))
	win[1].add_child(_set_label("FPS LIMIT"))
	var auto: bool = D.fpsMode == "auto"
	win[1].add_child(_disp_seg(PalSettings.FPS_CAPS.map(func(id): return [id, id.to_upper()]), D.fpsCap, "fpsCap", "cap", {"disabled": [] if auto else PalSettings.FPS_CAPS}))
	win[1].add_child(_note("The most frames a second, with FRAME RATE on AUTO. With VSync on, your display's refresh rate is a limit too." if auto else "FRAME RATE is set to %s FPS. Set it to AUTO to use this limit." % D.fpsMode))
	win[1].add_child(_tog("Reduce motion (backgrounds and outfit effects hold still)", D.get("reduceMotion", false), func(on): D.reduceMotion = on))
	return win[0]


## one of the display's choices: saved, applied, and the page built again with the controller on the same choice
func _disp_seg(items: Array, cur: String, key: String, pre: String, opts: Dictionary) -> Control:
	var names := {}
	for it in items:
		names[it[0]] = it[1]
	var o := {"size": 15, "h": 40}
	o.merge(opts)
	var sg := UiKit.seg(items, cur, func(id):
		m.settings.data[key] = id
		_apply()
		show_settings()
		mn._refocus("%s:%s" % [pre, names[id]]), o)
	mn._tag_seg(sg, pre)
	return sg


func _note(text: String) -> Label:
	return _l(text, "m4", 11, UiKit.DIM, 0.0, 1.55, true)


func _apply() -> void:
	m.apply_settings()
	m.settings.save()


## .set: the name over a short gold range and its percentage
func _slider(title: String, val: float, lo: float, hi: float, cb: Callable, fid: String) -> Control:
	var v := UiKit.vbox(6)
	v.add_child(_set_label(title))
	var h := UiKit.hbox(12)
	var pct := _l("%d%%" % roundi(val * 100), "m6", 13, UiKit.BONE)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.custom_minimum_size.x = UiKit.px(46)
	var s := UiKit.slider(val, lo, hi, 0.05, func(x: float):
		pct.text = "%d%%" % roundi(x * 100)
		cb.call(x)
		_apply())
	s.custom_minimum_size.x = UiKit.px(130)
	mn._fid(s, "sl:" + fid)
	h.add_child(s)
	var gap := UiKit.spacer()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.size_flags_stretch_ratio = 0.6
	h.add_child(gap)
	h.add_child(pct)
	var rest := UiKit.spacer(0, 60)
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rest.size_flags_stretch_ratio = 0.4
	h.add_child(rest)
	v.add_child(h)
	return v


func _tog(text: String, on: bool, cb: Callable) -> Control:
	var c := UiKit.toggle(text, on, func(x: bool):
		cb.call(x)
		_apply(), 14, _in_game())
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mn._fid(c, "tog:" + text)
	return c


## a row: the action's name and the key or button for it (.padRow)
func _bind_row(name: String, cap: String, wait: bool, cb: Callable, fid: String, enabled: bool = true) -> UiKit.Btn:
	var h := UiKit.hbox(10)
	var n := _l(name, "m4", 12, UiKit.BONE, 0.06)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(n)
	var k := _l(cap, "m6", 11, UiKit.INKT)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ks := UiKit.sb(UiKit.WARN if wait else UiKit.BONE, Color(0, 0, 0, 0), 0, [1, 6, 1, 6])
	ks.set_corner_radius_all(int(UiKit.px(2)))
	k.add_theme_stylebox_override("normal", ks)
	k.custom_minimum_size.x = UiKit.px(40)
	k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(k)
	var pad := [8, 10, 8, 10]
	var bg := Color(0, 0, 0, 0.25)
	var ln: Color = UiKit.WARN if wait else UiKit.PLINE
	var box := {"normal": UiKit.sb(bg, ln, 1, pad), "hover": UiKit.sb(Color(1, 1, 1, 0.05), UiKit.WARN, 1, pad), "pressed": UiKit.sb(bg, UiKit.WARN, 1, pad), "disabled": UiKit.sb(bg, ln, 1, pad)}
	var b := UiKit.card_btn(h, box, cb)
	b.disabled = not enabled
	mn._fid(b, fid)
	return b


func _pad_card() -> Control:
	var st: PalSettings = m.settings
	var inp: PalInput = m.inp
	var c := _card("CONTROLLER")
	c[1].add_child(_l(("Controller connected (%s buttons). Pick an action, then press the button you want for it." % ("PlayStation" if inp.pad_kind == "ps" else "Xbox-style")) if inp.pad_dev >= 0 else "No controller found. Plug one in or pair it, then press any button on it.", "m4", 11, UiKit.DIM, 0.0, 1.55, true))
	var rows := UiKit.vbox(6)
	for id in ["fire", "nade", "build", "special", "sprint", "roll", "armory", "piece", "matPrev", "matNext", "start", "reload", "delgado", "skills"]:
		var a: Array = []
		for x in PalSettings.ACTIONS:
			if x[0] == id:
				a = x
		if a.is_empty():
			continue
		var wait: bool = inp.bind_act == id
		var aid: String = id
		rows.add_child(_bind_row(a[1], "PRESS A BUTTON" if wait else PalSettings.glyph(st.data.pad.get(id, -1), inp.pad_kind), wait, func():
			inp.start_bind(aid, func(_b):
				m.settings.save()
				if mn.screen == "settings":
					show_settings()
					mn._refocus("pad:" + aid))
			show_settings()
			mn._refocus("pad:" + aid), "pad:" + id))
	c[1].add_child(rows)
	var fx := UiKit.hbox(14)
	for it in [["MOVE", "LS"], ["AIM", "RS"], ["PAUSE", PalSettings.glyph(PalSettings.PB.MENU, inp.pad_kind)]]:
		var h := UiKit.hbox(6)
		h.add_child(_l(it[0], "m4", 11, UiKit.DIM))
		var k := _l(it[1], "m6", 11, UiKit.INKT)
		var ks := UiKit.sb(UiKit.BONE, Color(0, 0, 0, 0), 0, [1, 6, 1, 6])
		k.add_theme_stylebox_override("normal", ks)
		h.add_child(k)
		fx.add_child(h)
	c[1].add_child(fx)
	c[1].add_child(mn._fid(UiKit.btn("RESET BUTTONS", "ghost", 16, func():
		st.reset_pad()
		st.save()
		show_settings()
		mn._refocus("pad:reset"), {"h": 46}), "pad:reset"))
	return c[0]


## this game's keyboard: every action and its key; pick one, then press the key
func _key_card() -> Control:
	var st: PalSettings = m.settings
	var c := _card("KEYBOARD")
	c[1].add_child(_l("Pick an action, then press the key you want for it. Esc cancels. Aim with the mouse; hold the left button to fire.", "m4", 11, UiKit.DIM, 0.0, 1.55, true))
	var rows := UiKit.vbox(6)
	for a in PalSettings.ACTIONS:
		var id: String = a[0]
		var wait: bool = mn.binding == "k:" + id
		rows.add_child(_bind_row(a[1], "PRESS A KEY" if wait else st.keys_label(id), wait, func():
			mn.binding = "k:" + id
			show_settings()
			mn._refocus("key:" + id), "key:" + id))
	c[1].add_child(rows)
	c[1].add_child(mn._fid(UiKit.btn("RESET KEYS", "ghost", 16, func():
		st.reset_keys()
		st.apply_keys()
		st.save()
		show_settings()
		mn._refocus("key:reset"), {"h": 46}), "key:reset"))
	return c[0]


# ---------------------------------------------------------------- the save backup (#saveOv)

func overlay_open() -> bool:
	return is_instance_valid(_ov)


func close_overlay() -> void:
	if is_instance_valid(_ov):
		_ov.queue_free()
	_ov = null
	if mn.screen == "backup":
		mn.screen = "settings"
	mn._refocus("save:export")


## EXPORT SAVE: the browser's save code (it moves between the browser game and this one); IMPORT SAVE: paste one
func show_backup(mode: String, msg: String = "") -> void:
	if mn.screen != "settings":
		show_settings()
	if is_instance_valid(_ov):
		_ov.queue_free()
	mn.screen = "backup"
	_ov = Control.new()
	_ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	mn.root.add_child(_ov)
	var dim := ColorRect.new()
	dim.color = Color(12 / 255.0, 11 / 255.0, 9 / 255.0, 0.95)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ov.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ov.add_child(cc)
	var col := UiKit.vbox(16)
	col.custom_minimum_size.x = UiKit.px(470)
	cc.add_child(col)
	col.add_child(_l("SAVE BACKUP", "s8", 13, UiKit.OWARN, 0.22))
	col.add_child(_l("EXPORT SAVE" if mode == "export" else "IMPORT SAVE", "s9", 28, UiKit.OWARN, 0.08))
	var cloud: bool = m.locker != null and not m.locker.cloud.is_empty()
	var lede := "Your locker, best runs and settings as one line of text. Keep it somewhere safe, or paste it into the browser game (Settings › Save backup) or another computer." if mode == "export" else "Paste a save code (it starts PALISADE-SAVE-1), then CHECK CODE. Restoring keeps this computer's current save as a backup copy."
	if cloud:
		lede += " You're signed in: your locker lives on your account and follows you anyway."
	col.add_child(_l(lede, "m4", 12, UiKit.ODIM, 0.0, 1.55, true))
	var ta := TextEdit.new()
	ta.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	ta.custom_minimum_size.y = UiKit.px(110)
	ta.add_theme_font_override("font", UiKit.face("m4"))
	ta.add_theme_font_size_override("font_size", UiKit.fs(12))
	ta.add_theme_color_override("font_color", UiKit.OBONE)
	var tsb := UiKit.sb(Color("#0c0b09"), UiKit.OLINE, 1, 10)
	ta.add_theme_stylebox_override("normal", tsb)
	ta.add_theme_stylebox_override("focus", UiKit.sb(Color("#0c0b09"), UiKit.OWARN, 2, 10))
	ta.placeholder_text = "PALISADE-SAVE-1…"
	col.add_child(ta)
	var note := _l(msg, "m4", 12, UiKit.OWARN, 0.0, 1.5, true)
	col.add_child(note)
	var pending := {}
	if mode == "export":
		ta.text = PalSaves.export_code(m.locker, m.settings)
		ta.editable = false
		var row := UiKit.hbox(8)
		var cp := UiKit.btn("COPY", "ogo", 16, func():
			DisplayServer.clipboard_set(ta.text)
			note.text = "Copied. Paste it somewhere safe.", {"h": 46})
		row.add_child(UiKit.expand(mn._fid(cp, "bk:copy")))
		row.add_child(UiKit.expand(UiKit.btn("SAVE FILE", "oghost", 16, func():
			var dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
			var path := (dir if dir != "" else OS.get_user_data_dir()).path_join("palisade-save.txt")
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f != null:
				f.store_string(ta.text + "\n")
				note.text = "Saved as " + path + "."
			else:
				note.text = "Couldn't write the file. Copy the code instead.", {"h": 46})))
		col.add_child(row)
	else:
		var row := UiKit.hbox(8)
		var confirm := UiKit.btn("RESTORE THIS SAVE", "ogo", 22, func():
			if pending.is_empty():
				return
			PalSaves.restore(pending, m.locker, m.settings)
			m.apply_settings()
			pending.clear()
			ta.text = ""
			note.text = "Restored. Your locker is back.", {"h": 56})
		confirm.visible = false
		var chk := UiKit.btn("CHECK CODE", "ogo", 16, func():
			var r := PalSaves.parse_code(ta.text)
			pending.clear()
			confirm.visible = false
			if r.has("err"):
				note.text = r.err
				return
			pending.merge(r.d)
			note.text = PalSaves.summary(r.d) + ". Press RESTORE THIS SAVE to replace this computer's save (the current one is kept as a backup copy)."
			confirm.visible = true, {"h": 46})
		row.add_child(UiKit.expand(mn._fid(chk, "bk:check")))
		row.add_child(UiKit.expand(UiKit.btn("PASTE", "oghost", 16, func(): ta.text = DisplayServer.clipboard_get(), {"h": 46})))
		col.add_child(row)
		col.add_child(confirm)
		ta.text_changed.connect(func():
			pending.clear()
			confirm.visible = false)
	col.add_child(mn._fid(UiKit.btn("CLOSE", "oghost", 16, func(): close_overlay(), {"h": 46}), "bk:close"))
	mn._refocus("bk:copy" if mode == "export" else "bk:check")


# ---------------------------------------------------------------- ACCOUNT (19-accounts.js renderAcct)

func _acct_do(fn: Callable) -> void:
	if mn.acct_busy:
		return
	mn.acct_busy = true
	m.account.msg = ""
	show_account()
	var out = await fn.call()
	m.account.msg = out if out is String else ""
	mn.acct_busy = false
	show_account()


## .acBox: a small form card; returns its column
func _form(title: String, lede: String) -> Array:
	var c := _card(title, 8)
	if lede != "":
		c[1].add_child(_l(lede, "m4", 11, UiKit.DIM, 0.0, 1.55, true))
	return c


func _join_row(field: LineEdit, label: String, cb: Callable, dis: bool) -> Control:
	var h := UiKit.hbox(8)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(field)
	var b := UiKit.btn(label, "go", 18, cb, {"w": 120, "h": 46})
	b.disabled = dis
	h.add_child(b)
	return h


func show_account() -> void:
	mn._begin("account", show_account)
	var A: PalAccount = m.account
	var body: VBoxContainer = mn._shell("card")
	var st := A.state if A != null else "off"
	var g: bool = A != null and A.is_guest()
	var live: bool = st == "guest" or st == "full"
	var u: Dictionary = A.s.get("user") if A != null and A.s.get("user") is Dictionary else {}
	body.add_child(mn._pt("ACCOUNT", 28))
	var head := UiKit.panel(UiKit.PANEL, UiKit.PLINE, 1, [14, 16, 14, 16])
	var hr := UiKit.hbox(16)
	var av := Menus.Avatar.new(m.locker.eq.duplicate(), str(m.settings.data.setup.cls), 96)
	hr.add_child(av)
	var hv := UiKit.vbox(0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	var full: bool = st == "full" and not g
	hv.add_child(_l("SET USERNAME" if full and A.name_ == "" else mn.my_name(), "s9", 30, UiKit.BONE, 0.05))
	hv.add_child(UiKit.spacer(3))
	hv.add_child(_l(mn.identity_state(), "m4", 10, Color("#a2e7c6"), 0.08))
	hv.add_child(UiKit.spacer(8))
	var lede := ""
	match st:
		"off":
			lede = "This build is playing offline. Your locker is saved on this computer."
		"wait":
			lede = "Connecting to your account…"
		"down":
			lede = "Can't reach the account server right now. You can still play: finished runs are sent when you're back online, and opening cases waits for a connection." if A.signed_in() else "No account yet. Your locker is saved on this computer, and it moves into your account once one is made."
		_:
			lede = "You're playing as a guest. Your locker is backed up online, but only this computer can get back into it. Add an email to keep it on any device, or sign in to an account you already have." if g else "Signed in%s%s. Your locker is saved to your account and follows you to any device you sign in on, the browser game included." % [(" as " + A.name_) if A.name_ != "" else "", (" · " + str(u.email)) if u.get("email") else ""]
	hv.add_child(_l(lede, "m4", 12, UiKit.BONE, 0.0, 1.55, true))
	hr.add_child(hv)
	head.add_child(hr)
	body.add_child(head)
	if A != null and A.msg != "":
		body.add_child(_l(A.msg, "m4", 12, UiKit.WARN, 0.0, 1.5, true))
	var dis: bool = mn.acct_busy or st == "wait"
	if st == "down":
		var tr := UiKit.btn("TRY AGAIN", "go", 22, func():
			A.msg = ""
			A.boot(), {"h": 56, "w": 220})
		tr.disabled = dis
		var r0 := UiKit.hbox(0)
		r0.add_child(tr)
		body.add_child(r0)
	var cards := UiKit.grid(3, 12)
	body.add_child(cards)
	if live:
		var f := _form("USERNAME", "What other players see. 3 to 16 letters, numbers or _.")
		var un := UiKit.field(A.name_, "Pick a name", {"size": 16})
		un.max_length = 16
		f[1].add_child(_join_row(un, "SAVE", func():
			var n := un.text.strip_edges()
			if not RegEx.create_from_string("^[A-Za-z0-9_]{3,16}$").search(n):
				A.msg = "Usernames are 3 to 16 letters, numbers or _."
				show_account()
				return
			_acct_do(func(): return await A.set_username(n)), dis))
		cards.add_child(f[0])
	if live and g:
		var f := _form("KEEP IT ON ANY DEVICE", "Add your email. We send a link; open it on any device, then choose a password. Your locker stays as it is.")
		var mail := UiKit.field("", "you@example.com", {"size": 16})
		f[1].add_child(_join_row(mail, "SEND LINK", func():
			var mm := mail.text.strip_edges()
			if not RegEx.create_from_string("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$").search(mm):
				A.msg = "That doesn't look like an email address."
				show_account()
				return
			_acct_do(func(): return await A.link_email(mm)), dis))
		cards.add_child(f[0])
	if live and not g and A.needs_password():
		var f := _form("SET A PASSWORD", "So you can sign in on your other devices. At least 8 characters.")
		var pw := UiKit.field("", "New password", {"size": 16, "secret": true})
		f[1].add_child(_join_row(pw, "SAVE", func():
			if pw.text.length() < 8:
				A.msg = "Pick a longer password: at least 8 characters."
				show_account()
				return
			_acct_do(func(): return await A.set_password(pw.text)), dis))
		cards.add_child(f[0])
	if st == "guest" or (st == "down" and not A.signed_in()):
		var f := _form("HAVE AN ACCOUNT?", "")
		var im := UiKit.field("", "Email", {"size": 16})
		f[1].add_child(im)
		var ip := UiKit.field("", "Password", {"size": 16, "secret": true})
		f[1].add_child(_join_row(ip, "SIGN IN", func():
			var mm := im.text.strip_edges()
			if mm == "" or ip.text == "":
				A.msg = "Enter your email and password."
				show_account()
				return
			_acct_do(func(): return await A.sign_in(mm, ip.text)), dis))
		var fg := UiKit.btn("FORGOT PASSWORD", "ghost", 13, func():
			var mm := im.text.strip_edges()
			if not mm.contains("@"):
				A.msg = "Type your email above first, then press Forgot password."
				show_account()
				return
			_acct_do(func(): return await A.forgot(mm)), {"h": 36, "pad": [0, 14, 0, 14]})
		fg.disabled = dis
		var r := UiKit.hbox(0)
		r.add_child(fg)
		f[1].add_child(r)
		cards.add_child(f[0])
	if live and not g:
		var so := UiKit.btn("SIGN OUT", "ghost", 16, func(): _acct_do(func(): return await A.sign_out()), {"h": 46, "w": 220})
		so.disabled = dis
		var r := UiKit.hbox(0)
		r.add_child(so)
		body.add_child(r)
	var br := UiKit.hbox(0)
	var bk := UiKit.btn("BACK", "ghost", 16, func(): mn.show_main(), {"h": 46, "w": 220})
	br.add_child(mn._fid(bk, "acct:back"))
	body.add_child(br)
	mn._focus = bk
	mn._settle()


# ---------------------------------------------------------------- INDEX (19e-index.js)

var idx_tab := "classes"


func show_index(tab: String) -> void:
	idx_tab = tab
	var cls: String = str(m.settings.data.setup.cls)
	if _in_game():
		var col: VBoxContainer = _frame("index", func(): show_index(idx_tab), "INDEX")
		_index_body(col, true)
		var b := UiKit.btn("BACK TO THE PAUSE MENU", "ogo", 22, func(): mn.show_pause(), {"h": 56})
		col.add_child(mn._fid(b, "idx:done"))
		mn._settle()
		return
	mn._begin("index", func(): show_index(idx_tab))
	var body: Control = mn._shell("party")
	var row := UiKit.hbox(18)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_child(row)
	var lp: Array = mn._side_panel(380)
	row.add_child(lp[0])
	_index_body(lp[1], false)
	row.add_child(mn._stage_column("CLASSES", Pal.CLASSES[cls].name, "Your class carries into solo and multiplayer.", [], mn.my_name(), "CHOOSING A CLASS", ""))
	mn._settle()


func _index_body(col: VBoxContainer, overlay: bool) -> void:
	var o := "o" if overlay else ""
	if not overlay:
		col.add_child(mn._pt("INDEX"))
	var tabs := UiKit.seg([["classes", "CLASSES"], ["raiders", "RAIDERS"], ["bosses", "BOSSES"]], idx_tab, func(id):
		show_index(id)
		mn._refocus("idx:" + str(id).to_upper()), {"size": 12, "em": 0.02, "h": 40, "palette": o})
	mn._tag_seg(tabs, "idx")
	col.add_child(tabs)
	for b in tabs.get_child(0).get_children():
		if b.get_meta("sel", false):
			mn._focus = b
	var bone: Color = UiKit.OBONE if overlay else UiKit.BONE
	var cardbg := Color(27 / 255.0, 24 / 255.0, 20 / 255.0, 0.8)
	var line: Color = UiKit.OLINE if overlay else UiKit.LINE
	match idx_tab:
		"classes":
			col.add_child(_l("Pick your class. It carries into solo and multiplayer.", "m4", 11, bone, 0.0, 1.55, true))
			var cls: String = str(m.settings.data.setup.cls)
			for id in Pal.CLASS_IDS:
				var sel: bool = id == cls
				var v := UiKit.vbox(7)
				v.add_child(_l(Pal.CLASSES[id].name, "s9", 21, bone, 0.03))
				v.add_child(_l(Menus.CLASS_TEXT[id][0], "m4", 10, UiKit.OWARN, 0.04))
				v.add_child(_l(Menus.CLASS_TEXT[id][1], "m4", 12, UiKit.ODIM if overlay else UiKit.DIM, 0.0, 1.4, true))
				var pad := [14, 14, 14, 14]
				var on := Color(58 / 255.0, 48 / 255.0, 28 / 255.0, 0.85)
				var box := {"normal": UiKit.sb(on if sel else cardbg, UiKit.WARN if sel else line, 1, pad), "hover": UiKit.sb(on if sel else Color(40 / 255.0, 36 / 255.0, 30 / 255.0, 0.9), UiKit.WARN, 1, pad),
					"pressed": UiKit.sb(on, UiKit.WARN, 1, pad), "disabled": UiKit.sb(cardbg, line, 1, pad)}
				var cid: String = id
				var b := UiKit.card_btn(v, box, func():
					m.settings.data.setup.cls = cid
					m.settings.save()
					if m.net.is_online() and not m.net.in_game:
						var me: Dictionary = m.net_me()
						m.net.set_loadout(cid, me.cos, me.name, me.sk)
					show_index("classes")
					mn._refocus("cls:" + cid))
				b.custom_minimum_size.y = UiKit.px(158)
				mn._fid(b, "cls:" + id)
				col.add_child(b)
		"raiders":
			col.add_child(_l("Who comes over the fence, and when.", "m4", 11, bone, 0.0, 1.55, true))
			for r in Menus.IDX_RAIDERS:
				var E: Dictionary = Pal.ETYPES[r[0]]
				col.add_child(_idx_card(str(Sim.ENAMES[r[0]][0]).to_upper(), bone, m.LOOK.get(r[0], m.LOOK.rifle), [["stat", "%d health · speed %s · from raid %d" % [int(E.hp), str(E.speed), r[1]]], ["", r[2]]], overlay))
		"bosses":
			col.add_child(_l("Every boss, every attack and its warning, and the ammo that hurts him most. Health is the base, before crew size and map scaling.", "m4", 11, bone, 0.0, 1.55, true))
			for grp in Menus.IDX_BOSSES:
				col.add_child(UiKit.spacer(2))
				col.add_child(_l(grp[0], "s9", 15, UiKit.WARN, 0.08))
				for bd in grp[1]:
					var B: Dictionary = Sim.boss_def(bd[0])
					var where: String = bd[1]
					if where == "":
						var ms: Array = PalMaps.MAP_IDS.filter(func(k): return PalMaps.MAPS[k].bosses.has(bd[0])).map(func(k): return PalMaps.MAPS[k].short)
						where = (", ".join(ms) + " · every 5th raid") if not ms.is_empty() else "Boss raids"
					var lines: Array = [["stat", "%d base health · %s" % [roundi(B.hp * Sim.BOSS_HP), where]], ["atk", "%d ATTACK%s" % [bd[2].size(), "S" if bd[2].size() > 1 else ""]], ["list", bd[2]]]
					if bd[3] != "":
						lines.append(["phase", bd[3]])
					var wk: String = Sim.BOSS_WEAK.get(bd[0], Sim.BOSS_WEAK2.get(bd[0], ""))
					for A in Sim.AMMO:
						if A.id == wk:
							lines.append(["weak", "WEAK TO %s (+35%% bullet damage)" % A.name, Color(A.col)])
					col.add_child(_idx_card(B.name, Color(B.col), B.look, lines, overlay))
				if grp[0] == "CITY BLACK OUT":
					var p := UiKit.panel(cardbg, line, 1, 9)
					var v := UiKit.vbox(3)
					v.add_child(_l("THE EIGHT POINTS", "s9", 16, bone, 0.04))
					v.add_child(_l("Each point gives a perk while it holds. A lost major point adds a squad to every final-push wave; a lost minor point gives final-push bosses +5% health.", "m4", 11, UiKit.DIM, 0.0, 1.4, true))
					for P in PalMaps.CITY_POIS:
						v.add_child(_l("•  %s%s: %s" % [P[1], " (major)" if P[2] else "", P[4]], "m4", 11, UiKit.DIM, 0.0, 1.4, true))
					p.add_child(v)
					col.add_child(p)


## .idxCard: a portrait and the facts
func _idx_card(name: String, col: Color, look: Dictionary, lines: Array, overlay: bool) -> Control:
	var p := UiKit.panel(Color(27 / 255.0, 24 / 255.0, 20 / 255.0, 0.8), UiKit.OLINE if overlay else UiKit.LINE, 1, 9)
	var h := UiKit.hbox(10)
	var por := Portrait.new(look)
	por.custom_minimum_size = Vector2(UiKit.px(72), UiKit.px(72))
	por.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(por)
	var v := UiKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_l(name, "s9", 16, col, 0.04, 1.2, true))
	for ln in lines:
		match ln[0]:
			"stat":
				v.add_child(_l(ln[1], "m4", 11, Color("#c9bf9f"), 0.0, 1.4, true))
			"atk":
				v.add_child(_l(ln[1], "m6", 11, UiKit.BONE, 0.04))
			"list":
				for s in ln[1]:
					var r := UiKit.hbox(6)
					var dot := _l("•", "m4", 11, UiKit.DIM, 0.0, 1.4)
					dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
					r.add_child(dot)
					r.add_child(UiKit.expand(_l(s, "m4", 11, UiKit.DIM, 0.0, 1.4, true)))
					v.add_child(r)
			"phase":
				v.add_child(_l(ln[1], "m4", 11, Color("#e0a46a"), 0.0, 1.4, true))
			"weak":
				v.add_child(_l(ln[1], "m6", 11, ln[2], 0.04, 1.4, true))
			_:
				v.add_child(_l(ln[1], "m4", 11, UiKit.DIM, 0.0, 1.4, true))
	h.add_child(v)
	p.add_child(h)
	return p


class Portrait extends Control:
	var look: Dictionary

	func _init(l: Dictionary) -> void:
		look = l.duplicate()
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))
		var k := size.x / 96.0
		var o: Dictionary = look.duplicate()
		if not o.has("mark"):
			o.mark = "#e2b436"
		Wardrobe.draw(self, o, 0.6, 1.0, 2.05 * k, 48 * k, 90 * k, false)


# ---------------------------------------------------------------- SKILLS (renderSkills)

func show_skills() -> void:
	var P: PalProfile = m.profile
	var body := _frame("skills", show_skills, "SKILL TREE")
	var ig := _in_game()
	if not ig:
		body.add_child(mn._pt("SKILL TREE", 28))
	var head := UiKit.hbox(16)
	var pts := UiKit.panel(Color(58 / 255.0, 48 / 255.0, 18 / 255.0, 0.6), UiKit.WARN, 1, [8, 10, 8, 10])
	pts.custom_minimum_size.x = UiKit.px(92)
	var pv := UiKit.vbox(2)
	var n := _l(str(P.sp), "s9", 40, UiKit.WARN, 0.0, 1.0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(n)
	pv.add_child(_l("SKILL POINTS", "m6", 10, UiKit.BONE, 0.08))
	pts.add_child(pv)
	head.add_child(pts)
	var spent := 0
	for S in PalProfile.SKILLS:
		for l in mini(P.level(S.id), S.max):
			spent += S.cost[l]
	var lede := _l("1 point for every 5 raids you hold (%d more to the next one), and 1 for every boss that goes down. %d spent, %d earned in all." % [5 - P.sp_prog, spent, P.sp_total], "m4", 11, UiKit.DIM, 0.0, 1.55, true)
	lede.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lede.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(lede)
	body.add_child(head)
	body.add_child(_l("One tree for every job. In Base Battle and Free-for-all the perks count half and the job nodes are off. Rockets (soldier, Q) and stealth (sniper, Q) are co-op only.", "m4", 11, UiKit.DIM, 0.0, 1.55, true))
	var msg: String = m.sk_msg if m.sk_msg != "" else _sk_msg
	if msg != "":
		body.add_child(_l(msg, "m4", 12, UiKit.WARN, 0.0, 1.5, true))
	var tree := UiKit.grid(2 if ig else 3, 12)
	body.add_child(tree)
	var branches: Array = []
	for S in PalProfile.SKILLS:
		if not branches.has(S.br):
			branches.append(S.br)
	for br in branches:
		var c := _card(br, 0)
		c[0].size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var v: VBoxContainer = c[1]
		v.add_child(UiKit.spacer(10))
		var first := true
		for S in PalProfile.SKILLS:
			if S.br != br:
				continue
			v.add_child(_skill_row(S, first))
			first = false
		tree.add_child(c[0])
	var sure := Time.get_ticks_msec() / 1000.0 - _sk_sure < 3.0
	var rs := UiKit.btn("TAP AGAIN TO RESET" if sure else ("RESET TREE · 40 SHARDS" if P.cloud else "RESET TREE"), "ghost", 16, func(): _reset_tree(), {"h": 46, "w": 220})
	rs.disabled = spent == 0
	var r1 := UiKit.hbox(0)
	r1.add_child(mn._fid(rs, "sk:reset"))
	body.add_child(UiKit.spacer(8))
	body.add_child(r1)
	var r2 := UiKit.hbox(0)
	var bk := UiKit.btn("BACK", "ghost", 16, func(): mn.back(), {"h": 46, "w": 220})
	r2.add_child(mn._fid(bk, "sk:back"))
	body.add_child(r2)
	mn._settle()


func _skill_row(S: Dictionary, first: bool) -> Control:
	var P: PalProfile = m.profile
	var lv := P.level(S.id)
	var v := UiKit.vbox(0)
	v.add_child(UiKit.rule() if not first else UiKit.rule())
	v.add_child(UiKit.spacer(8))
	var h := UiKit.hbox(12)
	var left := UiKit.vbox(4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_l(S.name, "s9", 17, Color("#f3e7b9") if lv > 0 else UiKit.BONE, 0.05))
	left.add_child(UiKit.Pips.new(S.max, lv))
	var what: String = S.what + (" (co-op)" if S.id == "revive" else "")
	if S.has("gate") and lv < S.max:
		what += " Next tier: %d lifetime SP earned, %d SP to buy." % [S.gate[lv], S.cost[lv]]
	left.add_child(_l(what, "m4", 11, UiKit.DIM, 0.0, 1.4, true))
	h.add_child(left)
	var reason := P.block_reason(S.id)
	var label := ""
	if lv >= S.max:
		label = "MAXED"
	elif reason.begins_with("Needs"):
		label = "NEEDS " + PalProfile.skill_by(S.req[0]).name
	elif S.has("gate") and P.sp_total < S.gate[lv]:
		label = "NEEDS %d EARNED" % S.gate[lv]
	else:
		var c: int = S.cost[lv]
		label = "%d PT%s" % [c, "S" if c > 1 else ""]
	var id: String = S.id
	var b := UiKit.btn(label, "go", 14, func():
		await m.skill_buy(id)
		show_skills()
		mn._refocus("sk:" + id), {"w": 84, "h": 44, "em": 0.05, "pad": [0, 8, 0, 8]})
	b.disabled = reason != ""
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mn._fid(b, "sk:" + id)
	h.add_child(b)
	v.add_child(h)
	if S.id == "molotov" and lv > 0:
		v.add_child(UiKit.toggle("Throw Molotovs", not P.mol_off, func(on: bool):
			P.mol_off = not on
			P.save(), 13))
	v.add_child(UiKit.spacer(10))
	return v


func _reset_tree() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _sk_sure >= 3.0:
		_sk_sure = now
		_sk_msg = "Every point comes back%s." % ("; it costs 40 shards" if m.profile.cloud else "")
		show_skills()
		mn._refocus("sk:reset")
		return
	_sk_sure = -10.0
	_sk_msg = ""
	await m.skill_respec()
	if _sk_msg == "" and m.sk_msg == "":
		_sk_msg = "Your points are back. Spend them again."
	show_skills()
	mn._refocus("sk:reset")


# ---------------------------------------------------------------- TABLES (21b-tables.js renderTables)

func show_tables() -> void:
	mn._begin("tables", show_tables)
	var body: VBoxContainer = mn._shell("plain")
	body.add_child(mn._pt("TABLES", 28, UiKit.OWARN))
	var tables = m.casino_ui.tables if m.casino_ui != null else null
	var bal := UiKit.hbox(10)
	var bl := _l("YOUR SHARDS", "m4", 12, UiKit.ODIM, 0.1)
	bl.size_flags_vertical = Control.SIZE_SHRINK_END
	bal.add_child(bl)
	var shards: int = m.locker.shards if m.locker != null else 0
	if tables != null and tables.balance > 0:
		shards = tables.balance
	bal.add_child(_l(str(shards), "s9", 28, Color("#9fd8ff"), 0.06))
	body.add_child(bal)
	body.add_child(_marquee())
	body.add_child(_l("Blackjack, Texas Hold'em, American roulette, craps, baccarat, sixteen slot machines and a Plinko board, for real shards (never bought, never cashed out). Walk in, walk up to a table or a machine: you sit down with 5 shards (the buy-in), top up whenever you like, and whatever is in front of you goes back to your balance when you stand up. Up to 6 of your crew in one casino.", "m4", 12, UiKit.ODIM, 0.0, 1.45, true))
	var enter := UiKit.btn("ENTER THE CASINO", "ogo", 20, func(): m.start_casino(), {"h": 56})
	mn._focus = enter
	body.add_child(mn._fid(enter, "cas:enter"))
	var A: PalAccount = m.account
	var why := ""
	if A == null or A.state == "off":
		why = "The tables need a connection to your account."
	elif A.s.is_empty():
		why = "Sign in to play at the tables."
	elif A.is_guest():
		why = "Make an account on the Account page to play at the tables. Guests can't."
	var msg := _l(why, "m4", 12, UiKit.OWARN, 0.0, 1.5, true)
	msg.visible = why != ""
	body.add_child(msg)
	body.add_child(UiKit.spacer(4))
	body.add_child(_l("OR JOIN A FRIEND'S CASINO", "s8", 16, UiKit.OWARN, 0.12))
	var jr := UiKit.hbox(8)
	var code := UiKit.field("", "ROOM CODE", {"palette": "o", "face": "m4", "size": 16, "em": 0.3, "h": 40, "bg": Color("#0f0d0a")})
	code.max_length = 6
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code.text_submitted.connect(func(t: String): m.net_join(t.to_upper()))
	jr.add_child(code)
	jr.add_child(mn._fid(UiKit.btn("JOIN", "oghost", 14, func(): m.net_join(code.text.to_upper()), {"h": 40, "pad": [0, 12, 0, 12], "em": 0.08}), "cas:join"))
	body.add_child(jr)
	var tr := UiKit.hbox(6)
	tr.add_child(UiKit.expand(mn._fid(UiKit.btn("HAND HISTORY", "oghost", 14, func(): _cas_modal("hist"), {"h": 40, "em": 0.08}), "cas:hist")))
	tr.add_child(UiKit.expand(mn._fid(UiKit.btn("HOUSE RULES", "oghost", 14, func(): _cas_modal("rules"), {"h": 40, "em": 0.08}), "cas:rules")))
	body.add_child(tr)
	var mine_box := UiKit.vbox(6)
	body.add_child(mine_box)
	body.add_child(UiKit.spacer(6))
	body.add_child(mn._fid(UiKit.btn("BACK", "oghost", 16, func(): mn.show_main(), {"h": 46}), "cas:back"))
	mn._settle()
	if tables != null and why == "":
		_tables_lobby(tables, mine_box, bal.get_child(1))


## the lobby call: the balance, and a seat still held from before (STAND UP takes the shards home)
func _tables_lobby(tables, box: VBoxContainer, bal: Label) -> void:
	var r: Dictionary = await tables.lobby()
	if not is_instance_valid(box) or r.get("error"):
		return
	bal.text = str(tables.balance)
	var mine = tables.mine
	if mine is Dictionary:
		var p := UiKit.panel(Color(0, 0, 0, 0), Color("#e8573a"), 1, [8, 10, 8, 10])
		var h := UiKit.hbox(8)
		var t := "Your bets are still being played out at a table you left; your shards come home once they're decided." if mine.get("pending") != null else "You're still seated at a casino %s from before. Stand up to take your shards home." % ("machine" if mine.get("station") else "table")
		h.add_child(UiKit.expand(_l(t, "m4", 12, Color("#ffb39e"), 0.0, 1.5, true)))
		if mine.get("pending") == null:
			h.add_child(UiKit.btn("STAND UP", "oghost", 14, func():
				await tables.call_op({"op": "leave", "id": int(mine.id)})
				show_tables(), {"h": 36}))
		p.add_child(h)
		box.add_child(p)


func _cas_modal(kind: String) -> void:
	var cu = m.casino_ui
	if cu == null:
		return
	cu.layer = 6   # over the menus while it's up
	mn._cas_modal = true
	if kind == "hist":
		cu.show_history()
	else:
		cu._rules()


## .casMarq: THE PALISADE FALLS · ★ CASINO ★
func _marquee() -> Control:
	var wash := UiKit.gradient_rect([Color(1.0, 140 / 255.0, 40 / 255.0, 0.25), Color(80 / 255.0, 8 / 255.0, 20 / 255.0, 0.5)], [0.0, 0.7], true, Vector2(0.5, 0.0), Vector2(1.0, 1.0))
	var p := UiKit.panel(Color(0, 0, 0, 0), Color("#d6aa46"), 2, [12, 8, 12, 8])
	var v := UiKit.vbox(2)
	var t := Label.new()
	t.text = "THE PALISADE FALLS"
	var s := UiKit.ls("s9", 26, Color("#fff3d6"), 0.1, 0.0, 3.0, Color(1.0, 0.54, 0.16, 0.35)).duplicate()
	t.label_settings = s
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var c := _l("★  CASINO  ★", "s8", 16, Color("#ff4a6a"), 0.3)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	p.add_child(v)
	return mn._layered(wash, p)
