extends RefCounted
const OutgoingHits = preload("res://outgoing_hits.gd")
const HitSession = preload("res://network_session.gd")
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const Cooldowns = preload("res://player_cooldowns.gd")
const Catalog = preload("res://subclass_catalog.gd")
const Balance = preload("res://class_skill_balance.gd")
const WeaverCombat = preload("res://weaver_combat.gd")
const Ranger = preload("res://ranger_combat.gd")
const Reaper = preload("res://reaper_combat.gd")
const CLIPS := {
	"weave":"Attack_wand", "bloom":"Attack_staff", "silk":"Attack_orb",
	"salvo":"Attack_bow", "snare":"Attack_ring", "retreat":"Attack_crossbow",
	"harvest":"Attack_scythe", "veil":"Attack_knives", "grave":"Attack_whip",
	"omen":"Attack_fan", "bell":"Attack_bell", "sanctuary":"Attack_censer",
}


static func plan(game: Node, player: Dictionary, field: RefCounted, skill: Dictionary, forward: Vector3, distance: float) -> Dictionary:
	var origin: Vector3 = player.pos
	var reach := float(skill.get("range",0))
	var radius := float(skill.get("radius",0))
	var center := origin
	var endpoint := origin
	var target := -2
	var valid := true
	var shape: String = skill.shape
	match shape:
		"ground", "dash", "retreat":
			var amount := reach if distance < 0.0 else minf(distance,reach)
			var direction := -forward if shape == "retreat" else forward
			endpoint = field.dash(origin,origin+direction*amount)
			if shape != "retreat":
				center = endpoint
			if shape in ["dash","retreat"]:
				valid = origin.distance_to(endpoint) >= .22
		"target":
			var picked: Dictionary = load("res://class_ability_targeting.gd").pick(game,field,origin,forward,reach)
			valid = not picked.is_empty()
			target = int(picked.get("target",-2))
			center = picked.get("point",origin)
		"line":
			endpoint = field.projectile_endpoint(origin,origin+forward*reach,float(skill.width))
			center = endpoint
			valid = origin.distance_to(endpoint) >= .22
		"cone":
			endpoint = origin + forward
	return {"center":center,"endpoint":endpoint,"origin":origin,"forward":forward,"range":reach,
		"radius":radius,"width":float(skill.get("width",0)),"span":float(skill.get("span",0)),
		"target":target,"valid":valid,"shape":shape}


static func footprint(cast: Dictionary) -> Array:
	var shapes: Array = []
	if cast.range > 0.0:
		shapes.append({"kind":"range","at":cast.origin,"radius":cast.range})
	if not cast.valid:
		return shapes
	match cast.shape:
		"line":
			shapes.append({"kind":"strip","from":cast.origin,"to":cast.endpoint,"width":cast.width})
		"cone":
			shapes.append({"kind":"cone","at":cast.origin,"forward":cast.forward,"radius":cast.radius,"span":cast.span})
		_:
			if cast.shape in ["dash","retreat"]:
				shapes.append({"kind":"travel","from":cast.origin,"to":cast.endpoint})
			shapes.append({"kind":"area","at":cast.center,"radius":cast.radius})
			if cast.shape == "target":
				shapes.append({"kind":"point","at":cast.center,"radius":.48})
	return shapes


static func targets(game: Node, cast: Dictionary, skill: Dictionary) -> Array[int]:
	if cast.shape == "line":
		return game.skill_line_targets(cast.origin,cast.forward,cast.range,cast.width,int(skill.limit))
	var result: Array[int] = game.skill_area_targets(cast.center,cast.radius,cast.origin)
	if cast.shape == "target":
		result.erase(cast.target)
		result.sort_custom(func(a,b): return cast.center.distance_squared_to(game.enemy_position(a)) < cast.center.distance_squared_to(game.enemy_position(b)))
		result.push_front(cast.target)
		result.resize(mini(result.size(),int(skill.limit)))
	elif cast.shape == "cone":
		for target in result.duplicate():
			var offset: Vector3 = game.enemy_position(target)-Vector3(cast.origin)
			if offset.length_squared() > .0001 and offset.normalized().dot(cast.forward) < cos(float(cast.span)*.5):
				result.erase(target)
	return result


static func in_windup(game: Node, target: int, now: int) -> bool:
	return game.tactics.winding_up if target == -1 else int(game.encounter.scout(target).get("windup",0)) > now


static func allies(game: Node, center: Vector3, radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ally in game.players.values():
		if game.Life.alive(ally) and center.distance_to(ally.pos) <= radius and game.battlefield.clear_line(center,ally.pos):
			result.append(ally)
	result.sort_custom(func(a,b):
		return PlayerVitals.current_hp(a)/float(PlayerVitals.maximum_hp(a)) < PlayerVitals.current_hp(b)/float(PlayerVitals.maximum_hp(b)))
	return result


static func cast_skill(game: Node, id: int, player: Dictionary, skill: Dictionary, stats: Dictionary, now: int) -> void:
	var aim: Vector3 = player.get("class_aim",player.get("facing",Vector3.FORWARD))
	if not player.has("class_aim"):
		var targeting = load("res://class_ability_targeting.gd")
		var width := float(skill.width) if skill.shape == "line" else -1.0
		var chosen: int = targeting.automatic(game,player,float(skill.get("range",4.0)),{},width)
		if chosen != -2:
			var offset: Vector3 = game.enemy_position(chosen)-Vector3(player.pos)
			if offset.length_squared() > .001:
				aim = offset.normalized()
	var cast := plan(game,player,game.battlefield,skill,aim,float(player.get("class_aim_distance",-1.0)))
	if not cast.valid:
		game.tell(id,"No clear target for %s." % skill.name)
		return
	var adapter: Dictionary = stats.get("cr02_adapter", {})
	var events = preload("res://combat_action_events.gd")
	var event: RefCounted = stats.get(events.CONTEXT)
	if not adapter.is_empty() and event == null: event = events.class_start(game,id,adapter,now)
	var leaves_snare: bool = skill.visual in ["snare", "retreat"]
	var ranger := skill.has("ranger_nodes")
	var reaper := skill.has("reaper_nodes")
	var oracle := skill.has("oracle_nodes")
	var oracle_api = preload("res://oracle_combat.gd")
	var bind := Balance.subclass_bind(skill,{})
	if ranger and leaves_snare:
		var trap := skill.duplicate()
		trap.bind = bind
		if game.battlefield.occupied(cast.center) or game.Traits.place_snare(game,player,cast.center,trap,stats,now).is_empty():
			game.tell(id,"Could not set %s here. Use open ground and wait for an active effect to expire." % skill.name)
			return
	var affected: Array[int] = []
	if not leaves_snare:
		affected = targets(game,cast,skill)
	var release_end: Vector3 = cast.endpoint if cast.shape in ["line","dash","retreat","cone"] else cast.center
	player.facing = aim
	player.aim_direction = aim
	if cast.shape in ["dash","retreat"]:
		player.pos = cast.endpoint
		player.velocity = Vector3.ZERO
		if player.has("affinity_spirit_follow"):
			preload("res://spirit_affinity.gd").movement(game,player,cast.origin,player.pos)
	game.emit_combat_event("subclass_release",skill.visual,cast.origin,release_end,.67,Color(skill.color),cast.radius,id,
		{"pattern":cast.shape,"width":cast.width,"span":cast.span,"owner":id,"clip":CLIPS[skill.visual],"label":skill.name})
	var cast_id: int = game.combat_event_serial
	var weaver := skill.has("weaver_nodes")
	var oracle_hit := oracle_api.begin_q(game,player,skill,affected,cast.center,now) if oracle else {}
	var q_contact := false
	var ranger_damage := false
	var reaper_damage := false
	var prey_set := false
	if leaves_snare and not ranger:
		var trap := skill.duplicate()
		trap.bind = bind
		game.Traits.place_snare(game,player,cast.center,trap,stats,now)
	var drain_contacts := 0
	var radius: float = cast.radius if cast.radius > 0.0 else 2.0
	var contact: Vector3 = cast.center
	if cast.shape == "line":
		contact = game.enemy_position(affected[0]) if not affected.is_empty() else cast.origin
	for target in affected:
		var impact: Vector3 = game.enemy_position(target)
		if cast.shape == "target" and target != cast.target:
			game.emit_combat_event("link","interwoven_bind",cast.center,impact,.5,Color(skill.color),0.0,id)
		var windup := in_windup(game,target,now)
		var damage := Balance.Preview.authored_amount(float(skill.get("damage",0)) + (float(skill.get("punish",0)) if windup else 0.0))
		var rewardable: bool = target == -1 or not game.encounter.scout(target).get("summoned",false)
		var oracle_hp: int = int(oracle_hit.hp) if target == int(oracle_hit.get("target",-2)) else 0
		if damage > 0 or oracle_hp > 0:
			var hit := stats.duplicate() if damage > 0 else oracle_api.spell_hit(oracle_hp)
			hit.damage = damage
			hit.knockback = -.35
			var before: int = game.encounter.hp(target)
			hit.ranger_direct_hit = not ranger and damage > 0
			if oracle_hp > 0:
				hit.native_bonus_hp = oracle_hp
			if ranger and not ranger_damage and skill.ranger_nodes.has("splinter_ambush"):
				hit.native_bonus_hp = Catalog.Ranger.AMBUSH_HP
			if reaper:
				Reaper.tag_hit(hit,skill.reaper_nodes)
				if not reaper_damage and skill.reaper_nodes.has("rending_cut"):
					hit.native_bonus_hp = Catalog.Reaper.RENDING_HP
			OutgoingHits.hit_world(game, HitSession.peer_for(player), target, cast.center, hit, now)
			var after: int = game.encounter.hp(target)
			q_contact = q_contact or after < before
			if reaper and after < before:
				reaper_damage = true
			if ranger and after < before:
				if not ranger_damage:
					Ranger.q_contact(game,id,player,skill,cast_id,now)
				ranger_damage = true
				if not prey_set and after > 0 and skill.subclass_focus == "wildstalker":
					prey_set = Ranger.track(game,id,player,target,cast_id,now)
			if rewardable:
				drain_contacts += int(after<before)
		if not game.Traits.valid_target(game,target):
			continue
		if bind > 0:
			var until := now+bind+int(stats.get("skill_duration",0))
			var previous: int = game.tactics.rooted_until if target == -1 else int(game.encounter.scout(target).get("rooted_until",0))
			preload("res://combat_status.gd").root(game,target,until)
			q_contact = q_contact or until > previous
		if skill.has("pull"):
			pull(game,target,cast.center,float(skill.pull),now)
	if weaver and not affected.is_empty() and skill.second == 0:
		echo(game,player,contact,affected,Color(skill.color),now,weaver)
	var drain_count := drain_contacts
	if skill.get("leech",false) and drain_count>0:
		game.Life.Sustain.heal(game,player,Balance.drain_amount(skill,drain_count),skill.id,Balance.Preview.HEAL_DRAIN_SPREAD_HP)
	var field_duration := Balance.duration(skill,stats)
	var field := {}
	if skill.has("field") and not (ranger and leaves_snare):
		field = game.Traits.zone(game,player,skill.field,cast.center,cast.radius,field_duration,Balance.field_power(skill),now,false,
			events.field_action(stats))
		if not field.is_empty() and skill.subclass_focus == "bloomcaller":
			field.native_weaver_bloom = true
	var nearby := allies(game,contact,radius)
	var extend_ward: bool = weaver and skill.subclass_focus == "silkwarden" and skill.first == 2
	var heal_hp := 0
	if skill.has("heal") and not nearby.is_empty():
		var healing := Balance.direct_heal(skill,stats)
		heal_hp = Balance.Preview.roll_heal(healing)
	for ally in nearby:
		if heal_hp > 0:
			game.Life.Sustain.restore(game,ally,heal_hp,skill.id,-1,id)
		if skill.get("cleanse",false) or (not ranger and not oracle and skill.second == 2):
			ally[Conditions.STATE] = ally[Conditions.STATE].cleanse_slow()
		if skill.get("ward",false):
			var extra := Catalog.Weaver.GIFT_EXTENSION_MS if extend_ward and is_same(ally,nearby[0]) else 0
			events.grant_ward(game,ally,now+Balance.WARD_MS+extra,1,event,adapter,now)
	if not reaper and not oracle and not nearby.is_empty() and ((not ranger and skill.first == 2 and not extend_ward) or (skill.get("hit_ward",false) and not affected.is_empty())):
		nearby[0][Protection.STATE] = nearby[0][Protection.STATE].grant(now+Balance.WARD_MS,1,Time.get_ticks_msec(),game.participation.epoch())
	if not skill.has("heal") and Balance.healing_bonus(stats) > 0.0:
		game.Life.Sustain.heal(game,player,Balance.healing_bonus(stats),"class_healing_bonus")
	var follow := -1
	if weaver:
		follow = Catalog.Weaver.TREE.lane_at(skill.weaver_nodes,3)
		WeaverCombat.on_q(game,id,player,skill.weaver_nodes,contact,nearby,q_contact,field,cast_id,now)
	if ranger:
		Ranger.after_q(game,id,player,skill,cast_id,now)
	elif reaper:
		Reaper.after_q(game,id,player,skill,contact,nearby,reaper_damage,cast_id,now)
	elif oracle:
		oracle_api.after_q(game,id,player,skill,int(event.identity) if event != null else cast_id,affected,nearby,now)
	elif weaver and follow >= 0 and follow != 1:
		player.subclass_follow = {"lane":follow,"epoch":game.participation.epoch(),"life":PlayerLifecycle.generation(player)}
	if not field.is_empty():game.effect_timeline.update_native(field)
	player.contributed = true
	var timers: Cooldowns.Timers = player[Cooldowns.STATE]
	player[Cooldowns.STATE] = timers.start(Cooldowns.Q, now, Balance.cooldown(skill,stats))
	player.cast_until = now+550
	player.skill_fx_seq = int(player.get("skill_fx_seq",0))+1
	player.subclass_pose = {"until":player.cast_until,"clip":CLIPS[skill.visual],"direction":aim}
	if event != null:
		var recipients: Array[int] = []
		if adapter.recipients == "living_heal_recipients":
			for ally_id in game.players:
				if nearby.any(func(ally): return is_same(ally,game.players[ally_id])): recipients.append(ally_id)
		events.class_complete(game,event,adapter,cast.origin,Vector3(player.pos) if adapter.origin.begins_with("departure") or adapter.origin == "landing" else contact,affected,recipients,now,radius)
	load("res://spirit_replicas.gd").class_cast(game,id,skill,cast.origin,contact,radius,now,cast)
	if cast.shape in ["dash","retreat"]:load("res://spirit_affinity.gd").voluntary(game,id,cast.origin,player.pos,now)
	if game.encounter_cleared():
		game.finish_combat(id,contact)


static func pull(game: Node, target: int, center: Vector3, amount: float, now: int) -> void:
	if in_windup(game,target,now):
		return
	if target == -1 and game.tactics.boss_kind >= 0:
		return
	var point: Vector3 = game.enemy_position(target)
	var moved: Vector3 = game.battlefield.dash(point,point.move_toward(center,amount))
	if target == -1:
		game.tactics.position = moved
	else:
		game.encounter.scout(target).pos = moved
	if point.distance_squared_to(moved) > .01:
		game.emit_combat_event("enemy_release","pulled",point,moved,.4,Color("#e7dbad"),0.0,target)


static func echo(game: Node, player: Dictionary, center: Vector3, exclude: Array[int], color: Color, now: int, isolated := false) -> void:
	var nearest := -2
	var best := 2.6
	for target in game.skill_area_targets(center,best,center):
		var distance: float = center.distance_to(game.enemy_position(target))
		if not exclude.has(target) and distance <= best:
			nearest = target
			best = distance
	if nearest == -2:
		return
	var point: Vector3 = game.enemy_position(nearest)
	if isolated:
		WeaverCombat.secondary_hit(game,player,nearest,center,Catalog.Weaver.BRANCHING_HP,now)
	else:
		OutgoingHits.hit_world(game, HitSession.peer_for(player), nearest, center, {"damage":Balance.FOLLOWUP_POINTS,"knockback":-.35,"trait_secondary":true}, now)
	game.emit_combat_event("link","subclass_echo",center,point,.5,color,0.0,0)


static func follow_lane(game: Node, player: Dictionary) -> int:
	var follow: Dictionary = player.get("subclass_follow",{})
	if follow.is_empty() or follow.epoch != game.participation.epoch() or not PlayerLifecycle.matches(player,int(follow.life)) or not game.Life.alive(player):
		return -1
	return int(follow.lane)


static func follow_through(game: Node, player: Dictionary, skill: Dictionary, center: Vector3, _affected: Array[int], now: int) -> void:
	var lane := follow_lane(game,player)
	player.erase("subclass_follow")
	if lane == 2 and skill.has("weaver_nodes"):
		for ally in allies(game,center,3.0):
			ally[Protection.STATE] = ally[Protection.STATE].grant(now+Balance.WARD_MS,1,Time.get_ticks_msec(),game.participation.epoch())
		game.emit_combat_event("subclass_release","silk",center,center,.55,Color(skill.color),3.0,0,{"pattern":"ground"})


static func pose_state(player: Dictionary, now: int) -> Dictionary:
	var result: Dictionary = player.get("subclass_pose",{})
	return result if int(result.get("until",0)) == int(player.get("cast_until",0)) and now < int(result.get("until",0)) else {}
