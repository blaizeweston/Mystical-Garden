extends RefCounted
## Reviewed Blender slashes and their individual return-to-ready clips.
## Presentation only: no attack state, damage, cooldown or locomotion authority.
const Native = preload("res://traveller_weapon_animation.gd")
const Locomotion = preload("res://traveller_locomotion.gd")
const Poses = preload("res://weapon_pose_catalog.gd")
const CLIPS := {
	"Attack_rootblade_forehand":preload("res://assets/characters/rootblade_forehand.glb"),
	"Attack_rootblade_backhand":preload("res://assets/characters/rootblade_backhand.glb"),
	"Recover_rootblade_left":preload("res://assets/characters/rootblade_recover_left.glb"),
	"Recover_rootblade_right":preload("res://assets/characters/rootblade_recover_right.glb"),
	"Ready_rootblade":preload("res://assets/characters/rootblade_ready.glb"),
}
static var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/rootblade_motion.json"))

static func add_clips(library: AnimationLibrary, visual: Node3D, skeleton: Skeleton3D) -> void:
	for name: String in CLIPS:Native.add_from(library,visual,skeleton,CLIPS[name],name)

static func calibration(skeleton: Skeleton3D, player: AnimationPlayer, pelvis: int) -> Dictionary:
	var old: Array[Quaternion]=[]
	for bone in skeleton.get_bone_count():old.append(skeleton.get_bone_pose_rotation(bone))
	var idle:=Locomotion.sample_clip(skeleton,player.get_animation("Idle"),pelvis,4.0/24.0)
	var ready:=Locomotion.sample_clip(skeleton,player.get_animation("Ready_rootblade"),pelvis,0.0,idle.rotations)
	for bone in skeleton.get_bone_count():skeleton.set_bone_pose_rotation(bone,ready.rotations[bone])
	skeleton.force_update_all_bone_transforms()
	var wrist_index:=skeleton.find_bone("hand_r")
	var wrist:=skeleton.get_bone_global_pose(wrist_index)
	var center:=Vector3.ZERO
	for finger in ["index","middle","ring","pinky"]:
		for joint in [2,3]:center+=skeleton.get_bone_global_pose(skeleton.find_bone("%s_%02d_r"%[finger,joint])).origin
	var source: Dictionary=data.calibration
	var result:={"right":{"bone":wrist_index,"point":wrist.affine_inverse()*(center/8.0)},
		"mount":wrist.basis.inverse()*Basis(quaternion(source.weapon)),"ready":ready.rotations}
	for bone in skeleton.get_bone_count():skeleton.set_bone_pose_rotation(bone,old[bone])
	skeleton.force_update_all_bone_transforms()
	return result

## The short recovery is visual only and may be interrupted by the next host
## action. It never extends the authoritative attack/exclusion deadline.
static func pose(field: Dictionary, motion: Dictionary, phase: float, active: bool, delta: float, baseline: Array[Quaternion]) -> Dictionary:
	var state: Dictionary=field.rootblade
	var player: AnimationPlayer=field.player
	if active:
		var timing:=Native.playback(player,"blade",phase,int(motion.get("combo",0)),str(motion.get("clip","")))
		state.last_clip=timing.clip
		state.recovery_elapsed=0.0
		return {"rotations":Native.pose(field,"blade",phase,int(motion.get("combo",0)),baseline,str(motion.get("clip",""))),
			"weight":smoothstep(0.0,.12,phase)}
	if not str(state.get("last_clip","")).is_empty():
		var definition: Dictionary=Poses.DEFINITIONS.blade
		var index: int=definition.clips.find(state.last_clip)
		var name: String=definition.recoveries[index]
		state.recovery_elapsed=float(state.recovery_elapsed)+maxf(0,delta)
		var progress:=clampf(float(state.recovery_elapsed)/float(definition.recovery_seconds),0,1)
		var time:=progress*player.get_animation(name).length
		if player.current_animation!=name:player.play(name)
		player.seek(time,false)
		var rotations: Array[Quaternion]=Locomotion.sample_clip(field.skeleton,player.get_animation(name),field.pelvis,time,baseline).rotations
		if progress>=1.0:clear(field)
		return {"rotations":rotations,"weight":1.0-smoothstep(.75,1.0,progress)}
	return {"rotations":state.ready,"weight":0.0}

static func clear(field: Dictionary) -> void:
	field.rootblade.erase("last_clip")
	field.rootblade.erase("recovery_elapsed")

static func quaternion(values: Array) -> Quaternion:
	return Quaternion(values[0],values[1],values[2],values[3]).normalized()
