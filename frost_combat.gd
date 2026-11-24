extends "res://frost_balance.gd"
const Effects = preload("res://enemy_affinity_effects.gd")
const OutgoingHits = preload("res://outgoing_hits.gd")

const Catalog = preload("res://affinity_card_catalog.gd")
const CREDIT := "frost_card_credit"
const RHYTHM := "frost_card_rhythm"
const CARD_FIELDS := [CREDIT, RHYTHM]
const CARD_GRANTS := {"avalanche_unlock":{"method":"rupture_effects","capability":{"producer":"card","id":"avalanche","recipient":"enemy"}}}
const Sources = preload("res://affinity_status_source.gd")
const BRITTLE := "affinity_brittle"
const RESPONSE := "frost_response"
const COLOR := Color("#97dfff")


static func state(actor: Dictionary, now: int) -> Dictionary:
	return active_brittle(Effects.from_body(actor), now)


static func active_brittle(effects: Dictionary, now: int) -> Dictionary:
	var status: Dictionary = effects.get(BRITTLE, {})
	return status if int(status.get("expires", 0)) > now else {}


static func rooted(actor: Dictionary, now: int) -> bool:
	return int(Effects.from_body(actor).get("frost_root_until", 0)) > now


static func motion_scale(actor: Dictionary, now: int, boss := false) -> float:
	var effects := Effects.from_body(actor)
	if int(effects.get("frost_root_until", 0)) > now:
		return 0.0
	var frost := float(active_brittle(effects, now).get("slow", 0.0)) * (BOSS_SLOW_SCALE if boss else 1.0)
	return 1.0 - maxf(frost,float(effects.get("affinity_thorn_slow",0.0)))


## Capture the maximum as a numerator, with a shared denominator of 3,000.
## No per-stack rounding: round the complete rupture once, half upward.
static func clean(game: Node, target: int, now: int) -> Dictionary:
	var actor := Effects.read(game, target)
	var status := active_brittle(actor, now)
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
	if not game.multiplayer.is_server(): return
	for target in range(-1,game.encounter.scout_count()):
		if Effects.read(game,target).has(BRITTLE): clean(game,target,now)

static func ordinary_bonus(game: Node, event: RefCounted, target: int, now: int) -> int:
	if event.source!="form" or event.affinity!="frost": return 0
	return int(event.potency().get("precision_hp_per_stack",0))*clean(game,target,now).get("stacks",[]).size()


static func apply(game: Node, event: RefCounted, target: int, count: int, now: int) -> void:
	var source:=Sources.capture(event)
	if not game.multiplayer.is_server() or not Sources.current(game,source) or not game.encounter.alive(target): return
	var q: Dictionary=event.potency()
	if event.source=="catalyst" and event.native_slot in [0,1] and event.take_response("frost_rhythm_capture"):
		var p: Dictionary=game.players[event.actor]
		var all_preps: Dictionary=p.get(RHYTHM,{})
		var prep: Dictionary=all_preps.get(event.native_slot,{})
		if not prep.is_empty() and Sources.current(game,prep) and now<int(prep.until) and int(prep.activation)!=event.identity:
			event.card_potency_bonus=int(prep.hp)
			all_preps.erase(event.native_slot)
	var maximum: float=float(q.get("personal_cap_hp",q.max_shatter_hp))+float(q.get("source_shatter_hp",0))+event.card_potency_bonus
	var slow:=float(q.move_slow)+float(q.get("slow_bonus_percent",0))/100.0
	var point: Vector3=game.enemy_position(target)
	var bursts:=resolve_stacks(game,source,Sources.units(maximum),slow,q,target,count,now)
	if event.source!="catalyst" or not Sources.current(game,source): return
	if bursts>0 and event.native_slot in [0,1] and int(q.get("rhythm_shatter_hp",0))>0 and event.take_response("frost_rhythm_grant"):
		var prep:=source.duplicate(true)
		prep.merge({"hp":int(q.rhythm_shatter_hp),"until":now+int(Catalog.DEFINITIONS.shatter_rhythm.tuning.duration_ms)})
		if not game.players[event.actor].has(RHYTHM): game.players[event.actor][RHYTHM]={}
		game.players[event.actor][RHYTHM][event.native_slot]=prep
	if int(q.get("side_shatter_percent",0))>0 and event.take_response("frost_side_stack"):
		var tuning: Dictionary=Catalog.DEFINITIONS.spreading_chill.tuning
		var neighbors: Array=game.skill_area_targets(point,float(tuning.radius_m),point)
		neighbors.erase(target)
		neighbors.sort_custom(func(a,b):return game.enemy_position(a).distance_squared_to(point)<game.enemy_position(b).distance_squared_to(point) or (is_equal_approx(game.enemy_position(a).distance_squared_to(point),game.enemy_position(b).distance_squared_to(point)) and a<b))
		if not neighbors.is_empty(): resolve_stacks(game,source,Sources.units(maximum*float(q.side_shatter_percent)/100.0),slow,q,int(neighbors[0]),1,now,true)


## One group of three frozen numerators, regardless of which owner completes it.
static func resolve_stacks(game: Node, source: Dictionary, maximum_units: int, slow: float,
		effects: Dictionary, target: int, count: int, now: int, secondary := false) -> int:
	if not Sources.current(game,source) or not game.encounter.alive(target): return 0
	var actor:=Effects.edit(game,target)
	var current:=clean(game,target,now)
	var stacks: Array=current.get("stacks",[])
	for index in count:
		var contribution:=source.duplicate(true)
		contribution.merge({"slow":slow,"numerator":maximum_units,"effects":effects.duplicate(true)})
		stacks.append(contribution)
	var bursts: Array=[]
	while stacks.size()>=STACKS_TO_RUPTURE:
		bursts.append(stacks.slice(0,STACKS_TO_RUPTURE))
		stacks=stacks.slice(STACKS_TO_RUPTURE)
	if stacks.is_empty(): actor.erase(BRITTLE)
	else:
		var combined:=0.0
		for stack in stacks: combined+=float(stack.slow)
		actor[BRITTLE]={"epoch":source.epoch,"token":game.encounter.spawn_identity(target),"expires":now+BRITTLE_MS,"stacks":stacks,"slow":combined}
	for spent in bursts:
		var numerator:=0
		for stack in spent: numerator+=int(stack.numerator)
		var hp:=roundi(float(numerator)/(STACKS_TO_RUPTURE*Sources.UNITS_PER_HP))
		var point: Vector3=game.enemy_position(target)
		game.emit_combat_event("ability","frost_rupture",point,point,.55,COLOR,1.2,int(source.actor),{"label":"Brittle rupture"})
		var record: Callable=game.get_meta(&"frost_rupture_witness",Callable())
		if record.is_valid(): record.call(spent.duplicate(true),hp)
		var attribution := {"stat_affinity":"Brittle rupture","stat_weights":Sources.damage_weights(game,spent,"numerator")}
		if secondary: OutgoingHits.affinity_world(game,int(source.actor),target,hp,now,COLOR,true,attribution)
		else: OutgoingHits.affinity_and_clear(game,int(source.actor),target,hp,now,COLOR,false,attribution)
		if Sources.current(game,source): rupture_effects(game,target,point,spent,hp,now,secondary)
		if not game.encounter.alive(target): break
	return bursts.size()


static func effect_owner(stacks: Array, parameter: String) -> Dictionary:
	var candidates:={}
	for index in stacks.size():
		var row: Dictionary=stacks[index]
		var strength:=int(row.get("effects",{}).get(parameter,0))
		if strength>0:
			var candidate:=row.duplicate(true)
			candidate.strength=strength
			candidates[str(index)]=candidate
	return Sources.dominant(candidates,"strength")


static func rupture_effects(game: Node, target: int, point: Vector3, spent: Array, hp: int, now: int, propagated := false) -> void:
	var root:=effect_owner(spent,"rupture_root_ms")
	if not root.is_empty() and Sources.current(game,root) and game.encounter.alive(target):
		var actor:=Effects.edit(game,target)
		actor.frost_root_until=maxi(int(actor.get("frost_root_until",0)),now+int(root.strength))
	var wave:=effect_owner(spent,"shatterwave_percent")
	if not wave.is_empty() and Sources.current(game,wave):
		var radius:=float(Catalog.DEFINITIONS.shatterwave.tuning.radius_m)
		game.emit_combat_event("ability","shatterwave",point,point,.5,COLOR,radius,int(wave.actor),{"label":"Shatterwave"})
		for victim in game.skill_area_targets(point,radius,point):
			if not Sources.current(game,wave) or game.persistence_session.is_blocked(): break
			OutgoingHits.affinity_world(game,int(wave.actor),victim,roundi(hp*float(wave.strength)/100.0),now,COLOR,true,{"stat_affinity":"Shatterwave"})
	if propagated: return # Root and wave are finite; only another propagation is recursive.
	var avalanche:=effect_owner(spent,"avalanche_unlock")
	if not avalanche.is_empty() and Sources.current(game,avalanche):
		var radius:=float(Catalog.DEFINITIONS.avalanche.tuning.radius_m)
		for victim in game.skill_area_targets(point,radius,point):
			if victim!=target and Sources.current(game,avalanche) and not game.persistence_session.is_blocked():
				resolve_stacks(game,avalanche,int(avalanche.numerator),float(avalanche.slow),avalanche.effects,victim,1,now,true)
		preload("res://diagnostic_journal.gd").event("combat","avalanche",{"actor":avalanche.actor,"target":target,"numerator":avalanche.numerator})


static func bloom(game: Node, cast: Dictionary, now: int) -> bool:
	if not cast.grown:
		cast.grown = true
		cast.closes_at = now + BLOOM_DELAY_MS
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
		float(BLOOM_DELAY_MS) / 1000.0 if phase == "open" else .42, color, BLOOM_RADIUS, cast.owner,
		{"label":"Opening petals" if phase=="open" else "Closing petals"})
	for target in game.skill_area_targets(center, BLOOM_RADIUS, center):
		cast.affinity_action.publish(game, "core_action", phase, game.encounter.contact_key(target), now,
			{"enemy": target, "stacks": count+int(cast.affinity_action.potency().get("closing_stacks",0)) if phase=="close" else count, "opening_hp": BLOOM_OPEN_HP + int(cast.affinity_action.potency().get("opening_bonus_hp",0)) if phase == "open" else 0})


static func on_event(game: Node, event: RefCounted, kind: String, details: Dictionary, now: int) -> void:
	match kind:
		"core_action":
			var enemy: int = details.enemy
			if int(details.opening_hp) > 0:
				OutgoingHits.affinity_and_clear(game, event.actor, enemy, int(details.opening_hp), now, COLOR)
			apply(game, event, enemy, int(details.stacks), now)
		"weapon_contact":
			var extra:=0
			var q: Dictionary=event.potency()
			if int(q.get("extra_stack_milli",0))>0:
				var player: Dictionary=game.players[event.actor]
				var credit: Dictionary=player.get(CREDIT,{})
				var units:=int(credit.get("units",0)) if not credit.is_empty() and Sources.current(game,credit) else 0
				units+=int(q.extra_stack_milli)
				@warning_ignore("integer_division")
				extra=units/1000
				var next:=Sources.capture(event);next.units=units%1000;player[CREDIT]=next
			apply(game,event,int(details.enemy),1+extra,now)
		"class_contact", "incoming_hit":
			apply(game, event, int(details.enemy), 1, now)
		"actual_block":
			var center: Vector3 = details.center
			game.emit_combat_event("ability", "frost_guard", center, center, .55, COLOR, WARD_RADIUS, details.recipient, {"label":"Frost Ward"})
			for enemy in game.skill_area_targets(center, WARD_RADIUS, center):
				apply(game, event, enemy, 1, now)
		"class_action":
			var response: String = details.get("response", "")
			if response in ["recipient_frost_response", "self_frost_response"]:
				var recipients: Array = [event.actor] if response == "self_frost_response" else details.recipients
				for id in recipients:
					if game.players.has(id) and game.Life.alive(game.players[id]):
						game.players[id][RESPONSE] = {"event": event, "until": now + RESPONSE_MS}
			elif response == "brittle":
				var enemies: Array = details.enemies
				if details.get("target_scope") == "designated_area":
					enemies = game.skill_area_targets(details.center, details.radius, details.center)
				for enemy in enemies:
					apply(game, event, enemy, 1, now)


static func incoming(game: Node, recipient: Dictionary, id: int, now: int) -> void:
	var response: Dictionary = recipient.get(RESPONSE, {})
	if response.is_empty():
		return
	if now >= int(response.until):
		recipient.erase(RESPONSE)
		return
	var target: int = game.tactics.attacking_slot()
	if not game.encounter.alive(target):
		return
	recipient.erase(RESPONSE)
	response.event.publish(game, "incoming_hit", str(id), game.encounter.contact_key(target), now, {"enemy": target})
