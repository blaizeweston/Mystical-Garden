extends Node
# Test-only synchronization; all admission, movement and snapshots use game.gd.
const Network=preload("res://network_settings.gd")
const MOVE_THRESHOLD=.3
var role="host"
var index=0
var guests=3
var port=24600
var address="127.0.0.1"
var play_ms=2500
var timeout_ms=20000
var run_id=""
var save_root=""
var report_dir=""
var packaged=false
var game: Node
var phase="boot"
var deadline=0
var started=0
var finished=false
var ready_peers={}
var reports={}
var acknowledgments={}
var traces={}
var samples=0
var last_snapshot=-1
var snapshots=0
var first_joint=Quaternion.IDENTITY
var joint_seen=false
var joint_excursion=0.0
var peak_pace=0.0
var own_metrics={}
var group_passed=false
var group_message=""
var held_action=""
var closing_queue: Array=[]
var closing_peer=0
func _ready() -> void:
 var error=parse_args()
 if not error.is_empty():finish(3,error);return
 if DirAccess.make_dir_recursive_absolute(save_root)!=OK or DirAccess.make_dir_recursive_absolute(report_dir)!=OK:finish(3,"Cannot create isolated test directories");return
 if packaged and (FileAccess.file_exists("res://test/net_test.gd") or FileAccess.file_exists("res://test/net_test.tscn")):
  finish(3,"Shipping pack contains test harness resources");return
 var scene=load("res://world.tscn")
 if scene==null:finish(3,"Missing world scene");return
 game=scene.instantiate()
 var peer_dir=save_root.path_join(role+"-"+str(index))
 DirAccess.make_dir_recursive_absolute(peer_dir)
 game.progress.path=peer_dir.path_join("garden.cfg")
 game.local_character.path=peer_dir.path_join("local.cfg")
 game.guest_character.path=peer_dir.path_join("guest.cfg")
 game.slot_storage_root=peer_dir.path_join("world-slots");game.character_storage_root=peer_dir.path_join("characters")
 game.active_slot=-1;game.active_character_slot=-1;game.slot_claimed=false;game.character_slot_claimed=false
 game.local_character.identity=(run_id+"-local-"+role+str(index)).md5_text()
 game.guest_character.identity=(run_id+"-guest-"+str(index)).md5_text()
 game.local_character.data.name="Test Host";game.guest_character.data.name="Test Guest "+str(index+1)
 add_child(game)
 if game.local_character.save_profile()!=OK or game.guest_character.save_profile()!=OK:finish(3,"Could not save isolated test profiles");return
 phase="connecting";deadline=Time.get_ticks_msec()+timeout_ms
 var code=game.host_game(port) if role=="host" else game.join_game(address,port)
 if code!=OK:finish(3,"Cannot start %s on UDP %d (error %d)"%[role,port,code]);return
 log_line("protocol=%d role=%s guests=%d address=%s port=%d run=%s"%[Network.PROTOCOL,role,guests,address,port,run_id])
 if role=="host":write_json("host.ready.json",{"run_id":run_id,"port":port,"protocol":Network.PROTOCOL})
func _process(_delta: float) -> void:
 if finished or game==null:return
 var now=Time.get_ticks_msec()
 if now>deadline:finish(2,"Timed out in %s: %s"%[phase,game.status]);return
 if role=="guest" and phase!="connecting" and game.session!="Guest":finish(1,"Lost host during "+phase+": "+game.status);return
 if role=="guest" and phase=="connecting":
  var id=game.multiplayer.get_unique_id()
  if game.session=="Solo":finish(1,"Connection failed: "+game.status);return
  if game.session=="Guest" and game.players.has(id) and game.players.size()==guests+1 and not game.client_details.is_empty():
   phase="waiting_start";deadline=now+timeout_ms
   peer_ready.rpc_id(1,run_id,index)
 if role=="host" and phase=="connecting" and ready_peers.size()==guests and game.players.size()==guests+1:
  begin_play.rpc(run_id);begin_play(run_id)
 if phase=="playing":
  steer(now-started);observe()
  if now-started>=play_ms:
   release_input();own_metrics=metrics();phase="collecting" if role=="host" else "waiting_verdict";deadline=now+timeout_ms
   if role=="guest":peer_report.rpc_id(1,run_id,own_metrics)
 if role=="host" and phase=="collecting" and reports.size()==guests:judge()
 if role=="host" and phase=="verdict" and acknowledgments.size()==guests:
  phase="closing";stop_fixture();closing_queue=ready_peers.keys();deadline=now+timeout_ms
 if role=="host" and phase=="closing" and (closing_peer==0 or not game.multiplayer.get_peers().has(closing_peer)):
  if closing_queue.is_empty():finish(0 if group_passed else 1,group_message)
  else:closing_peer=int(closing_queue.pop_front());shutdown.rpc_id(closing_peer,run_id)
func observe() -> void:
 samples+=1
 for id in game.players:
  var p=game.players[id]
  if not p.has("pos"):continue
  if not traces.has(id):traces[id]={"last":p.pos,"distance":0.0,"updates":0}
  var trace=traces[id];var distance=trace.last.distance_to(p.pos)
  if distance>.00001:trace.updates+=1;trace.distance+=distance
  trace.last=p.pos
 var id=game.multiplayer.get_unique_id()
 if game.stage.avatar_models.has(id):
  var actor=game.stage.avatar_models[id]
  var rig: Skeleton3D=actor.field_rig.skeleton
  var joint:=rig.get_bone_pose_rotation(rig.find_bone("thigh_l"))
  if not joint_seen:first_joint=joint;joint_seen=true
  joint_excursion=maxf(joint_excursion,first_joint.angle_to(joint));peak_pace=maxf(peak_pace,float(actor.pace))
 if role=="guest" and game.net_view.snapshot_received!=last_snapshot:
  snapshots+=1;last_snapshot=game.net_view.snapshot_received
func metrics() -> Dictionary:
 var paths={}
 for id in traces:paths[str(id)]={"distance":traces[id].distance,"updates":traces[id].updates}
 var id=game.multiplayer.get_unique_id();var slots=[];var privacy=true
 for peer in game.players:
  slots.append(int(game.players[peer].get("party_slot",-1)))
  if role=="guest" and peer!=id and game.players[peer].has("bag"):privacy=false
 return {"peer":id,"samples":samples,"paths":paths,"snapshot_updates":snapshots,"joint_excursion":joint_excursion,"peak_pace":peak_pace,"details":not game.client_details.is_empty(),"party_size":game.players.size(),"party_slots":slots,"private_inventory":privacy,"still_connected":game.session==("Host" if role=="host" else "Guest")}
func problems(data: Dictionary,guest: bool) -> Array[String]:
 var errors: Array[String]=[]
 if not data.get("still_connected",false):errors.append("connection lost")
 if int(data.get("party_size",0))!=guests+1:errors.append("party size changed")
 var slots=data.get("party_slots",[])
 for i in range(guests+1):
  if slots.count(i)!=1:errors.append("missing or duplicate party slot "+str(i))
 var paths=data.get("paths",{})
 if paths.size()!=guests+1:errors.append("missing movement observations")
 for peer in paths:
  if float(paths[peer].get("distance",0))<MOVE_THRESHOLD or int(paths[peer].get("updates",0))<3:errors.append("peer "+str(peer)+" did not synchronize movement")
 if float(data.get("joint_excursion",0))<.15 or float(data.get("peak_pace",0))<.2:errors.append("walking joints did not animate")
 if guest:
  if int(data.get("snapshot_updates",0))<3:errors.append("missing frequent snapshots")
  if not data.get("details",false):errors.append("missing reliable owner details")
  if not data.get("private_inventory",false):errors.append("another player's inventory leaked")
 return errors
func judge() -> void:
 var errors=problems(own_metrics,false)
 if game.players.size()!=guests+1:errors.append("peer left before host verification")
 for id in reports:
  for issue in problems(reports[id],true):errors.append("peer %d: %s"%[id,issue])
 group_passed=errors.is_empty();group_message="host and %d guests synchronized movement, walking and owner details"%guests if group_passed else "; ".join(errors)
 phase="verdict";deadline=Time.get_ticks_msec()+timeout_ms
 verdict.rpc(run_id,group_passed,group_message)
@rpc("any_peer","call_remote","reliable",2)
func peer_ready(tag: String,guest_index: int) -> void:
 if role!="host" or phase!="connecting":return
 var id=multiplayer.get_remote_sender_id()
 if tag!=run_id or guest_index<0 or guest_index>=guests or ready_peers.values().has(guest_index):finish(1,"Unexpected or duplicate test peer");return
 if not game.players.has(id) or not game.players[id].profile_ready:finish(1,"Peer bypassed game admission");return
 ready_peers[id]=guest_index
@rpc("authority","call_remote","reliable",2)
func begin_play(tag: String) -> void:
 if tag!=run_id or phase not in ["connecting","waiting_start"]:return
 phase="playing";started=Time.get_ticks_msec();deadline=started+play_ms+timeout_ms
 traces.clear();observe();steer(0)
@rpc("any_peer","call_remote","reliable",2)
func peer_report(tag: String,data: Dictionary) -> void:
 var id=multiplayer.get_remote_sender_id()
 if role!="host" or tag!=run_id or not ready_peers.has(id) or int(data.get("peer",0))!=id:return
 reports[id]=data
@rpc("authority","call_remote","reliable",2)
func verdict(tag: String,passed: bool,message: String) -> void:
 if role!="guest" or tag!=run_id or phase!="waiting_verdict":return
 group_passed=passed;group_message=message;phase="waiting_shutdown";deadline=Time.get_ticks_msec()+timeout_ms
 verdict_ack.rpc_id(1,run_id);stop_fixture()
@rpc("any_peer","call_remote","reliable",2)
func verdict_ack(tag: String) -> void:
 var id=multiplayer.get_remote_sender_id()
 if role=="host" and tag==run_id and ready_peers.has(id):acknowledgments[id]=true
@rpc("authority","call_remote","reliable",2)
func shutdown(tag: String) -> void:
 if tag==run_id and role=="guest" and phase=="waiting_shutdown":finish(0 if group_passed else 1,group_message)
func steer(elapsed_ms: int) -> void:
 var directions=["right","down","left","up"]
 var wanted: String=directions[(elapsed_ms/700+(0 if role=="host" else index+1))%4]
 if wanted!=held_action:release_input();Input.action_press(wanted);held_action=wanted
func release_input() -> void:
 for action in ["right","down","left","up"]:
  if InputMap.has_action(action):Input.action_release(action)
 held_action=""
func parse_args() -> String:
 var args=OS.get_cmdline_user_args();var options={};var i=0
 while i<args.size():
  if i+1>=args.size():return "Missing value for "+args[i]
  options[args[i]]=args[i+1];i+=2
 role=options.get("--role","host");run_id=options.get("--run-id","");address=Network.address(options.get("--address","127.0.0.1"))
 for key in ["--index","--guests","--port","--play-ms","--timeout-ms"]:
  if options.has(key) and not str(options[key]).is_valid_int():return "Invalid integer: "+key
 index=int(options.get("--index",0));guests=int(options.get("--guests",3));port=int(options.get("--port",24600));play_ms=int(options.get("--play-ms",2500));timeout_ms=int(options.get("--timeout-ms",20000))
 var regex=RegEx.new();regex.compile("^[A-Za-z0-9_-]{1,80}$")
 if regex.search(run_id)==null:return "Supply an alphanumeric --run-id (1-80 characters)"
 if role not in ["host","guest"] or guests<1 or guests>=Network.MAX_PLAYERS or index<0 or index>=guests:return "Invalid role, guest count or guest index"
 if not Network.error(address,port).is_empty():return Network.error(address,port)
 if play_ms<500 or timeout_ms<1000:return "Play/timeout durations too short"
 report_dir=options.get("--report-dir","user://nettest/"+run_id);save_root=options.get("--save-root",report_dir.path_join("saves"));packaged=options.get("--packaged","false")=="true"
 return ""
func write_json(name: String,data: Dictionary) -> void:
 var file=FileAccess.open(report_dir.path_join(name),FileAccess.WRITE)
 if file:file.store_string(JSON.stringify(data,"  "))
func log_line(message: String) -> void:print("NETTEST [%s#%d] %s"%[role,index,message])
func stop_fixture() -> void:
 # Stop fixture traffic before its coordinated shutdown. Actual leave/reconnect
 # behavior is covered by direct_ip_coop and four_players_coop, not this smoke.
 if game==null:return
 game.set_process(false);game.set_physics_process(false)
 if game.multiplayer.peer_disconnected.is_connected(game.remove_player):game.multiplayer.peer_disconnected.disconnect(game.remove_player)
 if game.multiplayer.peer_connected.is_connected(game.add_player):game.multiplayer.peer_connected.disconnect(game.add_player)
func finish(code: int,message: String) -> void:
 if finished:return
 finished=true;release_input()
 var status="PASS" if code==0 else "FAIL"
 var report={"schema":3,"fixture":"supplied_network_smoke","run_id":run_id,"role":role,"index":index,"status":status,"exit":code,"message":message,"protocol":Network.PROTOCOL,"pid":OS.get_process_id(),"guests_expected":guests,"port":port,"address":address,"packaged":packaged,"metrics":own_metrics,"guest_reports":reports}
 if not report_dir.is_empty():write_json("result_%s_%d.json"%[role,index],report)
 log_line("RESULT %s (exit=%d) %s"%[status,code,message])
 if game!=null:
  stop_fixture()
  game.leave_game("Network test complete");game.queue_free()
 get_tree().create_timer(.15).timeout.connect(func():get_tree().quit(code))
