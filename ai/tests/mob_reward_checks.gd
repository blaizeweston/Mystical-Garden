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
	test_sight_skips_healthy_retreat()
	test_first_sight()
	test_dodges_and_abilities()
	test_squad_mix()
	test_retreat()
	test_share_needs_contribution()
	test_guard_unused()
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
	var per_bar := float(rewards.weights.damage_to_player_per_health_bar)
	check(is_equal_approx(rewards.take(slot), per_bar * 0.5), "half a player's health bar earns half the per-bar damage reward (%.2f)" % (per_bar * 0.5))
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
	check(is_equal_approx(rewards.take(hitter), 4.0), "the mob that downed a player earns 3 for the down and 1 for the killing blow")
	check(is_zero_approx(rewards.take(bystander)), "a mob that never hit the player earns nothing for the down")
	sim.party.set_player(1, Vector2(0, -6), Vector2.ZERO, 0.0, 100.0)
	step(sim, rewards)
	var wipe := float(rewards.weights.party_wipe)
	check(is_equal_approx(rewards.take(hitter), wipe), "a mob that hit a player in the last 10 s earns the wipe reward (%.1f) when the party is wiped" % wipe)
	check(is_zero_approx(rewards.take(bystander)), "a mob that kept out of the fight earns nothing for the wipe")
	check(rewards.totals.killing_blows == 1 and rewards.totals.wipes == 1, "the report counts killing blows and wipes")


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
	check(is_zero_approx(rewards.take(slot)), "changing intent costs nothing (holds already prevent thrashing)")
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
	var rate := float(rewards.weights.line_of_sight_per_second)
	var cap := float(rewards.weights.line_of_sight_cap_per_decision)
	check(earned > 0.0 and earned <= cap + 1e-6, "sight of the target earns at most %.4f between decisions (%.4f)" % [cap, earned])
	step(sim, rewards, 30)
	var half_second := rewards.take(slot)
	check(is_equal_approx(half_second, minf(cap, rate * 0.5)), "sight of the target earns %.3f a second, capped (%.4f in half a second)" % [rate, half_second])


## A mob retreating while healthy earns no sight reward; one below the free line, or not retreating, still does.
func test_sight_skips_healthy_retreat() -> void:
	var sim := make_sim()
	var slot := add_mob(sim, "rootbound", Vector2.ZERO)
	var rewards := solo(sim)
	rewards.weights["first_sight"] = 0.0
	rewards.weights["retreat_per_second"] = 0.0
	check(bool(rewards.weights.get("sight_skips_healthy_retreat", false)), "sight skips healthy retreaters")
	var free_below := float(rewards.weights.retreat_free_below_hp_fraction)
	var expected := minf(float(rewards.weights.line_of_sight_cap_per_decision), float(rewards.weights.line_of_sight_per_second) * 0.5)
	sim.pool.enemy_target[slot] = 1
	var row: int = slot * sim.contract.players
	sim.perception.seen_tick[row] = sim.clock.tick
	sim.perception.visible[row] = 1
	step(sim, rewards)
	rewards.take(slot)
	for label in ["take_cover", "hide", "flee"]:
		sim.pool.behaviour[slot] = sim.contract.id(label)
		step(sim, rewards, 30)
		check(is_zero_approx(rewards.take(slot)), "a healthy mob earns no sight reward during %s" % label)
	sim.pool.behaviour[slot] = sim.contract.id("ranged_attack")
	step(sim, rewards, 30)
	check(is_equal_approx(rewards.take(slot), expected), "an attacking mob still earns the sight reward")
	sim.pool.behaviour[slot] = sim.contract.id("take_cover")
	sim.pool.hp[slot] = (free_below - 0.05) * sim.pool.max_hp[slot]
	step(sim, rewards, 30)
	check(is_equal_approx(rewards.take(slot), expected), "a badly hurt mob in cover still earns the sight reward")

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
	rewards.weights["squad_share_needs_contribution"] = false
	var mix := float(rewards.weights.squad_mix_start)
	check(mix > 0.0 and is_equal_approx(rewards.squad_mix, mix), "the squad mix starts at its configured share (%.2f)" % mix)
	step(sim, rewards)
	rewards.take(hitter)
	rewards.take(mate)
	sim.record_hit(hitter, sim.pool.generation[hitter], 0, 100.0)
	step(sim, rewards)
	var earned := float(rewards.weights.damage_to_player_per_health_bar)
	check(is_equal_approx(rewards.take(hitter), earned * (1.0 - mix)) and is_equal_approx(rewards.take(mate), earned * mix), "an ally receives the squad's share")
	# A second player stays up, so this down does not also wipe the party.
	sim.party.set_player(1, Vector2(0, -6), Vector2.ZERO, 100.0, 100.0)
	step(sim, rewards)
	rewards.take(hitter)
	rewards.take(mate)
	sim.party.set_player(0, Vector2(0, 6), Vector2.ZERO, 0.0, 100.0)
	step(sim, rewards)
	var down := float(rewards.weights.player_downed)
	check(is_equal_approx(rewards.take(hitter), down * (1.0 - mix) + 1.0) and is_equal_approx(rewards.take(mate), down * mix),
		"the killing blow is kept whole while the down is shared with the squad")
	rewards.weights["first_sight"] = 0.0
	rewards.weights["line_of_sight_per_second"] = 0.0
	rewards.weights["support_alive_casting_per_second"] = 0.0
	sim.pool.behaviour[hitter] = sim.contract.id("take_cover")
	step(sim, rewards, 60)
	check(is_equal_approx(rewards.take(hitter), float(rewards.weights.retreat_per_second)) and is_zero_approx(rewards.take(mate)),
		"the retreat cost is kept whole: allies share none of it")
	test_share_skips_healthy_retreat()


## A mob retreating while healthy gets no share of an ally's gain (the earner keeps it), but still shares losses.
func test_share_skips_healthy_retreat() -> void:
	var sim := make_sim()
	var hitter := add_mob(sim, "rootbound", Vector2.ZERO)
	var mate := add_mob(sim, "rootbound", Vector2(1.5, 0))
	var third := add_mob(sim, "rootbound", Vector2(-1.5, 0))
	sim.perception.refresh_allies(PackedInt32Array([hitter, mate, third]), sim.clock.tick)
	var rewards := Rewards.new(sim)
	for key in ["first_sight", "line_of_sight_per_second", "support_alive_casting_per_second", "retreat_per_second"]:
		rewards.weights[key] = 0.0
	rewards.weights["squad_share_needs_contribution"] = false
	var mix := rewards.squad_mix
	var free_below := float(rewards.weights.retreat_free_below_hp_fraction)
	check(bool(rewards.weights.get("squad_share_skips_healthy_retreat", false)), "the squad share skips healthy retreaters")
	var earned := float(rewards.weights.damage_to_player_per_health_bar) * 0.5
	var lost := -float(rewards.weights.own_hp_lost_per_health_bar) * 0.25
	step(sim, rewards)
	for slot in [hitter, mate, third]:
		rewards.take(slot)
	sim.pool.behaviour[mate] = sim.contract.id("take_cover")
	sim.record_hit(hitter, sim.pool.generation[hitter], 0, 50.0)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(hitter), earned * (1.0 - mix)) and is_zero_approx(rewards.take(mate))
		and is_equal_approx(rewards.take(third), earned * mix), "a healthy mate in cover gets no share; the fighting ally gets it all")
	sim.pool.behaviour[third] = sim.contract.id("hide")
	sim.record_hit(hitter, sim.pool.generation[hitter], 0, 50.0)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(hitter), earned) and is_zero_approx(rewards.take(mate)) and is_zero_approx(rewards.take(third)),
		"with every ally hiding, the earner keeps the whole gain")
	sim.pool.hp[mate] = (free_below - 0.05) * sim.pool.max_hp[mate]
	sim.record_hit(hitter, sim.pool.generation[hitter], 0, 50.0)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(hitter), earned * (1.0 - mix)) and is_equal_approx(rewards.take(mate), earned * mix)
		and is_zero_approx(rewards.take(third)), "a badly hurt mate in cover still gets its share")
	sim.pool.hp[mate] = sim.pool.max_hp[mate]
	sim.damage_mob(hitter, 25.0, 0)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(hitter), lost * (1.0 - mix)) and is_equal_approx(rewards.take(mate), lost * mix / 2.0)
		and is_equal_approx(rewards.take(third), lost * mix / 2.0), "losses are still shared with healthy retreaters")


func test_retreat() -> void:
	var sim := make_sim()
	var slot := add_mob(sim, "rootbound", Vector2.ZERO)
	var rewards := solo(sim)
	rewards.weights["first_sight"] = 0.0
	rewards.weights["line_of_sight_per_second"] = 0.0
	rewards.weights["guard_unused"] = 0.0
	var rate := float(rewards.weights.retreat_per_second)
	var free_below := float(rewards.weights.retreat_free_below_hp_fraction)
	check(rate < 0.0 and free_below > 0.0, "retreating costs %.4f a second above %.0f%% health" % [rate, free_below * 100.0])
	step(sim, rewards)
	rewards.take(slot)
	step(sim, rewards, 60)
	check(is_zero_approx(rewards.take(slot)), "a mob that is not retreating pays nothing")
	for label in ["take_cover", "hide", "flee"]:
		sim.pool.behaviour[slot] = sim.contract.id(label)
		step(sim, rewards, 60)
		check(is_equal_approx(rewards.take(slot), rate), "a healthy mob pays %.4f for a second of %s" % [rate, label])
	for label in ["ranged_attack", "melee_attack", "approach", "defend_ally"]:
		sim.pool.behaviour[slot] = sim.contract.id(label)
		step(sim, rewards, 60)
		check(is_zero_approx(rewards.take(slot)), "%s costs nothing" % label)
	sim.pool.behaviour[slot] = sim.contract.id("take_cover")
	sim.pool.hp[slot] = (free_below - 0.05) * sim.pool.max_hp[slot]
	step(sim, rewards, 60)
	check(is_zero_approx(rewards.take(slot)), "a mob below %.0f%% health retreats for free" % (free_below * 100.0))
	sim.pool.hp[slot] = (free_below + 0.05) * sim.pool.max_hp[slot]
	step(sim, rewards, 60)
	check(is_equal_approx(rewards.take(slot), rate), "a mob just above the line pays again")
	check(is_equal_approx(float(rewards.totals.retreat), rate * 4.0), "the report sums the retreat cost (%.4f)" % float(rewards.totals.retreat))


## Rewards with every trickle and the guard cost off, so only the shares under test move.
func quiet(rewards: Rewards) -> Rewards:
	for key in ["first_sight", "line_of_sight_per_second", "support_alive_casting_per_second", "retreat_per_second", "guard_unused"]:
		rewards.weights[key] = 0.0
	return rewards


func take_all(rewards: Rewards, slots: Array) -> void:
	for slot in slots:
		rewards.take(slot)


## An ally gets a share of gains only after contributing within the window (or while badly hurt); losses reach all.
func test_share_needs_contribution() -> void:
	var sim := make_sim()
	var hitter := add_mob(sim, "rootbound", Vector2.ZERO)
	var mate := add_mob(sim, "rootbound", Vector2(1.5, 0))
	var third := add_mob(sim, "rootbound", Vector2(-1.5, 0))
	var everyone := [hitter, mate, third]
	sim.perception.refresh_allies(PackedInt32Array(everyone), sim.clock.tick)
	var rewards := quiet(Rewards.new(sim))
	var mix := rewards.squad_mix
	var free_below := float(rewards.weights.retreat_free_below_hp_fraction)
	var window := float(rewards.weights.contribution_window_seconds)
	check(bool(rewards.weights.get("squad_share_needs_contribution", false)) and window > 0.0,
		"the squad share needs a contribution within %.0f s" % window)
	var earned := float(rewards.weights.damage_to_player_per_health_bar) * 0.5
	var lost := -float(rewards.weights.own_hp_lost_per_health_bar) * 0.25
	step(sim, rewards)
	take_all(rewards, everyone)
	sim.record_hit(hitter, sim.pool.generation[hitter], 0, 50.0)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(hitter), earned) and is_zero_approx(rewards.take(mate)) and is_zero_approx(rewards.take(third)),
		"allies that have not contributed get no share: the earner keeps the whole gain")
	sim.record_hit(mate, sim.pool.generation[mate], 0, 2.0)
	step(sim, rewards)
	take_all(rewards, everyone)
	sim.record_hit(hitter, sim.pool.generation[hitter], 0, 50.0)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(hitter), earned * (1.0 - mix)) and is_equal_approx(rewards.take(mate), earned * mix)
		and is_zero_approx(rewards.take(third)), "a mate that hit a player gets the squad's share")
	step(sim, rewards, int(window * 60.0) + 6)
	take_all(rewards, everyone)
	sim.record_hit(hitter, sim.pool.generation[hitter], 0, 50.0)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(hitter), earned) and is_zero_approx(rewards.take(mate)),
		"the share stops once the mate's last contribution is older than the window")
	sim.pool.hp[third] = (free_below - 0.05) * sim.pool.max_hp[third]
	sim.record_hit(hitter, sim.pool.generation[hitter], 0, 50.0)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(hitter), earned * (1.0 - mix)) and is_equal_approx(rewards.take(third), earned * mix),
		"a badly hurt mate still gets its share without contributing")
	sim.pool.hp[third] = sim.pool.max_hp[third]
	sim.damage_mob(hitter, 25.0, 0)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(hitter), lost * (1.0 - mix)) and is_equal_approx(rewards.take(mate), lost * mix / 2.0)
		and is_equal_approx(rewards.take(third), lost * mix / 2.0), "losses are still shared with allies that did not contribute")
	take_all(rewards, everyone)
	sim.events.push(Events.Kind.EVADED, sim.clock.tick, mate, sim.pool.generation[mate], 0)
	step(sim, rewards)
	take_all(rewards, everyone)
	sim.record_hit(hitter, sim.pool.generation[hitter], 0, 50.0)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(mate), earned * mix), "making a player dodge counts as contributing")
	test_share_from_supports()


## A casting support, and a mob guarding a support with defend_ally, count as contributing.
func test_share_from_supports() -> void:
	var sim := make_sim()
	var hitter := add_mob(sim, "rootbound", Vector2.ZERO)
	var support := add_mob(sim, "bellcap", Vector2(1.5, 0))
	var guard := add_mob(sim, "rootbound", Vector2(-1.5, 0))
	var everyone := [hitter, support, guard]
	sim.perception.refresh_allies(PackedInt32Array(everyone), sim.clock.tick)
	var rewards := quiet(Rewards.new(sim))
	var mix := rewards.squad_mix
	var earned := float(rewards.weights.damage_to_player_per_health_bar) * 0.5
	step(sim, rewards)
	sim.pool.windup_until[support] = sim.clock.tick + 120
	for index in sim.contract.allies:
		if sim.perception.ally(guard, index) == support:
			sim.pool.ally_target[guard] = index + 1
	sim.pool.behaviour[guard] = sim.contract.id("defend_ally")
	step(sim, rewards, 6)
	take_all(rewards, everyone)
	sim.record_hit(hitter, sim.pool.generation[hitter], 0, 50.0)
	step(sim, rewards)
	check(is_equal_approx(rewards.take(support), earned * mix / 2.0) and is_equal_approx(rewards.take(guard), earned * mix / 2.0),
		"a casting support and a mob defending it both get their share")


## Guarding costs guard_unused for each window in which neither the guard nor what it guards was attacked.
func test_guard_unused() -> void:
	var sim := make_sim()
	var guard := add_mob(sim, "rootbound", Vector2.ZERO)
	var ward := add_mob(sim, "rootbound", Vector2(1.5, 0))
	var other := add_mob(sim, "rootbound", Vector2(-1.5, 0))
	var everyone := [guard, ward, other]
	sim.perception.refresh_allies(PackedInt32Array(everyone), sim.clock.tick)
	var rewards := solo(sim)
	for key in ["first_sight", "line_of_sight_per_second", "support_alive_casting_per_second", "retreat_per_second"]:
		rewards.weights[key] = 0.0
	var cost := float(rewards.weights.guard_unused)
	var window := int(float(rewards.weights.guard_window_seconds) * 60.0)
	check(cost < 0.0 and window > 0, "guarding unanswered costs %.3f per %d s" % [cost, window / 60])
	var lost := -float(rewards.weights.own_hp_lost_per_health_bar) * 0.1
	var ward_index := -1
	for index in sim.contract.allies:
		if sim.perception.ally(guard, index) == ward:
			ward_index = index
	check(ward_index >= 0, "the guard sees its ward among its allies")
	sim.pool.ally_target[guard] = ward_index + 1
	# Line up so the next tick adds trickles, which opens the window on it.
	while (sim.clock.tick + 1) % 6 != 0:
		step(sim, rewards)
	sim.pool.behaviour[guard] = sim.contract.id("defend_ally")
	step(sim, rewards)
	take_all(rewards, everyone)
	step(sim, rewards, window - 1)
	check(is_zero_approx(rewards.take(guard)), "nothing is charged before the window ends")
	step(sim, rewards)
	check(is_equal_approx(rewards.take(guard), cost), "defending an ally that nobody attacks for %d s costs %.3f" % [window / 60, cost])
	# Each window below runs exactly `window` ticks and is judged on its last tick, which opens the next one.
	step(sim, rewards, 60)
	sim.damage_mob(ward, 10.0, 0)
	step(sim, rewards, window - 60)
	take_all(rewards, [ward, other])
	check(is_zero_approx(rewards.take(guard)), "defending an ally that is attacked costs nothing")
	step(sim, rewards, 60)
	sim.damage_mob(other, 10.0, 0)
	step(sim, rewards, window - 60)
	take_all(rewards, [ward, other])
	check(is_equal_approx(rewards.take(guard), cost), "an attack on a different ally does not answer defend_ally")
	step(sim, rewards, 60)
	sim.damage_mob(guard, 10.0, 0)
	step(sim, rewards, window - 61)
	sim.pool.behaviour[guard] = sim.contract.id("block_enemy")
	step(sim, rewards)
	check(is_equal_approx(rewards.take(guard), lost), "a guard that is attacked itself pays only for the hit")
	step(sim, rewards, 60)
	sim.events.push(Events.Kind.DODGED, sim.clock.tick, other, sim.pool.generation[other], 0)
	step(sim, rewards, window - 60)
	take_all(rewards, [ward, other])
	check(is_zero_approx(rewards.take(guard)), "block_enemy is answered when any nearby ally is attacked (a dodge counts)")
	step(sim, rewards, window)
	check(is_equal_approx(rewards.take(guard), cost), "block_enemy with no attack on itself or its allies costs %.3f" % cost)
	sim.pool.behaviour[guard] = sim.contract.id("ranged_attack")
	step(sim, rewards, window)
	check(is_equal_approx(rewards.take(guard), cost), "the window still judges the guard that was started, after the mob stops guarding")
	step(sim, rewards, window * 2)
	check(is_zero_approx(rewards.take(guard)), "a mob that is not guarding pays nothing")
	check(is_equal_approx(float(rewards.totals.guard_unused), cost * 4.0), "the report sums the guard cost (%.3f)" % float(rewards.totals.guard_unused))
