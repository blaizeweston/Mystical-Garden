extends VBoxContainer

const Developer = preload("res://developer_mode.gd")
const Transactions = preload("res://game_transaction.gd")
var context: Node
var settings: Window
var title_menu := false
var toggle: CheckBox
var hint: Label
var tools: VBoxContainer
var reset: CheckBox
var reset_digests := {}
var tech_picker: OptionButton
var unlock_button: Button
var finish_button: Button
var grant_button: Button
var materials_button: Button


func _ready() -> void:
	toggle = settings.check(self,"Developer Mode")
	toggle.toggled.connect(func(_value): refresh_tools())
	hint = settings.label(self,"")
	if context != null and preload("res://combat_ruleset.gd").active(context):
		settings.button(self,"Stock Frostbell in isolated Garden",func():
			settings.notice.text = preload("res://frost_combat.gd").stock_test_garden(context))
	tools = VBoxContainer.new()
	tools.add_theme_constant_override("separation",8)
	add_child(tools)
	if title_menu:
		reset = settings.check(tools,"Start fresh and back up the previous test save")
		reset.toggled.connect(func(value):
			if context != null and context.guarded_persistence:
				reset_digests = Developer.reset_snapshot(context) if value else {})
		settings.button(tools,"Open Developer Garden",open_garden)
		if context != null and context.production_route:
			settings.button(tools,"Review Developer Garden Recovery…",func():
				settings.cancel()
				context.review_developer_recovery())
	elif context != null and Developer.is_test_garden(context):
		grant_button = Button.new()
		grant_button.text = "Grant Knowledge and starter supplies"
		grant_button.pressed.connect(func(): run_tool("grant"))
		tools.add_child(grant_button)
		materials_button = Button.new()
		materials_button.text = "Stock every material"
		materials_button.tooltip_text = "Top up to 25 of each crafting part and 5 of each seed, including mystery seeds."
		materials_button.pressed.connect(func(): run_tool("materials"))
		tools.add_child(materials_button)
		finish_button = Button.new()
		finish_button.text = "Finish current research"
		finish_button.pressed.connect(func(): run_tool("finish"))
		tools.add_child(finish_button)
		var unlock_row := HBoxContainer.new()
		tools.add_child(unlock_row)
		tech_picker = OptionButton.new()
		tech_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unlock_row.add_child(tech_picker)
		unlock_button = Button.new()
		unlock_button.text = "Test unlock"
		unlock_button.pressed.connect(func(): run_tool("unlock"))
		unlock_row.add_child(unlock_button)


func setup(enabled: bool) -> void:
	if preload("res://playtest_storage.gd").retail():
		toggle.set_pressed_no_signal(false)
		hide()
		return
	toggle.set_pressed_no_signal(enabled)
	toggle.disabled = context != null and not title_menu and not Developer.is_solo(context)
	if reset != null:
		reset.button_pressed = false
	refresh_tools()


func refresh_tools() -> void:
	tools.visible = toggle.button_pressed and not toggle.disabled and (title_menu or tech_picker != null)
	if toggle.disabled:
		hint.text = "Developer Mode is available in single player."
	elif title_menu:
		hint.text = "The Developer Garden uses its own save and character."
	elif tech_picker != null:
		hint.text = "Use these tools between expeditions. Test unlocks stage their prerequisites and play the selected reveal."
	else:
		hint.text = "Open the Developer Garden from Settings on the main menu."
	if tech_picker == null or not tools.visible:
		return
	var selected: String = tech_picker.get_selected_metadata() if tech_picker.selected >= 0 else ""
	tech_picker.clear()
	for tech in Developer.available_tech(context):
		tech_picker.add_item(tech.name)
		tech_picker.set_item_metadata(tech_picker.item_count-1,tech.id)
		if tech.id == selected:
			tech_picker.select(tech_picker.item_count-1)
	var available := Developer.can_edit(context)
	unlock_button.disabled = not available or tech_picker.item_count == 0
	finish_button.disabled = not available or context.progress.heart.active.is_empty()
	grant_button.disabled = not available
	materials_button.disabled = not available
	if not available and toggle.button_pressed and not context.app_settings.values.get("developer_mode",false):
		hint.text = "Apply Settings to enable the tools."
	var pending := Transactions.pending_notice(context)
	if not pending.is_empty(): hint.text = pending


func open_garden() -> void:
	if not title_menu or not settings.visible or not toggle.button_pressed:
		return
	if context.guarded_persistence:
		settings.save()
		if settings.visible:
			return
		var error := Developer.open_garden(context, reset.button_pressed, reset_digests)
		if error != OK:
			settings.begin(context.app_settings)
			settings.notice.text = context.notice.text
			reset_digests = {}
		return
	settings.save()
	if settings.visible:
		return
	var result := Developer.open_garden(context,reset.button_pressed)
	if result != OK:
		context.notice.text = "The Developer Garden is already open." if result == ERR_BUSY else "Could not open the Developer Garden (%s)." % error_string(result)


func run_tool(action: String) -> void:
	if not toggle.button_pressed:
		return
	if not Developer.can_edit(context):
		var pending := Transactions.pending_notice(context)
		settings.notice.text = "Developer tools are available in the single-player Developer Garden." if pending.is_empty() else pending
		return
	var result := ""
	var tech := ""
	match action:
		"grant":
			result = Developer.grant_resources(context)
		"materials":
			result = Developer.stock_materials(context)
		"finish":
			tech = context.progress.heart.active
			result = Developer.finish_research(context)
		"unlock":
			if tech_picker.selected < 0:
				return
			tech = tech_picker.get_selected_metadata()
			result = Developer.test_unlock(context,tech)
	settings.notice.text = Transactions.feedback_text(context, result)
	refresh_tools()
	# An uncertain save retains tentative research in memory for recovery.
	var pending := Transactions.pending_notice(context)
	if not tech.is_empty() and context.progress.heart.has(tech) and (pending.is_empty() or pending == Transactions.CLEANUP_NOTICE):
		context.tell(context.HOST,result)
		settings.cancel()
		context.toggle_overlay(null)
