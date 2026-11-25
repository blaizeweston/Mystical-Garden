extends RefCounted
## Passive projections for a caller's selected save path. These never acquire the gate.

const Planner = preload("res://persistence_recovery_plan.gd")
const Profile = preload("res://character_profile.gd")
const Layout = preload("res://persistence_save_layout.gd")
const VALUE_CONSTRUCTORS = [
 "Array", "Dictionary", "PackedByteArray", "PackedInt32Array", "PackedInt64Array",
 "PackedFloat32Array", "PackedFloat64Array", "PackedStringArray", "PackedVector2Array",
 "PackedVector3Array", "PackedVector4Array", "PackedColorArray", "StringName", "NodePath",
 "Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i", "Rect2", "Rect2i",
 "Transform2D", "Plane", "Quaternion", "AABB", "Basis", "Transform3D", "Projection", "Color"
]

static func garden(path: String) -> Dictionary:
 var inspected := _inspect(path, "garden")
 var result: Dictionary = inspected.result
 if inspected.file != null:
  var file: ConfigFile = inspected.file
  var beds: Variant = file.get_value("garden", "plots_v2", [])
  result.summary = {
   "suspended_owner": str(file.get_value("expedition","suspended",{}).get("owner","")) if file.get_value("expedition","suspended",{}) is Dictionary else "",
   "knowledge": _number(file.get_value("garden", "knowledge", 0)),
   "plots": beds.size() if beds is Array and not beds.is_empty() else 3,
   "best": _number(file.get_value("campaign", "best_clear", 0))
  }
 return result

static func character(path: String, include_profile := false) -> Dictionary:
 var inspected := _inspect(path, "character")
 var result: Dictionary = inspected.result
 if inspected.file != null:
  var file: ConfigFile = inspected.file
  var identity: Variant = file.get_value("character", "identity", "")
  var saved: Variant = file.get_value("character", "progress", {})
  var data := Profile.blank()
  if saved is Dictionary:
   if not Profile.Experience.supported(saved):
    result.state = "invalid"
    result.reason = "unsupported_class_xp_version"
    return result
   data = Profile.normalize(Profile.ContentIDs.profile(saved, file.get_value("content", "manifest", Profile.ContentIDs.legacy())))
  var class_id: int = data.active_class
  var identified: bool = identity is String and Profile.valid_identity(identity)
  result.summary = {
   "name": data.name, "class_name": Profile.Classes.DEFINITIONS[class_id].name,
   "level": Profile.level(data.xp[class_id]),
   "identity": identity if identified else "", "identity_pending": not identified
  }
  if include_profile:
   result.summary.profile = data
 return result

static func _inspect(path: String, section: String, owned_session := false) -> Dictionary:
 var result := {"path": path, "state": "invalid", "reason": "wrong_save_kind",
  "exists": null, "active": false, "digest": "", "summary": {}, "participants": PackedStringArray(),
  "journal_anchors": PackedStringArray()}
 var leaf := path.get_file()
 var matches_kind := leaf == "garden.cfg" if section == "garden" else leaf in ["character.cfg", "character-local-guest.cfg"]
 if not matches_kind:
  return {"result": result, "file": null}
 var plan := Planner.discover(recovery_seeds(PackedStringArray([path])))
 result.state = plan.state
 result.reason = plan.reason
 result.participants = plan.participants
 result.journal_anchors = plan.journal_anchors
 result.active = plan.active_leases.get(path.get_base_dir().path_join("session.cfg"), false)
 if plan.observed.has(path):
  result.exists = plan.observed[path] != "absent"
 if result.active and not owned_session and plan.state in ["healthy", "empty"]:
  return _refuse(result, "busy", "active_session_lease")
 if plan.state != "healthy":
  return {"result": result, "file": null}
 if result.exists == false:
  result.state = "empty"
  return {"result": result, "file": null}

 # Use only bytes matching the planner's observation. A concurrent writer can
 # make this preview stale. The preview never authorizes a later mutation.
 var bytes := Planner._read_bytes(path)
 if not bytes.ok or Planner._digest(bytes.bytes) != plan.observed[path]:
  return _refuse(result, "busy", "save_changed_during_inspection")
 var content: String = bytes.bytes.get_string_from_utf8()
 if content.to_utf8_buffer() != bytes.bytes or not _safe_value_syntax(content):
  return _refuse(result, "invalid", "unsafe_save_content")
 var file := _parse_save(content, section)
 if file == null:
  return _refuse(result, "invalid", "invalid_save_content")
 result.digest = plan.observed[path]
 return {"result": result, "file": file}

static func recovery_seeds(paths: PackedStringArray) -> PackedStringArray:
 var participants := paths.duplicate()
 var layout := Layout.directories()
 for path in paths:
  var metadata := Layout.deletion_metadata(path, layout)
  if not metadata.is_empty() and DirAccess.dir_exists_absolute(metadata.get_base_dir()) and not participants.has(metadata):
   participants.append(metadata)
 participants.sort()
 return participants

static func decode_save(bytes: PackedByteArray, section: String) -> ConfigFile:
 var content := bytes.get_string_from_utf8()
 if content.to_utf8_buffer() != bytes or not _safe_value_syntax(content):
  return null
 return _parse_save(content, section)

static func _parse_save(content: String, section: String) -> ConfigFile:
 var file := ConfigFile.new()
 if file.parse(content) != OK or (not section.is_empty() and not file.has_section(section)):
  return null
 return file

static func _safe_value_syntax(content: String) -> bool:
 # ConfigFile can instantiate Object and load resources through Variant syntax.
 # Remove quoted strings and comments before checking unquoted constructors.
 var literals := RegEx.create_from_string('"(?:[^"\\\\]++|\\\\.)*+"|;[^\\r\\n]*')
 var stripped := literals.sub(content, " ", true)
 var constructor := RegEx.create_from_string('[A-Za-z_][A-Za-z_0-9]*\\s*\\(')
 for match_result in constructor.search_all(stripped):
  var name := match_result.get_string().trim_suffix("(").strip_edges()
  if name not in VALUE_CONSTRUCTORS:
   return false
 return true

static func _number(value: Variant) -> int:
 return int(value) if value is int or value is float or value is String else 0

static func _refuse(result: Dictionary, state: String, reason: String) -> Dictionary:
 result.state = state
 result.reason = reason
 return {"result": result, "file": null}
