extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
var failed=false
func check(ok: bool,message: String) -> void:
 if not ok: failed=true;printerr("FAIL gate/crafting: ",message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/gate-crafting-"+str(Time.get_ticks_usec())+".cfg";game.local_character.path=game.progress.path+".character";var viewport:=SubViewport.new();viewport.size=Vector2i(1100,720);root.add_child(viewport);viewport.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1];ExpeditionCase.set_membership(game, p, true);ExpeditionCase.set_world(game, {"destination": 0});game.encounter.set_hp(-1, 0);game.encounter.clear_scouts()
 for floor_number in range(1,37):
  ExpeditionCase.set_world(game, {"encounter_number": floor_number})
  check(game.upgrade_checkpoint_open()==(floor_number%3==0),"cards every third gate "+str(floor_number))
  check(game.extraction_checkpoint_open()==(floor_number%6==0),"extraction every sixth gate "+str(floor_number))
  game.encounter.set_hp(-1, 1);check(not game.upgrade_checkpoint_open() and not game.extraction_checkpoint_open(),"clearing required");game.encounter.set_hp(-1, 0)
 ExpeditionCase.set_world(game, {"encounter_number": 3});p.pos=game.battlefield.advance;game._process(.016)
 check(not UIFixture.control(game,"guide").text.contains("T  Extract"),"third gate does not advertise extraction")
 ExpeditionCase.Transitions.checkpoint(game, 1,false);check(ExpeditionCase.is_wild(p),"third gate cannot bank carried loot")
 ExpeditionCase.set_world(game, {"encounter_number": 6});game._process(.016);check(UIFixture.control(game,"guide").text.contains("T  Extract"),"sixth gate advertises extraction")
 ExpeditionCase.set_world(game, {"destination": 3});check(not game.upgrade_checkpoint_open() and not game.extraction_checkpoint_open(),"Heart finale excluded")
 ExpeditionCase.set_world(game, {"destination": 0});game.encounter.set_hp(-1, 100);ExpeditionCase.set_membership(game, p, false);p.pos=game.stage.gate_position();p.prepared=0;p.prepared_secondary=0;p.prepared_catalyst=0
 game.progress.parts.fill(0);game.seed_reserve(p).parts.fill(0);game.progress.discoveries.fill(true);game.progress.parts[0]=1
 var view=UIFixture.control(game,"loadout_view");view.refresh()
 for slot in 3:
  check(view.slots[slot].get_item_index(1)>=0 and view.slots[slot].get_item_index(2)<0,"only owned material appears despite discovered species")
 var core_choice: int=view.slots[0].get_item_index(1)
 view.slots[0].select(core_choice)
 view.slots[0].item_selected.emit(core_choice)
 check(p.prepared==0 and not view.slot_equip_buttons[0].disabled,"browsing previews a part without reserving it")
 view.slot_equip_buttons[0].pressed.emit()
 check(p.prepared==1 and view.slots[0].get_item_index(1)>=0 and view.slots[1].get_item_index(1)<0 and view.slots[2].get_item_index(1)<0,"Core reserves sole part immediately")
 game.handle_loadout_action(1,p,"loadpart_1_1");check(p.prepared_secondary==0,"authority rejects duplicate reservation")
 view.select_part(0,0);check(view.slots[1].get_item_index(1)>=0,"removal releases material")
 view.select_part(2,1);check(view.slots[0].get_item_index(1)<0 and view.slots[1].get_item_index(1)<0 and p.prepared_catalyst==1,"Catalyst reserves against both earlier slots")
 game.progress.parts[0]=2;view.refresh();view.select_part(0,1)
 check(p.prepared==1 and p.prepared_catalyst==1 and view.slots[1].get_item_index(1)<0,"two copies permit two slots, not three")
 view.select_part(2,0);check(view.slots[1].get_item_index(1)>=0,"removing any slot returns availability")
 check(game.progress.parts[0]==2,"preparation does not consume inventory")
 p.prepared=1;p.prepared_secondary=1;p.prepared_catalyst=1;game.progress.parts[0]=1
 game.show_gate_preparation(1)
 check([p.prepared,p.prepared_secondary,p.prepared_catalyst]==[1,0,0],"saved overbooked plans normalize on opening workbench")
 p.character.loadouts[1]={"weapon":0,"parts":[1,1,1]}
 game.select_class(1,p,1)
 check([p.prepared,p.prepared_secondary,p.prepared_catalyst]==[1,0,0] and p.character.loadouts[1].parts==[1,0,0],"switching classes also normalizes its saved material plan")
 check(view.slots[0].allow_reselect,"Empty can clear a stale selection after inventory changes")
 var class_tree: Button=view.find_children("*","Button",true,false).filter(func(button):return button.text=="Class tree")[0]
 class_tree.pressed.emit()
 var progression: Control=UIFixture.control(game,"progression_view")
 check(UIFixture.control(game,"progression_menu").visible and progression.tabs.current_tab==2 and progression.inspected_class==1,"crafting opens the current class tree")
 var first_node: int=game.Classes.Weaver.TREE.REQUEST_OFFSET
 progression.select_node("class_1_%d"%first_node)
 await process_frame
 await process_frame
 await process_frame
 check(progression.tree_scroll.scroll_vertical>0,"the Class tree opens with its starting nodes in view")
 var learn: Button=progression.learn_button
 check(learn.has_node("ReachingRoots") and not learn.disabled and progression.refund_button.disabled,"the Gate can learn and the refund stays at the Heart")
 var point:=learn.get_global_rect().get_center()
 var hover:=InputEventMouseMotion.new()
 hover.position=point
 hover.global_position=point
 viewport.push_input(hover,true)
 check(learn.get_node("ReachingRoots").highlighted,"hovering Learn grows the shared border roots")
 mouse_click(viewport,point,true)
 check(learn.is_pressed(),"the first mouse-down reaches Learn")
 progression.refresh()
 check(learn.is_pressed(),"a periodic tree refresh preserves the mouse press")
 mouse_click(viewport,point,false)
 check(game.Classes.Weaver.TREE.path(p.character)==["thornbinder"] and learn.disabled,"first click spends exactly one point and immediately updates Learn")
 var saved=game.Character.new()
 saved.path=game.local_character.path
 check(saved.load_profile()==OK and game.Classes.Weaver.TREE.path(saved.data)==["thornbinder"],"the new class node is saved")
 progression.close_button.pressed.emit()
 check(UIFixture.control(game,"loadout_menu").visible and not UIFixture.control(game,"progression_menu").visible and p.prepared==1,"Back returns to the prepared weapon")
 p.pos=game.stage.gate_position()+Vector3(20,0,0)
 game.garden_action(1,"learn_0_%d"%first_node)
 check(p.character.upgrades[0]==0,"the host rejects learning outside the Heart and Gate")
 p.pos=game.stage.gate_position();ExpeditionCase.set_membership(game, p, true)
 game.garden_action(1,"learn_0_%d"%first_node)
 check(p.character.upgrades[0]==0,"the host rejects learning during an expedition")
 viewport.queue_free();await process_frame
 if not failed:print("PASS: independent 3/6 gate rules, clearing/Heart restrictions, honest extraction HUD, all-direction slot budgets, stack quantities, first-click class learning and authoritative rejection")
 quit(1 if failed else 0)

func mouse_click(viewport: SubViewport,point: Vector2,down: bool) -> void:
 var event:=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_LEFT
 event.position=point
 event.global_position=point
 event.pressed=down
 viewport.push_input(event,true)
