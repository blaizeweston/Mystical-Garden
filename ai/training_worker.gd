extends SceneTree
## A training worker: plays episodes (ai/training_env.gd) with the trainer's latest policy and writes them as
## rollout shards. Started and stopped by ai/training/start_training.ps1 and stop_training.ps1.
##
## godot --headless --path <project> --script res://ai/training_worker.gd -- --run-dir <folder> --worker <n>
##   [--episodes <n>]   stop after n episodes (for tests)
##
## Files in the run folder:
## - STOP: when present, the worker finishes its episode, writes what it has and exits.
## - policy/manifest.json: the trainer's current policy (version, file, sha256, squad_mix, episode overrides).
##   A new version is loaded between episodes once its file matches the checksum.
## - shards/*.shard: written atomically (see ai/rollout_recorder.gd). The worker waits while too many are
##   waiting for the trainer, so a stopped trainer never fills the disk.
## - workers/wNN.json: this worker's progress, for the status script.

const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Recorder = preload("res://ai/rollout_recorder.gd")
const Schema = preload("res://ai/mob_schema.gd")
const Env = preload("res://ai/training_env.gd")

const SETTINGS_PATH := "res://ai/training/training.json"
const WAIT_MS := 1000

var run_dir := ""
var worker := 0
var max_episodes := 0
var settings: Dictionary = {}
var base_episodes: Dictionary = {}
var recorder: Recorder
var env: Env
var policy_version := 0
var shards_written := 0
var started_unix := 0
var shard_started_usec := 0
var shard_ticks := 0


func _initialize() -> void:
	var code := _run()
	if env != null:
		env.close()
	env = null
	recorder = null
	quit(code)


func _run() -> int:
	if not _parse_arguments():
		printerr("Usage: --script res://ai/training_worker.gd -- --run-dir <folder> --worker <n> [--episodes <n>]")
		return 2
	if not NavWorld.ensure_loaded():
		printerr("The native extension did not load.")
		return 2
	var schema := Schema.new()
	if not schema.errors.is_empty():
		printerr("The schema has errors: ", schema.errors)
		return 2
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if not parsed is Dictionary:
		printerr("Could not read ", SETTINGS_PATH)
		return 2
	settings = parsed
	base_episodes = settings.episodes
	for folder in ["shards", "workers"]:
		DirAccess.make_dir_recursive_absolute(run_dir.path_join(folder))
	_remove_own_temporaries()
	started_unix = int(Time.get_unix_time_from_system())
	recorder = Recorder.new(schema)
	env = Env.new(schema, recorder, base_episodes.duplicate(true), hash([worker, started_unix, Time.get_ticks_usec()]))
	print("Worker %d started in %s" % [worker, run_dir])
	while policy_version == 0:
		if _stopping():
			return 0
		_poll_policy()
		if policy_version == 0:
			OS.delay_msec(WAIT_MS)
	var played := 0
	shard_started_usec = Time.get_ticks_usec()
	while not _stopping():
		_poll_policy()
		if _backlog() >= int(settings.shards.backlog):
			OS.delay_msec(WAIT_MS)
			continue
		var ticks_before := env.ticks
		var report := env.run_episode()
		if report.is_empty():
			printerr("Episode failed: ", env.error)
			return 1
		shard_ticks += env.ticks - ticks_before
		played += 1
		if recorder.rows >= int(settings.shards.rows):
			if not _write_shard():
				return 1
		if max_episodes > 0 and played >= max_episodes:
			break
	if recorder.rows > 0 and not _write_shard():
		return 1
	print("Worker %d stopped after %d episodes" % [worker, played])
	return 0


func _parse_arguments() -> bool:
	var args := OS.get_cmdline_user_args()
	for index in args.size() - 1:
		match args[index]:
			"--run-dir":
				run_dir = args[index + 1]
			"--worker":
				worker = int(args[index + 1])
			"--episodes":
				max_episodes = int(args[index + 1])
	return not run_dir.is_empty()


func _stopping() -> bool:
	return FileAccess.file_exists(run_dir.path_join("STOP"))


## Loads a newer policy named by the manifest when its file matches the checksum. Rows recorded with the old
## policy are written first, so every shard holds one policy version.
func _poll_policy() -> void:
	var path := run_dir.path_join("policy/manifest.json")
	var text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	if text.is_empty():
		return
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary or int(parsed.get("version", 0)) <= policy_version:
		return
	var manifest: Dictionary = parsed
	var bytes := FileAccess.get_file_as_bytes(run_dir.path_join("policy").path_join(str(manifest.get("file", ""))))
	if bytes.is_empty() or Recorder.sha256(bytes).hex_encode() != str(manifest.get("sha256", "")):
		return
	if recorder.rows > 0 and not _write_shard():
		return
	if not env.set_policy(bytes, int(manifest.version)):
		printerr("Policy %d does not fit this schema." % int(manifest.version))
		return
	policy_version = int(manifest.version)
	env.squad_mix = float(manifest.get("squad_mix", env.squad_mix))
	var episodes: Dictionary = base_episodes.duplicate(true)
	episodes.merge(manifest.get("episodes", {}), true)
	env.settings = episodes


func _write_shard() -> bool:
	var rows := recorder.rows
	var count := recorder.episodes.size()
	var name := "w%02d_%d_%05d" % [worker, started_unix, shards_written]
	var status := recorder.write_shard(run_dir.path_join("shards"), name, worker)
	if status != OK:
		printerr("Could not write shard %s (error %d)" % [name, status])
		return false
	shards_written += 1
	var seconds := maxf(0.001, (Time.get_ticks_usec() - shard_started_usec) / 1000000.0)
	var progress := {"worker": worker, "policy": policy_version, "shards": shards_written, "episodes": env.episodes,
		"rows_per_second": snappedf(rows / seconds, 0.1), "speed": snappedf(shard_ticks / 60.0 / seconds, 0.1),
		"time": Time.get_datetime_string_from_system()}
	print("Shard %s: %d rows from %d episodes, %.0f rows/s, %.0fx real time, policy %d" % [name, rows, count, progress.rows_per_second,
		progress.speed, policy_version])
	_write_progress(progress)
	shard_started_usec = Time.get_ticks_usec()
	shard_ticks = 0
	return true


func _write_progress(progress: Dictionary) -> void:
	var path := run_dir.path_join("workers/w%02d.json" % worker)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(progress))
	file.close()
	DirAccess.rename_absolute(path + ".tmp", path)


func _backlog() -> int:
	var count := 0
	for name in DirAccess.get_files_at(run_dir.path_join("shards")):
		count += int(name.ends_with(".shard"))
	return count


## Removes this worker's shards left half written by a crash or power loss.
func _remove_own_temporaries() -> void:
	var prefix := "w%02d_" % worker
	for name in DirAccess.get_files_at(run_dir.path_join("shards")):
		if name.begins_with(prefix) and name.ends_with(".tmp"):
			DirAccess.remove_absolute(run_dir.path_join("shards").path_join(name))
