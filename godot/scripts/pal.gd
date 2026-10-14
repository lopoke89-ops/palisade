class_name Pal
## Tuning constants, ported 1:1 from dev/src/js/01-setup.js, 04-state-armory.js and 10-phases-bosses.js.
## Change a number here only together with the browser build (protocol yard-29), or cross-play drifts.

const D4: Array = [[1, 0], [-1, 0], [0, 1], [0, -1]]

const MAT: Array = [
	{"name": "WOOD", "cost": 4, "hp": 60.0, "bullet": 1.0, "blast": 2.2, "cd": 0.22, "top": "#b8894f", "l": "#8b6236", "r": "#6b4a28", "line": Color(52 / 255.0, 32 / 255.0, 14 / 255.0, 0.55)},
	{"name": "BRICK", "cost": 4, "hp": 170.0, "bullet": 0.42, "blast": 1.3, "cd": 0.55, "top": "#a0533c", "l": "#7b3b2a", "r": "#5d2c20", "line": Color(220 / 255.0, 190 / 255.0, 160 / 255.0, 0.28)},
	{"name": "METAL", "cost": 4, "hp": 320.0, "bullet": 0.14, "blast": 0.55, "cd": 1.0, "top": "#a3a9a8", "l": "#727a7a", "r": "#565d5e", "line": Color(28 / 255.0, 32 / 255.0, 33 / 255.0, 0.5)},
	{"name": "CONCRETE", "cost": 99, "hp": 9999.0, "bullet": 0.0, "blast": 0.0, "cd": 1.0, "top": "#8f8b80", "l": "#6d6a61", "r": "#56534c", "line": Color(30 / 255.0, 28 / 255.0, 24 / 255.0, 0.4)},
]

# burst carbine: a burst always finishes once started; rounds per burst and the pause after it follow the DAMAGE level
const SOLDIER: Dictionary = {"name": "SOLDIER", "hp": 115.0, "nades": 2, "build": 0.6, "cap": [64, 64, 64], "blast": 1.0, "nadeCd": 1.0, "spd": 1.0,
	"gun": {"dmg": 12.0, "cd": 0.09, "spread": 0.12, "range": 11.0, "speed": 22.0, "burst": true}}

const DIFF: Dictionary = {
	"easy": {"name": "EASY", "dmg": 0.55, "hp": 0.8, "extra": -1, "build": 10, "core": 600},
	"normal": {"name": "NORMAL", "dmg": 0.85, "hp": 1.0, "extra": 0, "build": 0, "core": 500},
	"hard": {"name": "HARD", "dmg": 1.15, "hp": 1.2, "extra": 1, "build": -6, "core": 420},
}

const RATE: Array = [0.18, 0.225, 0.54]
const YIELD: Array = [4, 1, 1]
const WAVES := 5
const WALL_COST := 4
const DOOR_COST := 8
const WALL_SALVAGE: Array = [5, 8, 15]
const BURST_N: Array = [3, 5, 7, 9, 9]

const ETYPES: Dictionary = {
	"rifle": {"hp": 36.0, "speed": 1.5}, "gren": {"hp": 46.0, "speed": 1.25}, "breach": {"hp": 30.0, "speed": 2.1},
	"shield": {"hp": 66.0, "speed": 1.15}, "medic": {"hp": 34.0, "speed": 1.55}, "spotter": {"hp": 30.0, "speed": 1.45}, "fire": {"hp": 40.0, "speed": 1.4},
}

# Second Wind defaults with no skills taken (perkMods({}))
const REGEN_AFTER := 4.0
const REGEN := 4.0


## The browser's hash(i,j): Math.imul integer mixing, returns 0..1. Must match bit for bit.
static func hash2(i: int, j: int) -> float:
	var h: int = _i32(i * 374761393 + j * 668265263)
	h = _imul(h ^ _ushr(h, 13), 1274126177)
	return float(_u32(h ^ _ushr(h, 16))) / 4294967295.0


static func _i32(v: int) -> int:
	v = v & 0xFFFFFFFF
	return v - 0x100000000 if v >= 0x80000000 else v


static func _u32(v: int) -> int:
	return v & 0xFFFFFFFF


static func _ushr(v: int, s: int) -> int:
	return (v & 0xFFFFFFFF) >> s


static func _imul(a: int, b: int) -> int:
	# 32x32 multiply split in halves so nothing overflows 64 bits; the low 32 bits are what Math.imul keeps
	var al: int = a & 0xFFFFFFFF
	var bl: int = b & 0xFFFFFFFF
	var lo: int = al * (bl & 0xFFFF)
	var hi: int = (al * (bl >> 16)) & 0xFFFF
	return _i32(lo + (hi << 16))


static func wall_state(w: Dictionary) -> int:
	var r: float = w.hp / w.max
	return 0 if r > 0.66 else (1 if r > 0.33 else 2)


static func make_wall(mat: int, door: bool, ratio: float = 1.0) -> Dictionary:
	var hp: float = MAT[mat].hp * (0.85 if door else 1.0)
	return {"mat": mat, "door": door, "hp": hp * ratio, "max": hp, "fire": 0.0, "char": 0.0, "flash": 0.0, "crew": false, "fire_by": null}


static func burst_n(d_level: int) -> int:
	return BURST_N[mini(4, d_level)]


static func burst_gap(d_level: int) -> float:
	return maxf(0.2, 0.4 - 0.05 * d_level)
