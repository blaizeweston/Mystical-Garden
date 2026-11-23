extends RefCounted
## The held seed follows both wrists. The flying seed uses the ordinary projectile.
const CASTS = preload("res://assets/characters/seed_focus_casts.glb")
const Native = preload("res://traveller_weapon_animation.gd")
const Locomotion = preload("res://traveller_locomotion.gd")
const Motion = preload("res://weapon_motion.gd")
const READY := "Ready_focus"
const PUSH := "Attack_focus_push"
const GATHER := "Attack_focus_gather"
static var motion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/seed_focus_motion.json"))
static var contact_centers: Dictionary = {}

static func idle_hip_basis(rig: Skeleton3D, player: AnimationPlayer) -> Basis:
	var bone := rig.find_bone("pelvis")
	var idle := Locomotion.sample_clip(rig, player.get_animation("Idle"), bone, 4.0/24.0)
	var basis := Basis.IDENTITY
	while bone >= 0:
		basis = Basis(idle.rotations[bone]) * basis
		bone = rig.get_bone_parent(bone)
	return basis

static func sample(field: Dictionary, action: Dictionary, phase: float, active: bool, delta: float) -> Array[Quaternion]:
	var state: Dictionary = field.focus
	var player: AnimationPlayer = field.player
	var clip := READY
	var time := 0.0
	if active:
		clip = action.get("clip", "")
		if clip not in [PUSH, GATHER]:
			clip = Motion.basic_variant("orb", int(action.get("combo", 1))).clip
		time = phase * player.get_animation(clip).length
		state.return_clip = "Recover_focus_gather" if clip == GATHER else "Recover_focus_push"
		state.return_time = 0.0
	elif state.has("return_clip"):
		clip = state.return_clip
		# Match the return speed to the cast playback speed.
		var rate := player.get_animation(PUSH).length / float(Motion.profile("orb").duration)
		time = float(state.return_time) + maxf(delta, 0.0) * rate
		if time >= player.get_animation(clip).length:
			state.clear()
			clip = READY
			time = 0.0
		else:
			state.return_time = time
	if player.current_animation != clip:
		player.play(clip)
	player.seek(time, false)
	var keys: Array = motion.clips[clip]
	var cursor := clampf(time * float(motion.samples_per_second), 0.0, keys.size() - 1)
	var index := floori(cursor)
	var a: Array = keys[index]
	var b: Array = keys[mini(index + 1, keys.size() - 1)]
	state.offset = Vector3(a[0], a[1], a[2]).lerp(Vector3(b[0], b[1], b[2]), cursor-index)
	state.held_scale = lerpf(float(a[3]), float(b[3]), cursor-index)
	if active and phase < float(Motion.profile("orb").release):
		state.held_scale = 1.0
	return Locomotion.sample_clip(field.skeleton, player.get_animation(clip), field.pelvis, time).rotations

static func held_center(field: Dictionary) -> Vector3:
	var rig: Skeleton3D = field.skeleton
	var wrists := (rig.get_bone_global_pose(field.left.bone).origin + rig.get_bone_global_pose(field.right.bone).origin) * .5
	return rig.to_global(wrists + Vector3(field.focus.offset))

## Cache the two retargeted contact poses for delayed events. Evaluate joint
## transforms locally, so resolving a late seed never seeks a live actor's rig.
static func cache_contacts(field: Dictionary, body: int) -> void:
	if contact_centers.has(body): return
	var rig: Skeleton3D = field.skeleton
	var player: AnimationPlayer = field.player
	var idle := Locomotion.sample_clip(rig, player.get_animation("Idle"), field.pelvis, 4.0/24.0)
	var contacts := {}
	for clip in [PUSH, GATHER]:
		var animation := player.get_animation(clip)
		var time := animation.length * float(Motion.profile("orb").release)
		var cast := Locomotion.sample_clip(rig, animation, field.pelvis, time)
		var transforms: Array[Transform3D] = []
		for i in rig.get_bone_count():
			var rotation: Quaternion = cast.rotations[i] if Native.upper_body(rig.get_bone_name(i)) else idle.rotations[i]
			var position: Vector3 = idle.pelvis if i == field.pelvis else rig.get_bone_rest(i).origin
			var local := Transform3D(Basis(rotation), position)
			var parent := rig.get_bone_parent(i)
			transforms.append(local if parent < 0 else transforms[parent] * local)
		var wrists := (transforms[field.left.bone].origin + transforms[field.right.bone].origin) * .5
		var key: Array = motion.clips[clip][roundi(time * float(motion.samples_per_second))]
		var center := wrists + Vector3(key[0],key[1],key[2])
		var lift := 0.0
		for sole in field.soles:
			lift = maxf(lift, -(transforms[sole.bone] * Vector3(sole.point)).y)
		contacts[clip] = center + Vector3.UP * lift
	contact_centers[body] = contacts

static func contact_offset(body: int, clip: String, height: float) -> Vector3:
	var profile := Motion.profile("orb")
	var authored := Vector3(-float(profile.muzzle_side),profile.height,profile.muzzle_forward)
	var center: Vector3 = contact_centers.get(body,{}).get(clip,authored)
	return center * Vector3(1,height,1)
