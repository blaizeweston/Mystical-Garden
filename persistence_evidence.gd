extends RefCounted
## The primary SaveBatch record keeps its existing ConfigFile encoding.

const Layout = preload("res://persistence_save_layout.gd")
const EXPECTED := ".txn_expected"
const RECEIPT := ".txn_receipt"
const FALLBACK := ".txn_previous"
const SCRATCH := ".txn_publish"
const SUFFIXES = [EXPECTED, RECEIPT, FALLBACK, SCRATCH]
const MAX_BYTES := 8192
const MAX_PARTICIPANTS := 16
const MAX_FILE_BYTES := 8 * 1024 * 1024

static func make(attempt: String, anchor: String, paths: PackedStringArray, states: Dictionary, old: PackedByteArray, committed: PackedByteArray) -> Dictionary:
 var participants := []
 for path in paths:
  var entry: Dictionary = states[path]
  participants.append({
   "path": path, "exists": entry.exists, "length": entry.bytes.size(),
   "sha256": digest(entry.bytes),
  })
 return {"version": 1, "attempt": attempt, "anchor": anchor, "participants": participants,
  "uncommitted_sha256": digest(old), "committed_sha256": digest(committed)}

static func encode(record: Dictionary) -> PackedByteArray:
 return JSON.stringify(record).to_utf8_buffer()

## Canonical encoding rejects duplicate keys, unexpected fields and ambiguous numbers.
static func parse(bytes: PackedByteArray, anchor: String, attempt := "", paths := PackedStringArray()) -> Dictionary:
 if bytes.is_empty() or bytes.size() > MAX_BYTES:
  return {}
 var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
 if not value is Dictionary or value.size() != 6 or value.get("version") != 1:
  return {}
 if not _hex(value.get("attempt"), 32) or (not attempt.is_empty() and value.attempt != attempt):
  return {}
 var layout := Layout.directories()
 if value.get("anchor") != anchor or not Layout.is_canonical(anchor, layout):
  return {}
 if not _hex(value.get("uncommitted_sha256"), 64) or not _hex(value.get("committed_sha256"), 64):
  return {}
 if value.uncommitted_sha256 == value.committed_sha256:
  return {}
 var entries: Variant = value.get("participants")
 if not entries is Array or entries.is_empty() or entries.size() > MAX_PARTICIPANTS:
  return {}
 var actual := PackedStringArray()
 for entry in entries:
  if not entry is Dictionary or entry.size() != 4:
   return {}
  var path: Variant = entry.get("path")
  var size: Variant = entry.get("length")
  if not path is String or not Layout.is_participant(path, layout) or (not actual.is_empty() and actual[-1] >= path):
   return {}
  if not (size is int or size is float) or size < 0 or size > MAX_FILE_BYTES or size != int(size):
   return {}
  if not entry.get("exists") is bool or not _hex(entry.get("sha256"), 64):
   return {}
  if not entry.exists and (size != 0 or entry.sha256 != digest(PackedByteArray())):
   return {}
  entry.length = int(size)
  actual.append(path)
 value.version = 1
 if not actual.has(anchor) or not Layout.valid_journal_scope(anchor, actual, layout) or (not paths.is_empty() and paths != actual) or encode(value) != bytes:
  return {}
 return value

static func paths(record: Dictionary) -> PackedStringArray:
 var result := PackedStringArray()
 for entry in record.participants:
  result.append(entry.path)
 return result

static func matches(entry: Dictionary, exists: bool, bytes: PackedByteArray) -> bool:
 return entry.exists == exists and entry.length == bytes.size() and entry.sha256 == digest(bytes)

## A fixed whitespace trailer binds both primary images to the nonce.
## ConfigFile and the legacy journal grammar accept the unchanged entries.
static func journal_image(bytes: PackedByteArray, attempt: String) -> PackedByteArray:
 var trailer := "\n"
 for symbol in attempt:
  var digit := "0123456789abcdef".find(symbol)
  for bit in [8, 4, 2, 1]:
   trailer += "\t" if digit & bit else " "
 return bytes + (trailer + "\n").to_utf8_buffer()

static func binds_journal(bytes: PackedByteArray, proof: Dictionary, committed: bool) -> bool:
 var trailer := journal_image(PackedByteArray(), proof.attempt)
 return bytes.size() >= trailer.size() and bytes.slice(bytes.size() - trailer.size()) == trailer and digest(bytes) == (proof.committed_sha256 if committed else proof.uncommitted_sha256)

static func journal_attempt(bytes: PackedByteArray) -> String:
 if bytes.size() < 130 or bytes[-130] != 10 or bytes[-1] != 10:
  return ""
 var result := ""
 for index in 32:
  var digit := 0
  for bit in 4:
   var symbol := bytes[bytes.size() - 129 + index * 4 + bit]
   if symbol != 9 and symbol != 32:
    return ""
   digit = digit * 2 + int(symbol == 9)
  result += "0123456789abcdef"[digit]
 return result

static func digest(bytes: PackedByteArray) -> String:
 var hash := HashingContext.new()
 hash.start(HashingContext.HASH_SHA256)
 if not bytes.is_empty():
  hash.update(bytes)
 return hash.finish().hex_encode()

static func _hex(value: Variant, size: int) -> bool:
 if not value is String or value.length() != size:
  return false
 for symbol in value:
  if not symbol in "0123456789abcdef":
   return false
 return true
