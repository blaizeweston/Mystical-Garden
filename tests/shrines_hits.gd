extends SceneTree
const WorldViewCase = preload("res://tests/support/world_presentation_case.gd")
const WeaponCase = preload("res://tests/support/weapon_attack_case.gd")
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const WeaponActions = preload("res://player_weapon_actions.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const Grafts=preload("res://expedition_grafts.gd")
var failed:=false
func check(ok: bool,message: String):
	if not ok:
		failed=true
		printerr("FAIL: ",message)
func _initialize():
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
	ExpeditionCase.set_membership(game, p, true)
	var tree=game.Classes.connected_tree(0)
	p.character[tree.profile_key]=tree.state(["rootkeeper"])
	p[Grafts.STATE]=Grafts.Ledger.new(1)
	ExpeditionCase.set_world(game, {"encounter_number": game.GRAFT_ROOM})
	ExpeditionCase.set_world(game, {"depth": 4})
	ExpeditionCase.set_world(game, {"map_seed": 91247})
	game.reset_encounter()
	p.pos=game.battlefield.graft
	game._process(.016)
	check(game.enemy_health()>0 and game.graft_altar_open() and game.stage.graft_altar.visible,"eighth encounter shrine appears before combat is cleared")
	check(WorldViewCase.component(game,"map").has_shrine and WorldViewCase.component(game,"map").seen(game.battlefield.graft),"discovered shrine appears on the floor map")
	p.carried_parts[4]=1
	game.send_garden_action(Grafts.request(Grafts.owner_details(p,game.participation.floor()),"reach",game.Items.part_id(4)))
	check(p.carried_parts[4]==0 and Grafts.owner_details(p,game.participation.floor()).revision==1,"shrine accepts one cumulative reinforcement during combat")
	p.secondary=0
	ExpeditionCase.set_world(game, {"encounter_number": game.GRAFT_ROOM*2})
	check(game.graft_altar_open(),"shrine schedule continues across biome boundaries")
	ExpeditionCase.set_world(game, {"encounter_number": 5})
	check(not game.graft_altar_open(),"ordinary floors do not claim to contain a shrine")
	ExpeditionCase.set_world(game, {"encounter_number": game.GRAFT_ROOM})
	var previous_route: int=game.participation.route()
	game.participation.select_route(3)
	check(game.participation.route()==previous_route and game.graft_altar_open(),"unknown route cannot replace an earned shrine floor")
	ExpeditionCase.set_world(game, {"destination": 0})
	ExpeditionCase.set_world(game, {"depth": 1})
	game.enemy_mutations=0
	game.encounter.clear_scouts()
	game.battlefield.configure(0,1)
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[Rect2(-8,-3.2,3,.6)])
	game.tactics.position=Vector3(0,0,6.4)
	game.encounter.set_hp(-1, 100)
	game.tactics.winding_up=false
	p.pos=Vector3(0,0,5.4)
	p.weapon=0;p.secondary=0;p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0);p.frame=0
	var before: Vector3=game.tactics.position
	WeaponCase.start(game,1,p.pos)
	WeaponCase.advance(game,Time.get_ticks_msec()+1000)
	check(game.enemy_health()>0 and game.enemy_health()<100 and game.tactics.position.distance_to(p.pos)>before.distance_to(p.pos)+.2,"successful monster hit applies a small knockback")
	check(game.tactics.position.distance_to(before)<=.36 and game.tactics.stagger_until>Time.get_ticks_msec(),"push remains small and grants a short reaction beat")
	game.tactics.winding_up=true
	game.tactics.strike_at=Time.get_ticks_msec()+500
	p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0)
	WeaponCase.start(game,1,p.pos)
	WeaponCase.advance(game,Time.get_ticks_msec()+1000)
	check(game.tactics.winding_up,"hit reaction does not cancel committed attacks")
	game.tactics.winding_up=false
	game.tactics.position=Vector3(-6.5,0,-3.58)
	p.pos=Vector3(-6.5,0,-4.58)
	p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0)
	WeaponCase.start(game,1,p.pos)
	WeaponCase.advance(game,Time.get_ticks_msec()+1000)
	check(not game.battlefield.occupied(game.tactics.position,.34) and game.tactics.position.z < -3.53,"knockback cannot push a monster through cover")
	# Explicit overlap tests interaction priority independently of floor generation.
	ExpeditionCase.set_world(game, {"destination": 1})
	ExpeditionCase.set_world(game, {"depth": 2})
	ExpeditionCase.set_world(game, {"encounter_number": game.GRAFT_ROOM})
	ExpeditionCase.set_world(game, {"map_seed": 775002413})
	game.reset_encounter()
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 0)
	game.encounter_rewarded=true
	game.wild_item_drops.clear()
	p.loot_pending=false
	game.battlefield.graft=game.battlefield.advance.move_toward(game.battlefield.leader,1.0)
	p.pos=game.battlefield.graft
	game._process(.016)
	check(UIFixture.control(game,"guide").text=="E  Grafting Altar","standing at the shrine shows its prompt")
	game._act(1,false)
	check(UIFixture.control(game,"graft_menu").visible,"standing at the shrine still opens grafting")
	game.ui.close_panels()
	p.pos=game.battlefield.advance
	check(game.at_graft_altar(p),"the generated fixture reproduces overlapping interaction ranges")
	game._process(.016)
	check(UIFixture.control(game,"guide").text!="E  Grafting Altar","the shrine prompt yields to the closer gate")
	game._act(1,false)
	check(game.participation.floor()==game.GRAFT_ROOM+1 and not UIFixture.control(game,"graft_menu").visible,"the gate advances when it is the closer interaction")
	await process_frame
	if not failed: print("PASS: visible mid-combat shrines, grafting, safe hit reactions and overlapping gate interactions")
	quit(1 if failed else 0)
