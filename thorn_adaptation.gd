extends RefCounted

const PlayerLifecycle = preload("res://player_lifecycle.gd")
const Journal = preload("res://diagnostic_journal.gd")
const Catalog = preload("res://enemy_catalog.gd")
const CORE_STATE := &"core_combat"
const TACTIC := "thorn_line"
const MOVE := "thorn_vault"
const CUE := "Thorn vault"
const WINDUP := 1250
const LANDING_RADIUS := 1.15
const HOUND := 4
const MIN_FLOOR := 6
const MIN_SCORE := 6
const LEAP_REACH := 3.6
const EVIDENCE := &"thorn_line_evidence"


static func evidence(game: Node) -> Dictionary:
	var observed: Dictionary = game.get_meta(EVIDENCE, {})
	if int(observed.get("epoch", -1)) == game.combat_epoch:
		return observed
	return {"epoch": game.combat_epoch, "armed": 0, "crossings": 0}


static func armed(game: Node, owner: int, line: Dictionary) -> void:
	var observed := evidence(game)
	observed.armed += 1
	game.set_meta(EVIDENCE, observed)
	Journal.event("combat", "wilds_thorn_armed", {"actor": owner, "cast_id": line.id, "floor": game.encounter_number})


static func tripped(game: Node, owner: int, line: Dictionary, target: int, before: Vector3, after: Vector3) -> void:
	if before.distance_squared_to(after) < .0025 or touches(line, before):
		return
	if (target == -1 and game.tactics.boss_kind >= 0) or (target >= 0 and game.encounter.scout(target).get("summoned", false)):
		return
	var observed := evidence(game)
	observed.crossings += 1
	game.set_meta(EVIDENCE, observed)
	Journal.event("combat", "wilds_thorn_crossing", {"actor": owner, "cast_id": line.id, "target": target,
		"species": Catalog.get_kind(game.enemy_kind if target == -1 else int(game.encounter.scout(target).kind)).id, "floor": game.encounter_number})


static func selected(game: Node, actor: Dictionary) -> bool:
	if int(actor.kind) != HOUND or game.encounter_number < MIN_FLOOR or actor.get("summoned", false):
		return false
	var score: int = game.progress.wilds_memory.score.get(TACTIC, 0)
	var roll := posmod(int(game.map_seed) + int(actor.route) * 31 + int(game.encounter_number) * 11, 10)
	return score >= MIN_SCORE and roll < mini(7, 3 + floori(score / 6.0))


static func active_lines(game: Node, now: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var lines: Dictionary = game.get_meta(CORE_STATE, {})
	for owner in lines:
		var line: Dictionary = lines[owner]
		var player: Dictionary = game.players.get(owner, {})
		if line.skill.mechanic == "line_trap" and line.grown and int(line.epoch) == game.combat_epoch and now < int(line.expires) \
				and game.Life.alive(player) and PlayerLifecycle.matches(player,int(line.life)):
			result.append(line)
	return result


static func touches(line: Dictionary, point: Vector3, padding: float = 0.0) -> bool:
	var edge := Geometry3D.get_closest_point_to_segment(point, line.from, line.to)
	return point.distance_to(edge) <= float(line.skill.radius) + padding


static func crosses(line: Dictionary, start: Vector3, end: Vector3) -> bool:
	var normal := (Vector3(line.to) - Vector3(line.from)).normalized().cross(Vector3.UP)
	if (start - Vector3(line.from)).dot(normal) * (end - Vector3(line.from)).dot(normal) >= 0.0:
		return false
	var nearest := Geometry3D.get_closest_points_between_segments(start, end, line.from, line.to)
	return nearest[0].distance_squared_to(nearest[1]) <= .0001


static func plan(game: Node, actor: Dictionary, victim: Vector3, now: int) -> Dictionary:
	if actor.get("thorn_vault_used", false) or not selected(game, actor):
		return {}
	var origin: Vector3 = actor.pos
	var landing := origin.move_toward(victim, LEAP_REACH)
	if origin.distance_squared_to(landing) < 2.25:
		return {}
	var lines := active_lines(game, now)
	if lines.is_empty() or lines.any(func(line): return touches(line, landing, .24)):
		return {}
	var nearest := INF
	var chosen: Dictionary = {}
	for line in lines:
		if touches(line, origin, .08) or not crosses(line, origin, landing):
			continue
		var distance := origin.distance_squared_to(Geometry3D.get_closest_point_to_segment(origin, line.from, line.to))
		if distance < nearest:
			nearest = distance
			chosen = line
	if chosen.is_empty() or not open_lane(game, origin, landing):
		return {}
	return {"line_id": chosen.id, "landing": landing}


static func open_lane(game: Node, origin: Vector3, landing: Vector3) -> bool:
	var clearance: float = game.Battlefield.CLEARANCE
	return not game.battlefield.occupied(landing, clearance) and game.battlefield.clear_line(origin, landing, clearance)


static func can_land(game: Node, actor: Dictionary, attack: Dictionary, now: int) -> bool:
	var origin: Vector3 = actor.pos
	var landing: Vector3 = attack.to
	return now >= int(actor.get("rooted_until", 0)) and origin.distance_squared_to(attack.from) <= .16 \
		and open_lane(game, origin, landing) \
		and not active_lines(game, now).any(func(line): return touches(line, landing, .24))


static func landed(game: Node, actor: Dictionary, attack: Dictionary, now: int) -> void:
	var index: int = -1 if actor.get("gate_elite", false) else game.encounter.scout_slot(actor)
	var token: int = 0 if index == -1 else game.encounter.token_for(actor)
	for line in active_lines(game, now):
		if line.id != attack.thorn_line:
			continue
		# The jump crossed above this line. Begin the next ground sweep at the landing.
		line.previous[index] = {"pos": attack.to, "token": token}
		break
	Journal.event("combat", "wilds_thorn_vault_landed", {"target": index, "target_token": token, "cast_id": attack.thorn_line})
