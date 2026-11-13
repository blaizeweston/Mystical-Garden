extends SceneTree
const Hud = preload("res://root_ui.gd")
var failed := false
func check(ok: bool, message: String):
	if not ok:
		failed = true
		printerr("FAIL: ", message)
func _initialize():
	preload("res://combat_balance_preview.gd").enabled = false
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
	check(p.hp == 10 and p.max_hp == 10, "player starts with ten health points")
	for i in 5:
		check(Hud.heart_state(p.hp,10,i) == 0, "starting hearts are full")
	p.wild = true
	p.pos = game.battlefield.leader
	game.hit_players(p.pos, 1.0, Time.get_ticks_msec())
	check(p.hp == 9 and Hud.heart_state(p.hp,10,4) == 1, "basic enemy hit removes one point and displays a half heart")
	for i in 4:
		check(Hud.heart_state(p.hp,10,i) == 0, "basic damage preserves the other full hearts")
	game.damage_player(1,p,1)
	check(p.hp == 8 and Hud.heart_state(p.hp,10,4) == 2, "second point empties the same heart")
	game.damage_player(1,p,2)
	check(p.hp == 6 and Hud.heart_state(p.hp,10,3) == 2, "stronger hits can remove a full heart")
	check(Hud.heart_state(8,8,4) == 3, "lost capacity retains its separate texture")
	var small := Hud.half_heart_pulse(0.6)
	var large := Hud.half_heart_pulse(0.2)
	check(large > small and small >= 1.0 and large <= 1.101, "half-heart pulse changes scale without changing health")
	p.hp = 9
	game._process(.016)
	check(game.player_hud.state.hp == 9 and game.player_hud.state.max_hp == 10, "HUD receives point totals")
	var snapshot: Dictionary = game.player_snapshot(1)[1]
	check(snapshot.hp == 9 and snapshot.max_hp == 10, "multiplayer snapshot preserves health totals")
	p.hp = 1
	game.damage_player(1,p,1)
	check(not p.wild and not p.fallen and p.hp == 10, "solo wipe returns to Garden with full health and a cleared fallen state")
	await process_frame
	if not failed: print("PASS: ten-point health, half-heart damage, pulse, stronger hits and recovery")
	quit(1 if failed else 0)
