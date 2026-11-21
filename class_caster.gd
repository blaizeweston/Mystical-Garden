extends RefCounted
const OutgoingHits = preload("res://outgoing_hits.gd")
## Integration port for exactly one captured caster life and world generation.
## No public operation returns a mutable actor/profile or an owner service.
## This is not another player owner; existing owners remain authoritative.

const Lifecycle = preload("res://player_lifecycle.gd")
const Life = preload("res://expedition_life.gd")
const Cooldowns = preload("res://player_cooldowns.gd")
const Protection = preload("res://player_protection.gd")
const WeaponActions = preload("res://player_weapon_actions.gd")
const WeaponMotion = preload("res://weapon_motion.gd")
const Skills = preload("res://skill_catalog.gd")
const Classes = preload("res://class_catalog.gd")
const Events = preload("res://combat_action_events.gd")
const Targeting = preload("res://class_ability_targeting.gd")
const Warden = preload("res://warden_combat.gd")
const Weaver = preload("res://weaver_combat.gd")
const Ranger = preload("res://ranger_combat.gd")
const Reaper = preload("res://reaper_combat.gd")
const Oracle = preload("res://oracle_combat.gd")
const Focus = preload("res://subclass_combat.gd")

var _world: Node
var _peer: int
var _actor: Dictionary
var _life: int
var _epoch: int
# These are the handlers' per-cast results, not additional persistent state.
var _snare := {}
var _siphon := {}
var _chime := {}


func _init(world: Node, peer: int) -> void:
	_world = world
	_peer = peer
	_actor = world.players.get(peer, {})
	_life = Lifecycle.generation(_actor)
	_epoch = world.participation.epoch()


func peer_id() -> int:
	return _peer


func is_current() -> bool:
	return _world.multiplayer.is_server() and _epoch == _world.participation.epoch() \
		and Lifecycle.matches(_actor, _life) and is_same(_actor, _world.players.get(_peer, {}))


func record_request(slot: int) -> void:
	preload("res://diagnostic_journal.gd").event("combat", "skill_requested", {"actor":_peer, "slot":slot,
		"state":preload("res://diagnostic_journal.gd").player_state(_actor,_world.replication.health_revision(_peer))})


func observe(slot: int, now: int) -> Dictionary:
	if not is_current(): return {}
	var facts := {"alive":Life.alive(_actor), "cleared":_world.encounter_cleared(),
		"ready":_actor[Cooldowns.STATE].ready(slot, now), "core_cast_until":int(_actor.get("core_cast_until", 0)),
		"position":Vector3(_actor.pos), "aimed":_actor.has("class_aim"),
		"weapon_reach":float(Classes.DEFINITIONS[int(_actor.frame)].weapons[int(_actor.weapon_kind)].reach)}
	facts.make_read_only()
	return facts


func resolved_stats() -> Dictionary:
	return _world.weapon_stats(_actor).duplicate(true)


func native_skill(slot: int) -> Dictionary:
	return Skills.resolve(int(_actor.frame), slot, _actor.character).duplicate(true)


func resolved_class_skill(slot: int) -> Dictionary:
	return _world.combat_build(_actor).class_skill(slot)


func begin_event(adapter: Dictionary, now: int, catalyst: Dictionary) -> RefCounted:
	return Events.class_start(_world, _peer, adapter, now, catalyst)


func cast_focus(skill: Dictionary, stats: Dictionary, now: int) -> void:
	Focus.cast_skill(_world, _peer, _actor, skill, stats, now)


func target_plan(skill: Dictionary, stats: Dictionary, reach: float) -> Dictionary:
	if _actor.has("class_aim"):
		var plan := Targeting.plan(_world, _actor, _world.battlefield, skill, stats, _actor.class_aim, float(_actor.get("class_aim_distance", -1)))
		if plan.valid:
			_actor.facing = plan.forward
			_actor.aim_direction = plan.forward
		return plan
	var target := Targeting.automatic(_world, _actor, reach + float(skill.get("travel", 0)))
	return {"valid":true, "target":target, "point":_world.enemy_position(target) if target != -2 else Vector3(_actor.pos),
		"reach":reach, "forward":Vector3(_actor.facing)}


func ally_facts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for peer in _world.players:
		var ally: Dictionary = _world.players[peer]
		var facts := {"id":int(peer), "position":Vector3(ally.pos), "alive":Life.alive(ally), "is_self":is_same(ally, _actor)}
		facts.make_read_only()
		result.append(facts)
	return result


func clear_line(origin: Vector3, destination: Vector3) -> bool:
	return _world.battlefield.clear_line(origin, destination)


func grant_ward(recipient: int, until: int, charges: int, event: RefCounted, adapter: Dictionary, now: int) -> void:
	Events.grant_ward(_world, _world.players[recipient], until, charges, event, adapter, now)


func set_guard(mode: String, until: int, facing: Vector3) -> void:
	var guard: Protection.State = _actor[Protection.STATE]
	_actor[Protection.STATE] = guard.with_front_guard(until, facing) if mode == "front_guard" else guard.with_counter_guard(until)


func ground_endpoint(destination: Vector3) -> Vector3:
	return _world.battlefield.dash(_actor.pos, destination)


func ground_occupied(point: Vector3) -> bool:
	return _world.battlefield.occupied(point)


func place_snare(center: Vector3, skill: Dictionary, stats: Dictionary, now: int) -> bool:
	_snare = preload("res://combat_traits.gd").place_snare(_world, _actor, center, skill, stats, now)
	return not _snare.is_empty()


func quake_center(skill: Dictionary, now: int) -> Vector3:
	return Warden.quake_center(_world, _actor, _world.battlefield, skill, now)


func area_targets(center: Vector3, radius: float) -> Array[int]:
	return _world.skill_area_targets(center, radius, center)


func begin_siphon(skill: Dictionary, target: int, point: Vector3, now: int) -> bool:
	_siphon = Reaper.begin_siphon(_world, _peer, _actor, skill, target, point, now)
	return not _siphon.is_empty()


func siphon_damaged(target: int) -> bool:
	return Reaper.enemy_hp(_world, target) < int(_siphon.before)


func begin_chime(skill: Dictionary, event: RefCounted, now: int) -> Dictionary:
	_chime = Oracle.begin_chime(_world, _actor, skill, event, now)
	return _chime.duplicate(true)


func notify_movement(origin: Vector3) -> void:
	if _actor.has("affinity_spirit_follow") and _actor.pos != origin:
		preload("res://spirit_affinity.gd").movement(_world, _actor, origin, _actor.pos)


func prepare_nova(skill: Dictionary, targets: Array[int], center: Vector3, now: int) -> Vector3:
	return Weaver.prepare_nova(_world, _peer, _actor, skill, targets, center, now)


func prepare_impact(skill: Dictionary, now: int) -> void:
	_actor[WeaponActions.STATE] = _actor[WeaponActions.STATE].swing_until(now + WeaponMotion.DEFAULT_POSE_MS)
	if skill.mode == "quake" and skill.has("warden_focus"): Warden.prepare_quake_damage(_world, _actor, skill, now)


func apply_targets(targets: Array[int], skill: Dictionary, stats: Dictionary, now: int) -> int:
	return OutgoingHits.skill_world(_world, _peer, targets, skill, stats, now)


func warden_cast(skill: Dictionary, until: int, now: int, event: RefCounted) -> void:
	Warden.on_cast(_world, _actor, skill, until, now, event)


func quake_hit(center: Vector3, targets: Array[int], radius: float, now: int) -> void:
	Warden.consume_anchor(_world, _actor, center, now)
	Warden.quake_hit(_world, _actor, center, targets, radius, now)


func drain(amount: float, mode: String) -> void:
	Life.Sustain.heal(_world, _actor, amount, mode, Life.Preview.HEAL_DRAIN_SPREAD_HP)


func commit_cooldown(slot: int, now: int, duration: int, bonus_heal: float) -> void:
	_actor.contributed = true
	if bonus_heal > 0: Life.Sustain.heal(_world, _actor, bonus_heal, "class_healing_bonus")
	_actor[Cooldowns.STATE] = _actor[Cooldowns.STATE].start(slot, now, duration)


func finish_snare(origin: Vector3, now: int) -> String:
	var message:=Ranger.finish_snare(_world, _actor, _snare, origin, now)
	_world.effect_timeline.update_native(_snare)
	return message


func complete_event(event: RefCounted, adapter: Dictionary, origin: Vector3, center: Vector3,
		targets: Array, recipients: Array, now: int, radius: float) -> void:
	Events.class_complete(_world, event, adapter, origin, center, targets, recipients, now, radius)


func finish_siphon(skill: Dictionary, target: int, center: Vector3, damaged: bool, now: int) -> void:
	Reaper.finish_siphon(_world, _actor, skill, target, center, _siphon, damaged, now)


func finish_chime(skill: Dictionary, now: int) -> void:
	Oracle.finish_chime(_world, _peer, _actor, skill, _chime, now)


func follow_through(skill: Dictionary, center: Vector3, targets: Array[int], now: int) -> void:
	Focus.follow_through(_world, _actor, skill, center, targets, now)


func complete_nova(nodes: Array, center: Vector3, impact: Vector3, now: int) -> void:
	Weaver.complete_nova(_world, _peer, _actor, nodes, center, impact, now)


func publish(skill: Dictionary, origin: Vector3, center: Vector3, radius: float, now: int, feedback: String) -> void:
	load("res://spirit_replicas.gd").class_cast(_world,_peer,skill,origin,center,radius,now)
	load("res://spirit_affinity.gd").voluntary(_world,_peer,origin,_actor.pos,now)
	_actor.skill_fx_seq = int(_actor.get("skill_fx_seq", 0)) + 1
	_actor.skill_fx_until = now + 650
	_actor.skill_fx = {"seq":_actor.skill_fx_seq, "pos":center, "radius":maxf(.8, radius), "color":skill.color, "event_driven":true}
	_actor.cast_until = now + 550
	_world.emit_combat_event("ability", str(skill.mode), origin, center, .8, Color(skill.color), maxf(.8, radius), _peer)
	preload("res://event_audio.gd").emit(_world, "combat_cast", origin)
	tell("%s used." % skill.name if feedback.is_empty() else feedback)


func tell(message: String) -> void:
	_world.tell(_peer, message)


func finish_if_cleared(targets: Array[int], center: Vector3) -> void:
	if _world.encounter_cleared():
		_world.finish_combat(_peer, _world.enemy_position(targets.back()) if not targets.is_empty() else center)
