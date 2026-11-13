extends SceneTree

const Slots = preload("res://save_slots.gd")
const Profile = preload("res://character_profile.gd")
const Progress = preload("res://progress.gd")
const Preview = preload("res://combat_balance_preview.gd")

var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL combat balance saves: ", detail)


func run() -> void:
	check(Preview.enabled and not Preview.playtest, "the new combat balance is active on ordinary launch")
	await verify_new_garden()
	var fixture := "res://.godot/balance-saves-" + Crypto.new().generate_random_bytes(8).hex_encode()
	var storage := Slots.new()
	storage.root_path = fixture.path_join("saves")
	storage.legacy_garden = fixture.path_join("garden.cfg")
	storage.legacy_character = fixture.path_join("character.cfg")
	storage.legacy_guest = fixture.path_join("guest.cfg")
	if DirAccess.make_dir_recursive_absolute(fixture) != OK:
		check(false, "fixture directory is writable")
		quit(1)
		return
	var old_garden := ConfigFile.new()
	old_garden.set_value("garden", "knowledge", 19)
	old_garden.set_value("garden", "unknown", [1])
	old_garden.set_value("garden", "stock_0", 4)
	old_garden.set_value("garden", "parts_0", 7)
	old_garden.set_value("garden", "planted_0", true)
	old_garden.set_value("garden", "ready_0", true)
	old_garden.set_value("campaign", "best_clear", 12)
	check(old_garden.save(storage.legacy_garden) == OK, "pre-manifest Garden is written")
	var old_profile := ConfigFile.new()
	var legacy_levels: Array = Profile.ContentIDs.legacy().get("levels", [0,3,7,12,20])
	var prior_data := {
		"name":"Earlier Warden", "xp":[legacy_levels[2],0,0,0,0],
		"plants":[9], "upgrades":[1,0,0,0,0], "loadouts":[{"weapon":1,"parts":[1,0,0]}],
	}
	var identity := "a3d56083704e49b6841fa86fcf91de62"
	old_profile.set_value("character", "identity", identity)
	old_profile.set_value("character", "progress", prior_data)
	check(old_profile.save(storage.legacy_character) == OK, "pre-manifest character is written")
	var old_garden_hash := FileAccess.get_sha256(storage.legacy_garden)
	var old_profile_hash := FileAccess.get_sha256(storage.legacy_character)
	check(storage.prepare(false) == OK and storage.new_game(1) == OK, "current-format save is written alongside legacy fixture")
	var current_world := Progress.new()
	current_world.path = storage.paths(1).garden
	current_world.knowledge = 31
	current_world.stock[0] = 8
	current_world.parts[1] = 3
	check(current_world.save_garden() == OK, "current Garden holds known progression")
	var current_profile := Profile.new()
	current_profile.path = storage.paths(1).character
	current_profile.data.name = "Current Ranger"
	current_profile.data.active_class = 1
	current_profile.data.xp[1] = 13
	current_profile.data.xp_tenths[1] = 4
	check(current_profile.save_profile() == OK, "current character holds known progression")
	var game: Node = await open_save(storage, fixture, 0, "Earlier Warden")
	if game == null:
		quit(1)
		return
	check(game.progress.knowledge == 19 and game.progress.stock[0] == 4 and game.progress.parts[0] == 7, "legacy Garden knowledge and inventory survive import")
	check(game.progress.unknown == [1] and game.progress.plots[0].species == 0 and game.progress.campaign.best_clear == 12, "legacy seed, bed and expedition record survive import")
	var loaded: Dictionary = game.local_character.data
	check(game.local_character.identity == identity and Profile.level(loaded.xp[0]) == 3 and loaded.plants[0] == 9, "legacy identity, rank and plant familiarity survive import")
	check(loaded.upgrades[0] == 1 and loaded.loadouts[0].weapon == 1 and loaded.loadouts[0].parts[0] == 1, "legacy skill and loadout IDs survive import")
	var expected_hp: int = 100 + Preview.effect_hp(game.weapon_stats(game.players[1]).get("max_health", 0))
	check(game.players[1].max_hp == expected_hp, "legacy character resolves the new pool and preserves max-HP bonuses")
	check(game.progress.save_garden() == OK and game.local_character.save_profile() == OK, "imported slots can be saved with current content IDs")
	check(FileAccess.get_sha256(storage.legacy_garden) == old_garden_hash and FileAccess.get_sha256(storage.legacy_character) == old_profile_hash, "legacy originals are byte-identical")
	check(FileAccess.get_sha256(game.progress.path + ".pre-content-v2.bak") == old_garden_hash, "the in-place Garden conversion retains an original-format backup")
	var saved_profile := ConfigFile.new()
	check(saved_profile.load(game.local_character.path) == OK and saved_profile.has_section("content"), "roster copy uses current IDs and leaves the original profile untouched")
	await close_world(game)
	game = await open_save(storage, fixture, 1, "Current Ranger")
	if game == null:
		quit(1)
		return
	check(game.progress.knowledge == 31 and game.progress.stock[0] == 8 and game.progress.parts[1] == 3, "current Garden opens without losing data")
	check(game.local_character.identity == current_profile.identity and game.local_character.data.xp[1] == 13 and game.local_character.data.xp_tenths[1] == 4 and game.players[1].frame == 1, "current profile keeps identity, fractional XP and chosen class")
	check(game.players[1].max_hp == 100, "current save also resolves 100 maximum HP")
	await close_world(game)
	game = await open_save(storage, fixture, 0, "Earlier Warden")
	if game != null:
		check(game.progress.knowledge == 19 and game.local_character.identity == identity, "converted save reopens without duplicating the character")
		await close_world(game)
	if not failed:
		print("PASS: prior and current Garden/character fixtures, legacy backups, stable identities, 100 HP and reload")
	quit(1 if failed else 0)

func verify_new_garden() -> void:
	var menu: Control = load("res://main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	check(menu.storage.root_path == "user://saves", "ordinary play uses regular Garden slots")
	check(not menu.new_button.disabled and menu.continue_button.disabled, "New Garden is available on a fresh install")
	menu.new_button.pressed.emit()
	check(menu.creator.visible, "New Garden opens the creator when no character exists")
	menu.creator.name_field.text = "Fresh Warden"
	menu.creator.confirmed.emit()
	menu.creator.hide()
	await process_frame
	var game := current_scene
	if game == menu:
		check(false, "character creation continues into the requested new Garden")
		menu.queue_free()
		await process_frame
		return
	check(game.progress.path == "user://saves/slot_1/garden.cfg" and FileAccess.file_exists(game.progress.path), "fresh Garden persists in the regular slot")
	check(game.local_character.data.name == "Fresh Warden" and game.players[1].max_hp == 100, "the new Garden starts with the selected character and 100 HP")
	check(not DirAccess.dir_exists_absolute(Preview.STORAGE_PATH), "regular play leaves preview storage alone")
	await close_world(game)

func open_save(storage: RefCounted, fixture: String, slot: int, profile_name: String) -> Node:
	var menu: Control = load("res://main_menu.tscn").instantiate()
	menu.storage = storage
	menu.settings_path = fixture.path_join("settings.cfg")
	menu.restore_last_selection = false
	menu.restore_last_character = false
	root.add_child(menu)
	var character_slot := -1
	for index in menu.characters.count():
		if menu.characters.summary(index).name == profile_name:
			character_slot = index
			break
	if character_slot < 0:
		check(false, "character is available in the title roster: " + profile_name)
		menu.queue_free()
		return null
	menu.select_slot(slot)
	menu.select_character(character_slot)
	menu.continue_game()
	await process_frame
	var game := current_scene
	if game == null or not game.get("progress") is RefCounted:
		check(false, "Continue opens the selected Garden")
		if is_instance_valid(menu):
			menu.queue_free()
		return null
	game.set_process(false)
	game.set_physics_process(false)
	return game


func close_world(game: Node) -> void:
	game.queue_free()
	await process_frame
