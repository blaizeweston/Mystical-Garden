extends RefCounted
const Catalog=preload("res://garden_growth_catalog.gd")
## Replicated event kinds and acknowledgements. Version 2 adds frontier expansion playback.
const NETWORK_VERSION := 2
const LIMIT:=64
static func snapshot(owner: RefCounted) -> Dictionary:
 return {"tech":owner.heart.unlocked.duplicate(),"phase":owner.heart.phase(owner),"level":Catalog.level(owner.knowledge,int(owner.flowering_unlocked)+int(owner.veilcap_discovered)+owner.heart.clearing_bonus())}
static func load_history(data: Dictionary,owner: RefCounted) -> Dictionary:
 var result:=initialize(data,snapshot(owner))
 if result.get("version",1)!=1 or not result.get("growth") is Dictionary or result.growth.get("version")!=1:return result
 var growth: Dictionary=result.growth
 if growth.get("baseline") is Dictionary and growth.baseline.get("tech") is Array:
  for retired in ["rift_hook","infusion"]: growth.baseline.tech.erase(retired)
 if growth.get("events") is Array:
  # Keep sequence numbers and per-viewer acknowledgements for surviving events.
  growth.events=growth.events.filter(func(event):return not (event is Dictionary and event.get("technology") in ["rift_hook","infusion"]))
 return result
static func initialize(data: Dictionary,current: Dictionary) -> Dictionary:
 var result:=data.duplicate(true)
 if int(result.get("version",1))!=1:return result
 if not result.has("growth"):result.growth={"version":1,"sequence":0,"baseline":current.duplicate(true),"events":[],"seen":{}}
 return result
static func prepare(owner: RefCounted) -> Dictionary:
 var current:=snapshot(owner);var result:=initialize(owner.garden_interactions,current)
 if result.get("version",1)!=1 or not result.growth is Dictionary or result.growth.get("version",0)!=1:return result
 var state: Dictionary=result.growth
 if not state.get("baseline",current) is Dictionary:return result
 var before: Dictionary=state.get("baseline",current)
 if not before.get("tech") is Array or not before.get("phase") is int or not before.get("level") is int or not state.get("events") is Array or not state.get("seen") is Dictionary:return result
 var added: Array=[]
 var walking:=before.duplicate(true)
 for id in current.tech:
  if id!="heart" and not before.tech.has(id) and Catalog.Heart.enabled(id):
   var next:=current.duplicate(true);next.tech=walking.tech.duplicate();next.tech.append(id)
   added.append(Catalog.describe(id,walking,next));walking=next
 if added.is_empty() and int(current.phase)>int(before.phase):added.append(Catalog.describe("",before,current))
 var returned=owner.garden_interactions.get("returns",{})
 if returned is Dictionary and returned.get("version",0)==1 and returned.get("discoveries") is Dictionary:
  if not state.has("return_receipts"):state.return_receipts=[]
  for definition in preload("res://garden_return_catalog.gd").DEFINITIONS:
   if returned.discoveries.has(definition.id) and not state.return_receipts.has(definition.id):
    added.append({"kind":"return","discovery":definition.id,"point":definition.point,"name":definition.name,"description":definition.description,"from_phase":current.phase,"to_phase":current.phase,"from_level":current.level,"to_level":current.level})
    state.return_receipts.append(definition.id)
 for event in added:
  _append_event(state,event)
 while state.events.size()>LIMIT:state.events.pop_front()
 state.baseline=current
 return result

# Called inside the same guarded transaction that saves the purchased land and root.
static func record_expansion(owner: RefCounted, number: int, direction: String) -> bool:
 var data:=prepare(owner)
 var growth: Dictionary=data.get("growth",{}) if data.get("growth") is Dictionary else {}
 if data.get("version",1)!=1 or growth.get("version")!=1 or not growth.get("events") is Array or not growth.get("seen") is Dictionary:return false
 _append_event(growth,{"kind":"expansion","expansion":number,"name":"The Garden expands · "+direction})
 if growth.events.size()>LIMIT:growth.events.pop_front()
 owner.garden_interactions=data
 return true

static func _append_event(state: Dictionary,event: Dictionary) -> void:
 state.sequence=int(state.get("sequence",0))+1
 event.sequence=state.sequence
 state.events.append(event)
