class_name PalMaps
## The co-op maps (dev/src/js/06b-maps.js and 06d-elevation.js): where the stake sits, resource piles, old ruins, the
## ground, where raiders come in and which bosses turn up. lay() fills one in for the chosen size: 16x16, or 24x24 for
## XL, where the 16x16 layout sits two tiles in from the south-west corner and the new ground gets its own extras.
## Terrain is one byte a tile, in the browser's codes (never renumber: the network sends them).

const T_GROUND := 0
const T_WATER := 1
const T_BRIDGE := 2
const T_LOW := 3
const T_CRACK := 4
const T_PIT := 5
const T_ROCK := 6
const T_DRUM := 7
const T_ROAD := 8
const T_WALK := 9
const T_RUBBLE := 10
const T_BLDG := 11
const SIZES := {"std": 16, "xl": 24}

const MAPS := {
	"yard": {"name": "THE YARD", "short": "Yard", "blurb": "The claim you know. Open ground, a few old ruins, raiders over the east fence.",
		"from": "over the east fence", "bosses": ["butcher", "demolisher", "storm"], "col": "#b8894f", "hp": 1.0},
	"river": {"name": "RIVERBEND", "short": "Riverbend", "blurb": "A river cuts the yard in two. Two bridges, slow wading, more scrap, less wood. From raid 3 the banks flood.",
		"from": "across the river", "bosses": ["ferryman", "butcher", "storm"], "col": "#4a9ac0", "hp": 1.05},
	"quarry": {"name": "ASHFALL QUARRY", "short": "Quarry", "blurb": "A night pit lit by oil drums. Plenty of brick, little wood, three ramps in. Heavy blasts crack the floor into pits.",
		"from": "down the ramps", "bosses": ["foreman", "demolisher", "storm"], "col": "#e0763a", "night": true, "hp": 1.1},
	"frost": {"name": "FROSTPEAK", "short": "Frostpeak", "blurb": "Hold the summit. Two switchback approaches, ramps and stairs bring raiders up through three snowy terraces.",
		"from": "up the mountain", "bosses": ["rime", "storm", "rime"], "col": "#a8dfef", "hp": 1.08},
}
const MAP_IDS := ["yard", "river", "quarry", "frost"]
## City Black Out's own map (06e-city.js): not on the co-op map list, the mode picks it
const CITY_MAP := {"name": "THE CITY", "short": "City", "city": true, "night": true, "hp": 1.0, "col": "#8f9aa8", "from": "from every edge",
	"bosses": ["butcher", "demolisher", "storm", "ferryman", "foreman"], "blurb": "A ruined city in a blackout. Eight points to hold, then Main Command."}
const CITY := {"size": 64, "fallback": 48, "roadSpeed": 1.35, "rubbleSpeed": 0.8}
## [id, name, major, perk, what the perk does]
const CITY_POIS := [
	["radio", "RADIO TOWER", true, "warn", "Warns which point is hit next, 15 s ahead (3 s without it)."],
	["power", "POWER STATION", true, "lights", "Lights the roads. If it falls the whole city goes darker."],
	["hospital", "HOSPITAL", true, "heal", "Heals 3 HP a second within 5 tiles; teammates get up 50% faster there."],
	["armory", "ARMORY DEPOT", true, "refill", "A grenade and a rocket back every 30 s for everyone."],
	["gas", "GAS STATION", false, "salvage", "+25% salvage from kills nearby."],
	["hardware", "HARDWARE STORE", false, "wood", "Extra wood and metal piles that refill."],
	["brick", "BRICK WORKS", false, "brick", "Extra brick piles that refill."],
	["garage", "PARKING GARAGE", false, "range", "High ground: +2 tiles of range for anyone on it."]]
const LAMP_GAP := 4
const D4 := [[1, 0], [-1, 0], [0, 1], [0, -1]]


static func terr_solid(t: int) -> bool:
	return t == T_PIT or t == T_ROCK or t == T_DRUM or t == T_BLDG


## what stops a bullet and blocks sight: rock outcrops (and buildings); oil drums and pits don't
static func terr_shot(t: int) -> bool:
	return t == T_ROCK or t == T_BLDG


## Riverbend's river: the centre column for each row
static func river_c(j: int, o: Dictionary) -> float:
	return 9 + o.ox + 1.2 * sin((j - o.oy) * 0.5 + 0.6)


static func _wood(t: Array) -> Dictionary:
	return {"i": t[0], "j": t[1], "type": 0, "amt": 48, "max": 48, "rt": 0.0, "locked": false, "solid": false}


static func _kiln(t: Array, unlock: int) -> Dictionary:
	return {"i": t[0], "j": t[1], "type": 1, "locked": unlock > 0, "unlock": unlock, "solid": true}


static func _scrap(t: Array, unlock: int) -> Dictionary:
	return {"i": t[0], "j": t[1], "type": 2, "locked": unlock > 0, "unlock": unlock, "solid": true}


static func _edge(N: int, side: String, a: int, b: int) -> Array:
	var out: Array = []
	for s in range(maxi(0, a), mini(N, b)):
		out.append([N - 1, s] if side == "e" else [s, 0])
	return out


## The layout for a map: {N, terr, heights, connectors, core, nodes, ruins, spawns, bossAt, raftAt, ramps, evacAt, map}
static func lay(id: String, size: String = "std") -> Dictionary:
	if id == "city":
		return lay_city(CITY.size)
	if not MAPS.has(id):
		id = "yard"
	var N: int = SIZES.get(size, 16)
	var terr := PackedByteArray()
	terr.resize(N * N)
	var heights := PackedByteArray()
	heights.resize(N * N)
	var conn := PackedByteArray()
	conn.resize(N * N)
	var o := {"ox": 2 if N > 16 else 0, "oy": N - 16 - 2 if N > 16 else 0, "xl": N > 16}
	var P := func(t: Array) -> Array: return [t[0] + o.ox, t[1] + o.oy]
	var at := func(i: int, j: int) -> int: return terr[j * N + i] if i >= 0 and j >= 0 and i < N and j < N else T_GROUND
	var L := {"N": N, "id": id, "map": MAPS[id], "nodes": [], "ruins": [], "raftAt": [], "ramps": [], "o": o}
	match id:
		"yard":
			L.core = P.call([4, 11])
			var wood: Array = [[2, 7], [7, 13], [6, 6], [9, 9], [1, 13], [10, 4], [13, 14]].map(P)
			if o.xl:
				wood.append_array([[14, 3], [20, 9], [19, 20], [9, 2], [3, 3]])
			L.nodes = wood.map(_wood)
			L.nodes.append(_kiln(P.call([11, 11]), 2))
			L.nodes.append(_scrap(P.call([12, 7]), 4))
			if o.xl:
				L.nodes.append(_scrap([18, 4], 6))
			L.ruins = [[[[3, 9], [4, 9], [5, 9]].map(P), 0, 0.63, 0.25], [[[8, 6], [8, 7], [11, 9]].map(P), 1, 0.55, 0.3]]
			if o.xl:
				L.ruins.append([[[16, 11], [16, 12]], 1, 0.55, 0.3])
				L.ruins.append([[[12, 4], [13, 4]], 0, 0.63, 0.25])
			L.spawns = [{"w": 0.6, "tiles": _edge(N, "e", 0, o.oy + 12)}, {"w": 0.4, "tiles": _edge(N, "n", o.ox + 6, N)}]
			L.bossAt = _edge(N, "e", o.oy + 2, o.oy + 11)
		"river":
			L.core = P.call([4, 11])
			# the river: about two tiles wide, winding north to south; the bridges cross it
			for j in N:
				var c := river_c(j, o)
				for i in N:
					if absf(i + 0.5 - c) < 1:
						terr[j * N + i] = T_WATER
			var rows: Array = [o.oy + 4, o.oy + 11]
			if o.xl:
				rows.append(1)
			for j in rows:
				for i in N:
					if terr[j * N + i] == T_WATER:
						terr[j * N + i] = T_BRIDGE
			# low banks next to the water flood (the ends of the bridges stay dry)
			for j in N:
				for i in N:
					var k: int = j * N + i
					if terr[k] != T_GROUND:
						continue
					var near_bridge := false
					var wet := false
					for a in range(-1, 2):
						for b in range(-1, 2):
							if at.call(i + a, j + b) == T_BRIDGE:
								near_bridge = true
							if at.call(i + a, j + b) == T_WATER:
								wet = true
					if wet and not near_bridge:
						terr[k] = T_LOW
			var wood: Array = [[2, 7], [6, 14], [1, 13], [4, 3], [13, 13]].map(P)
			if o.xl:
				wood.append_array([[5, 2], [17, 3], [20, 18], [19, 11]])
			L.nodes = wood.map(_wood)
			L.nodes.append(_kiln(P.call([3, 14]), 2))
			L.nodes.append(_scrap(P.call([1, 4]), 2))
			L.nodes.append(_scrap(P.call([13, 5]), 0))
			if o.xl:
				L.nodes.append(_scrap([21, 6], 3))
			L.ruins = [[[[4, 8], [5, 8]].map(P), 0, 0.63, 0.25], [[[12, 9], [12, 10]].map(P), 1, 0.55, 0.3]]
			if o.xl:
				L.ruins.append([[[16, 15], [17, 15]], 1, 0.55, 0.3])
			var c0 := river_c(0, o)
			L.spawns = [{"w": 0.7, "tiles": _edge(N, "e", 0, N)}, {"w": 0.3, "tiles": _edge(N, "n", ceili(c0) + 2, N)}]
			L.bossAt = _edge(N, "e", o.oy + 1, N - 2)
			for i in N:   # the Ferryman comes down the river from the north
				if terr[i] == T_WATER:
					L.raftAt.append([i, 0])
		"quarry":
			L.core = P.call([4, 11])
			var put := func(list: Array, t: int) -> void:
				for q in list:
					if q[0] >= 0 and q[1] >= 0 and q[0] < N and q[1] < N:
						terr[q[1] * N + q[0]] = t
			put.call([[7, 8], [8, 8], [10, 12], [10, 13], [5, 5], [13, 10], [12, 2]].map(P), T_ROCK)
			put.call([[3, 9], [8, 11], [9, 3], [13, 7], [2, 2], [12, 14]].map(P), T_DRUM)
			if o.xl:
				put.call([[16, 4], [17, 4], [20, 13], [19, 21], [8, 1]], T_ROCK)
				put.call([[15, 9], [21, 3], [18, 17], [5, 1]], T_DRUM)
			var wood: Array = [[2, 7], [1, 13], [7, 5], [3, 3]].map(P)
			if o.xl:
				wood.append_array([[14, 2], [20, 20]])
			L.nodes = wood.map(_wood)
			var k1 := _kiln(P.call([6, 13]), 0)
			k1.locked = false
			L.nodes.append(k1)
			L.nodes.append(_kiln(P.call([11, 9]), 3))
			L.nodes.append(_scrap(P.call([12, 4]), 4))
			if o.xl:
				L.nodes.append(_kiln([18, 8], 2))
			L.ruins = [[[[5, 8], [6, 8]].map(P), 1, 0.55, 0.3], [[[9, 5], [10, 5]].map(P), 1, 0.55, 0.3], [[[2, 10]].map(P), 0, 0.63, 0.25]]
			if o.xl:
				L.ruins.append([[[15, 14], [16, 14]], 1, 0.55, 0.3])
			# three ramps down into the pit: north, east, south-east
			var rN: Array = [o.ox + 8, o.ox + 9]
			var rE: Array = [o.oy + 4, o.oy + 5]
			var rS: Array = [o.oy + 12, o.oy + 13]
			for i in rN:
				L.ramps.append([i, 0])
			for j in rE + rS:
				L.ramps.append([N - 1, j])
			L.spawns = [{"w": 1.0 / 3, "tiles": rN.map(func(i): return [i, 0])}, {"w": 1.0 / 3, "tiles": rE.map(func(j): return [N - 1, j])}, {"w": 1.0 / 3, "tiles": rS.map(func(j): return [N - 1, j])}]
			L.bossAt = L.ramps.duplicate()
			# cracked floor across the middle of the pit, where the fighting is
			var node_k := {}
			for n in L.nodes:
				node_k[n.j * N + n.i] = true
			for j in range(o.oy + 5, o.oy + 12):
				for i in range(o.ox + 7, o.ox + 14):
					var k: int = j * N + i
					if i < N and j < N and terr[k] == T_GROUND and not node_k.has(k) and Pal.hash2(i * 5 + 3, j * 9 + 1) > 0.4:
						terr[k] = T_CRACK
			if o.xl:
				for j in range(2, 10):
					for i in range(15, 22):
						var k: int = j * N + i
						if terr[k] == T_GROUND and not node_k.has(k) and Pal.hash2(i * 5 + 3, j * 9 + 1) > 0.5:
							terr[k] = T_CRACK
		"frost":
			# three terraces (2 at the summit, 0 at the foot); stairs (2) and ramps (1) link them in two lanes
			var a := 7 if N > 16 else 5
			var b := 15 if N > 16 else 10
			var lanes: Array = [[4, 5, 6], [16, 17, 18]] if N > 16 else [[3, 4, 5], [10, 11, 12]]
			for j in N:
				for i in N:
					var k: int = j * N + i
					heights[k] = 2 if j < a else (1 if j < b else 0)
					if (j == a or j == b) and (lanes[0].has(i) or lanes[1].has(i)):
						conn[k] = 2 if lanes[1].has(i) else 1
						heights[k] = 1 if j == a else 0
			var c: Array = [10 if N > 16 else 7, 2]
			L.core = c
			L.nodes = [[2, 2], [N - 3, 3], [2, a + 3], [N - 3, b + 3]].map(_wood)
			L.nodes.append(_kiln([c[0] - 3, 3], 0))
			L.nodes.append(_scrap([c[0] + 3, 3], 0))
			L.nodes.append(_scrap([N - 3, a + 3], 0))
			L.ruins = [[[[c[0] - 1, 4], [c[0] + 1, 4]], 1, 0.65, 0.1]]
			var foot: Array = []
			for i in N - 2:
				foot.append([i + 1, N - 1])
			L.spawns = [{"w": 1.0, "tiles": foot}]
			L.bossAt = [[3, N - 2], [N - 4, N - 2]]
			L.evacAt = [11 if N > 16 else 7, a + 3]
			for q in [[1, a + 2], [N - 2, a + 2], [1, b + 2], [N - 2, b + 2]]:
				terr[q[1] * N + q[0]] = T_ROCK
	# piles, ruins and the stake always stand on plain ground
	var keep: Array = [L.core]
	for n in L.nodes:
		keep.append([n.i, n.j])
	for r in L.ruins:
		keep.append_array(r[0])
	for q in keep:
		var k: int = q[1] * N + q[0]
		if terr[k] != T_GROUND and terr[k] != T_LOW:
			terr[k] = T_GROUND
	L.terr = terr
	L.heights = heights
	L.connectors = conn
	return L


## PvP layouts (06c-pvp-maps.js): every map but Frostpeak has a Base Battle and a Free-for-all version, always 16x16.
## Base Battle is point-mirrored (tile i,j on one side is 15-i,15-j on the other). Free-for-all arenas are turned four
## times round the middle, with spawns on the same symmetry; their cover can't be broken.
const PVP_BLURB := {
	"yard": {"base": "Today's yard, split down the middle: a stake each, the same piles and ruins on both sides.", "ffa": "Stacked-timber lanes round an open middle, and two ruined sheds to fight over."},
	"river": {"base": "The river runs corner to corner between the stakes. Two bridges and a ford on each side; both banks flood.", "ffa": "Four islands round a deep pool, one bridge to each neighbour. Wading is slow."},
	"quarry": {"base": "Lit by drums, the same rock on both sides and a cracked middle. A ramp behind each stake.", "ffa": "A stepped pit: a ring of ledges with ramps, rock pillars, and a cracked floor round a stone spire."}}
## the solo spawn spots round a stake at (4,11); PvP and the online crew use them too (SPAWNS in 04-state-armory.js)
const SPAWNS := [[5.5, 11.5], [5.5, 12.5], [3.5, 12.5], [4.5, 12.5], [5.5, 10.5], [3.5, 10.5]]


static func _pv_mir(list: Array) -> Array:
	var out := list.duplicate()
	for t in list:
		var m: Array = [15 - t[0], 15 - t[1]]
		m.append_array(t.slice(2))
		out.append(m)
	return out


static func _pv_rot(list: Array) -> Array:
	var out: Array = []
	for t in list:
		var c: Array = t
		for r in 4:
			out.append(c)
			var n: Array = [15 - c[1], c[0]]
			n.append_array(c.slice(2))
			c = n
	return out


static func _pv_rot_xy(list: Array) -> Array:
	var out: Array = []
	for p in list:
		var c: Array = p
		for r in 4:
			out.append(c)
			c = [16 - c[1], c[0]]
	return out


static func lay_pvp(id: String, pvp: String) -> Dictionary:
	if not PVP_BLURB.has(id):
		id = "yard"
	var N := 16
	var terr := PackedByteArray()
	terr.resize(N * N)
	var heights := PackedByteArray()
	heights.resize(N * N)
	var conn := PackedByteArray()
	conn.resize(N * N)
	var put := func(list: Array, t: int) -> void:
		for q in list:
			if q[0] >= 0 and q[1] >= 0 and q[0] < N and q[1] < N:
				terr[q[1] * N + q[0]] = t
	var t_at := func(i: int, j: int) -> int: return terr[j * N + i] if i >= 0 and j >= 0 and i < N and j < N else T_GROUND
	var L := {"N": N, "id": id, "map": MAPS[id], "nodes": [], "ruins": [], "cover": [], "raftAt": [], "ramps": [], "spawns": [], "pvp": pvp,
		"o": {"ox": 0, "oy": 0, "xl": false, "pvp": pvp}}
	match [id, pvp]:
		["yard", "base"]:
			L.cores = [[4, 11], [11, 4]]
			L.nodes = _pv_mir([[2, 8], [6, 14], [1, 13], [5, 8]]).map(_wood)
			L.nodes.append_array([_kiln([1, 6], 0), _kiln([14, 9], 0), _scrap([7, 13], 0), _scrap([8, 2], 0)])
			L.ruins = [[_pv_mir([[3, 9], [4, 9], [5, 9]]), 0, 0.63, 0.25], [[[7, 8], [8, 7], [6, 6], [9, 9]], 1, 0.55, 0.3]]
		["yard", "ffa"]:
			L.cover = _pv_rot([[4, 3, "timber"], [5, 3, "timber"], [6, 3, "timber"], [9, 3, "timber"], [10, 3, "timber"], [11, 3, "timber"], [4, 1, "timber"], [11, 1, "timber"]])
			L.cover.append_array(_pv_mir([[4, 5, "shed"], [4, 6, "shed"], [5, 5, "shed"]]))
			L.pspawns = _pv_rot_xy([[1.5, 1.5], [6.5, 1.3]])
		["river", "base"]:
			L.cores = [[3, 12], [12, 3]]
			for j in N:
				for i in N:
					if absi(i - j) <= 1:
						terr[j * N + i] = T_WATER
			var block := func(t: int, ty: int) -> void:
				for q in [[t, t], [t + 1, t], [t, t + 1], [t + 1, t + 1]]:
					if q[0] < N and q[1] < N and absi(q[0] - q[1]) <= 1:
						terr[q[1] * N + q[0]] = ty
			for t in [1, 5, 9, 13]:
				block.call(t, T_BRIDGE)
			for t in [3, 11]:
				block.call(t, T_LOW)
			for j in N:
				for i in N:
					if absi(i - j) != 2:
						continue
					var near := false
					for a in range(-1, 2):
						for b in range(-1, 2):
							if t_at.call(i + a, j + b) == T_BRIDGE:
								near = true
					if not near:
						terr[j * N + i] = T_LOW
			L.nodes = _pv_mir([[1, 9], [6, 14], [5, 7]]).map(_wood)
			L.nodes.append_array([_kiln([1, 14], 0), _kiln([14, 1], 0), _scrap([6, 10], 0), _scrap([9, 5], 0), _scrap([0, 6], 0), _scrap([15, 9], 0)])
			L.ruins = [[_pv_mir([[2, 9], [3, 9]]), 0, 0.63, 0.25], [_pv_mir([[7, 12], [8, 12]]), 1, 0.55, 0.3]]
		["river", "ffa"]:
			for j in N:
				for i in N:
					if i == 7 or i == 8 or j == 7 or j == 8 or Vector2(i - 7.5, j - 7.5).length() < 2.7:
						terr[j * N + i] = T_WATER
			put.call(_pv_rot([[7, 3], [8, 3], [7, 4], [8, 4]]), T_BRIDGE)
			L.cover = _pv_rot([[3, 3, "crate"], [4, 3, "crate"], [3, 4, "crate"], [6, 5, "crate"], [3, 1, "crate"], [1, 5, "crate"]])
			L.pspawns = _pv_rot_xy([[1.5, 1.5], [5.5, 1.3]])
		["quarry", "base"]:
			L.cores = [[4, 11], [11, 4]]
			L.ramps = [[2, 15], [3, 15], [13, 0], [12, 0]]
			for j in N:
				for i in N:
					if absf(i - 7.5) + absf(j - 7.5) <= 2.5:
						terr[j * N + i] = T_CRACK
			put.call(_pv_mir([[6, 2], [2, 6], [7, 10], [10, 13]]), T_ROCK)
			put.call(_pv_mir([[1, 9], [6, 13], [5, 6]]), T_DRUM)
			L.nodes = _pv_mir([[2, 7], [5, 13]]).map(_wood)
			L.nodes.append_array([_kiln([1, 12], 0), _kiln([14, 3], 0), _scrap([7, 14], 0), _scrap([8, 1], 0), _kiln([4, 8], 0), _kiln([11, 7], 0)])
			L.ruins = [[_pv_mir([[5, 9], [6, 9]]), 1, 0.55, 0.3]]
		["quarry", "ffa"]:
			for j in N:
				for i in N:
					if absf(i - 7.5) + absf(j - 7.5) <= 3.5:
						terr[j * N + i] = T_CRACK
			put.call([[7, 7], [8, 7], [7, 8], [8, 8]], T_ROCK)
			put.call(_pv_rot([[5, 5]]), T_ROCK)
			put.call(_pv_rot([[3, 2], [4, 2], [5, 2], [10, 2], [11, 2], [12, 2]]), T_ROCK)
			put.call(_pv_rot([[4, 1], [11, 1]]), T_ROCK)
			put.call(_pv_rot([[2, 2], [7, 4]]), T_DRUM)
			L.pspawns = _pv_rot_xy([[1.5, 1.5], [8.5, 0.9]])
	var keep: Array = L.get("cores", []).duplicate()
	for n in L.nodes:
		keep.append([n.i, n.j])
	for r in L.ruins:
		keep.append_array(r[0])
	keep.append_array(L.cover)
	for q in keep:
		var k: int = q[1] * N + q[0]
		if terr[k] != T_GROUND and terr[k] != T_LOW and terr[k] != T_CRACK:
			terr[k] = T_GROUND
	L.core = L.cores[0] if L.has("cores") else [7, 7]
	if pvp == "base":
		var ca: Array = L.cores[0]
		L.teamSpawns = SPAWNS.map(func(s): return [s[0] + ca[0] - 4, s[1] + ca[1] - 11])
	L.terr = terr
	L.heights = heights
	L.connectors = conn
	return L


static func city_geo(n: int) -> Dictionary:
	var C := n >> 1
	var ri := roundi(n * 0.1)
	var ro := roundi(n * 0.25)
	var rm := roundi(n * 0.34)
	return {"C": C, "ri": ri, "ro": ro, "rm": rm, "maj": [[C, C - rm], [C + rm, C], [C, C + rm], [C - rm, C]], "min": [[C - ro, C - ro], [C + ro, C - ro], [C + ro, C + ro], [C - ro, C + ro]]}


## on a road tile? (two tiles wide: the inner ring, the outer ring, and the four avenues from the inner ring to the edge)
static func city_road(i: int, j: int, G: Dictionary) -> bool:
	var dx := absf(i + 0.5 - G.C)
	var dy := absf(j + 0.5 - G.C)
	var m := maxf(dx, dy)
	if m >= G.ri - 1 and m <= G.ri + 1 and m > G.ri - 1:
		return true
	if m > G.ro - 1 and m <= G.ro + 1:
		return true
	return m > G.ri and (dx <= 1 or dy <= 1)


static func city_plaza(i: int, j: int, G: Dictionary, pois: Array) -> bool:
	if maxf(absf(i + 0.5 - G.C), absf(j + 0.5 - G.C)) < G.ri - 1:
		return true
	for p in pois:
		var r := 3.5 if p.major else 2.5
		if absf(i - p.i) < r and absf(j - p.j) < r:
			return true
	return false


static func lay_city(n: int) -> Dictionary:
	var G := city_geo(n)
	var terr := PackedByteArray()
	terr.resize(n * n)
	var heights := PackedByteArray()
	heights.resize(n * n)
	var conn := PackedByteArray()
	conn.resize(n * n)
	var L := {"N": n, "id": "city", "map": CITY_MAP, "core": [G.C, G.C], "nodes": [], "ruins": [], "pois": [], "city": G, "raftAt": [], "ramps": [], "o": {"ox": 0, "oy": 0, "xl": true}}
	var t_at := func(i: int, j: int) -> int: return terr[j * n + i] if i >= 0 and j >= 0 and i < n and j < n else T_GROUND
	var mi := 0
	var ni := 0
	for P in CITY_POIS:   # majors on the avenues, minors on the outer ring's corners
		var at: Array = G.maj[mi] if P[2] else G["min"][ni]
		if P[2]:
			mi += 1
		else:
			ni += 1
		L.pois.append({"id": P[0], "name": P[1], "major": P[2], "perk": P[3], "what": P[4], "i": at[0], "j": at[1]})
	var node_k := {}
	var node := func(x: Dictionary) -> void:
		if x.i < 0 or x.j < 0 or x.i >= n or x.j >= n:
			return
		var k: int = x.j * n + x.i
		if node_k.has(k):
			return
		node_k[k] = true
		L.nodes.append(x)
	for j in n:
		for i in n:
			var k := j * n + i
			if city_road(i, j, G):
				terr[k] = T_ROAD
				continue
			if city_plaza(i, j, G, L.pois) or i < 2 or j < 2 or i >= n - 2 or j >= n - 2:
				continue
			# the blocks: 4x4 cells, a 3x3 building in most, one-tile alleys between; ruined corners become rubble
			var h := Pal.hash2((i / 4) * 7 + 3, (j / 4) * 13 + 5)
			if h > 0.32 and i % 4 < 3 and j % 4 < 3:
				terr[k] = T_RUBBLE if Pal.hash2(i * 3 + 1, j * 5 + 2) > 0.87 else T_BLDG
				continue
			if Pal.hash2(i + 51, j + 17) > 0.9:
				terr[k] = T_RUBBLE
	for j in n:   # sidewalks along every road, where the ground is open
		for i in n:
			var k := j * n + i
			if terr[k] != T_GROUND:
				continue
			for d in D4:
				if t_at.call(i + d[0], j + d[1]) == T_ROAD:
					terr[k] = T_WALK
					break
	for cy in range(1, n / 4 - 1):   # parks: open lots off the roads get a wood pile
		for cx in range(1, n / 4 - 1):
			if Pal.hash2(cx * 7 + 3, cy * 13 + 5) > 0.32:
				continue
			var i := cx * 4 + 1
			var j := cy * 4 + 1
			if terr[j * n + i] == T_GROUND and not city_plaza(i, j, G, L.pois):
				node.call({"i": i, "j": j, "type": 0, "amt": 48, "max": 48, "rt": 0.0, "locked": false, "solid": false})
	# Main Command's supply: a kiln and a scrap pile off the plaza; the Brick Works and the Hardware Store add more
	node.call({"i": G.C - 2, "j": G.C + 2, "type": 1, "locked": false, "unlock": 0, "solid": true})
	node.call({"i": G.C + 2, "j": G.C - 2, "type": 2, "locked": false, "unlock": 0, "solid": true})
	for p in L.pois:
		if p.perk == "brick":
			node.call({"i": p.i - 1, "j": p.j + 1, "type": 1, "locked": false, "unlock": 0, "solid": true, "poi": p.id})
			node.call({"i": p.i + 1, "j": p.j + 1, "type": 1, "locked": false, "unlock": 0, "solid": true, "poi": p.id})
		if p.perk == "wood":
			node.call({"i": p.i - 1, "j": p.j + 1, "type": 2, "locked": false, "unlock": 0, "solid": true, "poi": p.id})
			node.call({"i": p.i + 1, "j": p.j - 1, "type": 0, "amt": 48, "max": 48, "rt": 0.0, "locked": false, "solid": false, "poi": p.id})
	# sandbag walls: a broken ring round Main Command's plaza, and round each major POI
	var used := node_k.duplicate()
	used[G.C * n + G.C] = true
	for p in L.pois:
		used[p.j * n + p.i] = true
	var ring := func(ci: int, cj: int, r: int) -> Array:
		var out: Array = []
		for a in range(-r, r + 1):
			for t in [[ci + a, cj - r], [ci + a, cj + r], [ci - r, cj + a], [ci + r, cj + a]]:
				var k: int = t[1] * n + t[0]
				if used.has(k) or Pal.hash2(t[0] * 9 + 1, t[1] * 3 + 7) <= 0.45 or terr[k] != T_GROUND:
					continue
				used[k] = true
				out.append(t)
		return out
	L.ruins.append([ring.call(G.C, G.C, 2), 1, 0.8, 0.0])
	for p in L.pois:
		if p.major:
			L.ruins.append([ring.call(p.i, p.j, 2), 1, 0.6, 0.0])
	L.lamps = []   # streetlamps: every fourth sidewalk tile along a road, leaning out over it
	for j in n:
		for i in n:
			if terr[j * n + i] != T_WALK or node_k.has(j * n + i):
				continue
			for d in D4:
				if t_at.call(i + d[0], j + d[1]) == T_ROAD and ((j % LAMP_GAP == 0) if d[0] != 0 else (i % LAMP_GAP == 0)):
					L.lamps.append([i, j, d[0], d[1]])
					break
	var edge := func(side: String) -> Array:
		var out: Array = []
		for s in range(3, n - 3):
			out.append([s, 0] if side == "n" else ([s, n - 1] if side == "s" else ([0, s] if side == "w" else [n - 1, s])))
		return out
	L.edges = {"n": edge.call("n"), "e": edge.call("e"), "s": edge.call("s"), "w": edge.call("w")}
	L.spawns = [{"w": 0.25, "tiles": L.edges.n}, {"w": 0.25, "tiles": L.edges.e}, {"w": 0.25, "tiles": L.edges.s}, {"w": 0.25, "tiles": L.edges.w}]
	L.bossAt = L.edges.e
	var keep: Array = [L.core]
	for p in L.pois:
		keep.append([p.i, p.j])
	for x in L.nodes:
		keep.append([x.i, x.j])
	for r in L.ruins:
		keep.append_array(r[0])
	for q in keep:
		terr[q[1] * n + q[0]] = T_GROUND
	L.terr = terr
	L.heights = heights
	L.connectors = conn
	return L


## the nearest edge to a point (attack spawns)
static func city_edge_for(i: int, j: int, n: int) -> String:
	var d := {"n": j, "s": n - 1 - j, "w": i, "e": n - 1 - i}
	var best := "n"
	for k in ["n", "s", "w", "e"]:   # Object.keys order, stable sort: ties go to the earlier key
		if d[k] < d[best]:
			best = k
	return best
