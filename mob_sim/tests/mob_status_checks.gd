extends SceneTree
## Checks MobStatus: damage over time, stacking and expiry, armour, dodge windows, channeling, and that
## an encounter with no damage over time does no status work.

const Battlefield = preload("res://battlefield.gd")
const Catalog = preload("res://enemy_catalog.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Sim = preload("res://mob_sim/mob_sim.gd")
const Status = preload("res://mob_sim/mob_status.gd")

const HP := 1000.0

var failures := 0
var checks := 0


func _initialize() -> void:
	if not NavWorld.ensure_loaded():
		print("FAIL native extension did not load")
		quit(2)
		return
	test_damage_over_time()
	test_stacking()
	test_kill_credit()
	test_modifiers()
	test_idle_cost()
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


func add_mob(sim: Sim, at: Vector2, hp := HP, mutations := 0, label := "colossus") -> int:
	var request := Pool.Spawn.new()
	request.species = sim.species.ids.find(label)
	request.at = at
	request.hp = hp
	request.damage = 1.0
	request.mutations = mutations
	return sim.spawn(request)


## Advances only the clock and the status step, so nothing else changes health.
func run_status(sim: Sim, ticks: int) -> void:
	for step in ticks:
		sim.clock.advance()
		sim.tick_status(sim.clock.tick)


func test_damage_over_time() -> void:
	var sim := make_sim()
	var mob := add_mob(sim, Vector2(0, 5))
	sim.apply_dot(mob, 6.0, 100)
	run_status(sim, 40)
	check(is_equal_approx(sim.pool.hp[mob], HP - 6.0 * 30 / 60.0), "damage over time lands every quarter second (%.3f)" % (HP - sim.pool.hp[mob]))
	run_status(sim, 120)
	check(is_equal_approx(sim.pool.hp[mob], HP - 6.0 * 100 / 60.0), "the total matches damage per second times duration (%.3f)" % (HP - sim.pool.hp[mob]))
	check(sim.status.burning.is_empty() and sim.pool.dot_dps[mob] == 0.0, "finished damage over time is retired")


func test_stacking() -> void:
	var sim := make_sim()
	var mob := add_mob(sim, Vector2(0, 5))
	sim.apply_dot(mob, 6.0, 60)
	sim.apply_dot(mob, 3.0, 30)
	check(is_equal_approx(sim.pool.dot_dps[mob], 9.0), "stacks add their damage per second")
	check(sim.pool.dot_until[mob] == sim.clock.tick + 60, "the longest duration wins")
	check(sim.status.burning.size() == 1, "a stacked mob is tracked once")


func test_kill_credit() -> void:
	var sim := make_sim()
	var mob := add_mob(sim, Vector2(0, 5), 2.0)
	var cursor := sim.events.head
	sim.apply_dot(mob, 12.0, 120, 2)
	run_status(sim, 30)
	var deaths := sim.events.read_since(cursor).filter(func(event: Dictionary) -> bool: return event.kind == Events.Kind.DEATH)
	check(sim.pool.alive[mob] == 0, "damage over time can kill")
	check(deaths.size() == 1 and int(deaths[0].a) == 2, "the kill is credited to the player who applied it")
	check(sim.status.burning.is_empty(), "a dead mob stops burning")


func test_modifiers() -> void:
	var sim := make_sim()
	var plain := add_mob(sim, Vector2(0, 5))
	var bark := add_mob(sim, Vector2(4, 5), HP, Catalog.BARK)
	var ratio := float(preload("res://enemy_balance.gd").tuning.get("armor_damage_ratio", 1.0))
	sim.damage_mob(plain, 10.0)
	sim.damage_mob(bark, 10.0)
	check(is_equal_approx(sim.pool.hp[plain], HP - 10.0), "an unarmoured mob takes full damage")
	check(is_equal_approx(sim.pool.hp[bark], HP - 10.0 * ratio), "the Bark mutation applies the shared armour ratio (%.2f)" % ratio)
	var resolved: float = sim.pool.hp[bark]
	sim.damage_mob(bark, 10.0, -1, false)
	check(is_equal_approx(sim.pool.hp[bark], resolved - 10.0), "damage a host already resolved is applied unscaled")
	var cursor := sim.events.head
	sim.start_dodge(plain, 10)
	check(sim.damage_mob(plain, 10.0, 1) == 0.0, "a dodging mob ignores hits")
	var dodged := sim.events.read_since(cursor).filter(func(event: Dictionary) -> bool: return event.kind == Events.Kind.DODGED)
	check(dodged.size() == 1 and int(dodged[0].a) == 1, "a dodge is recorded with its source")
	run_status(sim, 11)
	check(sim.damage_mob(plain, 10.0) > 0.0, "the dodge window ends")
	var channeler := add_mob(sim, Vector2(8, 5), HP, 0, "bellcap")
	var taken: float = sim.status.channel_damage_taken[sim.pool.species[channeler]]
	sim.start_channel(channeler, 60)
	sim.damage_mob(channeler, 10.0)
	check(is_equal_approx(sim.pool.hp[channeler], HP - 10.0 * taken) and taken > 1.0, "channeling raises damage taken (x%.2f)" % taken)
	sim.stop_channel(channeler)
	var before: float = sim.pool.hp[channeler]
	sim.damage_mob(channeler, 10.0)
	check(is_equal_approx(sim.pool.hp[channeler], before - 10.0), "ending the channel restores normal damage")


func test_idle_cost() -> void:
	var sim := make_sim()
	for index in 4:
		add_mob(sim, Vector2(index * 3, 5))
	var before: float = sim.pool.hp[0]
	run_status(sim, 60)
	check(sim.status.burning.is_empty() and sim.pool.hp[0] == before, "with no damage over time, the status step does nothing")
