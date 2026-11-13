extends SceneTree
const Service=preload("res://garden_interaction_service.gd")
const State=preload("res://garden_interaction_state.gd")
const Catalog=preload("res://garden_interaction_catalog.gd")
var game: Node
var role: String
var base: String
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL Garden observations co-op ",role,": ",message)
func mark(key: String) -> void:
 var file=FileAccess.open(base+"-"+key,FileAccess.WRITE);file.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+"-"+key)
func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+16000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func payload(revision: int,key: String) -> String:return "garden:"+JSON.stringify({"point":"heart_root_scar","action":"observe","revision":revision,"request":key})
func _initialize() -> void:call_deferred("run")
func run() -> void:
 role=OS.get_cmdline_user_args()[0];base="res://.godot/garden-observation-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role+".cfg";game.local_character.path=base+role+".character";game.guest_character.path=base+role+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 game.leave_game("Fixture complete")
 check(game.online_peer == null and game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "network shuts down before world removal")
 game.queue_free();await process_frame
 if not failed:print("PASS: Garden observation co-op ",role," shared receipt, remote inspection, no rewards and rejoin without cue replay")
 quit(1 if failed else 0)
func host_run() -> void:
 check(game.host_game()==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return p.profile_ready)):check(false,"admission");return
 var guest_id: int=game.players.keys().filter(func(id):return id!=1)[0];var guest: Dictionary=game.players[guest_id]
 var point: Dictionary=Catalog.point("heart_root_scar")
 guest.pos=point.position;game.players[1].pos=point.position
 game.act(guest_id,false)
 mark("ready")
 if not await until(func():return marked("submitted")):check(false,"guest sends observation");return
 # Both intents use the same expected revision. Either ordering must commit once.
 game.garden_action(1,payload(0,"host-race"))
 if not await until(func():return State.observed(game.progress.garden_interactions,"old_root_scar")):check(false,"committed observation");return
 check(game.progress.garden_interactions.revision==1 and game.progress.garden_interactions.receipts.size()==1,"simultaneous host/guest requests produce one receipt")
 var restored=game.Progress.new();restored.path=game.progress.path
 check(restored.load_garden()==OK and restored.garden_interactions.revision==1,"shared result is durable")
 mark("committed")
 if not await until(func():return marked("first_verified")):check(false,"guest sees committed state");return
 guest.pos=game.Stage.GATE
 mark("out_of_range")
 if not await until(func():return marked("rejected")):check(false,"guest checks range");return
 check(game.progress.garden_interactions.revision==1,"forged remote request cannot mutate")
 mark("rejoin")
 if not await until(func():return marked("late_verified")):check(false,"guest rejoins with saved projection");return
 check(game.progress.garden_interactions.receipts.size()==1,"rejoining does not add a receipt")
 mark("done")
 await create_timer(.3).timeout
func guest_run() -> void:
 check(game.join_game()==OK,"guest connects")
 if not await until(func():return marked("ready") and game.session=="Guest" and not game.client_details.is_empty() and game.players.get(game.local_player_id(),{}).get("garden_interactions",{}).has("focus")):check(false,"Garden projection arrives");return
 var view=game.get_node("GardenInteractions")
 if not await until(func():return view.panel.visible):check(false,"remote E opens inspect view");return
 var before: Dictionary=game.inventory_ui_data().duplicate(true)
 game.send_garden_action(payload(0,"guest-race"));mark("submitted")
 if not await until(func():return Service.projection(game,game.local_player_id()).get("revision",0)==1):check(false,"shared observation arrives");return
 check(Service.projection(game,game.local_player_id()).observations.has("old_root_scar"),"guest receives durable shared observation")
 check(game.inventory_ui_data()==before,"no discovery reward changes private inventory")
 mark("first_verified")
 if not await until(func():return marked("out_of_range") and game.players[game.local_player_id()].pos.distance_to(game.Stage.GATE)<.2):check(false,"range setup arrives");return
 game.send_garden_action(payload(99,"forged-revision"))
 if not await until(func():return game.status.contains("closer")):check(false,"range rejection arrives");return
 mark("rejected")
 if not await until(func():return marked("rejoin")):check(false,"rejoin allowed");return
 game.leave_game("Observation rejoin fixture");game.toggle_overlay(null)
 check(game.join_game()==OK,"guest reconnects")
 if not await until(func():return game.session=="Guest" and Service.projection(game,game.local_player_id()).get("revision",0)==1):check(false,"late-join state arrives");return
 await process_frame
 check(view.cue_until==0 and not view.panel.visible,"late join restores knowledge without replaying cue or opening old inspection")
 mark("late_verified");check(await until(func():return marked("done")),"host completes")
