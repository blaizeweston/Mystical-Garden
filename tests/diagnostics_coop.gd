extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const Journal=preload("res://diagnostic_journal.gd")
var game: Node
var role: String
var base: String
var failed=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL diagnostics co-op ",role,": ",message)
func mark(key: String):
 var f=FileAccess.open(base+key,FileAccess.WRITE);f.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+key)
func until(predicate: Callable) -> bool:
 var deadline=Time.get_ticks_msec()+18000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func _initialize():call_deferred("run")
func run():
 role=OS.get_cmdline_user_args()[0];base="res://.godot/diagnostic-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role;game.local_character.path=base+role+".character";game.guest_character.path=base+role+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 game.free()
 if not failed:print("PASS: diagnostics co-op ",role," host/guest correlation, authoritative damage, reliable vitals, user markers and readable report")
 quit(1 if failed else 0)
func host_run():
 check(game.session_world.host()==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return SessionCase.Session.ready_for(p))):check(false,"registration");return
 var id=game.players.keys().filter(func(i):return i!=1)[0];var p: Dictionary=game.players[id]
 ExpeditionCase.set_membership(game, p, true);p[PlayerVitals.STATE]=p[PlayerVitals.STATE].with_hp(10);p.pos=Vector3.ZERO;game.encounter.set_hp(-1, 0);game.encounter.clear_scouts();game.progress.knowledge=47
 IncomingPlayerHit.apply_health_loss(game, id, PlayerLifecycle.generation(p), 1);game.replication.observe_health(game.replication_source);game.diagnostic_watch.tick(true)
 mark("damage");check(await until(func():return marked("guest_verified")),"guest validates log")
 check(PlayerVitals.current_hp(p)==9,"authoritative one point damage")
 Journal.event("diagnostics","user_issue",{"note":"co-op host marker"})
 check(not Journal.current.export_report().is_empty(),"host report exports")
 mark("done");check(await until(func():return game.players.size()==1),"guest disconnects")
func guest_run():
 game.guest_character.save_profile();check(game.session_world.join()==OK,"guest joins")
 if not await until(func():return game.network_session.role()=="Guest" and game.players.has(1) and not str(game.players[1].get("diagnostic_host","")).is_empty()):check(false,"host correlation arrives");return
 var id=game.multiplayer.get_unique_id()
 check(await until(func():return marked("damage") and game.players.get(id,{}).get("hp",10)==9 and game.guest_replication.garden_progress().size()>16 and game.guest_replication.garden_progress()[6]==47),"reliable damage reaches guest")
 game.diagnostic_watch.tick(true)
 check(Journal.garden_state(game).get("source")=="host_snapshot" and Journal.garden_state(game).get("knowledge")==47,"guest diagnostics use authoritative received Garden values")
 var context: Dictionary=Journal.current.context
 check(context.host_session==game.players[1].diagnostic_host and context.world_session==game.players[1].diagnostic_world and context.host_session!=Journal.current.session_id,"shared host/world IDs across separate local sessions")
 var report: String=Journal.current.export_report();var zip=ZIPReader.new();check(zip.open(report)==OK,"guest report readable")
 var text=""
 for path in zip.get_files():
  if path.begins_with(Journal.current.session_id+"/") and path.ends_with(".jsonl"):text+=zip.read_file(path).get_string_from_utf8()
 zip.close();check(text.contains('"rtt_ms"') and text.contains('"event":"vitals_received"') and text.contains('"host_session":"'+context.host_session+'"'),"guest report has vitals and host correlation")
 mark("guest_verified");check(await until(func():return marked("done")),"host finished");game.session_world.leave("Diagnostics fixture")
