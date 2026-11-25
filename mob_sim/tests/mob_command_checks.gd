extends SceneTree
## Checks the fight's commander (mob_sim/mob_command.gd): who commands, promotion when it dies, orders that hold
## for commander_message_ms, idle followers that stay near their own spawn, and the commander's reward share.

const Battlefield = preload("res://battlefield.gd")
const Clock = preload("res://mob_sim/mob_clock.gd")
const Contract = preload("res://mob_sim/mob_contract.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Rewards = preload("res://ai/mob_rewards.gd")
const Sim = preload("res://mob_sim/mob_sim.gd")


## Sends a new message every decision and otherwise idles, so the commander's hold is what limits its orders.
## It also checks, at every decision, that a commander whose order holds is offered only the message it is sending.
class Talker extends "res://mob_sim/mob_brain.gd":
	const Head = preload("res://mob_sim/mob_contract.gd").Head
	var symbol := 0
	var held := 0
	var held_ok := true

	func decide(batch: Batch) -> void:
		var contract = batch.contract
		var pool = batch.pool
		for index in batch.slots.size():
			var slot: int = batch.slots[index]
			if pool.flags[slot] & 1 == 0 or batch.clock.tick >= pool.message_until[slot]:
				continue
			held += 1
			var offset: int = index * contract.mask_size + contract.head_offsets[Head.MESSAGE_A]
			for option in contract.message_symbols:
				held_ok = held_ok and batch.masks[offset + option] == int(option == pool.message_a[slot])
		symbol = symbol % (contract.message_symbols - 1) + 1
		for index in batch.slots.size():
			batch.write_intent(index, batch.contract.id("idle_wander"), 0, 0, 0, symbol, symbol, 0)


var failures := 0
var checks := 0


func _initialize() -> void:
	if not NavWorld.ensure_loaded():
		print("FAIL native extension did not load")
		quit(2)
		return
	test_choice()
	test_orders_hold()
	test_idle_followers()
	test_reward_share()
	print("PASSED: %d checks, %d failures" % [checks, failures] if failures == 0 else "FAILED: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, label: String) -> void:
	checks += 1
	print("PASS " if condition else "FAIL ", label)
	failures += int(not condition)


func make_sim(slots: int, brain: RefCounted = null) -> Sim:
	var field = Battlefield.new()
	field.configure(0, 1)
	preload("res://tests/support/terrain_case.gd").walls(field, [])
	var sim := Sim.new(slots, brain)
	sim.configure(field)
	return sim


func add_mob(sim: Sim, at: Vector2, intelligence: float, flags := 0) -> int:
	var request := Pool.Spawn.new()
	request.species = sim.species.ids.find("rootbound")
	request.at = at
	request.hp = 100.0
	request.damage = 2.0
	request.intelligence = intelligence
	request.flags = flags
	return sim.spawn(request)


func followers_of(sim: Sim, chief: int) -> bool:
	for slot in sim.pool.active:
		if slot != chief and sim.pool.leader_of(slot) != chief:
			return false
	return sim.pool.leader_of(chief) == -1


func test_choice() -> void:
	var sim := make_sim(6)
	var contract := sim.contract
	check(bool(contract.rules.commander) and int(contract.rules.commander_message_ms) == 1000, "the contract turns commanders on with orders held 1 s")
	var dim := add_mob(sim, Vector2(0, 0), 0.3)
	var bright := add_mob(sim, Vector2(2, 0), 0.9)
	var middle := add_mob(sim, Vector2(4, 0), 0.6)
	sim.tick()
	check(sim.command.commander == bright and followers_of(sim, bright), "without an elite the brightest mob commands and the rest follow it")
	check(sim.pool.flags[bright] & Pool.FLAG_LEADER != 0 and sim.pool.flags[dim] & Pool.FLAG_LEADER == 0, "only the commander carries the leader flag")
	check(sim.pool.is_leader(bright) and not sim.pool.is_leader(middle), "the commander reads as a leader in its own inputs")
	sim.damage_mob(bright, 1000.0)
	sim.tick()
	check(sim.command.commander == middle and followers_of(sim, middle), "when the commander dies the brightest survivor takes over")
	var elite := add_mob(sim, Vector2(6, 0), 0.1, Pool.FLAG_LEADER | Pool.FLAG_ELITE)
	sim.tick()
	check(sim.command.commander == elite and followers_of(sim, elite), "an elite takes command while it lives")
	check(sim.pool.flags[middle] & Pool.FLAG_LEADER == 0, "the replaced commander loses the leader flag")


func test_orders_hold() -> void:
	var brain := Talker.new()
	var sim := make_sim(4, brain)
	var contract := sim.contract
	var chief := add_mob(sim, Vector2(0, 0), 1.0)
	var mate := add_mob(sim, Vector2(3, 0), 0.5)
	sim.party.set_player(0, Vector2(0, 8), Vector2.ZERO, 100.0, 100.0)
	var hold := Clock.from_ms(float(contract.rules.commander_message_ms))
	var chief_changes := PackedInt32Array()
	var mate_changes := 0
	var last_chief: int = sim.pool.message_a[chief]
	var last_mate: int = sim.pool.message_a[mate]
	for tick in hold * 4:
		sim.tick()
		if sim.pool.message_a[chief] != last_chief:
			chief_changes.append(sim.clock.tick)
			last_chief = sim.pool.message_a[chief]
		mate_changes += int(sim.pool.message_a[mate] != last_mate)
		last_mate = sim.pool.message_a[mate]
	var gaps_ok := chief_changes.size() >= 3
	for index in range(1, chief_changes.size()):
		gaps_ok = gaps_ok and chief_changes[index] - chief_changes[index - 1] >= hold
	check(gaps_ok, "the commander's orders change at most once per hold (%d changes in %d ticks)" % [chief_changes.size(), hold * 4])
	check(mate_changes > chief_changes.size() * 2, "followers still talk freely (%d changes)" % mate_changes)
	check(brain.held > 0 and brain.held_ok, "while an order holds, only the message being sent is legal for the commander (%d decisions)" % brain.held)


func test_idle_followers() -> void:
	for reference in [false, true]:
		var sim := make_sim(4)
		if reference:
			sim.use_reference_executors()
		var chief := add_mob(sim, Vector2(-15, -15), 1.0)
		var follower := add_mob(sim, Vector2(15, 15), 0.2)
		for tick in 600:
			sim.tick()
		var from_spawn := Vector2(sim.pool.xz[follower * 2], sim.pool.xz[follower * 2 + 1]).distance_to(Vector2(15, 15))
		check(sim.pool.leader_of(follower) == chief and from_spawn < 10.0,
			"%s: an idle follower of a regular commander stays near its own spawn (%.1f m)" % ["reference" if reference else "native", from_spawn])
	var sim := make_sim(4)
	var elite := add_mob(sim, Vector2(-15, -15), 0.5, Pool.FLAG_LEADER | Pool.FLAG_ELITE)
	var packed := add_mob(sim, Vector2(15, 15), 0.2)
	for tick in 900:
		sim.tick()
	var moved := Vector2(sim.pool.xz[packed * 2], sim.pool.xz[packed * 2 + 1]).distance_to(Vector2(15, 15))
	check(moved > 15.0, "an elite still gathers its idle pack (the follower walked %.1f m toward it)" % moved)


func test_reward_share() -> void:
	var sim := make_sim(6)
	var chief := add_mob(sim, Vector2(0, 0), 1.0)
	var first := add_mob(sim, Vector2(2, 0), 0.4)
	var second := add_mob(sim, Vector2(4, 0), 0.3)
	sim.tick()
	var rewards := Rewards.new(sim)
	rewards.squad_mix = 0.0
	rewards.tick()
	var share := float(rewards.weights.commander_team_share)
	rewards._keep(first, 1.0, "damage")
	rewards._give(second, 0.5, "damage")
	check(is_equal_approx(rewards.take(chief), share * 1.5 / 2.0), "the commander earns its share of the followers' average reward (%.3f)" % share)
	check(is_equal_approx(rewards.take(first), 1.0) and is_equal_approx(rewards.take(second), 0.5), "followers keep their own rewards whole")
	rewards._keep(chief, 1.0, "damage")
	check(is_equal_approx(rewards.take(chief), 1.0), "the commander's own reward is not shared back to itself")
	check(is_equal_approx(rewards._value(chief), float(rewards.weights.mob_value_basic)), "a regular commander is valued as a regular mob")
