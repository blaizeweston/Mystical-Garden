extends RefCounted
## CE04 leaf replicas. No actors, acquisition state, movement, cooldowns or resource
## costs are recreated. Native owners validate and apply every effect.
const Spirit=preload("res://spirit_affinity.gd")
const Sources=preload("res://affinity_status_source.gd")
const Catalog=preload("res://affinity_card_catalog.gd")
const Events=preload("res://combat_action_events.gd")
const Preview=preload("res://combat_balance_preview.gd")
const Protection=preload("res://player_protection.gd")
const Balance=preload("res://class_skill_balance.gd")
const CORE_EFFECTS := {"storm":{"effect":"chain","solo_enabler":true},"wood":{"effect":"bark","solo_enabler":true},"vital":{"effect":"vitality","solo_enabler":false}}
const NATIVE_MODES := ["quake","nova","siphon","ward","guard","front_guard","counter_guard"]

static func class_supported(skill: Dictionary) -> bool:
	if skill.is_empty():return false
	if skill.get("mode") in NATIVE_MODES:return true
	return skill.get("mode")=="subclass" and skill.get("visual") not in ["snare","retreat"] and (float(skill.get("damage",0))>0 or float(skill.get("heal",0))>0 or skill.get("ward",false))

static func build_supported(build: Dictionary) -> bool:
	var core: Dictionary=build.get("core",{})
	if core.get("state")=="ready" and core.get("executable",false) and CORE_EFFECTS.get(core.get("primary_affinity"),{}).get("solo_enabler",false):return true
	return build.get("class_skills",[]).any(func(adapter):return solo_skill_supported(adapter.get("native_skill",{})))

## Weaker overlapping Ward/Vital capacity alone cannot help a solo recipient.
## They remain supported supplementary copies, but cannot by themselves qualify
## a build for the card. This is the executing module's own compatibility query.
static func solo_skill_supported(skill: Dictionary) -> bool:
	return class_supported(skill) and (float(skill.get("damage",0))>0.0 or float(skill.get("heal",0))>0.0)

static func info() -> String:
	return "Wraithcast copies class opening damage/healing and native Ward protection. Core: Chain Spark, Ironbark, Vital Bloom. Copies omit movement, traps, persistent fields, Catalyst, graft and learned-node side effects. Unsupported casts keep shadows."

static func weapon(game: Node,peer: int,stats: Dictionary,form: String,now: int,duration: int) -> void:
	var player: Dictionary=game.players.get(peer,{})
	var echoes:=Spirit.take_prepared(game,player,Spirit.ECHOES,now)
	if echoes.is_empty():return
	var event: RefCounted=stats.get(Events.CONTEXT)
	if event==null:return
	var tuning: Dictionary=Catalog.DEFINITIONS.mirrorstep.tuning
	for echo: Dictionary in echoes:
		if not Sources.current(game,echo) or not game.Life.alive(player):break
		var copy:=stats.duplicate(true)
		# Capture the primary weapon roll; no extra random roll or unrelated procs.
		for key in ["native_graft_contact","ranger_ordinary","native_bonus_hp","spirit_basic_hp","thorn_momentum_hp","vital_spent_hp","vital_primary_bonus_hp","vital_attack_hp","heal_on_kill",load("res://reaper_combat.gd").STRIKE]:copy.erase(key)
		copy.merge({"trait_secondary":true,"card_secondary":true,"spirit_replica":true,"core_hit":true,
			"spirit_origin":echo.point,"affinity_hp":maxi(1,roundi(int(stats.get("preview_strike_hp",Preview.effect_hp(stats.damage)))*float(tuning.weapon_percent)/100.0))},true)
		var q: Dictionary=event.potency()
		q.replica_scale=float(tuning.form_percent)/100.0
		copy[Events.CONTEXT]=event.replicated(game,q,now)
		var direction: Vector3=player.get("aim_direction",player.facing) if player.get("mouse_aim",false) else player.facing
		var pose:={"direction":direction.normalized(),"mouse":false,"sequence":-1,"epoch":echo.epoch,"life":echo.life,"binding":echo.binding}
		if game.weapon_attacks.schedule(game.weapon_attack_world,peer,echo.point,copy,now,form,duration,-2,pose)>0:
			game.emit_combat_event("ability","mirrorstep_attack",echo.point,echo.point+direction,duration*.001,Spirit.COLOR,float(stats.reach),peer,{"label":"","clip":stats.get("weapon_variant","")})
	Journal_event("mirrorstep_released",peer,echoes.size())

static func Journal_event(kind: String,peer: int,count: int) -> void:
	load("res://diagnostic_journal.gd").event("combat",kind,{"actor":peer,"copies":count})

## One native leaf Form response per echo. These operations use the original
## family status/fragment owners and cannot create new phantoms or class procs.
static func form_contact(game: Node,event: RefCounted,details: Dictionary,now: int) -> void:
	if not event.take_response("mirror_form"):return
	var q: Dictionary=event.potency()
	var amount:=float(q.get("replica_scale",0))
	var source:=Sources.capture(event)
	var target: int=details.enemy
	var point: Vector3=details.get("point",game.enemy_position(target))
	match event.affinity:
		"frost":
			var frost=load("res://frost_combat.gd")
			frost.resolve_stacks(game,source,Sources.units((float(q.get("personal_cap_hp",q.max_shatter_hp))+float(q.get("source_shatter_hp",0)))*amount),float(q.move_slow)*amount,{},target,1,now,true)
		"fire":
			var fire=load("res://fire_combat.gd")
			fire.apply_stacks(game,source,target,maxi(1,roundi((int(fire.APPLICATION_STACKS.form)+int(q.stack_bonus))*amount)),{},now,false)
		"water":
			var water=load("res://water_combat.gd")
			q.application_scale=amount;q.reduction=float(q.reduction)*amount;q.sequence_saturation=0;q.prepared_heal_hp=0
			water.drench(game,event.replicated(game,q,now),target)
		"thorn":
			var thorn=load("res://thorn_affinity.gd")
			q.direct_bleed_percent=roundi(float(thorn.APPLICATION_FRACTION.form)*100.0*amount)
			q.opening_bleed_percent=0;q.streak_bleed_percent=0;q.rupture_percent=0
			thorn.direct_application(game,event.replicated(game,q,now),target)
		"wood":
			for key in ["impact_hp","fragment_hp","concentrated_hp","held_bark_percent"]:q[key]=float(q.get(key,0))*amount
			load("res://wood_affinity.gd").splinters(game,event.replicated(game,q,now),details,now)
		"storm":
			load("res://storm_affinity.gd").discharge(game,event.actor,target,details.get("origin",point),point,maxi(1,roundi(float(q.arc)*amount)),1,now,{"jump_range_cm":q.get("jump_range_cm",0)},source)
		"spirit":
			q.speed=float(q.speed)*amount
			load("res://spirit_affinity.gd").grant(game,event.replicated(game,q,now),event.actor)
		"vital":
			q.bonus_hp=roundi(float(q.bonus_hp)*amount);q.regen_per_second=roundi(float(q.regen_per_second)*amount)
			load("res://vital_combat.gd").grant(game,event.replicated(game,q,now),event.actor,load("res://affinity_time.gd").now(game))
		"void":
			load("res://outgoing_hits.gd").affinity_and_clear(game,event.actor,target,maxi(1,roundi(float(q.form_hp)*amount)),now,load("res://void_affinity.gd").COLOR,true)
			load("res://void_affinity.gd").queue_motion(game,event,target,details.get("origin",point),true,float(q.form_force)*amount)

static func class_cast(game: Node,peer: int,skill: Dictionary,origin: Vector3,center: Vector3,radius: float,now: int,cast: Dictionary = {}) -> void:
	if not class_supported(skill):return
	var player: Dictionary=game.players.get(peer,{})
	var shadows:=Spirit.take_prepared(game,player,Spirit.SHADOWS,now)
	if shadows.is_empty():return
	var strength:=float(Catalog.DEFINITIONS.wraithcast.tuning.effect_percent)/100.0
	var native: Dictionary=game.combat_build(player).native_stats()
	for shadow: Dictionary in shadows:
		if not Sources.current(game,shadow) or not game.Life.alive(player):break
		var at: Vector3=shadow.point
		var destination:=at
		var targets: Array=[]
		var mode: String=skill.mode
		if mode=="subclass":
			var direction: Vector3=cast.get("forward",player.facing)
			var distance:=origin.distance_to(cast.get("endpoint",center))
			var plan: Dictionary=load("res://subclass_combat.gd").plan(game,{"pos":at},game.battlefield,skill,direction,distance)
			if not plan.valid:continue
			destination=plan.center
			targets=load("res://subclass_combat.gd").targets(game,plan,skill)
		elif mode=="siphon":
			var reach:=Balance.range_limit(skill,native,float(game.Classes.DEFINITIONS[int(player.frame)].weapons[int(player.weapon_kind)].reach))
			var picked: Dictionary=load("res://class_ability_targeting.gd").pick(game,game.battlefield,at,player.facing,reach)
			if not picked.is_empty():targets=[int(picked.target)];destination=picked.point
		elif mode in ["quake","nova"]:
			destination=game.battlefield.dash(at,at+(center-origin))
			targets=game.skill_area_targets(destination,radius,at)
		var hp:=maxi(0,roundi(Preview.effect_hp(Preview.authored_amount(float(skill.get("damage",0))))*strength))
		for target in targets:
			if game.persistence_session.is_blocked() or not Sources.current(game,shadow):break
			if hp>0:load("res://outgoing_hits.gd").affinity_and_clear(game,peer,int(target),hp,now,Spirit.COLOR,true)
		var healing:=maxi(0,roundi(Preview.effect_hp(Balance.direct_heal(skill,native))*strength)) if mode=="subclass" and skill.has("heal") else 0
		var protection: bool=mode in ["ward","guard","front_guard","counter_guard"] or bool(skill.get("ward",false))
		var ward_ms:=roundi(Balance.protection_ms(skill,native)*strength) if mode!="subclass" else roundi(Balance.WARD_MS*strength)
		for recipient in game.Life.living_ids(game):
			var ally: Dictionary=game.players[recipient]
			var offset: Vector3=ally.pos-destination
			if offset.length()>maxf(.01,radius) or not game.battlefield.clear_line(destination,ally.pos):continue
			if mode in ["guard","counter_guard"] and recipient!=peer:continue
			if mode=="front_guard" and offset.length_squared()>.001 and offset.normalized().dot(player.facing)<.15:continue
			if healing>0:game.Life.Sustain.restore(game,ally,healing,"wraithcast/"+str(peer),-1,peer)
			if protection and ward_ms>0:ally[Protection.STATE]=ally[Protection.STATE].grant(now+ward_ms,maxi(1,int(skill.get("charges",1))),now,game.participation.epoch())
		game.emit_combat_event("ability","wraithcast",at,destination,.5,Spirit.COLOR,radius,peer,{"label":"Wraithcast · "+str(skill.name)})
	Journal_event("wraithcast_class",peer,shadows.size())

static func core_cast(game: Node,peer: int,line: Dictionary,now: int) -> void:
	var family: String=line.skill.affinity_family
	if not CORE_EFFECTS.has(family):return
	var player: Dictionary=game.players.get(peer,{})
	var shadows:=Spirit.take_prepared(game,player,Spirit.SHADOWS,now)
	if shadows.is_empty():return
	var event: RefCounted=line.affinity_action
	var forward: Vector3=line.get("forward",player.facing)
	var strength:=float(Catalog.DEFINITIONS.wraithcast.tuning.effect_percent)/100.0
	for shadow: Dictionary in shadows:
		if not Sources.current(game,shadow) or not game.Life.alive(player):break
		var q: Dictionary=event.potency()
		var at: Vector3=shadow.point
		var copy: RefCounted=event.replicated(game,q,now)
		match str(CORE_EFFECTS[family].effect):
			"chain":
				var target := -2
				var motion=load("res://weapon_motion.gd")
				if motion.is_projectile(str(line.skill.weapon_form)):
					var path: Dictionary=game.weapon_attack_world.projectile_path(at,forward,line.skill.weapon_form,float(line.skill.range))
					var contacts: Array=game.weapon_attack_world.swept_contacts(path.from,path.to,float(motion.profile(str(line.skill.weapon_form)).projectile_radius),-3,"")
					if not contacts.is_empty():target=contacts[0].id
				else:
					var stats: Dictionary=game.combat_build(player).basic_stats()
					stats.reach=line.skill.range
					for enemy in load("res://weapon_contact.gd").candidates(game,at):
						if load("res://weapon_contact.gd").accepts(game,enemy,at,at+Vector3(forward)*float(line.skill.range),line.skill.weapon_form,stats):target=enemy;break
				if target!= -2:load("res://storm_affinity.gd").discharge(game,peer,target,at,game.enemy_position(target),maxi(1,roundi(int(q.initial)*strength)),2+int(q.get("extra_jumps",0)),now,q,Sources.capture(copy))
			"bark":
				q.core_capacity=roundi(int(q.core_capacity)*strength);q.break_hp=roundi(int(q.break_hp)*strength)
				q.guard_fragments=0;q.retaliation_fragments=0
				copy=event.replicated(game,q,now)
				var wood=load("res://wood_affinity.gd")
				for recipient in wood.nearby(game,at,wood.CORE_RADIUS):wood.grant(game,copy,recipient,"wraith/"+str(shadow.activation))
			"vitality":
				q.bonus_hp=roundi(int(q.bonus_hp)*strength);q.regen_per_second=roundi(int(q.regen_per_second)*strength);q.bloom_attack_hp=0
				copy=event.replicated(game,q,now)
				var vital=load("res://vital_combat.gd")
				for recipient in game.Life.living_ids(game):
					if at.distance_to(game.players[recipient].pos)<=vital.CORE_RADIUS and game.battlefield.clear_line(at,game.players[recipient].pos):vital.grant(game,copy,recipient,load("res://affinity_time.gd").now(game))
		game.emit_combat_event("ability","wraithcast",at,at,.5,Spirit.COLOR,1.0,peer,{"label":"Wraithcast · "+str(line.skill.name)})
	Journal_event("wraithcast_core",peer,shadows.size())
