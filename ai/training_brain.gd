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
## The learnability probe (ai/training/learnability_probe.py): a decision that sends probe_symbol on message
## channel A earns probe_reward, kept whole. Messages change nothing in the fight by themselves, so how fast
## training learns to send it measures the learning pipeline alone. Off (-1) in normal training.
var probe_symbol := -1
var probe_reward := 0.0


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
			if probe_symbol >= 0 and actions[Contract.Head.MESSAGE_A] == probe_symbol and recorder.rewards != null:
				recorder.rewards._keep(batch.slots[index], probe_reward, "probe")
	decisions += batch.slots.size()


## Samples each head from its legal options at temperature 1, writing the options it allowed into masks and
## the choices into actions. A behaviour that needs a target cannot choose "none". A head the chosen behaviour
## does not use (Contract.uses_head) is fixed to one option, so it adds nothing to training. Returns the summed
## log-probability of the choices.
func _choose_recorded(batch: Batch, index: int, logits: PackedFloat32Array, row: int, masks: PackedByteArray, actions: PackedByteArray) -> float:
	var contract := batch.contract
	var behaviour := _sample_head(batch, index, logits, row, Contract.Head.BEHAVIOUR, false, masks, actions)
	var chosen := int(behaviour.x)
	var kind := contract.target_kind[chosen]
	var needs_enemy := kind == Contract.TargetKind.ENEMY or kind == Contract.TargetKind.ABILITY
	var picks := PackedInt32Array([chosen, 0, 0, 0, 0, 0, 0])
	var total := behaviour.y
	for head in range(Contract.Head.ENEMY_TARGET, Contract.HEAD_COUNT):
		var choice := Vector2(_fixed_head(batch, index, head, masks, actions), 0.0)
		if contract.uses_head(chosen, head):
			var skip_none := (head == Contract.Head.ENEMY_TARGET and needs_enemy) or (head == Contract.Head.ALLY_TARGET and kind == Contract.TargetKind.ALLY)
			_clear_head(head, masks)
			choice = _sample_head(batch, index, logits, row, head, skip_none, masks, actions)
		picks[head] = int(choice.x)
		total += choice.y
	batch.write_intent(index, picks[0], picks[1], picks[2], picks[3], picks[4], picks[5], picks[6])
	return total


## Fixes a head the behaviour does not use to its first legal option (option 0 unless the mob is locked) and
## records only that option. Returns it.
func _fixed_head(batch: Batch, index: int, head: int, masks: PackedByteArray, actions: PackedByteArray) -> int:
	var option := 0
	for candidate in _head_sizes[head]:
		if batch.allowed(index, head, candidate):
			option = candidate
			break
	_clear_head(head, masks)
	masks[schema.contract.head_offsets[head] + option] = 1
	actions[head] = option
	return option


func _clear_head(head: int, masks: PackedByteArray) -> void:
	var offset := schema.contract.head_offsets[head]
	for option in _head_sizes[head]:
		masks[offset + option] = 0


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
	var temperature := _temperature_for(batch, index, head)
	var total := 0.0
	for option in range(first, size):
		if masks[mask_offset + option] != 0:
			total += exp((logits[offset + option] - best) / temperature)
	var roll := rng.randf() * total
	var chosen := first
	for option in range(first, size):
		if masks[mask_offset + option] != 0:
			chosen = option
			roll -= exp((logits[offset + option] - best) / temperature)
			if roll <= 0.0:
				break
	actions[head] = chosen
	return Vector2(chosen, (logits[offset + chosen] - best) / temperature - log(total))


## The temperature a head is sampled at: 1 in training, so the trainer's probabilities match exactly.
## ai/game_temperature_brain.gd samples as the game does instead, for evaluation.
func _temperature_for(_batch: Batch, _index: int, _head: int) -> float:
	return 1.0
