extends PanelContainer

const Settings = preload("res://app_settings.gd")
const UI = preload("res://root_ui.gd")
const BuildView = preload("res://ui/gameplay/player_build_projection.gd")
signal refresh_requested
signal requested(command: String, data: Dictionary)
var heading: Label
var totals: GridContainer
var bonuses: Label
var grouped_scroll: ScrollContainer
var grouped_cards: VBoxContainer
var empty_cards: Label
var close_button: Button
var shown: Dictionary
var next_refresh := 0


func opened() -> void:
	refresh()
	close_button.grab_focus()


func _ready() -> void:
	add_theme_stylebox_override("panel", UI.root_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	heading = UI.label(box, 22, UI.INK)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(columns)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	scroll.add_child(left)
	UI.label(left, 16, UI.GREEN).text = "Combat stats"
	totals = GridContainer.new()
	totals.columns = 2
	totals.add_theme_constant_override("v_separation", 5)
	totals.add_theme_constant_override("h_separation", 16)
	left.add_child(totals)
	UI.label(left, 16, UI.GREEN).text = "Unique bonuses"
	bonuses = UI.label(left, 13, UI.INK)
	bonuses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	UI.label(right, 16, UI.GREEN).text = "Expedition upgrades"
	empty_cards = UI.label(right, 13, UI.MUTED)
	empty_cards.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grouped_scroll = ScrollContainer.new()
	grouped_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grouped_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grouped_scroll.follow_focus = true
	right.add_child(grouped_scroll)
	grouped_cards = VBoxContainer.new()
	grouped_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grouped_cards.add_theme_constant_override("separation", 10)
	grouped_scroll.add_child(grouped_cards)
	close_button = UI.button(box, "Close", func(): requested.emit("close",{}))
	get_viewport().size_changed.connect(fit)
	visibility_changed.connect(func(): set_process(is_visible_in_tree()))
	fit()
	set_process(false)


func fit() -> void:
	var room := get_viewport_rect().size - Vector2(36, 36)
	custom_minimum_size = Vector2(790, 530).min(room.max(Vector2.ZERO))


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() >= next_refresh: refresh()


func refresh() -> void:
	next_refresh = Time.get_ticks_msec() + 200
	refresh_requested.emit()

func present(facts: Dictionary) -> void:
	facts = facts.duplicate(true)
	if not facts.get("active",false):
		if is_visible_in_tree(): requested.emit("close",{})
		return
	var stats: Dictionary = facts.get("stats",{})
	var view := BuildView.summary(facts)
	var shortcut := Settings.hint("run_summary")
	close_button.text = "Close" if shortcut == "Unbound" else "Close · " + shortcut
	if view == shown and not heading.text.is_empty():
		return
	heading.text = "Expedition" if view.is_empty() else "Expedition · " + str(stats.name)
	if view.get("totals", []) != shown.get("totals", []) or heading.text == "Expedition":
		for child in totals.get_children():
			totals.remove_child(child)
			child.queue_free()
		for row in view.get("totals", []):
			var title: Label = UI.label(totals, 13, UI.INK)
			title.text = row[0]
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var value: Label = UI.label(totals, 13, UI.INK)
			value.text = row[1]
			if row.size() > 2:
				for label: Label in [title, value]:
					label.tooltip_text = row[2]
					label.mouse_filter = Control.MOUSE_FILTER_PASS
	bonuses.text = view.get("bonuses", "No unique bonuses active.")
	var rows: Array = view.get("cards", [])
	if rows != shown.get("cards", []):
		for child in grouped_cards.get_children():
			grouped_cards.remove_child(child)
			child.queue_free()
		for card in rows:
			add_grouped_card(card)
	empty_cards.visible = rows.is_empty()
	grouped_scroll.visible = grouped_cards.get_child_count() > 0
	empty_cards.text = "Waiting for expedition details…" if view.is_empty() else "No upgrades acquired yet."
	shown = view


func add_grouped_card(card: Dictionary) -> void:
	var group := VBoxContainer.new()
	grouped_cards.add_child(group)
	var title := Button.new()
	title.text = card.title
	title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.toggle_mode = true
	title.tooltip_text = card.tooltip
	group.add_child(title)
	var summary: Label = UI.label(group, 13, UI.INK)
	summary.text = card.summary
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var details: Label = UI.label(group, 13, UI.MUTED)
	details.text = card.tooltip
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.hide()
	title.toggled.connect(func(expanded: bool): details.visible = expanded)
