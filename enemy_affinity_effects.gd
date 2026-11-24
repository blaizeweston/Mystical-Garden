extends RefCounted
## Shared transient effects on one enemy. A new roster member or floor gets a
## fresh record; the existing encounter/tactics savepoint restores it on rollback.
## Family code can mutate these effects without receiving AI, movement or HP fields.
const STATE := &"affinity_effects"


static func from_body(body: Dictionary) -> Dictionary:
	return body.get(STATE, {})


## Read an installed record in place. Inspecting a clean enemy allocates no stored state.
static func read(world: Node, slot: int) -> Dictionary:
	return from_body(_body(world, slot))


static func edit(world: Node, slot: int) -> Dictionary:
	return _body(world, slot).get_or_add(STATE, {})


static func _body(world: Node, slot: int) -> Dictionary:
	return world.tactics.memory if slot == -1 else world.encounter.scout(slot)
