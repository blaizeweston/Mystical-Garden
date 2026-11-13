extends SceneTree

const Operations = preload("res://persistence_operations.gd")
const Integration = preload("res://persistence_writer_integration.gd")
const Authorization = preload("res://persistence_authorization.gd")
const Planner = preload("res://persistence_recovery_plan.gd")
const Batch = preload("res://save_batch.gd")
const Progress = preload("res://progress.gd")
const Profile = preload("res://character_profile.gd")
const Slots = preload("res://save_slots.gd")
const Roster = preload("res://character_slots.gd")

const Garden = "user://saves/slot_1/garden.cfg"
const ProfilePath = "user://saves/characters/slot_1/character.cfg"
const OtherProfile = "user://saves/characters/slot_2/character.cfg"
const WorldMarker = "user://saves/slot_1/session.cfg"
const RosterMarker = "user://saves/characters/slot_1/session.cfg"
const Catalog = "user://saves/characters/catalog.cfg"
const Tombstone = "user://saves/slot_1/deleted.cfg"
const Sentinel = "user://.mystical-garden-persistence.lock"

var failed := false
var expired: RefCounted
var denied_callbacks := 0

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, message: String) -> void:
 if not condition:
  failed = true
  printerr("FAIL: ", message)

func record(id: String, result: Dictionary) -> void:
 var row := result.duplicate()
 row.case = id
 row.run_id = OS.get_environment("MYSTICAL_VALIDATION_RUN")
 print("CASE ", JSON.stringify(row))

func put(path: String, bytes: PackedByteArray) -> void:
 check(Batch.write_bytes(path, bytes) == OK, "fixture write " + path)

func manifest(path: String) -> Dictionary:
 var result := {}
 for name in DirAccess.get_directories_at(path):
  if path == "user://" and name in ["logs", "diagnostics"]:
   continue
  var child := path.path_join(name)
  result[child] = "directory"
  result.merge(manifest(child))
 for name in DirAccess.get_files_at(path):
  var child := path.path_join(name)
  if child != Sentinel:
   result[child] = FileAccess.get_sha256(child)
 return result

func must_not_run(_context: RefCounted) -> Error:
 denied_callbacks += 1
 return ERR_BUG

func check_block(id: String, outcome: Dictionary, error: Error, reason: String) -> void:
 check(not outcome.ran and outcome.error == error and outcome.reason == reason, id)
 record(id, outcome)

func test_activation(paths: PackedStringArray) -> void:
 var result := Integration.activation_status()
 check(not result.allowed and result.blockers.size() == Integration.REQUIRED_WRITERS.size() + 1, "every inventoried row blocks production")
 var before := manifest("user://")
 var blocked := Operations.run_production(paths, PackedStringArray(), must_not_run)
 check_block("production_disabled", blocked, ERR_UNAVAILABLE, "production_integration_incomplete")
 check(before == manifest("user://") and not FileAccess.file_exists(Sentinel), "activation check acquired a lock or wrote files")

func test_writers(paths: PackedStringArray, files: PackedStringArray) -> void:
 var empty := Operations.prepare(paths, files)
 check(empty.plan.state == "empty" and Operations.inspect(Garden).state == "empty", "disposable world starts empty")
 var guarded := Operations.run(paths, files, func(context):
  expired = context
  check_block("foreign_context", Operations.run_nested(RefCounted.new(), paths, must_not_run), ERR_UNAUTHORIZED, "operation_context_rejected")
  check_block("nested_scope_expansion", Operations.run_nested(context, PackedStringArray([OtherProfile]), must_not_run), ERR_UNAUTHORIZED, "nested_scope_rejected")
  check_block("unrelated_reentry", Operations.run(paths, files, must_not_run), ERR_BUSY, "operation_in_progress")

  var world := Slots.new()
  var created := Operations.run_nested(context, PackedStringArray([Garden, Garden + ".tmp"]), func(_context):
   return world.new_world(0))
  check(created.ran and created.value == OK, "nested world creation")
  var roster := Roster.new()
  var profile := Operations.run_nested(context, PackedStringArray([ProfilePath, ProfilePath + ".tmp", RosterMarker]), func(_context):
   return roster.create(0, "Guarded Wanderer", 0, []))
  check(profile.ran and profile.value == OK, "nested roster creation")
  var catalog := Operations.run_nested(context, PackedStringArray([ProfilePath, Catalog, Catalog + ".tmp"]), func(_context):
   return roster.set_capacity(4))
  check(catalog.ran and catalog.value == OK and roster.count() == 4, "nested roster catalog update")
  var lease := Operations.run_nested(context, PackedStringArray([Garden, WorldMarker, WorldMarker + ".tmp"]), func(_context):
   var claim := world.claim(0)
   if claim != OK:
    return claim
   world.heartbeat(0)
   check(world.is_active(0), "session remains active under operation lock")
   world.release(0)
   return OK)
  check(lease.ran and lease.value == OK and not world.is_active(0), "nested claim, heartbeat and release")

  var saved := Operations.run_nested(context, paths, func(_context):
   var garden := Progress.new()
   garden.path = Garden
   var character := Profile.new()
   character.path = ProfilePath
   var loaded := character.load_profile(false)
   if loaded != OK:
    return loaded
   var garden_saved := garden.save_garden()
   return character.save_profile() if garden_saved == OK else garden_saved)
  check(saved.ran and saved.value == OK, "standalone serializers reuse the outer context")
  return OK, empty)

 check(guarded.ran and guarded.error == OK and guarded.value == OK, "guarded writers finished")
 check(Operations.inspect(Garden).state == "healthy" and Operations.inspect(ProfilePath).state == "healthy", "passive inspection sees both saves")
 check_block("expired_context", Operations.run_nested(expired, paths, must_not_run), ERR_UNAUTHORIZED, "operation_context_rejected")
 record("guarded_world_roster_catalog_lease_serializers", guarded)

func test_refusals(paths: PackedStringArray, files: PackedStringArray) -> void:
 var before := manifest("user://")
 check_block("wrong_owner_metadata", Operations.run(paths, PackedStringArray(["user://saves/slot_2/session.cfg"]), must_not_run), ERR_INVALID_DATA, "auxiliary_outside_scope")
 check_block("unlisted_archive_destination", Operations.run(paths, PackedStringArray(["user://saves/slot_1/backups/old/garden.cfg"]), must_not_run), ERR_INVALID_DATA, "auxiliary_outside_scope")
 check_block("changed_destination", Operations.run(PackedStringArray([OtherProfile]), PackedStringArray(), must_not_run, Operations.prepare(paths, files)), ERR_BUSY, "operation_scope_changed")
 Batch.begin(Garden)
 check_block("foreign_batch", Operations.run(paths, files, must_not_run), ERR_BUSY, "save_batch_in_progress")
 Batch.cancel()
 var holding := Authorization.run(PackedStringArray([Garden]), func(_token):
  return Operations.run(paths, files, must_not_run))
 check(holding.error == OK and holding.ran, "competing boundary control")
 check_block("busy_root", holding.value, ERR_BUSY, "authorization_acquire_failed")
 check(before == manifest("user://"), "scope refusals changed save tree")

 var metadata_preview := Operations.prepare(paths, files)
 var partial := Authorization.run(metadata_preview.plan.authorization_paths, func(token):
  return Operations._run_locked(token, metadata_preview, must_not_run, {}))
 check(partial.ran and partial.error == OK, "partial scope probe held canonical authorization")
 check_block("incomplete_locked_scope", partial.value, ERR_UNAUTHORIZED, "incomplete_locked_scope")
 check(before == manifest("user://"), "partial scope refusal changed save tree")
 put(Tombstone, "[deletion]\narchive=\"fixture\"\n".to_utf8_buffer())
 before = manifest("user://")
 check_block("changed_metadata", Operations.run(paths, files, must_not_run, metadata_preview), ERR_INVALID_DATA, "prepared_observations_changed")
 check(before == manifest("user://"), "metadata refusal changed save tree")
 check(DirAccess.remove_absolute(Tombstone) == OK, "fixture tombstone removal")

 var foreign := ConfigFile.new()
 foreign.set_value("session", "process_id", OS.get_process_id() + 1)
 foreign.set_value("session", "updated", Time.get_unix_time_from_system())
 check(foreign.save(WorldMarker) == OK, "foreign session fixture")
 before = manifest("user://")
 check_block("foreign_lease", Operations.run(paths, files, must_not_run), ERR_BUSY, "foreign_session_lease")
 check(before == manifest("user://"), "foreign lease refusal changed save tree")
 check(DirAccess.remove_absolute(WorldMarker) == OK, "fixture lease removal")

func test_recovery(paths: PackedStringArray, files: PackedStringArray) -> void:
 var healthy := Operations.prepare(paths, files)
 var garden_only := PackedStringArray([Garden])
 var unlinked := Operations.prepare(garden_only)
 var journal_path := Garden + ".transaction"
 var journal := ConfigFile.new()
 journal.set_value("transaction", "entries", {
  ProfilePath: {"exists": true, "bytes": FileAccess.get_file_as_bytes(ProfilePath)},
 })
 journal.set_value("transaction", "committed", false)
 check(journal.save(journal_path) == OK, "disposable journal with omitted anchor and no links")
 var before := manifest("user://")
 check_block("changed_linked_participants", Operations.run(garden_only, PackedStringArray(), must_not_run, unlinked), ERR_BUSY, "operation_scope_changed")
 check_block("changed_recovery_plan", Operations.run(paths, files, must_not_run, healthy), ERR_INVALID_DATA, "prepared_observations_changed")
 var pending := Operations.prepare(PackedStringArray([ProfilePath]))
 check(pending.plan.state == "pending_recovery" and pending.plan.journal_anchors == PackedStringArray([Garden]), "reverse journal discovery and absent anchor entry")
 check(pending.plan.participants == PackedStringArray([ProfilePath, Garden]), "complete linked participant set")
 var blocked := Operations.run(PackedStringArray([ProfilePath]), PackedStringArray(), must_not_run, pending)
 check_block("valid_recovery_remains_pending", blocked, ERR_BUSY, "journal_found")
 record("linked_plan", {"participants": pending.plan.participants, "journal_anchors": pending.plan.journal_anchors, "state": pending.plan.state})
 check(before == manifest("user://"), "pending recovery rewrote canonical bytes or evidence")
 # Feed the original clean plan directly to the locked phase. This exercises
 # revalidation even when the change occurs after the outer preview was built.
 var locked := Authorization.run(healthy.plan.authorization_paths + files, func(token):
  return Operations._run_locked(token, healthy, must_not_run, {}))
 check(locked.ran and locked.error == OK, "locked revalidation test held native authorization")
 check_block("locked_plan_drift", locked.value, ERR_INVALID_DATA, "observations_changed")
 check(before == manifest("user://"), "locked refusal rewrote canonical bytes or evidence")
 var locked_unlinked := Authorization.run(unlinked.plan.authorization_paths, func(token):
  return Operations._run_locked(token, unlinked, must_not_run, {}))
 check(locked_unlinked.ran and locked_unlinked.error == OK, "locked participant probe held original authorization")
 check_block("locked_participant_drift", locked_unlinked.value, ERR_INVALID_DATA, "participant_set_changed")
 check(before == manifest("user://"), "linked participant refusal changed save tree")

 check(DirAccess.remove_absolute(journal_path) == OK, "fixture journal removal")
 var retry := Operations.run(paths, files, func(_context): return ERR_CANT_CREATE)
 check(retry.ran and retry.error == OK and retry.value == ERR_CANT_CREATE, "retry preserved callback error as a separate value")
 var release := Operations.run(paths, files, func(_context): return OK)
 check(release.ran and release.error == OK and release.value == OK, "boundary released after writer error")
 record("retry_and_release", release)

func run() -> void:
 var paths := PackedStringArray([Garden, ProfilePath])
 var files := PackedStringArray([Garden + ".tmp", ProfilePath + ".tmp", Catalog, Catalog + ".tmp", WorldMarker, WorldMarker + ".tmp", RosterMarker, Tombstone])
 test_activation(paths)
 var bootstrap := Authorization.bootstrap(PackedStringArray([Garden.get_base_dir(), ProfilePath.get_base_dir(), OtherProfile.get_base_dir()]))
 check(bootstrap.error == OK, "bootstrap disposable directories before preparing scope")
 test_writers(paths, files)
 test_refusals(paths, files)
 test_recovery(paths, files)
 check(denied_callbacks == 0, "refused operations never dispatched a mutation callback")
 if not failed:
  print("PASS: guarded persistence operation boundary")
 quit(1 if failed else 0)