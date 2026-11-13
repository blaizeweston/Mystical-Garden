extends RefCounted
## Canonical save directories and leaves for the supported user-data trees.

const ROOTS = ["user://saves", "user://combat-balance-preview/saves"]
const LEGACY = ["garden.cfg", "character.cfg", "character-local-guest.cfg"]

static func directories() -> Dictionary:
 var supported := {"user://": LEGACY, "user://combat-balance-preview": LEGACY}
 for base: String in ROOTS:
  supported[base] = []
  var roster := base.path_join("characters")
  var developer := base.path_join("developer-garden")
  supported[roster] = []
  supported[developer] = []
  for slot in range(1, 4):
   var name := "slot_%d" % slot
   supported[base.path_join(name)] = ["garden.cfg", "character.cfg"]
   supported[developer.path_join(name)] = ["garden.cfg", "character.cfg"]
  for slot in range(1, 129):
   supported[roster.path_join("slot_%d" % slot)] = ["character.cfg"]
 return supported

static func is_canonical(path: String, supported: Dictionary) -> bool:
 var parent := path.get_base_dir()
 var leaf := path.get_file()
 return supported.get(parent, []).has(leaf) and parent.path_join(leaf) == path

## Group 2B journals may include the metadata that makes a deletion authoritative.
## Save selection and serialization still accept canonical saves only.
static func deletion_metadata(path: String, supported: Dictionary) -> String:
 if not is_canonical(path, supported) or not path.get_base_dir().get_file().begins_with("slot_"):
  return ""
 var parent := path.get_base_dir()
 var root := parent.get_base_dir()
 return root.path_join("catalog.cfg") if root.get_file() == "characters" else parent.path_join("deleted.cfg")

static func is_participant(path: String, supported: Dictionary) -> bool:
 if is_canonical(path, supported):
  return true
 var parent := path.get_base_dir()
 if path == parent.path_join("deleted.cfg"):
  return deletion_metadata(parent.path_join("garden.cfg"), supported) == path
 if path == parent.path_join("catalog.cfg"):
  return deletion_metadata(parent.path_join("slot_1/character.cfg"), supported) == path
 return false

static func archive_folder(path: String, source: String, supported: Dictionary) -> bool:
 if deletion_metadata(source, supported).is_empty() or path.get_base_dir() != source.get_base_dir().path_join("backups"):
  return false
 var leaf := path.get_file()
 var pattern := RegEx.create_from_string("\\A(?:[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]+|deleted-[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9a-f]{12}|(?:world|deleted-world|deleted-character)-[0-9a-f]{16})\\z")
 return path == path.get_base_dir().path_join(leaf) and pattern.search(leaf) != null

static func archive_source(path: String, supported: Dictionary) -> String:
 var folder := path.get_base_dir()
 var leaf := path.get_file().trim_suffix(".tmp")
 var source := folder.get_base_dir().get_base_dir().path_join(leaf)
 if not archive_folder(folder, source, supported):
  return ""
 var name := folder.get_file()
 if (name.begins_with("world-") or name.begins_with("deleted-world-")) and leaf != "garden.cfg":
  return ""
 if name.begins_with("deleted-character-") != (source.get_base_dir().get_base_dir().get_file() == "characters"):
  return ""
 return source

static func valid_journal_scope(anchor: String, members: PackedStringArray, supported: Dictionary) -> bool:
 var metadata := deletion_metadata(anchor, supported)
 for path in members:
  if not is_canonical(path, supported) and (path != metadata or not members.has(anchor)):
   return false
  if members.has(metadata) and is_canonical(path, supported) and path.get_base_dir() != anchor.get_base_dir():
   return false
 return true
