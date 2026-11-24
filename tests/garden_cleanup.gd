extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
var failed=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL Garden cleanup: ",message)
func frames(count: int=4) -> void:
 for i in count: await process_frame
func bottom(panel: Node) -> bool:
 var bar=panel.tree_scroll.get_v_scroll_bar()
 return bar.max_value>bar.page and absi(panel.tree_scroll.scroll_vertical-roundi(bar.max_value-bar.page))<=1
func capture(game: Node,name: String) -> void:
 if DisplayServer.get_name()=="headless": return
 await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png("res://.godot/garden-cleanup-"+name+".png")
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/garden-cleanup-"+str(Time.get_ticks_usec())+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_physics_process(false)
 var g=game.progress;var p: Dictionary=game.players[1];var panel=UIFixture.control(game,"progression_view")
 p.pos=game.Stage.HEART;g.knowledge=400;g.parts.fill(60)
 var before=g.heart.serialize();game.send_garden_action("expand_plot")
 check(g.heart.serialize()==before and g.plots.size()==3,"retired bed shortcut cannot start or pay for research")
 game.send_garden_action("heart_start_plot_4")
 check(g.heart.has("plot_4") and g.plots.size()==3,"explicit Knowledge-node research still works")
 check(preload("res://tests/support/terrain_case.gd").place_structure(game,"bed"),"Knowledge unlock permits a real placed bed");check(g.plots.size()==4,"bed research completion expands Garden")
 # Simulate an actual older save rather than rebuilding its retired systems in memory.
 g.campaign.cleared.fill(true)
 check(g.save_garden()==OK,"create a populated disposable Garden")
 var old:=ConfigFile.new()
 check(old.load(g.path)==OK,"load fixture data")
 old.set_value("campaign","offshoot_0",2)
 old.set_value("campaign","offshoot_bed_0",0)
 old.set_value("campaign","offshoot_progress_0",3)
 old.set_value("campaign","ending",2)
 var research: Dictionary=old.get_value("heart","state")
 research.version=2
 research.paid=["plot_4","perfect_recollection"]
 research.active="perfect_recollection"
 research.work={"perfect_recollection":120.0}
 research.spent+=12
 old.set_value("heart","state",research)
 var knowledge: int=g.knowledge
 var valid_spending: int=g.heart.spent
 check(old.save(g.path)==OK and g.load_garden()==OK,"load historical records")
 check(g.knowledge==knowledge and g.heart.spent==valid_spending and g.heart.has("plot_4"),
  "refund retired research while preserving paid bed research and lifetime Knowledge")
 for action in ["nurture","harvest_offshoot","awaken"]:game.send_garden_action(action)
 check(game.Progress.decode_plots(g.plot_snapshot()).all(func(b):return not b.has("offshoot")),"legacy history reserves no bed")
 p.pos=game.Stage.PLOTS[0];game.show_planting_picker(1,0)
 check(UIFixture.control(game,"planting_menu").visible,"a previously reserved bed accepts normal planting")
 game.ui.close_panels();g.stock[0]=1;game.garden_action(1,"plant_at_0_0")
 check(g.plots[0].species==0,"normal seeds can occupy former offshoot beds")
 var packet=game.campaign_snapshot()
 check(packet[2]==0 and packet[3]==0 and packet[4]==0 and packet[5]==0 and packet[17]==0,"reserved wire fields remain zero")
 var written:=ConfigFile.new()
 check(g.save_garden()==OK and written.load(g.path)==OK,"modern save succeeds after planting")
 check(not written.has_section_key("campaign","ending") and not written.has_section_key("campaign","offshoot_bed_0")
  and not written.has_section_key("campaign","offshoot_progress_0") and not written.has_section_key("campaign","offshoot_0")
  and not written.get_value("heart","state").has("paid") and not written.get_value("heart","state").unlocked.has("perfect_recollection"),"rewritten saves omit retired fields and payments")
 var restored=game.Progress.new();restored.path=g.path
 check(restored.load_garden()==OK and restored.plots[0].species==0 and restored.heart.spent==valid_spending and restored.campaign.cleared.all(func(x):return x),
  "reload preserves the planted bed and guardian progress without repeating the refund")
 p.pos=game.Stage.HEART;game.open_heart_tree();await frames()
 check(bottom(panel),"Heart opens at the actual bottom after visible layout")
 check(not panel.nodes.any(func(n):return n.id=="heart_perfect_recollection") and panel.nodes.size()==preload("res://heart_catalog.gd").DEFINITIONS.filter(func(n):return preload("res://heart_catalog.gd").enabled(n.id)).size(),"active tree hides deferred final node without renumbering technologies")
 var root_node: Dictionary=panel.tree.node_at("heart_heart")
 var view=Rect2(Vector2(panel.tree_scroll.scroll_horizontal,panel.tree_scroll.scroll_vertical),panel.tree_scroll.size)
 check(view.has_point(root_node.position),"starting Heart root is visible and centered")
 await capture(game,"knowledge")
 panel.tree_scroll.scroll_vertical=0;panel.refresh();await frames()
 check(panel.tree_scroll.scroll_vertical==0,"research refreshes do not fight manual scrolling")
 panel.tabs.current_tab=3;panel.refresh();await frames()
 check(panel.care.visible and panel.care.stories!=null,"Heart tab is a read-only Garden stories recap")
 var personal: Array=game.seed_reserve(p).parts;personal[1]=2
 var shared_before: int=game.progress.part_count(1)
 game.garden_action(1,"care_donate_1")
 check(personal[1]==2 and game.progress.part_count(1)==shared_before,"retired Garden care donation cannot move items")
 var item: String=game.Items.part_id(1)
 game.handle_inventory_action(1,p,JSON.stringify({"operation":"transfer","source":"stash","target":"shared","item":item,"quantity":2}))
 check(personal[1]==0 and game.progress.part_count(1)==shared_before+2,"inventory still transfers a selected stack to shared storage")
 game.handle_inventory_action(1,p,JSON.stringify({"operation":"transfer","source":"shared","target":"stash","item":item,"quantity":2}))
 check(personal[1]==2 and game.progress.part_count(1)==shared_before,"inventory transfer back to personal stash remains intact")
 await capture(game,"care")
 panel.tabs.current_tab=1;await frames();check(bottom(panel),"switching back to Knowledge starts at its base")
 game.ui.close_panels();panel.tree_scroll.scroll_vertical=0;game.open_heart_tree();await frames();check(bottom(panel),"reopening the same Knowledge tab also resets to the base")
 game.queue_free();await process_frame
 if not failed:print("PASS: Knowledge-only bed expansion, retired offshoot/finale routes, released legacy beds, save preservation, clean care tabs and bottom-anchored Knowledge view")
 quit(1 if failed else 0)
