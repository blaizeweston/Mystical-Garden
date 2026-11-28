extends RefCounted
## Runs training episodes: a real Wilds floor, mobs at the game's health and damage for a random floor, the
## stand-in party (ai/stand_in_party.gd) and the training brain, recording every mob decision.
##
## Two kinds of start, so mobs learn both to fight and to find the party:
## - Engaged: mobs start 9-16 m from the party and usually sense it at once.
## - Explore (explore_share of episodes): mobs start 25-45 m away in a few groups and have not sensed anyone,
##   while the party patrols the floor. Mobs must search, and the first sight of a player earns a small reward.
## Every mob decides through the training brain, awake or not, so searching is learned too.
##
## An episode ends when the party is wiped or every mob is dead, or at its time limit. With time_limit_terminal
## (the default) the time limit is a true end, worth nothing more: bootstrapping it from the critic (truncated)
## let mobs that hid until time ran out collect the critic's own unchecked estimate, which taught them to camp.
## A floor is reused for map_episodes episodes, then a new one is generated. With connected_spawns, the party and
## mobs start only in the largest region the mobs' route grid connects (_connected); without it, any open point.

const Balance = preload("res://enemy_balance.gd")
const Battlefield = preload("res://battlefield.gd")
const Catalog = preload("res://enemy_catalog.gd")
const Clock = preload("res://mob_sim/mob_clock.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const Pace = preload("res://ai/game_pace.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Recorder = preload("res://ai/rollout_recorder.gd")
const Rewards = preload("res://ai/mob_rewards.gd")
const Schema = preload("res://ai/mob_schema.gd")
const Sim = preload("res://mob_sim/mob_sim.gd")
const StandIns = preload("res://ai/stand_in_party.gd")
const TrainingBrain = preload("res://ai/training_brain.gd")

const OPEN_RADIUS := 0.8
const OPEN_CLEARANCE := 0.5
const MUTATIONS := [Catalog.REACH, Catalog.BARK, Catalog.SPORES, Catalog.MOBILITY]
const FLOORS_PER_SITE := 6

var schema: Schema
var recorder: Recorder
var settings: Dictionary
var rng := RandomNumberGenerator.new()
var weights := PackedByteArray()
var policy_version := 0
var squad_mix := 0.2
var error := ""
## The brain each new floor gets: ai/training_brain.gd or a script extending it (the choice test forces choices).
var brain_script: GDScript = TrainingBrain

var field: RefCounted
var sim: Sim
var brain: TrainingBrain
var party: StandIns
var rewards: Rewards
var open: Array[Vector2] = []
var floor_number := 1
var episodes_on_map := 0
var episodes := 0
var ticks := 0
var _species: PackedInt32Array


func _init(model_schema: Schema, rollouts: Recorder, episode_settings: Dictionary, seed_value: int) -> void:
	schema = model_schema
	recorder = rollouts
	settings = episode_settings
	rng.seed = seed_value


## Uses new weights from the next decision on. Returns false when they do not fit the schema.
func set_policy(policy: PackedByteArray, version: int) -> bool:
	if brain != null and not brain.reload(policy, int(settings.capacity)):
		return false
	weights = policy
	policy_version = version
	recorder.policy_version = version
	return true


## Plays one episode into the recorder and returns its report.
func run_episode() -> Dictionary:
	if sim == null or episodes_on_map >= int(settings.map_episodes):
		if not _new_map():
			return {}
	else:
		_clear()
	episodes_on_map += 1
	episodes += 1
	var explore := rng.randf() < float(settings.explore_share)
	var night := rng.randf() < float(settings.night_share)
	var light := _uniform("night_light") if night else 1.0
	var difficulty := _uniform("difficulty")
	var start: Vector2 = open[rng.randi() % open.size()]
	var classes: Array[String] = []
	var size := _fight_size()
	for index in size.x:
		classes.append(settings.classes[rng.randi() % settings.classes.size()])
	party.reset(classes, _near(start, classes.size(), 2.5), difficulty, light)
	if explore or rng.randf() < float(settings.engaged_patrol_share):
		party.plan_patrol(open, int(settings.patrol_legs))
	rewards = Rewards.new(sim)
	rewards.squad_mix = squad_mix
	recorder.rewards = rewards
	brain.episode_start = sim.clock.tick
	brain.probe_symbol = int(settings.get("probe_symbol", -1))
	brain.probe_reward = float(settings.get("probe_reward", 0.0))
	var spawned := _spawn_mobs(start, explore, size.y)
	var report := {"episode": episodes, "policy": policy_version, "mode": "explore" if explore else "engaged", "floor": floor_number,
		"night": night, "party": classes.size(), "difficulty": snappedf(difficulty, 0.01), "mobs": spawned.count,
		"elite": spawned.elite}
	var limit := Clock.from_ms(float(settings.explore_seconds if explore else settings.engaged_seconds) * 1000.0)
	var cursor := sim.events.head
	var began := sim.clock.tick
	var first_found := -1
	var decisions_before := brain.decisions
	var end := Recorder.End.TERMINAL if bool(settings.get("time_limit_terminal", true)) else Recorder.End.TRUNCATED
	var outcome := "timeout"
	for step in limit:
		party.before_tick()
		sim.tick()
		party.after_tick()
		rewards.tick()
		for event in sim.events.read_since(cursor):
			if int(event.kind) == Events.Kind.DEATH:
				recorder.close(int(event.slot), Recorder.End.TERMINAL)
		cursor = sim.events.head
		if first_found < 0 and int(rewards.totals.found) > 0:
			first_found = sim.clock.tick - began
		if party.wiped():
			end = Recorder.End.TERMINAL
			outcome = "wipe"
			break
		if sim.pool.active.is_empty():
			end = Recorder.End.TERMINAL
			outcome = "cleared"
			break
	# The party's last downs reach the simulation and the rewards on one more publish.
	party.before_tick()
	rewards.tick()
	recorder.close_all(end)
	var played := sim.clock.tick - began
	ticks += played
	report.merge({"outcome": outcome, "seconds": snappedf(Clock.to_seconds(played), 0.01), "decisions": brain.decisions - decisions_before,
		"first_sight": snappedf(Clock.to_seconds(first_found), 0.01) if first_found >= 0 else -1.0,
		"mobs_killed": spawned.count - sim.pool.active.size(), "downs": classes.size() - party.alive_count(),
		"damage_to_party": snappedf(party.damage_taken, 0.1), "damage_to_mobs": snappedf(party.damage_dealt, 0.1),
		"dodged": party.hits_dodged, "rewards": rewards.totals.duplicate()})
	if party.hunt:
		report.merge({"party_hunts": party.hunts, "party_hunts_failed": party.hunts_failed})
	recorder.episodes.append(report)
	return report


## Lets go of the current floor. The simulation's handler port refers back to it, so that link is cut first,
## or every replaced floor would stay in memory.
func close() -> void:
	if sim != null:
		sim.abilities.port = null
	if recorder != null:
		recorder.rewards = null
	sim = null
	brain = null
	party = null
	rewards = null
	field = null


func _new_map() -> bool:
	close()
	var floors: Array = settings.floors
	floor_number = rng.randi_range(int(floors[0]), int(floors[1]))
	field = Battlefield.new()
	field.configure((floor_number - 1) / FLOORS_PER_SITE, (floor_number - 1) % FLOORS_PER_SITE + 1, rng.randi_range(1, 2147483646))
	var capacity := int(settings.capacity)
	sim = Sim.new(capacity)
	if sim.configure(field) != OK:
		error = "The floor could not be baked."
		return false
	sim.abilities.resolve_hits = true
	brain = brain_script.new(schema, weights, sim.locomotion.world, sim.events, capacity, rng.randi())
	if not brain.error.is_empty():
		error = brain.error
		return false
	brain.recorder = recorder
	sim.brain = brain
	# Mobs decide through the net even before they sense anyone, so they learn to search.
	sim.idle_brain = brain
	party = StandIns.new(sim, field, rng.randi())
	party.hunt = bool(settings.get("party_hunt", false))
	open.clear()
	for x in range(-28, 29):
		for z in range(-27, 28):
			var at := Vector2(x, z)
			if not field.occupied(Vector3(at.x, 0.0, at.y), OPEN_RADIUS) and sim.locomotion.world.clearance(at.x, at.y) >= OPEN_CLEARANCE:
				open.append(at)
	if bool(settings.get("connected_spawns", false)):
		open = _connected(open)
	if open.size() < 50:
		error = "The floor has too little open ground."
		return false
	if _species.is_empty():
		for kind in sim.species.count:
			if sim.species.spawnable[kind] != 0:
				_species.append(kind)
	episodes_on_map = 0
	return true


## The points of the largest region the mobs' route grid connects. Some open points sit in pockets whose ways
## out are too narrow for a route (mob_nav.c PASS_CLEARANCE), so a mob spawned there can only stand and wait for
## the party to come into sight. Each region is found by solving one complete route field from a point not yet
## placed and reading every point's route cost. Uses no random numbers; runs before any mob is placed, and
## leaves the route fields lazy and aimed at the locomotion's targets as before.
func _connected(points: Array[Vector2]) -> Array[Vector2]:
	var world: RefCounted = sim.locomotion.world
	var left := points.duplicate()
	var best: Array[Vector2] = []
	world.set_lazy_fields(0)
	while left.size() > best.size():
		var seed: Vector2 = left[0]
		world.set_targets(PackedFloat32Array([seed.x, seed.y]))
		world.tick(0.0)
		var region: Array[Vector2] = []
		var rest: Array[Vector2] = []
		for point: Vector2 in left:
			if world.path_cost(0, point.x, point.y) >= 0.0:
				region.append(point)
			else:
				rest.append(point)
		if region.is_empty():
			rest.erase(seed)
		if region.size() > best.size():
			best = region
		left = rest
	world.set_lazy_fields(1)
	world.set_targets(sim.locomotion.targets)
	return best


## Removes the last episode's mobs, attacks and fields without events, so nothing is credited for them.
func _clear() -> void:
	recorder.discard_open()
	for slot in sim.pool.active.duplicate():
		sim.abilities.cancel(slot)
		sim.status.clear_slot(slot)
		sim.locomotion.remove(slot)
		sim.pool.despawn(slot)
	sim.abilities.releases.clear()
	sim.abilities.hazards.clear()
	sim.abilities._repeats.clear()
	sim.fields.prune(1 << 30)
	sim.pool.supports_spawned = 0
	sim.perception.lights = PackedFloat32Array()


func _spawn_mobs(start: Vector2, explore: bool, mobs := -1) -> Dictionary:
	var count := mini(mobs if mobs >= 0 else _range_int("mobs"), int(settings.capacity))
	var places: Array[Vector2] = []
	if explore:
		var distance: Array = settings.explore_distance
		var groups := mini(_range_int("explore_groups"), count)
		var centres := _ring(start, float(distance[0]), float(distance[1]), groups)
		for index in count:
			var around := _near(centres[index % centres.size()], 1, 3.0, places)
			places.append(around[0])
	else:
		var distance: Array = settings.engaged_distance
		places = _ring(start, float(distance[0]), float(distance[1]), count)
	var elite := -1
	if rng.randf() < float(settings.elite_share):
		elite = _spawn(places[0], -1, true)
	var spawned := int(elite >= 0)
	for index in range(spawned, places.size()):
		spawned += int(_spawn(places[index], elite, false) >= 0)
	return {"count": spawned, "elite": elite >= 0}


## A mob of a random species at the game's health and damage for this floor and party size.
func _spawn(at: Vector2, leader: int, elite: bool) -> int:
	var kind := _species[rng.randi() % _species.size()]
	var definition: Dictionary = Catalog.all()[kind]
	var party_size := party.count
	var request := Pool.Spawn.new()
	request.species = kind
	request.at = at
	request.intelligence = _uniform("intelligence")
	request.leader = leader
	request.speed_scale = Pace.speed_scale(float(definition.speed), floor_number)
	request.windup_scale = Pace.windup_scale(floor_number)
	request.recovery_scale = Pace.recovery_scale(floor_number)
	var tuning: Dictionary = Balance.tuning
	var hit := float(tuning.regular.get("hit_hp", definition.preview_hit_hp)) + (floor_number - 1) * float(tuning.regular.hit_per_floor)
	if elite:
		request.hp = Balance.elite_hp(definition, floor_number, (floor_number - 1) % FLOORS_PER_SITE + 1, 0, party_size)
		request.damage = roundf(hit * float(tuning.elite.hit_multiplier))
		request.flags = Pool.FLAG_LEADER | Pool.FLAG_ELITE
	else:
		request.hp = Balance.scout_hp(definition, floor_number, 0, rng.randi_range(0, 2), party_size)
		request.damage = roundf(hit)
	if rng.randf() < float(settings.mutation_chance):
		request.mutations = MUTATIONS[rng.randi() % MUTATIONS.size()]
	return sim.spawn(request)


## count open points from min_distance to max_distance away from centre, spread out where possible. When too
## few are that far, the farthest open points are used instead.
func _ring(centre: Vector2, min_distance: float, max_distance: float, count: int) -> Array[Vector2]:
	var band: Array[Vector2] = []
	for point in open:
		var distance := point.distance_to(centre)
		if distance >= min_distance and distance <= max_distance:
			band.append(point)
	if band.size() < count:
		var by_distance := open.duplicate()
		by_distance.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(centre) > b.distance_to(centre))
		band.assign(by_distance.slice(0, maxi(count, by_distance.size() / 10)))
	var chosen: Array[Vector2] = []
	for index in count:
		var best := Vector2.INF
		var best_gap := -1.0
		# Each pick is the farthest of a few random candidates from those already chosen.
		for attempt in 6:
			var candidate: Vector2 = band[rng.randi() % band.size()]
			var gap := INF
			for other in chosen:
				gap = minf(gap, candidate.distance_to(other))
			if gap > best_gap:
				best_gap = gap
				best = candidate
		chosen.append(best)
	return chosen


## count distinct open points within radius of centre, avoiding taken ones; centre itself when none are left.
func _near(centre: Vector2, count: int, radius: float, taken: Array[Vector2] = []) -> Array[Vector2]:
	var nearby: Array[Vector2] = []
	for point in open:
		if point.distance_to(centre) <= radius and not taken.has(point):
			nearby.append(point)
	var chosen: Array[Vector2] = []
	for index in count:
		if nearby.is_empty():
			chosen.append(centre)
			continue
		chosen.append(nearby.pop_at(rng.randi() % nearby.size()))
	return chosen


## The party size, and the mob count when mob_ratio_mix chooses it (-1 otherwise: _spawn_mobs draws it later, so
## the generator is consumed exactly as before for settings without a mix, such as the benchmark's frozen fights).
## mob_ratio_mix lists bands of mobs per player as [share, from, to): a band is drawn by share, then a party size
## that can meet it within the mobs range, then a mob count inside the band. A band no party size can meet falls
## back to the independent draws.
func _fight_size() -> Vector2i:
	var mix: Array = settings.get("mob_ratio_mix", [])
	if mix.is_empty():
		return Vector2i(_range_int("party"), -1)
	var total := 0.0
	for band: Array in mix:
		total += float(band[0])
	var roll := rng.randf() * total
	var chosen: Array = mix[mix.size() - 1]
	for band: Array in mix:
		roll -= float(band[0])
		if roll <= 0.0:
			chosen = band
			break
	var bounds: Array = settings.mobs
	var fewest_mobs := int(bounds[0])
	var most_mobs := mini(int(bounds[1]), int(settings.capacity))
	var options: Array[Vector3i] = []
	var sizes: Array = settings.party
	for size in range(int(sizes[0]), int(sizes[1]) + 1):
		var fewest := maxi(fewest_mobs, ceili(size * float(chosen[1])))
		var most := mini(most_mobs, ceili(size * float(chosen[2])) - 1)
		if fewest <= most:
			options.append(Vector3i(size, fewest, most))
	if options.is_empty():
		return Vector2i(_range_int("party"), mini(_range_int("mobs"), int(settings.capacity)))
	var option := options[rng.randi() % options.size()]
	return Vector2i(option.x, rng.randi_range(option.y, option.z))


func _uniform(key: String) -> float:
	var bounds: Array = settings[key]
	return rng.randf_range(float(bounds[0]), float(bounds[1]))


func _range_int(key: String) -> int:
	var bounds: Array = settings[key]
	return rng.randi_range(int(bounds[0]), int(bounds[1]))
