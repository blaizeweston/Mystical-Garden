extends RefCounted
## Synthetic fixture setup only. Production admission uses ExpeditionTransitions.
## Keep every fixture bound to the same participation owner used at runtime.

const Participation = preload("res://expedition_participation.gd")
const Transitions = preload("res://expedition_transitions.gd")

static func is_wild(actor: Dictionary) -> bool:
	return Participation.is_wild(actor)

static func set_membership(game: Node, actor: Dictionary, active: bool) -> void:
	var peer := 0
	for candidate in game.players:
		if is_same(game.players[candidate], actor):
			peer = int(candidate)
			break
	assert(peer > 0, "Fixture actor must be installed in the world before joining")
	if Participation.peer_for(actor) != peer:
		actor[Participation.STATE] = game.participation.attach(peer)
	if active:
		if not game.participation.contains(peer):
			# A fixture may deliberately rewind a canned case after a partial return.
			# Reset only its synthetic admission hold; runtime enter still enforces it.
			var saved: Dictionary = game.participation.savepoint()
			saved.members[peer].waiting = false
			game.participation.restore_savepoint(saved)
			assert(game.participation.enter(peer))
	else:
		game.participation.leave(peer)
	actor.erase("wild")

static func set_world(game: Node, changes: Dictionary) -> void:
	var saved: Dictionary = game.participation.savepoint()
	for key in changes:
		assert(saved.world.has(key), "Unknown fixture world field: " + str(key))
		saved.world[key] = changes[key]
	game.participation.restore_savepoint(saved)

static func install_actor(game: Node, peer: int, actor: Dictionary) -> void:
	var active := is_wild(actor)
	game.participation.detach(peer)
	actor[Participation.STATE] = game.participation.attach(peer)
	actor.erase("wild")
	game.players[peer] = actor
	if active:
		assert(game.participation.enter(peer))

static func remove_actor(game: Node, peer: int) -> void:
	game.participation.detach(peer)
	game.players.erase(peer)
