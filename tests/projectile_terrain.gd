extends SceneTree
const WeaponCase = preload("res://tests/support/weapon_attack_case.gd")
const ClassActions = preload("res://native_class_actions.gd")
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const WeaponActions = preload("res://player_weapon_actions.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")

const Cooldowns = preload("res://player_cooldowns.gd")

const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Surface = preload("res://assets/terrain_m02/wilds_play_surface.gd")
const Navigation = preload("res://assets/terrain_m02/wilds_combat_navigation.gd")
const Wilds = preload("res://battlefield.gd")
const Battlefield = preload("res://battlefield.gd")
const Motion = preload("res://weapon_motion.gd")
const Mouse = preload("res://mouse_combat.gd")
const Hurt = preload("res://enemy_hurtbox.gd")
const Aim = preload("res://ability_aim.gd")
const Core = preload("res://core_combat.gd")
const Storm = preload("res://storm_affinity.gd")
const EnemyAttack = preload("res://enemy_attack.gd")
const BANK := Vector3(-2.9, 0, 0)
const ACROSS := Vector3(1.3, 0, 0)
const BOULDER := Vector3(1.45, 0, -2.5)
const BOULDER_RADIUS := .56

var game: Node
var field: Wilds
var player: Dictionary
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL TC01: ", label)

func rectangle(id: String, left: float, top: float, right: float, bottom: float) -> Dictionary:
	return Shape.shape(id, id, PackedVector2Array([Vector2(left, top), Vector2(right, top),
		Vector2(right, bottom), Vector2(left, bottom)]))

func floor_fixture() -> Wilds:
	var arena := Shape.shape("playable", "arena", PackedVector2Array([
		Vector2(-8, -7), Vector2(-1, -7), Vector2(-1, -5), Vector2(1, -5),
		Vector2(1, -7), Vector2(8, -7), Vector2(8, 7), Vector2(-8, 7),
	]))
	var water := [rectangle("river", -.65, -7, .65, 7)]
	var rubble := Shape.disk("satellite", "rock", Vector2(-1.65, 0), .27)
	rubble.cover_role = Shape.LOW_RUBBLE
	var boulder := Shape.disk("boulder", "rock", Wilds.planar(BOULDER), BOULDER_RADIUS)
	boulder.cover_role = Shape.SOLID_COVER
	var unknown := Shape.disk("unclassified", "rock", Vector2(3, 0), .22)
	var wall := rectangle("wall", -3.60, -4.8, -3.45, -3.2)
	var result := Wilds.new()
	result.ground = Surface.new({}, {
		"masses": [wall], "rocks": [rubble, boulder, unknown], "water": water,
		"crossings": [rectangle("bridge", -2.2, 2.9, 2.2, 4.7)],
		"plants": [
			{"id":"trunk", "kind":"tree", "center":Vector2(1.6, 1.8), "height":5.0},
			{"id":"leaves", "kind":"fern", "center":Vector2(0, 0), "height":2.0},
		],
		"boundary": {"playable":arena, "rim":[], "water":water},
		"trail_network": {"nodes": {}, "edges": []}, "paths": [], "clearings": [],
	}, 1.75)
	return result

func surface_checks() -> void:
	var east := Vector3.RIGHT
	var bow := Motion.profile("bow")
	var radius: float = bow.projectile_radius
	check(field.projectile_endpoint(BANK,ACROSS,radius).is_equal_approx(ACROSS),
		"a clear segment ends at its finite requested endpoint")
	check(field.combat_sight(BANK, ACROSS) and field.projectile_clear(BANK, ACROSS, radius),
		"water, foliage and explicitly low rubble leave sight and flight clear")
	check(not field.clear_line(BANK, ACROSS) and field.occupied(Vector3(-1.65, 0, 0), .34)
		and field.dash(BANK, ACROSS).x < -1.65, "low rubble still blocks actor lines and travel")
	var open_bank := Vector3(-2.0, 0, .85)
	var other_bank := Vector3(2.0, 0, .85)
	var nav := Navigation.new(field.ground)
	check(field.dash(open_bank, other_bank).x < -.65 and not nav.traversable(Wilds.planar(open_bank), Wilds.planar(other_bank)),
		"player dash and enemy navigation cannot cross open water")
	check(field.occupied(Vector3(0, 0, .85)) and not field.can_spawn(Vector3(0, 0, .85)),
		"water remains unavailable for occupied centers and spawns")
	var deck_from := Vector3(-2, 0, 3.8)
	var deck_to := Vector3(2, 0, 3.8)
	check(field.dash(deck_from, deck_to).is_equal_approx(deck_to)
		and nav.traversable(Wilds.planar(deck_from), Wilds.planar(deck_to))
		and nav.traversable(Wilds.planar(deck_to), Wilds.planar(deck_from)), "bridge still fits actors in both directions")
	var edge := Vector3(0, 0, .79)
	check(field.dash(deck_from + edge, deck_to + edge).x < 0.0
		and field.projectile_clear(deck_from + edge, deck_to + edge, radius), "bridge-edge shot uses projectile clearance")
	var glance := BOULDER + Vector3(-4, 0, BOULDER_RADIUS + radius * .5)
	check(field.combat_sight(glance, glance + 6.0 * east) and not field.projectile_clear(glance, glance + 6.0 * east, radius),
		"boulder catches the arrow radius at a glancing angle")
	check(Hurt.projectile_contact(field, BOULDER-4.0*east, BOULDER+east, BOULDER, BOULDER_RADIUS, radius).is_empty(),
		"cover takes precedence over simultaneous enemy contact")
	check(not field.combat_sight(Vector3(-2,0,1.8), Vector3(3,0,1.8))
		and not field.combat_sight(ACROSS, Vector3(4,0,0)), "trunk and unknown rock are solid")
	var blocked_muzzle := Mouse.projectile_path(field, Vector3(-4,0,-4), east, bow, 6.0)
	check(blocked_muzzle.muzzle_blocked and blocked_muzzle.from.x == -4.0 and blocked_muzzle.to.x < -3.60,
		"an offset muzzle cannot start a projectile beyond a thin wall")
	var exit := field.projectile_endpoint(Vector3(-3,0,-6), Vector3(3,0,-6), radius)
	check(is_equal_approx(exit.x, -1.0 - radius) and not field.combat_sight(Vector3(-3,0,-6), Vector3(3,0,-6)),
		"swept radius stops at first concave arena edge even when the destination is inside")
	var boss := Battlefield.new()
	boss.configure(0,1,91247,22,0)
	var rib: Rect2=boss.barriers[0]
	var from := Vector3(rib.position.x-2,0,rib.get_center().y)
	var to := Vector3(rib.end.x+2,0,rib.get_center().y)
	check(not boss.combat_sight(from,to) and not boss.projectile_clear(from,to,radius)
		and boss.dash(from,to).distance_to(to)>.34,"modern authored Nest ribs block sight, projectile radius and actors")

func prepare(origin: Vector3, foe: Vector3) -> void:
	game.weapon_attacks.clear()
	game.encounter.clear_scouts()
	game.combat_events.clear()
	game.trait_events.clear()
	game.enemy_traits.clear()
	game.enemy_kind = 0
	game.enemy_growth = 0
	game.enemy_mutations = 0
	game.tactics.position = foe
	game.encounter.set_hp(-1, 100)
	game.tactics.rooted_until = 0
	game.encounter_rewarded = false
	player.pos = origin
	player.facing = Vector3.RIGHT
	player.aim_direction = Vector3.RIGHT
	player[WeaponActions.STATE] = player[WeaponActions.STATE].with_ready_at(0)
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.R, 0)
	player.cast_until = 0
	player.core_cast_until = 0
	player.core_ready_at = 0
	player.weapon_kind = 0
	player.weapon = 0
	player.mouse_aim = false
	player.erase("class_aim")
	player.erase("class_aim_distance")
	player.character = game.Character.blank()
	var tree: RefCounted = game.Classes.connected_tree(int(player.frame))
	player.character[tree.profile_key] = tree.state([tree.nodes[0].id])
	Core.reset(game)

func scout(at: Vector3) -> Dictionary:
	var foe: Dictionary = game.make_scout(0, at, game.encounter.scout_count() + 1)
	foe.hp = 100
	game.encounter.register_scout(foe)
	return foe

func finish_shots() -> Dictionary:
	if not check_queue():
		return {}
	var shot: Dictionary = game.weapon_attacks.views().front()
	var contacts: Array = []
	var observe := func(_peer: int, target: int): contacts.append("leader" if target == -1 else str(game.encounter.token(target)))
	game.outgoing_contact_requested.connect(observe)
	WeaponCase.advance(game,int(shot.release))
	WeaponCase.advance(game,int(shot.release) + 2000)
	game.outgoing_contact_requested.disconnect(observe)
	return shot.merged({"contacts":contacts})

func check_queue() -> bool:
	var queued: bool = not game.weapon_attacks.is_empty()
	check(queued, "weapon route queued an actual projectile")
	return queued

func event_point(event: Dictionary) -> Vector3:
	return Vector3(event.to[0], event.to[1], event.to[2])

func weapon_checks() -> void:
	prepare(BANK, ACROSS)
	WeaponCase.start(game,game.HOST,player.pos)
	var bow := finish_shots()
	check(not bow.is_empty() and bow.get("locked_target") == -1 and game.enemy_health() < 100,
		"the actual Vine Bow selects and hits an enemy across water and rubble")
	for form in ["crossbow", "ring", "staff", "wand", "orb", "fan"]:
		var path := Mouse.projectile_path(field, BANK, Vector3.RIGHT, Motion.profile(form), 4.5)
		check(path.to.x > .65 and not path.muzzle_blocked, "open-water path for " + form)

	var origin := Vector3(-3.2,0,-2.5)
	var behind := Vector3(2.9,0,-2.5)
	prepare(origin, behind)
	var first := scout(Vector3(-2.05,0,-2.5))
	var second := scout(Vector3(-1.15,0,-2.5))
	var stats: Dictionary = game.weapon_stats(player)
	stats.targets = 3
	WeaponCase.schedule(game,game.HOST,origin,stats,Time.get_ticks_msec(),"bow",300)
	var piercing := finish_shots()
	check(not piercing.is_empty() and piercing.contacts.size() == 2 and piercing.contacts[0] == "1" and piercing.contacts[1] == "2"
		and game.encounter.hp_for(first) < 100 and game.encounter.hp_for(second) < 100 and game.enemy_health() == 100, "piercing resolves two ordered contacts before solid cover")
	var end_events: Array = game.combat_events.filter(func(event): return event.kind == "projectile_end")
	check(end_events.size() == 1 and event_point(end_events[0]).is_equal_approx(piercing.get("aim", Vector3.INF)),
		"remaining pierce budget keeps the wall as the visual endpoint")

	prepare(BANK, Vector3(-1.15,0,0))
	var across := scout(ACROSS)
	stats = game.weapon_stats(player)
	stats.pattern = "chain"
	stats.targets = 2
	WeaponCase.schedule(game,game.HOST,BANK,stats,Time.get_ticks_msec(),"bow",300)
	var chain := finish_shots()
	check(not chain.is_empty() and chain.contacts.size() == 2 and game.encounter.hp_for(across) < 100 and game.enemy_health() < 100,
		"native chain jumps across water once after a valid first contact")
	prepare(origin, Vector3(.75,0,-2.1))
	var hidden := scout(behind)
	check(Storm.nearest(game, game.tactics.position, 3.0, {"leader":true}) == -2,
		"Storm hop cannot reach a target directly behind solid cover")
	stats = game.weapon_stats(player)
	stats.pattern = "chain"
	stats.targets = 2
	player.aim_direction = Vector3.RIGHT
	player.facing = player.pos.direction_to(game.tactics.position)
	WeaponCase.schedule(game,game.HOST,origin,stats,Time.get_ticks_msec(),"bow",300)
	var blocked_chain := finish_shots()
	check(not blocked_chain.is_empty() and blocked_chain.contacts.size() == 1 and game.encounter.hp_for(hidden) == 100 and game.enemy_health() < 100,
		"native chain stops before obstructed target")

	prepare(Vector3(-3.2,0,-3.3), behind)
	var overlap := scout(Vector3(-2.4,0,-3.3))
	var fan_stats: Dictionary = game.weapon_stats(player)
	fan_stats.pattern = "line"
	fan_stats.targets = 2
	WeaponCase.schedule(game,game.HOST,player.pos,fan_stats,Time.get_ticks_msec(),"fan",300)
	var fan := finish_shots()
	var fan_events: Array = game.combat_events.filter(func(event): return event.kind == "projectile")
	check(fan_events.size() == 3 and game.encounter.hp_for(overlap) < 100 and fan.get("contacts", []).count(str(game.encounter.token_for(overlap))) == 1
		and game.enemy_health() == 100, "fan rays clip independently and share one hit token")
	if fan_events.size() == 3:
		# One petal meets the boulder while the center ray passes below it.
		check(event_point(fan_events[0]).x > event_point(fan_events[1]).x
			or event_point(fan_events[0]).x > event_point(fan_events[2]).x, "at least one spread ray has an independently shortened endpoint")

func class_checks() -> void:
	for far_side in [true, false]:
		var origin := BANK if far_side else Vector3(-2.9,0,-2.5)
		var foe := ACROSS if far_side else Vector3(2.8,0,-2.5)
		prepare(origin, foe)
		player.class_aim = Vector3.RIGHT
		var salvo := Aim.footprint(game,player,field,0,Vector3.RIGHT,6.0)
		var strip: Array = salvo.shapes.filter(func(shape):return shape.kind=="strip")
		ClassActions.cast_world(game, game.HOST, 0)
		var releases: Array = game.combat_events.filter(func(event):return event.shape=="hunter")
		if releases.is_empty():
			releases = game.combat_events.filter(func(event):return event.kind=="subclass_release")
		check((game.enemy_health() < 100) == far_side and strip.size() == 1 and releases.size() == 1
			and event_point(releases[0]).is_equal_approx(strip[0].to), "Hunter's Salvo uses its traced strip for preview, hit and release")

	prepare(BANK, ACROSS)
	player.class_aim = Vector3.RIGHT
	player.class_aim_distance = 5.0
	ClassActions.cast_world(game, game.HOST, 1)
	var traps: Array = game.trait_events.filter(func(event):return event.kind == "snare")
	check(traps.size() == 1 and traps[0].position.x < -1.65 and not field.occupied(traps[0].position),
		"actual Bramble Snare still clamps to unoccupied dry ground")

func core_and_enemy_checks() -> void:
	for far_side in [true, false]:
		prepare(BANK if far_side else Vector3(-2.9,0,-2.5), ACROSS if far_side else Vector3(2.8,0,-2.5))
		player.weapon = game.Parts.index_of("plant:storm_reed")
		var skill := Core.equipped(player)
		check(skill.get("id") == "chain_spark", "Chain Spark is an actual equipped Core skill")
		if skill.get("id") == "chain_spark":
			var aim := Core.preview(game, player, field, Vector3.RIGHT, 0.0)
			Core.command(game,game.HOST,player,Core.request(game,player,Vector2.RIGHT))
			var cast: Dictionary = game.get_meta(Core.STATE,{}).get(game.HOST,{})
			var capsule: Array = aim.shapes.filter(func(shape):return shape.kind=="capsule")
			check(not cast.is_empty() and capsule.size() == 1 and Vector3(cast.to).is_equal_approx(capsule[0].to),
				"ranged Core host endpoint equals preview")
			if not cast.is_empty():
				Core.tick(game,int(cast.release))
				Core.tick(game,int(cast.armed))
			check((game.enemy_health() < 100) == far_side, "Chain Spark crosses water and stops at the boulder")
		var watcher: Dictionary = game.make_scout(1,player.pos,20)
		player.pos = game.tactics.position
		player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(40)
		player[Conditions.STATE] = player[Conditions.STATE].clear_grace()
		player[Protection.STATE] = player[Protection.STATE].clear_expedition()
		watcher.mode = "volley"
		watcher.attack = EnemyAttack.plan(game,watcher,"volley",player.pos)
		preload("res://scout_behavior.gd").release(game, watcher,game.Enemies.get_kind(1),Time.get_ticks_msec())
		check((PlayerVitals.current_hp(player) < 40) == far_side, "actual Watcher volley uses the same cover role and water policy")

func run() -> void:
	field = floor_fixture()
	surface_checks()
	game = preload("res://world.tscn").instantiate()
	game.progress.path = "user://release-fixtures/tc01-garden.cfg"
	game.local_character.path = "user://release-fixtures/tc01-character.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.battlefield = field
	player = game.players[game.HOST]
	SessionCase.set_ready(game, player, true)
	player.frame = game.Frames.RANGER
	ExpeditionCase.set_membership(game, player, true)
	weapon_checks()
	class_checks()
	core_and_enemy_checks()
	game.free()
	if failures == 0:
		print("PASS: TC01 swept cover, movement, weapon, class, Core, enemy and ground routes")
	quit(int(failures != 0))
