extends RefCounted
const Tx=preload("res://game_transaction.gd")
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
static func projection(game: Node,id: int) -> Dictionary:
 if not game.multiplayer.is_server():return game.players.get(id,{}).get("garden_interactions",{}).get("conduit",{})
 var value:=state(game.progress)
 if value.is_empty():return {}
 value.unlocked=game.progress.heart.has("living_conduit");value.host=id==game.HOST
 return value
static func command(game: Node,id: int,request: Dictionary) -> Dictionary:
 var reject=preload("res://garden_interaction_service.gd").reject
 if id!=game.HOST:return reject.call(game,id,"Only the Garden host can redirect the conduit. You can still inspect and tend its plants.")
 var point:=Layout.Catalog.point(POINT)
 if request.get("point","")!=POINT or not game.progress.heart.has("living_conduit") or not Layout.enabled(point,game.progress.heart.unlocked) or not game.travel_kind.is_empty() or game.players[id].pos.distance_to(point.position)>float(point.range):return reject.call(game,id,"Research the Living Water Conduit and approach the terrace to redirect it.")
 var before:=state(game.progress)
 if before.is_empty() or mode(str(request.get("mode",""))).is_empty():return reject.call(game,id,"This conduit configuration needs a compatible game version.")
 if int(request.revision)!=before.revision:return reject.call(game,id,"The conduit changed. Review its setting before choosing.")
 if request.mode==before.mode:return {"changed":false,"revision":before.revision}
 var result=Tx.run_gameplay(game,Tx.Scope.PAIR,func():
  var next:=before.duplicate(true);next.mode=request.mode;next.revision+=1
  game.progress.garden_interactions.conduit=next;return next)
 if not result.completed or not result.value is Dictionary:
  var notice:=Tx.feedback(result,"Could not save the conduit. Its previous setting remains active.")
  if result.persistence.is_empty():return reject.call(game,id,notice)
  game.tell(id,notice)
  return {"changed":false,"error":notice}
 var saved: Dictionary=result.value
 game.tell(id,mode(saved.mode).name+" will shape newly planted terrace crops. Existing crops keep their care choice.")
 preload("res://diagnostic_journal.gd").event("garden","conduit_changed",{"actor":id,"zone":ZONE,"mode":saved.mode,"revision":saved.revision})
 return {"changed":true,"revision":saved.revision}
