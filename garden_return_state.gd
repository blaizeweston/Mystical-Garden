extends RefCounted
const Catalog=preload("res://garden_return_catalog.gd")
const HISTORY_LIMIT:=32
static func initialize(data: Dictionary) -> Dictionary:
 var result:=data.duplicate(true)
 if result.get("version",1)!=1:return result
 if not result.has("returns"):result.returns={"version":1,"sequence":0,"active":{},"credits":{},"discoveries":{},"history":[]}
 return result
static func usable(state) -> bool:
 return state is Dictionary and state.get("version",0)==1 and state.get("active") is Dictionary and state.get("credits") is Dictionary and state.get("discoveries") is Dictionary and state.get("history") is Array
static func finish(state: Dictionary) -> void:
 var run: Dictionary=state.active
 if run.is_empty() or run.get("closed",false):return
 for entry in run.members.values():
  if str(entry.status).is_empty():return
 run.closed=true
 var outcomes: Dictionary={}
 for entry in run.members.values():outcomes[entry.status]=int(outcomes.get(entry.status,0))+1
 var summary := {"run":run.id,"sequence":run.sequence,"outcomes":outcomes}
 if run.has("archive"): summary.archive=run.archive
 state.history.append(summary)
 while state.history.size()>HISTORY_LIMIT:state.history.pop_front()
static func begin(state: Dictionary) -> void:
 if not state.active.is_empty() and not state.active.get("closed",false):
  for entry in state.active.members.values():
   if str(entry.status).is_empty():entry.status="interrupted"
  finish(state)
 state.sequence=int(state.get("sequence",0))+1
 state.active={"id":Crypto.new().generate_random_bytes(16).hex_encode(),"sequence":state.sequence,"members":{},"closed":false}
static func join(state: Dictionary,actor: String) -> void:
 if state.active.is_empty() or state.active.get("closed",false):return
 if not state.active.members.has(actor):state.active.members[actor]={"status":"","banks":{}}
 else:state.active.members[actor].status=""
static func credit(state: Dictionary,actor: String,run: String,source: String,species: Array,ancient: bool=false) -> void:
 if state.active.get("id","")!=run or state.active.get("closed",true) or not state.active.get("members",{}).has(actor):return
 var entry: Dictionary=state.active.members[actor]
 if entry.banks.has(source):return
 entry.banks[source]=true
 for id in species:
  if not state.credits.has(id):state.credits[id]={"run":run,"source":source}
 if ancient and not state.credits.has("ancient"):state.credits.ancient={"run":run,"source":source}
static func outcome(state: Dictionary,actor: String,run: String,status: String) -> void:
 if state.active.get("id","")!=run or state.active.get("closed",true) or not state.active.get("members",{}).has(actor):return
 var entry: Dictionary=state.active.members[actor]
 if not str(entry.status).is_empty():return
 entry.status=status;finish(state)
static func identify(state: Dictionary,species: String,ancient: bool=false) -> Array[String]:
 var result: Array[String]=[];var key: String="ancient" if ancient else species
 if not state.credits.has(key):return result
 for definition in Catalog.DEFINITIONS:
  if definition.species!=species or state.discoveries.has(definition.id):continue
  state.discoveries[definition.id]={"run":state.credits[key].run,"source":state.credits[key].source}
  result.append(definition.id)
 return result
