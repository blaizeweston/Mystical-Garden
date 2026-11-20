extends RefCounted
## Host publication port. Only this adapter reads world actors and services.
## Every returned record is detached; no public operation exposes an actor.
const Clock = preload("res://combat_clock.gd")
const Session = preload("res://network_session.gd")
const Participation = preload("res://expedition_participation.gd")
const Lifecycle = preload("res://player_lifecycle.gd")
const Vitals = preload("res://player_vitals.gd")
const Cooldowns = preload("res://player_cooldowns.gd")
const Protection = preload("res://player_protection.gd")
const Conditions = preload("res://player_hit_conditions.gd")
const Cards = preload("res://affinity_cards.gd")
const Identity = preload("res://network_action_identity.gd")
const Journal = preload("res://diagnostic_journal.gd")
const Inventory = preload("res://inventory_model.gd")
const Travel = preload("res://party_travel.gd")
var _world: Node

func _init(world: Node) -> void:
	_world = world

func health_states() -> Dictionary:
	var result := {}
	for peer in _world.players:
		var actor: Dictionary = _world.players[peer]
		result[peer] = {"hp":Vitals.current_hp(actor),"max_hp":Vitals.maximum_hp(actor),
			"wild":Participation.is_wild(actor),"fallen":Lifecycle.fallen(actor),
			"lost_health":actor.get("lost_health",0),"damage_seq":actor.get("damage_seq",0),
			"damage_amount":actor.get("damage_amount",0)}
	return result

func peers() -> PackedInt32Array:
	var result := PackedInt32Array()
	var transport: ENetMultiplayerPeer = _world.network_session.transport()
	if transport==null or _world.multiplayer.multiplayer_peer!=transport or not _world.multiplayer.is_server() \
		or transport.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED: return result
	for peer in _world.multiplayer.get_peers():
		if not Session.ready_for(_world.players.get(peer,{}),false): continue
		var packet := transport.get_peer(peer)
		# Godot reserves 0/1; RPC channel 4 requires ENet channel 5.
		if packet!=null and packet.is_active() and packet.get_state()==ENetPacketPeer.STATE_CONNECTED and packet.get_channels()>5:
			result.append(peer)
	return result

## A committed save can still need cleanup. Publish only for its captured
## transport, from a surviving world that still owns its guarded leases.
func publish_committed_cleanup(transport: ENetMultiplayerPeer) -> void:
	if not is_instance_valid(_world) or not _world.is_inside_tree() or transport==null \
		or _world.network_session.transport()!=transport: return
	var session = _world.persistence_session
	if session.is_stopping() or not session.is_guarded() or not session.owns_leases(): return
	_world.replication.publish(self,0.0,true)

func state_key() -> String:
	return str([_world.participation.route(),_world.participation.floor(),_world.participation.seed()])

func observer() -> Callable:
	return _world.get_meta(&"snapshot_witness",Callable())

func world_state(now: int) -> Dictionary:
	var tactics = _world.tactics
	return {"people":players(-1,false),"campaign":_world.campaign_snapshot(),
		"scouts":_world.encounter.scout_pack(now),"enemy":tactics.position,
		"hp":_world.enemy_health(),"maximum":_world.encounter_health(),"drop":_world.drop_pos,
		"depth":_world.participation.depth(),
		"flags":int(tactics.winding_up)|(8 if now<tactics.rooted_until else 0)|(16 if tactics.longlimb else 0)}

func garden() -> Array:
	var result: Array = _world.garden_snapshot().duplicate(true)
	if _world.stage.experimental_garden != null:
		result.append(_world.stage.experimental_garden.snapshot())
	return result

func roster() -> Dictionary:
	var result := {}
	for id in _world.players: result[id] = _world.players[id].character.get("name","Wanderer")
	return result

func diagnostics() -> Dictionary:
	return {"host":Journal.current.session_id if is_instance_valid(Journal.current) else "",
		"world":_world.diagnostic_watch.world_session if is_instance_valid(_world.diagnostic_watch) else ""}

func recipient(peer: int) -> Dictionary:
	if not _world.players.has(peer): return {}
	var actor: Dictionary = _world.players[peer]
	return {"carried":actor.carried_seeds.size(),"dropped":actor.loot_pending,"pouch":actor.pouch}

func owner_binding(peer: int) -> Dictionary:
	return {"connection":_world.network_session.connection_key(peer),
		"action_identity":Identity.current_stamp(_world,_world.players[peer])}

func common_details() -> Dictionary:
	# These bounded presentation queues prune expired entries when inspected.
	# Inspect once for the whole details burst, not once for every recipient.
	return {"combat_events":_world.combat_events_snapshot(),"attack_hints":_world.attack_hints_snapshot(),
		"death_events":_world.death_events_snapshot()}.duplicate(true)

func owner_details(peer: int, common: Dictionary) -> Dictionary:
	if not _world.players.has(peer): return {}
	var actor: Dictionary = _world.players[peer]
	var wild := Participation.is_wild(actor)
	var now := Clock.now()
	var timers: Cooldowns.Timers = actor[Cooldowns.STATE]
	var result := {"core_state":preload("res://core_combat.gd").owner_state(actor,now,_world.combat_build(actor).core_skill()),
		"weapon":actor.weapon,"prepared":actor.prepared,"experiment":actor.experiment,
		"dodge_ready":timers.ready(Cooldowns.DODGE,now),"last_offer":Cards.completed_floor(actor),
		"reclaim_choice":actor.get("reclaim_choice",0),"offering_choice":actor.get("offering_choice",0),
		"last_deposit":actor.get("last_deposit",0),"catalyst":actor.catalyst,"graft_part":0,"graft_floor":0,
		"prepared_catalyst":actor.prepared_catalyst,"cargo_plan":actor.cargo_plan,
		"stored_parts":_world.stored_counts(actor),"weapon_stats":_world.weapon_stats(actor,not wild),
		"carried_parts":actor.carried_parts,"reserve_parts":_world.seed_reserve(actor).parts,
		"run_upgrades":{},"bag":Inventory.snapshot(_world,actor),
		"ground_items":_world.inventory_floor_snapshot(actor),"secondary":actor.secondary,
		"prepared_secondary":actor.prepared_secondary,
		"garden_interactions":_world.garden_commands.projection(peer),
		"party_travel":Travel.snapshot(_world,peer),"seed_choice":_world.selected_seed(actor),
		"graft_choice":0,"cache_claimed":actor.cache_claimed,
		"graft_improvements":preload("res://expedition_grafts.gd").owner_details(actor,_world.participation.floor())}
	result.merge(common)
	if wild:
		result.affinity_feedback = preload("res://combat_status.gd").affinity_feedback(_world,actor)
		result.thief_routes = preload("res://thief_escape.gd").snapshot(_world)
		result.ability_growth_centers = preload("res://class_ability_targeting.gd").growth_centers(_world,peer)
		if int(actor.frame)==0:
			var warden = preload("res://warden_combat.gd")
			result.warden_anchor_point = warden.anchor_point(_world,actor,now)
			result.warden_relay_point = warden.relay_point(_world,actor,now)
			result.warden_quake_prepared = warden.prepared_until(_world,actor,now)>0
		if actor.has(Cards.STATE): result.affinity_run_cards = Cards.project_owned(actor,result.weapon_stats,_world.DODGE_COOLDOWN_MS)
	return result.duplicate(true)

## Compatibility inspection for local consumers: public roster plus at most one
## owner's details. The publisher uses owner_details directly, without this loop.
func players(viewer: int, include_details: bool = true) -> Dictionary:
	var result := {}
	var diagnostic := diagnostics()
	var now := Clock.now()
	for peer in _world.players:
		var state := _public_player(peer,now)
		if peer==viewer and include_details: state.merge(owner_details(peer,common_details()))
		state.diagnostic_host = diagnostic.host
		state.diagnostic_world = diagnostic.world
		result[peer] = state
	return result

func _public_player(peer: int, now: int) -> Dictionary:
	var actor: Dictionary = _world.players[peer]
	var wild := Participation.is_wild(actor)
	var stride := preload("res://spirit_affinity.gd").scale(actor,preload("res://affinity_time.gd").now(_world)) if actor.has("affinity_spirit_strides") else 1.0
	if actor.has("ranger_speed_grants"):
		stride = maxf(stride,preload("res://ranger_combat.gd").speed_scale(_world,actor,now))
	var health: Vitals.Health = actor[Vitals.STATE]
	var timers: Cooldowns.Timers = actor[Cooldowns.STATE]
	var motion_key: String = _world.net_motion.world_key(_world,actor)
	var result := {"motion_radius":_world.bound_position(Vector3(1000,0,0)).x,"motion_epoch":motion_key,
		"motion_ack":_world.net_motion.acknowledgement(peer,motion_key),
		"motion_scale":actor[Protection.STATE].movement_scale(now)*actor[Conditions.STATE].movement_scale(now)*stride,
		"velocity":actor.get("velocity",Vector3.ZERO),"vitals_revision":_world.replication.health_revision(peer),
		"damage_seq":actor.get("damage_seq",0),"damage_amount":actor.get("damage_amount",0),
		"party_slot":Session.slot_for(actor,0),"display_name":actor.character.get("name","Wanderer"),
		"enemy_max_hp":_world.encounter_health(),"pos":actor.pos,"wild":wild,"fallen":Lifecycle.fallen(actor),
		"lost_health":actor.get("lost_health",0),"hp":health.hp(),"max_hp":health.max_hp(),
		"appearance":PackedByteArray(actor.character.get("appearance",[0,0,0,0,0])),"frame":actor.frame,
		"attack_anim":_world.attack_animation_snapshot(actor),
		"skill_fx":actor.get("skill_fx",{}) if now<int(actor.get("skill_fx_until",0)) else {},
		"weapon_kind":actor.get("weapon_kind",0),"core_part":actor.weapon if wild else actor.prepared,
		"pose":_world.combat_pose(actor),"wallet":_world.run_wallet(actor)}
	result.merge(timers.skill_projection(now))
	var garden_view = _world.stage.experimental_garden
	if garden_view != null and not wild:
		result.garden_layout_revision = garden_view.layout_revision if garden_view.reveal == null else -1
	return result.duplicate(true)

func inventory(peer: int) -> Array:
	return _world.inventory_snapshot(_world.players[peer]).duplicate(true)

func transport_stats(peer: int) -> Dictionary:
	var transport: ENetMultiplayerPeer = _world.network_session.transport()
	var packet: ENetPacketPeer = transport.get_peer(peer) if transport != null else null
	if packet == null: return {}
	return {"throttle":int(packet.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE)),
		"counter":int(packet.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_COUNTER))}

func send_vitals(peer: int, states: Dictionary) -> Error:
	return _world.rpc_id(peer,"receive_vitals",states)

func send_fast(peer: int, frame: PackedByteArray) -> Error:
	return _world.rpc_id(peer,"receive_state",frame)

func send_details(peer: int, details: PackedByteArray, garden_bytes: PackedByteArray, inventory_data: Array, key: String) -> Error:
	return _world.rpc_id(peer,"receive_details",details,garden_bytes,inventory_data,key)

func refuse_frame() -> void:
	push_error("World snapshot exceeds the supported player, scout, or payload limits.")
