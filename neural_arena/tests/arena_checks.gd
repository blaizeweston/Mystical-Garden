extends SceneTree
## Proves the arena's safety, repeatability, combat and time controls. Run through run_arena.ps1.

const MobNavWorld = preload("res://mob_sim/mob_nav_world.gd")
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


## At floor 12 every late-unlocking signature is available, so the kits' variety must show up in play.
func test_kits() -> void:
	var world := make_world(make_config(Config.SCRIPTED_BRAIN, {"nightbloom": 4, "orchid": 3, "spore_widow": 3, "ashen_hart": 3, "rootbound": 4, "broodmother": 1}, 3))
	var lowest := 1.0
	for tick in REPEAT_TICKS * 2:
		world.step_once()
		for peer: int in world.players:
			lowest = minf(lowest, PlayerVitals.current_hp(world.players[peer]) / PlayerVitals.maximum_hp(world.players[peer]))
	var used: Dictionary = world.bridge.sim.abilities.used if world.bridge != null else {}
	var placed: int = world.bridge.sim.abilities.hazards_placed if world.bridge != null else 0
	var kits = load("res://mob_sim/definitions/definition_loader.gd").shared()
	var foreign := PackedStringArray()
	for id in used:
		if not kits.species.any(func(species) -> bool: return species.kit.has(id)) and id != kits.support_fallback:
			foreign.append(id)
	print("KIT_USE ", used, " hazards ", placed)
	check(used.size() >= 5, "the arena's enemies use at least five different kit abilities (%d)" % used.size())
	check(used.has("nightbloom_late_pulse"), "an unlocked signature ability is used in real combat")
	check(placed > 0, "hazard abilities place hazards in the real game")
	check(foreign.is_empty(), "every ability used comes from a species kit %s" % foreign)
	check(lowest < 1.0, "kit abilities damage real players through the game's hit rules")
	await close_world(world)


## Support handlers against the real game: rallies order escorts, and rites through allies are cast.
func test_handlers() -> void:
	var world := make_world(make_config(Config.SCRIPTED_BRAIN, {"root_shepherd": 2, "root_choir": 1, "bellcap": 1, "pallbearer": 1,
		"rootbound": 6, "thornmaw": 3, "graft_thief": 1}, 3))
	var ordered := 0
	var used := {}
	for tick in REPEAT_TICKS * 2:
		world.step_once()
		if world.bridge == null:
			continue
		# Each round starts a fresh simulation, so collect ability use as it happens.
		for id in world.bridge.sim.abilities.used:
			used[id] = true
		var pool = world.bridge.sim.pool
		for slot in pool.active:
			ordered += int(pool.command_until[slot] > world.bridge.sim.clock.tick)
	print("HANDLER_USE ", used.keys(), " ordered ticks ", ordered)
	check(used.has("root_shepherd_rally") or used.has("root_shepherd_flank_order"), "a Root Shepherd rallies in real combat")
	check(ordered > 0, "a rally orders real escorts onto its target")
	check(used.has("root_choir_pulse") or used.has("root_choir_split_chorus"), "a Root Choir pulses through its escorts")
	await close_world(world)


## Mana and dodging against the real game: casters spend mana and channel, agile mobs dodge real hits.
func test_actions() -> void:
	var world := make_world(make_config(Config.SCRIPTED_BRAIN, {"nightbloom": 3, "bellcap": 1, "thornmaw": 4, "graft_thief": 1,
		"rootbound": 4}, 3))
	var channel_ticks := 0
	var dodges := 0
	var spent := false
	for tick in REPEAT_TICKS * 2:
		world.step_once()
		if world.bridge == null:
			continue
		var sim = world.bridge.sim
		var pool = sim.pool
		for slot in pool.active:
			channel_ticks += int(sim.actions.channeling(slot, sim.clock.tick))
			dodges += int(pool.dodge_until[slot] == sim.clock.tick + sim.species.dodge_ticks[pool.species[slot]])
			spent = spent or (sim.species.mana_pool[pool.species[slot]] > 0.0 and pool.mana[slot] < sim.species.mana_pool[pool.species[slot]])
	print("ACTIONS channel ticks ", channel_ticks, " dodges ", dodges)
	check(spent, "casters spend mana in real combat")
	check(channel_ticks > 0, "a caster channels to refill its mana")
	check(dodges > 0, "an agile mob dodges in real combat")
	await close_world(world)


## Flyers against the real game: they move on the air layer, fight, are never rooted, and the game leaves
## them where the simulation put them.
func test_flying() -> void:
	var world := make_world(make_config(Config.SCRIPTED_BRAIN, {"wasp": 4, "orchid": 3, "rootbound": 2}, 1))
	var flyer_ticks := 0
	var rooted := 0
	var lost := 0
	var timed := false
	var used := {}
	for tick in REPEAT_TICKS * 2:
		world.step_once()
		if world.bridge == null:
			continue
		var sim = world.bridge.sim
		if not timed:
			timed = true
			var began := Time.get_ticks_usec()
			var floor: PackedByteArray = MobNavWorld.floor_mask(world.bridge.game.battlefield)
			var middle := Time.get_ticks_usec()
			MobNavWorld.air_mask(world.bridge.game.battlefield, floor)
			print("AIR_MASK_MS floor ", (middle - began) / 1000.0, " air ", (Time.get_ticks_usec() - middle) / 1000.0)
		for slot in sim.pool.active:
			if not sim.locomotion.flies(slot):
				continue
			flyer_ticks += 1
			rooted += int(sim.pool.root_until[slot] > sim.clock.tick)
			lost += int(sim.locomotion.world.air_clearance(sim.pool.xz[slot * 2], sim.pool.xz[slot * 2 + 1]) < 0.0)
		used = sim.abilities.used
	var released := 0
	for ability: String in used:
		released += int(used[ability]) if ability.begins_with("wasp") or ability.begins_with("orchid") else 0
	print("FLYING flyer ticks ", flyer_ticks, " releases ", released, " rooted ", rooted, " outside ", lost, " used ", used)
	check(flyer_ticks > 0, "flyers take part in real combat")
	check(released > 0, "flyers attack in real combat")
	check(rooted == 0, "flyers are never rooted")
	check(lost == 0, "the game never moves a flyer outside the air layer")
	await close_world(world)


## A night round: the simulation senses by light, hiding is legal, players see only lit or close enemies,
## the bots still fight, and the host's view hides enemies the local player cannot see.
func test_darkness() -> void:
	var config := make_config(Config.SCRIPTED_BRAIN, {"rootbound": 4, "lantern_lure": 1, "nightbloom": 2}, 2)
	config.darkness = "night"
	var world := make_world(config)
	var seen := 0
	var unseen := 0
	var lit_glow := false
	var view_checked := false
	var view_ok := true
	for tick in REPEAT_TICKS:
		world.step_once()
		if world.bridge == null or world.bridge.light == null:
			continue
		var sim = world.bridge.sim
		var light = world.bridge.light
		for slot in sim.pool.active:
			for peer: int in world.players:
				if world.bridge.player_sees(peer, slot):
					seen += 1
				else:
					unseen += 1
		for index in range(0, sim.perception.lights.size(), 4):
			lit_glow = lit_glow or sim.perception.lights[index + 2] == 5.0
		if not view_checked and unseen > 0 and tick % 60 == 0:
			view_checked = true
			var mode = world.config.mode
			world.config.mode = Config.Mode.PLAY
			var local_id: int = world.multiplayer.get_unique_id()
			for slot in sim.pool.active:
				world.stage.support_models[slot].visible = true
			world._darkness_view.apply(world)
			for slot in sim.pool.active:
				view_ok = view_ok and world.stage.support_models[slot].visible == world.bridge.player_sees(local_id, slot)
			world.config.mode = mode
			world._darkness_view.apply(world)
	var bridge = world.bridge
	print("DARKNESS seen ", seen, " unseen ", unseen, " defeated ", world._enemies_defeated)
	check(bridge != null and bridge.light.enabled and bridge.sim.perception.senses_enabled, "a night round turns the simulation's senses on")
	check(bridge != null and bridge.sim.rules.available[bridge.sim.contract.id("hide")] != 0, "enemies may hide at night")
	check(seen > 0 and unseen > 0, "players see some enemies and lose others in the dark")
	check(lit_glow, "the Lantern Lure's lantern is a light source")
	check(view_checked and view_ok, "the host's view shows exactly the enemies the local player sees")
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
	for child in game.ui.find_children("*", "Button", true, false):
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
	await test_kits()
	await test_handlers()
	await test_actions()
	await test_flying()
	await test_darkness()
	await test_round_outcomes()
	await test_species()
	await test_classes()
	await test_time_controls()
	await test_play_mode()
	await test_menu_button()
	print("%s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)
