extends SceneTree
var main
func _initialize(): call_deferred("run")
func frames(n: int=5):
	for i in n: await process_frame
func shot(name: String):
	await frames()
	await RenderingServer.frame_post_draw
	var file=ProjectSettings.globalize_path("res://../../bench/")+"v0125-visitor-"+name+".png"
	root.get_texture().get_image().save_png(file)
	print("SAVED ",file)
func run():
	PalAccount.offline=true
	main=load("res://main.tscn").instantiate()
	root.add_child(main)
	main.locker.persist=false
	main.profile.persist=false
	await frames()
	main.demo=false
	main.menus.close()
	main.run_sp=0
	main.draft_wave=1
	main.settings.data.tips=false
	main.sim.new_game(1234,"normal",{},{"mode":"understrip","us_seed":7,"us_level":9})
	var s=main.sim
	s.enemies.clear()
	var a=s.lay.arena
	var p=s.player
	p.hp=1e7
	p.max=1e7
	p.x=a.x+a.w/2+2
	p.y=a.y+a.h/2+3
	UsDeep.wake(s)
	s.game.us.gate=2
	var visitor=s.enemies[0]
	visitor.x=a.x+a.w/2
	visitor.y=a.y+a.h/2
	visitor.aim=Vector2(1,1).normalized()
	p.aim=Vector2(visitor.x-p.x,visitor.y-p.y).normalized()
	s.game.paused=true
	main.mouse_seen=true
	main.v.cam_snap(visitor.x,visitor.y+1)
	await shot("stage1")
	visitor.hp=visitor.max*.66
	UsDeep.think_visitor(s,visitor,.05)
	UsDeep.think_visitor(s,visitor,3.1)
	s.game.time+=4
	main.v.cam_snap(visitor.x+1,visitor.y+1)
	await shot("stage2")
	print("SUMMON ",UsDeep.add_key(7),"; Visitor still alive ",not visitor.dead)
	main.sim.dispose()
	main.queue_free()
	await frames(10)
	UsWeapons.meshes.clear()
	UsWeapons.icons.clear()
	ArtLibrary._lib=null
	await frames(5)
	print("RENDER COMPLETE")
	quit()
