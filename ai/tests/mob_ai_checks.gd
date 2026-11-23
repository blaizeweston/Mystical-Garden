extends SceneTree
## Proves the neural brain against the Python model and runs it in a synthetic encounter.

const Arena = preload("res://mob_sim/tests/mob_sim_arena.gd")
const Battlefield = preload("res://battlefield.gd")
const Builder = preload("res://ai/mob_observation_builder.gd")
const DecisionBatch = preload("res://mob_sim/mob_decision_batch.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const NeuralBrain = preload("res://ai/mob_neural_brain.gd")
const Policy = preload("res://ai/mob_policy_reference.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Runtime = preload("res://ai/mob_native_runtime.gd")
const Schema = preload("res://ai/mob_schema.gd")
const Sim = preload("res://mob_sim/mob_sim.gd")

const WEIGHTS := "res://ai/training/out/policy.bin"
const PARITY := "res://ai/training/out/parity.bin"
const LAYOUT := "res://ai/training/out/godot_layout.json"
const PARITY_LIMIT := 0.0001
const OBSERVATION_LIMIT := 0.00001
const ARENA_MOBS := 100
const ARENA_TICKS := 10000
const REPEAT_MOBS := 40
const REPEAT_TICKS := 1800
const LOCKSTEP_MOBS := 40
const LOCKSTEP_TICKS := 3600
const AUDIT_EVERY := 30
const MP_ERR_SCHEMA := 4


## Runs the GDScript and native builders on every decision and compares every value.
class LockstepBrain extends "res://mob_sim/mob_scripted_brain.gd":
	var builder: RefCounted
	var runtime: RefCounted
	var event_log: RefCounted
	var rows := 0
	var worst := 0.0
	var worst_index := -1
	var mismatched_sizes := 0
	var global_size := 0

	func reset_slot(slot: int) -> void:
		if builder != null:
			builder.reset_slot(slot)
			runtime.reset_slot(slot)

	func decide(batch: Batch) -> void:
		var script_rows: PackedFloat32Array = builder.build(batch, event_log)
		var native_rows: PackedFloat32Array = runtime.build(batch, event_log)
		if script_rows.size() != native_rows.size():
			mismatched_sizes += 1
		else:
			for index in script_rows.size():
				var difference := absf(script_rows[index] - native_rows[index])
				if difference > worst:
					worst = difference
					worst_index = index
			rows += batch.slots.size()
		global_size = builder.build_global(batch).size()
		super(batch)


var failures := 0
var checks := 0
var report := {}
var weights := PackedByteArray()


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	print("PASS " if condition else "FAIL ", label)
	failures += int(not condition)


func test_schema(schema: Schema) -> void:
	check(schema.errors.is_empty(), "the schema loads without errors " + str(schema.errors))
	check(schema.observation_size == 744, "the observation has 744 values")
	check(schema.global_size == 52, "the critic state has 52 values")
	var encoder_sizes := {}
	for block in schema.ordered_blocks:
		encoder_sizes[block.encoder] = int(encoder_sizes.get(block.encoder, 0)) + block.stride * block.repeat
	check(encoder_sizes == {"self": 157, "enemy": 136, "ally": 384, "leader": 67}, "each encoder receives the agreed size")
	var builder := Builder.new(schema)
	check(builder.errors.is_empty(), "every live field has a source and no masked field does " + str(builder.errors))
	var file := FileAccess.open(LAYOUT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"hash": schema.hash_hex, "observation_size": schema.observation_size,
		"global_size": schema.global_size, "rows": schema.layout_rows()}))
	file.close()


func test_parity(schema: Schema, policy: Policy) -> void:
	var file := FileAccess.open(PARITY, FileAccess.READ)
	var rows := file.get_32()
	var obs_size := file.get_32()
	var hidden_size := file.get_32()
	var logit_size := file.get_32()
	check(obs_size == schema.observation_size and logit_size == policy.logit_count, "the parity file matches the schema")
	var obs := file.get_buffer(rows * obs_size * 4).to_float32_array()
	var hidden := file.get_buffer(rows * hidden_size * 4).to_float32_array()
	var logits := file.get_buffer(rows * logit_size * 4).to_float32_array()
	var next_hidden := file.get_buffer(rows * hidden_size * 4).to_float32_array()

	var world: RefCounted = NavWorld.create(1, 1)
	check(world.policy_load(weights, schema.hash_hex.to_ascii_buffer(), Runtime.policy_layout(schema, rows)) == OK, "the native runner loads the model")
	var began := Time.get_ticks_usec()
	var native: PackedFloat32Array = world.policy_forward(obs, hidden)
	report["native_forward_us_per_mob"] = snappedf(float(Time.get_ticks_usec() - began) / rows, 0.01)
	check(native.size() == rows * (logit_size + hidden_size), "the native runner returns every row")
	var worst_native := 0.0
	for index in rows * logit_size:
		worst_native = maxf(worst_native, absf(native[index] - logits[index]))
	for index in rows * hidden_size:
		worst_native = maxf(worst_native, absf(native[rows * logit_size + index] - next_hidden[index]))
	report["native_parity_max_difference"] = worst_native
	check(worst_native < PARITY_LIMIT, "the native runner matches PyTorch on %d rows (largest difference %.7f)" % [rows, worst_native])

	var worst := 0.0
	began = Time.get_ticks_usec()
	for row in rows:
		var output := policy.forward(obs, row * obs_size, hidden, row * hidden_size)
		for index in logit_size:
			worst = maxf(worst, absf(output[index] - logits[row * logit_size + index]))
		for index in hidden_size:
			worst = maxf(worst, absf(hidden[row * hidden_size + index] - next_hidden[row * hidden_size + index]))
	report["reference_forward_ms"] = snappedf((Time.get_ticks_usec() - began) / 1000.0 / rows, 0.01)
	check(worst < PARITY_LIMIT, "the GDScript reference matches PyTorch on %d rows (largest difference %.7f)" % [rows, worst])


func test_refuses_wrong_model(schema: Schema) -> void:
	var bytes := weights.duplicate()
	bytes[8] = 48 if bytes[8] != 48 else 49
	var path := "res://ai/training/out/wrong_schema.bin"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var wrong := Policy.new(schema)
	check(not wrong.load_weights(path) and wrong.error.contains("different schema"), "the reference refuses a model built for another schema")
	var world: RefCounted = NavWorld.create(1, 1)
	var status: int = world.policy_load(bytes, schema.hash_hex.to_ascii_buffer(), Runtime.policy_layout(schema, 1))
	check(status == MP_ERR_SCHEMA, "the native runner refuses a model built for another schema")


func neural_arena(schema: Schema, count: int, seed_value: int) -> Arena:
	var arena := Arena.new(2222, count)
	arena.sim.brain = NeuralBrain.new(schema, weights, arena.sim.locomotion.world, arena.sim.events, count, seed_value)
	check((arena.sim.brain as NeuralBrain).error.is_empty(), "the neural brain loads its model")
	return arena


## With dark set, the encounter is at night with lit players, and the players publish combat stats and
## changing dodge and wind-up timers, so light levels and player stats are compared too.
func test_native_observations(schema: Schema, dark := false) -> void:
	var arena := Arena.new(2222 if not dark else 3333, LOCKSTEP_MOBS)
	var brain := LockstepBrain.new()
	brain.builder = Builder.new(schema)
	brain.runtime = Runtime.new(schema, arena.sim.locomotion.world)
	brain.event_log = arena.sim.events
	arena.sim.brain = brain
	var party = arena.sim.party
	if dark:
		arena.sim.set_darkness(true, 0.1)
		for player in party.count:
			party.set_stats(player, PackedFloat32Array([10.0 + player, 6.0, 2.0 + player * 0.5, 8.0, 4.5, 1.1, 0.1 * player]))
			party.set_class(player, player % 6)
	for tick in LOCKSTEP_TICKS:
		arena.before_tick()
		if dark:
			var lights := PackedFloat32Array()
			for player in party.count:
				lights.append_array(PackedFloat32Array([party.x[player], party.z[player], 5.5, 1.0]))
				var now: int = arena.sim.clock.tick
				party.set_timers(player, now + (tick * 7 + player * 13) % 90, now + (tick + player) % 40 - 20, now + (tick * 3 + player) % 30 - 15)
				party.set_effects(player, 0.25 * ((tick + player) % 6), (tick + player * 3) % 5, float((tick * 3 + player) % 40))
			arena.sim.perception.lights = lights
		arena.sim.tick()
		arena.after_tick()
	var label := " at night with player stats" if dark else ""
	report["observation_rows_compared" + ("_dark" if dark else "")] = brain.rows
	report["observation_max_difference" + ("_dark" if dark else "")] = brain.worst
	check(brain.rows > 1000, "the native and GDScript builders compared %d observation rows%s" % [brain.rows, label])
	check(brain.mismatched_sizes == 0, "both builders return the same number of values" + label)
	check(brain.worst < OBSERVATION_LIMIT, "native observations match GDScript%s (largest difference %.8f at value %d)" % [label, brain.worst, brain.worst_index % maxi(1, schema.observation_size)])
	check(brain.global_size == schema.global_size, "the critic state builds alongside the observations" + label)


func test_arena(schema: Schema) -> void:
	var arena := neural_arena(schema, ARENA_MOBS, 7)
	var brain := arena.sim.brain as NeuralBrain
	var behaviours := {}
	var cursor := 0
	var masked := _masked_indices(schema)
	var masked_nonzero := 0
	var out_of_range := 0
	var began := Time.get_ticks_usec()
	for tick in ARENA_TICKS:
		arena.before_tick()
		arena.sim.tick()
		arena.after_tick()
		for event in arena.sim.events.read_since(cursor):
			if event.kind == Events.Kind.INTENT:
				behaviours[event.a] = true
		cursor = arena.sim.events.head
		if tick % AUDIT_EVERY == 0:
			arena.audit()
			var batch: DecisionBatch = arena.sim._awake_batch
			if not batch.slots.is_empty():
				var obs: PackedFloat32Array = brain.runtime.build(batch, arena.sim.events)
				for value in obs:
					out_of_range += int(absf(value) > schema.clip or is_nan(value))
				for row in batch.slots.size():
					for index in masked:
						masked_nonzero += int(obs[row * schema.observation_size + index] != 0.0)
	report["arena_seconds"] = snappedf((Time.get_ticks_usec() - began) / 1000000.0, 0.1)
	report["arena_decisions"] = brain.decisions
	report["arena_behaviours_used"] = behaviours.size()
	check(arena.sim.clock.tick == ARENA_TICKS, "the neural brain runs %d ticks with %d mobs" % [ARENA_TICKS, ARENA_MOBS])
	check(brain.decisions > 10000, "the neural brain made %d decisions" % brain.decisions)
	check(arena.sim.rules.rejected == 0, "the neural brain never submits an illegal intent (saw %d)" % arena.sim.rules.rejected)
	check(masked_nonzero == 0, "fields for missing mechanics stay at zero")
	check(out_of_range == 0, "every observation value is finite and inside the clip range")
	check(arena.clip_count == 0, "no mob clips a wall (saw %d)" % arena.clip_count)
	check(arena.attacker_mismatches == 0, "the attacker cap accounting stays correct")
	check(arena.max_attackers_seen <= int(arena.sim.contract.rules.max_attackers_per_player), "the attacker cap holds")
	check(behaviours.size() >= 5, "the untrained policy explores several behaviours (saw %d)" % behaviours.size())
	check(not behaviours.has(schema.contract.id("hide")), "hide is never chosen until darkness exists")


func _masked_indices(schema: Schema) -> PackedInt32Array:
	var result := PackedInt32Array()
	for block in schema.ordered_blocks:
		for repeat in block.repeat:
			for label: String in block.fields:
				if block.masked[label]:
					for index in int(block.sizes[label]):
						result.append(block.offset + repeat * block.stride + block.at(label) + index)
	return result


func test_repeatable(schema: Schema) -> void:
	var hashes: Array[int] = []
	for attempt in 2:
		var arena := neural_arena(schema, REPEAT_MOBS, 11)
		for tick in REPEAT_TICKS:
			arena.before_tick()
			arena.sim.tick()
			arena.after_tick()
		hashes.append(hash([arena.sim.state_hash(), arena.sim.locomotion.world.policy_memory_hash()]))
	check(hashes[0] == hashes[1], "identical seeds repeat the same decisions and memory")

	var arena := neural_arena(schema, 2, 3)
	var world: RefCounted = arena.sim.locomotion.world
	var empty: int = world.policy_memory_hash()
	var row := PackedFloat32Array()
	row.resize(schema.observation_size)
	row.fill(0.5)
	world.policy_step(row, PackedFloat32Array([0.0]))
	check(world.policy_memory_hash() != empty, "a decision updates the mob's memory")
	var request := Pool.Spawn.new()
	request.species = arena.spawnable[0]
	request.at = arena.open_cells[0]
	request.hp = 10.0
	arena.sim.damage_mob(0, 1000.0)
	check(arena.sim.spawn(request) == 0 and world.policy_memory_hash() == empty, "a new mob starts with empty memory")


func field_value(schema: Schema, obs: PackedFloat32Array, block_name: String, repeat: int, label: String, offset := 0) -> float:
	var block: Schema.Block = schema.blocks[block_name]
	return obs[block.offset + repeat * block.stride + block.at(label) + offset]


func one_hot_total(schema: Schema, obs: PackedFloat32Array, block_name: String, label: String) -> float:
	var total := 0.0
	for index in int(schema.blocks[block_name].sizes[label]):
		total += field_value(schema, obs, block_name, 0, label, index)
	return total


func observe(sim: Sim, runtime: Runtime, slot: int) -> PackedFloat32Array:
	var batch: DecisionBatch = sim._awake_batch
	batch.prepare(PackedInt32Array([slot]))
	sim.perception.refresh_allies(batch.slots, sim.clock.tick)
	return runtime.build(batch, sim.events)


func add_mob(sim: Sim, label: String, at: Vector2, flags := 0, leader := -1) -> int:
	var request := Pool.Spawn.new()
	request.species = sim.species.ids.find(label)
	request.at = at
	request.hp = 50.0
	request.damage = 10.0
	request.flags = flags
	request.leader = leader
	return sim.spawn(request)


func test_observation_values(schema: Schema) -> void:
	var field = Battlefield.new()
	field.configure(0, 1)
	preload("res://tests/support/terrain_case.gd").walls(field,[Rect2(-6.0, -0.5, 12.0, 1.0)])
	var sim := Sim.new(3)
	sim.configure(field)
	var runtime := Runtime.new(schema, sim.locomotion.world)
	var chief := add_mob(sim, "rootbound", Vector2(12, 10), Pool.FLAG_LEADER)
	var mob := add_mob(sim, "rootbound", Vector2(10, 10), 0, chief)
	var mate := add_mob(sim, "nightbloom", Vector2(10, 12))
	sim.party.set_player(2, Vector2(13, 10), Vector2(1.0, 0.0), 80.0, 100.0)
	for tick in 14:
		sim.tick()
	sim.damage_mob(mob, 10.0, 2)
	var obs := observe(sim, runtime, mob)
	var near := func(actual: float, expected: float) -> bool: return absf(actual - expected) < 0.0005
	var vision: float = sim.species.vision[sim.pool.species[mob]]
	var row: int = mob * schema.contract.players + 2
	var dx: float = sim.perception.seen_x[row] - sim.pool.xz[mob * 2]
	check(near.call(field_value(schema, obs, "self_dynamic", 0, "hp_fraction"), 0.8), "self health reads as a fraction")
	check(near.call(field_value(schema, obs, "self_dynamic", 0, "hp_change_1s"), -0.2), "recent damage reads as lost health")
	check(near.call(field_value(schema, obs, "self_capabilities", 0, "max_hp"), log(51.0) / 8.0), "max health uses its fixed log scale")
	check(field_value(schema, obs, "enemy", 2, "present") == 1.0 and field_value(schema, obs, "enemy", 2, "visible") == 1.0, "player 3 appears in enemy slot 3")
	check(field_value(schema, obs, "enemy", 0, "present") == 0.0, "an absent player's slot stays empty")
	check(near.call(field_value(schema, obs, "enemy", 2, "dx"), dx / vision), "enemy positions are relative to vision range")
	check(near.call(field_value(schema, obs, "enemy", 2, "hp_fraction"), 0.8), "a visible player's health is read")
	check(near.call(field_value(schema, obs, "enemy", 2, "damage_they_dealt_me"), log(11.0) / 5.0), "damage is credited to the player who dealt it")
	check(one_hot_total(schema, obs, "self_intent", "behaviour") == 1.0, "the current behaviour is one option")
	check(field_value(schema, obs, "self_intent", 0, "behaviour", sim.pool.behaviour[mob]) == 1.0, "the behaviour flag matches the mob")
	check(one_hot_total(schema, obs, "self_intent", "target") == 1.0, "the current target is one option")
	check(field_value(schema, obs, "self_archetype", 0, "archetype", schema.archetypes.find("swipe")) == 1.0, "the archetype matches the species role")
	check(field_value(schema, obs, "ally", 0, "present") == 1.0, "a nearby ally fills a slot")
	check(near.call(field_value(schema, obs, "ally", 0, "dy"), (sim.pool.xz[mate * 2 + 1] - sim.pool.xz[mob * 2 + 1]) / vision), "ally positions are relative")
	check(field_value(schema, obs, "ally", 0, "role_ranged") == 1.0, "ally roles are reported")
	check(field_value(schema, obs, "ally", 1, "present") == 0.0, "the leader does not take an ally slot")
	check(field_value(schema, obs, "leader", 0, "present") == 1.0 and field_value(schema, obs, "leader", 0, "is_elite") == 1.0, "the leader has its own block")

	sim.party.set_player(2, Vector2(25, 20), Vector2.ZERO, 40.0, 100.0)
	for tick in 14:
		sim.tick()
	obs = observe(sim, runtime, mob)
	check(field_value(schema, obs, "enemy", 2, "visible") == 0.0 and field_value(schema, obs, "enemy", 2, "present") == 1.0, "a lost player stays present but unseen")
	check(near.call(field_value(schema, obs, "enemy", 2, "hp_fraction"), 0.8), "a lost player's health freezes at its last seen value")
	sim.damage_mob(mate, 50.0)
	obs = observe(sim, runtime, mob)
	check(field_value(schema, obs, "ally", 0, "present") == 0.0, "a dead ally leaves its slot empty")


func run() -> void:
	if not NavWorld.ensure_loaded():
		print("FAIL the native extension did not load")
		quit(2)
		return
	var schema := Schema.new()
	test_schema(schema)
	weights = FileAccess.get_file_as_bytes(WEIGHTS)
	var policy := Policy.new(schema)
	check(policy.load_weights(WEIGHTS), "the exported model loads " + policy.error)
	test_parity(schema, policy)
	test_refuses_wrong_model(schema)
	test_observation_values(schema)
	test_native_observations(schema)
	test_native_observations(schema, true)
	test_repeatable(schema)
	test_arena(schema)
	print("AI_REPORT ", JSON.stringify(report))
	print("%s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)
