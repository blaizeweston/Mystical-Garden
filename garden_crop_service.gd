extends RefCounted

const Session = preload("res://network_session.gd")

const Participation = preload("res://expedition_participation.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")
const Tx=preload("res://game_transaction.gd")
const State=preload("res://garden_crop_state.gd")
const Catalog=preload("res://garden_crop_catalog.gd")
const Growth=preload("res://cultivation_growth.gd")
static func eligible(game: Node,id: int,slot: int) -> bool:
 if not game.multiplayer.is_server() or not game.players.has(id) or slot<0 or slot>=game.progress.plots.size():return false
 var p: Dictionary=game.players[id]
 return Session.ready_for(p,false) and not Participation.is_wild(p) and not PlayerLifecycle.fallen(p) and game.participation.travel_kind().is_empty() and p.pos.distance_to(game.stage.bed_position(slot))<=1.65 and game.progress.offshoot_in_bed(slot)<0
static func focus(game: Node,id: int,slot: int) -> bool:
 if not eligible(game,id,slot) or int(game.progress.plots[slot].species)<0:return false
 var previous: Dictionary=game.players[id].get("garden_crop_focus",{})
 game.players[id].garden_crop_focus={"slot":slot,"serial":int(previous.get("serial",0))+1}
 return true
static func fill_water(game: Node,id: int) -> bool:
 var garden=load("res://garden_interaction_service.gd")
 if not garden.eligible(game,id):return false
 var player: Dictionary=game.players[id]
 if not game.participation.travel_kind().is_empty() or garden.nearest(game,player,garden.projection(game,id))!="spring_water":
  game.tell(id,"Visit the sheltered spring to fill your watering vessel.")
  return false
 if player.get("spring_water",false):return true
 player.spring_water=true
 preload("res://event_audio.gd").emit(game,"vessel_filled",player.pos)
 game.tell(id,"Watering vessel filled. Use it on a growing crop.")
 preload("res://diagnostic_journal.gd").event("garden","spring_water_collected",{"actor":id,"point":"spring_water"})
 return true
static func spring_ready(game: Node) -> bool:
 return Growth.spring_ready(game.progress) and (not game.has_meta(&"experimental_terrain") or game.stage.station_position("spring").is_finite())
static func projection(game: Node,id: int) -> Dictionary:
 if not game.multiplayer.is_server():return game.players.get(id,{}).get("garden_interactions",{}).get("cultivation",{})
 var beds: Array=[];var player: Dictionary=game.players.get(id,{})
 if player.is_empty() or Participation.is_wild(player):return {"version":2,"catalog":Catalog.signature,"beds":[],"focus":{}}
 var watering_available:=spring_ready(game)
 for index in game.progress.plots.size():
  var bed: Dictionary=game.progress.plots[index];var species: int=int(bed.species)
  if species<0:continue
  var care: Dictionary=bed.get("care",{});var base: float=game.Seeds.DEFINITIONS[species].grow_seconds;var policy:=Catalog.definition(str(care.get("opportunity","")))
  var familiarity: int=int(player.get("character",{}).get("plants",[])[species]) if not player.is_empty() else 0
  var chance: float=game.rare_harvest_chance(familiarity);var work:=maxf(0,State.duration(bed,base)-float(bed.age));var seconds: float=work/Growth.rate(game.progress,bed,game.participation.active())
  beds.append({"slot":index,"species":species,"stage":int(bed.stage),"flowering":bool(bed.flowering),"cycle":care.get("cycle",""),"revision":care.get("revision",0),"choice":care.get("choice",""),"compatible":State.compatible(bed),"available":State.available(bed),"preserved":State.preserved(bed),"remaining":seconds,"base_chance":chance,"chance":State.chance(bed,chance),"preserve_chance":minf(float(policy.get("rare_cap",1)),chance+float(policy.get("rare_bonus",0))),"extra_seconds":base*float(policy.get("delay_fraction",0))/game.progress.heart.growth_multiplier(),"flower_enabled":game.progress.flowering_unlocked and not game.participation.active(),"opportunity":care.get("opportunity","patient_bud")})
  beds[-1].merge({"remaining":seconds,"garden_remaining":work/Growth.rate(game.progress,bed),"wild_remaining":work/Growth.rate(game.progress,bed,true),"growth_rate":Growth.rate(game.progress,bed,game.participation.active()),"extra_seconds":base*float(policy.get("delay_fraction",0))/Growth.rate(game.progress,bed,game.participation.active()),"watered":Growth.watered(bed),"water_available":Growth.supported(bed) and State.compatible(bed) and int(bed.stage)<3 and watering_available and not Growth.watered(bed),"spring_ready":watering_available,"flower_enabled":game.progress.flowering_unlocked},true)
 return {"version":2,"catalog":Catalog.signature,"beds":beds,"spring_water":player.get("spring_water",false),"focus":player.get("garden_crop_focus",{}).duplicate(true)}
static func harvest_seeds(game: Node,id: int,slot: int) -> Dictionary:
 if not eligible(game,id,slot) or not game.progress.flowering_unlocked:return reject(game,id,"Research Flowering before harvesting seeds at a Garden bed.")
 var before: Dictionary=game.progress.plots[slot].duplicate(true)
 if int(before.species)<0 or int(before.stage)<3:return reject(game,id,"Let this plant mature, then choose seeds or parts at harvest.")
 if game.has_meta(Tx.SESSION):
  return {"changed":game.harvest_guarded(id,slot,true)}
 var result=Tx.run(game,func():
  game.progress.plots[slot].flowering=true
  game._harvest(id,slot)
  return int(game.progress.plots[slot].species)<0)
 if result!=true:return reject(game,id,"Could not save the seed harvest. Nothing was consumed; please retry.")
 preload("res://diagnostic_journal.gd").event("garden","crop_harvested",{"actor":id,"bed":slot,"cycle":before.get("care",{}).get("cycle",""),"species":game.Seeds.DEFINITIONS[int(before.species)].id,"flowering":true,"preserved":false,"forfeited_bud":State.preserved(before),"rare":false})
 return {"changed":true}
static func reject(game: Node,id: int,reason: String) -> Dictionary:
 game.tell(id,reason)
 preload("res://diagnostic_journal.gd").event("garden","crop_request_rejected",{"actor":id,"reason":reason})
 return {"changed":false,"error":reason}
static func command(game: Node,id: int,request: Dictionary) -> Dictionary:
 var point:=str(request.get("point",""));var number:=point.trim_prefix("bed_")
 if not number.is_valid_int():return reject(game,id,"Unknown planting bed.")
 var slot:=int(number)-1
 if point!="bed_"+str(slot+1) or not eligible(game,id,slot):return reject(game,id,"Move closer to a Garden bed before tending it.")
 var bed: Dictionary=game.progress.plots[slot]
 if not State.compatible(bed):return reject(game,id,"This crop cannot be tended by this game version.")
 if request.get("cycle","")!=bed.care.cycle:return reject(game,id,"This bed contains a different crop. Inspect it again.")
 var action:=str(request.get("action",""));var chosen: String={"preserve_bud":"preserve","leave_bud":"leave"}.get(action,"")
 if action=="water_crop" and Growth.watered(bed):return {"changed":false,"revision":bed.care.revision}
 if not chosen.is_empty() and bed.care.choice==chosen:return {"changed":false,"revision":bed.care.revision}
 if request.get("revision",-1)!=bed.care.revision or request.get("stage",-1)!=int(bed.stage):return reject(game,id,"This crop has changed. Review it before choosing.")
 if action=="inspect_crop":focus(game,id,slot);return {"changed":false}
 if action=="flower_crop":
  return harvest_seeds(game,id,slot)
 if action=="water_crop":
  if int(bed.stage)>=3 or not Growth.supported(bed) or not spring_ready(game):return reject(game,id,"The sheltered spring is unavailable for this crop.")
  if not game.players[id].get("spring_water",false):return reject(game,id,"Fill your watering vessel at the sheltered spring first.")
  var watered_result:=Tx.run_gameplay(game,Tx.Scope.PAIR,func():Growth.water(bed);return true)
  if (watered_result.completed or Tx.committed(watered_result.persistence)) and watered_result.value==true:
   game.players[id].spring_water=false
  if not watered_result.completed or watered_result.value!=true:
   var notice:=Tx.feedback(watered_result,"Could not save watering. Nothing changed; please retry.")
   if watered_result.persistence.is_empty():return reject(game,id,notice)
   game.tell(id,notice)
   return {"changed":false,"error":notice}
  preload("res://event_audio.gd").emit(game,"crop_watered",game.stage.bed_position(slot))
  game.tell(id,"Spring water nourishes this crop. Growth is 25% faster until harvest.")
  preload("res://diagnostic_journal.gd").event("garden","crop_watered",{"actor":id,"bed":slot,"cycle":bed.care.cycle,"revision":bed.care.revision,"multiplier":Growth.WATER_RATE})
  return {"changed":true,"revision":bed.care.revision}
 if action=="harvest_crop":
  if int(bed.stage)!=3:return reject(game,id,"This crop is still growing.")
  return {"changed":game.harvest(id,slot)}
 if chosen.is_empty() or not State.available(bed):return reject(game,id,"That bud is no longer available. The crop will keep growing.")
 # Freeze the care outcome using a copy of the existing RNG state. No extra draw
 # advances combat/loot RNG; harvest still consumes its one ordinary draw.
 var preview_rng:=RandomNumberGenerator.new();preview_rng.seed=game.rng.seed;preview_rng.state=game.rng.state;var roll:=preview_rng.randf()
 var result=Tx.run_gameplay(game,Tx.Scope.PAIR,func():State.choose(bed,chosen,roll);return true)
 if not result.completed or result.value!=true:
  var notice:=Tx.feedback(result,"Could not save the care choice. Nothing changed; please retry.")
  if result.persistence.is_empty():return reject(game,id,notice)
  game.tell(id,notice)
  return {"changed":false,"error":notice}
 game.tell(id,"The bud is preserved. It needs more time and may yield a richer part." if chosen=="preserve" else "The plant will mature at its normal pace.")
 preload("res://diagnostic_journal.gd").event("garden","crop_care_chosen",{"actor":id,"bed":slot,"cycle":bed.care.cycle,"species":game.Seeds.DEFINITIONS[int(bed.species)].id,"choice":chosen,"revision":bed.care.revision})
 return {"changed":true,"revision":bed.care.revision}
