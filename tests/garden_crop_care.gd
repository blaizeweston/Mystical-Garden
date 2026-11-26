extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const State=preload("res://garden_crop_state.gd")
const Catalog=preload("res://garden_crop_catalog.gd")
const Garden=preload("res://garden_interaction_service.gd")
const View=preload("res://garden_crop_view.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL crop care: ",message)
func shown(game: Node,index: int) -> Dictionary:
 for bed in game.cultivation.projection(1).beds:
  if int(bed.slot)==index:return bed
 return {}
func act(game: Node,request: Dictionary) -> Dictionary:return game.garden_commands.command(1,JSON.stringify(request))
func plant(game: Node,index: int,species: int=0) -> void:
 game.players[1].pos=game.Stage.PLOTS[index];game.players[1].seed_choice=species;game.seed_reserve(game.players[1]).stock[species]+=1;game.cultivation.plant_seed(1,index)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 check(Catalog.errors().is_empty(),"care catalog validates")
 var game=load("res://world.tscn").instantiate();var base: String="res://.godot/care-"+Crypto.new().generate_random_bytes(8).hex_encode()
 game.progress.path=base+".cfg";game.local_character.path=base+".character";game.guest_character.path=base+".guest";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var g=game.progress;var p: Dictionary=game.players[1];var crop_view=game.get_node("GardenInteractions/Crops");crop_view.set_process(false)
 plant(game,0);plant(game,1)
 var cycle: String=g.plots[0].care.cycle
 check(cycle!=g.plots[1].care.cycle and not shown(game,0).available,"planting creates distinct cycles and seeds have no care opportunity")
 g.advance_growth(168.75);p.pos=game.Stage.PLOTS[0]
 check(g.plots[0].stage==2 and shown(game,0).available,"young crop exposes one opportunity")
 game.send_action(false);crop_view._process(0)
 check(crop_view.panel.visible and crop_view.preserve.visible and crop_view.outcome.text.contains("20%") and crop_view.outcome.text.contains("1m 00s"),"interacting opens the live choice with exact time/chance previews")
 var request:=View.request(shown(game,0),"preserve_bud")
 var invalid: Dictionary=request.duplicate();invalid.stage=1
 check(act(game,invalid).has("error"),"old stage intent is rejected")
 ExpeditionCase.set_membership(game, p, true);check(act(game,request).has("error"),"Wilds actors cannot tend Garden crops");ExpeditionCase.set_membership(game, p, false)
 p.pos=game.stage.gate_position();check(act(game,request).has("error"),"remote crop request is rejected");p.pos=game.Stage.PLOTS[0]
 # Fix a roll that misses the ordinary 5% but succeeds with preservation's 20%.
 g.plots[0].care.harvest_draw = 150000
 var rng_before: int=game.rng.state;var parts: Array=g.parts.duplicate();var familiarity: Array=p.character.plants.duplicate();var xp: Array=p.character.xp.duplicate()
 var result:=act(game,request)
 check(result.get("changed",false) and State.preserved(g.plots[0]) and game.rng.state==rng_before,"preserving commits once without advancing gameplay RNG")
 check(g.parts==parts and p.character.plants==familiarity and p.character.xp==xp,"care gives no items, familiarity or combat XP")
 check(not act(game,request).changed and g.plots[0].care.revision==request.revision+1,"duplicate/simultaneous same-choice request cannot stack care")
 invalid=View.request(shown(game,0),"leave_bud")
 check(act(game,invalid).has("error"),"a committed choice cannot be swapped to remove its delay")
 var saved=game.Progress.new();saved.path=g.path
 check(saved.load_garden()==OK and saved.plots[0].care==g.plots[0].care and saved.plots[0].stage==2,"cycle, revision, choice and frozen roll survive save/reload")
 check(not shown(game,0).has("roll") and not shown(game,0).has("care"),"projection conceals the harvest roll")
 g.advance_growth(131.25)
 check(g.plots[0].stage==2 and g.plots[1].stage==3,"preserving adds growth time while an unattended crop matures normally")
 p.pos=game.Stage.PLOTS[1];var before: int=g.parts[0];game.cultivation.harvest(1,1)
 check(g.parts[0]==before+1 and g.plots[1].species<0,"unattended crop retains guaranteed material harvest")
 g.advance_growth(60);g.save_garden();p.pos=game.Stage.PLOTS[0]
 check(g.plots[0].stage==3,"preserved crop matures after its one delay")
 var rare: int=game.Parts.rare_part(0);var rare_before: int=g.part_count(rare);var fam_before: int=p.character.plants[0];before=g.parts[0]
 var profile_path: String=game.local_character.path;var old_bed: Dictionary=g.plots[0].duplicate(true);rng_before=game.rng.state
 var cue_count: int=game.combat_events.filter(func(e):return e.kind=="audio" and e.shape=="crop_harvested").size()
 game.local_character.path=base+"-missing/profile";game.cultivation.harvest(1,0)
 check(game.combat_events.filter(func(e):return e.kind=="audio" and e.shape=="crop_harvested").size()==cue_count,"failed save does not confirm a harvest in audio")
 check(g.plots[0]==old_bed and g.parts[0]==before and g.part_count(rare)==rare_before and p.character.plants[0]==fam_before and game.rng.state==rng_before,"failed multi-file harvest rolls back crop, yields, familiarity and RNG")
 game.local_character.path=profile_path;game.cultivation.harvest(1,0)
 check(g.plots[0].species<0 and g.parts[0]==before+1 and g.part_count(rare)==rare_before+1 and p.character.plants[0]==fam_before+1,"one real harvest pays ordinary plus at most one existing rare part and normal familiarity")
 game.cultivation.harvest(1,0)
 check(game.combat_events.filter(func(e):return e.kind=="audio" and e.shape=="crop_harvested").size()==cue_count+1,"only a committed harvest plays its cue")
 check(g.parts[0]==before+1 and g.part_count(rare)==rare_before+1 and p.character.plants[0]==fam_before+1,"repeated harvest cannot duplicate either payout or familiarity")
 plant(game,0)
 check(g.plots[0].care.cycle!=cycle and act(game,request).has("error"),"replanting the same species invalidates old cycle commands")
 g.advance_growth(168.75)
 var current:=View.request(shown(game,0),"preserve_bud");check(act(game,current).get("changed",false),"second crop may choose its own care")
 var phase_request:=View.request(shown(game,0),"preserve_bud")
 var before_age: float=g.plots[0].age
 check(act(game,View.request(shown(game,0),"flower_crop")).has("error") and g.plots[0].age==before_age,"immature seed harvesting does not reset growth")
 g.advance_growth(360);var seeds_before: int=g.reserve("__shared_garden_inventory__").stock[0];before=g.parts[0];rare_before=g.part_count(rare);fam_before=p.character.plants[0]
 check(act(game,View.request(shown(game,0),"flower_crop")).get("changed",false),"mature flowering harvest uses the existing payout atomically")
 check(g.plots[0].species<0 and act(game,phase_request).has("error"),"seed harvesting consumes the crop and invalidates old intents")
 check(g.reserve("__shared_garden_inventory__").stock[0]==seeds_before+2 and g.parts[0]==before and g.part_count(rare)==rare_before and p.character.plants[0]==fam_before+1,"seed choice yields two shared seeds and normal harvest familiarity")
 plant(game,2);g.advance_growth(168.75);var leave:=View.request(shown(game,2),"leave_bud")
 check(act(game,leave).get("changed",false) and not act(game,leave).changed,"normal-growth choice is also bounded and idempotent")
 g.advance_growth(131.25);check(g.plots[2].stage==3,"choosing normal growth adds no delay")
 # A failed choice must not leave a changed revision, roll or preview.
 plant(game,0);g.advance_growth(168.75);old_bed=g.plots[0].duplicate(true);var path: String=g.path;g.path=base+"-missing/garden"
 check(act(game,View.request(shown(game,0),"preserve_bud")).has("error") and g.plots[0]==old_bed,"save failure rolls back the entire care decision")
 g.path=path
 # Template applies to every existing species without weapon/loot special cases.
 for species in game.Seeds.DEFINITIONS.size():
  var bed: Dictionary={"species":species,"stage":2,"age":0.0,"flowering":false,"care":State.new_cycle(species)}
  State.choose(bed,"preserve",.1)
  check(is_equal_approx(State.duration(bed,100),120) and is_equal_approx(State.chance(bed,.45),.60) and game.Parts.rare_part(species)>0,"reusable delay/rare policy "+str(species))
 var future: Dictionary={"version":9,"future":{"keep":true}}
 g.plots[0].care=future.duplicate(true);g.save_garden();saved.load_garden()
 check(saved.plots[0].care==future and act(game,View.request(shown(game,0),"preserve_bud")).has("error"),"future care data is preserved without executing unsupported choices")
 # A legacy crop receives a cycle while retaining its age/yield mode.
 var legacy:=ConfigFile.new();legacy.set_value("garden","plots_v2",[{"species":1,"stage":2,"age":45.0,"flowering":false}]);legacy.save(base+"-old.cfg")
 var old=game.Progress.new();old.path=base+"-old.cfg"
 check(old.load_garden()==OK and old.plots[0].species==1 and is_equal_approx(old.plots[0].age/300.0,45.0/80.0) and State.compatible(old.plots[0]),"old planted crops migrate without losing progress")
 var first_care: Dictionary=old.plots[0].care.duplicate(true)
 check(old.load_garden()==OK and first_care==old.plots[0].care,"reopening a pre-cycle save before migration is committed cannot reroll the crop")
 old.save_garden();var old_again=game.Progress.new();old_again.path=old.path;old_again.load_garden()
 check(old_again.plots[0].care.cycle==old.plots[0].care.cycle,"migrated crop identity persists")
 game.queue_free();await process_frame
 if not failed:print("PASS: crop care cycles, previews, delays, bounded rare outcome, normal/seed harvest, migration, rollback and reusable species policy")
 quit(1 if failed else 0)
