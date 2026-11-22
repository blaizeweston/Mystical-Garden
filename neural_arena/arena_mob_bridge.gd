extends RefCounted
## Connects the neural mob simulation to the real enemies in an arena round.
## Each tick it mirrors the roster into the simulation, runs the brain, then writes movement back.

const ArenaAbilities = preload("res://neural_arena/arena_abilities.gd")
const ArenaLight = preload("res://neural_arena/arena_light.gd")
const ArenaFields = preload("res://neural_arena/arena_fields.gd")
const Catalog = preload("res://enemy_catalog.gd")
const CombatClock = preload("res://combat_clock.gd")
const Config = preload("res://neural_arena/arena_config.gd")
const Frost = preload("res://frost_combat.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const NeuralBrain = preload("res://ai/mob_neural_brain.gd")
const Participation = preload("res://expedition_participation.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Schema = preload("res://ai/mob_schema.gd")
const Session = preload("res://network_session.gd")
const Sim = preload("res://mob_sim/mob_sim.gd")
const Species = preload("res://mob_sim/mob_species.gd")
const Enums = preload("res://mob_sim/definitions/definition_enums.gd")
const EnemyBehaviors = preload("res://enemy_behaviors.gd")
const Glasscap = preload("res://glasscap_feint.gd")
const Thief = preload("res://thief_escape.gd")
const Tactics = preload("res://wilds_skill_tactics.gd")
const Campaign = preload("res://campaign.gd")
const Elite = preload("res://elite_enemy.gd")

const MS_PER_TICK := 1000.0 / 60.0
const MOBILITY_SPEED := 1.18
const JUVENILE_SPEED := 1.15
const NO_HITTER := -1
## Legacy play-style score at which a signature move becomes available.
const PLAYSTYLE_SCORE := 6
const UNLOCKS := Species.UNLOCK_SIGNATURE | Species.UNLOCK_COUNTER
## The gate elite chases 8% faster than its species, and has its signature from this floor, as in the game.
const ELITE_PURSUIT := 1.08
const ELITE_SIGNATURE_FLOOR := 3

var game: Node
var config: Config
var sim: Sim
## This round's darkness: light sources, and which player sees which enemy.
var light: ArenaLight
var error := ""
var capacity := 0
## The simulation's last slot is the gate elite, which the game keeps as encounter member -1.
var leader_slot := -1
## The elite's body is brought in step with the game's tactics once per game tick, then reused.
var _elite_synced_at := -1
var _tokens := PackedInt64Array()
var _hitters := PackedInt32Array()
var _written := PackedVector3Array()
var _peers := PackedInt32Array()
## Play-style evidence the party has shown this run, as one bit per DefinitionEnums.Evidence value.
var _party_evidence := 0
## Nonzero for enemies the game's own behaviour drives this tick: a Graft Thief stealing or escaping,
## or a Glasscap holding its feint. The simulation holds them and leaves their position alone.
var _host_owned := PackedByteArray()
## Unlock bits by species, floor and evidence, which change only when the party shows new evidence.
var _unlock_cache := {}
## The game's speed for each species this tick, shared by every enemy of that species.
var _speed_cache := {}
var _speed_tick := -1


func _init(world: Node, settings: Config) -> void:
	game = world
	config = settings
	capacity = int(game.EncounterConfig.MAX_SCOUTS) + 1
	leader_slot = capacity - 1


static func available() -> bool:
	return NavWorld.ensure_loaded()


## Frees the finished round's simulation.
func release() -> void:
	if sim != null and sim.abilities is ArenaAbilities:
		sim.abilities.disconnect_game()
	sim = null


## Builds a fresh simulation for the current map and roster.
func begin_round(seed_value: int) -> bool:
	release()
	sim = Sim.new(capacity)
	if sim.configure(game.battlefield) != OK:
		error = "The navigation map could not be built."
		return false
	var attacks := ArenaAbilities.new(sim.pool, sim.party, sim.species, sim.rules, sim.events, sim.locomotion)
	attacks.connect_game(game, self)
	sim.abilities = attacks
	sim.executors.abilities = attacks
	if config.brain != Config.SCRIPTED_BRAIN:
		var schema := Schema.new()
		var brain := NeuralBrain.new(schema, FileAccess.get_file_as_bytes(config.brain), sim.locomotion.world, sim.events, capacity, seed_value)
		if not brain.error.is_empty():
			error = brain.error
			return false
		sim.brain = brain
	_tokens.resize(capacity)
	_tokens.fill(-1)
	_hitters.resize(capacity)
	_hitters.fill(NO_HITTER)
	_written.resize(capacity)
	_host_owned.resize(capacity)
	_host_owned.fill(0)
	_peers.resize(sim.contract.players)
	_peers.fill(0)
	_unlock_cache.clear()
	_speed_cache.clear()
	light = ArenaLight.new(config.darkness, capacity, sim.contract.players)
	light.attach(sim)
	return true


## Whether a player sees an enemy. Always true in daylight.
func player_sees(peer: int, slot: int) -> bool:
	return light == null or light.sees(_party_slot(peer), slot)


func peer_of(party_slot: int) -> int:
	return _peers[party_slot]


func note_hit(target: int, peer: int) -> void:
	target = leader_slot if target == -1 else target
	if target >= 0 and target < capacity:
		_hitters[target] = _party_slot(peer)


## The game's encounter slot for a simulation slot: -1 for the gate elite.
func game_slot(slot: int) -> int:
	return -1 if slot == leader_slot else slot


## Whether the framework runs the gate elite: an ordinary elite (not a boss, not the Heart's Briar) is alive.
func drives_elite() -> bool:
	return sim != null and game.tactics.boss_kind < 0 and game.participation.route() != Campaign.HEART and game.encounter.alive(-1)


## The game's record for an enemy: a scout, or the gate elite's body kept in step with the game's tactics.
func actor(slot: int) -> Dictionary:
	if slot == leader_slot:
		return _elite_body() if drives_elite() else {}
	return game.encounter.scout(slot) if slot < game.encounter.scout_count() else {}


func actor_alive(slot: int) -> bool:
	return drives_elite() if slot == leader_slot else slot < game.encounter.scout_count() and game.encounter.alive(slot)


func actor_token(slot: int) -> int:
	return game.encounter.spawn_identity(-1) if slot == leader_slot else game.encounter.token(slot)


## After a wind-up locks: the gate elite's tactics show the attack, as the game's elite code does.
func after_lock(slot: int, body: Dictionary) -> void:
	if slot != leader_slot:
		return
	game.tactics.landing = body.attack.to
	game.tactics.begin_attack(str(body.mode), int(body.windup), float(body.attack.radius))


## After a release: the gate elite's tactics take the body's position, follow-up and ready time.
func after_release(slot: int, body: Dictionary) -> void:
	if slot != leader_slot:
		return
	game.tactics.position = body.pos
	game.tactics.winding_up = int(body.get("windup", 0)) > 0
	if game.tactics.winding_up:
		game.tactics.strike_at = int(body.windup)
	else:
		game.tactics.stop_attack()
		game.tactics.active_radius = 0
		game.tactics.ready_at = int(body.get("ready", game.tactics.ready_at))
	game.tactics.recovery_bonus = 0


## The elite's body, with what the game changes on its tactics (position, control, a cancelled wind-up).
func _elite_body() -> Dictionary:
	var body: Dictionary = Elite.state(game)
	var now := CombatClock.now()
	if now == _elite_synced_at:
		return body
	_elite_synced_at = now
	var tactics = game.tactics
	body.pos = tactics.position
	body.rooted_until = tactics.rooted_until
	body.stagger_until = tactics.stagger_until
	body.haste_until = tactics.haste_until
	body.mutations = game.enemy_mutations
	body.engaged = tactics.engaged
	if not tactics.winding_up:
		body.windup = 0
		body.ready = maxi(int(body.get("ready", 0)), int(tactics.ready_at))
	return body


func party_health() -> PackedFloat32Array:
	return sim.party.hp.duplicate()


## Credits the player health lost during one attack release to the mob that released it.
func credit_hits(slot: int, before: PackedFloat32Array) -> void:
	for player in sim.party.count:
		var lost: float = before[player] - _current_health(player)
		if lost > 0.0:
			sim.record_hit(slot, sim.pool.generation[slot], player, lost)


func place(slot: int, at: Vector3) -> void:
	sim.locomotion.world.place_agents(PackedFloat32Array([slot, at.x, at.z, Species.BODY_RADIUS, 1.0]))
	sim.pool.xz[slot * 2] = at.x
	sim.pool.xz[slot * 2 + 1] = at.z
	_written[slot] = at


func tick(now: int, delta: float = 1.0 / 60.0) -> void:
	for slot in capacity:
		_host_owned[slot] = int(_host_turn(slot, delta, now))
	_publish_party()
	_party_evidence = _playstyle_bits()
	var next := sim.clock.tick + 1
	sim.party.attackers.fill(0)
	for slot in capacity:
		_mirror_slot(slot, next, now)
	light.update(sim, next)
	ArenaFields.publish(game, sim, next, now)
	sim.tick()
	if game.participation.active():
		_write_back()


func _current_health(player: int) -> float:
	var peer := _peers[player]
	return PlayerVitals.current_hp(game.players[peer]) if peer != 0 and game.players.has(peer) else 0.0


func _party_slot(peer: int) -> int:
	return _peers.find(peer)


func _publish_party() -> void:
	_peers.fill(0)
	for peer: int in game.players:
		var record: Dictionary = game.players[peer]
		var slot: int = Session.slot_for(record, 0)
		if slot < _peers.size() and Participation.is_wild(record):
			_peers[slot] = peer
	for player in sim.party.count:
		var peer := _peers[player]
		if peer == 0:
			sim.party.clear_player(player)
			continue
		var record: Dictionary = game.players[peer]
		var velocity: Vector3 = game.combat_velocity.get(peer, Vector3.ZERO)
		var health: float = PlayerVitals.current_hp(record) if game.Life.alive(record) else 0.0
		sim.party.set_player(player, Vector2(record.pos.x, record.pos.z), Vector2(velocity.x, velocity.z), health, PlayerVitals.maximum_hp(record))


## The game resolves a hit before the simulation sees it. A dodge restores a hit the mob survived, and a
## channel adds its extra damage, though never the last point of health, which only the game's own hits take
## so its death handling runs.
func _apply_defences(slot: int, health: float) -> float:
	var pool := sim.pool
	var tick := sim.clock.tick
	if tick < pool.dodge_until[slot]:
		sim.damage_mob(slot, pool.hp[slot] - health, _hitters[slot])
		game.encounter.set_hp(game_slot(slot), ceili(pool.hp[slot]))
		return pool.hp[slot]
	if sim.actions.channeling(slot, tick):
		var extra := minf((pool.hp[slot] - health) * (sim.status.channel_damage_taken[pool.species[slot]] - 1.0), health - 1.0)
		if extra >= 1.0:
			health -= game.encounter.apply_damage(game_slot(slot), int(extra), actor_token(slot))
	return health


func _mirror_slot(slot: int, next: int, now: int) -> void:
	var pool := sim.pool
	if not actor_alive(slot):
		if pool.alive[slot] != 0:
			sim.damage_mob(slot, pool.hp[slot], _hitters[slot], false)
		return
	var token: int = actor_token(slot)
	if pool.alive[slot] == 0 or _tokens[slot] != token:
		if pool.alive[slot] != 0:
			sim.damage_mob(slot, pool.hp[slot], NO_HITTER, false)
		if not _adopt(slot, token):
			return
	var scout: Dictionary = actor(slot)
	var health := float(game.encounter.hp(game_slot(slot)))
	if health < pool.hp[slot]:
		health = _apply_defences(slot, health)
	if health < pool.hp[slot]:
		# The game already applied armour and every other defence, so the simulation copies the result unscaled.
		sim.damage_mob(slot, pool.hp[slot] - health, _hitters[slot], false)
	else:
		pool.hp[slot] = health
	if pool.alive[slot] == 0:
		return
	pool.max_hp[slot] = maxf(1.0, float(scout.get("max_hp", health)))
	var floor_number: int = game.participation.floor()
	pool.mutations[slot] = (pool.mutations[slot] & ~UNLOCKS) | _unlocks(int(scout.kind), floor_number, _party_evidence | _denial_bits(scout)) \
		| (Species.UNLOCK_SIGNATURE if slot == leader_slot and floor_number >= ELITE_SIGNATURE_FLOOR else 0)
	var at: Vector3 = scout.pos
	if not at.is_equal_approx(_written[slot]):
		place(slot, at)
	pool.speed[slot] = _speed(scout, now)
	pool.ready_at[slot] = next + _ticks_until(int(scout.ready), now)
	pool.stun_until[slot] = next + _ticks_until(int(scout.get("stagger_until", 0)), now)
	# Flyers cannot be rooted.
	pool.root_until[slot] = 0 if sim.species.layer[pool.species[slot]] != 0 else next + _ticks_until(int(scout.rooted_until), now)
	pool.haste_until[slot] = next + _ticks_until(int(scout.get("haste_until", 0)), now)
	if bool(scout.get("engaged", false)):
		pool.engaged[slot] = 1
	if _host_owned[slot] != 0:
		pool.stun_until[slot] = next + 1
	var winding: bool = int(scout.windup) > 0
	pool.windup_until[slot] = next + maxi(1, _ticks_until(int(scout.windup), now)) if winding else 0
	if winding and pool.aim_player[slot] != Pool.NO_PLAYER:
		sim.party.attackers[pool.aim_player[slot]] += 1
	elif not winding:
		pool.aim_player[slot] = Pool.NO_PLAYER


func _adopt(slot: int, token: int) -> bool:
	var scout: Dictionary = actor(slot)
	var request := Pool.Spawn.new()
	request.species = int(scout.kind)
	request.at = Vector2(scout.pos.x, scout.pos.z)
	request.hp = float(game.encounter.hp(game_slot(slot)))
	if slot == leader_slot:
		request.flags = Pool.FLAG_LEADER | Pool.FLAG_ELITE
	request.damage = float(game.Director.Balance.scout_hit(game, game.Enemies.get_kind(int(scout.kind)), scout))
	request.mutations = int(scout.get("mutations", 0))
	request.intelligence = config.intelligence
	if sim.spawn_at(slot, request) != slot:
		return false
	_tokens[slot] = token
	_hitters[slot] = NO_HITTER
	_written[slot] = scout.pos
	return true


## Runs the game's own thief and feint behaviour. Returns true while it owns the enemy this tick.
func _host_turn(slot: int, delta: float, now: int) -> bool:
	if not actor_alive(slot):
		return false
	var scout: Dictionary = actor(slot)
	var kind := int(scout.get("kind", -1))
	if kind != Thief.KIND and kind != Glasscap.KIND:
		return false
	var owned := EnemyBehaviors.tick(game, scout, delta, now)
	if owned and slot == leader_slot:
		# The game's elite code copies a thief's escape and grab back onto its tactics the same way.
		game.tactics.position = scout.pos
		if int(scout.get("windup", 0)) > 0 and not game.tactics.winding_up:
			game.tactics.winding_up = true
			game.tactics.attack_mode = scout.mode
			game.tactics.strike_at = int(scout.windup)
			game.tactics.landing = scout.attack.to
	return owned


## Signature moves follow the same play-style scores and floors the legacy variants use.
func _playstyle_bits() -> int:
	var bits := 1 << Enums.Evidence.LATE
	var progress = game.progress
	var scores: Dictionary = progress.wilds_memory.get("score", {})
	for entry in [["ranged", Enums.Evidence.RANGED, int(progress.ranged_pressure)], ["choke", Enums.Evidence.CHOKE, int(progress.choke_pressure)],
			["burst", Enums.Evidence.BURST, int(progress.burst_pressure)], ["kite", Enums.Evidence.KITE, 0]]:
		if maxi(int(scores.get(entry[0], 0)), int(entry[2]) * 2) >= PLAYSTYLE_SCORE:
			bits |= 1 << int(entry[1])
	if int(Tactics.evidence(game).get(Tactics.AREA_PRESSURE, 0)) > 0:
		bits |= 1 << Enums.Evidence.AREA_PRESSURE
	return bits


## Learned counters unlock for an enemy once the party has denied that enemy this run.
func _denial_bits(scout: Dictionary) -> int:
	var epoch: int = game.participation.epoch()
	var bits := 0
	if int(scout.get("rite_disrupted_epoch", -1)) == epoch:
		bits |= 1 << Enums.Evidence.CAST_DENIAL
	if int(scout.get("route_denied_epoch", -1)) == epoch:
		bits |= 1 << Enums.Evidence.ROUTE_DENIAL
	if int(scout.get("shelter_break_epoch", -1)) == epoch:
		bits |= 1 << Enums.Evidence.SHELTER_BREAK
	return bits


func _unlocks(kind: int, floor_number: int, evidence: int) -> int:
	var key := kind | (evidence << 8) | (floor_number << 24)
	if not _unlock_cache.has(key):
		_unlock_cache[key] = sim.species.unlock_bits(kind, floor_number, evidence)
	return _unlock_cache[key]


func _speed(scout: Dictionary, now: int) -> float:
	var kind := int(scout.kind)
	if _speed_tick != now:
		_speed_tick = now
		_speed_cache.clear()
	if not _speed_cache.has(kind):
		_speed_cache[kind] = game.Director.speed(game, float(game.Enemies.get_kind(kind).speed))
	var mask := int(scout.get("mutations", 0))
	return float(_speed_cache[kind]) * Frost.motion_scale(scout, now) * (ELITE_PURSUIT if scout.get("gate_elite", false) else 1.0) \
		* (MOBILITY_SPEED if mask & Catalog.MOBILITY else 1.0) * (JUVENILE_SPEED if mask & Catalog.JUVENILE else 1.0)


func _ticks_until(deadline: int, now: int) -> int:
	return ceili(maxi(0, deadline - now) / MS_PER_TICK)


func _write_back() -> void:
	for slot in sim.pool.active:
		var scout: Dictionary = actor(slot)
		if scout.is_empty() or int(scout.windup) > 0 or _host_owned[slot] != 0:
			continue
		var at := Vector3(sim.pool.xz[slot * 2], 0.0, sim.pool.xz[slot * 2 + 1])
		scout.pos = at
		_written[slot] = at
		if sim.pool.engaged[slot] != 0:
			scout.engaged = true
		if slot == leader_slot:
			game.tactics.position = at
			game.tactics.engaged = game.tactics.engaged or sim.pool.engaged[slot] != 0
