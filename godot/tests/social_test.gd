extends SceneTree
## Friends, invitations and the open games list (scripts/pal_social.gd) against a fake Supabase that answers the
## way the real social RPCs do. Nothing touches the network or the PC's saves.
##   godot --headless --path godot --script res://tests/social_test.gd     (exit 0 = pass)

var fails := 0
const ME := "11111111-1111-4111-8111-111111111111"
const ANN := "22222222-2222-4222-8222-222222222222"
const BO := "33333333-3333-4333-8333-333333333333"


func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


class Fake:
	var log: Array = []
	var friends: Array = [{"id": ANN, "username": "ann"}]
	var incoming: Array = [{"id": "req-1", "at": "2026-10-17T00:00:00Z", "user": {"id": BO, "username": "bo"}}]
	var outgoing: Array = []
	var meta: Dictionary = {}
	var lobbies: Array = []
	var invited: Array = []
	var answered: Array = []

	func call_(method: String, path: String, body, h) -> Dictionary:
		log.append(method + " " + path.split("?")[0])
		var now := int(Time.get_unix_time_from_system())
		if path.begins_with("/auth/v1/token"):
			return {"ok": true, "status": 200, "j": {"access_token": "h.e30.s", "refresh_token": "r2", "expires_in": 3600, "user": {"id": ME}}}
		if path.begins_with("/auth/v1/user"):
			if method == "PUT":
				meta.merge(body.data, true)
			return {"ok": true, "status": 200, "j": {"id": ME, "email": "me@example.com", "user_metadata": meta}}
		if path.begins_with("/rest/v1/profiles"):
			if path.contains("username=eq.bobby"):
				return {"ok": true, "status": 200, "j": [{"id": BO, "username": "bo", "cos": "std|cap|std|none"}]}
			if path.contains("id=in."):
				return {"ok": true, "status": 200, "j": [{"id": BO, "username": "bo", "cos": ""}]}
			return {"ok": true, "status": 200, "j": []}
		if path.begins_with("/rest/v1/lobbies"):
			if method == "POST":
				lobbies = lobbies.filter(func(l): return l.host_id != body.host_id)
				lobbies.append(body)
				return {"ok": true, "status": 201, "j": null}
			if method == "DELETE":
				lobbies = lobbies.filter(func(l): return not path.contains(l.host_id))
				return {"ok": true, "status": 204, "j": null}
			if path.contains("host_id=in."):
				return {"ok": true, "status": 200, "j": [{"host_id": ANN, "code": "ANN1", "players": 2, "in_game": false}]}
			return {"ok": true, "status": 200, "j": lobbies + [{"code": "ZZZ9", "name": "Bo's game", "mode": "base", "length": null, "diff": null, "players": 3, "in_game": true}]}
		match path:
			"/rest/v1/rpc/social_state":
				return {"ok": true, "status": 200, "j": {"friends": friends, "incoming": incoming, "outgoing": outgoing, "unseen": 1,
					"notes": [{"kind": "friend_request", "user": {"username": "bo"}, "created_at": "2026-10-17T00:00:00Z"}],
					"invites": [{"id": "inv-1", "user": {"id": ANN, "username": "ann"}, "expires_at": Time.get_datetime_string_from_unix_time(now + 240) + "Z",
						"room": {"mode": "coop", "length": "blitz", "map": "river", "players": 2, "locked": false}}]}}
			"/rest/v1/rpc/friend_answer":
				if body.p_accept:
					friends.append(incoming[0].user)
				incoming.clear()
				return {"ok": true, "status": 200, "j": {}}
			"/rest/v1/rpc/friend_send":
				outgoing.append({"id": "req-2", "at": "2026-10-17T00:00:00Z", "user": {"id": body.p_to, "username": "?"}})
				return {"ok": true, "status": 200, "j": {"state": "sent"}}
			"/rest/v1/rpc/friend_remove":
				friends = friends.filter(func(f): return f.id != body.p_other)
				return {"ok": true, "status": 200, "j": {}}
			"/rest/v1/rpc/notes_seen":
				return {"ok": true, "status": 200, "j": {}}
			"/rest/v1/rpc/room_register":
				return {"ok": true, "status": 200, "j": {"ok": true}}
			"/rest/v1/rpc/lobby_invite_send":
				invited.append(body.p_to)
				return {"ok": true, "status": 200, "j": {"duplicate": false}}
			"/rest/v1/rpc/lobby_invite_answer":
				answered.append([body.p_id, body.p_accept, body.p_proto])
				return {"ok": true, "status": 200, "j": {"code": "ANN1", "incarnation": "inc-9"} if body.p_accept else {}}
		return {"ok": false, "status": 404, "j": {"message": "no route " + path}}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	PalAccount.offline = true
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	for n in 5:
		await process_frame
	main.locker.persist = false
	main.profile.persist = false
	main.settings.data.name = "Me"
	var A: PalAccount = main.account
	var F := Fake.new()
	A.persist = false
	A.transport = F.call_
	var S: PalSocial = main.social
	print("friends")
	check(not S.active(), "no saved account: no friends (a guest has none either)")
	A.s = {"access_token": "h.e30.s", "refresh_token": "r1", "expires_at": Time.get_unix_time_from_system() + 3600, "user": {"id": ME, "email": "me@example.com", "is_anonymous": false}}
	A.state = "full"
	check(S.active(), "a saved account has friends")
	await S.poll()
	check(S.ok and S.friends.size() == 1 and S.incoming.size() == 1 and S.unseen == 1 and S.invites.size() == 1, "social_state: friends, requests, mail and an invitation")
	check(S.room_text(ANN) == "IN LOBBY · 2/6" and S.room_of(ANN).code == "ANN1", "a friend's listed room shows (and can be joined)")
	await S.answer(S.incoming[0], true)
	check(S.friends.size() == 2 and S.incoming.is_empty() and S.msg.begins_with("You and bo are friends"), "accepting a request: friends now (%s)" % S.msg)
	await S.find("x")
	check(S.result == null and S.msg.begins_with("Enter an exact username"), "a bad username is refused before asking")
	await S.find("bobby")
	check(S.result != null and S.result.id == BO, "an exact username finds the player")
	await S.save_player(BO, true)
	check(S.saved == [BO] and F.meta.get(PalSocial.SAVED_KEY) == [BO], "saving a player writes only our metadata field")
	await S.refresh_saved()
	check(S.profiles.size() == 1 and S.profiles[0].username == "bo", "recent players load their profiles")
	await S.mark_seen()
	check(S.unseen == 0 and F.log.has("POST /rest/v1/rpc/notes_seen"), "opening the mailbox marks it seen")
	await S.remove_friend({"id": BO, "username": "bo"})
	check(S.friends.size() == 1 and S.msg == "bo removed from friends.", "removing a friend")
	print("the room: listing and invitations")
	var why: String = await S.refresh_open_games()
	check(why == "" and S.open_games.size() == 1 and PalSocial.game_line(S.open_games[0]) == "BASE BATTLE · IN PROGRESS", "the open games list (%s)" % (PalSocial.game_line(S.open_games[0]) if not S.open_games.is_empty() else why))
	var n: PalNet = main.net
	n.mode = "host"
	n.code = "ABCD"
	n.incarnation = "inc-1"
	n.roster = [{"id": "host", "name": "Me", "cls": "soldier", "cos": "", "team": "a", "sk": ""}]
	n.me = main.net_me()
	await S.publish()
	check(F.lobbies.size() == 1 and F.lobbies[0].code == "ABCD" and F.lobbies[0].proto == PalNet.PROTO and F.lobbies[0].host_id == ME, "a hosted room is listed for everyone")
	check(F.log.has("POST /rest/v1/rpc/room_register"), "and registered for invitations")
	check(S.can_invite(), "the host can invite friends")
	await S.invite({"id": ANN, "username": "ann"})
	check(F.invited == [ANN] and S.msg.begins_with("Invitation sent to ann"), "an invitation goes out (%s)" % S.msg)
	n.mode = "solo"
	n.code = ""
	S.unpublish("inc-1")
	for k in 3:
		await process_frame
	check(F.lobbies.is_empty(), "closing the room takes it off the list")
	print("an invitation, accepted")
	check(PalSocial.invite_line(S.invites[0]).begins_with("BLITZKRIEG RUSH · Riverbend · 4 slots · expires in"), "it says what the room is (%s)" % PalSocial.invite_line(S.invites[0]))
	n.opts = {"host": "127.0.0.1", "port": 1, "path": "/", "secure": false, "ice": []}   # nowhere: we only check the join is attempted
	await S.answer_invite(S.invites[0], true)
	check(F.answered[0] == ["inv-1", true, PalNet.PROTO], "answered with this game's protocol")
	check(n.code == "ANN1" and n._invite == "inc-9" and (n.mode == "joining" or n.mode == "solo"), "joins the friend's room with its incarnation")
	n.reset()
	print("")
	print("FAILED %d" % fails if fails else "ALL PASSED")
	quit(1 if fails else 0)
