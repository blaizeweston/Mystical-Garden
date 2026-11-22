extends RefCounted
## The approved Blender thrust/sweep, retargeted onto either visible character.
## Rotations come from imported clips; companion samples preserve authored wrist
## orientation, elbow planes and sliding contacts across different proportions.
## No gameplay state, clock, damage, locomotion or procedural attack trajectory.
const Native = preload("res://traveller_weapon_animation.gd")
const Locomotion = preload("res://traveller_locomotion.gd")
const THRUST = preload("res://assets/characters/spear_thrust.glb")
const SWEEP = preload("res://assets/characters/spear_sweep.glb")
# Retargeting clearance, measured as a fraction of shoulder width; not combat reach.
const GUIDING_ELBOW_FORWARD_SHOULDERS := .4
static var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/spear_motion.json"))

static func add_clips(library: AnimationLibrary, visual: Node3D, skeleton: Skeleton3D) -> void:
	Native.add_from(library,visual,skeleton,THRUST,"Attack_spear")
	Native.add_from(library,visual,skeleton,SWEEP,"Attack_spear_sweep")

static func calibration(skeleton: Skeleton3D, player: AnimationPlayer, pelvis: int) -> Dictionary:
	var old: Array[Quaternion]=[]
	for bone in skeleton.get_bone_count():old.append(skeleton.get_bone_pose_rotation(bone))
	var old_hips:=skeleton.get_bone_pose_position(pelvis)
	var idle:=Locomotion.clip_pose(skeleton,player,pelvis,Locomotion.IDLE,4.0/24.0)
	var guard:=Locomotion.sample_clip(skeleton,player.get_animation("Attack_spear"),pelvis,0.0,idle.rotations)
	for bone in skeleton.get_bone_count():skeleton.set_bone_pose_rotation(bone,guard.rotations[bone])
	skeleton.set_bone_pose_position(pelvis,idle.pelvis)
	skeleton.force_update_all_bone_transforms()
	var result: Dictionary={}
	var source: Dictionary=data.clips.Attack_spear.samples[0]
	for side in ["r","l"]:
		var bone:=skeleton.find_bone("hand_"+side)
		var wrist:=skeleton.get_bone_global_pose(bone)
		var center:=Vector3.ZERO
		for finger in ["index","middle","ring","pinky"]:
			for joint in [2,3]:center+=skeleton.get_bone_global_pose(skeleton.find_bone("%s_%02d_%s"%[finger,joint,side])).origin
		var key: String="right" if side=="r" else "left"
		result[key]={"bone":bone,"point":wrist.affine_inverse()*(center/8.0),
			"alignment":Basis(quaternion(source[key])).inverse()*wrist.basis}
	for bone in skeleton.get_bone_count():skeleton.set_bone_pose_rotation(bone,old[bone])
	skeleton.set_bone_pose_position(pelvis,old_hips)
	skeleton.force_update_all_bone_transforms()
	return result

static func clip_name(motion: Dictionary) -> String:
	var name: String=motion.get("clip","")
	return name if data.clips.has(name) else "Attack_spear"

static func seconds(player: AnimationPlayer, motion: Dictionary, phase: float, active: bool) -> float:
	if not active:return 0.0
	var name:=clip_name(motion)
	var contact:=float(motion.get("contact",.42))
	var impact:=float(data.clips[name].contact_seconds)
	return lerpf(0,impact,clampf(phase/contact,0,1)) if phase<=contact else lerpf(impact,player.get_animation(name).length,clampf((phase-contact)/(1-contact),0,1))

static func rotations(field: Dictionary, motion: Dictionary, phase: float, active: bool, baseline: Array[Quaternion]) -> Array[Quaternion]:
	var player: AnimationPlayer=field.player
	var name:=clip_name(motion)
	var time:=seconds(player,motion,phase,active)
	if player.current_animation!=name:player.play(name)
	player.seek(time,false)
	return Locomotion.sample_clip(field.skeleton,player.get_animation(name),field.pelvis,time,baseline).rotations

## Detached presentation facts. Grip coordinates are metres in the weapon model;
## elbow vectors and quaternions use the character rig's coordinate space.
static func sample(field: Dictionary, motion: Dictionary, phase: float, active: bool) -> Dictionary:
	var samples: Array=data.clips[clip_name(motion)].samples
	var frame:=clampf(seconds(field.player,motion,phase,active)*float(data.fps),0,samples.size()-1)
	var index:=floori(frame)
	var a: Dictionary=samples[index]
	var b: Dictionary=samples[mini(index+1,samples.size()-1)]
	var t:=frame-index
	var result:={"rear_grip":lerpf(a.rear_grip,b.rear_grip,t),"front_grip":lerpf(a.front_grip,b.front_grip,t)}
	for key in ["weapon","right","left"]:result[key]=Basis(quaternion(a[key]).slerp(quaternion(b[key]),t))
	for key in ["right_elbow","left_elbow"]:result[key]=vector(a[key]).lerp(vector(b[key]),t)
	result.rear_point=vector(a.rear_point).lerp(vector(b.rear_point),t)
	result.shoulder_center=vector(a.shoulder_center).lerp(vector(b.shoulder_center),t)
	result.arm_length=float(a.arm_length)
	return result

static func quaternion(values: Array) -> Quaternion:
	return Quaternion(values[0],values[1],values[2],values[3]).normalized()

static func vector(values: Array) -> Vector3:
	return Vector3(values[0],values[1],values[2])
