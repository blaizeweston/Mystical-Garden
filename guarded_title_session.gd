extends RefCounted
## Owns only the leases acquired for one opt-in title launch. The original
## store instances must survive the handoff because they own the lease digests.

const Ops = preload("res://persistence_operations.gd")
const Slots = preload("res://save_slots.gd")
const Inspection = preload("res://persistence_save_inspection.gd")
const Profile = preload("res://character_profile.gd")
const META := &"guarded_title_session"

var _garden: RefCounted
var _roster: RefCounted
var _garden_slot := -1
var _profile_slot := -1
var _garden_path := ""
var _profile_path := ""
var _heartbeat_at := 0.0

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
func start(world: Node, garden: RefCounted, garden_slot: int, garden_digest: String,
 roster: RefCounted, profile_slot: int, profile_digest: String) -> Dictionary:
 if _garden != null or _roster != null or profile_digest.is_empty() or (garden != null and garden_digest.is_empty()):
  return Ops.management_result(ERR_INVALID_PARAMETER, "startup_confirmation_missing")
 var result := Ops.management_result(OK, "")
 _profile_path = world.local_character.path
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
  if _garden_path != world.progress.path or (roster == null and garden.paths(garden_slot).character != _profile_path):
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
  world.local_character.identity = ""
  var error: Error = world.local_character.load_profile(false)
  if error == OK and not Profile.valid_identity(world.local_character.identity):
   error = ERR_INVALID_DATA
  if error == OK and world.guest_character.path == _profile_path:
   error = world.guest_character.load_profile(false)
  if error == OK and _garden != null:
   error = world.progress.load_garden(false)
  return Ops.management_result(error, "" if error == OK else "startup_load_failed")))
 if not completed(result):
  return _startup_failed(result)
 _heartbeat_at = Time.get_unix_time_from_system()
 world.progress.require_guarded_access = true
 world.local_character.require_guarded_access = true
 world.guest_character.require_guarded_access = true
 world.set_meta(META, self)
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
 if now - _heartbeat_at < 1.0:
  return Ops.management_result(OK, "")
 _heartbeat_at = now
 if not owns_leases():
  return Ops.management_result(ERR_UNAUTHORIZED, "stale_session_lease")
 if _garden != null:
  var result := outcome(_garden.heartbeat_guarded(_garden_slot))
  if not completed(result) and (result.get("state") != "busy" or not owns_leases()):
   return result
 if _roster != null:
  var result := outcome(_roster.heartbeat_guarded(_profile_slot))
  if not completed(result) and (result.get("state") != "busy" or not owns_leases()):
   return result
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
