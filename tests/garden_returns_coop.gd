extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const Service=preload("res://garden_return_service.gd")
const Scenes=preload("res://garden_growth_service.gd")
var game: Node
var role: String
var base: String
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL Garden returns co-op ",role,": ",message)
func mark(key: String) -> void:
 var file=FileAccess.open(base+"-"+key,FileAccess.WRITE);file.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+"-"+key)
func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+16000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func _initialize() -> void:call_deferred("run")
func run() -> void:
 role=OS.get_cmdline_user_args()[0];base="res://.godot/returns-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role+".cfg";game.local_character.path=base+role+".character";game.guest_character.path=base+role+".guest";root.add_child(game)
 game.get_node("GardenInteractions/GrowthScenes").set_process(false)
 if role=="host":await host_run()
 else:await guest_run()
 SessionCase.World.leave(game,"Garden returns fixture complete")
 var offline := game.network_session.transport() == null and game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
 check(offline,"offline peer is installed before world removal")
 if offline:
  if role=="guest":mark("guest-offline")
  game.queue_free()
  check(await until(func():return not is_instance_valid(game)),"world is removed after network shutdown")
 if not failed:print("PASS: Garden returns co-op ",role," real banking/identification, private provenance, shared trace, independent acknowledgement and reconnect")
 quit(1 if failed else 0)
func host_run() -> void:
 check(SessionCase.World.host(game)==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return SessionCase.Session.ready_for(p))):check(false,"admission");return
 var id: int=game.players.keys().filter(func(peer):return peer!=1)[0];var moss: int=game.Seeds.index_of("lantern_moss")
 game.progress.discoveries[moss]=true
 for peer in [1,id]:
  var p: Dictionary=game.players[peer];p.pos=game.stage.gate_position();p.prepared=0;p.prepared_secondary=0;p.prepared_catalyst=0;p.cargo_plan.fill(0)
  var tree=game.Classes.connected_tree(int(p.frame))
  game.handle_loadout_action(peer,p,"learn_%d_%d"%[p.frame,tree.REQUEST_OFFSET])
  check(not tree.focus(p.character).is_empty(),"host validates the explicit free starting focus")
 check(game.Transactions.run(game,func():
  if not ExpeditionCase.Transitions.admit(game,1,game.players[1]):return false
  return ExpeditionCase.Transitions.admit(game,id,game.players[id]))==true,"shared run starts")
 if not ExpeditionCase.is_wild(game.players[1]) or not ExpeditionCase.is_wild(game.players[id]):
  check(false,"both members must be admitted before inspecting run provenance");return
 check(game.players[1].garden_run_id==game.players[id].garden_run_id and game.progress.garden_interactions.returns.active.members.size()==2,"both members use one expedition identity")
 ExpeditionCase.set_world(game, {"depth": 6});ExpeditionCase.set_world(game, {"encounter_number": 6});game.deepest_milestone=0;game.encounter.set_hp(-1, 0);game.encounter.clear_scouts()
 for peer in [1,id]:game.players[peer].pos=game.battlefield.advance;game.players[peer].carried_seeds=[moss]
 check(game.Transactions.run(game,func():ExpeditionCase.Transitions.commit_checkpoint(game, 1,false);return true)==true,"party banks a cleared checkpoint")
 check(game.progress.garden_interactions.returns.history.size()==1 and game.progress.garden_interactions.returns.history[0].outcomes.get("extracted",0)==2,"one closed run records both outcomes")
 for peer in [1,id]:game.players[peer].pos=game.stage.altar_position()
 mark("banked")
 if not await until(func():return marked("submitted")):check(false,"guest receives private inventory");return
 game.Altar.identify_all(game,game.players[1])
 if not await until(func():return Service.known(game.garden_commands.return_projection(id),"lantern_homecoming") and game.seed_reserve(game.players[id]).unknown.is_empty()):check(false,"both identify");return
 check(game.progress.garden_interactions.growth.events.filter(func(e):return e.get("discovery","")=="lantern_homecoming").size()==1,"two players cannot duplicate a world event")
 mark("identified")
 if not await until(func():return marked("skipped") and Scenes.projection(game,id).pending.is_empty()):check(false,"guest acknowledgement");return
 check(Scenes.projection(game,1).pending.size()==1,"guest skip preserves host playback")
 mark("rejoin")
 if not await until(func():return marked("rejoined")):check(false,"guest reconnect");return
 check(game.progress.garden_interactions.returns.history.size()==1,"reconnect cannot duplicate banking")
 mark("done")
 check(await until(func():return marked("guest-offline") and game.multiplayer.get_peers().is_empty()),"host observes guest disconnect before teardown")
func guest_run() -> void:
 check(SessionCase.World.join(game)==OK,"guest joins")
 if not await until(func():return marked("banked") and game.network_session.role()=="Guest" and game.players.has(game.local_player_id()) and not ExpeditionCase.is_wild(game.players[game.local_player_id()])):check(false,"banked snapshot");return
 check(game.garden_commands.return_projection(game.local_player_id()).get("entries",[]).is_empty(),"unidentified banking reveals no species/story")
 game.send_altar_action("identify_all",[],0);mark("submitted")
 if not await until(func():return marked("identified") and Service.known(game.garden_commands.return_projection(game.local_player_id()),"lantern_homecoming") and Scenes.projection(game,game.local_player_id()).get("pending",[]).size()==1):check(false,"shared discovery arrives");return
 var data = game.garden_commands.return_projection(game.local_player_id())
 check(not JSON.stringify(data).contains("credits") and not JSON.stringify(data).contains("members") and game.progress.garden_interactions.get("returns",{}).get("discoveries",{}).is_empty(),"host projection omits private provenance and does not alter guest world")
 game.send_garden_action("growth_ack:"+str(Scenes.projection(game,game.local_player_id()).pending[0].sequence));mark("skipped")
 if not await until(func():return marked("rejoin")):check(false,"rejoin allowed");return
 SessionCase.World.leave(game,"Garden return reconnect fixture");game.ui.close_panels();check(SessionCase.World.join(game)==OK,"reconnect starts")
 if not await until(func():return game.network_session.role()=="Guest" and Service.known(game.garden_commands.return_projection(game.local_player_id()),"lantern_homecoming")):check(false,"persistent trace returns");return
 check(Scenes.projection(game,game.local_player_id()).get("pending",[]).is_empty(),"acknowledged scene does not replay")
 mark("rejoined");check(await until(func():return marked("done")),"host completes")
