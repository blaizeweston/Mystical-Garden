extends RefCounted

const Lance = preload("res://core_lance.gd")
const Status = preload("res://combat_status.gd")
const Journal = preload("res://diagnostic_journal.gd")


static func endpoint(field: RefCounted, cast: Dictionary, direction: Vector3) -> Vector3:
	var star: Vector3 = cast.center
	return field.projectile_endpoint(star, star + direction.normalized() * float(cast.skill.beam_range), float(cast.skill.radius))


static func direction(game: Node, id: int, cast: Dictionary, now: int) -> Vector3:
	var aim: Dictionary = game.mouse_controls.states.get(id, {})
	var sampled := int(aim.get("at", 0))
	if sampled < int(cast.release) or now - sampled > game.MouseCombat.MAX_AGE:
		return cast.forward
	var facing: Vector3 = aim.aim
	var distance := float(aim.get("cursor_distance", -1.0))
	if distance >= 0.0:
		var offset: Vector3 = game.players[id].pos + facing * distance - cast.center
		if offset.length_squared() >= .09:
			return offset.normalized()
	return facing


static func fire(game: Node, id: int, cast: Dictionary, end: Vector3, now: int) -> void:
	var star: Vector3 = cast.center
	if star.distance_squared_to(end) < .01:
		return
	var radius: float = cast.skill.radius
	var until := now + int(cast.skill.root_ms)
	var targets: Array[int] = []
	for hit in Lance.ordered_hits(game, star, end, radius):
		var point: Vector3 = game.enemy_position(hit.target)
		var edge := Geometry3D.get_closest_point_to_segment(point, star, end)
		if not game.battlefield.combat_sight(edge, point):
			continue
		Status.root(game, hit.target, until)
		if cast.skill.has("beam_damage"):
			game.apply_weapon_hit(game.players[id], hit.target, star, {"damage": cast.skill.beam_damage,
				"knockback": -.35, "trait_secondary": true, "core_hit": true}, now)
		targets.append(hit.target)
		if targets.size() >= int(cast.skill.targets):
			break
	game.emit_combat_event("swing", cast.skill.id, star, end, .6, Color(cast.skill.color), star.distance_to(end), 0,
		{"form": "proc", "pattern": "line", "width": radius, "contact": .10})
	Journal.event("combat", "core_anchor_beam", {"actor": id, "cast_id": cast.id, "skill": cast.skill.id, "targets": targets})
