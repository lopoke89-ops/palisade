extends SceneTree
## The Godot half of tests/peer_cross.js (PeerNet against real PeerJS in Chromium). Not a test on its own.
##   godot --headless --path godot --script res://tests/peer_cross_driver.gd -- join|host CODE close|kick|destroy
## join: dial the browser's room; host: open the room for the browser. Once 'r', 'u' and 'st' are open it pings on
## each, answers the other side's 'st' ping with {t:'gotst'} on 'r', and prints one line per event for the script
## to read. close: when the exchange is done, close_peer and quit; otherwise wait for the browser to leave.

const OPTS := {"host": "127.0.0.1", "port": 9000, "path": "/", "secure": false, "ice": []}
const UNI := "héllo ✓ 日本 \"q\""

var net: PeerNet
var mode := ""
var finish := ""
var other := ""
var pinged := false
var acked := false
var gotst := false
var got := {}
var t_st := 0
var t_end := 0
var deadline := 0


func say(what: String, rest = "") -> void:
	print("EV %s %s" % [what, rest if rest is String else JSON.stringify(rest)])


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	mode = a[0]
	finish = a[2] if a.size() > 2 else "close"
	deadline = Time.get_ticks_msec() + 40000
	net = PeerNet.new()
	root.add_child(net)
	net.opened.connect(func(id): say("opened", id))
	net.error.connect(func(t, m): say("error", t + " " + m))
	net.peer_connected.connect(func(p):
		other = p
		say("connected", p))
	net.peer_closed.connect(func(p):
		say("closed", p)
		if finish != "close":
			t_end = Time.get_ticks_msec() + 300)
	net.data.connect(_on_data)
	if mode == "host":
		net.host(a[1], OPTS)
	else:
		net.join(a[1], OPTS)


func _on_data(p: String, ch: String, m) -> void:
	var show = m.duplicate() if m is Dictionary else m
	if show is Dictionary and show.has("pad"):
		show.pad = "<%d chars>" % str(show.pad).length()
	if show is Dictionary and show.get("t") == "big":
		show.s = "<%d chars>" % str(show.s).length()
	say("data", {"ch": ch, "msg": show})
	if not (m is Dictionary):
		return
	got[ch + ":" + str(m.get("t"))] = m
	if ch == "st" and m.get("t") == "ping" and not acked:
		acked = true
		net.send(p, {"t": "gotst"}, "r")
	if m.get("t") == "gotst":
		gotst = true


func _process(_dt: float) -> bool:
	var now := Time.get_ticks_msec()
	if now > deadline:
		say("timeout")
		quit(1)
		return true
	if t_end and now >= t_end:
		quit(0)
		return true
	if other == "" or t_end:
		return false
	if not pinged and net.is_open(other, "u") and net.is_open(other, "st"):
		pinged = true
		net.send(other, {"t": "ping", "ch": "r", "from": "godot", "s": UNI}, "r")
		net.send(other, {"t": "ping", "ch": "u", "from": "godot", "s": UNI}, "u")
		net.send(other, {"t": "big", "s": "g".repeat(12000)}, "r")
		say("refused_big", not net.send(other, {"t": "toobig", "s": "x".repeat(17000)}, "r"))
	if pinged and not gotst and now >= t_st:   # 'st' never resends, and the other end may not have made it yet
		t_st = now + 200
		var m := {"t": "ping", "ch": "st", "from": "godot", "s": UNI}
		if mode == "host":
			m.pad = "S".repeat(30000)   # a big state frame
		net.send(other, m, "st")
	if gotst and got.has("r:ping") and got.has("u:ping") and got.has("st:ping") and got.has("r:big"):
		if not got.has("done"):
			got["done"] = true
			say("done")
			if finish == "close":
				net.close_peer(other)
				t_end = now + 1500
	return false
