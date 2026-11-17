extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const Model=preload("res://inventory_model.gd")
const Items=preload("res://item_catalog.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL inventory party: ",message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/inventory-party-"+str(Time.get_ticks_usec());game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1];ExpeditionCase.set_membership(game, p, false);p.pos=game.Stage.GATE;p.prepared=0;p.prepared_secondary=0;p.prepared_catalyst=0;p.cargo_plan.fill(0)
 var friend: Dictionary=p.duplicate(true);SessionCase.set_identity(game, friend, "inventory-test-friend");ExpeditionCase.install_actor(game, 2, friend)
 var own: Dictionary=game.seed_reserve(p);var theirs: Dictionary=game.seed_reserve(friend)
 own.parts.fill(0);theirs.parts.fill(0);game.progress.parts.fill(0);own.stock.fill(0);theirs.stock.fill(0);game.progress.parts[0]=1
 game.handle_loadout_action(1,p,"loadpart_0_1")
 check(p.prepared==1 and game.stored_counts(friend)[1]==0,"host selection reserves final shared part for guest")
 game.handle_loadout_action(2,friend,"loadpart_0_1");check(friend.prepared==0,"authority rejects competing selection")
 game.handle_loadout_action(1,p,"loadpart_0_0");check(game.stored_counts(friend)[1]==1,"clearing releases shared copy")
 friend.prepared_catalyst=1;friend.loadout_reserving=true;check(game.stored_counts(p)[1]==0,"guest reservation reflected for host")
 own.parts[1]=1;check(game.stored_counts(p)[1]==1,"personal materials remain available despite another player's shared claim")
 var item:=Items.part_id(1)
 check(Model.take(game,p,"shared",item,1).is_empty(),"reserved shared material cannot be withdrawn")
 ExpeditionCase.remove_actor(game, 2);check(game.stored_counts(p)[1]==2,"disconnect releases reservations without consuming inventory");ExpeditionCase.install_actor(game, 2, friend)
 friend.prepared_catalyst=0;friend.loadout_reserving=false;p.loadout_reserving=false
 own.stock[0]=5
 check(Model.transfer(game,p,"stash","shared",Items.seed_id(0),3).begins_with("Moved"),"identified seed stack shares")
 check(own.stock[0]==2 and Model.counts(game,friend,"shared").get(Items.seed_id(0),0)==3,"shared seeds visible to another player")
 check(Model.transfer(game,friend,"shared","stash",Items.seed_id(0),3).begins_with("Moved") and theirs.stock[0]==3,"friend withdraws actual shared seed stack")
 own.unknown.assign([2,4]);check(Model.transfer(game,p,"stash","shared","unidentified_seed",2).begins_with("Moved"),"mystery stack shares")
 check(Model.transfer(game,friend,"shared","stash","unidentified_seed",2).begins_with("Moved") and theirs.unknown==[2,4],"hidden seed identities survive transfer")
 Model.extra_stash(game,p).boss_mystery_seed=1
 check(Model.transfer(game,p,"stash","shared","boss_mystery_seed",1).begins_with("Moved") and Model.transfer(game,friend,"shared","stash","boss_mystery_seed",1).begins_with("Moved"),"ancient mystery seeds also share")
 var paths: Dictionary={};var total:=0
 for part in range(1,game.Parts.DEFINITIONS.size()):
  if not game.Parts.is_plant(part):continue
  game.progress.add_parts(part,1);var definition:=Items.get_item(Items.part_id(part));paths[definition.icon]=true;total+=1
  check(ResourceLoader.exists(definition.icon) and not str(definition.icon).contains("/seeds/"),"independent component icon "+str(part))
 check(total==48 and paths.size()==48,"all normal and rare plant components have unique icons")
 var view=game.inventory_view;view.refresh();view.filter_pick.select(0);view.storage_pick.select(0);view.key="";view.refresh()
 check(view.source()=="all" and view.shown.any(func(e):return e.bucket=="shared" and Items.get_item(e.item).category=="plant_part"),"default Garden view includes harvested shared plant parts")
 check(view.shown.size()>40 and view.grid.get_child_count()==40 and not view.next_page.disabled,"large collection is paginated")
 var first: Dictionary=view.shown[0];var moved: Dictionary={"type":"garden_item_stack","source":first.bucket,"item":first.item,"quantity":first.quantity,"key":first.key}
 check(view.can_accept("all",moved),"combined-view empty slots accept reordering")
 var quantity_before: int=Model.counts(game,p,first.bucket).get(first.item,0);view.move_stack("all",moved)
 check(Model.counts(game,p,first.bucket).get(first.item,0)==quantity_before and view.shown.back().key==first.key,"reordering in combined view does not transfer ownership")
 view.next_page.pressed.emit();check(view.page==1 and not view.previous_page.disabled and view.grid.get_child_count()==40,"next page reachable with a stable square-slot grid")
 view.filter_pick.select(2);view.page=0;view.key="";view.refresh();check(view.shown.all(func(e):return Items.get_item(e.item).category=="plant_part"),"plant filter works across both stores and pages")
 var reload=load("res://progress.gd").new();check(game.progress.save_garden()==OK,"shared seed storage saves")
 reload.path=game.progress.path;check(reload.load_garden()==OK and reload.reserve("inventory-test-friend").unknown==[2,4],"shared seed transfer survives reload")
 game.queue_free();await process_frame
 if not failed:print("PASS: combined Garden inventory, 40-slot pages, 48 component icons, full seed sharing, private budgets and cross-player reservations")
 quit(1 if failed else 0)
