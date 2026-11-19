extends RefCounted

const Session = preload("res://network_session.gd")

const Participation = preload("res://expedition_participation.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")
# Host reliable-health publication. Guest reconciliation lives in GuestReplication.
var server_vitals: Dictionary={}

func clear() -> void:
 server_vitals.clear()

func snapshot_targets(game: Node) -> PackedInt32Array:
 var targets := PackedInt32Array()
 var transport: ENetMultiplayerPeer = game.network_session.transport()
 if transport==null or game.multiplayer.multiplayer_peer!=transport or not game.multiplayer.is_server() \
  or transport.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:
  return targets
 for id in game.multiplayer.get_peers():
  if not Session.ready_for(game.players.get(id,{}),false): continue
  var peer := transport.get_peer(id)
  # Godot reserves channels 0 and 1. Snapshot RPC channel 4 uses ENet channel 5.
  if peer!=null and peer.is_active() and peer.get_state()==ENetPacketPeer.STATE_CONNECTED and peer.get_channels()>5:
   targets.append(id)
 return targets

func publish_committed_cleanup(game: Node, transport: ENetMultiplayerPeer) -> void:
 if not is_instance_valid(game) or not game.is_inside_tree() or transport==null or game.network_session.transport()!=transport:
  return
 if game.persistence_session.is_stopping() or not game.persistence_session.is_guarded() or not game.persistence_session.owns_leases():
  return
 game.send_expedition_state(0.0,true)

func observe(game: Node) -> void:
 var changes={}
 for id in game.players:
  var p=game.players[id]
  var hp := PlayerVitals.current_hp(p)
  var maximum := PlayerVitals.maximum_hp(p)
  var fallen := PlayerLifecycle.fallen(p)
  var signature=str([hp,maximum,Participation.is_wild(p),fallen,p.get("lost_health",0),p.get("damage_seq",0)])
  if server_vitals.get(id,{}).get("signature","")==signature:continue
  var revision=int(server_vitals.get(id,{}).get("revision",0))+1
  var state={"revision":revision,"hp":hp,"max_hp":maximum,"fallen":fallen,"lost_health":p.get("lost_health",0),"damage_seq":p.get("damage_seq",0),"damage_amount":p.get("damage_amount",0)}
  server_vitals[id]={"signature":signature,"revision":revision};p.vitals_revision=revision;changes[id]=state
 if not changes.is_empty():
  for id in snapshot_targets(game):
   game.receive_vitals.rpc_id(id,changes)
