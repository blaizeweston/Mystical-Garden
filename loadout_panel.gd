extends VBoxContainer

const Participation = preload("res://expedition_participation.gd")
var game: Node
var depart_button: Button
var class_pick: OptionButton
var focus_options: VBoxContainer
var focus_buttons: Array[Button]=[]
var focus_previews: Array[Label] = []
var focus_class_id: int=0
var weapon_pick: OptionButton
var slots: Array[OptionButton]=[]
var slot_summaries: Array[Label] = []
var slot_details: Array[Label] = []
var slot_detail_buttons: Array[Button] = []
var slot_equip_buttons: Array[Button] = []
var part_previews: Array[Dictionary] = [{}, {}, {}]
var displayed_parts: Array = []
var cargo_pick: OptionButton
var pack_button: Button
var clear_button: Button
var description: RichTextLabel
var cargo_label: Label
var notice: Label
var elapsed:=0.0
var state_key:=""
var pending_slots: Dictionary={}
var pending_until: int=0
func _ready():
	var title:=Label.new()
	title.text="WEAPON CRAFTING"
	title.add_theme_font_size_override("font_size",22)
	add_child(title)
	var row:=HBoxContainer.new()
	add_child(row)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(460,405)
	row.add_child(scroll)
	var left:=VBoxContainer.new()
	left.custom_minimum_size.x=445
	scroll.add_child(left)
	label(left,"Class")
	class_pick=OptionButton.new()
	class_pick.fit_to_longest_item=false
	for c in game.Classes.DEFINITIONS.size(): class_pick.add_item(game.Classes.DEFINITIONS[c].name,c)
	left.add_child(class_pick)
	class_pick.item_selected.connect(func(index): pending_slots.clear();game.send_garden_action("class_%d"%class_pick.get_item_id(index)))
	focus_options=VBoxContainer.new()
	left.add_child(focus_options)
	focus_options.add_theme_constant_override("separation",10)
	label(focus_options,"Choose a starting focus")
	for lane in 3:
		var choice := VBoxContainer.new()
		choice.add_theme_constant_override("separation",3)
		focus_options.add_child(choice)
		var focus_button := Button.new()
		choice.add_child(focus_button)
		focus_buttons.append(focus_button)
		var preview := label(choice,"")
		preview.add_theme_font_size_override("font_size",14)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_previews.append(preview)
		focus_button.pressed.connect(func():
			var request:=preload("res://connected_class_tree.gd").REQUEST_OFFSET+lane
			game.send_garden_action("learn_%d_%d"%[focus_class_id,request]))
	focus_options.hide()
	label(left,"Weapon")
	weapon_pick=OptionButton.new()
	weapon_pick.fit_to_longest_item=false
	left.add_child(weapon_pick)
	weapon_pick.item_selected.connect(func(index): game.send_garden_action("loadweapon_%d"%weapon_pick.get_item_id(index)))
	var pages:=TabContainer.new()
	pages.custom_minimum_size.x=445
	left.add_child(pages)
	var plant_page:=VBoxContainer.new()
	plant_page.name="Plant slots"
	pages.add_child(plant_page)
	var monster_page:=VBoxContainer.new()
	monster_page.name="Monster cargo"
	pages.add_child(monster_page)
	for slot in 3:
		label(plant_page,game.Weapons.SLOT_NAMES[slot])
		var options := HBoxContainer.new()
		plant_page.add_child(options)
		var option:=OptionButton.new()
		option.allow_reselect=true
		option.fit_to_longest_item=false
		option.clip_text=true
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		options.add_child(option)
		slots.append(option)
		option.item_selected.connect(func(_index): show_part_preview(slot))
		var equip := Button.new()
		equip.text = "Equip"
		options.add_child(equip)
		slot_equip_buttons.append(equip)
		equip.pressed.connect(func(): select_part(slot,option.get_selected_id()))
		var info := Button.new()
		info.text = "Details"
		info.toggle_mode = true
		options.add_child(info)
		slot_detail_buttons.append(info)
		var summary := label(plant_page,"")
		summary.add_theme_font_size_override("font_size",13)
		slot_summaries.append(summary)
		var details := label(plant_page,"")
		details.add_theme_font_size_override("font_size",13)
		details.hide()
		slot_details.append(details)
		info.toggled.connect(func(expanded: bool): details.visible = expanded)
	label(monster_page,"Pack monster parts to graft at Wilds altars.")
	cargo_pick=OptionButton.new()
	cargo_pick.fit_to_longest_item=false
	monster_page.add_child(cargo_pick)
	pack_button=Button.new()
	pack_button.text="Pack one"
	monster_page.add_child(pack_button)
	pack_button.pressed.connect(func():
		if cargo_pick.selected>=0: game.send_garden_action("pack_%d"%cargo_pick.get_item_id(cargo_pick.selected)))
	clear_button=Button.new()
	clear_button.text="Unpack all"
	monster_page.add_child(clear_button)
	clear_button.pressed.connect(func(): game.send_garden_action("clearpack"))
	cargo_label=label(monster_page,"")
	cargo_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	cargo_label.custom_minimum_size.x=420
	var right:=VBoxContainer.new()
	row.add_child(right)
	description=RichTextLabel.new()
	description.custom_minimum_size=Vector2(350,366)
	description.bbcode_enabled=true
	right.add_child(description)
	notice=label(self,"")
	notice.custom_minimum_size.x=800
	notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_font_size_override("font_size",13)
	var tree_button:=Button.new()
	tree_button.text="Class tree"
	var navigation:=HBoxContainer.new();add_child(navigation);navigation.add_child(tree_button);tree_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	tree_button.pressed.connect(func(): game.progression_view.open_from_crafting())
	var route:=Button.new();route.text="Change destination";navigation.add_child(route);route.pressed.connect(func(): game.send_garden_action("destination"))
	depart_button=Button.new()
	depart_button.text="Craft weapon & enter the Wilds"
	add_child(depart_button)
	depart_button.pressed.connect(func():
		if game.party_travel_state().get("ready",false): game.send_travel_ready(true)
		else: game.send_garden_action("depart"))
	var close:=Button.new()
	close.text="Close"
	add_child(close)
	close.pressed.connect(func(): game.toggle_overlay(null))
	refresh()
func label(parent: Control,value: String) -> Label:
	var result:=Label.new()
	result.text=value
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(result)
	return result
func player() -> Dictionary:
	var id: int=game.HOST if game.multiplayer.is_server() else game.multiplayer.get_unique_id()
	return game.players.get(id,{})
func _process(delta: float):
	if not is_visible_in_tree(): return
	elapsed+=delta
	if elapsed>.25: elapsed=0;refresh()
func select_part(slot: int,part: int) -> void:
	pending_slots[slot]=part;pending_until=Time.get_ticks_msec()+2000
	game.send_garden_action("loadpart_%d_%d"%[slot,part])
	state_key="";refresh()
func show_part_preview(slot: int) -> void:
	var part := slots[slot].get_selected_id()
	var preview: Dictionary = part_previews[slot].get(part, {})
	var equipped := part == int(displayed_parts[slot])
	var brief: String = preview.get("summary","")
	slot_summaries[slot].text = brief if equipped else "Preview · " + brief
	slot_equip_buttons[slot].disabled = equipped or slots[slot].disabled or part < 0
	slot_equip_buttons[slot].text = "Unequip" if part == 0 and not equipped else "Equip"
	var detail: String = preview.get("detail","")
	slot_detail_buttons[slot].disabled = detail.is_empty()
	if detail.is_empty():
		slot_detail_buttons[slot].set_pressed_no_signal(false)
	slot_details[slot].text = detail
	slot_details[slot].visible = slot_detail_buttons[slot].button_pressed


func refresh():
	var p:=player()
	var affinity_api = preload("res://affinity_build.gd")
	if p.is_empty(): return
	var c:=int(p.get("frame",0))
	var prepared: bool=not Participation.is_wild(p)
	var counts: Array=game.stored_counts(p) if game.multiplayer.is_server() else p.get("stored_parts",game.Parts.empty_counts())
	var parts: Array=[p.get("prepared",0),p.get("prepared_secondary",0),p.get("prepared_catalyst",0)] if prepared else [p.get("weapon",0),p.get("secondary",0),p.get("catalyst",0)]
	if Time.get_ticks_msec()>pending_until or not prepared: pending_slots.clear()
	for slot in pending_slots.keys():
		if int(parts[slot])==int(pending_slots[slot]): pending_slots.erase(slot)
		else: parts[slot]=int(pending_slots[slot])
	var cargo: Array=p.get("cargo_plan",game.Parts.empty_counts())
	var profile: Dictionary=p.get("character",game.guest_character.data)
	var key:=str([c,p.get("weapon_kind",0),counts,parts,cargo,profile])
	if key!=state_key:
		state_key=key
		displayed_parts = parts
		var resolved := affinity_api.resolve(c,int(p.get("weapon_kind",0)),parts,profile)
		class_pick.select(c)
		weapon_pick.clear()
		for i in game.Classes.DEFINITIONS[c].weapons.size(): weapon_pick.add_item(game.Classes.DEFINITIONS[c].weapons[i].name,i)
		weapon_pick.select(int(p.get("weapon_kind",0)))
		for slot in 3:
			var option: OptionButton=slots[slot]
			option.clear()
			option.add_item("Empty",0)
			part_previews[slot].clear()
			var slot_name: String = affinity_api.SLOTS[slot]
			part_previews[slot][0] = affinity_api.slot_preview(resolved,slot_name,0)
			for part in range(1,game.Parts.DEFINITIONS.size()):
				if not game.Parts.is_plant(part): continue
				var available: int=game.LoadoutMaterials.remaining(counts,parts,slot,part)
				if available<=0: continue
				var icon: String=game.Items.get_item(game.Items.part_id(part)).icon
				var part_title := "%s · %d available" % [game.Parts.part_name(part), available]
				option.add_icon_item(load(icon),part_title,part)
				option.get_popup().set_item_icon_max_width(option.item_count-1,28)
				var preview := affinity_api.slot_preview(resolved,slot_name,part)
				part_previews[slot][part] = preview
				option.get_popup().set_item_tooltip(option.item_count-1,preview.summary)
			option.select(maxi(0,option.get_item_index(int(parts[slot]))))
		var selected_cargo: int=cargo_pick.get_selected_id()
		cargo_pick.clear()
		var cargo_text: Array[String]=[]
		var total:=0
		for part in range(1,game.Parts.DEFINITIONS.size()):
			if not game.Parts.is_monster(part): continue
			var available:=maxi(0,int(counts[part])-int(cargo[part]))
			if available>0: cargo_pick.add_item("%s · %d available"%[game.Parts.part_name(part),available],part)
			if int(cargo[part])>0: cargo_text.append("%s x%d"%[game.Parts.part_name(part),cargo[part]])
			total+=int(cargo[part])
		if cargo_pick.get_item_index(selected_cargo)>=0: cargo_pick.select(cargo_pick.get_item_index(selected_cargo))
		cargo_label.text="Packed %d / %d: %s"%[total,game.monster_cargo_limit(),", ".join(cargo_text)]
	var allowed: bool=game.at_weapon_gate(p)
	depart_button.visible=game.at_weapon_gate(p)
	depart_button.disabled=not allowed
	depart_button.text="Not Ready" if game.party_travel_state().get("ready",false) else "Ready to Enter Wilds" if game.players.size()>1 else "Craft Weapon & Enter Wilds"
	var class_allowed: bool=(game.at_heart(p) and not game.participation.active()) or game.at_weapon_gate(p)
	class_pick.disabled=not class_allowed
	weapon_pick.disabled=not allowed
	for slot in slots.size():
		slots[slot].disabled = not allowed
		show_part_preview(slot)
	cargo_pick.disabled=not allowed
	pack_button.disabled=not allowed or cargo_pick.item_count==0 or cargo.reduce(func(a,b): return a+int(b),0)>=game.monster_cargo_limit()
	clear_button.disabled=not allowed
	var stats: Dictionary=game.weapon_stats(p,prepared) if game.multiplayer.is_server() else p.get("weapon_stats",{})
	var starting_tree := affinity_api.starting_tree(c,profile) if prepared else null
	focus_options.visible=starting_tree!=null
	if starting_tree!=null:
		focus_class_id=c
		depart_button.disabled=true
		depart_button.text="Choose a starting focus to enter"
		for lane in focus_buttons.size():
			var node: Dictionary=starting_tree.nodes[lane]
			focus_buttons[lane].text="%s · %s"%[starting_tree.LANES[lane],node.name]
			var candidate := profile.duplicate()
			candidate[starting_tree.profile_key] = starting_tree.state([node.id])
			var ability: Dictionary = game.Skills.resolve_in_world(game,c,0,candidate)
			var cooldown: int = game.Skills.Balance.cooldown(ability,stats)
			focus_previews[lane].text = "%s · %s cooldown\n%s" % [
				ability.name,game.Skills.Balance.seconds(cooldown),ability.description]
			focus_buttons[lane].tooltip_text = game.Skills.describe(ability,stats)
			focus_buttons[lane].disabled=not class_allowed
	var connected = game.Classes.connected_tree(c)
	var current_progression: bool = connected.eligible(profile) and connected.valid(profile)
	var level: int = connected.level(profile)
	var points: int = level-connected.path(profile).size() if current_progression else 0
	var focused: bool = current_progression and not connected.focus(profile).is_empty()
	if not current_progression:
		depart_button.disabled = true
		depart_button.text = "Review class progression at the Heart"
	var weapon_stats := stats.duplicate()
	if not prepared and stats.has("affinity_build"):
		var cards = preload("res://affinity_cards.gd")
		var applied: Dictionary = cards.totals(p) if game.multiplayer.is_server() else cards.applied_totals(p.get("affinity_run_cards", []))
		game.Weapons.tune_affinity_basic(weapon_stats, applied)
	var body: String="[b]%s · Lv %d[/b]\n%s\n%d class point(s) available\n\n%s"%[game.Classes.DEFINITIONS[c].name,level,game.Classes.DEFINITIONS[c].description,points,game.Weapons.describe(weapon_stats) if not weapon_stats.is_empty() else ""]
	for skill_slot in range(0 if focused else 1,2):
		var skill: Dictionary=game.Skills.resolve_in_world(game,c,skill_slot,profile)
		var info: String=game.Skills.describe(skill,stats)
		info=info.substr(info.find("\n")+1)
		body+="\n\n[b]%s[/b]\n%s"%[skill.name,info]
	description.text=body
	notice.text=("Uses one part per filled slot on departure. Selected parts are reserved for you.\nPacked monster parts need a Wilds altar. Unbanked cargo is lost on defeat." if allowed else "Craft and pack at the Wilds Gate.")
	if allowed:
		notice.text = "Browse plant parts to preview each slot. Equip confirms your choice. Empty slots keep native combat."
	if starting_tree!=null:
		notice.text = "Level 1 focus is available now. Choose it before departure. Plant slots are optional."
	elif not connected.eligible(profile):
		notice.text = "Historical investments are preserved. Refund this class at the Heart to activate its connected tree. Class XP is preserved."
	elif not connected.valid(profile):
		notice.text = "This connected class path needs review before it can change or enter combat."
	var travel: Dictionary=game.party_travel_state()
	if not travel.is_empty():
		var rows: Array=[]
		for member in travel.members: rows.append(str(member.name)+(": Ready" if member.ready else ": Not ready"))
		notice.text+="\n"+str(travel.get("goal","Party"))+": "+" / ".join(rows)
	elif not game.status.is_empty(): notice.text+="\n"+game.status

