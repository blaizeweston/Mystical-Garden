extends RefCounted
# Public health versions reconcile independent reliable/unreliable channels.
var server_vitals: Dictionary={}
var client_vitals: Dictionary={}
var flash_until: Dictionary={}
var snapshot_sent:=0
var snapshot_received:=-1
var rejected_snapshots:=0
var snapshot_gaps:=0
# Reuse the current replacement frame on the existing reliable details channel
# when ENet is shedding most unreliable sends.
const RECOVERY_THROTTLE := ENetPacketPeer.PACKET_THROTTLE_SCALE / 2.0
var latest_frame := PackedByteArray()
var latest_frame_key := ""
var names: Dictionary = {}
var diagnostic_host := ""
var diagnostic_world := ""

func set_roster(roster: Dictionary, host_id: String, world_id: String) -> void:
 names = roster
 diagnostic_host = host_id
 diagnostic_world = world_id

func apply_roster(people: Dictionary) -> void:
 for id in people:
  var p: Dictionary = people[id]
  p.display_name = names.get(id, "Wanderer")
  p.diagnostic_host = diagnostic_host
  p.diagnostic_world = diagnostic_world

func clear() -> void:
 server_vitals.clear();client_vitals.clear();flash_until.clear();snapshot_sent=0;snapshot_received=-1;rejected_snapshots=0;snapshot_gaps=0
 latest_frame.clear()
 latest_frame_key = ""
 set_roster({}, "", "")
func snapshot_targets(game: Node) -> PackedInt32Array:
 var targets := PackedInt32Array()
 var transport: ENetMultiplayerPeer = game.online_peer
 if transport==null or game.multiplayer.multiplayer_peer!=transport or not game.multiplayer.is_server() \
  or transport.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:
  return targets
 for id in game.multiplayer.get_peers():
  if not game.players.get(id,{}).get("profile_ready",false): continue
  var peer := transport.get_peer(id)
  # Godot reserves channels 0 and 1. Snapshot RPC channel 4 uses ENet channel 5.
  if peer!=null and peer.is_active() and peer.get_state()==ENetPacketPeer.STATE_CONNECTED and peer.get_channels()>5:
   targets.append(id)
 return targets

func publish_committed_cleanup(game: Node, transport: ENetMultiplayerPeer) -> void:
 var tx=preload("res://game_transaction.gd")
 if not is_instance_valid(game) or not game.is_inside_tree() or transport==null or game.online_peer!=transport:
  return
 if game.get_meta(tx.STOPPING,false) or not game.has_meta(tx.SESSION) or not game.get_meta(tx.SESSION).owns_leases():
  return
 game.send_expedition_state(0.0,true)

func observe(game: Node) -> void:
 var changes={}
 for id in game.players:
  var p=game.players[id]
  var signature=str([p.hp,p.get("max_hp",10),p.wild,p.fallen,p.get("lost_health",0),p.get("damage_seq",0)])
  if server_vitals.get(id,{}).get("signature","")==signature:continue
  var revision=int(server_vitals.get(id,{}).get("revision",0))+1
  var state={"revision":revision,"hp":p.hp,"max_hp":p.get("max_hp",10),"fallen":p.fallen,"lost_health":p.get("lost_health",0),"damage_seq":p.get("damage_seq",0),"damage_amount":p.get("damage_amount",0)}
  server_vitals[id]={"signature":signature,"revision":revision};p.vitals_revision=revision;changes[id]=state
 if not changes.is_empty():
  for id in snapshot_targets(game):
   game.receive_vitals.rpc_id(id,changes)
func accept_sequence(sequence: int) -> bool:
 if sequence<0:return true # Explicit local fixtures, never transmitted by the host.
 if sequence<=snapshot_received:rejected_snapshots+=1;return false
 if snapshot_received>=0:snapshot_gaps+=maxi(0,sequence-snapshot_received-1)
 snapshot_received=sequence;return true
func merge_health(id: int,player: Dictionary) -> void:
 var revision=int(player.get("vitals_revision",0))
 if revision>int(client_vitals.get(id,{}).get("revision",-1)):
  accept_vital(id,{"revision":revision,"hp":player.hp,"max_hp":player.get("max_hp",10),"fallen":player.get("fallen",false),"lost_health":player.get("lost_health",0),"damage_seq":player.get("damage_seq",0),"damage_amount":player.get("damage_amount",0)})
 if client_vitals.has(id):
  var state=client_vitals[id]
  if int(state.revision)>=revision:
   player.hp=state.hp;player.max_hp=state.max_hp;player.damage_seq=state.damage_seq
   player.vitals_revision=state.revision;player.damage_amount=state.get("damage_amount",0)
   if state.has("fallen"): player.fallen=state.fallen
   if state.has("lost_health"): player.lost_health=state.lost_health
 player.client_hurt_until=int(flash_until.get(id,0))
func accept_vital(id: int,state: Dictionary) -> void:
 var previous=client_vitals.get(id,{})
 if int(state.get("revision",0))<=int(previous.get("revision",-1)):return
 if not previous.is_empty() and int(state.get("damage_seq",0))>int(previous.get("damage_seq",0)):
  flash_until[id]=Time.get_ticks_msec()+250
 client_vitals[id]=state.duplicate(true)
func receive(game: Node,states: Dictionary) -> void:
 preload("res://diagnostic_journal.gd").event("network","vitals_received",{"states":states,"snapshot_sequence":snapshot_received})
 for id in states:
  if not states[id] is Dictionary:continue
  accept_vital(int(id),states[id])
  if game.players.has(id):merge_health(int(id),game.players[id])
