extends RefCounted
## Authoritative native-effect timeline and active Core casts.
## Records are detached on admission/inspection. Only matching records can commit.
## The world adapter resolves actual damage, status and presentation operations.
const NATIVE_LIMIT := 24
var _native: Dictionary={}
var _cores: Dictionary={}
var _serial:=0

func native_count(grafts_only: bool=false) -> int:
 if not grafts_only:return _native.size()
 var count:=0
 for row: Dictionary in _native.values():count+=int(row.has("graft_source"))
 return count

func native_records() -> Array:
 return _native.values().duplicate(true)

func schedule_native(facts: Dictionary) -> Dictionary:
 if _native.size()>=NATIVE_LIMIT:return {}
 var row:=facts.duplicate(true)
 if not row.has("kind") or not row.has("owner") or not row.has("epoch") or not row.has("life"):return {}
 _serial+=1;row["_native_record"]=_serial
 _native[_serial]=row
 return row.duplicate(true)

func update_native(row: Dictionary) -> bool:
 var id:=int(row.get("_native_record",0))
 if not _native.has(id):return false
 var current: Dictionary=_native[id]
 for key in ["kind","owner","epoch","life","binding"]:
  if current.get(key)!=row.get(key):return false
 _native[id]=row.duplicate(true)
 return true

func remove_native(row: Dictionary) -> bool:
 var id:=int(row.get("_native_record",0))
 if not _native.has(id):return false
 _native.erase(id)
 return true

func clear_native() -> void:_native.clear()

func advance_native(runtime: RefCounted, now: int) -> void:
 runtime.prepare(now)
 # New callbacks can schedule effects, but do not execute them in this frame.
 for id in _native.keys():
  if not _native.has(id):continue
  var row: Dictionary=_native[id].duplicate(true)
  if not runtime.source_current(row):
   remove_native(row);runtime.end(row);continue
  if row.kind=="hit":
   if now<int(row.due):continue
   remove_native(row);runtime.hit(row,now);continue
  if now>=int(row.until):
   remove_native(row);runtime.end(row);continue
  if row.has("ranger_route"):runtime.route(row,now)
  if now>=int(row.next):runtime.pulse(row,now)
  update_native(row)

func core_active(peer: int) -> bool:return _cores.has(peer)
func core(peer: int) -> Dictionary:return _cores.get(peer,{}).duplicate(true)
func core_records() -> Dictionary:return _cores.duplicate(true)

func begin_core(peer: int, line: Dictionary) -> bool:
 if _cores.has(peer):return false
 _cores[peer]=line.duplicate(true)
 return true

func commit_cores(before: Dictionary, after: Dictionary) -> void:
 # A delayed update cannot restore an old cast over a newly admitted cast.
 for peer in before:
  if not _cores.has(peer):continue
  var current: Dictionary=_cores[peer]
  var captured: Dictionary=before[peer]
  if current.get("id")!=captured.get("id") or current.get("epoch")!=captured.get("epoch") or current.get("life")!=captured.get("life"):continue
  if after.has(peer):_cores[peer]=after[peer].duplicate(true)
  else:_cores.erase(peer)

func clear_cores() -> void:_cores.clear()

func savepoint() -> Dictionary:
 return {"native":_native.duplicate(true),"cores":_cores.duplicate(true),"serial":_serial}

func restore_savepoint(value: Dictionary) -> void:
 _native=value.get("native",{}).duplicate(true)
 _cores=value.get("cores",{}).duplicate(true)
 _serial=maxi(_serial,int(value.get("serial",0)))
