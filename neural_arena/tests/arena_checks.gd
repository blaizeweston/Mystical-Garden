extends SceneTree
## Proves the arena's safety, repeatability, combat and time controls. Run through run_arena.ps1.

const Characters = preload("res://neural_arena/arena_characters.gd")
const CombatClock = preload("res://combat_clock.gd")
const Config = preload("res://neural_arena/arena_config.gd")
const Entry = preload("res://neural_arena/arena_entry.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const SaveBatch = preload("res://save_batch.gd")

const NEURAL := "res://ai/training/out/policy.bin"
const CANARIES := ["user://garden.cfg", "user://character.cfg", "user://saves/slot_0/garden.cfg", "user://saves/characters/slot_0/character.cfg"]
const SPECIES_TICKS := 1500
const REPEAT_TICKS := 1800

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	print("PASS " if condition else "FAIL ", label)
	failures += int(not condition)


func make_config(brain: String, enemies: Dictionary, bots := 2) -> Config:
	var config := Config.new()
	config.brain = brain
	config.enemies = enemies
	config.bots = bots
	config.floor_number = 12
	config.round_seconds = 60
	config.map_seed = 4242
	return config


func make_world(config: Config) -> Node:
	var world: Node = load(Entry.WORLD_SCENE).instantiate()
	world.set_script(load(Entry.WORLD_SCRIPT))
	world.name = Entry.WORLD_NAME
	world.config = config
	world.headless_driver = true
	root.add_child(world)
	world.begin_session()
	return world


func close_world(world: Node) -> void:
	world.queue_free()
	await process_frame
	await process_frame


func write_canaries() -> Dictionary:
	var hashes := {}
	for path: String in CANARIES:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("canary for " + path)
		file.close()
		hashes[path] = FileAccess.get_sha256(path)
	return hashes


func test_saves() -> void:
	var before := write_canaries()
	var world := make_world(make_config(NEURAL, {"rootbound": 8, "nightbloom": 4}))
	check(SaveBatch.active, "every game save is refused while the arena runs")
	check(CombatClock.is_stepped(), "the arena runs on fixed-step time")
	check(world.progress.save_garden() != OK, "a direct garden save is refused")
	check(world.local_character.save_profile() != OK, "a direct character save is refused")
	var sandbox: String = world._sandbox
	for tick in REPEAT_TICKS:
		world.step_once()
	await close_world(world)
	var unchanged := true
	for path: String in before:
		unchanged = unchanged and FileAccess.get_sha256(path) == before[path]
	check(unchanged, "real save files stay byte-for-byte identical")
	check(not DirAccess.dir_exists_absolute(sandbox), "the temporary arena folder is removed on exit")
	check(not SaveBatch.active, "game saves work again after leaving the arena")
	check(not CombatClock.is_stepped(), "the real clock returns after leaving the arena")


func run_fingerprint(brain: String) -> Array:
	var world := make_world(make_config(brain, {"rootbound": 6, "nightbloom": 3, "thornmaw": 3}))
	var prints: Array = []
	for tick in REPEAT_TICKS:
		world.step_once()
		if tick % 300 == 299:
			prints.append(world.state_hash())
	await close_world(world)
	return prints


func test_repeatable() -> void:
	for brain: String in [Config.GAME_AI, Config.SCRIPTED_BRAIN, NEURAL]:
		var first: Array = await run_fingerprint(brain)
		var second: Array = await run_fingerprint(brain)
		check(first == second, "identical seeds replay identically with brain '%s'" % brain)


func test_combat() -> void:
	var world := make_world(make_config(NEURAL, {"rootbound": 10, "nightbloom": 6, "gallhorn": 4}, 2))
	var lowest := 1.0
	var enemy_moved := false
	var start: Vector3 = world.encounter.scout(0).pos
	var over_cap := 0
	var cap := int(world.bridge.sim.contract.rules.max_attackers_per_player)
	for tick in REPEAT_TICKS * 2:
		world.step_once()
		if not world.round_running or world.bridge == null:
			continue
		for peer: int in world.players:
			lowest = minf(lowest, PlayerVitals.current_hp(world.players[peer]) / PlayerVitals.maximum_hp(world.players[peer]))
		if world.round_index == 1 and world.encounter.scout_count() > 0:
			enemy_moved = enemy_moved or world.encounter.scout(0).pos.distance_to(start) > 1.0
		for player in world.bridge.sim.party.count:
			over_cap += int(world.bridge.sim.party.attackers[player] > cap)
	check(enemy_moved, "neural enemies move through the real world")
	check(lowest < 1.0, "neural enemies damage real players")
	check(over_cap == 0, "the attacker cap holds against real players")
	await close_world(world)


func test_round_outcomes() -> void:
	var config := make_config(Config.GAME_AI, {"colossus": 12, "gallhorn": 8}, 1)
	config.floor_number = 40
	var world := make_world(config)
	var guard := 0
	while world.results.is_empty() and guard < 18000:
		world.step_once()
		guard += 1
	check(not world.results.is_empty(), "a round reports a result")
	if not world.results.is_empty():
		var result: Dictionary = world.results[0]
		check(result.outcome in ["party_wiped", "enemies_cleared", "timeout"], "the result names how the round ended: " + str(result.outcome))
		if result.outcome == "party_wiped":
			check(result.party_health == 0.0 and result.enemies_left > 0, "a wiped party reports the surviving enemies")
	for tick in 5:
		world.step_once()
	check(world.round_index >= 2 and world.participation.active(), "the next round starts automatically")
	await close_world(world)

	var timed := make_config(Config.GAME_AI, {"rootbound": 1}, 1)
	timed.round_seconds = 5
	timed.floor_number = 60
	var short := make_world(timed)
	short.bots[1].game = short
	short.encounter.scout(0).max_hp = 100000
	short.encounter.set_hp(0, 100000)
	for tick in 330:
		short.step_once()
	check(not short.results.is_empty() and short.results[0].outcome == "timeout", "a round ends when its time limit passes")
	await close_world(short)


func test_species() -> void:
	var attacked: Array[String] = []
	var missed: Array[String] = []
	var catalog: Array = load("res://enemy_catalog.gd").all()
	for entry: Dictionary in catalog:
		if entry.get("boss", false):
			continue
		var config := make_config(Config.SCRIPTED_BRAIN, {str(entry.id): 4}, 1)
		var world := make_world(config)
		var windups := 0
		for tick in SPECIES_TICKS:
			world.step_once()
			for slot in world.encounter.scout_count():
				windups += int(int(world.encounter.scout(slot).windup) > 0)
		(attacked if windups > 0 else missed).append(str(entry.id))
		await close_world(world)
	print("SPECIES_MISSED ", missed)
	check(missed.is_empty(), "every regular enemy species attacks through the bridge (%d of %d)" % [attacked.size(), attacked.size() + missed.size()])


func test_classes() -> void:
	for class_id in Characters.class_count():
		var config := make_config(NEURAL, {"rootbound": 6}, 1)
		config.player_class = class_id
		var world := make_world(config)
		var host: Dictionary = world.players[1]
		check(int(host.frame) == class_id, "the host plays %s" % Characters.class_name_of(class_id))
		for tick in 900:
			world.step_once()
		check(world.encounter_kills.size() > 0 or world.round_index > 1 or world.encounter.living_scout_count() < 6, "%s fights with real abilities" % Characters.class_name_of(class_id))
		await close_world(world)


func test_time_controls() -> void:
	var world := make_world(make_config(NEURAL, {"rootbound": 4}))
	world.headless_driver = false
	for speed_value: float in [0.25, 1.0, 4.0, 16.0]:
		world.set_speed(speed_value)
		var before: int = world.total_ticks
		var clock_before := CombatClock.now()
		for frame in 16:
			world._physics_process(world.TICK_SECONDS)
		check(world.total_ticks - before == roundi(16 * speed_value), "speed %.2fx runs the expected ticks" % speed_value)
		check(CombatClock.now() - clock_before == (world.total_ticks - before) * 1000 / 60 or absi(CombatClock.now() - clock_before - (world.total_ticks - before) * 1000 / 60) <= 1, "combat time follows the speed setting")
	world.paused = true
	var held: int = world.total_ticks
	var held_clock := CombatClock.now()
	for frame in 30:
		world._physics_process(world.TICK_SECONDS)
	check(world.total_ticks == held and CombatClock.now() == held_clock, "pausing stops combat time")
	world.step_once()
	check(world.total_ticks == held + 1, "single-step advances one tick while paused")
	world.config.mode = Config.Mode.PLAY
	check(not world.allowed_speeds().has(16.0) and world.allowed_speeds().has(1.0), "fast-forward is unavailable while a person is playing")
	world.config.session = Config.SessionKind.HOST
	check(world.allowed_speeds() == [1.0], "multiplayer stays at normal speed")
	await close_world(world)


func test_play_mode() -> void:
	var config := make_config(NEURAL, {"rootbound": 3}, 2)
	config.mode = Config.Mode.PLAY
	var world := make_world(config)
	check(not world.host_is_bot(), "the host controls their own body in Play mode")
	check(world.players.size() == 3 and world.bots.size() == 2, "AI allies join the host in Play mode")
	check(world.Life.alive(world.players[1]), "the host enters the fight")
	await close_world(world)


func test_menu_button() -> void:
	var game: Node = load("res://world.tscn").instantiate()
	game.set_script(load("res://neural_arena/tests/menu_game_stub.gd"))
	game.progress.path = "res://.godot/arena_menu_check_garden.cfg"
	game.local_character.path = "res://.godot/arena_menu_check_character.cfg"
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	game.set_physics_process(false)
	var found := false
	for child in game.abandon_button.get_parent().get_children():
		found = found or (child is Button and child.text == "Neural Arena")
	check(found, "the game menu offers the Neural Arena")
	Entry.open_from(game)
	for frame in 8:
		await process_frame
	var scene: Node = current_scene
	check(scene != null and scene.get_script() == load(Entry.WORLD_SCRIPT), "the menu button opens the arena")
	check(scene != null and scene.name == Entry.WORLD_NAME, "the arena keeps the network path co-op relies on")
	check(scene != null and scene.awaiting_setup, "the arena opens on its setup screen")
	if scene != null:
		await close_world(scene)


func run() -> void:
	await test_saves()
	await test_repeatable()
	await test_combat()
	await test_round_outcomes()
	await test_species()
	await test_classes()
	await test_time_controls()
	await test_play_mode()
	await test_menu_button()
	print("%s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)
