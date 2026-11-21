extends RefCounted
## Host-owned native Guard/Ward and counter timelines. One immutable State is
## attached to each actor. HP, Bark, damage reduction and hit grace have other
## owners. Guests receive existing status/motion projections, never this object.
## Deadlines are monotonic milliseconds; counter power is authored damage points.

const STATE := "player_protection"
const Balance = preload("res://class_skill_balance.gd")


class WardClaim extends RefCounted:
	var _event: RefCounted
	var _adapter: Dictionary
	var _until_ms: int
	var _order: int
	var _epoch: int

	func _init(event: RefCounted, adapter: Dictionary, until_ms: int, order: int, epoch: int) -> void:
		_event = event
		_adapter = adapter.duplicate(true)
		_adapter.make_read_only()
		_until_ms = until_ms
		_order = order
		_epoch = epoch


class Block extends RefCounted:
	var next_state: State
	var response: RefCounted
	var adapter: Dictionary

	func _init(state: State, event: RefCounted = null, definition: Dictionary = {}) -> void:
		next_state = state
		response = event
		adapter = definition.duplicate(true)
		adapter.make_read_only()


class State extends RefCounted:
	var _guard_until_ms := 0
	var _charges := 0
	var _front_until_ms := 0
	var _facing := Vector3.FORWARD
	var _counter_guard_until_ms := 0
	var _counter_until_ms := 0
	var _counter_points := 1.0
	var _claims: Array[WardClaim] = []
	var _grant_order := 0

	func guard_until_ms() -> int:
		return _guard_until_ms

	func charge_count() -> int:
		return _charges

	func claim_count() -> int:
		return _claims.size()

	func counter_until_ms() -> int:
		return _counter_until_ms

	func counter_points() -> float:
		return _counter_points

	func counter_ready(now_ms: int) -> bool:
		return now_ms < _counter_until_ms

	func counter_guard_active(now_ms: int) -> bool:
		return now_ms < _counter_guard_until_ms

	func movement_scale(now_ms: int) -> float:
		return Balance.FRONT_GUARD_SPEED_SCALE if now_ms < _front_until_ms else 1.0

	func allows_block(position: Vector3, origin: Vector3, now_ms: int) -> bool:
		if now_ms >= _guard_until_ms: return false
		if now_ms >= _front_until_ms or origin == Vector3.INF: return true
		var direction := origin - position
		return direction.length_squared() < Balance.FRONT_GUARD_POINT_EPSILON_SQ \
			or direction.normalized().dot(_facing) >= Balance.FRONT_GUARD_MIN_DOT

	## Max-merge charges/duration, never add charges. A refresh can extend native
	## protection without extending the originating event's response budget.
	## Source events own their once-per-recipient budget; this owner holds only
	## the accepted claim. Null events are ordinary, unenhanced protection.
	func grant(until_ms: int, charges: int, now_ms: int, epoch: int,
			event: RefCounted = null, adapter: Dictionary = {}, recipient_id: int = 0) -> State:
		var next := _copy()
		var previous_charges := _charges if _guard_until_ms > now_ms else 0
		if _guard_until_ms <= now_ms or previous_charges <= 0:
			next._claims.clear()
		next._guard_until_ms = maxi(_guard_until_ms, until_ms)
		next._charges = maxi(previous_charges, Balance.guard_charges(charges))
		if next._guard_until_ms <= now_ms or (next._guard_until_ms == _guard_until_ms and next._charges == previous_charges):
			return next
		if event != null and not event.accept_grant(recipient_id): return next
		next._grant_order += 1
		next._claims = _live_claims(next._claims, now_ms, epoch)
		next._claims.append(WardClaim.new(event, adapter, until_ms, next._grant_order, epoch))
		return next

	func with_front_guard(until_ms: int, facing: Vector3) -> State:
		var next := _copy()
		next._front_until_ms = until_ms
		next._facing = facing.normalized()
		return next

	func with_counter_guard(until_ms: int) -> State:
		var next := _copy()
		next._counter_guard_until_ms = until_ms
		return next

	## Called only for a validated actual block. Earliest expiry wins, then
	## accepted host grant order. Order is recipient-local: claims on different
	## recipients never compete. One block consumes one claim, even a native one.
	func consume_block(now_ms: int, epoch: int, recipient_id: int) -> Block:
		var next := _copy()
		next._charges = maxi(0, _charges - 1)
		if next._charges == 0: next._guard_until_ms = 0
		if _charges <= 0: return Block.new(next)
		var chosen: WardClaim = null
		var kept: Array[WardClaim] = []
		for claim in _live_claims(_claims, now_ms, epoch):
			if claim._event != null and not claim._event.block_available(recipient_id, claim._adapter, now_ms): continue
			kept.append(claim)
			if chosen == null or claim._until_ms < chosen._until_ms \
					or (claim._until_ms == chosen._until_ms and claim._order < chosen._order):
				chosen = claim
		if chosen != null: kept.erase(chosen)
		next._claims = kept
		if next._charges <= 0: next._claims.clear()
		return Block.new(next, chosen._event, chosen._adapter) if chosen != null else Block.new(next)

	func prepare_counter(until_ms: int, power_points: float) -> State:
		var next := _copy()
		next._counter_until_ms = until_ms
		next._counter_points = power_points
		return next

	func extend_ready_counter(now_ms: int, additional_ms: int) -> State:
		if not counter_ready(now_ms): return self
		var next := _copy()
		next._counter_until_ms += additional_ms
		return next

	func spend_counter() -> State:
		var next := _copy()
		next._counter_until_ms = 0
		return next

	func expire_claims(now_ms: int) -> State:
		if _claims.is_empty() or (_guard_until_ms > now_ms and _charges > 0): return self
		var next := _copy()
		next._claims.clear()
		return next

	## Fall/revival cancels protection and claims. Preserve the native counter
	## and directional windows, as before; life validity is owned by Lifecycle.
	func clear_guard() -> State:
		var next := _copy()
		next._guard_until_ms = 0
		next._claims.clear()
		return next

	## Entry/return also clears charges and active native windows. Stored facing
	## and inactive power remain harmless, matching the old lifecycle resets.
	func clear_expedition() -> State:
		var next := clear_guard()
		next._charges = 0
		next._front_until_ms = 0
		next._counter_guard_until_ms = 0
		next._counter_until_ms = 0
		return next

	static func _live_claims(claims: Array[WardClaim], now_ms: int, epoch: int) -> Array[WardClaim]:
		var result: Array[WardClaim] = []
		for claim in claims:
			if claim._until_ms > now_ms and claim._epoch == epoch: result.append(claim)
		return result

	func _copy() -> State:
		var next := State.new()
		next._guard_until_ms = _guard_until_ms
		next._charges = _charges
		next._front_until_ms = _front_until_ms
		next._facing = _facing
		next._counter_guard_until_ms = _counter_guard_until_ms
		next._counter_until_ms = _counter_until_ms
		next._counter_points = _counter_points
		next._claims.assign(_claims)
		next._grant_order = _grant_order
		return next
