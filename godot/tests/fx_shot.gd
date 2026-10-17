extends SceneTree
## Tracers and painted kill finishers, the same sheets tools/fx_ref.js paints in the browser:
##   xvfb-run godot --path godot --rendering-driver opengl3 --script res://tests/fx_shot.gd -- out_prefix


class Sheet extends Node2D:
	var what := ""

	func _draw() -> void:
		var x := Ctx2D.new(self)
		var C := PalLocker.catalog()
		if what == "tracers":
			var keys: Array = C.TRAILS.keys()
			draw_rect(Rect2(0, 0, 600, ceili(keys.size() / 4.0) * 26), Color("#1b2226"))
			for i in keys.size():
				var cx := (i % 4) * 150.0
				var cy := floorf(i / 4.0) * 26 + 13
				CosArt.paint_tracer(x, cx + 120, cy, cx + 10, cy, keys[i], 4, 1.3, false, 1)
		else:
			var keys: Array = C.FINISH_LIFE.keys()
			draw_rect(Rect2(0, 0, 800, ceili(keys.size() * 4 / 8.0) * 100), Color("#1b2226"))
			for i in keys.size():
				for j in 4:
					var n := i * 4 + j
					CosArt.paint_finish(x, keys[i], [0.12, 0.3, 0.55, 0.78][j], 1.5, (n % 8) * 100 + 50, floorf(n / 8.0) * 100 + 62)


func _init() -> void:
	var pre: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://fx"
	var C := PalLocker.catalog()
	for what in ["tracers", "finishes"]:
		var s := Sheet.new()
		s.what = what
		var vp := SubViewport.new()
		vp.size = Vector2i(600, ceili(C.TRAILS.size() / 4.0) * 26) if what == "tracers" else Vector2i(800, ceili(C.FINISH_LIFE.size() * 4 / 8.0) * 100)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.add_child(s)
		root.add_child(vp)
		for n in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s_%s.png" % [pre, what])
		vp.queue_free()
	print(",".join(C.FINISH_LIFE.keys()))
	quit()
