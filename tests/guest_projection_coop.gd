extends SceneTree

const Slots = preload("res://save_slots.gd")
const Owner = preload("res://guarded_title_session.gd")
const Profile = preload("res://character_profile.gd")
const Tx = preload("res://game_transaction.gd")
const Ops = preload("res://persistence_operations.gd")
const Integration = preload("res://persistence_writer_integration.gd")
const G = "user://saves/slot_1/garden.cfg"
const P = "user://saves/characters/slot_2/character.cfg"
const Cases = ["apply","abort","recover","cleanup","uncertain","repair","lease","disconnect","pending"]
var signals: String
var world: Node
var failed := false

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: ",message)

func mark(key: String, value := "ready") -> void:
 var file := FileAccess.open(signals + key, FileAccess.WRITE)
 if file == null:
  check(false,"fixture marker " + key)
  return
 file.store_string(value)

func read(key: String) -> String:
 return FileAccess.get_file_as_string(signals + key)

func until(predicate: Callable) -> bool:
 var deadline := Time.get_ticks_msec() + 8000
 while not predicate.call() and Time.get_ticks_msec() < deadline:
  await process_frame
 return predicate.call()

func title() -> Node:
 var menu = load("res://main_menu.tscn").instantiate()
 menu.restore_last_character = false
 menu.restore_last_selection = false
 root.add_child(menu)
 current_scene = menu
 check(menu.production_route and menu.guarded_persistence,"default title selected candidate production route")
 return menu

func peer() -> int:
 for id in world.players:
  if id != 1 and world.players[id].profile_ready: return id
 return 0

func delivery(id: int) -> Dictionary:
 return world.players.get(id,{}).get("projection_delivery",{})

func current(id: int) -> Dictionary:
 var record: Dictionary = world.progress.character_records[world.players[id].seed_owner]
 return {"origin":world.progress.projection_origin,"profile":record.profile,"projection":record.projection}

func record_host(key: String, id: int, before: String) -> void:
 var payload := current(id)
 print("CASE ",JSON.stringify({"case":key,"role":"host","before":before,"after":Slots._save_digest(G),
  "receipt":payload.projection,"familiarity":payload.profile.plants[0],"upgrades":payload.profile.upgrades,
  "loadout":payload.profile.loadouts[0],"delivery":delivery(id).get("state","")}))

func record_guest(key: String, before: String) -> void:
 var profile := Profile.new()
 profile.path = P
 check(profile.load_profile(false)==OK,"guest canonical profile readable")
 print("CASE ",JSON.stringify({"case":key,"role":"guest","before":before,"after":Slots._save_digest(P),
  "receipts":profile.projection_receipts,"canonical_familiarity":profile.data.plants[0],
  "memory_familiarity":world.guest_character.data.plants[0],"loadout":profile.data.loadouts[0],
  "notice":Tx.pending_notice(world),"feedback":world.status,"journal":Slots._save_digest(P+".transaction")}))

func send_action(id: int, key: String) -> bool:
 var player: Dictionary = world.players[id]
 var result: Dictionary = world.run_guarded_action(id,Tx.Scope.GARDEN,func(effects):
  player.character.plants[0] += 1
  player.character.xp[0] += 100
  player.character.upgrades[0] = 0
  player.character.loadouts[0].weapon = 1
  world.save_action_profile(id,effects)
  effects.append(world.tell_profile_action.bind(id,"Profile committed "+key))
  return true)
 return Tx.committed(result.persistence)

func host() -> void:
 var menu := title()
 check(Owner.completed(Owner.outcome(menu.storage.new_world_guarded(0))),"host Garden")
 check(Owner.completed(Owner.outcome(menu.characters.create_guarded(0,"Host",0,[]))),"host profile")
 menu.select_character(0)
 menu.select_slot(0)
 menu.host_choice.button_pressed = true
 menu.continue_game()
 world = current_scene
 check(world != menu and world.session == "Host","guarded host")
 if failed: return
 mark("listen",str(world.network_port))
 var older := {}
 var last_revision := 0
 for index in Cases.size():
  var key: String = Cases[index]
  if not await until(func():return not read(key+"-ready").is_empty() and peer()!=0 and delivery(peer()).get("state") in ["committed","cleanup_pending"]):
   check(false,"guest ready for "+key)
   return
  var id := peer()
  var before := Slots._save_digest(G)
  if key in ["recover","repair"]:
   check(current(id).projection.revision==last_revision,"reconnect acknowledges the original host revision without replay")
  elif key=="pending":
   check(send_action(id,key),"host commits before disconnect")
   check(delivery(id).state=="pending","host can disconnect without an acknowledgment")
   record_host(key,id,before)
   world.return_to_main_menu()
   check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"host offline on exit")
   check(await until(func():return read("pending-done")=="ready"),"guest observed shutdown")
   return
  else:
   older = current(id)
   check(send_action(id,key),"host commits "+key)
   last_revision = current(id).projection.revision
   check(delivery(id).state=="pending" and Slots._save_digest(G)!=before,"Garden committed before any guest acknowledgment")
   if key=="apply":
    world.receive_character.rpc_id(id,older)
    world.send_committed_profile(id)
  if key=="disconnect":
   record_host(key,id,before)
   check(await until(func():return peer()==0 and read(key+"-done")=="ready"),"disconnect leaves host commit without a persistence acknowledgment")
   mark(key+"-offline")
   continue
  var expected: String = {"abort":"aborted","cleanup":"cleanup_pending","uncertain":"uncertain","lease":"refused"}.get(key,"committed")
  if not await until(func():return delivery(id).get("state")==expected and read(key+"-done")=="ready"):
   check(false,key+" host state "+str(delivery(id)))
   return
  record_host(key,id,before)
  mark(key+"-advance")
  if key in ["abort","cleanup","uncertain","lease"]:
   check(await until(func():return peer()==0),"host observes disconnect after "+key)
   mark(key+"-offline")

func open_guest(menu: Node) -> bool:
 menu.network_address = "127.0.0.1"
 menu.network_port = int(read("listen"))
 menu.select_character(1)
 menu.join_game()
 world = current_scene
 if world==menu: return false
 return await until(func():return is_instance_valid(world) and world.session=="Guest" and not world.client_details.is_empty())

func guest() -> void:
 if not await until(func():return read("listen").is_valid_int()):
  check(false,"host not listening")
  return
 var menu := title()
 check(Owner.completed(Owner.outcome(menu.characters.create_guarded(1,"Guest",0,[]))),"guest profile")
 var initial := Profile.new()
 initial.path = P
 check(initial.load_profile(false)==OK,"load initial guest class data")
 initial.data.xp[0] = 9999
 initial.data.upgrades[0] = 1 << initial.Classes.Warden.OFFSET
 initial.data.loadouts[0].weapon = 2
 check(initial.save_profile_guarded().value.outcome.outcome==preload("res://save_batch.gd").Outcome.COMMITTED,"seed existing class and loadout before join")
 if not await open_guest(menu):
  check(false,"guest admission")
  return
 var expected := 0
 var staged := {"count":0}
 for index in Cases.size():
  var key: String = Cases[index]
  var before := Slots._save_digest(P)
  var count: int = staged.count
  if key=="lease":
   var marker := P.get_base_dir().path_join("session.cfg")
   var lease := ConfigFile.new()
   lease.set_value("session","process_id",OS.get_process_id())
   lease.set_value("session","updated",Time.get_unix_time_from_system()-60)
   check(lease.save(marker)==OK,"expire guest lease")
   world.get_meta(Tx.SESSION)._heartbeat_at=Time.get_unix_time_from_system()+20
  world.set_meta(&"guarded_gameplay_test_fault",func(phase,path):
   if phase=="stage":
    staged.count += 1
    if key=="abort": return ERR_FILE_CANT_WRITE
   if key=="cleanup" and phase=="publish_receipt": return ERR_CANT_CREATE
   if key=="uncertain":
    if phase=="publish_commit_marker": return ERR_CANT_CREATE
    if phase=="restore": return ERR_FILE_CANT_WRITE
   if key=="disconnect" and phase=="replace" and path==P:
    world.go_offline()
   return OK)
  mark(key+"-ready")
  if key=="pending":
   check(await until(func():return current_scene!=world),"guest returns to title on host shutdown")
   mark("pending-done")
   return
  if key=="apply":
   check(world.guest_character.data.upgrades[0]!=0 and world.guest_character.data.loadouts[0].weapon==2,"initial non-monotonic values are present")
   expected+=1
   check(await until(func():return world.status=="Profile committed apply"),"success feedback after acknowledgment")
   check(staged.count==count+1 and world.guest_character.data.plants[0]==expected,"duplicate and delayed old revision do not stage or apply")
   check(world.guest_character.data.upgrades[0]==0 and world.guest_character.data.loadouts[0].weapon==1,"respec and reduced weapon choice are committed")
  elif key=="abort":
   check(await until(func():return world.has_meta(&"guest_projection_notice")),"aborted projection is visible")
   check(Slots._save_digest(P)==before and world.guest_character.data.plants[0]==expected and not world.status.begins_with("Profile committed"),"abort preserves guest bytes, memory and withholds success")
  elif key=="cleanup":
   expected+=1
   check(await until(func():return Tx.pending_notice(world)==Tx.CLEANUP_NOTICE),"confirmed cleanup pending")
   check(world.guest_character.data.plants[0]==expected and Slots._save_digest(P)!=before,"cleanup pending retains committed profile")
  elif key=="uncertain":
   check(await until(func():return Tx.pending_notice(world).contains("uncertain")),"uncertain guest commit")
   check(FileAccess.file_exists(P+".transaction") and world.guest_character.data.plants[0]==expected+1,"uncertain retains tentative memory and journal")
  elif key=="lease":
   await create_timer(.35).timeout
   check(Slots._save_digest(P)==before and staged.count==count,"delayed projection after lease expiry writes nothing")
  elif key=="disconnect":
   expected+=1
   check(await until(func():return Slots._save_digest(P)!=before and world.online_peer==null),"authorized guest save can finish after transport closes")
   check(world.guest_character.data.plants[0]==expected and not world.status.begins_with("Profile committed disconnect"),"committed local bytes without an acknowledgment or success toast")
  else:
   expected+=int(key in ["recover","repair"])
   check(world.guest_character.data.plants[0]==expected and world.guest_character.data.loadouts[0].weapon==1,"reconnected data matches committed revision")
  record_guest(key,before)
  mark(key+"-done")
  if key=="disconnect":
   world.return_to_main_menu()
   await process_frame
   check(await until(func():return read(key+"-offline")=="ready"),"host drops the disconnected peer")
   if not await open_guest(current_scene):
    check(false,"reconnect proves already committed local receipt")
    return
   check(world.guest_character.data.plants[0]==expected,"reconnect after lost acknowledgment does not duplicate credit")
   continue
  if not await until(func():return read(key+"-advance")=="ready"):
   check(false,"host did not verify "+key)
   return
  if key in ["abort","cleanup","uncertain","lease"]:
   if is_instance_valid(world) and current_scene == world: world.return_to_main_menu()
   check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"guest offline before world detach")
   await process_frame
   if key in ["cleanup","uncertain"]:
    check(Ops.recover(PackedStringArray([P])).value.verified,"explicit guest B2 recovery")
   if key=="lease":
    # The fixture's expired marker no longer claims the slot.
    expected+=1
   check(await until(func():return read(key+"-offline")=="ready"),"host releases prior peer before reconnect")
   if not await open_guest(current_scene):
    check(false,"guest reconnect after "+key)
    return

func run() -> void:
 set_meta(Integration.VALIDATION_ROUTE,true)
 var is_host := OS.get_cmdline_user_args()[0]=="host"
 signals = ProjectSettings.globalize_path("user://release-fixtures/guest-projection-")
 if not is_host:
  var data := OS.get_environment("APPDATA").path_join("guest")
  check(DirAccess.make_dir_recursive_absolute(data.path_join(OS.get_user_data_dir().get_file()))==OK,"create guest root")
  OS.set_environment("APPDATA",data)
 if is_host: await host()
 else: await guest()
 if not failed: print("PASS: guarded projection ", "host" if is_host else "guest")
 quit(1 if failed else 0)
