extends SceneTree
## The Godot half of tests/relay_cross.js (CasinoRelay with the browser's own relay client, 21a, in Chromium). Not a
## test on its own.
##   godot --headless --path godot --script res://tests/relay_cross_driver.gd -- host|guest URL TOKEN CMDFILE [CODE]
## Prints one JSON line per event ("EV [...]"). guest: says hello like PalNet once the relay lets it in. host: answers
## a hello with a welcome, a lobby and a chat line, as the browser's host would start. The script steers it by
## appending lines to CMDFILE: chat PEER TEXT | lock | unlock | remove PEER 0|1 | drop | leave | quit

var net: CasinoRelay
var mode := ""
var cmd_file := ""
var done_lines := 0
var next_g := 1
var deadline := 0
var cmd_at := 0


func say(a: Array) -> void:
	print("EV " + JSON.stringify(a))


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	mode = a[0]
	var url := a[1]
	var tok := a[2]
	cmd_file = a[3]
	deadline = Time.get_ticks_msec() + 120000
	net = CasinoRelay.new()
	root.add_child(net)
	net.opened.connect(func(c): say(["opened", c, net.id, net.incarnation]))
	net.error.connect(func(t, m):
		say(["error", t, m])
		_quit.call_deferred())
	net.status.connect(func(s): say(["status", s]))
	net.peer_connected.connect(_on_connected)
	net.peer_closed.connect(func(p): say(["closed", p]))
	net.peer_resumed.connect(func(p): say(["resumed", p]))
	net.data.connect(_on_data)
	var opts := {"url": url, "token_fn": func(): return tok}
	if mode == "host":
		net.host("", opts)
	else:
		net.join(a[4], opts)


func _on_connected(p: String) -> void:
	say(["connected", p])
	if mode == "guest":
		# what PalNet sends when its host connection opens
		net.send(p, {"t": "hello", "name": "GodotGuest", "cls": "soldier", "cos": "std|class|std|none", "v": "yard-29", "sk": "", "uid": "",
			"session": "0123456789abcdef01234567", "invitationSession": ""})


func _on_data(p: String, ch: String, m) -> void:
	if not (m is Dictionary):
		return
	var keep := {"t": m.get("t")}
	for k in ["id", "room", "mode", "map", "m", "uid", "name", "v", "code", "n"]:
		if m.has(k) and not (m[k] is Array or m[k] is Dictionary):
			keep[k] = m[k]
	say(["data", p, ch, keep])
	if mode == "host" and m.get("t") == "hello":
		var gid := "g%d" % next_g
		next_g += 1
		net.send(p, {"t": "welcome", "id": gid})
		net.send(p, {"t": "lobby", "roster": [{"id": "host", "name": "GodotHost", "cls": "soldier", "cos": "std|class|std|none", "team": "a", "sk": ""},
			{"id": gid, "name": str(m.get("name", "")), "cls": "soldier", "cos": "std|class|std|none", "team": "a", "sk": ""}],
			"code": net.code, "diff": "normal", "mode": "casino", "pvp": "coop", "map": "casino", "size": "std", "playing": false, "mods": [], "job": "", "locked": net.locked})
		net.send(p, {"t": "c", "id": "host", "n": "GodotHost", "m": "welcome from Godot"})


func _process(_dt: float) -> bool:
	var now := Time.get_ticks_msec()
	if now > deadline:
		say(["timeout"])
		_quit()
		return true
	if now >= cmd_at:
		cmd_at = now + 100
		_commands()
	return false


func _commands() -> void:
	if not FileAccess.file_exists(cmd_file):
		return
	var lines := FileAccess.get_file_as_string(cmd_file).split("\n", false)
	while done_lines < lines.size():
		var w := lines[done_lines].split(" ", false, 2)
		done_lines += 1
		say(["cmd", " ".join(w)])
		match w[0]:
			"chat":
				say(["sent", net.send(w[1], {"t": "c", "id": "host", "n": "GodotHost", "m": w[2]} if mode == "host" else {"t": "c", "m": w[2]})])
			"lock":
				net.set_locked(true)
			"unlock":
				net.set_locked(false)
			"remove":
				say(["sent", net.remove(w[1], w[2] == "1")])
			"drop":
				net._sock._end()   # the network goes away under us
			"leave":
				net.shutdown()
			"quit":
				_quit()


func _quit() -> void:
	net.shutdown()
	say(["bye"])
	quit(0)
