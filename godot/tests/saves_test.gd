extends SceneTree
## The save code against the browser's encoder: a code made with 18-cosmetics.js's own crc32 and base64 reads back here,
## and one made here reads back the same. godot --headless --path godot --script res://tests/saves_test.gd -- code.txt
var fails := 0


func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var code := FileAccess.get_file_as_string(a[0]).strip_edges() if a.size() > 0 else ""
	var r := PalSaves.parse_code(code)
	check(r.has("d"), "the browser's code reads (%s)" % r.get("err", "ok"))
	if r.has("d"):
		check(r.d.locker.shards == 37 and r.d.cfg.name == "Zoë" and r.d.best["5:normal"].held == 5, "with its locker, best runs and settings (non-ASCII name intact)")
	check(PalSaves.parse_code(code.substr(0, code.length() - 1) + "0").has("err"), "a damaged code is refused")
	check(PalSaves.parse_code("hello").err.begins_with("That isn't a PALISADE save code"), "anything else is refused")
	check(PalSaves.best_key("5", "normal", "yard", "std", []) == "5:normal" and PalSaves.best_key("blitz", "hard", "river", "xl", ["weather", "elite"]) == "blitz:hard:river:xl|elite+weather", "best-run keys match the browser's")
	quit(1 if fails else 0)
