extends RefCounted
## Synchronous opt-in authorization. Callbacks must finish without awaiting.
## Results separate boundary errors from the callback's own value.

const BACKEND := &"B0NativeLock"
const SENTINEL := ".mystical-garden-persistence.lock"
const Layout = preload("res://persistence_save_layout.gd")
static var _active: RefCounted
static var _lock: Object
static var _locked_root := ""
static var _participants := PackedStringArray()
static var _bootstrapping := false

static func run(paths: PackedStringArray, operation: Callable) -> Dictionary:
 if not Thread.is_main_thread() or _active != null or _bootstrapping:
  return _result(ERR_BUSY)
 if not operation.is_valid():
  return _result(ERR_INVALID_PARAMETER)
 var location := _root()
 if location.error != OK:
  return _result(location.error)
 var participants := _resolve_paths(paths, location.path, location.directory)
 if participants.is_empty():
  return _result(ERR_INVALID_PARAMETER)
 var held := _acquire(location.path, location.directory, participants)
 if held.error != OK:
  return held
 var authorization := RefCounted.new()
 _active = authorization
 _lock = held.value
 _locked_root = location.path
 _participants = participants
 var value: Variant = operation.call(authorization)
 _active = null
 _lock = null
 _locked_root = ""
 _participants = PackedStringArray()
 return _release(held.value, value)

## Creates only the requested supported directories and their supported ancestors.
## This operation has no callback or token. Rebuild the save plan after it returns.
static func bootstrap(paths: PackedStringArray) -> Dictionary:
 if not Thread.is_main_thread() or _active != null or _bootstrapping:
  return _result(ERR_BUSY)
 var supported := Layout.directories()
 var wanted := {}
 if paths.is_empty():
  return _result(ERR_INVALID_PARAMETER)
 for path in paths:
  if path == "user://" or not supported.has(path):
   return _result(ERR_INVALID_PARAMETER)
  while path != "user://":
   wanted[path] = true
   path = path.get_base_dir()
 var directories := PackedStringArray(wanted.keys())
 directories.sort()
 var location := _root()
 if location.error != OK:
  return _result(location.error)
 var held := _acquire(location.path, location.directory, PackedStringArray())
 if held.error != OK:
  return held
 _bootstrapping = true
 var outcome := _create_directories(location.path, location.directory, directories)
 _bootstrapping = false
 var result := _release(held.value, outcome)
 if result.error == OK:
  result.error = outcome.error
 return result

static func _create_directories(root: String, disk: DirAccess, paths: PackedStringArray) -> Dictionary:
 var missing := PackedStringArray()
 for path in paths:
  var target := root.path_join(path.trim_prefix("user://"))
  if target.length() >= 260 or disk.is_link(target) or disk.file_exists(target):
   return {"error": ERR_INVALID_PARAMETER, "path": path, "created": PackedStringArray()}
  if not disk.dir_exists(target):
   missing.append(path)
  elif not _plain_ancestry(disk, target) or not _exact_directory(target):
   return {"error": ERR_INVALID_PARAMETER, "path": path, "created": PackedStringArray()}
 var created := PackedStringArray()
 for path in missing:
  var target := root.path_join(path.trim_prefix("user://"))
  if not _plain_ancestry(disk, target.get_base_dir()):
   return {"error": ERR_INVALID_PARAMETER, "path": path, "created": created}
  var error := disk.make_dir(target)
  if error != OK:
   return {"error": error, "path": path, "created": created}
  created.append(path)
  if not _plain_ancestry(disk, target) or not _exact_directory(target):
   return {"error": ERR_INVALID_PARAMETER, "path": path, "created": created}
 return {"error": OK, "path": "", "created": created}

static func _exact_directory(path: String) -> bool:
 var parent := DirAccess.open(path.get_base_dir())
 if parent == null:
  return false
 parent.include_hidden = true
 return parent.get_directories().has(path.get_file())

static func _root() -> Dictionary:
 if OS.get_name() != "Windows":
  return _result(ERR_UNAVAILABLE)
 if not ClassDB.class_exists(BACKEND) or not ClassDB.can_instantiate(BACKEND):
  return _result(ERR_UNAVAILABLE)
 if not ClassDB.class_has_method(BACKEND, &"acquire") or ClassDB.class_get_method_argument_count(BACKEND, &"acquire") != 2:
  return _result(ERR_UNAVAILABLE)
 for method in [&"release", &"is_held", &"last_error"]:
  if not ClassDB.class_has_method(BACKEND, method) or ClassDB.class_get_method_argument_count(BACKEND, method) != 0:
   return _result(ERR_UNAVAILABLE)

 var root := OS.get_user_data_dir().replace("\\","/").trim_suffix("/")
 if not _is_drive_absolute(root) or not _ordinary_components(root.substr(3)):
  return _result(ERR_INVALID_PARAMETER)
 var directory := DirAccess.open(root)
 if directory == null:
  return _result(DirAccess.get_open_error())
 if not _plain_ancestry(directory, root):
  return _result(ERR_UNAVAILABLE)
 return {"error": OK, "path": root, "directory": directory}

static func _acquire(root: String, directory: DirAccess, participants: PackedStringArray) -> Dictionary:
 var sentinel := root.path_join(SENTINEL)
 if directory.is_link(sentinel) or directory.dir_exists(sentinel):
  return _result(ERR_INVALID_PARAMETER)

 var lock: Object = ClassDB.instantiate(BACKEND)
 if lock == null:
  return _result(ERR_UNAVAILABLE)
 var absolute_paths := PackedStringArray()
 for path in participants:
  absolute_paths.append(root.path_join(path.trim_prefix("user://")))
 var acquire_status: Variant = lock.call(&"acquire", sentinel, absolute_paths)
 if not (acquire_status is int):
  lock.free()
  return _result(ERR_UNAVAILABLE)
 var native_error: int = acquire_status
 if native_error != 0:
  lock.free()
  return _result(_acquire_error(native_error), native_error)
 if lock.call(&"is_held") != 1:
  lock.free()
  return _result(ERR_UNAVAILABLE)
 return _result(OK, 0, false, lock)

static func _release(lock: Object, value: Variant) -> Dictionary:
 var release_status: Variant = lock.call(&"release")
 lock.free()
 if not (release_status is int):
  return _result(FAILED, 0, true, value)
 var release_error: int = release_status
 return _result(OK if release_error == 0 else FAILED, release_error, true, value)

static func run_nested(authorization: RefCounted, paths: PackedStringArray, operation: Callable) -> Dictionary:
 if not Thread.is_main_thread() or authorization == null or authorization != _active:
  return _result(ERR_UNAUTHORIZED)
 if paths.is_empty() or not operation.is_valid():
  return _result(ERR_INVALID_PARAMETER)
 for path in paths:
  if not _participants.has(path):
   return _result(ERR_UNAUTHORIZED)
 return _result(OK, 0, true, operation.call(authorization))

## Requires the live native handle and the exact paths captured at acquisition.
static func replacement_available() -> bool:
 return ClassDB.class_exists(BACKEND) and ClassDB.class_has_method(BACKEND, &"replace_authorized") and ClassDB.class_get_method_argument_count(BACKEND, &"replace_authorized") == 2

static func replace_authorized(token: RefCounted, source: String, destination: String) -> Dictionary:
 if not Thread.is_main_thread() or token == null or token != _active or _lock == null:
  return _result(ERR_UNAUTHORIZED)
 if not _participants.has(source) or not _participants.has(destination) or source == destination or source.get_base_dir() != destination.get_base_dir():
  return _result(ERR_UNAUTHORIZED)
 if not replacement_available():
  return _result(ERR_UNAVAILABLE)
 var native: Variant = _lock.call(&"replace_authorized", _locked_root.path_join(source.trim_prefix("user://")),
  PackedStringArray([_locked_root.path_join(destination.trim_prefix("user://"))]))
 if not native is int:
  return _result(ERR_UNAVAILABLE)
 return _result(OK if native == 0 else _acquire_error(native), native, true)

static func _resolve_paths(paths: PackedStringArray, root: String, directory: DirAccess) -> PackedStringArray:
 var resolved := PackedStringArray()
 for path in paths:
  if not path.begins_with("user://"):
   return PackedStringArray()
  var relative := path.trim_prefix("user://")
  if not _ordinary_components(relative):
   return PackedStringArray()
  var target := root.path_join(relative)
  if relative.to_lower() == SENTINEL or target.length() >= 260:
   return PackedStringArray()
  # Existing ancestry must be ordinary directories. A new leaf is allowed.
  var parent := target.get_base_dir()
  if not _plain_ancestry(directory, parent) or directory.dir_exists(target) or directory.is_link(target):
   return PackedStringArray()
  resolved.append(path)
 return resolved

static func _plain_ancestry(directory: DirAccess, path: String) -> bool:
 if not _is_drive_absolute(path):
  return false
 var current := path.left(3)
 for component in path.substr(3).split("/", false):
  current = current.path_join(component)
  if not directory.dir_exists(current) or directory.is_link(current) or directory.is_case_sensitive(current):
   return false
 return true

static func _is_drive_absolute(path: String) -> bool:
 if path.length() < 3 or path.substr(1, 2) != ":/":
  return false
 var letter := path.unicode_at(0)
 return (letter >= 65 and letter <= 90) or (letter >= 97 and letter <= 122)

static func _ordinary_components(path: String) -> bool:
 for component in path.split("/", true):
  if component.is_empty() or component.ends_with(".") or component.ends_with(" "):
   return false
  for index in component.length():
   if component.unicode_at(index) < 32 or component[index] in ['\\', ':', '"', '<', '>', '|', '?', '*', '~']:
    return false
  var stem := component.get_slice(".", 0).strip_edges().to_upper()
  if stem in ["CON", "PRN", "AUX", "NUL", "CONIN$", "CONOUT$"]:
   return false
  if stem.length() == 4 and (stem.begins_with("COM") or stem.begins_with("LPT")):
   if stem[3] in "0123456789¹²³":
    return false
 return true

static func _acquire_error(native_error: int) -> Error:
 if native_error == 32:
  return ERR_BUSY
 if native_error == 50:
  return ERR_UNAVAILABLE
 if native_error == 123:
  return ERR_INVALID_PARAMETER
 return ERR_CANT_OPEN

static func _result(error: Error, native_error := 0, ran := false, value: Variant = null) -> Dictionary:
 return {"error":error, "native_error":native_error, "ran":ran, "value":value}
