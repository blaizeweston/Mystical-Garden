extends RefCounted

const PlayerLifecycle = preload("res://player_lifecycle.gd")

static func can_learn_here(game: Node, player: Dictionary) -> bool:
	return not PlayerLifecycle.fallen(player) and (game.at_heart(player) or game.at_weapon_gate(player)) and not game.expedition_active()
