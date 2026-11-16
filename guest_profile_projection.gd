extends RefCounted

const Profile = preload("res://character_profile.gd")
const MAX_RECEIPTS := 64
const MAX_REVISION := 2147483647

static func digest(profile: Dictionary) -> String:
 return JSON.stringify(Profile.Experience.projection_input(profile)).sha256_text()

static func valid_origin(value: Variant) -> bool:
 return _hex(value, 32)

static func _hex(value: Variant, length: int) -> bool:
 return value is String and value.length() == length and value.to_lower() == value and value.is_valid_hex_number(false)

static func _revision(value: Variant, minimum: int) -> bool:
 return value is int and value >= minimum and value <= MAX_REVISION

static func valid_receipts(value: Variant) -> bool:
 if not value is Dictionary or value.size() > MAX_RECEIPTS: return false
 for origin in value:
  var receipt: Variant = value[origin]
  if not valid_origin(origin) or not receipt is Dictionary or receipt.size() != 2 \
   or not _revision(receipt.get("revision"), 1) or not _hex(receipt.get("digest"), 64):
   return false
 return true

static func valid_descriptor(value: Variant, profile: Dictionary) -> bool:
 return value is Dictionary and value.size() == 4 and _revision(value.get("revision"), 1) \
  and _revision(value.get("base_revision"), 0) and value.base_revision < value.revision \
  and _hex(value.get("base_digest"), 64) and value.get("digest") == digest(profile)

static func merge_progress(incoming: Dictionary, recovered: Dictionary) -> void:
 for field in ["plants", "monsters"]:
  for i in incoming[field].size(): incoming[field][i] = maxi(int(incoming[field][i]), int(recovered[field][i]))
 for c in incoming.xp.size():
  incoming.xp[c] = maxi(int(incoming.xp[c]), int(recovered.xp[c]))

static func build(profile: Dictionary, revision: int, base: Dictionary) -> Dictionary:
 if revision > MAX_REVISION: return {}
 return {"revision": revision, "digest": digest(profile), "base_revision": base.revision, "base_digest": base.digest}

## Either retransmit the committed pending profile or admit the guest's current
## local profile as the base for future projections. Never replay Garden actions.
static func admit(origin: String, incoming: Dictionary, receipts: Dictionary, record: Variant) -> Dictionary:
 if not valid_receipts(receipts) or (not receipts.has(origin) and receipts.size() == MAX_RECEIPTS): return {}
 var local_digest := digest(incoming)
 var receipt: Dictionary = receipts.get(origin, {"revision": 0, "digest": ""})
 var base := {"revision": receipt.revision, "digest": local_digest}
 var latest := 0
 if record is Dictionary and record.get("profile") is Dictionary:
  if not Profile.Experience.supported(record.profile): return {}
  var recovered := Profile.normalize(Profile.ContentIDs.profile(record.profile, record.get("manifest", Profile.ContentIDs.legacy())))
  if record.has("projection"):
   var descriptor: Variant = record.projection
   if not valid_descriptor(descriptor, recovered): return {}
   latest = descriptor.revision
   if receipt.revision > latest or (receipt.revision == latest and receipt.digest != descriptor.digest): return {}
   if receipt.revision < latest:
    var same_base: bool = receipt.revision == descriptor.base_revision and local_digest == descriptor.base_digest
    var applied_intermediate: bool = receipt.revision > descriptor.base_revision and local_digest == receipt.digest
    if not same_base and not applied_intermediate: return {}
    return {"profile": recovered, "projection": descriptor, "base": base}
   if local_digest == descriptor.digest:
    return {"profile": recovered, "projection": descriptor, "base": base}
  merge_progress(incoming, recovered)
 if latest == 0 and receipt.revision != 0: return {}
 var descriptor := build(incoming, latest + 1, base)
 return {} if descriptor.is_empty() else {"profile": incoming, "projection": descriptor, "base": base}
