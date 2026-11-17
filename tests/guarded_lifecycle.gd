extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const Tx=preload("res://game_transaction.gd")
const Batch=preload("res://save_batch.gd")
const Slots=preload("res://save_slots.gd")
const Owner=preload("res://guarded_title_session.gd")
const Ops=preload("res://persistence_operations.gd")
const Plan=preload("res://persistence_recovery_plan.gd")
const Preferences=preload("res://app_settings.gd")
const Network=preload("res://network_settings.gd")
const Metrics=preload("res://game_metrics.gd")
const G="user://saves/slot_1/garden.cfg"
const C="user://saves/characters/slot_1/character.cfg"
const Settings="user://settings.cfg"
var failed:=false

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failed=true
  printerr("FAIL: ",message)

func disk() -> Dictionary:
 var result:={}
 for p in [G,C]:
  for suffix in ["",".pre-content-v2.bak"]+Plan.ARTIFACTS: result[p+suffix]=Slots._save_digest(p+suffix)
  result[p.get_base_dir().path_join("session.cfg")]=Slots._save_digest(p.get_base_dir().path_join("session.cfg"))
 for p in [Settings,"user://saves/network.cfg"]: result[p]=Slots._save_digest(p)
 return result

func record(key: String,before: Dictionary,facts: Dictionary) -> void:
 print("CASE ",JSON.stringify({"case":key,"run_id":OS.get_environment("MYSTICAL_VALIDATION_RUN"),"before":before,"after":disk(),"facts":facts}))

func title() -> Node:
 var menu=load("res://main_menu.tscn").instantiate()
 menu.guarded_persistence=true
 menu.restore_last_character=false
 menu.restore_last_selection=false
 menu.import_legacy=false
 root.add_child(menu)
 current_scene=menu
 return menu

func launch(menu: Node) -> Node:
 menu.select_slot(0)
 menu.continue_game()
 check(current_scene!=menu and current_scene.has_meta(Tx.SESSION),"real guarded Continue")
 return current_scene if current_scene!=menu else null

func preferences(world: Node) -> void:
 var model:=Preferences.new()
 var old:=ConfigFile.new()
 old.set_value("settings","values",{"master":.27,"bindings":{"attack":[{"kind":"key","code":int(KEY_B)}]}})
 check(old.save(Settings)==OK and model.load_settings()==OK and model.values.master==.27 and model.values.bindings.core_skill[0].code==KEY_X,"existing settings format and migrated binding")
 var before:=disk()
 var draft:=model.values.duplicate(true)
 draft.master=.31
 Batch.begin(G)
 check(model.save_settings(draft)==OK and Network.save_settings("user://saves","127.0.0.1",28115)==OK,
  "both preferences write inside legacy transaction")
 check(Batch.staged.is_empty() and Batch.failure==OK,"legacy batch excludes preferences")
 Batch.cancel()
 check(disk()[G]==before[G] and disk()[C]==before[C] and disk()[Settings]!=before[Settings],"legacy cancellation does not undo independent preference")
 draft.master=.41
 var result:=Tx.run_gameplay(world,Tx.Scope.PAIR,func():
  check(model.save_settings(draft)==OK and Network.save_settings("user://saves","127.0.0.2",28116)==OK,"preferences write inside guarded transaction")
  var bad:=Preferences.new()
  bad.path=G
  check(bad.save_settings(draft)==ERR_INVALID_PARAMETER,"preference cannot write a Garden path")
  bad.path="user://missing/settings.cfg"
  check(bad.save_settings(draft)!=OK and bad.values.master==.5,"auxiliary IO failure leaves previous applied values")
  var old_path:=Metrics.path
  Metrics.path="user://missing/metrics.jsonl"
  Metrics.record("auxiliary_failure_fixture")
  Metrics.path=old_path
  world.progress.knowledge+=3
  return false)
 check(result.completed and result.value==false and model.values.master==.41 and disk()[G]!=before[G]
  and Network.load_settings("user://saves").address=="127.0.0.2","auxiliary failures cannot poison canonical verdict")
 record("preferences",before,{"outcome":result.persistence.value.outcome.outcome,"master":model.values.master,"business":result.value})
 check(Network.save_settings("user://saves","127.0.0.1",28117,false)==OK,"standalone network setting")

func run() -> void:
 var menu:=title()
 check(Owner.completed(Owner.outcome(menu.storage.new_world_guarded(0))),"create disposable Garden")
 check(Owner.completed(Owner.outcome(menu.characters.create_guarded(0,"Keeper",0,[]))),"create disposable profile")
 menu.select_character(0)
 menu.select_slot(0)
 var world:=launch(menu)
 if world==null: quit(1);return
 await process_frame
 preferences(world)
 var before:=disk()
 world.progress.needs_content_backup=true
 world.local_character.needs_content_backup=true
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,path):return ERR_FILE_CANT_WRITE if phase=="stage" and path==C+".txn_stage" else OK)
 var failed_save:=Tx.run_gameplay(world,Tx.Scope.PAIR,func():world.progress.knowledge+=1;return true)
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(not failed_save.completed and world.progress.needs_content_backup and world.local_character.needs_content_backup and disk()[G]==before[G] and disk()[C]==before[C],"verified abort restores bytes and migration flags")
 check(Tx.run_gameplay(world,Tx.Scope.PAIR,func():world.progress.knowledge+=1).completed,"migration retry")
 check(not world.progress.needs_content_backup and not world.local_character.needs_content_backup and disk()[G+".pre-content-v2.bak"]==before[G]
  and disk()[C+".pre-content-v2.bak"]==before[C],"migration copies retain originals")
 record("migration_abort_retry",before,{"first_outcome":failed_save.persistence.value.outcome.outcome})
 before=disk()
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,_path):return ERR_CANT_CREATE if phase=="publish_receipt" else OK)
 world.progress.knowledge+=2
 world.return_to_main_menu()
 menu=current_scene
 check(menu!=world and menu.has_meta(&"guarded_return_notice") and menu.get_meta(&"guarded_return_notice")==Tx.CLEANUP_NOTICE
  and menu.garden_summary(0).state=="pending_recovery" and root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"cleanup-pending exit shows warning and blocks Continue")
 var retained:=disk()
 menu.continue_game()
 check(current_scene==menu and disk()==retained,"passive title refuses cleanup-pending")
 record("cleanup_pending_title",before,{"warning":menu.get_meta(&"guarded_return_notice"),"offline":true})
 await process_frame
 check(not FileAccess.file_exists(G.get_base_dir().path_join("session.cfg")) and not FileAccess.file_exists(C.get_base_dir().path_join("session.cfg")),
  "terminal owner can release its markers without changing pending recovery")
 check(Ops.recover(PackedStringArray([G])).value.verified,"explicit cleanup recovery")
 world=launch(menu)
 if world==null: quit(1);return
 check(not world.progress.needs_content_backup and not world.local_character.needs_content_backup,"guarded reload derives migration flags from committed format")
 world.character_dirty=true
 world.players[1].character.name="Tentative title"
 before=disk()
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,path):
  if phase=="replace" and path==G:return ERR_CANT_CREATE
  return ERR_FILE_CANT_WRITE if phase=="restore" else OK)
 world.return_to_main_menu()
 check(current_scene==world and Tx.pending_notice(world).contains("uncertain") and disk()[C]!=before[C] and disk()[G]==before[G],"uncertain first exit retains runtime and evidence")
 world.return_to_main_menu()
 menu=current_scene
 check(menu!=world and str(menu.get_meta(&"guarded_return_notice","")).contains("uncertain") and menu.garden_summary(0).state=="pending_recovery","uncertain title retry does not replay")
 record("uncertain_title",before,{"notice":menu.get_meta(&"guarded_return_notice",""),"offline":root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer})
 await process_frame
 check(not FileAccess.file_exists(G.get_base_dir().path_join("session.cfg")) and not FileAccess.file_exists(C.get_base_dir().path_join("session.cfg")),
  "uncertain title transition releases owned markers but keeps journals")
 check(Ops.recover(PackedStringArray([C])).value.verified,"verified B2 restoration")
 world=launch(menu)
 if world==null: quit(1);return
 world.players[1].pos=world.Stage.GATE
 ExpeditionCase.Transitions.enter(world, 1,world.players[1])
 world.players[1].safe_items=[{"item":"unidentified_seed","quantity":1,"seeds":[0]}]
 before=disk()
 world.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 check(not world.participation.active() and disk()[G]!=before[G] and disk()[G.get_base_dir().path_join("session.cfg")]=="absent"
  and disk()[C.get_base_dir().path_join("session.cfg")]=="absent" and root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"window close settles pouch, detaches and releases both leases")
 record("window_close",before,{"offline":true,"wild":world.participation.active()})
 if not failed:print("PASS: guarded lifecycle, preference isolation and title recovery")
 quit(1 if failed else 0)
