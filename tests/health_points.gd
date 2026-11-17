extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const IncomingPlayerHit = preload("res://incoming_player_hit.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const Orb = preload("res://health_orb.gd")
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
 game.progress.path = "res://.godot/health_" + token + ".cfg"
 game.local_character.path = game.progress.path + ".character"
 root.add_child(game)
 game.set_physics_process(false)
 game.set_process(false)
 var p: Dictionary = game.players[1]
 check(PlayerVitals.current_hp(p) == 100 and PlayerVitals.maximum_hp(p) == 100, "player starts with one hundred HP")
 check(Orb.fractions(100,100,0).is_equal_approx(Vector2.ONE), "full health fills the orb")
 ExpeditionCase.set_membership(game, p, true)
 p.pos = game.battlefield.leader
 preload("res://enemy_attack_hits.gd").for_world(game).area(p.pos, 1.0, Time.get_ticks_msec())
 check(PlayerVitals.current_hp(p) == 90 and Orb.fractions(90,100,0).is_equal_approx(Vector2(.9,1)), "one authored enemy damage point removes ten HP")
 IncomingPlayerHit.apply_health_loss(game, 1, PlayerLifecycle.generation(p), 10)
 check(PlayerVitals.current_hp(p) == 80 and Orb.fractions(80,100,0).is_equal_approx(Vector2(.8,1)), "resolved health loss is expressed directly in HP")
 IncomingPlayerHit.apply_health_loss(game, 1, PlayerLifecycle.generation(p), 20)
 check(PlayerVitals.current_hp(p) == 60 and Orb.fractions(60,100,0).is_equal_approx(Vector2(.6,1)), "stronger resolved hits remove their exact HP")
 check(Orb.fractions(80,80,20).is_equal_approx(Vector2(.8,.8)), "sacrificed capacity stays distinct from missing HP")
 p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(90)
 game._process(.016)
 check(game.player_hud.state.hp == 90 and game.player_hud.state.max_hp == 100, "HUD receives resolved HP totals")
 var snapshot: Dictionary = game.player_snapshot(1)[1]
 check(snapshot.hp == 90 and snapshot.max_hp == 100, "multiplayer snapshot preserves HP totals")
 p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(1)
 IncomingPlayerHit.apply_health_loss(game, 1, PlayerLifecycle.generation(p), 1)
 check(not ExpeditionCase.is_wild(p) and not PlayerLifecycle.fallen(p) and PlayerVitals.current_hp(p) == 100, "solo wipe returns to Garden with full health and a cleared fallen state")
 await process_frame
 if not failed: print("PASS: current HP scale, exact damage, health orb capacity, HUD/snapshot projection and recovery")
 quit(1 if failed else 0)
