extends SceneTree
## The two approved clips and the same host-selected shape from queue to indicator.
const Actions=preload("res://player_weapon_actions.gd")
const Motion=preload("res://weapon_motion.gd")
const Contact=preload("res://weapon_contact.gd")
const Avatar=preload("res://traveller_avatar.gd")
const Field=preload("res://field_traveller.gd")
const Weapons=preload("res://weapon_visuals.gd")
const Expedition=preload("res://tests/support/expedition_case.gd")
const Terrain=preload("res://tests/support/terrain_case.gd")
const Case=preload("res://tests/support/weapon_attack_case.gd")
var failed:=false

func check(ok: bool,message: String) -> void:
	if not ok:failed=true;printerr("FAIL spear attacks: ",message)

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var state:=Actions.State.new().try_start(1000,650,420,3.1,"spear")
	check(state.basic_step()==1 and Motion.basic_variant("spear",state.basic_step()).clip=="Attack_spear","first admitted basic is thrust")
	var old:=state
	state=state.core_pose(1650,420,3.1,Vector3.BACK,"Attack_staff","line",0,false)
	state=state.try_start(2070,650,420,3.1,"spear")
	check(state.basic_step()==2 and Motion.basic_variant("spear",state.basic_step()).clip=="Attack_spear_sweep","Core does not disturb basic alternation")
	check(old.basic_step()==1 and old.try_start(1000,650,420,3.1,"spear")==null,"rollback value and refused duplicate retain the step")
	state=state.try_start(2720,650,420,3.1,"spear")
	check(Motion.basic_variant("spear",state.basic_step()).clip=="Attack_spear","third attack is thrust again")
	check(state.ready_at_ms()==3370 and state.duration_ms()==420,"original cadence and pose timing")
	for body in 2:inspect_body(body)
	await inspect_combat()
	if not failed:print("PASS: approved spear clips on both bodies; locomotion/grips; thrust-sweep sequence, distinct authoritative hit geometry, footprint, terrain, once-only contact and rollback identity")
	quit(1 if failed else 0)

func inspect_body(body: int) -> void:
	var parent:=Node3D.new();root.add_child(parent)
	var stage:=preload("res://stage.gd").new()
	var actor:=Avatar.build(parent)
	Avatar.swap(actor,body)
	var reference:=Avatar.build(parent)
	Avatar.swap(reference,body)
	actor.visual_weapon=Weapons.build(stage,0,1)
	actor.visual_weapon.reparent(actor.model,false)
	actor.model.rotation.y=0
	var rig: Skeleton3D=actor.field_rig.skeleton
	var lower_rig: Skeleton3D=reference.field_rig.skeleton
	var grip_error:=0.0
	var clearance:=INF
	var joint_step:=0.0
	var poses:=0
	var lower_error:=0.0
	var worst_clearance: Array=[]
	var worst_step: Array=[]
	for variant: Dictionary in Motion.profile("spear").basic_variants:
		for speed in [0.0,1.4,3.5,7.0]:
			actor.speed=speed;actor.pace=1.0 if speed>0 else 0.0
			reference.speed=speed;reference.pace=actor.pace
			var previous: Array[Quaternion]=[]
			var across:=Vector2(INF,-INF)
			for step in 121:
				var phase:=step/120.0
				var action:={"equipped":true,"aim_yaw":0.0,"contact":.42,"clip":variant.clip}
				actor.gait_travel=speed*.0035;actor.gait_vector=Vector3.BACK*speed*.0035
				reference.gait_travel=actor.gait_travel;reference.gait_vector=actor.gait_vector
				Avatar.animate(actor,true,phase,"spear",action,.0035)
				Avatar.animate(reference,false,0.0,"blade",{"equipped":false},.0035)
				Weapons.animate(actor,"spear",phase,true,0.0,3.1,action)
				var weapon: Node3D=actor.visual_weapon
				grip_error=maxf(grip_error,weapon.to_global(weapon.get_meta("handle")).distance_to(Field.hand(actor,false)))
				grip_error=maxf(grip_error,weapon.to_global(weapon.get_meta("support_grip")).distance_to(Field.hand(actor,true)))
				for side in ["r","l"]:
					var pair:=Geometry3D.get_closest_points_between_segments(
						rig.get_bone_global_pose(rig.find_bone("lowerarm_"+side)).origin,rig.get_bone_global_pose(rig.find_bone("hand_"+side)).origin,
						rig.get_bone_global_pose(rig.find_bone("spine_01")).origin,rig.get_bone_global_pose(rig.find_bone("spine_03")).origin)
					if pair[0].distance_to(pair[1])<clearance:
						clearance=pair[0].distance_to(pair[1]);worst_clearance=[variant.clip,speed,phase,side]
				var current: Array[Quaternion]=[]
				for side in ["r","l"]:
					for joint in ["upperarm_","lowerarm_","hand_"]:
						var rotation:=rig.get_bone_pose_rotation(rig.find_bone(joint+side))
						if not previous.is_empty() and previous[current.size()].angle_to(rotation)>joint_step:
							joint_step=previous[current.size()].angle_to(rotation);worst_step=[variant.clip,speed,phase,side,joint]
						current.append(rotation)
				previous=current
				if variant.delivery=="sweep":
					var tip: Vector3=weapon.get_node("WeaponTip").global_position
					across=Vector2(minf(across.x,tip.x),maxf(across.y,tip.x))
					if step==38:check(float(weapon.get_meta("handle").y)<-.30 and float(weapon.get_meta("support_grip").y)<-.10,"sweep slides both grips toward the butt")
				# Compare against an independently animated locomotion-only character.
				for bone in rig.get_bone_count():
					check(rig.get_bone_global_pose(bone).is_finite(),"finite imported pose")
					if not preload("res://traveller_weapon_animation.gd").upper_body(rig.get_bone_name(bone)):
						lower_error=maxf(lower_error,(rig.get_bone_pose_rotation(bone)-lower_rig.get_bone_pose_rotation(bone)).length())
				lower_error=maxf(lower_error,rig.get_bone_pose_position(actor.field_rig.pelvis).distance_to(lower_rig.get_bone_pose_position(reference.field_rig.pelvis)))
				poses+=1
			if variant.delivery=="sweep":check(across.y-across.x>2.0,"sweep traverses the front instead of thrusting")
	print("SPEAR BODY ",body," poses=",poses," grip_error_m=",grip_error," min_forearm_clearance_m=",clearance," max_arm_step_rad=",joint_step," lower_body_error=",lower_error)
	print("SPEAR WORST: ",worst_clearance," / ",worst_step)
	check(grip_error<.01,"both hands retain the sliding shaft on body "+str(body))
	check(clearance>.14,"forearms stay outside the torso on body "+str(body))
	check(joint_step<.36,"continuous retargeted motion on body "+str(body))
	check(lower_error<.00001,"legs and pelvis retain existing locomotion on body "+str(body))
	parent.free();stage.free()

func inspect_combat() -> void:
	var world: Node=load("res://world.tscn").instantiate()
	var path:="res://.godot/spear-"+str(OS.get_process_id())
	world.progress.path=path+".garden";world.local_character.path=path+".character";world.guest_character.path=path+".guest"
	root.add_child(world);world.set_process(false);world.set_physics_process(false)
	var actor: Dictionary=world.players[1]
	Expedition.set_membership(world,actor,true)
	actor.frame=0;actor.weapon_kind=1;actor.weapon=0;actor.secondary=0;actor.catalyst=0
	actor.pos=Vector3.ZERO;actor.facing=Vector3.BACK;actor.mouse_aim=true;actor.aim_direction=Vector3.BACK
	actor[Actions.STATE]=Actions.State.new()
	Terrain.walls(world.battlefield,[])
	world.tactics.position=Vector3(20,0,20);world.encounter.clear_scouts()
	var front: int=world.encounter.register_scout(world.make_scout(0,Vector3(0,0,2.0),1))
	var side: int=world.encounter.register_scout(world.make_scout(0,Vector3(1.6,0,1.6),2))
	world.encounter.set_hp(front,1000);world.encounter.set_hp(side,1000)
	for step in 3:
		actor[Actions.STATE]=actor[Actions.STATE].with_ready_at(0)
		var hp_front: int=world.encounter.hp(front);var hp_side: int=world.encounter.hp(side)
		check(Case.start(world,1,actor.pos),"real basic admission")
		var shot: Dictionary=world.weapon_attacks.views()[0]
		var event: Dictionary=world.combat_events.filter(func(e):return e.kind=="swing").back()
		var shape:=Contact.describe("spear",shot.stats)
		var sweeping:=step==1
		check(shape.clip==("Attack_spear_sweep" if sweeping else "Attack_spear") and event.clip==shape.clip,"host freezes the selected clip for queue and event")
		check(event.pattern==("sweep" if sweeping else "line") and is_equal_approx(event.span,shape.span),"matching authoritative footprint")
		check(Contact.accepts(world,side,actor.pos,Vector3.BACK,"spear",shot.stats)==sweeping,"only the sweep accepts the side target")
		var outline:=Contact.outline(shape,actor.pos,Vector3.BACK)
		check(outline.size()>16 and (outline[0].is_zero_approx()==sweeping),"sweep fan and thrust corridor have different contours")
		Case.advance(world,int(shot.release)-1)
		check(world.encounter.hp(front)==hp_front and world.encounter.hp(side)==hp_side,"no damage before unchanged release")
		Case.advance(world,int(shot.release))
		check(world.encounter.hp(front)<hp_front and (world.encounter.hp(side)<hp_side)==sweeping,"actual damage follows selected area")
		var after:=Vector2(world.encounter.hp(front),world.encounter.hp(side))
		Case.advance(world,int(shot.release)+100)
		check(after==Vector2(world.encounter.hp(front),world.encounter.hp(side)),"contact cannot replay")
		Terrain.add_wall(world.battlefield,Rect2(-.6,.6,1.2,.2))
		check(not Contact.accepts(world,front,actor.pos,Vector3.BACK,"spear",shot.stats),"terrain still blocks selected contact")
		Terrain.walls(world.battlefield,[])
	world.queue_free();await process_frame
