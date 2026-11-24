extends RefCounted
## Owns one world's persistence access, recovery hold and shutdown lifecycle.
## Original store instances retain their lease digests across title/world handoff.
## Receives only persistence participants and confirmed selection facts, never Game.

const Ops = preload("res://persistence_operations.gd")
const Slots = preload("res://save_slots.gd")
const Inspection = preload("res://persistence_save_inspection.gd")
const Profile = preload("res://character_profile.gd")
const Batch = preload("res://save_batch.gd")

var _garden: RefCounted
var _roster: RefCounted
var _garden_slot := -1
var _profile_slot := -1
var _garden_path := ""
var _profile_path := ""
# Lease markers expire after 30 seconds. Renew with two full intervals in
# reserve; a transiently busy native lock gets a retry after one second.
const RENEW_SECONDS := 8.0
const BUSY_RETRY_SECONDS := 1.0
var _heartbeat_at := 0.0
var _profile_heartbeat_at := 0.0
var _stagger_heartbeats := false

## Session state is independent of scene lifetime, reward receipts and durable
## recovery evidence. A released guarded session never becomes an unguarded one.
enum Block { NONE, RECOVERY, UNCERTAIN, COMMITTED_CLEANUP, READ_ONLY }
const CLEANUP_NOTICE := "Saved. Recovery cleanup is pending. Further saves are blocked."
var _guarded := false
var _stopping := false
var _block: Block = Block.NONE
var _pending_notice := ""
var _feedback_reported := false
var _legacy_cleanup: Batch.Finalization

func is_guarded() -> bool:
 return _guarded

func is_stopping() -> bool:
 return _stopping

func is_blocked() -> bool:
 return _block != Block.NONE

func can_write() -> bool:
 return not is_blocked() and (not _guarded or (not _stopping and owns_leases()))

func pending_notice() -> String:
 return _pending_notice if is_blocked() else ""

func can_publish_state() -> bool:
 # A confirmed cleanup warning may travel to guests, but combat stays stopped.
 return not is_blocked() or (_block == Block.COMMITTED_CLEANUP and _feedback_reported)

func begin_shutdown() -> bool:
 if _stopping: return false
 _stopping = true
 return true

func finish_network_detach() -> void:
 # Leaving a network session may retain this Garden. It never clears recovery.
 _stopping = false

func status() -> Dictionary:
 return {"guarded": _guarded, "stopping": _stopping, "blocked": is_blocked(),
  "block": Block.keys()[_block], "writable": can_write(), "owns_leases": owns_leases(),
  "notice": pending_notice()}

func record_finalization(boundary: Dictionary) -> void:
 if is_blocked(): return # A retry cannot reinterpret an already held outcome.
 var execution: Variant = boundary.get("value")
 var final: Batch.Finalization = execution.get("outcome") if execution is Dictionary else null
 if final == null:
  if boundary.get("state") in ["pending_recovery", "ambiguous", "unresolved"] or boundary.get("release_error", OK) != OK:
   _block = Block.UNCERTAIN if boundary.get("reason") == "missing_gameplay_finalization" else Block.RECOVERY
 elif final.write_blocked or boundary.get("release_error", OK) != OK:
  match final.outcome:
   Batch.Outcome.COMMITTED_CLEANUP_PENDING: _block = Block.COMMITTED_CLEANUP
   Batch.Outcome.UNCERTAIN: _block = Block.UNCERTAIN
   _: _block = Block.READ_ONLY

 # A failed lock release requires reopening under a fresh authorization.
 if not _guarded and _block == Block.COMMITTED_CLEANUP and boundary.get("release_error", OK) == OK and final.verification.has("participants"):
  _legacy_cleanup = final

func finish_legacy_cleanup() -> bool:
 if _legacy_cleanup == null or Batch.finish_legacy_cleanup(_legacy_cleanup) != OK: return false
 _legacy_cleanup = null
 _block = Block.NONE
 _pending_notice = ""
 _feedback_reported = false
 return true

func require_departure_recovery() -> void:
 _block = Block.UNCERTAIN
 _pending_notice = "Departure save is uncertain. Recovery is required before saving again."
 _feedback_reported = true

func finalization_feedback(boundary: Dictionary) -> Dictionary:
 var execution: Variant = boundary.get("value")
 var final: Batch.Finalization = execution.get("outcome") if execution is Dictionary else null
 var message := "Save could not start. No changes were saved."
 if final != null:
  match final.outcome:
   Batch.Outcome.COMMITTED:
    message = "" if boundary.error == OK else "Saved. Further saves are blocked until the session is reopened."
   Batch.Outcome.COMMITTED_CLEANUP_PENDING:
    message = CLEANUP_NOTICE
   Batch.Outcome.ABORTED_RESTORED:
    message = "Save cancelled. The original state was verified."
    if final.write_blocked: message += " Recovery cleanup is pending."
   Batch.Outcome.UNCERTAIN:
    message = "Save state is uncertain. Recovery is required before saving again."
 elif boundary.get("state") in ["pending_recovery", "ambiguous", "unresolved"] or boundary.get("reason") == "guarded_persistence_pending":
  message = "Save recovery is pending. Your files are preserved."
 elif boundary.get("reason") in ["stale_session_lease", "unowned_participant", "foreign_session_lease", "guarded_session_stopping"]:
  message = "This session no longer has access to the selected save."
 var prior := pending_notice()
 var clear_status := false
 var set_status := false
 if not prior.is_empty():
  message = prior
 elif is_blocked():
  _pending_notice = message
  _feedback_reported = true
  clear_status = true
 else:
  set_status = not message.is_empty()
 return {"notice": message, "clear_status": clear_status, "set_status": set_status}

func title_return_view(role: String, message: String, guest_notice := "", unguarded_paths := PackedStringArray()) -> Dictionary:
 var pending := pending_notice()
 var paths := PackedStringArray()
 if not pending.is_empty():
  if not _guarded:
   paths = unguarded_paths.duplicate()
  elif role in ["Solo", "Host"]:
   paths.append(_garden_path)
   paths.append(_profile_path)
  elif role in ["Guest", "Connecting"]:
   paths.append(_profile_path)
 elif not guest_notice.is_empty():
  pending = guest_notice
 return {"guarded": _guarded, "notice": pending, "recovery_paths": paths,
  "message": message if pending.is_empty() else pending}


static func outcome(boundary: Dictionary) -> Dictionary:
 if boundary.get("ran", false) and boundary.get("value") is Dictionary:
  var inner: Dictionary = boundary.value
  if boundary.error == OK:
   return inner
  return Ops.management_result(boundary.error, "authorization_release_failed", "unresolved")
 return boundary

static func completed(result: Dictionary) -> bool:
 return result.get("error") == OK and result.get("state") == "completed"

static func notice(result: Dictionary) -> String:
 match result.get("state"):
  "pending_recovery":
   return "Save recovery is pending. Your files are preserved."
  "ambiguous":
   return "The save has conflicting recovery records. It needs review."
  "busy":
   return "This save is in use or temporarily busy."
  "committed_cleanup_pending":
   return "The change was saved. Recovery cleanup is still pending."
  "partial_completion":
   return "The operation only partly completed. Check the save before retrying."
  "unresolved":
   return "The operation needs recovery before it can be retried."
  "empty":
   return "The selected save is no longer available."
 if str(result.get("reason", "")).begins_with("stale_"):
  return "The save changed. Reopen the confirmation."
 if result.get("outcome") != null:
  return "The operation was cancelled and the original save was verified."
 return "The save could not be used. Check its status and try again."

static func label(state: String) -> String:
 match state:
  "busy": return "In use in another window"
  "pending_recovery": return "Recovery pending"
  "ambiguous": return "Conflicting recovery records"
  _: return "Save needs attention"

static func garden_summary(path: String) -> Dictionary:
 var info := Inspection.garden(path)
 _apply_scratch_state(path, info)
 var result := {"knowledge": 0, "plots": 3, "best": 0}
 result.merge(info.summary, true)
 return _summary(result, info)

static func character_summary(path: String) -> Dictionary:
 var info := Inspection.character(path)
 _apply_scratch_state(path, info)
 var result := {"name": "Empty character" if info.state == "empty" else "Unavailable character",
  "class_name": "", "level": 1, "identity": ""}
 result.merge(info.summary, true)
 if info.state == "healthy" and result.identity.is_empty():
  info.state = "invalid"
  info.reason = "profile_identity_missing"
 return _summary(result, info)

static func _apply_scratch_state(path: String, info: Dictionary) -> void:
 if info.state not in ["healthy", "empty"]:
  return
 var metadata := Inspection.Layout.deletion_metadata(path, Inspection.Layout.directories())
 if metadata.is_empty():
  return
 for scratch in [path.get_base_dir().path_join("session.cfg.tmp"), metadata + ".tmp"]:
  if FileAccess.file_exists(scratch) or DirAccess.dir_exists_absolute(scratch):
   info.state = "pending_recovery"
   info.reason = "metadata_publication_pending"
   info.digest = ""
   return

static func _summary(result: Dictionary, info: Dictionary) -> Dictionary:
 result.state = info.state
 result.digest = info.digest
 result.exists = info.state == "healthy"
 result.active = info.state == "busy"
 result.error = OK if info.state in ["healthy", "empty", "busy"] else ERR_INVALID_DATA
 return result

static func prepare(worlds: RefCounted, roster: RefCounted, import_legacy: bool) -> Dictionary:
 var world_result := outcome(worlds.prepare_guarded(import_legacy))
 if not completed(world_result):
  return world_result
 return outcome(roster.prepare_guarded(worlds))

## Claim first, then validate exact confirmed bytes and load under the root
## lock. Title Join supplies no Garden store or Garden digest.
func start(progress: RefCounted, local_profile: RefCounted, guest_profile: RefCounted,
 garden: RefCounted, garden_slot: int, garden_digest: String,
 roster: RefCounted, profile_slot: int, profile_digest: String, stagger_heartbeats := false) -> Dictionary:
 if _guarded or _stopping or is_blocked() or _garden != null or _roster != null or profile_digest.is_empty() or (garden != null and garden_digest.is_empty()):
  return Ops.management_result(ERR_INVALID_PARAMETER, "startup_confirmation_missing")
 var result := Ops.management_result(OK, "")
 _profile_path = local_profile.path
 if roster != null:
  if roster.paths(profile_slot).get("character") != _profile_path:
   return Ops.management_result(ERR_INVALID_PARAMETER, "profile_destination_changed")
  var claim: Dictionary = roster.claim_guarded(profile_slot)
  result = outcome(claim)
  if _claim_written(claim) and roster.owns_guarded_lease(profile_slot):
   _roster = roster
   _profile_slot = profile_slot
  if not completed(result) or _roster == null:
   return _startup_failed(result if not completed(result) else Ops.management_result(ERR_BUSY, "profile_lease_lost"))
 if garden != null:
  _garden_path = garden.paths(garden_slot).garden
  if _garden_path != progress.path or (roster == null and garden.paths(garden_slot).character != _profile_path):
   return _startup_failed(Ops.management_result(ERR_INVALID_PARAMETER, "garden_destination_changed"))
  var claim: Dictionary = garden.claim_guarded(garden_slot)
  result = outcome(claim)
  if _claim_written(claim) and garden.owns_guarded_lease(garden_slot):
   _garden = garden
   _garden_slot = garden_slot
  if not completed(result) or _garden == null:
   return _startup_failed(result if not completed(result) else Ops.management_result(ERR_BUSY, "garden_lease_lost"))
 var paths := PackedStringArray([_profile_path])
 if _garden != null:
  paths.append(_garden_path)
 result = outcome(Ops.run_management(paths, PackedStringArray(), func(_context):
  if not owns_leases():
   return Ops.management_result(ERR_BUSY, "startup_lease_lost")
  if Slots._save_digest(_profile_path) != profile_digest or (_garden != null and Slots._save_digest(_garden_path) != garden_digest):
   return Ops.management_result(ERR_UNAUTHORIZED, "stale_startup_confirmation")
  var profile := Inspection._inspect(_profile_path, "character", true)
  _apply_scratch_state(_profile_path, profile.result)
  if profile.result.state != "healthy":
   return Ops.management_result(ERR_INVALID_DATA, profile.result.reason, profile.result.state)
  if _garden != null:
   var inspected := Inspection._inspect(_garden_path, "garden", true)
   _apply_scratch_state(_garden_path, inspected.result)
   if inspected.result.state != "healthy":
    return Ops.management_result(ERR_INVALID_DATA, inspected.result.reason, inspected.result.state)
  local_profile.identity = ""
  var error: Error = local_profile.load_profile(false)
  if error == OK and not Profile.valid_identity(local_profile.identity):
   error = ERR_INVALID_DATA
  if error == OK and guest_profile.path == _profile_path:
   error = guest_profile.load_profile(false)
  if error == OK and _garden != null:
   error = progress.load_garden(false)
  return Ops.management_result(error, "" if error == OK else "startup_load_failed")))
 if not completed(result):
  return _startup_failed(result)
 _heartbeat_at = Time.get_unix_time_from_system()
 _stagger_heartbeats = stagger_heartbeats and _garden != null and _roster != null
 _profile_heartbeat_at = _heartbeat_at - RENEW_SECONDS * 0.5
 progress.require_guarded_access = true
 local_profile.require_guarded_access = true
 guest_profile.require_guarded_access = true
 _guarded = true
 return result

static func _claim_written(boundary: Dictionary) -> bool:
 return boundary.get("ran", false) and boundary.get("value") is Dictionary and completed(boundary.value)

func owns_leases() -> bool:
 return (_garden != null or _roster != null) and (_garden == null or _garden.owns_guarded_lease(_garden_slot)) \
  and (_roster == null or _roster.owns_guarded_lease(_profile_slot))

func authorizes(path: String) -> bool:
 return (path == _profile_path or (_garden != null and path == _garden_path)) and owns_leases()

func reload_guest(profile: RefCounted) -> Error:
 if profile.path != _profile_path:
  return ERR_UNAUTHORIZED
 var result := outcome(Ops.run_management(PackedStringArray([_profile_path]), PackedStringArray(), func(_context):
  if not owns_leases():
   return Ops.management_result(ERR_UNAUTHORIZED, "stale_session_lease")
  var inspected := Inspection._inspect(_profile_path, "character", true)
  _apply_scratch_state(_profile_path, inspected.result)
  if inspected.result.state != "healthy":
   return Ops.management_result(ERR_INVALID_DATA, inspected.result.reason, inspected.result.state)
  profile.identity = ""
  var error: Error = profile.load_profile(false)
  if error == OK and not Profile.valid_identity(profile.identity):
   error = ERR_INVALID_DATA
  return Ops.management_result(error, "profile_read")))
 return result.error

func tick() -> Dictionary:
 var now := Time.get_unix_time_from_system()
 var garden_due := now - _heartbeat_at >= RENEW_SECONDS
 var profile_due := now - _profile_heartbeat_at >= RENEW_SECONDS if _stagger_heartbeats else garden_due
 if _stagger_heartbeats and garden_due: profile_due = false
 if not garden_due and not profile_due:
  return Ops.management_result(OK, "")
 if not owns_leases():
  return Ops.management_result(ERR_UNAUTHORIZED, "stale_session_lease")
 if garden_due:
  _heartbeat_at = now
  if _garden != null:
   var result := outcome(_garden.heartbeat_guarded(_garden_slot))
   if not completed(result):
    if result.get("state") != "busy" or not owns_leases(): return result
    _heartbeat_at -= RENEW_SECONDS - BUSY_RETRY_SECONDS
 if profile_due:
  _profile_heartbeat_at = now
  if _roster != null:
   var result := outcome(_roster.heartbeat_guarded(_profile_slot))
   if not completed(result):
    if result.get("state") != "busy" or not owns_leases(): return result
    _profile_heartbeat_at -= RENEW_SECONDS - BUSY_RETRY_SECONDS
    if not _stagger_heartbeats: _heartbeat_at = minf(_heartbeat_at, _profile_heartbeat_at)
 return Ops.management_result(OK, "")

func release() -> Dictionary:
 var result := Ops.management_result(OK,"")
 if _roster != null:
  result=outcome(_roster.release_guarded(_profile_slot))
  _roster = null
 if _garden != null:
  var garden_result := outcome(_garden.release_guarded(_garden_slot))
  if completed(result): result=garden_result
  _garden = null
 return result

func _startup_failed(result: Dictionary) -> Dictionary:
 release()
 return result
