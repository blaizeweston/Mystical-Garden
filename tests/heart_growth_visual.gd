extends SceneTree
const Growth=preload("res://heart_growth_visuals.gd")
const Scenes=preload("res://garden_growth_service.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL Heart visual growth: ",message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var game=load("res://world.tscn").instantiate();var base:="user://release-fixtures/heart-tree-"+Crypto.new().generate_random_bytes(8).hex_encode();DirAccess.make_dir_recursive_absolute(base)
 game.progress.path=base+"/world";game.local_character.path=base+"/character";game.guest_character.path=base+"/guest";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var view=game.get_node("GardenInteractions/GrowthScenes");view.set_process(false)
 var g=game.progress;var completed:=0
 var ids: Array=[]
 for node in game.HeartCatalog.DEFINITIONS:
  if node.id!="heart" and game.HeartCatalog.enabled(node.id):ids.append(node.id)
 var rng_state: int=game.rng.state
 for id in ids:
  g.heart.complete(g,id);check(g.save_garden()==OK,"research fixture saves")
  game._process(.016)
  var pending: Array=Scenes.projection(game,1).pending
  check(not pending.is_empty(),"every enabled unlock creates a scene")
  if pending.is_empty():continue
  var event: Dictionary=pending[0]
  check(event.from_growth==completed and event.to_growth==completed+1,"each scene owns exactly one permanent visual growth step")
  view.begin(event);view.animate(0)
  check(float(game.stage.heart_tree.get_meta("rendered_growth"))==completed,"scene begins at previous Heart size")
  var heart=game.stage.experimental_garden.heart
  var current: MeshInstance3D=heart.sculpt_models[heart.stage]
  var start_scale:=current.scale.y
  check(game.stage.heart_tree==heart and heart.sculpt_only and heart.models.is_empty(),"only the imported Heart owns Garden growth")
  check(game.stage.find_children("HeartForm","Node3D",true,false).is_empty() and game.stage.heart_core==null,"old organic Heart is absent, not hidden beneath the sculpt")
  view.animate(.75)
  check(is_equal_approx(float(heart.get_meta("rendered_growth")),completed+.5),"camera shot animates actual intermediate growth")
  var middle_scale:=current.scale.y
  check(middle_scale>start_scale,"research grows the imported mesh itself at the midpoint")
  view.animate(1.5);completed+=1
  check(float(heart.get_meta("rendered_growth"))==completed and current.scale.y>middle_scale,"research growth completes on the same imported mesh")
  check(heart.sculpt_models.filter(func(model):return model.is_visible_in_tree()).size()==1,"one authored stage is visible during every research transition")
  check(current.position.is_zero_approx(),"the sculpt and its roots retain their grounded origin")
  view.finish(true);game._process(.016)
  check(int(game.stage.heart_tree.get_meta("heart_visual_count"))==completed and Scenes.projection(game,1).pending.is_empty(),"completion retains growth without replay or reward")
 check(completed==ids.size() and game.stage.experimental_garden.heart._growth_scale().y>1.0,"all available Knowledge contributes to the imported Heart")
 check(not game.Campaign.LEGACY_ENDING_ENABLED and g.heart.phase(g)<5 and not g.heart.recollection_seen,"visual completion leaves deferred ending disabled")
 check(game.rng.state==rng_state,"tree construction and scenes consume no gameplay RNG")
 Growth.motion(game.stage,false,Vector3(0,0,-6))
 check(game.stage.get_meta("heart_foliage_motion")==false,"motion preference remains available without constructing old foliage")
 check(game.stage.get_meta("heart_foliage_viewer")==Vector3(0,1,-6),"viewer projection remains available to compatible foliage")
 var model: Node3D=game.stage.heart_tree;Growth.sync(game.stage,{"unlocked":g.heart.unlocked});check(game.stage.heart_tree==model,"steady frames do not rebuild tree geometry")
 # Legacy queued events without new fields still play one old growth step.
 var old_events: Array=[]
 for i in 3:old_events.append({"sequence":i+1,"technology":ids[ids.size()-3+i]})
 for i in 3:check(Growth.counts(old_events[i],old_events,g.heart.unlocked)==Vector2i(completed-3+i,completed-2+i),"old queued scenes infer their research order safely")
 var saved_path: String=g.path
 var saved_unlocked: Array=g.heart.unlocked.duplicate()
 game.free()
 var fresh=load("res://world.tscn").instantiate();fresh.progress.path=saved_path;fresh.local_character.path=base+"/reload-character";fresh.guest_character.path=base+"/reload-guest";root.add_child(fresh);fresh.set_process(false);fresh.set_physics_process(false);fresh.get_node("GardenInteractions/GrowthScenes").set_process(false);fresh._process(.016)
 check(fresh.progress.heart.unlocked==saved_unlocked,"reloading retains every earned research investment")
 check(fresh.stage.experimental_garden.heart.stage==mini(int(fresh.heart_state().phase),4),"reload reconstructs the current generated Heart's authored stage")
 fresh.free();await process_frame
 if not failed:print("PASS: imported-only Heart growth, no organic overlay after scene updates, legacy queues, reload, bounded updates and deferred-ending safety")
 quit(1 if failed else 0)
