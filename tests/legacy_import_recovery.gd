extends SceneTree

const Gate = preload("res://persistence_writer_integration.gd")
const Ops = preload("res://persistence_operations.gd")
const Slots = preload("res://save_slots.gd")
const Batch = preload("res://save_batch.gd")
const Developer = preload("res://developer_mode.gd")
const G = "user://saves/slot_1/garden.cfg"
const P = "user://saves/slot_1/character.cfg"
const R = "user://saves/characters/slot_1/character.cfg"
const R2 = "user://saves/characters/slot_2/character.cfg"
const C = "user://saves/characters/catalog.cfg"
const DG = "user://saves/developer-garden/slot_1/garden.cfg"
const DP = "user://saves/developer-garden/slot_1/character.cfg"
const LG = "user://garden.cfg"
const LP = "user://character.cfg"
const ID = "1234567890abcdef1234567890abcdef"
var failed := false

func _initialize() -> void: call_deferred("run")

func check(ok: bool, what: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: ", what)

func snap(path := "user://") -> Dictionary:
 var disk := DirAccess.open(path)
 var state := {}
 if disk == null: return state
 disk.include_hidden = true
 for name in disk.get_files():
  if name == Ops.Authorization.SENTINEL: continue
  var target := path.path_join(name)
  state[target] = Slots._save_digest(target)
 for name in disk.get_directories():
  if name in ["logs", "shader_cache", "diagnostics"]: continue
  var target := path.path_join(name)
  state[target] = "directory"
  state.merge(snap(target))
 return state

func record(label: String, before: Dictionary, notice := "") -> void:
 print("CASE ", JSON.stringify({"case":label, "before":before, "after":snap(), "notice":notice}))

func raw(path: String, data: String) -> void:
 check(DirAccess.make_dir_recursive_absolute(path.get_base_dir()) == OK, "fixture parent")
 check(Batch._write_bytes(path, data.to_utf8_buffer()) == OK, "fixture bytes " + path)

func profile(identity: String, name := "Older traveller") -> String:
 return "[character]\nprogress={\"name\": \"%s\", \"xp\": [42, 0, 0, 0, 0]}\n" % name + ("identity=\"%s\"\n" % identity if not identity.is_empty() else "")

func journal(anchor: String, paths: Array) -> void:
 var file := ConfigFile.new()
 var entries := {}
 for path in paths:
  var exists := FileAccess.file_exists(path)
  entries[path] = {"exists":exists, "bytes":FileAccess.get_file_as_bytes(path) if exists else PackedByteArray()}
 file.set_value("transaction","entries",entries)
 file.set_value("transaction","committed",false)
 raw(anchor + ".transaction", file.encode_to_text())

func title() -> Node:
 var menu: Node = load("res://main_menu.tscn").instantiate()
 root.add_child(menu)
 current_scene = menu
 check(menu.production_route, "actual candidate title")
 return menu

func run() -> void:
 set_meta(Gate.VALIDATION_ROUTE,true)
 var menu := title()
 match OS.get_environment("MYSTICAL_F2_MODE"):
  "interrupt": interrupted(menu)
  "restart": restarted(menu)
  "garden_only": garden_only(menu)
  _: await exercise(menu)
 if not failed: print("PASS: explicit import transaction and actual recovery owner selection")
 quit(1 if failed else 0)

func exercise(menu: Node) -> void:
 raw(LG, "[garden]\nknowledge=27\n")
 raw(LP, profile(""))
 var before := snap()
 menu.import_legacy_saves()
 check(snap() == before and menu.notice.text.contains("no verifiable identity"), "identity-less profile refuses before destination mutation")
 record("identityless_refusal",before,menu.notice.text)
 raw(LP,profile(ID))
 raw(R,profile(ID,"Different character"))
 before = snap()
 menu.import_legacy_saves()
 check(snap() == before and menu.notice.text.contains("already uses this identity"), "identity collision refuses")
 record("identity_collision",before,menu.notice.text)
 check(DirAccess.remove_absolute(R)==OK,"remove only fixture collision")
 raw(C,"[roster]\ncapacity=128\n")
 for slot in 128:
  raw(menu.characters._slot_profile(slot), profile(("full-roster-slot-" + str(slot)).md5_text()))
 before = snap()
 menu.import_legacy_saves()
 check(snap() == before and menu.notice.text.contains("roster is full"),"capacity refused before import")
 record("full_roster",before,menu.notice.text)
 for slot in 128:
  check(DirAccess.remove_absolute(menu.characters._slot_profile(slot)) == OK,"remove fixture roster profile")
 check(DirAccess.remove_absolute(C)==OK,"remove fixture catalog")
 var conflict := P + ".pre-content-v2.bak"
 raw(conflict,"Unverified historical backup")
 before=snap()
 menu.import_legacy_saves()
 check(snap()==before and not FileAccess.file_exists(G),"conflicting backup refuses before any copy")
 record("backup_conflict",before,menu.notice.text)
 check(DirAccess.remove_absolute(conflict)==OK,"remove fixture conflict")
 # An interrupted pre-F2 operation left exact legacy copies but no catalog.
 raw(G,FileAccess.get_file_as_string(LG))
 raw(P,FileAccess.get_file_as_string(LP))
 before=snap()
 menu.set_meta(&"legacy_import_test_fault",func(phase,_path): return ERR_CANT_CREATE if phase=="publish_receipt" else OK)
 menu.import_legacy_saves()
 check(menu.notice.text.contains("cleanup") and FileAccess.file_exists(R) and FileAccess.file_exists(C),"cleanup pending keeps all committed data")
 check(Slots._save_digest(LG)==before[LG] and Slots._save_digest(LP)==before[LP] and not FileAccess.file_exists(conflict),"immutable originals replace the need for a backup of a fresh destination")
 record("committed_cleanup_pending",before,menu.notice.text)
 before=snap()
 menu.import_legacy_saves()
 check(snap()==before and menu.notice.text.contains("pending") and menu.recovery_notice.visible,"cleanup pending blocks repeated import and keeps warning")
 record("blocked_retry",before,menu.notice.text)
 menu.review_legacy_recovery()
 check(menu.reviewed_recovery.journal_anchors==PackedStringArray([R]),"older-save recovery routes to actual import anchor")
 menu.recovery_confirmation.confirmed.emit()
 check(menu.notice.text.contains("cleanup completed") and not menu.recovery_notice.visible,"cleanup through actual title clears verified warning")
 before=snap()
 menu.import_legacy_saves()
 check(snap()==before and menu.notice.text.contains("needed importing") and menu.character_summary(0).identity==ID,"repeat keeps stable profile without a duplicate")
 record("reconciled_repeat",before,menu.notice.text)

 check(Ops.Authorization.bootstrap(PackedStringArray([R2.get_base_dir(),DP.get_base_dir()])).error==OK,"recovery fixture directories")
 journal(R,[R,C])
 journal(DP,[DP])
 before=snap()
 check(menu.character_summary(1).state=="pending_recovery","shared catalog blocks other slot")
 menu.select_character(1)
 menu.character_recovery_button.pressed.emit()
 check(menu.reviewed_recovery.journal_anchors==PackedStringArray([R]) and not menu.reviewed_recovery.participants.has(R2),"review shows actual catalog owner")
 check(menu.recovery_confirmation.dialog_text.contains(R) and not menu.recovery_confirmation.dialog_text.contains(R2),"dialog names owner and linked members only")
 check(snap()==before,"review read only")
 var scratch := R.get_base_dir().path_join("session.cfg.tmp")
 raw(scratch,"Unresolved session publication")
 before=snap()
 menu.recovery_confirmation.confirmed.emit()
 check(snap()==before and menu.recovery_confirmation.get_ok_button().disabled,"scratch appearing after review refuses")
 record("review_scratch_drift",before,menu.notice.text)
 check(DirAccess.remove_absolute(scratch)==OK,"remove only fixture scratch")
 menu.review_recovery(R2)
 var marker := R.get_base_dir().path_join("session.cfg")
 raw(marker,"[session]\nprocess_id=%d\nupdated=%.4f\n" % [OS.get_process_id(),Time.get_unix_time_from_system()])
 before=snap()
 menu.recovery_confirmation.confirmed.emit()
 check(snap()==before and menu.recovery_confirmation.get_ok_button().disabled,"lease appearing after review refuses")
 record("review_lease_drift",before,menu.notice.text)
 check(DirAccess.remove_absolute(marker)==OK,"remove only fixture lease")
 menu.review_recovery(R2)
 menu.recovery_confirmation.confirmed.emit()
 check(not FileAccess.file_exists(R + ".transaction") and FileAccess.file_exists(DP + ".transaction"),"catalog recovery affects selected owner only")
 menu.app_settings.values.developer_mode=true
 check(Developer.open_garden(menu,false)==ERR_BUSY,"Developer cannot open with profile-only evidence")
 menu.settings_dialog.begin(menu.app_settings)
 var controls: Node = menu.settings_dialog.developer_controls
 var button: Button = null
 for child in controls.tools.get_children():
  if child is Button and child.text.begins_with("Review Developer"): button = child
 check(button != null,"actual Developer Settings review button")
 if button == null: return
 before=snap()
 button.pressed.emit()
 check(menu.reviewed_recovery.journal_anchors==PackedStringArray([DP]) and snap()==before,"Developer Settings reviews profile-only owner read only")
 journal(DG,[DG])
 before=snap()
 menu.review_developer_recovery()
 check(menu.recovery_owner_picker.visible and menu.recovery_owner_picker.item_count==2,"independent Developer owners are selectable")
 menu.recovery_owner_picker.select(1)
 menu.recovery_owner_picker.item_selected.emit(1)
 check(snap()==before and menu.reviewed_recovery.journal_anchors==PackedStringArray([DG]),"choosing Garden journal remains read-only")
 menu.recovery_confirmation.confirmed.emit()
 check(FileAccess.file_exists(DP+".transaction") and not FileAccess.file_exists(DG+".transaction"),"Garden review recovers its owner only")
 menu.review_developer_recovery()
 before=snap()
 record("developer_owner_selection",before)
 record("developer_profile_review",before)
 menu.recovery_confirmation.confirmed.emit()
 check(not FileAccess.file_exists(DP + ".transaction") and not FileAccess.file_exists(DG),"Developer recovery only restores recorded absence")
 check(DirAccess.remove_absolute(LG)==OK and DirAccess.remove_absolute(LP)==OK,"remove only fixture legacy inputs")
 var guest := "user://character-local-guest.cfg"
 var guest_id := "fedcba0987654321fedcba0987654321"
 raw(guest, profile(guest_id))
 before=snap()
 menu.set_meta(&"legacy_import_test_fault",func(phase,_path):
  return ERR_CANT_CREATE if phase=="replace" and _path==R2 or phase=="restore" else OK)
 menu.import_legacy_saves()
 check(menu.notice.text.contains("needs recovery") and menu.recovery_notice.visible and FileAccess.file_exists(R2+".transaction"),"uncertain import retains evidence and warning")
 record("uncertain_import",before,menu.notice.text)
 before=snap()
 menu.import_legacy_saves()
 check(snap()==before and menu.recovery_notice.visible,"uncertainty blocks repeat")
 menu.remove_meta(&"legacy_import_test_fault")
 menu.review_legacy_recovery()
 menu.recovery_confirmation.confirmed.emit()
 check(not FileAccess.file_exists(R2) and not FileAccess.file_exists(R2+".transaction") and not menu.recovery_notice.visible,"uncertain import restored through selected owner")
 menu.import_legacy_saves()
 check(menu.character_summary(1).identity==guest_id and Slots._save_digest(guest)==before[guest],"guest retry preserves source identity and bytes")
 record("uncertain_import_recovered",before,menu.notice.text)
 await process_frame

func garden_only(menu: Node) -> void:
 raw(LG,"[garden]\nknowledge=27\n")
 var original := Slots._save_digest(LG)
 menu.import_legacy_saves()
 check(menu.notice.text=="Older saves imported." and Slots._save_digest(G)==original and FileAccess.file_exists(C),"Garden-only import records completion")
 raw(G,"[garden]\nknowledge=71\n")
 var before := snap()
 menu.import_legacy_saves()
 check(snap()==before and menu.notice.text.contains("needed importing"),"Garden-only retry preserves progress")
 record("garden_only_retry",before,menu.notice.text)

func interrupted(menu: Node) -> void:
 raw(LG,"[garden]\nknowledge=27\n")
 raw(LP,profile(ID))
 var before := snap()
 menu.set_meta(&"legacy_import_test_fault",func(phase,_path):
  if phase=="replace" and _path==R:
   record("before_termination",before)
   while true: OS.delay_msec(100)
  return OK)
 menu.import_legacy_saves()
 check(false,"owner must stop inside transaction")

func restarted(menu: Node) -> void:
 var before := snap()
 menu.import_legacy_saves()
 check(snap()==before and menu.notice.text.contains("pending"),"restart blocks import until recovery")
 record("restart_refusal",before,menu.notice.text)
 menu.review_legacy_recovery()
 check(not menu.recovery_confirmation.get_ok_button().disabled,"interrupted transaction review")
 menu.recovery_confirmation.confirmed.emit()
 check(not FileAccess.file_exists(G) and not FileAccess.file_exists(P) and not FileAccess.file_exists(R) and not FileAccess.file_exists(C),"verified restore of absent destinations")
 check(Slots._save_digest(LG)==before[LG] and Slots._save_digest(LP)==before[LP],"restart preserved originals")
 menu.import_legacy_saves()
 check(FileAccess.file_exists(G) and FileAccess.file_exists(P) and FileAccess.file_exists(R) and FileAccess.file_exists(C) and menu.character_summary(0).identity==ID,"retry imports every destination coherently")
 record("restart_recovery_and_import",before,menu.notice.text)
