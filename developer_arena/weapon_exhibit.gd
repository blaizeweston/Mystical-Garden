extends Node3D
## The private viewport poses the same rig, props and ribbons as the live stage.
const Avatar = preload("res://traveller_avatar.gd")
const Weapons = preload("res://weapon_visuals.gd")
const Motion = preload("res://weapon_motion.gd")
const Trail = preload("res://weapon_motion_trail.gd")
const Delivery = preload("res://weapon_delivery_visuals.gd")
const Classes = preload("res://class_catalog.gd")
const FPS := 120.
var actor := {}
var form := ""
var action := {}
var profile := {}
var values := {}
var duration := 0.
var last_frame := -1
var reference: Node
var flight := {}

func build(stage: Node, class_id: int, weapon_id: int, variant: int, settings: Dictionary) -> void:
	reference=stage.get_node("CombatEffects")
	values=settings
	var weapon: Dictionary=Classes.DEFINITIONS[class_id].weapons[weapon_id]
	form=weapon.visual
	profile=Motion.profile(form)
	duration=profile.duration
	action=Motion.basic_variant(form,variant+1)
	action.merge({"equipped":true,"aim_yaw":0.,"combo":variant+1,"contact":profile.release,"delivery":profile.delivery,"reach":weapon.reach})
	actor=Avatar.build(self)
	# The factory is used only to assemble meshes. No world or practice round starts.
	var factory:=preload("res://stage.gd").new()
	actor.visual_weapon=Weapons.build(factory,class_id,weapon_id)
	actor.visual_weapon.reparent(actor.model,false)
	if form=="knives":
		actor.secondary_weapon=Weapons.build(factory,class_id,weapon_id)
		actor.secondary_weapon.reparent(actor.model,false)
	if Motion.is_projectile(form):
		var event:={"form":form,"shape":profile.shape,"clip":action.clip,"projectile_radius":profile.projectile_radius,"duration":3./float(profile.speed),
			"weapon_release":{"position":[0,0,0],"body":0,"height":1.,"yaw":0.}}
		var release:=factory.weapon_release_point(event)-factory.WILD_OFFSET
		var glyph:=MeshInstance3D.new()
		glyph.mesh=ImmediateMesh.new()
		glyph.material_override=reference.material(Color("#e7dbb8"),0.)
		glyph.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(glyph)
		event.color=Color("#e7dbb8")
		flight={"root":glyph,"mesh":glyph,"event":event,"visual_from":release}
		reference.mount_projectile_glyph(flight,event)
	factory.free()

func pose_frame(frame: int) -> void:
	var elapsed:=frame/FPS
	var phase:=clampf(elapsed/duration,0.,1.)
	var active:=phase<1.
	Avatar.animate(actor,active,phase,form,action,1./FPS)
	Weapons.animate(actor,form,phase,active,0.,action.reach,action)
	Trail.sample_actor(actor,form,phase,active,action,1./FPS,values)

func seek(seconds: float) -> void:
	var target:=roundi(seconds*FPS)
	if target<last_frame:
		for name in ["visual_weapon","secondary_weapon"]:
			if actor.has(name) and actor[name].has_node("MotionTrail"): actor[name].get_node("MotionTrail").erase_history()
		last_frame=-1
	for frame in range(last_frame+1,target+1): pose_frame(frame)
	last_frame=target
	if flight.is_empty(): return
	var t: float=(seconds-duration*float(profile.release))*float(profile.speed)/3.
	flight.mesh.visible=t>=0. and t<1.
	if not flight.mesh.visible: return
	var strip: ImmediateMesh=flight.mesh.mesh
	strip.clear_surfaces()
	strip.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var start: Vector3=flight.visual_from-Vector3.UP*float(profile.height)
	flight.event.height=profile.height
	Delivery.projectile(reference,strip,flight,start,start+Vector3.BACK*3.,t,values.get("projectile.tail",Delivery.CONTROLS["projectile.tail"][0]))
	strip.surface_end()
