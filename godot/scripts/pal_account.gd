class_name PalAccount
extends Node
## Accounts and the cloud locker (19-accounts.js), on the browser's own Supabase project, so one account and its
## locker, skills and rewards work in both games.
## Everyone starts as a guest account, made quietly in the background. Adding an email (and a password, set on the
## website from the link) makes it a full account that signs in anywhere. Once there is an account the server owns
## the locker: cases are rolled there and every finished run is checked there. This PC keeps a copy, so the menus
## open instantly and solo plays with no signal; finished runs wait in a queue (user://claims.json) until they reach
## the account.

## the public "publishable" key: it can only do what the database's own rules allow
const SB_URL := "https://puvjfhwxigxjpsvdwrwf.supabase.co"
const SB_KEY := "sb_publishable_xe3uY3icYguSM5pqlD7a1Q_7OD3B4v6"
## where the links in our emails land (the browser game finishes confirmations and password resets)
const SITE_URL := "https://lopoke89-ops.github.io/palisade/"
const AUTH_PATH := "user://auth.json"
const GUEST_PATH := "user://auth_guest.json"
const CLAIM_PATH := "user://claims.json"

## tests and render scripts switch the network off before the main scene starts
static var offline := false

signal changed   # the state, name or locker changed: screens redraw
signal claim_done(c: Dictionary, R, big: String)   # a queued run reached the account (R: the reward, or a refusal's text)

var m   # the main node (its locker and profile)
var s := {}   # the session: access_token, refresh_token, expires_at, user
var name_ := ""
var state := "off"   # off (no network), wait, down, guest, full
var msg := ""
var busy := false
var persist := true
var claims: Array = []
var _refreshing := false
var _flushing := false
var last_claim_locker = null
var t_sync := 0.0
## a stand-in for the network, for tests: func(method, path, body, headers) -> {ok, status, j}
var transport: Callable


func _init(main = null) -> void:
	m = main


func _ready() -> void:
	if offline:   # tests and render scripts: no network, no account files
		state = "off"
		persist = false
		return
	_load()


func _load() -> void:
	var a = _read(AUTH_PATH)
	if a is Dictionary and a.get("access_token") and a.get("refresh_token"):
		s = a
	var q = _read(CLAIM_PATH)
	claims = q.get("q", []) if q is Dictionary else []


static func _read(path: String):
	return JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null


func _write(path: String, v) -> void:
	if not persist:
		return
	if v == null:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(v))


# ---------------------------------------------------------------- the session

func is_guest() -> bool:
	return s.has("user") and s.user is Dictionary and s.user.get("is_anonymous", false)


func uid():
	if s.has("user") and s.user is Dictionary and s.user.get("id"):
		return s.user.id
	return jwt_sub(s.get("access_token", "")) if s.has("access_token") else null


static func jwt_sub(t: String):
	var parts := t.split(".")
	if parts.size() < 2:
		return null
	var b := parts[1].replace("-", "+").replace("_", "/")
	while b.length() % 4:
		b += "="
	var d = JSON.parse_string(Marshalls.base64_to_utf8(b))
	return d.get("sub") if d is Dictionary else null


func signed_in() -> bool:
	return not s.is_empty()


func set_session(d) -> void:
	if not (d is Dictionary) or not d.get("access_token"):
		s = {}
		_write(AUTH_PATH, null)
		return
	var keep = s.get("user") if s.get("user") is Dictionary and s.user.get("id") == jwt_sub(d.access_token) else null
	var exp := float(d.get("expires_at", 0))
	if exp <= 0:
		exp = Time.get_unix_time_from_system() + float(d.get("expires_in", 3600))
	s = {"access_token": d.access_token, "refresh_token": d.get("refresh_token", ""), "expires_at": exp, "user": d.get("user") if d.get("user") is Dictionary else keep}
	_write(AUTH_PATH, s)


## one call to the project: {ok, status, j}. status 0: it never got an answer.
func sb_fetch(path: String, method: String = "GET", body = null, auth: bool = true, timeout: float = 9.0, extra: Array = []) -> Dictionary:
	var h := PackedStringArray(["apikey: " + SB_KEY, "Content-Type: application/json"])
	if auth and s.has("access_token"):
		h.append("Authorization: Bearer " + s.access_token)
	h.append_array(extra)
	if transport.is_valid():
		return await transport.call(method, path, body, h)
	var req := HTTPRequest.new()
	req.timeout = timeout
	add_child(req)
	_net_setup(req)
	var methods := {"GET": HTTPClient.METHOD_GET, "POST": HTTPClient.METHOD_POST, "PUT": HTTPClient.METHOD_PUT, "DELETE": HTTPClient.METHOD_DELETE, "PATCH": HTTPClient.METHOD_PATCH}
	var err := req.request(SB_URL + path, h, methods.get(method, HTTPClient.METHOD_GET), JSON.stringify(body) if body != null else "")
	if err != OK:
		req.queue_free()
		return {"ok": false, "status": 0, "j": null}
	var res: Array = await req.request_completed
	req.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "j": null}
	var code: int = res[1]
	var t: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var j = JSON.parse_string(t) if t != "" else null
	return {"ok": code >= 200 and code < 300, "status": code, "j": j}


## Godot reads no system proxy: an HTTPS_PROXY in the environment is honoured, and SSL_CERT_FILE adds trusted roots
## (a proxy that re-signs TLS, as some company and school networks do)
func _net_setup(req: HTTPRequest) -> void:
	var px := OS.get_environment("HTTPS_PROXY")
	if px == "":
		px = OS.get_environment("https_proxy")
	if px != "":
		var u := px.trim_prefix("http://").trim_prefix("https://").split("/")[0]
		if u.contains("@"):
			u = u.split("@")[1]
		var hp := u.rsplit(":", true, 1)
		req.set_https_proxy(hp[0], int(hp[1]) if hp.size() > 1 else 8080)
	var ca := OS.get_environment("SSL_CERT_FILE")
	if ca != "" and FileAccess.file_exists(ca):
		var cert := X509Certificate.new()
		if cert.load(ca) == OK:
			req.set_tls_options(TLSOptions.client(cert))


## sbErr: a server answer in plain words
static func err_text(r: Dictionary, fb: String = "") -> String:
	if not r.get("status", 0):
		return "Couldn't reach the account server. Check your connection and try again."
	var j: Dictionary = r.j if r.get("j") is Dictionary else {}
	var mm: String = str(j.get("message", j.get("msg", j.get("error_description", j.get("error", "")))))
	var c: String = str(j.get("error_code", j.get("code", "")))
	var low := mm.to_lower()
	if c == "email_exists" or low.contains("already been registered"):
		return "That email already has an account. Sign in to it below instead."
	if c == "invalid_credentials" or low.contains("invalid login"):
		return "That email and password don't match."
	if c == "email_not_confirmed" or low.contains("not confirmed"):
		return "That email isn't confirmed yet. Open the link we sent, then sign in."
	if c == "weak_password" or low.contains("password should"):
		return "Pick a longer password: at least 8 characters."
	if c == "same_password":
		return "That's already your password."
	if c == "over_email_send_rate_limit" or c == "over_request_rate_limit" or r.status == 429:
		return "Too many tries. Wait a few minutes and try again."
	if low.contains("captcha"):
		return "The robot check failed. Try again."
	if c == "validation_failed" and low.contains("email"):
		return "That doesn't look like an email address."
	return mm if mm != "" and mm.length() < 140 else (fb if fb != "" else "Something went wrong. Try again.")


func fresh_token() -> bool:
	if s.is_empty():
		return false
	if float(s.get("expires_at", 0)) - Time.get_unix_time_from_system() > 90:
		return true
	while _refreshing:
		await get_tree().process_frame
		if not s.is_empty() and float(s.get("expires_at", 0)) - Time.get_unix_time_from_system() > 90:
			return true
	_refreshing = true
	var r := await sb_fetch("/auth/v1/token?grant_type=refresh_token", "POST", {"refresh_token": s.get("refresh_token", "")}, false)
	_refreshing = false
	if r.ok and r.j is Dictionary and r.j.get("access_token"):
		set_session(r.j)
		return true
	if r.status in [400, 401, 403]:
		end_session("Your sign-in ended. Sign in again to get your locker back.")
	return false


func rpc_call(fn: String, args: Dictionary = {}) -> Dictionary:
	if not await fresh_token():
		return {"ok": false, "status": 401 if signed_in() else 0, "j": {"message": "Sign in first."}}
	var r := await sb_fetch("/rest/v1/rpc/" + fn, "POST", args)
	if r.status == 401 and signed_in():
		s.expires_at = 0
		if await fresh_token():
			r = await sb_fetch("/rest/v1/rpc/" + fn, "POST", args)
	return r


# ---------------------------------------------------------------- starting up

func boot() -> void:
	if (offline and not transport.is_valid()) or busy:
		return
	busy = true
	state = "wait"
	changed.emit()
	if s.is_empty():
		var g = _read(GUEST_PATH)
		if g is Dictionary and g.get("refresh_token"):
			g.expires_at = 1
			set_session(g)
			_write(GUEST_PATH, null)
	if s.is_empty():
		var r := await make_guest()
		if not r.ok:
			state = "down"
			if r.status:
				msg = err_text(r)
			busy = false
			changed.emit()
			return
	var r := await sync_locker()
	await load_profile()
	busy = false
	if s.is_empty():
		state = "down"
	elif not r.ok:
		state = "down"
		msg = err_text(r) if r.status else ""
	else:
		state = "guest" if is_guest() else "full"
		t_sync = Time.get_ticks_msec() / 1000.0
	changed.emit()


## coming back to the game: try again, or bring the locker up to date (at most every two minutes)
func resume() -> void:
	if offline or busy or Time.get_ticks_msec() / 1000.0 - t_sync < 120:
		return
	t_sync = Time.get_ticks_msec() / 1000.0
	if state == "down":
		boot()
	elif state == "guest" or state == "full":
		await sync_locker()
		changed.emit()


func make_guest() -> Dictionary:
	var r := await sb_fetch("/auth/v1/signup", "POST", {"data": {}}, false)
	if r.ok and r.j is Dictionary and r.j.get("access_token"):
		set_session(r.j)
	elif r.ok:
		return {"ok": false, "status": 400, "j": {"message": "Guest accounts are switched off."}}
	return r


## switching from a guest to a full account keeps the guest's sign-in, so signing out returns to it
func keep_guest(new_uid) -> void:
	if is_guest() and s.user.get("id") != new_uid:
		_write(GUEST_PATH, s)


func end_session(why: String) -> void:
	set_session(null)
	name_ = ""
	state = "down"
	if why != "":
		msg = why
	var L: PalLocker = m.locker
	L.norm({})
	L.cloud = {}
	L.save()
	m.profile.from_cloud({})
	claims = []
	_save_claims()
	changed.emit()


# ---------------------------------------------------------------- the locker

## an untouched local locker (nothing worth importing)
static func locker_fresh(L: PalLocker) -> bool:
	if L.cases > 1 or L.shards or L.prog:
		return false
	for k in L.st:
		if int(L.st[k]):
			return false
	for k in L.bag:
		if int(L.bag[k]) > 0:
			return false
	for id in L.owned:
		var c := PalLocker.item(id)
		if c.is_empty() or c.src != "free":
			return false
	return true


## takeLocker: the account's locker becomes this PC's copy, skill tree included
func take_locker(j) -> void:
	if not (j is Dictionary) or not (j.get("owned") is Array) or s.is_empty():
		return
	var L: PalLocker = m.locker
	L.norm(j)
	L.cloud = {"id": uid(), "guest": is_guest()}
	L.save()
	m.profile.from_cloud(j)
	changed.emit()


## get_my_locker; a save made on this PC before it had an account (or a guest's locker, signing in to a real
## account) goes in once with import_local_save. The server refuses a second import into the same account.
func sync_locker() -> Dictionary:
	await flush_claims()
	var r: Dictionary
	if last_claim_locker != null and Time.get_ticks_msec() / 1000.0 - last_claim_locker.at < 5:
		r = {"ok": true, "status": 200, "j": last_claim_locker.j}
	else:
		r = await rpc_call("get_my_locker")
	if not r.ok:
		return r
	last_claim_locker = null
	var j = r.j
	var L: PalLocker = m.locker
	var me = uid()
	var mine: bool = L.cloud.is_empty() or (L.cloud.get("guest", false) and L.cloud.get("id") != me)
	if j is Dictionary and not j.get("imported", false) and mine and not locker_fresh(L):
		var im := await rpc_call("import_local_save", {"p_save": {"owned": L.owned, "eq": L.eq, "cases": L.cases, "bag": L.bag, "shards": L.shards, "prog": L.prog, "st": L.st}})
		if im.ok:
			j = im.j
	elif j is Dictionary and j.get("imported", false) and mine and not L.cloud.is_empty() and not locker_fresh(L):
		msg = "This account already took in a guest locker once, so this PC's guest items stay with the guest. Sign out to get back to them."
	take_locker(j)
	return r


func load_profile() -> void:
	var me = uid()
	if me == null or not await fresh_token():
		return
	var u := await sb_fetch("/auth/v1/user")
	if u.ok and u.j is Dictionary and u.j.get("id"):
		s.user = u.j
		set_session(s)
	var r := await sb_fetch("/rest/v1/profiles?select=username&id=eq." + str(me).uri_encode())
	if r.ok and r.j is Array and not r.j.is_empty():
		name_ = str(r.j[0].get("username", "")) if r.j[0].get("username") != null else ""


# ---------------------------------------------------------------- finished runs

func _save_claims() -> void:
	_write(CLAIM_PATH, {"q": claims.slice(maxi(0, claims.size() - 8))})


## a finished run goes in the queue; the reward shows when the server answers (claim_done)
func queue_claim(c: Dictionary) -> Dictionary:
	var q := c.duplicate(true)
	if q.get("kind", "run") == "run" and q.get("mode") not in ["blitz", "campaign"]:   # the browser only sends these for Blitzkrieg and Whiteout
		q.erase("fb_keys")
		q.erase("evac")
	if q.get("kind", "run") == "run" and q.get("mode") != "campaign":
		q.erase("g_cleared")
		q.erase("ch_evac")
	q.uid = m.locker.cloud.get("id")
	q.at = int(Time.get_unix_time_from_system() * 1000)
	claims.append(q)
	_save_claims()
	flush_claims()
	return {"kind": c.get("kind", "run"), "pending": true, "cases": {}, "shards": 0, "sp": 0, "unlocked": [], "claim_at": q.at,
		"text": "Sending your result to your account…"}


func flush_claims() -> void:
	if _flushing or claims.is_empty() or s.is_empty():
		return
	_flushing = true
	while not claims.is_empty() and not s.is_empty():
		var c: Dictionary = claims[0]
		if c.get("uid") != uid() or Time.get_unix_time_from_system() * 1000 - float(c.get("at", 0)) > 30 * 864e5:
			claims.pop_front()
			_save_claims()
			continue
		var p := c.duplicate(true)
		p.erase("uid")
		p.erase("at")
		p.erase("boHeld")
		var r := await rpc_call("claim_match_reward", {"p": p})
		if r.ok:
			claims.pop_front()
			_save_claims()
			take_locker(r.j.get("locker") if r.j is Dictionary else null)
			last_claim_locker = {"j": r.j.get("locker"), "at": Time.get_ticks_msec() / 1000.0}
			var dropped: bool = c.get("kind") == "run" and r.j.get("bonus") is Dictionary and int(r.j.bonus.get("n", 0)) > 0
			claim_done.emit(c, claim_reward(c, r.j), "CASE DROP" if dropped else "REWARDS SAVED")
			continue
		var why := err_text(r)
		if not r.status or r.status >= 500 or r.status == 401:
			break
		if why.contains("moment ago"):
			get_tree().create_timer(21).timeout.connect(flush_claims)
			break
		if why.contains("saved later"):   # the play-time budget: the server takes it once enough real time has passed
			get_tree().create_timer(300).timeout.connect(flush_claims)
			break
		claims.pop_front()
		_save_claims()
		claim_done.emit(c, "The server didn't accept that result (%s). Nothing was added." % why, "NOT SAVED")
	_flushing = false


## claimReward: the server's answer in the shape the reward cards read
func claim_reward(c: Dictionary, j: Dictionary) -> Dictionary:
	var cases := {}
	if j.get("cases") is Dictionary:
		for id in j.cases:
			cases[id] = int(j.cases[id])
	elif c.get("kind") == "run":
		cases.supply = int(j.get("cases_granted", 0))
	elif j.get("case_id"):
		cases[j.case_id] = int(j.get("cases_granted", 0))
		var bl: Array = j.get("bonuses") if j.get("bonuses") is Array else [j.get("bonus") if j.get("bonus") is Dictionary else {}]
		for b in bl:
			if b is Dictionary and b.get("case"):
				cases[b.case] = int(cases.get(b.case, 0)) + int(b.get("n", 0))
	var prog := int(j.locker.get("prog", 0)) if j.get("locker") is Dictionary else 0
	var ids: Array = j.unlocked_ids if j.get("unlocked_ids") is Array else []
	var R := {"kind": c.get("kind", "run"), "cases": cases, "shards": int(j.get("shards", 0)), "unlocked": ids, "prog": prog,
		"toNext": int(j.to_next) if j.get("to_next") != null else 3 - prog, "cloud": true, "bossShards": int(j.get("boss_shards", 0)),
		"sp": int(j.get("skill_points", 0)), "left": bool(j.get("left_behind", false)), "blitzShards": c.get("mode") in ["blitz", "campaign"],
		"pois": -1, "claim_at": c.get("at", 0)}
	R.text = m.locker.reward_text(R)
	return R


# ---------------------------------------------------------------- the account page's actions

func set_username(n: String) -> String:
	var r := await rpc_call("set_username", {"p_name": n})
	if not r.ok:
		return err_text(r)
	name_ = n
	return "Username saved."


func link_email(mail: String) -> String:
	if not await fresh_token():
		return err_text({"status": 0})
	var r := await sb_fetch("/auth/v1/user?redirect_to=" + SITE_URL.uri_encode(), "PUT", {"email": mail})
	if not r.ok:
		return err_text(r)
	return "Link sent to %s. Open it (check spam too) and choose a password on the website, then sign in here with it." % mail


func set_password(pw: String) -> String:
	if not await fresh_token():
		return err_text({"status": 0})
	var r := await sb_fetch("/auth/v1/user", "PUT", {"password": pw, "data": {"pw": 1}})
	if not r.ok:
		return err_text(r)
	if r.j is Dictionary and r.j.get("id"):
		s.user = r.j
		set_session(s)
	return "Password saved. Sign in with your email and this password on any device."


func needs_password() -> bool:
	return s.has("user") and s.user is Dictionary and not is_guest() and s.user.get("email") and not (s.user.get("user_metadata", {}) as Dictionary).get("pw")


func sign_in(mail: String, pw: String) -> String:
	var r := await sb_fetch("/auth/v1/token?grant_type=password", "POST", {"email": mail, "password": pw}, false)
	if not r.ok or not (r.j is Dictionary) or not r.j.get("access_token"):
		return err_text(r)
	keep_guest(r.j.user.get("id") if r.j.get("user") is Dictionary else null)
	set_session(r.j)
	name_ = ""
	if r.j.get("user") is Dictionary and not (r.j.user.get("user_metadata", {}) as Dictionary).get("pw"):
		sb_fetch("/auth/v1/user", "PUT", {"data": {"pw": 1}})
	var sl := await sync_locker()
	await load_profile()
	state = "full"
	changed.emit()
	return (msg if msg != "" else "Signed in. Your locker is loaded.") if sl.ok else "Signed in, but your locker didn't load yet. It will when you're back online."


func forgot(mail: String) -> String:
	var r := await sb_fetch("/auth/v1/recover?redirect_to=" + SITE_URL.uri_encode(), "POST", {"email": mail}, false)
	if not r.ok:
		return err_text(r)
	return "If %s has an account, a reset link is on its way. Choose a new password on the website, then sign in here." % mail


func sign_out() -> String:
	if await fresh_token():
		await sb_fetch("/auth/v1/logout?scope=local", "POST")
	end_session("")
	busy = false
	await boot()
	return "Signed out. Sign back in any time to get your locker."


# ---------------------------------------------------------------- the cloud locker's actions (20-locker-ui.js, 20b-case-openings.js)

const OPEN_PATH := "user://opening.json"


## an opening that was sent but whose answer never came back (a crash, a lost connection): it is resumed with the
## same operation ID, so the server hands back the same results instead of opening more cases
func pending_opening() -> Dictionary:
	var p = _read(OPEN_PATH)
	return p if p is Dictionary and p.get("owner") == uid() else {}


func clear_opening() -> void:
	_write(OPEN_PATH, null)


static func new_operation() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]


## open_cases_v0964 (catalog 4); a server without it answers 404 and the catalog-3 opener runs.
## {ok, results: [{it, dup, shards, box}], err, uncertain}. Uncertain: the opening is kept to resume.
func open_cases(id: String, n: int, resume: Dictionary = {}) -> Dictionary:
	var p := resume
	if p.is_empty():
		p = {"owner": uid(), "operation": new_operation(), "case": id, "quantity": n}
		if persist:
			_write(OPEN_PATH, p)
	var args := {"p_case": p.case, "p_quantity": p.quantity, "p_operation": p.operation}
	var r := await rpc_call("open_cases_v0964", args)
	if r.status == 404 and p.case != "hybrid":
		r = await rpc_call("open_cases_v0962", args)
	if not r.ok:
		var unsure: bool = not r.status or r.status >= 500 or r.status == 401
		if not unsure:
			clear_opening()
		return {"ok": false, "uncertain": unsure, "err": err_text(r) if r.status else "Opening is awaiting confirmation. Reconnect and resume; your opening is saved."}
	if uid() != p.owner:
		return {"ok": false, "uncertain": true, "err": "Sign back into the account that started this opening to resume."}
	take_locker(r.j.get("locker"))
	var out: Array = []
	for x in r.j.get("results", []):
		var item: Dictionary = x.get("item", {})
		var it := PalLocker.item(str(item.get("id", "")))
		if it.is_empty():   # an item this build doesn't know yet
			it = PalLocker.item("fx:none").duplicate()
			it.merge(item, true)
			it.r = item.get("rarity", "c")
		out.append({"it": it, "dup": bool(x.get("dup", false)), "shards": int(x.get("shards", 0)), "box": p.case})
	return {"ok": true, "results": out, "case": p.case}


func buy_case(id: String) -> String:
	var r := await rpc_call("buy_case", {"p_case": id})
	if r.ok:
		take_locker(r.j)
		return ""
	return err_text(r) if r.status else "Buying a case needs a connection. Your shards are safe."


func buy_case_sp() -> String:
	var r := await rpc_call("buy_case_sp")
	if r.ok:
		take_locker(r.j)
		return ""
	return err_text(r) if r.status else "Trading skill points needs a connection. Your points are safe."


## the item is already worn here; the account follows, and a refusal brings the account's locker back
func equip(item_id: String) -> void:
	var r := await rpc_call("equip", {"p_item": item_id})
	if r.ok:
		take_locker(r.j)
	elif r.status and r.status != 401:
		sync_locker()
