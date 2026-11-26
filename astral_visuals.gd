extends RefCounted
## Cosmetic strips share one mesh per silhouette. Endpoints and field radii come from the host.
const SHADER = preload("res://assets/shaders/astral_currents.gdshader")
const SKIN = preload("res://assets/shaders/spectral_skin.gdshader")
const Avatar = preload("res://traveller_avatar.gd")
const Weapons = preload("res://weapon_visuals.gd")
const Motion = preload("res://weapon_motion.gd")
const Classes = preload("res://class_catalog.gd")
const CONTROLS := {
	"storm.width":[1.,.45,1.7,.05,"Filament width","×"],
	"storm.kink":[1.,.2,1.6,.05,"Discharge irregularity","×"],
	"spirit.veil":[.49,.15,.80,.01,"Spectral silhouette opacity","α"],
	"spirit.wisp":[.72,.15,1.,.01,"Wisp visibility","α"],
	"void.flow":[1.,.4,1.8,.05,"Inward dust speed","×"],
	"void.shade":[.48,.1,.7,.01,"Gravitational core darkness","α"]
}
const LABELS := {"storm":"Electrical discharge","spirit":"Spectral manifestations","void":"Gravitational currents"}
const PREVIEWS := ["storm_arc","spirit_step","mirrorstep","wraithcast_shadow","gravity_well","singularity","rift_shear","mirrorstep_attack","void_collapse"]
const TITLES := ["Chain Spark · resolved jump","Phantom Step · path","Mirrorstep · weapon echo","Wraithcast · anchored shadow","Gravity Well · gathering","Singularity · gathering","Rift Shear · confirmed contact","Mirrorstep · captured weapon release","Gravity Well · collapse"]
const RECEIPTS := ["storm_arc","storm_burst","spirit_step","spirit_trace","spirit_follow","mirrorstep_attack","wraithcast","void_pulse","void_collapse","rift_shear","void_grip"]
const BODIES := ["mirrorstep","mirrorstep_attack","wraithcast_shadow","wraithcast"]
enum {BOLT, SPARK, SILK, ANCHOR, ORBIT, EDGE, CORE, SHEAR}
static var templates := {}

static func family(kind:String) -> String:
	if kind.begins_with("storm"):return "storm"
	if kind in BODIES or kind.begins_with("spirit"):return "spirit"
	return "void"

static func strips(tool:SurfaceTool, role:int, count:int, segments:int) -> void:
	for lane in count:
		for section in segments:
			for corner:Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var u:=(section+corner.x)/segments
				tool.set_uv(Vector2(u,corner.y))
				tool.set_uv2(Vector2(role,lane))
				tool.add_vertex(Vector3(u,corner.y,0))

static func template(kind:String) -> ArrayMesh:
	if templates.has(kind):return templates[kind]
	var tool:=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"storm_arc":
			strips(tool,BOLT,3,16)
			strips(tool,SPARK,5,2)
		"rift_shear","void_grip":
			strips(tool,SHEAR,3 if kind=="rift_shear" else 2,16)
		"storm_burst":
			strips(tool,SPARK,11,6)
		"spirit_step","spirit_follow","spirit_stride":
			strips(tool,SILK,5,16)
		"mirrorstep","mirrorstep_attack","spirit_trace":
			strips(tool,SILK,3,16)
		"wraithcast_shadow","wraithcast":
			strips(tool,ANCHOR,5,18)
			if kind=="wraithcast":strips(tool,SILK,2,12)
		_:
			strips(tool,ORBIT,10 if kind=="singularity" else 7,22)
			strips(tool,CORE,2,32)
			if kind in ["gravity_well","singularity"]:strips(tool,EDGE,5,18)
	templates[kind]=tool.commit()
	return templates[kind]

static func create(parent:Node3D,kind:String,at:Vector3,path:Vector3,radius:float,seed_value:int,values:Dictionary,style:="",body:Dictionary={}) -> MeshInstance3D:
	var glyph:=MeshInstance3D.new()
	glyph.mesh=template(kind)
	glyph.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat:=ShaderMaterial.new()
	mat.shader=SHADER
	glyph.material_override=mat
	glyph.set_meta("astral_kind",kind)
	var bounds:=maxf(radius,.8)+1.8
	glyph.custom_aabb=AABB(Vector3.ZERO.min(path)-Vector3.ONE*bounds,path.abs()+Vector3.ONE*bounds*2.)
	parent.add_child(glyph)
	glyph.position=at
	mat.set_shader_parameter("path",path)
	mat.set_shader_parameter("extent",maxf(.05,radius))
	mat.set_shader_parameter("seed_offset",posmod(seed_value,997)*.131)
	mat.set_shader_parameter("event_weight",.54 if style in ["form","catalyst","fork"] else .78 if style=="return" else 1.)
	mat.set_shader_parameter("returning",style=="return")
	mat.set_shader_parameter("collapse",kind=="void_collapse")
	mat.set_shader_parameter("outward",style=="repulsion")
	mat.set_shader_parameter("standing",kind in ["mirrorstep","mirrorstep_attack","spirit_trace"] or (kind=="wraithcast" and path.length_squared()<.001))
	mat.set_shader_parameter("burst",kind=="storm_burst")
	mat.set_shader_parameter("singularity",kind=="singularity" or style=="singularity")
	if kind in BODIES and not body.is_empty():mount_body(glyph,kind,body.duplicate(true))
	configure(glyph,values)
	return glyph

static func configure(glyph:MeshInstance3D,values:Dictionary) -> void:
	var group:=family(glyph.get_meta("astral_kind"))
	for id:String in CONTROLS:
		if id.get_slice(".",0)==group:
			glyph.material_override.set_shader_parameter(id.replace(".","_"),values.get(id,CONTROLS[id][0]))
	if glyph.has_meta("spectral_body"):
		glyph.get_meta("spectral_body").skin.set_shader_parameter("opacity",values.get("spirit.veil",CONTROLS["spirit.veil"][0]))

static func mount_body(glyph:MeshInstance3D,kind:String,body:Dictionary,skin:ShaderMaterial=null) -> void:
	var appearance:=preload("res://character_appearance.gd").normalize(body.get("appearance",[]))
	var actor:=Avatar.build(glyph,appearance[5])
	var class_id:=clampi(int(body.get("frame",0)),0,Classes.DEFINITIONS.size()-1)
	var weapon_id:=clampi(int(body.get("weapon_kind",0)),0,Classes.DEFINITIONS[class_id].weapons.size()-1)
	preload("res://character_appearance.gd").apply(actor,appearance,false)
	var form:String=Classes.DEFINITIONS[class_id].weapons[weapon_id].visual
	actor.visual_weapon=Weapons.build(actor.model,class_id,weapon_id)
	if form=="knives":
		actor.secondary_weapon=Weapons.build(actor.model,class_id,weapon_id)
	var yaw:=float(body.get("yaw",0.))
	actor.model.rotation.y=yaw
	var action:=Motion.variant_by_clip(form,body.get("clip","")).duplicate()
	if action.is_empty():action=Motion.basic_variant(form,1)
	action.merge({"equipped":true,"aim_yaw":yaw,"contact":Motion.profile(form).release,"delivery":Motion.profile(form).delivery,"reach":float(body.get("reach",Classes.DEFINITIONS[class_id].weapons[weapon_id].reach))})
	var casting:=kind=="wraithcast"
	if casting:action.ability=true
	if skin==null:
		skin=ShaderMaterial.new()
		skin.shader=SKIN
		skin.set_shader_parameter("anchored",kind in ["wraithcast_shadow","wraithcast"])
		skin.set_shader_parameter("ground_y",glyph.global_position.y)
	for piece:MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
		piece.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if piece.name=="MotionTrail" or piece.mesh==null:continue
		if piece.material_override!=null:
			piece.material_override=skin
		else:
			for surface in piece.mesh.get_surface_count():piece.set_surface_override_material(surface,skin)
	glyph.set_meta("spectral_body",{"actor":actor,"source":body,"skin":skin,"form":form,"action":action,"yaw":yaw,"attack":kind=="mirrorstep_attack","last_frame":-1,"release":casting or kind=="mirrorstep_attack"})
	# The image appears in a settled ready pose, including on its first rendered frame.
	Avatar.animate(actor,false,0.,form,action,.45)
	Weapons.animate(actor,form,0.,false,yaw,action.reach,action)

static func seek(glyph:MeshInstance3D,elapsed:float,lifetime:float) -> void:
	var phase:=clampf(elapsed/maxf(.001,lifetime),0.,1.)
	glyph.material_override.set_shader_parameter("seconds",elapsed)
	glyph.material_override.set_shader_parameter("phase",phase)
	if glyph.has_meta("spectral_body"):
		var b:Dictionary=glyph.get_meta("spectral_body")
		b.skin.set_shader_parameter("veil",smoothstep(0.,.07,elapsed)*smoothstep(0.,.18,lifetime-elapsed))
		if b.release:
			var frame:=floori(elapsed*60.)
			if frame<b.last_frame:
				# Rewind the attachment, pose player and ribbon together; forward samples reuse this rig.
				b.actor.model.free()
				mount_body(glyph,glyph.get_meta("astral_kind"),b.source,b.skin)
				b=glyph.get_meta("spectral_body")
			for index in range(int(b.last_frame)+1,frame+1):
				var pose:=clampf(index/(60.*lifetime),0.,1.)
				Avatar.animate(b.actor,true,pose,b.form,b.action,1./60.)
				Weapons.animate(b.actor,b.form,pose,true,b.yaw,b.action.reach,b.action)
				if b.attack:
					preload("res://weapon_motion_trail.gd").sample_actor(b.actor,b.form,pose,true,b.action,1./60.,{"trail.opacity":.38})
			b.last_frame=frame
