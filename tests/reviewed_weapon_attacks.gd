extends SceneTree
const Avatar := preload("res://traveller_avatar.gd")
const Weapons := preload("res://weapon_visuals.gd")
const Motion := preload("res://weapon_motion.gd")
const Field := preload("res://field_traveller.gd")
const Reviewed := preload("res://reviewed_weapon_attacks.gd")
const Snapshot := preload("res://world_snapshot.gd")
var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed=true
		printerr("FAIL reviewed weapons: ",message)

func _initialize() -> void: call_deferred("run")

func pose(actor: Dictionary, form: String, clip: String, phase: float, active: bool, step: int, delta := .016) -> void:
	var action := {"equipped":true,"clip":clip,"combo":step,"aim_yaw":0.0}
	Avatar.animate(actor,active,phase,form,action,delta)
	Weapons.animate(actor,form,phase,active,0,3.0,action)

func inspect(stage: Node3D, actor: Dictionary, body: int, form: String, class_id: int, weapon_id: int) -> void:
	var original_scale: Vector3=actor.model.scale
	if form=="fan":actor.model.scale.y=.92 if body==0 else 1.08
	var weapon := Weapons.build(stage,class_id,weapon_id)
	actor.visual_weapon=weapon
	weapon.reparent(actor.model,false)
	if form=="knives":
		actor.secondary_weapon=Weapons.build(stage,class_id,weapon_id)
		actor.secondary_weapon.reparent(actor.model,false)
	var rig: Skeleton3D=actor.field_rig.skeleton
	var contact := float(Motion.profile(form).release)
	var max_grip_error := 0.0
	var max_support_error := 0.0
	var max_release_error := 0.0
	var poses: Array[Quaternion]=[]
	for step in [1,2]:
		var clip: String=Motion.basic_variant(form,step).clip
		check(Snapshot.CLIPS.has(clip),"compact snapshot supports "+clip)
		pose(actor,form,clip,0,true,step)
		pose(actor,form,clip,0,false,step,.50)
		var ready := weapon.global_transform.orthonormalized()
		for frame in 51:
			var phase := frame/50.0
			pose(actor,form,clip,phase,true,step)
			check(actor.field_rig.player.current_animation==clip,"visible rig plays "+clip)
			if form!="ring" or phase<contact*.55:
				var grip: Vector3=weapon.to_global(weapon.get_meta("handle"))
				max_grip_error=maxf(max_grip_error,grip.distance_to(Field.hand(actor,form=="bow")))
			if form in ["crossbow","scythe"]:
				max_support_error=maxf(max_support_error,weapon.to_global(weapon.get_meta("support_grip")).distance_to(Field.hand(actor,true)))
			if form=="knives":
				max_support_error=maxf(max_support_error,actor.secondary_weapon.global_position.distance_to(Field.hand(actor,true)))
			if form=="bow" and phase>=contact*.85 and phase<contact:
				var nock: Vector3=weapon.get_node("NockedArrow").to_global(Vector3(0,.2,-.2))
				max_support_error=maxf(max_support_error,nock.distance_to(Field.hand(actor,false)))
			if frame==12: poses.append(rig.get_bone_pose_rotation(rig.find_bone("upperarm_r")))
		if form=="scythe":inspect_scythe_arc(actor,step,clip)
		pose(actor,form,clip,contact,true,step)
		if form=="fan":
			check(weapon.global_basis.get_scale().is_equal_approx(Vector3.ONE*.54),"Fan keeps its reviewed size on tall and short travellers")
			var points: Array=Reviewed.grips.fan.rim_points[clip]
			var last_x := -INF
			for index in 3:
				var rim := weapon.to_global(Reviewed.point(points[index],0))
				var offset := Reviewed.release_offset(body,clip,actor.model.scale.y,index)
				max_release_error=maxf(max_release_error,rim.distance_to(actor.model.get_parent_node_3d().global_position+offset))
				check(rim.z>.35 and rim.x>last_x,"three separate forward petal origins in volley order")
				last_x=rim.x
		elif Motion.is_projectile(form):
			var center := weapon.to_global(Vector3(0,.282,0)) if form=="ring" else weapon.to_global(Reviewed.sampled_point(actor.field_rig.reviewed,13))
			var offset := Reviewed.release_offset(body,clip,actor.model.scale.y)
			max_release_error=maxf(max_release_error,center.distance_to(actor.model.get_parent_node_3d().global_position+offset))
			if form=="bow":
				check(is_equal_approx(weapon.global_basis.x.length(),1.35),"approved enlarged bow scale")
				var mesh: MeshInstance3D=weapon.get_meta("flex_mesh")
				check(mesh.get_blend_shape_value(0)>.95,"bow limbs flex at full draw")
			if form in ["bow","crossbow"]:check(not weapon.get_node("NockedArrow").visible,"one projectile at release")
			if form=="ring":check(not weapon.visible,"held disc hands off at release")
		pose(actor,form,clip,1,true,step)
		pose(actor,form,clip,0,false,step,.005)
		check(actor.field_rig.player.current_animation==clip.replace("Attack_","Recover_"),"individual recovery")
		pose(actor,form,clip,0,false,step,.50)
		check(actor.field_rig.player.current_animation=="Ready_"+form+"_review","attack returns to ready")
		check(ready.basis.get_rotation_quaternion().angle_to(weapon.global_transform.orthonormalized().basis.get_rotation_quaternion())<.01,"ready orientation recovered")
		if form=="bow":check(weapon.get_node("NockedArrow").visible,"ready arrow is nocked")
	print("Body ",body," ",form," maximum distances (metres) grip=",max_grip_error," support=",max_support_error," release=",max_release_error)
	var tolerance := .022 if form=="knives" else .003
	check(max_grip_error<tolerance and max_support_error<tolerance,"props align with retargeted fingers on "+form)
	check(max_release_error<.006,"captured contact is near visible release on "+form)
	check(poses[0].angle_to(poses[1])>.025,"alternates have distinct upper-body poses: "+form)
	if form=="bow":
		var casting := {"equipped":true,"ability":true,"clip":"Cast"}
		Avatar.animate(actor,true,.4,form,casting,.016)
		Weapons.animate(actor,form,.4,true,0,3,casting)
		check(is_equal_approx(weapon.global_basis.x.length(),Reviewed.BOW_SCALE),"class actions keep the enlarged bow")
	actor.model.scale=original_scale
	weapon.free()
	actor.erase("visual_weapon")
	if actor.has("secondary_weapon"):
		actor.secondary_weapon.free()
		actor.erase("secondary_weapon")

func inspect_scythe_arc(actor: Dictionary, step: int, clip: String) -> void:
	var contact := float(Motion.profile("scythe").release)
	var variant := Motion.basic_variant("scythe",step)
	var start := 16 if step==1 else 17
	var weapon: Node3D=actor.visual_weapon
	var origin: Vector3=actor.model.global_position
	var previous := Vector3.ZERO
	var previous_tip := Vector3.ZERO
	var minimum := 180.0
	var maximum := -180.0
	for half_frame in range((start-1)*2,(start+8)*2+1):
		var time := half_frame/48.0
		var impact := 20/24.0
		var phase := contact*time/impact if time<=impact else contact+(1-contact)*(time-impact)/(30/24.0-impact)
		pose(actor,"scythe",clip,phase,true,step)
		var tip := weapon.get_node("WeaponTip") as Node3D
		var ray := tip.global_position-origin
		ray.y=0
		if not previous.is_zero_approx():
			check(previous.signed_angle_to(ray,Vector3.UP)*(1 if step==1 else -1)>0,"hook leads the "+clip+" sweep")
			var travel := previous_tip.direction_to(tip.global_position)
			check(absf(travel.dot(weapon.global_basis.z.normalized()))<.25,"cut follows the blade plane")
		previous=ray
		previous_tip=tip.global_position
		for blade_point in [tip.global_position,weapon.to_global(Vector3(0,1.20,0)),weapon.to_global(Vector3(.492,1.10,0))]:
			var point: Vector3=blade_point-origin
			var angle := atan2(point.x,point.z)
			minimum=minf(minimum,rad_to_deg(angle))
			maximum=maxf(maximum,rad_to_deg(angle))
			check(absf(angle-float(variant.yaw_offset))<=float(variant.span)*.5,"cutting blade inside indicated "+clip+" sector")
	print(clip," cutting arc degrees ",minimum," to ",maximum)
	var line := preload("res://weapon_contact.gd").describe("scythe",{"pattern":"line","reach":3,"weapon_variant":clip})
	check(line.clip=="Attack_scythe_line" and line.pattern=="line" and is_zero_approx(float(line.yaw_offset)),"crafted line remains straight")

func run() -> void:
	var stage := preload("res://stage.gd").new()
	for form in ["bow","crossbow","ring","fan"]:
		for variant: Dictionary in Motion.profile(form).basic_variants:
			check(Reviewed.release_offset(1,variant.clip,1).is_finite(),"release before the remote rig loads")
	check(not Reviewed.release_offset(1,"unknown",1).is_finite(),"unknown clip has no release")
	var pivot := Node3D.new()
	root.add_child(pivot)
	var actor := Avatar.build(pivot)
	for body in 2:
		Avatar.swap(actor,body)
		actor.model.rotation.y=0
		for index in Reviewed.FORMS.size():
			var form: String=Reviewed.FORMS[index]
			inspect(stage,actor,body,form,2 if index<3 else 4 if form in ["bell","censer","fan"] else 3,index if index<3 else int({"knives":0,"scythe":1,"whip":2,"bell":0,"censer":1,"fan":2}[form]))
	stage.free()
	pivot.free()
	await process_frame
	if not failed: print("PASS: both travellers play the reviewed attacks, grips, releases and ready recoveries")
	quit(1 if failed else 0)
