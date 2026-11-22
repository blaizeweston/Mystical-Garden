extends RefCounted
## Host-owned weapon action timeline. Actor records hold one immutable State;
## guests receive the existing pose/attack_anim projections, never this object.
## Times are monotonic milliseconds, reach is metres, span is radians.

const Motion = preload("res://weapon_motion.gd")
const STATE := "player_weapon_actions"

class State extends RefCounted:
	var _ready_at_ms := 0
	var _pose_until_ms := 0
	var _swing_until_ms := 0
	var _duration_ms := Motion.DEFAULT_POSE_MS
	var _sequence := 0
	var _basic_form := ""
	var _basic_step := 0
	var _reach_m := 2.0
	var _direction := Vector3.INF
	var _clip := ""
	var _has_clip := false
	var _delivery := "sweep"
	var _span_rad := 1.9
	var _windup_sequence := -1
	var _release_at_ms := 0

	func ready(now_ms: int) -> bool:
		return now_ms >= _ready_at_ms

	func ready_at_ms() -> int:
		return _ready_at_ms

	func sequence() -> int:
		return _sequence

	func basic_step() -> int:
		return _basic_step

	func duration_ms() -> int:
		return _duration_ms

	func pose_until_ms() -> int:
		return _pose_until_ms

	## Admission precedes rolls/proc capture in WeaponAttackQueue. The owner also refuses a
	## second start at the same deadline if called independently.
	func try_start(now_ms: int, interval_ms: int, authored_pose_ms: int, reach_m: float, form: String = "") -> State:
		if not ready(now_ms): return null
		var next := _copy()
		next._ready_at_ms = now_ms + interval_ms
		next._duration_ms = Motion.basic_duration_ms(authored_pose_ms, interval_ms)
		next._pose_until_ms = now_ms + next._duration_ms
		next._swing_until_ms = next._pose_until_ms
		next._reach_m = reach_m
		next._sequence += 1
		next._basic_step = _basic_step + 1 if form == _basic_form else 1
		next._basic_form = form
		return next

	func with_pose(direction: Vector3, clip: String, delivery: String, span_rad: float) -> State:
		var next := _copy()
		next._direction = direction
		next._clip = clip
		next._has_clip = true
		next._delivery = delivery
		next._span_rad = span_rad
		return next

	func follow_cursor_until(release_at_ms: int) -> State:
		var next := _copy()
		next._windup_sequence = _sequence
		next._release_at_ms = release_at_ms
		return next

	func aim_is_live(now_ms: int, mouse_enabled: bool) -> bool:
		return mouse_enabled and _windup_sequence == _sequence and now_ms < _release_at_ms

	## Older queued shots still use their own release path, but cannot change
	## the newest action's committed presentation direction.
	func sample_release(sequence_id: int, direction: Vector3) -> State:
		if sequence_id != _sequence: return self
		var next := _copy()
		next._direction = direction
		return next

	## Core shares the weapon pose and basic-attack exclusion deadline. Its
	## independent cooldown, cast queue and damage stay with CoreCombat.
	func core_pose(now_ms: int, recovery_duration_ms: int, reach_m: float, direction: Vector3, clip: String, delivery: String, span_rad: float, weapon_pose: bool) -> State:
		var next := with_pose(direction, clip, delivery, span_rad)
		next._ready_at_ms = maxi(_ready_at_ms, now_ms + recovery_duration_ms)
		next._duration_ms = recovery_duration_ms
		next._pose_until_ms = now_ms + recovery_duration_ms if weapon_pose else 0
		next._reach_m = reach_m
		next._sequence += 1
		return next

	## A native class hit's existing short swing pulse is presentation only.
	func swing_until(until_ms: int) -> State:
		var next := _copy()
		next._swing_until_ms = until_ms
		return next

	func clear_active() -> State:
		var next := _copy()
		next._pose_until_ms = 0
		next._swing_until_ms = 0
		return next

	## Used by existing content/fixtures that explicitly ready ordinary attacks.
	## It changes neither the active pose nor any class/Core cooldown.
	func with_ready_at(until_ms: int) -> State:
		var next := _copy()
		next._ready_at_ms = until_ms
		return next

	func swing_ticks(now_ms: int) -> int:
		return clampi(ceili((_swing_until_ms - now_ms) / 10.0), 0, 24)

	func swing_fraction(now_ms: int) -> float:
		return clampf((_swing_until_ms - now_ms) / float(Motion.DEFAULT_POSE_MS), 0.0, 1.0)

	func animation(now_ms: int, facing: Vector3, mouse_enabled: bool, live_aim: Vector3, fallback_clip: String) -> Dictionary:
		var direction := _direction if _direction.is_finite() else facing
		var live := aim_is_live(now_ms, mouse_enabled)
		if live and live_aim.is_finite(): direction = live_aim
		var duration := maxi(1, _duration_ms)
		var remaining := _pose_until_ms - now_ms
		return {"active":remaining>0, "phase":clampf(1.0-remaining/float(duration),0,1),
			"combo":_sequence, "duration":duration, "reach":_reach_m, "direction":direction,
			"aim_live":live, "clip":_clip if _has_clip else fallback_clip,
			"delivery":_delivery, "span":_span_rad, "form":"weapon"}

	func _copy() -> State:
		var next := State.new()
		next._ready_at_ms = _ready_at_ms
		next._pose_until_ms = _pose_until_ms
		next._swing_until_ms = _swing_until_ms
		next._duration_ms = _duration_ms
		next._sequence = _sequence
		next._basic_form = _basic_form
		next._basic_step = _basic_step
		next._reach_m = _reach_m
		next._direction = _direction
		next._clip = _clip
		next._has_clip = _has_clip
		next._delivery = _delivery
		next._span_rad = _span_rad
		next._windup_sequence = _windup_sequence
		next._release_at_ms = _release_at_ms
		return next
