extends RefCounted
## Read-only SaveBatch discovery. A preview grants no recovery authority.

const Authorization = preload("res://persistence_authorization.gd")
const Layout = preload("res://persistence_save_layout.gd")
const Evidence = preload("res://persistence_evidence.gd")
const ARTIFACTS = [".transaction", ".txn_link", ".txn_stage", ".recovery"] + Evidence.SUFFIXES
const MAX_DIRECTORY_ENTRIES = 4096
const MAX_RECORD_BYTES = 8 * 1024 * 1024
const MAX_JOURNAL_BYTES = 32 * 1024 * 1024
const MAX_OBSERVED_BYTES = 64 * 1024 * 1024
const MAX_JOURNAL_ENTRIES = 16
# ConfigFile's existing format, restricted to the types written by SaveBatch.
const BYTE_ARRAY = 'PackedByteArray\\(\\s*(?:"[A-Za-z0-9+/=]*"|(?:[0-9]{1,3}(?:\\s*,\\s*[0-9]{1,3})*)?)\\s*\\)'
const BYTES_FIELD = '"bytes"\\s*:\\s*' + BYTE_ARRAY
const EXISTS_FIELD = '"exists"\\s*:\\s*(?:true|false)'
const ENTRY = '"user://[^"\\\\\\r\\n]+"\\s*:\\s*\\{\\s*(?:' + BYTES_FIELD + '\\s*,\\s*' + EXISTS_FIELD + '|' + EXISTS_FIELD + '\\s*,\\s*' + BYTES_FIELD + ')\\s*\\}'
const ENTRIES = 'entries\\s*=\\s*\\{\\s*' + ENTRY + '(?:\\s*,\\s*' + ENTRY + '){0,15}\\s*\\}'
const COMMITTED = 'committed\\s*=\\s*(?:true|false)'
const JOURNAL = '\\A\\s*\\[transaction\\]\\s+(?:' + ENTRIES + '\\s+' + COMMITTED + '|' + COMMITTED + '\\s+' + ENTRIES + ')\\s*\\z'

## Returns a candidate plan plus the exact paths to supply to Authorization.run().
## Pending recovery is authorizable only when the complete journal set was validated.
static func discover(paths: PackedStringArray, require_resolved_links := false) -> Dictionary:
 var requested := _sorted(paths)
 var plan := {
  "state": "invalid", "reason": "", "path": "", "requested": requested,
  "participants": requested, "journal_anchors": PackedStringArray(),
  "journals": [], "authorization_paths": PackedStringArray(), "observed": {}, "active_leases": {},
  "locked": false, "recovery_ready": false
 }
 var directories := Layout.directories()
 if requested.is_empty():
  return _refuse(plan, "invalid", "no_participants")
 for path in requested:
  if not Layout.is_participant(path, directories):
   return _refuse(plan, "invalid", "unsafe_participant", path)

 var root := OS.get_user_data_dir().replace("\\", "/").trim_suffix("/")
 if not Authorization._is_drive_absolute(root) or not Authorization._ordinary_components(root.substr(3)):
  return _refuse(plan, "invalid", "unsupported_user_root", root)
 var disk := DirAccess.open(root)
 if disk == null or not Authorization._plain_ancestry(disk, root):
  return _refuse(plan, "invalid", "unsupported_user_root", root)

 var index := {}
 var directory_counts := {}
 var directory_error := _index_directory("user://", root, directories, index, directory_counts)
 plan.directory_counts = directory_counts
 if not directory_error.is_empty():
  return _refuse(plan, "pending_recovery", directory_error.reason, directory_error.path)

 var candidates := PackedStringArray()
 var link_paths := PackedStringArray()
 for path: String in index:
  if path.ends_with(".transaction"):
   candidates.append(path)
  elif path.ends_with(".txn_link"):
   link_paths.append(path)
 candidates.sort()
 link_paths.sort()
 var links := {}
 for path in link_paths:
  var link := _read(path, index, 260 * 4)
  if not link.ok:
   return _refuse(plan, "pending_recovery", link.reason, path)
  var target: String = link.bytes.get_string_from_utf8()
  if target.ends_with(".transaction") and Layout.is_canonical(target.trim_suffix(".transaction"), directories):
   links[path.trim_suffix(".txn_link")] = target.trim_suffix(".transaction")
  elif require_resolved_links:
   return _refuse(plan, "ambiguous", "unresolved_link_identity", path)
 var records := {}
 var total_bytes := 0
 var unreadable := {}
 var artifacts := {}
 var journal_pattern := RegEx.create_from_string(JOURNAL) if not candidates.is_empty() else null
 for journal in candidates:
  var anchor := journal.trim_suffix(".transaction")
  var file := _read(journal, index)
  if not file.ok:
   unreadable[journal] = _bad_record("pending_recovery", file.reason)
   continue
  total_bytes += file.bytes.size()
  if total_bytes > MAX_JOURNAL_BYTES:
   return _refuse(plan, "pending_recovery", "journal_scan_limit", journal)
  var record := _journal(file.bytes, directories, journal_pattern)
  if record.ok and not Layout.valid_journal_scope(anchor, PackedStringArray(record.entries.keys()), directories):
   record = _bad_record("invalid", "unowned_deletion_metadata")
  if not record.ok:
   unreadable[journal] = record
   continue
  record.anchor = anchor
  record.path = journal
  record.sha256 = _digest(file.bytes)
  record.attempt = Evidence.journal_attempt(file.bytes)
  records[journal] = record

 for path in _sorted(PackedStringArray(index.keys())):
  var suffix := _evidence_suffix(path)
  if suffix.is_empty():
   continue
  var anchor := path.trim_suffix(suffix)
  var group: Dictionary = artifacts.get(anchor, {})
  var item := _read(path, index, Evidence.MAX_BYTES if suffix in [Evidence.EXPECTED, Evidence.RECEIPT] else MAX_RECORD_BYTES)
  if not item.ok:
   return _refuse(plan, "pending_recovery", item.reason, path)
  total_bytes += item.bytes.size()
  if total_bytes > MAX_JOURNAL_BYTES:
   return _refuse(plan, "pending_recovery", "journal_scan_limit", path)
  group[suffix] = item.bytes
  artifacts[anchor] = group
 plan.journal_scan_bytes = total_bytes
 # These records supply reverse membership even after links or the primary disappear.
 for anchor: String in artifacts:
  var group: Dictionary = artifacts[anchor]
  var journal := anchor + ".transaction"
  var primary: Dictionary = records.get(journal, {})
  var proof_bytes: PackedByteArray = group.get(Evidence.EXPECTED, group.get(Evidence.RECEIPT, PackedByteArray()))
  var proof := Evidence.parse(proof_bytes, anchor)
  var fallback := {}
  if group.has(Evidence.FALLBACK):
   fallback = _journal(group[Evidence.FALLBACK], directories, RegEx.create_from_string(JOURNAL))
   if not fallback.ok or fallback.committed:
    return _refuse(plan, "pending_recovery", "invalid_journal_fallback", anchor)
  if proof.is_empty() and (group.has(Evidence.EXPECTED) or group.has(Evidence.RECEIPT)):
   return _refuse(plan, "pending_recovery", "invalid_expected_state", anchor)
  if primary.is_empty() and proof.is_empty() and fallback.is_empty():
   return _refuse(plan, "pending_recovery", "unbound_publication_scratch", anchor)
  var membership := PackedStringArray(primary.get("entries", {}).keys())
  if membership.is_empty():
   membership = Evidence.paths(proof) if not proof.is_empty() else PackedStringArray(fallback.entries.keys())
  membership.sort()
  if not proof.is_empty() and membership != Evidence.paths(proof):
   return _refuse(plan, "ambiguous", "evidence_participants_changed", anchor)
  if not fallback.is_empty():
   if proof.is_empty() or membership != PackedStringArray(fallback.entries.keys()) or not Evidence.binds_journal(group[Evidence.FALLBACK], proof, false):
    return _refuse(plan, "ambiguous", "fallback_binding_mismatch", anchor)
  if not proof.is_empty() and not primary.is_empty():
   var journal_file := _read(journal, index)
   if not journal_file.ok or not Evidence.binds_journal(journal_file.bytes, proof, primary.committed):
    return _refuse(plan, "ambiguous", "journal_evidence_mismatch", anchor)
  if group.has(Evidence.RECEIPT) and (group.has(Evidence.EXPECTED) or (primary.is_empty() and group.has(Evidence.FALLBACK)) or (not primary.is_empty() and not primary.committed)):
   return _refuse(plan, "ambiguous", "conflicting_commit_receipt", anchor)
  if not primary.is_empty() and primary.get("attempt", "").is_empty():
   return _refuse(plan, "ambiguous", "legacy_journal_with_durable_artifacts", anchor)
  var evidence_only: bool = primary.is_empty()
  if evidence_only:
   var entries := {}
   for participant in membership:
    entries[participant] = {}
   primary = {"anchor": anchor, "path": journal, "entries": entries, "evidence_only": true}
   records[journal] = primary
   if not candidates.has(journal):
    candidates.append(journal)
  primary.evidence = proof
  primary.receipt = group.has(Evidence.RECEIPT)
 candidates.sort()
 if require_resolved_links:
  for owner: String in links:
   var journal: String = links[owner] + ".transaction"
   if unreadable.has(journal):
    continue # The existing unreadable-record check preserves its specific error.
   if not records.has(journal) or not records[journal].entries.has(owner):
    return _refuse(plan, "ambiguous", "unresolved_link_identity", owner + ".txn_link")

 var participants := {}
 for path in requested:
  participants[path] = true
 var selected := {}
 # Each pass adds a journal or terminates. This also follows a journal's anchor.
 var changed := true
 while changed:
  changed = false
  for owner: String in links:
   var anchor: String = links[owner]
   if participants.has(owner) == participants.has(anchor):
    continue
   participants[owner] = true
   participants[anchor] = true
   changed = true
  for journal in candidates:
   if not records.has(journal) or selected.has(journal):
    continue
   var record: Dictionary = records[journal]
   if not _touches(record, participants):
    continue
   selected[journal] = record
   participants[record.anchor] = true
   for path: String in record.entries:
    participants[path] = true
   changed = true

 plan.participants = _sorted(PackedStringArray(participants.keys()))
 var anchors := PackedStringArray()
 var owners := {}
 var overlap := ""
 for journal in _sorted(PackedStringArray(selected.keys())):
  var record: Dictionary = selected[journal]
  anchors.append(record.anchor)
  plan.journals.append(record)
  for path in record.entries:
   if owners.has(path) and overlap.is_empty():
    overlap = path
   owners[path] = journal
  if not record.entries.has(record.anchor):
   if owners.has(record.anchor) and overlap.is_empty():
    overlap = record.anchor
   owners[record.anchor] = journal
 plan.journal_anchors = anchors
 if not unreadable.is_empty():
  var blocked_journal: String = _sorted(PackedStringArray(unreadable.keys()))[0]
  var problem: Dictionary = unreadable[blocked_journal]
  plan.journal_anchors = _sorted(anchors + PackedStringArray([blocked_journal.trim_suffix(".transaction")]))
  return _refuse(plan, problem.state, problem.reason, blocked_journal)
 if not overlap.is_empty():
  return _refuse(plan, "ambiguous", "overlapping_journals", overlap)
 return _check_artifacts(plan, index, owners)

## Call inside the root-lock callback. The result is scoped to that callback.
static func revalidate(previous: Dictionary, paths: PackedStringArray, token: RefCounted) -> Dictionary:
 var requested := _sorted(paths)
 if requested != previous.get("requested"):
  return _refuse(previous.duplicate(true), "invalid", "requested_paths_changed")
 if not previous.get("state") in ["healthy", "empty", "pending_recovery"] or previous.get("authorization_paths", []).is_empty():
  return _refuse(previous.duplicate(true), "invalid", "preview_not_authorizable")
 var result := Authorization.run_nested(token, previous.authorization_paths, func(_token):
  return discover(requested))
 if not result.ran:
  return _refuse(previous.duplicate(true), "invalid", "authorization_rejected")
 var current: Dictionary = result.value
 if current.authorization_paths.is_empty():
  return current
 if current.participants != previous.participants:
  return _refuse(current, "invalid", "participant_set_changed", current.path)
 if current.authorization_paths != previous.authorization_paths:
  return _refuse(current, "invalid", "authorization_paths_changed", current.path)
 if current.state != previous.state or current.observed != previous.observed or current.journal_anchors != previous.journal_anchors:
  return _refuse(current, "invalid", "observations_changed", current.path)
 current.locked = true
 current.recovery_ready = current.state == "pending_recovery" and current.reason == "journal_found"
 return current

static func _index_directory(path: String, root: String, supported: Dictionary, index: Dictionary, counts: Dictionary) -> Dictionary:
 var disk := DirAccess.open(path)
 if disk == null:
  return {"reason": "directory_unreadable", "path": path}
 disk.include_hidden = true
 if disk.list_dir_begin() != OK:
  return {"reason": "directory_unreadable", "path": path}
 var names := {}
 var name := disk.get_next()
 while not name.is_empty():
  if names.size() >= MAX_DIRECTORY_ENTRIES:
   disk.list_dir_end()
   return {"reason": "directory_scan_limit", "path": path}
  names[name] = disk.current_is_dir()
  name = disk.get_next()
 disk.list_dir_end()
 counts[path] = names.size()

 var children := PackedStringArray(names.keys())
 children.sort()
 for child in children:
  var target := path.path_join(child)
  var absolute := root.path_join(target.trim_prefix("user://"))
  var folded := target.to_lower()
  if supported.has(folded):
   if folded != target or not names[child] or disk.is_link(absolute) or disk.is_case_sensitive(absolute):
    return {"reason": "unsafe_directory", "path": target}
   var error := _index_directory(target, root, supported, index, counts)
   if not error.is_empty():
    return error
   continue
  var owner := folded
  for suffix in ARTIFACTS:
   if owner.ends_with(suffix):
    owner = owner.trim_suffix(suffix)
    break
  var lease: bool = child.to_lower() == "session.cfg" and not supported[path].is_empty()
  if not Layout.is_participant(owner, supported) and not lease:
   if child.to_lower().ends_with(".transaction") or child.to_lower().ends_with(".txn_link") or not _evidence_suffix(child.to_lower()).is_empty():
    return {"reason": "unknown_artifact_owner", "path": target}
   continue
  if target != folded or names[child] or disk.is_link(absolute) or absolute.length() >= 260:
   index[folded] = false
  else:
   index[folded] = true
 return {}

static func _journal(bytes: PackedByteArray, directories: Dictionary, pattern: RegEx) -> Dictionary:
 # ConfigFile can deserialize objects/resources. Screen journal syntax first.
 var content := bytes.get_string_from_utf8()
 if content.to_utf8_buffer() != bytes:
  return _bad_record("pending_recovery", "journal_encoding")
 if pattern.search(content) == null:
  return _bad_record("pending_recovery", "journal_syntax")
 var config := ConfigFile.new()
 if config.parse(content) != OK:
  return _bad_record("pending_recovery", "journal_parse")
 var entries: Variant = config.get_value("transaction", "entries", {})
 var committed: Variant = config.get_value("transaction", "committed", null)
 if not entries is Dictionary or entries.is_empty() or entries.size() > MAX_JOURNAL_ENTRIES or not committed is bool:
  return _bad_record("pending_recovery", "journal_structure")
 # ConfigFile dictionaries collapse duplicate keys. Verify each file key occurs once.
 var keys := RegEx.create_from_string('"([^"\\\\]*+)"\\s*:\\s*\\{').search_all(content)
 if keys.size() != entries.size():
  return _bad_record("ambiguous", "duplicate_or_unresolved_entry")
 var paths := PackedStringArray()
 for key in entries:
  if not key is String or not Layout.is_participant(key, directories):
   return _bad_record("invalid", "unsafe_journal_participant")
  paths.append(key)
 paths.sort()
 var ordered := {}
 for path in paths:
  var entry: Variant = entries[path]
  if not entry is Dictionary or not entry.get("exists") is bool or not entry.get("bytes") is PackedByteArray:
   return _bad_record("pending_recovery", "entry_structure")
  if not entry.exists and not entry.bytes.is_empty():
   return _bad_record("pending_recovery", "absent_entry_has_bytes")
  ordered[path] = entry
 return {"ok": true, "committed": committed, "entries": ordered}

static func _check_artifacts(plan: Dictionary, index: Dictionary, owners: Dictionary) -> Dictionary:
 var authorization := {}
 var any_present := false
 var total_bytes := 0
 for path: String in plan.participants:
  var marker := path.get_base_dir().path_join("session.cfg")
  if index.has(marker) and not plan.observed.has(marker):
   var lease_result := _lease(marker, index)
   if not lease_result.ok:
    return _refuse(plan, "pending_recovery", lease_result.reason, marker)
   plan.active_leases[marker] = lease_result.active
   if lease_result.busy:
    return _refuse(plan, "busy", "foreign_session_lease", marker)
   plan.observed[marker] = lease_result.sha256
   authorization[marker] = true
  var record: Dictionary = {}
  if owners.has(path):
   for journal in plan.journals:
    if journal.path == owners[path]:
     record = journal
     break
  for suffix: String in [""] + ARTIFACTS:
   var target := path + suffix
   authorization[target] = true
   if not index.has(target):
    plan.observed[target] = "absent"
    continue
   var file := _read(target, index)
   if not file.ok:
    return _refuse(plan, "pending_recovery", file.reason, target)
   total_bytes += file.bytes.size()
   if total_bytes > MAX_OBSERVED_BYTES:
    return _refuse(plan, "pending_recovery", "observation_limit", target)
   plan.observed[target] = _digest(file.bytes)
   if suffix.is_empty():
    any_present = true
   elif suffix in Evidence.SUFFIXES:
    if record.is_empty() or record.anchor != path:
     return _refuse(plan, "pending_recovery", "unowned_evidence", target)
   elif suffix == ".txn_link":
    var link: String = file.bytes.get_string_from_utf8()
    if not index.has(link) and (record.is_empty() or not record.get("evidence_only", false) or link != record.path):
     return _refuse(plan, "pending_recovery", "dangling_or_unsafe_link", target)
    if not owners.has(path) or owners[path] != link or not plan.journals.any(func(record): return record.path == link and record.entries.has(path)):
     return _refuse(plan, "ambiguous", "link_owner_mismatch", target)
   elif suffix in [".txn_stage", ".recovery"]:
    if suffix == ".txn_stage" and (record.get("committed", false) or record.get("receipt", false)) and not record.get("evidence", {}).is_empty():
     for entry in record.evidence.participants:
      if entry.path == path and not Evidence.matches(entry, true, file.bytes):
       return _refuse(plan, "pending_recovery", "staged_state_mismatch", target)
    if not owners.has(path) or not plan.journals.any(func(record): return record.path == owners[path] and record.entries.has(path)):
     return _refuse(plan, "pending_recovery", "unowned_artifact", target)
   elif suffix == ".transaction":
    if not plan.journals.any(func(record): return record.path == target and record.sha256 == plan.observed[target]):
     return _refuse(plan, "pending_recovery", "journal_changed_during_scan", target)
 for record in plan.journals:
  var proof: Dictionary = record.get("evidence", {})
  var committed: bool = record.get("committed", false) or record.get("receipt", false)
  if committed and not proof.is_empty():
   for entry in proof.participants:
    var seen: String = plan.observed.get(entry.path, "absent")
    if (seen != "absent") != entry.exists:
     return _refuse(plan, "pending_recovery", "committed_state_mismatch", entry.path)
    if entry.exists:
     var file := _read(entry.path, index)
     if not file.ok or not Evidence.matches(entry, true, file.bytes):
      return _refuse(plan, "pending_recovery", "committed_state_mismatch", entry.path)
 plan.authorization_paths = _sorted(PackedStringArray(authorization.keys()))
 if not plan.journals.is_empty():
  plan.state = "pending_recovery"
  plan.reason = "journal_found"
  if plan.journals.any(func(record): return record.has("evidence")):
   plan.reason = "durable_evidence_pending"
 elif any_present:
  plan.state = "healthy"
 else:
  plan.state = "empty"
 return plan

static func _evidence_suffix(path: String) -> String:
 for suffix: String in Evidence.SUFFIXES:
  if path.ends_with(suffix):
   return suffix
 return ""

## Conservative upper bound for every intermediate state, before the first file write.
static func check_footprint(plan: Dictionary, paths: PackedStringArray, anchor: String, original_bytes: int, stage_bytes: int, journal_bytes: int, proof_bytes: int) -> bool:
 if journal_bytes > MAX_RECORD_BYTES or proof_bytes > Evidence.MAX_BYTES:
  return false
 var metadata_bytes := 3 * journal_bytes + proof_bytes
 if int(plan.get("journal_scan_bytes", MAX_JOURNAL_BYTES)) + metadata_bytes > MAX_JOURNAL_BYTES:
  return false
 var observed_limit := original_bytes + stage_bytes + MAX_RECORD_BYTES + metadata_bytes + paths.size() * 1040 + paths.size() * 4096
 if observed_limit > MAX_OBSERVED_BYTES:
  return false
 var additions := {}
 for path in paths:
  var parent := path.get_base_dir()
  # Canonical file, link, stage and restore scratch (even if already present).
  additions[parent] = int(additions.get(parent, 0)) + 4
 var journal_parent := anchor.get_base_dir()
 additions[journal_parent] = int(additions.get(journal_parent, 0)) + 1 + Evidence.SUFFIXES.size()
 for parent in additions:
  if int(plan.directory_counts.get(parent, MAX_DIRECTORY_ENTRIES)) + int(additions[parent]) >= MAX_DIRECTORY_ENTRIES:
   return false
 return true

## Account for the largest one-file restore scratch and any newly present original.
static func restore_footprint(scope: PackedStringArray, observed: Dictionary, originals: Dictionary) -> Error:
 var totals := 0
 var largest_scratch := 0
 var growth := 0
 var additions := {}
 for target in scope:
  if observed.get(target, "absent") == "absent":
   continue
  var file := FileAccess.open(target, FileAccess.READ)
  if file == null:
   return FileAccess.get_open_error()
  totals += file.get_length()
 for path: String in originals:
  if not originals[path].exists:
   continue
  var current := FileAccess.open(path, FileAccess.READ) if observed[path] != "absent" else null
  if observed[path] != "absent" and current == null:
   return FileAccess.get_open_error()
  var current_bytes := current.get_length() if current != null else 0
  growth += maxi(0, originals[path].bytes.size() - current_bytes)
  largest_scratch = maxi(largest_scratch, originals[path].bytes.size())
  var parent := path.get_base_dir()
  additions[parent] = int(additions.get(parent, 0)) + int(observed[path] == "absent") + int(observed[path + ".recovery"] == "absent")
 for parent in additions:
  var disk := DirAccess.open(parent)
  if disk == null:
   return DirAccess.get_open_error()
  disk.include_hidden = true
  if disk.get_files().size() + disk.get_directories().size() + int(additions[parent]) >= MAX_DIRECTORY_ENTRIES:
   return ERR_INVALID_DATA
 return OK if totals + growth + largest_scratch <= MAX_OBSERVED_BYTES else ERR_INVALID_DATA

static func _lease(path: String, index: Dictionary) -> Dictionary:
 var file := _read(path, index, 4096)
 if not file.ok:
  return file
 var text: String = file.bytes.get_string_from_utf8()
 var pattern := RegEx.create_from_string("\\A\\s*\\[session\\]\\s+process_id\\s*=\\s*([0-9]{1,10})\\s+updated\\s*=\\s*([0-9]+(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)\\s*\\z")
 var match_result := pattern.search(text)
 if match_result == null:
  return {"ok": false, "reason": "invalid_session_lease"}
 var owner := match_result.get_string(1).to_int()
 var updated := match_result.get_string(2).to_float()
 var active := Time.get_unix_time_from_system() - updated < 30.0
 return {"ok": true, "active": active, "busy": active and owner != OS.get_process_id(), "sha256": _digest(file.bytes)}

static func _read(path: String, index: Dictionary, maximum := MAX_RECORD_BYTES) -> Dictionary:
 if not index.get(path, false):
  return {"ok": false, "reason": "unsafe_file"}
 return _read_bytes(path, maximum)

static func _read_bytes(path: String, maximum := MAX_RECORD_BYTES) -> Dictionary:
 var file := FileAccess.open(path, FileAccess.READ)
 if file == null:
  return {"ok": false, "reason": "file_unreadable"}
 var length := file.get_length()
 if length < 0 or length > maximum:
  return {"ok": false, "reason": "file_size_limit"}
 var bytes := file.get_buffer(length)
 if bytes.size() != length or file.get_error() != OK or file.get_length() != length:
  return {"ok": false, "reason": "file_read_incomplete"}
 return {"ok": true, "bytes": bytes}

static func _touches(record: Dictionary, participants: Dictionary) -> bool:
 if participants.has(record.anchor):
  return true
 for path in record.entries:
  if participants.has(path):
   return true
 return false

static func _sorted(paths: PackedStringArray) -> PackedStringArray:
 var unique := {}
 for path in paths:
  unique[path] = true
 var sorted := PackedStringArray(unique.keys())
 sorted.sort()
 return sorted

static func _digest(bytes: PackedByteArray) -> String:
 var hash := HashingContext.new()
 hash.start(HashingContext.HASH_SHA256)
 if not bytes.is_empty():
  hash.update(bytes)
 return hash.finish().hex_encode()

static func _bad_record(state: String, reason: String) -> Dictionary:
 return {"ok": false, "state": state, "reason": reason}

static func _refuse(plan: Dictionary, state: String, reason: String, path := "") -> Dictionary:
 plan.state = state
 plan.reason = reason
 plan.path = path
 plan.locked = false
 plan.recovery_ready = false
 plan.authorization_paths = PackedStringArray()
 return plan
