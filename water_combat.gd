extends RefCounted
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const Sources = preload("res://affinity_status_source.gd")
const Actors = preload("res://frost_combat.gd")
const Clock = preload("res://affinity_time.gd")
const Footprint = preload("res://core_footprint.gd")
const DRENCHED := "affinity_drenched"
const COLOR := Color("#82d7ec")
const DURATION_MS := 4200
const WAVE_MS := 550
const WAVE_RADIUS := 1.05
const RADIUS := 2.4
const COOLDOWN_MS := 8000
# Whole Saturation points; Surge is native secondary HP, never healing.
const SATURATION_THRESHOLD := 100
const APPLICATION_SATURATION := {"core":40,"form":15,"catalyst":30}
const SURGE_HP := 6
const SURGE_RADIUS := 2.4
const REDUCTION_LIMIT := .30
const QUALITY := {
	"ordinary": {"reduction": .18, "saturation_bonus":0, "impact_hp": 7, "surge_hp":SURGE_HP, "surge_radius":SURGE_RADIUS},
	"refined": {"reduction": .30, "saturation_bonus":10, "impact_hp": 11, "surge_hp":SURGE_HP, "surge_radius":SURGE_RADIUS},
}
const VERSION_DATA := [DURATION_MS, WAVE_MS, WAVE_RADIUS, RADIUS, COOLDOWN_MS, SATURATION_THRESHOLD, APPLICATION_SATURATION, SURGE_HP, SURGE_RADIUS, REDUCTION_LIMIT, QUALITY]


static func description(slot: String, quality: String, resolved: Dictionary = {}) -> String:
	var p: Dictionary = QUALITY[quality] if resolved.is_empty() else resolved
	var line: String = {
		"core": "Dewfall · A forward curtain deals %d HP and Drenches enemies. Cleanses ordinary Slow from you at formation and from living allies it touches. %.1f s cooldown." % [p.impact_hp, COOLDOWN_MS / 1000.0],
		"form": "Drenching Strikes · Your direct weapon contacts Drench their targets.",
		"catalyst": "Water Catalyst · Offensive class skills Drench. A qualifying block, mapped heal or movement landing washes once within %.1f m." % RADIUS,
	}[slot]
	return line + "\nDrenched reduces direct enemy attack damage by %d%% for %.1f s; only the strongest applies (maximum %d%%). Adds %d shared Saturation. At %d points, Surge deals %d damage within %.1f m and cleanses ordinary Slow from living allies there. Keeps overflow; no healing or recursive Saturation." % [
		roundi(minf(REDUCTION_LIMIT,float(p.reduction))*100),(DURATION_MS+int(p.get("duration_bonus_ms",0)))/1000.0,roundi(100*REDUCTION_LIMIT),
		APPLICATION_SATURATION[slot]+int(p.saturation_bonus),SATURATION_THRESHOLD,int(p.get("surge_hp",SURGE_HP)),float(p.get("surge_radius",SURGE_RADIUS))]


static func clean(game: Node, target: int, elapsed: int) -> Dictionary:
	var actor := Actors.body(game,target)
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
	return status

static func tick(game: Node, elapsed: int) -> void:
	if not game.multiplayer.is_server(): return
	for target in range(-1,game.encounter.scout_count()):
		if Actors.body(game,target).has(DRENCHED): clean(game,target,elapsed)

static func drench(game: Node, event: RefCounted, target: int) -> void:
	var source := Sources.capture(event)
	if not game.multiplayer.is_server() or not Sources.current(game,source) or not Actors.valid_target(game,target): return
	var elapsed := Clock.now(game)
	var status := clean(game,target,elapsed)
	if status.is_empty():
		status={"epoch":event.epoch,"token":game.encounter.spawn_identity(target),"sources":{},"saturation":0}
	var potency: Dictionary=event.potency()
	var amount := clampf(float(potency.reduction),0.0,REDUCTION_LIMIT)
	# Different strengths expire independently, even from the same slot/player.
	# Refreshing a weaker record never prolongs the stronger record's deadline.
	var surge_hp := maxi(0,int(potency.get("surge_hp",SURGE_HP)))
	var surge_radius := float(potency.get("surge_radius",SURGE_RADIUS))
	if not is_finite(surge_radius) or surge_radius<0.0: return
	var saturation_bonus := int(potency.get("saturation_bonus",0))
	if not Sources.sum_fits(int(APPLICATION_SATURATION[event.source]),saturation_bonus): return
	var applied := int(APPLICATION_SATURATION[event.source])+saturation_bonus
	if not Sources.sum_fits(int(status.saturation),applied): return
	var key: String = Sources.key(source)+"/"+event.source+"/"+str([amount,surge_hp,surge_radius])
	source.surge_hp=surge_hp
	source.surge_radius=surge_radius
	source.reduction=amount
	source.until=elapsed+DURATION_MS+int(potency.get("duration_bonus_ms",0))
	status.sources[key]=source
	status.saturation+=applied
	Actors.body(game,target)[DRENCHED]=status
	while int(status.saturation)>=SATURATION_THRESHOLD:
		status.saturation-=SATURATION_THRESHOLD # Consume before any damage callbacks.
		surge(game,event,game.enemy_position(target),surge_values(status))
		if not Sources.target_current(game,target,status) or game.persistence_session.is_blocked(): break

static func reduction(actor: Dictionary, elapsed: int) -> float:
	var strongest:=0.0
	for source in actor.get(DRENCHED,{}).get("sources",{}).values():
		if int(source.until)>elapsed: strongest=maxf(strongest,float(source.reduction))
	return minf(REDUCTION_LIMIT,strongest)

## Damage and radius each use the strongest still-live contributed value.
## The threshold-crossing action keeps damage credit; weak refreshes cannot
## erase or prolong a stronger source's independently expiring influence.
static func surge_values(status: Dictionary) -> Dictionary:
	var result := {"hp":0,"radius":0.0}
	for row: Dictionary in status.get("sources",{}).values():
		result.hp=maxi(int(result.hp),int(row.get("surge_hp",SURGE_HP)))
		result.radius=maxf(float(result.radius),float(row.get("surge_radius",SURGE_RADIUS)))
	return result

static func surge(game: Node, event: RefCounted, center: Vector3, values: Dictionary = {}) -> void:
	var damage_hp := int(values.get("hp",SURGE_HP))
	var radius := float(values.get("radius",SURGE_RADIUS))
	game.emit_combat_event("ability","water_wash",center,center,.55,COLOR,radius,event.actor,{"label":"Surge"})
	var victims: Array=[]
	for target in game.skill_area_targets(center,radius,center):
		victims.append({"target":target,"token":game.encounter.spawn_identity(target)})
	for victim in victims:
		if game.persistence_session.is_blocked() or event.epoch!=game.participation.epoch(): return
		if game.encounter.alive(int(victim.target),int(victim.token)):
			Actors.damage(game,event.actor,int(victim.target),damage_hp,preload("res://combat_clock.gd").now(),COLOR)
	for id in game.Life.living_ids(game):
		var player: Dictionary=game.players[id]
		if center.distance_to(player.pos)<=radius and game.battlefield.clear_line(center,player.pos): cleanse(player)
	preload("res://diagnostic_journal.gd").event("combat","water_surge",{"actor":event.actor,"activation":event.identity,"damage_hp":damage_hp,"radius_m":radius})


static func direct_damage(game: Node, hp: int) -> int:
	# Native enemy strikes and ranged attacks deal their damage on the host
	# at impact. Evaluate the attacker's current Drenched sources here.
	# Delayed ground hazards and unrelated sources have no attack context.
	var target: int = game.get_meta(Actors.ATTACKER, -2)
	if target < -1 or target >= game.encounter.scout_count():
		return hp
	clean(game,target,Clock.now(game))
	return roundi(hp * (1.0 - reduction(Actors.body(game,target), Clock.now(game))))


static func cleanse(player: Dictionary) -> void:
	player[Conditions.STATE] = player[Conditions.STATE].cleanse_slow()


static func wash(game: Node, event: RefCounted, center: Vector3) -> void:
	game.emit_combat_event("ability", "water_wash", center, center, .55, COLOR, RADIUS, event.actor, {"label": "Cleansing wash"})
	for target in game.skill_area_targets(center,RADIUS,center):
		drench(game,event,target)
	for id in game.Life.living_ids(game):
		var player: Dictionary = game.players[id]
		if center.distance_to(player.pos) <= RADIUS and game.battlefield.clear_line(center,player.pos):
			cleanse(player)


static func wave(game: Node, cast: Dictionary, player: Dictionary, now: int) -> bool:
	var elapsed := Clock.now(game)
	if not cast.grown:
		cast.grown = true
		cast.wave_at = elapsed
		var from: Vector3 = player.pos
		var reach: float = Vector3(cast.cast_origin).distance_to(cast.center)
		cast.wave_center = from
		cast.wave_origin = from
		cast.wave_end = game.battlefield.dash(from,from + Vector3(cast.forward) * reach)
		cast.affinity_action.publish(game,"core_action","cleanse",str(cast.owner),now,{"player":cast.owner})
		game.emit_combat_event("projectile", "dewfall", from, cast.wave_end, WAVE_MS / 1000.0, COLOR, WAVE_RADIUS, cast.owner,
			{"label":"Dewfall", "projectile_radius":WAVE_RADIUS, "height":.1})
	var fraction := clampf(float(elapsed - int(cast.wave_at)) / WAVE_MS, 0.0, 1.0)
	var point: Vector3 = Vector3(cast.wave_origin).lerp(cast.wave_end, fraction)
	var previous: Vector3 = cast.wave_center
	var shapes := [{"kind":"capsule", "from":previous, "to":point, "width":WAVE_RADIUS}]
	for id in game.Life.living_ids(game):
		if id != int(cast.owner) and Footprint.reaches(game.battlefield,shapes,game.players[id].pos,previous):
			cast.affinity_action.publish(game,"core_action","cleanse",str(id),now,{"player":id})
	for target in Footprint.targets(game,shapes,previous):
		cast.affinity_action.publish(game,"core_action","impact",Actors.target_token(game,target),now,{"enemy":target})
	cast.wave_center = point
	return fraction >= 1.0


static func on_event(game: Node, event: RefCounted, kind: String, details: Dictionary, now: int) -> void:
	match kind:
		"core_action":
			if details.has("player"):
				var id: int = details.player
				if game.players.has(id) and game.Life.alive(game.players[id]):
					cleanse(game.players[id])
					var ward_ms := int(event.potency().get("shelter_ward_ms",0))
					if ward_ms > 0:
						game.players[id][Protection.STATE] = game.players[id][Protection.STATE].grant(now+ward_ms,1,Time.get_ticks_msec(),game.participation.epoch())
			else:
				Actors.damage(game,event.actor,int(details.enemy),int(event.potency().impact_hp),now,COLOR)
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
