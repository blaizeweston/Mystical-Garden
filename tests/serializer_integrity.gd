extends SceneTree
const SessionCase = preload("res://tests/support/session_case.gd")

const Batch = preload("res://save_batch.gd")
const Ops = preload("res://persistence_operations.gd")
const Gate = preload("res://persistence_writer_integration.gd")
const Tx = preload("res://game_transaction.gd")
const Slots = preload("res://save_slots.gd")
const Garden = preload("res://progress.gd")
const Profile = preload("res://character_profile.gd")
const Settings = preload("res://app_settings.gd")
const Metrics = preload("res://game_metrics.gd")
const NetworkSession = preload("res://network_session.gd")
const G = "user://saves/slot_1/garden.cfg"
const P = "user://saves/characters/slot_1/character.cfg"
const GB = G + ".pre-content-v2.bak"
const PB = P + ".pre-content-v2.bak"
const Identity = "cc390ac1d0464c02a1ca4ec967e131ea"
var failed := false

class LegacyWorld extends Node:
 var weapon_attacks := preload("res://weapon_attack_queue.gd").new()
 var effect_timeline := preload("res://combat_effect_timeline.gd").new()
 var persistence_session := preload("res://guarded_title_session.gd").new()
 const HOST = 1
 var progress := Garden.new()
 var local_character := Profile.new()
 var guest_character := Profile.new()
 var players := {}
 var transaction_publishes := []
 var combat_events := []
 var rng := RandomNumberGenerator.new()
 var network_session := NetworkSession.new()
 var status := ""

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, message: String) -> void:
 if not condition:
  failed = true
  printerr("FAIL: ", message)

func state() -> Dictionary:
 var files := {}
 for path in [G, P]:
  for suffix in [""] + Ops.Planner.ARTIFACTS:
   files[path + suffix] = Slots._save_digest(path + suffix)
 var backups := [PB]
 for suffix in Ops.MIGRATION_BACKUPS:
  backups.append(G + suffix)
 for path in backups:
  files[path] = Slots._save_digest(path)
  files[path + ".tmp"] = Slots._save_digest(path + ".tmp")
 return files

func record(case_name: String, before: Dictionary, facts: Dictionary) -> void:
 print("CASE ", JSON.stringify({"case": case_name, "before": before, "after": state(), "facts": facts}))

func fixture_legacy() -> void:
 check(Ops.Authorization.bootstrap(PackedStringArray([G.get_base_dir(), P.get_base_dir()])).error == OK, "bootstrap")
 var garden := ConfigFile.new()
 garden.set_value("garden", "knowledge", 9)
 garden.set_value("garden", "stock_0", 3)
 garden.set_value("garden", "planted_0", true)
 check(garden.save(G) == OK, "legacy Garden fixture")
 var profile := ConfigFile.new()
 profile.set_value("character", "identity", Identity)
 profile.set_value("character", "progress", {"name": "Legacy keeper", "active_class": 0})
 check(profile.save(P) == OK, "legacy character fixture")

func launch() -> Node:
 set_meta(Gate.VALIDATION_ROUTE, true)
 var menu = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
 menu.import_legacy = false
 menu.restore_last_character = false
 menu.restore_last_selection = false
 root.add_child(menu)
 current_scene = menu
 check(menu.production_route and menu.guarded_persistence, "candidate title owns migration admission")
 menu.select_character(0)
 menu.select_slot(0)
 menu.continue_button.pressed.emit()
 check(current_scene != menu and SessionCase.has_guarded_session(current_scene), "guarded legacy save opened through title")
 return current_scene if current_scene != menu else null

func result_code(result: Dictionary) -> Batch.Finalization:
 return result.persistence.value.outcome

func flags(world: Node) -> Dictionary:
 var result := {"profile_content": world.local_character.needs_content_backup}
 for field in ["content", "growth", "research", "heart", "inventory", "altar", "plot"]:
  result[field] = world.progress.get("needs_" + field + "_backup")
 return result

func backup_fault(path: String) -> void:
 check(Batch._write_bytes(path + ".tmp", "unverified previous scratch".to_utf8_buffer()) == OK, "backup scratch fault")

func assert_refused(world: Node) -> void:
 var before := state()
 check(world.progress.save_garden() == ERR_UNAUTHORIZED and world.local_character.save_profile() == ERR_UNAUTHORIZED, "standalone canonical serializers refused")
 check(not world.progress.save_garden_guarded().ran and not world.local_character.save_profile_guarded().ran, "cannot acquire independent authorization")
 var forged := func(_path, _bytes): check(false, "forged stage called"); return OK
 check(world.progress._serialize_save(forged) == ERR_UNAUTHORIZED and world.local_character._serialize_save() == ERR_UNAUTHORIZED, "raw serializers require the actual owning stage")
 check(state() == before, "refusal preserves all files")

func legacy_first_error(world: Node) -> void:
 # Use unclaimed fixtures with the same serializer objects on the legacy route
 # before the guarded title takes ownership.
 var before := state()
 var rng: int = world.rng.state
 var result := Tx.run_gameplay(world, Tx.Scope.PAIR, func():
  world.progress.knowledge += 7
  world.rng.randf()
  var nested = Tx.run(world, func():
   check(world.progress.save_garden() == ERR_FILE_CANT_WRITE, "legacy early Garden copy rejection")
   check(world.local_character.save_profile() == OK, "legacy second serializer stages")
   return null)
  check(nested == null, "nested null business return")
  Batch.record_serializer_error(ERR_CANT_CREATE, P)
  check(Batch.failure == ERR_FILE_CANT_WRITE, "legacy first failure retained")
  return "success must not escape")
 check(not result.completed and result.value == false and world.progress.knowledge == 9, "legacy transaction propagates serializer failure and restores model")
 check(world.rng.state == rng, "legacy abort restores RNG")
 check(world.progress.needs_content_backup and world.local_character.needs_content_backup, "legacy abort retains both migration flags")
 check(state()[G] == before[G] and state()[P] == before[P] and state()[PB] == before[P], "legacy abort retains original canonical bytes and successful backup")
 check(state()[G + ".txn_stage"] == "absent" and state()[P + ".txn_stage"] == "absent", "legacy abort discards staging")
 record("legacy_first_serializer", before, {"completed":result.completed, "flags":flags(world), "feedback":result.notice})

func first_and_second(world: Node) -> void:
 var original := state()
 var initial := flags(world)
 var rng: int = world.rng.state
 for blocked in [GB, PB]:
  backup_fault(blocked)
  var before := state()
  var callback := func():
   world.progress.knowledge += 8
   world.players[1].character.name = "Tentative"
   world.rng.randf()
   var nested := Tx.run_guarded(world, func():
    var garden: Error = world.progress.save_garden()
    var profile: Error = world.local_character.save_profile()
    check(garden == (ERR_BUSY if blocked == GB else OK), "Garden serializer reports own result")
    check(profile == (ERR_BUSY if blocked == PB else OK), "profile serializer reports own result")
    Batch.record_serializer_error(ERR_CANT_CREATE, P)
    return null, Callable(), Tx.Scope.PAIR)
   check(nested.ran and nested.value == null, "nested operation reused owner")
   return true
  var result := Tx.run_gameplay(world, Tx.Scope.PAIR, callback)
  var final := result_code(result)
  check(not result.completed and final.outcome == Batch.Outcome.ABORTED_RESTORED and final.original_error == ERR_BUSY
   and final.failed_path == (G if blocked == GB else P), "guarded first error and failure location retained")
  check(world.progress.knowledge == 9 and world.players[1].character.name == "Legacy keeper" and world.rng.state == rng and flags(world) == initial, "abort restores data, RNG and flags")
  check(state()[G] == original[G] and state()[P] == original[P] and state()[blocked + ".tmp"] == before[blocked + ".tmp"]
   and state()[G + ".transaction"] == "absent", "abort preserves canonical bytes and refused scratch")
  check(not final.write_blocked, "a verified abort permits explicit retry after resolving the scratch")
  record("guarded_first" if blocked == GB else "guarded_second", before, {"error":final.original_error, "flags":flags(world), "retry_allowed":not final.write_blocked})
  check(DirAccess.remove_absolute(blocked + ".tmp") == OK, "remove disposable fault")

func interrupted(world: Node, mode: String) -> void:
 var before := state()
 world.set_meta(&"guarded_gameplay_test_fault", func(phase, path):
  if (mode == "before" and phase == "replace" and path == P) or (mode == "partial" and phase == "replace" and path == G):
   record("interruption_barrier", before, {"phase":phase, "flags":flags(world)})
   while true: OS.delay_msec(50)
  return OK)
 Tx.run_gameplay(world, Tx.Scope.PAIR, func():
  world.progress.knowledge = 77
  world.players[1].character.name = "Interrupted migration"
  return true)
 check(false, "interruption barrier was not reached")

func recover_and_retry() -> void:
 var before := state()
 var garden := Garden.new()
 var profile := Profile.new()
 garden.path = G
 profile.path = P
 var result := Ops.recover(PackedStringArray([P]))
 check(result.ran and result.value.verified, "B2 restart recovery")
 check(garden.load_garden_guarded().value == OK and profile.load_profile_guarded().value == OK, "reload recovered canonical bytes")
 check(garden.knowledge == 9 and garden.needs_content_backup and profile.needs_content_backup and profile.identity == Identity, "migration still due after recovery")
 check(state()[G] == before[GB] and state()[P] == before[PB], "recovery restores originals; backup originals intact")
 check(garden.save_garden_guarded().value.outcome.outcome == Batch.Outcome.COMMITTED and profile.save_profile_guarded().value.outcome.outcome == Batch.Outcome.COMMITTED, "standalone guarded migration retries")
 check(not garden.needs_content_backup and not profile.needs_content_backup and state()[GB] == before[GB] and state()[PB] == before[PB], "commit clears flags, not backups")
 record("restart_recovery_retry", before, {"recovery_verified":result.value.verified, "garden_flag":garden.needs_content_backup, "profile_flag":profile.needs_content_backup})

func timed_research() -> void:
 var garden := Garden.new()
 garden.path = "user://saves/slot_2/garden.cfg"
 check(Ops.Authorization.bootstrap(PackedStringArray([garden.path.get_base_dir()])).error == OK, "bootstrap timed migration")
 var old := ConfigFile.new()
 old.set_value("garden", "plots_v2", [])
 old.set_value("garden", "knowledge", 20)
 old.set_value("heart", "state", {"version":1, "spent":5, "paid":["flowering","infusion"], "active":"flowering"})
 check(old.save(garden.path) == OK and garden.load_garden_guarded().value == OK, "load legacy heart research")
 var target: String = garden.path + ".pre-immediate-heart-v3.bak"
 var original := FileAccess.get_file_as_bytes(garden.path)
 check(garden.needs_research_backup and not garden.needs_heart_backup, "heart version 1 requires only timed research conversion")
 check(Batch._write_bytes(target, "unverifiable backup".to_utf8_buffer()) == OK, "block publication with contradictory backup")
 var failed_save := garden.save_garden_guarded()
 check(failed_save.value.outcome.outcome == Batch.Outcome.ABORTED_RESTORED and failed_save.value.outcome.original_error == ERR_FILE_CORRUPT
  and garden.needs_research_backup and FileAccess.get_file_as_bytes(garden.path) == original
  and FileAccess.get_file_as_string(target) == "unverifiable backup", "backup contradiction preserves all evidence")
 check(DirAccess.remove_absolute(target) == OK and Batch._write_bytes(target + ".tmp", original) == OK, "replace fixture fault with verified interrupted backup")
 check(garden.save_garden_guarded().value.outcome.outcome == Batch.Outcome.COMMITTED and not garden.needs_research_backup
  and FileAccess.get_file_as_bytes(target) == original and not FileAccess.file_exists(target + ".tmp"), "matching scratch can safely publish and migration commits")
 var current := ConfigFile.new()
 check(current.load(garden.path) == OK and current.get_value("heart", "state", {}).get("version") == garden.heart.VERSION, "immediate research marker committed")
 check(garden.load_garden_guarded().value == OK and garden.knowledge == 20 and garden.heart.spent == 0 and not garden.heart.has("flowering"), "recovered migration retires free Flowering and releases the original five without increasing lifetime Knowledge")
 record("timed_research_backup", {}, {"canonical":Slots._save_digest(garden.path), "backup":Slots._save_digest(target),
  "original":Ops.Batch.Evidence.digest(original), "needs_research_backup":garden.needs_research_backup})

func first_open_migration() -> void:
 fixture_legacy()
 backup_fault(PB)
 var before := state()
 var world := launch()
 if world == null: return
 check(world.persistence_session.owns_leases() and world.progress.knowledge==9
  and world.local_character.identity==Identity,"Continue reads supported old saves under owned leases")
 var after := state()
 check(after[G]==before[G] and after[P]==before[P] and after[PB+".tmp"]==before[PB+".tmp"]
  and after[GB]==before[G] and after[G+".transaction"]=="absent" and after[P+".txn_stage"]=="absent",
  "startup backup fault preserves originals, exact Garden backup and conflicting profile evidence")
 check(world.progress.needs_content_backup and world.local_character.needs_content_backup
  and world.status.begins_with("Save cancelled") and not world.progress.garden_interactions.growth.seen.has(Identity),
  "failed first-open registration restores memory and does not report success")
 record("initial_continue_migration_abort",before,{"flags":flags(world),"feedback":world.status})
 check(DirAccess.remove_absolute(PB+".tmp")==OK,"remove only the fixture's conflicting scratch")
 world.return_to_main_menu()
 await process_frame
 check(current_scene!=world and root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,
  "return settles available migration and releases the session")
 world = launch()
 if world == null: return
 check(not flags(world).values().has(true) and world.local_character.identity==Identity
  and state()[GB]==before[G] and state()[PB]==before[P] and state()[G]!=before[G] and state()[P]!=before[P],
  "next title admission reads migrated bytes and preserves both originals")
 record("initial_continue_migration_retry",before,{"flags":flags(world)})
 world.return_to_main_menu()
 await process_frame
 for path in [G,P]:
  for suffix in Ops.MIGRATION_BACKUPS:
   if FileAccess.file_exists(path+suffix):
    check(DirAccess.remove_absolute(path+suffix)==OK,"remove only the initial-case backup")

func run() -> void:
 var mode := OS.get_environment("MYSTICAL_A1_MODE")
 if mode == "recover":
  recover_and_retry()
  finish()
  return
 if mode.is_empty():
  await first_open_migration()
 fixture_legacy()
 # Startup registers the host's growth receipt and can commit the migration.
 # Start on current saves, then install and load controlled older bytes under
 # the fixture's existing ownership so each tested action owns its first save.
 var garden := Garden.new()
 garden.path = G
 check(garden.load_garden(false) == OK and garden.save_garden_guarded().value.outcome.outcome == Batch.Outcome.COMMITTED, "prepare current Garden")
 var profile := Profile.new()
 profile.path = P
 check(profile.load_profile(false) == OK and profile.save_profile_guarded().value.outcome.outcome == Batch.Outcome.COMMITTED, "prepare current profile")
 var world := launch()
 if world == null:
  quit(1)
  return
 await process_frame
 fixture_legacy()
 for suffix in Ops.MIGRATION_BACKUPS:
  if FileAccess.file_exists(G + suffix):
   check(DirAccess.remove_absolute(G + suffix) == OK, "reset disposable Garden backup")
 if FileAccess.file_exists(PB):
  check(DirAccess.remove_absolute(PB) == OK, "reset disposable profile backup")
 check(world.progress.load_garden(false) == OK and world.local_character.load_profile(false) == OK, "load fixture migration state without recovery")
 world.players[1].character = world.local_character.data
 if mode in ["before", "partial"]:
  interrupted(world, mode)
  finish()
  return
 assert_refused(world)
 first_and_second(world)
 var before := state()
 world.set_meta(&"guarded_gameplay_test_fault", func(phase, path):
  if phase == "replace" and path == G: return ERR_CANT_CREATE
  return ERR_FILE_CANT_WRITE if phase == "restore" else OK)
 var uncertain := Tx.run_gameplay(world, Tx.Scope.PAIR, func():
  world.progress.knowledge = 27
  world.players[1].character.name = "Tentative"
  return null)
 var final := result_code(uncertain)
 check(final.outcome == Batch.Outcome.UNCERTAIN and final.write_blocked and world.progress.knowledge == 27 and world.progress.needs_content_backup and world.local_character.needs_content_backup, "uncertainty retains tentative state and migration flags")
 var split := state()
 check(split[G] == before[G] and split[P] != before[P] and split[GB] == before[G] and split[PB] == before[P] and split[G + ".transaction"] != "absent", "partial replacement and backups preserved")
 check(not Tx.run_gameplay(world, Tx.Scope.PAIR, func(): check(false, "uncertain replay")).completed and state() == split, "uncertainty refuses further writes")
 record("uncertain_migration", before, {"outcome":final.outcome, "flags":flags(world), "notice":uncertain.notice})
 world.return_to_main_menu()
 await process_frame
 check(Ops.recover(PackedStringArray([P])).value.verified, "explicit reconciliation")
 world = launch()
 if world == null:
  quit(1)
  return
 before = state()
 world.set_meta(&"guarded_gameplay_test_fault", func(phase, _path): return ERR_CANT_CREATE if phase == "publish_receipt" else OK)
 var committed := Tx.run_gameplay(world, Tx.Scope.PAIR, func():
  var settings := Settings.new()
  settings.path = "user://missing/settings.cfg"
  check(settings.save_settings(settings.values) != OK, "isolated preference failure")
  var metric_path := Metrics.path
  Metrics.path = "user://missing/metrics.jsonl"
  Metrics.record("fixture_only")
  Metrics.path = metric_path
  world.progress.knowledge = 37
  world.players[1].character.name = "Migrated keeper"
  return false)
 final = result_code(committed)
 check(committed.completed and committed.value == false and final.outcome == Batch.Outcome.COMMITTED_CLEANUP_PENDING
  and world.persistence_session.pending_notice() == Tx.CLEANUP_NOTICE and world.progress.knowledge == 37, "cleanup pending remains committed with false business value and warning")
 check(not world.progress.needs_content_backup and not world.local_character.needs_content_backup and not world.progress.needs_plot_backup, "committed cleanup pending clears migration flags")
 check(state()[GB] == before[GB] and state()[PB] == before[PB] and state()[G] != before[G] and state()[P] != before[P], "confirmed canonical bytes and original backups")
 record("committed_migration_cleanup_pending", before, {"outcome":final.outcome, "flags":flags(world), "notice":committed.notice})
 world.return_to_main_menu()
 await process_frame
 check(Ops.recover(PackedStringArray([G])).value.verified, "committed cleanup")
 world = launch()
 if world == null:
  quit(1)
  return
 before = state()
 check(not flags(world).values().has(true) and world.progress.knowledge == 37 and world.local_character.identity == Identity, "already migrated reload")
 check(Tx.run_gameplay(world, Tx.Scope.PAIR, func(): return null).completed and state()[GB] == before[GB] and state()[PB] == before[PB], "subsequent save preserves original backups")
 world.return_to_main_menu()
 await process_frame
 fixture_legacy()
 var legacy := LegacyWorld.new()
 legacy.progress.path = G
 legacy.local_character.path = P
 check(legacy.progress.load_garden(false) == OK and legacy.local_character.load_profile(false) == OK, "legacy fixture load")
 check(DirAccess.remove_absolute(GB) == OK and DirAccess.make_dir_absolute(GB) == OK, "directory blocks legacy backup copy")
 legacy_first_error(legacy)
 check(DirAccess.remove_absolute(GB) == OK, "remove legacy backup fault")
 check(Tx.run_gameplay(legacy, Tx.Scope.PAIR, func(): return null).completed and not legacy.progress.needs_content_backup and not legacy.local_character.needs_content_backup, "legacy explicit retry finalizes migration")
 legacy.free()
 timed_research()
 finish()

func finish() -> void:
 if not failed:
  print("PASS: serializer errors, migration integrity and verified retries")
 quit(1 if failed else 0)
