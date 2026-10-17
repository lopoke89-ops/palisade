class_name PeerNet
extends Node
## Online rooms with the browser game (21-online.js), which uses PeerJS 1.5.5. This speaks PeerJS's signalling
## protocol over a WebSocket and makes the same WebRTC data channels, so a Godot player and a browser player can
## host or join each other's rooms.
##
## Each PeerJS "DataConnection" is its own WebRTCPeerConnection with one data channel made by the side that dials.
## A guest dials the host twice: 'r' (ordered, reliable) and 'u' (unordered). Once 'r' is open both sides add the
## negotiated channel 'st' (id 1000, unordered, never resent) on that same connection for game state.
## On 'r' and 'u' every message is UTF-8 JSON sent as BINARY (PeerJS 'json' serialization); on 'st' it is JSON text.
##
## Use:
##   var net := PeerNet.new(); add_child(net)       # in the tree it polls itself; otherwise call net.poll() each frame
##                                                  # (leaving the tree shuts it down)
##   net.host("AB23", {})  /  net.join("AB23", {})
##   opts: host, port, path, secure (default the PeerJS cloud, 0.peerjs.com:443 '/' wss),
##         ice (Array of {urls, username?, credential?}; default Google STUN; [] for local tests),
##         prefix (default 'palisade-yard-27-')
##   send(peer_id, msg, "r"|"u"|"st") -> bool    send_all(msg, ch)    close_peer(peer_id)    shutdown()
##   is_open(peer_id, ch)    peers() -> the peers whose 'r' is open    id: our PeerJS id
##
## Signals:
##   opened(id)             registered with the signalling server (fires again after a host's reconnect)
##   error(type, msg)       PeerJS's error names: unavailable-id, peer-unavailable, timeout, network, server-error,
##                          socket-error, invalid-key, webrtc. For a guest still joining, and for any failure to
##                          register, the session is already shut down when this fires. A host that loses the server
##                          gets 'network', keeps its games running and re-registers by itself.
##   peer_connected(peer_id)   the remote's 'r' is open (host: each guest; guest: the host)
##   peer_closed(peer_id)      that 'r' went away (closed, failed, or closed by us); 'u' dropping is not a leave
##   data(peer_id, channel, msg)   parsed JSON (numbers come back as floats)
##
## Messages on 'r'/'u' of 16300 bytes or more are refused (send returns false), as PeerJS refuses them
## ("Message too big for JSON channel"); 'st' has no such limit.

signal opened(id: String)
signal error(type: String, msg: String)
signal peer_connected(peer_id: String)
signal peer_closed(peer_id: String)
signal data(peer_id: String, channel: String, msg)

const PREFIX := "palisade-yard-27-"
const CODE_CHARS := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const PEERJS_VERSION := "1.5.5"
const MAX_JSON := 16300   # PeerJS's chunkedMTU: its json serializer refuses anything this big
const STUN := [{"urls": "stun:stun.l.google.com:19302"}, {"urls": "stun:stun1.l.google.com:19302"}]
const CLOUD := {"host": "0.peerjs.com", "port": 443, "path": "/", "secure": true}
const HEARTBEAT_MS := 5000
const JOIN_TIMEOUT_MS := 15000
const RECONNECT_MS := 1500
const STALE_MS := 30000   # a half-made connection that never opened
const CLOSE_LINGER_MS := 400   # let the __peerData close reach the other side before the connection goes
const CLOSE_MSG := {"__peerData": {"type": "close"}}


## one PeerJS DataConnection
class Conn:
	var cid := ""
	var peer := ""
	var label := ""
	var reliable := true
	var pc: WebRTCPeerConnection
	var ch: WebRTCDataChannel
	var st: WebRTCDataChannel   # only on 'r'
	var open := false
	var remote_set := false
	var pending: Array = []   # remote candidates waiting for the remote description
	var born := 0
	var kill_at := 0


var id := ""
var role := ""   # "", host, guest
var _opts := {}
var _token := ""
var _ws: WebSocketPeer
var _ws_open := false   # registered (OPEN seen)
var _ever_open := false
var _retry_ms := RECONNECT_MS
var _outq: Array = []   # signalling messages waiting for the socket
var _hb_at := 0
var _reconnect_at := 0
var _target := ""   # the host a guest dials
var _join_by := 0
var _conns := {}   # connectionId -> Conn
var _early := {}   # connectionId -> candidates that came before its OFFER
var _dying: Array = []   # Conns lingering after close_peer
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func _process(_dt: float) -> void:
	poll()


func _exit_tree() -> void:
	shutdown()


# ---------------------------------------------------------------- public

func host(code: String, opts := {}) -> void:
	shutdown()
	_opts = opts
	role = "host"
	id = str(opts.get("prefix", PREFIX)) + code
	_start_socket()


func join(code: String, opts := {}) -> void:
	shutdown()
	_opts = opts
	role = "guest"
	_target = str(opts.get("prefix", PREFIX)) + code
	id = _uuid()   # the browser asks the server for one (GET /peerjs/id); any valid id works
	_join_by = Time.get_ticks_msec() + JOIN_TIMEOUT_MS
	_start_socket()


static func gen_code(rng: RandomNumberGenerator = null) -> String:
	var s := ""
	for i in 4:
		s += CODE_CHARS[rng.randi_range(0, CODE_CHARS.length() - 1) if rng else randi() % CODE_CHARS.length()]
	return s


func send(peer_id: String, msg, channel := "r") -> bool:
	return _send_text(peer_id, JSON.stringify(msg), channel)


func send_all(msg, channel := "r") -> void:
	var s := JSON.stringify(msg)
	for p in peers():
		_send_text(p, s, channel)


func is_open(peer_id: String, channel := "r") -> bool:
	return _chan(peer_id, channel) != null


func peers() -> Array:
	var out: Array = []
	for c: Conn in _conns.values():
		if c.label != "u" and c.open and not out.has(c.peer):
			out.append(c.peer)
	return out


## tell the peer we're closing (PeerJS's close message), then close both of its connections
func close_peer(peer_id: String) -> void:
	var now := Time.get_ticks_msec()
	for c: Conn in _conns.values():
		if c.peer == peer_id:
			if c.open and c.ch.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
				c.ch.put_packet(JSON.stringify(CLOSE_MSG).to_utf8_buffer())
			c.kill_at = now + CLOSE_LINGER_MS
	for c: Conn in _conns.values():
		if c.peer == peer_id and _conns.has(c.cid):   # dropping 'r' takes 'u' along
			_dying.append(c)
			_drop(c, false)


func shutdown() -> void:
	for c: Conn in _conns.values():
		if c.open and c.ch.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
			c.ch.put_packet(JSON.stringify(CLOSE_MSG).to_utf8_buffer())   # best effort: the channel closing says it too
		_kill(c)
	for c: Conn in _dying:
		_kill(c)
	_conns.clear()
	_early.clear()
	_dying.clear()
	if _ws:
		_ws.close()
	_ws = null
	_ws_open = false
	_ever_open = false
	_outq.clear()
	_reconnect_at = 0
	_retry_ms = RECONNECT_MS
	_join_by = 0
	_target = ""
	role = ""


func poll() -> void:
	var now := Time.get_ticks_msec()
	_poll_socket(now)
	for c: Conn in _conns.values():   # a copy: handlers may close connections
		if _conns.has(c.cid):
			_poll_conn(c, now)
	for c: Conn in _dying.duplicate():
		c.pc.poll()
		if now >= c.kill_at:
			_kill(c)
			_dying.erase(c)
	if _join_by and now >= _join_by:
		_fail("timeout", "The room didn't answer.")


# ---------------------------------------------------------------- signalling

func _start_socket() -> void:
	if _token == "":
		_token = _rand_token()
	var host_ := str(_opts.get("host", CLOUD.host))
	var port := int(_opts.get("port", CLOUD.port))
	var secure := bool(_opts.get("secure", CLOUD.secure))
	var path := str(_opts.get("path", CLOUD.path))
	if not path.begins_with("/"):
		path = "/" + path
	if not path.ends_with("/"):
		path += "/"
	var url := "%s://%s:%d%speerjs?key=peerjs&id=%s&token=%s&version=%s" % ["wss" if secure else "ws", host_, port, path, id.uri_encode(), _token, PEERJS_VERSION]
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 20
	_ws_open = false
	var err := _ws.connect_to_url(url)
	if err != OK:
		_ws = null
		_socket_lost(-1)


func _poll_socket(now: int) -> void:
	if _ws == null:
		if _reconnect_at and now >= _reconnect_at:
			_reconnect_at = 0
			_start_socket()
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	# read even when closed: the server says ID-TAKEN and hangs up in the same breath
	while _ws and _ws.get_available_packet_count() > 0:
		var m = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
		if m is Dictionary:
			_on_server(m)
	if _ws == null:
		return
	if state == WebSocketPeer.STATE_OPEN:
		if _ws_open and now >= _hb_at:
			_hb_at = now + HEARTBEAT_MS
			_ws.send_text(JSON.stringify({"type": "HEARTBEAT"}))
	elif state == WebSocketPeer.STATE_CLOSED:
		var code := _ws.get_close_code()
		_ws = null
		_socket_lost(code)


## code: the WebSocket close code, -1 when it never got as far as a WebSocket
func _socket_lost(code: int) -> void:
	var was := _ws_open
	_ws_open = false
	if role == "host" and _ever_open:
		# players already connected keep playing (their channels don't need the server); win the room code back.
		# The same token lets the server hand us our own id again.
		_reconnect_at = Time.get_ticks_msec() + _retry_ms
		_retry_ms = mini(_retry_ms * 2, 12000)
		if was:
			error.emit("network", "Lost connection to server.")
		return
	if not was and code >= 0 and role == "host":
		# The server took the socket and hung up before OPEN: that is ID-TAKEN (a bad key or id is the only other
		# reason, and ours are fixed). Godot drops a message that lands in the same poll as the close, so the
		# ID-TAKEN text itself never reaches us.
		_fail("unavailable-id", "ID \"%s\" is taken" % id)
	elif not was and code >= 0:
		_fail("server-error", "The signalling server refused us.")
	elif not was:   # never got through to the server
		_fail("socket-error", "Couldn't reach the signalling server.")
	elif _join_by:
		_fail("network", "Lost connection to server.")
	else:
		error.emit("network", "Lost connection to server.")


func _signal(m: Dictionary) -> void:
	if _ws and _ws_open:
		_ws.send_text(JSON.stringify(m))
	elif _outq.size() < 256:
		_outq.append(m)


func _on_server(m: Dictionary) -> void:
	var type := str(m.get("type", ""))
	var src := str(m.get("src", ""))
	var p = m.get("payload")
	match type:
		"OPEN":
			_ws_open = true
			_ever_open = true
			_retry_ms = RECONNECT_MS
			_hb_at = Time.get_ticks_msec() + HEARTBEAT_MS
			for q in _outq:
				_ws.send_text(JSON.stringify(q))
			_outq.clear()
			opened.emit(id)
			if role == "guest" and _join_by and _conns.is_empty():
				_dial(_target, "r", true)
				_dial(_target, "u", false)
		"ID-TAKEN":
			_fail("unavailable-id", "ID \"%s\" is taken" % id)
		"INVALID-KEY":
			_fail("invalid-key", "API KEY \"peerjs\" is invalid")
		"ERROR":
			_fail("server-error", str(p.get("msg", "")) if p is Dictionary else "")
		"LEAVE":   # PeerJS drops every connection to a peer that left the server
			for c: Conn in _conns.values():
				if c.peer == src:
					_drop(c, true)
		"EXPIRE":   # our OFFER sat at the server: nobody has that id
			if role == "guest" and _join_by and src == _target:
				_fail("peer-unavailable", "Could not connect to peer " + src)
			else:
				for c: Conn in _conns.values():
					if c.peer == src and not c.open:
						_drop(c, true)
				error.emit("peer-unavailable", "Could not connect to peer " + src)
		"OFFER":
			if p is Dictionary and role == "host":   # a guest only talks to its host
				_on_offer(src, p)
		"ANSWER":
			if p is Dictionary and _conns.has(str(p.get("connectionId", ""))):
				var c: Conn = _conns[str(p.connectionId)]
				var sdp = p.get("sdp")
				if sdp is Dictionary and not c.remote_set:
					c.pc.set_remote_description("answer", str(sdp.get("sdp", "")))
					c.remote_set = true
					_flush_candidates(c)
		"CANDIDATE":
			if p is Dictionary and p.get("candidate") is Dictionary:
				var cid := str(p.get("connectionId", ""))
				var c: Conn = _conns.get(cid)
				if c == null:   # it can beat its OFFER here
					if _early.size() > 32:   # offers that never came
						_early.clear()
					if not _early.has(cid):
						_early[cid] = []
					if _early[cid].size() < 64:
						_early[cid].append(p.candidate)
				else:
					c.pending.append(p.candidate)
					if c.remote_set:
						_flush_candidates(c)


func _fail(type: String, msg: String) -> void:
	if role == "host" and _ever_open:
		# as PeerJS: once registered, a server refusal only disconnects, and the browser's host reconnects after it
		if _ws:
			_ws.close()
		_ws = null
		_ws_open = false
		_reconnect_at = Time.get_ticks_msec() + _retry_ms
		_retry_ms = mini(_retry_ms * 2, 12000)
	else:
		shutdown()
	error.emit(type, msg)


# ---------------------------------------------------------------- connections

func _new_pc(c: Conn) -> bool:
	c.pc = WebRTCPeerConnection.new()
	var ice: Array = []
	for s in _opts.get("ice", STUN):
		if s is Dictionary and s.has("urls"):
			var e := {"urls": s.urls if s.urls is Array else [str(s.urls)]}   # the browser takes a string or a list
			if s.has("username"):
				e.username = str(s.username)
			if s.has("credential"):
				e.credential = str(s.credential)
			ice.append(e)
	if c.pc.initialize({"iceServers": ice}) != OK:
		return false
	c.pc.session_description_created.connect(_on_sdp.bind(c))
	c.pc.ice_candidate_created.connect(_on_candidate.bind(c))
	c.pc.data_channel_received.connect(_on_channel.bind(c))
	c.born = Time.get_ticks_msec()
	_conns[c.cid] = c
	return true


func _dial(peer_id: String, label: String, reliable: bool) -> void:
	var c := Conn.new()
	c.cid = "dc_" + _rand_token()
	c.peer = peer_id
	c.label = label
	c.reliable = reliable
	if not _new_pc(c):
		_fail("webrtc", "Couldn't start WebRTC.")
		return
	c.ch = c.pc.create_data_channel(label, {"ordered": reliable})   # exactly what PeerJS asks for
	if c.ch == null:
		_fail("webrtc", "Couldn't make a data channel.")
		return
	c.ch.write_mode = WebRTCDataChannel.WRITE_MODE_BINARY
	c.pc.create_offer()


func _on_offer(src: String, p: Dictionary) -> void:
	var cid := str(p.get("connectionId", ""))
	var sdp = p.get("sdp")
	if cid == "" or not (sdp is Dictionary) or str(p.get("type", "data")) != "data":
		return
	if _conns.has(cid):
		_drop(_conns[cid], true)
	var c := Conn.new()
	c.cid = cid
	c.peer = src
	c.label = str(p.get("label", ""))
	if not _new_pc(c):
		return
	c.pending = _early.get(cid, [])
	_early.erase(cid)
	c.pc.set_remote_description("offer", str(sdp.get("sdp", "")))   # makes the answer: session_description_created
	c.remote_set = true
	_flush_candidates(c)


func _on_sdp(type: String, sdp: String, c: Conn) -> void:
	if not _conns.has(c.cid):
		return
	c.pc.set_local_description(type, sdp)
	var payload := {"sdp": {"type": type, "sdp": sdp}, "type": "data", "connectionId": c.cid}
	if type == "offer":
		payload.merge({"label": c.label, "reliable": c.reliable, "serialization": "json", "metadata": null})
	_signal({"type": type.to_upper(), "payload": payload, "dst": c.peer})


func _on_candidate(mid: String, index: int, cand: String, c: Conn) -> void:
	if not _conns.has(c.cid) or cand == "":
		return
	if cand.begins_with("a="):
		cand = cand.substr(2)
	_signal({"type": "CANDIDATE", "payload": {"candidate": {"candidate": cand, "sdpMid": mid, "sdpMLineIndex": index}, "type": "data", "connectionId": c.cid}, "dst": c.peer})


func _on_channel(ch: WebRTCDataChannel, c: Conn) -> void:
	if c.ch == null and not ch.is_negotiated():
		c.ch = ch
		ch.write_mode = WebRTCDataChannel.WRITE_MODE_BINARY
		if c.label == "":
			c.label = ch.get_label()


func _flush_candidates(c: Conn) -> void:
	for k in c.pending:
		var s := str(k.get("candidate", ""))
		if s != "":   # an empty one is the browser's end-of-candidates
			c.pc.add_ice_candidate(str(k.get("sdpMid", "0")), int(k.get("sdpMLineIndex", 0)), s)
	c.pending.clear()


func _poll_conn(c: Conn, now: int) -> void:
	c.pc.poll()
	var pcs := c.pc.get_connection_state()
	if pcs == WebRTCPeerConnection.STATE_FAILED or pcs == WebRTCPeerConnection.STATE_CLOSED:
		_drop(c, true)
		return
	if c.ch == null:
		if now - c.born > STALE_MS:
			_drop(c, true)
		return
	c.ch.poll()
	var cs := c.ch.get_ready_state()
	if not c.open:
		if cs == WebRTCDataChannel.STATE_OPEN:
			c.open = true
			if c.label != "u":
				# the browser's openStateCh: both ends add the same pre-agreed channel, no extra signalling
				c.st = c.pc.create_data_channel("st", {"negotiated": true, "id": 1000, "ordered": false, "maxRetransmits": 0})
				if c.st:
					c.st.write_mode = WebRTCDataChannel.WRITE_MODE_TEXT
				if role == "guest" and c.peer == _target:
					_join_by = 0
				peer_connected.emit(c.peer)
		elif cs == WebRTCDataChannel.STATE_CLOSED or now - c.born > STALE_MS:
			_drop(c, true)
			return
		else:
			return
	while c.ch.get_available_packet_count() > 0:
		var m = JSON.parse_string(c.ch.get_packet().get_string_from_utf8())
		if m is Dictionary and m.has("__peerData"):
			if m.__peerData is Dictionary and m.__peerData.get("type") == "close":
				_drop(c, true)
				return
			continue   # a chunk from another serializer: not ours
		if m != null:
			data.emit(c.peer, c.label, m)
		if not _conns.has(c.cid):
			return
	if c.st:
		c.st.poll()
		while c.st and c.st.get_available_packet_count() > 0:
			var m = JSON.parse_string(c.st.get_packet().get_string_from_utf8())
			if m != null:
				data.emit(c.peer, "st", m)
			if not _conns.has(c.cid):
				return
	if c.ch.get_ready_state() == WebRTCDataChannel.STATE_CLOSED:
		_drop(c, true)


## forget a connection. kill: close its WebRTC now (otherwise close_peer's linger does it).
func _drop(c: Conn, kill: bool) -> void:
	if not _conns.has(c.cid):
		return
	_conns.erase(c.cid)
	if kill:
		_kill(c)
	if c.label != "u" and c.open:
		# the peer's fast channel goes with it
		for u: Conn in _conns.values():
			if u.peer == c.peer and u.label == "u":
				_conns.erase(u.cid)
				if kill:
					_kill(u)
				else:
					u.kill_at = c.kill_at
					_dying.append(u)
		peer_closed.emit(c.peer)


func _kill(c: Conn) -> void:
	if c.st:
		c.st.close()
	if c.ch:
		c.ch.close()
	if c.pc:
		c.pc.close()


func _chan(peer_id: String, channel: String) -> WebRTCDataChannel:
	for c: Conn in _conns.values():
		if c.peer != peer_id or not c.open:
			continue
		if channel == "u" and c.label == "u" and c.ch.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
			return c.ch
		if c.label == "u":
			continue
		if channel == "r" and c.ch.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
			return c.ch
		if channel == "st" and c.st and c.st.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
			return c.st
	return null


func _send_text(peer_id: String, s: String, channel: String) -> bool:
	var x := _chan(peer_id, channel)
	if x == null and channel != "r":   # like the browser's sendAll: fall back to the reliable channel
		channel = "r"
		x = _chan(peer_id, "r")
	if x == null:
		return false
	var b := s.to_utf8_buffer()
	if channel == "st":
		return x.put_packet(b) == OK   # write mode text: the browser JSON.parse()s ev.data
	if b.size() >= MAX_JSON:
		return false
	return x.put_packet(b) == OK


# ---------------------------------------------------------------- ids

func _rand_token() -> String:
	# PeerJS: Math.random().toString(36).slice(2)
	const A := "0123456789abcdefghijklmnopqrstuvwxyz"
	var s := ""
	for i in 11:
		s += A[_rng.randi_range(0, 35)]
	return s


func _uuid() -> String:
	var b := PackedByteArray()
	for i in 16:
		b.append(_rng.randi_range(0, 255))
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]
