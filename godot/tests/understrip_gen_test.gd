extends SceneTree
## Compare native levels with fixtures produced by the unchanged browser generator.
const Gen = preload("res://scripts/pal_understrip_gen.gd")
const Under = preload("res://scripts/pal_understrip.gd")
func _initialize():
	var args = OS.get_cmdline_user_args()
	var path = args[0] if args.size() else "res://tests/understrip_gen_fixture.json"
	var fixture = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not fixture is Array or fixture.is_empty():
		push_error("Missing generator fixture: " + path)
		quit(1)
		return
	var kits = {}
	for region in [1,2,3]: kits[region] = Gen.load_kit(region)
	var count = 0
	for row in fixture:
		var kind = "normal" if row[1] == "normal" else "boss"
		var level = Gen.generate(kits[int(row[0])], int(row[2]), kind, "" if kind=="normal" else row[1])
		if not level.ok or Gen.tile_hash(level) != int(row[3]):
			push_error("Generator mismatch: %s; actual %s" % [row, Gen.tile_hash(level) if level.ok else "FAILED"])
			quit(1)
			return
		count += 1
	# Check the terrain contract consumed by collision, shots, and the future tunnel view.
	for c in ["#", "%", "K", "o", "t"]:
		if not PalMaps.terr_solid(Under.cell(c)):
			push_error("Tunnel obstruction is walkable: " + c)
			quit(1)
			return
	if PalMaps.terr_shot(Under.cell("o")) or not PalMaps.terr_shot(Under.cell("t")):
		push_error("Junk must pass shots; specimen tanks must stop them")
		quit(1)
		return
	for i in Under.PLAN.size():
		var level = Under.level(0xffffffff, i)
		var terrain = Under.terrain(level)
		if terrain.is_empty() or terrain.terr.size() != level.T*level.T or level.marks.P.size()!=6:
			push_error("Invalid run level %d" % i)
			quit(1)
			return
	print("PASS understrip_gen: %d browser hashes match" % count)
	print("PASS understrip_terrain: all ten run levels and obstruction rules")
	quit()
