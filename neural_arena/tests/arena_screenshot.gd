extends SceneTree
## Opens the arena in a real window and saves screenshots of its setup screen and a running fight.

const Config = preload("res://neural_arena/arena_config.gd")
const Entry = preload("res://neural_arena/arena_entry.gd")

const FIGHT_FRAMES := 420


func _initialize() -> void:
	call_deferred("run")


func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("SCREENSHOT ", ProjectSettings.globalize_path(path))


func run() -> void:
	var config := Config.new()
	config.brain = "res://ai/training/out/policy.bin"
	config.bots = 4
	config.floor_number = 6
	config.enemies = {"rootbound": 6, "nightbloom": 3, "thornmaw": 3, "gallhorn": 2, "bellcap": 1}
	var world: Node = Entry.launch(self, config, false)
	for frame in 60:
		await process_frame
	await capture("user://arena_setup.png")
	world.hud._start()
	world.set_speed(2.0)
	for frame in FIGHT_FRAMES:
		await process_frame
	await capture("user://arena_fight.png")
	print("ARENA_STATE ", JSON.stringify({"round": world.round_index, "ticks": world.total_ticks, "enemies": world.encounter.living_scout_count(), "bar": world.hud._info.text}))
	world.return_to_main_menu()
	for frame in 10:
		await process_frame
	quit(0)
