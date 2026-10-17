extends SceneTree
## Music routing (03-audio.js musicRoute / casinoUp): which track each screen and mode wants, and the casino playlist.
##   godot --headless --path godot --script res://tests/music_test.gd      (exit 0 = pass)

var fails := 0


func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var A := PalAudio.new()
	var s := Sim.new()
	A.sim = s
	var m := {"demo": true}
	A.main = m
	s.new_game(1, "normal", {}, {"mode": "5", "map": "yard"})
	check(A.music_route()[0] == "menu", "the menus play the menu track")
	m.demo = false
	check(A.music_route()[0] == "between", "the build phase plays between raids")
	s.game.phase = "raid"
	s.game.wave = 2
	check(A.music_route()[0] == "cool", "raid 2 plays cool")
	s.game.phase = "over"
	check(A.music_route()[0] == "results", "the end screen plays results")
	s.new_game(1, "normal", {}, {"mode": "blitz", "map": "yard"})
	s.game.fb = {}
	check(A.music_route()[0] == "finale", "Blitzkrieg's Final Blitz plays the finale")
	s.new_game(1, "normal", {}, {"mode": "blackout", "map": "city"})
	s.game.phase = "raid"
	s.game.bo = {"stage": "push"}
	check(A.music_route()[0] == "finale", "Black Out's final push plays the finale")
	s.game.bo.stage = "attack"
	check(A.music_route()[0] in ["attitude", "cool", "express"], "a Black Out attack plays a raid track")
	s.new_game(1, "normal", {}, {"mode": "casino", "map": "casino"})
	var r := A.music_route()
	check(r[0] == "casino" and r[1].begins_with("casino:"), "the casino plays its playlist (%s)" % r[1])
	var seen := {}
	var prev := ""
	var repeat := false
	for i in 33:
		var k := A.casino_up()
		A.cas_up = ""
		A.cas_last = k
		seen[k] = true
		repeat = repeat or k == prev
		prev = k
	check(seen.size() == 11 and not repeat, "the shuffle plays all 11 tracks and never one twice in a row")
	for k in PalAudio.CASINO + PalAudio.MUSIC.values():
		check(ResourceLoader.exists("res://music/%s.ogg" % k), "music/%s.ogg is there" % k)
	A.free()
	print("ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
