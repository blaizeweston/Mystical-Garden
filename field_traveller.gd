extends RefCounted

const Polearms := preload("res://plant_polearms.gd")
const WeaponModels := preload("res://plant_weapon_models.gd")
const Locomotion := preload("res://traveller_locomotion.gd")
const WeaponAnimation := preload("res://traveller_weapon_animation.gd")
const WeaponPoses := preload("res://weapon_pose_catalog.gd")

const MODELS := [
	preload("res://assets/characters/field_traveller_male.glb"),
	preload("res://assets/characters/field_traveller_female.glb"),
]
const DRIVER_JOINTS := {
	"spine_01":"spine", "spine_03":"chest", "neck_01":"neck", "Head":"head",
	"clavicle_l":"clavicle.L", "upperarm_l":"upper_arm.L", "lowerarm_l":"forearm.L", "hand_l":"hand.L",
	"clavicle_r":"clavicle.R", "upperarm_r":"upper_arm.R", "lowerarm_r":"forearm.R", "hand_r":"hand.R",
	"thumb_01_l":"thumb.L", "thumb_01_r":"thumb.R",
	"index_01_l":"fingers.L", "middle_01_l":"fingers.L", "ring_01_l":"fingers.L", "pinky_01_l":"fingers.L",
	"index_01_r":"fingers.R", "middle_01_r":"fingers.R", "ring_01_r":"fingers.R", "pinky_01_r":"fingers.R",
}
static var libraries: Dictionary = {}


static func build(model: Node3D, driver: Skeleton3D, kind: int) -> Dictionary:
	kind = clampi(kind,0,MODELS.size()-1)
	var visual := MODELS[kind].instantiate() as Node3D
	model.add_child(visual)
	var skeleton := visual.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := AnimationPlayer.new()
	visual.add_child(player)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if not libraries.has(kind):
		libraries[kind] = Locomotion.library(visual,skeleton)
		WeaponAnimation.add_clips(libraries[kind],visual,skeleton)
	player.add_animation_library("", libraries[kind])
	var links: Dictionary = {}
	for name in DRIVER_JOINTS:
		var target := skeleton.find_bone(name)
		var source := driver.find_bone(DRIVER_JOINTS[name])
		links[target] = {
			"source":source,
			"alignment":driver.get_bone_global_rest(source).basis.inverse() * skeleton.get_bone_global_rest(target).basis,
		}
	var soles: Array = []
	for side in ["l", "r"]:
		for joint in ["foot_", "ball_"]:
			var bone := skeleton.find_bone(joint + side)
			var rest := skeleton.get_bone_global_rest(bone)
			var point := rest.origin
			point.y = 0.006
			soles.append({"bone":bone, "point":rest.affine_inverse() * point})
	return {
		"scene":visual, "skeleton":skeleton, "player":player, "links":links, "soles":soles,
		"left":socket(skeleton,"l"), "right":socket(skeleton,"r"), "gait":0.0,
		"pelvis":skeleton.find_bone("pelvis"),
	}


static func socket(skeleton: Skeleton3D, side: String) -> Dictionary:
	var bone := skeleton.find_bone("hand_"+side)
	var wrist := skeleton.get_bone_global_rest(bone)
	var middle := skeleton.get_bone_global_rest(skeleton.find_bone("middle_01_"+side))
	return {"bone":bone,"point":wrist.affine_inverse()*wrist.origin.lerp(middle.origin,.57)}


static func hand(actor: Dictionary, left: bool) -> Vector3:
	var field: Dictionary = actor.field_rig
	var anchor: Dictionary = field.left if left else field.right
	var skeleton: Skeleton3D = field.skeleton
	return skeleton.to_global(skeleton.get_bone_global_pose(anchor.bone) * anchor.point)


static func animate(actor: Dictionary, active: bool, phase: float, form: String, motion: Dictionary, delta: float) -> void:
	var field: Dictionary = actor.field_rig
	var skeleton: Skeleton3D = field.skeleton
	var driver: Skeleton3D = actor.skeleton
	var old_pose: Array[Quaternion] = []
	for index in skeleton.get_bone_count():
		old_pose.append(skeleton.get_bone_pose_rotation(index))
	var old_hips := skeleton.get_bone_pose_position(field.pelvis)
	var locomotion := Locomotion.pose(actor,field,delta)
	var native_action: Array[Quaternion] = []
	if active and not bool(motion.get("ability",false)):
		native_action=WeaponAnimation.pose(field,form,phase,int(motion.get("combo",0)))
	var global_bases: Array[Basis] = []
	var pose_blend := 1.0-exp(-20.0*maxf(delta,0))
	skeleton.set_bone_pose_position(field.pelvis,old_hips.lerp(locomotion.pelvis,pose_blend))
	# Imported attacks replace upper-body rotations only; locomotion keeps the legs.
	var action_weight := smoothstep(0.0,.16,phase)*(1.0-smoothstep(.78,1.0,phase)) if active else 0.0
	for index in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(index)
		var parent_basis := global_bases[parent] if parent>=0 else Basis.IDENTITY
		var rotation: Quaternion = locomotion.rotations[index]
		if index==int(field.pelvis):
			var turn := parent_basis.inverse()*Basis(Vector3.UP,float(locomotion.yaw))*parent_basis
			rotation = turn.get_rotation_quaternion()*rotation
		var link: Dictionary = field.links.get(index,{})
		var bone_name := skeleton.get_bone_name(index)
		var native_bone := not native_action.is_empty() and WeaponAnimation.upper_body(bone_name)
		# Constrained grips solve these joints below. Imported arm twists would fight
		# that solution; retain native torso/free-arm motion and locomotion wrists.
		var grip_joint := not native_action.is_empty() and grip_controls_joint(form,bone_name)
		var has_action := action_weight>0.0 and not grip_joint and (native_bone or not link.is_empty())
		if has_action:
			var action_pose: Quaternion
			if native_bone:
				action_pose=native_action[index]
			else:
				var goal: Basis = driver.get_bone_global_pose(link.source).basis * link.alignment
				action_pose=(parent_basis.inverse()*goal).orthonormalized().get_rotation_quaternion()
			rotation = rotation.slerp(action_pose,action_weight)
		rotation = old_pose[index].slerp(rotation,lerpf(pose_blend,1.0,action_weight) if has_action else pose_blend).normalized()
		skeleton.set_bone_pose_rotation(index,rotation)
		global_bases.append(parent_basis*Basis(rotation))
	skeleton.force_update_all_bone_transforms()
	var lowest := INF
	for sole in field.soles:
		lowest = minf(lowest,(skeleton.get_bone_global_pose(sole.bone)*sole.point).y)
	# Keep the authored flight phase. Ground correction only lifts a penetrating sole.
	var penetration := maxf(0.0,-lowest*actor.model.scale.y)
	field.floor_lift=maxf(penetration,move_toward(float(field.get("floor_lift",0.0)),0.0,3.5*delta))
	actor.model.position.y=field.floor_lift
	if not WeaponPoses.DEFINITIONS.has(form) or (active and bool(motion.get("ability",false))):
		return
	pose_weapon_hands(actor,skeleton,field,form,phase,active,motion,action_weight)


static func grip_controls_joint(form: String, bone: String) -> bool:
	if form in ["blade","knives","hammer"]:
		return false
	if not (bone.begins_with("clavicle_") or bone.begins_with("upperarm_") or bone.begins_with("lowerarm_") or bone.begins_with("hand_")):
		return false
	return bone.ends_with("_r") or form in ["spear","hammer","scythe","orb","bow","crossbow"]


static func pose_weapon_hands(actor: Dictionary, skeleton: Skeleton3D, field: Dictionary, form: String, phase: float, active: bool, motion: Dictionary, action_weight: float) -> void:
	var yaw := float(motion.get("aim_yaw",actor.model.rotation.y))
	var aim := Basis(Vector3.UP,yaw)
	var center := shoulder_position(skeleton,field.left).lerp(shoulder_position(skeleton,field.right),.5)
	var orientation := WeaponPoses.orientation(form,phase,active,yaw,motion)
	if form=="bow":
		var release := float(motion.get("contact",.55))
		var draw := smoothstep(0.0,release,phase) if active and phase<release else 1.0-smoothstep(release,release+.08,phase) if active else 0.0
		# Bow and draw hand share the same string plane, including the ready pose.
		var bow_hand := center+aim*WeaponPoses.BOW_CARRY
		var string_offset := orientation*Vector3(0,0,-.20-.25*draw)*Polearms.SCALE
		hold_pair(skeleton,field,bow_hand+string_offset,-string_offset,1.0)
	elif form=="crossbow":
		var rear := center+aim*Vector3(-.075,-.20,.18)
		hold_pair(skeleton,field,rear,orientation*WeaponModels.ARBALEST_SUPPORT*Polearms.SCALE,1.0)
	elif form=="orb":
		var profile: Dictionary = preload("res://weapon_motion.gd").profile(form)
		var focus: Dictionary = WeaponModels.MODELS.orb
		var offset: Vector3 = (focus.core-focus.grip)*Polearms.SCALE
		var ground: Vector3 = actor.model.get_parent_node_3d().global_position
		var release_center := ground+aim*(Vector3(0,float(profile.height),float(profile.muzzle_forward))-offset)
		var held_center := (center+aim*WeaponPoses.ORB_CARRY).lerp(release_center,WeaponPoses.pulse(form,phase,active))
		var separation := aim*Vector3(-.26,0,0)
		hold_pair(skeleton,field,held_center-separation*.5,separation,1.0)
	elif Polearms.WEAPONS.has(form):
		hold_polearm(actor,skeleton,field,form,phase,active,motion,1.0)
	elif form in ["staff","wand"]:
		var profile: Dictionary = preload("res://weapon_motion.gd").profile(form)
		var ground: Vector3 = actor.model.get_parent_node_3d().global_position
		var emitter := ground+aim*Vector3(0,float(profile.height),float(profile.muzzle_forward))
		var target: Vector3 = emitter-orientation*WeaponModels.SPELL_TIPS[form]*Polearms.SCALE
		pose_hand(skeleton,field.right,(center+aim*WeaponPoses.CARRY_RIGHT).lerp(target,WeaponPoses.pulse(form,phase,active)),Vector3(-1,-.7,-.2),1.0)
	elif form in ["ring","whip","bell","censer","fan"]:
		var target := center+aim*WeaponPoses.hand_offset(form,phase,active,int(motion.get("combo",0)))
		pose_hand(skeleton,field.right,target,Vector3(-1,0,-.3),1.0)
	else:
		pose_hand(skeleton,field.right,center+aim*WeaponPoses.CARRY_RIGHT,Vector3(-1,-.65,-.2),1.0-action_weight)
	if form not in ["bow","crossbow","orb","spear","hammer","scythe"]:
		pose_hand(skeleton,field.left,center+aim*WeaponPoses.CARRY_LEFT,Vector3(1,-.65,-.2),1.0-action_weight)


static func hold_polearm(actor: Dictionary, skeleton: Skeleton3D, field: Dictionary, form: String, phase: float, active: bool, motion: Dictionary, weight: float) -> void:
	var yaw := float(motion.get("aim_yaw",actor.model.rotation.y))
	var pose := WeaponPoses.orientation(form,phase,active,yaw,motion)
	var separation := pose.y*Polearms.SCALE*float(Polearms.WEAPONS[form].support)
	var middle := shoulder_position(skeleton,field.right).lerp(shoulder_position(skeleton,field.left),.5)
	var desired := middle+Polearms.grip_target(form,phase,active,yaw)
	# Keep some of the authored strike's hand travel while the paired grips share one shaft.
	hold_pair(skeleton,field,desired,separation,weight)


static func hold_pair(skeleton: Skeleton3D, field: Dictionary, desired: Vector3, separation: Vector3, weight: float) -> void:
	var offset := skeleton.global_basis.inverse()*separation
	var rear := skeleton.to_local(desired)
	var right := palm_reach(skeleton,field.right)
	var left := palm_reach(skeleton,field.left)
	var rear_center := Vector3(right.x,right.y,right.z)
	var support_center := Vector3(left.x,left.y,left.z)-offset
	# Project the rear palm into the intersection of both arms' reach in rig space.
	for pass_index in 4:
		rear = rear_center+(rear-rear_center).limit_length(right.w)
		rear = support_center+(rear-support_center).limit_length(left.w)
	if rear.distance_to(rear_center)>right.w+.001:
		rear = rear_center.lerp(support_center,right.w/(right.w+left.w))
	pose_hand(skeleton,field.right,skeleton.to_global(rear),Vector3(-1,-.78,-.24),weight)
	pose_hand(skeleton,field.left,skeleton.to_global(rear+offset),Vector3(1,-.78,-.24),weight)


static func palm_reach(skeleton: Skeleton3D, palm: Dictionary) -> Vector4:
	var elbow := skeleton.get_bone_parent(palm.bone)
	var shoulder := skeleton.get_bone_parent(elbow)
	var a := skeleton.get_bone_global_pose(shoulder)
	var b := skeleton.get_bone_global_pose(elbow)
	var c := skeleton.get_bone_global_pose(palm.bone)
	var center: Vector3 = a.origin+c.basis*palm.point
	var reach := a.origin.distance_to(b.origin)+b.origin.distance_to(c.origin)-.025
	return Vector4(center.x,center.y,center.z,reach)


static func shoulder_position(skeleton: Skeleton3D, palm: Dictionary) -> Vector3:
	var upper_arm := skeleton.get_bone_parent(skeleton.get_bone_parent(palm.bone))
	return skeleton.to_global(skeleton.get_bone_global_pose(upper_arm).origin)


static func pose_hand(skeleton: Skeleton3D, socket_data: Dictionary, target: Vector3, preferred_elbow: Vector3, weight: float) -> void:
	var wrist: int = socket_data.bone
	var elbow := skeleton.get_bone_parent(wrist)
	var shoulder := skeleton.get_bone_parent(elbow)
	var previous_shoulder := skeleton.get_bone_pose_rotation(shoulder)
	var previous_elbow := skeleton.get_bone_pose_rotation(elbow)
	var previous_wrist := skeleton.get_bone_pose_rotation(wrist)
	var a := skeleton.get_bone_global_pose(shoulder)
	var b := skeleton.get_bone_global_pose(elbow)
	var c := skeleton.get_bone_global_pose(wrist)
	var desired: Vector3 = skeleton.to_local(target)-c.basis*socket_data.point
	var upper := a.origin.distance_to(b.origin)
	var fore := b.origin.distance_to(c.origin)
	var ray := desired-a.origin
	var axis := ray.normalized()
	if axis.is_zero_approx():
		return
	var span := clampf(ray.length(),absf(upper-fore)+.005,upper+fore-.005)
	var current := b.origin-a.origin
	var pole := current if preferred_elbow.is_zero_approx() else preferred_elbow
	var bend := (pole-axis*pole.dot(axis)).normalized()
	if bend.is_zero_approx():
		bend = axis.cross(Vector3.FORWARD).normalized()
	if bend.is_zero_approx():
		bend = Vector3.UP
	var along := (upper*upper-fore*fore+span*span)/(2.0*span)
	var joint := a.origin+axis*along+bend*sqrt(maxf(0,upper*upper-along*along))
	var endpoint := a.origin+axis*span
	var upper_pose := Basis(Quaternion(current.normalized(),(joint-a.origin).normalized()))*a.basis
	set_world_rotation(skeleton,shoulder,upper_pose)
	var posed_elbow := skeleton.get_bone_global_pose(elbow)
	var posed_wrist := skeleton.get_bone_global_pose(wrist)
	var fore_pose := Basis(Quaternion((posed_wrist.origin-posed_elbow.origin).normalized(),(endpoint-posed_elbow.origin).normalized()))*posed_elbow.basis
	set_world_rotation(skeleton,elbow,fore_pose)
	set_world_rotation(skeleton,wrist,c.basis)
	if weight<1.0:
		skeleton.set_bone_pose_rotation(shoulder,previous_shoulder.slerp(skeleton.get_bone_pose_rotation(shoulder),weight))
		skeleton.set_bone_pose_rotation(elbow,previous_elbow.slerp(skeleton.get_bone_pose_rotation(elbow),weight))
		skeleton.set_bone_pose_rotation(wrist,previous_wrist.slerp(skeleton.get_bone_pose_rotation(wrist),weight))
	skeleton.force_update_all_bone_transforms()


static func set_world_rotation(skeleton: Skeleton3D, bone: int, rotation: Basis) -> void:
	# Only write the rotation. Reapplying full transforms can accumulate drift in joint length.
	var parent := skeleton.get_bone_parent(bone)
	var parent_rotation := skeleton.get_bone_global_pose(parent).basis.orthonormalized()
	var local := parent_rotation.transposed()*rotation.orthonormalized()
	skeleton.set_bone_pose_rotation(bone,local.get_rotation_quaternion().normalized())
