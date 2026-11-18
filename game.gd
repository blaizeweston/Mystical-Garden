extends Node3D
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const Participation = preload("res://expedition_participation.gd")
const Session = preload("res://network_session.gd")
const SessionWorld = preload("res://session_world.gd")
const ActionIdentity = preload("res://network_action_identity.gd")

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
var network_dialog: Window
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
const RANGED_DISTANCE := 2.75
const ENGAGE_RADIUS := 8.0
const SCOUT_RADIUS := 1.45
const DODGE_DISTANCE := 2.8
const DODGE_COOLDOWN_MS := 850
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
var pending_finale_at:=0
var pending_finale_peer:=1
var enemy_death_serial:=0
var enemy_death_events: Array=[]
var death_visuals: Node3D
const WeaponMotion=preload("res://weapon_motion.gd")
var combat_visuals: Node3D
var combat_events: Array=[]
var combat_event_serial:=0
var received_combat_events: Array=[]
var projectile_queue: Array=[]
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
var client_leader_hp := ENEMY_HEALTH
var battlefield := Battlefield.new()
var client_pack := PackedFloat32Array()
var run_guardians := 0
var map_rng := RandomNumberGenerator.new()
var pressure_at := 0
var client_campaign := PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0])
var damage_this_room := 0
var ranged_damage_this_room := 0
var ranged_clears := 0
var drop_pos := Vector3.ZERO
var has_drop := false
var rng := RandomNumberGenerator.new()
var deepest_milestone := 0
var client_pouch_filled := false
var client_briar_bound := false
var recollection_checked:=false
var checkpoint_pending:=false
var checkpoint_ready: Dictionary={}
const Altar=preload("res://altar_service.gd")

var client_garden := [0, false, false, [false, false, false], [false, false, false], [0, 0, 0], 0, false, 0, false, 0, false, PackedByteArray([0,0,0,0,0,0,0,0,0])]
var next_snapshot := 0.0
var next_details:=0.0
var client_details: Dictionary={}
var client_details_key: String=""
var toast_until := 0
var status := "The Heart shelters this Garden. Follow the path to the Wilds gate.":
	set(value):
		status = value
		toast_until = Time.get_ticks_msec() + 4800
var net_view=preload("res://network_presentation.gd").new()
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
var trait_events: Array=[]
const Life=preload("res://expedition_life.gd")
var spectator_view: Node
var client_inventory := [0, 0, 0, [false, false, false], 0, 0]
var client_carried_count := 0

const Items=preload("res://item_catalog.gd")
const InventoryModel=preload("res://inventory_model.gd")
var wild_item_drops: Array=[]
var inventory_drop_visuals: Node
const LOOK_NAMES=preload("res://character_appearance.gd").OPTIONS
var growth_clock := 0.0
var exploration: Node


func _init() -> void:
	guest_character.path = Life.Preview.STORAGE_PATH.path_join("character-local-guest.cfg") if Life.Preview.playtest else "user://character-local-guest.cfg"


func _ready() -> void:
	if has_meta(&"experimental_terrain") and not preload("res://assets/terrain_m02/experimental/experiment_mode.gd").verified():
		set_process(false)
		set_physics_process(false)
		_refuse_unowned_world.call_deferred()
		return
	if has_meta(&"experimental_terrain") or preload("res://persistence_writer_integration.gd").default_route(get_tree()):
		var owner: Variant = persistence_session if persistence_session.is_guarded() else null
		if not (owner is GuardedTitleSession) or not owner.authorizes(local_character.path) or (not network_session.joined_from_title() and not owner.authorizes(progress.path)):
			set_process(false)
			set_physics_process(false)
			_refuse_unowned_world.call_deferred()
			return
	get_tree().auto_accept_quit = false
	if has_meta(&"experimental_terrain"):
		var terrain_experiment = preload("res://assets/terrain_m02/experimental/experiment_garden.gd").new()
		stage.add_child(terrain_experiment)
		terrain_experiment.configure(self, stage)
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
	if not persistence_session.is_guarded():
		var result := progress.load_garden()
		if result != OK and result != ERR_FILE_NOT_FOUND:
			status = "Could not read Garden save (error %d)." % result
	network_compatibility=preload("res://network_compatibility.gd").new()
	add_child(network_compatibility)
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(func(id): SessionWorld.remove(self,id))
	multiplayer.connected_to_server.connect(SessionWorld.joined.bind(self))
	multiplayer.connection_failed.connect(SessionWorld.connection_failed.bind(self))
	multiplayer.server_disconnected.connect(SessionWorld.server_disconnected.bind(self))
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
		if load("res://expedition_transitions.gd").request_guest_exit(self,Session.Exit.APPLICATION): return
		if persistence_session.is_guarded():
			if not prepare_guarded_exit(): return
			persistence_session.begin_shutdown()
			SessionWorld.offline(self)
			release_slot()
			get_tree().quit()
			return
		if network_session.role() in ["Host","Solo"] and participation.active():
			if not load("res://expedition_transitions.gd").finish_voluntary(self): return
		if character_dirty:
			save_local_character()
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
	# Feature panels keep their existing domain adapters until plan step 1b.
	for feature in ["inventory","progression","loadout","graft","altar","planting","summary"]:
		var path: String = {"inventory":"inventory_panel","progression":"progression_panel",
			"loadout":"loadout_panel","graft":"affinity_grafting_panel","altar":"garden_altar_panel",
			"planting":"planting_panel","summary":"run_summary_panel"}[feature]
		var view = load("res://"+path+".gd").new()
		view.game = self
		ui.mount_feature(feature,view)
	network_dialog=preload("res://network_panel.gd").new()
	add_child(network_dialog)
	network_dialog.applied.connect(func(address: String,port: int,_join: bool):
		var saved := Network.save_settings(slot_storage_root,address,port)
		if saved!=OK: Journal.event("network","preference_save_failed",{"error":saved},"warning")
		if SessionWorld.join(self,address,port)!=OK:
			network_dialog.begin(address,port,true,str(local_character.data.get("name","Wanderer")),Transactions.feedback_text(self,status)))
	inventory_drop_visuals=preload("res://inventory_drop_visuals.gd").new()
	inventory_drop_visuals.game=self
	add_child(inventory_drop_visuals)
	preload("res://garden_interaction_view.gd").mount(self)

func request_host_session() -> void:
	if network_session.role()=="Solo" and SessionWorld.host(self)!=OK: return
	if network_session.role()=="Host": network_dialog.begin_host(network_session.port(),Network.lan_addresses(),"Your Garden",not participation.active())

func _handle_ui_request(command: String, data: Dictionary) -> void:
	# Presentation requests go through the same authorized domain operations as keys/RPCs.
	match command:
		"settings":
			mouse_controls.release(self)
			settings_dialog.begin(app_settings)
		"save": save_progress(HOST,"Garden saved.")
		"host": request_host_session()
		"join": request_ip_join()
		"leave":
			if not load("res://expedition_transitions.gd").request_guest_exit(self,Session.Exit.SESSION): SessionWorld.leave(self,"Back in your own Garden.")
		"abandon": request_abandon_run()
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
			send_garden_action("bank_part_%d"%(value-1000) if value>=1000 else "bank_seed_%d"%value)
		"inventory_drop": send_inventory_action("drop",str(data.source),"",str(data.item),int(data.quantity))
		"face_heart":
			var player: Dictionary = players.get(HOST,{})
			if not player.is_empty():
				player.pos=Stage.HEART
				awaken_heart(HOST,player)














@rpc("any_peer", "call_remote", "reliable")
func register_character(identity: String, profile: Dictionary,catalog: Dictionary={},protocol: int=0) -> void:
	SessionWorld.register(self,multiplayer.get_remote_sender_id(),identity,profile,catalog,protocol)

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
	players[id] = {Session.STATE:link,"velocity":Vector3.ZERO,"damage_seq":0,"damage_amount":0,"vitals_revision":0,"pos": spawn, Participation.STATE: participation.attach(id), PlayerLifecycle.STATE: PlayerLifecycle.start_life(), "lost_health":0, "prepared": 0, "weapon": 0, "experiment": 0, ExpeditionWallet.STATE: ExpeditionWallet.Wallet.new(), "upgrade_seed":Crypto.new().generate_random_bytes(8).hex_encode().hash(),
		"weapon_kind":0, "catalyst":0, "prepared_catalyst":0, "cargo_plan":Parts.empty_counts(), "frame": Frames.WARDEN, Cooldowns.STATE: Cooldowns.Timers.new(), Protection.STATE: Protection.State.new(), WeaponActions.STATE: WeaponActions.State.new(), "contributed": false,
		"character": local_character.data if id == HOST else Character.blank(),
		"seed_choice": 0, "carried_seeds": [],"safe_items":[],"carried_items":{}, "pouch": false, "loot_pending": false,
		"donation_choice": Parts.EMPTY, "cache_claimed": false,
		"carried_parts": Parts.empty_counts(), "secondary": Parts.EMPTY,
		"prepared_secondary": Parts.EMPTY, Conditions.STATE: Conditions.State.new(), PlayerVitals.STATE: PlayerVitals.Health.new(float(base_health), base_health), "facing": Vector3.FORWARD}
	restore_class_loadout(players[id])
	preload("res://garden_growth_service.gd").register(self,id)


func _input(event: InputEvent) -> void:
	if preload("res://ability_aim.gd").release_event(self,event):
		get_viewport().set_input_as_handled()
		return
	if get_meta("garden_cinematic_active",false):return
	if settings_dialog!=null and settings_dialog.visible: return
	if stage != null and stage.experimental_garden != null and stage.experimental_garden.cancel_placement_input(event):
		get_viewport().set_input_as_handled()
		return
	if preload("res://run_summary_panel.gd").handle_input(self,event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("session_menu"):
		ui.close_panels() if ui.is_overlay_open() else ui.toggle_panel("session")
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
	if get_meta("garden_cinematic_active",false):return
	if settings_dialog!=null and settings_dialog.visible: return
	if stage.experimental_garden != null and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B:
		if stage.experimental_garden.can_view_development():
			stage.experimental_garden.open_development()
			get_viewport().set_input_as_handled()
			return
	mouse_controls.frame(self)
	if network_session.role()=="Connecting" or (network_session.role()=="Guest" and client_details.is_empty()):
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
	if preload("res://ability_aim.gd").input_event(self,event):
		get_viewport().set_input_as_handled()
		return
	var local_player: Dictionary=players.get(HOST if multiplayer.is_server() else multiplayer.get_unique_id(),{})
	if not Participation.is_wild(local_player):
		for old_action in ["research","experiment","catalyst","graft","donate","select_donation","awaken","destination","nurture","harvest_offshoot","trait","frame","expand_plot"]:
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
		elif network_session.role() == "Guest":
			request_dodge.rpc_id(HOST, direction)


func send_action(strike: bool) -> void:
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
		if not SessionWorld.allow_remote(self,id,"profile_receipt",120,true): return
		var fields := action.split(":")
		if fields.size()==5 and fields[2].is_valid_int():
			guest_projection_status(id,fields[1],int(fields[2]),fields[3],fields[4])
		return
	if SessionWorld.allow_remote(self,id,"action",30): garden_action(id, action)


func garden_action(id: int, action: String) -> void:
	if not persistence_session.can_write(): return
	if action.begins_with("core_cast:"):
		preload("res://core_combat.gd").command(self,id,players.get(id,{}),action)
		return
	if action.begins_with("class_cast:"):
		preload("res://ability_aim.gd").command(self,id,players.get(id,{}),action)
		return
	var diagnostic_request:=Journal.interaction(self,id,action,"begin")
	var persistent: bool=action in ["experiment","donate"] or action.begins_with("breed_") or action.begins_with("care_")
	if persistent and not persistence_session.is_guarded(): Transactions.run(self,func(): _garden_action(id,action))
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
	if action=="altar_identify":
		if at_garden_altar(player):
			run_altar_save(id, player, Altar.identify.bind(self, player))
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
		load("res://expedition_transitions.gd").abandon(self,id,player,action.trim_prefix("abandon_run:") if action.begins_with("abandon_run:") else "")
		return
	if action.begins_with("care_"):
		var pieces:=action.split("_")
		if pieces.size()!=3 or not pieces[2].is_valid_int(): return
		var value:=int(pieces[2])
		if pieces[1]=="reclaim" and value>=0 and value<Seeds.NAMES.size() and progress.discoveries[value] and at_garden_station(player,"seed_archive"):
			reclaim_seed(id,player,value)
		elif pieces[1]=="offer" and Parts.is_monster(value) and at_garden_station(player,"monster_studies"):
			if stored_counts(player)[value]<=0:
				tell(id,"That trophy is no longer available.")
				return
			offer_monster(id,player,value)
		else:
			tell(id,"Move to the appropriate Garden station with an available ingredient.")
		return
	if action.begins_with("plant_at_"):
		var fields:=action.split("_")
		if fields.size()!=4 or not fields[2].is_valid_int() or not fields[3].is_valid_int(): return
		var slot:=int(fields[2]);var species:=int(fields[3])
		if Participation.is_wild(player) or slot<0 or slot>=progress.plots.size() or species<0 or species>=Seeds.NAMES.size() or player.pos.distance_to(stage.bed_position(slot))>1.65: return
		if progress.plots[slot].species>=0 or progress.offshoot_in_bed(slot)>=0 or seed_reserve(player).stock[species]<=0:
			tell(id,"That bed or seed is no longer available.");show_planting_picker(id,slot);return
		player.seed_choice=species
		if plant_seed(id,slot):
			if id==HOST: ui.close_panels()
			else: close_planting_picker.rpc_id(id)
		return
	if action.begins_with("travel_ready:") or action.begins_with("travel_unready:"):
		var token:=action.get_slice(":",1)
		if not token.is_valid_int() or int(token)!=participation.travel_epoch() or participation.travel_kind().is_empty(): return
		if action.begins_with("travel_unready:"): participation.withdraw(id,int(token))
		else: PartyTravel.request(self,id,participation.travel_kind())
		return
	if action=="depart":
		if at_weapon_gate(player):
			load("res://expedition_transitions.gd").enter(self,id,player)
			if Participation.is_wild(player) and not persistence_session.is_guarded(): close_flow_for(id)
		return
	if action.begins_with(AffinityCards.COMMAND):
		_affinity_checkpoint_command(id, player, action)
		return
	if action.begins_with("heart_material_"):
		if at_heart(player) and not Participation.is_wild(player):
			var choice:=action.trim_prefix("heart_material_")
			if choice=="auto" or Seeds.index_of(choice)>=0: progress.heart.material_choice="" if choice=="auto" else choice
		return
	if action.begins_with("heart_confirm:"):
		if id!=HOST or not at_heart(player) or participation.active(): return
		var request=JSON.parse_string(action.trim_prefix("heart_confirm:"))
		if not request is Dictionary or not request.get("id") is String or not request.get("plan") is Dictionary: return
		var node:=HeartCatalog.get_node(request.id)
		if node.is_empty(): return
		var expected: Dictionary={}
		if not progress.heart.matches_plan(request.plan,expected): tell(id,"Available ingredients changed. Review the updated material preview and confirm again.");return
		tell(id,run_heart_save(progress.heart.start.bind(progress,request.id)));return
	if action.begins_with("heart_start_"):
		if id==HOST and at_heart(player) and not participation.active():
			tell(id,run_heart_save(progress.heart.start.bind(progress,action.trim_prefix("heart_start_"))))
		else: tell(id,"The host restores Garden technologies at the Heart between expeditions.")
		return
	if action.begins_with("heart_infusion:"):
		if not at_heart(player) or Participation.is_wild(player): return
		var offer=JSON.parse_string(action.trim_prefix("heart_infusion:"))
		if not offer is Dictionary: return
		if offer.get("project","")!=progress.heart.active or not progress.heart.matches_plan(offer.get("plan",{}),progress.heart.material_plan(progress,progress.heart.OFFER_PARTS).parts):
			tell(id,"Research or offering materials changed. Review the updated preview and try again.");return
		tell(id,run_heart_save(progress.heart.infuse.bind(progress)));return
	if action=="heart_infuse":
		if at_heart(player) and not Participation.is_wild(player): tell(id,run_heart_save(progress.heart.infuse.bind(progress)))
		return
	if action.begins_with("bank_"):
		bank_checkpoint_item(id,player,action)
		return
	if (action.begins_with("class_") and action not in ["class_skill","class_skill_two"]) or action.begins_with("loadweapon_") or action.begins_with("loadpart_") or action.begins_with("pack_") or action.begins_with("learn_") or action.begins_with("respec_") or action=="clearpack":
		handle_loadout_action(id,player,action)
		return
	if action.begins_with("breed_"):
		var fields := action.split("_")
		if fields.size() == 3 and fields[1].is_valid_int() and fields[2].is_valid_int() and not Participation.is_wild(player) and stage.altar_position().distance_to(player.pos) <= 1.65:
			run_seed_experiment(id, player, int(fields[1]), int(fields[2]))
		else:
			tell(id, "Crossbreed at the Garden altar.")
		return
	if action.begins_with("look_"):
		if not Participation.is_wild(player) and action in ["look_0", "look_1", "look_2", "look_3", "look_4"]:
			var index := int(action.trim_prefix("look_"))
			if persistence_session.is_guarded() and id != HOST:
				run_guarded_action(id,Transactions.Scope.GARDEN,func(effects):
					var look: Array = player.character.appearance
					look[index] = (int(look[index]) + 1) % LOOK_NAMES[index].size()
					save_action_profile(id,effects))
				return
			var applied := Transactions.run_gameplay(self, Transactions.Scope.PROFILE, func():
				var look: Array = player.character.appearance
				look[index] = (int(look[index]) + 1) % LOOK_NAMES[index].size()
				if not persistence_session.is_guarded(): publish_character(id)
				return true, false)
			if Transactions.committed(applied.persistence): record_character(id)
		return
	match action:
		"expand_plot":
			tell(id,"Select a planting-bed node in Heart / Knowledge to begin its research.")
		"extract":
			load("res://expedition_transitions.gd").checkpoint(self,id, false)
		"awaken":
			if at_heart(player):
				awaken_heart(id, player)
		"destination":
			if id == HOST and not Participation.is_wild(player) and not participation.active() and stage.gate_position().distance_to(player.pos) <= preload("res://gate_interaction.gd").RANGE:
				cycle_destination()
		"nurture", "harvest_offshoot":
			return # Retired commands cannot consume materials or reserve a bed.
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
			use_class_skill(id,player,1)
		"class_skill":
			use_class_skill(id, player)
		"pouch":
			if Participation.is_wild(player) and not player.pouch:
				tell(id,InventoryModel.transfer(self,player,"carry","pouch","unidentified_seed",1))
		"research":
			if Participation.is_wild(player):
				use_class_skill(id,player,1)
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
			elif not Participation.is_wild(player) and stage.altar_position().distance_to(player.pos) <= 1.65:
				for step in range(1, Progress.ALTAR_PAIRS.size() + 1):
					var next := (int(player.experiment) + step) % Progress.ALTAR_PAIRS.size()
					var pair: Array = Progress.ALTAR_PAIRS[next]
					if progress.discoveries[int(pair[0])] and progress.discoveries[int(pair[1])]:
						player.experiment = next
						break
		"experiment":
			if not Participation.is_wild(player) and stage.altar_position().distance_to(player.pos) <= 1.65:
				run_seed_experiment(id, player, -1, -1, true)
		"flower":
			var slot := nearby_plot(player.pos)
			if slot>=0:preload("res://garden_crop_service.gd").harvest_seeds(self,id,slot)


func awaken_heart(id: int, player: Dictionary) -> void:
	if not Campaign.LEGACY_ENDING_ENABLED: return
	if not participation.active() and participation.route()==Campaign.HEART and participation.travel_kind()=="depart":
		load("res://expedition_transitions.gd").enter(self,id,player);return
	if participation.active():
		if participation.route() == Campaign.HEART:
			load("res://expedition_transitions.gd").enter(self,id, player)
		return
	if id != HOST:
		tell(id, "The host can begin the finale when the Heart is ready.")
		return
	if not progress.finale_available():
		tell(id, "The Heart's restoration is incomplete. Check Inventory for progress.")
		return
	var previous := participation.route()
	participation.select_route(Campaign.HEART)
	load("res://expedition_transitions.gd").enter(self,id, player)
	if not Participation.is_wild(player) and participation.travel_kind()!="depart":
		participation.select_route(previous)


func cycle_destination() -> void:
	for offset in range(1, Campaign.HEART + 1):
		var site := (participation.route() + offset) % Campaign.HEART
		if progress.campaign.available(site):
			participation.select_route(site)
			break
	for id in players:
		tell(id, "Selected %s. Entry costs %d shared plant parts." % [
			Campaign.NAMES[participation.route()], Campaign.SHORTCUT_COST[participation.route()]])


func route_rooms() -> int:
	return 1 if participation.route() == Campaign.HEART else ROUTE_ROOMS


func enemy_name() -> String:
	if tactics.boss_kind>=0: return Enemies.get_kind(tactics.boss_kind).name
	if participation.route() != Campaign.HEART:
		return ("Longlimb " if tactics.longlimb else "Elite ")+Enemies.get_kind(enemy_kind).name+" · "+preload("res://elite_enemy.gd").empowered(enemy_kind)
	if tactics.longlimb:
		return "Longlimb " + Enemies.get_kind(enemy_kind).name
	return "Awakened Heart" if participation.route() == Campaign.HEART else Enemies.get_kind(enemy_kind).name


func campaign_snapshot() -> PackedInt32Array:
	var flags := 0
	for i in progress.campaign.cleared.size():
		if progress.campaign.cleared[i]:
			flags |= 1 << i
	var result := PackedInt32Array([participation.route(), flags, Campaign.DORMANT if not Campaign.LEGACY_ENDING_ENABLED else progress.campaign.offshoots[0],
		Campaign.DORMANT if not Campaign.LEGACY_ENDING_ENABLED else progress.campaign.offshoots[1], Campaign.DORMANT if not Campaign.LEGACY_ENDING_ENABLED else progress.campaign.offshoots[2], Campaign.UNFINISHED if not Campaign.LEGACY_ENDING_ENABLED else progress.campaign.ending,
		roundi(tactics.active_radius * 100.0), 0, participation.seed(), participation.floor(),
		participation.cycle(), maxi(0, ceili((pressure_at - Time.get_ticks_msec()) / 1000.0)),
		progress.campaign.best_clear, progress.campaign.best_extraction,
		progress.campaign.memories[0], progress.campaign.memories[1], progress.campaign.memories[2],
		int(progress.finale_available()), Enemies.encode(enemy_kind, enemy_mutations, enemy_growth)])
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


# Only the guarded route queues feedback. Legacy callers retain their existing
# write and publication order. The typed boundary decides whether to publish.
func snapshot_expedition_runtime() -> Dictionary:
	return {"map_rng":map_rng.state, "heal_rng":Life.Preview.heal_rng.state, "battlefield":battlefield,
		"mouse":Transactions.snapshot(mouse_controls),
		"aim_visible":is_instance_valid(mouse_controls.marker) and mouse_controls.marker.visible,
		"core":get_meta(&"core_combat", {}).duplicate(true) if has_meta(&"core_combat") else null}

func restore_expedition_runtime(state: Dictionary) -> void:
	map_rng.state=state.map_rng
	Life.Preview.heal_rng.state=state.heal_rng
	battlefield=state.battlefield
	Transactions.restore(mouse_controls,state.mouse)
	if is_instance_valid(mouse_controls.marker): mouse_controls.marker.visible=state.aim_visible
	if state.core != null: set_meta(&"core_combat",state.core)
	elif has_meta(&"core_combat"): remove_meta(&"core_combat")

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
			if int(event.id)>first_event: publish_combat_event(event)
		for effect in effects:
			effect.call()
		if persistence_session.is_blocked() and persistence_session.can_publish_state() and multiplayer.is_server():
			net_view.publish_committed_cleanup.call_deferred(self,network_session.transport())
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

func run_seed_experiment(id: int, player: Dictionary, first: int, second: int, legacy_recipe := false) -> void:
	var action := func(effects):
		var stock: Array = seed_reserve(player).stock
		var outcome := progress.experiment(player.experiment, stock) if legacy_recipe else progress.breed(first, second, stock)
		if outcome.is_empty():
			action_feedback(effects, id, "Not enough identified seeds for this experiment." if legacy_recipe else "Need one identified seed of each parent (two for a matching pair).")
		elif effects == null:
			save_progress(id, outcome)
		else:
			action_feedback(effects, id, outcome)
	if persistence_session.is_guarded():
		run_guarded_action(id, Transactions.Scope.GARDEN, action)
	else:
		action.call(null)

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
	return has_meta(&"experimental_terrain") and persistence_session.is_guarded()

func flush_kill_rewards() -> bool:
	if persistence_session.is_blocked():
		return false
	# The active experimental floor pays run loot promptly and banks Class XP
	# at a checkpoint. Garden disconnects still use guarded settlement.
	if _defers_kill_profiles() and participation.active():
		return true
	if persistence_session.is_guarded():
		if not monster_rewards.has_pending() and departure_settlement.is_empty():
			return true
		if Life.living_ids(self).is_empty() and departure_settlement.has_wild_departure():
			return load("res://expedition_transitions.gd").finish_failed(self)
		var result := run_guarded_action(HOST, Transactions.Scope.PAIR, func(effects):
			settle_expedition_rewards(effects, true)
			return true)
		return Transactions.committed(result.persistence)
	if monster_rewards.has_pending() and not Transactions.run(self, _apply_pending_kill_rewards):
		return false
	if not SaveBatch.active:
		_publish_kill_reward_notices(monster_rewards.take_legacy_notices())
	return true

func _kill_reward_identity(id: int, player: Dictionary) -> String:
	return local_character.identity if id == HOST else Session.inventory_owner(player)

func _queue_monster_reward(spawn_token: String, kind: int, mask: int, position: Vector3, leader: bool, summoned := false) -> bool:
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
	var death := {"kind":kind, "position":position, "leader":leader, "summoned":summoned}
	var key := monster_rewards.admit_kill(participation.epoch(), spawn_token, death, candidates, roll_kill_trophy.bind(kind, mask, leader), rng.randf)
	if key.is_empty():
		return false
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
		if reward.boss_seed:
			at.x += 0.7
			wild_item_drops.append({"id":drop_id+":seed", "owner":id, "stack":{"item":"boss_mystery_seed","quantity":1}, "position":[at.x, at.y, at.z]})
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
			preload("res://garden_return_service.gd").outcome(self, leaving, "disconnected")
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
	var owner: String=local_character.identity if id==HOST else Session.inventory_owner(player)
	var record := {"profile":player.character.duplicate(true),"manifest":progress.ContentIDs.manifest()}
	var base: Dictionary = player.get("projection_base", {})
	if persistence_session.is_guarded() and id!=HOST and not base.is_empty():
		var projection = load("res://guest_profile_projection.gd")
		var prior: Dictionary = progress.character_records.get(owner, {}).get("projection", {})
		record.profile = Character.normalize(player.character)
		if prior.get("digest") == projection.digest(record.profile): return
		var descriptor: Dictionary = projection.build(record.profile, int(prior.get("revision",0))+1, base)
		if descriptor.is_empty():
			SaveBatch.record_serializer_error(ERR_OUT_OF_MEMORY, progress.path)
			return
		record.projection = descriptor
	progress.character_records[owner] = record

# The host stores the Garden's character record. A guest alone owns its
# canonical profile and receives the existing reliable ordered projection.
func actor_profile_scope(id: int) -> Transactions.Scope:
	return Transactions.Scope.PAIR if id == HOST else Transactions.Scope.GARDEN

func save_action_profile(id: int, effects) -> void:
	if effects == null:
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
		if save_guest_projection(profile,origin,descriptor): load("res://expedition_transitions.gd").confirm_guest_exit(self,departure)
		return
	if profile.has("projection") or not Character.Experience.supported(profile): return
	guest_character.data = Character.normalize(profile)
	character_dirty = true
	if save_local_character(): load("res://expedition_transitions.gd").confirm_guest_exit(self,departure)

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




func use_class_skill(id: int, player: Dictionary, slot: int=0) -> void:
	Journal.event("combat","skill_requested",{"actor":id,"slot":slot,"state":Journal.player_state(player)})
	if slot<0 or slot>1: return
	var now:=Time.get_ticks_msec()
	var cooldowns: Cooldowns.Timers = player[Cooldowns.STATE]
	if not Life.alive(player) or encounter_cleared() or not cooldowns.ready(slot, now) or now<int(player.get("core_cast_until",0)): return
	var stats:=weapon_stats(player)
	var skill: Dictionary
	var event: RefCounted
	var adapter := {}
	var combat_events_api = preload("res://combat_action_events.gd")
	var affinity_build: Dictionary = stats.get("affinity_build", {})
	if not affinity_build.is_empty():
		stats.erase("affinity_build")
		var refusal := preload("res://affinity_build.gd").refusal(affinity_build, "catalyst")
		if not refusal.is_empty():
			tell(id, refusal)
			return
		adapter = affinity_build.class_skills[slot]
		if adapter.is_empty():
			tell(id, "This class ability has no affinity contract.")
			return
		skill = adapter.native_skill.duplicate()
		AffinityCards.tune_class(player,skill,affinity_build,Life.Preview.scale())
		event = combat_events_api.class_start(self, id, adapter, now, affinity_build.catalyst)
		if adapter.trigger == "contact" or (event != null and event.affinity in ["vital","wood"] and adapter.recipients == "designated_area"):
			stats[combat_events_api.CONTEXT] = event
		if skill.mode == "subclass":
			stats.cr02_adapter = adapter
			stats[combat_events_api.CONTEXT] = event
	else:
		skill = Skills.resolve(int(player.frame),slot,player.character)
	skill=skill.duplicate(true)
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
	var recipients: Array[int] = []
	var ranger_snare := {}
	var reaper_siphon := {}
	var oracle = preload("res://oracle_combat.gd")
	var chime := {}
	var mode:=str(skill.mode)
	var aimed: bool=player.has("class_aim")
	var plan: Dictionary={}
	if aimed:
		plan=preload("res://class_ability_targeting.gd").plan(self,player,battlefield,skill,stats,player.class_aim,float(player.get("class_aim_distance",-1)))
		if not plan.valid:
			tell(id,"%s: no enemy within clear range."%skill.name)
			return
		target=plan.target
		point=plan.point
		range_limit=plan.reach
		player.facing=plan.forward
		player.aim_direction=plan.forward
	else:
		var targeting = preload("res://class_ability_targeting.gd")
		target=targeting.automatic(self,player,range_limit+float(skill.get("travel",0)))
		if target!=-2: point=enemy_position(target)
	if not aimed and mode in ["siphon"]:
		var extra_travel:=float(skill.get("travel",0)) if not skill.has("range") else 0.0
		if target==-2 or player.pos.distance_to(point)>range_limit+extra_travel:
			tell(id,"%s: no enemy within clear range."%skill.name)
			return
	if slot==1 and skill.has("oracle_nodes"):
		chime = oracle.begin_chime(self,player,skill,event,now)
	match mode:
		"front_guard","counter_guard":
			combat_events_api.grant_ward(self,player,now+int(skill.duration)+duration,int(skill.charges),event,adapter,now)
			if mode=="front_guard":
				player[Protection.STATE] = player[Protection.STATE].with_front_guard(now+int(skill.duration)+duration,player.facing)
				for ally in players.values():
					var offset: Vector3=ally.pos-player.pos
					if not is_same(ally,player) and Life.alive(ally) and offset.length()<=radius and (offset.length_squared()<.01 or offset.normalized().dot(player.facing.normalized())>=Skills.Balance.FRONT_GUARD_MIN_DOT) and battlefield.clear_line(player.pos,ally.pos):
						combat_events_api.grant_ward(self,ally,now+int(skill.duration)+duration,1,event,adapter,now)
			else: player[Protection.STATE] = player[Protection.STATE].with_counter_guard(now+int(skill.duration)+duration)
		"guard":
			combat_events_api.grant_ward(self,player,now+int(skill.duration)+duration,int(skill.charges),event,adapter,now)
		"ward":
			var ward_ms := int(chime.get("duration",skill.duration)) + duration + int(skill.get("ward_ms",0))
			for ally in players.values():
				if Life.alive(ally) and ally.pos.distance_to(player.pos)<=radius and battlefield.clear_line(player.pos,ally.pos):
					combat_events_api.grant_ward(self,ally,now+ward_ms,int(skill.charges),event,adapter,now)
		"snare":
			effect_point=plan.center if aimed else battlefield.dash(player.pos,point if target!=-2 else player.pos+Vector3(player.facing)*range_limit)
			if skill.has("ranger_nodes") and battlefield.occupied(effect_point):
				tell(id,"Bramble Snare needs supported ground.")
				return
			var placed := Traits.place_snare(self,player,effect_point,skill,stats,now)
			if skill.has("ranger_nodes"):
				if placed.is_empty():
					tell(id,"Bramble Snare could not be set. Wait for an active effect to expire.")
					return
				ranger_snare = placed
		"quake","nova":
			if mode=="quake" and skill.has("warden_focus"):
				effect_point=plan.center if aimed else preload("res://warden_combat.gd").quake_center(self,player,battlefield,skill,now)
				skill.effect_origin=effect_point
			targets=skill_area_targets(effect_point,radius,effect_point)
		"siphon":
			targets.assign([target])
			effect_point=point
			if skill.has("reaper_nodes"):
				reaper_siphon = preload("res://reaper_combat.gd").begin_siphon(self,id,player,skill,target,point,now)
	if player.has("affinity_spirit_follow") and player.pos!=cast_origin:
		preload("res://spirit_affinity.gd").movement(self,player,cast_origin,player.pos)
	var native_weaver_nova := mode=="nova" and skill.has("weaver_nodes")
	var catalyst_targets := targets.duplicate() if native_weaver_nova else targets
	var weaver_impact := Vector3.INF
	var weaver = preload("res://weaver_combat.gd")
	if native_weaver_nova:
		weaver_impact = weaver.prepare_nova(self,id,player,skill,targets,effect_point,now)
	if not targets.is_empty():
		player[WeaponActions.STATE] = player[WeaponActions.STATE].swing_until(now + WeaponMotion.DEFAULT_POSE_MS)
		if mode=="quake" and skill.has("warden_focus"):
			preload("res://warden_combat.gd").prepare_quake_damage(self,player,skill,now)
	var hits:=apply_skill_targets(player,targets,skill,stats,now)
	var siphon_damaged := not reaper_siphon.is_empty() and preload("res://reaper_combat.gd").enemy_hp(self,target)<int(reaper_siphon.before)
	var secondary_radius := float(skill.get("warden_catalyst_radius",radius))
	if skill.has("warden_focus") and slot==0:
		preload("res://warden_combat.gd").on_cast(self,player,skill,now+int(skill.duration)+duration,now,event)
	if mode=="quake":
		if skill.has("warden_focus"):
			var warden=preload("res://warden_combat.gd")
			warden.consume_anchor(self,player,effect_point,now)
			warden.quake_hit(self,player,effect_point,targets,radius,now)
	if mode=="siphon" and hits>0:
		Life.Sustain.heal(self,player,Skills.Balance.drain_amount(skill,hits),mode,Life.Preview.HEAL_DRAIN_SPREAD_HP)
	player.contributed=true
	if bonus_heal>0: Life.Sustain.heal(self,player,bonus_heal,"class_healing_bonus")
	player[Cooldowns.STATE] = player[Cooldowns.STATE].start(slot, now, Skills.Balance.cooldown(skill,stats))
	var ranger_feedback := ""
	if not ranger_snare.is_empty():
		ranger_feedback = preload("res://ranger_combat.gd").finish_snare(self,player,ranger_snare,cast_origin,now)
	combat_events_api.class_complete(self,event,adapter,cast_origin,effect_point,catalyst_targets,recipients,now,secondary_radius)
	if not reaper_siphon.is_empty():
		preload("res://reaper_combat.gd").finish_siphon(self,player,skill,target,effect_point,reaper_siphon,siphon_damaged,now)
	elif not chime.is_empty():
		oracle.finish_chime(self,id,player,skill,chime,now)
	elif slot==1 and skill.has("subclass_focus") and not skill.has("ranger_nodes") and (not native_weaver_nova or skill.subclass_follow_lane != 0):
		preload("res://subclass_combat.gd").follow_through(self,player,skill,effect_point,targets,now)
	if native_weaver_nova:
		weaver.complete_nova(self,id,player,skill.weaver_nodes,effect_point,weaver_impact,now)
	player.skill_fx_seq=int(player.get("skill_fx_seq",0))+1
	player.skill_fx_until=now+650
	player.skill_fx={"seq":player.skill_fx_seq,"pos":effect_point,"radius":maxf(.8,radius),"color":skill.color,"event_driven":true}
	player.cast_until=now+550
	emit_combat_event("ability",mode,cast_origin,effect_point,.8,Color(skill.color),maxf(.8,radius),id)
	preload("res://event_audio.gd").emit(self,"combat_cast",cast_origin)
	tell(id,"%s used."%skill.name if ranger_feedback.is_empty() else ranger_feedback)
	if encounter_cleared(): finish_combat(id,enemy_position(targets.back()) if not targets.is_empty() else effect_point)

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

func apply_skill_targets(player: Dictionary,targets: Array[int],skill: Dictionary,stats: Dictionary,now: int) -> int:
	var before_primary:=enemy_health()
	var drain_contacts:=0
	var native_hits: Dictionary = skill.get("native_hit_adjustments",{})
	var echo_bloom := AffinityCards.bloom_echo_source(self,player,skill,now)
	var echo_hit := false
	for target in targets:
		var adjustment: Dictionary = native_hits.get(target,{})
		var root_time:=Skills.Balance.bind_ms(skill,stats)
		if root_time>0:
			var until:=now+root_time
			if target==-1: tactics.extend_root(until)
			else: encounter.scout(target).rooted_until=maxi(int(encounter.scout(target).get("rooted_until",0)),until)
		var recovery:=int(skill.get("recovery",0))
		if recovery>0:
			if target==-1: tactics.recovery_bonus=maxi(tactics.recovery_bonus,recovery)
			else: encounter.scout(target).recovery=maxi(int(encounter.scout(target).get("recovery",0)),recovery)
		var damage:=Life.Preview.authored_amount(float(skill.get("damage",0))) + float(adjustment.get("bonus_hp",0))/Life.Preview.scale()
		if damage>0.0:
			var hit: Dictionary=stats.duplicate(true)
			hit.damage=damage
			hit.audio_form="magic"
			hit.stagger=int(stats.get("stagger",0))+int(skill.get("stagger",0))
			hit.recovery=int(stats.get("recovery",0))+recovery
			hit.knockback=float(skill.get("push",0))-.35
			if adjustment.get("isolated",false):
				hit = {"damage":0.0,"affinity_hp":Life.Preview.effect_hp(damage),"trait_secondary":true,
					"core_hit":true,"knockback":-.35}
			else:
				hit.ranger_direct_hit = not stats.get("ranger_trap_contact",false) and skill.mode != "salvo"
				if skill.has("reaper_nodes"):
					preload("res://reaper_combat.gd").tag_hit(hit,skill.reaper_nodes)
			var before:=encounter.hp(target)
			var inside_bloom := before > 0 and not echo_bloom.is_empty() and AffinityCards.bloom_contains(self,echo_bloom,target)
			apply_weapon_hit(player,target,adjustment.get("origin",skill.get("effect_origin",player.pos)),hit,now)
			var after:=encounter.hp(target)
			echo_hit = echo_hit or (inside_bloom and after < before)
			if Life.Sustain.eligible(self,target):
				drain_contacts+=int(after<before)
	if echo_hit:
		AffinityCards.bloom_echo(self,player,echo_bloom,skill,now)
	if participation.route()==Campaign.HEART and before_primary>Campaign.FINAL_HP/2.0 and enemy_health()>0 and enemy_health()<=Campaign.FINAL_HP/2.0:
		for peer_id in players: tell(peer_id,"The Heart remembers: I sheltered them, too. I will not let it happen again.")
	return drain_contacts


func graft_altar_open() -> bool:
	return participation.route() != Campaign.HEART and participation.floor() % GRAFT_ROOM == 0


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
	var build = preload("res://affinity_build.gd")
	var project_stats := build.graft_value_resolver(player, AffinityCards.totals(player), MAX_HEALTH)
	var purchase := ledger.plan_purchase(request_data, participation.floor(), player.carried_parts, project_stats)
	if purchase.has("ledger"):
		# The host installs the successor and debits inventory in the same
		# synchronous command before publishing any receipt or projection.
		var carry: Array = player.carried_parts.duplicate()
		carry[purchase.part] = int(carry[purchase.part]) - int(purchase.cost)
		player.carried_parts = carry
		player[grafts.STATE] = purchase.ledger
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
	return participation.route() != Campaign.HEART and participation.floor() % CHECKPOINT_INTERVAL == 0 and encounter_cleared()


func extraction_checkpoint_open() -> bool:
	return participation.route() != Campaign.HEART and participation.floor() % EXTRACTION_INTERVAL == 0 and encounter_cleared()








func guarded_growth_tick(elapsed: float) -> void:
	if not persistence_session.can_write(): return
	var original: Array = progress.plots.duplicate(true)
	if not progress.advance_growth(elapsed,participation.active()): return
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
	if multiplayer.is_server() and SessionWorld.allow_remote(self,multiplayer.get_remote_sender_id(),"action",30):
		act(multiplayer.get_remote_sender_id(), strike)


@rpc("any_peer", "call_remote", "reliable")
func request_dodge(direction: Vector2) -> void:
	if multiplayer.is_server() and direction.is_finite() and SessionWorld.allow_remote(self,multiplayer.get_remote_sender_id(),"action",30):
		dodge_player(multiplayer.get_remote_sender_id(), direction.limit_length())


@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_motion(direction: Vector2) -> void:
	var id := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and direction.is_finite() and SessionWorld.allow_remote(self,id,"motion",120):
		motions[id] = [direction.limit_length(), Time.get_ticks_msec()]


@rpc("any_peer", "call_remote", "unreliable_ordered",3)
func submit_movement(commands: Array,epoch: String) -> void:
	var id:=multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not players.has(id) or not Session.ready_for(players[id],false) or not SessionWorld.allow_remote(self,id,"motion",120):return
	net_motion.accept(id,commands,epoch,net_motion.world_key(self,players[id]),Time.get_ticks_msec())


func _physics_process(delta: float) -> void:
	if persistence_session.is_guarded():
		if returning_to_title or persistence_session.is_stopping(): return
		if persistence_session.is_blocked():
			if multiplayer.is_server() and persistence_session.can_publish_state():
				send_expedition_state(delta)
			return
		if not persistence_session.can_write(): return
	if multiplayer.is_server():net_motion.frame(delta,players)
	mouse_controls.frame(self)
	var direction := Vector2.ZERO if ui.is_overlay_open() or get_meta("garden_cinematic_active",false) else Input.get_vector("left", "right", "up", "down")
	if multiplayer.is_server():
		var now := Time.get_ticks_msec()
		growth_clock += delta
		if growth_clock >= 1.0:
			var elapsed := growth_clock
			growth_clock = 0.0
			if persistence_session.is_guarded():
				guarded_growth_tick(elapsed)
				if persistence_session.can_write() and not progress.heart.active.is_empty():
					var message := run_heart_save(progress.heart.tick.bind(progress,elapsed,participation.active()))
					if not message.is_empty(): status = message
				if stage.experimental_garden != null:
					stage.experimental_garden.advance_assimilation(elapsed, participation.active())
			else:
				if progress.advance_growth(elapsed,participation.active()) and progress.save_garden() != OK:
					status = "Plant growth could not be saved. Use Save Garden to retry."
				var research_message:=progress.heart.tick(progress,elapsed,participation.active())
				if not research_message.is_empty(): status=research_message
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
		update_projectiles(now)
		if persistence_session.is_blocked(): return
		Traits.tick(self,now)
		if persistence_session.is_blocked(): return
		if participation.active():
			preload("res://warden_combat.gd").tick(self,now)
			if persistence_session.is_blocked(): return
			preload("res://weaver_combat.gd").tick(self,now)
			if persistence_session.is_blocked(): return
			var elapsed := preload("res://affinity_time.gd").advance(self,delta)
			preload("res://void_affinity.gd").resolve_motion(self,elapsed,now)
			preload("res://fire_combat.gd").tick(self,elapsed,now)
			if persistence_session.is_blocked(): return
			preload("res://vital_combat.gd").tick(self,elapsed)
			preload("res://thorn_affinity.gd").tick(self,elapsed,now)
			preload("res://wood_affinity.gd").tick(self,elapsed)
			preload("res://spirit_affinity.gd").tick(self,elapsed)
			if persistence_session.is_blocked(): return
		preload("res://combat_status.gd").sync(self,now)
		attract_loot(delta)
		Bosses.tick_hazards(self,now)
		if persistence_session.is_blocked(): return
		if participation.active() and encounter_cleared() and pending_finale_at==0 and not encounter_rewarded and now>=reward_retry_at: finish_combat(HOST,tactics.position)
		if now>=next_kill_reward_flush:
			next_kill_reward_flush=now+150
			flush_kill_rewards()
		if persistence_session.is_blocked(): return
		update_combat_tracking(delta)
		LeaderBehavior.tick(self, delta, now)
		if persistence_session.is_blocked(): return
		ScoutBehavior.tick(self, delta, now)
		if persistence_session.is_blocked(): return
		preload("res://core_combat.gd").tick(self,now)
		if persistence_session.is_blocked(): return
		update_pressure(now)
		if pending_finale_at>0 and now>=pending_finale_at:
			pending_finale_at=0
			complete_finale(pending_finale_peer)
		if persistence_session.can_publish_state():
			send_expedition_state(delta)
	elif network_session.role() == "Guest":
		var commands: Array=net_motion.client_tick(self,multiplayer.get_unique_id(),direction,delta)
		if not commands.is_empty():submit_movement.rpc_id(HOST,commands,net_motion.epoch)


func send_expedition_state(delta: float,force := false) -> void:
	var now := Time.get_ticks_msec()
	net_view.observe(self)
	var peers := net_view.snapshot_targets(self)
	if not peers.is_empty():
		next_details-=delta
		next_snapshot -= delta
		var witness: Callable = get_meta(&"snapshot_witness", Callable())
		var state_key := str([participation.route(), participation.floor(), participation.seed()])
		if force or next_snapshot <= 0.0:
			next_snapshot = maxf(0,next_snapshot+0.05)
			var began := Time.get_ticks_usec() if witness.is_valid() else 0
			var flags := int(tactics.winding_up) | (8 if now < tactics.rooted_until else 0) | (16 if tactics.longlimb else 0)
			var pack := scout_snapshot(now)
			var shared := WorldSnapshot.encode(net_view.snapshot_sent + 1, player_snapshot(HOST,false),
				campaign_snapshot(), pack, tactics.position, enemy_health(), encounter_health(), drop_pos, participation.depth(), flags)
			if shared.is_empty() or shared.size() > WorldSnapshot.PAYLOAD_BUDGET:
				push_error("World snapshot exceeds the supported player, scout, or payload limits.")
			else:
				net_view.snapshot_sent += 1
				net_view.latest_frame = shared
				net_view.latest_frame_key = state_key
				for peer_id in peers:
					var guest: Dictionary = players[peer_id]
					var frame := WorldSnapshot.for_viewer(shared, guest.carried_seeds.size(), guest.loot_pending, guest.pouch)
					var transport: ENetPacketPeer = network_session.transport().get_peer(peer_id) if began > 0 else null
					var throttle := int(transport.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE)) if transport != null else -1
					var counter := int(transport.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_COUNTER)) if transport != null else -1
					var packed_at := Time.get_ticks_usec() if transport != null else 0
					var error := rpc_id(peer_id, "receive_state", frame)
					if transport != null:
						var enqueued_at := Time.get_ticks_usec()
						witness.call({"phase":"send","peer":peer_id,"sequence":net_view.snapshot_sent,"at":packed_at,
							"bytes":frame.size(),"marker":int(drop_pos.x),"scout_count":pack.size() / float(PACK_STRIDE),
							"encode_us":packed_at-began,"enqueue_us":enqueued_at-packed_at,"error":error,
							"throttle":throttle,"counter_before":counter,
							"counter_after":int(transport.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_COUNTER))})
		if force or next_details<=0:
			next_details=maxf(0,next_details+.25)
			var shared_garden := garden_snapshot()
			if stage.experimental_garden != null:
				shared_garden.append(stage.experimental_garden.snapshot())
			var garden_bytes:=var_to_bytes(shared_garden).compress(FileAccess.COMPRESSION_DEFLATE)
			var roster := {}
			for id in players:
				roster[id] = players[id].character.get("name", "Wanderer")
			for peer_id in peers:
				var details: Dictionary=player_snapshot(peer_id)[peer_id]
				for key in player_snapshot(peer_id,false)[peer_id]: details.erase(key)
				details[ActionIdentity.BINDING_KEY] = network_session.connection_key(peer_id)
				details[ActionIdentity.KEY] = ActionIdentity.current_stamp(self,players[peer_id])
				details.snapshot_roster = roster
				details.diagnostic_host = Journal.current.session_id if is_instance_valid(Journal.current) else ""
				details.diagnostic_world = diagnostic_watch.world_session if is_instance_valid(diagnostic_watch) else ""
				var guest: Dictionary = players[peer_id]
				var transport := network_session.transport().get_peer(peer_id)
				var repairing: bool = not net_view.latest_frame.is_empty() and net_view.latest_frame_key == state_key \
					and transport.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE) <= net_view.RECOVERY_THROTTLE
				if repairing:
					details.snapshot_recovery = WorldSnapshot.for_viewer(net_view.latest_frame,
						guest.carried_seeds.size(), guest.loot_pending, guest.pouch)
				var payload := var_to_bytes(details).compress(FileAccess.COMPRESSION_DEFLATE)
				var result := rpc_id(peer_id, "receive_details", payload, garden_bytes, inventory_snapshot(guest), state_key)
				if repairing and witness.is_valid():
					witness.call({"phase":"repair_send", "peer":peer_id, "sequence":net_view.snapshot_sent,
						"at":Time.get_ticks_usec(), "bytes":details.snapshot_recovery.size(), "error":result})


func move_player(id: int, direction: Vector2, delta: float) -> void:
	var p: Dictionary = players[id]
	if Participation.is_wild(p) and not Life.alive(p): p.velocity=Vector3.ZERO;return
	var move := world_direction(direction)
	if not move.is_zero_approx() and (not Participation.is_wild(p) or not p.get("mouse_aim",false)):
		p.facing = move.normalized()
	var guard_speed: float=p[Protection.STATE].movement_scale(Time.get_ticks_msec())
	var stride := preload("res://spirit_affinity.gd").scale(p,preload("res://affinity_time.gd").now(self)) if p.has("affinity_spirit_strides") else 1.0
	if p.has("ranger_speed_grants"):
		stride = maxf(stride,preload("res://ranger_combat.gd").speed_scale(self,p,Time.get_ticks_msec()))
	var desired := bound_position(p.pos + move * WALK_SPEED * guard_speed * stride * p[Conditions.STATE].movement_scale(Time.get_ticks_msec()) * delta, Participation.is_wild(p))
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
	if not wild:
		if stage.experimental_garden != null: return position_next
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
	if not Life.alive(p) or not p[Cooldowns.STATE].ready(Cooldowns.DODGE, now):
		return
	var facing := world_direction(direction).normalized()
	if not facing.is_zero_approx():
		p.facing = facing
	var previous: Vector3 = p.pos
	p.pos = battlefield.dash(p.pos, bound_position(p.pos + p.facing * DODGE_DISTANCE, true))
	if p.has("affinity_spirit_follow"):
		preload("res://spirit_affinity.gd").movement(self,p,previous,p.pos)
	var recovery := DODGE_COOLDOWN_MS - int(weapon_stats(p).get("dodge_cooldown",0))
	p[Cooldowns.STATE] = p[Cooldowns.STATE].start(Cooldowns.DODGE, now, maxi(350,recovery - AffinityCards.amount(p,"run_dodge_recovery")))


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
	if participation.route()!=Campaign.HEART:
		hp=Director.Balance.scout_hp(definition,participation.floor(),participation.cycle(),growth,encounter_party_size,juvenile)
	else:
		hp=Life.Preview.hp(1) if juvenile else Director.health(self,int(Director.config().scout_base_hp)+int(definition.hp)+growth,false)
	return {"spawn_token":encounter.reserve_token(),"pos": position, "kind": kind, "mutations": mutations | (Enemies.JUVENILE if juvenile else 0),
		"growth": growth, "hp": hp,
		"windup": 0, "ready": 0, "rooted_until": 0, "recovery": 0, "engaged": juvenile,
		"ranged": Enemies.ranged(kind), "blast": position, "route": route,
		"stagger_until": 0, "mode": "", "repeat": 0, "summons": 0, "haste_until": 0,
		"max_hp": hp,
		"variant": "" if juvenile else preload("res://enemy_variants.gd").choose(self,kind,route)}


func scout_radius(scout: Dictionary) -> float:
	return Enemies.radius(int(scout.get("kind", 0)), int(scout.get("mutations", 0)))


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
	return client_leader_hp <= 0 and living_scout_count() == 0


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
	if target == -1:
		return client_leader_hp
	var offset := target * PACK_STRIDE + 2
	return int(client_pack[offset]) if target >= 0 and offset < client_pack.size() else 0


func scout_snapshot(now: int) -> PackedFloat32Array:
	return encounter.scout_pack(now)


func act(id: int, strike: bool) -> void:
	var request:=Journal.interaction(self,id,"interact","begin") if not strike else 0
	_act(id,strike)
	if not strike:Journal.interaction(self,id,"interact","end",request)

func _act(id: int, strike: bool) -> void:
	if not persistence_session.can_write(): return
	if not players.has(id) or not Session.ready_for(players[id]):
		return
	var p: Dictionary = players[id]
	if Participation.is_wild(p) and not Life.alive(p): return
	var pos: Vector3 = p.pos
	var rescue:=Life.nearest(self,p)
	if not strike and rescue!=0:
		revive_player(id,rescue)
	elif strike:
		strike_enemy(id, p, pos)
	elif nearest_inventory_drop(p)!="":
		pickup_inventory_drop(id,p,nearest_inventory_drop(p))
	elif Participation.is_wild(p) and p.loot_pending and pos.distance_to(drop_pos) <= 1.45:
		collect_drop(p)
		tell(id,"Seeds collected.")
	elif Participation.is_wild(p) and battlefield.has_seed_cache() and participation.route() != Campaign.HEART and (
			not p.cache_claimed and pos.distance_to(battlefield.cache) <= 1.55):
		var reserve := seed_reserve(p)
		var kind := progress.roll_seed(reserve, p.carried_seeds, [], participation.route(), rng.randf(), participation.floor())
		p.carried_seeds.append(kind)
		p.cache_claimed = true
		tell(id, "Seed found. Extract to keep it.")
	elif not Participation.is_wild(p) and pos.distance_to(stage.gate_position()) <= preload("res://gate_interaction.gd").RANGE:
		if participation.route() == Campaign.HEART:
			tell(id, "Join the finale from the Heart in the Garden.")
		else:
			show_gate_preparation(id)
	elif Participation.is_wild(p) and at_graft_altar(p) and preload("res://gate_interaction.gd").shrine_preferred(battlefield,pos):
		show_graft_menu(id)
	elif Participation.is_wild(p):
		if participation.route() != Campaign.HEART and pos.distance_to(battlefield.advance) <= preload("res://gate_interaction.gd").RANGE:
			load("res://expedition_transitions.gd").checkpoint(self,id, true)
		else:
			tell(id, "Move closer to the seed or a checkpoint.")
	elif not Participation.is_wild(p) and preload("res://garden_interaction_service.gd").interact(self,id):
		pass
	elif at_heart(p):
		show_heart_tree(id)
	elif pos.distance_to(stage.altar_position()) <= 1.65:
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
		if pos.distance_to(stage.bed_position(i)) <= 1.55:
			return i
	return -1


func harvest(id: int, slot: int) -> bool:
	if not players.has(id) or slot<0 or slot>=progress.plots.size():return false
	if persistence_session.is_guarded():
		return harvest_guarded(id, slot, false)
	var bed: Dictionary=progress.plots[slot].duplicate(true)
	var before_rng: int=rng.state
	var rare: int=Parts.rare_part(int(bed.species)) if int(bed.species)>=0 else 0
	var rare_before: int=progress.part_count(rare) if rare>0 else 0
	var result=Transactions.run(self,func(): _harvest(id,slot))
	if result==false:rng.state=before_rng;return false
	if int(bed.species)>=0 and int(bed.stage)==3 and int(progress.plots[slot].species)<0:
		report_harvest(id, slot, bed, bool(bed.flowering), rare>0 and progress.part_count(rare)>rare_before)
		return true
	return false

func harvest_guarded(id: int, slot: int, flower: bool) -> bool:
	if not preload("res://garden_crop_service.gd").eligible(self, id, slot): return false
	var bed: Dictionary = progress.plots[slot].duplicate(true)
	if int(bed.species)<0 or int(bed.stage)<3 or (flower and not progress.flowering_unlocked): return false
	var result := run_guarded_action(id, actor_profile_scope(id), func(effects):
		if flower: progress.plots[slot].flowering = true
		var rare := Parts.rare_part(int(bed.species))
		var rare_before := progress.part_count(rare) if rare>0 else 0
		var changed := _harvest(id, slot, effects)
		if changed:
			effects.append(report_harvest.bind(id, slot, bed, flower or bool(bed.flowering), rare>0 and progress.part_count(rare)>rare_before))
		return changed)
	return Transactions.committed(result.persistence) and result.value == true

func report_harvest(id: int, slot: int, bed: Dictionary, flowering: bool, rare: bool) -> void:
	var preserved := preload("res://garden_crop_state.gd").preserved(bed)
	Journal.event("garden", "crop_harvested", {"actor":id,"bed":slot,"cycle":bed.get("care",{}).get("cycle",""),"species":Seeds.DEFINITIONS[int(bed.species)].id,"flowering":flowering,"preserved":preserved and not flowering,"forfeited_bud":preserved and flowering,"rare":rare})

func _harvest(id: int, slot: int, effects = null) -> bool:
	var bed: Dictionary = progress.plots[slot]
	var kind := int(bed.species)
	if kind < 0 or bed.stage < 3:
		action_feedback(effects, id, "Still growing: %s." % ["Seed", "Sprout", "Young plant", "Mature"][int(bed.stage)])
		return false
	var seeds := bool(bed.flowering)
	progress.plots[slot] = Progress.empty_plot()
	progress.sync_plot_flags()
	var profile: Dictionary = players[id].character
	var familiarity: int = profile.plants[kind]
	profile.plants[kind] = mini(9999, familiarity + 1 + int(progress.heart.has("nursery")))
	save_action_profile(id, effects)
	var message: String
	if seeds:
		seed_reserve(players[id]).stock[kind] += 2
		message = "Harvested two %s seeds. The bed is ready to replant." % Progress.PLANT_NAMES[kind]
	else:
		progress.parts[kind] += 1
		message = "Harvested a %s part. Replant this bed with any identified seed." % Progress.PLANT_NAMES[kind]
		var harvest_roll:=rng.randf()
		if preload("res://garden_crop_state.gd").preserved(bed):harvest_roll=preload("res://garden_crop_state.gd").roll(bed)
		if harvest_roll < preload("res://garden_crop_state.gd").chance(bed,rare_harvest_chance(familiarity)):
			var rare:=Parts.rare_part(kind)
			if rare>0: progress.add_parts(rare,1);message+=" Rare harvest: "+Parts.part_name(rare)+"."
	var play_audio := func(): preload("res://event_audio.gd").emit(self, "crop_harvested", stage.bed_position(slot))
	if effects == null:
		save_progress(id, message)
		play_audio.call()
	else:
		effects.append(tell_profile_action.bind(id,message))
		effects.append(play_audio)
	return true

func rare_harvest_chance(familiarity: int) -> float:
	return minf(.45,0.05+0.04*mini(familiarity,5)+.005*maxi(0,familiarity-5))


func strike_enemy(id: int, p: Dictionary, pos: Vector3) -> void:
	if not Life.alive(p): return
	var now:=Time.get_ticks_msec()
	var attack: WeaponActions.State = p[WeaponActions.STATE]
	if not attack.ready(now): return
	var stats:=weapon_stats(p)
	var affinity_build: Dictionary = stats.get("affinity_build", {})
	if not affinity_build.is_empty():
		var refusal := preload("res://affinity_build.gd").refusal(affinity_build, "form")
		if not refusal.is_empty():
			tell(id, refusal)
			return
		var events = preload("res://combat_action_events.gd")
		Weapons.tune_affinity_basic(stats, AffinityCards.totals(p))
		var form_affinity: Dictionary = affinity_build.form
		var ready: bool = form_affinity.state == "ready"
		var event: RefCounted = events.begin(self,id,"form" if ready else "native_weapon",form_affinity if ready else {},
			form_affinity.potency_profile.values if ready else {},["weapon_contact","secondary"],now+15000)
		var grafts = preload("res://native_grafts.gd")
		var captured := grafts.capture(p,affinity_build.improvements.adaptations)
		if not captured.is_empty():
			stats[grafts.CONTEXT] = captured
		if int(p.frame)==Frames.REAPER and int(affinity_build.class_skills.size())>0:
			preload("res://reaper_combat.gd").commit_melee(self,p,affinity_build.class_skills[0].get("native_skill",{}),stats,now)
		stats[events.CONTEXT] = event
		stats.erase("affinity_build")
		if int(p.frame)==Frames.RANGER and p.character.has(Classes.Ranger.PROFILE_KEY):
			stats.ranger_ordinary = true
	Life.Preview.lock_strike(stats,0)
	var form:=WeaponMotion.form(p)
	var started := attack.try_start(now, int(stats.interval), roundi(float(WeaponMotion.profile(form).duration)*1000), float(stats.reach))
	if started == null: return
	p[WeaponActions.STATE] = started
	p.cast_until=0
	var duration := started.duration_ms()
	if p.get("mouse_aim",false):
		MouseCombat.queue_attack(self,id,p,pos,stats,now,form,duration)
		return
	var ranged := WeaponMotion.is_projectile(form)
	var targeting = preload("res://class_ability_targeting.gd")
	var first: int = targeting.automatic(self,p,float(stats.reach),WeaponMotion.profile(form) if ranged else {})
	var aim: Vector3 = pos if first == -2 else preload("res://enemy_hurtbox.gd").contact(self,first,pos,ranged)
	if first==-2 or pos.distance_to(aim)>float(stats.reach):
		MouseCombat.queue_attack(self,id,p,pos,stats,now,form,duration)
		tell(id,"No enemy within clear weapon reach.")
		return
	if aim.distance_to(pos)>.001: p.facing=(aim-pos).normalized()
	MouseCombat.queue_attack(self,id,p,pos,stats,now,form,duration,first)



func apply_weapon_hit(p: Dictionary,target: int,origin: Vector3,stats: Dictionary,now: int) -> void:
	if not encounter.alive(target): return
	var target_token := encounter.token(target)
	p.contributed=true
	var grafts = preload("res://native_grafts.gd")
	var graft_contact := grafts.start_contact(self,p,stats,target,now)
	if not stats.get("core_hit",false) and not stats.get("oracle_spell",false): stats=Traits.augment_hit(self,p,target,stats,now,graft_contact)
	var point:=enemy_position(target)
	var contact_point := point
	var distance:=origin.distance_to(point)
	var winding: bool=stats.get("was_winding",tactics.winding_up if target==-1 else float(encounter.scout(target).windup)>0)
	var pull:=float(stats.get("pull",0))
	if pull>0 and not winding:
		point=battlefield.dash(point,point.move_toward(origin,clampf(distance-0.9,0,pull)))
	var authored_damage:=Life.Preview.authored_amount(float(stats.damage))
	if not graft_contact.is_empty():
		authored_damage += grafts.bonus(self,p,graft_contact,now)
	if not stats.get("trait_secondary",false):
		authored_damage+=int(stats.get("preview_power",0))
	if winding:
		authored_damage+=Life.Preview.authored_amount(float(stats.get("windup_damage",0)))
	if winding and float(stats.get("windup_damage",0))>0:preload("res://combat_status.gd").proc(self,"punish",origin,point,target)
	var damage := int(stats.affinity_hp) if stats.has("affinity_hp") else Life.Preview.resolved_hit(authored_damage,stats)
	damage += int(stats.get("native_bonus_hp",0))
	if damage > 0 and stats.get("ranger_direct_hit",false) and not stats.get("trait_secondary",false) and not stats.get("core_hit",false):
		damage += preload("res://ranger_combat.gd").consume_prey(self,p,target,now)
	var push:=0.35+float(stats.get("knockback",0))
	var mutations: int=enemy_mutations if target==-1 else int(encounter.scout(target).get("mutations",0))
	if not preload("res://enemy_support.gd").shelter_source(self,target,point,origin,now).is_empty():
		damage=Life.Preview.armor(damage)
	if target==-1 and tactics.boss_kind>=0: push*=.2
	elif target==-1 and (participation.depth()==ROUTE_ROOMS or participation.route()==Campaign.HEART): push*=0.5
	var guard_actor: Dictionary=encounter.scout(target) if target>=0 else encounter.leader_tactics()
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
	var before: int=encounter.hp(target)
	var applied:=Life.Vitals.damage_taken(before,damage)
	if Life.Vitals.counts_as_burst(damage,Life.Preview.scale()): burst_hits_this_room+=1
	if before<=applied and battlefield.procedural and battlefield.floor_distance(point)<1.6: choke_kills_this_room+=1
	if target==-1:
		if tactics.winding_up and Bosses.owns_warnings(tactics.boss_kind):point=tactics.position
		tactics.position=point
		tactics.engaged=true
		encounter.apply_damage(-1, applied)
		tactics.recovery_bonus=maxi(tactics.recovery_bonus,recovery)
		if winding and enemy_health()>0 and tactics.boss_kind==22 and float(stats.get("stagger",0))>=150:
			preload("res://boss_phase_fights.gd").interrupt(self,point,now)
		if winding and tactics.boss_kind<0 and not encounter.leader_tactics().is_empty() and float(stats.get("stagger",0))>=150 and EnemyBehaviors.interrupt(self,encounter.leader_tactics(),point,now):
			tactics.ready_at=encounter.leader_tactics().ready
			tactics.winding_up=false
			winding=false
		if not winding and not stats.has("affinity_hp"): tactics.stagger_until=stagger
		if enemy_health()==0: tactics.winding_up=false
	else:
		var scout: Dictionary=encounter.scout(target)
		scout.pos=point
		scout.engaged=true
		encounter.apply_damage(target, applied, target_token)
		scout.recovery=maxi(int(scout.recovery),recovery)
		if winding and float(stats.get("stagger",0))>=150 and EnemyBehaviors.interrupt(self,scout,point,now):winding=false
		if not winding and not stats.has("affinity_hp"): scout.stagger_until=stagger
	if stats.get("rite_suppressed",false) and applied<before:
		var actor: Dictionary=encounter.scout(target) if target>=0 else encounter.leader_tactics()
		preload("res://wilds_skill_tactics.gd").interrupted(self,actor,"suppression")
	if applied>0:
		if (int(p.frame)==4 or p.has("oracle_omens")):
			preload("res://oracle_combat.gd").ordinary_contact(self,p,target,contact_point,stats,now)
		var form := "magic" if stats.get("trait_secondary",false) else str(stats.get("audio_form",WeaponMotion.form(p)))
		emit_combat_event("impact","hit",origin,point,.85,stats.get("affinity_color",weapon_effect_color(p)),float(applied),target,{"form":form})
	if encounter.death_pending(target, target_token):
		record_enemy_death(target,point,origin,target_token)
		Life.Sustain.heal_on_kill(self,p,target,Life.Preview.authored_amount(float(stats.get("heal_on_kill",0))))
	Traits.after_hit(self,p,target,stats,now,before>0 and applied>=before)
	if not graft_contact.is_empty() and applied > 0:
		grafts.finish_contact(self,p,target,stats,graft_contact,now,before>0 and applied>=before)
	damage_this_room+=applied
	if float(stats.get("shot_distance",distance))>=RANGED_DISTANCE:
		ranged_damage_this_room+=applied
		if player_id!=0 and combat_velocity.get(player_id,Vector3.ZERO).length()>.8: moving_ranged_hits+=1

func finish_combat(id: int,loot_position: Vector3) -> void:
	if persistence_session.is_guarded():
		if not persistence_session.can_write() or not participation.active() or encounter_rewarded or not encounter_cleared() or participation.route()==Campaign.HEART: return
		run_guarded_action(id, Transactions.Scope.PAIR, func(effects):
			settle_expedition_rewards(effects, true)
			_finish_combat(id,loot_position,effects))
		if not encounter_rewarded: reward_retry_at=Time.get_ticks_msec()+1000
		return
	if not flush_kill_rewards(): return
	Transactions.run(self,func(): _finish_combat(id,loot_position))
	if not encounter_rewarded: reward_retry_at=Time.get_ticks_msec()+1000

func _finish_combat(id: int,loot_position: Vector3,effects = null) -> void:
	if pending_finale_at>0 or encounter_rewarded: return
	encounter_rewarded=true
	record_settlement_metric(effects,"encounter_clear",{"floor":participation.floor(),"biome":participation.route(),"kills":encounter_kills.size(),"cycle":participation.cycle()})
	burst_clears+=int(burst_hits_this_room>=2)
	choke_clears+=int(choke_kills_this_room>=3)
	if effects == null: award_combat_progress()
	if participation.route()==Campaign.HEART:
		pending_finale_peer=id
		pending_finale_at=Time.get_ticks_msec()+1500
		tactics.winding_up=false
		tell(id,"The Heart collapses as its last roots fall silent…")
		return
	var ranged_evidence:=Life.Vitals.counts_as_ranged(ranged_damage_this_room,damage_this_room,Life.Preview.scale())
	if ranged_evidence: ranged_clears+=1
	var previous_memory: Dictionary=progress.wilds_memory.score.duplicate()
	var skill_evidence:=preload("res://wilds_skill_tactics.gd").evidence(self)
	var learned: Dictionary={"ranged":ranged_evidence,"burst":burst_hits_this_room>=2,"choke":choke_kills_this_room>=3 and choke_kills_this_room*2>=encounter_kills.size(),"kite":moving_ranged_hits>=3 and Time.get_ticks_msec()-encounter_started_at>=8000}
	for tactic in skill_evidence: learned[tactic]=int(skill_evidence[tactic])>0
	Learning.observe(progress.wilds_memory,learned,participation.floor())
	record_settlement_metric(effects,"wilds_learning",{"floor":participation.floor(),"encounters":progress.wilds_memory.encounters,"scores":progress.wilds_memory.score.duplicate(),"skill_evidence":skill_evidence,"party":encounter_party_size,"elapsed_ms":Time.get_ticks_msec()-encounter_started_at})
	deepest_milestone=maxi(deepest_milestone,participation.floor())
	if participation.depth()==ROUTE_ROOMS and participation.route()<Campaign.HEART: run_guardians|=1 << participation.route();guardian_counts[participation.route()]+=1
	tactics.winding_up=false
	drop_pos=loot_position
	var seeds_available := battlefield.clear_seed_count(participation.depth()) > 0
	for player in players.values(): player.loot_pending=seeds_available and Life.alive(player)
	refresh_drop()
	if encounter_cleared():
		var cue := "extract_ready" if extraction_checkpoint_open() else "gate_ready"
		preload("res://event_audio.gd").emit(self,cue,battlefield.advance)
	var clear_message := "Encounter cleared. Press E near the glowing loot." if has_drop else "Encounter cleared."
	action_feedback(effects,id,clear_message+Learning.notice(previous_memory,progress.wilds_memory.score))


func wild_entry(id: int) -> Vector3:
	var slot: int=Session.slot_for(players.get(id,{}),0)
	var offset: Vector3=[Vector3(-.65,0,-.45),Vector3(.65,0,-.45),Vector3(-.65,0,.65),Vector3(.65,0,.65)][clampi(slot,0,Network.MAX_PLAYERS-1)]
	return battlefield.slide(battlefield.entry,battlefield.entry+offset)


func complete_finale(id: int) -> void:
	if persistence_session.is_guarded(): return
	if not Campaign.LEGACY_ENDING_ENABLED: return
	if not players.has(id): id=HOST
	progress.campaign.finish()
	var message := ending_message(progress.campaign.ending)
	for peer_id in players:
		if Participation.is_wild(players[peer_id]):
			load("res://expedition_transitions.gd").return_member(self,players[peer_id])
		if peer_id != id:
			tell(peer_id, message)
	participation.select_route(Campaign.GROVE)
	load("res://expedition_transitions.gd").reset(self)
	save_progress(id, message)


func ending_message(ending: int) -> String:
	if ending == Campaign.SEED:
		return "ENDING: A Seed Remains. The Heart can be cultivated anew."
	if ending == Campaign.CORRUPTION:
		return "ENDING: The Returning Wilds. Without the Heart, corruption returns."
	return ""


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


func refresh_drop() -> void:
	has_drop = false
	for player in players.values():
		if player.get("loot_pending",false):
			has_drop = true
			return


func collect_drop(player: Dictionary) -> void:
	if not player.get("loot_pending", false):
		return
	var count := battlefield.clear_seed_count(participation.depth())
	var reserve := seed_reserve(player)
	var bundle: Array = []
	for i in count:
		var seed_kind := progress.roll_seed(reserve, player.carried_seeds, bundle, participation.route(), rng.randf(), participation.floor())
		bundle.append(seed_kind)
		player.carried_seeds.append(seed_kind)
	player.loot_pending = false
	refresh_drop()


func activate_checkpoint() -> bool:
	if not upgrade_checkpoint_open() or checkpoint_all_ready(): return false
	if not checkpoint_pending:
		checkpoint_pending=true
		checkpoint_ready.clear()
	for id in players:
		if Life.alive(players[id]): present_checkpoint_cards(id)
	return true

func milestone_message(message: String, extracted: bool) -> String:
	if deepest_milestone > 0 and participation.route() != Campaign.HEART:
		progress.remember_expedition(ranged_clears, burst_clears, choke_clears)
		progress.campaign.advance_growth()
		progress.campaign.record_expedition(deepest_milestone, extracted)
	return message + progress.apply_milestone(deepest_milestone)


func encounter_health() -> int:
	if not multiplayer.is_server(): return int(players.get(multiplayer.get_unique_id(),{}).get("enemy_max_hp",Life.Preview.hp(ENEMY_HEALTH)))
	if participation.route()!=Campaign.HEART:
		if tactics.boss_kind>=0: return Director.Balance.boss_hp(Enemies.get_kind(tactics.boss_kind),participation.floor(),participation.cycle(),encounter_party_size)
		return Director.Balance.elite_hp(Enemies.get_kind(enemy_kind),participation.floor(),participation.depth(),participation.cycle(),encounter_party_size)
	if tactics.boss_kind>=0: return Director.health(self,30+int(Enemies.get_kind(tactics.boss_kind).hp)+participation.floor()/3,true)
	return Director.health(self,Campaign.FINAL_HP,true)


func start_encounter() -> void:
	wild_item_drops.clear()
	reset_encounter(map_rng.randi_range(1, 2147483647))


func reset_encounter(seed_value: int = -1) -> void:
	if not SaveBatch.guarded_active(): flush_kill_rewards()
	monster_rewards.retire_completed()
	encounter_kill_records.clear();combat_threat.clear();combat_velocity.clear();combat_last_positions.clear();tactics.memory.clear();moving_ranged_hits=0;encounter_started_at=Time.get_ticks_msec();encounter_party_size=Director.party_size(self)
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
	enemy_traits.clear();trait_events.clear()
	projectile_queue.clear()
	combat_events.clear()
	Bosses.prepare(self)
	# A new floor has independent pathing. Keep the old object intact for abort.
	if stage.experimental_garden != null: battlefield = preload("res://assets/terrain_m02/experimental/experiment_wilds.gd").new()
	elif SaveBatch.guarded_active(): battlefield = Battlefield.new()
	battlefield.configure(participation.route(), participation.depth(), participation.seed(),tactics.boss_kind,tactics.boss_phase)
	pressure_at = 0
	tactics.haste_until=0
	pending_finale_at=0
	enemy_death_events.clear()
	encounter.clear_scouts()
	tactics.position = Director.spawn(self,battlefield.leader,-1)
	if tactics.position==Vector3.INF:
		tactics.position = clear_spawn(battlefield.leader)
		if tactics.position == Vector3.INF:
			# A generated leader room is already certified for enemy clearance.
			tactics.position = battlefield.leader
	enemy_kind = tactics.boss_kind if tactics.boss_kind>=0 else 9 if participation.route() == Campaign.HEART else preload("res://elite_enemy.gd").select(self)
	encounter.begin_floor(encounter_health())
	tactics.reset_approach()
	enemy_growth = Enemies.tier(participation.floor(), participation.cycle())
	enemy_mutations = current_mutations(enemy_kind, enemy_growth, participation.seed())
	var count := Director.scout_count(self)
	if tactics.boss_kind>=0: count=Director.Balance.boss_escorts(self,count)
	var composition=preload("res://wilds_composition.gd")
	var roster: Array[int]=composition.roster(self,count)
	for i in count:
		var origin: Vector3 = battlefield.spawn_points[i%battlefield.spawn_points.size()] if battlefield.procedural else Stage.SUPPORT_SPAWNS[i%Stage.SUPPORT_SPAWNS.size()]+Vector3.RIGHT*(i/Stage.SUPPORT_SPAWNS.size())*1.8
		var spawn: Vector3=composition.companion_spawn(self,i) if i==1 and tactics.boss_kind<0 and participation.route()!=Campaign.HEART and battlefield.procedural else Vector3.INF
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
		player.loot_pending = false
		player.cache_claimed = false
	tactics.reset_attack((enemy_mutations & Enemies.REACH)!=0)
	has_drop = false


func clear_spawn(position: Vector3) -> Vector3:
	for shift in [Vector3.ZERO, Vector3.RIGHT * 1.5, Vector3.LEFT * 1.5,
			Vector3.FORWARD * 1.5, Vector3.BACK * 1.5, Vector3.BACK * 2.7]:
		var candidate: Vector3 = position + shift
		if not battlefield.occupied(candidate, Battlefield.CLEARANCE) and _experimental_spawn_reachable(candidate):
			return candidate
	for radius in range(2, 5):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var candidate := position + Vector3(x, 0, z)
				if absf(candidate.x) <= Stage.WILD_BOUNDS.x and absf(candidate.z) <= Stage.WILD_BOUNDS.y and (
						not battlefield.occupied(candidate, Battlefield.CLEARANCE)) and _experimental_spawn_reachable(candidate):
					return candidate
	return position if _experimental_spawn_reachable(position) else Vector3.INF

func _experimental_spawn_reachable(candidate: Vector3) -> bool:
	return stage.experimental_garden == null or not battlefield.has_method("can_spawn") or battlefield.can_spawn(candidate)


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
		if persistence_session.is_guarded() or progress.save_garden()==OK: return true
		stock[kind]+=1;progress.plots[slot]=before;progress.sync_plot_flags()
		return false, false)
	if not planted.completed or planted.value != true:
		tell(id,Transactions.feedback(planted,"Planting could not be saved. Your seed was returned."))
		return false
	tell(id,"%s planted."%Progress.PLANT_NAMES[kind])
	return true

func deferred_save_available(id: int) -> bool:
	if not persistence_session.is_guarded(): return true
	if persistence_session.can_write(): tell(id, "This action is unavailable in the guarded session.")
	return false

func save_session_garden() -> bool:
	if persistence_session.is_guarded():
		return Transactions.run_gameplay(self, Transactions.Scope.GARDEN, func(): return true).completed
	return progress.save_garden() == OK

func save_progress(id: int, message: String) -> void:
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

func tell(id: int, message: String) -> void:
	if id == HOST:
		status = message
	elif network_session.transport() != null:
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
	var swing: int = player[WeaponActions.STATE].swing_ticks(Time.get_ticks_msec())
	return degrees | (swing << 9)


func player_snapshot(viewer: int,include_details: bool=true) -> Dictionary:
	var snapshot := {}
	for id in players:
		var p: Dictionary = players[id]
		var stride := preload("res://spirit_affinity.gd").scale(p,preload("res://affinity_time.gd").now(self)) if p.has("affinity_spirit_strides") else 1.0
		if p.has("ranger_speed_grants"):
			stride = maxf(stride,preload("res://ranger_combat.gd").speed_scale(self,p,Time.get_ticks_msec()))
		var health: PlayerVitals.Health = p[PlayerVitals.STATE]
		var state := {"motion_radius":bound_position(Vector3(1000,0,0)).x,"motion_epoch":net_motion.world_key(self,p),"motion_ack":net_motion.acknowledgement(id,net_motion.world_key(self,p)),"motion_scale":p[Protection.STATE].movement_scale(Time.get_ticks_msec())*p[Conditions.STATE].movement_scale(Time.get_ticks_msec())*stride,"velocity":p.get("velocity",Vector3.ZERO),"vitals_revision":p.get("vitals_revision",0),"damage_seq":p.get("damage_seq",0),"damage_amount":p.get("damage_amount",0),"party_slot":Session.slot_for(p,0),"display_name":p.character.get("name","Wanderer"),"enemy_max_hp":encounter_health(),"pos": p.pos, "wild": Participation.is_wild(p), "fallen":PlayerLifecycle.fallen(p),"lost_health":p.get("lost_health",0), "hp": health.hp(), "max_hp": health.max_hp(), "appearance": PackedByteArray(p.character.get("appearance", [0,0,0,0,0])), "frame": p.frame,
			"attack_anim":attack_animation_snapshot(p),"skill_fx":p.get("skill_fx",{}) if Time.get_ticks_msec()<int(p.get("skill_fx_until",0)) else {}, "weapon_kind":p.get("weapon_kind",0), "core_part":p.weapon if Participation.is_wild(p) else p.prepared, "pose": combat_pose(p),"wallet": run_wallet(p)}
		var cooldowns: Cooldowns.Timers = p[Cooldowns.STATE]
		var cooldown_now := Time.get_ticks_msec()
		state.merge(cooldowns.skill_projection(cooldown_now))
		if stage.experimental_garden != null and not Participation.is_wild(p):
			var garden = stage.experimental_garden
			state["garden_layout_revision"] = garden.layout_revision if garden.reveal == null else -1
		if id == viewer and include_details:
			if Participation.is_wild(p):
				state["affinity_feedback"]=preload("res://combat_status.gd").affinity_feedback(self,p)
			state["core_state"]=preload("res://core_combat.gd").owner_state(p,Time.get_ticks_msec(),get_meta("core_combat",{}).get(id,{}))
			if Participation.is_wild(p):
				state["thief_routes"]=preload("res://thief_escape.gd").snapshot(self)
				state["ability_growth_centers"]=preload("res://class_ability_targeting.gd").growth_centers(self,id)
				if int(p.frame)==0:
					var warden=preload("res://warden_combat.gd")
					var now:=Time.get_ticks_msec()
					state["warden_anchor_point"]=warden.anchor_point(self,p,now)
					state["warden_relay_point"]=warden.relay_point(self,p,now)
					state["warden_quake_prepared"]=warden.prepared_until(self,p,now)>0
			state.merge({"weapon": p.weapon, "prepared": p.prepared, "experiment": p.experiment,
				"dodge_ready": cooldowns.ready(Cooldowns.DODGE, cooldown_now), "last_offer": AffinityCards.completed_floor(p),
				"reclaim_choice":p.get("reclaim_choice",0),"offering_choice":p.get("offering_choice",0),"last_deposit":p.get("last_deposit",0),"weapon_kind":p.weapon_kind,"catalyst":p.catalyst,"graft_part":0,"graft_floor":0,"prepared_catalyst":p.prepared_catalyst,"cargo_plan":p.cargo_plan,"stored_parts":stored_counts(p),"weapon_stats":weapon_stats(p,not Participation.is_wild(p)), "carried_parts": p.carried_parts, "reserve_parts": seed_reserve(p).parts,"combat_events":combat_events_snapshot(),"attack_hints":attack_hints_snapshot(),"death_events":death_events_snapshot(),"run_upgrades":{},"bag":InventoryModel.snapshot(self,p),"ground_items":inventory_floor_snapshot(p), "secondary": p.secondary, "prepared_secondary": p.prepared_secondary,
				"garden_interactions":preload("res://garden_interaction_service.gd").projection(self,id),
				"party_travel":PartyTravel.snapshot(self,id),"seed_choice": selected_seed(p), "graft_choice": 0, "cache_claimed": p.cache_claimed})
			state["graft_improvements"] = preload("res://expedition_grafts.gd").owner_details(p, participation.floor())
			if Participation.is_wild(p) and p.has(AffinityCards.STATE):
				state["affinity_run_cards"] = AffinityCards.project_owned(p,state.weapon_stats,DODGE_COOLDOWN_MS)
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
func receive_state(frame: PackedByteArray) -> void:
	apply_world_snapshot(frame, false)


func apply_world_snapshot(frame: PackedByteArray, recovery: bool) -> void:
	var witness: Callable = get_meta(&"snapshot_witness",Callable())
	var received_at := Time.get_ticks_usec() if witness.is_valid() else 0
	var state := WorldSnapshot.decode(frame)
	if state.is_empty():
		if received_at > 0: witness.call({"phase":"invalid","at":received_at,"bytes":frame.size()})
		return
	var sequence: int = state.sequence
	var drop: Vector3 = state.drop
	if received_at > 0:
		witness.call({"phase":"repair_receive" if recovery else "receive","sequence":sequence,
			"marker":int(drop.x),"at":received_at,"bytes":frame.size()})
	if recovery and sequence <= net_view.snapshot_received:
		return # This frame was delivered on the fast channel, or superseded there.
	if not net_view.accept_sequence(sequence):
		if received_at > 0:
			witness.call({"phase":"stale","sequence":sequence,"marker":int(drop.x),"at":Time.get_ticks_usec()})
		if is_instance_valid(Journal.current) and Journal.current.detail:Journal.event("network","stale_snapshot",{"sequence":sequence,"last_sequence":net_view.snapshot_received})
		return
	var before_movement: Dictionary = players
	var membership := {}
	for peer in state.people: membership[peer] = bool(state.people[peer].wild)
	var links := participation.project_participants(membership)
	players = state.people
	for peer in players:
		players[peer][Participation.STATE] = links[peer]
		players[peer].erase("wild")
	for peer in players: net_view.merge_health(int(peer),players[peer])
	net_view.apply_roster(players)
	var local_id := multiplayer.get_unique_id()
	if players.has(local_id):
		var public_state: Dictionary = players[local_id]
		players[local_id] = client_details.duplicate(true)
		players[local_id].merge(public_state,true)
		players[local_id].erase("wild")
	client_leader_hp = state.hp
	var flags: int = state.flags
	drop_pos = drop
	has_drop = (flags & 2) != 0
	client_carried_count = state.carried
	client_pouch_filled = (flags & 4) != 0
	client_briar_bound = (flags & 8) != 0
	client_campaign = state.campaign
	client_pack = state.scouts
	var campaign_state: PackedInt32Array = state.campaign
	participation.project_world({"depth":state.depth,"destination":campaign_state[0],
		"map_seed":campaign_state[8],"encounter_number":campaign_state[9],"difficulty_cycle":campaign_state[10]})
	var form := Enemies.decode(campaign_state[18])
	enemy_kind = form.kind
	enemy_mutations = form.mask
	enemy_growth = form.tier
	var landing := Vector3(campaign_state[EncounterConfig.LANDING_X] / 100.0, 0, campaign_state[EncounterConfig.LANDING_Z] / 100.0)
	tactics.project(state.enemy, (flags & 1) != 0, (flags & 16) != 0, landing,
		"vault" if campaign_state[EncounterConfig.ATTACK_MODE] != 0 else "",
		campaign_state[EncounterConfig.BOSS_KIND], campaign_state[EncounterConfig.BOSS_PHASE], campaign_state[6] / 100.0)
	net_motion.receive(self,local_id,before_movement,Time.get_ticks_msec())
	if received_at > 0:
		witness.call({"phase":"repair_apply" if recovery else "apply","sequence":sequence,
			"marker":int(drop.x),"at":Time.get_ticks_usec(),
			"apply_us":Time.get_ticks_usec()-received_at,"people":players.size(),"floor":participation.floor(),"enemy_hp":enemy_health()})


func _process(_delta: float) -> void:
	if not persistence_session.pending_notice().is_empty() or (network_session.role() == "Guest" and has_meta(&"guarded_host_cleanup_notice")):
		refresh_feedback()
	if not persistence_session.can_publish_state():
		# Keep the last presented floor while the retained state awaits recovery.
		return
	if persistence_session.is_guarded() and not returning_to_title:
		var owner = persistence_session
		var renewal: Dictionary = owner.tick()
		if renewal.error != OK:
			_stop_guarded_session("This session lost access to its save. Returning to the title.")
			return
	if multiplayer.is_server() and not persistence_session.is_blocked(): PartyTravel.validate(self)
	SessionWorld.update(self)
	if returning_to_title: return
	if not multiplayer.is_server() and client_details.is_empty(): return
	if not persistence_session.is_guarded() and (slot_claimed or character_slot_claimed) and Time.get_unix_time_from_system() - slot_heartbeat_at >= 1.0:
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
	var briar_bound := Time.get_ticks_msec() < tactics.rooted_until if multiplayer.is_server() else client_briar_bound
	var campaign_state := campaign_snapshot() if multiplayer.is_server() else client_campaign
	var visual_field: RefCounted = battlefield if multiplayer.is_server() else stage.visual_field
	if multiplayer.is_server(): stage.visual_field=battlefield
	var rendered_players: Dictionary=players if multiplayer.is_server() else net_motion.render_players(players,local_id,Time.get_ticks_msec())
	if not multiplayer.is_server():rendered_players=preload("res://avatar_motion_view.gd").people(rendered_players,local_id,mouse_controls.local_aim)
	var p: Dictionary = local_player
	var local_timers: Cooldowns.Timers = p.get(Cooldowns.STATE)
	var cooldown_now := Time.get_ticks_msec()
	var wild: bool = Participation.is_wild(p)
	var warnings: Array=attack_hints_snapshot() if multiplayer.is_server() and wild else p.get("attack_hints",[]) if wild else []
	if not multiplayer.is_server() and client_details_key!=str([participation.route(),participation.floor(),participation.seed()]):
		warnings=warnings.filter(func(hint): return hint.role not in ["core_thorns","core_anchor","core_field","core_lured","glasscap_feint"])
	preload("res://glasscap_visuals.gd").prepare(stage,warnings)
	stage.set_meta("enemy_attack_poses",preload("res://enemy_attack.gd").poses(warnings))
	var rendered_pack := scout_snapshot(cooldown_now) if multiplayer.is_server() else client_pack
	stage.draw_state(rendered_players, local_id, tactics.position, enemy_health(), tactics.winding_up, LeaderBehavior.strike_radius(self), drop_pos, visible_drop, data[3], participation.depth(), route_rooms(), graft_altar_open(), briar_bound, tactics.longlimb, campaign_state,
		rendered_pack, _delta,view_id)
	update_ready_panel(p,local_id)
	death_visuals.sync(death_events_snapshot() if multiplayer.is_server() and wild else p.get("death_events",[]) if wild else [],"%d:%d:%d:%s"%[participation.route(),participation.floor(),participation.seed(),str(wild)],observer)
	var presentation_key := "%d:%d:%d:%s"%[participation.route(),participation.floor(),participation.seed(),str(wild)]
	var events := combat_events_snapshot() if multiplayer.is_server() else guest_combat_events(p)
	get_node("EventAudio").sync(events,presentation_key,wild,observer,local_id,Time.get_ticks_msec())
	combat_visuals.sync(events if wild else [],warnings,presentation_key,observer)
	stage.attack_ring.visible=false
	for ring in stage.support_rings: ring.visible=false
	exploration.thief_routes=preload("res://thief_escape.gd").map_routes(self,p) if wild else []
	exploration.update_floor(stage.visual_field, "%d:%d:%d" % [participation.route(), participation.floor(), participation.seed()],
		observer, stage.camera, wild, drop_pos, visible_drop,
		not p.get("cache_claimed", false) and participation.route() != Campaign.HEART, ui.is_overlay_open(), graft_altar_open(),inventory_floor_snapshot(p) if multiplayer.is_server() else p.get("ground_items",[]))
	stage.apply_exploration_sight(observer, wild, exploration.SIGHT,
		exploration.seen(visual_field.advance) if is_instance_valid(stage.experimental_exit) else true)
	preload("res://glasscap_visuals.gd").sync(stage,observer,exploration.SIGHT)
	var carried: int = p.carried_seeds.size() if multiplayer.is_server() and wild else client_carried_count
	var health := PlayerVitals.current_hp(p)
	var prompt := ""
	var details := ""
	var session_text := ""
	if wild:
		if not encounter_cleared():
			var pack := rendered_pack
			var hatching: bool=tactics.boss_kind==22 and warnings.any(func(hint):return hint.role=="nursery_exit")
			var warning := not hatching and tactics.winding_up and (tactics.landing if tactics.attack_mode == "vault" else tactics.position).distance_to(p.pos) < LeaderBehavior.strike_radius(self) + 0.7
			for i in range(2, pack.size(), PACK_STRIDE):
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
			prompt = "Dodge out of the marked attack!" if warning else "Stand at a hatch site to block it." if hatching else ""
		elif visible_drop:
			prompt = "E  Collect seeds"
		else:
			if participation.depth() < route_rooms():
				prompt = "E  Continue"
			else:
				prompt = "Continue to %s" % Campaign.NAMES[(participation.route() + 1) % Campaign.HEART]
		var last_offer := AffinityCards.completed_floor(p) if multiplayer.is_server() else int(p.get("last_offer", 0))
		if upgrade_checkpoint_open() and last_offer != participation.floor():
			prompt="E  Choose an upgrade" if visual_field.advance.distance_to(p.pos)<=preload("res://gate_interaction.gd").RANGE else "Upgrades await at the gate"
		if extraction_checkpoint_open() and visual_field.advance.distance_to(p.pos) <= preload("res://gate_interaction.gd").RANGE:
			prompt = "E  Continue    ·    T  Extract to the Garden"
			details = "Extract or continue."
			if last_offer != participation.floor():
				details += "\nE  Choose an upgrade   ·   %d Essence" % (run_wallet(p) if multiplayer.is_server() else int(p.get("wallet", 0)))
		if visual_field.has_seed_cache() and not p.get("cache_claimed", false) and (
				visual_field.cache.distance_to(p.pos) <= 1.55 and participation.route() != Campaign.HEART):
			prompt = "E  Search the abandoned clearing"
		if graft_altar_open() and visual_field.graft.distance_to(p.pos) <= 1.65 and preload("res://gate_interaction.gd").shrine_preferred(visual_field,p.pos):
			prompt="E  Grafting Altar"
			var improvements: Dictionary = preload("res://expedition_grafts.gd").owner_details(p, participation.floor()) if multiplayer.is_server() else p.get("graft_improvements",{})
			details="Altar used" if improvements.get("used",false) else "Spend a carried trophy on an expedition improvement."
			if improvements.has("remaining"):
				details += " · %d remaining" % int(improvements.remaining)
		session_text = "%s  ·  %d player(s)" % [network_session.role(), players.size()]
		if stage.experimental_garden != null:
			session_text = "Experimental terrain · %s" % network_session.role() if stage._has_experimental_floor() else "Experimental terrain · Special floor fallback"
	else:
		prompt = ""
	if not wild:
		var garden := garden_snapshot() if multiplayer.is_server() else client_garden
		var near_gate := stage.gate_position().distance_to(p.get("pos", Vector3.ZERO)) <= preload("res://gate_interaction.gd").RANGE
		var slot := nearby_plot(p.get("pos", Vector3.ZERO))
		var beds := Progress.decode_plots(garden[12])
		if slot >= 0 and slot < beds.size():
			var bed: Dictionary = beds[slot]
			if bed.species >= 0:
				prompt = "E  Harvest %s" % ("seed" if bed.flowering else "crafting parts") if bed.stage == 3 else "%s · %s" % [Progress.PLANT_NAMES[bed.species], ["Seed", "Sprout", "Young", "Mature"][bed.stage]]
				if bed.flowering and bed.stage < 3:
					prompt += " · Seed crop"
				if garden[2] and not bed.flowering:
					prompt += "  |  F  Harvest seeds instead" if int(bed.stage)==3 else "  |  Seeds can be harvested when mature"
			else:
				prompt = "Living offshoot · care at the Heart" if int(bed.get("offshoot",-1))>=0 else "E  Choose a seed to plant"
		elif stage.altar_position().distance_to(p.get("pos", Vector3.ZERO)) <= 1.65:
			prompt="E  Altar"
			details="Identify seeds · Combine seeds or plant parts"
		elif near_gate:
			prompt="E  Wilds Gate"
		elif at_heart(p):
			prompt="E  Heart"
			if stage.experimental_garden != null: prompt += "   ·   B  Garden development"

	if wild and can_checkpoint_bank(p):
		details+="\nJ · Send one carried find home"
	var garden_prompt: String = get_node("GardenInteractions").context_prompt(p)
	if not garden_prompt.is_empty(): prompt = garden_prompt
	var rescue_id:=Life.nearest(self,p)
	if rescue_id!=0:
		var ally: Dictionary=players[rescue_id]
		var can_revive:=Life.Vitals.can_revive(PlayerVitals.maximum_hp(ally,Life.Preview.hp(MAX_HEALTH)),Life.Preview.scale())
		var cost: String="%d maximum HP"%Life.Preview.revive_cost()
		prompt="E  Revive %s · costs them %s"%[ally.get("display_name",ally.get("character",{}).get("name","ally")),cost] if can_revive else "This ally has too little maximum health to revive."
	if PlayerLifecycle.fallen(p) and wild: prompt="Fallen · awaiting revival"
	var ground_id:=nearest_inventory_drop(p) if multiplayer.is_server() else nearest_visible_inventory_drop(p)
	if not ground_id.is_empty() and rescue_id==0 and not PlayerLifecycle.fallen(p): prompt="E  Pick up item"
	if multiplayer.is_server() and not participation.active(): consider_recollection()
	refresh_feedback()

	if not wild:
		var ending := ending_message(campaign_state[5])
		session_text = ending if not ending.is_empty() else "%s  |  %d player(s)" % [network_session.role(), players.size()]
		session_text += "\nDeepest clear %d  ·  Best extraction %d" % [campaign_state[12], campaign_state[13]]
	var shared := garden_snapshot() if multiplayer.is_server() else client_garden
	stage.update_plots(Progress.decode_plots(shared[12]))
	stage.update_heart_progress(heart_state())
	get_node("Soundscape").update_mix(_delta,wild,participation.route(),participation.floor(),tactics.boss_kind>=0,observer,stage.heart_unlocked)
	stage.update_garden(int(shared[6]), int(shared[2]) + int(shared[7]) + int(shared[11]) + int(heart_state().get("clearing",0)))
	var host_side := multiplayer.is_server()
	var ready_skill := (local_timers == null or local_timers.ready(Cooldowns.Q, cooldown_now)) if host_side else bool(p.get("skill_ready", false))
	var second_ready := (local_timers == null or local_timers.ready(Cooldowns.R, cooldown_now)) if host_side else bool(p.get("skill_two_ready", false))
	var skills: Array=[Skills.resolve_in_world(self,int(p.get("frame",0)),0,p.get("character",guest_character.data)),
		Skills.resolve_in_world(self,int(p.get("frame",0)),1,p.get("character",guest_character.data))]
	var cooldowns: Array = local_timers.skill_seconds(cooldown_now) if host_side and local_timers != null else p.get("skill_cooldowns", [0.0, 0.0])
	var skill_tips: Array=Skills.wild_tooltips(self,p,skills) if wild else [skills[0].name+"\n"+skills[0].description,skills[1].name+"\n"+skills[1].description]
	var quake_prepared:=false
	if skills[0].has("warden_focus"):
		var warden=preload("res://warden_combat.gd")
		quake_prepared=warden.prepared_until(self,p,Time.get_ticks_msec())>0 if host_side else bool(p.get("warden_quake_prepared",false))
		if quake_prepared:skill_tips[1]+="\nQuake prepared."
	var ready_dodge := (local_timers == null or local_timers.ready(Cooldowns.DODGE, cooldown_now)) if host_side else bool(p.get("dodge_ready", false))
	if network_session.role()=="Host": session_text+="\nHosting on UDP %d"%network_session.port()
	ui.present_menu({"session_text":"Developer Garden · Single player" if has_meta("developer_garden") else session_text,
		"role":network_session.role(),"can_host":not has_meta("developer_garden") and network_session.role() in ["Host","Solo"] and not (network_session.role()=="Solo" and wild),
		"can_join":not has_meta("developer_garden") and network_session.role()=="Solo" and not wild,
		"can_leave":network_session.role()!="Solo","can_save":multiplayer.is_server(),"can_bank":can_checkpoint_bank(p),"wild":wild,
		"look":Array(p.get("character",{}).get("appearance",p.get("appearance",[0,0,0,0,0])))})
	ui.present_context(prompt,details)
	ui.present_hud({"party":preload("res://party_hud.gd").members(players,local_id),
		"location": Campaign.NAMES[participation.route()] if wild else "Mystical Garden",
		"floor":participation.floor(),
		"encounter": "%d foes" % [int(enemy_health() > 0) + living_scout_count()] if wild else "Your living sanctuary",
		"damage_flash":maxf(0,(int(p[Conditions.STATE].grace_until_ms() if host_side else p.get("client_hurt_until",0))-Time.get_ticks_msec())/250.0),"hp": health, "max_hp": PlayerVitals.maximum_hp(p,MAX_HEALTH), "lost_health":p.get("lost_health",0),"fallen":PlayerLifecycle.fallen(p), "wild": wild, "frame": p.get("frame", 0),
		"skill_ready": ready_skill,"skill_two_ready":second_ready,"skill_names":[skills[0].name,skills[1].name+(" •" if quake_prepared else "")],"skill_cooldowns":cooldowns, "dodge_ready": ready_dodge,
		"core":preload("res://core_combat.gd").hud_state(self,p),
		"skill_tooltips":skill_tips,
		"affinity_feedback":preload("res://combat_status.gd").affinity_feedback(self,p) if host_side and wild else str(p.get("affinity_feedback","")) if wild else "",
		"carried": carried if wild else data[0],
		"pouch": p.get("pouch", false) if host_side else client_pouch_filled,
		"wallet": run_wallet(p) if host_side and wild else int(p.get("wallet", 0)) if wild else 0,
		"insight":heart_state().get("insight",0), "knowledge": shared[6]},exploration.expanded)


func living_scout_count() -> int:
	if multiplayer.is_server():
		return encounter.living_scout_count()
	var count := 0
	for i in range(2, client_pack.size(), PACK_STRIDE):
		count += int(client_pack[i] > 0)
	return count



func request_main_menu() -> void:
	if participation.active() and network_session.role() in ["Solo","Host"] or Participation.is_wild(players.get(local_player_id(),{})):
		ui.show_title_confirmation()
	else:
		return_to_main_menu()


func prepare_guarded_exit(save_garden := true) -> bool:
	if not persistence_session.can_write(): return true
	if network_session.role() in ["Solo","Host"] and slot_claimed:
		if participation.active():
			if not load("res://expedition_transitions.gd").finish_voluntary(self): return false
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
	if load("res://expedition_transitions.gd").request_guest_exit(self,Session.Exit.TITLE): return
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
	if network_session.role() in ["Solo","Host"] and not network_session.joined_from_title():
		if participation.active():
			if not load("res://expedition_transitions.gd").finish_voluntary(self):
				returning_to_title = false
				return
			for player in players.values():
				if Participation.is_wild(player):
					load("res://expedition_transitions.gd").return_member(self,player)
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
	SessionWorld.offline(self)
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
	# Static callables outlive a Node; release the connections this world owns.
	if multiplayer.connected_to_server.is_connected(SessionWorld.joined.bind(self)):
		multiplayer.connected_to_server.disconnect(SessionWorld.joined.bind(self))
	if multiplayer.connection_failed.is_connected(SessionWorld.connection_failed.bind(self)):
		multiplayer.connection_failed.disconnect(SessionWorld.connection_failed.bind(self))
	if multiplayer.server_disconnected.is_connected(SessionWorld.server_disconnected.bind(self)):
		multiplayer.server_disconnected.disconnect(SessionWorld.server_disconnected.bind(self))
	SessionWorld.offline(self)
	release_slot()


func current_mutations(kind: int, growth: int, stamp: int) -> int:
	var gain := 2 if participation.floor() >= 10 else 0
	var older_pressure: Dictionary={"ranged":progress.ranged_pressure+ranged_clears*gain,
		"burst":progress.burst_pressure+burst_clears*gain,"choke":progress.choke_pressure+choke_clears*gain}
	var traits:=Enemies.mutations(kind,growth,0,0,0,participation.floor(),stamp)
	traits|=Learning.traits(progress.wilds_memory,participation.floor(),stamp,older_pressure)
	if kind==0 and ((participation.depth()>=2 and progress.ranged_pressure>=3 and participation.depth()%2==0) or (participation.depth()>=4 and ranged_clears>=2)): traits|=Enemies.REACH
	return Learning.bounded(traits,participation.floor(),stamp)


func weapon_stats(player: Dictionary, prepared: bool=false) -> Dictionary:
	var builds = preload("res://affinity_build.gd")
	var build := builds.for_player(player,prepared)
	var result: Dictionary = builds.native_stats(build)
	result.affinity_build = build
	result["class_power"] = 0
	var band := Life.Preview.weapon_range(result,0)
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
			var tree := Classes.connected_tree(c)
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
	if client_garden.size()>16 and client_garden[16] is Dictionary: return client_garden[16]
	return {"unlocked":["heart"],"paid":[],"active":"","progress":{},"natural":{},"infused":{},"spent":0,"insight":0,"phase":0,"clearing":0}

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

func reclaim_seed(id: int,player: Dictionary,requested := -1) -> void:
	if not at_garden_station(player,"seed_archive"): return
	if persistence_session.is_guarded():
		run_guarded_action(id, Transactions.Scope.GARDEN, func(effects): _reclaim_seed(id, player, requested, effects))
	else:
		_reclaim_seed(id, player, requested, null)

func _reclaim_seed(id: int,player: Dictionary,requested: int,effects) -> void:
	if requested >= 0: player.reclaim_choice=requested
	var kind:=reclamation_species(player)
	if not progress.discoveries[kind]:
		action_feedback(effects,id,"Discover a species before reclaiming its seed.")
		return
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
	var seeds: int=player.carried_seeds.size() if multiplayer.is_server() else client_carried_count
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
	var seed: int=-1
	if fields[1]=="seed":
		if index<0 or index>=player.carried_seeds.size(): return
		seed=int(player.carried_seeds[index])
		player.carried_seeds.remove_at(index)
		preload("res://garden_return_service.gd").bank(self,player,[seed],"checkpoint:"+str(participation.floor()))
		reserve.unknown.append(seed)
		if index==0 and player.get("safe_items",[]).is_empty(): player.pouch=false
	elif fields[1]=="part":
		if index<=0 or index>=Parts.DEFINITIONS.size() or player.carried_parts[index]<=0: return
		player.carried_parts[index]-=1
		reserve.parts[index]+=1
	else: return
	if effects == null and progress.save_garden()!=OK:
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
	player.last_deposit=participation.floor()
	action_feedback(effects,id,"Item sent to Garden storage.")



func consider_recollection() -> void:
	if not Campaign.LEGACY_ENDING_ENABLED: return
	if not progress.heart.has("perfect_recollection") or progress.heart.recollection_seen or progress.campaign.ending!=Campaign.UNFINISHED or players.is_empty(): return
	if ui.is_overlay_open(): return
	if persistence_session.is_guarded():
		var result := Transactions.run_gameplay(self, Transactions.Scope.GARDEN, func(): progress.heart.recollection_seen=true)
		if not Transactions.committed(result.persistence): return
	else:
		var before: bool=progress.heart.recollection_seen
		progress.heart.recollection_seen=true
		if progress.save_garden()!=OK:
			progress.heart.recollection_seen=before
			return
	ui.toggle_panel("recollection")
	for id in players:
		if id!=HOST: tell(id,"The Heart perfectly remembers. Its final awakening awaits your party.")


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
	var stats := weapon_stats(player)
	Weapons.tune_affinity_basic(stats)
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
	if ledger == null:
		present_checkpoint_cards(id)
		return
	var stats := weapon_stats(player)
	Weapons.tune_affinity_basic(stats)
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
			load("res://expedition_transitions.gd").checkpoint(self,id,true)
			return






func graft_menu_data(player: Dictionary) -> Dictionary:
	var ledger := preload("res://expedition_grafts.gd").active_ledger(player)
	if ledger == null:
		return {}
	var build = preload("res://affinity_build.gd")
	var project_stats := build.graft_value_resolver(player, AffinityCards.totals(player), MAX_HEALTH)
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
	var stats: Dictionary=weapon_stats(player,not Participation.is_wild(data)) if multiplayer.is_server() else player.get("weapon_stats",{})
	# Local view only: reliable weapon details already carry this resolved build.
	data.affinity_build=stats.get("affinity_build",{}).duplicate(true)
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
		drops.erase(drop);InventoryModel.put(self,player,source,stack)
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
			InventoryModel.take(self,player,target,entry.stack.item,int(entry.stack.quantity));drops.insert(index,entry)
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
	var data:=Altar.snapshot(self,players[id],[{},{}],0)
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


func record_enemy_death(target: int,position: Vector3,origin: Vector3,expected_token: int = -1) -> void:
	if not encounter.death_pending(target, expected_token):
		return
	var spawn_token := "leader" if target == -1 else str(encounter.token(target))
	var kind: int = enemy_kind if target == -1 else int(encounter.scout(target).get("kind", 0))
	var mask: int = enemy_mutations if target == -1 else int(encounter.scout(target).get("mutations", 0))
	var summoned := target >= 0 and bool(encounter.scout(target).get("summoned", false))
	if not _queue_monster_reward(spawn_token, kind, mask, position, target == -1, summoned):
		return
	encounter.confirm_death(target)
	if not summoned:
		encounter_kills.append(kind)
		encounter_kill_records.append({"kind":kind,"mask":mask})
	if target>=0: EnemyBehaviors.death(self,encounter.scout(target),position)
	elif not encounter.leader_tactics().is_empty(): EnemyBehaviors.death(self,encounter.leader_tactics(),position)
	var growth: int=enemy_growth if target==-1 else int(encounter.scout(target).get("growth",0))
	var direction: Vector3=(position-origin).normalized()
	enemy_death_serial+=1
	var scale_value: float=1.0 if tactics.boss_kind>=0 and target==-1 else (1.9 if participation.route()==Campaign.HEART or participation.depth()==ROUTE_ROOMS else 1.0 if participation.depth()==1 else 1.22) if target==-1 else 1.0
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
	var now:=Time.get_ticks_msec()
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
	combat_events.append({"id":combat_event_serial,"kind":kind,"shape":shape,"from":[from.x,from.y,from.z],"to":[to.x,to.y,to.z],"duration":duration,"color":color.to_html(),"reach":reach,"combo":combo,"span":2.7 if shape=="wide_arc" else 1.3 if shape=="knife_arc" else 1.9,"born":Time.get_ticks_msec()})

	var latest: Dictionary=combat_events.back()
	for key in options:
		if key in ["form","pattern","contact","width","span","projectile_radius","height","owner","clip","target_token","core_shapes","core_phase"]:latest[key]=options[key]
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
	event.age=maxf(0,(Time.get_ticks_msec()-int(source.born))/1000.0)
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
		if int(shot.epoch)!=participation.epoch() or not players.has(shot.player) or not Life.alive(players[shot.player]):projectile_queue.erase(shot);continue
		if not PlayerLifecycle.matches(players[shot.player],int(shot.get("life",-1))):projectile_queue.erase(shot);continue
		if shot.get("melee_shape",false):
			if now>=int(shot.due):
				preload("res://event_audio.gd").weapon(self,shot.form,players[shot.player].pos)
				var spirit = preload("res://spirit_affinity.gd")
				var owner: Dictionary=players[shot.player]
				if owner.has(spirit.FOLLOW): spirit.launch(self,owner,shot.stats,1)
				preload("res://weapon_contact.gd").melee(self,shot,now)
				if owner.has(spirit.FOLLOW): spirit.finish(self,owner,shot.stats)
				projectile_queue.erase(shot)
			continue
		if now<int(shot.release):continue
		var rays: Array=[shot]
		if not shot.get("emitted",false):
			MouseCombat.launch(self,shot)
			preload("res://event_audio.gd").weapon(self,shot.form,shot.origin)
			rays=MouseCombat.volley(self,shot)
			var owner: Dictionary=players[shot.player]
			if owner.has("affinity_spirit_follow"):
				preload("res://spirit_affinity.gd").launch(self,owner,shot.stats,rays.size())
			if shot.stats.get("ranger_ordinary",false):
				var second_shot := preload("res://ranger_combat.gd").launch(self,owner,shot,now)
				if not second_shot.is_empty():
					rays.append(second_shot)
			for ray in rays:
				if not is_same(ray,shot):projectile_queue.append(ray)
				var form: String=ray.form
				var flight:=maxf(.03,(int(ray.due)-int(ray.release))/1000.)
				var color := weapon_effect_color(players[ray.player])
				if ray.get("ranger_secondary",false):
					color = color.lerp(Color("#e6bd69"),.65)
				emit_combat_event("projectile",str(WeaponMotion.profile(form).shape),ray.origin,ray.aim,flight,color,float(ray.stats.reach),0,preload("res://weapon_contact.gd").describe(form,ray.stats))
				ray.visual_event_id=combat_event_serial
		for ray in rays:
			if MouseCombat.ray_tick(self,ray,now):
				if ray.has("visual_event_id"):emit_combat_event("projectile_end",str(ray.visual_event_id),ray.origin,ray.get("visual_stop",ray.aim),.15,Color.WHITE,0,0)
				var owner: Dictionary=players[ray.player]
				if owner.has("affinity_spirit_follow") and not ray.get("ranger_secondary",false):
					preload("res://spirit_affinity.gd").finish(self,owner,ray.stats)
				projectile_queue.erase(ray)


func attack_hints_snapshot() -> Array:
	var result: Array=Bosses.hints(self)
	result.append_array(preload("res://glasscap_feint.gd").hints(self,Time.get_ticks_msec()))
	if tactics.boss_kind<0 and participation.route()!=Campaign.HEART and not encounter.leader_tactics().is_empty():result.append_array(preload("res://elite_enemy.gd").hints(self))
	if enemy_health()>0 and tactics.winding_up and not Bosses.owns_warnings(tactics.boss_kind) and (tactics.boss_kind>=0 or encounter.leader_tactics().is_empty()):
		var target:=tactics.landing if tactics.attack_mode=="vault" or tactics.boss_kind>=0 else tactics.position
		result.append({"id":-1,"role":("charge" if tactics.attack_mode in ["root_sweep","orchard_march","drowned_surge","matriarch_lunge","memory_lance","remembered_rend"] else "volley") if tactics.boss_kind>=0 else "vault" if tactics.attack_mode=="vault" else "swipe","from":[tactics.position.x,0,tactics.position.z],"to":[target.x,0,target.z],"radius":Bosses.warning_radius(self) if tactics.boss_kind>=0 else LeaderBehavior.strike_radius(self),"width":Bosses.warning_width(self) if tactics.boss_kind>=0 else .85,"remaining":maxf(0,(tactics.strike_at-Time.get_ticks_msec())/1000.0)})
	var attacks=preload("res://enemy_attack.gd")
	result.append_array(attacks.scout_hints(encounter,participation.epoch(),Time.get_ticks_msec(),
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
	result.append_array(preload("res://warden_combat.gd").hints(self,Time.get_ticks_msec()))
	return result


func show_planting_picker(id: int,slot: int) -> void:
	var p: Dictionary=players[id]
	if Participation.is_wild(p) or slot<0 or slot>=progress.plots.size() or p.pos.distance_to(stage.bed_position(slot))>1.65 or progress.plots[slot].species>=0 or progress.offshoot_in_bed(slot)>=0: return
	var stock: Array=seed_reserve(p).stock.duplicate()
	if id==HOST: open_planting_picker(slot,stock)
	else: open_planting_picker.rpc_id(id,slot,stock)
@rpc("authority","call_remote","reliable")
func open_planting_picker(slot: int,stock: Array) -> void:
	ui.show_planting(slot,stock)
@rpc("authority","call_remote","reliable")
func close_planting_picker() -> void:
	if ui.panel_is_open("planting"): ui.close_panels()



@rpc("authority","call_remote","reliable",1)
func receive_details(payload: PackedByteArray,garden: PackedByteArray,inventory_data: Array,state_key: String) -> void:
	var decoded=bytes_to_var(payload.decompress_dynamic(262144,FileAccess.COMPRESSION_DEFLATE))
	var world=bytes_to_var(garden.decompress_dynamic(262144 if stage.experimental_garden != null else 65536,FileAccess.COMPRESSION_DEFLATE))
	if not decoded is Dictionary or not world is Array or world.size()<13: return
	if not network_session.permits_details(str(decoded.get(ActionIdentity.BINDING_KEY,""))): return
	if stage.experimental_garden != null:
		if world.size() != 18 or not world[17] is Dictionary: return
		stage.experimental_garden.receive_snapshot(world[17])
	net_view.set_roster(decoded.get("snapshot_roster", {}), decoded.get("diagnostic_host", ""), decoded.get("diagnostic_world", ""))
	net_view.apply_roster(players)
	decoded.erase("snapshot_roster")
	var recovery: PackedByteArray = decoded.get("snapshot_recovery", PackedByteArray())
	decoded.erase("snapshot_recovery")
	client_details=decoded;client_details_key=state_key;client_inventory=inventory_data;client_garden=world
	set_meta("core_details_at",Time.get_ticks_msec())
	var id:=multiplayer.get_unique_id()
	if players.has(id): players[id].merge(client_details,true)
	if not recovery.is_empty(): apply_world_snapshot(recovery, true)

@rpc("authority","call_remote","reliable",2)
func receive_combat_event(event: Dictionary,key: String) -> void:
	received_combat_events.append({"event":event,"key":key,"born":Time.get_ticks_msec()})
	while received_combat_events.size()>100: received_combat_events.pop_front()

func guest_combat_events(player: Dictionary) -> Array:
	var result: Array=[];var key:=str([participation.route(),participation.floor(),participation.seed()]);var now:=Time.get_ticks_msec()
	for entry in received_combat_events.duplicate():
		var age: float=maxf(0,float(entry.event.get("age",0)))+(now-int(entry.born))/1000.0
		if age>float(entry.event.duration)+.2: received_combat_events.erase(entry);continue
		if entry.key!=key: continue
		var event: Dictionary=entry.event.duplicate();event.age=age;result.append(event)
	if client_details_key==key: result.append_array(player.get("combat_events",[]))
	return result

func request_ip_join() -> void:
	if stage.experimental_garden != null:
		return_to_main_menu("Choose a character and join from the Co-op tab.")
		return
	var recent := Network.load_settings(slot_storage_root)
	network_dialog.begin(recent.address,recent.port,true,str(local_character.data.get("name","Wanderer")))

@rpc("authority","call_remote","reliable")
func connection_accepted(profile: Dictionary) -> void:
	SessionWorld.accepted(self,profile)

@rpc("authority","call_remote","reliable")
func connection_rejected(reason: String) -> void:
	SessionWorld.rejected(self,reason)

func party_travel_state() -> Dictionary:
	var id:=multiplayer.get_unique_id()
	return PartyTravel.snapshot(self,id) if multiplayer.is_server() else players.get(id,{}).get("party_travel",{})

func send_travel_ready(unready: bool) -> void:
	var state:=party_travel_state()
	if not state.is_empty(): send_garden_action(("travel_unready:" if unready else "travel_ready:")+str(state.epoch))

func update_ready_panel(player: Dictionary,id: int) -> void:
	var state: Dictionary=PartyTravel.snapshot(self,id) if multiplayer.is_server() else player.get("party_travel",{})
	ui.present_travel(state,participation.route()==Campaign.HEART)

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
	if multiplayer.is_server() and aim.is_finite() and SessionWorld.allow_remote(self,id,"combat_input",60):mouse_controls.receive(self,id,aim,held,Time.get_ticks_msec())
