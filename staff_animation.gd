extends RefCounted
## Reviewed Blender Spore Staff actions on either traveller rig. This is presentation
## only: the host weapon timeline still owns cadence, contact and alternation.
const Native = preload("res://traveller_weapon_animation.gd")
const Locomotion = preload("res://traveller_locomotion.gd")
const CLIPS := {
	"Attack_staff_forward":preload("res://assets/characters/staff_forward.glb"),
	"Attack_staff_side":preload("res://assets/characters/staff_side.glb"),
	"Recover_staff_forward":preload("res://assets/characters/staff_recover_forward.glb"),
	"Recover_staff_side":preload("res://assets/characters/staff_recover_side.glb"),
	"Ready_staff_authored":preload("res://assets/characters/staff_ready.glb"),
}
# Visual blending/recovery only, in seconds; neither delays the next attack.
const RECOVERY_SECONDS := .20
const ENTRY_PHASE := .16
static var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/staff_motion.json"))

static func add_clips(library: AnimationLibrary, visual: Node3D, skeleton: Skeleton3D) -> void:
	for name in CLIPS:Native.add_from(library,visual,skeleton,CLIPS[name],name)

static func calibration(skeleton: Skeleton3D, player: AnimationPlayer, pelvis: int) -> Dictionary:
	return Native.paired_calibration(skeleton,player,pelvis,"Ready_staff_authored",sample_at("Ready_staff_authored",0))


static func clear(field: Dictionary) -> void:
	for key in ["was_active","last_attack","recover_elapsed","entry_elapsed","entry_sample","entry_rotations","sequence","rotations"]:
		field.staff.erase(key)
	field.erase("staff_sample")

## Both casts translate the upright shaft forward, then return to the shared ready.
## Recovery is presentation only and may be interrupted by the next action.
static func rotations(field: Dictionary, motion: Dictionary, phase: float, active: bool, baseline: Array[Quaternion], delta: float) -> Array[Quaternion]:
	var state: Dictionary=field.staff
	var player: AnimationPlayer=field.player
	var name: String=motion.get("clip","Attack_staff_forward")
	if name not in ["Attack_staff_forward","Attack_staff_side"]:name="Attack_staff_forward"
	var time:=0.0
	if active:
		var sequence:=int(motion.get("combo",0))
		if sequence!=int(state.get("sequence",-1)) or not state.get("was_active",false):
			state.entry_elapsed=0.0
			state.entry_sample=field.get("staff_sample",{})
			state.entry_rotations=state.get("rotations",[])
		state.sequence=sequence
		state.last_attack=name
		state.recover_elapsed=0.0
		var contact:=float(motion.get("contact",.42))
		var impact:=float(data.clips[name].contact_seconds)
		time=lerpf(0,impact,clampf(phase/contact,0,1)) if phase<=contact else lerpf(impact,float(data.clips[name].duration_seconds),clampf((phase-contact)/(1-contact),0,1))
	else:
		var sweep: bool=state.get("last_attack","")=="Attack_staff_side"
		var elapsed:=float(state.get("recover_elapsed",RECOVERY_SECONDS))+maxf(0,delta)
		state.recover_elapsed=elapsed
		if elapsed<RECOVERY_SECONDS:
			name="Recover_staff_side" if sweep else "Recover_staff_forward"
			time=elapsed/RECOVERY_SECONDS*float(data.clips[name].duration_seconds)
		else:name="Ready_staff_authored"
	state.was_active=active
	if player.current_animation!=name:player.play(name)
	player.seek(time,false)
	var rotations: Array[Quaternion]=Locomotion.sample_clip(field.skeleton,player.get_animation(name),field.pelvis,time,baseline).rotations
	var sample:=sample_at(name,time)
	if active and not state.get("entry_sample",{}).is_empty() and not state.get("entry_rotations",[]).is_empty():
		state.entry_elapsed=float(state.get("entry_elapsed",0.0))+maxf(0,delta)
		var weight:=smoothstep(0,ENTRY_PHASE,phase)
		sample=Native.blend_grip_samples(state.entry_sample,sample,weight)
		for bone in rotations.size():
			if Native.upper_body(field.skeleton.get_bone_name(bone)):rotations[bone]=state.entry_rotations[bone].slerp(rotations[bone],weight)
	state.rotations=rotations
	field.staff_sample=sample
	return rotations

## Detached samples: grip coordinates in model metres, other values in rig space.
static func sample_at(name: String, seconds: float) -> Dictionary:
	return Native.grip_sample(data,name,seconds)

# Derived rendering layouts only, keyed by body and clip, never actor authority.
# Cached once from the actual imported rig; a late reliable event can still emit
# from its captured cast instead of the actor's newer animation or character.
static var release_layouts: Dictionary={}

static func release_offset(body: int, clip: String, height: float) -> Vector3:
	if not release_layouts.has(body) or not release_layouts[body].has(clip):return Vector3.INF
	var layout: Dictionary=release_layouts[body][clip]
	var scale_basis:=Basis.IDENTITY.scaled(Vector3(1,height,1))
	var orientation: Basis=(scale_basis*layout.weapon).orthonormalized()
	var separation:=orientation.y*float(layout.grip_distance)*float(data.source_weapon_scale)
	var palm:=Native.fit_grip_pair(layout.desired,scale_basis.inverse()*separation,layout.right,layout.left)
	var tip: Vector3=preload("res://plant_weapon_models.gd").SPELL_TIPS.staff
	return scale_basis*palm+orientation*(tip-Vector3.UP*float(layout.right_grip))*float(data.source_weapon_scale)+Vector3.UP*maxf(0,-float(layout.lowest)*height)
