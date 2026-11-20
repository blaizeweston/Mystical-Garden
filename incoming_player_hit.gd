extends RefCounted
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const Participation = preload("res://expedition_participation.gd")
## Resolves a host-validated enemy contact. The recipient adapter binds one
## player life and bridges the existing class, affinity and save operations.

const Life = preload("res://expedition_life.gd")
const Lifecycle = preload("res://player_lifecycle.gd")
const Vitals = preload("res://player_vitals.gd")
const Preview = preload("res://combat_balance_preview.gd")
const Transactions = preload("res://game_transaction.gd")
const Wood = preload("res://wood_affinity.gd")
const Omens = preload("res://oracle_omens.gd")
const Journal = preload("res://diagnostic_journal.gd")

enum Outcome { REJECTED, GRACE, BLOCKED, NO_HP_LOSS, DAMAGED, FELL, UNCOMMITTED }


class Contact extends RefCounted:
	var now: int
	var authored_damage: float
	var slow_ms: int
	var origin: Vector3
	var direct: bool

	func _init(at_ms: int, damage: float, slow: int, from: Vector3, direct_attack: bool) -> void:
		now = at_ms
		authored_damage = damage
		slow_ms = slow
		origin = from
		direct = direct_attack


static func resolve_world(world: Node, peer_id: int, target_life: int, now: int,
		damage: float, slow_ms: int = 0, origin: Vector3 = Vector3.INF, direct_attack: bool = true) -> Dictionary:
	var contact := Contact.new(now, damage, slow_ms, origin, direct_attack)
	var recipient := Recipient.new(world, peer_id, target_life)
	return _resolve(contact, recipient.observe(contact), recipient)


static func _resolve(contact: Contact, observation: Dictionary, recipient: Recipient) -> Dictionary:
	if observation.is_empty():
		return Recipient.result(Outcome.REJECTED)
	if observation.within_hit_grace:
		return Recipient.result(Outcome.GRACE)
	if observation.guarded:
		recipient.consume_guard(contact)
		return Recipient.result(Outcome.BLOCKED)

	var points := float(observation.default_damage) if contact.authored_damage < 0.0 \
		else Preview.authored_amount(contact.authored_damage)
	var hp := Preview.effect_hp(points)
	var bark: Dictionary = {}
	hp = recipient.modify_affinity_damage(contact,hp)
	bark = recipient.plan_bark(hp)
	hp -= int(bark.get("absorbed",0))
	return recipient.commit_contact(contact, hp, bark, int(observation.epoch))


## Raw HP loss shares the vitals/persistence commit. It carries no enemy
## defense, hit grace, Slow or retaliation, including outside the Wilds.
static func apply_health_loss(world: Node, peer_id: int, target_life: int, amount: int) -> Dictionary:
	return Recipient.new(world, peer_id, target_life).apply_health_loss(amount)


## The adapter is scoped to one recipient. Only value observations and outcomes
## cross the resolver boundary. World-dependent effects remain with their owners.
class Recipient extends RefCounted:
	var _world: Node
	var _peer: int
	var _life: int
	var _actor: Dictionary

	func _init(world: Node, peer: int, target_life: int) -> void:
		_world = world
		_peer = peer
		_life = target_life
		_actor = world.players.get(peer, {})

	static func result(kind: int, applied_hp: int = 0, damage_recorded: bool = false) -> Dictionary:
		return {"kind": kind, "applied_hp": applied_hp, "damage_recorded": damage_recorded}

	func _is_current() -> bool:
		return _world.multiplayer.is_server() and Lifecycle.matches(_actor, _life) \
			and is_same(_actor, _world.players.get(_peer, {}))

	func observe(contact: Contact) -> Dictionary:
		if not _is_current() or not Life.alive(_actor) or not _world.persistence_session.can_write():
			return {}
		var observation := {
			"within_hit_grace": _actor[Conditions.STATE].grace_active(contact.now),
			"guarded": _actor[Protection.STATE].allows_block(_actor.pos, contact.origin, contact.now),
			"default_damage": float(1 + _world.participation.cycle() / 2),
			"epoch": int(_world.participation.epoch()),
		}
		observation.make_read_only()
		return observation

	func consume_guard(contact: Contact) -> void:
		var consumed: Protection.Block = _actor[Protection.STATE].consume_block(contact.now, _world.participation.epoch(), _peer)
		_actor[Protection.STATE] = consumed.next_state
		var block_event := preload("res://ward_responses.gd").block(_world, consumed, _peer, _actor.pos, contact.now)
		var stats: Dictionary = _world.weapon_stats(_actor)
		if float(stats.get("counter_damage",0)) > 0 or _actor[Protection.STATE].counter_guard_active(contact.now):
			var balance = preload("res://class_skill_balance.gd")
			_actor[Protection.STATE] = _actor[Protection.STATE].prepare_counter(contact.now + balance.COUNTER_WINDOW_MS, balance.counter_points(stats))
		if block_event != null:
			preload("res://warden_combat.gd").connected_block(_world, block_event, _peer, contact.now)
			preload("res://oracle_combat.gd").ward_blocked(_world, _actor, _peer, block_event, contact.direct)
		_actor.contributed = true
		_world.emit_combat_event("impact", "block", _actor.pos, _actor.pos, .85, Color("#f1d989"), 0, _peer)
		_world.tell(_peer, "Guard blocked the attack.")

	func modify_affinity_damage(contact: Contact, hp: int) -> int:
		var adjusted := preload("res://water_combat.gd").direct_damage(_world, hp)
		if contact.direct:
			adjusted = preload("res://warden_combat.gd").direct_damage(_world, _actor, adjusted, contact.now)
		return adjusted

	func plan_bark(hp: int) -> Dictionary:
		return Wood.absorption_plan(_actor, hp, preload("res://affinity_time.gd").now(_world))

	func commit_contact(contact: Contact, hp: int, bark: Dictionary, epoch: int) -> Dictionary:
		if not _is_current() or not _world.persistence_session.can_write():
			return result(Outcome.REJECTED)
		if _world.persistence_session.is_guarded() and hp >= int(Vitals.current_hp(_actor)):
			return _guarded_loss(func(effects) -> Dictionary:
				_prepare_contact(contact, bark, effects)
				var resolution := _install_loss(hp, effects)
				if not bark.is_empty():
					effects.append(Wood.after_hit.bind(_world, _peer, epoch, bark, contact.now))
				return resolution)
		_prepare_contact(contact, bark, null)
		var before_hp := Vitals.current_hp(_actor)
		var resolution := apply_health_loss(hp)
		if Life.alive(_actor) and Vitals.current_hp(_actor) < before_hp:
			if _actor.has(Omens.STATE) and Omens.direct_context(_world, contact.direct):
				Omens.recover_hit(_world, _actor, contact.now)
			preload("res://frost_combat.gd").incoming(_world, _actor, _peer, contact.now)
			preload("res://fire_combat.gd").incoming(_world, _actor, _peer, contact.now)
		Wood.after_hit(_world, _peer, epoch, bark, contact.now)
		return resolution

	func _prepare_contact(contact: Contact, bark: Dictionary, effects) -> void:
		Wood.consume(_actor, bark)
		var conditions: Conditions.State = _actor[Conditions.STATE]
		var prevented := conditions.slow_needs_prevention(contact.now, contact.slow_ms) \
			and _actor.has(Omens.STATE) and Omens.prevent_slow(_world, _actor, contact.now)
		var grace_ms := int(preload("res://game_balance.gd").values.combat.hit_grace_ms)
		var update := conditions.after_hit(contact.now, contact.slow_ms, grace_ms, prevented)
		_actor[Conditions.STATE] = update.next_state
		if update.slow_applied: _world.action_feedback(effects, _peer, "Slowed.")

	func apply_health_loss(amount: int) -> Dictionary:
		if not _is_current() or not _world.persistence_session.can_write():
			return result(Outcome.REJECTED)
		if _world.persistence_session.is_guarded():
			if amount < int(Vitals.current_hp(_actor)):
				return _install_loss(amount)
			return _guarded_loss(func(effects) -> Dictionary: return _install_loss(amount, effects))
		# Legacy applies contact status before opening its HP transaction.
		var saved: Variant = Transactions.run(_world, func() -> Dictionary: return _install_loss(amount))
		return saved if saved is Dictionary else result(Outcome.UNCOMMITTED)

	func _guarded_loss(action: Callable) -> Dictionary:
		var saved: Dictionary = _world.run_guarded_action(_peer, Transactions.Scope.PAIR, action)
		if Transactions.committed(saved.persistence) and saved.value is Dictionary:
			return saved.value
		return result(Outcome.UNCOMMITTED)

	func _install_loss(amount: int, effects = null) -> Dictionary:
		if not _is_current() or (Participation.is_wild(_actor) and not Life.alive(_actor)):
			return result(Outcome.REJECTED)
		var loss := Vitals.apply_damage(_actor, amount, false)
		if loss.is_empty():
			return result(Outcome.REJECTED)
		if not loss.recorded:
			return result(Outcome.NO_HP_LOSS)
		var applied: int = loss.applied_hp
		var in_wilds: bool = Participation.is_wild(_actor)
		_actor.damage_seq = int(_actor.get("damage_seq", 0)) + 1
		_actor.damage_amount = applied
		var record := {"actor": _peer, "amount": amount, "applied_hp": applied, "hp": int(loss.hp),
			"damage_seq": _actor.damage_seq, "vitals_revision": _world.replication.health_revision(_peer), "hp_per_point": Preview.scale()}
		if effects == null:
			Journal.event("combat", "damage_applied", record)
		else:
			effects.append(func(): Journal.event("combat", "damage_applied", record))
		if in_wilds and applied > 0:
			_world.emit_combat_event("impact", "hurt", _actor.pos, _actor.pos, .85, Color("#ff957d"), float(applied), _peer)
		if float(loss.hp) > 0.0:
			return result(Outcome.DAMAGED if applied > 0 else Outcome.NO_HP_LOSS, applied, true)
		if in_wilds:
			Life.down(_world, _peer, _actor, effects)
		else:
			if effects != null:
				_world.settle_expedition_rewards(effects)
			_world.expedition_transitions.return_member(preload("res://network_session.gd").peer_for(_actor))
		return result(Outcome.FELL, applied, true)
