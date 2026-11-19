extends SceneTree
## Compares the current movement stack with the native core on identical scenarios.
## Pass "-- throughput" to measure sustained native ticks per second instead.

const Battlefield = preload("res://battlefield.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const FRAMES := 600
const DT := 1.0 / 60.0
const SPEED := 2.2
const STOP := 1.2
const SEEDS := [11, 2222, 987654]
const COUNTS := [20, 50, 100, 200]
const THROUGHPUT_TICKS := 60000


func _initialize() -> void:
	call_deferred("run")


func free_points(field: RefCounted, count: int, rng: RandomNumberGenerator) -> Array[Vector3]:
	var cells: Array[Vector2i] = []
	for x in range(-56,57):
		for z in range(-54,55):
			if not field.occupied(Vector3(x*.5,0,z*.5),.8):
				cells.append(Vector2i(x,z))
	var out: Array[Vector3] = []
	for i in count:
		var c: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		out.append(Vector3(c.x * 0.5, 0, c.y * 0.5))
	return out


## Four players walking between random goals, recorded so both stacks see the same motion.
func record_players(field: RefCounted, seed_value: int, frames: int) -> Array[PackedFloat32Array]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var players := free_points(field, 4, rng)
	var goals := free_points(field, 4, rng)
	var track: Array[PackedFloat32Array] = []
	for frame in frames:
		var row := PackedFloat32Array()
		for p in 4:
			if players[p].distance_to(goals[p]) < 1.0:
				goals[p] = free_points(field, 1, rng)[0]
			players[p] = field.navigate(players[p], goals[p], 4.5 * DT, 100000 + p)
			row.append(players[p].x)
			row.append(players[p].z)
		track.append(row)
	return track


func summary(samples: PackedInt64Array) -> Dictionary:
	samples.sort()
	var total := 0
	for value in samples:
		total += value
	return {"mean_ms": snappedf(total / 1000.0 / samples.size(), 0.001),
		"p95_ms": snappedf(samples[int(samples.size() * .95)] / 1000.0, 0.001),
		"max_ms": snappedf(samples[samples.size() - 1] / 1000.0, 0.001)}


func director_navigate(field: RefCounted, agents: Array[Vector3], index: int, to: Vector3, distance: float) -> Vector3:
	var from: Vector3 = agents[index]
	var desired: Vector3 = field.navigate(from, to, distance, index)
	var repel := Vector3.ZERO
	for position in agents:
		var offset: Vector3 = from - position
		var length := offset.length()
		if length > .001 and length < .85:
			repel += offset.normalized() * (.85 - length) / .85
	return field.slide(from, desired + repel.limit_length(1.0) * distance * .65) if not repel.is_zero_approx() else desired


func run_current(field: RefCounted, starts: Array[Vector3], track: Array[PackedFloat32Array]) -> Dictionary:
	var agents: Array[Vector3] = starts.duplicate()
	var samples := PackedInt64Array()
	field.routes.clear()
	for frame in track.size():
		var row: PackedFloat32Array = track[frame]
		var started := Time.get_ticks_usec()
		for i in agents.size():
			var best := INF
			var victim := Vector3.ZERO
			for p in 4:
				var at := Vector3(row[p * 2], 0, row[p * 2 + 1])
				var d: float = agents[i].distance_to(at)
				if d < best:
					best = d
					victim = at
			if best > STOP:
				agents[i] = director_navigate(field, agents, i, victim, SPEED * DT)
		samples.append(Time.get_ticks_usec() - started)
	return summary(samples)


func agent_rows(starts: Array[Vector3]) -> PackedFloat32Array:
	var rows := PackedFloat32Array()
	for at in starts:
		rows.append_array(PackedFloat32Array([1.0, at.x, at.z, SPEED, Battlefield.CLEARANCE, STOP,
			float(NavWorld.NEAREST_TARGET), float(NavWorld.Mode.SEEK), 0.0, 0.0]))
	return rows


func run_native(field: RefCounted, starts: Array[Vector3], track: Array[PackedFloat32Array]) -> Dictionary:
	var world: RefCounted = NavWorld.create(starts.size(), 4)
	var baked_at := Time.get_ticks_usec()
	var baked: int = NavWorld.bake(world, field)
	var bake_ms := (Time.get_ticks_usec() - baked_at) / 1000.0
	world.set_targets(track[0])
	world.load_agents(agent_rows(starts))
	var samples := PackedInt64Array()
	for row in track:
		var started := Time.get_ticks_usec()
		world.set_targets(row)
		world.tick(DT)
		world.positions()
		samples.append(Time.get_ticks_usec() - started)
	var result := summary(samples)
	result["bake_ms"] = snappedf(bake_ms, 0.01)
	result["bake_status"] = baked
	result["field_solves"] = world.field_solves()
	return result


func compare() -> void:
	var report := {}
	for seed_value in SEEDS:
		var field = Battlefield.new()
		field.configure(0, 5, seed_value)
		var track := record_players(field, seed_value, FRAMES)
		var entry := {}
		for count in COUNTS:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value + count
			var starts := free_points(field, count, rng)
			entry[str(count)] = {"current": run_current(field, starts, track), "native": run_native(field, starts, track)}
		report[str(seed_value)] = entry
	print("BENCH_RESULT ", JSON.stringify(report))


func throughput() -> void:
	var field = Battlefield.new()
	field.configure(0, 5, 2222)
	var track := record_players(field, 2222, FRAMES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2322
	var world: RefCounted = NavWorld.create(100, 4)
	NavWorld.bake(world, field)
	world.set_targets(track[0])
	world.load_agents(agent_rows(free_points(field, 100, rng)))
	var started := Time.get_ticks_usec()
	for tick in THROUGHPUT_TICKS:
		world.set_targets(track[tick % track.size()])
		world.tick(DT)
	var seconds := (Time.get_ticks_usec() - started) / 1000000.0
	print("THROUGHPUT_RESULT ", JSON.stringify({"ticks_per_second": roundi(THROUGHPUT_TICKS / seconds),
		"times_real_time": snappedf(THROUGHPUT_TICKS / seconds / 60.0, 0.1)}))


func run() -> void:
	if not NavWorld.ensure_loaded():
		printerr("FAIL native extension did not load")
		quit(2)
		return
	if "throughput" in OS.get_cmdline_user_args():
		throughput()
	else:
		compare()
	quit(0)
