extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")

const Slots = preload("res://save_slots.gd")
const Owner = preload("res://guarded_title_session.gd")
const Profile = preload("res://character_profile.gd")
const Warden = preload("res://warden_connected_tree.gd")
const Tx = preload("res://game_transaction.gd")
const Ops = preload("res://persistence_operations.gd")
const Integration = preload("res://persistence_writer_integration.gd")
const G = "user://saves/slot_1/garden.cfg"
const P = "user://saves/characters/slot_2/character.cfg"
const Cases = ["apply","abort","recover","cleanup","uncertain","repair","lease","disconnect","pending"]
var signals: String
var world: Node
var failed := false
var projection_mode := OS.get_environment("MYSTICAL_F5_PROJECTION")
var actual_actions := projection_mode in ["actions","appearance"]

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
 var menu = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
 menu.restore_last_character = false
 menu.restore_last_selection = false
 root.add_child(menu)
 current_scene = menu
 check(menu.production_route and menu.guarded_persistence,"default title selected candidate production route")
 return menu

func peer() -> int:
 for id in world.players:
  if id != 1 and SessionCase.Session.ready_for(world.players[id]): return id
 return 0

func delivery(id: int) -> Dictionary:
 return world.players.get(id,{}).get("projection_delivery",{})

func current(id: int) -> Dictionary:
 var record: Dictionary = world.progress.character_records[SessionCase.Session.inventory_owner(world.players[id])]
 return {"origin":world.progress.projection_origin,"profile":record.profile,"projection":record.projection}

func record_host(key: String, id: int, before: String) -> void:
 var payload := current(id)
 print("CASE ",JSON.stringify({"case":key,"role":"host","before":before,"after":Slots._save_digest(G),
  "receipt":payload.projection,"familiarity":payload.profile.plants[0],"connected_path":Warden.path(payload.profile),
  "loadout":payload.profile.loadouts[0],"appearance":payload.profile.appearance,"delivery":delivery(id).get("state","")}))

func record_guest(key: String, before: String) -> void:
 var profile := Profile.new()
 profile.path = P
 check(profile.load_profile(false)==OK,"guest canonical profile readable")
 print("CASE ",JSON.stringify({"case":key,"role":"guest","before":before,"after":Slots._save_digest(P),
  "receipts":profile.projection_receipts,"canonical_familiarity":profile.data.plants[0],
  "memory_familiarity":world.guest_character.data.plants[0],"loadout":profile.data.loadouts[0],
  "canonical_appearance":profile.data.appearance,"memory_appearance":world.guest_character.data.appearance,
  "notice":world.persistence_session.pending_notice(),"feedback":world.status,"journal":Slots._save_digest(P+".transaction")}))

func send_action(id: int, key: String) -> bool:
 var player: Dictionary = world.players[id]
 var result: Dictionary = world.run_guarded_action(id,Tx.Scope.GARDEN,func(effects):
  player.character.plants[0] += 1
  player.character.xp[0] += 1000
  player.character[Warden.PROFILE_KEY] = Warden.state([])
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
 check(world != menu and world.network_session.role() == "Host","guarded host")
 if failed: return
 mark("listen",str(world.network_session.port()))
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
 return await until(func():return is_instance_valid(world) and world.network_session.role()=="Guest" and world.guest_replication.has_details())

func guest() -> void:
 if not await until(func():return read("listen").is_valid_int()):
  check(false,"host not listening")
  return
 var menu := title()
 check(Owner.completed(Owner.outcome(menu.characters.create_guarded(1,"Guest",0,[]))),"guest profile")
 var initial := Profile.new()
 initial.path = P
 check(initial.load_profile(false)==OK,"load initial guest class data")
 initial.data.xp[0] = Profile.Experience.MAX_XP
 initial.data[Warden.PROFILE_KEY] = Warden.state(["vanguard"])
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
   world.persistence_session._heartbeat_at=Time.get_unix_time_from_system()+20
  if key=="cleanup":
   # Observe the positive acknowledgment while the peer is still attached.
   # The next heartbeat can legitimately return a cleanup-pending guest to title.
   world.persistence_session._heartbeat_at=Time.get_unix_time_from_system()
  world.set_meta(&"guarded_gameplay_test_fault",func(phase,path):
   if phase=="stage":
    staged.count += 1
    if key=="abort": return ERR_FILE_CANT_WRITE
   if key=="cleanup" and phase=="publish_receipt":
    world.persistence_session._heartbeat_at=Time.get_unix_time_from_system()+8.0
    return ERR_CANT_CREATE
   if key=="uncertain":
    if phase=="publish_commit_marker": return ERR_CANT_CREATE
    if phase=="restore": return ERR_FILE_CANT_WRITE
   if key=="disconnect" and phase=="replace" and path==P:
    world.session_world.offline()
   return OK)
  mark(key+"-ready")
  if key=="pending":
   check(await until(func():return current_scene!=world),"guest returns to title on host shutdown")
   mark("pending-done")
   return
  if key=="apply":
   check(not Warden.path(world.guest_character.data).is_empty() and world.guest_character.data.loadouts[0].weapon==2,"initial non-monotonic values are present")
   expected+=1
   check(await until(func():return world.status=="Profile committed apply"),"success feedback after acknowledgment")
   check(staged.count==count+1 and world.guest_character.data.plants[0]==expected,"duplicate and delayed old revision do not stage or apply")
   check(Warden.path(world.guest_character.data).is_empty() and world.guest_character.data.loadouts[0].weapon==1,"respec and reduced weapon choice are committed")
  elif key=="abort":
   check(await until(func():return world.has_meta(&"guest_projection_notice")),"aborted projection is visible")
   check(Slots._save_digest(P)==before and world.guest_character.data.plants[0]==expected and not world.status.begins_with("Profile committed"),"abort preserves guest bytes, memory and withholds success")
  elif key=="cleanup":
   expected+=1
   check(await until(func():return world.persistence_session.pending_notice()==Tx.CLEANUP_NOTICE),"confirmed cleanup pending")
   check(world.guest_character.data.plants[0]==expected and Slots._save_digest(P)!=before,"cleanup pending retains committed profile")
  elif key=="uncertain":
   check(await until(func():return world.persistence_session.pending_notice().contains("uncertain")),"uncertain guest commit")
   check(FileAccess.file_exists(P+".transaction") and world.guest_character.data.plants[0]==expected+1,"uncertain retains tentative memory and journal")
  elif key=="lease":
   await create_timer(.35).timeout
   check(Slots._save_digest(P)==before and staged.count==count,"delayed projection after lease expiry writes nothing")
  elif key=="disconnect":
   expected+=1
   check(await until(func():return Slots._save_digest(P)!=before and world.network_session.transport()==null),"authorized guest save can finish after transport closes")
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
   if key=="cleanup":
    # Now exercise the real pending heartbeat exit rather than requiring it
    # to race the acknowledgment. Recovery remains explicit after detach.
    if is_instance_valid(world) and current_scene == world:
     world.persistence_session._heartbeat_at=0.0
    check(await until(func():return current_scene!=world),"cleanup-pending heartbeat returns guest to title")
    check(current_scene.persistence_return_view().get("notice", "")==Tx.CLEANUP_NOTICE,"cleanup notice survives title handoff")
   elif is_instance_valid(world) and current_scene == world:
    # Interrupt the transport, rather than request a graceful custody release
    # which would itself repair the missing projection before reconnect.
    world.session_world.offline()
    world.return_to_main_menu()
   if not await until(func():return not is_instance_valid(world) or current_scene!=world):
    check(false,"guest releases profile lease and returns to title after "+key);return
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
 if actual_actions:
  if is_host: await action_host()
  else: await action_guest()
 elif is_host: await host()
 else: await guest()
 if not failed: print("PASS: guarded projection ", "host" if is_host else "guest")
 quit(1 if failed else 0)


# The normal case matrix above isolates the acknowledgment protocol. This case
# drives Learn and Respec through their own multiplayer command handlers.
func action_host() -> void:
 var menu := title()
 menu.host_choice.button_pressed=true
 menu.new_button.pressed.emit()
 menu.creator.name_field.text="Action Host"
 menu.creator.confirmed.emit()
 await process_frame
 if current_scene==menu: menu.new_button.pressed.emit()
 world=current_scene
 if world==menu or world.network_session.role()!="Host":
  check(false,"actual host title launch")
  return
 mark("listen",str(world.network_session.port()))
 for step in (["appearance"] if projection_mode=="appearance" else ["learn","respec","loadout"]):
  if not await until(func(): return peer()!=0 and delivery(peer()).get("state")=="committed" and read(step+"-ready")=="ready"):
   check(false,step+" guest admitted")
   return
  var id := peer()
  var player: Dictionary = world.players[id]
  player.pos = world.stage.gate_position() if step=="loadout" else world.Stage.HEART
  var before := Slots._save_digest(G)
  var old := current(id).duplicate(true)
  mark(step+"-send")
  if step=="appearance":
   check(await until(func(): return current(id).projection.revision>old.projection.revision),
    "actual guest action commits an appearance revision on the host")
   check(delivery(id).get("state")=="pending" and Slots._save_digest(G)!=before,
    "host Garden commits before any guest success acknowledgment")
   record_host("appearance_pending_ack",id,before)
  var expected: String = {"learn":"aborted","respec":"cleanup_pending","loadout":"uncertain","appearance":"aborted"}[step]
  if not await until(func(): return delivery(id).get("state")==expected and read(step+"-observed")=="ready"):
   check(false,step+" acknowledgment disposition "+str(delivery(id)))
   return
  var committed := current(id)
  check(committed.projection.revision==old.projection.revision+1 and Slots._save_digest(G)!=before,"host commits one "+step+" revision")
  match step:
   "learn": check(not Warden.path(committed.profile).is_empty(),"actual learn updates host projection")
   "respec": check(Warden.path(committed.profile).is_empty(),"actual respec updates host projection")
   "loadout": check(committed.profile.loadouts[0].weapon==1,"actual loadout updates host projection")
   "appearance": check(committed.profile.appearance[0]==(int(old.profile.appearance[0])+1)%world.LOOK_NAMES[0].size(),"host records appearance once without waiting for the guest save")
  record_host("actual_"+step,id,before)
  mark(step+"-leave")
  if not await until(func(): return peer()!=0 and peer()!=id and delivery(peer()).get("state")=="committed" and read(step+"-rejoined")=="ready"):
   check(false,step+" reconnects and acknowledges authoritative revision")
   return
  var new_id := peer()
  check(current(new_id).projection.revision==committed.projection.revision,"reconnect never replays "+step)
  world.receive_character.rpc_id(new_id,old)
  world.send_committed_profile(new_id)
  mark(step+"-duplicate")
  if not await until(func(): return read(step+"-checked")=="ready"):
   check(false,step+" duplicate checks")
   return
 world.return_to_main_menu()
 check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"action host offline before teardown")

func action_guest() -> void:
 if not await until(func():return read("listen").is_valid_int()):
  check(false,"action host listens")
  return
 var menu := title()
 menu.select_character(1)
 menu.request_create_character()
 menu.creator.name_field.text="Action Guest"
 menu.creator.confirmed.emit()
 var initial := Profile.new()
 initial.path=P
 check(initial.load_profile(false)==OK,"load fixture XP")
 initial.data.xp[0]=Profile.Experience.MAX_XP
 check(initial.save_profile_guarded().value.outcome.outcome==Ops.Batch.Outcome.COMMITTED,"seed legal Learn eligibility")
 if not await open_guest(menu):
  check(false,"actual action guest admitted")
  return
 for step in (["appearance"] if projection_mode=="appearance" else ["learn","respec","loadout"]):
  var before := Slots._save_digest(P)
  var prior: Dictionary = world.guest_character.data.duplicate(true)
  var stages := {"count":0}
  world.set_meta(&"guarded_gameplay_test_fault",func(phase,_path):
   if phase=="stage": stages.count+=1
   if step in ["learn","appearance"] and phase=="stage": return ERR_FILE_CANT_WRITE
   if step=="respec" and phase=="publish_receipt": return ERR_CANT_CREATE
   if step=="loadout" and phase in ["publish_commit_marker","restore"]: return ERR_CANT_CREATE
   return OK)
  mark(step+"-ready")
  if not await until(func(): return read(step+"-send")=="ready"):
   check(false,step+" host positions traveller")
   return
  world.send_garden_action({"learn":"learn_0_64","respec":"respec_0","loadout":"loadweapon_1","appearance":"look_0"}[step])
  if not await until(func(): return stages.count==1 and (world.has_meta(&"guest_projection_notice") or not world.persistence_session.pending_notice().is_empty())):
   check(false,step+" local projection result")
   return
  var blocked := Slots._save_digest(P)
  match step:
   "learn":
    check(blocked==before and Warden.path(world.guest_character.data)==Warden.path(prior) and not world.status.begins_with("Learned"),"Learn abort preserves points and withholds feedback")
   "respec":
    check(blocked!=before and Warden.path(world.guest_character.data).is_empty() and world.persistence_session.pending_notice()==Tx.CLEANUP_NOTICE,"respec cleanup pending keeps confirmed change and warning")
   "loadout":
    check(world.persistence_session.pending_notice().contains("uncertain") and FileAccess.file_exists(P+".transaction"),"uncertain loadout keeps recovery evidence")
   "appearance":
    check(blocked==before and world.guest_character.data.appearance==prior.appearance
     and world.get_meta(&"guest_projection_notice","").contains("not saved"),
     "failed appearance save preserves local canonical and runtime profile and displays refusal")
  record_guest("actual_"+step,before)
  mark(step+"-observed")
  if not await until(func(): return read(step+"-leave")=="ready"):
   check(false,step+" host observed disposition")
   return
  world.return_to_main_menu()
  check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"action guest offline before detach")
  await process_frame
  menu=current_scene
  if step in ["respec","loadout"]:
   check(menu.recovery_notice.visible and menu.join_button.disabled,step+" title keeps recovery warning and blocks Join")
   menu.character_recovery_button.pressed.emit()
   menu.recovery_confirmation.confirmed.emit()
   check(Slots._save_digest(P)==(blocked if step=="respec" else before),"actual guest recovery keeps authoritative bytes")
  if not await open_guest(menu):
   check(false,step+" guest reconnects")
   return
  match step:
   "learn": check(not Warden.path(world.guest_character.data).is_empty(),"Learn is applied once on reconnect")
   "respec": check(Warden.path(world.guest_character.data).is_empty(),"reconnect preserves refunded class points")
   "loadout": check(world.guest_character.data.loadouts[0].weapon==1,"reconnect applies current loadout")
   "appearance":
    check(world.guest_character.data.appearance[0]==(int(prior.appearance[0])+1)%world.LOOK_NAMES[0].size()
     and Slots._save_digest(P)!=before,"reconnect commits host appearance revision to the guest profile exactly once")
  var joined := Slots._save_digest(P)
  if step=="appearance": record_guest("appearance_reconnect",before)
  mark(step+"-rejoined")
  check(await until(func():return read(step+"-duplicate")=="ready"),"host sends duplicate and delayed revision")
  await create_timer(.3).timeout
  check(Slots._save_digest(P)==joined and not FileAccess.file_exists(G),"duplicate and stale projection preserve guest profile and host ownership")
  mark(step+"-checked")
 check(await until(func():return current_scene!=world),"host disconnect returns guest to title")
 check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"guest is offline after actual host shutdown")
