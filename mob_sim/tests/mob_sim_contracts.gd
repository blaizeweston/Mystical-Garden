extends SceneTree
## Proves each architecture contract without loading the game.

const Arena = preload("res://mob_sim/tests/mob_sim_arena.gd")
const Battlefield = preload("res://battlefield.gd")
const Catalog = preload("res://enemy_catalog.gd")
const Clock = preload("res://mob_sim/mob_clock.gd")
const Contract = preload("res://mob_sim/mob_contract.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Sim = preload("res://mob_sim/mob_sim.gd")
const Species = preload("res://mob_sim/mob_species.gd")

const HP := 50.0
const HIT := 10.0


class ForcedBrain extends "res://mob_sim/mob_brain.gd":
	var behaviour := 0
	var enemy := 0
	var ally := 0
	var manoeuvre := 0
	var message := 0
	var calls := 0
	var seen_slots := PackedInt32Array()
	var last_masks := PackedByteArray()
	var reset_slots := PackedInt32Array()

	func reset_slot(slot: int) -> void:
		reset_slots.append(slot)

	func decide(batch: Batch) -> void:
		calls += 1
		seen_slots.append_array(batch.slots)
		last_masks = batch.masks.duplicate()
		for index in batch.slots.size():
			batch.write_intent(index, behaviour, enemy, ally, manoeuvre, message, message)


var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL ", label)


## An open arena with one wall across the middle, from x = -6 to x = 6 at z = 0.
func walled_field() -> RefCounted:
	var field = Battlefield.new()
	field.configure(0, 1)
	preload("res://tests/support/terrain_case.gd").walls(field,[Rect2(-6.0, -0.5, 12.0, 1.0)])
	return field


func make_sim(slots: int, brain: RefCounted = null) -> Sim:
	var sim := Sim.new(slots, brain)
	check(sim.configure(walled_field()) == OK, "the test map bakes")
	return sim


func kind_of(sim: Sim, label: String) -> int:
	return sim.species.ids.find(label)


func add_mob(sim: Sim, label: String, at: Vector2, flags := 0, mutations := 0, leader := -1) -> int:
	var request := Pool.Spawn.new()
	request.species = kind_of(sim, label)
	request.at = at
	request.hp = HP
	request.damage = HIT
	request.flags = flags
	request.mutations = mutations
	request.leader = leader
	return sim.spawn(request)


func place_player(sim: Sim, player: int, at: Vector2, velocity := Vector2.ZERO) -> void:
	sim.party.set_player(player, at, velocity, 100.0, 100.0)


func run_ticks(sim: Sim, ticks: int) -> void:
	for tick in ticks:
		sim.tick()


func events_of(sim: Sim, kind: int, cursor := 0) -> Array[Dictionary]:
	return sim.events.read_since(cursor).filter(func(event: Dictionary) -> bool: return event.kind == kind)


func test_contract() -> void:
	var contract := Contract.new()
	check(contract.errors.is_empty(), "the contract loads without errors")
	check(contract.behaviour_count == 14, "the contract defines 14 behaviours")
	check(contract.head_sizes == PackedInt32Array([14, 5, 8, 5, 4, 4]), "the action heads have the agreed sizes")
	check(contract.mask_size == 40, "the action heads total 40 options")
	check(contract.available[contract.id("hide")] == 0, "hide is unavailable until darkness exists")
	check(contract.available[contract.id("dodge")] == 0, "dodge is unavailable until mobs can dodge")
	var sim := make_sim(1)
	for index in contract.behaviour_count:
		check(sim.executors._run[index].is_valid(), "behaviour %s has an executor" % contract.names[index])


func test_clock() -> void:
	check(Clock.from_ms(1000) == 60, "one second is 60 ticks")
	check(Clock.from_ms(750) == 45, "wind-ups convert exactly")
	check(Clock.from_ms(1) == 1, "any positive time lasts at least one tick")


func test_species() -> void:
	var table := Species.new()
	check(table.count == Catalog.all().size(), "every catalog species is compiled")
	var bosses := 0
	for kind in table.count:
		bosses += int(table.spawnable[kind] == 0)
		if table.spawnable[kind] != 0:
			var attacks := 0
			for slot in Species.ATTACKS:
				attacks += table.attack_exists[kind * Species.ATTACKS + slot]
			check(attacks > 0, "%s has an attack" % table.ids[kind])
	check(bosses == 4, "the four bosses stay outside the pool")
	var root := table.ids.find("rootbound")
	check(table.attack_delivery[root * Species.ATTACKS] == Contract.Delivery.MELEE, "a swipe is a basic melee attack")
	var bloom := table.ids.find("nightbloom")
	check(table.attack_delivery[bloom * Species.ATTACKS] == Contract.Delivery.RANGED, "a volley is a basic ranged attack")
	var horn := table.ids.find("gallhorn")
	check(table.attack_exists[horn * Species.ATTACKS] == 0, "a charger has no basic attack")
	check(table.attack_shape[horn * Species.ATTACKS + 1] == Species.Shape.DASH, "a charge is ability 1")
	var bell := table.ids.find("bellcap")
	check(table.attack_lonely[bell * Species.ATTACKS] == 1, "a support's basic attack needs it to be alone")
	check(table.has_attack(root, 2, Catalog.MOBILITY) and not table.has_attack(root, 2, 0), "the vault needs the mobility mutation")


func test_pool() -> void:
	var sim := make_sim(2)
	var first := add_mob(sim, "rootbound", Vector2(10, 10), Pool.FLAG_LEADER)
	var second := add_mob(sim, "rootbound", Vector2(12, 10), 0, 0, first)
	check(first == 0 and second == 1, "slots fill in order")
	check(add_mob(sim, "rootbound", Vector2(14, 10)) == -1, "a full pool refuses another mob")
	check(sim.pool.is_leader(first) and not sim.pool.is_leader(second), "a leader is a normal slot with a flag")
	check(sim.pool.leader_of(second) == first, "a mob knows its leader")
	var boss := Pool.Spawn.new()
	boss.species = kind_of(sim, "orchard")
	boss.hp = HP
	sim.damage_mob(second, HP)
	check(sim.spawn(boss) == -1, "bosses cannot enter the pool")
	var old_generation: int = sim.pool.generation[first]
	sim.damage_mob(first, HP)
	var again := add_mob(sim, "rootbound", Vector2(14, 10))
	check(again == first and sim.pool.generation[again] == old_generation + 1, "a reused slot gets a new generation")


func test_masks() -> void:
	var brain := ForcedBrain.new()
	var sim := make_sim(2, brain)
	var contract := sim.contract
	brain.behaviour = contract.id("approach")
	brain.enemy = 1
	var slot := add_mob(sim, "rootbound", Vector2(10, 10))
	place_player(sim, 0, Vector2(10.8, 10))
	run_ticks(sim, 12)
	check(brain.calls > 0, "an alerted mob reaches the awake brain")
	var masks := brain.last_masks
	check(masks[contract.id("melee_attack")] == 1, "a ready melee attack is legal")
	check(masks[contract.id("ranged_attack")] == 0, "a melee species cannot pick a ranged attack")
	check(masks[contract.id("ability_1")] == 0, "a missing ability is masked")
	check(masks[contract.id("ability_3")] == 0, "ability 3 is masked for ordinary mobs")
	check(masks[contract.id("hide")] == 0 and masks[contract.id("dodge")] == 0, "missing mechanics are masked")
	var enemy_base := contract.head_offsets[Contract.Head.ENEMY_TARGET]
	check(masks[enemy_base] == 1 and masks[enemy_base + 1] == 1 and masks[enemy_base + 2] == 0, "only known players can be targeted")
	var message_base := contract.head_offsets[Contract.Head.MESSAGE_A]
	check(masks[message_base] == 1 and masks[message_base + 1] == 0, "messages stay silent for now")
	sim.pool.ready_at[slot] = sim.clock.tick + 600
	run_ticks(sim, 8)
	check(brain.last_masks[contract.id("melee_attack")] == 0, "an attack on cooldown is masked")


func test_rules() -> void:
	var brain := ForcedBrain.new()
	var sim := make_sim(1, brain)
	var contract := sim.contract
	var slot := add_mob(sim, "rootbound", Vector2(10, 10))
	place_player(sim, 0, Vector2(13, 10))
	brain.behaviour = contract.id("hide")
	brain.enemy = 1
	run_ticks(sim, 14)
	check(sim.rules.rejected > 0, "an illegal intent is refused")
	check(sim.pool.behaviour[slot] != contract.id("hide"), "a refused intent never becomes active")
	brain.behaviour = 200
	var before: int = sim.rules.rejected
	run_ticks(sim, 8)
	check(sim.rules.rejected > before, "an out-of-range behaviour is refused")

	brain.behaviour = contract.id("flee")
	run_ticks(sim, 8)
	check(sim.pool.behaviour[slot] == contract.id("flee"), "a legal intent is applied")
	var started: int = sim.pool.behaviour_since[slot]
	var hold_end: int = sim.pool.hold_until[slot]
	brain.behaviour = contract.id("approach")
	while sim.clock.tick + 1 < hold_end:
		sim.tick()
		check(sim.pool.behaviour[slot] == contract.id("flee"), "the minimum hold blocks a new behaviour")
	run_ticks(sim, 10)
	check(sim.pool.behaviour[slot] == contract.id("approach") and sim.pool.behaviour_since[slot] > started, "a new behaviour applies after the hold")


func test_attack_timing() -> void:
	var brain := ForcedBrain.new()
	var sim := make_sim(1, brain)
	var contract := sim.contract
	var kind := kind_of(sim, "rootbound")
	var slot := add_mob(sim, "rootbound", Vector2(10, 10))
	place_player(sim, 0, Vector2(10.8, 10))
	brain.behaviour = contract.id("melee_attack")
	brain.enemy = 1
	var limit := 120
	while sim.pool.windup_until[slot] == 0 and limit > 0:
		sim.tick()
		limit -= 1
	check(limit > 0, "a mob in reach starts its attack")
	var start: int = sim.clock.tick
	var windup: int = sim.species.attack_windup[kind * Species.ATTACKS]
	check(sim.pool.windup_until[slot] == start + windup, "the wind-up lasts the species time")
	check(sim.party.attackers[0] == 1, "the attacker is counted during the wind-up")
	var held := Vector2(sim.pool.xz[slot * 2], sim.pool.xz[slot * 2 + 1])
	var locked := Vector2(sim.pool.aim_x[slot], sim.pool.aim_z[slot])
	place_player(sim, 0, Vector2(16, 10))
	run_ticks(sim, windup - 1)
	check(events_of(sim, Events.Kind.RELEASE).is_empty(), "nothing is released before the wind-up ends")
	check(held.is_equal_approx(Vector2(sim.pool.xz[slot * 2], sim.pool.xz[slot * 2 + 1])), "a mob stands still while winding up")
	sim.tick()
	var releases := events_of(sim, Events.Kind.RELEASE)
	check(releases.size() == 1 and releases[0].tick == start + windup, "the attack releases on the telegraphed tick")
	check(locked.is_equal_approx(Vector2(releases[0].x, releases[0].z)), "the release uses the locked aim")
	check(sim.party.attackers[0] == 0, "the attacker is released after the hit")
	check(sim.pool.ready_at[slot] == start + windup + sim.species.attack_recovery[kind * Species.ATTACKS], "recovery starts at release")


func test_interrupt_and_death() -> void:
	var brain := ForcedBrain.new()
	var sim := make_sim(2, brain)
	var slot := add_mob(sim, "rootbound", Vector2(10, 10))
	place_player(sim, 0, Vector2(10.8, 10))
	brain.behaviour = sim.contract.id("melee_attack")
	brain.enemy = 1
	while sim.pool.windup_until[slot] == 0 and sim.clock.tick < 120:
		sim.tick()
	sim.abilities.interrupt(slot, 30, sim.clock.tick)
	check(sim.pool.windup_until[slot] == 0 and sim.party.attackers[0] == 0, "an interrupt ends the wind-up and frees the attacker")
	run_ticks(sim, 20)
	check(events_of(sim, Events.Kind.RELEASE).is_empty() and events_of(sim, Events.Kind.INTERRUPT).size() == 1, "an interrupted attack never lands")
	while sim.pool.windup_until[slot] == 0 and sim.clock.tick < 400:
		sim.tick()
	check(sim.party.attackers[0] == 1, "the mob can attack again after recovering")
	check(sim.damage_mob(slot, HP * 2.0, 0) == HP, "damage removes only the remaining health")
	check(sim.party.attackers[0] == 0, "a dying mob frees its attacker")
	check(events_of(sim, Events.Kind.DEATH).size() == 1 and sim.pool.alive[slot] == 0, "death is recorded once")
	var reused := add_mob(sim, "rootbound", Vector2(14, 10))
	check(reused == slot and brain.reset_slots.count(slot) == 2, "a brain is told when a slot gets a new mob")


func test_attacker_cap() -> void:
	var brain := ForcedBrain.new()
	var sim := make_sim(30, brain)
	var cap := int(sim.contract.rules.max_attackers_per_player)
	for index in 30:
		add_mob(sim, "nightbloom", Vector2(10, 10) + Vector2.from_angle(index * 0.7) * (2.0 + index * 0.1))
	place_player(sim, 0, Vector2(10, 10))
	brain.behaviour = sim.contract.id("ranged_attack")
	brain.enemy = 1
	var highest := 0
	var refused := false
	for tick in 600:
		sim.tick()
		highest = maxi(highest, sim.party.attackers[0])
		refused = refused or sim.party.attackers[0] == cap and not sim.rules.can_claim_attacker(0)
	check(highest == cap, "attackers reach but never pass the cap of %d (saw %d)" % [cap, highest])
	check(refused, "a full player refuses another attacker")


func test_locomotion() -> void:
	var brain := ForcedBrain.new()
	var sim := make_sim(3, brain)
	var contract := sim.contract
	var runner := add_mob(sim, "rootbound", Vector2(-12, 10))
	place_player(sim, 0, Vector2(12, 10))
	sim.perception.seen_tick[runner * contract.players] = 0
	sim.pool.engaged[runner] = 1
	brain.behaviour = contract.id("search")
	brain.enemy = 1
	sim.pool.last_sensed[runner] = 0
	var start := Vector2(sim.pool.xz[runner * 2], sim.pool.xz[runner * 2 + 1])
	run_ticks(sim, 60)
	var moved := start.distance_to(Vector2(sim.pool.xz[runner * 2], sim.pool.xz[runner * 2 + 1]))
	check(moved > 1.0, "the executor moves a mob through locomotion")
	check(sim.pool.xz == sim.locomotion.world.positions(), "pool positions always match the movement core")

	sim.apply_status(runner, Sim.Status.ROOT, 30)
	var rooted := Vector2(sim.pool.xz[runner * 2], sim.pool.xz[runner * 2 + 1])
	run_ticks(sim, 25)
	check(rooted.is_equal_approx(Vector2(sim.pool.xz[runner * 2], sim.pool.xz[runner * 2 + 1])), "a rooted mob does not walk")
	run_ticks(sim, 10)
	sim.apply_status(runner, Sim.Status.STUN, 30)
	var stunned := Vector2(sim.pool.xz[runner * 2], sim.pool.xz[runner * 2 + 1])
	run_ticks(sim, 25)
	check(stunned.is_equal_approx(Vector2(sim.pool.xz[runner * 2], sim.pool.xz[runner * 2 + 1])), "a stunned mob does not walk")

	var dasher := add_mob(sim, "gallhorn", Vector2(0, -3))
	sim.locomotion.displace(dasher, 0.0, 3.0)
	check(sim.pool.xz[dasher * 2 + 1] < -0.5 - Species.BODY_RADIUS, "a dash stops at the wall")


func test_perception() -> void:
	var brain := ForcedBrain.new()
	var sim := make_sim(8, brain)
	var watcher := add_mob(sim, "rootbound", Vector2(0, -3))
	place_player(sim, 0, Vector2(0, 3))
	run_ticks(sim, 14)
	check(not sim.perception.knows(watcher, 0), "a mob behind a wall has not sensed the player")
	place_player(sim, 0, Vector2(9, -3))
	run_ticks(sim, 14)
	check(sim.perception.sees(watcher, 0), "a mob sees a player in range with a clear line")
	var seen := sim.pool.engaged[watcher]
	check(seen == 1, "seeing a player engages the mob")
	place_player(sim, 0, Vector2(25, 20))
	run_ticks(sim, 14)
	check(not sim.perception.sees(watcher, 0) and sim.perception.knows(watcher, 0), "a lost player is remembered")
	var at: int = watcher * sim.contract.players
	check(is_equal_approx(sim.perception.seen_x[at], 9.0) and is_equal_approx(sim.perception.seen_z[at], -3.0), "the last known position stays frozen")

	var neighbour := add_mob(sim, "rootbound", Vector2(0, -8))
	place_player(sim, 0, Vector2(0, -12))
	sim.perception.refresh_allies(PackedInt32Array([watcher]), sim.clock.tick)
	check(sim.perception.ally(watcher, 0) == neighbour, "a nearby ally takes a slot")
	var closer := add_mob(sim, "rootbound", Vector2(1, -3))
	sim.perception.refresh_allies(PackedInt32Array([watcher]), sim.clock.tick)
	check(sim.perception.ally(watcher, 0) == neighbour and sim.perception.ally(watcher, 1) == closer, "ally slots stay sticky when a closer ally arrives")
	sim.damage_mob(neighbour, HP)
	sim.perception.refresh_allies(PackedInt32Array([watcher]), sim.clock.tick)
	check(sim.perception.ally(watcher, 0) != neighbour, "a dead ally loses its slot")


func test_sleep() -> void:
	var brain := ForcedBrain.new()
	var sim := make_sim(1, brain)
	add_mob(sim, "rootbound", Vector2(-20, 20))
	place_player(sim, 0, Vector2(20, -20))
	run_ticks(sim, 60)
	check(brain.calls == 0, "a mob that has sensed nobody skips the awake brain")
	place_player(sim, 0, Vector2(-17, 20))
	run_ticks(sim, 14)
	check(brain.calls > 0, "sensing a player wakes the mob")


func test_support_buff() -> void:
	var sim := make_sim(3)
	var caster := add_mob(sim, "bellcap", Vector2(10, 10))
	var fighter := add_mob(sim, "rootbound", Vector2(11, 10))
	sim.perception.seen_tick[caster * sim.contract.players] = 0
	place_player(sim, 0, Vector2(12.5, 10))
	check(sim.abilities.begin(caster, 1, 0, sim.clock.tick), "a caster in range starts its chant")
	run_ticks(sim, sim.species.attack_windup[kind_of(sim, "bellcap") * Species.ATTACKS + 1] + 1)
	check(sim.pool.haste_until[fighter] > sim.clock.tick, "a released chant hastes nearby fighters")


func test_full_encounter() -> void:
	var first := Arena.new(2222, 100)
	var hashes := PackedInt64Array()
	for tick in 1800:
		first.before_tick()
		first.sim.tick()
		first.after_tick()
		first.audit()
		if tick % 300 == 299:
			hashes.append(first.sim.state_hash())
	check(first.clip_count == 0, "no mob clips a wall in a 100-mob encounter (saw %d)" % first.clip_count)
	check(first.attacker_mismatches == 0, "the attacker count always matches active wind-ups")
	check(first.max_attackers_seen <= int(first.sim.contract.rules.max_attackers_per_player), "the attacker cap holds in a full encounter")
	check(first.damage_dealt > 0.0, "mobs damage the party")
	check(first.mobs_killed > 0, "the party can kill mobs")
	check(first.sim.rules.rejected == 0, "the scripted brain never submits an illegal intent (saw %d)" % first.sim.rules.rejected)
	var second := Arena.new(2222, 100)
	var repeat := PackedInt64Array()
	for tick in 1800:
		second.before_tick()
		second.sim.tick()
		second.after_tick()
		if tick % 300 == 299:
			repeat.append(second.sim.state_hash())
	check(hashes == repeat, "identical encounters produce identical state hashes")


func run() -> void:
	if not NavWorld.ensure_loaded():
		print("FAIL the native extension did not load")
		quit(2)
		return
	test_contract()
	test_clock()
	test_species()
	test_pool()
	test_masks()
	test_rules()
	test_attack_timing()
	test_interrupt_and_death()
	test_attacker_cap()
	test_locomotion()
	test_perception()
	test_sleep()
	test_support_buff()
	test_full_encounter()
	print("%s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)
