extends RefCounted
## Saved fields 0–12 retain their original meanings; optional mesh choices append.
const VERSION := 2
const HOOD := 13
const SHOULDER_ARMOR := 14
const BRACERS := 15
const BELTS := 16
const OPTION_FIELDS = [0,1,2,3,4,HOOD,SHOULDER_ARMOR,BRACERS,BELTS]
const LABELS=["Hood / armor tint","Clothing tint","Hair color","Hair style","Skin tone","Hood","Shoulder armor","Bracers","Extra belts"]
const OPTIONS=[["Muted","Moss","Warm","Cool"],["Muted","Warm","Cool"],["Sandy","Dark brown","Silver"],["Parted","Buns","Long"],["Warm","Deep","Pale"],["Off","On"],["Off","On"],["Off","On"],["Off","On"]]
const TOOLTIPS=["Tints the textured hood and shoulder armor.","Tints the textured Ranger clothing and leather accessories.","Colors hair and eyebrows.","Your selected hairstyle returns when the hood is removed.","Colors exposed skin.","Covers your hair while worn; your hairstyle choice is retained.","Show or hide the separate shoulder armor.","Show or hide the bracers; the arms remain visible.","Show or hide the two additional waist belts; the clothing's fixed belt remains visible."]
const DEFAULT=[0,0,0,0,0,0,50,50,50,50,50,50,50,1,1,1,1]
const SLIDERS=["Height","Build","Shoulders","Face width","Jaw","Nose","Eye size"]
const MORPHS=["Build","Shoulders","FaceWidth","Jaw","Nose","Eyes"]
const MESH_OPTIONS={HOOD:"Ranger_Head_Hood",SHOULDER_ARMOR:"Ranger_Acc_Pauldron",BRACERS:"Ranger_Arms_Bracer",BELTS:"Ranger_Body_Belt_"}

static func option_field(option: int) -> int:
 return OPTION_FIELDS[option] if option >= 0 and option < OPTION_FIELDS.size() else -1

static func normalize(value) -> Array:
 var result=DEFAULT.duplicate()
 if value is Array or value is PackedByteArray:
  for i in mini(value.size(),result.size()):
   var option := OPTION_FIELDS.find(i)
   var maximum: int = OPTIONS[option].size()-1 if option >= 0 else (1 if i == 5 else 100)
   if value[i] is int: result[i]=clampi(value[i],0,maximum)
  # Older characters wore the hood with style zero and all accessories equipped.
  if value.size() <= HOOD: result[HOOD]=1 if result[3] == 0 else 0
 return result

static func cycle_option(value: Array, option: int) -> Array:
 var result := normalize(value)
 var field := option_field(option)
 if field >= 0: result[field]=(int(result[field])+1) % OPTIONS[option].size()
 return result

static func apply(actor: Dictionary, values: Array, tint_materials := true) -> void:
 var look=normalize(values)
 if actor.get("look_key","")==str(look): return
 if actor.has("rig_kind") and actor.rig_kind!=look[5]: preload("res://traveller_avatar.gd").swap(actor,look[5])
 actor.look_key=str(look)
 actor.model.scale=Vector3(1,lerpf(.92,1.08,look[6]/100.0),1)
 var colors := {}
 colors.FieldCloth=[Color("#bdab92"),Color("#c1a271"),Color("#a1aeb6")][look[1]]
 colors.FieldHood=[Color("#95998c"),Color("#b4c19d"),Color("#b5a17d"),Color("#98acb4")][look[0]]
 colors.FieldSkin=[Color("#e4ba96"),Color("#a37d64"),Color("#f4e1cb")][look[4]]
 colors.FieldHair=[Color("#b6957c"),Color("#716b65"),Color("#f2eeea")][look[2]]
 for mesh in actor.field_rig.scene.find_children("*","MeshInstance3D",true,false):
  for i in range(mesh.get_blend_shape_count()):
   var index=MORPHS.find(str(mesh.mesh.get_blend_shape_name(i)))
   if index>=0: mesh.set_blend_shape_value(i,(look[index+7]-50)/50.0)
  for i in (mesh.mesh.get_surface_count() if tint_materials and DisplayServer.get_name()!="headless" else 0):
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
    material.albedo_color=colors[key]
  if str(mesh.name).begins_with("FieldHair"):
   mesh.visible=look[HOOD]==0 and str(mesh.name).begins_with("FieldHair"+str(look[3]))
  for field: int in MESH_OPTIONS:
   if MESH_OPTIONS[field] in str(mesh.name): mesh.visible=look[field]==1
