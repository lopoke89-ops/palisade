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
const T_RUBBLE := 9
const T_BLDG := 10
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
