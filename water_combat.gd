extends RefCounted

const Actors = preload("res://frost_combat.gd")
const Clock = preload("res://affinity_time.gd")
const Footprint = preload("res://core_footprint.gd")
const DRENCHED := "affinity_drenched"
const COLOR := Color("#82d7ec")
const DURATION_MS := 4200
const WAVE_MS := 550
const WAVE_RADIUS := 1.05
const RADIUS := 2.4
const COOLDOWN_MS := 8000
const QUALITY := {
	"ordinary": {"reduction": .18, "impact_hp": 7},
	"refined": {"reduction": .30, "impact_hp": 11},
}
const VERSION_DATA := [DURATION_MS, WAVE_MS, WAVE_RADIUS, RADIUS, COOLDOWN_MS, QUALITY]


static func description(slot: String, quality: String) -> String:
	var p: Dictionary = QUALITY[quality]
	var line: String = {
		"core": "Dewfall · A forward curtain deals %d HP and Drenches enemies. Cleanses ordinary Slow from you at formation and from living allies it touches. %.1f s cooldown." % [p.impact_hp, COOLDOWN_MS / 1000.0],
		"form": "Drenching Strikes · Your direct weapon contacts Drench their targets.",
		"catalyst": "Water Catalyst · Offensive class skills Drench. A qualifying block, mapped heal or movement landing washes once within %.1f m." % RADIUS,
	}[slot]
	return line + "\nDrenched reduces direct enemy attack damage by %d%% for %.1f s. Sources expire separately. Only the strongest applies." % [
		roundi(p.reduction * 100), DURATION_MS / 1000.0,
	]


static func drench(game: Node, event: RefCounted, target: int) -> void:
	if not Actors.valid_target(game, target):
		return
	var elapsed := Clock.now(game)
	var actor: Dictionary = Actors.body(game, target)
	var sources: Dictionary = actor.get(DRENCHED, {})
	for key in sources.keys():
		if int(sources[key].until) <= elapsed:
			sources.erase(key)
	sources["%d/%s" % [event.actor,event.source]] = {
		"reduction": event.potency().reduction, "until": elapsed + DURATION_MS,
		"quality": event.quality, "activation": event.identity, "item": event.material_id,
	}
	actor[DRENCHED] = sources


static func reduction(actor: Dictionary, elapsed: int) -> float:
	var strongest := .0
	for source in actor.get(DRENCHED, {}).values():
		if int(source.until) > elapsed:
			strongest = maxf(strongest, float(source.reduction))
	return strongest


static func direct_damage(game: Node, hp: int) -> int:
	# Native enemy strikes and ranged attacks deal their damage on the host
	# at impact. Evaluate the attacker's current Drenched sources here.
	# Delayed ground hazards and unrelated sources have no attack context.
	var target: int = game.get_meta(Actors.ATTACKER, -2)
	if target < -1 or target >= game.scouts.size():
		return hp
	return roundi(hp * (1.0 - reduction(Actors.body(game,target), Clock.now(game))))


static func cleanse(player: Dictionary) -> void:
	player.slow_until = 0


static func wash(game: Node, event: RefCounted, center: Vector3) -> void:
	game.emit_combat_event("ability", "water_wash", center, center, .55, COLOR, RADIUS, event.actor, {"label": "Cleansing wash"})
	for target in game.skill_area_targets(center,RADIUS,center):
		drench(game,event,target)
	for id in game.Life.living_ids(game):
		var player: Dictionary = game.players[id]
		if center.distance_to(player.pos) <= RADIUS and game.battlefield.clear_line(center,player.pos):
			cleanse(player)


static func wave(game: Node, cast: Dictionary, player: Dictionary, now: int) -> bool:
	var elapsed := Clock.now(game)
	if not cast.grown:
		cast.grown = true
		cast.wave_at = elapsed
		var from: Vector3 = player.pos
		var reach: float = Vector3(cast.cast_origin).distance_to(cast.center)
		cast.wave_center = from
		cast.wave_origin = from
		cast.wave_end = game.battlefield.dash(from,from + Vector3(cast.forward) * reach)
		cast.affinity_action.publish(game,"core_action","cleanse",str(cast.owner),now,{"player":cast.owner})
		game.emit_combat_event("projectile", "dewfall", from, cast.wave_end, WAVE_MS / 1000.0, COLOR, WAVE_RADIUS, cast.owner,
			{"label":"Dewfall", "projectile_radius":WAVE_RADIUS, "height":.1})
	var fraction := clampf(float(elapsed - int(cast.wave_at)) / WAVE_MS, 0.0, 1.0)
	var point: Vector3 = Vector3(cast.wave_origin).lerp(cast.wave_end, fraction)
	var previous: Vector3 = cast.wave_center
	var shapes := [{"kind":"capsule", "from":previous, "to":point, "width":WAVE_RADIUS}]
	for id in game.Life.living_ids(game):
		if id != int(cast.owner) and Footprint.reaches(game.battlefield,shapes,game.players[id].pos,previous):
			cast.affinity_action.publish(game,"core_action","cleanse",str(id),now,{"player":id})
	for target in Footprint.targets(game,shapes,previous):
		cast.affinity_action.publish(game,"core_action","impact",Actors.target_token(game,target),now,{"enemy":target})
	cast.wave_center = point
	return fraction >= 1.0


static func on_event(game: Node, event: RefCounted, kind: String, details: Dictionary, now: int) -> void:
	match kind:
		"core_action":
			if details.has("player"):
				var id: int = details.player
				if game.players.has(id) and game.Life.alive(game.players[id]):
					cleanse(game.players[id])
			else:
				Actors.damage(game,event.actor,int(details.enemy),int(event.potency().impact_hp),now,COLOR)
				drench(game,event,int(details.enemy))
		"weapon_contact", "class_contact":
			drench(game,event,int(details.enemy))
		"actual_block":
			wash(game,event,details.center)
		"class_action":
			match details.get("response", ""):
				"healing_wash", "landing_wash":
					wash(game,event,details.center)
				"drench":
					var targets: Array = details.enemies
					if details.get("target_scope") == "designated_area":
						targets = game.skill_area_targets(details.center,details.radius,details.center)
					for target in targets:
						drench(game,event,target)
