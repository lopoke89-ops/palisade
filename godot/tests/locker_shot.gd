extends SceneTree
## The Locker on screen: xvfb-run godot --path godot --rendering-driver opengl3 --script res://tests/locker_shot.gd -- out_prefix
## (the locker is dressed in memory for the shots, never saved)


func _init() -> void:
	var pre: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://locker"
	PalAccount.offline = true   # tests never make or touch real accounts
	var main: Node2D = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var L: PalLocker = main.locker
	L.persist = false
	main.profile.persist = false
	L.cases = 3
	L.bag = {"halloween": 6, "afterglow": 1}
	L.shards = 37
	main.profile.sp = 4
	for id in ["skin:gold", "skin:neonops", "hat:crown", "hat:tophat", "trail:rainbow", "trail:plasma", "fx:supernova", "bg:aurora", "skin:tiger", "skin:arctic"]:
		L.grant(id)
	L.eq.skin = "gold"
	L.eq.hat = "crown"
	L.eq.bg = "aurora"
	main.menus.show_main()
	for n in 20:
		await process_frame
	await _save(pre + "_main.png")
	main.menus.show_locker()
	for n in 10:
		await process_frame
	await _save(pre + "_skins.png")
	LockerUI.cat = "trail"
	main.menus.show_locker()
	for n in 8:
		await process_frame
	await _save(pre + "_trails.png")
	var ui: LockerUI = main.menus.root.get_children().filter(func(c): return c is LockerUI)[0]
	L.fixed_r = 0.995
	ui.open_cases("halloween", 1)
	L.fixed_r = -1.0
	await create_timer(1.6).timeout
	await _save(pre + "_intro.png")
	await create_timer(3.4).timeout
	await _save(pre + "_reel.png")
	await create_timer(3.5).timeout
	await _save(pre + "_reveal.png")
	for ch in ui.get_children():
		if ch is CaseOpen:
			ch.close()
	await process_frame
	ui.open_cases("halloween", 5)
	await create_timer(0.3).timeout
	for ch in ui.get_children():
		if ch is CaseOpen:
			ch.reveal()
	for n in 6:
		await process_frame
	await _save(pre + "_five.png")
	main.account.state = "guest"   # the Account page as a guest sees it (no network)
	main.account.s = {"access_token": "a", "refresh_token": "r", "expires_at": 9e9, "user": {"id": "x", "is_anonymous": true}}
	main.account.name_ = "Yardhand"
	main.menus.show_account()
	for n in 6:
		await process_frame
	await _save(pre + "_account.png")
	quit()


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
