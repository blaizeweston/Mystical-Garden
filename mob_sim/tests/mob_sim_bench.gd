extends SceneTree
## Measures the mob simulation layers in a synthetic encounter. Host stand-in work is not timed.
## Pass "-- throughput" to measure sustained ticks per second instead.

const Arena = preload("res://mob_sim/tests/mob_sim_arena.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")

const SEEDS := [11, 2222, 987654]
const COUNTS := [20, 50, 100]
const WARMUP_TICKS := 300
const TICKS := 1800
const THROUGHPUT_MOBS := 100
const THROUGHPUT_TICKS := 12000
const PHASES := ["perception", "decisions", "executors", "abilities", "movement"]


func _initialize() -> void:
	call_deferred("run")


## Mirrors MobSim.tick() so each layer can be timed on its own.
func timed_tick(arena: Arena, spent: PackedInt64Array) -> int:
	var sim: Arena.Sim = arena.sim
	var began := Time.get_ticks_usec()
	sim.clock.advance()
	var now := sim.clock.tick
	sim.perception.update(now)
	var a := Time.get_ticks_usec()
	sim._decide(now)
	var b := Time.get_ticks_usec()
	sim.executors.run(now)
	var c := Time.get_ticks_usec()
	sim.abilities.tick_windups(now)
	var d := Time.get_ticks_usec()
	sim.locomotion.step(now)
	var e := Time.get_ticks_usec()
	spent[0] += a - began
	spent[1] += b - a
	spent[2] += c - b
	spent[3] += d - c
	spent[4] += e - d
	return e - began


func measure(seed_value: int, count: int) -> Dictionary:
	var arena := Arena.new(seed_value, count)
	for tick in WARMUP_TICKS:
		arena.before_tick()
		arena.sim.tick()
		arena.after_tick()
	var samples := PackedInt64Array()
	var spent := PackedInt64Array([0, 0, 0, 0, 0])
	for tick in TICKS:
		arena.before_tick()
		samples.append(timed_tick(arena, spent))
		arena.after_tick()
	samples.sort()
	var total := 0
	for value in samples:
		total += value
	var phases := {}
	for index in PHASES.size():
		phases[PHASES[index]] = snappedf(spent[index] / 1000.0 / TICKS, 0.001)
	return {"mean_ms": snappedf(total / 1000.0 / TICKS, 0.001), "p95_ms": snappedf(samples[int(TICKS * 0.95)] / 1000.0, 0.001),
		"max_ms": snappedf(samples[TICKS - 1] / 1000.0, 0.001), "phases": phases, "engaged": arena.sim.pool.engaged.count(1)}


func throughput() -> void:
	var arena := Arena.new(2222, THROUGHPUT_MOBS)
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
	if "throughput" in OS.get_cmdline_user_args():
		throughput()
	else:
		var report := {}
		for seed_value in SEEDS:
			var entry := {}
			for count in COUNTS:
				entry[str(count)] = measure(seed_value, count)
			report[str(seed_value)] = entry
		print("SIM_BENCH_RESULT ", JSON.stringify(report))
	quit(0)
