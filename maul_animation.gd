extends RefCounted
## Reviewed Blender Maul actions on either traveller rig. This is presentation
## only: the host weapon timeline still owns cadence, contact and alternation.
const Native = preload("res://traveller_weapon_animation.gd")
const Locomotion = preload("res://traveller_locomotion.gd")
const CLIPS := {
	"Attack_maul_overhead":preload("res://assets/characters/maul_overhead.glb"),
	"Attack_maul_sweep":preload("res://assets/characters/maul_sweep.glb"),
	"Recover_maul_overhead":preload("res://assets/characters/maul_recover_overhead.glb"),
	"Recover_maul_sweep":preload("res://assets/characters/maul_recover_sweep.glb"),
	"Ready_maul":preload("res://assets/characters/maul_ready.glb"),
	"Ready_maul_sweep":preload("res://assets/characters/maul_sweep_ready.glb"),
}
# Visual blending/recovery only, in seconds; neither delays the next attack.
const RECOVERY_SECONDS := .24
const REGRIP_SECONDS := .08
static var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/maul_motion.json"))

static func add_clips(library: AnimationLibrary, visual: Node3D, skeleton: Skeleton3D) -> void:
	for name in CLIPS:Native.add_from(library,visual,skeleton,CLIPS[name],name)

static func calibration(skeleton: Skeleton3D, player: AnimationPlayer, pelvis: int) -> Dictionary:
	var old: Array[Quaternion]=[]
	for bone in skeleton.get_bone_count():old.append(skeleton.get_bone_pose_rotation(bone))
	var hips:=skeleton.get_bone_pose_position(pelvis)
	var idle:=Locomotion.clip_pose(skeleton,player,pelvis,Locomotion.IDLE,4.0/24.0)
	var ready:=Locomotion.sample_clip(skeleton,player.get_animation("Ready_maul"),pelvis,0,idle.rotations)
	for bone in skeleton.get_bone_count():skeleton.set_bone_pose_rotation(bone,ready.rotations[bone])
	skeleton.set_bone_pose_position(pelvis,idle.pelvis)
	skeleton.force_update_all_bone_transforms()
	var result: Dictionary={"pelvis_basis":skeleton.get_bone_global_pose(pelvis).basis.orthonormalized()}
	var source: Dictionary=sample_at("Ready_maul",0)
	for side in ["r","l"]:
		var bone:=skeleton.find_bone("hand_"+side)
		var wrist:=skeleton.get_bone_global_pose(bone)
		var center:=Vector3.ZERO
		for finger in ["index","middle","ring","pinky"]:
			for joint in [2,3]:center+=skeleton.get_bone_global_pose(skeleton.find_bone("%s_%02d_%s"%[finger,joint,side])).origin
		var key: String="right" if side=="r" else "left"
		result[key]={"bone":bone,"point":wrist.affine_inverse()*(center/8.0),"alignment":Basis(source[key]).inverse()*wrist.basis}
	for bone in skeleton.get_bone_count():skeleton.set_bone_pose_rotation(bone,old[bone])
	skeleton.set_bone_pose_position(pelvis,hips)
	skeleton.force_update_all_bone_transforms()
	return result

static func clear(field: Dictionary) -> void:
	for key in ["was_active","last_attack","recover_elapsed","entry_elapsed","entry_sample","entry_rotations","sequence","rotations"]:
		field.maul.erase(key)
	field.erase("maul_sample")

## The two source stances have different hand ordering. Briefly blend the
## reviewed poses when an admitted attack changes stance; never alter its clock.
static func rotations(field: Dictionary, motion: Dictionary, phase: float, active: bool, baseline: Array[Quaternion], delta: float) -> Array[Quaternion]:
	var state: Dictionary=field.maul
	var player: AnimationPlayer=field.player
	var name: String=motion.get("clip","Attack_maul_overhead")
	if name not in ["Attack_maul_overhead","Attack_maul_sweep"]:name="Attack_maul_overhead"
	var time:=0.0
	if active:
		var sequence:=int(motion.get("combo",0))
		if sequence!=int(state.get("sequence",-1)) or not state.get("was_active",false):
			state.entry_elapsed=0.0
			state.entry_sample=field.get("maul_sample",{})
			state.entry_rotations=state.get("rotations",[])
		state.sequence=sequence
		state.last_attack=name
		state.recover_elapsed=0.0
		var contact:=float(motion.get("contact",.48))
		var impact:=float(data.clips[name].contact_seconds)
		time=lerpf(0,impact,clampf(phase/contact,0,1)) if phase<=contact else lerpf(impact,float(data.clips[name].duration_seconds),clampf((phase-contact)/(1-contact),0,1))
	else:
		var sweep: bool=state.get("last_attack","")=="Attack_maul_sweep"
		var elapsed:=float(state.get("recover_elapsed",RECOVERY_SECONDS))+maxf(0,delta)
		state.recover_elapsed=elapsed
		if elapsed<RECOVERY_SECONDS:
			name="Recover_maul_sweep" if sweep else "Recover_maul_overhead"
			time=elapsed/RECOVERY_SECONDS*float(data.clips[name].duration_seconds)
		else:name="Ready_maul_sweep" if sweep else "Ready_maul"
	state.was_active=active
	if player.current_animation!=name:player.play(name)
	player.seek(time,false)
	var rotations: Array[Quaternion]=Locomotion.sample_clip(field.skeleton,player.get_animation(name),field.pelvis,time,baseline).rotations
	var sample:=sample_at(name,time)
	if active and not state.get("entry_sample",{}).is_empty() and not state.get("entry_rotations",[]).is_empty():
		state.entry_elapsed=float(state.get("entry_elapsed",0.0))+maxf(0,delta)
		var weight:=smoothstep(0,REGRIP_SECONDS,float(state.entry_elapsed))
		sample=blend_samples(state.entry_sample,sample,weight)
		for bone in rotations.size():
			if Native.upper_body(field.skeleton.get_bone_name(bone)):rotations[bone]=state.entry_rotations[bone].slerp(rotations[bone],weight)
	state.rotations=rotations
	field.maul_sample=sample
	return rotations

## Detached samples: grip coordinates in model metres, other values in rig space.
static func sample_at(name: String, seconds: float) -> Dictionary:
	var samples: Array=data.clips[name].samples
	var frame:=clampf(seconds*float(data.fps),0,samples.size()-1)
	var index:=floori(frame)
	return blend_samples(decoded(samples[index]),decoded(samples[mini(index+1,samples.size()-1)]),frame-index)

static func decoded(sample: Dictionary) -> Dictionary:
	var result:=sample.duplicate()
	for key in ["weapon","right","left"]:
		var values: Array=sample[key]
		result[key]=Quaternion(values[0],values[1],values[2],values[3]).normalized()
	for key in ["right_elbow","left_elbow","right_point","shoulder_center"]:
		var values: Array=sample[key]
		result[key]=Vector3(values[0],values[1],values[2])
	return result

static func blend_samples(a: Dictionary, b: Dictionary, weight: float) -> Dictionary:
	var result: Dictionary={}
	for key in ["weapon","right","left"]:result[key]=a[key].slerp(b[key],weight)
	for key in ["right_elbow","left_elbow","right_point","shoulder_center"]:result[key]=a[key].lerp(b[key],weight)
	for key in ["right_grip","left_grip","arm_length"]:result[key]=lerpf(a[key],b[key],weight)
	return result
