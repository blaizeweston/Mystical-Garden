extends RefCounted
const FieldRig=preload("res://field_traveller.gd")
const MODELS=[preload("res://assets/characters/traveller_male.glb"),preload("res://assets/characters/traveller_female.glb")]
static func build(parent: Node) -> Dictionary:
 var model=Node3D.new();parent.add_child(model)
 var actor={"model":model,"legs":[],"arms":[],"phase":0.0,"pace":0.0,"last":Vector3.INF,"windup":0.0,"rig_kind":-1}
 swap(actor,0)
 return actor
static func swap(actor: Dictionary,kind: int) -> void:
 if actor.has("visual_weapon"):
  actor.visual_weapon.free();actor.erase("visual_weapon");actor.erase("weapon_key")
 if actor.has("secondary_weapon"):
  actor.secondary_weapon.free();actor.erase("secondary_weapon")
 if actor.has("rig"):
  var old: Node3D=actor.rig
  actor.model.remove_child(old);old.queue_free()
 if actor.has("field_rig"):
  var old_visual: Node3D=actor.field_rig.scene
  actor.model.remove_child(old_visual);old_visual.queue_free()
 var rig=MODELS[clampi(kind,0,1)].instantiate();actor.model.add_child(rig);rig.hide()
 actor.rig=rig;actor.rig_kind=kind;actor.look_key=""
 actor.skeleton=rig.find_children("*","Skeleton3D",true,false)[0]
 actor.animator=rig.find_children("*","AnimationPlayer",true,false)[0]
 actor.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 actor.animator.active=true
 actor.field_rig=FieldRig.build(actor.model,actor.skeleton,kind)
 actor.foot_contacts=[]
 for side in ["L","R"]:
  var bone=actor.skeleton.find_bone("foot."+side)
  var rest: Transform3D=actor.skeleton.get_bone_global_rest(bone)
  var x=.105 if side=="L" else -.105
  for z in [-.055,.04,.13]:
   actor.foot_contacts.append({"bone":bone,"point":rest.affine_inverse()*Vector3(x,.006,z)})
 var grip=BoneAttachment3D.new();actor.skeleton.add_child(grip);grip.bone_name="hand.R";actor.grip=grip
 var left=BoneAttachment3D.new();actor.skeleton.add_child(left);left.bone_name="hand.L";actor.offhand_grip=left
 var palm:=Node3D.new();grip.add_child(palm);palm.name="PalmSocket";palm.position=Vector3(0,.045,0);actor.palm=palm
 var offpalm:=Node3D.new();left.add_child(offpalm);offpalm.name="PalmSocket";offpalm.position=Vector3(0,.045,0);actor.offpalm=offpalm
# Manual playback applies exactly one pose per rendered frame, including guests.
static func sample(actor: Dictionary,clip: String,time: float) -> void:
 var player: AnimationPlayer=actor.animator
 if player.current_animation!=clip: player.play(clip)
 player.seek(time,true)
 player.advance(0.0)
static func animate(actor: Dictionary,active: bool,phase: float,form: String,motion: Dictionary={},delta: float=1.0/60.0) -> void:
 var skeleton: Skeleton3D=actor.skeleton
 var previous: Array[Quaternion]=[]
 for i in skeleton.get_bone_count(): previous.append(skeleton.get_bone_pose_rotation(i))
 actor.idle_time=float(actor.get("idle_time",0.0))+delta
 sample(actor,"Idle",fposmod(actor.idle_time,2.0))
 var idle: Array[Quaternion]=[]
 for i in skeleton.get_bone_count(): idle.append(skeleton.get_bone_pose_rotation(i))
 var moving=clampf(float(actor.pace)/.45,0.0,1.0)
 if moving>.001:
  var clip="Run" if float(actor.get("speed",0.0))>4.5 else "Walk"
  var time=fposmod(float(actor.get("gait_phase",float(actor.phase)*.1)),1.0)*actor.animator.get_animation(clip).length
  sample(actor,clip,time)
  for i in skeleton.get_bone_count():
   skeleton.set_bone_pose_rotation(i,idle[i].slerp(skeleton.get_bone_pose_rotation(i),moving))
 var locomotion: Array[Quaternion]=[]
 for i in skeleton.get_bone_count(): locomotion.append(skeleton.get_bone_pose_rotation(i))
 var profile: Dictionary=preload("res://weapon_motion.gd").profile(form)
 if active and bool(motion.get("equipped",false)) and actor.animator.has_animation(str(profile.ready)):
  sample(actor,str(profile.ready),0)
  var two_handed: bool=form in ["bow","crossbow","spear","hammer","staff","orb","scythe"]
  for i in skeleton.get_bone_count():
   var name:=skeleton.get_bone_name(i)
   var upper: bool=name.begins_with("clavicle.") or name.begins_with("upper_arm.") or name.begins_with("forearm.") or name.begins_with("hand.") or name.begins_with("fingers.") or name.begins_with("thumb.")
   var amount:=1.0 if two_handed or name.ends_with(".R") else .15
   skeleton.set_bone_pose_rotation(i,locomotion[i].slerp(skeleton.get_bone_pose_rotation(i),amount) if upper else locomotion[i])
  for i in skeleton.get_bone_count():locomotion[i]=skeleton.get_bone_pose_rotation(i)
 if active:
  var clip: String=str(motion.get("clip",profile.clip))
  if clip.is_empty():clip="Cast" if motion.get("ability",false) else str(profile.clip)
  var authored: bool=actor.animator.has_animation(clip)
  if not authored:clip="Cast" if form in ["staff","orb","wand"] else "Attack"
  sample(actor,clip,clampf(phase,0,1)*actor.animator.get_animation(clip).length)
  var weight:=smoothstep(0,.06,phase)*(1.0-smoothstep(.88,1,phase))
  for i in skeleton.get_bone_count():
   var name:=skeleton.get_bone_name(i)
   var lower: bool=name in ["root","pelvis"] or name.begins_with("thigh.") or name.begins_with("shin.") or name.begins_with("foot.")
   skeleton.set_bone_pose_rotation(i,locomotion[i] if lower else locomotion[i].slerp(skeleton.get_bone_pose_rotation(i),weight))
 var blend=1.0-exp(-24.0*maxf(0.0,delta))
 for i in skeleton.get_bone_count():
  skeleton.set_bone_pose_rotation(i,previous[i].slerp(skeleton.get_bone_pose_rotation(i),1.0 if active and not (skeleton.get_bone_name(i).begins_with("thigh.") or skeleton.get_bone_name(i).begins_with("shin.") or skeleton.get_bone_name(i).begins_with("foot.") or skeleton.get_bone_name(i) in ["root","pelvis"]) else blend))

 # Align the lowest sole sample to the floor; height customization remains cosmetic.
 skeleton.force_update_all_bone_transforms()
 # Manual sampling precedes deferred BoneAttachment updates; use this frame’s pose.
 actor.grip.transform=skeleton.get_bone_global_pose(skeleton.find_bone("hand.R"))
 actor.offhand_grip.transform=skeleton.get_bone_global_pose(skeleton.find_bone("hand.L"))
 var lowest=INF
 for contact in actor.foot_contacts:
  lowest=minf(lowest,(skeleton.get_bone_global_pose(contact.bone)*contact.point).y)
 actor.floor_offset=clampf(-lowest*actor.model.scale.y,-.24,.24)
 actor.model.position.y=actor.floor_offset
 FieldRig.animate(actor,active,phase,form,motion,delta)
