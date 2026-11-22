extends SceneTree
## Visible carry/strike regressions. Combat timing is covered by weapon_actions.
const Avatar = preload("res://traveller_avatar.gd")
const Appearance = preload("res://character_appearance.gd")
const Classes = preload("res://class_catalog.gd")
const Field = preload("res://field_traveller.gd")
const Motion = preload("res://weapon_motion.gd")
const Poses = preload("res://weapon_pose_catalog.gd")
const Native = preload("res://traveller_weapon_animation.gd")
const Models = preload("res://plant_weapon_models.gd")
const Weapons = preload("res://weapon_visuals.gd")
const Locomotion = preload("res://traveller_locomotion.gd")
var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed=true
		printerr("FAIL weapon presentation: ",message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var stage := preload("res://stage.gd").new()
	var parent := Node3D.new()
	root.add_child(parent)
	for body in 2:
		var actor := Avatar.build(parent)
		var look := Appearance.DEFAULT.duplicate()
		look[5]=body
		Appearance.apply(actor,look)
		inspect_library(actor)
		inspect_sampling_independence(actor)
		for class_id in 5:
			for weapon_id in 3:
				var form: String=Classes.DEFINITIONS[class_id].weapons[weapon_id].visual
				actor.visual_weapon=Weapons.build(stage,class_id,weapon_id)
				actor.visual_weapon.reparent(actor.model,false)
				if form=="knives":
					actor.secondary_weapon=Weapons.build(stage,class_id,weapon_id)
					actor.secondary_weapon.reparent(actor.model,false)
				for moving in [false,true]:
					actor.pace=.65 if moving else 0.0
					actor.speed=3.5 if moving else 0.0
					pose(actor,form,0.0,false)
					inspect_carry(actor,form)
				actor.pace=0.0
				actor.speed=0.0
				inspect_attack(actor,form)
				inspect_continuity(actor,form)
				inspect_body_clearance(actor,form)
				inspect_relaxed_recovery(actor,form)
				actor.visual_weapon.free()
				actor.erase("visual_weapon")
				if actor.has("secondary_weapon"):
					actor.secondary_weapon.free()
					actor.erase("secondary_weapon")
		actor.model.queue_free()
	parent.queue_free()
	stage.free()
	await process_frame
	if not failed:
		print("PASS: 30 weapon/body pairs, moving carries, elevated focus, bow string, cutting planes, alternating upper-body clips, utility sweeps and fixed release markers")
	quit(1 if failed else 0)

func pose(actor: Dictionary, form: String, phase: float, active: bool, combo := 0) -> void:
	var action := {"equipped":true,"aim_yaw":0.0,"contact":Motion.profile(form).release,"combo":combo}
	actor.model.rotation.y=0.0
	Avatar.animate(actor,active,phase,form,action,1.0)
	Weapons.animate(actor,form,phase,active,0.0,3.0,action)

func inspect_library(actor: Dictionary) -> void:
	var player: AnimationPlayer=actor.field_rig.player
	var skeleton: Skeleton3D=actor.field_rig.skeleton
	for definition: Dictionary in Poses.DEFINITIONS.values():
		for name: String in definition.clips+definition.get("recoveries",[]):
			check(player.has_animation(name),"native clip imported: "+name)
			var animation := player.get_animation(name)
			for track in animation.get_track_count():
				var path := animation.track_get_path(track)
				check(animation.track_get_type(track)==Animation.TYPE_ROTATION_3D and Native.upper_body(path.get_subname(0)),"weapon clips cannot move roots, legs, bone positions or scales")
	var hand := skeleton.find_bone("upperarm_r")
	var first := Native.pose(actor.field_rig,"blade",float(Motion.profile("blade").release),0)
	var second := Native.pose(actor.field_rig,"blade",float(Motion.profile("blade").release),1)
	check(first[hand].angle_to(second[hand])>.1,"alternating attacks use distinct original A/B poses")

func inspect_carry(actor: Dictionary, form: String) -> void:
	var weapon: Node3D=actor.visual_weapon
	var right := Field.hand(actor,false)
	var left := Field.hand(actor,true)
	var expected := left if form=="bow" else (left+right)*.5 if form=="orb" else right
	check(weapon.to_global(weapon.get_meta("handle",Vector3.ZERO)).distance_to(expected)<.001,"carry stays in actual palms: "+form)
	if form=="orb":
		var rig: Skeleton3D=actor.field_rig.skeleton
		var pelvis := rig.to_global(rig.get_bone_global_pose(actor.field_rig.pelvis).origin)
		check(weapon.get_node("CoreSeed").global_position.y>pelvis.y+.15,"focus is above the pelvis while standing and moving")
	if form in ["blade","knives","staff","wand"]:
		check(weapon.global_basis.y.normalized().z>.30,"carry leans forward: "+form)
	if form in ["blade","knives","hammer","scythe","fan"]:
		var correction := Poses.orientation(form,0.0,false,0.0,{})
		check(absf(correction.z.dot(Vector3.BACK))<.001,"authored broad-face plane corrected by 90 degrees: "+form)
	if form=="bow":
		check(absf(right.x-left.x)>.3,"resting bow leaves the draw arm relaxed at its own side")
	if form=="ring":
		check(weapon.get_node("CoreSeed").global_position.y<right.y,"ring hangs below the relaxed hand rather than in the face")
	if form=="scythe":
		var tip := weapon.to_global(Vector3(.765,.90,0))
		var blade_root := weapon.to_global(Vector3(0,1.20,0))
		check(tip.y<blade_root.y-.2,"the scythe blade points down from its head")
	if form=="spear":
		check(absf(weapon.global_basis.y.normalized().y)<.1,"spear stays level instead of lowering from a rifle pose")
		check(right.x<-.14,"spear rear grip stays beside the body")
	if form=="whip":
		for step in 40:
			check(Weapons.lash_point(step/39.0,0.0,3.0).z>=0.0,"coiled lash stays in front of its grip")

func inspect_attack(actor: Dictionary, form: String) -> void:
	var contact := float(Motion.profile(form).release)
	pose(actor,form,contact*.45,true)
	var windup := Field.hand(actor,false)
	pose(actor,form,contact,true)
	var hand := Field.hand(actor,false)
	if form in ["bell","censer","fan"]:
		check(hand.distance_to(windup)>.24,"utility attack travels forward rather than shrugging: "+form)
	if form=="spear":
		pose(actor,form,0.0,false)
		var start := Field.hand(actor,false)
		pose(actor,form,contact,true)
		var thrust := Field.hand(actor,false)-start
		check(thrust.z>.15 and absf(thrust.y)<.15 and absf(actor.visual_weapon.global_basis.y.normalized().y)<.10,"reviewed spear thrust drives forward with a level shaft")
	if form in ["bell","censer"]:
		var model: Dictionary=Models.MODELS[form]
		var body: Vector3=actor.visual_weapon.to_global(model.core)-hand
		check(body.z>.20,"hanging instrument swings forward: "+form)
	if form=="bow":
		pose(actor,form,contact-.001,true)
		check(actor.visual_weapon.to_global(Vector3(0,.2,-.45)).distance_to(Field.hand(actor,false))<.035,"attack draw stays on the nock")
	if form in ["staff","wand"]:
		var profile := Motion.profile(form)
		var ground: Vector3=actor.model.get_parent_node_3d().global_position
		var muzzle := ground+Vector3(0,float(profile.height),float(profile.muzzle_forward))
		check(actor.visual_weapon.get_node("WeaponTip").global_position.distance_to(muzzle)<.08,"spell tip meets the unchanged gameplay muzzle: "+form)
	var primary: Node3D=actor.visual_weapon
	pose(actor,form,0.0,false)
	var ready := primary.global_basis.get_rotation_quaternion()
	pose(actor,form,1.0,true)
	check(ready.angle_to(primary.global_basis.get_rotation_quaternion())<.001,"action ends at the same carry orientation: "+form)

func inspect_continuity(actor: Dictionary, form: String) -> void:
	var skeleton: Skeleton3D=actor.field_rig.skeleton
	var joints: Array[int]=[]
	for side in ["l","r"]:
		for name in ["upperarm_","lowerarm_","hand_"]:
			joints.append(skeleton.find_bone(name+side))
	for combo in 2:
		for warmup in 25:pose(actor,form,0.0,false,combo)
		var previous: Array[Quaternion]=[]
		var largest := 0.0
		for step in 121:
			var phase := step/120.0
			var action := {"equipped":true,"aim_yaw":0.0,"combo":combo}
			Avatar.animate(actor,true,phase,form,action,1.0/120.0)
			for index in joints.size():
				var rotation := skeleton.get_bone_pose_rotation(joints[index])
				if step>0:largest=maxf(largest,previous[index].angle_to(rotation))
				if step==0:previous.append(rotation)
				else:previous[index]=rotation
		check(largest<.36,"native arms remain continuous through contact/recovery: "+str([form,combo,largest]))

func bone_point(skeleton: Skeleton3D, name: String) -> Vector3:
	return skeleton.get_bone_global_pose(skeleton.find_bone(name)).origin

func inspect_body_clearance(actor: Dictionary, form: String) -> void:
	if form not in ["spear","bow","scythe","bell","censer","fan"]:return
	var skeleton: Skeleton3D=actor.field_rig.skeleton
	var nearest := INF
	for step in 121:
		var phase := step/120.0
		Avatar.animate(actor,true,phase,form,{"equipped":true,"aim_yaw":0.0},1.0/120.0)
		if phase<.1 or phase>.78:continue
		for side in ["l","r"]:
			var closest := Geometry3D.get_closest_points_between_segments(bone_point(skeleton,"lowerarm_"+side),bone_point(skeleton,"hand_"+side),bone_point(skeleton,"spine_01"),bone_point(skeleton,"spine_03"))
			nearest=minf(nearest,closest[0].distance_to(closest[1]))
	check(nearest>.14,"forearms remain outside the conservative torso capsule throughout the attack: "+str([form,nearest]))

func inspect_relaxed_recovery(actor: Dictionary, form: String) -> void:
	if form not in ["knives","ring","whip","bell","censer","fan","bow","scythe"]:return
	# Same clock sample: weapon carry may not replace the original relaxed arms.
	actor.idle_time=.75
	Avatar.animate(actor,false,0.0,"",{},1.0)
	var right := Field.hand(actor,false)
	var left := Field.hand(actor,true)
	actor.idle_time=.75
	Avatar.animate(actor,false,0.0,form,{"equipped":true},1.0)
	check(right.distance_to(Field.hand(actor,false))<.015 and left.distance_to(Field.hand(actor,true))<.015,"ordinary carry uses relaxed idle arms instead of a permanent attack guard: "+form)
	for frame in 90:
		Avatar.animate(actor,false,0.0,form,{"equipped":true},1.0/60.0)
	var skeleton: Skeleton3D=actor.field_rig.skeleton
	var spine := skeleton.get_bone_pose_rotation(skeleton.find_bone("spine_03"))
	var clock := float(actor.idle_time)
	Avatar.animate(actor,false,0.0,"",{},1.0)
	actor.idle_time=clock-1.0
	Avatar.animate(actor,false,0.0,form,{"equipped":true},1.0)
	check(spine.angle_to(skeleton.get_bone_pose_rotation(skeleton.find_bone("spine_03")))<.015,"post-attack torso recovers to the current idle sample: "+form)

func inspect_sampling_independence(actor: Dictionary) -> void:
	var field: Dictionary=actor.field_rig
	var skeleton: Skeleton3D=field.skeleton
	var expected := Locomotion.clip_pose(skeleton,field.player,field.pelvis,"Idle",.5)
	for bone in skeleton.get_bone_count():
		skeleton.set_bone_pose_rotation(bone,Quaternion(Vector3.UP,.7)*skeleton.get_bone_pose_rotation(bone))
	var actual := Locomotion.clip_pose(skeleton,field.player,field.pelvis,"Idle",.5)
	for bone in skeleton.get_bone_count():
		check(expected.rotations[bone].angle_to(actual.rotations[bone])<.001,"omitted animation tracks resolve from neutral data, independent of previous attacks: "+skeleton.get_bone_name(bone))
