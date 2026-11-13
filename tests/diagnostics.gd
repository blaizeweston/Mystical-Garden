extends SceneTree
const Journal=preload("res://diagnostic_journal.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL diagnostics: ",message)
func _initialize() -> void:call_deferred("run")
func rows(journal: Logger) -> Array:
 var result: Array=[];var folder=DirAccess.open(journal.directory)
 var names=folder.get_files();names.sort()
 for name in names:
  if not name.ends_with(".jsonl"):continue
  for line in FileAccess.get_file_as_string(journal.directory.path_join(name)).split("\n",false):
   var row=JSON.parse_string(line)
   check(row is Dictionary,"each flushed record is valid JSON")
   if row is Dictionary:result.append(row)
 return result
func run() -> void:
 var base="res://.godot/diagnostic-test-"+Crypto.new().generate_random_bytes(8).hex_encode();DirAccess.make_dir_recursive_absolute(base)
 var log=Journal.new();check(log.start(base)==OK,"session starts")
 log.set_context({"role":"Guest","peer":42,"host_session":"host-example","world_session":"world-example"})
 log.record("test","payload",{"hp":8,"pos":Vector3(1,0,2),"identity":"a".repeat(32),"name":"Private name","address":"192.168.1.2","note":"192.168.1.2 "+OS.get_environment("USERPROFILE")})
 var entries=rows(log);var entry: Dictionary=entries.back()
 check(entry.context.host_session=="host-example" and entry.context.peer==42 and entry.data.hp==8 and Vector3(entry.data.pos[0],entry.data.pos[1],entry.data.pos[2])==Vector3(1,0,2),"structured context, state, UTC and local sequence")
 check(not entry.data.has("identity") and not entry.data.has("name") and not entry.data.has("address") and not str(entry.data.note).contains("192.168.1.2"),"identity/name/address fields omitted and text addresses redacted")
 var threads: Array=[]
 for worker in 2:
  var thread=Thread.new();thread.start(func():
   for index in 20:log.record("thread","record",{"worker":worker,"index":index}))
  threads.append(thread)
 for thread in threads:thread.wait_to_finish()
 entries=rows(log);var sequences={}
 for row in entries:sequences[row.seq]=true
 check(entries.size()==42 and sequences.size()==entries.size(),"concurrent writes are serialized without interleaving")
 OS.add_logger(log);push_warning("Intentional diagnostic capture test");OS.remove_logger(log)
 check(rows(log).any(func(row):return row.event=="warning" and str(row.data.get("message","")).contains("Intentional diagnostic capture test")),"engine warning callback is saved")
 var other=Journal.new();check(other.start(base)==OK and other.session_id!=log.session_id,"simultaneous instances have distinct files")
 other.metadata.pid=0;other.status_file();other.record("test","before_forced_exit");other.file.close();other.file=null;other.enabled=false
 var report: String=log.export_report();check(not report.is_empty(),"report exports")
 var zip=ZIPReader.new();check(zip.open(report)==OK,"export is readable ZIP")
 var files=Array(zip.get_files());check(files.has("README.txt") and files.has(log.session_id+"/session.json") and files.has(other.session_id+"/session.json"),"report includes current and recent unclean session")
 check(not files.any(func(path):return path.ends_with("character.cfg") or path.ends_with("garden.cfg")),"report contains no save files")
 zip.close();log.finish();check(JSON.parse_string(FileAccess.get_file_as_string(log.directory.path_join("session.json"))).clean_exit,"normal exit marked")
 var limited=Journal.new();limited.start(base+"-rotation",2048,3)
 for index in 70:limited.record("test","rotate",{"index":index,"note":"x".repeat(100)})
 var chunks=Array(DirAccess.open(limited.directory).get_files()).filter(func(name):return name.ends_with(".jsonl"))
 check(chunks.size()<=3 and rows(limited).back().data.index==69,"rolling chunks retain newest events and bound disk usage")
 limited.burst_second=int(Time.get_ticks_msec()/1000);limited.burst_count=160
 check(limited.record("test","rate_limited")==0,"routine event floods are bounded")
 check(limited.record("engine","critical_after_flood",{},"error")>0,"error budget survives routine floods")
 limited.burst_second=-1;limited.record("test","oversized",{"note":"x".repeat(20000)})
 check(rows(limited).back().data.get("truncated",false),"oversized lines are bounded")
 limited.finish()
 var retention_root=base+"-retention";var active=Journal.new();active.start(retention_root)
 for index in 12:
  var completed=Journal.new();completed.start(retention_root);completed.finish()
 check(DirAccess.dir_exists_absolute(active.directory) and DirAccess.open(retention_root).get_directories().size()<=10,"retention protects active sessions and bounds old sessions")
 active.finish()
 var restart=Journal.new();restart.start(base)
 check(rows(restart).any(func(row):return row.event=="previous_unclean_exit" and row.data.previous_session==other.session_id),"restart points to the previous unclean session")
 restart.finish()
 var broken=Journal.new();var blocker=FileAccess.open(base+"-file",FileAccess.WRITE);blocker.store_string("not a folder");blocker.close()
 # This exact, unique path may produce one engine error during the blocked-directory probe.
 set_meta(&"validation_expected_engine_errors", ["Could not create directory: '%s'." % (base+"-file/blocked")])
 check(broken.start(base+"-file/blocked")!=OK and broken.record("test","ignored")==0,"unwritable logs fail independently of gameplay")
 await child_check(base,"error")
 await child_check(base,"kill")
 var game=load("res://world.tscn").instantiate();game.progress.path=base+".world";game.local_character.path=base+".character";root.add_child(game);game.set_physics_process(false);game.set_process(false)
 var global_log=Journal.current;var before: int=global_log.sequence
 game.garden_action(1,"unknown_action")
 var global_rows=rows(global_log).filter(func(row):return row.seq>before)
 check(global_rows.any(func(row):return row.event=="action_begin") and global_rows.any(func(row):return row.event=="action_end"),"interaction begin/end breadcrumbs")
 var panel=load("res://diagnostics_panel.gd").new();root.add_child(panel);panel.note.text="test marker";panel.mark_issue()
 check(panel.status.text.contains("Issue marked"),"player can mark an issue from settings")
 panel.free();game.free()
 if not failed:print("PASS: saved diagnostics, thread safety, privacy, rotation, report export, real engine error, abrupt termination and interaction breadcrumbs")
 quit(1 if failed else 0)
func child_check(base: String,mode: String) -> void:
 var script=base+"-"+mode+".gd";var source="extends SceneTree\nvar log\nfunc _initialize():call_deferred('run')\nfunc run():\n log=load('res://diagnostic_journal.gd').new();log.start('"+base+"-child-"+mode+"')\n OS.add_logger(log)\n log.record('test','checkpoint_before_problem');log.status_file()\n"
 if mode=="kill":source+=" OS.kill(OS.get_process_id())\n"
 else:source+=" fail.call_deferred()\n await create_timer(.1).timeout\n OS.remove_logger(log);log.finish();quit()\nfunc fail():\n var missing=null\n missing.no_such_method()\n"
 var file=FileAccess.open(script,FileAccess.WRITE);file.store_string(source);file.close()
 var args: Array[String]=["--headless","--script",ProjectSettings.globalize_path(script),"--quit-after","240"]
 var source_root=ProjectSettings.globalize_path("res://")
 if not source_root.is_empty():args.append_array(["--path",source_root])
 elif OS.has_feature("editor"):
  var pack:=OS.get_environment("MYSTICAL_VALIDATION_PACK")
  check(not pack.is_empty() and FileAccess.file_exists(pack),"packaged child has the exact tested pack")
  if pack.is_empty() or not FileAccess.file_exists(pack):return
  args.append_array(["--path",str(get_script().resource_path).get_base_dir(),"--main-pack",pack])
 # This test deliberately kills one child and handles a script error in another.
 var output: Array=[];var exit_code:=OS.execute(OS.get_executable_path(),args,output,true)
 check(exit_code!=-1 and (mode=="kill" or exit_code==0),"fault child launched and the handled exception child exited normally: "+mode)
 var folder=DirAccess.open(base+"-child-"+mode)
 check(folder!=null,"child diagnostic directory exists: "+mode)
 if folder==null:return
 var children=folder.get_directories();check(not children.is_empty(),"child records session: "+mode)
 if children.is_empty():return
 var path=(base+"-child-"+mode).path_join(children[0]);var meta=JSON.parse_string(FileAccess.get_file_as_string(path.path_join("session.json")));var text=FileAccess.get_file_as_string(path.path_join("events-000001.jsonl"))
 check(meta.get("protocol")==Journal.current.metadata.protocol and meta.get("build",{}).get("built_utc")==Journal.current.metadata.build.get("built_utc"),"child loaded the matching game build")
 if mode=="kill":check(not meta.clean_exit and text.contains("checkpoint_before_problem") and not text.contains('"event":"ended"'),"forced process termination preserves flushed breadcrumbs and unclean marker")
 else:
  var captured=false
  for line in text.split("\n",false):
   var row=JSON.parse_string(line)
   if row is Dictionary and row.get("event")=="script_error":captured=captured or row.data.get("stack",[]).any(func(frame):return frame.get("function")=="fail")
  check(captured,"real script exception records source, function and a nonempty stack in child process")
