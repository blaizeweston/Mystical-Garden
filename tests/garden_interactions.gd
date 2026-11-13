extends SceneTree
const Catalog=preload("res://garden_interaction_catalog.gd")
const State=preload("res://garden_interaction_state.gd")
const Service=preload("res://garden_interaction_service.gd")
const Gateway=preload("res://garden_inventory_gateway.gd")
const Model=preload("res://inventory_model.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL Garden interactions: ",message)
func request(game: Node,revision: int,key: String="test",point: String="heart_root_scar",action: String="observe") -> Dictionary:
 return Service.command(game,1,JSON.stringify({"point":point,"action":action,"revision":revision,"request":key}))
func _initialize() -> void:call_deferred("run")
func run() -> void:
 check(Catalog.errors().is_empty(),"catalog has stable IDs, supported handlers and valid parents")
 check(not Service.compatible_projection({}) and not Service.compatible_projection({"version":1,"catalog":"wrong"}),"absent/foreign catalog projections cannot expose mismatched anchors")
 var second: Dictionary=Catalog.POINTS[0].duplicate(true);second.id="second_scar";second.observation="second_trace";second.position=Vector3(2,0,8)
 check(Catalog.errors([Catalog.POINTS[0],second],[Catalog.ZONES[0]]).is_empty(),"a second point requires data, not a new handler")
 check(not Catalog.errors([], [{"id":"a","parent":"b"},{"id":"b","parent":"a"}]).is_empty(),"cyclic parent/child content is rejected")
 var pure:=State.blank();pure.observations.future_observation=true;pure.future_field={"keep":7}
 State.record(pure,second,"other:request")
 check(State.observed(State.normalize(pure),"second_trace") and State.normalize(pure).future_field.keep==7,"generic transition and normalization preserve future IDs/fields")
 for index in 40:
  var definition: Dictionary=second.duplicate();definition.observation="trace_%d"%index
  State.record(pure,definition,"receipt_%d"%index)
 check(pure.receipts.size()==32 and State.observed(pure,"trace_0"),"bounded receipts do not erase durable discoveries")
 var game=load("res://world.tscn").instantiate()
 var base: String="res://.godot/garden-observations-"+Crypto.new().generate_random_bytes(8).hex_encode()
 game.progress.path=base+".cfg";game.local_character.path=base+".character";game.guest_character.path=base+".guest"
 root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var g=game.progress;var p: Dictionary=game.players[1];var view=game.get_node("GardenInteractions");view.set_process(false)
 var point: Dictionary=Catalog.point("heart_root_scar");p.pos=point.position
 var stock: Array=g.stock.duplicate();var parts: Array=g.parts.duplicate();var knowledge: int=g.knowledge;var xp: Array=p.character.xp.duplicate()
 check(Service.nearest(game,p,Service.projection(game,1))==point.id,"point is reachable without taking an existing station interaction")
 for at in [game.Stage.HEART,game.Stage.ALTAR,game.Stage.GATE]+game.Stage.PLOTS:
  p.pos=at
  check(Service.nearest(game,p,Service.projection(game,1)).is_empty(),"canonical station/bed wins at its own anchor")
 p.pos=point.position
 game._process(.016)
 check(game.guide.text.contains("Inspect") and game.prompt_panel.visible,"the actual on-screen prompt includes the observation action")
 game.send_action(false);view._process(0)
 check(view.panel.visible and game.overlay.visible,"E opens the catalog-backed inspect panel")
 game.toggle_overlay(game.pack_menu)
 check(not view.panel.visible and game.pack_menu.visible,"other menus replace the inspection panel")
 game.toggle_overlay(null);view._process(0)
 check(request(game,1).has("error") and g.garden_interactions.revision==0,"old or future state revisions cannot mutate")
 check(request(game,0,"invalid","missing").has("error"),"unknown point is rejected")
 check(request(game,0,"invalid",point.id,"grant_gold").has("error"),"unsupported verbs are rejected")
 p.pos=game.Stage.GATE
 check(request(game,0).has("error"),"remote/out-of-range observation is rejected")
 p.pos=point.position;p.wild=true
 check(request(game,0).has("error"),"expedition actors cannot alter a Garden observation")
 p.wild=false
 var path: String=g.path;g.path=base+"-missing/failure.cfg"
 check(request(game,0,"failed").has("error") and g.garden_interactions.revision==0 and g.garden_interactions.observations.is_empty(),"save failure rolls back observations and receipts")
 view._process(0);check(view.cue_until==0,"failed commit emits no success cue")
 g.path=path
 var result:=request(game,0,"committed")
 check(result.get("changed",false) and g.garden_interactions.revision==1,"validated observation commits once")
 view._process(0);check(view.cue_until>Time.get_ticks_msec(),"successful commit produces a local cue")
 check(not request(game,0,"committed").changed and not request(game,0,"simultaneous").changed and g.garden_interactions.revision==1,"retry and simultaneous requests cannot duplicate discovery")
 check(g.stock==stock and g.parts==parts and g.knowledge==knowledge and p.character.xp==xp,"observation creates no seed, item, Knowledge or class XP")
 var restored=game.Progress.new();restored.path=path
 check(restored.load_garden()==OK and State.observed(restored.garden_interactions,point.observation),"saved observation survives reloading")
 var config:=ConfigFile.new();config.load(path);config.erase_section("garden_interactions");config.save(base+"-legacy.cfg")
 restored.path=base+"-legacy.cfg"
 check(restored.load_garden()==OK and restored.garden_interactions.revision==0 and restored.garden_interactions.observations.is_empty() and restored.garden_interactions.growth.events.is_empty(),"old saves receive additive defaults without replaying old growth")
 g.garden_interactions.observations.future_observation=true;g.garden_interactions.future_field={"keep":9};g.save_garden();restored.path=path;restored.load_garden()
 check(restored.garden_interactions.observations.future_observation and restored.garden_interactions.future_field.keep==9,"unknown save IDs and fields survive disk roundtrip")
 var late=load("res://garden_interaction_view.gd").new();late.game=game;game.add_child(late);late.set_process(false);late._process(0)
 check(late.cue_until==0,"late-join projection restores state without replaying a historical cue")
 late.queue_free()
 var actor: Dictionary=game.seed_reserve(p);actor.parts[1]=1;g.parts[0]=1
 game.add_player(4242);var other: Dictionary=game.players[4242];other.seed_owner="observation-fixture-other";other.profile_ready=true;other.prepared=1;other.loadout_reserving=true
 game.seed_reserve(other).parts[1]=0;p.prepared=1;p.loadout_reserving=true;p.pos=game.Stage.ALTAR
 var item: String=Model.Items.part_id(1)
 var costs: Array=[{"item":item,"source":"shared","quantity":1}]
 check(not Gateway.plan(game,p,costs).ok and Gateway.available(game,p,"stash",item)==0,"offering plan respects another player's shared claim and this player's personal claim")
 check(Model.take(game,p,"shared",item,1).is_empty() and Model.take(game,p,"stash",item,1).is_empty(),"payment agrees with preview and cannot steal reserved components")
 g.parts[0]=2
 var draft: Array=[{"item":item,"source":"shared"},{"item":item,"source":"shared"}]
 check(not preload("res://altar_service.gd").preview(game,p,draft).can_combine,"Altar aggregates duplicate costs against unreserved stock")
 other.loadout_reserving=false;p.loadout_reserving=false
 check(preload("res://altar_service.gd").preview(game,p,draft).can_combine,"released claims become available without a second inventory ledger")
 var future:=State.blank();future.version=2;g.garden_interactions=future;p.pos=point.position
 check(request(game,0).has("error") and g.garden_interactions.version==2,"unknown future schemas are preserved and fail closed")
 game.queue_free();await process_frame
 if not failed:print("PASS: Garden hierarchy, observation authority, save migration/rollback, cues and reservation-aware offering previews")
 quit(1 if failed else 0)
