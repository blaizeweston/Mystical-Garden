extends SceneTree
## Reviewed wand poses plus actual queued host projectiles. Disposable saves only.
const Avatar=preload("res://traveller_avatar.gd")
const Field=preload("res://field_traveller.gd")
const Weapons=preload("res://weapon_visuals.gd")
const Wand=preload("res://wand_animation.gd")
const Motion=preload("res://weapon_motion.gd")
const Actions=preload("res://player_weapon_actions.gd")
const Native=preload("res://traveller_weapon_animation.gd")
const Codec=preload("res://world_snapshot.gd")
const Case=preload("res://tests/support/weapon_attack_case.gd")
const Expedition=preload("res://tests/support/expedition_case.gd")
const Terrain=preload("res://tests/support/terrain_case.gd")
var failed:=false

func check(ok: bool,message: String) -> void:
	if not ok:failed=true;printerr("FAIL wand attacks: ",message)
func _initialize() -> void:call_deferred("run")

func draw(actor: Dictionary,active: bool,phase: float,clip: String,sequence: int,delta: float) -> void:
	var motion:={"equipped":true,"aim_yaw":0.0,"contact":.32,"combo":sequence,"clip":clip}
	Avatar.animate(actor,active,phase,"wand",motion,delta)
	Weapons.animate(actor,"wand",phase,active,0,3.3,motion)

func event(body: int,height: float,clip: String,sequence: int) -> Dictionary:
	return {"id":1,"kind":"projectile","shape":"needle","form":"wand","from":[0,0,.7],"to":[0,0,3.3],"duration":.15,"color":"#b9dca4","reach":3.3,"projectile_radius":.065,"height":1.25,"owner":1,"combo":sequence,"clip":clip,
		"weapon_release":{"position":[0,0,0],"yaw":0.0,"body":body,"height":height}}

func run() -> void:
	check(Motion.profile("wand").duration==.28 and Motion.profile("wand").release==.32,"unchanged 280 ms pose and 32% release")
	check(Codec.PLAYER_BYTES==137 and Codec.SCOUT_BYTES==21,"protocol-41 layout unchanged")
	var state:=Actions.State.new().try_start(1000,480,280,3.3,"wand")
	check(Motion.basic_variant("wand",state.basic_step()).clip=="Attack_wand_forward","first admitted cast")
	check(state.try_start(1000,480,280,3.3,"wand")==null,"refused duplicate does not advance alternation")
	var saved:=state
	state=state.core_pose(1480,300,3.3,Vector3.BACK,"Attack_wand","projectile",0,false)
	state=state.try_start(1780,480,280,3.3,"wand")
	check(Motion.basic_variant("wand",state.basic_step()).clip=="Attack_wand_sweep" and state.ready_at_ms()==2260,"Core preserves alternation and native cadence")
	check(saved.basic_step()==1 and saved.ready_at_ms()==1480,"action savepoint is unchanged by later admission")
	for body in 2:
		for height in [.92,1.0,1.08]:inspect_body(body,height)
	await inspect_combat()
	if not failed:print("PASS: approved wand casts on both bodies/heights, 15-degree outward sweep and shared finish, straight wrist/grip, locomotion, returns, actual-tip release, duplicate/stale rejection and original host damage/timing")
	quit(1 if failed else 0)

func inspect_body(body: int,height: float) -> void:
	var parent:=Node3D.new();root.add_child(parent);parent.position=Vector3(80,0,0)
	var stage:=preload("res://stage.gd").new()
	var actor:=Avatar.build(parent);Avatar.swap(actor,body)
	var reference:=Avatar.build(parent);Avatar.swap(reference,body)
	actor.model.scale.y=height;reference.model.scale.y=height
	actor.model.rotation.y=0;reference.model.rotation.y=0
	actor.visual_weapon=Weapons.build(stage,1,1);actor.visual_weapon.reparent(actor.model,false)
	var rig: Skeleton3D=actor.field_rig.skeleton
	var lower: Skeleton3D=reference.field_rig.skeleton
	var grip_error:=0.0;var lower_error:=0.0;var cache_error:=0.0;var wrist_error:=0.0;var min_index_dot:=1.0
	var starts: Array[Transform3D]=[];var finishes: Array[Transform3D]=[]
	for clip in ["Attack_wand_forward","Attack_wand_sweep"]:
		check(Codec.CLIPS.has(clip),"host clip has a snapshot ID")
		for speed in [0.0,3.5]:
			actor.speed=speed;actor.pace=1.0 if speed>0 else 0.0;reference.speed=speed;reference.pace=actor.pace
			for frame in 30:draw(actor,false,0,clip,0,1.0/120);Avatar.animate(reference,false,0,"",{},1.0/120)
			for step in 101:
				var phase:=step/100.0
				actor.gait_travel=speed/120;actor.gait_vector=Vector3.BACK*speed/120
				reference.gait_travel=actor.gait_travel;reference.gait_vector=actor.gait_vector
				draw(actor,true,phase,clip,1,1.0/120);Avatar.animate(reference,false,0,"",{},1.0/120)
				var weapon: Node3D=actor.visual_weapon
				grip_error=maxf(grip_error,weapon.to_global(weapon.get_meta("handle")).distance_to(Field.hand(actor,false)))
				for bone in rig.get_bone_count():
					check(rig.get_bone_global_pose(bone).is_finite(),"finite imported pose")
					if not Native.upper_body(rig.get_bone_name(bone)):lower_error=maxf(lower_error,(rig.get_bone_pose_rotation(bone)-lower.get_bone_pose_rotation(bone)).length())
				lower_error=maxf(lower_error,rig.get_bone_pose_position(actor.field_rig.pelvis).distance_to(lower.get_bone_pose_position(reference.field_rig.pelvis)))
				var wrist:=rig.get_bone_global_pose(rig.find_bone("hand_r")).origin
				var elbow:=rig.get_bone_global_pose(rig.find_bone("lowerarm_r")).origin
				var middle:=rig.get_bone_global_pose(rig.find_bone("middle_01_r")).origin
				wrist_error=maxf(wrist_error,(wrist-elbow).normalized().angle_to((middle-wrist).normalized()))
				var index:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("index_01_r")).origin)
				var pinky:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("pinky_01_r")).origin)
				min_index_dot=minf(min_index_dot,(index-pinky).normalized().dot(weapon.global_basis.y.normalized()))
				if speed==0 and step==32:
					var tip: Vector3=weapon.get_node("WeaponTip").global_position
					cache_error=maxf(cache_error,Wand.release_offset(body,clip,height).distance_to(tip-stage.WILD_OFFSET))
					stage.avatar_models[1]=actor;actor.motion_key="weapon:1"
					var release:=event(body,height,clip,1)
					check(stage.weapon_release_point(release).distance_to(tip)<.0001,"matching cast releases at actual wand tip")
					var fx:=preload("res://combat_effects.gd").new();fx.stage=stage;root.add_child(fx)
					fx.sync([release],[],"wand",Vector3.ZERO)
					var frozen: Vector3=fx.active[1].visual_from
					check(frozen.distance_to(tip-stage.WILD_OFFSET)<.0001,"bolt starts at raised wand tip")
					actor.model.position.x+=2;fx.pose(fx.active[1]);fx.sync([release],[],"wand",Vector3.ZERO)
					check(fx.active.size()==1 and fx.active[1].visual_from==frozen,"duplicate event cannot follow/restart bolt")
					actor.model.position.x-=2;fx.clear();fx.free()
			for frame in 30:draw(actor,false,0,clip,1,1.0/120);Avatar.animate(reference,false,0,"",{},1.0/120)
			check(actor.field_rig.player.current_animation=="Ready_wand_authored","return reaches raised ready")
		# Compare actual imported geometry at source frame 12 and the common end.
		# Use the same idle frame: different walking phases legitimately move the
		# shoulder origin even when both imported upper-body finish poses match.
		for item: Dictionary in [actor,reference]:
			item.speed=0.0;item.pace=0.0;item.gait_travel=0.0;item.gait_vector=Vector3.ZERO;item.idle_time=0.0
		draw(actor,true,.32*11.0/17.0,clip,1,4.0/24.0)
		Avatar.animate(reference,false,0,"",{},4.0/24.0)
		starts.append(actor.visual_weapon.global_transform)
		actor.idle_time=0.0;reference.idle_time=0.0
		draw(actor,true,1,clip,1,4.0/24.0)
		Avatar.animate(reference,false,0,"",{},4.0/24.0)
		var relative_finish: Transform3D=actor.visual_weapon.global_transform
		relative_finish.origin-=rig.to_global(rig.get_bone_global_pose(actor.field_rig.pelvis).origin)
		finishes.append(relative_finish)
	var sweep:=rad_to_deg(starts[0].basis.get_rotation_quaternion().angle_to(starts[1].basis.get_rotation_quaternion()))
	print("WAND FINISH ",body," height=",height," position_delta_m=",finishes[0].origin.distance_to(finishes[1].origin)," angle_delta_deg=",rad_to_deg(finishes[0].basis.get_rotation_quaternion().angle_to(finishes[1].basis.get_rotation_quaternion())))
	check(absf(sweep-15)<.1,"actual imported sweep starts 15 degrees outward")
	check(finishes[0].origin.distance_to(finishes[1].origin)<.001 and finishes[0].basis.get_rotation_quaternion().angle_to(finishes[1].basis.get_rotation_quaternion())<.001,"both casts share exact finish")
	print("WAND BODY ",body," height=",height," grip_error_m=",grip_error," lower_error=",lower_error," cached_tip_error_m=",cache_error," wrist_deg=",rad_to_deg(wrist_error)," index_tip_dot=",min_index_dot," sweep_deg=",sweep)
	check(grip_error<.002 and lower_error<.00001,"fixed grip and unchanged lower-body locomotion")
	check(wrist_error<deg_to_rad(8) and min_index_dot>.9,"straight wrist and thumb/index side toward tip")
	check(cache_error<.03,"late source projection stays near actual tip on this body/height")
	stage.avatar_models.clear()
	var delayed:=event(body,height,"Attack_wand_sweep",3)
	check((stage.weapon_release_point(delayed)-stage.WILD_OFFSET).distance_to(Wand.release_offset(body,"Attack_wand_sweep",height))<.0001,"delayed event resolves without actor")
	var bad:=delayed.duplicate(true);bad.weapon_release.position=[0,INF,0]
	check(not stage.weapon_release_point(bad).is_finite(),"invalid release facts fail closed")
	draw(actor,true,.99,"Attack_wand_forward",8,.01);draw(actor,false,0,"Attack_wand_forward",8,.04)
	draw(actor,true,.2,"Attack_wand_sweep",9,.01)
	check(actor.field_rig.player.current_animation=="Attack_wand_sweep","new cast interrupts return")
	Avatar.animate(actor,true,.3,"wand",{"ability":true,"clip":"Attack_wand"},.01)
	check(not actor.field_rig.wand_active and not actor.field_rig.wand.has("last_clip"),"Core/class clears cosmetic return")
	parent.free();stage.free()

func inspect_combat() -> void:
	var world: Node=load("res://world.tscn").instantiate()
	var path:="user://wand-"+str(OS.get_process_id())
	world.progress.path=path+".garden";world.local_character.path=path+".character";world.guest_character.path=path+".guest"
	root.add_child(world);world.set_process(false);world.set_physics_process(false)
	var actor: Dictionary=world.players[1]
	Expedition.set_membership(world,actor,true)
	actor.frame=1;actor.weapon_kind=1;actor.weapon=0;actor.secondary=0;actor.catalyst=0
	actor.pos=Vector3.ZERO;actor.facing=Vector3.BACK;actor.mouse_aim=true;actor.aim_direction=Vector3.BACK
	actor[Actions.STATE]=Actions.State.new()
	Terrain.walls(world.battlefield,[]);world.encounter.clear_scouts();world.encounter.set_hp(-1,1000);world.tactics.position=Vector3(0,0,3)
	var now:=preload("res://combat_clock.gd").now()
	var stats:={"damage":1.0,"reach":3.3,"targets":1,"pattern":"single","weapon_variant":"Attack_wand_forward"}
	var id:=Case.schedule(world,1,actor.pos,stats,now,"wand",280)
	var shot: Dictionary=world.weapon_attacks.inspect(id)
	Case.advance(world,int(shot.release)-1);check(world.enemy_health()==1000,"no damage before original release")
	Case.advance(world,int(shot.release))
	var events: Array=world.combat_events.filter(func(e):return e.kind=="projectile")
	check(events.size()==1 and events[0].has("weapon_release") and events[0].clip=="Attack_wand_forward","one authoritative wand-tip event")
	var emitted: Dictionary=world.weapon_attacks.inspect(id)
	check(emitted.origin==Vector3(0,0,.7) and emitted.aim==Vector3(0,0,3.3),"physical path and range unchanged")
	Case.advance(world,int(emitted.due)+1)
	check(world.enemy_health()==990 and world.weapon_attacks.is_empty(),"one host contact with unchanged damage")
	Case.advance(world,int(emitted.due)+1);check(world.enemy_health()==990,"no duplicate damage")
	stats.spirit_replica=true
	world.weapon_attack_world.show_projectile(1,"wand",Vector3(5,0,0),Vector3(5,0,3),.2,stats,false,2)
	check(not world.combat_events.back().has("weapon_release"),"replica keeps its virtual origin")
	stats.erase("spirit_replica")
	Case.schedule(world,1,actor.pos,stats,now,"wand",280)
	actor[preload("res://player_lifecycle.gd").STATE]=preload("res://player_lifecycle.gd").start_life()
	Case.advance(world,now+2000)
	check(world.weapon_attacks.is_empty() and world.enemy_health()==990,"previous life cannot release delayed wand attack")
	world.free()
