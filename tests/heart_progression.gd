extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
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
 check((["heart","plot_4","plot_5","plot_6","plot_7","plot_8","plot_9"]+Catalog.required_core()).all(func(id):return not Catalog.get_node(id).is_empty()),"historical stable technology IDs remain available")
 var seen: Array=[]
 var new_state: Dictionary=h.serialize()
 check(Catalog.get_node("rift_hook").is_empty() and not Catalog.enabled("rift_hook") and h.start(g,"rift_hook")=="Unknown memory.","retired research cannot be selected")
 h.complete(g,"rift_hook")
 check(h.serialize()==new_state,"a stale completion cannot restore a retired node or spend Knowledge")
 for n in Catalog.DEFINITIONS:
  check(not seen.has(n.id),"unique id "+n.id)
  for parent in n.parents: check(not Catalog.get_node(parent).is_empty(),"valid parent")
  seen.append(n.id)
 g.knowledge=400;g.parts.fill(500)
 check(h.phase(g)==1,"knowledge begins organic growth")
 var before: int=h.total_materials(g)
 h.start(g,"plot_4")
 check(g.plots.size()==3 and h.active=="plot_4" and g.knowledge==400 and h.spent==2 and h.total_materials(g)==before,"plot research spends Knowledge without upfront plant materials")
 h.add_work(g,h.duration("plot_4"));check(preload("res://tests/support/terrain_case.gd").place_structure(game,"bed"),"researched fourth bed is placed")
 check(g.plots.size()==4,"completed plot research grows a bed")
 h.start(g,"flowering")
 h.advance(g,1)
 check(h.active=="flowering" and not h.has("flowering"),"milestone research remains incomplete")
 h.start(g,"clearing_1")
 check(h.active=="clearing_1","research focus can switch without losing previous work")
 h.advance(g,1)
 # Research coverage needs space for all nine beds and three stations. Reclaim
 # real land after its unlock instead of placing under the maximum Heart canopy.
 var garden = game.stage.experimental_garden
 var claimed: bool = game.slot_claimed
 var original_position: Vector3 = p.pos
 game.slot_claimed = true
 p.pos = Vector3(0,0,1.5)
 garden.funds.energy = 10000 # Disposable research-fixture setup, not a reward.
 for sector in [4,6,1]:
  garden.open_development()
  check(garden.expand(sector), "research fixture reclaims unlocked construction space")
  if garden.reveal != null: garden.reveal.custom_step(3.0)
 garden.development_dialog.hide()
 game.slot_claimed = claimed
 p.pos = original_position
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
  h.start(g,"plot_%d"%count);h.add_work(g,h.duration("plot_%d"%count));check(preload("res://tests/support/terrain_case.gd").place_structure(game,"bed"),"researched bed %d is placed" % count)
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
 h.sync_memories(g)
 check(["memory_grove","memory_mire","memory_hollow"].all(func(id):return h.has(id)),
  "the three living guardian memories unlock at their earned thresholds")
 g.save_garden()
 var reload=Progress.new();reload.path=g.path
 check(reload.load_garden()==OK and reload.heart.serialize()==h.serialize(),"Heart state round-trips across saves")
 check_rift_retirement(g.path)
 # Legacy earned restoration remains available and receives a recovery backup.
 var legacy_file=ConfigFile.new();legacy_file.load(g.path);legacy_file.erase_section("heart")
 legacy_file.set_value("garden","rift_hook_discovered",true) # Actual pre-tree restoration requirement.
 var legacy_path: String=g.path+".legacy";legacy_file.save(legacy_path)
 var migrated=Progress.new();migrated.path=legacy_path;migrated.load_garden()
 check(Catalog.required_core().all(func(id):return migrated.heart.has(id)) and migrated.plots.size()==9,"pre-tree Garden retains its earned technologies and plots")
 migrated.save_garden()
 check(FileAccess.file_exists(legacy_path+".pre-heart-v1.bak"),"legacy Heart recovery backup")
 legacy_file.erase_section_key("garden","rift_hook_discovered")
 migrated.path=legacy_path+".unfinished"
 check(legacy_file.save(migrated.path)==OK and migrated.load_garden()==OK and not migrated.heart.has("living_archive"),
  "incomplete pre-tree progression does not unlock unearned Archive research")
 # Reclamation consumes matching parts and returns a known species to its owner's reserve.
 ExpeditionCase.set_membership(game, p, false);check(preload("res://tests/support/terrain_case.gd").place_structure(game,"archive") and preload("res://tests/support/terrain_case.gd").place_structure(game,"study"),"current Heart stations are constructed");p.pos=game.stage.station_position("seed_archive")
 g.discoveries[0]=true;p.reclaim_choice=0
 var reserve: Dictionary=game.seed_reserve(p)
 reserve.parts.fill(0);g.parts.fill(0);g.parts[0]=10
 var seeds_before: int=reserve.stock[0]
 game.reclaim_seed(1,p)
 check(reserve.stock[0]==seeds_before+1 and g.parts[0]==10-game.reclamation_cost(0),"reclamation is matching-parts seed recovery")
 p.pos=game.stage.station_position("monster_studies")
 var trophy: int=game.Parts.HOOK
 reserve.parts[trophy]=2;p.offering_choice=trophy
 var knowledge_before: int=g.knowledge
 game.offer_monster(1,p);game.offer_monster(1,p)
 check(g.knowledge==knowledge_before+5 and reserve.parts[trophy]==0,"first trophy knowledge and lower repeat reward")
 check(game.monster_cargo_limit()==8,"preservation expands monster cargo")
 p.pos=game.stage.gate_position()
 var focus_tree=game.Classes.connected_tree(0)
 game.handle_loadout_action(1,p,"learn_0_%d"%focus_tree.REQUEST_OFFSET)
 check(focus_tree.focus(p.character)==focus_tree.nodes[0].id,"level-one starting focus is available before departure")
 game.send_action(false);game.send_garden_action("depart")
 check(ExpeditionCase.is_wild(p),"focused character enters Wilds before checkpoint courier checks")
 ExpeditionCase.set_world(game, {"encounter_number": 6});game.encounter.set_hp(-1, 1);game.encounter.clear_scouts()
 p.pos=game.battlefield.advance;p.carried_seeds.assign([0,1]);p.pouch=true
 check(not game.can_checkpoint_bank(p),"live checkpoint cannot send items")
 game.encounter.set_hp(-1, 0)
 check(game.can_checkpoint_bank(p),"cleared third-gate upgrade gate offers courier")
 var unknown_before: int=reserve.unknown.size()
 game.bank_checkpoint_item(1,p,"bank_seed_0")
 check(ExpeditionCase.is_wild(p) and p.carried_seeds==[1] and not p.pouch and reserve.unknown.size()==unknown_before+1,"one seed banks without ending expedition or transferring pouch")
 check(not game.can_checkpoint_bank(p),"one courier item per checkpoint")
 ExpeditionCase.set_world(game, {"encounter_number": 12});p.last_deposit=0;p.carried_parts[trophy]=1
 var valid_path: String=g.path;g.path="res://.godot/no-such-directory/courier.cfg"
 game.bank_checkpoint_item(1,p,"bank_part_%d"%trophy)
 check(p.carried_parts[trophy]==1 and p.last_deposit==0,"courier save failure returns carried material")
 g.path=valid_path
 game.bank_checkpoint_item(1,p,"bank_part_%d"%trophy)
 check(p.carried_parts[trophy]==0 and game.seed_reserve(p).parts[trophy]==1,"courier banks a selected monster material")
 ExpeditionCase.set_membership(game, p, false);ExpeditionCase.set_world(game, {"depth": 0});ExpeditionCase.set_world(game, {"destination": game.Campaign.GROVE})
 for phase in 5:
  game.stage.update_heart_progress({"phase":phase,"unlocked":h.unlocked})
  check(game.stage.experimental_garden.heart.sculpt_models[mini(phase,4)].is_visible_in_tree(),"phase %d uses the imported Heart without an organic overlay"%phase)
 check(["seed_archive","monster_studies","living_archive"].all(func(id):return game.stage.station_position(id).is_finite()),"three restored services use current Garden stations")
 p.pos=game.Stage.HEART;ExpeditionCase.set_membership(game, p, false)
 UIFixture.control(game,"progression_view").tabs.current_tab=1
 UIFixture.control(game,"progression_view").refresh()
 check(UIFixture.control(game,"progression_view").tree.nodes.size()==Catalog.DEFINITIONS.filter(func(n):return Catalog.enabled(n.id)).size(),"reusable tree displays active Heart catalog")
 game.free()
 if not failed: print("PASS: Heart catalog, costs, research, infusion, rollback, save persistence, current imported Heart stages and stations")
 quit(1 if failed else 0)

func check_rift_retirement(source: String) -> void:
 var starter:=Progress.new()
 starter.path=source+".starter"
 check(starter.save_garden()==OK,"create independent starter Garden for migration cases")
 for scenario in ["researching","completed","inherited","free_discovery"]:
  var file:=ConfigFile.new()
  check(file.load(starter.path)==OK,"read disposable migration fixture")
  var state: Dictionary=file.get_value("heart","state")
  state.unlocked=["heart","rift_hook"] if scenario!="researching" else ["heart"]
  state.paid=["plot_4"] if scenario=="free_discovery" else ["plot_4","rift_hook"]
  state.spent=8 if scenario in ["researching","completed"] else 2
  state.active="rift_hook" if scenario=="researching" else "plot_4"
  for field in ["progress","natural","infused","work"]:
   state[field]={"rift_hook":1,"plot_4":0}
  state.work.plot_4=20.0
  file.set_value("heart","state",state)
  file.set_value("garden","knowledge",40)
  file.set_value("garden","studying_rift_hook",scenario=="researching")
  file.set_value("garden","rift_research_points",2)
  file.set_value("garden","rift_hook_discovered",scenario!="researching")
  var history: Dictionary=file.get_value("garden_interactions","state")
  history.growth.events=[{"sequence":4,"technology":"rift_hook"},{"sequence":5,"kind":"expansion","expansion":1}]
  history.growth.sequence=5
  history.growth.seen={"viewer":3}
  history.growth.baseline.tech=["heart","rift_hook"]
  file.set_value("garden_interactions","state",history)
  var migrated:=Progress.new()
  migrated.path=source+"."+scenario
  check(file.save(migrated.path)==OK and migrated.load_garden()==OK,"load old Garden with "+scenario+" Rift Hook")
  var heart=migrated.heart
  check(heart.available_insight(migrated)==38 and heart.spent==2 and migrated.knowledge==40,"refund only paid Rift Knowledge, keep lifetime total: "+scenario)
  check(heart.paid==["plot_4"] and not heart.has("rift_hook") and heart.active==("" if scenario=="researching" else "plot_4")
   and heart.work.plot_4==20.0,"retain unrelated research and its payment: "+scenario)
  for field in ["work","natural","infused","progress"]:check(not heart.get(field).has("rift_hook"),"retire saved "+field)
  var growth: Dictionary=migrated.garden_interactions.growth
  check(growth.events.size()==1 and growth.events[0].sequence==5 and growth.seen.viewer==3 and growth.sequence==5
   and not growth.baseline.tech.has("rift_hook"),"retire obsolete notices without renumbering surviving scenes")
  check(migrated.save_garden()==OK and migrated.load_garden()==OK and heart.spent==2 and migrated.knowledge==40,"saving and reloading cannot repeat the refund")
  var written:=ConfigFile.new()
  check(written.load(migrated.path)==OK and not written.has_section_key("garden","rift_hook_discovered")
   and not written.has_section_key("garden","studying_rift_hook") and not written.has_section_key("garden","rift_research_points"),
   "new saves omit retired top-level fields")

