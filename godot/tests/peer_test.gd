extends SceneTree
## PeerNet against a local PeerJS server: a host and a guest in this one process.
##   (cd dev/test && node peer-server.js) &      # port 9000, path /
##   godot --headless --path godot --script res://tests/peer_test.gd     (exit 0 = pass)

const OPTS := {"host": "127.0.0.1", "port": 9000, "path": "/", "secure": false, "ice": []}

var fails := 0
var passes := 0
var ev: Array = []   # [who, signal, args...]


func check(cond: bool, what: String) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if cond:
		passes += 1
	else:
		fails += 1


func _net(who: String) -> PeerNet:
	var n := PeerNet.new()
	n.name = who
	root.add_child(n)
	n.opened.connect(func(id): ev.append([who, "opened", id]))
	n.error.connect(func(t, m): ev.append([who, "error", t, m]))
	n.peer_connected.connect(func(p): ev.append([who, "connected", p]))
	n.peer_closed.connect(func(p): ev.append([who, "closed", p]))
	n.data.connect(func(p, ch, m): ev.append([who, "data", p, ch, m]))
	return n


func _find(who: String, kind: String, f := Callable()) -> Array:
	for e in ev:
		if e[0] == who and e[1] == kind and (not f.is_valid() or f.call(e)):
			return e
	return []


## run frames until cond() holds or the time runs out
func wait(cond: Callable, secs: float) -> bool:
	var until := Time.get_ticks_msec() + int(secs * 1000)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
		OS.delay_msec(2)
	return cond.call()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var code := PeerNet.gen_code(rng)
	var host := _net("host")
	var guest := _net("guest")

	print("register and join (room %s)" % code)
	host.host(code, OPTS)
	check(await wait(func(): return not _find("host", "opened").is_empty(), 5), "host registers as " + PeerNet.PREFIX + code)
	if _find("host", "opened").is_empty():
		print(ev)
		return _done()
	guest.join(code, OPTS)
	var hid := PeerNet.PREFIX + code
	check(await wait(func(): return not _find("guest", "connected").is_empty() and not _find("host", "connected").is_empty(), 10), "both sides see the 'r' channel open")
	var gid := guest.id
	check(_find("guest", "connected") == ["guest", "connected", hid], "the guest's peer is the host's id")
	check(_find("host", "connected") == ["host", "connected", gid], "the host's peer is the guest's id")
	check(await wait(func(): return host.is_open(gid, "u") and guest.is_open(hid, "u") and host.is_open(gid, "st") and guest.is_open(hid, "st"), 5), "'u' and the negotiated 'st' open on both sides")
	check(host.peers() == [gid] and guest.peers() == [hid], "peers() lists the other side")

	print("messages")
	var uni := "héllo ✓ 日本 \"q\" \\ \n"
	for ch in ["r", "u", "st"]:
		check(guest.send(hid, {"t": "g", "ch": ch, "s": uni, "n": 7}, ch), "guest sends on " + ch)
		check(host.send(gid, {"t": "h", "ch": ch, "a": [1, 2.5, true, null]}, ch), "host sends on " + ch)
	for ch in ["r", "u", "st"]:
		var c: String = ch
		var got := await wait(func(): return not _find("host", "data", func(e): return e[3] == c and e[4] is Dictionary and e[4].get("t") == "g").is_empty(), 5)
		var e := _find("host", "data", func(e): return e[3] == c and e[4] is Dictionary and e[4].get("t") == "g")
		check(got and e[2] == gid and e[4].s == uni and e[4].n == 7.0 and e[4].ch == c, "host gets the guest's message on " + c)
		got = await wait(func(): return not _find("guest", "data", func(e): return e[3] == c and e[4] is Dictionary and e[4].get("t") == "h").is_empty(), 5)
		e = _find("guest", "data", func(e): return e[3] == c and e[4] is Dictionary and e[4].get("t") == "h")
		check(got and e[2] == hid and e[4].a == [1.0, 2.5, true, null], "guest gets the host's message on " + c)
	host.send_all({"t": "all"}, "u")
	check(await wait(func(): return not _find("guest", "data", func(e): return e[4] is Dictionary and e[4].get("t") == "all").is_empty(), 5), "send_all reaches the guest")

	print("size limit")
	var big := "x".repeat(16400)
	check(not guest.send(hid, {"big": big}, "r") and not host.send(gid, {"big": big}, "u"), "a message over 16300 bytes is refused on 'r' and 'u'")
	var fits := "y".repeat(16000)
	check(guest.send(hid, {"t": "fits", "s": fits}, "r"), "a 16 KB message under the limit goes")
	check(await wait(func(): return not _find("host", "data", func(e): return e[4] is Dictionary and e[4].get("t") == "fits" and e[4].s == fits).is_empty(), 5), "and arrives whole")
	var state := "z".repeat(40000)
	check(host.send(gid, {"t": "bigst", "s": state}, "st"), "'st' takes a 40 KB state message")
	check(await wait(func(): return not _find("guest", "data", func(e): return e[3] == "st" and e[4] is Dictionary and e[4].get("t") == "bigst").is_empty(), 5), "and it arrives")

	print("the host loses the signalling server")
	ev.clear()
	host._ws.close()   # what a dropped network does to the socket
	check(await wait(func(): return not _find("host", "error", func(e): return e[2] == "network").is_empty(), 5), "host reports 'network'")
	check(host.send(gid, {"t": "still"}, "r"), "the channels keep working while the socket is down")
	check(await wait(func(): return not _find("guest", "data", func(e): return e[4] is Dictionary and e[4].get("t") == "still").is_empty(), 5), "and the guest gets it")
	check(await wait(func(): return not _find("host", "opened").is_empty(), 6), "host re-registers its room code")

	print("a second host can't take the code")
	var dup := _net("dup")
	dup.host(code, OPTS)
	check(await wait(func(): return not _find("dup", "error").is_empty(), 5) and _find("dup", "error")[2] == "unavailable-id", "'unavailable-id' %s" % [_find("dup", "error").slice(2)])

	print("close")
	ev.clear()
	guest.close_peer(hid)
	check(await wait(func(): return not _find("host", "closed").is_empty(), 5) and _find("host", "closed")[2] == gid, "the host sees the guest leave")
	check(not _find("guest", "closed").is_empty(), "the guest's own peer_closed fires")
	check(not host.is_open(gid, "r") and not host.is_open(gid, "u") and host.peers().is_empty(), "the host forgets the guest")

	print("a code nobody hosts")
	ev.clear()
	var lost := _net("lost")
	var t0 := Time.get_ticks_msec()
	lost.join("Q" + code.substr(1) if code[0] != "Q" else "R" + code.substr(1), OPTS)
	check(await wait(func(): return not _find("lost", "error").is_empty(), 12) and _find("lost", "error")[2] == "peer-unavailable", "'peer-unavailable' (after %.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	check(lost.role == "", "the failed join shut itself down")

	print("join timeout (the room is registered but never answers)")
	ev.clear()
	var mute := _net("mute")
	var mcode := PeerNet.gen_code(rng)
	mute.host(mcode, OPTS)
	await wait(func(): return not _find("mute", "opened").is_empty(), 5)
	mute.set_process(false)   # registered, but it never reads its OFFERs
	var slow := _net("slow")
	t0 = Time.get_ticks_msec()
	slow.join(mcode, OPTS)
	check(await wait(func(): return not _find("slow", "error").is_empty(), 20) and _find("slow", "error")[2] == "timeout", "'timeout' (after %.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	for n in [host, guest, dup, lost, mute, slow]:
		n.shutdown()
	_done()


func _done() -> void:
	print("%d passed, %d failed" % [passes, fails])
	print("RESULT: " + ("PASS" if fails == 0 else "FAIL"))
	quit(1 if fails else 0)
