extends SceneTree
var failed=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL network presentation: ",message)
class MovementFixture extends Node:
 const WALK_SPEED=3.6
 var participation=preload("res://expedition_participation.gd").new()
 var players={}
 var stage={"visual_field":null,"experimental_garden":null}
 func world_direction(v: Vector2) -> Vector3:return Vector3(v.x,0,v.y)
 func bound_position(v: Vector3,_wild: bool=false) -> Vector3:return Vector3(clampf(v.x,-10,10),0,clampf(v.z,-10,10))
 func move_player(id: int,direction: Vector2,delta: float):
  var p: Dictionary=players[id];var before: Vector3=p.pos
  p.pos=bound_position(p.pos+world_direction(direction)*WALK_SPEED*delta)
  p.velocity=(p.pos-before)/maxf(delta,.001)
func movement_checks():
 var original: Dictionary={2:{"pos":Vector3.RIGHT,"velocity":Vector3.ZERO}}
 var view:=preload("res://avatar_motion_view.gd").people(original)
 var stage=load("res://stage.gd").new();var root_actor:=Node3D.new();var gait: Dictionary={"last":Vector3.ZERO,"pace":0.0,"phase":0.0}
 stage.slide_actor(root_actor,gait,view[2].pos,1.0/60.0,view[2].get("velocity",Vector3.INF))
 check(gait.pace>.05 and root_actor.position.length()>0 and original[2].velocity==Vector3.ZERO,"visible movement animates despite a zero prediction substep without mutating simulation")
 for frame in 90:stage.slide_actor(root_actor,gait,view[2].pos,1.0/60.0,view[2].get("velocity",Vector3.INF))
 check(gait.pace<.05,"walking settles after rendered movement stops")
 root_actor.free();stage.free()
 var Movement=load("res://network_movement.gd")
 var client=MovementFixture.new();var host=MovementFixture.new()
 var cm=Movement.new();var hm=Movement.new()
 var start={"pos":Vector3.ZERO,"velocity":Vector3.ZERO,"wild":false,"fallen":false,"motion_scale":1.0}
 var key: String=hm.world_key(host,start);start.motion_epoch=key
 client.players[2]=start.duplicate(true);host.players[2]=start.duplicate(true)
 var delayed: Array=[]
 # 100ms round-trip approximation, every seventh outbound packet lost.
 for tick in 180:
  var direction:=Vector2.RIGHT if tick<120 else Vector2.ZERO
  var commands: Array=cm.client_tick(client,2,direction,1.0/60)
  if tick%7!=0:delayed.append({"at":tick+3,"commands":commands})
  while not delayed.is_empty() and delayed[0].at<=tick:
   hm.accept(2,delayed.pop_front().commands,key,key,tick*17)
  hm.server_tick(host,2,1.0/60,tick*17)
  if tick%3==0 and tick>6:
   var before: Dictionary=client.players
   var state: Dictionary=host.players[2].duplicate(true);state.motion_epoch=key;state.motion_ack=hm.acknowledgement(2,key)
   client.players={2:state};cm.receive(client,2,before,tick*17)
  if tick==0:check(client.players[2].pos.x>.05 and host.players[2].pos.x==0,"guest predicts before host reply")
 check(absf(host.players[2].pos.x-7.2)<.02,"redundant input recovers dropped packets without lost travel")
 check(Vector3(client.players[2].pos).distance_to(host.players[2].pos)<.02,"prediction converges to host after release")
 var before_pos: Vector3=host.players[2].pos
 hm.accept(2,[[999,Vector2.RIGHT,5.0]],key,key,4000)
 hm.server_tick(host,2,1.0/60,4000)
 check(Vector3(host.players[2].pos).distance_to(before_pos)<.001,"invalid duration cannot grant accelerated movement")
 hm.accept(2,[[999,Vector2.RIGHT,1.0/60]],"old floor",key,4000)
 check(int(hm.servers[2].latest)<999,"old-floor input rejected")
 hm.accept(2,[[1000,Vector2.RIGHT,1.0/60]],key,key,4000)
 hm.server_tick(host,2,1.0/60,4400)
 check(Vector3(host.players[2].pos).distance_to(before_pos)<.001,"expired commands cannot cause delayed movement burst")
 # A partial server step must only replay the unconsumed part of its command.
 hm.clear();hm.accept(2,[[1,Vector2.RIGHT,1.0/30]],key,key,5000)
 hm.server_tick(host,2,1.0/60,5000)
 var ack: Dictionary=hm.acknowledgement(2,key)
 check(ack.partial_sequence==1 and absf(ack.partial-1.0/60)<.0001,"partial command acknowledgement preserves simulated time")
 cm.remote[3]=[{"at":100,"pos":Vector3.ZERO,"epoch":key},{"at":200,"pos":Vector3(1,0,0),"epoch":key}]
 var people={3:{"pos":Vector3(1,0,0)}}
 var draw: Dictionary=cm.render_players(people,2,250)
 check(absf(draw[3].pos.x-.5)<.001 and people[3].pos.x==1,"remote interpolation buffers presentation without changing authority")
 draw=cm.render_players(people,2,1000)
 check(draw[3].pos.x==1,"remote silence holds last position instead of unbounded extrapolation")
 client.players[2].pos=Vector3(9.99,0,0);cm.client_tick(client,2,Vector2.RIGHT,1.0/60)
 check(client.players[2].pos.x<=10,"prediction respects movement bounds")

 client.players[2].pos=Vector3.ZERO;client.players[2].motion_scale=.6;cm.pending.clear()
 cm.client_tick(client,2,Vector2.RIGHT,1.0/60)
 check(absf(client.players[2].pos.x-.036)<.0001,"host slow modifier applies to prediction")
 client.players[2].fallen=true;var fallen_pos: Vector3=client.players[2].pos;cm.client_tick(client,2,Vector2.RIGHT,1.0/60)
 check(client.players[2].pos==fallen_pos,"fallen guest cannot predict walking")
 client.players[2].fallen=false;client.players[2].motion_scale=1.0;client.players[2].pos=Vector3.ZERO;cm.pending.clear()
 for frame in 120:cm.client_tick(client,2,Vector2.RIGHT,1.0/60)
 check(client.players[2].pos.x<.91,"long snapshot silence caps speculative movement instead of runaway travel")
 client.players[2].motion_epoch="next floor";cm.client_tick(client,2,Vector2.ZERO,1.0/60)
 check(cm.pending.size()==1 and cm.epoch=="next floor","floor transition discards old predicted inputs")
 var field=load("res://battlefield.gd").new();field.configure(0,1,0);client.stage.visual_field=field
 client.players[2].wild=true;client.players[2].pos=Vector3(-6,0,-4);cm.pending.clear()
 preload("res://tests/support/terrain_case.gd").walls(field,[Rect2(-7,-3.5,2,1)])
 for frame in 15:cm.client_tick(client,2,Vector2.DOWN,1.0/60)
 check(client.players[2].pos.z<-3.5,"predicted movement respects actual terrain collision")

 preload("res://tests/support/terrain_case.gd").walls(field,[])
 client.players[2].pos=Vector3(25,0,0);cm.pending.clear()
 cm.client_tick(client,2,Vector2.RIGHT,1.0/60)
 check(client.players[2].pos.x>25,"procedural prediction uses expanded map bounds beyond old arena")
 field.configured_key=Vector3i(-1,-1,-1);var waiting_pos: Vector3=client.players[2].pos;cm.client_tick(client,2,Vector2.RIGHT,1.0/60)
 check(client.players[2].pos==waiting_pos,"prediction waits for the matching generated collision field")
 hm.frame(1.0/60,{})
 check(hm.servers.is_empty(),"disconnected peers release queued input state")
 client.free();host.free()
func _initialize():call_deferred("run")
func run():
 movement_checks()
 var game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/net-view-"+str(Time.get_ticks_usec())+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false);game._process(.016)
 var p=game.players[1];var actor=game.stage.avatar_models[1];var avatar=game.stage.avatars[1]
 # Reproduce a 240Hz renderer receiving only 20 position packets per second.
 var packet=p.duplicate(true);packet.velocity=Vector3(3.6,0,0);packet.pos=Vector3.ZERO
 game.players[1]=packet
 var first=Quaternion.IDENTITY;var excursion=0.0
 for frame in 480:
  if frame%12==0:packet.pos.x+=.18
  game.stage.update_avatar(avatar,actor,game.actor_presentation.avatar(1,Time.get_ticks_msec()),packet.pos,1.0/240.0)
  var pose=actor.field_rig.skeleton.get_bone_pose_rotation(actor.field_rig.skeleton.find_bone("thigh_l"))
  if frame==120:first=pose
  if frame>120:excursion=maxf(excursion,first.angle_to(pose))
 game.players[1]=p
 check(actor.pace>.7 and excursion>.5,"packet gaps do not stop guest walking at high frame rates")
 preload("res://tests/support/guest_replication_case.gd").health_checks(check)
 # An outgoing guest projection has no host-only combat fields after transport teardown.
 game.players[1]=packet
 game.queue_free();game._process(.016);await process_frame
 if not failed:print("PASS: predicted collision, loss recovery, reconciliation, bounded replay, remote interpolation, high-FPS guest locomotion, sequenced snapshots, reliable health reconciliation and deduplicated damage feedback")
 quit(1 if failed else 0)
