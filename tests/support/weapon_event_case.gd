extends RefCounted
## Observe the real event at admission to test duplicate/secondary rejection.
## Presentation views intentionally contain scalar identities, not event handles.
## This fixture never reads or changes the queue's private records.
const Port = preload("res://weapon_attack_world.gd")
const Clock = preload("res://combat_clock.gd")

class ObservedLaunch extends Port:
	var _contact_context := {}

	func capture_attack(peer: int, now: int) -> Dictionary:
		var stats := super.capture_attack(peer, now)
		for key in [Events.CONTEXT, "pull", "knockback"]:
			if stats.has(key): _contact_context[key] = stats[key]
		return stats

	func contact_context() -> Dictionary:
		return _contact_context.duplicate(true)

static func start(world: Node, peer: int, origin: Vector3) -> Dictionary:
	var port := ObservedLaunch.new(world)
	assert(world.weapon_attacks.try_start(port, peer, origin, Clock.now()))
	return port.contact_context()
