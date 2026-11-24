extends VBoxContainer

const Classes = preload("res://class_catalog.gd")
const Skills = preload("res://skill_catalog.gd")
const Campaign = preload("res://campaign.gd")
const HeartCatalog = preload("res://heart_catalog.gd")
const Seeds = preload("res://seed_catalog.gd")
var care: Control
signal refresh_requested(selection: Dictionary)
signal requested(command: String, data: Dictionary)
var _facts: Dictionary = {}
var _inspect_active_class := false
var tree_scroll: ScrollContainer
var scroll_reset_version: int=0
var tree: Control
var details: RichTextLabel
var tabs: TabBar
var notice: Label
var chosen := ""
var previewed := ""
var portraits := {}
var heart_buttons: HBoxContainer
var heart_start_button: Button
var tree_hint: Label
var class_pick: OptionButton
var learn_button: Button
var refund_button: Button
var inspected_class := 0
var from_crafting := false
var close_button: Button
var elapsed := 0.0
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
	care=preload("res://garden_story_panel.gd").new();add_child(care)
	class_pick=OptionButton.new()
	for c in Classes.DEFINITIONS.size():
		class_pick.add_item("Class path: "+Classes.DEFINITIONS[c].name,c)
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
	var class_buttons:=HBoxContainer.new()
	add_child(class_buttons)
	learn_button=Button.new()
	learn_button.text="Learn · 1 point"
	class_buttons.add_child(learn_button)
	learn_button.pressed.connect(func():
		var pieces:=chosen.split("_")
		if pieces.size()==3 and pieces[2].is_valid_int():
			_garden_request("learn_%d_%d"%[int(pieces[1]),int(pieces[2])])
		refresh())
	refund_button=Button.new()
	refund_button.text="Refund class points"
	refund_button.tooltip_text="Refund class choices at the Heart between expeditions."
	class_buttons.add_child(refund_button)
	refund_button.pressed.connect(func(): _garden_request("respec_%d"%inspected_class);refresh())
	heart_buttons=HBoxContainer.new()
	add_child(heart_buttons)
	heart_start_button=Button.new()
	heart_start_button.text="Begin research"
	heart_buttons.add_child(heart_start_button)
	heart_start_button.pressed.connect(func():
		if chosen.begins_with("heart_"):
			var id:=chosen.trim_prefix("heart_");var node: Dictionary=HeartCatalog.get_node(id)
			if bool(_facts.get("is_host",false)) and not node.is_empty():
				_garden_request("heart_start_" + id)
		refresh())
	notice = Label.new()
	notice.custom_minimum_size.x = 900
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_font_size_override("font_size",12)
	add_child(notice)
	close_button=Button.new()
	close_button.text="Close  ·  O / Esc"
	close_button.pressed.connect(func(): requested.emit("close_progression",{"from_crafting":from_crafting}))
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
	requested.emit("open_progression",{})

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	elapsed += delta
	if elapsed >= 0.25:
		elapsed = 0
		refresh()
func _garden_request(action: String) -> void:
	requested.emit("garden_action",{"action":action})
func known_flags() -> Array:
	return _facts.get("known_seeds",Seeds.counts(false)).duplicate()
func stocks() -> Array:
	return _facts.get("seed_stock",Seeds.counts()).duplicate()

func refresh() -> void:
	if tree == null: return
	refresh_requested.emit({"tab":tabs.current_tab,"chosen":chosen})

func present(facts: Dictionary) -> void:
	if facts.is_empty() or tree == null: return
	_facts = facts.duplicate(true)
	if _inspect_active_class:
		inspected_class=int(_facts.class_id)
		class_pick.select(inspected_class)
		_inspect_active_class=false
	care.present(_facts.get("stories",{}))
	var care_tab: bool=tabs.current_tab==3
	var class_tab: bool=tabs.current_tab==2
	var heart_tab: bool=tabs.current_tab==1
	care.visible=care_tab
	tree_scroll.get_parent().visible=not care_tab
	tree_hint.visible=not care_tab
	notice.visible=not care_tab
	class_pick.visible=class_tab
	learn_button.get_parent().visible=class_tab
	heart_buttons.visible=heart_tab
	close_button.text="Back to weapon crafting" if from_crafting else "Close  ·  O / Esc"
	if care_tab: return
	var known := known_flags()
	var counts := stocks()
	nodes = seed_nodes(known,counts) if tabs.current_tab==0 else heart_nodes() if tabs.current_tab==1 else class_nodes()
	tree.set_nodes(nodes)
	var at_altar := bool(_facts.at_altar)
	refund_button.disabled=not bool(_facts.may_respec)
	var can_learn:=false
	if class_tab and bool(_facts.may_learn):
		var pieces:=chosen.split("_")
		var data: Dictionary=_facts.profile
		if pieces.size()==3 and pieces[2].is_valid_int():
			var c:=int(pieces[1])
			var n:=int(pieces[2])
			var connected = Classes.connected_tree(c)
			if connected != null:
				can_learn = connected.refusal(data,n).is_empty()
	learn_button.disabled=not can_learn
	if heart_tab:
		var state: Dictionary=_facts.get("heart",{})
		var owns: bool=bool(_facts.may_start_research)
		var id: String=chosen.trim_prefix("heart_") if chosen.begins_with("heart_") else ""
		var definition: Dictionary=HeartCatalog.get_node(id)
		heart_start_button.disabled=not owns or definition.is_empty() or state.unlocked.has(id) or definition.has("memory")
		heart_start_button.text="Unlocked" if state.unlocked.has(id) else "Unlock · %d Knowledge" % int(definition.get("insight",0))
		if owns and not definition.is_empty(): heart_start_button.disabled=not str(_facts.research_refusal).is_empty()
	notice.text = ("Combine seeds at the Altar. Failed combinations return materials and a clue." if at_altar else "Identify and combine seeds at the Altar.")
	if class_tab:
		var class_profile: Dictionary=_facts.profile
		refund_button.text="Refund historical class choices" if not Classes.connected_tree(inspected_class).eligible(class_profile) else "Refund class choices"
	if class_tab:
		var data: Dictionary=_facts.profile
		var connected = Classes.connected_tree(inspected_class)
		var class_name_text: String=Classes.DEFINITIONS[inspected_class].name
		if not connected.eligible(data):
			notice.text="%s has preserved historical investments. Refund this class at the Heart to activate its connected tree; Class XP is preserved." % class_name_text
		elif not connected.valid(data):
			notice.text="Connected %s data needs review before it can change." % class_name_text
		else:
			var level: int=connected.level(data)
			notice.text="%s level %d / %d · %d XP · %d available" % [class_name_text,level,
				connected.XP_THRESHOLDS.size(),data.xp[inspected_class],level-connected.path(data).size()]
	tree_hint.text="Select an upgrade to inspect it. Roots mark your chosen path." if class_tab else "Select a seed to inspect it. ? marks an undiscovered species."
	if heart_tab:
		var state: Dictionary=_facts.get("heart",{})
		var knowledge := int(_facts.knowledge)
		notice.text="Lifetime Knowledge %d · Available Knowledge %d · %s"%[knowledge,state.get("insight",0),HeartCatalog.phase_name(int(state.get("phase",0)))]
		tree_hint.text="Select a technology. The host unlocks it immediately at the Heart."
	if not str(_facts.notice).is_empty():
		notice.text += "\n"+str(_facts.notice)
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
		var recorded: bool=_facts.get("recorded_seed_recipes",[]).has(i)
		var visible_hint: bool=d.parents.is_empty()
		for parent in d.parents:
			if recorded: parents.append(str(parent))
			visible_hint=visible_hint or (known[parent] and not Seeds.wild_only(i))
		var unlocked: bool=known[i]
		var info := "[b]%s[/b]\n%s · Tier %d\n\n%s\n\nGrowth: %ds\nStored seeds: %d\nWilds: possible from encounter %d (favours %s)." % [
			d.name,d.rarity,d.tier,Seeds.modifier_text(i),d.grow_seconds,counts[i],d.wild_min,Campaign.NAMES[int(d.biome)]]
		if not unlocked:
			info="[b]Undiscovered possibility[/b]\n\n"+(d.hint if visible_hint else "Discover lower lineages to reveal a clue.")+"\n\nUnidentified seeds can also be found deeper in the Wilds."
		if not unlocked and Seeds.wild_only(i): info="An undiscovered species of the Wilds."
		if unlocked and (Seeds.wild_only(i) or d.parents.is_empty()): info+="\n\nNatural Wilds species. No seed-producing recipe."
		elif unlocked and not recorded: info+="\n\nSpecies discovered. Seed recipe untested."
		if unlocked and recorded:
			info+="\n\nRecorded recipe: "+Seeds.NAMES[int(d.parents[0])]+" + "+Seeds.NAMES[int(d.parents[1])]+"."
		result.append({"id":str(i),"label":d.name,"parents":parents,"position":Vector2(x,base_y-(int(d.tier)-1)*70),"unlocked":unlocked,"detail":info,"color":d.color,"icon":portrait(str(d.id)) if unlocked else null,"summary":(str(d.name)+" · "+str(d.rarity)+"\n"+Seeds.modifier_text(i)) if unlocked else ("An undiscovered species of the Wilds." if Seeds.wild_only(i) else "Undiscovered seed\n"+(str(d.hint) if visible_hint else "Discover lower lineages to reveal a clue."))})
	return result
func heart_nodes() -> Array:
	var state: Dictionary=_facts.get("heart",{})
	var knowledge := int(_facts.knowledge)
	var memories: Array=_facts.memories
	var known: Array=state.get("unlocked",["heart"])
	var result: Array=[]
	for d in HeartCatalog.DEFINITIONS:
		if not HeartCatalog.enabled(str(d.id)): continue
		var id: String=d.id
		var owned: bool=known.has(id)
		var parents: Array=[]
		var is_ready:=true
		for parent in d.parents:
			parents.append("heart_"+str(parent))
			is_ready=is_ready and known.has(parent)
		var ratio := 0.0
		var description: String="[b]%s[/b]\n%s\n\n"%[d.name,d.description]
		if d.has("memory"):
			var index:=int(d.memory)
			var current:=int(memories[index])
			var needed:=int(Campaign.MEMORY_REQUIREMENTS[index])
			ratio=current/float(needed)
			description+="Guardian expeditions: %d/%d. Decode through the Living Archive."%[current,needed]
			is_ready=false
		else:
			description+="Requires %d lifetime Knowledge.\nPrice: %d available Knowledge.\n"%[d.knowledge,d.insight]
			if not parents.is_empty():
				var names: Array[String]=[]
				for parent in d.parents: names.append(HeartCatalog.get_node(str(parent)).name)
				description+="Prerequisites: "+", ".join(names)+".\n"
			is_ready=is_ready and knowledge>=int(d.knowledge) and int(state.get("insight",0))>=int(d.insight)
		description+="\nRestored." if owned else "\nAvailable." if is_ready else "\nUnavailable."
		var icon: Texture2D=null
		if id=="heart":
			var path: String="res://assets/ui/heart/phase_%d.png"%int(state.get("phase",0))
			if ResourceLoader.exists(path): icon=load(path)
		result.append({"id":"heart_"+id,"label":d.name,"parents":parents,"position":Vector2(float(d.position[0]),float(d.position[1])),"unlocked":owned,"detail":description,"summary":d.name+"\n"+d.description,"color":"#93b78a","available":is_ready,"progress":ratio if not owned else 0.0,"icon":icon})
	return result

func class_nodes() -> Array:
	return connected_nodes(_facts.profile,inspected_class)

func connected_nodes(data: Dictionary, c: int) -> Array:
	var connected = Classes.connected_tree(c)
	var base := "class_%d_base" % c
	var title: String=Classes.DEFINITIONS[c].name
	var level: int=connected.level(data)
	var selected: Array=connected.path(data) if connected.eligible(data) else []
	var focus_id: String=connected.focus(data) if connected.eligible(data) else ""
	var focus: String=Classes.focus_name(focus_id)
	var starting_ability: String=Skills.resolve(c,0,data).name if not focus_id.is_empty() else ""
	var base_y := 628.0
	var introduction := "%s · Lv %d\n%s\n\nChoose one node per level through level 6. Follow a connected root into each next tier; crossing lanes preserves your starting Q." % [title,level,focus if not focus.is_empty() else "Choose a starting focus"]
	if not connected.eligible(data):
		introduction += "\n\nHistorical investments are preserved. Refund this class at the Heart to activate the connected tree without losing Class XP."
	var result: Array=[{"id":base,"label":title,"parents":[],"position":Vector2(350,base_y),
		"unlocked":true,"color":"#c4be83","detail":introduction,
		"summary":title+" · "+", ".join(connected.LANES),"caption":title}]
	var nodes_by_id: Dictionary={}
	for i in connected.nodes.size():
		nodes_by_id[connected.nodes[i].id]="class_%d_%d" % [c,connected.REQUEST_OFFSET+i]
	for i in connected.nodes.size():
		var node: Dictionary=connected.nodes[i]
		var index: int=connected.REQUEST_OFFSET+i
		var learned: bool=selected.has(node.id)
		var reason: String=connected.refusal(data,index)
		var is_ready := reason.is_empty()
		var parents: Array=[base] if node.parents.is_empty() else node.parents.map(func(id):return nodes_by_id[id])
		var description: String=node.description
		match c:
			0: description=preload("res://warden_connected_tree.gd").description(node,focus_id,starting_ability)
			1: description=Classes.Weaver.description(node,focus_id,starting_ability)
			2: description=Classes.Ranger.description(node,focus_id,starting_ability)
			3: description=Classes.Reaper.description(node,focus_id,starting_ability)
			4: description=preload("res://connected_class_tree.gd").focus_text(node.description,starting_ability)
		if c==2 and node.id in ["trail_ward","clear_trail"] and not starting_ability.is_empty():
			description+="\nSupport radius: %.2f m." % Skills.resolve(c,0,data).ranger_support_radius
		var summary: String=node.name+" · "+connected.LANES[node.lane]+"\n"+description
		if node.tier==0 and connected.eligible(data):
			var candidate: Dictionary=data.duplicate(true)
			if not learned:candidate[connected.profile_key]=connected.state([node.id])
			summary+="\n"+Skills.describe(Skills.resolve(c,0,candidate))
		var detail: String=summary+"\n\nLevel %d · %s" % [node.level,"Learned" if learned else "Available" if is_ready else "Locked"]
		if not is_ready and not learned:detail+="\n"+reason
		result.append({"id":nodes_by_id[node.id],"label":node.name,"parents":parents,
			"position":Vector2(145+205*int(node.lane),base_y-98-88*int(node.tier)),"unlocked":learned,
			"available":is_ready,"show_route":true,"color":Classes.Warden.COLORS[node.lane],
			"summary":summary,"detail":detail,"caption":node.name if node.tier==0 else ""})
	return result

func select_node(id: String) -> void:
	previewed=""
	chosen=id
	tree.selected=id
	refresh()
func show_details() -> void:
	for node in nodes:
		if node.id==(previewed if not previewed.is_empty() else chosen):
			details.text=node.get("summary",str(node.label)+"\n"+str(node.detail).split("\n\n")[0]) if not previewed.is_empty() else node.detail
			return
	if tabs.current_tab==1:
		details.text="[b]Heart / Knowledge[/b]\n\nResearch Garden upgrades and planting beds. Unlocks take effect immediately.\n\nSelect a technology to inspect it."
		return
	if tabs.current_tab==2:
		details.text="[b]Class progression[/b]\n\nSelect a node to see its requirements and what it unlocks."
		return
	details.text="[b]Seed discoveries[/b]\n\nSelect a seed to inspect it. Roots connect successfully tested seed recipes. Undiscovered nodes may offer breeding clues."


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
		_inspect_active_class=true
	refresh()
	request_tree_base()


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
