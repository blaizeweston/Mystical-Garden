extends SceneTree

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
 menu.request_delete_character()
 menu.character_deletion.confirmed.emit()
 check(menu.character_summary(1).state=="empty" and not menu.character_deletion.visible,"roster deletion verified")
 menu.select_character(0)
 menu.select_slot(0)
 menu.continue_game()
 var world := current_scene
 check(world!=menu and world.has_meta(Tx.SESSION) and world.progress.knowledge==23,"default Continue has guarded lease and loaded bytes")
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
 menu.new_game()
 menu.confirmation.confirmed.emit()
 world=current_scene
 check(world!=menu and world.progress.knowledge==0,"confirmed occupied Garden replacement")
 if world==menu: quit(1); return
 world.return_to_main_menu()
 await process_frame
 menu=current_scene
 menu.request_delete_save()
 menu.deletion_confirmation.confirmed.emit()
 check(menu.garden_summary(0).state=="empty" and menu.character_summary(0).exists,"Garden delete leaves roster")
 menu.new_game()
 world=current_scene
 check(world!=menu and world.has_meta(Tx.SESSION),"fresh Garden from default title")
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
 check(world!=menu and world.progress.knowledge==0 and world.has_meta(Tx.SESSION),"Developer reset preserves guarded session")
 if world==menu: quit(1); return
 var developer_path: String=world.progress.path
 var prior := Slots._save_digest(developer_path)
 world.progress.knowledge=8
 world.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 check(Slots._save_digest(developer_path)!=prior and root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer and not FileAccess.file_exists(developer_path.get_base_dir().path_join("session.cfg")),"window close commits guarded Garden and releases lease")
 record("title_lifecycle",{"developer":Slots._save_digest(developer_path),"legacy_preserved":Slots._save_digest(legacy.path)==legacy_hash})
 if not failed: print("PASS: production route title, roster, Garden, recovery and lifecycle")
 quit(1 if failed else 0)
