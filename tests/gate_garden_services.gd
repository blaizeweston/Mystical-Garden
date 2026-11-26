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
 game.progress.heart.complete(game.progress,"seed_archive");game.progress.heart.complete(game.progress,"monster_studies")
 check(not game.progress.heart.has("living_archive") and game.stage.heart_stations.living_archive.visible,"Archive stands in a starting Garden without research")
 check(preload("res://tests/support/terrain_case.gd").place_structure(game,"archive") and preload("res://tests/support/terrain_case.gd").place_structure(game,"study"),"researched stations use actual placed structures")
 var view=game.get_node("GardenInteractions")
 var seeds: Array=game.seed_reserve(p).stock
 var before: int=seeds[0]
 var shared: Array=game.InventoryModel.reserve(game,p,"shared").stock
 var shared_before: int=shared[0]
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
  if station=="living_archive":
   var archive=view.station_controls.archive_view
   check(archive.visible and archive.scope.tab_count==2 and archive.categories.tab_count==4,"Archive offers both scopes and all four categories")
   check(archive.facts.current.retired==0 and archive.facts.current.species==[1,24] and archive.facts.current.research[1]==31,"starting collections and research come from current ledgers")
   archive.categories.current_tab=1
   var historical: Dictionary=archive.facts.duplicate(true)
   historical.current.best_clear=12
   archive.present(historical)
   check(archive.grid.get_children().any(func(cell):return cell.text=="At least 12"),"a historical clear is only a lower bound for deepest reached")
   await process_frame;await process_frame
   archive.scroll.grab_focus()
   var down:=InputEventAction.new();down.action="ui_down";down.pressed=true
   archive.scroll.gui_input.emit(down)
   check(archive.scroll.scroll_vertical>0,"directional input scrolls longer Archive categories")
   archive.scope.current_tab=1;archive.categories.current_tab=2
   check(archive.grid.get_children().any(func(cell):return cell.text=="Damage prevented on this character"),"personal protection is labeled by recipient")
  if station=="seed_archive":
   view.station_controls.apply.pressed.emit()
   check(shared[0]==shared_before+1 and seeds[0]==before and game.progress.parts[0]==10-game.reclamation_cost(0),"station button completes shared-only reclamation into the shared Garden")
  p.pos=game.Stage.HEART
  view._process(0.0)
  check(not view.station_panel.visible,"walking away closes "+station)
 if not failed: print("PASS: portal combat locking, local Garden stations, Heart story access and constructed stations in the modern Garden")
 game.queue_free();await process_frame;quit(1 if failed else 0)
