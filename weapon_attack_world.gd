extends RefCounted
## World integration for ordinary weapon attacks. The queue owns scheduled
## attacks; this port exposes facts and explicit operations, never actor records.
## Collision/damage remain with WeaponContact, OutgoingHits and the terrain API.
const Actions = preload("res://player_weapon_actions.gd")
const Lifecycle = preload("res://player_lifecycle.gd")
const Life = preload("res://expedition_life.gd")
const Motion = preload("res://weapon_motion.gd")
const Contact = preload("res://weapon_contact.gd")
const Hurt = preload("res://enemy_hurtbox.gd")
const Mouse = preload("res://mouse_combat.gd")
const Events = preload("res://combat_action_events.gd")
const Spirit = preload("res://spirit_affinity.gd")
const Outgoing = preload("res://outgoing_hits.gd")
const Frames = preload("res://weapon_frames.gd")
const Classes = preload("res://class_catalog.gd")
var _world: Node

func _init(world: Node) -> void:
	_world = world

func start_facts(peer: int, now: int) -> Dictionary:
	var actor: Dictionary = _world.players.get(peer, {})
	if not _world.multiplayer.is_server() or not Life.alive(actor): return {}
	if not actor[Actions.STATE].ready(now): return {}
	return {"form":Motion.form(actor), "mouse":bool(actor.get("mouse_aim", false))}

func capture_attack(peer: int, now: int) -> Dictionary:
	var actor: Dictionary = _world.players[peer]
	var stats: Dictionary = _world.combat_build(actor).basic_stats()
	if Motion.form(actor) == "spear" and _world.developer_tuning != null and _world.developer_tuning.authorized(_world):
		var tuning = _world.developer_tuning
		stats.reach += tuning.applied(tuning.SPEAR) - tuning.baseline(tuning.SPEAR)
	stats.interval = preload("res://basic_attack_timing.gd").interval(int(stats.interval),preload("res://basic_attack_timing.gd").temporary_percent(_world,actor,now))
	var build: Dictionary = stats.get("affinity_build", {})
	if build.is_empty(): return stats
	var refusal := preload("res://affinity_build.gd").refusal(build, "form")
	if not refusal.is_empty():
		_world.tell(peer, refusal)
		return {}
	var form: Dictionary = build.form
	var ready: bool = form.state == "ready"
	var event := Events.begin(_world, peer, "form" if ready else "native_weapon", form if ready else {},
		form.potency_profile.values if ready else {}, ["weapon_contact", "secondary"], now + 15000)
	var grafts = preload("res://native_grafts.gd")
	var captured: Dictionary = grafts.capture(actor, build.improvements.adaptations)
	if not captured.is_empty(): stats[grafts.CONTEXT] = captured
	if int(actor.frame) == Frames.REAPER and not build.class_skills.is_empty():
		preload("res://reaper_combat.gd").commit_melee(_world, actor, build.class_skills[0].get("native_skill", {}), stats, now)
	preload("res://thorn_affinity.gd").capture_attack(_world,actor,stats,now)
	stats[Events.CONTEXT] = event
	stats.erase("affinity_build")
	if int(actor.frame) == Frames.RANGER and actor.character.has(Classes.Ranger.PROFILE_KEY):
		stats.ranger_ordinary = true
	return stats

func start_timeline(peer: int, stats: Dictionary, form: String, now: int) -> int:
	var actor: Dictionary = _world.players[peer]
	var started = actor[Actions.STATE].try_start(now, int(stats.interval), roundi(float(Motion.profile(form).duration) * 1000), float(stats.reach), form)
	if started == null: return -1
	actor[Actions.STATE] = started
	if form=="spear" and _world.developer_tuning != null and _world.developer_tuning.authorized(_world):
		var tune = _world.developer_tuning
		tune.last_used[tune.SPEAR] = tune.applied(tune.SPEAR)
	var variant := Motion.basic_variant(form, started.basic_step())
	if not variant.is_empty(): stats.weapon_variant = variant.clip
	preload("res://vital_combat.gd").launch(_world,actor,stats,now)
	Spirit.basic_launch(_world,actor,stats,now)
	actor.cast_until = 0
	return started.duration_ms()

func aim_at_target(peer: int, origin: Vector3, reach: float, form: String) -> int:
	var actor: Dictionary = _world.players[peer]
	var ranged := Motion.is_projectile(form)
	var target: int = preload("res://class_ability_targeting.gd").automatic(_world, actor, reach, Motion.profile(form) if ranged else {})
	var aim := origin if target == -2 else Hurt.contact(_world, target, origin, ranged)
	if target == -2 or origin.distance_to(aim) > reach: return -2
	if aim.distance_to(origin) > .001: actor.facing = origin.direction_to(aim)
	return target

func no_target(peer: int) -> void:
	_world.tell(peer, "No enemy within clear weapon reach.")

func prepare_pose(peer: int, form: String, stats: Dictionary, release: int) -> Dictionary:
	var actor: Dictionary = _world.players.get(peer, {})
	if not Life.alive(actor): return {}
	var mouse: bool = actor.get("mouse_aim", false)
	var direction: Vector3 = (actor.get("aim_direction", actor.facing) if mouse else actor.facing).normalized()
	actor.facing = direction
	var shape := Contact.describe(form, stats)
	actor[Actions.STATE] = actor[Actions.STATE].with_pose(direction, shape.clip, shape.pattern, float(shape.span))
	var sequence: int = actor[Actions.STATE].sequence()
	if mouse and Motion.is_projectile(form): actor[Actions.STATE] = actor[Actions.STATE].follow_cursor_until(release)
	return {"direction":direction, "mouse":mouse, "sequence":sequence,
		"epoch":_world.participation.epoch(), "life":Lifecycle.generation(actor), "binding":_world.network_session.binding(peer)}

func current(peer: int, epoch: int, life: int, binding: int) -> bool:
	var actor: Dictionary = _world.players.get(peer, {})
	return _world.multiplayer.is_server() and epoch == _world.participation.epoch() \
		and binding == _world.network_session.binding(peer) and Life.alive(actor) and Lifecycle.matches(actor, life)

func release_facts(peer: int, direction: Vector3, sequence: int) -> Dictionary:
	var actor: Dictionary = _world.players[peer]
	if sequence >= 0 and actor.get("mouse_aim", false):
		direction = actor.get("aim_direction", direction)
		actor[Actions.STATE] = actor[Actions.STATE].sample_release(sequence, direction)
	return {"position":Vector3(actor.pos), "direction":direction}

func projectile_path(origin: Vector3, direction: Vector3, form: String, reach: float) -> Dictionary:
	return Mouse.projectile_path(_world.battlefield, origin, direction, Motion.profile(form), reach)

func projectile_endpoint(origin: Vector3, end: Vector3, radius: float) -> Vector3:
	return _world.battlefield.projectile_endpoint(origin, end, radius)

func target_token(target: int) -> String:
	return Contact.token(_world, target)

func telegraph(peer: int, origin: Vector3, end: Vector3, stats: Dictionary, now: int) -> void:
	_world.emit_weapon_attack(_world.players[peer], origin, end, stats, now)

func sound(peer: int, form: String, origin: Vector3, is_melee: bool) -> void:
	preload("res://event_audio.gd").weapon(_world, form, _world.players[peer].pos if is_melee else origin)

func show_projectile(peer: int, form: String, origin: Vector3, end: Vector3, flight: float, stats: Dictionary, secondary_effect: bool, source_sequence: int = -1, volley_direction := Vector3.ZERO, fan_rim := 1) -> int:
	var color: Color = _world.weapon_effect_color(_world.players[peer])
	if secondary_effect: color = color.lerp(Color("#e6bd69"), .65)
	var description:=Contact.describe(form,stats)
	if form in ["staff","wand","orb","bow","crossbow","ring","fan"] and not stats.get("spirit_replica",false):
		var actor: Dictionary=_world.players[peer]
		var look:=preload("res://character_appearance.gd").normalize(Array(actor.character.get("appearance",[])))
		var variants: Array=Motion.profile(form).basic_variants
		if not variants.any(func(v):return v.clip==description.clip):description.clip=variants[0].clip
		description.owner=peer
		description.weapon_release={"position":[actor.pos.x,actor.pos.y,actor.pos.z],"yaw":atan2((end-origin).x,(end-origin).z),"body":int(look[5]),"height":lerpf(.92,1.08,float(look[6])/100.0)}
		if form=="fan":
			description.weapon_release.rim=fan_rim
			if not volley_direction.is_zero_approx():
				description.weapon_release.yaw=atan2(volley_direction.x,volley_direction.z)
	_world.emit_combat_event("projectile", str(Motion.profile(form).shape), origin, end, flight, color, float(stats.reach), source_sequence if form in ["staff","wand","orb","bow","crossbow","ring","fan"] else 0, description)
	return _world.combat_event_serial

func end_projectile(event_id: int, origin: Vector3, end: Vector3) -> void:
	_world.emit_combat_event("projectile_end", str(event_id), origin, end, .15, Color.WHITE, 0, 0)

func claim_spirit(peer: int, stats: Dictionary, lanes: int) -> void:
	var actor: Dictionary = _world.players[peer]
	if actor.has(Spirit.FOLLOW) and not stats.get("spirit_replica",false): Spirit.launch(_world, actor, stats, lanes)

func finish_spirit(peer: int, stats: Dictionary) -> void:
	var actor: Dictionary = _world.players.get(peer, {})
	if actor.has(Spirit.FOLLOW) and not stats.get("spirit_replica",false): Spirit.finish(_world, actor, stats)

func ranger_grants(peer: int, form: String, stats: Dictionary, now: int) -> Dictionary:
	return preload("res://ranger_combat.gd").launch_grants(_world, _world.players[peer], peer, form, stats, now)

func melee(peer: int, origin: Vector3, end: Vector3, form: String, stats: Dictionary, now: int) -> void:
	# WeaponContact may update this local packet. It cannot edit queue records.
	Contact.melee(_world, {"player":peer, "origin":origin, "aim":end, "form":form, "stats":stats}, now)

func swept_contacts(previous: Vector3, at: Vector3, radius: float, locked: int, locked_token: String) -> Array:
	var result: Array = []
	for target in range(-1, _world.encounter.scout_count()):
		if not _world.Traits.valid_target(_world, target): continue
		if target == locked and target_token(target) != locked_token: continue
		var collision := Hurt.sweep(_world, target, previous, at, radius)
		if not collision.is_empty(): result.append({"id":target, "token":_world.encounter.token(target), "distance":float(collision.fraction), "point":collision.point})
	result.sort_custom(func(a,b): return a.distance < b.distance or (a.distance == b.distance and a.id < b.id))
	return result

func target_current(target: int, token: int) -> bool:
	return _world.encounter.alive(target, token)

func target_distance(target: int, origin: Vector3) -> float:
	return origin.distance_to(_world.enemy_position(target))

func pierce(previous: Vector3, point: Vector3, target: int) -> void:
	preload("res://combat_status.gd").proc(_world, "pierce", previous, point, target)

func hit(peer: int, target: int, origin: Vector3, point: Vector3, forward: Vector3, stats: Dictionary, now: int) -> void:
	Outgoing.hit_world(_world, peer, target, origin, stats, now)
	if stats.has(Events.CONTEXT):
		Events.contact(_world, stats, target, now, false, point, forward)

func secondary(peer: int, stats: Dictionary, point: Vector3, hits: Array, budget: int) -> Array:
	# The queue supplies a detached contact list, not its authoritative shared set.
	Contact.secondary(_world, _world.players[peer], stats, point, hits, budget)
	return hits

func finish_encounter(peer: int, point: Vector3) -> void:
	if _world.encounter_cleared(): _world.finish_combat(peer, point)


func release_mirrors(peer: int, stats: Dictionary, form: String, now: int, duration: int) -> void:
	load("res://spirit_replicas.gd").weapon(_world,peer,stats,form,now,duration)
