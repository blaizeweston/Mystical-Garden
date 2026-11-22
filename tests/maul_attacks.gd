extends SceneTree
## Reviewed Maul presentation plus the real, unchanged host contact path.
const Actions=preload("res://player_weapon_actions.gd")
const Motion=preload("res://weapon_motion.gd")
const Maul=preload("res://maul_animation.gd")
const Avatar=preload("res://traveller_avatar.gd")
const Field=preload("res://field_traveller.gd")
const Weapons=preload("res://weapon_visuals.gd")
const Contact=preload("res://weapon_contact.gd")
const Codec=preload("res://world_snapshot.gd")
const Expedition=preload("res://tests/support/expedition_case.gd")
const Terrain=preload("res://tests/support/terrain_case.gd")
const Case=preload("res://tests/support/weapon_attack_case.gd")
var failed:=false

func check(ok: bool,message: String) -> void:
	if not ok:failed=true;printerr("FAIL Maul attacks: ",message)

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var state:=Actions.State.new().try_start(1000,900,620,2.4,"hammer")
	var old:=state
	check(Motion.basic_variant("hammer",state.basic_step()).clip=="Attack_maul_overhead","first accepted attack is overhead")
	check(state.try_start(1000,900,620,2.4,"hammer")==null,"duplicate does not advance the sequence")
	state=state.core_pose(1900,420,2.4,Vector3.BACK,"Attack_staff","line",0,false)
	state=state.try_start(2320,900,620,2.4,"hammer")
	check(Motion.basic_variant("hammer",state.basic_step()).clip=="Attack_maul_sweep","native/Core does not advance ordinary alternation")
	check(old.basic_step()==1 and old.ready_at_ms()==1900,"rollback value remains immutable")
	check(state.duration_ms()==620 and state.ready_at_ms()==3220,"original Maul pose and attack interval")
	check(Motion.profile("hammer").release==.48 and Codec.PLAYER_BYTES==137 and Codec.SCOUT_BYTES==21,"unchanged release and protocol-41 frame layout")
	for pattern in ["sweep","line","splash","chain"]:
		var stats:={"reach":2.4,"pattern":pattern}
		var original:=Contact.describe("hammer",stats)
		for clip in ["Attack_maul_overhead","Attack_maul_sweep"]:
			var shape:=Contact.describe("hammer",stats.merged({"weapon_variant":clip}))
			check(shape.clip==clip and Codec.CLIPS.has(clip),"authoritative clip is serializable")
			shape.erase("clip");var expected:=original.duplicate();expected.erase("clip")
			check(shape==expected,"clip-only variant preserves resolved geometry and graft pattern")
	for body in 2:inspect_body(body)
	await inspect_combat()
	if not failed:print("PASS: Maul overhead/sweep, both rigs and recoveries, face trajectory, grips, locomotion, unchanged contact/timing, exactly-once damage and rollback")
	quit(1 if failed else 0)

func draw(actor: Dictionary,active: bool,phase: float,clip: String,sequence: int,delta: float) -> void:
	var motion:={"equipped":true,"aim_yaw":0.0,"contact":.48,"combo":sequence,"clip":clip}
	Avatar.animate(actor,active,phase,"hammer",motion,delta)
	Weapons.animate(actor,"hammer",phase,active,0,2.4,motion)

func point(rig: Skeleton3D,name: String) -> Vector3:
	return rig.get_bone_global_pose(rig.find_bone(name)).origin

func inspect_body(body: int) -> void:
	var parent:=Node3D.new();root.add_child(parent)
	var stage:=preload("res://stage.gd").new()
	var actor:=Avatar.build(parent);Avatar.swap(actor,body)
	var reference:=Avatar.build(parent);Avatar.swap(reference,body)
	actor.visual_weapon=Weapons.build(stage,0,2);actor.visual_weapon.reparent(actor.model,false)
	actor.model.rotation.y=0
	var rig: Skeleton3D=actor.field_rig.skeleton
	var lower: Skeleton3D=reference.field_rig.skeleton
	var grip_error:=0.0;var lower_error:=0.0;var face_alignment:=1.0;var highest:=0.0
	var sequence:=0;var worst_step:=0.0;var worst_pose: Array=[]
	var forward_forearm:=1.0;var low_elbow:=INF
	for clip in ["Attack_maul_overhead","Attack_maul_sweep"]:
		for speed in [0.0,1.4,3.5,7.0]:
			sequence+=1
			actor.speed=speed;actor.pace=1.0 if speed>0 else 0.0
			reference.speed=speed;reference.pace=actor.pace
			var previous: Array[Quaternion]=[]
			var prior_head:=Vector3.ZERO
			for step in 181:
				var phase:=step/180.0
				actor.gait_travel=speed/240;actor.gait_vector=Vector3.BACK*speed/240
				reference.gait_travel=actor.gait_travel;reference.gait_vector=actor.gait_vector
				draw(actor,true,phase,clip,sequence,1.0/240)
				Avatar.animate(reference,false,0,"",{},1.0/240)
				var weapon: Node3D=actor.visual_weapon
				for side in ["right","left"]:
					var key: String="handle" if side=="right" else "support_grip"
					grip_error=maxf(grip_error,weapon.to_global(weapon.get_meta(key)).distance_to(Field.hand(actor,side=="left")))
				var head:=weapon.to_global(Vector3(0,.95,0))
				if phase>.43 and phase<.53 and step>0:
					var velocity:=head-prior_head
					var shaft:=weapon.global_basis.y.normalized()
					var tangent:=velocity-shaft*velocity.dot(shaft)
					if tangent.length()>.00001:face_alignment=minf(face_alignment,absf(tangent.normalized().dot(weapon.global_basis.x.normalized())))
				prior_head=head
				highest=maxf(highest,Field.hand(actor,false).y-point(rig,"spine_03").y)
				var current: Array[Quaternion]=[]
				for side in ["r","l"]:
					for joint in ["upperarm_","lowerarm_","hand_"]:
						var rotation:=rig.get_bone_pose_rotation(rig.find_bone(joint+side))
						if not previous.is_empty() and previous[current.size()].angle_to(rotation)>worst_step:
							worst_step=previous[current.size()].angle_to(rotation);worst_pose=[clip,speed,phase,side,joint]
						current.append(rotation)
				previous=current
				for bone in rig.get_bone_count():
					check(rig.get_bone_global_pose(bone).is_finite(),"finite imported pose")
					if not preload("res://traveller_weapon_animation.gd").upper_body(rig.get_bone_name(bone)):
						lower_error=maxf(lower_error,(rig.get_bone_pose_rotation(bone)-lower.get_bone_pose_rotation(bone)).length())
				lower_error=maxf(lower_error,rig.get_bone_pose_position(actor.field_rig.pelvis).distance_to(lower.get_bone_pose_position(reference.field_rig.pelvis)))
			# Every single swing must return instead of indefinitely holding its end pose.
			for frame in 65:
				draw(actor,false,0,clip,sequence,1.0/240)
				Avatar.animate(reference,false,0,"",{},1.0/240)
				if clip=="Attack_maul_sweep" and frame==16:
					var chest:=rig.find_bone("spine_03")
					var forward: Vector3=rig.get_bone_global_pose(chest).basis*rig.get_bone_global_rest(chest).basis.inverse()*Vector3.BACK
					var forearm: Vector3=(point(rig,"hand_l")-point(rig,"lowerarm_l")).normalized()
					forward_forearm=minf(forward_forearm,forearm.dot(forward.normalized()))
					low_elbow=minf(low_elbow,point(rig,"upperarm_l").y-point(rig,"lowerarm_l").y)
					if speed==0:print("MAUL RETURN VECTORS body=",body," forearm=",forearm," forward=",forward," elbow=",point(rig,"lowerarm_l")-point(rig,"upperarm_l"))
			var ready: String="Ready_maul_sweep" if clip=="Attack_maul_sweep" else "Ready_maul"
			check(actor.field_rig.player.current_animation==ready,"matching ready after a single "+clip)
			check(actor.field_rig.maul_sample.right_grip==(-.10 if clip=="Attack_maul_sweep" else -.25),"reviewed hand ordering retained")
	print("MAUL BODY ",body," grip_error_m=",grip_error," lower_body_error=",lower_error," face_alignment=",face_alignment," overhead_height=",highest," max_arm_step_rad=",worst_step)
	print("MAUL WORST ",worst_pose)
	print("MAUL SWEEP RETURN forward_forearm_cosine=",forward_forearm," elbow_below_shoulder_m=",low_elbow)
	check(grip_error<.012,"two-handed shaft attachment on body "+str(body))
	check(lower_error<.00001,"original leg and pelvis locomotion on body "+str(body))
	check(face_alignment>.85,"striking end face follows trajectory on body "+str(body))
	check(highest>.20,"overhead reaches above the chest")
	check(forward_forearm>.85 and low_elbow>.12,"reviewed sweep return keeps left elbow low and forearm forward")
	# At the unchanged 620 ms gameplay pose, the reviewed wrist turnover is
	# compressed with the rest of the clip. Reject a flip, not its intended turn.
	check(worst_step<.50,"reviewed wrist turnover has no discontinuous flip")
	# A next admitted action may interrupt the visual return without a new cooldown.
	draw(actor,true,.99,"Attack_maul_overhead",sequence+1,.01)
	draw(actor,false,0,"Attack_maul_overhead",sequence+1,.04)
	draw(actor,true,0,"Attack_maul_sweep",sequence+2,.01)
	check(actor.field_rig.player.current_animation=="Attack_maul_sweep","new swing interrupts recovery")
	Avatar.animate(actor,true,.3,"hammer",{"ability":true,"clip":"Attack_hammer"},.01)
	check(not actor.field_rig.maul_active and not actor.field_rig.maul.has("last_attack") and not actor.field_rig.has("maul_sample"),"native action clears cosmetic Maul recovery")
	parent.free();stage.free()

func inspect_combat() -> void:
	var world: Node=load("res://world.tscn").instantiate()
	var path:="user://maul-"+str(OS.get_process_id())
	world.progress.path=path+".garden";world.local_character.path=path+".character";world.guest_character.path=path+".guest"
	root.add_child(world);world.set_process(false);world.set_physics_process(false)
	var actor: Dictionary=world.players[1]
	Expedition.set_membership(world,actor,true)
	actor.frame=0;actor.weapon_kind=2;actor.weapon=0;actor.secondary=0;actor.catalyst=0
	actor.pos=Vector3.ZERO;actor.facing=Vector3.BACK;actor.mouse_aim=true;actor.aim_direction=Vector3.BACK
	actor[Actions.STATE]=Actions.State.new()
	Terrain.walls(world.battlefield,[])
	world.tactics.position=Vector3(20,0,20);world.encounter.clear_scouts()
	var target: int=world.encounter.register_scout(world.make_scout(0,Vector3(0,0,1.7),1))
	world.encounter.set_hp(target,10000)
	for step in 3:
		actor[Actions.STATE]=actor[Actions.STATE].with_ready_at(0)
		var before: int=world.encounter.hp(target)
		check(Case.start(world,1,Vector3.ZERO),"real queued Maul attack admitted")
		check(not Case.start(world,1,Vector3.ZERO),"same-frame duplicate refused")
		var until_ms: int=actor[Actions.STATE].pose_until_ms()
		var animation: Dictionary=actor[Actions.STATE].animation(until_ms-1,Vector3.BACK,false,Vector3.BACK,"")
		check(animation.clip==("Attack_maul_sweep" if step==1 else "Attack_maul_overhead"),"host-selected alternating clip")
		var release_ms: int=until_ms-actor[Actions.STATE].duration_ms()+roundi(actor[Actions.STATE].duration_ms()*.48)
		Case.advance(world,release_ms-1)
		check(world.encounter.hp(target)==before,"no damage before original release")
		Case.advance(world,until_ms+1)
		var after: int=world.encounter.hp(target)
		check(after<before,"real damage at release")
		Case.advance(world,until_ms+1)
		check(world.encounter.hp(target)==after,"repeated advance cannot damage twice")
	world.free();await process_frame
