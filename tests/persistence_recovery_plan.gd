extends SceneTree

const Planner = preload("res://persistence_recovery_plan.gd")
const Authorization = preload("res://persistence_authorization.gd")
const GARDEN = "user://saves/slot_1/garden.cfg"
const PROFILE = "user://saves/characters/slot_2/character.cfg"
const OTHER = "user://saves/slot_2/garden.cfg"
const PREVIEW = "user://combat-balance-preview/saves/slot_1/garden.cfg"
const DEVELOPER = "user://saves/developer-garden/slot_1/garden.cfg"
const LEGACY = "user://character-local-guest.cfg"
var failed := false

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: ", message)

func write_text(path: String, body: String) -> void:
 var file := FileAccess.open(path, FileAccess.WRITE)
 check(file != null, "fixture write " + path)
 if file != null:
  file.store_string(body)
  file.close()

func remove(path: String) -> void:
 check(DirAccess.remove_absolute(path) == OK, "fixture remove " + path)

func journal(anchor: String, entries: Dictionary, committed := false) -> void:
 var config := ConfigFile.new()
 config.set_value("transaction", "entries", entries)
 config.set_value("transaction", "committed", committed)
 check(config.save(anchor + ".transaction") == OK, "fixture journal")

func old(value: String) -> Dictionary:
 return {"exists": true, "bytes": value.to_utf8_buffer()}

func manifest(path: String) -> Dictionary:
 var result := {}
 for child in DirAccess.get_directories_at(path):
  result[path.path_join(child)] = "directory"
  result.merge(manifest(path.path_join(child)))
 for child in DirAccess.get_files_at(path):
  var file := path.path_join(child)
  result[file] = FileAccess.get_sha256(file)
 return result

func report(id: String, plan: Dictionary) -> void:
 print("CASE ", JSON.stringify({"case": id, "run_id": OS.get_environment("MYSTICAL_VALIDATION_RUN"),
  "state": plan.state, "reason": plan.reason, "path": plan.path, "participants": plan.participants,
  "anchors": plan.journal_anchors, "locked": plan.locked, "recovery_ready": plan.recovery_ready}))

func preview(id: String, paths: Array, state: String, reason: String, participants := [], anchors := []) -> Dictionary:
 var before := manifest("user://")
 var result := Planner.discover(PackedStringArray(paths))
 check(before == manifest("user://"), id + " mutated the disposable root")
 check(result.state == state and result.reason == reason and not result.recovery_ready, id + " state or reason")
 if not participants.is_empty():
  var sorted := PackedStringArray(participants)
  sorted.sort()
  check(result.participants == sorted, id + " participants")
 if not anchors.is_empty():
  check(result.journal_anchors == PackedStringArray(anchors), id + " anchors")
 report(id, result)
 return result

func run() -> void:
 for path in [GARDEN, PROFILE, OTHER, PREVIEW, DEVELOPER]:
  check(DirAccess.make_dir_recursive_absolute(path.get_base_dir()) == OK, "fixture directories")
 preview("empty", [GARDEN, PROFILE], "empty", "", [GARDEN, PROFILE])
 preview("unsafe_request", ["user://saves/slot_1/../slot_2/garden.cfg"], "invalid", "unsafe_participant")
 write_text(GARDEN, "current garden")
 write_text(PROFILE, "current character")
 var healthy := preview("healthy", [PROFILE, GARDEN], "healthy", "", [GARDEN, PROFILE])
 check(Planner.discover(PackedStringArray([GARDEN, PROFILE, GARDEN])) == healthy, "deterministic deduplication")

 var entries := {GARDEN: old("old garden"), PROFILE: old("old profile")}
 journal(GARDEN, entries)
 write_text(PROFILE + ".txn_link", GARDEN + ".transaction")
 var pair := preview("direct_cross_directory", [PROFILE], "pending_recovery", "journal_found", [GARDEN, PROFILE], [GARDEN])
 check(pair.journals[0].entries[PROFILE].bytes == "old profile".to_utf8_buffer(), "preserved original bytes")
 remove(PROFILE + ".txn_link")
 preview("reverse_missing_link", [PROFILE], "pending_recovery", "journal_found", [GARDEN, PROFILE], [GARDEN])
 preview("disjoint_journal", [OTHER], "empty", "", [OTHER])
 remove(PROFILE)
 var absent := preview("recoverable_missing_profile", [PROFILE], "pending_recovery", "journal_found", [GARDEN, PROFILE], [GARDEN])
 check(absent.observed[PROFILE] == "absent", "recoverable profile still absent")
 var verified := Authorization.run(absent.authorization_paths, func(token):
  var before := manifest("user://")
  var plan := Planner.revalidate(absent, PackedStringArray([PROFILE]), token)
  check(before == manifest("user://"), "revalidation performed no writes")
  report("locked_same_plan", plan)
  return plan.recovery_ready)
 check(verified.ran and verified.error == OK and verified.value == true, "locked plan accepted")
 var foreign := Planner.revalidate(absent, PackedStringArray([PROFILE]), RefCounted.new())
 check(foreign.reason == "authorization_rejected", "foreign token refused")
 report("foreign_token", foreign)
 remove(GARDEN + ".transaction")

 journal(OTHER, {PROFILE: old("recover"), GARDEN: {"exists": false, "bytes": PackedByteArray()}}, true)
 write_text(PROFILE + ".txn_link", OTHER + ".transaction")
 var orphan_anchor := preview("anchor_outside_entries", [PROFILE], "pending_recovery", "journal_found", [PROFILE, GARDEN, OTHER], [OTHER])
 check(orphan_anchor.journals[0].committed and not orphan_anchor.journals[0].entries.has(OTHER), "committed marker and independent anchor")
 remove(PROFILE + ".txn_link")
 remove(OTHER + ".transaction")

 journal(PREVIEW, {DEVELOPER: old("dev"), LEGACY: old("legacy")})
 preview("preview_developer_and_legacy", [LEGACY], "pending_recovery", "journal_found", [PREVIEW, DEVELOPER, LEGACY], [PREVIEW])
 remove(PREVIEW + ".transaction")

 write_text(GARDEN + ".transaction", "[transaction]\nentries=garbage")
 preview("corrupt_journal", [PROFILE], "pending_recovery", "journal_syntax")
 remove(GARDEN + ".transaction")
 check(DirAccess.make_dir_absolute(GARDEN + ".transaction") == OK, "unreadable journal fixture")
 preview("unreadable_journal", [PROFILE], "pending_recovery", "unsafe_file")
 remove(GARDEN + ".transaction")
 journal(GARDEN, {"user://../outside.cfg": old("bad")})
 preview("unsafe_journal_target", [PROFILE], "invalid", "unsafe_journal_participant")
 remove(GARDEN + ".transaction")
 journal(GARDEN, {GARDEN: old("valid entry"), PROFILE: {"exists": false, "bytes": PackedByteArray([1])}})
 preview("bad_later_entry", [GARDEN], "pending_recovery", "absent_entry_has_bytes")
 remove(GARDEN + ".transaction")

 journal(GARDEN, entries)
 journal(OTHER, {PROFILE: old("conflict")})
 preview("overlap", [GARDEN], "ambiguous", "overlapping_journals", [PROFILE, GARDEN, OTHER], [GARDEN, OTHER])
 remove(OTHER + ".transaction")
 write_text(OTHER + ".txn_link", GARDEN + ".transaction")
 preview("foreign_link", [GARDEN], "ambiguous", "link_owner_mismatch", [PROFILE, GARDEN, OTHER])
 remove(OTHER + ".txn_link")
 remove(GARDEN + ".transaction")
 write_text(PROFILE + ".txn_link", OTHER + ".transaction")
 preview("dangling_link", [PROFILE], "pending_recovery", "dangling_or_unsafe_link", [PROFILE, OTHER])
 remove(PROFILE + ".txn_link")
 write_text(PROFILE + ".txn_stage", "orphan")
 preview("unowned_stage", [PROFILE], "pending_recovery", "unowned_artifact")
 remove(PROFILE + ".txn_stage")

 var marker := PROFILE.get_base_dir().path_join("session.cfg")
 var lease := ConfigFile.new()
 lease.set_value("session", "process_id", OS.get_process_id() + 1)
 lease.set_value("session", "updated", Time.get_unix_time_from_system())
 check(lease.save(marker) == OK, "foreign lease fixture")
 preview("foreign_lease", [PROFILE], "busy", "foreign_session_lease")
 remove(marker)
 preview("missing_parent", ["user://saves/slot_3/garden.cfg"], "empty", "")

 var candidate := preview("before_participant_change", [GARDEN], "healthy", "")
 journal(GARDEN, entries)
 var changed := Authorization.run(candidate.authorization_paths, func(token):
  var before := manifest("user://")
  var plan := Planner.revalidate(candidate, PackedStringArray([GARDEN]), token)
  check(before == manifest("user://"), "changed set revalidation performed no writes")
  report("locked_participants_changed", plan)
  return plan.reason == "participant_set_changed" and not plan.recovery_ready)
 check(changed.ran and changed.error == OK and changed.value == true, "changed participant set refused")
 remove(GARDEN + ".transaction")
 var changed_destination := Authorization.run(candidate.authorization_paths, func(token):
  var plan := Planner.revalidate(candidate, PackedStringArray([OTHER]), token)
  report("locked_destination_changed", plan)
  return plan.reason == "requested_paths_changed" and not plan.recovery_ready)
 check(changed_destination.ran and changed_destination.value == true, "changed destination refused")
 write_text(GARDEN, "different bytes at the same path")
 var changed_bytes := Authorization.run(candidate.authorization_paths, func(token):
  var plan := Planner.revalidate(candidate, PackedStringArray([GARDEN]), token)
  report("locked_bytes_changed", plan)
  return plan.reason == "observations_changed")
 check(changed_bytes.ran and changed_bytes.value == true, "changed bytes refused")
 if not failed:
  print("PASS: read-only persistence participant discovery and locked revalidation")
 quit(1 if failed else 0)
