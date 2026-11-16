extends RefCounted

const Motion = preload("res://weapon_motion.gd")
const Contact = preload("res://weapon_contact.gd")
const Mouse = preload("res://mouse_combat.gd")
const GROUND_TRAPS := ["snare", "snare_field"]
const NEEDS_TARGET := ["bind", "strangle", "siphon", "salvo", "judgement", "reap", "harvest", "requiem", "volley"]
const TARGET_AREA := ["judgement", "requiem", "growth"]
const TRAVEL := ["charge", "harvest", "reap", "windstep"]
const SELF_AREA := ["bastion", "ward", "quake", "nova", "bloodmoon", "heal", "sanctuary"]


static func range_limit(game: Node, player: Dictionary, skill: Dictionary, stats: Dictionary) -> float:
	var base: float = game.Classes.DEFINITIONS[int(player.frame)].weapons[int(player.weapon_kind)].reach
	return float(skill.get("range", stats.reach)) + maxf(0.0, float(stats.reach) - base)


static func target_range(mode: String, skill: Dictionary, stats: Dictionary, reach: float) -> float:
	if mode == "reap":
		return float(stats.reach) + float(skill.travel)
	if mode == "volley":
		return float(stats.reach)
	return reach + (float(skill.get("travel", 0)) if not skill.has("range") else 0.0)


static func positions(game: Node) -> Dictionary:
	var result := {}
	if game.enemy_hp > 0:
		result[-1] = game.enemy_pos
	if game.multiplayer.is_server():
		for index in game.scouts.size():
			if game.scouts[index].hp > 0:
				result[index] = game.scouts[index].pos
	else:
		for index in range(0, game.client_pack.size() - game.PACK_STRIDE + 1, game.PACK_STRIDE):
			if game.client_pack[index + 2] > 0.0:
				result[int(index / game.PACK_STRIDE)] = Vector3(game.client_pack[index], 0, game.client_pack[index + 1])
	return result


static func pick(game: Node, field: RefCounted, origin: Vector3, facing: Vector3, reach: float) -> Dictionary:
	var best := INF
	var result := {}
	var candidates := positions(game)
	for target in candidates:
		var point: Vector3 = candidates[target]
		var offset := point - origin
		var distance := offset.length()
		var dot := facing.dot(offset.normalized()) if distance > .01 else 1.0
		if distance > reach or dot < .75 or not field.clear_line(origin, point):
			continue
		var score := distance + (1.0 - dot) * .55
		if score < best:
			best = score
			result = {"target": target, "point": point}
	return result


static func landing(field: RefCounted, origin: Vector3, facing: Vector3, skill: Dictionary, target: Vector3 = Vector3.INF) -> Vector3:
	var travel := float(skill.get("travel", 0.0))
	if skill.mode == "windstep":
		return field.dash(origin, origin - facing * travel)
	if target == Vector3.INF:
		return field.dash(origin, origin + facing * travel)
	var distance := minf(travel, maxf(0.0, origin.distance_to(target) - .6))
	return field.dash(origin, origin.move_toward(target, distance))


static func growth_centers(game: Node, id: int) -> Array:
	if not game.multiplayer.is_server():
		return game.players.get(id, {}).get("ability_growth_centers", [])
	var result := []
	var now := Time.get_ticks_msec()
	for field in game.trait_events:
		if field.kind == "growth" and field.owner == id and field.epoch == game.combat_epoch and now < int(field.until):
			result.append(field.position)
	return result


static func plan(game: Node, player: Dictionary, field: RefCounted, skill: Dictionary, stats: Dictionary, forward: Vector3, distance: float = -1.0) -> Dictionary:
	if skill.mode == "subclass":
		return preload("res://subclass_combat.gd").plan(game,player,field,skill,forward,distance)
	var origin: Vector3 = player.pos
	var mode: String = skill.mode
	var reach := range_limit(game, player, skill, stats)
	var selection_range := target_range(mode, skill, stats, reach)
	var selected := {}
	if mode in NEEDS_TARGET or mode in ["charge", "growth"]:
		selected = pick(game, field, origin, forward, selection_range)
	var found: bool = not selected.is_empty()
	var target: int = selected.get("target", -2)
	var point: Vector3 = selected.get("point", origin)
	var result := {"target": target, "point": point, "reach": reach, "range": selection_range, "center": origin, "forward": forward,
		"valid": found or mode not in NEEDS_TARGET, "growth": []}
	if mode=="quake" and skill.has("warden_focus"):
		result.center=preload("res://warden_combat.gd").quake_center(game,player,field,skill,Time.get_ticks_msec())
	if mode in TRAVEL:
		result.center = landing(field, origin, forward, skill, point if found and mode != "windstep" else Vector3.INF)
	elif mode in GROUND_TRAPS:
		var amount := minf(distance, reach) if distance >= 0.0 else reach
		result.center = field.dash(origin, origin + forward * amount)
		result.point = result.center
		result.valid = not field.occupied(result.center)
	elif mode in TARGET_AREA and found:
		result.center = point
	if mode in ["reap", "volley", "salvo"] and found:
		var direction := point - Vector3(result.center)
		if not direction.is_zero_approx():
			result.forward = direction.normalized()
	if mode == "bloom_detonate":
		result.growth = growth_centers(game, game.multiplayer.get_unique_id() if not game.multiplayer.is_server() else game.Traits.player_id(game, player))
		result.valid = not result.growth.is_empty()
	return result


static func footprint(game: Node, player: Dictionary, field: RefCounted, skill: Dictionary, stats: Dictionary, cast: Dictionary) -> Array:
	if skill.mode == "subclass":
		return preload("res://subclass_combat.gd").footprint(cast)
	var result: Array = []
	var mode: String = skill.mode
	var origin: Vector3 = player.pos
	var center: Vector3 = cast.center
	var radius := float(skill.get("radius", 0.0))
	if mode in NEEDS_TARGET or mode in GROUND_TRAPS or mode == "growth":
		result.append({"kind": "range", "at": origin, "radius": cast.range})
	if mode == "front_guard":
		result.append({"kind": "cone", "at": origin, "radius": radius, "forward": cast.forward, "span": 2.0 * acos(.15)})
	elif mode in SELF_AREA or (mode in TARGET_AREA + GROUND_TRAPS and cast.valid) or mode in ["charge", "harvest"]:
		result.append({"kind": "area", "at": center, "radius": radius})
	elif mode == "bloom_detonate" and cast.valid:
		for patch in cast.growth:
			result.append({"kind": "area", "at": patch, "radius": radius})
	elif mode in ["guard", "counter_guard", "bloom_detonate"]:
		result.append({"kind": "point", "at": origin, "radius": .55})
	if mode in TRAVEL:
		if mode in ["charge", "windstep"]:
			result.append({"kind": "range", "at": origin, "radius": float(skill.travel)})
		result.append({"kind": "travel", "from": origin, "to": center})
	if mode in ["bind", "strangle", "siphon"] and cast.target != -2:
		result.append({"kind": "point", "at": cast.point, "radius": .48})
	if mode == "salvo":
		var end: Vector3 = origin + cast.forward * float(cast.reach)
		result.append({"kind": "strip", "from": origin, "to": end, "width": float(skill.width)})
	elif mode in ["reap", "volley"] and cast.valid:
		var burst := stats.duplicate()
		burst.pattern = "chain" if int(player.frame) == game.Frames.RANGER else "sweep"
		var form := Motion.form(player)
		var shape := Contact.describe(form, burst)
		if shape.pattern == "projectile":
			var profile := Motion.profile(form)
			var path := Mouse.projectile_path(field, center, cast.forward, profile, shape.reach)
			var rays := Mouse.volley(game, {"form": form, "direction": cast.forward, "origin": path.from, "aim": path.to,
				"launch_position": center, "stats": burst, "release": 0}, field)
			for ray in rays:
				result.append({"kind": "capsule", "from": ray.origin, "to": ray.aim, "width": shape.projectile_radius})
		else:
			result.append({"kind": "weapon", "at": center, "forward": cast.forward, "profile": shape})
	if cast.valid and mode != "bloom_detonate":
		var zone_center: Vector3 = cast.point if mode in ["bind", "strangle", "snare", "siphon", "salvo"] else center
		var zone_radii: Array[float] = []
		if skill.has("field"):
			zone_radii.append(float(skill.get("radius", 2.0)))
		else:
			if float(stats.get("growth_field", 0)) > 0.0:
				zone_radii.append(2.0)
			if float(stats.get("protect_growth", 0)) > 0.0 and mode in ["heal", "sanctuary"]:
				zone_radii.append(3.0)
		for zone_radius in zone_radii:
			if not is_equal_approx(zone_radius, radius) or mode not in SELF_AREA + TARGET_AREA:
				result.append({"kind": "range", "at": zone_center, "radius": zone_radius})
	return result
