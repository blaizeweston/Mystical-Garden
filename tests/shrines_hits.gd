extends SceneTree
var failed:=false
func check(ok: bool,message: String):
	if not ok:
		failed=true
		printerr("FAIL: ",message)
func _initialize():
	preload("res://combat_balance_preview.gd").enabled = false
	call_deferred("run")
func run():
	var game=load("res://world.tscn").instantiate()
	var token:=Crypto.new().generate_random_bytes(8).hex_encode()
	game.progress.path="res://.godot/shrines_"+token+".cfg"
	game.local_character.path=game.progress.path+".character"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	var p: Dictionary=game.players[1]
	p.wild=true
	game.encounter_number=game.GRAFT_ROOM
	game.depth=4
	game.map_seed=91247
	game.reset_encounter()
	p.pos=game.battlefield.graft
	game._process(.016)
	check(game.enemy_hp>0 and game.graft_altar_open() and game.stage.graft_altar.visible,"eighth encounter shrine appears before combat is cleared")
	check(game.exploration.has_shrine and game.exploration.seen(game.battlefield.graft),"discovered shrine appears on the floor map")
	p.carried_parts[4]=1
	p.graft_choice=4
	game.attempt_graft(1,p)
	check(p.carried_parts[4]==0,"shrine accepts a graft attempt during combat")
	p.secondary=0
	p.graft_part=0
	game.encounter_number=game.GRAFT_ROOM*2
	check(game.graft_altar_open(),"shrine schedule continues across biome boundaries")
	game.encounter_number=5
	check(not game.graft_altar_open(),"ordinary floors do not claim to contain a shrine")
	game.encounter_number=game.GRAFT_ROOM
	game.destination=3
	check(not game.graft_altar_open(),"story finale does not spawn a normal shrine")
	game.destination=0
	game.depth=1
	game.enemy_mutations=0
	game.scouts.clear()
	game.battlefield.configure(0,1)
	game.enemy_pos=Vector3(0,0,6.4)
	game.enemy_hp=5
	game.enemy_winding_up=false
	p.pos=Vector3(0,0,5.4)
	p.weapon=0;p.secondary=0;p.power=0;p.strike_at=0;p.frame=0
	var before: Vector3=game.enemy_pos
	game.strike_enemy(1,p,p.pos)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	check(game.enemy_hp==4 and game.enemy_pos.distance_to(p.pos)>before.distance_to(p.pos)+.2,"successful monster hit applies a small knockback")
	check(game.enemy_pos.distance_to(before)<=.36 and game.enemy_stagger_until>Time.get_ticks_msec(),"push remains small and grants a short reaction beat")
	game.enemy_winding_up=true
	game.enemy_strike_at=Time.get_ticks_msec()+500
	p.strike_at=0
	game.strike_enemy(1,p,p.pos)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	check(game.enemy_winding_up,"hit reaction does not cancel committed attacks")
	game.enemy_winding_up=false
	game.enemy_pos=Vector3(-6.5,0,-3.58)
	p.pos=Vector3(-6.5,0,-4.58)
	p.strike_at=0
	game.strike_enemy(1,p,p.pos)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	check(not game.battlefield.occupied(game.enemy_pos,.34) and game.enemy_pos.z < -3.53,"knockback cannot push a monster through cover")
	game.enemy_hp=5
	game.enemy_pos=Vector3(0,0,5.8)
	p.pos=Vector3(0,0,4)
	p.weapon=0
	p.graft_part=4
	p.strike_at=0
	before=game.enemy_pos
	game.strike_enemy(1,p,p.pos)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	check(game.enemy_pos.distance_to(p.pos)<before.distance_to(p.pos),"Briar Hook pull is preserved instead of being cancelled by knockback")
	# This generated floor places the two interaction areas on top of each other.
	game.destination=1
	game.depth=2
	game.encounter_number=game.GRAFT_ROOM
	game.map_seed=775002413
	game.reset_encounter()
	game.scouts.clear()
	game.enemy_hp=0
	game.encounter_rewarded=true
	game.wild_item_drops.clear()
	p.loot_pending=false
	p.pos=game.battlefield.graft
	game._process(.016)
	check(game.guide.text=="E  Graft","standing at the shrine shows its prompt")
	game._act(1,false)
	check(game.graft_menu.visible,"standing at the shrine still opens grafting")
	game.toggle_overlay(null)
	p.pos=game.battlefield.advance
	check(game.at_graft_altar(p),"the generated fixture reproduces overlapping interaction ranges")
	game._process(.016)
	check(game.guide.text!="E  Graft","the shrine prompt yields to the closer gate")
	game._act(1,false)
	check(game.encounter_number==game.GRAFT_ROOM+1 and not game.graft_menu.visible,"the gate advances when it is the closer interaction")
	await process_frame
	if not failed: print("PASS: visible mid-combat shrines, grafting, safe hit reactions and overlapping gate interactions")
	quit(1 if failed else 0)
