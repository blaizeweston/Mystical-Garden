extends "res://mob_sim/abilities/ability_handler.gd"
## Gallhorn's angled charge and the Wicker Wasp's wide flank: step to the side before the wind-up, as
## EnemyVariants.prepare does. Each attack takes the step once; the next attempt winds up from there.

const Geometry = preload("res://mob_sim/abilities/handler_geometry.gd")


func approach(port: Port, release: Release) -> Vector2:
	var memory := port.memory(release.slot)
	if memory.get("approached", false):
		memory.approached = false
		return Vector2.INF
	var origin := port.position(release.slot)
	var victim := port.player_position(release.player)
	if not victim.is_finite():
		return Vector2.INF
	var forward := (victim - origin).normalized()
	var goal := origin + Geometry.side(origin, victim, release.slot) * (1.35 if release.legacy == "angled_charge" else 1.1)
	if release.legacy == "angled_charge":
		goal -= forward * 0.6
	if not port.line_clear(origin, goal, Geometry.BODY_CLEARANCE) or not port.line_clear(goal, victim, Geometry.BODY_CLEARANCE):
		return Vector2.INF
	memory.approached = true
	return goal
