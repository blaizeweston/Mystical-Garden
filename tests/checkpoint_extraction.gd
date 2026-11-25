extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
var failed := false
func check(ok: bool, message: String):
	if not ok:
		failed = true
		printerr("FAIL: ", message)
func _initialize():
	call_deferred("run")
func run():
	var returns=preload("res://garden_return_service.gd")
	for row in [[0,0],[5,0],[6,2],[11,2],[12,6],[18,10],[24,14],[36,22],[60,38]]:
		check(returns.extraction_reward(row[0])==row[1],"cumulative Knowledge after %d clears"%row[0])
	var game = load("res://world.tscn").instantiate()
	var token := Crypto.new().generate_random_bytes(8).hex_encode()
	game.progress.path = "res://.godot/checkpoint_" + token + ".cfg"
	game.local_character.path = game.progress.path + ".character"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	var p: Dictionary = game.players[1]
	p.pos = game.stage.gate_position()
	var tree=game.Classes.connected_tree(int(p.frame))
	p.character[tree.profile_key]=tree.state([tree.nodes[0].id])
	game.send_action(false)
	game.send_garden_action("depart")
	p.carried_seeds.assign([0])
	var original_knowledge: int = game.progress.knowledge
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
			if game.checkpoint_pending: game.send_garden_action(game.affinity_checkpoint_action(game.ui.checkpoint_revision(),"skip"))
		else:
			p.pos = game.battlefield.entry
			game.send_garden_action("extract")
			check(ExpeditionCase.is_wild(p), "extraction is unavailable at the map entrance")
			p.pos = game.battlefield.advance
			game._process(.016)
			check(UIFixture.control(game,"guide").text.contains("T  Extract"), "checkpoint offers extraction next to onward gate")
			game.send_garden_action("extract")
			check(not ExpeditionCase.is_wild(p) and game.seed_reserve(p).unknown == [0], "checkpoint banks carried loot and returns to Garden")
	check(game.progress.knowledge == original_knowledge + 2,"one confirmed six-clear extraction adds two shared Knowledge")
	p.pos = game.stage.gate_position()
	game.send_action(false)
	game.send_garden_action("depart")
	ExpeditionCase.set_world(game, {"encounter_number": 6})
	game.encounter.set_hp(-1, 0)
	game.encounter.clear_scouts()
	p.pos = game.battlefield.advance
	game.send_action(false)
	check(UIFixture.control(game,"checkpoint_menu").visible and game.participation.floor()==6,"checkpoint holds travel for a card decision")
	game.send_garden_action(game.affinity_checkpoint_action(game.ui.checkpoint_revision(),"skip"))
	check(ExpeditionCase.is_wild(p) and game.participation.floor() == 7, "E continues instead of extracting at the checkpoint")
	await process_frame
	if not failed: print("PASS: cleared checkpoint extraction, onward choice and real six-floor route")
	quit(1 if failed else 0)
