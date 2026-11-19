extends SceneTree
const SessionCase = preload("res://tests/support/session_case.gd")

const Gate = preload("res://persistence_writer_integration.gd")
const Ops = preload("res://persistence_operations.gd")
const Batch = preload("res://save_batch.gd")
const Tx = preload("res://game_transaction.gd")
const Slots = preload("res://save_slots.gd")
const Profile = preload("res://character_profile.gd")
const Garden = preload("res://progress.gd")
const Developer = preload("res://developer_mode.gd")
const G = "user://saves/slot_1/garden.cfg"
const P = "user://saves/characters/slot_1/character.cfg"
const Other = "user://saves/slot_3/garden.cfg"
var failed := false

# Forward the real title calls to the existing guarded writer with a
# deterministic fault. The title still captures and passes its own digest.
class FaultedSlots extends "res://save_slots.gd":
 var phase := ""
 var fail_restore := false
 var last := {}
 func inject(step: String, _path: String) -> Error:
  return ERR_CANT_CREATE if step==phase or (step=="restore" and fail_restore) else OK
 func new_world_guarded(slot: int, confirmed := false, digest := "") -> Dictionary:
  last = _initialize_guarded(slot,false,confirmed,false,inject,"",{} if digest.is_empty() else {paths(slot).garden:digest})
  return last
 func delete_world_guarded(slot: int, confirmed := false, digest := "") -> Dictionary:
  last = _delete_guarded(slot,false,confirmed,{} if digest.is_empty() else {paths(slot).garden:digest},inject)
  return last

class FaultedRoster extends "res://character_slots.gd":
 var phase := ""
 var fail_restore := false
 var last := {}
 func inject(step: String, _path: String) -> Error:
  return ERR_CANT_CREATE if step==phase or (step=="restore" and fail_restore) else OK
 func update_guarded(slot: int, name: String, class_id: int, appearance: Array, digest := "") -> Dictionary:
  last = _edit_guarded(slot,name,class_id,appearance,true,digest,inject)
  return last
 func delete_character_guarded(slot: int, confirmed := false, digest := "") -> Dictionary:
  last = _delete_guarded(slot,confirmed,digest,inject)
  return last

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: ",message)

func launch_title() -> Node:
 var title = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
 root.add_child(title)
 current_scene = title
 return title

func read(path: String) -> Dictionary:
 return Ops.Planner.discover(PackedStringArray([path]))

func record(key: String, detail: Dictionary) -> void:
 print("CASE ",JSON.stringify({"case":key,"garden":Slots._save_digest(G),"profile":Slots._save_digest(P),"detail":detail}))

func journal(anchor: String, participants: Array, committed := false) -> String:
 var entries := {}
 for path in participants:
  entries[path] = {"exists":FileAccess.file_exists(path),"bytes":FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()}
 var file := ConfigFile.new()
 file.set_value("transaction","entries",entries)
 file.set_value("transaction","committed",committed)
 check(file.save(anchor+".transaction")==OK,"fixture journal created")
 return anchor+".transaction"

func outcome(store: FaultedSlots, expected: Batch.Outcome) -> void:
 var result := preload("res://guarded_title_session.gd").outcome(store.last)
 var final: Batch.Finalization = result.get("outcome")
 check(final != null and final.outcome == expected, "title finalization: "+str(result.get("state")))
 if final != null:
  print("CASE ",JSON.stringify({"case":"title_writer_outcome","outcome":Batch.Outcome.keys()[final.outcome],
   "phase":final.phase,"paths":final.paths,"garden":Slots._save_digest(G),"profile":Slots._save_digest(P),
   "tombstone":Slots._save_digest(G.get_base_dir().path_join("deleted.cfg")),
   "journal":Slots._save_digest(G+".transaction"),"archives":result.get("archives",{})}))

func title_faults(menu: Node) -> void:
 var store := FaultedSlots.new()
 store.root_path = menu.storage.root_path
 menu.storage = store
 var saved := Slots._save_digest(G)
 var profile := Slots._save_digest(P)
 var marker := G.get_base_dir().path_join("deleted.cfg")
 check(Slots._save_digest(marker)=="absent","disposable title starts without tombstone")
 store.phase = "publish_commit_marker"
 menu.new_button.pressed.emit()
 menu.confirmation.confirmed.emit()
 outcome(store,Batch.Outcome.ABORTED_RESTORED)
 check(current_scene==menu and Slots._save_digest(G)==saved and Slots._save_digest(P)==profile
  and Slots._save_digest(G+".transaction")=="absent" and menu.confirmation.get_ok_button().disabled,
  "replacement rollback restores bytes and refuses launch")
 menu.confirmation.hide()
 menu.delete_button.pressed.emit()
 menu.deletion_confirmation.confirmed.emit()
 outcome(store,Batch.Outcome.ABORTED_RESTORED)
 check(current_scene==menu and Slots._save_digest(G)==saved and Slots._save_digest(P)==profile
  and Slots._save_digest(marker)=="absent" and not menu.notice.text.contains("deleted."),
  "delete rollback restores Garden and recorded tombstone absence")
 menu.deletion_confirmation.hide()
 store.fail_restore = true
 menu.delete_button.pressed.emit()
 menu.deletion_confirmation.confirmed.emit()
 outcome(store,Batch.Outcome.UNCERTAIN)
 var evidence := Slots._save_digest(G+".transaction")
 check(evidence!="absent" and Slots._save_digest(P)==profile and menu.continue_button.disabled
  and menu.delete_button.disabled and not menu.notice.text.contains("deleted."),"uncertain deletion blocks replay and success")
 menu.deletion_confirmation.hide()
 menu.garden_recovery_button.pressed.emit()
 menu.recovery_confirmation.confirmed.emit()
 check(Slots._save_digest(G)==saved and Slots._save_digest(P)==profile and Slots._save_digest(marker)=="absent",
  "title recovery restores Garden and tombstone absence")
 store.phase = "publish_receipt"
 store.fail_restore = false
 menu.new_button.pressed.emit()
 menu.confirmation.confirmed.emit()
 outcome(store,Batch.Outcome.COMMITTED_CLEANUP_PENDING)
 check(current_scene==menu and Slots._save_digest(G)!=saved and Slots._save_digest(P)==profile
  and menu.continue_button.disabled and menu.notice.text.contains("cleanup"),"committed replacement warns and blocks launch pending cleanup")
 var replacement := Slots._save_digest(G)
 menu.confirmation.hide()
 menu.garden_recovery_button.pressed.emit()
 menu.recovery_confirmation.confirmed.emit()
 check(Slots._save_digest(G)==replacement and Slots._save_digest(G+".transaction")=="absent","title cleanup retains new Garden")
 store.phase = ""

func outcome_code(boundary: Dictionary, expected: Batch.Outcome, name: String) -> void:
 var result := preload("res://guarded_title_session.gd").outcome(boundary)
 var final: Batch.Finalization = result.get("outcome")
 check(final != null and final.outcome == expected, name+" finalization: "+str(result.get("state")))
 if final == null: return
 var files := {}
 for path: String in final.paths:
  files[path] = Slots._save_digest(path)
 for path: String in result.get("archives",{}).values():
  files[path] = Slots._save_digest(path)
 var lease := final.journal_anchor.get_base_dir().path_join("session.cfg")
 print("CASE ",JSON.stringify({"case":name,"outcome":Batch.Outcome.keys()[final.outcome],
  "files":files,"journal":Slots._save_digest(final.journal_anchor+".transaction"),"lease":Slots._save_digest(lease),
  "phase":final.phase,"errors":[final.original_error,final.recovery_error,final.cleanup_error]}))

func roster_faults(menu: Node) -> void:
 var store := FaultedRoster.new()
 store.root_path = menu.characters.root_path
 menu.characters = store
 var profile: String = store.paths(1).character
 var catalog: String = store.root_path.path_join("catalog.cfg")
 var g := Slots._save_digest(G)
 var original := Slots._save_digest(profile)
 var catalog_original := Slots._save_digest(catalog)
 for mode in ["edit_uncertain","edit_cleanup","delete_archive","delete_catalog_abort","delete_uncertain","delete_cleanup"]:
  var editing: bool = mode.begins_with("edit")
  var uncertain: bool = mode.ends_with("uncertain")
  var cleanup: bool = mode.ends_with("cleanup")
  store.fail_restore = uncertain
  store.phase = "publish_receipt" if cleanup else "archive" if mode=="delete_archive" else "replace" if mode=="delete_catalog_abort" else "publish_commit_marker"
  menu.select_character(1)
  if editing:
   menu.request_create_character()
   menu.creator.name_field.text = "Committed "+mode
   menu.creator.confirmed.emit()
   check(menu.creator.get_ok_button().disabled and not menu.notice.text.contains("Committed "+mode),"no ordinary edit success: "+mode)
   menu.creator.dismiss()
  else:
   menu.delete_character_button.pressed.emit()
   menu.character_deletion.confirmed.emit()
   check(menu.character_deletion.get_ok_button().disabled and not menu.notice.text.contains("deleted."),"no ordinary delete success: "+mode)
   menu.character_deletion.hide()
  check(Slots._save_digest(G)==g,"roster action leaves Garden unchanged: "+mode)
  if mode=="delete_archive":
   var failed_archive := preload("res://guarded_title_session.gd").outcome(store.last)
   check(failed_archive.get("state")=="verified_failure" and Slots._save_digest(profile)==original
    and Slots._save_digest(catalog)==catalog_original and Slots._save_digest(profile+".transaction")=="absent","archive failure preserves roster and catalog")
   record(mode,{"profile":original,"catalog":catalog_original,"reason":failed_archive.get("reason"),"notice":menu.notice.text})
   continue
  var expected := Batch.Outcome.UNCERTAIN if uncertain else Batch.Outcome.COMMITTED_CLEANUP_PENDING if cleanup else Batch.Outcome.ABORTED_RESTORED
  outcome_code(store.last,expected,mode)
  if mode=="delete_catalog_abort":
   check(Slots._save_digest(profile)==original and Slots._save_digest(catalog)==catalog_original,"catalog failure restores both participants")
   continue
  var during := Slots._save_digest(profile)
  var during_catalog := Slots._save_digest(catalog)
  check(menu.character_summary(1).state=="pending_recovery" and menu.join_button.disabled
   and Slots._save_digest(profile+".transaction")!="absent","title blocks admission pending reconciliation: "+mode)
  menu.character_recovery_button.pressed.emit()
  menu.recovery_confirmation.confirmed.emit()
  check(Slots._save_digest(profile)==(original if uncertain else during)
   and Slots._save_digest(catalog)==(catalog_original if uncertain else during_catalog),"B2 verifies the authoritative roster state: "+mode)
  if cleanup:
   original = during
   catalog_original = during_catalog
 store.phase=""
 store.fail_restore=false
 check(menu.character_summary(1).state=="empty" and Slots._save_digest(profile)=="absent","verified delete cleanup exposes vacant slot")
 menu.select_character(0)

func garden_f5_faults(menu: Node) -> void:
 var store := FaultedSlots.new()
 store.root_path = menu.storage.root_path
 menu.storage = store
 var original := Slots._save_digest(G)
 var profile := Slots._save_digest(P)
 var marker := G.get_base_dir().path_join("deleted.cfg")
 for mode in ["replace_uncertain","delete_archive","delete_cleanup"]:
  store.phase = "publish_commit_marker" if mode=="replace_uncertain" else "archive" if mode=="delete_archive" else "publish_receipt"
  store.fail_restore = mode=="replace_uncertain"
  if store.fail_restore:
   menu.new_button.pressed.emit()
   menu.confirmation.confirmed.emit()
   check(current_scene==menu and not menu.transitioning,"uncertain replacement stays at title")
   menu.confirmation.hide()
  else:
   menu.delete_button.pressed.emit()
   menu.deletion_confirmation.confirmed.emit()
   check(not menu.notice.text.contains("deleted."),"deletion with adverse result has no ordinary success")
   menu.deletion_confirmation.hide()
  check(Slots._save_digest(P)==profile,"Garden management leaves roster untouched")
  if mode=="delete_archive":
   var result := preload("res://guarded_title_session.gd").outcome(store.last)
   check(result.get("state")=="verified_failure" and Slots._save_digest(G)==original
    and Slots._save_digest(marker)=="absent" and Slots._save_digest(G+".transaction")=="absent","archive failure creates no tombstone")
   record("garden_archive_failure",{"before":original,"tombstone":Slots._save_digest(marker),"reason":result.get("reason")})
   continue
  outcome_code(store.last,Batch.Outcome.UNCERTAIN if store.fail_restore else Batch.Outcome.COMMITTED_CLEANUP_PENDING,"garden_"+mode)
  check(menu.continue_button.disabled and Slots._save_digest(G+".transaction")!="absent","unresolved Garden cannot be opened")
  if mode=="delete_cleanup":
   check(Slots._save_digest(G)=="absent" and Slots._save_digest(marker)!="absent","confirmed delete has tombstone and durable evidence")
  menu.garden_recovery_button.pressed.emit()
  menu.recovery_confirmation.confirmed.emit()
  check(Slots._save_digest(G)==(original if store.fail_restore else "absent"),"recovery preserves authoritative Garden")
 store.phase=""
 store.fail_restore=false

func run() -> void:
 check(not Gate.PRODUCTION_CUTOVER_APPROVED and not Gate.default_route(self),"normal startup remains inactive")
 set_meta(Gate.VALIDATION_ROUTE,true)
 check(Gate.default_route(self),"validation routes through normal title selection")
 var legacy := Garden.new()
 legacy.knowledge=23
 check(legacy.save_garden()==OK,"disposable legacy Garden")
 var profile := Profile.new()
 profile.data.name = "Legacy traveller"
 check(profile.save_profile()==OK,"disposable legacy profile")
 var legacy_hash := Slots._save_digest(legacy.path)
 var menu := launch_title()
 check(menu.production_route and menu.guarded_persistence and not FileAccess.file_exists(G),"title selects guarded passive route with no automatic import")
 menu.review_legacy_import()
 var prompt := menu.get_children().filter(func(child):return child is ConfirmationDialog and child.title=="Import older saves")[0] as ConfirmationDialog
 prompt.confirmed.emit()
 check(menu.garden_summary(0).knowledge==23 and menu.character_summary(0).name=="Legacy traveller" and Slots._save_digest(legacy.path)==legacy_hash,"explicit import preserves original")
 menu.select_character(1)
 menu.request_create_character()
 menu.create_character("Scout",1,[])
 menu.request_create_character()
 menu.create_character("Scout edited",2,[])
 check(menu.character_summary(1).name=="Scout edited","roster create and edit")
 roster_faults(menu)
 menu.select_character(1)
 menu.request_create_character()
 menu.create_character("Second Scout",1,[])
 menu.request_delete_character()
 menu.character_deletion.confirmed.emit()
 check(menu.character_summary(1).state=="empty" and not menu.character_deletion.visible,"roster deletion verified")
 menu.select_character(0)
 menu.select_slot(0)
 menu.continue_game()
 var world := current_scene
 check(world!=menu and SessionCase.has_guarded_session(world) and world.progress.knowledge==23,"default Continue has guarded lease and loaded bytes")
 if world==menu: quit(1); return
 check(world.progress.save_garden()==ERR_UNAUTHORIZED and world.local_character.save_profile()==ERR_UNAUTHORIZED,"standalone writes refuse outside session transaction")
 var before := Slots._save_digest(G)
 world.progress.knowledge+=3
 check(world.save_session_garden() and Slots._save_digest(G)!=before,"standalone gameplay save uses guarded transaction")
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,_path):return ERR_CANT_CREATE if phase=="publish_receipt" else OK)
 world.progress.knowledge+=4
 world.return_to_main_menu()
 await process_frame
 menu=current_scene
 check(menu.production_route and root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer and menu.garden_summary(0).state=="pending_recovery","cleanup-pending remains blocked at default title")
 var committed := Slots._save_digest(G)
 var evidence := Slots._save_digest(G+".transaction")
 check(Batch.recover(G)==ERR_BUSY and Slots._save_digest(G+".transaction")==evidence,"legacy recovery cannot touch guarded evidence")
 check(Batch.write(G,"unsafe".to_utf8_buffer())==ERR_BUSY and Slots._save_digest(G)==committed,"legacy serializer cannot overwrite guarded evidence")
 menu.review_recovery(G)
 check(not menu.recovery_confirmation.get_ok_button().disabled and Slots._save_digest(G+".transaction")==evidence,"review is read only")
 menu.recovery_confirmation.confirmed.emit()
 check(menu.notice.text.contains("cleanup completed") and Slots._save_digest(G)==committed and not FileAccess.file_exists(G+".transaction"),"confirmed cleanup retains committed bytes")
 check(not menu.recovery_notice.visible,"verified recovery clears the affected title warning")
 record("committed_cleanup",{"notice":menu.notice.text,"original_journal":evidence})

 check(Ops.Authorization.bootstrap(PackedStringArray([Other.get_base_dir()])).error==OK,"recovery directory")
 var proof := journal(Other,[Other])
 var proof_hash := Slots._save_digest(proof)
 menu.select_slot(2)
 check(menu.new_button.disabled and menu.continue_button.disabled and not menu.join_button.disabled,"missing Garden evidence blocks Continue and New only")
 menu.review_recovery(Other)
 var competing := journal(G,[Other])
 menu.recovery_confirmation.confirmed.emit()
 check(Slots._save_digest(proof)==proof_hash and FileAccess.file_exists(competing) and menu.recovery_confirmation.visible,"changed recovery plan refused")
 menu.recovery_confirmation.hide()
 menu.review_recovery(Other)
 check(menu.recovery_confirmation.get_ok_button().disabled,"ambiguous journal has no recovery action")
 menu.recovery_confirmation.hide()
 check(DirAccess.remove_absolute(competing)==OK,"remove only fixture overlap")
 menu.review_recovery(Other)
 var marker := ConfigFile.new()
 marker.set_value("session","process_id",OS.get_process_id())
 marker.set_value("session","updated",Time.get_unix_time_from_system())
 var marker_path := Other.get_base_dir().path_join("session.cfg")
 check(marker.save(marker_path)==OK,"lease race")
 menu.recovery_confirmation.confirmed.emit()
 check(Slots._save_digest(proof)==proof_hash and FileAccess.file_exists(marker_path),"review refuses lease changes")
 menu.recovery_confirmation.hide()
 check(DirAccess.remove_absolute(marker_path)==OK,"remove fixture lease")
 menu.review_recovery(Other)
 menu.recovery_confirmation.confirmed.emit()
 check(menu.notice.text=="Original saves restored." and menu.garden_summary(2).state=="empty","verified absent original is restored without claiming deletion")
 record("restored_abort",{"notice":menu.notice.text,"evidence":proof_hash})

 menu.select_slot(0)
 title_faults(menu)
 menu.new_game()
 menu.confirmation.confirmed.emit()
 world=current_scene
 check(world!=menu and world.progress.knowledge==0,"confirmed occupied Garden replacement")
 if world==menu: quit(1); return
 world.return_to_main_menu()
 await process_frame
 menu=current_scene
 garden_f5_faults(menu)
 check(menu.garden_summary(0).state=="empty" and menu.character_summary(0).exists,"Garden delete leaves roster")
 menu.new_game()
 world=current_scene
 check(world!=menu and SessionCase.has_guarded_session(world),"fresh Garden from default title")
 if world==menu: quit(1); return
 world.return_to_main_menu()
 await process_frame
 menu=current_scene
 menu.app_settings.values.developer_mode=true
 check(Developer.open_garden(menu,false)==OK,"default Developer Garden")
 world=current_scene
 world.progress.knowledge=31
 world.return_to_main_menu()
 await process_frame
 menu=current_scene
 menu.app_settings.values.developer_mode=true
 check(Developer.open_garden(menu,true,Developer.reset_snapshot(menu))==OK,"guarded Developer Garden reset")
 world=current_scene
 check(world!=menu and world.progress.knowledge==0 and SessionCase.has_guarded_session(world),"Developer reset preserves guarded session")
 if world==menu: quit(1); return
 world.app_settings.values.developer_mode=true
 var dev_before := Slots._save_digest(world.progress.path)
 var dev_profile := Slots._save_digest(world.local_character.path)
 var dev_stock: Array = world.progress.stock.duplicate()
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,_path): return ERR_CANT_CREATE if phase=="stage" else OK)
 var refusal := Developer.grant_resources(world)
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(refusal.begins_with("Save cancelled") and world.progress.knowledge==0 and world.progress.stock==dev_stock
  and Slots._save_digest(world.progress.path)==dev_before,"Developer grant abort restores resources")
 var grant := Developer.grant_resources(world)
 check(grant.begins_with("Added") and world.progress.knowledge==100
  and Slots._save_digest(world.progress.path)!=dev_before and Slots._save_digest(world.local_character.path)==dev_profile,
  "Developer grant commits Garden only")
 world.players[1].pos=world.Stage.HEART
 world.garden_action(1,"research")
 check(world.progress.heart.active=="flowering","Developer Garden has actual active research")
 var research_before := Slots._save_digest(world.progress.path)
 var research: Dictionary = world.progress.heart.serialize()
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,_path): return ERR_CANT_CREATE if phase=="stage" else OK)
 var finish_abort := Developer.finish_research(world)
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(finish_abort.begins_with("Save cancelled") and world.progress.heart.serialize()==research
  and Slots._save_digest(world.progress.path)==research_before,"Developer finish research abort restores its state")
 Developer.finish_research(world)
 check(world.progress.flowering_unlocked and Slots._save_digest(world.progress.path)!=research_before,
  "Developer finish research commits the unlock")
 record("developer_grant_and_research",{"grant":grant,"grant_abort":refusal,"research_abort":finish_abort,
  "garden_before":dev_before,"profile":dev_profile})
 world.return_to_main_menu()
 await process_frame
 await selected_technology_effects()
 menu=current_scene
 menu.app_settings.values.developer_mode=true
 if Developer.open_garden(menu,false)!=OK:
  quit(1);return
 world=current_scene
 var developer_path: String=world.progress.path
 var prior := Slots._save_digest(developer_path)
 world.progress.knowledge=8
 world.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 check(Slots._save_digest(developer_path)!=prior and root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer and not FileAccess.file_exists(developer_path.get_base_dir().path_join("session.cfg")),"window close commits guarded Garden and releases lease")
 record("title_lifecycle",{"developer":Slots._save_digest(developer_path),"legacy_preserved":Slots._save_digest(legacy.path)==legacy_hash})
 if not failed: print("PASS: production route title, roster, Garden, recovery and lifecycle")
 quit(1 if failed else 0)

func selected_technology_effects() -> void:
 var journal = preload("res://diagnostic_journal.gd")
 var growth_service = preload("res://garden_growth_service.gd")
 for expected in ["ABORTED_RESTORED","UNCERTAIN","COMMITTED_CLEANUP_PENDING"]:
  var menu: Node=current_scene
  menu.app_settings.values.developer_mode=true
  menu.settings_dialog.begin(menu.app_settings)
  menu.settings_dialog.developer_controls.open_garden()
  var game: Node=current_scene
  if game==menu or not SessionCase.has_guarded_session(game):
   check(false,"Developer Settings opens a guarded world")
   return
  check(game.persistence_session.owns_leases(),"Developer Garden and profile leases owned")
  game.set_process(false)
  game.set_physics_process(false)
  game.app_settings.values.garden_cinematics=true
  game.app_settings.values.ambient_motion=true
  var scene: Node=game.get_node("GardenInteractions/GrowthScenes")
  scene.set_process(false)
  scene.force_playback=true
  for old_reveal in growth_service.projection(game,1).get("pending",[]):
   game.send_garden_action("growth_ack:"+str(old_reveal.sequence))
  check(growth_service.projection(game,1).get("pending",[]).is_empty(),"only the selected reveal is under test")
  var settings: Window=game.settings_dialog
  settings.begin(game.app_settings)
  var controls: Node=settings.developer_controls
  for i in controls.tech_picker.item_count:
   if controls.tech_picker.get_item_metadata(i)=="irrigation":
    controls.tech_picker.select(i)
    break
  check(controls.tech_picker.get_selected_metadata()=="irrigation" and not controls.unlock_button.disabled,"actual selected-technology action enabled")
  var garden_path: String=game.progress.path
  var profile_path: String=game.local_character.path
  var garden_before := Slots._save_digest(garden_path)
  var profile_before := Slots._save_digest(profile_path)
  var heart: Dictionary=game.progress.heart.serialize().duplicate(true)
  var rng: int=game.rng.state
  var staged := {"count":0}
  var sequence_before: int=journal.current.sequence
  game.set_meta(&"guarded_gameplay_test_fault",func(phase,_path):
   if phase=="stage":
    staged.count+=1
    if expected=="ABORTED_RESTORED": return ERR_FILE_CANT_WRITE
   if expected=="UNCERTAIN" and phase in ["publish_commit_marker","restore"]: return ERR_CANT_CREATE
   if expected=="COMMITTED_CLEANUP_PENDING" and phase=="publish_receipt": return ERR_CANT_CREATE
   return OK)
  controls.unlock_button.pressed.emit()
  scene._process(0)
  var pending: Array=growth_service.projection(game,1).get("pending",[])
  var notice: String = game.persistence_session.pending_notice()
  var cleanup: bool = expected=="COMMITTED_CLEANUP_PENDING"
  var abort: bool = expected=="ABORTED_RESTORED"
  var garden_after := Slots._save_digest(garden_path)
  var primary := Slots._save_digest(garden_path+".transaction")
  var result := {}
  var log: String=FileAccess.get_file_as_string(journal.current.file.get_path())
  for line in log.split("\n",false):
   var entry: Variant=JSON.parse_string(line)
   if entry is Dictionary and entry.seq>sequence_before and entry.event=="guarded_gameplay_result":
    result=entry.data
  check(result.get("outcome")==expected and staged.count==1 and game.rng.state==rng
   and Slots._save_digest(profile_path)==profile_before,"Developer exact finalization and Garden-only scope")
  check(settings.visible==not cleanup and scene.event.is_empty() and not game.ui.cinematic_active(),
   "Developer settings and cinematic respect "+expected)
  if abort:
   check(game.progress.heart.serialize()==heart and garden_after==garden_before and primary=="absent"
    and pending.is_empty() and settings.notice.text.begins_with("Save cancelled"),"aborted unlock leaves no growth receipt")
  else:
   check(game.progress.heart.has("irrigation") and pending.size()==1 and garden_after!=garden_before and primary!="absent"
    and not game.persistence_session.can_write() and (notice==Tx.CLEANUP_NOTICE if cleanup else notice.contains("uncertain")),
    "blocked Developer action retains committed or tentative Garden with one selected reveal")
   controls.unlock_button.pressed.emit()
   scene._process(0)
   check(staged.count==1 and game.rng.state==rng and Slots._save_digest(garden_path)==garden_after and scene.event.is_empty(),
    "blocked Developer unlock cannot replay or present its growth scene")
  game.remove_meta(&"guarded_gameplay_test_fault")
  record("developer_selected_tech_"+expected.to_lower(),{"garden_before":garden_before,"garden_after":garden_after,
   "profile":profile_before,"journal":primary,"outcome":result,"rng":str(rng),"warning":notice,
   "settings_visible":settings.visible,"pending_growth":pending})
  if not abort and not cleanup:
   check(settings.notice.text.contains(notice),"Developer dialog retains the uncertainty warning")
  if settings.visible: settings.cancel()
  game.return_to_main_menu()
  await process_frame
  if abort: continue
  menu=current_scene
  menu.review_developer_recovery()
  menu.recovery_confirmation.confirmed.emit()
  check(Slots._save_digest(garden_path)==(garden_after if cleanup else garden_before)
   and Slots._save_digest(garden_path+".transaction")=="absent","Developer review selects authoritative version")
  if not cleanup: continue
  menu.app_settings.values.developer_mode=true
  check(Developer.open_garden(menu,false)==OK,"reopen Developer Garden after verified cleanup")
  game=current_scene
  scene=game.get_node("GardenInteractions/GrowthScenes")
  scene.set_process(false)
  scene.force_playback=true
  scene._process(0)
  check(not scene.event.is_empty() and pending.size()==1 and scene.event.sequence==pending[0].sequence,
   "verified cleanup allows the single original growth reveal")
  scene.finish(true)
  scene._process(0)
  var seen: Dictionary=growth_service.projection(game,1)
  check(scene.event.is_empty() and seen.pending.is_empty() and pending.size()==1 and seen.seen==pending[0].sequence
   and game.progress.heart.has("irrigation"),"growth receipt commits once without replaying the unlock")
  record("developer_selected_tech_recovered",{"seen":seen.seen,"pending":seen.pending,"garden":Slots._save_digest(garden_path)})
  game.return_to_main_menu()
  await process_frame
