extends SceneTree
var fails=0
func check(value: bool, what: String):
	print(("ok " if value else "FAIL ")+what)
	if not value: fails+=1
func _initialize():
	call_deferred("run")
func run():
	PalAccount.offline=true
	var main=load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in 5: await process_frame
	main.demo=false
	main.menus.close()
	main.game_n+=1
	main.sim.new_game(1234,"normal",{}, {"mode":"understrip"})
	main.run_sp=0
	main.draft_wave=1
	var p=main.sim.player
	var trader=main.sim.lay.merchants[0]
	p.x=trader.x
	p.y=trader.y
	p.sal=500
	main.do_action("armory")
	check(is_instance_valid(main.us_shop) and main.us_shop.merchant==0 and main.sim.game.paused,"E opens trader sheet and pauses solo play")
	check(main.us_shop.rows.get_child_count()>3,"trader sheet lists stock and purchase buttons")
	main.do_action("armory")
	check(main.us_shop.merchant==-1 and not main.sim.game.paused,"E closes trader and resumes")
	p.hp=p.max*.5
	main.do_action("drink")
	check(p.uj==2 and p.ujT>0,"drink action consumes Lucky Juice")
	UsLoot.apply(main.sim,p,{"kind":"weapon","w":{"id":"w_nailgun","r":"c","mods":[]}})
	main.do_action("mat1")
	check(p.wSel==0,"1 selects class weapon")
	main.do_action("mat2")
	check(p.wSel==1,"2 selects second weapon")
	p.ui.flare=1
	main.do_action("piece")
	main.do_action("build")
	check(main.sim.game.us.flares.size()==1 and p.ui.flare==0,"F selects road flare and SPACE throws it")
	# the PLAY page offers the mode solo (the online room's picker doesn't until cross-play is ported)
	var S=main.settings.data.setup
	var was=S.mode
	S.mode="understrip"
	var rows=main.menus._rows_for("home")
	check(rows[0][2]=="UNDER THE STRIP" and rows[1][2]=="THE UNDERSTRIP","PLAY lists THE UNDERSTRIP's map and length")
	check(main.menus.US_SOLO[0]=="understrip" and main.menus.MODE_HINT.has("understrip"),"the length sheet offers it solo, with its hint")
	S.mode=was
	main.sim.dispose()
	main.queue_free()
	for i in 3: await process_frame
	print("PASS understrip_client" if fails==0 else "FAIL understrip_client")
	quit(0 if fails==0 else 1)
