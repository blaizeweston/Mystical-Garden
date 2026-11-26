extends RefCounted
## A character owns ONE spendable reserve. Existing InventoryModel consumers
## mutate the Garden reserve only while the matching durable custody is active.
## The profile's locked outbound payload is a retry envelope, never a stash.
const Seeds=preload("res://seed_catalog.gd")
const Parts=preload("res://weapon_parts.gd")
const Items=preload("res://item_catalog.gd")
const Ancient=preload("res://ancient_seed.gd")
const VERSION:=1
const MAX_SEQUENCE:=2147483647

static func blank_payload() -> Dictionary:
 return {"seeds":{},"parts":{},"unknown":[],"extras":{},"history":["",0]}

static func hex_id(value: Variant, length: int) -> bool:
 return value is String and value.length()==length and value==value.to_lower() and value.is_valid_hex_number(false)

static func sequence(value: Variant, minimum: int=1) -> bool:
 return value is int and value>=minimum and value<=MAX_SEQUENCE

static func counts_valid(value: Variant, ids: Array) -> bool:
 if not value is Dictionary:return false
 for key in value:
  if not key is String or not ids.has(key) or not value[key] is int or value[key]<=0:return false
 return true

static func valid_payload(value: Variant) -> bool:
 if not value is Dictionary or value.size()!=5:return false
 var seed_ids: Array=Seeds.DEFINITIONS.map(func(definition):return str(definition.id))
 var part_ids: Array=Parts.DEFINITIONS.slice(1).map(func(definition):return str(definition.id))
 if not counts_valid(value.get("seeds"),seed_ids) or not counts_valid(value.get("parts"),part_ids):return false
 var unknown: Variant=value.get("unknown")
 if not unknown is Array or not unknown.all(func(id):return id is String and seed_ids.has(id)):return false
 var history: Variant=value.get("history")
 if not history is Array or history.size()!=2 or not history[0] is String or (history[0]!="" and not seed_ids.has(history[0])) or not history[1] is int or history[1]<0 or history[1]>2:return false
 var extras: Variant=value.get("extras")
 if not extras is Dictionary or extras!=Items.clean_counts(extras):return false
 for id in extras:
  var item:=Items.get_item(id)
  if id=="unidentified_seed" or item.has("legacy_seed") or item.has("legacy_part"):return false
 return true

static func digest(payload: Dictionary) -> String:
 return JSON.stringify(payload).sha256_text()

static func valid_profile(value: Variant) -> bool:
 if not value is Dictionary:return false
 if value.is_empty():return true # verified legacy profile, not yet converted
 if value.get("version")!=VERSION or not sequence(value.get("sequence"),0) or not valid_payload(value.get("payload")):return false
 if value.get("state")=="home":return value.size()==4
 return value.get("state")=="away" and value.size()==8 and sequence(value.sequence) and hex_id(value.get("origin"),32) and hex_id(value.get("token"),64) and value.get("checkout")==digest(value.payload) and value.get("endpoint") is String and value.endpoint.length()<=256

static func home(value: Dictionary) -> Dictionary:
 return {"version":VERSION,"state":"home","sequence":0,"payload":blank_payload()} if value.is_empty() else value.duplicate(true)

static func locked(value: Dictionary) -> bool:
 return value.get("state")=="away"

static func checkout(value: Dictionary,origin: String,endpoint: String) -> Dictionary:
 var prior:=home(value)
 if not valid_profile(prior) or prior.state!="home" or prior.sequence>=MAX_SEQUENCE or not hex_id(origin,32) or endpoint.length()>256:return {}
 return {"version":VERSION,"state":"away","sequence":prior.sequence+1,"origin":origin,"endpoint":endpoint,"token":Crypto.new().generate_random_bytes(32).hex_encode(),"payload":prior.payload,"checkout":digest(prior.payload)}

static func matches(record: Dictionary,lock: Dictionary) -> bool:
 return record.get("sequence")==lock.get("sequence") and record.get("token")==lock.get("token") and record.get("checkout")==lock.get("checkout")

static func valid_records(value: Variant) -> bool:
 if not value is Dictionary:return false
 for identity in value:
  var record: Variant=value[identity]
  if not hex_id(identity,32) or not record is Dictionary or not sequence(record.get("sequence")) or not hex_id(record.get("token"),64) or not hex_id(record.get("checkout"),64):return false
  if record.get("state") in ["active","closed"]:
   if record.size()!=4:return false
  elif record.get("state")=="returned":
   if record.size()!=6 or not valid_payload(record.get("payload")) or record.get("returned")!=digest(record.payload):return false
  else:return false
 return true

static func capture(garden,owner: String) -> Dictionary:
 var result:=blank_payload()
 var reserve: Dictionary=garden.reserve(owner)
 for species in reserve.stock.size():
  if reserve.stock[species]>0:result.seeds[str(Seeds.DEFINITIONS[species].id)]=reserve.stock[species]
 for part in range(1,reserve.parts.size()):
  if reserve.parts[part]>0:result.parts[str(Parts.DEFINITIONS[part].id)]=reserve.parts[part]
 for species: int in reserve.unknown:result.unknown.append(str(Seeds.DEFINITIONS[species].id))
 result.history=[str(Seeds.DEFINITIONS[reserve.history[0]].id) if reserve.history[0]>=0 else "",reserve.history[1]]
 result.extras=garden.item_stashes.get(owner,{}).duplicate(true)
 return result

static func clear_reserve(garden,owner: String) -> void:
 if owner.is_empty():
  garden.stock.fill(0);garden.unknown.clear();garden.personal_parts.fill(0);garden.seed_history.assign([-1,0])
 else:garden.guest_seeds.erase(owner)
 garden.item_stashes.erase(owner)

static func install(garden,owner: String,payload: Dictionary) -> void:
 clear_reserve(garden,owner)
 var reserve: Dictionary=garden.reserve(owner)
 for id in payload.seeds:reserve.stock[Seeds.index_of(id)]=payload.seeds[id]
 for id in payload.parts:reserve.parts[Parts.index_of(id)]=payload.parts[id]
 for id in payload.unknown:reserve.unknown.append(Seeds.index_of(id))
 reserve.history.assign([Seeds.index_of(payload.history[0]) if payload.history[0]!="" else -1,payload.history[1]])
 if not payload.extras.is_empty():garden.item_stashes[owner]=payload.extras.duplicate(true)

static func merge(destination: Dictionary,source: Dictionary) -> Dictionary:
 var result:=destination.duplicate(true)
 for field in ["seeds","parts","extras"]:
  for id in source[field]:
   if field=="extras" and id==Ancient.ITEM:
    if not result.extras.has(id):result.extras[id]={}
    Ancient.add(result.extras[id],source.extras[id])
   else:result[field][id]=int(result[field].get(id,0))+int(source[field][id])
 result.unknown.append_array(source.unknown)
 if result.history[0]=="":result.history=source.history.duplicate()
 return result

static func needs_host_assignment(garden) -> bool:
 return garden.legacy_personal_owner.is_empty() and capture(garden,"")!=blank_payload()

## No second spendable reserve is installed when revisiting a matching active lock.
## A returned record is terminal until a strictly newer checkout arrives.
static func admit(garden,identity: String,lock: Dictionary,assign_host: bool=false) -> String:
 if not hex_id(identity,32) or not valid_profile(lock) or not locked(lock) or lock.origin!=garden.archive.origin:return "invalid"
 var prior: Dictionary=garden.personal_custody.get(identity,{})
 if matches(prior,lock):return str(prior.state)
 if not prior.is_empty() and (prior.state=="active" or int(prior.sequence)>=int(lock.sequence)):return "conflict"
 var payload: Dictionary=lock.payload.duplicate(true)
 # A keyed legacy reserve predates custody. A modern returned record must
 # have no remaining spendable reserve; fail closed on contradictory data.
 var legacy:=capture(garden,identity)
 if not prior.is_empty() and legacy!=blank_payload():return "conflict"
 if prior.is_empty():payload=merge(payload,legacy)
 if assign_host:
  if not needs_host_assignment(garden):return "conflict"
  payload=merge(payload,capture(garden,""))
 if not valid_payload(payload):return "invalid"
 if assign_host:
  clear_reserve(garden,"")
  garden.legacy_personal_owner=identity
 install(garden,identity,payload)
 garden.personal_custody[identity]={"state":"active","sequence":lock.sequence,"token":lock.token,"checkout":lock.checkout}
 return "active"

## Call only within the Garden's guarded settlement, after freezing all
## personal actions and resolving expedition participation.
static func release(garden,identity: String) -> Dictionary:
 var record: Dictionary=garden.personal_custody.get(identity,{})
 if record.get("state")=="returned":return record.duplicate(true)
 if record.get("state")!="active":return {}
 var payload:=capture(garden,identity)
 if not valid_payload(payload):return {}
 var returned:=record.duplicate(true)
 returned.state="returned";returned.payload=payload;returned.returned=digest(payload)
 clear_reserve(garden,identity)
 garden.personal_custody[identity]=returned
 return returned.duplicate(true)

static func accept_return(lock: Dictionary,origin: String,record: Dictionary) -> Dictionary:
 if not valid_profile(lock) or not locked(lock) or lock.origin!=origin or not valid_records({"a".repeat(32):record}) or record.state!="returned" or not matches(record,lock):return {}
 return {"version":VERSION,"state":"home","sequence":lock.sequence,"payload":record.payload.duplicate(true)}

## A confirmed profile acceptance permits compacting the retry envelope.
## The sequence/token tombstone remains to reject stale checkout retries.
static func close_return(garden,identity: String,record: Dictionary) -> bool:
 var prior: Dictionary=garden.personal_custody.get(identity,{})
 if prior.get("state")!="returned" or not matches(prior,record) or prior.get("returned")!=record.get("returned"):return false
 garden.personal_custody[identity]={"state":"closed","sequence":prior.sequence,"token":prior.token,"checkout":prior.checkout}
 return true

static func active(garden,identity: String) -> bool:
 return garden.personal_custody.get(identity,{}).get("state")=="active"

static func unresolved(garden) -> bool:
 return garden.personal_custody.values().any(func(record):return record.get("state") in ["active","returned"])

## Management operations call this while holding their existing save scope.
## Never delete/replace the only copy of another character's active inventory.
static func file_held(path: String) -> bool:
 if not FileAccess.file_exists(path):return false
 var inspect=load("res://persistence_save_inspection.gd")
 var bytes:=FileAccess.get_file_as_bytes(path)
 var file: ConfigFile=inspect.decode_save(bytes,"")
 if file==null:
  var text:=bytes.get_string_from_utf8()
  return "personal_custody=" in text or "inventory_custody=" in text
 var profile: Variant=file.get_value("character","inventory_custody",{})
 var records: Variant=file.get_value("inventory","personal_custody",{})
 if not valid_profile(profile) or not valid_records(records):return true
 return locked(profile) or records.values().any(func(record):return record.state in ["active","returned"])
