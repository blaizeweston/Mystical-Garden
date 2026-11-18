extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")
const Service=preload("res://garden_growth_service.gd")
var game: Node
var role: String
var base: String
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL Garden growth co-op ",role,": ",message)
func mark(key: String) -> void:
 var file=FileAccess.open(base+"-"+key,FileAccess.WRITE);file.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+"-"+key)
func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+16000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func _initialize() -> void:call_deferred("run")
func run() -> void:
 role=OS.get_cmdline_user_args()[0];base="res://.godot/growth-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role+".cfg";game.local_character.path=base+role+".character";game.guest_character.path=base+role+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 SessionCase.World.leave(game,"Garden growth fixture complete")
 var offline := game.network_session.transport() == null and game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
 check(offline,"offline peer is installed before world removal")
 if offline:
  print("TEARDOWN: Garden growth co-op ",role," is offline before world removal")
  if role=="guest":mark("guest-offline")
  game.queue_free()
  check(await until(func():return not is_instance_valid(game)),"world is removed after network shutdown")
 if not failed:print("PASS: Garden growth co-op ",role," private queues, shared unlocks, independent skip and reconnect")
 quit(1 if failed else 0)
func host_run() -> void:
 check(SessionCase.World.host(game)==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return SessionCase.Session.ready_for(p))):check(false,"admission");return
 var id: int=game.players.keys().filter(func(peer):return peer!=1)[0]
 game.progress.heart.complete(game.progress,"plot_4");game.progress.save_garden();mark("first")
 if not await until(func():return marked("skipped") and Service.projection(game,id).pending.is_empty()):check(false,"guest acknowledgement commits");return
 check(Service.projection(game,1).pending.size()==1,"guest skipping cannot dismiss host's scene")
 game.send_garden_action("growth_ack:"+str(Service.projection(game,1).pending[0].sequence))
 game.progress.heart.complete(game.progress,"plot_5");game.progress.save_garden()
 game.send_garden_action("growth_ack:"+str(Service.projection(game,1).pending[0].sequence));mark("second")
 if not await until(func():return marked("rejoined")):check(false,"guest reconnects with pending scene");return
 check(Service.projection(game,1).pending.is_empty(),"host receipts survive guest reconnect")
 for technology in game.Stage.HEART_STATIONS:game.progress.heart.complete(game.progress,technology)
 game.progress.save_garden();mark("stations")
 check(await until(func():return marked("stations_seen")),"guest sees researched buildings")
 for technology in game.Stage.HEART_STATIONS:check(game.stage.heart_stations[technology].visible,"host retains unlocked building: "+technology)
 mark("done")
 check(await until(func():return marked("guest-offline") and game.multiplayer.get_peers().is_empty()),"host observes the guest disconnect before its own teardown")
func guest_run() -> void:
 check(SessionCase.World.join(game)==OK,"guest joins")
 if not await until(func():return game.network_session.role()=="Guest" and marked("first") and Service.projection(game,game.local_player_id()).get("pending",[]).size()==1 and game.stage.heart_tree.get_meta("heart_visual_count")==1):check(false,"private pending scene arrives");return
 var data:=Service.projection(game,game.local_player_id())
 check(data.pending[0].kind=="bed" and not game.progress.heart.has("plot_4"),"guest sees host event without changing local world research")
 check(data.pending[0].from_growth==0 and data.pending[0].to_growth==1 and game.stage.heart_tree.get_meta("heart_visual_count")==1,"guest receives per-unlock Heart growth from host research")
 game.send_garden_action("growth_ack:"+str(data.pending[0].sequence));mark("skipped")
 if not await until(func():return marked("second") and Service.projection(game,game.local_player_id()).get("pending",[]).any(func(e):return e.technology=="plot_5")):check(false,"second event arrives");return
 game.send_garden_action("growth_ack:999999")
 await create_timer(.2).timeout
 check(Service.projection(game,game.local_player_id()).pending.size()==1,"guest cannot forge a future sequence")
 var scene=game.get_node("GardenInteractions/GrowthScenes");scene.set_process(false);scene.begin(Service.projection(game,game.local_player_id()).pending[0])
 SessionCase.World.leave(game,"Growth reconnect fixture");game.ui.close_panels()
 scene.force_playback=true;scene._process(0);scene.force_playback=false
 check(scene.event.is_empty() and not game.get_meta("garden_cinematic_active") and not game.stage.has_meta("garden_growth_camera"),"disconnect releases the old host's scene without acknowledging it in the local Garden")
 check(SessionCase.World.join(game)==OK,"reconnect")
 if not await until(func():return game.network_session.role()=="Guest" and Service.projection(game,game.local_player_id()).get("pending",[]).any(func(e):return e.technology=="plot_5") and game.stage.heart_tree.get_meta("heart_visual_count")==2):check(false,"unwatched scene persists through rejoin");return
 check(Service.projection(game,game.local_player_id()).pending.size()==1,"previously acknowledged scene is not replayed")
 check(game.stage.heart_tree.get_meta("heart_visual_count")==2,"reconnecting restores accumulated Heart growth")
 mark("rejoined")
 check(await until(func():return marked("stations") and game.Stage.HEART_STATIONS.keys().all(func(technology):return game.stage.heart_stations.has(technology) and game.stage.heart_stations[technology].visible)),"host unlock snapshots create all three permanent guest buildings")
 var queued: Array=Service.projection(game,game.local_player_id()).pending
 for technology in game.Stage.HEART_STATIONS:
  var reveals: Array=queued.filter(func(e):return e.get("station","")==technology)
  if reveals.is_empty():check(false,"guest receives building reveal: "+technology);continue
  scene.begin(reveals[0]);scene.animate(0);scene.animate(scene.DURATION);scene.finish(false)
  check(game.stage.heart_stations[technology].visible and game.stage.heart_stations[technology].scale.is_equal_approx(Vector3.ONE),"guest completion retains permanent building: "+technology)
  check(not game.stage.heart_tree.get_node("SeedForm").visible and not game.stage.heart_core.is_visible_in_tree(),"guest sees the grown tree without the old overlapping Heart")
 mark("stations_seen");check(await until(func():return marked("done")),"host completes")
