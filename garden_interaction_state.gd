extends RefCounted
const VERSION:=1
const RECEIPT_LIMIT:=32
static func blank() -> Dictionary:return {"version":VERSION,"revision":0,"observations":{},"receipts":[],"latest":{}}
static func normalize(value) -> Dictionary:
 var state: Dictionary=value.duplicate(true) if value is Dictionary else {}
 state.version=maxi(1,int(state.get("version",VERSION))) if state.get("version",VERSION) is int else VERSION
 state.revision=maxi(0,int(state.get("revision",0))) if state.get("revision",0) is int else 0
 if not state.get("observations") is Dictionary:state.observations={}
 if not state.get("receipts") is Array:state.receipts=[]
 var receipts: Array=[]
 for entry in state.receipts:
  if entry is Dictionary and entry.get("key") is String and entry.get("observation") is String and entry.get("revision") is int:receipts.append(entry.duplicate(true))
 state.receipts=receipts.slice(maxi(0,receipts.size()-RECEIPT_LIMIT))
 if not state.get("latest") is Dictionary:state.latest={}
 return state
static func observed(state: Dictionary,id: String) -> bool:return state.get("observations",{}).get(id,false)==true
static func receipt(state: Dictionary,key: String) -> Dictionary:
 for entry in state.get("receipts",[]):
  if entry.key==key:return entry.duplicate(true)
 return {}
static func record(state: Dictionary,point: Dictionary,key: String) -> Dictionary:
 if int(state.version)!=VERSION:return {"changed":false,"error":"This Garden interaction save needs a newer game version."}
 if observed(state,point.observation) or not receipt(state,key).is_empty():return {"changed":false,"revision":state.revision}
 state.revision+=1;state.observations[point.observation]=true
 state.receipts.append({"key":key,"observation":point.observation,"revision":state.revision})
 if state.receipts.size()>RECEIPT_LIMIT:state.receipts.pop_front()
 state.latest={"point":point.id,"observation":point.observation,"revision":state.revision}
 return {"changed":true,"revision":state.revision}
