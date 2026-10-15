class_name PalLocker
extends RefCounted
## The locker (18-cosmetics.js): what you own and wear, cases and shards, milestone counters, and the rules that pay a
## run out. It follows the browser's no-account locker (localRun, the same rules as the server, minus the cloud);
## the catalog comes from data/cosmetics.json, pulled from the browser build by tools/cos_extract.js.

const PATH := "user://locker.json"
const SAL_SHARD := {"rate": 20, "perRaid": 2, "max": 10}
const BLITZ_EVAC := {"cases": 1, "shards": 25}
const GAUNTLET_PAY := {"shards": [5, 10], "waveCase": 1, "evacCases": 2, "evacShards": 25, "chapterCase": 1}
const BO_PAY := {"winCases": 2, "winShards": 25, "destShards": 40, "minWin": 420}
const SP_CASE := 3
const CATN := {"skin": "SKIN", "hat": "HEADGEAR", "trail": "TRACER", "fx": "KILL FX", "bg": "BACKGROUND"}
const DEFAULT_COS := {"skin": "std", "hat": "class", "trail": "std", "fx": "none"}
const BOSS_BOX := {"butcher": "halloween", "ferryman": "halloween", "harbinger": "blitz", "bluebutcher": "blitz", "arsonist": "blitz", "tempest": "blitz", "bulldozer": "blitz",
	"rime": "winter", "whitebutcher": "winter", "whiteferryman": "winter", "whiteforeman": "winter"}
const BOSS_CASES := {"harbinger": 2, "bluebutcher": 2, "arsonist": 2, "tempest": 2, "bulldozer": 2, "rime": 2, "whitebutcher": 1, "whiteferryman": 1, "whiteforeman": 1}

static var CAT: Dictionary = {}   # the catalog (cosmetics.json)
static var BY: Dictionary = {}   # item id -> item

var profile: PalProfile   # skill points live in the profile (they also buy Supply Cases here)
var persist := true
var rng := RandomNumberGenerator.new()
var fixed_r := -1.0   # tests: every roll returns this (the browser's Math.random stubbed the same way)
var owned: Array = []
var eq := {}
var cases := 1   # one welcome case
var bag := {}
var shards := 0
var prog := 0
var st := {}


static func catalog() -> Dictionary:
	if CAT.is_empty():
		CAT = JSON.parse_string(FileAccess.get_file_as_string("res://data/cosmetics.json"))
		for c in CAT.COS:
			BY[c.id] = c
	return CAT


static func item(id: String) -> Dictionary:
	catalog()
	return BY.get(id, {})


func _init(prof: PalProfile = null) -> void:
	profile = prof
	catalog()
	rng.randomize()
	norm({})


## normLocker: free items always owned, unknown items kept, equipment only what's owned
func norm(L: Dictionary) -> void:
	var free: Array = CAT.COS.filter(func(c): return c.src == "free").map(func(c): return c.id)
	owned = []
	for id in L.get("owned", free):
		if id is String and id.length() < 40 and not owned.has(id):
			owned.append(id)
	for id in free:
		if not owned.has(id):
			owned.append(id)
	st = {"raids": 0, "wins": 0, "drops": 0, "endless": 0, "hardWins": 0}
	for k in L.get("st", {}):
		st[k] = int(L.st[k])
	cases = maxi(0, int(L.get("cases", 1)))
	shards = maxi(0, int(L.get("shards", 0)))
	prog = maxi(0, int(L.get("prog", 0)))
	bag = {}
	for k in L.get("bag", {}):
		if k != "supply":
			bag[k] = maxi(0, int(L.bag[k]))
	var e: Dictionary = L.get("eq", {})
	eq = DEFAULT_COS.duplicate()
	for k in DEFAULT_COS:
		if e.has(k) and owned.has(k + ":" + str(e[k])):
			eq[k] = e[k]
	var bg: String = e.get("bg", "campfire")
	eq.bg = bg if owned.has("bg:" + bg) else "campfire"


func load_file() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if d is Dictionary:
		norm(d)


func save() -> void:
	if not persist:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"owned": owned, "eq": eq, "cases": cases, "bag": bag, "shards": shards, "prog": prog, "st": st}))


func _r() -> float:
	return fixed_r if fixed_r >= 0 else rng.randf()


func owns(id: String) -> bool:
	return owned.has(id)


func grant(id: String) -> bool:
	if not BY.has(id) or owns(id):
		return false
	owned.append(id)
	return true


func equip(id: String) -> bool:
	var c := item(id)
	if c.is_empty() or not owns(id):
		return false
	eq[c.cat] = c.key
	save()
	return true


func meets(need: Dictionary) -> bool:
	for k in need:
		if int(st.get(k, 0)) < int(need[k]):
			return false
	return true


func check_unlocks() -> Array:
	var got: Array = []
	for c in CAT.COS:
		if c.src == "unlock" and not owns(c.id) and c.need != null and meets(c.need):
			grant(c.id)
			got.append(c)
	return got


func case_count(id: String) -> int:
	return cases if id == "supply" else int(bag.get(id, 0))


func case_add(id: String, n: int) -> void:
	if id == "supply":
		cases = maxi(0, cases + n)
	else:
		bag[id] = maxi(0, int(bag.get(id, 0)) + n)


func all_cases() -> int:
	var n := 0
	for id in CAT.CASES:
		n += case_count(id)
	return n


## rollCase: rarest first against the case's weights, then any item of that rarity from that case's own pool
func roll_case(id: String = "supply") -> Dictionary:
	var C: Dictionary = CAT.CASES.get(id, CAT.CASES.supply)
	var W: Array = []
	for k in C.weights:
		W.append([k, float(C.weights[k])])
	W.sort_custom(func(a, b): return a[1] < b[1])
	var tot := 0.0
	for w in W:
		tot += w[1]
	var x := _r() * tot
	var want := "c"
	for w in W:
		if x < w[1]:
			want = w[0]
			break
		x -= w[1]
	var pool: Array = CAT.COS.filter(func(c): return c.get("box") == id and c.r == want)
	if pool.is_empty():
		pool = CAT.COS.filter(func(c): return c.get("box") == id and c.r == "c")
	return pool[floori(_r() * pool.size())]


## openCase: a duplicate turns into shards by its rarity
func open_case(id: String = "supply") -> Dictionary:
	if case_count(id) < 1:
		return {}
	case_add(id, -1)
	var it := roll_case(id)
	var dup := owns(it.id)
	if dup:
		shards += int(CAT.RAR[it.r].sh)
	else:
		grant(it.id)
	save()
	return {"it": it, "dup": dup, "box": id}


func buy_case(id: String) -> bool:
	var C: Dictionary = CAT.CASES.get(id, {})
	if C.is_empty() or C.get("cost") == null or shards < int(C.cost):
		return false
	shards -= int(C.cost)
	case_add(id, 1)
	save()
	return true


## 3 unspent skill points buy a Supply Case (points traded here never come back on a reset)
func buy_case_sp() -> bool:
	if profile == null or profile.sp < SP_CASE:
		return false
	profile.sp -= SP_CASE
	profile.save()
	case_add("supply", 1)
	save()
	return true


# ---------------------------------------------------------------- paying out a run

static func mod_bonus(list: Array, mode: String) -> int:
	var b := 0
	for id in Sim.clean_mods(list, mode):
		for M in Sim.MODS:
			if M.id == id:
				b += int(M.bonus)
	return clampi(b, -15, 75)


static func salvage_shards(sal: int, held: int) -> int:
	return maxi(0, mini(mini(floori(maxf(0, sal) / SAL_SHARD.rate), SAL_SHARD.perRaid * maxi(0, held)), SAL_SHARD.max))


static func boss_base(k: String) -> String:
	return Sim.boss_def(k).get("base", k)


static func boss_box(k: String) -> String:
	return BOSS_BOX.get(k, "afterglow")


## which of the bosses that went down this claim counts (the same cap the server uses)
static func boss_counted(keys: Array, held: int, from: int, waves: float, size: String) -> Array:
	if waves == Sim.CAMPAIGN.waves:
		var hi := mini(13, held + 1)
		var out: Array = []
		for k in keys:
			var w: int = (Sim.CAMPAIGN.bosses.find(k) + 1) * 3
			if Sim.CAMPAIGN.bosses.has(k) and w > from and w <= hi and not out.has(k):
				out.append(k)
		return out
	var hi2: float = minf(held + 1, waves if not is_inf(waves) else 1e9)
	var cap: int = maxi(0, floori(hi2 / 5) - from / 5) * (2 if size == "xl" else 1)
	var out2: Array = []
	for k in keys:
		if out2.size() >= cap:
			break
		out2.append(k)
	return out2


static func boss_drops(keys: Array, held: int, from: int, waves: float, size: String) -> Dictionary:
	var out := {}
	for k in boss_counted(keys, held, from, waves, size):
		var box := boss_box(k)
		out[box] = int(out.get(box, 0)) + BOSS_CASES.get(k, 1)
	return out


func boss_milestone(k: String, mode: String = "") -> void:
	var b := "boss_" + boss_base(k)
	st[b] = int(st.get(b, 0)) + 1
	var B := Sim.boss_def(k)
	if B.has("base") and not B.get("campaign", false) and mode != "campaign":
		st.mode_blitz_bosses = int(st.get("mode_blitz_bosses", 0)) + 1


static func chapter_credit(from: int, to: int) -> Dictionary:
	var out := {"yard": 0, "river": 0, "quarry": 0, "frost": 0}
	for w in range(from + 1, mini(13, to) + 1):
		out[Sim.CAMPAIGN.maps[mini(3, maxi(0, w - 1) / 3)]] += 1
	return out


func add_milestones(keys: Array, held: int, from: int, mine: int, cls: String, map: String, waves: float, size: String) -> void:
	for k in boss_counted(keys, held, from, waves, size):
		boss_milestone(k, "campaign" if waves == Sim.CAMPAIGN.waves else "")
	if mine > 0:
		if waves == Sim.CAMPAIGN.waves:
			var cr := chapter_credit(from, held)
			for mp in cr:
				st["map_" + mp] = int(st.get("map_" + mp, 0)) + cr[mp]
		elif PalMaps.MAP_IDS.has(map):
			st["map_" + map] = int(st.get("map_" + map, 0)) + mine
		if Pal.CLASSES.has(cls):
			st["cls_" + cls + "_raids"] = int(st.get("cls_" + cls + "_raids", 0)) + mine


## runClaim: this run's facts, read off the sim when it ends
static func run_claim(s: Sim) -> Dictionary:
	var g: Dictionary = s.game
	var p: Dictionary = s.player
	var held: int = s.bo_stages() if s.blackout() else (int(g.waves) if g.won else (g.wave if g.end_reason == "evacfail" else maxi(0, g.wave - 1)))
	var res := ""
	if s.blitz() and not (g.fb != null and g.fb.get("mapEvac", false)):
		res = "evac" if p.get("out", false) else ("left" if g.end_reason == "left" else "")
	var win: bool = g.won
	if res != "":
		held = s.final_wave()
		win = res == "evac"
	var c := {"mode": g.mode, "diff": g.diff, "win": win, "held": held, "raid_from": 0, "raid_to": held, "kills": p.kills, "boss_keys": g.bossLog.slice(0, 40),
		"shard_bosses": g.sbN, "sb_keys": g.sbLog.slice(0, 40), "fb_keys": g.fbLog.slice(0, 20), "salvage": maxi(0, p.sal), "size": g.size, "duration_s": roundi(g.time),
		"mods": s.mods, "map": g.map, "cls": p.cls, "evac": res, "cv": 4, "g_cleared": 0, "ch_evac": []}
	if s.blackout():
		var B = g.bo
		c.cv = 5
		c.boss_keys = []
		c.pois_held = B.held if B != null else 0
		var lostM := s.cores.filter(func(k): return k.has("poi") and k.poi.major and k.lost).size()
		c.pois_major = maxi(0, maxi(0, (B.held + B.lost if B != null else 0) - 4) - lostM)
		c.destroyer = B != null and B.destroyer
	if s.campaign():
		var gk: Array = g.get("gKill", [])
		c.g_cleared = gk.filter(func(n): return n >= Sim.GAUNTLET.rimes + 1).size()
		var ce: Array = p.get("chEvac", [])
		c.ch_evac = [0, 1, 2].map(func(i): return null if i >= ce.size() else ce[i] == 1)
	return c


func _bo_local_pay(c: Dictionary) -> Dictionary:
	var pois := mini(mini(8, int(c.pois_held)), mini(int(c.held), maxi(0, 1 + floori((int(c.duration_s) - 45) / 30.0))))
	var major := mini(mini(4, int(c.pois_major)), pois)
	var won: bool = c.win and int(c.raid_to) >= 9 and int(c.raid_from) * 2 <= 9 and int(c.duration_s) >= BO_PAY.minWin
	var dest: bool = won and c.destroyer
	st.bo_pois = int(st.get("bo_pois", 0)) + pois
	if won:
		st.bo_wins = int(st.get("bo_wins", 0)) + 1
		if pois >= 8:
			st.bo_perfect = int(st.get("bo_perfect", 0)) + 1
	if dest:
		st.bo_dest = int(st.get("bo_dest", 0)) + 1
	return {"pois": pois, "major": major, "won": won, "dest": dest, "cases": major + (BO_PAY.winCases if won else 0), "shards": (BO_PAY.winShards if won else 0) + (BO_PAY.destShards if dest else 0), "sp": 1 if dest else 0}


static func _fb_cap(c: Dictionary) -> int:
	if int(c.raid_to) < (Sim.CAMPAIGN.waves if c.mode == "campaign" else Sim.BLITZ.waves):
		return 0
	if c.mode == "campaign" and int(c.cv) >= 4:
		return Sim.GAUNTLET.waves * (Sim.GAUNTLET.rimes + 1)
	return Sim.BLITZ.maxDT if c.mods.has("blitzclock") else Sim.BLITZ.max


## the reward for a finished run (lockerReward + localRun): converts leftover salvage to shards, pays cases, drops,
## milestones and skill points, and returns the reward data the end screen shows
func pay_run(s: Sim) -> Dictionary:
	var c := run_claim(s)
	var pct := mod_bonus(c.mods, "blitz" if c.mode == "blitz" else "")
	var sh := mini(salvage_shards(c.salvage, c.held), floori(SAL_SHARD.max * (100 + pct) / 100.0))
	if sh > 0:
		s.player.sal -= sh * SAL_SHARD.rate   # what converts is spent, so it can't count twice
	return local_run(c, sh)


func local_run(c: Dictionary, sal_shards: int) -> Dictionary:
	var held: int = c.raid_to
	var from: int = c.raid_from
	var mine: int = c.held
	var BO: bool = c.mode == "blackout"
	var keys: Array = [] if BO else c.boss_keys
	var sb: int = 0 if BO else int(c.shard_bosses)
	var BZ: bool = c.mode == "blitz" or c.mode == "campaign"
	var b0 := {"bag": bag.duplicate(), "cases": cases, "shards": shards}
	var waves: float = INF if c.mode == "endless" else (float(Sim.CAMPAIGN.waves) if c.mode == "campaign" else (float(Sim.BLITZ.waves) if BZ else (9.0 if BO else float(c.mode))))
	var pct := mod_bonus(c.mods, "blitz" if c.mode == "blitz" else "")
	var bo := _bo_local_pay(c) if BO else {}
	var won: bool = bo.won if BO else (c.win and from * 2 <= waves and (not BZ or c.evac == "evac"))
	var drops := boss_drops(keys, held, from, waves, c.size)
	var bshards := 0
	for i in sb:
		bshards += 15 + floori(_r() * 16)
	shards += sal_shards + bshards
	st.raids += mine
	st.drops += int(c.kills)
	if won:
		st.wins += 1
		if c.diff == "hard":
			st.hardWins += 1
	if c.mode == "endless":
		st.endless = maxi(st.endless, held)
	prog += floori((bo.pois if BO else mine) * (100 + pct) / 100.0)
	cases += prog / 3
	prog = prog % 3
	if BO:
		cases += bo.cases
		shards += bo.shards
	elif won:
		cases += 2 if waves >= 10 else 1
	if c.mode == "endless":
		cases += mine / 5
	for id in drops:
		case_add(id, drops[id])
	add_milestones(keys, held, from, mine, c.cls, c.map, waves, c.size)
	var sp_prog: int = profile.sp_prog if profile != null else 0
	var sp_gain: int = (sp_prog + mine) / 5 + boss_counted(keys, held, from, waves, c.size).size() + sb + (bo.sp if BO else 0)
	for k in c.sb_keys.slice(0, sb):   # every in-between boss kill counts toward the boss milestones
		st["boss_" + k] = int(st.get("boss_" + k, 0)) + 1
	var fshards := 0
	if BZ:   # Final Blitz bosses, the evacuation bonus, then halving
		var fk: Array = c.fb_keys.filter(func(k): return Sim.boss_def(k).has("base") or k == "rime").slice(0, _fb_cap(c))
		if c.mode == "campaign" and int(c.cv) >= 4:
			var G := GAUNTLET_PAY
			for k in fk:
				fshards += G.shards[0] + floori(_r() * (G.shards[1] - G.shards[0] + 1))
				boss_milestone(k, c.mode)
			case_add("winter", G.waveCase * mini(mini(Sim.GAUNTLET.waves, int(c.g_cleared)), fk.size() / (Sim.GAUNTLET.rimes + 1)))
			if won:
				case_add("winter", G.evacCases)
				fshards += G.evacShards
			case_add("winter", G.chapterCase * c.ch_evac.slice(0, 3).filter(func(r): return r == true).size())
		else:
			for k in fk:
				case_add(boss_box(k), BOSS_CASES.get(k, 2))
				fshards += 15 + floori(_r() * 16)
				boss_milestone(k, c.mode)
			if won:
				case_add("winter" if c.mode == "campaign" else "blitz", BLITZ_EVAC.cases)
				fshards += BLITZ_EVAC.shards
		sp_gain += fk.size()
		shards += fshards
	if profile != null:   # the profile keeps the 1-per-5-raids counter
		profile.sp_prog = (sp_prog + mine) % 5
		profile.sp += sp_gain
		profile.sp_total += sp_gain
		profile.save()
	if won and _r() < float(CAT.CASES.flags.drop.win):   # the Flag Case's chance after any win
		case_add("flags", 1)
	if won and int(c.cv) >= 4:   # one Hybrid Theory Case for every co-op win
		case_add("hybrid", 1)
	var left: bool = BZ and c.evac == "left"
	if left:   # left behind: half this run's cases and shards, odd counts rounded up first
		cases -= (cases - b0.cases) / 2
		for id in bag:
			bag[id] -= (int(bag[id]) - int(b0.bag.get(id, 0))) / 2
		shards -= (shards - b0.shards) / 2
	var got_cases := {"supply": cases - b0.cases}
	for id in bag:
		var d: int = int(bag[id]) - int(b0.bag.get(id, 0))
		if d > 0:
			got_cases[id] = d
	var got := check_unlocks()
	save()
	var all_shards: int = shards - b0.shards
	var R := {"kind": "run", "cases": got_cases, "shards": all_shards, "bossShards": mini(all_shards, bshards + fshards + (bo.shards if BO else 0)), "sp": sp_gain,
		"unlocked": got.map(func(x): return x.id), "left": left, "blitzShards": BZ or BO, "pois": bo.pois if BO else -1, "toNext": 3 - prog, "prog": prog}
	R.text = reward_text(R)
	return R


func reward_text(R: Dictionary) -> String:
	var bits: Array = []
	var pl := func(n: int, w: String) -> String: return "%d %s%s" % [n, w, "" if n == 1 else "s"]
	if R.left:
		bits.append("Left behind: half your cases and shards")
	if R.cases.get("supply", 0) > 0:
		bits.append("+" + pl.call(R.cases.supply, "supply case"))
	for id in R.cases:
		if id != "supply" and R.cases[id] > 0 and CAT.CASES.has(id):
			var C: Dictionary = CAT.CASES[id]
			bits.append("+%d %s%s %s" % [R.cases[id], C.name.to_lower(), "s" if R.cases[id] > 1 else "", "for the win" if C.has("drop") and C.drop.has("win") else "from bosses"])
	if R.bossShards > 0:
		bits.append("+%s from %s" % [pl.call(R.bossShards, "shard"), "the win and the Destroyer" if R.pois >= 0 else ("bosses and the evac" if R.blitzShards else "in-between bosses")])
	if R.shards - R.bossShards > 0:
		bits.append("+%s from leftover salvage" % pl.call(R.shards - R.bossShards, "shard"))
	if R.sp > 0:
		bits.append("+" + pl.call(R.sp, "skill point"))
	if R.pois >= 0:
		bits.append("%s held · %s to the next supply case" % [pl.call(R.pois, "point"), pl.call(R.toNext, "more point")])
	else:
		bits.append("%s to the next supply case" % pl.call(R.toNext, "more raid"))
	if not R.unlocked.is_empty():
		bits.append("Unlocked " + ", ".join(R.unlocked.map(func(id): return item(id).get("name", id))))
	return " · ".join(bits) + "."
