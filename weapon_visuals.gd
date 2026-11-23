extends RefCounted
# Shared grip-space weapon kit with independently animated bow strings and vine segments.
const Classes=preload("res://class_catalog.gd")
const FieldRig=preload("res://field_traveller.gd")
const WeaponPoses=preload("res://weapon_pose_catalog.gd")
const Polearms=preload("res://plant_polearms.gd")
const ROOTBLADE=preload("res://assets/weapons/rootblade.glb")
const VINE_BOW=preload("res://assets/weapons/vine_bow.glb")
const Models=preload("res://plant_weapon_models.gd")
static func build(stage: Node3D,class_id: int,weapon_id: int) -> Node3D:
 var root:=Node3D.new()
 stage.add_child(root)
 var form: String=Classes.DEFINITIONS[class_id].weapons[weapon_id].visual
 var wood:=Color("#684c2d")
 var steel:=Color("#d7dfc8")
 var seed_position:=Vector3(0,.13,.08)
 var handle:=Vector3.ZERO
 if Models.MODELS.has(form):
  Models.attach(root,form)
  handle=Models.MODELS[form].grip
  seed_position=Models.MODELS[form].core
 match form:
  "blade":
   var blade:=ROOTBLADE.instantiate()
   blade.name="RootbladeModel"
   root.add_child(blade)
  "spear","hammer","scythe":
   var definition: Dictionary=Polearms.WEAPONS[form]
   var model: Node3D=definition.scene.instantiate()
   model.name=definition.name
   root.add_child(model)
   marker(root,"WeaponTip",definition.tip)
   root.set_meta("support_grip",Vector3(0,definition.support,0))
   seed_position=definition.seed
  "staff","wand":
   marker(root,"WeaponTip",Models.SPELL_TIPS[form])
  "bow","crossbow":
   var bow:=form=="bow"
   if bow:
    var model:=VINE_BOW.instantiate()
    model.name="VineBowModel"
    root.add_child(model)
    handle=Vector3(0,.2,0)
   else:
    root.set_meta("support_grip",handle+Models.ARBALEST_SUPPORT)
    marker(root,"WeaponTip",Models.ARBALEST_TRACK)
   var nock:=Vector3(0,.2,-.20) if bow else Models.ARBALEST_NOCK
   for side in [-1.0,1.0]:
    var string:=rod(stage,root,limb_tip(form,side),nock,.006,Color("#d9d0ae"))
    string.name="StringLower" if side<0 else "StringUpper"
   var arrow:=Node3D.new()
   arrow.name="NockedArrow"
   root.add_child(arrow)
   var tip:=Vector3(0,.2,.65) if bow else Models.ARBALEST_TRACK
   rod(stage,arrow,nock,tip,.009,wood)
   rod(stage,arrow,tip-Vector3.BACK*.10,tip,.023,steel)
  "whip":
   var segments: Array[Node3D]=[]
   for i in 18:
    var piece: Node3D=Models.LASH_SEGMENT.instantiate()
    root.add_child(piece)
    segments.append(piece)
   root.set_meta("vine_segments",segments)
 # A material-colored seed set into every weapon makes Core changes visible.
 var gem: MeshInstance3D=stage.sphere(seed_position,.055,Color("#a3bf7c"))
 gem.name="CoreSeed"
 gem.reparent(root,false)
 root.set_meta("handle",handle)
 root.scale=Vector3.ONE*.9
 return root
static func marker(root: Node3D, label: String, at: Vector3) -> void:
 var marker_node:=Node3D.new()
 marker_node.name=label
 root.add_child(marker_node)
 marker_node.position=at

static func limb_tip(form: String, side: float) -> Vector3:
 if form=="bow":
  return Vector3(0,.2+side*.5,-.10)
 return Models.ARBALEST_TIP*Vector3(side,1,1)
static func rod(stage: Node3D,root: Node3D,a: Vector3,b: Vector3,radius: float,color: Color) -> MeshInstance3D:
 var shape:=CylinderMesh.new()
 shape.height=a.distance_to(b)
 shape.top_radius=radius*.8
 shape.bottom_radius=radius
 shape.radial_segments=8
 var node: MeshInstance3D=stage.mesh(shape,(a+b)/2,color)
 node.basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()))
 node.reparent(root,false)
 return node


static func segment(node: Node3D,a: Vector3,b: Vector3,rest_length: float=0.0,thickness: float=1.0) -> void:
 if rest_length<=0.0:
  rest_length=((node as MeshInstance3D).mesh as CylinderMesh).height
 var direction:=b-a
 node.position=(a+b)*.5
 node.basis=Basis(Quaternion(Vector3.UP,direction.normalized())).scaled_local(Vector3(thickness,direction.length()/maxf(.001,rest_length),thickness))
static func animate(actor: Dictionary,form: String,phase: float,active: bool,yaw: float,reach: float,action: Dictionary={}) -> void:
 var profile: Dictionary=preload("res://weapon_motion.gd").profile(form)
 var contact:=float(profile.release)
 var primary: Node3D=actor.visual_weapon
 var right:=FieldRig.hand(actor,false)
 var left:=FieldRig.hand(actor,true)
 var anchor:=left if form=="bow" else right
 var focus_cast: bool = form=="orb" and actor.field_rig.focus.has("offset")
 if focus_cast:anchor=preload("res://seed_focus_animation.gd").held_center(actor.field_rig)
 elif form=="orb":anchor=(right+left)*.5
 var pose:=FieldRig.weapon_orientation(actor,form,phase,active,yaw,action)
 if form=="hammer" and actor.field_rig.get("maul_active",false):
  var sample: Dictionary=actor.field_rig.maul_sample
  primary.set_meta("handle",Vector3.UP*float(sample.right_grip))
  primary.set_meta("support_grip",Vector3.UP*float(sample.left_grip))
 elif form=="spear" and actor.field_rig.get("spear_active",false):
  var sample: Dictionary=actor.field_rig.spear_sample
  primary.set_meta("handle",Vector3.UP*float(sample.rear_grip))
  primary.set_meta("support_grip",Vector3.UP*float(sample.front_grip))
 elif Polearms.WEAPONS.has(form):
  primary.set_meta("handle",Vector3.ZERO)
  primary.set_meta("support_grip",Vector3.UP*Polearms.support_distance(form,phase,active,action))
 var held_size := float(actor.field_rig.focus.held_scale) if focus_cast else 1.0
 var basis:=pose.scaled(Vector3.ONE*Polearms.SCALE*maxf(.001,held_size))
 primary.global_transform=Transform3D(basis,anchor-basis*Vector3(primary.get_meta("handle",Vector3.ZERO)))
 primary.visible=held_size>.001 if focus_cast else not (form in ["ring","orb"] and active and phase>contact and phase<.82)
 if actor.has("secondary_weapon"):
  var other: Node3D=actor.secondary_weapon
  other.global_transform=Transform3D(WeaponPoses.orientation(form,phase,active,yaw,action,true).scaled(Vector3.ONE*.9),left)
 if form in ["bow","crossbow"]:
  var draw:=smoothstep(0,contact,phase) if active and phase<contact else (1-smoothstep(contact,contact+.08,phase)) if active else 0.0
  var offset:=Vector3.BACK*(-.25 if form=="bow" else -.15)*draw
  var nock:=Vector3(0,.2,-.20) if form=="bow" else Models.ARBALEST_NOCK
  for side in [-1.0,1.0]:
   var string: MeshInstance3D=primary.get_node("StringLower" if side<0 else "StringUpper")
   segment(string,limb_tip(form,side),nock+offset)
  var arrow: Node3D=primary.get_node("NockedArrow")
  arrow.visible=active and phase<contact
  arrow.position=offset
 if form=="whip":
  var nodes: Array=primary.get_meta("vine_segments")
  var extension:=smoothstep(0,contact,phase) if phase<contact else 1-smoothstep(contact,1,phase)
  if not active:extension=0
  var length:=maxf(.4,reach-.4)/Polearms.SCALE
  var prior:=lash_point(0,extension,length)
  for i in nodes.size():
   var along: float=(i+1)/float(nodes.size())
   var next:=lash_point(along,extension,length)
   segment(nodes[i],prior,next,1.0,lerpf(1.32,.27,along))
   prior=next


static func lash_point(along: float, extension: float, length: float) -> Vector3:
 var coil:=1.0-extension
 var turn:=along*TAU*1.45
 return Vector3(sin(turn)*.155*coil,.12-along*.32*coil,along*length*extension+(1-cos(turn))*.105*coil)
