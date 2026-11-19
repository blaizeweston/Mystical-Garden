extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Pressure=preload("res://expedition_pressure.gd")
var game: Node
var base: String
var role: String
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL reinforcement co-op ",role,": ",message)
func mark(key: String) -> void:
 var file:=FileAccess.open(base+key,FileAccess.WRITE);file.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+key)
func until(predicate: Callable) -> bool:
 var end:=Time.get_ticks_msec()+18000
 while not predicate.call() and Time.get_ticks_msec()<end:
  if role=="host" and not game.is_physics_processing():
   game.send_expedition_state(0,true)
  await create_timer(.05).timeout
 return predicate.call()
func _initialize() -> void:call_deferred("run")
func run() -> void:
 role=OS.get_cmdline_user_args()[0]
 base="user://release-fixtures/pressure-net-"+OS.get_cmdline_user_args()[1]+"/"
 DirAccess.make_dir_recursive_absolute(base)
 game=load("res://world.tscn").instantiate();game.progress.path=base+role+".garden";game.local_character.path=base+role+".character";game.guest_character.path=base+role+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 game.free()
 if not failed:print("PASS: reinforcement co-op ",role," warning replication, authoritative arrival, clear cancellation and unchanged health")
 quit(1 if failed else 0)
func host_run() -> void:
 check(SessionCase.World.host(game)==OK,"host opens")
 print("pressure host awaiting admission")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return SessionCase.Session.ready_for(p))):check(false,"admission");return
 game.set_physics_process(false)
 print("pressure host admitted")
 ExpeditionCase.set_world(game, {"destination": 0});ExpeditionCase.set_world(game, {"encounter_number": 19});ExpeditionCase.set_world(game, {"depth": 1});ExpeditionCase.set_world(game, {"difficulty_cycle": 1});ExpeditionCase.set_world(game, {"map_seed": 91273});game.reset_encounter();game.encounter.clear_scouts();game.encounter.set_hp(-1, 10)
 for p in game.players.values():ExpeditionCase.set_membership(game, p, true);p[PlayerLifecycle.STATE] = p[PlayerLifecycle.STATE].clear_inactive();p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10);p.pos=game.battlefield.entry
 var now:=Time.get_ticks_msec();game.pressure_at=now;game.update_pressure(now)
 check(not Pressure.hints(game).is_empty(),"host plans warning")
 print("pressure host warning ready")
 mark("warning")
 check(await until(func():return marked("seen")),"guest saw warning")
 game.update_pressure(game.pressure_at)
 check(game.encounter.scout_count()==1,"host emits one wave")
 mark("spawned")
 check(await until(func():return marked("arrived")),"guest saw arrival")
 for slot in game.encounter.scout_count():game.encounter.set_hp(slot, 0)
 game.pressure_at=Time.get_ticks_msec();game.encounter.set_hp(-1, 10);game.update_pressure(game.pressure_at)
 game.encounter.set_hp(-1, 0);game.update_pressure(game.pressure_at)
 check(game.encounter_cleared() and Pressure.hints(game).is_empty(),"clear cancels pending wave")
 mark("cleared")
 check(await until(func():return marked("done")),"guest confirmed clear")
 for p in game.players.values():check(PlayerVitals.current_hp(p)==10,"no automatic pressure damage")
func guest_run() -> void:
 check(SessionCase.World.join(game,"127.0.0.1")==OK,"guest connects")
 check(await until(func():return marked("warning") and game.client_details.get("attack_hints",[]).any(func(h):return h.role=="reinforcement")),"received warning on existing reliable owner snapshot")
 var hints: Array=game.client_details.get("attack_hints",[])
 if not hints.is_empty():check(hints.any(func(h):return h.role=="reinforcement" and h.remaining>0 and h.remaining<=3),"guest receives labeled location and countdown")
 var before: int=game.pressure_at;Pressure.tick(game,Time.get_ticks_msec()+999999)
 check(game.pressure_at==before,"guest cannot author reinforcements")
 mark("seen")
 check(await until(func():return marked("spawned") and not game.encounter_cleared() and game.client_pack.size()>=8 and game.client_pack[2]>0),"guest receives authoritative living scout")
 var id:=game.multiplayer.get_unique_id()
 check(game.players.get(id,{}).get("hp",0)==10,"guest health unchanged during pressure")
 check(await until(func():return not game.client_details.get("attack_hints",[]).any(func(h):return h.role=="reinforcement")),"spawn warning removed after arrival")
 mark("arrived")
 check(await until(func():return marked("cleared") and game.encounter_cleared()),"guest exit becomes clear without phantom pending wave")
 mark("done")
