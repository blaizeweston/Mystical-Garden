extends SceneTree

const Integration = preload("res://persistence_writer_integration.gd")
const Authorization = preload("res://persistence_authorization.gd")
const Developer = preload("res://developer_mode.gd")
var failed := false

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, message: String) -> void:
 if not condition:
  failed = true
  printerr("FAIL: ",message)

func run() -> void:
 set_meta(Integration.VALIDATION_ROUTE,true)
 var title = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
 root.add_child(title)
 current_scene = title
 var expected: Array = []
 if OS.get_environment("MYSTICAL_VALIDATION_BACKEND") == "missing":
  expected = [
   'Condition "!FileAccess::exists(path)" is true. Returning: ERR_FILE_NOT_FOUND',
   "GDExtension dynamic library not found: 'res://assets/native/persistence_lock/persistence_lock.gdextension'.",
   "Error loading extension: 'res://assets/native/persistence_lock/persistence_lock.gdextension'.",
  ]
 set_meta(&"validation_expected_engine_errors", expected)
 check(ClassDB.class_exists(Authorization.BACKEND) == (OS.get_environment("MYSTICAL_VALIDATION_BACKEND") == "incompatible"), "specific unavailable backend loaded as intended")
 check(title.production_route and title.guarded_persistence and not title.production_backend_ready,"default route refuses unavailable/incompatible backend")
 check(title.notice.text.contains("persistence library") and title.new_button.disabled and title.join_button.disabled
  and title.continue_button.disabled and title.create_character_button.disabled,"explicit title failure")
 title.app_settings.values.developer_mode = true
 check(Developer.open_garden(title,false)==ERR_UNAVAILABLE,"Developer Garden refused")
 title.select_character(1)
 title.import_legacy_saves()
 title.new_game()
 title.join_game()
 check(current_scene==title and not DirAccess.dir_exists_absolute("user://saves")
  and not FileAccess.file_exists("user://"+Authorization.SENTINEL),"no authorization, directory bootstrap or fallback")
 print("CASE ",JSON.stringify({"case":"backend_refusal","backend":ClassDB.class_exists(Authorization.BACKEND),"notice":title.notice.text}))
 if not failed: print("PASS: default persistence fails closed without compatible native backend")
 quit(1 if failed else 0)
