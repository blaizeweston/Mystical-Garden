extends Node3D
# Emitted by the outgoing-hit port and connected by the world composition root.
@warning_ignore("unused_signal")
signal outgoing_contact_requested(source_peer: int, target: int)
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const CombatClock = preload("res://combat_clock.gd")
const Participation = preload("res://expedition_participation.gd")
const Session = preload("res://network_session.gd")
var session_world := preload("res://session_world.gd").new(self)
var expedition_statistics := preload("res://expedition_statistics.gd").new()
var expedition_transitions := preload("res://expedition_transitions.gd").new(self)
const ActionIdentity = preload("res://network_action_identity.gd")

const Journal=preload("res://diagnostic_journal.gd")
var diagnostic_watch: Node
const HeartCatalog=preload("res://heart_catalog.gd")
const ClassActions = preload("res://native_class_actions.gd")
const Skills = preload("res://skill_catalog.gd")
const Classes = preload("res://class_catalog.gd")
const Weapons = preload("res://weapon_system.gd")
const Seeds = preload("res://seed_catalog.gd")
const Enemies = preload("res://enemy_catalog.gd")
const Stage = preload("res://stage.gd")
const Progress = preload("res://progress.gd")
const AttackGeometry=preload("res://attack_geometry.gd")
const Transactions=preload("res://game_transaction.gd")
const GuardedTitleSession=preload("res://guarded_title_session.gd")
var persistence_session := GuardedTitleSession.new()
const SaveBatch=preload("res://save_batch.gd")
var transaction_publishes: Array=[]
var encounter_kills: Array=[]
var guardian_counts: Array=[0,0,0]
var encounter_rewarded:=false
var reward_retry_at:=0
const Director=preload("res://combat_director.gd")
const Learning=preload("res://wilds_learning.gd")
var combat_threat: Dictionary={}
var combat_velocity: Dictionary={}
var combat_last_positions: Dictionary={}
var encounter_kill_records: Array=[]
const MonsterRewards=preload("res://monster_rewards.gd")
var monster_rewards:=MonsterRewards.new()
const DepartureSettlement=preload("res://departure_settlement.gd")
var departure_settlement:=DepartureSettlement.new()
var next_kill_reward_flush:=0
var moving_ranged_hits:=0
var encounter_started_at:=0
var encounter_party_size:=1
const PartyTravel=preload("res://party_travel.gd")
const Network=preload("res://network_settings.gd")
const WorldSnapshot = preload("res://world_snapshot.gd")
const WorldReplication = preload("res://world_replication.gd")
const ReplicationSource = preload("res://world_replication_source.gd")
var replication := WorldReplication.new()
var replication_source := ReplicationSource.new(self)
var network_dialog: Window
const WorldGuidance = preload("res://ui/gameplay/world_guidance.gd")
const WorldPresentation = preload("res://world_presentation.gd")
const AppSettings=preload("res://app_settings.gd")
const MouseCombat=preload("res://mouse_combat.gd")
var app_settings:=AppSettings.new()
var settings_path: String="user://settings.cfg"
var settings_dialog: Window
var mouse_controls:=MouseCombat.new()
const HOST := 1
const COURIER_ANCIENT_OPTION := 1000 # Ordinary parts start at 1001.
static var PORT: int=clampi(int(OS.get_environment("MYSTICAL_GARDEN_TEST_PORT")),1024,65535) if not OS.get_environment("MYSTICAL_GARDEN_TEST_PORT").is_empty() else 24576
const MAX_HEALTH := 10
const ENEMY_HEALTH := 3
const GuestReplication = preload("res://guest_replication.gd")
const GuestWorld = preload("res://guest_replication_world.gd")
var guest_replication := GuestReplication.new(ENEMY_HEALTH)
var guest_replication_world := GuestWorld.new(self)
const WALK_SPEED := 5.5
const RANGED_DISTANCE := 2.75
const ENGAGE_RADIUS := 8.0
const SCOUT_RADIUS := 1.45
const DODGE_DISTANCE := 2.8
const DODGE_COOLDOWN_MS := Cooldowns.BASELINE_DODGE_MS
const EncounterConfig=preload("res://encounter_config.gd")
const CHECKPOINT_INTERVAL := EncounterConfig.UPGRADE_INTERVAL
const EXTRACTION_INTERVAL := EncounterConfig.EXTRACTION_INTERVAL
const LoadoutMaterials=preload("res://loadout_materials.gd")
const ROUTE_ROOMS := EncounterConfig.BIOME_LENGTH
const ExpeditionWallet = preload("res://expedition_wallet.gd")
const Cooldowns = preload("res://player_cooldowns.gd")
const WeaponActions = preload("res://player_weapon_actions.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const AffinityCards = preload("res://affinity_cards.gd")
const GRAFT_ROOM := EncounterConfig.GRAFT_INTERVAL
const Parts = preload("res://weapon_parts.gd")
const Frames = preload("res://weapon_frames.gd")
const Character = preload("res://character_profile.gd")
const Battlefield = preload("res://battlefield.gd")
const PACK_STRIDE := 8
const SPORE_RADIUS := 1.75
const SPORE_RANGE := 6.2
const Campaign = preload("res://campaign.gd")

@onready var stage: Stage = $Stage
@onready var ui = $GameplayUI

var active_character_slot:=-1
var character_slot_claimed:=false
var character_storage_root:="user://saves/characters"
var active_slot := -1
var slot_claimed := false
var slot_heartbeat_at := 0.0
var slot_storage_root := "user://saves"
var returning_to_title := false
var progress := Progress.new()
var local_character := Character.new()
var guest_character := Character.new()
var character_dirty := false
var players := {}
var participation := preload("res://expedition_participation.gd").new()
var network_session := preload("res://network_session.gd").new()
var motions := {}
var enemy_kind := 0
var enemy_death_serial:=0
var enemy_death_events: Array=[]
const WeaponMotion=preload("res://weapon_motion.gd")
var combat_events: Array=[]
var combat_event_serial:=0
const WeaponAttackQueue = preload("res://weapon_attack_queue.gd")
const WeaponAttackWorld = preload("res://weapon_attack_world.gd")
const ResolvedBuild = preload("res://resolved_combat_build.gd")
var combat_builds := ResolvedBuild.Cache.new()
var weapon_attacks: WeaponAttackQueue = WeaponAttackQueue.new()
var weapon_attack_world := WeaponAttackWorld.new(self)
var enemy_mutations := 0
var enemy_growth := 0
var burst_hits_this_room := 0
var choke_kills_this_room := 0
var burst_clears := 0
var choke_clears := 0
const EnemyTactics = preload("res://enemy_tactics.gd")
const LeaderBehavior = preload("res://leader_behavior.gd")
const ScoutBehavior = preload("res://scout_behavior.gd")
const EnemyFormation = preload("res://enemy_formation.gd")
var tactics := EnemyTactics.new(Stage.ENEMY_START)
const EncounterRoster = preload("res://encounter_roster.gd")
var encounter := EncounterRoster.new(ENEMY_HEALTH)
var battlefield := Battlefield.new()
var run_guardians := 0
var map_rng := RandomNumberGenerator.new()
var pressure_at := 0
var damage_this_room := 0
var ranged_damage_this_room := 0
var ranged_clears := 0
const WildFlora = preload("res://wild_flora.gd")
var wild_flora := WildFlora.new()
var rng := RandomNumberGenerator.new()
var deepest_milestone := 0
var checkpoint_pending:=false
var checkpoint_ready: Dictionary={}
const Altar=preload("res://altar_service.gd")

var toast_until := 0
var status := "The Heart shelters this Garden. Follow the path to the Wilds gate.":
	set(value):
		status = value
		toast_until = Time.get_ticks_msec() + 4800
var net_motion=preload("res://network_movement.gd").new()
var network_compatibility: Node
const Bosses=preload("res://boss_encounters.gd")
const EnemyBehaviors=preload("res://enemy_behaviors.gd")
var boss_floors: Dictionary={}
var used_bosses: Array=[]
var enemy_hazards: Array=[]
var enemy_hazard_serial: int=0
const Traits=preload("res://combat_traits.gd")
var enemy_traits: Dictionary={}
var effect_timeline := preload("res://combat_effect_timeline.gd").new()
var native_effects_world := preload("res://native_effects_world.gd").new(self)
const Life=preload("res://expedition_life.gd")
var cultivation := preload("res://garden_cultivation_world.gd").new(self)
var garden_commands := preload("res://garden_commands_world.gd").new(self)
var garden_presentation := preload("res://garden_presentation_world.gd").new(self)
var world_view: WorldPresentation
var spectator_view: Node

const Items=preload("res://item_catalog.gd")
const InventoryModel=preload("res://inventory_model.gd")
var wild_item_drops: Array=[]
var actor_presentation := preload("res://actor_presentation_world.gd").new(self)
const CharacterAppearance=preload("res://character_appearance.gd")
const LOOK_NAMES=CharacterAppearance.OPTIONS
var growth_clock := 0.0


func _init() -> void:
	guest_character.path = Life.Preview.STORAGE_PATH.path_join("character-local-guest.cfg") if Life.Preview.playtest else "user://character-local-guest.cfg"


func _ready() -> void:
	mouse_controls.attack_requested.connect(func(peer: int, origin: Vector3, now: int): weapon_attacks.try_start(weapon_attack_world, peer, origin, now))
	if has_meta(&"experimental_terrain") and not preload("res://assets/terrain_m02/experimental/experiment_mode.gd").verified():
		set_process(false)
		set_physics_process(false)
		_refuse_unowned_world.call_deferred()
		return
	if has_meta(&"experimental_terrain") or preload("res://persistence_writer_integration.gd").default_route(get_tree()):
		var owner_context: Variant = persistence_session if persistence_session.is_guarded() else null
		if not (owner_context is GuardedTitleSession) or not owner_context.authorizes(local_character.path) or (not network_session.joined_from_title() and not owner_context.authorizes(progress.path)):
			set_process(false)
			set_physics_process(false)
			_refuse_unowned_world.call_deferred()
			return
	get_tree().auto_accept_quit = false
	toast_until = Time.get_ticks_msec() + 4800
	if not persistence_session.is_guarded():
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
	configure_gameplay_ui()
	settings_dialog=preload("res://settings_panel.gd").new()
	settings_dialog.developer_context=self
	add_child(settings_dialog)
	settings_dialog.applied.connect(ui.redraw_hud)
	var deaths=preload("res://enemy_death_effects.gd").new()
	deaths.name="DeathEffects";deaths.stage=stage;stage.add_child(deaths)
	var effects=preload("res://combat_effects.gd").new()
	effects.name="CombatEffects";effects.stage=stage;stage.add_child(effects)
	var map=preload("res://exploration.gd").new()
	map.name="Exploration";add_child(map)
	world_view=WorldPresentation.new(stage,deaths,effects,map,event_audio,soundscape)
	spectator_view=preload("res://spectator_view.gd").new()
	spectator_view.configure(ui)
	spectator_view.refresh_requested.connect(func(peer: int):spectator_view.present(actor_presentation.spectator_frame(peer)))
	add_child(spectator_view)
	if not persistence_session.is_guarded():
		var result := progress.load_garden()
		if result != OK and result != ERR_FILE_NOT_FOUND:
			status = "Could not read Garden save (error %d)." % result
	var garden_terrain = preload("res://assets/terrain_m02/experimental/experiment_garden.gd").new()
	stage.add_child(garden_terrain)
	garden_terrain.configure(self,stage)
	network_compatibility=preload("res://network_compatibility.gd").new()
	add_child(network_compatibility)
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(func(id): session_world.remove(id))
	multiplayer.connected_to_server.connect(session_world.joined)
	multiplayer.connection_failed.connect(session_world.connection_failed)
	multiplayer.server_disconnected.connect(session_world.server_disconnected)
	add_player(HOST)
	diagnostic_watch=preload("res://diagnostic_watch.gd").new();diagnostic_watch.game=self;add_child(diagnostic_watch)
	preload("res://menu_button_roots.gd").watch(self,func():return app_settings.values.get("ambient_motion",true))

func _refuse_unowned_world() -> void:
	var menu = load("res://main_menu.tscn").instantiate()
	menu.return_message = "Open a Garden or join from the title to claim the save first."
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	queue_free()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT: mouse_controls.release(self)
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if persistence_session.is_blocked() and not persistence_session.is_guarded():
			get_tree().quit()
			return
		if expedition_transitions.request_guest_exit(Session.Exit.APPLICATION): return
		if persistence_session.is_guarded():
			if not prepare_guarded_exit(): return
			persistence_session.begin_shutdown()
			session_world.offline()
			release_slot()
			get_tree().quit()
			return
		if network_session.role() in ["Host","Solo"] and participation.active():
			if not expedition_transitions.finish_voluntary(): return
		if character_dirty and persistence_session.can_write() and not save_local_character():
			return
		get_tree().quit()


func configure_keys() -> void:
	app_settings.path=settings_path;app_settings.load_settings();app_settings.apply()


func configure_gameplay_ui() -> void:
	ui.requested.connect(_handle_ui_request)
	ui.overlay_opened.connect(func():
		var preview = preload("res://ability_aim.gd").active(self)
		if preview != null: preview.cancel())
	var entries: Array = []
	for definition in Enemies.all(): entries.append({"name":definition.name,"description":definition.description})
	ui.fill_bestiary(entries)
	ui.configure_arena_menu(FileAccess.file_exists("res://neural_arena/arena_entry.gd"))
	for feature in ["inventory","progression","loadout","graft","altar","planting","summary"]:
		var path: String = {"inventory":"inventory_panel","progression":"progression_panel",
			"loadout":"loadout_panel","graft":"affinity_grafting_panel","altar":"garden_altar_panel",
			"planting":"planting_panel","summary":"run_summary_panel"}[feature]
		var view = load("res://"+path+".gd").new()
		ui.mount_feature(feature,view)
	network_dialog=preload("res://network_panel.gd").new()
	add_child(network_dialog)
	network_dialog.applied.connect(func(address: String,port: int,_join: bool):
		var saved := Network.save_settings(slot_storage_root,address,port)
		if saved!=OK: Journal.event("network","preference_save_failed",{"error":saved},"warning")
		if session_world.join(address,port)!=OK:
			network_dialog.begin(address,port,true,str(local_character.data.get("name","Wanderer")),Transactions.feedback_text(self,status)))
	var drops=preload("res://inventory_drop_visuals.gd").new()
	drops.name="InventoryDrops";drops.configure(stage)
	drops.refresh_requested.connect(func():drops.present(actor_presentation.drop_frame(spectator_view.target_peer(),world_view.sight_radius())))
	add_child(drops)
	var garden_view=preload("res://garden_interaction_view.gd").new()
	garden_view.name="GardenInteractions";garden_view.configure(stage,ui)
	garden_presentation.bind(garden_view);add_child(garden_view)

func request_host_session() -> void:
	if network_session.role()=="Solo" and session_world.host()!=OK: return
	if network_session.role()=="Host": network_dialog.begin_host(network_session.port(),Network.lan_addresses(),"Your Garden",not participation.active())

func _handle_ui_request(command: String, data: Dictionary) -> void:
	# Presentation requests go through the same authorized domain operations as keys/RPCs.
	match command:
		"settings":
			mouse_controls.release(self)
			settings_dialog.begin(app_settings)
		"save":
			if persistence_session.is_blocked() and not persistence_session.is_guarded():
				recover_departure_cleanup()
			else: save_progress(HOST,"Garden saved.")
		"host": request_host_session()
		"join": request_ip_join()
		"leave":
			if not expedition_transitions.request_guest_exit(Session.Exit.SESSION): session_world.leave("Back in your own Garden.")
		"abandon": request_abandon_run()
		"arena_open":
			if FileAccess.file_exists("res://neural_arena/arena_entry.gd"): load("res://neural_arena/arena_entry.gd").open_from(self)
		"title": request_main_menu()
		"confirm_abandon": send_garden_action("abandon_run")
		"confirm_title": return_to_main_menu()
		"cancel_connection":
			network_session.cancel_join()
			connection_rejected("Connection cancelled. Your character is preserved.")
		"appearance": send_garden_action("look_"+str(data.index))
		"ready": send_travel_ready(bool(data.unready))
		"checkpoint": send_garden_action(affinity_checkpoint_action(int(data.revision),str(data.choice)))
		"bank":
			var value := int(data.value)
			send_garden_action("bank_ancient_0" if value==COURIER_ANCIENT_OPTION else "bank_part_%d"%(value-1000) if value>=1000 else "bank_seed_%d"%value)
		"refresh_progression": ui.present_progression(progression_ui_data(data))
		"close_progression":
			if bool(data.from_crafting) and at_weapon_gate(players.get(local_player_id(),{})): open_gate_preparation()
			else: ui.close_panels()
		"refresh_inventory": ui.present_inventory(inventory_ui_data())
		"refresh_loadout": ui.present_loadout(loadout_ui_data())
		"refresh_summary": ui.present_summary(run_summary_ui_data())
		"inventory_transfer": send_inventory_action("transfer",str(data.source),str(data.target),str(data.item),int(data.quantity))
		"garden_action": send_garden_action(str(data.action))
		"altar_action": send_altar_action(str(data.operation),data.draft.duplicate(true),int(data.revision))
		"depart":
			if party_travel_state().get("ready",false): send_travel_ready(true)
			else: send_garden_action("depart")
		"inventory_drop": send_inventory_action("drop",str(data.source),"",str(data.item),int(data.quantity))














@rpc("any_peer", "call_remote", "reliable")
func register_character(identity: String, profile: Dictionary,catalog: Dictionary={},protocol: int=0) -> void:
	session_world.register(multiplayer.get_remote_sender_id(),identity,profile,catalog,protocol)

func add_player(id: int) -> void:
	if not multiplayer.is_server():
		return
	var link := network_session.admit_peer(id,Time.get_ticks_msec(),local_character.identity if id == HOST else "",id == HOST)
	if link == null:
		network_session.refuse_unregistered(id)
		return
	var party_slot := link.slot()
	var spawn: Vector3 = Stage.SPAWN + [Vector3.ZERO,Vector3(1.1,0,0),Vector3(-1.1,0,0),Vector3(0,0,1.1)][party_slot]
	var base_health:=Life.Preview.hp(MAX_HEALTH)
	players[id] = {Session.STATE:link,"velocity":Vector3.ZERO,"damage_seq":0,"damage_amount":0,"pos": spawn, Participation.STATE: participation.attach(id), PlayerLifecycle.STATE: PlayerLifecycle.start_life(), "lost_health":0, "prepared": 0, "weapon": 0, ExpeditionWallet.STATE: ExpeditionWallet.Wallet.new(), "upgrade_seed":Crypto.new().generate_random_bytes(8).hex_encode().hash(),
		"weapon_kind":0, "catalyst":0, "prepared_catalyst":0, "cargo_plan":Parts.empty_counts(), "frame": Frames.WARDEN, Cooldowns.STATE: Cooldowns.Timers.new(), Protection.STATE: Protection.State.new(), WeaponActions.STATE: WeaponActions.State.new(), "contributed": false,
		"character": local_character.data if id == HOST else Character.blank(),
		"seed_choice": 0, "carried_seeds": [],"safe_items":[],"carried_items":{}, "pouch": false,
		"donation_choice": Parts.EMPTY, "cache_claimed": false,
		"carried_parts": Parts.empty_counts(), "secondary": Parts.EMPTY,
		"prepared_secondary": Parts.EMPTY, Conditions.STATE: Conditions.State.new(), PlayerVitals.STATE: PlayerVitals.Health.new(float(base_health), base_health), "facing": Vector3.FORWARD}
	restore_class_loadout(players[id])
	preload("res://garden_growth_service.gd").register(self,id)


func _input(event: InputEvent) -> void:
	if preload("res://ability_aim.gd").release_event(self,event):
		get_viewport().set_input_as_handled()
		return
	if ui.cinematic_active():return
	if settings_dialog!=null and settings_dialog.visible: return
	if stage != null and stage.experimental_garden != null and stage.experimental_garden.build_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("run_summary") and ui.summary_input(event,network_session.role()!="Connecting" and not returning_to_title
			and Participation.is_wild(players.get(local_player_id(),{}))):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("session_menu"):
		if ui.is_overlay_open(): ui.close_panels()
		else: ui.toggle_panel("session")
	elif event.is_action_pressed("pack_menu"):
		ui.toggle_panel("pack")
	elif event.is_action_pressed("workbench"):
		ui.toggle_panel("loadout")
	elif event.is_action_pressed("progression"):
		ui.toggle_panel("progression")
	elif event.is_action_pressed("field_guide"):
		ui.toggle_panel("guide")
	else:
		return
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if stage.experimental_garden != null and event is InputEventMouseMotion:
		if stage.experimental_garden.placement_input(event): get_viewport().set_input_as_handled()
	if event is InputEventMouseButton: _unhandled_key_input(event)

func _unhandled_key_input(event: InputEvent) -> void:
	if stage.experimental_garden != null and stage.experimental_garden.placement_input(event):
		get_viewport().set_input_as_handled()
		return
	if ui.cinematic_active():return
	if settings_dialog!=null and settings_dialog.visible: return
	if stage.experimental_garden != null and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B:
		if stage.experimental_garden.can_view_development():
			stage.experimental_garden.open_development()
			get_viewport().set_input_as_handled()
			return
	mouse_controls.frame(self)
	if network_session.role()=="Connecting" or (network_session.role()=="Guest" and not guest_replication.has_details()):
		if event.is_action_pressed("session_menu"): connection_rejected("Connection cancelled. Your character is preserved.")
		return
	if ui.panel_is_open("checkpoint"):
		for index in 4:
			if event.is_action_pressed(["upgrade_power","upgrade_technique","upgrade_synergy","upgrade_fourth"][index]):
				ui.choose_checkpoint(str(index))
				get_viewport().set_input_as_handled()
				return
	if ui.is_overlay_open():
		return
	if preload("res://card_active_actions.gd").input_event(self,event):
		get_viewport().set_input_as_handled()
		return
	if preload("res://ability_aim.gd").input_event(self,event):
		get_viewport().set_input_as_handled()
		return
	var local_player: Dictionary=players.get(HOST if multiplayer.is_server() else multiplayer.get_unique_id(),{})
	if not Participation.is_wild(local_player):
		for old_action in ["research","experiment","catalyst","graft","donate","select_donation","destination","trait","frame","expand_plot"]:
			if event.is_action_pressed(old_action): return
		if event.is_action_pressed("craft") and nearby_plot(local_player.get("pos",Vector3.INF))<0: return
	if event.is_action_pressed("interact"):
		send_action(false)
	elif event.is_action_pressed("pouch"):
		send_garden_action("pouch")
	elif event.is_action_pressed("research"):
		send_garden_action("research")
	elif event.is_action_pressed("flower"):
		get_node("GardenInteractions").flower_shortcut()
	elif event.is_action_pressed("catalyst"):
		send_garden_action("catalyst")
	elif event.is_action_pressed("craft"):
		send_garden_action("craft")
	elif event.is_action_pressed("expand_plot"):
		send_garden_action("expand_plot")
	elif event.is_action_pressed("extract"):
		send_garden_action("extract")
	elif event.is_action_pressed("graft"):
		send_garden_action("graft")
	elif event.is_action_pressed("donate"):
		send_garden_action("donate")
	elif event.is_action_pressed("select_donation"):
		send_garden_action("select_donation")
	elif event.is_action_pressed("destination"):
		send_garden_action("destination")
	elif event.is_action_pressed("trait"):
		send_garden_action("trait")
	elif event.is_action_pressed("frame"):
		send_garden_action("frame")
	elif event.is_action_pressed("dodge"):
		var direction := Input.get_vector("left", "right", "up", "down")
		if multiplayer.is_server():
			dodge_player(HOST, direction)
		elif network_session.role() == "Guest":
			request_dodge.rpc_id(HOST, direction)


func send_action(strike: bool) -> void:
	if not strike:
		var peer := multiplayer.get_unique_id()
		var actor: Dictionary = players.get(peer, {})
		var flora := wild_flora_view(peer)
		var field := battlefield if multiplayer.is_server() else stage.visual_field
		if WildFlora.within_reach(flora, actor.get("pos", Vector3.INF), field.clear_line) and Life.nearest(self, actor) == 0:
			var ground_item := nearest_inventory_drop(actor) if multiplayer.is_server() else nearest_visible_inventory_drop(actor)
			if ground_item.is_empty():
				send_wild_flora_harvest(flora.identity)
				return
	if multiplayer.is_server():
		act(HOST, strike)
	elif network_session.role() == "Guest":
		request_action.rpc_id(HOST, strike)


func send_garden_action(action: String) -> void:
	if not persistence_session.pending_notice().is_empty(): return
	if not (action.begins_with("core_cast:") or action.begins_with("class_cast:")): Journal.interaction(self,multiplayer.get_unique_id(),action,"requested")
	if action in ["class_skill","class_skill_two"] and encounter_cleared(): return
	if multiplayer.is_server():
		garden_action(HOST, action)
	elif network_session.role() == "Guest":
		var actor: Dictionary = players.get(multiplayer.get_unique_id(),{})
		if action in ["class_skill","class_skill_two"] or (action == "research" and Participation.is_wild(actor)):
			action = preload("res://ability_aim.gd").request_native(self,actor,0 if action == "class_skill" else 1)
		if not action.is_empty(): request_garden_action.rpc_id(HOST, action)


@rpc("any_peer", "call_remote", "reliable")
func request_garden_action(action: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or action.length()>512: return
	if action in ["class_skill","class_skill_two"] or (action == "research" and Participation.is_wild(players.get(id,{}))): return
	if action.begins_with("guest_projection:"):
		if not session_world.allow_remote(id,"profile_receipt",120,true): return
		var fields := action.split(":")
		if fields.size()==5 and fields[2].is_valid_int():
			guest_projection_status(id,fields[1],int(fields[2]),fields[3],fields[4])
		return
	if session_world.allow_remote(id,"action",30): garden_action(id, action)


func garden_action(id: int, action: String) -> void:
	if action.begins_with("card_cast:"):
		if not persistence_session.can_simulate(): return
		preload("res://card_active_actions.gd").command(self,id,players.get(id,{}),action)
		return
	if action.begins_with("core_cast:"):
		if not persistence_session.can_simulate(): return
		preload("res://core_combat.gd").command(self,id,players.get(id,{}),action)
		return
	if action.begins_with("class_cast:"):
		if not persistence_session.can_simulate(): return
		preload("res://ability_aim.gd").command(self,id,players.get(id,{}),action)
		return
	if not persistence_session.can_write(): return
	var diagnostic_request:=Journal.interaction(self,id,action,"begin")
	var persistent: bool=action=="donate" or action.begins_with("care_")
	if persistent and not persistence_session.is_guarded(): Transactions.run(self,func(): _garden_action(id,action))
	else: _garden_action(id,action)
	Journal.interaction(self,id,action,"end",diagnostic_request)

func _garden_action(id: int, action: String) -> void:
	if not players.has(id):
		return
	var player: Dictionary = players[id]
	if action=="spring_fill":
		cultivation.fill_water(id);return
	if action.begins_with("growth_ack:"):
		preload("res://garden_growth_service.gd").acknowledge(self,id,action.trim_prefix("growth_ack:"));return
	if action.begins_with("garden:"):
		garden_commands.command(id,action.trim_prefix("garden:"));return
	if PlayerLifecycle.fallen(player) and Participation.is_wild(player) and action!="abandon_run" and not action.begins_with("abandon_run:"): return
	if not Session.ready_for(player):
		return
	if action.begins_with("revive:"):
		var target:=action.get_slice(":",1)
		if target.is_valid_int(): revive_player(id,int(target))
		return
	if action.begins_with("altar:"):
		handle_altar_action(id,player,action.trim_prefix("altar:"))
		return
	if action.begins_with("inventory:"):
		handle_inventory_action(id,player,action.trim_prefix("inventory:"))
		return
	if action.begins_with(preload("res://expedition_grafts.gd").COMMAND):
		var result := _purchase_expedition_graft(id, player, action)
		graft_feedback(id,player,result)
		show_graft_menu(id)
		return
	if action=="abandon_run" or action.begins_with("abandon_run:"):
		expedition_transitions.abandon(id,action.trim_prefix("abandon_run:") if action.begins_with("abandon_run:") else "")
		return
	if garden_commands.handle(id,action):return
	if action.begins_with("travel_ready:") or action.begins_with("travel_unready:"):
		var token:=action.get_slice(":",1)
		if not token.is_valid_int() or int(token)!=participation.travel_epoch() or participation.travel_kind().is_empty(): return
		if action.begins_with("travel_unready:"): participation.withdraw(id,int(token))
		else: PartyTravel.request(self,id,participation.travel_kind())
		return
	if action=="depart":
		if at_weapon_gate(player):
			expedition_transitions.enter(id)
			if Participation.is_wild(player) and not persistence_session.is_guarded(): close_flow_for(id)
		return
	if action.begins_with(AffinityCards.COMMAND):
		_affinity_checkpoint_command(id, player, action)
		return
	if action.begins_with("bank_"):
		bank_checkpoint_item(id,player,action)
		return
	if (action.begins_with("class_") and action not in ["class_skill","class_skill_two"]) or action.begins_with("loadweapon_") or action.begins_with("loadpart_") or action.begins_with("pack_") or action.begins_with("learn_") or action.begins_with("respec_") or action=="clearpack":
		handle_loadout_action(id,player,action)
		return
	if action.begins_with("look_"):
		var choice := action.trim_prefix("look_")
		var index := int(choice) if choice.is_valid_int() else -1
		if not Participation.is_wild(player) and CharacterAppearance.option_field(index) >= 0 and action == "look_"+str(index):
			if persistence_session.is_guarded() and id != HOST:
				run_guarded_action(id,Transactions.Scope.GARDEN,func(effects):
					player.character.appearance = CharacterAppearance.cycle_option(player.character.appearance,index)
					save_action_profile(id,effects))
				return
			var applied := Transactions.run_gameplay(self, Transactions.Scope.PROFILE, func():
				player.character.appearance = CharacterAppearance.cycle_option(player.character.appearance,index)
				if not persistence_session.is_guarded(): publish_character(id)
				return true, false)
			if Transactions.committed(applied.persistence): record_character(id)
		return
	match action:
		"expand_plot":
			tell(id,"Select a planting-bed node in Heart / Knowledge to begin its research.")
		"extract":
			expedition_transitions.checkpoint(id,false)
		"destination":
			if id == HOST and not Participation.is_wild(player) and not participation.active() and stage.gate_position().distance_to(player.pos) <= preload("res://gate_interaction.gd").RANGE:
				cycle_destination()
		"donate":
			if Participation.is_wild(player):
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
		"graft":
			if Participation.is_wild(player):
				show_graft_menu(id)
			elif at_weapon_gate(player):
				cycle_slot(id, player, "prepared_secondary", player.prepared)
		"frame":
			if not Participation.is_wild(player) and not participation.active() and Stage.HEART.distance_to(player.pos) <= 1.7:
				select_class(id,player,(int(player.frame)+1)%Classes.DEFINITIONS.size())
		"class_skill_two":
			ClassActions.cast_world(self,id,1)
		"class_skill":
			ClassActions.cast_world(self,id)
		"pouch":
			if Participation.is_wild(player) and not player.pouch:
				tell(id,InventoryModel.transfer(self,player,"carry","pouch","unidentified_seed",1))
		"research":
			if Participation.is_wild(player):
				ClassActions.cast_world(self,id,1)
			elif not Participation.is_wild(player) and not participation.active() and Stage.HEART.distance_to(player.pos) <= 1.7:
				use_heart_research(id)
		"catalyst":
			if at_weapon_gate(player):
				cycle_slot(id,player,"prepared_catalyst",0)
		"craft":
			if not Participation.is_wild(player) and nearby_plot(player.pos) >= 0:
				var slot:=nearby_plot(player.pos)
				if progress.plots[slot].species<0: show_planting_picker(id,slot)
			elif at_weapon_gate(player):
				cycle_slot(id, player, "prepared", player.prepared_secondary)
		"flower":
			var slot := nearby_plot(player.pos)
			if slot>=0:cultivation.harvest_seeds(id,slot)


func cycle_destination() -> void:
	for offset in range(1, Campaign.BIOME_COUNT + 1):
		var site := (participation.route() + offset) % Campaign.BIOME_COUNT
		if progress.campaign.available(site):
			participation.select_route(site)
			break
	for id in players:
		tell(id, "Selected %s. Entry costs %d shared plant parts." % [
			Campaign.NAMES[participation.route()], Campaign.SHORTCUT_COST[participation.route()]])


func enemy_name() -> String:
	if tactics.boss_kind>=0: return Enemies.get_kind(tactics.boss_kind).name
	return ("Longlimb " if tactics.longlimb else "Elite ")+Enemies.get_kind(enemy_kind).name+" · "+preload("res://elite_enemy.gd").empowered(enemy_kind)



func campaign_snapshot() -> PackedInt32Array:
	var flags := 0
	for i in progress.campaign.cleared.size():
		if progress.campaign.cleared[i]:
			flags |= 1 << i
	# Protocol 41 reserves campaign words 2–5 and 17. Active biomes use none of them.
	var result := PackedInt32Array([participation.route(), flags, 0, 0, 0, 0,
		roundi(tactics.active_radius * 100.0), 0, participation.seed(), participation.floor(),
		participation.cycle(), maxi(0, ceili((pressure_at - CombatClock.now()) / 1000.0)),
		progress.campaign.best_clear, progress.campaign.best_extraction,
		progress.campaign.memories[0], progress.campaign.memories[1], progress.campaign.memories[2],
		0, Enemies.encode(enemy_kind, enemy_mutations, enemy_growth)])
	result.append_array(encounter.scout_codes())
	result.append(roundi(tactics.landing.x * 100.0))
	result.append(roundi(tactics.landing.z * 100.0))
	result.append(int(tactics.attack_mode == "vault"))
	result.append(tactics.boss_kind)
	result.append(tactics.boss_phase)
	return result


func at_heart(player: Dictionary) -> bool:
	return not player.is_empty() and not Participation.is_wild(player) and Stage.HEART.distance_to(player.get("pos",Vector3.INF)) <= 1.7


func selected_donation(player: Dictionary) -> int:
	var parts: Array = seed_reserve(player).parts
	var choice: int = player.donation_choice
	return choice if choice != Parts.EMPTY and parts[choice] > 0 else next_part(Parts.EMPTY, parts, Parts.EMPTY)


# An expedition savepoint includes transient input, event and random state.
# Both writers restore it on confirmed rollback.
func snapshot_expedition_runtime() -> Dictionary:
	return {"map_rng":map_rng.state, "heal_rng":Life.Preview.heal_rng.state, "battlefield":battlefield, "wild_flora":wild_flora.savepoint(),
		"mouse":Transactions.snapshot(mouse_controls), "weapons":weapon_attacks.savepoint(), "effects":effect_timeline.savepoint(),
		"aim_visible":is_instance_valid(mouse_controls.marker) and mouse_controls.marker.visible}

func restore_expedition_runtime(state: Dictionary) -> void:
	map_rng.state=state.map_rng
	Life.Preview.heal_rng.state=state.heal_rng
	battlefield=state.battlefield
	wild_flora.restore(state.wild_flora)
	Transactions.restore(mouse_controls,state.mouse)
	weapon_attacks.restore_savepoint(state.weapons)
	effect_timeline.restore_savepoint(state.effects)
	if is_instance_valid(mouse_controls.marker): mouse_controls.marker.visible=state.aim_visible

func run_guarded_action(id: int, scope: Transactions.Scope, action: Callable) -> Dictionary:
	var effects: Array[Callable] = []
	var first_event := combat_event_serial
	var already_settling := departure_settlement.is_settling()
	var result := Transactions.run_gameplay(self, scope, action.bind(effects))
	if not already_settling and departure_settlement.is_settling():
		_resolve_departure_settlement(result.persistence)
	var committed := Transactions.committed(result.persistence)
	if not result.notice.is_empty():
		if network_session.transport() != null and multiplayer.is_server() and persistence_session.is_blocked():
			for peer_id in multiplayer.get_peers():
				if Session.ready_for(players.get(peer_id, {}),false): tell(peer_id,result.notice)
		elif id != HOST:
			tell(id, result.notice)
	if committed:
		for event in combat_events:
			if persistence_session.is_guarded() and int(event.id)>first_event: publish_combat_event(event)
		for effect in effects:
			effect.call()
		if persistence_session.is_blocked() and persistence_session.can_publish_state() and multiplayer.is_server():
			replication_source.publish_committed_cleanup.call_deferred(network_session.transport())
	return result

func record_settlement_metric(effects,event: String,fields: Dictionary) -> void:
	var record := func(): preload("res://game_metrics.gd").record(event,fields)
	if effects == null: record.call()
	else: effects.append(record)

func action_feedback(effects, id: int, message: String) -> void:
	if effects == null:
		tell(id, message)
	else:
		effects.append(tell.bind(id, message))

func donate_part(id: int, player: Dictionary) -> void:
	if persistence_session.is_guarded():
		run_guarded_action(id, Transactions.Scope.GARDEN, func(effects): _donate_part(id, player, effects))
	else:
		_donate_part(id, player, null)

func _donate_part(id: int, player: Dictionary, effects) -> void:
	var part := selected_donation(player)
	if part == Parts.EMPTY:
		action_feedback(effects, id, "Extract with a weapon part to donate it.")
		return
	seed_reserve(player).parts[part] -= 1
	progress.add_parts(part, 1)
	var message := "Donated %s to the shared Garden." % Parts.part_name(part)
	if effects == null:
		save_progress(id, message)
	else:
		action_feedback(effects, id, message)


func award_combat_progress() -> void:
	flush_kill_rewards()

func _defers_kill_profiles() -> bool:
	return persistence_session.is_guarded()

func flush_kill_rewards() -> bool:
	if persistence_session.is_blocked():
		return false
	# The active floor pays run loot promptly and banks Class XP
	# at a checkpoint. Disconnected profiles use the departure settlement owner.
	if _defers_kill_profiles() and participation.active() and departure_settlement.is_empty():
		return true
	if persistence_session.is_guarded() or (not SaveBatch.active and not departure_settlement.is_empty()):
		if not monster_rewards.has_pending() and departure_settlement.is_empty():
			return true
		if Life.living_ids(self).is_empty() and departure_settlement.has_wild_departure():
			return expedition_transitions.finish_failed()
		var result := run_guarded_action(HOST, Transactions.Scope.PAIR, func(effects):
			settle_expedition_rewards(effects, true)
			return true)
		return Transactions.committed(result.persistence)
	if monster_rewards.has_pending() and not Transactions.run(self, _apply_pending_kill_rewards):
		return false
	if not SaveBatch.active:
		_publish_kill_reward_notices(monster_rewards.take_legacy_notices())
	return true

## Only an admitted character can supply personal credit.
func expedition_stat_identity(peer: int) -> String:
	if not players.has(peer) or not participation.contains(peer): return ""
	return _kill_reward_identity(peer, players[peer])

## Entry markers and frozen summaries share one ordered, reliable channel.
func publish_expedition_results() -> void:
	var entries := expedition_statistics.take_entries()
	var finished := expedition_statistics.publishable()
	if entries.is_empty() and finished.is_empty(): return
	for peer in players:
		var identity := _kill_reward_identity(peer,players[peer])
		if entries.has(identity): send_expedition_result(peer,identity,entries[identity],{})
		if identity in finished:
			var report := expedition_statistics.result_for(identity)
			send_expedition_result(peer,identity,report.run,report)

func send_expedition_result(peer: int, identity: String, run: int, report: Dictionary) -> void:
	var connection := network_session.connection_key(peer)
	if not report.is_empty():
		Journal.event("expedition","result_published",{"actor":peer,"run":run,"outcome":report.outcome,"participants":report.players.size()})
	if peer == HOST:
		if is_instance_valid(ui): ui.expedition_result(connection,run,report)
	elif network_session.transport() != null and multiplayer.get_peers().has(peer) and network_session.identity(peer) == identity:
		receive_expedition_result.rpc_id(peer,connection,identity,run,report)

@rpc("authority","call_remote","reliable")
func receive_expedition_result(connection: String, identity: String, run: int, report: Dictionary) -> void:
	if network_session.permits_details(connection) and identity == network_session.accepted_identity():
		ui.expedition_result(connection,run,report)

func _kill_reward_identity(id: int, player: Dictionary) -> String:
	return local_character.identity if id == HOST else Session.inventory_owner(player)

func _queue_monster_reward(spawn_token: String, kind: int, mask: int, world_position: Vector3, leader: bool, summoned := false) -> bool:
	if not multiplayer.is_server() or not persistence_session.can_write():
		return false
	var candidates: Array[Dictionary] = []
	if not summoned:
		for id in players:
			var player: Dictionary = players[id]
			candidates.append({
				"id": id, "identity": _kill_reward_identity(id, player), "class": int(player.get("frame", Frames.WARDEN)),
				"profile_ready": Session.ready_for(player,false), "wild": Participation.is_wild(player), "fallen": PlayerLifecycle.fallen(player),
			})
	var death := {"depth":participation.floor(), "kind":kind, "position":world_position, "leader":leader, "summoned":summoned}
	var key := monster_rewards.admit_kill(participation.epoch(), spawn_token, death, candidates, roll_kill_trophy.bind(kind, mask, leader), rng.randf)
	if key.is_empty():
		return false
	for award in monster_rewards.experience_awards(key):
		expedition_statistics.count(participation.run_id(),award.identity,"xp",award.xp)
	if _defers_kill_profiles():
		var receipt := monster_rewards.take_run_awards(key)
		if not receipt.is_empty():
			var notices: Array[Dictionary] = []
			for reward: Dictionary in receipt.rewards:
				notices.append(_apply_run_kill_reward(receipt, reward, players[reward.id]))
			if not SaveBatch.guarded_active():
				_publish_kill_reward_notices(notices, false, true)
	return true

func _apply_pending_kill_rewards(effects = null, departure_work: Array[Dictionary] = []) -> bool:
	var notices: Array[Dictionary] = []
	var live_profiles: Dictionary = {}
	for receipt in monster_rewards.stage_pending():
		for reward: Dictionary in receipt.rewards:
			var id: int = reward.id
			var player: Dictionary = players.get(id, {})
			var is_live: bool = not player.is_empty() and _kill_reward_identity(id, player) == reward.identity
			if not is_live:
				player = {}
				for entry in departure_work:
					if entry.peer_id == id and entry.identity == reward.identity:
						player = entry.actor
						break
			if player.is_empty():
				continue
			var profile: Dictionary = player.character
			var class_id: int = reward["class"]
			var kind: int = receipt.kind
			profile.xp[class_id] = mini(Character.Experience.MAX_XP, int(profile.xp[class_id]) + int(reward.xp))
			profile.monsters[kind] = mini(9999, int(profile.monsters[kind]) + 1)
			# DepartureSettlement banks detached profiles with protected cargo.
			if not is_live:
				continue
			if effects == null:
				publish_character(id)
			else:
				live_profiles[id] = true
			if not receipt.run_rewards_granted:
				notices.append(_apply_run_kill_reward(receipt, reward, player))
	if effects == null:
		monster_rewards.defer_legacy_notices(notices)
	else:
		for id in live_profiles:
			save_action_profile(id, effects)
		if not notices.is_empty():
			effects.append(_publish_kill_reward_notices.bind(notices, true))
	return true

func _apply_run_kill_reward(receipt: Dictionary, reward: Dictionary, player: Dictionary) -> Dictionary:
	var id: int = reward.id
	grant_run_essence(id, player, int(reward.essence))
	if int(receipt.epoch) == participation.epoch():
		var at: Vector3 = receipt.position
		var drop_id := "%s:%d" % [receipt.key, id]
		if not reward.item.is_empty():
			wild_item_drops.append({"id":drop_id, "owner":id, "stack":{"item":reward.item,"quantity":1}, "position":[at.x, at.y, at.z]})
		if not reward.boss_seed.is_empty():
			at.x += 0.7
			wild_item_drops.append({"id":drop_id+":seed", "owner":id, "stack":reward.boss_seed.duplicate(true), "position":[at.x, at.y, at.z]})
	return {"id":id, "identity":reward.identity, "essence":reward.essence, "xp":reward.xp, "parts":int(not reward.item.is_empty())}

func _publish_kill_reward_notices(notices: Array[Dictionary], require_profile := false, xp_pending := false) -> void:
	var totals := {}
	for notice in notices:
		var id: int = notice.id
		if not players.has(id) or _kill_reward_identity(id, players[id]) != notice.identity:
			continue
		if not totals.has(id):
			totals[id] = {"essence":0, "xp":0, "parts":0}
		totals[id].essence += int(notice.essence)
		totals[id].xp += int(notice.xp)
		totals[id].parts += int(notice.parts)
	for id in totals:
		# A frozen recipient may lose its transport before reward feedback.
		if id != HOST and not multiplayer.get_peers().has(id): continue
		var notice: Dictionary = totals[id]
		var essence := int(notice.essence) / float(Director.config().essence_sparks_per_point)
		var message := "+%.2f essence · +%d class XP%s%s" % [essence, notice.xp, " pending" if xp_pending else "", " · Monster part nearby" if notice.parts > 0 else ""]
		if require_profile:
			tell_profile_action(id, message)
		else:
			tell(id, message)

func _capture_pending_departure(id: int, player: Dictionary) -> void:
	var snapshot := {
		"character": player.character,
		"projection_base": player.get("projection_base", {}),
		"wild": Participation.is_wild(player),
		"pouch": player.pouch,
		"safe_items": player.safe_items,
		"carried_seeds": player.carried_seeds,
		"garden_run_actor": player.get("garden_run_actor", ""),
		"garden_run_id": player.get("garden_run_id", ""),
	}
	departure_settlement.register(id, Session.inventory_owner(player), snapshot)

func _resolve_departure_settlement(boundary: Dictionary) -> void:
	var execution: Variant = boundary.get("value")
	var final: SaveBatch.Finalization = execution.get("outcome") if execution is Dictionary else null
	if final == null:
		departure_settlement.finish(DepartureSettlement.Result.UNCERTAIN)
		persistence_session.require_departure_recovery()
		return
	match final.outcome:
		SaveBatch.Outcome.COMMITTED:
			if final.write_blocked or boundary.release_error != OK:
				departure_settlement.finish(DepartureSettlement.Result.CLEANUP_PENDING)
			else:
				departure_settlement.finish(DepartureSettlement.Result.COMMITTED)
		SaveBatch.Outcome.ABORTED_RESTORED:
			departure_settlement.finish(DepartureSettlement.Result.RESTORED)
		SaveBatch.Outcome.COMMITTED_CLEANUP_PENDING:
			departure_settlement.finish(DepartureSettlement.Result.CLEANUP_PENDING)
		SaveBatch.Outcome.UNCERTAIN:
			departure_settlement.finish(DepartureSettlement.Result.UNCERTAIN)

func settle_expedition_rewards(effects: Array[Callable], bank_kills := false) -> void:
	var settle_kills := bank_kills or not _defers_kill_profiles()
	var waiting_on_rewards: Array[String] = []
	if not settle_kills:
		waiting_on_rewards = monster_rewards.pending_profile_ids()
	var work := departure_settlement.stage(waiting_on_rewards)
	if settle_kills:
		_apply_pending_kill_rewards(effects, work)
	for entry in work:
		var leaving: Dictionary = entry.actor
		if not Session.inventory_owner(leaving).is_empty():
			record_character(entry.peer_id, leaving)
		_recover_pouch(leaving)
		if Participation.is_wild(leaving):
			garden_commands.return_outcome(preload("res://garden_return_service.gd").Member.new(str(leaving.get("garden_run_actor","")),str(leaving.get("garden_run_id","")),bool(leaving.get("wild",false))),"disconnected")
		expedition_statistics.settled_disconnect(entry.identity)
		monster_rewards.finish_expedition(entry.identity, participation.run_id())

func close_flow_for(id: int) -> void:
	if id==HOST: close_run_flow_panel()
	elif network_session.transport()!=null and multiplayer.get_peers().has(id): close_run_flow_panel.rpc_id(id)

func revive_player(id: int, target: int) -> void:
	if persistence_session.is_guarded():
		run_guarded_action(id, Transactions.Scope.PAIR, func(effects): return Life.revive(self, id, target, effects))
	else:
		Transactions.run(self, func(): return Life.revive(self, id, target))

func wallet_for(player: Dictionary) -> ExpeditionWallet.Wallet:
	return player.get(ExpeditionWallet.STATE)


func run_wallet(player: Dictionary) -> int:
	var wallet := wallet_for(player)
	if wallet == null or not Participation.is_wild(player):
		return 0
	return wallet.balance(deepest_milestone, int(Director.config().essence_sparks_per_point))


func _plan_essence_debit(player: Dictionary, cost: int) -> ExpeditionWallet.Wallet:
	var wallet := wallet_for(player)
	if not multiplayer.is_server() or wallet == null or not Participation.is_wild(player):
		return null
	return wallet.plan_debit(cost, deepest_milestone, int(Director.config().essence_sparks_per_point))


func grant_run_essence(id: int, player: Dictionary, sparks: int) -> void:
	if not multiplayer.is_server() or not is_same(players.get(id), player) or not Participation.is_wild(player):
		return
	var wallet := wallet_for(player)
	if wallet != null:
		player[ExpeditionWallet.STATE] = wallet.credit_sparks(sparks)


func record_character(id: int, actor: Dictionary = {}) -> void:
	var player: Dictionary = players[id] if actor.is_empty() else actor
	var owner_context: String=local_character.identity if id==HOST else Session.inventory_owner(player)
	var record := {"profile":player.character.duplicate(true),"manifest":progress.ContentIDs.manifest()}
	var base: Dictionary = player.get("projection_base", {})
	if persistence_session.is_guarded() and id!=HOST and not base.is_empty():
		var projection = load("res://guest_profile_projection.gd")
		var prior: Dictionary = progress.character_records.get(owner_context, {}).get("projection", {})
		record.profile = Character.normalize(player.character)
		if prior.get("digest") == projection.digest(record.profile): return
		var descriptor: Dictionary = projection.build(record.profile, int(prior.get("revision",0))+1, base)
		if descriptor.is_empty():
			SaveBatch.record_serializer_error(ERR_OUT_OF_MEMORY, progress.path)
			return
		record.projection = descriptor
	progress.character_records[owner_context] = record

# The host stores the Garden's character record. A guest alone owns its
# canonical profile and receives the existing reliable ordered projection.
func actor_profile_scope(id: int) -> Transactions.Scope:
	return Transactions.Scope.PAIR if id == HOST else Transactions.Scope.GARDEN

func save_action_profile(id: int, effects) -> void:
	if effects == null or not persistence_session.is_guarded():
		publish_character(id)
		return
	record_character(id)
	if id != HOST:
		effects.append(send_committed_profile.bind(id))

func send_committed_profile(id: int) -> void:
	if multiplayer.is_server() and network_session.transport() != null and multiplayer.get_peers().has(id) and players.has(id):
		var player: Dictionary = players[id]
		var record: Dictionary = progress.character_records.get(Session.inventory_owner(player),{})
		if not record.has("projection"): return
		var revision: int = record.projection.revision
		var delivery: Dictionary = player.get("projection_delivery",{})
		if delivery.get("revision") != revision:
			player.projection_delivery = {"revision":revision,"state":"pending","feedback":delivery.get("feedback",[])}
		receive_character.rpc_id(id,{"profile":record.profile,"origin":progress.projection_origin,"projection":record.projection,"departure_receipt":network_session.departure_receipt(id)})

func tell_profile_action(id: int, message: String) -> void:
	if id == HOST or not persistence_session.is_guarded():
		tell(id,message)
		return
	var delivery: Dictionary = players.get(id,{}).get("projection_delivery",{})
	if delivery.get("state") in ["committed","cleanup_pending"]:
		tell(id,message)
	elif delivery.get("state") in ["pending","received"] and delivery.feedback.size() < 8:
		delivery.feedback.append(message)

func guest_projection_status(id: int, origin: String, revision: int, digest: String, disposition: String) -> void:
	if not persistence_session.is_guarded() or network_session.role()!="Host" or not multiplayer.is_server() or origin!=progress.projection_origin: return
	var player: Dictionary = players.get(id,{})
	var delivery: Dictionary = player.get("projection_delivery",{})
	var current: Dictionary = progress.character_records.get(Session.inventory_owner(player),{}).get("projection",{})
	if delivery.get("revision")!=revision or current.get("revision")!=revision or current.get("digest")!=digest: return
	if not disposition in ["received","committed","cleanup_pending","aborted","uncertain","refused"]: return
	if delivery.state in ["committed","cleanup_pending"] or (disposition=="received" and delivery.state!="pending"): return
	delivery.state = disposition
	if disposition in ["committed","cleanup_pending"]:
		player.projection_base = {"revision":revision,"digest":digest}
		for message in delivery.feedback: tell(id,message)
		delivery.feedback.clear()
	elif disposition in ["aborted","uncertain","refused"]:
		delivery.feedback.clear()
		Journal.event("save","guest_projection_unconfirmed",{"actor":id,"revision":revision,"state":disposition},"warning")

func publish_character(id: int) -> void:
	if persistence_session.is_guarded(): return
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
	if network_session.role() != "Guest": return
	var departure: String = str(profile.get("departure_receipt",""))
	if persistence_session.is_guarded():
		if not profile.get("origin") is String or not profile.get("projection") is Dictionary or not profile.get("profile") is Dictionary: return
		var origin: String = profile.origin
		var descriptor: Dictionary = profile.projection
		profile = profile.profile
		if not persistence_session.can_write():
			var projection = load("res://guest_profile_projection.gd")
			if origin == get_meta(&"guest_projection_origin","") and projection.valid_origin(origin) and projection.valid_descriptor(descriptor,profile):
				_report_guest_projection(origin,descriptor,"refused")
			return
		if save_guest_projection(profile,origin,descriptor): expedition_transitions.confirm_guest_exit(departure)
		return
	if profile.has("projection") or not Character.Experience.supported(profile): return
	guest_character.data = Character.normalize(profile)
	character_dirty = true
	if save_local_character(): expedition_transitions.confirm_guest_exit(departure)

func save_guest_projection(profile: Dictionary, origin: String, descriptor: Dictionary) -> bool:
	if not Character.Experience.supported(profile): return false
	var projection = load("res://guest_profile_projection.gd")
	profile = Character.normalize(profile)
	if origin!=get_meta(&"guest_projection_origin","") or not projection.valid_origin(origin) or not projection.valid_descriptor(descriptor,profile):
		return false
	var receipt: Dictionary = guest_character.projection_receipts.get(origin,{"revision":0,"digest":""})
	if descriptor.revision < receipt.revision: return false
	if descriptor.revision == receipt.revision:
		if descriptor.digest != receipt.digest: return false
		if get_meta(&"guest_projection_uncertain_revision",0)==descriptor.revision:
			_report_guest_projection(origin,descriptor,"uncertain")
			return false
		if network_session.role()=="Guest" and not persistence_session.can_write() and not persistence_session.can_publish_state(): return false
		_report_guest_projection(origin,descriptor,"committed")
		return true
	var local_digest: String = projection.digest(guest_character.data)
	if not ((receipt.revision==descriptor.base_revision and local_digest==descriptor.base_digest)
		or (receipt.revision>descriptor.base_revision and local_digest==receipt.digest)):
		_report_guest_projection(origin,descriptor,"refused")
		set_meta(&"guest_projection_notice","Profile update conflicts with newer local data. Reconnect after reviewing the saves.")
		return false
	if not guest_character.projection_receipts.has(origin) and guest_character.projection_receipts.size()>=projection.MAX_RECEIPTS:
		_report_guest_projection(origin,descriptor,"refused")
		return false
	_report_guest_projection(origin,descriptor,"received")
	var saved := Transactions.run_gameplay(self, Transactions.Scope.GUEST_PROFILE, func():
		guest_character.data = profile.duplicate(true)
		guest_character.projection_receipts[origin] = {"revision":descriptor.revision,"digest":descriptor.digest}
		return true)
	var committed := Transactions.committed(saved.persistence)
	if committed: character_dirty = false
	var execution: Variant = saved.persistence.get("value")
	var final: SaveBatch.Finalization = execution.get("outcome") if execution is Dictionary else null
	var disposition := "refused"
	if final != null:
		disposition = ["committed","aborted","cleanup_pending","uncertain"][final.outcome]
		if final.outcome == SaveBatch.Outcome.UNCERTAIN:
			set_meta(&"guest_projection_uncertain_revision",descriptor.revision)
	_report_guest_projection(origin,descriptor,disposition)
	if not committed and persistence_session.pending_notice().is_empty():
		set_meta(&"guest_projection_notice","Profile update not saved. Reconnect to reconcile it.")
	elif committed and has_meta(&"guest_projection_notice"):
		remove_meta(&"guest_projection_notice")
	return committed

func _report_guest_projection(origin: String, descriptor: Dictionary, disposition: String) -> void:
	if network_session.transport() != null and multiplayer.get_peers().has(HOST):
		request_garden_action.rpc_id(HOST,"guest_projection:%s:%d:%s:%s"%[origin,descriptor.revision,descriptor.digest,disposition])


func save_local_character() -> bool:
	if persistence_session.is_blocked(): return false
	var active := guest_character if network_session.role() == "Guest" else local_character
	if persistence_session.is_guarded():
		var scope := Transactions.Scope.GUEST_PROFILE if network_session.role() == "Guest" else Transactions.Scope.PROFILE
		var saved := Transactions.run_gameplay(self, scope, func(): return true)
		if Transactions.committed(saved.persistence): character_dirty = false
		return saved.completed
	if active.save_profile() == OK:
		character_dirty = false
		return true
	status = "Character progress could not be saved."
	return false




func skill_area_targets(center: Vector3,radius: float,origin: Vector3) -> Array[int]:
	var result: Array[int]=[]
	for target in range(-1,encounter.scout_count()):
		if encounter.hp(target)<=0: continue
		var point:=enemy_position(target)
		if center.distance_to(point)<=radius and battlefield.clear_line(origin,point) and battlefield.clear_line(center,point): result.append(target)
	return result

func skill_line_targets(origin: Vector3,facing: Vector3,distance: float,width: float,limit: int) -> Array[int]:
	var result: Array[int]=[]
	var ordered: Array=[]
	var fraction: float = battlefield.projectile_block_fraction(origin,origin+facing*distance,width)
	var cover_distance := fraction * distance if fraction != INF else INF
	for target in range(-1,encounter.scout_count()):
		if encounter.hp(target)<=0: continue
		var point := enemy_position(target)
		var offset := point - origin
		var along := offset.dot(facing)
		if along >= 0.0 and along <= distance and along + .00001 < cover_distance \
				and (offset-facing*along).length()<=width and battlefield.projectile_clear(origin,point):
			ordered.append({"id":target,"distance":along})
	ordered.sort_custom(func(a,b): return a.distance<b.distance)
	for item in ordered:
		if result.size()>=limit: break
		result.append(int(item.id))
	return result

func graft_altar_open() -> bool:
	return participation.floor() % GRAFT_ROOM == 0


func at_graft_altar(player: Dictionary) -> bool:
	var location: Vector3=battlefield.graft if multiplayer.is_server() else stage.visual_field.graft
	return not player.is_empty() and Participation.is_wild(player) and graft_altar_open() and location.distance_to(player.get("pos",Vector3.INF))<=1.65

func _purchase_expedition_graft(id: int, player: Dictionary, action: String) -> String:
	if not multiplayer.is_server() or not persistence_session.can_write() \
			or not Life.alive(player) or not Session.ready_for(player,false) or not is_same(players.get(id,{}),player):
		return "This graft purchase is unavailable."
	if not at_graft_altar(player) or not participation.travel_kind().is_empty():
		return "Use the current Grafting Altar before leaving the floor."
	var grafts = preload("res://expedition_grafts.gd")
	var request_data := grafts.decode_request(action)
	if request_data.is_empty():
		return "That graft request is invalid."
	var ledger := grafts.active_ledger(player)
	if ledger == null:
		return grafts.EXPIRED
	var project_stats := combat_build(player).graft_value_resolver(MAX_HEALTH,int(player.get("lost_health",0)),PlayerVitals.temporary_hp(player))
	var purchase := ledger.plan_purchase(request_data, participation.floor(), player.carried_parts, project_stats)
	if purchase.has("ledger"):
		# The host installs the successor and debits inventory in the same
		# synchronous command before publishing any receipt or projection.
		var carry: Array = player.carried_parts.duplicate()
		carry[purchase.part] = int(carry[purchase.part]) - int(purchase.cost)
		player.carried_parts = carry
		player[grafts.STATE] = purchase.ledger
		expedition_statistics.count(participation.run_id(),expedition_stat_identity(id),"grafts")
		if purchase.has("health"):
			var health: PlayerVitals.Health = player[PlayerVitals.STATE]
			player[PlayerVitals.STATE] = health.with_native_max_hp(int(purchase.health) - health.temporary_hp())
		var receipt: Dictionary = purchase.receipt
		Journal.event("grafting","improvement_acquired",{"actor":id,"run":ledger.identity(),"floor":receipt.floor,
			"serial":receipt.serial,"improvement":receipt.id,"item":receipt.item,"quantity":purchase.cost})
	return purchase.message










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
	if not at_weapon_gate(player): return
	if persistence_session.is_guarded():
		run_guarded_action(id, actor_profile_scope(id), func(effects): _cycle_slot(id, player, slot, effects))
	else:
		_cycle_slot(id, player, slot, null)

func _cycle_slot(id: int, player: Dictionary, slot: String, effects) -> void:
	for offset in range(1,Parts.DEFINITIONS.size()+1):
		var candidate: int=(int(player[slot])+offset)%Parts.DEFINITIONS.size()
		if candidate==0 or (Parts.is_plant(candidate) and LoadoutMaterials.remaining(stored_counts(player),LoadoutMaterials.choices(player),LoadoutMaterials.FIELDS.find(slot),candidate)>0):
			player[slot]=candidate
			persist_loadout(id,player,effects)
			action_feedback(effects,id,"%s: %s" % [slot.trim_prefix("prepared").replace("_"," ").strip_edges(),Parts.part_name(candidate)])
			return


func available_parts(player: Dictionary, part: int) -> int:
	return int(seed_reserve(player).parts[part]) + progress.part_count(part)


func upgrade_checkpoint_open() -> bool:
	return participation.floor() % CHECKPOINT_INTERVAL == 0 and encounter_cleared()


func extraction_checkpoint_open() -> bool:
	return participation.floor() % EXTRACTION_INTERVAL == 0 and encounter_cleared()








func guarded_growth_tick(elapsed: float) -> void:
	if not persistence_session.can_simulate(): return
	var in_wilds := participation.active()
	var original: Array = progress.plots.duplicate(true)
	var crop_due := progress.advance_growth(elapsed, in_wilds)
	if not crop_due: return
	var updated: Array = progress.plots.duplicate(true)
	progress.plots.assign(original)
	progress.sync_plot_flags()
	var message := Transactions.save_growth_checkpoint(self, updated)
	if not message.is_empty(): status = message

func run_heart_save(action: Callable) -> String:
	var result := Transactions.run_gameplay(self, Transactions.Scope.GARDEN, action)
	return Transactions.feedback(result, "Research could not be saved.")

func use_heart_research(id: int) -> void:
	if id!=HOST:
		tell(id,"The host chooses the Garden's research.")
	show_heart_tree(id)

@rpc("any_peer", "call_remote", "reliable")
func request_action(strike: bool) -> void:
	if multiplayer.is_server() and session_world.allow_remote(multiplayer.get_remote_sender_id(),"action",30):
		act(multiplayer.get_remote_sender_id(), strike)


@rpc("any_peer", "call_remote", "reliable")
func request_dodge(direction: Vector2) -> void:
	if multiplayer.is_server() and direction.is_finite() and session_world.allow_remote(multiplayer.get_remote_sender_id(),"action",30):
		dodge_player(multiplayer.get_remote_sender_id(), direction.limit_length())


@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_motion(direction: Vector2) -> void:
	var id := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and direction.is_finite() and session_world.allow_remote(id,"motion",120):
		motions[id] = [direction.limit_length(), CombatClock.now()]


@rpc("any_peer", "call_remote", "unreliable_ordered",3)
func submit_movement(commands: Array,epoch: String) -> void:
	var id:=multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not players.has(id) or not Session.ready_for(players[id],false) or not session_world.allow_remote(id,"motion",120):return
	net_motion.accept(id,commands,epoch,net_motion.world_key(self,players[id]),CombatClock.now())


func _physics_process(delta: float) -> void:
	if persistence_session.is_blocked() or persistence_session.is_guarded():
		if returning_to_title or persistence_session.is_stopping(): return
		if persistence_session.is_blocked():
			if multiplayer.is_server() and persistence_session.can_publish_state():
				send_expedition_state(delta)
			return
		if not persistence_session.can_simulate(): return
	if multiplayer.is_server():net_motion.frame(delta,players)
	mouse_controls.frame(self)
	var direction := Vector2.ZERO if ui.is_overlay_open() or ui.cinematic_active() else Input.get_vector("left", "right", "up", "down")
	if multiplayer.is_server():
		var now := CombatClock.now()
		growth_clock += delta
		if growth_clock >= 1.0:
			var elapsed := growth_clock
			growth_clock = 0.0
			if persistence_session.is_guarded():
				guarded_growth_tick(elapsed)
			else:
				if progress.advance_growth(elapsed,participation.active()) and progress.save_garden() != OK:
					status = "Plant growth could not be saved. Use Save Garden to retry."
		if persistence_session.is_blocked(): return
		motions[HOST] = [direction, now]
		for id in players:
			players[id].velocity=Vector3.ZERO
			if id!=HOST and net_motion.servers.has(id):
				net_motion.server_tick(self,id,delta,now)
			elif motions.has(id) and now - int(motions[id][1]) < 250:
				move_player(id, motions[id][0], delta)
		mouse_controls.tick(self,now)
		if participation.active() and encounter_cleared() and not encounter_rewarded and now>=reward_retry_at: finish_combat(HOST,tactics.position)
		if persistence_session.is_blocked(): return
		weapon_attacks.advance(weapon_attack_world, now)
		if persistence_session.is_blocked(): return
		effect_timeline.advance_native(native_effects_world,now)
		if persistence_session.is_blocked(): return
		if participation.active():
			preload("res://warden_combat.gd").tick(self,now)
			if persistence_session.is_blocked(): return
			preload("res://weaver_combat.gd").tick(self,now)
			if persistence_session.is_blocked(): return
			var elapsed := preload("res://affinity_time.gd").advance(self,delta)
			preload("res://void_affinity.gd").resolve_motion(self,elapsed,now)
			preload("res://frost_combat.gd").tick(self,now)
			preload("res://fire_combat.gd").tick(self,elapsed,now)
			if persistence_session.is_blocked(): return
			preload("res://water_combat.gd").tick(self,elapsed)
			preload("res://vital_combat.gd").tick(self,elapsed)
			preload("res://thorn_affinity.gd").tick(self,elapsed,now)
			preload("res://wood_affinity.gd").tick(self,elapsed)
			preload("res://spirit_affinity.gd").tick(self,elapsed)
			if persistence_session.is_blocked(): return
		preload("res://combat_status.gd").sync(self,now)
		attract_loot(delta)
		Bosses.tick_hazards(self,now)
		if persistence_session.is_blocked(): return
		if participation.active() and encounter_cleared() and not encounter_rewarded and now>=reward_retry_at: finish_combat(HOST,tactics.position)
		if now>=next_kill_reward_flush:
			next_kill_reward_flush=now+150
			flush_kill_rewards()
		if persistence_session.is_blocked(): return
		update_combat_tracking(delta)
		tick_enemies(delta, now)
		if persistence_session.is_blocked(): return
		preload("res://core_combat.gd").tick(self,now)
		if persistence_session.is_blocked(): return
		update_pressure(now)
		if persistence_session.can_publish_state():
			send_expedition_state(delta)
	elif network_session.role() == "Guest":
		var commands: Array=net_motion.client_tick(self,multiplayer.get_unique_id(),direction,delta)
		if not commands.is_empty():submit_movement.rpc_id(HOST,commands,net_motion.epoch)


## Advances enemy behaviour for one physics step. The Neural Arena replaces this step.
func tick_enemies(delta: float, now: int) -> void:
	LeaderBehavior.tick(self, delta, now)
	if persistence_session.is_blocked(): return
	ScoutBehavior.tick(self, delta, now)


func send_expedition_state(delta: float,force := false) -> void:
	replication.publish(replication_source,delta,force)


func move_player(id: int, direction: Vector2, delta: float) -> void:
	var p: Dictionary = players[id]
	if Participation.is_wild(p) and not Life.alive(p): p.velocity=Vector3.ZERO;return
	var move := world_direction(direction)
	if not move.is_zero_approx() and (not Participation.is_wild(p) or not p.get("mouse_aim",false)):
		p.facing = move.normalized()
	var guard_speed: float=p[Protection.STATE].movement_scale(CombatClock.now())
	var stride := preload("res://spirit_affinity.gd").scale(p,preload("res://affinity_time.gd").now(self)) if p.has("affinity_spirit_strides") else 1.0
	if p.has("ranger_speed_grants"):
		stride = maxf(stride,preload("res://ranger_combat.gd").speed_scale(self,p,CombatClock.now()))
	var desired := bound_position(p.pos + move * WALK_SPEED * guard_speed * stride * p[Conditions.STATE].movement_scale(CombatClock.now()) * delta, Participation.is_wild(p))
	var previous: Vector3=p.pos
	if Participation.is_wild(p):
		p.pos = battlefield.slide(p.pos, desired)
		if p.has("affinity_spirit_follow"):
			preload("res://spirit_affinity.gd").movement(self,p,previous,p.pos)
	elif stage.experimental_garden != null:
		p.pos = stage.experimental_garden.slide(previous, desired)
	else:
		p.pos = desired
	p.velocity=(p.pos-previous)/maxf(delta,.001)


func world_direction(direction: Vector2) -> Vector3:
	return Vector3(direction.x, 0, direction.y).rotated(Vector3.UP, atan2(3.3, 14.0))


func bound_position(position_next: Vector3, wild: bool = false) -> Vector3:
	if not wild: return position_next # The Garden's continuous barrier resolves its movement.
	return Vector3(clampf(position_next.x,Battlefield.REGION.position.x+0.5,Battlefield.REGION.end.x-0.5),0,clampf(position_next.z,Battlefield.REGION.position.y+0.5,Battlefield.REGION.end.y-0.5))


func dodge_player(id: int, direction: Vector2) -> void:
	if not players.has(id) or not direction.is_finite(): return
	var p: Dictionary=players[id]
	var now:=CombatClock.now()
	var resolved:=combat_build(p)
	p[Cooldowns.STATE]=p[Cooldowns.STATE].configure_dodge(resolved.dodge_capacity(),now)
	if not Life.alive(p) or not p[Cooldowns.STATE].ready(Cooldowns.DODGE,now): return
	var facing:=world_direction(direction).normalized()
	if facing.is_zero_approx(): facing=p.facing
	var previous: Vector3=p.pos
	var landing:=battlefield.dash(previous,bound_position(previous+facing*DODGE_DISTANCE,true))
	if not landing.is_finite() or landing.distance_to(previous)<preload("res://spirit_affinity.gd").MIN_STEP: return
	var prepared:=preload("res://spirit_affinity.gd").claim_recovery(self,p,now)
	p[Cooldowns.STATE]=p[Cooldowns.STATE].start(Cooldowns.DODGE,now,resolved.dodge_ms(DODGE_COOLDOWN_MS,prepared))
	p.facing=facing
	p.pos=landing
	preload("res://spirit_affinity.gd").movement(self,p,previous,p.pos)
	preload("res://spirit_affinity.gd").voluntary(self,id,previous,p.pos,now)


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


func make_scout(kind: int, world_position: Vector3, route: int, mutations: int = 0, growth: int = 0, juvenile: bool = false) -> Dictionary:
	var definition := Enemies.get_kind(kind)
	var hp := Director.Balance.scout_hp(definition,participation.floor(),participation.cycle(),growth,encounter_party_size,juvenile)
	return {"spawn_token":encounter.reserve_token(),"pos": world_position, "kind": kind, "mutations": mutations | (Enemies.JUVENILE if juvenile else 0),
		"growth": growth, "hp": hp,
		"windup": 0, "ready": 0, "rooted_until": 0, "recovery": 0, "engaged": juvenile,
		"ranged": Enemies.ranged(kind), "blast": world_position, "route": route,
		"stagger_until": 0, "mode": "", "repeat": 0, "summons": 0, "haste_until": 0,
		"max_hp": hp,
		"variant": "" if juvenile else preload("res://enemy_variants.gd").choose(self,kind,route)}


func can_vault(from: Vector3, to: Vector3) -> bool:
	if battlefield.clear_line(from, to, Battlefield.CLEARANCE) or battlefield.occupied(to, Battlefield.CLEARANCE):
		return false
	for step in 13:
		if not battlefield.inside_floor(from.lerp(to, step / 12.0), Battlefield.CLEARANCE):
			return false
	return true

func encounter_cleared() -> bool:
	if multiplayer.is_server():
		return encounter.cleared()
	return guest_replication.enemy_hp() <= 0 and living_scout_count() == 0


func closest_enemy(origin: Vector3, visible_only: bool = false) -> int:
	var primary_visible := enemy_health() > 0 and (not visible_only or battlefield.clear_line(origin, tactics.position))
	var index := -1 if primary_visible else -2
	var best := origin.distance_squared_to(tactics.position) if primary_visible else INF
	for i in encounter.scout_count():
		if encounter.hp(i) > 0 and origin.distance_squared_to(encounter.scout(i).pos) < best and (
				not visible_only or battlefield.clear_line(origin, encounter.scout(i).pos)):
			index = i
			best = origin.distance_squared_to(encounter.scout(i).pos)
	return index


func enemy_position(index: int) -> Vector3:
	return tactics.position if index == -1 else encounter.position(index)


func enemy_health(target: int = -1) -> int:
	if multiplayer.is_server():
		return encounter.hp(target)
	return guest_replication.enemy_hp(target)


func scout_snapshot(now: int) -> PackedFloat32Array:
	return encounter.scout_pack(now)


func act(id: int, strike: bool) -> void:
	var request:=Journal.interaction(self,id,"interact","begin") if not strike else 0
	_act(id,strike)
	if not strike:Journal.interaction(self,id,"interact","end",request)

func _act(id: int, strike: bool) -> void:
	if strike:
		if not persistence_session.can_simulate(): return
	elif not persistence_session.can_write(): return
	if not players.has(id) or not Session.ready_for(players[id]):
		return
	var p: Dictionary = players[id]
	if Participation.is_wild(p) and not Life.alive(p): return
	var pos: Vector3 = p.pos
	var rescue:=Life.nearest(self,p)
	if not strike and rescue!=0:
		revive_player(id,rescue)
	elif strike:
		weapon_attacks.try_start(weapon_attack_world, id, pos, CombatClock.now())
	elif nearest_inventory_drop(p)!="":
		pickup_inventory_drop(id,p,nearest_inventory_drop(p))
	elif Participation.is_wild(p) and battlefield.has_seed_cache() and (
			not p.cache_claimed and pos.distance_to(battlefield.cache) <= 1.55):
		var reserve := seed_reserve(p)
		var kind := progress.roll_seed(reserve, p.carried_seeds, [], participation.route(), rng.randf(), participation.floor())
		p.carried_seeds.append(kind)
		p.cache_claimed = true
		tell(id, "Seed found. Extract to keep it.")
	elif not Participation.is_wild(p) and pos.distance_to(stage.gate_position()) <= preload("res://gate_interaction.gd").RANGE:
		show_gate_preparation(id)
	elif Participation.is_wild(p) and at_graft_altar(p) and preload("res://gate_interaction.gd").shrine_preferred(battlefield,pos):
		show_graft_menu(id)
	elif Participation.is_wild(p):
		if pos.distance_to(battlefield.advance) <= preload("res://gate_interaction.gd").RANGE:
			expedition_transitions.checkpoint(id,true)
		else:
			tell(id, "Move closer to the seed or a checkpoint.")
	elif not Participation.is_wild(p) and garden_commands.interact(id):
		pass
	elif at_heart(p):
		show_heart_tree(id)
	elif pos.distance_to(stage.altar_position()) <= 1.65:
		show_garden_altar(id)
	else:
		var kind := nearby_plot(pos)
		if kind >= 0:
			if progress.plots[kind].species >= 0:
				if int(progress.plots[kind].stage)<3:cultivation.focus(id,kind)
				else:cultivation.harvest(id, kind)
			else:
				show_planting_picker(id,kind)
		else:
			tell(id, "Move closer to the altar, a plot, or the gate.")


func nearby_plot(pos: Vector3) -> int:
	var count: int = progress.plots.size() if multiplayer.is_server() else guest_replication.garden_progress()[12].size() / 3
	for i in count:
		if pos.distance_to(stage.bed_position(i)) <= 1.55:
			return i
	return -1


func finish_combat(id: int,_loot_position: Vector3) -> void:
	if persistence_session.is_guarded():
		if not persistence_session.can_write() or not participation.active() or encounter_rewarded or not encounter_cleared(): return
		run_guarded_action(id, Transactions.Scope.PAIR, func(effects):
			settle_expedition_rewards(effects, true)
			_finish_combat(id,effects))
		if not encounter_rewarded: reward_retry_at=CombatClock.now()+1000
		return
	if not flush_kill_rewards(): return
	Transactions.run(self,func(): _finish_combat(id))
	if not encounter_rewarded: reward_retry_at=CombatClock.now()+1000

func _finish_combat(id: int,effects = null) -> void:
	if encounter_rewarded: return
	encounter_rewarded=true
	expedition_statistics.clear_encounter(participation.run_id(),participation.floor())
	record_settlement_metric(effects,"encounter_clear",{"floor":participation.floor(),"biome":participation.route(),"kills":encounter_kills.size(),"cycle":participation.cycle()})
	burst_clears+=int(burst_hits_this_room>=2)
	choke_clears+=int(choke_kills_this_room>=3)
	if effects == null: award_combat_progress()
	var ranged_evidence:=Life.Vitals.counts_as_ranged(ranged_damage_this_room,damage_this_room,Life.Preview.scale())
	if ranged_evidence: ranged_clears+=1
	var previous_memory: Dictionary=progress.wilds_memory.score.duplicate()
	var skill_evidence:=preload("res://wilds_skill_tactics.gd").evidence(self)
	var learned: Dictionary={"ranged":ranged_evidence,"burst":burst_hits_this_room>=2,"choke":choke_kills_this_room>=3 and choke_kills_this_room*2>=encounter_kills.size(),"kite":moving_ranged_hits>=3 and CombatClock.now()-encounter_started_at>=8000}
	for tactic in skill_evidence: learned[tactic]=int(skill_evidence[tactic])>0
	Learning.observe(progress.wilds_memory,learned,participation.floor())
	record_settlement_metric(effects,"wilds_learning",{"floor":participation.floor(),"encounters":progress.wilds_memory.encounters,"scores":progress.wilds_memory.score.duplicate(),"skill_evidence":skill_evidence,"party":encounter_party_size,"elapsed_ms":CombatClock.now()-encounter_started_at})
	deepest_milestone=maxi(deepest_milestone,participation.floor())
	if participation.depth()==ROUTE_ROOMS: run_guardians|=1 << participation.route();guardian_counts[participation.route()]+=1
	tactics.winding_up=false
	if encounter_cleared():
		var cue := "extract_ready" if extraction_checkpoint_open() else "gate_ready"
		preload("res://event_audio.gd").emit(self,cue,battlefield.advance)
	action_feedback(effects,id,"Encounter cleared." +Learning.notice(previous_memory,progress.wilds_memory.score))


func wild_entry(id: int) -> Vector3:
	var slot: int=Session.slot_for(players.get(id,{}),0)
	var offset: Vector3=[Vector3(-.65,0,-.45),Vector3(.65,0,-.45),Vector3(-.65,0,.65),Vector3(.65,0,.65)][clampi(slot,0,Network.MAX_PLAYERS-1)]
	return battlefield.slide(battlefield.entry,battlefield.entry+offset)


func seed_reserve(player: Dictionary) -> Dictionary:
	return progress.reserve(Session.inventory_owner(player))


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


func wild_flora_view(peer: int) -> Dictionary:
	var actor: Dictionary = players.get(peer, {})
	if not Participation.is_wild(actor): return {}
	if multiplayer.is_server():
		return wild_flora.view(_kill_reward_identity(peer, actor))
	if peer != multiplayer.get_unique_id() or ActionIdentity.current_stamp(self, actor).is_empty(): return {}
	return actor.get("wild_flora", {}).duplicate()


func harvest_wild_flora(peer: int, identity: String) -> bool:
	if not multiplayer.is_server() or not persistence_session.can_write(): return false
	var actor: Dictionary = players.get(peer, {})
	if not Session.belongs_to(actor, network_session) or Session.peer_for(actor) != peer \
			or not Session.ready_for(actor) or not participation.contains(peer) or not Life.alive(actor): return false
	var character := _kill_reward_identity(peer, actor)
	if not wild_flora.collect(identity, character, actor.pos, battlefield.clear_line,
			InventoryModel.admit_wild_seed.bind(self, actor)): return false
	Journal.event("expedition", "flora_harvest", {"specimen":identity, "character":character, "species":Seeds.DEFINITIONS[actor.carried_seeds.back()].id})
	tell(peer, "Seed collected. Return it to the Garden for identification.")
	return true


func activate_checkpoint(id: int) -> bool:
	var player: Dictionary = players.get(id, {})
	if not multiplayer.is_server() or not Life.alive(player) or not upgrade_checkpoint_open():
		return false
	if player.pos.distance_to(battlefield.advance) > preload("res://gate_interaction.gd").RANGE or int(checkpoint_ready.get(id, 0)) == participation.floor():
		return false
	if not checkpoint_pending:
		checkpoint_pending=true
		checkpoint_ready.clear()
	present_checkpoint_cards(id)
	return true

func milestone_message(message: String, extracted: bool) -> String:
	if deepest_milestone > 0:
		progress.remember_expedition(ranged_clears, burst_clears, choke_clears)
		progress.campaign.record_expedition(deepest_milestone, extracted)
	return message


func encounter_health() -> int:
	if not multiplayer.is_server(): return int(players.get(multiplayer.get_unique_id(),{}).get("enemy_max_hp",Life.Preview.hp(ENEMY_HEALTH)))
	if tactics.boss_kind>=0: return Director.Balance.boss_hp(Enemies.get_kind(tactics.boss_kind),participation.floor(),participation.cycle(),encounter_party_size)
	return Director.Balance.elite_hp(Enemies.get_kind(enemy_kind),participation.floor(),participation.depth(),participation.cycle(),encounter_party_size)


func start_encounter() -> void:
	wild_item_drops.clear()
	reset_encounter(map_rng.randi_range(1, 2147483647))
	# Only Wilds entry and advance populate botanical specimens. Combat-room
	# rebuilds and Arena rounds use reset_encounter independently.
	if participation.run_id() <= 0: return
	var floor_key := "%s/%d/%d/%d/%d" % [network_session.session_identity(), participation.run_id(),
		participation.route(), participation.floor(), participation.seed()]
	wild_flora.begin(floor_key, func() -> Dictionary:
		var occupied: Array[Vector3] = [tactics.position]
		for slot in encounter.scout_count():
			occupied.append(encounter.position(slot))
		var starter := WildFlora.starter(participation.floor(), InventoryModel.garden_or_party_has_seed.bind(progress, players))
		return battlefield.generate_flora(participation.floor(), starter, occupied))


func reset_encounter(seed_value: int = -1) -> void:
	if not SaveBatch.guarded_active(): flush_kill_rewards()
	monster_rewards.retire_completed()
	encounter_kill_records.clear();combat_threat.clear();combat_velocity.clear();combat_last_positions.clear();tactics.memory.clear();moving_ranged_hits=0;encounter_started_at=CombatClock.now();encounter_party_size=Director.party_size(self)
	encounter_kills.clear();encounter_rewarded=false;reward_retry_at=0
	participation.begin_floor(seed_value)
	for player in players.values():
		preload("res://native_grafts.gd").clear(player)
	for player in players.values():
		preload("res://oracle_combat.gd").clear(player)
		preload("res://vital_combat.gd").clear(self,player)
		preload("res://wood_affinity.gd").clear(player)
		preload("res://storm_affinity.gd").clear(player)
		preload("res://spirit_affinity.gd").clear(player)
		player.erase("affinity_void_form_ready")
		player.erase("affinity_thorn_form_ready")
	preload("res://core_combat.gd").reset(self)
	enemy_traits.clear();effect_timeline.clear_native()
	weapon_attacks.clear()
	combat_events.clear()
	Bosses.prepare(self)
	# A new floor has independent pathing. Keep the old object intact for abort.
	battlefield = Battlefield.new()
	battlefield.configure(participation.route(), participation.depth(), participation.seed(),tactics.boss_kind,tactics.boss_phase)
	pressure_at = 0
	tactics.haste_until=0
	enemy_death_events.clear()
	encounter.clear_scouts()
	tactics.position = Director.spawn(self,battlefield.leader,-1)
	if tactics.position==Vector3.INF:
		tactics.position = clear_spawn(battlefield.leader)
		if tactics.position == Vector3.INF:
			# A generated leader room is already certified for enemy clearance.
			tactics.position = battlefield.leader
	enemy_kind = tactics.boss_kind if tactics.boss_kind>=0 else preload("res://elite_enemy.gd").select(self)
	encounter.begin_floor(encounter_health())
	tactics.reset_approach()
	enemy_growth = Enemies.tier(participation.floor(), participation.cycle())
	enemy_mutations = current_mutations(enemy_kind, enemy_growth, participation.seed())
	var count := Director.scout_count(self)
	if tactics.boss_kind>=0: count=Director.Balance.boss_escorts(self,count)
	var composition=preload("res://wilds_composition.gd")
	var roster: Array[int]=composition.roster(self,count)
	for i in count:
		var origin: Vector3 = battlefield.spawn_points[i%battlefield.spawn_points.size()]
		var spawn: Vector3=composition.companion_spawn(self,i) if i==1 and tactics.boss_kind<0 else Vector3.INF
		if spawn.is_finite() and not _experimental_spawn_reachable(spawn): spawn = Vector3.INF
		if not spawn.is_finite():spawn=Director.spawn(self,origin,i)
		if not spawn.is_finite():continue
		var kind: int=roster[i]
		var mutations := current_mutations(kind, enemy_growth, participation.seed() + i)
		encounter.register_scout(make_scout(kind, spawn, i + 1, mutations, enemy_growth))
	EnemyFormation.arrange(self)
	Director.Balance.trace_encounter(self,count)
	if stage.experimental_garden != null and participation.seed() != 0:
		preload("res://game_metrics.gd").record("experimental_floor", {
			"seed": participation.seed(), "biome": participation.route(), "floor": participation.floor(),
			"generated": not battlefield.generated.is_empty(),
			"entry": [battlefield.entry.x, battlefield.entry.z],
			"gate": [battlefield.advance.x, battlefield.advance.z],
			"foes": 1 + encounter.scout_count()})
	burst_hits_this_room = 0
	choke_kills_this_room = 0
	damage_this_room = 0
	ranged_damage_this_room = 0
	for player in players.values():
		player.contributed = false
		player.cache_claimed = false
	tactics.reset_attack((enemy_mutations & Enemies.REACH)!=0)


func clear_spawn(world_position: Vector3) -> Vector3:
	for shift in [Vector3.ZERO, Vector3.RIGHT * 1.5, Vector3.LEFT * 1.5,
			Vector3.FORWARD * 1.5, Vector3.BACK * 1.5, Vector3.BACK * 2.7]:
		var candidate: Vector3 = world_position + shift
		if not battlefield.occupied(candidate, Battlefield.CLEARANCE) and _experimental_spawn_reachable(candidate):
			return candidate
	for radius in range(2, 5):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var candidate := world_position + Vector3(x, 0, z)
				if absf(candidate.x) <= Stage.WILD_BOUNDS.x and absf(candidate.z) <= Stage.WILD_BOUNDS.y and (
						not battlefield.occupied(candidate, Battlefield.CLEARANCE)) and _experimental_spawn_reachable(candidate):
					return candidate
	return world_position if _experimental_spawn_reachable(world_position) else Vector3.INF

func _experimental_spawn_reachable(candidate: Vector3) -> bool:
	return battlefield.can_spawn(candidate)


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


## Only a matching committed journal may release this live world's holds.
func recover_departure_cleanup() -> bool:
	if not persistence_session.finish_legacy_cleanup(): return false
	departure_settlement.release_committed_cleanup()
	monster_rewards.release_committed_cleanup()
	status = "Saved. Recovery cleanup completed."
	return true

func save_session_garden() -> bool:
	if persistence_session.is_blocked(): return false
	if persistence_session.is_guarded():
		return Transactions.run_gameplay(self, Transactions.Scope.GARDEN, func(): return true).completed
	return progress.save_garden() == OK

func save_progress(id: int, message: String) -> void:
	if persistence_session.is_blocked(): return
	if persistence_session.is_guarded():
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
	var remote_notice := str(get_meta(&"guarded_host_cleanup_notice", "")) if network_session.role() == "Guest" else ""
	var profile_notice := str(get_meta(&"guest_projection_notice", "")) if network_session.role() == "Guest" else ""
	var pending := not persistence_session.pending_notice().is_empty() or not remote_notice.is_empty() or not profile_notice.is_empty()
	var message := status if Time.get_ticks_msec() < toast_until else ""
	if not remote_notice.is_empty() and message != remote_notice and not message.ends_with("\n" + remote_notice):
		message = remote_notice if message.is_empty() else message + "\n" + remote_notice
	if not profile_notice.is_empty(): message = profile_notice if message.is_empty() else message + "\n" + profile_notice
	ui.present_feedback(Transactions.feedback_text(self,message),pending)
	ui.present_planting_access(persistence_session.pending_notice().is_empty())

func tell(id: int, message: String) -> void:
	if id == HOST:
		status = message
	elif network_session.transport() != null and not Transactions.queue_legacy_notice(self,id,message):
		receive_message.rpc_id(id, Transactions.feedback_text(self, message))


@rpc("authority", "call_remote", "reliable")
func receive_message(message: String) -> void:
	if persistence_session.is_guarded() and network_session.role() == "Guest" and (message == Transactions.CLEANUP_NOTICE or message.ends_with("\n" + Transactions.CLEANUP_NOTICE)):
		# The host's blocked Garden is distinct from this guest's local profile.
		set_meta(&"guarded_host_cleanup_notice", Transactions.CLEANUP_NOTICE)
	status = message


func combat_pose(player: Dictionary) -> int:
	var facing: Vector3 = player.facing
	var degrees := posmod(roundi(rad_to_deg(atan2(facing.x, facing.z))), 360)
	var swing: int = player[WeaponActions.STATE].swing_ticks(CombatClock.now())
	return degrees | (swing << 9)


func player_snapshot(viewer: int,include_details: bool=true) -> Dictionary:
	return replication_source.players(viewer,include_details)


func inventory_snapshot(player: Dictionary) -> Array:
	var reserve := seed_reserve(player)
	return [reserve.unknown.size(), reserve.stock[0], reserve.stock[1], progress.planted,
		reserve.stock[Progress.VEILCAP], selected_donation(player), reserve.stock.duplicate()]


func garden_snapshot() -> Array:
	# Protocol 41 reserves slots 9–11. Keep later Garden fields at their established indices.
	return [0, false, progress.flowering_unlocked,
		progress.flowering, progress.harvest_ready, progress.parts, progress.knowledge, progress.veilcap_discovered, progress.briar_hooks,
		false, 0, false, progress.plot_snapshot(), progress.discoveries.duplicate(), progress.heartwood_barbs, shared_parts_snapshot(), progress.heart.snapshot(progress)]


@rpc("authority", "call_remote", "unreliable_ordered",4)
func receive_state(frame: PackedByteArray) -> void:
	apply_world_snapshot(frame, false)


func apply_world_snapshot(frame: PackedByteArray, recovery: bool) -> void:
	guest_replication.receive_frame(guest_replication_world,frame,recovery)


func _process(_delta: float) -> void:
	# Transport can already be offline while the outgoing guest scene awaits deletion.
	if is_queued_for_deletion(): return
	if not persistence_session.pending_notice().is_empty() or (network_session.role() == "Guest" and has_meta(&"guarded_host_cleanup_notice")):
		refresh_feedback()
	if not persistence_session.can_publish_state():
		# Keep the last presented floor while the retained state awaits recovery.
		return
	if persistence_session.is_guarded() and not returning_to_title:
		var owner_context = persistence_session
		var renewal: Dictionary = owner_context.tick()
		if renewal.error != OK:
			_stop_guarded_session("This session lost access to its save. Returning to the title.")
			return
	if multiplayer.is_server() and not persistence_session.is_blocked(): PartyTravel.validate(self)
	session_world.update()
	if returning_to_title: return
	if not multiplayer.is_server() and not guest_replication.has_details(): return
	if not persistence_session.is_guarded() and (slot_claimed or character_slot_claimed) and Time.get_unix_time_from_system() - slot_heartbeat_at >= GuardedTitleSession.RENEW_SECONDS:
		var slots := preload("res://save_slots.gd").new()
		slots.root_path = slot_storage_root
		if slot_claimed: slots.heartbeat(active_slot)
		if character_slot_claimed:
			var roster:=preload("res://character_slots.gd").new();roster.root_path=character_storage_root;roster.heartbeat(active_character_slot)
		slot_heartbeat_at = Time.get_unix_time_from_system()
	var local_id := multiplayer.get_unique_id()
	var view_id: int=spectator_view.focus_id(local_id)
	var observer: Vector3=actor_presentation.position(view_id)
	var local_player: Dictionary = players.get(local_id, {})
	if ui.panel_is_open("graft"): ui.present_world_access("graft",at_graft_altar(local_player))
	elif ui.panel_is_open("altar"): ui.present_world_access("altar",at_garden_altar(local_player))
	var data: Array = inventory_snapshot(local_player) if multiplayer.is_server() and not local_player.is_empty() else guest_replication.inventory()
	var flora := wild_flora_view(local_id)
	var briar_bound := CombatClock.now() < tactics.rooted_until if multiplayer.is_server() else guest_replication.briar_bound()
	var campaign_state := campaign_snapshot() if multiplayer.is_server() else guest_replication.campaign()
	var visual_field: RefCounted = battlefield if multiplayer.is_server() else stage.visual_field
	if multiplayer.is_server(): stage.visual_field=battlefield
	var rendered_players: Dictionary=actor_presentation.people(local_id,CombatClock.now())
	var p: Dictionary = local_player
	var local_timers: Cooldowns.Timers = p.get(Cooldowns.STATE)
	var cooldown_now := CombatClock.now()
	var wild: bool = Participation.is_wild(p)
	var warnings: Array=attack_hints_snapshot() if multiplayer.is_server() and wild else p.get("attack_hints",[]) if wild else []
	if not multiplayer.is_server() and guest_replication.details_key()!=str([participation.route(),participation.floor(),participation.seed()]):
		warnings=warnings.filter(func(hint): return hint.role not in ["core_thorns","core_anchor","core_field","core_lured","glasscap_feint"])
	world_view.prepare(warnings)
	var rendered_pack := scout_snapshot(cooldown_now) if multiplayer.is_server() else guest_replication.scouts()
	stage.draw_state(rendered_players, local_id, tactics.position, enemy_health(), tactics.winding_up, LeaderBehavior.strike_radius(self), data[3], participation.depth(), graft_altar_open(), briar_bound, tactics.longlimb, campaign_state,
		rendered_pack, _delta,view_id)
	stage.show_wild_flora(flora, observer, wild)
	var travel := party_travel_state()
	ui.present_travel(travel)
	world_view.present_effects({"site":participation.route(),"floor":participation.floor(),"seed":participation.seed(),
		"wild":wild,"local_id":local_id,"observer":observer,"advance":visual_field.advance,
		"deaths":death_events_snapshot() if multiplayer.is_server() and wild else p.get("death_events",[]) if wild else [],
		"events":combat_events_snapshot() if multiplayer.is_server() else guest_combat_events(p),"warnings":warnings,
		"thief_routes":preload("res://thief_escape.gd").map_routes(self,p) if wild else [],
		"cache_available":not p.get("cache_claimed",false),"overlay_open":ui.is_overlay_open(),
		"graft_open":graft_altar_open(),"ground_items":inventory_floor_snapshot(p) if multiplayer.is_server() else p.get("ground_items",[])})
	var carried: int = p.carried_seeds.size() if multiplayer.is_server() and wild else guest_replication.carried_count()
	var health := PlayerVitals.current_hp(p)
	var garden_facts := {}
	if not wild:
		var garden := garden_snapshot() if multiplayer.is_server() else guest_replication.garden_progress()
		var slot := nearby_plot(p.get("pos",Vector3.ZERO))
		var beds := Progress.decode_plots(garden[12])
		garden_facts={"bed":beds[slot].duplicate(true) if slot>=0 and slot<beds.size() else {},
			"flowering_unlocked":bool(garden[2]),"near_altar":stage.altar_position().distance_to(p.get("pos",Vector3.ZERO))<=1.65,
			"near_gate":stage.gate_position().distance_to(p.get("pos",Vector3.ZERO))<=preload("res://gate_interaction.gd").RANGE,
			"near_heart":at_heart(p),"development":stage.experimental_garden!=null,
			"deepest_clear":campaign_state[12],"best_extraction":campaign_state[13]}
	var garden_prompt: String=get_node("GardenInteractions").context_prompt()
	var rescue_id:=Life.nearest(self,p)
	var rescue := {}
	if rescue_id!=0:
		var ally: Dictionary=players[rescue_id]
		rescue={"name":ally.get("display_name",ally.get("character",{}).get("name","ally")),
			"allowed":Life.Vitals.can_revive(PlayerVitals.maximum_hp(ally,Life.Preview.hp(MAX_HEALTH)),Life.Preview.scale()),"cost":Life.Preview.revive_cost()}
	var ground_id:=nearest_inventory_drop(p) if multiplayer.is_server() else nearest_visible_inventory_drop(p)
	var near_graft: bool=wild and graft_altar_open() and visual_field.graft.distance_to(p.pos)<=1.65 and preload("res://gate_interaction.gd").shrine_preferred(visual_field,p.pos)
	var improvements: Dictionary=(preload("res://expedition_grafts.gd").owner_details(p,participation.floor()) if multiplayer.is_server() else p.get("graft_improvements",{})) if near_graft else {}
	var context: Dictionary=WorldGuidance.project({"wild":wild,"position":p.get("pos",Vector3.ZERO),"fallen":PlayerLifecycle.fallen(p),
		"floor":participation.floor(),"depth":participation.depth(),"route":participation.route(),
		"role":network_session.role(),"party_size":players.size(),"host_port":network_session.port() if network_session.role()=="Host" else 0,
		"cleared":encounter_cleared(),"flora_near":WildFlora.within_reach(flora, p.get("pos",Vector3.INF), visual_field.clear_line),
		"leader":{"boss_kind":tactics.boss_kind,"winding_up":tactics.winding_up,"landing":tactics.landing,"attack_mode":tactics.attack_mode,"position":tactics.position,"radius":LeaderBehavior.strike_radius(self)},
		"scouts":rendered_pack,"campaign":campaign_state,"warnings":warnings,
		"gate_distance":visual_field.advance.distance_to(p.get("pos",Vector3.ZERO)),"upgrade_open":wild and upgrade_checkpoint_open(),"extraction_open":wild and extraction_checkpoint_open(),
		"offer_floor":(AffinityCards.completed_floor(p) if multiplayer.is_server() else int(p.get("last_offer",0))) if wild else 0,
		"wallet":(run_wallet(p) if multiplayer.is_server() else int(p.get("wallet",0))) if wild else 0,
		"cache_near":wild and visual_field.has_seed_cache() and not p.get("cache_claimed",false) and visual_field.cache.distance_to(p.pos)<=1.55,
		"graft_near":near_graft,"improvements":{"used":improvements.get("used",false),"remaining":improvements.remaining} if improvements.has("remaining") else {"used":improvements.get("used",false)},
		"garden":garden_facts,"courier":wild and can_checkpoint_bank(p),"garden_prompt":garden_prompt,"rescue":rescue,"pickup":not ground_id.is_empty()})
	var prompt: String=context.prompt
	var details: String=context.details
	var session_text: String=context.session_text
	refresh_feedback()

	var shared := garden_snapshot() if multiplayer.is_server() else guest_replication.garden_progress()
	var heart := heart_state()
	world_view.present_garden(_delta,{"plots":Progress.decode_plots(shared[12]),"heart":heart,
		"wild":wild,"site":participation.route(),"floor":participation.floor(),"boss":tactics.boss_kind>=0,"observer":observer,
		"knowledge":int(shared[6]),"technologies":int(shared[2])+int(shared[7])})
	var host_side := multiplayer.is_server()
	var ready_skill := (local_timers == null or local_timers.ready(Cooldowns.Q, cooldown_now)) if host_side else bool(p.get("skill_ready", false))
	var second_ready := (local_timers == null or local_timers.ready(Cooldowns.R, cooldown_now)) if host_side else bool(p.get("skill_two_ready", false))
	var resolved := combat_build(p,not wild)
	var skills: Array=resolved.class_skills()
	var has_resolved_skills: bool=skills.size()==2 and not skills.any(func(skill): return skill.is_empty())
	if not has_resolved_skills:
		skills=[Skills.resolve_in_world(self,int(p.get("frame",0)),0,p.get("character",guest_character.data)),
			Skills.resolve_in_world(self,int(p.get("frame",0)),1,p.get("character",guest_character.data))]
	var cooldowns: Array = local_timers.skill_seconds(cooldown_now) if host_side and local_timers != null else p.get("skill_cooldowns", [0.0, 0.0])
	var skill_tips: Array=resolved.tooltips() if wild and has_resolved_skills else [skills[0].name+"\n"+skills[0].description,skills[1].name+"\n"+skills[1].description]
	var quake_prepared:=false
	if skills[0].has("warden_focus"):
		var warden=preload("res://warden_combat.gd")
		quake_prepared=warden.prepared_until(self,p,CombatClock.now())>0 if host_side else bool(p.get("warden_quake_prepared",false))
		if quake_prepared:skill_tips[1]+="\nQuake prepared."
	var ready_dodge := (local_timers == null or local_timers.configure_dodge(combat_build(p).dodge_capacity(),cooldown_now).ready(Cooldowns.DODGE,cooldown_now)) if host_side else bool(p.get("dodge_ready", false))
	ui.present_menu({"session_text":"Developer Garden · Single player" if has_meta("developer_garden") else session_text,
		"role":network_session.role(),"can_host":not has_meta("developer_garden") and network_session.role() in ["Host","Solo"] and not (network_session.role()=="Solo" and wild),
		"can_join":not has_meta("developer_garden") and network_session.role()=="Solo" and not wild,
		"can_leave":network_session.role()!="Solo","can_save":multiplayer.is_server(),"can_bank":can_checkpoint_bank(p),"wild":wild,
		"look":Array(p.get("character",{}).get("appearance",p.get("appearance",[0,0,0,0,0])))})
	ui.present_context(prompt,details)
	ui.present_hud({"party":preload("res://party_hud.gd").members(players,local_id,travel.get("members",[])),
		"location": Campaign.NAMES[participation.route()] if wild else "Mystical Garden",
		"floor":participation.floor(),
		"encounter": "%d foes" % [int(enemy_health() > 0) + living_scout_count()] if wild else "Your living sanctuary",
		"damage_flash":maxf(0,(int(p[Conditions.STATE].grace_until_ms() if host_side else p.get("client_hurt_until",0))-CombatClock.now())/250.0),"hp": health, "max_hp": PlayerVitals.maximum_hp(p,MAX_HEALTH), "lost_health":p.get("lost_health",0),"fallen":PlayerLifecycle.fallen(p), "wild": wild, "frame": p.get("frame", 0),
		"skill_ready": ready_skill,"skill_two_ready":second_ready,"skill_names":[skills[0].name,skills[1].name+(" •" if quake_prepared else "")],"skill_cooldowns":cooldowns, "spirit_prepared":{"echoes":p.get("spirit_card_echoes",[]).size(),"shadows":p.get("spirit_card_shadows",[]).size()} if host_side else p.get("spirit_prepared",{}),"dodge_ready": ready_dodge,"dodge_state":local_timers.configure_dodge(combat_build(p).dodge_capacity(),cooldown_now).dodge_projection(cooldown_now) if host_side else p.get("dodge_state",{}),
		"core":preload("res://core_combat.gd").hud_state(self,p),
		"card_actions":preload("res://card_active_actions.gd").hud_state(self,p),
		"skill_tooltips":skill_tips,
		"affinity_feedback":preload("res://combat_status.gd").affinity_feedback(self,p) if host_side and wild else str(p.get("affinity_feedback","")) if wild else "",
		"carried": carried if wild else data[0],
		"pouch": p.get("pouch", false) if host_side else guest_replication.pouch_filled(),
		"wallet": run_wallet(p) if host_side and wild else int(p.get("wallet", 0)) if wild else 0,
		"insight":heart.get("insight",0), "knowledge": shared[6]},world_view.map_expanded())


func living_scout_count() -> int:
	if multiplayer.is_server():
		return encounter.living_scout_count()
	return guest_replication.living_scouts()



func request_main_menu() -> void:
	if participation.active() and network_session.role() in ["Solo","Host"] or Participation.is_wild(players.get(local_player_id(),{})):
		ui.show_title_confirmation()
	else:
		return_to_main_menu()


func prepare_guarded_exit(save_garden := true) -> bool:
	if not persistence_session.can_write(): return true
	if network_session.role() in ["Solo","Host"] and slot_claimed:
		if participation.active():
			if not expedition_transitions.finish_voluntary(): return false
			character_dirty=false
			return true
		if not departure_settlement.is_empty() or monster_rewards.has_pending():
			if not flush_kill_rewards(): return false
			character_dirty=false
			return true
		if save_garden:
			var scope := Transactions.Scope.PAIR if character_dirty else Transactions.Scope.GARDEN
			var result := Transactions.run_gameplay(self,scope,func(): return true)
			if not Transactions.committed(result.persistence): return false
			character_dirty=false
			return true
	return not character_dirty or save_local_character()

func return_to_main_menu(message: String = "") -> void:
	if persistence_session.can_write() and expedition_transitions.request_guest_exit(Session.Exit.TITLE): return
	if returning_to_title:
		return
	returning_to_title = true
	if persistence_session.is_guarded():
		var owned: bool=persistence_session.owns_leases()
		if not prepare_guarded_exit():
			returning_to_title=false
			return
		_finish_title_return(message if owned else "This session lost access to its save. Returning to the title.")
		return
	if persistence_session.is_blocked():
		_finish_title_return(message)
		return
	if network_session.role() in ["Solo","Host"] and not network_session.joined_from_title():
		if participation.active():
			if not expedition_transitions.finish_voluntary():
				returning_to_title = false
				return
			# The paired departure already saved the Garden and host character.
			_finish_title_return(message)
			return
		if not save_session_garden():
			returning_to_title = false
			if not persistence_session.is_guarded(): status = "Could not save this Garden. Use Save Garden before leaving."
			return
		if not persistence_session.pending_notice().is_empty():
			_finish_title_return(message)
			return
	if character_dirty and not save_local_character():
		returning_to_title = false
		return
	_finish_title_return(message)

func _stop_guarded_session(message: String) -> void:
	if not persistence_session.begin_shutdown(): return
	returning_to_title = true
	process_mode = Node.PROCESS_MODE_DISABLED
	set_process(false)
	set_physics_process(false)
	_finish_title_return.call_deferred(message)

func _finish_title_return(message: String) -> void:
	if persistence_session.is_guarded(): persistence_session.begin_shutdown()
	session_world.offline()
	release_slot()
	if network_dialog.visible:
		network_dialog.dismiss()
	var menu = load("res://main_menu.tscn").instantiate()
	menu.settings_path=settings_path
	var dev_return: Dictionary=get_meta("developer_garden",{})
	menu.storage.root_path = dev_return.get("root",slot_storage_root)
	menu.import_legacy = menu.storage.root_path == "user://saves"
	menu.restore_last_selection = false
	menu.selected = dev_return.get("slot",maxi(0,active_slot))
	menu.selected_character=dev_return.get("character",maxi(0,active_character_slot))
	menu.restore_last_character=false
	var recovery_paths := PackedStringArray()
	if network_session.role() in ["Solo","Host"]:
		recovery_paths.append(progress.path)
		recovery_paths.append(local_character.path)
	elif network_session.role() in ["Guest","Connecting"]:
		recovery_paths.append(guest_character.path)
	menu.accept_persistence_return(persistence_session.title_return_view(
		network_session.role(), message, str(get_meta(&"guest_projection_notice", "")), recovery_paths))
	if network_session.joined_from_title() or network_session.role()=="Connecting" or network_session.join_phase()=="garden":
		menu.set_meta("join_return",{"address":network_session.address(),"port":network_session.port(),"open":not network_session.join_cancelled()})
	set_process(false)
	set_physics_process(false)
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	var report: Dictionary = ui.visible_expedition_result() if is_instance_valid(ui) else {}
	if not report.is_empty(): preload("res://ui/gameplay/expedition_summary.gd").show_at_title(menu,report)
	queue_free()


func release_slot() -> void:
	if persistence_session.is_guarded():
		var released: Dictionary=persistence_session.release()
		if released.get("error",OK)!=OK:
			Journal.event("save","session_lease_release_failed",{"error":released.error,"reason":released.get("reason","")},"warning")
		character_slot_claimed = false
		slot_claimed = false
		return
	if preload("res://persistence_writer_integration.gd").default_route(get_tree()): return
	if character_slot_claimed and active_character_slot>=0:
		var roster:=preload("res://character_slots.gd").new();roster.root_path=character_storage_root;roster.release(active_character_slot);character_slot_claimed=false
	if slot_claimed and active_slot >= 0:
		var slots := preload("res://save_slots.gd").new()
		slots.root_path = slot_storage_root
		slots.release(active_slot)
		slot_claimed = false


func _exit_tree() -> void:
	persistence_session.begin_shutdown()
	# Release the callbacks this world owns before its integration ports retire.
	if multiplayer.connected_to_server.is_connected(session_world.joined):
		multiplayer.connected_to_server.disconnect(session_world.joined)
	if multiplayer.connection_failed.is_connected(session_world.connection_failed):
		multiplayer.connection_failed.disconnect(session_world.connection_failed)
	if multiplayer.server_disconnected.is_connected(session_world.server_disconnected):
		multiplayer.server_disconnected.disconnect(session_world.server_disconnected)
	session_world.offline()
	release_slot()


func current_mutations(kind: int, growth: int, stamp: int) -> int:
	var gain := 2 if participation.floor() >= 10 else 0
	var older_pressure: Dictionary={"ranged":progress.ranged_pressure+ranged_clears*gain,
		"burst":progress.burst_pressure+burst_clears*gain,"choke":progress.choke_pressure+choke_clears*gain}
	var traits:=Enemies.mutations(kind,growth,0,0,0,participation.floor(),stamp)
	traits|=Learning.traits(progress.wilds_memory,participation.floor(),stamp,older_pressure)
	if kind==0 and ((participation.depth()>=2 and progress.ranged_pressure>=3 and participation.depth()%2==0) or (participation.depth()>=4 and ranged_clears>=2)): traits|=Enemies.REACH
	return Learning.bounded(traits,participation.floor(),stamp)


func combat_build(player: Dictionary, prepared: bool = false) -> ResolvedBuild.Snapshot:
	if not multiplayer.is_server():
		return combat_builds.received(player.get("weapon_stats",{}), AffinityCards.applied_totals(player.get("affinity_run_cards",[])))
	var fields := ["prepared","prepared_secondary","prepared_catalyst"] if prepared else ["weapon","secondary","catalyst"]
	var parts := fields.map(func(field): return int(player.get(field,0)))
	var class_id := int(player.get("frame",0))
	return combat_builds.resolve(class_id,int(player.get("weapon_kind",0)),parts,Classes.combat_profile(player.get("character",{}),class_id),
		AffinityCards.ledger(player) if not prepared else null,
		preload("res://expedition_grafts.gd").active_ledger(player) if not prepared else null,not prepared)

func weapon_stats(player: Dictionary, prepared: bool = false) -> Dictionary:
	return combat_build(player,prepared).native_stats()

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
	var health: PlayerVitals.Health = player[PlayerVitals.STATE]
	player[PlayerVitals.STATE] = health.with_native_max_hp(Life.native_maximum(self, player, not Participation.is_wild(player)))
func persist_loadout(id: int,player: Dictionary,effects = null) -> void:
	if effects == null and persistence_session.is_guarded(): return
	player.character.active_class=int(player.frame)
	player.character.loadouts[player.frame]={"weapon":int(player.weapon_kind),"parts":[int(player.prepared),int(player.prepared_secondary),int(player.prepared_catalyst)]}
	save_action_profile(id, effects)

func select_class(id: int,player: Dictionary,class_id: int) -> void:
	if class_id<0 or class_id>=Classes.DEFINITIONS.size() or not ((at_heart(player) and not participation.active()) or at_weapon_gate(player)): return
	if persistence_session.is_guarded():
		run_guarded_action(id, actor_profile_scope(id), func(effects): _select_class(id, player, class_id, effects))
	else:
		_select_class(id, player, class_id, null)

func _select_class(id: int,player: Dictionary,class_id: int,effects) -> void:
	player.loadout_reserving=false
	player.character.active_class=class_id
	restore_class_loadout(player)
	if at_weapon_gate(player):
		LoadoutMaterials.reconcile(player,stored_counts(player));player.loadout_reserving=true
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].refilled()
	persist_loadout(id,player,effects)
	var message := "%s selected."%Classes.DEFINITIONS[class_id].name
	if preload("res://affinity_build.gd").starting_tree(class_id,player.character) != null:
		message += " Choose your starting focus in the class tree or at the Wilds Gate."
	if effects == null: tell(id,message)
	else: effects.append(tell_profile_action.bind(id,message))

func handle_loadout_action(id: int,player: Dictionary,action: String) -> void:
	var allowed: bool
	if action.begins_with("learn_"):
		allowed=preload("res://class_tree_access.gd").can_learn_here(self,player)
	elif action.begins_with("respec_"):
		allowed=at_heart(player) and not participation.active()
	else:
		allowed=at_weapon_gate(player) or (action.begins_with("class_") and at_heart(player))
	if not allowed:
		tell(id,"Learn class upgrades at the Heart or Wilds Gate between expeditions." if action.begins_with("learn_") else "Refund class points at the Heart between expeditions." if action.begins_with("respec_") else "Prepare weapons at the Wilds Gate.")
		return
	var fields:=action.split("_")
	for field in fields.slice(1):
		if not field.is_valid_int(): return
	var command := fields[0]
	if command == "class":
		if fields.size()==2: select_class(id,player,int(fields[1]))
	elif persistence_session.is_guarded() and command in ["loadweapon", "loadpart", "learn", "respec"]:
		run_guarded_action(id, actor_profile_scope(id), func(effects): _apply_loadout_action(id, player, fields, effects))
	else:
		_apply_loadout_action(id, player, fields, null)

func _apply_loadout_action(id: int, player: Dictionary, fields: PackedStringArray, effects) -> void:
	match fields[0]:
		"loadweapon":
			if fields.size()==2 and int(fields[1])>=0 and int(fields[1])<Classes.DEFINITIONS[int(player.frame)].weapons.size():
				player.weapon_kind=int(fields[1])
				persist_loadout(id,player,effects)
		"loadpart":
			if fields.size()!=3: return
			if effects == null: LoadoutMaterials.reconcile(player,stored_counts(player))
			var slot:=int(fields[1])
			var part:=int(fields[2])
			if slot<0 or slot>2 or (part!=0 and not Parts.is_plant(part)): return
			var reconciled := effects != null and LoadoutMaterials.reconcile(player,stored_counts(player))
			if part!=0 and LoadoutMaterials.remaining(stored_counts(player),LoadoutMaterials.choices(player),slot,part)<=0:
				if reconciled and effects != null: persist_loadout(id,player,effects)
				action_feedback(effects,id,"That material is unavailable or already assigned to another weapon slot.")
				return
			player[LoadoutMaterials.FIELDS[slot]]=part
			player.loadout_reserving=true
			persist_loadout(id,player,effects)
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
			var connected := Classes.connected_in_world(self,c,player.character)
			var title: String
			if connected != null:
				var refusal: String = connected.learn(player.character,node)
				if not refusal.is_empty():
					action_feedback(effects,id,refusal)
					return
				title = connected.nodes[node-connected.REQUEST_OFFSET].name
			else:
				action_feedback(effects,id,"Historical class investments are preserved. Refund them at the Heart, then choose your connected path before departing.")
				return
			restore_class_loadout(player)
			save_action_profile(id, effects)
			var message := "Learned %s." % title
			if effects == null: tell(id,message)
			else: effects.append(tell_profile_action.bind(id,message))
		"respec":
			if fields.size()==2 and int(fields[1])>=0 and int(fields[1])<Classes.DEFINITIONS.size():
				var c := int(fields[1])
				var tree := Classes.connected_tree(c)
				if tree == null or not tree.valid(player.character):
					action_feedback(effects,id,"This class path needs review before it can be refunded.")
					return
				if not tree.eligible(player.character):
					var refunded := Character.refund_historical_class(player.character,c)
					if refunded.error != OK:
						action_feedback(effects,id,"The historical class refund could not be validated. Your investments are unchanged.")
						return
					player.character = refunded.profile
				else:
					player.character[tree.profile_key] = tree.state([])
				restore_class_loadout(player)
				save_action_profile(id, effects)
				var message := "Class points refunded. Choose a new path before the next expedition."
				if effects == null: tell(id,message)
				else: effects.append(tell_profile_action.bind(id,message))









func heart_state() -> Dictionary:
	if multiplayer.is_server(): return progress.heart.snapshot(progress)
	if guest_replication.garden_progress().size()>16 and guest_replication.garden_progress()[16] is Dictionary: return guest_replication.garden_progress()[16]
	return {"unlocked":["heart"],"spent":0,"insight":0,"phase":0,"clearing":0}

func monster_cargo_limit() -> int:
	return Weapons.MONSTER_CARGO_LIMIT+(2 if heart_state().get("unlocked",[]).has("spore_bench") else 0)

func at_garden_station(player: Dictionary,id: String) -> bool:
	if player.is_empty() or Participation.is_wild(player) or PlayerLifecycle.fallen(player) or participation.active() or not participation.travel_kind().is_empty():
		return false
	return Stage.HEART_STATIONS.has(id) and heart_state().get("unlocked",[]).has(id) and stage.station_position(id).distance_to(player.get("pos",Vector3.INF))<=1.8

func show_heart_tree(id: int) -> void:
	if id==HOST:
		open_heart_tree()
	elif network_session.transport()!=null:
		open_heart_tree.rpc_id(id)

@rpc("authority","call_remote","reliable")
func open_heart_tree() -> void:
	ui.show_progression(false,true)

func reclamation_species(player: Dictionary) -> int:
	var selected:=clampi(int(player.get("reclaim_choice",0)),0,Seeds.NAMES.size()-1)
	var known: Array=progress.discoveries if multiplayer.is_server() else guest_replication.garden_progress()[13] if guest_replication.garden_progress().size()>13 else Seeds.counts(false)
	if known[selected]: return selected
	for i in Seeds.NAMES.size():
		if known[i]: return i
	return selected

func reclamation_cost(kind: int) -> int:
	return 2+int(Seeds.DEFINITIONS[kind].tier)

func reclaim_seed(id: int,player: Dictionary,requested := -1) -> void:
	if not at_garden_station(player,"seed_archive"): return
	if persistence_session.is_guarded():
		run_guarded_action(id, Transactions.Scope.GARDEN, func(effects): _reclaim_seed(id, player, requested, effects))
	else:
		_reclaim_seed(id, player, requested, null)

func _reclaim_seed(id: int,player: Dictionary,requested: int,effects) -> void:
	var kind:=requested if requested>=0 else reclamation_species(player)
	if kind>=Seeds.DEFINITIONS.size() or not progress.discoveries[kind]:
		action_feedback(effects,id,"Discover a species before reclaiming its seed.")
		return
	player.reclaim_choice=kind
	var part:=int(Seeds.DEFINITIONS[kind].part)
	var cost:=reclamation_cost(kind)
	if stored_counts(player)[part]<cost:
		action_feedback(effects,id,"Need %d matching %s parts."%[cost,Seeds.NAMES[kind]])
		return
	var reserve:=seed_reserve(player)
	var personal:=mini(int(reserve.parts[part]),cost)
	reserve.parts[part]-=personal
	progress.add_parts(part,-(cost-personal))
	reserve.stock[kind]+=1
	if effects == null and progress.save_garden()!=OK:
		reserve.parts[part]+=personal
		progress.add_parts(part,cost-personal)
		reserve.stock[kind]-=1
		tell(id,"Could not save reclamation. Materials were returned.")
		return
	action_feedback(effects,id,"Reclaimed one %s seed."%Seeds.NAMES[kind])

func selected_offering(player: Dictionary) -> int:
	var part:=int(player.get("offering_choice",0))
	var counts: Array=stored_counts(player) if multiplayer.is_server() else player.get("stored_parts",Parts.empty_counts())
	if Parts.is_monster(part) and counts[part]>0: return part
	return next_monster_part(0,counts)

func offer_monster(id: int,player: Dictionary,requested := -1) -> void:
	if not at_garden_station(player,"monster_studies"): return
	if persistence_session.is_guarded():
		run_guarded_action(id, Transactions.Scope.GARDEN, func(effects): _offer_monster(id, player, requested, effects))
	else:
		_offer_monster(id, player, requested, null)

func _offer_monster(id: int,player: Dictionary,requested: int,effects) -> void:
	if requested >= 0: player.offering_choice=requested
	var part:=selected_offering(player)
	if part==0: action_feedback(effects,id,"Bring a stored monster trophy.");return
	var reserve:=seed_reserve(player)
	var personal: bool=int(reserve.parts[part])>0
	if personal: reserve.parts[part]-=1
	else: progress.add_parts(part,-1)
	var fresh: bool=not progress.heart.offered.has(part)
	var reward:=4 if fresh else 1
	if fresh: progress.heart.offered.append(part)
	progress.knowledge+=reward
	if effects == null and progress.save_garden()!=OK:
		if personal: reserve.parts[part]+=1
		else: progress.add_parts(part,1)
		progress.knowledge-=reward
		if fresh: progress.heart.offered.erase(part)
		tell(id,"Could not save offering. The trophy was returned.")
		return
	action_feedback(effects,id,"Offered %s. The Heart gained %d Knowledge."%[Parts.part_name(part),reward])

func can_checkpoint_bank(player: Dictionary) -> bool:
	return not player.is_empty() and Participation.is_wild(player) and upgrade_checkpoint_open() and heart_state().get("unlocked",[]).has("checkpoint_deposit") and player.get("pos",Vector3.INF).distance_to(battlefield.advance if multiplayer.is_server() else stage.visual_field.advance)<=preload("res://gate_interaction.gd").RANGE and int(player.get("last_deposit",0))!=participation.floor()

func open_deposit_menu() -> void:
	var id: int=HOST if multiplayer.is_server() else multiplayer.get_unique_id()
	var player: Dictionary=players.get(id,{})
	if not can_checkpoint_bank(player):
		status="The courier needs Returning Mycelium and a cleared checkpoint gate. One item may be sent per checkpoint."
		return
	var items: Array = []
	var seeds: int=player.carried_seeds.size() if multiplayer.is_server() else guest_replication.carried_count()
	var bag: Array=InventoryModel.snapshot(self,player).carry if multiplayer.is_server() else player.get("bag",{}).get("carry",[])
	if bag.any(func(stack):return stack.item==Items.Ancient.ITEM):
		items.append({"label":"Ancient Mystery Seed","id":COURIER_ANCIENT_OPTION})
	for i in seeds: items.append({"label":"Mysterious seed %d"%(i+1),"id":i})
	for part in range(1,Parts.DEFINITIONS.size()):
		if player.get("carried_parts",Parts.empty_counts())[part]>0:
			items.append({"label":Parts.part_name(part),"id":1000+part})
	ui.show_deposit(items)

@rpc("authority","call_remote","reliable")
func show_checkpoint_deposit() -> void:
	open_deposit_menu()

func bank_checkpoint_item(id: int,player: Dictionary,action: String) -> void:
	if not can_checkpoint_bank(player): return
	var fields:=action.split("_")
	if fields.size()!=3 or not fields[2].is_valid_int(): return
	if persistence_session.is_guarded():
		run_guarded_action(id, Transactions.Scope.GARDEN, func(effects): _bank_checkpoint_item(id, player, fields, effects))
	else:
		_bank_checkpoint_item(id, player, fields, null)

func _bank_checkpoint_item(id: int,player: Dictionary,fields: PackedStringArray,effects) -> void:
	var index:=int(fields[2])
	var return_before: Dictionary=progress.garden_interactions.duplicate(true)
	var reserve:=seed_reserve(player)
	var old_pouch: bool=player.pouch
	var species_id: int=-1
	var ancient := {}
	if fields[1]=="ancient" and index==0:
		ancient=InventoryModel.take(self,player,"carry",Items.Ancient.ITEM,1)
		if ancient.is_empty(): return
		InventoryModel.put(self,player,"stash",ancient)
		garden_commands.credit_return(preload("res://garden_return_service.gd").Member.new(str(player.get("garden_run_actor","")),str(player.get("garden_run_id","")),Participation.is_wild(player)),[],"checkpoint:"+str(participation.floor()),true)
	elif fields[1]=="seed":
		if index<0 or index>=player.carried_seeds.size(): return
		species_id=int(player.carried_seeds[index])
		player.carried_seeds.remove_at(index)
		garden_commands.credit_return(preload("res://garden_return_service.gd").Member.new(str(player.get("garden_run_actor","")),str(player.get("garden_run_id","")),preload("res://expedition_participation.gd").is_wild(player)),[species_id],"checkpoint:"+str(participation.floor()))
		reserve.unknown.append(species_id)
		if index==0 and player.get("safe_items",[]).is_empty(): player.pouch=false
	elif fields[1]=="part":
		if index<=0 or index>=Parts.DEFINITIONS.size() or player.carried_parts[index]<=0: return
		player.carried_parts[index]-=1
		reserve.parts[index]+=1
	else: return
	if effects == null and progress.save_garden()!=OK:
		progress.garden_interactions=return_before
		if not ancient.is_empty():
			InventoryModel.undo_put(self,player,"stash",ancient)
			InventoryModel.put(self,player,"carry",ancient)
		elif species_id>=0:
			reserve.unknown.pop_back()
			player.carried_seeds.insert(index,species_id)
			player.pouch=old_pouch
		else:
			player.carried_parts[index]+=1
			reserve.parts[index]-=1
		tell(id,"Could not save courier delivery. Your item was returned.")
		return
	player.last_deposit=participation.floor()
	action_feedback(effects,id,"Item sent to Garden storage.")



func at_weapon_gate(player: Dictionary) -> bool:
	return not player.is_empty() and not Participation.is_wild(player) and not PlayerLifecycle.fallen(player) and stage.gate_position().distance_to(player.get("pos",Vector3.INF))<=preload("res://gate_interaction.gd").RANGE

func local_player_id() -> int:
	return HOST if multiplayer.is_server() else multiplayer.get_unique_id()

func request_abandon_run() -> void:
	if Participation.is_wild(players.get(local_player_id(),{})): ui.show_abandon_confirmation()

func show_gate_preparation(id: int) -> void:
	if not players.has(id) or not at_weapon_gate(players[id]): return
	var player: Dictionary = players[id]
	if persistence_session.is_guarded():
		if not persistence_session.can_write(): return
		var projected := player.duplicate()
		if LoadoutMaterials.reconcile(projected,stored_counts(player)):
			var result := run_guarded_action(id, actor_profile_scope(id), func(effects):
				if LoadoutMaterials.reconcile(player,stored_counts(player)): persist_loadout(id,player,effects)
				player.loadout_reserving=true)
			if not Transactions.committed(result.persistence): return
	elif LoadoutMaterials.reconcile(player,stored_counts(player)):
		persist_loadout(id,player)
	player.loadout_reserving=true
	if id==HOST: open_gate_preparation()
	else: open_gate_preparation.rpc_id(id)

@rpc("authority","call_remote","reliable")
func open_gate_preparation() -> void:
	ui.show_loadout()

@rpc("authority","call_remote","reliable")
func close_run_flow_panel() -> void:
	ui.close_run_flow()

func checkpoint_all_ready() -> bool:
	for id in players:
		if Life.alive(players[id]) and int(checkpoint_ready.get(id,0))!=participation.floor(): return false
	return true

func checkpoint_card_data(player: Dictionary) -> Array:
	var stats := combat_build(player).weapon_base_stats()
	var ledger := AffinityCards.ledger(player)
	if ledger == null:
		ledger = AffinityCards.Ledger.new()
	var revision := int(get_meta(AffinityCards.SERIAL, 0)) + 1
	var opened := ledger.open_offer(participation.floor(), revision, int(player.upgrade_seed), stats, DODGE_COOLDOWN_MS)
	if opened != ledger:
		player[AffinityCards.STATE] = opened
		set_meta(AffinityCards.SERIAL, revision)
	var waiting := int(checkpoint_ready.get(Traits.player_id(self, player), 0)) == participation.floor()
	return [AffinityCards.checkpoint_view(opened, stats, DODGE_COOLDOWN_MS, run_wallet(player), waiting)]

func present_checkpoint_cards(id: int) -> void:
	var player: Dictionary=players[id]
	var waiting: bool=int(checkpoint_ready.get(id,0))==participation.floor()
	var wallet: int=run_wallet(player)
	if id==HOST: open_checkpoint_cards(checkpoint_card_data(player),wallet,participation.floor(),waiting)
	elif network_session.transport()!=null: open_checkpoint_cards.rpc_id(id,checkpoint_card_data(player),wallet,participation.floor(),waiting)

@rpc("authority","call_remote","reliable")
func open_checkpoint_cards(cards: Array,wallet: int,floor_number: int,waiting: bool) -> void:
	if cards.size() != 1 or not cards[0].get("affinity_offer",false) or floor_number < participation.floor(): return
	ui.show_checkpoint_offer(cards[0],wallet,floor_number,waiting)


func _affinity_checkpoint_command(id: int, player: Dictionary, action: String) -> void:
	if not multiplayer.is_server() or not Life.alive(player) or not checkpoint_pending \
			or not upgrade_checkpoint_open() or int(checkpoint_ready.get(id, 0)) == participation.floor() \
			or player.pos.distance_to(battlefield.advance) > preload("res://gate_interaction.gd").RANGE:
		return
	var fields := action.trim_prefix(AffinityCards.COMMAND).split("_")
	if fields.size() != 2 or not fields[0].is_valid_int():
		return
	var ledger := AffinityCards.ledger(player)
	if ledger == null or not ledger.has_offer_for(participation.floor()):
		return
	var stats := combat_build(player).weapon_base_stats()
	var revision := int(get_meta(AffinityCards.SERIAL, 0)) + 1
	var plan := ledger.plan_choice(participation.floor(), int(fields[0]), fields[1], revision,
		int(player.upgrade_seed), run_wallet(player), stats, DODGE_COOLDOWN_MS)
	# Install the accepted state and debit together before publishing feedback.
	if plan.has("ledger"):
		if plan.has("cost"):
			var debited := _plan_essence_debit(player, int(plan.cost))
			if debited == null:
				present_checkpoint_cards(id)
				return
			player[ExpeditionWallet.STATE] = debited
		player[AffinityCards.STATE] = plan.ledger
		if plan.has("cost"):
			set_meta(AffinityCards.SERIAL, revision)
			Journal.event("combat", "affinity_card_reroll", {"actor": id, "floor": participation.floor(),
				"revision": revision, "cost": plan.cost, "rerolls": plan.rerolls})
		if plan.has("copy"):
			expedition_statistics.count(participation.run_id(),expedition_stat_identity(id),"cards")
			var copy: Dictionary = plan.copy
			if copy.id == "run_health":
				player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_native_max_hp(Life.native_maximum(self,player))
			Journal.event("combat", "affinity_card_acquired", {"actor": id, "floor": copy.floor,
				"acquisition": copy.acquisition_id, "card": copy.id, "rarity": copy.rarity, "amount": copy.amount})
	if plan.has("message"):
		tell(id, plan.message)
	if plan.get("ready", false):
		mark_checkpoint_ready(id)
	elif plan.get("refresh", false):
		present_checkpoint_cards(id)


func affinity_checkpoint_action(revision: int, choice: String) -> String:
	return "%s%d_%s" % [AffinityCards.COMMAND,revision,choice]



func mark_checkpoint_ready(id: int) -> void:
	checkpoint_ready[id]=participation.floor()
	if persistence_session.is_guarded():
		# Selection is independent of expedition settlement in guarded sessions.
		if id==HOST: close_run_flow_panel()
		elif network_session.transport()!=null: close_run_flow_panel.rpc_id(id)
		return
	if PartyTravel.members(self,"advance").size()>1:
		if id==HOST: close_run_flow_panel()
		elif network_session.transport()!=null: close_run_flow_panel.rpc_id(id)
		tell(id,"Upgrade chosen. Ready up at the gate.")
		return
	resume_checkpoint_if_ready()
	if checkpoint_pending: present_checkpoint_cards(id)

func resume_checkpoint_if_ready() -> void:
	if persistence_session.is_guarded(): return
	if PartyTravel.members(self,"advance").size()>1: return
	if not checkpoint_pending or not checkpoint_all_ready(): return
	for id in players:
		if Life.alive(players[id]) and players[id].pos.distance_to(battlefield.advance)<=preload("res://gate_interaction.gd").RANGE:
			expedition_transitions.checkpoint(id,true)
			return






func graft_menu_data(player: Dictionary) -> Dictionary:
	var ledger := preload("res://expedition_grafts.gd").active_ledger(player)
	if ledger == null:
		return {}
	var project_stats := combat_build(player).graft_value_resolver(MAX_HEALTH,int(player.get("lost_health",0)),PlayerVitals.temporary_hp(player))
	return ledger.altar_view(participation.floor(), player.carried_parts, str(player.get("graft_message", "")), project_stats)

func show_graft_menu(id: int) -> void:
	if not players.has(id) or not at_graft_altar(players[id]): return
	var data:=graft_menu_data(players[id])
	if data.is_empty(): return
	if id==HOST: open_graft_menu(data)
	else: open_graft_menu.rpc_id(id,data)

@rpc("authority","call_remote","reliable")
func open_graft_menu(data: Dictionary) -> void:
	ui.show_graft(data)


func graft_feedback(id: int,player: Dictionary,message: String,effects = null) -> void:
	if effects != null:
		effects.append(graft_feedback.bind(id, player, message))
		return
	player.graft_message=message
	tell(id,message)

func inventory_ui_data() -> Dictionary:
	var player: Dictionary=players.get(local_player_id(),{})
	if player.is_empty(): return {}
	var data: Dictionary=InventoryModel.snapshot(self,player) if multiplayer.is_server() else player.get("bag",{}).duplicate()
	if data.is_empty(): return data
	# Local projection from existing owner details; no additional wire state.
	data.affinity_build=combat_build(player,not Participation.is_wild(data)).affinity_build()
	data.notice = status
	return data.duplicate(true)

func progression_ui_data(selection: Dictionary) -> Dictionary:
	var id := local_player_id()
	var player: Dictionary = players.get(id,{})
	if player.is_empty(): return {}
	var host := multiplayer.is_server()
	var garden: Array = garden_snapshot() if host else guest_replication.garden_progress()
	var heart: Dictionary = garden[16] if garden.size()>16 and garden[16] is Dictionary else heart_state()
	var campaign: PackedInt32Array = campaign_snapshot() if host else guest_replication.campaign()
	var at_home := at_heart(player)
	var between_runs := not participation.active()
	var may_start := host and at_home and between_runs
	var chosen := str(selection.get("chosen",""))
	var chosen_id := chosen.trim_prefix("heart_") if chosen.begins_with("heart_") else ""
	var refusal := progress.heart.requirements(progress,chosen_id) if may_start and int(selection.get("tab",0))==1 else ""
	return {"class_id":int(player.get("frame",0)),
		"profile":preload("res://ui/gameplay/player_build_projection.gd").progression_profile(player.get("character",guest_character.data)),
		"recorded_seed_recipes":Altar.recorded_seed_species(progress) if host else player.get("recorded_seed_recipes",[]),
		"known_seeds":garden[13] if garden.size()>13 else Seeds.counts(false),
		"seed_stock":seed_reserve(player).stock if host else guest_replication.inventory()[6] if guest_replication.inventory().size()>6 else Seeds.counts(),
		"heart":heart,"shared_parts":garden[5],"knowledge":int(garden[6]),
		"memories":[campaign[14],campaign[15],campaign[16]],
		"at_altar":not Participation.is_wild(player) and player.get("pos",Vector3.ZERO).distance_to(stage.altar_position())<=1.65,
		"may_learn":preload("res://class_tree_access.gd").can_learn_here(self,player),"may_respec":at_home and between_runs,
		"is_host":host,"may_start_research":may_start,
		"research_refusal":refusal,
		"stories":garden_commands.return_projection(id) if int(selection.get("tab",0))==3 else {},
		"notice":status}.duplicate(true)

func loadout_ui_data() -> Dictionary:
	var player: Dictionary = players.get(local_player_id(),{})
	if player.is_empty(): return {}
	var host := multiplayer.is_server()
	var prepared := not Participation.is_wild(player)
	return {"class_id":int(player.get("frame",0)),"weapon_kind":int(player.get("weapon_kind",0)),
		"prepared":prepared,"counts":stored_counts(player) if host else player.get("stored_parts",Parts.empty_counts()),
		"equipment":[player.get("prepared",0),player.get("prepared_secondary",0),player.get("prepared_catalyst",0)] if prepared else [player.get("weapon",0),player.get("secondary",0),player.get("catalyst",0)],
		"cargo":player.get("cargo_plan",Parts.empty_counts()),
		"profile":preload("res://ui/gameplay/player_build_projection.gd").class_profile(player.get("character",guest_character.data),int(player.get("frame",0))),
		"stats":weapon_stats(player,prepared) if host else player.get("weapon_stats",{}),
		"card_totals":AffinityCards.totals(player) if host else AffinityCards.applied_totals(player.get("affinity_run_cards",[])),
		"at_gate":at_weapon_gate(player),"class_allowed":(at_heart(player) and not participation.active()) or at_weapon_gate(player),
		"cargo_limit":monster_cargo_limit(),"party_size":players.size(),"travel":party_travel_state(),"notice":status}.duplicate(true)

func run_summary_ui_data(peer_id: int = -1) -> Dictionary:
	var player: Dictionary = players.get(local_player_id() if peer_id < 0 else peer_id,{})
	if player.is_empty(): return {}
	var host := multiplayer.is_server()
	var stats: Dictionary = weapon_stats(player) if host else player.get("weapon_stats",{}) if guest_replication.details_key()==str([participation.route(),participation.floor(),participation.seed()]) else {}
	var class_id := int(player.get("frame",0))
	var profile: Dictionary = player.get("character",guest_character.data)
	var facts := {"active":Participation.is_wild(player),"stats":stats,"class_id":class_id,
		"attack_speed_percent":preload("res://basic_attack_timing.gd").temporary_percent(self,player,CombatClock.now()) if host else int(player.get("temporary_attack_speed_percent",0)),
		"weapon_kind":int(player.get("weapon_kind",0)),"base_hp":Life.Preview.hp(MAX_HEALTH),
		"max_hp":PlayerVitals.maximum_hp(player,Life.Preview.hp(MAX_HEALTH)),"dodge_ms":DODGE_COOLDOWN_MS,
		"skills":[Skills.resolve(class_id,0,profile),Skills.resolve(class_id,1,profile)],
		"copies":AffinityCards.project_owned(player,stats,DODGE_COOLDOWN_MS) if host else player.get("affinity_run_cards",[]),
		"grafts":preload("res://expedition_grafts.gd").owner_details(player,participation.floor()) if host else player.get("graft_improvements",{}),
		"spirit_prepared":{"echoes":player.get("spirit_card_echoes",[]).size(),"shadows":player.get("spirit_card_shadows",[]).size(),"compatibility":load("res://spirit_replicas.gd").info()} if host else player.get("spirit_prepared",{}),"kill_heal_limit":Life.Sustain.KILL_BUDGET_HP}
	var boundary := participation.depth()==ROUTE_ROOMS
	var cycle := participation.cycle()+int(boundary and participation.route()==Campaign.HOLLOW)
	facts.recovery_band = Life.Preview.heal_band(Life.Sustain.recovery_center_hp(boundary,cycle))
	return facts.duplicate(true)

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
		if Participation.is_wild(player):
			tell(id,transfer.call())
		else:
			var result := Transactions.run_gameplay(self, Transactions.Scope.GARDEN, transfer, false)
			tell(id,Transactions.feedback(result, "Could not save the transfer."))
	elif data.operation=="drop": drop_inventory_stack(id,player,data.source,data.item,amount)

func inventory_drop_list(player: Dictionary) -> Array:
	return wild_item_drops if Participation.is_wild(player) else progress.ground_items

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
	if not Participation.is_wild(player) and persistence_session.is_guarded():
		run_guarded_action(id, Transactions.Scope.GARDEN, func(effects): _drop_inventory_stack(id, player, source, item, quantity, effects))
	else:
		_drop_inventory_stack(id, player, source, item, quantity, null)

func _drop_inventory_stack(id: int,player: Dictionary,source: String,item: String,quantity: int,effects) -> void:
	var allowed: Array=["carry","pouch"] if Participation.is_wild(player) else ["stash","shared"]
	if not allowed.has(source): return
	var stack:=InventoryModel.take(self,player,source,item,quantity)
	if stack.is_empty(): action_feedback(effects,id,"That stack changed. Refresh the inventory.");return
	var point: Vector3=player.pos+Vector3(.65,0,.35)
	if Participation.is_wild(player): point=battlefield.dash(player.pos,point)
	var drop: Dictionary={"id":Crypto.new().generate_random_bytes(12).hex_encode(),"stack":stack,"position":[point.x,point.y,point.z]}
	var drops:=inventory_drop_list(player)
	drops.append(drop)
	if effects == null and not Participation.is_wild(player) and progress.save_garden()!=OK:
		drops.erase(drop);InventoryModel.undo_take(self,player,source,stack)
		tell(id,"Could not save the dropped item. The stack was returned.");return
	action_feedback(effects,id,"Dropped %d %s. Close the inventory and press E nearby to recover it."%[quantity,Items.get_item(item).name])

func pickup_inventory_drop(id: int,player: Dictionary,key: String) -> void:
	if not Participation.is_wild(player) and persistence_session.is_guarded():
		run_guarded_action(id, Transactions.Scope.GARDEN, func(effects): _pickup_inventory_drop(id, player, key, effects))
	else:
		_pickup_inventory_drop(id, player, key, null)

func _pickup_inventory_drop(id: int,player: Dictionary,key: String,effects) -> void:
	var drops:=inventory_drop_list(player)
	for index in drops.size():
		var entry: Dictionary=drops[index]
		if entry.id!=key or not can_see_item_drop(player,entry): continue
		var values: Array=entry.position
		if player.pos.distance_to(Vector3(values[0],values[1],values[2]))>1.65: return
		var target: String="carry" if Participation.is_wild(player) else "stash"
		drops.remove_at(index)
		InventoryModel.put(self,player,target,entry.stack)
		if effects == null and not Participation.is_wild(player) and progress.save_garden()!=OK:
			InventoryModel.undo_put(self,player,target,entry.stack);drops.insert(index,entry)
			tell(id,"Could not save pickup. The stack remains on the ground.");return
		action_feedback(effects,id,"Picked up %d %s."%[entry.stack.quantity,Items.get_item(entry.stack.item).name])
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
	return not player.is_empty() and not Participation.is_wild(player) and player.get("pos",Vector3.INF).distance_to(stage.altar_position())<=1.65



func show_garden_altar(id: int) -> void:
	if not players.has(id) or not at_garden_altar(players[id]): return
	var data:=Altar.snapshot(self,players[id],[{},{}],int(players[id].get("altar_revision",0)))
	if id==HOST: open_garden_altar(data)
	else: open_garden_altar.rpc_id(id,data)

@rpc("authority","call_remote","reliable")
func open_garden_altar(data: Dictionary) -> void:
	ui.show_altar(data)

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
	var previous := int(player.get("altar_revision",0))
	if revision<=previous: return # Reliable replies already acknowledge the accepted request.
	player.altar_revision=revision
	if request.operation=="combine":
		if persistence_session.is_guarded():
			var result := run_guarded_action(id, Transactions.Scope.GARDEN, func(effects): return Altar.combine(self, player, draft, effects))
			player.altar_message = Transactions.feedback(result, "Could not save the Altar offering.")
			tell(id, player.altar_message)
		else:
			run_altar_save(id, player, Altar.combine.bind(self, player, draft))
	elif request.operation=="identify": run_altar_save(id, player, Altar.identify.bind(self, player))
	elif request.operation=="identify_all": run_altar_save(id, player, Altar.identify_all.bind(self, player))
	var data:=Altar.snapshot(self,player,draft,revision)
	if id==HOST: update_garden_altar(data)
	else: update_garden_altar.rpc_id(id,data)

@rpc("authority","call_remote","reliable")
func update_garden_altar(data: Dictionary) -> void:
	ui.update_altar(data)


func record_enemy_death(target: int,world_position: Vector3,origin: Vector3,expected_token: int = -1, finisher: String = "") -> void:
	if not encounter.death_pending(target, expected_token):
		return
	var spawn_token := "leader" if target == -1 else str(encounter.token(target))
	var kind: int = enemy_kind if target == -1 else int(encounter.scout(target).get("kind", 0))
	var mask: int = enemy_mutations if target == -1 else int(encounter.scout(target).get("mutations", 0))
	var summoned := target >= 0 and bool(encounter.scout(target).get("summoned", false))
	if not _queue_monster_reward(spawn_token, kind, mask, world_position, target == -1, summoned):
		return
	encounter.confirm_death(target)
	var boss := target == -1 and tactics.boss_kind >= 0
	# LeaderBehavior dispatches this role even before its lazy elite body exists.
	var elite := target == -1 and not boss
	expedition_statistics.defeat(participation.run_id(),finisher,elite,boss)
	if not summoned:
		encounter_kills.append(kind)
		encounter_kill_records.append({"kind":kind,"mask":mask})
	if target>=0: EnemyBehaviors.death(self,encounter.scout(target),world_position)
	elif not encounter.leader_tactics().is_empty(): EnemyBehaviors.death(self,encounter.leader_tactics(),world_position)
	var growth: int=enemy_growth if target==-1 else int(encounter.scout(target).get("growth",0))
	var direction: Vector3=(world_position-origin).normalized()
	enemy_death_serial+=1
	var scale_value: float=1.0 if tactics.boss_kind>=0 and target==-1 else (1.9 if participation.depth()==ROUTE_ROOMS else 1.0 if participation.depth()==1 else 1.22) if target==-1 else 1.0
	enemy_death_events.append({"id":enemy_death_serial,"position":[world_position.x,world_position.y,world_position.z],"direction":[direction.x,0,direction.z],"code":Enemies.encode(kind,mask,growth),"scale":scale_value,"born":CombatClock.now()})
	while enemy_death_events.size()>24: enemy_death_events.pop_front()

func death_events_snapshot() -> Array:
	var now:=CombatClock.now()
	var result: Array=[]
	for index in range(enemy_death_events.size()-1,-1,-1):
		if now-int(enemy_death_events[index].born)>2300: enemy_death_events.remove_at(index)
	for event in enemy_death_events:
		var copy: Dictionary=event.duplicate();copy.erase("born");copy.age=maxf(0,(now-int(event.born))/1000.0);result.append(copy)
	return result


func attack_animation_snapshot(player: Dictionary, at_ms: int=-1) -> Dictionary:
	var now:=CombatClock.now() if at_ms<0 else at_ms
	if int(player.get("cast_until",0))>now:
		var cast_pose: Dictionary = preload("res://subclass_combat.gd").pose_state(player,now)
		return {"active":true,"phase":clampf(1.0-(int(player.cast_until)-now)/550.0,0,1),"combo":int(player.get("skill_fx_seq",0)),"duration":550,"form":"cast","clip":cast_pose.get("clip",""),"direction":cast_pose.get("direction",null)}
	var attack: WeaponActions.State = player[WeaponActions.STATE]
	return attack.animation(now,player.facing,bool(player.get("mouse_aim",false)),player.get("aim_direction",Vector3.INF),WeaponMotion.profile(WeaponMotion.form(player)).clip)

func weapon_effect_color(player: Dictionary) -> Color:
	var part:=int(player.get("weapon",0))
	if Parts.is_plant(part): return Color(Seeds.DEFINITIONS[Parts.plant_source(part)].color).lightened(.25)
	return Color("#d7e8ab")

func emit_combat_event(kind: String,shape: String,from: Vector3,to: Vector3,duration: float,color: Color,reach: float,combo: int,options: Dictionary={}) -> void:
	combat_event_serial+=1
	combat_events.append({"id":combat_event_serial,"kind":kind,"shape":shape,"from":[from.x,from.y,from.z],"to":[to.x,to.y,to.z],"duration":duration,"color":color.to_html(),"reach":reach,"combo":combo,"span":2.7 if shape=="wide_arc" else 1.3 if shape=="knife_arc" else 1.9,"born":CombatClock.now()})

	var latest: Dictionary=combat_events.back()
	for key in options:
		if key in ["form","pattern","contact","width","span","yaw_offset","projectile_radius","height","owner","clip","weapon_release","target_token","core_shapes","core_phase"]:latest[key]=options[key]
	if kind=="impact" and shape in ["hit","hurt","block","heal"]:
		latest.amount=maxi(0,roundi(reach));latest.target_id=combo
		latest.target_token=encounter.token(combo) if shape=="hit" and combo>=0 and combo<encounter.scout_count() else -1
	if kind=="subclass_release":
		latest.label=options.get("label","")
	if kind=="ability":
		latest.label=shape.replace("_"," ").capitalize()
		if players.has(combo):
			for slot in 2:
				var skill:=Skills.resolve_in_world(self,int(players[combo].frame),slot,players[combo].character)
				if str(skill.mode)==shape:latest.label=skill.name;break
		latest.label=options.get("label",latest.label)
	if is_instance_valid(Journal.current) and Journal.current.detail:
		Journal.event("combat","presentation_event",{"event_id":latest.id,"kind":kind,"shape":shape,"amount":latest.get("amount",0),"from":latest.from,"to":latest.to,"target_id":latest.get("target_id",-2),"target_token":latest.get("target_token",-1),"weapon_form":latest.get("form",""),"pattern":latest.get("pattern",""),"width":latest.get("width",0),"span":latest.get("span",0),"contact":latest.get("contact",0),"status_actor":latest.combo if kind=="status" else -2,"status_stacks":latest.reach if kind=="status" else 0})
	while combat_events.size()>80: combat_events.pop_front()
	if not SaveBatch.active and not SaveBatch.guarded_active(): publish_combat_event(latest)

func publish_combat_event(source: Dictionary) -> void:
	if network_session.transport()==null or not multiplayer.is_server(): return
	var event := source.duplicate()
	event.erase("born")
	event.age=maxf(0,(CombatClock.now()-int(source.born))/1000.0)
	receive_combat_event.rpc(event,str([participation.route(),participation.floor(),participation.seed()]))

func emit_weapon_attack(player: Dictionary,from: Vector3,to: Vector3,stats: Dictionary,_now: int) -> void:
	var form:=WeaponMotion.form(player);var profile:=WeaponMotion.profile(form)
	var attack: WeaponActions.State = player[WeaponActions.STATE]
	var duration: float=attack.duration_ms()/1000.0
	if WeaponMotion.is_projectile(form): duration=clampf(from.distance_to(to)/float(profile.speed),.08,.45)
	var description:=preload("res://weapon_contact.gd").describe(form,stats)
	for id in players:
		if is_same(players[id],player):description.owner=id;break
	emit_combat_event("projectile" if WeaponMotion.is_projectile(form) else "swing",str(profile.shape),from,to,duration,weapon_effect_color(player),float(stats.reach),attack.sequence(),description)

func combat_events_snapshot() -> Array:
	var now:=CombatClock.now();var result: Array=[]
	for index in range(combat_events.size()-1,-1,-1):
		if now-int(combat_events[index].born)>float(combat_events[index].duration)*1000+150: combat_events.remove_at(index)
	for event in combat_events:
		if event.kind=="status":continue
		var copy: Dictionary=event.duplicate();copy.erase("born");copy.age=maxf(0,(now-int(event.born))/1000.0);result.append(copy)
	var known: Array=result.map(func(e):return e.id)
	for event in preload("res://combat_status.gd").snapshot(self,now):
		if not known.has(event.id):result.append(event)
	return result

func attack_hints_snapshot() -> Array:
	var result: Array=Bosses.hints(self)
	result.append_array(preload("res://glasscap_feint.gd").hints(self,CombatClock.now()))
	if tactics.boss_kind<0 and not encounter.leader_tactics().is_empty():result.append_array(preload("res://elite_enemy.gd").hints(self))
	if enemy_health()>0 and tactics.winding_up and not Bosses.owns_warnings(tactics.boss_kind) and (tactics.boss_kind>=0 or encounter.leader_tactics().is_empty()):
		var target:=tactics.landing if tactics.attack_mode=="vault" or tactics.boss_kind>=0 else tactics.position
		result.append({"id":-1,"role":("charge" if tactics.attack_mode in ["root_sweep","orchard_march","drowned_surge","matriarch_lunge","memory_lance","remembered_rend"] else "volley") if tactics.boss_kind>=0 else "vault" if tactics.attack_mode=="vault" else "swipe","from":[tactics.position.x,0,tactics.position.z],"to":[target.x,0,target.z],"radius":Bosses.warning_radius(self) if tactics.boss_kind>=0 else LeaderBehavior.strike_radius(self),"width":Bosses.warning_width(self) if tactics.boss_kind>=0 else .85,"remaining":maxf(0,(tactics.strike_at-CombatClock.now())/1000.0)})
	var attacks=preload("res://enemy_attack.gd")
	result.append_array(attacks.scout_hints(encounter,participation.epoch(),CombatClock.now(),
		func(scout: Dictionary) -> Dictionary: return attacks.current(self,scout)))
	if enemy_kind==11 and enemy_health()>0 and tactics.engaged and encounter.leader_tactics().get("attack",{}).get("variant","")!="planted_canopy":
		result.append(attacks.warning(-2000,"canopy",tactics.position,tactics.position,float(Enemies.get_kind(11).shelter_radius),0,0))
	for index in encounter.scout_count():
		var actor: Dictionary=encounter.scout(index)
		if actor.kind==11 and encounter.hp(index)>0 and actor.engaged and actor.get("attack",{}).get("variant","")!="planted_canopy":
			result.append(attacks.warning(-2001-index,"canopy",actor.pos,actor.pos,float(Enemies.get_kind(11).shelter_radius),0,0))
	result.append_array(preload("res://expedition_pressure.gd").hints(self))
	result.append_array(preload("res://core_combat.gd").hints(self))
	result.append_array(preload("res://thorn_affinity.gd").hints(self))
	result.append_array(preload("res://warden_combat.gd").hints(self,CombatClock.now()))
	return result


func show_planting_picker(id: int,slot: int) -> void:
	var p: Dictionary=players[id]
	if Participation.is_wild(p) or slot<0 or slot>=progress.plots.size() or p.pos.distance_to(stage.bed_position(slot))>1.65 or progress.plots[slot].species>=0: return
	var stock: Array=seed_reserve(p).stock.duplicate()
	if id==HOST: open_planting_picker(slot,stock)
	else: open_planting_picker.rpc_id(id,slot,stock)
@rpc("authority","call_remote","reliable")
func open_planting_picker(slot: int,stock: Array) -> void:
	ui.show_planting(slot,stock,persistence_session.pending_notice().is_empty())
@rpc("authority","call_remote","reliable")
func close_planting_picker() -> void:
	if ui.panel_is_open("planting"): ui.close_panels()



@rpc("authority","call_remote","reliable",1)
func receive_details(payload: PackedByteArray,garden: PackedByteArray,inventory_data: Array,state_key: String) -> void:
	guest_replication.receive_details(guest_replication_world,payload,garden,inventory_data,state_key)


@rpc("authority","call_remote","reliable",2)
func receive_combat_event(event: Dictionary,key: String) -> void:
	guest_replication.receive_event(event,key)


func guest_combat_events(player: Dictionary) -> Array:
	var key := str([participation.route(),participation.floor(),participation.seed()])
	return guest_replication.events(key,CombatClock.now(),player.get("combat_events",[]))


func request_ip_join() -> void:
	if stage.experimental_garden != null:
		return_to_main_menu("Choose a character and join from the Co-op tab.")
		return
	var recent := Network.load_settings(slot_storage_root)
	network_dialog.begin(recent.address,recent.port,true,str(local_character.data.get("name","Wanderer")))

@rpc("authority","call_remote","reliable")
func connection_accepted(profile: Dictionary) -> void:
	session_world.accepted(profile)

@rpc("authority","call_remote","reliable")
func connection_rejected(reason: String) -> void:
	session_world.rejected(reason)

func party_travel_state() -> Dictionary:
	var id:=multiplayer.get_unique_id()
	return PartyTravel.snapshot(self,id) if multiplayer.is_server() else players.get(id,{}).get("party_travel",{})

func send_travel_ready(unready: bool) -> void:
	var state:=party_travel_state()
	if not state.is_empty(): send_garden_action(("travel_unready:" if unready else "travel_ready:")+str(state.epoch))

func update_combat_tracking(delta: float) -> void:
	for id in players:
		var p: Dictionary=players[id]
		if not Participation.is_wild(p): combat_last_positions.erase(id);combat_velocity[id]=Vector3.ZERO;continue
		var previous: Vector3=combat_last_positions.get(id,p.pos)
		var velocity: Vector3=(p.pos-previous)/maxf(.001,delta)
		# Teleports/dodges do not become implausible long-range predictive aim.
		combat_velocity[id]=velocity if velocity.length()<6.2 else Vector3.ZERO
		combat_last_positions[id]=p.pos
		combat_threat[id]=maxf(0,float(combat_threat.get(id,0))-delta*2.5)

func select_attack_target(player: Dictionary,reach: float) -> int:
	return preload("res://class_ability_targeting.gd").automatic(self,player,reach)


func roll_kill_trophy(kind: int,mask: int=0,leader: bool=false) -> String:
	var chance:=float(Enemies.get_kind(kind).get("trophy_chance",0.6)) if Enemies.get_kind(kind).get("boss",false) else Director.trophy_chance(participation.floor(),leader and participation.depth()==ROUTE_ROOMS,mask!=0)
	return roll_monster_item(kind,mask) if rng.randf()<chance else ""

@rpc("authority","call_remote","reliable",2)
func receive_vitals(states: Dictionary) -> void:
	guest_replication.receive_vitals(guest_replication_world,states)


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
	if multiplayer.is_server() and aim.is_finite() and session_world.allow_remote(id,"combat_input",60):mouse_controls.receive(self,id,aim,held,CombatClock.now())

func send_wild_flora_harvest(identity: String) -> void:
	if identity.is_empty(): return
	if multiplayer.is_server():
		harvest_wild_flora(HOST,identity)
	elif network_session.role() == "Guest":
		var actor: Dictionary = players.get(multiplayer.get_unique_id(),{})
		var stamp := ActionIdentity.current_stamp(self,actor)
		if not stamp.is_empty(): request_wild_flora.rpc_id(HOST,identity,stamp)

@rpc("any_peer","call_remote","reliable")
func request_wild_flora(identity: String, stamp: String) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or identity.is_empty() or identity.length()>256 or stamp.is_empty() or stamp.length()>96: return
	if not session_world.allow_remote(peer,"action",30): return
	if stamp == ActionIdentity.current_stamp(self,players.get(peer,{})):
		harvest_wild_flora(peer,identity)
