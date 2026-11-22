extends SceneTree
## Runs arena rounds without a window, as fast as the machine allows.
## Add --profile to report time per tick for bots, enemies and the rest of the game.
## Example: godot --headless --path . --script res://neural_arena/arena_headless.gd -- --rounds=5 --bots=4 --enemies=rootbound:6,wasp:4

const Config = preload("res://neural_arena/arena_config.gd")
const Entry = preload("res://neural_arena/arena_entry.gd")

const DEFAULT_ROUNDS := 3
const TICK_GUARD_PER_ROUND := 100000


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var config := Config.new()
	config.apply_arguments(arguments)
	var rounds := DEFAULT_ROUNDS
	for argument in arguments:
		if argument.begins_with("--rounds="):
			rounds = maxi(1, argument.get_slice("=", 1).to_int())
	var world: Node = load(Entry.WORLD_SCENE).instantiate()
	world.set_script(load(Entry.WORLD_SCRIPT))
	world.name = Entry.WORLD_NAME
	world.config = config
	world.headless_driver = true
	world.profile = "--profile" in arguments
	root.add_child(world)
	world.begin_session()
	var began := Time.get_ticks_usec()
	var guard := rounds * TICK_GUARD_PER_ROUND
	while world.results.size() < rounds and world.total_ticks < guard:
		world.step_once()
	var seconds := maxf(0.001, (Time.get_ticks_usec() - began) / 1000000.0)
	for result: Dictionary in world.results:
		print("ROUND_RESULT ", JSON.stringify(result))
	print("ARENA_SUMMARY ", JSON.stringify({"rounds": world.results.size(), "ticks": world.total_ticks,
		"ticks_per_second": roundi(world.total_ticks / seconds), "times_real_time": snappedf(world.total_ticks / seconds / 60.0, 0.1),
		"state_hash": world.state_hash(), "profile": world.profile_report() if world.profile else {}}))
	var finished: bool = world.results.size() >= rounds
	world.queue_free()
	await process_frame
	quit(0 if finished else 1)
