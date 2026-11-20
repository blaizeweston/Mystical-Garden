extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")
const Slots=preload("res://save_slots.gd")
const Owner=preload("res://guarded_title_session.gd")
const G="user://saves/slot_1/garden.cfg"
const Unowned="user://saves/slot_3/garden.cfg"
const HostProfile="user://saves/characters/slot_1/character.cfg"
const P="user://saves/characters/slot_2/character.cfg"
var signals: String
var failed:=false

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool,message: String) -> void:
 if not ok:
  failed=true
  printerr("FAIL: ",message)

func mark(key: String,value := "ready") -> void:
 var file:=FileAccess.open(signals+key,FileAccess.WRITE)
 check(file!=null,"fixture marker "+key)
 if file!=null: file.store_string(value)

func read(key: String) -> String:
 return FileAccess.get_file_as_string(signals+key)

func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+15500
 while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
 return predicate.call()

func title() -> Node:
 var menu=load("res://main_menu.tscn").instantiate()
 menu.guarded_persistence=true
 menu.import_legacy=false
 menu.restore_last_character=false
 menu.restore_last_selection=false
 root.add_child(menu)
 current_scene=menu
 return menu

func launch_guest(menu: Node) -> Node:
 menu.network_port=int(read("listening"))
 menu.join_game()
 if current_scene!=menu: return current_scene
 check(false,"title Join preflight: "+menu.notice.text)
 return null

func place_unowned_proof() -> String:
 check(DirAccess.make_dir_recursive_absolute(Unowned.get_base_dir())==OK,"create unowned fixture dir")
 var proof:=ConfigFile.new()
 proof.set_value("transaction","committed",false)
 proof.set_value("transaction","entries",{Unowned:{"exists":false,"bytes":PackedByteArray()}})
 check(proof.save(Unowned+".transaction")==OK,"place unowned pending evidence")
 return Slots._save_digest(Unowned+".transaction")

func run() -> void:
 var host:=OS.get_cmdline_user_args()[0]=="host"
 signals=ProjectSettings.globalize_path("user://release-fixtures/lifecycle-")
 if not host:
  # Keep the fixture handshake in the shared runner folder. Give the guest
  # its own physical data root, as it would have on another computer.
  var data:=OS.get_environment("APPDATA").path_join("guest")
  var project_dir:=OS.get_user_data_dir().get_file()
  check(DirAccess.make_dir_recursive_absolute(data.path_join(project_dir))==OK,"create disposable guest root")
  OS.set_environment("APPDATA",data)
  check(OS.get_user_data_dir().simplify_path()==data.path_join(project_dir).replace("\\","/").simplify_path(),"guest uses separate physical root")
  if failed:
   quit(1)
   return
 if host: await host_run()
 else: await guest_run()
 if not failed: print("PASS: guarded title, join, reconnect and shutdown ","host" if host else "guest")
 quit(1 if failed else 0)

func host_run() -> void:
 var menu:=title()
 check(Owner.completed(Owner.outcome(menu.storage.new_world_guarded(0))),"create host Garden")
 check(Owner.completed(Owner.outcome(menu.characters.create_guarded(0,"Host",0,[]))),"create host profile")
 var proof_hash:=place_unowned_proof()
 menu.select_character(0)
 menu.select_slot(0)
 menu.host_choice.button_pressed=true
 menu.continue_game()
 var world:=current_scene
 if world==menu or world.network_session.role()!="Host":
  check(false,"host continues and starts through the actual title")
  return
 var refused:=Slots._save_digest(G)
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,path):
  if phase=="stage" and path==G+".txn_stage":return ERR_FILE_CANT_WRITE
  return OK)
 mark("listening",str(world.network_session.port()))
 if not await until(func():return read("refused").contains("cancelled") and world.multiplayer.get_peers().is_empty()):
  check(false,"first admission refuses failed host persistence: "+read("refused"))
  return
 check(Slots._save_digest(G)==refused,"failed admission preserves host Garden")
 world.remove_meta(&"guarded_gameplay_test_fault")
 mark("admission-ready")
 if not await until(func():return read("joined")=="yes" and world.players.values().filter(func(p):return SessionCase.Session.ready_for(p)).size()==2):
  check(false,"guest enters actual guarded host")
  return
 var original: String=read("peer")
 check(await until(func():return read("reconnected")=="yes" and world.players.values().filter(func(p):return SessionCase.Session.ready_for(p)).size()==2),"guest disconnects and reconnects through title without waiting for host callback")
 var ids: Array=world.players.keys().filter(func(id):return id!=1)
 check(ids.size()==1 and str(ids[0])!=original,"reconnect is a fresh network peer")
 check(Slots._save_digest(Unowned+".transaction")==proof_hash and not FileAccess.file_exists(Unowned),"unowned Garden and evidence preserved")
 var before:=Slots._save_digest(G)
 world.return_to_main_menu()
 check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer and current_scene!=world,"host goes offline before returning to title")
 check(not FileAccess.file_exists(G.get_base_dir().path_join("session.cfg")) and not FileAccess.file_exists(HostProfile.get_base_dir().path_join("session.cfg")),"host releases both owned leases")
 check(await until(func():return read("saw-shutdown")=="yes"),"guest observes real host shutdown")
 print("CASE ",JSON.stringify({"case":"guarded_host_title_shutdown","garden_before":before,"garden_after":Slots._save_digest(G),"unowned_proof":proof_hash,"offline":true}))

func guest_run() -> void:
 if not await until(func():return read("listening").is_valid_int()):
  check(false,"host started")
  return
 var menu:=title()
 check(Owner.completed(Owner.outcome(menu.characters.create_guarded(1,"Guest",0,[]))),"create guest profile")
 var proof:=place_unowned_proof()
 menu.select_character(1)
 menu.select_slot(2)
 var before:=Slots._save_digest(P)
 menu.network_address="127.0.0.1"
 menu.network_port=int(read("listening"))
 check(menu.garden_summary(2).state=="pending_recovery" and menu.join_button.disabled==false,"guest can join with another Garden pending")
 var world:=launch_guest(menu)
 if world==null: return
 if not await until(func():return is_instance_valid(current_scene) and SessionCase.returned_to_guarded_title(current_scene)):
  check(false,"failed admission returns to title")
  return
 menu=current_scene
 check(not is_instance_valid(world) or world.network_session.transport()==null,"refused join went offline")
 check(Slots._save_digest(P)==before and not FileAccess.file_exists(P.get_base_dir().path_join("session.cfg")),"failed join unwinds selected profile lease")
 mark("refused",menu.return_message)
 if not await until(func():return read("admission-ready")=="ready"):
  check(false,"host clears controlled admission fault")
  return
 world=launch_guest(menu)
 if world==null: return
 if not await until(func():return is_instance_valid(world) and world.network_session.role()=="Guest" and world.guest_replication.has_details()):
  check(false,"first successful admission")
  return
 mark("peer",str(world.local_player_id()))
 mark("joined","yes")
 world.session_world.leave("Reconnect from title")
 menu=current_scene
 check(menu!=world and root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"guest offline before old world detaches")
 await process_frame
 world=launch_guest(menu)
 if world==null: return
 if not await until(func():return is_instance_valid(world) and world.network_session.role()=="Guest" and world.guest_replication.has_details()):
  check(false,"reconnect through guarded title")
  return
 mark("reconnected","yes")
 if not await until(func():return current_scene!=world and is_instance_valid(current_scene) and SessionCase.returned_to_guarded_title(current_scene)):
  check(false,"host disconnect returns guest to title")
  return
 var marker:=P.get_base_dir().path_join("session.cfg")
 check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"guest offline after host shutdown")
 check(await until(func():return not FileAccess.file_exists(marker)),"guest profile released after host shutdown")
 check(Slots._save_digest(Unowned+".transaction")==proof and not FileAccess.file_exists(Unowned),"guest never claims or recovers selected unowned Garden")
 print("CASE ",JSON.stringify({"case":"guarded_guest_reconnect_shutdown","profile_before":before,"profile_after":Slots._save_digest(P),"unowned_proof":proof,"offline":true}))
 mark("saw-shutdown","yes")
