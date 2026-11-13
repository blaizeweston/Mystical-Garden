extends SceneTree

const Gate = preload("res://persistence_writer_integration.gd")
const Tx = preload("res://game_transaction.gd")
const Network = preload("res://network_settings.gd")
const G = "user://saves/slot_1/garden.cfg"
const P = "user://saves/characters/slot_1/character.cfg"
var sync_path: String
var failed := false

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: ",message)

func mark(key: String, value := "yes") -> void:
 var file := FileAccess.open(sync_path+key,FileAccess.WRITE)
 check(file!=null,"fixture signal "+key)
 if file!=null: file.store_string(value)

func read(key: String) -> String:
 return FileAccess.get_file_as_string(sync_path+key)

func until(predicate: Callable) -> bool:
 var deadline := Time.get_ticks_msec()+17000
 while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
 return predicate.call()

func title() -> Node:
 check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"load configured main scene")
 await scene_changed
 var menu: Node = current_scene
 check(menu.production_route and menu.guarded_persistence,"candidate default title")
 return menu

func run() -> void:
 var role := OS.get_cmdline_user_args()[0]
 check(not Gate.default_route(self) and not Gate.PRODUCTION_CUTOVER_APPROVED and Network.PROTOCOL==40,"normal startup stays inactive and protocol 40 is current")
 sync_path = ProjectSettings.globalize_path("user://release-fixtures/four-title-")
 set_meta(Gate.VALIDATION_ROUTE,true)
 if role!="host":
  var data := OS.get_environment("APPDATA").path_join("p2a-"+role)
  check(DirAccess.make_dir_recursive_absolute(data.path_join(OS.get_user_data_dir().get_file()))==OK,"isolated role root")
  OS.set_environment("APPDATA",data)
  check(OS.get_user_data_dir().simplify_path()==data.path_join(OS.get_user_data_dir().get_file()).replace("\\","/").simplify_path(),"guest has a separate physical data root")
 if role=="host": await host()
 else: await guest(role)
 if not failed: print("PASS: candidate default title four player ",role)
 quit(1 if failed else 0)

func host() -> void:
 var menu: Node = await title()
 create_character(menu,"Release Host")
 menu.host_choice.button_pressed = true
 menu.new_button.pressed.emit()
 var game := current_scene
 if game==menu or game.session!="Host":
  check(false,"host New Garden handoff")
  return
 mark("port",str(game.network_port))
 if not await until(func(): return game.players.size()==4 and committed_guests(game)==3):
  check(false,"all three guarded profiles acknowledged")
  return
 mark("full")
 check(await until(func():return read("overflow-done")=="yes"),"fifth player attempt completed")
 check(game.players.size()==4,"capacity refused without replacing the existing party")
 mark("reconnect-ready")
 var revisions: Array = []
 for player in game.players.values():
  if not player.has("projection_delivery"): continue
  revisions.append(player.projection_delivery.revision)
 check(revisions==[1,1,1] and game.progress.character_records.size()>=3,"host tracks all three committed admissions")
 var receipts: int = game.progress.character_records.size()
 if not await until(func(): return read("reconnected")=="yes" and game.players.size()==4 and committed_guests(game)==3):
  check(false,"guest reconnect through title and acknowledges its committed profile")
  return
 check(game.progress.character_records.size()==receipts,"reconnect uses the existing identity")
 var harvest_id: int = game.players.keys().filter(func(id): return id!=1 and game.players[id].character.name=="Release Guest 2")[0]
 var harvester: Dictionary = game.players[harvest_id]
 var garden_before := FileAccess.get_sha256(G)
 var bed: Dictionary = game.progress.empty_plot().merged({"species":0,"stage":3,"age":10000.0},true)
 preload("res://garden_crop_state.gd").ensure(bed)
 game.progress.plots[0] = bed
 game.progress.sync_plot_flags()
 harvester.pos = game.Stage.PLOTS[0]
 mark("harvest-request",JSON.stringify({"point":"bed_1","action":"harvest_crop","request":"release-harvest","revision":0,"stage":3,"cycle":bed.care.cycle}))
 if not await until(func(): return read("harvest-done")=="yes" and harvester.character.plants[0]==1 and harvester.projection_delivery.get("state")=="committed"):
  check(false,"real guest harvest and committed acknowledgment")
  return
 check(game.progress.plots[0].species<0 and FileAccess.get_sha256(G)!=garden_before,"host harvest commits Garden in full party")
 print("CASE ",JSON.stringify({"case":"full_party_harvest","before":garden_before,"after":FileAccess.get_sha256(G),"delivery":harvester.projection_delivery}))
 var peer_id: int = game.players.keys().filter(func(id): return id!=1 and game.players[id].character.name=="Release Guest 3")[0]
 check(await until(func(): return read("lease-ready")=="yes" and game.players.has(peer_id)),"guest expired its local lease")
 var actor: Dictionary = game.players[peer_id]
 var projection = load("res://guest_profile_projection.gd")
 var incoming: Dictionary = actor.character.duplicate(true)
 incoming.name = "Delayed acceptance probe"
 var descriptor: Dictionary = projection.build(incoming, actor.projection_delivery.revision+1, actor.get("projection_base",{}))
 game.receive_character.rpc_id(peer_id,{"profile":incoming,"origin":game.progress.projection_origin,"projection":descriptor})
 mark("projection-sent")
 check(await until(func(): return read("lease-refused")=="yes"),"late real projection refused after lease loss")

 print("CASE ",JSON.stringify({"case":"four_guarded_admissions","revisions":revisions,"garden":FileAccess.get_sha256(G)}))
 game.return_to_main_menu()
 check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"host offline before detach")
 check(await until(func():return read("offline-1")=="yes" and read("offline-2")=="yes" and read("offline-3")=="yes"),"all guests return through title")

func guest(role: String) -> void:
 check(await until(func():return read("port").is_valid_int()),"host listening")
 var menu: Node = await title()
 create_character(menu,"Release Guest "+role)
 var before := FileAccess.get_sha256(P)
 if role=="overflow": check(await until(func():return read("full")=="yes"),"party full")
 if role=="1":
  var legacy: Node = connect_to_host(menu)
  if legacy == null: return
  legacy.multiplayer.connected_to_server.disconnect(legacy.on_joined_world)
  legacy.multiplayer.connected_to_server.connect(func():
   var catalog: Dictionary = legacy.progress.ContentIDs.manifest()
   catalog["guest_projection_receipts"] = legacy.guest_character.projection_receipts
   legacy.register_character.rpc_id(1,legacy.guest_character.identity,legacy.guest_character.data,catalog,39),
   CONNECT_ONE_SHOT)
  var refused_id := legacy.get_instance_id()
  if not await until(func():return current_scene.get_instance_id()!=refused_id):
   check(false,"protocol 39 returned to title")
   return
  menu=current_scene
  check(menu.return_message.contains("versions") and FileAccess.get_sha256(P)==before,"protocol 39 refused without changing profile")
  print("CASE ",JSON.stringify({"case":"protocol_39_refused","profile":before,"notice":menu.return_message}))
  await process_frame
 var game: Node = connect_to_host(menu)
 if game==null: return
 if game==menu:
  check(false,"title Join starts")
  return
 if role=="overflow":
  game.connection_deadline = Time.get_ticks_msec()+4500
  var attempt := game.get_instance_id()
  check(await until(func():return current_scene.get_instance_id()!=attempt),"overflow returned to title")
  check(FileAccess.get_sha256(P)==before and not FileAccess.file_exists(G),"overflow kept profile and no Garden")
  check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"overflow offline")
  mark("overflow-done")
  return
 var game_id := game.get_instance_id()
 if not await until(func(): return admitted(game_id)):
  check(false,"guest joins")
  return
 check(FileAccess.get_sha256(P)!=before and game.guest_character.projection_receipts.size()==1 and not FileAccess.file_exists(G),"guest committed only its own receipt")
 print("CASE ",JSON.stringify({"case":"guest_receipt","role":role,"before":before,"after":FileAccess.get_sha256(P),"receipts":game.guest_character.projection_receipts}))
 if role=="1":
  check(await until(func():return read("reconnect-ready")=="yes"),"overflow completed before reconnect")
  game.leave_game("Reconnect acceptance")
  check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer and not FileAccess.file_exists(P.get_base_dir().path_join("session.cfg")),"guest releases lease before reconnect")
  await process_frame
  menu=current_scene
  game=connect_to_host(menu)
  if game==null: return
  game_id=game.get_instance_id()
  if not await until(func(): return admitted(game_id)):
   check(false,"real title reconnect")
   return
  mark("reconnected")
 if role=="2":
  if not await until(func(): return not read("harvest-request").is_empty()):
   check(false,"host prepares party harvest")
   return
  var before_harvest := FileAccess.get_sha256(P)
  game.send_garden_action("garden:"+read("harvest-request"))
  if not await until(func(): return game.guest_character.data.plants[0]==1 and game.status.begins_with("Harvested")):
   check(false,"guest harvest profile and confirmation: "+game.status)
   return
  check(FileAccess.get_sha256(P)!=before_harvest,"guest harvest writes owned local profile")
  mark("harvest-done")
 if role=="3":
  if not await until(func(): return read("harvest-done")=="yes"):
   check(false,"reconnect reached before expiry")
   return
  var marker := ConfigFile.new()
  marker.set_value("session","process_id",OS.get_process_id())
  marker.set_value("session","updated",Time.get_unix_time_from_system()-60.0)
  var lease := P.get_base_dir().path_join("session.cfg")
  check(marker.save(lease)==OK,"expire disposable profile lease")
  game.get_meta(Tx.SESSION)._heartbeat_at = Time.get_unix_time_from_system()+25.0
  var stable := FileAccess.get_sha256(P)
  var stages := {"count":0}
  game.set_meta(&"guarded_gameplay_test_fault",func(phase,_path):
   if phase=="stage": stages.count+=1
   return OK)
  mark("lease-ready")
  check(await until(func(): return read("projection-sent")=="yes"),"host dispatches delayed projection")
  await create_timer(.4).timeout
  check(FileAccess.get_sha256(P)==stable and stages.count==0 and game.guest_character.data.name!="Delayed acceptance probe","late projection does not stage or persist")
  print("CASE ",JSON.stringify({"case":"late_projection_lease_loss","before":stable,"after":FileAccess.get_sha256(P),"stages":stages.count}))
  mark("lease-refused")
 var attempt := game.get_instance_id()
 check(await until(func():return current_scene.get_instance_id()!=attempt),"guest returned to title")
 check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"guest offline after host shutdown")
 if role!="3":
  check(not FileAccess.file_exists(P.get_base_dir().path_join("session.cfg")),"guest releases owned lease")
 mark("offline-"+role)


func committed_guests(game: Node) -> int:
 return game.players.values().filter(func(player): return player.get("projection_delivery",{}).get("state")=="committed").size()

func create_character(menu: Node, name: String) -> void:
 menu.request_create_character()
 check(menu.creator.visible,"title opens creator")
 menu.creator.name_field.text = name
 menu.creator.confirmed.emit()
 check(menu.character_summary(0).name==name and not menu.creator.visible,"title commits roster creation")


func connect_to_host(menu: Node) -> Node:
 menu.join_button.pressed.emit()
 check(menu.network_dialog.visible,"Join by IP opens real title dialog")
 menu.network_dialog.address_field.text = "127.0.0.1:" + read("port")
 menu.network_dialog.submit.pressed.emit()
 if current_scene==menu:
  check(false,"title Join starts: "+menu.notice.text)
  return null
 return current_scene

func admitted(instance: int) -> bool:
 return is_instance_valid(current_scene) and current_scene.get_instance_id()==instance and current_scene.session=="Guest" and not current_scene.client_details.is_empty()
