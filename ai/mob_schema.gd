extends RefCounted
## Reads ai/schema.json and the mob contract into offsets. Observation layouts come only from here.

const Contract = preload("res://mob_sim/mob_contract.gd")

const PATH := "res://ai/schema.json"
const CONTRACT_PATH := "res://mob_sim/mob_contract.json"

enum ScaleKind { NONE, DIVIDE, LOG1P, VISION }

const SCALE_NAMES := {"none": ScaleKind.NONE, "divide": ScaleKind.DIVIDE, "log1p": ScaleKind.LOG1P, "vision": ScaleKind.VISION}


class Block:
	var name := ""
	var encoder := ""
	var repeat := 1
	var offset := 0
	var stride := 0
	## Field name to its offset inside one repeat.
	var fields: Dictionary = {}
	var sizes: Dictionary = {}
	var masked: Dictionary = {}

	func at(field: String) -> int:
		return int(fields.get(field, -1))


var contract: Contract
var version := 0
var clip := 0.0
var hash_hex := ""
var observation_size := 0
var global_size := 0
var blocks: Dictionary = {}
var global_blocks: Dictionary = {}
var ordered_blocks: Array[Block] = []
var ordered_global: Array[Block] = []
var archetypes := PackedStringArray()
var network: Dictionary = {}
var sampling: Dictionary = {}
var scale_kind := PackedByteArray()
var scale_inverse := PackedFloat32Array()
var global_kind := PackedByteArray()
var global_inverse := PackedFloat32Array()
var errors := PackedStringArray()
var _scales: Dictionary = {}


func _init(path: String = PATH) -> void:
	contract = Contract.new()
	errors.append_array(contract.errors)
	var bytes := FileAccess.get_file_as_bytes(path)
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		errors.append("The observation schema could not be read.")
		return
	var data: Dictionary = parsed
	version = int(data.version)
	clip = float(data.clip)
	network = data.network
	sampling = data.sampling
	archetypes = PackedStringArray(data.archetypes)
	_scales = data.scales
	hash_hex = _hash(bytes, FileAccess.get_file_as_bytes(CONTRACT_PATH))
	observation_size = _compile(data.observation, data.masked_reasons, blocks, ordered_blocks, scale_kind, scale_inverse)
	global_size = _compile(data.global_state, data.masked_reasons, global_blocks, ordered_global, global_kind, global_inverse)
	_validate()


## Both languages hash the file bytes with Windows line endings turned into Unix ones, so a model matches its
## schema on any computer, whatever line endings its checkout uses.
static func _hash(schema: PackedByteArray, contract_bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(_unix_lines(schema))
	context.update(_unix_lines(contract_bytes))
	return context.finish().hex_encode()


static func _unix_lines(data: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(data.size())
	var size := 0
	for index in data.size():
		if data[index] == 13 and index + 1 < data.size() and data[index + 1] == 10:
			continue
		out[size] = data[index]
		size += 1
	out.resize(size)
	return out


func _compile(entries: Array, reasons: Dictionary, table: Dictionary, ordered: Array[Block], kinds: PackedByteArray, inverses: PackedFloat32Array) -> int:
	var cursor := 0
	for entry: Dictionary in entries:
		var block := Block.new()
		block.name = str(entry.name)
		block.encoder = str(entry.get("encoder", ""))
		block.repeat = int(entry.get("repeat", 1))
		block.offset = cursor
		var repeat_kinds := PackedByteArray()
		var repeat_inverses := PackedFloat32Array()
		for field: Dictionary in entry.fields:
			_add_field(block, field, reasons, repeat_kinds, repeat_inverses)
		for index in block.repeat:
			kinds.append_array(repeat_kinds)
			inverses.append_array(repeat_inverses)
		cursor += block.stride * block.repeat
		table[block.name] = block
		ordered.append(block)
	return cursor


func _add_field(block: Block, field: Dictionary, reasons: Dictionary, kinds: PackedByteArray, inverses: PackedFloat32Array) -> void:
	var label := str(field.name)
	var size := int(field.get("size", 1))
	if block.fields.has(label):
		errors.append("Duplicate field %s.%s" % [block.name, label])
	var scale_name := str(field.scale)
	if not _scales.has(scale_name):
		errors.append("Unknown scale on %s.%s" % [block.name, label])
		return
	var scale: Dictionary = _scales[scale_name]
	if field.has("masked") and not reasons.has(str(field.masked)):
		errors.append("Unknown mask reason on %s.%s" % [block.name, label])
	block.fields[label] = block.stride
	block.sizes[label] = size
	block.masked[label] = field.has("masked")
	for index in size:
		kinds.append(int(SCALE_NAMES[str(scale.kind)]))
		inverses.append(1.0 / float(scale.max) if scale.has("max") else 1.0)
	block.stride += size


func _validate() -> void:
	if blocks.is_empty():
		return
	var intent: Block = blocks.self_intent
	if int(intent.sizes.behaviour) != contract.behaviour_count:
		errors.append("The intent block does not match the behaviour count.")
	if int(intent.sizes.target) != contract.players + contract.allies + 2:
		errors.append("The target block does not match the player and ally slots.")
	if int(blocks.enemy.repeat) != contract.players or int(blocks.ally.repeat) != contract.allies:
		errors.append("Enemy or ally slots do not match the contract.")
	if int(blocks.ally.sizes.enemy_target) != contract.players + 1:
		errors.append("The ally target block does not match the player slots.")
	if int(blocks.ally.sizes.message) != 2 * contract.message_symbols:
		errors.append("The ally message block does not match the message symbols.")
	if int(blocks.context_party.sizes.class_count) != contract.party_classes.size():
		errors.append("The party class counts do not match the contract's party classes.")
	if archetypes.size() > int(blocks.self_archetype.sizes.archetype):
		errors.append("There are more archetypes than archetype slots.")


## Applies a field's fixed scale. Vision-relative values are divided by the mob's range first.
func scaled(kind: int, inverse: float, value: float) -> float:
	match kind:
		ScaleKind.DIVIDE:
			value *= inverse
		ScaleKind.LOG1P:
			value = log(1.0 + maxf(value, 0.0)) * inverse
	return clampf(value, -clip, clip)


## Stable text form of the layout, compared against the Python parser.
func layout_rows() -> Array:
	var rows: Array = []
	for block in ordered_blocks:
		for index in block.repeat:
			for label: String in block.fields:
				rows.append(["%s[%d].%s" % [block.name, index, label], block.offset + index * block.stride + block.at(label), int(block.sizes[label])])
	for block in ordered_global:
		for index in block.repeat:
			for label: String in block.fields:
				rows.append(["global.%s[%d].%s" % [block.name, index, label], block.offset + index * block.stride + block.at(label), int(block.sizes[label])])
	return rows
