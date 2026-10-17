class_name ArtLibrary
extends RefCounted
## The 3D model library (lopoke89-ops/palisade-3d-model-library), copied into res://palisade_art by tools/sync_art.sh.
## Looks up the library's IDs (the same as the game's: skin:sahur, hat:crown, bg:campfire, weapon:bolt), caches the
## imported scenes, and builds a dressed character: the class or skin model, its headgear (the library's replacement
## and fit rules, docs/godot/recipes/modular_loadout.gd), the class's weapon in place of the one the skin was posed
## with (weapon_profiles.json), playing its idle.

const ROOT := "res://palisade_art"
const CLASS_WEAPON := {"soldier": "weapon:carbine", "sniper": "weapon:bolt", "grenadier": "weapon:pump", "quartermaster": "weapon:smg"}

static var _lib: ArtLibrary = null

var assets := {}   # id -> catalog entry (assets, utilities and weapons)
var characters := {}   # id -> animation manifest entry
var headgear_overrides := {}
var attach := {}   # weapon_profiles.json weapon_attach
var scenes := {}   # file -> PackedScene


## the library, or null when the art isn't in this build (the menus fall back to the painted backgrounds)
static func get_lib() -> ArtLibrary:
	if _lib == null and FileAccess.file_exists(ROOT + "/catalog.json"):
		var l := ArtLibrary.new()
		if l._open():
			_lib = l
	return _lib


func _json(rel: String) -> Variant:
	var p := ROOT.path_join(rel)
	return JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null


func _open() -> bool:
	var cat = _json("catalog.json")
	var man = _json("animation/manifest.json")
	if not (cat is Dictionary) or not (man is Dictionary):
		return false
	for key in ["assets", "utilities", "weapons"]:
		for e in cat.get(key, []):
			assets[e.id] = e
	for e in man.get("characters", []):
		characters[e.id] = e
	headgear_overrides = man.get("headgear_fit_overrides", {})
	var wp = _json("weapon_profiles.json")
	attach = wp.get("weapon_attach", {}) if wp is Dictionary else {}
	return true


func has(id: String) -> bool:
	return assets.has(id) and ResourceLoader.exists(ROOT.path_join(assets[id].file))


func instantiate_file(rel: String) -> Node3D:
	var ps: PackedScene = scenes.get(rel)
	if ps == null:
		var path := ROOT.path_join(rel)
		if not ResourceLoader.exists(path):
			return null
		ps = ResourceLoader.load(path, "PackedScene") as PackedScene
		if ps == null:
			return null
		scenes[rel] = ps
	var n := ps.instantiate()
	if not (n is Node3D):
		n.free()
		return null
	return n as Node3D


func instantiate_id(id: String) -> Node3D:
	return instantiate_file(assets[id].file) if assets.has(id) else null


## the model a class wears with this skin: the standard look is the class's own model
func character_id(cls: String, skin: String) -> String:
	var sid := "skin:" + skin
	if skin != "" and skin != "std" and has(sid):
		return sid
	return "player:" + (cls if CLASS_WEAPON.has(cls) else "soldier")


# ---------------------------------------------------------------- dressing a character

static func _all(root: Node, out: Array = []) -> Array:
	out.append(root)
	for c in root.get_children():
		_all(c, out)
	return out


static func named(root: Node, wanted: String) -> Node:
	for n in _all(root):
		if String(n.name) == wanted:
			return n
	return null


## a slot's meshes, and the fur that belongs to it (skinned meshes are flattened, so ownership is by name or meta)
static func show_slot(model: Node, slot: String, on: bool) -> void:
	for n in _all(model):
		if n is GeometryInstance3D:
			var nm := String(n.name)
			if nm == slot or nm.begins_with("Fur_" + slot + "_") or n.get_meta("modular_owner", "") == slot:
				n.visible = on


## headgear by the library's rules: class/default keeps the authored head; none bares it; a replacement head (the
## pumpkins) hides the head and face; a covering item hides the face. Unknown or unfitted: the class default.
func equip_hat(model: Node3D, char_id: String, hat: String) -> void:
	var hat_id := "hat:" + hat
	var item: Dictionary = assets.get(hat_id, {})
	var ch: Dictionary = assets.get(char_id, {})
	var socket := named(model, "HeadSocket") as Node3D
	var ok: bool = hat != "class" and hat != "" and item.get("category", "") == "hat" and socket != null
	if ok and ch.get("category", "") == "skin" and not (hat in ch.get("compatible_headgear", [])):
		ok = false
	var acc: Node3D = null
	if ok:
		var fit: Dictionary = headgear_overrides.get(char_id, {}).get(hat_id, {})
		acc = instantiate_file(fit.get("file", item.file))
		if acc != null:
			var t: Array = fit.get("translation", [0, 0, 0])
			var s: Array = fit.get("scale", [1, 1, 1])
			acc.position = Vector3(t[0], t[1], t[2])
			acc.scale = Vector3(s[0], s[1], s[2])
	for slot in ["DefaultHead", "DefaultFace", "DefaultHeadgear"]:
		show_slot(model, slot, true)
	if acc == null:
		return
	show_slot(model, "DefaultHeadgear", false)
	acc.name = "EquippedCosmetic"
	socket.add_child(acc)
	var fp: Dictionary = item.get("fit_profile", {})
	var replacement: bool = fp.get("kind", "") == "replacement head"
	if replacement:
		show_slot(model, "DefaultHead", false)
	if replacement or fp.get("covered", false):
		show_slot(model, "DefaultFace", false)


## the class's weapon in place of the one the model was posed with (kept when they're the same gun, so skins with
## decorations in their weapon slot keep them)
func equip_weapon(model: Node3D, char_id: String, cls: String) -> void:
	var want: String = CLASS_WEAPON.get(cls, "weapon:carbine")
	var a: Dictionary = attach.get(char_id, {})
	if a.is_empty() or a.get("default_weapon", "") == want or not has(want):
		return
	var socket := named(model, String(a.get("socket", "WeaponSocket"))) as Node3D
	var gun := instantiate_id(want)
	if socket == null or gun == null:
		if gun != null:
			gun.free()
		return
	var lg: Dictionary = a.get("long_gun", {})
	var t: Array = lg.get("translation", [0, 0, 0])
	var r: Array = lg.get("rotation", [0, 0, 0, 1])
	gun.transform = Transform3D(Basis(Quaternion(r[0], r[1], r[2], r[3])), Vector3(t[0], t[1], t[2]))
	gun.name = "ClassWeapon"
	show_slot(model, "Weapon", false)
	socket.add_child(gun)


func animation_player(model: Node) -> AnimationPlayer:
	for n in _all(model):
		if n is AnimationPlayer:
			return n
	return null


## a dressed character standing at its idle (offset so a crew doesn't breathe in step)
func build(cls: String, cos: Dictionary, idle_offset: float = 0.0) -> Node3D:
	var cid := character_id(cls, str(cos.get("skin", "std")))
	var model := instantiate_id(cid)
	if model == null:
		return null
	equip_hat(model, cid, str(cos.get("hat", "class")))
	equip_weapon(model, cid, cls)
	var ap := animation_player(model)
	if ap != null:
		for c in characters.get(cid, {}).get("clips", []):
			if ap.has_animation(c.name):
				ap.get_animation(c.name).loop_mode = Animation.LOOP_LINEAR if c.get("loop", false) else Animation.LOOP_NONE
		if ap.has_animation("Idle_Loop"):
			ap.play("Idle_Loop")
			ap.seek(fmod(idle_offset, maxf(0.1, ap.current_animation_length)), true)
	model.set_meta("char_id", cid)
	return model
