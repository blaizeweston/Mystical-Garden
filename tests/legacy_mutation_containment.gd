extends SceneTree

const Batch = preload("res://save_batch.gd")
const Ops = preload("res://persistence_operations.gd")
const Gate = preload("res://persistence_writer_integration.gd")
const Slots = preload("res://save_slots.gd")
const Roster = preload("res://character_slots.gd")
const Profile = preload("res://character_profile.gd")
const G = "user://saves/slot_1/garden.cfg"
const C = "user://saves/characters/slot_1/character.cfg"
const C2 = "user://saves/characters/slot_2/character.cfg"
const G2 = "user://saves/slot_2/garden.cfg"
const M = "user://saves/characters/catalog.cfg"
const JOURNAL = ".transaction"
const TOKEN = "1234567890abcdef1234567890abcdef"
const SEED = "[garden]\nknowledge=19\n"
var failed := false

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: ", message)

func raw(path: String, value: String) -> void:
 check(DirAccess.make_dir_recursive_absolute(path.get_base_dir()) == OK, "fixture directory: " + path)
 check(Batch._write_bytes(path, value.to_utf8_buffer()) == OK, "fixture file: " + path)

func snapshot(path := "user://") -> Dictionary:
 var result := {}
 var directory := DirAccess.open(path)
 if directory == null: return result
 directory.include_hidden = true
 for file in directory.get_files():
  if file == Ops.Authorization.SENTINEL: continue
  result[path.path_join(file)] = FileAccess.get_sha256(path.path_join(file))
 for child in directory.get_directories():
  if child in ["logs", "diagnostics", "shader_cache"]: continue
  var folder := path.path_join(child)
  result[folder] = "directory"
  result.merge(snapshot(folder))
 return result

func unchanged(id: String, before: Dictionary, observed: Dictionary) -> void:
 var after := snapshot()
 check(after == before, id + " preserves every file, sidecar and directory")
 print("CASE ", JSON.stringify({"case":id, "before":before, "after":after, "observed":observed}))

func pending(anchor: String, entries: Dictionary, guarded := true) -> void:
 var journal := ConfigFile.new()
 journal.set_value("transaction", "committed", false)
 journal.set_value("transaction", "entries", entries)
 var data := journal.encode_to_text().to_utf8_buffer()
 if guarded: data = Batch.Evidence.journal_image(data, TOKEN)
 check(Batch._write_bytes(anchor + JOURNAL, data) == OK, "fixture journal")

func entry(path: String) -> Dictionary:
 var exists := FileAccess.file_exists(path)
 return {"exists":exists, "bytes":FileAccess.get_file_as_bytes(path) if exists else PackedByteArray()}

func clear_primary(anchor: String) -> void:
 check(DirAccess.remove_absolute(anchor + JOURNAL) == OK, "fixture remove journal")

func backend_refusal() -> void:
 var before := snapshot()
 var menu = load("res://main_menu.tscn").instantiate()
 root.add_child(menu)
 current_scene = menu
 var world := Slots.new()
 var roster := Roster.new()
 var path := "user://garden.cfg"
 check(not menu.guarded_persistence and not Ops.Authorization.replacement_available(), "ordinary title uses legacy handlers with backend unavailable")
 check(world.new_world(0) == ERR_UNAVAILABLE and world.claim(0) == ERR_UNAVAILABLE and roster.create(0, "Refused", 0, []) == ERR_UNAVAILABLE, "management refuses")
 check(Batch.write(path, SEED.to_utf8_buffer()) == ERR_UNAVAILABLE and Batch.write_bytes(path, SEED.to_utf8_buffer()) == ERR_UNAVAILABLE
  and Batch.recover(path) == ERR_UNAVAILABLE, "public writers and recovery refuse")
 unchanged("backend_refusal", before, {"backend":ClassDB.class_exists(Ops.Authorization.BACKEND), "notice":menu.notice.text})
 check(not FileAccess.file_exists("user://" + Ops.Authorization.SENTINEL), "backend refusal acquires no lock")
 finish()

func finish() -> void:
 if not failed: print("PASS: legacy mutation containment across actual title and public writers")
 quit(1 if failed else 0)

func contend(role: String) -> void:
 var ready := "user://fixture-ready"
 var released := "user://fixture-release"
 var complete := "user://fixture-complete"
 if role == "owner":
  raw(G, SEED)
  raw(C, "[character]\nidentity=\"22222222222222222222222222222222\"\n")
  var plan := Ops.Planner.discover(PackedStringArray([C]))
  var held := Ops.Authorization.run(PackedStringArray([G, C]), func(_token):
   raw(ready, "locked")
   var deadline := Time.get_ticks_msec() + 15000
   while not FileAccess.file_exists(released) and Time.get_ticks_msec() < deadline: OS.delay_msec(20)
   check(FileAccess.file_exists(released), "contender saw live native holder")
   pending(G, {G:entry(G), C:entry(C)}))
  check(held.error == OK and plan.state == "healthy", "owner acquired guarded native lock")
  raw(complete, "published")
 else:
  var deadline := Time.get_ticks_msec() + 15000
  while not FileAccess.file_exists(ready) and Time.get_ticks_msec() < deadline: OS.delay_msec(20)
  check(FileAccess.file_exists(ready), "owner ready")
  var seen := Ops.Planner.discover(PackedStringArray([C]))
  check(seen.state == "healthy", "initial passive observation predates evidence")
  var before := snapshot()
  var locked := Batch.write(C, "unsafe".to_utf8_buffer())
  check(locked == ERR_BUSY, "legacy cannot enter while native gate held")
  unchanged("cross_process_native_contention", before, {"error":locked, "initial_state":seen.state})
  raw(released, "observed")
  while not FileAccess.file_exists(complete) and Time.get_ticks_msec() < deadline: OS.delay_msec(20)
  check(FileAccess.file_exists(complete), "owner published")
  before = snapshot()
  var refused := Batch.write(C, "unsafe".to_utf8_buffer())
  check(refused == ERR_BUSY, "legacy rediscovers evidence after lock releases")
  unchanged("evidence_after_passive_observation", before, {"error":refused, "state":Ops.Planner.discover(PackedStringArray([C])).state})
 finish()

func run() -> void:
 var mode := OS.get_environment("MYSTICAL_F1_MODE")
 if mode == "backend":
  backend_refusal()
  return
 if mode in ["owner", "contender"]:
  contend(mode)
  return
 check(not Gate.PRODUCTION_CUTOVER_APPROVED and Gate.VERIFIED_WRITERS.is_empty(), "cutover remains closed")
 var menu = load("res://main_menu.tscn").instantiate()
 root.add_child(menu)
 current_scene = menu
 check(not menu.guarded_persistence, "normal legacy title")
 var world := Slots.new()
 var roster := Roster.new()
 check(world.new_world(0) == OK and roster.create(0, "Original", 0, []) == OK, "legacy creation")
 var committed := Ops._run_batch(PackedStringArray([G,C]), G, func(stage,_context):
  check(stage.call(G, SEED.to_utf8_buffer()) == OK, "stage Garden")
  check(stage.call(C, FileAccess.get_file_as_bytes(C)) == OK, "stage character"),
  false, func(phase,_path): return ERR_CANT_CREATE if phase == "publish_receipt" else OK)
 check(Ops.transaction_result(committed.value).state == "committed_cleanup_pending", "real B2 cleanup pending")
 check(DirAccess.remove_absolute(C + ".txn_link") == OK, "remove forward link")
 var before := snapshot()
 var plan := Ops.Planner.discover(PackedStringArray([C]))
 check(plan.state == "pending_recovery" and plan.participants.has(G), "reverse membership")
 var profile := Profile.new()
 profile.path = C
 profile.needs_content_backup = true
 var direct := Batch.write(C, "unsafe".to_utf8_buffer())
 var raw_write := Batch.write_bytes(C, "unsafe".to_utf8_buffer())
 var raw_sidecar := Batch.write_bytes(G + ".txn_expected", "unsafe".to_utf8_buffer())
 var standalone := profile.save_profile()
 var recovery := Batch.recover(C)
 check(Batch.begin(G) == OK and Batch.write(G, "tentative".to_utf8_buffer()) == OK and Batch.write(C, "tentative".to_utf8_buffer()) == OK, "memory-only staging")
 check(snapshot() == before, "staging performs no disk writes")
 var commit_error := Batch.commit().original_error
 check(direct == ERR_BUSY and raw_write == ERR_BUSY and raw_sidecar == ERR_UNAUTHORIZED and standalone == ERR_BUSY and recovery == ERR_BUSY and commit_error == ERR_BUSY, "public writers refuse reverse-only evidence")
 unchanged("reverse_link_refusal", before, {"direct":direct, "raw":raw_write, "sidecar":raw_sidecar, "serializer":standalone, "recovery":recovery, "commit":commit_error, "plan":plan.reason, "participants":Array(plan.participants)})
 check(world.new_world(2) == OK and world.delete_world(2, true) == OK, "unrelated healthy Garden can be created and deleted")
 var recovered := Ops.recover(PackedStringArray([C]))
 check(recovered.ran and recovered.value.verified, "B2 cleanup remains available")
 check(roster.update(0, "Edited", 0, []) == OK, "legacy roster edit after verified cleanup")

 check(world.new_world(1) == OK, "legacy second Garden")
 menu.select_slot(1)
 menu.request_delete_save()
 check(menu.pending_delete == 1, "legacy title confirmed target")
 pending(G2, {G2:entry(G2)})
 before = snapshot()
 menu.deletion_confirmation.confirmed.emit()
 check(menu.notice.text.contains("pending save recovery") and not menu.notice.text.contains("deleted."), "legacy title does not publish delete success")
 check(world.new_world(1, true) == ERR_BUSY and world.delete_save(1, true) == ERR_BUSY, "occupied replacement and paired deletion refuse")
 unchanged("title_guarded_primary_refusal", before, {"notice":menu.notice.text})
 clear_primary(G2)
 menu.select_slot(1)
 menu.request_delete_save()
 menu.deletion_confirmation.confirmed.emit()
 check(not FileAccess.file_exists(G2) and menu.notice.text.contains("deleted"), "legacy title deletion succeeds when healthy")

 pending(G, {G:entry(G), C2:entry(C2)})
 before = snapshot()
 check(not FileAccess.file_exists(C2) and roster.create(1,"Vacant",0,[]) == ERR_BUSY and roster.claim(1) == ERR_BUSY, "recorded absent profile unavailable")
 unchanged("absent_linked_participant", before, {})
 clear_primary(G)
 pending(C, {C:entry(C), M:entry(M)})
 before = snapshot()
 check(roster.set_capacity(4) == ERR_BUSY and roster.create(1,"Shared",0,[]) == ERR_BUSY, "shared roster catalog blocks other slot")
 roster.remember(1)
 check(roster.delete_character(0, true, Slots._save_digest(C)) == ERR_BUSY, "roster deletion refuses catalog evidence")
 unchanged("shared_roster_catalog", before, {})
 clear_primary(C)

 raw(G + JOURNAL, "not a journal")
 before = snapshot()
 check(Batch.write(C, "unsafe".to_utf8_buffer()) == ERR_BUSY and world.claim(2) == ERR_BUSY, "malformed journal cannot establish independence")
 unchanged("malformed_evidence", before, {})
 clear_primary(G)
 raw(C + ".txn_link", "user://not-a-journal")
 before = snapshot()
 check(world.new_world(2) == ERR_BUSY, "unknown link cannot establish independence")
 unchanged("unresolved_link", before, {})
 check(DirAccess.remove_absolute(C + ".txn_link") == OK, "fixture remove link")
 raw(C + ".txn_link", G2 + JOURNAL)
 before = snapshot()
 check(Batch.write(G, "unsafe".to_utf8_buffer()) == ERR_BUSY, "dangling link cannot establish independence")
 unchanged("dangling_link", before, {})
 check(DirAccess.remove_absolute(C + ".txn_link") == OK, "fixture remove dangling link")

 before = snapshot()
 check(Batch.begin(C) == OK and profile.save_profile() == ERR_UNAUTHORIZED and Batch.commit().original_error == ERR_UNAUTHORIZED,
  "unowned staged serializer cannot publish a migration backup")
 unchanged("unowned_serializer_stage", before, {})

 raw("user://saves/slot_1/character.cfg", FileAccess.get_file_as_string(C))
 var imported := Profile.new()
 imported.path = "user://saves/slot_1/character.cfg"
 check(imported.load_profile(false) == OK, "legacy import source")
 imported.identity = "abcd0123abcd0123abcd0123abcd0123"
 imported.data.name = "Imported"
 check(imported.save_profile() == OK and roster.prepare(world) == OK and roster.summary(1).name == "Imported", "legacy roster import")
 check(roster.delete_character(1, true, Slots._save_digest(C2)) == OK and not FileAccess.file_exists(C2), "legacy roster deletion")
 check(world.new_world(0, true) == OK and FileAccess.file_exists(G), "legacy occupied Garden replacement")

 var original := entry(G)
 pending(G, {G:original}, false)
 raw(G, "partially replaced")
 check(Batch.recover(G) == OK and entry(G) == original and not FileAccess.file_exists(G + JOURNAL), "readable legacy restart restores under gate")

 finish()
