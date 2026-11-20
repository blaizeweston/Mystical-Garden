extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const SessionCase = preload("res://tests/support/session_case.gd")
var game: Node
var role: String
var base: String
var failed=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL crafting co-op ",role,": ",message)
func mark(key: String) -> void:
 var file=FileAccess.open(base+"-"+key,FileAccess.WRITE);file.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+"-"+key)
func until(predicate: Callable) -> bool:
 var deadline=Time.get_ticks_msec()+18000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func _initialize() -> void:call_deferred("run")
func run() -> void:
 role=OS.get_cmdline_user_args()[0];base="res://.godot/crafting-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role+".cfg";game.local_character.path=game.progress.path+".character";game.guest_character.path=game.progress.path+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 game.queue_free();await process_frame
 if not failed:print("PASS: crafting availability co-op ",role," immediate slot filtering, authoritative reservations, release/reselect and live stack counts")
 quit(1 if failed else 0)
func host_run() -> void:
 check(game.session_world.host()==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return SessionCase.Session.ready_for(p))):
  check(false,"guest registers: "+game.status+" / peers "+str(game.players.keys()));return
 var id=int(game.players.keys()[1]);var p: Dictionary=game.players[id]
 game.progress.parts.fill(0);game.seed_reserve(p).parts.fill(0);game.progress.parts[0]=1
 for player in game.players.values():player.pos=game.stage.gate_position();player.prepared=0;player.prepared_secondary=0;player.prepared_catalyst=0
 check(await until(func():return p.prepared==1 and marked("first")),"guest assigns first copy")
 check(await until(func():return marked("forged")),"guest sends duplicate request")
 check(p.prepared_secondary==0,"host rejects a second reservation of sole copy")
 mark("checked")
 check(await until(func():return p.prepared==0 and p.prepared_catalyst==1 and marked("moved")),"removing Core releases material for Catalyst")
 game.progress.parts[0]=2
 check(await until(func():return p.prepared==1 and p.prepared_catalyst==1 and marked("two")),"second copy permits both slots")
 check(p.prepared_secondary==0 and game.progress.parts[0]==2,"unselected slot empty and no materials consumed")
 var host: Dictionary=game.players[1]
 check(game.stored_counts(host)[1]==0,"guest reserves both copies against host")
 game.handle_loadout_action(1,host,"loadpart_0_1");check(host.prepared==0,"host cannot steal guest reservation");mark("host-checked")
 check(await until(func():return p.prepared==0 and marked("released")),"guest releases a shared copy")
 game.handle_loadout_action(1,host,"loadpart_0_1");check(host.prepared==1,"host claims released copy")
 check(await until(func():return marked("host-hidden")),"guest filters host-claimed copy")
 game.handle_loadout_action(1,host,"loadpart_0_0");game.seed_reserve(p).stock[0]=3
 check(await until(func():return marked("seed-shared")),"guest shares seeds")
 check(game.InventoryModel.counts(game,host,"shared").get(game.Items.seed_id(0),0)==2,"host sees shared seed stack")
 game.send_inventory_action("transfer","shared","stash",game.Items.seed_id(0),2)
 check(await until(func():return marked("seed-removed")),"guest sees host withdrawal")
 mark("done");check(await until(func():return game.players.size()==1),"guest disconnects");game.session_world.leave("Crafting fixture complete")
func guest_run() -> void:
 game.guest_character.save_profile();check(game.session_world.join()==OK,"guest joins")
 if not await until(func():return game.network_session.role()=="Guest" and game.guest_replication.has_details()):check(false,"guest accepted: "+game.status+" / "+game.network_session.role());return
 var id=game.multiplayer.get_unique_id();var view=UIFixture.control(game,"loadout_view")
 var cached_bag: Dictionary=game.players[id].get("bag",{})
 var original_bag:=JSON.stringify(cached_bag)
 var display_bag: Dictionary=game.inventory_ui_data()
 check(not display_bag.is_empty() and display_bag.equipment.size()==3,"inventory read port supplies an equipped-slot projection")
 display_bag.equipment.clear();display_bag.stash.clear();display_bag.shared.clear()
 check(JSON.stringify(cached_bag)==original_bag,"mutating detached inventory output cannot alter replicated guest state")
 var original_counts: Array=game.players[id].get("stored_parts",[]).duplicate()
 var original_guest_xp: Array=game.guest_character.data.xp.duplicate()
 var original_actor_profile:=JSON.stringify(game.players[id].get("character",{}))
 var display_loadout: Dictionary=game.loadout_ui_data()
 display_loadout.counts.clear();display_loadout.profile.xp.clear()
 check(game.players[id].get("stored_parts",[])==original_counts and game.guest_character.data.xp==original_guest_xp and JSON.stringify(game.players[id].get("character",{}))==original_actor_profile,
  "loadout read results cannot edit reservations or permanent XP")
 var original_stats:=JSON.stringify(game.players[id].get("weapon_stats",{}))
 var display_summary: Dictionary=game.run_summary_ui_data()
 display_summary.stats.clear();display_summary.copies.clear()
 check(JSON.stringify(game.players[id].get("weapon_stats",{}))==original_stats,"Tab read results cannot edit reliable weapon details")
 check(await until(func():return game.players[id].pos.distance_to(game.stage.gate_position())<1 and game.players[id].get("stored_parts",[]).size()>1 and int(game.players[id].stored_parts[1])==1),"owned counts arrive")
 game.open_gate_preparation();view.refresh()
 check(view.slots[1].get_item_index(1)>=0,"sole part initially available")
 view.select_part(0,1)
 check(view.slots[1].get_item_index(1)<0 and view.slots[2].get_item_index(1)<0,"filter updates before network acknowledgment")
 check(await until(func():return game.players[id].prepared==1),"selection acknowledged");mark("first")
 game.request_garden_action.rpc_id(1,"loadpart_1_1");await create_timer(.3).timeout;mark("forged")
 check(await until(func():return marked("checked")),"authority confirms duplicate rejection")
 view.select_part(0,0)
 check(view.slots[1].get_item_index(1)>=0 and view.slots[2].get_item_index(1)>=0,"local removal restores other options immediately")
 view.select_part(2,1)
 check(view.slots[0].get_item_index(1)<0,"later slot reserves against first")
 check(await until(func():return game.players[id].prepared==0 and game.players[id].prepared_catalyst==1),"rapid ordered edits acknowledged");mark("moved")
 check(await until(func():return int(game.players[id].stored_parts[1])==2),"stock changes synchronize")
 view.refresh();check(view.slots[0].get_item_index(1)>=0,"second copy becomes available")
 view.select_part(0,1);check(view.slots[1].get_item_index(1)<0,"third slot cannot overbook two copies")
 check(await until(func():return game.players[id].prepared==1 and game.players[id].prepared_catalyst==1),"two reservations synchronize");mark("two")
 check(await until(func():return marked("host-checked")),"host respects guest claims")
 view.select_part(0,0);check(await until(func():return game.players[id].prepared==0),"Core releases");mark("released")
 check(await until(func():return int(game.players[id].stored_parts[1])==1),"other player's claim updates available counts")
 view.refresh();check(view.slots[0].get_item_index(1)<0,"host-selected last copy disappears from guest dropdown");mark("host-hidden")
 check(await until(func():return game.inventory_ui_data().get("stash",[]).any(func(s):return s.item==game.Items.seed_id(0) and s.quantity==3)),"seed stack arrives")
 game.send_inventory_action("transfer","stash","shared",game.Items.seed_id(0),2)
 check(await until(func():return game.inventory_ui_data().get("shared",[]).any(func(s):return s.item==game.Items.seed_id(0) and s.quantity==2)),"guest sees seed sharing acknowledged");mark("seed-shared")
 check(await until(func():return not game.inventory_ui_data().get("shared",[]).any(func(s):return s.item==game.Items.seed_id(0))),"host withdrawal updates guest inventory");mark("seed-removed")
 check(await until(func():return marked("done")),"host finishes");game.session_world.leave("Crafting fixture complete")
