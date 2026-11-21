extends RefCounted
## Host monotonic milliseconds. Immutable replacements preserve transaction rollback.
## Dash charges share one sequential recharge deadline, never parallel timers.
const STATE := "player_cooldowns"
const BASELINE_DODGE_MS := 2200 # CE04 provisional; was 850 ms. Movement is unchanged.
enum { Q, R, DODGE }

class Timers extends RefCounted:
	var _deadlines: Array[int]
	var _dodge_capacity := 1
	var _dodge_recovery: Array[int] = []

	func _init(q_ms: int = 0, r_ms: int = 0, dodge_ms: int = 0) -> void:
		_deadlines = [q_ms, r_ms, dodge_ms]
		if dodge_ms > 0: _dodge_recovery.append(0)

	func _copy() -> Timers:
		var result := Timers.new(deadline(Q), deadline(R))
		result._deadlines[DODGE] = deadline(DODGE)
		result._dodge_capacity = _dodge_capacity
		result._dodge_recovery.assign(_dodge_recovery)
		return result

	func _settled(now_ms: int) -> Timers:
		var result := _copy()
		while not result._dodge_recovery.is_empty() and result.deadline(DODGE) <= now_ms:
			result._dodge_recovery.pop_front()
			if result._dodge_recovery.is_empty(): result._deadlines[DODGE] = 0
			else: result._deadlines[DODGE] += result._dodge_recovery[0]
		return result

	func configure_dodge(capacity: int, now_ms: int) -> Timers:
		var result := _settled(now_ms)
		result._dodge_capacity = maxi(1, capacity)
		while result._dodge_recovery.size() > result._dodge_capacity: result._dodge_recovery.pop_back()
		return result

	func dodge_projection(now_ms: int) -> Dictionary:
		var current := _settled(now_ms)
		return {"available":current._dodge_capacity-current._dodge_recovery.size(), "capacity":current._dodge_capacity,
			"remaining_ms":maxi(0,current.deadline(DODGE)-now_ms), "recovering":current._dodge_recovery.size()}

	func deadline(action: int) -> int:
		return _deadlines[action]

	func ready(action: int, now_ms: int) -> bool:
		return int(dodge_projection(now_ms).available)>0 if action==DODGE else now_ms>=deadline(action)

	func start(action: int, now_ms: int, duration_ms: int) -> Timers:
		if action!=DODGE: return with_deadline(action,now_ms+duration_ms)
		var result:=_settled(now_ms)
		if result._dodge_recovery.size()>=result._dodge_capacity: return self
		var duration:=maxi(1,duration_ms)
		if result._dodge_recovery.is_empty(): result._deadlines[DODGE]=now_ms+duration
		result._dodge_recovery.append(duration)
		return result

	func refund(action: int, now_ms: int, reduction_ms: int, minimum_remaining_ms: int = 0) -> Timers:
		return with_deadline(action,maxi(now_ms+minimum_remaining_ms,deadline(action)-reduction_ms))

	func ready_by(action: int, now_ms: int) -> Timers:
		if action!=DODGE: return with_deadline(action,mini(now_ms,deadline(action)))
		var result:=_settled(now_ms)
		if not result._dodge_recovery.is_empty(): result._dodge_recovery.pop_front()
		result._deadlines[DODGE]=0 if result._dodge_recovery.is_empty() else now_ms+result._dodge_recovery[0]
		return result

	func with_deadline(action: int, deadline_ms: int) -> Timers:
		var result:=_copy()
		result._deadlines[action]=deadline_ms
		if action==DODGE:
			if deadline_ms<=0: result._dodge_recovery.clear()
			elif result._dodge_recovery.is_empty(): result._dodge_recovery.append(0)
		return result

	func skill_seconds(now_ms: int) -> Array[float]:
		return [maxi(0,deadline(Q)-now_ms)/1000.0,maxi(0,deadline(R)-now_ms)/1000.0]

	func skill_projection(now_ms: int) -> Dictionary:
		return {"skill_ready":ready(Q,now_ms),"skill_two_ready":ready(R,now_ms),"skill_cooldowns":skill_seconds(now_ms)}
