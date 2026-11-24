extends RefCounted
## One synchronous legacy mutation at a time, using the same native root gate
## as B2. A passive plan is never permission to modify a save.

const Auth = preload("res://persistence_authorization.gd")
const Layout = preload("res://persistence_save_layout.gd")
const Plan = preload("res://persistence_recovery_plan.gd")
static var _scope := PackedStringArray()
static var _held := false
const BACKUPS = [".pre-tier-growth-v2.bak", ".pre-timed-research-v2.bak", ".pre-immediate-heart-v3.bak", ".pre-construction-v1.bak", ".pre-irrigation-v2.bak", ".pre-content-v2.bak",
 ".pre-altar-v1.bak", ".pre-inventory-v1.bak", ".pre-heart-v1.bak", ".pre-plots-v2.bak"]

static func fixture_path(path: String) -> bool:
 if DisplayServer.get_name() != "headless" or not OS.has_environment("MYSTICAL_VALIDATION_RUN"):
  return false
 for prefix in ["res://.godot/", "user://release-fixtures/"]:
  if path.begins_with(prefix) and Auth._ordinary_components(path.trim_prefix(prefix)):
   return true
 return false

static func held() -> bool:
 return _held

static func run(paths: PackedStringArray, operation: Callable, auxiliary := PackedStringArray(), recover := false) -> Error:
 if not Thread.is_main_thread():
  return ERR_BUSY
 if paths.is_empty():
  return ERR_INVALID_PARAMETER
 if Array(paths).all(fixture_path):
  if not Array(auxiliary).all(fixture_path): return ERR_UNAUTHORIZED
  return operation.call({})
 var supported := Layout.directories()
 var requested := PackedStringArray()
 for path in paths:
  if not Layout.is_participant(path, supported):
   return ERR_INVALID_PARAMETER
  if not requested.has(path):
   requested.append(path)
  var metadata := Layout.deletion_metadata(path, supported)
  if not metadata.is_empty() and not requested.has(metadata):
   requested.append(metadata)
 requested.sort()
 if _held:
  for path in requested + auxiliary:
   if not _scope.has(path):
    return ERR_UNAUTHORIZED
  # A nested operation may read healthy state but must not reinterpret newly
  # created scratch as restart evidence. The outer call owns its own cleanup.
  return operation.call({})
 if not Auth.replacement_available():
  return ERR_UNAVAILABLE
 # A legacy restart can have additional members. Record its complete scope
 # before acquisition, then rediscover it under the root gate before writing.
 var before := Plan.discover(requested, true) if recover else {}
 if recover and not _eligible(before, true):
  return ERR_BUSY
 var participants: PackedStringArray = before.get("participants", requested)
 var files := {}
 for path in participants:
  for suffix in ["", ".tmp"] + Plan.ARTIFACTS:
   files[path + suffix] = true
  if Layout.is_canonical(path, supported):
   for suffix in BACKUPS if path.get_file() == "garden.cfg" else [".pre-content-v2.bak"]:
    files[path + suffix] = true
    files[path + suffix + ".tmp"] = true
   var parent := path.get_base_dir()
   var marker := parent.path_join("session.cfg")
   files[marker] = true
   files[marker + ".tmp"] = true
 for path in auxiliary:
  files[path] = true
 var native_paths := PackedStringArray()
 var missing_parents := {}
 var physical_root := OS.get_user_data_dir().replace("\\", "/").trim_suffix("/")
 for path: String in files:
  if not path.begins_with("user://") or not Auth._ordinary_components(path.trim_prefix("user://")):
   return ERR_INVALID_PARAMETER
  var parent := path.get_base_dir()
  if DirAccess.dir_exists_absolute(parent):
   native_paths.append(path)
  elif physical_root.path_join(path.trim_prefix("user://")).length() >= 260:
   return ERR_INVALID_PARAMETER
  else:
   missing_parents[parent] = true
 native_paths.sort()
 var gate := Auth.run_legacy(native_paths, func(_token):
  for parent in missing_parents:
   if DirAccess.dir_exists_absolute(parent):
    return ERR_BUSY
  var locked := Plan.discover(requested, true)
  if not _eligible(locked, recover):
   return ERR_BUSY
  if locked.participants != participants or (recover and locked.observed != before.observed):
   return ERR_BUSY
  for file: String in files:
   if file.ends_with(".tmp"):
    if FileAccess.file_exists(file) or DirAccess.dir_exists_absolute(file):
     return ERR_BUSY
  _scope = PackedStringArray(files.keys())
  _held = true
  var value: Error = operation.call(locked)
  _held = false
  _scope = PackedStringArray()
  return value)
 return gate.value if gate.ran and gate.value != OK else gate.error

static func create_archive(path: String, source: String) -> Error:
 if fixture_path(path):
  return DirAccess.make_dir_recursive_absolute(path)
 if not _held or not _scope.has(source) or not Layout.archive_folder(path, source, Layout.directories()):
  return ERR_UNAUTHORIZED
 var folder := ProjectSettings.globalize_path(path).replace("\\", "/")
 var disk := DirAccess.open(source.get_base_dir())
 var parent := folder.get_base_dir()
 if disk == null or folder.length() + 15 >= 260 or disk.is_link(parent) or disk.is_link(folder):
  return ERR_INVALID_PARAMETER
 if disk.dir_exists(folder) or disk.file_exists(folder) or disk.file_exists(parent):
  return ERR_ALREADY_EXISTS
 if disk.dir_exists(parent) and (not Auth._plain_ancestry(disk, parent) or not Auth._exact_directory(parent)):
  return ERR_INVALID_PARAMETER
 return DirAccess.make_dir_recursive_absolute(path)

static func _eligible(plan: Dictionary, recover: bool) -> bool:
 if plan.state in ["healthy", "empty"]:
  return true
 if not recover or plan.state != "pending_recovery" or plan.reason != "journal_found" or plan.journals.size() != 1:
  return false
 var record: Dictionary = plan.journals[0]
 return not record.get("evidence_only", false) and record.get("attempt", "").is_empty() and not record.has("evidence")
