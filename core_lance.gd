extends RefCounted

const Status = preload("res://combat_status.gd")
const Effects = preload("res://core_skill_effects.gd")
const StrikeMark = preload("res://core_strike_mark.gd")
const Hurt = preload("res://enemy_hurtbox.gd")
const Contact = preload("res://weapon_contact.gd")
const Mouse = preload("res://mouse_combat.gd")
const Motion = preload("res://weapon_motion.gd")
const Journal = preload("res://diagnostic_journal.gd")


static func placement(field: RefCounted, origin: Vector3, forward: Vector3, skill: Dictionary) -> Dictionary:
	var radius := float(skill.radius)
	var start := origin
	var end: Vector3
	if skill.get("affinity_family") == "storm" and skill.delivery != "ground":
		var path := Mouse.projectile_path(field, origin, forward, Motion.profile(skill.weapon_form), float(skill.range), radius)
		start = path.from
		end = path.to
	else:
		end = field.projectile_endpoint(origin, origin + forward * float(skill.range), radius)
	if origin.distance_to(end) < .85:
		return {}
	return {"from": start, "to": end, "center": end, "previous_point": start, "hit_tokens": {}}


static func release(game: Node, cast: Dictionary) -> void:
	if cast.skill.get("affinity_family")=="storm":
		game.emit_combat_event("projectile",cast.skill.projectile,cast.from,cast.to,cast.flight_ms/1000.0,
			Color(cast.skill.color),cast.from.distance_to(cast.to),0,{"projectile_radius":cast.skill.radius,"height":0.0})
		return
	var height: float = float(cast.origin.y) if cast.skill.delivery != "ground" else .85
	var lift := Vector3.UP * height
	game.emit_combat_event("projectile", "needle", cast.from + lift, cast.to + lift, cast.flight_ms / 1000.0,
		Color(cast.skill.color), cast.from.distance_to(cast.to), 0, {"projectile_radius": cast.skill.radius, "height": 0.0})


static func advance(game: Node, id: int, player: Dictionary, cast: Dictionary, now: int) -> bool:
	if not cast.released:
		return false
	var fraction := clampf((now - int(cast.release)) / float(cast.flight_ms), 0.0, 1.0)
	var tip: Vector3 = cast.from.lerp(cast.to, fraction)
	var previous: Vector3 = cast.previous_point
	var cover: float = game.battlefield.projectile_block_fraction(previous, tip, float(cast.skill.radius))
	var blocked := cover != INF
	if blocked:
		tip = previous.lerp(tip, cover)
	if tip.is_equal_approx(previous):
		if blocked:
			stop(game, cast, tip)
		return blocked
	cast.previous_point = tip
	var hits := ordered_hits(game, previous, tip, float(cast.skill.radius), cast.hit_tokens)
	for hit in hits:
		if game.Traits.valid_target(game, hit.target) and Contact.token(game, hit.target) == hit.token:
			if cast.skill.get("affinity_family")=="storm":
				preload("res://storm_affinity.gd").core_contact(game,cast,hit.target,cast.from,hit.point,now)
				stop(game,cast,hit.point)
				return true
			if cast.skill.get("contact", "damage") == "strike_mark":
				StrikeMark.place(game, id, hit.target, cast, now)
				stop(game, cast, hit.point)
				return true
			if cast.skill.get("contact") == "chain":
				Effects.chain(game, id, player, cast, hit.target, now)
				stop(game, cast, hit.point)
				return true
			var first: bool = cast.hit_tokens.is_empty()
			cast.hit_tokens[hit.token] = true
			var distance: float = cast.from.distance_to(game.enemy_position(hit.target))
			game.apply_weapon_hit(player, hit.target, cast.from, {
				"damage": cast.skill.damage, "knockback": -.35, "trait_secondary": true,
				"shot_distance": distance, "core_hit": true,
			}, now)
			if first and int(cast.skill.root_ms) > 0 and game.Traits.valid_target(game, hit.target):
				Status.root(game, hit.target, now + int(cast.skill.root_ms))
			Journal.event("combat", "core_lance_hit", {"actor": id, "skill": cast.skill.id, "cast_id": cast.id, "target": hit.target, "target_token": hit.token})
			if cast.hit_tokens.size() >= int(cast.skill.targets):
				stop(game, cast, hit.point)
				return true
	if blocked:
		stop(game, cast, tip)
	return blocked or fraction >= 1.0


static func stop(game: Node, cast: Dictionary, point: Vector3) -> void:
	game.emit_combat_event("projectile_end", str(cast.flight_event), point, point, .15, Color.WHITE, 0.0, 0)


static func ordered_hits(game: Node, from: Vector3, to: Vector3, radius: float, excluded: Dictionary = {}) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	for target in range(-1, game.scouts.size()):
		if not game.Traits.valid_target(game, target):
			continue
		var token := Contact.token(game, target)
		if excluded.has(token):
			continue
		var collision := Hurt.sweep(game, target, from, to, radius)
		if not collision.is_empty():
			hits.append({"target": target, "token": token, "fraction": collision.fraction, "point": collision.point})
	hits.sort_custom(func(a, b): return a.fraction < b.fraction or (a.fraction == b.fraction and a.target < b.target))
	return hits
