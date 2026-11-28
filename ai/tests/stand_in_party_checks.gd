extends SceneTree
## Checks the training party (ai/stand_in_party.gd): stats, classes and timers reach the simulation, dodges,
## armour, guard, bark armour, healing, going down, darkness, skills, hunting lost mobs, and that a harder party
## fights better against the scripted brain.

const Battlefield = preload("res://battlefield.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const Fields = preload("res://mob_sim/mob_fields.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Party = preload("res://mob_sim/mob_party.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Sim = preload("res://mob_sim/mob_sim.gd")
const StandIns = preload("res://ai/stand_in_party.gd")

const ROSTER := ["rootbound", "rootbound", "thornmaw", "gallhorn", "nightbloom", "bellcap", "wasp", "willow"]
const FULL_PARTY := ["warden", "ranger", "oracle", "weaver"]


## A brain that keeps every mob standing idle where it is.
class StillBrain extends "res://mob_sim/mob_brain.gd":
	func decide(batch: Batch) -> void:
		for index in batch.slots.size():
			batch.write_intent(index, batch.contract.id("idle_wander"), 0, 0, 0)

var failures := 0
var checks := 0
var report := {}


func _initialize() -> void:
	if not NavWorld.ensure_loaded():
		print("FAIL native extension did not load")
		quit(2)
		return
	test_publishing()
	test_hits()
	test_effects()
	test_darkness()
	test_patrol()
	test_hunt()
	test_fights()
	print("PARTY_REPORT ", JSON.stringify(report))
	print("PASSED: %d checks, %d failures" % [checks, failures] if failures == 0 else "FAILED: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


## A real Wilds floor, a simulation that resolves its own hits, and open points to place everyone.
func make_world(seed_value: int, slots := 12) -> Array:
	var field = Battlefield.new()
	field.configure(0, 5, seed_value)
	var sim := Sim.new(slots)
	sim.configure(field)
	sim.abilities.resolve_hits = true
	var open: Array[Vector2] = []
	for x in range(-56, 57, 2):
		for z in range(-54, 55, 2):
			if not field.occupied(Vector3(x * 0.5, 0, z * 0.5), 0.8):
				open.append(Vector2(x * 0.5, z * 0.5))
	return [field, sim, open]


func add_mob(sim: Sim, label: String, at: Vector2) -> int:
	var request := Pool.Spawn.new()
	request.species = sim.species.ids.find(label)
	request.at = at
	request.hp = 60.0
	request.damage = 11.0
	request.intelligence = 1.0
	return sim.spawn(request)


func test_publishing() -> void:
	var world := make_world(5)
	var sim: Sim = world[1]
	var party := StandIns.new(sim, world[0], 1)
	party.reset(["warden", "ranger"], [Vector2(0, 0), Vector2(1, 0)], 0.5)
	var stats: PackedFloat32Array = sim.party.stats
	check(stats[Party.Stat.MELEE_DAMAGE] == 11.0 and stats[Party.STAT_COUNT + Party.Stat.RANGED_RANGE] == 6.0,
		"each player's class stats reach the simulation")
	check(stats[Party.Stat.CLASS] == 1.0 and stats[Party.STAT_COUNT + Party.Stat.CLASS] == 3.0,
		"each player's class reaches the simulation as its place in the contract's party classes")
	check(stats[Party.Stat.SPEED_SCALE] == 1.0 and stats[Party.Stat.GUARD] == 0.0, "a fresh player moves at full speed, unguarded")
	for label: String in party.CLASSES:
		check(sim.contract.party_classes.has(label), "the training class %s is one of the game's classes" % label)
	check(sim.party.present[0] != 0 and sim.party.present[1] != 0 and sim.party.present[2] == 0, "only the party's players are present")


func test_hits() -> void:
	var world := make_world(6)
	var sim: Sim = world[1]
	var party := StandIns.new(sim, world[0], 2)
	party.reset(["warden"], [Vector2(0, 0)], 0.5)
	party.has_bark[0] = 0
	party.skill_ready[0] = sim.clock.tick + 100000
	var mob := add_mob(sim, "rootbound", Vector2(1, 0))
	sim.events.push(Events.Kind.HIT, sim.clock.tick, mob, sim.pool.generation[mob], 0, 0, 0.0, 0.0, 100.0)
	party.after_tick()
	var full: float = StandIns.CLASSES.warden.hp
	check(is_equal_approx(party.hp[0], full - 70.0), "armour takes its share of a hit")
	party.dodge_until[0] = sim.clock.tick + 10
	sim.events.push(Events.Kind.HIT, sim.clock.tick, mob, sim.pool.generation[mob], 0, 0, 0.0, 0.0, 100.0)
	party.after_tick()
	check(party.hits_dodged == 1 and is_equal_approx(party.hp[0], full - 70.0), "a hit during a dodge does nothing")
	party.dodge_until[0] = 0
	sim.events.push(Events.Kind.HIT, sim.clock.tick, mob, sim.pool.generation[mob], 0, 0, 0.0, 0.0, 1000.0)
	party.after_tick()
	party.before_tick()
	check(party.down[0] != 0 and party.wiped() and sim.party.alive[0] == 0, "a player at zero health goes down and the party is wiped")


## Guard blocks whole hits, bark armour soaks part of one, roots show as lost speed, and the oracle heals.
func test_effects() -> void:
	var world := make_world(9)
	var sim: Sim = world[1]
	var party := StandIns.new(sim, world[0], 5)
	party.reset(["warden", "oracle"], [Vector2(0, 0), Vector2(1, 0)], 0.5)
	party.has_bark.fill(0)
	party.skill_ready[1] = sim.clock.tick + 100000
	var mob := add_mob(sim, "rootbound", Vector2(1.5, 0))
	var now: int = sim.clock.tick
	party.skill_ready[0] = now
	party.target[0] = -1
	party._try_skill(0, StandIns.CLASSES.warden, now)
	check(party.guard_charges[0] == 0, "a warden keeps its guard while no mob winds up on it")
	sim.pool.windup_until[mob] = now + 20
	sim.pool.aim_player[mob] = 0
	party._try_skill(0, StandIns.CLASSES.warden, now)
	sim.pool.windup_until[mob] = 0
	party.before_tick()
	check(party.guard_charges[0] == 1 and is_equal_approx(sim.party.stats[Party.Stat.GUARD], 0.25),
		"a warden raises its guard against a wind-up and the mobs can see it")
	var full: float = party.hp[0]
	sim.events.push(Events.Kind.HIT, now, mob, sim.pool.generation[mob], 0, 0, 0.0, 0.0, 40.0)
	party.after_tick()
	check(party.blocked == 1 and is_equal_approx(party.hp[0], full), "a guard charge blocks a whole hit")
	party.before_tick()
	check(sim.party.stats[Party.Stat.GUARD] == 0.0, "a spent guard no longer shows")
	party.has_bark[0] = 1
	party.bark_ready[0] = now
	party.target[0] = mob
	party._try_bark(0, now)
	party.before_tick()
	check(is_equal_approx(sim.party.stats[Party.Stat.BARK], StandIns.BARK.capacity) and is_equal_approx(sim.party.stats[Party.STAT_COUNT + Party.Stat.BARK], StandIns.BARK.capacity),
		"bark armour reaches the player and an ally beside it")
	sim.events.push(Events.Kind.HIT, now, mob, sim.pool.generation[mob], 0, 0, 0.0, 0.0, 50.0)
	party.after_tick()
	var after_armour: float = 50.0 * (1.0 - float(StandIns.CLASSES.warden.armour))
	check(is_equal_approx(party.hp[0], full - after_armour * 0.6) and is_equal_approx(party.bark[0], StandIns.BARK.capacity - after_armour * 0.4),
		"bark armour soaks its share of an unblocked hit")
	party.rooted_until[1] = now + 30
	party.before_tick()
	check(sim.party.stats[Party.STAT_COUNT + Party.Stat.SPEED_SCALE] == 0.0 and sim.party.stats[Party.Stat.SPEED_SCALE] == 1.0,
		"a rooted player shows no speed and a free one full speed")
	party.hp[1] = 40.0
	party.skill_ready[1] = now
	party._try_skill(1, StandIns.CLASSES.oracle, now)
	check(is_equal_approx(party.hp[1], 40.0 + StandIns.HEAL.amount) and party.healed > 0.0, "the oracle heals a hurt ally nearby")


func test_darkness() -> void:
	var world := make_world(7)
	var sim: Sim = world[1]
	var party := StandIns.new(sim, world[0], 3)
	party.reset(["ranger", "weaver"], [Vector2(0, 0), Vector2(1, 0)], 0.5, 0.1)
	for step in 6:
		sim.clock.advance()
		party.before_tick()
	check(sim.perception.senses_enabled and sim.perception.lights.size() >= 8, "at night the simulation senses by light and the players carry lights")


## With no mobs, a patrolling party walks its route across the floor and keeps together.
func test_patrol() -> void:
	var world := make_world(8)
	var sim: Sim = world[1]
	var open: Array = world[2]
	var party := StandIns.new(sim, world[0], 4)
	var start: Vector2 = open[open.size() / 2]
	var points: Array[Vector2] = [start]
	for point: Vector2 in open:
		if points.size() < 3 and point != start and point.distance_to(start) < 2.5:
			points.append(point)
	party.reset(["warden", "ranger", "oracle"], points, 0.5)
	var placed := party.plan_patrol(open, 4)
	var farthest := 0.0
	for point: Vector2 in party.patrol:
		farthest = maxf(farthest, point.distance_to(start))
	var reached := 0
	var spread := 0.0
	var travelled := 0.0
	var last: Vector2 = party.position[0]
	for tick in 60 * 45:
		party.before_tick()
		sim.tick()
		party.after_tick()
		reached = maxi(reached, party.patrol_leg[0])
		spread = maxf(spread, party.position[0].distance_to(party.position[2]))
		travelled += party.position[0].distance_to(last)
		last = party.position[0]
	report["patrol"] = {"points": placed, "farthest": snappedf(farthest, 0.1), "reached": reached, "travelled": snappedf(travelled, 0.1),
		"spread": snappedf(spread, 0.1), "detours": party.detours}
	check(placed == 5 and farthest > 12.0, "a patrol of four legs and the way home reaches %.0f m out" % farthest)
	check(reached >= placed, "the patrolling party walks its whole route (%d points of %d, %.0f m)" % [reached, placed, travelled])
	check(spread < 12.0, "the party keeps together on patrol (%.1f m apart at most)" % spread)



## A party that hunts walks to where it last saw a mob, searches around it and then gives up; a hit marks where
## it came from; a hurt player and an old lead do not hunt; without hunt the party stays put.
func test_hunt() -> void:
	var results := {}
	for hunting: bool in [true, false]:
		var world := make_world(9)
		var sim: Sim = world[1]
		var open: Array = world[2]
		var party := StandIns.new(sim, world[0], 5)
		party.hunt = hunting
		var start: Vector2 = open[open.size() / 2]
		# At night, with a mob that stands still far away: it keeps the fight going but is never seen.
		party.reset(["warden", "ranger"], [start, start + Vector2(0.8, 0)], 0.5, 0.1)
		sim.brain = StillBrain.new()
		sim.idle_brain = StillBrain.new()
		var far := start
		for point: Vector2 in open:
			if point.distance_to(start) > far.distance_to(start):
				far = point
		# A lead in plain view of the start, so the walk there needs no routing.
		var world_nav = sim.locomotion.world
		var lead := start
		for point: Vector2 in open:
			var length := point.distance_to(start)
			if length > 8.0 and length < 14.0 and (lead == start or point.distance_to(far) > lead.distance_to(far)) 					and world_nav.line_clear(start.x, start.y, point.x, point.y, StandIns.BODY_CLEARANCE) != 0:
				lead = point
		check(lead.distance_to(start) > 8.0 and lead.distance_to(far) > 8.0, "the test lead lies %.0f m out, away from the mob" % lead.distance_to(start))
		var mob := add_mob(sim, "rootbound", far)
		party._note_lead(lead, sim.clock.tick)
		var closest := INF
		var hunted := false
		var strayed := 0.0
		for tick in 60 * 30:
			party.before_tick()
			sim.tick()
			party.after_tick()
			closest = minf(closest, party.position[0].distance_to(lead))
			hunted = hunted or party.mode[0] == StandIns.Mode.HUNT
			strayed = maxf(strayed, party.position[0].distance_to(start))
		results[hunting] = {"closest": snappedf(closest, 0.1), "strayed": snappedf(strayed, 0.1), "hunts": party.hunts,
			"failed": party.hunts_failed, "mode": party.mode[0], "far": snappedf(start.distance_to(far), 0.1)}
		if not hunting:
			check(not hunted and party.hunts == 0, "without hunt the party ignores a lead (closest %.1f m)" % closest)
			continue
		check(hunted and closest < float(StandIns.HUNT_REACHED) + 0.5,
			"a hunting party walks to its lead %.0f m away (closest %.1f m)" % [start.distance_to(lead), closest])
		check(party.hunts_failed >= 1 and party.mode[0] == StandIns.Mode.WANDER,
			"after searching %d points around the lead the party gives up and wanders" % StandIns.HUNT_SEARCH_POINTS)
		var mob_at := Vector2(sim.pool.xz[mob * 2], sim.pool.xz[mob * 2 + 1])
		party._take_hit({"slot": mob, "generation": sim.pool.generation[mob], "a": 1, "b": 0, "value": 5.0, "radius": 0.0,
			"from_x": 0.0, "from_z": 0.0}, sim.clock.tick)
		check(party._lead_tick == sim.clock.tick and party._lead.distance_to(mob_at) < 0.01, "a hit marks where it came from as the lead")
		check(party._hunting(0), "a healthy player hunts a fresh lead")
		party.hp[0] = party.max_hp[0] * (StandIns.RETREAT_HEALTH - 0.05)
		check(not party._hunting(0), "a badly hurt player does not hunt")
		party.hp[0] = party.max_hp[0]
		party._lead_tick = sim.clock.tick - roundi(float(StandIns.HUNT_MEMORY_S[1]) * 60.0) - 1
		check(not party._hunting(0) and party._lead_tick == -1, "a lead older than the party's memory is forgotten")
	report["hunt"] = {"on": results[true], "off": results[false]}


## The same fights at low and high difficulty, over three seeds, against the scripted brain.
func test_fights() -> void:
	var results := {}
	for skill: float in [0.1, 0.9]:
		var totals := {"kills": 0, "taken": 0.0, "dealt": 0.0, "dodges": 0, "downs": 0, "fields": 0, "ticks": 0, "usec": 0,
			"windups": 0, "hits": 0, "blocked": 0, "healed": 0.0}
		for seed_value in [11, 22, 33, 44, 55, 66, 77, 88]:
			var world := make_world(seed_value)
			var sim: Sim = world[1]
			var open: Array = world[2]
			var party := StandIns.new(sim, world[0], seed_value)
			var start: Vector2 = open[seed_value * 7 % open.size()]
			var points: Array[Vector2] = []
			for index in 4:
				points.append(start + Vector2(index * 0.8, 0))
			party.reset(FULL_PARTY, points, skill)
			var far: Array[Vector2] = []
			for point: Vector2 in open:
				if point.distance_to(start) > 9.0 and point.distance_to(start) < 16.0:
					far.append(point)
			for index in ROSTER.size():
				add_mob(sim, ROSTER[index], far[(index * 37 + seed_value) % far.size()])
			var began := Time.get_ticks_usec()
			var fields_seen := 0
			var cursor: int = sim.events.head
			for tick in 60 * 60:
				party.before_tick()
				sim.tick()
				for event in sim.events.read_since(cursor):
					totals.windups += int(int(event.kind) == Events.Kind.WINDUP)
					totals.hits += int(int(event.kind) == Events.Kind.HIT)
				cursor = sim.events.head
				party.after_tick()
				for index in sim.fields.count():
					fields_seen = maxi(fields_seen, int(sim.fields.owner[index] == Fields.Owner.PLAYERS))
				if party.wiped() or sim.pool.active.is_empty():
					totals.ticks += tick
					break
				if tick == 60 * 60 - 1:
					totals.ticks += tick
			totals.usec += Time.get_ticks_usec() - began
			totals.kills += party.kills
			totals.taken += party.damage_taken
			totals.dealt += party.damage_dealt
			totals.dodges += party.dodges
			totals.blocked += party.blocked
			totals.healed += party.healed
			totals.downs += 4 - party.alive_count()
			totals.fields += fields_seen
		results[skill] = totals
	report["difficulty"] = results
	var low: Dictionary = results[0.1]
	var high: Dictionary = results[0.9]
	report["ticks_per_second"] = roundi((low.ticks + high.ticks) / ((low.usec + high.usec) / 1000000.0))
	check(high.kills > 0 and high.dealt > 0.0, "the party kills mobs")
	check(low.taken > 0.0 and high.taken > 0.0, "mobs hurt the party")
	check(high.dodges > low.dodges, "a harder party dodges more (%d against %d)" % [high.dodges, low.dodges])
	check(high.kills >= low.kills and high.taken / maxf(1.0, high.kills) < low.taken / maxf(1.0, low.kills),
		"a harder party kills more and takes less damage per kill")
	check(high.fields > 0, "class skills leave player fields")
	check(low.blocked + high.blocked > 0 and low.healed + high.healed > 0.0, "in real fights the warden guards and the oracle heals")
