extends RefCounted
## A plain GDScript forward pass of the exported policy. It proves the model format and is too slow
## for a full encounter, so the shipped game will use a native runner with the same weights.

const Schema = preload("res://ai/mob_schema.gd")

const MAGIC := "MOBW"
const FORMAT_VERSION := 1
const HASH_LENGTH := 64

var schema: Schema
var error := ""
var hidden_size := 0
var logit_count := 0
var _tensors: Dictionary = {}
var _rows: Dictionary = {}
var _cols: Dictionary = {}


func _init(model_schema: Schema) -> void:
	schema = model_schema
	hidden_size = int(schema.network.recurrent_hidden)
	for size in schema.contract.head_sizes:
		logit_count += size


## Reads a weight file. A model built for a different schema is refused.
func load_weights(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		error = "The model file could not be opened."
		return false
	if file.get_buffer(MAGIC.length()).get_string_from_ascii() != MAGIC or file.get_32() != FORMAT_VERSION:
		error = "The model file has an unknown format."
		return false
	var model_hash := file.get_buffer(HASH_LENGTH).get_string_from_ascii()
	if model_hash != schema.hash_hex:
		error = "The model was built for a different schema."
		return false
	for index in file.get_32():
		var name_length := file.get_32()
		var rows := file.get_32()
		var cols := file.get_32()
		var label := file.get_buffer(name_length).get_string_from_ascii()
		_tensors[label] = file.get_buffer(rows * cols * 4).to_float32_array()
		_rows[label] = rows
		_cols[label] = cols
	return true


## Runs one row. Writes the next hidden state in place and returns every head's logits.
func forward(obs: PackedFloat32Array, base: int, hidden: PackedFloat32Array, hidden_base: int) -> PackedFloat32Array:
	var joined := PackedFloat32Array()
	var self_input := PackedFloat32Array()
	for block in schema.ordered_blocks:
		if block.encoder == "self":
			self_input.append_array(obs.slice(base + block.offset, base + block.offset + block.stride * block.repeat))
	joined.append_array(_relu(_linear("self_encoder", self_input)))
	var enemy: Schema.Block = schema.blocks.enemy
	for index in enemy.repeat:
		var start := base + enemy.offset + index * enemy.stride
		joined.append_array(_relu(_linear("enemy_encoder", obs.slice(start, start + enemy.stride))))
	var ally: Schema.Block = schema.blocks.ally
	for index in ally.repeat:
		var start := base + ally.offset + index * ally.stride
		joined.append_array(_relu(_linear("ally_encoder", obs.slice(start, start + ally.stride))))
	var leader: Schema.Block = schema.blocks.leader
	joined.append_array(_relu(_linear("leader_encoder", obs.slice(base + leader.offset, base + leader.offset + leader.stride))))
	var trunk := _relu(_linear("trunk_b", _relu(_linear("trunk_a", joined))))
	var next := _gru(trunk, hidden.slice(hidden_base, hidden_base + hidden_size))
	for index in hidden_size:
		hidden[hidden_base + index] = next[index]
	var head_input := trunk.duplicate()
	head_input.append_array(next)
	return _linear("heads", head_input)


func _linear(layer: String, input: PackedFloat32Array) -> PackedFloat32Array:
	var weight: PackedFloat32Array = _tensors[layer + ".weight"]
	var bias: PackedFloat32Array = _tensors[layer + ".bias"]
	var rows: int = _rows[layer + ".weight"]
	var cols: int = _cols[layer + ".weight"]
	var output := PackedFloat32Array()
	output.resize(rows)
	var at := 0
	for row in rows:
		var total: float = bias[row]
		for col in cols:
			total += weight[at] * input[col]
			at += 1
		output[row] = total
	return output


func _relu(values: PackedFloat32Array) -> PackedFloat32Array:
	for index in values.size():
		if values[index] < 0.0:
			values[index] = 0.0
	return values


func _dot(table: PackedFloat32Array, row: int, cols: int, input: PackedFloat32Array) -> float:
	var total := 0.0
	var at := row * cols
	for col in cols:
		total += table[at + col] * input[col]
	return total


## Matches torch.nn.GRUCell: reset gate, update gate, then the new hidden value.
func _gru(input: PackedFloat32Array, hidden: PackedFloat32Array) -> PackedFloat32Array:
	var input_weight: PackedFloat32Array = _tensors["recurrent.weight_ih"]
	var hidden_weight: PackedFloat32Array = _tensors["recurrent.weight_hh"]
	var input_bias: PackedFloat32Array = _tensors["recurrent.bias_ih"]
	var hidden_bias: PackedFloat32Array = _tensors["recurrent.bias_hh"]
	var input_cols: int = _cols["recurrent.weight_ih"]
	var output := PackedFloat32Array()
	output.resize(hidden_size)
	for index in hidden_size:
		var reset_at := index
		var update_at := hidden_size + index
		var value_at := 2 * hidden_size + index
		var reset := _sigmoid(_dot(input_weight, reset_at, input_cols, input) + input_bias[reset_at]
			+ _dot(hidden_weight, reset_at, hidden_size, hidden) + hidden_bias[reset_at])
		var update := _sigmoid(_dot(input_weight, update_at, input_cols, input) + input_bias[update_at]
			+ _dot(hidden_weight, update_at, hidden_size, hidden) + hidden_bias[update_at])
		var value := tanh(_dot(input_weight, value_at, input_cols, input) + input_bias[value_at]
			+ reset * (_dot(hidden_weight, value_at, hidden_size, hidden) + hidden_bias[value_at]))
		output[index] = (1.0 - update) * value + update * hidden[index]
	return output


func _sigmoid(value: float) -> float:
	return 1.0 / (1.0 + exp(-value))
