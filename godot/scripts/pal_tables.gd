class_name PalTables
extends Node
## The casino's dealer is a server: the `tables` edge function (dev/supabase/functions/tables), POST /functions/v1/tables
## on the browser's Supabase project (21b-tables.js tbCall / tbCallOp / tbSend). The server shuffles, deals, spins, rolls
## and pays; this client only sends moves and keeps the latest view the server says this player may see. It polls once
## a second while seated. Moves that can move shards carry an operation id made before the first send and kept until
## the server answers, so a timeout or a dropped connection resends the same id and the server answers it from its
## record instead of moving shards twice.
## Also here: the fairness check (tbVerify), byte for byte the browser's, so hand history can rerun any round.

const PATH := "/functions/v1/tables"
const TIMEOUT := 12.0
## the moves that can move shards (TB_MONEY): these carry an operation id
const MONEY := ["sit", "topup", "leave", "bet", "insure", "move", "rlbets", "babets", "crbet", "spin", "drop", "pick"]
const NAME := {"bj": "BLACKJACK", "he": "TEXAS HOLD'EM", "rl": "ROULETTE", "ba": "BACCARAT", "cr": "CRAPS", "sl": "SLOTS", "pk": "PLINKO"}
const RL_RED := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]

signal updated(v: Dictionary)   # a new view of your own table
signal message(text: String)   # the line under the sheet (tbMsg)
signal receipt(rc: Dictionary)   # a spin or drop's receipt came with the answer (replayed as is on a retry)
signal left_table(kind: String)   # no longer seated: "left" (stood up, shards home), "pending" (craps bets still working), "gone"
signal balance_changed(n: int)

var account   # PalAccount
var id := 0   # your table (0: not seated)
var code := ""
var v: Dictionary = {}   # the latest view of your table; v._t: when it arrived (ms)
var balance := 0
var mine = null   # the lobby's "you're still seated somewhere" ({id, game, station, pending})
var station := ""
var busy := false
var pend := {}   # the money move waiting for an answer: {key, id, t}
var hist: Array = []   # the last hand history fetched
var peeks := {}   # "game:station" -> {v, t}: tables you're standing next to
var polling := true   # poll while seated (the sheet hidden too)
var _poll_t := 0.0
var _poll_busy := false
var retry_wait := 0.7   # seconds before a retry (x1, x2); tests shorten it


func _init(acct = null) -> void:
	account = acct


static func now_ms() -> float:
	return float(Time.get_ticks_msec())


## why this player can't play at the tables, or "" (tbCanPlay)
func cant_play() -> String:
	if account == null or not account.signed_in():
		return "Sign in to play at the tables."
	if account.is_guest():
		return "Make an account on the Account page to play at the tables. Guests can't."
	return ""


# ---------------------------------------------------------------- talking to the server

## tbCall: one request; the answer's body, or {error} in plain words
func call_api(body: Dictionary) -> Dictionary:
	if account == null or not await account.fresh_token():
		return {"error": "Sign in to play at the tables"}
	var r: Dictionary = await account.sb_fetch(PATH, "POST", body, true, TIMEOUT)
	if r.status == 401 and account.signed_in():   # a token the server no longer takes: refresh once and resend
		account.s.expires_at = 0
		if await account.fresh_token():
			r = await account.sb_fetch(PATH, "POST", body, true, TIMEOUT)
	if not (r.get("j") is Dictionary):
		return {"error": "The tables are busy. Try again." if r.get("status", 0) else "No connection"}
	return r.j


## a fresh operation id (tbOpId): 'o' and 22 base-36 characters from 12 random bytes
static func op_id() -> String:
	var b := Crypto.new().generate_random_bytes(12)
	var s := ""
	for x in b:
		s += _b36(x).lpad(2, "0")
	return "o" + s.substr(0, 22)


static func _b36(n: int) -> String:
	const D := "0123456789abcdefghijklmnopqrstuvwxyz"
	if n == 0:
		return "0"
	var s := ""
	while n > 0:
		s = D[n % 36] + s
		n /= 36
	return s


static func _transient(r: Dictionary) -> bool:
	var e := str(r.get("error", "")) if r.get("error") != null else ""
	return e.to_lower().contains("connection") or e.to_lower().contains("busy")


## tbCallOp: a money move keeps its id across retries (the same request, within two minutes, is the same move)
func call_op(body: Dictionary) -> Dictionary:
	if not MONEY.has(body.get("op", "")):
		return await call_api(body)
	var b := body.duplicate(true)
	b.erase("opId")
	var key := JSON.stringify(b, "", true)
	if pend.is_empty() or pend.key != key or now_ms() - pend.t > 120000.0:
		pend = {"key": key, "id": op_id(), "t": now_ms()}
	b.opId = pend.id
	var r := await call_api(b)
	for k in 2:   # same id: never a second debit
		if r.has("view") or not _transient(r):
			break
		await get_tree().create_timer(retry_wait * (k + 1)).timeout
		r = await call_api(b)
	if r.has("view") or r.get("replay", false) or not _transient(r):
		pend = {}
	return r


## tbSend: a move, and what follows from its answer (the view, the balance, a receipt, standing up)
func send(body: Dictionary, quiet: bool = false) -> Dictionary:
	if busy and not quiet:
		return {"error": "", "skipped": true}
	if not quiet:
		busy = true
	var r := await call_op(body)
	if not quiet:
		busy = false
	var e: String = str(r.error) if r.get("error") != null else ""
	if e != "" and not r.has("view"):
		message.emit(e)
		if e.contains("closed"):
			_gone("gone")
		return r
	var op: String = body.get("op", "")
	if r.get("view") is Dictionary:
		id = int(r.get("id", id))
		code = str(r.get("code", code))
		_set_balance(int(r.get("balance", balance)))
		if op == "leave" and int(r.view.get("me", -1)) < 0:
			_gone("left")   # stood up: the shards went home
		else:
			_take(r.view)
		message.emit(e)
	if r.get("rcpt") is Dictionary:
		receipt.emit(r.rcpt)
	if op == "leave" and r.get("view") is Dictionary:
		var vv: Dictionary = r.view
		if int(vv.get("me", -1)) < 0:
			pass
		elif vv.get("gone") is Array and int(vv.me) < vv.gone.size() and vv.gone[int(vv.me)]:   # craps: the Pass or Come bet stays and is rolled out
			var n: int = (vv.get("locked", []) as Array).size()
			var g: String = vv.get("game", "cr")
			var tid := id
			_gone("pending")
			mine = {"id": tid, "game": g, "pending": {"bets": n}}
	return r


func _set_balance(n: int) -> void:
	if n != balance:
		balance = n
		balance_changed.emit(n)


func _take(view: Dictionary) -> void:
	view["_t"] = now_ms()   # when this view arrived: the reveal and the review count from it
	if int(view.get("me", -1)) < 0:
		v = view
		_gone("gone")
		return
	v = view
	station = str(view.get("station", ""))
	updated.emit(view)


func _gone(kind: String) -> void:
	var was := id != 0
	id = 0
	v = {}
	station = ""
	if was or kind != "gone":
		left_table.emit(kind)


## walk up to a seat (tbSitAt): the server gives you that seat if it's free, else the next free one
func sit(room: String, game: String, seat: int, st: String = "", seed: String = "") -> Dictionary:
	var t0 := now_ms()
	while busy and now_ms() - t0 < 15000.0:   # a stand-up still on its way: sit once it's answered
		await get_tree().process_frame
	station = st
	var r := await send({"op": "sit", "room": room, "game": game, "seat": seat, "station": st, "seed": seed})
	return r


func state() -> Dictionary:
	if id == 0:
		return {}
	return await send({"op": "state", "id": id}, true)


func leave() -> Dictionary:
	if id == 0:
		return {}
	return await send({"op": "leave", "id": id})


func lobby() -> Dictionary:
	var r := await call_api({"op": "lobby"})
	if r.get("error"):
		message.emit(str(r.error))
		return r
	_set_balance(int(r.get("balance", balance)))
	mine = r.get("mine") if r.get("mine") is Dictionary else null
	return r


## Before sitting down, as the browser's TABLES page does on the way in: the lobby stands players up from tables left
## idle, rolls out craps bets left working, and says where you're still seated. A seat you can't walk back to (an older
## casino room, or another table while this game has you standing) is stood up from here, as that page's LEAVE does;
## its shards come home.
func free_old_seat(room_id: String, game: String, st: String) -> void:
	var r := await lobby()
	if r.get("error") or not (mine is Dictionary) or id != 0:
		return
	var m: Dictionary = mine
	if m.get("pending") != null or int(m.get("id", 0)) == 0:
		return   # craps bets still rolling out: the server says so when you sit
	if str(m.get("room", "")) == room_id and str(m.get("game", "")) == game and str(m.get("station", "")) == st:
		return   # that very seat: sitting takes you back to it
	var lr := await call_op({"op": "leave", "id": int(m.id)})
	if lr.get("balance") != null:
		_set_balance(int(lr.balance))
	mine = null


func history() -> Dictionary:
	var r := await call_api({"op": "history"})
	if not r.get("error"):
		hist = r.get("hands", []) if r.get("hands") is Array else []
	return r


## what's on a table you're standing next to (no hole cards); kept 6 s
func peek(room: String, game: String, st: String = "") -> Dictionary:
	var r := await call_api({"op": "peek", "room": room, "game": game, "station": st})
	if not r.get("error"):
		var pv = r.get("view")
		if pv is Dictionary:
			pv["_t"] = now_ms()
		peeks[game + ":" + st] = {"v": pv if pv is Dictionary else {}, "t": now_ms()}
	return r


## your own table if it's this game and station, else a recent peek (casView)
func view_of(game: String, st: String = "") -> Dictionary:
	if id != 0 and not v.is_empty() and v.get("game") == game and str(v.get("station", "")) == st:
		return v
	var pk = peeks.get(game + ":" + st)
	if pk is Dictionary and now_ms() - pk.t < 6000.0:
		return pk.v
	return {}


func _process(dt: float) -> void:
	if id == 0 or not polling or _poll_busy:
		return
	_poll_t += dt
	if _poll_t < 1.0:
		return
	_poll_t = 0.0
	_poll_busy = true
	await state()
	_poll_busy = false


# ---------------------------------------------------------------- the check (the browser's tbVerify, step for step)
# The same steps as the server (engine.js): SHA-256 of "seed:seeds joined by |:nonce" (first 48 hex) is the key; the random
# stream is SHA-256("key:0"), SHA-256("key:1"), ... read 32 bits at a time with rejection sampling; the deck is a
# Fisher-Yates shuffle with it. Hold'em cards: salt = SHA-256("seed:card:i") (32 hex), fingerprint = SHA-256("salt:card").

static func sha(s: String) -> String:
	return s.sha256_text()   # UTF-8 bytes, lowercase hex: the same as the browser's crypto.subtle digest


class FairRng:
	var key := ""
	var ctr := 0
	var buf: Array = []
	var pos := 0

	func _init(seed: String, seeds: Array, nonce: String) -> void:
		var ss := PackedStringArray()
		for x in seeds:
			ss.append(PalTables.js(x))
		key = PalTables.sha(seed + ":" + "|".join(ss) + ":" + nonce).substr(0, 48) + ":"

	func _next() -> int:
		if pos >= buf.size():
			var hx := PalTables.sha(key + str(ctr))
			ctr += 1
			buf = []
			for i in range(0, 64, 8):
				buf.append(hx.substr(i, 8).hex_to_int())
			pos = 0
		pos += 1
		return buf[pos - 1]

	## 0..n-1, every value exactly as likely (no modulo bias)
	func next(n: int) -> int:
		if n <= 1:
			return 0
		var lim := (4294967296 / n) * n
		while true:
			var x := _next()
			if x < lim:
				return x % n
		return 0


static func shuffle(n: int, r: FairRng) -> Array:
	var d: Array = range(n)
	for i in range(n - 1, 0, -1):
		var j := r.next(i + 1)
		var t = d[i]
		d[i] = d[j]
		d[j] = t
	return d


## a JSON value as JavaScript would put it in a string (numbers come back from JSON as floats here)
static func js(x) -> String:
	if x is float and x == floorf(x) and absf(x) < 1e15:
		return str(int(x))
	return str(x)


static func rl_name(n: int) -> String:
	if n == 37:
		return "00 GREEN"
	if n == 0:
		return "0 GREEN"
	return str(n) + (" RED" if RL_RED.has(n) else " BLACK")


static func _truthy(x) -> bool:
	return x != null and not (x is String and x == "") and not (x is bool and not x)


static func _int_eq(a, b) -> bool:
	return (a is float or a is int) and (b is float or b is int) and int(a) == int(b)


static func _same(a: Array, b) -> bool:
	if not (b is Array) or a.size() != b.size():
		return false
	for i in a.size():
		if not _int_eq(a[i], b[i]):
			return false
	return true


static func _shoe_hashes(seed: String, deck: Array) -> Array:
	var hs: Array = []
	for i in deck.size():
		hs.append(sha(sha(seed + ":card:" + str(i)).substr(0, 32) + ":" + js(deck[i])))
	return hs


## check one round: [ok (true / false / null: nothing to check), what was checked]
func verify(h: Dictionary, history_rows: Array = []) -> Array:
	var r: Dictionary = h.result if h.get("result") is Dictionary else {}
	var rows: Array = history_rows if not history_rows.is_empty() else hist
	if not _truthy(r.get("seeds")):
		return [null, "From before v0.10.0: checked by its deck fingerprint only."]
	var game: String = str(h.get("game", ""))
	if _truthy(h.get("seed")):
		var seed: String = str(h.seed)
		if sha(seed) != str(h.get("commit")):
			return [false, "The seed does not match the fingerprint shown before the round."]
		var rr := FairRng.new(seed, r.seeds, js(r.get("nonce")))
		if game == "rl":
			var n := rr.next(38)
			return [true, "The seed matches its fingerprint and the spin reruns to %s." % rl_name(n)] if _int_eq(n, r.get("number")) else [false, "The spin does not rerun to the same number."]
		# v0.10.3: each roll, spin and drop reruns from its own seed
		if game == "cr":
			var d := [1 + rr.next(6), 1 + rr.next(6)]
			return [true, "The seed matches its fingerprint and the roll reruns to %d and %d." % [d[0], d[1]]] if _same(d, r.get("dice")) else [false, "The roll does not rerun to the same dice."]
		if game == "sl":
			var st := [rr.next(20), rr.next(20), rr.next(20)]
			return [true, "The seed matches its fingerprint and the reels rerun to the same stops."] if _same(st, r.get("stops")) else [false, "The reels do not rerun to the same stops."]
		if game == "pk":
			var p: Array = []
			for i in 12:
				p.append(rr.next(2))
			return [true, "The seed matches its fingerprint and the ball reruns to pocket %d." % (int(r.get("pocket", 0)) + 1)] if _same(p, r.get("path")) else [false, "The path does not rerun."]
		if game == "ba":
			var d := shuffle(416, rr)
			if not _same(d, h.get("deck")):
				return [false, "The shoe does not rerun to the same cards."]
			var hs := _shoe_hashes(seed, d)
			return [true, "The seed matches its fingerprint, the whole shoe reruns card for card (%s dealt), and its card fingerprints build the root every hand was checked against." % js(r.get("dealt"))] if sha(",".join(PackedStringArray(hs))) == str(r.get("root")) else [false, "The shoe does not build its root."]
		var dk := shuffle(208 if game == "bj" else 52, rr)
		return [true, "The seed matches its fingerprint and the %s reruns card for card." % ("shoe" if game == "bj" else "deck")] if _same(dk, h.get("deck")) else [false, "The shuffle does not rerun to the same cards."]
	if game == "ba" and h.get("cards") is Array and _truthy(h.get("root")):   # a hand from a shoe: its cards against the shoe's fingerprints
		var no = r.shoe.get("no") if r.get("shoe") is Dictionary else null
		var end := {}
		for x in rows:
			if x is Dictionary and x.get("game") == "ba" and x.get("result") is Dictionary and _int_eq(x.result.get("shoeEnd"), no) and x.get("tid") == h.get("tid") and _truthy(x.get("seed")):
				end = x
				break
		var hashes: Array = []
		if not end.is_empty():
			hashes = _shoe_hashes(str(end.seed), end.deck)
		else:
			var p := await call_api({"op": "shoe", "id": h.get("tid"), "no": no})
			if p.get("hashes") is Array:
				hashes = p.hashes
			else:
				return [null, str(p.error) if p.get("error") else "The shoe isn't reachable right now."]
		if sha(",".join(PackedStringArray(hashes.map(func(x): return str(x))))) != str(h.root):
			return [false, "The shoe's card fingerprints do not build its root."]
		for c in h.cards:
			if sha(str(c[2]) + ":" + js(c[1])) != str(hashes[int(c[0])]):
				return [false, "A card does not match its fingerprint."]
		return [true, "The %d cards of this hand each match the fingerprint fixed when the shoe started (cards %s-%s of 416).%s" % [h.cards.size(), js(h.cards[0][0]), js(h.cards[-1][0]),
			" The shoe is finished: its own row reruns the whole shuffle." if not end.is_empty() else " The seed shows once the shoe is finished."]]
	if h.get("cards") is Array and h.get("cardHashes") is Array:
		if sha(",".join(PackedStringArray(h.cardHashes.map(func(x): return str(x))))) != str(h.get("root")):
			return [false, "The card fingerprints do not build the hand's root."]
		for c in h.cards:
			if sha(str(c[2]) + ":" + js(c[1])) != str(h.cardHashes[int(c[0])]):
				return [false, "A card does not match its fingerprint."]
		return [true, "The %d cards you saw each match their fingerprint, and all 52 build the root shown at the deal. The seed and the whole deck show in %d h." % [h.cards.size(), ceili(float(h.get("seedIn", 0)) / 36e5)]]
	return [null, "Nothing to check yet."]
