extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Character = preload("res://character_profile.gd")
const Orb = preload("res://health_orb.gd")
var failed := false
func check(ok: bool, message: String):
	if not ok:
		failed = true
		printerr("FAIL: ", message)
func _initialize():
	call_deferred("run")
func run():
	check(Orb.fractions(100,100,0).is_equal_approx(Vector2.ONE), "full health fills the health pool")
	check(Orb.fractions(90,100,0).is_equal_approx(Vector2(.9,1)), "damage reduces the health fill without changing capacity")
	check(Orb.fractions(80,100,0).is_equal_approx(Vector2(.8,1)), "recoverable damage remains separate from capacity")
	check(Orb.fractions(80,80,20).is_equal_approx(Vector2(.8,.8)), "revival capacity loss reserves a separate pool segment")
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
	p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100)
	IncomingPlayerHit.apply_health_loss(game, 1, PlayerLifecycle.generation(p), 10)
	check(PlayerVitals.current_hp(p) == 90, "resolved damage removes its stated HP")
	ExpeditionCase.set_membership(game, p, false)
	game._process(.016)
	check(game.stage.experimental_garden != null, "modern Garden owns the visible sanctuary")
	var actor: Dictionary = game.stage.avatar_models[1]
	check(actor.field_rig.scene.find_child("FieldHair1",true,false).visible and not actor.field_rig.scene.find_child("FieldHair0",true,false).visible, "selected field hair is visible without overlapping other styles")
	check(game.player_snapshot(999)[1].appearance is PackedByteArray, "appearance synchronization stays compact")
	game.queue_free();await process_frame
	if not failed: print("PASS: health pool, modern Garden and saved appearance")
	quit(1 if failed else 0)

