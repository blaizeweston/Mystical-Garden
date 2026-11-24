extends RefCounted
## Synthetic fixture setup only. Production admission uses ExpeditionTransitions.
## Keep every fixture bound to the same participation owner used at runtime.

const Participation = preload("res://expedition_participation.gd")
const Sessions = preload("res://tests/support/session_case.gd")

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
	Sessions.install_registration(game,peer,actor)
	game.players[peer] = actor
	if active:
		assert(game.participation.enter(peer))

static func remove_actor(game: Node, peer: int) -> void:
	game.network_session.release_peer(peer)
	game.participation.detach(peer)
	game.players.erase(peer)

## Install a floor-local specimen/root at the actor for persistence fault injection.
## Procedural placement and normal encounter entry are covered separately.
static func returning_root(game: Node, actor: Dictionary, floor_key: String) -> void:
	game.wild_flora.begin(floor_key, func(): return {})
	game.wild_flora.generate_root(floor_key,func(_plant): return actor.pos)

static func deposit_request(game: Node, actor: Dictionary, item: String) -> String:
	var root: Dictionary = game.ReturningRoot.view(game,game.Session.peer_for(actor),actor)
	return game.ReturningRoot.request(root,game.ActionIdentity.current_stamp(game,actor),item)
