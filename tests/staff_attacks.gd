extends SceneTree
## Actual imported staff poses and the real host release/contact path. Saves are fixtures.
const Avatar=preload("res://traveller_avatar.gd")
const Appearance=preload("res://character_appearance.gd")
const Field=preload("res://field_traveller.gd")
const Weapons=preload("res://weapon_visuals.gd")
const Staff=preload("res://staff_animation.gd")
const Motion=preload("res://weapon_motion.gd")
const Actions=preload("res://player_weapon_actions.gd")
const Codec=preload("res://world_snapshot.gd")
const Case=preload("res://tests/support/weapon_attack_case.gd")
const Expedition=preload("res://tests/support/expedition_case.gd")
const Terrain=preload("res://tests/support/terrain_case.gd")
var failed:=false

func check(ok: bool,message: String) -> void:
	if not ok:failed=true;printerr("FAIL staff attacks: ",message)
func _initialize() -> void:call_deferred("run")

func draw(actor: Dictionary,active: bool,phase: float,clip: String,sequence: int,delta: float) -> void:
	var motion:={"equipped":true,"aim_yaw":0.0,"contact":.42,"combo":sequence,"clip":clip}
	Avatar.animate(actor,active,phase,"staff",motion,delta)
	Weapons.animate(actor,"staff",phase,active,0,4.0,motion)

func release_event(body: int,height: float,clip: String,sequence: int) -> Dictionary:
	return {"id":1,"kind":"projectile","shape":"spell","form":"staff","from":[0,0,1.05],"to":[0,0,4.0],"duration":.15,"color":"#abcfff","reach":4.0,"projectile_radius":.11,"height":1.23,"owner":1,"combo":sequence,"clip":clip,
		"weapon_release":{"position":[0,0,0],"yaw":0.0,"body":body,"height":height}}

func run() -> void:
	check(Motion.profile("staff").duration==.45 and Motion.profile("staff").release==.42,"unchanged 450 ms pose and 42% release")
	check(Codec.PLAYER_BYTES==137 and Codec.SCOUT_BYTES==21,"protocol-41 compact layout unchanged")
	var state:=Actions.State.new().try_start(1000,720,450,4.0,"staff")
	check(Motion.basic_variant("staff",state.basic_step()).clip=="Attack_staff_forward","first admitted cast")
	check(state.try_start(1000,720,450,4,"staff")==null,"duplicate does not advance alternation")
	state=state.core_pose(1720,420,4.0,Vector3.BACK,"Attack_staff","line",0,false)
	state=state.try_start(2140,720,450,4,"staff")
	check(Motion.basic_variant("staff",state.basic_step()).clip=="Attack_staff_side" and state.ready_at_ms()==2860,"class/Core preserves alternation and cadence")
	for body in 2:
		for height in [.92,1.0,1.08]:inspect_body(body,height)
	await inspect_combat()
	if not failed:print("PASS: staff casts/recoveries on both rigs and heights, grips, upright translation, original locomotion/cadence, actual-tip and delayed launch, exactly-once host contact and stale cleanup")
	quit(1 if failed else 0)

func inspect_body(body: int,height: float) -> void:
	var parent:=Node3D.new();root.add_child(parent);parent.position=Vector3(80,0,0)
	var stage:=preload("res://stage.gd").new()
	var actor:=Avatar.build(parent);Avatar.swap(actor,body)
	var reference:=Avatar.build(parent);Avatar.swap(reference,body)
	actor.model.scale.y=height;reference.model.scale.y=height
	actor.model.rotation.y=0;reference.model.rotation.y=0
	actor.visual_weapon=Weapons.build(stage,1,0);actor.visual_weapon.reparent(actor.model,false)
	var rig: Skeleton3D=actor.field_rig.skeleton
	var lower: Skeleton3D=reference.field_rig.skeleton
	var grip_error:=0.0;var lower_error:=0.0;var cache_error:=0.0;var min_leg_gap:=INF
	for clip in ["Attack_staff_forward","Attack_staff_side"]:
		check(Codec.CLIPS.has(clip),"host cast has a serializable clip")
		for speed in [0.0,3.5]:
			actor.speed=speed;actor.pace=1.0 if speed>0 else 0.0;reference.speed=speed;reference.pace=actor.pace
			for frame in 24:draw(actor,false,0,clip,0,1.0/120);Avatar.animate(reference,false,0,"",{},1.0/120)
			var initial: Basis=actor.visual_weapon.global_basis
			var initial_palm:=Field.hand(actor,false)
			for step in 101:
				var phase:=step/100.0
				actor.gait_travel=speed/120;actor.gait_vector=Vector3.BACK*speed/120
				reference.gait_travel=actor.gait_travel;reference.gait_vector=actor.gait_vector
				draw(actor,true,phase,clip,1,1.0/120);Avatar.animate(reference,false,0,"",{},1.0/120)
				var weapon: Node3D=actor.visual_weapon
				for side in ["right","left"]:
					var key: String="handle" if side=="right" else "support_grip"
					grip_error=maxf(grip_error,weapon.to_global(weapon.get_meta(key)).distance_to(Field.hand(actor,side=="left")))
				for bone in rig.get_bone_count():
					check(rig.get_bone_global_pose(bone).is_finite(),"finite pose")
					if not preload("res://traveller_weapon_animation.gd").upper_body(rig.get_bone_name(bone)):
						lower_error=maxf(lower_error,(rig.get_bone_pose_rotation(bone)-lower.get_bone_pose_rotation(bone)).length())
				lower_error=maxf(lower_error,rig.get_bone_pose_position(actor.field_rig.pelvis).distance_to(lower.get_bone_pose_position(reference.field_rig.pelvis)))
				if speed==0:
					check(weapon.global_basis.get_rotation_quaternion().angle_to(initial.get_rotation_quaternion())<.012,"upright shaft translates without extra tilt")
					var butt:=weapon.to_global(Vector3(0,-.55,0))
					for side in ["l","r"]:
						var thigh:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("thigh_"+side)).origin)
						var knee:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("calf_"+side)).origin)
						min_leg_gap=minf(min_leg_gap,butt.distance_to(Geometry3D.get_closest_point_to_segment(butt,thigh,knee)))
				if step==42 and speed==0:
					check(Field.hand(actor,false).z-initial_palm.z>.05,"approved forward push")
					var tip: Vector3=weapon.get_node("WeaponTip").global_position
					cache_error=maxf(cache_error,Staff.release_offset(body,clip,height).distance_to(tip-stage.WILD_OFFSET))
					stage.avatar_models[1]=actor;actor.motion_key="weapon:1"
					var event:=release_event(body,height,clip,1)
					check(stage.weapon_release_point(event).distance_to(tip)<.0001,"current matching cast emits from the actual staff tip")
					var fx:=preload("res://combat_effects.gd").new();fx.stage=stage;root.add_child(fx)
					fx.sync([event],[],"staff",Vector3.ZERO)
					var frozen: Vector3=fx.active[1].visual_from
					check(frozen.distance_to(tip-stage.WILD_OFFSET)<.0001,"projectile glyph starts at tip, no character-origin gap")
					actor.model.position.x+=2;fx.pose(fx.active[1]);fx.sync([event],[],"staff",Vector3.ZERO)
					check(fx.active.size()==1 and fx.active[1].visual_from==frozen,"release freezes once; duplicate event cannot follow/restart")
					actor.model.position.x-=2;fx.clear();fx.free()
			for frame in 30:draw(actor,false,0,clip,1,1.0/120);Avatar.animate(reference,false,0,"",{},1.0/120)
			check(actor.field_rig.player.current_animation=="Ready_staff_authored","individual recovery ends in ready")
	print("STAFF BODY ",body," height=",height," grip_error_m=",grip_error," lower_error=",lower_error," cached_tip_error_m=",cache_error," leg_center_gap_m=",min_leg_gap)
	check(grip_error<.012,"both hands remain on shaft")
	check(lower_error<.00001,"unchanged lower-body locomotion")
	check(cache_error<.03,"delayed event preserves cast-tip origin on this body/height")
	check(min_leg_gap>.12,"staff butt stays clear of leg centerlines")
	stage.avatar_models.clear()
	var delayed:=release_event(body,height,"Attack_staff_side",3)
	var predicted:=stage.weapon_release_point(delayed)
	check(predicted.is_finite() and (predicted-stage.WILD_OFFSET).distance_to(Staff.release_offset(body,"Attack_staff_side",height))<.0001,"late release works without a current actor pose")
	var bad:=delayed.duplicate(true);bad.weapon_release.position=[0,INF,0]
	check(not stage.weapon_release_point(bad).is_finite(),"malformed visual facts fail closed")
	draw(actor,true,.99,"Attack_staff_forward",8,.01);draw(actor,false,0,"Attack_staff_forward",8,.04)
	draw(actor,true,.2,"Attack_staff_side",9,.01)
	check(actor.field_rig.player.current_animation=="Attack_staff_side","next cast interrupts recovery")
	Avatar.animate(actor,true,.3,"staff",{"ability":true,"clip":"Attack_staff"},.01)
	check(not actor.field_rig.staff_active and not actor.field_rig.staff.has("last_attack"),"class/Core clears cosmetic recovery")
	parent.free();stage.free()

func inspect_combat() -> void:
	var world: Node=load("res://world.tscn").instantiate()
	var path:="user://staff-"+str(OS.get_process_id())
	world.progress.path=path+".garden";world.local_character.path=path+".character";world.guest_character.path=path+".guest"
	root.add_child(world);world.set_process(false);world.set_physics_process(false)
	var actor: Dictionary=world.players[1]
	Expedition.set_membership(world,actor,true)
	actor.frame=1;actor.weapon_kind=0;actor.weapon=0;actor.secondary=0;actor.catalyst=0
	actor.pos=Vector3.ZERO;actor.facing=Vector3.BACK;actor.mouse_aim=true;actor.aim_direction=Vector3.BACK
	actor[Actions.STATE]=Actions.State.new()
	Terrain.walls(world.battlefield,[]);world.encounter.clear_scouts();world.encounter.set_hp(-1,1000);world.tactics.position=Vector3(0,0,3)
	var now:=preload("res://combat_clock.gd").now()
	var stats:={"damage":1.0,"reach":4.0,"targets":1,"pattern":"single","weapon_variant":"Attack_staff_forward"}
	var id:=Case.schedule(world,1,actor.pos,stats,now,"staff",450)
	var shot: Dictionary=world.weapon_attacks.inspect(id)
	Case.advance(world,int(shot.release)-1)
	check(world.enemy_health()==1000,"no damage before original release")
	Case.advance(world,int(shot.release))
	var events: Array=world.combat_events.filter(func(e):return e.kind=="projectile")
	check(events.size()==1 and events[0].has("weapon_release") and events[0].clip=="Attack_staff_forward","one authoritative staff-tip event")
	var emitted: Dictionary=world.weapon_attacks.inspect(id)
	check(emitted.origin==Vector3(0,0,1.05) and emitted.aim==Vector3(0,0,4),"physics path and range unchanged")
	Case.advance(world,int(emitted.due)+1)
	check(world.enemy_health()==990 and world.weapon_attacks.is_empty(),"one actual host hit")
	Case.advance(world,int(emitted.due)+1);check(world.enemy_health()==990,"no replay damage")
	var before: int=world.combat_events.size()
	stats.spirit_replica=true
	world.weapon_attack_world.show_projectile(1,"staff",Vector3(5,0,0),Vector3(5,0,4),.2,stats,false,2)
	check(world.combat_events.size()==before+1 and not world.combat_events.back().has("weapon_release"),"phantom retains its own source, never real character tip")
	stats.erase("spirit_replica")
	Case.schedule(world,1,actor.pos,stats,now,"staff",450)
	actor[preload("res://player_lifecycle.gd").STATE]=preload("res://player_lifecycle.gd").start_life()
	Case.advance(world,now+2000)
	check(world.weapon_attacks.is_empty() and world.enemy_health()==990,"stale previous-life staff cannot release")
	world.free()
