class_name UsNet
extends RefCounted
## THE UNDERSTRIP on the wire (yard-31), as 10h's network part and 21-online.js carry it, so a desktop and a browser
## can share a run either way round:
## - the start message's us: [seed, level, lives] (guests build the same tiles from the seed);
## - the snapshot's us array (usSnap / usApplySnap): the level, lives, lift and gate clocks, shrines, doors, chests,
##   drops, flares, loot, shop stock, vents, blast doors, the last cleared level, regions, the bosses' floor effects;
## - player rows: us (bits: juice, items, drinking, bled out, selected item) and usk (the kit: weapon, hand, perks, relic);
## - raider rows: el and est (an elite and its trick), ub (the Gatekeeper's shield 1, his pilot 2);
## - guests' requests: ud drink, ui interact, uu use an item, ub buy, uw swap weapon, ut take loot.

const DRINK := 0.8   # US.drink: how long a drink takes

static func r2(v: float) -> float:
	return roundf(v * 100.0) / 100.0

# ---------------------------------------------------------------- player rows

static func player_bits(p: Dictionary) -> int:
	var ui: Dictionary = p.get("ui", {})
	return (int(p.get("uj", 0)) & 7) | ((int(p.get("ujm", 0)) & 7) << 3) | ((int(ui.get("bar", 0)) & 3) << 6) | ((int(ui.get("flare", 0)) & 3) << 8) \
		| ((1 if p.get("ujT", 0.0) > 0 else 0) << 10) | ((1 if p.get("usDead", false) else 0) << 11) | ((1 if p.get("uSel", "bar") == "flare" else 0) << 12)

static func read_bits(p: Dictionary, v, mine: bool) -> void:
	if not (v is int or v is float):
		return
	var b := int(v)
	p.uj = b & 7
	p.ujm = (b >> 3) & 7
	p.ui = {"bar": (b >> 6) & 3, "flare": (b >> 8) & 3}
	if not ((b >> 10) & 1):
		p.ujT = 0.0
	elif not (p.get("ujT", 0.0) > 0):
		p.ujT = DRINK
	p.usDead = bool((b >> 11) & 1)
	if not mine:
		p.uSel = "flare" if (b >> 12) & 1 else "bar"

## usKitStr: weapon id.rarity.mods | hand | perks | relic
static func kit_str(p: Dictionary) -> String:
	var w = p.get("w2")
	var ws := ("%s.%s.%s" % [w.id, w.r, "+".join(w.get("mods", []))]) if w != null else ""
	return "%s|%d|%s|%s" % [ws, int(p.get("wSel", 0)), "+".join(p.get("uPerks", [])), str(p.get("uRelic", ""))]

static func kit_from(s, p: Dictionary, v) -> void:
	if not (v is String) or v == p.get("uKitS", ""):
		return
	p.uKitS = v
	var a: PackedStringArray = (v as String).split("|")
	while a.size() < 4:
		a.append("")
	var T: Dictionary = UsLoot.tables()
	if a[0] != "":
		var w := a[0].split(".")
		var id: String = w[0]
		var r: String = w[1] if w.size() > 1 else ""
		if T.weapons.has(id) and T.tier.has(r):
			var ms: Array = Array((w[2] if w.size() > 2 else "").split("+", false)).filter(func(m): return T.mods.has(m))
			if p.get("w2") == null or p.w2.id != id or p.w2.r != r:
				p.w2 = {"id": id, "r": r, "mods": ms, "ammo": 0, "res": 0}
			else:
				p.w2.mods = ms
	else:
		p.w2 = null
	p.wSel = 1 if a[1] == "1" and p.w2 != null else 0
	p.uPerks = Array(a[2].split("+", false)).filter(func(k): return T.perks.has(k) or k == "p_tiepin")
	p.uRelic = a[3] if T.relics.has(a[3]) else ""
	UsLoot.refit(s, p)

# ---------------------------------------------------------------- raider rows

static func enemy_extra(e: Dictionary) -> Array:
	var el := 0
	if str(e.get("elite", "")) == "charger":
		el = 1
	elif str(e.get("elite", "")) == "caller":
		el = 2
	return [el, int(e.get("est", 0)), int(e.get("ub", 0))]

static func enemy_read(e: Dictionary, el: int, est: int, ub: int) -> void:
	e.elite = "charger" if el == 1 else ("caller" if el == 2 else 0)
	e.est = est
	e.ub = ub
	e.pilot = bool(ub & 2)
	if e.pilot:
		e.gk2 = true

# ---------------------------------------------------------------- the snapshot

static func snap(s) -> Array:
	var U: Dictionary = s.game.us
	var lg: Array = U.log
	return [int(U.level), int(U.lives), r2(U.exitT), r2(U.lift), r2(U.wipe), int(U.gate), int(U.lit), int(U.opened), int(U.chests), 1 if U.floodOn else 0, 1 if U.bossDown else 0, int(U.rest.ix),
		U.drops.map(func(d): return [int(d.get("slot", 0)), r2(d.x), r2(d.y), int(d.sal)]),
		U.flares.map(func(f): return [r2(f.x), r2(f.y), r2(f.t), f.get("r", 4)]),
		U.get("left", []), int(U.get("done", 0)), int(U.bossStage),
		U.loot.map(func(l): return [l.n, r2(l.x), r2(l.y), l.kind, [l.w.id, l.w.r, l.w.get("mods", [])] if l.kind == "weapon" else (l.sal if l.kind == "salvage" else l.k)]),
		U.get("got", []), U.get("vents", []).map(func(v): return int(v.s)), U.get("blast", []),
		lg[lg.size() - 1] if not lg.is_empty() else null, int(U.get("regions", 0)),
		U.get("bfx", []).map(func(f): return [f.k, r2(f.x), r2(f.y), r2(f.get("a", 0.0)), r2(f.get("r", 0.0)), r2(f.t), r2(f.T), r2(f.get("warn", 0.0)),
			r2(f.get("x1", 0.0)), r2(f.get("y1", 0.0)), r2(f.get("half", 0.0)), 1 if f.get("tank", false) else 0])]

## the host's level first: a guest follows the lift down before the rest of the snapshot is read
static func follow_level(s, a) -> void:
	if not (a is Array) or a.is_empty() or not s.game.has("us"):
		return
	var lv := int(a[0])
	if lv > int(s.game.us.level) and lv < 10:
		s.us.change_level(lv, true)

static func apply(s, a) -> void:
	if not (a is Array) or a.size() < 12 or not s.game.has("us"):
		return
	var U: Dictionary = s.game.us
	follow_level(s, a)
	U.lives = int(a[1])
	U.exitT = float(a[2])
	U.lift = float(a[3])
	U.wipe = float(a[4])
	U.gate = int(a[5])
	U.lit = int(a[6])
	U.opened = int(a[7])
	U.chests = int(a[8])
	U.floodOn = a[9] != 0
	s.flood_on = U.floodOn
	U.bossDown = a[10] != 0
	U.rest = {"x": U.rest.get("x", 0.0), "y": U.rest.get("y", 0.0), "ix": int(a[11])}
	var at := func(i: int, d = null): return a[i] if a.size() > i and a[i] != null else d
	var slot_id := func(sl: int) -> String:
		for p in s.players.values():
			if int(p.get("slot", 0)) == sl:
				return str(p.id)
		return ""
	U.drops = (at.call(12, []) as Array).map(func(d): return {"id": slot_id.call(int(d[0])), "slot": int(d[0]), "x": float(d[1]), "y": float(d[2]), "sal": int(d[3])})
	U.flares = (at.call(13, []) as Array).map(func(f): return {"x": float(f[0]), "y": float(f[1]), "t": float(f[2]), "r": float(f[3]) if f.size() > 3 else 4.0})
	if at.call(14) is Array:
		U.left = a[14]
	U.done = int(at.call(15, 0))
	U.bossStage = int(at.call(16, 0))
	var T: Dictionary = UsLoot.tables()
	var loot: Array = []
	for l in at.call(17, []):
		var o := {"n": int(l[0]), "x": float(l[1]), "y": float(l[2]), "kind": str(l[3])}
		var v = l[4] if l.size() > 4 else null
		if o.kind == "weapon":
			if not (v is Array) or not T.weapons.has(str(v[0])):
				continue
			o.w = {"id": str(v[0]), "r": str(v[1]), "mods": v[2] if v.size() > 2 and v[2] is Array else []}
		elif o.kind == "salvage":
			o.sal = int(v)
		else:
			o.k = str(v)
		loot.append(o)
	U.loot = loot
	if at.call(18) is Array:
		U.got = a[18]
	if at.call(19) is Array:
		if not U.has("vents"):
			UsDeep.haz_start(U, s.lay)
		for n in a[19].size():
			if n < U.vents.size():
				U.vents[n].s = int(a[19][n])
	if at.call(20) is Array:
		if not U.has("blast"):
			UsDeep.haz_start(U, s.lay)
		for n in a[20].size():
			if n < U.blast.size() and int(a[20][n]) != int(U.blast[n]):
				guest_blast(s, n, int(a[20][n]))
	var last = at.call(21)
	if last is Array and not (not U.log.is_empty() and U.log[U.log.size() - 1][0] == last[0]):
		U.log.append(last)
	U.regions = int(at.call(22, 0))
	if at.call(23) is Array:
		U.bfx = a[23].map(func(f): return {"k": str(f[0]), "x": float(f[1]), "y": float(f[2]), "a": float(f[3]), "r": float(f[4]), "t": float(f[5]), "T": float(f[6]),
			"warn": float(f[7]), "x1": float(f[8]), "y1": float(f[9]), "half": float(f[10]), "tank": f[11] != 0, "went": float(f[5]) >= float(f[7])})

## a guest's copy of a blast door: the tiles only (the host hurts and shoves)
static func guest_blast(s, n: int, st: int) -> void:
	var U: Dictionary = s.game.us
	var was: int = U.blast[n]
	U.blast[n] = st
	if (was == 2) == (st == 2) or n >= s.lay.blast.size():
		return
	for t in s.lay.blast[n].tiles:
		s.terr[s.idx(t[0], t[1])] = PalMaps.T_SHUT if st == 2 else PalMaps.T_GROUND
	s.mark_flow()

# ---------------------------------------------------------------- guests' requests, on the host

static func host_data(s, p: Dictionary, d: Dictionary) -> void:
	var I := func(v, lo: int, hi: int) -> bool: return (v is int or v is float) and float(v) == floorf(float(v)) and int(v) >= lo and int(v) <= hi
	match str(d.get("t", "")):
		"uw":
			if I.call(d.get("to"), 0, 1):
				UsLoot.swap(s, p, int(d.to))
		"ut":
			if I.call(d.get("n"), 0, 1000000):
				s.us.take_loot(p, int(d.n))
		"ud":
			s.us.drink(p)
		"ui":
			s.us.interact(p)
		"uu":
			if str(d.get("k", "")) in ["bar", "flare"] and I.call(d.get("i"), 0, s.N - 1) and I.call(d.get("j"), 0, s.N - 1):
				s.us.use_item_at(p, str(d.k), int(d.i), int(d.j))
		"ub":
			if I.call(d.get("m"), 0, 8) and I.call(d.get("s"), 0, 8):
				s.us.buy(p, int(d.m), int(d.s))
