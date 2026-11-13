extends SceneTree
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
		check(game.encounter_number == floor_number, "route advances through six encounters")
		game.scouts.clear()
		game.enemy_hp = 1
		p.pos = game.battlefield.advance
		game.send_garden_action("extract")
		check(p.wild, "live checkpoint never extracts")
		game.enemy_hp = 0
		game.deepest_milestone = floor_number
		if floor_number < 6:
			game.send_garden_action("extract")
			check(p.wild and game.seed_reserve(p).unknown.is_empty(), "ordinary cleared floors cannot bank loot")
			game.send_action(false)
			if game.checkpoint_pending: game.send_garden_action("checkpoint_choice_-1")
		else:
			p.pos = game.battlefield.entry
			game.send_garden_action("extract")
			check(p.wild, "extraction is unavailable at the map entrance")
			p.pos = game.battlefield.advance
			game._process(.016)
			check(game.guide.text.contains("T  Extract"), "checkpoint offers extraction next to onward gate")
			game.send_garden_action("extract")
			check(not p.wild and game.seed_reserve(p).unknown == [0], "checkpoint banks carried loot and returns to Garden")
	p.pos = game.Stage.GATE
	game.send_action(false)
	game.send_garden_action("depart")
	game.encounter_number = 6
	game.enemy_hp = 0
	game.scouts.clear()
	p.pos = game.battlefield.advance
	game.send_action(false)
	check(game.checkpoint_menu.visible and game.encounter_number==6,"checkpoint holds travel for a card decision")
	game.send_garden_action("checkpoint_choice_-1")
	check(p.wild and game.encounter_number == 7, "E continues instead of extracting at the checkpoint")
	await process_frame
	if not failed: print("PASS: cleared checkpoint extraction, onward choice and real six-floor route")
	quit(1 if failed else 0)
