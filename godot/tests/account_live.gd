extends SceneTree
## The live check against the real account server (not part of the normal tests: it makes a real guest account).
##   godot --headless --path godot --script res://tests/account_live.gd -- [name]
## It makes one guest, names it (godot_test_…), loads its locker, sends a short run, opens its welcome case, equips
## what came out, tries a purchase it can't afford and refreshes its sign-in, then prints the account's ID so it
## can be deleted. Nothing on this PC is touched: the locker, profile and sign-in stay in memory.


class Host extends Node:
	var locker: PalLocker
	var profile: PalProfile


func _init() -> void:
	var tag: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "godot_test_%04d" % (randi() % 10000)
	var host := Host.new()
	host.profile = PalProfile.new()
	host.profile.persist = false
	host.locker = PalLocker.new(host.profile)
	host.locker.persist = false
	root.add_child(host)
	var A := PalAccount.new(host)
	A.persist = false
	host.add_child(A)
	host.locker.account = A
	await process_frame
	var t0 := Time.get_unix_time_from_system()
	await A.boot()
	print("boot: ", A.state, " uid ", A.uid(), " ", A.msg)
	if A.state != "guest":
		quit(1)
		return
	print("locker: cases %d shards %d owned %d sp %d" % [host.locker.cases, host.locker.shards, host.locker.owned.size(), host.profile.sp])
	print("username: ", await A.set_username(tag))
	await A.load_profile()
	print("profile name: ", A.name_)
	# a short run, sent once the account is old enough for its length (the server's play-time check)
	var wait := 31.0 - (Time.get_unix_time_from_system() - t0)
	if wait > 0:
		await create_timer(wait).timeout
	var c := {"kind": "run", "mode": "5", "diff": "normal", "win": false, "held": 0, "raid_from": 0, "raid_to": 0, "kills": 3, "bosses": 0, "boss_keys": [],
		"shard_bosses": 0, "sb_keys": [], "salvage": 0, "size": "std", "duration_s": 30, "game_id": "godottest-" + tag, "joined_s": 0, "left_s": 30, "left": false,
		"upgrades": "00000:0", "mods": [], "map": "yard", "cls": "soldier", "end_reason": "", "cv": 4, "claim_id": "godottest-%s:0:0:0:30" % tag}
	var got := []
	A.claim_done.connect(func(_c, R, big): got.append([R, big]))
	host.locker.cloud = {"id": A.uid(), "guest": true}
	A.queue_claim(c)
	while A._flushing:
		await process_frame
	print("claim: ", got[0][1] if got.size() else "still queued", " · ", (got[0][0].text if got[0][0] is Dictionary else got[0][0]) if got.size() else "")
	# the welcome case
	if host.locker.case_count("supply") > 0:
		var res: Dictionary = await A.open_cases("supply", 1)
		if res.ok:
			var it: Dictionary = res.results[0].it
			print("opened: ", it.name, " (", it.r, ")", " dup" if res.results[0].dup else " new")
			if not res.results[0].dup and host.locker.equip(it.id):
				await A.equip(it.id)
				var r := await A.rpc_call("get_my_locker")
				print("equipped on the account: ", r.j.eq.get(it.cat) == it.key if r.ok else r.status)
		else:
			print("open failed: ", res.err)
	print("buy without shards: ", await A.buy_case("halloween"))
	A.s.expires_at = 0
	var r2 := await A.rpc_call("get_my_locker")
	print("refreshed sign-in: ", r2.ok)
	print("TEST ACCOUNT ", A.uid(), " ", tag)
	quit(0)
