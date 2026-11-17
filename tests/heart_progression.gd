extends SceneTree
const Catalog=preload("res://heart_catalog.gd")
const Progress=preload("res://progress.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL Heart: ",message)
func _initialize(): call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate()
 var token=Crypto.new().generate_random_bytes(8).hex_encode()
 game.progress.path="res://.godot/heart_test_"+token+".cfg"
 game.local_character.path=game.progress.path+".character"
 root.add_child(game)
 game.set_process(false);game.set_physics_process(false)
 var g=game.progress
 var h=g.heart
 var p: Dictionary=game.players[1]
 check((["heart","plot_4","plot_5","plot_6","plot_7","plot_8","plot_9","perfect_recollection"]+Catalog.required_core()).all(func(id):return not Catalog.get_node(id).is_empty()),"historical stable technology IDs remain available")
 var seen: Array=[]
 for n in Catalog.DEFINITIONS:
  check(not seen.has(n.id),"unique id "+n.id)
  for parent in n.parents: check(not Catalog.get_node(parent).is_empty(),"valid parent")
  seen.append(n.id)
 g.knowledge=400;g.parts.fill(500)
 check(h.phase(g)==1,"knowledge begins organic growth")
 var before: int=h.total_materials(g)
 h.start(g,"plot_4")
 check(g.plots.size()==3 and h.active=="plot_4" and g.knowledge==400 and h.spent==2 and h.total_materials(g)==before,"plot research spends Knowledge without upfront plant materials")
 h.advance(g,1)
 check(g.plots.size()==4,"completed plot research grows a bed")
 h.start(g,"flowering")
 h.advance(g,1)
 check(h.active=="flowering" and not h.has("flowering"),"milestone research remains incomplete")
 h.start(g,"clearing_1")
 check(h.active=="clearing_1","research focus can switch without losing previous work")
 h.advance(g,1)
 h.start(g,"monster_studies")
 var spent: int=h.spent
 h.start(g,"flowering")
 check(h.spent==spent and h.progress.flowering==1,"resume does not repay or lose progress")
 h.advance(g,2)
 check(g.flowering_unlocked and h.active.is_empty(),"milestones unlock flowering through legacy interface")
 h.start(g,"monster_studies");h.advance(g,4)
 h.start(g,"infusion");h.advance(g,6)
 h.start(g,"irrigation")
 before=h.total_materials(g)
 h.infuse(g);h.infuse(g)
 check(h.progress.irrigation==2 and h.total_materials(g)==before-4,"infusion technology improves optional offerings")
 h.infuse(g)
 check(h.progress.irrigation==3,"additional offerings can continue accelerating research")
 h.advance(g,3)
 check(h.has("irrigation") and is_equal_approx(h.growth_multiplier(),1.2),"irrigation has functional growth bonus")
 for count in range(5,10):
  h.start(g,"plot_%d"%count);h.advance(g,1)
 check(g.plots.size()==9,"all nine universal beds expandable")
 var snapshot: Dictionary=h.serialize()
 var parts: Array=g.parts.duplicate()
 var path: String=g.path
 g.path="res://.godot/no-such-directory/heart.cfg"
 h.start(g,"clearing_2")
 check(h.serialize()==snapshot and g.parts==parts,"failed save rolls back technology and costs")
 g.path=path
 for id in Catalog.required_core(): h.unlock_direct(id)
 h.mirror(g)
 g.veilcap_discovered=true
 g.campaign.memories.assign(g.Campaign.MEMORY_REQUIREMENTS)
 g.campaign.offshoots.fill(g.Campaign.MATURE)
 h.sync_memories(g)
 check(not g.heart_restored(),"full Knowledge and memories cannot bypass Perfect Recollection")
 check(not h.requirements(g,"perfect_recollection").is_empty(),"final ending research is deferred")
 h.start(g,"perfect_recollection");h.advance(g,24)
 check(not h.has("perfect_recollection") and not g.finale_available(),"complete Knowledge cannot activate the deferred ending")
 h.unlock_direct("perfect_recollection") # Earned legacy state is retained, but cannot launch anything.
 g.save_garden()
 var reload=Progress.new();reload.path=g.path
 check(reload.load_garden()==OK and reload.heart.serialize()==h.serialize(),"Heart state round-trips across saves")
 # Legacy earned restoration remains available and receives a recovery backup.
 var legacy_file=ConfigFile.new();legacy_file.load(g.path);legacy_file.erase_section("heart")
 var legacy_path: String=g.path+".legacy";legacy_file.save(legacy_path)
 var migrated=Progress.new();migrated.path=legacy_path;migrated.load_garden()
 check(migrated.heart.has("perfect_recollection") and migrated.plots.size()==9,"earned legacy ending and plots migrate")
 migrated.save_garden()
 check(FileAccess.file_exists(legacy_path+".pre-heart-v1.bak"),"legacy Heart recovery backup")
 # Reclamation consumes matching parts and returns a known species to its owner's reserve.
 p.wild=false;p.pos=game.Stage.HEART_STATIONS.seed_archive
 g.discoveries[0]=true;p.reclaim_choice=0
 var reserve: Dictionary=game.seed_reserve(p)
 reserve.parts.fill(0);g.parts.fill(0);g.parts[0]=10
 var seeds_before: int=reserve.stock[0]
 game.reclaim_seed(1,p)
 check(reserve.stock[0]==seeds_before+1 and g.parts[0]==10-game.reclamation_cost(0),"reclamation is matching-parts seed recovery")
 p.pos=game.Stage.HEART_STATIONS.monster_studies
 var trophy: int=game.Parts.HOOK
 reserve.parts[trophy]=2;p.offering_choice=trophy
 var knowledge_before: int=g.knowledge
 game.offer_monster(1,p);game.offer_monster(1,p)
 check(g.knowledge==knowledge_before+5 and reserve.parts[trophy]==0,"first trophy knowledge and lower repeat reward")
 check(game.monster_cargo_limit()==8,"preservation expands monster cargo")
 p.pos=game.Stage.GATE;game.send_action(false);game.send_garden_action("depart")
 game.encounter_number=6;game.encounter.set_hp(-1, 1);game.encounter.clear_scouts()
 p.pos=game.battlefield.advance;p.carried_seeds.assign([0,1]);p.pouch=true
 check(not game.can_checkpoint_bank(p),"live checkpoint cannot send items")
 game.encounter.set_hp(-1, 0)
 check(game.can_checkpoint_bank(p),"cleared third-gate upgrade gate offers courier")
 var unknown_before: int=reserve.unknown.size()
 game.bank_checkpoint_item(1,p,"bank_seed_0")
 check(p.wild and p.carried_seeds==[1] and not p.pouch and reserve.unknown.size()==unknown_before+1,"one seed banks without ending expedition or transferring pouch")
 check(not game.can_checkpoint_bank(p),"one courier item per checkpoint")
 game.encounter_number=12;p.last_deposit=0;p.carried_parts[trophy]=1
 var valid_path: String=g.path;g.path="res://.godot/no-such-directory/courier.cfg"
 game.bank_checkpoint_item(1,p,"bank_part_%d"%trophy)
 check(p.carried_parts[trophy]==1 and p.last_deposit==0,"courier save failure returns carried material")
 g.path=valid_path
 game.bank_checkpoint_item(1,p,"bank_part_%d"%trophy)
 check(p.carried_parts[trophy]==0 and reserve.parts[trophy]==1,"courier banks a selected monster material")
 p.wild=false;game.depth=0;game.destination=game.Campaign.GROVE
 for phase in 6:
  game.stage.update_heart_progress({"phase":phase,"unlocked":h.unlocked})
  check(is_instance_valid(game.stage.heart_core),"phase %d constructs an organic 3D core"%phase)
 check(game.stage.heart_stations.size()==3,"three restored services retained in Heart menus")
 p.pos=game.Stage.HEART;p.wild=false
 game.progression_view.tabs.current_tab=1
 game.progression_view.refresh()
 check(game.progression_view.tree.nodes.size()==Catalog.DEFINITIONS.filter(func(n):return Catalog.enabled(n.id)).size(),"reusable tree displays active Heart catalog")
 game.consider_recollection()
 check(not game.recollection_menu.visible,"deferred recollection does not interrupt the Garden")
 game.toggle_overlay(null);game.consider_recollection()
 check(not game.recollection_menu.visible,"narrative does not repeatedly interrupt Garden")
 game.free()
 if not failed: print("PASS: Heart catalog, costs, research, infusion, rollback, save persistence, six 3D forms, stations and deferred recollection")
 quit(1 if failed else 0)

