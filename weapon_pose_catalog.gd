extends RefCounted
## Presentation only. Angles are degrees; hand offsets are metres from shoulders.
## Combat timing/reach/damage remain in weapon_actions.json and their existing owners.
const Motion = preload("res://weapon_motion.gd")
const Polearms = preload("res://plant_polearms.gd")
const DEFINITIONS := {
	"blade": {"carry_pitch":22.0,"mesh_roll":90.0,"relaxed":true,"hand_bound":true,"clips":["Attack_rootblade_forehand","Attack_rootblade_backhand"],"recoveries":["Recover_rootblade_left","Recover_rootblade_right"],"impact":21.0/47.0,"separate_recovery":true,"recovery_seconds":0.18},
	"knives": {"carry_pitch":24.0,"mesh_roll":90.0,"relaxed":true,"clips":["Sword_Regular_B","Sword_Regular_A"],"recoveries":["Sword_Regular_B_Rec","Sword_Regular_A_Rec"],"impact":0.85},
	"spear": {"carry_pitch":90.0,"mesh_roll":0.0,"clips":["Attack_spear","Attack_spear_sweep"]},
	"hammer": {"carry_pitch":19.0,"mesh_roll":90.0,"clips":["Attack_maul_overhead","Attack_maul_sweep"],"recoveries":["Recover_maul_overhead","Recover_maul_sweep"]},
	"scythe": {"carry_pitch":33.0,"mesh_roll":-90.0,"relaxed":true,"procedural_stance":true,"carry_twist":0.0,"windup_twist":-60.0,"strike_twist":-35.0,"strike_lean":4.0,"clips":[]},
	"staff": {"carry_pitch":24.0,"mesh_roll":0.0,"clips":["Attack_staff_forward","Attack_staff_side"],"recoveries":["Recover_staff_forward","Recover_staff_side"],"separate_recovery":true,"impact":0.55},
	"wand": {"carry_pitch":25.0,"mesh_roll":0.0,"relaxed":true,"hand_bound":true,"clips":["Attack_wand_forward","Attack_wand_sweep"],"recoveries":["Recover_wand_forward","Recover_wand_sweep"],"separate_recovery":true,"impact":17.0/39.0},
	"orb": {"carry_pitch":0.0,"mesh_roll":0.0,"clips":["Attack_focus_push","Attack_focus_gather"],"recoveries":["Recover_focus_push","Recover_focus_gather"],"separate_recovery":true,"impact":0.48},
	"bow": {"carry_pitch":8.0,"mesh_roll":0.0,"relaxed":true,"procedural_stance":true,"carry_twist":0.0,"strike_twist":-55.0,"clips":[]},
	"crossbow": {"carry_pitch":8.0,"mesh_roll":0.0,"clips":[]},
	"ring": {"carry_pitch":160.0,"mesh_roll":-20.0,"relaxed":true,"clips":["OverhandThrow"],"impact":0.60},
	"whip": {"carry_pitch":20.0,"mesh_roll":0.0,"relaxed":true,"clips":["Melee_Hook"],"recoveries":["Melee_Hook_Rec"],"impact":0.9},
	"bell": {"carry_pitch":-10.0,"mesh_roll":0.0,"relaxed":true,"clips":["Spell_Simple_Shoot"],"impact":0.55},
	"censer": {"carry_pitch":-12.0,"mesh_roll":0.0,"relaxed":true,"clips":["Melee_Hook"],"recoveries":["Melee_Hook_Rec"],"impact":0.85},
	"fan": {"carry_pitch":12.0,"mesh_roll":90.0,"relaxed":true,"clips":["Melee_Hook"],"recoveries":["Melee_Hook_Rec"],"impact":0.85},
}
const CARRY_RIGHT := Vector3(-0.23,-0.36,0.24)
const CARRY_LEFT := Vector3(0.23,-0.36,0.24)
const BOW_DRAW := Vector3(-0.18,-0.08,0.62)
const UTILITY_WINDUP := Vector3(-0.38,-0.34,0.28)
const UTILITY_CONTACT := Vector3(-0.10,-0.16,0.57)
const UTILITY_FOLLOW := Vector3(-0.18,-0.27,0.50)

static func envelope(phase: float) -> float:
	return smoothstep(0.0,0.16,phase)*(1.0-smoothstep(0.78,1.0,phase))

static func relaxed_carry(form: String) -> bool:
	return bool(DEFINITIONS.get(form,{}).get("relaxed",false))

static func procedural_stance(form: String) -> bool:
	return bool(DEFINITIONS.get(form,{}).get("procedural_stance",false))

static func body_pose(form: String, phase: float, active: bool) -> Vector2:
	var definition: Dictionary=DEFINITIONS.get(form,{})
	var carry := float(definition.get("carry_twist",0.0))
	var amount := pulse(form,phase,active)
	var twist := lerpf(carry,float(definition.get("strike_twist",carry)),amount)
	if active and definition.has("windup_twist"):
		var contact := float(Motion.profile(form).release)
		var ready := contact*.45
		if phase<ready:twist=lerpf(carry,float(definition.windup_twist),smoothstep(0.0,ready,phase))
		elif phase<contact:twist=lerpf(float(definition.windup_twist),float(definition.strike_twist),smoothstep(ready,contact,phase))
		else:twist=lerpf(float(definition.strike_twist),carry,smoothstep(contact,1.0,phase))
	return Vector2(deg_to_rad(twist),deg_to_rad(float(definition.get("strike_lean",0.0))*amount))

static func pulse(form: String, phase: float, active: bool) -> float:
	if not active: return 0.0
	var contact := float(Motion.profile(form).release)
	return smoothstep(0.0,contact,phase)*(1.0-smoothstep(contact,1.0,phase))

static func hand_offset(form: String, phase: float, active: bool, combo: int) -> Vector3:
	if not active: return CARRY_RIGHT
	var contact := float(Motion.profile(form).release)
	var first := contact*0.45
	var follow := contact+(1.0-contact)*0.48
	var target: Vector3
	if phase<first: target=CARRY_RIGHT.lerp(UTILITY_WINDUP,smoothstep(0.0,first,phase))
	elif phase<contact: target=UTILITY_WINDUP.lerp(UTILITY_CONTACT,smoothstep(first,contact,phase))
	elif phase<follow: target=UTILITY_CONTACT.lerp(UTILITY_FOLLOW,smoothstep(contact,follow,phase))
	else: target=UTILITY_FOLLOW.lerp(CARRY_RIGHT,smoothstep(follow,1.0,phase))
	if form in ["fan","censer"]:
		var direction := 1.0 if combo%2==0 else -1.0
		target.x += direction*0.22*sin(phase*PI)*sin((phase-contact)*PI)
	return target

static func orientation(form: String, phase: float, active: bool, yaw: float, action: Dictionary, offhand := false) -> Basis:
	var definition: Dictionary = DEFINITIONS.get(form,DEFINITIONS.blade)
	var roll := deg_to_rad(float(definition.mesh_roll))*(-1.0 if offhand else 1.0)
	if Polearms.WEAPONS.has(form):
		return Polearms.orientation(form,phase,active,yaw,action)*Basis(Vector3.UP,roll)
	var amount := pulse(form,phase,active)
	var pitch := deg_to_rad(float(definition.carry_pitch))
	var turn := 0.0
	var contact := float(Motion.profile(form).release)
	var direction := -1.0 if int(action.get("combo",0))%2 else 1.0
	if form in ["blade","knives"]:
		pitch=lerpf(pitch,PI*0.50,amount)
		if active and action.get("delivery",Motion.profile(form).delivery) in ["sweep","sector"]:
			turn=direction*lerpf(-0.8,0.8,clampf(phase/(contact*1.8),0,1))*envelope(phase)
	elif form in ["staff","wand"]: pitch=lerpf(pitch,PI*0.5,amount)
	elif form=="ring": pitch=lerpf(pitch,PI*0.5,amount)
	elif form=="whip":
		pitch=lerpf(pitch,0.0,amount)
		if active and action.get("delivery",Motion.profile(form).delivery)=="sweep":
			var span := float(action.get("span",Motion.profile(form).span))
			turn=lerpf(-span*.5,span*.5,clampf(phase/(contact*2.0),0,1))*envelope(phase)
	elif form in ["bell","censer"]: pitch-=deg_to_rad(68.0 if form=="bell" else 76.0)*amount
	elif form=="fan": turn=direction*lerpf(-0.55,0.65,clampf(phase/(contact*1.8),0,1))*envelope(phase) if active else 0.0
	elif form in ["bow","crossbow"]: pitch=lerpf(pitch,0.0,amount)
	return Basis(Vector3.UP,yaw+turn)*Basis(Vector3.RIGHT,pitch)*Basis(Vector3.UP,roll)
