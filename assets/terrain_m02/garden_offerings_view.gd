extends AcceptDialog

const Offerings = preload("res://assets/terrain_m02/garden_offerings.gd")
signal contributed

var model: Offerings
var experimental_commit := Callable()
var study_summary := Callable()
var study_status: Label
var study_progress: ProgressBar
var selection := {}
var review := {}
var selected := ""
var list: ItemList
var quantity: SpinBox
var status: Label
var confirm_offer: Button

func _ready() -> void:
	title = "Heart Offerings"
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
	var replenish := Button.new()
	replenish.text = "Replenish test parts"
	replenish.visible = not experimental_commit.is_valid()
	replenish.pressed.connect(func():
		model.replenish()
		selection.clear()
		_refresh())
	controls.add_child(replenish)
	var clear := Button.new()
	clear.text = "Cancel selection"
	clear.pressed.connect(func():
		selection.clear()
		_refresh())
	controls.add_child(clear)
	var instructions := Label.new()
	instructions.text = "Choose a part and set its quantity. You can select several parts before confirming."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(instructions)
	if study_summary.is_valid():
		instructions.text = "Offer unreserved parts from shared storage. The Heart studies them while you play."
		study_status = Label.new()
		study_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(study_status)
		study_progress = ProgressBar.new()
		study_progress.custom_minimum_size.y = 20
		body.add_child(study_progress)
	list = ItemList.new()
	list.custom_minimum_size.y = 164 if study_summary.is_valid() else 205
	list.item_selected.connect(func(index: int):
		selected = list.get_item_metadata(index)
		_update_quantity())
	body.add_child(list)
	var actions := HBoxContainer.new()
	body.add_child(actions)
	var caption := Label.new()
	caption.text = "Selected quantity"
	actions.add_child(caption)
	quantity = SpinBox.new()
	quantity.min_value = 0
	quantity.step = 1
	quantity.custom_minimum_size.x = 90
	quantity.value_changed.connect(func(value: float):
		if selected.is_empty():
			return
		if value > 0:
			selection[selected] = int(value)
		else:
			selection.erase(selected)
		_update_row(list.get_selected_items()[0], selected)
		_update_totals())
	actions.add_child(quantity)
	confirm_offer = Button.new()
	confirm_offer.text = "Confirm offering"
	confirm_offer.pressed.connect(_confirm)
	actions.add_child(confirm_offer)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(status)

func present(source: Offerings) -> void:
	model = source
	selection.clear()
	_refresh()
	popup_centered(Vector2i(715, 470))

func _refresh() -> void:
	list.clear()
	for id: String in model.items:
		var index := list.item_count
		list.add_item("")
		list.set_item_metadata(index, id)
		_update_row(index, id)
		if id == selected:
			list.select(index)
	if list.get_selected_items().is_empty():
		list.select(0)
		selected = list.get_item_metadata(0)
	_update_quantity()
	_update_totals()

func _update_row(index: int, id: String) -> void:
	var item: Dictionary = model.items[id]
	var kind := "Plant" if item.category == "plant_part" else "Monster"
	var held := int(model.reserved.get(id, 0))
	var reserve_note := " (%d reserved)" % held if held > 0 else ""
	list.set_item_text(index, "%s · %s · %d free%s · %d selected · +%d each" % [
		item.name, kind, model.available(id), reserve_note, selection.get(id, 0), model.unit_energy(id)])
	list.set_item_tooltip(index, "%s · %s" % [item.rarity, id])

func _update_quantity() -> void:
	quantity.set_value_no_signal(0)
	quantity.max_value = model.available(selected)
	quantity.set_value_no_signal(selection.get(selected, 0))

func _update_totals() -> void:
	review = model.quote(selection)
	confirm_offer.disabled = review.is_empty()
	status.text = "%d stored growth energy   ·   %d energy selected" % [model.energy, review.get("energy", 0)]
	refresh_studies()

func refresh_studies() -> void:
	if not study_summary.is_valid():
		return
	var summary: Dictionary = study_summary.call(review.get("items", {}))
	var active: Dictionary = summary.active
	study_status.text = "%d Knowledge available  ·  %d pending  ·  +%d from selection" % [
		summary.available, summary.pending, summary.selected]
	if active.is_empty():
		study_status.text += "\nNo active study."
	else:
		study_status.text += "\nStudying %s  ·  %ds of work left  ·  %d waiting" % [
			active.name, ceili(active.required - active.done), summary.waiting]
	if not summary.blocked.is_empty():
		study_status.text += "\n" + summary.blocked
	study_progress.visible = not active.is_empty()
	if study_progress.visible:
		study_progress.max_value = active.required
		study_progress.value = active.done

func _confirm() -> void:
	var gain: int = review.get("energy", 0)
	var accepted := bool(experimental_commit.call(review)) if experimental_commit.is_valid() else model.offer(review)
	selection.clear()
	_refresh()
	if accepted:
		status.text += "   ·   Contributed %d" % gain
		contributed.emit()
	else:
		status.text += "   ·   Offering changed. Select parts again."
