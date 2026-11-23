extends SceneTree
## Authored slashes, wrist turnover, recovery and unchanged combat footprint.
const Avatar=preload("res://traveller_avatar.gd")
const Field=preload("res://field_traveller.gd")
const Weapons=preload("res://weapon_visuals.gd")
const Motion=preload("res://weapon_motion.gd")
const Native=preload("res://traveller_weapon_animation.gd")
const Contact=preload("res://weapon_contact.gd")
const Actions=preload("res://player_weapon_actions.gd")
var failed:=false

func check(ok: bool,message: String) -> void:
	if not ok:failed=true;printerr("FAIL Rootblade: ",message)

func _initialize() -> void:call_deferred("run")

func run() -> void:
	inspect_rules()
	for body in 2:inspect_body(body)
	await inspect_combat()
	if not failed:print("PASS: Rootblade forehand/backhand, palm-down wrist, both return clips, unchanged lower-body locomotion, grips, cadence and shared hit indicator")
	quit(1 if failed else 0)

func inspect_rules() -> void:
	var state:=Actions.State.new()
	var names: Array=[]
	for step in 3:
		state=state.try_start(1000+step*450,450,340,2.25,"blade")
		var variant:=Motion.basic_variant("blade",state.basic_step())
		names.append(variant.clip)
		check(state.duration_ms()==340 and state.ready_at_ms()==1450+step*450,"unchanged Rootblade timing")
		check(state.try_start(1000+step*450,450,340,2.25,"blade")==null,"duplicate admission cannot advance alternation")
	check(names==["Attack_rootblade_forehand","Attack_rootblade_backhand","Attack_rootblade_forehand"],"basic-only alternating clips")
	for pattern in ["single","line","sweep","chain","splash"]:
		var original:=Contact.describe("blade",{"pattern":pattern,"reach":2.25})
		for variant: Dictionary in Motion.profile("blade").basic_variants:
			var selected:=Contact.describe("blade",{"pattern":pattern,"reach":2.25,"weapon_variant":variant.clip})
			check(selected.clip==variant.clip,"host-selected clip reaches presentation")
			selected.erase("clip");var baseline:=original.duplicate();baseline.erase("clip")
			check(selected==baseline,"both slashes preserve resolved footprint including graft patterns: "+pattern)

func pose(actor: Dictionary, reference: Dictionary, phase: float, active: bool, clip: String, delta: float) -> void:
	var action:={"equipped":true,"aim_yaw":0.0,"clip":clip,"contact":.42,"combo":1}
	Avatar.animate(actor,active,phase,"blade",action,delta)
	Avatar.animate(reference,false,0.0,"",{"equipped":false},delta)
	Weapons.animate(actor,"blade",phase,active,0,2.25,action)

func inspect_body(body: int) -> void:
	var parent:=Node3D.new();root.add_child(parent)
	var stage:=preload("res://stage.gd").new()
	var actor:=Avatar.build(parent);Avatar.swap(actor,body)
	var reference:=Avatar.build(parent);Avatar.swap(reference,body)
	actor.visual_weapon=Weapons.build(stage,0,0)
	actor.visual_weapon.reparent(actor.model,false)
	var skeleton: Skeleton3D=actor.field_rig.skeleton
	var other: Skeleton3D=reference.field_rig.skeleton
	var hand:=skeleton.find_bone("hand_r")
	var grip_error:=0.0;var lower_error:=0.0;var clearance:=INF;var step_error:=0.0
	var worst: Array=[]
	var count:=0
	for variant: Dictionary in Motion.profile("blade").basic_variants:
		for speed in [0.0,1.4,3.5,7.0]:
			actor.speed=speed;actor.pace=1.0 if speed>0 else 0.0
			reference.speed=speed;reference.pace=actor.pace
			for warmup in 20:pose(actor,reference,0.0,false,variant.clip,1.0/120.0)
			var previous: Array[Quaternion]=[]
			var recovery_seen:=false
			for step in 121:
				var phase:=step/120.0
				actor.gait_travel=speed*.003;actor.gait_vector=Vector3.BACK*speed*.003
				reference.gait_travel=actor.gait_travel;reference.gait_vector=actor.gait_vector
				pose(actor,reference,phase,true,variant.clip,.003)
				grip_error=maxf(grip_error,actor.visual_weapon.global_position.distance_to(Field.hand(actor,false)))
				var timing:=Native.playback(actor.field_rig.player,"blade",phase,1,variant.clip)
				var current: Array[Quaternion]=[]
				for side in ["r","l"]:
					for joint in ["upperarm_","lowerarm_","hand_"]:
						var q:=skeleton.get_bone_pose_rotation(skeleton.find_bone(joint+side))
						if not previous.is_empty() and previous[current.size()].angle_to(q)>step_error:
							step_error=previous[current.size()].angle_to(q);worst=[variant.clip,speed,phase,joint+side,timing]
						current.append(q)
				previous=current
				var closest:=Geometry3D.get_closest_points_between_segments(skeleton.get_bone_global_pose(skeleton.find_bone("lowerarm_r")).origin,
					skeleton.get_bone_global_pose(hand).origin,skeleton.get_bone_global_pose(skeleton.find_bone("spine_01")).origin,
					skeleton.get_bone_global_pose(skeleton.find_bone("spine_03")).origin)
				clearance=minf(clearance,closest[0].distance_to(closest[1]))
				for bone in skeleton.get_bone_count():
					check(skeleton.get_bone_global_pose(bone).is_finite(),"finite imported pose")
					if not Native.upper_body(skeleton.get_bone_name(bone)):
						lower_error=maxf(lower_error,(skeleton.get_bone_pose_rotation(bone)-other.get_bone_pose_rotation(bone)).length())
				lower_error=maxf(lower_error,skeleton.get_bone_pose_position(actor.field_rig.pelvis).distance_to(other.get_bone_pose_position(reference.field_rig.pelvis)))
				if is_equal_approx(phase,.425) and variant.clip=="Attack_rootblade_backhand":
					# glTF's +Z face is Blender's -Y face after the Z-up conversion.
					check(actor.visual_weapon.global_basis.z.normalized().y>.9,"backhand turns palm/blade face downward")
				count+=1
			for frame in 90:
				pose(actor,reference,0.0,false,variant.clip,1.0/60.0)
				var expected: String="Recover_rootblade_left" if variant.clip=="Attack_rootblade_forehand" else "Recover_rootblade_right"
				recovery_seen=recovery_seen or str(actor.field_rig.player.current_animation)==expected
			check(recovery_seen,"each slash uses its own imported return clip after the active swing")
			check(actor.visual_weapon.global_basis.y.normalized().y<-.4,"weapon returns to low ready rather than raised guard")
			check(not actor.field_rig.rootblade.has("last_clip"),"completed visual recovery cannot remain pending")
	print("ROOTBLADE BODY ",body," poses=",count," grip_error_m=",grip_error," lower_body_error=",lower_error," forearm_clearance_m=",clearance," max_joint_step_rad=",step_error," worst=",worst)
	check(grip_error<.001,"weapon remains in the hand on both bodies")
	check(lower_error<.00001,"lower-body locomotion is unchanged")
	check(clearance>.14,"forearm stays outside torso")
	check(step_error<.36,"continuous authored cuts and recovery")
	parent.free();stage.free()

func inspect_combat() -> void:
	var world: Node=load("res://world.tscn").instantiate()
	var path:="res://.godot/rootblade-"+str(OS.get_process_id())
	world.progress.path=path+".garden";world.local_character.path=path+".character";world.guest_character.path=path+".guest"
	root.add_child(world);world.set_process(false);world.set_physics_process(false)
	var actor: Dictionary=world.players[1]
	preload("res://tests/support/expedition_case.gd").set_membership(world,actor,true)
	actor.frame=0;actor.weapon_kind=0;actor.weapon=0;actor.secondary=0;actor.catalyst=0
	actor.pos=Vector3.ZERO;actor.facing=Vector3.BACK;actor.mouse_aim=true;actor.aim_direction=Vector3.BACK
	actor[Actions.STATE]=Actions.State.new()
	preload("res://tests/support/terrain_case.gd").walls(world.battlefield,[])
	world.tactics.position=Vector3(20,0,20);world.encounter.clear_scouts()
	var target: int=world.encounter.register_scout(world.make_scout(0,Vector3(0,0,1.7),1))
	world.encounter.set_hp(target,1000)
	var case=preload("res://tests/support/weapon_attack_case.gd")
	var first_outline:=PackedVector3Array()
	for step in 3:
		actor[Actions.STATE]=actor[Actions.STATE].with_ready_at(0)
		var hp: int=world.encounter.hp(target)
		check(case.start(world,1,actor.pos),"real Rootblade basic admission")
		var shot: Dictionary=world.weapon_attacks.views()[0]
		var event: Dictionary=world.combat_events.filter(func(e):return e.kind=="swing").back()
		var shape:=Contact.describe("blade",shot.stats)
		var expected: String="Attack_rootblade_forehand" if step%2==0 else "Attack_rootblade_backhand"
		check(shape.clip==expected and event.clip==expected,"host freezes alternating clip into queued contact and event")
		check(event.pattern=="sweep" and is_equal_approx(event.span,1.9),"both slashes retain the existing indicator")
		var outline:=Contact.outline(shape,actor.pos,Vector3.BACK)
		if step==0:first_outline=outline
		else:check(outline==first_outline,"second slash and subsequent slashes have the identical hit contour")
		case.advance(world,int(shot.release)-1)
		check(world.encounter.hp(target)==hp,"no damage before unchanged release")
		case.advance(world,int(shot.release))
		check(world.encounter.hp(target)<hp,"real Rootblade damage after release")
		var after: int=world.encounter.hp(target)
		case.advance(world,int(shot.release)+100)
		check(world.encounter.hp(target)==after,"contact cannot deal duplicate damage")
	world.queue_free();await process_frame
