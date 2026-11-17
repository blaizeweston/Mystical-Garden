extends RefCounted
## Native Q, R and dodge cooldowns. Deadlines use the host's monotonic
## milliseconds. Each change returns a replacement so a transaction can
## restore its prior actor snapshot without sharing mutable timer state.

const STATE := "player_cooldowns"
enum { Q, R, DODGE }

class Timers extends RefCounted:
	var _deadlines: Array[int]

	func _init(q_ms: int = 0, r_ms: int = 0, dodge_ms: int = 0) -> void:
		_deadlines = [q_ms, r_ms, dodge_ms]

	func deadline(action: int) -> int:
		return _deadlines[action]

	func ready(action: int, now_ms: int) -> bool:
		return now_ms >= deadline(action)

	func start(action: int, now_ms: int, duration_ms: int) -> Timers:
		return with_deadline(action, now_ms + duration_ms)

	func refund(action: int, now_ms: int, reduction_ms: int, minimum_remaining_ms: int = 0) -> Timers:
		return with_deadline(action, maxi(now_ms + minimum_remaining_ms, deadline(action) - reduction_ms))

	func ready_by(action: int, now_ms: int) -> Timers:
		return with_deadline(action, mini(now_ms, deadline(action)))

	func with_deadline(action: int, deadline_ms: int) -> Timers:
		if deadline_ms == deadline(action):
			return self
		var replacement := Timers.new(deadline(Q), deadline(R), deadline(DODGE))
		replacement._deadlines[action] = deadline_ms
		return replacement

	func skill_seconds(now_ms: int) -> Array[float]:
		return [maxi(0, deadline(Q) - now_ms) / 1000.0, maxi(0, deadline(R) - now_ms) / 1000.0]

	func skill_projection(now_ms: int) -> Dictionary:
		return {
			"skill_ready": ready(Q, now_ms),
			"skill_two_ready": ready(R, now_ms),
			"skill_cooldowns": skill_seconds(now_ms),
		}
