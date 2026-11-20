extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")
const Catalog=preload("res://garden_interaction_catalog.gd")
const Layout=preload("res://garden_layout.gd")
var game: Node
var role: String
var base: String
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL Garden spring co-op ",role,": ",message)
func mark(key: String) -> void:
 var file=FileAccess.open(base+"-"+key,FileAccess.WRITE);file.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+"-"+key)
func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+16000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func payload(key: String) -> String:return "garden:"+JSON.stringify({"point":"spring_weave","revision":0,"request":key,"action":"observe"})
func _initialize() -> void:call_deferred("run")
func run() -> void:
 role=OS.get_cmdline_user_args()[0];base="res://.godot/spring-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role+".cfg";game.local_character.path=base+role+".character";game.guest_character.path=base+role+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 SessionCase.World.leave(game,"Fixture complete")
 check(game.network_session.transport() == null and game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "network shuts down before world removal")
 game.queue_free();await process_frame
 if not failed:print("PASS: Garden spring co-op ",role," host research/layout, stale crop rejection, shared clue race and reward-free late join")
 quit(1 if failed else 0)
func host_run() -> void:
 check(SessionCase.World.host(game)==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return SessionCase.Session.ready_for(p))):check(false,"admission");return
 var g=game.progress;var id: int=game.players.keys().filter(func(peer):return peer!=1)[0];var guest: Dictionary=game.players[id]
 for tech in ["clearing_1","flowering","irrigation"]:g.heart.unlock_direct(tech)
 g.heart.sync_legacy(g)
 var moss: int=game.Seeds.index_of("lantern_moss");var vine: int=game.Seeds.index_of("whispervine")
 g.plots[0]={"species":moss,"age":86400.0,"stage":3,"flowering":false};g.plots[1]={"species":vine,"age":86400.0,"stage":3,"flowering":false};g.sync_plot_flags();g.save_garden()
 var point: Dictionary=Catalog.point("spring_weave")
 guest.pos=point.position;game.players[1].pos=point.position
 mark("ready")
 if not await until(func():return marked("prepared")):check(false,"guest sees mature conditions");return
 game.players[1].pos=game.Stage.PLOTS[0];game.cultivation.harvest(1,0)
 mark("changed")
 if not await until(func():return marked("stale_rejected")):check(false,"guest verifies stale command rejection");return
 check(g.garden_interactions.revision==0,"crop changed without granting a stale observation")
 g.plots[0]={"species":moss,"age":86400.0,"stage":3,"flowering":false};g.sync_plot_flags();g.save_garden()
 game.players[1].pos=point.position
 mark("restored")
 if not await until(func():return marked("submitted")):check(false,"guest observes restored relationship");return
 var before: Array=g.parts.duplicate();var knowledge: int=g.knowledge
 game.garden_action(1,payload("host-race"))
 if not await until(func():return g.garden_interactions.revision==1):check(false,"shared clue commits");return
 check(g.garden_interactions.receipts.size()==1 and g.parts==before and g.knowledge==knowledge and g.altar_recipes.is_empty(),"race records once with no ingredient, Knowledge or recipe grant")
 game.players[1].pos=game.Stage.PLOTS[1];game.cultivation.harvest(1,1)
 mark("committed")
 if not await until(func():return marked("first_verified")):check(false,"guest sees durable clue");return
 mark("rejoin")
 if not await until(func():return marked("late_verified")):check(false,"guest restores spring and clue after reconnect");return
 check(g.garden_interactions.receipts.size()==1,"late join cannot duplicate discovery")
 mark("done");await create_timer(.3).timeout
func guest_run() -> void:
 check(SessionCase.World.join(game)==OK,"guest joins")
 if not await until(func():return marked("ready") and game.network_session.role()=="Guest" and game.stage.heart_unlocked.has("irrigation") and game.garden_commands.projection(game.local_player_id()).get("available",[]).has("spring_weave")):check(false,"host projection reveals relationship");return
 check(not game.progress.heart.has("irrigation") and game.stage.heart_unlocked.has("irrigation"),"guest uses host capabilities rather than a local Garden")
 check(Layout.ponds(game.stage,game.stage.garden_extent).size()==2,"guest has the same revealed water layout")
 check(not game.stage.garden_edge.has_node("ShelteredSpring") and not game.stage.garden_edge.has_node("DormantSpringSite") and preload("res://garden_water.gd").anchor(game.stage).is_finite(),"host research enables the same fixture-free Garden water for guests")
 mark("prepared")
 if not await until(func():return marked("changed")):check(false,"crop changes");return
 game.send_garden_action(payload("stale"))
 if not await until(func():return game.status.contains("changed")):check(false,"host rejects the invalidated crop condition");return
 mark("stale_rejected")
 if not await until(func():return marked("restored") and game.garden_commands.projection(game.local_player_id()).get("available",[]).has("spring_weave")):check(false,"new mature arrangement arrives");return
 game.send_action(false)
 var view=game.get_node("GardenInteractions")
 if not await until(func():return view.panel.visible):check(false,"relationship inspection opens");return
 game.send_garden_action(payload("guest-race"));mark("submitted")
 if not await until(func():return game.garden_commands.projection(game.local_player_id()).get("revision",0)==1 and marked("committed")):check(false,"recorded clue arrives");return
 var data = game.garden_commands.projection(game.local_player_id())
 check(data.clues.get("moss_whisper_resonance","").contains("Altar") and data.available.has("spring_weave"),"recorded clue remains readable after a required plant is harvested")
 mark("first_verified")
 if not await until(func():return marked("rejoin")):check(false,"host allows rejoin");return
 SessionCase.World.leave(game,"Spring rejoin fixture");game.ui.close_panels();check(SessionCase.World.join(game)==OK,"guest reconnects")
 if not await until(func():return game.network_session.role()=="Guest" and game.garden_commands.projection(game.local_player_id()).get("revision",0)==1):check(false,"shared journal returns");return
 await process_frame
 check(view.cue_until==0 and not view.panel.visible and game.garden_commands.projection(game.local_player_id()).clues.has("moss_whisper_resonance"),"late join restores context without reward/animation replay")
 mark("late_verified");check(await until(func():return marked("done")),"host completes")
