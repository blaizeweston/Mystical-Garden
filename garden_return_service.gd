extends RefCounted
## Return/discovery operations on the existing Progress owner, never Game.
const State=preload("res://garden_return_state.gd")
const Catalog=preload("res://garden_return_catalog.gd")
const Seeds=preload("res://seed_catalog.gd")

## A frozen receipt identity remains meaningful after its peer is released.
## This value is not another authoritative actor or participation record.
class Member extends RefCounted:
 var _actor: String
 var _run: String
 var _participating: bool
 func _init(actor: String, run: String, participating: bool) -> void:
  _actor=actor;_run=run;_participating=participating
 func actor() -> String:return _actor
 func run() -> String:return _run
 func participating() -> bool:return _participating

static func _state(progress: RefCounted) -> Dictionary:
 if progress.garden_interactions.get("version",1)!=1:return {}
 if not progress.garden_interactions.has("returns"):progress.garden_interactions=State.initialize(progress.garden_interactions)
 var value=progress.garden_interactions.get("returns",{})
 return value if State.usable(value) else {}
static func state(progress: RefCounted) -> Dictionary:return _state(progress).duplicate(true)
static func begin(progress: RefCounted) -> void:
 var value:=_state(progress)
 if not value.is_empty():State.begin(value)
static func join(progress: RefCounted, actor: String) -> String:
 var value:=_state(progress)
 if value.is_empty() or value.active.is_empty():return ""
 State.join(value,actor)
 return str(value.active.id)
static func bank(progress: RefCounted, member: Member, seeds: Array, source: String, ancient: bool=false) -> void:
 var value:=_state(progress)
 if value.is_empty() or member==null or not member.participating():return
 var stable: Array=[]
 for species in seeds:
  if species is int and species>=0 and species<Seeds.DEFINITIONS.size():stable.append(str(Seeds.DEFINITIONS[species].id))
 if stable.is_empty() and not ancient:return
 State.credit(value,member.actor(),member.run(),source,stable,ancient)
static func outcome(progress: RefCounted, member: Member, status: String) -> void:
 var value:=_state(progress)
 if not value.is_empty() and member!=null:State.outcome(value,member.actor(),member.run(),status)
static func identified(progress: RefCounted,species: int,ancient: bool=false) -> void:
 var value:=_state(progress)
 if value.is_empty() or species<0 or species>=Seeds.DEFINITIONS.size():return
 State.identify(value,str(Seeds.DEFINITIONS[species].id),ancient)
static func projection(root: Dictionary) -> Dictionary:
 var value=root.get("returns",{});var entries: Array=[]
 if root.get("version",1)!=1 or not State.usable(value):return {}
 for definition in Catalog.DEFINITIONS:
  if value.discoveries.has(definition.id):entries.append(definition.duplicate(true))
 return {"version":1,"catalog":Catalog.signature,"entries":entries}
static func known(data: Dictionary,id: String) -> bool:
 return data.get("version",0)==1 and data.get("catalog","")==Catalog.signature and data.get("entries",[]).any(func(e):return e.get("id","")==id)
static func note(data: Dictionary,point: String) -> String:
 var lines: Array[String]=[]
 for entry in data.get("entries",[]):
  if entry.get("point","")==point:lines.append(str(entry.description)+"\n"+str(entry.hint))
 return "\n\n".join(lines)
