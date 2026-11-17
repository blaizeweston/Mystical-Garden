extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok: failed=true;printerr("FAIL species depth: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/species-depth-"+str(Time.get_ticks_usec())+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1]
 check(game.Seeds.DEFINITIONS.size()==24,"exactly 24 species")
 for i in range(15,24):
  var d: Dictionary=game.Seeds.DEFINITIONS[i];var part:=int(d.part)
  check(game.Parts.plant_source(part)==i and game.Parts.rare_part(i)>0,"ordinary and refined mapping "+d.id)
  for slot in 3:
   var slots: Array=[0,0,0];slots[slot]=part
   var build: Dictionary=preload("res://affinity_build.gd").resolve(0,0,slots,p.character)
   var resolved: Dictionary=build[["core","form","catalyst"][slot]]
   check(resolved.state=="ready" and resolved.executable,"approved family is executable in each slot "+d.id)
  for growth in 4:
   var crop=game.stage.build_crop(i,growth,false);check(crop.get_child_count()>0,"growth model "+d.id);crop.free()
  var a:=int(d.parents[0]);var b:=int(d.parents[1])
  check(game.Seeds.recipe(b,a)==i,"tiered crossbreeding route "+d.id)
  check(not game.Altar.Recipes.find("parts",game.Items.part_id(part),game.Items.part_id(part)).is_empty(),"material refinement route "+d.id)
 check(load("res://content_validator.gd").validate().is_empty(),"all content validates")
 game.queue_free();await process_frame
 if not failed:print("PASS: 24 species, explicit family resolution in each slot, growth models, lineage and refinement")
 quit(1 if failed else 0)
