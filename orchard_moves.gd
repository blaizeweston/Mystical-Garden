extends RefCounted
## Orchard-specific rotation, reach and geometry. The host locks aim before warning players.
const LATE_ROTATION := ["root_sweep", "falling_fruit", "orchard_march", "root_cage"]


static func next_move(opening: Array, phase: int, casts: int, phase_start: int) -> String:
	if phase <= 0:
		return opening[casts % opening.size()]
	return LATE_ROTATION[(casts - phase_start) % LATE_ROTATION.size()]


static func reach(mode: String, phase: int) -> float:
	match mode:
		"root_sweep": return 8.1 + phase * .65
		"orchard_march": return 11.5 + phase * .5
		"root_cage": return 12.5
		"falling_fruit": return 15.0 + phase
	return 0.0


static func inside_cage(center: Vector3, axis: Vector3, at: Vector3, outer: float, inner: float, gap: float, buffer: float = 0.0) -> bool:
	var offset := at - center
	var distance := offset.length()
	if distance > outer + buffer:
		return false
	if distance <= inner + buffer:
		return true
	var clear_angle := maxf(0.0, gap - buffer / distance)
	return absf(axis.dot(offset / distance)) < cos(clear_angle)


static func cage_exits(plan: Dictionary, at: Vector3) -> Array[Vector3]:
	var axis: Vector3 = (plan.to - plan.from).normalized()
	var offset: Vector3 = at - plan.from
	var projection := absf(axis.dot(offset))
	var distances := [maxf(float(plan.inner) + .62, projection), float(plan.inner) + .62]
	var exits: Array[Vector3] = []
	for distance in distances:
		exits.append(plan.from + axis * distance)
		exits.append(plan.from - axis * distance)
	return exits
