extends RefCounted
## Typed view of mob_contract.json. Behaviour ids, head sizes and slot counts come only from here.

const PATH := "res://mob_sim/mob_contract.json"

enum TargetKind { NONE, ENEMY, ALLY, ABILITY }
enum Delivery { ANY, MELEE, RANGED }
enum Head { BEHAVIOUR, ENEMY_TARGET, ALLY_TARGET, MANOEUVRE, MESSAGE_A, MESSAGE_B }

const HEAD_COUNT := 6
const TARGET_NAMES := {"none": TargetKind.NONE, "enemy": TargetKind.ENEMY, "ally": TargetKind.ALLY, "ability": TargetKind.ABILITY}
const DELIVERY_NAMES := {"any": Delivery.ANY, "melee": Delivery.MELEE, "ranged": Delivery.RANGED}

var version := 0
var tick_rate := 0
var players := 0
var allies := 0
var attacks := 0
var message_symbols := 0
## The game's player classes, in the order the party profile counts them. A host publishes each player's class as
## its position here plus one (MobParty.Stat.CLASS); 0 means unknown.
var party_classes := PackedStringArray()
var behaviour_count := 0
var manoeuvre_count := 0
var names := PackedStringArray()
var manoeuvres := PackedStringArray()
var hold_ms := PackedInt32Array()
var available := PackedByteArray()
var target_kind := PackedByteArray()
var attack_slot := PackedInt32Array()
var delivery := PackedByteArray()
var leader_only := PackedByteArray()
var head_sizes := PackedInt32Array()
var head_offsets := PackedInt32Array()
var mask_size := 0
var rules: Dictionary = {}
var perception: Dictionary = {}
var errors := PackedStringArray()
var _ids: Dictionary = {}


func _init(path: String = PATH) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("The mob contract could not be read.")
		return
	var data: Dictionary = parsed
	version = int(data.version)
	tick_rate = int(data.tick_rate)
	players = int(data.slots.players)
	allies = int(data.slots.allies)
	attacks = int(data.slots.attacks)
	message_symbols = int(data.slots.message_symbols)
	party_classes = PackedStringArray(data.get("party_classes", []))
	rules = data.rules
	perception = data.perception
	manoeuvres = PackedStringArray(data.manoeuvres)
	manoeuvre_count = manoeuvres.size()
	for entry: Dictionary in data.behaviours:
		_add_behaviour(entry)
	behaviour_count = names.size()
	head_sizes = PackedInt32Array([behaviour_count, players + 1, allies + 2, manoeuvre_count, message_symbols, message_symbols])
	for size in head_sizes:
		head_offsets.append(mask_size)
		mask_size += size


func _add_behaviour(entry: Dictionary) -> void:
	var label := str(entry.name)
	if _ids.has(label):
		errors.append("Duplicate behaviour " + label)
	if not TARGET_NAMES.has(str(entry.target)):
		errors.append("Unknown target kind on " + label)
		return
	_ids[label] = names.size()
	names.append(label)
	hold_ms.append(int(entry.hold_ms))
	available.append(int(entry.get("available", true)))
	target_kind.append(int(TARGET_NAMES[str(entry.target)]))
	attack_slot.append(int(entry.get("attack", -1)))
	delivery.append(int(DELIVERY_NAMES[str(entry.get("delivery", "any"))]))
	leader_only.append(int(entry.get("leader_only", false)))


func id(label: String) -> int:
	return int(_ids.get(label, -1))
