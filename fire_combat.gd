extends RefCounted

const Catalog = preload("res://affinity_card_catalog.gd")
const SEQUENCE := "fire_card_sequence"
const FLASH_READY := "fire_flashover_ready"
const SPREAD_READY := "fire_wildfire_ready"
const CARD_GRANTS := {"wildfire_unlock":{"method":"spread","capability":{"producer":"card","id":"wildfire","recipient":"enemy"}}}
const Sources = preload("res://affinity_status_source.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")

const Actors = preload("res://frost_combat.gd")
const Clock = preload("res://affinity_time.gd")
const Footprint = preload("res://core_footprint.gd")
const BURNING := "affinity_burning"
const RESPONSE := "affinity_ember_response"
const COLOR := Color("#f29b57")
const RADIUS := 2.4
const RESPONSE_MS := 4500
const BURN_MS := 3000
const TICK_MS := 250
const TICK_HP_PER_STACK := .125
const DECAY_MS := 500
const DECAY_STACKS := 8
# Provisional linear loss: doubling maintained input doubles high-intensity
# equilibrium. Below 80 stacks the existing eight-stack decay is unchanged.
const DECAY_PERCENT := 10
const FIELD_APPLICATION_MS := 750
const APPLICATION_STACKS := {"core":16,"form":8,"catalyst":12}
const FIELD_MS := 3200
const HALF_LENGTH := 2.15
const WIDTH := .68
const COOLDOWN_MS := 8000
const QUALITY := {
	"ordinary": {"stack_bonus": 0, "impact_hp": 8, "burst_hp": 5},
	"refined": {"stack_bonus": 4, "impact_hp": 12, "burst_hp": 8},
}
const VERSION_DATA := [RADIUS, RESPONSE_MS, BURN_MS, TICK_MS, TICK_HP_PER_STACK, DECAY_MS, DECAY_STACKS, DECAY_PERCENT, FIELD_APPLICATION_MS, APPLICATION_STACKS, FIELD_MS, HALF_LENGTH, WIDTH, COOLDOWN_MS, QUALITY]


static func description(slot: String, quality: String, resolved: Dictionary = {}) -> String:
	var p: Dictionary = QUALITY[quality] if resolved.is_empty() else resolved
	var line: String = {
		"core": "Ember Wake · %.1f s burning-root trail. %d HP on first contact per enemy, then maintains Burning. %.1f s cooldown." % [(FIELD_MS+int(p.get("field_duration_ms",0))) / 1000.0, p.impact_hp, COOLDOWN_MS / 1000.0],
		"form": "Burning Strikes · Direct weapon contacts ignite the enemies actually hit.",
		"catalyst": "Fire Catalyst · Offensive class skills ignite. An actual block bursts for %d HP and ignites within %.1f m. Mapped healing and movement can grant a %.1f s single-use response to an unblocked enemy hit you survive." % [p.burst_hp, RADIUS, RESPONSE_MS / 1000.0],
	}[slot]
	return line + "\nApplies %d shared Burning stacks. Each stack deals %.3f damage every %.2f s; fractional damage carries between ticks. Every %.1f s, lose %d%% of current intensity (rounded up), at least %d stacks. No fixed intensity ceiling. A contributor expires %.1f s after its last application. The field adds stacks at most once per %.2f s per enemy." % [
		APPLICATION_STACKS[slot]+int(p.stack_bonus),TICK_HP_PER_STACK,TICK_MS/1000.0,DECAY_MS/1000.0,DECAY_PERCENT,DECAY_STACKS,BURN_MS/1000.0,FIELD_APPLICATION_MS/1000.0]



static func count(status: Dictionary) -> int:
	var total:=0
	for row in status.get("contributors",{}).values(): total+=int(row.stacks)
	return total

## Round the percentage upward using integer arithmetic without total*percent
## overflow. Work is per contributor (at most four), never per stack.
static func decay_amount(total: int) -> int:
	@warning_ignore("integer_division")
	var proportional := (total/100)*DECAY_PERCENT + ((total%100)*DECAY_PERCENT+99)/100
	return mini(total,maxi(DECAY_STACKS,proportional))

static func prune(game: Node, status: Dictionary, at: int) -> void:
	for key in status.contributors.keys():
		var row: Dictionary=status.contributors[key]
		if int(row.until)<=at or int(row.stacks)<=0 or not Sources.current(game,row): status.contributors.erase(key)

static func deal_tick(game: Node, target: int, status: Dictionary, now: int) -> void:
	var owner := Sources.dominant(status.contributors,"stacks")
	var hp := Sources.whole_tick(status,count(status)*Sources.units(TICK_HP_PER_STACK))
	if hp>0 and not owner.is_empty(): Actors.damage(game,int(owner.actor),target,hp,now,COLOR,status.contributors.values().all(func(row):return row.get("secondary_only",false)),{"stat_affinity":"Burning","stat_weights":Sources.damage_weights(game,status.contributors.values(),"stacks")})

static func advance(game: Node, target: int, elapsed: int, now: int) -> Dictionary:
	var actor := Actors.body(game,target)
	var status: Dictionary=actor.get(BURNING,{})
	if status.is_empty(): return {}
	if not Sources.target_current(game,target,status):
		actor.erase(BURNING)
		return {}
	# Apply decay before a tick at the same instant. Decay removes the oldest
	# contributing activation first, with peer-ID ties. No source gets its own clock.
	while mini(int(status.next),int(status.decay))<=elapsed:
		var at := mini(int(status.next),int(status.decay))
		prune(game,status,at)
		if status.contributors.is_empty(): break
		if int(status.decay)<=int(status.next):
			status.decay+=DECAY_MS
			var remaining := decay_amount(count(status))
			var ordered: Array=status.contributors.keys()
			ordered.sort_custom(func(a,b):
				var left: Dictionary=status.contributors[a];var right: Dictionary=status.contributors[b]
				return int(left.activation)<int(right.activation) or (left.activation==right.activation and int(left.actor)<int(right.actor)))
			for key in ordered:
				if remaining<=0: break
				var row: Dictionary=status.contributors[key]
				var budget:=mini(remaining,int(row.stacks))
				var denominator:=100+int(row.get("retention_rating",0))
				# Fixed-point carry makes every efficiency copy useful even at low intensity.
				# Decompose before multiplication, as in the existing decay arithmetic.
				@warning_ignore("integer_division")
				var loss_units: int=(budget/denominator)*100000+((budget%denominator)*100000)/denominator+int(row.get("decay_remainder",0))
				@warning_ignore("integer_division")
				var removed: int=loss_units/1000
				row.decay_remainder=loss_units%1000
				row.stacks-=removed;remaining-=budget
				if int(row.stacks)<=0: status.contributors.erase(key)
		else:
			status.next+=TICK_MS
			deal_tick(game,target,status,now)
			if game.persistence_session.is_blocked() or not Sources.target_current(game,target,status): return {}
	prune(game,status,elapsed)
	if status.contributors.is_empty():
		actor.erase(BURNING)
		return {}
	return status

static func identity(row: Dictionary) -> Dictionary:
	return {"actor":row.actor,"binding":row.binding,"life":row.life,"epoch":row.epoch,
		"activation":row.activation,"slot":row.slot,"quality":row.quality,"item":row.item}


static func interval_with_tempo(interval_ms: int, percent: int) -> int:
	return maxi(preload("res://affinity_card_ledger.gd").STRIKE_MIN_MS,roundi(interval_ms/(1.0+maxi(0,percent)/100.0)))


static func tempo_percent(game: Node, player: Dictionary, now: int) -> int:
	var row: Dictionary=player.get(SEQUENCE,{})
	return int(row.get("tempo_percent",0)) if not row.is_empty() and Sources.current(game,row) and now<int(row.get("tempo_until",0)) else 0


static func form_sequence(game: Node, event: RefCounted, q: Dictionary, already: bool, now: int) -> int:
	if event.source!="form" or int(q.get("stoking_stacks",0))+int(q.get("tempo_percent",0))==0: return 0
	var p: Dictionary=game.players[event.actor]
	var old: Dictionary=p.get(SEQUENCE,{})
	var current: bool=not old.is_empty() and Sources.current(game,old) and now<int(old.get("until",0))
	var row: Dictionary=old if current else Sources.capture(event)
	if int(row.get("activation",-1))!=event.identity or not row.has("hits"):
		row.hits=int(row.get("hits",0))+1 if current else 1
		row.activation=event.identity
	row.until=now+int(Catalog.DEFINITIONS.stoking_strikes.tuning.window_ms)
	if already and int(q.get("tempo_percent",0))>0 and int(row.hits)>1:
		row.tempo_percent=(int(row.hits)-1)*int(q.tempo_percent)
		row.tempo_until=now+int(Catalog.DEFINITIONS.feverish_tempo.tuning.duration_ms)
	p[SEQUENCE]=row
	return (int(row.hits)-1)*int(q.get("stoking_stacks",0))


static func apply_stacks(game: Node, source: Dictionary, target: int, offered: int,
		q: Dictionary, now: int, native := true) -> Dictionary:
	if not game.multiplayer.is_server() or not Sources.current(game,source) or game.persistence_session.is_blocked() or not Actors.valid_target(game,target) or offered<=0: return {}
	var elapsed:=Clock.now(game)
	var status:=advance(game,target,elapsed,now)
	if game.persistence_session.is_blocked() or not Actors.valid_target(game,target): return {}
	var fresh:=status.is_empty()
	if fresh:status={"epoch":source.epoch,"token":game.encounter.spawn_identity(target),"contributors":{},"next":elapsed+TICK_MS,"decay":elapsed+DECAY_MS,"remainder":0}
	var existing:=count(status)
	@warning_ignore("integer_division")
	var exact_stacks: int=(Sources.MAX_INTEGER-(Sources.UNITS_PER_HP-1))/Sources.units(TICK_HP_PER_STACK)
	if not Sources.sum_fits(existing,offered) or existing+offered>exact_stacks:
		preload("res://diagnostic_journal.gd").event("combat","affinity_application_rejected",{"family":"fire","actor":source.actor,"reason":"integer_representation"})
		return {}
	var key:=Sources.key(source)
	var row: Dictionary=status.contributors.get(key,identity(source))
	row.stacks=int(row.get("stacks",0))+offered
	row.until=elapsed+BURN_MS
	row.retention_rating=maxi(int(row.get("retention_rating",0)),int(q.get("retention_rating",0)))
	if native:
		row.native_until=elapsed+BURN_MS;row.potency=q.duplicate(true);row.secondary_only=false
	elif not row.has("secondary_only"): row.secondary_only=true
	status.contributors[key]=row
	Actors.body(game,target)[BURNING]=status
	if fresh: deal_tick(game,target,status,now)
	return status


static func ignite(game: Node, event: RefCounted, target: int, now: int) -> void:
	var source:=Sources.capture(event)
	if not Sources.current(game,source) or not Actors.valid_target(game,target): return
	var status:=advance(game,target,Clock.now(game),now)
	var already:=count(status)>0
	var q: Dictionary=event.potency()
	var bonus:=int(q.get("stack_bonus",0))+form_sequence(game,event,q,already,now)
	if already and event.source=="catalyst":bonus+=int(q.get("burning_target_stacks",0))
	if bonus<0 or not Sources.sum_fits(int(APPLICATION_STACKS[event.source]),bonus):return
	var offered:=int(APPLICATION_STACKS[event.source])+bonus
	status=apply_stacks(game,source,target,offered,q,now)
	if status.is_empty() or not Sources.target_current(game,target,status):return
	if int(q.get("flashover_percent",0))>0: flashover(game,source,target,status,q,now)
	if event.source=="catalyst" and int(q.get("resonance_percent",0))>0 and event.take_response("fire_resonance"):
		var point: Vector3=game.enemy_position(target)
		var radius:=float(Catalog.DEFINITIONS.ember_resonance.tuning.radius_m)
		var stacks:=maxi(1,roundi(offered*float(q.resonance_percent)/100.0))
		for victim in game.skill_area_targets(point,radius,point):
			if victim!=target:apply_stacks(game,source,victim,stacks,q,now,false)


static func effect_ready(game: Node, target: int, key: String) -> int:
	var row: Dictionary=Actors.body(game,target).get(key,{})
	return int(row.get("until",0)) if int(row.get("epoch",-1))==game.participation.epoch() and int(row.get("token",-1))==game.encounter.spawn_identity(target) else 0


static func reserve_effect(game: Node, target: int, key: String, until: int) -> void:
	Actors.body(game,target)[key]={"epoch":game.participation.epoch(),"token":game.encounter.spawn_identity(target),"until":until}


static func flashover(game: Node, source: Dictionary, target: int, status: Dictionary, q: Dictionary, now: int) -> void:
	var tuning: Dictionary=Catalog.DEFINITIONS.flashover.tuning
	var elapsed:=Clock.now(game)
	if count(status)<int(tuning.threshold_stacks) or elapsed<effect_ready(game,target,FLASH_READY):return
	var spend:=mini(count(status)-int(tuning.minimum_remaining),maxi(1,floori(count(status)*float(tuning.consume_percent)/100.0)))
	if spend<=0:return
	reserve_effect(game,target,FLASH_READY,elapsed+int(tuning.interval_ms)) # Global target reservation before damage.
	var remaining:=spend
	var ordered: Array=status.contributors.keys()
	ordered.sort_custom(func(a,b):return int(status.contributors[a].actor)<int(status.contributors[b].actor))
	for key in ordered:
		var row: Dictionary=status.contributors[key]
		var used:=mini(remaining,int(row.stacks));row.stacks-=used;remaining-=used
		if int(row.stacks)==0:status.contributors.erase(key)
		if remaining==0:break
	var hp:=roundi((spend-remaining)*float(q.flashover_percent)/100.0)
	var point: Vector3=game.enemy_position(target)
	game.emit_combat_event("ability","flashover",point,point,.5,COLOR,float(tuning.radius_m),int(source.actor),{"label":"Flashover"})
	for victim in game.skill_area_targets(point,float(tuning.radius_m),point):
		if Sources.current(game,source) and not game.persistence_session.is_blocked():load("res://outgoing_hits.gd").affinity_world(game,int(source.actor),victim,hp,now,COLOR,true,{"stat_affinity":"Flashover"})
	preload("res://diagnostic_journal.gd").event("combat","flashover",{"actor":source.actor,"target":target,"spent":spend-remaining,"hp":hp})


static func spread_plan(game: Node, target: int, status: Dictionary, elapsed: int) -> Dictionary:
	if status.is_empty() or not Sources.target_current(game,target,status):return {}
	var tuning: Dictionary=Catalog.DEFINITIONS.wildfire.tuning
	if count(status)<int(tuning.threshold_stacks) or elapsed<effect_ready(game,target,SPREAD_READY):return {}
	var candidates:={}
	for key in status.contributors:
		var row: Dictionary=status.contributors[key]
		if int(row.get("native_until",0))>elapsed and int(row.get("potency",{}).get("wildfire_unlock",0))>0:candidates[key]=row
	var owner:=Sources.dominant(candidates,"stacks")
	return {} if owner.is_empty() else {"target":target,"token":status.token,"source":identity(owner),"potency":owner.potency.duplicate(true),"stacks":maxi(1,roundi(count(status)*float(tuning.spread_percent)/100.0))}


static func spread(game: Node, plan: Dictionary, elapsed: int, now: int) -> void:
	if plan.is_empty() or not Sources.current(game,plan.source) or not game.encounter.alive(int(plan.target),int(plan.token)):return
	var tuning: Dictionary=Catalog.DEFINITIONS.wildfire.tuning
	if elapsed<effect_ready(game,int(plan.target),SPREAD_READY):return
	reserve_effect(game,int(plan.target),SPREAD_READY,elapsed+int(tuning.interval_ms))
	var point: Vector3=game.enemy_position(int(plan.target))
	for victim in game.skill_area_targets(point,float(tuning.radius_m),point):
		if victim!=int(plan.target):apply_stacks(game,plan.source,victim,int(plan.stacks),plan.potency,now,false)
	game.emit_combat_event("ability","wildfire",point,point,.5,COLOR,float(tuning.radius_m),int(plan.source.actor),{"label":"Wildfire"})


static func tick(game: Node, elapsed: int, now: int) -> void:
	if not game.multiplayer.is_server():return
	var epoch: int=game.participation.epoch()
	var plans: Array=[]
	for target in range(-1,game.encounter.scout_count()):
		if game.participation.epoch()!=epoch or game.persistence_session.is_blocked():return
		if Actors.body(game,target).has(BURNING):
			var status:=advance(game,target,elapsed,now)
			var plan:=spread_plan(game,target,status,elapsed)
			if not plan.is_empty():plans.append(plan)
	# Freeze periodic candidates before applying any spread: no same-event cascade.
	for plan in plans:
		if game.participation.epoch()!=epoch or game.persistence_session.is_blocked():return
		spread(game,plan,elapsed,now)


static func field(game: Node, cast: Dictionary, now: int) -> bool:
	var elapsed := Clock.now(game)
	if not cast.grown:
		cast.grown = true
		cast.field_until = elapsed + FIELD_MS + int(cast.affinity_action.potency().get("field_duration_ms",0))
		cast.shapes = Footprint.build(game.battlefield, cast, cast.cast_origin)
		cast.next_maintain = elapsed
		cast.stack_ready = {}
		for shape in cast.shapes:
			game.emit_combat_event("ability", "ember_trail", shape.from, shape.to, (int(cast.field_until)-elapsed) / 1000.0, COLOR, WIDTH, cast.owner,
				{"label": "Ember Wake", "core_shapes": Footprint.encode(cast.shapes)})
	if elapsed >= int(cast.field_until):
		return true
	if elapsed < int(cast.next_maintain):
		return false
	cast.next_maintain = elapsed + 80
	for target in Footprint.targets(game, cast.shapes, cast.center):
		var first: bool = cast.affinity_action.publish(game, "core_action", "impact", Actors.target_token(game, target), now, {"enemy": target})
		var token := Actors.target_token(game,target)
		if first:
			cast.stack_ready[token]=elapsed+FIELD_APPLICATION_MS
		elif elapsed>=int(cast.stack_ready.get(token,0)):
			cast.stack_ready[token]=elapsed+FIELD_APPLICATION_MS
			ignite(game,cast.affinity_action,target,now)
	return false


static func on_event(game: Node, event: RefCounted, kind: String, details: Dictionary, now: int) -> void:
	match kind:
		"core_action":
			Actors.damage(game, event.actor, int(details.enemy), int(event.potency().impact_hp), now, COLOR)
			ignite(game, event, int(details.enemy), now)
		"weapon_contact", "class_contact", "incoming_hit":
			ignite(game, event, int(details.enemy), now)
		"actual_block":
			var center: Vector3 = details.center
			game.emit_combat_event("ability", "ember_guard", center, center, .55, COLOR, RADIUS, details.recipient, {"label": "Ember Ward"})
			for enemy in game.skill_area_targets(center, RADIUS, center):
				Actors.damage(game, event.actor, enemy, int(event.potency().burst_hp), now, COLOR)
				ignite(game, event, enemy, now)
		"class_action":
			var response: String = details.get("response", "")
			match response:
				"recipient_ember_response", "self_ember_response":
					var recipients: Array = [event.actor] if response == "self_ember_response" else details.recipients
					for id in recipients:
						if game.players.has(id) and game.Life.alive(game.players[id]):
							game.players[id][RESPONSE] = {"event": event, "until": Clock.now(game) + RESPONSE_MS}
				"burn":
					var enemies: Array = details.enemies
					if details.get("target_scope") == "designated_area":
						enemies = game.skill_area_targets(details.center, details.radius, details.center)
					for enemy in enemies:
						ignite(game, event, enemy, now)


static func incoming(game: Node, recipient: Dictionary, id: int, now: int) -> void:
	var response: Dictionary = recipient.get(RESPONSE, {})
	if response.is_empty():
		return
	if Clock.now(game) >= int(response.until) or response.event.epoch != game.participation.epoch():
		recipient.erase(RESPONSE)
		return
	var target: int = game.get_meta(Actors.ATTACKER, -2)
	if not Actors.valid_target(game, target):
		return
	recipient.erase(RESPONSE)
	response.event.publish(game, "incoming_hit", str(id), Actors.target_token(game, target), now, {"enemy": target})
