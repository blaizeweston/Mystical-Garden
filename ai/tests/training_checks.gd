extends SceneTree
## Checks training episodes (ai/training_env.gd) with the training brain and recorder: exploration and engaged
## starts, game-scale mobs, clean resets between episodes on one floor, and well-formed records and shards.
## Uses ai/training/out/policy.bin, which ai/training/check_model.py writes (run_checks.ps1 runs it first).

const Choice = preload("res://ai/choice_test.gd")
const Env = preload("res://ai/training_env.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Recorder = preload("res://ai/rollout_recorder.gd")
const Schema = preload("res://ai/mob_schema.gd")

const POLICY := "res://ai/training/out/policy.bin"

var failures := 0
var checks := 0
var report := {}
var schema: Schema
var settings: Dictionary


func _initialize() -> void:
	if not NavWorld.ensure_loaded():
		print("FAIL native extension did not load")
		quit(2)
		return
	schema = Schema.new()
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://ai/training/training.json")).episodes
	test_starts()
	test_episodes()
	test_choice_replay()
	print("TRAINING_REPORT ", JSON.stringify(report))
	print("PASSED: %d checks, %d failures" % [checks, failures] if failures == 0 else "FAILED: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


func make_env(overrides: Dictionary, seed_value: int) -> Env:
	var episodes: Dictionary = settings.duplicate(true)
	episodes.merge(overrides, true)
	var env := Env.new(schema, Recorder.new(schema), episodes, seed_value)
	env.set_policy(FileAccess.get_file_as_bytes(POLICY), 1)
	return env


## Places mobs and the party as an episode would, without playing it: distances, awareness and balance.
func test_starts() -> void:
	var nearest_explore := INF
	var farthest_engaged := 0.0
	var sensed_at_start := 0
	var hp_ok := true
	var damage_ok := true
	for seed_value in [3, 4, 5, 6]:
		for explore: bool in [true, false]:
			var env := make_env({"explore_share": 1.0 if explore else 0.0, "night_share": 0.0, "elite_share": 0.0, "floors": [1, 1]}, seed_value)
			env._new_map()
			var start: Vector2 = env.open[seed_value * 31 % env.open.size()]
			env.party.reset(["warden"], [start], 0.5)
			var placed: Dictionary = env._spawn_mobs(start, explore)
			var pool = env.sim.pool
			for slot in pool.active:
				var distance: float = pool.distance_to(slot, start.x, start.y)
				if explore:
					nearest_explore = minf(nearest_explore, distance)
				else:
					farthest_engaged = maxf(farthest_engaged, distance)
				hp_ok = hp_ok and pool.max_hp[slot] >= 20.0 and pool.max_hp[slot] <= 90.0
				damage_ok = damage_ok and pool.damage[slot] >= 6.0 and pool.damage[slot] <= 20.0
			env.sim.tick()
			if explore:
				for slot in pool.active:
					sensed_at_start += int(env.sim.perception.sees(slot, 0))
			check(int(placed.count) >= 3, "%s start %d places its mobs" % ["an explore" if explore else "an engaged", seed_value])
			env.close()
	report["starts"] = {"nearest_explore": snappedf(nearest_explore, 0.1), "farthest_engaged": snappedf(farthest_engaged, 0.1)}
	check(nearest_explore >= 20.0, "explore starts keep every mob at least 20 m from the party (%.1f m)" % nearest_explore)
	check(farthest_engaged <= 17.0, "engaged starts keep mobs within reach of the party (%.1f m)" % farthest_engaged)
	check(sensed_at_start == 0, "no mob sees the party when an explore episode begins")
	check(hp_ok and damage_ok, "floor 1 mobs have the game's health (20-90) and hits (6-20)")


## Plays episodes of each kind on one floor and checks the records, the resets and the shard.
func test_episodes() -> void:
	var env := make_env({"map_episodes": 4, "night_share": 0.5, "engaged_seconds": 30, "explore_seconds": 45}, 11)
	var reports: Array = []
	var leftovers := 0
	var maps := []
	for episode in 6:
		env.settings.explore_share = 1.0 if episode % 2 == 0 else 0.0
		reports.append(env.run_episode())
		maps.append(env.sim.get_instance_id())
		leftovers += int(env.recorder.has_life(0)) + int(env.sim.fields.count() > 64)
	var recorder := env.recorder
	check(reports.all(func(r: Dictionary) -> bool: return not r.is_empty()), "six episodes play to the end")
	check(maps[0] == maps[3] and maps[3] != maps[4], "a floor is reused for map_episodes episodes, then replaced")
	check(leftovers == 0, "every life is closed when its episode ends")
	var explore := reports.filter(func(r: Dictionary) -> bool: return r.mode == "explore")
	var found := explore.filter(func(r: Dictionary) -> bool: return float(r.first_sight) >= 0.0)
	report["episodes"] = reports.map(func(r: Dictionary) -> Dictionary: return {"mode": r.mode, "outcome": r.outcome, "seconds": r.seconds,
		"first_sight": r.first_sight, "mobs": r.mobs, "killed": r.mobs_killed, "downs": r.downs, "night": r.night})
	check(explore.size() == 3 and explore.all(func(r: Dictionary) -> bool: return float(r.first_sight) != 0.0),
		"explore episodes begin with no mob seeing the party")
	# Lives are contiguous, end once, and every choice was legal under the recorded masks.
	var life: PackedInt32Array = recorder._life
	var ends: PackedByteArray = recorder._end
	var ordered := true
	var ended_once := true
	for row in recorder.rows:
		if row > 0 and life[row] < life[row - 1]:
			ordered = false
		var last := row == recorder.rows - 1 or life[row + 1] != life[row]
		ended_once = ended_once and (ends[row] != Recorder.End.CONTINUES) == last
	check(recorder.rows > 500 and ordered and ended_once, "%d decisions in %d lives, each life whole and ended once" % [recorder.rows, recorder.lives])
	var legal := true
	var probable := true
	var heads := recorder.heads
	for row in recorder.rows:
		var offset := 0
		for head in heads:
			var choice: int = recorder._actions[row * heads + head]
			legal = legal and recorder._masks[row * recorder.mask_size + offset + choice] != 0
			offset += schema.contract.head_sizes[head]
		probable = probable and recorder._log_prob[row] <= 0.0001
	check(legal and probable, "every recorded choice was legal and has a log-probability at most 0")
	var terminal := 0
	for row in recorder.rows:
		terminal += int(ends[row] == Recorder.End.TERMINAL)
	check(terminal > 0, "deaths and finished fights end lives as terminal (%d)" % terminal)
	var truncated := 0
	for row in recorder.rows:
		truncated += int(ends[row] == Recorder.End.TRUNCATED)
	check(bool(env.settings.get("time_limit_terminal", true)) and truncated == 0,
		"the time limit ends lives as terminal too, so no life is bootstrapped from the critic")
	var data := recorder.to_bytes(3)
	var body := data.slice(0, data.size() - 32)
	check(data.slice(0, 4).get_string_from_ascii() == "MOBR" and Recorder.sha256(body) == data.slice(data.size() - 32),
		"a shard starts with its tag and ends with the SHA-256 of the rest")
	env.close()


## The choice test (ai/choice_test.gd) replays a seeded fight to the same state, forces one behaviour there, and
## with the same continuation seed plays the rest the same way again.
func test_choice_replay() -> void:
	var weights := FileAccess.get_file_as_bytes(POLICY)
	var recorder := Choice.ChoiceRecorder.new(schema)
	recorder.max_rows = 8
	var play := func(setup: Callable) -> Choice.ChoiceBrain:
		var env := Choice.ChoiceEnv.new(schema, recorder, settings.duplicate(true), 21)
		env.set_policy(weights, 1)
		var report: Dictionary = env.play(setup)
		var brain: Choice.ChoiceBrain = env.brain
		env.close()
		return brain if not report.is_empty() else null
	var scout: Choice.ChoiceBrain = play.call(func(brain: Choice.ChoiceBrain) -> void:
		brain.scouting = true
		brain.picker.seed = 5)
	check(scout != null and not scout.picked.is_empty() and scout.picked.options.size() >= 2, "the choice test finds a free decision of an aware mob")
	if scout == null or scout.picked.is_empty():
		return
	var moment: Dictionary = scout.picked
	recorder.clear()
	var streams := []
	var same := true
	var legal := true
	for option: int in [moment.options[0], moment.options[1], moment.options[1]]:
		recorder.start_branch()
		var brain: Choice.ChoiceBrain = play.call(func(choice: Choice.ChoiceBrain) -> void:
			choice.force_tick = int(moment.tick)
			choice.force_slot = int(moment.slot)
			choice.force_option = option
			choice.continuation_seed = 77
			choice.party_seed = 78)
		same = same and brain != null and brain.forced and brain.fingerprint == moment.fingerprint
		legal = legal and brain != null and brain.forced_legal
		streams.append(recorder.stream.duplicate())
	check(same, "every replay reaches the scouted state at the moment")
	check(legal and recorder.lives == 3 and recorder.rows <= 24, "each branch forces a legal behaviour and keeps at most its first rows")
	check(streams[1] == streams[2] and not streams[1].is_empty(), "the same behaviour and continuation seed replay the same rewards")
	recorder.start_branch()
	var held: Choice.ChoiceBrain = play.call(func(choice: Choice.ChoiceBrain) -> void:
		choice.force_tick = int(moment.tick)
		choice.force_until = int(moment.tick) + 240
		choice.force_slot = int(moment.slot)
		choice.force_option = moment.options[1]
		choice.continuation_seed = 77
		choice.party_seed = 78)
	check(held != null and held.forced_legal and held.later_forced + held.later_missed > 0,
		"a held choice is forced again at the mob's later decisions (%d held, %d not legal)" % [held.later_forced if held else 0, held.later_missed if held else 0])
