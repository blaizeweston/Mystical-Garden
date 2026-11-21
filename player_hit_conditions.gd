extends RefCounted
## Host-owned ordinary Slow and post-hit grace. Each actor holds one immutable
## State. This is not an affinity-status store, Omen registry or HP owner.
## Deadlines/durations are host monotonic milliseconds; movement is a ratio.

const STATE := "player_hit_conditions"
const Tuning = preload("res://game_balance.gd")

## These authored values are included in the gameplay-definition handshake.
## RPC contracts and protocol-41 projections do not carry this component.
static func rules_contract() -> Dictionary:
	return {
		"hit_grace_ms": int(Tuning.values.combat.hit_grace_ms),
		"revival_grace_ms": int(Tuning.values.combat.revival_grace_ms),
		"player_slow_movement_scale": float(Tuning.values.combat.player_slow_movement_scale),
	}


class HitUpdate extends RefCounted:
	var next_state: State
	var slow_applied: bool

	func _init(state: State, applied: bool) -> void:
		next_state = state
		slow_applied = applied


class State extends RefCounted:
	var _grace_until_ms: int
	var _slow_until_ms: int

	func _init(grace_deadline_ms: int = 0, slow_deadline_ms: int = 0) -> void:
		_grace_until_ms = grace_deadline_ms
		_slow_until_ms = slow_deadline_ms

	func grace_active(now_ms: int) -> bool:
		return now_ms < _grace_until_ms

	func grace_until_ms() -> int:
		return _grace_until_ms

	func slow_active(now_ms: int) -> bool:
		return now_ms < _slow_until_ms

	func slow_until_ms() -> int:
		return _slow_until_ms

	func movement_scale(now_ms: int) -> float:
		return float(Tuning.values.combat.player_slow_movement_scale) if slow_active(now_ms) else 1.0

	## Quiet Ground is only asked to consume an influence when a positive Slow
	## would extend the current deadline. The Omen owner still chooses/consumes
	## that source; this query does not access or duplicate its records.
	func slow_needs_prevention(now_ms: int, duration_ms: int) -> bool:
		return duration_ms > 0 and now_ms + duration_ms > _slow_until_ms

	## Apply the existing validated unblocked contact's aftermath. Preserve the
	## original replacement rule: a shorter/equal Slow can replace the deadline
	## without spending Quiet Ground. Blocked/grace/stale contacts never call this.
	func after_hit(now_ms: int, slow_ms: int, grace_ms: int, slow_prevented: bool) -> HitUpdate:
		var applied := slow_ms > 0 and not (slow_prevented and slow_needs_prevention(now_ms, slow_ms))
		var next := State.new(now_ms + grace_ms, now_ms + slow_ms if applied else _slow_until_ms)
		return HitUpdate.new(next, applied)

	## Explicitly validated deadline changes (revival or controlled fixtures).
	func with_grace_until(until_ms: int) -> State:
		return self if until_ms == _grace_until_ms else State.new(until_ms, _slow_until_ms)

	func with_slow_until(until_ms: int) -> State:
		return self if until_ms == _slow_until_ms else State.new(_grace_until_ms, until_ms)

	func cleanse_slow() -> State:
		return with_slow_until(0)

	func clear_grace() -> State:
		return with_grace_until(0)

	func clear_all() -> State:
		return State.new()
