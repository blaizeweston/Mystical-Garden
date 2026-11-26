extends RefCounted
const Profile=preload("res://character_profile.gd")
const Slots=preload("res://save_slots.gd")
const Batch=preload("res://save_batch.gd")
const INITIAL_COUNT:=3
const MAX_COUNT:=128
var root_path:="user://saves/characters"

func count() -> int:
 var file:=ConfigFile.new()
 if file.load(root_path.path_join("catalog.cfg"))!=OK: return INITIAL_COUNT
 return clampi(int(file.get_value("roster","capacity",INITIAL_COUNT)),INITIAL_COUNT,MAX_COUNT)

func leases() -> RefCounted:
 var store:=Slots.new();store.root_path=root_path;store.capacity=count();return store

func paths(slot: int) -> Dictionary:
 if slot<0 or slot>=count(): return {}
 return leases().paths(slot)

func set_capacity(amount: int) -> Error:
 return Batch.Legacy.run(PackedStringArray([_catalog_path()]), func(_plan): return _legacy_set_capacity(amount))

func _legacy_set_capacity(amount: int) -> Error:
 if amount<count() or amount>MAX_COUNT: return ERR_INVALID_PARAMETER
 var error:=DirAccess.make_dir_recursive_absolute(root_path)
 if error!=OK: return error
 var file:=ConfigFile.new();file.load(root_path.path_join("catalog.cfg"))
 file.set_value("roster","capacity",amount)
 return Batch.write(root_path.path_join("catalog.cfg"),file.encode_to_text().to_utf8_buffer())

func is_active(slot: int) -> bool:
 return slot>=0 and slot<count() and leases().is_active(slot)
func claim(slot: int) -> Error:
 return leases().claim(slot)
func heartbeat(slot: int) -> void:
 leases().heartbeat(slot)
func release(slot: int) -> void:
 leases().release(slot)

func summary(slot: int) -> Dictionary:
 var result:={"exists":false,"active":is_active(slot),"error":OK,"name":"Empty character","class_name":"","level":1,"identity":""}
 var location:=paths(slot)
 if location.is_empty(): result.error=ERR_INVALID_PARAMETER;return result
 if not FileAccess.file_exists(location.character): return result
 result.exists=true
 var profile:=Profile.new();profile.path=location.character;result.error=profile.load_profile(false)
 if result.error!=OK: return result
 result.name=profile.data.name;result.identity=profile.identity
 var class_id: int=profile.data.active_class
 result.class_name=Profile.Classes.DEFINITIONS[class_id].name
 result.level=Profile.level(profile.data.xp[class_id])
 return result

func create(slot: int,name: String,class_id: int,appearance: Array) -> Error:
 var location := paths(slot)
 if location.is_empty(): return ERR_INVALID_PARAMETER
 return Batch.Legacy.run(PackedStringArray([location.character, _catalog_path()]), func(_plan):
  if paths(slot) != location: return ERR_BUSY
  return _legacy_create(slot, name, class_id, appearance))

func _legacy_create(slot: int,name: String,class_id: int,appearance: Array) -> Error:
 var location:=paths(slot)
 if location.is_empty() or class_id<0 or class_id>=Profile.Classes.DEFINITIONS.size() or Profile.clean_name(name).is_empty(): return ERR_INVALID_PARAMETER
 var error:=claim(slot)
 if error!=OK: return error
 if FileAccess.file_exists(location.character): release(slot);return ERR_ALREADY_EXISTS
 var profile:=Profile.new();profile.path=location.character
 profile.data=Profile.normalize({"name":name,"active_class":class_id,"appearance":appearance})
 error=profile.save_profile();release(slot)
 return error

func last_slot() -> int:
 var file:=ConfigFile.new();file.load(root_path.path_join("catalog.cfg"))
 return clampi(int(file.get_value("roster","selected",0)),0,count()-1)
func remember(slot: int) -> void:
 var location := paths(slot)
 if location.is_empty(): return
 Batch.Legacy.run(PackedStringArray([location.character, _catalog_path()]), func(_plan): return _legacy_remember(slot))

func _legacy_remember(slot: int) -> Error:
 var file:=ConfigFile.new();file.load(root_path.path_join("catalog.cfg"))
 file.set_value("roster","selected",clampi(slot,0,count()-1))
 return Batch.write(root_path.path_join("catalog.cfg"),file.encode_to_text().to_utf8_buffer())

# Copy existing per-world profiles once, deduplicating by permanent identity.
# Original files remain available for recovery and old-build compatibility.
func prepare(worlds: RefCounted) -> Error:
 for legacy_slot in Slots.COUNT:
  var source: String = worlds.paths(legacy_slot).character
  if not FileAccess.file_exists(source): continue
  var candidate := _legacy_import_candidate(source)
  if candidate.error != OK: return candidate.error
  if candidate.skip: continue
  var destination := _legacy_profile_path(candidate.slot)
  var error := Batch.Legacy.run(PackedStringArray([source, destination, _catalog_path()]), func(_plan):
   var locked := _legacy_import_candidate(source)
   if locked.error != OK: return locked.error
   if locked.skip or locked.slot != candidate.slot or locked.capacity != candidate.capacity: return ERR_BUSY
   return _legacy_import(source, legacy_slot, locked))
  if error != OK: return error
 if Batch.Legacy.fixture_path(root_path): return DirAccess.make_dir_recursive_absolute(root_path)
 return Batch.Legacy.Auth.bootstrap(PackedStringArray([root_path])).error

func _legacy_profile_path(slot: int) -> String:
 return root_path.path_join("slot_%d/character.cfg" % (slot + 1))

func _legacy_import_candidate(source: String) -> Dictionary:
 var mapping := ConfigFile.new()
 mapping.load(_catalog_path())
 var capacity := count()
 var result := {"error": OK, "skip": true, "slot": -1, "capacity": capacity}
 if not FileAccess.file_exists(source) or mapping.has_section_key("imports", source): return result
 var old := Profile.new()
 old.path = source
 result.error = old.load_profile(false)
 if result.error != OK or mapping.has_section_key("deleted_identities", old.identity): return result
 var empty := -1
 for slot in capacity:
  var data := summary(slot)
  if data.exists and data.identity == old.identity: return result
  if not data.exists and empty < 0: empty = slot
 result.skip = false
 result.slot = capacity if empty < 0 else empty
 result.profile = old
 result.mapping = mapping
 if result.slot >= MAX_COUNT: result.error = ERR_INVALID_PARAMETER
 return result

func _legacy_import(source: String, legacy_slot: int, candidate: Dictionary) -> Error:
 var slot: int = candidate.slot
 if slot == candidate.capacity:
  var expanded := set_capacity(slot + 1)
  if expanded != OK: return expanded
 var error := claim(slot)
 if error != OK: return error
 var old: RefCounted = candidate.profile
 old.path = _legacy_profile_path(slot)
 if old.data.name == "Wanderer": old.data.name = "Wanderer %d" % (legacy_slot + 1)
 error = old.save_profile()
 release(slot)
 if error != OK: return error
 var mapping := ConfigFile.new()
 mapping.load(_catalog_path())
 mapping.set_value("imports", source, old.identity)
 return Batch.write(_catalog_path(), mapping.encode_to_text().to_utf8_buffer())

func update(slot: int,name: String,class_id: int,appearance: Array) -> Error:
 var location := paths(slot)
 if location.is_empty(): return ERR_INVALID_PARAMETER
 return Batch.Legacy.run(PackedStringArray([location.character, _catalog_path()]), func(_plan):
  if paths(slot) != location: return ERR_BUSY
  return _legacy_update(slot, name, class_id, appearance), PackedStringArray([location.character + ".pre-content-v2.bak"]))

func _legacy_update(slot: int,name: String,class_id: int,appearance: Array) -> Error:
 if Profile.clean_name(name).is_empty() or class_id<0 or class_id>=Profile.Classes.DEFINITIONS.size(): return ERR_INVALID_PARAMETER
 var location=paths(slot)
 if location.is_empty(): return ERR_INVALID_PARAMETER
 var error=claim(slot)
 if error!=OK: return error
 var profile=Profile.new();profile.path=location.character
 error=profile.load_profile()
 if error==OK and Profile.Custody.locked(profile.inventory_custody):error=ERR_BUSY
 if error==OK:
  profile.data.name=Profile.clean_name(name);profile.data.active_class=class_id
  profile.data.appearance=preload("res://character_appearance.gd").normalize(appearance)
  error=profile.save_profile()
 release(slot)
 return error

func delete_character(slot: int,confirmed: bool=false,expected_digest: String="") -> Error:
 var location := paths(slot)
 if location.is_empty(): return ERR_INVALID_PARAMETER
 return Batch.Legacy.run(PackedStringArray([location.character, _catalog_path()]), func(_plan):
  if paths(slot) != location: return ERR_BUSY
  return _legacy_delete_character(slot, confirmed, expected_digest))

func _legacy_delete_character(slot: int,confirmed: bool=false,expected_digest: String="") -> Error:
 if not confirmed:return ERR_UNAUTHORIZED
 var location=paths(slot)
 if location.is_empty():return ERR_INVALID_PARAMETER
 if is_active(slot):return ERR_BUSY
 var error=claim(slot)
 if error!=OK:return error
 error=remove_character(location,expected_digest)
 release(slot);return error
func remove_character(location: Dictionary,expected_digest: String) -> Error:
 if location.get("character") != location.get("directory", "").path_join("character.cfg"):
  return ERR_INVALID_PARAMETER
 return Batch.Legacy.run(PackedStringArray([location.character, _catalog_path()]), func(_plan):
  return _legacy_remove_character(location, expected_digest))

func _legacy_remove_character(location: Dictionary,expected_digest: String) -> Error:
 var error=Batch.recover(location.character)
 if error!=OK:return error
 if not FileAccess.file_exists(location.character):return ERR_DOES_NOT_EXIST
 if Profile.Custody.file_held(location.character):return ERR_BUSY
 if not expected_digest.is_empty() and FileAccess.get_sha256(location.character)!=expected_digest:return ERR_BUSY
 var archive: String=location.directory.path_join("backups/deleted-character-"+Crypto.new().generate_random_bytes(8).hex_encode())
 error=DirAccess.make_dir_recursive_absolute(archive)
 if error==OK:error=DirAccess.copy_absolute(location.character,archive.path_join("character.cfg"))
 if error!=OK:return error
 var source=ConfigFile.new();source.load(location.character)
 var identity: String=str(source.get_value("character","identity",""))
 var catalog_path: String=root_path.path_join("catalog.cfg")
 var existed=FileAccess.file_exists(catalog_path);var before=FileAccess.get_file_as_bytes(catalog_path) if existed else PackedByteArray()
 var catalog=ConfigFile.new();catalog.load(catalog_path)
 if Profile.valid_identity(identity):catalog.set_value("deleted_identities",identity,archive)
 catalog.set_value("deleted_slots",str(location.directory),archive)
 error=Batch.write(catalog_path,catalog.encode_to_text().to_utf8_buffer())
 if error!=OK:return error
 error=DirAccess.remove_absolute(location.character)
 if error!=OK:
  if existed:Batch.write(catalog_path,before)
  else:DirAccess.remove_absolute(catalog_path)
 return error

## Dormant Group 2A roster entry points.
const Ops = preload("res://persistence_operations.gd")
const Auth = preload("res://persistence_authorization.gd")
const Plan = preload("res://persistence_recovery_plan.gd")
var _guarded_leases := Slots.new()

func _catalog_path() -> String:
 return root_path.path_join("catalog.cfg")

func _slot_profile(slot: int) -> String:
 return root_path.path_join("slot_%d/character.cfg" % (slot + 1))

func delete_character_guarded(slot: int, confirmed := false, digest := "") -> Dictionary:
 return _delete_guarded(slot, confirmed, digest)

func _delete_guarded(slot: int, confirmed: bool, digest: String, fault := Callable(), archive_override := "") -> Dictionary:
 if not confirmed or slot < 0 or slot >= MAX_COUNT:
  return Ops.management_result(ERR_INVALID_PARAMETER if confirmed else ERR_UNAUTHORIZED, "deletion_not_confirmed")
 var source := _slot_profile(slot)
 var directory := source.get_base_dir()
 var ready := Auth.bootstrap(PackedStringArray([directory]))
 if ready.error != OK:
  return ready
 var catalog := _catalog_path()
 var blocked := Ops.archive_preflight(PackedStringArray([source, catalog]))
 if not blocked.is_empty():
  return blocked
 var confirmation := digest if not digest.is_empty() else Slots._save_digest(source)
 var archive := archive_override if not archive_override.is_empty() else Slots._archive_folder(directory, "deleted-character-")
 ready = Auth.bootstrap_archive(archive, source)
 if ready.error != OK:
  return ready
 var targets := Slots._archive_targets(archive, PackedStringArray([source]))
 return Ops.run_management(PackedStringArray([source, catalog]), Slots._archive_scope(targets) + PackedStringArray([catalog + ".tmp"]), func(context):
  if source != _slot_profile(slot) or catalog != _catalog_path():
   return Ops.management_result(ERR_BUSY, "destination_changed")
  var current := _read_catalog()
  if current.error != OK or slot >= current.get("capacity", 0):
   return Ops.management_result(ERR_INVALID_DATA, "roster_capacity_changed")
  if is_active(slot):
   return Ops.management_result(ERR_BUSY, "slot_in_use")
  if FileAccess.file_exists(catalog + ".tmp"):
   return Ops.management_result(ERR_BUSY, "metadata_scratch_pending", "unresolved")
  var actual := Slots._save_digest(source)
  if actual.is_empty() or actual != confirmation:
   return Ops.management_result(ERR_UNAUTHORIZED, "stale_deletion_confirmation")
  if actual == "absent":
   return Ops.management_result(ERR_DOES_NOT_EXIST, "save_missing")
  return _remove_character_guarded(context, source, archive, targets, current.file, catalog, fault))

func _remove_character_guarded(context: RefCounted, source: String, archive: String, targets: Dictionary, catalog: ConfigFile, catalog_path: String, fault: Callable) -> Dictionary:
 var authorized := Ops.run_nested(context, PackedStringArray([source, catalog_path]), func(_context):
  var profile := Profile.new()
  profile.path = source
  profile.identity = ""
  var error := profile.load_profile(false)
  if error != OK or not Profile.valid_identity(profile.identity):
   return Ops.management_result(error if error != OK else ERR_INVALID_DATA, "roster_identity_unverified")
  if Profile.Custody.locked(profile.inventory_custody):return Ops.management_result(ERR_BUSY,"inventory_custody_held")
  var prepared := Ops.archive_copies(context, targets, fault)
  if prepared.error != OK:
   return prepared
  catalog.set_value("deleted_identities", profile.identity, archive)
  catalog.set_value("deleted_slots", source.get_base_dir(), archive)
  var result := Ops.transaction_result(Ops.commit_bytes(context, {catalog_path: catalog.encode_to_text().to_utf8_buffer()}, source, fault, PackedStringArray([source])))
  result.archives = prepared.archives
  return result)
 return authorized.value if authorized.ran else authorized

func _read_catalog() -> Dictionary:
 var file := ConfigFile.new()
 var path := _catalog_path()
 var error := file.load(path) if FileAccess.file_exists(path) else OK
 if error != OK:
  return {"error": error}
 return {"error": OK, "file": file, "capacity": clampi(int(file.get_value("roster", "capacity", INITIAL_COUNT)), INITIAL_COUNT, MAX_COUNT)}

func create_guarded(slot: int, name: String, class_id: int, appearance: Array) -> Dictionary:
 return _edit_guarded(slot, name, class_id, appearance, false)

func update_guarded(slot: int, name: String, class_id: int, appearance: Array, digest := "") -> Dictionary:
 return _edit_guarded(slot, name, class_id, appearance, true, digest)

func _edit_guarded(slot: int, name: String, class_id: int, appearance: Array, editing: bool, digest := "", fault := Callable()) -> Dictionary:
 var cleaned := Profile.clean_name(name)
 if slot < 0 or slot >= MAX_COUNT or cleaned.is_empty() or class_id < 0 or class_id >= Profile.Classes.DEFINITIONS.size():
  return Ops.management_result(ERR_INVALID_PARAMETER, "invalid_character")
 var profile := Profile.new()
 profile.path = _slot_profile(slot)
 var ready := Auth.bootstrap(PackedStringArray([profile.path.get_base_dir()]))
 if ready.error != OK:
  return ready
 var catalog := _catalog_path()
 var scope := Ops._serializer_scope([profile])
 return Ops.run_management(scope.paths, scope.auxiliary + PackedStringArray([catalog, catalog + ".tmp"]), func(context):
  var read := _read_catalog()
  if read.error != OK or slot >= read.get("capacity", 0) or profile.path != _slot_profile(slot) or catalog != _catalog_path():
   return Ops.management_result(ERR_INVALID_DATA, "roster_capacity_changed")
  if FileAccess.file_exists(catalog + ".tmp"):
   return Ops.management_result(ERR_BUSY, "metadata_scratch_pending", "unresolved")
  if is_active(slot):
   return Ops.management_result(ERR_BUSY, "slot_in_use")
  if FileAccess.file_exists(profile.path) != editing:
   return Ops.management_result(ERR_FILE_NOT_FOUND if editing else ERR_ALREADY_EXISTS, "character_vacancy_changed")
  if editing:
   if not digest.is_empty() and Slots._save_digest(profile.path) != digest:
    return Ops.management_result(ERR_UNAUTHORIZED, "stale_profile_confirmation")
   # A load of an old profile can leave the default identity in place.
   # Require a saved identity before an edit can replace canonical bytes.
   profile.identity = ""
   var loaded := profile.load_profile(false)
   if loaded != OK:
    return Ops.management_result(loaded, "profile_unreadable")
   if not Profile.valid_identity(profile.identity):
    return Ops.management_result(ERR_INVALID_DATA, "roster_identity_unverified")
   if Profile.Custody.locked(profile.inventory_custody):return Ops.management_result(ERR_BUSY,"inventory_custody_held")
   profile.data.name = cleaned
   profile.data.active_class = class_id
   profile.data.appearance = preload("res://character_appearance.gd").normalize(appearance)
  else:
   profile.data = Profile.normalize({"name": cleaned, "active_class": class_id, "appearance": appearance})
  return Ops.transaction_result(Ops.commit_serializers(context, [profile], profile.path, profile.save_profile, fault)))

func set_capacity_guarded(amount: int) -> Dictionary:
 if amount < INITIAL_COUNT or amount > MAX_COUNT:
  return Ops.management_result(ERR_INVALID_PARAMETER, "invalid_capacity")
 return _write_catalog_guarded(0, func(info):
  if amount < info.capacity:
   return ERR_INVALID_PARAMETER
  info.file.set_value("roster", "capacity", amount)
  return OK)

func remember_guarded(slot: int) -> Dictionary:
 return _write_catalog_guarded(clampi(slot, 0, count() - 1), func(info):
  info.file.set_value("roster", "selected", clampi(slot, 0, info.capacity - 1))
  return OK)

func _write_catalog_guarded(slot: int, change: Callable) -> Dictionary:
 var participant := _slot_profile(slot)
 var ready := Auth.bootstrap(PackedStringArray([participant.get_base_dir()]))
 if ready.error != OK:
  return ready
 var catalog := _catalog_path()
 return Ops.run_management(PackedStringArray([participant]), PackedStringArray([catalog, catalog + ".tmp"]), func(context):
  if participant != _slot_profile(slot) or catalog != _catalog_path():
   return Ops.management_result(ERR_BUSY, "destination_changed")
  var info := _read_catalog()
  if info.error != OK:
   return Ops.management_result(info.error, "catalog_unreadable")
  var error: Error = change.call(info)
  if error != OK:
   return Ops.management_result(error, "catalog_precondition_failed")
  return Ops.write_metadata(context, catalog, info.file))

func claim_guarded(slot: int) -> Dictionary:
 return _change_lease(slot, "claim")

func heartbeat_guarded(slot: int) -> Dictionary:
 return _change_lease(slot, "heartbeat")

func release_guarded(slot: int) -> Dictionary:
 return _change_lease(slot, "release")

func owns_guarded_lease(slot: int) -> bool:
 return _guarded_leases.root_path == root_path and _guarded_leases.owns_guarded_lease(slot)

func _change_lease(slot: int, operation: String) -> Dictionary:
 _guarded_leases.root_path = root_path
 _guarded_leases.capacity = count()
 return _guarded_leases._lease_guarded(slot, operation, true, _catalog_path())

func prepare_guarded(worlds: RefCounted) -> Dictionary:
 var imported := 0
 for slot in Slots.COUNT:
  var result := _import_guarded(worlds.paths(slot).character, slot)
  var outcome: Dictionary = result.value if result.get("ran", false) else result
  if outcome.error != OK:
   outcome.imported = imported
   if imported > 0:
    outcome.partial = true
    if outcome.get("state") not in ["pending_recovery", "unresolved", "committed_cleanup_pending"]:
     outcome.state = "partial_completion"
   return result
  imported += int(outcome.get("imported", false))
 var completed := Ops.management_result(OK, "")
 completed.imported = imported
 return completed

func _import_guarded(source: String, legacy_slot: int, selected := {}, fault := Callable()) -> Dictionary:
 var first := _slot_profile(0)
 var ready := Auth.bootstrap(PackedStringArray([first.get_base_dir(), source.get_base_dir()]))
 if ready.error != OK:
  return ready
 var input := _import_candidate(source) if selected.is_empty() else selected
 if input.error != OK:
  return input
 var destination: String = input.get("destination", first)
 ready = Auth.bootstrap(PackedStringArray([destination.get_base_dir()]))
 if ready.error != OK:
  return ready
 var profile := Profile.new()
 profile.path = destination
 var catalog := _catalog_path()
 var scope := Ops._serializer_scope([profile])
 var participants := PackedStringArray([source, destination])
 return Ops.run_management(participants, scope.auxiliary + PackedStringArray([catalog, catalog + ".tmp"]), func(context):
  var current := _import_candidate(source)
  if current != input or catalog != _catalog_path():
   return Ops.management_result(ERR_BUSY, "roster_import_selection_changed")
  if not current.has("destination"):
   if FileAccess.file_exists(catalog + ".tmp"):
    return Ops.management_result(ERR_BUSY, "metadata_scratch_pending", "unresolved")
   return Ops.management_result(OK, "")
  var info := _read_catalog()
  if info.error != OK:
   return Ops.management_result(info.error, "catalog_unreadable")
  var target_slot: int = current.slot
  if FileAccess.file_exists(catalog + ".tmp"):
   return Ops.management_result(ERR_BUSY, "metadata_scratch_pending", "unresolved")
  if FileAccess.file_exists(destination) or is_active(target_slot):
   return Ops.management_result(ERR_BUSY, "roster_destination_changed")
  profile.path = source
  var loaded := profile.load_profile(false)
  profile.path = destination
  if loaded != OK or profile.identity != current.identity:
   return Ops.management_result(ERR_INVALID_DATA, "legacy_identity_changed")
  if profile.data.name == "Wanderer":
   profile.data.name = "Wanderer %d" % (legacy_slot + 1)
  if target_slot == info.capacity:
   info.file.set_value("roster", "capacity", target_slot + 1)
   var expanded := Ops.write_metadata(context, catalog, info.file)
   if expanded.error != OK:
    return expanded
  var outcome := Ops.transaction_result(Ops.commit_serializers(context, [profile], destination, profile.save_profile, fault))
  if outcome.error != OK:
   if target_slot == info.capacity:
    outcome.capacity_expanded = true
    outcome.partial = true
    if outcome.state not in ["pending_recovery", "unresolved", "committed_cleanup_pending"]:
     outcome.state = "partial_completion"
   return outcome
  info.file.set_value("imports", source, current.identity)
  var mapped := Ops.write_metadata(context, catalog, info.file)
  mapped.imported = true
  if mapped.error != OK:
   mapped.state = "partial_completion" if mapped.state != "unresolved" else mapped.state
   mapped.reason = "profile_committed_" + mapped.reason
  return mapped)

## Read-only selection is recomputed under the root lock before import. No
## recovery-capable summary calls are used to identify a vacant destination.
func _import_candidate(source: String) -> Dictionary:
 if FileAccess.file_exists(_catalog_path() + ".tmp"):
  return Ops.management_result(ERR_BUSY, "metadata_scratch_pending", "unresolved")
 var catalog := _read_catalog()
 if catalog.error != OK:
  return Ops.management_result(catalog.error, "catalog_unreadable")
 var source_plan := Plan.discover(PackedStringArray([source]))
 if not source_plan.state in ["empty", "healthy"]:
  return Ops.management_result(ERR_BUSY, source_plan.reason, source_plan.state)
 if not FileAccess.file_exists(source) or catalog.file.has_section_key("imports", source):
  return Ops.management_result(OK, "")
 var source_file := ConfigFile.new()
 var error := source_file.load(source)
 if error != OK:
  return Ops.management_result(error, "legacy_profile_unreadable")
 var identity: Variant = source_file.get_value("character", "identity", "")
 if not identity is String or not Profile.valid_identity(identity):
  return Ops.management_result(ERR_INVALID_DATA, "legacy_identity_unverified")
 if catalog.file.has_section_key("deleted_identities", identity):
  return Ops.management_result(OK, "")
 var vacancy := -1
 var roster_paths := PackedStringArray()
 for slot in catalog.capacity:
  roster_paths.append(_slot_profile(slot))
 # Read the whole roster's evidence as a bounded observation, not as a
 # mutation capability. Only the preselected destination enters the scope.
 var roster_plan := Plan.discover(roster_paths)
 if not roster_plan.state in ["empty", "healthy"]:
  return Ops.management_result(ERR_BUSY, roster_plan.reason, roster_plan.state)
 for slot in catalog.capacity:
  var path := _slot_profile(slot)
  if not FileAccess.file_exists(path):
   if vacancy < 0:
    vacancy = slot
   continue
  var existing := ConfigFile.new()
  error = existing.load(path)
  if error != OK:
   return Ops.management_result(error, "roster_identity_unreadable")
  if existing.get_value("character", "identity", "") == identity:
   return Ops.management_result(OK, "")
 if vacancy < 0:
  if catalog.capacity >= MAX_COUNT:
   return Ops.management_result(ERR_OUT_OF_MEMORY, "roster_full")
  vacancy = catalog.capacity
 return {"error": OK, "slot": vacancy, "destination": _slot_profile(vacancy), "identity": identity}
