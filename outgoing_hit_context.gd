extends RefCounted
## A short-lived integration port for one source life, floor and roster.
## Existing owners keep HP, tactics, statuses, rewards and acquisitions.
## Returned facts are detached; no public method returns an actor or service.

const Lifecycle = preload("res://player_lifecycle.gd")
const Life = preload("res://expedition_life.gd")
const Motion = preload("res://weapon_motion.gd")

# Immutable script resources, loaded lazily to break recursive proc preloads.
# They never store a world, actor, target or any mutable combat state.
static var _grafts: Script
static var _shelter: Script
static var _variants: Script

var _world: Node
var _actor: Dictionary
var _identity: String
var _peer: int
var _life: int
var _epoch: int
var _roster: RefCounted
var _departed_affinity: bool
var _bloom := {}


func _init(world: Node, peer: int, accepted_affinity := false) -> void:
	_world = world
	_peer = peer
	_identity = world.expedition_stat_identity(peer)
	_actor = world.players.get(peer, {})
	_departed_affinity = accepted_affinity and _actor.is_empty()
	_life = Lifecycle.generation(_actor)
	_epoch = world.participation.epoch()
	_roster = world.encounter
	if _grafts == null: _grafts = load("res://native_grafts.gd")


func is_current() -> bool:
	if not is_instance_valid(_world) or not _world.multiplayer.is_server() or _world.participation.epoch() != _epoch or not is_same(_world.encounter, _roster): return false
	if _departed_affinity: return not _world.players.has(_peer)
	return Lifecycle.matches(_actor, _life) and is_same(_actor, _world.players.get(_peer, {}))


func observe_contact(target: int) -> void:
	_world.outgoing_contact_requested.emit(_peer, target)

func permits_contact(stats: Dictionary) -> bool:
	return not _departed_affinity or (stats.get("trait_secondary", false) and stats.get("core_hit", false) and stats.has("affinity_hp"))


func capture_target(target: int) -> int:
	return _roster.spawn_identity(target) if is_current() and _roster.alive(target) else -1


func capture_targets(targets: Array[int]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for target in targets: result.append({"target":target, "token":capture_target(target)})
	return result


func target_is_current(target: int, token: int) -> bool:
	return is_current() and token >= 0 and _roster.spawn_identity(target) == token and _roster.alive(target, token)


func target_position(target: int) -> Vector3:
	return _world.enemy_position(target)


func position() -> Vector3:
	return _actor.get("pos", Vector3.ZERO)


func begin_contact(target: int, stats: Dictionary, now: int) -> Dictionary:
	if _departed_affinity: return {"stats":stats, "graft":{}}
	_actor.contributed = true
	var graft: Dictionary = _grafts.start_contact(_world, _actor, stats, target, now)
	if not stats.get("core_hit", false) and not stats.get("oracle_spell", false) and not stats.get("spirit_replica",false):
		stats = _world.Traits.augment_hit(_world, _actor, target, stats, now, graft)
	var event: RefCounted = stats.get("cr02_action")
	if event != null and event.source in ["form","native_weapon"] and not stats.get("trait_secondary",false) and not stats.get("core_hit",false):
		var bonus: int = load("res://thorn_affinity.gd").ordinary_bonus(event,stats)
		bonus += load("res://frost_combat.gd").ordinary_bonus(_world,event,target,now)
		bonus += load("res://water_combat.gd").ordinary_bonus(_world,event,target)
		bonus += load("res://vital_combat.gd").ordinary_bonus(event,stats)
		bonus += load("res://spirit_affinity.gd").ordinary_bonus(event,stats)
		bonus += load("res://void_affinity.gd").ordinary_bonus(_world,event,target)
		if bonus > 0:
			stats = stats.duplicate()
			stats.native_bonus_hp = int(stats.get("native_bonus_hp",0)) + bonus
	return {"stats":stats, "graft":graft}


func target_facts(target: int, stats: Dictionary, origin: Vector3, now: int) -> Dictionary:
	var leader := target == -1
	var body: Dictionary = _roster.leader_tactics() if leader else _roster.scout(target)
	var mutations: int = _world.enemy_mutations if leader else int(body.get("mutations", 0))
	var bark_guard: bool = body.get("variant", "") == "bark_guard"
	var guards := false
	if bark_guard:
		if _variants == null: _variants = load("res://enemy_variants.gd")
		guards = _variants.guards(body, origin, now)
	var facts := {"point":target_position(target), "facing":_actor.get("facing", Vector3.FORWARD),
		"winding":bool(stats.get("was_winding", _world.tactics.winding_up if leader else float(body.windup) > 0)),
		"boss":leader and _world.tactics.boss_kind >= 0,
		"guardian":leader and _world.participation.depth() == _world.ROUTE_ROOMS,
		"bark_guard":bark_guard, "guards":guards,
		"bark":bool(mutations & _world.Enemies.BARK), "exposed":leader and _world.Bosses.exposed(_world, now)}
	facts.make_read_only()
	return facts


func graft_bonus(contact: Dictionary, now: int) -> float:
	return _grafts.bonus(_world, _actor, contact, now)


func punish(origin: Vector3, point: Vector3, target: int) -> void:
	load("res://combat_status.gd").proc(_world, "punish", origin, point, target)


func consume_prey(target: int, now: int) -> int:
	return load("res://ranger_combat.gd").consume_prey(_world, _actor, target, now)


func sheltered(target: int, point: Vector3, origin: Vector3, now: int) -> bool:
	if _shelter == null: _shelter = load("res://enemy_support.gd")
	return not _shelter.shelter_source(_world, target, point, origin, now).is_empty()


func exposed_bonus(damage: int) -> int:
	return _world.Director.Balance.exposed_bonus(damage)


func movement_endpoint(from: Vector3, to: Vector3) -> Vector3:
	return _world.battlefield.dash(from, to)


func enemy_hp(target: int) -> int:
	return _roster.hp(target)


func alert(point: Vector3, damage: int) -> void:
	if not _departed_affinity:
		_world.combat_threat[_peer] = float(_world.combat_threat.get(_peer, 0)) + Life.Vitals.threat_from_hit(damage, Life.Preview.scale())
	_world.Director.alert(_world, point)


func record_pressure(point: Vector3, damage: int, before: int, applied: int) -> void:
	if Life.Vitals.counts_as_burst(damage, Life.Preview.scale()): _world.burst_hits_this_room += 1
	if before <= applied and _world.battlefield.floor_distance(point) < 1.6: _world.choke_kills_this_room += 1


## Install already-resolved damage through the roster, then preserve each native
## interrupt/telegraph rule. Specialist decisions remain with their handlers.
func install_hit(target: int, token: int, point: Vector3, applied: int, recovery: int,
		stagger: int, winding: bool, stats: Dictionary, now: int, interrupt_threshold: int) -> Vector3:
	if target == -1:
		if _world.tactics.winding_up and _world.Bosses.owns_warnings(_world.tactics.boss_kind): point = _world.tactics.position
		_world.tactics.position = point
		_world.tactics.engaged = true
		_roster.apply_damage(-1, applied, token)
		_world.tactics.recovery_bonus = maxi(_world.tactics.recovery_bonus, recovery)
		if winding and enemy_hp(-1) > 0 and _world.tactics.boss_kind == 22 and float(stats.get("stagger", 0)) >= interrupt_threshold:
			load("res://boss_phase_fights.gd").interrupt(_world, point, now)
		if winding and _world.tactics.boss_kind < 0 and not _roster.leader_tactics().is_empty() and float(stats.get("stagger", 0)) >= interrupt_threshold and _world.EnemyBehaviors.interrupt(_world, _roster.leader_tactics(), point, now):
			_world.tactics.ready_at = _roster.leader_tactics().ready
			_world.tactics.winding_up = false
			winding = false
		if not winding and not stats.has("affinity_hp"): _world.tactics.stagger_until = stagger
		if enemy_hp(-1) == 0: _world.tactics.winding_up = false
	else:
		var scout: Dictionary = _roster.scout(target)
		scout.pos = point
		scout.engaged = true
		_roster.apply_damage(target, applied, token)
		scout.recovery = maxi(int(scout.recovery), recovery)
		if winding and float(stats.get("stagger", 0)) >= interrupt_threshold and _world.EnemyBehaviors.interrupt(_world, scout, point, now): winding = false
		if not winding and not stats.has("affinity_hp"): scout.stagger_until = stagger
	return point


func finish_contact(target: int, token: int, origin: Vector3, point: Vector3, contact_point: Vector3,
		stats: Dictionary, graft: Dictionary, now: int, before: int, applied: int) -> void:
	var attribution: Dictionary = stats.get("stat_weights",{_identity:1})
	_world.expedition_statistics.damage(_world.participation.run_id(),applied,attribution,stats.get("stat_affinity",""))
	if stats.get("rite_suppressed", false) and applied < before:
		var body: Dictionary = _roster.scout(target) if target >= 0 else _roster.leader_tactics()
		load("res://wilds_skill_tactics.gd").interrupted(_world, body, "suppression")
	if applied > 0:
		if int(_actor.get("frame", -1)) == 4 or _actor.has("oracle_omens"):
			load("res://oracle_combat.gd").ordinary_contact(_world, _actor, target, contact_point, stats, now)
		var form := "magic" if stats.get("trait_secondary", false) else str(stats.get("audio_form", Motion.form(_actor)))
		_world.emit_combat_event("impact", "hit", origin, point, .85, stats.get("affinity_color", _world.weapon_effect_color(_actor)), float(applied), target, {"form":form})
	if _roster.death_pending(target, token):
		load("res://thorn_affinity.gd").on_death(_world, target, now, stats.get("card_secondary",false))
		_world.record_enemy_death(target, point, origin, token, _identity)
		Life.Sustain.heal_on_kill(_world, _actor, target, Life.Preview.authored_amount(float(stats.get("heal_on_kill", 0))))
	_world.Traits.after_hit(_world, _actor, target, stats, now, before > 0 and applied >= before)
	if not graft.is_empty() and applied > 0:
		_grafts.finish_contact(_world, _actor, target, stats, graft, now, before > 0 and applied >= before)


func record_damage(applied: int, shot_distance: float) -> void:
	_world.damage_this_room += applied
	if shot_distance >= _world.RANGED_DISTANCE:
		_world.ranged_damage_this_room += applied
		if not _departed_affinity and _world.combat_velocity.get(_peer, Vector3.ZERO).length() > .8: _world.moving_ranged_hits += 1


func begin_bloom(skill: Dictionary, now: int) -> bool:
	_bloom = load("res://affinity_cards.gd").bloom_echo_source(_world, _actor, skill, now)
	return not _bloom.is_empty()


func extend_control(target: int, root_until: int, recovery: int) -> void:
	if target == -1:
		if root_until > 0: _world.tactics.extend_root(root_until)
		if recovery > 0: _world.tactics.recovery_bonus = maxi(_world.tactics.recovery_bonus, recovery)
	else:
		var body: Dictionary = _roster.scout(target)
		if root_until > 0: body.rooted_until = maxi(int(body.get("rooted_until", 0)), root_until)
		if recovery > 0: body.recovery = maxi(int(body.get("recovery", 0)), recovery)


func tag_reaper_hit(stats: Dictionary, nodes: Array) -> void:
	load("res://reaper_combat.gd").tag_hit(stats, nodes)


func inside_bloom(target: int) -> bool:
	return load("res://affinity_cards.gd").bloom_contains(_world, _bloom, target)


func drain_eligible(target: int) -> bool:
	return Life.Sustain.eligible(_world, target)


func release_bloom(skill: Dictionary, now: int) -> void:
	load("res://affinity_cards.gd").bloom_echo(_world, _actor, _bloom, skill, now)
