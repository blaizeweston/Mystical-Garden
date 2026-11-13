extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/performance_fixture.cfg";game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1];p.wild=true;game.enemy_hp=10000
 var generation: Array=[]
 for seed_value in [91247,98723,91261,77331,42518]:
  var start:=Time.get_ticks_usec();game.map_seed=seed_value;game.destination=1;game.depth=6;game.encounter_number=48;game.difficulty_cycle=4;game.reset_encounter();game.stage.visual_field=game.battlefield;game.stage.redraw_terrain(1,6,seed_value);generation.append((Time.get_ticks_usec()-start)/1000.)
 var frames: Array=[]
 p.pos=game.battlefield.entry;game.enemy_engaged=true
 for mob in game.scouts: mob.engaged=true
 game._process(.016)
 for i in 40:
  var start:=Time.get_ticks_usec();game._physics_process(.016);game._process(.016);frames.append((Time.get_ticks_usec()-start)/1000.)
 generation.sort();frames.sort()
 print(JSON.stringify({"generated_floors":generation.size(),"floor_generation_p95_ms":generation.back(),"frame_cpu_p95_ms":frames[int(frames.size()*.95)],"active_scouts":game.scouts.size(),"snapshot_bytes":var_to_bytes(game.player_snapshot(1)).size(),"scope":"headless CPU sample; excludes GPU rendering"}))
 game.queue_free();await process_frame;quit()
