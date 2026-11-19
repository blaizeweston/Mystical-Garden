extends Node
const Journal=preload("res://diagnostic_journal.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")
var game: Node
var world_session: String
var clock:=0.0
var sample_clock:=0.0
var previous: Dictionary={}
var previous_context: Dictionary={}
var previous_garden: Dictionary={}
var last_sequence:=-1
var last_packet_at:=0
var stall_reported:=false
func _ready() -> void:
 world_session=Crypto.new().generate_random_bytes(8).hex_encode()
 Journal.event("world","attached",{"world_session":world_session,"world_slot":game.active_slot,"character_slot":game.active_character_slot})
 tick(true)
func _process(delta: float) -> void:
 clock+=delta;sample_clock+=delta
 if clock<.25:return
 clock=0;tick(sample_clock>=2)
 if sample_clock>=2:sample_clock=0
func tick(sample: bool=false) -> void:
 var journal=Journal.current
 if not is_instance_valid(journal) or not is_instance_valid(game):return
 var role: String=game.network_session.role();var peer: int=game.multiplayer.get_unique_id()
 var host: Dictionary=game.players.get(1,{})
 var context={"role":role,"peer":peer,"host_session":journal.session_id if game.multiplayer.is_server() else host.get("diagnostic_host",""),"world_session":world_session if game.multiplayer.is_server() else host.get("diagnostic_world",""),"floor":game.participation.floor(),"biome":game.participation.route(),"map_seed":game.participation.seed(),"cycle":game.participation.cycle(),"combat_epoch":game.participation.epoch()}
 journal.set_context(context)
 if context!=previous_context:Journal.event("world","context_changed",context);previous_context=context.duplicate()
 var garden=Journal.garden_state(game)
 var garden_bucket=garden.duplicate(true)
 garden_bucket.work_seconds=5*int(int(garden.get("work_seconds",0))/5)
 if garden_bucket!=previous_garden:Journal.event("progression","garden_changed",garden_bucket);previous_garden=garden_bucket
 for id in game.players:
  var p: Dictionary=game.players[id];var state=Journal.player_state(p,game.replication.health_revision(id) if game.multiplayer.is_server() else -1);var old: Dictionary=previous.get(id,{})
  var changed={}
  for key in state:
   if key in ["pos","skill_at","skill_two_at","attack_combo"]:continue
   if old.get(key)!=state[key]:changed[key]={"before":old.get(key),"after":state[key]}
  if not changed.is_empty():Journal.event("state","player_changed",{"actor":id,"changes":changed,"hp_per_point":game.Life.Preview.scale()})
  if journal.detail and old.get("attack_combo")!=state.get("attack_combo"):Journal.event("combat","attack_sequence",{"actor":id,"combo":state.get("attack_combo"),"weapon_kind":p.get("weapon_kind",0),"facing":p.get("facing",Vector3.ZERO)})
  previous[id]=state.duplicate(true)
 for id in previous.keys():
  if not game.players.has(id):Journal.event("network","peer_removed",{"actor":id});previous.erase(id)
 var now:=Time.get_ticks_msec();var sequence: int=game.guest_replication.sequence()
 if role=="Guest":
  if sequence!=last_sequence:last_packet_at=now;last_sequence=sequence;stall_reported=false
  elif last_packet_at>0 and now-last_packet_at>3000 and not stall_reported:
   stall_reported=true;Journal.event("network","snapshot_stall",{"last_sequence":sequence,"silence_ms":now-last_packet_at},"warning")
 if sample:
  var transport={}
  if game.network_session.transport()!=null and game.network_session.transport().get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:
   for id in (game.multiplayer.get_peers() if game.multiplayer.is_server() else PackedInt32Array([1])):
    var packet: ENetPacketPeer=game.network_session.transport().get_peer(int(id))
    if packet!=null and packet.is_active():transport[id]={"rtt_ms":packet.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME),"enet_reliable_loss_percent_estimate":100.0*packet.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)/ENetPacketPeer.PACKET_LOSS_SCALE,"loss_epoch_ms":packet.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS_EPOCH)}
  var positions={}
  for id in game.players:
   var actor: Dictionary = game.players[id]
   positions[id]={"pos":actor.get("pos",Vector3.ZERO),"hp":PlayerVitals.current_hp(actor),"max_hp":PlayerVitals.maximum_hp(actor,0),
    "lost_health":actor.get("lost_health",0),"fallen":PlayerLifecycle.fallen(actor),"damage_seq":actor.get("damage_seq",0),"vitals_revision":game.replication.health_revision(id) if game.multiplayer.is_server() else actor.get("vitals_revision",0)}
  Journal.event("network","sample",{"transport":transport,"rejected_snapshots":game.guest_replication.rejected_count(),"snapshot_gaps":game.guest_replication.gap_count(),"sent_sequence":game.replication.sequence(),"received_sequence":sequence,"players":positions,"living_enemies":game.living_scout_count()+int(game.enemy_health()>0),"pending_projectiles":game.weapon_attacks.pending_count(),"movement_timing":game.net_motion.sample(),"fps":Engine.get_frames_per_second()})
func _exit_tree() -> void:
 Journal.event("world","detached",{"world_session":world_session})
 if is_instance_valid(Journal.current):Journal.current.set_context({"role":"Menu"})
