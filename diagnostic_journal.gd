extends Logger
const Participation = preload("res://expedition_participation.gd")
# Local, bounded and independent of gameplay save transactions.
static var current: Logger
const SCHEMA:=1
const Cooldowns = preload("res://player_cooldowns.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const DEFAULT_BYTES:=1048576
const DEFAULT_CHUNKS:=4
const KEEP_SESSIONS:=8
var mutex:=Mutex.new()
var directory: String=""
var session_id: String=""
var root_path: String=""
var enabled:=false
var detail:=false
var last_error:=OK
var writing:=false
var closed:=false
var sequence:=0
var chunk:=0
var limit_bytes:=DEFAULT_BYTES
var limit_chunks:=DEFAULT_CHUNKS
var file: FileAccess
var metadata: Dictionary={}
var context: Dictionary={}
var burst_second:=-1
var burst_count:=0
var critical_count:=0
var suppressed:=0
var ip_pattern:=RegEx.new()
var identity_pattern:=RegEx.new()

static func event(category: String,kind: String,fields: Dictionary={},level: String="info") -> int:
 return current.record(category,kind,fields,level) if is_instance_valid(current) else 0

func start(path: String="user://diagnostics",bytes: int=DEFAULT_BYTES,chunks: int=DEFAULT_CHUNKS) -> Error:
 ip_pattern.compile("\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b")
 identity_pattern.compile("\\b[a-fA-F0-9]{32}\\b")
 root_path=path;limit_bytes=maxi(512,bytes);limit_chunks=maxi(1,chunks)
 session_id="session-"+Time.get_datetime_string_from_system(true).replace(":","").replace("-","")+"-"+str(OS.get_process_id())+"-"+Crypto.new().generate_random_bytes(4).hex_encode()
 directory=root_path.path_join(session_id)
 last_error=DirAccess.make_dir_recursive_absolute(directory)
 if last_error!=OK:return last_error
 metadata={"schema":SCHEMA,"session":session_id,"pid":OS.get_process_id(),"started_unix":Time.get_unix_time_from_system(),"started_utc":Time.get_datetime_string_from_system(true)+"Z","clean_exit":false,"engine":Engine.get_version_info().get("string","unknown"),"os":OS.get_name(),"protocol":preload("res://network_settings.gd").PROTOCOL,"build":{}}
 var manifest="res://assets/content/build_manifest.json"
 if FileAccess.file_exists(manifest):
  var build=JSON.parse_string(FileAccess.get_file_as_string(manifest))
  if build is Dictionary:metadata.build=build
 enabled=true;closed=false
 record("session","started",{"engine":metadata.engine,"protocol":metadata.protocol,"build":metadata.build})
 status_file();prune_sessions()
 return last_error

func sanitize(value,depth: int=0):
 if depth>5:return "<depth limit>"
 if value is String or value is StringName:
  var text=str(value).left(4096);var home=OS.get_environment("USERPROFILE")
  if not home.is_empty():text=text.replace(home,"<user>").replace(home.replace("\\","/"),"<user>")
  return identity_pattern.sub(ip_pattern.sub(text,"<address>",true),"<identity>",true)
 if value is Vector3:return [snappedf(value.x,.01),snappedf(value.y,.01),snappedf(value.z,.01)]
 if value is Vector2:return [snappedf(value.x,.01),snappedf(value.y,.01)]
 if value is Dictionary:
  var result={};var count:=0
  for key in value:
   if count>=96:result["_truncated"]=true;break
   if str(key).to_lower() in ["name","display_name","identity","seed_owner","address","ip","profile","character","path","password","token"]:continue
   result[str(key)]=sanitize(value[key],depth+1);count+=1
  return result
 if value is Array or value is PackedInt32Array or value is PackedFloat32Array or value is PackedStringArray:
  var result: Array=[]
  for item in value:
   if result.size()>=96:break
   result.append(sanitize(item,depth+1))
  return result
 if value is float:return value if is_finite(value) else str(value)
 if value==null or value is bool or value is int:return value
 return "<"+type_string(typeof(value))+">"

# Journal timestamps store whole seconds.
@warning_ignore_start("integer_division")
func record(category: String,kind: String,fields: Dictionary={},level: String="info") -> int:
 mutex.lock()
 if not enabled or closed or writing:mutex.unlock();return 0
 writing=true
 var second:=int(Time.get_ticks_msec()/1000)
 if second!=burst_second:burst_second=second;burst_count=0;critical_count=0
 var urgent:=level in ["error","warning"]
 if urgent:critical_count+=1
 else:burst_count+=1
 if (urgent and critical_count>160) or (not urgent and burst_count>160):
  suppressed+=1;writing=false;mutex.unlock();return 0
 sequence+=1
 var row={"schema":SCHEMA,"session":session_id,"seq":sequence,"utc":Time.get_datetime_string_from_system(true)+"Z","elapsed_ms":Time.get_ticks_msec(),"level":level,"category":category,"event":kind,"context":sanitize(context),"data":sanitize(fields)}
 if suppressed>0:row.suppressed_since_previous=suppressed;suppressed=0
 var text:=JSON.stringify(row)+"\n"
 if text.to_utf8_buffer().size()>mini(16384,limit_bytes):
  row.data={"truncated":true};row.context={"truncated":true};text=JSON.stringify(row)+"\n"
 if file==null or file.get_position()+text.to_utf8_buffer().size()>limit_bytes:
  if file!=null:file.flush();file.close()
  chunk+=1;file=FileAccess.open(directory.path_join("events-%06d.jsonl"%chunk),FileAccess.WRITE)
  if file==null:last_error=FileAccess.get_open_error();enabled=false
  if chunk>limit_chunks:DirAccess.remove_absolute(directory.path_join("events-%06d.jsonl"%(chunk-limit_chunks)))
 if file!=null and enabled:
  file.store_string(text);file.flush();last_error=file.get_error()
  if last_error!=OK:enabled=false
 var saved:=sequence if enabled else 0
 writing=false;mutex.unlock();return saved

@warning_ignore_restore("integer_division")
func set_context(fields: Dictionary) -> void:
 mutex.lock();context=sanitize(fields);mutex.unlock()

func status_file() -> void:
 mutex.lock()
 if not enabled or writing:mutex.unlock();return
 writing=true
 metadata.last_utc=Time.get_datetime_string_from_system(true)+"Z";metadata.last_seq=sequence;metadata.last_context=sanitize(context)
 var output=FileAccess.open(directory.path_join("session.json.tmp"),FileAccess.WRITE)
 if output!=null:
  output.store_string(JSON.stringify(metadata,"  "));output.flush();output.close()
  DirAccess.rename_absolute(directory.path_join("session.json.tmp"),directory.path_join("session.json"))
 writing=false;mutex.unlock()

func finish(reason: String="normal_exit") -> void:
 if closed:return
 record("session","ended",{"reason":reason});metadata.clean_exit=true;metadata.end_reason=reason;status_file()
 mutex.lock();closed=true
 if file!=null:file.flush();file.close();file=null
 mutex.unlock()

func sessions() -> Array:
 var result: Array=[];var folder=DirAccess.open(root_path)
 if folder==null:return result
 for child in folder.get_directories():
  if not child.begins_with("session-"):continue
  var path=root_path.path_join(child);var raw=JSON.parse_string(FileAccess.get_file_as_string(path.path_join("session.json"))) if FileAccess.file_exists(path.path_join("session.json")) else null
  if raw is Dictionary and raw.get("schema")==SCHEMA:result.append({"directory":path,"id":child,"metadata":raw})
 result.sort_custom(func(a,b):return float(a.metadata.get("started_unix",0))>float(b.metadata.get("started_unix",0)) if a.metadata.get("started_unix",0)!=b.metadata.get("started_unix",0) else a.id>b.id);return result

func inactive(entry: Dictionary) -> bool:
 return entry.directory!=directory and (bool(entry.metadata.get("clean_exit",false)) or not OS.is_process_running(int(entry.metadata.get("pid",0))))

func prune_sessions() -> void:
 var kept:=0
 for entry in sessions():
  if not inactive(entry):continue
  kept+=1
  if not entry.metadata.get("clean_exit",false) and kept<=2:record("session","previous_unclean_exit",{"previous_session":entry.id,"last_seq":entry.metadata.get("last_seq",0)},"warning")
  if kept<=KEEP_SESSIONS:continue
  # Delete only our known leaf files; never recursively delete arbitrary contents.
  var folder=DirAccess.open(entry.directory)
  if folder==null:continue
  for child in folder.get_files():
   if child in ["session.json","session.json.tmp"] or (child.begins_with("events-") and child.ends_with(".jsonl")):DirAccess.remove_absolute(str(entry.directory).path_join(child))
  DirAccess.remove_absolute(entry.directory)

func export_report() -> String:
 if directory.is_empty() or not DirAccess.dir_exists_absolute(directory):return ""
 record("diagnostics","report_requested");status_file()
 var report_root="user://diagnostic_reports"
 if DirAccess.make_dir_recursive_absolute(report_root)!=OK:return ""
 var target=report_root.path_join("garden-report-"+session_id+"-"+str(Time.get_ticks_msec())+".zip")
 var zip=ZIPPacker.new()
 if zip.open(target)!=OK:return ""
 var included: Array=[directory]
 for entry in sessions():
  if inactive(entry) and included.size()<3:included.append(entry.directory)
 var failed:=false;var snapshot: Array=[]
 mutex.lock();writing=true
 for path in included:
  var folder=DirAccess.open(path)
  if folder==null:continue
  for child in folder.get_files():
   if child!="session.json" and not (child.begins_with("events-") and child.ends_with(".jsonl")):continue
   var bytes=FileAccess.get_file_as_bytes(str(path).path_join(child))
   if bytes.is_empty():failed=true
   snapshot.append({"file":str(path).get_file()+"/"+child,"bytes":bytes})
 writing=false;mutex.unlock()
 for entry in snapshot:
  if zip.start_file(entry.file)!=OK:failed=true;break
  if zip.write_file(entry.bytes)!=OK:failed=true
  if zip.close_file()!=OK:failed=true
 var readme="Mystical Garden local diagnostic report\nContains this application session and up to two recent inactive sessions.\nMatch context.host_session and context.world_session across host/guest reports. Event seq and elapsed_ms are local; UTC clocks may differ.\nNo saves, account profiles, raw network packets or automatic uploads. An unclean exit means no normal shutdown was recorded; it is not proof of an engine crash.\nA hard process kill or power loss may leave no crash stack. Flushed breadcrumbs still describe the preceding activity.\n"
 if zip.start_file("README.txt")==OK:zip.write_file(readme.to_utf8_buffer());zip.close_file()
 else:failed=true
 if zip.close()!=OK:failed=true
 if failed:DirAccess.remove_absolute(target);return ""
 # Bound exported reports separately from rolling sessions.
 var reports=DirAccess.open(report_root).get_files();reports.sort();reports.reverse();var count:=0
 for name in reports:
  if name.begins_with("garden-report-") and name.ends_with(".zip"):
   count+=1
   if count>5:DirAccess.remove_absolute(report_root.path_join(name))
 return ProjectSettings.globalize_path(target)

func _log_message(message: String,error: bool) -> void:
 if error or detail:record("engine","stderr" if error else "stdout",{"message":message},"error" if error else "debug")

func _log_error(function: String,source: String,line: int,code: String,rationale: String,_editor_notify: bool,error_type: int,script_backtraces: Array[ScriptBacktrace]) -> void:
 var frames: Array=[]
 for trace in script_backtraces:
  for index in mini(trace.get_frame_count(),20):frames.append({"source":trace.get_frame_file(index),"function":trace.get_frame_function(index),"line":trace.get_frame_line(index)})
 record("engine","script_error" if error_type==ERROR_TYPE_SCRIPT else "warning" if error_type==ERROR_TYPE_WARNING else "error",{"function":function,"source":source,"line":line,"code":code,"message":code if rationale.is_empty() else rationale,"type":error_type,"stack":frames},"warning" if error_type==ERROR_TYPE_WARNING else "error")

static func player_state(p: Dictionary, health_revision: int = -1) -> Dictionary:
 var result={}
 for key in ["pos","lost_health","damage_seq","vitals_revision","frame","weapon_kind","weapon","secondary","catalyst","prepared","prepared_secondary","prepared_catalyst","attack_combo","carried_parts"]:
  if p.has(key):result[key]=p[key]
 if health_revision>=0:result.vitals_revision=health_revision
 if p.has(PlayerLifecycle.STATE) or p.has("fallen"):
  result.wild = Participation.is_wild(p)
  result.fallen = PlayerLifecycle.fallen(p)
 if p.has(PlayerVitals.STATE) or p.has("hp"):
  result.hp = PlayerVitals.current_hp(p)
 if p.has(PlayerVitals.STATE) or p.has("max_hp"):
  result.max_hp = PlayerVitals.maximum_hp(p)
 var cooldowns: Cooldowns.Timers = p.get(Cooldowns.STATE)
 if cooldowns != null:
  result.skill_at = cooldowns.deadline(Cooldowns.Q)
  result.skill_two_at = cooldowns.deadline(Cooldowns.R)
 result.carried_seeds=p.get("carried_seeds",[]).size();return result

static func interaction(game: Node,id: int,action: String,phase: String,request_seq: int=0) -> int:
 if is_instance_valid(game.diagnostic_watch):game.diagnostic_watch.tick()
 var info={"actor":id,"action":action.get_slice(":",0).left(80),"phase":phase,"request_seq":request_seq,"state":player_state(game.players.get(id,{}),game.replication.health_revision(id) if game.multiplayer.is_server() else -1)}
 if action.contains(":"):
  var parser := JSON.new()
  if parser.parse(action.substr(action.find(":")+1)) == OK and parser.data is Dictionary:
   var payload: Dictionary = parser.data
   for key in ["operation","source","target","item","quantity","draft","revision","id","plan"]:
    if payload.has(key):info[key]=payload[key]
 var player: Dictionary=game.players.get(id,{})
 var character: Dictionary=player.get("character",game.guest_character.data if game.network_session.role()=="Guest" else {})
 info.familiarity=character.get("plants",[])
 info.class_choices=character.get("upgrades",[])
 info.garden=garden_state(game)
 return event("interaction","action_"+phase,info)

static func garden_state(game: Node) -> Dictionary:
 if game.multiplayer.is_server():
  var heart=game.progress.heart
  return {"source":"host_authority","knowledge":game.progress.knowledge,"available":heart.available_insight(game.progress),"unlocked_count":heart.unlocked.size()}
 var garden: Array=game.guest_replication.garden_progress()
 if garden.size()>16 and garden[16] is Dictionary:
  var heart: Dictionary=garden[16]
  return {"source":"host_snapshot","knowledge":garden[6],"available":int(heart.get("insight",0)),"unlocked_count":heart.get("unlocked",[]).size()}
 return {"source":"awaiting_host"}
