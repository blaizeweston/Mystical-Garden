extends RefCounted
const Plan=preload("res://developer_arena/build_plan.gd")
var panel: Control
var draft: Dictionary
var resolved: Dictionary
var class_pick:=OptionButton.new()
var weapon:=OptionButton.new()
var node_pick:=OptionButton.new()
var path_text:=Label.new()
var parts: Array[OptionButton]=[]
var search:=LineEdit.new()
var all_upgrades:=CheckButton.new()
var options:=OptionButton.new()
var rarity:=OptionButton.new()
var owned:=OptionButton.new()
var copies:=SpinBox.new()
var details:=Label.new()
var preview:=Label.new()

func setup(owner: Control) -> void:
	panel=owner
	draft=panel.world.session.build.duplicate(true)
	var build: Control=panel.pages.Build
	var upgrades: Control=panel.pages.Upgrades
	for frame in Plan.Classes.DEFINITIONS: class_pick.add_item(frame.name)
	row(build,"Class",class_pick)
	class_pick.item_selected.connect(change_class)
	row(build,"Weapon",weapon)
	weapon.item_selected.connect(func(id):draft.weapon=id;refresh())
	for index in 3:
		var pick:=OptionButton.new()
		pick.add_item("Empty",0)
		for part in range(1,Plan.Parts.DEFINITIONS.size()):
			if Plan.Parts.is_plant(part): pick.add_item(Plan.Parts.part_name(part),part)
		row(build,["Core","Form","Catalyst"][index],pick)
		pick.item_selected.connect(func(i):draft.parts[index]=pick.get_item_id(i);refresh())
		parts.append(pick)
	build.add_child(path_text)
	row(build,"Next connected node",node_pick)
	panel.command(build,"Learn selected focus or node",learn)
	panel.command(build,"Remove last progression node",unlearn)
	search.placeholder_text="Search cards, grafts, adaptations and transformations"
	upgrades.add_child(search)
	search.text_changed.connect(func(_text):list_options())
	all_upgrades.text="Include ineligible upgrades and reasons"
	upgrades.add_child(all_upgrades)
	all_upgrades.toggled.connect(func(_on):list_options())
	row(upgrades,"Upgrade",options)
	options.item_selected.connect(func(_id):show_option())
	row(upgrades,"Rarity",rarity)
	rarity.item_selected.connect(func(_id):show_reason())
	row(upgrades,"Copies to add",copies)
	copies.min_value=1
	copies.max_value=Plan.Catalog.PLAYTEST.acquisition_limit
	details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	upgrades.add_child(details)
	panel.command(upgrades,"Add to draft",add_upgrade)
	row(upgrades,"Acquired copies",owned)
	panel.command(upgrades,"Remove selected copy",remove_copy)
	panel.command(upgrades,"Clear all upgrades",func():draft.upgrades=[];refresh())
	preview.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var review:=ScrollContainer.new()
	review.name="DependencyPreview"
	review.custom_minimum_size.y=58
	review.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel.message.get_parent().add_child(review)
	preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	review.add_child(preview)
	var submit: Button=panel.command(panel.message.get_parent(),"Apply build and restart round",apply)
	var update_visibility:=func(_index): submit.visible=panel.tabs.get_current_tab_control().name in ["Build","Upgrades"]
	panel.tabs.tab_changed.connect(update_visibility)
	update_visibility.call(panel.tabs.current_tab)
	load_controls()
	refresh()

func row(target: Control,caption: String,control: Control) -> void:
	var line:=HBoxContainer.new()
	target.add_child(line)
	var label:=Label.new()
	label.text=caption
	line.add_child(label)
	control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	line.add_child(control)

func change_class(id: int) -> void:
	draft.frame=id
	draft.weapon=0
	draft.path=[]
	load_controls()
	refresh()

func load_controls() -> void:
	class_pick.select(draft.frame)
	weapon.clear()
	for item in Plan.Classes.DEFINITIONS[draft.frame].weapons: weapon.add_item(item.name)
	weapon.select(draft.weapon)
	for i in parts.size(): parts[i].select(parts[i].get_item_index(draft.parts[i]))

func learn() -> void:
	if node_pick.selected>=0:
		draft.path.append(node_pick.get_selected_metadata())
		refresh()

func unlearn() -> void:
	if not draft.path.is_empty(): draft.path.pop_back();refresh()

func refresh() -> void:
	resolved=Plan.plan(panel.world,draft)
	if not resolved.error.is_empty():
		preview.text=resolved.error
		return
	var tree:=Plan.Classes.connected_tree(draft.frame)
	var learned:=PackedStringArray()
	for id in draft.path: learned.append(tree.node(id).name)
	path_text.text="Focus and progression: "+(" / ".join(learned) if not learned.is_empty() else "Choose a starting focus")
	node_pick.clear()
	for i in tree.nodes.size():
		if tree.refusal(resolved.profile,i+tree.REQUEST_OFFSET).is_empty():
			node_pick.add_item(tree.nodes[i].name)
			node_pick.set_item_metadata(node_pick.item_count-1,tree.nodes[i].id)
	var removals:=PackedStringArray()
	for entry in resolved.removed: removals.append(Plan.title(entry.entry.id)+" - "+entry.reason)
	preview.text=("Applying also removes: "+"; ".join(removals)) if not removals.is_empty() else ("Draft ready to apply" if draft!=panel.world.session.build else "")
	preview.get_parent().visible=not preview.text.is_empty()
	owned.clear()
	for entry in draft.upgrades: owned.add_item(Plan.title(entry.id)+" "+entry.get("rarity",""))
	list_options()

func list_options() -> void:
	var previous: String=options.get_selected_metadata() if options.selected>=0 else ""
	options.clear()
	var eligible: Array=[]
	var unavailable: Array=[]
	for id: String in Plan.Catalog.DEFINITIONS.keys()+Plan.Grafts.REINFORCEMENTS.keys()+Plan.Grafts.ADAPTATIONS.keys():
		if not search.text.is_empty() and not (Plan.title(id)+" "+id).containsn(search.text): continue
		var grade:=default_grade(id)
		var quote:=Plan.acquire(panel.world,draft,resolved,{"id":id,"rarity":grade})
		if quote.has("ledger"): eligible.append(id)
		elif all_upgrades.button_pressed: unavailable.append(id)
	for id in eligible+unavailable:
		options.add_item(Plan.title(id)+(" (unavailable)" if unavailable.has(id) else ""))
		options.set_item_metadata(options.item_count-1,id)
		if id==previous: options.select(options.item_count-1)
	show_option()

func default_grade(id: String) -> String:
	var definition: Dictionary=Plan.Catalog.DEFINITIONS.get(id,{})
	return Plan.Catalog.RARITIES[0] if not definition.is_empty() and definition.policy!="unique" else ""

func show_option() -> void:
	var previous:=rarity.get_item_text(rarity.selected) if rarity.selected>=0 else ""
	rarity.clear()
	if options.selected<0:
		details.text="No matching upgrades."
		return
	var id: String=options.get_selected_metadata()
	if default_grade(id).is_empty():
		rarity.add_item("Fixed")
		rarity.disabled=true
	else:
		rarity.disabled=false
		for grade in Plan.Catalog.RARITIES:
			rarity.add_item(grade)
			if grade==previous: rarity.select(rarity.item_count-1)
	show_reason()

func entry() -> Dictionary:
	return {"id":options.get_selected_metadata(),"rarity":"" if rarity.disabled else rarity.get_item_text(rarity.selected)}

func show_reason() -> void:
	if options.selected<0: return
	var item:=entry()
	var quote:=Plan.acquire(panel.world,draft,resolved,item)
	var definition: Dictionary=Plan.Catalog.DEFINITIONS.get(item.id,Plan.Grafts.ADAPTATIONS.get(item.id,Plan.Grafts.REINFORCEMENTS.get(item.id,{})))
	details.text=quote.get("message",definition.get("trigger",definition.get("text","Eligible")))

func add_upgrade() -> void:
	if options.selected<0: return
	var chosen:=entry()
	for i in int(copies.value):
		var quote:=Plan.acquire(panel.world,draft,resolved,chosen)
		if not quote.has("ledger"):
			panel.message.text=quote.message
			break
		draft.upgrades.append(chosen.duplicate())
		resolved=Plan.plan(panel.world,draft)
	refresh()

func remove_copy() -> void:
	if owned.selected>=0: draft.upgrades.remove_at(owned.selected);refresh()

func apply() -> void:
	if draft==panel.world.session.build: return
	panel.message.text=panel.world.apply_build(draft,resolved.get("removed",[]))
