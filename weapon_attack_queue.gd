extends RefCounted
## Sole owner of pending ordinary attacks, release paths, shared fan hit budgets
## and completion. Receives a narrow world port, never Game or mutable actors.
## Time: absolute combat milliseconds. Distances/radii: metres.
const Motion = preload("res://weapon_motion.gd")
const Life = preload("res://expedition_life.gd")
const Events = preload("res://combat_action_events.gd")
var _pending: Array[Dictionary] = []
var _serial := 0
var _revision := 0

func try_start(port, peer: int, origin: Vector3, now: int) -> bool:
	var facts: Dictionary = port.start_facts(peer, now)
	if facts.is_empty(): return false
	var stats: Dictionary = port.capture_attack(peer, now)
	if stats.is_empty(): return false
	Life.Preview.lock_strike(stats, 0)
	var form: String = facts.form
	var duration: int = port.start_timeline(peer, stats, form, now)
	if duration < 0: return false
	var target := -2
	if not facts.mouse: target = port.aim_at_target(peer, origin, float(stats.reach), form)
	schedule(port, peer, origin, stats, now, form, duration, target)
	if port.has_method("release_mirrors"):port.release_mirrors(peer,stats,form,now,duration)
	if not facts.mouse and target == -2: port.no_target(peer)
	return true

## Also used by explicit delivery fixtures. Stats are captured once at admission;
## callers cannot edit the queued attack by later changing their input dictionary.
func schedule(port, peer: int, origin: Vector3, stats: Dictionary, now: int, form: String, duration: int, locked_target := -2, replica_pose: Dictionary = {}) -> int:
	var profile := Motion.profile(form)
	var release := now + roundi(duration * float(profile.release))
	var pose: Dictionary = port.prepare_pose(peer, form, stats, release) if replica_pose.is_empty() else replica_pose
	if pose.is_empty(): return 0
	var direction: Vector3 = pose.direction
	var end := origin + direction * float(stats.reach)
	_serial += 1
	var shot := {"queue_id":_serial, "hit_group":_serial, "player":peer, "epoch":pose.epoch, "life":pose.life,
		"binding":pose.binding, "sequence":pose.get("sequence",-1), "replica":not replica_pose.is_empty(),"replica_position":origin, "release":release, "due":release, "form":form, "origin":origin, "aim":end,
		"stats":_freeze(stats.duplicate(true)), "hits":[], "remaining":int(stats.targets)}
	if Motion.is_projectile(form):
		var path: Dictionary = port.projectile_path(origin, direction, form, float(stats.reach))
		shot.merge({"direction":direction, "mouse_ray":true, "emitted":false, "projectile":true,
			"origin":path.from, "aim":path.to, "previous":path.from, "muzzle_blocked":path.muzzle_blocked}, true)
		shot.due = release + _flight_ms(path.from, path.to, profile)
		if pose.mouse: shot.aim_combo = pose.sequence
		if locked_target >= -1:
			shot.locked_target = locked_target
			shot.locked_token = port.target_token(locked_target)
	else:
		port.telegraph(peer, origin, end, stats, now)
		shot.merge({"melee_shape":true, "emitted":true, "projectile":false})
	_pending.append(shot)
	return _serial

func advance(port, now: int) -> void:
	var revision := _revision
	for shot in _pending.duplicate():
		if revision != _revision: return # A callback reset/restored the world.
		if not _current(port, shot):
			_pending.erase(shot)
			continue
		if shot.get("melee_shape", false):
			if now >= int(shot.due):
				port.sound(shot.player, shot.form, shot.origin, true)
				port.claim_spirit(shot.player, shot.stats, 1)
				port.melee(shot.player, shot.origin, shot.aim, shot.form, shot.stats, now)
				if revision != _revision: return
				port.finish_spirit(shot.player, shot.stats)
				_pending.erase(shot)
			continue
		if now < int(shot.release): continue
		var rays: Array = [shot]
		if not shot.emitted:
			_release(port, shot)
			port.sound(shot.player, shot.form, shot.origin, false)
			rays = _volley(port, shot)
			port.claim_spirit(shot.player, shot.stats, rays.size())
			if shot.stats.get("ranger_ordinary", false):
				var grants: Dictionary = port.ranger_grants(shot.player, shot.form, shot.stats, now)
				if grants.has("follow_hp"): shot.ranger_follow_hp = grants.follow_hp
				if grants.has("secondary_stats"):
					_serial += 1
					var extra: Dictionary = shot.duplicate()
					extra.erase("ranger_follow_hp")
					extra.merge({"queue_id":_serial, "hit_group":_serial, "ranger_secondary":true,
						"hits":[], "remaining":1, "stats":_freeze(grants.secondary_stats.duplicate(true))}, true)
					rays.append(extra)
			for ray in rays:
				if not is_same(ray, shot): _pending.append(ray)
				ray.visual_event_id = port.show_projectile(ray.player, ray.form, ray.origin, ray.aim,
					maxf(.03, (int(ray.due) - int(ray.release)) / 1000.0), ray.stats, ray.get("ranger_secondary", false), int(ray.get("sequence",-1)),
					ray.direction, int(ray.get("fan_rim",1)))
		for ray in rays:
			var complete := _advance_ray(port, ray, now, revision)
			if revision != _revision: return
			if complete:
				if ray.has("visual_event_id"): port.end_projectile(ray.visual_event_id, ray.origin, ray.get("visual_stop", ray.aim))
				if not ray.get("ranger_secondary", false): port.finish_spirit(ray.player, ray.stats)
				_pending.erase(ray)

func _release(port, shot: Dictionary) -> void:
	var facts: Dictionary = {"position":shot.replica_position,"direction":shot.direction} if shot.get("replica",false) else port.release_facts(shot.player, shot.direction, int(shot.get("aim_combo", -1)))
	var profile := Motion.profile(shot.form)
	var path: Dictionary = port.projectile_path(facts.position, facts.direction, shot.form, float(shot.stats.reach))
	shot.merge({"emitted":true, "direction":facts.direction, "launch_position":facts.position,
		"origin":path.from, "previous":path.from, "muzzle_blocked":path.muzzle_blocked, "aim":path.to}, true)
	shot.due = int(shot.release) + _flight_ms(path.from, path.to, profile)

func _volley(port, shot: Dictionary) -> Array:
	var profile := Motion.profile(shot.form)
	var count := int(profile.get("projectiles", 1))
	if count == 1 or shot.muzzle_blocked: return [shot]
	count = mini(5, count + maxi(0, int(shot.stats.targets) - 2))
	var rays: Array = [shot]
	for index in range(1, count):
		var fraction := ceilf(index * .5) / ceilf((count - 1) * .5)
		var direction: Vector3 = shot.direction.rotated(Vector3.UP, float(profile.spread) * fraction * (1.0 if index % 2 == 1 else -1.0))
		var end: Vector3 = port.projectile_endpoint(shot.origin, Vector3(shot.launch_position) + direction * float(shot.stats.reach), float(profile.projectile_radius))
		_serial += 1
		var petal: Dictionary = shot.duplicate() # Shared hit group and frozen stats.
		petal.queue_id = _serial
		petal.fan_rim = 2 if index % 2 == 1 else 0
		petal.aim = end
		petal.due = int(shot.release) + _flight_ms(shot.origin, end, profile)
		rays.append(petal)
	for ray in rays: ray.remaining = 1
	return rays

func _advance_ray(port, shot: Dictionary, now: int, revision: int) -> bool:
	var fraction := clampf((now - int(shot.release)) / float(maxi(1, int(shot.due) - int(shot.release))), 0, 1)
	var at := Vector3(shot.origin).lerp(shot.aim, fraction)
	var previous: Vector3 = shot.previous
	var contacts: Array = port.swept_contacts(previous, at, float(Motion.profile(shot.form).projectile_radius),
		int(shot.get("locked_target", -3)), str(shot.get("locked_token", "")))
	for entry in contacts:
		if int(shot.remaining) <= 0 or not _current(port, shot): break
		var target: int = entry.id
		var point: Vector3 = entry.point
		if not port.target_current(target, int(entry.token)) or shot.hits.has(port.target_token(target)): continue
		if not shot.hits.is_empty() and shot.form != "fan": port.pierce(previous, point, target)
		shot.hits.append(port.target_token(target))
		shot.remaining -= 1
		var hit: Dictionary = shot.stats.duplicate(true)
		hit.shot_distance = port.target_distance(target, shot.get("launch_position", shot.origin))
		if not shot.get("ranger_secondary", false):
			hit.ranger_direct_hit = true
			if shot.has("ranger_follow_hp"):
				hit.native_bonus_hp = int(shot.ranger_follow_hp)
				shot.erase("ranger_follow_hp")
		port.hit(shot.player, target, shot.origin, point, Vector3(shot.origin).direction_to(shot.aim), hit, now)
		if revision != _revision: return false
		if shot.stats.pattern in ["chain", "splash"]:
			var budget := maxi(0, int(shot.stats.targets) - shot.hits.size()) if shot.form == "fan" else int(shot.remaining)
			var hits: Array = port.secondary(shot.player, shot.stats, point, shot.hits.duplicate(), budget)
			if revision != _revision: return false
			shot.hits.assign(hits)
			shot.remaining = 0
		if int(shot.remaining) <= 0: shot.visual_stop = point
		port.finish_encounter(shot.player, point)
		if revision != _revision: return false
	shot.previous = at
	return now >= int(shot.due) or int(shot.remaining) <= 0

func _current(port, shot: Dictionary) -> bool:
	return port.current(int(shot.player), int(shot.epoch), int(shot.life), int(shot.binding))

func pending_count() -> int:
	return _pending.size()

func is_empty() -> bool:
	return _pending.is_empty()

func clear() -> void:
	_pending.clear()
	_revision += 1

## Detached presentation/debug data. Event objects remain owned by their event
## system; views expose only their scalar identity, never a mutable event handle.
func views() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for shot in _pending: result.append(_view(shot))
	result.make_read_only()
	return result

func inspect(queue_id: int) -> Dictionary:
	for shot in _pending:
		if int(shot.queue_id) == queue_id: return _view(shot)
	return {}

func savepoint() -> Dictionary:
	return {"serial":_serial, "pending":_pending.duplicate(true)}

func restore_savepoint(saved: Dictionary) -> void:
	clear()
	_serial = maxi(_serial, int(saved.serial))
	var groups := {}
	for source in saved.pending:
		var shot: Dictionary = source.duplicate(true)
		var group: int = shot.hit_group
		if not groups.has(group): groups[group] = shot.hits
		shot.hits = groups[group]
		shot.stats = _freeze(shot.stats)
		_pending.append(shot)

static func _flight_ms(origin: Vector3, end: Vector3, profile: Dictionary) -> int:
	return maxi(30, roundi(origin.distance_to(end) / float(profile.speed) * 1000))

static func _freeze(value: Variant) -> Variant:
	if value is Dictionary:
		for key in value: _freeze(value[key])
		value.make_read_only()
	elif value is Array:
		for child in value: _freeze(child)
		value.make_read_only()
	return value

static func _view(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = _view(value[key])
		result.make_read_only()
		return result
	if value is Array:
		var result: Array = []
		for child in value: result.append(_view(child))
		result.make_read_only()
		return result
	if value is Events:
		return _freeze({"identity":value.identity, "actor":value.actor, "source":value.source,
			"epoch":value.epoch, "life_generation":value.life_generation})
	return value
