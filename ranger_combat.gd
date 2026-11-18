extends RefCounted
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const Session = preload("res://network_session.gd")

const Participation = preload("res://expedition_participation.gd")
## Host-owned Ranger effects. Corridor and route belong to an accepted trap.
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const Cooldowns = preload("res://player_cooldowns.gd")
const Progression = preload("res://ranger_connected_tree.gd")
const Balance = preload("res://class_skill_balance.gd")
const Journal = preload("res://diagnostic_journal.gd")
const PREY := "ranger_tracked_prey"
const SNARE := "ranger_next_snare"
const FOLLOW := "ranger_follow_through"
const DOUBLE := "ranger_double_draw"
const SPEEDS := "ranger_speed_grants"
const CORRIDOR := "ranger_bramble_corridor"
const ESCAPE := "ranger_escape_route"
const PREY_COLOR := Color("#e6bd69")
const CORRIDOR_COLOR := Color("#98bd64")
const ESCAPE_COLOR := Color("#77c9c9")


static func stamp(game: Node, actor: int, player: Dictionary, cast: int) -> Dictionary:
	return {"owner":actor, "life":PlayerLifecycle.generation(player), "epoch":game.participation.epoch(), "cast":cast}


static func living_here(game: Node, player: Dictionary) -> bool:
	return Participation.is_wild(player) and game.Life.alive(player)


static func source_live(game: Node, record: Dictionary) -> bool:
	if int(record.get("epoch",-1)) != game.participation.epoch():
		return false
	var owner: Dictionary = game.players.get(record.owner,{})
	return living_here(game,owner) and PlayerLifecycle.matches(owner,int(record.life))


static func active_prey(game: Node, state: Dictionary, now: int) -> Dictionary:
	var record: Dictionary = state.get(PREY,{})
	if record.is_empty():
		return {}
	if now >= int(record.until) or not source_live(game,record):
		state.erase(PREY)
		return {}
	return record


static func track(game: Node, actor: int, player: Dictionary, target: int, cast: int, now: int) -> bool:
	var state: Dictionary = game.Traits.target_state(game,target)
	# One active record per enemy. A competing Salvo can choose another survivor.
	if not active_prey(game,state,now).is_empty():
		return false
	var record := stamp(game,actor,player,cast)
	record.until = now + Progression.PREY_MS
	state[PREY] = record
	Journal.event("combat","tracked_prey_set",{"actor":actor,"cast_id":cast,"target":target})
	return true


static func consume_prey(game: Node, hitter: Dictionary, target: int, now: int) -> int:
	if not game.multiplayer.is_server() or not living_here(game,hitter):
		return 0
	var state: Dictionary = game.Traits.target_state(game,target)
	var record := active_prey(game,state,now)
	if record.is_empty():
		return 0
	state.erase(PREY)
	var point: Vector3 = game.enemy_position(target)
	game.emit_combat_event("proc","Tracked Prey triggered",point,point,.55,PREY_COLOR,0,target)
	Journal.event("combat","tracked_prey_hit",{"actor":game.Traits.player_id(game,hitter),
		"owner":record.owner,"cast_id":record.cast,"target":target,"bonus_hp":Progression.PREY_HP})
	return Progression.PREY_HP


static func after_q(game: Node, actor: int, player: Dictionary, skill: Dictionary, cast: int, now: int) -> void:
	var selected: Array = skill.ranger_nodes
	var record := stamp(game,actor,player,cast)
	var center: Vector3 = player.pos
	if selected.has("trail_ward") or selected.has("clear_trail"):
		var lowest := INF
		var recipient: Dictionary = {}
		for id in game.players:
			var ally: Dictionary = game.players[id]
			if not nearby(game,ally,center,float(skill.ranger_support_radius)):
				continue
			if selected.has("clear_trail"):
				ally[Conditions.STATE] = ally[Conditions.STATE].cleanse_slow()
			var ratio := PlayerVitals.current_hp(ally)/maxf(1.0,float(PlayerVitals.maximum_hp(ally,1)))
			if ratio < lowest:
				lowest = ratio
				recipient = ally
		if selected.has("trail_ward") and not recipient.is_empty():
			recipient[Protection.STATE] = recipient[Protection.STATE].grant(now+Balance.WARD_MS,1,Time.get_ticks_msec(),game.participation.epoch())
	# One tier-three choice, independent of the attack preparations.
	if selected.size() > 3:
		player[SNARE] = record.merged({"node":selected[3]})
	if selected.has("fleetfoot"):
		grant_speed(player,"fleetfoot",record,Progression.FLEETFOOT_SPEED,now)


static func q_contact(game: Node, actor: int, player: Dictionary, skill: Dictionary, cast: int, now: int) -> void:
	var selected: Array = skill.ranger_nodes
	var record := stamp(game,actor,player,cast)
	if selected.has("follow_through"):
		player[FOLLOW] = record.merged({"until":now+Progression.FOLLOW_MS})
	if selected.has("double_draw"):
		player[DOUBLE] = record.merged({"until":now+Progression.DOUBLE_MS})


static func prepared_until(game: Node, player: Dictionary, key: String, now: int) -> int:
	var record: Dictionary = player.get(key,{})
	var until := int(record.get("until",0))
	return until if until > now and source_live(game,record) else 0


static func launch(game: Node, player: Dictionary, shot: Dictionary, now: int) -> Dictionary:
	if prepared_until(game,player,FOLLOW,now) > 0:
		shot.ranger_follow_hp = Progression.FOLLOW_HP
		Journal.event("combat","ranger_follow_launch",{"actor":shot.player,"cast_id":player[FOLLOW].cast})
	player.erase(FOLLOW)
	var armed := prepared_until(game,player,DOUBLE,now) > 0
	var cast := int(player.get(DOUBLE,{}).get("cast",0))
	player.erase(DOUBLE)
	if not armed:
		return {}
	var rolled := int(shot.stats.get("preview_strike_hp",Balance.Preview.effect_hp(float(shot.stats.damage))))
	var extra := shot.duplicate()
	extra.erase("ranger_follow_hp")
	extra.ranger_secondary = true
	extra.hits = []
	extra.remaining = 1
	extra.stats = {"pattern":"single","targets":1,"reach":shot.stats.reach,"damage":0.0,"knockback":-.35,
		"affinity_hp":roundi(rolled*Progression.DOUBLE_SCALE),"core_hit":true,"trait_secondary":true}
	Journal.event("combat","double_draw_launch",{"actor":shot.player,"cast_id":cast,
		"weapon":shot.form,"roll_hp":rolled,"secondary_hp":extra.stats.affinity_hp})
	return extra


static func nearby(game: Node, ally: Dictionary, center: Vector3, radius: float) -> bool:
	return living_here(game,ally) and center.distance_to(ally.pos) <= radius and game.battlefield.clear_line(center,ally.pos)


static func grant_speed(ally: Dictionary, key: String, source: Dictionary, amount: float, now: int) -> void:
	var grants: Dictionary = ally.get(SPEEDS,{})
	# Replace one grant per source and effect. Expirations of distinct grants stay independent.
	for name in grants.keys():
		if now >= int(grants[name].until):
			grants.erase(name)
	grants[key] = source.merged({"until":now+Progression.SPEED_MS,"speed":amount,"recipient_life":PlayerLifecycle.generation(ally)})
	ally[SPEEDS] = grants


static func speed_scale(game: Node, ally: Dictionary, now: int) -> float:
	var result := 0.0
	if not ally.has(SPEEDS) or not living_here(game,ally):
		return 1.0
	for grant: Dictionary in ally[SPEEDS].values():
		if now < int(grant.until) and PlayerLifecycle.matches(ally,int(grant.recipient_life)) and source_live(game,grant):
			result = maxf(result,float(grant.speed))
	return 1.0 + result


static func corridor(field: RefCounted, from: Vector3, to: Vector3) -> Dictionary:
	var width := Progression.ROUTE_WIDTH
	if field.occupied(from,width):
		return {}
	var steps := maxi(1,ceili(from.distance_to(to)/.13))
	var end := from
	for i in range(1,steps+1):
		var point := from.lerp(to,float(i)/steps)
		if field.occupied(point,width) or not field.clear_line(end,point,width):
			break
		end = point
	return {"from":from,"to":end,"width":width} if from.distance_to(end) >= .22 else {}


static func corridor_contact(field: RefCounted, route: Dictionary, at: Vector3) -> Vector3:
	var nearest := Geometry3D.get_closest_point_to_segment(at,route.from,route.to)
	if at.distance_to(nearest) > float(route.width) or field.occupied(at) or not field.clear_line(nearest,at):
		return Vector3.INF
	return nearest


static func finish_snare(game: Node, player: Dictionary, trap: Dictionary, from: Vector3, now: int) -> String:
	var prepared: Dictionary = player.get(SNARE,{})
	player.erase(SNARE)
	if source_live(game,prepared):
		match prepared.node:
			"barbed_snare":
				trap.ranger_bonus_hp = Progression.BARBED_HP
			"quick_reset":
				var timers: Cooldowns.Timers = player[Cooldowns.STATE]
				player[Cooldowns.STATE] = timers.refund(Cooldowns.R, now, Progression.RESET_MS, Balance.COOLDOWN_MIN_MS)
			"safe_passage":
				for ally in game.players.values():
					if nearby(game,ally,trap.position,Progression.PASSAGE_RADIUS):
						ally[Protection.STATE] = ally[Protection.STATE].grant(now+Balance.WARD_MS,1,Time.get_ticks_msec(),game.participation.epoch())
	var nodes: Array = trap.skill.ranger_nodes
	var escape := nodes.has("escape_route")
	if not escape and not nodes.has("bramble_corridor"):
		return ""
	var route := corridor(game.battlefield,from,trap.position)
	var name := "Escape Route" if escape else "Bramble Corridor"
	if route.is_empty():
		return "Bramble Snare set. %s needs a wider stretch of traversable ground." % name
	route.until = mini(now+Progression.ESCAPE_MS,int(trap.until)) if escape else int(trap.until)
	route.kind = ESCAPE if escape else CORRIDOR
	route.recipients = {}
	game.emit_combat_event("field",route.kind,route.from,route.to,(int(route.until)-now)/1000.0,
		ESCAPE_COLOR if escape else CORRIDOR_COLOR,route.width,trap.owner)
	route.visual_id = game.combat_event_serial
	trap.ranger_route = route
	Journal.event("combat","ranger_route_set",{"actor":trap.owner,"cast_id":trap.visual_id,"kind":route.kind,
		"from":route.from,"to":route.to})
	if escape:
		tick_route(game,trap,now)
	return ""


static func tick_route(game: Node, trap: Dictionary, now: int) -> void:
	var route: Dictionary = trap.get("ranger_route",{})
	if route.is_empty() or route.kind != ESCAPE:
		return
	if now >= int(route.until):
		end_route(game,trap)
		return
	for id in game.players:
		var ally: Dictionary = game.players[id]
		var identity: Variant = Session.inventory_owner(ally)
		if identity == "":
			identity = id
		if route.recipients.has(identity) or not living_here(game,ally) or not corridor_contact(game.battlefield,route,ally.pos).is_finite():
			continue
		route.recipients[identity] = true
		var source := {"owner":trap.owner,"life":trap.life,"epoch":trap.epoch,"cast":trap.visual_id}
		grant_speed(ally,"escape/%d" % trap.owner,source,Progression.ESCAPE_SPEED,now)
		Journal.event("combat","escape_route_grant",{"actor":trap.owner,"cast_id":trap.visual_id,"recipient":id})


static func end_route(game: Node, trap: Dictionary) -> void:
	var route: Dictionary = trap.get("ranger_route",{})
	if route.is_empty():
		return
	trap.erase("ranger_route")
	game.emit_combat_event("field_end",str(route.visual_id),route.to,route.to,.15,Color.WHITE,0,0)


static func corridor_targets(game: Node, trap: Dictionary) -> Dictionary:
	var result := {}
	var route: Dictionary = trap.get("ranger_route",{})
	if route.get("kind") != CORRIDOR:
		return result
	for target in range(-1,game.encounter.scout_count()):
		if game.Traits.valid_target(game,target):
			var origin := corridor_contact(game.battlefield,route,game.enemy_position(target))
			if origin.is_finite():
				result[target] = origin
	return result


static func trap_hit(game: Node, player: Dictionary, trap: Dictionary, target: int, point: Vector3,
		caught: bool, only_corridor: bool, now: int) -> Dictionary:
	var skill: Dictionary = trap.skill
	var bonus := 0
	if caught:
		bonus = int(trap.get("ranger_bonus_hp",0))
		trap.erase("ranger_bonus_hp")
		if skill.slot == 0 and not trap.get("ranger_caught",false):
			trap.ranger_caught = true
			q_contact(game,int(trap.owner),player,skill,int(trap.visual_id),now)
			if skill.ranger_nodes.has("splinter_ambush"):
				bonus = Progression.AMBUSH_HP
	if bonus == 0 and not only_corridor:
		return skill
	var adjusted := skill.duplicate()
	adjusted.native_hit_adjustments = {target:{"bonus_hp":bonus,"origin":point,
		"isolated":only_corridor or float(skill.get("damage",0)) <= 0.0}}
	return adjusted
