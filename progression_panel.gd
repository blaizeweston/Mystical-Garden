extends VBoxContainer
const Seeds = preload("res://seed_catalog.gd")
const Parts = preload("res://weapon_parts.gd")
const Character = preload("res://character_profile.gd")
var care: Control
var game: Node
var tree_scroll: ScrollContainer
var scroll_reset_version: int=0
var tree: Control
var details: RichTextLabel
var tabs: TabBar
var first: OptionButton
var second: OptionButton
var breed_button: Button
var identify_button: Button
var notice: Label
var chosen := ""
var previewed := ""
var portraits := {}
var material_row: HBoxContainer
var material_pick: OptionButton
var material_preview: Label
var material_key: String=""
var heart_buttons: HBoxContainer
var heart_start_button: Button
var heart_infuse_button: Button
var heart_finale_button: Button
var tree_hint: Label
var class_pick: OptionButton
var learn_button: Button
var refund_button: Button
var inspected_class := 0
var from_crafting := false
var close_button: Button
var elapsed := 0.0
var list_key := ""
var nodes: Array = []
func _ready() -> void:
	var heading := Label.new()
	heading.text = "LIVING ROOTS"
	heading.add_theme_font_size_override("font_size",23)
	add_child(heading)
	tabs = TabBar.new()
	for name_text in ["Seeds", "Heart / Knowledge", "Classes", "Garden stories"]:
		tabs.add_tab(name_text)
	add_child(tabs)
	tabs.tab_changed.connect(change_tab)
	care=preload("res://garden_story_panel.gd").new();care.game=game;add_child(care)
	class_pick=OptionButton.new()
	for c in game.Classes.DEFINITIONS.size():
		class_pick.add_item("Class path: "+game.Classes.DEFINITIONS[c].name,c)
	add_child(class_pick)
	class_pick.item_selected.connect(func(index): inspected_class=class_pick.get_item_id(index);chosen="";previewed="";refresh())
	var row := HBoxContainer.new()
	add_child(row)
	var scroll := ScrollContainer.new()
	tree_scroll=scroll
	scroll.custom_minimum_size = Vector2(710,clampf(get_viewport_rect().size.y * 0.49,290,400))
	row.add_child(scroll)
	tree = preload("res://progression_tree.gd").new()
	scroll.add_child(tree)
	tree.node_selected.connect(select_node)
	tree.node_hovered.connect(func(id): previewed=id; show_details())
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 240
	row.add_child(side)
	details = RichTextLabel.new()
	details.custom_minimum_size = Vector2(240,330)
	details.bbcode_enabled = true
	details.scroll_active = true
	side.add_child(details)
	var hint := Label.new()
	tree_hint=hint
	hint.text = "Select a seed to inspect it. ? marks an undiscovered species."
	hint.add_theme_font_size_override("font_size",12)
	add_child(hint)
	var breeding := HBoxContainer.new()
	breeding.hide()
	add_child(breeding)
	first = OptionButton.new()
	second = OptionButton.new()
	for option in [first,second]:
		option.custom_minimum_size.x = 225
		breeding.add_child(option)
	breed_button = Button.new()
	breed_button.text = "Sacrifice / crossbreed"
	breeding.add_child(breed_button)
	breed_button.pressed.connect(breed)
	identify_button = Button.new()
	identify_button.text = "Identify a seed"
	breeding.add_child(identify_button)
	identify_button.pressed.connect(func(): game.send_garden_action("altar_identify"); refresh())
	first.item_selected.connect(func(_i): update_selection())
	second.item_selected.connect(func(_i): update_selection())
	var class_buttons:=HBoxContainer.new()
	add_child(class_buttons)
	learn_button=Button.new()
	learn_button.text="Learn · 1 point"
	class_buttons.add_child(learn_button)
	learn_button.pressed.connect(func():
		var pieces:=chosen.split("_")
		if pieces.size()==3 and pieces[2].is_valid_int():
			game.send_garden_action("learn_%d_%d"%[int(pieces[1]),int(pieces[2])])
		refresh())
	refund_button=Button.new()
	refund_button.text="Refund class points"
	refund_button.tooltip_text="Refund class choices at the Heart between expeditions."
	class_buttons.add_child(refund_button)
	refund_button.pressed.connect(func(): game.send_garden_action("respec_%d"%inspected_class);refresh())
	heart_buttons=HBoxContainer.new()
	add_child(heart_buttons)
	heart_start_button=Button.new()
	heart_start_button.text="Begin research"
	heart_buttons.add_child(heart_start_button)
	heart_start_button.pressed.connect(func():
		if chosen.begins_with("heart_"):
			var id:=chosen.trim_prefix("heart_");var node: Dictionary=game.HeartCatalog.get_node(id)
			if game.multiplayer.is_server() and not node.is_empty():
				var plan: Dictionary={}
				game.send_garden_action("heart_confirm:"+JSON.stringify({"id":id,"plan":plan}))
		refresh())
	heart_infuse_button=Button.new()
	heart_infuse_button.text="Offer 2 shared plant parts"
	heart_buttons.add_child(heart_infuse_button)
	heart_infuse_button.pressed.connect(func():
		game.send_garden_action("heart_infusion:"+JSON.stringify({"project":game.heart_state().get("active",""),"plan":offering_plan().parts}));refresh())
	heart_finale_button=Button.new()
	heart_finale_button.text="Face the Heart"
	heart_buttons.add_child(heart_finale_button)
	heart_finale_button.pressed.connect(func(): game.send_garden_action("awaken");game.toggle_overlay(null))
	material_row=HBoxContainer.new();add_child(material_row);var label:=Label.new();label.text="Research ingredients:";material_row.add_child(label)
	material_pick=OptionButton.new();material_pick.size_flags_horizontal=Control.SIZE_EXPAND_FILL;material_row.add_child(material_pick)
	material_pick.item_selected.connect(func(index):
		game.send_garden_action("heart_material_"+("auto" if index==0 else str(material_pick.get_item_metadata(index))));refresh())
	material_preview=Label.new();material_preview.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;material_preview.custom_minimum_size.x=900;add_child(material_preview)
	notice = Label.new()
	notice.custom_minimum_size.x = 900
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_font_size_override("font_size",12)
	add_child(notice)
	close_button=Button.new()
	close_button.text="Close  ·  O / Esc"
	close_button.pressed.connect(func():
		if from_crafting and game.at_weapon_gate(profile()):
			game.open_gate_preparation()
		else:
			game.toggle_overlay(null))
	add_child(close_button)
	refresh()
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			from_crafting=false
		else:
			request_tree_base())
func open_from_crafting() -> void:
	from_crafting=true
	if tabs.current_tab==2:
		change_tab(2)
	else:
		tabs.current_tab=2
	game.toggle_overlay(game.progression_menu)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	elapsed += delta
	if elapsed >= 0.25:
		elapsed = 0
		refresh()
func profile() -> Dictionary:
	var id: int = game.HOST if game.multiplayer.is_server() else game.multiplayer.get_unique_id()
	return game.players.get(id, {})
func known_flags() -> Array:
	var garden: Array = game.garden_snapshot() if game.multiplayer.is_server() else game.client_garden
	return garden[13] if garden.size()>13 else Seeds.counts(false)
func stocks() -> Array:
	var player := profile()
	if game.multiplayer.is_server() and not player.is_empty():
		return game.seed_reserve(player).stock
	return game.client_inventory[6] if game.client_inventory.size()>6 else Seeds.counts()
func selected_species(option: OptionButton) -> int:
	return option.get_item_id(option.selected) if option.selected>=0 else -1
func refresh() -> void:
	if game == null or tree == null:
		return
	var care_tab: bool=tabs.current_tab==3
	var class_tab: bool=tabs.current_tab==2
	var heart_tab: bool=tabs.current_tab==1
	care.visible=care_tab
	tree_scroll.get_parent().visible=not care_tab
	tree_hint.visible=not care_tab
	notice.visible=not care_tab
	class_pick.visible=class_tab
	learn_button.get_parent().visible=class_tab
	material_row.visible=heart_tab
	material_preview.visible=heart_tab
	heart_buttons.visible=heart_tab
	close_button.text="Back to weapon crafting" if from_crafting else "Close  ·  O / Esc"
	if care_tab: return
	var known := known_flags()
	var counts := stocks()
	nodes = seed_nodes(known,counts) if tabs.current_tab==0 else heart_nodes() if tabs.current_tab==1 else class_nodes()
	tree.set_nodes(nodes)
	var key := str(known)+str(counts)
	if key != list_key:
		list_key=key
		for option in [first,second]:
			var previous := selected_species(option)
			option.clear()
			for i in Seeds.NAMES.size():
				if i<known.size() and known[i] or counts[i]>0:
					option.add_item("%s · %d" % [Seeds.NAMES[i],counts[i]],i)
			var index: int = option.get_item_index(previous)
			if index>=0: option.select(index)
	var p := profile()
	var at_altar: bool = not p.is_empty() and not p.get("wild",false) and p.get("pos",Vector3.ZERO).distance_to(game.stage.altar_position())<=1.65
	var a := selected_species(first)
	var b := selected_species(second)
	var enough: bool = a>=0 and b>=0 and counts[a]>=(2 if a==b else 1) and counts[b]>=1
	breed_button.disabled = not at_altar or not enough
	identify_button.disabled = not at_altar
	refund_button.disabled=not game.at_heart(p) or game.expedition_active()
	var can_learn:=false
	if class_tab and preload("res://class_tree_access.gd").can_learn_here(game,p):
		var pieces:=chosen.split("_")
		var data: Dictionary=p.get("character",game.guest_character.data)
		if pieces.size()==3 and pieces[2].is_valid_int():
			var c:=int(pieces[1])
			var n:=int(pieces[2])
			var connected = game.Classes.connected_in_world(game,c,data)
			if connected != null:
				can_learn = connected.refusal(data,n).is_empty()
			else:
				can_learn=game.Classes.can_learn(data,c,n,Character.level(int(data.xp[c])))
	learn_button.disabled=not can_learn
	if heart_tab:
		var state: Dictionary=game.heart_state()
		var owns: bool=game.multiplayer.is_server() and game.at_heart(p) and not game.expedition_active()
		var can_offer: bool=game.at_heart(p) and not p.get("wild",false)
		var id: String=chosen.trim_prefix("heart_") if chosen.begins_with("heart_") else ""
		var definition: Dictionary=game.HeartCatalog.get_node(id)
		heart_start_button.disabled=not owns or definition.is_empty() or state.unlocked.has(id) or definition.has("memory")
		heart_start_button.text="Resume research" if state.get("paid",[]).has(id) and not state.unlocked.has(id) else "Begin research · %d Knowledge"%int(definition.get("insight",0))
		if owns and not definition.is_empty(): heart_start_button.disabled=not game.progress.heart.requirements(game.progress,id).is_empty()
		heart_infuse_button.disabled=not can_offer or str(state.get("active","")).is_empty() or int(offering_plan().missing)>0
		heart_finale_button.visible=bool((game.campaign_snapshot() if game.multiplayer.is_server() else game.client_campaign)[17])
		heart_finale_button.disabled=not owns
		material_pick.disabled=not can_offer
		var shared: Array=game.garden_snapshot() if game.multiplayer.is_server() else game.client_garden
		var material_signature: String=str(shared[5])+str(state.get("material_choice",""))
		if material_signature!=material_key:
			material_key=material_signature;material_pick.clear();material_pick.add_item("Common materials first · optional offering");material_pick.set_item_metadata(0,"auto")
			for i in game.Seeds.DEFINITIONS.size():
				material_pick.add_item("Only %s · %d available"%[game.Seeds.NAMES[i],shared[5][i]]);material_pick.set_item_metadata(i+1,str(game.Seeds.DEFINITIONS[i].id))
				if str(game.Seeds.DEFINITIONS[i].id)==state.get("material_choice",""): material_pick.select(i+1)
		var labels: Array[String]=[]
		for species in offering_plan().parts: labels.append("%d %s"%[offering_plan().parts[species],game.Seeds.NAMES[game.Seeds.index_of(species)]])
		material_preview.text="Optional offering · %s → %s less research."%[", ".join(labels) if int(offering_plan().missing)==0 else "not enough selected shared plant parts",time_text(float(state.get("offering_seconds",60)))]


	var seed_tab := tabs.current_tab==0
	first.visible=false
	second.visible=false
	breed_button.visible=false
	identify_button.visible=false
	notice.text = ("Combine seeds at the Altar. Failed combinations return materials and a clue." if at_altar else "Identify and combine seeds at the Altar.")
	if class_tab:
		var class_profile: Dictionary=p.get("character",game.guest_character.data)
		refund_button.text="Refund and switch to new tree" if game.Classes.Warden.legacy(class_profile,inspected_class) else "Refund class choices"
	if class_tab:
		var data: Dictionary=p.get("character",game.guest_character.data)
		var connected = game.Classes.connected_in_world(game,inspected_class,data)
		var level:=Character.level(int(data.xp[inspected_class]))
		var available: int=game.Classes.points(data,inspected_class,level)
		var class_name_text: String=game.Classes.DEFINITIONS[inspected_class].name
		if connected != null:
			if connected.valid(data):
				level = connected.level(data)
				available = level-connected.path(data).size()
				notice.text="%s level %d / %d · %d XP · %d available"%[class_name_text,level,
					connected.XP_THRESHOLDS.size(),data.xp[inspected_class],available]
			else:
				notice.text="Connected %s data needs review before it can change."%class_name_text
		elif game.Classes.Warden.legacy(data,inspected_class):
			notice.text="%s level %d · %d available · Refund at the Heart to switch to the new tree."%[class_name_text,level,available]
		else:
			notice.text="%s level %d · %d available · Choose a subclass, then follow a root to the next tier."%[class_name_text,level,available]
	tree_hint.text="Select an upgrade to inspect it. Roots mark your chosen path." if class_tab else "Select a seed to inspect it. ? marks an undiscovered species."
	if heart_tab:
		var state: Dictionary=game.heart_state()
		var g: Array=game.garden_snapshot() if game.multiplayer.is_server() else game.client_garden
		notice.text="Lifetime Knowledge %d · Available Knowledge %d · %s"%[g[6],state.get("insight",0),game.HeartCatalog.phase_name(int(state.get("phase",0)))]
		var research: String=state.get("active","")
		if not research.is_empty():
			var active_node: Dictionary=game.HeartCatalog.get_node(research)
			notice.text+="\nResearch: %s · %s remaining in Garden / %s in Wilds."%[active_node.name,time_text(float(state.get("remaining_seconds",0))),time_text(float(state.get("remaining_seconds",0))/3.0)]
		tree_hint.text="Select a technology. The host starts research at the Heart."
	if not game.status.is_empty():
		notice.text += "\n"+game.status
	show_details()
func seed_nodes(known: Array,counts: Array) -> Array:
	var result: Array=[]
	var tiers: Dictionary={}
	for i in Seeds.DEFINITIONS.size():
		var d: Dictionary=Seeds.DEFINITIONS[i]
		if not tiers.has(d.tier): tiers[d.tier]=[]
		tiers[d.tier].append(i)
	var width := 700.0
	for row in tiers.values():
		width = maxf(width, row.size()*170.0+30.0)
	var base_y := maxf(325.0, (tiers.size()-1)*70.0+45.0)
	for i in Seeds.DEFINITIONS.size():
		var d: Dictionary=Seeds.DEFINITIONS[i]
		var siblings: Array=tiers[d.tier]
		var x: float=width/2.0+(siblings.find(i)-(siblings.size()-1)/2.0)*170.0
		var parents: Array=[]
		var visible_hint: bool=d.parents.is_empty()
		for parent in d.parents:
			parents.append(str(parent))
			visible_hint=visible_hint or known[parent]
		var unlocked: bool=known[i]
		var info := "[b]%s[/b]\n%s · Tier %d\n\n%s\n\nGrowth: %ds\nStored seeds: %d\nWilds: possible from encounter %d (favours %s)." % [
			d.name,d.rarity,d.tier,Seeds.modifier_text(i),d.grow_seconds,counts[i],d.wild_min,game.Campaign.NAMES[int(d.biome)]]
		if not unlocked:
			info="[b]Undiscovered possibility[/b]\n\n"+(d.hint if visible_hint else "Discover lower lineages to reveal a clue.")+"\n\nUnidentified seeds can also be found deeper in the Wilds."
		if unlocked and not parents.is_empty():
			info+="\n\nRecorded recipe: "+Seeds.NAMES[int(d.parents[0])]+" + "+Seeds.NAMES[int(d.parents[1])]+"."
		result.append({"id":str(i),"label":d.name,"parents":parents,"position":Vector2(x,base_y-(int(d.tier)-1)*70),"unlocked":unlocked,"detail":info,"color":d.color,"icon":portrait(str(d.id)) if unlocked else null,"summary":(str(d.name)+" · "+str(d.rarity)+"\n"+Seeds.modifier_text(i)) if unlocked else ("Undiscovered seed\n"+(str(d.hint) if visible_hint else "Discover lower lineages to reveal a clue."))})
	return result
func heart_nodes() -> Array:
	var state: Dictionary=game.heart_state()
	var g: Array=game.garden_snapshot() if game.multiplayer.is_server() else game.client_garden
	var campaign: PackedInt32Array=game.campaign_snapshot() if game.multiplayer.is_server() else game.client_campaign
	var known: Array=state.get("unlocked",["heart"])
	var result: Array=[]
	var total:=0
	for value in g[5]: total+=int(value)
	for d in game.HeartCatalog.DEFINITIONS:
		if not game.HeartCatalog.enabled(str(d.id)): continue
		var id: String=d.id
		var owned: bool=known.has(id)
		var parents: Array=[]
		var ready:=true
		for parent in d.parents:
			parents.append("heart_"+str(parent))
			ready=ready and known.has(parent)
		var research_progress:=int(state.get("progress",{}).get(id,0))
		var duration:=maxf(float(state.get("minimum_seconds",60)),float(d.research)*float(state.get("seconds_per_point",120)))
		var ratio: float=float(state.get("work",{}).get(id,research_progress*120.0))/duration
		var description: String="[b]%s[/b]\n%s\n\n"%[d.name,d.description]
		if d.has("memory"):
			var index:=int(d.memory)
			var current:=int(campaign[14+index])
			var needed:=int(game.Campaign.MEMORY_REQUIREMENTS[index])
			ratio=current/float(needed)
			description+="Guardian expeditions: %d/%d. Decode through the Living Archive."%[current,needed]
			ready=false
		else:
			description+="Requires %d lifetime Knowledge.\nStart cost: %d available Knowledge. No upfront plant parts.\n"%[d.knowledge,d.insight]
			description+="Research time: %s in Garden, %s in Wilds. Optional plant offerings speed it up.\n"%[time_text(duration),time_text(duration/3.0)]
			if not parents.is_empty():
				var names: Array[String]=[]
				for parent in d.parents: names.append(game.HeartCatalog.get_node(str(parent)).name)
				description+="Prerequisites: "+", ".join(names)+".\n"
			ready=ready and int(g[6])>=int(d.knowledge) and (state.get("paid",[]).has(id) or (int(state.get("insight",0))>=int(d.insight)))
			if d.get("fact","")=="veilcap":
				ready=ready and bool(g[7])
				description+="Discover Veilcap to study this memory.\n"
			if d.get("fact","")=="offshoots": description+="Resolve the three offshoot choices before the final recollection.\n"
			if state.get("paid",[]).has(id) and not owned:
				description+="This project is funded. Resume it without paying again.\n"
		description+="\nRestored." if owned else "\nResearch in progress." if state.get("active","")==id else "\nNot yet restored."
		var icon: Texture2D=null
		if id=="heart":
			var path: String="res://assets/ui/heart/phase_%d.png"%int(state.get("phase",0))
			if ResourceLoader.exists(path): icon=load(path)
		result.append({"id":"heart_"+id,"label":d.name,"parents":parents,"position":Vector2(float(d.position[0]),float(d.position[1])),"unlocked":owned,"detail":description,"summary":d.name+"\n"+d.description,"color":"#c6c789" if id=="perfect_recollection" else "#93b78a","available":ready,"progress":ratio if not owned else 0.0,"icon":icon})
	return result

func class_nodes() -> Array:
	var p:=profile()
	var data: Dictionary=p.get("character",game.guest_character.data)
	var c:=inspected_class
	var definition: Dictionary=game.Classes.DEFINITIONS[c]
	var level:=Character.level(int(data.xp[c]))
	var mask:=int(data.upgrades[c])
	if not game.Classes.Warden.legacy(data,c):
		return subclass_nodes(data,c,level,mask)
	var points: int=game.Classes.points(data,c,level)
	var base_y: float=65.0*(definition.nodes.size()/2+1)
	var node_indices: Dictionary={}
	for index in definition.nodes.size(): node_indices[str(definition.nodes[index].id)]=index
	var base: String="class_%d_base"%c
	var result: Array=[{"id":base,"label":definition.name,"parents":[],"position":Vector2(350,base_y),"unlocked":true,"color":"#c4be83","detail":"%s · Lv %d\n%s\n\nXP: %d · Available points: %d\n\nOne choice per row. Learn at the Heart or Wilds Gate between expeditions. Refunds are free at the Heart."%[definition.name,level,definition.description,int(data.xp[c]),points],"summary":definition.name+"\n"+definition.description}]
	for i in definition.nodes.size():
		var node: Dictionary=definition.nodes[i]
		var id: String="class_%d_%d"%[c,i]
		var parents: Array=[base] if node.get("parents",[]).is_empty() else []
		for parent in node.get("parents",[]):
			if node_indices.has(str(parent)): parents.append("class_%d_%d"%[c,int(node_indices[str(parent)])])
		var learned: bool=bool(mask & (1 << i))
		var change: Dictionary=node.get("skill_change",{})
		var effects: String=game.Classes.effect_text(node.effects,game.Life.Preview.enabled)
		if game.has_meta(&"combat_affinity_ruleset"):
			effects = preload("res://affinity_build.gd").class_effects_text(node.effects)
		var change_text: String=game.Skills.change_text(c,change)
		if game.Life.Preview.enabled and not change.is_empty():
			var candidate: Dictionary=data.duplicate(true)
			candidate.upgrades[c]=mask | (1 << i) if learned else (mask & ~(3 << (i-i%2))) | (1 << i)
			var affected: Array=[0,1] if change.kind in ["power","efficient"] else [int(change.get("slot",0))]
			var preview_stats: Dictionary = game.Classes.bonuses(candidate,c)
			if game.has_meta(&"combat_affinity_ruleset"):
				var resolver = preload("res://affinity_build.gd")
				var loadout: Dictionary = candidate.loadouts[c]
				preview_stats = resolver.native_stats(resolver.resolve(c,int(loadout.weapon),loadout.parts,0,candidate))
			change_text+="\n\n"+ "\n\n".join(affected.map(func(slot):return game.Skills.describe(game.Skills.resolve(c,slot,candidate),preview_stats)))
		var detail: String="%s\nRequires class level %d · 1 point\n\n%s\n\n%s\nChoose one upgrade in this row. Previous row must be learned. Choices stay with this character."%[node.name,node.level,effects+"\n\n"+change_text,"Learned" if learned else "Available" if game.Classes.can_learn(data,c,i,level) else "Locked / alternative path"]
		result.append({"id":id,"label":node.name,"parents":parents,"position":Vector2(245+(i%2)*210,base_y-70-int(node.tier)*65),"unlocked":learned,"detail":detail,"summary":node.name+"\n"+change_text+"\n"+effects,"color":"#a8bc86"})
	return result

func subclass_nodes(data: Dictionary, c: int, level: int, mask: int) -> Array:
	var tree_data = game.Classes.Warden
	var base := "class_%d_base"%c
	var title: String=game.Classes.DEFINITIONS[c].name
	var connected = game.Classes.connected_in_world(game,c,data)
	var use_connected := connected != null
	var nodes: Array = connected.nodes if use_connected else game.Classes.branch_nodes(c)
	var offset: int = connected.REQUEST_OFFSET if use_connected else tree_data.OFFSET
	var lanes: Array = connected.LANES if use_connected else tree_data.LANES
	var focus_id: String = connected.focus(data) if use_connected else game.Classes.focus_id(data,c)
	var focus: String=game.Classes.focus_name(focus_id)
	var starting_ability := ""
	if use_connected:
		level = connected.level(data)
		if not focus_id.is_empty():
			starting_ability = game.Skills.resolve(c,0,data,true).name
	var base_y := 628.0 if use_connected else 452.0
	var result: Array=[{"id":base,"label":title,"parents":[],"position":Vector2(350,base_y),
		"unlocked":true,"color":"#c4be83","detail":"%s · Lv %d\n%s\n\nChoose one node per tier at the Heart or Wilds Gate. The first choice teaches your subclass skill. Later tiers can follow a root to an adjacent branch."%[title,level,focus if not focus.is_empty() else "Choose a subclass"],
		"summary":title+" · "+", ".join(lanes),"caption":title}]
	var nodes_by_id: Dictionary={}
	for i in nodes.size():
		nodes_by_id[nodes[i].id]="class_%d_%d"%[c,offset+i]
	for i in nodes.size():
		var node: Dictionary=nodes[i]
		var index: int=offset+i
		var learned: bool = connected.path(data).has(node.id) if use_connected else bool(mask & (1<<index))
		var reason: String = connected.refusal(data,index) if use_connected else ""
		var ready: bool = reason.is_empty() if use_connected else game.Classes.can_learn(data,c,index,level)
		var parents: Array=[base] if node.parents.is_empty() else node.parents.map(func(id):return nodes_by_id[id])
		var description: String = node.description
		if use_connected:
			match c:
				0: description = preload("res://warden_connected_tree.gd").description(node,focus_id,starting_ability)
				1: description = game.Classes.Weaver.description(node,focus_id,starting_ability)
				2: description = game.Classes.Ranger.description(node,focus_id,starting_ability)
				3: description = game.Classes.Reaper.description(node,focus_id,starting_ability)
				4: description = preload("res://connected_class_tree.gd").focus_text(node.description,starting_ability)
			if c == 2 and node.id in ["trail_ward","clear_trail"] and not starting_ability.is_empty():
				var skill: Dictionary = game.Skills.resolve(c,0,data,true)
				description += "\nSupport radius: %.2f m." % skill.ranger_support_radius
		var summary: String=node.name+" · "+lanes[node.lane]+"\n"+description
		if game.has_meta(&"combat_affinity_ruleset"):
			var restriction: String = preload("res://affinity_build.gd").RESTRICTED_NODES.get(node.id, "")
			if not restriction.is_empty():
				summary = node.name + "\n" + restriction
				ready = false
		if node.tier==0:
			if game.Life.Preview.enabled:
				var candidate: Dictionary=data.duplicate(true)
				if not learned:
					if use_connected: candidate[connected.profile_key] = connected.state([node.id])
					else: candidate.upgrades[c]=1<<index
				summary+="\n"+game.Skills.describe(game.Skills.resolve(c,0,candidate,use_connected))
			else:
				summary+="\n"+str(tree_data.FOCUSES[node.id].description if c==0 else game.Classes.Subclasses.FOCUSES[c-1][node.lane].description)
		var detail: String=summary+"\n\nLevel %d · %s"%[node.level,"Learned" if learned else "Available" if ready else "Locked"]
		if use_connected and not ready and not learned:
			detail += "\n" + reason
		result.append({"id":nodes_by_id[node.id],"label":node.name,"parents":parents,
			"position":Vector2(145+205*int(node.lane),base_y-98-88*int(node.tier)),"unlocked":learned,
			"available":ready,"show_route":true,"color":tree_data.COLORS[node.lane],"summary":summary,"detail":detail,
			"caption":node.name if node.tier==0 else ""})
	return result


func select_node(id: String) -> void:
	previewed=""
	chosen=id
	tree.selected=id
	if tabs.current_tab==0:
		var d: Dictionary=Seeds.DEFINITIONS[int(id)]
		if d.parents.size()==2:
			for index in 2:
				var option: OptionButton=first if index==0 else second
				var item := option.get_item_index(int(d.parents[index]))
				if item>=0: option.select(item)
	refresh()
func show_details() -> void:
	for node in nodes:
		if node.id==(previewed if not previewed.is_empty() else chosen):
			details.text=node.get("summary",str(node.label)+"\n"+str(node.detail).split("\n\n")[0]) if not previewed.is_empty() else node.detail
			return
	if tabs.current_tab==1:
		details.text="[b]Heart / Knowledge[/b]\n\nResearch Garden upgrades and planting beds. Plant offerings speed up research.\n\nSelect a technology to inspect it."
		return
	if tabs.current_tab==2:
		details.text="[b]Class progression[/b]\n\nSelect a node to see its requirements and what it unlocks."
		return
	details.text="[b]Seed discoveries[/b]\n\nSelect a seed to inspect it. Roots connect discovered species. Undiscovered nodes may offer breeding clues."
func update_selection() -> void: refresh()
func breed() -> void:
	var a:=selected_species(first)
	var b:=selected_species(second)
	if a>=0 and b>=0:
		game.send_garden_action("breed_%d_%d"%[a,b])
	refresh()



func portrait(key: String) -> Texture2D:
	if not portraits.has(key):
		portraits[key]=load("res://assets/ui/seeds/"+key+".png")
	return portraits[key]



func change_tab(index: int) -> void:
	scroll_reset_version+=1
	chosen=""
	previewed=""
	tree.set_hover("")
	tree.selected=""
	if index==2 and class_pick!=null:
		inspected_class=int(profile().get("frame",0))
		class_pick.select(inspected_class)
	refresh()
	request_tree_base()



func time_text(seconds: float) -> String:
	var value:=maxi(0,ceili(seconds))
	return "%d:%02d"%[value/60,value%60]

func offering_plan() -> Dictionary:
	var state: Dictionary=game.heart_state()
	var shared: Array=game.garden_snapshot() if game.multiplayer.is_server() else game.client_garden
	var order: Array=[];var plan: Dictionary={};var left:=int(state.get("offering_cost",2))
	for i in game.Seeds.DEFINITIONS.size():
		if str(state.get("material_choice","")).is_empty() or str(game.Seeds.DEFINITIONS[i].id)==str(state.material_choice): order.append(i)
	order.sort_custom(func(a,b):return int(game.Seeds.DEFINITIONS[a].tier)<int(game.Seeds.DEFINITIONS[b].tier) if int(game.Seeds.DEFINITIONS[a].tier)!=int(game.Seeds.DEFINITIONS[b].tier) else a<b)
	for i in order:
		var take:=mini(maxi(0,int(shared[5][i])),left)
		if take>0: plan[str(game.Seeds.DEFINITIONS[i].id)]=take;left-=take
	return {"parts":plan,"missing":left}

func request_tree_base() -> void:
	if tabs==null or tabs.current_tab not in [1,2]: return
	scroll_reset_version+=1
	apply_tree_base.call_deferred(scroll_reset_version)
func apply_tree_base(version: int) -> void:
	# Containers need their visible layout before scrollbar limits are trustworthy.
	await get_tree().process_frame
	await get_tree().process_frame
	if version!=scroll_reset_version or not is_visible_in_tree() or tabs.current_tab not in [1,2]: return
	var bar:=tree_scroll.get_v_scroll_bar()
	tree_scroll.scroll_vertical=maxi(0,ceili(bar.max_value-bar.page))
	var base_id: String="heart_heart" if tabs.current_tab==1 else "class_%d_base"%inspected_class
	for node in nodes:
		if node.id==base_id:
			tree_scroll.scroll_horizontal=maxi(0,roundi(Vector2(node.position).x-tree_scroll.size.x*.5))
			break
