extends SceneTree
## Checks rewards v2 (ai/mob_rewards.gd): each term against a controlled event, and the squad mix.

const Battlefield = preload("res://battlefield.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Rewards = preload("res://ai/mob_rewards.gd")
const Sim = preload("res://mob_sim/mob_sim.gd")

var failures := 0
var checks := 0


func _initialize() -> void:
	if not NavWorld.ensure_loaded():
		print("FAIL native extension did not load")
		quit(2)
		return
	test_damage_and_loss()
	test_downs_and_wipes()
	test_healing_death_and_intent()
	test_supports()
	test_sight_cap()
	test_first_sight()
	test_dodges_and_abilities()
	test_squad_mix()
	print("PASSED: %d checks, %d failures" % [checks, failures] if failures == 0 else "FAILED: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


func make_sim(slots := 6) -> Sim:
	var field = Battlefield.new()
	field.configure(0, 1)
	preload("res://tests/support/terrain_case.gd").walls(field, [])
	var sim := Sim.new(slots)
	sim.configure(field)
	sim.party.set_player(0, Vector2(0, 6), Vector2.ZERO, 100.0, 100.0)
	return sim


func add_mob(sim: Sim, label: String, at: Vector2) -> int:
	var request := Pool.Spawn.new()
	request.species = sim.species.ids.find(label)
	request.at = at
	request.hp = 100.0
	request.damage = 2.0
	return sim.spawn(request)


## Rewards without the squad mix, so each term is seen whole.
func solo(sim: Sim) -> Rewards:
	var rewards := Rewards.new(sim)
	rewards.squad_mix = 0.0
	return rewards


func step(sim: Sim, rewards: Rewards, ticks := 1) -> void:
	for index in ticks:
		sim.clock.advance()
		rewards.tick()


func test_damage_and_loss() -> void:
	var sim := make_sim()
	var slot := add_mob(sim, "rootbound", Vector2.ZERO)
	var rewards := solo(sim)
	step(sim, rewards)
	rewards.take(slot)
	sim.record_hit(slot, sim.pool.generation[slot], 0, 50.0)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(slot), 1.0), "half a player's health bar earns 1.0")
	sim.damage_mob(slot, 30.0, 0)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(slot), -0.09), "losing 30% of its own health costs 0.09")


func test_downs_and_wipes() -> void:
	var sim := make_sim()
	var hitter := add_mob(sim, "rootbound", Vector2.ZERO)
	var bystander := add_mob(sim, "rootbound", Vector2(12, 0))
	sim.party.set_player(1, Vector2(0, -6), Vector2.ZERO, 100.0, 100.0)
	var rewards := solo(sim)
	step(sim, rewards)
	sim.record_hit(hitter, sim.pool.generation[hitter], 0, 10.0)
	step(sim, rewards)
	rewards.take(hitter)
	rewards.take(bystander)
	sim.party.set_player(0, Vector2(0, 6), Vector2.ZERO, 0.0, 100.0)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(hitter), 3.75), "the mob that hit a downed player earns 3.75")
	check(is_zero_approx(rewards.take(bystander)), "a mob that never hit the player earns nothing for the down")
	sim.party.set_player(1, Vector2(0, -6), Vector2.ZERO, 0.0, 100.0)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(bystander), 8.5), "every mob alive earns 8.5 when the party is wiped")


func test_healing_death_and_intent() -> void:
	var sim := make_sim()
	var slot := add_mob(sim, "pallbearer", Vector2.ZERO)
	var rewards := solo(sim)
	step(sim, rewards)
	rewards.take(slot)
	sim.events.push(Events.Kind.HEALED, sim.clock.tick, slot, sim.pool.generation[slot], slot, 0, 0.0, 0.0, 25.0)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(slot), 0.15), "healing a quarter of a mob's health earns 0.15")
	sim.events.push(Events.Kind.INTENT, sim.clock.tick, slot, sim.pool.generation[slot], 2, 1)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(slot), -0.002), "changing intent costs a little")
	var other := add_mob(sim, "rootbound", Vector2(10, 0))
	step(sim, rewards)
	rewards.take(other)
	sim.damage_mob(other, 1000.0, 0)
	step(sim, rewards)
	check(rewards.take(other) < -0.14, "a mob's death costs it its value")


func test_supports() -> void:
	var sim := make_sim()
	var support := add_mob(sim, "bellcap", Vector2.ZERO)
	var fighter := add_mob(sim, "rootbound", Vector2(1.5, 0))
	sim.perception.refresh_allies(PackedInt32Array([support, fighter]), sim.clock.tick)
	var rewards := solo(sim)
	step(sim, rewards)
	rewards.take(fighter)
	sim.pool.windup_until[support] = sim.clock.tick + 120
	step(sim, rewards, 60)
	var uptime := rewards.take(fighter)
	check(uptime > 0.015 and uptime < 0.025, "a casting support earns its allies about 0.02 a second (%.4f)" % uptime)
	sim.pool.windup_until[support] = 0
	sim.damage_mob(support, 1000.0, 0)
	step(sim, rewards)
	check(rewards.take(fighter) <= -0.3, "losing a support costs its allies 0.3 times its value")


func test_sight_cap() -> void:
	var sim := make_sim()
	var slot := add_mob(sim, "rootbound", Vector2.ZERO)
	var rewards := solo(sim)
	rewards.weights["first_sight"] = 0.0
	sim.pool.enemy_target[slot] = 1
	var row: int = slot * sim.contract.players
	sim.perception.seen_tick[row] = sim.clock.tick
	sim.perception.visible[row] = 1
	step(sim, rewards)
	rewards.take(slot)
	step(sim, rewards, 600)
	var earned := rewards.take(slot)
	check(earned > 0.0 and earned <= 0.005 + 1e-6, "sight of the target earns at most 0.005 between decisions (%.4f)" % earned)


func test_first_sight() -> void:
	var sim := make_sim()
	var slot := add_mob(sim, "rootbound", Vector2(30, 0))
	var rewards := solo(sim)
	step(sim, rewards, 12)
	check(is_zero_approx(rewards.take(slot)), "a mob that has not seen a player earns nothing for it")
	var row: int = slot * sim.contract.players
	sim.perception.seen_tick[row] = sim.clock.tick
	sim.perception.visible[row] = 1
	step(sim, rewards, 6)
	check(is_equal_approx(rewards.take(slot), 0.2), "first sight of a player earns 0.2")
	step(sim, rewards, 60)
	check(is_zero_approx(rewards.take(slot)) and rewards.totals.found == 1, "seeing players again earns no more")


func test_dodges_and_abilities() -> void:
	var sim := make_sim()
	var slot := add_mob(sim, "bellcap", Vector2.ZERO)
	var rewards := solo(sim)
	step(sim, rewards)
	rewards.take(slot)
	var generation: int = sim.pool.generation[slot]
	sim.events.push(Events.Kind.EVADED, sim.clock.tick, slot, generation, 0)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(slot), 0.05), "making a player dodge earns 0.05")
	sim.events.push(Events.Kind.DODGED, sim.clock.tick, slot, generation, 0)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(slot), 0.01), "dodging a player's hit earns 0.01")
	sim.events.push(Events.Kind.RELEASE, sim.clock.tick, slot, generation, 0)
	sim.events.push(Events.Kind.HIT, sim.clock.tick, slot, generation, 0, 30)
	step(sim, rewards)
	check(is_zero_approx(rewards.take(slot)), "a basic attack landing without damage earns nothing extra")
	sim.events.push(Events.Kind.RELEASE, sim.clock.tick, slot, generation, 1)
	sim.events.push(Events.Kind.HIT, sim.clock.tick, slot, generation, 0, 30)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(slot), 0.02), "an ability landing on a player earns 0.02, even without damage")
	sim.party.set_timers(0, 0, 0, sim.clock.tick + 20)
	sim.events.push(Events.Kind.HIT, sim.clock.tick, slot, generation, 0, 30)
	step(sim, rewards)
	check(is_zero_approx(rewards.take(slot)), "an ability the player dodged earns nothing for landing")


func test_squad_mix() -> void:
	var sim := make_sim()
	var hitter := add_mob(sim, "rootbound", Vector2.ZERO)
	var mate := add_mob(sim, "rootbound", Vector2(1.5, 0))
	sim.perception.refresh_allies(PackedInt32Array([hitter, mate]), sim.clock.tick)
	var rewards := Rewards.new(sim)
	check(is_equal_approx(rewards.squad_mix, 0.2), "the squad mix starts at its configured share")
	step(sim, rewards)
	rewards.take(hitter)
	rewards.take(mate)
	sim.record_hit(hitter, sim.pool.generation[hitter], 0, 100.0)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(hitter), 1.6) and is_equal_approx(rewards.take(mate), 0.4), "an ally receives the squad's share")
