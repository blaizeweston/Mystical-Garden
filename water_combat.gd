extends RefCounted
const Effects = preload("res://enemy_affinity_effects.gd")
const OutgoingHits = preload("res://outgoing_hits.gd")
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const Sources = preload("res://affinity_status_source.gd")
const Clock = preload("res://affinity_time.gd")
const Footprint = preload("res://core_footprint.gd")
const DRENCHED := "affinity_drenched"
const COLOR := Color("#82d7ec")
const DURATION_MS := 4200
const WAVE_MS := 550
const WAVE_RADIUS := 1.05
const RADIUS := 2.4
const COOLDOWN_MS := 8000
# Whole Saturation points; one threshold funds source-weighted damage and restoration.
const SATURATION_THRESHOLD := 100
const SATURATION_RETENTION := "maintained_drenched_and_current_source"
const APPLICATION_SATURATION := {"core":40,"form":15,"catalyst":30}
const SURGE_HP := 6
const SURGE_HEAL_HP := 6
const SEQUENCE := "water_card_sequence"
const REFRESH := "water_card_restoration"
const CARD_FIELDS := [SEQUENCE, REFRESH]
const REDUCTION_LIMIT := .30
const SHELTER_WARD_PARAMETER := "shelter_ward_ms"
# The same parameter is read by on_event below; eligibility does not invent it.
const CARD_GRANTS := {"monsoon_unlock":{"method":"drench","capability":{"producer":"card","id":"monsoon","recipient":"living_allies"}},SHELTER_WARD_PARAMETER:{"method":"on_event", "capability":{
	"producer":"card", "id":"dew_shelter", "slot":"core", "recipient":"living_allies"}}}
const QUALITY := {
	"ordinary": {"reduction": .18, "saturation_bonus":0, "impact_hp": 7, "surge_hp":SURGE_HP, "surge_heal_hp":SURGE_HEAL_HP, "direct_heal_hp":2},
	"refined": {"reduction": .30, "saturation_bonus":10, "impact_hp": 11, "surge_hp":SURGE_HP, "surge_heal_hp":SURGE_HEAL_HP, "direct_heal_hp":3},
}
const VERSION_DATA := [DURATION_MS, WAVE_MS, WAVE_RADIUS, RADIUS, COOLDOWN_MS, SATURATION_THRESHOLD, SATURATION_RETENTION, APPLICATION_SATURATION, SURGE_HP, SURGE_HEAL_HP, REDUCTION_LIMIT, QUALITY,preload("res://water_tidal_return.gd").VERSION_DATA]


static func description(slot: String, quality: String, resolved: Dictionary = {}) -> String:
	var p: Dictionary = QUALITY[quality] if resolved.is_empty() else resolved
	var line: String = {
		"core": "Dewfall · A forward curtain deals %d HP and Drenches enemies. Cleanses ordinary Slow from you at formation and from living allies it touches. %.1f s cooldown." % [p.impact_hp, COOLDOWN_MS / 1000.0],
		"form": "Drenching Strikes · Your direct weapon contacts Drench their targets.",
		"catalyst": "Water Catalyst · Offensive class skills Drench. A qualifying block, mapped heal or movement landing washes once within %.1f m." % RADIUS,
	}[slot]
	return line + "\nDrenched reduces direct attacks by %d%% for %.1f s (strongest only, at most %d%%). Adds %d Saturation to the shared 100-point threshold. Tidal Return sends source-weighted outgoing damage (%.1f full share) and returning healing (%.1f full share), with ordinary Slow cleansing. Keeps pressure overflow; tide contacts cannot create more Saturation." % [
		roundi(minf(REDUCTION_LIMIT,float(p.reduction))*100),(DURATION_MS+int(p.get("duration_bonus_ms",0)))/1000.0,roundi(100*REDUCTION_LIMIT),
		APPLICATION_SATURATION[slot]+int(p.saturation_bonus),float(p.get("surge_hp",SURGE_HP)),float(p.get("surge_heal_hp",SURGE_HEAL_HP))]



static func clean(game: Node, target: int, elapsed: int) -> Dictionary:
	var actor := Effects.read(game,target)
	var status: Dictionary=actor.get(DRENCHED,{})
	if status.is_empty(): return {}
	if not Sources.target_current(game,target,status):
		actor.erase(DRENCHED)
		return {}
	for key in status.sources.keys():
		var row: Dictionary=status.sources[key]
		if int(row.until)<=elapsed or not Sources.current(game,row): status.sources.erase(key)
	if status.sources.is_empty():
		actor.erase(DRENCHED)
		return {}
	if status.has("pressure"):
		# Pressure has no decay. Maintained Drenched retains its captured credits;
		# invalid owners are removed, and the whole meter ends with Drenched.
		status.pressure=status.pressure.filter(func(row):return Sources.current(game,row.source) and game.Life.alive(game.players.get(row.source.actor,{})))
		status.saturation=0
		for row in status.pressure:status.saturation+=int(row.amount)
	return status

static func tick(game: Node, elapsed: int) -> void:
	if not game.multiplayer.is_server(): return
	for target in range(-1,game.encounter.scout_count()):
		if Effects.read(game,target).has(DRENCHED): clean(game,target,elapsed)

static func drench(game: Node, event: RefCounted, target: int) -> void:
	var source := Sources.capture(event)
	if not game.multiplayer.is_server() or not Sources.current(game,source) or not game.encounter.alive(target): return
	var elapsed := Clock.now(game)
	var status := clean(game,target,elapsed)
	if status.is_empty():
		status={"epoch":event.epoch,"token":game.encounter.spawn_identity(target),"sources":{},"saturation":0,"pressure":[]}
	var potency: Dictionary=event.potency()
	if event.source=="form" and not event.replica:
		var sequence:=ordinary_sequence(game,event,preload("res://combat_clock.gd").now())
		potency.saturation_bonus=int(potency.get("saturation_bonus",0))+maxi(0,int(sequence.count)-1)*int(potency.get("sequence_saturation",0))
	var amount := clampf(float(potency.reduction),0.0,REDUCTION_LIMIT)
	# Different strengths expire independently, even from the same slot/player.
	# Refreshing a weaker record never prolongs the stronger record's deadline.
	var saturation_bonus := int(potency.get("saturation_bonus",0))
	if not Sources.sum_fits(int(APPLICATION_SATURATION[event.source]),saturation_bonus): return
	var applied := roundi((int(APPLICATION_SATURATION[event.source])+saturation_bonus)*float(potency.get("application_scale",1.0)))
	if not Sources.sum_fits(int(status.saturation),applied): return
	var key: String = Sources.key(source)+"/"+event.source+"/"+str(amount)
	source.reduction=amount
	source.until=elapsed+DURATION_MS+int(potency.get("duration_bonus_ms",0))
	status.sources[key]=source
	status.saturation+=applied
	status.pressure.append({"source":Sources.capture(event),"potency":potency,"amount":applied})
	Effects.edit(game,target)[DRENCHED]=status
	while int(status.saturation)>=SATURATION_THRESHOLD:
		if not load("res://water_tidal_return.gd").admit(game,target,status,preload("res://combat_clock.gd").now()):break
		if not Sources.target_current(game,target,status) or game.persistence_session.is_blocked():break

static func ordinary_sequence(game: Node, event: RefCounted, now: int) -> Dictionary:
	var player: Dictionary=game.players.get(event.actor,{})
	var prior: Dictionary=player.get(SEQUENCE,{})
	var p: Dictionary=event.potency()
	var source:=Sources.capture(event)
	if prior.get("source",{}).get("life")!=event.life_generation or not Sources.current(game,prior.get("source",source)) or now-int(prior.get("last",0))>int(preload("res://affinity_card_catalog.gd").DEFINITIONS.rolling_current.tuning.gap_ms):prior={}
	if int(prior.get("activation",-1))!=event.identity:
		prior={"source":source,"activation":event.identity,"last":now,"count":int(prior.get("count",0))+1}
		player[SEQUENCE]=prior
		if int(p.get("prepared_heal_hp",0))>0:player[REFRESH]={"source":source,"hp":int(p.prepared_heal_hp),"until":now+int(preload("res://affinity_card_catalog.gd").DEFINITIONS.refreshing_strikes.tuning.duration_ms)}
	return prior

static func ordinary_bonus(game: Node, event: RefCounted, target: int) -> int:
	if event.affinity!="water" or event.source!="form":return 0
	var status:=clean(game,target,Clock.now(game))
	var bonus:=int(event.potency().get("pressure_hit_hp",0))
	return bonus if bonus>0 and int(status.get("saturation",0))>=int(preload("res://affinity_card_catalog.gd").DEFINITIONS.pressure_point.tuning.threshold) and event.take_response("water_pressure_point") else 0


static func reduction(status: Dictionary, elapsed: int) -> float:
	var strongest:=0.0
	for source in status.get("sources",{}).values():
		if int(source.until)>elapsed: strongest=maxf(strongest,float(source.reduction))
	return minf(REDUCTION_LIMIT,strongest)



static func direct_damage(game: Node, hp: int) -> int:
	# Native enemy strikes and ranged attacks deal their damage on the host
	# at impact. Evaluate the attacker's current Drenched sources here.
	# Delayed ground hazards and unrelated sources have no attack context.
	var target: int = game.tactics.attacking_slot()
	if target < -1 or target >= game.encounter.scout_count():
		return hp
	var elapsed := Clock.now(game)
	return roundi(hp * (1.0 - reduction(clean(game,target,elapsed),elapsed)))


static func cleanse(player: Dictionary) -> void:
	player[Conditions.STATE] = player[Conditions.STATE].cleanse_slow()


static func wash(game: Node, event: RefCounted, center: Vector3) -> void:
	game.emit_combat_event("ability", "water_wash", center, center, .55, COLOR, RADIUS, event.actor, {"label": "Cleansing wash"})
	for target in game.skill_area_targets(center,RADIUS,center):
		drench(game,event,target)
	var support_radius:=RADIUS+int(event.potency().get("cleanse_radius_cm",0))/100.0
	for id in game.Life.living_ids(game):
		var player: Dictionary = game.players[id]
		if center.distance_to(player.pos) <= support_radius and game.battlefield.clear_line(center,player.pos):
			cleanse(player)


static func wave(game: Node, cast: Dictionary, player: Dictionary, now: int) -> bool:
	var elapsed := Clock.now(game)
	var width: float=cast.skill.radius
	if not cast.grown:
		cast.grown = true
		cast.wave_at = elapsed
		var from: Vector3 = player.pos
		var reach: float = Vector3(cast.cast_origin).distance_to(cast.center)
		cast.wave_center = from
		cast.wave_origin = from
		cast.wave_end = game.battlefield.dash(from,from + Vector3(cast.forward) * reach)
		cast.affinity_action.publish(game,"core_action","cleanse",str(cast.owner),now,{"player":cast.owner})
		game.emit_combat_event("projectile", "dewfall", from, cast.wave_end, WAVE_MS / 1000.0, COLOR, width, cast.owner,
			{"label":"Dewfall", "projectile_radius":width, "height":.1})
	var fraction := clampf(float(elapsed - int(cast.wave_at)) / WAVE_MS, 0.0, 1.0)
	var point: Vector3 = Vector3(cast.wave_origin).lerp(cast.wave_end, fraction)
	var previous: Vector3 = cast.wave_center
	var shapes := [{"kind":"capsule", "from":previous, "to":point, "width":width}]
	for id in game.Life.living_ids(game):
		if id != int(cast.owner) and Footprint.reaches(game.battlefield,shapes,game.players[id].pos,previous):
			cast.affinity_action.publish(game,"core_action","cleanse",str(id),now,{"player":id})
	for target in Footprint.targets(game,shapes,previous):
		cast.affinity_action.publish(game,"core_action","impact",game.encounter.contact_key(target),now,{"enemy":target})
	cast.wave_center = point
	return fraction >= 1.0


static func on_event(game: Node, event: RefCounted, kind: String, details: Dictionary, now: int) -> void:
	match kind:
		"core_action":
			if details.has("player"):
				var id: int = details.player
				if game.players.has(id) and game.Life.alive(game.players[id]):
					cleanse(game.players[id])
					game.Life.Sustain.restore(game,game.players[id],int(event.potency().get("direct_heal_hp",0)),"dewfall/"+str(event.actor),-1,event.actor)
					var ward_ms := int(event.potency().get(SHELTER_WARD_PARAMETER,0))
					if ward_ms > 0:
						game.players[id][Protection.STATE] = game.players[id][Protection.STATE].grant(now+ward_ms,1,Time.get_ticks_msec(),game.participation.epoch())
			else:
				OutgoingHits.affinity_and_clear(game,event.actor,int(details.enemy),int(event.potency().impact_hp),now,COLOR)
				drench(game,event,int(details.enemy))
		"weapon_contact", "class_contact":
			drench(game,event,int(details.enemy))
		"actual_block":
			wash(game,event,details.center)
		"class_action":
			match details.get("response", ""):
				"healing_wash", "landing_wash":
					wash(game,event,details.center)
				"drench":
					var targets: Array = details.enemies
					if details.get("target_scope") == "designated_area":
						targets = game.skill_area_targets(details.center,details.radius,details.center)
					for target in targets:
						drench(game,event,target)
