extends RefCounted
const OutgoingHits = preload("res://outgoing_hits.gd")

const Balance = preload("res://frost_balance.gd")
const Sources = preload("res://affinity_status_source.gd")
const BRITTLE := "affinity_brittle"
const RESPONSE := "frost_response"
const ATTACKER := &"frost_attacker"
const COLOR := Color("#97dfff")


static func valid_target(game: Node, target: int) -> bool:
	return game.encounter.alive(target)


static func body(game: Node, target: int) -> Dictionary:
	return game.tactics.memory if target == -1 else game.encounter.scout(target)


static func target_token(game: Node, target: int) -> String:
	return "leader" if target == -1 else str(game.encounter.token(target))


static func state(actor: Dictionary, now: int) -> Dictionary:
	var status: Dictionary = actor.get(BRITTLE, {})
	return status if int(status.get("expires", 0)) > now else {}


static func rooted(actor: Dictionary, now: int) -> bool:
	return int(actor.get("frost_root_until", 0)) > now


static func motion_scale(actor: Dictionary, now: int, boss := false) -> float:
	if rooted(actor, now):
		return 0.0
	var frost := float(state(actor, now).get("slow", 0.0)) * (Balance.BOSS_SLOW_SCALE if boss else 1.0)
	return 1.0 - maxf(frost,float(actor.get("affinity_thorn_slow",0.0)))


static func damage(game: Node, actor: int, target: int, hp: int, now: int, color := COLOR) -> void:
	# Use the same native damage, death, drops and encounter settlement path.
	# An affinity hit contributes no legacy on-hit traits or attack delay.
	# A previously granted effect keeps its author even after disconnect.
	OutgoingHits.affinity_world(game, actor, target, hp, now, color)
	if game.encounter_cleared():
		game.finish_combat(actor if game.players.has(actor) else game.HOST, game.enemy_position(target))


## Capture the maximum as a numerator, with a shared denominator of 3,000.
## No per-stack rounding: round the complete rupture once, half upward.
static func clean(game: Node, target: int, now: int) -> Dictionary:
	var actor := body(game,target)
	var status := state(actor,now)
	if status.is_empty() or not Sources.target_current(game,target,status):
		actor.erase(BRITTLE)
		return {}
	status.stacks=status.stacks.filter(func(stack):return Sources.current(game,stack))
	if status.stacks.is_empty():
		actor.erase(BRITTLE)
		return {}
	status.slow=0.0
	for stack in status.stacks: status.slow+=float(stack.slow)
	return status

static func tick(game: Node, now: int) -> void:
	for target in range(-1,game.encounter.scout_count()):
		if body(game,target).has(BRITTLE): clean(game,target,now)

static func apply(game: Node, event: RefCounted, target: int, count: int, now: int) -> void:
	var source := Sources.capture(event)
	if not game.multiplayer.is_server() or not Sources.current(game,source) or not valid_target(game,target): return
	var actor := body(game,target)
	var current := clean(game,target,now)
	var stacks: Array = current.get("stacks",[])
	var potency: Dictionary = event.potency()
	var maximum := float(potency.get("personal_cap_hp",potency.max_shatter_hp))
	for index in count:
		var contribution := source.duplicate(true)
		contribution.slow=potency.move_slow
		contribution.numerator=Sources.units(maximum)
		stacks.append(contribution)
	var bursts: Array=[]
	while stacks.size()>=Balance.STACKS_TO_RUPTURE:
		bursts.append(stacks.slice(0,Balance.STACKS_TO_RUPTURE))
		stacks=stacks.slice(Balance.STACKS_TO_RUPTURE)
	if stacks.is_empty(): actor.erase(BRITTLE)
	else:
		var slow:=0.0
		for stack in stacks: slow+=float(stack.slow)
		actor[BRITTLE]={"epoch":event.epoch,"token":game.encounter.spawn_identity(target),
			"expires":now+Balance.BRITTLE_MS,"stacks":stacks,"slow":slow}
	for spent in bursts:
		var numerator:=0
		for stack in spent: numerator+=int(stack.numerator)
		var hp:=roundi(float(numerator)/(Balance.STACKS_TO_RUPTURE*Sources.UNITS_PER_HP))
		var point: Vector3=game.enemy_position(target)
		game.emit_combat_event("ability","frost_rupture",point,point,.55,COLOR,1.2,event.actor,{"label":"Brittle rupture"})
		var record: Callable=game.get_meta(&"frost_rupture_witness",Callable())
		if record.is_valid(): record.call(spent.duplicate(true),hp)
		damage(game,event.actor,target,hp,now)
		if not valid_target(game,target): break


static func bloom(game: Node, cast: Dictionary, now: int) -> bool:
	if not cast.grown:
		cast.grown = true
		cast.closes_at = now + Balance.BLOOM_DELAY_MS
		cast.ends_at = int(cast.closes_at)
		bloom_phase(game, cast, "open", 2, now)
		return false
	if now < int(cast.closes_at):
		return false
	bloom_phase(game, cast, "close", 1, now)
	return true


static func bloom_phase(game: Node, cast: Dictionary, phase: String, count: int, now: int) -> void:
	var center: Vector3 = cast.center
	var color := COLOR if phase == "open" else Color("#d9f6ff")
	game.emit_combat_event("ability", "frost_" + phase, center, center,
		float(Balance.BLOOM_DELAY_MS) / 1000.0 if phase == "open" else .42, color, Balance.BLOOM_RADIUS, cast.owner,
		{"label":"Opening petals" if phase=="open" else "Closing petals"})
	for target in game.skill_area_targets(center, Balance.BLOOM_RADIUS, center):
		cast.affinity_action.publish(game, "core_action", phase, target_token(game, target), now,
			{"enemy": target, "stacks": count, "opening_hp": Balance.BLOOM_OPEN_HP + int(cast.affinity_action.potency().get("opening_bonus_hp",0)) if phase == "open" else 0})


static func on_event(game: Node, event: RefCounted, kind: String, details: Dictionary, now: int) -> void:
	match kind:
		"core_action":
			var enemy: int = details.enemy
			if int(details.opening_hp) > 0:
				damage(game, event.actor, enemy, int(details.opening_hp), now)
			apply(game, event, enemy, int(details.stacks), now)
		"weapon_contact", "class_contact", "incoming_hit":
			apply(game, event, int(details.enemy), 1, now)
		"actual_block":
			var center: Vector3 = details.center
			game.emit_combat_event("ability", "frost_guard", center, center, .55, COLOR, Balance.WARD_RADIUS, details.recipient, {"label":"Frost Ward"})
			for enemy in game.skill_area_targets(center, Balance.WARD_RADIUS, center):
				apply(game, event, enemy, 1, now)
		"class_action":
			var response: String = details.get("response", "")
			if response in ["recipient_frost_response", "self_frost_response"]:
				var recipients: Array = [event.actor] if response == "self_frost_response" else details.recipients
				for id in recipients:
					if game.players.has(id) and game.Life.alive(game.players[id]):
						game.players[id][RESPONSE] = {"event": event, "until": now + Balance.RESPONSE_MS}
			elif response == "brittle":
				var enemies: Array = details.enemies
				if details.get("target_scope") == "designated_area":
					enemies = game.skill_area_targets(details.center, details.radius, details.center)
				for enemy in enemies:
					apply(game, event, enemy, 1, now)


static func with_attacker(game: Node, attacker: int, attack: Callable) -> void:
	var previous: int = game.get_meta(ATTACKER, -2)
	game.set_meta(ATTACKER, attacker)
	attack.call()
	game.set_meta(ATTACKER, previous)


static func incoming(game: Node, recipient: Dictionary, id: int, now: int) -> void:
	var response: Dictionary = recipient.get(RESPONSE, {})
	if response.is_empty():
		return
	if now >= int(response.until):
		recipient.erase(RESPONSE)
		return
	var target: int = game.get_meta(ATTACKER, -2)
	if not valid_target(game, target):
		return
	recipient.erase(RESPONSE)
	response.event.publish(game, "incoming_hit", str(id), target_token(game, target), now, {"enemy": target})


static func stock_test_garden(game: Node) -> String:
	var ruleset = load("res://combat_ruleset.gd")
	if not preload("res://assets/terrain_m02/experimental/experiment_mode.gd").verified() or not game.multiplayer.is_server() or game.participation.active() or not game.persistence_session.is_guarded():
		return "Affinity supplies are available to the host in the isolated affinity Garden."
	return game.run_heart_save(func():
		for part in game.Parts.DEFINITIONS.size():
			var material := preload("res://plant_affinities.gd").for_part(part)
			if not ruleset.FAMILIES.has(material.get("primary_affinity", "")):
				continue
			game.progress.add_parts(part, maxi(0, 12 - game.progress.part_count(part)))
		return "Test Garden stocked with supported ordinary and refined affinity materials.")
