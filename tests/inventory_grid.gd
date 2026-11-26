extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const Items=preload("res://item_catalog.gd")
const Model=preload("res://inventory_model.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL inventory: ",message)
func _initialize(): call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate()
 var token=Crypto.new().generate_random_bytes(8).hex_encode()
 game.progress.path="res://.godot/inventory_test_"+token+".cfg"
 game.local_character.path=game.progress.path+".character"
 root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var g=game.progress;var p: Dictionary=game.players[1];var reserve: Dictionary=game.seed_reserve(p)
 check(Items.all().size()==game.Seeds.DEFINITIONS.size()+game.Parts.DEFINITIONS.size()+1,"all seeds, parts and both mystery-seed qualities have stable item templates")
 var part:=Items.part_id(4)
 check(Items.get_item(part).monster_tags==["rootbound"] and Items.get_item(part).category=="monster_part","monster component carries loot tags and rarity")
 check(Items.register({"id":"test_relic","name":"Test Relic","monster_tags":["nightbloom","adapted"],"rarity":"Rare","tags":["research"],"stack_limit":20}),"new item registers from generic template")
 check(not Items.register({"id":"test_relic","name":"Duplicate"}),"stable item IDs cannot be overwritten")
 check(not Items.loot_candidates(game.monster_loot_tags(1,0)).has("test_relic") and Items.loot_candidates(game.monster_loot_tags(1,game.Enemies.BARK)).has("test_relic"),"loot tables match required monster and adaptation tags")
 reserve.stock[0]=120;reserve.parts[4]=7;g.parts[0]=8
 var split: Array=Model.stacks(Model.counts(game,p,"stash"),"stash")
 var quantities: Array=[]
 for entry in split:
  if entry.item==Items.seed_id(0): quantities.append(entry.quantity)
 check(quantities==[99,21],"duplicates form bounded stacks without losing overflow")
 Model.transfer(game,p,"shared","stash",Items.part_id(1),5)
 check(g.parts[0]==3 and reserve.parts[1]==5,"shared and personal stash transfers use original crafting storage")
 var saved_path: String=g.path
 g.path="res://.godot/absent-inventory-dir/garden.cfg"
 Model.transfer(game,p,"stash","shared",Items.part_id(1),2)
 check(g.parts[0]==3 and reserve.parts[1]==5,"failed save rolls stash transfer back")
 g.path=saved_path
 # Actual floor stacks are persistent in the Garden and recover through E.
 game.drop_inventory_stack(1,p,"stash",Items.seed_id(0),21)
 check(reserve.stock[0]==99 and g.ground_items.size()==1,"drag-drop removes exactly the displayed stack")
 var reload=load("res://progress.gd").new();reload.path=g.path;reload.load_garden()
 check(reload.ground_items.size()==1 and reload.stock[0]==99,"Garden ground drops persist across saves")
 game.send_action(false)
 check(reserve.stock[0]==120 and g.ground_items.is_empty(),"E picks up a nearby dropped stack")
 var bad_count: int=reserve.parts[4]
 game.drop_inventory_stack(1,p,"carry",part,1)
 check(reserve.parts[4]==bad_count and g.ground_items.is_empty(),"cannot use backpack source from the Garden")
 ExpeditionCase.set_membership(game, p, true);p.carried_parts[4]=9;p.carried_seeds.assign([0,1,2]);p.pos=game.battlefield.entry
 var public: Dictionary=game.player_snapshot(1)[1]
 check(public.bag.carry.size()==2 and not str(public.bag).contains('"seeds"'),"unidentified seed payloads are absent from private UI snapshots")
 Model.transfer(game,p,"carry","pouch",part,9)
 check(p.carried_parts[4]==0 and p.safe_items[0].quantity==9 and p.pouch,"entire monster-part stack moves into one safe slot")
 var before: Array=p.carried_seeds.duplicate()
 Model.transfer(game,p,"carry","pouch","unidentified_seed",3)
 check(p.carried_seeds==before and p.safe_items[0].item==part,"occupied pouch rejects incompatible stack")
 Model.transfer(game,p,"pouch","carry",part,4)
 check(p.carried_parts[4]==4 and p.safe_items[0].quantity==5,"safe stack can be partially removed")
 check(game.recover_pouch(p) and reserve.parts[4]==bad_count+5,"defeat recovery banks the full protected material stack")
 check(not game.recover_pouch(p),"safe recovery cannot duplicate items")
 Model.transfer(game,p,"carry","pouch","unidentified_seed",3)
 check(p.carried_seeds.is_empty() and p.safe_items[0].seeds==[0,1,2],"mysterious stack retains hidden species server-side")
 var visible: Dictionary=Model.snapshot(game,p)
 check(visible.pouch[0].item=="unidentified_seed" and visible.pouch[0].quantity==3 and not visible.pouch[0].has("seeds"),"safe UI cannot reveal concealed species")
 game.drop_inventory_stack(1,p,"pouch","unidentified_seed",3)
 check(not p.pouch and game.wild_item_drops.size()==1,"protected stack can intentionally be dropped")
 check(not game.inventory_floor_snapshot(p)[0].has("seeds"),"ground snapshots conceal species")
 game.pickup_inventory_drop(1,p,game.wild_item_drops[0].id)
 check(p.carried_seeds==[0,1,2] and game.wild_item_drops.is_empty(),"dropped mysterious stack recovers exact species")
 Model.put(game,p,"carry",{"item":"test_relic","quantity":4})
 Model.transfer(game,p,"carry","pouch","test_relic",4)
 game.recover_pouch(p)
 check(Model.extra_stash(game,p).get("test_relic",0)==4,"new template item works with carry, pouch, recovery and stash")
 Model.put(game,p,"carry",{"item":Items.seed_id(1),"quantity":2})
 var seed_before: int=reserve.stock[1]
 Model.bank_extra(game,p)
 check(reserve.stock[1]==seed_before+2,"identified seed pickups return to plantable seed storage")
 # Generic stacks persist without adding bespoke save fields.
 g.save_garden();reload.load_garden()
 check(int(reload.item_stashes.get("",{}).get("test_relic",0))==4,"template items persist in the Garden save")
 # Full-stack safe contents bank at extraction and are intentionally lost on abandonment.
 p.carried_parts[4]=3
 Model.transfer(game,p,"carry","pouch",part,3)
 var part_before: int=reserve.parts[4]
 ExpeditionCase.set_world(game, {"encounter_number": 6});game.encounter.set_hp(-1, 0);game.encounter.clear_scouts();p.pos=game.battlefield.advance
 game.expedition_transitions.checkpoint(1,false)
 check(not ExpeditionCase.is_wild(p) and reserve.parts[4]==part_before+3 and p.safe_items.is_empty(),"checkpoint extraction banks pouch stacks")
 ExpeditionCase.set_membership(game, p, true);p.carried_parts[4]=2
 check(game.monster_rewards.begin_expedition(game._kill_reward_identity(1,p),game.participation.run_id(),p.character.xp,p.character.monsters),
  "synthetic new inventory run records pre-entry rewards before abandonment")
 Model.transfer(game,p,"carry","pouch",part,2)
 part_before=reserve.parts[4]
 game.expedition_transitions.abandon(1)
 check(not p.pouch and p.safe_items.is_empty() and reserve.parts[4]==part_before,"abandonment discards safe stacks without banking")
 # Failing persistence returns Garden drops and pickup items to their original place.
 var seed_count: int=reserve.stock[0]
 g.path="res://.godot/absent-inventory-dir/garden.cfg"
 game.drop_inventory_stack(1,p,"stash",Items.seed_id(0),2)
 check(reserve.stock[0]==seed_count and g.ground_items.is_empty(),"failed drop save restores the original stack")
 g.path=saved_path
 game.drop_inventory_stack(1,p,"stash",Items.seed_id(0),2)
 g.path="res://.godot/absent-inventory-dir/garden.cfg"
 game.pickup_inventory_drop(1,p,g.ground_items[0].id)
 check(reserve.stock[0]==seed_count-2 and g.ground_items.size()==1,"failed pickup save leaves the ground stack intact")
 g.path=saved_path
 game.pickup_inventory_drop(1,p,g.ground_items[0].id)
 # Legacy saves retain their original resources and get a recovery copy.
 var legacy=ConfigFile.new();legacy.load(g.path);legacy.erase_section("inventory")
 var legacy_path: String=g.path+".legacy";legacy.save(legacy_path)
 var migrated=load("res://progress.gd").new();migrated.path=legacy_path;migrated.load_garden();migrated.save_garden()
 check(FileAccess.file_exists(legacy_path+".pre-inventory-v1.bak") and migrated.stock[0]==reserve.stock[0],"legacy counts migrate with a recovery backup")
 # Sorting and filtering are display operations, not item mutations.
 game.expedition_transitions.return_member(preload("res://network_session.gd").peer_for(p));game.ui.toggle_panel("pack");UIFixture.control(game,"inventory_view").refresh()
 check(UIFixture.control(game,"inventory_view").grid.get_child_count()>=40,"normal inventory uses square grid slots with empty spaces")
 var original: int=reserve.stock[0]
 UIFixture.control(game,"inventory_view").filter_pick.select(3);UIFixture.control(game,"inventory_view").key="";UIFixture.control(game,"inventory_view").refresh()
 for entry in UIFixture.control(game,"inventory_view").shown: check(Items.get_item(entry.item).category=="monster_part","type filter hides other items")
 UIFixture.control(game,"inventory_view").sort_pick.select(1);UIFixture.control(game,"inventory_view").sort_button.pressed.emit()
 check(reserve.stock[0]==original,"sorting never moves or loses stored counts")
 var inventory: Control=UIFixture.control(game,"inventory_view")
 reserve.parts[1]=5;p.prepared=1;p.prepared_secondary=0;p.prepared_catalyst=0
 p.cargo_plan.fill(0);p.loadout_reserving=true
 inventory.storage_pick.select(1);inventory.filter_pick.select(2)
 inventory.search.text=Items.get_item(Items.part_id(1)).name
 inventory.key="";inventory.refresh()
 check(inventory.shown.size()==1 and inventory.shown[0].quantity==5 and inventory.shown[0].free==4,"search and availability expose the equipment reservation without hiding ownership")
 var cell: Control=inventory.grid.get_child(0)
 cell.grab_focus()
 check(inventory.selected.item==Items.part_id(1) and inventory.transfer_quantity.max_value==4,"keyboard/controller focus selects the stack and caps transfer quantity")
 var tool: Control=cell._make_custom_tooltip(cell.tooltip_text)
 check(tool.get_child(0).custom_minimum_size.x<=350 and "reserved" in tool.get_child(0).text,"item tooltip wraps and describes the reservation")
 tool.free()
 var refresh_facts: Dictionary=game.inventory_ui_data()
 refresh_facts.notice="A changed notice."
 inventory.present(refresh_facts)
 check(inventory.grid.get_child(0)==cell,"unrelated refresh retains the item control and its focus")
 inventory.transfer_quantity.value=2
 var shared_before:int=g.part_count(1)
 inventory.transfer_button.pressed.emit()
 check(reserve.parts[1]==3 and g.part_count(1)==shared_before+2,"partial transfer sends the chosen quantity through the existing operation")
 inventory.search.text="no_matching_item";inventory.key="";inventory.refresh()
 check(inventory.empty_hint.visible and inventory.transfer_button.disabled,"empty filtered views explain the empty state and refuse transfers")
 game.add_player(2)
 var guest: Dictionary=game.players[2]
 var session=preload("res://tests/support/session_case.gd")
 session.set_ready(game,guest,true);session.set_identity(game,guest,"0000000000000000000000000000e002")
 var guest_reserve: Dictionary=game.seed_reserve(guest)
 game.garden_action(2,"inventory_withdrawals:0")
 check(g.guest_withdrawals,"guest cannot change the host policy")
 game.garden_action(1,"inventory_withdrawals:0")
 check(not g.guest_withdrawals and Model.transfer(game,guest,"shared","stash",Items.part_id(1),1).contains("disabled"),"host disables guest withdrawal immediately at the inventory boundary")
 check(guest_reserve.parts[1]==0,"denied transfer grants nothing")
 var trophy: int=game.Parts.HOOK
 guest.pos=game.stage.gate_position()
 g.add_parts(trophy,2)
 game.handle_loadout_action(2,guest,"pack_%d"%trophy)
 check(guest.cargo_plan[trophy]==0,"shared trophy packing cannot bypass disabled withdrawals")
 guest.cargo_plan[trophy]=1
 check(not game.LoadoutMaterials.cargo_refusal(game,guest).is_empty(),"previously planned shared cargo is rejected at departure")
 guest_reserve.parts[trophy]=1
 check(game.LoadoutMaterials.cargo_refusal(game,guest).is_empty(),"personal trophy cargo remains legitimate")
 guest.cargo_plan.fill(0)
 check(game.LoadoutMaterials.available(game,guest)[1]>guest_reserve.parts[1],"withdrawal policy does not block shared equipment availability")
 var communal: Dictionary=Model.reserve(game,p,"shared")
 communal.stock[0]=2;guest.pos=game.stage.bed_position(0)
 g.plots[0]=game.Progress.empty_plot()
 # This unit fixture uses a synthetic peer without a network connection.
 check(game.cultivation.plant_seed(2,0,0,"shared"),"authoritative planting accepts the shared source")
 check(communal.stock[0]==1 and guest_reserve.stock[0]==0 and g.plots[0].species==0,"guest can plant shared seeds while withdrawals are disabled")
 g.advance_growth(float(game.Seeds.DEFINITIONS[0].grow_seconds))
 game.cultivation.harvest_seeds(2,0)
 check(communal.stock[0]==3 and guest_reserve.stock[0]==0,"propagation awards the shared Garden and not the harvester's stash")
 g.discoveries[0]=true
 guest.pos=game.stage.station_position("seed_archive")
 var cost: int=game.reclamation_cost(0)
 guest_reserve.parts[1]=1
 g.add_parts(1,cost)
 # Test the reclamation transaction owner directly; this fixture does not place the unlocked station.
 game._reclaim_seed(2,guest,0,null,1)
 check(communal.stock[0]==4 and guest_reserve.stock[0]==0 and guest_reserve.parts[1]==0,"mixed reclamation pays a shared seed")
 p.pos=guest.pos
 game.drop_inventory_stack(1,p,"shared",Items.seed_id(0),1)
 var ground: Dictionary=g.ground_items.back()
 check(ground.get("shared",false) and communal.stock[0]==3,"a dropped communal resource retains shared provenance")
 game.pickup_inventory_drop(2,guest,ground.id)
 check(communal.stock[0]==4 and guest_reserve.stock[0]==0 and g.ground_items.is_empty(),"picking up shared drops cannot bypass disabled withdrawals")
 game.garden_action(1,"inventory_withdrawals:1")
 check(g.guest_withdrawals and Model.transfer(game,guest,"shared","stash",Items.part_id(1),1).contains("Moved") and guest_reserve.parts[1]==1,"the host can enable live withdrawals again")
 var snapshot: Dictionary=game.player_snapshot(999)[1]
 check(not snapshot.has("bag"),"other characters cannot see private inventories")
 game.free()
 if not failed: print("PASS: item templates, rarity/tag loot matching, stacks, shared stash, rollback, persistent drops, concealed seeds, full-stack pouch recovery, generic items, filtering and privacy")
 quit(1 if failed else 0)
