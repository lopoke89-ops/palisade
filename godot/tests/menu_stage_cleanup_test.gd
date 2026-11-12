extends SceneTree
func _initialize(): call_deferred("run")
func run():
	PalAccount.offline=true
	var main=load("res://main.tscn").instantiate()
	root.add_child(main)
	main.locker.persist=false
	main.profile.persist=false
	for i in 5: await process_frame
	var stage=main.menus.stage
	if not is_instance_valid(stage):
		push_error("Expected the real cached lobby stage")
		quit(1)
		return
	var stage_ref=weakref(stage)
	var aura_ref=weakref(stage.under)
	var viewport_ref=weakref(stage.vp)
	main.menus.close()
	if stage.get_parent()!=null or stage.under.get_parent()!=null:
		push_error("Expected the cached stage and aura to be detached during gameplay")
		quit(1)
		return
	main.queue_free()
	for i in 5: await process_frame
	var ok=stage_ref.get_ref()==null and aura_ref.get_ref()==null and viewport_ref.get_ref()==null
	print("PASS detached lobby viewport, stage and aura are freed" if ok else "FAIL detached lobby stage leaked")
	quit(0 if ok else 1)
