extends RefCounted

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
const TICK_MS := 750
const FIELD_MS := 3200
const HALF_LENGTH := 2.15
const WIDTH := .68
const COOLDOWN_MS := 8000
const QUALITY := {
	"ordinary": {"tick_hp": 4, "impact_hp": 8, "burst_hp": 5},
	"refined": {"tick_hp": 6, "impact_hp": 12, "burst_hp": 8},
}
const VERSION_DATA := [RADIUS, RESPONSE_MS, BURN_MS, TICK_MS, FIELD_MS, HALF_LENGTH, WIDTH, COOLDOWN_MS, QUALITY]


static func description(slot: String, quality: String) -> String:
	var p: Dictionary = QUALITY[quality]
	var line: String = {
		"core": "Ember Wake · %.1f s burning-root trail. %d HP on first contact per enemy, then maintains Burning. %.1f s cooldown." % [FIELD_MS / 1000.0, p.impact_hp, COOLDOWN_MS / 1000.0],
		"form": "Burning Strikes · Direct weapon contacts ignite the enemies actually hit.",
		"catalyst": "Fire Catalyst · Offensive class skills ignite. An actual block bursts for %d HP and ignites within %.1f m. Mapped healing and movement can grant a %.1f s single-use response to an unblocked enemy hit you survive." % [p.burst_hp, RADIUS, RESPONSE_MS / 1000.0],
	}[slot]
	return line + "\nBurning deals %d HP immediately and every %.2f s for up to %.1f s. Refreshes by player and slot without extra ticks." % [p.tick_hp, TICK_MS / 1000.0, BURN_MS / 1000.0]


static func ignite(game: Node, event: RefCounted, target: int, now: int) -> void:
	if event.epoch != game.combat_epoch or game.get_meta(game.Transactions.PENDING,false) or not Actors.valid_target(game, target) \
			or not PlayerLifecycle.matches(game.players.get(event.actor,{}),event.life_generation):
		return
	var actor: Dictionary = Actors.body(game, target)
	var sources: Dictionary = actor.get(BURNING, {})
	var key := "%d/%s" % [event.actor, event.source]
	var elapsed := Clock.now(game)
	var previous: Dictionary = sources.get(key, {})
	var fresh: bool = int(previous.get("until", 0)) <= elapsed or int(previous.get("source_life",-1)) != event.life_generation
	var next := elapsed + TICK_MS if fresh else int(previous.next)
	var hp: int = event.potency().tick_hp
	sources[key] = {"actor": event.actor, "source_life": event.life_generation, "hp": hp, "next": next,
		"until": elapsed + BURN_MS, "quality": event.quality, "activation": event.identity, "item": event.material_id}
	actor[BURNING] = sources
	if fresh:
		Actors.damage(game, event.actor, target, hp, now, COLOR)


static func tick(game: Node, elapsed: int, now: int) -> void:
	var epoch: int = game.combat_epoch
	for target in range(-1, game.encounter.scout_count()):
		if game.combat_epoch != epoch:
			return
		var actor: Dictionary = Actors.body(game, target)
		if not actor.has(BURNING):
			continue
		if not Actors.valid_target(game, target):
			actor.erase(BURNING)
			continue
		var sources: Dictionary = actor[BURNING]
		for key in sources.keys():
			var burn: Dictionary = sources[key]
			if not PlayerLifecycle.matches(game.players.get(burn.actor,{}),int(burn.source_life)):
				sources.erase(key)
				continue
			# The expiry is exclusive. A stalled host processes due ticks once,
			# and stops if the target dies or the encounter is replaced.
			while int(burn.next) <= elapsed and int(burn.next) < int(burn.until):
				burn.next += TICK_MS
				Actors.damage(game, burn.actor, target, burn.hp, now, COLOR)
				if game.combat_epoch != epoch or not Actors.valid_target(game, target) or game.get_meta(game.Transactions.PENDING,false):
					break
			if game.combat_epoch != epoch or not Actors.valid_target(game, target) or game.get_meta(game.Transactions.PENDING,false):
				break
			if int(burn.until) <= elapsed:
				sources.erase(key)
		if sources.is_empty():
			actor.erase(BURNING)


static func field(game: Node, cast: Dictionary, now: int) -> bool:
	var elapsed := Clock.now(game)
	if not cast.grown:
		cast.grown = true
		cast.field_until = elapsed + FIELD_MS
		cast.shapes = Footprint.build(game.battlefield, cast, cast.cast_origin)
		cast.next_maintain = elapsed
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
		if not first:
			ignite(game, cast.affinity_action, target, now)
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
	if Clock.now(game) >= int(response.until) or response.event.epoch != game.combat_epoch:
		recipient.erase(RESPONSE)
		return
	var target: int = game.get_meta(Actors.ATTACKER, -2)
	if not Actors.valid_target(game, target):
		return
	recipient.erase(RESPONSE)
	response.event.publish(game, "incoming_hit", str(id), Actors.target_token(game, target), now, {"enemy": target})
