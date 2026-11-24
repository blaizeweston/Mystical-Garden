extends RefCounted
## Routes the floor leader to its specialist behavior and projects the warning radius.

const Bosses = preload("res://boss_encounters.gd")
const Elite = preload("res://elite_enemy.gd")
const Enemies = preload("res://enemy_catalog.gd")


static func tick(game: Node, delta: float, now: int) -> void:
	if game.tactics.boss_kind >= 0:
		Bosses.tick(game, delta, now)
	elif game.encounter.alive(-1):
		Elite.tick(game, delta, now)


static func strike_radius(game: Node) -> float:
	if game.tactics.active_radius > 0.0:
		return game.tactics.active_radius
	var radius: float = 3.0 if game.tactics.longlimb else [1.8, 2.1, 2.25][game.participation.route()]
	return radius + (0.35 if game.enemy_mutations & Enemies.SPORES else 0.0)
