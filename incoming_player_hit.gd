extends RefCounted
## Resolves a host-validated enemy contact. The recipient adapter binds one
## player life and bridges the existing class, affinity and save operations.

const Life = preload("res://expedition_life.gd")
const Lifecycle = preload("res://player_lifecycle.gd")
const Vitals = preload("res://player_vitals.gd")
const Preview = preload("res://combat_balance_preview.gd")
const Transactions = preload("res://game_transaction.gd")
const Traits = preload("res://combat_traits.gd")
const Wood = preload("res://wood_affinity.gd")
const Omens = preload("res://oracle_omens.gd")
const Journal = preload("res://diagnostic_journal.gd")

enum Outcome { REJECTED, GRACE, BLOCKED, BRACED, NO_HP_LOSS, DAMAGED, FELL, UNCOMMITTED }


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
	if contact.now < int(observation.hurt_until):
		return Recipient.result(Outcome.GRACE)
	if observation.guarded:
		recipient.consume_guard(contact)
		return Recipient.result(Outcome.BLOCKED)
	if recipient.try_brace(contact.now):
		return Recipient.result(Outcome.BRACED)

	var points := float(observation.default_damage) if contact.authored_damage < 0.0 \
		else Preview.authored_amount(contact.authored_damage)
	var hp := Preview.effect_hp(points)
	var bark: Dictionary = {}
	if observation.affinity:
		hp = recipient.modify_affinity_damage(contact, hp)
		bark = recipient.plan_bark(hp)
		hp -= int(bark.get("absorbed", 0))
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
		if not _is_current() or not Life.alive(_actor) or not Transactions.session_writable(_world):
			return {}
		var observation := {
			"hurt_until": int(_actor.get("hurt_until", 0)),
			"guarded": Traits.guard_allows(_actor, contact.origin, contact.now),
			"default_damage": float(1 + _world.difficulty_cycle / 2),
			"affinity": _world.has_meta(&"combat_affinity_ruleset"),
			"epoch": int(_world.combat_epoch),
		}
		observation.make_read_only()
		return observation

	func consume_guard(contact: Contact) -> void:
		var recorded_ward := _world.has_meta(&"combat_affinity_ruleset") and int(_actor.get("guard_charges", 0)) > 0
		_actor.guard_charges = maxi(0, int(_actor.get("guard_charges", 1)) - 1)
		if _actor.guard_charges == 0:
			_actor.guard_until = 0
		var block_event: RefCounted
		if recorded_ward:
			block_event = preload("res://combat_action_events.gd").blocked(_world, _peer, _actor, contact.now)
		preload("res://core_skill_effects.gd").ironbark_block(_world, _peer, _actor, contact.now)
		Traits.blocked(_world, _actor, contact.now)
		if block_event != null:
			preload("res://warden_combat.gd").connected_block(_world, block_event, _peer, contact.now)
			preload("res://oracle_combat.gd").ward_blocked(_world, _actor, _peer, block_event, contact.direct)
		_actor.contributed = true
		_world.emit_combat_event("impact", "block", _actor.pos, _actor.pos, .85, Color("#f1d989"), 0, _peer)
		_world.tell(_peer, "Guard blocked the attack.")

	func try_brace(now: int) -> bool:
		return Traits.try_brace(_world, _actor, now)

	func modify_affinity_damage(contact: Contact, hp: int) -> int:
		var adjusted := preload("res://water_combat.gd").direct_damage(_world, hp)
		if contact.direct:
			adjusted = preload("res://warden_combat.gd").direct_damage(_world, _actor, adjusted, contact.now)
		return adjusted

	func plan_bark(hp: int) -> Dictionary:
		return Wood.absorption_plan(_actor, hp, preload("res://affinity_time.gd").now(_world))

	func commit_contact(contact: Contact, hp: int, bark: Dictionary, epoch: int) -> Dictionary:
		if not _is_current() or not Transactions.session_writable(_world):
			return result(Outcome.REJECTED)
		if _world.has_meta(Transactions.SESSION) and hp >= int(Vitals.current_hp(_actor)):
			return _guarded_loss(func(effects) -> Dictionary:
				_prepare_contact(contact, bark, effects)
				var resolution := _install_loss(hp, effects)
				if not bark.is_empty():
					effects.append(Wood.after_hit.bind(_world, _peer, epoch, bark, contact.now))
				return resolution)
		_prepare_contact(contact, bark, null)
		var before_hp := Vitals.current_hp(_actor)
		var resolution := apply_health_loss(hp)
		if _world.has_meta(&"combat_affinity_ruleset") and Life.alive(_actor) and Vitals.current_hp(_actor) < before_hp:
			if _actor.has(Omens.STATE) and Omens.direct_context(_world, contact.direct):
				Omens.recover_hit(_world, _actor, contact.now)
			preload("res://frost_combat.gd").incoming(_world, _actor, _peer, contact.now)
			preload("res://fire_combat.gd").incoming(_world, _actor, _peer, contact.now)
		Wood.after_hit(_world, _peer, epoch, bark, contact.now)
		return resolution

	func _prepare_contact(contact: Contact, bark: Dictionary, effects) -> void:
		Wood.consume(_actor, bark)
		var grace_ms := int(preload("res://combat_director.gd").config().hit_grace_ms)
		preload("res://combat_status.gd").incoming_grace(_actor, contact.now, contact.slow_ms, grace_ms,
			func() -> bool: return _actor.has(Omens.STATE) and Omens.prevent_slow(_world, _actor, contact.now),
			func() -> void: _world.action_feedback(effects, _peer, "Slowed."))

	func apply_health_loss(amount: int) -> Dictionary:
		if not _is_current() or not Transactions.session_writable(_world):
			return result(Outcome.REJECTED)
		if _world.has_meta(Transactions.SESSION):
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
		if not _is_current() or (_actor.get("wild", false) and not Life.alive(_actor)):
			return result(Outcome.REJECTED)
		var loss := Vitals.apply_damage(_actor, amount, not Preview.enabled)
		if loss.is_empty():
			return result(Outcome.REJECTED)
		if not loss.recorded:
			return result(Outcome.NO_HP_LOSS)
		var applied: int = loss.applied_hp
		var in_wilds: bool = _actor.get("wild", false)
		_actor.damage_seq = int(_actor.get("damage_seq", 0)) + 1
		_actor.damage_amount = applied if Preview.enabled else maxi(0, amount)
		var record := {"actor": _peer, "amount": amount, "applied_hp": applied, "hp": int(loss.hp),
			"damage_seq": _actor.damage_seq, "vitals_revision": _actor.get("vitals_revision", 0), "hp_per_point": Preview.scale()}
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
			_world.return_to_garden(_actor)
		return result(Outcome.FELL, applied, true)
