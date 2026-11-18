extends RefCounted
## Physical deployment boundary, not gameplay or character progression state.
## Production activation is separate; no preference or CLI flag enables it.
const POLICY := "res://assets/content/save_cutover.json"
const Auth = preload("res://persistence_authorization.gd")
const Playtest = preload("res://playtest_storage.gd")

static func policy() -> Dictionary:
 var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(POLICY))
 if not value is Dictionary or value.get("schema") != 1 or value.get("marker") != "guarded-root.json" \
  or not value.get("root_name") is String \
  or not RegEx.create_from_string("\\AMystical Garden Guarded [1-9][0-9]*\\z").search(value.root_name):
  return {}
 return value

## Identity is semantic and independent of JSON formatting and operational limits.
static func policy_digest() -> String:
 var config := policy()
 if config.is_empty(): return ""
 return (str(int(config.schema)) + "\n" + str(config.root_name) + "\n" + str(config.marker)).sha256_text()

static func location_error(actual: String, roaming: String, profile: String, settings_name: String) -> String:
 var config := policy()
 if config.is_empty(): return "The guarded save-root policy is missing or unsupported."
 var root := actual.replace("\\", "/").trim_suffix("/")
 var parent := roaming.replace("\\", "/").trim_suffix("/")
 var account := profile.replace("\\", "/").trim_suffix("/")
 if not Auth._is_drive_absolute(parent) or not Auth._ordinary_components(parent.substr(3)) \
  or not Auth._is_drive_absolute(account) or parent.nocasecmp_to(account.path_join("AppData/Roaming")) != 0 \
  or settings_name != config.root_name or root.nocasecmp_to(parent.path_join(config.root_name)) != 0:
  return "Guarded saving requires its separate save folder. Older Garden saves were not opened."
 return ""

static func valid_marker(value: Variant) -> bool:
 if not value is Dictionary: return false
 var config := policy()
 if config.is_empty() or value.get("schema") != 1 or value.get("root_name") != config.root_name \
  or value.get("policy_sha256") != policy_digest(): return false
 if value.get("origin") == "fresh": return value.keys().size() == 4
 if value.get("origin") != "migration": return false
 var digest := RegEx.create_from_string("\\A[0-9a-f]{64}\\z")
 return value.keys().size() == 5 and value.get("manifest_sha256") is String \
  and digest.search(value.manifest_sha256) != null

## Runs before diagnostics/preferences/canonical bootstrap, only after approval.
## Missing markers can initialize a genuinely fresh root, never an existing save.
static func prepare() -> String:
 var refusal := location_error(OS.get_user_data_dir(), OS.get_environment("APPDATA"), OS.get_environment("USERPROFILE"),
  str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")))
 if not refusal.is_empty(): return refusal
 var path: String = "user://" + str(policy().marker)
 # Godot can create its own logfile before any autoload runs. It is the
 # only additional fresh-root file allowed and passes the same native gate.
 var paths := PackedStringArray([path])
 if FileAccess.file_exists("user://logs/godot.log"): paths.append("user://logs/godot.log")
 var result := Auth.run_legacy(paths, func(_token):
  if FileAccess.file_exists(path):
   var existing := FileAccess.open(path, FileAccess.READ)
   if existing == null or existing.get_length() > 4096: return ERR_INVALID_DATA
   var text := existing.get_as_text()
   var read_error := existing.get_error()
   existing.close()
   var parser := JSON.new()
   return OK if read_error == OK and parser.parse(text) == OK and valid_marker(parser.data) else ERR_INVALID_DATA
  var directory := DirAccess.open("user://")
  if directory == null: return ERR_CANT_OPEN
  directory.include_hidden = true
  if Array(directory.get_files()).any(func(name): return name != Auth.SENTINEL): return ERR_ALREADY_EXISTS
  for name in directory.get_directories():
   if name == "shader_cache" and Playtest.is_compatibility_shader_cache(directory): continue
   if name == "logs" and not directory.is_link(name):
    var logs := DirAccess.open("user://logs")
    if logs == null: return ERR_CANT_OPEN
    logs.include_hidden = true
    if logs.get_directories().is_empty() and Array(logs.get_files()) in [[],["godot.log"]]: continue
   return ERR_ALREADY_EXISTS
  var value := {"schema":1,"root_name":policy().root_name,"origin":"fresh","policy_sha256":policy_digest()}
  var bytes := (JSON.stringify(value) + "\n").to_utf8_buffer()
  var file := FileAccess.open(path, FileAccess.WRITE)
  if file == null: return FileAccess.get_open_error()
  var stored := file.store_buffer(bytes)
  file.flush()
  var error := file.get_error()
  file.close()
  if error != OK or not stored: return ERR_FILE_CANT_WRITE
  return OK if FileAccess.get_file_as_bytes(path) == bytes else ERR_FILE_CORRUPT)
 if result.error != OK or not result.ran or result.value != OK:
  return "The guarded save folder is busy, redirected, unverified, or needs explicit migration review. No saves were opened."
 return ""
