extends RefCounted
## Applying accepted guest display data is a world/owner integration operation.
## This port owns no incoming buffers and exposes no mutable actor or service.
const Participation = preload("res://expedition_participation.gd")
const Enemies = preload("res://enemy_catalog.gd")
const Encounter = preload("res://encounter_config.gd")
const Clock = preload("res://combat_clock.gd")
var _world: Node

func _init(world: Node) -> void: _world = world
func observer() -> Callable: return _world.get_meta(&"snapshot_witness",Callable())
func local_peer() -> int: return _world.multiplayer.get_unique_id()
func floor_number() -> int: return _world.participation.floor()
func requires_layout() -> bool: return _world.stage.experimental_garden != null
func accepts_details(binding: String) -> bool: return _world.network_session.permits_details(binding)

func apply_layout(layout: Dictionary) -> void:
	_world.stage.experimental_garden.receive_snapshot(layout)

func apply_roster(names: Dictionary, host: String, session: String) -> void:
	for peer in _world.players:
		var actor: Dictionary = _world.players[peer]
		actor.display_name = names.get(peer,"Wanderer")
		actor.diagnostic_host = host;actor.diagnostic_world = session

func apply_details(details: Dictionary) -> void:
	var peer := local_peer()
	if _world.players.has(peer): _world.players[peer].merge(details,true)

func apply_vitals(updates: Dictionary) -> void:
	for peer in updates:
		if _world.players.has(peer): _world.players[peer].merge(updates[peer],true)

func apply_world(state: Dictionary) -> void:
	# Game.players remains the current display/prediction projection. The receive
	# owner never keeps a second actor roster; host gameplay records are separate.
	var before: Dictionary = _world.players
	var membership := {}
	for peer in state.people: membership[peer] = bool(state.people[peer].wild)
	var links: Dictionary = _world.participation.project_participants(membership)
	_world.players = state.people
	for peer in _world.players:
		_world.players[peer][Participation.STATE] = links[peer]
		_world.players[peer].erase("wild")
	var flags := int(state.flags)
	var campaign: PackedInt32Array = state.campaign
	_world.participation.project_world({"depth":state.depth,"destination":campaign[0],
		"map_seed":campaign[8],"encounter_number":campaign[9],"difficulty_cycle":campaign[10]})
	var form: Dictionary = Enemies.decode(campaign[18])
	_world.enemy_kind = form.kind;_world.enemy_mutations = form.mask;_world.enemy_growth = form.tier
	var landing := Vector3(campaign[Encounter.LANDING_X]/100.0,0,campaign[Encounter.LANDING_Z]/100.0)
	_world.tactics.project(state.enemy,(flags&1)!=0,(flags&16)!=0,landing,
		"vault" if campaign[Encounter.ATTACK_MODE]!=0 else "",campaign[Encounter.BOSS_KIND],
		campaign[Encounter.BOSS_PHASE],campaign[6]/100.0)
	_world.net_motion.receive(_world,local_peer(),before,Clock.now())
