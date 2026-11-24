extends RefCounted
## Native Oracle grants. Each named effect has one opportunity per recipient.
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const Progression = preload("res://oracle_connected_tree.gd")
const Journal = preload("res://diagnostic_journal.gd")
const STATE := "oracle_omens"
const GUIDED_DEADLINE := "oracle_guided_deadline"
const ATTACK_STARTED := "oracle_attack_started"
const FOREBODING_MS := "oracle_foreboding_ms"
const GUIDED_MS := "oracle_guided_ms"


static func token(game: Node, body: Dictionary) -> int:
	if body.has(PlayerLifecycle.STATE):
		return PlayerLifecycle.generation(body)
	var slot: int = game.encounter.scout_slot(body)
	return game.encounter.token(slot) if slot >= 0 else 0


static func grant(game: Node, source: int, focus: String, cast: int, target: int,
		body: Dictionary, omen: String, duration: int, now: int) -> void:
	var oracle: Dictionary = game.players.get(source,{})
	if not game.multiplayer.is_server() \
			or not game.Life.alive(oracle) or int(oracle.frame) != Progression.CLASS_ID:
		return
	var definition: Dictionary = Progression.OMENS[omen]
	var state: Dictionary = body.get(STATE,{})
	var sources: Dictionary = state.get(omen,{})
	var record := {"effect":omen,"type":definition.type,"trigger":definition.trigger,
		"source":source,"source_life":PlayerLifecycle.generation(oracle),"class_id":Progression.CLASS_ID,"focus":focus,"cast":cast,
		"epoch":game.participation.epoch(),"target":target,"target_token":token(game,body),
		"magnitude":definition.value,"until":now+duration}
	if int(sources.get(source,{}).get("cast",-1)) == cast:
		return
	sources[source] = record
	state[omen] = sources
	body[STATE] = state
	Journal.event("combat","oracle_omen_granted",record)


static func valid(game: Node, body: Dictionary, record: Dictionary, now: int) -> bool:
	var source: Dictionary = game.players.get(int(record.source), {})
	return int(record.epoch) == game.participation.epoch() and PlayerLifecycle.matches(source,int(record.source_life)) \
		and int(record.target_token) == token(game,body) and now < int(record.until)


static func strongest(game: Node, body: Dictionary, omen: String, now: int, source := 0) -> Dictionary:
	var strongest_grant := {}
	var sources: Dictionary = body.get(STATE,{}).get(omen,{})
	for actor in sources:
		if source != 0 and int(actor) != source:
			continue
		var record: Dictionary = sources[actor]
		if not valid(game,body,record,now):
			continue
		if strongest_grant.is_empty() or int(record.magnitude) > int(strongest_grant.magnitude) \
				or (int(record.magnitude) == int(strongest_grant.magnitude) and int(actor) < int(strongest_grant.source)):
			strongest_grant = record
	return strongest_grant


static func consume(body: Dictionary, record: Dictionary) -> int:
	if record.is_empty():
		return 0
	var state: Dictionary = body[STATE]
	# Overlapping copies offer one response. Other named effects keep their own lifetimes.
	state.erase(record.effect)
	if state.is_empty():
		body.erase(STATE)
	Journal.event("combat","oracle_omen_consumed",record)
	return int(record.magnitude)


static func indicators(game: Node, body: Dictionary, now: int) -> Dictionary:
	var result := {}
	var state: Dictionary = body.get(STATE,{})
	for omen in state.keys():
		var sources: Dictionary = state[omen]
		for actor in sources.keys():
			var record: Dictionary = sources[actor]
			if valid(game,body,record,now):
				result[omen] = maxi(int(result.get(omen,0)),int(record.until))
			else:
				sources.erase(actor)
		if sources.is_empty():
			state.erase(omen)
	if state.is_empty():
		body.erase(STATE)
	return result


static func enemy_body(game: Node, target: int) -> Dictionary:
	return game.tactics.memory if target == -1 else game.encounter.scout(target)


static func begin_attack(game: Node, actor: Dictionary, attack: Dictionary, now: int) -> void:
	if not game.multiplayer.is_server() \
			or attack.has(ATTACK_STARTED):
		return
	attack[ATTACK_STARTED] = true
	if attack.get("mode","") in ["trophy_grab","canopy_shift"]:
		return
	var body: Dictionary = game.tactics.memory if actor.get("gate_elite",false) else actor
	var curse := strongest(game,body,Progression.FOREBODING,now)
	if not curse.is_empty():
		attack[FOREBODING_MS] = consume(body,curse)


static func release_attack(body: Dictionary, attack: Dictionary, ready: int) -> int:
	var guided := int(attack.get(GUIDED_MS,0))
	var extended := ready + int(attack.get(FOREBODING_MS,0)) + guided
	if guided > 0:
		body[GUIDED_DEADLINE] = extended
	return extended


static func current_attack(game: Node, target: int, body: Dictionary) -> Dictionary:
	if target >= 0:
		return body.get("attack",{})
	var elite: Dictionary = game.encounter.leader_tactics()
	return body.get("lair_plan",body.get("phase_plan",elite.get("attack",{})))


static func guide_contact(game: Node, recipient: Dictionary, target: int, now: int) -> void:
	var portent := strongest(game,recipient,Progression.GUIDED_STRIKE,now)
	if portent.is_empty() or not game.Traits.valid_target(game,target):
		return
	var body := enemy_body(game,target)
	var winding: bool = game.tactics.winding_up if target == -1 else int(body.get("windup",0)) > 0
	if winding:
		var attack := current_attack(game,target,body)
		if attack.has(ATTACK_STARTED) and not attack.has(GUIDED_MS):
			attack[GUIDED_MS] = consume(recipient,portent)
		return
	var ready: int = game.tactics.ready_at if target == -1 else int(body.get("ready",0))
	if now < ready and int(body.get(GUIDED_DEADLINE,-1)) == ready:
		return
	ready = maxi(now,ready) + consume(recipient,portent)
	body[GUIDED_DEADLINE] = ready
	if target == -1:
		game.tactics.ready_at = ready
	else:
		body.ready = ready


static func direct_context(game: Node, direct_attack: bool) -> bool:
	return direct_attack and game.tactics.attacking_slot() >= -1


static func recover_hit(game: Node, recipient: Dictionary, now: int) -> void:
	var breath := strongest(game,recipient,Progression.SECOND_BREATH,now)
	var mercy := strongest(game,recipient,Progression.MERCY,now)
	var response := mercy if int(mercy.get("magnitude",0)) > int(breath.get("magnitude",0)) else breath
	if not response.is_empty():
		game.Life.Sustain.restore(game,recipient,consume(recipient,response),str(response.effect),-1,response.source)


static func prevent_slow(game: Node, recipient: Dictionary, now: int) -> bool:
	return consume(recipient,strongest(game,recipient,Progression.QUIET_GROUND,now)) > 0
