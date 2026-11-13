extends RefCounted

const Catalog = preload("res://subclass_catalog.gd")
const Mark = preload("res://core_strike_mark.gd")
const Balance = preload("res://class_skill_balance.gd")
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
			endpoint = field.dash(origin,origin+forward*reach)
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


static func targets(game: Node, cast: Dictionary, skill: Dictionary, card: Dictionary) -> Array[int]:
	if cast.shape == "line":
		return game.skill_line_targets(cast.origin,cast.forward,cast.origin.distance_to(cast.endpoint),cast.width,int(skill.limit))
	var result: Array[int] = game.skill_area_targets(cast.center,cast.radius,cast.origin)
	if cast.shape == "target":
		result.erase(cast.target)
		result.sort_custom(func(a,b): return cast.center.distance_squared_to(game.enemy_position(a)) < cast.center.distance_squared_to(game.enemy_position(b)))
		result.push_front(cast.target)
		result.resize(mini(result.size(),int(skill.limit)+int(card.get("extra",0))))
	elif cast.shape == "cone":
		for target in result.duplicate():
			var offset: Vector3 = game.enemy_position(target)-Vector3(cast.origin)
			if offset.length_squared() > .0001 and offset.normalized().dot(cast.forward) < cos(float(cast.span)*.5):
				result.erase(target)
	return result


static func in_windup(game: Node, target: int, now: int) -> bool:
	return game.enemy_winding_up if target == -1 else int(game.scouts[target].get("windup",0)) > now


static func allies(game: Node, center: Vector3, radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ally in game.players.values():
		if game.Life.alive(ally) and center.distance_to(ally.pos) <= radius and game.battlefield.clear_line(center,ally.pos):
			result.append(ally)
	result.sort_custom(func(a,b): return float(a.hp)/float(a.max_hp) < float(b.hp)/float(b.max_hp))
	return result


static func cast_skill(game: Node, id: int, player: Dictionary, skill: Dictionary, stats: Dictionary, now: int) -> void:
	var aim: Vector3 = player.get("class_aim",player.get("facing",Vector3.FORWARD))
	if not player.has("class_aim"):
		var chosen: int = game.select_attack_target(player,float(skill.get("range",4.0)))
		if chosen != -2:
			var offset: Vector3 = game.enemy_position(chosen)-Vector3(player.pos)
			if offset.length_squared() > .001:
				aim = offset.normalized()
	var cast := plan(game,player,game.battlefield,skill,aim,float(player.get("class_aim_distance",-1.0)))
	if not cast.valid:
		game.tell(id,"No clear target for %s." % skill.name)
		return
	var card: Dictionary = skill.card.effect if int(player.get("run_upgrades",{}).get(skill.card.id,0)) > 0 else {}
	var leaves_snare: bool = skill.visual in ["snare", "retreat"]
	var affected: Array[int] = []
	if not leaves_snare:
		affected = targets(game,cast,skill,card)
	var release_end: Vector3 = cast.endpoint if cast.shape in ["line","dash","retreat","cone"] else cast.center
	player.facing = aim
	player.aim_direction = aim
	if cast.shape in ["dash","retreat"]:
		player.pos = cast.endpoint
		player.velocity = Vector3.ZERO
	game.emit_combat_event("subclass_release",skill.visual,cast.origin,release_end,.67,Color(skill.color),cast.radius,id,
		{"pattern":cast.shape,"width":cast.width,"span":cast.span,"owner":id,"clip":CLIPS[skill.visual],"label":skill.name})
	var cast_id: int = game.combat_event_serial
	var bind := Balance.subclass_bind(skill,card)
	if leaves_snare:
		var trap := skill.duplicate()
		trap.bind = bind
		game.Traits.place_snare(game,player,cast.center,trap,stats,now)
	var marks := int(skill.get("marks",0)) + int(card.get("marks",0))
	var kills := 0
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
		var damage := Balance.Preview.authored_amount(float(skill.get("damage",0)) + (float(skill.get("punish",0))+float(card.get("punish",0)) if windup else 0.0))
		var rewardable: bool = target == -1 or not game.scouts[target].get("summoned",false)
		if damage > 0:
			var hit := stats.duplicate()
			hit.damage = damage
			hit.knockback = -.35
			var before: int = game.enemy_hp if target==-1 else int(game.scouts[target].hp)
			game.apply_weapon_hit(player,target,cast.center,hit,now)
			if Balance.Preview.enabled and rewardable:
				var after: int = game.enemy_hp if target==-1 else int(game.scouts[target].hp)
				drain_contacts += int(after<before)
		if not game.Traits.valid_target(game,target):
			kills += int(rewardable)
			continue
		if bind > 0:
			preload("res://combat_status.gd").root(game,target,now+bind+int(stats.get("skill_duration",0)))
		if skill.has("pull"):
			pull(game,target,cast.center,float(skill.pull),now)
		if marks > 0 and Mark.active(game,game.Traits.target_state(game,target),now).is_empty():
			Mark.place(game,id,target,{"id":cast_id,"life":player.get("lost_health",0),
				"skill":{"id":skill.id,"mark_ms":2700,"mark_damage":Balance.MARK_POINTS,"color":skill.color,"subclass_mark":true}},now)
			marks -= 1
	if not affected.is_empty() and skill.second == 0:
		echo(game,player,contact,affected,Color(skill.color),now)
	var drain_count := drain_contacts if Balance.Preview.enabled else affected.size()
	if skill.get("leech",false) and drain_count>0:
		game.Life.Sustain.heal(game,player,Balance.drain_amount(skill,drain_count),skill.id,Balance.Preview.HEAL_DRAIN_SPREAD_HP)
	if card.get("grave",false) and kills > 0:
		player.grave_charges = mini(3,int(player.get("grave_charges",0))+1)
	var field_duration := Balance.duration(skill,stats) if Balance.Preview.enabled else int(skill.get("duration",0))
	if skill.has("field"):
		game.Traits.zone(game,player,skill.field,cast.center,cast.radius,field_duration,Balance.field_power(skill),now)
	if card.get("thorn_patch",false):
		game.Traits.zone(game,player,"cinder",cast.center,cast.radius,field_duration,Balance.FOLLOWUP_POINTS,now)
	var nearby := allies(game,contact,radius)
	var heal_hp := 0
	if skill.has("heal") and not nearby.is_empty():
		var healing := Balance.direct_heal(skill,stats) if Balance.Preview.enabled else float(skill.heal)
		heal_hp = Balance.Preview.roll_heal(healing)
	for ally in nearby:
		if heal_hp > 0:
			game.Life.Sustain.restore(game,ally,heal_hp,skill.id)
		if skill.get("cleanse",false) or card.get("cleanse",false) or skill.second == 2:
			ally.slow_until = 0
		if skill.get("ward",false) or card.get("ward",false) or (card.get("party_hit_ward",false) and not affected.is_empty()):
			game.grant_guard(ally,now+Balance.WARD_MS,1)
	if not nearby.is_empty() and (skill.first == 2 or (skill.get("hit_ward",false) and not affected.is_empty())):
		game.grant_guard(nearby[0],now+Balance.WARD_MS,1)
	if card.get("landing_ward",false):
		game.grant_guard(player,now+Balance.WARD_MS,1)
	if Balance.Preview.enabled and not skill.has("heal") and Balance.healing_bonus(stats) > 0.0:
		game.Life.Sustain.heal(game,player,Balance.healing_bonus(stats),"class_healing_bonus")
	var follow := Catalog.lane_at(player.character,int(player.frame),3)
	if follow >= 0:
		player.subclass_follow = {"lane":follow,"epoch":game.combat_epoch,"life":player.get("lost_health",0)}
	player.contributed = true
	player.skill_at = now + Balance.cooldown(skill,stats)
	player.cast_until = now+550
	player.skill_fx_seq = int(player.get("skill_fx_seq",0))+1
	player.subclass_pose = {"until":player.cast_until,"clip":CLIPS[skill.visual],"direction":aim}
	if game.encounter_cleared():
		game.finish_combat(id,contact)


static func pull(game: Node, target: int, center: Vector3, amount: float, now: int) -> void:
	if in_windup(game,target,now):
		return
	if target == -1 and game.boss_kind >= 0:
		return
	var point: Vector3 = game.enemy_position(target)
	var moved: Vector3 = game.battlefield.dash(point,point.move_toward(center,amount))
	if target == -1:
		game.enemy_pos = moved
	else:
		game.scouts[target].pos = moved
	if point.distance_squared_to(moved) > .01:
		game.emit_combat_event("enemy_release","pulled",point,moved,.4,Color("#e7dbad"),0.0,target)


static func echo(game: Node, player: Dictionary, center: Vector3, exclude: Array[int], color: Color, now: int) -> void:
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
	game.apply_weapon_hit(player,nearest,center,{"damage":Balance.FOLLOWUP_POINTS,"knockback":-.35,"trait_secondary":true},now)
	game.emit_combat_event("link","subclass_echo",center,point,.5,color,0.0,0)


static func follow_lane(game: Node, player: Dictionary) -> int:
	var follow: Dictionary = player.get("subclass_follow",{})
	if follow.is_empty() or follow.epoch != game.combat_epoch or follow.life != player.get("lost_health",0) or not game.Life.alive(player):
		return -1
	return int(follow.lane)


static func follow_through(game: Node, player: Dictionary, skill: Dictionary, center: Vector3, affected: Array[int], now: int) -> void:
	var lane := follow_lane(game,player)
	player.erase("subclass_follow")
	match lane:
		0:
			echo(game,player,center,affected,Color(skill.color),now)
		1:
			player.skill_two_at = maxi(now+1800,int(player.skill_two_at)-1700)
		2:
			for ally in allies(game,center,3.0):
				game.grant_guard(ally,now+Balance.WARD_MS,1)
			game.emit_combat_event("subclass_release","silk",center,center,.55,Color(skill.color),3.0,0,{"pattern":"ground"})


static func pose_state(player: Dictionary, now: int) -> Dictionary:
	var result: Dictionary = player.get("subclass_pose",{})
	return result if int(result.get("until",0)) == int(player.get("cast_until",0)) and now < int(result.get("until",0)) else {}
