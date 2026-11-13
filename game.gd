extends Node3D

const Journal=preload("res://diagnostic_journal.gd")
var diagnostic_watch: Node
const HeartCatalog=preload("res://heart_catalog.gd")
const Skills = preload("res://skill_catalog.gd")
const Classes = preload("res://class_catalog.gd")
const Weapons = preload("res://weapon_system.gd")
const Seeds = preload("res://seed_catalog.gd")
const Enemies = preload("res://enemy_catalog.gd")
const Stage = preload("res://stage.gd")
const Progress = preload("res://progress.gd")
const AttackGeometry=preload("res://attack_geometry.gd")
const Transactions=preload("res://game_transaction.gd")
const SaveBatch=preload("res://save_batch.gd")
var transaction_publishes: Array=[]
var encounter_kills: Array=[]
var guardian_counts: Array=[0,0,0]
var encounter_rewarded:=false
var reward_retry_at:=0
const Director=preload("res://combat_director.gd")
const Learning=preload("res://wilds_learning.gd")
var leader_brain: Dictionary={}
var combat_threat: Dictionary={}
var combat_velocity: Dictionary={}
var combat_last_positions: Dictionary={}
var encounter_kill_records: Array=[]
const MonsterRewards=preload("res://monster_rewards.gd")
var pending_kill_rewards: Array=[]
var kill_receipts: Dictionary={}
var kill_reward_notices: Dictionary={}
var next_kill_reward_flush:=0
var moving_ranged_hits:=0
var encounter_started_at:=0
var encounter_party_size:=1
const PartyTravel=preload("res://party_travel.gd")
var travel_kind:=""
var travel_votes: Dictionary={}
var travel_members: Array=[]
var travel_epoch:=0
var travel_panel: PanelContainer
var travel_label: Label
var ready_button: Button
var unready_button: Button
const Network=preload("res://network_settings.gd")
var network_address:="127.0.0.1"
var network_port:=Network.DEFAULT_PORT
var connection_deadline:=0
var network_dialog: Window
var connection_panel: PanelContainer
var connection_label: Label
const AppSettings=preload("res://app_settings.gd")
const MouseCombat=preload("res://mouse_combat.gd")
var app_settings:=AppSettings.new()
var settings_path: String="user://settings.cfg"
var settings_dialog: Window
var mouse_controls:=MouseCombat.new()
const HOST := 1
static var PORT: int=clampi(int(OS.get_environment("MYSTICAL_GARDEN_TEST_PORT")),1024,65535) if not OS.get_environment("MYSTICAL_GARDEN_TEST_PORT").is_empty() else 24576
const MAX_HEALTH := 10
const ENEMY_HEALTH := 3
const WALK_SPEED := 5.5
const BRIAR_STRIKE_RADIUS := 1.8
const LONGLIMB_STRIKE_RADIUS := 3.0
const RANGED_DISTANCE := 2.75
const ENGAGE_RADIUS := 8.0
const SCOUT_RADIUS := 1.45
const BRIAR_WINDUP_MS := 650
const DODGE_DISTANCE := 2.8
const DODGE_COOLDOWN_MS := 850
const EncounterConfig=preload("res://encounter_config.gd")
const CHECKPOINT_INTERVAL := EncounterConfig.UPGRADE_INTERVAL
const EXTRACTION_INTERVAL := EncounterConfig.EXTRACTION_INTERVAL
const LoadoutMaterials=preload("res://loadout_materials.gd")
const ROUTE_ROOMS := EncounterConfig.BIOME_LENGTH
const ROOM_CURRENCY := 2
const RunUpgrades=preload("res://run_upgrade_catalog.gd")
const HOOK_ROOM := 3
const GRAFT_ROOM := EncounterConfig.GRAFT_INTERVAL
const GRAFT_CHANCE := 0.65
const Parts = preload("res://weapon_parts.gd")
const Frames = preload("res://weapon_frames.gd")
const Character = preload("res://character_profile.gd")
const Battlefield = preload("res://battlefield.gd")
const PACK_STRIDE := 8
const SPORE_RADIUS := 1.75
const SPORE_RANGE := 6.2
const Campaign = preload("res://campaign.gd")

@onready var stage: Stage = $Stage

var active_character_slot:=-1
var character_slot_claimed:=false
var character_storage_root:="user://saves/characters"
var active_slot := -1
var slot_claimed := false
var slot_heartbeat_at := 0.0
var slot_storage_root := "user://saves"
var joined_from_title := false
var returning_to_title := false
var title_confirmation: ConfirmationDialog
var enemy_stagger_until := 0
var progress := Progress.new()
var local_character := Character.new()
var guest_character := Character.new()
var character_dirty := false
var players := {}
var motions := {}
var enemy_attack_mode := ""
var enemy_landing := Vector3.ZERO
var enemy_kind := 0
var pending_finale_at:=0
var pending_finale_peer:=1
var enemy_haste_until:=0
var enemy_death_serial:=0
var enemy_death_events: Array=[]
var death_visuals: Node3D
const WeaponMotion=preload("res://weapon_motion.gd")
var combat_visuals: Node3D
var combat_events: Array=[]
var combat_event_serial:=0
var received_combat_events: Array=[]
var projectile_queue: Array=[]
var combat_epoch:=0
var scout_serial:=0
var enemy_mutations := 0
var enemy_growth := 0
var burst_hits_this_room := 0
var choke_kills_this_room := 0
var burst_clears := 0
var choke_clears := 0
var enemy_pos := Stage.ENEMY_START
var enemy_hp := ENEMY_HEALTH
var enemy_engaged := false
var scouts: Array[Dictionary] = []
var battlefield := Battlefield.new()
var client_pack := PackedFloat32Array()
var enemy_strike_at := 0
var enemy_ready_at := 0
var rooted_until := 0
var longlimb := false
var destination := Campaign.GROVE
var encounter_number := 1
var difficulty_cycle := 0
var run_guardians := 0
var map_seed := 0
var map_rng := RandomNumberGenerator.new()
var pressure_at := 0
var attack_pattern := 0
var active_radius := 0.0
var client_campaign := PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0])
var damage_this_room := 0
var ranged_damage_this_room := 0
var ranged_clears := 0
var enemy_winding_up := false
var moss_recovery_bonus := 0
var drop_pos := Vector3.ZERO
var has_drop := false
var depth := 1
var rng := RandomNumberGenerator.new()
var deepest_milestone := 0
var client_pouch_filled := false
var client_briar_bound := false
var recollection_menu: PanelContainer
var deposit_menu: PanelContainer
var deposit_pick: OptionButton
var deposit_button: Button
var recollection_checked:=false
var abandon_confirmation: ConfirmationDialog
var abandon_button: Button
var checkpoint_menu: PanelContainer
var checkpoint_cards: HBoxContainer
var checkpoint_notice: Label
var checkpoint_skip: Button
var checkpoint_pending:=false
var checkpoint_ready: Dictionary={}
const Altar=preload("res://altar_service.gd")
var altar_menu: PanelContainer
var altar_view: Control
var graft_menu: PanelContainer
var graft_view: Control
var loadout_menu: PanelContainer
var loadout_view: Control
var progression_menu: PanelContainer
var progression_view: Control

var client_garden := [0, false, false, [false, false, false], [false, false, false], [0, 0, 0], 0, false, 0, false, 0, false, PackedByteArray([0,0,0,0,0,0,0,0,0])]
var next_snapshot := 0.0
var next_details:=0.0
var client_details: Dictionary={}
var client_details_key: String=""
var session := "Solo"
var toast_until := 0
var status := "The Heart shelters this Garden. Follow the path to the Wilds gate.":
	get:
		var pending := Transactions.pending_notice(self)
		return status if pending.is_empty() else pending
	set(value):
		status = value
		toast_until = Time.get_ticks_msec() + 4800
var net_view=preload("res://network_presentation.gd").new()
var net_motion=preload("res://network_movement.gd").new()
var online_peer: ENetMultiplayerPeer
var network_compatibility: Node
const Bosses=preload("res://boss_encounters.gd")
const EnemyBehaviors=preload("res://enemy_behaviors.gd")
var boss_kind: int=-1
var boss_phase: int=0
var boss_moves: int=0
var boss_floors: Dictionary={}
var used_bosses: Array=[]
var enemy_hazards: Array=[]
var enemy_hazard_serial: int=0
const Traits=preload("res://combat_traits.gd")
var enemy_traits: Dictionary={}
var trait_events: Array=[]
const Life=preload("res://expedition_life.gd")
var spectator_view: Node
var client_inventory := [0, 0, 0, [false, false, false], 0, 0]
var client_carried_count := 0

var title: Label
var inventory: Label
var guide: Label
var feedback: Label
var session_label: Label
var field_guide: PanelContainer
var overlay: CenterContainer
var overlay_shade: ColorRect
var session_menu: PanelContainer
const Items=preload("res://item_catalog.gd")
const InventoryModel=preload("res://inventory_model.gd")
var inventory_view: Control
var wild_item_drops: Array=[]
var inventory_drop_visuals: Node
var pack_menu: PanelContainer
var health_label: Label
var menu_notice: Label
var skill_label: Label
var detail_label: Label
var bestiary_menu: PanelContainer
var appearance_menu: PanelContainer
var appearance_button: Button
var appearance_options: Array[Button] = []
const LOOK_NAMES=preload("res://character_appearance.gd").OPTIONS
var growth_clock := 0.0
var player_hud: Control
var exploration: Node
var planting_menu: PanelContainer
var planting_view: Control
var prompt_panel: PanelContainer
var toast_panel: PanelContainer
var host_button: Button
var join_button: Button
var leave_button: Button
var save_button: Button


func _init() -> void:
	guest_character.path = Life.Preview.STORAGE_PATH.path_join("character-local-guest.cfg") if Life.Preview.playtest else "user://character-local-guest.cfg"


func _ready() -> void:
	get_tree().auto_accept_quit = false
	toast_until = Time.get_ticks_msec() + 4800
	if not has_meta("guarded_title_session"):
		var character_error := local_character.load_profile()
		if character_error != OK and character_error != ERR_FILE_NOT_FOUND:
			status = "Character progress could not be loaded."
	configure_keys()
	var soundscape := preload("res://soundscape.gd").new()
	soundscape.name="Soundscape"
	add_child(soundscape)
	var event_audio := preload("res://event_audio.gd").new()
	event_audio.name = "EventAudio"
	add_child(event_audio)
	build_hud()
	settings_dialog=preload("res://settings_panel.gd").new()
	settings_dialog.developer_context=self
	add_child(settings_dialog)
	settings_dialog.applied.connect(func():player_hud.queue_redraw())
	death_visuals=preload("res://enemy_death_effects.gd").new()
	death_visuals.stage=stage
	stage.add_child(death_visuals)
	combat_visuals=preload("res://combat_effects.gd").new()
	combat_visuals.stage=stage
	stage.add_child(combat_visuals)
	exploration = preload("res://exploration.gd").new()
	add_child(exploration)
	spectator_view=preload("res://spectator_view.gd").new()
	add_child(spectator_view)
	if not has_meta("guarded_title_session"):
		var result := progress.load_garden()
		if result != OK and result != ERR_FILE_NOT_FOUND:
			status = "Could not read Garden save (error %d)." % result
	network_compatibility=preload("res://network_compatibility.gd").new()
	add_child(network_compatibility)
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	multiplayer.connected_to_server.connect(on_joined_world)
	multiplayer.connection_failed.connect(on_connection_failed)
	multiplayer.server_disconnected.connect(on_server_disconnected)
	add_player(HOST)
	diagnostic_watch=preload("res://diagnostic_watch.gd").new();diagnostic_watch.game=self;add_child(diagnostic_watch)
	preload("res://menu_button_roots.gd").watch(self,func():return app_settings.values.get("ambient_motion",true))


func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT: mouse_controls.release(self)
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if has_meta(Transactions.SESSION):
			if not Transactions.session_writable(self):
				set_meta(Transactions.STOPPING, true)
				get_tree().quit()
				return
			if not expedition_active() and character_dirty: save_local_character()
			set_meta(Transactions.STOPPING, true)
			get_tree().quit()
			return
		if session in ["Host","Solo"] and expedition_active():
			finish_failed_expedition()
		if character_dirty:
			save_local_character()
		get_tree().quit()


func configure_keys() -> void:
	app_settings.path=settings_path;app_settings.load_settings();app_settings.apply()


func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var surface := Control.new()
	layer.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.theme = preload("res://root_ui.gd").make_theme()

	player_hud = preload("res://root_ui.gd").new()
	surface.add_child(player_hud)
	var panel := hud_panel(surface, Color("#14262bca"), Vector2(10, 5))
	panel.hide()
	panel.position = Vector2(14, 12)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	rows.add_theme_constant_override("separation", 2)
	title = add_label(rows, 16, Color("#c9f5dd"))
	health_label = add_label(rows, 16, Color("#f7a899"))
	skill_label = add_label(rows, 13, Color("#c0cecf"))

	var menu_button := add_button(surface, "Menu  ·  Esc", func(): toggle_overlay(session_menu))
	menu_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu_button.offset_left = -112
	menu_button.offset_right = -14
	menu_button.offset_top = 12
	menu_button.offset_bottom = 39

	var prompts := VBoxContainer.new()
	surface.add_child(prompts)
	prompts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompts.alignment = BoxContainer.ALIGNMENT_END
	prompts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompts.offset_left = -295
	prompts.offset_right = 295
	prompts.offset_top = -252
	prompts.offset_bottom = -162
	toast_panel = hud_panel(prompts, Color("#14262bda"), Vector2(10, 5))
	toast_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	feedback = add_label(toast_panel, 14, Color("#9ddad7"))
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_panel = hud_panel(prompts, Color("#14262bea"), Vector2(12, 6))
	prompt_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var context := VBoxContainer.new()
	context.add_theme_constant_override("separation", 2)
	prompt_panel.add_child(context)
	guide = add_label(context, 16, Color("#fce8ab"))
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label = add_label(context, 14, Color("#e5edea"))
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	overlay_shade = ColorRect.new()
	surface.add_child(overlay_shade)
	overlay_shade.color = Color("#07151ca0")
	overlay_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay = preload("res://inventory_drop_surface.gd").new()
	overlay.game=self
	surface.add_child(overlay)
	preload("res://run_summary_panel.gd").mount(self)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	session_menu = hud_panel(overlay, Color("#14262b"), Vector2(20, 14))
	var menu:=VBoxContainer.new()
	menu.add_theme_constant_override("separation",10)
	session_menu.add_child(menu)
	add_label(menu,24,Color("#e6ddbd")).text="Game Menu"
	session_label=add_label(menu,14,Color("#c0cecf"))
	var sections:=HBoxContainer.new()
	sections.add_theme_constant_override("separation",18)
	menu.add_child(sections)
	var actions:=VBoxContainer.new()
	var session_actions:=VBoxContainer.new()
	for section in [actions,session_actions]:
		section.custom_minimum_size.x=204
		section.add_theme_constant_override("separation",12)
		sections.add_child(section)
	var resume:=add_button(actions,"Resume",func():toggle_overlay(null))
	resume.name="Resume"
	session_menu.visibility_changed.connect(func():
		if session_menu.visible and overlay.visible:resume.grab_focus())
	add_button(actions,"Inventory  ·  I",func():toggle_overlay(pack_menu))
	add_button(actions,"Field Guide  ·  F1",func():toggle_overlay(field_guide))
	add_button(actions,"Wilds Bestiary",func():toggle_overlay(bestiary_menu))
	appearance_button=add_button(actions,"Appearance",func():toggle_overlay(appearance_menu))
	add_button(actions,"Settings",func():mouse_controls.release(self);settings_dialog.begin(app_settings))
	add_label(session_actions,16,Color("#c9d3a4")).text="Garden & Co-op"
	save_button=add_button(session_actions,"Save Garden",func():save_progress(HOST,"Garden saved."))
	host_button=add_button(session_actions,"Host Co-op",func():
		if session=="Solo" and host_game()!=OK:
			return
		if session=="Host":
			network_dialog.begin_host(network_port,Network.lan_addresses(),"Your Garden",not expedition_active()))
	join_button=add_button(session_actions,"Join by IP",request_ip_join)
	leave_button=add_button(session_actions,"Leave Session",func():leave_game("Back in your own Garden."))
	var exit_row:=HBoxContainer.new()
	exit_row.add_theme_constant_override("separation",8)
	menu.add_child(exit_row)
	abandon_button=add_button(exit_row,"Abandon Expedition",request_abandon_run)
	add_button(exit_row,"Return to Main Menu",request_main_menu)
	network_dialog=preload("res://network_panel.gd").new();add_child(network_dialog)
	network_dialog.applied.connect(func(address: String,port: int,_join: bool):
		Network.save_settings(slot_storage_root,address,port)
		if join_game(address,port)!=OK:
			network_dialog.begin(address,port,true,str(local_character.data.get("name","Wanderer")),status))
	travel_panel=hud_panel(surface,Color("#14262b"),Vector2(16,10))
	travel_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	travel_panel.offset_left=-240;travel_panel.offset_right=240;travel_panel.offset_top=48;travel_panel.offset_bottom=194
	var ready_box:=VBoxContainer.new();travel_panel.add_child(ready_box)
	travel_label=add_label(ready_box,16,Color("#ded9b7"));travel_label.custom_minimum_size=Vector2(440,60);travel_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var ready_actions:=HBoxContainer.new();ready_box.add_child(ready_actions)
	ready_button=add_button(ready_actions,"Ready at Gate",func():send_travel_ready(false))
	unready_button=add_button(ready_actions,"Not Ready",func():send_travel_ready(true))
	travel_panel.hide()
	connection_panel=hud_panel(surface,Color("#14262b"),Vector2(16,10))
	connection_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	connection_panel.offset_left=-238;connection_panel.offset_right=238;connection_panel.offset_top=-80;connection_panel.offset_bottom=80
	var connecting:=VBoxContainer.new();connection_panel.add_child(connecting)
	connection_label=add_label(connecting,18,Color("#ded9b7"));connection_label.custom_minimum_size=Vector2(420,65);connection_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_button(connecting,"Cancel Connection",func():
		set_meta("join_cancelled",true)
		connection_rejected("Connection cancelled. Your character is preserved."))
	connection_panel.hide()
	title_confirmation = ConfirmationDialog.new()
	add_child(title_confirmation)
	title_confirmation.title = "End this expedition?"
	title_confirmation.dialog_text = "Returning to the main menu ends the expedition. Only safe-pouch contents are kept; unbanked loot is lost."
	title_confirmation.ok_button_text = "Return to Main Menu"
	title_confirmation.confirmed.connect(func(): return_to_main_menu())
	menu_notice = add_label(menu, 14, Color("#9ddad7"))
	menu_notice.custom_minimum_size.x = 280
	menu_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	pack_menu = hud_panel(overlay, Color("#14262b"), Vector2(20, 14))
	var pack := VBoxContainer.new()
	pack_menu.add_child(pack)
	add_label(pack, 22, Color("#c9f5dd")).text = "Inventory  ·  I"
	inventory = add_label(pack, 16, Color("#e5edea"))
	inventory.hide()
	inventory_view=preload("res://inventory_panel.gd").new()
	inventory_view.game=self
	pack.add_child(inventory_view)
	add_button(pack, "Close", func(): toggle_overlay(pack_menu))

	field_guide = hud_panel(overlay, Color("#14262b"), Vector2(20, 14))
	var notes := VBoxContainer.new()
	field_guide.add_child(notes)
	add_label(notes, 22, Color("#c9f5dd")).text = "Field Guide  ·  F1"
	var body := add_label(notes, 16, Color("#e5edea"))
	body.custom_minimum_size.x = 330
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = "WASD / Arrows  Move   Space  Strike\nShift  Dodge   Q / R  Class skills\n\nGARDEN\nE at Heart: research and class upgrades\nE at Altar: identify and combine seeds or parts\nE at Wilds Gate: craft and depart\nE at plots: plant, inspect or harvest · F harvests seeds\nE at spring: fill watering vessel\nI: inventory · O: inspect progression\n\nWILDS\nE: collect loot, use grafting altars or continue at the gate\nT: extract at every sixth cleared gate\nEsc: menu / abandon expedition"
	add_button(notes, "Close", func(): toggle_overlay(field_guide))
	appearance_menu = hud_panel(overlay, Color("#14262b"), Vector2(22, 20))
	var looks := VBoxContainer.new()
	appearance_menu.add_child(looks)
	add_label(looks, 22, Color("#ddd2aa")).text = "Character appearance"
	add_label(looks, 13, Color("#acaa8a")).text = "Choose your travelling clothes in the Garden."
	for index in 5:
		var option := add_button(looks, "", func(): send_garden_action("look_" + str(index)))
		option.custom_minimum_size.x = 300
		appearance_options.append(option)
	add_button(looks, "Close", func(): toggle_overlay(appearance_menu))
	bestiary_menu = hud_panel(overlay, Color("#14262b"), Vector2(22,18))
	var bestiary := VBoxContainer.new()
	bestiary_menu.add_child(bestiary)
	add_label(bestiary,22,Color("#ddd2aa")).text = "Creatures of the corrupted network"
	var legend := add_label(bestiary,13,Color("#aabf91"))
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
	for definition in Enemies.all():
		add_label(entries,16,Color("#e6ddbd")).text = definition.name
		var description := add_label(entries,13,Color("#bdbda9"))
		description.custom_minimum_size.x = 520
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.text = definition.description
	add_button(bestiary, "Close", func(): toggle_overlay(bestiary_menu))
	build_heart_panels()
	build_loadout_panel()
	build_run_flow_panels()
	build_grafting_panel()
	build_garden_altar_panel()
	build_planting_panel()
	inventory_drop_visuals=preload("res://inventory_drop_visuals.gd").new()
	inventory_drop_visuals.game=self
	add_child(inventory_drop_visuals)
	build_progression_panel()
	preload("res://garden_interaction_view.gd").mount(self)
	toggle_overlay(null)


func hud_panel(parent: Node, color: Color, margin: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := preload("res://root_ui.gd").root_style()
	style.content_margin_left = maxf(18.0, margin.x)
	style.content_margin_right = maxf(18.0, margin.x)
	style.content_margin_top = maxf(16.0, margin.y)
	style.content_margin_bottom = maxf(16.0, margin.y)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func toggle_overlay(panel: PanelContainer) -> void:
	var open := panel != null and not (overlay.visible and panel.visible)
	overlay.visible = open
	if open:
		var preview = preload("res://ability_aim.gd").active(self)
		if preview != null: preview.cancel()
	overlay_shade.visible = open
	for child in overlay.get_children():
		if child is Control and child.has_meta("garden_interaction_panel"): child.visible=open and child==panel
	var run_summary:=overlay.get_node_or_null("RunSummary")
	if run_summary != null: run_summary.visible=open and panel==run_summary
	session_menu.visible = open and panel == session_menu
	pack_menu.visible = open and panel == pack_menu
	field_guide.visible = open and panel == field_guide
	if appearance_menu != null:
		appearance_menu.visible = open and panel == appearance_menu
	if recollection_menu!=null: recollection_menu.visible=open and panel==recollection_menu
	if deposit_menu!=null: deposit_menu.visible=open and panel==deposit_menu
	if checkpoint_menu!=null: checkpoint_menu.visible=open and panel==checkpoint_menu
	if graft_menu!=null: graft_menu.visible=open and panel==graft_menu
	if altar_menu!=null: altar_menu.visible=open and panel==altar_menu
	if loadout_menu != null:
		loadout_menu.visible = open and panel == loadout_menu
	if planting_menu!=null: planting_menu.visible=open and panel==planting_menu
	if progression_menu != null:
		progression_menu.visible = open and panel == progression_menu
	if bestiary_menu != null:
		bestiary_menu.visible = open and panel == bestiary_menu


func add_label(parent: Control, size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func add_button(parent: Control, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_ALL if is_instance_valid(overlay) and overlay.is_ancestor_of(parent) else Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func host_game(port: int=0) -> Error:
	if not Transactions.pending_notice(self).is_empty(): return ERR_BUSY
	if has_meta("developer_garden"):
		status="The Developer Garden is single-player."
		return ERR_UNAVAILABLE
	Journal.event("network","host_requested",{"port":network_port if port==0 else port})
	if session!="Solo" or expedition_active(): return ERR_BUSY
	var selected_port:=network_port if port==0 else port
	if not Network.error("127.0.0.1",selected_port).is_empty(): return ERR_INVALID_PARAMETER
	var peer:=ENetMultiplayerPeer.new()
	peer.set_bind_ip("*")
	var result:=peer.create_server(selected_port,Network.GUEST_LIMIT)
	if result!=OK:
		Journal.event("network","host_failed",{"error":result,"port":selected_port},"error")
		status="Could not host on UDP port %d. Another host may already be using it."%selected_port;return result
	network_port=selected_port;online_peer=peer;multiplayer.multiplayer_peer=peer;session="Host"
	status="Hosting co-op on UDP port %d. Share your reachable IP with up to three friends."%network_port
	Journal.event("network","host_started",{"port":network_port})
	toggle_overlay(null);return OK


func on_joined_world() -> void:
	Journal.event("network","transport_connected")
	set_meta("join_phase","character")
	status = Network.join_progress("character",network_address,network_port)
	connection_deadline=Time.get_ticks_msec()+Network.REGISTER_TIMEOUT_MS
	toggle_overlay(null)
	register_character.rpc_id(HOST, guest_character.identity, guest_character.data,progress.ContentIDs.manifest(),Network.PROTOCOL)


@rpc("any_peer", "call_remote", "reliable")
func register_character(identity: String, profile: Dictionary,catalog: Dictionary={},protocol: int=0) -> void:
	if not Transactions.session_writable(self): return
	var id := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not players.has(id) or players[id].profile_ready:
		return
	var reason:=admission_error(identity,catalog,protocol)
	if var_to_bytes(profile).size()>32768: reason="This character profile is too large."
	if not reason.is_empty(): reject_peer(id,reason);return
	var incoming: Dictionary=Character.normalize(profile)
	var recorded=progress.character_records.get(identity,{})
	if recorded is Dictionary and recorded.get("profile") is Dictionary:
		var recovered: Dictionary=Character.normalize(progress.ContentIDs.profile(recorded.profile,recorded.get("manifest",progress.ContentIDs.legacy())))
		for field in ["plants","monsters"]:
			for i in incoming[field].size(): incoming[field][i]=maxi(int(incoming[field][i]),int(recovered[field][i]))
		for c in incoming.xp.size():
			var best:=maxi(int(incoming.xp[c])*10+int(incoming.xp_tenths[c]),int(recovered.xp[c])*10+int(recovered.xp_tenths[c]))
			incoming.xp[c]=best/10;incoming.xp_tenths[c]=best%10
	players[id].character = incoming
	players[id].seed_owner = identity
	players[id].profile_ready = true
	PartyTravel.cancel(self,"Party changed. Confirm readiness again.")
	restore_class_loadout(players[id])
	preload("res://garden_growth_service.gd").register(self,id)
	Journal.event("network","character_registered",{"actor":id,"class_id":incoming.get("active_class",0)})
	connection_accepted.rpc_id(id,incoming)


func join_game(address: String="",port: int=0) -> Error:
	if has_meta("developer_garden"):
		status="The Developer Garden is single-player."
		return ERR_UNAVAILABLE
	Journal.event("network","join_requested",{"port":network_port if port==0 else port})
	if session!="Solo" or expedition_active() or not Transactions.pending_notice(self).is_empty():
		return ERR_BUSY
	var host:=Network.address(network_address if address.is_empty() else address)
	var selected_port:=network_port if port==0 else port
	var problem:=Network.error(host,selected_port)
	if not problem.is_empty(): status=problem;return ERR_INVALID_PARAMETER
	var guarded = get_meta("guarded_title_session") if has_meta("guarded_title_session") else null
	var loaded: Error = guarded.reload_guest(guest_character) if guarded != null else guest_character.load_profile()
	if guarded != null and loaded != OK:
		status = "Could not read the selected character."
		return loaded
	if loaded!=OK and loaded!=ERR_FILE_NOT_FOUND: status="Could not read the selected character.";return loaded
	if slot_claimed:
		if guarded != null:
			if not save_session_garden(): return ERR_CANT_CREATE
		else:
			var saved := progress.save_garden()
			if saved != OK: status="Save the Garden before joining another host.";return saved
	if guarded == null and guest_character.save_profile() != OK:
		status = "Could not save the guest character identity."
		return ERR_CANT_CREATE
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(host, selected_port)
	if result != OK:
		Journal.event("network","join_failed",{"error":result},"error")
		status = "Could not start the connection. Check the address and port."
		return result
	net_view.clear();net_motion.clear()
	players.clear()
	motions.clear()
	client_details.clear();client_details_key="";received_combat_events.clear()
	network_address=host;network_port=selected_port;connection_deadline=Time.get_ticks_msec()+Network.CONNECT_TIMEOUT_MS
	online_peer = peer
	multiplayer.multiplayer_peer = peer
	session = "Connecting"
	set_meta("join_phase","connect")
	set_meta("join_cancelled",false)
	status = Network.join_progress("connect",network_address,network_port)
	toggle_overlay(null)
	return OK


func leave_game(message: String) -> void:
	Journal.event("network","leave_requested",{"role":session})
	if has_meta(Transactions.SESSION) and not Transactions.session_writable(self):
		_stop_guarded_session("This session lost access to its save. Returning to the title.")
		return
	if active_character_slot>=0 and session in ["Guest","Connecting"]:
		return_to_main_menu(message);return
	var was_guest := session == "Guest"
	if character_dirty:
		save_local_character()
		if not Transactions.pending_notice(self).is_empty(): return
	if session == "Host" and expedition_active():
		if has_meta(Transactions.SESSION):
			_stop_guarded_session("Returned to the title. Expedition settlement is unavailable in the guarded session.")
			return
		finish_failed_expedition()
	if online_peer != null:
		online_peer.close()
	online_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	net_view.clear();net_motion.clear()
	players.clear()
	motions.clear()
	destination = Campaign.GROVE
	reset_expedition()
	add_player(HOST)
	session = "Solo"
	if was_guest and active_slot >= 0:
		if has_meta("guarded_title_session"):
			if get_meta("guarded_title_session").reload_guest(local_character) != OK:
				_stop_guarded_session("Could not read the selected character.")
				return
		else:
			local_character.load_profile()
		players[HOST].character = local_character.data
	status = message


func add_player(id: int) -> void:
	if not multiplayer.is_server():
		return
	var used: Array=[]
	for existing in players.values(): used.append(int(existing.get("party_slot",0)))
	var party_slot:=0
	while party_slot in used: party_slot+=1
	if party_slot>=Network.MAX_PLAYERS:
		if online_peer!=null: online_peer.disconnect_peer(id)
		return
	var spawn: Vector3 = Stage.SPAWN + [Vector3.ZERO,Vector3(1.1,0,0),Vector3(-1.1,0,0),Vector3(0,0,1.1)][party_slot]
	var base_health:=Life.Preview.hp(MAX_HEALTH)
	players[id] = {"party_slot":party_slot,"velocity":Vector3.ZERO,"damage_seq":0,"damage_amount":0,"vitals_revision":0,"pos": spawn, "wild": false, "fallen": false, "lost_health":0, "prepared": 0, "weapon": 0, "experiment": 0, "spent": 0,"essence_sparks":0, "last_offer": 0,"run_upgrades":{},"checkpoint_offers":[],"offer_floor":0,"upgrade_seed":Crypto.new().generate_random_bytes(8).hex_encode().hash(), "power": 0, "technique": 0,
		"weapon_kind":0, "catalyst":0, "graft_part":0,"graft_floor":0, "prepared_catalyst":0, "cargo_plan":Parts.empty_counts(), "frame": Frames.WARDEN, "skill_at": 0, "skill_two_at":0, "guard_charges":0, "guard_until": 0, "attack_until":0,"attack_duration":240,"attack_combo":0,"swing_until": 0, "contributed": false,
		"character": local_character.data if id == HOST else Character.blank(), "profile_ready": id == HOST,"joined_at":Time.get_ticks_msec(),
		"seed_choice": 0, "seed_owner": "", "carried_seeds": [],"safe_items":[],"carried_items":{}, "pouch": false, "loot_pending": false,
		"donation_choice": Parts.EMPTY, "cache_claimed": false,
		"carried_parts": Parts.empty_counts(), "secondary": Parts.EMPTY,
		"prepared_secondary": Parts.EMPTY, "graft_choice": Parts.EMPTY, "rift_hook": false, "slow_until": 0, "hp": float(base_health), "max_hp": base_health, "strike_at": 0, "dodge_at": 0, "facing": Vector3.FORWARD}
	restore_class_loadout(players[id])
	preload("res://garden_growth_service.gd").register(self,id)


func remove_player(id: int) -> void:
	Journal.event("network","peer_disconnected",{"actor":id})
	if has_meta(Transactions.SESSION):
		# Disconnect can arrive during or after teardown. Keep transport cleanup
		# separate from rewards, profile records and expedition settlement.
		if multiplayer.is_server() and not returning_to_title and Transactions.session_writable(self):
			var leaving: Dictionary = players.get(id, {})
			if pending_kill_rewards.is_empty() and leaving.get("profile_ready", false):
				Transactions.run_gameplay(self, Transactions.Scope.PAIR, func():
					if not leaving.get("seed_owner", "").is_empty(): record_character(id)
					_recover_pouch(leaving)
					if leaving.wild:
						preload("res://garden_return_service.gd").outcome(self, leaving, "disconnected")
					return true)
			PartyTravel.cancel(self,"A player disconnected. Confirm readiness again to continue.")
		players.erase(id)
		motions.erase(id)
		refresh_drop()
		return
	if multiplayer.is_server():
		MonsterRewards.flush(self)
		if players.has(id) and players[id].profile_ready:
			if not players[id].get("seed_owner","").is_empty(): progress.character_records[players[id].seed_owner]={"profile":players[id].character.duplicate(true),"manifest":progress.ContentIDs.manifest()}
			recover_pouch(players[id])
			preload("res://garden_return_service.gd").member_left(self,players[id])
		players.erase(id)
		PartyTravel.cancel(self,"A player disconnected. Confirm readiness again to continue.")
		refresh_drop()
		motions.erase(id)
		abandon_if_empty()
		resume_checkpoint_if_ready()


func _input(event: InputEvent) -> void:
	if preload("res://ability_aim.gd").release_event(self,event):
		get_viewport().set_input_as_handled()
		return
	if get_meta("garden_cinematic_active",false):return
	if settings_dialog!=null and settings_dialog.visible: return
	if preload("res://run_summary_panel.gd").handle_input(self,event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("session_menu"):
		toggle_overlay(null if overlay.visible else session_menu)
	elif event.is_action_pressed("pack_menu"):
		toggle_overlay(pack_menu)
	elif event.is_action_pressed("workbench"):
		toggle_overlay(loadout_menu)
	elif event.is_action_pressed("progression"):
		toggle_overlay(progression_menu)
	elif event.is_action_pressed("field_guide"):
		toggle_overlay(field_guide)
	else:
		return
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton: _unhandled_key_input(event)

func _unhandled_key_input(event: InputEvent) -> void:
	if get_meta("garden_cinematic_active",false):return
	if settings_dialog!=null and settings_dialog.visible: return
	mouse_controls.frame(self)
	if session=="Connecting" or (session=="Guest" and client_details.is_empty()):
		if event.is_action_pressed("session_menu"): connection_rejected("Connection cancelled. Your character is preserved.")
		return
	if checkpoint_menu.visible:
		for index in 4:
			if event.is_action_pressed(["upgrade_power","upgrade_technique","upgrade_synergy","upgrade_fourth"][index]):
				send_garden_action("checkpoint_choice_%d"%index)
				get_viewport().set_input_as_handled()
				return
	if overlay.visible:
		return
	if preload("res://ability_aim.gd").input_event(self,event):
		get_viewport().set_input_as_handled()
		return
	var local_player: Dictionary=players.get(HOST if multiplayer.is_server() else multiplayer.get_unique_id(),{})
	if not local_player.get("wild",false):
		for old_action in ["research","experiment","catalyst","graft","select_graft","donate","select_donation","awaken","destination","nurture","harvest_offshoot","trait","frame","expand_plot"]:
			if event.is_action_pressed(old_action): return
		if event.is_action_pressed("craft") and nearby_plot(local_player.get("pos",Vector3.INF))<0: return
	if event.is_action_pressed("interact"):
		send_action(false)
	elif event.is_action_pressed("pouch"):
		send_garden_action("pouch")
	elif event.is_action_pressed("research"):
		send_garden_action("research")
	elif event.is_action_pressed("flower"):
		preload("res://garden_crop_view.gd").flower_shortcut(self)
	elif event.is_action_pressed("experiment"):
		send_garden_action("experiment")
	elif event.is_action_pressed("catalyst"):
		send_garden_action("catalyst")
	elif event.is_action_pressed("craft"):
		send_garden_action("craft")
	elif event.is_action_pressed("upgrade_power"):
		send_garden_action("upgrade_power")
	elif event.is_action_pressed("upgrade_technique"):
		send_garden_action("upgrade_technique")
	elif event.is_action_pressed("upgrade_synergy"):
		send_garden_action("upgrade_synergy")
	elif event.is_action_pressed("expand_plot"):
		send_garden_action("expand_plot")
	elif event.is_action_pressed("extract"):
		send_garden_action("extract")
	elif event.is_action_pressed("graft"):
		send_garden_action("graft")
	elif event.is_action_pressed("select_graft"):
		send_garden_action("select_graft")
	elif event.is_action_pressed("donate"):
		send_garden_action("donate")
	elif event.is_action_pressed("select_donation"):
		send_garden_action("select_donation")
	elif event.is_action_pressed("awaken"):
		send_garden_action("awaken")
	elif event.is_action_pressed("destination"):
		send_garden_action("destination")
	elif event.is_action_pressed("nurture"):
		send_garden_action("nurture")
	elif event.is_action_pressed("harvest_offshoot"):
		send_garden_action("harvest_offshoot")
	elif event.is_action_pressed("trait"):
		send_garden_action("trait")
	elif event.is_action_pressed("frame"):
		send_garden_action("frame")
	elif event.is_action_pressed("dodge"):
		var direction := Input.get_vector("left", "right", "up", "down")
		if multiplayer.is_server():
			dodge_player(HOST, direction)
		elif session == "Guest":
			request_dodge.rpc_id(HOST, direction)


func send_action(strike: bool) -> void:
	if multiplayer.is_server():
		act(HOST, strike)
	elif session == "Guest":
		request_action.rpc_id(HOST, strike)


func send_garden_action(action: String) -> void:
	if not Transactions.pending_notice(self).is_empty(): return
	if not (action.begins_with("core_cast:") or action.begins_with("class_cast:")): Journal.interaction(self,multiplayer.get_unique_id(),action,"requested")
	if action in ["class_skill","class_skill_two"] and encounter_cleared(): return
	if multiplayer.is_server():
		garden_action(HOST, action)
	elif session == "Guest":
		request_garden_action.rpc_id(HOST, action)


@rpc("any_peer", "call_remote", "reliable")
func request_garden_action(action: String) -> void:
	if multiplayer.is_server() and action.length()<=512 and allow_remote(multiplayer.get_remote_sender_id(),"action",30):
		garden_action(multiplayer.get_remote_sender_id(), action)


func garden_action(id: int, action: String) -> void:
	if not Transactions.session_writable(self): return
	if action.begins_with("core_cast:"):
		preload("res://core_combat.gd").command(self,id,players.get(id,{}),action)
		return
	if action.begins_with("class_cast:"):
		preload("res://ability_aim.gd").command(self,id,players.get(id,{}),action)
		return
	var diagnostic_request:=Journal.interaction(self,id,action,"begin")
	var persistent: bool=action in ["experiment","donate"] or action.begins_with("breed_") or action.begins_with("care_")
	if persistent: Transactions.run(self,func(): _garden_action(id,action))
	else: _garden_action(id,action)
	Journal.interaction(self,id,action,"end",diagnostic_request)

func _garden_action(id: int, action: String) -> void:
	if not players.has(id):
		return
	var player: Dictionary = players[id]
	if action=="spring_fill":
		preload("res://garden_crop_service.gd").fill_water(self,id);return
	if action.begins_with("growth_ack:"):
		preload("res://garden_growth_service.gd").acknowledge(self,id,action.trim_prefix("growth_ack:"));return
	if action.begins_with("garden:"):
		preload("res://garden_interaction_service.gd").command(self,id,action.trim_prefix("garden:"));return
	if player.get("fallen",false) and player.get("wild",false) and action!="abandon_run": return
	if not player.profile_ready:
		return
	if action.begins_with("revive:"):
		var target:=action.get_slice(":",1)
		if target.is_valid_int(): Transactions.run(self,func(): return Life.revive(self,id,int(target)))
		return
	if action.begins_with("altar:"):
		handle_altar_action(id,player,action.trim_prefix("altar:"))
		return
	if action=="altar_identify":
		if at_garden_altar(player):
			run_altar_save(id, player, Altar.identify.bind(self, player))
		return
	if action.begins_with("inventory:"):
		handle_inventory_action(id,player,action.trim_prefix("inventory:"))
		return
	if action.begins_with("graft_install_"):
		var value:=action.trim_prefix("graft_install_")
		if value.is_valid_int() and int(value)>0: attempt_graft(id,player,int(value))
		if at_graft_altar(player): show_graft_menu(id)
		return
	if action=="abandon_run":
		abandon_run(id,player)
		return
	if action.begins_with("care_"):
		var pieces:=action.split("_")
		if pieces.size()!=3 or not pieces[2].is_valid_int(): return
		var value:=int(pieces[2])
		if pieces[1]=="reclaim" and value>=0 and value<Seeds.NAMES.size() and progress.discoveries[value] and at_garden_station(player,"seed_archive"):
			player.reclaim_choice=value
			reclaim_seed(id,player)
		elif pieces[1]=="offer" and Parts.is_monster(value) and at_garden_station(player,"monster_studies"):
			if stored_counts(player)[value]<=0:
				tell(id,"That trophy is no longer available.")
				return
			player.offering_choice=value
			offer_monster(id,player)
		else:
			tell(id,"Move to the appropriate Garden station with an available ingredient.")
		return
	if action.begins_with("plant_at_"):
		var fields:=action.split("_")
		if fields.size()!=4 or not fields[2].is_valid_int() or not fields[3].is_valid_int(): return
		var slot:=int(fields[2]);var species:=int(fields[3])
		if player.wild or slot<0 or slot>=progress.plots.size() or species<0 or species>=Seeds.NAMES.size() or player.pos.distance_to(Stage.PLOTS[slot])>1.65: return
		if progress.plots[slot].species>=0 or progress.offshoot_in_bed(slot)>=0 or seed_reserve(player).stock[species]<=0:
			tell(id,"That bed or seed is no longer available.");show_planting_picker(id,slot);return
		player.seed_choice=species
		if plant_seed(id,slot):
			if id==HOST: toggle_overlay(null)
			else: close_planting_picker.rpc_id(id)
		return
	if action.begins_with("travel_ready:") or action.begins_with("travel_unready:"):
		var token:=action.get_slice(":",1)
		if not token.is_valid_int() or int(token)!=travel_epoch or travel_kind.is_empty(): return
		if action.begins_with("travel_unready:"): travel_votes.erase(id)
		else: PartyTravel.request(self,id,travel_kind)
		return
	if action=="depart":
		if at_weapon_gate(player):
			enter_wilds(id,player)
			if player.wild:
				if id==HOST: close_run_flow_panel()
				elif online_peer!=null: close_run_flow_panel.rpc_id(id)
		return
	if action.begins_with("checkpoint_choice_"):
		var value:=action.trim_prefix("checkpoint_choice_")
		if value.is_valid_int(): choose_checkpoint_card(id,player,int(value))
		return
	if action.begins_with("heart_material_"):
		if at_heart(player) and not player.wild:
			var choice:=action.trim_prefix("heart_material_")
			if choice=="auto" or Seeds.index_of(choice)>=0: progress.heart.material_choice="" if choice=="auto" else choice
		return
	if action.begins_with("heart_confirm:"):
		if id!=HOST or not at_heart(player) or expedition_active(): return
		var request=JSON.parse_string(action.trim_prefix("heart_confirm:"))
		if not request is Dictionary or not request.get("id") is String or not request.get("plan") is Dictionary: return
		var node:=HeartCatalog.get_node(request.id)
		if node.is_empty(): return
		var expected: Dictionary={}
		if not progress.heart.matches_plan(request.plan,expected): tell(id,"Available ingredients changed. Review the updated material preview and confirm again.");return
		tell(id,run_heart_save(progress.heart.start.bind(progress,request.id)));return
	if action.begins_with("heart_start_"):
		if id==HOST and at_heart(player) and not expedition_active():
			tell(id,run_heart_save(progress.heart.start.bind(progress,action.trim_prefix("heart_start_"))))
		else: tell(id,"The host restores Garden technologies at the Heart between expeditions.")
		return
	if action.begins_with("heart_infusion:"):
		if not at_heart(player) or player.wild: return
		var offer=JSON.parse_string(action.trim_prefix("heart_infusion:"))
		if not offer is Dictionary: return
		if offer.get("project","")!=progress.heart.active or not progress.heart.matches_plan(offer.get("plan",{}),progress.heart.material_plan(progress,progress.heart.OFFER_PARTS).parts):
			tell(id,"Research or offering materials changed. Review the updated preview and try again.");return
		tell(id,run_heart_save(progress.heart.infuse.bind(progress)));return
	if action=="heart_infuse":
		if at_heart(player) and not player.wild: tell(id,run_heart_save(progress.heart.infuse.bind(progress)))
		return
	if action.begins_with("bank_"):
		bank_checkpoint_item(id,player,action)
		return
	if (action.begins_with("class_") and action not in ["class_skill","class_skill_two"]) or action.begins_with("loadweapon_") or action.begins_with("loadpart_") or action.begins_with("pack_") or action.begins_with("learn_") or action.begins_with("respec_") or action=="clearpack":
		handle_loadout_action(id,player,action)
		return
	if action.begins_with("breed_"):
		var fields := action.split("_")
		if fields.size() == 3 and fields[1].is_valid_int() and fields[2].is_valid_int() and not player.wild and Stage.ALTAR.distance_to(player.pos) <= 1.65:
			var outcome := progress.breed(int(fields[1]), int(fields[2]), seed_reserve(player).stock)
			if not outcome.is_empty():
				save_progress(id, outcome)
			else:
				tell(id,"Need one identified seed of each parent (two for a matching pair).")
		else:
			tell(id, "Crossbreed at the Garden altar.")
		return
	if action.begins_with("look_"):
		if not player.wild and action in ["look_0", "look_1", "look_2", "look_3", "look_4"]:
			if has_meta(Transactions.SESSION) and id != HOST and not deferred_save_available(id): return
			var index := int(action.trim_prefix("look_"))
			var applied := Transactions.run_gameplay(self, Transactions.Scope.PROFILE, func():
				var look: Array = player.character.appearance
				look[index] = (int(look[index]) + 1) % LOOK_NAMES[index].size()
				if not has_meta(Transactions.SESSION): publish_character(id)
				return true, false)
			if Transactions.committed(applied.persistence): record_character(id)
		return
	match action:
		"expand_plot":
			tell(id,"Select a planting-bed node in Heart / Knowledge to begin its research.")
		"extract":
			use_checkpoint(id, false)
		"awaken":
			if at_heart(player):
				awaken_heart(id, player)
		"destination":
			if id == HOST and not player.wild and not expedition_active() and Stage.GATE.distance_to(player.pos) <= preload("res://gate_interaction.gd").RANGE:
				cycle_destination()
		"nurture", "harvest_offshoot":
			return # Retired commands cannot consume materials or reserve a bed.
		"donate":
			if player.wild:
				if id==HOST: open_deposit_menu()
				else: show_checkpoint_deposit.rpc_id(id)
				return
			if at_heart(player):
				donate_part(id, player)
		"select_donation":
			if at_heart(player):
				player.donation_choice = next_part(selected_donation(player), seed_reserve(player).parts, Parts.EMPTY, false)
		"trait":
			return # Retired class affinity; class tree choices are authoritative.
		"upgrade_power":
			choose_checkpoint_card(id, player, 0)
		"upgrade_technique":
			choose_checkpoint_card(id, player, 1)
		"upgrade_synergy":
			choose_checkpoint_card(id, player, 2)
		"graft":
			if player.wild:
				show_graft_menu(id)
			elif at_weapon_gate(player):
				cycle_slot(id, player, "prepared_secondary", player.prepared)
		"select_graft":
			if player.wild and graft_altar_open() and battlefield.graft.distance_to(player.pos) <= 1.65:
				player.graft_choice = next_monster_part(selected_graft(player), player.carried_parts)
		"frame":
			if not player.wild and not expedition_active() and Stage.HEART.distance_to(player.pos) <= 1.7:
				select_class(id,player,(int(player.frame)+1)%Classes.DEFINITIONS.size())
		"class_skill_two":
			use_class_skill(id,player,1)
		"class_skill":
			use_class_skill(id, player)
		"pouch":
			if player.wild and not player.pouch:
				tell(id,InventoryModel.transfer(self,player,"carry","pouch","unidentified_seed",1))
		"research":
			if player.wild:
				use_class_skill(id,player,1)
			elif not player.wild and not expedition_active() and Stage.HEART.distance_to(player.pos) <= 1.7:
				use_heart_research(id)
		"catalyst":
			if at_weapon_gate(player):
				cycle_slot(id,player,"prepared_catalyst",0)
		"craft":
			if not player.wild and nearby_plot(player.pos) >= 0:
				var slot:=nearby_plot(player.pos)
				if progress.plots[slot].species<0: show_planting_picker(id,slot)
			elif at_weapon_gate(player):
				cycle_slot(id, player, "prepared", player.prepared_secondary)
			elif not player.wild and Stage.ALTAR.distance_to(player.pos) <= 1.65:
				for step in range(1, Progress.ALTAR_PAIRS.size() + 1):
					var next := (int(player.experiment) + step) % Progress.ALTAR_PAIRS.size()
					var pair: Array = Progress.ALTAR_PAIRS[next]
					if progress.discoveries[int(pair[0])] and progress.discoveries[int(pair[1])]:
						player.experiment = next
						break
		"experiment":
			if not player.wild and Stage.ALTAR.distance_to(player.pos) <= 1.65:
				var outcome := progress.experiment(player.experiment, seed_reserve(player).stock)
				if outcome.is_empty():
					tell(id, "Not enough identified seeds for this experiment.")
				else:
					save_progress(id, outcome)
		"flower":
			var slot := nearby_plot(player.pos)
			if slot>=0:preload("res://garden_crop_service.gd").harvest_seeds(self,id,slot)


func awaken_heart(id: int, player: Dictionary) -> void:
	if not Campaign.LEGACY_ENDING_ENABLED: return
	if not expedition_active() and destination==Campaign.HEART and travel_kind=="depart":
		enter_wilds(id,player);return
	if expedition_active():
		if destination == Campaign.HEART:
			enter_wilds(id, player)
		return
	if id != HOST:
		tell(id, "The host can begin the finale when the Heart is ready.")
		return
	if not progress.finale_available():
		tell(id, "The Heart's restoration is incomplete. Check Inventory for progress.")
		return
	var previous := destination
	destination = Campaign.HEART
	enter_wilds(id, player)
	if not player.wild and travel_kind!="depart":
		destination = previous


func cycle_destination() -> void:
	for offset in range(1, Campaign.HEART + 1):
		var site := (destination + offset) % Campaign.HEART
		if progress.campaign.available(site):
			destination = site
			break
	for id in players:
		tell(id, "Selected %s. Entry costs %d shared plant parts." % [
			Campaign.NAMES[destination], Campaign.SHORTCUT_COST[destination]])


func route_rooms() -> int:
	return 1 if destination == Campaign.HEART else ROUTE_ROOMS


func enemy_name() -> String:
	if boss_kind>=0: return Enemies.get_kind(boss_kind).name
	if destination != Campaign.HEART:
		return ("Longlimb " if longlimb else "Elite ")+Enemies.get_kind(enemy_kind).name+" · "+preload("res://elite_enemy.gd").empowered(enemy_kind)
	if longlimb:
		return "Longlimb " + Enemies.get_kind(enemy_kind).name
	return "Awakened Heart" if destination == Campaign.HEART else Enemies.get_kind(enemy_kind).name


func campaign_snapshot() -> PackedInt32Array:
	var flags := 0
	for i in progress.campaign.cleared.size():
		if progress.campaign.cleared[i]:
			flags |= 1 << i
	var result := PackedInt32Array([destination, flags, Campaign.DORMANT if not Campaign.LEGACY_ENDING_ENABLED else progress.campaign.offshoots[0],
		Campaign.DORMANT if not Campaign.LEGACY_ENDING_ENABLED else progress.campaign.offshoots[1], Campaign.DORMANT if not Campaign.LEGACY_ENDING_ENABLED else progress.campaign.offshoots[2], Campaign.UNFINISHED if not Campaign.LEGACY_ENDING_ENABLED else progress.campaign.ending,
		roundi(active_radius * 100.0), 0, map_seed, encounter_number,
		difficulty_cycle, maxi(0, ceili((pressure_at - Time.get_ticks_msec()) / 1000.0)),
		progress.campaign.best_clear, progress.campaign.best_extraction,
		progress.campaign.memories[0], progress.campaign.memories[1], progress.campaign.memories[2],
		int(progress.finale_available()), Enemies.encode(enemy_kind, enemy_mutations, enemy_growth)])
	for i in EncounterConfig.MAX_SCOUTS:
		var scout: Dictionary = scouts[i] if i < scouts.size() else {}
		result.append(Enemies.encode(int(scout.get("kind", 0)), int(scout.get("mutations", 0)), int(scout.get("growth", 0))))
	result.append(roundi(enemy_landing.x * 100.0))
	result.append(roundi(enemy_landing.z * 100.0))
	result.append(int(enemy_attack_mode == "vault"))
	result.append(boss_kind)
	result.append(boss_phase)
	return result


func at_heart(player: Dictionary) -> bool:
	return not player.is_empty() and not player.get("wild",false) and Stage.HEART.distance_to(player.get("pos",Vector3.INF)) <= 1.7


func selected_donation(player: Dictionary) -> int:
	var parts: Array = seed_reserve(player).parts
	var choice: int = player.donation_choice
	return choice if choice != Parts.EMPTY and parts[choice] > 0 else next_part(Parts.EMPTY, parts, Parts.EMPTY)


func donate_part(id: int, player: Dictionary) -> void:
	if not deferred_save_available(id): return
	var part := selected_donation(player)
	if part == Parts.EMPTY:
		tell(id, "Extract with a weapon part to donate it.")
		return
	seed_reserve(player).parts[part] -= 1
	progress.add_parts(part, 1)
	save_progress(id, "Donated %s to the shared Garden." % Parts.part_name(part))


func award_combat_progress() -> void:
	MonsterRewards.flush(self)

func run_wallet(player: Dictionary) -> int:
	return maxi(0,deepest_milestone*ROOM_CURRENCY+int(player.get("essence_sparks",0))/int(Director.config().essence_sparks_per_point)-int(player.get("spent",0)))


func record_character(id: int) -> void:
	var owner: String=local_character.identity if id==HOST else players[id].get("seed_owner","")
	progress.character_records[owner]={"profile":players[id].character.duplicate(true),"manifest":progress.ContentIDs.manifest()}

func publish_character(id: int) -> void:
	if has_meta(Transactions.SESSION): return
	record_character(id)
	if SaveBatch.active:
		if not transaction_publishes.has(id): transaction_publishes.append(id)
		if id==HOST: local_character.data=players[id].character;local_character.save_profile()
		return
	if id == HOST:
		character_dirty = true
		save_local_character()
	else:
		receive_character.rpc_id(id, players[id].character)


@rpc("authority", "call_remote", "reliable")
func receive_character(profile: Dictionary) -> void:
	if session != "Guest" or not Transactions.session_writable(self): return
	if has_meta(Transactions.SESSION):
		# Only the guest's local write participates in this transaction.
		var saved := Transactions.run_gameplay(self, Transactions.Scope.GUEST_PROFILE, func():
			guest_character.data = Character.normalize(profile)
			return true)
		if Transactions.committed(saved.persistence): character_dirty = false
		return
	guest_character.data = Character.normalize(profile)
	character_dirty = true
	save_local_character()


func save_local_character() -> bool:
	var active := guest_character if session == "Guest" else local_character
	if has_meta(Transactions.SESSION):
		var scope := Transactions.Scope.GUEST_PROFILE if session == "Guest" else Transactions.Scope.PROFILE
		var saved := Transactions.run_gameplay(self, scope, func(): return true)
		if Transactions.committed(saved.persistence): character_dirty = false
		return saved.completed
	if active.save_profile() == OK:
		character_dirty = false
		return true
	status = "Character progress could not be saved."
	return false


func graft_chance(player: Dictionary, part: int) -> float:
	var profile: Dictionary = player.get("character", guest_character.data)
	var familiarity: int = profile.monsters[int(Parts.DEFINITIONS[part].monster)] if Parts.is_monster(part) else profile.plants[Parts.plant_source(part)]
	return minf(0.95, GRAFT_CHANCE + minf(.25,mini(5,familiarity)*.04+maxi(0,familiarity-5)*.002) + (0.05 if heart_state().get("unlocked",[]).has("monster_studies") else 0.0) + float(weapon_stats(player).get("graft_chance",0)))


func use_class_skill(id: int, player: Dictionary, slot: int=0) -> void:
	Journal.event("combat","skill_requested",{"actor":id,"slot":slot,"state":Journal.player_state(player)})
	if slot<0 or slot>1: return
	var now:=Time.get_ticks_msec()
	var timer: String="skill_at" if slot==0 else "skill_two_at"
	if not Life.alive(player) or encounter_cleared() or now<int(player.get(timer,0)) or now<int(player.get("core_cast_until",0)): return
	var skill:=Skills.resolve(int(player.frame),slot,player.character)
	var stats:=weapon_stats(player)
	skill=Traits.tune_skill(skill,stats)
	if skill.mode=="subclass":
		preload("res://subclass_combat.gd").cast_skill(self,id,player,skill,stats,now)
		return
	var duration:=int(stats.get("skill_duration",0))
	var bonus_heal:=Skills.Balance.healing_bonus(stats)
	var range_limit:=float(skill.get("range",stats.reach))+maxf(0.0,float(stats.reach)-float(Classes.DEFINITIONS[int(player.frame)].weapons[int(player.weapon_kind)].reach))
	var radius:=float(skill.get("radius",0))
	var target: int=-2
	var point: Vector3=player.pos
	var targets: Array[int]=[]
	var cast_origin: Vector3=player.pos
	var effect_point: Vector3=player.pos
	var mode:=str(skill.mode)
	var aimed: bool=player.has("class_aim")
	var plan: Dictionary={}
	if aimed:
		plan=preload("res://class_ability_targeting.gd").plan(self,player,battlefield,skill,stats,player.class_aim,float(player.get("class_aim_distance",-1)))
		if not plan.valid:
			tell(id,"Cultivate a bloom before detonating it." if mode=="bloom_detonate" else "%s: no enemy within clear range."%skill.name)
			return
		target=plan.target
		point=plan.point
		range_limit=plan.reach
		player.facing=plan.forward
		player.aim_direction=plan.forward
	else:
		target=select_attack_target(player,range_limit+float(skill.get("travel",0)))
		if target!=-2: point=enemy_position(target)
	if not aimed and mode in ["bind","strangle","siphon","salvo","judgement","reap","harvest","requiem"]:
		var extra_travel:=float(skill.get("travel",0)) if not skill.has("range") else 0.0
		if target==-2 or player.pos.distance_to(point)>range_limit+extra_travel:
			tell(id,"%s: no enemy within clear range."%skill.name)
			return
	match mode:
		"growth":
			effect_point=point if target!=-2 and player.pos.distance_to(point)<=range_limit else player.pos
		"bloom_detonate":
			if not Traits.has_growth(self,player): tell(id,"Cultivate a bloom before detonating it.");return
			targets=Traits.detonation_targets(self,player,radius)
		"requiem":
			effect_point=point
			Traits.defer_skill(self,player,skill_area_targets(point,radius,player.pos),skill,stats,now)
		"front_guard", "counter_guard":
			grant_guard(player,now+int(skill.duration)+duration,int(skill.charges))
			if mode=="front_guard":
				player.front_guard_until=now+int(skill.duration)+duration;player.guard_face=player.facing.normalized()
				for ally in players.values():
					var offset: Vector3=ally.pos-player.pos
					if not is_same(ally,player) and Life.alive(ally) and offset.length()<=radius and (offset.length_squared()<.01 or offset.normalized().dot(player.guard_face)>=.15) and battlefield.clear_line(player.pos,ally.pos):
						grant_guard(ally,now+int(skill.duration)+duration,1)
			else: player.counter_guard_until=now+int(skill.duration)+duration
		"guard":
			grant_guard(player,now+int(skill.duration)+duration,int(skill.charges))
		"bastion","ward":
			for ally in players.values():
				if Life.alive(ally) and ally.pos.distance_to(player.pos)<=radius and battlefield.clear_line(player.pos,ally.pos):
					grant_guard(ally,now+int(skill.duration)+duration,int(skill.charges))
		"bind","strangle":
			targets.assign([target])
			effect_point=point
		"snare","snare_field":
			effect_point=plan.center if aimed else battlefield.dash(player.pos,point if target!=-2 else player.pos+Vector3(player.facing)*range_limit)
			Traits.place_snare(self,player,effect_point,skill,stats,now)
		"volley","reap":
			if target==-2 or player.pos.distance_to(point)>float(stats.reach)+(float(skill.get("travel",3)) if mode=="reap" else 0.0):
				tell(id,"No enemy within skill range.")
				return
			if mode=="volley": player.focus_until=now+int(skill.duration)+duration
			else:
				grant_guard(player,now+int(skill.duration)+duration,1)
				player.pos=plan.center if aimed else battlefield.dash(player.pos,player.pos.move_toward(point,minf(float(skill.travel),maxf(0,player.pos.distance_to(point)-.6))))
			player.skill_burst=true
			player.skill_burst_damage=Skills.Balance.burst_points(skill)
			player.skill_burst_targets=2+int(skill.mastered)
			player.strike_at=0
			strike_enemy(id,player,player.pos)
			player.skill_burst=false
			effect_point=player.pos
		"windstep":
			var facing: Vector3=player.get("facing",Vector3.FORWARD)
			if facing.length_squared()<.01: facing=Vector3.FORWARD
			player.pos=plan.center if aimed else battlefield.dash(player.pos,player.pos-facing.normalized()*float(skill.travel))
			player.focus_until=now+int(skill.duration)+duration
			effect_point=player.pos
		"charge","harvest":
			var facing: Vector3=(point-player.pos).normalized() if target!=-2 else player.facing
			var distance:=float(skill.travel)
			if target!=-2: distance=minf(distance,maxf(0,player.pos.distance_to(point)-.6))
			player.pos=plan.center if aimed else battlefield.dash(player.pos,player.pos+facing*distance)
			effect_point=player.pos
			if mode=="harvest": grant_guard(player,now+int(skill.duration)+duration,1)
			targets=skill_area_targets(player.pos,radius,player.pos)
		"quake","nova","bloodmoon":
			if mode=="quake" and skill.get("warden_focus","")=="rootkeeper":
				effect_point=plan.center if aimed else preload("res://warden_combat.gd").quake_center(self,player,battlefield,skill,now)
				skill.effect_origin=effect_point
			targets=skill_area_targets(effect_point,radius,effect_point)
		"judgement":
			effect_point=point
			targets=skill_area_targets(point,radius,player.pos)
		"salvo":
			var aim: Vector3=point-player.pos
			player.facing=aim.normalized() if aim.length_squared()>.001 else player.get("facing",Vector3.FORWARD)
			if player.facing.length_squared()<.001: player.facing=Vector3.FORWARD
			targets=skill_line_targets(player.pos,player.facing,range_limit,float(skill.width),int(skill.targets))
			effect_point=point
		"siphon":
			targets.assign([target])
			effect_point=point
		"heal","sanctuary":
			var heal_hp:=Life.Preview.roll_heal(Skills.Balance.direct_heal(skill,stats))
			for ally in players.values():
				if Life.alive(ally) and ally.pos.distance_to(player.pos)<=radius and battlefield.clear_line(player.pos,ally.pos):
					Life.Sustain.restore(self,ally,heal_hp,mode)
					Life.Sustain.begin_renewal(ally,now,int(skill.duration)+duration,Skills.Balance.RENEWAL_INTERVAL_MS)
					if mode=="sanctuary": grant_guard(ally,now+int(skill.ward_duration)+duration,int(skill.charges))
			bonus_heal=0
	targets=Traits.spread_targets(self,player,targets,skill,stats)
	if not targets.is_empty(): player.swing_until=now+240
	var hits:=apply_skill_targets(player,targets,skill,stats,now)
	if skill.has("warden_focus") and slot==0:
		preload("res://warden_combat.gd").on_cast(self,player,skill,now+int(skill.duration)+duration,now)
	if mode=="quake":
		preload("res://core_combat.gd").quake(self,id,effect_point,radius,now)
		if skill.has("warden_focus"):
			var warden=preload("res://warden_combat.gd")
			warden.consume_anchor(self,player,effect_point,now)
			warden.quake_hit(self,player,effect_point,targets,radius,now)
	if mode in ["siphon","bloodmoon"] and hits>0:
		Life.Sustain.heal(self,player,Skills.Balance.drain_amount(skill,hits),mode,Life.Preview.HEAL_DRAIN_SPREAD_HP)
	Traits.skill_cast(self,player,skill,stats,effect_point,now)
	player.contributed=true
	if bonus_heal>0: Life.Sustain.heal(self,player,bonus_heal,"class_healing_bonus")
	player[timer]=now+Skills.Balance.cooldown(skill,stats)
	if slot==1 and skill.has("subclass_focus"):
		preload("res://subclass_combat.gd").follow_through(self,player,skill,effect_point,targets,now)
	player.skill_fx_seq=int(player.get("skill_fx_seq",0))+1
	player.skill_fx_until=now+650
	player.skill_fx={"seq":player.skill_fx_seq,"pos":effect_point,"radius":maxf(.8,radius),"color":skill.color,"event_driven":true}
	player.cast_until=now+550
	emit_combat_event("ability",mode,cast_origin,effect_point,.8,Color(skill.color),maxf(.8,radius),id)
	preload("res://event_audio.gd").emit(self,"combat_cast",cast_origin)
	tell(id,"%s used."%skill.name)
	if encounter_cleared(): finish_combat(id,enemy_position(targets.back()) if not targets.is_empty() else effect_point)

func grant_guard(player: Dictionary,until: int,charges: int) -> void:
	if charges > 1 or until > int(player.get("guard_until",0)): player.erase("ironbark_ward")
	var old_charges:=int(player.get("guard_charges",0)) if int(player.get("guard_until",0))>Time.get_ticks_msec() else 0
	player.guard_until=maxi(int(player.get("guard_until",0)),until)
	player.guard_charges=maxi(old_charges,Skills.Balance.guard_charges(charges))

func skill_area_targets(center: Vector3,radius: float,origin: Vector3) -> Array[int]:
	var result: Array[int]=[]
	for target in range(-1,scouts.size()):
		if (enemy_hp if target==-1 else int(scouts[target].hp))<=0: continue
		var point:=enemy_position(target)
		if center.distance_to(point)<=radius and battlefield.clear_line(origin,point) and battlefield.clear_line(center,point): result.append(target)
	return result

func skill_line_targets(origin: Vector3,facing: Vector3,distance: float,width: float,limit: int) -> Array[int]:
	var result: Array[int]=[]
	var ordered: Array=[]
	for target in range(-1,scouts.size()):
		if (enemy_hp if target==-1 else int(scouts[target].hp))<=0: continue
		var offset:=enemy_position(target)-origin
		var along:=offset.dot(facing)
		if along>=0 and along<=distance and (offset-facing*along).length()<=width and battlefield.clear_line(origin,enemy_position(target)):
			ordered.append({"id":target,"distance":along})
	ordered.sort_custom(func(a,b): return a.distance<b.distance)
	for item in ordered:
		if result.size()>=limit: break
		result.append(int(item.id))
	return result

func apply_skill_targets(player: Dictionary,targets: Array[int],skill: Dictionary,stats: Dictionary,now: int) -> int:
	var before_primary:=enemy_hp
	var drain_contacts:=0
	for target in targets:
		var root_time:=Skills.Balance.bind_ms(skill,stats)
		if root_time>0:
			var until:=now+root_time
			if target==-1: rooted_until=maxi(rooted_until,until)
			else: scouts[target].rooted_until=maxi(int(scouts[target].get("rooted_until",0)),until)
		var recovery:=int(skill.get("recovery",0))
		if recovery>0:
			if target==-1: moss_recovery_bonus=maxi(moss_recovery_bonus,recovery)
			else: scouts[target].recovery=maxi(int(scouts[target].get("recovery",0)),recovery)
		var damage:=Life.Preview.authored_amount(float(skill.get("damage",0)))
		if damage>0.0:
			var hit: Dictionary=stats.duplicate(true)
			hit.damage=damage
			hit.audio_form="magic"
			hit.stagger=int(stats.get("stagger",0))+int(skill.get("stagger",0))
			hit.recovery=int(stats.get("recovery",0))+recovery
			hit.knockback=float(skill.get("push",0))-.35
			var before:=enemy_hp if target==-1 else int(scouts[target].hp)
			apply_weapon_hit(player,target,skill.get("effect_origin",player.pos),hit,now)
			if Life.Preview.enabled and Life.Sustain.eligible(self,target):
				var after:=enemy_hp if target==-1 else int(scouts[target].hp)
				drain_contacts+=int(after<before)
	if destination==Campaign.HEART and before_primary>Campaign.FINAL_HP/2.0 and enemy_hp>0 and enemy_hp<=Campaign.FINAL_HP/2.0:
		for peer_id in players: tell(peer_id,"The Heart remembers: I sheltered them, too. I will not let it happen again.")
	return drain_contacts if Life.Preview.enabled else targets.size()


func graft_altar_open() -> bool:
	return destination != Campaign.HEART and encounter_number % GRAFT_ROOM == 0


func at_graft_altar(player: Dictionary) -> bool:
	var location: Vector3=battlefield.graft if multiplayer.is_server() else stage.visual_field.graft
	return not player.is_empty() and player.get("wild",false) and graft_altar_open() and location.distance_to(player.get("pos",Vector3.INF))<=1.65

func graft_block_reason(player: Dictionary,part: int) -> String:
	if not at_graft_altar(player): return "Move next to a grafting altar in the Wilds."
	if not Parts.is_monster(part): return "Select a carried monster part."
	if int(player.get("carried_parts",Parts.empty_counts())[part])<=0: return "No carried component of this type remains."
	var installed:=int(player.get("graft_part",0))
	if installed==part: return "This component is already installed."
	if installed!=0 and encounter_number<=int(player.get("graft_floor",0)): return "Replacement requires an altar on a later encounter."
	return ""

func attempt_graft(id: int, player: Dictionary,requested: int=-1) -> void:
	Transactions.run(self,func(): _attempt_graft(id,player,requested))

func _attempt_graft(id: int, player: Dictionary,requested: int=-1) -> void:
	var part: int=selected_graft(player) if requested==-1 else requested
	var reason:=graft_block_reason(player,part)
	if not reason.is_empty():
		graft_feedback(id,player,reason)
		return
	var previous:=int(player.get("graft_part",0))
	player.graft_choice=part
	player.carried_parts[part]-=1
	var graft_roll:=rng.randf()
	var probability:=graft_chance(player,part)
	Journal.event("grafting","roll",{"actor":id,"part":part,"previous_part":previous,"probability":probability,"roll":graft_roll,"success":graft_roll<probability})
	if graft_roll<probability:
		player.graft_part=part
		player.graft_floor=encounter_number
		if Life.Preview.enabled:
			player.max_hp=Life.maximum(self,player)
			player.hp=minf(float(player.hp),float(player.max_hp))
		progress.record_monster_graft(part)
		var message: String="%s grafted into the fourth slot."%Parts.part_name(part)
		if previous!=0: message="%s replaced %s. The old component was sacrificed."%[Parts.part_name(part),Parts.part_name(previous)]
		var saved:=progress.save_garden()
		if saved!=OK:
			message+=" Save failed. Use Save Garden to retry."
			if id!=HOST: status="Garden save failed. Use Save Garden to retry."
		graft_feedback(id,player,message)
	else:
		graft_feedback(id,player,"The graft failed and consumed %s.%s"%[Parts.part_name(part)," The installed component remains intact." if previous!=0 else ""])


func selected_graft(player: Dictionary) -> int:
	var choice: int=player.graft_choice
	if Parts.is_monster(choice) and player.carried_parts[choice]>0:
		return choice
	return next_monster_part(0,player.carried_parts)

func next_monster_part(current: int,counts: Array) -> int:
	for offset in range(1,Parts.DEFINITIONS.size()):
		var part: int=(current+offset)%Parts.DEFINITIONS.size()
		if Parts.is_monster(part) and part<counts.size() and counts[part]>0:
			return part
	return 0


func next_part(current: int, counts: Array, excluded: int, allow_empty: bool = true) -> int:
	for offset in range(1, Parts.DEFINITIONS.size()):
		var candidate := (current + offset) % Parts.DEFINITIONS.size()
		if candidate == Parts.EMPTY:
			if allow_empty:
				return candidate
		elif candidate != excluded and counts[candidate] > 0:
			return candidate
	return Parts.EMPTY


func cycle_slot(id: int, player: Dictionary, slot: String, _excluded: int) -> void:
	if not deferred_save_available(id): return
	if not at_weapon_gate(player): return
	for offset in range(1,Parts.DEFINITIONS.size()+1):
		var candidate: int=(int(player[slot])+offset)%Parts.DEFINITIONS.size()
		if candidate==0 or (Parts.is_plant(candidate) and LoadoutMaterials.remaining(stored_counts(player),LoadoutMaterials.choices(player),LoadoutMaterials.FIELDS.find(slot),candidate)>0):
			player[slot]=candidate
			persist_loadout(id,player)
			tell(id,"%s: %s" % [slot.trim_prefix("prepared").replace("_"," ").strip_edges(),Parts.part_name(candidate)])
			return


func available_parts(player: Dictionary, part: int) -> int:
	return int(seed_reserve(player).parts[part]) + progress.part_count(part)


func upgrade_checkpoint_open() -> bool:
	return destination != Campaign.HEART and encounter_number % CHECKPOINT_INTERVAL == 0 and encounter_cleared()


func extraction_checkpoint_open() -> bool:
	return destination != Campaign.HEART and encounter_number % EXTRACTION_INTERVAL == 0 and encounter_cleared()


func checkpoint_offer_ids(player: Dictionary) -> Array:
	if not player.get("wild",false) or not upgrade_checkpoint_open(): return []
	if int(player.get("offer_floor",0))!=encounter_number:
		var wallet: int=run_wallet(player)
		player.checkpoint_offers=RunUpgrades.roll(player,encounter_number,int(player.get("upgrade_seed",1)),wallet)
		player.offer_floor=encounter_number
	return player.get("checkpoint_offers",[])

func buy_upgrade(id: int,player: Dictionary,choice: int) -> bool:
	return bool(Transactions.run(self,func(): return _buy_upgrade(id,player,choice)))

func _buy_upgrade(id: int,player: Dictionary,choice: int) -> bool:
	if not player.wild or not upgrade_checkpoint_open() or battlefield.advance.distance_to(player.pos)>preload("res://gate_interaction.gd").RANGE or int(player.last_offer)==encounter_number: return false
	var offers:=checkpoint_offer_ids(player)
	if choice<0 or choice>=offers.size(): return false
	var entry:=RunUpgrades.get_upgrade(str(offers[choice]))
	var reason:=RunUpgrades.requirement(entry,player)
	if not reason.is_empty(): tell(id,reason);return false
	if run_wallet(player)<int(entry.cost): tell(id,"Not enough essence for that upgrade.");return false
	var before_health:=int(player.get("max_hp",MAX_HEALTH))
	if not player.has("run_upgrades"): player.run_upgrades={}
	player.run_upgrades[entry.id]=int(player.run_upgrades.get(entry.id,0))+1
	player.spent+=int(entry.cost)
	preload("res://game_metrics.gd").record("upgrade",{"id":entry.id,"floor":encounter_number,"cost":int(entry.cost)})
	player.last_offer=encounter_number
	player.power+=int(entry.effects.get("power",0))
	player.technique+=int(entry.effects.get("technique",0))
	if entry.effects.has("rift_hook"): player.rift_hook=true
	player.max_hp=Life.maximum(self,player)
	Life.Vitals.heal(player,maxi(0,int(player.max_hp)-before_health))
	var message: String="%s · Rank %d gained for this expedition."%[entry.name,int(player.run_upgrades[entry.id])]
	if entry.id=="rift_hook" and not progress.rift_hook_discovered:
		progress.discover_rift_hook();save_progress(id,message+" The Heart remembers this link.")
	else: tell(id,message)
	return true


func guarded_growth_tick(elapsed: float) -> void:
	if not Transactions.session_writable(self): return
	var original: Array = progress.plots.duplicate(true)
	if not progress.advance_growth(elapsed,expedition_active()): return
	var updated: Array = progress.plots.duplicate(true)
	progress.plots.assign(original)
	progress.sync_plot_flags()
	Transactions.run_gameplay(self, Transactions.Scope.GARDEN, func():
		progress.plots.assign(updated)
		progress.sync_plot_flags())

func run_heart_save(action: Callable) -> String:
	var result := Transactions.run_gameplay(self, Transactions.Scope.GARDEN, action, false)
	return Transactions.feedback(result, "Research could not be saved.")

func use_heart_research(id: int) -> void:
	if id!=HOST:
		tell(id,"The host chooses the Garden's research.")
		return
	if progress.heart.active.is_empty():
		if not progress.flowering_unlocked: tell(id,run_heart_save(progress.heart.start.bind(progress,"flowering")))
		else: show_heart_tree(id)
	else:
		tell(id,run_heart_save(progress.heart.infuse.bind(progress)))

func infuse_study(id: int) -> void:
	if id==HOST: tell(id,run_heart_save(progress.heart.infuse.bind(progress)))


@rpc("any_peer", "call_remote", "reliable")
func request_action(strike: bool) -> void:
	if multiplayer.is_server() and allow_remote(multiplayer.get_remote_sender_id(),"action",30):
		act(multiplayer.get_remote_sender_id(), strike)


@rpc("any_peer", "call_remote", "reliable")
func request_dodge(direction: Vector2) -> void:
	if multiplayer.is_server() and direction.is_finite() and allow_remote(multiplayer.get_remote_sender_id(),"action",30):
		dodge_player(multiplayer.get_remote_sender_id(), direction.limit_length())


@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_motion(direction: Vector2) -> void:
	var id := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and direction.is_finite() and allow_remote(id,"motion",120):
		motions[id] = [direction.limit_length(), Time.get_ticks_msec()]


@rpc("any_peer", "call_remote", "unreliable_ordered",3)
func submit_movement(commands: Array,epoch: String) -> void:
	var id:=multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not players.has(id) or not players[id].get("profile_ready",false) or not allow_remote(id,"motion",120):return
	net_motion.accept(id,commands,epoch,net_motion.world_key(self,players[id]),Time.get_ticks_msec())


func _physics_process(delta: float) -> void:
	if has_meta(Transactions.SESSION) and (returning_to_title or get_meta(Transactions.PENDING, false)):
		return
	if multiplayer.is_server():net_motion.frame(delta,players)
	mouse_controls.frame(self)
	var direction := Vector2.ZERO if overlay.visible or get_meta("garden_cinematic_active",false) else Input.get_vector("left", "right", "up", "down")
	if multiplayer.is_server():
		var now := Time.get_ticks_msec()
		growth_clock += delta
		if growth_clock >= 1.0:
			var elapsed := growth_clock
			growth_clock = 0.0
			if has_meta(Transactions.SESSION):
				guarded_growth_tick(elapsed)
				if Transactions.session_writable(self) and not progress.heart.active.is_empty():
					var message := run_heart_save(progress.heart.tick.bind(progress,elapsed,expedition_active()))
					if not message.is_empty(): status = message
			else:
				if progress.advance_growth(elapsed,expedition_active()) and progress.save_garden() != OK:
					status = "Plant growth could not be saved. Use Save Garden to retry."
				var research_message:=progress.heart.tick(progress,elapsed,expedition_active())
				if not research_message.is_empty(): status=research_message
		motions[HOST] = [direction, now]
		for id in players:
			players[id].velocity=Vector3.ZERO
			if id!=HOST and net_motion.servers.has(id):
				net_motion.server_tick(self,id,delta,now)
			elif motions.has(id) and now - int(motions[id][1]) < 250:
				move_player(id, motions[id][0], delta)
		mouse_controls.tick(self,now)
		if expedition_active() and encounter_cleared() and not encounter_rewarded and now>=reward_retry_at: finish_combat(HOST,enemy_pos)
		update_projectiles(now)
		Traits.tick(self,now)
		preload("res://combat_status.gd").sync(self,now)
		attract_loot(delta)
		Bosses.tick_hazards(self,now)
		if expedition_active() and encounter_cleared() and pending_finale_at==0 and not encounter_rewarded and now>=reward_retry_at: finish_combat(HOST,enemy_pos)
		if now>=next_kill_reward_flush:
			next_kill_reward_flush=now+150
			MonsterRewards.flush(self)
		update_support_effects(now)
		update_combat_tracking(delta)
		update_enemy(delta, now)
		update_scouts(delta, now)
		preload("res://core_combat.gd").tick(self,now)
		update_pressure(now)
		if pending_finale_at>0 and now>=pending_finale_at:
			pending_finale_at=0
			complete_finale(pending_finale_peer)
		net_view.observe(self)
		if online_peer != null:
			next_details-=delta
			next_snapshot -= delta
			if next_snapshot <= 0.0:
				next_snapshot = maxf(0,next_snapshot+0.05)
				net_view.snapshot_sent+=1
				for peer_id in multiplayer.get_peers():
					if not players.has(peer_id) or not players[peer_id].profile_ready:
						continue
					var guest: Dictionary = players[peer_id]
					receive_state.rpc_id(peer_id, var_to_bytes(player_snapshot(peer_id,false)).compress(FileAccess.COMPRESSION_DEFLATE), enemy_pos, enemy_hp, enemy_winding_up,
						drop_pos, guest.loot_pending, [], depth, guest.carried_seeds.size(),
						guest.pouch, PackedByteArray(), now < rooted_until, longlimb, campaign_snapshot(), scout_snapshot(now).to_byte_array().compress(FileAccess.COMPRESSION_DEFLATE),net_view.snapshot_sent)
			if next_details<=0:
				next_details=maxf(0,next_details+.25)
				var garden_bytes:=var_to_bytes(garden_snapshot()).compress(FileAccess.COMPRESSION_DEFLATE)
				for peer_id in multiplayer.get_peers():
					if not players.has(peer_id) or not players[peer_id].profile_ready: continue
					var details: Dictionary=player_snapshot(peer_id)[peer_id]
					for key in player_snapshot(peer_id,false)[peer_id]: details.erase(key)
					receive_details.rpc_id(peer_id,var_to_bytes(details).compress(FileAccess.COMPRESSION_DEFLATE),garden_bytes,inventory_snapshot(players[peer_id]),str([destination,encounter_number,map_seed]))
	elif session == "Guest":
		var commands: Array=net_motion.client_tick(self,multiplayer.get_unique_id(),direction,delta)
		if not commands.is_empty():submit_movement.rpc_id(HOST,commands,net_motion.epoch)


func move_player(id: int, direction: Vector2, delta: float) -> void:
	var p: Dictionary = players[id]
	if p.get("wild",false) and not Life.alive(p): p.velocity=Vector3.ZERO;return
	var move := world_direction(direction)
	if not move.is_zero_approx() and (not p.wild or not p.get("mouse_aim",false)):
		p.facing = move.normalized()
	var guard_speed: float=.4 if Time.get_ticks_msec()<int(p.get("front_guard_until",0)) else 1.0
	var desired := bound_position(p.pos + move * WALK_SPEED * guard_speed * (0.6 if Time.get_ticks_msec() < int(p.get("slow_until", 0)) else 1.0) * delta, p.wild)
	var previous: Vector3=p.pos
	p.pos = battlefield.slide(p.pos, desired) if p.wild else desired
	p.velocity=(p.pos-previous)/maxf(delta,.001)


func world_direction(direction: Vector2) -> Vector3:
	return Vector3(direction.x, 0, direction.y).rotated(Vector3.UP, atan2(3.3, 14.0))


func bound_position(position_next: Vector3, wild: bool = false) -> Vector3:
	if not wild:
		var technologies := int(progress.flowering_unlocked) + int(progress.veilcap_discovered) + int(progress.rift_hook_discovered) + progress.heart.clearing_bonus()
		var radius := Stage.garden_radius(progress.knowledge, technologies) - 0.4
		var flat := Vector2(position_next.x, position_next.z).limit_length(radius)
		return Vector3(flat.x, 0, flat.y)
	var bounds := Stage.WILD_BOUNDS
	if battlefield.procedural:
		# The generated clearing can extend beyond the old +/-23 arena.
		return Vector3(clampf(position_next.x,Battlefield.REGION.position.x+0.5,Battlefield.REGION.end.x-0.5),0,clampf(position_next.z,Battlefield.REGION.position.y+0.5,Battlefield.REGION.end.y-0.5))
	position_next.x = clampf(position_next.x, -bounds.x, bounds.x)
	position_next.z = clampf(position_next.z, -bounds.y, bounds.y)
	return position_next


func dodge_player(id: int, direction: Vector2) -> void:
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	var now := Time.get_ticks_msec()
	if not Life.alive(p) or now < int(p.dodge_at):
		return
	var facing := world_direction(direction).normalized()
	if not facing.is_zero_approx():
		p.facing = facing
	p.pos = battlefield.dash(p.pos, bound_position(p.pos + p.facing * DODGE_DISTANCE, true))
	p.dodge_at = now + maxi(350,DODGE_COOLDOWN_MS-int(weapon_stats(p).get("dodge_cooldown",0)))


func update_enemy(delta: float, now: int) -> void:
	if boss_kind>=0:
		Bosses.tick(self,delta,now)
		return
	if enemy_hp <= 0:
		return
	if destination!=Campaign.HEART:
		preload("res://elite_enemy.gd").tick(self,delta,now)
		return
	if enemy_winding_up:
		if now >= enemy_strike_at:
			resolve_briar_strike(now)
		return
	if now < enemy_stagger_until:
		return
	var target := Director.target(self,enemy_pos,leader_brain,now)
	if target == 0:
		return
	var victim: Dictionary = players[target]
	var distance := enemy_pos.distance_to(victim.pos)
	if not enemy_engaged and (distance>float(Director.config().aggro_radius) or not battlefield.clear_line(enemy_pos,victim.pos)):
		return
	if not leader_brain.get("alerted",false): Director.alert(self,enemy_pos);leader_brain.alerted=true
	enemy_engaged = true
	if enemy_mutations & Enemies.MOBILITY and now >= enemy_ready_at and now >= rooted_until:
		var landing := enemy_pos.move_toward(victim.pos, minf(3.0, distance))
		if distance > 1.5 and can_vault(enemy_pos, landing):
			enemy_attack_mode = "vault"
			enemy_landing = landing
			enemy_winding_up = true
			active_radius = base_strike_radius()
			enemy_strike_at = now + 1000
			preload("res://event_audio.gd").enemy(self,{"mode":"vault","from":enemy_pos},false)
			return
	if distance > base_strike_radius() - 0.45 or not battlefield.clear_line(enemy_pos, victim.pos):
		if now >= rooted_until:
			var speed: float = minf(float(Enemies.get_kind(enemy_kind).speed) + (depth - 1) * 0.30, 2.9) + [0.0, -0.15, 0.25, 0.35][destination] + minf(difficulty_cycle * 0.12, 0.72)
			if now<enemy_haste_until: speed*=1.22
			enemy_pos = Director.navigate(self,enemy_pos, Director.pursuit(self,target,0), Director.speed(self,speed + 0.55 if longlimb else speed) * (1.18 if enemy_mutations & Enemies.MOBILITY else 1.0) * delta)
	elif now >= enemy_ready_at:
		enemy_attack_mode = ""
		enemy_winding_up = true
		active_radius = base_strike_radius()
		var windup := BRIAR_WINDUP_MS
		if destination == Campaign.HEART:
			attack_pattern += 1
			if enemy_hp <= encounter_health() / 2.0 and attack_pattern % 2 == 0:
				active_radius = 3.65
				windup = 950
			else:
				windup = 540
		elif destination == Campaign.MIRE:
			windup = 830
		elif destination == Campaign.HOLLOW:
			windup = 500
		enemy_strike_at = now + Director.windup(self,windup)
		preload("res://event_audio.gd").enemy(self,{"mode":"swipe","from":enemy_pos},false)


func update_pressure(now: int) -> void:
	preload("res://expedition_pressure.gd").tick(self,now)


func nearest_wild_player(origin: Vector3) -> int:
	var target := 0
	var distance := INF
	for id in players:
		var p: Dictionary = players[id]
		if Life.alive(p) and origin.distance_squared_to(p.pos) < distance:
			target = id
			distance = origin.distance_squared_to(p.pos)
	return target


func make_scout(kind: int, position: Vector3, route: int, mutations: int = 0, growth: int = 0, juvenile: bool = false) -> Dictionary:
	var definition := Enemies.get_kind(kind)
	var hp: int
	if Life.Preview.enabled and destination!=Campaign.HEART:
		hp=Director.Balance.scout_hp(definition,encounter_number,difficulty_cycle,growth,encounter_party_size,juvenile)
	else:
		hp=Life.Preview.hp(1) if juvenile else Director.health(self,int(Director.config().scout_base_hp)+int(definition.hp)+growth,false)
	scout_serial+=1
	return {"spawn_token":scout_serial,"pos": position, "kind": kind, "mutations": mutations | (Enemies.JUVENILE if juvenile else 0),
		"growth": growth, "hp": hp,
		"windup": 0, "ready": 0, "rooted_until": 0, "recovery": 0, "engaged": juvenile,
		"ranged": Enemies.ranged(kind), "blast": position, "route": route,
		"stagger_until": 0, "mode": "", "repeat": 0, "summons": 0, "haste_until": 0,
		"max_hp": hp,
		"variant": "" if juvenile else preload("res://enemy_variants.gd").choose(self,kind,route)}


func scout_radius(scout: Dictionary) -> float:
	return Enemies.radius(int(scout.get("kind", 0)), int(scout.get("mutations", 0)))


func update_scouts(delta: float, now: int) -> void:
	# Copy the list, retaining dictionary references, so a finite brood can occupy vacant slots safely.
	for scout in scouts.duplicate():
		if scout.hp <= 0:
			continue
		if EnemyBehaviors.tick(self,scout,delta,now): continue
		var definition := Enemies.get_kind(int(scout.get("kind", 0)))
		var role: String = definition.role
		var mask := int(scout.get("mutations", 0))
		if scout.windup > 0:
			if now >= int(scout.windup):
				resolve_scout(scout, definition, now)
				if not expedition_active():
					abandon_if_empty()
					return
			continue
		if now < int(scout.get("stagger_until",0)):
			continue
		var target := Director.target(self,scout.pos,scout,now)
		if target == 0:
			continue
		var position: Vector3 = scout.pos
		var victim: Vector3 = players[target].pos
		var distance := position.distance_to(victim)
		var allies: Array=support_allies(scout) if Enemies.is_support(int(scout.kind)) else []
		for ally in allies:
			if ally.engaged: scout.engaged=true
		if not scout.engaged and (distance>float(Director.config().aggro_radius) or not battlefield.clear_line(position,victim)):
			continue
		if not scout.get("alerted",false) and distance<=float(Director.config().aggro_radius): Director.alert(self,position);scout.alerted=true
		scout.engaged = true
		var speed := Director.speed(self,float(definition.speed)) * (1.18 if mask & Enemies.MOBILITY else 1.0)
		if now < int(scout.get("haste_until", 0)):
			speed *= 1.22
		if mask & Enemies.JUVENILE:
			speed *= 1.15
		if Enemies.is_support(int(scout.kind)):
			if not allies.is_empty():
				update_support_position(scout,allies,definition,speed,delta,now)
				continue
			role="desperate"
		if scout.has("command_via"):
			if now<int(scout.command_until) and now>=int(scout.rooted_until) and position.distance_to(scout.command_via)>.25 and battlefield.clear_line(position,scout.command_via,Battlefield.CLEARANCE):
				scout.pos=Director.navigate(self,position,scout.command_via,speed*delta,int(scout.route))
				continue
			scout.erase("command_via")
		var attack_range := (1.15 if role=="desperate" else float(definition.range)) + (0.65 if mask & Enemies.REACH else 0.0)
		if now >= int(scout.ready) and now >= int(scout.rooted_until):
			var attacks = preload("res://enemy_attack.gd")
			if attacks.try_skill_approach(self,scout,victim,now) or attacks.try_thorn_vault(self,scout,victim,now):
				continue
		if mask & Enemies.MOBILITY and now >= int(scout.ready) and now >= int(scout.rooted_until):
			var attack = preload("res://enemy_attack.gd")
			var landing: Vector3 = attack.vault_target(self, scout, victim)
			if landing.is_finite():
				attack.lock(self, scout, "vault", landing, now + attack.VAULT_WINDUP)
				continue
		if role == "skirmish" and distance < 3.8 and distance > attack_range and now >= int(scout.rooted_until):
			var tangent := (victim - position).normalized().rotated(Vector3.UP, 0.75 if int(scout.route) % 2 == 0 else -0.75)
			scout.pos = battlefield.slide(position, position + tangent * speed * delta)
		elif distance > attack_range or not battlefield.clear_line(position, victim):
			if now >= int(scout.rooted_until):
				scout.pos = Director.navigate(self,position,Director.pursuit(self,target,int(scout.route)) if not scout.ranged else victim,speed*delta,int(scout.route))
		elif now >= int(scout.ready):
			if preload("res://enemy_variants.gd").prepare(self,scout,victim,delta,now):continue
			var aim := preload("res://enemy_attack.gd").aim(self,scout,role,target)
			var windup_ms: int=int(definition.windup)+(300 if scout.get("variant","")=="early_decoys" else 0)
			preload("res://enemy_attack.gd").lock(self, scout, role, aim, now + Director.windup(self,windup_ms))
			scout.erase("approach_done");scout.erase("approach");scout.erase("approach_used")
			EnemyBehaviors.telegraph(self,scout,now)
			scout.repeat = 1 if int(scout.kind)==1 and role=="volley" else 0


func resolve_scout(scout: Dictionary, definition: Dictionary, now: int) -> void:
	var attacks = preload("res://enemy_attack.gd")
	var attack: Dictionary = attacks.current(self, scout)
	var mode: String = attack.mode
	var damage := Director.Balance.scout_hit(self,definition,scout)
	var radius: float = attack.radius
	var origin: Vector3 = attack.from
	var target_point: Vector3 = attack.to
	scout.windup = 0
	scout.ready = now + roundi((Director.recovery(self,int(definition.recovery))+int(scout.recovery))*(.82 if now<int(scout.get("haste_until",0)) else 1.0))
	scout.recovery = 0
	scout.erase("attack")
	scout.ready += int(attack.get("recovery_bonus",0))
	if mode=="shepherd" and EnemyBehaviors.resolve(self,scout,attack,now): return
	if mode=="lure":
		var anchor: Vector3=attack.anchor
		if not battlefield.clear_line(anchor,target_point): return
		preload("res://event_audio.gd").enemy(self,attack,true)
		var feedback = preload("res://enemy_move_feedback.gd")
		if attack.get("learned",false):feedback.release(self,"burst",anchor,target_point,radius)
		for id in players:
			var p: Dictionary=players[id]
			if not Life.alive(p) or p.pos.distance_to(target_point)>radius or not battlefield.clear_line(anchor,p.pos):continue
			var before: int=int(p.get("damage_seq",0))
			apply_enemy_hit(id,p,now,damage,900,anchor)
			if Life.alive(p) and int(p.get("damage_seq",0))!=before:
				var before_pull: Vector3=p.pos
				p.pos=battlefield.dash(p.pos,p.pos.move_toward(anchor,.9))
				if attack.get("learned",false) and not before_pull.is_equal_approx(p.pos):
					feedback.release(self,"pulled",before_pull,p.pos,0.0,Color("#bad2ee"))
		return
	if mode=="chant":
		if EnemyBehaviors.resolve(self,scout,attack,now): return
		preload("res://event_audio.gd").enemy(self,attack,true)
		if enemy_hp>0 and not Enemies.is_support(enemy_kind) and enemy_pos.distance_to(origin)<=radius and battlefield.clear_line(origin,enemy_pos): enemy_haste_until=now+3500
		for other in scouts:
			if other.hp>0 and not Enemies.is_support(int(other.get("kind",0))) and other.pos.distance_to(origin)<=radius and battlefield.clear_line(origin,other.pos): other.haste_until=now+3500
		return
	if mode in ["charge","pounce","vault"]:
		var learned: bool=attack.get("learned_move",false) or attack.variant==attacks.Thorn.MOVE
		var feedback = preload("res://enemy_move_feedback.gd")
		if not attacks.landing_is_clear(self,scout,attack,now):
			if learned:feedback.stopped(self,scout.pos)
			return
		preload("res://event_audio.gd").enemy(self,attack,true)
		if learned:feedback.movement(self,attack,attacks.CONTACT_PADDING)
		scout.pos=target_point
		if attack.variant==attacks.Thorn.MOVE:
			attacks.Thorn.landed(self,scout,attack,now)
		if attack.get("variant")=="antler_hook":
			attacks.SkillResponses.hit_bent_charge(self,attack,now,damage,attacks.CONTACT_PADDING)
			return
		if mode=="charge" and int(scout.kind)!=13:
			hit_players_charge(origin,target_point,attack.width,radius,now,damage)
			EnemyBehaviors.resolve(self,scout,attack,now)
			return
		hit_players(target_point,radius,now,damage)
		return
	if EnemyBehaviors.resolve(self,scout,attack,now): return
	if float(attack.span)>0.0:
		preload("res://event_audio.gd").enemy(self,attack,true)
		if attack.get("learned",false):
			var feedback = preload("res://enemy_move_feedback.gd")
			feedback.release(self,"sector",origin,attack.face,radius,feedback.THREAT,0.0,attack.span)
		for id in players:
			var p: Dictionary=players[id]
			if Life.alive(p) and AttackGeometry.accepts_sector(origin,attack.face,p.pos,0.0,radius,attack.span) and battlefield.clear_line(origin,p.pos):
				apply_enemy_hit(id,p,now,damage,0,origin)
		return
	if not scout.ranged or battlefield.clear_line(origin,target_point):
		preload("res://event_audio.gd").enemy(self,attack,true)
		if attack.get("variant")=="echo_bud":
			preload("res://enemy_move_feedback.gd").release(self,"burst",origin,target_point,radius,Color("#b895ed"))
		elif int(attack.pulse)>0:
			emit_combat_event("swing","pulse",origin,target_point,.35,Color("#b895ed"),radius,int(attack.pulse))
		hit_players(target_point,radius,now,damage,1600 if mode=="snare" else 0)
		preload("res://glasscap_feint.gd").release(self,scout,now)
	if int(scout.get("repeat", 0)) > 0 and not attack.get("learned",false):
		scout.repeat -= 1
		attack.pulse+=1
		scout.attack=attack
		scout.windup = now + (1000 if attack.variant=="late_pulse" else 500)
		preload("res://event_audio.gd").enemy(self,attack,false)

func spawn_brood(parent: Dictionary) -> bool:
	var support=preload("res://enemy_support.gd")
	var choices: Array[Vector3]=support.brood_sites(self,parent.pos,1)
	return not choices.is_empty() and support.spawn_brood_at(self,choices[0])


func can_vault(from: Vector3, to: Vector3) -> bool:
	if battlefield.clear_line(from, to, Battlefield.CLEARANCE) or battlefield.occupied(to, Battlefield.CLEARANCE):
		return false
	for step in 13:
		if not battlefield.inside_floor(from.lerp(to, step / 12.0), Battlefield.CLEARANCE):
			return false
	return true

func encounter_cleared() -> bool:
	if enemy_hp > 0:
		return false
	if not multiplayer.is_server():
		for i in range(2, client_pack.size(), PACK_STRIDE):
			if client_pack[i] > 0:
				return false
	else:
		for scout in scouts:
			if scout.hp > 0:
				return false
	return true


func closest_enemy(origin: Vector3, visible_only: bool = false) -> int:
	var primary_visible := enemy_hp > 0 and (not visible_only or battlefield.clear_line(origin, enemy_pos))
	var index := -1 if primary_visible else -2
	var best := origin.distance_squared_to(enemy_pos) if primary_visible else INF
	for i in scouts.size():
		if scouts[i].hp > 0 and origin.distance_squared_to(scouts[i].pos) < best and (
				not visible_only or battlefield.clear_line(origin, scouts[i].pos)):
			index = i
			best = origin.distance_squared_to(scouts[i].pos)
	return index


func enemy_position(index: int) -> Vector3:
	return enemy_pos if index == -1 else scouts[index].pos


func scout_snapshot(now: int) -> PackedFloat32Array:
	var snapshot := PackedFloat32Array()
	for scout in scouts:
		snapshot.append_array(PackedFloat32Array([scout.pos.x, scout.pos.z, scout.hp,
			float(scout.windup > 0), float(int(now < int(scout.rooted_until)) | (2 if now < int(scout.get("haste_until", 0)) else 0)), float(scout.ranged),
			scout.blast.x, scout.blast.z]))
	return snapshot


func base_strike_radius() -> float:
	var radius: float = LONGLIMB_STRIKE_RADIUS if longlimb else [BRIAR_STRIKE_RADIUS, 2.1, 2.25, 2.45][destination]
	return radius + (0.35 if enemy_mutations & Enemies.SPORES else 0.0)


func strike_radius() -> float:
	return active_radius if active_radius > 0.0 else base_strike_radius()


func resolve_briar_strike(now: int) -> void:
	if boss_kind<0 and leader_brain.has("elite"):
		preload("res://elite_enemy.gd").resolve(self,now);return
	var vault_release := enemy_attack_mode == "vault"
	if not vault_release or not battlefield.occupied(enemy_landing, Battlefield.CLEARANCE):
		preload("res://event_audio.gd").enemy(self,{"mode":"vault" if vault_release else "swipe","from":enemy_pos},true)
	if enemy_attack_mode == "vault" and not battlefield.occupied(enemy_landing, Battlefield.CLEARANCE):
		enemy_pos = enemy_landing
	enemy_attack_mode = ""
	enemy_winding_up = false
	enemy_ready_at = now + roundi((Director.recovery(self,750)+moss_recovery_bonus)*(.82 if now<enemy_haste_until else 1.0))
	moss_recovery_bonus = 0
	hit_players(enemy_pos, strike_radius(), now, Director.Balance.scout_hit(self,Enemies.get_kind(enemy_kind),{"gate_elite":true}))
	active_radius = 0.0
	abandon_if_empty()


func hit_players(center: Vector3, radius: float, now: int, damage: float = -1.0, slow_ms: int = 0) -> void:
	for id in players:
		var p: Dictionary = players[id]
		if not Life.alive(p) or center.distance_to(p.pos) > radius or not battlefield.clear_line(center, p.pos):
			continue
		apply_enemy_hit(id,p,now,damage,slow_ms,center)

func apply_enemy_hit(id: int,player: Dictionary,now: int,damage: float,slow_ms: int=0,origin: Vector3=Vector3.INF) -> void:
	if not Life.alive(player): return
	if now<int(player.get("hurt_until",0)): return
	if Traits.guard_allows(player,origin,now):
		player.guard_charges=maxi(0,int(player.get("guard_charges",1))-1)
		if player.guard_charges==0: player.guard_until=0
		preload("res://core_skill_effects.gd").ironbark_block(self,id,player,now)
		Traits.blocked(self,player,now)
		player.contributed=true;emit_combat_event("impact","block",player.pos,player.pos,.85,Color("#f1d989"),0,id);tell(id,"Guard blocked the attack.");return
	if Traits.try_brace(self,player,now): return
	if slow_ms>0:
		player.slow_until=now+slow_ms;tell(id,"Slowed.")
	player.hurt_until=now+int(Director.config().hit_grace_ms)
	var hit_points := float(1+difficulty_cycle/2) if damage<0.0 else Life.Preview.authored_amount(damage)
	damage_player(id,player,Life.Preview.effect_hp(hit_points))



func damage_player(id: int, player: Dictionary, amount: int) -> void:
	Transactions.run(self,func(): _damage_player(id,player,amount))

func _damage_player(id: int, player: Dictionary, amount: int) -> void:
	if player.get("wild",false) and not Life.alive(player): return
	var actual_damage:=Life.Vitals.damage_taken(int(player.hp),amount)
	if Life.Preview.enabled and actual_damage==0: return
	player.damage_seq=int(player.get("damage_seq",0))+1
	player.damage_amount=actual_damage if Life.Preview.enabled else maxi(0,amount)
	player.hp = maxi(0, int(player.hp) - actual_damage)
	Journal.event("combat","damage_applied",{"actor":id,"amount":amount,"applied_hp":actual_damage,"hp":player.hp,"damage_seq":player.damage_seq,"vitals_revision":player.get("vitals_revision",0),"hp_per_point":Life.Preview.scale()})
	if player.get("wild",false) and actual_damage>0: emit_combat_event("impact","hurt",player.pos,player.pos,.85,Color("#ff957d"),float(actual_damage),id)
	if player.hp > 0:
		return
	if player.wild:
		Life.down(self,id,player)
	else:
		return_to_garden(player)




func act(id: int, strike: bool) -> void:
	var request:=Journal.interaction(self,id,"interact","begin") if not strike else 0
	_act(id,strike)
	if not strike:Journal.interaction(self,id,"interact","end",request)

func _act(id: int, strike: bool) -> void:
	if not Transactions.session_writable(self): return
	if not players.has(id) or not players[id].profile_ready:
		return
	var p: Dictionary = players[id]
	if p.get("wild",false) and not Life.alive(p): return
	var pos: Vector3 = p.pos
	var rescue:=Life.nearest(self,p)
	if not strike and rescue!=0:
		Transactions.run(self,func(): return Life.revive(self,id,rescue))
	elif strike:
		strike_enemy(id, p, pos)
	elif nearest_inventory_drop(p)!="":
		pickup_inventory_drop(id,p,nearest_inventory_drop(p))
	elif p.wild and p.loot_pending and pos.distance_to(drop_pos) <= 1.45:
		collect_drop(p)
		tell(id,"Seeds collected.")
	elif p.wild and battlefield.procedural and destination != Campaign.HEART and (
			not p.cache_claimed and pos.distance_to(battlefield.cache) <= 1.55):
		var reserve := seed_reserve(p)
		var kind := progress.roll_seed(reserve, p.carried_seeds, [], destination, rng.randf(), encounter_number)
		p.carried_seeds.append(kind)
		p.cache_claimed = true
		tell(id, "Seed found. Extract to keep it.")
	elif not p.wild and pos.distance_to(Stage.GATE) <= preload("res://gate_interaction.gd").RANGE:
		if destination == Campaign.HEART:
			tell(id, "Join the finale from the Heart in the Garden.")
		else:
			show_gate_preparation(id)
	elif p.wild and at_graft_altar(p) and preload("res://gate_interaction.gd").shrine_preferred(battlefield,pos):
		show_graft_menu(id)
	elif p.wild:
		if destination != Campaign.HEART and pos.distance_to(battlefield.advance) <= preload("res://gate_interaction.gd").RANGE:
			use_checkpoint(id, true)
		else:
			tell(id, "Move closer to the seed or a checkpoint.")
	elif not p.wild and preload("res://garden_interaction_service.gd").interact(self,id):
		pass
	elif at_heart(p):
		show_heart_tree(id)
	elif pos.distance_to(Stage.ALTAR) <= 1.65:
		show_garden_altar(id)
	else:
		var kind := nearby_plot(pos)
		if kind >= 0:
			if progress.offshoot_in_bed(kind)>=0: tell(id,"This bed nurtures a living offshoot. Its care is managed at the Heart.");return
			if progress.plots[kind].species >= 0:
				if int(progress.plots[kind].stage)<3:preload("res://garden_crop_service.gd").focus(self,id,kind)
				else:harvest(id, kind)
			else:
				show_planting_picker(id,kind)
		else:
			tell(id, "Move closer to the altar, a plot, or the gate.")


func nearby_plot(pos: Vector3) -> int:
	var count: int = progress.plots.size() if multiplayer.is_server() else client_garden[12].size() / 3
	for i in count:
		if pos.distance_to(Stage.PLOTS[i]) <= 1.55:
			return i
	return -1


func harvest(id: int, slot: int) -> void:
	if not players.has(id) or slot<0 or slot>=progress.plots.size():return
	var bed: Dictionary=progress.plots[slot].duplicate(true)
	var before_rng: int=rng.state
	var rare: int=Parts.rare_part(int(bed.species)) if int(bed.species)>=0 else 0
	var rare_before: int=progress.part_count(rare) if rare>0 else 0
	var result=Transactions.run(self,func(): _harvest(id,slot))
	if result==false:rng.state=before_rng;return
	if int(bed.species)>=0 and int(bed.stage)==3 and int(progress.plots[slot].species)<0:
		Journal.event("garden","crop_harvested",{"actor":id,"bed":slot,"cycle":bed.get("care",{}).get("cycle",""),"species":Seeds.DEFINITIONS[int(bed.species)].id,"flowering":bool(bed.flowering),"preserved":preload("res://garden_crop_state.gd").preserved(bed),"rare":rare>0 and progress.part_count(rare)>rare_before})

func _harvest(id: int, slot: int) -> void:
	var bed: Dictionary = progress.plots[slot]
	var kind := int(bed.species)
	if kind < 0 or bed.stage < 3:
		tell(id, "Still growing: %s." % ["Seed", "Sprout", "Young plant", "Mature"][int(bed.stage)])
		return
	var seeds := bool(bed.flowering)
	progress.plots[slot] = Progress.empty_plot()
	progress.sync_plot_flags()
	var profile: Dictionary = players[id].character
	var familiarity: int = profile.plants[kind]
	profile.plants[kind] = mini(9999, familiarity + 1 + int(progress.heart.has("nursery")) + int(Classes.bonuses(profile,int(players[id].frame)).get("familiarity",0)))
	publish_character(id)
	if seeds:
		seed_reserve(players[id]).stock[kind] += 2
		save_progress(id, "Harvested two %s seeds. The bed is ready to replant." % Progress.PLANT_NAMES[kind])
	else:
		progress.parts[kind] += 1
		var message := "Harvested a %s part. Replant this bed with any identified seed." % Progress.PLANT_NAMES[kind]
		var harvest_roll:=rng.randf()
		if preload("res://garden_crop_state.gd").preserved(bed):harvest_roll=preload("res://garden_crop_state.gd").roll(bed)
		if harvest_roll < preload("res://garden_crop_state.gd").chance(bed,rare_harvest_chance(familiarity)):
			var rare:=Parts.rare_part(kind)
			if rare>0: progress.add_parts(rare,1);message+=" Rare harvest: "+Parts.part_name(rare)+"."
		save_progress(id, message)
	preload("res://event_audio.gd").emit(self,"crop_harvested",Stage.PLOTS[slot])

func rare_harvest_chance(familiarity: int) -> float:
	return minf(.45,0.05+0.04*mini(familiarity,5)+.005*maxi(0,familiarity-5))


func strike_enemy(id: int, p: Dictionary, pos: Vector3) -> void:
	if not Life.alive(p): return
	var now:=Time.get_ticks_msec()
	if now<int(p.strike_at): return
	var stats:=weapon_stats(p)
	if p.get("skill_burst",false):
		stats.targets=mini(5,int(stats.targets)+int(p.get("skill_burst_targets",2)))
		stats.damage+=int(p.get("skill_burst_damage",1))
		stats.pattern="chain" if int(p.frame)==Frames.RANGER else "sweep"
	Life.Preview.lock_strike(stats,int(p.power))
	p.strike_at=now+int(stats.interval)
	p.cast_until=0
	var form:=WeaponMotion.form(p)
	var duration:=maxi(180,mini(roundi(float(WeaponMotion.profile(form).duration)*1000),roundi(int(stats.interval)*.9)))
	p.attack_reach=float(stats.reach);p.attack_duration=duration;p.attack_until=now+duration;p.swing_until=now+duration;p.attack_combo=int(p.get("attack_combo",0))+1
	if p.get("mouse_aim",false):
		MouseCombat.queue_attack(self,id,p,pos,stats,now,form,duration)
		return
	var first:=select_attack_target(p,float(stats.reach))
	if first==-2 or pos.distance_to(enemy_contact_point(first,pos))>float(stats.reach):
		MouseCombat.queue_attack(self,id,p,pos,stats,now,form,duration)
		tell(id,"No enemy within clear weapon reach.")
		return
	var aim: Vector3=enemy_contact_point(first,pos)
	if aim.distance_to(pos)>.001: p.facing=(aim-pos).normalized()
	MouseCombat.queue_attack(self,id,p,pos,stats,now,form,duration,first)



func apply_weapon_hit(p: Dictionary,target: int,origin: Vector3,stats: Dictionary,now: int) -> void:
	if target < -1 or target>=scouts.size() or (enemy_hp if target==-1 else int(scouts[target].hp))<=0: return
	p.contributed=true
	if not stats.get("core_hit",false): stats=Traits.augment_hit(self,p,target,stats,now)
	var point:=enemy_position(target)
	var distance:=origin.distance_to(point)
	var winding: bool=stats.get("was_winding",enemy_winding_up if target==-1 else float(scouts[target].windup)>0)
	var pull:=float(stats.get("pull",0))
	if pull>0 and not winding:
		point=battlefield.dash(point,point.move_toward(origin,clampf(distance-0.9,0,pull)))
	var authored_damage:=Life.Preview.authored_amount(float(stats.damage))
	if not stats.get("trait_secondary",false):
		authored_damage+=int(stats.get("preview_power",p.power))
	if winding:
		authored_damage+=Life.Preview.authored_amount(float(stats.get("windup_damage",0)))
	if winding and p.rift_hook and not stats.get("core_hit",false): p.dodge_at=0
	if winding and float(stats.get("windup_damage",0))>0:preload("res://combat_status.gd").proc(self,"punish",origin,point,target)
	if Life.Preview.authored_amount(float(stats.damage))>0.0 and not stats.get("trait_secondary",false) and not stats.get("core_hit",false):
		authored_damage+=preload("res://core_strike_mark.gd").consume(self,p,target,now)
	var damage:=Life.Preview.resolved_hit(authored_damage,stats)
	var push:=0.35+float(stats.get("knockback",0))
	var mutations: int=enemy_mutations if target==-1 else int(scouts[target].get("mutations",0))
	if not preload("res://enemy_support.gd").shelter_source(self,target,point,origin,now).is_empty():
		damage=Life.Preview.armor(damage)
	if target==-1 and boss_kind>=0: push*=.2
	elif target==-1 and (depth==ROUTE_ROOMS or destination==Campaign.HEART): push*=0.5
	var guard_actor: Dictionary=scouts[target] if target>=0 else leader_brain.get("elite",{})
	if guard_actor.get("variant","")=="bark_guard":
		if preload("res://enemy_variants.gd").guards(guard_actor,origin,now):
			push*=.6;damage=Life.Preview.armor(damage)
	elif mutations & Enemies.BARK: push*=0.6;damage=Life.Preview.armor(damage)
	if target==-1 and Bosses.exposed(self,now):damage+=Director.Balance.exposed_bonus(damage)
	if winding: push*=0.4
	if pull<=0 or winding:
		var direction: Vector3=(point-origin).normalized() if distance>0.001 else p.facing
		point=battlefield.dash(point,point+direction*push)
	var stagger:=now+90+int(stats.get("stagger",0))
	var recovery:=int(stats.get("recovery",0))
	var player_id:=0
	for peer_id in players:
		if is_same(players[peer_id],p): player_id=peer_id;break
	if player_id!=0: combat_threat[player_id]=float(combat_threat.get(player_id,0))+Life.Vitals.threat_from_hit(damage,Life.Preview.scale())
	Director.alert(self,point)
	var before: int=enemy_hp if target==-1 else int(scouts[target].hp)
	var applied:=Life.Vitals.damage_taken(before,damage)
	if Life.Vitals.counts_as_burst(damage,Life.Preview.scale()): burst_hits_this_room+=1
	if before<=applied and battlefield.procedural and battlefield.floor_distance(point)<1.6: choke_kills_this_room+=1
	if target==-1:
		if enemy_winding_up and Bosses.owns_warnings(boss_kind):point=enemy_pos
		enemy_pos=point
		enemy_engaged=true
		enemy_hp-=applied
		moss_recovery_bonus=maxi(moss_recovery_bonus,recovery)
		if winding and enemy_hp>0 and boss_kind==22 and float(stats.get("stagger",0))>=150:
			preload("res://boss_phase_fights.gd").interrupt(self,point,now)
		if winding and boss_kind<0 and leader_brain.has("elite") and float(stats.get("stagger",0))>=150 and EnemyBehaviors.interrupt(self,leader_brain.elite,point,now):
			enemy_ready_at=leader_brain.elite.ready
			enemy_winding_up=false
			winding=false
		if not winding: enemy_stagger_until=stagger
		if enemy_hp==0: enemy_winding_up=false
	else:
		var scout: Dictionary=scouts[target]
		scout.pos=point
		scout.engaged=true
		scout.hp-=applied
		scout.recovery=maxi(int(scout.recovery),recovery)
		if winding and float(stats.get("stagger",0))>=150 and EnemyBehaviors.interrupt(self,scout,point,now):winding=false
		if not winding: scout.stagger_until=stagger
	if stats.get("rite_suppressed",false) and applied<before:
		var actor: Dictionary=scouts[target] if target>=0 else leader_brain.get("elite",{})
		preload("res://wilds_skill_tactics.gd").interrupted(self,actor,"suppression")
	if applied>0:
		var form := "magic" if stats.get("trait_secondary",false) else str(stats.get("audio_form",WeaponMotion.form(p)))
		emit_combat_event("impact","hit",origin,point,.85,weapon_effect_color(p),float(applied),target,{"form":form})
	if before>0 and applied>=before:
		record_enemy_death(target,point,origin)
		var restored:=Life.Sustain.heal_on_kill(self,p,target,Life.Preview.authored_amount(float(stats.get("heal_on_kill",0))))
		if restored>0.0 and not Life.Preview.enabled:preload("res://combat_status.gd").proc(self,"siphon",point,p.pos)
	Traits.after_hit(self,p,target,stats,now,before>0 and applied>=before)
	damage_this_room+=applied
	if float(stats.get("shot_distance",distance))>=RANGED_DISTANCE:
		ranged_damage_this_room+=applied
		if player_id!=0 and combat_velocity.get(player_id,Vector3.ZERO).length()>.8: moving_ranged_hits+=1

func finish_combat(id: int,loot_position: Vector3) -> void:
	if not MonsterRewards.flush(self): return
	Transactions.run(self,func(): _finish_combat(id,loot_position))
	if not encounter_rewarded: reward_retry_at=Time.get_ticks_msec()+1000

func _finish_combat(id: int,loot_position: Vector3) -> void:
	if pending_finale_at>0 or encounter_rewarded: return
	encounter_rewarded=true
	preload("res://game_metrics.gd").record("encounter_clear",{"floor":encounter_number,"biome":destination,"kills":encounter_kills.size(),"cycle":difficulty_cycle})
	burst_clears+=int(burst_hits_this_room>=2)
	choke_clears+=int(choke_kills_this_room>=3)
	award_combat_progress()
	if destination==Campaign.HEART:
		pending_finale_peer=id
		pending_finale_at=Time.get_ticks_msec()+1500
		enemy_winding_up=false
		tell(id,"The Heart collapses as its last roots fall silent…")
		return
	var ranged_evidence:=Life.Vitals.counts_as_ranged(ranged_damage_this_room,damage_this_room,Life.Preview.scale())
	if ranged_evidence: ranged_clears+=1
	var previous_memory: Dictionary=progress.wilds_memory.score.duplicate()
	var thorn_evidence:=preload("res://thorn_adaptation.gd").evidence(self)
	var skill_evidence:=preload("res://wilds_skill_tactics.gd").evidence(self)
	var learned: Dictionary={"ranged":ranged_evidence,"burst":burst_hits_this_room>=2,"choke":choke_kills_this_room>=3 and choke_kills_this_room*2>=encounter_kills.size(),"kite":moving_ranged_hits>=3 and Time.get_ticks_msec()-encounter_started_at>=8000,"thorn_line":thorn_evidence.crossings>0}
	for tactic in skill_evidence: learned[tactic]=int(skill_evidence[tactic])>0
	Learning.observe(progress.wilds_memory,learned,encounter_number)
	preload("res://game_metrics.gd").record("wilds_learning",{"floor":encounter_number,"encounters":progress.wilds_memory.encounters,"scores":progress.wilds_memory.score.duplicate(),"thorn_armed":thorn_evidence.armed,"thorn_crossings":thorn_evidence.crossings,"skill_evidence":skill_evidence,"party":encounter_party_size,"elapsed_ms":Time.get_ticks_msec()-encounter_started_at})
	deepest_milestone=maxi(deepest_milestone,encounter_number)
	if depth==ROUTE_ROOMS and destination<Campaign.HEART: run_guardians|=1 << destination;guardian_counts[destination]+=1
	enemy_winding_up=false
	drop_pos=loot_position
	for player in players.values(): player.loot_pending=Life.alive(player)
	refresh_drop()
	if encounter_cleared():
		var cue := "extract_ready" if extraction_checkpoint_open() else "gate_ready"
		preload("res://event_audio.gd").emit(self,cue,battlefield.advance)
	tell(id,"Encounter cleared. Press E near the glowing loot."+Learning.notice(previous_memory,progress.wilds_memory.score))


func wild_entry(id: int) -> Vector3:
	var slot: int=players.get(id,{}).get("party_slot",0)
	var offset: Vector3=[Vector3(-.65,0,-.45),Vector3(.65,0,-.45),Vector3(-.65,0,.65),Vector3(.65,0,.65)][clampi(slot,0,Network.MAX_PLAYERS-1)]
	return battlefield.slide(battlefield.entry,battlefield.entry+offset)


func enter_wilds(id: int, p: Dictionary) -> void:
	if players.size()>1: PartyTravel.request(self,id,"depart")
	else: Transactions.run(self,func(): _enter_wilds(id,p))

func _enter_wilds(id: int, p: Dictionary,reserved_override: Array=[]) -> void:
	var starting := not expedition_active()
	var available := progress.finale_available() if destination == Campaign.HEART else progress.campaign.available(destination)
	if starting and not available:
		tell(id, "This path is still sealed.")
		return
	if expedition_active() and p.fallen:
		tell(id, "Wait for your party to finish the expedition.")
		return
	var selected: Array = [p.prepared, p.prepared_secondary, p.get("prepared_catalyst",0)]
	var needed := Parts.empty_counts()
	for part in selected:
		if part!=0 and not Parts.is_plant(part):
			tell(id,"Only plant materials fit the first three slots.")
			return
		needed[part]+=1
	for part in range(1,needed.size()):
		needed[part]+=int(p.cargo_plan[part])
		if available_parts(p,part)<needed[part]:
			tell(id,"Not enough %s for the loadout and cargo."%Parts.part_name(part))
			return
	var reserved := Seeds.counts()
	for part in range(1,needed.size()):
		if Parts.is_plant(part) and part!=Parts.HEARTWOOD:
			reserved[Parts.plant_source(part)]+=maxi(0,int(needed[part])-int(seed_reserve(p).parts[part]))
	for part in selected:
		if part != Parts.EMPTY and available_parts(p, part) == 0:
			tell(id, "%s is unavailable. Change the slot at the Wilds gate." % Parts.part_name(part))
			return
	if starting:
		var cost: int = 0 if destination == Campaign.HEART else Campaign.SHORTCUT_COST[destination]
		if cost > 0:
			if id != HOST:
				tell(id, "The host must open this paid route first.")
				return
			var paid := progress.pay_shortcut(cost,reserved_override if not reserved_override.is_empty() else reserved)
			if paid != OK:
				tell(id, "Need %d shared plant parts to open this route." % cost if paid == ERR_UNAVAILABLE
					else "Could not save the route payment. Your parts were returned.")
				return
		reset_expedition()
		start_encounter()
	if starting:preload("res://garden_return_service.gd").begin(self)
	preload("res://garden_return_service.gd").join(self,id,p)
	p.wild = true
	p.fallen=false
	p.lost_health=0
	for key in ["echo_charge","grave_charges","tide_ready","decoy_ready","link_ready","counter_until","front_guard_until","counter_guard_until","brace_block_ready"]: p[key]=0
	p.still_since=Time.get_ticks_msec();p.still_point=wild_entry(id)
	p.essence_sparks=0
	p.pos = wild_entry(id)
	p.dodge_at = 0
	p.skill_at = 0
	p.skill_two_at=0
	p.core_ready_at=0
	p.core_cast_until=0
	p.hurt_until=0
	p.guard_charges=0
	p.guard_until = 0
	p.weapon = p.prepared
	p.secondary = p.prepared_secondary
	p.catalyst = p.prepared_catalyst
	p.graft_part = 0
	p.graft_floor=0
	p.erase("graft_message")
	p.prepared_catalyst = 0
	p.prepared = Parts.EMPTY
	p.prepared_secondary = Parts.EMPTY
	var gained := 0
	for part in selected:
		if part != Parts.EMPTY:
			var reserve := seed_reserve(p)
			if reserve.parts[part] > 0:
				reserve.parts[part] -= 1
			else:
				progress.add_parts(part, -1)
			gained += progress.record_part_craft(part)
	for part in range(1,Parts.DEFINITIONS.size()):
		var amount: int=p.cargo_plan[part]
		if amount>0 and Parts.is_monster(part):
			var reserve:=seed_reserve(p)
			var personal:=mini(int(reserve.parts[part]),amount)
			reserve.parts[part]-=personal
			progress.add_parts(part,-(amount-personal))
			p.carried_parts[part]+=amount
	p.cargo_plan.fill(0)
	p.max_hp=Life.maximum(self,p)
	Life.Vitals.heal(p,maxi(0,int(p.max_hp)-Life.Preview.hp(MAX_HEALTH)))
	if gained > 0:
		save_progress(id, "Weapon assembled. The Heart gained %d knowledge." % gained)
	else:
		progress.save_garden()
	if gained <= 0:
		tell(id, "Entered %s." % Campaign.NAMES[destination])


func complete_finale(id: int) -> void:
	if has_meta(Transactions.SESSION): return
	if not Campaign.LEGACY_ENDING_ENABLED: return
	if not players.has(id): id=HOST
	progress.campaign.finish()
	var message := ending_message(progress.campaign.ending)
	for peer_id in players:
		if players[peer_id].wild:
			return_to_garden(players[peer_id])
		if peer_id != id:
			tell(peer_id, message)
	destination = Campaign.GROVE
	reset_expedition()
	save_progress(id, message)


func ending_message(ending: int) -> String:
	if ending == Campaign.SEED:
		return "ENDING: A Seed Remains. The Heart can be cultivated anew."
	if ending == Campaign.CORRUPTION:
		return "ENDING: The Returning Wilds. Without the Heart, corruption returns."
	return ""


func return_to_garden(p: Dictionary) -> void:
	MonsterRewards.flush(self)
	p.attack_until=0;p.swing_until=0;p.cast_until=0
	p.run_upgrades={}
	p.essence_sparks=0
	p.checkpoint_offers=[]
	p.offer_floor=0
	p.power=0
	p.technique=0
	p.wild = false
	p.fallen=false
	p.lost_health=0
	p.weapon = 0
	p.guard_until = 0
	p.front_guard_until=0;p.counter_guard_until=0;p.counter_until=0;p.grave_charges=0;p.echo_charge=0
	p.focus_until=0
	p.skill_fx_until=0
	p.guard_charges=0
	p.renewal_until=0
	p.carried_parts.fill(0)
	p.carried_seeds.clear()
	p.safe_items=[]
	p.carried_items={}
	p.pouch = false
	p.loot_pending = false
	refresh_drop()
	p.secondary = Parts.EMPTY
	p.catalyst=0
	p.graft_part=0
	p.graft_floor=0
	p.erase("graft_message")
	p.rift_hook = false
	p.pos = Stage.GATE + Vector3(0, 0, 2.0)
	p.hp = float(p.get("max_hp", MAX_HEALTH))
	p.slow_until = 0
	p.hurt_until=0
	restore_class_loadout(p)
	p.hp=float(p.max_hp)


func expedition_active() -> bool:
	for player in players.values():
		if player.wild:
			return true
	return false


func abandon_if_empty() -> void:
	if expedition_active() and Life.living_ids(self).is_empty():
		finish_failed_expedition()
	elif not expedition_active() and (enemy_hp < encounter_health() or deepest_milestone > 0):
		finish_failed_expedition()


func finish_failed_expedition() -> void:
	var returned=Transactions.run(self,func(): _finish_failed_expedition())
	if returned==false:battlefield.configure(destination,depth,map_seed)

func _finish_failed_expedition() -> void:
	for player in players.values():
		recover_pouch(player)
		if player.wild:
			preload("res://garden_return_service.gd").outcome(self,player,"wipe")
			return_to_garden(player)
	var milestone := deepest_milestone
	var message := milestone_message("Expedition ended. Only safe-pouch contents are kept.", false)
	destination = Campaign.GROVE
	reset_expedition()
	if milestone > 0:
		save_progress(HOST, message)
	else:
		tell(HOST, message)
	for id in players:
		if id != HOST:
			tell(id, message)


func seed_reserve(player: Dictionary) -> Dictionary:
	return progress.reserve(player.seed_owner)


func recover_pouch(player: Dictionary) -> bool:
	if SaveBatch.active: return bool(Transactions.run(self,func(): return _recover_pouch(player)))
	var result := Transactions.run_gameplay(self, Transactions.Scope.PAIR, func(): return _recover_pouch(player))
	return (result.completed or Transactions.committed(result.persistence)) and result.value == true

func _recover_pouch(player: Dictionary) -> bool:
	InventoryModel.normalize_pouch(player)
	if player.safe_items.is_empty(): return false
	InventoryModel.bank_safe(self,player)
	if not SaveBatch.guarded_active() and progress.save_garden() != OK:
		status = "Protected seed could not be saved. Use Save Garden to retry."
	return true


func refresh_drop() -> void:
	has_drop = false
	for player in players.values():
		if player.loot_pending:
			has_drop = true
			return


func collect_drop(player: Dictionary) -> void:
	var count := 1 if depth == 1 else 2
	var reserve := seed_reserve(player)
	var bundle: Array = []
	for i in count:
		var seed_kind := progress.roll_seed(reserve, player.carried_seeds, bundle, destination, rng.randf(), encounter_number)
		bundle.append(seed_kind)
		player.carried_seeds.append(seed_kind)
	player.loot_pending = false
	refresh_drop()


func use_checkpoint(id: int, descend: bool) -> void:
	if PartyTravel.members(self,"advance").size()>1:
		PartyTravel.request(self,id,"advance" if descend else "extract");return
	var returned=Transactions.run(self,func(): _use_checkpoint(id,descend))
	if returned==false:battlefield.configure(destination,depth,map_seed)

func _use_checkpoint(id: int, descend: bool) -> void:
	if not players.has(id) or not Life.alive(players[id]):
		return
	if not descend and not extraction_checkpoint_open():
		tell(id, "Extraction opens after clearing every sixth gate.")
		return
	if players[id].pos.distance_to(battlefield.advance) > preload("res://gate_interaction.gd").RANGE:
		tell(id, "Use the onward gate to continue or extract at a checkpoint.")
		return
	if not encounter_cleared():
		tell(id, "Defeat the enemies to open the checkpoint.")
		return
	var checkpoint := battlefield.advance
	for player in players.values():
		if Life.alive(player) and checkpoint.distance_to(player.pos) > preload("res://gate_interaction.gd").RANGE+preload("res://gate_interaction.gd").READY_MARGIN:
			tell(id, "Gather your expedition party at this checkpoint.")
			return
	if descend and upgrade_checkpoint_open():
		if not checkpoint_pending:
			checkpoint_pending=true
			checkpoint_ready.clear()
		if not checkpoint_all_ready():
			for peer_id in players:
				if Life.alive(players[peer_id]): present_checkpoint_cards(peer_id)
			return
		checkpoint_pending=false
		checkpoint_ready.clear()
		close_run_flow_panel()
		for peer_id in players:
			if peer_id!=HOST and online_peer!=null: close_run_flow_panel.rpc_id(peer_id)
	if descend:
		if destination == Campaign.HEART:
			return
		var crossed_biome := depth == ROUTE_ROOMS
		encounter_number += 1
		if crossed_biome:
			depth = 1
			if destination == Campaign.HOLLOW:
				difficulty_cycle += 1
			destination = (destination + 1) % Campaign.HEART
		else:
			depth += 1
		start_encounter()
		var recovery_hp:=Life.Sustain.recovery_hp(crossed_biome or (not Life.Preview.enabled and depth==ROUTE_ROOMS),difficulty_cycle)
		for peer_id in players:
			var player: Dictionary = players[peer_id]
			if player.wild:
				player.pos = wild_entry(peer_id)
				if Life.alive(player): Life.Sustain.restore(self,player,recovery_hp,"floor_recovery")
				tell(peer_id, "%s · Encounter %d. %s awaits.%s" % [
					Campaign.NAMES[destination], encounter_number, enemy_name(),
					" A grafting shrine waits off the main path." if graft_altar_open() else ""])
		return
	var banked := 0
	var banked_parts := 0
	for player in players.values():
		if player.wild and player.fallen:
			recover_pouch(player)
		elif player.wild:
			InventoryModel.bank_safe(self,player)
			InventoryModel.bank_extra(self,player)
			banked += player.carried_seeds.size()
			preload("res://garden_return_service.gd").bank(self,player,player.carried_seeds,"extract")
			seed_reserve(player).unknown.append_array(player.carried_seeds)
			for part in range(1, Parts.DEFINITIONS.size()):
				var count: int = player.carried_parts[part]
				seed_reserve(player).parts[part] += count
				banked_parts += count
	var milestone := deepest_milestone
	var message := milestone_message("Extracted with %d seed(s) and %d weapon part(s)." % [banked, banked_parts], true)
	if destination != Campaign.HEART:
		progress.campaign.record_guardian_memories(run_guardians,guardian_counts)
	for site in Campaign.HEART:
		if (run_guardians & (1 << site)) != 0 and progress.campaign.record_clear(site):
			message += " %s awaits at the Heart." % Campaign.OFFSHOOTS[site]
	for peer_id in players:
		var player: Dictionary = players[peer_id]
		if player.wild:
			preload("res://garden_return_service.gd").outcome(self,player,"fallen" if player.fallen else "extracted")
			return_to_garden(player)
			if peer_id != id:
				tell(peer_id, message)
	destination = Campaign.GROVE
	reset_expedition()
	if banked > 0 or banked_parts > 0 or milestone > 0:
		save_progress(id, message)
	else:
		tell(id, message)


func milestone_message(message: String, extracted: bool) -> String:
	if deepest_milestone > 0 and destination != Campaign.HEART:
		progress.remember_expedition(ranged_clears, burst_clears, choke_clears)
		progress.campaign.advance_growth()
		progress.campaign.record_expedition(deepest_milestone, extracted)
	return message + progress.apply_milestone(deepest_milestone)


func encounter_health() -> int:
	if not multiplayer.is_server(): return int(players.get(multiplayer.get_unique_id(),{}).get("enemy_max_hp",Life.Preview.hp(ENEMY_HEALTH)))
	if Life.Preview.enabled and destination!=Campaign.HEART:
		if boss_kind>=0: return Director.Balance.boss_hp(Enemies.get_kind(boss_kind),encounter_number,difficulty_cycle,encounter_party_size)
		return Director.Balance.elite_hp(Enemies.get_kind(enemy_kind),encounter_number,depth,difficulty_cycle,encounter_party_size)
	if boss_kind>=0: return Director.health(self,30+int(Enemies.get_kind(boss_kind).hp)+encounter_number/3,true)
	if destination == Campaign.HEART:
		return Director.health(self,Campaign.FINAL_HP,true)
	return Director.health(self,int(Director.config().leader_base_hp)+depth-1+destination+(2 if depth==ROUTE_ROOMS else 0)+difficulty_cycle*(difficulty_cycle+2),true)


func start_encounter() -> void:
	wild_item_drops.clear()
	map_seed = map_rng.randi_range(1, 2147483647)
	reset_encounter()


func reset_encounter() -> void:
	MonsterRewards.flush(self)
	if pending_kill_rewards.is_empty(): kill_receipts.clear()
	encounter_kill_records.clear();combat_threat.clear();combat_velocity.clear();combat_last_positions.clear();leader_brain.clear();moving_ranged_hits=0;encounter_started_at=Time.get_ticks_msec();encounter_party_size=Director.party_size(self)
	encounter_kills.clear();encounter_rewarded=false;reward_retry_at=0
	combat_epoch+=1
	preload("res://core_combat.gd").reset(self)
	enemy_traits.clear();trait_events.clear()
	projectile_queue.clear()
	combat_events.clear()
	Bosses.prepare(self)
	battlefield.configure(destination, depth, map_seed,boss_kind,boss_phase)
	pressure_at = 0
	enemy_haste_until=0
	pending_finale_at=0
	enemy_death_events.clear()
	scouts.clear()
	enemy_pos = Director.spawn(self,battlefield.leader,-1)
	if enemy_pos==Vector3.INF: enemy_pos=clear_spawn(battlefield.leader)
	enemy_kind = boss_kind if boss_kind>=0 else 9 if destination == Campaign.HEART else preload("res://elite_enemy.gd").select(self)
	enemy_hp = encounter_health()
	enemy_engaged = false
	enemy_stagger_until = 0
	enemy_attack_mode = ""
	scouts.clear()
	enemy_growth = Enemies.tier(encounter_number, difficulty_cycle)
	enemy_mutations = current_mutations(enemy_kind, enemy_growth, map_seed)
	var count := Director.scout_count(self)
	if boss_kind>=0: count=Director.Balance.boss_escorts(self,count)
	var composition=preload("res://wilds_composition.gd")
	var roster: Array[int]=composition.roster(self,count)
	for i in count:
		var origin: Vector3 = battlefield.spawn_points[i%battlefield.spawn_points.size()] if battlefield.procedural else Stage.SUPPORT_SPAWNS[i%Stage.SUPPORT_SPAWNS.size()]+Vector3.RIGHT*(i/Stage.SUPPORT_SPAWNS.size())*1.8
		var spawn: Vector3=composition.companion_spawn(self,i) if i==1 and boss_kind<0 and destination!=Campaign.HEART and battlefield.procedural else Vector3.INF
		if not spawn.is_finite():spawn=Director.spawn(self,origin,i)
		if not spawn.is_finite():continue
		var kind: int=roster[i]
		var mutations := current_mutations(kind, enemy_growth, map_seed + i)
		scouts.append(make_scout(kind, spawn, i + 1, mutations, enemy_growth))
	arrange_support_groups()
	Director.Balance.trace_encounter(self,count)
	longlimb = (enemy_mutations & Enemies.REACH)!=0
	burst_hits_this_room = 0
	choke_kills_this_room = 0
	attack_pattern = 0
	active_radius = 0.0
	damage_this_room = 0
	ranged_damage_this_room = 0
	for player in players.values():
		player.contributed = false
		player.loot_pending = false
		player.cache_claimed = false
	enemy_winding_up = false
	enemy_ready_at = 0
	rooted_until = 0
	moss_recovery_bonus = 0
	has_drop = false


func clear_spawn(position: Vector3) -> Vector3:
	for shift in [Vector3.ZERO, Vector3.RIGHT * 1.5, Vector3.LEFT * 1.5,
			Vector3.FORWARD * 1.5, Vector3.BACK * 1.5, Vector3.BACK * 2.7]:
		var candidate: Vector3 = position + shift
		if not battlefield.occupied(candidate, Battlefield.CLEARANCE):
			return candidate
	for radius in range(2, 5):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var candidate := position + Vector3(x, 0, z)
				if absf(candidate.x) <= Stage.WILD_BOUNDS.x and absf(candidate.z) <= Stage.WILD_BOUNDS.y and (
						not battlefield.occupied(candidate, Battlefield.CLEARANCE)):
					return candidate
	return position


func reset_expedition() -> void:
	mouse_controls.clear(self)
	boss_kind=-1;boss_phase=0;boss_moves=0;boss_floors.clear();used_bosses.clear();enemy_hazards.clear()
	PartyTravel.clear(self)
	guardian_counts.fill(0)
	wild_item_drops.clear()
	checkpoint_pending=false
	checkpoint_ready.clear()
	depth = 1
	encounter_number = 1
	difficulty_cycle = 0
	run_guardians = 0
	map_seed = 0
	deepest_milestone = 0
	ranged_clears = 0
	burst_clears = 0
	choke_clears = 0
	for player in players.values():
		player.fallen = false
		player.lost_health=0
		player.spent = 0
		player.essence_sparks=0
		player.last_offer = 0
		player.run_upgrades={}
		player.checkpoint_offers=[]
		player.offer_floor=0
		player.upgrade_seed=Crypto.new().generate_random_bytes(8).hex_encode().hash()
		player.last_deposit=0
		player.power = 0
		player.technique = 0
		player.carried_parts.fill(0)
		player.carried_seeds.clear()
		player.pouch = false
		player.safe_items=[]
		player.carried_items={}
		player.secondary = Parts.EMPTY
		player.graft_choice = Parts.EMPTY
		player.rift_hook = false
	reset_encounter()


func identify_seed(id: int) -> void:
	if players.has(id):tell(id,Altar.identify(self,players[id]))

func selected_seed(player: Dictionary) -> int:
	var stock: Array = seed_reserve(player).stock
	var selected := clampi(int(player.get("seed_choice", 0)), 0, Seeds.NAMES.size() - 1)
	if stock[selected] > 0:
		return selected
	for i in stock.size():
		if stock[i] > 0:
			player.seed_choice = i
			return i
	return selected


func plant_seed(id: int, slot: int) -> bool:
	var player: Dictionary = players[id]
	var kind := selected_seed(player)
	var stock: Array = seed_reserve(player).stock
	if progress.plots[slot].species >= 0:
		return false
	if stock[kind] <= 0:
		tell(id, "Identify seeds at the Altar first.")
		return false
	var before: Dictionary=progress.plots[slot].duplicate(true)
	var planted := Transactions.run_gameplay(self, Transactions.Scope.GARDEN, func():
		stock[kind] -= 1
		progress.plots[slot] = {"species": kind, "age": 0.0, "stage": 0, "flowering": false,"growth_rules":2,"growth_base":float(Seeds.DEFINITIONS[kind].grow_seconds),"care":preload("res://garden_conduit.gd").cycle(progress,slot,kind)}
		progress.sync_plot_flags()
		if has_meta(Transactions.SESSION) or progress.save_garden()==OK: return true
		stock[kind]+=1;progress.plots[slot]=before;progress.sync_plot_flags()
		return false, false)
	if not planted.completed or planted.value != true:
		tell(id,Transactions.feedback(planted,"Planting could not be saved. Your seed was returned."))
		return false
	tell(id,"%s planted."%Progress.PLANT_NAMES[kind])
	return true

func deferred_save_available(id: int) -> bool:
	if not has_meta(Transactions.SESSION): return true
	if Transactions.session_writable(self): tell(id, "This action is unavailable in the guarded session.")
	return false

func save_session_garden() -> bool:
	if has_meta(Transactions.SESSION):
		return Transactions.run_gameplay(self, Transactions.Scope.GARDEN, func(): return true).completed
	return progress.save_garden() == OK

func save_progress(id: int, message: String) -> void:
	if has_meta(Transactions.SESSION):
		if save_session_garden():
			tell(id, message)
		return
	var result := progress.save_garden()
	if result != OK:
		Journal.event("save","garden_failed",{"error":result},"error")
		message += " Save failed (error %d). Use Save Garden to retry." % result
	tell(id, message)
	if id != HOST and result != OK:
		status = "Garden save failed (error %d). Use Save Garden to retry." % result


func refresh_feedback() -> void:
	var pending := not Transactions.pending_notice(self).is_empty()
	if pending and is_instance_valid(planting_menu) and planting_menu.visible:
		planting_view.confirm.disabled = true
	feedback.text = status
	var message_width := feedback.get_theme_font("font").get_string_size(status,
		HORIZONTAL_ALIGNMENT_LEFT, -1, feedback.get_theme_font_size("font_size")).x
	feedback.custom_minimum_size.x = minf(message_width + 2.0, 500.0)
	var fresh_notice := pending or (Time.get_ticks_msec() < toast_until and not status.is_empty())
	toast_panel.z_index = 1 if pending else 0
	toast_panel.visible = fresh_notice and (not overlay.visible or (pending and not session_menu.visible))
	menu_notice.text = status
	menu_notice.visible = fresh_notice

func tell(id: int, message: String) -> void:
	if id == HOST:
		status = message
	elif online_peer != null:
		var pending := Transactions.pending_notice(self)
		receive_message.rpc_id(id, message if pending.is_empty() else pending)


@rpc("authority", "call_remote", "reliable")
func receive_message(message: String) -> void:
	status = message


func combat_pose(player: Dictionary) -> int:
	var facing: Vector3 = player.facing
	var degrees := posmod(roundi(rad_to_deg(atan2(facing.x, facing.z))), 360)
	var swing := clampi(ceili((int(player.swing_until) - Time.get_ticks_msec()) / 10.0), 0, 24)
	return degrees | (swing << 9)


func player_snapshot(viewer: int,include_details: bool=true) -> Dictionary:
	var snapshot := {}
	for id in players:
		var p: Dictionary = players[id]
		var state := {"motion_radius":bound_position(Vector3(1000,0,0)).x,"motion_epoch":net_motion.world_key(self,p),"motion_ack":net_motion.acknowledgement(id,net_motion.world_key(self,p)),"motion_scale":(.4 if Time.get_ticks_msec()<int(p.get("front_guard_until",0)) else 1.0)*(.6 if Time.get_ticks_msec()<int(p.get("slow_until",0)) else 1.0),"velocity":p.get("velocity",Vector3.ZERO),"vitals_revision":p.get("vitals_revision",0),"damage_seq":p.get("damage_seq",0),"damage_amount":p.get("damage_amount",0),"party_slot":p.get("party_slot",0),"display_name":p.character.get("name","Wanderer"),"enemy_max_hp":encounter_health(),"pos": p.pos, "wild": p.wild, "fallen":p.fallen,"lost_health":p.get("lost_health",0), "hp": p.hp, "max_hp": p.get("max_hp", MAX_HEALTH), "appearance": PackedByteArray(p.character.get("appearance", [0,0,0,0,0])), "frame": p.frame,
			"attack_anim":attack_animation_snapshot(p),"skill_fx":p.get("skill_fx",{}) if Time.get_ticks_msec()<int(p.get("skill_fx_until",0)) else {}, "weapon_kind":p.get("weapon_kind",0), "core_part":p.weapon if p.wild else p.prepared, "pose": combat_pose(p), "wallet": run_wallet(p),"skill_ready":Time.get_ticks_msec()>=int(p.skill_at),"skill_two_ready":Time.get_ticks_msec()>=int(p.get("skill_two_at",0)),"skill_cooldowns":[maxf(0,(int(p.skill_at)-Time.get_ticks_msec())/1000.0),maxf(0,(int(p.get("skill_two_at",0))-Time.get_ticks_msec())/1000.0)]}
		if id == viewer and include_details:
			state["core_state"]=preload("res://core_combat.gd").owner_state(p,Time.get_ticks_msec(),get_meta("core_combat",{}).get(id,{}))
			if p.wild:
				state["thief_routes"]=preload("res://thief_escape.gd").snapshot(self)
				state["ability_growth_centers"]=preload("res://class_ability_targeting.gd").growth_centers(self,id)
				if int(p.frame)==0:
					var warden=preload("res://warden_combat.gd")
					var now:=Time.get_ticks_msec()
					state["warden_anchor_point"]=warden.anchor_point(self,p,now)
					state["warden_quake_prepared"]=warden.prepared_until(self,p,now)>0
			state.merge({"weapon": p.weapon, "prepared": p.prepared, "experiment": p.experiment,
				"skill_ready": Time.get_ticks_msec() >= int(p.skill_at),"skill_two_ready":Time.get_ticks_msec()>=int(p.get("skill_two_at",0)),"skill_cooldowns":[maxf(0,(int(p.skill_at)-Time.get_ticks_msec())/1000.0),maxf(0,(int(p.get("skill_two_at",0))-Time.get_ticks_msec())/1000.0)], "dodge_ready": Time.get_ticks_msec() >= int(p.dodge_at), "last_offer": p.last_offer,
				"reclaim_choice":p.get("reclaim_choice",0),"offering_choice":p.get("offering_choice",0),"last_deposit":p.get("last_deposit",0),"weapon_kind":p.weapon_kind,"catalyst":p.catalyst,"graft_part":p.graft_part,"graft_floor":p.get("graft_floor",0),"prepared_catalyst":p.prepared_catalyst,"cargo_plan":p.cargo_plan,"stored_parts":stored_counts(p),"weapon_stats":weapon_stats(p,not p.wild), "carried_parts": p.carried_parts, "reserve_parts": seed_reserve(p).parts,"combat_events":combat_events_snapshot(),"attack_hints":attack_hints_snapshot(),"death_events":death_events_snapshot(),"run_upgrades":p.get("run_upgrades",{}),"bag":InventoryModel.snapshot(self,p),"ground_items":inventory_floor_snapshot(p), "secondary": p.secondary, "prepared_secondary": p.prepared_secondary,
				"garden_interactions":preload("res://garden_interaction_service.gd").projection(self,id),
				"party_travel":PartyTravel.snapshot(self,id),"seed_choice": selected_seed(p), "graft_choice": p.graft_choice, "cache_claimed": p.cache_claimed})
		state.diagnostic_host=Journal.current.session_id if is_instance_valid(Journal.current) else ""
		state.diagnostic_world=diagnostic_watch.world_session if is_instance_valid(diagnostic_watch) else ""
		snapshot[id] = state
	return snapshot


func inventory_snapshot(player: Dictionary) -> Array:
	var reserve := seed_reserve(player)
	return [reserve.unknown.size(), reserve.stock[0], reserve.stock[1], progress.planted,
		reserve.stock[Progress.VEILCAP], selected_donation(player), reserve.stock.duplicate()]


func garden_snapshot() -> Array:
	return [progress.research_points, progress.studying_flowering, progress.flowering_unlocked,
		progress.flowering, progress.harvest_ready, progress.parts, progress.knowledge, progress.veilcap_discovered, progress.briar_hooks,
		progress.studying_rift_hook, progress.rift_research_points, progress.rift_hook_discovered, progress.plot_snapshot(), progress.discoveries.duplicate(), progress.heartwood_barbs, shared_parts_snapshot(), progress.heart.snapshot(progress)]


@rpc("authority", "call_remote", "unreliable_ordered",4)
func receive_state(people: PackedByteArray, enemy: Vector3, hp: int, winding_up: bool, drop: Vector3, dropped: bool, stock: Array, room_depth: int, carried_count: int, protected: bool, garden: PackedByteArray, briar_bound: bool, evolved: bool, campaign_state: PackedInt32Array, pack: PackedByteArray,sequence: int=-1) -> void:
	if not net_view.accept_sequence(sequence):
		if is_instance_valid(Journal.current) and Journal.current.detail:Journal.event("network","stale_snapshot",{"sequence":sequence,"last_sequence":net_view.snapshot_received})
		return
	var decoded_people = bytes_to_var(people.decompress_dynamic(262144, FileAccess.COMPRESSION_DEFLATE))
	if not decoded_people is Dictionary:
		return
	var before_movement: Dictionary=players
	players = decoded_people
	for peer in players: net_view.merge_health(int(peer),players[peer])
	var state_key:=str([campaign_state[0],campaign_state[9],campaign_state[8]])
	var local_id:=multiplayer.get_unique_id()
	if players.has(local_id):
		var public_state: Dictionary=players[local_id]
		players[local_id]=client_details.duplicate(true)
		players[local_id].merge(public_state,true)
	enemy_pos = enemy
	enemy_hp = hp
	enemy_winding_up = winding_up
	drop_pos = drop
	has_drop = dropped
	if not stock.is_empty(): client_inventory = stock
	depth = room_depth
	client_carried_count = carried_count
	client_pouch_filled = protected
	var decoded = bytes_to_var(garden.decompress_dynamic(32768, FileAccess.COMPRESSION_DEFLATE)) if not garden.is_empty() else null
	if decoded is Array and decoded.size() >= 13:
		client_garden = decoded
	client_briar_bound = briar_bound
	longlimb = evolved
	client_campaign = campaign_state
	client_pack = PackedFloat32Array() if pack.is_empty() else (
		pack.decompress_dynamic(4096, FileAccess.COMPRESSION_DEFLATE).to_float32_array())
	destination = campaign_state[0]
	if campaign_state.size() > 18:
		var form := Enemies.decode(campaign_state[18])
		enemy_kind = form.kind
		enemy_mutations = form.mask
		enemy_growth = form.tier
	if campaign_state.size() > EncounterConfig.ATTACK_MODE:
		enemy_landing = Vector3(campaign_state[EncounterConfig.LANDING_X] / 100.0, 0, campaign_state[EncounterConfig.LANDING_Z] / 100.0)
		enemy_attack_mode = "vault" if campaign_state[EncounterConfig.ATTACK_MODE] != 0 else ""
	if campaign_state.size()>EncounterConfig.BOSS_PHASE:
		boss_kind=campaign_state[EncounterConfig.BOSS_KIND];boss_phase=campaign_state[EncounterConfig.BOSS_PHASE]
	map_seed = campaign_state[8]
	encounter_number = campaign_state[9]
	difficulty_cycle = campaign_state[10]
	active_radius = campaign_state[6] / 100.0
	net_motion.receive(self,local_id,before_movement,Time.get_ticks_msec())


func _process(_delta: float) -> void:
	if not Transactions.pending_notice(self).is_empty():
		refresh_feedback()
	if has_meta("guarded_title_session") and not returning_to_title:
		var owner = get_meta("guarded_title_session")
		var renewal: Dictionary = owner.tick()
		if renewal.error != OK:
			_stop_guarded_session("This session lost access to its save. Returning to the title.")
			return
	if multiplayer.is_server(): PartyTravel.validate(self)
	update_network_session()
	if returning_to_title: return
	if not multiplayer.is_server() and client_details.is_empty(): return
	if not has_meta("guarded_title_session") and (slot_claimed or character_slot_claimed) and Time.get_unix_time_from_system() - slot_heartbeat_at >= 1.0:
		var slots := preload("res://save_slots.gd").new()
		slots.root_path = slot_storage_root
		if slot_claimed: slots.heartbeat(active_slot)
		if character_slot_claimed:
			var roster:=preload("res://character_slots.gd").new();roster.root_path=character_storage_root;roster.heartbeat(active_character_slot)
		slot_heartbeat_at = Time.get_unix_time_from_system()
	var local_id := multiplayer.get_unique_id()
	var view_id: int=spectator_view.focus_id(local_id)
	var observer: Vector3=players.get(view_id,{}).get("pos",Vector3.ZERO)
	var local_player: Dictionary = players.get(local_id, {})
	var data: Array = inventory_snapshot(local_player) if multiplayer.is_server() and not local_player.is_empty() else client_inventory
	var visible_drop: bool = local_player.get("loot_pending", false) if multiplayer.is_server() else has_drop
	var briar_bound := Time.get_ticks_msec() < rooted_until if multiplayer.is_server() else client_briar_bound
	var campaign_state := campaign_snapshot() if multiplayer.is_server() else client_campaign
	var visual_field: RefCounted = battlefield if multiplayer.is_server() else stage.visual_field
	if multiplayer.is_server(): stage.visual_field=battlefield
	var rendered_players: Dictionary=players if multiplayer.is_server() else net_motion.render_players(players,local_id,Time.get_ticks_msec())
	if not multiplayer.is_server():rendered_players=preload("res://avatar_motion_view.gd").people(rendered_players,local_id,mouse_controls.local_aim)
	var p: Dictionary = local_player
	var wild: bool = p.get("wild", false)
	var warnings: Array=attack_hints_snapshot() if multiplayer.is_server() and wild else p.get("attack_hints",[]) if wild else []
	if not multiplayer.is_server() and client_details_key!=str([destination,encounter_number,map_seed]):
		warnings=warnings.filter(func(hint): return hint.role not in ["core_thorns","core_anchor","core_field","core_lured","glasscap_feint"])
	preload("res://glasscap_visuals.gd").prepare(stage,warnings)
	stage.set_meta("enemy_attack_poses",preload("res://enemy_attack.gd").poses(warnings))
	stage.draw_state(rendered_players, local_id, enemy_pos, enemy_hp, enemy_winding_up, strike_radius(), drop_pos, visible_drop, data[3], depth, route_rooms(), graft_altar_open(), briar_bound, longlimb, campaign_state,
		scout_snapshot(Time.get_ticks_msec()) if multiplayer.is_server() else client_pack, _delta,view_id)
	update_ready_panel(p,local_id)
	death_visuals.sync(death_events_snapshot() if multiplayer.is_server() and wild else p.get("death_events",[]) if wild else [],"%d:%d:%d:%s"%[destination,encounter_number,map_seed,str(wild)],observer)
	var presentation_key := "%d:%d:%d:%s"%[destination,encounter_number,map_seed,str(wild)]
	var events := combat_events_snapshot() if multiplayer.is_server() else guest_combat_events(p)
	get_node("EventAudio").sync(events,presentation_key,wild,observer,local_id,Time.get_ticks_msec())
	combat_visuals.sync(events if wild else [],warnings,presentation_key,observer)
	stage.attack_ring.visible=false
	for ring in stage.support_rings: ring.visible=false
	exploration.thief_routes=preload("res://thief_escape.gd").map_routes(self,p) if wild else []
	exploration.update_floor(stage.visual_field, "%d:%d:%d" % [destination, encounter_number, map_seed],
		observer, stage.camera, wild, drop_pos, visible_drop,
		not p.get("cache_claimed", false) and destination != Campaign.HEART, overlay.visible, graft_altar_open(),inventory_floor_snapshot(p) if multiplayer.is_server() else p.get("ground_items",[]))
	stage.apply_exploration_sight(observer, wild, exploration.SIGHT)
	preload("res://glasscap_visuals.gd").sync(stage,observer,exploration.SIGHT)
	var carried: int = p.carried_seeds.size() if multiplayer.is_server() and wild else client_carried_count
	title.text = "%s  ·  Encounter %d" % [Campaign.NAMES[destination], encounter_number] if wild else "Mystical Garden"
	var health: float = p.get("hp", 0)
	health_label.text = "♥".repeat(int(ceil(health / 2.0)))
	skill_label.text = ""
	skill_label.hide()
	detail_label.text = ""
	inventory.text = "Mysterious seeds     %d\nThorn Bloom             %d\nLantern Moss           %d\nVeilcap                       %d" % [
		data[0], data[1], data[2], data[4]]
	if wild:
		if not encounter_cleared():
			var pack := scout_snapshot(Time.get_ticks_msec()) if multiplayer.is_server() else client_pack
			var alive := int(enemy_hp > 0)
			var hatching: bool=boss_kind==22 and warnings.any(func(hint):return hint.role=="nursery_exit")
			var warning := not hatching and enemy_winding_up and (enemy_landing if enemy_attack_mode == "vault" else enemy_pos).distance_to(p.pos) < strike_radius() + 0.7
			for i in range(2, pack.size(), PACK_STRIDE):
				alive += int(pack[i] > 0.0)
				var impact := Vector3(pack[i + 4], 0, pack[i + 5])
				var slot := (i - 2) / PACK_STRIDE
				var code := campaign_state[19 + slot] if campaign_state.size() > 19 + slot else 0
				var form := Enemies.decode(code)
				var radius := Enemies.radius(int(form.kind), int(form.mask))
				warning = warning or (Enemies.get_kind(form.kind).role != "chant" and pack[i] > 0.0 and pack[i + 1] > 0.0 and impact.distance_to(p.pos) < radius + 0.7)
			for hint in warnings:
				if hint.role=="charge":
					var a:=Vector3(hint.from[0],0,hint.from[2]);var b:=Vector3(hint.to[0],0,hint.to[2])
					warning=warning or p.pos.distance_to(Geometry3D.get_closest_point_to_segment(p.pos,a,b))<=float(hint.width)+.4
			guide.text = "Dodge out of the marked attack!" if warning else "Stand at a hatch site to block it." if hatching else ""
			skill_label.text = "%d foes remaining" % alive if alive > 1 or enemy_hp == 0 else (
				"%s  %d/%d" % [enemy_name(), enemy_hp, encounter_health()])
		elif visible_drop:
			guide.text = "E  Collect seeds"
		else:
			if depth < route_rooms():
				guide.text = "E  Continue"
			else:
				guide.text = "Continue to %s" % Campaign.NAMES[(destination + 1) % Campaign.HEART]
		if upgrade_checkpoint_open() and p.get("last_offer",0)!=encounter_number:
			guide.text="E  Choose an upgrade" if visual_field.advance.distance_to(p.pos)<=preload("res://gate_interaction.gd").RANGE else "Upgrades await at the gate"
		if extraction_checkpoint_open() and visual_field.advance.distance_to(p.pos) <= preload("res://gate_interaction.gd").RANGE:
			guide.text = "E  Continue    ·    T  Extract to the Garden"
			detail_label.text = "Extract or continue."
			if p.get("last_offer", 0) != encounter_number:
				detail_label.text += "\nE  Choose upgrade cards   ·   %d essence available" % (run_wallet(p) if multiplayer.is_server() else int(p.get("wallet", 0)))
		if visual_field.procedural and not p.get("cache_claimed", false) and (
				visual_field.cache.distance_to(p.pos) <= 1.55 and destination != Campaign.HEART):
			guide.text = "E  Search the abandoned clearing"
		if graft_altar_open() and visual_field.graft.distance_to(p.pos) <= 1.65 and preload("res://gate_interaction.gd").shrine_preferred(visual_field,p.pos):
			guide.text="E  Graft"
			detail_label.text="Installed: %s · Replace at a later altar"%Parts.part_name(int(p.get("graft_part",0))) if int(p.get("graft_part",0))!=0 else "Choose a monster part to graft."
		var protected: bool = p.pouch if multiplayer.is_server() else client_pouch_filled
		inventory.text += "\n\nCarried seeds   %d  |  Safe pouch   %d/1" % [carried, int(protected)]
		var wallet: int = run_wallet(p) if multiplayer.is_server() else p.wallet
		inventory.text += "\nRun currency     %d" % wallet
		var frame: Dictionary = Frames.DEFINITIONS[p.frame]
		var skill_ready: bool = Time.get_ticks_msec() >= int(p.skill_at) if multiplayer.is_server() else p.skill_ready
		inventory.text += "\n\n%s: %s + %s" % [frame.weapon, Parts.part_name(p.weapon), Parts.part_name(p.secondary)]
		skill_label.text += ("\n" if not skill_label.text.is_empty() else "") + "Q  %s%s" % [
			Skills.resolve(int(p.frame),0,p.get("character",guest_character.data)).name, "" if skill_ready else " · recovering"]
		if difficulty_cycle > 0:
			skill_label.text += "\nCorruption %d" % (difficulty_cycle + 1)
			if not encounter_cleared() and int(campaign_state[11])>0:
				skill_label.text += "  ·  Reinforcements in %ds" % campaign_state[11]
		skill_label.show()
		session_label.text = "%s  ·  %d player(s)" % [session, players.size()]
	else:
		guide.text = ""
	if not wild:
		var garden := garden_snapshot() if multiplayer.is_server() else client_garden
		var near_gate := Stage.GATE.distance_to(p.get("pos", Vector3.ZERO)) <= preload("res://gate_interaction.gd").RANGE
		inventory.text += "\n\nShared parts\nThorn %d  ·  Moss %d  ·  Veilcap %d  ·  Hooks %d" % [
			garden[5][0], garden[5][1], garden[5][2], garden[8]]
		inventory.text += "\n\nHeart restoration  ·  Knowledge %d/%d" % [garden[6], Campaign.FULL_KNOWLEDGE]
		for site in Campaign.HEART:
			inventory.text += "\n%s memories   %d/%d" % [
				Campaign.NAMES[site], campaign_state[14 + site], Campaign.MEMORY_REQUIREMENTS[site]]
		inventory.text += "\nFlowering: %s  ·  Veilcap: %s  ·  Rift Hook: %s" % [
			"Known" if garden[2] else "Open", "Known" if garden[7] else "Open", "Known" if garden[11] else "Open"]
		var slot := nearby_plot(p.get("pos", Vector3.ZERO))
		var beds := Progress.decode_plots(garden[12])
		if slot >= 0 and slot < beds.size():
			var bed: Dictionary = beds[slot]
			if bed.species >= 0:
				guide.text = "E  Harvest %s" % ("seed" if bed.flowering else "crafting parts") if bed.stage == 3 else "%s · %s" % [Progress.PLANT_NAMES[bed.species], ["Seed", "Sprout", "Young", "Mature"][bed.stage]]
				if bed.flowering and bed.stage < 3:
					guide.text += " · Seed crop"
				if garden[2] and not bed.flowering:
					guide.text += "  |  F  Harvest seeds instead" if int(bed.stage)==3 else "  |  Seeds can be harvested when mature"
			else:
				var choice := selected_seed(p) if multiplayer.is_server() else int(p.get("seed_choice", 0))
				guide.text = "Living offshoot · care at the Heart" if int(bed.get("offshoot",-1))>=0 else "E  Choose a seed to plant"
		elif Stage.ALTAR.distance_to(p.get("pos", Vector3.ZERO)) <= 1.65:
			guide.text="E  Altar"
			detail_label.text="Identify seeds · Combine seeds or plant parts"
		elif near_gate:
			guide.text="E  Wilds Gate"
		elif at_heart(p):
			guide.text="E  Heart"

	if wild and can_checkpoint_bank(p):
		detail_label.text+="\nJ · Send one carried find home"
	get_node("GardenInteractions").update_prompt(p)
	var rescue_id:=Life.nearest(self,p)
	if rescue_id!=0:
		var ally: Dictionary=players[rescue_id]
		var can_revive:=Life.Vitals.can_revive(int(ally.get("max_hp",Life.Preview.hp(MAX_HEALTH))),Life.Preview.scale())
		var cost: String="%d maximum HP"%Life.Preview.revive_cost() if Life.Preview.enabled else "1 maximum heart"
		guide.text="E  Revive %s · costs them %s"%[ally.get("display_name",ally.get("character",{}).get("name","ally")),cost] if can_revive else ("This ally has too little maximum health to revive." if Life.Preview.enabled else "This ally has no full heart left to sacrifice.")
	if p.get("fallen",false) and wild: guide.text="Fallen · awaiting revival"
	var ground_id:=nearest_inventory_drop(p) if multiplayer.is_server() else nearest_visible_inventory_drop(p)
	if not ground_id.is_empty() and rescue_id==0 and not p.get("fallen",false): guide.text="E  Pick up item"
	if deposit_button!=null: deposit_button.disabled=not can_checkpoint_bank(p)
	if abandon_button!=null: abandon_button.disabled=not wild
	if multiplayer.is_server() and not expedition_active(): consider_recollection()
	refresh_feedback()

	if not wild:
		var ending := ending_message(campaign_state[5])
		session_label.text = ending if not ending.is_empty() else "%s  |  %d player(s)" % [session, players.size()]
		session_label.text += "\nDeepest clear %d  ·  Best extraction %d" % [campaign_state[12], campaign_state[13]]
	detail_label.visible = not detail_label.text.is_empty()
	prompt_panel.visible = not overlay.visible and (not guide.text.is_empty() or detail_label.visible)
	host_button.text = "Share Join Address" if session=="Host" else "Host Co-op"
	host_button.disabled = session not in ["Host","Solo"] or (session=="Solo" and wild)
	join_button.disabled = session != "Solo" or wild
	if has_meta("developer_garden"):
		host_button.disabled=true
		join_button.disabled=true
		session_label.text="Developer Garden · Single player"
	leave_button.disabled = session == "Solo"
	save_button.disabled = not multiplayer.is_server()
	var shared := garden_snapshot() if multiplayer.is_server() else client_garden
	stage.update_plots(Progress.decode_plots(shared[12]))
	stage.update_heart_progress(heart_state())
	get_node("Soundscape").update_mix(_delta,wild,destination,encounter_number,boss_kind>=0,observer,stage.heart_unlocked)
	stage.update_garden(int(shared[6]), int(shared[2]) + int(shared[7]) + int(shared[11]) + int(heart_state().get("clearing",0)))
	var host_side := multiplayer.is_server()
	var ready_skill := Time.get_ticks_msec() >= int(p.get("skill_at", 0)) if host_side else bool(p.get("skill_ready", false))
	var second_ready: bool=Time.get_ticks_msec()>=int(p.get("skill_two_at",0)) if host_side else bool(p.get("skill_two_ready",false))
	var skills: Array=[Skills.resolve(int(p.get("frame",0)),0,p.get("character",guest_character.data)),Skills.resolve(int(p.get("frame",0)),1,p.get("character",guest_character.data))]
	var cooldowns: Array=[maxf(0,(int(p.get("skill_at",0))-Time.get_ticks_msec())/1000.0),maxf(0,(int(p.get("skill_two_at",0))-Time.get_ticks_msec())/1000.0)] if host_side else p.get("skill_cooldowns",[0.0,0.0])
	var skill_tips: Array=Skills.wild_tooltips(self,p,skills) if wild and Life.Preview.enabled else [skills[0].name+"\n"+skills[0].description,skills[1].name+"\n"+skills[1].description]
	var quake_prepared:=false
	if skills[0].has("warden_focus"):
		var warden=preload("res://warden_combat.gd")
		quake_prepared=warden.prepared_until(self,p,Time.get_ticks_msec())>0 if host_side else bool(p.get("warden_quake_prepared",false))
		if quake_prepared:skill_tips[1]+="\nQuake prepared."
	if skills[0].has("warden_focus") or skills[0].has("subclass_focus"):
		for slot in 2:
			var purchased:=Classes.Warden.card_lines(p,slot) if int(p.frame)==0 else Classes.Subclasses.card_lines(p,slot)
			if not purchased.is_empty():skill_tips[slot]+="\n"+purchased
	var ready_dodge := Time.get_ticks_msec() >= int(p.get("dodge_at", 0)) if host_side else bool(p.get("dodge_ready", false))
	if session=="Host": session_label.text+="\nHosting on UDP %d"%network_port
	appearance_button.disabled = wild
	var look: Array = Array(p.get("character", {}).get("appearance", p.get("appearance", [0, 0, 0, 0, 0])))
	for i in appearance_options.size():
		var option_values: Array = LOOK_NAMES[i]
		var choice: int = clampi(int(look[i]) if i < look.size() else 0, 0, option_values.size() - 1)
		appearance_options[i].text = "%s: %s" % [["Cloak", "Tunic", "Hair color", "Hair style", "Skin"][i], option_values[choice]]
		appearance_options[i].disabled = wild
	player_hud.set_chart_expanded(exploration.expanded)
	player_hud.update_state({"party":preload("res://party_hud.gd").members(players,local_id),
		"location": Campaign.NAMES[destination] if wild else "Mystical Garden", 
		"floor":encounter_number,
		"encounter": "%d foes" % [int(enemy_hp > 0) + living_scout_count()] if wild else "Your living sanctuary",
		"damage_flash":maxf(0,(int(p.get("hurt_until",0) if host_side else p.get("client_hurt_until",0))-Time.get_ticks_msec())/250.0),"hp": health, "max_hp": p.get("max_hp", MAX_HEALTH), "lost_health":p.get("lost_health",0),"fallen":p.get("fallen",false), "wild": wild, "frame": p.get("frame", 0),
		"skill_ready": ready_skill,"skill_two_ready":second_ready,"skill_names":[skills[0].name,skills[1].name+(" •" if quake_prepared else "")],"skill_cooldowns":cooldowns, "dodge_ready": ready_dodge,
		"core":preload("res://core_combat.gd").hud_state(self,p),
		"skill_tooltips":skill_tips,
		"carried": carried if wild else data[0],
		"pouch": p.get("pouch", false) if host_side else client_pouch_filled,
		"wallet": run_wallet(p) if host_side and wild else int(p.get("wallet", 0)) if wild else 0,
		"insight":heart_state().get("insight",0), "knowledge": shared[6]})


func living_scout_count() -> int:
	if multiplayer.is_server():
		var count := 0
		for scout in scouts:
			count += int(scout.hp > 0)
		return count
	var count := 0
	for i in range(2, client_pack.size(), PACK_STRIDE):
		count += int(client_pack[i] > 0)
	return count



func request_main_menu() -> void:
	if expedition_active() and session in ["Solo","Host"]:
		title_confirmation.popup_centered(Vector2i(480,180))
	else:
		return_to_main_menu()


func on_server_disconnected() -> void:
	Journal.event("network","on_server_disconnected",{},"warning")
	if session=="Connecting" or (session=="Guest" and get_meta("join_phase","")=="garden"):
		connection_rejected(Network.join_failure(get_meta("join_phase","connect"),network_address,network_port,false))
	elif session=="Guest":
		leave_game("Host disconnected. Your character progress is preserved.")


func on_connection_failed() -> void:
	Journal.event("network","on_connection_failed",{},"warning")
	if network_compatibility!=null and not network_compatibility.failure_reason.is_empty():
		connection_rejected(network_compatibility.failure_reason);return
	connection_rejected(Network.join_failure(get_meta("join_phase","connect"),network_address,network_port,false))


func return_to_main_menu(message: String = "") -> void:
	if returning_to_title:
		return
	returning_to_title = true
	if has_meta(Transactions.SESSION) and not Transactions.session_writable(self):
		_stop_guarded_session("This session lost access to its save. Returning to the title.")
		return
	if session in ["Solo","Host"] and not joined_from_title and (not has_meta("guarded_title_session") or slot_claimed):
		if expedition_active() and has_meta(Transactions.SESSION):
			# Exit without replaying the deferred expedition settlement.
			_stop_guarded_session("Returned to the title. Expedition settlement is unavailable in the guarded session.")
			return
		if expedition_active():
			finish_failed_expedition()
			for player in players.values():
				if player.wild:
					return_to_garden(player)
		if not save_session_garden():
			returning_to_title = false
			if not has_meta(Transactions.SESSION): status = "Could not save this Garden. Use Save Garden before leaving."
			return
	if character_dirty and not save_local_character():
		returning_to_title = false
		return
	_finish_title_return(message)

func _stop_guarded_session(message: String) -> void:
	if get_meta(Transactions.STOPPING, false): return
	set_meta(Transactions.STOPPING, true)
	returning_to_title = true
	process_mode = Node.PROCESS_MODE_DISABLED
	set_process(false)
	set_physics_process(false)
	_finish_title_return.call_deferred(message)

func _finish_title_return(message: String) -> void:
	if has_meta(Transactions.SESSION): set_meta(Transactions.STOPPING, true)
	if online_peer != null:
		online_peer.close()
		online_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	release_slot()
	if network_dialog.visible:
		network_dialog.dismiss()
	var menu = load("res://main_menu.tscn").instantiate()
	menu.guarded_persistence = has_meta("guarded_title_session")
	menu.settings_path=settings_path
	var dev_return: Dictionary=get_meta("developer_garden",{})
	menu.storage.root_path = dev_return.get("root",slot_storage_root)
	menu.import_legacy = menu.storage.root_path == "user://saves"
	menu.restore_last_selection = false
	menu.selected = dev_return.get("slot",maxi(0,active_slot))
	menu.selected_character=dev_return.get("character",maxi(0,active_character_slot))
	menu.restore_last_character=false
	var pending := Transactions.pending_notice(self)
	menu.return_message = message if pending.is_empty() else pending
	if not pending.is_empty(): menu.set_meta(&"guarded_return_notice", pending)
	if joined_from_title or session=="Connecting" or get_meta("join_phase","")=="garden":
		menu.set_meta("join_return",{"address":network_address,"port":network_port,"open":not get_meta("join_cancelled",false)})
	set_process(false)
	set_physics_process(false)
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	queue_free()


func release_slot() -> void:
	if has_meta("guarded_title_session"):
		get_meta("guarded_title_session").release()
		character_slot_claimed = false
		slot_claimed = false
		return
	if character_slot_claimed and active_character_slot>=0:
		var roster:=preload("res://character_slots.gd").new();roster.root_path=character_storage_root;roster.release(active_character_slot);character_slot_claimed=false
	if slot_claimed and active_slot >= 0:
		var slots := preload("res://save_slots.gd").new()
		slots.root_path = slot_storage_root
		slots.release(active_slot)
		slot_claimed = false


func _exit_tree() -> void:
	release_slot()


func current_mutations(kind: int, growth: int, stamp: int) -> int:
	var gain := 2 if encounter_number >= 10 else 0
	var older_pressure: Dictionary={"ranged":progress.ranged_pressure+ranged_clears*gain,
		"burst":progress.burst_pressure+burst_clears*gain,"choke":progress.choke_pressure+choke_clears*gain}
	var traits:=Enemies.mutations(kind,growth,0,0,0,encounter_number,stamp)
	traits|=Learning.traits(progress.wilds_memory,encounter_number,stamp,older_pressure)
	if kind==0 and ((depth>=2 and progress.ranged_pressure>=3 and depth%2==0) or (depth>=4 and ranged_clears>=2)): traits|=Enemies.REACH
	return Learning.bounded(traits,encounter_number,stamp)
func build_progression_panel() -> void:
	progression_menu = hud_panel(overlay, Color("#14262b"), Vector2(20,14))
	progression_view = preload("res://progression_panel.gd").new()
	progression_view.game = self
	progression_menu.add_child(progression_view)

func weapon_stats(player: Dictionary, prepared: bool=false) -> Dictionary:
	var slots: Array=[player.get("prepared",0),player.get("prepared_secondary",0),player.get("prepared_catalyst",0)] if prepared else [player.get("weapon",0),player.get("secondary",0),player.get("catalyst",0)]
	var result:=Weapons.resolve(int(player.get("frame",0)),int(player.get("weapon_kind",0)),slots,0 if prepared else int(player.get("graft_part",0)),int(player.get("technique",0)),player.get("character",guest_character.data))
	if not prepared and player.get("wild",false):
		Weapons.add_effects(result,RunUpgrades.effects(player))
		var core: Dictionary=result.core_build.skill
		if not core.is_empty():
			RunUpgrades.tune_core(player,core)
			var cards:=RunUpgrades.core_card_lines(player,core.id)
			if not cards.is_empty(): core.cards=cards
		result.damage=maxf(1.0,float(result.damage)) if Life.Preview.enabled else maxi(1,roundi(float(result.damage)))
		result.targets=clampi(int(result.targets),1,5)
		if result.targets>1 and result.pattern=="single": result.pattern="sweep" if int(player.frame) in [0,3] else "chain"
		result.interval=maxi(230,int(result.strike_ms)-int(result.cooldown))
		for key in ["recovery","stagger","skill_cooldown","skill_duration","dodge_cooldown","windup_damage"]:
			if result.has(key) and (key!="windup_damage" or not Life.Preview.enabled): result[key]=roundi(float(result[key]))
		result.max_health=Life.Preview.capped_amount(float(result.get("max_health",0)),12)
		result.heal_on_kill=Life.Preview.capped_amount(float(result.get("heal_on_kill",0)),3)
		if Life.Preview.enabled and result.heal_on_kill>0:
			result["kill_heal_remaining"]=Life.Sustain.kill_remaining(player,combat_epoch)
		result.skill_heal=Life.Preview.capped_amount(float(result.get("skill_heal",0)),4)
	if not prepared and player.get("wild",false) and Time.get_ticks_msec()<int(player.get("focus_until",0)):
		result.targets=mini(5,int(result.targets)+1)
		result.interval=maxi(230,int(result.interval)-60)
		if result.pattern=="single": result.pattern="chain"
		result.interactions.append("Gale Focus")
	if Life.Preview.enabled:
		var strike_power := int(player.get("power",0)) if not prepared and player.get("wild",false) else 0
		result["class_power"]=strike_power
		var band:=Life.Preview.weapon_range(result,strike_power)
		result.damage_min=band.x;result.damage_max=band.y
	return result

func shared_parts_snapshot() -> Array:
	var result:=Parts.empty_counts()
	for part in range(1,result.size()): result[part]=progress.part_count(part)
	return result

func stored_counts(player: Dictionary) -> Array:
	return LoadoutMaterials.available(self,player)

func restore_class_loadout(player: Dictionary) -> void:
	var profile: Dictionary=player.character
	player.frame=int(profile.get("active_class",0))
	var loadout: Dictionary=profile.loadouts[player.frame]
	player.weapon_kind=int(loadout.weapon)
	player.prepared=int(loadout.parts[0])
	player.prepared_secondary=int(loadout.parts[1])
	player.prepared_catalyst=int(loadout.parts[2])
	player.max_hp=Life.Preview.hp(MAX_HEALTH+int(Classes.bonuses(profile,int(player.frame)).get("max_health",0)))
	player.hp=minf(float(player.get("hp",player.max_hp)),float(player.max_hp))

func persist_loadout(id: int,player: Dictionary) -> void:
	if has_meta(Transactions.SESSION): return
	player.character.active_class=int(player.frame)
	player.character.loadouts[player.frame]={"weapon":int(player.weapon_kind),"parts":[int(player.prepared),int(player.prepared_secondary),int(player.prepared_catalyst)]}
	publish_character(id)

func select_class(id: int,player: Dictionary,class_id: int) -> void:
	if not deferred_save_available(id): return
	if class_id<0 or class_id>=Classes.DEFINITIONS.size() or not ((at_heart(player) and not expedition_active()) or at_weapon_gate(player)): return
	player.loadout_reserving=false
	player.character.active_class=class_id
	restore_class_loadout(player)
	if at_weapon_gate(player):
		LoadoutMaterials.reconcile(player,stored_counts(player));player.loadout_reserving=true
	player.hp=float(player.max_hp)
	persist_loadout(id,player)
	tell(id,"%s selected."%Classes.DEFINITIONS[class_id].name)

func handle_loadout_action(id: int,player: Dictionary,action: String) -> void:
	if not action.begins_with("pack_") and action != "clearpack" and not deferred_save_available(id): return
	var allowed: bool
	if action.begins_with("learn_"):
		allowed=preload("res://class_tree_access.gd").can_learn_here(self,player)
	elif action.begins_with("respec_"):
		allowed=at_heart(player) and not expedition_active()
	else:
		allowed=at_weapon_gate(player) or (action.begins_with("class_") and at_heart(player))
	if not allowed:
		tell(id,"Learn class upgrades at the Heart or Wilds Gate between expeditions." if action.begins_with("learn_") else "Refund class points at the Heart between expeditions." if action.begins_with("respec_") else "Prepare weapons at the Wilds Gate.")
		return
	var fields:=action.split("_")
	for field in fields.slice(1):
		if not field.is_valid_int(): return
	match fields[0]:
		"class":
			if fields.size()==2: select_class(id,player,int(fields[1]))
		"loadweapon":
			if fields.size()==2 and int(fields[1])>=0 and int(fields[1])<Classes.DEFINITIONS[int(player.frame)].weapons.size():
				player.weapon_kind=int(fields[1])
				persist_loadout(id,player)
		"loadpart":
			if fields.size()!=3: return
			LoadoutMaterials.reconcile(player,stored_counts(player))
			var slot:=int(fields[1])
			var part:=int(fields[2])
			if slot<0 or slot>2 or (part!=0 and not Parts.is_plant(part)): return
			if part!=0 and LoadoutMaterials.remaining(stored_counts(player),LoadoutMaterials.choices(player),slot,part)<=0:
				tell(id,"That material is unavailable or already assigned to another weapon slot.")
				return
			player[["prepared","prepared_secondary","prepared_catalyst"][slot]]=part
			player.loadout_reserving=true
			persist_loadout(id,player)
		"pack":
			if fields.size()!=2: return
			var part:=int(fields[1])
			var total:=0
			for count in player.cargo_plan: total+=int(count)
			if Parts.is_monster(part) and total<monster_cargo_limit() and int(stored_counts(player)[part])>int(player.cargo_plan[part]):
				player.cargo_plan[part]+=1
				player.loadout_reserving=true
				tell(id,"Packed %s. Graft at a Wilds altar."%Parts.part_name(part))
		"clearpack": player.cargo_plan.fill(0)
		"learn":
			if fields.size()!=3: return
			var c:=int(fields[1])
			var node:=int(fields[2])
			if Classes.can_learn(player.character,c,node,Character.level(int(player.character.xp[c])) if c>=0 and c<Classes.DEFINITIONS.size() else 0):
				player.character.upgrades[c] |= 1 << node
				restore_class_loadout(player)
				publish_character(id)
				tell(id,"Learned %s."%Classes.all_nodes(c)[node].name)
		"respec":
			if fields.size()==2 and int(fields[1])>=0 and int(fields[1])<Classes.DEFINITIONS.size():
				player.character.upgrades[int(fields[1])]=0
				restore_class_loadout(player)
				publish_character(id)
				tell(id,"Class points refunded. Choose a new path before the next expedition.")

func has_rift_loadout(player: Dictionary) -> bool:
	return [player.get("weapon",0),player.get("secondary",0),player.get("catalyst",0)].has(Parts.VEIL) and int(player.get("graft_part",0))==Parts.HOOK

func build_loadout_panel() -> void:
	loadout_menu=hud_panel(overlay,Color("#14262b"),Vector2(20,14))
	loadout_view=preload("res://loadout_panel.gd").new()
	loadout_view.game=self
	loadout_menu.add_child(loadout_view)





func update_support_effects(now: int) -> void:
	for player in players.values():
		if Life.alive(player) and now<int(player.get("renewal_until",0)) and now>=int(player.get("renewal_tick",0)):
			Life.Sustain.renewal_tick(self,player)
			player.renewal_tick=now+Skills.Balance.RENEWAL_INTERVAL_MS


func heart_state() -> Dictionary:
	if multiplayer.is_server(): return progress.heart.snapshot(progress)
	if client_garden.size()>16 and client_garden[16] is Dictionary: return client_garden[16]
	return {"unlocked":["heart"],"paid":[],"active":"","progress":{},"natural":{},"infused":{},"spent":0,"insight":0,"phase":0,"clearing":0}

func monster_cargo_limit() -> int:
	return Weapons.MONSTER_CARGO_LIMIT+(2 if heart_state().get("unlocked",[]).has("spore_bench") else 0)

func at_garden_station(player: Dictionary,id: String) -> bool:
	if player.is_empty() or player.get("wild",false) or player.get("fallen",false) or expedition_active() or not travel_kind.is_empty():
		return false
	return Stage.HEART_STATIONS.has(id) and heart_state().get("unlocked",[]).has(id) and Stage.HEART_STATIONS[id].distance_to(player.get("pos",Vector3.INF))<=1.8

func show_heart_tree(id: int) -> void:
	if id==HOST:
		open_heart_tree()
	elif online_peer!=null:
		open_heart_tree.rpc_id(id)

@rpc("authority","call_remote","reliable")
func open_heart_tree() -> void:
	progression_view.tabs.current_tab=1
	progression_view.refresh()
	toggle_overlay(progression_menu)
	progression_view.request_tree_base()

func reclamation_species(player: Dictionary) -> int:
	var selected:=clampi(int(player.get("reclaim_choice",0)),0,Seeds.NAMES.size()-1)
	var known: Array=progress.discoveries if multiplayer.is_server() else client_garden[13] if client_garden.size()>13 else Seeds.counts(false)
	if known[selected]: return selected
	for i in Seeds.NAMES.size():
		if known[i]: return i
	return selected

func reclamation_cost(kind: int) -> int:
	return 2+int(Seeds.DEFINITIONS[kind].tier)

func cycle_reclamation(player: Dictionary) -> void:
	var start:=int(player.get("reclaim_choice",0))
	var known: Array=progress.discoveries if multiplayer.is_server() else heart_state().get("discoveries",[])
	for step in range(1,Seeds.NAMES.size()+1):
		var kind: int=(start+step)%Seeds.NAMES.size()
		if kind<known.size() and known[kind]:
			player.reclaim_choice=kind
			return

func reclaim_seed(id: int,player: Dictionary) -> void:
	if not deferred_save_available(id): return
	if not at_garden_station(player,"seed_archive"): return
	var kind:=reclamation_species(player)
	if not progress.discoveries[kind]:
		tell(id,"Discover a species before reclaiming its seed.")
		return
	var part:=int(Seeds.DEFINITIONS[kind].part)
	var cost:=reclamation_cost(kind)
	if stored_counts(player)[part]<cost:
		tell(id,"Need %d matching %s parts."%[cost,Seeds.NAMES[kind]])
		return
	var reserve:=seed_reserve(player)
	var personal:=mini(int(reserve.parts[part]),cost)
	reserve.parts[part]-=personal
	progress.add_parts(part,-(cost-personal))
	reserve.stock[kind]+=1
	if progress.save_garden()!=OK:
		reserve.parts[part]+=personal
		progress.add_parts(part,cost-personal)
		reserve.stock[kind]-=1
		tell(id,"Could not save reclamation. Materials were returned.")
		return
	tell(id,"Reclaimed one %s seed."%Seeds.NAMES[kind])

func selected_offering(player: Dictionary) -> int:
	var part:=int(player.get("offering_choice",0))
	var counts: Array=stored_counts(player) if multiplayer.is_server() else player.get("stored_parts",Parts.empty_counts())
	if Parts.is_monster(part) and counts[part]>0: return part
	return next_monster_part(0,counts)

func offer_monster(id: int,player: Dictionary) -> void:
	if not deferred_save_available(id): return
	if not at_garden_station(player,"monster_studies"): return
	var part:=selected_offering(player)
	if part==0: tell(id,"Bring a stored monster trophy.");return
	var reserve:=seed_reserve(player)
	var personal: bool=int(reserve.parts[part])>0
	if personal: reserve.parts[part]-=1
	else: progress.add_parts(part,-1)
	var fresh: bool=not progress.heart.offered.has(part)
	var reward:=4 if fresh else 1
	if fresh: progress.heart.offered.append(part)
	progress.knowledge+=reward
	if progress.save_garden()!=OK:
		if personal: reserve.parts[part]+=1
		else: progress.add_parts(part,1)
		progress.knowledge-=reward
		if fresh: progress.heart.offered.erase(part)
		tell(id,"Could not save offering. The trophy was returned.")
		return
	tell(id,"Offered %s. The Heart gained %d Knowledge."%[Parts.part_name(part),reward])

func can_checkpoint_bank(player: Dictionary) -> bool:
	return not player.is_empty() and player.get("wild",false) and upgrade_checkpoint_open() and heart_state().get("unlocked",[]).has("checkpoint_deposit") and player.get("pos",Vector3.INF).distance_to(battlefield.advance if multiplayer.is_server() else stage.visual_field.advance)<=preload("res://gate_interaction.gd").RANGE and int(player.get("last_deposit",0))!=encounter_number

func open_deposit_menu() -> void:
	var id: int=HOST if multiplayer.is_server() else multiplayer.get_unique_id()
	var player: Dictionary=players.get(id,{})
	if not can_checkpoint_bank(player):
		status="The courier needs Returning Mycelium and a cleared checkpoint gate. One item may be sent per checkpoint."
		return
	deposit_pick.clear()
	var seeds: int=player.carried_seeds.size() if multiplayer.is_server() else client_carried_count
	for i in seeds: deposit_pick.add_item("Mysterious seed %d"%(i+1),i)
	for part in range(1,Parts.DEFINITIONS.size()):
		if player.get("carried_parts",Parts.empty_counts())[part]>0:
			deposit_pick.add_item(Parts.part_name(part),1000+part)
	toggle_overlay(deposit_menu)

@rpc("authority","call_remote","reliable")
func show_checkpoint_deposit() -> void:
	open_deposit_menu()

func bank_checkpoint_item(id: int,player: Dictionary,action: String) -> void:
	if not deferred_save_available(id): return
	if not can_checkpoint_bank(player): return
	var fields:=action.split("_")
	if fields.size()!=3 or not fields[2].is_valid_int(): return
	var index:=int(fields[2])
	var return_before: Dictionary=progress.garden_interactions.duplicate(true)
	var reserve:=seed_reserve(player)
	var old_pouch: bool=player.pouch
	var seed: int=-1
	if fields[1]=="seed":
		if index<0 or index>=player.carried_seeds.size(): return
		seed=int(player.carried_seeds[index])
		player.carried_seeds.remove_at(index)
		preload("res://garden_return_service.gd").bank(self,player,[seed],"checkpoint:"+str(encounter_number))
		reserve.unknown.append(seed)
		if index==0 and player.get("safe_items",[]).is_empty(): player.pouch=false
	elif fields[1]=="part":
		if index<=0 or index>=Parts.DEFINITIONS.size() or player.carried_parts[index]<=0: return
		player.carried_parts[index]-=1
		reserve.parts[index]+=1
	else: return
	if progress.save_garden()!=OK:
		progress.garden_interactions=return_before
		if seed>=0:
			reserve.unknown.pop_back()
			player.carried_seeds.insert(index,seed)
			player.pouch=old_pouch
		else:
			player.carried_parts[index]+=1
			reserve.parts[index]-=1
		tell(id,"Could not save courier delivery. Your item was returned.")
		return
	player.last_deposit=encounter_number
	tell(id,"Item sent to Garden storage.")

func build_heart_panels() -> void:
	deposit_menu=hud_panel(overlay,Color("#14262b"),Vector2(20,14))
	var box:=VBoxContainer.new()
	deposit_menu.add_child(box)
	add_label(box,22,Color("#dfd4a6")).text="Returning Mycelium"
	add_label(box,14,Color("#c8d1ad")).text="Send one carried item home from this checkpoint."
	deposit_pick=OptionButton.new()
	deposit_pick.custom_minimum_size.x=420
	box.add_child(deposit_pick)
	deposit_button=add_button(box,"Bank selected item",func():
		if deposit_pick.selected<0: return
		var value:=deposit_pick.get_item_id(deposit_pick.selected)
		send_garden_action("bank_part_%d"%(value-1000) if value>=1000 else "bank_seed_%d"%value)
		toggle_overlay(null))
	add_button(box,"Keep exploring",func(): toggle_overlay(null))
	recollection_menu=hud_panel(overlay,Color("#14262b"),Vector2(22,18))
	var story:=VBoxContainer.new()
	recollection_menu.add_child(story)
	add_label(story,24,Color("#ead8a3")).text="The Heart Remembers"
	var text:=add_label(story,16,Color("#d4d7b5"))
	text.custom_minimum_size.x=520
	text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	text.text="Every root has found its lost memory. The civilization, the corruption, the sacrifice: the Heart remembers it all.\n\nIt remembers what it protected. It remembers what people asked of it. And now it fears the Garden will repeat that ending.\n\nIts final remembrance is awake. Prepare your weapon, then face the Heart."
	add_button(story,"Prepare in the Garden",func(): toggle_overlay(null))
	add_button(story,"Face the Heart",func():
		toggle_overlay(null)
		var player: Dictionary=players.get(HOST,{})
		if not player.is_empty():
			player.pos=Stage.HEART
			awaken_heart(HOST,player))

func consider_recollection() -> void:
	if has_meta(Transactions.SESSION): return
	if not Campaign.LEGACY_ENDING_ENABLED: return
	if not progress.heart.has("perfect_recollection") or progress.heart.recollection_seen or progress.campaign.ending!=Campaign.UNFINISHED or players.is_empty(): return
	if overlay.visible: return
	var before: bool=progress.heart.recollection_seen
	progress.heart.recollection_seen=true
	if progress.save_garden()!=OK:
		progress.heart.recollection_seen=before
		return
	toggle_overlay(recollection_menu)
	for id in players:
		if id!=HOST: tell(id,"The Heart perfectly remembers. Its final awakening awaits your party.")


func at_weapon_gate(player: Dictionary) -> bool:
	return not player.is_empty() and not player.get("wild",false) and not player.get("fallen",false) and Stage.GATE.distance_to(player.get("pos",Vector3.INF))<=preload("res://gate_interaction.gd").RANGE

func local_player_id() -> int:
	return HOST if multiplayer.is_server() else multiplayer.get_unique_id()

func request_abandon_run() -> void:
	if players.get(local_player_id(),{}).get("wild",false): abandon_confirmation.popup_centered()

func abandon_run(id: int,player: Dictionary) -> void:
	if not player.get("wild",false): return
	Transactions.run(self,func():
		preload("res://garden_return_service.gd").outcome(self,player,"abandoned")
		return_to_garden(player)
		player.fallen=expedition_active()
		checkpoint_ready.erase(id)
		tell(id,"Expedition abandoned. All carried items lost, including the safe pouch. Class progress kept.")
		if expedition_active() and Life.living_ids(self).is_empty():
			finish_failed_expedition()
		elif not expedition_active():
			destination=Campaign.GROVE
			reset_expedition()
		else:
			resume_checkpoint_if_ready()
		if id==HOST: close_run_flow_panel()
		elif online_peer!=null: close_run_flow_panel.rpc_id(id)
		return true)

func show_gate_preparation(id: int) -> void:
	if not players.has(id) or not at_weapon_gate(players[id]): return
	if LoadoutMaterials.reconcile(players[id],stored_counts(players[id])) and not has_meta(Transactions.SESSION): persist_loadout(id,players[id])
	players[id].loadout_reserving=true
	if id==HOST: open_gate_preparation()
	else: open_gate_preparation.rpc_id(id)

@rpc("authority","call_remote","reliable")
func open_gate_preparation() -> void:
	if not loadout_menu.visible: toggle_overlay(loadout_menu)
	loadout_view.refresh()

@rpc("authority","call_remote","reliable")
func close_run_flow_panel() -> void:
	if checkpoint_menu.visible or loadout_menu.visible or session_menu.visible or graft_menu.visible or altar_menu.visible or (progression_menu.visible and progression_view.from_crafting):
		toggle_overlay(null)

func checkpoint_all_ready() -> bool:
	for id in players:
		if Life.alive(players[id]) and int(checkpoint_ready.get(id,0))!=encounter_number: return false
	return true

func checkpoint_card_data(player: Dictionary) -> Array:
	var result: Array=[]
	var wallet: int=run_wallet(player)
	var offers:=checkpoint_offer_ids(player)
	for index in offers.size():
		var entry:=RunUpgrades.get_upgrade(str(offers[index]))
		var rank:=int(player.get("run_upgrades",{}).get(entry.id,0))
		var reason:=RunUpgrades.requirement(entry,player)
		var text: String="%s · %s"%[entry.rarity,RunUpgrades.source_text(entry,player)]
		if not entry.has("behavior") and not entry.has("class_behavior"):
			var details:=RunUpgrades.effect_text(entry)
			if not details.is_empty(): text+="\n\n"+details
			text+="\n\nRank %d → %d%s"%[rank,rank+1," / %d"%int(entry.max_rank) if int(entry.max_rank)>0 else ""]
		if Life.Preview.enabled and entry.has("class_behavior"):
			var details:=RunUpgrades.effect_text(entry)
			if not details.is_empty(): text+="\n\n"+details
		if not str(entry.description).is_empty():text+="\n\n"+str(entry.description)
		if not reason.is_empty(): text+="\n"+reason
		result.append({"choice":index,"id":entry.id,"title":entry.name,"rarity":entry.rarity,"description":text,"cost":int(entry.cost),"enabled":int(player.last_offer)!=encounter_number and wallet>=int(entry.cost) and reason.is_empty()})
	return result

func present_checkpoint_cards(id: int) -> void:
	var player: Dictionary=players[id]
	var waiting: bool=int(checkpoint_ready.get(id,0))==encounter_number
	var wallet: int=run_wallet(player)
	if id==HOST: open_checkpoint_cards(checkpoint_card_data(player),wallet,encounter_number,waiting)
	elif online_peer!=null: open_checkpoint_cards.rpc_id(id,checkpoint_card_data(player),wallet,encounter_number,waiting)

@rpc("authority","call_remote","reliable")
func open_checkpoint_cards(cards: Array,wallet: int,floor_number: int,waiting: bool) -> void:
	for child in checkpoint_cards.get_children():
		checkpoint_cards.remove_child(child);child.queue_free()
	checkpoint_notice.text="Checkpoint %d · %d essence\nChoose one upgrade."%[floor_number,wallet]
	checkpoint_notice.text+=" Then confirm readiness at the gate with your party." if players.size()>1 else " It lasts until this expedition ends."
	if cards.size()==4: checkpoint_notice.text+="\nA hidden root reveals a fourth choice."
	if waiting: checkpoint_notice.text="Upgrade chosen. Waiting for party."
	var width: float=190 if cards.size()==4 else 225
	for data in cards:
		var frame:=hud_panel(checkpoint_cards,Color("#14262b"),Vector2(12,12))
		frame.custom_minimum_size=Vector2(width,340)
		var card:=VBoxContainer.new();card.add_theme_constant_override("separation",10);frame.add_child(card)
		var title:=add_label(card,18,Color("#e4d7a5"));title.text=str(data.title);title.add_theme_color_override("font_color",Color({"Common":"#d0d1b3","Uncommon":"#a3c57b","Rare":"#83b7d7","Epic":"#b99adb"}.get(str(data.get("rarity","Common")),"#e4d7a5")));title.custom_minimum_size=Vector2(width-28,52);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(width-28,220);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;card.add_child(scroll)
		var description:=add_label(scroll,14,Color("#c8d1bd"));description.text=str(data.description);description.custom_minimum_size.x=width-40;description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var choice:=int(data.choice)
		var button:=add_button(card,"%d · Choose · %d essence"%[choice+1,int(data.cost)],func(): send_garden_action("checkpoint_choice_%d"%choice))
		button.add_theme_font_size_override("font_size",13)
		button.disabled=waiting or not bool(data.enabled)
	checkpoint_skip.text="Waiting for party…" if waiting else "Skip upgrade"
	checkpoint_skip.disabled=waiting
	if not checkpoint_menu.visible: toggle_overlay(checkpoint_menu)

func choose_checkpoint_card(id: int,player: Dictionary,choice: int) -> void:
	if not checkpoint_pending or not Life.alive(player) or not upgrade_checkpoint_open() or player.pos.distance_to(battlefield.advance)>preload("res://gate_interaction.gd").RANGE or int(checkpoint_ready.get(id,0))==encounter_number: return
	if choice>=0:
		if choice>=checkpoint_offer_ids(player).size(): return
		if not buy_upgrade(id,player,choice):
			present_checkpoint_cards(id)
			return
	elif choice!=-1: return
	checkpoint_ready[id]=encounter_number
	if PartyTravel.members(self,"advance").size()>1:
		if id==HOST: close_run_flow_panel()
		elif online_peer!=null: close_run_flow_panel.rpc_id(id)
		tell(id,"Upgrade chosen. Ready up at the gate.")
		return
	resume_checkpoint_if_ready()
	if checkpoint_pending: present_checkpoint_cards(id)

func resume_checkpoint_if_ready() -> void:
	if PartyTravel.members(self,"advance").size()>1: return
	if not checkpoint_pending or not checkpoint_all_ready(): return
	for id in players:
		if Life.alive(players[id]) and players[id].pos.distance_to(battlefield.advance)<=preload("res://gate_interaction.gd").RANGE:
			use_checkpoint(id,true)
			return

func build_run_flow_panels() -> void:
	abandon_confirmation=ConfirmationDialog.new()
	abandon_confirmation.title="Abandon this expedition?"
	abandon_confirmation.dialog_text="Return to the Garden now? All carried seeds, materials, monster cargo and safe-pouch contents will be lost.
No expedition milestone, research or guardian-memory rewards will be granted.
Already banked items and permanent progress remain."
	abandon_confirmation.ok_button_text="Abandon & return"
	abandon_confirmation.cancel_button_text="Keep exploring"
	add_child(abandon_confirmation)
	abandon_confirmation.confirmed.connect(func(): send_garden_action("abandon_run"))
	checkpoint_menu=hud_panel(overlay,Color("#14262b"),Vector2(22,18))
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",14);checkpoint_menu.add_child(box)
	add_label(box,25,Color("#e4d7a5")).text="Roots of Strength"
	checkpoint_notice=add_label(box,15,Color("#c8d1bd"))
	checkpoint_cards=HBoxContainer.new();checkpoint_cards.add_theme_constant_override("separation",14);box.add_child(checkpoint_cards)
	checkpoint_skip=add_button(box,"Continue without another upgrade",func(): send_garden_action("checkpoint_choice_-1"))


func build_grafting_panel() -> void:
	graft_menu=hud_panel(overlay,Color("#14262b"),Vector2(20,14))
	graft_view=preload("res://grafting_panel.gd").new()
	graft_view.game=self
	graft_menu.add_child(graft_view)

func graft_menu_data(player: Dictionary) -> Dictionary:
	var installed:=int(player.get("graft_part",0))
	var slots: Array=[player.weapon,player.secondary,player.catalyst]
	var current:=weapon_stats(player)
	var options: Array=[]
	for part in range(1,Parts.DEFINITIONS.size()):
		if not Parts.is_monster(part) or int(player.carried_parts[part])<=0: continue
		var candidate: Dictionary=player.duplicate(true)
		candidate.graft_part=part
		options.append({"part":part,"name":Parts.part_name(part),"count":int(player.carried_parts[part]),"chance":graft_chance(player,part),"tags":Parts.DEFINITIONS[part].tags,"preview":Weapons.describe(weapon_stats(candidate)),"reason":graft_block_reason(player,part)})
	return {"floor":encounter_number,"slots":slots,"installed":installed,"installed_floor":int(player.get("graft_floor",0)),"current":Weapons.describe(current),"options":options,"status":str(player.get("graft_message","Choose a carried component. Grafting does not pause the Wilds."))}

func show_graft_menu(id: int) -> void:
	if not players.has(id) or not at_graft_altar(players[id]): return
	var data:=graft_menu_data(players[id])
	if id==HOST: open_graft_menu(data)
	else: open_graft_menu.rpc_id(id,data)

@rpc("authority","call_remote","reliable")
func open_graft_menu(data: Dictionary) -> void:
	graft_view.set_data(data)
	if not graft_menu.visible: toggle_overlay(graft_menu)


func graft_feedback(id: int,player: Dictionary,message: String) -> void:
	player.graft_message=message
	tell(id,message)

func inventory_ui_data() -> Dictionary:
	var player: Dictionary=players.get(local_player_id(),{})
	if player.is_empty(): return {}
	var data: Dictionary=InventoryModel.snapshot(self,player) if multiplayer.is_server() else player.get("bag",{}).duplicate()
	if data.is_empty(): return data
	var stats: Dictionary=weapon_stats(player,not data.wild) if multiplayer.is_server() else player.get("weapon_stats",{})
	data.core=stats.get("core_build",{})
	return data

func send_inventory_action(operation: String,source: String,target: String,item: String,quantity: int) -> void:
	send_garden_action("inventory:"+JSON.stringify({"operation":operation,"source":source,"target":target,"item":item,"quantity":quantity}))

func handle_inventory_action(id: int,player: Dictionary,payload: String) -> void:
	if payload.length()>1024: return
	var data=JSON.parse_string(payload)
	if not data is Dictionary: return
	for field in ["operation","source","target","item"]:
		if not data.get(field) is String: return
	if not (data.get("quantity") is int or data.get("quantity") is float): return
	var amount:=int(data.quantity)
	if float(data.quantity)!=amount or amount<=0: return
	if data.operation=="transfer":
		var transfer := InventoryModel.transfer.bind(self,player,data.source,data.target,data.item,amount)
		if player.get("wild", false):
			tell(id,transfer.call())
		else:
			var result := Transactions.run_gameplay(self, Transactions.Scope.GARDEN, transfer, false)
			tell(id,Transactions.feedback(result, "Could not save the transfer."))
	elif data.operation=="drop": drop_inventory_stack(id,player,data.source,data.item,amount)

func inventory_drop_list(player: Dictionary) -> Array:
	return wild_item_drops if player.get("wild",false) else progress.ground_items

func can_see_item_drop(player: Dictionary,entry: Dictionary) -> bool:
	if not entry.has("owner"): return true
	return players.has(int(entry.owner)) and is_same(players[int(entry.owner)],player)

func inventory_floor_snapshot(player: Dictionary) -> Array:
	var result: Array=[]
	for entry in inventory_drop_list(player):
		if not can_see_item_drop(player,entry): continue
		result.append({"id":entry.id,"item":entry.stack.item,"quantity":entry.stack.quantity,"position":entry.position})
	return result

func nearest_visible_inventory_drop(player: Dictionary) -> String:
	var closest:=1.65;var found: String=""
	for entry in player.get("ground_items",[]):
		var values: Array=entry.position
		var distance: float=player.get("pos",Vector3.INF).distance_to(Vector3(values[0],values[1],values[2]))
		if distance<closest: closest=distance;found=entry.id
	return found

func nearest_inventory_drop(player: Dictionary) -> String:
	var closest:=1.65;var found: String=""
	for entry in inventory_drop_list(player):
		if not can_see_item_drop(player,entry): continue
		var values: Array=entry.position
		var distance: float=player.get("pos",Vector3.INF).distance_to(Vector3(values[0],values[1],values[2]))
		if distance<closest: closest=distance;found=entry.id
	return found

func drop_inventory_stack(id: int,player: Dictionary,source: String,item: String,quantity: int) -> void:
	if not player.get("wild",false) and not deferred_save_available(id): return
	var allowed: Array=["carry","pouch"] if player.get("wild",false) else ["stash","shared"]
	if not allowed.has(source): return
	var stack:=InventoryModel.take(self,player,source,item,quantity)
	if stack.is_empty(): tell(id,"That stack changed. Refresh the inventory.");return
	var point: Vector3=player.pos+Vector3(.65,0,.35)
	if player.get("wild",false): point=battlefield.dash(player.pos,point)
	var drop: Dictionary={"id":Crypto.new().generate_random_bytes(12).hex_encode(),"stack":stack,"position":[point.x,point.y,point.z]}
	var drops:=inventory_drop_list(player)
	drops.append(drop)
	if not player.get("wild",false) and progress.save_garden()!=OK:
		drops.erase(drop);InventoryModel.put(self,player,source,stack)
		tell(id,"Could not save the dropped item. The stack was returned.");return
	tell(id,"Dropped %d %s. Close the inventory and press E nearby to recover it."%[quantity,Items.get_item(item).name])

func pickup_inventory_drop(id: int,player: Dictionary,key: String) -> void:
	if not player.get("wild",false) and not deferred_save_available(id): return
	var drops:=inventory_drop_list(player)
	for index in drops.size():
		var entry: Dictionary=drops[index]
		if entry.id!=key or not can_see_item_drop(player,entry): continue
		var values: Array=entry.position
		if player.pos.distance_to(Vector3(values[0],values[1],values[2]))>1.65: return
		var target: String="carry" if player.get("wild",false) else "stash"
		drops.remove_at(index)
		InventoryModel.put(self,player,target,entry.stack)
		var component:=int(Items.get_item(entry.stack.item).get("legacy_part",0))
		if Parts.is_monster(component): player.graft_choice=component
		if not player.get("wild",false) and progress.save_garden()!=OK:
			InventoryModel.take(self,player,target,entry.stack.item,int(entry.stack.quantity));drops.insert(index,entry)
			tell(id,"Could not save pickup. The stack remains on the ground.");return
		tell(id,"Picked up %d %s."%[entry.stack.quantity,Items.get_item(entry.stack.item).name])
		return

func monster_loot_tags(kind: int,mask: int=0) -> Array:
	var result: Array=Enemies.get_kind(kind).get("loot_tags",[]).duplicate()
	if mask!=0: result.append("adapted")
	for pair in [[Enemies.REACH,"reach"],[Enemies.BARK,"armored"],[Enemies.SPORES,"spores"],[Enemies.MOBILITY,"mobile"],[Enemies.JUVENILE,"juvenile"]]:
		if (mask & int(pair[0]))!=0: result.append(pair[1])
	return result

func roll_monster_item(kind: int,mask: int=0) -> String:
	var candidates: Array=Items.loot_candidates(monster_loot_tags(kind,mask))
	if candidates.is_empty(): return ""
	if candidates.size()==1: return candidates[0]
	var total:=0.0
	for item in candidates: total+=float(Items.get_item(item).get("loot_weight",1.0))
	var roll:=rng.randf()*total
	for item in candidates:
		roll-=float(Items.get_item(item).get("loot_weight",1.0))
		if roll<=0: return item
	return candidates.back()


func at_garden_altar(player: Dictionary) -> bool:
	return not player.is_empty() and not player.get("wild",false) and player.get("pos",Vector3.INF).distance_to(Stage.ALTAR)<=1.65

func build_garden_altar_panel() -> void:
	altar_menu=hud_panel(overlay,Color("#14262b"),Vector2(20,14))
	altar_view=preload("res://garden_altar_panel.gd").new()
	altar_view.game=self
	altar_menu.add_child(altar_view)

func show_garden_altar(id: int) -> void:
	if not players.has(id) or not at_garden_altar(players[id]): return
	var data:=Altar.snapshot(self,players[id],[{},{}],0)
	if id==HOST: open_garden_altar(data)
	else: open_garden_altar.rpc_id(id,data)

@rpc("authority","call_remote","reliable")
func open_garden_altar(data: Dictionary) -> void:
	altar_view.begin(data)
	if not altar_menu.visible: toggle_overlay(altar_menu)

func send_altar_action(operation: String,draft: Array,revision: int) -> void:
	send_garden_action("altar:"+JSON.stringify({"operation":operation,"draft":draft,"revision":revision}))

func run_altar_save(id: int, player: Dictionary, action: Callable) -> void:
	var result := Transactions.run_gameplay(self, Transactions.Scope.GARDEN, action, false)
	player.altar_message = Transactions.feedback(result, "Could not save the Altar offering.")
	tell(id, player.altar_message)

func handle_altar_action(id: int,player: Dictionary,payload: String) -> void:
	if not at_garden_altar(player) or payload.length()>2048: return
	var request=JSON.parse_string(payload)
	if not request is Dictionary or request.get("operation","") not in ["preview","combine","identify","identify_all"]: return
	if not (request.get("revision",0) is int or request.get("revision",0) is float): return
	var draft:=Altar.clean_draft(request.get("draft",[]))
	var revision:=clampi(int(request.get("revision",0)),0,2147483647)
	if request.operation=="combine": run_altar_save(id, player, Altar.combine.bind(self, player, draft))
	elif request.operation=="identify": run_altar_save(id, player, Altar.identify.bind(self, player))
	elif request.operation=="identify_all": run_altar_save(id, player, Altar.identify_all.bind(self, player))
	var data:=Altar.snapshot(self,player,draft,revision)
	if id==HOST: update_garden_altar(data)
	else: update_garden_altar.rpc_id(id,data)

@rpc("authority","call_remote","reliable")
func update_garden_altar(data: Dictionary) -> void:
	altar_view.set_data(data)


func support_allies(support: Dictionary) -> Array:
	var result: Array=[]
	if enemy_hp>0 and not Enemies.is_support(enemy_kind): result.append({"index":-1,"pos":enemy_pos,"engaged":enemy_engaged})
	for index in scouts.size():
		var other: Dictionary=scouts[index]
		if other.hp>0 and not Enemies.is_support(int(other.get("kind",0))): result.append({"index":index,"pos":other.pos,"engaged":bool(other.get("engaged",false))})
	result.sort_custom(func(a,b): return support.pos.distance_squared_to(a.pos)<support.pos.distance_squared_to(b.pos))
	return result

func formation_position(anchor: Vector3,ignore: int,phase: float) -> Vector3:
	for radius in [1.5,2.0,2.6]:
		for step in 20:
			var angle:=phase+step*TAU/20
			var candidate:=anchor+Vector3(cos(angle)*radius,0,sin(angle)*radius)
			if battlefield.occupied(candidate,Battlefield.CLEARANCE) or not battlefield.clear_line(anchor,candidate,Battlefield.CLEARANCE): continue
			if not preload("res://wilds_composition.gd").partner_position(self,candidate) or candidate.distance_to(enemy_pos)<.85: continue
			var free:=true
			for index in scouts.size():
				if index!=ignore and scouts[index].hp>0 and candidate.distance_to(scouts[index].pos)<.85: free=false;break
			if free: return candidate
	return Vector3.INF

func arrange_support_groups() -> void:
	for index in scouts.size():
		var support: Dictionary=scouts[index]
		if not Enemies.is_support(int(support.kind)): continue
		var minimum:=maxi(1,int(Enemies.get_kind(int(support.kind)).get("escort_min",2)))
		var allies:=support_allies(support)
		# A support-heavy pool still needs fighters. Reuse slots instead of adding enemies.
		if allies.size()<minimum:
			for other in range(scouts.size()-1,-1,-1):
				if other==index or not Enemies.is_support(int(scouts[other].kind)): continue
				var old: Dictionary=scouts[other]
				scouts[other]=make_scout(0,old.pos,int(old.route),int(old.mutations),int(old.growth))
				allies=support_allies(support)
				if allies.size()>=minimum: break
		if allies.size()<minimum:
			scouts[index]=make_scout(0,support.pos,int(support.route),int(support.mutations),int(support.growth));continue
		var anchor: Vector3=allies[0].pos
		var placed:=formation_position(anchor,index,float(index)*1.7)
		if placed==Vector3.INF:
			scouts[index]=make_scout(0,support.pos,int(support.route),int(support.mutations),int(support.growth));continue
		support.pos=placed
		var radius:=float(Enemies.get_kind(int(support.kind)).get("escort_radius",3.8))
		for ally in allies.slice(1,minimum):
			if int(ally.index)<0: continue
			if support.pos.distance_to(ally.pos)<=radius and battlefield.clear_line(support.pos,ally.pos,Battlefield.CLEARANCE): continue
			var companion:=formation_position(anchor,int(ally.index),float(index)*1.7+PI)
			if companion!=Vector3.INF: scouts[int(ally.index)].pos=companion
		var nearby:=0
		for ally in support_allies(support):
			nearby+=int(support.pos.distance_to(ally.pos)<=radius and battlefield.clear_line(support.pos,ally.pos,Battlefield.CLEARANCE))
		if nearby<minimum: scouts[index]=make_scout(0,support.pos,int(support.route),int(support.mutations),int(support.growth))

	# A later group may have reused an escort. Check the complete formation once more.
	for index in scouts.size():
		var support: Dictionary=scouts[index]
		if not Enemies.is_support(int(support.kind)): continue
		var definition:=Enemies.get_kind(int(support.kind))
		var nearby:=0
		for ally in support_allies(support):
			nearby+=int(support.pos.distance_to(ally.pos)<=float(definition.get("escort_radius",3.8)) and battlefield.clear_line(support.pos,ally.pos,Battlefield.CLEARANCE))
		if nearby<int(definition.get("escort_min",2)): scouts[index]=make_scout(0,support.pos,int(support.route),int(support.mutations),int(support.growth))

func update_support_position(scout: Dictionary,allies: Array,definition: Dictionary,speed: float,delta: float,now: int) -> void:
	var anchor: Vector3=allies[0].pos
	var distance: float=scout.pos.distance_to(anchor)
	if distance>2.65 or not battlefield.clear_line(scout.pos,anchor):
		if now>=int(scout.rooted_until): scout.pos=battlefield.navigate(scout.pos,anchor,speed*delta,int(scout.route))
		return
	if now>=int(scout.ready):
		if EnemyBehaviors.support_target(self,scout,allies,anchor,speed,delta,now):return
		scout.repeat=0
		var attacks=preload("res://enemy_attack.gd")
		var role: String=definition.role
		var aim: Vector3=attacks.aim(self,scout,role,int(scout.cast_target))
		var duration:=int(definition.windup)+(380 if scout.get("variant","")=="long_tether" else 0)
		attacks.lock(self,scout,role,aim,now+duration)
		var tactics=preload("res://wilds_skill_tactics.gd")
		scout.windup=now+tactics.response_windup(scout.attack,duration)
		if scout.get("covered_once",false):scout.covered_cast=true

func record_enemy_death(target: int,position: Vector3,origin: Vector3) -> void:
	var key:=str(combat_epoch)+":"+("leader" if target==-1 else str(scouts[target].get("spawn_token",target)))
	if kill_receipts.has(key): return
	var kind: int=enemy_kind if target==-1 else int(scouts[target].get("kind",0))
	if target==-1 or not scouts[target].get("summoned",false): encounter_kills.append(kind)
	var mask: int=enemy_mutations if target==-1 else int(scouts[target].get("mutations",0))
	if target==-1 or not scouts[target].get("summoned",false): encounter_kill_records.append({"kind":kind,"mask":mask})
	if target==-1 or not scouts[target].get("summoned",false): MonsterRewards.queue(self,key,kind,mask,position,target==-1)
	else: kill_receipts[key]=true
	if target>=0: EnemyBehaviors.death(self,scouts[target],position)
	elif leader_brain.has("elite"): EnemyBehaviors.death(self,leader_brain.elite,position)
	var growth: int=enemy_growth if target==-1 else int(scouts[target].get("growth",0))
	var direction: Vector3=(position-origin).normalized()
	enemy_death_serial+=1
	var scale_value: float=1.0 if boss_kind>=0 and target==-1 else (1.9 if destination==Campaign.HEART or depth==ROUTE_ROOMS else 1.0 if depth==1 else 1.22) if target==-1 else 1.0
	enemy_death_events.append({"id":enemy_death_serial,"position":[position.x,position.y,position.z],"direction":[direction.x,0,direction.z],"code":Enemies.encode(kind,mask,growth),"scale":scale_value,"born":Time.get_ticks_msec()})
	while enemy_death_events.size()>24: enemy_death_events.pop_front()

func death_events_snapshot() -> Array:
	var now:=Time.get_ticks_msec()
	var result: Array=[]
	for index in range(enemy_death_events.size()-1,-1,-1):
		if now-int(enemy_death_events[index].born)>2300: enemy_death_events.remove_at(index)
	for event in enemy_death_events:
		var copy: Dictionary=event.duplicate();copy.erase("born");copy.age=maxf(0,(now-int(event.born))/1000.0);result.append(copy)
	return result


func attack_animation_snapshot(player: Dictionary) -> Dictionary:
	var duration:=maxi(1,int(player.get("attack_duration",240)))
	var remaining:=int(player.get("attack_until",0))-Time.get_ticks_msec()
	if int(player.get("cast_until",0))>Time.get_ticks_msec():
		var cast_pose: Dictionary = preload("res://subclass_combat.gd").pose_state(player,Time.get_ticks_msec())
		return {"active":true,"phase":clampf(1.0-(int(player.cast_until)-Time.get_ticks_msec())/550.0,0,1),"combo":int(player.get("skill_fx_seq",0)),"duration":550,"form":"cast","clip":cast_pose.get("clip",""),"direction":cast_pose.get("direction",null)}
	var now:=Time.get_ticks_msec()
	return {"active":remaining>0,"phase":clampf(1.0-remaining/float(duration),0,1),"combo":int(player.get("attack_combo",0)),"duration":duration,"reach":player.get("attack_reach",2.0),"direction":MouseCombat.attack_direction(player,now),"aim_live":MouseCombat.aim_is_live(player,now),"clip":player.get("attack_clip",WeaponMotion.profile(WeaponMotion.form(player)).clip),"delivery":player.get("attack_delivery","sweep"),"span":player.get("attack_span",1.9),"form":"weapon"}

func weapon_effect_color(player: Dictionary) -> Color:
	var part:=int(player.get("weapon",0))
	if Parts.is_plant(part): return Color(Seeds.DEFINITIONS[Parts.plant_source(part)].color).lightened(.25)
	return Color("#d7e8ab")

func emit_combat_event(kind: String,shape: String,from: Vector3,to: Vector3,duration: float,color: Color,reach: float,combo: int,options: Dictionary={}) -> void:
	combat_event_serial+=1
	combat_events.append({"id":combat_event_serial,"kind":kind,"shape":shape,"from":[from.x,from.y,from.z],"to":[to.x,to.y,to.z],"duration":duration,"color":color.to_html(),"reach":reach,"combo":combo,"span":2.7 if shape=="wide_arc" else 1.3 if shape=="knife_arc" else 1.9,"born":Time.get_ticks_msec()})

	var latest: Dictionary=combat_events.back()
	for key in options:
		if key in ["form","pattern","contact","width","span","projectile_radius","height","owner","clip","target_token","core_shapes","core_phase"]:latest[key]=options[key]
	if kind=="impact" and shape in ["hit","hurt","block","heal"]:
		latest.amount=maxi(0,roundi(reach));latest.target_id=combo
		latest.target_token=int(scouts[combo].get("spawn_token",0)) if shape=="hit" and combo>=0 and combo<scouts.size() else -1
	if kind=="subclass_release":
		latest.label=options.get("label","")
	if kind=="ability":
		latest.label=shape.replace("_"," ").capitalize()
		if players.has(combo):
			for slot in 2:
				var skill:=Skills.resolve(int(players[combo].frame),slot,players[combo].character)
				if str(skill.mode)==shape:latest.label=skill.name;break
		latest.label=options.get("label",latest.label)
	if is_instance_valid(Journal.current) and Journal.current.detail:
		Journal.event("combat","presentation_event",{"event_id":latest.id,"kind":kind,"shape":shape,"amount":latest.get("amount",0),"from":latest.from,"to":latest.to,"target_id":latest.get("target_id",-2),"target_token":latest.get("target_token",-1),"weapon_form":latest.get("form",""),"pattern":latest.get("pattern",""),"width":latest.get("width",0),"span":latest.get("span",0),"contact":latest.get("contact",0),"status_actor":latest.combo if kind=="status" else -2,"status_stacks":latest.reach if kind=="status" else 0})
	while combat_events.size()>80: combat_events.pop_front()
	if online_peer!=null and multiplayer.is_server() and not SaveBatch.active:
		var event: Dictionary=combat_events.back().duplicate();event.erase("born");event.age=0.0
		receive_combat_event.rpc(event,str([destination,encounter_number,map_seed]))

func emit_weapon_attack(player: Dictionary,from: Vector3,to: Vector3,stats: Dictionary,_now: int) -> void:
	var form:=WeaponMotion.form(player);var profile:=WeaponMotion.profile(form)
	var duration: float=int(player.get("attack_duration",240))/1000.0
	if WeaponMotion.is_projectile(form): duration=clampf(from.distance_to(to)/float(profile.speed),.08,.45)
	var description:=preload("res://weapon_contact.gd").describe(form,stats)
	for id in players:
		if is_same(players[id],player):description.owner=id;break
	emit_combat_event("projectile" if WeaponMotion.is_projectile(form) else "swing",str(profile.shape),from,to,duration,weapon_effect_color(player),float(stats.reach),int(player.get("attack_combo",0)),description)

func combat_events_snapshot() -> Array:
	var now:=Time.get_ticks_msec();var result: Array=[]
	for index in range(combat_events.size()-1,-1,-1):
		if now-int(combat_events[index].born)>float(combat_events[index].duration)*1000+150: combat_events.remove_at(index)
	for event in combat_events:
		if event.kind=="status":continue
		var copy: Dictionary=event.duplicate();copy.erase("born");copy.age=maxf(0,(now-int(event.born))/1000.0);result.append(copy)
	var known: Array=result.map(func(e):return e.id)
	for event in preload("res://combat_status.gd").snapshot(self,now):
		if not known.has(event.id):result.append(event)
	return result

func update_projectiles(now: int) -> void:
	for shot in projectile_queue.duplicate():
		if int(shot.epoch)!=combat_epoch or not players.has(shot.player) or not Life.alive(players[shot.player]):projectile_queue.erase(shot);continue
		if shot.get("melee_shape",false):
			if now>=int(shot.due):
				preload("res://event_audio.gd").weapon(self,shot.form,players[shot.player].pos)
				preload("res://weapon_contact.gd").melee(self,shot,now);projectile_queue.erase(shot)
			continue
		if now<int(shot.release):continue
		var rays: Array=[shot]
		if not shot.get("emitted",false):
			MouseCombat.launch(self,shot)
			preload("res://event_audio.gd").weapon(self,shot.form,shot.origin)
			rays=MouseCombat.volley(self,shot)
			for ray in rays:
				if not is_same(ray,shot):projectile_queue.append(ray)
				var form: String=ray.form
				var flight:=maxf(.03,(int(ray.due)-int(ray.release))/1000.)
				emit_combat_event("projectile",str(WeaponMotion.profile(form).shape),ray.origin,ray.aim,flight,weapon_effect_color(players[ray.player]),float(ray.stats.reach),0,preload("res://weapon_contact.gd").describe(form,ray.stats))
				ray.visual_event_id=combat_event_serial
		for ray in rays:
			if MouseCombat.ray_tick(self,ray,now):
				if ray.has("visual_event_id"):emit_combat_event("projectile_end",str(ray.visual_event_id),ray.origin,ray.get("visual_stop",ray.aim),.15,Color.WHITE,0,0)
				projectile_queue.erase(ray)


func attack_hints_snapshot() -> Array:
	var result: Array=Bosses.hints(self)
	result.append_array(preload("res://glasscap_feint.gd").hints(self,Time.get_ticks_msec()))
	if boss_kind<0 and destination!=Campaign.HEART and leader_brain.has("elite"):result.append_array(preload("res://elite_enemy.gd").hints(self))
	if enemy_hp>0 and enemy_winding_up and not Bosses.owns_warnings(boss_kind) and (boss_kind>=0 or not leader_brain.has("elite")):
		var target:=enemy_landing if enemy_attack_mode=="vault" or boss_kind>=0 else enemy_pos
		result.append({"id":-1,"role":("charge" if enemy_attack_mode in ["root_sweep","orchard_march","drowned_surge","matriarch_lunge","memory_lance","remembered_rend"] else "volley") if boss_kind>=0 else "vault" if enemy_attack_mode=="vault" else "swipe","from":[enemy_pos.x,0,enemy_pos.z],"to":[target.x,0,target.z],"radius":Bosses.warning_radius(self) if boss_kind>=0 else strike_radius(),"width":Bosses.warning_width(self) if boss_kind>=0 else .85,"remaining":maxf(0,(enemy_strike_at-Time.get_ticks_msec())/1000.0)})
	for index in scouts.size():
		var scout: Dictionary=scouts[index]
		if scout.hp<=0 or int(scout.windup)<=0: continue
		var attacks = preload("res://enemy_attack.gd")
		result.append_array(attacks.hints(attacks.current(self,scout),index,maxf(0,(int(scout.windup)-Time.get_ticks_msec())/1000.0)))
	var attacks=preload("res://enemy_attack.gd")
	if enemy_kind==11 and enemy_hp>0 and enemy_engaged and leader_brain.get("elite",{}).get("attack",{}).get("variant","")!="planted_canopy":
		result.append(attacks.warning(-2000,"canopy",enemy_pos,enemy_pos,float(Enemies.get_kind(11).shelter_radius),0,0))
	for index in scouts.size():
		var actor: Dictionary=scouts[index]
		if actor.kind==11 and actor.hp>0 and actor.engaged and actor.get("attack",{}).get("variant","")!="planted_canopy":
			result.append(attacks.warning(-2001-index,"canopy",actor.pos,actor.pos,float(Enemies.get_kind(11).shelter_radius),0,0))
	result.append_array(preload("res://expedition_pressure.gd").hints(self))
	result.append_array(preload("res://core_combat.gd").hints(self))
	result.append_array(preload("res://warden_combat.gd").hints(self,Time.get_ticks_msec()))
	return result

func hit_players_charge(from: Vector3,to: Vector3,width: float,landing_radius: float,now: int,damage: float) -> void:
	for id in players:
		var player: Dictionary=players[id]
		if not Life.alive(player): continue
		var nearest:=Geometry3D.get_closest_point_to_segment(player.pos,from,to)
		if player.pos.distance_to(nearest)<=width+.35 or player.pos.distance_to(to)<=landing_radius+.35:
			if battlefield.clear_line(nearest,player.pos): apply_enemy_hit(id,player,now,damage,0,from)



func build_planting_panel() -> void:
	planting_menu=hud_panel(overlay,Color("#14262b"),Vector2(20,14));planting_view=preload("res://planting_panel.gd").new();planting_view.game=self;planting_menu.add_child(planting_view)
func show_planting_picker(id: int,slot: int) -> void:
	var p: Dictionary=players[id]
	if p.wild or slot<0 or slot>=progress.plots.size() or p.pos.distance_to(Stage.PLOTS[slot])>1.65 or progress.plots[slot].species>=0 or progress.offshoot_in_bed(slot)>=0: return
	var stock: Array=seed_reserve(p).stock.duplicate()
	if id==HOST: open_planting_picker(slot,stock)
	else: open_planting_picker.rpc_id(id,slot,stock)
@rpc("authority","call_remote","reliable")
func open_planting_picker(slot: int,stock: Array) -> void:
	planting_view.begin(slot,stock)
	if not planting_menu.visible: toggle_overlay(planting_menu)
@rpc("authority","call_remote","reliable")
func close_planting_picker() -> void:
	if planting_menu.visible: toggle_overlay(null)



@rpc("authority","call_remote","reliable",1)
func receive_details(payload: PackedByteArray,garden: PackedByteArray,inventory_data: Array,state_key: String) -> void:
	var decoded=bytes_to_var(payload.decompress_dynamic(262144,FileAccess.COMPRESSION_DEFLATE))
	var world=bytes_to_var(garden.decompress_dynamic(65536,FileAccess.COMPRESSION_DEFLATE))
	if not decoded is Dictionary or not world is Array or world.size()<13: return
	client_details=decoded;client_details_key=state_key;client_inventory=inventory_data;client_garden=world
	set_meta("core_details_at",Time.get_ticks_msec())
	var id:=multiplayer.get_unique_id()
	if players.has(id): players[id].merge(client_details,true)

@rpc("authority","call_remote","reliable",2)
func receive_combat_event(event: Dictionary,key: String) -> void:
	received_combat_events.append({"event":event,"key":key,"born":Time.get_ticks_msec()})
	while received_combat_events.size()>100: received_combat_events.pop_front()

func guest_combat_events(player: Dictionary) -> Array:
	var result: Array=[];var key:=str([destination,encounter_number,map_seed]);var now:=Time.get_ticks_msec()
	for entry in received_combat_events.duplicate():
		var age: float=maxf(0,float(entry.event.get("age",0)))+(now-int(entry.born))/1000.0
		if age>float(entry.event.duration)+.2: received_combat_events.erase(entry);continue
		if entry.key!=key: continue
		var event: Dictionary=entry.event.duplicate();event.age=age;result.append(event)
	if client_details_key==key: result.append_array(player.get("combat_events",[]))
	return result

func request_ip_join() -> void:
	var recent := Network.load_settings(slot_storage_root)
	network_dialog.begin(recent.address,recent.port,true,str(local_character.data.get("name","Wanderer")))

func admission_error(identity: String,catalog: Dictionary,protocol: int) -> String:
	if protocol!=Network.PROTOCOL: return "Different multiplayer versions. Use the same updated game build."
	if catalog!=progress.ContentIDs.manifest(): return "Different game content. Update all game copies before joining."
	if not Character.valid_identity(identity): return "Invalid character identity. Choose another character."
	if identity==local_character.identity: return "This character is already the host. Choose a different character."
	for player in players.values():
		if player.profile_ready and player.get("seed_owner","")==identity: return "This character is already connected."
	if expedition_active(): return "The host is in the Wilds. Join after the party returns to the Garden."
	return ""

func reject_peer(id: int,reason: String) -> void:
	if not players.has(id) or players[id].get("rejecting",false): return
	Journal.event("network","peer_rejected",{"actor":id,"reason":reason},"warning")
	players[id].rejecting=true
	connection_rejected.rpc_id(id,reason)
	get_tree().create_timer(.25).timeout.connect(func():
		if online_peer!=null and multiplayer.is_server() and players.has(id): online_peer.disconnect_peer(id))

@rpc("authority","call_remote","reliable")
func connection_accepted(profile: Dictionary) -> void:
	if session!="Connecting" or not Transactions.session_writable(self): return
	Journal.event("network","join_accepted")
	session="Guest";joined_from_title=false;status="Joined the host's Garden."
	set_meta("join_phase","garden")
	receive_character(profile);connection_deadline=Time.get_ticks_msec()+Network.REGISTER_TIMEOUT_MS
	if Transactions.pending_notice(self).is_empty(): toggle_overlay(null)

@rpc("authority","call_remote","reliable")
func connection_rejected(reason: String) -> void:
	Journal.event("network","connection_rejected",{"reason":reason},"warning")
	connection_deadline=0
	if active_character_slot>=0 or joined_from_title: return_to_main_menu(reason)
	else: leave_game(reason)

func update_network_session() -> void:
	if connection_panel==null: return
	var waiting: bool=session=="Connecting" or (session=="Guest" and client_details.is_empty())
	connection_panel.visible=waiting
	if waiting:
		var phase: String = get_meta("join_phase","connect")
		connection_label.text=Network.join_progress(phase,network_address,network_port)
		if connection_deadline>0 and Time.get_ticks_msec()>connection_deadline:
			connection_rejected(Network.join_failure(phase,network_address,network_port,true))
	elif session=="Guest":
		connection_deadline=0
		if has_meta("join_phase"): remove_meta("join_phase")
	if session=="Host":
		var now:=Time.get_ticks_msec()
		for id in players:
			if id!=HOST and not players[id].profile_ready and now-int(players[id].get("joined_at",now))>Network.REGISTER_TIMEOUT_MS: reject_peer(id,"Character registration timed out. Check both game versions.")

func allow_remote(id: int,channel: String,limit: int) -> bool:
	if not players.has(id) or not players[id].profile_ready or players[id].get("rejecting",false): return false
	var now:=Time.get_ticks_msec();var player: Dictionary=players[id]
	var key:="budget_"+channel;var budget: Array=player.get(key,[now,0])
	if now-int(budget[0])>=1000: budget=[now,0]
	budget[1]+=1;player[key]=budget
	return int(budget[1])<=limit

func party_travel_state() -> Dictionary:
	var id:=multiplayer.get_unique_id()
	return PartyTravel.snapshot(self,id) if multiplayer.is_server() else players.get(id,{}).get("party_travel",{})

func send_travel_ready(unready: bool) -> void:
	var state:=party_travel_state()
	if not state.is_empty(): send_garden_action(("travel_unready:" if unready else "travel_ready:")+str(state.epoch))

func update_ready_panel(player: Dictionary,id: int) -> void:
	var state: Dictionary=PartyTravel.snapshot(self,id) if multiplayer.is_server() else player.get("party_travel",{})
	travel_panel.visible=not state.is_empty() and not overlay.visible
	if state.is_empty(): return
	var count:=0;var rows: Array=[]
	for member in state.members:
		count+=int(member.ready);rows.append(str(member.name)+(" - Ready" if member.ready else " - Not ready"))
	var title: String={"depart":"Enter "+str(state.get("goal","the Wilds")),"advance":"Next stage","extract":"Extract to Garden"}.get(str(state.kind),"Party travel")
	travel_label.text="%s - %d/%d ready\n%s"%[title,count,state.members.size(),"\n".join(rows)]
	ready_button.text="Ready at Heart" if state.kind=="depart" and destination==Campaign.HEART else "Ready at Gate"
	ready_button.disabled=bool(state.ready);unready_button.disabled=not bool(state.ready)

func update_combat_tracking(delta: float) -> void:
	for id in players:
		var p: Dictionary=players[id]
		if not p.wild: combat_last_positions.erase(id);combat_velocity[id]=Vector3.ZERO;continue
		var previous: Vector3=combat_last_positions.get(id,p.pos)
		var velocity: Vector3=(p.pos-previous)/maxf(.001,delta)
		# Teleports/dodges do not become implausible long-range predictive aim.
		combat_velocity[id]=velocity if velocity.length()<6.2 else Vector3.ZERO
		combat_last_positions[id]=p.pos
		combat_threat[id]=maxf(0,float(combat_threat.get(id,0))-delta*2.5)

func select_attack_target(player: Dictionary,reach: float) -> int:
	var best:=INF;var result:=-2
	for target in range(-1,scouts.size()):
		if (enemy_hp if target==-1 else int(scouts[target].hp))<=0: continue
		var offset: Vector3=enemy_contact_point(target,player.pos)-player.pos;var distance:=offset.length()
		if distance>reach or not battlefield.clear_line(player.pos,enemy_contact_point(target,player.pos)): continue
		var facing: Vector3=player.get("facing",Vector3.FORWARD)
		if player.get("mouse_aim",false) and not offset.is_zero_approx() and facing.dot(offset.normalized())<.75:continue
		var score: float=distance+(1.0-facing.dot(offset.normalized()))*.55
		var token: int=-1 if target==-1 else int(scouts[target].get("spawn_token",0))
		if int(player.get("aim_target",-3))==target and int(player.get("aim_token",-99))==token: score-=.3
		if score<best: best=score;result=target
	if result!=-2: player.aim_target=result;player.aim_token=-1 if result==-1 else int(scouts[result].get("spawn_token",0))
	return result

func roll_kill_trophy(kind: int,mask: int=0,leader: bool=false) -> String:
	var chance:=float(Enemies.get_kind(kind).get("trophy_chance",0.6)) if Enemies.get_kind(kind).get("boss",false) else Director.trophy_chance(encounter_number,leader and depth==ROUTE_ROOMS,mask!=0)
	return roll_monster_item(kind,mask) if rng.randf()<chance else ""

@rpc("authority","call_remote","reliable",2)
func receive_vitals(states: Dictionary) -> void:
	net_view.receive(self,states)

func attract_loot(delta: float) -> void:
	if not encounter_cleared(): return
	for id in players:
		var p: Dictionary=players[id]
		if not Life.alive(p): continue
		var radius:=minf(8,float(weapon_stats(p).get("loot_attract",0)))
		if radius<=0: continue
		for drop in wild_item_drops:
			if not can_see_item_drop(p,drop): continue
			var at:=Vector3(drop.position[0],0,drop.position[2])
			if at.distance_to(p.pos)<=radius and battlefield.clear_line(at,p.pos):
				at=at.move_toward(p.pos,4.5*delta);drop.position=[at.x,0,at.z]

func enemy_contact_point(target: int,origin: Vector3) -> Vector3:
	return preload("res://enemy_hurtbox.gd").contact(self,target,origin)

@rpc("any_peer","call_remote","unreliable_ordered",1)
func submit_combat(aim: Vector2,held: bool) -> void:
	var id:=multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and aim.is_finite() and allow_remote(id,"combat_input",60):mouse_controls.receive(self,id,aim,held,Time.get_ticks_msec())
