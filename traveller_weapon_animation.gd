extends RefCounted
## Samples imported upper-body rotations on the existing visible rig.
## It owns no attacks, clocks, cooldowns, movement or player records.
const DONOR = preload("res://assets/characters/weapon_combat.glb")
const Poses = preload("res://weapon_pose_catalog.gd")
const Motion = preload("res://weapon_motion.gd")
const Locomotion = preload("res://traveller_locomotion.gd")

static func upper_body(name: String) -> bool:
	return name=="Head" or name.begins_with("spine_") or name.begins_with("neck_") or name.begins_with("clavicle_") or name.begins_with("upperarm_") or name.begins_with("lowerarm_") or name.begins_with("hand_") or name.begins_with("thumb_") or name.begins_with("index_") or name.begins_with("middle_") or name.begins_with("ring_") or name.begins_with("pinky_")

static func add_clips(result: AnimationLibrary, visual: Node3D, skeleton: Skeleton3D) -> void:
	add_from(result,visual,skeleton,DONOR)

## One retargeting rule for library clips and the separately authored spear actions.
static func add_from(result: AnimationLibrary, visual: Node3D, skeleton: Skeleton3D, scene: PackedScene, renamed: String = "") -> void:
	var donor := scene.instantiate()
	var source := donor.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var player := donor.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	var target_path := str(visual.get_path_to(skeleton))
	for name in player.get_animation_list():
		if name=="RESET": continue
		var clip := player.get_animation(name).duplicate() as Animation
		clip.loop_mode=Animation.LOOP_NONE
		for track in range(clip.get_track_count()-1,-1,-1):
			var path := clip.track_get_path(track)
			var bone := path.get_subname(0) if path.get_subname_count()>0 else &""
			var target := skeleton.find_bone(bone)
			var origin := source.find_bone(bone)
			if clip.track_get_type(track)!=Animation.TYPE_ROTATION_3D or target<0 or origin<0 or not upper_body(str(bone)):
				clip.remove_track(track); continue
			clip.track_set_path(track,NodePath(target_path+":"+str(bone)))
			var correction := skeleton.get_bone_rest(target).basis.get_rotation_quaternion()*source.get_bone_rest(origin).basis.get_rotation_quaternion().inverse()
			for key in clip.track_get_key_count(track):
				var rotation: Quaternion=clip.track_get_key_value(track,key)
				clip.track_set_key_value(track,key,(correction*rotation).normalized())
		result.add_animation(renamed if not renamed.is_empty() else str(name),clip)
	donor.free()

## One time mapping for imported rotations and their companion grip samples.
static func playback(player: AnimationPlayer, form: String, phase: float, combo: int, preferred_clip: String="") -> Dictionary:
	var definition: Dictionary=Poses.DEFINITIONS.get(form,{})
	var clips: Array=definition.get("clips",[])
	if clips.is_empty(): return {}
	var index := clips.find(preferred_clip) if clips.has(preferred_clip) else posmod(combo,clips.size())
	var name: String=clips[index]
	var length := player.get_animation(name).length
	var recoveries: Array=definition.get("recoveries",[])
	var recovery: String=recoveries[index] if index<recoveries.size() else ""
	var total := length+(player.get_animation(recovery).length if not recovery.is_empty() and not definition.get("separate_recovery",false) else 0.0)
	var impact := length*float(definition.get("impact",0.55))
	var contact := float(Motion.profile(form).release)
	var time := lerpf(0.0,impact,clampf(phase/contact,0,1)) if phase<=contact else lerpf(impact,total,clampf((phase-contact)/(1.0-contact),0,1))
	if time>length and not recovery.is_empty(): name=recovery; time-=length
	return {"clip":name,"time":clampf(time,0.0,player.get_animation(name).length-0.00001)}

static func pose(field: Dictionary, form: String, phase: float, combo: int, baseline: Array[Quaternion]=[], preferred_clip: String="") -> Array[Quaternion]:
	var timing:=playback(field.player,form,phase,combo,preferred_clip)
	if timing.is_empty():return []
	var name: String=timing.clip
	var time: float=timing.time
	var player: AnimationPlayer=field.player
	if player.current_animation!=name: player.play(name)
	player.seek(time,false)
	return Locomotion.sample_clip(field.skeleton,player.get_animation(name),field.pelvis,time,baseline).rotations


## Calibrate authored two-hand grips without retaining or changing the current pose.
static func paired_calibration(skeleton: Skeleton3D, player: AnimationPlayer, pelvis: int, ready_name: String, ready_sample: Dictionary) -> Dictionary:
	var old: Array[Quaternion]=[]
	for bone in skeleton.get_bone_count():old.append(skeleton.get_bone_pose_rotation(bone))
	var hips:=skeleton.get_bone_pose_position(pelvis)
	var idle:=Locomotion.clip_pose(skeleton,player,pelvis,Locomotion.IDLE,4.0/24.0)
	var ready:=Locomotion.sample_clip(skeleton,player.get_animation(ready_name),pelvis,0,idle.rotations)
	for bone in skeleton.get_bone_count():skeleton.set_bone_pose_rotation(bone,ready.rotations[bone])
	skeleton.set_bone_pose_position(pelvis,idle.pelvis)
	skeleton.force_update_all_bone_transforms()
	var result: Dictionary={"pelvis_basis":skeleton.get_bone_global_pose(pelvis).basis.orthonormalized()}
	var source: Dictionary=ready_sample
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

static func grip_sample(data: Dictionary, name: String, seconds: float) -> Dictionary:
	var samples: Array=data.clips[name].samples
	var frame:=clampf(seconds*float(data.fps),0,samples.size()-1)
	var index:=floori(frame)
	return blend_grip_samples(decode_grip_sample(samples[index]),decode_grip_sample(samples[mini(index+1,samples.size()-1)]),frame-index)

static func decode_grip_sample(sample: Dictionary) -> Dictionary:
	var result:=sample.duplicate()
	for key in ["weapon","right","left"]:
		var values: Array=sample[key]
		result[key]=Quaternion(values[0],values[1],values[2],values[3]).normalized()
	for key in ["right_elbow","left_elbow","right_point","shoulder_center"]:
		var values: Array=sample[key]
		result[key]=Vector3(values[0],values[1],values[2])
	return result

static func blend_grip_samples(a: Dictionary, b: Dictionary, weight: float) -> Dictionary:
	var result: Dictionary={}
	for key in ["weapon","right","left"]:result[key]=a[key].slerp(b[key],weight)
	for key in ["right_elbow","left_elbow","right_point","shoulder_center"]:result[key]=a[key].lerp(b[key],weight)
	for key in ["right_grip","left_grip","arm_length"]:result[key]=lerpf(a[key],b[key],weight)
	return result

## Project one palm into the intersection of both arms' reach (rig metres).
static func fit_grip_pair(desired: Vector3, offset: Vector3, right: Vector4, left: Vector4) -> Vector3:
	var rear:=desired
	var rear_center:=Vector3(right.x,right.y,right.z)
	var support_center:=Vector3(left.x,left.y,left.z)-offset
	for pass_index in 4:
		rear=rear_center+(rear-rear_center).limit_length(right.w)
		rear=support_center+(rear-support_center).limit_length(left.w)
	if rear.distance_to(rear_center)>right.w+.001:
		rear=rear_center.lerp(support_center,right.w/(right.w+left.w))
	return rear

## Compose the reviewed upper-body contact on standing legs, without seeking a live rig.
static func contact_bones(field: Dictionary, clip: String, time: float) -> Array[Transform3D]:
	var rig: Skeleton3D = field.skeleton
	var player: AnimationPlayer = field.player
	var idle := Locomotion.sample_clip(rig, player.get_animation("Idle"), field.pelvis, 4.0/24.0)
	var cast := Locomotion.sample_clip(rig, player.get_animation(clip), field.pelvis, time)
	var transforms: Array[Transform3D] = []
	for i in rig.get_bone_count():
		var rotation: Quaternion = cast.rotations[i] if upper_body(rig.get_bone_name(i)) else idle.rotations[i]
		var position: Vector3 = idle.pelvis if i == field.pelvis else rig.get_bone_rest(i).origin
		var local := Transform3D(Basis(rotation), position)
		var parent := rig.get_bone_parent(i)
		transforms.append(local if parent < 0 else transforms[parent] * local)
	return transforms
