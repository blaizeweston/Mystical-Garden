extends SceneTree
## Checks roaming (the "roam" behaviour, native/mob_exec.c and mob_executors_reference.gd): mobs head toward
## the nearest player's scent, a keen nose aims better than a weak one, distance blurs the aim, a mob without
## smell picks any direction, and a mob with no player to smell holds.

const Battlefield = preload("res://battlefield.gd")
const Locomotion = preload("res://mob_sim/mob_locomotion.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Reference = preload("res://mob_sim/mob_executors_reference.gd")
const Sim = preload("res://mob_sim/mob_sim.gd")

const PERIODS := 240

var failures := 0
var checks := 0
var report := {}


func _initialize() -> void:
	if not NavWorld.ensure_loaded():
		print("FAIL native extension did not load")
		quit(2)
		return
	test_aim()
	test_without_players()
	print("ROAM_REPORT ", JSON.stringify(report))
	print("PASSED: %d checks, %d failures" % [checks, failures] if failures == 0 else "FAILED: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


func make_sim() -> Sim:
	var field = Battlefield.new()
	field.configure(0, 1)
	preload("res://tests/support/terrain_case.gd").walls(field, [])
	var sim := Sim.new(4)
	sim.configure(field)
	return sim


func add_mob(sim: Sim, label: String, at: Vector2) -> int:
	var request := Pool.Spawn.new()
	request.species = sim.species.ids.find(label)
	request.at = at
	request.hp = 50.0
	return sim.spawn(request)


## The mean angle, in degrees, between each roaming step and the true bearing to the player, over many periods.
func mean_error(label: String, player_at: Vector2) -> float:
	var sim := make_sim()
	sim.party.set_player(0, player_at, Vector2.ZERO, 100.0, 100.0)
	var slot := add_mob(sim, label, Vector2.ZERO)
	var roam: int = sim.contract.id("roam")
	var bearing := player_at.angle()
	var total := 0.0
	var counted := 0
	for period in PERIODS:
		var tick: int = 1000 + period * Reference.ROAM_TICKS
		sim.clock.tick = tick
		sim.pool.behaviour[slot] = roam
		sim.pool.behaviour_since[slot] = tick
		sim.executors.run(tick)
		var row: int = slot * Locomotion.STRIDE
		if int(sim.locomotion.commands[row + Locomotion.AT_MODE]) != NavWorld.Mode.DIRECT:
			continue
		var goal := Vector2(sim.locomotion.commands[row + Locomotion.AT_OFFSET_X], sim.locomotion.commands[row + Locomotion.AT_OFFSET_Z])
		total += absf(angle_difference(bearing, goal.angle()))
		counted += 1
	return rad_to_deg(total / maxi(1, counted))


func test_aim() -> void:
	var keen := mean_error("thornmaw", Vector2(20, 0))
	var weak := mean_error("colossus", Vector2(20, 0))
	var keen_far := mean_error("thornmaw", Vector2(50, 0))
	var weak_near := mean_error("colossus", Vector2(8, 0))
	var none := mean_error("nightbloom", Vector2(20, 0))
	report["mean_error_degrees"] = {"smell_14_at_20m": snappedf(keen, 0.1), "smell_14_at_50m": snappedf(keen_far, 0.1),
		"smell_5_at_8m": snappedf(weak_near, 0.1), "smell_5_at_20m": snappedf(weak, 0.1), "no_smell_at_20m": snappedf(none, 0.1)}
	check(keen < 8.0, "a keen nose (smell 14) roams within a few degrees of the player at 20 m (%.1f)" % keen)
	check(weak_near > keen and weak_near < 40.0, "a weak nose (smell 5) close by aims roughly (%.1f)" % weak_near)
	check(weak > weak_near, "a weak nose aims worse from farther away (%.1f at 20 m)" % weak)
	check(keen_far > keen, "distance blurs even a keen nose (%.1f at 50 m)" % keen_far)
	check(none > 70.0 and none < 110.0, "a mob without smell roams in any direction (%.1f on average)" % none)


func test_without_players() -> void:
	var sim := make_sim()
	var slot := add_mob(sim, "thornmaw", Vector2.ZERO)
	sim.pool.behaviour[slot] = sim.contract.id("roam")
	sim.pool.behaviour_since[slot] = sim.clock.tick
	sim.executors.run(sim.clock.tick)
	check(int(sim.locomotion.commands[slot * Locomotion.STRIDE + Locomotion.AT_MODE]) == NavWorld.Mode.HOLD,
		"with no player to smell a roaming mob holds")
