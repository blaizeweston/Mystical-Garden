extends SceneTree
## Checks the senses native/mob_sense.c adds when they are switched on: light-scaled sight, darkvision,
## hearing through walls, and scent tracking. With senses on, engaged mobs no longer track unseen players
## for free. With senses off, darkness changes nothing and that legacy tracking stays.
## The map has one wall across the middle, from x = -6 to x = 6 at z = 0.

const Battlefield = preload("res://battlefield.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Sim = preload("res://mob_sim/mob_sim.gd")

var failures := 0
var checks := 0
var _tick := 0


func _initialize() -> void:
	if not NavWorld.ensure_loaded():
		print("FAIL native extension did not load")
		quit(2)
		return
	test_senses_off()
	test_darkness_and_light()
	test_darkvision()
	test_hearing()
	test_smell()
	print("PASSED: %d checks, %d failures" % [checks, failures] if failures == 0 else "FAILED: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


func make_sim(senses: bool, ambient: float) -> Sim:
	var field = Battlefield.new()
	field.configure(0, 1)
	preload("res://tests/support/terrain_case.gd").walls(field, [Rect2(-6.0, -0.5, 12.0, 1.0)])
	var sim := Sim.new(4)
	sim.configure(field)
	sim.perception.set_senses(senses)
	sim.perception.ambient = ambient
	_tick = 0
	return sim


func add_mob(sim: Sim, label: String, at: Vector2) -> int:
	var request := Pool.Spawn.new()
	request.species = sim.species.ids.find(label)
	request.at = at
	request.hp = 50.0
	request.damage = 1.0
	return sim.spawn(request)


## Runs whole refresh cycles so every mob updates at least once.
func sense(sim: Sim, cycles := 1) -> void:
	for step in cycles * sim.perception.refresh_ticks:
		_tick += 1
		sim.perception.update(_tick)


func at_row(sim: Sim, slot: int, player: int) -> int:
	return slot * sim.perception.players + player


func test_senses_off() -> void:
	var sim := make_sim(false, 0.0)
	var mob := add_mob(sim, "rootbound", Vector2(0, 5))
	sim.party.set_player(0, Vector2(0, 12), Vector2.ZERO, 100.0, 100.0)
	sense(sim)
	check(sim.perception.sees(mob, 0), "with senses off, darkness does not limit sight")
	sim.party.set_player(0, Vector2(0, -3), Vector2.ZERO, 100.0, 100.0)
	sense(sim)
	var row := at_row(sim, mob, 0)
	check(not sim.perception.sees(mob, 0) and is_equal_approx(sim.perception.seen_z[row], -3.0),
		"with senses off, an engaged mob still tracks a player behind the wall")


func test_darkness_and_light() -> void:
	var sim := make_sim(true, 0.0)
	var mob := add_mob(sim, "rootbound", Vector2(0, 5))
	sim.party.set_player(0, Vector2(0, 12), Vector2.ZERO, 100.0, 100.0)
	sense(sim)
	check(not sim.perception.sees(mob, 0), "in darkness, a mob cannot see a player beyond its darkvision")
	check(is_zero_approx(sim.locomotion.world.sense_light_at(0.0, 12.0)), "the light grid reads zero with no sources and no ambient light")
	sim.perception.lights = PackedFloat32Array([0.0, 12.0, 4.0, 1.0])
	sense(sim)
	check(sim.locomotion.world.sense_light_at(0.0, 12.0) > 0.7, "a light source brightens the cells around it")
	check(sim.perception.sees(mob, 0), "a lit player is visible from normal sight range")
	sim.perception.lights = PackedFloat32Array()
	sim.perception.ambient = 1.0
	sense(sim)
	check(sim.perception.sees(mob, 0), "full ambient light restores normal sight")


func test_darkvision() -> void:
	var sim := make_sim(true, 0.0)
	var mob := add_mob(sim, "rootbound", Vector2(0, 5))
	sim.party.set_player(0, Vector2(0, 7.5), Vector2.ZERO, 100.0, 100.0)
	sense(sim)
	check(sim.perception.sees(mob, 0), "darkvision sees a nearby player in the dark")


## The Mourning Willow hears up to 7 units and has no sense of smell, so only hearing can inform it.
func test_hearing() -> void:
	var sim := make_sim(true, 1.0)
	var mob := add_mob(sim, "willow", Vector2(0, 3))
	sim.party.set_player(0, Vector2(0, -3), Vector2.ZERO, 100.0, 100.0)
	sense(sim)
	check(not sim.perception.knows(mob, 0), "a player behind the wall is unknown before making noise")
	sim.perception.add_noise(0.0, -3.0, 0.5, 0)
	sense(sim)
	check(not sim.perception.knows(mob, 0), "a quiet noise beyond hearing range goes unheard")
	sim.perception.add_noise(0.0, -3.0, 1.0, 0)
	sense(sim)
	check(sim.perception.knows(mob, 0) and not sim.perception.sees(mob, 0), "a loud noise reveals the player's position through the wall")
	check(sim.pool.engaged[mob] != 0, "hearing a fight engages the mob")
	var row := at_row(sim, mob, 0)
	check(is_equal_approx(sim.perception.seen_x[row], 0.0) and is_equal_approx(sim.perception.seen_z[row], -3.0),
		"the mob remembers where the noise came from")


func test_smell() -> void:
	var sim := make_sim(true, 1.0)
	var hound := add_mob(sim, "thornmaw", Vector2(0, 3))
	var bell := add_mob(sim, "bellcap", Vector2(2, 3))
	sim.party.set_player(0, Vector2(0, -3), Vector2.ZERO, 100.0, 100.0)
	sim.perception.add_noise(0.0, -3.0, 1.0, 0)
	sense(sim)
	check(sim.pool.engaged[hound] != 0 and sim.pool.engaged[bell] != 0, "both mobs heard the player")
	for step in 6:
		sim.party.set_player(0, Vector2(step, -3), Vector2.ZERO, 100.0, 100.0)
		sense(sim)
	var hound_row := at_row(sim, hound, 0)
	var bell_row := at_row(sim, bell, 0)
	var tracked := Vector2(sim.perception.seen_x[hound_row], sim.perception.seen_z[hound_row])
	check(not sim.perception.sees(hound, 0), "the hound still cannot see the player behind the wall")
	check(tracked.distance_to(Vector2(5, -3)) <= 1.0, "a mob with smell follows the fresh scent trail (%s)" % tracked)
	check(Vector2(sim.perception.seen_x[bell_row], sim.perception.seen_z[bell_row]).is_equal_approx(Vector2(0, -3)),
		"a mob without smell keeps the last position it heard")
	var fresh: float = sim.locomotion.world.sense_scent_at(0, 0.5, -2.5)
	sim.party.clear_player(0)
	for step in 60:
		sense(sim)
	var faded: float = sim.locomotion.world.sense_scent_at(0, 0.5, -2.5)
	check(fresh > 0.9 and faded < fresh * 0.6, "scent fades over time (%.2f to %.2f)" % [fresh, faded])
