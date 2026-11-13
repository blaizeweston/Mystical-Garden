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
