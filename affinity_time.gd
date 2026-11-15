extends RefCounted

# Accumulated by the authoritative physics loop. Paused, stopped, and
# persistence-blocked sessions do not spend a status lifetime or bank ticks.
const CLOCK := &"affinity_combat_time"


static func now(game: Node) -> int:
	return roundi(float(game.get_meta(CLOCK, 0.0)))


static func advance(game: Node, delta: float) -> int:
	var elapsed := float(game.get_meta(CLOCK, 0.0)) + delta * 1000.0
	game.set_meta(CLOCK, elapsed)
	return roundi(elapsed)
