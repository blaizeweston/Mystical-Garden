extends RefCounted
const LABELS=["Cloak","Tunic","Hair color","Hair style","Skin"]
const OPTIONS=[["Charcoal","Moss","Umber","Blue gray"],["Moss","Ochre","Slate"],["Chestnut","Black","Silver"],["Tousled","Tied","Long"],["Warm","Deep","Pale"]]
const DEFAULT=[0,0,0,0,0,0,50,50,50,50,50,50,50]
const SLIDERS=["Height","Build","Shoulders","Face width","Jaw","Nose","Eye size"]
const MORPHS=["Build","Shoulders","FaceWidth","Jaw","Nose","Eyes"]
static func normalize(value) -> Array:
 var result=DEFAULT.duplicate()
 if value is Array:
  for i in mini(value.size(),result.size()):
   if value[i] is int: result[i]=clampi(value[i],0,[3,2,2,2,2,1][i] if i<6 else 100)
 return result
static func apply(actor: Dictionary, values: Array) -> void:
 var look=normalize(values)
 if actor.get("look_key","")==str(look): return
 if actor.has("rig_kind") and actor.rig_kind!=look[5]: preload("res://traveller_avatar.gd").swap(actor,look[5])
 actor.look_key=str(look)
 actor.model.scale=Vector3(1,lerpf(.92,1.08,look[6]/100.0),1)
 var colors={"Cloak":[Color("34383c"),Color("455339"),Color("594431"),Color("465766")][look[0]],"Tunic":[Color("596340"),Color("8a703e"),Color("4f5b60")][look[1]],"Hair":[Color("40281b"),Color("201d1b"),Color("a4a193")][look[2]],"Skin":[Color("c79b73"),Color("754b35"),Color("e5c6a7")][look[4]]}
 colors.HairDetail=colors.Hair.lightened(.12)
 colors.FieldCloth=[Color("#bdab92"),Color("#c1a271"),Color("#a1aeb6")][look[1]]
 colors.FieldHood=[Color("#95998c"),Color("#b4c19d"),Color("#b5a17d"),Color("#98acb4")][look[0]]
 colors.FieldSkin=[Color("#e4ba96"),Color("#a37d64"),Color("#f4e1cb")][look[4]]
 colors.FieldHair=[Color("#b6957c"),Color("#716b65"),Color("#f2eeea")][look[2]]
 for mesh in actor.model.find_children("*","MeshInstance3D",true,false):
  for i in range(mesh.get_blend_shape_count()):
   var index=MORPHS.find(str(mesh.mesh.get_blend_shape_name(i)))
   if index>=0: mesh.set_blend_shape_value(i,(look[index+7]-50)/50.0)
  for i in (mesh.mesh.get_surface_count() if DisplayServer.get_name()!="headless" else 0):
   var original=mesh.mesh.surface_get_material(i)
   if original==null: continue
   var key=str(original.resource_name)
   for group in ["FieldCloth","FieldHood","FieldSkin","FieldHair"]:
    if key.begins_with(group):
     key=group
     break
   if "Eyebrows"==str(mesh.name) and key.begins_with("MI_Hair"):
    key="FieldHair"
   if colors.has(key):
    var material=mesh.get_surface_override_material(i)
    if material==null:
     material=original.duplicate();mesh.set_surface_override_material(i,material)
     if not actor.has("materials"): actor.materials=[]
     actor.materials.append(material)
    material.albedo_color=colors[key]
  if str(mesh.name).begins_with("AdventurerHair"):
   mesh.visible=str(mesh.name).begins_with("AdventurerHair"+str(look[3]))
  if str(mesh.name).begins_with("FieldHair"):
   mesh.visible=str(mesh.name).begins_with("FieldHair"+str(look[3]))
  if "Ranger_Head_Hood" in str(mesh.name):
   mesh.visible=look[3]==0
