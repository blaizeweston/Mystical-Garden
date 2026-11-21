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
  check(actor.skeleton.get_bone_count()==25 and actor.skeleton.find_bone("hand.R")>=0,"shared 25-joint animation rig")
  check(actor.grip.get_parent()==actor.skeleton and actor.grip.bone_name=="hand.R","weapon grip bound to hand")
  for clip in ["Idle","Walk","Run","Attack","Cast","Guard"]: check(actor.animator.has_animation(clip),"authored clip "+clip)
  for m in actor.rig.find_children("*","MeshInstance3D",true,false):
   check(m.skin!=null and m.get_blend_shape_count()==6,"existing action driver retains its source rig")
  var field: Dictionary=actor.field_rig
  check(not actor.rig.visible and field.scene.visible and field.skeleton.get_bone_count()==65,"field rig is the visible traveller")
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
 var body=a.rig.find_child("TravellerBody*",true,false)
 check(is_equal_approx(body.get_blend_shape_value(0),.7) and is_equal_approx(a.model.scale.y,1.08),"sliders deform model within bounds")
 # Inspect imported vertex positions, so a cumulative Blender morph cannot pass.
 for actor in [a,b]:
  var body_mesh=actor.rig.find_child("TravellerBody*",true,false).mesh
  var changed={}
  for surface in body_mesh.get_surface_count():
   var basis=body_mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
   var targets=body_mesh.surface_get_blend_shape_arrays(surface)
   for shape in targets.size():
    var name=str(body_mesh.get_blend_shape_name(shape))
    var points=targets[shape][Mesh.ARRAY_VERTEX]
    for vertex in points.size():
     var difference=points[vertex]-basis[vertex]
     if difference.length()>.00001: changed[name]=true
     if name in ["FaceWidth","Jaw","Nose","Eyes"] and basis[vertex].y<1.46:
      if difference.length()>.00001: check(false,"facial morph changed torso: "+name);break
     if name=="Nose" and absf(difference.x)>.00001:
      check(false,"nose morph changed width");break
  check(changed.size()==6,"all six shapes independently affect their intended features")
 var female_mesh=a.rig.find_child("TravellerBody*",true,false).mesh
 var male_mesh=b.rig.find_child("TravellerBody*",true,false).mesh
 var female_front=0.0;var male_front=0.0
 for pair in [[female_mesh,true],[male_mesh,false]]:
  for surface in pair[0].get_surface_count():
   var material=pair[0].surface_get_material(surface)
   if material.resource_name!="Tunic": continue
   for point in pair[0].surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
    if point.y>1.20 and point.y<1.33:
     if pair[1]: female_front=maxf(female_front,point.z)
     else: male_front=maxf(male_front,point.z)
 check(female_front>male_front+.035,"female tunic includes modeled breast volume")
 var hand=a.skeleton.find_bone("upper_arm.R")
 Avatar.animate(a,true,.5,"staff")
 check(not a.skeleton.get_bone_pose_rotation(hand).is_equal_approx(Quaternion.IDENTITY),"animation moves joints")
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
