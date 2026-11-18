extends RefCounted
## Everything a player chooses on the arena setup screen or passes to the headless runner.

enum Mode { WATCH, PLAY }
enum SessionKind { SOLO, HOST, JOIN }

const GAME_AI := ""
const SCRIPTED_BRAIN := "scripted"
const MAX_ENEMIES := 20
const MAX_PARTY := 4
const DEFAULT_PORT := 24580
const CHECKPOINT_FOLDER := "res://ai/checkpoints"
const UNTRAINED_MODEL := "res://ai/training/out/policy.bin"

var mode: Mode = Mode.WATCH
var session: SessionKind = SessionKind.SOLO
var address := "127.0.0.1"
var port := DEFAULT_PORT
var player_class := 0
## Computer-controlled party members, including the host's body in Watch mode.
var bots := 4
var brain := GAME_AI
var intelligence := 1.0
var floor_number := 6
var generated_map := true
var map_seed := 1
var round_seconds := 120
var elite := ""
var auto_restart := true
var enemies: Dictionary = {"rootbound": 4, "nightbloom": 2, "thornmaw": 2}


func total_enemies() -> int:
	var total := 0
	for count in enemies.values():
		total += int(count)
	return total


func duplicate_config() -> RefCounted:
	var copy: RefCounted = get_script().new()
	for key in ["mode", "session", "address", "port", "player_class", "bots", "brain", "intelligence", "floor_number",
			"generated_map", "map_seed", "round_seconds", "elite", "auto_restart"]:
		copy.set(key, get(key))
	copy.enemies = enemies.duplicate()
	return copy


## Lists the models the arena can load, as label and path pairs.
static func available_brains() -> Array:
	var result: Array = [["Current game AI", GAME_AI], ["Scripted baseline", SCRIPTED_BRAIN]]
	if FileAccess.file_exists(UNTRAINED_MODEL):
		result.append(["Untrained neural net", UNTRAINED_MODEL])
	var folder := DirAccess.open(CHECKPOINT_FOLDER)
	if folder != null:
		var names := folder.get_files()
		names.sort()
		for file_name in names:
			if file_name.ends_with(".bin"):
				result.append([file_name.get_basename(), CHECKPOINT_FOLDER.path_join(file_name)])
	return result


## Reads options such as --enemies=rootbound:6,wasp:4 from the command line.
func apply_arguments(arguments: PackedStringArray) -> void:
	for argument in arguments:
		if not argument.begins_with("--") or not argument.contains("="):
			continue
		var key := argument.get_slice("=", 0).trim_prefix("--")
		var value := argument.get_slice("=", 1)
		match key:
			"bots": bots = clampi(value.to_int(), 1, MAX_PARTY)
			"brain": brain = value
			"intelligence": intelligence = clampf(value.to_float(), 0.0, 1.0)
			"floor": floor_number = maxi(1, value.to_int())
			"seed": map_seed = value.to_int()
			"map": generated_map = value != "open"
			"round-seconds": round_seconds = maxi(5, value.to_int())
			"elite": elite = value
			"enemies": enemies = parse_enemies(value)


static func parse_enemies(text: String) -> Dictionary:
	var result := {}
	for entry in text.split(",", false):
		result[entry.get_slice(":", 0)] = maxi(0, entry.get_slice(":", 1).to_int())
	return result
