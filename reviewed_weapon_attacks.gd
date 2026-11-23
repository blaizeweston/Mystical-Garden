extends RefCounted
## Samples the approved body pose and its matching prop pose at the same instant.
const CLIPS := preload("res://assets/characters/ranger_and_knife_attacks.glb")
const Motion := preload("res://weapon_motion.gd")
const Locomotion := preload("res://traveller_locomotion.gd")
const Native := preload("res://traveller_weapon_animation.gd")
const FORMS := ["bow", "crossbow", "ring", "knives", "whip"]
const FPS := 48.0
const HELD_SCALE := preload("res://plant_polearms.gd").SCALE
const BOW_SCALE := HELD_SCALE*1.5
# Blender samples start with a grip offset (XYZ) and rotation (XYZW).
# Bows then store the two limb tips, nock, ammunition scale, flex and support hand.
const LOWER_TIP := 7
const UPPER_TIP := 10
const NOCK := 13
const AMMO_SCALE := 16
const FLEX := 17
const SUPPORT_HAND := 18
static var grips: Dictionary = load_grips()
static var releases: Dictionary = {}

static func load_grips() -> Dictionary:
	var result: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/ranger_and_knife_grips.json"))
	result.whip = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/root_lash_grips.json"))
	return result

static func sample(field: Dictionary, form: String, action: Dictionary, phase: float, active: bool, delta: float) -> Array[Quaternion]:
	var player: AnimationPlayer = field.player
	var state: Dictionary = field.reviewed
	if state.get("form", "") != form:
		state.clear()
	state.form = form
	var clip := "Ready_" + form + "_review"
	var time := 0.0
	if active:
		clip = action.get("clip", "")
		if not grips[form].clips.has(clip) or not clip.begins_with("Attack_"):
			clip = Motion.basic_variant(form, maxi(1, int(action.get("combo", 1)))).clip
		var length := player.get_animation(clip).length
		var contact := float(Motion.profile(form).release)
		var impact := float(grips[form].impact_seconds)
		time = lerpf(0.0, impact, clampf(phase/contact, 0, 1)) if phase <= contact else lerpf(impact, length, clampf((phase-contact)/(1.0-contact), 0, 1))
		state.recovery = clip.replace("Attack_", "Recover_")
		state.return_time = 0.0
		state.rate = length / float(Motion.profile(form).duration)
	elif state.has("recovery"):
		clip = state.recovery
		time = state.return_time + maxf(delta, 0) * float(state.rate)
		if time >= player.get_animation(clip).length:
			state.erase("recovery")
			clip = "Ready_" + form + "_review"
			time = 0.0
		else:
			state.return_time = time
	var keys: Array = grips[form].clips[clip]
	var cursor := clampf(time * FPS, 0, keys.size()-1)
	var index := floori(cursor)
	state.a = keys[index]
	state.b = keys[mini(index+1, keys.size()-1)]
	state.fraction = cursor-index
	if player.current_animation != clip: player.play(clip)
	player.seek(time, false)
	return Locomotion.sample_clip(field.skeleton, player.get_animation(clip), field.pelvis, time).rotations

static func point(key: Array, index: int) -> Vector3:
	return Vector3(key[index], key[index+1], key[index+2])

static func rotation(key: Array, index: int) -> Quaternion:
	return Quaternion(key[index], key[index+1], key[index+2], key[index+3]).normalized()

static func sampled_point(state: Dictionary, index: int) -> Vector3:
	return point(state.a,index).lerp(point(state.b,index),state.fraction)

static func scalar(state: Dictionary, index: int) -> float:
	return lerpf(state.a[index],state.b[index],state.fraction)

## The review grips use curled fingers. The bow draw rests on two fingertips.
static func grip_joints(rig: Skeleton3D) -> Dictionary:
	var joints := {}
	for form in FORMS:
		joints[form] = []
		for left in [false,true]:
			var suffix := "_l" if left else "_r"
			var weights := {}
			if form=="bow" and not left:
				for joint in ["index_03","middle_03"]: weights[joint]=.5
			elif form=="knives":
				for digit in ["index","middle","ring","pinky"]:
					for segment in 3: weights["%s_0%d" % [digit,segment+1]]=[.4,.15,.45][segment]*.25
			else:
				for joint in ["index_02","pinky_02","middle_03","ring_03"]: weights[joint]=.25
			var bones := {}
			for joint: String in weights: bones[rig.find_bone(joint+suffix)]=weights[joint]
			joints[form].append(bones)
	return joints

static func grip_center(field: Dictionary, form: String, left: bool, bones: Array[Transform3D]=[]) -> Vector3:
	var center := Vector3.ZERO
	var weights: Dictionary=field.review_joints[form][int(left)]
	for index: int in weights:
		var transform: Transform3D = field.skeleton.get_bone_global_pose(index) if bones.is_empty() else bones[index]
		center += transform.origin*float(weights[index])
	return center

static func mount(field: Dictionary, left: bool, index := 0) -> Transform3D:
	var state: Dictionary = field.reviewed
	var rig: Skeleton3D = field.skeleton
	var palm := grip_center(field,state.form,left)
	var q := rotation(state.a,index+3).slerp(rotation(state.b,index+3),state.fraction)
	var scale_factor := BOW_SCALE if state.form=="bow" else HELD_SCALE
	return rig.global_transform * Transform3D(Basis(q).scaled(Vector3.ONE*scale_factor),palm+sampled_point(state,index))

## Resolve delayed projectile events at the original contact pose, even after the actor moves.
static func cache_releases(field: Dictionary, body: int) -> void:
	if releases.has(body): return
	var cache := {}
	for form in ["bow", "crossbow", "ring"]:
		for variant: Dictionary in Motion.profile(form).basic_variants:
			var clip: String = variant.clip
			var time := float(grips[form].impact_seconds)
			var key: Array = grips[form].clips[clip][roundi(time*FPS)]
			var transforms := Native.contact_bones(field,clip,time)
			var palm := grip_center(field,form,form=="bow",transforms)
			var center := palm + point(key,0)
			var scale_factor := BOW_SCALE if form=="bow" else HELD_SCALE
			var local := Vector3(0,.282,0) if form=="ring" else point(key,NOCK)-Vector3.UP*.2
			center += Basis(rotation(key,3)) * (local*scale_factor)
			var lift := 0.0
			for sole in field.soles: lift = maxf(lift,-(transforms[sole.bone]*Vector3(sole.point)).y)
			cache[clip] = center+Vector3.UP*lift
	releases[body] = cache

static func release_offset(body: int, clip: String, height: float) -> Vector3:
	var offset: Vector3 = releases.get(body,{}).get(clip,Vector3.INF)
	if not offset.is_finite():
		# A remote release can arrive before an avatar with this body has been built.
		for form in ["bow","crossbow","ring"]:
			if grips[form].release_centers.has(clip):
				offset = point(grips[form].release_centers[clip],0)
				break
	return offset*Vector3(1,height,1)
