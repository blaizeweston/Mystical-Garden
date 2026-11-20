extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const Growth=preload("res://cultivation_growth.gd")
const Care=preload("res://garden_crop_state.gd")
const Service=preload("res://garden_crop_service.gd")
const Garden=preload("res://garden_interaction_service.gd")
const View=preload("res://garden_crop_view.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL cultivation growth: ",message)
func shown(game: Node) -> Dictionary:
 for bed in Service.projection(game,1).beds:
  if bed.slot==0:return bed
 return {}
func act(game: Node,action: String) -> Dictionary:return Garden.command(game,1,JSON.stringify(View.request(shown(game),action)))
func plant(game: Node,species: int=0) -> void:
 var p: Dictionary=game.players[1];p.pos=game.Stage.PLOTS[0];p.seed_choice=species;game.seed_reserve(p).stock[species]+=1;game.plant_seed(1,0)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var game=load("res://world.tscn").instantiate();var base: String="res://.godot/growth-rates-"+Crypto.new().generate_random_bytes(8).hex_encode()
 game.progress.path=base+".cfg";game.local_character.path=base+".character";game.guest_character.path=base+".guest";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var g=game.progress;var p: Dictionary=game.players[1]
 for seed in game.Seeds.DEFINITIONS:
  check(int(seed.grow_seconds)==[300,720,1500,3000,5400][int(seed.tier)-1],"strictly increasing tier duration "+seed.id)
 plant(game,game.Seeds.index_of("crownroot"))
 var bed: Dictionary=g.plots[0];g.advance_growth(60);check(is_equal_approx(bed.age,60) and bed.stage==0,"mythic plant stays immature after one Garden minute")
 var work: float=bed.age;g.advance_growth(60,true);check(is_equal_approx(bed.age-work,120),"Wilds clock advances twice as fast")
 work=bed.age;game.growth_clock=.99;ExpeditionCase.set_membership(game, p, true);game._physics_process(.01);ExpeditionCase.set_membership(game, p, false);p.pos=game.Stage.PLOTS[0]
 check(is_equal_approx(bed.age-work,2.0),"the live host tick selects the Wilds rate")
 work=bed.age;g.apply_milestone(6);check(bed.age==work,"milestones no longer add a second growth payout")
 var request:=View.request(shown(game),"water_crop")
 check(Garden.command(game,1,JSON.stringify(request)).has("error") and not Growth.watered(bed),"watering requires the actual spring")
 for tech in ["clearing_1","irrigation"]:g.heart.unlock_direct(tech)
 check(Growth.spring_ready(g) and is_equal_approx(Growth.rate(g,bed),1.2),"spring requirements and Knowledge rate share existing research")
 check(act(game,"water_crop").has("error"),"unlocked spring still requires a trip to collect water")
 game.garden_action(1,"spring_fill")
 check(not p.get("spring_water",false),"cannot fill at a bed")
 p.pos=Garden.Catalog.point("spring_water").position
 var garden_view=game.get_node("GardenInteractions")
 game.ui.set_prompt(garden_view.context_prompt())
 check(UIFixture.control(game,"guide").text.contains("Fill watering vessel"),"the spring advertises its direct interaction")
 game.act(1,false);garden_view._process(0.0)
 check(p.get("spring_water",false) and not game.ui.is_overlay_open(),"spring interaction fills the vessel directly")
 check(game.combat_events.filter(func(e):return e.kind=="audio" and e.shape=="vessel_filled").size()==1,"a real spring fill emits one cue")
 game.ui.set_prompt(garden_view.context_prompt())
 check(UIFixture.control(game,"guide").text.contains("Inspect"),"the full vessel exposes spring inspection")
 game.act(1,false);garden_view._process(0.0)
 check(garden_view.panel.visible and garden_view.selected=="spring_water","the observation remains accessible")
 game.ui.close_panels()
 p.pos=game.Stage.PLOTS[0]
 var before_age: float=bed.age;var rng_before: int=game.rng.state;var xp: Array=p.character.xp.duplicate();var fam: Array=p.character.plants.duplicate();var stock: Array=g.stock.duplicate()
 var path: String=g.path;var old: Dictionary=bed.duplicate(true);g.path=base+"-missing/save"
 check(act(game,"water_crop").has("error") and g.plots[0]==old and p.spring_water,"failed watering restores the crop and retains water")
 check(not game.combat_events.any(func(e):return e.kind=="audio" and e.shape=="crop_watered"),"save failure emits no watering cue")
 g.path=path;bed=g.plots[0];request=View.request(shown(game),"water_crop")
 var crop_view=game.get_node("GardenInteractions/Crops")
 game.ui.set_prompt(crop_view.context_prompt())
 check(crop_view.quick_water.visible and not game.ui.is_overlay_open(),"a filled vessel exposes the Water plant button at the growing bed")
 p.pos=game.Stage.HEART
 game.ui.set_prompt(crop_view.context_prompt())
 check(not crop_view.quick_water.visible,"the button disappears away from the bed")
 p.pos=game.Stage.PLOTS[0]
 game.ui.set_prompt(crop_view.context_prompt());crop_view.quick_water.pressed.emit()
 check(Growth.watered(bed) and bed.age==before_age and not p.spring_water,"watering commits a rate, not free instant progress")
 game.ui.set_prompt(crop_view.context_prompt())
 check(not crop_view.quick_water.visible,"the button disappears after watering")
 check(not Garden.command(game,1,JSON.stringify(request)).changed and is_equal_approx(Growth.rate(g,bed),1.5),"co-op retries cannot stack watering")
 check(game.combat_events.filter(func(e):return e.kind=="audio" and e.shape=="crop_watered").size()==1,"watering plays once after the crop is saved")
 g.heart.unlock_direct("nursery")
 check(is_equal_approx(Growth.rate(g,bed,true),3.5),"Wilds, best Knowledge and watering multiply to one capped 3.5x rate")
 work=bed.age;g.advance_growth(10,true);check(is_equal_approx(bed.age-work,35),"actual growth uses the same rate as previews")
 check(shown(game).watered and is_equal_approx(shown(game).garden_remaining/shown(game).wild_remaining,2),"Garden/Wilds ETA reflects watering and research")
 check(game.rng.state==rng_before and p.character.xp==xp and p.character.plants==fam and g.stock==stock,"watering gives no seed, familiarity, XP or random roll")
 g.save_garden();var loaded=game.Progress.new();loaded.path=path;loaded.load_garden()
 check(Growth.watered(loaded.plots[0]) and is_equal_approx(loaded.plots[0].age,bed.age),"long crop work and watering survive reload")
 var age: float=bed.age;g.flowering_unlocked=true
 check(act(game,"flower_crop").has("error") and bed.age==age and not bed.flowering,"immature flowering cannot restart or advance growth")
 g.advance_growth(86400,true);var seeds_before: int=game.seed_reserve(p).stock[int(bed.species)];var parts: Array=g.parts.duplicate();var species: int=bed.species
 var profile_path: String=game.local_character.path;game.local_character.path=base+"-missing/profile"
 check(act(game,"flower_crop").has("error") and g.plots[0].stage==3 and not g.plots[0].flowering,"failed seed harvest restores the mature plant and its outcome choice")
 game.local_character.path=profile_path
 check(act(game,"flower_crop").get("changed",false) and g.plots[0].species<0 and game.seed_reserve(p).stock[species]==seeds_before+2 and g.parts==parts,"flowering consumes the mature plant for seeds without another growth cycle or material payout")
 plant(game,species);check(not Growth.watered(g.plots[0]) and g.plots[0].age==0,"replanting creates an unwatered fresh crop")
 # Old partial, mature and formerly flowering crops keep their percentages.
 for item in [{"species":0,"age":45.,"stage":2,"flowering":false},{"species":23,"age":205.,"stage":3,"flowering":false},{"species":0,"age":40.,"stage":1,"flowering":true}]:
  var config:=ConfigFile.new();config.set_value("content","manifest",g.ContentIDs.manifest());config.set_value("garden","plots_v2",[item]);var legacy_path: String=base+"-legacy-"+str(item.species)+str(item.flowering)+".cfg";config.save(legacy_path)
  var migrated=game.Progress.new();migrated.path=legacy_path;check(migrated.load_garden()==OK,"old save loads")
  var expected:=float(item.age)/float(game.Seeds.DEFINITIONS[int(item.species)].legacy_grow_seconds)
  check(is_equal_approx(float(migrated.plots[0].age)/Growth.duration(migrated.plots[0]),expected) and not migrated.plots[0].flowering,"migration preserves percentage and removes the old seed-growing mode")
  migrated.save_garden();check(FileAccess.file_exists(legacy_path+".pre-tier-growth-v2.bak"),"old crop save is backed up before overwrite")
  var reloaded=game.Progress.new();reloaded.path=legacy_path;reloaded.load_garden();check(is_equal_approx(reloaded.plots[0].age,migrated.plots[0].age),"migration does not apply twice")
 check(Growth.time_text(5400)=="1h 30m" and Growth.time_text(720)=="12m 00s","long growth times are readable")
 game.queue_free();await process_frame
 if not failed:print("PASS: tier growth, one Wilds clock, Knowledge, bounded watering, ETAs, seed-harvest choice, failure rollback and old-save progress migration")
 quit(1 if failed else 0)
