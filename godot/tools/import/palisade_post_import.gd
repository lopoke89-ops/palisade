@tool
extends EditorScenePostImport
## The model library's import script (art/3d/godot_demo/palisade_post_import.gd), applied to every GLB through the
## scene importer defaults in project.godot: vertex palettes on as linear albedo, loop flags from the clip names.
## Plus two lobby-environment fixes found rendering them here: the browser's "invisible ground" only catches shadows,
## and the sky gradient is its vertex colours, unlit (imported as-is, the floor came out white and the sky grey).
func _post_import(scene: Node) -> Object:
	visit(scene)
	return scene


func visit(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var colors = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			var material = node.mesh.surface_get_material(surface)
			if not (material is BaseMaterial3D):
				continue
			var nm := String(material.resource_name)
			if nm.contains("invisible ground"):
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.shadow_to_opacity = true
				material.albedo_color = Color(0, 0, 0, 0.55)
			elif nm.contains("sky gradient"):
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.emission_enabled = false
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = true
			elif colors != null and colors.size() > 0:
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = false
	if node is AnimationPlayer:
		for name in node.get_animation_list():
			node.get_animation(name).loop_mode = Animation.LOOP_LINEAR if String(name).ends_with("_Loop") else Animation.LOOP_NONE
	for child in node.get_children():
		visit(child)
