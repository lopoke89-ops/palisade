class_name UsTradeUI
extends CanvasLayer
var m
var panel: PanelContainer
var rows: VBoxContainer
var merchant=-1
func _init(main):
	m=main
	layer=20
func open(index: int):
	merchant=index
	m.sim.game.paused=true
	refresh()
func close():
	merchant=-1
	m.sim.game.paused=false
	if is_instance_valid(panel): panel.queue_free()
func refresh():
	if is_instance_valid(panel):
		remove_child(panel)
		panel.queue_free()
	panel=PanelContainer.new()
	panel.position=Vector2(160,80)
	panel.custom_minimum_size=Vector2(660,0)
	add_child(panel)
	rows=VBoxContainer.new()
	rows.add_theme_constant_override("separation",10)
	panel.add_child(rows)
	var p=m.sim.player
	var title=Label.new()
	var kind=m.sim.lay.merchants[merchant].kind
	title.text="%s — %d SALVAGE" % [{"trader":"THE TUNNEL TRADER","keeper":"THE SHRINE KEEPER","collector":"THE COLLECTOR","lift":"THE LIFT MERCHANT"}[kind],p.sal]
	title.add_theme_font_size_override("font_size",24)
	rows.add_child(title)
	var stock=m.sim.lay.merchants[merchant].stock
	for i in stock.size():
		var item=stock[i]
		var gear=item.gear if item.has("gear") else {"kind":"consumable","k":item.k}
		var price=int(floor(item.price*(1.25 if UsLoot.relic(p,"x_deck") else 1)*(.75 if UsLoot.has(p,"p_comped") else 1)+.5))
		var bought=(m.sim.game.us.got[merchant][i] & (1<<p.slot))!=0 if item.has("gear") else m.sim.game.us.left[merchant][i]<=0
		var button=Button.new()
		button.text="%s · %d SAL%s" % [UsLoot.label(gear),price," · SOLD OUT" if bought else ""]
		button.custom_minimum_size.y=46
		button.disabled=bought or p.sal<price or not UsLoot.can_apply(p,gear)
		button.pressed.connect(func():
			m.sim.us.buy(p,merchant,i)
			refresh())
		rows.add_child(button)
	if kind in ["keeper","lift"]:
		for upgrade in Sim.UPG:
			var rank=int(p.up[upgrade.k])
			var button=Button.new()
			button.text="%s · %d/8 · %s" % [upgrade.name,rank,"MAX" if rank>=8 else "%d SAL" % upgrade.cost[rank]]
			button.disabled=rank>=8 or (rank<8 and p.sal<upgrade.cost[rank])
			button.pressed.connect(func():
				m.sim.buy_upgrade(p,upgrade.k)
				refresh())
			rows.add_child(button)
	var done=Button.new()
	done.text="CLOSE (E / ESC)"
	done.pressed.connect(close)
	rows.add_child(done)
