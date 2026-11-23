extends SceneTree
const Avatar = preload("res://traveller_avatar.gd")
const Weapons = preload("res://weapon_visuals.gd")
const Focus = preload("res://seed_focus_animation.gd")
const Actions = preload("res://player_weapon_actions.gd")
const Motion = preload("res://weapon_motion.gd")
var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL Seed Focus: ", message)

func _initialize() -> void:
	call_deferred("run")

func draw(actor: Dictionary, clip: String, phase: float, active: bool, step: int, dt := .016) -> void:
	var action := {"equipped":true, "clip":clip, "combo":step, "aim_yaw":0.0}
	actor.motion_key = "weapon:"+str(step)
	Avatar.animate(actor, active, phase, "orb", action, dt)
	Weapons.animate(actor, "orb", phase, active, 0, 3.4, action)

func inspect(body: int, height: float) -> void:
	var stage := preload("res://stage.gd").new()
	var pivot := Node3D.new()
	root.add_child(pivot)
	pivot.position = stage.WILD_OFFSET
	var actor := Avatar.build(pivot)
	Avatar.swap(actor,body)
	actor.model.rotation.y = 0
	actor.model.scale.y = height
	actor.visual_weapon = Weapons.build(stage, 1, 2)
	actor.visual_weapon.reparent(actor.model,false)
	var rig: Skeleton3D = actor.field_rig.skeleton
	var seed: Node3D = actor.visual_weapon
	var handle: Vector3 = seed.get_meta("handle")
	var ready := Vector3.ZERO
	var gathers: Array[Vector3] = []
	var max_palm_error := 0.0
	var max_late_error := 0.0
	for step in [1,2]:
		var clip: String = Motion.basic_variant("orb",step).clip
		for i in 20: draw(actor,clip,0,false,step)
		ready = seed.to_global(handle)
		for frame in 101:
			var phase := frame/100.0
			draw(actor,clip,phase,true,step)
			var center := seed.to_global(handle)
			var palms := Vector3.ZERO
			for side in ["l","r"]:
				palms += rig.to_global(rig.get_bone_global_pose(rig.find_bone("middle_01_"+side)).origin)*.5
			max_palm_error = maxf(max_palm_error,center.distance_to(palms))
			check(center.distance_to(rig.to_global(rig.get_bone_global_pose(actor.field_rig.pelvis).origin))>.3,"seed clear of the pelvis")
			if frame==32: gathers.append(center)
			if frame==48:
				check(actor.field_rig.player.current_animation==clip,"visible field rig plays selected clip")
				check(center.z > ready.z+.13,"hands cast the seed forwards")
				var event := {"id":step,"kind":"projectile","shape":"orb","form":"orb","owner":1,"combo":step,"clip":clip,
					"from":[0,0,.50],"to":[0,0,3.4],"height":1.365,"duration":.16,"color":"#ccd98d",
					"reach":3.4,"projectile_radius":.18,"weapon_release":{"position":[0,0,0],"height":height,"body":body,"yaw":0.0}}
				stage.avatar_models[1]=actor
				var fx := preload("res://combat_effects.gd").new()
				fx.stage=stage
				root.add_child(fx)
				fx.sync([event],[],"focus",Vector3.ZERO)
				check(fx.active[step].glyph.global_position.distance_to(center)<.001,"flying seed starts at the actual held seed center")
				var flying_seed: Node3D=fx.active[step].glyph.get_child(0)
				check(is_equal_approx(flying_seed.scale.x,preload("res://plant_polearms.gd").SCALE),"seed retains its held size on release")
				var frozen: Vector3=fx.active[step].visual_from
				pivot.position.x+=2.0
				check(stage.weapon_release_point(event).distance_to(center)<.015,"late packet cannot launch from a moved caster")
				pivot.position.x-=2.0
				stage.avatar_models.clear()
				var late := stage.weapon_release_point(event)
				max_late_error=maxf(max_late_error,center.distance_to(late))
				fx.sync([event],[],"focus",Vector3.ZERO)
				check(fx.active.size()==1 and fx.active[step].visual_from==frozen,"duplicate release is frozen")
				fx.clear()
				fx.free()
			if frame in [49,61]:
				check(not seed.visible,"only the flying seed is visible after release")
		draw(actor,clip,0,false,step)
		check(actor.field_rig.player.current_animation==("Recover_focus_push" if step==1 else "Recover_focus_gather"),"individual return plays")
		for i in 30: draw(actor,clip,0,false,step)
		check(actor.field_rig.player.current_animation=="Ready_focus" and seed.visible,"seed reforms and returns to ready")
	print("FOCUS body=",body," height=",height," palm error=",max_palm_error," late origin error=",max_late_error," windup separation=",gathers[0].distance_to(gathers[1]))
	check(max_palm_error<.145,"seed remains within its radius of the palm midpoint")
	check(max_late_error<.015,"late launch stays close to the actual model's release")
	check(gathers.size()==2 and gathers[0].x-gathers[1].x>.07,"second cast visibly gathers to the side")
	pivot.free()
	stage.free()

func run() -> void:
	var state := Actions.State.new()
	for step in [1,2,3]:
		var now: int=1000*step
		state=state.try_start(now,950,520,3.4,"orb")
		check(Motion.basic_variant("orb",state.basic_step()).clip==(Focus.GATHER if step==2 else Focus.PUSH),"alternation wraps through the admitted basic sequence")
		check(state.try_start(now,950,520,3.4,"orb")==null,"duplicate start refused")
	for body in 2:
		for height in [.92,1.0,1.08]: inspect(body,height)
	if not failed:print("PASS: Seed Focus two casts, palm launches, held/flying handoff, returns and duplicate rejection on both bodies")
	quit(1 if failed else 0)
