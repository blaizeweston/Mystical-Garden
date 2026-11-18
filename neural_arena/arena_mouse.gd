extends "res://mouse_combat.gd"
## Ignores the local mouse while the host's body is controlled by a bot.


func frame(game: Node) -> void:
	if not game.host_is_bot():
		super(game)
