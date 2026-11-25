extends RefCounted
const Catalog = preload("res://developer_arena/tuning.gd")
const Presets = preload("res://developer_arena/tuning_presets.gd")
var panel: Control
var tuning: RefCounted
var store: RefCounted
var category := TabContainer.new()
var search := LineEdit.new()
var modified := CheckButton.new()
var rows := {}
var lab: Control
var visual_property := OptionButton.new()
var name_entry := LineEdit.new()
var saved := OptionButton.new()
var feedback := Label.new()
var decision := ConfirmationDialog.new()
var confirm_action: Callable

func setup(workbench: Control, parent: Control) -> void:
	panel=workbench
	tuning=panel.world.developer_tuning
	store=Presets.new(panel.world)
	search.placeholder_text="Search objects and properties"
	parent.add_child(search)
	modified.text="Modified only"
	parent.add_child(modified)
	parent.add_child(category)
	for group in ["Gameplay","Garden","World","Visuals","Presets"]:
		var page:=VBoxContainer.new()
		page.name=group
		category.add_child(page)
		if group=="Presets":
			preset_page(page)
			continue
		if group=="Visuals": playback(page)
		var ids: Array=[]
		for id in Catalog.PROPERTIES:
			if Catalog.PROPERTIES[id].category!=group: continue
			ids.append(id)
			property_row(page,id)
		panel.command(page,"Reset "+group,func():tuning.reset(panel.world,ids);refresh())
	var actions := HBoxContainer.new()
	parent.add_child(actions)
	panel.command(actions,"Apply pending changes",func():tuning.apply(panel.world,Catalog.PROPERTIES.keys());refresh())
	panel.command(actions,"Reset all",func():tuning.reset(panel.world,Catalog.PROPERTIES.keys());refresh())
	parent.add_child(feedback)
	feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	search.text_changed.connect(search_properties)
	modified.toggled.connect(func(_v):refresh())
	category.tab_changed.connect(func(_v):refresh())
	panel.add_child(decision)
	decision.confirmed.connect(func():if confirm_action.is_valid(): confirm_action.call())
	refresh()

func property_row(parent: Control,id: String) -> void:
	var d: Dictionary = Catalog.PROPERTIES[id]
	var box:=VBoxContainer.new()
	parent.add_child(box)
	var name_label:=Label.new()
	name_label.text="%s · %s (%s)"%[d.object_name,d.label,d.unit]
	box.add_child(name_label)
	var values:=Label.new()
	box.add_child(values)
	var controls:=HBoxContainer.new()
	box.add_child(controls)
	var slider:=HSlider.new()
	var number:=SpinBox.new()
	for input in [slider,number]:
		input.min_value=d.minimum
		input.max_value=d.maximum
		input.step=d.step
		controls.add_child(input)
	slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x=100
	number.step=d.step if d.unit in ["pieces","off/on","°"] else 0.01
	number.suffix=d.unit
	var tint: ColorPickerButton
	if id.ends_with(".hue"):
		tint=ColorPickerButton.new()
		tint.custom_minimum_size.x=36
		tint.edit_alpha=false
		tint.tooltip_text="Choose hue. The effect preserves its material saturation and brightness."
		controls.add_child(tint)
		tint.color_changed.connect(func(value: Color): change(id,roundf(value.h*360.0)))
	panel.command(controls,"Reset",func():tuning.reset(panel.world,[id]);refresh())
	var timing:=Label.new()
	timing.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	timing.text=d.timing
	box.add_child(timing)
	rows[id]={"box":box,"values":values,"slider":slider,"number":number,"tint":tint}
	slider.value_changed.connect(func(value):change(id,value))
	number.value_changed.connect(func(value):change(id,value))

func search_properties(term: String) -> void:
	if not term.is_empty():
		var matches: Array[String]=[]
		for id in Catalog.PROPERTIES:
			var d: Dictionary=Catalog.PROPERTIES[id]
			if " ".join([d.category,d.object_name,d.label,id]).containsn(term): matches.append(d.category)
		var current:=category.get_current_tab_control()
		if not matches.is_empty() and (current==null or not str(current.name) in matches):
			category.current_tab=category.get_node(matches[0]).get_index()
	refresh()

func change(id: String,value: float) -> void:
	if tuning.request(panel.world,id,value): refresh()
	else: feedback.text="Value refused."

func refresh() -> void:
	if not tuning.authorized(panel.world): return
	if lab!=null: lab.refresh_ambient()
	for id in rows:
		var row: Dictionary=rows[id]
		var d: Dictionary = Catalog.PROPERTIES[id]
		var base: float=tuning.baseline(id)
		var proposed: float=tuning.requested(id)
		var actual: float=tuning.applied(id)
		var label: String=" ".join([d.category,d.object_name,d.label,id])
		var changed:=not is_equal_approx(base,proposed) or not is_equal_approx(base,actual)
		row.box.visible=(not modified.button_pressed or changed) and (search.text.is_empty() or label.containsn(search.text))
		if d.category=="Visuals" and search.text.is_empty() and not modified.button_pressed:
			row.box.visible=visual_property.get_selected_metadata()==id
		row.slider.set_value_no_signal(proposed)
		row.number.set_value_no_signal(proposed)
		if row.tint!=null:row.tint.color=Color.from_hsv(proposed/360.0,0.6,0.97)
		var state: String="Pending Apply" if not is_equal_approx(proposed,actual) else "Applied" if changed else "Production"
		if state=="Applied" and id in [Catalog.SPEAR,Catalog.FLORA,Catalog.IMPACT]: state="Ready for next use"
		row.values.text="Baseline %s   ·   Applied %s   ·   %s"%[String.num(base,3),String.num(actual,3),state]
		if tuning.last_used.has(id): row.values.text+="   ·   Last used %s"%String.num(tuning.last_used[id],3)
	if category.get_current_tab_control()!=null and category.get_current_tab_control().name=="Presets": refresh_names()

func playback(page: Control) -> void:
	var legacy:=VBoxContainer.new()
	lab=preload("res://developer_arena/contact_lab.gd").new()
	page.add_child(lab)
	page.add_child(legacy)
	lab.setup(panel,legacy)
	lab.selection.item_selected.connect(func(_index): populate_visual_properties(); refresh())
	page.add_child(visual_property)
	visual_property.tooltip_text="Select a parameter to tune beside the preview"
	visual_property.item_selected.connect(func(_index): refresh())
	populate_visual_properties()
	var abilities:=OptionButton.new()
	var build=panel.world.combat_build(panel.world.players[panel.world.HOST])
	for i in 2:
		var skill: Dictionary=build.class_skill(i)
		abilities.add_item(skill.get("name","Ability %d"%(i+1)))
	abilities.select(tuning.replay_slot)
	abilities.item_selected.connect(func(index):if tuning.authorized(panel.world): tuning.replay_slot=index)
	legacy.add_child(abilities)
	var buttons:=HBoxContainer.new()
	legacy.add_child(buttons)
	for baseline: bool in [false,true]:
		panel.command(buttons,"Replay baseline impact" if baseline else "Replay tuned impact",func():
			if not tuning.replay(panel.world,baseline): feedback.text="Choose an equipped ability first.")

func populate_visual_properties() -> void:
	visual_property.clear()
	var prefix := "rupture." if lab.selection.selected==2 else "impact."
	if lab.selection.selected>=4 and lab.selection.selected<lab.WEAPON_SEQUENCE: prefix=lab.Exhibit.GROUPS[lab.selection.selected-4]+"."
	for id: String in Catalog.PROPERTIES:
		if lab.selection.selected==lab.WEAPON_SEQUENCE:
			if not (id.begins_with("trail.") or id=="projectile.tail" or id=="text.detail"): continue
		elif lab.selection.selected==lab.DODGE:
			if id!="dodge.dust": continue
		elif not id.begins_with(prefix) and id!=Catalog.SUN: continue
		var definition: Dictionary=Catalog.PROPERTIES[id]
		visual_property.add_item("Tune · "+str(definition.label))
		visual_property.set_item_metadata(visual_property.item_count-1,id)

func preset_page(page: Control) -> void:
	page.add_child(saved)
	page.add_child(name_entry)
	name_entry.placeholder_text="Name for new, renamed or duplicated preset"
	var creation:=HBoxContainer.new()
	page.add_child(creation)
	panel.command(creation,"Save new",func():finish(store.save_new(name_entry.text),name_entry.text))
	panel.command(creation,"Rename",func():finish(store.copy_named(selection(),name_entry.text,true),name_entry.text))
	panel.command(creation,"Duplicate",func():finish(store.copy_named(selection(),name_entry.text,false),name_entry.text))
	panel.command(creation,"Delete…",func():
		var name:=selection()
		if not name.is_empty(): confirm("Delete preset “"+name+"”?",func():finish(store.remove(name,true))))
	var use:=HBoxContainer.new()
	page.add_child(use)
	panel.command(use,"Compare",func():inspect(false))
	panel.command(use,"Load…",func():inspect(true))
	panel.command(use,"Export preset",func():feedback.text=store.export_review(selection()) if not selection().is_empty() else "Choose a preset.")
	panel.command(page,"Export current changes",func():feedback.text=store.export_review())

func selection() -> String:
	return saved.get_item_text(saved.selected) if saved.selected>=0 else ""

func refresh_names(preferred: String="") -> void:
	if preferred.is_empty(): preferred=selection()
	var names: Array=store.names()
	saved.clear()
	for name in names:
		saved.add_item(name)
		if name==preferred: saved.select(saved.item_count-1)

func finish(error: String, preferred: String="") -> void:
	feedback.text=error if not error.is_empty() else "Preset updated."
	refresh_names(preferred)
	refresh()

func confirm(prompt: String, action: Callable) -> void:
	confirm_action=action
	decision.dialog_text=prompt
	decision.popup_centered()

func inspect(loading: bool) -> void:
	var name:=selection()
	if name.is_empty(): feedback.text="Choose a preset."; return
	var record: Dictionary=store.read(name)
	var report: Dictionary=store.compare(record)
	var lines:=PackedStringArray()
	var entries: Variant=record.get("properties",[])
	for e in entries if entries is Array else []:
		if e is Dictionary and report.values.has(e.get("id","")) and e.has_all(["modified","unit"]):
			lines.append("%s: baseline %s → proposed %s %s"%[e.id,tuning.baseline(e.id),e.modified,e.unit])
	for issue in report.invalid+report.conflicts: lines.append(str(issue))
	if lines.is_empty(): lines.append("Production defaults.")
	feedback.text="\n".join(lines)
	if not loading or not report.invalid.is_empty(): return
	var token: String=store.review_token(record,report)
	var prompt: String="Replace current tuning with “%s”?"%name
	if not report.conflicts.is_empty(): prompt+="\n"+"\n".join(report.conflicts)+"\nApply against the new baseline?"
	confirm(prompt,func():finish(store.load_named(name,token),name))
