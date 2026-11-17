extends SceneTree

const Session = preload("res://guarded_title_session.gd")
const Slots = preload("res://save_slots.gd")
const Roster = preload("res://character_slots.gd")
const Batch = preload("res://save_batch.gd")
const Ops = preload("res://persistence_operations.gd")
const Developer = preload("res://developer_mode.gd")
var failed := false

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: ", message)

func completed(boundary: Dictionary) -> bool:
 return Session.completed(Session.outcome(boundary))

func record(id: String, data: Dictionary) -> void:
 print("CASE ", id, " ", JSON.stringify(data))

func journal(anchor: String, participant: String) -> String:
 var config := ConfigFile.new()
 config.set_value("transaction", "entries", {participant: {"exists": true, "bytes": "original".to_utf8_buffer()}})
 config.set_value("transaction", "committed", false)
 var path := anchor + ".transaction"
 check(config.save(path) == OK, "journal fixture")
 return path

func lease_marker(path: String, pid: int, age: float) -> void:
 var cfg := ConfigFile.new()
 cfg.set_value("session", "process_id", pid)
 cfg.set_value("session", "updated", Time.get_unix_time_from_system() - age)
 check(cfg.save(path) == OK, "lease fixture")

func startup(menu: Node) -> void:
 var world = load("res://world.tscn").instantiate()
 var garden: String = menu.storage.paths(0).garden
 var profile: String = menu.characters.paths(0).character
 var marker := garden.get_base_dir().path_join("session.cfg")
 var profile_marker := profile.get_base_dir().path_join("session.cfg")
 world.progress.path = garden
 world.local_character.path = profile
 world.guest_character.path = profile
 var garden_digest := Slots._save_digest(garden)
 var profile_digest := Slots._save_digest(profile)
 var owner := Session.new()
 lease_marker(marker, OS.get_process_id() + 1, 0)
 var marker_hash := Slots._save_digest(marker)
 var refused := owner.start(world, menu.storage, 0, garden_digest, menu.characters, 0, profile_digest)
 check(refused.state == "busy" and Slots._save_digest(marker) == marker_hash and not FileAccess.file_exists(profile_marker),
  "failed Garden claim unwinds only newly claimed profile")
 check(Slots._save_digest(profile) == profile_digest and Slots._save_digest(garden) == garden_digest, "claim refusal preserves saves")
 lease_marker(marker, OS.get_process_id() + 1, 60)
 refused = owner.start(world, menu.storage, 0, "wrong-digest", menu.characters, 0, profile_digest)
 check(refused.reason == "stale_startup_confirmation" and not FileAccess.file_exists(marker) and not FileAccess.file_exists(profile_marker),
  "failed startup unwinds both acquired leases")
 check(Session.completed(owner.start(world, menu.storage, 0, garden_digest, menu.characters, 0, profile_digest)),
  "expired lease can be replaced")
 var competing := Session.new()
 refused = competing.start(world, menu.storage, 0, garden_digest, menu.characters, 0, profile_digest)
 check(refused.state == "busy" and owner.owns_leases(), "competing launch cannot release original owner")
 var renewed_before := Slots._save_digest(profile_marker)
 owner._heartbeat_at -= 2.0
 check(Session.completed(owner.tick()) and Slots._save_digest(profile_marker) != renewed_before, "owner renews original store instance")
 lease_marker(profile_marker, OS.get_process_id(), 60)
 var successor := Roster.new()
 check(completed(successor.claim_guarded(0)), "successor acquires expired profile")
 renewed_before = Slots._save_digest(profile_marker)
 owner._heartbeat_at -= 2.0
 check(not Session.completed(owner.tick()), "stale heartbeat refused")
 owner.release()
 check(Slots._save_digest(profile_marker) == renewed_before and not FileAccess.file_exists(marker), "release touches only owned markers")
 check(completed(successor.release_guarded(0)), "successor releases its profile")
 world.free()
 record("startup_claim_and_handoff", {"garden": garden_digest, "profile": profile_digest})

func staggered_heartbeat(menu: Node) -> void:
 var world = load("res://world.tscn").instantiate()
 var garden: String = menu.storage.paths(0).garden
 var profile: String = menu.characters.paths(0).character
 var garden_marker := garden.get_base_dir().path_join("session.cfg")
 var profile_marker := profile.get_base_dir().path_join("session.cfg")
 var garden_digest := Slots._save_digest(garden)
 var profile_digest := Slots._save_digest(profile)
 world.set_meta(&"experimental_terrain", true)
 world.progress.path = garden
 world.local_character.path = profile
 world.guest_character.path = profile
 var owner := Session.new()
 check(Session.completed(owner.start(world, menu.storage, 0, garden_digest, menu.characters, 0, profile_digest)),
  "experimental session owns both leases before renewal")
 var first_garden := Slots._save_digest(garden_marker)
 var first_profile := Slots._save_digest(profile_marker)
 owner._heartbeat_at -= 2.0
 owner._profile_heartbeat_at -= 2.0
 check(Session.completed(owner.tick()) and Slots._save_digest(garden_marker) != first_garden
  and Slots._save_digest(profile_marker) == first_profile, "simultaneously due experimental leases publish only the Garden marker first")
 var garden_after := Slots._save_digest(garden_marker)
 var evidence := journal(profile, profile)
 var journal_digest := Slots._save_digest(evidence)
 check(owner.tick().state == "pending_recovery" and Slots._save_digest(evidence) == journal_digest
  and Slots._save_digest(profile_marker) == first_profile and Slots._save_digest(garden_marker) == garden_after,
  "pending profile recovery refuses the second renewal and preserves the evidence and both markers")
 check(DirAccess.remove_absolute(evidence) == OK, "remove fixture-created journal")
 owner._profile_heartbeat_at -= 2.0
 check(Session.completed(owner.tick()) and Slots._save_digest(profile_marker) != first_profile
  and Slots._save_digest(garden_marker) == garden_after, "eligible profile renews separately")
 lease_marker(profile_marker, OS.get_process_id() + 1, 0)
 var foreign := Slots._save_digest(profile_marker)
 owner._heartbeat_at -= 2.0
 check(owner.tick().error == ERR_UNAUTHORIZED and Slots._save_digest(profile_marker) == foreign
  and Slots._save_digest(garden_marker) == garden_after, "foreign profile lease prevents either renewal")
 check(Slots._save_digest(garden) == garden_digest and Slots._save_digest(profile) == profile_digest,
  "experimental renewal only affects lease metadata")
 owner.release()
 check(Slots._save_digest(profile_marker) == foreign and not FileAccess.file_exists(garden_marker),
  "experimental shutdown releases only its own marker")
 check(DirAccess.remove_absolute(profile_marker) == OK, "remove fixture-created foreign marker")
 world.free()
 record("experimental_staggered_heartbeat", {"garden": garden_digest, "profile": profile_digest})

func run() -> void:
 var legacy := Slots.new()
 var old = preload("res://progress.gd").new()
 old.path = legacy.legacy_garden
 old.knowledge = 31
 check(old.save_garden() == OK, "legacy Garden seed")
 var traveler = preload("res://character_profile.gd").new()
 traveler.path = legacy.legacy_character
 traveler.data.name = "Legacy traveller"
 check(traveler.save_profile() == OK, "legacy profile seed")
 var menu = load("res://main_menu.tscn").instantiate()
 menu.guarded_persistence = true
 menu.restore_last_selection = false
 menu.restore_last_character = false
 menu.settings_path = "user://group3a-settings.cfg"
 root.add_child(menu)
 current_scene = menu
 check(menu.garden_summary(0).state == "healthy" and menu.garden_summary(0).knowledge == 31, "guarded legacy Garden import")
 check(menu.character_summary(0).state == "healthy" and menu.character_summary(0).identity == traveler.identity, "guarded roster preparation")
 check(menu.garden_summary(2).state == "empty" and menu.character_summary(2).state == "empty", "fresh slots selectable")
 var invalid_profile: String = menu.characters.paths(2).character
 check(DirAccess.make_dir_recursive_absolute(invalid_profile.get_base_dir()) == OK, "invalid profile parent")
 check(Batch._write_bytes(invalid_profile, "[other]\nignored=1\n".to_utf8_buffer()) == OK, "invalid profile seed")
 menu.select_character(2)
 check(menu.character_summary(2).state == "invalid" and menu.create_character_button.disabled, "invalid profile cannot be replaced")
 check(DirAccess.remove_absolute(invalid_profile) == OK, "dispose invalid profile fixture")
 menu.select_character(0)
 check(completed(menu.storage.new_world_guarded(1)), "guarded Garden creation")
 var selected_path: String = menu.storage.paths(0).garden
 var selected_profile: String = menu.characters.paths(0).character
 menu.select_slot(0)
 menu.new_game()
 var replacement_digest: String = menu.pending_world_digest
 old.path = selected_path
 old.knowledge = 33
 check(old.save_garden() == OK, "change after replacement selection")
 menu.confirmation.confirmed.emit()
 check(not replacement_digest.is_empty() and not menu.transitioning and menu.confirmation.visible
  and menu.garden_summary(0).knowledge == 33, "stale Garden replacement stays in dialog")
 menu.confirmation.hide()

 menu.select_character(2)
 menu.request_create_character()
 menu.create_character("Scout", 1, [])
 check(menu.character_summary(2).name == "Scout" and not menu.creator.visible, "guarded character create")
 menu.request_create_character()
 menu.create_character("Scout renamed", 2, [])
 check(menu.character_summary(2).name == "Scout renamed", "guarded character update")
 menu.request_delete_character()
 var edited: String = menu.characters.paths(2).character
 check(completed(menu.characters.update_guarded(2, "Changed", 1, [])), "change after deletion selection")
 var edited_hash := Slots._save_digest(edited)
 menu.character_deletion.confirmed.emit()
 check(menu.character_deletion.visible and Slots._save_digest(edited) == edited_hash, "stale roster confirmation preserved")
 menu.character_deletion.hide()
 menu.select_character(0)
 startup(menu)
 staggered_heartbeat(menu)

 var empty_garden: String = menu.storage.paths(2).garden
 check(DirAccess.make_dir_recursive_absolute(empty_garden.get_base_dir()) == OK, "journal parent")
 var proof := journal(empty_garden, empty_garden)
 var proof_hash := Slots._save_digest(proof)
 menu.select_slot(2)
 check(menu.garden_summary(2).state == "pending_recovery" and menu.new_button.disabled and menu.continue_button.disabled,
  "missing Garden with evidence is blocked")
 var other_anchor: String = menu.storage.paths(1).garden
 var overlap := journal(other_anchor, empty_garden)
 check(menu.garden_summary(2).state == "ambiguous", "overlap appears as ambiguous")
 check(DirAccess.remove_absolute(overlap) == OK, "dispose overlapping journal fixture")
 var missing_roster := journal(selected_profile, invalid_profile)
 check(DirAccess.remove_absolute(edited) == OK, "fixture missing profile")
 check(menu.character_summary(2).state == "pending_recovery" and Slots._save_digest(missing_roster) != "absent",
  "missing profile with reverse evidence is unavailable")
 check(DirAccess.remove_absolute(missing_roster) == OK, "dispose missing profile fixture")
 var profile_proof := journal(selected_profile, selected_profile)
 var profile_proof_hash := Slots._save_digest(profile_proof)
 check(menu.character_summary(0).state == "pending_recovery" and not menu.character_ready(), "profile browse is passive")
 menu.launch(false)
 check(current_scene == menu and not menu.transitioning and Slots._save_digest(profile_proof) == profile_proof_hash, "blocked launch preserves journal")
 var profile_overlap := journal(invalid_profile, selected_profile)
 check(menu.character_summary(0).state == "ambiguous", "profile overlap stays ambiguous")
 check(DirAccess.remove_absolute(profile_overlap) == OK and DirAccess.remove_absolute(profile_proof) == OK, "dispose roster fixture")
 menu.network_port = 0
 menu.request_ip_join()
 menu.launch(true)
 check(current_scene == menu and not menu.transitioning and menu.network_dialog.visible and Slots._save_digest(proof) == proof_hash
  and not FileAccess.file_exists(empty_garden), "Title Join failure does not load or recover unclaimed Garden")
 menu.network_dialog.dismiss()
 await process_frame
 check(DirAccess.remove_absolute(proof) == OK, "dispose Garden journal fixture")
 var scratch := empty_garden.get_base_dir().path_join("deleted.cfg.tmp")
 check(Batch._write_bytes(scratch, "unresolved publication".to_utf8_buffer()) == OK, "tombstone scratch")
 var scratch_hash := Slots._save_digest(scratch)
 menu.select_slot(2)
 check(menu.garden_summary(2).state == "pending_recovery" and menu.new_button.disabled and Slots._save_digest(scratch) == scratch_hash,
  "unpublished tombstone blocks an apparently vacant Garden")
 check(DirAccess.remove_absolute(scratch) == OK, "dispose scratch fixture")

 menu.select_slot(0)
 menu.new_game()
 menu.confirmation.confirmed.emit()
 var started = current_scene
 check(started != menu and started.has_meta(Session.META), "confirmed replacement launches through guarded title")
 if started == menu:
  quit(1)
  return
 check(started.progress.path == selected_path and started.progress.knowledge == 0 and started.local_character.identity == traveler.identity,
  "guarded launch retains roster assignment")
 started.return_to_main_menu()
 await process_frame
 menu = current_scene
 check(menu.guarded_persistence and menu.selected == 0 and menu.selected_character == 0
  and not menu.storage.is_active(0) and not menu.characters.is_active(0), "return preserves selection and releases title-owned leases")

 menu.select_slot(1)
 menu.request_delete_save()
 menu.deletion_confirmation.confirmed.emit()
 check(menu.garden_summary(1).state == "empty" and not menu.deletion_confirmation.visible, "Garden deletion completes before dialog closes")
 check(completed(menu.storage.new_game_guarded(1)) and completed(menu.storage.delete_save_guarded(1, true)), "pair deletion route")
 for state in ["committed_cleanup_pending", "partial_completion", "unresolved", "verified_failure"]:
  var inner := Ops.management_result(ERR_CANT_CREATE, "fixture", state)
  menu.deletion_confirmation.show()
  menu._finish_guarded_deletion(Session.outcome({"error": OK, "ran": true, "value": inner}), menu.deletion_confirmation, "DELETED")
  check(menu.deletion_confirmation.visible and menu.notice.text != "DELETED", state + " keeps dialog and withholds success")
  menu.deletion_confirmation.hide()
 menu.app_settings.values.developer_mode = true
 check(Developer.open_garden(menu, false) == OK, "guarded developer launch")
 var dev = current_scene
 check(dev.has_meta(Session.META) and dev.has_meta(Developer.WORLD_META), "Developer Garden lease handoff")
 var developer_path: String = dev.progress.path
 dev.progress.knowledge = 45
 dev.return_to_main_menu()
 await process_frame
 menu = current_scene
 menu.app_settings.values.developer_mode = true
 var dev_digest := Developer.reset_snapshot(menu)
 var reset_result := Developer.open_garden(menu, true, dev_digest)
 check(reset_result == OK, "guarded occupied developer reset: " + str(reset_result) + " " + menu.notice.text)
 if reset_result != OK:
  quit(1)
  return
 dev = current_scene
 check(dev.progress.path == developer_path and dev.progress.knowledge == 0, "reset uses same developer slot")
 dev.return_to_main_menu()
 await process_frame
 check(current_scene.guarded_persistence and Slots._save_digest(selected_path) != "absent", "return retains opt-in and original Garden")
 record("menu_and_developer", {"garden": selected_path, "profile": selected_profile, "developer": developer_path})
 check(not preload("res://persistence_writer_integration.gd").activation_status().allowed, "production remains disabled")
 if not failed:
  print("PASS: guarded title and session lifecycle")
 quit(1 if failed else 0)
