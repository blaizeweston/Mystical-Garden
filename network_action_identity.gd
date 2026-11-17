extends RefCounted
## Native Core and aimed Q/R request identity. The host derives this from
## separate session, player-life and expedition authorities. Guests receive
## only the opaque result through reliable owner details, never the fast frame.

const Session = preload("res://network_session.gd")
const Participation = preload("res://expedition_participation.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const VERSION := 1
const KEY := "action_identity"
const BINDING_KEY := "session_binding"
const CHARACTER_KEY := "session_character"
const WORLD_FIELDS := ["run_id","combat_epoch","destination","depth",
	"encounter_number","difficulty_cycle","map_seed"]

static func build(connection: String, character: String, life: int,
		world: Dictionary, active: bool) -> String:
	if connection.is_empty() or character.is_empty() or life <= 0 or not active:
		return ""
	var context: Array = [VERSION,connection,character,life]
	for field: String in WORLD_FIELDS:
		if not world.get(field) is int: return ""
		context.append(int(world[field]))
	if int(world.run_id) <= 0 or int(world.combat_epoch) < 0 or int(world.encounter_number) <= 0:
		return ""
	return "a%d/" % VERSION + JSON.stringify(context).sha256_text()

static func current_stamp(game: Node, player: Dictionary) -> String:
	if game.multiplayer.is_server():
		var peer := Session.peer_for(player)
		if peer <= 0 or not Session.belongs_to(player,game.network_session) \
				or Participation.peer_for(player) != peer or not game.network_session.ready(peer): return ""
		return build(game.network_session.connection_key(peer),game.network_session.identity(peer),
			PlayerLifecycle.generation(player),game.participation.world(),Participation.is_wild(player))
	# Reliable details can trail the fast floor projection. Do not present an
	# old floor's opaque request as current while that recovery is pending.
	if game.client_details_key != str([game.participation.route(),game.participation.floor(),game.participation.seed()]):
		return ""
	if not game.network_session.permits_details(str(player.get(BINDING_KEY,""))):
		return ""
	var stamp := str(player.get(KEY,""))
	return stamp if stamp.begins_with("a%d/" % VERSION) else ""
