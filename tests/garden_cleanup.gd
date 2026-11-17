extends SceneTree

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
 var g=game.progress;var p: Dictionary=game.players[1];var panel=game.progression_view
 p.pos=game.Stage.HEART;g.knowledge=400;g.parts.fill(60)
 var before=g.heart.serialize();game.send_garden_action("expand_plot")
 check(g.heart.serialize()==before and g.plots.size()==3,"retired bed shortcut cannot start or pay for research")
 game.send_garden_action("heart_confirm:"+JSON.stringify({"id":"plot_4","plan":{}}))
 check(g.heart.active=="plot_4" and g.plots.size()==3,"explicit Knowledge-node research still works")
 g.advance_research(1);check(g.plots.size()==4,"bed research completion expands Garden")
 var fresh=game.Campaign.new();fresh.record_clear(0)
 check(fresh.offshoots==[game.Campaign.DORMANT,game.Campaign.DORMANT,game.Campaign.DORMANT],"new guardian clears do not create old offshoot choices")
 # A pre-cleanup save retains its history but does not reserve beds or alter the living Garden.
 g.campaign.cleared.fill(true);g.campaign.offshoots.assign([game.Campaign.PENDING,game.Campaign.GROWING,game.Campaign.MATURE]);g.campaign.offshoot_beds.assign([-1,0,1]);g.campaign.offshoot_progress.assign([0,1,3]);g.campaign.ending=game.Campaign.CORRUPTION
 var old=g.campaign.offshoots.duplicate();var beds=g.campaign.offshoot_beds.duplicate();var growth=g.campaign.offshoot_progress.duplicate();var barbs: int=g.heartwood_barbs
 for action in ["nurture","harvest_offshoot","awaken"]:game.send_garden_action(action)
 g.campaign.advance_growth();game.complete_finale(1)
 check(g.campaign.offshoots==old and g.campaign.offshoot_beds==beds and g.campaign.offshoot_progress==growth and g.heartwood_barbs==barbs and g.campaign.ending==game.Campaign.CORRUPTION,"retired actions and growth cannot mutate legacy history or grant rewards")
 check(g.offshoot_in_bed(0)==-1 and game.Progress.decode_plots(g.plot_snapshot()).all(func(b):return b.offshoot==-1),"old offshoot beds are released in authority and snapshots")
 p.pos=game.Stage.PLOTS[0];game.show_planting_picker(1,0)
 check(game.planting_menu.visible,"a previously reserved bed accepts normal planting")
 game.toggle_overlay(null);g.stock[0]=1;game.garden_action(1,"plant_at_0_0")
 check(g.plots[0].species==0,"normal seeds can occupy former offshoot beds")
 g.heart.unlock_direct("perfect_recollection");game.consider_recollection()
 check(not g.finale_available() and not game.recollection_menu.visible and not ExpeditionCase.is_wild(p),"legacy restoration cannot trigger the deferred finale")
 check(not g.heart.requirements(g,"perfect_recollection").is_empty(),"deferred research cannot be purchased")
 var packet=game.campaign_snapshot();check(packet[2]==0 and packet[3]==0 and packet[4]==0 and packet[5]==game.Campaign.UNFINISHED and packet[17]==0,"public Garden state hides deferred ending choices")
 g.save_garden();var restored=game.Progress.new();restored.path=g.path;restored.load_garden()
 check(restored.campaign.offshoots==old and restored.campaign.offshoot_beds==beds and restored.campaign.offshoot_progress==growth and restored.campaign.ending==game.Campaign.CORRUPTION,"legacy metadata survives saving and reloading")
 check(restored.plots[0].species==0 and restored.offshoot_in_bed(0)==-1,"new planting persists independently of legacy records")
 var paused=game.Progress.new();paused.path=g.path+".paused"
 paused.heart.paid.append("perfect_recollection");paused.heart.active="perfect_recollection";paused.heart.work.perfect_recollection=120.0;paused.heart.spent=12;paused.save_garden()
 var loaded=game.Progress.new();loaded.path=paused.path;loaded.load_garden()
 check(loaded.heart.active.is_empty() and loaded.heart.paid.has("perfect_recollection") and loaded.heart.work.perfect_recollection==120.0 and loaded.heart.spent==12,"deferred in-progress research is paused without deleting paid work")
 check(g.heart.phase(g)==4,"old final restoration no longer presents an awakened ending phase")
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
 game.toggle_overlay(null);panel.tree_scroll.scroll_vertical=0;game.open_heart_tree();await frames();check(bottom(panel),"reopening the same Knowledge tab also resets to the base")
 game.queue_free();await process_frame
 if not failed:print("PASS: Knowledge-only bed expansion, retired offshoot/finale routes, released legacy beds, save preservation, clean care tabs and bottom-anchored Knowledge view")
 quit(1 if failed else 0)
