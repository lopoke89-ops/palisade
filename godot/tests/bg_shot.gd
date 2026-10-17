extends SceneTree
## Every lobby background, the same sheet tools/bg_ref.js paints in the browser:
##   xvfb-run godot --path godot --rendering-driver opengl3 --script res://tests/bg_shot.gd -- out.png [t]


class Sheet extends Node2D:
	var t := 1.3

	var pool: Array = []

	func _draw() -> void:
		var ids: Array = Backgrounds.ids()
		var x := Ctx2D.new(self).layered(pool)   # 'lighter' adds light, as the canvas does
		for i in ids.size():
			x.save()
			x.translate((i % 6) * 320, floorf(i / 6.0) * 200)
			x.begin_path()
			x.rect(0, 0, 320, 200)
			x.clip()
			Backgrounds.draw(x, ids[i], 320, 200, t)
			x.restore()


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var s := Sheet.new()
	if args.size() > 1:
		s.t = float(args[1])
	var vp := SubViewport.new()
	vp.size = Vector2i(6 * 320, ceili(Backgrounds.ids().size() / 6.0) * 200)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(s)
	root.add_child(vp)
	var t0 := Time.get_ticks_msec()
	for n in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	print("frame ms ", (Time.get_ticks_msec() - t0) / 4)
	vp.get_texture().get_image().save_png(args[0] if args.size() > 0 else "user://bg.png")
	Ctx2D.free_pool(s.pool)
	quit()
