extends SceneTree
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
 p.wild=true;p.carried_parts[4]=9;p.carried_seeds.assign([0,1,2]);p.pos=game.battlefield.entry
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
 game.encounter_number=6;game.enemy_hp=0;game.scouts.clear();p.pos=game.battlefield.advance
 game.use_checkpoint(1,false)
 check(not p.wild and reserve.parts[4]==part_before+3 and p.safe_items.is_empty(),"checkpoint extraction banks pouch stacks")
 p.wild=true;p.carried_parts[4]=2
 Model.transfer(game,p,"carry","pouch",part,2)
 part_before=reserve.parts[4]
 game.abandon_run(1,p)
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
 game.return_to_garden(p);game.toggle_overlay(game.pack_menu);game.inventory_view.refresh()
 check(game.inventory_view.grid.get_child_count()>=40,"normal inventory uses square grid slots with empty spaces")
 var original: int=reserve.stock[0]
 game.inventory_view.filter_pick.select(3);game.inventory_view.key="";game.inventory_view.refresh()
 for entry in game.inventory_view.shown: check(Items.get_item(entry.item).category=="monster_part","type filter hides other items")
 game.inventory_view.sort_pick.select(1);game.inventory_view.sort_button.pressed.emit()
 check(reserve.stock[0]==original,"sorting never moves or loses stored counts")
 var snapshot: Dictionary=game.player_snapshot(999)[1]
 check(not snapshot.has("bag"),"other characters cannot see private inventories")
 game.free()
 if not failed: print("PASS: item templates, rarity/tag loot matching, stacks, shared stash, rollback, persistent drops, concealed seeds, full-stack pouch recovery, generic items, filtering and privacy")
 quit(1 if failed else 0)
