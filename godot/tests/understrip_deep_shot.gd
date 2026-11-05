extends SceneTree
## G3 on screen: Shelter 7 with a vent leaking, the Custodian in both stages, Area 67 with drones, the Gatekeeper and his
## pilot, the Visitor before and after its field fails. Settings and saves are changed in memory only, never saved.
##   godot --path godot --rendering-driver opengl3 --resolution 1600x900 --script res://tests/understrip_deep_shot.gd -- out_prefix

var main
var pre := ""

func _initialize():
	call_deferred("go")

func shot(name: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(pre + "_" + name + ".png")
	print("saved ", name)

func start(n: int):
	main.game_n += 1
	main.sim.new_game(1234, "normal", {}, {"mode": "understrip", "us_level": n})
	var p = main.sim.player
	p.hp = 1e6
	p.max = 1e6

func play(frames: int, hold = null):
	var p = main.sim.player
	for i in frames:
		p.hp = p.max
		p.alive = true
		if hold != null:
			p.x = hold.x
			p.y = hold.y
		main.sim.update(.02)
		main.v.cam_snap(p.x, p.y)
		await process_frame

## into the arena; the gate closes and the boss wakes. Returns the boss.
func fight() -> Dictionary:
	var s = main.sim
	s.enemies = s.enemies.filter(func(e): return e.type == "boss")
	var A = s.lay.arena
	var at := Vector2(A.x + A.w / 2.0, A.y + A.h - 2.5)
	for i in 300:
		await play(1, at)
		if s.game.us.gate == 2: break
	var B = s.enemies.filter(func(e): return e.type == "boss")
	return B[0] if not B.is_empty() else {}

## stand a few tiles from the boss (so the camera shows him and his moves) for a while
func watch(e: Dictionary, frames: int):
	var s = main.sim
	var p = s.player
	for i in frames:
		var want := Vector2(e.x + 2.2, e.y + 2.2)
		if not s.solid_tile(int(want.x), int(want.y)):
			p.x = want.x
			p.y = want.y
		await play(1)

func go():
	pre = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://deep"
	PalAccount.offline = true
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.locker.persist = false
	main.profile.persist = false
	for i in 5: await process_frame
	main.demo = false
	main.menus.close()
	# Shelter 7: a vent leaking
	start(3)
	var s = main.sim
	s.enemies.clear()
	if not s.lay.vents.is_empty():
		var v = s.lay.vents[0]
		s.game.us.vents[0].s = 2
		s.game.us.vents[0].t = 6.0
		var spot := Vector2(v.cx + 2.5, v.cy + 2.5)
		for k in [[2.5, 2.5], [-2.5, 2.5], [2.5, -2.5], [1.5, 0], [0, 1.5]]:
			if not s.solid_tile(int(v.cx + k[0]), int(v.cy + k[1])):
				spot = Vector2(v.cx + k[0], v.cy + k[1])
				break
		await play(30, spot)
	else:
		await play(30)
	await shot("shelter7")
	# the Custodian, stage 1 then cracked
	start(5)
	var cu = await fight()
	await watch(cu, 120)
	await shot("custodian1")
	main.sim.hurt_enemy(cu, cu.hp - cu.max * 0.49, main.sim.player.id)
	await watch(cu, 260)
	await shot("custodian2")
	# Area 67: a drone pack
	start(6)
	s = main.sim
	s.enemies.clear()
	UsDeep.drone_pack(s, s.player.x + 2.5, s.player.y + 0.5, 5)
	await play(25)
	await shot("area67")
	# the Gatekeeper, then the pilot out
	start(8)
	var gk = await fight()
	await watch(gk, 140)
	await shot("gatekeeper1")
	main.sim.hurt_enemy(gk, gk.hp - gk.max * 0.49, main.sim.player.id)
	await watch(gk, 220)
	await shot("gatekeeper2")
	# the Visitor, then the field failing
	start(9)
	var vi = await fight()
	await watch(vi, 140)
	await shot("visitor1")
	main.sim.hurt_enemy(vi, vi.hp - vi.max * 0.49, main.sim.player.id)
	await watch(vi, 330)
	await shot("visitor2")
	main.queue_free()
	for i in 10: await process_frame
	quit()
