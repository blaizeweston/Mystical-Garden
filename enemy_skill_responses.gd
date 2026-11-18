extends RefCounted
## Additional attack plans after confirmed player interference. The warning and hit use the same plan.
const Tactics = preload("res://wilds_skill_tactics.gd")
const Catalog = preload("res://enemy_catalog.gd")
const Support = preload("res://enemy_support.gd")
const Variants = preload("res://enemy_variants.gd")
const APPROACH := {2: "charge", 8: "pounce", 11: "canopy_shift", 13: "charge", 17: "charge"}
const MIN_WINDUP := 1150
const GRAB_REACH := 3.1


static func ready_profile(game: Node, actor: Dictionary) -> Dictionary:
	var profile: Dictionary = Tactics.REGULAR_RESPONSES.get(actor.kind, {})
	return profile if not profile.is_empty() and Tactics.regular_ready(game, actor, profile) else {}


static func commit(attack: Dictionary, profile: Dictionary) -> void:
	attack.variant = profile.id
	attack.cue = profile.cue
	attack.recovery_bonus = maxi(320, int(attack.recovery_bonus))
	attack.learned = true


static func decorate(game: Node, actor: Dictionary, attack: Dictionary, aim: Vector3) -> void:
	var profile := ready_profile(game, actor)
	if profile.is_empty() or attack.mode != profile.mode or APPROACH.has(actor.kind):
		return
	var origin: Vector3 = attack.from
	match int(actor.kind):
		0, 7:
			if origin.distance_squared_to(aim) < .01:
				return
			attack.role = "enemy_sweep"
			attack.span = 1.35 if actor.kind == 0 else 1.7
			attack.radius = 2.1 if actor.kind == 0 else 3.15
			attack.erase("follow")
		1:
			# Place a single follow-up bud beside the point where its volley was stopped.
			var denied: Vector3 = actor.get("denied_aim", aim)
			var beds := open_spots(game, origin, denied, [Vector2(1.55, 0)], .9, actor.route)
			if beds.is_empty():
				return
			attack.to = beds[0]
			attack.radius = .9
			attack.pulse = 1
		5, 14, 18:
			var center := origin.lerp(aim, .7) if actor.kind == 14 else aim
			var offsets: Array[Vector2] = [Vector2(-1.4, 0), Vector2(1.4, 0)]
			if actor.kind == 5:
				offsets = [Vector2(-1.15, -.7), Vector2(1.15, .7)]
			elif actor.kind == 18:
				offsets = [Vector2(-1.5, .5), Vector2(1.5, -.5)]
			var radius := .8 if actor.kind == 14 else .75
			var pockets := open_spots(game, origin, center, offsets, radius, actor.route)
			if pockets.is_empty():
				return
			attack.spots = pockets
			attack.spot_radius = radius
		6:
			var fan := open_spots(game, origin, aim, [Vector2(-2.25, 0), Vector2(0, -.8), Vector2(2.25, 0)], .9, actor.route)
			if fan.is_empty():
				return
			attack.patches = fan
			attack.radius = .9
		12:
			var lamps := open_spots(game, origin, origin.lerp(aim, .35), [Vector2(1.65, 0)], .35, actor.route)
			if lamps.is_empty() or not game.battlefield.clear_line(lamps[0], aim):
				return
			attack.anchor = lamps[0]
			attack.radius = 1.15
		16:
			if origin.distance_to(aim) > GRAB_REACH or not game.battlefield.clear_line(origin, aim, game.Battlefield.CLEARANCE):
				return
			attack.grab_reach = GRAB_REACH
	commit(attack, profile)


static func open_spots(game: Node, origin: Vector3, center: Vector3, offsets: Array[Vector2], radius: float, route: int) -> Array[Vector3]:
	var ordered := offsets.duplicate()
	if route % 2 != 0:
		for i in ordered.size():
			ordered[i].x *= -1
	var spots := Variants.spread(game, origin, center, ordered, radius)
	for at in spots:
		if not game.battlefield.clear_line(origin, at):
			return []
	return spots


static func approach(game: Node, actor: Dictionary, attack: Dictionary, aim: Vector3, profile: Dictionary) -> bool:
	var origin: Vector3 = attack.from
	var gap := origin.distance_to(aim)
	match int(actor.kind):
		2, 13:
			if gap < 2.4 or gap > (4.8 if actor.kind == 2 else 6.3):
				return false
			var via := Variants.seam(game, origin, aim, int(actor.route))
			if not via.is_finite():
				return false
			attack.via = via
			attack.to = aim
			if actor.kind == 2:
				attack.width = .62
				attack.radius = .9
		8:
			if gap < 1.3 or gap > 3.6:
				return false
			var landing := Variants.cutoff(game, origin, aim, int(actor.route))
			if landing.is_equal_approx(aim):
				return false
			attack.to = landing
			attack.radius = .95
		11:
			if not plan_canopy(game, actor, attack):
				return false
		17:
			if gap < 2.2 or gap > 5.5 or not game.battlefield.clear_line(origin, aim, game.Battlefield.CLEARANCE):
				return false
			var landing := origin.lerp(aim, .68)
			var embers := open_spots(game, origin, landing, [Vector2(-1.55, .45), Vector2(1.55, .45)], .85, actor.route)
			if embers.is_empty():
				return false
			attack.to = landing
			attack.trail = embers
	commit(attack, profile)
	attack.learned_move = true
	return true


static func plan_canopy(game: Node, actor: Dictionary, attack: Dictionary) -> bool:
	var ref: Dictionary = actor.get("shelter_escort", {})
	if ref.is_empty() or not Support.live_ally(game, ref):
		return false
	var origin: Vector3 = actor.pos
	var ally: Vector3 = game.enemy_position(ref.slot)
	if Support.covers(game, actor, origin, ally, origin, preload("res://combat_clock.gd").now(), true):
		return false
	var goal := origin.move_toward(ally, minf(2.7, origin.distance_to(ally) - 1.1))
	var radius := float(Catalog.get_kind(11).shelter_radius)
	if origin.distance_to(goal) < .9 or goal.distance_to(ally) > radius:
		return false
	if not game.battlefield.clear_line(origin, goal, game.Battlefield.CLEARANCE) or not game.battlefield.clear_line(goal, ally):
		return false
	attack.role = "canopy"
	attack.to = goal
	attack.radius = radius
	attack.escorts = [{"slot": ref.slot, "token": ref.token, "point": ally}]
	return true


static func resolve_canopy(game: Node, actor: Dictionary, attack: Dictionary, now: int) -> void:
	if not move_still_valid(actor,attack,now):
		return
	var ref: Dictionary = attack.escorts[0]
	if not Support.live_ally(game, ref):
		return
	var ally: Vector3 = game.enemy_position(ref.slot)
	var goal: Vector3 = attack.to
	if goal.distance_to(ally) > float(attack.radius) or not game.battlefield.clear_line(goal, ally):
		return
	if not game.battlefield.clear_line(actor.pos, goal, game.Battlefield.CLEARANCE):
		return
	preload("res://event_audio.gd").enemy(game,attack,true)
	actor.pos = goal
	var feedback = preload("res://enemy_move_feedback.gd")
	feedback.release(game,"burst",attack.from,goal,attack.radius,feedback.SUPPORT)


static func move_still_valid(actor: Dictionary, attack: Dictionary, now: int) -> bool:
	return now >= int(actor.rooted_until) and Vector3(actor.pos).distance_squared_to(attack.from) < .65 * .65
