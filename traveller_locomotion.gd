extends RefCounted

const DONOR := preload("res://assets/characters/field_locomotion.glb")
const IDLE := &"Idle"
const WALK := &"Walk"
const JOG := &"Jog_Fwd"
const SPRINT := &"Sprint"
# Foot travel measured on the ground-contact part of each original loop.
const STRIDES := {WALK:1.4, JOG:5.35, SPRINT:5.55}
const STEP_START := {WALK:0.0, JOG:.035, SPRINT:.02}


static func library(visual: Node3D, skeleton: Skeleton3D) -> AnimationLibrary:
	var donor := DONOR.instantiate()
	var source := donor.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var player := donor.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	var result := AnimationLibrary.new()
	var target_path := str(visual.get_path_to(skeleton))
	for name in [IDLE,WALK,JOG,SPRINT]:
		var clip := player.get_animation(name).duplicate() as Animation
		for track in range(clip.get_track_count()-1,-1,-1):
			var path := clip.track_get_path(track)
			var bone := path.get_subname(0) if path.get_subname_count()>0 else &""
			var target_index := skeleton.find_bone(bone)
			var source_index := source.find_bone(bone)
			var type := clip.track_get_type(track)
			var hips: bool = type==Animation.TYPE_POSITION_3D and bone==&"pelvis" and name!=IDLE
			if target_index<0 or source_index<0 or (type!=Animation.TYPE_ROTATION_3D and not hips):
				clip.remove_track(track)
				continue
			clip.track_set_path(track,NodePath(target_path+":"+str(bone)))
			var target_rest := skeleton.get_bone_rest(target_index)
			var source_rest := source.get_bone_rest(source_index)
			if hips:
				var source_parent := source.get_bone_global_rest(source.get_bone_parent(source_index))
				var target_parent := skeleton.get_bone_global_rest(skeleton.get_bone_parent(target_index))
				var alignment := target_parent.basis.inverse()*source_parent.basis
				var ratio := target_rest.origin.length()/maxf(.01,source_rest.origin.length())
				for key in clip.track_get_key_count(track):
					var value: Vector3 = clip.track_get_key_value(track,key)
					clip.track_set_key_value(track,key,target_rest.origin+alignment*(value-source_rest.origin)*ratio)
			else:
				var correction := target_rest.basis.get_rotation_quaternion()*source_rest.basis.get_rotation_quaternion().inverse()
				for key in clip.track_get_key_count(track):
					var rotation: Quaternion = clip.track_get_key_value(track,key)
					clip.track_set_key_value(track,key,(correction*rotation).normalized())
		result.add_animation(name,clip)
	donor.free()
	return result


static func pose(actor: Dictionary, field: Dictionary, delta: float) -> Dictionary:
	var skeleton: Skeleton3D = field.skeleton
	var player: AnimationPlayer = field.player
	var speed := float(actor.get("speed",0))
	var weight := smoothstep(.08,1.35,speed) if float(actor.pace)>.001 else 0.0
	var gait_yaw := 0.0
	var step_sign := 1.0
	var displacement: Vector3 = actor.get("gait_vector",Vector3.ZERO)
	if displacement.length_squared()>.000001:
		var local := Basis(Vector3.UP,-float(actor.model.rotation.y))*displacement
		step_sign = -1.0 if local.z < -local.length()*.32 else 1.0
		gait_yaw = clampf(atan2(local.x*step_sign,absf(local.z)),-.94,.94)
	field.gait_yaw = lerpf(float(field.get("gait_yaw",0.0)),gait_yaw,1.0-exp(-16.0*delta))
	var idle := clip_pose(skeleton,player,field.pelvis,IDLE,float(actor.idle_time))
	idle["yaw"] = float(field.gait_yaw)*weight
	if weight<=.0001:
		return idle

	var jogging := smoothstep(1.4,5.1,speed)
	var sprinting := smoothstep(5.8,8.4,speed)
	var first := WALK if jogging<1.0 else JOG
	var second := JOG if jogging<1.0 else SPRINT
	var mix_value := jogging if jogging<1.0 else sprinting
	var stride := lerpf(float(STRIDES[first]),float(STRIDES[second]),mix_value)
	var step := minf(float(actor.get("gait_travel",0.0))/stride,maxf(0,delta)*1.85)
	field.gait = fposmod(float(field.gait)+step*step_sign,1.0)
	var phase := float(field.gait) if actor.has("gait_vector") else float(actor.get("gait_phase",0))
	var moving: Dictionary
	if mix_value>=.9999:
		moving=cycle(skeleton,player,field.pelvis,second,phase)
	else:
		moving=cycle(skeleton,player,field.pelvis,first,phase)
		if mix_value>.0001:
			blend(moving,cycle(skeleton,player,field.pelvis,second,phase),mix_value)
	blend(idle,moving,weight)
	return idle


static func cycle(skeleton: Skeleton3D, player: AnimationPlayer, pelvis: int, name: StringName, phase: float) -> Dictionary:
	var seconds := fposmod(phase+float(STEP_START[name]),1.0)*player.get_animation(name).length
	return clip_pose(skeleton,player,pelvis,name,seconds)


static func clip_pose(skeleton: Skeleton3D, player: AnimationPlayer, pelvis: int, name: StringName, seconds: float) -> Dictionary:
	skeleton.set_bone_pose_position(pelvis,skeleton.get_bone_rest(pelvis).origin)
	if player.current_animation!=name:
		player.play(name)
	player.seek(fposmod(seconds,player.get_animation(name).length),true)
	player.advance(0.0)
	var rotations: Array[Quaternion] = []
	for index in skeleton.get_bone_count():
		rotations.append(skeleton.get_bone_pose_rotation(index))
	return {"rotations":rotations,"pelvis":skeleton.get_bone_pose_position(pelvis)}


static func blend(result: Dictionary, target: Dictionary, amount: float) -> void:
	for index in result.rotations.size():
		result.rotations[index]=result.rotations[index].slerp(target.rotations[index],amount)
	var source: Vector3 = result.pelvis
	result.pelvis=source.lerp(target.pelvis,amount)
