extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const SessionCase = preload("res://tests/support/session_case.gd")
var game: Node
var role: String
var base: String
var failed=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL Garden cleanup co-op ",role,": ",message)
func mark(key: String) -> void:
 var file=FileAccess.open(base+"-"+key,FileAccess.WRITE);file.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+"-"+key)
func until(predicate: Callable) -> bool:
 var deadline=Time.get_ticks_msec()+18000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func bottom() -> bool:
 var panel=UIFixture.control(game,"progression_view");var bar=panel.tree_scroll.get_v_scroll_bar()
 return panel.is_visible_in_tree() and bar.max_value>bar.page and absi(panel.tree_scroll.scroll_vertical-roundi(bar.max_value-bar.page))<=1
func _initialize() -> void:call_deferred("run")
func run() -> void:
 role=OS.get_cmdline_user_args()[0];base="res://.godot/garden-clean-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role+".cfg";game.local_character.path=game.progress.path+".character";game.guest_character.path=game.progress.path+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 game.queue_free();await process_frame
 if not failed:print("PASS: Garden cleanup co-op ",role," remote bottom anchoring, hidden legacy state, retired command rejection and shared Knowledge-only beds")
 quit(1 if failed else 0)
func host_run() -> void:
 check(game.session_world.host()==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return SessionCase.Session.ready_for(p))):
  check(false,"guest registers");return
 var g=game.progress
 for p in game.players.values():p.pos=game.Stage.HEART
 g.knowledge=100;g.parts.fill(20);g.campaign.cleared.fill(true)
 var before=g.heart.serialize();var parts=g.parts.duplicate()
 check(await until(func():return marked("retired")),"guest checks retired actions")
 check(g.heart.serialize()==before and g.parts==parts and g.plots.size()==3,"remote legacy requests cannot spend Knowledge, reserve beds or grant parts")
 game.garden_action(1,"heart_confirm:"+JSON.stringify({"id":"plot_4","plan":{}}));g.heart.add_work(g,g.heart.duration("plot_4"));check(preload("res://tests/support/terrain_case.gd").place_structure(game,"bed"),"Knowledge unlock permits a real placed bed")
 check(g.plots.size()==4,"host still researches shared bed through tree")
 mark("research")
 check(await until(func():return marked("verified")),"guest verifies expanded bed and tree behavior")
 var guest: int=game.players.keys().filter(func(peer):return peer!=1)[0]
 g.heart.unlock_direct("monster_studies");check(preload("res://tests/support/terrain_case.gd").place_structure(game,"study"),"build a real Offering Altar")
 var trophy: int=game.Parts.HOOK
 game.seed_reserve(game.players[guest]).parts[trophy]=1
 var knowledge: int=g.knowledge
 mark("trophy_ready")
 if not await until(func():return marked("remote_rejected")):check(false,"guest tests offering from the Heart");return
 check(game.seed_reserve(game.players[guest]).parts[trophy]==1 and g.knowledge==knowledge,"remote offering from the Heart consumes nothing")
 game.players[guest].pos=game.stage.station_position("monster_studies")
 if not await until(func():return marked("offered")):check(false,"guest submits a station offering");return
 check(game.seed_reserve(game.players[guest]).parts[trophy]==0 and g.knowledge==knowledge+4,"guest station offering commits on host")
 mark("done");check(await until(func():return game.players.size()==1),"guest disconnects normally");game.session_world.leave("Garden cleanup fixture")
func guest_run() -> void:
 game.guest_character.save_profile();check(game.session_world.join()==OK,"guest joins")
 if not await until(func():return game.network_session.role()=="Guest" and game.guest_replication.has_details()):check(false,"guest accepted");return
 var id=game.multiplayer.get_unique_id();var panel=UIFixture.control(game,"progression_view")
 check(await until(func():return game.guest_replication.garden_progress().size()>13 and game.guest_replication.garden_progress()[6]==100 and game.players[id].pos.distance_to(game.Stage.HEART)<1),"Garden state arrives")
 game.send_action(false)
 check(await until(func():return panel.tabs.current_tab==1 and bottom()),"remote E opens the tree at its base")
 check(not panel.nodes.any(func(n):return n.id=="heart_perfect_recollection"),"guest sees no deferred ending route")
 check(game.guest_replication.campaign()[5]==0 and game.guest_replication.campaign()[17]==0 and game.Progress.decode_plots(game.guest_replication.garden_progress()[12]).all(func(b):return not b.has("offshoot")),"guest receives no blocking legacy offshoot or ending state")
 for action in ["expand_plot","nurture","harvest_offshoot","awaken"]:game.send_garden_action(action)
 await create_timer(.4).timeout;mark("retired")
 panel.tree_scroll.scroll_vertical=0
 check(await until(func():return marked("research") and game.Progress.decode_plots(game.guest_replication.garden_progress()[12]).size()==4),"host's Knowledge-tree expansion synchronizes")
 await create_timer(.3).timeout
 check(panel.tree_scroll.scroll_vertical==0,"research synchronization preserves manual scroll")
 panel.tabs.current_tab=3;panel.refresh();check(panel.care.stories!=null,"guest Heart shows read-only Garden stories")
 panel.tabs.current_tab=1;check(await until(bottom),"returning to Knowledge resets to bottom")
 mark("verified")
 if not await until(func():return marked("trophy_ready") and game.heart_state().unlocked.has("monster_studies")):check(false,"offering unlock arrives");return
 game.send_garden_action("care_offer_%d"%game.Parts.HOOK)
 if not await until(func():return game.status.contains("appropriate Garden station")):check(false,"remote offering rejected at Heart");return
 mark("remote_rejected");game.ui.close_panels()
 if not await until(func():return game.at_garden_station(game.players[id],"monster_studies")):check(false,"guest is near the Offering Altar");return
 game.send_action(false)
 var view=game.get_node("GardenInteractions")
 if not await until(func():return view.station_panel.visible and view.station_controls.station=="monster_studies" and not view.station_controls.apply.disabled):check(false,"guest opens local Offering Altar");return
 view.station_controls.apply.pressed.emit()
 if not await until(func():return game.status.contains("Offered")):check(false,"guest receives offering result");return
 mark("offered")
 check(await until(func():return marked("done")),"host finishes");game.session_world.leave("Garden cleanup fixture")
