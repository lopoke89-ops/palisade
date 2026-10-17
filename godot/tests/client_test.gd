extends SceneTree
## The client around the sim: settings, key and controller bindings, the menu flow, touch sticks.
##   godot --headless --path godot --script res://tests/client_test.gd     (exit 0 = pass)

var fails := 0


func _find(n: Node, cls: String) -> Node:
	for ch in n.get_children():
		if ch.get_class() == cls:
			return ch
		var r := _find(ch, cls)
		if r != null:
			return r
	return null


func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _init() -> void:
	var keep := FileAccess.get_file_as_string(PalSettings.PATH) if FileAccess.file_exists(PalSettings.PATH) else ""   # put the player's settings back after
	var keep_l := FileAccess.get_file_as_string(PalLocker.PATH) if FileAccess.file_exists(PalLocker.PATH) else ""
	var keep_p := FileAccess.get_file_as_string(PalProfile.PATH) if FileAccess.file_exists(PalProfile.PATH) else ""
	print("settings")
	var st := PalSettings.new()
	check(st.data.keys.build == [KEY_SPACE] and st.data.pad.fire == 7 and st.data.pad.build == 0, "browser defaults: SPACE builds; RT fires, A builds")
	st.apply_keys()
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	check(InputMap.has_action("pal_build") and ev.is_action_pressed("pal_build"), "keys go into the InputMap as pal_ actions")
	check(PalSettings.glyph(7, "ps") == "R2" and PalSettings.glyph(0, "xbox") == "A", "button names follow the controller in hand")
	print("locker: the browser's run payouts (tests/locker_ref.json, from tools/locker_ref.js)")
	var ref: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/locker_ref.json"))
	for r in ref:
		var prof := PalProfile.new()
		prof.persist = false
		var L := PalLocker.new(prof)
		L.persist = false
		L.fixed_r = 0.99
		L.cases = 0
		var c: Dictionary = r.claim
		var R := L.local_run(c, int(r.shards))
		var o: Dictionary = r.out
		var st_ok := true
		for k in o.st:
			if int(L.st.get(k, 0)) != int(o.st[k]):
				st_ok = false
				print("    st ", k, " godot ", L.st.get(k, 0), " browser ", o.st[k])
		var bag_ok := true
		for k in o.bag:
			if int(L.bag.get(k, 0)) != int(o.bag[k]):
				bag_ok = false
				print("    bag ", k, " godot ", L.bag.get(k, 0), " browser ", o.bag[k])
		var unl: Array = R.unlocked.duplicate()
		unl.sort()
		var unl2: Array = o.unlocked.duplicate()
		unl2.sort()
		var same: bool = L.cases == int(o.cases) and L.shards == int(o.shards) and L.prog == int(o.prog) and prof.sp == int(o.sp) and st_ok and bag_ok and unl == unl2 and R.text == o.text
		if not same:
			print("    godot:   ", L.cases, " ", L.shards, " ", L.prog, " ", prof.sp, " ", R.text)
			print("    browser: ", o.cases, " ", o.shards, " ", o.prog, " ", o.sp, " ", o.text)
		check(same, "%s: cases, shards, milestones, skill points and unlocks match" % r.name)
	print("controller")
	var dz: Array = PalInput.deadzone(Vector2(0.1, 0), 0.2)
	var full: Array = PalInput.deadzone(Vector2(1, 0), 0.2)
	check(dz[1] == 0.0 and is_equal_approx(full[1], 1.0), "stick deadzone: the middle is ignored, the rest stretched to 0..1")
	PalAccount.offline = true   # tests never make or touch real accounts
	var main: Node2D = load("res://main.tscn").instantiate()
	root.add_child(main)
	for n in 5:
		await process_frame
	main.locker.cloud = {}   # whatever the PC's own locker is, the tests play it as a local one
	main.profile.cloud = false
	print("menus")
	check(main.demo and main.menus.screen == "main", "it opens on the main menu over the demo yard")
	check(main._controls().is_empty(), "nobody plays the demo")
	main.settings.data.setup = {"mode": "blitz", "map": "river", "size": "std", "diff": "hard", "cls": "sniper", "mods": ["elite", "bossrush"]}
	main.start_game()
	check(not main.demo and main.sim.game.mode == "blitz" and main.sim.map_id == "river" and main.sim.player.cls == "sniper" and main.sim.mods == ["elite"], "PLAY starts Match Setup's game (Blitz drops modifiers it doesn't allow)")
	main.do_action("pause")
	check(main.sim.game.paused and main.menus.screen == "pause", "pause opens the pause menu")
	main.do_action("pause")
	check(not main.sim.game.paused and not main.menus.active(), "and closes it")
	print("cosmetics in play")
	main.locker.eq.trail = "f_pride"
	main.locker.eq.fx = "supernova"
	main._dress(main.sim.player)
	var sp: Dictionary = main.sim.player
	check(sp.trail == "f_pride" and sp.tsnd == "ts_grainbow" and sp.tcyc == 6 and sp.kfx == "supernova", "the soldier wears the locker's tracer and kill effect")
	var nb: int = main.sim.bullets.size()
	main.sim.shoot(sp, sp.gun, 0.0)
	main.sim.shoot(sp, sp.gun, 0.0)
	check(main.sim.bullets.size() > nb and main.sim.bullets[-1].tr == "f_pride" and main.sim.bullets[-1].tc == 1, "rounds carry the tracer, a flag tracer one colour per round")
	main.cparts.clear()
	main.kill_fx(sp.x + 2, sp.y, "supernova")
	check(main.cparts.any(func(q): return q.kind == "finish:supernova") and main.cparts.size() > 10, "a kill paints its finisher and throws its particles")
	main.sim.bullets.resize(nb)
	main.locker.eq.trail = "std"
	main.locker.eq.fx = "none"
	main.do_action("mat2")
	check(main.sim.game.sel == 1, "actions reach the game: brick picked")
	main.menus.came_from = "main"
	main.menus.show_controls()
	main.menus.binding = "k:build"
	var k := InputEventKey.new()
	k.keycode = KEY_B
	k.pressed = true
	main.menus.bind_key(k)
	var k2 := InputEventKey.new()
	k2.keycode = KEY_B
	k2.pressed = true
	check(main.settings.data.keys.build == [KEY_B] and k2.is_action_pressed("pal_build"), "rebinding a key: BUILD on B")
	main.menus.binding = "k:nade"
	main.menus.bind_key(k)
	check(main.settings.data.keys.nade == [KEY_B] and main.settings.data.keys.build.is_empty(), "a key does one thing: GRENADE takes B from BUILD")
	main.settings.reset_keys()
	main.settings.apply_keys()
	main.menus.close()
	print("touch")
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = Vector2(main.v.W * 0.1, 500)
	t.pressed = true
	main.inp.handle(t)
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = Vector2(main.v.W * 0.1 + 56, 500)
	main.inp.handle(d)
	check(main.inp.mode == "touch" and is_equal_approx(main.inp.stick_move.v.x, 1.0), "the left thumb is a move stick")
	var c: Dictionary = main._controls()
	check(c.move.length() > 0.9, "and it walks the soldier (%.2f)" % c.move.length())
	main.sim.game.phase = "over"
	await create_timer(1.3).timeout
	check(main.menus.screen == "results", "the after-action screen comes up at the end")
	check(not main.last_reward.is_empty() and main.last_reward.text.ends_with("."), "and the run is paid into the locker (%s)" % main.last_reward.get("text", ""))
	check(_find(main.menus.root, "HFlowContainer") != null, "the rewards come as cards")
	main.to_menu()
	check(main.demo and main.menus.screen == "main", "MAIN MENU goes back to the demo yard")
	var bg0 = main.menus.root.get_child(0)
	check((bg0 is Lobby3D) if Lobby3D.available() else (bg0 is LockerUI.BgView), "outside a game the menus sit on the lobby (the 3D stage, or the painted background without the models)")
	print("accounts (a stand-in server)")
	print("leaving a run early")
	main.locker.cloud = {}
	main.locker.persist = false
	main.start_game()
	var raids0: int = main.locker.st.raids
	main.sim.start_raid()
	main.sim.game.wave = 3
	main.sim.start_build(30.0)   # raid 3 broken: three raids held
	check(PalLocker.held_now(main.sim) == 3 and PalLocker.draft_due(main.sim), "three raids held: leaving now would pay for them")
	main.to_menu()
	check(main.locker.st.raids == raids0 + 3 and main.demo, "QUIT TO MENU pays the raids held so far (%d -> %d)" % [raids0, main.locker.st.raids])
	main.start_game()
	main.to_menu()
	check(main.locker.st.raids == raids0 + 3, "a run with nothing held pays nothing")
	await _accounts(main)
	print("locker screen")
	var L: PalLocker = main.locker
	L.cases = 2
	L.bag = {"halloween": 0}
	L.shards = 30
	main.profile.sp = 5
	main.menus.show_locker()
	await process_frame
	var ui: LockerUI = main.menus.root.get_children().filter(func(n): return n is LockerUI)[0]
	check(main.menus.screen == "locker" and ui.tiles.size() > 0, "the Locker opens on its tiles (%d)" % ui.tiles.size())
	var before := L.owned.size() + L.shards
	ui.open_cases("supply", 1)
	check(L.cases == 1 and L.owned.size() + L.shards > before, "OPEN takes a case and pays out before the show")
	var ov: CaseOpen = ui.get_children().filter(func(n): return n is CaseOpen)[0]
	ov.reveal()
	check(ov.phase == "reveal" and ov.done_b.visible, "SKIP goes straight to what it gave")
	ov.close()
	await process_frame
	ui = main.menus.root.get_children().filter(func(n): return n is LockerUI)[0]
	var halloween := L.case_count("halloween")
	ui._render_boxes()
	check(L.buy_case("halloween") and L.case_count("halloween") == halloween + 1 and L.shards == 18, "BUY trades 12 shards for a Halloween Case")
	ui._buy_sp()
	check(main.profile.sp == 5 and L.cases == 1, "the skill-point buy needs a second press")
	ui._buy_sp()
	check(main.profile.sp == 2 and L.cases == 2, "and then trades 3 skill points for a Supply Case")
	L.grant("bg:aurora")
	ui._equip(PalLocker.item("bg:aurora"))
	await process_frame
	check(L.eq.bg == "aurora" and main.menus.root.get_children().any(func(n): return (n is LockerUI.BgView and n.id == "aurora") or (n is Lobby3D and n.bg == "aurora" and n.env_root.get_child_count() == 1)), "equipping a background puts it behind the menus")
	ui._equip(PalLocker.item("hat:witch"))
	check(L.eq.hat != "witch" and ui.msg.text != "", "locked items say how to get them")
	main.menus.show_main()
	if keep != "":
		var f := FileAccess.open(PalSettings.PATH, FileAccess.WRITE)
		f.store_string(keep)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PalSettings.PATH))
	for kp in [[PalLocker.PATH, keep_l], [PalProfile.PATH, keep_p]]:
		if kp[1] != "":
			var f2 := FileAccess.open(kp[0], FileAccess.WRITE)
			f2.store_string(kp[1])
		elif FileAccess.file_exists(kp[0]):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(kp[0]))
	print("\nALL PASSED" if fails == 0 else "\nFAILED %d" % fails)
	quit(1 if fails else 0)


## a fake Supabase: the account's calls are answered from here, and logged
class Fake:
	var log: Array = []
	var locker := {"owned": ["skin:std", "hat:class", "hat:cap", "trail:std", "fx:none", "bg:campfire"], "eq": {"skin": "std"}, "cases": 1, "bag": {}, "shards": 0, "prog": 0,
		"st": {"raids": 0}, "sp": 2, "sp_prog": 1, "sp_total": 2, "skills": {"dmg": 1}, "imported": false}
	var imported: Dictionary = {}
	var claim_status := 200
	var open_status := 200
	var opens := {}   # operation -> results (the server's idempotency)
	var expired_once := false

	static func tok(sub: String, exp: int) -> String:
		var b := Marshalls.utf8_to_base64(JSON.stringify({"sub": sub, "exp": exp})).replace("+", "-").replace("/", "_").replace("=", "")
		return "h." + b + ".s"

	func call_(method: String, path: String, body, _h) -> Dictionary:
		log.append(method + " " + path.split("?")[0])
		var now := int(Time.get_unix_time_from_system())
		if path.begins_with("/auth/v1/signup"):
			return {"ok": true, "status": 200, "j": {"access_token": tok("guest-1", now + 3600), "refresh_token": "r1", "expires_in": 3600, "user": {"id": "guest-1", "is_anonymous": true}}}
		if path.begins_with("/auth/v1/token?grant_type=refresh_token"):
			return {"ok": true, "status": 200, "j": {"access_token": tok("guest-1", now + 3600), "refresh_token": "r2", "expires_in": 3600, "user": {"id": "guest-1", "is_anonymous": true}}}
		if path.begins_with("/auth/v1/user"):
			return {"ok": true, "status": 200, "j": {"id": "guest-1", "is_anonymous": true}}
		if path.begins_with("/rest/v1/profiles"):
			return {"ok": true, "status": 200, "j": [{"username": "tester"}]}
		match path:
			"/rest/v1/rpc/get_my_locker":
				return {"ok": true, "status": 200, "j": locker}
			"/rest/v1/rpc/import_local_save":
				imported = body.p_save
				locker.imported = true
				locker.shards = int(body.p_save.shards)
				return {"ok": true, "status": 200, "j": locker}
			"/rest/v1/rpc/claim_match_reward":
				if claim_status != 200:
					return {"ok": false, "status": claim_status, "j": {"message": "That raid count doesn't add up"}}
				locker.cases += 1
				return {"ok": true, "status": 200, "j": {"locker": locker, "cases_granted": 1, "shards": 2, "skill_points": 1, "to_next": 2}}
			"/rest/v1/rpc/open_cases_v0964":
				if open_status != 200:
					return {"ok": false, "status": open_status, "j": {"message": "Not enough cases for this opening."}}
				if not opens.has(body.p_operation):
					opens[body.p_operation] = [{"item": {"id": "skin:forest", "rarity": "r"}, "dup": false, "shards": 0}]
					locker.cases -= 1
					locker.owned.append("skin:forest")
				return {"ok": true, "status": 200, "j": {"locker": locker, "results": opens[body.p_operation]}}
			"/rest/v1/rpc/buy_case":
				return {"ok": false, "status": 400, "j": {"message": "Not enough shards"}}
		return {"ok": false, "status": 404, "j": {"message": "no route"}}


func _accounts(main) -> void:
	var F := Fake.new()
	var A: PalAccount = main.account
	A.persist = false
	A.transport = F.call_
	var L: PalLocker = main.locker
	var keep := {"owned": L.owned.duplicate(), "eq": L.eq.duplicate(), "cases": L.cases, "bag": L.bag.duplicate(), "shards": L.shards, "prog": L.prog, "st": L.st.duplicate()}
	L.persist = false
	main.profile.persist = false
	L.norm({})
	L.shards = 9   # progress made on this PC with no account
	await A.boot()
	check(A.state == "guest" and A.uid() == "guest-1" and L.cloud.get("id") == "guest-1", "a guest account is made quietly at start, and the locker becomes its copy")
	check(int(F.imported.get("shards", -1)) == 9 and L.shards == 9, "this PC's own progress goes into the account once (import_local_save)")
	check(main.profile.cloud and main.profile.sp == 2 and main.profile.level("dmg") == 1, "the skill tree comes from the account")
	check(F.log.has("POST /rest/v1/rpc/get_my_locker") and A.name_ == "tester", "and the username with it")
	# a run: the server checks and pays it
	main.sim.game.phase = "over"
	var R: Dictionary = L.pay_run(main.sim)
	check(R.get("pending", false) and A.claims.size() <= 1, "a finished run goes to the account's server (%s)" % R.text)
	for n in 5:
		await process_frame
	check(A.claims.is_empty() and L.cases == 2 and main.profile.sp == 2, "the server paid it: its case is in the locker")
	var got := []
	A.claim_done.connect(func(c, r2, big): got.append([r2, big]), CONNECT_ONE_SHOT)
	F.claim_status = 400
	L.pay_run(main.sim)
	for n in 5:
		await process_frame
	check(A.claims.is_empty() and got.size() == 1 and got[0][1] == "NOT SAVED", "a refused result is said plainly, not dropped quietly")
	F.claim_status = 0
	L.pay_run(main.sim)
	for n in 5:
		await process_frame
	check(A.claims.size() == 1, "with no connection the result waits in the queue")
	F.claim_status = 200
	await A.flush_claims()
	check(A.claims.is_empty(), "and goes when the connection is back")
	# cases: the server rolls; an answer that never came back is resumed with the same operation
	var before := L.case_count("supply")
	var res: Dictionary = await A.open_cases("supply", 1)
	check(res.ok and res.results[0].it.id == "skin:forest" and L.owns("skin:forest") and L.case_count("supply") == before - 1, "OPEN goes to the server, which rolls the case")
	F.open_status = 0
	A.persist = true   # the saved opening needs its file
	var lost: Dictionary = await A.open_cases("supply", 1)
	var pend := A.pending_opening()
	check(not lost.ok and lost.uncertain and pend.get("case") == "supply", "a lost answer keeps the opening to resume")
	F.open_status = 200
	F.opens[pend.operation] = [{"item": {"id": "hat:beanie", "rarity": "c"}, "dup": false, "shards": 0}]
	var again: Dictionary = await A.open_cases("supply", 1, pend)
	check(again.ok and again.results[0].it.id == "hat:beanie", "RESUME gets the same results back, not another opening")
	A.clear_opening()
	F.open_status = 400
	var no: Dictionary = await A.open_cases("supply", 1)
	check(not no.ok and not no.uncertain and A.pending_opening().is_empty(), "a refusal opens nothing and keeps nothing")
	A.persist = false
	var e: String = await A.buy_case("halloween")
	check(e == "Not enough shards", "the server's answers come through in plain words")
	# an expired sign-in is refreshed before the call
	A.s.expires_at = 0
	F.log.clear()
	await A.rpc_call("get_my_locker")
	check(F.log.size() == 2 and F.log[0].begins_with("POST /auth/v1/token"), "an expired sign-in is refreshed first")
	# back to a local locker for the rest of the tests
	A.transport = Callable()
	A.s = {}
	A.state = "off"
	L.norm(keep)
	L.cloud = {}
	main.profile.from_cloud({})
	main.profile.cloud = false
	main.sim.game.phase = "build"
