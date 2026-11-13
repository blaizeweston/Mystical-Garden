extends SceneTree
const Avatar=preload("res://traveller_avatar.gd")
const Appearance=preload("res://character_appearance.gd")
const Motion=preload("res://weapon_motion.gd")
const Weapons=preload("res://weapon_visuals.gd")
const Field=preload("res://field_traveller.gd")
const Polearms=preload("res://plant_polearms.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL character overhaul: ",message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate();var base: String="res://.godot/character-overhaul-"+Crypto.new().generate_random_bytes(8).hex_encode();game.progress.path=base+".cfg";game.local_character.path=base+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var parent:=Node3D.new();root.add_child(parent)
 for sex in 2:
  var actor:=Avatar.build(parent);var look: Array=Appearance.DEFAULT.duplicate();look[5]=sex;Appearance.apply(actor,look)
  var body=actor.rig.find_child("TravellerBody*",true,false)
  for surface in body.mesh.get_surface_count():
   var arrays: Array=body.mesh.surface_get_arrays(surface);var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
   for v in arrays[Mesh.ARRAY_VERTEX].size():
    var sum:=0.0
    for slot in 4:sum+=weights[v*4+slot]
    check(absf(sum-1)<.001,"every skinned vertex has normalized weights")
   var basis: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var targets: Array=body.mesh.surface_get_blend_shape_arrays(surface);var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
   for sign_value in [-1.0,1.0]:
    var points:=basis.duplicate();var longest:=0.0;var shortest:=INF
    for vertex in points.size():
     for target in targets:points[vertex]+=(target[Mesh.ARRAY_VERTEX][vertex]-basis[vertex])*sign_value
    for triangle in range(0,indices.size(),3):
     for edge in 3:
      var a: int=indices[triangle+edge];var b: int=indices[triangle+(edge+1)%3];var original: float=basis[a].distance_to(basis[b])
      if original<.003:continue
      var ratio: float=points[a].distance_to(points[b])/original;longest=maxf(longest,ratio);shortest=minf(shortest,ratio)
    check(longest<3.0 and shortest>.12,"combined slider extremes do not shred or collapse topology: "+str([sex,surface,sign_value,shortest,longest]))
  for index in range(6,13):
   for value in [0,50,100]:
    var isolated: Array=look.duplicate();isolated[index]=value;Appearance.apply(actor,isolated)
    check(is_equal_approx(actor.model.scale.x,1) and is_equal_approx(actor.model.scale.z,1),"no slider widens the entire actor root")
    if index>=7:
     for morph in 6:check(is_equal_approx(body.get_blend_shape_value(morph),(value-50)/50.0 if morph==index-7 else 0.0),"sliders retain independent signed morph channels")
  for extreme in [0,50,100]:
   var combined: Array=look.duplicate()
   for index in range(6,13):combined[index]=extreme
   Appearance.apply(actor,combined);actor.pace=0
   for c in 5:
    for w in 3:
     var form: String=game.Classes.DEFINITIONS[c].weapons[w].visual;var profile:=Motion.profile(form)
     actor.visual_weapon=Weapons.build(game.stage,c,w);actor.visual_weapon.reparent(actor.model,false)
     var previous: Array=[]
     for phase in [0.0,.1,.25,float(profile.release),.7,.95,1.0]:
      Avatar.animate(actor,true,phase,form,{"equipped":true},1.0/60.0);Weapons.animate(actor,form,phase,true,0,2)
      var left:=Field.hand(actor,true)
      var right:=Field.hand(actor,false)
      var expected:=left if form=="bow" else (right+left)*.5 if form=="orb" else right
      var handle: Vector3=actor.visual_weapon.global_transform*Vector3(actor.visual_weapon.get_meta("handle",Vector3.ZERO))
      check(handle.distance_to(expected)<.001,"weapon handle stays in actual palm across body/slider/phase extremes: "+form)
      for joint in actor.skeleton.get_bone_count():check(actor.skeleton.get_bone_pose_rotation(joint).is_normalized(),"finite normalized animation rotations")
      if form=="blade":
       check(actor.visual_weapon.has_node("RootbladeModel"),"Rootblade mesh is attached on the normal weapon path")
      if Polearms.WEAPONS.has(form):
       check(actor.visual_weapon.has_node(Polearms.WEAPONS[form].name),"plant weapon mesh is visible on the normal weapon path: "+form)
       var support: Vector3=actor.visual_weapon.to_global(actor.visual_weapon.get_meta("support_grip"))
       if phase>=.16 and phase<=.78:check(support.distance_to(left)<.035,"both palms grip the same shaft through contact: "+str([sex,extreme,form,phase]))
      if form=="bow":
       check(actor.visual_weapon.has_node("VineBowModel"),"Vine Bow mesh is attached on the normal weapon path")
       if phase>=.16 and phase<=float(profile.release):
        var draw:=smoothstep(0,float(profile.release),phase)
        var nock: Vector3=actor.visual_weapon.to_global(Vector3(0,.2,-.2-.25*draw))
        check(nock.distance_to(right)<.035,"draw palm meets the moving nock through release: "+str([sex,extreme,phase,nock.distance_to(right)]))
       check(actor.visual_weapon.get_node("NockedArrow").visible==(phase<float(profile.release)),"nocked arrow vanishes at the committed release")
     actor.visual_weapon.free();actor.erase("visual_weapon")
  Appearance.apply(actor,look);actor.pace=0
  for form in Motion.PROFILES:
   var profile: Dictionary=Motion.profile(form);var clips: Array=[profile.clip]+profile.get("variants",{}).values()
   for clip in clips:
    var prior: Array=[];var largest:=0.0
    for step in range(121):
     Avatar.animate(actor,true,step/120.0,form,{"equipped":true,"clip":clip},1.0/120)
     var rotations: Array=[]
     for bone in ["upper_arm.L","upper_arm.R","forearm.L","forearm.R","hand.L","hand.R","chest"]:
      rotations.append(actor.skeleton.get_bone_pose_rotation(actor.skeleton.find_bone(bone)))
     if not prior.is_empty():
      for joint in rotations.size():largest=maxf(largest,prior[joint].angle_to(rotations[joint]))
     prior=rotations
    check(largest<.35,"no abrupt joint pop through primary/crafted action: "+str([sex,clip,largest]))
  for entry in [[0,0,"line"],[0,2,"line"],[0,1,"sweep"]]:
   var form: String=game.Classes.DEFINITIONS[entry[0]].weapons[entry[1]].visual
   actor.visual_weapon=Weapons.build(game.stage,entry[0],entry[1]);actor.visual_weapon.reparent(actor.model,false)
   Avatar.animate(actor,false,0,form,{"equipped":true},1.0)
   Weapons.animate(actor,form,0,false,0,2);var rest_basis: Basis=actor.visual_weapon.global_basis.orthonormalized()
   for phase in [0.0,1.0]:
    Weapons.animate(actor,form,phase,true,0,2,{"delivery":entry[2],"span":1.9})
    check(rest_basis.get_rotation_quaternion().angle_to(actor.visual_weapon.global_basis.orthonormalized().get_rotation_quaternion())<.001,"crafted delivery begins/ends in weapon ready orientation: "+form)
   actor.visual_weapon.free();actor.erase("visual_weapon")
  for entry in [[0,1,"spear"],[0,2,"hammer"],[3,1,"scythe"]]:
   verify_polearm(game,actor,entry,sex)
  Avatar.animate(actor,true,.42,"blade",{"equipped":true},1.0/240)
  var fast: Quaternion=actor.skeleton.get_bone_pose_rotation(actor.skeleton.find_bone("hand.R"))
  Avatar.animate(actor,false,0,"blade",{"equipped":true},1.0)
  Avatar.animate(actor,true,.42,"blade",{"equipped":true},1.0/30)
  check(fast.angle_to(actor.skeleton.get_bone_pose_rotation(actor.skeleton.find_bone("hand.R")))<.001,"authored contact pose does not lag differently at 30/240 render FPS")
 parent.queue_free();game.queue_free();await process_frame
 if not failed:print("PASS: 90 body/slider/weapon combinations, skin weights, independent sliders, palm grips, bow release, full-action continuity and frame-rate-independent contact")
 quit(1 if failed else 0)

func verify_polearm(game: Node,actor: Dictionary,entry: Array,sex: int) -> void:
 var form: String=entry[2]
 var rig: Skeleton3D=actor.field_rig.skeleton
 var profile:=Motion.profile(form)
 var model:=Weapons.build(game.stage,int(entry[0]),int(entry[1]))
 model.reparent(actor.model,false)
 actor.visual_weapon=model
 var named_joints:=["upperarm_l","lowerarm_l","hand_l","upperarm_r","lowerarm_r","hand_r"]
 var joint_ids:=named_joints.map(func(name):return rig.find_bone(name))
 var origins:=joint_ids.map(func(bone):return rig.get_bone_pose_position(bone))
 var scales:=joint_ids.map(func(bone):return rig.get_bone_pose_scale(bone))
 actor.pace=.65
 actor.speed=3.0
 for delivery in ["line","sector"]:
  var aim:=.85
  actor.model.rotation.y=aim-.18
  var motion: Dictionary={"equipped":true,"aim_yaw":aim,"delivery":delivery,"span":2.3}
  motion.clip=profile.clip if delivery==profile.delivery else profile.variants.values()[0]
  var previous: Array[Quaternion]=[]
  var widest_step:=0.0
  var hand_error:=0.0
  for step in range(121):
   var phase:=float(step)/120.0
   actor.gait_phase=phase
   Avatar.animate(actor,true,phase,form,motion,1.0/120)
   Weapons.animate(actor,form,phase,true,aim,2.4,motion)
   var fore: Vector3=model.to_global(model.get_meta("support_grip"))
   if phase>=.16 and phase<=.78:hand_error=maxf(hand_error,fore.distance_to(Field.hand(actor,true)))
   var rotations: Array[Quaternion]=[]
   for bone in joint_ids:
    rotations.append(rig.get_bone_pose_rotation(bone))
   for index in previous.size():
    widest_step=maxf(widest_step,previous[index].angle_to(rotations[index]))
   previous=rotations
  check(hand_error<.035,"moving traveller keeps both grips through the attack: "+str([sex,form,delivery,hand_error]))
  check(widest_step<.36,"visible arm joints rotate continuously: "+str([sex,form,delivery,widest_step]))
  for index in joint_ids.size():
   check(rig.get_bone_pose_position(joint_ids[index]).is_equal_approx(origins[index]) and rig.get_bone_pose_scale(joint_ids[index]).is_equal_approx(scales[index]),"repeated attacks preserve visible joint lengths and scale")
 actor.pace=0.0
 actor.speed=0.0
 model.free()
 actor.erase("visual_weapon")
