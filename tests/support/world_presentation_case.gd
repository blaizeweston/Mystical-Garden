extends RefCounted
## Fixture-only access to named presentation nodes; production exposes queries.
static func component(world: Node, kind: String) -> Variant:
	var paths := {"combat":"Stage/CombatEffects","deaths":"Stage/DeathEffects","map":"Exploration"}
	assert(paths.has(kind),"Unknown presentation component: "+kind)
	return world.get_node(paths[kind])
