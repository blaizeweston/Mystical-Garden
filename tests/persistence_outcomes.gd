extends SceneTree

const Ops = preload("res://persistence_operations.gd")
const Batch = preload("res://save_batch.gd")
const Auth = preload("res://persistence_authorization.gd")
const Plan = preload("res://persistence_recovery_plan.gd")

var failed := false
var leaked_stage: Callable
var expired_token: RefCounted
var nested_results := {}

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, message: String) -> void:
 if not condition:
  failed = true
  printerr("FAIL: ", message)

func garden(slot: int, preview := false) -> String:
 var base := "user://combat-balance-preview/saves" if preview else "user://saves"
 return base + "/slot_%d/garden.cfg" % slot

func profile(slot: int, preview := false) -> String:
 var base := "user://combat-balance-preview/saves" if preview else "user://saves"
 return base + "/characters/slot_%d/character.cfg" % slot

func initial(path: String, content: String) -> void:
 var file := FileAccess.open(path, FileAccess.WRITE)
 check(file != null, "open fixture " + path)
 if file != null:
  file.store_string(content)
  file.close()

func bootstrap(paths: PackedStringArray) -> void:
 var dirs := PackedStringArray()
 for path in paths:
  dirs.append(path.get_base_dir())
 check(Auth.bootstrap(dirs).error == OK, "bootstrap fixture")

func action_for(paths: PackedStringArray, business_value: Variant) -> Callable:
 return func(stage, _context):
  for path in paths:
   check(stage.call(path, "new".to_utf8_buffer()) == OK, "stage " + path)
  return business_value

func read_file(path: String) -> Variant:
 return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null

func evidence(paths: PackedStringArray, anchor: String) -> Dictionary:
 var files := {}
 for path in paths:
  for suffix in ["", ".txn_stage", ".txn_link", ".recovery"]:
   files[path + suffix] = read_file(path + suffix)
 var journal := ConfigFile.new()
 var marker: Variant = null
 var entries := {}
 if FileAccess.file_exists(anchor + ".transaction") and journal.load(anchor + ".transaction") == OK:
  marker = journal.get_value("transaction", "committed", null)
  for path in journal.get_value("transaction", "entries", {}):
   var entry: Dictionary = journal.get_value("transaction", "entries")[path]
   entries[path] = entry.bytes.get_string_from_utf8() if entry.exists else null
 return {"files": files, "marker": marker, "journal_bytes": read_file(anchor + ".transaction"), "journal_originals": entries}

func record(id: String, row: Dictionary) -> void:
 row.case = id
 row.run_id = OS.get_environment("MYSTICAL_VALIDATION_RUN")
 print("CASE ", JSON.stringify(row))

func check_result(id: String, boundary: Dictionary, paths: PackedStringArray, anchor: String, expected: int, expected_disk: Array, first: Error, recovery: Error, cleanup: Error, marker: Variant, blocked: bool) -> void:
 check(boundary.error == OK and boundary.ran, id + " authorization")
 var execution: Dictionary = boundary.get("value", {})
 check(execution.get("error") == OK and execution.get("ran") and execution.get("action_ran"), id + " execution")
 var result: Batch.Finalization = execution.get("outcome")
 check(result != null, id + " typed result")
 if result == null:
  return
 check(result.outcome == expected and result.original_error == first and result.recovery_error == recovery and result.cleanup_error == cleanup, id + " outcome or errors")
 check(result.paths.size() == paths.size() and result.journal_anchor == anchor and not result.attempt_id.is_empty(), id + " result identity")
 var disk := evidence(paths, anchor)
 for index in paths.size():
  check(disk.files[paths[index]] == expected_disk[index], id + " canonical bytes " + paths[index])
 check(disk.marker == marker and (disk.journal_bytes != null) == (marker != null), id + " journal marker")
 var attempted := Ops.run_batch(paths, anchor, func(_stage, _context): return "probe", true)
 var can_write: bool = attempted.ran and attempted.value.get("ran", false)
 check(can_write == not blocked and result.write_blocked == blocked, id + " next authorization")
 check(disk == evidence(paths, anchor), id + " next authorization probe changed disk")
 record(id, {
  "outcome": Batch.Outcome.keys()[result.outcome], "action_value": execution.value,
  "attempt_id": result.attempt_id, "phase": result.phase, "failed_path": result.failed_path,
  "original_error": result.original_error, "recovery_error": result.recovery_error,
  "cleanup_error": result.cleanup_error, "recovery_path": result.recovery_path,
  "cleanup_path": result.cleanup_path, "journal_anchor": result.journal_anchor,
  "paths": result.paths, "verification": result.verification, "disk": disk,
  "next_write_permitted": can_write, "next_boundary_error": attempted.error,
 })

func test_success() -> void:
 var g := garden(1)
 var c := profile(1)
 var paths := PackedStringArray([g, c])
 bootstrap(paths)
 initial(g, "garden-old")
 initial(c, "character-old")
 var outcome := Ops.run_batch(paths, g, func(stage, context):
  leaked_stage = stage
  var nested := Ops.run_nested(context, PackedStringArray([c]), func(_context):
   check(stage.call(c, "new".to_utf8_buffer()) == OK, "nested stage")
   var reentrant := Ops.run_batch(paths, g, action_for(paths, true))
   check(reentrant.error == ERR_BUSY and not reentrant.ran, "nested cannot open another batch")
   nested_results.reentrant_error = reentrant.error
   var foreign := Ops.run_nested(RefCounted.new(), paths, func(_bad): return ERR_BUG)
   check(foreign.error == ERR_UNAUTHORIZED and not foreign.ran, "foreign guarded context")
   nested_results.foreign_context_error = foreign.error
   return false)
  check(nested.ran and nested.value == false, "nested business value")
  check(stage.call(g, "new".to_utf8_buffer()) == OK, "outer stage")
  return false)
 check_result("pair_false_action", outcome, paths, g, Batch.Outcome.COMMITTED, ["new", "new"], OK, OK, OK, null, false)
 check(outcome.value.value == false and outcome.value.outcome.verification.commit_marker_verified, "false business result is not a save failure")
 check(leaked_stage.call(g, "late".to_utf8_buffer()) == ERR_UNAUTHORIZED, "staging callback expired")
 var direct := Batch._run_guarded(RefCounted.new(), paths, g, action_for(paths, true), false)
 check(direct.error == ERR_UNAUTHORIZED and not direct.ran, "foreign raw authorization")
 var first := Plan.discover(paths)
 var acquired := Auth.run(first.authorization_paths, func(token):
  expired_token = token
  return OK)
 check(acquired.error == OK, "capture expired raw token")
 var expired := Batch._run_guarded(expired_token, paths, g, action_for(paths, true), false)
 check(expired.error == ERR_UNAUTHORIZED and not expired.ran, "expired raw authorization")
 record("ownership", {"foreign_raw_error": direct.error, "expired_raw_error": expired.error, "staging_expired_error": ERR_UNAUTHORIZED, "nested": nested_results, "disk": evidence(paths, g)})

 var standalone := PackedStringArray([profile(2)])
 bootstrap(standalone)
 var written := Ops.run_batch(standalone, standalone[0], action_for(standalone, null))
 check_result("standalone_null_action", written, standalone, standalone[0], Batch.Outcome.COMMITTED, ["new"], OK, OK, OK, null, false)
 check(written.value.value == null, "null business value preserved")
 var noop := Ops.run_batch(standalone, standalone[0], func(_stage, _context): return null, true)
 check_result("explicit_no_op", noop, standalone, standalone[0], Batch.Outcome.COMMITTED, ["new"], OK, OK, OK, null, false)
 check(noop.value.outcome.verification.no_op, "explicit no-op proof")
 var incomplete := Ops.run_batch(standalone, standalone[0], func(_stage, _context): return false)
 check_result("implicit_empty_stage_is_not_no_op", incomplete, standalone, standalone[0], Batch.Outcome.ABORTED_RESTORED, ["new"], ERR_INVALID_DATA, OK, OK, null, false)

func test_failure(id: String, slot: int, preview: bool, mode: String, expected: int, expected_disk: Array, recovery: Error, cleanup: Error, marker: Variant, blocked: bool) -> void:
 var g := garden(slot, preview)
 var c := profile(slot, preview)
 var paths := PackedStringArray([g, c])
 bootstrap(paths)
 initial(g, "garden-old")
 if mode != "replace":
  initial(c, "character-old")
 var outcome := Ops._run_batch(paths, g, action_for(paths, true), false, func(phase, path):
  if phase == "stage" and mode == "stage" and path == g + ".txn_stage":
   return ERR_CANT_CREATE
  if phase == "replace" and mode in ["replace", "restore"] and path == g:
   return ERR_CANT_CREATE
  if phase == "restore" and mode == "restore":
   return ERR_FILE_CANT_WRITE
  if phase == "publish_commit_marker" and mode == "marker":
   return ERR_CANT_CREATE
  if phase == "cleanup" and mode == "cleanup" and path == g + ".transaction":
   return ERR_CANT_CREATE
  return OK)
 var original_error := OK if mode == "cleanup" else ERR_CANT_CREATE
 check_result(id, outcome, paths, g, expected, expected_disk, original_error, recovery, cleanup, marker, blocked)
 if mode in ["replace", "restore"]:
  check(outcome.value.outcome.verification.replacements == 1, id + " first replacement was reached")
 if mode == "cleanup":
  check(outcome.value.outcome.verification.commit_marker_verified, "cleanup failure preserved commit proof")
 if blocked:
  var plan := Plan.discover(PackedStringArray([c]))
  check(plan.state == "pending_recovery" and plan.participants.has(g) and plan.participants.has(c), id + " reverse restart preflight")
  record(id + "_reverse_preflight", {"state": plan.state, "participants": plan.participants, "anchors": plan.journal_anchors, "reason": plan.reason})
  for path in paths:
   var single := Ops.run_batch(PackedStringArray([path]), path, action_for(PackedStringArray([path]), true))
   check(not single.ran or not single.value.get("ran", false), id + " blocked standalone " + path)

func test_contradictory_commit() -> void:
 var g := "user://garden.cfg"
 var c := "user://character.cfg"
 var paths := PackedStringArray([g, c])
 initial(g, "garden-old")
 initial(c, "character-old")
 var outcome := Ops._run_batch(paths, g, action_for(paths, "tentative"), false, func(phase, _path):
  if phase == "publish_commit_marker":
   # Simulate a non-cooperating writer at the point of marker publication.
   initial(c, "contradictory")
  return OK)
 check_result("marker_with_wrong_participant", outcome, paths, g, Batch.Outcome.UNCERTAIN, ["new", "contradictory"], ERR_INVALID_DATA, OK, OK, true, true)
 check(outcome.value.outcome.verification.commit_marker_verified and outcome.value.outcome.phase == "verify_committed_participants", "verified marker alone cannot certify inconsistent bytes")
 check(Plan.discover(PackedStringArray([c])).state == "pending_recovery", "contradictory record remains available")

func run() -> void:
 test_success()
 test_failure("before_replacement", 2, false, "stage", Batch.Outcome.ABORTED_RESTORED, ["garden-old", "character-old"], OK, OK, null, false)
 test_failure("partial_replace_restored_absence", 3, false, "replace", Batch.Outcome.ABORTED_RESTORED, ["garden-old", null], OK, OK, null, false)
 test_failure("partial_replace_restore_failed", 1, true, "restore", Batch.Outcome.UNCERTAIN, ["garden-old", "new"], ERR_FILE_CANT_WRITE, OK, false, true)
 test_failure("marker_publication_failed", 2, true, "marker", Batch.Outcome.ABORTED_RESTORED, ["garden-old", "character-old"], OK, OK, null, false)
 test_failure("committed_cleanup_pending", 3, true, "cleanup", Batch.Outcome.COMMITTED_CLEANUP_PENDING, ["new", "new"], OK, ERR_CANT_CREATE, true, true)
 test_contradictory_commit()
 if not failed:
  print("PASS: typed SaveBatch outcomes")
 quit(1 if failed else 0)