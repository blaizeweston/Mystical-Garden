extends RefCounted
## Route and placement helpers shared by ability handlers. They follow the legacy rules in
## enemy_variants.gd and enemy_support.gd, using the port's line of sight.

const Port = preload("res://mob_sim/abilities/handler_port.gd")
const Release = preload("res://mob_sim/mob_release.gd")

## Matches Battlefield.CLEARANCE, the body clearance used for movement lines.
const BODY_CLEARANCE := 0.45


## Sideways direction for a mob. Odd slots go the other way so neighbours spread out.
static func side(from: Vector2, to: Vector2, slot: int) -> Vector2:
	var forward := (to - from).normalized()
	return Vector2(-forward.y, forward.x) * (-1.0 if slot % 2 == 1 else 1.0)


## A bend point beside the line from from to to, as EnemyVariants.seam picks it, or Vector2.INF.
static func seam(port: Port, from: Vector2, to: Vector2, slot: int) -> Vector2:
	if from.distance_to(to) < 2.4:
		return Vector2.INF
	var across := side(from, to, slot)
	for sign_value: float in [1.0, -1.0]:
		var via := from.lerp(to, 0.53) + across * 1.3 * sign_value
		if port.line_clear(from, via, BODY_CLEARANCE) and port.line_clear(via, to, BODY_CLEARANCE):
			return via
	return Vector2.INF


## A landing beside the target that cuts off its escape, as EnemyVariants.cutoff picks it.
## Returns target itself when no side works.
static func cutoff(port: Port, from: Vector2, target: Vector2, slot: int) -> Vector2:
	var across := side(from, target, slot)
	for sign_value: float in [1.0, -1.0]:
		var aim := target + across * 1.55 * sign_value
		var escape := target - across * 2.1 * sign_value
		if port.line_clear(from, aim, BODY_CLEARANCE) and port.line_clear(target, escape, BODY_CLEARANCE):
			return aim
	return target


## True while an anchoring ally stays alive, within reach and sight, and near where it was chosen.
static func anchor_intact(port: Port, release: Release) -> bool:
	var anchor: Dictionary = release.data.get("anchor", {})
	if anchor.is_empty() or not port.alive(int(anchor.slot)):
		return false
	var point: Vector2 = port.position(int(anchor.slot))
	var origin: Vector2 = port.position(release.slot)
	return point.distance_squared_to(anchor.point) <= 0.64 and point.distance_to(origin) <= port.reach(release.slot) \
		and port.line_clear(origin, point)
