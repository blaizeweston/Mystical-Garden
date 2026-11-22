extends SceneTree
## Proves the native simulation code matches its GDScript references on identical state, every tick:
## - native/mob_decide.c masks and scripted brain against MobRules.build_masks_reference and
##   mob_scripted_brain_reference.gd, which must match exactly;
## - native/mob_exec.c executors against mob_executors_reference.gd, run in a dry mode that records
##   instead of acting. Modes, targets and attack starts must match exactly. Offsets may differ only in
##   the last bits, because Godot's and the native library's sine and cosine round differently.

const Abilities = preload("res://mob_sim/mob_abilities.gd")
const Arena = preload("res://mob_sim/tests/mob_sim_arena.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const Locomotion = preload("res://mob_sim/mob_locomotion.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Reference = preload("res://mob_sim/mob_executors_reference.gd")
const ReferenceBrain = preload("res://mob_sim/mob_scripted_brain_reference.gd")
const Species = preload("res://mob_sim/mob_species.gd")

const CASES := [[11, 20], [2222, 100], [987654, 60]]
const TICKS := 2400
const TOLERANCE := 0.0001
## Command fields that are discrete and must match exactly.
const EXACT_FIELDS := [Locomotion.AT_ACTIVE, Locomotion.AT_TARGET, Locomotion.AT_MODE]


## Runs MobAbilities.begin's checks without changing the simulation, and records each start.
class DryAbilities extends Abilities:
	var started := PackedInt32Array()
	var attackers := PackedInt32Array()

	func begin(slot: int, attack: int, player: int, tick: int) -> bool:
		if tick < pool.stun_until[slot] or not party.targetable(player) or not rules.attack_ready(slot, attack, tick):
			return false
		if not in_reach(slot, attack, player) or attackers[player] >= rules.max_attackers:
			return false
		var at := pool.species[slot] * Species.ATTACKS + attack
		if species.attack_sight[at] != 0 and locomotion.world.line_clear(pool.xz[slot * 2], pool.xz[slot * 2 + 1],
				party.x[player], party.z[player], 0.0) == 0:
			return false
		attackers[player] += 1
		started.append(slot)
		locomotion.hold(slot)
		return true


var failures := 0
var checks := 0


func _initialize() -> void:
	if not NavWorld.ensure_loaded():
		print("FAIL native extension did not load")
		quit(2)
		return
	var totals := {"ticks": 0, "starts": 0, "offsets": 0, "largest": 0.0, "decisions": 0}
	for entry in CASES:
		compare(int(entry[0]), int(entry[1]), totals)
	check(totals.starts > 0, "the compared encounters started %d attacks" % totals.starts)
	check(totals.decisions > 0, "the compared encounters made %d decisions" % totals.decisions)
	print("PARITY ", JSON.stringify(totals))
	print("PASSED: %d checks, %d failures" % [checks, failures] if failures == 0 else "FAILED: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


func compare(seed_value: int, mobs: int, totals: Dictionary) -> void:
	var arena := Arena.new(seed_value, mobs)
	var sim = arena.sim
	var shadow := Locomotion.new(sim.pool, sim.party, sim.contract)
	shadow.world = sim.locomotion.world
	var dry := DryAbilities.new(sim.pool, sim.party, sim.species, sim.rules, sim.events, shadow)
	var reference := Reference.new(sim.contract, sim.pool, sim.party, sim.species, sim.perception, dry, shadow)
	var reference_brain := ReferenceBrain.new()
	var problem := ""
	for tick in TICKS:
		arena.before_tick()
		sim.clock.advance()
		var now: int = sim.clock.tick
		sim.perception.update(now)
		problem = _decide_both(sim, reference_brain, now, totals)
		if not problem.is_empty():
			problem = "tick %d: %s" % [tick, problem]
			break
		shadow.commands = sim.locomotion.commands.duplicate()
		shadow.targets = sim.locomotion.targets.duplicate()
		shadow._tick = sim.locomotion.last_step_tick()
		dry.attackers = sim.party.attackers.duplicate()
		dry.started.clear()
		reference.run(now)
		var cursor: int = sim.events.head
		sim.executors.run(now)
		var native_started := PackedInt32Array()
		for event in sim.events.read_since(cursor):
			if event.kind == Events.Kind.WINDUP:
				native_started.append(int(event.slot))
		problem = _difference(sim.locomotion.commands, shadow.commands, sim.locomotion.targets, shadow.targets, totals)
		if problem.is_empty() and native_started != dry.started:
			problem = "attack starts: native %s, reference %s" % [native_started, dry.started]
		if not problem.is_empty():
			problem = "tick %d: %s" % [tick, problem]
			break
		totals.starts += native_started.size()
		totals.ticks += 1
		sim.abilities.tick_windups(now)
		sim.locomotion.step(now)
		arena.after_tick()
	check(problem.is_empty(), "seed %d, %d mobs: native and reference executors agree for %d ticks%s" % [seed_value, mobs, TICKS,
		"" if problem.is_empty() else " (%s)" % problem])


## Mirrors MobSim._decide, comparing native and reference masks and intents before committing.
func _decide_both(sim, reference_brain, now: int, totals: Dictionary) -> String:
	var awake := PackedInt32Array()
	var asleep := PackedInt32Array()
	for slot in sim.pool.active:
		if now < sim.pool.next_decision[slot]:
			continue
		sim.pool.next_decision[slot] = now + sim.pool.decision_interval[slot]
		if now - sim.pool.last_sensed[slot] >= sim.sleep_ticks:
			asleep.append(slot)
		else:
			awake.append(slot)
	sim.perception.refresh_allies(awake, now)
	for pair in [[sim._awake_batch, awake, sim.brain], [sim._asleep_batch, asleep, sim.idle_brain]]:
		var batch = pair[0]
		if pair[1].is_empty():
			continue
		batch.prepare(pair[1])
		sim.rules.build_masks_reference(batch, now)
		var expected_masks: PackedByteArray = batch.masks.duplicate()
		sim.rules.build_masks(batch, now)
		if batch.masks != expected_masks:
			return "masks differ for slots %s" % [batch.slots]
		batch.intents.fill(0)
		reference_brain.decide(batch)
		var expected_intents: PackedByteArray = batch.intents.duplicate()
		pair[2].decide(batch)
		if batch.intents != expected_intents:
			return "scripted intents differ for slots %s: native %s, reference %s" % [batch.slots, batch.intents, expected_intents]
		sim.rules.commit(batch, now)
		totals.decisions += batch.slots.size()
	return ""


func _difference(native: PackedFloat32Array, reference: PackedFloat32Array, native_targets: PackedFloat32Array,
		reference_targets: PackedFloat32Array, totals: Dictionary) -> String:
	if native.size() != reference.size() or native_targets.size() != reference_targets.size():
		return "array sizes differ"
	for index in native.size():
		var gap := absf(native[index] - reference[index])
		if gap == 0.0:
			continue
		var field := index % Locomotion.STRIDE
		if EXACT_FIELDS.has(field) or gap > TOLERANCE:
			return "slot %d field %d: native %s, reference %s" % [index / Locomotion.STRIDE, field, native[index], reference[index]]
		totals.offsets += 1
		totals.largest = maxf(totals.largest, gap)
	for index in native_targets.size():
		if absf(native_targets[index] - reference_targets[index]) > TOLERANCE:
			return "goal target %d: native %s, reference %s" % [index, native_targets[index], reference_targets[index]]
	return ""
