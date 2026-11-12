extends SceneTree
var failures=0
func check(ok: bool,label: String):
	print(("ok " if ok else "FAIL ")+label)
	if not ok: failures+=1
func _initialize(): call_deferred("run")
func frames(n: int=5):
	for i in n: await process_frame
func run():
	PalAccount.offline=true
	var main=load("res://main.tscn").instantiate()
	root.add_child(main)
	main.locker.persist=false
	main.profile.persist=false
	await frames()
	main.demo=false
	main.menus.close()
	main.run_sp=0
	main.draft_wave=1
	main.settings.data.tips=false
	main.sim.new_game(1234,"normal",{},{"mode":"understrip"})
	main.sim.enemies.clear()
	var p=main.sim.player
	p.sal=1000
	var trader=main.sim.lay.merchants[0]
	p.x=trader.x
	p.y=trader.y
	main.do_action("armory")
	await frames()
	var shop=main.us_shop
	check(main._controls().get("fire",false)==false and main._controls().get("move",Vector2.ZERO)==Vector2.ZERO,"shop blocks combat and movement")
	var images=0
	for n in ArtLibrary._all(shop.rows):
		if n is TextureRect and n.texture!=null: images+=1
	check(images>0,"shop contains rendered images of its actual guns")
	for size_ in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,900)]:
		root.size=size_
		shop.refresh()
		await frames()
		var r=shop.panel.get_global_rect()
		check(r.position.x>=0 and r.position.y>=0 and r.end.x<=size_.x+1 and r.end.y<=size_.y+1,"shop panel fits %dx%d" % [size_.x,size_.y])
		check(shop.scroll.size.y>200,"shop has a scrolling item list")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../bench/")+"playtest-shop-%d.png" % size_.x)
	# Buy through the real button, then ensure the UI reflects the stock and salvage change.
	var gear_slot=-1
	for i in trader.stock.size():
		if trader.stock[i].has("gear"): gear_slot=i; break
	var money=p.sal
	var card=shop.rows.get_child(gear_slot)
	var buy=card.get_child(0).get_child(card.get_child(0).get_child_count()-1)
	buy.pressed.emit()
	await frames()
	check(p.sal<money and p.w2!=null,"shop button buys the displayed gun")
	check((main.sim.game.us.got[0][gear_slot] & (1<<p.slot))!=0,"purchase marks personal gun stock sold")
	main.do_action("armory")
	check(not main.sim.game.paused and main.fire_blocked,"closing restores solo play and requires releasing the menu click")
	# The same model is attached in hand, and used by every gun drop.
	root.size=Vector2i(1280,720)
	p.aim=Vector2(1,0)
	main.mouse_seen=true
	main.sim.game.paused=true
	for i in UsWeapons.IDS.size():
		main.sim.us.drop_loot(p.x+(i%3-1)*1.2,p.y+1.8+floori(i/3.0)*1.2,{"kind":"weapon","w":{"id":UsWeapons.IDS[i],"r":"r","mods":[]}})
	main.v.cam_snap(p.x,p.y)
	await frames(12)
	var guns=[]
	for n in ArtLibrary._all(main.v3.actors):
		if n.name=="UnderstripWeapon" and n.is_visible_in_tree(): guns.append(n)
	check(guns.size()==1 and guns[0].get_meta("weapon_id")==p.w2.id,"equipped second gun displays its custom model")
	var floor_guns=[]
	for n in ArtLibrary._all(main.v3.world):
		if n.has_meta("weapon_id") and n.is_visible_in_tree(): floor_guns.append(n)
	check(floor_guns.size()==UsWeapons.IDS.size(),"all nine floor guns use their matching custom models")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../bench/")+"playtest-guns-in-world.png")
	main.sim.game.paused=false
	main.sim.dispose()
	main.queue_free()
	await frames()
	print("PASS understrip_playtest_ui" if failures==0 else "FAIL understrip_playtest_ui")
	quit(1 if failures else 0)
