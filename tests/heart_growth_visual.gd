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
 var g=game.progress;var completed:=0;var previous_height:=Growth.height(0)
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
  check(game.stage.heart_tree.get_node("SeedForm").visible==(completed<3),"old form is visible only before the sapling transition")
  var fresh_growth: Array=game.stage.heart_tree.get_meta("growth_branches",[]).filter(func(branch):return int(branch.get_meta("unlocked_at"))==completed+1)
  check(fresh_growth.size()==1 and not fresh_growth[0].visible,"new shoot or branch starts concealed")
  view.animate(.75)
  check(is_equal_approx(float(game.stage.heart_tree.get_meta("rendered_growth")),completed+.5),"camera shot animates actual intermediate growth")
  if completed==2:check(is_equal_approx(game.stage.heart_tree.get_node("SeedForm").scale.x,.5),"seed shrinks away as the sapling emerges")
  check(fresh_growth[0].visible and is_equal_approx(fresh_growth[0].scale.x,.5),"new branch physically unfurls at the midpoint")
  view.animate(1.5);completed+=1
  check(float(game.stage.heart_tree.get_meta("rendered_growth"))==completed and Growth.height(completed)>previous_height,"unlock adds lasting, measurable height")
  previous_height=Growth.height(completed)
  if completed>=3:
   check(game.stage.heart_tree.has_node("HeartTree/LivingTrunk"),"sapling/tree has real branching geometry")
   check(not game.stage.heart_tree.get_node("SeedForm").visible and not game.stage.heart_core.is_visible_in_tree(),"old seed body and petals cannot overlap the grown tree")
   check(game.stage.heart_tree.get_node("HeartTree").position.y==0 and game.stage.heart_tree.get_node("HeartTree/LivingTrunk").mesh.get_aabb().position.y<.1,"new trunk and roots reach the ground")
  for branch in game.stage.heart_tree.get_meta("growth_branches",[]):check(branch.visible and branch.get_meta("unlocked_at")<=completed,"all visible branches correspond to earned research")
  view.finish(true);game._process(.016)
  check(int(game.stage.heart_tree.get_meta("heart_visual_count"))==completed and Scenes.projection(game,1).pending.is_empty(),"completion retains growth without replay or reward")
 check(completed==ids.size() and previous_height>=7,"all available knowledge produces a large tree")
 check(not game.Campaign.LEGACY_ENDING_ENABLED and g.heart.phase(g)<5 and not g.heart.recollection_seen,"visual completion leaves deferred ending disabled")
 check(game.rng.state==rng_state,"tree construction and scenes consume no gameplay RNG")
 Growth.motion(game.stage,false,Vector3(0,0,-6))
 check(game.stage.heart_tree.get_meta("heart_foliage_material").get_shader_parameter("motion_enabled")==0.0,"motion preference stops canopy movement")
 check(game.stage.heart_tree.get_meta("heart_foliage_material").get_shader_parameter("player_world_position")==Vector3(0,1,-6),"canopy shader receives the player position for local occlusion fading")
 var model: Node3D=game.stage.heart_tree;Growth.sync(game.stage,{"unlocked":g.heart.unlocked});check(game.stage.heart_tree==model,"steady frames do not rebuild tree geometry")
 # Legacy queued events without new fields still play one old growth step.
 var old_events: Array=[]
 for i in 3:old_events.append({"sequence":i+1,"technology":ids[ids.size()-3+i]})
 for i in 3:check(Growth.counts(old_events[i],old_events,g.heart.unlocked)==Vector2i(completed-3+i,completed-2+i),"old queued scenes infer their research order safely")
 var fresh=load("res://world.tscn").instantiate();fresh.progress.path=g.path;fresh.local_character.path=base+"/reload-character";fresh.guest_character.path=base+"/reload-guest";root.add_child(fresh);fresh.set_process(false);fresh.set_physics_process(false);fresh.get_node("GardenInteractions/GrowthScenes").set_process(false);fresh._process(.016)
 check(int(fresh.stage.heart_tree.get_meta("heart_visual_count"))==completed and fresh.stage.heart_tree.has_node("HeartTree"),"reloading reconstructs earned mature tree")
 check(not fresh.stage.heart_tree.get_node("SeedForm").visible,"reload does not resurrect the old overlapping form")
 fresh.free();game.queue_free();await process_frame
 if not failed:print("PASS: every Knowledge unlock animates permanent Heart growth, sapling to mature tree, legacy queues, reload, bounded rebuilds, motion preference and deferred-ending safety")
 quit(1 if failed else 0)
