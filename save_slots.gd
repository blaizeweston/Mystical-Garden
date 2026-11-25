extends RefCounted
const Progress = preload("res://progress.gd")
const Character = preload("res://character_profile.gd")
const COUNT := 3
const Legacy = preload("res://legacy_persistence.gd")
var capacity:=COUNT
var root_path := "user://saves"
var legacy_garden := "user://garden.cfg"
var legacy_character := "user://character.cfg"
var legacy_guest := "user://character-local-guest.cfg"

func _legacy_scope(location: Dictionary, pair := true) -> PackedStringArray:
	var profile: String = location.character
	if root_path.get_file() == "characters": return PackedStringArray([profile])
	return PackedStringArray([location.garden, profile]) if pair else PackedStringArray([location.garden])

func paths(slot: int) -> Dictionary:
	var base := root_path.path_join("slot_%d" % (clampi(slot,0,capacity-1)+1))
	return {"directory":base,"garden":base.path_join("garden.cfg"),"character":base.path_join("character.cfg")}

func prepare(import_legacy: bool = true) -> Error:
	var garden := import_legacy and _imports_garden()
	var guest := import_legacy and _imports_guest()
	if not garden and not guest:
		if Legacy.fixture_path(root_path): return DirAccess.make_dir_recursive_absolute(root_path)
		return Legacy.Auth.bootstrap(PackedStringArray([root_path])).error
	var scope := PackedStringArray()
	if garden: scope.append_array(PackedStringArray([legacy_garden, legacy_character, paths(0).garden, paths(0).character]))
	if guest: scope.append_array(PackedStringArray([legacy_guest, paths(1).garden, paths(1).character]))
	return Legacy.run(scope, func(_plan):
		if _imports_garden() != garden or _imports_guest() != guest: return ERR_BUSY
		return _legacy_prepare(garden, guest))

func _imports_garden() -> bool:
	return not FileAccess.file_exists(paths(0).directory.path_join("deleted.cfg")) and not FileAccess.file_exists(paths(0).garden) and FileAccess.file_exists(legacy_garden)

func _imports_guest() -> bool:
	return not FileAccess.file_exists(paths(1).directory.path_join("deleted.cfg")) and FileAccess.file_exists(legacy_guest) and not FileAccess.file_exists(paths(1).character) and not FileAccess.file_exists(paths(1).garden)

func _legacy_prepare(garden: bool, guest: bool) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(root_path)
	if error != OK: return error
	if garden:
		error = DirAccess.make_dir_recursive_absolute(paths(0).directory)
		if error != OK: return error
		error = DirAccess.copy_absolute(legacy_garden,paths(0).garden)
		if error != OK: return error
		if FileAccess.file_exists(legacy_character) and not FileAccess.file_exists(paths(0).character):
			error = DirAccess.copy_absolute(legacy_character,paths(0).character)
			if error != OK: return error
	if guest:
		error = DirAccess.make_dir_recursive_absolute(paths(1).directory)
		if error != OK: return error
		error = DirAccess.copy_absolute(legacy_guest,paths(1).character)
	return error

func summary(slot: int) -> Dictionary:
	var location := paths(slot)
	var result := {"exists":false,"character":FileAccess.file_exists(location.character),"active":is_active(slot),"knowledge":0,"plots":3,"best":0,"error":OK}
	if not FileAccess.file_exists(location.garden):
		return result
	var file := ConfigFile.new()
	result.error = file.load(location.garden)
	result.exists = true
	if result.error != OK:
		return result
	var suspended: Variant = file.get_value("expedition","suspended",{})
	result.suspended_owner = suspended.get("owner","") if suspended is Dictionary else ""
	result.knowledge = int(file.get_value("garden","knowledge",0))
	result.best = int(file.get_value("campaign","best_clear",0))
	var beds = file.get_value("garden","plots_v2",[])
	result.plots = beds.size() if beds is Array and not beds.is_empty() else 3
	return result

func ensure_character(slot: int) -> Error:
	if slot < 0 or slot >= capacity: return ERR_INVALID_PARAMETER
	var location := paths(slot)
	return Legacy.run(PackedStringArray([location.character]), func(_plan): return _legacy_ensure_character(slot))

func _legacy_ensure_character(slot: int) -> Error:
	if slot < 0 or slot >= capacity:
		return ERR_INVALID_PARAMETER
	if is_active(slot): return ERR_BUSY
	var location := paths(slot)
	var error := DirAccess.make_dir_recursive_absolute(location.directory)
	if error != OK: return error
	if FileAccess.file_exists(location.character):
		var profile := Character.new()
		profile.path = location.character
		return profile.load_profile(false)
	var character := Character.new()
	character.path = location.character
	return character.save_profile()

func new_game(slot: int, replace_confirmed: bool = false) -> Error:
	if slot < 0 or slot >= capacity: return ERR_INVALID_PARAMETER
	var location := paths(slot)
	return Legacy.run(_legacy_scope(location, true), func(_plan): return _legacy_new_game(slot, replace_confirmed), PackedStringArray([location.garden + ".new", location.character + ".new"]))

func _legacy_new_game(slot: int, replace_confirmed: bool = false) -> Error:
	if slot < 0 or slot >= capacity:
		return ERR_INVALID_PARAMETER
	if is_active(slot): return ERR_BUSY
	var location := paths(slot)
	var occupied := FileAccess.file_exists(location.garden) or FileAccess.file_exists(location.character)
	if occupied and not replace_confirmed:
		return ERR_ALREADY_EXISTS
	if [location.garden, location.character].any(func(path): return FileAccess.file_exists(path + ".new") or DirAccess.dir_exists_absolute(path + ".new")):
		return ERR_BUSY
	var error := DirAccess.make_dir_recursive_absolute(location.directory)
	if error != OK: return error
	if occupied:
		var stamp := Time.get_datetime_string_from_system().replace(":","-") + "-" + str(Time.get_ticks_msec())
		var archive: String = location.directory.path_join("backups").path_join(stamp)
		error = Legacy.create_archive(archive, location.garden)
		if error != OK: return error
		for field in ["garden","character"]:
			if FileAccess.file_exists(location[field]):
				error = DirAccess.copy_absolute(location[field], archive.path_join(field+".cfg"))
				if error != OK: return error
	var fresh := Progress.new()
	fresh.path = location.garden
	var profile := Character.new()
	profile.path = location.character
	# Save both fresh files before replacing either current file.
	var garden_target: String = fresh.path
	var character_target: String = profile.path
	var batch = load("res://save_batch.gd")
	error = fresh._serialize_save(func(_path, bytes): return batch._write_bytes(garden_target + ".new", bytes))
	if error != OK: return error
	error = profile._serialize_save(func(_path, bytes): return batch._write_bytes(character_target + ".new", bytes))
	if error != OK: return error
	error = DirAccess.rename_absolute(garden_target + ".new", garden_target)
	if error != OK: return error
	return DirAccess.rename_absolute(character_target + ".new", character_target)


func is_active(slot: int) -> bool:
	var marker := ConfigFile.new()
	if marker.load(paths(slot).directory.path_join("session.cfg")) != OK:
		return false
	var updated := float(marker.get_value("session","updated",0.0))
	return Time.get_unix_time_from_system() - updated < 30.0

func claim(slot: int) -> Error:
	if slot < 0 or slot >= capacity: return ERR_INVALID_PARAMETER
	var location := paths(slot)
	return Legacy.run(_legacy_scope(location), func(_plan): return _legacy_claim(slot))

func _legacy_claim(slot: int) -> Error:
	if slot < 0 or slot >= capacity: return ERR_INVALID_PARAMETER
	if is_active(slot): return ERR_BUSY
	var error := DirAccess.make_dir_recursive_absolute(paths(slot).directory)
	if error != OK: return error
	var marker := ConfigFile.new()
	marker.set_value("session","process_id",OS.get_process_id())
	marker.set_value("session","updated",Time.get_unix_time_from_system())
	return marker.save(paths(slot).directory.path_join("session.cfg"))

func heartbeat(slot: int) -> void:
	if slot < 0 or slot >= capacity: return
	var location := paths(slot)
	Legacy.run(_legacy_scope(location), func(_plan):
		_legacy_heartbeat(slot)
		return OK)

func _legacy_heartbeat(slot: int) -> void:
	var file: String = paths(slot).directory.path_join("session.cfg")
	var marker := ConfigFile.new()
	if marker.load(file) != OK or int(marker.get_value("session","process_id",0)) != OS.get_process_id():
		return
	marker.set_value("session","updated",Time.get_unix_time_from_system())
	if marker.save(file+".tmp") == OK:
		DirAccess.rename_absolute(file+".tmp",file)

func release(slot: int) -> void:
	if slot < 0 or slot >= capacity: return
	var location := paths(slot)
	Legacy.run(_legacy_scope(location), func(_plan):
		_legacy_release(slot)
		return OK)

func _legacy_release(slot: int) -> void:
	var file: String = paths(slot).directory.path_join("session.cfg")
	if not FileAccess.file_exists(file): return
	var marker := ConfigFile.new()
	if marker.load(file) == OK and int(marker.get_value("session","process_id",0)) == OS.get_process_id():
		DirAccess.remove_absolute(file)


func last_slot() -> int:
	var settings := ConfigFile.new()
	if settings.load(root_path.path_join("settings.cfg")) != OK:
		return 0
	return clampi(int(settings.get_value("menu","last_slot",0)),0,capacity-1)

func remember_slot(slot: int) -> void:
	var preference := root_path.path_join("settings.cfg")
	Legacy.run(_legacy_scope(paths(slot)), func(_plan): return _legacy_remember_slot(slot), PackedStringArray([preference, preference + ".tmp"]))

func _legacy_remember_slot(slot: int) -> Error:
	var settings := ConfigFile.new()
	settings.set_value("menu","last_slot",clampi(slot,0,capacity-1))
	return settings.save(root_path.path_join("settings.cfg"))


func delete_save(slot: int,confirmed: bool=false) -> Error:
	if slot < 0 or slot >= capacity: return ERR_INVALID_PARAMETER
	var location := paths(slot)
	return Legacy.run(_legacy_scope(location, true), func(_plan): return _legacy_delete_save(slot, confirmed))

func _legacy_delete_save(slot: int,confirmed: bool=false) -> Error:
	if slot<0 or slot>=capacity: return ERR_INVALID_PARAMETER
	if not confirmed: return ERR_UNAUTHORIZED
	if is_active(slot): return ERR_BUSY
	var location:=paths(slot)
	if not FileAccess.file_exists(location.garden) and not FileAccess.file_exists(location.character): return ERR_DOES_NOT_EXIST
	var error:=claim(slot)
	if error!=OK: return error
	error=archive_deleted_save(location)
	release(slot)
	return error

func archive_deleted_save(location: Dictionary) -> Error:
	if location.get("garden") != location.get("directory", "").path_join("garden.cfg") or location.get("character") != location.get("directory", "").path_join("character.cfg"):
		return ERR_INVALID_PARAMETER
	return Legacy.run(_legacy_scope(location, true), func(_plan): return _legacy_archive_deleted_save(location))

func _legacy_archive_deleted_save(location: Dictionary) -> Error:
	# Move only the two live save files. Existing recovery archives remain intact.
	var stamp:=Time.get_datetime_string_from_system().replace(":","-")+"-"+Crypto.new().generate_random_bytes(6).hex_encode()
	var archive: String=location.directory.path_join("backups").path_join("deleted-"+stamp)
	var error:=Legacy.create_archive(archive, location.garden)
	if error!=OK: return error
	var moved: Array=[]
	for field in ["garden","character"]:
		if not FileAccess.file_exists(location[field]): continue
		error=DirAccess.rename_absolute(location[field],archive.path_join(field+".cfg"))
		if error!=OK:
			return restore_deleted_save(location,archive,moved,error)
		moved.append(field)
	# Remember explicit deletion so old legacy files cannot silently repopulate the slot.
	var marker:=ConfigFile.new()
	marker.set_value("deletion","archive",archive)
	var target: String=location.directory.path_join("deleted.cfg")
	error=marker.save(target+".tmp")
	if error==OK: error=DirAccess.rename_absolute(target+".tmp",target)
	if error!=OK: return restore_deleted_save(location,archive,moved,error)
	return OK

func restore_deleted_save(location: Dictionary,archive: String,moved: Array,error: Error) -> Error:
	if not Legacy.fixture_path(location.garden):
		if location.get("garden") != location.get("directory", "").path_join("garden.cfg") or location.get("character") != location.get("directory", "").path_join("character.cfg"):
			return ERR_INVALID_PARAMETER
		if not Legacy.held() or not Legacy.Layout.archive_folder(archive, location.garden, Legacy.Layout.directories()):
			return ERR_UNAUTHORIZED
		if not moved.all(func(field): return field in ["garden", "character"]): return ERR_INVALID_PARAMETER
	return Legacy.run(_legacy_scope(location, true), func(_plan):
		return _restore_deleted_save_locked(location, archive, moved, error))

func _restore_deleted_save_locked(location: Dictionary,archive: String,moved: Array,error: Error) -> Error:
	for field in moved:
		var restored:=DirAccess.rename_absolute(archive.path_join(field+".cfg"),location[field])
		if restored!=OK: return restored
	return error

# World-only operations used by the independent-character main menu.
func new_world(slot: int,confirmed: bool=false) -> Error:
	if slot < 0 or slot >= capacity: return ERR_INVALID_PARAMETER
	var location := paths(slot)
	return Legacy.run(_legacy_scope(location), func(_plan): return _legacy_new_world(slot, confirmed))

func _legacy_new_world(slot: int,confirmed: bool=false) -> Error:
	if slot<0 or slot>=capacity: return ERR_INVALID_PARAMETER
	if is_active(slot): return ERR_BUSY
	var location:=paths(slot)
	if FileAccess.file_exists(location.garden) and not confirmed: return ERR_ALREADY_EXISTS
	var error:=DirAccess.make_dir_recursive_absolute(location.directory)
	if error!=OK: return error
	if FileAccess.file_exists(location.garden):
		var backup: String=location.directory.path_join("backups/world-"+Crypto.new().generate_random_bytes(8).hex_encode())
		error=Legacy.create_archive(backup, location.garden)
		if error==OK: error=DirAccess.copy_absolute(location.garden,backup.path_join("garden.cfg"))
		if error!=OK: return error
	var world:=Progress.new();world.path=location.garden
	return world.save_garden()

func delete_world(slot: int,confirmed: bool=false) -> Error:
	if slot < 0 or slot >= capacity: return ERR_INVALID_PARAMETER
	var location := paths(slot)
	return Legacy.run(_legacy_scope(location), func(_plan): return _legacy_delete_world(slot, confirmed))

func _legacy_delete_world(slot: int,confirmed: bool=false) -> Error:
	if slot<0 or slot>=capacity: return ERR_INVALID_PARAMETER
	if not confirmed: return ERR_UNAUTHORIZED
	if is_active(slot): return ERR_BUSY
	var location:=paths(slot)
	if not FileAccess.file_exists(location.garden): return ERR_DOES_NOT_EXIST
	var error:=claim(slot)
	if error!=OK: return error
	var archive: String=location.directory.path_join("backups/deleted-world-"+Crypto.new().generate_random_bytes(8).hex_encode())
	error=Legacy.create_archive(archive, location.garden)
	if error==OK: error=DirAccess.copy_absolute(location.garden,archive.path_join("garden.cfg"))
	# Write the tombstone before removal so legacy imports cannot resurrect the world.
	if error==OK:
		var marker:=ConfigFile.new();marker.set_value("deletion","archive",archive)
		error=preload("res://save_batch.gd").write(location.directory.path_join("deleted.cfg"),marker.encode_to_text().to_utf8_buffer())
	if error==OK: error=DirAccess.remove_absolute(location.garden)
	release(slot);return error

## Dormant Group 2A routes. Keep the legacy entry points until cutover.
const Ops = preload("res://persistence_operations.gd")
const Auth = preload("res://persistence_authorization.gd")
const Plan = preload("res://persistence_recovery_plan.gd")
var _owned_markers := {}

func prepare_guarded(import_legacy := true) -> Dictionary:
	if not import_legacy:
		var bootstrap := Auth.bootstrap(PackedStringArray([root_path]))
		return Ops.management_result(bootstrap.error, "" if bootstrap.error == OK else "directory_bootstrap_failed")
	if capacity < 2:
		return Ops.management_result(ERR_INVALID_PARAMETER, "invalid_world_capacity")
	var first := paths(0)
	var second := paths(1)
	var ready := Auth.bootstrap(PackedStringArray([first.directory, second.directory]))
	if ready.error != OK:
		return ready
	var sources := [legacy_garden, legacy_character, legacy_guest]
	var participants := PackedStringArray([legacy_garden, legacy_character, legacy_guest,
		first.garden, first.character, second.garden, second.character])
	var first_tombstone: String = first.directory.path_join("deleted.cfg")
	var second_tombstone: String = second.directory.path_join("deleted.cfg")
	var auxiliary := PackedStringArray([first_tombstone, second_tombstone, first_tombstone + ".tmp", second_tombstone + ".tmp"])
	return Ops.run_management(participants, auxiliary, func(context):
		if paths(0) != first or paths(1) != second or sources != [legacy_garden, legacy_character, legacy_guest]:
			return Ops.management_result(ERR_BUSY, "destination_changed")
		if is_active(0) or is_active(1):
			return Ops.management_result(ERR_BUSY, "slot_in_use")
		if FileAccess.file_exists(first_tombstone + ".tmp") or FileAccess.file_exists(second_tombstone + ".tmp"):
			return Ops.management_result(ERR_BUSY, "deletion_publication_pending", "unresolved")
		var imported := {}
		if not FileAccess.file_exists(first_tombstone) and not FileAccess.file_exists(first.garden) and FileAccess.file_exists(legacy_garden):
			imported[first.garden] = legacy_garden
			if not FileAccess.file_exists(first.character) and FileAccess.file_exists(legacy_character):
				imported[first.character] = legacy_character
		if not FileAccess.file_exists(second_tombstone) and not FileAccess.file_exists(second.garden) and not FileAccess.file_exists(second.character) and FileAccess.file_exists(legacy_guest):
			imported[second.character] = legacy_guest
		if imported.is_empty():
			return Ops.management_result(OK, "")
		var staged := {}
		for target: String in imported:
			var source := Plan._read_bytes(imported[target])
			if not source.ok:
				return Ops.management_result(ERR_FILE_CANT_READ, source.reason)
			staged[target] = source.bytes
		return Ops.transaction_result(Ops.commit_bytes(context, staged, staged.keys()[0])))

func ensure_character_guarded(slot: int) -> Dictionary:
	return _initialize_guarded(slot, false, false, true)

func new_game_guarded(slot: int, replace_confirmed := false, digests := {}) -> Dictionary:
	return _initialize_guarded(slot, true, replace_confirmed, false, Callable(), "", digests)

func new_world_guarded(slot: int, confirmed := false, digest := "") -> Dictionary:
	return _initialize_guarded(slot, false, confirmed, false, Callable(), "", {} if digest.is_empty() else {paths(slot).garden: digest})

func _initialize_guarded(slot: int, pair: bool, confirmed: bool, character_only := false, fault := Callable(), archive_override := "", digests := {}) -> Dictionary:
	if slot < 0 or slot >= capacity:
		return Ops.management_result(ERR_INVALID_PARAMETER, "invalid_slot")
	var location := paths(slot)
	var ready := Auth.bootstrap(PackedStringArray([location.directory]))
	if ready.error != OK:
		return ready
	var garden := Progress.new()
	garden.path = location.garden
	var profile := Character.new()
	profile.path = location.character
	var serializers := [profile] if character_only else [garden, profile] if pair else [garden]
	var scope := Ops._serializer_scope(serializers)
	var participants := PackedStringArray([location.garden, location.character])
	var tombstone_scratch: String = location.directory.path_join("deleted.cfg.tmp")
	var occupied := not character_only and (FileAccess.file_exists(garden.path) or (pair and FileAccess.file_exists(profile.path)))
	var sources := participants if pair else PackedStringArray([garden.path])
	var confirmation := digests.duplicate()
	if confirmed and confirmation.is_empty():
		for source in sources:
			confirmation[source] = _save_digest(source)
	var targets := {}
	if occupied and confirmed:
		var blocked := Ops.archive_preflight(participants + PackedStringArray([location.directory.path_join("deleted.cfg")]))
		if not blocked.is_empty():
			return blocked
		var archive := archive_override if not archive_override.is_empty() else _archive_folder(location.directory, "" if pair else "world-")
		ready = Auth.bootstrap_archive(archive, garden.path)
		if ready.error != OK:
			return ready
		targets = _archive_targets(archive, sources)
	return Ops.run_management(participants, scope.auxiliary + _archive_scope(targets) + PackedStringArray([tombstone_scratch]), func(context):
		if paths(slot) != location or slot >= capacity:
			return Ops.management_result(ERR_BUSY, "destination_changed")
		if is_active(slot):
			return Ops.management_result(ERR_BUSY, "slot_in_use")
		if FileAccess.file_exists(tombstone_scratch):
			return Ops.management_result(ERR_BUSY, "deletion_publication_pending", "unresolved")
		if character_only and FileAccess.file_exists(profile.path):
			return Ops.management_result(profile.load_profile(false), "profile_read")
		var current_occupied := not character_only and (FileAccess.file_exists(garden.path) or (pair and FileAccess.file_exists(profile.path)))
		if current_occupied != occupied:
			return Ops.management_result(ERR_BUSY, "occupancy_changed")
		if confirmed:
			for source in sources:
				var actual := _save_digest(source)
				if actual.is_empty() or actual != confirmation.get(source):
					return Ops.management_result(ERR_UNAUTHORIZED, "stale_replacement_confirmation")
		if current_occupied and not confirmed:
			return Ops.management_result(ERR_ALREADY_EXISTS, "occupied")
		var archives := {}
		if current_occupied:
			var prepared := Ops.archive_copies(context, targets, fault)
			if prepared.error != OK:
				return prepared
			archives = prepared.archives
		var execution := Ops.commit_serializers(context, serializers, serializers[0].path, func():
			for serializer in serializers:
				if serializer == garden:
					garden.save_garden()
				else:
					profile.save_profile(), fault)
		var result := Ops.transaction_result(execution)
		result.archives = archives
		return result)

func delete_save_guarded(slot: int, confirmed := false, digests := {}) -> Dictionary:
	return _delete_guarded(slot, true, confirmed, digests)

func delete_world_guarded(slot: int, confirmed := false, digest := "") -> Dictionary:
	return _delete_guarded(slot, false, confirmed, {} if digest.is_empty() else {paths(slot).garden: digest})

func _delete_guarded(slot: int, pair: bool, confirmed: bool, digests: Dictionary, fault := Callable(), archive_override := "") -> Dictionary:
	if slot < 0 or slot >= capacity or not confirmed:
		return Ops.management_result(ERR_INVALID_PARAMETER if confirmed else ERR_UNAUTHORIZED, "deletion_not_confirmed")
	var location := paths(slot)
	var ready := Auth.bootstrap(PackedStringArray([location.directory]))
	if ready.error != OK:
		return ready
	var participants := PackedStringArray([location.garden, location.character])
	var sources := participants if pair else PackedStringArray([location.garden])
	var tombstone: String = location.directory.path_join("deleted.cfg")
	var blocked := Ops.archive_preflight(participants + PackedStringArray([tombstone]))
	if not blocked.is_empty():
		return blocked
	var confirmation := digests.duplicate()
	if confirmation.is_empty():
		for source in sources:
			confirmation[source] = _save_digest(source)
	var archive := archive_override if not archive_override.is_empty() else _archive_folder(location.directory, "deleted-" if pair else "deleted-world-")
	ready = Auth.bootstrap_archive(archive, location.garden)
	if ready.error != OK:
		return ready
	var targets := _archive_targets(archive, sources)
	return Ops.run_management(participants + PackedStringArray([tombstone]), _archive_scope(targets) + PackedStringArray([tombstone + ".tmp"]), func(context):
		if paths(slot) != location or slot >= capacity:
			return Ops.management_result(ERR_BUSY, "destination_changed")
		if is_active(slot):
			return Ops.management_result(ERR_BUSY, "slot_in_use")
		if FileAccess.file_exists(tombstone + ".tmp"):
			return Ops.management_result(ERR_BUSY, "deletion_publication_pending", "unresolved")
		var removals := PackedStringArray()
		for source in sources:
			var actual := _save_digest(source)
			if actual.is_empty() or confirmation.get(source) != actual:
				return Ops.management_result(ERR_UNAUTHORIZED, "stale_deletion_confirmation")
			if actual != "absent":
				removals.append(source)
		if removals.is_empty():
			return Ops.management_result(ERR_DOES_NOT_EXIST, "save_missing")
		var prepared := _archive_deleted_save_guarded(context, targets, fault)
		if prepared.error != OK:
			return prepared
		var marker := ConfigFile.new()
		marker.set_value("deletion", "archive", archive)
		var execution := Ops.commit_bytes(context, {tombstone: marker.encode_to_text().to_utf8_buffer()}, removals[0], fault, removals)
		var result := Ops.transaction_result(execution)
		result.archives = prepared.archives
		return result)

static func _archive_deleted_save_guarded(context: RefCounted, targets: Dictionary, fault: Callable) -> Dictionary:
	# B1/B2 owns restoration from its verified original state. Archives remain
	# separate copies, so compensation never consumes the deletion backup.
	return Ops.archive_copies(context, targets, fault)

static func _save_digest(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"

static func _archive_folder(directory: String, prefix: String) -> String:
	var id := Crypto.new().generate_random_bytes(8).hex_encode()
	if prefix in ["", "deleted-"]:
		var stamp := Time.get_datetime_string_from_system().replace(":", "-")
		id = stamp + "-" + (str(Time.get_ticks_msec()) if prefix.is_empty() else id.left(12))
	return directory.path_join("backups").path_join(prefix + id)

static func _archive_targets(directory: String, sources: PackedStringArray) -> Dictionary:
	var targets := {}
	for source in sources:
		targets[source] = directory.path_join(source.get_file())
	return targets

static func _archive_scope(targets: Dictionary) -> PackedStringArray:
	var scope := PackedStringArray()
	for target: String in targets.values():
		scope.append_array(PackedStringArray([target, target + ".tmp"]))
	return scope

func claim_guarded(slot: int) -> Dictionary:
	return _lease_guarded(slot, "claim")

func heartbeat_guarded(slot: int) -> Dictionary:
	return _lease_guarded(slot, "heartbeat")

func release_guarded(slot: int) -> Dictionary:
	return _lease_guarded(slot, "release")

func owns_guarded_lease(slot: int) -> bool:
	if slot < 0 or slot >= capacity:
		return false
	var file: String = paths(slot).directory.path_join("session.cfg")
	var marker := ConfigFile.new()
	return _owned_markers.has(file) and marker.load(file) == OK and _owns_marker(file, marker)

func _owns_marker(file: String, marker: ConfigFile) -> bool:
	return int(marker.get_value("session", "process_id", 0)) == OS.get_process_id() \
		and Time.get_unix_time_from_system() - float(marker.get_value("session", "updated", 0.0)) < 30.0 \
		and _owned_markers.get(file, "") == FileAccess.get_sha256(file)

func _lease_guarded(slot: int, operation: String, roster := false, catalog := "") -> Dictionary:
	if slot < 0 or slot >= capacity:
		return Ops.management_result(ERR_INVALID_PARAMETER, "invalid_slot")
	var location := paths(slot)
	var file: String = location.directory.path_join("session.cfg")
	if operation=="release":
		var result := Ops.relinquish_lease(file,str(_owned_markers.get(file,"")))
		if result.get("ran",false) and result.value.get("error")==OK:
			_owned_markers.erase(file)
		return result
	if operation == "claim":
		var ready := Auth.bootstrap(PackedStringArray([location.directory]))
		if ready.error != OK:
			return ready
	elif not DirAccess.dir_exists_absolute(location.directory):
		return Ops.management_result(ERR_UNAUTHORIZED, "stale_lease")
	var participants := PackedStringArray([location.character]) if roster else PackedStringArray([location.garden, location.character])
	var auxiliary := PackedStringArray()
	if not catalog.is_empty():
		auxiliary.append(catalog)
		auxiliary.append(catalog + ".tmp")
	var marker := ConfigFile.new()
	var validate := func():
		if paths(slot) != location or slot >= capacity:
			return Ops.management_result(ERR_BUSY, "destination_changed")
		if not catalog.is_empty() and FileAccess.file_exists(catalog + ".tmp"):
			return Ops.management_result(ERR_BUSY, "metadata_scratch_pending", "unresolved")
		if not catalog.is_empty() and FileAccess.file_exists(catalog):
			var info := ConfigFile.new()
			var status := info.load(catalog)
			if status != OK or slot >= clampi(int(info.get_value("roster", "capacity", COUNT)), COUNT, 128):
				return Ops.management_result(ERR_INVALID_DATA, "roster_capacity_changed")
		var error := marker.load(file) if FileAccess.file_exists(file) else ERR_FILE_NOT_FOUND
		if error != OK and error != ERR_FILE_NOT_FOUND:
			return Ops.management_result(error, "session_marker_unreadable")
		var active_now := error == OK and Time.get_unix_time_from_system() - float(marker.get_value("session", "updated", 0.0)) < 30.0
		if operation == "claim" and active_now:
			return Ops.management_result(ERR_BUSY, "slot_in_use")
		if operation != "claim" and (not _owned_markers.has(file) or not _owns_marker(file, marker)):
			return Ops.management_result(ERR_UNAUTHORIZED, "stale_lease")
		marker.set_value("session", "process_id", OS.get_process_id())
		marker.set_value("session", "updated", Time.get_unix_time_from_system())
		return Ops.management_result(OK, "")
	var result: Dictionary
	if operation == "heartbeat":
		result = Ops.renew_lease(file, marker, validate)
	else:
		result = Ops.run_management(participants, auxiliary, func(context):
			var checked: Dictionary = validate.call()
			return Ops.write_metadata(context, file, marker) if checked.error == OK else checked)
	if result.get("ran", false) and result.value is Dictionary and result.value.error == OK:
		_owned_markers[file] = marker.encode_to_text().sha256_text()
	return result

func remember_slot_guarded(slot: int) -> Dictionary:
	var location := paths(slot)
	var ready := Auth.bootstrap(PackedStringArray([location.directory]))
	if ready.error != OK:
		return ready
	var file := root_path.path_join("settings.cfg")
	return Ops.run_management(PackedStringArray([location.garden, location.character]), PackedStringArray([file, file + ".tmp"]), func(context):
		if paths(slot) != location or root_path.path_join("settings.cfg") != file:
			return Ops.management_result(ERR_BUSY, "destination_changed")
		var settings := ConfigFile.new()
		if FileAccess.file_exists(file):
			var error := settings.load(file)
			if error != OK:
				return Ops.management_result(error, "slot_settings_unreadable")
		settings.set_value("menu", "last_slot", clampi(slot, 0, capacity - 1))
		return Ops.write_metadata(context, file, settings))
