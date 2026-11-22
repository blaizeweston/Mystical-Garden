extends RefCounted
## The players mobs train against in the simulation: a scripted party with real classes, stats and tactics.
## It stands in for the game, so the simulation must run with abilities.resolve_hits on; the party reads the
## HIT events mobs make and deals its own damage through MobSim.damage_mob.
##
## Each player has a class (stats, attack and skill) and the party shares a difficulty from 0 to 1, which sets
## reaction time, dodge chance, aim, focus fire and kiting. Players go down at zero health and stay down until
## reset(). At night (darkness below 1) players carry lights and only see lit or nearby mobs, by the same rule
## as the arena (MobPerception.player_sees).
##
## Call before_tick() before MobSim.tick() and after_tick() after it.

const Battlefield = preload("res://battlefield.gd")
const Clock = preload("res://mob_sim/mob_clock.gd")
const CombatClock = preload("res://combat_clock.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const Fields = preload("res://mob_sim/mob_fields.gd")
const Party = preload("res://mob_sim/mob_party.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Species = preload("res://mob_sim/mob_species.gd")

const CLOCK_START_MS := 100000
const PLAN_TICKS := 6
const LIGHT_TICKS := 6
const PLAYER_LIGHT := 5.5
const DODGE_DISTANCE := 3.0
const DODGE_TICKS := 15
const ATTACK_WINDUP_TICKS := 9
const ATTACK_NOISE := 9.0
const MELEE_GRACE := 0.4
const DANGER_MARGIN := 0.7
const RETREAT_HEALTH := 0.3
const VISION := 18.0
## Players ask the game's pathfinder for a waypoint this far ahead every PLAN_TICKS and walk straight to it.
const WAYPOINT_AHEAD := 4.0
## A routed waypoint is reused this long while the way to it stays clear.
const ROUTE_TICKS := 60
const BODY_CLEARANCE := 0.3
## Each step only refuses walls closer than this. The game's router uses gaps the simulation's coarser grid
## rates a little tighter than BODY_CLEARANCE.
const STEP_CLEARANCE := 0.12

## Class profiles in the game's health units (a player has about 100 health and a mob's hit takes about 10).
## range > 3 is ranged; area > 0 splashes; skill is "fire", "root" or "".
const CLASSES := {
	"warrior": {"hp": 115.0, "speed": 5.0, "damage": 16.0, "range": 2.3, "interval": 0.7, "area": 0.0, "armour": 0.25,
		"dodge_s": 2.0, "skill": "", "skill_s": 0.0},
	"rogue": {"hp": 85.0, "speed": 5.8, "damage": 13.0, "range": 1.9, "interval": 0.45, "area": 0.0, "armour": 0.05,
		"dodge_s": 1.2, "skill": "", "skill_s": 0.0},
	"ranger": {"hp": 80.0, "speed": 5.2, "damage": 10.0, "range": 9.0, "interval": 0.75, "area": 0.0, "armour": 0.05,
		"dodge_s": 1.6, "skill": "", "skill_s": 0.0},
	"mage": {"hp": 75.0, "speed": 5.0, "damage": 8.0, "range": 8.0, "interval": 1.1, "area": 1.6, "armour": 0.0,
		"dodge_s": 1.8, "skill": "fire", "skill_s": 8.0},
	"warden": {"hp": 130.0, "speed": 4.7, "damage": 10.0, "range": 2.0, "interval": 0.8, "area": 0.0, "armour": 0.35,
		"dodge_s": 2.2, "skill": "root", "skill_s": 10.0},
}
const FIRE_FIELD := {"radius": 2.5, "ms": 4000, "dps": 10.0}
const ROOT_FIELD := {"radius": 2.2, "ms": 2500}
## A patrolling player moves on to its next point within this distance of the current one.
const PATROL_REACHED := 2.0
## A patrolling player waits while anyone standing is farther behind than this.
const PATROL_GATHER := 5.0
## A player that wants to move but has not covered STUCK_DISTANCE in STUCK_TICKS takes a short detour.
const STUCK_TICKS := 60
const STUCK_DISTANCE := 0.5
const DETOUR_TICKS := 45

var sim: RefCounted
var field: RefCounted
var rng := RandomNumberGenerator.new()
var difficulty := 0.5
## Light level for this episode; below 1 turns darkness on.
var ambient := 1.0
var classes: Array[String] = []
## Points the party walks between while it has no target, in order and looping. Empty: the party idles
## where it stands. Set after reset(), which clears it.
var patrol: Array[Vector2] = []
## How many patrol points each player has reached. Each walks the route on its own, and anyone well ahead
## of the slowest player standing waits for them.
var patrol_leg := PackedInt32Array()
var count := 0
var position: Array[Vector2] = []
var velocity: Array[Vector2] = []
var hp := PackedFloat32Array()
var max_hp := PackedFloat32Array()
var down := PackedByteArray()
var target := PackedInt32Array()
var goal: Array[Vector2] = []
var waypoint: Array[Vector2] = []
var _routed_at := PackedInt32Array()
var _progress_at: Array[Vector2] = []
var _progress_tick := PackedInt32Array()
var _detour_until := PackedInt32Array()
var attack_ready := PackedInt32Array()
var attack_due := PackedInt32Array()
var attack_slot := PackedInt32Array()
var dodge_ready := PackedInt32Array()
var dodge_until := PackedInt32Array()
var rooted_until := PackedInt32Array()
var skill_ready := PackedInt32Array()
## Mob wind-ups already judged for dodging, by slot * 8 + player, mapped to the tick a dodge may start.
var _reaction := {}
var _cursor := 0
## Episode totals for reports.
var damage_taken := 0.0
var damage_dealt := 0.0
var kills := 0
var dodges := 0
var hits_dodged := 0
var detours := 0


func _init(simulation: RefCounted, battlefield: RefCounted, seed_value: int) -> void:
	sim = simulation
	field = battlefield
	rng.seed = seed_value


## Starts an episode: players of the given classes at the given points, at a difficulty and light level.
func reset(party_classes: Array, points: Array, skill: float, light := 1.0) -> void:
	classes.assign(party_classes)
	patrol.clear()
	count = mini(classes.size(), sim.contract.players)
	difficulty = clampf(skill, 0.0, 1.0)
	ambient = light
	position.clear()
	velocity.clear()
	goal.clear()
	waypoint.clear()
	_progress_at.clear()
	for table in [hp, max_hp]:
		table.resize(count)
	for table in [down]:
		table.resize(count)
		table.fill(0)
	for table: PackedInt32Array in [target, attack_ready, attack_due, attack_slot, dodge_ready, dodge_until, rooted_until, skill_ready,
			_routed_at, _progress_tick, _detour_until, patrol_leg]:
		table.resize(count)
		table.fill(0)
	target.fill(-1)
	attack_due.fill(-1)
	var now: int = sim.clock.tick
	for player in count:
		var profile: Dictionary = CLASSES[classes[player]]
		position.append(points[player % points.size()])
		velocity.append(Vector2.ZERO)
		goal.append(position[player])
		waypoint.append(position[player])
		_progress_at.append(position[player])
		hp[player] = profile.hp
		max_hp[player] = profile.hp
		skill_ready[player] = now + Clock.from_ms(float(profile.skill_s) * 500.0)
	for player in range(count, sim.contract.players):
		sim.party.clear_player(player)
	sim.set_darkness(ambient < 1.0, ambient)
	for player in count:
		var profile: Dictionary = CLASSES[classes[player]]
		var ranged: bool = profile.range > 3.0
		sim.party.set_stats(player, PackedFloat32Array([0.0 if ranged else profile.damage, profile.damage if ranged else 0.0,
			0.0 if ranged else profile.range, profile.range if ranged else 0.0, profile.speed, 1.0 / float(profile.interval), profile.armour]))
	_reaction.clear()
	_cursor = sim.events.head
	damage_taken = 0.0
	damage_dealt = 0.0
	kills = 0
	dodges = 0
	hits_dodged = 0
	detours = 0
	for player in count:
		_progress_tick[player] = now
	_publish()


## Sets a patrol of legs points from the party's leader, each with a clear straight line to the one before, so
## the party walks it without the router. open lists candidate points; each leg is leg_min to leg_max long.
## The route returns to where it began. Returns the number of points placed.
func plan_patrol(open: Array, legs: int, leg_min := 8.0, leg_max := 16.0) -> int:
	patrol.clear()
	var leader := _leader()
	if leader < 0 or open.is_empty():
		return 0
	var world = sim.locomotion.world
	var home := position[leader]
	var at := home
	for leg in legs:
		var chosen := Vector2.INF
		for attempt in 40:
			var point: Vector2 = open[rng.randi() % open.size()]
			var length := point.distance_to(at)
			if length >= leg_min and length <= leg_max and world.line_clear(at.x, at.y, point.x, point.y, BODY_CLEARANCE) != 0:
				chosen = point
				break
		if not chosen.is_finite():
			break
		patrol.append(chosen)
		at = chosen
	if not patrol.is_empty():
		patrol.append(home)
	return patrol.size()


func alive_count() -> int:
	var alive := 0
	for player in count:
		alive += int(down[player] == 0)
	return alive


func wiped() -> bool:
	return count > 0 and alive_count() == 0


func before_tick() -> void:
	_publish()


func after_tick() -> void:
	var now: int = sim.clock.tick
	for event in sim.events.read_since(_cursor):
		if int(event.kind) == Events.Kind.HIT:
			_take_hit(event, now)
	_cursor = sim.events.head
	# Party pathing reads combat time, so it follows this encounter's own tick.
	CombatClock.begin_stepped(CLOCK_START_MS + now * 1000 / Clock.TICKS_PER_SECOND)
	for player in count:
		if down[player] == 0:
			_act(player, now)
	CombatClock.end_stepped()


func _publish() -> void:
	var party = sim.party
	var now: int = sim.clock.tick
	var lights := PackedFloat32Array()
	for player in count:
		party.set_player(player, position[player], velocity[player], 0.0 if down[player] != 0 else hp[player], max_hp[player])
		party.set_timers(player, dodge_ready[player], attack_due[player] if attack_due[player] >= 0 else 0, dodge_until[player])
		if ambient < 1.0 and down[player] == 0 and now % LIGHT_TICKS == 0:
			lights.append_array(PackedFloat32Array([snappedf(position[player].x, 0.5), snappedf(position[player].y, 0.5), PLAYER_LIGHT, 1.0]))
	if ambient < 1.0 and now % LIGHT_TICKS == 0:
		var pool = sim.pool
		for slot in pool.active:
			var glow: float = sim.species.glow[pool.species[slot]]
			if glow > 0.0:
				lights.append_array(PackedFloat32Array([snappedf(pool.xz[slot * 2], 0.5), snappedf(pool.xz[slot * 2 + 1], 0.5), glow, 0.9]))
		sim.perception.lights = lights


## A mob's attack reached a player: dodges ignore it, armour reduces it, roots and pulls apply.
func _take_hit(event: Dictionary, now: int) -> void:
	var player := int(event.a)
	if player < 0 or player >= count or down[player] != 0:
		return
	if now < dodge_until[player]:
		hits_dodged += 1
		return
	var amount := float(event.value) * (1.0 - float(CLASSES[classes[player]].armour))
	if amount > 0.0:
		var dealt := minf(amount, hp[player])
		hp[player] -= dealt
		damage_taken += dealt
		sim.record_hit(int(event.slot), int(event.generation), player, dealt)
		if hp[player] <= 0.0:
			down[player] = 1
			attack_due[player] = -1
	if int(event.b) > 0:
		rooted_until[player] = maxi(rooted_until[player], now + int(event.b))
	if float(event.radius) > 0.0:
		position[player] = position[player].move_toward(Vector2(event.from_x, event.from_z), float(event.radius))


func _act(player: int, now: int) -> void:
	var profile: Dictionary = CLASSES[classes[player]]
	if attack_due[player] >= 0 and now >= attack_due[player]:
		_release_attack(player, profile, now)
	if _consider_dodge(player, now):
		return
	if (now + player) % PLAN_TICKS == 0:
		target[player] = _choose_target(player, profile)
		goal[player] = _plan_goal(player, profile)
		if now >= _detour_until[player]:
			waypoint[player] = _waypoint(player)
			_check_progress(player, now)
	_move(player, profile, now)
	_try_attack(player, profile, now)
	_try_skill(player, profile, now)


func _sees(player: int, slot: int) -> bool:
	var at := Vector2(sim.pool.xz[slot * 2], sim.pool.xz[slot * 2 + 1])
	return position[player].distance_to(at) <= VISION and sim.perception.player_sees(position[player], at)


## Nearest mob at low difficulty; at higher difficulty the most wounded within reach, and supports first
## with a chance that grows with difficulty. The party shares a target when one player already has one in sight.
func _choose_target(player: int, profile: Dictionary) -> int:
	var pool = sim.pool
	var best := -1
	var best_score := INF
	var focus := difficulty >= 0.5
	var hunt_support := rng.randf() < difficulty * 0.6
	for slot in pool.active:
		if not _sees(player, slot):
			continue
		var distance := position[player].distance_to(Vector2(pool.xz[slot * 2], pool.xz[slot * 2 + 1]))
		var score := distance
		if focus:
			score = distance * 0.3 + 10.0 * pool.hp[slot] / maxf(1.0, pool.max_hp[slot])
			if distance > float(profile.range) * 2.0:
				score += 6.0
		if hunt_support and sim.species.support[pool.species[slot]] != 0:
			score -= 8.0
		for mate in count:
			if mate != player and down[mate] == 0 and target[mate] == slot:
				score -= 2.0 * difficulty
		if score < best_score:
			best_score = score
			best = slot
	return best


## Where to stand: melee closes in; ranged keeps its distance and backs off from melee mobs; a badly hurt
## player retreats from its target at higher difficulty. With no target, players wander together.
func _plan_goal(player: int, profile: Dictionary) -> Vector2:
	var slot := target[player]
	var at := position[player]
	if slot < 0 or sim.pool.alive[slot] == 0:
		return _wander(player)
	var mob := Vector2(sim.pool.xz[slot * 2], sim.pool.xz[slot * 2 + 1])
	var away := (at - mob).normalized() if not at.is_equal_approx(mob) else Vector2.RIGHT
	var reach := float(profile.range)
	if hp[player] / max_hp[player] < RETREAT_HEALTH and rng.randf() < difficulty:
		return at + away * 4.0
	if reach > 3.0:
		var keep := reach * lerpf(0.9, 0.7, difficulty)
		var nearest := _nearest_mob(at)
		if nearest >= 0 and difficulty > 0.3:
			var threat := Vector2(sim.pool.xz[nearest * 2], sim.pool.xz[nearest * 2 + 1])
			if at.distance_to(threat) < 3.0:
				return at + (at - threat).normalized() * 3.0
		return mob + away * keep + away.orthogonal() * rng.randf_range(-1.5, 1.5) * difficulty
	return mob + away * reach * 0.6


func _wander(player: int) -> Vector2:
	var leader := _leader()
	var lead := position[leader] if leader >= 0 else position[player]
	if patrol.is_empty():
		return lead + Vector2.from_angle(rng.randf() * TAU) * 3.0
	var at := position[player]
	if at.distance_to(_patrol_point(player)) < PATROL_REACHED:
		patrol_leg[player] += 1
	var mine := _patrol_progress(player)
	for mate in count:
		if mate != player and down[mate] == 0 and _patrol_progress(mate) < mine and position[mate].distance_to(at) > PATROL_GATHER:
			return at
	return _patrol_point(player)


func _patrol_point(player: int) -> Vector2:
	return patrol[patrol_leg[player] % patrol.size()]


## Points reached, less the share of the current leg still to walk.
func _patrol_progress(player: int) -> float:
	var point := _patrol_point(player)
	var from := patrol[(patrol_leg[player] + patrol.size() - 1) % patrol.size()]
	var leg := maxf(1.0, from.distance_to(point))
	return patrol_leg[player] - clampf(position[player].distance_to(point) / leg, 0.0, 1.0)


## The first player still standing, or -1.
func _leader() -> int:
	for player in count:
		if down[player] == 0:
			return player
	return -1


func _nearest_mob(at: Vector2) -> int:
	var best := -1
	var best_distance := INF
	for slot in sim.pool.active:
		var distance := at.distance_to(Vector2(sim.pool.xz[slot * 2], sim.pool.xz[slot * 2 + 1]))
		if distance < best_distance:
			best_distance = distance
			best = slot
	return best


## Where to walk next: straight to the goal when the way is clear, otherwise a point a short way along the
## game's route. Routing is by far the costliest part of the party, so a routed point is reused for a while.
func _waypoint(player: int) -> Vector2:
	var at := position[player]
	var to := goal[player]
	var world = sim.locomotion.world
	if at.distance_to(to) < 0.2 or world.line_clear(at.x, at.y, to.x, to.y, BODY_CLEARANCE) != 0:
		return to
	var now: int = sim.clock.tick
	var held := waypoint[player]
	if now - _routed_at[player] < ROUTE_TICKS and held.distance_to(at) > 0.3 and world.line_clear(at.x, at.y, held.x, held.y, BODY_CLEARANCE) != 0:
		return held
	_routed_at[player] = now
	var ahead: Vector3 = field.navigate(Vector3(at.x, 0.0, at.y), Vector3(to.x, 0.0, to.y), WAYPOINT_AHEAD, 200000 + player)
	return Vector2(ahead.x, ahead.z)


## The game's router can stall at some corners. A player that wants to move but has made no progress for a
## while walks a short way in a clear random direction, and a patrolling leader moves on to its next point.
func _check_progress(player: int, now: int) -> void:
	var at := position[player]
	var waiting := now < rooted_until[player] or attack_due[player] >= 0 or at.distance_to(goal[player]) < 1.5
	if waiting or at.distance_to(_progress_at[player]) > STUCK_DISTANCE:
		_progress_at[player] = at
		_progress_tick[player] = now
		return
	if now - _progress_tick[player] < STUCK_TICKS:
		return
	_progress_at[player] = at
	_progress_tick[player] = now
	if not patrol.is_empty() and target[player] < 0:
		patrol_leg[player] += 1
	var world = sim.locomotion.world
	for attempt in 8:
		var landing := at + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.0, 4.0)
		if world.line_clear(at.x, at.y, landing.x, landing.y, BODY_CLEARANCE) != 0:
			waypoint[player] = landing
			_detour_until[player] = now + DETOUR_TICKS
			detours += 1
			return


func _move(player: int, profile: Dictionary, now: int) -> void:
	var at := position[player]
	# Short steps still count: the game's router can slide a player a few centimetres at a time along a corner,
	# and it only finds a way around once the player has actually moved there.
	if now < rooted_until[player] or attack_due[player] >= 0 or at.distance_to(waypoint[player]) < 0.005:
		velocity[player] = Vector2.ZERO
		return
	var next := at.move_toward(waypoint[player], float(profile.speed) * Clock.DT)
	if sim.locomotion.world.clearance(next.x, next.y) < STEP_CLEARANCE:
		velocity[player] = Vector2.ZERO
		return
	velocity[player] = (next - at) / Clock.DT
	position[player] = next


## Starts an attack when the target is in reach and in sight. The swing lands after a short wind-up.
func _try_attack(player: int, profile: Dictionary, now: int) -> void:
	var slot := target[player]
	if slot < 0 or now < attack_ready[player] or attack_due[player] >= 0 or sim.pool.alive[slot] == 0:
		return
	var mob := Vector2(sim.pool.xz[slot * 2], sim.pool.xz[slot * 2 + 1])
	if position[player].distance_to(mob) > float(profile.range) or not _sees(player, slot):
		return
	attack_due[player] = now + ATTACK_WINDUP_TICKS
	attack_slot[player] = slot
	attack_ready[player] = now + Clock.from_ms(float(profile.interval) * 1000.0)
	sim.perception.add_noise(position[player].x, position[player].y, ATTACK_NOISE, player)


func _release_attack(player: int, profile: Dictionary, now: int) -> void:
	attack_due[player] = -1
	var slot := attack_slot[player]
	if slot < 0 or sim.pool.alive[slot] == 0:
		return
	var mob := Vector2(sim.pool.xz[slot * 2], sim.pool.xz[slot * 2 + 1])
	var reach := float(profile.range)
	if position[player].distance_to(mob) > reach + MELEE_GRACE:
		return
	if reach > 3.0:
		if sim.locomotion.world.sight_clear(position[player].x, position[player].y, mob.x, mob.y, 0.0) == 0:
			return
		if rng.randf() < lerpf(0.35, 0.05, difficulty):
			return
	var area := float(profile.area)
	if area > 0.0:
		for other in sim.pool.active.duplicate():
			if Vector2(sim.pool.xz[other * 2], sim.pool.xz[other * 2 + 1]).distance_to(mob) <= area:
				_strike(player, other, float(profile.damage))
	else:
		_strike(player, slot, float(profile.damage))


func _strike(player: int, slot: int, damage: float) -> void:
	var dealt: float = sim.damage_mob(slot, damage, player)
	damage_dealt += dealt
	if dealt > 0.0 and sim.pool.alive[slot] == 0:
		kills += 1


## Dodges a mob wind-up aimed at this player when it would land on them. The reaction delay and the chance
## to react follow difficulty. Returns true when the player dodged this tick.
func _consider_dodge(player: int, now: int) -> bool:
	if now < dodge_ready[player] or now < rooted_until[player]:
		return false
	var pool = sim.pool
	var at := position[player]
	for slot in pool.active:
		if pool.windup_until[slot] <= 0 or pool.aim_player[slot] != player:
			continue
		var key: int = slot * 8 + player
		if not _reaction.has(key):
			var react := rng.randf() < lerpf(0.2, 0.9, difficulty)
			_reaction[key] = now + roundi(lerpf(24.0, 6.0, difficulty)) if react else -1
		var allowed: int = _reaction[key]
		if allowed < 0 or now < allowed:
			continue
		var aim := Vector2(pool.aim_x[slot], pool.aim_z[slot])
		var row: int = pool.species[slot] * Species.ATTACKS + pool.windup_attack[slot]
		var danger: float = sim.species.attack_area[row] + DANGER_MARGIN
		var mob := Vector2(pool.xz[slot * 2], pool.xz[slot * 2 + 1])
		if at.distance_to(aim) > danger and at.distance_to(mob) > sim.species.attack_range[row] + DANGER_MARGIN:
			continue
		var away := (at - aim).normalized() if not at.is_equal_approx(aim) else Vector2.UP
		var side := away.orthogonal() if (slot + player) % 2 == 0 else -away.orthogonal()
		for direction: Vector2 in [side, -side, away]:
			var landing := at + direction * DODGE_DISTANCE
			if sim.locomotion.world.line_clear(at.x, at.y, landing.x, landing.y, 0.35) != 0:
				position[player] = landing
				break
		dodge_until[player] = now + DODGE_TICKS
		dodge_ready[player] = now + Clock.from_ms(float(CLASSES[classes[player]].dodge_s) * 1000.0)
		attack_due[player] = -1
		dodges += 1
		_reaction.erase(key)
		return true
	# Wind-ups that ended leave stale keys; drop them now and then.
	if now % 120 == 0:
		for key in _reaction.keys():
			if pool.windup_until[key / 8] <= 0:
				_reaction.erase(key)
	return false


## Class skills: the mage drops a fire field and the warden a binding field on the densest group of mobs near
## its target. Both are ground fields, so they do not touch flyers.
func _try_skill(player: int, profile: Dictionary, now: int) -> void:
	var skill: String = profile.skill
	var slot := target[player]
	if skill.is_empty() or now < skill_ready[player] or slot < 0 or sim.pool.alive[slot] == 0:
		return
	var at := Vector2(sim.pool.xz[slot * 2], sim.pool.xz[slot * 2 + 1])
	if position[player].distance_to(at) > float(profile.range) + 2.0 or not _sees(player, slot):
		return
	skill_ready[player] = now + Clock.from_ms(float(profile.skill_s) * 1000.0)
	if skill == "fire":
		sim.add_player_field(at, FIRE_FIELD.radius, FIRE_FIELD.ms, player, FIRE_FIELD.dps)
	else:
		sim.add_player_field(at, ROOT_FIELD.radius, ROOT_FIELD.ms, player, 0.0, 1.0, true)
