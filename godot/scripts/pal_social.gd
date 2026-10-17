class_name PalSocial
extends Node
## Friends, invitations and the open games list (19-accounts.js, 19b-social-lobby.js, 19d-friend-invites.js), on the
## browser's own Supabase calls, so friends made in either game are the same friends.
##
## - Friends: a request system on the server (friend_send, friend_answer, friend_cancel, friend_remove), everything at
##   once from social_state (friends, requests both ways, the mailbox, invitations), polled every 15 s while the menus
##   are up and once a minute in a match.
## - Recent players: up to 50 account ids kept in the account's own metadata (palisade_saved_players_v1).
## - Invitations: the host registers the room (room_register) and sends lobby_invite_send; the friend answers with
##   lobby_invite_answer and joins by code with the room's incarnation, so an invite can't land in a later room.
## - Open games: a host who lists the room publishes it to the lobbies table every 15 s; the online page reads it.
## Only a saved (non-guest) account has friends, as in the browser.

const SAVED_KEY := "palisade_saved_players_v1"
const MODE_NAME := {"coop": "CO-OP", "base": "BASE BATTLE", "ffa": "FREE-FOR-ALL"}
const LEN_NAME := {"5": "5 RAIDS", "10": "10 RAIDS", "endless": "ENDLESS", "blitz": "BLITZKRIEG RUSH", "campaign": "OPERATION WHITEOUT", "blackout": "CITY BLACK OUT", "casino": "THE CASINO"}

signal changed

var m   # main
var friends: Array = []
var incoming: Array = []
var outgoing: Array = []
var notes: Array = []
var invites: Array = []
var unseen := 0
var ok := false
var loaded := false
var busy := false
var msg := ""
var rooms: Array = []   # friends' and saved players' listed rooms: {host_id, code, players, in_game}
var saved: Array = []   # saved player ids
var profiles: Array = []   # their profiles
var result = null   # a username search's hit
var open_games: Array = []   # the open games list
var list_game := true   # publish this room while hosting
var _poll_t := 0.0
var _pub_t := 0.0
var _owner := ""


func _init(main) -> void:
	m = main


func active() -> bool:
	var a: PalAccount = m.account
	return a != null and a.state == "full" and not a.is_guest() and _me() != ""


func _me() -> String:
	var u = m.account.uid() if m.account != null else null
	return u if u is String else ""


func _process(dt: float) -> void:
	if not active():
		if _owner != "":
			_reset()
		return
	if _owner != _me():
		_reset()
		_owner = _me()
		_poll_t = 0.0
	_poll_t -= dt
	if _poll_t <= 0:
		_poll_t = 15.0 if m.demo else 60.0   # slower in a match
		poll()
	if m.net.mode == "host":
		_pub_t -= dt
		if _pub_t <= 0:
			_pub_t = 15.0
			publish()


func _reset() -> void:
	friends = []
	incoming = []
	outgoing = []
	notes = []
	invites = []
	rooms = []
	saved = []
	profiles = []
	result = null
	unseen = 0
	ok = false
	loaded = false
	_owner = ""
	changed.emit()


## social_state: friends, requests, the mailbox and invitations in one call; the friends' rooms in a second
func poll() -> void:
	if not active():
		loaded = true
		ok = false
		changed.emit()
		return
	var owner: String = _me()
	var r: Dictionary = await m.account.rpc_call("social_state")
	if owner != _me():
		return
	loaded = true
	if r.ok and r.get("j") is Dictionary:
		ok = true
		var j: Dictionary = r.j
		friends = j.get("friends", []) if j.get("friends") is Array else []
		incoming = j.get("incoming", []) if j.get("incoming") is Array else []
		outgoing = j.get("outgoing", []) if j.get("outgoing") is Array else []
		notes = j.get("notes", []) if j.get("notes") is Array else []
		invites = j.get("invites", []) if j.get("invites") is Array else []
		unseen = int(j.get("unseen", 0))
		await _load_rooms(friends.map(func(f): return str(f.id)) + saved)
	else:
		ok = false
	changed.emit()


func _load_rooms(ids: Array) -> void:
	var good: Array = ids.filter(func(i): return _valid_id(i))
	if good.is_empty():
		rooms = []
		return
	var q: Dictionary = await m.account.sb_fetch("/rest/v1/lobbies?select=host_id,code,players,in_game&host_id=in.(%s)&proto=eq.%s&limit=60" % [",".join(good), PalNet.PROTO])
	rooms = q.j if q.ok and q.get("j") is Array else []


static func _valid_id(v) -> bool:
	if not (v is String) or v.length() != 36:
		return false
	var parts: PackedStringArray = v.split("-")
	return parts.size() == 5 and [8, 4, 4, 4, 12] == Array(parts).map(func(p): return p.length()) and v.replace("-", "").is_valid_hex_number()


func room_of(id: String) -> Dictionary:
	for r in rooms:
		if r.get("host_id") == id:
			return r
	return {}


func room_text(id: String) -> String:
	var r := room_of(id)
	if r.is_empty():
		return "NO LISTED ROOM"
	return "%s · %d/6" % ["IN MATCH" if r.get("in_game", false) else "IN LOBBY", int(r.get("players", 0))]


func _do(fn: String, args: Dictionary, ok_msg: Callable) -> void:
	if not active() or busy:
		return
	busy = true
	msg = ""
	changed.emit()
	var r: Dictionary = await m.account.rpc_call(fn, args)
	msg = ok_msg.call(r.get("j", {}) if r.get("j") is Dictionary else {}) if r.ok else m.account.err_text(r)
	busy = false
	await poll()


func send_request(p: Dictionary) -> void:
	await _do("friend_send", {"p_to": p.id}, func(j): return ("You and %s are friends now." % p.username) if j.get("state") == "friends" else "Request sent to %s." % p.username)


func answer(r: Dictionary, yes: bool) -> void:
	await _do("friend_answer", {"p_id": r.id, "p_accept": yes}, func(_j): return ("You and %s are friends now." % r.user.username) if yes else "Request declined.")


func cancel(r: Dictionary) -> void:
	await _do("friend_cancel", {"p_id": r.id}, func(_j): return "Request cancelled.")


func remove_friend(f: Dictionary) -> void:
	await _do("friend_remove", {"p_other": f.id}, func(_j): return "%s removed from friends." % f.username)


func mark_seen() -> void:
	if unseen == 0:
		return
	unseen = 0
	changed.emit()
	await m.account.rpc_call("notes_seen", {})


## an exact username (3-16 letters, numbers or _)
func find(name: String) -> void:
	name = name.strip_edges()
	var rx := RegEx.create_from_string("^[A-Za-z0-9_]{3,16}$")
	if rx.search(name) == null:
		msg = "Enter an exact username (3–16 letters, numbers or _)."
		changed.emit()
		return
	msg = "Looking for %s…" % name
	result = null
	changed.emit()
	if not await m.account.fresh_token():
		msg = "Sign-in could not be refreshed. Try again."
		changed.emit()
		return
	var r: Dictionary = await m.account.sb_fetch("/rest/v1/profiles?select=id,username,cos&username=eq.%s&banned=eq.false&limit=1" % name.uri_encode())
	if r.ok and r.get("j") is Array and not r.j.is_empty():
		result = r.j[0]
		msg = ""
	else:
		msg = "No player called %s." % name if r.ok else "Couldn't search right now. Try again."
	changed.emit()


## Recent players: our own metadata field only; passwords, profile and locker records are untouched
func save_player(id: String, add: bool) -> void:
	if not active() or busy or not _valid_id(id) or id == _me():
		return
	busy = true
	msg = "Saving player…" if add else "Removing player…"
	changed.emit()
	var owner: String = _me()
	if await m.account.fresh_token():
		var fresh: Dictionary = await m.account.sb_fetch("/auth/v1/user")
		if fresh.ok and fresh.get("j") is Dictionary and fresh.j.get("id") == owner:
			var ids: Array = _saved_of(fresh.j)
			if add and not ids.has(id):
				if ids.size() >= 50:
					msg = "Your list is full (50 players). Remove someone first."
					busy = false
					changed.emit()
					return
				ids.append(id)
			elif not add:
				ids.erase(id)
			var r: Dictionary = await m.account.sb_fetch("/auth/v1/user", "PUT", {"data": {SAVED_KEY: ids}})
			if r.ok and r.get("j") is Dictionary and r.j.get("id") == owner:
				m.account.s.user = r.j
				saved = ids
				msg = "Player saved to Recent." if add else "Player removed."
				if not add:
					profiles = profiles.filter(func(p): return p.id != id)
				elif result != null and result.id == id:
					profiles.append(result)
			else:
				msg = "Could not save. Try again."
		else:
			msg = "Could not save. Your list has not changed."
	busy = false
	changed.emit()


static func _saved_of(user: Dictionary) -> Array:
	var md = user.get("user_metadata", {})
	var raw = md.get(SAVED_KEY, []) if md is Dictionary else []
	var out: Array = []
	if raw is Array:
		for v in raw:
			if _valid_id(v) and not out.has(v):
				out.append(v)
	return out.slice(0, 50)


## the saved players' profiles and rooms
func refresh_saved() -> void:
	if not active():
		return
	saved = _saved_of(m.account.s.get("user", {}))
	if saved.is_empty():
		profiles = []
		changed.emit()
		return
	var ids := ",".join(saved)
	var r: Dictionary = await m.account.sb_fetch("/rest/v1/profiles?select=id,username,cos&id=in.(%s)&banned=eq.false&limit=50" % ids)
	profiles = r.j if r.ok and r.get("j") is Array else []
	await _load_rooms(friends.map(func(f): return str(f.id)) + saved)
	changed.emit()


# ---------------------------------------------------------------- the room: listing it and inviting friends

func _room_body() -> Dictionary:
	var n: PalNet = m.net
	var pk: Dictionary = n.pick
	return {"incarnation": n.incarnation, "code": n.code, "proto": PalNet.PROTO, "mode": pk.pvp if pk.pvp != "" else "coop", "length": pk.mode,
		"map": m.sim.game.map if n.in_game and not m.demo else ("yard" if pk.mode == "campaign" else ("city" if pk.mode == "blackout" else pk.map)),
		"chapter": int(m.sim.game.get("chapter", 0)) if n.in_game and not m.demo else 0, "players": n.roster.size(), "locked": n.locked}


func register_room() -> Dictionary:
	var n: PalNet = m.net
	if not active() or n.mode != "host" or n.code == "" or n.incarnation == "":
		return {"ok": false}
	if not await m.account.fresh_token():
		return {"ok": false}
	return await m.account.rpc_call("room_register", {"p": _room_body()})


## the open games list: published every 15 s while hosting (if listed), dropped when the room closes
func publish() -> void:
	var n: PalNet = m.net
	var a: PalAccount = m.account
	var inc: String = n.incarnation
	var still := func() -> bool: return n.mode == "host" and n.incarnation == inc   # the room may close while we wait
	if n.mode != "host" or n.code == "" or a.s.is_empty() or not await a.fresh_token() or not still.call():
		return
	if active():
		await register_room()
		if not still.call():
			return
	if not list_game:
		a.sb_fetch("/rest/v1/lobbies?host_id=eq." + str(_me()).uri_encode(), "DELETE")
		return
	var coop: bool = n.pick.pvp == "coop"
	var cnt: int = m.sim.players.size() if n.in_game and not m.demo else n.roster.size()
	var body := {"host_id": _me(), "code": n.code, "name": PalNet.clean_chat("%s's game" % n.me.name).substr(0, 24), "mode": n.pick.pvp,
		"length": n.pick.mode if coop else null, "diff": n.pick.diff if coop else null, "players": clampi(cnt, 1, 6), "in_game": n.in_game, "proto": PalNet.PROTO}
	await a.sb_fetch("/rest/v1/lobbies", "POST", body, true, 9.0, ["Prefer: resolution=merge-duplicates,return=minimal"])


func unpublish(incarnation: String) -> void:
	var a: PalAccount = m.account
	if a == null or a.s.is_empty():
		return
	a.sb_fetch("/rest/v1/lobbies?host_id=eq." + str(_me()).uri_encode(), "DELETE")
	if incarnation != "":
		a.rpc_call("room_register", {"p": {"incarnation": incarnation, "close": true}})


func refresh_open_games() -> String:
	var a: PalAccount = m.account
	if a == null or a.state == "off":
		return "The Open Games list needs a connection. Joining by code still works."
	if a.s.is_empty():
		return "Can't reach the game server right now. Joining by code still works." if a.state == "down" else "Connecting…"
	if not await a.fresh_token():
		return "Couldn't load the list. Joining by code still works."
	var r: Dictionary = await a.sb_fetch("/rest/v1/lobbies?select=code,name,mode,length,diff,players,in_game&proto=eq.%s&order=updated_at.desc&limit=30" % PalNet.PROTO)
	if not r.ok or not (r.get("j") is Array):
		return "Couldn't load the list. Joining by code still works."
	open_games = r.j.filter(func(g): return g.get("code") != m.net.code)
	return "" if not open_games.is_empty() else "No open games right now. Host one and it shows up here for everyone."


static func game_line(g: Dictionary) -> String:
	var bits: Array = [MODE_NAME.get(g.get("mode", ""), str(g.get("mode", "")))]
	if g.get("mode") == "coop" and g.get("length"):
		bits.append(LEN_NAME.get(str(g.length), str(g.length)))
	if g.get("mode") == "coop" and g.get("diff"):
		bits.append(str(g.diff).to_upper())
	bits.append("IN PROGRESS" if g.get("in_game", false) else "IN LOBBY")
	return " · ".join(bits)


func can_invite() -> bool:
	var n: PalNet = m.net
	return active() and n.mode == "host" and n.code != "" and not n.locked and n.roster.size() < 6


func invite(f: Dictionary) -> void:
	if not can_invite() or busy:
		return
	busy = true
	msg = ""
	changed.emit()
	var inc: String = m.net.incarnation
	var reg := await register_room()
	if inc != m.net.incarnation:
		busy = false
		return
	if not reg.get("ok", false):
		msg = "Your room could not be registered. Try again."
	else:
		var r: Dictionary = await m.account.rpc_call("lobby_invite_send", {"p_to": f.id})
		msg = ("An active invitation is already waiting." if r.j.get("duplicate", false) else "Invitation sent to %s. Valid for five minutes." % f.username) if r.ok and r.get("j") is Dictionary else m.account.err_text(r)
	busy = false
	await poll()


## yes: join the friend's room (leaving any room or run this screen is in); returns the code joined, or ""
func answer_invite(i: Dictionary, yes: bool) -> void:
	if not active() or busy:
		return
	busy = true
	changed.emit()
	var r: Dictionary = await m.account.rpc_call("lobby_invite_answer", {"p_id": i.id, "p_accept": yes, "p_proto": PalNet.PROTO})
	busy = false
	if not r.ok:
		msg = m.account.err_text(r)
		await poll()
		return
	msg = "Connecting to your friend…" if yes else "Invitation declined."
	if yes and r.get("j") is Dictionary:
		if m.net.mode != "solo":
			m.net.reset()
		if not m.demo:
			m._demo_game()
		m.menus.show_online(msg)
		m.net.me = m.net_me()
		m.net.join_room(str(r.j.get("code", "")), str(r.j.get("incarnation", "")))
	await poll()


static func invite_line(i: Dictionary) -> String:
	var r: Dictionary = i.get("room", {}) if i.get("room") is Dictionary else {}
	var mode: String = LEN_NAME.get(str(r.get("length", "")), MODE_NAME.get(str(r.get("mode", "")), "ROOM"))
	var mp: String = PalMaps.MAPS[r.map].short if PalMaps.MAPS.has(r.get("map", "")) else ("City" if r.get("map") == "city" else "Room")
	var mins := maxi(0, ceili((Time.get_unix_time_from_datetime_string(str(i.get("expires_at", "")).substr(0, 19)) - Time.get_unix_time_from_system()) / 60.0))
	return "%s · %s%s · %d slots · %s" % [mode, mp, (" · chapter %d" % (int(r.get("chapter", 0)) + 1)) if r.get("length") == "campaign" else "",
		maxi(0, 6 - int(r.get("players", 6))), "locked" if r.get("locked", false) else "expires in %d min" % mins]


static func ago(t: String) -> String:
	var sec := maxf(0.0, Time.get_unix_time_from_system() - Time.get_unix_time_from_datetime_string(t.substr(0, 19)))
	if sec < 60:
		return "just now"
	if sec < 3600:
		return "%d min ago" % floori(sec / 60)
	if sec < 86400:
		return "%d h ago" % floori(sec / 3600)
	return "%d d ago" % floori(sec / 86400)
