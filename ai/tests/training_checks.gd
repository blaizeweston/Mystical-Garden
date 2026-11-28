extends SceneTree
## Checks training episodes (ai/training_env.gd) with the training brain and recorder: exploration and engaged
## starts, game-scale mobs, clean resets between episodes on one floor, well-formed records and shards, the
## hunting party in training (not in the frozen benchmark), starts only where the mobs' route grid connects, and
## the evaluation's time-limit snapshot.
## Uses ai/training/out/policy.bin, which ai/training/check_model.py writes (run_checks.ps1 runs it first).

const Catalog = preload("res://enemy_catalog.gd")
const Choice = preload("res://ai/choice_test.gd")
const Pace = preload("res://ai/game_pace.gd")
const Contract = preload("res://mob_sim/mob_contract.gd")
const Env = preload("res://ai/training_env.gd")
const EvalEnv = preload("res://ai/evaluation_env.gd")
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
	test_game_pace()
	test_fight_size()
	test_starts()
	test_episodes()
	test_hunt_and_snapshot()
	test_connected_spawns()
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


## Training mobs move, wind up and recover at the game's pace for their floor (combat_director.gd), and spawns
## carry it.
func test_game_pace() -> void:
	var participation := GDScript.new()
	participation.source_code = "extends RefCounted\nvar number := 1\nfunc floor() -> int:\n\treturn number\n"
	participation.reload()
	var game_script := GDScript.new()
	game_script.source_code = "extends Node\nvar participation\n"
	game_script.reload()
	var game: Node = game_script.new()
	game.participation = participation.new()
	var director = preload("res://combat_director.gd")
	var worst := 0.0
	for floor_number in range(1, 31):
		game.participation.number = floor_number
		for definition: Dictionary in Catalog.all():
			var base := float(definition.speed)
			worst = maxf(worst, absf(base * Pace.speed_scale(base, floor_number) - director.speed(game, base)))
			var windup := int(definition.windup)
			worst = maxf(worst, absf(roundi(windup * Pace.windup_scale(floor_number)) - director.windup(game, windup)) / 1000.0)
			var recovery := int(definition.recovery)
			worst = maxf(worst, absf(roundi(recovery * Pace.recovery_scale(floor_number)) - director.recovery(game, recovery)) / 1000.0)
	game.free()
	check(worst < 0.002, "training speed, wind-up and recovery match the game's director on floors 1-30 (worst %.4f)" % worst)
	var env := make_env({"explore_share": 0.0, "floors": [12, 12], "elite_share": 0.0, "mutation_chance": 0.0}, 9)
	env._new_map()
	var start: Vector2 = env.open[0]
	env.party.reset(["warden"], [start], 0.5)
	env._spawn_mobs(start, false)
	var pool = env.sim.pool
	var paced := true
	for slot in pool.active:
		var base: float = env.sim.species.speed[pool.species[slot]]
		paced = paced and is_equal_approx(pool.speed[slot], base * Pace.speed_scale(base, 12)) and is_equal_approx(pool.windup_scale[slot], Pace.windup_scale(12))
	check(paced and pool.active.size() > 0, "floor 12 training mobs spawn at the game's floor 12 speed and wind-up")
	env.close()


## Places mobs and the party as an episode would, without playing it: distances, awareness and balance.
## mob_ratio_mix picks fights by mobs per player; without it the generator is consumed exactly as before, so the
## benchmark's frozen fights (benchmark_episodes.json, no mix) stay the same fights.
func test_fight_size() -> void:
	var mixed := make_env({}, 31)
	var counts := {"under": 0, "contested": 0, "over": 0}
	var in_range := true
	for draw in 3000:
		var size := mixed._fight_size()
		var ratio := float(size.y) / size.x
		in_range = in_range and size.y >= 4 and size.y <= 16 and size.x >= 1 and size.x <= 4
		counts["under" if ratio < 2.0 else "contested" if ratio < 5.0 else "over"] += 1
	check(in_range, "mixed fights keep party sizes and mob counts in their ranges")
	check(absf(counts.under / 3000.0 - 0.15) < 0.03 and absf(counts.contested / 3000.0 - 0.6) < 0.04 and absf(counts.over / 3000.0 - 0.25) < 0.03,
		"fights follow the mobs-per-player mix (%s)" % counts)
	var frozen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ai/training/benchmark_episodes.json")).episodes
	check(not frozen.has("mob_ratio_mix"), "the benchmark's frozen fights have no mix")
	var plain := Env.new(schema, Recorder.new(schema), frozen.duplicate(true), 77)
	var reference := RandomNumberGenerator.new()
	reference.seed = plain.rng.seed
	reference.state = plain.rng.state
	var same := true
	for draw in 50:
		var size := plain._fight_size()
		same = same and size.y == -1 and size.x == reference.randi_range(int(frozen.party[0]), int(frozen.party[1]))
	check(same and plain.rng.state == reference.state, "without a mix only the party size is drawn, as before")
	check(not frozen.has("party_hunt"), "the benchmark's frozen fights keep the party that does not hunt")


func test_starts() -> void:
	var nearest_explore := INF
	var explore_short := INF
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
			# Where the start's region has no point explore_distance away, groups use its farthest tenth instead.
			var reach: Array = env.open.map(func(at: Vector2) -> float: return at.distance_to(start))
			var in_band := reach.any(func(d: float) -> bool: return d >= float(settings.explore_distance[0]) and d <= float(settings.explore_distance[1]))
			reach.sort()
			reach.reverse()
			var farthest_tenth: float = reach[maxi(1, reach.size() / 10) - 1]
			for slot in pool.active:
				var distance: float = pool.distance_to(slot, start.x, start.y)
				if explore and in_band:
					nearest_explore = minf(nearest_explore, distance)
				elif explore:
					explore_short = minf(explore_short, distance - (farthest_tenth - 3.5))
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
	report["starts"] = {"nearest_explore": snappedf(nearest_explore, 0.1), "farthest_engaged": snappedf(farthest_engaged, 0.1),
		"small_region_margin": snappedf(explore_short, 0.1) if explore_short < INF else null}
	# Explore groups centre at least explore_distance[0] away, and each mob stands within 3 m of its centre.
	var explore_floor := float(settings.explore_distance[0]) - 3.5
	check(nearest_explore >= explore_floor, "explore starts keep every mob at least %.1f m from the party (%.1f m)" % [explore_floor, nearest_explore])
	check(explore_short >= 0.0, "in a region too small for that, explore groups start among its farthest points")
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
	# The commitment is a choice only for positioning behaviours; for the rest it is fixed at the behaviour's own hold.
	var contract: Contract = schema.contract
	var commit_offset: int = contract.head_offsets[Contract.Head.COMMIT]
	var commit_options: int = contract.head_sizes[Contract.Head.COMMIT]
	var fixed_ok := true
	var free_rows := 0
	var long_holds := 0
	for row in recorder.rows:
		var behaviour: int = recorder._actions[row * heads + Contract.Head.BEHAVIOUR]
		var choice: int = recorder._actions[row * heads + Contract.Head.COMMIT]
		var open := 0
		for option in commit_options:
			open += int(recorder._masks[row * recorder.mask_size + commit_offset + option] != 0)
		if contract.commit[behaviour] == 0:
			fixed_ok = fixed_ok and open == 1 and choice == 0
		elif open == commit_options:
			free_rows += 1
			long_holds += int(choice > 0)
	check(fixed_ok and free_rows > 0 and long_holds > 0,
		"only positioning behaviours choose a commitment (%d free choices, %d chose a set length)" % [free_rows, long_holds])
	# Every head the chosen behaviour does not use is recorded with one legal option, so it adds nothing to training.
	var unused_ok := true
	var unused := 0
	for row in recorder.rows:
		var behaviour: int = recorder._actions[row * heads + Contract.Head.BEHAVIOUR]
		for head in [Contract.Head.ENEMY_TARGET, Contract.Head.ALLY_TARGET, Contract.Head.MANOEUVRE]:
			if contract.uses_head(behaviour, head):
				continue
			var open := 0
			for option in contract.head_sizes[head]:
				open += int(recorder._masks[row * recorder.mask_size + contract.head_offsets[head] + option] != 0)
			unused_ok = unused_ok and open == 1
			unused += 1
	check(unused_ok and unused > 0, "targets and manoeuvres the behaviour does not use have one recorded option (%d)" % unused)
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


## Training's party hunts and reports it; the frozen benchmark's does not. With snapshot on, an evaluation adds the
## fight's state at its time limit to each timeout's report, and leaves the report alone with it off.
func test_hunt_and_snapshot() -> void:
	check(bool(settings.get("party_hunt", false)), "training's party hunts mobs it lost sight of")
	var frozen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ai/training/benchmark_episodes.json")).episodes
	var reports := {}
	for snapshot: bool in [true, false]:
		var episodes: Dictionary = settings.duplicate(true) if snapshot else frozen.duplicate(true)
		episodes.merge({"map_episodes": 4, "engaged_seconds": 15, "explore_share": 0.0, "night_share": 1.0}, true)
		var env := EvalEnv.new(schema, Recorder.new(schema), episodes, 41)
		env.set_policy(FileAccess.get_file_as_bytes(POLICY), 1)
		env.snapshot = snapshot
		var played: Array = []
		for episode in 3:
			played.append(env.run_episode())
		check(env.party.hunt == snapshot, "the party hunts in training settings and not in the benchmark's (%s)" % ("training" if snapshot else "benchmark"))
		reports[snapshot] = played
		env.close()
	var timeouts: Array = reports[true].filter(func(r: Dictionary) -> bool: return r.outcome == "timeout")
	check(not timeouts.is_empty() and timeouts.all(func(r: Dictionary) -> bool: return r.has("at_limit")),
		"with snapshot on, %d timed-out fights report their state at the limit" % timeouts.size())
	check(reports[false].all(func(r: Dictionary) -> bool: return not r.has("at_limit")), "with snapshot off the reports are unchanged")
	if timeouts.is_empty():
		return
	var at: Dictionary = timeouts[0].at_limit
	var share := 0.0
	for name: String in at.final_behaviours:
		share += float(at.final_behaviours[name])
	report["at_limit"] = at
	check(int(at.mobs_alive) > 0 and int(at.mobs_aware) <= int(at.mobs_alive) and int(at.mobs_seeing) <= int(at.mobs_aware),
		"the snapshot counts live mobs, those aware of a player and those seeing one (%d, %d, %d)" % [at.mobs_alive, at.mobs_aware, at.mobs_seeing])
	check((at.player_health as Array).size() == int(timeouts[0].party) and (at.player_modes as Array).size() == int(timeouts[0].party),
		"the snapshot gives each player's health and party mode (%s)" % [at.player_modes])
	check(absf(share - 1.0) < 0.01 and float(at.nearest) >= 0.0, "the final behaviour shares sum to 1 (%.3f), nearest mob %.1f m" % [share, at.nearest])


## With connected_spawns (training, not the frozen benchmark) every start point lies in one region the mobs' route
## grid connects, the points left out have no route into it, and fights still play with lazy route fields.
func test_connected_spawns() -> void:
	check(bool(settings.get("connected_spawns", false)), "training starts the party and mobs only where routes connect")
	var frozen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ai/training/benchmark_episodes.json")).episodes
	check(not frozen.has("connected_spawns"), "the frozen benchmark keeps its own starts")
	var kept := 0
	var dropped := 0
	var stray := 0
	var cut_off := 0
	for seed_value in [7, 8, 9]:
		var everywhere := make_env({"connected_spawns": false, "map_episodes": 1}, seed_value)
		var connected := make_env({"connected_spawns": true, "map_episodes": 1}, seed_value)
		var plain: Dictionary = everywhere.run_episode()
		var played: Dictionary = connected.run_episode()
		check(not plain.is_empty() and not played.is_empty(), "both kinds of start play a fight (seed %d)" % seed_value)
		check(connected.floor_number == everywhere.floor_number and connected.open.all(func(at: Vector2) -> bool: return everywhere.open.has(at)),
			"the same floor keeps a subset of its open points (%d of %d, seed %d)" % [connected.open.size(), everywhere.open.size(), seed_value])
		var world: RefCounted = connected.sim.locomotion.world
		var hub: Vector2 = connected.open[connected.open.size() / 2]
		world.set_lazy_fields(0)
		world.set_targets(PackedFloat32Array([hub.x, hub.y]))
		world.tick(0.0)
		for at: Vector2 in everywhere.open:
			var routed: bool = world.path_cost(0, at.x, at.y) >= 0.0
			if connected.open.has(at):
				kept += 1
				stray += int(not routed)
			else:
				dropped += 1
				cut_off += int(not routed)
		world.set_lazy_fields(1)
		world.set_targets(connected.sim.locomotion.targets)
		everywhere.close()
		connected.close()
	report["connected_spawns"] = {"kept": kept, "dropped": dropped}
	check(stray == 0, "every kept point has a route to the others (%d kept)" % kept)
	check(cut_off == dropped, "no dropped point has a route into the kept region (%d dropped)" % dropped)


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
