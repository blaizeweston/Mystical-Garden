extends SceneTree

const Slots = preload("res://save_slots.gd")
const Roster = preload("res://character_slots.gd")
const Profile = preload("res://character_profile.gd")
const Progress = preload("res://progress.gd")
const Ops = preload("res://persistence_operations.gd")
const Auth = preload("res://persistence_authorization.gd")
const Batch = preload("res://save_batch.gd")
const Plan = preload("res://persistence_recovery_plan.gd")
var failed := false

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: ", message)

func result(boundary: Dictionary) -> Dictionary:
 return boundary.value if boundary.get("ran", false) and boundary.get("value") is Dictionary else boundary

func test_result(id: String, boundary: Dictionary, state: String) -> Dictionary:
 var outcome := result(boundary).duplicate()
 check(outcome.get("state") == state, id + ": " + str(outcome.get("reason")))
 if outcome.has("outcome"):
  var final: Batch.Finalization = outcome.outcome
  outcome.outcome = {"outcome": Batch.Outcome.keys()[final.outcome], "error": final.original_error, "paths": final.paths, "blocked": final.write_blocked}
 print("CASE ", JSON.stringify({"case": id, "run_id": OS.get_environment("MYSTICAL_VALIDATION_RUN"), "result": outcome}))
 return outcome

func file_hash(path: String) -> String:
 return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"

func fixture_journal(anchor: String, path: String) -> void:
 var cfg := ConfigFile.new()
 cfg.set_value("transaction", "entries", {path: {"exists": false, "bytes": PackedByteArray()}})
 cfg.set_value("transaction", "committed", false)
 check(cfg.save(anchor + ".transaction") == OK, "fixture journal")

func fixture_legacy(worlds: RefCounted) -> void:
 var world := Progress.new()
 world.path = worlds.legacy_garden
 world.knowledge = 32
 check(world.save_garden() == OK, "legacy Garden fixture")
 var character := Profile.new()
 character.path = worlds.legacy_character
 character.data.name = "Old Wanderer"
 check(character.save_profile() == OK, "legacy character fixture")
 character.path = worlds.legacy_guest
 check(character.save_profile() == OK, "legacy guest fixture shares identity")

func test_slots(worlds: RefCounted) -> void:
 fixture_legacy(worlds)
 var first: Dictionary = worlds.paths(0)
 var second: Dictionary = worlds.paths(1)
 check(Auth.bootstrap(PackedStringArray([first.directory, second.directory])).error == OK, "bootstrap")
 fixture_journal(first.garden, first.character)
 var before := file_hash(first.garden + ".transaction")
 test_result("pending_import", worlds.prepare_guarded(), "pending_recovery")
 check(file_hash(first.garden + ".transaction") == before and file_hash(first.garden) == "absent", "pending import preserved evidence")
 test_result("pending_replacement", worlds.new_game_guarded(0, true), "pending_recovery")
 check(Ops.recover(PackedStringArray([first.character])).value.verified, "recover fixture")
 var lease_scratch: String = first.directory.path_join("session.cfg.tmp")
 check(Batch.write_bytes(lease_scratch, "unresolved lease".to_utf8_buffer()) == OK, "lease scratch fixture")
 var lease_before := file_hash(lease_scratch)
 var refused := test_result("lease_scratch_blocks_legacy_import", worlds.prepare_guarded(), "unresolved")
 check(refused.reason == "lease_publication_pending" and file_hash(first.garden) == "absent" and file_hash(lease_scratch) == lease_before,
  "legacy import preserves unresolved lease and canonical absence")
 check(DirAccess.remove_absolute(lease_scratch) == OK, "dispose lease scratch fixture")
 var deletion_scratch: String = first.directory.path_join("deleted.cfg.tmp")
 check(Batch.write_bytes(deletion_scratch, "unresolved tombstone".to_utf8_buffer()) == OK, "tombstone scratch fixture")
 var deletion_before := file_hash(deletion_scratch)
 var blocked_import := test_result("tombstone_scratch_blocks_legacy_import", worlds.prepare_guarded(), "unresolved")
 var blocked_create := test_result("tombstone_scratch_blocks_fresh_pair", worlds.new_game_guarded(0), "unresolved")
 check(blocked_import.reason == "deletion_publication_pending" and blocked_create.reason == blocked_import.reason
  and file_hash(first.garden) == "absent" and file_hash(first.character) == "absent" and file_hash(deletion_scratch) == deletion_before,
  "pending tombstone blocks import and creation without touching recovery evidence")
 check(DirAccess.remove_absolute(deletion_scratch) == OK, "dispose tombstone scratch fixture")
 test_result("legacy_import", worlds.prepare_guarded(), "completed")
 for pair in [[worlds.legacy_garden, first.garden], [worlds.legacy_character, first.character], [worlds.legacy_guest, second.character]]:
  check(file_hash(pair[0]) == file_hash(pair[1]), "import preserved exact source bytes")
 test_result("ensure_character", worlds.ensure_character_guarded(2), "completed")
 test_result("fresh_garden", worlds.new_world_guarded(2), "completed")
 var original := file_hash(first.garden)
 test_result("replacement_requires_confirmation", worlds.new_game_guarded(0), "verified_failure")
 test_result("world_replacement_requires_confirmation", worlds.new_world_guarded(0), "verified_failure")
 check(file_hash(first.garden) == original, "occupied Garden unchanged")
 test_result("remember_garden", worlds.remember_slot_guarded(2), "completed")
 check(worlds.last_slot() == 2, "Garden selection persisted")

func test_roster(worlds: RefCounted) -> void:
 var roster := Roster.new()
 # Start with the two duplicate source identities, then introduce a distinct
 # third source for the destination drift probe.
 check(DirAccess.remove_absolute(worlds.paths(2).character) == OK, "reset disposable third source")
 test_result("roster_import", roster.prepare_guarded(worlds), "completed")
 check(roster.summary(0).name == "Old Wanderer" and not roster.summary(1).exists, "legacy identities deduplicated")
 var catalog: String = roster.root_path.path_join("catalog.cfg")
 var info := ConfigFile.new()
 check(info.load(catalog) == OK and info.has_section_key("imports", worlds.paths(0).character), "import mapping")
 info.set_value("deleted_identities", "test", "preserve")
 check(info.save(catalog) == OK, "deletion record fixture")
 test_result("fresh_roster", roster.create_guarded(1, "New Wanderer", 1, []), "completed")
 var identity: String = roster.summary(1).identity
 test_result("update_roster", roster.update_guarded(1, "Renamed", 2, []), "completed")
 check(roster.summary(1).identity == identity and roster.summary(1).name == "Renamed", "edit preserves identity")
 test_result("capacity", roster.set_capacity_guarded(4), "completed")
 test_result("roster_preference", roster.remember_guarded(3), "completed")
 check(info.load(catalog) == OK and info.has_section_key("imports", worlds.paths(0).character) and info.has_section_key("deleted_identities", "test") and roster.last_slot() == 3 and roster.count() == 4, "catalog read-modify-write preserves records")
 test_result("claim_roster", roster.claim_guarded(1), "completed")
 test_result("heartbeat_roster", roster.heartbeat_guarded(1), "completed")
 test_result("release_roster", roster.release_guarded(1), "completed")
 var profile_path: String = roster.paths(1).character
 var profile_data := ConfigFile.new()
 check(profile_data.load(profile_path) == OK, "load disposable roster profile")
 profile_data.erase_section_key("character", "identity")
 check(profile_data.save(profile_path) == OK, "remove disposable roster identity")
 var missing_identity := file_hash(profile_path)
 var unverified := test_result("update_requires_saved_identity", roster.update_guarded(1, "Blocked", 2, []), "verified_failure")
 check(unverified.reason == "roster_identity_unverified" and file_hash(profile_path) == missing_identity,
  "edit leaves unidentified profile bytes intact")
 profile_data.set_value("character", "identity", identity)
 check(profile_data.save(profile_path) == OK, "restore disposable roster identity")
 var roster_scratch := profile_path.get_base_dir().path_join("session.cfg.tmp")
 check(Batch.write_bytes(roster_scratch, "unresolved roster lease".to_utf8_buffer()) == OK, "roster lease scratch fixture")
 var roster_scratch_hash := file_hash(roster_scratch)
 var before_edit := file_hash(profile_path)
 var blocked_edit := test_result("lease_scratch_blocks_roster_edit", roster.update_guarded(1, "Blocked", 2, []), "unresolved")
 check(blocked_edit.reason == "lease_publication_pending" and file_hash(profile_path) == before_edit and file_hash(roster_scratch) == roster_scratch_hash,
  "roster edit preserves profile and unresolved lease bytes")
 check(DirAccess.remove_absolute(roster_scratch) == OK, "dispose roster lease scratch fixture")

 test_result("third_legacy_source", worlds.ensure_character_guarded(2), "completed")
 var source: String = worlds.paths(2).character
 var candidate := roster._import_candidate(source)
 check(candidate.get("slot") == 2, "initial vacant destination")
 test_result("occupy_destination", roster.create_guarded(2, "Occupied", 0, []), "completed")
 var occupied: String = roster.paths(2).character
 var before := file_hash(occupied)
 var drift := test_result("changed_destination", roster._import_guarded(source, 2, candidate), "busy")
 check(drift.reason == "roster_import_selection_changed" and file_hash(occupied) == before, "changed destination refusal")
 var pending_path := roster._slot_profile(3)
 fixture_journal(source, pending_path)
 var evidence := file_hash(source + ".transaction")
 test_result("roster_import_pending_missing_destination", roster._import_guarded(source, 2), "pending_recovery")
 test_result("roster_create_pending_missing_destination", roster.create_guarded(3, "Blocked", 0, []), "pending_recovery")
 check(file_hash(pending_path) == "absent" and file_hash(source + ".transaction") == evidence, "pending roster cannot become a vacant destination")
 check(Ops.recover(PackedStringArray([pending_path])).value.verified, "recover pending roster fixture")
 test_result("fill_roster", roster.create_guarded(3, "Full roster", 0, []), "completed")
 var expanded_path := roster._slot_profile(4)
 var catalog_before_expansion := file_hash(catalog)
 var partial := test_result("capacity_published_before_import_abort", roster._import_guarded(source, 2, {}, func(phase, _path):
  return ERR_CANT_CREATE if phase == "replace" else OK), "partial_completion")
 check(partial.capacity_expanded and partial.partial and partial.outcome.outcome == "ABORTED_RESTORED",
  "profile abort retains the separately committed capacity result")
 check(roster.count() == 5 and file_hash(catalog) != catalog_before_expansion and file_hash(expanded_path) == "absent",
  "catalog growth survives without a partially installed profile")
 check(info.load(catalog) == OK and not info.has_section_key("imports", source), "no import mapping on abort")
 var retried := test_result("roster_import_retries_after_capacity_growth", roster.prepare_guarded(worlds), "completed")
 check(retried.imported == 1 and roster.count() == 5 and roster.summary(4).exists, "retry uses exact next slot")
 var current_catalog := file_hash(catalog)
 var scratch := FileAccess.open(catalog + ".tmp", FileAccess.WRITE)
 check(scratch != null, "interrupted catalog fixture")
 if scratch != null:
  scratch.store_string("unresolved catalog data")
  scratch.close()
 var scratch_hash := file_hash(catalog + ".tmp")
 test_result("catalog_scratch_blocks_update", roster.set_capacity_guarded(6), "unresolved")
 test_result("catalog_scratch_blocks_import", roster.prepare_guarded(worlds), "unresolved")
 check(file_hash(catalog) == current_catalog and file_hash(catalog + ".tmp") == scratch_hash, "preserved catalog and unresolved scratch")
 check(DirAccess.remove_absolute(catalog + ".tmp") == OK, "dispose scratch fixture")
 print("CASE ", JSON.stringify({"case": "catalog_hashes", "run_id": OS.get_environment("MYSTICAL_VALIDATION_RUN"),
  "catalog": current_catalog, "unresolved_scratch": scratch_hash, "slot_four": file_hash(pending_path)}))

func test_developer() -> void:
 var dev := Slots.new()
 dev.root_path = "user://saves/developer-garden"
 test_result("prepare_developer", dev.prepare_guarded(false), "completed")
 test_result("create_developer", dev.new_game_guarded(0), "completed")
 test_result("developer_reset_requires_confirmation", dev.new_game_guarded(0), "verified_failure")
 var location := dev.paths(1)
 var failed_pair := dev._initialize_guarded(1, true, false, false, func(phase, path):
  if phase == "replace" and path == location.garden:
   return ERR_CANT_CREATE
  return ERR_FILE_CANT_WRITE if phase == "restore" else OK)
 var pending := test_result("unresolved_second_replacement", failed_pair, "unresolved")
 check(pending.outcome.outcome == "UNCERTAIN" and FileAccess.file_exists(location.garden + ".transaction"), "preserved unresolved journal")
 test_result("blocked_followup", dev.new_game_guarded(1), "pending_recovery")
 var recovered := Ops.recover(PackedStringArray([location.character]))
 check(recovered.value.verified and not FileAccess.file_exists(location.character) and not FileAccess.file_exists(location.garden), "restored vacant pair")
 test_result("retry_after_recovery", dev.new_game_guarded(1), "completed")

func test_leases(worlds: RefCounted) -> void:
 test_result("lease_claim", worlds.claim_guarded(0), "completed")
 var competitor := Slots.new()
 test_result("competing_claim", competitor.claim_guarded(0), "busy")
 test_result("stale_heartbeat", competitor.heartbeat_guarded(0), "verified_failure")
 test_result("stale_release", competitor.release_guarded(0), "verified_failure")
 test_result("owner_heartbeat", worlds.heartbeat_guarded(0), "completed")
 test_result("owner_release", worlds.release_guarded(0), "completed")
 var marker: String = worlds.paths(0).directory.path_join("session.cfg")
 var file := ConfigFile.new()
 file.set_value("session", "process_id", OS.get_process_id() + 1)
 file.set_value("session", "updated", Time.get_unix_time_from_system())
 check(file.save(marker) == OK, "foreign marker fixture")
 test_result("foreign_lease", worlds.claim_guarded(0), "busy")
 check(DirAccess.remove_absolute(marker) == OK, "remove fixture marker")

func run() -> void:
 var worlds := Slots.new()
 test_slots(worlds)
 test_roster(worlds)
 test_developer()
 test_leases(worlds)
 var integration = preload("res://persistence_writer_integration.gd")
 check(not integration.activation_status().allowed and integration.VERIFIED_WRITERS.is_empty(), "activation remains disabled")
 if not failed:
  print("PASS: guarded slot and roster management")
 quit(1 if failed else 0)
