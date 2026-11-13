extends SceneTree

const Slots = preload("res://save_slots.gd")
const Roster = preload("res://character_slots.gd")
const Ops = preload("res://persistence_operations.gd")
const Batch = preload("res://save_batch.gd")
const Planner = preload("res://persistence_recovery_plan.gd")
var failed := false
var worlds := Slots.new()
var roster := Roster.new()

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, reason: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: ", reason)

func result(boundary: Dictionary) -> Dictionary:
 return boundary.value if boundary.get("ran", false) and boundary.get("value") is Dictionary else boundary

func expect(id: String, boundary: Dictionary, state: String, paths: PackedStringArray) -> Dictionary:
 var outcome := result(boundary).duplicate()
 check(outcome.get("state") == state, id + " " + str(outcome.get("reason")))
 var final: Batch.Finalization = outcome.get("outcome")
 if final != null:
  outcome.outcome = {"outcome": Batch.Outcome.keys()[final.outcome], "original_error": final.original_error,
   "recovery_error": final.recovery_error, "cleanup_error": final.cleanup_error, "failed_path": final.failed_path,
   "recovery_path": final.recovery_path, "verification": final.verification}
 var snapshot := {}
 var evidence_paths := paths.duplicate()
 for archive: String in outcome.get("archives", {}).values():
  evidence_paths.append(archive)
 if outcome.has("failed_path"):
  evidence_paths.append(outcome.failed_path)
  evidence_paths.append(outcome.failed_path + ".tmp")
 for path in evidence_paths:
  snapshot[path] = Slots._save_digest(path)
  if path.get_file() in ["garden.cfg", "character.cfg", "catalog.cfg", "deleted.cfg"]:
   for suffix: String in Planner.ARTIFACTS:
    snapshot[path + suffix] = Slots._save_digest(path + suffix)
 print("CASE ", JSON.stringify({"case": id, "result": outcome, "files": snapshot}))
 return outcome

func check_archive(outcome: Dictionary, source: String, digest: String) -> void:
 var archive: String = outcome.get("archives", {}).get(source, "")
 check(not archive.is_empty() and Slots._save_digest(archive) == digest, "archive bytes for " + source)

func worlds_test() -> void:
 var first: Dictionary = worlds.paths(0)
 var second: Dictionary = worlds.paths(1)
 var dev := Slots.new()
 dev.root_path = "user://saves/developer-garden"
 var dev_slot := dev.paths(0)
 var paths := PackedStringArray([first.garden, first.character, first.directory.path_join("deleted.cfg"),
  first.directory.path_join("session.cfg")])
 expect("create_pair", worlds.new_game_guarded(0), "completed", paths)
 var garden := Slots._save_digest(first.garden)
 var character := Slots._save_digest(first.character)
 var replaced := expect("occupied_world", worlds.new_world_guarded(0, true), "completed", paths)
 check_archive(replaced, first.garden, garden)
 check(not replaced.archives.has(first.character) and Slots._save_digest(first.character) == character, "world leaves character intact")
 replaced = expect("occupied_pair", worlds.new_game_guarded(0, true), "completed", paths)
 check_archive(replaced, first.garden, garden)
 check_archive(replaced, first.character, character)
 character = Slots._save_digest(first.character)
 check(dev.new_game_guarded(0).value.error == OK, "developer fixture")
 var dev_character := Slots._save_digest(dev_slot.character)
 replaced = expect("occupied_developer_reset", dev.new_game_guarded(0, true), "completed", PackedStringArray([dev_slot.garden, dev_slot.character]))
 check_archive(replaced, dev_slot.character, dev_character)

 for fail_name in ["character.cfg", "garden.cfg"]:
  var partial := expect("archive_failure_" + fail_name,
   worlds._initialize_guarded(0, true, true, false, func(phase, path):
    return ERR_FILE_CANT_WRITE if phase == "archive" and path.get_file() == fail_name else OK),
   "verified_failure" if fail_name == "character.cfg" else "partial_completion", paths)
  check(Slots._save_digest(first.garden) == garden and Slots._save_digest(first.character) == character, "archive failure preserves originals")
  if fail_name == "garden.cfg":
   check_archive(partial, first.character, character)
 var aborted := expect("replace_after_archive_aborts", worlds._initialize_guarded(0, true, true, false, func(phase, path):
  return ERR_CANT_CREATE if phase == "replace" and path == first.garden else OK), "verified_failure", paths)
 check(aborted.outcome.outcome == "ABORTED_RESTORED" and Slots._save_digest(first.character) == character, "replacement compensation")
 check_archive(aborted, first.character, character)

 var occupied := Slots._archive_folder(first.directory, "deleted-world-")
 check(Slots.Auth.bootstrap_archive(occupied, first.garden).error == OK, "occupied archive fixture")
 var target := occupied.path_join("garden.cfg")
 check(Batch.write_bytes(target, "keep this archive".to_utf8_buffer()) == OK, "archive seed")
 var target_hash := Slots._save_digest(target)
 expect("archive_destination_occupied", worlds._delete_guarded(0, false, true, {}, Callable(), occupied), "verified_failure", paths)
 check(Slots._save_digest(target) == target_hash and Slots._save_digest(first.garden) == garden, "no archive overwrite")
 var unsafe := worlds._delete_guarded(0, false, true, {}, Callable(), second.directory.path_join("backups/deleted-world-1111111111111111"))
 check(unsafe.error == ERR_INVALID_PARAMETER and Slots._save_digest(first.garden) == garden, "unsafe archive refused")
 expect("stale_confirmation", worlds.delete_world_guarded(0, true, "incorrect"), "verified_failure", paths)
 expect("tombstone_failure", worlds._delete_guarded(0, false, true, {}, func(phase, path):
  return ERR_CANT_CREATE if phase == "replace" and path.get_file() == "deleted.cfg" else OK), "verified_failure", paths)
 check(Slots._save_digest(first.garden) == garden and Slots._save_digest(paths[2]) == "absent", "tombstone never published")
 expect("world_removal_failure", worlds._delete_guarded(0, false, true, {}, func(phase, _path):
  return ERR_CANT_CREATE if phase == "remove" else OK), "verified_failure", paths)
 check(Slots._save_digest(first.garden) == garden and Slots._save_digest(paths[2]) == "absent", "restored original tombstone absence")
 var marker := ConfigFile.new()
 marker.set_value("session", "process_id", OS.get_process_id() + 1)
 marker.set_value("session", "updated", Time.get_unix_time_from_system())
 check(marker.save(paths[3]) == OK, "foreign lease fixture")
 expect("foreign_lease", worlds.delete_world_guarded(0, true), "busy", paths)
 check(DirAccess.remove_absolute(paths[3]) == OK, "dispose foreign lease")
 var deleted := expect("delete_world", worlds.delete_world_guarded(0, true, garden), "completed", paths)
 check_archive(deleted, first.garden, garden)
 check(Slots._save_digest(first.garden) == "absent" and Slots._save_digest(first.character) == character, "world deletion keeps character")
 check(Ops.inspect(first.garden).state == "empty", "committed deleted world is empty")
 check(Batch.write_bytes(worlds.legacy_garden, "legacy".to_utf8_buffer()) == OK, "legacy input")
 expect("legacy_tombstone_blocks_import", worlds.prepare_guarded(), "completed", paths)
 check(Slots._save_digest(first.garden) == "absent", "legacy garden remains deleted")
 check(worlds.new_game_guarded(1).value.error == OK, "second pair")
 var second_paths := PackedStringArray([second.garden, second.character, second.directory.path_join("deleted.cfg")])
 var second_hash := Slots._save_digest(second.character)
 var journal := ConfigFile.new()
 journal.set_value("transaction", "entries", {second.character: {"exists": true, "bytes": FileAccess.get_file_as_bytes(second.character)}})
 journal.set_value("transaction", "committed", false)
 check(journal.save(second.garden + ".transaction") == OK, "legacy journal fixture")
 check(DirAccess.remove_absolute(second.character) == OK, "fixture missing linked profile")
 expect("missing_canonical_pending_delete", worlds.delete_save_guarded(1, true), "pending_recovery", second_paths)
 expect("missing_canonical_pending_replace", worlds.new_game_guarded(1, true), "pending_recovery", second_paths)
 check(Ops.recover(PackedStringArray([second.character])).value.verified, "restore recoverable missing participant")
 check(Slots._save_digest(second.character) == second_hash, "restored missing participant bytes")
 deleted = expect("delete_pair", worlds.delete_save_guarded(1, true), "completed", second_paths)
 check_archive(deleted, second.character, second_hash)
 check(Slots._save_digest(second.garden) == "absent" and Slots._save_digest(second.character) == "absent", "pair absent")

func roster_test() -> void:
 var source := roster._slot_profile(0)
 var unrelated := roster._slot_profile(1)
 var catalog := roster._catalog_path()
 var paths := PackedStringArray([source, unrelated, catalog, source.get_base_dir().path_join("session.cfg")])
 expect("create_roster_target", roster.create_guarded(0, "Delete", 0, []), "completed", paths)
 expect("create_roster_neighbor", roster.create_guarded(1, "Keep", 0, []), "completed", paths)
 expect("roster_preferences", roster.remember_guarded(1), "completed", paths)
 var prior := Slots._save_digest(source)
 var keep := Slots._save_digest(unrelated)
 var old_catalog := Slots._save_digest(catalog)
 var identity: String = roster.summary(0).identity
 var catalog_failed := expect("catalog_failure", roster._delete_guarded(0, true, prior, func(phase, path):
  return ERR_CANT_CREATE if phase == "replace" and path == catalog else OK), "verified_failure", paths)
 check(catalog_failed.outcome.outcome == "ABORTED_RESTORED", "catalog failure verified abort")
 check(Slots._save_digest(catalog) == old_catalog and Slots._save_digest(source) == prior, "catalog failure keeps originals")
 var uncertain := expect("catalog_compensation_failure", roster._delete_guarded(0, true, prior, func(phase, path):
  if phase == "remove" and path == source:
   return ERR_CANT_CREATE
  return ERR_FILE_CANT_WRITE if phase == "restore" else OK), "unresolved", paths)
 check(uncertain.outcome.outcome == "UNCERTAIN" and Slots._save_digest(catalog) != old_catalog, "catalog evidence retained")
 check_archive(uncertain, source, prior)
 expect("shared_catalog_conflicting_edit", roster.update_guarded(1, "Blocked", 0, []), "pending_recovery", paths)
 check(Ops.inspect(unrelated).state == "pending_recovery", "shared catalog pending visible")
 check(Ops.recover(PackedStringArray([source])).value.verified, "restore roster from verified journal")
 check(Slots._save_digest(source) == prior and Slots._save_digest(catalog) == old_catalog, "restored source and catalog")
 var deleted := expect("delete_roster", roster.delete_character_guarded(0, true, prior), "completed", paths)
 check_archive(deleted, source, prior)
 var config := ConfigFile.new()
 check(config.load(catalog) == OK and config.has_section_key("deleted_identities", identity) and roster.last_slot() == 1, "catalog preserves preferences")
 check(Slots._save_digest(source) == "absent" and Slots._save_digest(unrelated) == keep, "unrelated roster unchanged")

func run() -> void:
 worlds_test()
 roster_test()
 check(not preload("res://persistence_writer_integration.gd").activation_status().allowed, "production disabled")
 if not failed:
  print("PASS: guarded destructive slot and roster operations")
 quit(1 if failed else 0)
