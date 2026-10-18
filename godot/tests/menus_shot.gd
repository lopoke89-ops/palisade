extends SceneTree
## Every menu page, as the browser's desktop reference shots name them:
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1600x900 --script res://tests/menus_shot.gd -- out_prefix [page,page,...]
## Pages: 01_home 02_multi 02_locker 02_skills 02_tables 02_classes 02_settings 03_account 04_index_raiders
## 04_index_bosses 05_setup_map 05_setup_rules 05_setup_job 05_setup_mods 06_locker 07_friends 08_lobby 10_pause
## 11_armory 12_results 13_case. Writes <prefix><page>.png. Prints FAIL lines for errors it can see.

var fails := 0
var pre := ""


func _init() -> void:
	_run.call_deferred()


func _shot(name: String, frames: int = 8) -> void:
	for n in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(pre + name + ".png")
	print("wrote ", pre + name + ".png")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	pre = args[0] if args.size() > 0 else "user://menus_"
	var only: Array = args[1].split(",") if args.size() > 1 else []
	var want := func(n: String) -> bool: return only.is_empty() or only.has(n)
	PalAccount.offline = true
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	for n in 5:
		await process_frame
	main.locker.persist = false
	main.profile.persist = false
	main.settings.data.name = "Big U"
	main.locker.cloud = {}
	main.locker.eq = {"skin": "std", "hat": "class", "trail": "std", "fx": "none", "bg": "campfire"}
	main.locker.cases = 1
	main.locker.bag = {}
	main.locker.shards = 0
	main.profile.sp = 0
	main.settings.data.setup = {"mode": "5", "map": "yard", "size": "std", "diff": "normal", "cls": "soldier", "mods": [], "pvp": "coop"}
	var M: Menus = main.menus
	if want.call("01_home"):
		M.show_main()
		await _shot("01_home", 20)
	for s in [["05_setup_map", "map"], ["05_setup_rules", "rules"], ["05_setup_job", "job"], ["05_setup_mods", "mods"]]:
		if want.call(s[0]):
			M.show_main()
			M._open_sheet(s[1], "home")
			await _shot(s[0])
			M.close_sheet()
	if want.call("02_multi"):
		M.show_online("")
		await _shot("02_multi")
	if want.call("02_locker") or want.call("06_locker"):
		M.show_locker()
		await _shot("06_locker", 12)
	if want.call("02_skills"):
		M.show_skills()
		await _shot("02_skills")
	if want.call("02_tables"):
		M.show_tables()
		await _shot("02_tables")
	if want.call("02_classes"):
		M.show_index("classes")
		await _shot("02_classes")
	if want.call("04_index_raiders"):
		M.show_index("raiders")
		await _shot("04_index_raiders")
	if want.call("04_index_bosses"):
		M.show_index("bosses")
		await _shot("04_index_bosses")
	if want.call("02_settings"):
		M.show_settings()
		await _shot("02_settings")
	if want.call("03_account"):
		M.show_account()
		await _shot("03_account")
	if want.call("07_friends"):
		M.show_main()
		await process_frame
		M.show_friends()
		await _shot("07_friends")
		M.close_friends()
	if want.call("08_lobby"):
		# a room without the network: the lobby page reads the PalNet state
		var n: PalNet = main.net
		n.mode = "host"
		n.code = "NT5J"
		n.my_id = "host"
		n.roster = [{"id": "host", "name": "Big U", "cls": "soldier", "cos": "std|class|std|none", "team": "a", "ready": true}]
		n.pick = {"diff": "normal", "mode": "5", "pvp": "coop", "map": "yard", "size": "std", "mods": [], "job": ""}
		M.show_lobby()
		await _shot("08_lobby", 12)
		n.mode = "solo"
		n.code = ""
		n.roster = []
		M.show_main()
	if want.call("13_case"):
		M.show_locker()
		await process_frame
		var ui: LockerUI = M._lockers(M.root)[0]
		ui.open_cases("supply", 1)
		await _shot("13_case_intro", 40)
		for i in 200:
			await process_frame
		await _shot("13_case_reel", 2)
		var ov: CaseOpen = ui.get_children().filter(func(x): return x is CaseOpen)[0]
		ov.reveal()
		await _shot("13_case_result", 20)
		ov.close()
	if want.call("10_pause") or want.call("11_armory") or want.call("12_results"):
		main.start_game()
		for i in 30:
			await process_frame
		if want.call("10_pause"):
			main.do_action("pause")
			await _shot("10_pause")
			main.do_action("pause")
		if want.call("11_armory"):
			main.sim.player.sal = 200
			main.armory_open = true
			main.sim.game.paused = true
			await _shot("11_armory")
			main._close_armory()
		if want.call("12_results"):
			main.sim.game.wave = 3
			main.sim.game.phase = "over"
			main.sim.game.won = false
			for i in 120:
				await process_frame
			await _shot("12_results", 30)
	print("RESULT " + ("PASS" if fails == 0 else "FAIL %d" % fails))
	quit(1 if fails else 0)
