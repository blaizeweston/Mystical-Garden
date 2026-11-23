extends CanvasLayer
## Owns the gameplay HUD, overlay frames and checkpoint presentation.
## Receives display values and emits requests; it never receives Game or actors.
signal requested(command: String, data: Dictionary)
signal overlay_opened

const Style = preload("res://root_ui.gd")
const CARD_BORDERS: Dictionary[String, Texture2D] = {
	"Common": preload("res://assets/ui/card_borders/common_paper_birch.png"),
	"Uncommon": preload("res://assets/ui/card_borders/uncommon_moss_green.png"),
	"Rare": preload("res://assets/ui/card_borders/rare_slate_blue.png"),
	"Epic": preload("res://assets/ui/card_borders/epic_amethyst.png"),
	"Unique": preload("res://assets/ui/card_borders/unique_dusty_rose.png"),
	"Mythic": preload("res://assets/ui/card_borders/mythic_garnet.png"),
}
const Appearance = preload("res://character_appearance.gd")
const LOOK_NAMES = Appearance.OPTIONS
var _panels: Dictionary = {}
var _features: Dictionary = {}
var _cinematic: Node
@onready var _inventory_mount: VBoxContainer = %InventoryMount
@onready var _bestiary_entries: VBoxContainer = %BestiaryEntries
@onready var _travel_panel: PanelContainer = %TravelPanel
@onready var _travel_label: Label = %TravelLabel
@onready var _ready_button: Button = %ReadyButton
@onready var _unready_button: Button = %UnreadyButton
@onready var _connection_panel: PanelContainer = %ConnectionPanel
@onready var _connection_label: Label = %ConnectionLabel
@onready var _recollection_menu: PanelContainer = %RecollectionMenu
@onready var _deposit_menu: PanelContainer = %DepositMenu
@onready var _deposit_pick: OptionButton = %DepositPick
@onready var _deposit_button: Button = %DepositButton
@onready var _abandon_confirmation: ConfirmationDialog = %AbandonConfirmation
@onready var _abandon_button: Button = %AbandonButton
@onready var _checkpoint_menu: PanelContainer = %CheckpointMenu
@onready var _checkpoint_cards: HBoxContainer = %CheckpointCards
@onready var _checkpoint_notice: Label = %CheckpointNotice
@onready var _checkpoint_skip: Button = %CheckpointSkip
@onready var _checkpoint_reroll: Button = %CheckpointReroll
var _checkpoint_offer_revision := 0
@onready var _guide: Label = %Guide
@onready var _feedback: Label = %Feedback
@onready var _session_label: Label = %SessionLabel
@onready var _field_guide: PanelContainer = %FieldGuide
@onready var _overlay: CenterContainer = %Overlay
@onready var _overlay_shade: ColorRect = %OverlayShade
@onready var _session_menu: PanelContainer = %SessionMenu
@onready var _pack_menu: PanelContainer = %PackMenu
@onready var _menu_notice: Label = %MenuNotice
@onready var _detail_label: Label = %DetailLabel
@onready var _bestiary_menu: PanelContainer = %BestiaryMenu
@onready var _appearance_menu: PanelContainer = %AppearanceMenu
@onready var _appearance_button: Button = %AppearanceButton
@onready var _appearance_options: Array[Button] = [%HoodColorOption,%ClothingColorOption,%HairColorOption,%HairStyleOption,%SkinOption,%HoodOption,%ShoulderArmorOption,%BracersOption,%BeltsOption]
@onready var _player_hud: Control = %PlayerHud
@onready var _prompt_panel: PanelContainer = %PromptPanel
@onready var _toast_panel: PanelContainer = %ToastPanel
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _leave_button: Button = %LeaveButton
@onready var _save_button: Button = %SaveButton
@onready var _title_confirmation: ConfirmationDialog = %TitleConfirmation
@onready var _arena_button: Button = %ArenaButton
@onready var _arena_setup_button: Button = %ArenaSetupButton

func _enter_tree() -> void:
	# Apply the shared theme before scene-authored children initialize their sizes.
	$Surface.theme = Style.make_theme()

func _ready() -> void:
	%MenuButton.pressed.connect(func(): toggle_panel("session"))
	%Resume.pressed.connect(close_panels)
	_session_menu.visibility_changed.connect(func():
		if _session_menu.visible and _overlay.visible: %Resume.grab_focus())
	%InventoryButton.pressed.connect(func(): toggle_panel("pack"))
	%GuideButton.pressed.connect(func(): toggle_panel("guide"))
	%BestiaryButton.pressed.connect(func(): toggle_panel("bestiary"))
	_appearance_button.pressed.connect(func(): toggle_panel("appearance"))
	%SettingsButton.pressed.connect(func(): requested.emit("settings",{}))
	_save_button.pressed.connect(func(): requested.emit("save",{}))
	_host_button.pressed.connect(func(): requested.emit("host",{}))
	_join_button.pressed.connect(func(): requested.emit("join",{}))
	_leave_button.pressed.connect(func(): requested.emit("leave",{}))
	_abandon_button.pressed.connect(func(): requested.emit("abandon",{}))
	%TitleButton.pressed.connect(func(): requested.emit("title",{}))
	_arena_button.pressed.connect(func(): requested.emit("arena_open",{}))
	_arena_setup_button.pressed.connect(func(): requested.emit("arena_setup",{}))
	_ready_button.pressed.connect(func(): requested.emit("ready",{"unready":false}))
	_unready_button.pressed.connect(func(): requested.emit("ready",{"unready":true}))
	%CancelConnection.pressed.connect(func(): requested.emit("cancel_connection",{}))
	_title_confirmation.confirmed.connect(func(): requested.emit("confirm_title",{}))
	_abandon_confirmation.confirmed.connect(func(): requested.emit("confirm_abandon",{}))
	%CloseInventory.pressed.connect(func(): toggle_panel("pack"))
	%CloseGuide.pressed.connect(func(): toggle_panel("guide"))
	%CloseAppearance.pressed.connect(func(): toggle_panel("appearance"))
	%CloseBestiary.pressed.connect(func(): toggle_panel("bestiary"))
	for index in _appearance_options.size():
		_appearance_options[index].pressed.connect(func(): requested.emit("appearance",{"index":index}))
	_deposit_button.pressed.connect(_request_deposit)
	%KeepExploring.pressed.connect(close_panels)
	%PrepareInGarden.pressed.connect(close_panels)
	%FaceHeart.pressed.connect(func():
		close_panels()
		requested.emit("face_heart",{}))
	_checkpoint_skip.pressed.connect(func():
		if _checkpoint_offer_revision > 0: choose_checkpoint("skip"))
	_checkpoint_reroll.pressed.connect(func(): choose_checkpoint("reroll"))
	_overlay.inventory_drop_requested.connect(func(data: Dictionary): requested.emit("inventory_drop",data))
	_overlay.bind_inventory_panel(_pack_menu)
	_panels.merge({"session":_session_menu,"pack":_pack_menu,"guide":_field_guide,
		"bestiary":_bestiary_menu,"appearance":_appearance_menu,"recollection":_recollection_menu,
		"deposit":_deposit_menu,"checkpoint":_checkpoint_menu})
	configure_arena_menu(false)
	close_panels()

func _request_deposit() -> void:
	if _deposit_pick.selected < 0: return
	requested.emit("bank",{"value":_deposit_pick.get_item_id(_deposit_pick.selected)})
	close_panels()

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
		var grade: String = "Unique" if data.unique else data.rarity
		var frame_style: StyleBoxTexture = frame.get_theme_stylebox("panel")
		frame_style.texture = CARD_BORDERS.get(grade, frame_style.texture)
		frame.custom_minimum_size = Vector2(width,340)
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation",10)
		frame.add_child(card)
		var title := Style.label(card,18,Color("#e4d7a5"))
		title.text = str(data.title)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_color_override("font_color",Color({"Common":"#d0d1b3","Uncommon":"#a3c57b","Rare":"#83b7d7","Epic":"#b99adb"}.get(str(data.get("rarity","Common")),"#e4d7a5")))
		title.custom_minimum_size = Vector2(width-28,0)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		Style.label(card,14,Color("#a3c57b")).text = "%s · %s" % [data.scope,grade]
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
	var count := 0
	for member in state.members:
		count += int(member.ready)
	var title: String={"depart":"Enter "+str(state.get("goal","the Wilds")),"advance":"Next stage","extract":"Extract to Garden"}.get(str(state.kind),"Party travel")
	_travel_label.text="%s - %d/%d ready"%[title,count,state.members.size()]
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


# Only variable offer/feature content is constructed at runtime. Static shell layout is scene-authored.
func _button(parent: Control, caption: String, action: Callable) -> Button:
	return Style.button(parent,caption,action,Control.FOCUS_ALL if is_instance_valid(_overlay) and _overlay.is_ancestor_of(parent) else Control.FOCUS_NONE)

## The view owns active playback; the shell exposes it as input eligibility.
func bind_cinematic(view: Node) -> void:
	assert(not is_instance_valid(_cinematic))
	_cinematic=view
func cinematic_active() -> bool:
	return is_instance_valid(_cinematic) and _cinematic.is_active()

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
	if kind != "progression": view.requested.connect(_feature_request)
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
	_features.graft.set_data(data)
	ensure_panel("graft")

func show_altar(data: Dictionary) -> void:
	_features.altar.begin(data)
	ensure_panel("altar")

func update_altar(data: Dictionary) -> void:
	_features.altar.set_data(data)

func show_planting(slot: int, stock: Array, selection_enabled := true) -> void:
	_features.planting.begin(slot,stock)
	_features.planting.set_selection_enabled(selection_enabled)
	ensure_panel("planting")

## World integration supplies eligibility; views never query actors or terrain.
func present_world_access(kind: String, allowed: bool) -> void:
	if not allowed and panel_is_open(kind): close_panels()

func present_planting_access(allowed: bool) -> void:
	if panel_is_open("planting"): _features.planting.set_selection_enabled(allowed)

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
	# At the Garden gate the workbench and the party vote can both be open.
	_player_hud.party_panel.loadout_left = _panels.loadout.get_global_rect().position.x if panel_is_open("loadout") else INF
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
	var look := Appearance.normalize(state.look)
	for i in _appearance_options.size():
		var values: Array = LOOK_NAMES[i]
		var choice: int = look[Appearance.option_field(i)]
		_appearance_options[i].text = "%s: %s" % [Appearance.LABELS[i],values[choice]]
		_appearance_options[i].tooltip_text = Appearance.TOOLTIPS[i]
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
