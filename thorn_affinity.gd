extends RefCounted

const Actors = preload("res://frost_combat.gd")
const Clock = preload("res://affinity_time.gd")
const Footprint = preload("res://core_footprint.gd")
const Journal = preload("res://diagnostic_journal.gd")
const FIELDS := &"affinity_thorn_fields"
const BLEED := "affinity_bleed"
const SLOW := "affinity_thorn_slow"
const FORM_READY := "affinity_thorn_form_ready"
const COLOR := Color("#a7bf67")
const CORE_HALF_LENGTH := 2.25
const CORE_WIDTH := .65
const CORE_COOLDOWN_MS := 8000
const FORM_INTERVAL_MS := 2100
const BLEED_MS := 2580
const TICK_MS := 720
const LIFETIME := {"core": 7000, "form": 4600, "catalyst": 4000}
const LIMIT := {"core": 1, "form": 2, "catalyst": 2}
const RADIUS := {"form": 1.25, "catalyst": 1.85, "ward": 2.4}
const QUALITY := {"ordinary":{"slow":.18,"tick_hp":4},"refined":{"slow":.27,"tick_hp":6}}
const VERSION_DATA := [CORE_HALF_LENGTH, CORE_WIDTH, CORE_COOLDOWN_MS, FORM_INTERVAL_MS,
	BLEED_MS, TICK_MS, LIFETIME, LIMIT, RADIUS, QUALITY]


static func description(slot: String, quality: String) -> String:
	var q: Dictionary=QUALITY[quality]
	var line: String={
		"core":"Thorn Line · Brambles last %.1f s. %.1f s cooldown." % [LIFETIME.core/1000.0,CORE_COOLDOWN_MS/1000.0],
		"form":"Barbed Strikes · First direct hit plants a stationary %.2f m patch, at most once per %.1f s. Lasts %.1f s." % [RADIUS.form,FORM_INTERVAL_MS/1000.0,LIFETIME.form/1000.0],
		"catalyst":"Thorn Catalyst · Mapped class actions plant growth at the impact, heal, or departure point. Actual blocks grow a %.1f m thicket. Lasts %.1f s." % [RADIUS.ward,LIFETIME.catalyst/1000.0],
	}[slot]
	return line + "\n%d%% movement slow while inside. Bleed deals %d HP every %.2f s and lingers %.2f s. %d active per player in this slot. A new patch replaces the oldest at the limit." % [
		roundi(100*q.slow),q.tick_hp,TICK_MS/1000.0,BLEED_MS/1000.0,LIMIT[slot]]


static func active_fields(game: Node, elapsed: int) -> Array:
	return game.get_meta(FIELDS,[]).filter(func(field):
		return int(field.epoch)==game.combat_epoch and int(field.until)>elapsed \
			and game.Life.alive(game.players.get(field.actor,{})) \
			and int(game.players[field.actor].get("lost_health",0))==int(field.life))


static func suitable(game: Node, center: Vector3) -> bool:
	return game.battlefield.inside_floor(center,0.0) and not game.battlefield.occupied(center)


static func grow(game: Node, event: RefCounted, center: Vector3, shapes: Array, now: int) -> bool:
	var player: Dictionary=game.players.get(event.actor,{})
	if event.epoch!=game.combat_epoch or not game.Life.alive(player) or shapes.is_empty():
		return false
	if not suitable(game,center):
		return false
	var elapsed:=Clock.now(game)
	var fields:=active_fields(game,elapsed)
	var key:="%d/%s" % [event.actor,event.source]
	var owned:=fields.filter(func(field):return field.key==key)
	if owned.size()>=int(LIMIT[event.source]):
		fields.erase(owned.front())
	var q: Dictionary=event.potency()
	fields.append({"id":"affinity-thorn:%d:%s" % [event.identity,str(center)],"epoch":event.epoch,
		"actor":event.actor,"key":key,"slot":event.source,"quality":event.quality,"item":event.material_id,
		"activation":event.identity,"life":player.get("lost_health",0),"center":center,"shapes":shapes,
		"slow":q.slow,"hp":q.tick_hp,"until":elapsed+int(LIFETIME[event.source])})
	game.set_meta(FIELDS,fields)
	Journal.event("combat","affinity_thorn_grown",{"actor":event.actor,"activation":event.identity,"slot":event.source,"quality":event.quality})
	# Occupants at creation are affected on the action itself.
	tick(game,elapsed,now)
	return true


static func apply_occupancy(game: Node, target: int, actor: Dictionary, fields: Array, elapsed: int) -> Dictionary:
	var sources: Dictionary=actor.get(BLEED,{})
	var active := {}
	var strongest:=0.0
	var point: Vector3=game.enemy_position(target)
	for field in fields:
		if not Footprint.reaches(game.battlefield,field.shapes,point,field.center):
			continue
		strongest=maxf(strongest,float(field.slow))
		if not active.has(field.key) or int(field.hp)>int(active[field.key].hp):
			active[field.key]=field
	if strongest>0.0: actor[SLOW]=strongest
	else: actor.erase(SLOW)
	for key in active:
		var wound: Dictionary=sources.get(key,{})
		var field: Dictionary=active[key]
		var next:=elapsed+TICK_MS if int(wound.get("until",0))<=elapsed else int(wound.next)
		sources[key]={"actor":field.actor,"activation":field.activation,"item":field.item,"quality":field.quality,
			"hp":field.hp,"next":next,"until":elapsed+BLEED_MS}
	if not sources.is_empty(): actor[BLEED]=sources
	return sources


static func tick(game: Node, elapsed: int, now: int) -> void:
	if not game.has_meta(FIELDS):
		return
	var epoch: int=game.combat_epoch
	var fields:=active_fields(game,elapsed)
	var wounds_remain:=false
	for target in range(-1,game.scouts.size()):
		if game.combat_epoch!=epoch or game.get_meta(game.Transactions.PENDING,false):
			return
		var actor: Dictionary=Actors.body(game,target)
		if not Actors.valid_target(game,target):
			actor.erase(SLOW)
			actor.erase(BLEED)
			continue
		var sources:=apply_occupancy(game,target,actor,fields,elapsed)
		for key in sources.keys():
			var wound: Dictionary=sources[key]
			while int(wound.next)<=elapsed and int(wound.next)<int(wound.until):
				wound.next+=TICK_MS
				Actors.damage(game,wound.actor,target,wound.hp,now,COLOR)
				if game.combat_epoch!=epoch or game.get_meta(game.Transactions.PENDING,false) or not Actors.valid_target(game,target):
					break
			if game.combat_epoch!=epoch or game.get_meta(game.Transactions.PENDING,false) or not Actors.valid_target(game,target):
				break
			if int(wound.until)<=elapsed: sources.erase(key)
		if sources.is_empty(): actor.erase(BLEED)
		else: wounds_remain=true
	if game.combat_epoch==epoch:
		if fields.is_empty() and not wounds_remain: game.remove_meta(FIELDS)
		else: game.set_meta(FIELDS,fields)


static func release(game: Node, cast: Dictionary, now: int) -> void:
	var shapes:=Footprint.build(game.battlefield,cast,cast.cast_origin)
	cast.affinity_action.publish(game,"core_action","grow","",now,{"center":cast.center,"shapes":shapes})


static func patch(game: Node, event: RefCounted, center: Vector3, radius: float, now: int) -> bool:
	center.y=0
	return grow(game,event,center,[Footprint.area(center,radius)],now)


static func on_event(game: Node, event: RefCounted, kind: String, details: Dictionary, now: int) -> void:
	match kind:
		"core_action":
			grow(game,event,details.center,details.shapes,now)
		"weapon_contact":
			var player: Dictionary=game.players.get(event.actor,{})
			var elapsed:=Clock.now(game)
			var point: Vector3=details.get("point",game.enemy_position(details.enemy))
			point.y=0
			if not game.Life.alive(player) or elapsed<int(player.get(FORM_READY,0)) or not suitable(game,point) or not event.take_response("thorn_form"):
				return
			if patch(game,event,point,RADIUS.form,now):
				player[FORM_READY]=elapsed+FORM_INTERVAL_MS
		"class_contact":
			if event.take_response("thorn_class"):
				patch(game,event,details.get("point",game.enemy_position(details.enemy)),RADIUS.catalyst,now)
		"actual_block":
			patch(game,event,details.center,RADIUS.ward,now)
		"class_action":
			match details.get("response",""):
				"growth","protective_growth":
					patch(game,event,details.center,RADIUS.catalyst,now)
				"departure_growth":
					patch(game,event,details.start,RADIUS.catalyst,now)


static func hints(game: Node) -> Array:
	if not game.has_meta(FIELDS):
		return []
	var elapsed:=Clock.now(game)
	var result := []
	for field in active_fields(game,elapsed):
		var center: Vector3=field.center
		var at:=[center.x,0,center.z]
		result.append({"id":field.id,"role":"core_field","from":at,"to":at,
			"radius":CORE_HALF_LENGTH+CORE_WIDTH if field.slot=="core" else RADIUS.ward,
			"remaining":(int(field.until)-elapsed)/1000.0,"color":"#a7bf67","skill":"thorn_line",
			"core_shapes":Footprint.encode(field.shapes)})
	return result
