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
	var donor := DONOR.instantiate()
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
		result.add_animation(name,clip)
	donor.free()

static func pose(field: Dictionary, form: String, phase: float, combo: int, baseline: Array[Quaternion]=[]) -> Array[Quaternion]:
	var definition: Dictionary=Poses.DEFINITIONS.get(form,{})
	var clips: Array=definition.get("clips",[])
	if clips.is_empty(): return []
	var index := posmod(combo,clips.size())
	var name: String=clips[index]
	var player: AnimationPlayer=field.player
	var length := player.get_animation(name).length
	var recoveries: Array=definition.get("recoveries",[])
	var recovery: String=recoveries[index] if index<recoveries.size() else ""
	var total := length+(player.get_animation(recovery).length if not recovery.is_empty() else 0.0)
	var impact := length*float(definition.get("impact",0.55))
	var contact := float(Motion.profile(form).release)
	var time := lerpf(0.0,impact,clampf(phase/contact,0,1)) if phase<=contact else lerpf(impact,total,clampf((phase-contact)/(1.0-contact),0,1))
	if time>length and not recovery.is_empty(): name=recovery; time-=length
	if player.current_animation!=name: player.play(name)
	time=clampf(time,0.0,player.get_animation(name).length-0.00001)
	player.seek(time,false)
	return Locomotion.sample_clip(field.skeleton,player.get_animation(name),field.pelvis,time,baseline).rotations
