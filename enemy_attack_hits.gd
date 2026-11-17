extends RefCounted
## Resolves enemy contact geometry from detached target positions. The world
## adapter validates each contact before the existing player defense resolver.

const Geometry = preload("res://attack_geometry.gd")
const Life = preload("res://expedition_life.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const CONTACT_PADDING := 0.35


class HitWindow extends RefCounted:
	var _field: RefCounted
	var _observe: Callable
	var _deliver: Callable
	var _current_source: Callable

	func _init(field: RefCounted, observe: Callable, deliver: Callable, current_source: Callable) -> void:
		_field = field
		_observe = observe
		_deliver = deliver
		_current_source = current_source

	func source_is_current() -> bool:
		return bool(_current_source.call())

	func area(center: Vector3, radius: float, now: int, damage: float = -1.0,
			slow_ms: int = 0, direct_attack: bool = true, ranged_impact: bool = false) -> void:
		var targets: Array[Dictionary] = _observe.call()
		for target in targets:
			var point: Vector3 = target.position
			if center.distance_to(point) > radius:
				continue
			var clear: bool = _field.combat_sight(center, point) if ranged_impact else _field.clear_line(center, point)
			if clear:
				_deliver.call(target, now, damage, slow_ms, center, direct_attack)

	func charge(from: Vector3, to: Vector3, width: float, landing_radius: float, now: int, damage: float) -> void:
		var targets: Array[Dictionary] = _observe.call()
		for target in targets:
			var point: Vector3 = target.position
			var nearest := Geometry3D.get_closest_point_to_segment(point, from, to)
			if point.distance_to(nearest) > width + CONTACT_PADDING and point.distance_to(to) > landing_radius + CONTACT_PADDING:
				continue
			if _field.clear_line(nearest, point):
				_deliver.call(target, now, damage, 0, from, true)

	func bent_charge(from: Vector3, via: Vector3, to: Vector3, width: float,
			landing_radius: float, now: int, damage: float, padding: float) -> void:
		var targets: Array[Dictionary] = _observe.call()
		for target in targets:
			var point: Vector3 = target.position
			var first := Geometry3D.get_closest_point_to_segment(point, from, via)
			var second := Geometry3D.get_closest_point_to_segment(point, via, to)
			var contact := (point.distance_to(first) <= width + padding and bool(_field.clear_line(first, point))) \
				or (point.distance_to(second) <= width + padding and bool(_field.clear_line(second, point)))
			var landed := point.distance_to(to) <= landing_radius + padding and bool(_field.clear_line(to, point))
			if contact or landed:
				_deliver.call(target, now, damage, 0, from, true)

	func lure(anchor: Vector3, center: Vector3, radius: float, now: int, damage: float, after_contact: Callable) -> void:
		var targets: Array[Dictionary] = _observe.call()
		for target in targets:
			var point: Vector3 = target.position
			if point.distance_to(center) > radius or not _field.clear_line(anchor, point):
				continue
			if _deliver.call(target, now, damage, 900, anchor, true):
				after_contact.call(target.id, target.life)

	func sector(from: Vector3, face: Vector3, radius: float, span: float, now: int, damage: float) -> void:
		var targets: Array[Dictionary] = _observe.call()
		for target in targets:
			var point: Vector3 = target.position
			if Geometry.accepts_sector(from, face, point, 0.0, radius, span) and _field.clear_line(from, point):
				_deliver.call(target, now, damage, 0, from, true)


static func _source_matches(game: Node, slot: int, token: int, epoch: int) -> bool:
	if not game.multiplayer.is_server() or game.participation.epoch() != epoch:
		return false
	if slot >= 0:
		return token > 0 and game.encounter.token(slot) == token
	if slot == -1 and token > 0:
		return game.encounter.token_for(game.encounter.leader_tactics()) == token
	return true


## Check delayed commitments before constructing a contact window at impact.
static func commitment_is_current(game: Node, commitment: Dictionary) -> bool:
	return _source_matches(game, int(commitment.slot), int(commitment.token), int(commitment.epoch))


## Uses EnemyAttack.SCOUT_COMMIT's scalar epoch, slot, token, target and life.
## An empty commitment keeps the ordinary world scope for scripted moves.
static func for_commitment(game: Node, commitment: Dictionary) -> HitWindow:
	return for_world(game, int(commitment.get("slot", -2)), int(commitment.get("token", -1)),
		int(commitment.get("epoch", -1)), int(commitment.get("target", 0)), int(commitment.get("target_life", -1)))


## Source validity is identity, not health. An already-released strike stays
## committed when its attacker falls, but a replacement cannot inherit it.
## Bystanders can enter the locked footprint. A new life of the chosen target
## cannot inherit the target identity sampled when the attack was scheduled.
static func for_world(game: Node, source_slot: int = -2, spawn_token: int = -1,
		source_epoch: int = -1, intended_peer: int = 0, intended_life: int = -1) -> HitWindow:
	var epoch: int = game.participation.epoch() if source_epoch < 0 else source_epoch
	var token: int = game.encounter.token(source_slot) if source_slot >= 0 and spawn_token < 0 else spawn_token
	var source_is_current := func() -> bool:
		return _source_matches(game, source_slot, token, epoch)
	var observe := func() -> Array[Dictionary]:
		var targets: Array[Dictionary] = []
		if not source_is_current.call():
			return targets
		for id in game.players:
			var actor: Dictionary = game.players[id]
			var life := PlayerLifecycle.generation(actor)
			if life > 0 and Life.alive(actor) and (id != intended_peer or life == intended_life):
				targets.append({"id": id, "life": life, "position": actor.pos})
		return targets
	var deliver := func(target: Dictionary, now: int, damage: float, slow_ms: int,
			origin: Vector3, direct_attack: bool) -> bool:
		if not source_is_current.call():
			return false
		var actor: Dictionary = game.players.get(target.id, {})
		if not Life.alive(actor) or not PlayerLifecycle.matches(actor, target.life):
			return false
		var damage_sequence := int(actor.get("damage_seq", 0))
		load("res://incoming_player_hit.gd").resolve_world(game, target.id, target.life, now, damage, slow_ms, origin, direct_attack)
		var survivor: Dictionary = game.players.get(target.id, {})
		return source_is_current.call() and Life.alive(survivor) and PlayerLifecycle.matches(survivor, target.life) \
			and int(survivor.get("damage_seq", 0)) != damage_sequence
	return HitWindow.new(game.battlefield, observe, deliver, source_is_current)
