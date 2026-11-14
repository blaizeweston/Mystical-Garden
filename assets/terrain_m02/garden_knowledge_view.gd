extends AcceptDialog
## Garden lab controls. Closing this dialog has no effect on Garden state.

const Knowledge = preload("res://assets/terrain_m02/garden_knowledge.gd")
const Build = preload("res://assets/terrain_m02/garden_construction.gd")

var model: Knowledge
var records: Dictionary
var research_list: ItemList
var balance: Label
var detail: Label
var capabilities: Label
var study: Button
var grant: Button
var sandbox: CheckButton
var selected := ""

func _ready() -> void:
	title = "Garden Knowledge"
	ok_button_text = "Back to Garden"
	exclusive = true
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("#131e18")
	skin.border_color = Color("#60563b")
	skin.set_border_width_all(1)
	skin.set_content_margin_all(14)
	theme = Theme.new()
	theme.set_stylebox("panel", "AcceptDialog", skin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	var controls := HBoxContainer.new()
	body.add_child(controls)
	grant = Button.new()
	grant.text = "Grant 10 test Knowledge"
	grant.pressed.connect(func(): model.grant_test_knowledge())
	controls.add_child(grant)
	sandbox = CheckButton.new()
	sandbox.text = "Free-build test mode"
	sandbox.toggled.connect(func(on: bool): model.set_sandbox(on))
	controls.add_child(sandbox)
	balance = Label.new()
	body.add_child(balance)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	body.add_child(columns)
	research_list = ItemList.new()
	research_list.custom_minimum_size = Vector2(282, 226)
	research_list.item_selected.connect(func(index: int):
		selected = research_list.get_item_metadata(index)
		_update_detail())
	columns.add_child(research_list)
	var descriptions := VBoxContainer.new()
	descriptions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(descriptions)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	descriptions.add_child(detail)
	study = Button.new()
	study.text = "Complete research"
	study.pressed.connect(func(): model.research(selected))
	descriptions.add_child(study)
	capabilities = Label.new()
	capabilities.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(capabilities)

func present(state: Knowledge, buildings: Dictionary) -> void:
	model = state
	records = buildings
	refresh()
	popup_centered(Vector2i(660, 470))

func refresh() -> void:
	sandbox.set_pressed_no_signal(model.sandbox)
	balance.text = "%d lifetime Knowledge   ·   %d available" % [model.knowledge, model.available_knowledge()]
	research_list.clear()
	for row: Dictionary in model.relevant_research():
		var index := research_list.item_count
		var status := "Done" if model.unlocked.has(row.id) else ("Ready" if model.research_refusal(row.id).is_empty() else "Locked")
		research_list.add_item("%s  ·  %s" % [row.name, status])
		research_list.set_item_metadata(index, row.id)
		if row.id == selected:
			research_list.select(index)
	if research_list.get_selected_items().is_empty() and research_list.item_count > 0:
		research_list.select(0)
		selected = research_list.get_item_metadata(0)
	_update_detail()
	var available := PackedStringArray()
	for kind: String in Build.CATALOG:
		if model.construction_refusal(kind, records).is_empty():
			available.append(Build.CATALOG[kind].name)
	var expansion := "Locked · Research Reaching Roots"
	if model.sandbox:
		expansion = "Free in test mode"
	elif model.clearing_tier() > 0:
		expansion = "Repeatable · Heart growth tier %d" % model.clearing_tier()
	var beds := "unlimited in test mode" if model.sandbox else "%d of %d available" % [
		maxi(0, model.extra_bed_limit() - model.bed_count(records)), model.extra_bed_limit()]
	capabilities.text = "Garden growth: %s\nExtra cultivation beds: %s\nAvailable in Build: %s" % [
		expansion, beds, ", ".join(available) if not available.is_empty() else "None"]

func _update_detail() -> void:
	var row := Knowledge.Catalog.get_node(selected)
	if row.is_empty():
		return
	var required := PackedStringArray()
	for parent: String in row.parents:
		required.append(Knowledge.Catalog.get_node(parent).name)
	var effect := "Supports related Garden research in this lab."
	if row.has("plots"):
		effect = "Unlocks one extra cultivation bed. Place it using Build."
	elif selected == "clearing_1":
		effect = "Unlocks repeatable expansion funded by Heart offerings."
	elif row.has("clearing"):
		effect = "Reduces the growth energy required for each expansion."
	elif selected == "seed_archive":
		effect = "Unlocks the Seed cache in Build."
	elif selected == "monster_studies":
		effect = "Unlocks one Field study in Build."
	elif selected == "irrigation":
		effect = "With Reaching Roots, unlocks the Watering basin in Build."
	var refusal := model.research_refusal(selected)
	study.disabled = not refusal.is_empty()
	detail.text = "%s\nRequires %s\n%d lifetime Knowledge · Spend %d available\n\n%s\n\n%s" % [
		row.name, ", ".join(required), row.knowledge, row.insight, effect,
		"Ready. Research completes immediately in the lab." if refusal.is_empty() else refusal]
