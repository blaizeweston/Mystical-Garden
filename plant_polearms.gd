extends RefCounted

const Motion := preload("res://weapon_motion.gd")
const SCALE := .9
# All models have a rear grip at the origin and a forward grip on local +Y.
const WEAPONS := {
	"spear": {
		"scene": preload("res://assets/weapons/briar_spear.glb"),
		"name": "BriarSpearModel", "support": .31,
		"tip": Vector3(.051,1.67,0),
		"stance": Vector3(-.27,-.23,.12),
		"pitch": Vector4(PI*.5,PI*.5+.02,PI*.5-.03,PI*.5), "extension": .30,
		"support_slide": .15,
	},
	"hammer": {
		"scene": preload("res://assets/weapons/heartwood_maul.glb"),
		"name": "HeartwoodMaulModel", "support": .26,
		"tip": Vector3(0,1.11,0),
		"stance": Vector3(-.14,-.27,.19),
		"pitch": Vector4(.33,-.57,1.63,1.96), "extension": .13,
	},
	"scythe": {
		"scene": preload("res://assets/weapons/harvest_scythe.glb"),
		"name": "HarvestScytheModel", "support": .24,
		"tip": Vector3(.765,.90,0),
		"stance": Vector3(-.22,-.25,.26),
		"pitch": Vector4(.57,.93,1.40,1.70), "extension": .02, "visual_arc_scale": .2,
	},
}


static func support_distance(form: String, phase: float, active: bool, action: Dictionary) -> float:
	var definition: Dictionary=WEAPONS[form]
	var distance := float(definition.support)
	if form=="spear" and active and action.get("delivery",Motion.profile(form).delivery)=="line":
		var contact := float(Motion.profile(form).release)
		var thrust := smoothstep(contact*.44,contact,phase)*(1.0-smoothstep(contact,.94,phase))
		distance-=float(definition.support_slide)*thrust
	return distance


static func orientation(form: String, phase: float, active: bool, yaw: float, action: Dictionary) -> Basis:
	var definition: Dictionary = WEAPONS[form]
	var pitches: Vector4 = definition.pitch
	if not active:
		return Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitches.x)
	var profile := Motion.profile(form)
	var contact := float(profile.release)
	var sector: bool = action.get("delivery",profile.delivery) in ["sweep","sector"]
	var arc := float(action.get("span",profile.span))*float(definition.get("visual_arc_scale",.45)) if sector else .08
	var start := Vector2(0,pitches.x)
	var windup := Vector2(-arc,pitches.y)
	var impact := Vector2(0,pitches.z)
	var follow := Vector2(arc,pitches.w)
	var ready_at := contact*.52
	var follow_at := contact+(1.0-contact)*.46
	var pose: Vector2
	if phase < ready_at:
		pose = start.lerp(windup,smoothstep(0,ready_at,phase))
	elif phase < contact:
		pose = windup.lerp(impact,smoothstep(ready_at,contact,phase))
	elif phase < follow_at:
		pose = impact.lerp(follow,smoothstep(contact,follow_at,phase))
	else:
		pose = follow.lerp(start,smoothstep(follow_at,1,phase))
	return Basis(Vector3.UP,yaw+pose.x)*Basis(Vector3.RIGHT,pose.y)


static func grip_target(form: String, phase: float, active: bool, yaw: float) -> Vector3:
	var definition: Dictionary = WEAPONS[form]
	var stance: Vector3 = definition.stance
	if active:
		var contact := float(Motion.profile(form).release)
		var windup := smoothstep(0,contact*.45,phase)*(1.0-smoothstep(contact*.45,contact,phase))
		var strike := smoothstep(contact*.44,contact,phase)*(1.0-smoothstep(contact,.94,phase))
		stance.z += float(definition.extension)*strike-.11*windup
		stance.y += .15*windup-.05*strike
	return Basis(Vector3.UP,yaw)*stance
