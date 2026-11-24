extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")
const Tx = preload("res://game_transaction.gd")
const Batch = preload("res://save_batch.gd")
const Progress = preload("res://progress.gd")
const Profile = preload("res://character_profile.gd")
const Auth = preload("res://persistence_authorization.gd")
const Ops = preload("res://persistence_operations.gd")
const Plan = preload("res://persistence_recovery_plan.gd")
const Integration = preload("res://persistence_writer_integration.gd")
const G := "user://saves/slot_1/garden.cfg"
const C := "user://saves/characters/slot_1/character.cfg"
const Other := "user://saves/characters/slot_2/character.cfg"
var failed := false
var notifications := 0

class TransactionFixture extends Node:
 var persistence_session := preload("res://guarded_title_session.gd").new()
 const HOST := 1
 var progress := Progress.new()
 var local_character := Profile.new()
 var guest_character := Profile.new()
 var players := {}
 var transaction_publishes := []
 var rng := RandomNumberGenerator.new()
 var network_session := SessionCase.Session.new()
 var score := 0

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: ", message)

func record(id: String, data: Dictionary) -> void:
 data.case = id
 data.run_id = OS.get_environment("MYSTICAL_VALIDATION_RUN")
 print("CASE ", JSON.stringify(data))

func model() -> TransactionFixture:
 var world := TransactionFixture.new()
 world.progress.path = G
 world.local_character.path = C
 world.guest_character.path = Other
 world.rng.seed = 17
 return world

func hashes() -> Dictionary:
 var files := {}
 for path in [G,C,Other]:
  for suffix: String in [""] + Plan.ARTIFACTS + [".pre-content-v2.bak", ".pre-content-v2.bak.tmp"]:
   var file := str(path) + suffix
   files[file] = FileAccess.get_sha256(file) if FileAccess.file_exists(file) else null
 return files

func published(_value: Variant) -> void:
 notifications += 1

func get_outcome(boundary: Dictionary) -> Batch.Finalization:
 if not boundary.ran or not boundary.value is Dictionary:
  return null
 return boundary.value.get("outcome")

func verify_outcome(id: String, boundary: Dictionary, expected: int, before: Dictionary) -> void:
 var outcome := get_outcome(boundary)
 check(outcome != null, id + " result exists")
 if outcome != null:
  check(outcome.outcome == expected, id + " outcome")
  record(id, {"outcome": Batch.Outcome.keys()[outcome.outcome], "error": outcome.original_error,
   "cleanup_error": outcome.cleanup_error, "recovery_error": outcome.recovery_error,
   "reason": outcome.phase, "action_value": boundary.value.value, "publish_count": notifications,
   "write_blocked": outcome.write_blocked, "before": before, "after": hashes()})

func run() -> void:
 check(Auth.bootstrap(PackedStringArray([G.get_base_dir(), C.get_base_dir(), Other.get_base_dir()])).error == OK, "bootstrap")
 var world := model()
 var other_world := model()
 var before := hashes()
 verify_outcome("standalone_garden", world.progress.save_garden_guarded(), Batch.Outcome.COMMITTED, before)
 verify_outcome("standalone_character", world.local_character.save_profile_guarded(), Batch.Outcome.COMMITTED, hashes())
 before = hashes()
 world.progress.needs_content_backup = true
 world.local_character.needs_content_backup = true
 var pair := Tx.run_guarded(world, func():
  var unrelated := Tx.run_guarded(other_world, func(): check(false, "foreign action ran"))
  check(not unrelated.ran and unrelated.error == ERR_BUSY, "foreign game refused")
  var independent: Dictionary = world.local_character.save_profile_guarded()
  check(not independent.ran and independent.error == ERR_BUSY, "no independent reacquisition")
  var nested := Tx.run_guarded(world, func():
   world.progress.knowledge = 41
   check(world.progress.save_garden() == OK, "nested Garden serializer")
   check(world.local_character.save_profile() == OK, "nested profile serializer")
   check(world.local_character.load_profile() == OK, "nested load reuses lock")
   return false)
  check(nested.ran and nested.nested and nested.value == false, "nested business value")
  var original_dispatch = Tx.run(world, func(): return "nested legacy entry")
  check(original_dispatch == "nested legacy entry", "same-owner legacy dispatcher does not open a second batch")
  return null, published)
 verify_outcome("pair_nested_backups", pair, Batch.Outcome.COMMITTED, before)
 check(notifications == 1 and pair.value.value == null, "null business return and one publication")
 check(hashes()[G + ".pre-content-v2.bak"] == before[G] and hashes()[C + ".pre-content-v2.bak"] == before[C], "migration backups retain original bytes")
 var persisted := model()
 check(persisted.progress.load_garden_guarded().value == OK and persisted.progress.knowledge == 41, "guarded Garden load")
 check(persisted.local_character.load_profile_guarded().value == OK, "guarded profile load")

 before = hashes()
 var prior_rng := world.rng.state
 var aborted := Tx._run_guarded(world, func():
  world.progress.knowledge = 99
  world.score = 19
  world.rng.randf()
  world.players[99] = {"joined": true}
  return false, published, func(phase, _path):
  return ERR_CANT_CREATE if phase == "stage" else OK)
 verify_outcome("verified_abort", aborted, Batch.Outcome.ABORTED_RESTORED, before)
 check(world.progress.knowledge == 41 and world.score == 0 and world.rng.state == prior_rng and world.players.is_empty() and hashes() == before and notifications == 1, "verified abort restores memory and suppresses publication")

 var backup_path := C + ".pre-content-v2.bak"
 check(DirAccess.remove_absolute(backup_path) == OK, "prepare disposable backup fault")
 var scratch := FileAccess.open(backup_path + ".tmp", FileAccess.WRITE)
 check(scratch != null, "prepare interrupted backup")
 if scratch != null:
  scratch.store_string("unverified backup residue")
  scratch.close()
 var before_backup_failure := hashes()
 var backup_failed := Tx.run_guarded(world, func():
  check(world.progress.save_garden() == OK, "Garden staged before profile backup failure")
  world.local_character.needs_content_backup = true
  check(world.local_character.save_profile() == ERR_BUSY, "unverified backup scratch refused")
  return true, published)
 verify_outcome("backup_failure_after_staging", backup_failed, Batch.Outcome.ABORTED_RESTORED, before_backup_failure)
 check(backup_failed.value.outcome.original_error == ERR_BUSY and hashes() == before_backup_failure and notifications == 1, "failed backup preserves bytes and suppresses publication")
 check(DirAccess.remove_absolute(backup_path + ".tmp") == OK, "dispose invalid backup scratch")
 before = hashes()

 var unrelated := Profile.new()
 unrelated.path = Other
 var denied := Tx.run_guarded(world, func():
  check(unrelated.save_profile() == ERR_UNAUTHORIZED, "undeclared serializer refused")
  check(Batch.commit().original_error == ERR_BUSY, "legacy commit cannot finalize")
  return false, published)
 verify_outcome("foreign_serializer", denied, Batch.Outcome.ABORTED_RESTORED, before)
 check(hashes() == before and notifications == 1, "foreign serializer abort")

 var legacy_write := Tx.run_guarded(world, func():
  check(Batch.write("user://settings.cfg", "unrelated".to_utf8_buffer()) == ERR_UNAUTHORIZED, "legacy Batch.write refused")
  return false, published)
 verify_outcome("legacy_batch_bypass_refused", legacy_write, Batch.Outcome.ABORTED_RESTORED, before)
 check(not FileAccess.file_exists("user://settings.cfg"), "unrelated file untouched")

 var lease := ConfigFile.new()
 lease.set_value("session", "process_id", OS.get_process_id() + 1)
 lease.set_value("session", "updated", Time.get_unix_time_from_system())
 var marker := C.get_base_dir().path_join("session.cfg")
 check(lease.save(marker) == OK, "foreign lease setup")
 var foreign := Tx.run_guarded(world, func(): check(false, "leased action ran"))
 check(not foreign.ran and foreign.reason == "foreign_session_lease" and hashes() == before, "foreign lease refusal")
 check(DirAccess.remove_absolute(marker) == OK, "clear disposable lease")
 record("foreign_lease", foreign)

 var pending := Tx._run_guarded(world, func():
  world.progress.knowledge = 64
  world.score = 7
  world.local_character.data.name = "Changed profile"
  return true, published, func(phase, path):
  if phase == "replace" and path == G:
   return ERR_CANT_CREATE
  return ERR_FILE_CANT_WRITE if phase == "restore" else OK)
 verify_outcome("uncertain", pending, Batch.Outcome.UNCERTAIN, before)
 var split := hashes()
 check(world.progress.knowledge == 64 and world.score == 7 and notifications == 1 and world.persistence_session.is_blocked(), "uncertain preserves tentative memory without publication")
 var retry := Tx.run_guarded(world, func(): check(false, "uncertain action replayed"), published)
 check(not retry.ran and retry.reason == "guarded_persistence_pending" and split == hashes(), "uncertain retry refused")
 var read_pending: Dictionary = persisted.progress.load_garden_guarded()
 var profile_pending: Dictionary = persisted.local_character.load_profile_guarded()
 check(not read_pending.ran and not profile_pending.ran and read_pending.state == "pending_recovery" and split == hashes(), "guarded load is explicitly pending and does not recover")
 check(persisted.local_character.load_profile(false) == OK and split == hashes(), "read-only profile load remains non-recovering")
 check(persisted.progress.load_garden(false) == OK and split == hashes(), "read-only Garden load is non-recovering")
 var recovered := Ops.recover(PackedStringArray([C]))
 check(recovered.ran and recovered.value.verified and hashes() == before, "B2 recovery from guarded serializer split")
 record("recovery_after_uncertain", recovered)

 var refreshed := model()
 check(refreshed.progress.load_garden_guarded().value == OK and refreshed.progress.knowledge == 41, "reconcile by loading verified Garden")
 var committed_cleanup := Tx._run_guarded(refreshed, func():
  refreshed.progress.knowledge = 77
  return true, published, func(phase, _path):
  return ERR_CANT_CREATE if phase == "publish_receipt" else OK)
 verify_outcome("committed_cleanup_pending", committed_cleanup, Batch.Outcome.COMMITTED_CLEANUP_PENDING, before)
 check(refreshed.progress.knowledge == 77 and notifications == 2 and refreshed.persistence_session.is_blocked(), "confirmed commit keeps state and publishes once")
 check(Ops.recover(PackedStringArray([G])).value.verified, "B2 committed cleanup")

 var guest := model()
 SessionCase.set_role(guest, "Guest")
 var guest_before := hashes()
 verify_outcome("guest_garden_only", Tx.run_guarded(guest, func():
  guest.progress.knowledge = 79), Batch.Outcome.COMMITTED, guest_before)
 check(hashes()[C] == guest_before[C] and hashes()[Other] == guest_before[Other], "guest route stages only Garden")
 guest.free()

 var legacy := model()
 legacy.progress.knowledge = 81
 check(legacy.progress.save_garden() == OK and legacy.local_character.save_profile() == OK and not FileAccess.file_exists(G + ".transaction"), "legacy route stays active outside opted-in operation")
 check(not Integration.migration_status().allowed and Integration.VERIFIED_WRITERS.is_empty(), "older save migration remains gated")
 record("legacy_route", {"files": hashes(), "activation": Integration.migration_status()})
 world.free()
 other_world.free()
 persisted.free()
 refreshed.free()
 legacy.free()
 if not failed:
  print("PASS: guarded core serializers and transactions")
 quit(1 if failed else 0)