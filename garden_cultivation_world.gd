extends RefCounted
## Host cultivation integration. Progress owns beds; profiles/inventory own yields.
## Public operations accept peer/bed IDs and requests, never mutable actors.
## Only this port knows Game and persistence; there is no second crop store.
const Rules=preload("res://garden_cultivation.gd")
const Session = preload("res://network_session.gd")
const Participation = preload("res://expedition_participation.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const Tx=preload("res://game_transaction.gd")
const State=preload("res://garden_crop_state.gd")
const Catalog=preload("res://garden_crop_catalog.gd")
const Growth=preload("res://cultivation_growth.gd")
const Water=preload("res://garden_water.gd")
const Seeds=preload("res://seed_catalog.gd")
const Parts=preload("res://weapon_parts.gd")
const Progress=preload("res://progress.gd")
const Journal=preload("res://diagnostic_journal.gd")

var _world: WeakRef

func _init(world: Node) -> void:
	_world=weakref(world)

func _current_world() -> Node:
	var world: Node=_world.get_ref()
	return world if is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() else null

func eligible(id: int,slot: int) -> bool:
	var world:=_current_world()
	if world==null:return false
	if not world.multiplayer.is_server() or not world.players.has(id) or slot<0 or slot>=world.progress.plots.size():return false
	var p: Dictionary=world.players[id]
	return Session.ready_for(p,false) and not Participation.is_wild(p) and not PlayerLifecycle.fallen(p) and world.participation.travel_kind().is_empty() and p.pos.distance_to(world.stage.bed_position(slot))<=1.65
func focus(id: int,slot: int) -> bool:
	var world:=_current_world()
	if world==null:return false
	if not eligible(id,slot) or int(world.progress.plots[slot].species)<0:return false
	var previous: Dictionary=world.players[id].get("garden_crop_focus",{})
	world.players[id].garden_crop_focus={"slot":slot,"serial":int(previous.get("serial",0))+1}
	return true
func fill_water(id: int) -> bool:
	var world:=_current_world()
	if world==null:return false
	if not world.garden_commands.eligible(id):return false
	var player: Dictionary=world.players[id]
	var source:=Water.nearby(world.stage,player.pos)
	if not world.participation.travel_kind().is_empty() or not spring_ready() or source.is_empty():
		world.tell(id,"After Root Irrigation is researched, approach a clear Garden water bank to fill your watering vessel.")
		return false
	if player.get("spring_water",false):return true
	player.spring_water=true
	preload("res://event_audio.gd").emit(world,"vessel_filled",player.pos)
	world.tell(id,"Watering vessel filled. Use it on a growing crop.")
	preload("res://diagnostic_journal.gd").event("garden","spring_water_collected",{"actor":id,"point":"spring_water","source":source.source,"position":[source.position.x,source.position.y,source.position.z]})
	return true
func spring_ready() -> bool:
	var world:=_current_world()
	if world==null:return false
	return Growth.spring_ready(world.progress) and Water.available(world.stage)
## A scalar inspection must not build every crop's growth/yield projection.
func water_carried(id: int) -> bool:
	var world:=_current_world()
	if world==null:return false
	if not world.multiplayer.is_server():return bool(world.players.get(id,{}).get("garden_interactions",{}).get("cultivation",{}).get("spring_water",false))
	var player: Dictionary=world.players.get(id,{})
	return not player.is_empty() and not Participation.is_wild(player) and bool(player.get("spring_water",false))
func projection(id: int) -> Dictionary:
	var world:=_current_world()
	if world==null:return {}
	if not world.multiplayer.is_server():return world.players.get(id,{}).get("garden_interactions",{}).get("cultivation",{}).duplicate(true)
	var beds: Array=[];var player: Dictionary=world.players.get(id,{})
	if player.is_empty() or Participation.is_wild(player):return {"version":2,"catalog":Catalog.signature,"beds":[],"focus":{}}
	var watering_available:=spring_ready()
	for index in world.progress.plots.size():
		var bed: Dictionary=world.progress.plots[index];var species: int=int(bed.species)
		if species<0:continue
		var familiarity: int=int(player.get("character",{}).get("plants",[])[species])
		var rates: Dictionary={"current":Growth.rate(world.progress,bed,world.participation.active()),"garden":Growth.rate(world.progress,bed),"wild":Growth.rate(world.progress,bed,true)}
		beds.append(Rules.bed_projection(index,bed.duplicate(true),familiarity,rates,watering_available,world.progress.flowering_unlocked))
	return {"version":2,"catalog":Catalog.signature,"beds":beds,"spring_water":player.get("spring_water",false),"focus":player.get("garden_crop_focus",{}).duplicate(true)}
func harvest_seeds(id: int,slot: int) -> Dictionary:
	var world:=_current_world()
	if world==null:return {}
	if not eligible(id,slot) or not world.progress.flowering_unlocked:return reject(id,"Research Flowering before harvesting seeds at a Garden bed.")
	var before: Dictionary=world.progress.plots[slot].duplicate(true)
	if int(before.species)<0 or int(before.stage)<3:return reject(id,"Let this plant mature, then choose seeds or parts at harvest.")
	if world.persistence_session.is_guarded():
		return {"changed":_harvest_guarded(id,slot,true)}
	var result=Tx.run(world,func():
		world.progress.plots[slot].flowering=true
		_harvest(id,slot)
		return int(world.progress.plots[slot].species)<0)
	if result!=true:
		var pending: String = world.persistence_session.pending_notice()
		return reject(id,pending if not pending.is_empty() else "Could not save the seed harvest. Nothing was consumed; please retry.")
	preload("res://diagnostic_journal.gd").event("garden","crop_harvested",{"actor":id,"bed":slot,"cycle":before.get("care",{}).get("cycle",""),"species":Seeds.DEFINITIONS[int(before.species)].id,"flowering":true,"preserved":false,"forfeited_bud":State.preserved(before),"rare":false})
	return {"changed":true}
func reject(id: int,reason: String) -> Dictionary:
	var world:=_current_world()
	if world==null:return {}
	world.tell(id,reason)
	preload("res://diagnostic_journal.gd").event("garden","crop_request_rejected",{"actor":id,"reason":reason})
	return {"changed":false,"error":reason}

func command(id: int, request: Dictionary) -> Dictionary:
	var world:=_current_world()
	if world==null:return {}
	var slot:=Rules.bed_slot(str(request.get("point","")))
	var can_tend:=eligible(id,slot)
	var bed: Dictionary=world.progress.plots[slot] if can_tend else {}
	var decision:=Rules.care_request(request,can_tend,bed.duplicate(true),spring_ready(),bool(world.players.get(id,{}).get("spring_water",false)))
	match decision.operation:
		"reject":return reject(id,decision.error)
		"noop":return {"changed":false,"revision":decision.revision}
		"focus":focus(id,slot);return {"changed":false}
		"seeds":return harvest_seeds(id,slot)
		"parts":return {"changed":harvest(id,slot)}
		"water":
			var command_result:=Tx.run_gameplay(world,Tx.Scope.PAIR,func():Growth.water(bed);return true)
			if (command_result.completed or Tx.committed(command_result.persistence)) and command_result.value==true:world.players[id].spring_water=false
			if not command_result.completed or command_result.value!=true:
				var notice:=Tx.feedback(command_result,"Could not save watering. Nothing changed; please retry.")
				if command_result.persistence.is_empty():return reject(id,notice)
				world.tell(id,notice);return {"changed":false,"error":notice}
			preload("res://event_audio.gd").emit(world,"crop_watered",world.stage.bed_position(slot))
			world.tell(id,"Garden water nourishes this crop. Growth is 25% faster until harvest.")
			preload("res://diagnostic_journal.gd").event("garden","crop_watered",{"actor":id,"bed":slot,"cycle":bed.care.cycle,"revision":bed.care.revision,"multiplier":Growth.WATER_RATE})
			return {"changed":true,"revision":bed.care.revision}
	# Freeze the same one care roll without spending gameplay RNG.
	var preview_rng:=RandomNumberGenerator.new();preview_rng.seed=world.rng.seed;preview_rng.state=world.rng.state
	var roll:=preview_rng.randf();var chosen:=str(decision.choice)
	var result:=Tx.run_gameplay(world,Tx.Scope.PAIR,func():State.choose(bed,chosen,roll);return true)
	if not result.completed or result.value!=true:
		var notice:=Tx.feedback(result,"Could not save the care choice. Nothing changed; please retry.")
		if result.persistence.is_empty():return reject(id,notice)
		world.tell(id,notice);return {"changed":false,"error":notice}
	world.tell(id,"The bud is preserved. It needs more time and may yield a richer part." if chosen=="preserve" else "The plant will mature at its normal pace.")
	preload("res://diagnostic_journal.gd").event("garden","crop_care_chosen",{"actor":id,"bed":slot,"cycle":bed.care.cycle,"species":Seeds.DEFINITIONS[int(bed.species)].id,"choice":chosen,"revision":bed.care.revision})
	return {"changed":true,"revision":bed.care.revision}

func harvest(id: int, slot: int) -> bool:
	var world:=_current_world()
	if world==null or not world.multiplayer.is_server():return false
	if not world.players.has(id) or slot<0 or slot>=world.progress.plots.size():return false
	if not world.stage.bed_position(slot).is_finite():return false
	if world.persistence_session.is_guarded():
		return _harvest_guarded(id, slot, false)
	var bed: Dictionary=world.progress.plots[slot].duplicate(true)
	var rare: int=Parts.rare_part(int(bed.species)) if int(bed.species)>=0 else 0
	var rare_before: int=world.progress.part_count(rare) if rare>0 else 0
	var result=Tx.run(world,func(): _harvest(id,slot))
	if result==false:return false
	if int(bed.species)>=0 and int(bed.stage)==3 and int(world.progress.plots[slot].species)<0:
		_report_harvest(id, slot, bed, bool(bed.flowering), rare>0 and world.progress.part_count(rare)>rare_before)
		return true
	return false

func _harvest_guarded(id: int, slot: int, flower: bool) -> bool:
	var world:=_current_world()
	if not eligible(id, slot): return false
	var bed: Dictionary = world.progress.plots[slot].duplicate(true)
	if int(bed.species)<0 or int(bed.stage)<3 or (flower and not world.progress.flowering_unlocked): return false
	var result: Dictionary = world.run_guarded_action(id, world.actor_profile_scope(id), func(effects):
		if flower: world.progress.plots[slot].flowering = true
		var rare := Parts.rare_part(int(bed.species))
		var rare_before: int = world.progress.part_count(rare) if rare>0 else 0
		var changed := _harvest(id, slot, effects)
		if changed:
			effects.append(_report_harvest.bind(id, slot, bed, flower or bool(bed.flowering), rare>0 and world.progress.part_count(rare)>rare_before))
		return changed)
	return Tx.committed(result.persistence) and result.value == true

func _report_harvest(id: int, slot: int, bed: Dictionary, flowering: bool, rare: bool) -> void:
	var preserved := preload("res://garden_crop_state.gd").preserved(bed)
	Journal.event("garden", "crop_harvested", {"actor":id,"bed":slot,"cycle":bed.get("care",{}).get("cycle",""),"species":Seeds.DEFINITIONS[int(bed.species)].id,"flowering":flowering,"preserved":preserved and not flowering,"forfeited_bud":preserved and flowering,"rare":rare})

func _harvest(id: int, slot: int, effects = null) -> bool:
	var world:=_current_world()
	var bed: Dictionary = world.progress.plots[slot]
	var kind := int(bed.species)
	if kind < 0 or bed.stage < 3:
		world.action_feedback(effects, id, "Still growing: %s." % ["Seed", "Sprout", "Young plant", "Mature"][int(bed.stage)])
		return false
	var seeds := bool(bed.flowering)
	world.progress.plots[slot] = Progress.empty_plot()
	world.progress.sync_plot_flags()
	var profile: Dictionary = world.players[id].character
	var familiarity: int = profile.plants[kind]
	profile.plants[kind] = Rules.familiarity_after(familiarity,world.progress.heart.has("nursery"))
	world.save_action_profile(id, effects)
	var harvest_roll: float=world.rng.randf() if not seeds else 0.0
	var result:=Rules.harvest_yield(bed.duplicate(true),familiarity,harvest_roll)
	if seeds:world.seed_reserve(world.players[id]).stock[kind]+=int(result.seeds)
	else:
		world.progress.parts[kind]+=int(result.parts)
		if int(result.rare_part)>0:world.progress.add_parts(int(result.rare_part),1)
	var message:=str(result.message)
	var play_audio := func(): preload("res://event_audio.gd").emit(world, "crop_harvested", world.stage.bed_position(slot))
	if effects == null:
		world.save_progress(id, message)
		play_audio.call()
	else:
		effects.append(world.tell_profile_action.bind(id,message))
		effects.append(play_audio)
	return true


func plant_seed(id: int, slot: int) -> bool:
	var world:=_current_world()
	if world==null or not world.multiplayer.is_server() or not world.players.has(id) or slot<0 or slot>=world.progress.plots.size():return false
	if not world.stage.bed_position(slot).is_finite():return false
	var player: Dictionary = world.players[id]
	var kind: int = world.selected_seed(player)
	var stock: Array = world.seed_reserve(player).stock
	if world.progress.plots[slot].species >= 0:
		return false
	if stock[kind] <= 0:
		world.tell(id, "Identify seeds at the Altar first.")
		return false
	var before: Dictionary=world.progress.plots[slot].duplicate(true)
	var planted := Tx.run_gameplay(world, Tx.Scope.GARDEN, func():
		stock[kind] -= 1
		world.progress.plots[slot] = Rules.planted_bed(kind,preload("res://garden_conduit.gd").cycle(world.progress,slot,kind))
		world.progress.sync_plot_flags()
		if world.persistence_session.is_guarded() or world.progress.save_garden()==OK: return true
		stock[kind]+=1;world.progress.plots[slot]=before;world.progress.sync_plot_flags()
		return false, false)
	if not planted.completed or planted.value != true:
		world.tell(id,Tx.feedback(planted,"Planting could not be saved. Your seed was returned."))
		return false
	world.tell(id,"%s planted."%Progress.PLANT_NAMES[kind])
	return true
