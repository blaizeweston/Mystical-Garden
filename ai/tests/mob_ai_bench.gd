extends SceneTree
## Measures the neural brain inside the synthetic encounter. Host stand-in work is not timed.
## Pass "-- throughput" to measure sustained ticks per second instead.

const Arena = preload("res://mob_sim/tests/mob_sim_arena.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const NeuralBrain = preload("res://ai/mob_neural_brain.gd")
const Schema = preload("res://ai/mob_schema.gd")

const WEIGHTS := "res://ai/training/out/policy.bin"
const SEEDS := [11, 2222, 987654]
const COUNTS := [20, 50, 100]
const SCENARIOS := {"mixed": -1.0, "all_smart": 1.0}
const WARMUP_TICKS := 300
const TICKS := 1800
const THROUGHPUT_MOBS := 100
const THROUGHPUT_TICKS := 12000

var schema: Schema
var weights := PackedByteArray()


func _initialize() -> void:
	call_deferred("run")


func make_arena(seed_value: int, count: int, intelligence: float) -> Arena:
	var arena := Arena.new(seed_value, count, intelligence)
	arena.sim.brain = NeuralBrain.new(schema, weights, arena.sim.locomotion.world, arena.sim.events, count, seed_value)
	return arena


func measure(seed_value: int, count: int, intelligence: float) -> Dictionary:
	var arena := make_arena(seed_value, count, intelligence)
	var brain := arena.sim.brain as NeuralBrain
	for tick in WARMUP_TICKS:
		arena.before_tick()
		arena.sim.tick()
		arena.after_tick()
	brain.observe_usec = 0
	brain.infer_usec = 0
	brain.sample_usec = 0
	var first_decisions := brain.decisions
	var decisions := PackedInt64Array()
	var whole := PackedInt64Array()
	for tick in TICKS:
		arena.before_tick()
		var before := brain.observe_usec + brain.infer_usec
		var began := Time.get_ticks_usec()
		arena.sim.tick()
		whole.append(Time.get_ticks_usec() - began)
		decisions.append(brain.observe_usec + brain.infer_usec - before)
		arena.after_tick()
	decisions.sort()
	whole.sort()
	var total := 0
	for value in whole:
		total += value
	return {"budget_mean_ms": snappedf((brain.observe_usec + brain.infer_usec) / 1000.0 / TICKS, 0.001),
		"budget_max_ms": snappedf(decisions[TICKS - 1] / 1000.0, 0.001),
		"observe_ms": snappedf(brain.observe_usec / 1000.0 / TICKS, 0.001),
		"infer_ms": snappedf(brain.infer_usec / 1000.0 / TICKS, 0.001),
		"sample_ms": snappedf(brain.sample_usec / 1000.0 / TICKS, 0.001),
		"decisions_per_tick": snappedf(float(brain.decisions - first_decisions) / TICKS, 0.1),
		"sim_mean_ms": snappedf(total / 1000.0 / TICKS, 0.001),
		"sim_max_ms": snappedf(whole[TICKS - 1] / 1000.0, 0.001)}


func throughput() -> void:
	var arena := make_arena(2222, THROUGHPUT_MOBS, -1.0)
	var spent := 0
	for tick in THROUGHPUT_TICKS:
		arena.before_tick()
		var began := Time.get_ticks_usec()
		arena.sim.tick()
		spent += Time.get_ticks_usec() - began
		arena.after_tick()
	var rate := THROUGHPUT_TICKS / (spent / 1000000.0)
	print("THROUGHPUT_RESULT ", JSON.stringify({"ticks_per_second": roundi(rate), "times_real_time": snappedf(rate / 60.0, 0.1)}))


func run() -> void:
	if not NavWorld.ensure_loaded():
		printerr("FAIL native extension did not load")
		quit(2)
		return
	schema = Schema.new()
	weights = FileAccess.get_file_as_bytes(WEIGHTS)
	if "throughput" in OS.get_cmdline_user_args():
		throughput()
	else:
		var report := {}
		for scenario: String in SCENARIOS:
			var by_count := {}
			for count in COUNTS:
				var runs := []
				for seed_value in SEEDS:
					runs.append(measure(seed_value, count, SCENARIOS[scenario]))
				by_count[str(count)] = runs
			report[scenario] = by_count
		print("AI_BENCH_RESULT ", JSON.stringify(report))
	quit(0)
