extends SceneTree

const Auth = preload("res://persistence_authorization.gd")
const Plan = preload("res://persistence_recovery_plan.gd")
const Inspect = preload("res://persistence_save_inspection.gd")
const World = "user://saves/slot_1"
const Roster = "user://saves/characters/slot_3"
const Garden = World + "/garden.cfg"
const Character = Roster + "/character.cfg"
const Preview = "user://combat-balance-preview/saves/developer-garden/slot_2"
const Sentinel = "user://.mystical-garden-persistence.lock"
var failed := false

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, message: String) -> void:
 if not condition:
  failed = true
  printerr("FAIL: ", message)

func write(path: String, text: String) -> void:
 var output := FileAccess.open(path, FileAccess.WRITE)
 check(output != null, "fixture write " + path)
 if output != null:
  output.store_string(text)
  output.close()

func save_fixture(path: String, values: Dictionary) -> void:
 var config := ConfigFile.new()
 for section in values:
  for key in values[section]:
   config.set_value(section, key, values[section][key])
 check(config.save(path) == OK, "fixture config " + path)

func remove(path: String) -> void:
 check(DirAccess.remove_absolute(path) == OK, "fixture remove " + path)

func manifest(path: String) -> Dictionary:
 var result := {}
 for name in DirAccess.get_directories_at(path):
  var child := path.path_join(name)
  result[child] = "directory"
  result.merge(manifest(child))
 for name in DirAccess.get_files_at(path):
  var child := path.path_join(name)
  result[child] = FileAccess.get_sha256(child)
 return result

func emit_case(id: String, row: Dictionary) -> void:
 row.case = id
 row.run_id = OS.get_environment("MYSTICAL_VALIDATION_RUN")
 print("CASE ", JSON.stringify(row))

func passive(id: String, path: String, state: String, reason: String) -> Dictionary:
 var before := manifest("user://")
 var result := Inspect.garden(path) if path.get_file() == "garden.cfg" else Inspect.character(path)
 check(result.state == state and result.reason == reason, id + " state or reason")
 check(before == manifest("user://"), id + " changed files or directories")
 emit_case(id, result.duplicate(true))
 return result

func check_existing_directories() -> void:
 var archive := World + "/backups/archived"
 check(DirAccess.make_dir_recursive_absolute(archive) == OK, "fixture archive")
 write(archive + "/garden.cfg", "archived garden")
 write(Garden + ".transaction", "preserve journal")
 write(Character + ".txn_link", "preserve participant link")
 var before := manifest("user://")
 var result := Auth.bootstrap(PackedStringArray([World, Roster]))
 check(result.error == OK and result.value.created.is_empty(), "existing directories are reusable")
 check(before == manifest("user://"), "bootstrap left archive and recovery files untouched")
 emit_case("existing_artifacts_preserved", result)
 remove(Garden + ".transaction")
 remove(Character + ".txn_link")

func run() -> void:
 passive("empty_garden", Garden, "empty", "")
 passive("empty_roster", Character, "empty", "")
 check(not FileAccess.file_exists(Sentinel), "inspection did not acquire the lock")
 for path in ["user://", "user://other", World + "/../slot_2", "user://saves/SLOT_1",
              Garden, Garden + ".transaction", Character + ".txn_link",
              World + "/backups", World + "/backups/archive", "user://saves/characters/slot_129"]:
  var refused := Auth.bootstrap(PackedStringArray([World, path]))
  check(refused.error == ERR_INVALID_PARAMETER and not refused.ran, "refused " + path)
  check(not DirAccess.dir_exists_absolute(World), "invalid batch made no directories")
  emit_case("unsupported_bootstrap", {"path": path, "result": refused})
 check(not FileAccess.file_exists(Sentinel), "invalid input did not acquire the lock")

 var setup := Auth.bootstrap(PackedStringArray([World, Roster, Preview, World]))
 check(setup.ran and setup.error == OK and setup.value.created.size() == 8, "fresh supported directory tree")
 check(not FileAccess.file_exists(Garden) and not FileAccess.file_exists(Character), "no canonical files created")
 check(not FileAccess.file_exists(Garden + ".transaction") and not FileAccess.file_exists(Character + ".txn_link"), "no recovery artifacts created")
 emit_case("fresh_bootstrap", setup)
 var repeat := Auth.bootstrap(PackedStringArray([Roster, World, Preview]))
 check(repeat.error == OK and repeat.ran and repeat.value.created.is_empty(), "idempotent bootstrap")
 emit_case("idempotent_bootstrap", repeat)
 check_existing_directories()
 var plan := Plan.discover(PackedStringArray([Garden, Character]))
 var authorization := Auth.run(plan.authorization_paths, func(token):
  var denied := Auth.bootstrap(PackedStringArray(["user://saves/slot_2"]))
  check(denied.error == ERR_BUSY and not denied.ran, "no bootstrap inside a save token")
  return Plan.revalidate(plan, PackedStringArray([Garden, Character]), token).locked)
 check(authorization.ran and authorization.error == OK and authorization.value == true, "fresh plan authorized after bootstrap released")
 emit_case("new_file_authorization", authorization)

 var collision := "user://saves/characters/slot_4"
 write(collision, "unrelated regular file")
 var before_collision := manifest("user://")
 var blocked := Auth.bootstrap(PackedStringArray(["user://saves/slot_2", collision]))
 check(blocked.ran and blocked.error == ERR_INVALID_PARAMETER and blocked.value.created.is_empty(), "existing file blocks the whole preflight")
 check(before_collision == manifest("user://"), "collision did not create or overwrite anything")
 emit_case("directory_file_collision", blocked)
 remove(collision)
 var wrong_case := "user://saves/SLOT_2"
 check(DirAccess.make_dir_absolute(wrong_case) == OK, "existing case alias fixture")
 var case_alias := Auth.bootstrap(PackedStringArray(["user://saves/slot_2"]))
 check(case_alias.ran and case_alias.error == ERR_INVALID_PARAMETER and case_alias.value.created.is_empty(), "existing case alias refused")
 emit_case("directory_case_collision", case_alias)
 remove(wrong_case)

 save_fixture(Garden, {"garden": {"knowledge": 17, "plots_v2": [{"species": 0}, {}]}, "campaign": {"best_clear": 8}})
 var garden := passive("healthy_garden", Garden, "healthy", "")
 check(garden.summary == {"knowledge":17, "plots":2, "best":8}, "Garden summary semantics")
 var id := "0123456789abcdef0123456789abcdef"
 save_fixture(Character, {"character": {"identity": id, "progress": {"name":"Traveller", "active_class":1, "xp":[0, 90]}},
  "content": {"manifest": Inspect.Profile.ContentIDs.manifest()}})
 var character := passive("healthy_character", Character, "healthy", "")
 var legacy := Inspect.Profile.new()
 legacy.path = Character
 check(legacy.load_profile(false) == OK, "reference profile reads without recovery")
 check(character.summary.identity == legacy.identity and character.summary.name == legacy.data.name and
  character.summary.class_name == Inspect.Profile.Classes.DEFINITIONS[legacy.data.active_class].name and
  character.summary.level == Inspect.Profile.level(legacy.data.xp[legacy.data.active_class]), "profile projection matches persisted selection and identity")
 save_fixture(Character, {"character": {"identity":"legacy", "progress":{"name":"Legacy"}}})
 var no_id := passive("legacy_identity", Character, "healthy", "")
 check(no_id.summary.identity.is_empty() and no_id.summary.identity_pending, "legacy inspection does not generate an identity")

 var lease := World + "/session.cfg"
 save_fixture(lease, {"session":{"process_id":OS.get_process_id() + 1, "updated":Time.get_unix_time_from_system()}})
 var busy := passive("foreign_lease", Garden, "busy", "foreign_session_lease")
 check(busy.active, "foreign lease flagged active")
 save_fixture(lease, {"session":{"process_id":OS.get_process_id(), "updated":Time.get_unix_time_from_system()}})
 passive("same_process_lease", Garden, "busy", "active_session_lease")
 var empty_lease := Roster + "/session.cfg"
 save_fixture(empty_lease, {"session":{"process_id":OS.get_process_id(), "updated":Time.get_unix_time_from_system()}})
 remove(Character)
 var busy_empty := passive("claimed_missing_character", Character, "busy", "active_session_lease")
 check(busy_empty.exists == false and busy_empty.active, "claimed slot stays busy before the save exists")
 remove(empty_lease)
 remove(lease)

 var entries := {Garden: {"exists":true, "bytes":"old Garden".to_utf8_buffer()},
  Character: {"exists":true, "bytes":"old character".to_utf8_buffer()}}
 save_fixture(Garden + ".transaction", {"transaction":{"entries":entries, "committed":false}})
 var pending := passive("missing_recoverable_character", Character, "pending_recovery", "journal_found")
 check(pending.exists == false and pending.journal_anchors == PackedStringArray([Garden]), "absent participant remains pending")
 passive("pending_garden", Garden, "pending_recovery", "journal_found")
 save_fixture(Character + ".transaction", {"transaction":{"entries":entries, "committed":false}})
 passive("ambiguous_character", Character, "ambiguous", "overlapping_journals")
 remove(Character + ".transaction")
 remove(Garden + ".transaction")
 passive("invalid_path", "user://unsupported/garden.cfg", "invalid", "unsafe_participant")
 write(Garden, '[garden]\nknowledge=Object(RefCounted,)\n')
 passive("unsafe_config_constructor", Garden, "invalid", "unsafe_save_content")
 save_fixture(Garden, {"character":{"identity": id}})
 passive("invalid_garden_content", Garden, "invalid", "invalid_save_content")
 if not failed:
  print("PASS: directory bootstrap and passive save inspection")
 quit(1 if failed else 0)
