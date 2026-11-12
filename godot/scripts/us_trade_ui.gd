class_name UsTradeUI
extends CanvasLayer
var m
var panel: PanelContainer
var sheet: Control
var scroll: ScrollContainer
var rows: VBoxContainer
var merchant=-1
var was_paused=false
var signature=""
var refresh_t=0.0
const RARITY={"c":"COMMON","r":"RARE","e":"EPIC","l":"LEGENDARY","g":"GILDED"}
func _init(main):
	m=main
	layer=20
func open(index: int):
	if merchant<0: was_paused=m.sim.game.paused
	merchant=index
	# Online, block this player's input while everyone else's match continues.
	if not m.net.is_online(): m.sim.game.paused=true
	m.fire_blocked=true
	UsLoot.cancel_fire(m.sim.player)
	refresh()
func close():
	merchant=-1
	m.sim.game.paused=was_paused
	m.fire_blocked=true
	UsLoot.cancel_fire(m.sim.player)
	if is_instance_valid(sheet):
		remove_child(sheet)
		sheet.queue_free()
func state_signature() -> String:
	return JSON.stringify([m.sim.player.sal,m.sim.player.get("w2"),m.sim.player.up,m.sim.player.ui,m.sim.player.uj,m.sim.player.nades,m.sim.game.us.left,m.sim.game.us.got,m.sim.player.get("uPerks",[]),m.sim.player.get("uRelic","")])
func _process(dt: float):
	if merchant<0: return
	if not m.sim.understrip() or m.sim.game.phase=="over" or not m.sim.player.alive or m.sim.us.merchant_at(m.sim.player)!=merchant:
		close()
		return
	refresh_t-=dt
	if refresh_t<=0:
		refresh_t=.2
		if state_signature()!=signature: refresh()
func _label(text: String, size_: int, colour: Color=Color("#edf1e9")) -> Label:
	var l=Label.new()
	l.text=text
	l.add_theme_font_size_override("font_size",size_)
	l.add_theme_color_override("font_color",colour)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return l
func refresh():
	var old_scroll=scroll.scroll_vertical if is_instance_valid(scroll) else 0
	if is_instance_valid(sheet):
		remove_child(sheet)
		sheet.queue_free()
	signature=state_signature()
	sheet=Control.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sheet)
	var shade=ColorRect.new()
	shade.color=Color(0,0,0,.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.add_child(shade)
	var bounds=MarginContainer.new()
	bounds.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right"]: bounds.add_theme_constant_override("margin_"+edge,20)
	for edge in ["top","bottom"]: bounds.add_theme_constant_override("margin_"+edge,18)
	sheet.add_child(bounds)
	var center=HBoxContainer.new()
	bounds.add_child(center)
	var spacer=Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	center.add_child(spacer)
	panel=PanelContainer.new()
	panel.custom_minimum_size.x=minf(920,maxf(280,m.get_viewport_rect().size.x-40))
	center.add_child(panel)
	var style=StyleBoxFlat.new()
	style.bg_color=Color("#101c22")
	style.border_color=Color("#54736b")
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel",style)
	var right=Control.new()
	right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	center.add_child(right)
	var content=VBoxContainer.new()
	content.add_theme_constant_override("separation",10)
	panel.add_child(content)
	var p=m.sim.player
	var kind=m.sim.lay.merchants[merchant].kind
	content.add_child(_label({"trader":"THE TUNNEL TRADER","keeper":"THE SHRINE KEEPER","collector":"THE COLLECTOR","lift":"THE LIFT MERCHANT"}[kind],26))
	content.add_child(_label("%d SALVAGE · Supplies for the descent" % p.sal,16,Color("#efd347")))
	scroll=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	rows=VBoxContainer.new()
	rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",10)
	scroll.add_child(rows)
	var stock=m.sim.lay.merchants[merchant].stock
	for i in stock.size():
		var item=stock[i]
		var gear=item.gear if item.has("gear") else {"kind":"consumable","k":item.k}
		var price=int(floor(item.price*(1.25 if UsLoot.relic(p,"x_deck") else 1)*(.75 if UsLoot.has(p,"p_comped") else 1)+.5))
		var bought=(m.sim.game.us.got[merchant][i] & (1<<p.slot))!=0 if item.has("gear") else m.sim.game.us.left[merchant][i]<=0
		var card=PanelContainer.new()
		rows.add_child(card)
		var row=HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		card.add_child(row)
		if gear.kind=="weapon":
			var image=TextureRect.new()
			image.texture=UsWeapons.icon(gear.w.id)
			image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.custom_minimum_size=Vector2(136,100)
			row.add_child(image)
		var details=VBoxContainer.new()
		details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(details)
		var colour=Color(UsView3D.loot_col(gear))
		details.add_child(_label(UsLoot.label(gear),19,colour))
		if gear.kind=="weapon": details.add_child(_label(RARITY[gear.w.r],12,colour))
		details.add_child(_label(UsLoot.description(gear),14))
		var button=Button.new()
		button.custom_minimum_size=Vector2(116,50)
		button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		button.text="SOLD OUT" if bought else "%d SAL\nBUY" % price
		button.disabled=bought or p.sal<price or not UsLoot.can_apply(p,gear)
		button.pressed.connect(func():
			if m.net.guest():
				m.net.send_us({"t":"ub","m":merchant,"s":i})
				button.disabled=true
				return
			m.sim.us.buy(p,merchant,i)
			refresh())
		row.add_child(button)
	if kind in ["keeper","lift"]:
		rows.add_child(_label("CLASS UPGRADES",20,Color("#efd347")))
		for upgrade in Sim.UPG:
			var rank=int(p.up[upgrade.k])
			var button=Button.new()
			button.text="%s · %d/8 · %s" % [upgrade.name,rank,"MAX" if rank>=8 else "%d SAL" % upgrade.cost[rank]]
			button.custom_minimum_size.y=42
			button.disabled=rank>=8 or (rank<8 and p.sal<upgrade.cost[rank])
			button.pressed.connect(func():
				if m.net.guest(): m.net.send_upgrade(upgrade.k)
				else: m.sim.buy_upgrade(p,upgrade.k)
				refresh())
			rows.add_child(button)
	var done=Button.new()
	done.text="CLOSE (E / ESC)"
	done.custom_minimum_size.y=44
	done.pressed.connect(close)
	content.add_child(done)
	scroll.set_deferred("scroll_vertical",old_scroll)
