extends SceneTree
var failures := 0
func check(ok: bool, label: String):
	print(("ok " if ok else "FAIL ") + label)
	if not ok: failures += 1
func _initialize():
	var s := Sim.new()
	s.new_game(1234,"normal",{},{"mode":"understrip"})
	s.enemies.clear()
	var p := s.player
	UsLoot.apply(s,p,{"kind":"weapon","w":{"id":"w_smg","r":"c","mods":[]}})
	UsLoot.swap(s,p,0)
	p.bLeft=2  # switch during the Soldier's unfinished burst
	UsLoot.swap(s,p,1)
	for i in 40: s.update(.05,{"fire":false,"pulls":0})
	check(s.shot_seq==0,"switching during a burst never fires the second gun without input")
	p.bLeft=2
	UsLoot.apply(s,p,{"kind":"weapon","w":{"id":"w_nailgun","r":"c","mods":[]}})
	var before := s.shot_seq
	for i in 40: s.update(.05,{"fire":false,"pulls":0})
	check(s.shot_seq==before,"picking up a gun cancels the previous weapon's burst")
	s.dispose()
	for level in [2,5,8,9]:
		var expected={2:2962.5,5:10000.0,8:31250.0,9:62500.0}[level]
		var boss_sim=Sim.new()
		boss_sim.new_game(1234,"normal",{},{"mode":"understrip","us_level":level})
		boss_sim.enemies.clear()
		UsDeep.wake(boss_sim)
		check(is_equal_approx(boss_sim.enemies[0].max,expected),"boss at level %d has %.1f solo Normal HP" % [level+1,expected])
		check(level!=9 or boss_sim.enemies[0].boss=="visitor","the finale stays the Visitor")
		boss_sim.dispose()
	for id in UsWeapons.IDS:
		var item={"kind":"weapon","w":{"id":id,"r":"g","mods":["m_dmg","m_reload"]}}
		check(UsLoot.description(item).length()>80,"%s has a description, stats and modifiers" % id)
		var node=UsWeapons.build(id)
		check(node.mesh.get_surface_count()==1,"%s has a custom single-surface mesh" % id)
		node.free()
		var audio=load("res://sfx/us_%s.wav" % id.trim_prefix("w_"))
		check(audio!=null and audio.get_length()>.05,"%s has its own firing sound" % id)
	print("PASS understrip_playtest" if failures==0 else "FAIL understrip_playtest")
	quit(1 if failures else 0)
