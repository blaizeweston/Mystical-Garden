extends SceneTree

const Ops = preload("res://persistence_operations.gd")
const Auth = preload("res://persistence_authorization.gd")
const Plan = preload("res://persistence_recovery_plan.gd")
const Batch = preload("res://save_batch.gd")
const Proof = preload("res://persistence_evidence.gd")
const G := "user://saves/slot_1/garden.cfg"
const C := "user://saves/characters/slot_1/character.cfg"
const A := "user://saves/slot_2/garden.cfg"
const PATHS := [C, G]
var failed := false

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, text: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: ", text)

func put(path: String, value: String) -> void:
 check(Batch.write_bytes(path, value.to_utf8_buffer()) == OK, "write fixture " + path)

func file(path: String) -> Variant:
 return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null

func state() -> Dictionary:
 var output := {}
 for path in [G, C, A]:
  for suffix in [""] + Plan.ARTIFACTS:
   output[path + suffix] = file(path + suffix)
 return output

func print_case(id: String, result: Dictionary, before: Dictionary) -> void:
 print("CASE ", JSON.stringify({"case": id, "run_id": OS.get_environment("MYSTICAL_VALIDATION_RUN"),
  "result": result, "before": before, "after": state()}))

func journal(anchor: String, entries: Dictionary, committed := false) -> void:
 var cfg := ConfigFile.new()
 cfg.set_value("transaction", "entries", entries)
 cfg.set_value("transaction", "committed", committed)
 check(cfg.save(anchor + ".transaction") == OK, "fixture journal")

func old(text: String) -> Dictionary:
 return {"exists": true, "bytes": text.to_utf8_buffer()}

func blocked(id: String, reason: String, path := C) -> void:
 var before := state()
 var result := Ops.recover(PackedStringArray([path]))
 check(result.reason == reason and (not result.ran or result.value.write_blocked) and before == state(), id)
 var write := Ops.run_batch(PackedStringArray([path]), path, func(_stage, _context):
  check(false, "blocked writer ran"))
 check(not write.ran and before == state(), id + " writer refusal")
 print_case(id, {"recovery": result, "writer_permitted": write.ran}, before)

func run() -> void:
 var paths := PackedStringArray(PATHS)
 check(Auth.bootstrap(PackedStringArray([G.get_base_dir(), C.get_base_dir(), A.get_base_dir()])).error == OK, "bootstrap")
 put(G, "new garden")
 put(C, "new profile")
 put(A, "untouched anchor")
 var entries := {G: old("old garden"), C: {"exists": false, "bytes": PackedByteArray()}}
 journal(A, entries)
 var preview := Plan.discover(PackedStringArray([C]))
 var original := state()
 var scope_refusal := Auth.run(PackedStringArray([C]), func(token):
  return Batch._recover_guarded(token, preview, PackedStringArray([C]), Callable()))
 check(scope_refusal.ran and scope_refusal.value.authorization_error == ERR_UNAUTHORIZED and state() == original, "incomplete live scope")
 print_case("scope_refusal", scope_refusal.value, original)
 var drift := Auth.run(preview.authorization_paths, func(token):
  put(G, "changed after discovery")
  return Batch._recover_guarded(token, preview, PackedStringArray([C]), Callable()))
 check(drift.ran and drift.value.reason == "observations_changed" and file(C) == "new profile" and file(A + ".transaction") == original[A + ".transaction"], "locked drift refused")
 put(G, "new garden")
 print_case("locked_drift", drift.value, original)

 var held := Auth.run(preview.authorization_paths, func(_token):
  return Ops.recover(PackedStringArray([C])))
 check(held.ran and held.value.error == ERR_BUSY and state() == original, "nested acquisition refused")

 var lease := ConfigFile.new()
 lease.set_value("session", "process_id", OS.get_process_id() + 1)
 lease.set_value("session", "updated", Time.get_unix_time_from_system())
 var lease_path := C.get_base_dir().path_join("session.cfg")
 check(lease.save(lease_path) == OK, "write foreign lease")
 blocked("foreign_lease", "foreign_session_lease")
 check(DirAccess.remove_absolute(lease_path) == OK, "clear fixture lease")

 var restore_failed := Ops._recover(PackedStringArray([C]), func(phase, _path):
  return ERR_FILE_CANT_WRITE if phase == "restore" else OK)
 check(restore_failed.ran and restore_failed.value.restoration_error == ERR_FILE_CANT_WRITE and restore_failed.value.write_blocked and original == state(), "restoration error preserves evidence")
 print_case("restoration_failure", restore_failed, original)

 var stopped := Ops._recover(PackedStringArray([C]), func(phase, path):
  return ERR_CANT_CREATE if phase == "cleanup" and path == A + ".transaction" else OK)
 check(stopped.ran and stopped.value.cleanup_error == ERR_CANT_CREATE and stopped.value.write_blocked and file(A + ".transaction") != null and file(G) == "old garden" and file(C) == null, "cleanup failure after verified restore")
 print_case("cleanup_failure", stopped, original)
 var before_retry := state()
 var restored := Ops.recover(PackedStringArray([C]))
 check(restored.ran and restored.value.verified and not restored.value.write_blocked and file(A) == "untouched anchor" and file(A + ".transaction") == null, "legacy anchor and absent original")
 print_case("legacy_retry", restored, before_retry)
 var clean := Ops.recover(paths)
 check(clean.ran and clean.value.state == "clean", "idempotent clean recovery")
 var before_write := state()
 var written := Ops.run_batch(paths, G, func(stage, _scope):
  check(stage.call(G, "later garden".to_utf8_buffer()) == OK, "later stage")
  check(stage.call(C, "later profile".to_utf8_buffer()) == OK, "later stage"))
 check(written.ran and written.value.outcome.outcome == Batch.Outcome.COMMITTED and file(G) == "later garden" and file(C) == "later profile", "real write after recovery")

 print_case("subsequent_write", {"writer_permitted": written.ran, "outcome": written.value.outcome.outcome}, before_write)
 var before_commit := state()
 var pending := Ops._run_batch(paths, G, func(stage, _scope):
  stage.call(G, "expected garden".to_utf8_buffer())
  stage.call(C, "expected profile".to_utf8_buffer()), false, func(phase, _path):
  return ERR_CANT_CREATE if phase == "publish_receipt" else OK)
 check(pending.ran and pending.value.outcome.outcome == Batch.Outcome.COMMITTED_CLEANUP_PENDING, "receipt publication fault")
 print_case("receipt_publication_fault", {"outcome": pending.value.outcome.outcome, "cleanup_error": pending.value.outcome.cleanup_error}, before_commit)
 put(C, "mismatched file")
 blocked("contradictory_committed", "committed_state_mismatch")
 put(C, "expected profile")
 var recover_commit := Ops.recover(paths)
 check(recover_commit.value.verified and file(C) == "expected profile" and file(G) == "expected garden", "committed cleanup retry")
 journal(G, entries, true)
 blocked("legacy_committed", "committed_without_expected_state")
 check(DirAccess.remove_absolute(G + ".transaction") == OK, "clear fixture journal")
 put(G + ".transaction", "[transaction]\nentries={")
 blocked("corrupt", "journal_syntax")
 check(DirAccess.remove_absolute(G + ".transaction") == OK, "clear corrupt fixture")
 journal(G, {"user://../garden.cfg": old("unsafe")})
 blocked("unsafe", "unsafe_journal_participant")
 check(DirAccess.remove_absolute(G + ".transaction") == OK, "clear unsafe fixture")
 journal(G, entries)
 journal(A, entries)
 blocked("overlap", "overlapping_journals")
 check(DirAccess.remove_absolute(A + ".transaction") == OK, "clear overlap fixture")
 put(C + ".txn_link", "user://saves/slot_2/garden.cfg.transaction")
 blocked("wrong_link", "dangling_or_unsafe_link")
 check(DirAccess.remove_absolute(C + ".txn_link") == OK, "clear bad link")
 check(DirAccess.remove_absolute(G + ".transaction") == OK, "clear owned journal")
 put(C + ".txn_stage", "orphan stage")
 blocked("orphan_stage", "unowned_artifact")
 check(DirAccess.remove_absolute(C + ".txn_stage") == OK, "clear orphan stage")
 journal(G, entries)
 put(G + ".recovery", "foreign scratch")
 blocked("unowned_restore_scratch", "unowned_restore_scratch")
 if not failed:
  print("PASS: authorized restart recovery")
 quit(1 if failed else 0)