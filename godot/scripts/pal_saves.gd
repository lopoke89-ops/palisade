class_name PalSaves
extends RefCounted
## Best runs and the save backup (11-hud-chat.js loadBest/saveBest, 18-cosmetics.js exportSave/parseSave/restoreSave).
## The backup is the browser's own save code (PALISADE-SAVE-1.<base64 JSON>.<crc32>), so a code copied from the
## browser restores here and the other way round: the locker, best runs and the shared settings.

const BEST_PATH := "user://best.json"
const TAG := "PALISADE-SAVE-1"


static func load_best() -> Dictionary:
	if not FileAccess.file_exists(BEST_PATH):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(BEST_PATH))
	return d if d is Dictionary else {}


static func _write_best(b: Dictionary) -> void:
	var f := FileAccess.open(BEST_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(b))


## one record per length and threat on the Yard, per map and size elsewhere, per modifier set
static func best_key(mode: String, diff: String, map: String, size: String, mods: Array) -> String:
	var k := ("campaign" if mode == "campaign" else mode) + ":" + diff
	if (mode != "campaign" and map != "" and map != "yard") or size == "xl":
		k += ":" + ("all" if mode == "campaign" else (map if map != "" else "yard")) + (":xl" if size == "xl" else "")
	if not mods.is_empty():
		var m := mods.duplicate()
		m.sort()
		k += "|" + "+".join(m)
	return k


static func save_best(s: Sim, held: int, dropped: int) -> void:
	var g: Dictionary = s.game
	var b := load_best()
	var k := best_key(g.mode, g.diff, g.map, g.size, s.mods)
	var o = b.get(k)
	if not (o is Dictionary) or held > int(o.held) or (held == int(o.held) and dropped > int(o.dropped)):
		b[k] = {"held": held, "dropped": dropped, "cls": s.player.C.name}
		_write_best(b)


## the menu's line: the best run for the next game's setup, or "" if there is none
static func best_line(setup: Dictionary) -> String:
	var mods: Array = Sim.clean_mods(setup.get("mods", []), setup.mode)
	var b = load_best().get(best_key(setup.mode, setup.diff, setup.map, setup.size, mods))
	if not (b is Dictionary):
		return ""
	var w := ""
	if not mods.is_empty():
		w = " with %d modifiers" % mods.size() if mods.size() > 2 else " with " + " + ".join(mods.map(func(id): return _mod_name(id).to_lower()))
	var dn: String = Pal.DIFF[setup.diff].name.to_lower()
	if setup.mode == "endless":
		return "Best endless on %s%s: %d raids held, %d raiders dropped (%s)." % [dn, w, int(b.held), int(b.dropped), str(b.cls).to_lower()]
	var of: String = str(Sim.CAMPAIGN.waves) if setup.mode == "campaign" else (str(Sim.BLITZ.waves) if setup.mode == "blitz" else ("8" if setup.mode == "blackout" else setup.mode))
	return "Best on %s%s: %d of %s stages held, %d raiders dropped (%s)." % [dn, w, int(b.held), of, int(b.dropped), str(b.cls).to_lower()]


static func _mod_name(id: String) -> String:
	for M in Sim.MODS:
		if M.id == id:
			return M.name
	return id


static func crc32(s: String) -> String:
	var crc := 0xFFFFFFFF
	for ch in s.to_utf8_buffer():
		crc = crc ^ ch
		for k in 8:
			crc = (crc >> 1) ^ 0xEDB88320 if crc & 1 else crc >> 1
	return "%08x" % ((~crc) & 0xFFFFFFFF)


## exportSave: one line of text with the locker, best runs and settings
static func export_code(L: PalLocker, settings: PalSettings) -> String:
	var D: Dictionary = settings.data
	var cfg := {"name": str(D.get("name", "")), "volume": D.get("volume", 0.8), "music": D.get("music", 0.7), "shake": D.get("shake", 1.0), "haptics": D.get("haptics", true),
		"fps": D.get("fps", false), "fpsMode": str(D.get("fpsMode", "auto")), "tips": D.get("tips", true), "build": D.get("build", true)}
	var body := Marshalls.utf8_to_base64(JSON.stringify({"v": 1, "at": Time.get_datetime_string_from_system(true) + "Z",
		"locker": {"owned": L.owned, "eq": L.eq, "cases": L.cases, "bag": L.bag, "shards": L.shards, "prog": L.prog, "st": L.st}, "best": load_best(), "cfg": cfg}))
	return TAG + "." + body + "." + crc32(body)


## {d} or {err}: the browser's messages, word for word
static func parse_code(text: String) -> Dictionary:
	var s := ""
	for ch in text:
		if ch != " " and ch != "\n" and ch != "\t" and ch != "\r":
			s += ch
	var rx := RegEx.create_from_string("PALISADE-SAVE-1\\.([A-Za-z0-9+/=]+)\\.([0-9a-f]{8})")
	var m := rx.search(s)
	if m == null:
		return {"err": "That isn't a PALISADE save code. It starts with PALISADE-SAVE-1."}
	if crc32(m.get_string(1)) != m.get_string(2):
		return {"err": "That save code is damaged or incomplete. Copy the whole thing, or use the save file."}
	var d = JSON.parse_string(Marshalls.base64_to_utf8(m.get_string(1)))
	if not (d is Dictionary):
		return {"err": "That save code could not be read."}
	if int(d.get("v", 0)) != 1 or not (d.get("locker") is Dictionary) or not (d.locker.get("owned") is Array):
		return {"err": "That save code is from a version this game can't read."}
	return {"d": d}


static func summary(d: Dictionary) -> String:
	var L: Dictionary = d.locker
	var n := 0
	for id in L.get("owned", []):
		var it := PalLocker.item(str(id))
		if not it.is_empty() and it.get("src", "") != "free":
			n += 1
	var nc := int(L.get("cases", 0))
	var bag = L.get("bag", {})
	if bag is Dictionary:
		for k in bag:
			nc += int(bag[k])
	var st = L.get("st", {})
	var raids := int(st.get("raids", 0)) if st is Dictionary else 0
	var at: String = str(d.get("at", "")).substr(0, 16).replace("T", " ")
	return "%s%d item%s · %d case%s · %d shards · %d raids held" % [("Saved " + at + " · ") if at != "" else "", n, "" if n == 1 else "s", nc, "" if nc == 1 else "s", int(L.get("shards", 0)), raids]


## restoreSave: the locker (the current one kept as the backup copy first), best runs and the shared settings
static func restore(d: Dictionary, L: PalLocker, settings: PalSettings) -> void:
	if FileAccess.file_exists(PalLocker.PATH):
		var f := FileAccess.open(PalLocker.PATH + ".bak", FileAccess.WRITE)
		if f != null:
			f.store_string(FileAccess.get_file_as_string(PalLocker.PATH))
	L.norm(d.locker.duplicate(true))
	L.save()
	if d.get("best") is Dictionary:
		_write_best(d.best)
	if d.get("cfg") is Dictionary:
		var c: Dictionary = d.cfg
		var D: Dictionary = settings.data
		for k in ["name", "volume", "music", "shake", "fps", "tips", "build"]:
			if c.has(k) and typeof(c[k]) == typeof(D.get(k, c[k])):
				D[k] = c[k]
		if c.has("haptics") and c.haptics is bool:
			D.haptics = c.haptics
		if c.get("fpsMode") in ["auto", "30", "60"]:
			D.fpsMode = c.fpsMode
		settings.save()
