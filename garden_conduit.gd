extends RefCounted
# Only configuration changes here. Existing crop/harvest policies own outcomes.
const Layout=preload("res://garden_layout.gd")
const POINT:="terrace_memory"
const ZONE:="cultivation_terrace"
const MODES: Array=[
 {"id":"gentle","name":"Gentle seep","policy":"patient_bud","color":Color("#8ebeb0")},
 {"id":"deep","name":"Deep pulse","policy":"deep_bud","color":Color("#b1ab72")}
]
static func mode(id: String) -> Dictionary:
 for entry in MODES:
  if entry.id==id:return entry
 return {}
static func errors() -> Array[String]:
 var result: Array[String]=[];var ids: Array=[]
 if Layout.zone(ZONE).is_empty() or Layout.Catalog.point(POINT).get("parent","")!=ZONE:result.append("Invalid conduit zone/anchor")
 for entry in MODES:
  if ids.has(entry.id) or preload("res://garden_crop_catalog.gd").definition(entry.policy).is_empty():result.append("Invalid conduit mode/policy")
  ids.append(entry.id)
 return result
static func state(owner: RefCounted) -> Dictionary:
 if owner.garden_interactions.get("version",1)!=1:return {}
 var value=owner.garden_interactions.get("conduit",{"version":1,"revision":0,"mode":"gentle"})
 if not value is Dictionary or value.get("version",0)!=1 or not value.get("revision") is int or value.revision<0 or mode(str(value.get("mode",""))).is_empty():return {}
 return value.duplicate(true)
static func cycle(owner: RefCounted,slot: int,species: int) -> Dictionary:
 var result:=preload("res://garden_crop_state.gd").new_cycle(species)
 if not owner.heart.has("living_conduit") or not Layout.enabled(Layout.zone(ZONE),owner.heart.unlocked) or not Layout.zone_beds(ZONE,owner.plots.size()).has(slot):return result
 var value:=state(owner)
 if value.is_empty():return result
 result.opportunity=mode(value.mode).policy;result.zone_condition=value.mode
 return result
static func choose(request: Dictionary, before: Dictionary, host: bool, unlocked: bool, in_reach: bool) -> Dictionary:
 if not host:return {"error":"Only the Garden host can redirect the conduit. You can still inspect and tend its plants."}
 if request.get("point","")!=POINT or not unlocked or not in_reach:return {"error":"Research the Living Water Conduit and approach the terrace to redirect it."}
 if before.is_empty() or mode(str(request.get("mode",""))).is_empty():return {"error":"This conduit configuration needs a compatible game version."}
 if int(request.revision)!=before.revision:return {"error":"The conduit changed. Review its setting before choosing."}
 if request.mode==before.mode:return {"changed":false,"revision":before.revision}
 var next:=before.duplicate(true);next.mode=request.mode;next.revision+=1
 return {"changed":true,"next":next}
