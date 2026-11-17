extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
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
	game.progress.path = "res://.godot/checkpoint_" + token + ".cfg"
	game.local_character.path = game.progress.path + ".character"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	var p: Dictionary = game.players[1]
	p.pos = game.Stage.GATE
	game.send_action(false)
	game.send_garden_action("depart")
	p.carried_seeds.assign([0])
	for floor_number in range(1,7):
		check(game.participation.floor() == floor_number, "route advances through six encounters")
		game.encounter.clear_scouts()
		game.encounter.set_hp(-1, 1)
		p.pos = game.battlefield.advance
		game.send_garden_action("extract")
		check(ExpeditionCase.is_wild(p), "live checkpoint never extracts")
		game.encounter.set_hp(-1, 0)
		game.deepest_milestone = floor_number
		if floor_number < 6:
			game.send_garden_action("extract")
			check(ExpeditionCase.is_wild(p) and game.seed_reserve(p).unknown.is_empty(), "ordinary cleared floors cannot bank loot")
			game.send_action(false)
			if game.checkpoint_pending: game.send_garden_action("checkpoint_choice_-1")
		else:
			p.pos = game.battlefield.entry
			game.send_garden_action("extract")
			check(ExpeditionCase.is_wild(p), "extraction is unavailable at the map entrance")
			p.pos = game.battlefield.advance
			game._process(.016)
			check(game.guide.text.contains("T  Extract"), "checkpoint offers extraction next to onward gate")
			game.send_garden_action("extract")
			check(not ExpeditionCase.is_wild(p) and game.seed_reserve(p).unknown == [0], "checkpoint banks carried loot and returns to Garden")
	p.pos = game.Stage.GATE
	game.send_action(false)
	game.send_garden_action("depart")
	ExpeditionCase.set_world(game, {"encounter_number": 6})
	game.encounter.set_hp(-1, 0)
	game.encounter.clear_scouts()
	p.pos = game.battlefield.advance
	game.send_action(false)
	check(game.checkpoint_menu.visible and game.participation.floor()==6,"checkpoint holds travel for a card decision")
	game.send_garden_action("checkpoint_choice_-1")
	check(ExpeditionCase.is_wild(p) and game.participation.floor() == 7, "E continues instead of extracting at the checkpoint")
	await process_frame
	if not failed: print("PASS: cleared checkpoint extraction, onward choice and real six-floor route")
	quit(1 if failed else 0)
