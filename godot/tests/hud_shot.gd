extends SceneTree
## The HUD's phase box and tip against the browser's own boxes (tests/hud_ref.json, made by tests/hud_ref.js) in the
## same states: the build phase, a raid, City Black Out, Base Battle and Free-for-all, at 1600x900 and 1280x720.
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
	main.next_cls = "soldier"
	main._restart()
	var s: Sim = main.sim
	if name == "raid":
		s.start_raid()
		main.hud.note = "RAID 1 OF 5"
	for i in 3:   # a moment of play: Black Out's starting purse
		s.update(1.0 / 30.0, {})
	if name == "base":   # the browser's reference forces Base Battle onto a co-op start: no starting salvage, the co-op tip
		s.player.sal = 0
		main.hud.tip = "Walk next to a wood pile to gather. Delgado is gathering too."
	main.toasts.clear()
	s.game.paused = true
	await _frames(4)


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
		for name in ["build", "raid", "blackout", "base", "ffa"]:
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
	print("RESULT " + ("PASS" if fails == 0 else "FAIL %d" % fails))
	quit(1 if fails else 0)
