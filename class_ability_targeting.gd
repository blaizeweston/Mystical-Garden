extends RefCounted

const Mouse = preload("res://mouse_combat.gd")
const Hurt = preload("res://enemy_hurtbox.gd")



static func range_limit(game: Node, player: Dictionary, skill: Dictionary, stats: Dictionary) -> float:
	var base: float = game.Classes.DEFINITIONS[int(player.frame)].weapons[int(player.weapon_kind)].reach
	return preload("res://class_skill_balance.gd").range_limit(skill, stats, base)


static func positions(game: Node) -> Dictionary:
	var result := {}
	if game.enemy_health() > 0:
		result[-1] = game.tactics.position
	if game.multiplayer.is_server():
		for index in game.encounter.scout_count():
			if game.encounter.alive(index):
				result[index] = game.encounter.scout(index).pos
	else:
		var pack: PackedFloat32Array = game.guest_replication.scouts()
		for index in range(0, pack.size() - game.PACK_STRIDE + 1, game.PACK_STRIDE):
			if pack[index + 2] > 0.0:
				result[int(index / game.PACK_STRIDE)] = Vector3(pack[index], 0, pack[index + 1])
	return result


static func pick(game: Node, field: RefCounted, origin: Vector3, facing: Vector3, reach: float,
		shot: Dictionary = {}, line_width: float = -1.0) -> Dictionary:
	var best := INF
	var result := {}
	var candidates := positions(game)
	for target in candidates:
		var point: Vector3 = candidates[target]
		var offset := point - origin
		var distance := offset.length()
		var dot := facing.dot(offset.normalized()) if distance > .01 else 1.0
		if distance > reach or dot < .75:
			continue
		if not target_clear(game, field, origin, point, target, reach, shot, line_width):
			continue
		var score := distance + (1.0 - dot) * .55
		if score < best:
			best = score
			result = {"target": target, "point": point}
	return result


static func target_clear(game: Node, field: RefCounted, origin: Vector3, point: Vector3, target: int,
		reach: float, shot: Dictionary, line_width: float) -> bool:
	if not shot.is_empty():
		return Mouse.can_shoot(field, origin, point, Hurt.radius(game, target), shot, reach)
	if line_width >= 0.0:
		return origin.distance_to(point) <= reach and field.projectile_clear(origin, point, line_width)
	return field.clear_line(origin, point)


static func automatic(game: Node, player: Dictionary, reach: float, shot: Dictionary = {}, line_width: float = -1.0) -> int:
	var best := INF
	var result := -2
	var origin: Vector3 = player.pos
	var field: RefCounted = game.battlefield
	var facing: Vector3 = player.get("facing", Vector3.FORWARD)
	var ranged := not shot.is_empty() or line_width >= 0.0
	for target in range(-1, game.encounter.scout_count()):
		if not game.encounter.alive(target):
			continue
		var edge := Hurt.contact(game, target, origin, ranged)
		var offset := edge - origin
		var distance := offset.length()
		var dot := facing.dot(offset.normalized())
		if distance > reach or (player.get("mouse_aim", false) and not offset.is_zero_approx() and dot < .75):
			continue
		var point: Vector3 = game.enemy_position(target) if ranged else edge
		if not target_clear(game, field, origin, point, target, reach, shot, line_width):
			continue
		var score := distance + (1.0 - dot) * .55
		var token: int = -1 if target == -1 else game.encounter.token(target)
		if int(player.get("aim_target", -3)) == target and int(player.get("aim_token", -99)) == token:
			score -= .3
		if score < best:
			best = score
			result = target
	if result != -2:
		player.aim_target = result
		player.aim_token = -1 if result == -1 else game.encounter.token(result)
	return result


static func growth_centers(game: Node, id: int) -> Array:
	if not game.multiplayer.is_server():
		return game.players.get(id, {}).get("ability_growth_centers", [])
	var result := []
	var now := preload("res://combat_clock.gd").now()
	for field in game.effect_timeline.native_records():
		if field.kind == "growth" and field.owner == id and game.Traits.event_in_current_life(game,field) and now < int(field.until):
			result.append(field.position)
	return result


static func plan(game: Node, player: Dictionary, field: RefCounted, skill: Dictionary, stats: Dictionary, forward: Vector3, distance: float = -1.0) -> Dictionary:
	if skill.mode == "subclass":
		return preload("res://subclass_combat.gd").plan(game,player,field,skill,forward,distance)
	var origin: Vector3 = player.pos
	var mode: String = skill.mode
	var reach := range_limit(game, player, skill, stats)
	var selected := pick(game,field,origin,forward,reach) if mode == "siphon" else {}
	var found: bool = not selected.is_empty()
	var result := {"target":selected.get("target",-2), "point":selected.get("point",origin),
		"reach":reach, "range":reach, "center":origin, "forward":forward,
		"valid":found or mode != "siphon"}
	if mode == "quake" and skill.has("warden_focus"):
		result.center = preload("res://warden_combat.gd").quake_center(game,player,field,skill,preload("res://combat_clock.gd").now())
	elif mode == "snare":
		var amount := minf(distance,reach) if distance >= 0.0 else reach
		result.center = field.dash(origin,origin+forward*amount)
		result.point = result.center
		result.valid = not field.occupied(result.center)
	return result


static func footprint(game: Node, player: Dictionary, field: RefCounted, skill: Dictionary, _stats: Dictionary, cast: Dictionary) -> Array:
	if skill.mode == "subclass":
		return preload("res://subclass_combat.gd").footprint(cast)
	var result: Array = []
	var mode: String = skill.mode
	var origin: Vector3 = player.pos
	var radius := float(skill.get("radius",0.0))
	if mode in ["siphon","snare"]:
		result.append({"kind":"range", "at":origin, "radius":cast.range})
	if mode == "front_guard":
		result.append({"kind":"cone", "at":origin, "radius":radius, "forward":cast.forward, "span":2.0*acos(.15)})
	elif mode in ["ward","quake","nova"] or (mode == "snare" and cast.valid):
		result.append({"kind":"area", "at":cast.center, "radius":radius})
	elif mode in ["guard","counter_guard"]:
		result.append({"kind":"point", "at":origin, "radius":.55})
	if mode == "snare" and cast.valid and (skill.get("ranger_nodes",[]).has("bramble_corridor") or skill.get("ranger_nodes",[]).has("escape_route")):
		var lane := preload("res://ranger_combat.gd").corridor(field,origin,cast.center)
		if not lane.is_empty():
			lane.kind = "strip"
			result.append(lane)
	if mode == "siphon" and cast.target != -2:
		result.append({"kind":"point", "at":cast.point, "radius":.48})
	return result
