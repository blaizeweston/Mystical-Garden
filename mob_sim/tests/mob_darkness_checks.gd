extends SceneTree
## Checks darkness in the simulation: glowing species, hiding only while darkness is on (native and reference
## masks agree), the shared rule for what players see, and the hide executor seeking darkness out of a
## player's close sight, natively and in the GDScript reference.

const Battlefield = preload("res://battlefield.gd")
const Locomotion = preload("res://mob_sim/mob_locomotion.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Perception = preload("res://mob_sim/mob_perception.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Sim = preload("res://mob_sim/mob_sim.gd")
const Species = preload("res://mob_sim/mob_species.gd")

const NIGHT := 0.08
const PLAYER_LIGHT := 5.5

var failures := 0
var checks := 0


func _initialize() -> void:
	if not NavWorld.ensure_loaded():
		print("FAIL native extension did not load")
		quit(2)
		return
	test_glow()
	test_hide_legal()
	test_player_sight()
	test_hide_executor()
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


## A night with one lit player at the origin whom every listed mob knows about.
func night(sim: Sim, watchers: Array) -> void:
	sim.set_darkness(true, NIGHT)
	sim.party.set_player(0, Vector2.ZERO, Vector2.ZERO, 100.0, 100.0)
	sim.perception.lights = PackedFloat32Array([0.0, 0.0, PLAYER_LIGHT, 1.0])
	sim.perception.update(sim.clock.tick)
	for slot in watchers:
		var row: int = int(slot) * sim.contract.players
		sim.perception.seen_tick[row] = sim.clock.tick
		sim.perception.visible[row] = 1


func test_glow() -> void:
	var species := Species.new()
	check(species.glow[species.ids.find("lantern_lure")] == 5.0, "the Lantern Lure carries a lantern")
	check(species.glow[species.ids.find("rootbound")] == 0.0, "a Rootbound gives off no light")


func test_hide_legal() -> void:
	var sim := make_sim()
	var slot := add_mob(sim, "rootbound", Vector2(8, 0))
	var hide := sim.contract.id("hide")
	night(sim, [])
	sim.set_darkness(false)
	night_watch(sim, slot)
	var batch = sim._awake_batch
	batch.prepare(PackedInt32Array([slot]))
	sim.rules.build_masks(batch, sim.clock.tick)
	check(not batch.allowed(0, 0, hide), "hiding is illegal in daylight")
	sim.set_darkness(true, NIGHT)
	sim.rules.build_masks(batch, sim.clock.tick)
	var native: PackedByteArray = batch.masks.duplicate()
	batch.masks.fill(0)
	sim.rules.build_masks_reference(batch, sim.clock.tick)
	check(batch.allowed(0, 0, hide), "hiding is legal at night against a known player")
	check(native == batch.masks, "native and reference masks agree at night")


func night_watch(sim: Sim, slot: int) -> void:
	var row: int = slot * sim.contract.players
	sim.party.set_player(0, Vector2.ZERO, Vector2.ZERO, 100.0, 100.0)
	sim.perception.seen_tick[row] = sim.clock.tick
	sim.perception.visible[row] = 1


func test_player_sight() -> void:
	var sim := make_sim()
	var perception := sim.perception
	check(perception.player_sees(Vector2.ZERO, Vector2(10, 0)), "in daylight a player sees a mob ten units away")
	night(sim, [])
	check(perception.player_sees(Vector2.ZERO, Vector2(3, 0)), "at night a player sees a mob inside their light")
	check(not perception.player_sees(Vector2.ZERO, Vector2(10, 0)), "at night a player does not see a mob in the dark")
	check(perception.player_sees(Vector2(8, 0), Vector2(10, 0)), "a player sees a mob in the dark at close range")
	check(not perception.player_sees(Vector2.ZERO, Vector2(Perception.PLAYER_VIEW + 1.0, 0)), "nobody sees past the view range")


func test_hide_executor() -> void:
	var results := []
	for reference in [false, true]:
		var sim := make_sim()
		if reference:
			sim.use_reference_executors()
		var slot := add_mob(sim, "rootbound", Vector2(5, 0))
		night(sim, [slot])
		sim.pool.behaviour[slot] = sim.contract.id("hide")
		sim.pool.enemy_target[slot] = 1
		sim.pool.behaviour_since[slot] = sim.clock.tick
		sim.executors.run(sim.clock.tick)
		var at := slot * Locomotion.STRIDE
		var commands: PackedFloat32Array = sim.locomotion.commands
		results.append([int(commands[at + Locomotion.AT_MODE]), Vector2(commands[at + Locomotion.AT_OFFSET_X], commands[at + Locomotion.AT_OFFSET_Z])])
		var point: Vector2 = results[-1][1]
		var label := "reference" if reference else "native"
		check(results[-1][0] == NavWorld.Mode.DIRECT, "the %s hide executor walks to a spot" % label)
		check(sim.locomotion.world.sense_light_at(point.x, point.y) < Perception.LIT_THRESHOLD
			and point.length() > Perception.PLAYER_DARK_SIGHT, "the %s hide executor picks darkness out of close sight" % label)
	check(results[0][0] == results[1][0] and (results[0][1] as Vector2).distance_to(results[1][1]) < 1e-3,
		"native and reference hiding choose the same spot")
