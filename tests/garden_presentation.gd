extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Character = preload("res://character_profile.gd")
const RootUI = preload("res://root_ui.gd")
const Stage = preload("res://stage.gd")
var failed := false
func check(ok: bool, message: String):
	if not ok:
		failed = true
		printerr("FAIL: ", message)
func _initialize():
	call_deferred("run")
func run():
	check(RootUI.heart_state(10.0, 10, 4) == 0, "a complete heart uses the full texture")
	check(RootUI.heart_state(9.0, 10, 4) == 1, "half a heart uses the cracked red texture")
	check(RootUI.heart_state(8.0, 10, 4) == 2, "recoverable damage uses the dark damaged texture")
	check(RootUI.heart_state(8.0, 8, 4) == 3, "lost capacity uses the permanently lost texture")
	var old_profile := Character.normalize({"xp": [2, 0]})
	check(old_profile.appearance.slice(0,5) == [0,0,0,0,0] and old_profile.xp[0] == 20, "old profiles gain default appearance without losing progress")
	var malformed := Character.normalize({"appearance": [999,-1,999,999,999]})
	check(malformed.appearance.slice(0,5) == [3,0,2,2,2], "incoming appearance options are bounded")
	var game = load("res://world.tscn").instantiate()
	var token := Crypto.new().generate_random_bytes(8).hex_encode()
	game.progress.path = "res://.godot/garden_test_" + token + ".cfg"
	game.local_character.path = game.progress.path + ".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var p: Dictionary = game.players[1]
	game.garden_action(1, "look_0")
	game.garden_action(1, "look_3")
	check(p.character.appearance.slice(0,5) == [1,0,0,1,0], "Garden appearance controls change only selected options")
	var reload := Character.new()
	reload.path = game.local_character.path
	check(reload.load_profile() == OK and reload.data.appearance == p.character.appearance, "appearance survives saving and reloading")
	var original: Array = p.character.appearance.duplicate()
	ExpeditionCase.set_membership(game, p, true)
	game.garden_action(1, "look_0")
	check(p.character.appearance == original, "appearance cannot be changed mid-expedition")
	p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10)
	IncomingPlayerHit.apply_health_loss(game, 1, PlayerLifecycle.generation(p), 1)
	check(PlayerVitals.current_hp(p) == 9, "one damage point removes half a heart")
	ExpeditionCase.set_membership(game, p, false)
	game._process(.016)
	var start_radius: float = game.stage.garden_disc.scale.x
	game.progress.knowledge = 120
	game.progress.flowering_unlocked = true
	game.progress.veilcap_discovered = true
	game.progress.rift_hook_discovered = true
	game._process(.016)
	check(start_radius >= 11.5 and game.stage.heart_core != null, "larger green sanctuary has a living Heart")
	check(game.stage.garden_disc.scale.x > start_radius and game.stage.garden_disc.scale.x <= 19.0, "knowledge and technology expand the clearing modestly")
	var edge: Vector3 = game.bound_position(Vector3(20,0,20))
	check(is_equal_approx(edge.length(), Stage.garden_radius(120,3) - .4), "Garden movement follows the circular clearing")
	var actor: Dictionary = game.stage.avatar_models[1]
	check(actor.field_rig.scene.find_child("FieldHair1",true,false).visible and not actor.field_rig.scene.find_child("FieldHair0",true,false).visible, "selected field hair is visible without overlapping other styles")
	check(game.player_snapshot(999)[1].appearance is PackedByteArray, "appearance synchronization stays compact")
	var water_count := 0
	var grass_count := 0
	for child in game.stage.garden_edge.get_children():
		if child.has_meta("garden_water_position"):
			water_count += 1
		if child.name == "GardenGrass":
			for batch in child.get_children():
				check(batch is MultiMeshInstance3D and batch.get_meta("garden_motion",false),"ground cover stays batched and uses the ambient motion setting")
				grass_count += batch.multimesh.instance_count
	check(water_count == 2 and grass_count > 200, "Garden contains two animated ponds and a scattered grass field")
	check(game.stage.garden_disc.material_override.shader.resource_path.ends_with("garden_meadow.gdshader"),"the visible clearing uses the scanned meadow material")
	var old_scale: Vector3 = game.stage.heart_tree.scale
	await create_timer(.2).timeout
	game._process(.016)
	check(not game.stage.heart_tree.scale.is_equal_approx(old_scale), "living Heart visibly pulses over time")
	await process_frame
	if not failed: print("PASS: heart stages, Garden growth, circular bounds and saved appearance")
	quit(1 if failed else 0)

