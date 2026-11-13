extends SceneTree
const Conduit=preload("res://garden_conduit.gd")
const Service=preload("res://garden_interaction_service.gd")
var game: Node
var role: String
var base: String
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL Garden conduit co-op ",role,": ",message)
func mark(key: String) -> void:
 var file=FileAccess.open(base+"-"+key,FileAccess.WRITE);file.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+"-"+key)
func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+16000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func request(mode: String,revision: int) -> String:return "garden:"+JSON.stringify({"point":Conduit.POINT,"action":"configure_conduit","request":"coop","revision":revision,"mode":mode})
func _initialize() -> void:call_deferred("run")
func run() -> void:
 role=OS.get_cmdline_user_args()[0];base="res://.godot/conduit-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role+".cfg";game.local_character.path=base+role+".character";game.guest_character.path=base+role+".guest";root.add_child(game)
 game.get_node("GardenInteractions/GrowthScenes").set_process(false)
 if role=="host":await host_run()
 else:await guest_run()
 game.queue_free();await process_frame
 if not failed:print("PASS: Garden conduit co-op ",role," host permissions, authoritative policy, guest tending and reconnect")
 quit(1 if failed else 0)
func host_run() -> void:
 check(game.host_game()==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return p.profile_ready)):check(false,"admission");return
 var id: int=game.players.keys().filter(func(peer):return peer!=1)[0];var g=game.progress
 for tech in ["clearing_1","clearing_2","flowering","irrigation","plot_4","living_conduit"]:g.heart.unlock_direct(tech)
 g.heart.complete(g,"plot_4");g.heart.sync_legacy(g);g.save_garden()
 game.players[1].pos=Conduit.Layout.Catalog.point(Conduit.POINT).position;game.players[id].pos=game.players[1].pos;mark("ready")
 if not await until(func():return marked("rejected")):check(false,"guest attempts forbidden change");return
 check(Conduit.state(g).revision==0 and Conduit.state(g).mode=="gentle","guest command cannot alter host configuration")
 game.garden_action(1,request("deep",0))
 var p: Dictionary=game.players[1];var species: int=game.Seeds.index_of("whispervine");p.pos=game.Stage.PLOTS[3];p.seed_choice=species;game.seed_reserve(p).stock[species]+=1;game.plant_seed(1,3)
 g.plots[3].age=game.Seeds.DEFINITIONS[species].grow_seconds*.6;g.plots[3].stage=2;g.save_garden();game.players[id].pos=game.Stage.PLOTS[3];mark("planted")
 if not await until(func():return marked("tended") and g.plots[3].care.choice=="preserve"):check(false,"guest tend commits");return
 check(g.plots[3].care.opportunity=="deep_bud" and g.plots[3].care.revision==1,"guest uses host's fixed policy once")
 mark("rejoin")
 if not await until(func():return marked("rejoined")):check(false,"rejoin projection");return
 check(Conduit.state(g).revision==1,"rejoin cannot change mode")
 mark("done");await create_timer(.3).timeout
func guest_run() -> void:
 check(game.join_game()==OK,"guest joins")
 if not await until(func():return game.session=="Guest" and marked("ready") and Conduit.projection(game,game.local_player_id()).get("unlocked",false)):check(false,"host tool snapshot");return
 check(not Conduit.projection(game,game.local_player_id()).host and not game.progress.heart.has("living_conduit"),"projection describes host permissions without granting local research")
 game.send_garden_action(request("deep",0))
 if not await until(func():return game.status.contains("Only the Garden host")):check(false,"server permission rejection");return
 mark("rejected")
 if not await until(func():return marked("planted") and Conduit.projection(game,game.local_player_id()).get("mode","")=="deep" and Service.projection(game,game.local_player_id()).get("cultivation",{}).get("beds",[]).any(func(b):return b.slot==3 and b.opportunity=="deep_bud")):check(false,"new policy arrives");return
 var bed: Dictionary=Service.projection(game,game.local_player_id()).cultivation.beds.filter(func(b):return b.slot==3)[0]
 game.send_garden_action("garden:"+JSON.stringify({"point":"bed_4","action":"preserve_bud","request":"guest-tend","revision":bed.revision,"cycle":bed.cycle,"stage":bed.stage}))
 if not await until(func():return Service.projection(game,game.local_player_id()).cultivation.beds.any(func(b):return b.slot==3 and b.choice=="preserve")):check(false,"tending receipt");return
 mark("tended")
 if not await until(func():return marked("rejoin")):check(false,"rejoin allowed");return
 game.leave_game("Conduit rejoin fixture");game.toggle_overlay(null);check(game.join_game()==OK,"guest reconnects")
 if not await until(func():return game.session=="Guest" and Conduit.projection(game,game.local_player_id()).get("mode","")=="deep"):check(false,"configuration persists");return
 check(Service.projection(game,game.local_player_id()).cultivation.beds.any(func(b):return b.slot==3 and b.choice=="preserve"),"crop choice returns without reroll")
 mark("rejoined");check(await until(func():return marked("done")),"host completes")
