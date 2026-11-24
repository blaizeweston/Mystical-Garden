extends SceneTree
const Appearance=preload("res://character_appearance.gd")
const Avatar=preload("res://traveller_avatar.gd")
var failed=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL character rig: ",message)
func _initialize(): call_deferred("run")
func run():
 var host=Node3D.new();root.add_child(host)
 var a=Avatar.build(host);var b=Avatar.build(host)
 var look=Appearance.DEFAULT.duplicate();look[5]=1;look[6]=100;look[7]=85;look[3]=2;look[Appearance.HOOD]=0
 Appearance.apply(a,look);Appearance.apply(b,[])
 check(a.rig_kind==1 and b.rig_kind==0,"independent male and female models")
 for actor in [a,b]:
  var field: Dictionary=actor.field_rig
  check(field.scene.visible and field.skeleton.get_bone_count()==65,"current traveller rig is visible")
  check(actor.model.find_children("*","Skeleton3D",true,false)==[field.skeleton],"exactly one skeleton after creation and body swap")
  check(actor.model.find_children("*","AnimationPlayer",true,false)==[field.player],"only one animation player per traveller")
  check(field.skeleton.get_bone_name(field.right.bone)=="hand_r" and field.skeleton.get_bone_name(field.left.bone)=="hand_l","both grips belong to the rendered skeleton")
  var skills: Array=["Cast"]+preload("res://subclass_combat.gd").CLIPS.values()
  for clip: String in skills:
   check(field.skill_poses.has_animation(clip),"native traveller skill pose: "+clip)
   var joint: int=field.skeleton.find_bone("hand_r")
   Avatar.animate(actor,false,0,"",{},1.0)
   var ready: Basis=field.skeleton.get_bone_global_pose(joint).basis
   Avatar.animate(actor,true,.5,"staff",{"ability":true,"clip":clip},1.0)
   check(ready.get_rotation_quaternion().angle_to(field.skeleton.get_bone_global_pose(joint).basis.get_rotation_quaternion())>.05,"class action moves visible hand: "+clip)
  for clip in ["Idle","Walk","Jog_Fwd","Sprint"]:
   check(field.player.has_animation(clip),"retargeted field locomotion: "+clip)
  var shapes: Dictionary={}
  for mesh in field.scene.find_children("*","MeshInstance3D",true,false):
   check(mesh.skin!=null,"field mesh is attached to its imported rig")
   for i in mesh.get_blend_shape_count():
    shapes[str(mesh.mesh.get_blend_shape_name(i))]=mesh.get_blend_shape_value(i)
  for i in Appearance.MORPHS.size():
   check(shapes.has(Appearance.MORPHS[i]),"visible field mesh has morph "+Appearance.MORPHS[i])
  check(is_equal_approx(shapes.get("Build",0.0),.7 if actor==a else 0.0),"existing build slider applies to visible outfit")
  for style in 3:
   var hair: Node3D=field.scene.find_child("FieldHair"+str(style),true,false)
   check(hair!=null and hair.visible==(style==2 if actor==a else false),"hood covers hair without changing the saved choice")
 check(is_equal_approx(a.model.scale.y,1.08),"height slider scales the rendered traveller")
 check(Appearance.normalize([999,-1,0,0,0,999,-8,999]).slice(5,8)==[1,0,100],"appearance network values bounded")
 var roster=load("res://character_slots.gd").new();roster.root_path="res://.godot/rig-roster-"+str(Time.get_ticks_usec())
 check(roster.create(0,"Rowan",0,[])==OK,"create roster")
 var profile=load("res://character_profile.gd").new();profile.path=roster.paths(0).character;profile.load_profile()
 var identity=profile.identity;profile.data.xp[0]=27;profile.data.plants[0]=8;profile.save_profile()
 check(roster.update(0,"Mira",1,look)==OK,"customize existing character")
 profile.load_profile()
 check(profile.identity==identity and profile.data.xp[0]==27 and profile.data.plants[0]==8 and profile.data.appearance==look,"customization preserves identity and progression")
 var creator=load("res://character_creator.gd").new();root.add_child(creator);creator.begin(profile.data)
 check(creator.appearance()==look and creator.sliders.size()==7,"creator restores sliders")
 creator.dismiss();creator.queue_free();host.queue_free();await process_frame
 if not failed: print("PASS: rigged models, sliders, animation, hand grip and safe customization")
 quit(1 if failed else 0)
