extends SceneTree
## The HUD against the browser's own boxes (tests/hud_ref.json, made by tests/hud_ref.js): the phase box, the tip, the
## build kit, the key bar item by item, the banner, the kill feed and the boss bars' box, in the same states: the build
## phase, a raid, City Black Out, Base Battle, Free-for-all, the kit switched off, a Quartermaster (whose SPRINT widens
## the kit), a phase banner with two feed lines, a minor banner, and one, three and four bosses; at 1600x900 and 1280x720.
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1600x900 --script res://tests/hud_shot.gd -- /tmp/h
## Prints each box's offset from the browser's, OK/FAIL lines, and writes <prefix>_<state>_<width>.png.

const TOL := 5.0   # pixels: the browser lays text out in fractions, Godot in whole pixels (letter-spacing rounds to a
## whole pixel a letter: SALVAGE's 0.56 px is 1, so SALVAGE 40 runs 4.4 px wider)

var fails := 0
var main


func check(cond: bool, what: String) -> void:
	print(("OK " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	_run.call_deferred()


func _state(name: String) -> void:
	main.next_opt = {"map": "yard", "size": "std", "mode": "blackout" if name == "blackout" else "5", "diff": "normal", "mods": []}
	if name in ["base", "ffa"]:
		main.next_opt.pvp = name
	main.next_cls = "quartermaster" if name == "quarter" else "soldier"
	main.settings.data.build = name != "kitoff"
	main._restart()
	var s: Sim = main.sim
	if name in ["raid", "minor", "boss1", "boss3", "boss4"]:
		s.start_raid()
		main.hud.note = "RAID 1 OF 5"
	for i in 3:   # a moment of play: Black Out's starting purse
		s.update(1.0 / 30.0, {})
	if name == "base":   # the browser's reference forces Base Battle onto a co-op start: no starting salvage, the co-op tip
		s.player.sal = 0
		main.hud.tip = "Walk next to a wood pile to gather. Delgado is gathering too."
	main.hud.toast_clear()
	main.feed.clear()
	for k in {"boss1": ["butcher"], "boss3": ["butcher", "demolisher", "storm"], "boss4": ["butcher", "demolisher", "storm", "butcher"]}.get(name, []):
		s.spawn_boss(k)
	if name in ["raid", "boss1", "boss3", "boss4"]:
		main.hud.note = "RAID 1 OF 5"
	if name == "msg":
		for f in [["Rab took down a raider", "#e8c7a0"], ["Delgado dropped a breacher", "#a9bccb"]]:
			main.feed.push_front({"text": f[0], "col": f[1], "t": 5.7})
		main.hud.toast("RAID 1 OF 5", "3 riflemen coming over the east fence.")
	if name == "minor":
		main.hud.toast("ARMORY", "Walk back to the stake to spend salvage.")
	s.game.paused = true
	await _frames(4)
	if not name in ["msg", "minor"]:   # the game's own banners (a raid's, a boss's), which the browser's reference clears
		main.hud.toast_clear()
		if name in ["raid", "boss1", "boss3", "boss4"]:
			main.hud.note = "RAID 1 OF 5"
		await _frames(2)


## an item's offset from the browser's (CSS pixels, scaled by k for screen pixels), noted when it's over the tolerance
static func _off(off: Array, k: String, g: Rect2, b: Dictionary, sc: float) -> void:
	var d := [g.position.x - b.x, g.position.y - b.y, g.size.x - b.w, g.size.y - b.h]
	var mx := 0.0
	for v in d:
		mx = maxf(mx, absf(v))
	if mx > TOL:
		off.append("%s %.1f: %+.1f %+.1f %+.1f %+.1f" % [k, mx, d[0], d[1], d[2], d[3]])


## a control's box on screen
static func _r(c: Control) -> Rect2:
	return c.get_global_rect()


func _run() -> void:
	var pre: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://hud"
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/hud_ref.json"))
	PalAccount.offline = true
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	main.locker.persist = false
	main.profile.persist = false
	main.settings.data.tips = true
	main.demo = false
	main.menus.close()
	for sz in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		root.get_window().size = sz
		await _frames(4)
		for name in ["build", "raid", "blackout", "base", "ffa", "kitoff", "quarter", "msg", "minor", "boss1", "boss3", "boss4"]:
			var R: Dictionary = ref["%dx%d/%s" % [sz.x, sz.y, name]]
			await _state(name)
			var h: Hud = main.hud
			var got := {"phase": h.box, "lab": _r(h.lab), "pause": _r(h.pause_b), "val": _r(h.val), "core": _r(h.core_m), "core2": _r(h.core2_m),
				"qm": _r(h.qm_b), "note": _r(h.note_l), "salv": _r(h.salv), "skip": _r(h.skip_b), "kc": _r(h.skip_kc), "board": _r(h.board), "tip": _r(h.tip_p)}
			var shown := {"phase": true, "lab": true, "pause": true, "val": true, "core": h.core_m.visible, "core2": h.core2_m.visible, "qm": h.qm_b.visible,
				"note": h.note != "", "salv": h.salv.visible, "skip": h.skip_b.visible, "kc": h.skip_b.visible and h.skip_kc.visible, "board": h.board.visible, "tip": h.tip_p.visible}
			if R.has("map"):
				got.map = h.bo_map_box()
				shown.map = true
			var K: Dictionary = h.kit
			var pieces := Rect2()
			if K.wall.is_visible_in_tree():
				pieces = _r(K.wall).merge(_r(K.door))
			got.merge({"kit": h.kit_box, "bm": _r(K.bm), "pieces": pieces, "wall": _r(K.wall), "door": _r(K.door), "pk": _r(K.pk), "c0": _r(K.c0),
				"c1": _r(K.c1), "c2": _r(K.c2), "c0k": _r(K.c0.parts.k), "c0kc": _r(K.c0.parts.kc), "c0n": _r(K.c0.parts.n), "build": _r(K.build),
				"bact": _r(K.build.parts.act), "bsub": _r(K.build.parts.sub), "bkc": _r(K.build.parts.kc), "arm": _r(K.arm), "armkc": _r(K.arm.parts.kc),
				"nade": _r(K.nade), "nadekc": _r(K.nade.parts.kc), "naden": _r(K.nade.parts.n), "spr": _r(K.spr), "roll": _r(K.roll),
				"rollkc": _r(K.roll.parts.kc), "rolln": _r(K.roll.parts.n), "ab": _r(K.ab)})
			for k in ["bm", "wall", "door", "pk", "c0", "c1", "c2", "build", "arm", "nade", "spr", "roll", "ab"]:
				shown[k] = (K[k] as Control).is_visible_in_tree()
			shown.kit = K.nade.is_visible_in_tree()
			shown.pieces = shown.wall
			for k in [["c0k", "c0", "k"], ["c0kc", "c0", "kc"], ["c0n", "c0", "n"], ["bact", "build", "act"], ["bsub", "build", "sub"], ["bkc", "build", "kc"],
					["armkc", "arm", "kc"], ["nadekc", "nade", "kc"], ["naden", "nade", "n"], ["rollkc", "roll", "kc"], ["rolln", "roll", "n"]]:
				shown[k[0]] = (K[k[1]].parts[k[2]] as Control).is_visible_in_tree()
			got.keys = Rect2(h.keys_rect.position * h.s, h.keys_rect.size * h.s)
			shown.keys = h.keys_c.visible
			got.toast = _r(h.toast_p)
			shown.toast = h.toast_p.visible and h.toast_cur != null
			got.small = _r(h.toast_small)
			shown.small = shown.toast and h.toast_small.visible
			var bb := h.boss_box()
			got.bb = Rect2(bb.position * h.s, bb.size * h.s)
			shown.bb = bb.size.x > 0
			var id := "%d %s" % [sz.x, name]
			var worst := 0.0
			var off := []
			for k in got:
				if R.has(k) != shown[k]:
					check(false, "%s: %s is %s in the browser but %s here" % [id, k, "shown" if R.has(k) else "hidden", "shown" if shown[k] else "hidden"])
					continue
				if not R.has(k):
					continue
				var b: Dictionary = R[k]
				var g: Rect2 = got[k]
				var d := [g.position.x - b.x, g.position.y - b.y, g.size.x - b.w, g.size.y - b.h]
				var m := 0.0
				for v in d:
					m = maxf(m, absf(v))
				worst = maxf(worst, m)
				if m > TOL:
					off.append("%s %+.1f %+.1f %+.1f %+.1f" % [k, d[0], d[1], d[2], d[3]])
			# the key bar item by item, and the kill feed line by line
			var kbs: Array = R.get("kbs", [])
			check(kbs.size() == h.keys_boxes.size() and range(kbs.size()).all(func(i): return kbs[i].text == h.keys_boxes[i].it[0] + h.keys_boxes[i].it[1]),
				"%s: the key bar has the browser's keys (%s)" % [id, " · ".join(h.keys_boxes.map(func(k): return k.it[0] + " " + k.it[1]))])
			for i in mini(kbs.size(), h.keys_boxes.size()):
				_off(off, "kb%d" % i, h.keys_boxes[i].r, kbs[i], 1.0)
			var feeds: Array = R.get("feeds", [])
			var fl := h.feed_ls.filter(func(l): return l.visible)
			check(feeds.size() == fl.size(), "%s: %d feed lines (the browser: %d)" % [id, fl.size(), feeds.size()])
			for i in mini(feeds.size(), fl.size()):
				_off(off, "feed%d" % i, Rect2(fl[i].global_position / h.s, fl[i].size / h.s), feeds[i], 1.0)
			for o in off:
				worst = maxf(worst, float(o.get_slice(" ", 1)))
			check(off.is_empty(), "%s: every box within %d px of the browser's (worst %.1f)%s" % [id, int(TOL), worst, "" if off.is_empty() else ": " + ", ".join(off)])
			var digits := RegEx.create_from_string("[0-9]")
			for k in [["lab", h.lab.text], ["val", h.val.text], ["salv", h.salv.text]]:
				if R.has(k[0]):
					check(digits.sub(k[1], "#", true) == digits.sub(R[k[0]].text, "#", true), "%s: %s reads %s (the browser: %s)" % [id, k[0], k[1], R[k[0]].text])
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("%s_%s_%d.png" % [pre, name, sz.x])
	# the core meter's alarm, Delgado's button and START do what their keys do
	root.get_window().size = Vector2i(1600, 900)
	await _state("build")
	var s: Sim = main.sim
	var h: Hud = main.hud
	s.core.hp = s.core.max * 0.2
	await _frames(2)
	check(h.core_m.alarm, "the core meter turns rust under 30%")
	s.game.paused = false
	h.qm_b.pressed.emit()
	await _frames(2)
	check(s.qm.mode == "", "DELGADO · FOLLOW switches him to defending")
	check(h.qm_b.text == "DELGADO · DEFEND", "and the button says so (%s)" % h.qm_b.text)
	h.skip_b.pressed.emit()
	await _frames(2)
	check(s.game.phase == "raid", "START RAID starts the raid")
	check(h.tip == "", "the tip goes when the raid starts")
	# the kit's buttons do what their keys do
	await _state("build")
	s = main.sim
	s.game.paused = false
	var K: Dictionary = h.kit
	K.c1.pressed.emit()
	K.door.pressed.emit()
	check(s.game.sel == 1 and s.game.piece == "door", "BRICK and DOOR pick the brick door")
	K.wall.pressed.emit()
	K.c0.pressed.emit()
	var built0: int = s.game.stats.built
	var t := s.build_target(s.player, 0, false)
	K.build.pressed.emit()
	check(not t.ok or s.game.stats.built == built0 + 1, "PLACE builds what it says (%s %s)" % [t.act, t.reason])
	K.bm.pressed.emit()
	await _frames(2)
	check(not main.settings.data.build and not K.c0.is_visible_in_tree() and K.bm.parts.lab.text == "BUILD OFF", "BUILD ON switches the kit off")
	s.player.bcd = 0.0
	var built1: int = s.game.stats.built
	main.do_action("build")
	check(s.game.stats.built == built1, "and Space builds nothing while it's off")
	K.bm.pressed.emit()
	await _frames(2)
	check(main.settings.data.build and K.c0.is_visible_in_tree(), "BUILD OFF switches it back on")
	s.player.nades = 0
	await _frames(2)
	check(is_equal_approx(K.nade.modulate.a, 0.4), "NADE fades with no grenades left")
	check(s.player.rk > 0 and K.ab.parts.n.text == str(s.player.rk) and is_equal_approx(K.ab.modulate.a, 1.0), "ROCKET counts the soldier's rockets (%s)" % K.ab.parts.n.text)
	# the banner's queue: a phase message goes before the minor ones waiting, and a click dismisses the one up
	h.toast_clear()
	h.toast("ARMORY", "one")
	h.toast("ARMORY", "two")
	h.toast("RAID 2 OF 5", "three")
	check(h.toast_cur.small == "one" and h.toast_q.size() == 2 and h.toast_q[0].big == "RAID 2 OF 5", "a phase message jumps the minor ones waiting")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	h.toast_p.gui_input.emit(click)
	await _frames(2)
	check(h.toast_cur != null and h.toast_cur.big == "RAID 2 OF 5" and h.note == "RAID 2 OF 5", "a click dismisses the banner; the next one comes up and its title stays under the clock")
	# with a controller: the key bar and the key caps show its buttons
	main.inp.mode = "pad"
	await _frames(2)
	check(h.keys_boxes.size() > 0 and h.keys_boxes[0].it[0] == "LS" and K.build.parts.kc.text == PalSettings.glyph(main.settings.data.pad.get("build", -1)), "a controller's buttons in the key bar and on the kit (%s, %s)" % [h.keys_boxes[0].it[0] if h.keys_boxes.size() > 0 else "-", K.build.parts.kc.text])
	main.inp.mode = "mouse"
	print("RESULT " + ("PASS" if fails == 0 else "FAIL %d" % fails))
	quit(1 if fails else 0)
