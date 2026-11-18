extends SceneTree
const Gate = preload("res://persistence_writer_integration.gd")
const Location = preload("res://persistence_root.gd")
var failed := false
var checks := 0

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failed = true
  printerr("FAIL AC-06 cutover: ",label)

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 if "--root-roundtrip" in OS.get_cmdline_user_args():
  native_roundtrip()
  return
 if "--migration-admit" in OS.get_cmdline_user_args():
  await migrated_admission()
  return
 check(not Gate.activation_status().allowed and not Gate.default_route(self),"production stays inactive")
 var all_writers: Array = Gate.REQUIRED_WRITERS.keys()
 var requirements := {}
 for key in Gate.CUTOVER_REQUIREMENTS: requirements[key] = "fixture evidence only"
 check(Gate.evaluate_activation(true,all_writers,requirements).allowed,"complete sign-off can satisfy the gate")
 check(not Gate.evaluate_activation(false,all_writers,requirements).allowed,"approval is independent")
 for writer in all_writers:
  var selected := all_writers.duplicate()
  selected.erase(writer)
  check(Gate.evaluate_activation(true,selected,requirements).blockers.has(writer),"each writer is required: "+writer)
 for requirement in Gate.CUTOVER_REQUIREMENTS:
  var selected := requirements.duplicate()
  selected.erase(requirement)
  check(Gate.evaluate_activation(true,all_writers,selected).blockers.has(requirement),"each deployment requirement is required")
  selected[requirement] = " "
  check(not Gate.evaluate_activation(true,all_writers,selected).allowed,"empty evidence is not sign-off")
  selected[requirement] = true
  check(not Gate.evaluate_activation(true,all_writers,selected).allowed,"a boolean is not evidence")
 var config := Location.policy()
 var roaming := "C:/disposable/profile/AppData/Roaming"
 var account := "C:/disposable/profile"
 var destination: String = roaming.path_join(config.root_name)
 check(Location.location_error(destination,roaming,account,config.root_name).is_empty(),"separate root accepted")
 check(not Location.location_error(roaming.path_join("Mystical Garden Prototype"),roaming,account,config.root_name).is_empty(),"old physical root refused")
 check(not Location.location_error(destination,roaming,account,"Mystical Garden Prototype").is_empty(),"old project setting refused")
 check(not Location.location_error("//server/share/"+config.root_name,"//server/share",account,config.root_name).is_empty(),"UNC root refused")
 check(not Location.location_error(destination,roaming,"C:/different-profile",config.root_name).is_empty(),"redirected account root refused")
 var marker := {"schema":1,"root_name":config.root_name,"origin":"fresh","policy_sha256":Location.policy_digest()}
 check(Location.valid_marker(marker),"fresh root identity")
 marker.origin = "migration"
 marker.manifest_sha256 = "a".repeat(64)
 check(Location.valid_marker(marker),"reviewed migration identity")
 marker.manifest_sha256 = "stale"
 check(not Location.valid_marker(marker),"bad manifest identity refused")
 marker.manifest_sha256 = "a".repeat(64)
 marker.policy_sha256 = "0".repeat(64)
 check(not Location.valid_marker(marker),"old root policy refused")
 # This registered fixture uses the ordinary disposable Prototype root, so the
 # production guard must fail before it opens a sentinel or creates an identity.
 var marker_path: String = "user://" + str(config.marker)
 check(not FileAccess.file_exists(marker_path),"fixture begins without a guarded marker")
 check(not Location.prepare().is_empty(),"unapproved old-root location is refused")
 check(not FileAccess.file_exists(marker_path),"refusal creates no identity")
 check(not Gate.PRODUCTION_CUTOVER_APPROVED and Gate.VERIFIED_WRITERS.is_empty() and Gate.VERIFIED_REQUIREMENTS.is_empty(),"no acceptance claims or activation added")
 if not failed: print("PASS: AC-06 cutover readiness ",checks," checks")
 quit(1 if failed else 0)

# Also used by the explicit alternate-root rehearsal. The registered normal
# fixture never changes its project settings or selects a real save root.
func native_roundtrip() -> void:
 var actual := OS.get_user_data_dir().replace("\\", "/")
 check(DisplayServer.get_name() == "headless" and actual.contains("/.godot/vd/")
  and not OS.get_environment("MYSTICAL_VALIDATION_RUN").is_empty(),"verified disposable native root")
 if failed:
  quit(1)
  return
 var config := Location.policy()
 var path: String = "user://" + str(config.marker)
 check(Location.prepare().is_empty(),"native gate initializes a fresh guarded root")
 var original := FileAccess.get_file_as_bytes(path)
 check(Location.valid_marker(JSON.parse_string(original.get_string_from_utf8())),"native root identity readback")
 check(Location.prepare().is_empty() and FileAccess.get_file_as_bytes(path) == original,"native retry preserves root identity")
 var change := func(bytes: PackedByteArray):
  return Location.Auth.run_legacy(PackedStringArray([path]),func(_token):
   var file := FileAccess.open(path,FileAccess.WRITE)
   if file == null: return FileAccess.get_open_error()
   var stored := file.store_buffer(bytes)
   file.flush()
   return OK if stored and file.get_error() == OK else ERR_FILE_CANT_WRITE)
 var invalid: Dictionary = change.call("{malformed".to_utf8_buffer())
 check(invalid.error == OK and invalid.value == OK,"disposable malformed marker injected")
 check(not Location.prepare().is_empty() and FileAccess.get_file_as_string(path) == "{malformed","invalid identity retained and refused")
 var restored: Dictionary = change.call(original)
 check(restored.error == OK and restored.value == OK and Location.prepare().is_empty(),"explicit fixture restoration reopens the same identity")
 # An existing save set without a root identity must never be silently adopted.
 check(DirAccess.remove_absolute(path) == OK,"fixture temporarily removes only its marker")
 check(DirAccess.dir_exists_absolute("user://saves") or DirAccess.make_dir_absolute("user://saves") == OK,"fixture creates an unmarked save directory")
 check(not Location.prepare().is_empty() and not FileAccess.file_exists(path),"unmarked existing saves refused without mutation")
 if not failed: print("PASS: AC-06 native root roundtrip ",checks," checks ",actual)
 quit(1 if failed else 0)

func migrated_admission() -> void:
 var actual := OS.get_user_data_dir().replace("\\", "/")
 check(DisplayServer.get_name() == "headless" and actual.contains("/.godot/vd/")
  and not OS.get_environment("MYSTICAL_VALIDATION_RUN").is_empty(),"verified disposable migration destination")
 if failed:
  quit(1)
  return
 check(Location.prepare().is_empty(),"copied root identity accepted by native gate")
 var marker: String = "user://" + str(Location.policy().marker)
 var original := FileAccess.get_file_as_bytes(marker)
 var profile_path := "user://saves/characters/slot_1/character.cfg"
 var garden_path := "user://saves/slot_1/garden.cfg"
 check(FileAccess.file_exists(profile_path) and FileAccess.file_exists(garden_path),"real disposable profile and Garden copied")
 set_meta(Gate.VALIDATION_ROUTE,true)
 var menu = load("res://main_menu.tscn").instantiate()
 root.add_child(menu)
 current_scene = menu
 check(menu.production_route and menu.guarded_persistence,"normal title selects the candidate route")
 menu.select_character(0)
 menu.select_slot(0)
 menu.continue_game()
 var world := current_scene
 check(world != menu and world.persistence_session.is_guarded(),"guarded Continue loads the migrated pair")
 if world == menu:
  quit(1)
  return
 check(world.persistence_session.can_write(),"migrated session owns its valid leases")
 var world_id: int = world.get_instance_id()
 world.return_to_main_menu()
 await process_frame
 check(is_instance_valid(current_scene) and current_scene.get_instance_id() != world_id and not FileAccess.file_exists(garden_path.get_base_dir().path_join("session.cfg"))
  and not FileAccess.file_exists(profile_path.get_base_dir().path_join("session.cfg")),"title return releases migrated leases")
 check(FileAccess.get_file_as_bytes(marker) == original,"gameplay does not rewrite migration identity")
 if not failed: print("PASS: AC-06 migrated title admission ",checks," checks ",actual)
 quit(1 if failed else 0)
