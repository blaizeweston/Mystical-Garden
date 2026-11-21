extends SceneTree
const Conduit=preload("res://garden_conduit.gd")
const Care=preload("res://garden_crop_state.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL Garden conduit: ",message)
func choose(game: Node,mode: String,revision: int=0,id: int=1) -> Dictionary:
 return game.garden_commands.command(id,JSON.stringify({"point":Conduit.POINT,"action":"configure_conduit","request":"test","revision":revision,"mode":mode}))
func plant(game: Node,species: int,slot: int) -> void:
 var p: Dictionary=game.players[1];p.pos=game.stage.bed_position(slot);p.seed_choice=species;game.seed_reserve(p).stock[species]+=1;game.cultivation.plant_seed(1,slot)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var game=load("res://world.tscn").instantiate();var base: String="res://.godot/conduit-"+Crypto.new().generate_random_bytes(8).hex_encode()
 game.progress.path=base+".cfg";game.local_character.path=base+".character";game.guest_character.path=base+".guest";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 game.get_node("GardenInteractions/GrowthScenes").set_process(false)
 var g=game.progress;var p: Dictionary=game.players[1];var point: Dictionary=Conduit.Layout.Catalog.point(Conduit.POINT);p.pos=point.position
 check(Conduit.errors().is_empty() and Conduit.Layout.Catalog.errors().is_empty() and Care.Catalog.errors().is_empty(),"all content and refinement references validate")
 check(not game.garden_commands.projection(1).available.has(point.id) and choose(game,"deep").has("error"),"locked terrace/tool rejects commands")
 g.knowledge=300;p.pos=game.Stage.HEART
 for tech in ["clearing_1","clearing_2","flowering","irrigation","plot_4"]:
  if tech=="plot_4":check(not g.heart.requirements(g,"living_conduit").is_empty(),"tool requires its usable bed as well as clearing and irrigation")
  game.garden_action(1,"heart_confirm:"+JSON.stringify({"id":tech,"plan":{}}));g.advance_research(10000)
  check(g.heart.has(tech),"normal research completes "+tech)
 # Supply an already-owned fourth bed; physical purchasing is covered by experimental_terrain.
 g.plots.append(g.empty_plot());game.stage.experimental_garden.adopt_recorded_beds();game._process(.016)
 var plots: Array=g.plots.duplicate(true);var parts: Array=g.parts.duplicate();var stock: Array=g.stock.duplicate();game._process(.016)
 check(game.garden_commands.projection(1).available.has(point.id) and g.plots==plots and g.parts==parts and g.stock==stock,"later clearing reveals terrace without crop relocation or rewards")
 check(Conduit.Layout.zone_beds(Conduit.ZONE,g.plots.size())==[3],"terrace registers existing universal bed four")
 var terrace_events: Array=g.garden_interactions.growth.events.filter(func(e):return e.get("kind","")=="zone" and e.get("zone","")==Conduit.ZONE)
 check(terrace_events.size()==1,"real clearing research queues one terrace reveal")
 var scene=game.get_node("GardenInteractions/GrowthScenes");scene.begin(terrace_events[0]);scene.animate(4.0)
 check(scene.target==point.position and game.stage.has_meta("garden_growth_camera"),"existing root-following camera tracks the authored terrace anchor")
 scene.finish(false)
 var water_shapes: Array=game.stage.experimental_garden.state.layout.water
 var shape=preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
 check(not shape.in_any(water_shapes,Vector2(point.position.x,point.position.z),1.4),"generated water preserves the terrace approach")
 for bed in game.stage.bed_positions():
  if bed.is_finite():check(not shape.in_any(water_shapes,Vector2(bed.x,bed.z),1.1),"generated water preserves owned beds")
 check(Conduit.Layout.reserved(game.stage,point.position,20,.5),"terrace reserves scenery clearance")
 p.pos=point.position
 var rng_before: int=game.rng.state;var knowledge: int=g.knowledge
 check(game.garden_commands.command(1,JSON.stringify({"point":point.id,"action":"observe","request":"terrace","revision":0})).get("changed",false),"existing observation handler records terrace")
 check(game.garden_commands.projection(1).clues.get(point.observation,"").contains("Altar") and g.knowledge==knowledge and game.rng.state==rng_before,"existing refinement clue grants no reward or RNG draw")
 var species: int=game.Seeds.index_of("whispervine");plant(game,species,3);var original: Dictionary=g.plots[3].care.duplicate(true)
 p.pos=game.Stage.HEART;game.garden_action(1,"heart_confirm:"+JSON.stringify({"id":"living_conduit","plan":{}}));check(g.heart.active=="living_conduit","new node uses existing focused research queue")
 g.advance_research(10000);check(g.heart.has("living_conduit"),"research unlocks the usable tool")
 p.pos=point.position;var path: String=g.path;g.path=base+"-missing/config"
 check(choose(game,"deep").has("error") and Conduit.state(g).mode=="gentle","failed configuration save rolls back")
 g.path=path;check(choose(game,"deep").get("changed",false),"host changes next-cycle policy")
 check(g.plots[3].care==original and game.rng.state==rng_before,"setting and research do not reroll existing crop or gameplay RNG")
 check(choose(game,"gentle",0).has("error") and choose(game,"bad",1).has("error"),"stale and unknown mode rejected")
 p.pos=game.stage.gate_position();check(choose(game,"gentle",1).has("error"),"remote host cannot change setting")
 g.plots[3].species=-1;plant(game,species,3);var bed: Dictionary=g.plots[3];check(bed.care.opportunity=="deep_bud" and bed.care.zone_condition=="deep","new terrace crop snapshots deep policy")
 var cycle: String=bed.care.cycle;bed.stage=2;Care.choose(bed,"preserve",.5)
 check(is_equal_approx(Care.duration(bed,100),140) and is_equal_approx(Care.chance(bed,.1),.35),"deep policy reuses bounded duration and chance")
 p.pos=point.position;check(choose(game,"gentle",1).get("changed",false) and bed.care.cycle==cycle and bed.care.choice=="preserve","switching cannot reroll or clear an observed crop choice")
 plant(game,species,0);check(g.plots[0].care.opportunity=="patient_bud","other beds retain normal policy")
 g.save_garden();var loaded=game.Progress.new();loaded.path=path;check(loaded.load_garden()==OK and Conduit.state(loaded).mode=="gentle" and loaded.plots[3].care.opportunity=="deep_bud","configuration and snapshotted crop survive reload")
 g.garden_interactions.conduit={"version":9,"unknown":"retained"};g.garden_interactions.future_garden={"keep":true};g.save_garden();loaded.load_garden()
 check(Conduit.state(g).is_empty() and loaded.garden_interactions.conduit.version==9 and loaded.garden_interactions.future_garden.keep,"future/unknown Garden configuration preserved and fails closed")
 var old=game.Progress.new();old.path=base+"-advanced.cfg";old.knowledge=400
 for node in preload("res://heart_catalog.gd").DEFINITIONS:
  if node.id!="living_conduit" and preload("res://heart_catalog.gd").enabled(node.id):old.heart.complete(old,node.id)
 old.stock[0]=13;old.parts[1]=17;old.garden_interactions.future_garden={"keep":true};old.save_garden()
 var advanced=game.Progress.new();advanced.path=old.path;advanced.load_garden()
 check(advanced.plots.size()==9 and advanced.stock[0]==13 and advanced.parts[1]==17 and advanced.garden_interactions.future_garden.keep and not advanced.heart.has("living_conduit"),"fully upgraded historical Garden keeps beds, supplies and unknown data without a free new technology")
 game.queue_free();await process_frame
 if not failed:print("PASS: terrace layout/clue, real research, host-only next-cycle configuration, rollback, policy invariants and save compatibility")
 quit(1 if failed else 0)
