class_name PalNet
extends Node
## Online play (dev/src/js/21-online.js and 05-net-record.js), wire-compatible with the browser (protocol yard-29),
## so a Godot screen and a browser tab can share one room either way round.
##
## One screen hosts and runs the real match; the others join with a 4-character room code. PeerJS only introduces
## them (PeerNet), then they talk directly over three channels per guest: 'r' (reliable: hello, actions, chat and every
## one-off event), 'u' (fast: movement in) and 'st' (never resent: game state out, 15 times a second).
##
## main.gd owns the screen: it calls host_frame() after sim.update on the host, guest_frame() instead of sim.update on
## a guest, and the send_* functions where a guest's actions would otherwise go straight into the sim.

const PROTO := "yard-29"
const ROOM_PREFIX := "palisade-yard-27-"
const CODE_CHARS := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const LIMITS := {"name": 12, "chat": 120, "cos": 160, "skills": 160, "targetPad": 100, "moveBurst": 2.0}
## append only: the browser's enemy codes on the wire (10-phases-bosses.js, 10c, 10d, 10g)
const ECODE := ["rifle", "gren", "breach", "boss:demolisher", "boss:butcher", "boss:storm", "shield", "medic", "spotter", "fire", "boss:ferryman", "boss:foreman",
	"boss:harbinger", "boss:bluebutcher", "boss:arsonist", "boss:tempest", "boss:bulldozer", "boss:rime", "boss:whitebutcher", "boss:whiteferryman", "boss:whiteforeman", "boss:destroyer"]
const BO_STAGES := ["gather", "attack", "gap", "push", "done", "ready"]
const BO_NEAR := 22.0
const FAIL := {"peer-unavailable": "No game with that code. Check it with the host, and make sure they're sitting in the lobby.",
	"network": "Couldn't reach the matchmaking service. Check your connection and try again.",
	"server-error": "The matchmaking service is having trouble. Try again in a minute.",
	"socket-error": "Couldn't reach the matchmaking service. Check your connection and try again.",
	"timeout": "The room didn't answer. Some networks block direct connections; try both being on Wi-Fi."}

signal lobby_changed   # the roster or the room's settings changed (redraw the lobby)
signal started         # a match began on this screen (host or guest)
signal left(msg: String)   # back to the menu, with why ("" when we chose to)
signal status(text: String)   # a line for the online page while opening or joining
signal chat_line(line: Dictionary)   # {id, name, text, col}
signal room_closed(incarnation: String)   # the host's room is gone: take it off the open games list

var sim: Sim
var peer: PeerNet
var mode := "solo"   # solo, opening, host, joining, guest
var code := ""
var my_id := "solo"
var roster: Array = []   # [{id, name, cls, cos, team, sk, ready}]
var in_game := false
## the room's settings, as the host's lobby shows them: diff, mode, pvp ('coop', 'base', 'ffa'), map, size, mods, job
var pick := {"diff": "normal", "mode": "5", "pvp": "coop", "map": "yard", "size": "std", "mods": [], "job": ""}
var me := {"name": "PLAYER", "cls": "soldier", "cos": "std|class|std|none", "sk": "", "uid": ""}   # set by main before hosting or joining
var opts := {}   # PeerNet options (the local peer server in tests)
var locked := false
var incarnation := ""
var session := ""   # this run of the game, so a dropped guest who comes back gets their kit back
var chat: Array = []
var cas_room := ""   # a guest's casino room id, from the host's start message
var main_ref   # main, for the casino room id (cas_room()) in the start message

var _conns := {}   # host: peer id -> {pid, session, name, cls, cos, uid, sk, heard, moveAt, moveBudget, kicked}
var _host_peer := ""   # guest: the host's peer id
var _banned := {}
var _left_by := {}
var _next_g := 1
var _ready_sig = null
var _snap_t := 0.0
var _snap_n := 0
var _last_n := 0
var _in_t := 0.0
var _lobby_t := 0.0
var _heard := 0.0   # guest: when the host was last heard (msec)
var _wl_sent := PackedByteArray()
var _wl_at := 0
var _pi_sent := {}
var _ps_last := {}
var _fxq: Array = []
var _bullets_seen := {}   # host: bullet ids already sent
var _chat_rate := {}
var _join_t := 0.0


const SESSION_PATH := "user://room_session.json"
static var keep_session := true   # tests turn it off


## the room session survives a restart for a while (the browser's survives a reload in the same tab), so a guest who
## crashed or lost the game and comes straight back gets their armory, salvage and kills back from the host
func _ready() -> void:
	if keep_session and FileAccess.file_exists(SESSION_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SESSION_PATH))
		if d is Dictionary and str(d.get("id", "")).length() == 24 and Time.get_unix_time_from_system() - float(d.get("at", 0)) < 3600:
			session = d.id
	if session == "":
		var b := PackedByteArray()
		for i in 12:
			b.append(randi() % 256)
		session = b.hex_encode()
	_touch_session()


func _touch_session() -> void:
	if not keep_session:
		return
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"id": session, "at": Time.get_unix_time_from_system()}))


func _now() -> float:
	return Time.get_ticks_msec()


func is_online() -> bool:
	return mode == "host" or mode == "guest"


func guest() -> bool:
	return mode == "guest" and in_game


## tracers travel as their place in the catalog's TRAILS (the browser's TRAIL_IDS, the same order)
static func trail_index(id: String) -> int:
	return maxi(0, PalLocker.catalog().TRAILS.keys().find(id))


static func trail_id(i: int) -> String:
	var ks: Array = PalLocker.catalog().TRAILS.keys()
	return ks[i] if i >= 0 and i < ks.size() else "std"


static func r2(v: float) -> float:
	return roundf(v * 100.0) / 100.0


static func gen_code() -> String:
	var s := ""
	for i in 4:
		s += CODE_CHARS[randi() % CODE_CHARS.length()]
	return s


# ---------------------------------------------------------------- opening and joining

func _new_peer() -> void:
	if peer != null:
		peer.shutdown()
		peer.queue_free()
	peer = PeerNet.new()
	add_child(peer)
	peer.opened.connect(_on_opened)
	peer.error.connect(_on_error)
	peer.peer_connected.connect(_on_peer_connected)
	peer.peer_closed.connect(_on_peer_closed)
	peer.data.connect(_on_data)


func host_room() -> void:
	_touch_session()
	if mode == "opening" or mode == "joining" or is_online():
		return
	mode = "opening"
	status.emit("Opening a room…")
	_new_peer()
	code = gen_code()
	peer.host(code, opts)


var _invite := ""   # the room incarnation an accepted invitation was for


func join_room(c: String, invitation: String = "") -> void:
	_invite = invitation
	_touch_session()
	c = c.to_upper().strip_edges()
	var clean := ""
	for ch in c:
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			clean += ch
	if clean.length() != 4:
		status.emit("Room codes are 4 letters and numbers.")
		return
	if mode == "opening" or mode == "joining" or is_online():
		return
	mode = "joining"
	code = clean
	status.emit("Finding room %s…" % clean)
	_new_peer()
	peer.join(clean, opts)


func _on_opened(_id: String) -> void:
	if mode == "opening":
		incarnation = PalAccount.new_operation()
		mode = "host"
		my_id = "host"
		locked = false
		_banned.clear()
		roster = [{"id": "host", "name": me.name, "cls": me.cls, "cos": me.cos, "team": "a", "sk": me.sk}]
		status.emit("")
		broadcast_lobby()


func _on_error(type: String, msg: String) -> void:
	if type == "unavailable-id" and mode == "opening":   # someone has that code: pick another
		code = gen_code()
		_new_peer()
		peer.host(code, opts)
		return
	if mode == "host" and type in ["network", "server-error", "socket-error", "socket-closed", "disconnected", "peer-unavailable"]:
		return   # players already connected keep playing; PeerNet re-registers the room
	if mode == "guest" and type in ["network", "server-error", "socket-error", "socket-closed", "disconnected"]:
		return
	var why: String = FAIL.get(type, "Couldn't connect (%s)." % type)
	reset()
	left.emit(why)


func leave(msg: String = "") -> void:
	reset()
	left.emit(msg)


func reset() -> void:
	if mode == "host":
		room_closed.emit(incarnation)
	if peer != null:
		peer.shutdown()
		peer.queue_free()
		peer = null
	mode = "solo"
	in_game = false
	code = ""
	roster = []
	_conns.clear()
	_host_peer = ""
	my_id = "solo"
	_fxq.clear()
	_bullets_seen.clear()
	_left_by.clear()
	chat.clear()
	locked = false


# ---------------------------------------------------------------- host: guests arriving and talking

func _on_peer_connected(pid: String) -> void:
	if mode == "host":
		_conns[pid] = {"pid": "", "heard": _now()}
	elif mode == "joining":
		_host_peer = pid
		_heard = _now()
		peer.send(pid, {"t": "hello", "name": me.name, "cls": me.cls, "cos": me.cos, "v": PROTO, "sk": me.sk, "uid": me.uid, "session": session, "invitationSession": _invite})


func _on_peer_closed(pid: String) -> void:
	if mode == "host":
		_host_drop(pid)
	elif (mode == "guest" or mode == "joining") and pid == _host_peer:
		leave("The host closed the game.")


func _on_data(pid: String, _ch: String, d) -> void:
	if not (d is Dictionary) or not (d.get("t") is String):
		return
	if mode == "host":
		_host_data(pid, d)
	else:
		_guest_data(d)


static func _fin(v, lo: float, hi: float) -> bool:
	return (v is float or v is int) and is_finite(float(v)) and float(v) >= lo and float(v) <= hi


static func _int(v, lo: int, hi: int) -> bool:
	return (v is float or v is int) and float(v) == floorf(float(v)) and float(v) >= lo and float(v) <= hi


static func _text(v, mx: int) -> bool:
	return v is String and v.length() <= mx


func _lighter(list: Array) -> String:
	var a := 0
	var b := 0
	for r in list:
		if r.get("team", "") == "b":
			b += 1
		else:
			a += 1
	return "a" if a <= b else "b"


func _send_to(pid_or_player: String, msg: Dictionary) -> void:   # by player id
	for k in _conns:
		if _conns[k].get("pid", "") == pid_or_player:
			peer.send(k, msg)


func _send_all(msg: Dictionary, ch: String = "r") -> void:
	if peer == null:
		return
	for k in _conns:
		if _conns[k].get("pid", "") != "":
			peer.send(k, msg, ch)


func _host_data(peer_id: String, d: Dictionary) -> void:
	var c: Dictionary = _conns.get(peer_id, {})
	if c.is_empty() or c.get("kicked", false):
		return
	c.heard = _now()
	var t: String = d.t
	if t == "hello":
		if c.pid != "":
			return
		if d.get("v") != PROTO:
			peer.send(peer_id, {"t": "kick", "why": "Your copy of PALISADE is a different version from the host's. Both of you update or reload."})
			return
		var inv: String = str(d.get("invitationSession", ""))
		if inv != "" and inv != incarnation:
			peer.send(peer_id, {"t": "kick", "why": "That invitation belongs to an earlier room. Ask for a new invite."})
			return
		var ses: String = str(d.get("session", ""))
		if ses.length() != 24 or not ses.is_valid_hex_number():
			return
		if _banned.has(ses):
			peer.send(peer_id, {"t": "kick", "why": "The host removed you from the game."})
			return
		if locked:
			peer.send(peer_id, {"t": "kick", "why": "Room is locked."})
			return
		if not _text(d.get("name"), LIMITS.name) or not Pal.CLASSES.has(d.get("cls", "")) or not _text(d.get("cos"), LIMITS.cos) or not _text(d.get("sk", ""), LIMITS.skills):
			return
		if roster.size() >= 6:
			peer.send(peer_id, {"t": "kick", "why": "That game is full (6 players)."})
			return
		c.pid = "g%d" % _next_g
		_next_g += 1
		c.session = ses
		c.name = str(d.name).substr(0, 12) if str(d.name) != "" else "Player"
		c.cls = d.cls
		c.cos = str(d.cos)
		c.uid = str(d.get("uid", ""))
		c.sk = ""   # a guest's skill tree counts once it has been checked against their account (main's check_skills)
		var team := _lighter(sim.players.values()) if in_game and sim.pvp() == "base" else _lighter(roster)
		roster.append({"id": c.pid, "name": c.name, "cls": c.cls, "cos": c.cos, "team": team, "sk": ""})
		c.sk_claim = str(d.get("sk", ""))
		peer.send(peer_id, {"t": "welcome", "id": c.pid})
		if in_game:   # dropping into a game already running
			var cls: String = sim.game.job if sim.game.job != "" else c.cls
			var p := sim.make_player(c.pid, cls, sim.players.size(), team if sim.pvp() == "base" else "")
			p.name = c.name
			p.cosS = c.cos
			p.perk = PalProfile.perk_from({}, sim.pvp() != "")
			sim.kit_up(p)
			var at := sim.respawn_at(p)
			p.x = at.x
			p.y = at.y
			if sim.pvp() != "":
				p.prot = Pal.PVP.prot
			if sim.pvp() == "base":
				p.sal = Pal.PVP.startSal
			if sim.pvp() == "ffa":
				p.mats = [0, 0, 0]
			var back := _restore_leaver(c, p)
			sim.players[c.pid] = p
			peer.send(peer_id, _start_msg())
			_wl_sent = PackedByteArray()
			_pi_sent.clear()
			_ps_last.clear()
			var where := "Armory and salvage restored." if back else ("Dropped in on %s." % Pal.TEAMS[team].name if sim.pvp() == "base" else ("Dropped into the fight." if sim.pvp() != "" else "Dropped in at the stake."))
			toast_all("%s %s" % [c.name.to_upper(), "IS BACK" if back else "JOINED"], where)
		broadcast_lobby()
		skills_check.emit(c.pid, c.uid, c.sk_claim)
		return
	if c.pid == "":
		return
	match t:
		"loadout":
			if in_game:
				return
			var r := _roster_of(c.pid)
			if r.is_empty() or not Pal.CLASSES.has(d.get("cls", "")) or not _text(d.get("cos"), LIMITS.cos) or not _text(d.get("name"), LIMITS.name):
				return
			if d.has("sk") and not _text(d.sk, LIMITS.skills):
				return
			c.cls = d.cls
			c.cos = str(d.cos)
			c.name = str(d.name).substr(0, 12) if str(d.name) != "" else r.name
			r.cls = c.cls
			r.cos = c.cos
			r.name = c.name
			if d.has("sk") and d.sk != c.get("sk_claim", ""):
				c.sk_claim = d.sk
				skills_check.emit(c.pid, c.uid, d.sk)
			broadcast_lobby()
		"ping":
			pass
		"c":
			if _text(d.get("m"), LIMITS.chat):
				host_chat(c.pid, d.m)
		"nextcls":
			var p = sim.players.get(c.pid)
			if p != null and in_game and sim.pvp() == "ffa" and sim.game.job == "" and Pal.CLASSES.has(d.get("cls", "")):
				p.nextCls = "" if d.cls == p.cls else d.cls
		"ready":
			if not in_game:
				var r := _roster_of(c.pid)
				if not r.is_empty():
					r.ready = bool(d.get("on", false))
					broadcast_lobby()
			else:
				var p = sim.players.get(c.pid)
				if p != null:
					sim.bo_ready(d.get("on", true) != false, p)
		"team":
			if not in_game:
				var r := _roster_of(c.pid)
				if not r.is_empty():
					r.team = "a" if r.get("team", "a") == "b" else "b"
					broadcast_lobby()
		_:
			_host_action(c, t, d)


signal skills_check(pid: String, uid: String, claimed: String)   # main asks the server for this player's real tree


## the host checked a guest's tree against their account: their perks count from now on
func set_guest_skills(pid: String, sk: String) -> void:
	for k in _conns:
		if _conns[k].get("pid", "") == pid:
			_conns[k].sk = sk
	var r := _roster_of(pid)
	if not r.is_empty():
		r.sk = sk
		if not in_game:
			broadcast_lobby()
	var p = sim.players.get(pid) if sim != null else null
	if p != null and in_game and p.sk != sk:
		p.sk = sk
		var hp: float = p.hp / maxf(1.0, p.max)
		p.perk = PalProfile.perk_from(PalProfile.parse_skills(sk), sim.pvp() != "")
		p.max = 0.0
		sim.refit(p)
		p.hp = maxf(1.0, roundf(p.max * hp))


func _host_action(c: Dictionary, t: String, d: Dictionary) -> void:
	var p = sim.players.get(c.pid)
	if p == null or not in_game or sim.game.phase == "over" and t != "i":
		return
	var N: int = sim.N
	var pad: float = LIMITS.targetPad
	match t:
		"i":
			# malformed coordinates or aim never reach collision, drawing or the sim
			if not _fin(d.get("x"), 0, N) or not _fin(d.get("y"), 0, N) or not _fin(d.get("ax"), -1.1, 1.1) or not _fin(d.get("ay"), -1.1, 1.1):
				return
			if not _int(d.get("tp"), 0, 1000000) or not _int(d.get("f"), 0, 1) or not _int(d.get("a"), 0, 1):
				return
			if d.has("n") and not _int(d.n, 0, 9007199254740991):
				return
			if d.has("st") and not _int(d.st, 0, 199):
				return
			if sim.casino() and int(d.get("st", 0)) != int(p.get("seat", 0)):
				# a casino seat nobody else has, next to where they stand (only codes in the seat registry)
				var want := int(d.get("st", 0))
				var q := CasinoView.seat_of(want)
				var other = CasinoView.taken(sim, want) if want else null
				p.seat = want if want and not q.is_empty() and Vector2(p.x - q.pos[0], p.y - q.pos[1]).length() < 1.2 and (other == null or is_same(other, p)) else 0
				if p.seat:
					p.x = q.pos[0]
					p.y = q.pos[1]
					c.moveBudget = 0.0
			var a := Vector2(d.ax, d.ay)
			if a.length() > 0.01:
				p.aim = a.normalized()
				p.face = p.aim
			p.fire_in = int(d.f) == 1 and p.alive
			p.auto = int(d.a) != 0
			if d.has("n") and int(d.n) != p.pullIn:
				if p.pullIn == -1:
					p.pullUsed = int(d.n)
				p.pullIn = int(d.n)
				p.pullT = sim.game.time
			if p.alive and int(d.tp) == int(p.tp):
				var now := _now()
				var dt := clampf((now - c.get("moveAt", now)) / 1000.0, 0.0, 0.5)
				c.moveAt = now
				# the class's best honest pace, terrain at either end, and a small margin for timing and jitter
				var speed: float = 3.3 * p.C.get("spd", 1.0) * (Pal.SPRINT.mult if p.C.get("sprint", false) else 1.0) * p.perk.speed * (1.2 if sim.has_mod("adrenaline") else 1.0) \
					* maxf(sim.slow_at(p.x, p.y), sim.slow_at(d.x, d.y)) * 1.15
				c.moveBudget = minf(LIMITS.moveBurst, c.get("moveBudget", 0.55) + speed * dt)
				var dd := Vector2(d.x - p.x, d.y - p.y).length()
				if dd <= c.moveBudget + 0.02 and dd < 3 and sim.travel_clear(p.x, p.y, d.x, d.y, sim.pt(p), 0.27):
					c.moveBudget = maxf(0.0, c.moveBudget - dd)
					p.walk += dd * 3
					p.x = float(d.x)
					p.y = float(d.y)
				else:
					p.tp += 1   # snap them back to where the host has them
		"b":
			if _int(d.get("i"), 0, N - 1) and _int(d.get("j"), 0, N - 1) and _int(d.get("s"), 0, 2) and d.get("d") is bool:
				sim.do_build(p, int(d.i), int(d.j), int(d.s), d.d)
		"n":
			if _fin(d.get("x"), -pad, N + pad) and _fin(d.get("y"), -pad, N + pad):
				sim.throw_nade(p, d.x, d.y)
		"u":
			if d.get("k") is String and (d.k in ["d", "r", "g", "a", "n", "core", "dell"]):
				sim.buy_upgrade(p, d.k)
		"am":
			if d.get("id") is String and _int(d.get("slot"), 0, 1):
				sim.buy_ammo(p, d.id, int(d.slot))
		"rl":
			if p.gun.has("mag"):
				p.rlReq = true
		"ab":
			if _fin(d.get("x"), -pad, N + pad) and _fin(d.get("y"), -pad, N + pad):
				sim.use_ability(p, d.x, d.y)


func _roster_of(pid: String) -> Dictionary:
	for r in roster:
		if r.id == pid:
			return r
	return {}


func _host_drop(peer_id: String) -> void:
	var c: Dictionary = _conns.get(peer_id, {})
	if c.is_empty():
		return
	_conns.erase(peer_id)
	if c.get("pid", "") == "":
		return
	roster = roster.filter(func(r): return r.id != c.pid)
	if in_game and sim.players.has(c.pid):
		_stash_leaver(c, sim.players[c.pid])
		sim.players.erase(c.pid)
		toast_all("%s LEFT" % c.name.to_upper(), "")
	broadcast_lobby()


## a player who drops and comes back to the same co-op game keeps their armory, salvage and kills (by session)
func _stash_leaver(c: Dictionary, p: Dictionary) -> void:
	if c.get("session", "") == "" or c.get("kicked", false) or sim.pvp() != "":
		return
	_left_by[c.session] = {"gid": sim.game.gid, "chapter": sim.game.chapter, "prepEpoch": sim.game.get("prepEpoch", 0), "cls": p.cls, "up": p.up.duplicate(),
		"ammoEq": p.ammoEq.duplicate(), "sal": p.sal, "kills": p.kills, "deaths": p.deaths, "out": p.get("out", false), "chEvac": p.get("chEvac", []).duplicate(),
		"x": p.x, "y": p.y, "hp": p.hp, "max": p.max, "alive": p.alive, "downed": p.downed, "rt": p.rt, "revive": p.revive, "mats": p.mats.duplicate(),
		"nades": p.nades, "ammo": p.ammo, "rl": p.rl, "rk": p.rk, "rkCd": p.rkCd, "stl": p.stl, "stlCd": p.stlCd}
	if _left_by.size() > 12:
		_left_by.erase(_left_by.keys()[0])


func _restore_leaver(c: Dictionary, p: Dictionary) -> bool:
	var s: Dictionary = _left_by.get(c.session, {})
	if s.is_empty() or s.gid != sim.game.gid or sim.pvp() != "":
		return false
	_left_by.erase(c.session)
	if s.cls == p.cls:
		for k in p.up:
			p.up[k] = clampi(int(s.up.get(k, 0)), 0, Sim.ARM_MAX)
		sim.refit(p)
		p.nades = p.maxN
	if sim.ammo_mode():
		var a: Array = s.ammoEq
		p.ammoEq = [a[0] if a.size() > 0 else "", a[1] if p.cls == "sniper" and a.size() > 1 and a[1] != a[0] else ""]
	if sim.campaign():
		var prepared: bool = sim.game.get("prepEpoch", 0) > s.prepEpoch
		for i in 3:
			p.mats[i] = mini(s.mats[i], p.cap[i])
		if not prepared:
			p.hp = minf(p.max, s.hp * (p.max / s.max))
			p.alive = s.alive
			p.downed = s.downed
			p.rt = s.rt
			p.revive = s.revive
			p.nades = mini(p.maxN, s.nades)
			p.rk = s.rk
			p.rkCd = s.rkCd
			p.stl = s.stl
			p.stlCd = s.stlCd
			if s.cls == p.cls and p.gun.has("mag"):
				p.ammo = mini(p.gun.mag, s.ammo)
				p.rl = s.rl
		if s.chapter == sim.game.chapter and not sim.collides(s.x, s.y, 0.27, sim.pt(p)):
			p.x = s.x
			p.y = s.y
			p.tp += 1
	p.sal = maxi(p.sal, s.sal)
	p.kills = s.kills
	p.deaths = s.deaths
	p.chEvac = s.chEvac.slice(0, 3)
	if s.out and sim.game.fb != null and not sim.game.fb.done and s.chapter == sim.game.chapter:
		p.out = true
		p.alive = false
		p.downed = false
		p.ev = Sim.BLITZ.hold
	return true


func kick(pid: String) -> void:
	if mode != "host" or pid == "host":
		return
	for k in _conns:
		var c: Dictionary = _conns[k]
		if c.get("pid", "") == pid and not c.get("kicked", false):
			c.kicked = true
			if c.get("session", "") != "":
				_banned[c.session] = true
			peer.send(k, {"t": "kick", "why": "The host removed you from the game."})
			get_tree().create_timer(0.25).timeout.connect(func():
				if peer != null:
					peer.close_peer(k)
				_host_drop(k))
			return


func set_locked(on: bool) -> void:
	locked = on
	broadcast_lobby()


# ---------------------------------------------------------------- the lobby

func lobby_sig() -> String:
	return "|".join([pick.diff, pick.mode, pick.pvp, pick.map, pick.size, ",".join(pick.mods), pick.job])


func broadcast_lobby() -> void:
	if mode == "host" and not in_game:
		var sig := lobby_sig()
		if _ready_sig != null and _ready_sig != sig:   # changing the game's settings clears everyone's ready
			for r in roster:
				r.ready = false
		_ready_sig = sig
	_send_all({"t": "lobby", "roster": roster, "code": code, "diff": pick.diff, "mode": pick.mode, "pvp": pick.pvp, "map": pick.map, "size": pick.size,
		"playing": in_game, "mods": pick.mods, "job": pick.job, "locked": locked})
	lobby_changed.emit()


func set_ready(on: bool) -> void:
	if mode == "guest":
		peer.send(_host_peer, {"t": "ready", "on": on})


func switch_team() -> void:
	if mode == "host":
		var r := _roster_of("host")
		if not r.is_empty():
			r.team = "a" if r.get("team", "a") == "b" else "b"
			broadcast_lobby()
	elif mode == "guest" or mode == "joining":
		peer.send(_host_peer, {"t": "team"})


## this screen's class, outfit or name changed in the lobby
func set_loadout(cls: String, cos: String, nm: String, sk: String) -> void:
	me.cls = cls
	me.cos = cos
	me.name = nm
	me.sk = sk
	if mode == "host":
		var r := _roster_of("host")
		if not r.is_empty():
			r.cls = cls
			r.cos = cos
			r.name = nm
			r.sk = sk
			broadcast_lobby()
	elif mode == "guest" and not in_game:
		peer.send(_host_peer, {"t": "loadout", "cls": cls, "cos": cos, "name": nm, "sk": sk})


func guests() -> Array:
	return roster.filter(func(r): return r.id != "host")


## why the host can't start yet ("" when they can)
func start_block() -> String:
	if pick.pvp != "coop":
		if roster.size() < 2:
			return "PvP needs at least two players. Share the code."
		if pick.pvp == "base" and (roster.all(func(r): return r.get("team", "a") != "b") or roster.all(func(r): return r.get("team", "a") == "b")):
			return "Both sides need at least one player. Someone tap SWITCH SIDES."
	var n := guests().filter(func(r): return not r.get("ready", false)).size()
	if n > 0:
		return "Everyone has to ready up first: %d player%s not ready yet." % [n, "s" if n > 1 else ""]
	return ""


## the host starts the match: main has already called sim.new_game with roster_now() and start_opt()
func host_started() -> void:
	for r in roster:
		r.ready = false   # next time back in the lobby, everyone readies again
	in_game = true
	_snap_n = 0
	_fxq.clear()
	_bullets_seen.clear()
	for k in _conns:
		_conns[k].heard = _now()   # the lobby wait is not silence
	_send_all(_start_msg())
	_wl_sent = PackedByteArray()
	_pi_sent.clear()
	_ps_last.clear()
	broadcast_lobby()


func host_back_to_lobby() -> void:
	in_game = false
	broadcast_lobby()


## the options for sim.new_game on the host
func start_opt(perks_pvp: String) -> Dictionary:
	return {"roster": roster.map(func(r): return r.duplicate()), "pvp": perks_pvp, "my_id": my_id, "mode": pick.mode, "map": pick.map, "size": pick.size,
		"mods": pick.mods, "job": pick.job}


func _roster_now() -> Array:
	if in_game and sim != null:
		return sim.players.values().map(func(p): return {"id": p.id, "name": p.name, "cls": p.cls, "cos": p.cosS, "team": p.team, "sk": p.sk})
	return roster


func _start_msg() -> Dictionary:
	var shots: Array = []
	for b in sim.bullets:
		if not b.dead:
			shots.append(_bullet_event(b))
	var g: Dictionary = sim.game
	var room = main_ref.cas_room() if g.mode == "casino" and main_ref != null else null
	return {"t": "start", "room": room, "roster": _roster_now(), "diff": g.diff, "mode": g.mode, "pvp": g.pvp, "map": g.map, "size": g.size, "oct": 0, "gid": g.gid,
		"mods": sim.mods, "job": g.job, "shots": shots}


# ---------------------------------------------------------------- chat

static func clean_chat(s: String) -> String:
	var out := ""
	for ch in s:
		var c := ch.unicode_at(0)
		if c < 32 or c == 127 or (c >= 0x200b and c <= 0x200f) or (c >= 0x202a and c <= 0x202e) or (c >= 0x2066 and c <= 0x2069):
			continue
		out += ch
	var parts := out.split(" ", false)
	return " ".join(parts).strip_edges().substr(0, 120)


func send_chat(text: String) -> void:
	if mode == "host":
		host_chat("host", text)
	elif mode == "guest":
		peer.send(_host_peer, {"t": "c", "m": text})


func host_chat(pid: String, raw: String) -> void:
	var text := clean_chat(raw)
	if text == "":
		return
	var now := _now()
	var r: Array = _chat_rate.get(pid, [])
	while not r.is_empty() and now - r[0] > 6000:
		r.pop_front()
	if r.size() >= 5:
		return
	r.append(now)
	_chat_rate[pid] = r
	var who := _roster_of(pid)
	var nm: String = who.get("name", "?")
	var team: String = sim.players.get(pid, who).get("team", "") if sim != null else who.get("team", "")
	_send_all({"t": "c", "id": pid, "n": nm, "m": text, "tm": team})
	_add_chat(pid, nm, text, team)


func _add_chat(id: String, nm: String, text: String, team: String) -> void:
	var col: String = Pal.SLOTCOL[0]
	if in_game and sim.pvp() != "" and Pal.TEAMS.has(team):
		col = Pal.TEAMS[team].col
	elif in_game and sim.players.has(id):
		col = Pal.SLOTCOL[int(sim.players[id].slot) % 6]
	else:
		for i in roster.size():
			if roster[i].id == id:
				col = Pal.SLOTCOL[i % 6]
	var line := {"id": id, "name": nm.substr(0, 12), "text": text, "col": col, "at": Time.get_ticks_msec()}
	chat.append(line)
	if chat.size() > 40:
		chat.pop_front()
	chat_line.emit(line)


# ---------------------------------------------------------------- host: the frame

## after sim.update on the host: turn this frame's events into wire events, send state 15 times a second
func host_frame(dt: float) -> void:
	if peer == null:
		return
	if not in_game:
		_lobby_net(dt)
		return
	_record(sim.events)
	var live := {}
	for b in sim.bullets:
		live[b.id] = true
		if not _bullets_seen.has(b.id) and not b.dead:
			_bullets_seen[b.id] = true
			_fxq.append(_bullet_event(b))
	var gone: Array = []
	for id in _bullets_seen.keys():
		if not live.has(id):
			gone.append(id)
			_bullets_seen.erase(id)
	if not gone.is_empty():
		var bx: Array = ["bx"]
		bx.append_array(gone)
		_fxq.append(bx)
	_snap_t -= dt
	if _snap_t <= 0:
		_snap_t = 1.0 / 15.0
		_snap_n += 1
		_send_state(make_snap(false))
		# walls: checked 5 times a second; only changed tiles go out (events arrive reliably and in order), with the
		# whole grid at the start, when someone drops in, and every 10 s as a safety net
		var wl = null
		var wd: Array = []
		if _snap_n % 3 == 1:
			var b := wall_bytes()
			var old := _wl_sent
			if old.is_empty() or _now() - _wl_at > 10000:
				wl = Marshalls.raw_to_base64(b)
				_wl_at = int(_now())
			else:
				for k in sim.N * sim.N:
					var o := k * 4
					if b[o] != old[o] or b[o + 1] != old[o + 1] or b[o + 2] != old[o + 2] or b[o + 3] != old[o + 3]:
						wd.append_array([k, b[o], b[o + 1], b[o + 2], b[o + 3]])
			_wl_sent = b
		var pi := _changed_info()
		if not _fxq.is_empty() or wl != null or not wd.is_empty() or not pi.is_empty():
			_send_events(_fxq, wl, wd, pi)
			_fxq = []
	var now := _now()
	for k in _conns.keys():
		if _conns[k].get("pid", "") != "" and now - _conns[k].heard > 12000:
			_host_drop(k)


func _lobby_net(dt: float) -> void:
	_lobby_t -= dt
	if _lobby_t > 0:
		return
	_lobby_t = 2.0
	var now := _now()
	if mode == "host":
		_send_all({"t": "ping"})
		for k in _conns.keys():
			if _conns[k].get("pid", "") != "" and now - _conns[k].heard > 25000:
				_host_drop(k)
	elif mode == "guest":
		peer.send(_host_peer, {"t": "ping"})
		if now - _heard > 25000:
			leave("Lost the host while waiting in the lobby.")


## events and wall changes on the reliable channel, split to stay under PeerJS's 16 KB JSON limit
func _send_events(fx: Array, wl, wd: Array, pi: Array) -> void:
	var out: Array = []
	var put: Callable
	put = func(list: Array, w, dd: Array, inf: Array) -> void:
		var m := {"t": "x", "n": _snap_n, "fx": list}
		if sim.campaign():
			m.cm = sim.game.chapter
		if w != null:
			m.wl = w
		if not dd.is_empty():
			m.wd = dd
		if not inf.is_empty():
			m.pi = inf
		if list.size() > 1 and JSON.stringify(m).length() > 12000:
			var h := list.size() >> 1
			put.call(list.slice(0, h), w, dd, inf)
			put.call(list.slice(h), null, [], [])
		else:
			out.append(m)
	put.call(fx, wl, wd, pi)
	for m in out:
		_send_all(m)


func _send_state(s: Dictionary) -> void:
	var near: bool = s.has("near")
	for k in _conns:
		var c: Dictionary = _conns[k]
		if c.get("pid", "") == "":
			continue
		var m := s
		if near:   # on the city each guest gets the raiders near them (bosses always)
			m = s.duplicate()
			var p = sim.players.get(c.pid)
			if p != null:
				m.en = s.en.filter(func(r): return str(ECODE[r[1]] if r[1] >= 0 and r[1] < ECODE.size() else "").begins_with("boss:") or Vector2(r[2] - p.x, r[3] - p.y).length() < BO_NEAR)
		peer.send(k, m, "st")   # falls back to 'r' while 'st' isn't open


func wall_bytes() -> PackedByteArray:
	var NN: int = sim.N * sim.N
	var b := PackedByteArray()
	b.resize(NN * 4)
	for k in NN:
		var w = sim.walls[k]
		var o := k * 4
		if w != null:
			var tm: String = w.get("tm", "")
			b[o] = 0x80 | (0x40 if w.door else 0) | (0x20 if tm == "b" else (0x10 if tm == "a" else 0)) | (0x08 if w.get("slab", false) else 0) | (w.mat & 3)
			b[o + 1] = clampi(roundi(w.hp / w.max * 255), 1, 255)
			b[o + 2] = (0x80 if w.fire > 0 else 0) | clampi(roundi(w.char * 127), 0, 127)
		b[o + 3] = sim.debris[k]
	return b


func _set_wall_tile(k: int, f: int, hp: int, fc: int, db: int) -> void:
	if k < 0 or k >= sim.walls.size():
		return
	sim.debris[k] = db
	if not (f & 0x80):
		sim.walls[k] = null
		return
	var mat := f & 3
	var door := (f & 0x40) != 0
	var ratio := hp / 255.0
	var w = sim.walls[k]
	if w == null or w.mat != mat or w.door != door:
		w = Pal.make_wall(mat, door, ratio)
		sim.walls[k] = w
	else:
		var nh: float = w.max * ratio
		if nh < w.hp - 0.5:
			w.flash = 0.08
		w.hp = nh
	w.fire = 1.0 if fc & 0x80 else 0.0
	w.char = (fc & 0x7f) / 127.0
	w.tm = "b" if f & 0x20 else ("a" if f & 0x10 else "")
	w.slab = (f & 0x08) != 0
	if mat == 3 and not w.has("cov"):
		w.cov = ""


func _decode_walls(s: String) -> void:
	var b := Marshalls.base64_to_raw(s)
	for k in mini(sim.N * sim.N, b.size() / 4):
		_set_wall_tile(k, b[k * 4], b[k * 4 + 1], b[k * 4 + 2], b[k * 4 + 3])
	sim.mark_flow()


func _apply_wall_diff(d: Array) -> void:
	var q := 0
	while q + 4 < d.size():
		_set_wall_tile(int(d[q]), int(d[q + 1]), int(d[q + 2]), int(d[q + 3]), int(d[q + 4]))
		q += 5
	sim.mark_flow()


# the row layouts: one list per kind of row, the same order as the browser's PL_STATE, PL_SLOW, PL_INFO and EN_STATE
func _pl_state(p: Dictionary) -> Array:
	return [p.id, r2(p.x), r2(p.y), r2(p.aim.x), r2(p.aim.y), ceili(p.hp), 1 if p.alive else 0, int(p.ammo) if p.gun.has("mag") else -1, int(p.tp),
		1 if p.downed else 0, r2(p.revive), r2(minf(p.rt, 1e6)), r2(maxf(0.0, p.bcd)), r2(p.bolt / p.boltT) if p.bolt > 0 and p.boltT > 0 else 0, 1 if p.rl > 0 else 0,
		r2(p.stun), r2(p.get("ev", 0.0))]


static func _ch_evac_bits(p: Dictionary) -> int:
	var v := 0
	var ce: Array = p.get("chEvac", [])
	for i in mini(3, ce.size()):
		if ce[i] != null:
			v |= (1 if ce[i] else 2) << (2 * i)
	return v


static func _ch_evac_from(v: int) -> Array:
	var o: Array = []
	for i in 3:
		var b := (v >> (2 * i)) & 3
		if b:
			while o.size() < i:
				o.append(null)
			o.append(1 if b == 1 else 0)
	return o


func _pl_slow(p: Dictionary) -> Array:
	return [p.id, p.mats[0], p.mats[1], p.mats[2], p.nades, int(p.sal), int(p.kills), int(p.deaths), 1 if p.prot > 0 else 0, _ab_state(p),
		1 if p.get("out", false) else 0, _ch_evac_bits(p), 1 if p.get("boReady", false) else 0, int(p.get("seat", 0))]


## p.ab on the wire: rockets left (soldier) or stealth time x10 while on, minus the seconds of recharge (sniper)
func _ab_state(p: Dictionary) -> int:
	if sim.pvp() != "" or not (p.cls == "soldier" or p.cls == "sniper"):
		return 0
	if p.cls == "soldier":
		return int(p.rk)
	return ceili(p.stl * 10) if p.stl > 0 else -ceili(p.stlCd)


func _pl_info(p: Dictionary) -> Array:
	return [p.id, p.name, p.cls, p.slot, p.max, p.maxN, sim.up_str(p), p.cosS, p.team, ",".join(p.ammoEq), p.sk]


func _en_state(e: Dictionary) -> Array:
	var code := ECODE.find("boss:" + e.boss if e.type == "boss" else e.type)
	var st: int = e.get("st", 0)
	var r := [e.id, code, r2(e.x), r2(e.y), r2(e.aim.x), r2(e.aim.y), r2(e.hp / e.max), 1 if e.get("planted", false) else 0, st,
		r2(maxf(0.0, e.stT / e.stM)) if st and e.has("stT") and e.get("stM", 0.0) > 0 else 0, r2(e.get("lx", 0.0)), r2(e.get("ly", 0.0)),
		r2(e.get("burnT", 0.0)), r2(e.get("slowT", 0.0)), r2(e.get("slowPct", 0.0)), e.get("shieldHitsLeft", 0), e.get("shieldHitsMax", 0), 1 if e.get("shieldBroken", false) else 0]
	while r.size() > 1 and (r[-1] is float or r[-1] is int) and r[-1] == 0:
		r.pop_back()
	return r


static func _trim(r: Array) -> Array:
	while r.size() > 1 and (r[-1] is float or r[-1] is int) and r[-1] == 0:
		r.pop_back()
	return r


func _changed_info() -> Array:
	var out: Array = []
	for p in sim.players.values():
		var r := _pl_info(p)
		var k := JSON.stringify(r)
		if _pi_sent.get(p.id, "") != k:
			_pi_sent[p.id] = k
			out.append(r)
	return out


## a player's slow row goes out when it changes and for the next 8 packets (the state channel drops rather than
## resends), every player's every 30 packets, and all of them after someone joins
func _slow_rows() -> Array:
	var out: Array = []
	for p in sim.players.values():
		var r := _pl_slow(p)
		var k := JSON.stringify(r)
		var o: Dictionary = _ps_last.get(p.id, {})
		if o.is_empty() or o.k != k:
			_ps_last[p.id] = {"k": k, "n": _snap_n}
			out.append(r)
		elif _snap_n - o.n < 8 or _snap_n % 30 == 0:
			out.append(r)
	return out


func make_snap(with_walls: bool) -> Dictionary:
	var g: Dictionary = sim.game
	var q: Dictionary = sim.qm
	var flat := func(a: Array, f: Callable) -> Array:
		var o: Array = []
		for x in a:
			o.append_array(f.call(x))
		return o
	var S: Dictionary = g.stats
	var s := {"t": "s", "n": _snap_n, "ph": g.phase, "w": g.wave, "bk": int(g.get("bosses", 0)), "tm": r2(g.timer), "q": g.queue.size(), "tt": r2(g.time),
		"won": 1 if g.won else 0, "wn": g.get("winner", ""), "sb": int(g.get("sbN", 0)), "wx": 1 if g.get("wx", 0) else 0, "sd": 1 if g.get("sd", false) else 0,
		"er": _end_reason(), "ed": 0, "qc": [q.get("mode", "follow"), q.get("completedRaids", 0), q.get("layoutSize", 4), q.get("status", "")],
		"cs": flat.call(sim.cores, func(c): return [r2(c.hp), c.max, 1 if c.flash > 0 else 0]), "st": [S.dropped, S.built, S.lost, S.repairs, S.revives],
		"pl": sim.players.values().map(func(p): return _trim(_pl_state(p))), "ps": _slow_rows(),
		"qm": [r2(q.x), r2(q.y), r2(q.aim.x), r2(q.aim.y), ceili(q.hp), q.max, 1 if q.alive else 0, r2(q.revive), int(g.get("dellLv", 0))],
		"en": sim.enemies.filter(func(e): return not e.get("dead", false)).map(func(e): return _en_state(e)),
		"rk": flat.call(sim.rockets, func(r): return [r2(r.x), r2(r.y), r2(r.vx), r2(r.vy)]),
		"fz": flat.call(sim.fires, func(f): return [r2(f.x), r2(f.y), r2(f.t), r2(f.get("r", 0.9)), int(f.get("nap", 0))]),
		"lo": flat.call(sim.lobs, func(l): return [r2(l.x0), r2(l.y0), r2(l.x1), r2(l.y1), r2(l.t), r2(l.T), r2(l.R), int(l.get("k", 0))]),
		"ch": flat.call(sim.charges, func(c): return [r2(c.x), r2(c.y), r2(c.fuse)]),
		"sa": flat.call(sim.sacks, func(k): return [r2(k.x), r2(k.y)]),
		"nd": flat.call(sim.nodes, func(n): return [int(n.get("amt", 0)), 1 if n.locked else 0]), "fo": 1 if sim.flood_on else 0}
	if not g.bossLog.is_empty():
		s.bl = g.bossLog
	if sim.campaign():
		s.cm = g.chapter
	if g.get("bo") != null:
		s.bo = _bo_snap()
	if sim.map_id == "city":
		s.near = 1
	if not sim.frost_fields.is_empty():
		s.ice = sim.frost_fields.map(func(f): return [r2(f.x), r2(f.y), r2(f.t), r2(sim.height_at(f.x, f.y))])
	if g.get("fb") != null:
		var F: Dictionary = g.fb
		var E = F.get("evac")
		s.fb = [r2(F.t), F.n, F.max, r2(E.x) if E != null else 0, r2(E.y) if E != null else 0, r2(E.r) if E != null else 0, 1 if F.done else 0,
			1 if F.get("mapEvac", false) else (2 if F.get("gauntlet", false) else 0), int(F.get("ch", 0)), int(F.get("wave", 0))]
	if not g.fbLog.is_empty():
		s.fl = g.fbLog
	if not g.get("gKill", []).is_empty():
		s.gk = g.gKill
	if not sim.arcs.is_empty():
		s.ar = flat.call(sim.arcs, func(r): return [r2(r.x), r2(r.y), r2(r.vx), r2(r.vy)])
	if not g.sbLog.is_empty():
		s.sl = g.sbLog
	if not sim.terr_log.is_empty():
		s.tr = sim.terr_log
	if with_walls:
		s.wl = Marshalls.raw_to_base64(wall_bytes())
		s.bu = sim.bullets.filter(func(b): return not b.dead).map(func(b): return _bullet_event(b))
	return s


func _end_reason() -> String:
	var r: String = sim.game.get("end_reason", "")
	return "" if r == "pvp" else r


func _bo_snap() -> Array:
	var B: Dictionary = sim.game.bo
	var lost := 0
	var nxt := 0
	for i in sim.cores.size():
		if sim.cores[i].get("lost", false):
			lost |= 1 << i
		if sim.cores[i].get("next", false):
			nxt |= 1 << i
	var F = B.get("push")
	return [BO_STAGES.find(B.stage), 0 if B.stage == "gather" else r2(B.t), B.cur.ci if B.get("cur") != null else -1, lost, nxt, 1 if sim.game.get("dark", false) else 0,
		int(B.get("held", 0)), int(B.get("lost", 0)), r2(F.t) if F != null else 0, F.n if F != null else 0, 1 if F != null and F.get("dest", false) else 0,
		1 if B.get("destroyer", false) else 0]


func _bullet_event(b: Dictionary) -> Array:
	var scale := sqrt(1.0 + pow(b.zSlope * 0.8, 2))
	return ["b", b.id, r2(b.x), r2(b.y), r2(b.vx), r2(b.vy), b.team, 1 if b.get("heavy", false) else 0, trail_index(str(b.get("tr", "std"))) if b.team == 0 else 0, r2(b.range / scale - b.dist), null, null,
		int(b.get("tc", 0)), r2(sim.bullet_z(b)), r2(b.zSlope)]


## the host's sim events, as the wire's one-off events (rec in 05-net-record.js)
func _record(evs: Array) -> void:
	for e in evs:
		match e.k:
			"sfx":
				_fxq.append(["s", e.name, null if e.x < 0 else r2(e.x), null if e.y < 0 else r2(e.y)])
			"emit":
				var l = _fxq[-1] if not _fxq.is_empty() else null
				if l is Array and l[0] == "e" and l[1] == r2(e.x) and l[2] == r2(e.y) and l[4] == e.kind and l[5] == e.mat:
					l[6] = l[6] + e.n
				else:
					_fxq.append(["e", r2(e.x), r2(e.y), 12, e.kind, e.mat, e.n])
			"flt":
				_fxq.append(["f", r2(e.x), r2(e.y), e.text, e.col])
			"toast":
				_fxq.append(["t", e.title, e.body])
			"shake":
				_fxq.append(["k", r2(e.x), r2(e.y), e.amt])
			"flash":
				_fxq.append(["h", r2(e.x), r2(e.y), e.r, 1 if e.get("muzzle", false) else 0, e.life, null])
			"ring":
				_fxq.append(["o", r2(e.x), r2(e.y), e.r0, e.r1, e.life, e.c1, e.get("c2", e.c1), e.get("w", 2.0)])
			"zap":
				var z: Array = ["z"]
				for pt in e.pts:
					z.append_array([r2(pt.x), r2(pt.y)])
				_fxq.append(z)
			"slash":
				_fxq.append(["w", r2(e.x), r2(e.y), r2(e.ax), r2(e.ay)])
			"chain":
				_fxq.append(["C", r2(e.x0), r2(e.y0), r2(e.x1), r2(e.y1)])
			"killfx":
				if e.fx != "none" and e.fx != "":
					_fxq.append(["s", "kx_" + e.fx, r2(e.x), r2(e.y)])
					_fxq.append(["e", r2(e.x), r2(e.y), 12, "finish:" + e.fx, 0, 1])
			"personal":
				if e.id != my_id:
					_fxq.append(["p", e.id, e.name])
			"toast_to":
				if e.id != my_id:
					_send_to(e.id, {"t": "t", "b": e.title, "s": e.body})
			"feed":
				_fxq.append(["q", e.text, e.col])


func toast_all(big: String, small: String) -> void:
	sim.toast(big, small)


# ---------------------------------------------------------------- guest

func _guest_data(d: Dictionary) -> void:
	_heard = _now()
	match d.t:
		"welcome":
			my_id = str(d.id)
			mode = "guest"
			status.emit("")
			lobby_changed.emit()
		"lobby":
			roster = d.get("roster", [])
			code = str(d.get("code", code))
			locked = bool(d.get("locked", false))
			pick.diff = str(d.get("diff", "normal"))
			if d.has("mode"):
				pick.mode = str(d.mode)
			pick.pvp = str(d.get("pvp", "coop")) if d.get("pvp") else "coop"
			pick.mods = d.get("mods", []) if d.get("mods") is Array else []
			pick.job = str(d.get("job", "")) if Pal.CLASSES.has(str(d.get("job", ""))) else ""
			if d.has("map"):
				pick.map = d.map if d.map in PalMaps.MAP_IDS else "yard"
			if d.has("size"):
				pick.size = "xl" if d.size == "xl" else "std"
			if in_game and not d.get("playing", false):
				in_game = false   # the host went back to the lobby
			lobby_changed.emit()
		"start":
			pick.diff = str(d.get("diff", "normal"))
			if d.has("mode"):
				pick.mode = str(d.mode)
			pick.pvp = str(d.get("pvp", "")) if d.get("pvp") else "coop"
			pick.map = d.map if d.get("map", "") in PalMaps.MAP_IDS else "yard"
			pick.size = "xl" if d.get("size", "") == "xl" else "std"
			cas_room = str(d.get("room", "")).substr(0, 80) if d.get("room") is String else ""
			var pv: String = pick.pvp if pick.pvp in ["base", "ffa"] else ""
			sim.new_game(-1, pick.diff, {}, {"roster": d.get("roster", []), "pvp": pv, "my_id": my_id, "guest": true, "gid": d.get("gid", ""),
				"mods": d.get("mods", []), "job": d.get("job", ""), "mode": pick.mode, "map": pick.map, "size": pick.size})
			sim.game.joinHeld = null
			_last_n = 0
			sim.bullets.clear()
			_replay(d.get("shots", []))
			in_game = true
			started.emit()
		"ping":
			pass
		"s":
			if in_game and d.get("n", 0) > _last_n:
				_last_n = int(d.n)
				_apply_snap(d)
		"x":
			if in_game:
				if sim.campaign() and d.has("cm"):
					if d.cm < sim.game.chapter:
						return
					if d.cm != sim.game.chapter:
						sim.change_chapter(int(d.cm))
						sim.ev({"k": "map"})
				if d.has("pi"):
					_apply_info(d.pi)
				if d.has("wl"):
					_decode_walls(d.wl)
				if d.has("wd"):
					_apply_wall_diff(d.wd)
				_replay(d.get("fx", []))
		"t":
			sim.toast(str(d.get("b", "")), str(d.get("s", "")))
		"kick":
			leave(str(d.get("why", "")))
		"c":
			_add_chat(str(d.get("id", "")), str(d.get("n", "?")), clean_chat(str(d.get("m", ""))), str(d.get("tm", "")))


func _apply_info(rows: Array) -> void:
	for r in rows:
		if not (r is Array) or r.size() < 11:
			continue
		var id := str(r[0])
		var p = sim.players.get(id)
		if p == null:
			p = sim.make_player(id, str(r[2]), int(r[3]), str(r[8]))
			p.name = str(r[1])
			p.perk = PalProfile.perk_from({}, sim.pvp() != "")
			sim.kit_up(p)
			sim.players[id] = p
		elif str(r[2]) != "" and str(r[2]) != p.cls:
			sim.change_class(p, str(r[2]))
		if str(r[10]) != p.sk:
			p.sk = str(r[10])
			p.perk = PalProfile.perk_from(PalProfile.parse_skills(p.sk), sim.pvp() != "")
			sim.refit(p)
		var ups := str(r[6])
		if ups != sim.up_str(p):
			var i := 0
			for U in Sim.UPG:
				p.up[U.k] = clampi(int(ups[i]) if i < ups.length() else 0, 0, Sim.ARM_MAX)
				i += 1
			sim.refit(p)
		var a := str(r[9]).split(",")
		p.ammoEq = [a[0] if a.size() > 0 else "", a[1] if p.cls == "sniper" and a.size() > 1 and a[1] != a[0] else ""]
		if str(r[7]) != "":
			p.cosS = str(r[7])
		p.name = str(r[1])
		p.slot = int(r[3])
		p.max = float(r[4])
		p.maxN = int(r[5])
		if str(r[8]) != "":
			p.team = str(r[8])
	sim.player = sim.players.get(my_id, sim.player)


func _apply_snap(s: Dictionary) -> void:
	var g: Dictionary = sim.game
	if sim.campaign() and s.has("cm"):
		if s.cm < g.chapter:
			return
		if s.cm != g.chapter:
			sim.change_chapter(int(s.cm))
			sim.ev({"k": "map"})
	var was_over: bool = g.phase == "over"
	g.phase = s.ph
	g.wave = int(s.w)
	g.timer = float(s.tm)
	g.bosses = int(s.get("bk", 0))
	g.qn = int(s.get("q", 0))
	g.won = bool(s.get("won", 0))
	g.winner = str(s.get("wn", ""))
	g.sbN = int(s.get("sb", 0))
	g.wx = int(s.get("wx", 0))
	g.sd = bool(s.get("sd", 0))
	g.end_reason = str(s.get("er", ""))
	if s.has("qc"):
		sim.qm.mode = s.qc[0]
		sim.qm.completedRaids = int(s.qc[1])
		sim.qm.layoutSize = int(s.qc[2])
		sim.qm.status = str(s.qc[3])
	if g.get("joinHeld") == null:   # where this screen came in
		g.joinHeld = int(s.w) if s.ph == "build" or (s.ph == "over" and s.get("won", 0)) else maxi(0, int(s.w) - 1)
		g.joinT = float(s.tt)
		g.joinBoss = s.get("bl", []).size()
		g.joinSB = int(s.get("sb", 0))
		g.joinFB = s.get("fl", []).size()
	if absf(g.time - float(s.tt)) > 1:
		g.time = float(s.tt)
	var cs: Array = s.get("cs", [])
	for i in sim.cores.size():
		if i * 3 + 1 >= cs.size():
			break
		var c: Dictionary = sim.cores[i]
		if cs[i * 3] < c.hp - 0.01:
			c.flash = 0.12
		c.hp = float(cs[i * 3])
		c.max = float(cs[i * 3 + 1])
	var st: Array = s.get("st", [0, 0, 0, 0, 0])
	g.stats = {"dropped": int(st[0]), "built": int(st[1]), "lost": int(st[2]), "repairs": int(st[3]), "revives": int(st[4])}
	var seen := {}
	for r in s.get("pl", []):
		var v := func(i: int) -> float: return float(r[i]) if i < r.size() and r[i] != null else 0.0
		var id := str(r[0])
		var p = sim.players.get(id)
		seen[id] = true
		if p == null:
			continue   # their details arrive on the reliable channel; they appear a moment later
		if not p.has("fresh"):
			p.fresh = 0
			p.x = v.call(1)
			p.y = v.call(2)
		if id == my_id:
			if int(v.call(8)) != int(p.tp):   # the host moved us (a respawn, a refused step): go where it says
				p.x = v.call(1)
				p.y = v.call(2)
				p.tp = int(v.call(8))
		else:
			p.tx = v.call(1)
			p.ty = v.call(2)
			p.aim = Vector2(v.call(3), v.call(4))
			p.face = p.aim
			p.tp = int(v.call(8))
		if v.call(5) < p.hp - 0.01:
			p.flash = 0.1
		p.hp = v.call(5)
		p.alive = v.call(6) != 0
		p.downed = v.call(9) != 0
		p.revive = v.call(10)
		p.rt = v.call(11)
		p.bcd = v.call(12)
		if v.call(13) > p.get("boltF", 0.0) + 0.05:
			p.boltF = v.call(13)
		p.ammo = int(v.call(7))
		p.rl = v.call(14)
		p.stun = v.call(15)
		p.ev = v.call(16)
	for id in sim.players.keys():
		if not seen.has(id):
			sim.players.erase(id)
	sim.player = sim.players.get(my_id, sim.player)
	for r in s.get("ps", []):
		var p = sim.players.get(str(r[0]))
		if p == null:
			continue
		var w := func(i: int) -> int: return int(r[i]) if i < r.size() and r[i] != null else 0
		p.mats = [w.call(1), w.call(2), w.call(3)]
		p.nades = w.call(4)
		p.sal = w.call(5)
		p.kills = w.call(6)
		p.deaths = w.call(7)
		p.prot = 1.0 if w.call(8) else 0.0
		p.ab = w.call(9)
		if p.cls == "soldier" and sim.pvp() == "":
			p.rk = maxi(0, p.ab)
		elif p.cls == "sniper" and sim.pvp() == "":
			p.stl = p.ab / 10.0 if p.ab > 0 else 0.0
			p.stlCd = -p.ab if p.ab < 0 else 0.0
		p.out = w.call(10) != 0
		p.chEvac = _ch_evac_from(w.call(11))
		p.boReady = w.call(12) != 0
		if not is_same(p, sim.player):
			p.seat = w.call(13)
	var q: Array = s.qm
	var Q: Dictionary = sim.qm
	if q[4] < Q.hp - 0.01:
		Q.flash = 0.1
	Q.tx = float(q[0])
	Q.ty = float(q[1])
	Q.aim = Vector2(q[2], q[3])
	Q.hp = float(q[4])
	Q.max = float(q[5])
	Q.alive = q[6] != 0
	Q.revive = float(q[7])
	g.dellLv = int(q[8])
	var old := {}
	for e in sim.enemies:
		old[e.id] = e
	var en: Array = []
	for r in s.get("en", []):
		var v := func(i: int) -> float: return float(r[i]) if i < r.size() and r[i] != null else 0.0
		var id := int(r[0])
		var e = old.get(id)
		if e == null:
			e = {"id": id, "x": v.call(2), "y": v.call(3), "walk": randf() * 6, "flash": 0.0, "max": 1.0, "hp": 1.0, "dead": false, "cd": 0.0}
		if v.call(6) < e.hp - 0.001:
			e.flash = 0.08
		var ci := int(v.call(1))
		var c: String = ECODE[ci] if ci >= 0 and ci < ECODE.size() else "rifle"
		var bk := c.substr(5) if c.begins_with("boss:") else ""
		e.type = "boss" if bk != "" else c
		if bk != "":
			e.boss = bk
		e.big = bk != ""
		var ti := clampi(floori(v.call(2)), 0, sim.N - 1)
		var tj := clampi(floori(v.call(3)), 0, sim.N - 1)
		e.raft = bk in ["ferryman", "whiteferryman", "harbinger"] and sim.terr[sim.idx(ti, tj)] == PalMaps.T_WATER
		e.burrow = (bk == "foreman" or bk == "whiteforeman") and (int(v.call(8)) == 2 or int(v.call(8)) == 4)
		e.tx = v.call(2)
		e.ty = v.call(3)
		e.aim = Vector2(v.call(4), v.call(5))
		e.hp = v.call(6)
		e.max = 1.0
		e.planted = v.call(7) != 0
		e.st = int(v.call(8))
		e.stT = v.call(9)
		e.stM = 1.0
		e.lx = v.call(10)
		e.ly = v.call(11)
		e.burnT = v.call(12)
		e.slowT = v.call(13)
		e.slowPct = v.call(14)
		e.shieldHitsLeft = int(v.call(15))
		e.shieldHitsMax = int(v.call(16))
		e.shieldBroken = v.call(17) != 0
		en.append(e)
	sim.enemies = en
	sim.frost_fields = s.get("ice", []).map(func(f): return {"x": f[0], "y": f[1], "t": f[2], "r": 0.72, "k": sim.idx(floori(f[0]), floori(f[1]))})
	var unflat := func(a: Array, n: int, f: Callable) -> Array:
		var o: Array = []
		var i := 0
		while i + n <= a.size():
			o.append(f.call(a.slice(i, i + n)))
			i += n
		return o
	sim.rockets = unflat.call(s.get("rk", []), 4, func(a): return {"x": a[0], "y": a[1], "vx": a[2], "vy": a[3], "d": 0.0, "max": 99.0})
	sim.fires = unflat.call(s.get("fz", []), 5, func(a): return {"x": a[0], "y": a[1], "t": a[2], "r": a[3], "nap": int(a[4]), "max": 4.0, "tick": 1.0})
	sim.arcs = unflat.call(s.get("ar", []), 4, func(a): return {"x": a[0], "y": a[1], "vx": a[2], "vy": a[3], "d": 0.0, "max": 99.0, "hit": [], "wk": {}})
	if s.get("fb") is Array:
		var f: Array = s.fb
		g.fb = {"t": f[0], "n": f[1], "max": f[2], "evac": {"x": f[3], "y": f[4], "r": f[5]} if f[5] else null, "done": f[6] != 0, "mapEvac": f[7] == 1, "gauntlet": f[7] == 2,
			"ch": int(f[8]), "wave": int(f[9]), "every": 1e9, "shellT": 1.0, "trickT": 0.0}
	else:
		g.fb = null
	if s.get("fl") is Array:
		g.fbLog = s.fl.slice(0, 20)
	if s.has("bo"):
		_bo_apply(s.bo)
		if g.get("joinPois") == null:
			g.joinPois = int(s.bo[6])
			g.joinHeld = int(s.bo[6]) + int(s.bo[7])
	if s.get("gk") is Array:
		g.gKill = s.gk.slice(0, 6)
	if s.has("bu"):
		sim.bullets.clear()
		for b in s.bu:
			_add_bullet(b)
	sim.lobs = unflat.call(s.get("lo", []), 8, func(a): return {"x0": a[0], "y0": a[1], "x1": a[2], "y1": a[3], "t": a[4], "T": a[5], "R": a[6], "k": int(a[7]), "power": 1.0, "own": null})
	sim.charges = unflat.call(s.get("ch", []), 3, func(a): return {"x": a[0], "y": a[1], "fuse": a[2], "beep": 0.0})
	sim.sacks = unflat.call(s.get("sa", []), 2, func(a): return {"x": a[0], "y": a[1], "mats": [0, 0, 0]})
	var nd: Array = s.get("nd", [])
	for i in sim.nodes.size():
		if i * 2 + 1 >= nd.size():
			break
		sim.nodes[i].amt = int(nd[i * 2])
		sim.nodes[i].locked = nd[i * 2 + 1] != 0
	if s.has("wl"):
		_decode_walls(s.wl)
	var tr: Array = s.get("tr", [])
	if tr.size() != sim.terr_log.size():
		var i := 0
		while i + 1 < tr.size():
			var k := int(tr[i])
			if k >= 0 and k < sim.N * sim.N:
				sim.terr[k] = int(tr[i + 1])
			i += 2
		sim.terr_log = tr.duplicate()
		sim.mark_flow()
	sim.flood_on = s.get("fo", 0) != 0
	if s.get("bl") is Array:
		g.bossLog = s.bl.slice(0, 40)
	if s.get("sl") is Array:
		g.sbLog = s.sl.slice(0, 100)
	if sim.pvp() != "":
		g.won = sim.player.team == g.winner if sim.pvp() == "base" else my_id == g.winner
	if g.get("mode", "") == "blitz" and g.phase == "over":
		g.won = sim.player.get("out", false)   # each soldier's own evacuation decides their result
	if g.phase == "over" and not was_over:
		sim.ev({"k": "over", "win": g.won})


func _bo_apply(a: Array) -> void:
	var g: Dictionary = sim.game
	if g.get("bo") == null:
		g.bo = {"order": [], "n": 0, "q": [], "log": [], "refT": 30.0}
	var B: Dictionary = g.bo
	B.stage = BO_STAGES[a[0]] if a[0] >= 0 and a[0] < BO_STAGES.size() else "gap"
	B.t = float(a[1])
	B.cur = {"ci": int(a[2])} if a[2] >= 0 else null
	B.held = int(a[6])
	B.lost = int(a[7])
	B.destroyer = a[11] != 0
	B.push = {"t": a[8], "n": a[9], "dest": a[10] != 0} if a[0] == 3 or a[0] == 4 else null
	g.dark = a[5] != 0
	for i in sim.cores.size():
		var c: Dictionary = sim.cores[i]
		if not c.has("poi"):
			continue
		var L := (int(a[3]) & (1 << i)) != 0
		if L and not c.lost:
			c.lostAt = g.time
		c.lost = L
		c.next = (int(a[4]) & (1 << i)) != 0
		c.attack = int(a[2]) == i


func _add_bullet(e: Array) -> void:
	for b in sim.bullets:
		if b.id == e[1]:
			return   # the start snapshot and a queued reliable shot can overlap
	if sim.bullets.size() >= 300:
		return
	var z0: float = e[13] if e.size() > 13 and e[13] != null else sim.height_at(e[2], e[3]) + 0.7
	sim.bullets.append({"id": e[1], "x": e[2], "y": e[3], "vx": e[4], "vy": e[5], "team": int(e[6]), "heavy": e[7] != 0, "tr": trail_id(int(e[8])), "tc": maxi(0, int(e[12]) if e.size() > 12 and e[12] != null else 0),
		"left": float(e[9]), "dist": 0.0, "z0": z0, "zSlope": float(e[14]) if e.size() > 14 and e[14] != null else 0.0, "dead": false, "range": 99.0, "own": e[11] if e.size() > 11 else null})


## the host's one-off events, replayed as this screen's own (replayFx)
func _replay(list: Array) -> void:
	for e in list:
		if not (e is Array) or e.is_empty():
			continue
		match e[0]:
			"e":
				var kind := str(e[4])
				if kind.begins_with("finish:"):
					sim.ev({"k": "killfx", "x": e[1], "y": e[2], "fx": kind.substr(7)})
				else:
					sim.ev({"k": "emit", "x": e[1], "y": e[2], "kind": kind, "n": int(e[6]) if e.size() > 6 and e[6] != null else 1, "mat": int(e[5]) if e[5] != null else 0})
			"E":
				sim.ev({"k": "emit", "x": e[1], "y": e[2], "kind": str(e[6]), "n": int(e[8]), "mat": int(e[7])})
			"b":
				_add_bullet(e)
			"bx":
				var gone := {}
				for i in range(1, e.size()):
					gone[int(e[i])] = true
				sim.bullets = sim.bullets.filter(func(b): return not gone.has(int(b.id)))
			"s":
				var nm := str(e[1])
				if not nm.begins_with("kx_"):   # the kill effect plays its own sound with its painting
					sim.ev({"k": "sfx", "name": nm, "x": -1.0 if e[2] == null else e[2], "y": -1.0 if e[3] == null else e[3]})
			"f":
				sim.ev({"k": "flt", "x": e[1], "y": e[2], "text": str(e[3]), "col": str(e[4]) if e[4] != null else "#e8dcc0"})
			"k":
				sim.ev({"k": "shake", "x": e[1], "y": e[2], "amt": float(e[3])})
			"h":
				sim.ev({"k": "flash", "x": e[1], "y": e[2], "r": float(e[3]), "muzzle": e[4] != 0, "life": float(e[5])})
			"t":
				sim.toast(str(e[1]), str(e[2]))
			"p":
				if str(e[1]) == my_id:
					sim.ev({"k": "personal", "id": my_id, "name": str(e[2])})
			"q":
				sim.ev({"k": "feed", "text": str(e[1]), "col": str(e[2])})
			"z":
				var pts: Array = []
				var i := 1
				while i + 1 < e.size():
					pts.append(Vector2(e[i], e[i + 1]))
					i += 2
				sim.ev({"k": "zap", "pts": pts})
			"w":
				sim.ev({"k": "slash", "x": e[1], "y": e[2], "ax": e[3], "ay": e[4]})
			"C":
				sim.chains.append({"x0": e[1], "y0": e[2], "x1": e[3], "y1": e[4], "life": 0.45, "max": 0.45})
			"o":
				sim.ev({"k": "ring", "x": e[1], "y": e[2], "r0": float(e[3]), "r1": float(e[4]), "life": float(e[5]), "c1": str(e[6]), "c2": str(e[7]), "w": float(e[8]) if e.size() > 8 else 2.0})


## instead of sim.update on a guest: this soldier moves here, everything else eases toward the host's state
func guest_frame(dt: float, ctl: Dictionary) -> void:
	if peer == null:
		return
	if not in_game:
		_lobby_net(dt)
		return
	dt = minf(dt, 0.1)
	var g: Dictionary = sim.game
	g.time += dt
	for c in sim.cores:
		c.flash = maxf(0.0, c.flash - dt)
	var p: Dictionary = sim.player
	if g.phase != "over":
		sim.control_local(dt, ctl)
	var k := 1.0 - exp(-dt * 14)
	var smooth := func(e: Dictionary) -> void:
		if not e.has("tx"):
			return
		var dx: float = e.tx - e.x
		var dy: float = e.ty - e.y
		var d := Vector2(dx, dy).length()
		if d > 3:
			e.x = e.tx
			e.y = e.ty
		else:
			e.x += dx * k
			e.y += dy * k
			e.walk = e.get("walk", 0.0) + d * k * 3
	for o in sim.players.values():
		if not is_same(o, p):
			smooth.call(o)
		o.flash = maxf(0.0, o.get("flash", 0.0) - dt)
		if o.get("boltF", 0.0) > 0:
			o.boltF = maxf(0.0, o.boltF - dt * 1.9)
		o.stun = maxf(0.0, o.stun - dt)
	smooth.call(sim.qm)
	sim.qm.flash = maxf(0.0, sim.qm.flash - dt)
	for e in sim.enemies:
		smooth.call(e)
		e.flash = maxf(0.0, e.flash - dt)
		e.burnT = maxf(0.0, e.get("burnT", 0.0) - dt)
		e.slowT = maxf(0.0, e.get("slowT", 0.0) - dt)
		if e.get("st", 0) and e.get("stT", 0.0) > 0:
			e.stT = maxf(0.0, e.stT - dt / 1.1)
	for b in sim.bullets:
		var sp := Vector2(b.vx, b.vy).length()
		b.x += b.vx * dt
		b.y += b.vy * dt
		b.dist += sp * dt
		b.left -= sp * dt
		if b.left <= 0 or not sim.inb(floori(b.x), floori(b.y)):
			b.dead = true
	sim.bullets = sim.bullets.filter(func(b): return not b.dead)
	for l in sim.lobs:
		l.t = minf(l.T, l.t + dt)
	for r in sim.arcs:
		r.x += r.vx * dt
		r.y += r.vy * dt
	if g.get("fb") != null and not g.fb.done and g.phase == "raid":
		g.fb.t = maxf(0.0, g.fb.t - dt)
	for r in sim.rockets:
		r.x += r.vx * dt
		r.y += r.vy * dt
	for f in sim.fires:
		f.t -= dt
	for c in sim.charges:
		c.fuse -= dt
	for w in sim.walls:
		if w != null:
			w.flash = maxf(0.0, w.flash - dt)
	for ch in sim.chains:
		ch.life -= dt
	sim.chains = sim.chains.filter(func(ch): return ch.life > 0)
	_in_t -= dt
	if p.alive:
		if _in_t <= 0:
			_in_t = 1.0 / 30.0
			peer.send(_host_peer, {"t": "i", "x": r2(p.x), "y": r2(p.y), "ax": r2(p.aim.x), "ay": r2(p.aim.y), "f": 1 if p.fire_in else 0, "tp": int(p.tp),
				"n": maxi(0, p.pullIn), "a": 1 if p.auto else 0, "st": int(p.get("seat", 0))}, "u")
	elif _in_t <= 0:
		_in_t = 1.0
		peer.send(_host_peer, {"t": "ping"}, "u")
	if _now() - _heard > 12000:
		leave("Lost the host. Their game may have closed or dropped signal.")


# a guest's actions go to the host, which runs them through the same rules
func send_build(i: int, j: int, sel: int, door: bool) -> void:
	peer.send(_host_peer, {"t": "b", "i": i, "j": j, "s": sel, "d": door})


func send_nade(x: float, y: float) -> void:
	peer.send(_host_peer, {"t": "n", "x": r2(x), "y": r2(y)})


func send_upgrade(k: String) -> void:
	peer.send(_host_peer, {"t": "u", "k": k})


func send_ammo(id: String, slot: int) -> void:
	peer.send(_host_peer, {"t": "am", "id": id, "slot": slot})


func send_reload() -> void:
	peer.send(_host_peer, {"t": "rl"})


func send_ability(x: float, y: float) -> void:
	peer.send(_host_peer, {"t": "ab", "x": r2(x), "y": r2(y)})


func send_next_class(cls: String) -> void:
	peer.send(_host_peer, {"t": "nextcls", "cls": cls})


func send_bo_ready(on: bool) -> void:
	sim.player.boReady = on
	peer.send(_host_peer, {"t": "ready", "on": on})
