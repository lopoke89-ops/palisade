extends SceneTree
## CasinoRelay against the real relay (dev/render/relay.js) on localhost, with fake Supabase auth (relay_fixture.mjs,
## started here). Never the live relay or live Supabase.
##   godot --headless --path godot --script res://tests/relay_test.gd     (exit 0 = pass; about 30 s)
## Needs node and dev/render/node_modules (cd dev/render && npm ci).

const UNI := "héllo ✓ 日本 \"q\" \\ \n"
const USERS := 12

var fails := 0
var passes := 0
var ev: Array = []   # [who, signal, args...]
var tokens := {}   # who -> the token its token_fn hands out
var nets := {}
var fx_pid := -1
var port := 0
var cport := 0
var sport := 0
var tport := 0


func check(cond: bool, what: String) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if cond:
		passes += 1
	else:
		fails += 1


static func uid(i: int) -> String:
	return "a0000000-0000-4000-8000-%012d" % (i + 1)


## what dev/test mints: 'x.' + base64url({sub, exp, name}) + '.y'
static func token(i: int, exp_s: float, name := "") -> String:
	var j := JSON.stringify({"sub": uid(i), "exp": int(exp_s), "name": name if name != "" else "Player%d" % i})
	return "x." + Marshalls.utf8_to_base64(j).replace("+", "-").replace("/", "_").replace("=", "") + ".y"


static func now_s() -> float:
	return Time.get_unix_time_from_system()


func _net(who: String, user: int, coroutine := false) -> CasinoRelay:
	var n := CasinoRelay.new()
	n.name = who
	root.add_child(n)
	nets[who] = n
	tokens[who] = token(user, now_s() + 3600)
	n.opened.connect(func(c): ev.append([who, "opened", c]))
	n.error.connect(func(t, m): ev.append([who, "error", t, m]))
	n.peer_connected.connect(func(p): ev.append([who, "connected", p]))
	n.peer_closed.connect(func(p): ev.append([who, "closed", p]))
	n.peer_resumed.connect(func(p): ev.append([who, "resumed", p]))
	n.status.connect(func(s): ev.append([who, "status", s]))
	n.data.connect(func(p, ch, m): ev.append([who, "data", p, ch, m]))
	return n


func _opts(who: String, extra := {}, coroutine := false) -> Dictionary:
	var o := {"url": "http://127.0.0.1:%d" % port}
	if coroutine:
		o.token_fn = func():
			await process_frame   # as PalAccount.fresh_token() would
			return {"access_token": tokens[who], "expires_at": CasinoRelay.jwt_exp_ms(tokens[who]) / 1000.0}
	else:
		o.token_fn = func(): return tokens[who]
	o.merge(extra, true)
	return o


func _find(who: String, kind: String, f := Callable()) -> Array:
	for e in ev:
		if e[0] == who and e[1] == kind and (not f.is_valid() or f.call(e)):
			return e
	return []


func _count(who: String, kind: String, f := Callable()) -> int:
	var n := 0
	for e in ev:
		if e[0] == who and e[1] == kind and (not f.is_valid() or f.call(e)):
			n += 1
	return n


func _got(who: String, t: String, ch := "") -> Array:
	return _find(who, "data", func(e): return e[4].get("t") == t and (ch == "" or e[3] == ch))


func _err(who: String) -> Array:
	return _find(who, "error")


## run frames until cond() holds or the time runs out
func wait(cond: Callable, secs: float) -> bool:
	var until := Time.get_ticks_msec() + int(secs * 1000)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
		OS.delay_msec(2)
	return cond.call()


func ctl(path: String):
	var h := HTTPRequest.new()
	root.add_child(h)
	if h.request("http://127.0.0.1:%d%s" % [cport, path]) != OK:
		h.queue_free()
		return null
	var r: Array = await h.request_completed
	h.queue_free()
	return JSON.parse_string(r[3].get_string_from_utf8()) if r[0] == HTTPRequest.RESULT_SUCCESS else null


func member(peer: String) -> Dictionary:
	var s = await ctl("/state")
	if s is Dictionary:
		for r in s.rooms:
			for m in r.members:
				if m.id == peer:
					m.room = r
					return m
	return {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	port = rng.randi_range(20000, 40000)
	cport = port + 1
	sport = port + 2
	tport = port + 3
	var fx := ProjectSettings.globalize_path("res://tests/relay_fixture.mjs")
	fx_pid = OS.create_process("node", [fx, "--port", str(port), "--control", str(cport), "--native", "--strict-port", str(sport), "--tls-port", str(tport), "--origin", "http://localhost:8080"])
	var up := false
	var t_up := Time.get_ticks_msec() + 8000
	while not up and Time.get_ticks_msec() < t_up:
		up = (await ctl("/state")) is Dictionary
		if not up:
			await create_timer(0.1).timeout
	if not up:
		print("FAIL the relay fixture did not start (node + dev/render/node_modules?)")
		return _done()
	await _basics()
	await _tls()
	await _failures()
	await _tokens()
	await _restart()
	_done()


# ---------------------------------------------------------------- host, guest, messages, resume, lock, remove

func _basics() -> void:
	print("-- open and join")
	var h := _net("h", 0)
	h.host("", _opts("h", {}, true))   # the host's token_fn is a coroutine
	check(await wait(func(): return not _find("h", "opened").is_empty(), 8), "host is welcomed")
	var code: String = _find("h", "opened")[2] if not _find("h", "opened").is_empty() else ""
	check(CasinoRelay.is_code(code) and h.code == code, "the relay picks the room code and opened() gives it: " + code)
	check(_find("h", "status", func(e): return e[2] == CasinoRelay.CONNECTING) != [], "status shows the browser's connecting line")
	var hm := await member(h.id)
	check(hm.get("role") == "host" and hm.room.incarnation == h.incarnation and hm.room.code == code, "the relay has our room, incarnation and seat")
	var g := _net("g", 1)
	g.join(code.to_lower(), _opts("g", {"incarnation": h.incarnation}))
	check(await wait(func(): return not _find("g", "connected").is_empty() and not _find("h", "connected").is_empty(), 8), "guest joins")
	check(_find("g", "connected") == ["g", "connected", "host"] and _find("g", "opened") == ["g", "opened", code], "the guest's only peer is 'host'")
	check(_find("h", "connected") == ["h", "connected", g.id] and h.peers() == [g.id] and g.peers() == ["host"], "the host's peer is the guest's relay id")
	check(h.is_open(g.id, "r") and g.is_open("host", "st") and not h.is_open("nobody"), "is_open")

	print("-- messages")
	check(g.send("host", {"t": "hello", "name": "Forged", "uid": "forged", "v": "x", "session": "y", "cls": "soldier", "s": UNI}), "guest sends hello on r")
	check(g.send("host", {"t": "i", "x": 1.5, "y": 2}, "u"), "guest sends input on u (volatile)")
	check(g.send("host", {"t": "c", "m": UNI}), "guest sends chat on r")
	check(await wait(func(): return _got("h", "hello") != [] and _got("h", "i") != [] and _got("h", "c") != [], 5), "host gets all three")
	var hello: Array = _got("h", "hello")
	check(hello[2] == g.id and hello[3] == "r" and hello[4].uid == uid(1) and hello[4].name == "Player1" and hello[4].v == "yard-30" and hello[4].s == UNI,
		"the relay vouches for the hello (uid/name/v from the account, not the guest): %s" % JSON.stringify(hello[4]))
	check(_got("h", "i")[3] == "u" and _got("h", "i")[4].x == 1.5, "input arrives as 'u'")
	check(_got("h", "c")[4].m == UNI, "unicode survives")
	check(h.send(g.id, {"t": "welcome", "id": "g1"}), "host sends welcome on r")
	check(h.send(g.id, {"t": "s", "n": 1, "pad": "S".repeat(20000)}, "st"), "host sends a 20 KB state frame on st")
	check(h.send(g.id, {"t": "lobby", "pad": "L".repeat(30000), "s": UNI}), "host sends 30 KB on r")
	check(await wait(func(): return _got("g", "welcome") != [] and _got("g", "s") != [] and _got("g", "lobby") != [], 5), "guest gets all three")
	check(_got("g", "s")[3] == "st" and _got("g", "s")[4].pad.length() == 20000 and _got("g", "lobby")[4].s == UNI, "state arrives as 'st', intact")
	check(g.player_id == "g1", "the guest learns its player id from the host's welcome")
	check(not h.send(g.id, {"t": "hello"}) and not g.send("host", {"t": "s"}) and not h.send(g.id, {"t": "nope"}), "types the relay wouldn't forward are refused")
	check(not h.send("nobody", {"t": "c"}) and not g.send("someone", {"t": "c"}), "unknown peers are refused")
	check(not h.send(g.id, {"t": "start", "mode": "5", "map": "yard", "room": "x"}), "a start that would get the host thrown off is refused")
	check(h.send(g.id, {"t": "start", "mode": "casino", "map": "casino", "room": h.room_id()}), "a casino start for this room goes")
	check(not h.send(g.id, {"t": "c", "pad": "x".repeat(70000)}), "a message over the relay's 64 KiB limit is refused")
	h.send_all({"t": "c", "m": "to all"})
	check(await wait(func(): return _got("g", "c") != [], 3), "send_all reaches the guest")

	print("-- backpressure (the relay stops reading the host's socket)")
	await ctl("/pause?peer=" + h.id)
	var vol := 0
	var dropped := false
	for i in 4000:
		if not h.send(g.id, {"t": "s", "pad": "V".repeat(12000)}, "st"):
			dropped = true
			break
		vol += 1
	var waiting: int = h._sock.buffered() if h._sock else -1
	check(dropped and waiting > CasinoRelay.VOLATILE_BUFFERED and waiting <= CasinoRelay.MAX_BUFFERED + 13000,
		"volatile sends stop once 16 KiB is waiting (%d sent, %d bytes waiting)" % [vol, waiting])
	check(h.send(g.id, {"t": "c", "m": "reliable still goes"}), "a reliable send still goes")
	var rel := 0
	while h.send(g.id, {"t": "c", "pad": "R".repeat(12000)}) and rel < 100:
		rel += 1
	check(h._sock == null or h._sock.is_closed(), "past 64 KiB waiting the connection closes as too slow (%d more reliable sends)" % rel)
	check(await wait(func(): return _count("h", "opened") >= 2, 8), "the host resumes on a fresh socket")
	check(h.id == hm.id and h.code == code and _err("h") == [], "same seat, same room, no error")
	check(await wait(func(): return _find("h", "resumed", func(e): return e[2] == g.id) != [], 5), "the host hears its guest is still there (peer_resumed)")
	await ctl("/unpause")
	ev = ev.filter(func(e): return e[1] != "data")
	check(h.send(g.id, {"t": "c", "m": "after host resume"}) and await wait(func(): return _got("g", "c") != [], 3), "host -> guest after the host's resume")
	check(_err("g") == [], "the guest accepted the relayResume (its player id matched)")

	print("-- the relay drops the host's socket")
	ev.clear()
	await ctl("/drop?peer=" + h.id)
	check(await wait(func(): return _find("g", "status", func(e): return e[2] == "Reconnecting to the casino host…") != [], 3), "the guest hears the host is away (status)")
	check(await wait(func(): return _find("h", "opened") != [] and _find("g", "status", func(e): return e[2] == "") != [], 6), "the host resumes and the guest hears it is back")
	check(h.id == hm.id and h.code == code and _err("h") == [] and _err("g") == [] and _find("g", "closed") == [], "nobody lost their seat")
	check(await wait(func(): return _got("g", "relayResume") == [] and _find("h", "resumed", func(e): return e[2] == g.id) != [], 3), "the host gets peer_resumed for its guest")

	print("-- resume after the guest's socket drops")
	var gid := g.id
	ev.clear()
	var dropped_ok = await ctl("/drop?peer=" + gid)
	check(dropped_ok is Dictionary and dropped_ok.ok, "the relay drops the guest's socket")
	check(await wait(func(): return _find("g", "status", func(e): return e[2] == CasinoRelay.RECONNECTING) != [], 3), "the guest says it is reconnecting")
	check(await wait(func(): return _find("g", "opened") != [], 6), "the guest resumes")
	check(g.id == gid and _find("g", "connected") == [] and _find("h", "closed") == [], "same peer id; no leave on either side, no second peer_connected")
	check(await wait(func(): return _find("h", "resumed", func(e): return e[2] == gid) != [], 3), "the host gets peer_resumed")
	g.send("host", {"t": "c", "m": "after resume"})
	h.send(g.id, {"t": "c", "m": "back"})
	check(await wait(func(): return _got("h", "c") != [] and _got("g", "c") != [], 3), "messages flow both ways after the resume")
	print("-- resume after our own side loses the connection")
	ev.clear()
	g._sock._end()   # the network went: no close frame
	check(await wait(func(): return _find("g", "opened") != [], 6) and g.id == gid and _err("g") == [], "the guest resumes from a dead socket of its own")

	print("-- lock")
	h.set_locked(true)
	await wait(func(): return false, 0.3)
	var x := _net("x", 2)
	x.join(code, _opts("x"))
	check(await wait(func(): return _err("x") != [], 5), "a join to a locked room fails")
	check(_err("x") == ["x", "error", "locked", "This casino is locked."], "with the relay's words: %s" % [_err("x")])
	h.set_locked(false)
	await wait(func(): return false, 0.3)
	var y := _net("y", 2)
	y.join(code, _opts("y"))
	check(await wait(func(): return _find("y", "connected") != [], 5), "unlocked, the same account gets in")
	var yid := y.id
	y.close_peer("host")   # the guest leaves
	check(await wait(func(): return _find("h", "closed", func(e): return e[2] == yid) != [], 5), "the host sees a departing guest as peer_closed")
	check(_find("y", "closed") == ["y", "closed", "host"] and y.role == "", "close_peer on a guest leaves")

	print("-- relayResume naming someone else")
	var w := _net("w", 8)
	w.join(code, _opts("w"))
	await wait(func(): return _find("h", "connected", func(e): return e[2] == w.id) != [], 5)
	h.send(w.id, {"t": "welcome", "id": "g9"})
	await wait(func(): return _got("w", "welcome") != [], 3)
	w.player_id = "g4"   # as if this screen thought it was someone else
	await ctl("/drop?peer=" + w.id)
	check(await wait(func(): return _err("w") != [], 6), "a relayResume for another player id ends the session")
	check(_err("w") == ["w", "error", "session-changed", CasinoRelay.SESSION_CHANGED], str(_err("w")))

	print("-- remove and ban")
	ev.clear()
	check(h.remove(gid, true), "host removes the guest with a ban")
	check(_find("h", "closed") == ["h", "closed", gid] and h.peers().find(gid) < 0, "peer_closed at once on the host")
	check(await wait(func(): return _err("g") != [], 5), "the removed guest is told")
	check(_err("g") == ["g", "error", "removed", CasinoRelay.REPLACED], str(_err("g")))
	var g2 := _net("g2", 1)
	g2.join(code, _opts("g2"))
	check(await wait(func(): return _err("g2") != [], 5), "the removed account can't come back")
	check(_err("g2") == ["g2", "error", "removed", "The host removed you from this casino."], str(_err("g2")))
	var z := _net("z", 3)
	z.join(code, _opts("z"))
	await wait(func(): return _find("z", "connected") != [] and _find("h", "connected", func(e): return e[2] == z.id) != [], 5)
	var zid := z.id
	h.close_peer(zid)   # the browser's channel close(): remove without ban
	check(await wait(func(): return _err("z") != [], 5) and _err("z")[2] == "removed", "close_peer on the host removes the guest")
	var z2 := _net("z2", 3)
	z2.join(code, _opts("z2"))
	check(await wait(func(): return _find("z2", "connected") != [], 5), "...without a ban: they can come back")

	print("-- the host leaves")
	h.shutdown()
	check(await wait(func(): return _err("z2") != [], 5), "the guest is told at once (no grace for a departure)")
	check(_err("z2") == ["z2", "error", "host-closed", "The host closed this casino."], str(_err("z2")))
	var s = await ctl("/state")
	check(s is Dictionary and s.rooms.is_empty() and s.people == 0, "the relay has no rooms or people left")


# ---------------------------------------------------------------- wss://

func _tls() -> void:
	print("-- wss:// (TLS in front of the same relay, a self-signed certificate for 127.0.0.1)")
	var info = await ctl("/tls")
	if not (info is Dictionary):
		check(false, "the fixture has a TLS listener")
		return
	var cert := X509Certificate.new()
	check(cert.load(info.cert) == OK, "load the fixture's certificate")
	var url := "https://127.0.0.1:%d" % int(info.port)
	var th := _net("th", 0)
	th.host("", _opts("th", {"url": url, "tls_options": TLSOptions.client(cert)}))
	check(await wait(func(): return _find("th", "opened") != [], 8), "a host over wss:// is welcomed")
	var tg := _net("tg", 1)
	tg.join(th.code, _opts("tg", {"url": url, "tls_options": TLSOptions.client(cert)}))
	check(await wait(func(): return _find("tg", "connected") != [] and _find("th", "connected") != [], 8), "a guest over wss:// joins")
	tg.send("host", {"t": "c", "m": UNI})
	th.send(tg.id, {"t": "s", "pad": "T".repeat(40000)}, "st")
	check(await wait(func(): return _got("th", "c") != [] and _got("tg", "s") != [], 5), "messages both ways over TLS (a 40 KB frame too)")
	check(_got("th", "c")[4].m == UNI and _got("tg", "s")[4].pad.length() == 40000, "intact")
	var tid := tg.id
	await ctl("/drop?peer=" + tid)
	check(await wait(func(): return _count("tg", "opened") >= 2, 6) and tg.id == tid, "a dropped TLS socket resumes")
	var bad := _net("tbad", 2)
	bad.join(th.code, _opts("tbad", {"url": url, "join_ms": 1500}))   # the system CAs don't know this certificate
	check(await wait(func(): return _err("tbad") != [], 8) and _err("tbad")[2] == "timeout" and _find("tbad", "opened") == [], "an untrusted certificate never gets a hello through")
	th.shutdown()
	check(await wait(func(): return _err("tg") != [], 5) and _err("tg")[2] == "host-closed", "the host's departure over TLS reaches the guest with its message")


# ---------------------------------------------------------------- refusals before a seat

func _failures() -> void:
	print("-- refusals")
	var a := _net("a", 4)
	a.join("ABCD", _opts("a"))
	check(_err("a") == [], "an invalid code fails after join() returns, not inside it")
	check(await wait(func(): return _err("a") != [], 2) and _err("a") == ["a", "error", "invalid-code", CasinoRelay.BAD_CODE], str(_err("a")))
	var b := _net("b", 4)
	b.join("RZZZZZ", _opts("b", {"join_ms": 2500}))
	check(await wait(func(): return _err("b") != [], 8), "a code with no host fails once the join window runs out")
	check(_err("b") == ["b", "error", "peer-unavailable", "Waiting for the casino host…"], str(_err("b")))
	check(_count("b", "status", func(e): return e[2] == CasinoRelay.RECONNECTING) >= 1, "...after retrying")
	var c := _net("c", 4)
	tokens.c = ""
	c.host("", _opts("c"))
	check(await wait(func(): return _err("c") != [], 3) and _err("c") == ["c", "error", "signed-out", CasinoRelay.SIGN_IN], "no token: " + str(_err("c")))
	var d := _net("d", 4)
	tokens.d = "not-a-token"
	d.host("", _opts("d"))
	check(await wait(func(): return _err("d") != [], 3) and _err("d") == ["d", "error", "signed-out", "Sign in to a saved account."], "the relay rejects the token: " + str(_err("d")))
	var en := _net("e", 4)
	en.host("", _opts("e", {"enabled": false}))
	check(await wait(func(): return _err("e") != [], 2) and _err("e") == ["e", "error", "unavailable", CasinoRelay.UPDATING], str(_err("e")))
	var f := _net("f", 4)
	f.host("", _opts("f", {"url": "http://127.0.0.1:%d" % sport, "join_ms": 1500}))
	check(await wait(func(): return _err("f") != [], 8), "a relay that only admits browser origins refuses us (HTTP 403)")
	check(_err("f").size() == 4 and _err("f")[2] == "timeout" and f.last_http_status == 403 and _find("f", "opened") == [], str(_err("f")))
	var ups = await ctl("/upgrades")
	var strict: Array = ups.filter(func(u): return int(u.port) == sport) if ups is Array else []
	check(not strict.is_empty() and strict.all(func(u): return u.origin == null), "Godot's handshake carries no Origin (%d tries on the strict relay)" % strict.size())
	print("-- account change")
	var owner := {"id": uid(5)}
	var k := _net("k", 5)
	k.host("", _opts("k", {"uid_fn": func(): return owner.id}))
	await wait(func(): return _find("k", "opened") != [], 5)
	owner.id = uid(6)
	k.heartbeat()
	check(await wait(func(): return _err("k") != [], 2) and _err("k") == ["k", "error", "account-changed", CasinoRelay.ACCOUNT_CHANGED], str(_err("k")))


# ---------------------------------------------------------------- token refresh and expiry

func _tokens() -> void:
	print("-- token refresh by heartbeat, and a host whose sign-in runs out (up to 18 s)")
	var soon := now_s() + 8   # after the first 5 s heartbeat, before the relay's 10 s sweep can be sure to catch it
	var h1 := _net("h1", 9)
	tokens.h1 = token(9, soon)
	h1.host("", _opts("h1"))
	var h2 := _net("h2", 10)
	tokens.h2 = token(10, soon)
	h2.host("", _opts("h2"))
	check(await wait(func(): return _find("h1", "opened") != [] and _find("h2", "opened") != [], 5), "two hosts with tokens that expire in 8 s")
	var g1 := _net("g1", 6)
	g1.join(h1.code, _opts("g1"))
	var g2 := _net("g2b", 7)
	g2.join(h2.code, _opts("g2b"))
	check(await wait(func(): return _find("g1", "connected") != [] and _find("g2b", "connected") != [], 5), "each has a guest")
	h2._hb_at = Time.get_ticks_msec() + 3600000   # only the relay's own sweep may notice h2's expiry (a message would too, but then the room waits out the grace)
	var renewed := token(9, now_s() + 3600)
	tokens.h1 = renewed   # what fresh_token() would do; only the 5 s heartbeat tells the relay
	check(await wait(func(): return h1._auth_token == renewed and h1._pending_token == "", 7), "the heartbeat sends the new token and the relay acknowledges it")
	var m := await member(h1.id)
	check(int(m.get("expires", 0)) == CasinoRelay.jwt_exp_ms(renewed), "the relay now holds the new expiry")
	check(await wait(func(): return _err("g2b") != [] and _err("h2") != [], 20), "the other host's sign-in runs out")
	check(_err("g2b") == ["g2b", "error", "host-expired", "The host's sign-in expired. Sign in and open a new casino."], str(_err("g2b")))
	check(_err("h2") == ["h2", "error", "signed-out", "Sign in again."], str(_err("h2")))
	check(now_s() > soon and h1.connected and g1.connected and _err("h1") == [] and _err("g1") == [], "the renewed host and its guest are still in after the original expiry")
	h1.send(h1.peers()[0], {"t": "c", "m": "still here"})
	check(await wait(func(): return _got("g1", "c") != [], 3), "and still talking")
	h1.shutdown()
	await wait(func(): return _err("g1") != [], 3)


# ---------------------------------------------------------------- the relay restarts

func _restart() -> void:
	print("-- the relay restarts")
	var h := _net("h3", 0)
	h.host("", _opts("h3"))
	await wait(func(): return _find("h3", "opened") != [], 5)
	var g := _net("g3", 1)
	g.join(h.code, _opts("g3"))
	var g4 := _net("g4", 2)
	g4.join(h.code, _opts("g4"))
	check(await wait(func(): return _find("g3", "connected") != [] and _find("g4", "connected") != [], 5), "a room with two guests")
	g4._sock._end()   # g4 is offline while the relay restarts
	g4._retry_at = Time.get_ticks_msec() + 60000
	await wait(func(): return g4._sock == null, 2)
	await ctl("/restart")
	check(await wait(func(): return _err("h3") != [] and _err("g3") != [], 5), "everyone connected is told")
	var msg := "The casino connection server restarted. Open or join a new casino lobby."
	check(_err("h3") == ["h3", "error", "relay-restarted", msg] and _err("g3") == ["g3", "error", "relay-restarted", msg], "%s / %s" % [_err("h3"), _err("g3")])
	g4._retry_at = Time.get_ticks_msec()
	check(await wait(func(): return _err("g4") != [], 5), "a guest coming back with an old resume value is refused")
	check(_err("g4") == ["g4", "error", "relay-restarted", "The relay restarted. Open or join a new casino lobby."], str(_err("g4")))


func _done() -> void:
	for n in nets.values():
		n.shutdown()
	if cport:
		await ctl("/quit")
	if fx_pid > 0:
		OS.kill(fx_pid)
	print("%d passed, %d failed" % [passes, fails])
	print("RESULT: " + ("FAIL" if fails else "PASS"))
	quit(1 if fails else 0)
