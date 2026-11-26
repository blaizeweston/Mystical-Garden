extends RefCounted
const Custody=preload("res://inventory_custody.gd")
const Tx=preload("res://game_transaction.gd")
const Mode=preload("res://assets/terrain_m02/experimental/experiment_mode.gd")
const Appearance=preload("res://character_appearance.gd")
const Session=preload("res://network_session.gd")
const Build=preload("res://affinity_build.gd")
const Identity=preload("res://network_action_identity.gd")
const Profile=preload("res://character_profile.gd")
const Rare="eclipse_root"
const RareItem="seed_eclipse_root"
var tree: SceneTree
var signals: String
var role: String
var party:=false
var port:=0
var failed:=false

func check(ok: bool,label: String) -> bool:
 if not ok:failed=true;printerr("FAIL INV01 ",role,": ",label)
 return ok
func until(predicate: Callable,label: String) -> bool:
 var deadline:=Time.get_ticks_msec()+22000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await tree.process_frame
 return check(predicate.call(),label)
func verified() -> bool:
 var p:=OS.get_environment("APPDATA").replace("\\","/").simplify_path()
 return Mode.verified() and p.get_base_dir()==ProjectSettings.globalize_path("res://.godot/vd").replace("\\","/").simplify_path() and OS.get_user_data_dir().replace("\\","/").begins_with(p+"/")
func mark(key: String,value: String="yes") -> void:
 var f:=FileAccess.open(signals.path_join(key),FileAccess.WRITE)
 if check(f!=null,"write "+key):f.store_string(value)
func read(key: String) -> String:
 var path:=signals.path_join(key)
 return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
func is_world() -> bool:return is_instance_valid(tree.current_scene) and tree.current_scene.has_method("seed_reserve")
func is_title() -> bool:return is_instance_valid(tree.current_scene) and tree.current_scene.has_method("continue_game")
func join(menu: Node) -> void:
 menu.show_page(2)
 menu.join_button.pressed.emit()
 menu.network_dialog.address_field.text="127.0.0.1:"+str(port)
 menu.network_dialog.submit.pressed.emit()
func bag_count(game: Node,bucket: String,item: String) -> int:
 var total:=0
 for stack: Dictionary in game.inventory_ui_data().get(bucket,[]):
  if stack.item==item:total+=int(stack.quantity)
 return total
func read_profile(path: String) -> Profile:
 var p:=Profile.new();p.path=path
 if not check(p.load_profile()==OK,"read durable profile"):return null
 return p

func run(scene_tree: SceneTree,four: bool) -> bool:
 tree=scene_tree;party=four
 role=OS.get_cmdline_user_args()[0]
 signals=OS.get_environment("MYSTICAL_TERRAIN_TEST_SIGNALS")
 port=int(OS.get_environment("MYSTICAL_GARDEN_TEST_PORT"))
 if not check(verified() and not signals.is_empty(),"self-verifying disposable root before opening title"):return false
 var menu: Node=load("res://main_menu.tscn").instantiate()
 tree.root.add_child(menu);tree.current_scene=menu
 if role=="host":await host(menu)
 elif role=="overflow":await overflow(menu)
 else:await guest(menu)
 return not failed

func host(menu: Node) -> void:
 menu.host_port=port;menu.host_choice.button_pressed=true
 menu.new_game();menu.create_character("Custody host",0,Appearance.DEFAULT)
 if not await until(func():return is_world() and tree.current_scene.network_session.role()=="Host","ordinary guarded host"):return
 var game: Node=tree.current_scene
 var expected:=4 if party else 2
 var g=game.progress
 mark("host")
 if not await until(func():return game.players.size()==expected and game.players.values().all(func(p):return Session.ready_for(p)),"all portable guests admitted"):return
 var peers: Array=game.players.keys();peers.erase(1);peers.sort()
 var ids: Dictionary={}
 for peer: int in peers:
  var actor: Dictionary=game.players[peer]
  var identity:=Session.identity_for(actor)
  ids[peer]=identity
  var reserve: Dictionary=game.seed_reserve(actor)
  check(Custody.active(g,identity) and reserve.stock[0]==3 and reserve.stock[1]==1 and reserve.parts[1]==2,"imported exact personal inventory for "+identity)
 if party:mark("full")
 var stock: Dictionary=g.reserve(game.InventoryModel.SHARED_OWNER)
 stock.stock[0]=peers.size()
 game.garden_action(1,"inventory_withdrawals:0")
 for peer: int in peers:game.players[peer].pos=game.stage.altar_position()
 mark("altar")
 if not await until(func():return peers.all(func(peer):return game.seed_reserve(game.players[peer]).stock[2]==1),"accepted personal recipes from all guests"):return
 check(not g.guest_withdrawals and stock.stock[0]==peers.size() and peers.all(func(peer):return game.seed_reserve(game.players[peer]).stock[0]==2 and game.seed_reserve(game.players[peer]).stock[1]==0),"disabled shared withdrawal grants nothing; personal costs consumed")
 game.garden_action(1,"inventory_withdrawals:1")
 mark("enabled")
 if not await until(func():return stock.stock[0]==0 and peers.all(func(peer):return game.seed_reserve(game.players[peer]).stock[0]==3),"enabled shared withdrawal transfers one unit to each guest"):return
 if party and not await until(func():return read("fifth")=="yes","fifth player refused before locking inventory"):return
 game.players[1].pos=game.Stage.HEART
 game.run_heart_save(func():
  g.knowledge+=100
  return "")
 for tech in ["checkpoint_deposit","deep_root_network","reaching_tendrils"]:game.garden_action(1,"heart_start_"+tech)
 for peer in game.players:game.players[peer].pos=game.stage.gate_position()
 game.garden_action(1,"learn_0_66")
 mark("gate")
 if not await until(func():return game.players.values().all(func(actor):return Build.departure_refusal(actor).is_empty()),"every participant selected a legal focus"):return
 var probe:=RandomNumberGenerator.new()
 for seed_value in range(16,128):
  probe.seed=seed_value
  var key:=Vector3i(game.participation.route(),1,probe.randi_range(1,2147483647))
  if game.battlefield.root_random(key,1).randf()<.40:
   game.map_rng.seed=seed_value;break
 game.PartyTravel.request(game,1,"depart")
 mark("depart",str(game.participation.travel_epoch()))
 if not await until(func():return game.participation.participants().size()==expected,"all departed through ordinary consent"):return
 game.tactics.stagger_until=game.CombatClock.now()+90000;game.encounter.clear_scouts()
 var rare: int=game.Seeds.index_of(Rare)
 # Controlled carried reward fixture; actual root deposit/extraction are not mocked.
 for peer: int in peers:
  var actor: Dictionary=game.players[peer]
  var returning: Dictionary=game.ReturningRoot.view(game,peer,actor)
  if not check(not returning.is_empty() and returning.remaining==2,"generated real root with independent allowance"):return
  game.InventoryModel.put(game,actor,"carry",{"item":RareItem,"quantity":2})
  actor.pos=returning.position
 mark("root")
 if not await until(func():return peers.all(func(peer):return game.seed_reserve(game.players[peer]).stock[rare]==1),"every guest secured one rare seed through actual root request"):return
 check(peers.all(func(peer):return game.players[peer].carried_items.get(RareItem,0)==1),"one unit retained in carried inventory")
 for floor_number in range(5):
  if not check(game.participation.advance(game.participation.epoch(),game.ROUTE_ROOMS),"advance fixture to extraction gate"):return
  game.start_encounter()
 game.tactics.stagger_until=game.CombatClock.now()+90000
 game.encounter.set_hp(-1,0);game.encounter.clear_scouts();game.encounter_rewarded=true
 if not check(game.participation.floor()==6 and game.encounter_cleared(),"cleared sixth encounter fixture"):return
 for actor in game.players.values():actor.pos=game.battlefield.advance
 game.PartyTravel.request(game,1,"extract")
 mark("extract",str(game.participation.travel_epoch()))
 if not await until(func():return not game.participation.active(),"all accepted extraction"):return
 check(peers.all(func(peer):return game.seed_reserve(game.players[peer]).stock[rare]==2 and game.players[peer].carried_items.is_empty()),"both root delivery and final extraction retained once")
 if not await until(func():return peers.all(func(peer):return game.players[peer].get("projection_delivery",{}).get("state") in ["committed","cleanup_pending"]),"ordinary profile settlement acknowledged before custody return"):return
 mark("fault-peer",str(peers[0]));mark("release")
 if not await until(func():return peers.all(func(peer):return read("home-"+ids[peer])=="yes"),"each guest returned to their own Garden including interrupted return"):return
 for identity: String in ids.values():
  check(g.personal_custody[identity].state in ["returned","closed"] and Custody.capture(g,identity)==Custody.blank_payload(),"origin has no spendable duplicate for "+identity)
 check(stock.stock[0]==0,"shared stock reflects only authorized withdrawals")
 mark("done")
 game.return_to_main_menu()
 await until(is_title,"host checks in its own inventory")

func guest(menu: Node) -> void:
 menu.new_game();menu.create_character("Visitor "+role,0,Appearance.DEFAULT)
 if not await until(is_world,"create own local Garden"):return
 var game: Node=tree.current_scene
 var path: String=game.local_character.path
 var identity: String=game.local_character.identity
 var home_origin: String=game.progress.archive.origin
 var setup: Dictionary=Tx.run_gameplay(game,Tx.Scope.GARDEN,func():
  var reserve: Dictionary=game.seed_reserve(game.players[1])
  reserve.stock[0]=3;reserve.stock[1]=1;reserve.parts[1]=2;reserve.unknown.append(1)
  game.InventoryModel.put(game,game.players[1],"stash",{"item":"boss_mystery_seed","quantity":1,"lineages":{"ember_fern":1}})
  return true)
 if not check(Tx.committed(setup.persistence),"starting personal inventory saved"):return
 game.return_to_main_menu()
 if not await until(is_title,"check inventory into profile before visit"):return
 await tree.process_frame
 var p:=read_profile(path)
 if p==null or not check(p.inventory_custody.state=="home","home payload is spendable before visit"):return
 if not await until(func():return read("host")=="yes","host ready"):return
 join(tree.current_scene)
 if not await until(func():return is_world() and tree.current_scene.network_session.role()=="Guest" and tree.current_scene.guest_replication.has_details(),"remote admission with custody"):return
 game=tree.current_scene
 var peer: int=game.local_player_id()
 if not check(Custody.locked(game.guest_character.inventory_custody) and game.guest_character.inventory_custody.origin!=home_origin,"profile locked to remote origin before gameplay"):return
 if not await until(func():return read("altar")=="yes" and not game.inventory_ui_data().get("may_withdraw",true) and bag_count(game,"stash","seed_thorn_bloom")==3 and game.players[peer].pos.distance_to(game.stage.altar_position())<1.65,"replicated personal quantities and disabled permission"):return
 game.send_inventory_action("transfer","shared","stash","seed_thorn_bloom",1)
 var draft: Array=[{"source":"stash","item":"seed_thorn_bloom"},{"source":"stash","item":"seed_lantern_moss"}]
 game.send_altar_action("combine",draft,1)
 if not await until(func():return read("enabled")=="yes" and game.inventory_ui_data().get("may_withdraw",false) and bag_count(game,"stash","seed_veilcap")==1,"personal result and live enabled permission"):return
 game.send_inventory_action("transfer","shared","stash","seed_thorn_bloom",1)
 if not await until(func():return read("gate")=="yes" and game.players[peer].pos.distance_to(game.stage.gate_position())<1.65,"guest at expedition gate"):return
 game.send_garden_action("learn_0_66")
 if not await until(func():return not read("depart").is_empty(),"shared departure vote"):return
 game.send_garden_action("travel_ready:"+read("depart"))
 if not await until(func():return read("root")=="yes" and game.can_use_returning_root(game.players[peer]) and bag_count(game,"carry",RareItem)==2,"rare carried seed and active root replicate"):return
 var returning: Dictionary=game.ReturningRoot.view(game,peer,game.players[peer])
 var stamp:=Identity.current_stamp(game,game.players[peer])
 game.send_garden_action(game.ReturningRoot.request(returning,stamp,RareItem))
 if not await until(func():return not read("extract").is_empty() and game.participation.floor()==6 and game.players[peer].pos.distance_to(game.stage.visual_field.advance)<1.65,"extraction vote and gate replicate"):return
 game.send_garden_action("travel_ready:"+read("extract"))
 if not await until(func():return read("release")=="yes" and not game.participation.contains(peer) and bag_count(game,"stash",RareItem)==2,"retained personal rare seeds before leaving"):return
 if str(peer)==read("fault-peer"):
  game.set_meta(&"guarded_gameplay_test_fault",func(phase,_path):return ERR_FILE_CANT_WRITE if phase=="stage" else OK)
  game.return_to_main_menu()
  if not await until(func():return game.status.contains("Inventory return is unresolved"),"guest disk rollback after host committed return"):return
  check(Custody.locked(game.guest_character.inventory_custody),"failed profile return leaves durable character lock")
  game.remove_meta(&"guarded_gameplay_test_fault")
  game.session_world.offline();game.return_to_main_menu()
  if not await until(is_title,"disconnect with locked profile"):return
  await tree.process_frame
  p=read_profile(path)
  if p==null or not check(Custody.locked(p.inventory_custody),"process-style profile reload retains lock"):return
  var home_menu: Node=tree.current_scene
  home_menu.launch(false)
  check(is_title() and home_menu.notice.text.contains("held by another Garden"),"cannot spend locked resources in another Garden")
  join(home_menu)
  if not await until(func():return is_title() and read_profile_state(path)=="home","reconnect recovers committed return without importing again"):return
 else:
  game.return_to_main_menu()
  if not await until(func():return is_title() and read_profile_state(path)=="home","normal guest checks inventory back into character"):return
 await tree.process_frame
 p=read_profile(path)
 if p==null:return
 check(p.inventory_custody.payload.seeds.get("thorn_bloom",0)==3 and not p.inventory_custody.payload.seeds.has("lantern_moss") and p.inventory_custody.payload.seeds.get("veilcap",0)==1 and p.inventory_custody.payload.seeds.get(Rare,0)==2 and p.inventory_custody.payload.unknown==["lantern_moss"] and p.inventory_custody.payload.extras["boss_mystery_seed"]=={"ember_fern":1},"portable payload preserves exact costs, reward and concealed identity")
 menu=tree.current_scene;menu.launch(false)
 if not await until(is_world,"reopen original home Garden"):return
 game=tree.current_scene
 var rare: int=game.Seeds.index_of(Rare)
 var reserve: Dictionary=game.seed_reserve(game.players[1])
 check(reserve.stock[rare]==2 and reserve.parts[1]==2 and not game.progress.discoveries[rare],"rare seed and personal material arrive home; no arrival-only discovery")
 game.players[1].pos=game.stage.bed_position(0)
 check(game.cultivation.plant_seed(1,0,rare,"stash") and reserve.stock[rare]==1 and game.progress.discoveries[rare],"actual home cultivation of an already identified rare seed")
 game.return_to_main_menu()
 if not await until(is_title,"check home inventory in after cultivating"):return
 await tree.process_frame
 p=read_profile(path)
 if p==null:return
 check(p.inventory_custody.payload.seeds.get(Rare,0)==1,"home planting deducted exactly one seed")
 mark("home-"+identity)
 await until(func():return read("done")=="yes","host completes all receipts")

func read_profile_state(path: String) -> String:
 var file:=ConfigFile.new()
 if file.load(path)!=OK:return ""
 var state: Variant=file.get_value("character","inventory_custody",{})
 return str(state.get("state","")) if state is Dictionary else ""

func overflow(menu: Node) -> void:
 if not await until(func():return read("full")=="yes","four participants occupied"):return
 menu.request_create_character();menu.create_character("Overflow",0,Appearance.DEFAULT)
 if not check(menu.character_ready(),"overflow has an ordinary profile"):return
 var path: String=menu.characters.paths(menu.selected_character).character
 var old:=menu.get_instance_id()
 join(menu)
 if not await until(func():return is_title() and tree.current_scene.get_instance_id()!=old,"fifth client refused"):return
 var p:=read_profile(path)
 if p==null:return
 check(not Custody.locked(p.inventory_custody),"capacity rejection did not lock personal inventory")
 mark("fifth")
