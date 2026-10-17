class_name CasinoRelay
extends Node
## Player-hosted casino lobbies (up to 6 people) through the WebSocket relay dev/render/relay.js (wire casino-relay-1),
## as the browser's 21a-casino-relay.js does it. It has PeerNet's API and signals, so PalNet can run its protocol over
## either transport.
##
## The relay routes; the host's screen still runs the floor. Each side holds one socket to the relay:
##   peer ids   host: the relay's id for each guest (a uuid that survives a resume). guest: "host", the only peer.
##   channels   one ordered socket. 'r' is reliable; 'u' and 'st' are volatile (dropped once 16 KiB is waiting to go,
##              as the browser's rlySend(body, true)). Incoming: the relay's volatile types arrive as 's' -> "st" and
##              'i' -> "u", everything else as "r".
##   types      the relay forwards only host welcome/lobby/start/ping/s/x/t/kick/c/relayResume and guest
##              hello/loadout/ping/c/i/ready; send() refuses the rest (false) rather than let them vanish.
##
## Use:
##   var net := CasinoRelay.new(); add_child(net)      # in the tree it polls itself; otherwise call net.poll()
##   net.host("", opts)  -> opened(code): the relay picks the room code (R + 5); read net.code / net.incarnation
##   net.join("RAB2CD", opts)
##   opts: token_fn (Callable -> the current Supabase access token, or {access_token, expires_at}; may be a coroutine;
##             "" when signed out), url (default the public endpoint, dev/render/client.json), enabled (default true),
##         session (24 hex: this run of the game; random by default), incarnation (host: a uuid, random by default;
##             guest: from an invitation, or ""), uid_fn (Callable -> the signed-in account id; a change ends the
##             session as the browser's heartbeat does), game (default "yard-30"), join_ms (default 120000),
##         tls_options (a TLSOptions for wss://; default TLSOptions.client(): the system's CAs. Tests and a relay with a
##             private CA pass TLSOptions.client(their certificate))
##   send(peer_id, msg, "r"|"u"|"st") -> bool   send_all(msg, ch)   is_open(peer_id, ch)   peers()   close_peer(peer_id)
##   remove(peer_id, ban)   set_locked(on)   heartbeat()   room_id()   shutdown()   id: our relay peer id
##
## Signals (PeerNet's, plus three):
##   opened(code)              the relay welcomed us (again after every resume); host: the code it picked
##   error(type, msg)          the session is over and shut down; msg is the browser's player-facing line. Types:
##                             host-closed, host-expired, host-timeout, relay-restarted, removed, locked, full, banned
##                             (account), signed-out, account-changed, session-changed, stale-invite, busy, duplicate,
##                             auth-unavailable, resume-refused, protocol, peer-unavailable (no host behind that code
##                             for the whole join window), timeout, unavailable, invalid-code, refused, closed
##   peer_connected(peer_id)   host: a guest took a seat. guest: the relay let us in ("host")
##   peer_closed(peer_id)      host: a guest left, timed out or was removed. guest: only through close_peer
##   data(peer_id, channel, msg)
##   peer_resumed(peer_id)     host: that guest's socket (or ours) came back within the grace. We already sent the
##                             guest relayResume; re-send what it may have missed (the browser sends 'x' and a full
##                             snapshot in a game, the lobby otherwise).
##   status(text)              the browser's rlyStatus lines: connecting, reconnecting, the host being away; "" clears
##
## A dropped socket is not an error: we reconnect with the relay's resume value (same peer id, same seat) until the
## grace the welcome advertised (2 minutes) runs out. Only then, or when the relay says no, does error() fire.
##
## Why not WebSocketPeer: Godot drops a text frame that lands in the same poll as the close frame, and the relay sends
## every refusal and closure ("This casino is locked.", "The host's sign-in expired…") immediately before closing.
## So this speaks RFC 6455 itself over StreamPeerTCP / StreamPeerTLS.
##
## No Origin header is sent: relay.js admits only allow-listed browser origins, so a native client needs a policy
## decision on the relay (see PAL-079) rather than a spoofed header.

signal opened(id: String)
signal error(type: String, msg: String)
signal peer_connected(peer_id: String)
signal peer_closed(peer_id: String)
signal data(peer_id: String, channel: String, msg)
signal peer_resumed(peer_id: String)
signal status(text: String)

const WIRE := "casino-relay-1"
const GAME := "yard-30"
const DEFAULT_URL := "https://palisade-casino-staging.onrender.com"   # dev/render/client.json (public)
const HOST_ID := "host"
const GRACE_MS := 120000   # also the join window, as rlyEnter's deadline
const HEARTBEAT_MS := 5000
const CONNECT_TIMEOUT_MS := 70000   # a Render Free instance can take about a minute to wake
const TOKEN_RESEND_MS := 10000
const MAX_BUFFERED := 65536   # more than this waiting to go: the connection is too slow (close 4002 and resume)
const VOLATILE_BUFFERED := 16384   # volatile messages are dropped beyond this
const MAX_PAYLOAD := 65536   # the relay's maxPayload: a bigger frame would close us
const HOST_TYPES := ["welcome", "lobby", "start", "ping", "s", "x", "t", "kick", "c", "relayResume"]
const GUEST_TYPES := ["hello", "loadout", "ping", "c", "i", "ready"]

## the browser's own lines (21a-casino-relay.js)
const CONNECTING := "Connecting to the casino… First connection can take about a minute."
const RECONNECTING := "Reconnecting to the casino…"
const UPDATING := "Casino connections are being updated. Try again shortly."
const SIGN_IN := "Sign in again before joining the casino."
const NO_RECONNECT := "Could not reconnect. Open or join the casino again."
const TIMED_OUT := "The casino connection timed out. Try again."
const REPLACED := "This connection was replaced or removed by the host."
const SESSION_CHANGED := "The casino session changed. Join again."
const ACCOUNT_CHANGED := "Account changed. Join the casino again."
const BAD_CODE := "Type your friend's casino room code"
## the relay's lines (relay.js) -> error types, so a caller can branch without matching text
const KINDS := {
	"The casino connection server restarted. Open or join a new casino lobby.": "relay-restarted",
	"The relay restarted. Open or join a new casino lobby.": "relay-restarted",
	"The host's sign-in expired. Sign in and open a new casino.": "host-expired",
	"The host could not reconnect in time. Open or join a new casino.": "host-timeout",
	"The host closed this casino.": "host-closed",
	"Sign in again.": "signed-out",
	"Sign in to a saved account.": "signed-out",
	"Account changed.": "account-changed",
	"This account cannot enter the casino.": "banned",
	"Account verification is unavailable.": "auth-unavailable",
	"This casino is locked.": "locked",
	"This casino is full (6 players).": "full",
	"The host removed you from this casino.": "removed",
	"This invitation belongs to an earlier casino.": "stale-invite",
	"That lobby has closed. Open a new casino.": "closed",
	"All casino lobbies are in use. Try again later.": "busy",
	"This account is already in the casino.": "duplicate",
	"Cannot resume this connection.": "resume-refused",
	"Reload before joining this casino.": "protocol",
	"Bad lobby identity": "protocol",
	"Casino relay cannot start another game.": "protocol",
	"Waiting for the casino host…": "peer-unavailable",
	"Reconnecting to the casino host…": "peer-unavailable",
}


var id := ""   # our relay peer id (kept across resumes)
var role := ""   # "", host, guest
var code := ""   # the room code (the relay's, once welcomed)
var incarnation := ""   # binds invitations; a host's 'start' must carry room_id()
var epoch := ""   # the relay process we're talking to
var connected := false   # welcomed on the current socket
var locked := false
## guest: our player id in the host's game, read from its 'welcome' packet (the browser's myId). A relayResume naming
## anyone else ends the session.
var player_id := ""
var last_http_status := 0   # the relay's answer when a handshake was refused (403: origin not allowed, full, closing)

var _opts := {}
var _active := false
var _gen := 0   # bumps on shutdown: a coroutine that outlived its session must not touch the next one
var _sock: Sock
var _hello_sent := false
var _resume := ""
var _session := ""
var _owner := ""
var _peers := {}   # host: guest relay id -> true. guest: {"host": true}
var _pids := {}   # host: guest relay id -> its player id (from our 'welcome' packet), for relayResume
var _removals: Array = []   # host: removals the relay hasn't heard yet (our socket was down)
var _deadline := 0
var _attempt := 0
var _retry_at := 0
var _timeout_at := 0
var _hb_at := 0
var _err := ""   # the relay's last retryable complaint: the failure message if the window runs out
var _reconnect_ms := GRACE_MS
var _connecting := false
var _refreshing := false
var _hello_token := ""
var _auth_token := ""   # what the relay last verified
var _pending_token := ""
var _pending_expires := 0
var _token_at := 0
var _code_re := RegEx.create_from_string("^R[A-Z2-9]{5}$")
var _hex_re := RegEx.create_from_string("^[0-9a-f]{24}$")
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func _process(_dt: float) -> void:
	poll()


func _exit_tree() -> void:
	shutdown()


# ---------------------------------------------------------------- public

## The relay picks the code (a host's hello carries none); `_code` is ignored. opened(code) gives it.
func host(_code: String = "", opts := {}) -> void:
	shutdown()
	_begin("host", "", opts)


func join(room: String, opts := {}) -> void:
	shutdown()
	var c := room.strip_edges().to_upper()
	if _code_re.search(c) == null:
		_fail_later("invalid-code", BAD_CODE)
		return
	_begin("guest", c, opts)


static func is_code(c: String) -> bool:
	return RegEx.create_from_string("^R[A-Z2-9]{5}$").search(c) != null


## what the relay requires in a casino 'start' packet's room field
func room_id() -> String:
	return "R:%s:%s" % [code, incarnation]


func send(peer_id: String, msg, channel := "r") -> bool:
	if not connected or not (msg is Dictionary) or not (msg.get("t") is String):
		return false
	var t: String = msg.t
	if role == "host":
		if not t in HOST_TYPES or not _peers.has(peer_id):
			return false
		# the relay ends the host's connection over a start for anything but this casino
		if t == "start" and (msg.get("mode") != "casino" or msg.get("map") != "casino" or msg.get("room") != room_id()):
			return false
		if t == "welcome" and msg.get("id") is String:
			_pids[peer_id] = msg.id
	elif not t in GUEST_TYPES or peer_id != HOST_ID:
		return false
	return _raw({"type": "packet", "to": peer_id, "data": msg}, channel != "r")


func send_all(msg, channel := "r") -> void:
	for p in peers():
		send(p, msg, channel)


func is_open(peer_id: String, _channel := "r") -> bool:
	return connected and _peers.has(peer_id)


## the seats we hold. The relay keeps them through our own reconnects, so they don't vanish while we're away.
func peers() -> Array:
	return _peers.keys()


## host: take that guest out (no ban), as the browser's channel close(). guest: leave the casino.
func close_peer(peer_id: String) -> void:
	if role == "host":
		remove(peer_id, false)
	elif role == "guest" and peer_id == HOST_ID and _peers.has(HOST_ID):
		shutdown()
		peer_closed.emit(HOST_ID)


## host: the relay drops that guest (its socket closes with 4004); ban keeps their account out of this room
func remove(peer_id: String, ban := false) -> bool:
	if role != "host" or not _peers.has(peer_id):
		return false
	var body := {"type": "remove", "peer": peer_id}
	if ban:
		body.ban = true
	if not _raw(body):
		_removals.append(body)
	_peers.erase(peer_id)
	_pids.erase(peer_id)
	peer_closed.emit(peer_id)
	return true


## host: a locked room refuses new joins ("This casino is locked."); seated guests can still resume
func set_locked(on: bool) -> void:
	locked = on
	if role == "host":
		_raw({"type": "room", "locked": on})


## Every 5 s while connected: a ping, then the token check. Call it too when the app comes back to the foreground
## or the network returns, as the browser does on visibilitychange / online.
func heartbeat() -> void:
	if not _active:
		return
	if _owner_changed():
		_fail("account-changed", ACCOUNT_CHANGED)
		return
	if not connected and _sock == null and not _connecting:
		_retry_at = 0
		_connect()
		return
	_raw({"type": "ping"})
	if _refreshing or not connected:
		return
	var s := _sock
	var g := _gen
	_refreshing = true
	# A table call or anything else may already have rotated the token: compare against what the relay acknowledged.
	var tok := await _token()
	if g != _gen or _sock != s:
		return
	_refreshing = false
	if not connected or tok.token == "":   # a temporary Auth outage retries next time
		return
	var now := Time.get_ticks_msec()
	if tok.token != _auth_token and (tok.token != _pending_token or now - _token_at >= TOKEN_RESEND_MS):
		if _raw({"type": "token", "token": tok.token}):
			_pending_token = tok.token
			_pending_expires = tok.expires
			_token_at = now


func shutdown() -> void:
	_gen += 1
	if _sock != null:
		if _sock.is_open():
			_raw({"type": "depart"})
		_sock.close(1000, "Left casino")
		_sock = null
	_active = false
	connected = false
	_connecting = false
	_refreshing = false
	_hello_sent = false
	role = ""
	id = ""
	code = ""
	incarnation = ""
	epoch = ""
	locked = false
	player_id = ""
	_resume = ""
	_peers.clear()
	_pids.clear()
	_removals.clear()
	_err = ""
	_reconnect_ms = GRACE_MS
	_retry_at = 0
	_timeout_at = 0
	_attempt = 0
	_auth_token = ""
	_pending_token = ""
	_pending_expires = 0
	_token_at = 0


func poll() -> void:
	var s := _sock
	if s != null:
		s.poll()
		if s.is_open() and not _hello_sent and _sock == s:
			_hello_sent = true
			_raw({"type": "hello", "wire": WIRE, "game": str(_opts.get("game", GAME)), "role": role, "token": _hello_token,
				"session": _session, "code": code, "incarnation": incarnation, "resume": _resume})
		while _sock == s and not s.msgs.is_empty():
			var b = JSON.parse_string(s.msgs.pop_front())
			if b is Dictionary:
				_on_message(b)
		if _sock == s and s.is_closed():
			last_http_status = s.http_status
			_sock = null
			_on_close(s.close_code)
	if not _active:
		return
	var now := Time.get_ticks_msec()
	if _retry_at and now >= _retry_at:
		_retry_at = 0
		_connect()
	if connected and now >= _hb_at:
		_hb_at = now + HEARTBEAT_MS
		heartbeat()
	if _sock != null and not connected and _timeout_at and now >= _timeout_at:
		_timeout_at = 0
		_sock.close(1000, "")


# ---------------------------------------------------------------- session

func _begin(r: String, c: String, opts: Dictionary) -> void:
	_opts = opts
	role = r
	code = c
	incarnation = str(opts.get("incarnation", ""))
	if r == "host" and incarnation == "":
		incarnation = _uuid()
	_session = str(opts.get("session", ""))
	if _hex_re.search(_session) == null:
		_session = _hex(12)
	_owner = _uid()
	if not bool(opts.get("enabled", true)) or _url() == "":
		_fail_later("unavailable", UPDATING)
		return
	_active = true
	_deadline = Time.get_ticks_msec() + int(opts.get("join_ms", GRACE_MS))
	_attempt = 0
	_connect()


func _url() -> String:
	var u := str(_opts.get("url", DEFAULT_URL)).strip_edges()
	if u == "":
		return ""
	if u.begins_with("http"):   # as the browser: replace(/^http/, 'ws') + '/relay'
		u = "ws" + u.substr(4)
	return u.trim_suffix("/") + "/relay"


func _connect() -> void:
	if not _active or _connecting or _sock != null:
		return
	if Time.get_ticks_msec() > _deadline:
		_fail(_kind(_err, "timeout"), _err if _err != "" else NO_RECONNECT)
		return
	var g := _gen
	_connecting = true
	var tok := await _token()
	if g != _gen:
		return
	_connecting = false
	if not _active or _sock != null:
		return
	if _owner_changed():
		_fail("account-changed", ACCOUNT_CHANGED)
		return
	if tok.token == "":
		_fail("signed-out", SIGN_IN)
		return
	status.emit(RECONNECTING if _attempt else CONNECTING)
	if g != _gen:
		return
	_hello_token = tok.token
	_hello_sent = false
	connected = false
	_sock = Sock.new()
	var tls = _opts.get("tls_options")
	if tls is TLSOptions:
		_sock.tls_options = tls
	_sock.start(_url())
	_timeout_at = Time.get_ticks_msec() + CONNECT_TIMEOUT_MS


func _on_message(b: Dictionary) -> void:
	match str(b.get("type", "")):
		"welcome":
			_on_welcome(b)
		"packet":
			var d = b.get("data")
			if not (d is Dictionary) or not (d.get("t") is String):
				return
			var t: String = d.t
			var ch := "st" if t == "s" else ("u" if t == "i" else "r")
			if role == "host":
				var from := str(b.get("from", ""))
				if _peers.has(from):   # not a guest we already let go
					data.emit(from, ch, d)
			else:
				if t == "relayResume":   # for the relay client, as the browser: not a game message
					if player_id != "" and str(d.get("id", "")) != player_id:
						_fail("session-changed", SESSION_CHANGED)
					return
				if t == "welcome" and d.get("id") is String:
					player_id = d.id
				data.emit(HOST_ID, ch, d)
		"peer":
			if role != "host":
				return
			var p := str(b.get("peer", ""))
			if p == "":
				return
			if not _peers.has(p):
				_peers[p] = true
				peer_connected.emit(p)
			elif b.get("resumed"):
				if _pids.has(p):
					_raw({"type": "packet", "to": p, "data": {"t": "relayResume", "id": _pids[p]}})
				peer_resumed.emit(p)
		"left":
			var p := str(b.get("peer", ""))
			if role == "host" and _peers.has(p):
				_peers.erase(p)
				_pids.erase(p)
				peer_closed.emit(p)
		"hostAway":
			status.emit(str(b.get("message", "")))
		"hostBack":
			status.emit("")
		"token":
			var e = b.get("expires")
			if _pending_token != "" and (e is float or e is int) and (_pending_expires == 0 or int(e) == _pending_expires):
				_auth_token = _pending_token
				_pending_token = ""
				_pending_expires = 0
		"closed":
			var m := str(b.get("message", ""))
			_fail(_kind(m, "closed"), m)
		"error":
			var m := str(b.get("message", ""))
			_err = m
			if not b.get("retry", false):
				_fail(_kind(m, "refused"), m)


func _on_welcome(b: Dictionary) -> void:
	var g := _gen
	var first := _resume == ""
	var reset := epoch != "" and epoch != str(b.get("epoch", ""))
	var gm = b.get("graceMs")
	_reconnect_ms = int(gm) if (gm is float or gm is int) and gm >= 1000 and gm <= GRACE_MS else GRACE_MS
	var now := Time.get_ticks_msec()
	connected = true
	_attempt = 0
	_timeout_at = 0
	code = str(b.get("code", ""))
	incarnation = str(b.get("incarnation", ""))
	_resume = str(b.get("resume", ""))
	epoch = str(b.get("epoch", ""))
	id = str(b.get("id", ""))
	_err = ""
	_deadline = now + _reconnect_ms
	_auth_token = _hello_token
	_pending_token = ""
	_pending_expires = 0
	_token_at = 0
	_refreshing = false
	_hb_at = now + HEARTBEAT_MS
	status.emit("")
	if g != _gen:
		return
	if role == "host":
		if reset:   # a different relay process: those seats are gone
			for p in _peers.keys():
				_peers.erase(p)
				_pids.erase(p)
				peer_closed.emit(p)
				if g != _gen:
					return
		if not first:
			# what we told the relay while our socket was down
			for r in _removals:
				_raw(r)
			_removals.clear()
			if locked:
				_raw({"type": "room", "locked": true})
		opened.emit(code)
	else:
		if reset and _peers.has(HOST_ID):
			_peers.erase(HOST_ID)
			peer_closed.emit(HOST_ID)
			if g != _gen:
				return
		opened.emit(code)
		if g != _gen:
			return
		if first or reset:
			_peers[HOST_ID] = true
			peer_connected.emit(HOST_ID)
		else:
			_raw({"type": "ping"})


func _on_close(close_code: int) -> void:
	_timeout_at = 0
	if not _active:
		return
	var now := Time.get_ticks_msec()
	if connected:
		_deadline = now + _reconnect_ms
	connected = false
	if close_code == 4004:   # the relay replaced this connection or the host removed us
		_fail("removed", REPLACED)
		return
	if now > _deadline:
		_fail(_kind(_err, "timeout"), _err if _err != "" else TIMED_OUT)
		return
	status.emit(RECONNECTING)
	_retry_at = now + mini(5000, 500 * (1 << mini(4, _attempt))) + _rng.randi_range(0, 250)
	_attempt += 1


func _fail(type: String, msg: String) -> void:
	shutdown()
	error.emit(type, msg)


## from inside host()/join(): let the caller finish before its error handler runs
func _fail_later(type: String, msg: String) -> void:
	var g := _gen
	(func():
		if g == _gen:
			_fail(type, msg)).call_deferred()


func _kind(msg: String, fallback: String) -> String:
	return KINDS.get(msg, fallback)


func _raw(body: Dictionary, volatile := false) -> bool:
	if _sock == null or not _sock.is_open():
		return false
	var waiting := _sock.buffered()
	if waiting > MAX_BUFFERED:
		_sock.close(4002, "Connection too slow")   # then resume on a fresh socket, as the browser
		return false
	if volatile and waiting > VOLATILE_BUFFERED:
		return false
	var b := JSON.stringify(body).to_utf8_buffer()
	if b.size() > MAX_PAYLOAD:
		return false
	return _sock.send(b)


## {token, expires (ms, 0 unknown)} from opts.token_fn, which may be a coroutine
func _token() -> Dictionary:
	var f = _opts.get("token_fn")
	var r = _opts.get("token", "")
	if f is Callable and f.is_valid():
		r = await f.call()
	if r is Dictionary:
		var t := str(r.get("access_token", r.get("token", "")))
		var ex := int(float(r.get("expires_at", 0)) * 1000.0)
		return {"token": t, "expires": ex if ex > 0 else jwt_exp_ms(t)}
	if r is String:
		return {"token": r, "expires": jwt_exp_ms(r)}
	return {"token": "", "expires": 0}


func _uid() -> String:
	var f = _opts.get("uid_fn")
	return str(f.call()) if f is Callable and f.is_valid() else ""


func _owner_changed() -> bool:
	var f = _opts.get("uid_fn")
	return f is Callable and f.is_valid() and _uid() != _owner


## a Supabase access token's exp, in ms (what the relay acknowledges after a token update)
static func jwt_exp_ms(token: String) -> int:
	var parts := token.split(".")
	if parts.size() < 2:
		return 0
	var s := parts[1].replace("-", "+").replace("_", "/")
	while s.length() % 4:
		s += "="
	var j = JSON.parse_string(Marshalls.base64_to_raw(s).get_string_from_utf8())
	if j is Dictionary and (j.get("exp") is float or j.get("exp") is int):
		return int(j.exp) * 1000
	return 0


func _hex(n: int) -> String:
	var b := PackedByteArray()
	for i in n:
		b.append(_rng.randi_range(0, 255))
	return b.hex_encode()


func _uuid() -> String:
	var b := PackedByteArray()
	for i in 16:
		b.append(_rng.randi_range(0, 255))
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]


# ---------------------------------------------------------------- the socket

## A WebSocket client (RFC 6455) over TCP or TLS. Text frames in and out; answers pings; a close frame or a dropped
## connection ends it. Messages that arrived before the close stay readable in `msgs`.
class Sock:
	extends RefCounted
	const GUID := "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
	const MAX_IN := 1 << 20
	enum {RESOLVING, TCP, TLS, HANDSHAKE, OPEN, CLOSED}

	var phase := CLOSED
	var tls_options: TLSOptions
	var msgs: Array[String] = []
	var close_code := 1006   # as a browser reports a connection that died without a close frame
	var http_status := 0
	var _host := ""
	var _port := 0
	var _path := "/"
	var _secure := false
	var _resolve := -1
	var _tcp: StreamPeerTCP
	var _tls: StreamPeerTLS
	var _io: StreamPeer
	var _key := ""
	var _in := PackedByteArray()
	var _out := PackedByteArray()   # not yet taken by the OS: the browser's bufferedAmount
	var _frag := PackedByteArray()
	var _fragging := false
	var _rng := RandomNumberGenerator.new()
	var _linger_until := 0
	var _unlink := Callable()   # takes the linger step off the SceneTree (it holds us alive until then)

	func start(url: String) -> void:
		_rng.randomize()
		var m := RegEx.create_from_string("^(wss?)://(\\[[^\\]]+\\]|[^/:]+)(?::(\\d+))?(/.*)?$").search(url)
		if m == null:
			phase = CLOSED
			return
		_secure = m.get_string(1) == "wss"
		_host = m.get_string(2).trim_prefix("[").trim_suffix("]")
		_port = int(m.get_string(3)) if m.get_string(3) != "" else (443 if _secure else 80)
		_path = m.get_string(4) if m.get_string(4) != "" else "/"
		if _host.is_valid_ip_address():
			_dial(_host)
		else:
			_resolve = IP.resolve_hostname_queue_item(_host, IP.TYPE_ANY)   # don't block the frame on DNS
			phase = RESOLVING

	func is_open() -> bool:
		return phase == OPEN

	func is_closed() -> bool:
		return phase == CLOSED

	func buffered() -> int:
		return _out.size()

	func send(text: PackedByteArray) -> bool:
		if phase != OPEN:
			return false
		_out.append_array(_frame(0x1, text))
		_flush()
		return true

	## our side ends it: the close frame goes out, and the socket lingers (on the SceneTree, even if our owner is
	## freed) until the server answers, so a depart sent just before isn't lost to a reset
	func close(code: int, reason: String) -> void:
		if phase == OPEN:
			var p := PackedByteArray([code >> 8, code & 255])
			p.append_array(reason.to_utf8_buffer().slice(0, 120))
			_out.append_array(_frame(0x8, p))
			_flush()
			close_code = code
			phase = CLOSED
			_linger(1500)
		else:
			close_code = 1006
			phase = CLOSED
			_hangup()

	func poll() -> void:
		match phase:
			RESOLVING:
				var st := IP.get_resolve_item_status(_resolve)
				if st == IP.RESOLVER_STATUS_WAITING:
					return
				var addr := IP.get_resolve_item_address(_resolve) if st == IP.RESOLVER_STATUS_DONE else ""
				IP.erase_resolve_item(_resolve)
				_resolve = -1
				if addr == "":
					phase = CLOSED
					return
				_dial(addr)
			TCP:
				_tcp.poll()
				var st := _tcp.get_status()
				if st == StreamPeerTCP.STATUS_CONNECTED:
					_tcp.set_no_delay(true)
					if _secure:
						_tls = StreamPeerTLS.new()
						if _tls.connect_to_stream(_tcp, _host, tls_options if tls_options else TLSOptions.client()) != OK:
							_end()
							return
						phase = TLS
					else:
						_io = _tcp
						_handshake()
				elif st != StreamPeerTCP.STATUS_CONNECTING:
					_end()
			TLS:
				_tls.poll()
				var st := _tls.get_status()
				if st == StreamPeerTLS.STATUS_CONNECTED:
					_io = _tls
					_handshake()
				elif st != StreamPeerTLS.STATUS_HANDSHAKING:
					_end()
			HANDSHAKE, OPEN:
				_pump()

	func _dial(addr: String) -> void:
		_tcp = StreamPeerTCP.new()
		if _tcp.connect_to_host(addr, _port) != OK:
			_end()
			return
		phase = TCP

	func _handshake() -> void:
		var k := PackedByteArray()
		for i in 16:
			k.append(_rng.randi_range(0, 255))
		_key = Marshalls.raw_to_base64(k)
		var host_h := _host if not _host.contains(":") else "[%s]" % _host
		if _port != (443 if _secure else 80):
			host_h += ":%d" % _port
		var req := "GET %s HTTP/1.1\r\nHost: %s\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\n\r\n" % [_path, host_h, _key]
		_out.append_array(req.to_ascii_buffer())
		phase = HANDSHAKE
		_flush()

	## move bytes both ways, then read what came
	func _pump() -> void:
		if _tls:
			_tls.poll()
		else:
			_tcp.poll()
		_read()
		_flush()
		if phase == HANDSHAKE:
			_parse_handshake()
		if phase == OPEN:
			_parse_frames()
		if phase != CLOSED and not _alive():
			_end()

	func _alive() -> bool:
		if _tls:
			return _tls.get_status() == StreamPeerTLS.STATUS_CONNECTED
		return _tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED

	func _read() -> void:
		if _io == null or not _alive():   # the OS dropped it (only once nothing was left to read)
			return
		for i in 64:
			var n := _io.get_available_bytes()
			if n <= 0:
				return
			var r := _io.get_partial_data(n)
			if r[0] != OK or r[1].is_empty():
				return
			_in.append_array(r[1])
			if _in.size() > MAX_IN + 16:
				_fail_proto(1009)
				return

	func _flush() -> void:
		if _io == null or _out.is_empty():
			return
		var r := _io.put_partial_data(_out)
		if r[0] == OK and r[1] > 0:
			_out = _out.slice(r[1])

	func _parse_handshake() -> void:
		var end := -1
		for i in range(3, mini(_in.size(), 16384)):
			if _in[i] == 10 and _in[i - 1] == 13 and _in[i - 2] == 10 and _in[i - 3] == 13:
				end = i + 1
				break
		if end < 0:
			if _in.size() >= 16384:
				_end()
			return
		var head := _in.slice(0, end).get_string_from_ascii()
		_in = _in.slice(end)
		var lines := head.split("\r\n")
		var sl := lines[0].split(" ")
		http_status = int(sl[1]) if sl.size() > 1 else 0
		var accept := ""
		for l in lines:
			if l.to_lower().begins_with("sec-websocket-accept:"):
				accept = l.substr(l.find(":") + 1).strip_edges()
		if http_status != 101 or accept != Marshalls.raw_to_base64((_key + GUID).sha1_buffer()):
			_end()
			return
		phase = OPEN

	func _parse_frames() -> void:
		while phase == OPEN and _in.size() >= 2:
			var b0 := _in[0]
			var b1 := _in[1]
			var op := b0 & 0x0f
			var n := b1 & 0x7f
			var off := 2
			if n == 126:
				if _in.size() < 4:
					return
				n = (_in[2] << 8) | _in[3]
				off = 4
			elif n == 127:
				if _in.size() < 10:
					return
				n = 0
				for i in 8:
					n = (n << 8) | _in[2 + i]
				off = 10
			if n > MAX_IN:
				_fail_proto(1009)
				return
			var mk := PackedByteArray()
			if b1 & 0x80:   # servers don't mask; tolerate it anyway
				if _in.size() < off + 4:
					return
				mk = _in.slice(off, off + 4)
				off += 4
			if _in.size() < off + n:
				return
			var p := _in.slice(off, off + n)
			_in = _in.slice(off + n)
			if not mk.is_empty():
				p = Sock._mask(p, mk)
			_on_frame(op, b0 & 0x80 != 0, p)

	func _on_frame(op: int, fin: bool, p: PackedByteArray) -> void:
		match op:
			0x0, 0x1, 0x2:
				if op != 0x0:
					_frag = PackedByteArray()
					_fragging = true
				if not _fragging:
					return
				_frag.append_array(p)
				if _frag.size() > MAX_IN:
					_fail_proto(1009)
					return
				if fin:
					msgs.append(_frag.get_string_from_utf8())
					_frag = PackedByteArray()
					_fragging = false
			0x8:
				close_code = (p[0] << 8) | p[1] if p.size() >= 2 else 1005
				_out.append_array(_frame(0x8, p.slice(0, 2)))   # answer with the same code
				_flush()
				phase = CLOSED
				_linger(500)
			0x9:
				_out.append_array(_frame(0xA, p))
				_flush()

	func _fail_proto(code: int) -> void:
		close(code, "")
		close_code = code

	## the connection went without a close frame
	func _end() -> void:
		phase = CLOSED
		_hangup()

	func _linger(ms: int) -> void:
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			_hangup()
			return
		_linger_until = Time.get_ticks_msec() + ms
		var me := self   # held by the connection below until the socket is done
		var step := func() -> void:
			if me._io and me._alive():
				if me._tls:
					me._tls.poll()
				else:
					me._tcp.poll()
				me._flush()
				if me._alive() and me._io.get_available_bytes() > 0:
					me._io.get_partial_data(me._io.get_available_bytes())   # read and drop: unread data makes a reset
			if not me._alive() or Time.get_ticks_msec() >= me._linger_until:
				me._hangup()
		tree.process_frame.connect(step)
		_unlink = func() -> void:
			if tree.process_frame.is_connected(step):
				tree.process_frame.disconnect(step)

	func _hangup() -> void:
		if _unlink.is_valid():
			var u := _unlink
			_unlink = Callable()
			u.call()
		if _resolve >= 0:
			IP.erase_resolve_item(_resolve)
			_resolve = -1
		if _tls:
			_tls.disconnect_from_stream()
		if _tcp:
			_tcp.disconnect_from_host()
		_io = null

	func _frame(op: int, payload: PackedByteArray) -> PackedByteArray:
		var h := PackedByteArray([0x80 | op])
		var n := payload.size()
		if n < 126:
			h.append(0x80 | n)
		elif n < 65536:
			h.append_array(PackedByteArray([0x80 | 126, n >> 8, n & 255]))
		else:
			h.append(0x80 | 127)
			for i in range(7, -1, -1):
				h.append((n >> (8 * i)) & 255)
		var k := PackedByteArray()
		for i in 4:
			k.append(_rng.randi_range(0, 255))
		h.append_array(k)
		h.append_array(Sock._mask(payload, k))
		return h

	## XOR with the 4-byte key, eight bytes at a time (a frame can be 64 KiB)
	static func _mask(p: PackedByteArray, k: PackedByteArray) -> PackedByteArray:
		var n := p.size()
		var q := p.duplicate()
		q.resize(n + (8 - n % 8) % 8)
		var k8 := PackedByteArray([k[0], k[1], k[2], k[3], k[0], k[1], k[2], k[3]])
		var m := k8.decode_s64(0)
		var a := q.to_int64_array()
		for i in a.size():
			a[i] = a[i] ^ m
		var out := a.to_byte_array()
		out.resize(n)
		return out
