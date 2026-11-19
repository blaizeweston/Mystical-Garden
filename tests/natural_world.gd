extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL natural world: ",message)
func _initialize(): call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate()
 var token=Crypto.new().generate_random_bytes(8).hex_encode()
 game.progress.path="res://.godot/natural_test_"+token+".cfg";game.local_character.path=game.progress.path+".character"
 root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1];ExpeditionCase.set_membership(game, p, true)
 var frontier_checks:=0
 for seed_value in range(91247,91263):
  game.battlefield.configure(0,1,seed_value)
  var field=game.battlefield
  check(field.connected(),"connected generated destinations")
 # Explicit cardinal-edge regressions replace the obsolete north-facing seed
 # assumptions. New generated layouts intentionally change their orientation.
 for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
  var field=game.battlefield
  preload("res://tests/support/terrain_case.gd").walls(field,[])
  var from: Vector3=direction*22.8;var to: Vector3=direction*23.45
  check(field.clear_line(from,to,field.CLEARANCE),"edge fixture has a clear baked path")
  check(game.bound_position(to,true).distance_to(to)<.001,"old rectangular arena limit must not clip generated floor")
  p.pos=from
  # Exercise the same camera-relative movement path used by normal input.
  var camera_direction: Vector3=direction.rotated(Vector3.UP,-atan2(3.3,14.0))
  var input:=Vector2(camera_direction.x,camera_direction.z)
  for i in 14: game.move_player(1,input,.02)
  check(p.pos.dot(direction)>23.0,"normal walking crosses the old rectangular arena limit")
  frontier_checks+=1
 check(frontier_checks>=3,"fixture covers multiple generated outer clearings")
 for seed_value in [91247,98723,91261]:
  game.stage.redraw_terrain(0,1,seed_value)
  var feature=game.stage.terrain.find_child("Boundary",true,false)
  check(feature!=null and feature.get_child_count()>0,"the modern continuous boundary is rendered")
  var floor=game.stage.visual_field
  check(floor.connected(),"rendered floor and movement floor share connectivity")
 check(not game.stage.visual_field.generated.layout.boundary.rim.is_empty(),"modern terrain owns its visible enclosure")
 print("Frontier crossings tested: ",frontier_checks)
 if not failed: print("PASS: generated floor limits, normal movement beyond old bounds, connected floor and continuous root chains across three maps")
 game.queue_free();await process_frame
 quit(1 if failed else 0)
