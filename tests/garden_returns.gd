extends SceneTree

const PlayerLifecycle = preload("res://player_lifecycle.gd")
const Service=preload("res://garden_return_service.gd")
const State=preload("res://garden_return_state.gd")
const Scenes=preload("res://garden_growth_service.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL Garden returns: ",message)
func start(game: Node) -> void:
 var p: Dictionary=game.players[1];p.pos=game.Stage.GATE;p.prepared=0;p.prepared_secondary=0;p.prepared_catalyst=0;p.cargo_plan.fill(0);p[PlayerLifecycle.STATE] = p[PlayerLifecycle.STATE].clear_inactive()
 game.enter_wilds(1,p)
func extraction(game: Node) -> void:
 game.encounter_number=6;game.depth=6;game.deepest_milestone=0;game.enemy_hp=0;game.scouts.clear();game.players[1].pos=game.battlefield.advance
 game.use_checkpoint(1,false)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 check(Service.Catalog.errors().is_empty(),"discovery data references actual content and anchors")
 var game=load("res://world.tscn").instantiate();var base: String="res://.godot/returns-"+Crypto.new().generate_random_bytes(8).hex_encode()
 game.progress.path=base+".cfg";game.local_character.path=base+".character";game.guest_character.path=base+".guest";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var g=game.progress;var p: Dictionary=game.players[1];var moss: int=game.Seeds.index_of("lantern_moss");var ghost: int=game.Seeds.index_of("ghost_fern");var reserve: Dictionary=game.seed_reserve(p)
 var view=game.get_node("GardenInteractions/ReturnLife");view.set_process(false);var scene=game.get_node("GardenInteractions/GrowthScenes");scene.set_process(false);var ambience=game.get_node("GardenInteractions/Ambience");ambience.set_process(false)
 g.discoveries[moss]=true;p.pos=game.Stage.ALTAR;reserve.unknown.append(moss);game.Altar.identify(game,p)
 check(Service.projection(game,1).entries.is_empty(),"an old or crafted/unverified stash seed does not invent a returned discovery")
 start(game);var abandoned_run: String=p.garden_run_id;p.carried_seeds=[moss];game.abandon_run(1,p)
 check(not p.wild and g.garden_interactions.returns.history.size()==1 and not g.garden_interactions.returns.credits.has("lantern_moss"),"abandonment records one outcome and credits no lost seed")
 start(game);check(p.garden_run_id!=abandoned_run,"a new expedition has a new saved identity")
 p.carried_seeds=[moss];var history: int=g.garden_interactions.returns.history.size();var profile_path: String=game.local_character.path
 game.local_character.path=base+"-missing/profile";extraction(game)
 check(p.wild and p.carried_seeds==[moss] and g.garden_interactions.returns.history.size()==history and not g.garden_interactions.returns.credits.has("lantern_moss"),"failed extraction rolls loot and outcome provenance back together")
 game.local_character.path=profile_path;game.battlefield.configure(game.destination,game.depth,game.map_seed);extraction(game)
 check(not p.wild and reserve.unknown.has(moss) and g.garden_interactions.returns.history.size()==history+1 and g.garden_interactions.returns.credits.has("lantern_moss"),"real extraction banks the seed and seals one run summary")
 check(Service.projection(game,1).entries.is_empty() and not JSON.stringify(Service.projection(game,1)).contains("credits"),"banking an unidentified seed publishes neither its identity nor a story")
 p.pos=game.Stage.ALTAR;var path: String=g.path;g.path=base+"-missing/identify"
 check(game.Altar.identify_all(game,p).contains("Could not save") and reserve.unknown.has(moss) and g.garden_interactions.returns.discoveries.is_empty(),"failed identify-all restores seed and discovery atomically")
 g.path=path;var knowledge: int=g.knowledge;var xp: Array=p.character.xp.duplicate();var stock: int=reserve.stock[moss];var rng_state: int=game.rng.state
 game.Altar.identify_all(game,p)
 check(Service.known(Service.projection(game,1),"lantern_homecoming") and reserve.stock[moss]==stock+1 and g.knowledge==knowledge and p.character.xp==xp and game.rng.state==rng_state,"identification unlocks the shared trace without extra items, XP, Knowledge or RNG")
 var events: Array=g.garden_interactions.growth.events.filter(func(e):return e.get("discovery","")=="lantern_homecoming")
 check(events.size()==1,"discovery uses one event in the existing saved scene queue")
 reserve.unknown.append(moss);game.Altar.identify_all(game,p)
 check(g.garden_interactions.growth.events.filter(func(e):return e.get("discovery","")=="lantern_homecoming").size()==1,"later identifications cannot duplicate the scene or discovery")
 var loaded=game.Progress.new();loaded.path=path
 check(loaded.load_garden()==OK and loaded.garden_interactions.returns.discoveries==g.garden_interactions.returns.discoveries,"discovery and provenance survive reload")
 game._process(.016);scene.begin(events[0]);scene.animate(4.0);view._process(.2)
 check(not view.traces.lantern_homecoming.visible and scene.target==game.get_node("GardenInteractions").points.heart_root_scar.position,"return scene tracks a root to the existing investigation point before its trace forms")
 scene.animate(6.7);view._process(.2);check(view.traces.lantern_homecoming.visible and view.heart.visible,"committed discovery grows a permanent trace and answering Heart roots")
 var before_stock: Array=reserve.stock.duplicate();rng_state=game.rng.state;scene.finish(true);view._process(.2)
 for tech in ["clearing_1","irrigation"]:g.heart.unlock_direct(tech)
 g.heart.sync_legacy(g);game._process(.016);view._process(.2);ambience._process(.2)
 check(ambience.colonies.has("return_moths") and ambience.colonies.return_moths.multimesh.instance_count==6,"same bounded moth family gathers at the committed trace")
 var responding:=false
 for group in game.stage.garden_edge.get_children():
  if not group.has_meta("garden_water_position"):continue
  for model in group.find_children("*","MeshInstance3D",true,false):
   if model is MeshInstance3D and model.get_meta("garden_pond",false) and float(model.material_override.get_shader_parameter("resonance"))>.5:responding=true
 check(responding and reserve.stock==before_stock and game.rng.state==rng_state,"spring response, camera and fauna are cosmetic only")
 game.app_settings.values.ambient_motion=false;ambience._process(.2);check(not ambience.colonies.return_moths.visible,"motion preference suppresses moving fauna")
 var story=game.progression_view.care;story.refresh(Service.projection(game,1));check(story.stories.text.contains("Lantern Moss") and story.stories.text.contains("root scar"),"bounded recap survives skipped scenes")
 g.save_garden()
 game.add_player(9090);game.players[9090].profile_ready=true;game.players[9090].seed_owner="return-late-viewer";Scenes.register(game,9090)
 check(Scenes.projection(game,9090).pending.is_empty() and Service.known(Service.projection(game,9090),"lantern_homecoming"),"late join sees the changed Garden without replaying an old award/scene")
 game.players.erase(9090)
 start(game);p.carried_seeds=[moss];p.safe_items=[{"item":"unidentified_seed","quantity":1,"seeds":[ghost]}];var unknown_before: int=reserve.unknown.size();game.finish_failed_expedition()
 check(reserve.unknown.size()==unknown_before+1 and g.garden_interactions.returns.credits.has("ghost_fern") and g.garden_interactions.returns.history[-1].outcomes.has("wipe"),"wipe credits only the actually recovered safe-pouch seed")
 var void_seed: int=game.Seeds.index_of("void_willow");start(game);p.safe_items=[{"item":"unidentified_seed","quantity":1,"seeds":[void_seed]}];unknown_before=reserve.unknown.size();game.abandon_run(1,p)
 check(reserve.unknown.size()==unknown_before and not g.garden_interactions.returns.credits.has("void_willow"),"abandonment loses even the pouch and cannot create discovery credit")
 var pure: Dictionary=State.initialize({"version":1}).returns
 State.begin(pure)
 for actor in ["a","b","c","d"]:State.join(pure,actor)
 for actor in ["a","b","c","d"]:
  State.credit(pure,actor,pure.active.id,"extract",["lantern_moss"])
  State.identify(pure,"lantern_moss")
  State.outcome(pure,actor,pure.active.id,"extracted")
 check(pure.discoveries.size()==1 and pure.history.size()==1 and pure.history[0].outcomes.extracted==4,"four members produce one discovery and one summary")
 pure=State.initialize({"version":1}).returns
 for index in 40:State.begin(pure);State.join(pure,"actor");State.outcome(pure,"actor",pure.active.id,"abandoned");State.outcome(pure,"actor",pure.active.id,"abandoned")
 check(pure.history.size()==32 and pure.sequence==40,"run history is bounded and repeated closure cannot duplicate summaries")
 var future: Dictionary={"version":9,"future":{"keep":true}};g.garden_interactions.returns=future.duplicate(true);g.save_garden();loaded.load_garden()
 check(loaded.garden_interactions.returns==future and Service.projection(game,1).is_empty(),"future return schemas are retained without execution")
 game.app_settings.values.ambient_motion=true;ambience._process(.2)
 check(not ambience.colonies.return_moths.visible,"changing to a world without this discovery clears old fauna")
 game.queue_free();await process_frame
 if not failed:print("PASS: return provenance, extraction/abandon/wipe, rollback, private identification, one shared discovery, recap, late join and cosmetic ecology")
 quit(1 if failed else 0)
