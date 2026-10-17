extends SceneTree
## The wardrobe contact sheet (the same grid tools/wardrobe_ref.js paints in the browser), and a look parity check:
##   xvfb-run godot --path godot --rendering-driver opengl3 --script res://tests/wardrobe_shot.gd -- out.png


class Sheet extends Node2D:
	var list: Array = []

	func _draw() -> void:
		var C := 14
		var CW := 92.0
		var CH := 104.0
		draw_rect(Rect2(0, 0, C * CW, ceili(list.size() * 2.0 / C) * CH), Color("#1b2226"))
		for i in list.size():
			for k in 2:
				var n := i * 2 + k
				Wardrobe.draw(self, list[i].look, 3.6 if k else 0.5, 2.0, 1.9, (n % C) * CW + CW / 2, floorf(n / float(C)) * CH + CH - 14, false)


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://wardrobe.png"
	var list: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/wardrobe_looks.json"))
	var bad := 0
	for e in list:
		var mine := Wardrobe.look_for({"skin": e.skin, "hat": e.hat}, e.cls)
		var theirs: Dictionary = e.look
		var keys := {}
		for k in theirs.keys() + mine.keys():
			keys[k] = true
		for k in keys:
			var a = mine.get(k)
			var b = theirs.get(k)
			if (a is int or a is float) and (b is int or b is float):
				if is_equal_approx(float(a), float(b)):
					continue
			if str(a) != str(b):
				bad += 1
				print("  look %s/%s/%s: %s godot %s browser %s" % [e.skin, e.hat, e.cls, k, a, b])
	print("looks: %d of %d differ" % [bad, list.size()])
	var s := Sheet.new()
	s.list = list
	var vp := SubViewport.new()
	vp.size = Vector2i(14 * 92, ceili(list.size() * 2.0 / 14) * 104)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(s)
	root.add_child(vp)
	for n in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
