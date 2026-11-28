extends SceneTree
## Plays seeded training episodes with one brain and writes one JSON line per episode, for comparing brains on
## identical fights. ai/training/evaluate.py runs it once per brain and seed block and reads the results.
##
## godot --headless --path <project> --script res://ai/evaluate_policies.gd -- --policy <policy.bin>
##   --seed <n> --episodes <n> --out <results.jsonl> [--scripted] [--game-temperature] [--squad-mix <f>]
##   [--shards <folder> --record <n>] [--episodes-file <settings.json>] [--snapshot]
##
## --policy      the trained policy (ai/training/mob_net.py export). With --scripted the game's scripted brain
##               decides instead, and the policy only satisfies the episode setup.
## --seed        the same seed gives the same floors, parties and mob groups in the same order for every brain.
## --game-temperature  samples as the game does (ai/game_temperature_brain.gd: sharper for brighter mobs)
##               instead of at temperature 1 as in training.
## --snapshot    adds at_limit, the fight's state at its time limit, to each timeout's line
##               (ai/evaluation_env.gd _limit_snapshot). Without it the lines are unchanged.
## --record      keeps every decision of the first n episodes and writes them as a rollout shard into
##               --shards, for the critic diagnosis. Never a training run folder.
## Episode settings come from ai/training/training.json (and training.local.json), as in training, unless
## --episodes-file names a file whose "episodes" replace them whole (the benchmark's frozen fight mix,
## ai/training/benchmark_episodes.json).

const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Recorder = preload("res://ai/rollout_recorder.gd")
const Schema = preload("res://ai/mob_schema.gd")
const EvalEnv = preload("res://ai/evaluation_env.gd")
const GameTemperatureBrain = preload("res://ai/game_temperature_brain.gd")

const SETTINGS_PATH := "res://ai/training/training.json"
const LOCAL_SETTINGS_PATH := "res://ai/training/training.local.json"

var policy_path := ""
var out_path := ""
var shard_dir := ""
var seed_value := 1
var episode_count := 0
var record := 0
var scripted := false
var game_temperature := false
var squad_mix := -1.0
var episodes_file := ""
var snapshot := false


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	if not _parse_arguments():
		printerr("Usage: --script res://ai/evaluate_policies.gd -- --policy <file> --seed <n> --episodes <n> --out <file> [--scripted]")
		return 2
	if not NavWorld.ensure_loaded():
		printerr("The native extension did not load.")
		return 2
	var schema := Schema.new()
	if not schema.errors.is_empty():
		printerr("The schema has errors: ", schema.errors)
		return 2
	var settings := _settings()
	if settings.is_empty():
		printerr("Could not read ", SETTINGS_PATH)
		return 2
	if not episodes_file.is_empty():
		var frozen: Variant = JSON.parse_string(FileAccess.get_file_as_string(episodes_file))
		if not frozen is Dictionary or not frozen.get("episodes") is Dictionary:
			printerr("Could not read the episode settings in ", episodes_file)
			return 2
		settings.episodes = frozen.episodes
	var weights := FileAccess.get_file_as_bytes(policy_path)
	if weights.size() < 72 or weights.slice(8, 72).get_string_from_ascii() != schema.hash_hex:
		printerr("The policy %s does not fit this schema." % policy_path)
		return 2
	var recorder := Recorder.new(schema)
	var env := EvalEnv.new(schema, recorder, settings.episodes.duplicate(true), seed_value)
	env.use_scripted = scripted
	env.snapshot = snapshot
	if game_temperature:
		env.brain_script = GameTemperatureBrain
	env.set_policy(weights, 1)
	if squad_mix >= 0.0:
		env.squad_mix = squad_mix
	var out := FileAccess.open(out_path + ".tmp", FileAccess.WRITE)
	if out == null:
		printerr("Could not write ", out_path)
		return 2
	var code := 0
	for index in episode_count:
		env.keep_rows = index < record
		var report := env.run_episode()
		if report.is_empty():
			printerr("Episode failed: ", env.error)
			code = 1
			break
		report["seed"] = seed_value
		report["index"] = index
		out.store_line(JSON.stringify(report))
		if index + 1 == record and not shard_dir.is_empty():
			code = _write_rows(recorder)
			if code != 0:
				break
	out.close()
	env.close()
	if code != 0:
		DirAccess.remove_absolute(out_path + ".tmp")
		return code
	if Recorder.rename_retrying(out_path + ".tmp", out_path) != OK:
		printerr("Could not finish ", out_path)
		return 1
	print("Evaluated %d episodes (%s, seed %d)" % [episode_count, "scripted" if scripted else "policy", seed_value])
	return 0


func _write_rows(recorder: Recorder) -> int:
	DirAccess.make_dir_recursive_absolute(shard_dir)
	if recorder.rows == 0:
		return 0
	var status := recorder.write_shard(shard_dir, "eval_%d" % seed_value, 0)
	if status != OK:
		printerr("Could not write the decision shard (error %d)" % status)
		return 1
	return 0


func _settings() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if not parsed is Dictionary:
		return {}
	var settings: Dictionary = parsed
	if FileAccess.file_exists(LOCAL_SETTINGS_PATH):
		var local: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOCAL_SETTINGS_PATH))
		if local is Dictionary:
			for key: String in local:
				if local[key] is Dictionary and settings.get(key) is Dictionary:
					settings[key].merge(local[key], true)
				else:
					settings[key] = local[key]
	return settings


func _parse_arguments() -> bool:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		var value: String = args[index + 1] if index + 1 < args.size() else ""
		match args[index]:
			"--policy":
				policy_path = value
			"--out":
				out_path = value
			"--shards":
				shard_dir = value
			"--seed":
				seed_value = int(value)
			"--episodes":
				episode_count = int(value)
			"--record":
				record = int(value)
			"--squad-mix":
				squad_mix = float(value)
			"--scripted":
				scripted = true
			"--game-temperature":
				game_temperature = true
			"--episodes-file":
				episodes_file = value
			"--snapshot":
				snapshot = true
	return not policy_path.is_empty() and not out_path.is_empty() and episode_count > 0
