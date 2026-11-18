extends CanvasLayer
## Owns the gameplay HUD, overlay frames and checkpoint presentation.
## Receives display values and emits requests; it never receives Game or actors.
signal requested(command: String, data: Dictionary)
signal overlay_opened

const Style = preload("res://root_ui.gd")
const LOOK_NAMES = preload("res://character_appearance.gd").OPTIONS
@onready var _surface: Control = $Surface
var _panels: Dictionary = {}
var _features: Dictionary = {}
var _inventory_mount: VBoxContainer
var _bestiary_entries: VBoxContainer
var _travel_panel: PanelContainer
var _travel_label: Label
var _ready_button: Button
var _unready_button: Button
var _connection_panel: PanelContainer
var _connection_label: Label
var _recollection_menu: PanelContainer
var _deposit_menu: PanelContainer
var _deposit_pick: OptionButton
var _deposit_button: Button
var _abandon_confirmation: ConfirmationDialog
var _abandon_button: Button
var _checkpoint_menu: PanelContainer
var _checkpoint_cards: HBoxContainer
var _checkpoint_notice: Label
var _checkpoint_skip: Button
var _checkpoint_reroll: Button
var _checkpoint_offer_revision := 0
var _guide: Label
var _feedback: Label
var _session_label: Label
var _field_guide: PanelContainer
var _overlay: CenterContainer
var _overlay_shade: ColorRect
var _session_menu: PanelContainer
var _pack_menu: PanelContainer
var _menu_notice: Label
var _detail_label: Label
var _bestiary_menu: PanelContainer
var _appearance_menu: PanelContainer
var _appearance_button: Button
var _appearance_options: Array[Button] = []
var _player_hud: Control
var _prompt_panel: PanelContainer
var _toast_panel: PanelContainer
var _host_button: Button
var _join_button: Button
var _leave_button: Button
var _save_button: Button
var _title_confirmation: ConfirmationDialog
var _arena_button: Button
var _arena_setup_button: Button

func _ready() -> void:
	_surface.theme = Style.make_theme()
	_player_hud = preload("res://root_ui.gd").new()
	_surface.add_child(_player_hud)
	var menu_button := _button(_surface, "Menu  ·  Esc", func(): toggle_panel("session"))
	menu_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu_button.offset_left = -112
	menu_button.offset_right = -14
	menu_button.offset_top = 12
	menu_button.offset_bottom = 39

	var prompts := VBoxContainer.new()
	_surface.add_child(prompts)
	prompts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompts.alignment = BoxContainer.ALIGNMENT_END
	prompts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompts.offset_left = -295
	prompts.offset_right = 295
	prompts.offset_top = -252
	prompts.offset_bottom = -162
	_toast_panel = Style.panel(prompts, Color("#14262bda"), Vector2(10, 5))
	_toast_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_feedback = Style.label(_toast_panel, 14, Color("#9ddad7"))
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_panel = Style.panel(prompts, Color("#14262bea"), Vector2(12, 6))
	_prompt_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var context := VBoxContainer.new()
	context.add_theme_constant_override("separation", 2)
	_prompt_panel.add_child(context)
	_guide = Style.label(context, 16, Color("#fce8ab"))
	_guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label = Style.label(context, 14, Color("#e5edea"))
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_overlay_shade = ColorRect.new()
	_surface.add_child(_overlay_shade)
	_overlay_shade.color = Color("#07151ca0")
	_overlay_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay = preload("res://inventory_drop_surface.gd").new()
	_surface.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_session_menu = Style.panel(_overlay, Color("#14262b"), Vector2(20, 14))
	var menu:=VBoxContainer.new()
	menu.add_theme_constant_override("separation",10)
	_session_menu.add_child(menu)
	Style.label(menu,24,Color("#e6ddbd")).text="Game Menu"
	_session_label=Style.label(menu,14,Color("#c0cecf"))
	var sections:=HBoxContainer.new()
	sections.add_theme_constant_override("separation",18)
	menu.add_child(sections)
	var actions:=VBoxContainer.new()
	var session_actions:=VBoxContainer.new()
	for section in [actions,session_actions]:
		section.custom_minimum_size.x=204
		section.add_theme_constant_override("separation",12)
		sections.add_child(section)
	var resume:=_button(actions,"Resume",func():close_panels())
	resume.name="Resume"
	_session_menu.visibility_changed.connect(func():
		if _session_menu.visible and _overlay.visible:resume.grab_focus())
	_button(actions,"Inventory  ·  I",func():toggle_panel("pack"))
	_button(actions,"Field Guide  ·  F1",func():toggle_panel("guide"))
	_button(actions,"Wilds Bestiary",func():toggle_panel("bestiary"))
	_appearance_button=_button(actions,"Appearance",func():toggle_panel("appearance"))
	_button(actions,"Settings",func():requested.emit("settings",{}))
	Style.label(session_actions,16,Color("#c9d3a4")).text="Garden & Co-op"
	_save_button=_button(session_actions,"Save Garden",func():requested.emit("save",{}))
	_host_button=_button(session_actions,"Host Co-op",func():requested.emit("host",{}))
	_join_button=_button(session_actions,"Join by IP",func():requested.emit("join",{}))
	_leave_button=_button(session_actions,"Leave Session",func():requested.emit("leave",{}))
	var exit_row:=HBoxContainer.new()
	exit_row.add_theme_constant_override("separation",8)
	menu.add_child(exit_row)
	_abandon_button=_button(exit_row,"Abandon Expedition",func():requested.emit("abandon",{}))
	_button(exit_row,"Return to Main Menu",func():requested.emit("title",{}))
	_arena_button=_button(exit_row,"Neural Arena",func():requested.emit("arena_open",{}))
	_arena_setup_button=_button(exit_row,"Arena Setup",func():requested.emit("arena_setup",{}))
	configure_arena_menu(false)
	_travel_panel=Style.panel(_surface,Color("#14262b"),Vector2(16,10))
	_travel_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_travel_panel.offset_left=-240;_travel_panel.offset_right=240;_travel_panel.offset_top=48;_travel_panel.offset_bottom=194
	var ready_box:=VBoxContainer.new();_travel_panel.add_child(ready_box)
	_travel_label=Style.label(ready_box,16,Color("#ded9b7"));_travel_label.custom_minimum_size=Vector2(440,60);_travel_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var ready_actions:=HBoxContainer.new();ready_box.add_child(ready_actions)
	_ready_button=_button(ready_actions,"Ready at Gate",func():requested.emit("ready",{"unready":false}))
	_unready_button=_button(ready_actions,"Not Ready",func():requested.emit("ready",{"unready":true}))
	_travel_panel.hide()
	_connection_panel=Style.panel(_surface,Color("#14262b"),Vector2(16,10))
	_connection_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_connection_panel.offset_left=-238;_connection_panel.offset_right=238;_connection_panel.offset_top=-80;_connection_panel.offset_bottom=80
	var connecting:=VBoxContainer.new();_connection_panel.add_child(connecting)
	_connection_label=Style.label(connecting,18,Color("#ded9b7"));_connection_label.custom_minimum_size=Vector2(420,65);_connection_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_button(connecting,"Cancel Connection",func():requested.emit("cancel_connection",{}))
	_connection_panel.hide()
	_title_confirmation = ConfirmationDialog.new()
	add_child(_title_confirmation)
	_title_confirmation.title = "End this expedition?"
	_title_confirmation.dialog_text = "Leaving ends the expedition. Your run's Class XP, monster familiarity and carried items (including the safe pouch) will be forfeited. Courier deliveries and progression from earlier expeditions remain."
	_title_confirmation.ok_button_text = "Return to Main Menu"
	_title_confirmation.confirmed.connect(func(): requested.emit("confirm_title",{}))
	_menu_notice = Style.label(menu, 14, Color("#9ddad7"))
	_menu_notice.custom_minimum_size.x = 280
	_menu_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_pack_menu = Style.panel(_overlay, Color("#14262b"), Vector2(20, 14))
	var pack := VBoxContainer.new()
	_pack_menu.add_child(pack)
	Style.label(pack, 22, Color("#c9f5dd")).text = "Inventory  ·  I"
	_inventory_mount = pack
	_button(pack, "Close", func(): toggle_panel("pack"))

	_field_guide = Style.panel(_overlay, Color("#14262b"), Vector2(20, 14))
	var notes := VBoxContainer.new()
	_field_guide.add_child(notes)
	Style.label(notes, 22, Color("#c9f5dd")).text = "Field Guide  ·  F1"
	var body := Style.label(notes, 16, Color("#e5edea"))
	body.custom_minimum_size.x = 330
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = "WASD / Arrows  Move   Space  Strike\nShift  Dodge   Q / R  Class skills\n\nGARDEN\nE at Heart: research and class upgrades\nE at Altar: identify and combine seeds or parts\nE at Wilds Gate: craft and depart\nE at plots: plant, inspect or harvest · F harvests seeds\nE at spring: fill watering vessel\nI: inventory · O: inspect progression\n\nWILDS\nE: collect loot, use grafting altars or continue at the gate\nT: extract at every sixth cleared gate\nEsc: menu / abandon expedition"
	_button(notes, "Close", func(): toggle_panel("guide"))
	_appearance_menu = Style.panel(_overlay, Color("#14262b"), Vector2(22, 20))
	var looks := VBoxContainer.new()
	_appearance_menu.add_child(looks)
	Style.label(looks, 22, Color("#ddd2aa")).text = "Character appearance"
	Style.label(looks, 13, Color("#acaa8a")).text = "Choose your travelling clothes in the Garden."
	for index in 5:
		var option := _button(looks, "", func(): requested.emit("appearance",{"index":index}))
		option.custom_minimum_size.x = 300
		_appearance_options.append(option)
	_button(looks, "Close", func(): toggle_panel("appearance"))
	_bestiary_menu = Style.panel(_overlay, Color("#14262b"), Vector2(22,18))
	var bestiary := VBoxContainer.new()
	_bestiary_menu.add_child(bestiary)
	Style.label(bestiary,22,Color("#ddd2aa")).text = "Creatures of the corrupted network"
	var legend := Style.label(bestiary,13,Color("#aabf91"))
	legend.custom_minimum_size.x = 540
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.text = "Bark plates resist heavy hits. Long tendrils extend reach. Swollen sacs widen attacks. New frills and roots signal speed and cover vaults."
	var scroll := ScrollContainer.new()
	bestiary.add_child(scroll)
	scroll.custom_minimum_size = Vector2(550,410)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var entries := VBoxContainer.new()
	scroll.add_child(entries)
	entries.add_theme_constant_override("separation",8)
	_bestiary_entries = entries
	_button(bestiary, "Close", func(): toggle_panel("bestiary"))
	_build_support_panels()
	_build_checkpoint_panel()
	_overlay.inventory_drop_requested.connect(func(data: Dictionary):requested.emit("inventory_drop",data))
	_overlay.bind_inventory_panel(_pack_menu)
	_panels.merge({"session":_session_menu,"pack":_pack_menu,"guide":_field_guide,
		"bestiary":_bestiary_menu,"appearance":_appearance_menu,"recollection":_recollection_menu,
		"deposit":_deposit_menu,"checkpoint":_checkpoint_menu})
	_travel_panel.name = "TravelPanel"
	_travel_label.name = "TravelLabel"
	_ready_button.name = "ReadyButton"
	_unready_button.name = "UnreadyButton"
	_connection_panel.name = "ConnectionPanel"
	_connection_label.name = "ConnectionLabel"
	_recollection_menu.name = "RecollectionMenu"
	_deposit_menu.name = "DepositMenu"
	_deposit_pick.name = "DepositPick"
	_deposit_button.name = "DepositButton"
	_abandon_confirmation.name = "AbandonConfirmation"
	_abandon_button.name = "AbandonButton"
	_checkpoint_menu.name = "CheckpointMenu"
	_checkpoint_cards.name = "CheckpointCards"
	_checkpoint_notice.name = "CheckpointNotice"
	_checkpoint_skip.name = "CheckpointSkip"
	_checkpoint_reroll.name = "CheckpointReroll"
	_guide.name = "Guide"
	_feedback.name = "Feedback"
	_session_label.name = "SessionLabel"
	_field_guide.name = "FieldGuide"
	_overlay.name = "Overlay"
	_overlay_shade.name = "OverlayShade"
	_session_menu.name = "SessionMenu"
	_pack_menu.name = "PackMenu"
	_menu_notice.name = "MenuNotice"
	_detail_label.name = "DetailLabel"
	_bestiary_menu.name = "BestiaryMenu"
	_appearance_menu.name = "AppearanceMenu"
	_appearance_button.name = "AppearanceButton"
	_player_hud.name = "PlayerHud"
	_prompt_panel.name = "PromptPanel"
	_toast_panel.name = "ToastPanel"
	_host_button.name = "HostButton"
	_join_button.name = "JoinButton"
	_leave_button.name = "LeaveButton"
	_save_button.name = "SaveButton"
	_title_confirmation.name = "TitleConfirmation"
	close_panels()

func _build_support_panels() -> void:
	_deposit_menu=Style.panel(_overlay,Color("#14262b"),Vector2(20,14))
	var box:=VBoxContainer.new()
	_deposit_menu.add_child(box)
	Style.label(box,22,Color("#dfd4a6")).text="Returning Mycelium"
	Style.label(box,14,Color("#c8d1ad")).text="Send one carried item home from this checkpoint."
	_deposit_pick=OptionButton.new()
	_deposit_pick.custom_minimum_size.x=420
	box.add_child(_deposit_pick)
	_deposit_button=_button(box,"Bank selected item",func():
		if _deposit_pick.selected<0: return
		var value:=_deposit_pick.get_item_id(_deposit_pick.selected)
		requested.emit("bank",{"value":value})
		close_panels())
	_button(box,"Keep exploring",func(): close_panels())
	_recollection_menu=Style.panel(_overlay,Color("#14262b"),Vector2(22,18))
	var story:=VBoxContainer.new()
	_recollection_menu.add_child(story)
	Style.label(story,24,Color("#ead8a3")).text="The Heart Remembers"
	var text:=Style.label(story,16,Color("#d4d7b5"))
	text.custom_minimum_size.x=520
	text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	text.text="Every root has found its lost memory. The civilization, the corruption, the sacrifice: the Heart remembers it all.\n\nIt remembers what it protected. It remembers what people asked of it. And now it fears the Garden will repeat that ending.\n\nIts final remembrance is awake. Prepare your weapon, then face the Heart."
	_button(story,"Prepare in the Garden",func(): close_panels())
	_button(story,"Face the Heart",func():
		close_panels()
		requested.emit("face_heart",{}))

func _build_checkpoint_panel() -> void:
	_abandon_confirmation=ConfirmationDialog.new()
	_abandon_confirmation.title="Abandon this expedition?"
	_abandon_confirmation.dialog_text="Return to the Garden now? All carried seeds, materials, monster cargo and safe-pouch contents will be lost.
No expedition milestone, research or guardian-memory rewards will be granted.
All Class XP and monster familiarity earned this run, including earlier cleared floors, will be revoked. Courier deliveries and progression from earlier expeditions remain."
	_abandon_confirmation.ok_button_text="Abandon & return"
	_abandon_confirmation.cancel_button_text="Keep exploring"
	add_child(_abandon_confirmation)
	_abandon_confirmation.confirmed.connect(func(): requested.emit("confirm_abandon",{}))
	_checkpoint_menu=Style.panel(_overlay,Color("#14262b"),Vector2(22,18))
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",14);_checkpoint_menu.add_child(box)
	Style.label(box,25,Color("#e4d7a5")).text="Roots of Strength"
	_checkpoint_notice=Style.label(box,15,Color("#c8d1bd"))
	_checkpoint_cards=HBoxContainer.new();_checkpoint_cards.add_theme_constant_override("separation",14);box.add_child(_checkpoint_cards)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",14)
	box.add_child(controls)
	_checkpoint_skip = _button(controls,"Continue without another upgrade",func():
		if _checkpoint_offer_revision > 0:
			choose_checkpoint("skip"))
	_checkpoint_reroll = _button(controls,"Reroll",func():
		choose_checkpoint("reroll"))
	_checkpoint_reroll.hide()

func show_checkpoint_offer(offer: Dictionary, wallet: int, floor_number: int, waiting: bool) -> void:
	# Rendering receives detached host-owned offer data; it never rolls or acquires.
	offer = offer.duplicate(true)
	var cards: Array = offer.choices
	_checkpoint_offer_revision = int(offer.revision)
	_checkpoint_reroll.visible = not waiting and not offer.closed and not offer.exhausted
	for child in _checkpoint_cards.get_children():
		_checkpoint_cards.remove_child(child)
		child.queue_free()
	_checkpoint_notice.text = "Checkpoint %d · %d Essence · %d/%d upgrades claimed" % [floor_number,wallet,offer.acquired,offer.limit]
	if offer.exhausted:
		_checkpoint_notice.text += "\nUpgrade limit reached. Continue at the Gate."
	elif offer.closed:
		_checkpoint_notice.text += "\nThis checkpoint choice is complete."
	elif cards.is_empty():
		_checkpoint_notice.text += "\nNo eligible upgrades for your build. You can continue at the Gate."
	else:
		_checkpoint_notice.text += "\nChoose one free upgrade."
	var cost: int = offer.reroll_cost
	_checkpoint_reroll.text = "Reroll · %d Essence" % cost if cost > 0 else "Rerolls used"
	_checkpoint_reroll.disabled = not offer.reroll_enabled
	_checkpoint_reroll.tooltip_text = offer.reroll_reason
	if waiting:
		_checkpoint_notice.text = "Ready. Waiting for party."
	var width: float = 225
	for data in cards:
		var frame := Style.panel(_checkpoint_cards,Color("#14262b"),Vector2(12,12))
		frame.custom_minimum_size = Vector2(width,340)
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation",10)
		frame.add_child(card)
		var title := Style.label(card,18,Color("#e4d7a5"))
		title.text = str(data.title)
		title.add_theme_color_override("font_color",Color({"Common":"#d0d1b3","Uncommon":"#a3c57b","Rare":"#83b7d7","Epic":"#b99adb"}.get(str(data.get("rarity","Common")),"#e4d7a5")))
		title.custom_minimum_size = Vector2(width-28,0)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		Style.label(card,14,Color("#a3c57b")).text = "%s · %s" % [data.scope,"Unique" if data.unique else data.rarity]
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(width-28,166)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		card.add_child(scroll)
		var description := Style.label(scroll,14,Color("#c8d1bd"))
		description.text = str(data.description)
		description.custom_minimum_size.x = width-40
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var preview: String = data.get("preview", "")
		if not preview.is_empty():
			description.text += "\n\n" + preview
		var short_text := description.text
		var details := Button.new()
		details.text = "Details"
		card.add_child(details)
		details.toggle_mode = true
		details.add_theme_font_size_override("font_size",13)
		details.tooltip_text = data.get("detail","")
		details.toggled.connect(func(expanded: bool):
			details.text = "Hide details" if expanded else "Details"
			description.text = short_text + "\n\n" + str(data.get("detail","")) if expanded else short_text
			scroll.focus_mode = Control.FOCUS_ALL if expanded else Control.FOCUS_NONE
			scroll.scroll_vertical = 0)
		var choice := int(data.choice)
		var revision := int(offer.revision)
		var button := _button(card,"%d · Take upgrade" % (choice+1),func(): requested.emit("checkpoint",{"revision":revision,"choice":str(choice)}))
		button.add_theme_font_size_override("font_size",13)
		button.disabled = waiting or not bool(data.enabled)
	_checkpoint_skip.text = "Waiting for party…" if waiting else "Continue at the Gate" if offer.exhausted or offer.closed or cards.is_empty() else "Skip upgrade"
	_checkpoint_skip.disabled = waiting
	if not _checkpoint_menu.visible:
		toggle_panel("checkpoint")

func present_travel(state: Dictionary, heart_route: bool) -> void:
	_travel_panel.visible=not state.is_empty() and not _overlay.visible
	if state.is_empty(): return
	var count:=0;var rows: Array=[]
	for member in state.members:
		count+=int(member.ready);rows.append(str(member.name)+(" - Ready" if member.ready else " - Not ready"))
	var title: String={"depart":"Enter "+str(state.get("goal","the Wilds")),"advance":"Next stage","extract":"Extract to Garden"}.get(str(state.kind),"Party travel")
	_travel_label.text="%s - %d/%d ready\n%s"%[title,count,state.members.size(),"\n".join(rows)]
	_ready_button.text="Ready at Heart" if state.kind=="depart" and heart_route else "Ready at Gate"
	_ready_button.disabled=bool(state.ready);_unready_button.disabled=not bool(state.ready)

func present_feedback(message: String, pending: bool) -> void:
	_feedback.text = message
	var message_width := 0.0
	for line in _feedback.text.split("\n"):
		message_width = maxf(message_width, _feedback.get_theme_font("font").get_string_size(line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, _feedback.get_theme_font_size("font_size")).x)
	_feedback.custom_minimum_size.x = minf(message_width + 2.0, 500.0)
	var fresh_notice := not _feedback.text.is_empty()
	_toast_panel.z_index = 1 if pending else 0
	_toast_panel.visible = fresh_notice and (not _overlay.visible or (pending and not _session_menu.visible))
	_menu_notice.text = _feedback.text
	_menu_notice.visible = fresh_notice


# Control construction is shared styling, not world orchestration.
func _button(parent: Control, caption: String, action: Callable) -> Button:
	return Style.button(parent,caption,action,Control.FOCUS_ALL if is_instance_valid(_overlay) and _overlay.is_ancestor_of(parent) else Control.FOCUS_NONE)

func is_overlay_open() -> bool:
	return _overlay.visible

func panel_is_open(kind: String) -> bool:
	return is_overlay_open() and _panels.has(kind) and _panels[kind].visible

func toggle_panel(kind: String) -> void:
	if _panels.has(kind): toggle_external(_panels[kind])

func close_panels() -> void:
	toggle_external(null)

func ensure_panel(kind: String) -> void:
	if not panel_is_open(kind): toggle_panel(kind)

func toggle_external(panel: PanelContainer) -> void:
	# All overlay frames, including feature-owned Garden views, share one lifecycle.
	assert(panel == null or panel.get_parent() == _overlay)
	var open := panel != null and not (_overlay.visible and panel.visible)
	_overlay.visible = open
	_overlay_shade.visible = open
	for child in _overlay.get_children():
		if child is Control: child.visible = open and child == panel
	if open: overlay_opened.emit()

func create_overlay_panel(color: Color, margin: Vector2) -> PanelContainer:
	var panel := Style.panel(_overlay,color,margin)
	panel.hide()
	return panel

func mount_prompt_control(control: Control) -> void:
	_detail_label.get_parent().add_child(control)

func mount_feature(kind: String, view: Control) -> void:
	# The shell owns frames. The feature owns its content and existing domain port.
	assert(not _features.has(kind))
	_features[kind] = view
	if kind == "progression":
		view.refresh_requested.connect(func(selection: Dictionary): requested.emit("refresh_progression",selection.duplicate(true)))
		view.requested.connect(_feature_request)
	if kind in ["inventory","loadout","summary"]:
		view.refresh_requested.connect(func(): requested.emit("refresh_"+kind,{}))
		view.requested.connect(_feature_request)
	view.name = kind.to_pascal_case()+"View"
	if kind == "inventory":
		_inventory_mount.add_child(view)
	elif kind == "summary":
		_overlay.add_child(view)
		_panels[kind] = view
	else:
		var frame := create_overlay_panel(Color("#14262b"),Vector2(20,14))
		frame.name = kind.to_pascal_case()+"Menu"
		_panels[kind] = frame
		frame.add_child(view)
	if kind != "inventory": _panels[kind].hide()

func refresh_inventory() -> void:
	_features.inventory.refresh()

func show_loadout() -> void:
	ensure_panel("loadout")
	_features.loadout.refresh()

func show_progression(from_crafting := false, heart := false) -> void:
	var view: Control = _features.progression
	if from_crafting:
		view.open_from_crafting()
	elif heart:
		view.tabs.current_tab = 1
		view.refresh()
		toggle_panel("progression")
		view.request_tree_base()
	else:
		toggle_panel("progression")

func show_graft(data: Dictionary) -> void:
	_features.graft.set_data(data.duplicate(true))
	ensure_panel("graft")

func show_altar(data: Dictionary) -> void:
	_features.altar.begin(data.duplicate(true))
	ensure_panel("altar")

func update_altar(data: Dictionary) -> void:
	_features.altar.set_data(data.duplicate(true))

func show_planting(slot: int, stock: Array) -> void:
	_features.planting.begin(slot,stock.duplicate(true))
	ensure_panel("planting")

func toggle_summary() -> void:
	if is_overlay_open() and not panel_is_open("summary"): return
	toggle_panel("summary")
	if panel_is_open("summary"): _features.summary.opened()

func close_run_flow() -> void:
	for kind in ["checkpoint","loadout","session","graft","altar"]:
		if panel_is_open(kind):
			close_panels()
			return
	if panel_is_open("progression") and _features.progression.from_crafting: close_panels()

func choose_checkpoint(choice: String) -> void:
	if _checkpoint_offer_revision > 0:
		requested.emit("checkpoint",{"revision":_checkpoint_offer_revision,"choice":choice})

func checkpoint_revision() -> int:
	return _checkpoint_offer_revision

func show_abandon_confirmation() -> void:
	_abandon_confirmation.popup_centered()

func show_title_confirmation() -> void:
	_title_confirmation.popup_centered(Vector2i(540,220))

func present_connection(waiting: bool, message: String) -> void:
	_connection_panel.visible = waiting
	if waiting: _connection_label.text = message

func show_deposit(items: Array) -> void:
	_deposit_pick.clear()
	for item in items: _deposit_pick.add_item(item.label,int(item.id))
	toggle_panel("deposit")

func present_hud(state: Dictionary, chart_expanded: bool) -> void:
	if panel_is_open("summary") and not bool(state.get("wild",false)): close_panels()
	_player_hud.set_chart_expanded(chart_expanded)
	_player_hud.update_state(state.duplicate(true))

func redraw_hud() -> void:
	_player_hud.queue_redraw()

func set_prompt(text: String) -> void:
	_guide.text = text
	_refresh_prompt()

func present_context(prompt: String, details: String) -> void:
	_guide.text = prompt
	_detail_label.text = details
	_refresh_prompt()

func _refresh_prompt() -> void:
	_detail_label.visible = not _detail_label.text.is_empty()
	_prompt_panel.visible = not is_overlay_open() and (not _guide.text.is_empty() or _detail_label.visible)

func present_menu(state: Dictionary) -> void:
	_session_label.text = state.session_text
	_host_button.text = "Share Join Address" if state.role == "Host" else "Host Co-op"
	_host_button.disabled = not state.can_host
	_join_button.disabled = not state.can_join
	_leave_button.disabled = not state.can_leave
	_save_button.disabled = not state.can_save
	_deposit_button.disabled = not state.can_bank
	_abandon_button.disabled = not state.wild
	_appearance_button.disabled = state.wild
	for i in _appearance_options.size():
		var values: Array = LOOK_NAMES[i]
		var choice := clampi(int(state.look[i]) if i < state.look.size() else 0,0,values.size()-1)
		_appearance_options[i].text = "%s: %s" % [["Cloak","Tunic","Hair color","Hair style","Skin"][i],values[choice]]
		_appearance_options[i].disabled = state.wild

func fill_bestiary(entries: Array) -> void:
	for entry in entries:
		Style.label(_bestiary_entries,16,Color("#e6ddbd")).text = entry.name
		var description := Style.label(_bestiary_entries,13,Color("#bdbda9"))
		description.custom_minimum_size.x = 520
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.text = entry.description

func _feature_request(command: String, data: Dictionary) -> void:
	match command:
		"close": close_panels()
		"build_class_tree": show_progression(true)
		"open_progression": toggle_panel("progression")
		_: requested.emit(command,data.duplicate(true))

func present_inventory(data: Dictionary) -> void:
	_features.inventory.present(data)

func present_loadout(data: Dictionary) -> void:
	_features.loadout.present(data)

func present_summary(data: Dictionary) -> void:
	_features.summary.present(data)

func summary_input(event: InputEvent, allowed: bool) -> bool:
	if not allowed or not event.is_action_pressed("run_summary"): return false
	if is_overlay_open() and not panel_is_open("summary"): return false
	toggle_summary()
	return true

func present_progression(data: Dictionary) -> void:
	_features.progression.present(data)

func configure_arena_menu(available: bool, in_arena: bool = false) -> void:
	_arena_button.visible = available and not in_arena
	_arena_setup_button.visible = in_arena
	for button in [_save_button,_host_button,_join_button,_leave_button,_abandon_button,_appearance_button]:
		button.visible = not in_arena
