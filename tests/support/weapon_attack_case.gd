extends RefCounted
## Exercise the same private queue used by live input, without mutable test rows.
const Clock = preload("res://combat_clock.gd")

static func start(world: Node, peer: int, origin: Vector3) -> bool:
	return world.weapon_attacks.try_start(world.weapon_attack_world, peer, origin, Clock.now())

static func advance(world: Node, now: int) -> void:
	world.weapon_attacks.advance(world.weapon_attack_world, now)

static func schedule(world: Node, peer: int, origin: Vector3, stats: Dictionary, now: int, form: String, duration: int, target := -2) -> int:
	return world.weapon_attacks.schedule(world.weapon_attack_world, peer, origin, stats, now, form, duration, target)
