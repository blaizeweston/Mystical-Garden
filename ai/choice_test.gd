extends SceneTree
## The choice test: does a mob's choice change what it earns, and do the policy and the critic know which
## choice pays? ai/training/choice_test.py runs this once per moment and analyses what it writes.
##
## A moment is one free decision (two or more legal behaviours) of one mob that knows where a player is, in one
## seeded training fight, set up exactly as in training.
## 1. Scout: plays the fight with the training brain and picks a moment uniformly among the fight's free, aware
##    decisions. Picking uses a generator of its own, so it changes nothing in the fight.
## 2. Branches: for every behaviour legal at the moment and every continuation, replays the fight from its seed up
##    to the moment, reseeds the brain and the party with the continuation's seed (the same for every behaviour,
##    so behaviours are compared on the same luck), forces the behaviour (targets, manoeuvre and messages are still
##    the policy's, given that behaviour) and plays on to the end of the fight. Fights are deterministic from their
##    seed; a fingerprint of the world and both generators at the moment proves each replay reached the same state.
## With --hold-seconds the mob keeps the forced behaviour at each of its decisions for that long (whenever it is legal),
## which measures how much a committed choice matters rather than a single decision.
##
## Writes --out (JSON: the moment, and per branch the mob's reward at each of its decisions from the moment on, how
## its life ended, the squad's reward after the moment and the fight's outcome) and --shards/moment.shard: the mob's
## first --rows decisions from the moment in each branch, one life per branch in branch order, for the critic.
## The shard's reward column is zero; the rewards are in the JSON. Nothing is written to a run folder.
##
## godot --headless --path <project> --script res://ai/choice_test.gd -- --policy <policy.bin> --fight-seed <n>
##   --continuations <n> --rows <n> --out <moment.json> --shards <folder> [--squad-mix <f>] [--hold-seconds <f>]

const Clock = preload("res://mob_sim/mob_clock.gd")
const Contract = preload("res://mob_sim/mob_contract.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Schema = preload("res://ai/mob_schema.gd")

const SETTINGS_PATH := "res://ai/training/training.json"
const LOCAL_SETTINGS_PATH := "res://ai/training/training.local.json"


## The training brain, which can also scout for moments or force one behaviour at one moment.
class ChoiceBrain extends "res://ai/training_brain.gd":
	var sim: RefCounted
	var party: RefCounted
	var scouting := false
	var picker := RandomNumberGenerator.new()
	var seen := 0
	var picked := {}
	var force_tick := -1
	## The forced behaviour is kept at every decision of the mob before this tick (when legal); force_tick + 1 forces
	## only the moment's own decision.
	var force_until := -1
	var later_forced := 0
	var later_missed := 0
	var force_slot := -1
	var force_option := -1
	var continuation_seed := 0
	var party_seed := 0
	var fingerprint := ""
	var forced := false
	var forced_legal := false

	## A hash of what decides the rest of a fight: mob and player positions and health, the clock, and the brain's and
	## party's generators. Equal fingerprints at the moment mean the replay reached the scouted state.
	static func fingerprint_of(sim: RefCounted, brain_rng: RandomNumberGenerator, party_rng: RandomNumberGenerator) -> String:
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(sim.pool.xz.to_byte_array())
		context.update(sim.pool.hp.to_byte_array())
		context.update(sim.party.x.to_byte_array())
		context.update(sim.party.z.to_byte_array())
		context.update(sim.party.hp.to_byte_array())
		context.update(PackedInt64Array([sim.clock.tick, brain_rng.state, party_rng.state]).to_byte_array())
		return context.finish().hex_encode().left(24)

	func decide(batch: Batch) -> void:
		if scouting:
			_scout(batch)
		elif not forced and batch.clock.tick == force_tick and batch.slots.has(force_slot):
			fingerprint = fingerprint_of(sim, rng, party.rng)
			rng.seed = continuation_seed
			party.rng.seed = party_seed
			forced = true
			recorder.keep_slot = force_slot
		super(batch)

	## Reservoir-samples one free, aware decision among all the fight's decisions so far.
	func _scout(batch: Batch) -> void:
		var behaviours: int = _head_sizes[Contract.Head.BEHAVIOUR]
		for index in batch.slots.size():
			var slot: int = batch.slots[index]
			var options := PackedInt32Array()
			for option in behaviours:
				if batch.allowed(index, Contract.Head.BEHAVIOUR, option):
					options.append(option)
			if options.size() < 2 or not _aware(slot):
				continue
			seen += 1
			if picker.randi() % seen == 0:
				picked = {"tick": batch.clock.tick, "slot": slot, "options": Array(options),
					"seconds": snappedf(Clock.to_seconds(batch.clock.tick - episode_start), 0.01),
					"fingerprint": fingerprint_of(sim, rng, party.rng)}

	func _aware(slot: int) -> bool:
		for player in sim.contract.players:
			if sim.party.present[player] != 0 and sim.party.alive[player] != 0 and sim.perception.knows(slot, player):
				return true
		return false

	func _sample_head(batch: Batch, index: int, logits: PackedFloat32Array, row: int, head: int, skip_none: bool,
			masks: PackedByteArray, actions: PackedByteArray) -> Vector2:
		var result: Vector2 = super(batch, index, logits, row, head, skip_none, masks, actions)
		if head != Contract.Head.BEHAVIOUR or not forced or batch.slots[index] != force_slot:
			return result
		var tick: int = batch.clock.tick
		if tick < force_tick or tick >= maxi(force_until, force_tick + 1):
			return result
		var mask_offset: int = schema.contract.head_offsets[head]
		var legal: bool = force_option >= 0 and force_option < _head_sizes[head] and masks[mask_offset + force_option] != 0
		if tick == force_tick:
			forced_legal = legal
		elif legal:
			later_forced += 1
		else:
			later_missed += 1
		if not legal:
			return result
		var offset := row + mask_offset
		var best := -INF
		for option in _head_sizes[head]:
			if masks[mask_offset + option] != 0:
				best = maxf(best, logits[offset + option])
		var total := 0.0
		for option in _head_sizes[head]:
			if masks[mask_offset + option] != 0:
				total += exp(logits[offset + option] - best)
		actions[head] = force_option
		return Vector2(force_option, logits[offset + force_option] - best - log(total))


## Keeps only the forced mob's decisions from the moment on: its reward at every decision, and its first max_rows
## decisions as a recorded life. Every other decision still takes its reward, as in training, so rewards that
## depend on it (the sight allowance) behave the same.
class ChoiceRecorder extends "res://ai/rollout_recorder.gd":
	var keep_slot := -1
	var max_rows := 64
	var stream := PackedFloat32Array()
	var ended := -1
	var kept := 0

	func start_branch() -> void:
		keep_slot = -1
		stream = PackedFloat32Array()
		ended = -1
		kept = 0
		discard_open()

	func record(slot: int, obs: PackedFloat32Array, global_state: PackedFloat32Array, memory: PackedFloat32Array,
			masks: PackedByteArray, actions: PackedByteArray, log_prob: float) -> void:
		var earned: float = rewards.take(slot) if rewards != null else 0.0
		if slot != keep_slot or ended >= 0:
			return
		if not stream.is_empty():
			stream[stream.size() - 1] += earned
		stream.append(0.0)
		if kept < max_rows:
			kept += 1
			var source: RefCounted = rewards
			rewards = null
			super(slot, obs, global_state, memory, masks, actions, log_prob)
			rewards = source

	func close(slot: int, end: End) -> void:
		if slot != keep_slot or ended >= 0:
			super(slot, end)
			return
		var earned: float = rewards.take(slot) if rewards != null else 0.0
		if not stream.is_empty():
			stream[stream.size() - 1] += earned
		ended = end
		var source: RefCounted = rewards
		rewards = null
		super(slot, end if kept == stream.size() else End.TRUNCATED)
		rewards = source


## Rewards that also total what every mob earns from a given tick on.
class ChoiceRewards extends "res://ai/mob_rewards.gd":
	var from_tick := 1 << 40
	var squad_after := 0.0

	func _give(slot: int, value: float, kind: String) -> void:
		if value != 0.0 and slot >= 0 and slot < pending.size() and sim.clock.tick >= from_tick:
			squad_after += value
		super(slot, value, kind)

	func _keep(slot: int, value: float, kind: String) -> void:
		if value != 0.0 and slot >= 0 and slot < pending.size() and sim.clock.tick >= from_tick:
			squad_after += value
		super(slot, value, kind)


## One training fight on a fresh floor, set up exactly as ai/training_env.gd's run_episode does.
class ChoiceEnv extends "res://ai/training_env.gd":
	## Also cuts the brain's links to the simulation and party, which refer back to it.
	func close() -> void:
		if brain is ChoiceBrain:
			brain.sim = null
			brain.party = null
		super()

	func play(setup: Callable) -> Dictionary:
		brain_script = ChoiceBrain
		if not _new_map():
			return {}
		var choice: ChoiceBrain = brain
		choice.sim = sim
		choice.party = party
		setup.call(choice)
		episodes_on_map += 1
		episodes += 1
		var explore := rng.randf() < float(settings.explore_share)
		var night := rng.randf() < float(settings.night_share)
		var light := _uniform("night_light") if night else 1.0
		var difficulty := _uniform("difficulty")
		var start: Vector2 = open[rng.randi() % open.size()]
		var classes: Array[String] = []
		var size := _fight_size()
		for index in size.x:
			classes.append(settings.classes[rng.randi() % settings.classes.size()])
		party.reset(classes, _near(start, classes.size(), 2.5), difficulty, light)
		if explore or rng.randf() < float(settings.engaged_patrol_share):
			party.plan_patrol(open, int(settings.patrol_legs))
		var tally := ChoiceRewards.new(sim)
		tally.squad_mix = squad_mix
		rewards = tally
		recorder.rewards = rewards
		brain.episode_start = sim.clock.tick
		var spawned := _spawn_mobs(start, explore, size.y)
		var limit := Clock.from_ms(float(settings.explore_seconds if explore else settings.engaged_seconds) * 1000.0)
		var cursor := sim.events.head
		var began := sim.clock.tick
		var end := Recorder.End.TERMINAL if bool(settings.get("time_limit_terminal", true)) else Recorder.End.TRUNCATED
		var outcome := "timeout"
		var damage_before := -1.0
		for step in limit:
			party.before_tick()
			sim.tick()
			party.after_tick()
			if choice.forced and damage_before < 0.0:
				tally.from_tick = sim.clock.tick
				damage_before = party.damage_taken
			rewards.tick()
			for event in sim.events.read_since(cursor):
				if int(event.kind) == Events.Kind.DEATH:
					recorder.close(int(event.slot), Recorder.End.TERMINAL)
			cursor = sim.events.head
			if party.wiped():
				end = Recorder.End.TERMINAL
				outcome = "wipe"
				break
			if sim.pool.active.is_empty():
				end = Recorder.End.TERMINAL
				outcome = "cleared"
				break
		party.before_tick()
		rewards.tick()
		recorder.close_all(end)
		return {"mode": "explore" if explore else "engaged", "mobs": spawned.count, "party": classes.size(), "night": night,
			"outcome": outcome, "seconds": snappedf(Clock.to_seconds(sim.clock.tick - began), 0.01),
			"squad_after": snappedf(tally.squad_after, 0.0001),
			"party_damage_after": snappedf(party.damage_taken - damage_before, 0.1) if damage_before >= 0.0 else 0.0}


var policy_path := ""
var out_path := ""
var shard_dir := ""
var fight_seed := 1
var continuations := 4
var hold_seconds := 0.0
var rows := 64
var squad_mix := -1.0


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	if not _parse_arguments():
		printerr("Usage: --script res://ai/choice_test.gd -- --policy <file> --fight-seed <n> --continuations <n> --rows <n> --out <file> --shards <folder>")
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
	var weights := FileAccess.get_file_as_bytes(policy_path)
	if weights.size() < 72 or weights.slice(8, 72).get_string_from_ascii() != schema.hash_hex:
		printerr("The policy %s does not fit this schema." % policy_path)
		return 2
	var recorder := ChoiceRecorder.new(schema)
	recorder.max_rows = rows
	var began := Time.get_ticks_msec()
	var scout := _play(schema, recorder, settings, weights, func(brain: ChoiceBrain) -> void:
		brain.scouting = true
		brain.picker.seed = hash([fight_seed, "moment"]))
	if scout.is_empty():
		return 1
	var moment: Dictionary = scout.brain.picked
	var result := {"fight_seed": fight_seed, "scout": scout.report, "moment": moment if not moment.is_empty() else null,
		"candidates": scout.brain.seen, "branches": [], "rows": rows, "continuations": continuations, "hold_seconds": hold_seconds}
	recorder.clear()
	if not moment.is_empty():
		for option: int in moment.options:
			for continuation in continuations:
				recorder.start_branch()
				var lives_before := recorder.lives
				var branch := _play(schema, recorder, settings, weights, func(brain: ChoiceBrain) -> void:
					brain.force_tick = int(moment.tick)
					brain.force_until = int(moment.tick) + Clock.from_ms(hold_seconds * 1000.0)
					brain.force_slot = int(moment.slot)
					brain.force_option = option
					brain.continuation_seed = hash([fight_seed, continuation, "brain"])
					brain.party_seed = hash([fight_seed, continuation, "party"]))
				if branch.is_empty():
					return 1
				var choice: ChoiceBrain = branch.brain
				result.branches.append({"option": option, "continuation": continuation, "forced": choice.forced,
					"legal": choice.forced_legal, "held": choice.later_forced, "hold_missed": choice.later_missed, "same_state": choice.fingerprint == moment.fingerprint,
					"life": lives_before if recorder.lives > lives_before else -1, "kept": recorder.kept,
					"rewards": Array(recorder.stream).map(func(value: float) -> float: return snappedf(value, 0.00001)),
					"end": recorder.ended, "report": branch.report})
		DirAccess.make_dir_recursive_absolute(shard_dir)
		if recorder.rows > 0:
			var status := recorder.write_shard(shard_dir, "moment", 0)
			if status != OK:
				printerr("Could not write the moment's shard (error %d)" % status)
				return 1
	result["seconds"] = snappedf((Time.get_ticks_msec() - began) / 1000.0, 0.1)
	var out := FileAccess.open(out_path + ".tmp", FileAccess.WRITE)
	if out == null:
		printerr("Could not write ", out_path)
		return 2
	out.store_string(JSON.stringify(result))
	out.close()
	if ChoiceRecorder.rename_retrying(out_path + ".tmp", out_path) != OK:
		printerr("Could not finish ", out_path)
		return 1
	print("Moment of fight %d: %d branches in %.1f s" % [fight_seed, result.branches.size(), result.seconds])
	return 0


## Plays the fight once on a fresh floor. Returns {brain, report}, or {} when the floor fails.
func _play(schema: Schema, recorder: ChoiceRecorder, settings: Dictionary, weights: PackedByteArray, setup: Callable) -> Dictionary:
	var env := ChoiceEnv.new(schema, recorder, settings.episodes.duplicate(true), fight_seed)
	env.set_policy(weights, 1)
	if squad_mix >= 0.0:
		env.squad_mix = squad_mix
	var report := env.play(setup)
	var brain: ChoiceBrain = env.brain
	if report.is_empty():
		printerr("The fight failed: ", env.error)
		env.close()
		return {}
	env.close()
	return {"brain": brain, "report": report}


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
			"--fight-seed":
				fight_seed = int(value)
			"--continuations":
				continuations = maxi(1, int(value))
			"--hold-seconds":
				hold_seconds = maxf(0.0, float(value))
			"--rows":
				rows = maxi(2, int(value))
			"--squad-mix":
				squad_mix = float(value)
	return not policy_path.is_empty() and not out_path.is_empty() and not shard_dir.is_empty()
