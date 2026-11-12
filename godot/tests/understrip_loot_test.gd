extends SceneTree
var fails=0
func same(a, b) -> bool:
	if (a is int or a is float) and (b is int or b is float): return is_equal_approx(float(a),float(b))
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for k in a:
			if not b.has(k) or not same(a[k],b[k]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in a.size():
			if not same(a[i],b[i]): return false
		return true
	return a==b
func check(value: bool, label: String):
	print(("ok " if value else "FAIL ")+label)
	if not value: fails+=1
func _initialize():
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://tests/understrip_loot_fixture.json"))
	for row in fixture:
		if row[3].has("sal"): row[3].sal=int(row[3].sal)
		var got=UsLoot.roll(PalUnderstripGen.Rng.new(int(row[0])),row[2],int(row[1]))
		if got!=row[3]:
			push_error("Loot mismatch %s got %s" % [row,got])
			quit(1)
			return
	check(true,"540 browser loot rolls match")
	var stocks=JSON.parse_string(FileAccess.get_file_as_string("res://tests/understrip_stock_fixture.json"))
	for row in stocks:
		var rng=PalUnderstripGen.Rng.new(int(row[0]))
		var got=UsLoot.stock(rng,int(row[1])) if row[2]=="trader" else (UsLoot.lift_stock(rng,int(row[1])) if row[2]=="lift" else UsLoot.collector_stock(rng,int(row[1])))
		if not same(got,row[3]):
			push_error("Stock mismatch %s got %s" % [row,got])
			quit(1)
			return
	check(true,"180 browser merchant stocks match")
	var populations=JSON.parse_string(FileAccess.get_file_as_string("res://tests/understrip_population_fixture.json"))
	for row in populations:
		var level=PalUnderstripGen.generate(PalUnderstripGen.load_kit(int(row[0])),int(row[1]))
		if not same(SimUnderstrip.populate(level,int(row[0])),row[2]):
			push_error("Population mismatch region %s seed %s" % [row[0],row[1]])
			quit(1)
			return
	check(true,"12 browser raider populations match including unsigned seeds")
	var s=Sim.new()
	s.new_game(1234,"normal",{}, {"mode":"understrip"})
	var p=s.player
	var w={"id":"w_sawnoff","r":"r","mods":["m_mag"]}
	check(UsLoot.apply(s,p,{"kind":"weapon","w":w}) and p.wSel==1 and p.gun.mag==3 and p.w2.res==24,"second weapon equips with tier, magazine mod and reserve")
	p.ammo=1
	check(UsLoot.swap(s,p,0) and p.w2.ammo==1 and p.gun==p.C.gun,"putting second weapon away retains magazine and restores class gun")
	check(UsLoot.swap(s,p,1) and p.ammo==1,"swapping back restores saved magazine")
	s.enemies.clear()
	p.w2.res=1
	p.ammo=0
	p.sinceShot=9.0
	for i in 40: s.update(.05)
	check(p.ammo==1 and p.w2.res==0,"reload stops when second weapon reserve is exhausted")
	var merchant=s.lay.merchants[0]
	p.x=merchant.x
	p.y=merchant.y
	p.sal=200
	p.nades=0
	var left=s.game.us.left[0][0]
	check(s.us.buy(p,0,0) and p.nades==1 and p.sal==185 and s.game.us.left[0][0]==left-1,"merchant purchase charges salvage and decrements squad stock")
	p.sal=0
	check(not s.us.buy(p,0,0),"merchant refuses unaffordable purchase")
	var old=p.ujm
	check(UsLoot.apply(s,p,{"kind":"perk","k":"p_house"}) and p.ujm==old+1,"House Edge increases healing capacity")
	check(not UsLoot.apply(s,p,{"kind":"perk","k":"p_house"}),"duplicate perks are refused")
	s.us.drop_loot(p.x,p.y,{"kind":"salvage","sal":23})
	check(s.us.interact(p) and p.sal==23,"E picks up nearby loot")
	s.dispose()
	print("PASS understrip_loot" if fails==0 else "FAIL understrip_loot")
	quit(0 if fails==0 else 1)
