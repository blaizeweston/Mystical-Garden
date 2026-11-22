extends SceneTree
## Measures the mob simulation in a synthetic encounter. Host stand-in work is not timed.
## No argument: per-system breakdown for several seeds and mob counts.
## "-- throughput": sustained ticks per second for one 100-mob encounter.
## "-- budget": throughput and breakdown at the budgeted mob counts, as one JSON line for run_bench.ps1.

const Arena = preload("res://mob_sim/tests/mob_sim_arena.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")

const SEEDS := [11, 2222, 987654]
const COUNTS := [20, 50, 100]
const BUDGET_COUNTS := [20, 100]
const WARMUP_TICKS := 300
const TICKS := 1800
const THROUGHPUT_MOBS := 100
const THROUGHPUT_TICKS := 12000
const BUDGET_TICKS := 6000


func _initialize() -> void:
	call_deferred("run")


## Per-system mean, p95 and slowest tick, using the simulation's own timers.
func measure(seed_value: int, count: int) -> Dictionary:
	var arena := Arena.new(seed_value, count)
	for tick in WARMUP_TICKS:
		_step(arena)
	arena.sim.timers.enabled = true
	arena.sim.timers.reset()
	var samples := PackedInt64Array()
	for tick in TICKS:
		arena.before_tick()
		var began := Time.get_ticks_usec()
		arena.sim.tick()
		samples.append(Time.get_ticks_usec() - began)
		arena.after_tick()
	samples.sort()
	var report := arena.sim.timers.report()
	report["p95"] = snappedf(samples[int(TICKS * 0.95)] / 1000.0, 0.001)
	report["engaged"] = arena.sim.pool.engaged.count(1)
	return report


## Ticks per second with timers off, so the figure has no measurement overhead.
func rate(seed_value: int, count: int, ticks: int) -> Dictionary:
	var arena := Arena.new(seed_value, count)
	for tick in WARMUP_TICKS:
		_step(arena)
	var spent := 0
	for tick in ticks:
		arena.before_tick()
		var began := Time.get_ticks_usec()
		arena.sim.tick()
		spent += Time.get_ticks_usec() - began
		arena.after_tick()
	var per_second := ticks / maxf(0.000001, spent / 1000000.0)
	return {"ticks_per_second": roundi(per_second), "times_real_time": snappedf(per_second / 60.0, 0.1)}


func _step(arena: Arena) -> void:
	arena.before_tick()
	arena.sim.tick()
	arena.after_tick()


func run() -> void:
	if not NavWorld.ensure_loaded():
		printerr("FAIL native extension did not load")
		quit(2)
		return
	var arguments := OS.get_cmdline_user_args()
	if "throughput" in arguments:
		print("THROUGHPUT_RESULT ", JSON.stringify(rate(2222, THROUGHPUT_MOBS, THROUGHPUT_TICKS)))
	elif "budget" in arguments:
		var report := {}
		for count in BUDGET_COUNTS:
			report[str(count)] = rate(2222, count, BUDGET_TICKS).merged({"systems": measure(2222, count)})
		print("SIM_BUDGET_RESULT ", JSON.stringify(report))
	else:
		var report := {}
		for seed_value in SEEDS:
			var entry := {}
			for count in COUNTS:
				entry[str(count)] = measure(seed_value, count)
			report[str(seed_value)] = entry
		print("SIM_BENCH_RESULT ", JSON.stringify(report))
	quit(0)
