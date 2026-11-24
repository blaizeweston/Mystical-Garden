extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")
const Placement=preload("res://tests/support/garden_placement_case.gd")
var game: Node
var role: String
var base: String
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL Garden cultivation structures co-op ",role,": ",message)
func mark(key: String) -> void:
 var file=FileAccess.open(base+"-"+key,FileAccess.WRITE);file.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+"-"+key)
func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+16000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func _initialize() -> void:call_deferred("run")
func run() -> void:
 role=OS.get_cmdline_user_args()[0];base="res://.godot/cultivation-structures-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role+".cfg";game.local_character.path=base+role+".character";game.guest_character.path=base+role+".guest";root.add_child(game)
 game.get_node("GardenInteractions/GrowthScenes").set_process(false)
 if role=="host":await host_run()
 else:await guest_run()
 game.session_world.leave("Garden cultivation structures fixture complete")
 var offline := game.network_session.transport() == null and game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
 check(offline,"offline peer is installed before world removal")
 if offline:
  if role=="guest":mark("guest-offline")
  game.queue_free()
  check(await until(func():return not is_instance_valid(game)),"world is removed after network shutdown")
 if not failed:print("PASS: Garden cultivation structures co-op ",role," host permissions, authoritative policy, guest tending and reconnect")
 quit(1 if failed else 0)
func host_run() -> void:
 check(game.session_world.host()==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return SessionCase.Session.ready_for(p))):check(false,"admission");return
 var id: int=game.players.keys().filter(func(peer):return peer!=1)[0];var g=game.progress
 var garden=game.stage.experimental_garden
 game.slot_claimed=true
 game.players[1].pos=Vector3(0,0,1.5)
 for tech in ["clearing_1","clearing_2","irrigation","bud_sanctuary","bud_sanctuary_effectiveness","pollination_bloom","nursery"]:
  g.heart.complete(g,tech)
 var site: Vector2=garden.planar(game.stage.bed_position(0))
 for kind in ["bud_sanctuary","pollination_bloom","nursery"]:
  if not check_placed(garden,kind,site):return
 var sanctuary: int=g.structures.instances.keys().filter(func(key):return g.structures.instances[key].kind=="bud_sanctuary")[0]
 check(garden.configure_sanctuary(sanctuary,"enhanced",g.structures.revision),"host configures enhanced care")
 var host: Dictionary=game.players[1];host.pos=game.stage.bed_position(0);host.seed_choice=0;game.seed_reserve(host).stock[0]+=1
 check(game.cultivation.plant_seed(1,0),"host plants");g.advance_growth(86400);g.save_garden()
 var guest: Dictionary=game.players[id];guest.pos=host.pos
 var before: int=game.seed_reserve(guest).stock[0];var familiarity: int=guest.character.plants[0]
 mark("ready")
 if not await until(func():return marked("harvested") and g.plots[0].species<0):check(false,"guest harvest reached host");return
 check(game.seed_reserve(guest).stock[0]==before+3 and guest.character.plants[0]==familiarity+2,"one payout to the harvesting guest")
 mark("rejoin")
 if not await until(func():return marked("rejoined")):check(false,"guest recovered configured structure");return
 mark("done")
 check(await until(func():return marked("guest-offline") and game.multiplayer.get_peers().is_empty()),"guest departed")
func check_placed(garden: Node,kind: String,site: Vector2) -> bool:
 var id:=Placement.deploy_irrigation(garden,kind,site)
 check(id>0,"placed "+kind)
 return id>0
func guest_run() -> void:
 check(game.session_world.join()==OK,"guest joins")
 if not await until(func():return game.network_session.role()=="Guest" and marked("ready") and game.cultivation.projection(game.local_player_id()).get("beds",[]).any(func(b):return b.stage==3 and b.preserved and b.seeds==3 and b.familiarity==2)):check(false,"recipient sees actual mature yield");return
 var garden=game.stage.experimental_garden
 var inventory: Dictionary=garden.remote_development.layout.inventory
 var id: int=inventory.instances.keys().filter(func(key):return inventory.instances[key].kind=="bud_sanctuary")[0]
 check(inventory.instances[id].care_mode=="enhanced" and not garden.configure_sanctuary(id,"disabled",inventory.revision),"guest sees the setting and cannot change it")
 var bed: Dictionary=game.cultivation.projection(game.local_player_id()).beds[0]
 var cmd: String="garden:"+JSON.stringify(preload("res://garden_crop_view.gd").request(bed,"flower_crop"))
 game.send_garden_action(cmd);game.send_garden_action(cmd)
 mark("harvested")
 if not await until(func():return marked("rejoin")):check(false,"harvest confirmed");return
 game.session_world.leave("Cultivation rejoin fixture");game.ui.close_panels();check(game.session_world.join()==OK,"guest rejoins")
 if not await until(func():return game.network_session.role()=="Guest" and garden.remote_development.get("layout",{}).get("inventory",{}).get("instances",{}).get(id,{}).get("care_mode")=="enhanced"):check(false,"sanctuary setting synchronized after rejoin");return
 mark("rejoined");check(await until(func():return marked("done")),"host completes")
