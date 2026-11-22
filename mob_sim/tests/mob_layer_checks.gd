extends SceneTree
## Checks the air layer: which species fly, the flying grid built from the terrain, flyers crossing water
## that stops walkers while tall cover still stops both, sight across water, root immunity, and that flyers
## stay in the shared crowd for neighbour queries.

const Battlefield = preload("res://battlefield.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Sim = preload("res://mob_sim/mob_sim.gd")
const Species = preload("res://mob_sim/mob_species.gd")
const TerrainCase = preload("res://tests/support/terrain_case.gd")

var failures := 0
var checks := 0


func _initialize() -> void:
	if not NavWorld.ensure_loaded():
		print("FAIL native extension did not load")
		quit(2)
		return
	test_species()
	test_mask()
	test_crossing()
	test_roots_and_crowd()
	print("PASSED: %d checks, %d failures" % [checks, failures] if failures == 0 else "FAILED: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


## A room split by a moat from x = -2 to 2, with a tall wall across the moat's south end.
func moat_field() -> RefCounted:
	var field = Battlefield.new()
	field.configure(0, 1)
	var wall: Dictionary = Shape.shape("wall", "wall", TerrainCase.rectangle(-6.0, 14.0, 6.0, 16.0))
	var moat: Dictionary = Shape.shape("moat", "water", TerrainCase.rectangle(-2.0, -28.0, 2.0, 29.0))
	TerrainCase.area(field, TerrainCase.rectangle(-29, -28, 30, 29), [wall], [moat])
	return field


func make_sim(field: RefCounted, slots := 4) -> Sim:
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


func cell(mask: PackedByteArray, point: Vector2) -> int:
	var at := Vector2i(((point - NavWorld.ORIGIN) / NavWorld.FLOOR_CELL).floor())
	return mask[at.x + at.y * NavWorld.FLOOR_SIZE.x]


func test_species() -> void:
	var species := Species.new()
	check(species.layer[species.ids.find("orchid")] == 1 and species.layer[species.ids.find("wasp")] == 1, "the Orchid and Wicker Wasp fly")
	check(species.layer[species.ids.find("rootbound")] == 0, "a Rootbound walks")


func test_mask() -> void:
	var field := moat_field()
	var began := Time.get_ticks_usec()
	var ground := NavWorld.floor_mask(field)
	var air := NavWorld.air_mask(field, ground)
	print("AIR_MASK_MS ", (Time.get_ticks_usec() - began) / 1000.0)
	check(cell(ground, Vector2(0, 0)) == 0 and cell(air, Vector2(0, 0)) == 1, "water blocks walking but not flying")
	check(cell(ground, Vector2(0, 15)) == 0 and cell(air, Vector2(0, 15)) == 0, "tall cover blocks both")
	check(cell(ground, Vector2(-10, 0)) == 1 and cell(air, Vector2(-10, 0)) == 1, "open floor allows both")
	check(cell(air, Vector2(30.6, 0)) == 0, "flyers stay inside the arena")


func test_crossing() -> void:
	var field := moat_field()
	var sim := make_sim(field)
	var world: RefCounted = sim.locomotion.world
	check(world.line_clear(-10.0, 0.0, 10.0, 0.0, 0.0) == 0 and world.sight_clear(-10.0, 0.0, 10.0, 0.0, 0.0) != 0,
		"sight crosses water that walking cannot")
	check(world.sight_clear(0.0, 10.0, 0.0, 20.0, 0.0) == 0, "tall cover blocks sight")
	var walker := add_mob(sim, "rootbound", Vector2(-10, 3))
	var flyer := add_mob(sim, "wasp", Vector2(-10, 0))
	check(sim.locomotion.flies(flyer) and not sim.locomotion.flies(walker), "flyers move on the air layer and walkers on the ground")
	for tick in 600:
		sim.clock.advance()
		sim.locomotion.go_to(walker, 10.0, 3.0, 0.5)
		sim.locomotion.go_to(flyer, 10.0, 0.0, 0.5)
		sim.locomotion.step(sim.clock.tick)
	check(sim.pool.xz[flyer * 2] > 9.0, "a flyer crosses the moat")
	check(sim.pool.xz[walker * 2] < -2.0, "a walker cannot cross it")
	sim.locomotion.displace(flyer, 10.0, 20.0)
	check(sim.pool.xz[flyer * 2 + 1] < 14.0 or absf(sim.pool.xz[flyer * 2]) > 6.0, "a flyer's dash stops at tall cover")


func test_roots_and_crowd() -> void:
	var sim := make_sim(moat_field())
	var walker := add_mob(sim, "rootbound", Vector2(-10, 3))
	var flyer := add_mob(sim, "wasp", Vector2(-10, 4))
	sim.apply_status(flyer, Sim.Status.ROOT, 60)
	sim.apply_status(walker, Sim.Status.ROOT, 60)
	check(sim.pool.root_until[flyer] == 0, "a flyer cannot be rooted")
	check(sim.pool.root_until[walker] > sim.clock.tick, "a walker can be rooted")
	sim.locomotion.step(sim.clock.tick)
	var nearest: PackedFloat32Array = sim.locomotion.world.nearest_batch(PackedFloat32Array([walker]), 3.0, 4)
	check(int(nearest[0]) == flyer, "a flyer still counts as a nearby ally")
