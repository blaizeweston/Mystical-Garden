extends RefCounted

static func can_learn_here(game: Node, player: Dictionary) -> bool:
	return not player.get("fallen",false) and (game.at_heart(player) or game.at_weapon_gate(player)) and not game.expedition_active()
