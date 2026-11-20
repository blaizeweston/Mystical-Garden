extends RefCounted

const Sources = preload("res://affinity_status_source.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")

const Actors = preload("res://frost_combat.gd")
const Clock = preload("res://affinity_time.gd")
const Footprint = preload("res://core_footprint.gd")
const BURNING := "affinity_burning"
const RESPONSE := "affinity_ember_response"
const COLOR := Color("#f29b57")
const RADIUS := 2.4
const RESPONSE_MS := 4500
const BURN_MS := 3000
const TICK_MS := 250
const TICK_HP_PER_STACK := .125
const DECAY_MS := 500
const DECAY_STACKS := 8
const STACK_LIMIT := 96
const FIELD_APPLICATION_MS := 750
const APPLICATION_STACKS := {"core":16,"form":8,"catalyst":12}
const FIELD_MS := 3200
const HALF_LENGTH := 2.15
const WIDTH := .68
const COOLDOWN_MS := 8000
const QUALITY := {
	"ordinary": {"stack_bonus": 0, "impact_hp": 8, "burst_hp": 5},
	"refined": {"stack_bonus": 4, "impact_hp": 12, "burst_hp": 8},
}
const VERSION_DATA := [RADIUS, RESPONSE_MS, BURN_MS, TICK_MS, TICK_HP_PER_STACK, DECAY_MS, DECAY_STACKS, STACK_LIMIT, FIELD_APPLICATION_MS, APPLICATION_STACKS, FIELD_MS, HALF_LENGTH, WIDTH, COOLDOWN_MS, QUALITY]


static func description(slot: String, quality: String) -> String:
	var p: Dictionary = QUALITY[quality]
	var line: String = {
		"core": "Ember Wake · %.1f s burning-root trail. %d HP on first contact per enemy, then maintains Burning. %.1f s cooldown." % [FIELD_MS / 1000.0, p.impact_hp, COOLDOWN_MS / 1000.0],
		"form": "Burning Strikes · Direct weapon contacts ignite the enemies actually hit.",
		"catalyst": "Fire Catalyst · Offensive class skills ignite. An actual block bursts for %d HP and ignites within %.1f m. Mapped healing and movement can grant a %.1f s single-use response to an unblocked enemy hit you survive." % [p.burst_hp, RADIUS, RESPONSE_MS / 1000.0],
	}[slot]
	return line + "\nApplies %d shared Burning stacks. Each stack deals %.3f damage every %.2f s; fractional damage carries between ticks. %d stacks decay each %.1f s (limit %d). A contributor expires %.1f s after its last application. The field adds stacks at most once per %.2f s per enemy." % [
		APPLICATION_STACKS[slot]+int(p.stack_bonus),TICK_HP_PER_STACK,TICK_MS/1000.0,DECAY_STACKS,DECAY_MS/1000.0,STACK_LIMIT,BURN_MS/1000.0,FIELD_APPLICATION_MS/1000.0]


static func count(status: Dictionary) -> int:
	var total:=0
	for row in status.get("contributors",{}).values(): total+=int(row.stacks)
	return total

static func prune(game: Node, status: Dictionary, at: int) -> void:
	for key in status.contributors.keys():
		var row: Dictionary=status.contributors[key]
		if int(row.until)<=at or int(row.stacks)<=0 or not Sources.current(game,row): status.contributors.erase(key)

static func deal_tick(game: Node, target: int, status: Dictionary, now: int) -> void:
	var owner := Sources.dominant(status.contributors,"stacks")
	var hp := Sources.whole_tick(status,count(status)*Sources.units(TICK_HP_PER_STACK))
	if hp>0 and not owner.is_empty(): Actors.damage(game,int(owner.actor),target,hp,now,COLOR)

static func advance(game: Node, target: int, elapsed: int, now: int) -> Dictionary:
	var actor := Actors.body(game,target)
	var status: Dictionary=actor.get(BURNING,{})
	if status.is_empty(): return {}
	if not Sources.target_current(game,target,status):
		actor.erase(BURNING)
		return {}
	# Apply decay before a tick at the same instant. Decay removes the oldest
	# contributing activation first, with peer-ID ties. No source gets its own clock.
	while mini(int(status.next),int(status.decay))<=elapsed:
		var at := mini(int(status.next),int(status.decay))
		prune(game,status,at)
		if status.contributors.is_empty(): break
		if int(status.decay)<=int(status.next):
			status.decay+=DECAY_MS
			var remaining := DECAY_STACKS
			while remaining>0 and not status.contributors.is_empty():
				var oldest := {}
				var oldest_key := ""
				for key in status.contributors:
					var row: Dictionary=status.contributors[key]
					if oldest.is_empty() or int(row.activation)<int(oldest.activation) or (row.activation==oldest.activation and int(row.actor)<int(oldest.actor)):
						oldest=row;oldest_key=key
				var removed := mini(remaining,int(oldest.stacks))
				oldest.stacks-=removed;remaining-=removed
				if int(oldest.stacks)==0: status.contributors.erase(oldest_key)
		else:
			status.next+=TICK_MS
			deal_tick(game,target,status,now)
			if game.persistence_session.is_blocked() or not Sources.target_current(game,target,status): return {}
	prune(game,status,elapsed)
	if status.contributors.is_empty():
		actor.erase(BURNING)
		return {}
	return status

static func ignite(game: Node, event: RefCounted, target: int, now: int) -> void:
	var source := Sources.capture(event)
	if not game.multiplayer.is_server() or not Sources.current(game,source) or game.persistence_session.is_blocked() or not Actors.valid_target(game,target): return
	var elapsed := Clock.now(game)
	var status := advance(game,target,elapsed,now)
	if game.persistence_session.is_blocked() or not Actors.valid_target(game,target): return
	var fresh := status.is_empty()
	if fresh:
		status={"epoch":event.epoch,"token":game.encounter.spawn_identity(target),"contributors":{},
			"next":elapsed+TICK_MS,"decay":elapsed+DECAY_MS,"remainder":0}
	var offered:=int(APPLICATION_STACKS[event.source])+int(event.potency().stack_bonus)
	var admitted:=clampi(offered,0,STACK_LIMIT-count(status))
	var key := Sources.key(source)
	if admitted==0:
		if status.contributors.has(key): status.contributors[key].until=elapsed+BURN_MS
		return
	var row: Dictionary=status.contributors.get(key,source)
	row.stacks=int(row.get("stacks",0))+admitted
	row.until=elapsed+BURN_MS
	status.contributors[key]=row
	Actors.body(game,target)[BURNING]=status
	if fresh: deal_tick(game,target,status,now)

static func tick(game: Node, elapsed: int, now: int) -> void:
	if not game.multiplayer.is_server(): return
	var epoch: int=game.participation.epoch()
	for target in range(-1,game.encounter.scout_count()):
		if game.participation.epoch()!=epoch or game.persistence_session.is_blocked(): return
		if Actors.body(game,target).has(BURNING): advance(game,target,elapsed,now)


static func field(game: Node, cast: Dictionary, now: int) -> bool:
	var elapsed := Clock.now(game)
	if not cast.grown:
		cast.grown = true
		cast.field_until = elapsed + FIELD_MS
		cast.shapes = Footprint.build(game.battlefield, cast, cast.cast_origin)
		cast.next_maintain = elapsed
		cast.stack_ready = {}
		for shape in cast.shapes:
			game.emit_combat_event("ability", "ember_trail", shape.from, shape.to, FIELD_MS / 1000.0, COLOR, WIDTH, cast.owner,
				{"label": "Ember Wake", "core_shapes": Footprint.encode(cast.shapes)})
	if elapsed >= int(cast.field_until):
		return true
	if elapsed < int(cast.next_maintain):
		return false
	cast.next_maintain = elapsed + 80
	for target in Footprint.targets(game, cast.shapes, cast.center):
		var first: bool = cast.affinity_action.publish(game, "core_action", "impact", Actors.target_token(game, target), now, {"enemy": target})
		var token := Actors.target_token(game,target)
		if first:
			cast.stack_ready[token]=elapsed+FIELD_APPLICATION_MS
		elif elapsed>=int(cast.stack_ready.get(token,0)):
			cast.stack_ready[token]=elapsed+FIELD_APPLICATION_MS
			ignite(game,cast.affinity_action,target,now)
	return false


static func on_event(game: Node, event: RefCounted, kind: String, details: Dictionary, now: int) -> void:
	match kind:
		"core_action":
			Actors.damage(game, event.actor, int(details.enemy), int(event.potency().impact_hp), now, COLOR)
			ignite(game, event, int(details.enemy), now)
		"weapon_contact", "class_contact", "incoming_hit":
			ignite(game, event, int(details.enemy), now)
		"actual_block":
			var center: Vector3 = details.center
			game.emit_combat_event("ability", "ember_guard", center, center, .55, COLOR, RADIUS, details.recipient, {"label": "Ember Ward"})
			for enemy in game.skill_area_targets(center, RADIUS, center):
				Actors.damage(game, event.actor, enemy, int(event.potency().burst_hp), now, COLOR)
				ignite(game, event, enemy, now)
		"class_action":
			var response: String = details.get("response", "")
			match response:
				"recipient_ember_response", "self_ember_response":
					var recipients: Array = [event.actor] if response == "self_ember_response" else details.recipients
					for id in recipients:
						if game.players.has(id) and game.Life.alive(game.players[id]):
							game.players[id][RESPONSE] = {"event": event, "until": Clock.now(game) + RESPONSE_MS}
				"burn":
					var enemies: Array = details.enemies
					if details.get("target_scope") == "designated_area":
						enemies = game.skill_area_targets(details.center, details.radius, details.center)
					for enemy in enemies:
						ignite(game, event, enemy, now)


static func incoming(game: Node, recipient: Dictionary, id: int, now: int) -> void:
	var response: Dictionary = recipient.get(RESPONSE, {})
	if response.is_empty():
		return
	if Clock.now(game) >= int(response.until) or response.event.epoch != game.participation.epoch():
		recipient.erase(RESPONSE)
		return
	var target: int = game.get_meta(Actors.ATTACKER, -2)
	if not Actors.valid_target(game, target):
		return
	recipient.erase(RESPONSE)
	response.event.publish(game, "incoming_hit", str(id), Actors.target_token(game, target), now, {"enemy": target})
