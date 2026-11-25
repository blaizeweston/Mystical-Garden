extends MeshInstance3D
## Samples the mounted prop *after* its reviewed pose. World-space samples never feed combat.
const Motion = preload("res://weapon_motion.gd")
const FORMS := ["blade","spear","hammer","scythe","knives","whip"]
const CONTROLS = preload("res://weapon_delivery_visuals.gd").CONTROLS
const PROGRAM = preload("res://assets/shaders/weapon_edge.gdshader")
const MAX_SAMPLES := 24
static var shared_material: ShaderMaterial
var tips: Array[Vector3] = []
var edges: Array[Vector3] = []
var times: Array[float] = []
var clock := 0.0
var sequence := -1
var last_phase := 0.0
var was_running := false

static func attach_to(prop: Node3D) -> void:
	var trail := new()
	trail.name="MotionTrail"
	trail.top_level=true
	trail.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.mesh=ImmediateMesh.new()
	if shared_material==null:
		shared_material=ShaderMaterial.new()
		shared_material.shader=PROGRAM
	trail.material_override=shared_material
	trail.hide()
	prop.add_child(trail)

static func sample_actor(actor: Dictionary, form: String, phase: float, running: bool, action: Dictionary, delta: float, values: Dictionary) -> void:
	if form not in FORMS: return
	var left := str(action.get("clip","")).ends_with("_left")
	var primary: Node3D=actor.visual_weapon
	var trail=primary.get_node("MotionTrail")
	trail.sample(primary,form,phase,running and not left,action,delta,values)
	if form=="knives" and actor.has("secondary_weapon"):
		var secondary: Node3D=actor.secondary_weapon
		secondary.get_node("MotionTrail").sample(secondary,form,phase,running and left,action,delta,values)

func erase_history() -> void:
	if times.is_empty(): return
	tips.clear()
	edges.clear()
	times.clear()
	(mesh as ImmediateMesh).clear_surfaces()
	hide()

func sample(prop: Node3D, form: String, phase: float, running: bool, action: Dictionary, delta: float, values: Dictionary) -> void:
	var combo:=int(action.get("combo",0))
	var contact:=float(action.get("contact",Motion.profile(form).release))
	var cut_short:=was_running and not running and last_phase<contact+.15
	if cut_short or action.get("interrupt",false) or delta>.22 or sequence!=combo or (running and phase<last_phase-.03):
		erase_history()
	sequence=combo
	last_phase=phase
	was_running=running
	if action.get("interrupt",false): return
	clock+=delta
	var life:=float(values.get("trail.fade",CONTROLS["trail.fade"][0]))
	if form=="knives": life*=.66
	var drawing:=running and phase>=contact-.23 and phase<=contact+.19
	if times.is_empty() and not drawing: return
	while not times.is_empty() and times[0]<clock-life:
		times.pop_front()
		edges.pop_front()
		tips.pop_front()
	if drawing and (times.is_empty() or clock-times.back()>=1./120.-.00001):
		var tip: Vector3
		if form=="whip":
			var last: Node3D=prop.get_meta("vine_segments").back()
			tip=last.to_global(Vector3.UP*.5)
		else:
			tip=prop.get_node("WeaponTip").global_position
		var edge:=prop.to_global(prop.get_meta("handle",Vector3.ZERO))
		var width:=float(values.get("trail.width",CONTROLS["trail.width"][0]))
		edge=tip.move_toward(edge,minf(edge.distance_to(tip)*.42,(.34 if form in ["scythe","hammer","blade"] else .19)*width))
		if (form=="spear" and action.get("delivery","line")=="line") or form=="whip":
			edge=tip+prop.global_basis.x.normalized()*.06*width
		if not tips.is_empty() and tip.distance_squared_to(tips.back())>2.25: erase_history()
		if tips.is_empty() or tip.distance_squared_to(tips.back())>.00006:
			tips.append(tip)
			edges.append(edge)
			times.append(clock)
			if times.size()>MAX_SAMPLES:
				tips.pop_front()
				edges.pop_front()
				times.pop_front()
	var strip:=mesh as ImmediateMesh
	strip.clear_surfaces()
	visible=times.size()>=2
	if not visible: return
	# Identity basis with a nearby origin keeps the culling bounds local.
	global_transform=Transform3D(Basis.IDENTITY,tips.back())
	strip.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var opacity:=float(values.get("trail.opacity",CONTROLS["trail.opacity"][0]))
	for i in times.size():
		var strength:=clampf(1.-(clock-times[i])/life,0,1)*opacity
		strip.surface_set_color(Color(1,1,1,strength))
		strip.surface_set_uv(Vector2(0.,0.))
		strip.surface_add_vertex(edges[i]-global_position)
		strip.surface_set_uv(Vector2(0.,1.))
		strip.surface_add_vertex(tips[i]-global_position)
	strip.surface_end()
