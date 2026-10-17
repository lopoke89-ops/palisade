class_name PalSettings
extends RefCounted
## Settings (the browser's cfg, 04-state-armory.js, and the controller map, 08b-pad.js), kept in user://settings.json:
## sound, screen, the next game's setup, keyboard keys and controller buttons.

const PATH := "user://settings.json"
## the browser follows the system's reduced-motion preference; here it's a setting: backgrounds and auras hold still
static var reduce_motion := false

## Controller buttons in the browser's "standard" numbering, the same on Xbox and PlayStation pads
const PB := {"A": 0, "B": 1, "X": 2, "Y": 3, "LB": 4, "RB": 5, "LT": 6, "RT": 7, "VIEW": 8, "MENU": 9, "LS": 10, "RS": 11, "UP": 12, "DOWN": 13, "LEFT": 14, "RIGHT": 15, "HOME": 16}
const GLYPH := {"xbox": ["A", "B", "X", "Y", "LB", "RB", "LT", "RT", "VIEW", "MENU", "LS", "RS", "▲", "▼", "◀", "▶", "HOME"],
	"ps": ["✕", "○", "□", "△", "L1", "R1", "L2", "R2", "CREATE", "OPTIONS", "L3", "R3", "▲", "▼", "◀", "▶", "PS"]}

## [id, what Settings calls it, default keys, default controller button (-1: none until the player sets one)]
const ACTIONS := [
	["up", "MOVE UP", [KEY_W, KEY_UP], -1],
	["down", "MOVE DOWN", [KEY_S, KEY_DOWN], -1],
	["left", "MOVE LEFT", [KEY_A, KEY_LEFT], -1],
	["right", "MOVE RIGHT", [KEY_D, KEY_RIGHT], -1],
	["fire", "FIRE", [], 7],
	["build", "BUILD", [KEY_SPACE], 0],
	["nade", "GRENADE", [KEY_G], 6],
	["special", "ABILITY", [KEY_Q], 1],
	["sprint", "SPRINT", [KEY_SHIFT], -1],
	["reload", "RELOAD", [KEY_R], -1],
	["armory", "ARMORY", [KEY_E, KEY_U], 2],
	["piece", "WALL / DOOR", [KEY_F], 3],
	["mat1", "WOOD", [KEY_1], -1],
	["mat2", "BRICK", [KEY_2], -1],
	["mat3", "METAL", [KEY_3], -1],
	["matPrev", "MATERIAL BACK", [], 14],
	["matNext", "MATERIAL NEXT", [], 15],
	["start", "START RAID / READY", [KEY_ENTER, KEY_KP_ENTER], 8],
	["delgado", "DELGADO ORDERS", [KEY_H], -1],
	["skills", "SKILL TREE", [KEY_K], -1],
	["pause", "PAUSE", [KEY_ESCAPE, KEY_P], 9],
]

var data := {
	"volume": 0.8, "music": 0.7, "shake": 1.0, "zoom": 1.0, "msgTime": 1.0, "fpsMode": "auto", "fps": false, "tips": true,
	"haptics": true, "fullscreen": false, "vsync": true, "reduceMotion": false,
	"setup": {"mode": "5", "map": "yard", "size": "std", "diff": "normal", "cls": "soldier", "mods": []},
	"keys": {}, "pad": {},
}


func _init() -> void:
	reset_keys()
	reset_pad()


func reset_keys() -> void:
	data.keys = {}
	for a in ACTIONS:
		data.keys[a[0]] = a[2].duplicate()


func reset_pad() -> void:
	data.pad = {}
	for a in ACTIONS:
		data.pad[a[0]] = a[3]


func load_file() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not d is Dictionary:
		return
	for k in data:
		if not d.has(k):
			continue
		if k == "keys" or k == "pad" or k == "setup":
			for kk in d[k]:
				if data[k].has(kk):
					var val = d[k][kk]
					if k == "keys" and val is Array:
						data.keys[kk] = val.map(func(x): return int(x))
					elif k == "pad" and (val is float or val is int) and int(val) >= -1 and int(val) <= 16 and int(val) != PB.MENU:
						data.pad[kk] = int(val)
					elif k == "setup":
						data.setup[kk] = val
			continue
		if typeof(d[k]) == typeof(data[k]) or (data[k] is float and (d[k] is int or d[k] is float)):
			data[k] = d[k]
	data.pad.pause = PB.MENU   # the pause button never moves
	data.zoom = clampf(data.zoom, 0.7, 1.4)


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))


## the keyboard half of the bindings goes into Godot's InputMap, as actions "pal_<id>"
func apply_keys() -> void:
	for a in ACTIONS:
		var name: String = "pal_" + a[0]
		if InputMap.has_action(name):
			InputMap.action_erase_events(name)
		else:
			InputMap.add_action(name)
		for kc in data.keys.get(a[0], []):
			var ev := InputEventKey.new()
			ev.keycode = kc
			InputMap.action_add_event(name, ev)


static func key_name(kc: int) -> String:
	return OS.get_keycode_string(kc).to_upper() if kc != 0 else "—"


func keys_label(id: String) -> String:
	var ks: Array = data.keys.get(id, [])
	if ks.is_empty():
		return "—"
	return " / ".join(ks.map(func(k): return key_name(k)))


static func glyph(b: int, kind: String = "xbox") -> String:
	if b < 0:
		return "—"
	var G: Array = GLYPH.get(kind, GLYPH.xbox)
	return G[b] if b < G.size() else "B%d" % b
