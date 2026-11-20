extends RefCounted

const Sources = preload("res://affinity_status_source.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")
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
const BLEED_MS := 4500
const TICK_MS := 900
const APPLICATION_MS := 1000
const APPLICATION_FRACTION := {"core":.25,"form":.10,"catalyst":.25}
const LIFETIME := {"core": 7000, "form": 4600, "catalyst": 4000}
const LIMIT := {"core": 1, "form": 2, "catalyst": 2}
const RADIUS := {"form": 1.25, "catalyst": 1.85, "ward": 2.4}
const QUALITY := {"ordinary":{"slow":.18,"tick_hp":12},"refined":{"slow":.27,"tick_hp":18}}
const VERSION_DATA := [CORE_HALF_LENGTH, CORE_WIDTH, CORE_COOLDOWN_MS, FORM_INTERVAL_MS,
	BLEED_MS, TICK_MS, APPLICATION_MS, APPLICATION_FRACTION, LIFETIME, LIMIT, RADIUS, QUALITY]


static func description(slot: String, quality: String, resolved: Dictionary = {}) -> String:
	var q: Dictionary=QUALITY[quality] if resolved.is_empty() else resolved
	var line: String={
		"core":"Thorn Line · Brambles last %.1f s. %.1f s cooldown." % [LIFETIME.core/1000.0,CORE_COOLDOWN_MS/1000.0],
		"form":"Barbed Strikes · First direct hit plants a stationary %.2f m patch, at most once per %.1f s. Lasts %.1f s." % [RADIUS.form,FORM_INTERVAL_MS/1000.0,LIFETIME.form/1000.0],
		"catalyst":"Thorn Catalyst · Mapped class actions plant growth at the impact, heal, or departure point. Actual blocks grow a %.1f m thicket. Lasts %.1f s." % [RADIUS.ward,LIFETIME.catalyst/1000.0],
	}[slot]
	return line + "\n%d%% movement slow inside. Bleed shares one tick every %.2f s. Your resolved cap is %.2f damage per tick; this slot adds %d%% of it per application (at most once each %.1f s per target/slot). Contributions linger %.1f s. %d active patches in this slot." % [
		roundi(100*q.slow),TICK_MS/1000.0,float(q.get("personal_cap_hp",q.tick_hp)),roundi(100*APPLICATION_FRACTION[slot]),APPLICATION_MS/1000.0,BLEED_MS/1000.0,LIMIT[slot]]


static func active_fields(game: Node, elapsed: int) -> Array:
	return game.get_meta(FIELDS,[]).filter(func(field):
		return int(field.epoch)==game.participation.epoch() and int(field.until)>elapsed \
			and game.Life.alive(game.players.get(field.actor,{})) \
			and PlayerLifecycle.matches(game.players[field.actor],int(field.life)) \
			and game.network_session.matches(int(field.actor),int(field.binding)))


static func suitable(game: Node, center: Vector3) -> bool:
	return game.battlefield.inside_floor(center,0.0) and not game.battlefield.occupied(center)


static func grow(game: Node, event: RefCounted, center: Vector3, shapes: Array, now: int) -> bool:
	var player: Dictionary=game.players.get(event.actor,{})
	if event.epoch!=game.participation.epoch() or not game.Life.alive(player) or shapes.is_empty():
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
		"activation":event.identity,"life":event.life_generation,"binding":event.connection_binding,"center":center,"shapes":shapes,
		"slow":q.slow,"hp":q.get("personal_cap_hp",q.tick_hp),"until":elapsed+int(LIFETIME[event.source])})
	game.set_meta(FIELDS,fields)
	Journal.event("combat","affinity_thorn_grown",{"actor":event.actor,"activation":event.identity,"slot":event.source,"quality":event.quality})
	# Occupants at creation are affected on the action itself.
	tick(game,elapsed,now)
	return true


static func potency_units(status: Dictionary) -> int:
	var total:=0
	for contributor in status.get("contributors",{}).values(): total+=int(contributor.amount)
	return total

static func cap_units(status: Dictionary) -> int:
	var total:=0
	for contributor in status.get("contributors",{}).values(): total+=int(contributor.cap)
	return total

static func prune(game: Node, status: Dictionary, at: int) -> void:
	for key in status.contributors.keys():
		var row: Dictionary=status.contributors[key]
		if int(row.until)<=at or not Sources.current(game,row): status.contributors.erase(key)
	for key in status.applications.keys():
		if int(status.applications[key])+BLEED_MS<=at: status.applications.erase(key)

static func apply_occupancy(game: Node, target: int, actor: Dictionary, fields: Array, elapsed: int) -> Dictionary:
	var status: Dictionary=actor.get(BLEED,{})
	var active := {}
	var strongest:=0.0
	var point: Vector3=game.enemy_position(target)
	for field in fields:
		if not Footprint.reaches(game.battlefield,field.shapes,point,field.center): continue
		strongest=maxf(strongest,float(field.slow))
		if not active.has(field.key) or float(field.hp)>float(active[field.key].hp): active[field.key]=field
	if strongest>0.0: actor[SLOW]=strongest
	else: actor.erase(SLOW)
	for field: Dictionary in active.values():
		if status.is_empty():
			status={"epoch":game.participation.epoch(),"token":game.encounter.spawn_identity(target),
				"contributors":{},"applications":{},"next":elapsed+TICK_MS,"remainder":0}
		var source := {"actor":field.actor,"binding":field.binding,"life":field.life,"epoch":field.epoch,
			"activation":field.activation,"slot":field.slot,"quality":field.quality,"item":field.item}
		var owner_key := Sources.key(source)
		var response_key := owner_key+"/"+str(field.slot)
		if elapsed<int(status.applications.get(response_key,0)): continue
		status.applications[response_key]=elapsed+APPLICATION_MS
		var row: Dictionary=status.contributors.get(owner_key,source)
		# An accepted cap can increase; a weaker application cannot downgrade an
		# actively maintained contributor. It is forgotten after BLEED_MS idle,
		# a new life/connection, death or floor departure.
		row.cap=maxi(int(row.get("cap",0)),Sources.units(float(field.hp)))
		row.amount=mini(row.cap,int(row.get("amount",0))+roundi(Sources.units(float(field.hp))*float(APPLICATION_FRACTION[field.slot])))
		row.until=elapsed+BLEED_MS
		status.contributors[owner_key]=row
	if not status.is_empty(): actor[BLEED]=status
	return status

static func advance(game: Node, target: int, actor: Dictionary, elapsed: int, now: int) -> void:
	var status: Dictionary=actor.get(BLEED,{})
	if status.is_empty(): return
	if not Sources.target_current(game,target,status):
		actor.erase(BLEED)
		return
	while int(status.next)<=elapsed:
		prune(game,status,int(status.next))
		status.next+=TICK_MS # Claim before damage/reward callbacks.
		if status.contributors.is_empty(): break
		var owner := Sources.dominant(status.contributors,"amount")
		var hp := Sources.whole_tick(status,potency_units(status))
		if hp>0: Actors.damage(game,int(owner.actor),target,hp,now,COLOR)
		if game.persistence_session.is_blocked() or not Sources.target_current(game,target,status): return
	prune(game,status,elapsed)
	if status.contributors.is_empty(): actor.erase(BLEED)

static func tick(game: Node, elapsed: int, now: int) -> void:
	if not game.multiplayer.is_server(): return
	var epoch: int=game.participation.epoch()
	var fields:=active_fields(game,elapsed)
	var wounds_remain:=false
	for target in range(-1,game.encounter.scout_count()):
		if game.participation.epoch()!=epoch or game.persistence_session.is_blocked(): return
		var actor: Dictionary=Actors.body(game,target)
		if not Actors.valid_target(game,target):
			actor.erase(SLOW);actor.erase(BLEED)
			continue
		advance(game,target,actor,elapsed,now)
		if game.participation.epoch()!=epoch or game.persistence_session.is_blocked(): return
		if not Actors.valid_target(game,target): continue
		apply_occupancy(game,target,actor,fields,elapsed)
		wounds_remain=wounds_remain or actor.has(BLEED)
	if fields.is_empty() and not wounds_remain:
		if game.has_meta(FIELDS): game.remove_meta(FIELDS)
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
