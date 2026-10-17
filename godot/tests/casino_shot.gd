extends SceneTree
## The casino sheets on screen, every game, against the local tables server (tests/tables_server.js; never the real
## project):  xvfb-run -a godot --path godot --rendering-driver opengl3 --script res://tests/casino_shot.gd -- out_prefix

const PORT := 18798
const A := "a0000000-0000-4000-8000-00000000000a"

var pid := -1
var pre := "user://casino"
var main: Node2D
var ui: CasinoUI
var room := "SOLO:a0000000:s%d" % Time.get_ticks_msec()


func transport(method: String, path: String, body, headers: PackedStringArray) -> Dictionary:
	return await _http(method, path, body, headers)


func _http(method: String, path: String, body, headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	var req := HTTPRequest.new()
	root.add_child(req)
	req.request("http://127.0.0.1:%d%s" % [PORT, path], headers, HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_GET, JSON.stringify(body) if body != null else "")
	var res: Array = await req.request_completed
	req.queue_free()
	var t: String = (res[3] as PackedByteArray).get_string_from_utf8()
	return {"ok": res[1] >= 200 and res[1] < 300, "status": res[1], "j": JSON.parse_string(t) if t != "" else null}


func advance(ms: int) -> void:
	await _http("POST", "/test/advance", {"ms": ms})


func _init() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		pre = OS.get_cmdline_user_args()[0]
	PalAccount.offline = true
	pid = OS.create_process("node", [ProjectSettings.globalize_path("res://tests/tables_server.js"), str(PORT)])
	for i in 80:
		await create_timer(0.25).timeout
		var req := HTTPRequest.new()
		root.add_child(req)
		req.request("http://127.0.0.1:%d/test/ping" % PORT, [], HTTPClient.METHOD_POST, "{}")
		var r: Array = await req.request_completed
		req.queue_free()
		if r[0] == HTTPRequest.RESULT_SUCCESS:
			break
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.locker.persist = false
	main.profile.persist = false
	for n in 20:
		await process_frame
	main.menus.close()   # the demo yard stands in for the casino floor
	ui = CasinoUI.new(main)
	ui.persist_seed = false
	ui.sync_locker = false
	root.add_child(ui)
	await process_frame
	# signed out
	ui.tables.account = PalAccount.new(main)
	ui.open(11, room)
	await _shot("signed_out")
	ui.close()
	var acct: PalAccount = main.account
	acct.transport = transport
	acct.s = {"access_token": "tok-a", "refresh_token": "r", "expires_at": 9e9, "user": {"id": A, "is_anonymous": false}}
	acct.state = "full"
	ui.tables.account = acct
	ui.tables.polling = false
	await _blackjack()
	await _holdem()
	await _roulette()
	await _baccarat()
	await _craps()
	await _slots()
	await _plinko()
	await _history()
	OS.kill(pid)
	quit()


func _sit(code: int) -> void:
	ui.open(code, room)
	for i in 80:
		await process_frame
		if ui.tables.id != 0:
			break
	await _wait(0.2)


func _send(b: Dictionary) -> Dictionary:
	b.id = ui.tables.id
	return await ui.tables.send(b)


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _shot(name: String, scroll_end: bool = false) -> void:
	for n in 8:
		await process_frame
	ui.scroll.scroll_vertical = 100000 if scroll_end else 0
	for n in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(pre + "_" + name + ".png")
	print("saved ", pre + "_" + name + ".png")


func _blackjack() -> void:
	await _sit(12)
	await _shot("bj_start")
	await _send({"op": "start"})
	await _send({"op": "topup", "amt": 100})
	ui.amt = 10
	await ui.tables.state()
	await _shot("bj_bet")
	await _send({"op": "bet", "amt": 10, "side": false})
	if ui.tables.v.phase == "ins":
		await _shot("bj_insurance")
		await _send({"op": "insure", "yes": false})
	if ui.tables.v.get("myTurn", false):
		await _shot("bj_turn")
		await _send({"op": "move", "a": "stand"})
	await _wait(0.4)
	await _shot("bj_reveal")
	await _wait(3.0)
	await _shot("bj_result")
	await _shot("bj_result_acts", true)
	ui._act("stand")
	await _wait(0.5)


func _holdem() -> void:
	await _sit(21)
	await _send({"op": "topup", "amt": 100})
	await _send({"op": "start"})
	await ui.tables.state()
	for i in 6:
		if ui.tables.v.get("myTurn", false) or ui.tables.v.phase != "play":
			break
		await advance(1400)
		await ui.tables.state()
	await _shot("he_turn")
	await _shot("he_turn_acts", true)
	for i in 40:
		if ui.tables.v.phase != "play":
			break
		if ui.tables.v.get("myTurn", false):
			await _send({"op": "move", "a": "check" if ui.tables.v.can.check else "call"})
		else:
			await advance(1400)
			await ui.tables.state()
	await _wait(3.5)
	await _shot("he_result")
	ui._act("stand")
	await _wait(0.5)


func _roulette() -> void:
	await _sit(32)
	await _send({"op": "topup", "amt": 400})
	ui.rl.chip = 25
	for k in ["n:17", "sp:20-23", "co:28", "red", "dz:2", "col:1", "sl:31", "tl"]:
		ui.rl_add(k)
	await _wait(0.6)
	await _shot("rl_bets")
	ui._act("rlspin")
	await _wait(0.5)
	await _shot("rl_spin")
	await advance(6000)
	await ui.tables.state()
	await _shot("rl_result")
	ui._act("stand")
	await _wait(0.5)


func _baccarat() -> void:
	await _sit(53)
	await _send({"op": "topup", "amt": 200})
	ui.ba.chip = 20
	for k in ["P", "B", "T"]:
		ui.ba_spot(k)
	await _wait(0.6)
	await _shot("ba_bets")
	ui._act("baready")
	await advance(5000)
	await _wait(0.4)
	await ui.tables.state()
	await _wait(1.2)
	await _shot("ba_dealing")
	await _wait(3.5)
	await _shot("ba_result")
	ui._act("stand")
	await _wait(0.5)


func _craps() -> void:
	await _sit(41)
	await _send({"op": "topup", "amt": 300})
	for i in 8:
		if int(ui.tables.v.get("point", 0)):
			break
		if not ui.tables.v.myBets.has("pass"):
			await _send({"op": "crbet", "k": "pass", "amt": 10})
		await _send({"op": "crready"})
		await advance(5000)
		await ui.tables.state()
		await advance(9000)
		await ui.tables.state()
	ui.cr.chip = 10
	if int(ui.tables.v.get("point", 0)):
		ui.cr_spot("po")
	ui.cr_spot("field")
	ui.cr_spot("p6")
	await _wait(1.5)
	await _shot("cr_point")
	ui._act("cradv")
	await _shot("cr_allbets", true)
	ui._act("cradv")
	await _send({"op": "crready"})
	await advance(5000)
	await ui.tables.state()
	await _wait(0.6)
	await _shot("cr_rolling")
	await _wait(2.0)
	await _shot("cr_result")
	ui._act("stand")
	await _wait(0.5)
	if ui.tables.id != 0:
		await advance(200000)
		await ui.tables.lobby()


func _slots() -> void:
	await _sit(105)
	await _send({"op": "topup", "amt": 100})
	ui.sl_amt = 10
	ui._act("slspin")
	await _wait(1.5)
	await _shot("sl_spinning")
	await _wait(1.6)
	await _shot("sl_result")
	ui.set_meta("paytable", true)
	ui._key_felt = ""
	await _shot("sl_paytable", true)
	ui._act("stand")
	await _wait(0.5)


func _plinko() -> void:
	await _sit(117)
	await _send({"op": "topup", "amt": 100})
	ui.pk_amt = 50
	ui._act("pkdrop")
	await _wait(1.6)
	await _shot("pk_drop")
	await _wait(2.0)
	await _shot("pk_result")
	ui.last_result()
	await _shot("last_result")
	ui._close_modal()
	# a narrow window: the sheet along the bottom
	DisplayServer.window_set_size(Vector2i(600, 900))
	root.size = Vector2i(600, 900)
	await _wait(0.6)
	await _shot("pk_narrow")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	await _wait(0.6)
	ui._act("help")
	await _shot("pk_help", true)
	ui._act("help")
	ui._act("stand")
	await _wait(0.5)


func _history() -> void:
	await _sit(103)
	ui.show_history()
	await _wait(1.0)
	for b in _buttons(ui.modal):
		if b.text == "CHECK":
			b.pressed.emit()
	await _wait(4.0)
	await _shot("history")
	ui._close_modal()
	ui._act("rules")
	await _shot("rules")
	ui._close_modal()
	ui._act("fair")
	await _shot("fair", true)


func _buttons(n: Node) -> Array:
	var o: Array = []
	for c in n.get_children():
		if c is Button:
			o.append(c)
		o.append_array(_buttons(c))
	return o
