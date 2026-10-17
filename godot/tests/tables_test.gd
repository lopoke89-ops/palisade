extends SceneTree
## The casino's tables, played for real: PalTables and the CasinoUI sheet against the real `tables` request handler on a
## disposable local Postgres (tests/tables_server.js, started here; the real Supabase project is never touched).
##   godot --headless --path godot --script res://tests/tables_test.gd      (prints ALL PASSED; exit 0 = pass)
## Every game is played through: sit, bet, act, the result and its receipt, balances moving exactly as the server says,
## a money move whose answer is lost and retried with the same operation id (never paid twice), and the fairness CHECK
## on real hand histories (and failing on tampered ones).

const PORT := 18797
const A := "a0000000-0000-4000-8000-00000000000a"
const B := "b0000000-0000-4000-8000-00000000000b"

var fails := 0
var pid := -1
var lose_next := 0   # the server answers the next N table calls, and the answers are "lost" on the way back
var calls := 0
var main: Node2D
var room := "SOLO:a0000000:t%d" % Time.get_ticks_msec()


func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


## the network, for the account: straight to the local server
func transport(method: String, path: String, body, headers: PackedStringArray) -> Dictionary:
	var r := await _http(method, path, body, headers)
	if path == PalTables.PATH:
		calls += 1
		if lose_next > 0:   # the server did the move; the answer never arrives (a timeout)
			lose_next -= 1
			return {"ok": false, "status": 0, "j": null}
	return r


func _http(method: String, path: String, body, headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 20
	root.add_child(req)
	var err := req.request("http://127.0.0.1:%d%s" % [PORT, path], headers, HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_GET, JSON.stringify(body) if body != null else "")
	if err != OK:
		req.queue_free()
		return {"ok": false, "status": 0, "j": null}
	var res: Array = await req.request_completed
	req.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "j": null}
	var t: String = (res[3] as PackedByteArray).get_string_from_utf8()
	return {"ok": res[1] >= 200 and res[1] < 300, "status": res[1], "j": JSON.parse_string(t) if t != "" else null}


func advance(ms: int) -> void:
	await _http("POST", "/test/advance", {"ms": ms})


func balance(tok: String) -> int:
	var r := await _http("POST", "/test/balance", {"token": tok})
	return int(r.j.shards)


func account(tok: String, uid: String) -> PalAccount:
	var a := PalAccount.new(main)
	a.persist = false
	a.transport = transport
	a.s = {"access_token": tok, "refresh_token": "r", "expires_at": 9e9, "user": {"id": uid, "is_anonymous": false}}
	a.state = "full"
	root.add_child(a)
	return a


func client(tok: String, uid: String) -> PalTables:
	var t := PalTables.new(account(tok, uid))
	t.polling = false
	t.retry_wait = 0.05
	root.add_child(t)
	return t


func _init() -> void:
	PalAccount.offline = true   # no real accounts, ever
	pid = OS.create_process("node", [ProjectSettings.globalize_path("res://tests/tables_server.js"), str(PORT)])
	var up := false
	for i in 80:
		await create_timer(0.25).timeout
		var r := await _http("POST", "/test/ping", {})
		if r.ok:
			up = true
			break
	check(up, "the local tables server is up (the real handler on PGlite)")
	if not up:
		_end()
		return
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.locker.persist = false
	main.profile.persist = false
	await _signed_out()
	await _slots()
	await _plinko()
	await _roulette()
	await _baccarat()
	await _craps()
	await _blackjack()
	await _holdem()
	await _sheet()
	_end()


func _end() -> void:
	if pid > 0:
		OS.kill(pid)
	print("ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)


func _signed_out() -> void:
	print("signed out, guests")
	var t := PalTables.new(PalAccount.new(main))
	root.add_child(t)
	check(t.cant_play() == "Sign in to play at the tables.", "no account: 'Sign in to play at the tables.'")
	var g := client("tok-g", "d0000000-0000-4000-8000-00000000000d")
	g.account.s.user.is_anonymous = true
	check(g.cant_play().begins_with("Make an account on the Account page"), "a guest is told to make an account")
	var r := await g.call_api({"op": "lobby"})
	check(str(r.get("error", "")).contains("guests can't"), "the server refuses a guest too: " + str(r.get("error")))
	var ui := CasinoUI.new(main)
	ui.tables.account = PalAccount.new(main)
	root.add_child(ui)
	await process_frame
	ui.open(31, room)
	await process_frame
	check(ui.is_open() and ui.status_s.text == "Sign in to play at the tables.", "the sheet says so instead of a table")
	ui.close()
	check(not ui.is_open(), "close() hides it")
	ui.queue_free()


func _slots() -> void:
	print("slots")
	var t := client("tok-a", A)
	var b0 := await balance("tok-a")
	var r := await t.sit(room, "sl", 0, "s1")
	check(t.id > 0 and int(t.v.me) == 0 and t.v.game == "sl" and t.balance == b0 - 5, "sit at cabinet 1: the 5-shard buy-in")
	r = await t.send({"op": "topup", "id": t.id, "amt": 100})
	check(int(t.v.seats[0].stack) == 105 and t.balance == b0 - 105, "top up 100")
	lose_next = 1   # the next answer is lost: PalTables resends the same operation id
	var c0 := calls
	r = await t.send({"op": "topup", "id": t.id, "amt": 50})
	check(calls - c0 == 2 and r.get("replay", false), "a lost answer is retried with the same id and answered from the server's record")
	check(int(t.v.seats[0].stack) == 155 and await balance("tok-a") == b0 - 155, "the retried top-up moved 50 shards once, not twice")
	check(t.pend.is_empty(), "the operation id is let go once the server has answered")
	var stack := int(t.v.seats[0].stack)
	lose_next = 1
	var got := {}
	t.receipt.connect(func(rc): got.rc = rc, CONNECT_ONE_SHOT)
	r = await t.send({"op": "spin", "id": t.id, "amt": 5})
	var res: Dictionary = r.rcpt.result if r.get("rcpt") is Dictionary else {}
	check(r.get("replay", false) and not res.is_empty() and got.has("rc"), "a spin whose answer was lost: the replay brings its receipt")
	var p: Dictionary = res.players[0]
	check(int(p.bet) == 5 and int(p.back) == 5 * int(res.mult) and int(t.v.seats[0].stack) == stack - 5 + int(p.back), "one spin of 5: the stack moves by exactly the receipt's net (%+d)" % int(p.net))
	check(int(t.v.handNo) == 1, "the retried spin spun once")
	r = await t.send({"op": "spin", "id": t.id, "amt": 5})
	check(str(r.get("error", "")).contains("still turning"), "no new spin while the reels and the review are up")
	await advance(2600 + 3000)
	await t.state()
	check(t.v.phase == "idle", "after the reveal and the 3 s review the machine is ready")
	r = await t.send({"op": "spin", "id": t.id, "amt": 100})
	check(int(t.v.handNo) == 2 and int(r.rcpt.result.players[0].bet) == 100, "a 100 spin")
	await t.history()
	var h: Dictionary = t.hist.filter(func(x): return x.game == "sl")[0]
	var ok: Array = await t.verify(h)
	check(ok[0] == true, "CHECK a spin: " + str(ok[1]))
	var bad := h.duplicate(true)
	bad.result.stops[0] = (int(bad.result.stops[0]) + 1) % 20
	check((await t.verify(bad))[0] == false, "CHECK fails on a tampered spin")
	var bs := h.duplicate(true)
	bs.seed = "f" + str(bs.seed).substr(1)
	check((await t.verify(bs))[0] == false, "CHECK fails when the seed doesn't match its fingerprint")
	var before := await balance("tok-a")
	stack = int(t.v.seats[0].stack)
	await t.leave()
	check(t.id == 0 and await balance("tok-a") == before + stack, "stand up: the machine's %d shards go home" % stack)


func _plinko() -> void:
	print("plinko")
	var t := client("tok-a", A)
	await t.sit(room, "pk", 0, "p1")
	await t.send({"op": "topup", "id": t.id, "amt": 100})
	var r := await t.send({"op": "drop", "id": t.id, "amt": 15})
	check(str(r.get("error", "")).contains("10s"), "stakes go in 10s")
	var stack := int(t.v.seats[0].stack)
	r = await t.send({"op": "drop", "id": t.id, "amt": 50})
	var res: Dictionary = r.rcpt.result
	var pocket := 0
	for x in res.path:
		pocket += int(x)
	check(res.path.size() == 12 and int(res.pocket) == pocket, "twelve bounces; the pocket is the number of rights (%d)" % pocket)
	check(int(t.v.seats[0].stack) == stack - 50 + int(res.players[0].back) and int(res.players[0].back) == 50 * CasinoUI.PK_MULT_D[pocket] / 10, "pays %sx: the stack moves by the receipt" % PalTables.js(res.mult))
	await t.history()
	var h: Dictionary = t.hist.filter(func(x): return x.game == "pk")[0]
	check((await t.verify(h))[0] == true, "CHECK a drop reruns its path")
	var bad := h.duplicate(true)
	bad.result.path[3] = 1 - int(bad.result.path[3])
	check((await t.verify(bad))[0] == false, "CHECK fails on a tampered path")
	await t.leave()


func _roulette() -> void:
	print("roulette")
	var t := client("tok-a", A)
	await t.sit(room, "rl", 2)
	check(int(t.v.me) == 2 and t.v.phase == "bet", "seat 3 at roulette (the seat walked up to); betting is open")
	await t.send({"op": "topup", "id": t.id, "amt": 400})
	# every spot the board's hit zones and its controller cursor can produce is a real spot on the server's layout
	var spots := {}
	for xi in 26:
		for yi in 13:
			var k := CasinoUI.rl_spot_at(-1.0 + xi * 0.5 + (0.25 if xi % 2 else 0.0), yi * 0.25)
			if k != "":
				spots[k] = 1
	for xi in 200:
		var k := CasinoUI.rl_spot_at(randf_range(-1, 12), randf_range(0, 3))
		spots[k] = 1
	for o in CasinoUI.RL_OUT:
		spots[o[0]] = 1
	for c in [1, 2, 3]:
		spots["col:%d" % c] = 1
	var keys := spots.keys()
	var all_ok := true
	for i in range(0, keys.size(), 60):
		var bets := {}
		for k in keys.slice(i, i + 60):
			bets[k] = 1
		var r := await t.send({"op": "rlbets", "id": t.id, "bets": bets})
		if r.get("error"):
			all_ok = false
			print("    refused: ", r.error, " ", bets.keys())
	check(all_ok and keys.size() > 120, "all %d spots the board can put a chip on are spots the server takes" % keys.size())
	check(CasinoUI.rl_hit(0, 2, 0.1, 0.5) == "sp:0-1" and CasinoUI.rl_hit(3, 1, 0.5, 0.95) == "sp:10-11" and CasinoUI.rl_hit(3, 2, 0.9, 0.9) == "sl:10" and CasinoUI.rl_hit(5, 0, 0.5, 0.5) == "n:18" and CasinoUI.rl_spot_at(-0.5, 1.5) == "sp:0-37", "hit zones: line, split, six line, number, 0-00")
	var stack := int(t.v.seats[2].stack) + CasinoUI.sum(t.v.myBets)
	var bets := {"red": 10, "n:17": 2, "dz:2": 5, "sp:0-37": 1}
	await t.send({"op": "rlbets", "id": t.id, "bets": bets})
	check(int(t.v.seats[2].stack) == stack - 18, "18 on the board leaves the stack 18 lower")
	await t.send({"op": "rlready", "id": t.id})
	check(t.v.phase == "spin" and t.v.has("number"), "SPIN: everyone with a bet is ready, the ball goes")
	await advance(6000)
	await t.state()
	var res: Dictionary = t.v.last.result
	var n := int(res.number)
	var back := (20 if CasinoUI.RL_RED.has(n) else 0) + (72 if n == 17 else 0) + (15 if n >= 13 and n <= 24 else 0) + (18 if n == 0 or n == 37 else 0)
	var me: Dictionary = res.players[0]
	check(t.v.phase == "done" and int(me.back) == back and int(t.v.seats[2].stack) == stack - 18 + back, "the ball lands on %s: pays %d, exactly the layout's odds" % [PalTables.rl_name(n), back])
	await t.history()
	var h: Dictionary = t.hist.filter(func(x): return x.game == "rl")[0]
	var ok: Array = await t.verify(h)
	check(ok[0] == true, "CHECK a spin: " + str(ok[1]))
	var bad := h.duplicate(true)
	bad.result.number = (n + 1) % 38
	check((await t.verify(bad))[0] == false, "CHECK fails on a tampered number")
	await t.leave()


func _baccarat() -> void:
	print("baccarat")
	var t := client("tok-a", A)
	await t.sit(room, "ba", 0)
	await t.send({"op": "topup", "id": t.id, "amt": 200})
	var r := await t.send({"op": "babets", "id": t.id, "bets": {"B": 30}})
	check(str(r.get("error", "")).contains("20s"), "Banker bets go in 20s")
	for hand in 2:
		var stack := int(t.v.seats[0].stack)
		await t.send({"op": "babets", "id": t.id, "bets": {"P": 10, "B": 20, "T": 5}})
		await t.send({"op": "baready", "id": t.id})
		await advance(5000)
		await t.state()
		var res: Dictionary = t.v.last.result
		var win: String = res.win
		var back: int = (20 if win == "P" else (10 if win == "T" else 0)) + (39 if win == "B" else (20 if win == "T" else 0)) + (45 if win == "T" else 0)
		var me: Dictionary = res.players[0]
		check(t.v.phase == "done" and int(me.back) == back and int(t.v.seats[0].stack) == stack - 35 + back and CasinoUI.ba_tot(res.player) == int(res.pt), "hand %d: %s · returns %d of 35 (the stack agrees)" % [hand + 1, res.why, back])
		await advance(9000 + 8000)
		await t.state()
	await t.history()
	var hs: Array = t.hist.filter(func(x): return x.game == "ba" and not x.result.get("shoeEnd"))
	check(hs.size() >= 2 and not hs[0].has("seed") and hs[0].cards is Array, "history: a hand's cards and their salts, no seed while the shoe is in play")
	var ok: Array = await t.verify(hs[0])
	check(ok[0] == true, "CHECK a hand against the shoe's fingerprints (the shoe op): " + str(ok[1]))
	var bad: Dictionary = hs[0].duplicate(true)
	bad.cards[0][1] = (int(bad.cards[0][1]) + 1) % 416
	check((await t.verify(bad))[0] == false, "CHECK fails on a tampered card")
	await t.leave()
	await t.history()
	var end: Array = t.hist.filter(func(x): return x.game == "ba" and x.result.get("shoeEnd"))
	check(not end.is_empty() and end[0].has("seed"), "the table closed: the shoe's seed and every card are in the history")
	ok = await t.verify(end[0])
	check(ok[0] == true, "CHECK reruns the whole shoe (416 cards): " + str(ok[1]))
	ok = await t.verify(hs[1])
	check(ok[0] == true and str(ok[1]).contains("finished"), "a hand from the finished shoe checks against its rerun: " + str(ok[1]))
	var bad2: Dictionary = end[0].duplicate(true)
	var d0 = bad2.deck[0]
	bad2.deck[0] = bad2.deck[1]
	bad2.deck[1] = d0
	check((await t.verify(bad2))[0] == false, "CHECK fails on a shoe with two cards swapped")


func _craps() -> void:
	print("craps")
	var t := client("tok-a", A)
	await t.sit(room, "cr", 0)
	await t.send({"op": "topup", "id": t.id, "amt": 300})
	var rolls := 0
	var flows_ok := true
	while rolls < 6:
		var stack := int(t.v.seats[0].stack)
		var on := CasinoUI.sum(t.v.myBets)
		var P := int(t.v.get("point", 0))
		if not P and not (int(t.v.myBets.get("pass", 0)) > 0):
			await t.send({"op": "crbet", "id": t.id, "k": "pass", "amt": 10})
		if P and int(t.v.myBets.get("po", 0)) == 0 and int(t.v.myBets.get("pass", 0)) > 0:
			await t.send({"op": "crbet", "id": t.id, "k": "po", "amt": 10 - 10 % CasinoUI.cr_den("po", P)})
		if not t.v.myBets.has("field"):
			await t.send({"op": "crbet", "id": t.id, "k": "field", "amt": 5})
		var put := CasinoUI.sum(t.v.myBets) - on
		check(int(t.v.seats[0].stack) == stack - put, "roll %d: %d◆ more on the layout comes off the stack" % [rolls + 1, put])
		stack = int(t.v.seats[0].stack)
		await t.send({"op": "crready", "id": t.id})
		await advance(5000)
		await t.state()
		var res: Dictionary = t.v.last.result
		var me: Dictionary = res.players[0]
		var back := 0
		for it in me.items:
			back += int(it.back)
		flows_ok = flows_ok and int(t.v.seats[0].stack) == stack + back and int(me.back) == back
		print("    %s: %s" % [" + ".join(PackedStringArray(res.dice.map(func(x): return str(int(x))))), res.why])
		rolls += 1
		await advance(2200 + 6000)
		await t.state()
	check(flows_ok, "every roll: the stack gains exactly what the receipt's items return")
	var r := await t.send({"op": "crbet", "id": t.id, "k": "p6", "amt": 7})
	check(str(r.get("error", "")).contains("6s"), "Place 6 goes in 6s (whole-shard payouts)")
	await t.history()
	var hs: Array = t.hist.filter(func(x): return x.game == "cr")
	var all := true
	for h in hs:
		all = all and (await t.verify(h))[0] == true
	check(hs.size() >= 6 and all, "CHECK reruns all %d rolls" % hs.size())
	var bad: Dictionary = hs[0].duplicate(true)
	bad.result.dice[0] = int(bad.result.dice[0]) % 6 + 1
	check((await t.verify(bad))[0] == false, "CHECK fails on tampered dice")
	await t.leave()
	if t.id != 0:   # a Pass bet on a point stays: the lobby rolls it out
		await advance(200000)
	await t.lobby()
	check(t.mine == null, "off the craps table")


func _blackjack() -> void:
	print("blackjack")
	var t := client("tok-a", A)
	await t.sit(room, "bj", 0)
	check(t.v.host and not t.v.started, "the first to sit is the host; the table waits for START")
	await t.send({"op": "settings", "id": t.id, "lim": 250})
	await t.send({"op": "start", "id": t.id})
	await t.state()
	check(t.v.started and t.v.phase == "bet", "START: betting opens")
	await t.send({"op": "topup", "id": t.id, "amt": 100})
	for hand in 3:
		var stack := int(t.v.seats[0].stack)
		await t.send({"op": "bet", "id": t.id, "amt": 10, "side": false})
		var guard := 0
		while t.v.phase != "done" and guard < 20:
			guard += 1
			if t.v.phase == "ins" and t.v.get("insure", false):
				await t.send({"op": "insure", "id": t.id, "yes": false})
			elif t.v.get("myTurn", false):
				var me: Dictionary = t.v.players[0].hands[int(t.v.turn.h)]
				await t.send({"op": "move", "id": t.id, "a": "hit" if int(me.total) < 13 else "stand"})
			else:
				await t.state()
		var res: Dictionary = t.v.last.result
		var p: Dictionary = res.players[0]
		check(t.v.phase == "done" and int(t.v.seats[0].stack) == stack - int(p.bet) + int(p.back), "hand %d: dealer %d · %s · net %d (the stack agrees)" % [hand + 1, int(res.total), p.hands[0].result, int(p.net)])
		await advance(8000 + 6000)
		await t.state()
	await t.history()
	var h: Dictionary = t.hist.filter(func(x): return x.game == "bj")[0]
	var ok: Array = await t.verify(h)
	check(ok[0] == true and h.deck.size() == 208, "CHECK reruns the 4-deck shoe: " + str(ok[1]))
	var bad := h.duplicate(true)
	bad.deck[5] = (int(bad.deck[5]) + 1) % 208
	check((await t.verify(bad))[0] == false, "CHECK fails on a tampered shoe")
	bad = h.duplicate(true)
	bad.result.seeds = ["someone-else"]
	check((await t.verify(bad))[0] == false, "CHECK fails when the players' seeds are changed")
	await t.leave()


func _holdem() -> void:
	print("hold'em with SLIM")
	var t := client("tok-a", A)
	await t.sit(room, "he", 0)
	await t.send({"op": "topup", "id": t.id, "amt": 100})
	var stack := int(t.v.seats[0].stack)
	await t.send({"op": "start", "id": t.id})
	await t.state()
	var slim := false
	for s in t.v.seats:
		if s is Dictionary and s.bot:
			slim = s.name == "SLIM (BOT)"
	check(slim and t.v.phase == "play", "SLIM (the bot) sits in with one player, and the hand is dealt")
	var ui := CasinoUI.new(main)
	ui.tables = t   # the sheet's view of this table, for the floor's helpers
	check(ui.bot_at("he", 1) or ui.bot_at("he", 2) or ui.bot_at("he", 3), "bot_at() finds SLIM's seat")
	var guard := 0
	while t.v.phase == "play" and guard < 60:
		guard += 1
		if t.v.get("myTurn", false):
			var c: Dictionary = t.v.can
			await t.send({"op": "move", "id": t.id, "a": "check" if c.check else "call"})
		else:
			await advance(1400)   # SLIM thinks for 1.3 s
			await t.state()
	var res: Dictionary = t.v.last.result
	var me: Dictionary = res.players.filter(func(x): return x.uid == A)[0]
	check(t.v.phase == "done" and int(t.v.seats[0].stack) == stack - int(me.put) + int(me.won), "the hand plays out: %s (put %d, won %d; the stack agrees)" % [ui.result_text(t.v), int(me.put), int(me.won)])
	await t.history()
	var h: Dictionary = t.hist.filter(func(x): return x.game == "he")[0]
	check(not h.has("seed") and h.cardHashes is Array and h.cardHashes.size() == 52, "history inside 24 h: card fingerprints, no seed")
	var ok: Array = await t.verify(h)
	check(ok[0] == true, "CHECK the cards you saw: " + str(ok[1]))
	var bad := h.duplicate(true)
	bad.cards[0][1] = (int(bad.cards[0][1]) + 1) % 52
	check((await t.verify(bad))[0] == false, "CHECK fails on a tampered card")
	await t.leave()


func _sheet() -> void:
	print("the sheet")
	var ui := CasinoUI.new(main)
	ui.tables.account = account("tok-b", B)
	ui.persist_seed = false
	ui.sync_locker = false
	root.add_child(ui)
	await process_frame
	var ev := {"stood": 0, "shards": -1}
	ui.stood_up.connect(func(): ev.stood += 1)
	ui.shards_changed.connect(func(n): ev.shards = n)
	var b0 := await balance("tok-b")
	ui.open(102, room)   # cabinet 2
	for i in 40:
		await process_frame
		if ui.tables.id:
			break
	await create_timer(0.3).timeout
	check(ui.is_open() and ui.tables.id > 0 and ui.tables.v.station == "s2" and ev.shards == b0 - 5, "open(102): seated at slot cabinet 2; shards_changed reports the new balance")
	check(ui.title_l.text == "SLOTS · CABINET 2" and ui.status_t.text == "TOP UP" or ui.status_t.text == "PLACE A BET AND SPIN", "the head and the status line: " + ui.status_t.text)
	ui._act("top:25")
	await create_timer(0.5).timeout
	ui.sl_amt = 3
	ui._act("slspin")
	await create_timer(0.5).timeout
	check(ui.tables.v.phase == "done" and CasinoUI.left(ui.tables.v) > 0 and ui.slot_line("s2") is Array, "SPIN: the reels turn on the sheet (and on the cabinet: slot_line)")
	await create_timer(2.8).timeout
	var mine = ui.mine_of(ui.tables.v.last.result)
	check(ui.last_sfx == CasinoUI.result_kind(mine) and ui.last_sfx != "" , "the result sound once the reels stop: %s for net %+d" % [ui.last_sfx, int(mine.net)])
	check(ui.review_box.get_child_count() > 0 and not CasinoUI.last_rcpt.is_empty(), "the receipt is on the felt, and kept for LAST RESULT")
	ui.last_result()
	await process_frame
	check(ui.modal_open() and ui.modal_kind == "LAST RESULT", "LAST RESULT opens the review")
	ui._close_modal()
	check(CasinoUI.result_kind({"net": -250, "bet": 250}) == "cas_bust" and CasinoUI.result_kind({"net": -20, "bet": 20}) == "cas_lose" and CasinoUI.result_kind({"net": 0, "bet": 10, "back": 10}) == "cas_push"
		and CasinoUI.result_kind({"net": 5, "bet": 10}) == "cas_small" and CasinoUI.result_kind({"net": 10, "bet": 10}) == "cas_win" and CasinoUI.result_kind({"net": 40, "bet": 10}) == "cas_big"
		and CasinoUI.result_kind({"net": 600, "bet": 500}) == "cas_big" and CasinoUI.result_kind({"net": 150, "bet": 10}) == "cas_jackpot", "result sounds by net against bet (trombone at -200, fanfare 4x / 500, jackpot 15x / 2,500)")
	check(CasinoUI.verdict({"net": 5, "bet": 20, "back": 25, "items": [{"k": "P", "bet": 10, "back": 20}, {"k": "T", "bet": 10, "back": 0}]}) == "PARTIAL RESULT" and CasinoUI.verdict({"net": 0, "bet": 0, "back": 0}) == "NO DECISION", "verdicts: PARTIAL RESULT, NO DECISION")
	var bal := await balance("tok-b")
	var stack := int(ui.tables.v.seats[0].stack)
	ui._act("stand")
	for i in 40:
		await process_frame
		if ui.tables.id == 0:
			break
	await create_timer(0.2).timeout
	check(ev.stood >= 1 and not ui.is_open() and await balance("tok-b") == bal + stack, "STAND UP: stood_up, the sheet closes, the machine's shards go home")
	# a table seat code: n*10+k+1 (roulette is table 3)
	check(CasinoUI.seat_info(31) == {"game": "rl", "k": 0, "station": ""} and CasinoUI.seat_info(15) == {"game": "bj", "k": 4, "station": ""} and CasinoUI.seat_info(117).station == "p1" and CasinoUI.seat_info(116).station == "s16", "seat codes: table n seat k is n*10+k+1, machines 101-117")
	ui.open(33, room)
	for i in 60:
		await process_frame
		if ui.tables.id:
			break
	await create_timer(0.3).timeout
	check(ui.tables.v.game == "rl" and int(ui.tables.v.me) == 2, "open(33): roulette, seat 3")
	ui._act("top:100")
	await create_timer(0.4).timeout
	ui._act("chip:5")
	ui.rl_tap(5.5, 0.5)   # the 18
	ui.rl_add("red")
	await create_timer(0.6).timeout
	check(CasinoUI._ibets(ui.tables.v.myBets) == {"n:18": 5, "red": 5}, "taps on the board and an outside box: the bets reach the server (%s)" % JSON.stringify(ui.tables.v.myBets))
	ui._act("rlspin")
	await create_timer(0.6).timeout
	check(ui.tables.v.phase == "spin" and ui.wheel_state().ball != null, "SPIN: the ball is spinning (and on the floor's wheel)")
	ui._act("stand")
	await create_timer(0.6).timeout
	ui.queue_free()
