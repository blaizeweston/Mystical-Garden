extends RefCounted
## Explicit older-save import through the candidate title. Selection is read
## only and recomputed under the same root lock that commits the destinations.
const Ops = preload("res://persistence_operations.gd")
const Profile = preload("res://character_profile.gd")
const GuestProjection = preload("res://guest_profile_projection.gd")
const Plan = preload("res://persistence_recovery_plan.gd")
const Inspection = preload("res://persistence_save_inspection.gd")

static func run(worlds: RefCounted, roster: RefCounted, fault := Callable()) -> Dictionary:
 var selected := _select(worlds, roster)
 if selected.error != OK or selected.files.is_empty():
  return selected
 var directories := PackedStringArray()
 for path: String in selected.paths:
  var parent := path.get_base_dir()
  if parent != "user://" and not directories.has(parent): directories.append(parent)
 var boot := Ops.Authorization.bootstrap(directories)
 if boot.error != OK: return Ops.management_result(boot.error, "import_directory_unavailable")
 var boundary := Ops.run_management(selected.paths, selected.auxiliary, func(context):
  var current := _select(worlds, roster)
  if current.error != OK: return current
  if current != selected: return Ops.management_result(ERR_BUSY, "legacy_import_selection_changed")
  var execution := Ops.commit_bytes(context, current.files, current.anchor, fault)
  var result := Ops.transaction_result(execution)
  if result.state == "completed":
   result.imported = current.files.size()
  return result)
 if boundary.get("ran", false) and boundary.error == OK:
  return boundary.value
 if boundary.get("ran", false):
  return Ops.management_result(boundary.error, "import_authorization_release_failed", "unresolved")
 return boundary

static func _select(worlds: RefCounted, roster: RefCounted) -> Dictionary:
 var first: Dictionary = worlds.paths(0)
 var second: Dictionary = worlds.paths(1)
 var third: Dictionary = worlds.paths(2)
 var catalog_path: String = roster._catalog_path()
 var paths := PackedStringArray([worlds.legacy_garden, worlds.legacy_character, worlds.legacy_guest,
  first.garden, first.character, second.garden, second.character, third.character, catalog_path])
 var inspected := Plan.discover(Inspection.recovery_seeds(paths))
 if not inspected.state in ["healthy", "empty"]:
  return Ops.management_result(ERR_BUSY, inspected.reason, inspected.state)
 if inspected.active_leases.values().has(true):
  return Ops.management_result(ERR_BUSY, "slot_in_use")
 if not Ops.recovery_scratch(inspected.participants).is_empty():
  return Ops.management_result(ERR_BUSY, "metadata_publication_pending", "unresolved")
 var catalog := _read(catalog_path, "")
 if catalog.error != OK: return Ops.management_result(catalog.error, "catalog_unreadable")
 var index: ConfigFile = catalog.get("file", ConfigFile.new())
 var capacity := clampi(int(index.get_value("roster", "capacity", roster.INITIAL_COUNT)), roster.INITIAL_COUNT, roster.MAX_COUNT)
 var roster_paths := PackedStringArray([catalog_path])
 for slot in capacity: roster_paths.append(roster._slot_profile(slot))
 var roster_plan := Plan.discover(roster_paths)
 if not roster_plan.state in ["healthy", "empty"]:
  return Ops.management_result(ERR_BUSY, roster_plan.reason, roster_plan.state)
 if not Ops.recovery_scratch(roster_plan.participants).is_empty():
  return Ops.management_result(ERR_BUSY, "metadata_publication_pending", "unresolved")
 var identities := {}
 var vacancies := PackedStringArray()
 for slot in capacity:
  var path: String = roster_paths[slot + 1]
  var item := _read(path, "character")
  if item.error != OK: return Ops.management_result(item.error, "roster_identity_unreadable")
  if not item.exists:
   if not roster_plan.active_leases.get(path.get_base_dir().path_join("session.cfg"), false):
    vacancies.append(path)
   continue
  var identity := _identity(item.file)
  if identity.is_empty() or identities.has(identity):
   return Ops.management_result(ERR_INVALID_DATA, "roster_identity_ambiguous")
  identities[identity] = path

 var files := {}
 var anchor := ""
 var auxiliary := PackedStringArray([catalog_path, catalog_path + ".tmp"])
 var sources := {}
 var primary := _read(worlds.legacy_garden, "garden")
 if primary.error != OK: return Ops.management_result(primary.error, "legacy_garden_unreadable")
 var first_deleted := FileAccess.file_exists(first.directory.path_join("deleted.cfg"))
 var second_deleted := FileAccess.file_exists(second.directory.path_join("deleted.cfg"))
 var copy_garden := false
 if primary.exists and not first_deleted:
  var receipt: String = str(index.get_value("imports", first.garden, ""))
  if receipt.is_empty():
   if FileAccess.file_exists(first.garden) and FileAccess.get_sha256(first.garden) != Plan._digest(primary.bytes):
    # Older versions registered the profile only, so their completed imports
    # cannot prove a changed Garden's origin. Preserve the occupied Garden.
    return Ops.management_result(ERR_ALREADY_EXISTS, "legacy_garden_destination_occupied")
   copy_garden = not FileAccess.file_exists(first.garden)
   index.set_value("imports", first.garden, Plan._digest(primary.bytes))
  elif receipt != Plan._digest(primary.bytes) or not FileAccess.file_exists(first.garden):
   return Ops.management_result(ERR_INVALID_DATA, "legacy_garden_receipt_conflict")
  var old := _read(worlds.legacy_character, "character")
  if old.error != OK: return Ops.management_result(old.error, "legacy_profile_unreadable")
  if old.exists: sources[first.character] = old
 if not second_deleted and not FileAccess.file_exists(second.garden):
  var guest := _read(worlds.legacy_guest, "character")
  if guest.error != OK: return Ops.management_result(guest.error, "legacy_profile_unreadable")
  if guest.exists: sources[second.character] = guest

 for target in [first.character, second.character, third.character]:
  if (target == first.character and first_deleted) or (target == second.character and second_deleted):
   continue
  var existing := _read(target, "character")
  if existing.error != OK: return Ops.management_result(existing.error, "legacy_profile_unreadable")
  if not sources.has(target) and not existing.exists: continue
  var incoming: Dictionary = sources.get(target, existing)
  var identity := _identity(incoming.file)
  if identity.is_empty():
   return Ops.management_result(ERR_INVALID_DATA, "legacy_identity_unverified")
  if incoming.file.has_section_key("character", "progress") and not incoming.file.get_value("character", "progress") is Dictionary:
   return Ops.management_result(ERR_INVALID_DATA, "legacy_profile_unreadable")
  if not GuestProjection.valid_receipts(incoming.file.get_value("character", "projection_receipts", {})):
   return Ops.management_result(ERR_INVALID_DATA, "legacy_profile_unreadable")
  var registered: String = str(index.get_value("imports", target, ""))
  if not registered.is_empty():
   if registered != identity or not (identities.has(identity) or index.has_section_key("deleted_identities", identity)):
    return Ops.management_result(ERR_INVALID_DATA, "legacy_profile_receipt_conflict")
   continue
  if index.has_section_key("deleted_identities", identity):
   return Ops.management_result(ERR_UNAUTHORIZED, "legacy_identity_retired")
  if identities.has(identity):
   return Ops.management_result(ERR_ALREADY_EXISTS, "legacy_roster_identity_collision")
  if existing.exists and existing.bytes != incoming.bytes:
   return Ops.management_result(ERR_ALREADY_EXISTS, "legacy_profile_destination_occupied")
  var destination: String
  if not vacancies.is_empty():
   destination = vacancies[0]
   vacancies.remove_at(0)
  elif capacity < roster.MAX_COUNT:
   destination = roster._slot_profile(capacity)
   capacity += 1
   if FileAccess.file_exists(destination):
    return Ops.management_result(ERR_ALREADY_EXISTS, "legacy_roster_destination_occupied")
  else:
   return Ops.management_result(ERR_OUT_OF_MEMORY, "roster_full")
  paths.append(destination)
  if anchor.is_empty(): anchor = destination
  identities[identity] = destination
  files[destination] = incoming.bytes
  if sources.has(target) and not existing.exists: files[target] = incoming.bytes
  index.set_value("imports", target, identity)
 if copy_garden: files[first.garden] = primary.bytes

 if files.is_empty():
  return {"error":OK, "state":"completed", "reason":"legacy_import_no_changes", "files":{}}
 if anchor.is_empty(): anchor = first.garden
 index.set_value("roster", "capacity", capacity)
 files[catalog_path] = index.encode_to_text().to_utf8_buffer()
 for target: String in files:
  if target == catalog_path or FileAccess.file_exists(target): continue
  var serializer: RefCounted = load("res://progress.gd").new() if target.get_file() == "garden.cfg" else Profile.new()
  serializer.path = target
  for backup: String in serializer.migration_backup_paths():
   if FileAccess.file_exists(backup) or DirAccess.dir_exists_absolute(backup) or FileAccess.file_exists(backup + ".tmp") or DirAccess.dir_exists_absolute(backup + ".tmp"):
    return Ops.management_result(ERR_BUSY, "legacy_migration_backup_conflict", "unresolved")
   auxiliary.append(backup)
   auxiliary.append(backup + ".tmp")
 var roster_seed: String = roster._slot_profile(0)
 if not paths.has(roster_seed): paths.append(roster_seed)
 paths.sort()
 return {"error":OK, "state":"selected", "files":files, "paths":paths, "anchor":anchor, "auxiliary":auxiliary}

static func _identity(file: ConfigFile) -> String:
 var identity: Variant = file.get_value("character", "identity", "")
 return str(identity).to_lower() if identity is String and Profile.valid_identity(identity) else ""

static func _read(path: String, section: String) -> Dictionary:
 if not FileAccess.file_exists(path):
  return {"error":OK, "exists":false}
 var data := Plan._read_bytes(path)
 if not data.ok: return {"error":ERR_FILE_CANT_READ}
 var file := Inspection.decode_save(data.bytes, section)
 if file == null: return {"error":ERR_INVALID_DATA}
 return {"error":OK, "exists":true, "bytes":data.bytes, "file":file}
