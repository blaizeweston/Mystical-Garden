extends SceneTree
var failed=false
func check(ok: bool,message: String) -> void:
 if not ok: failed=true;printerr("FAIL gate/crafting: ",message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/gate-crafting-"+str(Time.get_ticks_usec())+".cfg";game.local_character.path=game.progress.path+".character";var viewport:=SubViewport.new();viewport.size=Vector2i(1100,720);root.add_child(viewport);viewport.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1];p.wild=true;game.destination=0;game.enemy_hp=0;game.scouts.clear()
 for floor_number in range(1,37):
  game.encounter_number=floor_number
  check(game.upgrade_checkpoint_open()==(floor_number%3==0),"cards every third gate "+str(floor_number))
  check(game.extraction_checkpoint_open()==(floor_number%6==0),"extraction every sixth gate "+str(floor_number))
  game.enemy_hp=1;check(not game.upgrade_checkpoint_open() and not game.extraction_checkpoint_open(),"clearing required");game.enemy_hp=0
 game.encounter_number=3;p.pos=game.battlefield.advance;game._process(.016)
 check(not game.guide.text.contains("T  Extract"),"third gate does not advertise extraction")
 game.use_checkpoint(1,false);check(p.wild,"third gate cannot bank carried loot")
 game.encounter_number=6;game._process(.016);check(game.guide.text.contains("T  Extract"),"sixth gate advertises extraction")
 game.destination=3;check(not game.upgrade_checkpoint_open() and not game.extraction_checkpoint_open(),"Heart finale excluded")
 game.destination=0;game.enemy_hp=100;p.wild=false;p.pos=game.Stage.GATE;p.prepared=0;p.prepared_secondary=0;p.prepared_catalyst=0
 game.progress.parts.fill(0);game.seed_reserve(p).parts.fill(0);game.progress.discoveries.fill(true);game.progress.parts[0]=1
 var view=game.loadout_view;view.refresh()
 for slot in 3:
  check(view.slots[slot].get_item_index(1)>=0 and view.slots[slot].get_item_index(2)<0,"only owned material appears despite discovered species")
 view.slots[0].item_selected.emit(view.slots[0].get_item_index(1))
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
 var progression: Control=game.progression_view
 check(game.progression_menu.visible and progression.tabs.current_tab==2 and progression.inspected_class==1,"crafting opens the current class tree")
 var first_node: int=game.Classes.Warden.OFFSET
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
 check(p.character.upgrades[1]==1<<first_node and learn.disabled,"first click spends exactly one point and immediately updates Learn")
 var saved=game.Character.new()
 saved.path=game.local_character.path
 check(saved.load_profile()==OK and saved.data.upgrades[1]==p.character.upgrades[1],"the new class node is saved")
 progression.close_button.pressed.emit()
 check(game.loadout_menu.visible and not game.progression_menu.visible and p.prepared==1,"Back returns to the prepared weapon")
 p.pos=game.Stage.GATE+Vector3(20,0,0)
 game.garden_action(1,"learn_0_%d"%first_node)
 check(p.character.upgrades[0]==0,"the host rejects learning outside the Heart and Gate")
 p.pos=game.Stage.GATE;p.wild=true
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
