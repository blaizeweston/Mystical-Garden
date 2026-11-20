extends RefCounted
## Regular and summoned scout tactics and shared attack release for gate elites.
## Membership and HP stay in EncounterRoster. Damage is applied by Game.

const Enemies = preload("res://enemy_catalog.gd")
const Life = preload("res://expedition_life.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const Director = preload("res://combat_director.gd")
const Battlefield = preload("res://battlefield.gd")
const Hits = preload("res://enemy_attack_hits.gd")
const Attacks = preload("res://enemy_attack.gd")
const Variants = preload("res://enemy_variants.gd")
const EnemyBehaviors = preload("res://enemy_behaviors.gd")
const Formation = preload("res://enemy_formation.gd")

enum AttackIntent { WAIT, ATTACK }


static func tick(game: Node, delta: float, now: int) -> void:
	var started: PackedInt64Array = game.encounter.scout_tokens()
	for slot in started.size():
		if not game.encounter.alive(slot, started[slot]):
			continue
		var scout: Dictionary = game.encounter.scout(slot)
		var frost_motion := preload("res://frost_combat.gd").motion_scale(scout,now)
		if EnemyBehaviors.tick(game,scout,delta*frost_motion,now): continue
		var definition := Enemies.get_kind(int(scout.get("kind", 0)))
		var role: String = definition.role
		var mask := int(scout.get("mutations", 0))
		if scout.windup > 0:
			if now >= int(scout.windup):
				var pending: Dictionary = scout.get("attack", {})
				var due := int(scout.windup)
				preload("res://frost_combat.gd").with_attacker(game,slot,release.bind(game, scout, definition, now, pending, due))
				if not game.participation.active():
					game.expedition_transitions.finish_if_empty()
					return
			continue
		if now < int(scout.get("stagger_until",0)):
			continue
		var target := Director.target(game,scout.pos,scout,now)
		if target == 0:
			continue
		var position: Vector3 = scout.pos
		var trace := preload("res://spirit_affinity.gd").diversion(game,scout,target)
		if trace.is_finite():
			if now>=int(scout.rooted_until):
				scout.pos=Director.navigate(game,position,trace,Director.speed(game,float(definition.speed))*delta*frost_motion,int(scout.route))
			continue
		var victim: Vector3 = game.players[target].pos
		var distance := position.distance_to(victim)
		var allies: Array=Formation.allies(game, scout) if Enemies.is_support(int(scout.kind)) else []
		for ally in allies:
			if ally.engaged: scout.engaged=true
		if not scout.engaged and (distance>float(Director.config().aggro_radius) or not Attacks.attack_sight(game.battlefield,position,victim,role)):
			continue
		if not scout.get("alerted",false) and distance<=float(Director.config().aggro_radius): Director.alert(game,position);scout.alerted=true
		scout.engaged = true
		var speed := Director.speed(game,float(definition.speed))*frost_motion * (1.18 if mask & Enemies.MOBILITY else 1.0)
		if now < int(scout.get("haste_until", 0)):
			speed *= 1.22
		if mask & Enemies.JUVENILE:
			speed *= 1.15
		if Enemies.is_support(int(scout.kind)):
			if not allies.is_empty():
				Formation.follow_support(game, scout, allies, definition, speed, delta, now)
				continue
			role="desperate"
		if scout.has("command_via"):
			if now<int(scout.command_until) and now>=int(scout.rooted_until) and position.distance_to(scout.command_via)>.25 and game.battlefield.clear_line(position,scout.command_via,Battlefield.CLEARANCE):
				scout.pos=Director.navigate(game,position,scout.command_via,speed*delta,int(scout.route))
				continue
			scout.erase("command_via")
		var attack_range := (1.15 if role=="desperate" else float(definition.range)) + (0.65 if mask & Enemies.REACH else 0.0)
		if now >= int(scout.ready) and now >= int(scout.rooted_until) and frost_motion > 0.0:
			if Attacks.try_skill_approach(game,scout,victim,now):
				continue
		if mask & Enemies.MOBILITY and now >= int(scout.ready) and now >= int(scout.rooted_until) and frost_motion > 0.0:
			var landing: Vector3 = Attacks.vault_target(game, scout, victim)
			if landing.is_finite():
				Attacks.lock(game, scout, "vault", landing, now + Attacks.VAULT_WINDUP)
				continue
		if role == "skirmish" and distance < 3.8 and distance > attack_range and now >= int(scout.rooted_until):
			var tangent := (victim - position).normalized().rotated(Vector3.UP, 0.75 if int(scout.route) % 2 == 0 else -0.75)
			scout.pos = game.battlefield.slide(position, position + tangent * speed * delta)
		elif distance > attack_range or not Attacks.attack_sight(game.battlefield,position,victim,role):
			if now >= int(scout.rooted_until):
				scout.pos = Director.navigate(game,position,Director.pursuit(game,target,int(scout.route)) if not scout.ranged else victim,speed*delta,int(scout.route))
		elif now >= int(scout.ready):
			if Variants.prepare(game, scout, victim, delta * frost_motion, now):
				continue
			var observation := attack_observation(slot, started[slot], game.participation.epoch(),
				target, position, victim, role, attack_range, int(scout.ready), now, PlayerLifecycle.generation(game.players[target]))
			apply_attack_intent(game, observation, choose_attack(observation), now)

## Only values cross the decision boundary. A behavior policy gets neither Game
## nor a live actor or player dictionary.
static func attack_observation(slot: int, token: int, epoch: int, target: int,
	origin: Vector3, target_position: Vector3, role: String, reach: float, ready_at: int, now: int, target_life: int) -> Dictionary:
	var result := {
		"slot": slot, "token": token, "epoch": epoch, "target": target,
		"origin": origin, "target_position": target_position, "target_life": target_life, "role": role,
		"reach": reach, "ready_at": ready_at, "observed_at": now,
	}
	result.make_read_only()
	return result


static func choose_attack(observation: Dictionary) -> AttackIntent:
	var origin: Vector3 = observation.origin
	var victim: Vector3 = observation.target_position
	if int(observation.observed_at) < int(observation.ready_at) or origin.distance_to(victim) > float(observation.reach):
		return AttackIntent.WAIT
	return AttackIntent.ATTACK


## The host turns an allowed intent into the existing locked, telegraphed attack.
static func apply_attack_intent(game: Node, observation: Dictionary, intent: AttackIntent, now: int) -> void:
	if intent != AttackIntent.ATTACK or not game.multiplayer.is_server():
		return
	var slot := int(observation.slot)
	var token := int(observation.token)
	if slot < 0 or token <= 0 or game.participation.epoch() != int(observation.epoch) or not game.encounter.alive(slot, token):
		return
	var target := int(observation.target)
	var player: Dictionary = game.players.get(target, {})
	if not Life.alive(player) or not PlayerLifecycle.matches(player, int(observation.target_life)):
		return
	var scout: Dictionary = game.encounter.scout(slot)
	if int(scout.windup) > 0 or now < maxi(int(scout.ready), int(scout.get("stagger_until", 0))):
		return
	var position: Vector3 = scout.pos
	var victim: Vector3 = player.pos
	var definition := Enemies.get_kind(int(scout.kind))
	var role: String = definition.role
	if Enemies.is_support(int(scout.kind)):
		if not Formation.allies(game, scout).is_empty():
			return
		role = "desperate"
	var reach := (1.15 if role == "desperate" else float(definition.range))
	if int(scout.mutations) & Enemies.REACH:
		reach += 0.65
	if role != observation.role or position.distance_to(victim) > reach or not Attacks.attack_sight(game.battlefield, position, victim, role):
		return
	var aim := Attacks.aim(game, scout, role, target)
	var windup_ms := int(definition.windup) + (300 if scout.get("variant", "") == "early_decoys" else 0)
	Attacks.lock(game, scout, role, aim, now + Director.windup(game, windup_ms), {}, observation)
	scout.erase("approach_done")
	scout.erase("approach")
	scout.erase("approach_used")
	EnemyBehaviors.telegraph(game, scout, now)
	scout.repeat = 1 if int(scout.kind) == 1 and role == "volley" else 0


static func release(game: Node, scout: Dictionary, definition: Dictionary, now: int,
		expected_plan: Dictionary = {}, expected_due: int = -1) -> void:
	var attack: Dictionary
	if scout.get(Attacks.REQUIRES_SCOUT_COMMIT, false) or expected_plan.has(Attacks.SCOUT_COMMIT):
		if not game.multiplayer.is_server() or not game.participation.active():
			return
		attack = Attacks.claim_scout_attack(game.encounter, scout, game.participation.epoch(), now, expected_plan, expected_due)
		if attack.is_empty():
			return
	else:
		attack = Attacks.current(game, scout)
		scout.windup = 0
		scout.erase("attack")
	var hits := Hits.for_commitment(game, attack.get(Attacks.SCOUT_COMMIT, {}))
	var mode: String = attack.mode
	var damage := Director.Balance.scout_hit(game,definition,scout)
	var radius: float = attack.radius
	var origin: Vector3 = attack.from
	var target_point: Vector3 = attack.to
	scout.ready = now + roundi((Director.recovery(game,int(definition.recovery))+int(scout.recovery))*(.82 if now<int(scout.get("haste_until",0)) else 1.0))
	scout.recovery = 0
	var recovery_body: Dictionary=game.tactics.memory if scout.get("gate_elite",false) else scout
	scout.ready = preload("res://oracle_omens.gd").release_attack(recovery_body,attack,int(scout.ready)+int(attack.get("recovery_bonus",0)))
	if mode=="shepherd" and EnemyBehaviors.resolve(game,scout,attack,now,hits): return
	if mode=="lure":
		var anchor: Vector3=attack.anchor
		if not game.battlefield.clear_line(anchor,target_point): return
		preload("res://event_audio.gd").enemy(game,attack,true)
		var feedback = preload("res://enemy_move_feedback.gd")
		if attack.get("learned",false):feedback.release(game,"burst",anchor,target_point,radius)
		hits.lure(anchor,target_point,radius,now,damage,func(id: int, life: int) -> void:
			var p: Dictionary=game.players.get(id,{})
			if not PlayerLifecycle.matches(p,life):
				return
			var before_pull: Vector3=p.pos
			p.pos=game.battlefield.dash(p.pos,p.pos.move_toward(anchor,.9))
			if attack.get("learned",false) and not before_pull.is_equal_approx(p.pos):
				feedback.release(game,"pulled",before_pull,p.pos,0.0,Color("#bad2ee")))
		return
	if mode=="chant":
		if EnemyBehaviors.resolve(game,scout,attack,now,hits): return
		preload("res://event_audio.gd").enemy(game,attack,true)
		if game.enemy_health()>0 and not Enemies.is_support(game.enemy_kind) and game.tactics.position.distance_to(origin)<=radius and game.battlefield.clear_line(origin,game.tactics.position): game.tactics.haste_until=now+3500
		for slot in game.encounter.scout_count():
			var other: Dictionary = game.encounter.scout(slot)
			if game.encounter.alive(slot) and not Enemies.is_support(int(other.get("kind",0))) and other.pos.distance_to(origin)<=radius and game.battlefield.clear_line(origin,other.pos): other.haste_until=now+3500
		return
	if mode in ["charge","pounce","vault"]:
		var frost = preload("res://frost_combat.gd")
		var frost_body: Dictionary = game.tactics.memory if game.get_meta(frost.ATTACKER,-2)==-1 else scout
		if frost.rooted(frost_body,now):
			target_point = scout.pos
			attack.to = target_point
			attack.via = target_point if Vector3(attack.get("via",Vector3.INF)).is_finite() else Vector3.INF
		var learned: bool=attack.get("learned_move",false)
		var feedback = preload("res://enemy_move_feedback.gd")
		if not Attacks.landing_is_clear(game,scout,attack,now):
			if learned:feedback.stopped(game,scout.pos)
			return
		preload("res://event_audio.gd").enemy(game,attack,true)
		if learned:feedback.movement(game,attack,Attacks.CONTACT_PADDING)
		scout.pos=target_point
		if attack.get("variant")=="antler_hook":
			hits.bent_charge(attack.from,attack.via,attack.to,attack.width,attack.radius,now,damage,Attacks.CONTACT_PADDING)
			return
		if mode=="charge" and int(scout.kind)!=13:
			hits.charge(origin,target_point,attack.width,radius,now,damage)
			if hits.source_is_current():
				EnemyBehaviors.resolve(game,scout,attack,now,hits)
			return
		hits.area(target_point,radius,now,damage)
		return
	if EnemyBehaviors.resolve(game,scout,attack,now,hits): return
	if float(attack.span)>0.0:
		preload("res://event_audio.gd").enemy(game,attack,true)
		if attack.get("learned",false):
			var feedback = preload("res://enemy_move_feedback.gd")
			feedback.release(game,"sector",origin,attack.face,radius,feedback.THREAT,0.0,attack.span)
		hits.sector(origin,attack.face,radius,attack.span,now,damage)
		return
	var directed := mode == "volley"
	if (not directed and not scout.ranged) or Attacks.attack_sight(game.battlefield,origin,target_point,mode):
		preload("res://event_audio.gd").enemy(game,attack,true)
		if attack.get("variant")=="echo_bud":
			preload("res://enemy_move_feedback.gd").release(game,"burst",origin,target_point,radius,Color("#b895ed"))
		elif int(attack.pulse)>0:
			game.emit_combat_event("swing","pulse",origin,target_point,.35,Color("#b895ed"),radius,int(attack.pulse))
		hits.area(target_point,radius,now,damage,1600 if mode=="snare" else 0,true,directed)
		if hits.source_is_current():
			preload("res://glasscap_feint.gd").release(game,scout,now)
	if hits.source_is_current() and int(scout.get("repeat", 0)) > 0 and not attack.get("learned",false):
		var next_due := now + (1000 if attack.variant=="late_pulse" else 500)
		if Attacks.rearm_scout_attack(game.encounter, scout, attack, game.participation.epoch(), next_due):
			scout.repeat -= 1
			attack.pulse+=1
			preload("res://event_audio.gd").enemy(game,attack,false)
