extends VBoxContainer
## Owner-only choices from the host. Browsing and closing this panel spend nothing.
const UI = preload("res://root_ui.gd")
const Grafts = preload("res://expedition_grafts.gd")
var game: Node
var data: Dictionary = {}
var picks: Array[ItemList] = []
var tabs: TabContainer
var materials: OptionButton
var budget: Label
var notice: Label
var details: RichTextLabel
var confirm: Button
var selected := ""
var trophy := ""
var busy := false


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	UI.label(self,23,Color("#e4d7a5")).text = "Grafting Altar"
	budget = UI.label(self,15,Color("#a3c57b"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	add_child(row)
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(285,320)
	row.add_child(tabs)
	for section in ["Reinforcements", "Adaptations"]:
		var list := ItemList.new()
		list.name = section
		picks.append(list)
		tabs.add_child(list)
		list.item_selected.connect(func(index: int):
			selected = list.get_item_metadata(index)
			show_selection())
	tabs.tab_changed.connect(func(index: int):
		var list := picks[index]
		selected = "" if list.get_selected_items().is_empty() else str(list.get_item_metadata(list.get_selected_items()[0]))
		show_selection())
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 415
	row.add_child(right)
	details = RichTextLabel.new()
	details.bbcode_enabled = true
	details.custom_minimum_size = Vector2(415,245)
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.focus_mode = Control.FOCUS_ALL
	right.add_child(details)
	materials = OptionButton.new()
	materials.fit_to_longest_item = false
	right.add_child(materials)
	materials.item_selected.connect(func(index: int):
		trophy = str(materials.get_item_metadata(index))
		update_confirm())
	confirm = UI.button(right,"Confirm improvement",send_purchase)
	notice = UI.label(self,13,Color("#c8d1bd"))
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.button(self,"Close",func(): game.ui.close_panels())


func set_data(value: Dictionary) -> void:
	data = value
	busy = false
	budget.text = "%d of %d expedition purchases remaining" % [data.remaining,data.limit]
	if data.used:
		budget.text += " · Altar used"
	notice.text = str(data.status)
	for list in picks:
		list.clear()
	var choice_found := false
	for option: Dictionary in data.options:
		var list := picks[int(option.unique)]
		var caption: String = option.name
		if int(option.count) > 0:
			caption += " · Acquired" if option.unique else " ×%d" % int(option.count)
		var index := list.add_item(caption)
		list.set_item_metadata(index,option.id)
		if option.id == selected:
			list.select(index)
			choice_found = true
	if not choice_found:
		selected = ""
	show_selection()


func selected_option() -> Dictionary:
	for option: Dictionary in data.get("options", []):
		if option.id == selected:
			return option
	return {}


func show_selection() -> void:
	var choice := selected_option()
	materials.clear()
	materials.visible = not choice.is_empty()
	if choice.is_empty():
		details.text = "Choose an improvement to inspect it. Reinforcements take one ordinary trophy. Adaptations take their matching trophy."
		update_confirm()
		return
	var description := "[b]%s[/b]\n%s\n\n%s\n\n%s" % [
		choice.name,"Unique adaptation" if choice.unique else "Repeatable reinforcement",choice.text,choice.detail]
	if choice.id in ["silken_link","prismatic_echo","chorus_pulse","cinder_field"]:
		description += "\n\nIf the combat effect queue is full, readiness is retained for your next qualifying hit."
	if not str(choice.values).is_empty():
		description += "\n\n" + str(choice.values)
	if not str(choice.reason).is_empty():
		description += "\n\n" + str(choice.reason)
	details.text = description
	if choice.unique:
		add_trophy(choice.material)
		materials.select(0)
		materials.disabled = true
	else:
		materials.add_item("Choose an ordinary trophy")
		materials.set_item_metadata(0,"")
		for material: Dictionary in data.materials:
			add_trophy(material)
			if material.id == trophy:
				materials.select(materials.item_count-1)
		materials.disabled = materials.item_count < 2
	update_confirm()


func add_trophy(material: Dictionary) -> void:
	materials.add_item("%d %s · %d carried" % [material.cost,material.name,material.carried])
	materials.set_item_metadata(materials.item_count-1,material.id)


func update_confirm() -> void:
	var choice := selected_option()
	confirm.disabled = true
	confirm.text = "Confirm improvement"
	var selected_index := materials.selected
	if choice.is_empty() or selected_index < 0:
		return
	var material_id: String = materials.get_item_metadata(selected_index)
	if material_id.is_empty():
		confirm.text = "No eligible trophies carried" if data.materials.is_empty() else "Choose the trophy to spend"
		return
	var material: Dictionary = choice.material if choice.unique else data.materials[selected_index-1]
	confirm.text = "Buy · %d %s" % [material.cost,material.name]
	if int(material.carried) < int(material.cost):
		confirm.text = "Need %d %s" % [material.cost,material.name]
	elif data.used:
		confirm.text = "Altar already used"
	elif int(data.remaining) == 0:
		confirm.text = "Expedition graft budget used"
	else:
		confirm.disabled = busy or not str(choice.reason).is_empty()


func send_purchase() -> void:
	if confirm.disabled:
		return
	busy = true
	confirm.disabled = true
	game.send_garden_action(Grafts.request(data,selected,str(materials.get_item_metadata(materials.selected))))


func _process(_delta: float) -> void:
	if is_visible_in_tree() and not game.at_graft_altar(game.players.get(game.local_player_id(),{})):
		game.ui.close_panels()
