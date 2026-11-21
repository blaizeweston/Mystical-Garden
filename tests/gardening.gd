extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")
const Progress = preload("res://progress.gd")
const Stage = preload("res://stage.gd")
var failed := false
func check(ok: bool, message: String):
	if not ok:
		failed = true
		printerr("FAIL: ", message)
func _initialize():
	call_deferred("run")
func run():
	var game = load("res://world.tscn").instantiate()
	var token := Crypto.new().generate_random_bytes(8).hex_encode()
	game.progress.path = "res://.godot/plots_" + token + ".cfg"
	game.local_character.path = game.progress.path + ".character"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	var p: Dictionary = game.players[1]
	var reserve: Dictionary = game.seed_reserve(p)
	reserve.stock.assign([2,2,2])
	p.pos = Stage.PLOTS[0]
	p.seed_choice = 2
	interact(game,p)
	check(game.progress.plots[0].species == 2 and reserve.stock[2] == 1, "any species can be planted in the first bed")
	game.progress.advance_growth(float(game.Seeds.DEFINITIONS[2].grow_seconds)*.225)
	check(game.progress.plots[0].stage == 1, "seed becomes a sprout")
	game.progress.advance_growth(float(game.Seeds.DEFINITIONS[2].grow_seconds)*.3375)
	check(game.progress.plots[0].stage == 2, "sprout becomes a young plant")
	var before: int = game.progress.parts[2]
	interact(game,p)
	check(game.progress.parts[2] == before, "immature plants cannot be harvested")
	game.progress.advance_growth(float(game.Seeds.DEFINITIONS[2].grow_seconds)*.4375)
	interact(game,p)
	check(game.progress.parts[2] == before + 1 and game.progress.plots[0].species == -1, "harvest grants the species part and empties the bed")
	p.seed_choice = 1
	interact(game,p)
	check(game.progress.plots[0].species == 1, "empty harvested bed accepts another species")
	p.pos = Stage.PLOTS[1]
	interact(game,p)
	check(game.progress.plots[1].species == 1, "duplicate crops can grow in separate beds")
	game.progress.flowering_unlocked = true
	game.progress.advance_growth(float(game.Seeds.DEFINITIONS[1].grow_seconds))
	var seeds_before: int = reserve.stock[1]
	game.send_garden_action("flower")
	check(game.progress.plots[1].species == -1 and reserve.stock[1] == seeds_before + 2, "seed harvest also clears the bed")
	game.progress.parts.assign([30,0,0])
	game.progress.knowledge = 60
	p.pos = Stage.HEART
	game.send_garden_action("heart_confirm:"+JSON.stringify({"id":"plot_4","plan":{}}))
	check(game.progress.plots.size()==3 and game.progress.heart.active=="plot_4" and game.progress.parts[0]==30,"host starts Knowledge-funded bed research")
	game.progress.heart.add_work(game.progress,game.progress.heart.duration(game.progress.heart.active));check(preload("res://tests/support/terrain_case.gd").place_structure(game,"bed"),"researched capacity accepts a placed bed")
	check(game.progress.plots.size()==4,"research grows a new independent bed")
	game.progress.save_garden()
	var reload := Progress.new()
	reload.path = game.progress.path
	check(reload.load_garden() == OK and reload.plots.size() == 4 and reload.plots[0].species == 1 and reload.plots[0].stage == 3, "plot species, maturity and expansion persist")
	var decoded := Progress.decode_plots(game.progress.plot_snapshot())
	check(decoded.size() == 4 and decoded[0].species == 1 and decoded[0].stage == 3, "compact multiplayer snapshot contains every bed")
	# Legacy save migration preserves old crops and creates a recovery backup.
	var legacy_path: String = game.progress.path + ".legacy"
	var legacy := ConfigFile.new()
	legacy.set_value("garden","planted_1",true)
	legacy.set_value("garden","ready_1",true)
	legacy.save(legacy_path)
	var migrated := Progress.new()
	migrated.path = legacy_path
	check(migrated.load_garden() == OK and migrated.plots[1].species == 1 and migrated.plots[1].stage == 3, "old Garden crops migrate intact")
	check(migrated.save_garden() == OK and FileAccess.file_exists(legacy_path+".pre-plots-v2.bak"), "legacy save is backed up before format conversion")
	game.progress.parts[0] = 200
	game.progress.knowledge = 400
	for remaining in range(Progress.MAX_PLOTS-game.progress.plots.size()):
		game.garden_action(1,"heart_confirm:"+JSON.stringify({"id":"plot_%d"%(game.progress.plots.size()+1),"plan":{}}));check(not game.progress.heart.active.is_empty(), "later bed capacity can be researched")
		game.progress.heart.add_work(game.progress,game.progress.heart.duration(game.progress.heart.active));check(preload("res://tests/support/terrain_case.gd").place_structure(game,"bed"),"researched capacity accepts a placed bed")
	var parts_before: int = game.progress.parts[0]
	check(game.progress.expand_plot() == ERR_UNAVAILABLE and game.progress.parts[0] == parts_before, "bed cap does not consume resources")
	game._process(.016)
	check(game.stage.active_plots == 9, "expanded plots are rendered")
	await process_frame
	if not failed: print("PASS: universal plots, growth stages, harvest/replant, flowering, expansion, migration and camera bounds")
	quit(1 if failed else 0)


func interact(game,p: Dictionary):
	game.send_action(false)
	if UIFixture.control(game,"planting_menu").visible: game.send_garden_action("plant_at_%d_%d"%[UIFixture.control(game,"planting_view").slot,p.seed_choice])

