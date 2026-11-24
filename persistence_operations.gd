extends RefCounted
## Internal synchronous boundary for opt-in writer integration.
## Callbacks are trusted code and must finish without awaiting. A token scopes
## nested calls. It does not intercept direct filesystem calls made by a writer.

const Authorization = preload("res://persistence_authorization.gd")
const Layout = preload("res://persistence_save_layout.gd")
const Planner = preload("res://persistence_recovery_plan.gd")
const Batch = preload("res://save_batch.gd")
const Inspection = preload("res://persistence_save_inspection.gd")

const MAX_AUXILIARIES := 64
const MAX_AUXILIARY_BYTES := 1024 * 1024
const MIGRATION_BACKUPS = [
 ".pre-tier-growth-v2.bak", ".pre-timed-research-v2.bak", ".pre-content-v2.bak",
 ".pre-altar-v1.bak", ".pre-inventory-v1.bak", ".pre-heart-v1.bak", ".pre-plots-v2.bak",
]

static var _context: RefCounted
static var _native_context: RefCounted
static var _serializer_context: RefCounted
static var _serializers := {}
static var _stage: Callable
static var _backup_owners := {}

## For menu previews. This result cannot authorize a write.
static func inspect(path: String) -> Dictionary:
 return Inspection.garden(path) if path.get_file() == "garden.cfg" else Inspection.character(path)

## A read-only snapshot for callers that select destinations before executing.
static func prepare(paths: PackedStringArray, auxiliaries := PackedStringArray()) -> Dictionary:
 var plan := Planner.discover(paths)
 var result := {"plan": plan, "auxiliaries": _sorted(auxiliaries), "observed": {}, "reason": plan.reason}
 if plan.authorization_paths.is_empty():
  return result
 var metadata := _observe_auxiliaries(plan.requested, result.auxiliaries)
 result.observed = metadata.observed
 if not metadata.reason.is_empty():
  result.reason = metadata.reason
 return result

## For a fresh root, bootstrap supported directories separately, then prepare.
## If a caller already selected destinations, pass its preview to reject drift.
## The callback's return value is independent of boundary acquisition/release.
static func run(paths: PackedStringArray, auxiliaries: PackedStringArray, operation: Callable, expected := {}) -> Dictionary:
 if not Thread.is_main_thread() or _context != null:
  return _result(ERR_BUSY, "busy", "operation_in_progress")
 if Batch.active:
  return _result(ERR_BUSY, "busy", "save_batch_in_progress")
 if not operation.is_valid():
  return _result(ERR_INVALID_PARAMETER, "invalid", "invalid_callback")

 var preview := prepare(paths, auxiliaries)
 var plan: Dictionary = preview.plan
 if not expected.is_empty() and not _same_scope(expected, preview):
  return _result(ERR_BUSY, "invalid", "operation_scope_changed")
 if plan.authorization_paths.is_empty():
  return _refuse(plan.state, plan.reason)
 if preview.reason != plan.reason:
  return _refuse("invalid", preview.reason)
 var authorized_paths := _sorted(plan.authorization_paths + preview.auxiliaries)
 var boundary := Authorization.run(authorized_paths, func(token):
  return _run_locked(token, preview, operation, expected))
 if not boundary.ran:
  var state := "busy" if boundary.error == ERR_BUSY else "invalid"
  return _result(boundary.error, state, "authorization_acquire_failed", boundary.native_error)
 if not boundary.value is Dictionary:
  return _result(ERR_BUG, "invalid", "invalid_operation_result")
 var result: Dictionary = boundary.value
 if boundary.error != OK:
  result.release_error = boundary.error
  result.native_error = boundary.native_error
  if result.error == OK:
   result.error = boundary.error
   result.reason = "authorization_release_failed"
 return result


## B1 opt-in finalization. The action receives (stage, context), and its value
## is independent of finalization and the enclosing authorization result.
static func run_batch(paths: PackedStringArray, anchor: String, action: Callable, no_op := false) -> Dictionary:
 return _run_batch(paths, anchor, action, no_op)

static func _run_batch(paths: PackedStringArray, anchor: String, action: Callable, no_op: bool, fault := Callable()) -> Dictionary:
 if not action.is_valid():
  return _result(ERR_INVALID_PARAMETER, "invalid", "invalid_callback")
 return run(paths, PackedStringArray(), func(context):
  return Batch._run_guarded(_native_context, paths, anchor, action.bind(context), no_op, fault))

## Authorize the read set and auxiliary files once. The mutation subset may
## be smaller than that scope, for example a legacy import destination.
static func run_management(paths: PackedStringArray, auxiliary: PackedStringArray, operation: Callable, expected := {}) -> Dictionary:
 if not operation.is_valid():
  return _result(ERR_INVALID_PARAMETER, "invalid", "invalid_callback")
 var scope := auxiliary.duplicate()
 var lease_scratch := PackedStringArray()
 var participants := paths.duplicate()
 var layout := Layout.directories()
 for path in paths:
  if Batch.guarded_write_pending(path):
   return _result(ERR_BUSY, "pending_recovery", "unresolved_transaction")
  var parent := path.get_base_dir()
  var metadata := Layout.deletion_metadata(path, layout)
  if not metadata.is_empty() and not participants.has(metadata) and DirAccess.dir_exists_absolute(parent):
   if Batch.guarded_write_pending(metadata):
    return _result(ERR_BUSY, "pending_recovery", "unresolved_transaction")
   participants.append(metadata)
  if parent.get_file().begins_with("slot_"):
   var marker := parent.path_join("session.cfg")
   scope.append(marker)
   scope.append(marker + ".tmp")
   lease_scratch.append(marker + ".tmp")
 return run(participants, scope, func(context):
  for scratch in lease_scratch:
   if FileAccess.file_exists(scratch):
    return management_result(ERR_BUSY, "lease_publication_pending", "unresolved")
  return operation.call(context), expected)

static func archive_preflight(paths: PackedStringArray) -> Dictionary:
 var plan := Planner.discover(paths)
 if not plan.state in ["empty", "healthy"]:
  return _refuse(plan.state, plan.reason)
 if not Authorization.replacement_available():
  return _result(ERR_UNAVAILABLE, "invalid", "replacement_backend_unavailable")
 return {}

static func commit_bytes(context: RefCounted, files: Dictionary, anchor: String, fault := Callable(), removals := PackedStringArray()) -> Dictionary:
 var paths := PackedStringArray(files.keys()) + removals
 var checked := run_nested(context, paths, func(_access_context):
  return Batch._run_guarded(_native_context, paths, anchor, func(stage):
   for path in paths:
    if files.has(path):
     stage.call(path, files[path]), false, fault, removals))
 return checked.value if checked.ran else checked

## The caller owns the gameplay snapshot. Serializers are bound by object and
## canonical path for this synchronous operation, including any nested saves.
static func run_serializers(serializers: Array, anchor: String, action: Callable, fault := Callable()) -> Dictionary:
 if not Thread.is_main_thread() or not action.is_valid() or serializers.is_empty():
  return _result(ERR_INVALID_PARAMETER, "invalid", "invalid_serializer_operation")
 var scope := _serializer_scope(serializers)
 if scope.is_empty():
  return _result(ERR_INVALID_PARAMETER, "invalid", "duplicate_serializer_path")
 return run(scope.paths, scope.auxiliary, func(context):
  return commit_serializers(context, serializers, anchor, action, fault))

static func _serializer_scope(serializers: Array) -> Dictionary:
 var paths := PackedStringArray()
 var auxiliary := PackedStringArray()
 var bindings := {}
 var backups := {}
 for serializer in serializers:
  var path: String = serializer.path
  if paths.has(path):
   return {}
  bindings[serializer.get_instance_id()] = path
  paths.append(path)
  for backup: String in serializer.migration_backup_paths():
   auxiliary.append(backup)
   auxiliary.append(backup + ".tmp")
   backups[backup] = path
 return {"paths": paths, "auxiliary": auxiliary, "bindings": bindings, "backups": backups}

static func commit_serializers(context: RefCounted, serializers: Array, anchor: String, action: Callable, fault := Callable()) -> Dictionary:
 var scope := _serializer_scope(serializers)
 if scope.is_empty() or not action.is_valid():
  return _result(ERR_INVALID_PARAMETER, "invalid", "invalid_serializer_operation")
 var checked := run_nested(context, scope.paths + scope.auxiliary, func(_access_context):
  var execution := Batch._run_guarded(_native_context, scope.paths, anchor, func(stage):
   _serializer_context = context
   _serializers = scope.bindings
   _backup_owners = scope.backups
   _stage = stage
   var value: Variant = action.call()
   _stage = Callable()
   _serializers = {}
   _backup_owners = {}
   _serializer_context = null
   return value, false, fault)
  var final: Batch.Finalization = execution.get("outcome")
  if final != null and final.outcome in [Batch.Outcome.COMMITTED, Batch.Outcome.COMMITTED_CLEANUP_PENDING]:
   for serializer in serializers:
    serializer.confirm_migration(scope.bindings[serializer.get_instance_id()])
  return execution)
 return checked.value if checked.ran else checked

## Atomic publication of one catalog, preference or lease file. A retained
## scratch blocks another attempt when publication cannot be classified.
static func write_metadata(context: RefCounted, target: String, file: ConfigFile) -> Dictionary:
 if target.get_file() not in ["session.cfg", "settings.cfg", "catalog.cfg"]:
  return management_result(ERR_UNAUTHORIZED, "unsupported_metadata_target")
 var scratch := target + ".tmp"
 var checked := run_nested(context, PackedStringArray([target, scratch]), func(_access_context):
  return _write_metadata_locked(_native_context, target, scratch, file.encode_to_text().to_utf8_buffer()))
 return checked.value if checked.ran else checked

## Archive copies precede the canonical transaction. Never overwrite or
## delete a previous archive, including when a later save operation aborts.
static func archive_copies(context: RefCounted, destinations: Dictionary, fault := Callable()) -> Dictionary:
 if not Authorization.replacement_available():
  return management_result(ERR_UNAVAILABLE, "replacement_backend_unavailable")
 var layout := Layout.directories()
 var scope := PackedStringArray()
 var ordered := PackedStringArray(destinations.keys())
 ordered.sort()
 for source in ordered:
  var target: String = destinations[source]
  if Layout.archive_source(target, layout) != source:
   return management_result(ERR_UNAUTHORIZED, "archive_scope_rejected")
  scope.append_array(PackedStringArray([source, target, target + ".tmp"]))
 var checked := run_nested(context, scope, func(_access_context):
  var originals := {}
  var archived := {}
  for source in ordered:
   var target: String = destinations[source]
   var archive := DirAccess.open(target.get_base_dir())
   if archive == null:
    return management_result(DirAccess.get_open_error(), "archive_directory_unreadable")
   archive.include_hidden = true
   if not archive.get_files().is_empty() or not archive.get_directories().is_empty():
    return management_result(ERR_ALREADY_EXISTS, "archive_destination_occupied")
   if FileAccess.file_exists(source):
    var prior := Planner._read_bytes(source)
    if not prior.ok:
     return management_result(ERR_FILE_CANT_READ, prior.reason)
    originals[source] = prior.bytes
  for source in ordered:
   if not originals.has(source):
    continue
   var target: String = destinations[source]
   var error: Error = fault.call("archive", target) if fault.is_valid() else OK
   if error == OK:
    error = Batch._write_bytes(target + ".tmp", originals[source])
   if error == OK and fault.is_valid():
    error = fault.call("archive_staged", target)
   if error == OK:
    error = _publish_backup(_native_context, target + ".tmp", target, originals[source])
   if error != OK:
    var failed := management_result(error, "archive_copy_failed",
     "partial_completion" if not archived.is_empty() or FileAccess.file_exists(target + ".tmp") or FileAccess.file_exists(target) else "verified_failure")
    failed.archives = archived
    failed.failed_path = target
    return failed
   archived[source] = target
   if fault.is_valid():
    error = fault.call("after_archive", target)
    if error != OK:
     var partial := management_result(error, "archive_copy_interrupted", "partial_completion")
     partial.archives = archived
     return partial
  var complete := management_result(OK, "")
  complete.archives = archived
  return complete)
 return checked.value if checked.ran else checked

## A renewal publishes only the session marker. Its destination is fixed, so we
## can acquire first and inspect once under the native lock. The slot owner
## rechecks its current digest, expiry and catalog before the marker is written.
static func renew_lease(marker: String, config: ConfigFile, validate: Callable) -> Dictionary:
 if Batch.active or _context != null:
  return management_result(ERR_BUSY, "operation_in_progress")
 var directory := marker.get_base_dir()
 var layout := Layout.directories()
 var participants := PackedStringArray()
 for leaf in layout.get(directory, []):
  participants.append(directory.path_join(leaf))
 if participants.is_empty() or marker != directory.path_join("session.cfg"):
  return management_result(ERR_UNAUTHORIZED, "lease_scope_rejected")
 var metadata := Layout.deletion_metadata(participants[0], layout)
 if metadata.is_empty():
  return management_result(ERR_UNAUTHORIZED, "lease_scope_rejected")
 participants.append(metadata)
 var scratch := marker + ".tmp"
 var boundary := Authorization.run(participants + PackedStringArray([marker, scratch, metadata + ".tmp"]), func(token):
  for path in participants:
   if Batch.guarded_write_pending(path): return management_result(ERR_BUSY, "unresolved_transaction", "pending_recovery")
  var plan := Planner.discover(participants)
  if plan.state not in ["healthy", "empty"]:
   return _refuse(plan.state, plan.reason)
  if FileAccess.file_exists(scratch) or FileAccess.file_exists(metadata + ".tmp"):
   return management_result(ERR_BUSY, "metadata_publication_pending", "unresolved")
  var checked: Dictionary = validate.call()
  if checked.error != OK: return checked
  return _write_metadata_locked(token, marker, scratch, config.encode_to_text().to_utf8_buffer()))
 if not boundary.ran:
  return _result(boundary.error, "busy" if boundary.error == ERR_BUSY else "invalid", "lease_renewal_refused", boundary.native_error)
 return boundary

## A terminal owner may relinquish its lease while recovery remains pending.
## This touches only the exact marker. It grants no save or recovery access.
static func relinquish_lease(marker: String, digest: String) -> Dictionary:
 var directory := marker.get_base_dir()
 if marker != directory.path_join("session.cfg") or Layout.directories().get(directory,[]).is_empty() or digest.length()!=64:
  return management_result(ERR_UNAUTHORIZED,"lease_scope_rejected")
 var boundary := Authorization.run(PackedStringArray([marker,marker+".tmp"]),func(_token):
  var bytes := Planner._read_bytes(marker,MAX_AUXILIARY_BYTES)
  if not bytes.ok or FileAccess.get_sha256(marker)!=digest:
   return management_result(ERR_UNAUTHORIZED,"stale_lease")
  var marker_data := ConfigFile.new()
  if marker_data.parse(bytes.bytes.get_string_from_utf8())!=OK or int(marker_data.get_value("session","process_id",0))!=OS.get_process_id():
   return management_result(ERR_UNAUTHORIZED,"stale_lease")
  var scratch := marker+".tmp"
  if FileAccess.file_exists(scratch) or DirAccess.dir_exists_absolute(scratch):
   return management_result(ERR_BUSY,"lease_publication_pending","unresolved")
  var removed := DirAccess.remove_absolute(marker)
  if removed != OK or FileAccess.file_exists(marker):
   return management_result(removed if removed!=OK else ERR_INVALID_DATA,"lease_removal_unverified","unresolved")
  return management_result(OK,""))
 if not boundary.ran:
  return _result(boundary.error,"busy" if boundary.error==ERR_BUSY else "invalid","lease_release_refused",boundary.native_error)
 return boundary

static func _write_metadata_locked(token: RefCounted, target: String, scratch: String, bytes: PackedByteArray) -> Dictionary:
 if not Authorization.replacement_available():
  return management_result(ERR_UNAVAILABLE, "replacement_backend_unavailable")
 if FileAccess.file_exists(scratch) or DirAccess.dir_exists_absolute(scratch) or DirAccess.dir_exists_absolute(target):
  return management_result(ERR_BUSY, "metadata_scratch_pending", "unresolved")
 var existed := FileAccess.file_exists(target)
 var original := Planner._read_bytes(target, MAX_AUXILIARY_BYTES) if existed else {}
 if (existed and not original.ok) or bytes.size() > MAX_AUXILIARY_BYTES:
  return management_result(ERR_INVALID_DATA, "metadata_unreadable_or_oversize")
 var written := Batch._write_bytes(scratch, bytes)
 var staged := Planner._read_bytes(scratch, MAX_AUXILIARY_BYTES)
 if written != OK or not staged.ok or staged.bytes != bytes:
  return _metadata_abort(scratch, written if written != OK else ERR_FILE_CANT_WRITE)
 var moved := Authorization.replace_authorized(token, scratch, target)
 var current := Planner._read_bytes(target, MAX_AUXILIARY_BYTES) if FileAccess.file_exists(target) else {}
 if current.get("ok", false) and current.bytes == bytes and not FileAccess.file_exists(scratch):
  return management_result(OK, "")
 if (not existed and current.is_empty()) or (existed and current.get("ok", false) and current.bytes == original.bytes):
  return _metadata_abort(scratch, moved.error if moved.error != OK else ERR_FILE_CANT_WRITE)
 var result := management_result(moved.error if moved.error != OK else ERR_INVALID_DATA, "metadata_publication_uncertain", "unresolved")
 result.native_error = moved.native_error
 return result

static func _metadata_abort(scratch: String, error: Error) -> Dictionary:
 if FileAccess.file_exists(scratch) and (DirAccess.remove_absolute(scratch) != OK or FileAccess.file_exists(scratch)):
  return management_result(error, "metadata_cleanup_pending", "unresolved")
 return management_result(error, "metadata_write_failed")

static func management_result(error: Error, reason: String, state := "") -> Dictionary:
 if state.is_empty():
  state = "completed" if error == OK else "busy" if error == ERR_BUSY else "verified_failure"
 return {"error": error, "reason": reason, "state": state}

static func transaction_result(execution: Dictionary) -> Dictionary:
 if not execution.ran or execution.get("outcome") == null:
  var error: Error = execution.error
  return management_result(error, execution.get("reason", "transaction_refused"),
   "pending_recovery" if execution.get("reason") == "unresolved_transaction" else "")
 var outcome: Batch.Finalization = execution.outcome
 var result := management_result(outcome.original_error, outcome.phase)
 match outcome.outcome:
  Batch.Outcome.COMMITTED:
   result = management_result(OK, "")
  Batch.Outcome.COMMITTED_CLEANUP_PENDING:
   result = management_result(outcome.cleanup_error, outcome.phase, "committed_cleanup_pending")
  Batch.Outcome.UNCERTAIN:
   result = management_result(outcome.original_error, outcome.phase, "unresolved")
  Batch.Outcome.ABORTED_RESTORED:
   if outcome.write_blocked:
    result.state = "pending_recovery"
 result.outcome = outcome
 return result

static func authorizes_serializer(serializer: RefCounted, stage: Callable) -> bool:
 return Thread.is_main_thread() and _stage.is_valid() and _stage == stage \
  and _serializers.get(serializer.get_instance_id()) == serializer.path

static func stage_serializer(serializer: RefCounted, operation: Callable) -> Error:
 if not Thread.is_main_thread():
  return ERR_UNAUTHORIZED
 var path: String = serializer.path
 if not authorizes_serializer(serializer, _stage):
  return Batch.reject_guarded_serializer(ERR_UNAUTHORIZED, path)
 var scope := PackedStringArray([path])
 for backup: String in serializer.migration_backup_paths():
  scope.append(backup)
  scope.append(backup + ".tmp")
 var result := run_nested(_serializer_context, scope, func(_access_context):
  return operation.call(_stage))
 var error: Error = result.value if result.ran else result.error
 return Batch.reject_guarded_serializer(error, path)

static func read_serializer(serializer: RefCounted, operation: Callable) -> Error:
 if _serializers.get(serializer.get_instance_id()) != serializer.path:
  return ERR_UNAUTHORIZED
 var result := run_nested(_serializer_context, PackedStringArray([serializer.path]), func(_access_context):
  return operation.call())
 return result.value if result.ran else result.error

static func load_serializer(path: String, operation: Callable) -> Dictionary:
 if not Thread.is_main_thread():
  return _result(ERR_UNAUTHORIZED, "invalid", "operation_context_rejected")
 if Batch.guarded_write_pending(path):
  return _result(ERR_BUSY, "pending_recovery", "unresolved_transaction")
 return run(PackedStringArray([path]), PackedStringArray(), func(_access_context): return operation.call())

## Migration backups remain outside the atomic pair. Publish an independently
## verified copy through its reserved sibling, keeping any existing backup.
static func backup_serializer(source: String, target: String) -> Error:
 if not Thread.is_main_thread() or _backup_owners.get(target) != source:
  return ERR_UNAUTHORIZED
 var scratch := target + ".tmp"
 var outcome := Authorization.run_nested(_native_context, PackedStringArray([source, target, scratch]), func(token):
  if DirAccess.dir_exists_absolute(scratch) or DirAccess.dir_exists_absolute(target):
   return ERR_BUSY
  var prior := Planner._read_bytes(source)
  if not prior.ok:
   return ERR_FILE_CANT_READ
  if FileAccess.file_exists(target):
   var published := Planner._read_bytes(target)
   if not published.ok or published.bytes != prior.bytes:
    return ERR_FILE_CORRUPT
   # A publication that succeeded before a previous process stopped can be
   # reused. Conflicting scratch remains evidence and blocks this migration.
   return ERR_BUSY if FileAccess.file_exists(scratch) else OK
  if FileAccess.file_exists(scratch):
   var previous := Planner._read_bytes(scratch)
   if not previous.ok or previous.bytes != prior.bytes:
    return ERR_BUSY
   return _publish_backup(token, scratch, target, prior.bytes)
  var file := FileAccess.open(scratch, FileAccess.WRITE)
  if file == null:
   return FileAccess.get_open_error()
  var stored := file.store_buffer(prior.bytes)
  file.flush()
  var error := file.get_error()
  file.close()
  if error == OK and not stored:
   error = ERR_FILE_CANT_WRITE
  if error == OK:
   var copied := Planner._read_bytes(scratch)
   if not copied.ok or copied.bytes != prior.bytes:
    error = ERR_FILE_CORRUPT
  if error != OK:
   if FileAccess.file_exists(scratch):
    DirAccess.remove_absolute(scratch)
   return error
  return _publish_backup(token, scratch, target, prior.bytes))
 return outcome.value if outcome.ran else outcome.error

static func _publish_backup(token: RefCounted, scratch: String, target: String, original: PackedByteArray) -> Error:
 var moved := Authorization.replace_authorized(token, scratch, target)
 if moved.error != OK:
  return moved.error
 var published := Planner._read_bytes(target)
 return OK if published.ok and published.bytes == original else ERR_FILE_CORRUPT

## Recovery has no gameplay callback. Authorization and disk outcomes stay separate.
static func recover(paths: PackedStringArray) -> Dictionary:
 return _recover(paths)

## Read-only observations. The selection can be blocked by a shared
## participant without owning the selected journal.
static func review_recovery(paths: PackedStringArray) -> Dictionary:
 var scope := Inspection.recovery_seeds(paths)
 var selected := Planner.discover(scope)
 var options := []
 for anchor: String in selected.journal_anchors:
  var owner := Planner.discover(PackedStringArray([anchor]))
  var isolated: bool = owner.journal_anchors == PackedStringArray([anchor])
  var blocked := recovery_scratch(scope + owner.participants)
  var can_recover: bool = (isolated and blocked.is_empty() and selected.state == "pending_recovery"
   and owner.state == "pending_recovery" and not owner.authorization_paths.is_empty()
   and not owner.active_leases.values().has(true))
  options.append({"anchor":anchor, "plan":owner, "can_recover":can_recover})
 return {"selection":selected, "options":options}

static func recovery_scratch(paths: PackedStringArray) -> String:
 var layout := Layout.directories()
 for path: String in paths:
  var scratch := PackedStringArray([path + ".tmp"])
  if Layout.is_canonical(path, layout):
   scratch.append(path.get_base_dir().path_join("session.cfg.tmp"))
   var metadata := Layout.deletion_metadata(path, layout)
   if not metadata.is_empty(): scratch.append(metadata + ".tmp")
  for file in scratch:
   if FileAccess.file_exists(file) or DirAccess.dir_exists_absolute(file):
    return file
 return ""

## Title recovery requires the plan the player reviewed and no live leases.
static func recover_selected(reviewed: Dictionary, selection := PackedStringArray(), observed := {}) -> Dictionary:
 if reviewed.get("state") != "pending_recovery" or reviewed.get("authorization_paths", []).is_empty():
  return _refuse(reviewed.get("state","invalid"), "recovery_review_not_authorizable")
 return _recover(reviewed.requested, Callable(), reviewed, selection, observed)

static func _recover(paths: PackedStringArray, fault := Callable(), reviewed := {}, selection := PackedStringArray(), observed := {}) -> Dictionary:
 if not Thread.is_main_thread() or _context != null or Batch.active:
  return _result(ERR_BUSY, "busy", "operation_in_progress")
 var plan := Planner.discover(paths)
 if not reviewed.is_empty() and (plan.participants != reviewed.participants or plan.observed != reviewed.observed \
  or plan.journal_anchors != reviewed.journal_anchors or plan.authorization_paths != reviewed.authorization_paths \
  or plan.state != reviewed.state):
  return _result(ERR_BUSY, "pending_recovery", "recovery_review_changed")
 if plan.authorization_paths.is_empty():
  var refused := _refuse(plan.state, plan.reason)
  refused.path = plan.path
  return refused
 var boundary := Authorization.run(plan.authorization_paths, func(token):
  if not selection.is_empty():
   var current := review_recovery(selection)
   if not _same_recovery_selection(observed, current.selection) or not current.options.any(func(option):
    return option.can_recover and option.plan.requested == paths):
    return {"state":"pending_recovery", "reason":"recovery_review_changed", "verified":false, "write_blocked":true}
  return Batch._recover_guarded(token, plan, paths, fault, not reviewed.is_empty()))
 if not boundary.ran:
  var state := "busy" if boundary.error == ERR_BUSY else "invalid"
  return _result(boundary.error, state, "authorization_acquire_failed", boundary.native_error)
 var execution: Dictionary = boundary.value
 var result := _result(OK, execution.state, execution.reason, boundary.native_error)
 result.ran = true
 result.value = execution
 result.release_error = boundary.error
 if boundary.error != OK:
  result.error = boundary.error
  execution.write_blocked = true
 return result

static func _same_recovery_selection(previous: Dictionary, current: Dictionary) -> bool:
 for key in ["state", "requested", "participants", "journal_anchors", "observed"]:
  if previous.get(key) != current.get(key): return false
 return true

## Serializers, slot helpers, and recovery helpers must use an existing context.
## This entry point cannot extend its scope or grant recovery on a pending plan.
static func run_nested(context: RefCounted, paths: PackedStringArray, operation: Callable) -> Dictionary:
 if not Thread.is_main_thread() or context == null or context != _context:
  return _result(ERR_UNAUTHORIZED, "invalid", "operation_context_rejected")
 if paths.is_empty() or not operation.is_valid():
  return _result(ERR_INVALID_PARAMETER, "invalid", "invalid_nested_operation")
 var nested := Authorization.run_nested(_native_context, paths, func(_token): return operation.call(context))
 if not nested.ran:
  return _result(nested.error, "invalid", "nested_scope_rejected", nested.native_error)
 var result := _result(OK, "authorized", "")
 result.ran = true
 result.value = nested.value
 return result

static func _run_locked(token: RefCounted, preview: Dictionary, operation: Callable, expected: Dictionary) -> Dictionary:
 var locked := Planner.revalidate(preview.plan, preview.plan.requested, token)
 if not locked.locked:
  return _refuse(locked.state, locked.reason)
 var scope := Authorization.run_nested(token, _sorted(locked.authorization_paths + preview.auxiliaries), func(_token): return true)
 if not scope.ran:
  return _result(scope.error, "invalid", "incomplete_locked_scope", scope.native_error)
 var metadata := _observe_auxiliaries(locked.requested, preview.auxiliaries)
 if not metadata.reason.is_empty():
  return _refuse("invalid", metadata.reason)
 if metadata.observed != preview.observed:
  return _refuse("invalid", "auxiliary_observations_changed")
 var current := {"plan": locked, "auxiliaries": preview.auxiliaries, "observed": metadata.observed}
 if not expected.is_empty() and not _same_observations(expected, current):
  return _refuse("invalid", "prepared_observations_changed")
 if locked.state == "pending_recovery":
  return _refuse(locked.state, locked.reason)

 var context := RefCounted.new()
 _context = context
 _native_context = token
 var value: Variant = operation.call(context)
 _native_context = null
 _context = null
 var result := _result(OK, locked.state, "")
 result.ran = true
 result.value = value
 return result

static func _same_scope(previous: Dictionary, current: Dictionary) -> bool:
 var plan: Variant = previous.get("plan")
 return plan is Dictionary and plan.get("requested") == current.plan.requested and plan.get("participants") == current.plan.participants and previous.get("auxiliaries") == current.auxiliaries

static func _same_observations(previous: Dictionary, current: Dictionary) -> bool:
 var plan: Dictionary = previous.plan
 return plan.get("state") == current.plan.state and plan.get("observed") == current.plan.observed and plan.get("authorization_paths") == current.plan.authorization_paths and plan.get("journal_anchors") == current.plan.journal_anchors and previous.get("observed") == current.observed

static func _observe_auxiliaries(paths: PackedStringArray, auxiliaries: PackedStringArray) -> Dictionary:
 var result := {"observed": {}, "reason": ""}
 var supported := Layout.directories()
 if auxiliaries.size() > MAX_AUXILIARIES:
  result.reason = "auxiliary_limit"
  return result
 var allowed := {}
 for path in paths:
  if not Layout.is_canonical(path, supported):
   continue
  var parent := path.get_base_dir()
  allowed[path + ".tmp"] = true
  if path.get_file() == "garden.cfg":
   for suffix: String in MIGRATION_BACKUPS:
    _allow_pair(allowed, path + suffix)
  else:
   _allow_pair(allowed, path + ".pre-content-v2.bak")
  if not parent.get_file().begins_with("slot_"):
   continue
  _allow_pair(allowed, parent.path_join("session.cfg"))
  var base := parent.get_base_dir()
  if base.get_file() == "characters":
   _allow_pair(allowed, base.path_join("catalog.cfg"))
  else:
   _allow_pair(allowed, parent.path_join("deleted.cfg"))
   _allow_pair(allowed, base.path_join("settings.cfg"))
   allowed[path + ".new"] = true
   allowed[path + ".new.tmp"] = true
 for path in auxiliaries:
  var archive_owner := Layout.archive_source(path, supported)
  if not allowed.has(path) and not paths.has(archive_owner):
   result.reason = "auxiliary_outside_scope"
   return result
  var directory := DirAccess.open(path.get_base_dir())
  if directory == null or directory.is_link(path.get_file()) or directory.dir_exists(path.get_file()):
   result.reason = "unsafe_auxiliary"
   return result
  if not directory.file_exists(path.get_file()):
   result.observed[path] = "absent"
   continue
  if not directory.get_files().has(path.get_file()):
   result.reason = "unsafe_auxiliary"
   return result
  var limit := Planner.MAX_RECORD_BYTES if not archive_owner.is_empty() or path.ends_with(".bak") or path.ends_with(".bak.tmp") else MAX_AUXILIARY_BYTES
  var file := Planner._read_bytes(path, limit)
  if not file.ok:
   result.reason = file.reason
   return result
  result.observed[path] = Planner._digest(file.bytes)
 return result

static func _allow_pair(allowed: Dictionary, path: String) -> void:
 allowed[path] = true
 allowed[path + ".tmp"] = true

static func _sorted(paths: PackedStringArray) -> PackedStringArray:
 var unique := {}
 for path in paths:
  unique[path] = true
 var result := PackedStringArray(unique.keys())
 result.sort()
 return result

static func _refuse(state: String, reason: String) -> Dictionary:
 var error := ERR_BUSY if state == "busy" or state == "pending_recovery" else ERR_INVALID_DATA
 return _result(error, state, reason)

static func _result(error: Error, state: String, reason: String, native_error := 0) -> Dictionary:
 return {
  "error": error, "state": state, "reason": reason, "native_error": native_error,
  "release_error": OK, "ran": false, "value": null,
 }
