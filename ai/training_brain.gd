extends "res://ai/mob_neural_brain.gd"
## The neural brain as used in training: it samples every head at temperature 1 and records each decision
## for the trainer through a recorder (ai/rollout_recorder.gd): the observation, the critic's view, the
## recurrent memory the decision started from, the legal options as sampled, the choices and their
## log-probability. The trainer recomputes the same probabilities from the same masks.

const Builder = preload("res://ai/mob_observation_builder.gd")
const Clock = preload("res://mob_sim/mob_clock.gd")

var recorder: RefCounted
## The tick the current training episode began. The critic sees time since then, as in a fresh encounter.
var episode_start := 0
var _global_builder: Builder
var _episode_time := -1
var _head_sizes := PackedInt32Array()
var _mask_size := 0


func _init(model_schema: Schema, weights: PackedByteArray, nav_world: RefCounted, event_log: Events, capacity: int, seed_value: int) -> void:
	super(model_schema, weights, nav_world, event_log, capacity, seed_value)
	_global_builder = Builder.new(model_schema)
	_head_sizes = model_schema.contract.head_sizes
	_mask_size = model_schema.contract.mask_size
	_episode_time = _global_builder._totals.offset + _global_builder._at("totals.episode_time")


## Swaps in new weights between decisions. Returns false when they do not fit this schema.
func reload(weights: PackedByteArray, capacity: int) -> bool:
	return world.policy_load(weights, schema.hash_hex.to_ascii_buffer(), Runtime.policy_layout(schema, capacity)) == OK


func decide(batch: Batch) -> void:
	var obs := runtime.build(batch, events)
	var slots := PackedFloat32Array()
	for slot in batch.slots:
		slots.append(slot)
	var hidden: PackedFloat32Array = world.policy_hidden(slots)
	var logits: PackedFloat32Array = world.policy_step(obs, slots)
	var global_row := _global_builder.build_global(batch)
	global_row[_episode_time] = schema.scaled(schema.global_kind[_episode_time], schema.global_inverse[_episode_time],
		Clock.to_seconds(batch.clock.tick - episode_start))
	var size := schema.observation_size
	var memory := int(schema.network.recurrent_hidden)
	for index in batch.slots.size():
		var masks := PackedByteArray()
		masks.resize(_mask_size)
		masks.fill(0)
		var actions := PackedByteArray()
		actions.resize(Contract.HEAD_COUNT)
		var log_prob := _choose_recorded(batch, index, logits, index * _logit_count, masks, actions)
		if recorder != null:
			recorder.record(batch.slots[index], obs.slice(index * size, (index + 1) * size), global_row,
				hidden.slice(index * memory, (index + 1) * memory), masks, actions, log_prob)
	decisions += batch.slots.size()


## Samples each head from its legal options at temperature 1, writing the options it allowed into masks and
## the choices into actions. A behaviour that needs a target cannot choose "none". Returns the summed
## log-probability of the choices.
func _choose_recorded(batch: Batch, index: int, logits: PackedFloat32Array, row: int, masks: PackedByteArray, actions: PackedByteArray) -> float:
	var contract := batch.contract
	var total := 0.0
	var behaviour := _sample_head(batch, index, logits, row, Contract.Head.BEHAVIOUR, false, masks, actions)
	total += behaviour.y
	var kind := contract.target_kind[int(behaviour.x)]
	var needs_enemy := kind == Contract.TargetKind.ENEMY or kind == Contract.TargetKind.ABILITY
	var enemy := _sample_head(batch, index, logits, row, Contract.Head.ENEMY_TARGET, needs_enemy, masks, actions)
	var ally := _sample_head(batch, index, logits, row, Contract.Head.ALLY_TARGET, kind == Contract.TargetKind.ALLY, masks, actions)
	var manoeuvre := _sample_head(batch, index, logits, row, Contract.Head.MANOEUVRE, false, masks, actions)
	var message_a := _sample_head(batch, index, logits, row, Contract.Head.MESSAGE_A, false, masks, actions)
	var message_b := _sample_head(batch, index, logits, row, Contract.Head.MESSAGE_B, false, masks, actions)
	total += enemy.y + ally.y + manoeuvre.y + message_a.y + message_b.y
	batch.write_intent(index, int(behaviour.x), int(enemy.x), int(ally.x), int(manoeuvre.x), int(message_a.x), int(message_b.x))
	return total


## Returns (choice, log-probability). With no legal option the head chooses 0 with certainty.
func _sample_head(batch: Batch, index: int, logits: PackedFloat32Array, row: int, head: int, skip_none: bool,
		masks: PackedByteArray, actions: PackedByteArray) -> Vector2:
	var offset := row + schema.contract.head_offsets[head]
	var mask_offset := schema.contract.head_offsets[head]
	var size := _head_sizes[head]
	var first := 1 if skip_none else 0
	var best := -INF
	for option in range(first, size):
		if batch.allowed(index, head, option):
			masks[mask_offset + option] = 1
			best = maxf(best, logits[offset + option])
	if best == -INF:
		masks[mask_offset] = 1
		actions[head] = 0
		return Vector2(0, 0.0)
	var total := 0.0
	for option in range(first, size):
		if masks[mask_offset + option] != 0:
			total += exp(logits[offset + option] - best)
	var roll := rng.randf() * total
	var chosen := first
	for option in range(first, size):
		if masks[mask_offset + option] != 0:
			chosen = option
			roll -= exp(logits[offset + option] - best)
			if roll <= 0.0:
				break
	actions[head] = chosen
	return Vector2(chosen, logits[offset + chosen] - best - log(total))
