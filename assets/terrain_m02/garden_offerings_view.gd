extends AcceptDialog

const Offerings = preload("res://assets/terrain_m02/garden_offerings.gd")
const Items = preload("res://item_catalog.gd")
signal contributed(knowledge: int)

var model: Offerings
var experimental_commit := Callable()
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
	theme = preload("res://root_ui.gd").make_theme()
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
	clear.text = "Clear selection"
	clear.pressed.connect(func():
		selection.clear()
		_refresh())
	controls.add_child(clear)
	var instructions := Label.new()
	instructions.text = "Choose a part and set its quantity. You can select several parts before confirming."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(instructions)
	list = ItemList.new()
	list.custom_minimum_size.y = 205
	list.fixed_icon_size=Vector2i(28,28)
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
		var rows:=list.get_selected_items()
		if not rows.is_empty():_update_row(rows[0], selected)
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
		if int(model.inventory.get(id,0))<=0:continue
		var index := list.item_count
		var item: Dictionary=model.items[id]
		var icon: Texture2D=load(item.icon) if not str(item.icon).is_empty() and ResourceLoader.exists(item.icon) else null
		list.add_item("",icon)
		list.set_item_metadata(index, id)
		_update_row(index, id)
		list.set_item_disabled(index,model.available(id)==0)
		if id == selected and not list.is_item_disabled(index):
			list.select(index)
	if list.get_selected_items().is_empty():
		selected=""
		for index in list.item_count:
			if list.is_item_disabled(index):continue
			list.select(index)
			selected=list.get_item_metadata(index)
			break
	_update_quantity()
	_update_totals()

func _update_row(index: int, id: String) -> void:
	var item: Dictionary = model.items[id]
	var held := int(model.reserved.get(id, 0))
	var reserve_note := " · %d reserved" % held if held > 0 else ""
	var knowledge: int=Offerings.KNOWLEDGE_BY_RARITY[item.rarity]
	list.set_item_text(index, "%s · %d available%s · %d selected · +%d K / +%d E" % [
		item.name, model.available(id), reserve_note, selection.get(id, 0), knowledge, model.unit_energy(id)])
	list.set_item_tooltip(index, "%s · %s\nEach item grants %d Knowledge and %d Growth Energy." % [item.name,item.rarity,knowledge,model.unit_energy(id)])

func _update_quantity() -> void:
	quantity.set_value_no_signal(0)
	quantity.max_value = model.available(selected)
	quantity.set_value_no_signal(selection.get(selected, 0))
	quantity.editable=not selected.is_empty() and quantity.max_value>0

func _update_totals() -> void:
	review = model.quote(selection)
	confirm_offer.disabled = review.is_empty()
	status.text = "%d Growth Energy held · Selection grants +%d Growth Energy and +%d Knowledge" % [model.energy, review.get("energy", 0), review.get("knowledge", 0)]
	if list.item_count==0:status.text+="\nShared storage has no eligible materials."
	elif selected.is_empty():status.text+="\nStored materials are reserved."

func _confirm() -> void:
	var gain: int = review.get("energy", 0)
	var knowledge: int = review.get("knowledge", 0)
	var accepted := bool(experimental_commit.call(review)) if experimental_commit.is_valid() else model.offer(review)
	selection.clear()
	_refresh()
	if accepted:
		status.text += "   ·   Gained %d Growth Energy and %d Knowledge" % [gain, knowledge]
		contributed.emit(knowledge)
	else:
		status.text += "   ·   Offering changed. Select parts again."
