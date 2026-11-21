extends RefCounted
# One persistence boundary for both single saves and multi-file gameplay commits.
static var active:=false
static var staged: Dictionary={}
static var failure:=OK
static var journal_path:=""
static var _legacy_serializers := {}
const Legacy = preload("res://legacy_persistence.gd")

static func write_bytes(path: String, bytes: PackedByteArray) -> Error:
 if _guarded_owner != null: return ERR_BUSY
 if not Legacy.fixture_path(path) and not Legacy.Layout.is_participant(path, Legacy.Layout.directories()):
  return ERR_UNAUTHORIZED
 return Legacy.run(PackedStringArray([path]), func(_plan): return _write_bytes(path, bytes))

static func _write_bytes(path: String, bytes: PackedByteArray) -> Error:
 var file := FileAccess.open(path, FileAccess.WRITE)
 if file == null: return FileAccess.get_open_error()
 var stored := file.store_buffer(bytes)
 file.flush()
 var error := file.get_error()
 file.close()
 return ERR_FILE_CANT_WRITE if error == OK and not stored else error

static func write(path: String, bytes: PackedByteArray) -> Error:
 if _guarded_owner != null: return reject_guarded_serializer(ERR_UNAUTHORIZED, path)
 if not Legacy.fixture_path(path) and not Legacy.Layout.is_participant(path, Legacy.Layout.directories()):
  return record_serializer_error(ERR_UNAUTHORIZED, path)
 if active:
  if failure != OK: return failure
  _legacy_serializers.erase(path)
  staged[path] = bytes
  return OK
 return Legacy.run(PackedStringArray([path]), func(_plan):
  var error := _write_bytes(path + ".tmp", bytes)
  return DirAccess.rename_absolute(path + ".tmp", path) if error == OK else error)

static func record_serializer_error(error: Error, path: String) -> Error:
 if _guarded_owner != null:
  return reject_guarded_serializer(error, path)
 if active and failure == OK and error != OK:
  failure = error
 return error

static func legacy_serializer_saved(serializer: RefCounted) -> void:
 if active:
  _legacy_serializers[serializer.path] = serializer
 else:
  serializer.confirm_migration(serializer.path)

static func begin(root: String) -> Error:
 if _guarded_owner != null or active: return ERR_BUSY
 if not Legacy.fixture_path(root) and not Legacy.Layout.is_canonical(root, Legacy.Layout.directories()):
  return ERR_INVALID_PARAMETER
 active = true
 staged = {}
 failure = OK
 journal_path = root + ".transaction"
 _legacy_serializers.clear()
 return OK

static func recover(path: String) -> Error:
 if _guarded_owner != null or active: return ERR_BUSY
 if Legacy.fixture_path(path):
  return _recover_fixture(path)
 if Legacy.held():
  # The owning operation already required a clean footprint. Its own staged
  # files and journal are handled only by _commit_locked.
  return Legacy.run(PackedStringArray([path]), func(_plan): return OK)
 return Legacy.run(PackedStringArray([path]), func(plan):
  if plan.journals.is_empty(): return OK
  var record: Dictionary = plan.journals[0]
  return _recover_locked(record.path, record.entries, record.committed), PackedStringArray(), true)

static func _recover_fixture(path: String) -> Error:
 var journal := path + ".transaction"
 if FileAccess.file_exists(path + ".txn_link"):
  journal = FileAccess.get_file_as_string(path + ".txn_link")
 if not FileAccess.file_exists(journal): return OK
 if not Legacy.fixture_path(journal): return ERR_UNAUTHORIZED
 var config := ConfigFile.new()
 var error := config.load(journal)
 if error != OK: return error
 var entries: Variant = config.get_value("transaction", "entries", {})
 if not entries is Dictionary or not entries.keys().all(Legacy.fixture_path):
  return ERR_INVALID_DATA
 return _recover_locked(journal, entries, config.get_value("transaction", "committed", false))

static func _recover_locked(journal: String, entries: Dictionary, committed: bool) -> Error:
 if not committed:
  for target: String in entries:
   var entry: Dictionary = entries[target]
   var error := OK
   if entry.exists:
    error = _write_bytes(target + ".recovery", entry.bytes)
    if error == OK: error = DirAccess.rename_absolute(target + ".recovery", target)
   elif FileAccess.file_exists(target):
    error = DirAccess.remove_absolute(target)
   if error != OK: return error
 for target: String in entries:
  for suffix in [".txn_link", ".txn_stage", ".recovery"]:
   if not FileAccess.file_exists(target + suffix): continue
   var error := DirAccess.remove_absolute(target + suffix)
   if error != OK: return error
 return DirAccess.remove_absolute(journal)

static func commit() -> Error:
 if _guarded_owner != null: return ERR_BUSY
 if not active: return ERR_UNAUTHORIZED
 var error := failure
 if error == OK and not staged.is_empty():
  var paths := PackedStringArray(staged.keys())
  paths.append(journal_path.trim_suffix(".transaction"))
  error = Legacy.run(paths, func(_plan): return _commit_locked())
 cancel()
 return error

static func _commit_locked() -> Error:
 var entries := {}
 var stages := PackedStringArray()
 for path: String in staged:
  var exists := FileAccess.file_exists(path)
  var original := PackedByteArray()
  if exists:
   var read := Planner._read_bytes(path)
   if not read.ok: return ERR_FILE_CANT_READ
   original = read.bytes
  entries[path] = {"exists":exists, "bytes":original}
 for path: String in staged:
  stages.append(path + ".txn_stage")
  var save_error := _write_bytes(path + ".txn_stage", staged[path])
  if save_error != OK:
   for scratch in stages:
    if FileAccess.file_exists(scratch): DirAccess.remove_absolute(scratch)
   return save_error
 var journal := ConfigFile.new()
 journal.set_value("transaction", "entries", entries)
 journal.set_value("transaction", "committed", false)
 var error := journal.save(journal_path)
 if error != OK: return error
 for path: String in staged:
  error = _write_bytes(path + ".txn_link", journal_path.to_utf8_buffer())
  if error != OK: break
 if error == OK:
  for path: String in staged:
   error = DirAccess.rename_absolute(path + ".txn_stage", path)
   if error != OK: break
 var committed := false
 if error == OK:
  journal.set_value("transaction", "committed", true)
  error = journal.save(journal_path)
  committed = error == OK
  if committed:
   for path in _legacy_serializers:
    _legacy_serializers[path].confirm_migration(path)
 var recovered := _recover_locked(journal_path, entries, committed)
 return recovered if error == OK else error

static func cancel() -> void:
 if _guarded_owner != null: return
 _legacy_serializers.clear()
 active = false
 staged = {}

# B1 opt-in API. Legacy callers above retain their existing Error/void contract.
const Authorization = preload("res://persistence_authorization.gd")
const Planner = preload("res://persistence_recovery_plan.gd")
const Evidence = preload("res://persistence_evidence.gd")

enum Outcome { COMMITTED, ABORTED_RESTORED, COMMITTED_CLEANUP_PENDING, UNCERTAIN }

class Finalization extends RefCounted:
 var outcome: Outcome = Outcome.UNCERTAIN
 var original_error: Error = OK
 var recovery_error: Error = OK
 var cleanup_error: Error = OK
 var native_error := 0
 var cleanup_native_error := 0
 var phase := "preflight"
 var failed_path := ""
 var recovery_path := ""
 var cleanup_path := ""
 var paths := PackedStringArray()
 var journal_anchor := ""
 var attempt_id := ""
 var verification := {}
 var write_blocked := true

static var _guarded_owner: RefCounted
static var _blocked_paths := {}

## Legacy entry points remain available outside an opt-in transaction.
static func guarded_active() -> bool:
 return _guarded_owner != null

static func guarded_write_pending(path: String) -> bool:
 return _blocked_paths.has(path)

static func reject_guarded_serializer(error: Error, path: String) -> Error:
 if Thread.is_main_thread() and _guarded_owner != null and error != OK:
  _guarded_owner._fail(error, "serializer", path)
 return error

# Internal entry for PersistenceOperations. The native token is never handed to
# the action. The optional fault hook is used only by disposable fixtures.
static func _run_guarded(token: RefCounted, paths: PackedStringArray, anchor: String, action: Callable, no_op: bool, fault := Callable(), removals := PackedStringArray()) -> Dictionary:
 if not Thread.is_main_thread() or active or _guarded_owner != null:
  return {"error": ERR_BUSY, "ran": false}
 var ordered := paths.duplicate()
 ordered.sort()
 if ordered.is_empty() or ordered.size() > Planner.MAX_JOURNAL_ENTRIES or not ordered.has(anchor) or not action.is_valid():
  return {"error": ERR_INVALID_PARAMETER, "ran": false}
 if not Evidence.Layout.valid_journal_scope(anchor, ordered, Evidence.Layout.directories()):
  return {"error": ERR_INVALID_PARAMETER, "ran": false}
 var scope := PackedStringArray()
 for index in ordered.size():
  var path := ordered[index]
  if index > 0 and path == ordered[index - 1]:
   return {"error": ERR_INVALID_PARAMETER, "ran": false}
  if _blocked_paths.has(path):
   return {"error": ERR_BUSY, "ran": false, "reason": "unresolved_transaction"}
  for suffix: String in [""] + Planner.ARTIFACTS:
   scope.append(path + suffix)
 var boundary := Authorization.run_nested(token, scope, func(_token):
  var plan := Planner.discover(ordered)
  if not plan.state in ["healthy", "empty"] or plan.participants != ordered:
   return {"error": ERR_BUSY, "ran": false, "reason": plan.reason}
  if not no_op and not Authorization.replacement_available():
   return {"error": ERR_UNAVAILABLE, "ran": false, "reason": "replacement_backend_unavailable"}
  var attempt := GuardedAttempt.new()
  attempt.token = token
  attempt.plan = plan
  attempt.result.paths = ordered
  attempt.result.journal_anchor = anchor
  attempt.result.attempt_id = Crypto.new().generate_random_bytes(16).hex_encode()
  attempt.journal = anchor + ".transaction"
  attempt.no_op = no_op
  attempt.fault = fault
  if attempt.capture_originals():
   _guarded_owner = attempt
   attempt.accepting_stages = true
   for path in removals:
    attempt.stage_absence(path)
   var stage := func(path: String, bytes: PackedByteArray) -> Error: return attempt.stage(path, bytes)
   var action_value: Variant = action.call(stage)
   attempt.accepting_stages = false
   attempt.finalize()
   _guarded_owner = null
   _remember_uncertainty(attempt.result)
   return {"error": OK, "ran": true, "action_ran": true, "value": action_value, "outcome": attempt.result}
  _remember_uncertainty(attempt.result)
  return {"error": OK, "ran": true, "action_ran": false, "value": null, "outcome": attempt.result})
 if not boundary.ran:
  return {"error": boundary.error, "ran": false}
 return boundary.value

static func _remember_uncertainty(result: Finalization) -> void:
 # Pending evidence is rediscovered after restart by the existing planner.
 # An in-process uncertainty stays blocked even when there is no journal.
 if result.outcome == Outcome.UNCERTAIN:
  for path in result.paths:
   _blocked_paths[path] = result.attempt_id

class GuardedAttempt extends RefCounted:
 var result := Finalization.new()
 var originals := {}
 var requested := {}
 var owned := PackedStringArray()
 var journal := ""
 var no_op := false
 var accepting_stages := false
 var fault: Callable
 var uncommitted := PackedByteArray()
 var committed := PackedByteArray()
 var token: RefCounted
 var plan := {}

 func capture_originals() -> bool:
  for path in result.paths:
   var prior := _read_state(path, Planner.MAX_RECORD_BYTES)
   if prior.error != OK:
    _fail(prior.error, "read_original", path)
    return false
   originals[path] = {"exists": prior.exists, "bytes": prior.bytes}
  result.verification.originals_captured = true
  return true

 func stage(path: String, bytes: PackedByteArray) -> Error:
  if not accepting_stages or not Thread.is_main_thread():
   return ERR_UNAUTHORIZED
  if no_op or not originals.has(path) or bytes.size() > Planner.MAX_RECORD_BYTES:
   _fail(ERR_INVALID_PARAMETER, "stage_request", path)
   return ERR_INVALID_PARAMETER
  requested[path] = {"exists": true, "bytes": bytes.duplicate()}
  return OK

 func stage_absence(path: String) -> Error:
  if not accepting_stages or not Thread.is_main_thread():
   return ERR_UNAUTHORIZED
  if result.original_error != OK:
   return result.original_error
  if no_op or not originals.has(path) or not Evidence.Layout.is_canonical(path, Evidence.Layout.directories()):
   _fail(ERR_INVALID_PARAMETER, "stage_absence", path)
   return result.original_error
  requested[path] = {"exists": false, "bytes": PackedByteArray()}
  return OK

 func finalize() -> void:
  if result.original_error != OK or (not no_op and requested.size() != originals.size()):
   _fail(ERR_INVALID_DATA, "validate_staging", "")
   _abort()
   return
  if no_op:
   result.verification.originals_verified = _verify_all(originals).error == OK
   if result.verification.originals_verified:
    result.verification.no_op = true
    _complete_commit()
   else:
    _fail(ERR_INVALID_DATA, "verify_no_op", "")
   return
  var config := ConfigFile.new()
  config.set_value("transaction", "entries", originals)
  config.set_value("transaction", "committed", false)
  uncommitted = Evidence.journal_image(config.encode_to_text().to_utf8_buffer(), result.attempt_id)
  config.set_value("transaction", "committed", true)
  committed = Evidence.journal_image(config.encode_to_text().to_utf8_buffer(), result.attempt_id)
  if uncommitted.size() > Planner.MAX_RECORD_BYTES or committed.size() > Planner.MAX_RECORD_BYTES:
   _fail(ERR_INVALID_DATA, "journal_size_limit", journal)
   _abort()
   return
  var proof := Evidence.make(result.attempt_id, result.journal_anchor, result.paths, requested, uncommitted, committed)
  var proof_bytes := Evidence.encode(proof)
  var old_bytes := 0
  var stage_bytes := 0
  for path in result.paths:
   old_bytes += originals[path].bytes.size()
   stage_bytes += requested[path].bytes.size()
  # Recheck the complete artifact reservation and global budget after the callback.
  var fresh := Planner.discover(result.paths)
  if fresh.state != plan.state or fresh.participants != plan.participants or fresh.observed != plan.observed:
   _fail(ERR_INVALID_DATA, "transaction_scope_changed", journal)
   return
  if not Planner.check_footprint(fresh, result.paths, result.journal_anchor, old_bytes, stage_bytes,
   maxi(uncommitted.size(), committed.size()), proof_bytes.size()):
   _fail(ERR_INVALID_DATA, "transaction_footprint", journal)
   _abort()
   return
  # Never publish a record that the bounded restart parser itself cannot read.
  var pattern := RegEx.create_from_string(Planner.JOURNAL)
  var layout := Evidence.Layout.directories()
  if not Planner._journal(uncommitted, layout, pattern).ok or not Planner._journal(committed, layout, pattern).ok or Evidence.parse(proof_bytes, result.journal_anchor, result.attempt_id, result.paths) != proof:
   _fail(ERR_INVALID_DATA, "unreadable_transaction_evidence", journal)
   _abort()
   return
  var prior := _verify_all(originals)
  if prior.error != OK:
   _fail(prior.error, "originals_changed", prior.path)
   return
  var anchor := result.journal_anchor
  var marker_temp := anchor + Evidence.SCRATCH
  if not _stage_artifact(marker_temp, uncommitted, "stage_journal"):
   _abort()
   return
  if not _move(marker_temp, journal, "publish_journal"):
   var absence := _verify_state(journal, {"exists": false, "bytes": PackedByteArray()})
   if absence == OK:
    _abort()
   else:
    result.recovery_error = absence
    result.recovery_path = journal
   return
  owned.append(journal)
  var journal_error := _verify_bytes(journal, uncommitted)
  if journal_error != OK:
   _fail(journal_error, "verify_journal", journal)
   return
  result.verification.uncommitted_journal_verified = true
  var prepared := anchor + Evidence.EXPECTED
  # Use the reserved publication scratch for atomic manifest publication too.
  if not _stage_artifact(marker_temp, proof_bytes, "stage_expected"):
   _abort()
   return
  if not _move(marker_temp, prepared, "publish_expected"):
   _abort_if_unpublished(prepared)
   return
  owned.append(prepared)
  var proof_file := _read_state(prepared, Evidence.MAX_BYTES)
  if proof_file.error != OK or not proof_file.exists or Evidence.parse(proof_file.bytes, anchor, result.attempt_id, result.paths) != proof:
   _fail(proof_file.error if proof_file.error != OK else ERR_INVALID_DATA, "verify_expected", prepared)
   return
  result.verification.expected_state_sha256 = Evidence.digest(proof_bytes)
  var fallback := anchor + Evidence.FALLBACK
  if not _stage_artifact(marker_temp, uncommitted, "stage_fallback"):
   _abort()
   return
  if not _move(marker_temp, fallback, "publish_fallback"):
   _abort_if_unpublished(fallback)
   return
  owned.append(fallback)
  var fallback_error := _verify_bytes(fallback, uncommitted)
  if fallback_error != OK:
   _fail(fallback_error, "verify_fallback", fallback)
   return
  result.verification.fallback_sha256 = proof.uncommitted_sha256
  for path in result.paths:
   if requested[path].exists and not _stage_artifact(path + ".txn_stage", requested[path].bytes, "stage"):
    _abort()
    return
  for path in result.paths:
   var link := path + ".txn_link"
   var link_scratch := path + ".recovery"
   if not _stage_artifact(link_scratch, journal.to_utf8_buffer(), "stage_link"):
    _abort()
    return
   if not _move(link_scratch, link, "link"):
    _abort_if_unpublished(link)
    return
   owned.append(link)
   var link_error := _verify_bytes(link, journal.to_utf8_buffer())
   if link_error != OK:
    _fail(link_error, "verify_link", link)
    return

  result.verification.replacements = 0
  for path in result.paths:
   if not _install(path):
    _resolve_replacement_failure()
    return
   result.verification.replacements += 1
  var replacement := _verify_all(requested)
  result.verification.replacements_verified = replacement.error == OK
  if replacement.error != OK:
   _fail(replacement.error, "verify_replacements", replacement.path)
   _resolve_replacement_failure()
   return
  if _verify_bytes(fallback, uncommitted) != OK or _verify_bytes(prepared, proof_bytes) != OK:
   _fail(ERR_INVALID_DATA, "publication_evidence_changed", fallback)
   return
  if _stage_artifact(marker_temp, committed, "stage_commit_marker"):
   _move(marker_temp, journal, "publish_commit_marker")
  var marker_error := _verify_bytes(journal, committed)
  if marker_error != OK:
   _fail(marker_error, "verify_commit_marker", journal)
   _resolve_replacement_failure()
   return
  result.verification.commit_marker_verified = true
  replacement = _verify_all(requested)
  if replacement.error != OK:
   _fail(replacement.error, "verify_committed_participants", replacement.path)
   return
  _complete_commit(prepared, proof_bytes)

 func _install(path: String) -> bool:
  if requested[path].exists:
   return _move(path + ".txn_stage", path, "replace")
  var error := _fault("remove", path)
  if error == OK:
   error = _verify_state(path, originals[path])
  if error == OK and originals[path].exists:
   error = DirAccess.remove_absolute(path)
  if error == OK:
   error = _verify_state(path, requested[path])
  if error != OK:
   _fail(error, "remove", path)
  return error == OK

 func _resolve_replacement_failure() -> void:
  # Resolve only this live attempt. Restart recovery stays on the legacy path.
  # Contradictory bytes or a missing/ambiguous journal grant no restore authority.
  var journal_error := _verify_bytes(journal, uncommitted)
  if journal_error != OK:
   result.recovery_error = journal_error
   result.recovery_path = journal
   return
  for path in result.paths:
   var current := _read_state(path, Planner.MAX_RECORD_BYTES)
   if current.error != OK or (_state(current) != originals[path] and _state(current) != requested[path]):
    result.recovery_error = current.error if current.error != OK else ERR_INVALID_DATA
    result.recovery_path = path
    return
  for path in result.paths:
   if _has_state(path, originals[path]):
    continue
   var prior: Dictionary = originals[path]
   var error := _fault("restore", path)
   if error == OK and prior.exists:
    var scratch := path + ".recovery"
    if not owned.has(scratch):
     owned.append(scratch)
    error = _write_checked(scratch, prior.bytes)
    if error == OK:
     var moved := Authorization.replace_authorized(token, scratch, path)
     error = moved.error
     result.verification.restore_native_error = moved.native_error
   elif error == OK:
    error = DirAccess.remove_absolute(path)
   if error != OK:
    result.recovery_error = error
    result.recovery_path = path
    return
  _abort()

 func _abort_if_unpublished(path: String) -> void:
  var absence := _verify_state(path, {"exists": false, "bytes": PackedByteArray()})
  if absence == OK:
   _abort()
  else:
   result.recovery_error = absence
   result.recovery_path = path

 func _abort() -> void:
  var restored := _verify_all(originals)
  result.verification.originals_verified = restored.error == OK
  if restored.error != OK:
   result.recovery_error = restored.error
   result.recovery_path = restored.path
   return
  result.outcome = Outcome.ABORTED_RESTORED
  _cleanup()

 func _complete_commit(prepared := "", proof := PackedByteArray()) -> void:
  result.outcome = Outcome.COMMITTED
  if result.original_error == OK:
   result.phase = "committed"
  if not prepared.is_empty():
   var receipt := result.journal_anchor + Evidence.RECEIPT
   var error := _verify_bytes(prepared, proof)
   if error == OK:
    error = _fault("publish_receipt", receipt)
   if error == OK:
    var moved := Authorization.replace_authorized(token, prepared, receipt)
    error = moved.error
    result.cleanup_native_error = moved.native_error
   if error == OK:
    error = _verify_bytes(receipt, proof)
   if error != OK:
    result.cleanup_error = error
    result.cleanup_path = receipt
   else:
    owned.append(receipt)
    result.verification.receipt_sha256 = Evidence.digest(proof)
  if result.cleanup_error == OK:
   _cleanup()
  if result.cleanup_error != OK:
   result.outcome = Outcome.COMMITTED_CLEANUP_PENDING
   if result.original_error == OK:
    result.phase = "cleanup"

 func _cleanup() -> void:
  # Remove the journal last. If any earlier cleanup fails, keep its record.
  var targets := owned.duplicate()
  # Fallback precedes prepared evidence on abort. The receipt outlives the primary.
  for last in [result.journal_anchor + Evidence.FALLBACK, result.journal_anchor + Evidence.EXPECTED, journal, result.journal_anchor + Evidence.RECEIPT]:
   if targets.has(last):
    targets.remove_at(targets.find(last))
    targets.append(last)
  for path in targets:
   var prior := _read_state(path, Planner.MAX_RECORD_BYTES)
   var error: Error = prior.error
   if error == OK and prior.exists:
    error = _fault("cleanup", path)
    if error == OK:
     error = DirAccess.remove_absolute(path)
    if error == OK:
     error = _verify_state(path, {"exists": false, "bytes": PackedByteArray()})
   if error != OK:
    result.cleanup_error = error
    result.cleanup_path = path
    return
  result.verification.cleanup_verified = true
  result.write_blocked = false

 func _stage_artifact(path: String, bytes: PackedByteArray, phase: String) -> bool:
  var error := _fault(phase, path)
  if error == OK and not owned.has(path):
   error = _verify_state(path, {"exists": false, "bytes": PackedByteArray()})
   if error == OK:
    owned.append(path)
  if error == OK:
   error = _write_checked(path, bytes)
  if error != OK:
   _fail(error, phase, path)
  return error == OK

 func _move(source: String, target: String, phase: String) -> bool:
  var error := _fault(phase, target)
  if error == OK:
   var moved := Authorization.replace_authorized(token, source, target)
   error = moved.error
   if error != OK:
    result.native_error = moved.native_error
  if error != OK:
   _fail(error, phase, target)
  return error == OK

 func _write_checked(path: String, bytes: PackedByteArray) -> Error:
  var file := FileAccess.open(path, FileAccess.WRITE)
  if file == null:
   return FileAccess.get_open_error()
  var stored := file.store_buffer(bytes)
  file.flush()
  var error := file.get_error()
  file.close()
  if error != OK:
   return error
  return _verify_bytes(path, bytes) if stored else ERR_FILE_CANT_WRITE

 func _verify_all(states: Dictionary) -> Dictionary:
  for path: String in states:
   var error := _verify_state(path, states[path])
   if error != OK:
    return {"error": error, "path": path}
  return {"error": OK, "path": ""}

 func _verify_bytes(path: String, bytes: PackedByteArray) -> Error:
  return _verify_state(path, {"exists": true, "bytes": bytes})

 func _has_state(path: String, expected: Dictionary) -> bool:
  return _verify_state(path, expected) == OK

 func _verify_state(path: String, expected: Dictionary) -> Error:
  var actual := _read_state(path, Planner.MAX_RECORD_BYTES)
  if actual.error != OK:
   return actual.error
  return OK if _state(actual) == expected else ERR_INVALID_DATA

 func _state(actual: Dictionary) -> Dictionary:
  return {"exists": actual.exists, "bytes": actual.bytes}

 func _read_state(path: String, limit: int) -> Dictionary:
  var parent := DirAccess.open(path.get_base_dir())
  if parent == null:
   return {"error": DirAccess.get_open_error()}
  var leaf := path.get_file()
  parent.include_hidden = true
  var error := parent.list_dir_begin()
  if error != OK:
   return {"error": error}
  var found := false
  var count := 0
  var name := parent.get_next()
  while not name.is_empty():
   count += 1
   if count > Planner.MAX_DIRECTORY_ENTRIES:
    parent.list_dir_end()
    return {"error": ERR_INVALID_DATA}
   if name.nocasecmp_to(leaf) == 0:
    var unsafe := found or name != leaf or parent.current_is_dir() or parent.is_link(name)
    if unsafe:
     parent.list_dir_end()
     return {"error": ERR_INVALID_DATA}
    found = true
   name = parent.get_next()
  parent.list_dir_end()
  if not found:
   return {"error": OK, "exists": false, "bytes": PackedByteArray()}
  var file := FileAccess.open(path, FileAccess.READ)
  if file == null:
   return {"error": FileAccess.get_open_error()}
  var length := file.get_length()
  if length < 0 or length > limit:
   return {"error": ERR_INVALID_DATA}
  var bytes := file.get_buffer(length)
  error = file.get_error()
  if error != OK:
   return {"error": error}
  if bytes.size() != length or file.get_length() != length:
   return {"error": ERR_FILE_CANT_READ}
  return {"error": OK, "exists": true, "bytes": bytes}

 func _fail(error: Error, phase: String, path: String) -> void:
  if result.original_error == OK:
   result.original_error = error
   result.phase = phase
   result.failed_path = path

 func _fault(phase: String, path: String) -> Error:
  return fault.call(phase, path) if fault.is_valid() else OK
## Executes only a plan freshly rediscovered with the original complete scope.
static func _recover_guarded(token: RefCounted, preview: Dictionary, paths: PackedStringArray, fault: Callable, idle_only := false) -> Dictionary:
 var answer := {
  "state": "pending_recovery", "reason": "", "path": "", "write_blocked": true,
  "filesystem_error": OK, "restoration_error": OK, "cleanup_error": OK,
  "authorization_error": OK, "native_error": 0, "records": [], "verified": false,
 }
 if active or _guarded_owner != null:
  answer.authorization_error = ERR_BUSY
  answer.reason = "save_batch_in_progress"
  return answer
 var authorized := Authorization.run_nested(token, preview.authorization_paths, func(_token):
  var locked := Planner.revalidate(preview, paths, token)
  if not locked.locked:
   answer.reason = locked.reason
   answer.path = locked.path
   answer.authorization_error = ERR_BUSY
   return answer
  if idle_only:
   var operations = load("res://persistence_operations.gd")
   var scratch: String = operations.recovery_scratch(locked.participants)
   if not scratch.is_empty():
    answer.reason = "metadata_publication_pending"
    answer.path = scratch
    answer.authorization_error = ERR_BUSY
    return answer
   for path: String in locked.participants:
    var marker := path.get_base_dir().path_join("session.cfg")
    if locked.active_leases.get(marker,false) or FileAccess.file_exists(marker+".tmp") or DirAccess.dir_exists_absolute(marker+".tmp"):
     answer.reason = "active_or_unresolved_session_lease"
     answer.authorization_error = ERR_BUSY
     answer.path = marker
     return answer
  if locked.journals.is_empty():
   for path in locked.participants:
    if _blocked_paths.has(path):
     answer.reason = "unresolved_process_state"
     return answer
   answer.state = "clean"
   answer.verified = true
   answer.write_blocked = false
   return answer
  if not Authorization.replacement_available():
   answer.reason = "replacement_backend_unavailable"
   answer.authorization_error = ERR_UNAVAILABLE
   return answer

  var jobs: Array[RestartRecovery] = []
  for record in locked.journals:
   var job := RestartRecovery.new()
   job.token = token
   job.fault = fault
   job.record = record
   job.observed = locked.observed
   job.scope = locked.authorization_paths
   if not job.preflight():
    return job.report(answer)
   jobs.append(job)
  for path in locked.participants:
   if _blocked_paths.has(path) and not jobs.any(func(job): return job.members.has(path) and job.attempt == _blocked_paths[path] and not job.attempt.is_empty()):
    answer.reason = "unresolved_process_state"
    answer.path = path
    return answer

  var all_originals := {}
  for job in jobs:
   all_originals.merge(job.originals)
  var reservation := Planner.restore_footprint(locked.authorization_paths, locked.observed, all_originals)
  if reservation != OK:
   answer.filesystem_error = reservation
   answer.reason = "restore_footprint_limit"
   return answer
  for job in jobs:
   if not job.execute():
    return job.report(answer)
   job.report(answer)
  # Check the complete discovered set again before releasing the lock.
  var final := Planner.discover(locked.participants)
  if not final.state in ["healthy", "empty"] or final.participants != locked.participants or not Array(final.authorization_paths).all(func(path): return locked.authorization_paths.has(path)):
   for path in locked.participants:
    _blocked_paths[path] = true
   answer.reason = "post_recovery_plan_changed"
   answer.path = final.path
   return answer
  for job in jobs:
   if not job.verify_participants():
    for path in job.members:
     _blocked_paths[path] = true
    return job.report(answer, false)
  for job in jobs:
   for path in job.members:
    _blocked_paths.erase(path)
  answer.state = "recovered"
  answer.verified = true
  answer.write_blocked = false
  return answer)
 if not authorized.ran:
  answer.reason = "authorization_scope_rejected"
  answer.authorization_error = authorized.error
 return answer

class RestartRecovery extends GuardedAttempt:
 var record := {}
 var observed := {}
 var scope := PackedStringArray()
 var members := PackedStringArray()
 var expected := {}
 var committed_state := false
 var durable := false
 var attempt := ""
 var verified_state := false
 var reason := ""
 var authority := ""
 var receipt := ""
 var prepared := ""
 var steps := PackedStringArray()
 var changed := 0

 func preflight() -> bool:
  journal = record.path
  receipt = record.anchor + Evidence.RECEIPT
  prepared = record.anchor + Evidence.EXPECTED
  members = PackedStringArray(record.entries.keys())
  if not members.has(record.anchor):
   members.append(record.anchor)
  members.sort()
  committed_state = record.get("committed", false) or record.get("receipt", false)
  var proof: Dictionary = record.get("evidence", {})
  attempt = record.get("attempt", proof.get("attempt", ""))
  durable = not attempt.is_empty()
  authority = receipt if record.get("receipt", false) else journal
  if record.get("evidence_only", false) and not record.get("receipt", false):
   return refuse("authoritative_primary_missing", journal)
  if committed_state and proof.is_empty():
   return refuse("committed_without_expected_state", journal)
  if committed_state:
   for entry in proof.participants:
    expected[entry.path] = entry
  else:
   originals = record.entries
  for path in members:
   for suffix: String in [""] + Planner.ARTIFACTS:
    var target := path + suffix
    if not scope.has(target) or not observed.has(target):
     return refuse("recovery_scope_incomplete", target)
    if suffix.is_empty() or observed[target] == "absent":
     continue
    if record.get("evidence_only", false) and target != receipt:
     return refuse("receipt_only_with_residue", target)
    if suffix == ".recovery" and not committed_state:
     var scratch := _read_state(target, Planner.MAX_RECORD_BYTES)
     if scratch.error != OK:
      result.original_error = scratch.error
      return refuse("recovery_file_unreadable", target)
     var prior: Dictionary = originals[path]
     var bytes: PackedByteArray = scratch.bytes
     var link_prefix := durable and bytes == journal.to_utf8_buffer().slice(0, bytes.size())
     if not link_prefix and (not prior.exists or bytes != prior.bytes.slice(0, bytes.size())):
      return refuse("unowned_restore_scratch", target)
    if suffix == ".recovery" and committed_state:
     return refuse("unexpected_committed_restore_scratch", target)
    if suffix == Evidence.SCRATCH and (not durable or record.get("receipt", false)):
     return refuse("unowned_publication_scratch", target)
    if suffix == Evidence.SCRATCH and committed_state:
     return refuse("unexpected_committed_publication_scratch", target)
    if suffix == Evidence.SCRATCH and not valid_publication_scratch(target, proof):
     return false
    steps.append(target)
  for path in steps:
   if not check_observed(path):
    return false
  # Validate every participant before restoring even the first one.
  if committed_state:
   return verify_participants()
  for path: String in originals:
   var actual := _read_state(path, Planner.MAX_RECORD_BYTES)
   if actual.error != OK:
    result.original_error = actual.error
    return refuse("participant_unreadable", path)
   if _state(actual) == originals[path] or not durable:
    continue
   var match_new := false
   for entry in proof.get("participants", []):
    if entry.path == path:
     match_new = Evidence.matches(entry, actual.exists, actual.bytes)
     break
   if not match_new:
    return refuse("uncommitted_participant_mismatch", path)
  return true

 func valid_publication_scratch(path: String, proof: Dictionary) -> bool:
  var scratch := _read_state(path, Planner.MAX_RECORD_BYTES)
  var primary := _read_state(journal, Planner.MAX_RECORD_BYTES)
  if scratch.error != OK or primary.error != OK:
   result.original_error = scratch.error if scratch.error != OK else primary.error
   return refuse("recovery_file_unreadable", path)
  var bytes: PackedByteArray = scratch.bytes
  if bytes == primary.bytes.slice(0, bytes.size()):
   return true
  if proof.is_empty():
   var candidate := Evidence.parse(bytes, record.anchor, attempt, members)
   if not candidate.is_empty() and Evidence.binds_journal(primary.bytes, candidate, false):
    return true
  else:
   var cfg := ConfigFile.new()
   cfg.set_value("transaction", "entries", originals)
   cfg.set_value("transaction", "committed", true)
   var image := Evidence.journal_image(cfg.encode_to_text().to_utf8_buffer(), attempt)
   if Evidence.binds_journal(image, proof, true) and bytes == image.slice(0, bytes.size()):
    return true
  return refuse("unowned_publication_scratch", path)

 func execute() -> bool:
  if not check_observed(authority):
   return false
  if not committed_state:
   for path: String in originals:
    if not restore_one(path):
     return false
  if not verify_participants():
   return false
  verified_state = true
  if committed_state and not record.get("receipt", false):
   if not promote_receipt():
    return false
  # Keep primary or receipt until all owned nonterminal artifacts are gone.
  for last in [record.anchor + Evidence.FALLBACK, prepared, journal, receipt]:
   if steps.has(last):
    steps.remove_at(steps.find(last))
    steps.append(last)
  for path in steps:
   if path == authority and (not verify_participants() or not verify_terminal_scope()):
    return false
   if not remove_observed(path):
    return false
  return true

 func verify_terminal_scope() -> bool:
  # Only the terminal authority may remain for this job. Detect newly
  # introduced or changed residue before discarding the authoritative record.
  for path in members:
   for suffix: String in Planner.ARTIFACTS:
    var target := path + suffix
    if target == authority:
     continue
    var error := _verify_state(target, {"exists": false, "bytes": PackedByteArray()})
    if error != OK:
     result.cleanup_error = error
     return refuse("terminal_scope_changed", target)
  return true

 func restore_one(path: String) -> bool:
  var prior: Dictionary = originals[path]
  if _has_state(path, prior):
   return true
  var scratch := path + ".recovery"
  if not check_observed(path) or not check_observed(scratch):
   return false
  var error := _fault("restore", path)
  if error == OK and prior.exists:
   error = _write_checked(scratch, prior.bytes)
   if error == OK:
    var moved := Authorization.replace_authorized(token, scratch, path)
    error = moved.error
    result.native_error = moved.native_error
    if error == OK:
     observed[scratch] = "absent"
  elif error == OK:
   error = DirAccess.remove_absolute(path)
  if error == OK:
   error = _verify_state(path, prior)
  if error != OK:
   result.recovery_error = error
   return refuse("restore_failed", path)
  changed += 1
  return after_step("after_restore", path)

 func verify_participants() -> bool:
  if not committed_state:
   var verified := _verify_all(originals)
   if verified.error != OK:
    result.recovery_error = verified.error
    return refuse("original_verification_failed", verified.path)
   return true
  for path: String in expected:
   var file := _read_state(path, Planner.MAX_RECORD_BYTES)
   if file.error != OK:
    result.original_error = file.error
    return refuse("committed_file_unreadable", path)
   if not Evidence.matches(expected[path], file.exists, file.bytes):
    return refuse("committed_state_mismatch", path)
  return true

 func promote_receipt() -> bool:
  if not check_observed(prepared) or not check_observed(receipt):
   return false
  var error := _fault("publish_receipt", receipt)
  if error == OK:
   var moved := Authorization.replace_authorized(token, prepared, receipt)
   error = moved.error
   result.cleanup_native_error = moved.native_error
  if error != OK:
   result.cleanup_error = error
   return refuse("receipt_publication_failed", receipt)
  observed[receipt] = observed[prepared]
  observed[prepared] = "absent"
  if not check_observed(receipt):
   return false
  authority = receipt
  steps.append(receipt)
  return true

 func remove_observed(path: String) -> bool:
  if not check_observed(path):
   return false
  if observed[path] == "absent":
   return true
  var error := _fault("cleanup", path)
  if error == OK:
   error = DirAccess.remove_absolute(path)
  if error == OK:
   error = _verify_state(path, {"exists": false, "bytes": PackedByteArray()})
  if error != OK:
   result.cleanup_error = error
   return refuse("cleanup_failed", path)
  return after_step("after_cleanup", path)

 func after_step(phase: String, path: String) -> bool:
  var error := _fault(phase, path)
  if error == OK:
   return true
  result.original_error = error
  return refuse("recovery_interrupted", path)

 func check_observed(path: String) -> bool:
  if not scope.has(path) or not observed.has(path):
   return refuse("recovery_scope_incomplete", path)
  var file := _read_state(path, Planner.MAX_RECORD_BYTES)
  if file.error != OK:
   result.original_error = file.error
   return refuse("recovery_file_unreadable", path)
  if (Evidence.digest(file.bytes) if file.exists else "absent") != observed[path]:
   return refuse("recovery_observation_changed", path)
  return true

 func refuse(problem: String, path: String) -> bool:
  reason = problem
  result.failed_path = path
  return false

 func report(answer: Dictionary, append := true) -> Dictionary:
  if append:
   answer.records.append({"anchor": record.anchor, "paths": members,
    "disposition": "committed_cleanup" if committed_state else "restore_originals",
    "attempt": attempt, "restored": changed, "verified_state": verified_state, "complete": reason.is_empty()})
  if not reason.is_empty():
   answer.reason = reason
   answer.path = result.failed_path
   answer.filesystem_error = result.original_error
   answer.restoration_error = result.recovery_error
   answer.cleanup_error = result.cleanup_error
   answer.native_error = result.native_error if result.native_error != 0 else result.cleanup_native_error
  return answer
