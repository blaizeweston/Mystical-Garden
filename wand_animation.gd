extends RefCounted
## Approved Thorn Wand casts, fixed grip and interruptible visual recovery.
## Presentation only: no combat clock, attack state, damage or movement ownership.
const Native = preload("res://traveller_weapon_animation.gd")
const Locomotion = preload("res://traveller_locomotion.gd")
const Motion = preload("res://weapon_motion.gd")
const CLIPS := {
	"Attack_wand_forward":preload("res://assets/characters/wand_forward.glb"),
	"Attack_wand_sweep":preload("res://assets/characters/wand_sweep.glb"),
	"Recover_wand_forward":preload("res://assets/characters/wand_recover_forward.glb"),
	"Recover_wand_sweep":preload("res://assets/characters/wand_recover_sweep.glb"),
	"Ready_wand_authored":preload("res://assets/characters/wand_ready.glb"),
}
const RECOVERY_SECONDS := .18
static var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/wand_motion.json"))
# Derived contact layouts, once per body/clip. These contain no actor authority.
static var release_layouts: Dictionary={}

static func add_clips(library: AnimationLibrary, visual: Node3D, skeleton: Skeleton3D) -> void:
	for name: String in CLIPS:Native.add_from(library,visual,skeleton,CLIPS[name],name)

static func calibration(skeleton: Skeleton3D, player: AnimationPlayer, pelvis: int) -> Dictionary:
	var old: Array[Quaternion]=[]
	for bone in skeleton.get_bone_count():old.append(skeleton.get_bone_pose_rotation(bone))
	var hips:=skeleton.get_bone_pose_position(pelvis)
	var idle:=Locomotion.sample_clip(skeleton,player.get_animation("Idle"),pelvis,4.0/24.0)
	var ready:=Locomotion.sample_clip(skeleton,player.get_animation("Ready_wand_authored"),pelvis,0.0,idle.rotations)
	for bone in skeleton.get_bone_count():skeleton.set_bone_pose_rotation(bone,ready.rotations[bone])
	skeleton.set_bone_pose_position(pelvis,idle.pelvis)
	skeleton.force_update_all_bone_transforms()
	var wrist_index:=skeleton.find_bone("hand_r")
	var wrist:=skeleton.get_bone_global_pose(wrist_index)
	var center:=Vector3.ZERO
	for finger in ["index","middle","ring","pinky"]:
		for joint in [2,3]:center+=skeleton.get_bone_global_pose(skeleton.find_bone("%s_%02d_r"%[finger,joint])).origin
	var source: Dictionary=data.calibration
	var scale: float=(center/8.0-wrist.origin).length()/float(source.knuckle_distance)
	var alignment:=wrist.basis.inverse()*Basis(quaternion(source.hand))
	var result:={"right":{"bone":wrist_index,"point":alignment*vector(source.grip)*scale},
		"mount":wrist.basis.inverse()*Basis(quaternion(source.weapon)),"ready":ready.rotations,
		"pelvis_basis":skeleton.get_bone_global_pose(pelvis).basis.orthonormalized()}
	for bone in skeleton.get_bone_count():skeleton.set_bone_pose_rotation(bone,old[bone])
	skeleton.set_bone_pose_position(pelvis,hips)
	skeleton.force_update_all_bone_transforms()
	return result

static func pose(field: Dictionary, motion: Dictionary, phase: float, active: bool, delta: float) -> Dictionary:
	var state: Dictionary=field.wand
	var player: AnimationPlayer=field.player
	var name: String="Ready_wand_authored"
	var time:=0.0
	var weight:=0.0
	if active:
		name=str(motion.get("clip",""))
		if name not in ["Attack_wand_forward","Attack_wand_sweep"]:name=Motion.basic_variant("wand",int(motion.get("combo",1))).clip
		state.last_clip=name;state.recovery_elapsed=0.0
		var contact:=float(Motion.profile("wand").release)
		var impact:=float(data.clips[name].contact_seconds)
		time=lerpf(0,impact,clampf(phase/contact,0,1)) if phase<=contact else lerpf(impact,float(data.clips[name].duration_seconds),clampf((phase-contact)/(1-contact),0,1))
		weight=smoothstep(0,.12,phase)
	elif state.has("last_clip"):
		name="Recover_wand_sweep" if state.last_clip=="Attack_wand_sweep" else "Recover_wand_forward"
		state.recovery_elapsed=float(state.recovery_elapsed)+maxf(0,delta)
		var progress:=clampf(float(state.recovery_elapsed)/RECOVERY_SECONDS,0,1)
		time=progress*float(data.clips[name].duration_seconds)
		weight=1.0-smoothstep(.75,1.0,progress)
		if progress>=1.0:clear(field);name="Ready_wand_authored";time=0.0
	if player.current_animation!=name:player.play(name)
	player.seek(time,false)
	# Importers omit constant tracks. Use this weapon's authored ready for those
	# upper-body joints; locomotion still owns the pelvis/legs in FieldTraveller.
	return {"rotations":Locomotion.sample_clip(field.skeleton,player.get_animation(name),field.pelvis,time,state.ready).rotations,"weight":weight}

static func clear(field: Dictionary) -> void:
	field.wand.erase("last_clip");field.wand.erase("recovery_elapsed")

## Capture only imported render geometry. The physical projectile path is unchanged.
static func cache_releases(skeleton: Skeleton3D, player: AnimationPlayer, pelvis: int, grip: Dictionary, body: int) -> void:
	if release_layouts.has(body):return
	var old: Array[Quaternion]=[]
	for bone in skeleton.get_bone_count():old.append(skeleton.get_bone_pose_rotation(bone))
	var hips:=skeleton.get_bone_pose_position(pelvis)
	var idle:=Locomotion.sample_clip(skeleton,player.get_animation("Idle"),pelvis,4.0/24.0)
	var layouts: Dictionary={}
	for name in ["Attack_wand_forward","Attack_wand_sweep"]:
		var pose_values:=Locomotion.sample_clip(skeleton,player.get_animation(name),pelvis,float(data.clips[name].contact_seconds),idle.rotations)
		for bone in skeleton.get_bone_count():skeleton.set_bone_pose_rotation(bone,pose_values.rotations[bone])
		skeleton.set_bone_pose_position(pelvis,idle.pelvis);skeleton.force_update_all_bone_transforms()
		var wrist:=skeleton.get_bone_global_pose(grip.right.bone)
		var lowest:=INF
		for side in ["l","r"]:
			for joint in ["foot_","ball_"]:
				var bone:=skeleton.find_bone(joint+side)
				var rest:=skeleton.get_bone_global_rest(bone)
				var point:=rest.origin;point.y=.006
				lowest=minf(lowest,(skeleton.get_bone_global_pose(bone)*rest.affine_inverse()*point).y)
		layouts[name]={"palm":wrist*grip.right.point,"weapon":wrist.basis*grip.mount,"lowest":lowest}
	for bone in skeleton.get_bone_count():skeleton.set_bone_pose_rotation(bone,old[bone])
	skeleton.set_bone_pose_position(pelvis,hips);skeleton.force_update_all_bone_transforms()
	release_layouts[body]=layouts

static func release_offset(body: int, clip: String, height: float) -> Vector3:
	if not release_layouts.has(body) or not release_layouts[body].has(clip):return Vector3.INF
	var layout: Dictionary=release_layouts[body][clip]
	var scale:=Basis.IDENTITY.scaled(Vector3(1,height,1))
	return scale*Vector3(layout.palm)+(scale*Basis(layout.weapon)).orthonormalized()*preload("res://plant_weapon_models.gd").SPELL_TIPS.wand*float(data.source_weapon_scale)+Vector3.UP*maxf(0,-float(layout.lowest)*height)

static func quaternion(values: Array) -> Quaternion:
	return Quaternion(values[0],values[1],values[2],values[3]).normalized()

static func vector(values: Array) -> Vector3:
	return Vector3(values[0],values[1],values[2])
