extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL gate services: ",message)
func _initialize(): call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/gate_services_"+Crypto.new().generate_random_bytes(8).hex_encode()+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1]
 game.encounter.set_hp(-1, 3);game.encounter.clear_scouts();game._process(.016)
 check(game.stage.experimental_garden!=null and game.stage.gate_position().is_finite(),"modern Garden entrance is available")
 check(not game.stage.wild_portal.visible,"Wilds portal locked during combat")
 game.encounter.set_hp(-1, 0);game.encounter.register_scout(game.make_scout(0,Vector3(0,0,5),1));game._process(.016)
 check(not game.stage.wild_portal.visible,"surviving support keeps gate closed")
 game.encounter.set_hp(0, 0);game._process(.016)
 check(game.stage.wild_portal.visible,"portal appears once every enemy is defeated")
 game.encounter.set_hp(-1, 2);game._process(.016);check(not game.stage.wild_portal.visible,"next encounter locks portal again")
 p.pos=game.Stage.HEART;game.act(1,false);check(UIFixture.control(game,"progression_menu").visible,"E opens detailed Heart menu")
 UIFixture.control(game,"progression_view").tabs.current_tab=3;UIFixture.control(game,"progression_view").refresh();check(UIFixture.control(game,"progression_view").care.visible,"Garden care tab is reachable")
 check(not UIFixture.control(game,"guide").text.contains("N ") and not UIFixture.control(game,"detail_label").text.contains("Select donation"),"legacy Heart hotkey clutter removed")
 game.progress.heart.unlock_direct("seed_archive");game.progress.heart.unlock_direct("monster_studies")
 game.progress.heart.unlock_direct("living_archive")
 check(preload("res://tests/support/terrain_case.gd").place_structure(game,"archive") and preload("res://tests/support/terrain_case.gd").place_structure(game,"study"),"researched stations use actual placed structures")
 var view=game.get_node("GardenInteractions")
 var seeds: Array=game.seed_reserve(p).stock
 var before: int=seeds[0]
 game.progress.discoveries[0]=true;game.progress.parts[0]=10
 game.garden_action(1,"care_reclaim_0")
 check(seeds[0]==before and game.progress.parts[0]==10,"Heart cannot reclaim a seed")
 game.ui.close_panels()
 for station in game.Stage.HEART_STATIONS:
  p.pos=game.stage.station_position(station)
  game.ui.set_prompt(view.context_prompt())
  check(UIFixture.control(game,"guide").text.contains(view.station_controls.label(station)),"nearby station offers a matching prompt")
  game.act(1,false);view._process(0.0)
  check(view.station_panel.visible and view.station_controls.station==station,"interact opens "+station)
  if station=="seed_archive":
   view.station_controls.apply.pressed.emit()
   check(game.seed_reserve(p).stock[0]==before+1 and game.progress.parts[0]==10-game.reclamation_cost(0),"station button completes reclamation")
  p.pos=game.Stage.HEART
  view._process(0.0)
  check(not view.station_panel.visible,"walking away closes "+station)
 if not failed: print("PASS: portal combat locking, local Garden stations, Heart story access and constructed stations in the modern Garden")
 game.queue_free();await process_frame;quit(1 if failed else 0)
