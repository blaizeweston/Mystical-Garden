extends SceneTree
## Checks MobFields: player fields burning, slowing and rooting the mobs inside them, flyers ignoring ground
## fields, expiry, nearest queries, host publishing, and mob hazards registering during training.

const Arena = preload("res://mob_sim/tests/mob_sim_arena.gd")
const Battlefield = preload("res://battlefield.gd")
const Fields = preload("res://mob_sim/mob_fields.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Sim = preload("res://mob_sim/mob_sim.gd")

var failures := 0
var checks := 0


func _initialize() -> void:
	if not NavWorld.ensure_loaded():
		print("FAIL native extension did not load")
		quit(2)
		return
	test_burning()
	test_control()
	test_expiry_and_nearest()
	test_publish()
	test_training_hazards()
	print("PASSED: %d checks, %d failures" % [checks, failures] if failures == 0 else "FAILED: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


func make_sim(slots := 4) -> Sim:
	var field = Battlefield.new()
	field.configure(0, 1)
	preload("res://tests/support/terrain_case.gd").walls(field, [])
	var sim := Sim.new(slots)
	sim.configure(field)
	return sim


func add_mob(sim: Sim, label: String, at: Vector2) -> int:
	var request := Pool.Spawn.new()
	request.species = sim.species.ids.find(label)
	request.at = at
	request.hp = 100.0
	request.damage = 2.0
	return sim.spawn(request)


func run_status(sim: Sim, ticks: int) -> void:
	for step in ticks:
		sim.clock.advance()
		sim.tick_status(sim.clock.tick)


func test_burning() -> void:
	var sim := make_sim()
	var walker := add_mob(sim, "rootbound", Vector2.ZERO)
	var flyer := add_mob(sim, "wasp", Vector2(1, 0))
	var outside := add_mob(sim, "rootbound", Vector2(8, 0))
	sim.add_player_field(Vector2.ZERO, 2.5, 2000, 0, 20.0)
	run_status(sim, 60)
	check(is_equal_approx(sim.pool.hp[walker], 80.0), "a fire field burns a walker for its damage per second")
	check(sim.pool.hp[flyer] == 100.0, "a ground field does not touch a flyer")
	check(sim.pool.hp[outside] == 100.0, "a field does not reach a mob outside it")
	sim.add_player_field(Vector2(1, 0), 2.5, 2000, 0, 20.0, 1.0, false, false)
	run_status(sim, 60)
	check(sim.pool.hp[flyer] < 100.0, "a field that is not on the ground reaches a flyer")


func test_control() -> void:
	var sim := make_sim()
	var walker := add_mob(sim, "rootbound", Vector2.ZERO)
	var flyer := add_mob(sim, "wasp", Vector2(1, 0))
	sim.add_player_field(Vector2.ZERO, 2.5, 2000, 0, 0.0, 0.5, true)
	run_status(sim, 15)
	var tick := sim.clock.tick
	check(sim.pool.root_until[walker] > tick and sim.pool.slow_until[walker] > tick, "a binding field roots and slows a walker")
	check(sim.pool.root_until[flyer] <= tick and sim.pool.slow_until[flyer] <= tick, "a flyer passes over a binding ground field")
	check(sim.fields.in_player_field(walker, tick) and not sim.fields.in_player_field(flyer, tick), "the registry knows who stands in a field")


func test_expiry_and_nearest() -> void:
	var sim := make_sim()
	var slot := add_mob(sim, "rootbound", Vector2.ZERO)
	sim.add_player_field(Vector2(6, 0), 1.0, 500)
	var near := sim.add_player_field(Vector2(3, 0), 1.0, 2000)
	var late := sim.fields.add(Fields.Owner.MOBS, Vector2(4, 0), 1.0, sim.clock.tick + 120, sim.clock.tick + 240)
	var order := sim.fields.nearest(Vector2.ZERO, 3, sim.clock.tick)
	check(order.size() == 3 and order[0] == near, "the nearest area comes first")
	check(order.has(late) and not sim.fields.active(late, sim.clock.tick), "an area that has not started is listed so a mob can see it coming")
	sim.add_player_field(Vector2.ZERO, 2.0, 500, 0, 40.0)
	run_status(sim, 120)
	var after := sim.pool.hp[slot]
	run_status(sim, 120)
	check(sim.pool.hp[slot] == after and after < 100.0, "a field stops burning when it ends")
	check(sim.fields.count() == 0, "every ended area is dropped (%d left)" % sim.fields.count())


func test_publish() -> void:
	var sim := make_sim()
	var slot := add_mob(sim, "rootbound", Vector2.ZERO)
	var local := sim.add_player_field(Vector2(9, 9), 1.0, 5000)
	var tick := sim.clock.tick
	sim.fields.publish([[Fields.Owner.PLAYERS, 0.0, 0.0, 2.0, tick, tick + 600, true], [Fields.Owner.MOBS, 5.0, 0.0, 1.5, tick, tick + 600, true]])
	check(sim.fields.count() == 3, "a host publish adds its areas beside the local ones")
	sim.fields.publish([[Fields.Owner.MOBS, 5.0, 0.0, 1.5, tick, tick + 600, true]])
	check(sim.fields.count() == 2 and sim.fields.x[local] == 9.0, "the next publish replaces the host's areas and keeps local ones")
	sim.fields.publish([[Fields.Owner.PLAYERS, 0.0, 0.0, 2.0, tick, tick + 600, true]])
	run_status(sim, 60)
	check(sim.pool.hp[slot] == 100.0 and sim.fields.in_player_field(slot, sim.clock.tick), "host fields are known but never applied twice")


func test_training_hazards() -> void:
	var arena := Arena.new(11, 24)
	var placed := 0
	for tick in 1800:
		arena.before_tick()
		arena.sim.tick()
		arena.after_tick()
		for index in arena.sim.fields.count():
			placed = maxi(placed, int(arena.sim.fields.owner[index] == Fields.Owner.MOBS))
	check(placed > 0, "mob hazards register as areas during training")
