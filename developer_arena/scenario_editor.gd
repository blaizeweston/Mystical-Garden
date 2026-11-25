extends RefCounted
const Scenarios=preload("res://developer_arena/scenarios.gd")
var panel: Control
var scenarios: RefCounted
var list:=OptionButton.new()
var title:=LineEdit.new()
var description:=LineEdit.new()
var preset:=LineEdit.new()
var seed_value:=SpinBox.new()
var depth:=SpinBox.new()
var contents:=Label.new()

func setup(owner: Control) -> void:
	panel=owner
	scenarios=Scenarios.new(panel.world)
	var page: Control=panel.pages.Scenarios
	page.add_child(list)
	page.add_child(contents)
	contents.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	contents.focus_mode=Control.FOCUS_ALL
	for field in [[title,"New scenario name"],[description,"Description or Developer Garden setup notes"],[preset,"Preferred preset name (optional)"]]:
		field[0].placeholder_text=field[1]
		page.add_child(field[0])
	title.max_length=64
	description.max_length=512
	preset.max_length=64
	var terrain:=HBoxContainer.new()
	page.add_child(terrain)
	for item in [[seed_value,"Terrain seed (0 = clearing)",0,2147483647,panel.world.session.terrain_seed],[depth,"Depth",1,600,panel.world.session.encounter_depth]]:
		var label:=Label.new()
		label.text=item[1]
		terrain.add_child(label)
		item[0].min_value=item[2]
		item[0].max_value=item[3]
		item[0].value=item[4]
		terrain.add_child(item[0])
	var actions:=HBoxContainer.new()
	page.add_child(actions)
	panel.command(actions,"Save current as new",save_current)
	panel.command(actions,"Load selection…",load_selected)
	panel.command(actions,"Replay scenario",replay)
	var manage:=HBoxContainer.new()
	page.add_child(manage)
	panel.command(manage,"Rename",func():change_name(true))
	panel.command(manage,"Duplicate",func():change_name(false))
	panel.command(manage,"Delete…",delete_selected)
	list.item_selected.connect(func(_index):inspect_selection())
	refresh(panel.world.session.active_scenario.get("name",""))

func selected() -> String:
	return "" if list.selected<0 else list.get_item_text(list.selected)

func refresh(preferred: String) -> void:
	list.clear()
	var labels: Array=Scenarios.STARTERS.duplicate()
	labels.append_array(scenarios.names())
	for entry in labels:
		list.add_item(entry)
		if entry==preferred: list.select(list.item_count-1)
	inspect_selection()

func inspect_selection() -> void:
	var entry: Dictionary=scenarios.get_record(selected())
	var result: Dictionary=scenarios.inspect(entry)
	if not result.error.is_empty():
		contents.text=result.error
		return
	var items:=PackedStringArray([entry.description,"Depth %d · Terrain seed %d"%[entry.terrain.depth,entry.terrain.seed]])
	for slot in entry.participants:
		var build: Dictionary=slot
		items.append("%s · %s · %s · %s"%[slot.slot,build.class_id,build.weapon_id,", ".join(build.parts)])
		if not build.path.is_empty(): items.append("Progression: "+", ".join(build.path))
		var copies:={}
		for upgrade in build.upgrades:
			var label: String=Scenarios.Plan.title(upgrade.id)+" "+str(upgrade.get("rarity",""))
			copies[label]=int(copies.get(label,0))+1
		for label in copies: items.append("%s × %d"%[label,copies[label]])
	var enemy: Dictionary=entry.encounter
	if not enemy.is_empty(): items.append("%d × %s · %s · %s%s"%[enemy.count,enemy.enemy,enemy.type,enemy.formation," · unlimited health" if enemy.type=="Target" and enemy.endless else ""])
	else: items.append("Empty field")
	var controls:=PackedStringArray()
	for key in entry.controls: controls.append("%s %s"%[str(key).capitalize(),"on" if entry.controls[key] else "off"])
	items.append(" · ".join(controls))
	if not entry.preferred_preset.is_empty(): items.append("Suggested preset: "+entry.preferred_preset+" (load separately in Tuning)")
	if result.changed: items.append("Gameplay content has changed. This setup passed current validation.")
	contents.text="\n".join(items)

func save_current() -> void:
	var name:=title.text
	var record: Dictionary=scenarios.current(name,description.text,preset.text,int(seed_value.value),int(depth.value))
	var error: String=scenarios.save_record(record)
	panel.message.text=error if not error.is_empty() else "Saved “"+name+"”."
	if error.is_empty(): refresh(name)

func load_selected() -> void:
	var record: Dictionary=scenarios.get_record(selected())
	var result: Dictionary=scenarios.inspect(record)
	if not result.error.is_empty():
		panel.message.text=result.error
		return
	var prompt: String="Start a clean round with “%s”? Your selected tuning will carry over."%selected()
	if result.changed: prompt+="\nThe source catalog has changed. Apply this reviewed setup?"
	panel.tuning_editor.confirm(prompt,func():panel.message.text=scenarios.start(record,true))

func replay() -> void:
	var active: Dictionary=panel.world.session.active_scenario
	if active.is_empty(): panel.message.text="Load a scenario first."; return
	var result: Dictionary=scenarios.inspect(active)
	if result.error.is_empty() and result.changed:
		panel.tuning_editor.confirm("Replay the previously reviewed setup against current gameplay definitions?",func():panel.message.text=scenarios.start(active,true))
	else: panel.message.text=scenarios.start(active)

func change_name(rename: bool) -> void:
	var error: String=scenarios.copy_scenario(selected(),title.text,rename)
	panel.message.text=error if not error.is_empty() else "Scenario saved."
	if error.is_empty(): refresh(title.text)

func delete_selected() -> void:
	var name:=selected()
	if name in Scenarios.STARTERS: panel.message.text="Built-in scenarios can be duplicated."; return
	panel.tuning_editor.confirm("Permanently delete “"+name+"”?",func():
		var error: String=scenarios.remove(name,true)
		panel.message.text=error if not error.is_empty() else "Scenario deleted."
		refresh(""))
