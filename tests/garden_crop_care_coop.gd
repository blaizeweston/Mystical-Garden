extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")
const Service=preload("res://garden_crop_service.gd")
const Garden=preload("res://garden_interaction_service.gd")
const View=preload("res://garden_crop_view.gd")
var game: Node
var role: String
var base: String
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL crop care co-op ",role,": ",message)
func mark(key: String) -> void:
 var file=FileAccess.open(base+"-"+key,FileAccess.WRITE);file.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+"-"+key)
func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+16000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func bed() -> Dictionary:
 for entry in Service.projection(game,game.local_player_id()).get("beds",[]):
  if int(entry.slot)==0:return entry
 return {}
func send(request: Dictionary) -> void:game.send_garden_action("garden:"+JSON.stringify(request))
func _initialize() -> void:call_deferred("run")
func run() -> void:
 role=OS.get_cmdline_user_args()[0];base="res://.godot/care-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role+".cfg";game.local_character.path=base+role+".character";game.guest_character.path=base+role+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 SessionCase.World.leave(game,"Fixture complete")
 check(game.network_session.transport() == null and game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "network shuts down before world removal")
 game.queue_free();await process_frame
 if not failed:print("PASS: crop care co-op ",role," competing choices, private preview, durable rejoin, one harvest and stale-cycle rejection")
 quit(1 if failed else 0)
func host_run() -> void:
 check(SessionCase.World.host(game)==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return SessionCase.Session.ready_for(p))):check(false,"admission");return
 var id: int=game.players.keys().filter(func(peer):return peer!=1)[0];var g=game.progress
 game.players[1].pos=game.Stage.PLOTS[0];game.players[id].pos=game.Stage.PLOTS[0];game.seed_reserve(game.players[1]).stock[0]=1;game.plant_seed(1,0);g.advance_growth(168.75);g.save_garden()
 var request:=View.request(bed(),"preserve_bud");var before: Array=g.parts.duplicate();var cycle: String=bed().cycle
 mark("ready")
 if not await until(func():return marked("submitted")):check(false,"guest submits competing care");return
 Garden.command(game,1,JSON.stringify(request))
 if not await until(func():return g.plots[0].care.choice in ["preserve","leave"]):check(false,"one choice commits");return
 check(g.plots[0].care.revision==request.revision+1 and g.parts==before and game.players[1].character.plants[0]==0 and game.players[id].character.plants[0]==0,"race selects once without items or familiarity")
 mark("chosen")
 if not await until(func():return marked("rejoined")):check(false,"guest reconnects with committed choice");return
 id=game.players.keys().filter(func(peer):return peer!=1)[0];game.players[id].pos=game.Stage.PLOTS[0];game.players[1].pos=game.Stage.PLOTS[0]
 g.advance_growth(300);g.save_garden();var rare: int=game.Parts.rare_part(0);var rare_before: int=g.part_count(rare)
 request=View.request(bed(),"harvest_crop");mark("mature")
 if not await until(func():return marked("harvest_submitted")):check(false,"guest submits harvest");return
 Garden.command(game,1,JSON.stringify(request))
 if not await until(func():return g.plots[0].species<0):check(false,"one harvest commits");return
 check(g.parts[0]==int(before[0])+1 and g.part_count(rare)<=rare_before+1 and game.players[1].character.plants[0]+game.players[id].character.plants[0]==1,"simultaneous harvest pays one common part, at most one rare part and one personal familiarity reward")
 game.seed_reserve(game.players[1]).stock[0]+=1;game.plant_seed(1,0);g.save_garden();check(g.plots[0].care.cycle!=cycle,"replant is a different cycle")
 mark("replanted")
 if not await until(func():return marked("stale_checked")):check(false,"guest checks stale crop");return
 check(g.plots[0].species==0 and g.plots[0].care.choice=="" and g.parts[0]==int(before[0])+1,"late old-cycle command cannot change or harvest the new crop")
 for tech in ["clearing_1","irrigation"]:g.heart.unlock_direct(tech)
 g.heart.sync_legacy(g);g.save_garden()
 game.players[id].pos=Garden.Catalog.point("spring_water").position
 mark("water_ready")
 if not await until(func():return game.players[id].get("spring_water",false)):check(false,"guest fills at the physical spring");return
 game.players[id].pos=game.Stage.PLOTS[0]
 if not await until(func():return marked("water_sent") and preload("res://cultivation_growth.gd").watered(g.plots[0])):check(false,"guest waters shared crop");return
 check(g.plots[0].care.revision==1 and is_equal_approx(preload("res://cultivation_growth.gd").rate(g,g.plots[0]),1.5),"repeated guest watering stacks neither revision nor speed")
 g.heart.complete(g,"flowering");g.advance_growth(86400);g.save_garden()
 var seed_total: int=game.seed_reserve(game.players[1]).stock[0]+game.seed_reserve(game.players[id]).stock[0]
 var common_before: int=g.parts[0];rare_before=g.part_count(rare);request=View.request(bed(),"flower_crop");mark("seed_ready")
 if not await until(func():return marked("seed_sent")):check(false,"guest chooses seed harvest");return
 Garden.command(game,1,JSON.stringify(request))
 if not await until(func():return g.plots[0].species<0):check(false,"seed harvest commits");return
 check(game.seed_reserve(game.players[1]).stock[0]+game.seed_reserve(game.players[id]).stock[0]==seed_total+2 and g.parts[0]==common_before and g.part_count(rare)==rare_before,"competing seed choices pay only two personal seeds and no parts")
 mark("done");await create_timer(.3).timeout
func guest_run() -> void:
 check(SessionCase.World.join(game)==OK,"guest joins")
 if not await until(func():return game.network_session.role()=="Guest" and marked("ready") and bed().get("available",false)):check(false,"host crop projection");return
 var old_cycle: String=bed().cycle;var request:=View.request(bed(),"leave_bud")
 check(not bed().has("roll") and bed().preserve_chance>bed().base_chance,"guest has a usable chance preview without the frozen outcome")
 game.send_action(false)
 if not await until(func():return game.get_node("GardenInteractions/Crops").panel.visible):check(false,"guest crop inspector opens");return
 send(request);mark("submitted")
 if not await until(func():return marked("chosen") and bed().get("choice","") in ["preserve","leave"]):check(false,"shared choice arrives");return
 var choice: String=bed().choice
 SessionCase.World.leave(game,"Crop-care rejoin fixture");game.ui.close_panels();check(SessionCase.World.join(game)==OK,"reconnect")
 if not await until(func():return game.network_session.role()=="Guest" and bed().get("cycle","")==old_cycle and bed().get("choice","")==choice):check(false,"saved cycle/choice returns");return
 check(game.progress.plots[0].species<0,"host care is not written into the guest's own Garden")
 mark("rejoined")
 if not await until(func():return marked("mature") and bed().get("stage",-1)==3):check(false,"mature projection arrives");return
 var harvest_request:=View.request(bed(),"harvest_crop");send(harvest_request);mark("harvest_submitted")
 if not await until(func():return marked("replanted") and not bed().is_empty() and bed().cycle!=old_cycle):check(false,"new cycle arrives");return
 send(request);send(harvest_request)
 if not await until(func():return game.status.contains("different crop")):check(false,"stale intent rejection arrives");return
 check(bed().choice=="" and bed().stage==0,"new crop remains untouched")
 mark("stale_checked")
 if not await until(func():return marked("water_ready") and bed().get("water_available",false)):check(false,"spring watering arrives");return
 var id: int=game.local_player_id()
 var spring: Vector3=Garden.Catalog.point("spring_water").position
 if not await until(func():return game.players[id].pos.distance_to(spring)<1.0):check(false,"guest reaches spring");return
 game.send_action(false)
 var view=game.get_node("GardenInteractions")
 if not await until(func():return Service.projection(game,id).get("spring_water",false) and game.players[id].pos.distance_to(game.Stage.PLOTS[0])<1.0):check(false,"water carried to crop");return
 check(not game.ui.is_overlay_open(),"guest fills without opening a menu")
 var water_request:=View.request(bed(),"water_crop")
 var crops=view.get_node("Crops")
 game.ui.set_prompt(crops.context_prompt())
 check(crops.quick_water.visible,"guest sees the nearby Water plant button")
 crops.quick_water.pressed.emit();send(water_request);mark("water_sent")
 if not await until(func():return marked("seed_ready") and bed().get("stage",-1)==3 and bed().get("flower_enabled",false)):check(false,"seed harvest choice arrives");return
 check(bed().watered,"committed watering is shared")
 check(await until(func():return game.get_node("EventAudio").last_played.has("crop_watered")),"nearby guest receives the watering cue")
 send(View.request(bed(),"flower_crop"));mark("seed_sent")
 check(await until(func():return marked("done") and bed().is_empty()),"seed harvest empties the crop without another growth cycle")
