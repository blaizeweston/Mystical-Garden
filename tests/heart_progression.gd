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
 check((["heart","cultivation_grounds"]+Catalog.required_core()).all(func(id):return not Catalog.get_node(id).is_empty()),"historical stable technology IDs remain available")
 var seen: Array=[]
 var new_state: Dictionary=h.serialize()
 check(Catalog.get_node("rift_hook").is_empty() and not Catalog.enabled("rift_hook") and h.purchase(g,"rift_hook")=="Unknown memory.","retired research cannot be selected")
 h.complete(g,"rift_hook")
 check(h.serialize()==new_state,"a stale completion cannot restore a retired node or spend Knowledge")
 for n in Catalog.DEFINITIONS:
  check(not seen.has(n.id),"unique id "+n.id)
  for parent in n.parents: check(seen.has(parent),"each prerequisite precedes its dependent (acyclic graph)")
  seen.append(n.id)
 g.knowledge=400;g.parts.fill(500)
 check(h.phase(g)==0,"unspent lifetime Knowledge alone does not grow the Heart")
 var research_progress=Progress.new()
 research_progress.knowledge=200
 var tree=research_progress.heart
 for blocked in ["wild_harvest","refined_gathering","root_resonance","deep_root_network","reaching_tendrils"]:
  tree.purchase(research_progress,blocked)
  check(not tree.has(blocked) and tree.spent==0,"missing prerequisite refuses "+blocked)
 for row in [["careful_gathering",8],["wild_harvest",16],["refined_gathering",30],["botanical_awareness",6],["root_resonance",20],["checkpoint_deposit",8],["reaching_tendrils",20],["deep_root_network",30]]:
  var original_spent: int=tree.spent
  tree.purchase(research_progress,row[0])
  tree.purchase(research_progress,row[0])
  check(tree.has(row[0]) and tree.spent==original_spent+row[1] and research_progress.knowledge==200,"exact cost and immediate shared unlock "+row[0])
 var before: Array=g.parts.duplicate()
 h.purchase(g,"cultivation_grounds")
 check(g.plots.size()==3 and h.has("cultivation_grounds") and g.knowledge==400 and h.spent==4 and g.parts==before,"bed permission spends only available Knowledge")
 check(preload("res://tests/support/terrain_case.gd").place_structure(game,"bed") and g.plots.size()==4,"researched fourth bed is placed")
 h.purchase(g,"flowering")
 h.purchase(g,"clearing_1")
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
 h.purchase(g,"monster_studies")
 var spent: int=h.spent
 h.purchase(g,"flowering")
 check(not h.has("flowering") and h.spent==spent,"duplicate free research cannot spend Knowledge")
 h.purchase(g,"irrigation")
 check(h.has("irrigation") and g.irrigation.effects.is_empty(),"irrigation grants structures without passive growth")
 for count in range(5,10):
  game.slot_claimed=true;p.pos=Vector3(0,0,1.5)
  check(garden.construct("bed",g.structures.revision) and preload("res://tests/support/terrain_case.gd").place_structure(game,"bed"),"paid bed %d is placed" % count)
 game.slot_claimed=claimed;p.pos=original_position
 check(g.plots.size()==9,"nine universal beds developed")
 var snapshot: Dictionary=h.serialize()
 var parts: Array=g.parts.duplicate()
 var path: String=g.path
 g.path="res://.godot/no-such-directory/heart.cfg"
 game.run_heart_save(h.purchase.bind(g,"seed_conservation"))
 check(h.serialize()==snapshot and g.parts==parts,"failed save rolls back technology and costs")
 g.path=path
 for id in Catalog.required_core(): h.complete(g,id)
 h.sync_legacy(g)
 g.veilcap_discovered=true
 g.campaign.memories.assign(g.Campaign.MEMORY_REQUIREMENTS)
 h.sync_memories(g)
 check(h.decoded==[true,true,true] and not h.has("memory_grove"),
  "the three living guardian memories unlock at their earned thresholds")
 g.save_garden()
 var reload=Progress.new();reload.path=g.path
 check(reload.load_garden()==OK and reload.heart.serialize()==h.serialize(),"Heart state round-trips across saves")
 check_rift_retirement(g.path)
 check_heart_economy_migration(g.path)
 # Legacy earned restoration remains available and receives a recovery backup.
 var legacy_file=ConfigFile.new();legacy_file.load(g.path);legacy_file.erase_section("heart")
 legacy_file.set_value("garden","flowering_unlocked",true)
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
 check(not game.can_use_returning_root(p),"historical gate cannot bank during combat")
 game.encounter.set_hp(-1,0)
 game.garden_action(1,"bank_seed_0")
 check(p.carried_seeds==[0,1] and not game.can_use_returning_root(p),"clear gate cannot bank either")
 ExpeditionCase.returning_root(game,p,"heart-root")
 var unknown_before: int=reserve.unknown.size()
 var bank:=ExpeditionCase.deposit_request(game,p,"unidentified_seed")
 game.garden_action(1,bank)
 check(p.carried_seeds.is_empty() and p.safe_items.front().seeds==[0] and reserve.unknown.size()==unknown_before+1 and reserve.unknown.back()==1,"root secures one carried seed while protecting the pouch")
 check(not game.can_use_returning_root(p),"one unit per root")
 ExpeditionCase.returning_root(game,p,"heart-second")
 p.carried_parts[trophy]=1
 game.garden_action(1,ExpeditionCase.deposit_request(game,p,game.Items.part_id(trophy)))
 check(p.carried_parts[trophy]==1 and game.can_use_returning_root(p),"trophy provenance is mixed; refusal preserves allowance")
 ExpeditionCase.set_membership(game, p, false);ExpeditionCase.set_world(game, {"depth": 0});ExpeditionCase.set_world(game, {"destination": game.Campaign.GROVE})
 for phase in 5:
  game.stage.update_heart_progress({"phase":phase,"unlocked":h.unlocked})
  check(game.stage.experimental_garden.heart.sculpt_models[mini(phase,4)].is_visible_in_tree(),"phase %d uses the imported Heart without an organic overlay"%phase)
 check(["seed_archive","monster_studies","living_archive"].all(func(id):return game.stage.station_position(id).is_finite()),"three restored services use current Garden stations")
 p.pos=game.Stage.HEART;ExpeditionCase.set_membership(game, p, false)
 UIFixture.control(game,"progression_view").tabs.current_tab=1
 UIFixture.control(game,"progression_view").refresh()
 var panel=UIFixture.control(game,"progression_view")
 var costs: Array=[]
 for branch in 3:
  panel.research_tabs.current_tab=branch;panel.refresh()
  var group=Catalog.DEFINITIONS.filter(func(n):return n.get("branch","")==Catalog.BRANCHES[branch])
  check(panel.research_list.item_count==group.size(),"each branch lists all of its purchases")
  costs.append(group.reduce(func(a,n):return a+n.insight,0))
 check(seen.size()==32 and costs==[7,420,142],"31 purchases plus starting Heart, 569 Knowledge")
 game.free()
 if not failed: print("PASS: Heart catalog, costs, immediate unlocks, rollback, save persistence, current imported Heart stages and stations")
 quit(1 if failed else 0)

func check_rift_retirement(source: String) -> void:
 var starter:=Progress.new()
 starter.path=source+".starter"
 check(starter.save_garden()==OK,"create independent starter Garden for migration cases")
 for scenario in ["researching","completed","inherited","free_discovery"]:
  var file:=ConfigFile.new()
  check(file.load(starter.path)==OK,"read disposable migration fixture")
  var state: Dictionary=file.get_value("heart","state")
  state.version=2
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
  check(heart.has("cultivation_grounds") and not heart.has("rift_hook") and not heart.serialize().has("work"), "retain the other funded unlock: "+scenario)
  var growth: Dictionary=migrated.garden_interactions.growth
  check(growth.events.size()==1 and growth.events[0].sequence==5 and growth.seen.viewer==3 and growth.sequence==5
   and not growth.baseline.tech.has("rift_hook"),"retire obsolete notices without renumbering surviving scenes")
  check(migrated.save_garden()==OK and migrated.load_garden()==OK and heart.spent==2 and migrated.knowledge==40,"saving and reloading cannot repeat the refund")
  var written:=ConfigFile.new()
  check(written.load(migrated.path)==OK and not written.has_section_key("garden","rift_hook_discovered")
   and not written.has_section_key("garden","studying_rift_hook") and not written.has_section_key("garden","rift_research_points"),
   "new saves omit retired top-level fields")


func check_heart_economy_migration(source: String) -> void:
 for version in [2,5]:
  var file:=ConfigFile.new()
  check(file.load(source)==OK,"read disposable historical Garden")
  var historical:=["heart","clearing_1","clearing_2","clearing_3","spore_bench","living_archive","memory_mire"]
  var record:={"version":version,"unlocked":historical,"spent":29,"offered":[]}
  if version==2: record.paid=historical.slice(1,6)
  file.set_value("heart","state",record)
  file.set_value("garden","knowledge",75)
  var g:=Progress.new();g.path=source+".retired"+str(version)
  check(file.save(g.path)==OK and g.load_garden()==OK,"migrate historical investment")
  var balance:int=g.heart.available_insight(g)
  check(balance==(72 if version==2 else 46) and g.knowledge==75,"explicit receipts refunded once, aggregate-only debits retained")
  check(g.heart.decoded[1] and g.heart.phase(g)==4 and g.heart.clearing_bonus()==3,"preserve guardian flags, highest historical sculpt and 20% discount")
  check(g.save_garden()==OK and g.load_garden()==OK and g.heart.available_insight(g)==balance,"repeat loading cannot credit another refund")
  check(FileAccess.file_exists(g.path+".pre-heart-economy-v6.bak"),"retain original economy save")
