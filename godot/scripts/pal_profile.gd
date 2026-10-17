class_name PalProfile
extends RefCounted
## The skill tree (01b-mods-skills.js) and the points that buy it.
## The browser keeps this on the player's account and the server awards the points; until accounts are ported the
## Godot build keeps a local profile in user://profile.json and awards points by the server's own rule
## (claim_match_reward: one point per 5 raids held, carried over between runs, plus one per boss dropped).

const PATH := "user://profile.json"
const SKILLS := [
	{"id": "dmg", "br": "WEAPON", "name": "HOT LOADS", "what": "+4% bullet damage", "max": 3, "cost": [1, 2, 3]},
	{"id": "rate", "br": "WEAPON", "name": "QUICK HANDS", "what": "+4% fire rate", "max": 3, "cost": [1, 2, 3]},
	{"id": "reload", "br": "WEAPON", "name": "SPEED LOADER", "what": "12% faster reloads and grenade cooldown", "max": 2, "cost": [1, 2]},
	{"id": "range", "br": "WEAPON", "name": "LONG BARREL", "what": "+6% range", "max": 2, "cost": [1, 2]},
	{"id": "hp", "br": "HEALTH", "name": "TOUGH HIDE", "what": "+6% max health", "max": 3, "cost": [1, 2, 3]},
	{"id": "regen", "br": "HEALTH", "name": "SECOND WIND", "what": "Out of a fight, you start healing sooner and heal faster", "max": 2, "cost": [2, 3]},
	{"id": "revive", "br": "HEALTH", "name": "BACK ON YOUR FEET", "what": "Revive teammates and get revived 25% faster", "max": 2, "cost": [1, 2]},
	{"id": "speed", "br": "MOVEMENT", "name": "LIGHT BOOTS", "what": "+3% move speed", "max": 3, "cost": [1, 2, 3]},
	{"id": "vest", "br": "MOVEMENT", "name": "KEVLAR", "what": "4% less damage taken", "max": 2, "cost": [2, 3]},
	{"id": "haul", "br": "MOVEMENT", "name": "PACK MULE", "what": "Gather 10% faster and carry 8 more of each material", "max": 2, "cost": [1, 2]},
	{"id": "rockets", "br": "SOLDIER", "cls": "soldier", "name": "BANDOLIER", "what": "+1 rocket", "max": 3, "cost": [1, 2, 3]},
	{"id": "pouch", "br": "GRENADIER", "cls": "grenadier", "name": "EXTRA POUCH", "what": "+1 grenade", "max": 2, "cost": [2, 3]},
	{"id": "molotov", "br": "GRENADIER", "cls": "grenadier", "name": "MOLOTOVS", "what": "Grenades leave burning ground that hurts raiders.", "max": 1, "cost": [3], "req": ["pouch", 1]},
	{"id": "ghillie", "br": "SNIPER", "cls": "sniper", "name": "GHILLIE SUIT", "what": "+3 s of stealth", "max": 2, "cost": [1, 2]},
	{"id": "stride", "br": "QUARTERMASTER", "cls": "quartermaster", "name": "LONG STRIDE", "what": "+0.6 s of sprint and 1 s less recharge", "max": 2, "cost": [1, 2]},
	{"id": "ammo_ap", "br": "SPECIAL AMMO", "name": "ARMOR PIERCING", "what": "More damage through riot shields.", "max": 4, "cost": [1, 2, 3, 4], "gate": [5, 10, 15, 20]},
	{"id": "ammo_fire", "br": "SPECIAL AMMO", "name": "INCENDIARY", "what": "Longer 10 HP/s burn.", "max": 4, "cost": [1, 2, 3, 4], "gate": [5, 10, 15, 20]},
	{"id": "ammo_blast", "br": "SPECIAL AMMO", "name": "EXPLOSIVE", "what": "Stronger small blasts.", "max": 4, "cost": [1, 2, 3, 4], "gate": [5, 10, 15, 20]},
	{"id": "ammo_shock", "br": "SPECIAL AMMO", "name": "LIGHTNING", "what": "Stronger slow within 3 blocks.", "max": 4, "cost": [1, 2, 3, 4], "gate": [5, 10, 15, 20]},
]

var sp := 0          # points to spend
var sp_total := 0    # lifetime points earned (the ammo tiers' gates)
var sp_prog := 0     # raids held toward the next point (0-4)
var skills := {}     # id -> level
var mol_off := false   # Molotovs switched off (the browser's 'm' on the skill string)
var persist := true  # tests switch this off so they never touch a real profile
var cloud := false   # the skill tree is the account's: points come from the server, buying goes through it


## an account's locker brought the skill tree (sp, sp_prog, sp_total, skills); {} when signed out
func from_cloud(j: Dictionary) -> void:
	cloud = not j.is_empty()
	sp = maxi(0, int(j.get("sp", 0)))
	sp_prog = maxi(0, int(j.get("sp_prog", 0)))
	sp_total = maxi(0, int(j.get("sp_total", 0)))
	skills = {}
	var t: Dictionary = j.get("skills") if j.get("skills") is Dictionary else {}
	for S in SKILLS:
		if int(t.get(S.id, 0)) > 0:
			skills[S.id] = mini(S.max, int(t[S.id]))
	save()


static func skill_by(id: String) -> Dictionary:
	for S in SKILLS:
		if S.id == id:
			return S
	return {}


func level(id: String) -> int:
	return int(skills.get(id, 0))


## why the next level of a node can't be bought, or "" when it can
func block_reason(id: String) -> String:
	var S := skill_by(id)
	var lv := level(id)
	if lv >= S.max:
		return "MAXED"
	if S.has("req") and level(S.req[0]) < S.req[1]:
		return "Needs " + skill_by(S.req[0]).name
	if S.has("gate") and sp_total < S.gate[lv]:
		return "%d lifetime SP" % S.gate[lv]
	if sp < S.cost[lv]:
		return "%d SP" % S.cost[lv]
	return ""


func buy(id: String) -> bool:
	if block_reason(id) != "":
		return false
	var S := skill_by(id)
	var lv := level(id)
	sp -= S.cost[lv]
	skills[id] = lv + 1
	save()
	return true


## every spent point back (the browser charges 40 shards for this; shards come with the account port)
func respec() -> void:
	var spent := 0
	for S in SKILLS:
		for l in mini(level(S.id), S.max):
			spent += S.cost[l]
	sp += spent
	skills = {}
	save()


## claim_match_reward: points for the raids held this run (carried in fives) and one per boss
func award_run(held: int, bosses: int) -> int:
	sp_prog += maxi(0, held)
	var got := sp_prog / 5 + maxi(0, bosses)
	sp_prog = sp_prog % 5
	sp += got
	sp_total += got
	save()
	return got


## perkMods (01b-mods-skills.js) for this profile's tree
func perk_mods(pvp: bool = false) -> Dictionary:
	var t := skills.duplicate()
	t.molOff = mol_off
	return perk_from(t, pvp)


## the tree as the browser's skill string (one digit per node, then 'm' with Molotovs off); "" with no account,
## as the browser sends: a guest's perks only count once the host has checked them against the account
func skill_str_mine() -> String:
	return skill_str(skills, mol_off) if cloud else ""


static func skill_str(t: Dictionary, molOff: bool = false) -> String:
	var s := ""
	for S in SKILLS:
		s += str(clampi(int(t.get(S.id, 0)), 0, S.max))
	return s + ("m" if molOff else "")


static func parse_skills(s) -> Dictionary:
	var t := {}
	var str_v := str(s) if s != null else ""
	for i in SKILLS.size():
		var S: Dictionary = SKILLS[i]
		var v := int(str_v[i]) if i < str_v.length() and str_v[i].is_valid_int() else 0
		if v > 0:
			t[S.id] = mini(v, S.max)
	for S in SKILLS:
		if S.has("req") and int(t.get(S.req[0], 0)) < S.req[1]:
			t.erase(S.id)
	t.molOff = str_v.substr(15).contains("m")   # old 15-node strings put the Molotov toggle at index 15
	return t


## pvp: stat perks at half, class nodes and special ammo off
static func perk_from(t: Dictionary, pvp: bool = false) -> Dictionary:
	var k := 0.5 if pvp else 1.0
	var L := func(id: String) -> int: return int(t.get(id, 0))
	var A := func(id: String) -> int: return 0 if pvp else int(t.get(id, 0))
	return {"dmg": 1 + 0.04 * L.call("dmg") * k, "rate": 1 + 0.04 * L.call("rate") * k, "reload": 1 - 0.12 * L.call("reload") * k, "range": 1 + 0.06 * L.call("range") * k,
		"hp": 1 + 0.06 * L.call("hp") * k, "regenAfter": 4 - 0.75 * L.call("regen") * k, "regen": 4 + 2 * L.call("regen") * k, "revive": 1 + 0.25 * L.call("revive") * k,
		"speed": 1 + 0.03 * L.call("speed") * k, "vest": 1 - 0.04 * L.call("vest") * k, "gather": 1 - 0.1 * L.call("haul") * k, "carry": roundi(8 * L.call("haul") * k),
		"rockets": A.call("rockets"), "pouch": A.call("pouch"), "molotov": A.call("molotov") > 0 and not t.get("molOff", false),
		"ghillie": 3 * A.call("ghillie"), "stride": A.call("stride"), "ammo": {"ap": mini(4, A.call("ammo_ap")), "fire": mini(4, A.call("ammo_fire")), "blast": mini(4, A.call("ammo_blast")), "shock": mini(4, A.call("ammo_shock"))}}


func load_file() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		sp = int(d.get("sp", 0))
		sp_total = int(d.get("sp_total", 0))
		sp_prog = int(d.get("sp_prog", 0))
		mol_off = bool(d.get("mol_off", false))
		cloud = bool(d.get("cloud", false))
		skills = {}
		var sk = d.get("skills", {})
		if sk is Dictionary:
			for S in SKILLS:
				if sk.has(S.id):
					skills[S.id] = clampi(int(sk[S.id]), 0, S.max)


func save() -> void:
	if not persist:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"sp": sp, "sp_total": sp_total, "sp_prog": sp_prog, "skills": skills, "mol_off": mol_off, "cloud": cloud}))
