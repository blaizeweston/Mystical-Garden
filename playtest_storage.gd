extends RefCounted
## The Windows retail playtest root is selected before Godot starts the scene tree.
## The editor-driven source and --main-pack fixtures keep their isolated test roots.
const Auth = preload("res://persistence_authorization.gd")
const PREFIX := "Mystical Garden Playtest "
const BUILD := "res://assets/content/build_manifest.json"
const MAX_ENTRIES := 16384
const IDENTITY := "user://playtest.identity"

static var refusal := ""
static var inspected := false

static func build() -> Dictionary:
 var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUILD))
 return data if data is Dictionary else {}

static func retail() -> bool:
 return OS.has_feature("template_release") and (bool(ProjectSettings.get_setting("application/config/mystical_playtest", false)) or build().has("playtest_version"))

static func inspect(info: Dictionary) -> String:
 var version: String = str(info.get("playtest_version", ""))
 var identity := RegEx.create_from_string("\\A(?:0|[1-9][0-9]{0,5})\\.(?:0|[1-9][0-9]{0,5})\\.(?:0|[1-9][0-9]{0,5})-playtest\\.[1-9][0-9]{0,5}\\z")
 var commit: String = str(info.get("git_commit", ""))
 if not identity.search(version) or not RegEx.create_from_string("\\A[0-9a-f]{40}\\z").search(commit) or info.get("save_root") != PREFIX + version:
  return "The playtest build identity is missing or invalid."
 var profile := OS.get_environment("USERPROFILE").replace("\\", "/").trim_suffix("/")
 var roaming := OS.get_environment("APPDATA").replace("\\", "/").trim_suffix("/")
 var root := OS.get_user_data_dir().replace("\\", "/").trim_suffix("/")
 if not Auth._is_drive_absolute(profile) or not Auth._ordinary_components(profile.substr(3)) \
  or roaming.nocasecmp_to(profile.path_join("AppData/Roaming")) != 0 \
  or root.nocasecmp_to(roaming.path_join(PREFIX + version)) != 0 \
  or root.length() + 120 >= 260:
  return "Use the default local Windows AppData folder for this playtest."
 for component in profile.to_lower().split("/"):
  if component in ["mystical garden", "mystical garden prototype"] or component.begins_with(PREFIX.to_lower()):
   return "The playtest save root must be separate from existing Garden saves."
 var location := Auth._root()
 if location.error == ERR_UNAVAILABLE and not Auth.replacement_available():
  return "The playtest persistence library is missing or incompatible."
 if location.error != OK or location.path != root:
  return "The playtest save root is unsupported or redirected."
 if not Auth.replacement_available():
  return "The playtest persistence library is missing or incompatible."
 var files := plain_files(root)
 if files.is_empty():
  return "The playtest save root contains a redirected or unsupported path."
 # Validate existing file identities with the native gate, including metadata,
 # archives and diagnostic files. Windows hard links are not reparse points.
 var marker := version + "\n" + commit + "\n"
 for offset in range(0, files.size(), 128):
  var checked := Auth.run_legacy(files.slice(offset, offset + 128), func(_token): return OK)
  if checked.error != OK:
   return "The playtest save root is unsupported or currently busy."
 var marked := Auth.run_legacy(PackedStringArray([IDENTITY]), func(_token):
  if FileAccess.file_exists(IDENTITY):
   return OK if FileAccess.get_file_as_string(IDENTITY) == marker else ERR_INVALID_DATA
  var directory := DirAccess.open("user://")
  if directory == null:
   return ERR_CANT_OPEN
  directory.include_hidden = true
  if Array(directory.get_files()).any(func(name): return name != Auth.SENTINEL):
   return ERR_INVALID_DATA
  for name in directory.get_directories():
   if name != "shader_cache" or not is_compatibility_shader_cache(directory):
    return ERR_INVALID_DATA
  var file := FileAccess.open(IDENTITY, FileAccess.WRITE)
  if file == null:
   return FileAccess.get_open_error()
  var stored := file.store_string(marker)
  file.flush()
  return file.get_error() if stored else ERR_FILE_CANT_WRITE)
 if marked.error != OK or not marked.ran or marked.value != OK:
  return "The playtest save set does not match this version. Restore a matching backup."
 return ""

# The desktop Compatibility renderer creates this cache before the title runs.
# Only its known directory/hash layout may precede first-run save identity.
static func is_compatibility_shader_cache(root: DirAccess) -> bool:
 if root.is_link("shader_cache"):
  return false
 var cache := DirAccess.open("user://shader_cache")
 if cache == null:
  return false
 cache.include_hidden = true
 if not cache.get_files().is_empty():
  return false
 var shader_name := RegEx.create_from_string("\\A[A-Za-z][A-Za-z0-9]*ShaderGLES3\\z")
 var shader_hash := RegEx.create_from_string("\\A[0-9a-f]{64}\\z")
 var cache_file := RegEx.create_from_string("\\A[0-9a-f]{40}\\.cache\\z")
 for shader in cache.get_directories():
  if not shader_name.search(shader) or cache.is_link(shader):
   return false
  var variants := DirAccess.open(cache.get_current_dir().path_join(shader))
  if variants == null:
   return false
  variants.include_hidden = true
  if not variants.get_files().is_empty():
   return false
  for variant in variants.get_directories():
   if not shader_hash.search(variant) or variants.is_link(variant):
    return false
   var compiled := DirAccess.open(variants.get_current_dir().path_join(variant))
   if compiled == null:
    return false
   compiled.include_hidden = true
   if not compiled.get_directories().is_empty():
    return false
   for file in compiled.get_files():
    if not cache_file.search(file) or compiled.is_link(file):
     return false
 return true

static func plain_files(root: String) -> PackedStringArray:
 var files := PackedStringArray([IDENTITY])
 var pending := PackedStringArray([root])
 var examined := 0
 while not pending.is_empty():
  var folder: String = pending[-1]
  pending.remove_at(pending.size() - 1)
  var directory := DirAccess.open(folder)
  if directory == null:
   return PackedStringArray()
  directory.include_hidden = true
  if directory.list_dir_begin() != OK:
   return PackedStringArray()
  var name := directory.get_next()
  while not name.is_empty():
   examined += 1
   var path := folder.path_join(name)
   if examined > MAX_ENTRIES or path.length() >= 260 or not Auth._ordinary_components(name) or directory.is_link(path):
    return PackedStringArray()
   if directory.current_is_dir():
    if directory.is_case_sensitive(path):
     return PackedStringArray()
    pending.append(path)
   elif path.get_file() != Auth.SENTINEL and path != root.path_join(IDENTITY.get_file()):
    files.append("user://" + path.trim_prefix(root + "/"))
   name = directory.get_next()
 return files
