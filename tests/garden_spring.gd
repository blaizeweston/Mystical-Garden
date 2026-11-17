extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const Catalog=preload("res://garden_interaction_catalog.gd")
const Layout=preload("res://garden_layout.gd")
const Service=preload("res://garden_interaction_service.gd")
const Relations=preload("res://garden_relationships.gd")
const Items=preload("res://item_catalog.gd")
const Recipes=preload("res://altar_recipes.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL Garden spring: ",message)
func request(game: Node,point: String,revision: int,key: String) -> Dictionary:
 return Service.command(game,1,JSON.stringify({"point":point,"revision":revision,"request":key,"action":"observe"}))
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var game=load("res://world.tscn").instantiate();var base: String="res://.godot/spring-"+Crypto.new().generate_random_bytes(8).hex_encode()
 game.progress.path=base+".cfg";game.local_character.path=base+".character";game.guest_character.path=base+".guest";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var g=game.progress;var p: Dictionary=game.players[1];var stage=game.stage;var view=game.get_node("GardenInteractions");view.set_process(false)
 var ambience=view.get_node("Ambience");ambience.set_process(false)
 var water: Dictionary=Catalog.point("spring_water");var trace: Dictionary=Catalog.point("spring_weave")
 game._process(.016)
 var dormant: Node3D=stage.garden_edge.get_node("DormantSpringSite")
 check(dormant.scene_file_path=="res://assets/garden/sheltered_spring.tscn" and not dormant.get_meta("garden_spring_awakened"),"locked spring has its own dormant landmark asset")
 check(dormant.find_children("GardenPond","MeshInstance3D",true,false).is_empty() and not dormant.has_node("SpringCascade"),"locked site has no water, lily basin or flowing spring")
 check(Layout.reserved(stage,Layout.zone("sheltered_spring").water.position,11.5),"dormant site reserves scenery space before unlock")
 check(Catalog.errors().is_empty(),"new zone and relationship catalog validate")
 p.pos=water.position
 view._process(0)
 check(not Service.projection(game,1).available.has(water.id) and request(game,water.id,0,"locked").has("error"),"locked spring cannot be inspected or recorded")
 g.knowledge=200;p.pos=game.Stage.HEART
 for id in ["clearing_1","flowering","irrigation"]:
  game.garden_action(1,"heart_confirm:"+JSON.stringify({"id":id,"plan":{}}));g.advance_research(3600)
  check(g.heart.has(id),"existing research unlocks "+id)
 var plots: Array=g.plots.duplicate(true);var stock: Array=g.stock.duplicate();var parts: Array=g.parts.duplicate();var spent: int=g.heart.spent
 game._process(.016)
 var spring: Node3D=stage.garden_edge.get_node("ShelteredSpring")
 check(spring.scene_file_path=="res://assets/garden/sheltered_spring.tscn" and spring.get_meta("garden_spring_awakened") and spring.has_node("SpringBasin/GardenPond") and spring.has_node("SpringCascade"),"research forms the dedicated spring source, basin and flowing cascade")
 check(not stage.garden_edge.has_node("DormantSpringSite") and spring.get_meta("garden_water_position")==Layout.zone("sheltered_spring").water.position,"unlock replaces the sealed site at its authored location")
 for model in stage.garden_edge.get_children():
  if model.has_meta("garden_water_position") and model!=spring:check(model.position.distance_to(spring.position)>2,"ambient pond cannot masquerade as the spring")
 view._process(0)
 check(view.points[water.id].scale.x<1.0,"newly unlocked point has a short local reveal")
 check(Service.projection(game,1).available.has(water.id) and not Service.projection(game,1).available.has(trace.id),"research reveals water but not an unfulfilled plant clue")
 check(g.plots==plots and g.stock==stock and g.parts==parts and g.heart.spent==spent,"physical reveal adds no fee, free bed or crop relocation")
 check(Layout.zone_beds("sheltered_spring",g.plots.size())==[0,1],"spring registers two existing initial beds")
 var zone: Dictionary=Layout.zone("sheltered_spring")
 for index in Layout.zone_beds(zone.id,g.plots.size()):check(zone.footprint.has_point(Vector2(stage.PLOTS[index].x,stage.PLOTS[index].z)),"registered beds are inside the zone footprint")
 check(Layout.ponds(stage,stage.garden_extent).size()==3,"revealed Garden has spring plus its two existing pools")
 # Exercise small/large clearings and every occupied-bed count without changing a crop.
 var unlocked: Array=stage.heart_unlocked.duplicate();var active: int=stage.active_plots
 for count in range(3,10):
  stage.active_plots=count
  for radius in [11.5,14.65,19.9]:
   var ponds: Array=Layout.ponds(stage,radius)
   check(ponds.size()==3,"layout can place all water features at supported bed counts")
   for pond in ponds:
    for at in [stage.HEART,stage.ALTAR,stage.GATE]+stage.PLOTS:
     check(not Layout.in_water(at,pond,1.1),"water does not overlap a station or occupied/future bed")
    for at in Layout.destinations(stage):
     var closest:=Geometry3D.get_closest_point_to_segment(pond.position,Vector3.ZERO,at)
     check(not Layout.in_water(closest,pond,.5),"registered approach paths avoid water")
 stage.active_plots=active;stage.heart_unlocked=unlocked;stage.garden_tier=-1;game._process(.016)
 check(is_equal_approx(stage.garden_extent,game.Stage.garden_radius(g.knowledge,int(g.flowering_unlocked)+int(g.veilcap_discovered)+int(g.rift_hook_discovered)+g.heart.clearing_bonus())),"registered zone fits the existing camera/movement extent")
 # A previously unlocked save reveals without paying or recording a discovery twice.
 g.save_garden();var restored=game.Progress.new();restored.path=g.path;check(restored.load_garden()==OK and restored.heart.has("irrigation") and restored.garden_interactions.revision==0,"old unlocked state remains eligible without a duplicate research payment")
 var moss: int=game.Seeds.index_of("lantern_moss");var vine: int=game.Seeds.index_of("whispervine");var reserve: Dictionary=game.seed_reserve(p)
 for species in [moss,vine]:g.discover(species);reserve.stock[species]=2
 p.pos=stage.PLOTS[0];p.seed_choice=moss;game.plant_seed(1,0)
 p.pos=stage.PLOTS[1];p.seed_choice=vine;game.plant_seed(1,1)
 check(not Relations.matches(game,trace),"young plants do not satisfy a mature relationship")
 g.advance_growth(86400)
 check(Relations.matches(game,trace),"two mature species in registered beds enable the relationship")
 var ingredient:=Items.part_id(int(game.Seeds.DEFINITIONS[moss].part));var recipe:=Recipes.find("parts",ingredient,ingredient)
 check(not recipe.is_empty(),"clue resolves an actual existing same-species refinement")
 var knowledge: int=g.knowledge;parts=g.parts.duplicate();stock=g.stock.duplicate();var xp: Array=p.character.xp.duplicate()
 p.pos=trace.position
 check(request(game,trace.id,0,"observe").get("changed",false),"eligible trace records through the existing host command")
 check(g.knowledge==knowledge and g.parts==parts and g.stock==stock and p.character.xp==xp and not g.altar_recipes.has(recipe.id),"observation grants no materials, XP or automatic recipe discovery")
 var projection:=Service.projection(game,1)
 check(projection.clues.get(trace.observation,"").contains(Items.get_item(ingredient).name),"recorded clue names actual Altar ingredients")
 p.pos=stage.PLOTS[0];game.harvest(1,0)
 check(g.plots[0].species==-1 and Service.projection(game,1).available.has(trace.id),"harvesting empties a bed while an already-recorded clue stays readable")
 # Clear the observation only in the fixture to test a stale pre-discovery intent.
 var saved: Dictionary=g.garden_interactions.duplicate(true);g.garden_interactions=game.progress.garden_interactions.duplicate(true);g.garden_interactions.observations.erase(trace.observation);g.garden_interactions.revision=0;g.garden_interactions.receipts=[]
 p.pos=trace.position
 check(request(game,trace.id,0,"stale").has("error"),"harvesting invalidates an outstanding unrecorded relationship request")
 g.garden_interactions=saved
 # Grow/harvest a second ordinary material, then pay the real Altar recipe.
 p.pos=stage.PLOTS[0];p.seed_choice=moss;game.plant_seed(1,0);g.advance_growth(86400);game.harvest(1,0)
 p.pos=stage.ALTAR;var draft: Array=[{"item":ingredient,"source":"shared"},{"item":ingredient,"source":"shared"}]
 game.send_altar_action("combine",draft,0)
 var output: Dictionary=Items.get_item(recipe.output);var refined:=int(output.legacy_part)
 check(g.altar_recipes.has(recipe.id) and int(game.seed_reserve(p).parts[refined])>0,"Altar consumes harvested materials and discovers its own output")
 check(Relations.clue(game,trace).begins_with("You already know"),"known-recipe fallback provides context without another reward")
 p.pos=stage.GATE;var baseline: Dictionary=game.weapon_stats(p,true)
 game.garden_action(1,"loadpart_0_%d"%refined)
 check(p.prepared==refined,"refined component enters the existing availability-filtered gate slots")
 var improved: Dictionary=game.weapon_stats(p,true);var changed:=false
 for key in ["damage","reach","interval","targets","skill_heal","heal_on_kill","recovery","cooldown"]:
  if improved.get(key,0)!=baseline.get(key,0):changed=true
 check(changed,"refined component changes real weapon/skill attributes")
 ExpeditionCase.Transitions.enter(game, 1,p)
 check(ExpeditionCase.is_wild(p) and p.weapon==refined,"crafted component travels into an actual expedition")
 ExpeditionCase.set_membership(game, p, false);p.pos=water.position
 var random_state: int=game.rng.state;knowledge=g.knowledge;parts=g.parts.duplicate();var interaction: Dictionary=g.garden_interactions.duplicate(true)
 game.app_settings.path=base+".settings";game.app_settings.values.ambient_motion=true;ambience._process(.2)
 check(ambience.colonies.has(zone.id) and ambience.colonies[zone.id].multimesh.instance_count<=ambience.MOTH_LIMIT,"spring fauna uses a bounded local instanced batch")
 var settings=game.settings_dialog;settings.begin(game.app_settings);settings.get_meta("garden_motion_toggle").button_pressed=false;settings.save();ambience._process(.2)
 check(not game.app_settings.values.ambient_motion and not ambience.colonies[zone.id].visible,"motion preference hides cosmetic fauna")
 for child in stage.garden_edge.find_children("*","GeometryInstance3D",true,false):
  if child.get_meta("garden_motion",false):check(child.material_override.get_shader_parameter("motion_enabled")==0.0,"motion preference freezes Garden shaders")
 var loaded=preload("res://app_settings.gd").new();loaded.path=game.app_settings.path;loaded.load_settings();check(not loaded.values.ambient_motion,"motion preference persists independently of gameplay saves")
 check(game.rng.state==random_state and g.knowledge==knowledge and g.parts==parts and g.garden_interactions==interaction,"ambient life cannot alter gameplay RNG, inventory or progression")
 game.queue_free();await process_frame
 if not failed:print("PASS: spring research/layout, mature plant clue to Altar/gate/Wilds, optional bounded ambience and saved motion preference")
 quit(1 if failed else 0)
