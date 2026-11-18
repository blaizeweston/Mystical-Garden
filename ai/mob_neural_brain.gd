extends "res://mob_sim/mob_brain.gd"
## Chooses mob intents with the trained policy, through the same interface as the scripted brain.
## Observations and inference run in native code. Sampling uses this brain's seeded generator.

const Contract = preload("res://mob_sim/mob_contract.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const Runtime = preload("res://ai/mob_native_runtime.gd")
const Schema = preload("res://ai/mob_schema.gd")

var schema: Schema
var runtime: Runtime
var world: RefCounted
var events: Events
var rng := RandomNumberGenerator.new()
var error := ""
var decisions := 0
var observe_usec := 0
var infer_usec := 0
var sample_usec := 0
var _logit_count := 0
var _temperature_dim := 1.0
var _temperature_smart := 1.0


## weights holds the bytes of a model exported by ai/training/mob_net.py.
func _init(model_schema: Schema, weights: PackedByteArray, nav_world: RefCounted, event_log: Events, capacity: int, seed_value: int) -> void:
	schema = model_schema
	world = nav_world
	events = event_log
	runtime = Runtime.new(schema, world)
	rng.seed = seed_value
	for size in schema.contract.head_sizes:
		_logit_count += size
	_temperature_dim = float(schema.sampling.temperature_at_zero_intelligence)
	_temperature_smart = float(schema.sampling.temperature_at_full_intelligence)
	var status: int = world.policy_load(weights, schema.hash_hex.to_ascii_buffer(), Runtime.policy_layout(schema, capacity))
	if status != OK:
		error = "The policy could not be loaded (code %d)." % status


func reset_slot(slot: int) -> void:
	world.policy_reset_slot(slot)
	runtime.reset_slot(slot)


func decide(batch: Batch) -> void:
	var began := Time.get_ticks_usec()
	var obs := runtime.build(batch, events)
	var observed := Time.get_ticks_usec()
	var slots := PackedFloat32Array()
	for slot in batch.slots:
		slots.append(slot)
	var logits: PackedFloat32Array = world.policy_step(obs, slots)
	var inferred := Time.get_ticks_usec()
	for index in batch.slots.size():
		_choose(batch, index, batch.slots[index], logits, index * _logit_count)
	decisions += batch.slots.size()
	observe_usec += observed - began
	infer_usec += inferred - observed
	sample_usec += Time.get_ticks_usec() - inferred


func _choose(batch: Batch, index: int, slot: int, logits: PackedFloat32Array, row: int) -> void:
	var contract := batch.contract
	var temperature := lerpf(_temperature_dim, _temperature_smart, batch.pool.intelligence[slot])
	var behaviour := _sample(batch, index, logits, row, Contract.Head.BEHAVIOUR, temperature, false)
	var kind := contract.target_kind[behaviour]
	var needs_enemy := kind == Contract.TargetKind.ENEMY or kind == Contract.TargetKind.ABILITY
	var enemy := _sample(batch, index, logits, row, Contract.Head.ENEMY_TARGET, temperature, needs_enemy)
	var ally := _sample(batch, index, logits, row, Contract.Head.ALLY_TARGET, temperature, kind == Contract.TargetKind.ALLY)
	var manoeuvre := _sample(batch, index, logits, row, Contract.Head.MANOEUVRE, 1.0, false)
	var message_a := _sample(batch, index, logits, row, Contract.Head.MESSAGE_A, 1.0, false)
	var message_b := _sample(batch, index, logits, row, Contract.Head.MESSAGE_B, 1.0, false)
	batch.write_intent(index, behaviour, enemy, ally, manoeuvre, message_a, message_b)


## Samples one head from its legal options. A behaviour that needs a target cannot choose "none".
func _sample(batch: Batch, index: int, logits: PackedFloat32Array, row: int, head: int, temperature: float, skip_none: bool) -> int:
	var offset := row + schema.contract.head_offsets[head]
	var size := schema.contract.head_sizes[head]
	var first := 1 if skip_none else 0
	var best := -INF
	for option in range(first, size):
		if batch.allowed(index, head, option):
			best = maxf(best, logits[offset + option])
	if best == -INF:
		return 0
	var weights := PackedFloat32Array()
	weights.resize(size)
	weights.fill(0.0)
	var total := 0.0
	for option in range(first, size):
		if batch.allowed(index, head, option):
			weights[option] = exp((logits[offset + option] - best) / temperature)
			total += weights[option]
	var roll := rng.randf() * total
	var chosen := 0
	for option in range(first, size):
		if weights[option] > 0.0:
			chosen = option
			roll -= weights[option]
			if roll <= 0.0:
				break
	return chosen
