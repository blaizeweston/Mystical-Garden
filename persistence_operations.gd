extends RefCounted
## Internal synchronous boundary for opt-in writer integration.
## Callbacks are trusted code and must finish without awaiting. A token scopes
## nested calls. It does not intercept direct filesystem calls made by a writer.

const Authorization = preload("res://persistence_authorization.gd")
const Layout = preload("res://persistence_save_layout.gd")
const Planner = preload("res://persistence_recovery_plan.gd")
const Batch = preload("res://save_batch.gd")
const Inspection = preload("res://persistence_save_inspection.gd")
const Integration = preload("res://persistence_writer_integration.gd")

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
 for path in paths:
  if Batch.guarded_write_pending(path):
   return _result(ERR_BUSY, "pending_recovery", "unresolved_transaction")
  var parent := path.get_base_dir()
  if parent.get_file().begins_with("slot_"):
   var marker := parent.path_join("session.cfg")
   scope.append(marker)
   scope.append(marker + ".tmp")
   lease_scratch.append(marker + ".tmp")
 return run(paths, scope, func(context):
  for scratch in lease_scratch:
   if FileAccess.file_exists(scratch):
    return management_result(ERR_BUSY, "lease_publication_pending", "unresolved")
  return operation.call(context), expected)

static func commit_bytes(context: RefCounted, files: Dictionary, anchor: String, fault := Callable()) -> Dictionary:
 var paths := PackedStringArray(files.keys())
 var checked := run_nested(context, paths, func(_context):
  return Batch._run_guarded(_native_context, paths, anchor, func(stage):
   for path in paths:
    stage.call(path, files[path]), false, fault))
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
 var checked := run_nested(context, scope.paths + scope.auxiliary, func(_context):
  return Batch._run_guarded(_native_context, scope.paths, anchor, func(stage):
   _serializer_context = context
   _serializers = scope.bindings
   _backup_owners = scope.backups
   _stage = stage
   var value: Variant = action.call()
   _stage = Callable()
   _serializers = {}
   _backup_owners = {}
   _serializer_context = null
   return value, false, fault))
 return checked.value if checked.ran else checked

## Atomic publication of one catalog, preference or lease file. A retained
## scratch blocks another attempt when publication cannot be classified.
static func write_metadata(context: RefCounted, target: String, file: ConfigFile) -> Dictionary:
 if target.get_file() not in ["session.cfg", "settings.cfg", "catalog.cfg"]:
  return management_result(ERR_UNAUTHORIZED, "unsupported_metadata_target")
 var scratch := target + ".tmp"
 var checked := run_nested(context, PackedStringArray([target, scratch]), func(_context):
  return _write_metadata_locked(target, scratch, file.encode_to_text().to_utf8_buffer()))
 return checked.value if checked.ran else checked

static func remove_lease(context: RefCounted, marker: String, digest: String) -> Error:
 if marker.get_file() != "session.cfg":
  return ERR_UNAUTHORIZED
 var checked := run_nested(context, PackedStringArray([marker, marker + ".tmp"]), func(_context):
  if not FileAccess.file_exists(marker) or FileAccess.get_sha256(marker) != digest:
   return ERR_UNAUTHORIZED
  return DirAccess.remove_absolute(marker))
 return checked.value if checked.ran else checked.error

static func _write_metadata_locked(target: String, scratch: String, bytes: PackedByteArray) -> Dictionary:
 if not Authorization.replacement_available():
  return management_result(ERR_UNAVAILABLE, "replacement_backend_unavailable")
 if FileAccess.file_exists(scratch) or DirAccess.dir_exists_absolute(scratch) or DirAccess.dir_exists_absolute(target):
  return management_result(ERR_BUSY, "metadata_scratch_pending", "unresolved")
 var existed := FileAccess.file_exists(target)
 var original := Planner._read_bytes(target, MAX_AUXILIARY_BYTES) if existed else {}
 if (existed and not original.ok) or bytes.size() > MAX_AUXILIARY_BYTES:
  return management_result(ERR_INVALID_DATA, "metadata_unreadable_or_oversize")
 var written := Batch.write_bytes(scratch, bytes)
 var staged := Planner._read_bytes(scratch, MAX_AUXILIARY_BYTES)
 if written != OK or not staged.ok or staged.bytes != bytes:
  return _metadata_abort(scratch, written if written != OK else ERR_FILE_CANT_WRITE)
 var moved := Authorization.replace_authorized(_native_context, scratch, target)
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

static func stage_serializer(serializer: RefCounted, operation: Callable) -> Error:
 if not Thread.is_main_thread():
  return ERR_UNAUTHORIZED
 var path: String = serializer.path
 if not _stage.is_valid() or _serializers.get(serializer.get_instance_id()) != path:
  return Batch.reject_guarded_serializer(ERR_UNAUTHORIZED, path)
 var scope := PackedStringArray([path])
 for backup: String in serializer.migration_backup_paths():
  scope.append(backup)
  scope.append(backup + ".tmp")
 var result := run_nested(_serializer_context, scope, func(_context):
  return operation.call(_stage))
 var error: Error = result.value if result.ran else result.error
 return Batch.reject_guarded_serializer(error, path)

static func read_serializer(serializer: RefCounted, operation: Callable) -> Error:
 if _serializers.get(serializer.get_instance_id()) != serializer.path:
  return ERR_UNAUTHORIZED
 var result := run_nested(_serializer_context, PackedStringArray([serializer.path]), func(_context):
  return operation.call())
 return result.value if result.ran else result.error

static func load_serializer(path: String, operation: Callable) -> Dictionary:
 if not Thread.is_main_thread():
  return _result(ERR_UNAUTHORIZED, "invalid", "operation_context_rejected")
 if Batch.guarded_write_pending(path):
  return _result(ERR_BUSY, "pending_recovery", "unresolved_transaction")
 return run(PackedStringArray([path]), PackedStringArray(), func(_context): return operation.call())

## Migration backups remain outside the atomic pair. Publish an independently
## verified copy through its reserved sibling, keeping any existing backup.
static func backup_serializer(source: String, target: String) -> Error:
 if not Thread.is_main_thread() or _backup_owners.get(target) != source:
  return ERR_UNAUTHORIZED
 var scratch := target + ".tmp"
 var outcome := Authorization.run_nested(_native_context, PackedStringArray([source, target, scratch]), func(token):
  if FileAccess.file_exists(target):
   return OK
  if DirAccess.dir_exists_absolute(scratch) or DirAccess.dir_exists_absolute(target):
   return ERR_BUSY
  var prior := Planner._read_bytes(source)
  if not prior.ok:
   return ERR_FILE_CANT_READ
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

static func _recover(paths: PackedStringArray, fault := Callable()) -> Dictionary:
 if not Thread.is_main_thread() or _context != null or Batch.active:
  return _result(ERR_BUSY, "busy", "operation_in_progress")
 var plan := Planner.discover(paths)
 if plan.authorization_paths.is_empty():
  var refused := _refuse(plan.state, plan.reason)
  refused.path = plan.path
  return refused
 var boundary := Authorization.run(plan.authorization_paths, func(token):
  return Batch._recover_guarded(token, plan, paths, fault))
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

static func run_production(paths: PackedStringArray, auxiliaries: PackedStringArray, operation: Callable, expected := {}) -> Dictionary:
 var activation := Integration.activation_status()
 if not activation.allowed:
  var result := _result(ERR_UNAVAILABLE, "invalid", "production_integration_incomplete")
  result.blockers = activation.blockers
  return result
 return run(paths, auxiliaries, operation, expected)

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
  if not allowed.has(path):
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
  var limit := Planner.MAX_RECORD_BYTES if path.ends_with(".bak") or path.ends_with(".bak.tmp") else MAX_AUXILIARY_BYTES
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
