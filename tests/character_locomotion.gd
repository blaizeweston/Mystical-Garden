extends SceneTree
const Avatar=preload("res://traveller_avatar.gd")
var failed=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL locomotion: ",message)
func rotation(actor: Dictionary,bone: String) -> Quaternion:
 return actor.field_rig.skeleton.get_bone_pose_rotation(actor.field_rig.skeleton.find_bone(bone))
func _initialize():call_deferred("run")
func run():
 var parent=Node3D.new();root.add_child(parent)
 for kind in [0,1]:
  var actor=Avatar.build(parent)
  Avatar.swap(actor,kind)
  check(actor.field_rig.player.active and actor.field_rig.player.callback_mode_process==AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,"manual animation playback is enabled")
  check(actor.field_rig.player.has_animation("Sprint"),"running clip imported for both models")
  actor.pace=1.0;actor.speed=3.0;actor.gait_phase=.25
  Avatar.animate(actor,false,0.0,"blade",{},1.0)
  var thigh=rotation(actor,"thigh_l");var arm=rotation(actor,"upperarm_l");var knee=rotation(actor,"calf_l")
  var field: Skeleton3D=actor.field_rig.skeleton
  var field_thigh:=field.find_bone("thigh_l")
  var rendered_stride:=field.get_bone_pose_rotation(field_thigh)
  actor.gait_phase=.75;Avatar.animate(actor,false,0.0,"blade",{},1.0)
  check(thigh.angle_to(rotation(actor,"thigh_l"))>.6,"hips alternate through actual walking poses")
  check(rendered_stride.angle_to(field.get_bone_pose_rotation(field_thigh))>.25,"visible boots cycle with the imported gait")
  check(knee.angle_to(rotation(actor,"calf_l"))>.6,"knees bend during foot recovery")
  check(arm.angle_to(rotation(actor,"upperarm_l"))>.075,"arms counter-swing during locomotion")
  var spine_id:=field.find_bone("spine_02")
  var spine:=field.get_bone_pose_rotation(spine_id)
  var hand:=field.get_bone_global_pose(field.find_bone("hand_l")).origin
  var arm_travel:=0.0
  var torso_turn:=0.0
  for sample in 16:
   actor.gait_phase=sample/16.0
   Avatar.animate(actor,false,0.0,"bow",{"equipped":true},1.0)
   arm_travel=maxf(arm_travel,hand.distance_to(field.get_bone_global_pose(field.find_bone("hand_l")).origin))
   torso_turn=maxf(torso_turn,spine.angle_to(field.get_bone_pose_rotation(spine_id)))
  check(arm_travel>.12,"carrying a bow in the Wilds preserves arm swing")
  check(torso_turn>.01,"carrying a bow in the Wilds preserves torso motion")
  check(not str(actor.field_rig.player.current_animation).begins_with("Ready_"),"the attack stance does not replace ordinary movement")
  var moving_leg=rotation(actor,"thigh_l")
  Avatar.animate(actor,true,.5,"blade",{},1.0)
  check(moving_leg.angle_to(rotation(actor,"thigh_l"))<.001,"attack layers over walking legs")
  actor.pace=0.0;actor.speed=0.0;actor.idle_time=.1;Avatar.animate(actor,false,0,"",{},.01)
  var transition=rotation(actor,"thigh_l")
  check(transition.angle_to(moving_leg)<.5,"stopping blends rather than snapping")
  Avatar.animate(actor,false,0,"",{},1.0)
  var standing_leg=rotation(actor,"thigh_l");var chest=rotation(actor,"spine_03")
  Avatar.animate(actor,false,0,"",{},1.0)
  check(standing_leg.angle_to(rotation(actor,"thigh_l"))<.075 and lowest_sole(actor)>=-.012,"idle breathing allows a small leg shift with the sole clear of the floor")
  check(chest.angle_to(rotation(actor,"spine_03"))>.005,"idle breath moves the skeleton")
 var game=load("res://world.tscn").instantiate()
 var token=str(Time.get_ticks_usec())
 game.progress.path="res://.godot/locomotion-"+token+".cfg";game.local_character.path=game.progress.path+".character"
 root.add_child(game);game.set_process(false);game.set_physics_process(false);game._process(.016)
 var p=game.players[1];var stage=game.stage
 stage.update_avatar(stage.avatars[1],stage.avatar_models[1],game.actor_presentation.avatar(1,Time.get_ticks_msec()),Vector3.ZERO,.016)
 var actor=stage.avatar_models[1];var phase=float(actor.get("gait_phase",0))
 check(actor.visual_weapon.is_visible_in_tree(),"live stage keeps the weapon on the visible model tree")
 p.velocity=Vector3(2.4,0,0)
 for i in range(1,31): stage.update_avatar(stage.avatars[1],actor,game.actor_presentation.avatar(1,Time.get_ticks_msec()),Vector3(i*.04,0,0),1.0/60.0)
 check(absf(float(actor.gait_phase)-phase)>.3 and actor.pace>.4,"live stage drives gait from traveled distance")
 check(lowest_sole(actor)>=-.012 and absf(actor.model.rotation.x)<.001,"the visible soles stay above the floor while blending")
 live_input_checks(game,actor)
 var snapshot=game.player_snapshot(999)[1]
 check(snapshot.has("attack_anim") and snapshot.appearance is PackedByteArray,"existing co-op presentation contract retained")
 game.queue_free();parent.queue_free();await process_frame
 if not failed: print("PASS: real idle, walk and run poses, smooth transitions, moving attacks and stage-driven gait")
 quit(1 if failed else 0)

func lowest_sole(actor: Dictionary) -> float:
 var floor_height:=INF
 var field: Dictionary=actor.field_rig
 for contact in field.soles:
  floor_height=minf(floor_height,(field.skeleton.get_bone_global_pose(contact.bone)*contact.point).y*actor.model.scale.y+actor.model.position.y)
 return floor_height

func live_input_checks(game: Node,actor: Dictionary) -> void:
 const DT:=1.0/60.0
 var player: Dictionary=game.players[1]
 var field: Dictionary=actor.field_rig
 var skeleton: Skeleton3D=field.skeleton
 var hips: int=field.pelvis
 player.pos=clear_movement_course(game)
 player.velocity=Vector3.ZERO
 var origin: Vector3=player.pos
 Input.action_press("right")
 for tick in 22:
  game._physics_process(DT);game._process(DT)
 var cycle:=float(field.gait)
 var advanced:=0.0
 var lowest_hip:=INF
 var highest_hip:=-INF
 var stance:=false
 var flight:=false
 for tick in 60:
  game._physics_process(DT)
  player.facing=-game.world_direction(Vector2.RIGHT)
  game._process(DT)
  var next:=float(field.gait)
  advanced+=fposmod(next-cycle,1.0)
  cycle=next
  var hip_height:=skeleton.get_bone_global_pose(hips).origin.y
  lowest_hip=minf(lowest_hip,hip_height)
  highest_hip=maxf(highest_hip,hip_height)
  var sole:=lowest_sole(actor)
  check(sole>=-.012,"authored footfalls never penetrate the Garden floor")
  stance=stance or sole<.04
  flight=flight or sole>.08
 Input.action_release("right")
 check(origin.distance_to(player.pos)>5.0,"actual input moved the visible traveller")
 check(advanced>.85 and advanced<1.25,"full-speed movement advances about one authored jog cycle per second: "+str(advanced))
 check(highest_hip-lowest_hip>.10 and stance and flight,"the visible jog retains hip motion, stance and flight")
 var facing:=Vector3(sin(actor.model.rotation.y),0,cos(actor.model.rotation.y))
 check(facing.dot(game.world_direction(Vector2.RIGHT))>.95,"the moving body faces travel when the player has no committed attack")
 for tick in 48:
  game._physics_process(DT);game._process(DT)
 check(actor.speed<.10 and field.player.current_animation=="Idle","releasing movement settles back into the authored idle")
 var stop_phase:=float(field.gait)
 for tick in 16:
  game._physics_process(DT);game._process(DT)
 check(absf(float(field.gait)-stop_phase)<.002,"standing still does not advance the gait cycle")

func clear_movement_course(game: Node) -> Vector3:
 # Keep the animation/input contract independent of Garden enclosure changes.
 var garden=game.stage.experimental_garden
 var step: Vector3=game.world_direction(Vector2.RIGHT)*game.WALK_SPEED/60.0
 var radius:=int(garden.Radius)-2
 for z in range(-radius,radius+1,2):
  for x in range(-radius,radius+1,2):
   var start:=Vector3(x,0,z)
   var point:=start
   var clear:=true
   for tick in 84:
    var target: Vector3=point+step
    if not garden.slide(point,target).is_equal_approx(target):
     clear=false;break
    point=target
   if clear:return start
 check(false,"Garden provides an unobstructed locomotion course")
 return Vector3.ZERO
