class_name PalUnderstrip
extends RefCounted
## Shared run order and terrain adapter. Gameplay is added separately from generation.
const PLAN = [[1,"normal",""],[1,"normal",""],[1,"boss","pitboss"],
	[2,"normal",""],[2,"normal",""],[2,"boss","custodian"],
	[3,"normal",""],[3,"normal",""],[3,"boss","gatekeeper"],[3,"boss","visitor"]]

static func level(run_seed: int, index: int) -> Dictionary:
	if index < 0 or index >= PLAN.size():
		return {"ok": false}
	var p = PLAN[index]
	var first = 0 if p[0]==1 else (3 if p[0]==2 else 6)
	return PalUnderstripGen.generate(PalUnderstripGen.load_kit(p[0]),
		PalUnderstripGen.mix([run_seed,p[0],index-first+1]),p[1],p[2])

static func cell(c: String) -> int:
	match c:
		"#", "%": return PalMaps.T_CONC
		"t": return PalMaps.T_TANK
		"o": return PalMaps.T_JUNK
		",": return PalMaps.T_LOW
		"~": return PalMaps.T_WATER
		"=": return PalMaps.T_BRIDGE
		"K": return PalMaps.T_SHUT
	return PalMaps.T_GROUND

static func terrain(generated: Dictionary) -> Dictionary:
	if not generated.get("ok",false): return {}
	var n: int = generated.T
	var tiles = PackedByteArray()
	tiles.resize(n*n)
	var edges = PackedByteArray()
	edges.resize(n*n)
	for y in n:
		for x in n: tiles[y*n+x] = cell(generated.tiles[y][x])
	for y in n:
		for x in n:
			if tiles[y*n+x] != PalMaps.T_CONC: continue
			for b in range(-1,2):
				for a in range(-1,2):
					var xx = x+a
					var yy = y+b
					if xx>=0 and yy>=0 and xx<n and yy<n and not PalMaps.terr_solid(tiles[yy*n+xx]): edges[y*n+x]=1
	return {"N":n,"terr":tiles,"edges":edges,"us":generated}
