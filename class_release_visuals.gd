extends RefCounted
## Each release uses the cast's resolved center, end, radius and angle. No targeting runs here.
const SHADER = preload("res://assets/shaders/class_release.gdshader")
const Strips = preload("res://astral_visuals.gd")
const CONTROLS := {
	"class.ink":[.84,.25,1.,.01,"Class stroke opacity","α"],
	"class.relief":[1.,.4,1.55,.05,"Class stroke thickness","×"]
}
const PREVIEWS := ["quake","nova","salvo","grave","ward"]
const TITLES := ["Warden · Root Quake","Weaver · Spore Nova","Ranger · Hunter’s Salvo","Reaper · Grave Sweep","Oracle · Warding Chime"]
const NATIVE := ["quake","nova","guard","front_guard","counter_guard","snare","siphon","ward"]
const FOCUS := ["bloom","snare","salvo","grave","harvest","bell","sanctuary","omen"]
# Shader families. Related casts share the mesh and retain their individual delivery.
const FORMS := {"quake":0,"front_guard":1,"counter_guard":1,"guard":1,"nova":2,"bloom":2,
	"snare":3,"salvo":4,"grave":5,"harvest":5,"siphon":6,"ward":7,"bell":7,"omen":8,"sanctuary":9}
static var mesh: ArrayMesh

static func accepts(event:Dictionary) -> bool:
	return (event.kind=="ability" and event.shape in NATIVE) or (event.kind=="subclass_release" and event.shape in FOCUS)

static func create(parent:Node3D,kind:String,start:Vector3,end:Vector3,radius:float,options:Dictionary,values:Dictionary) -> MeshInstance3D:
	if mesh==null:
		var tool:=SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		Strips.strips(tool,0,9,20)
		mesh=tool.commit()
	var glyph:=MeshInstance3D.new()
	glyph.mesh=mesh
	glyph.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat:=ShaderMaterial.new()
	mat.shader=SHADER
	glyph.material_override=mat
	glyph.set_meta("class_release",kind)
	var path:=end-start
	var from_start:=kind in ["salvo","grave","harvest","guard","counter_guard","front_guard"]
	glyph.position=start if from_start else end
	var limit:=Vector3.ONE*(maxf(radius,1.)+1.4)
	glyph.custom_aabb=AABB(-limit+Vector3.ZERO.min(path),limit*2.+path.abs())
	mat.set_shader_parameter("style",FORMS[kind])
	mat.set_shader_parameter("path",path)
	mat.set_shader_parameter("radius",radius)
	mat.set_shader_parameter("lane_width",float(options.get("width",0.)))
	mat.set_shader_parameter("angle",float(options.get("yaw_offset",atan2(path.z,path.x))))
	mat.set_shader_parameter("span",TAU if kind=="harvest" else float(options.get("span",2.35)))
	mat.set_shader_parameter("variation",kind in ["front_guard","bloom","bell","harvest"])
	mat.set_shader_parameter("braced",kind=="counter_guard")
	parent.add_child(glyph)
	configure(glyph,values)
	return glyph

static func configure(glyph:MeshInstance3D,values:Dictionary) -> void:
	for id:String in CONTROLS:
		glyph.material_override.set_shader_parameter(id.replace(".","_"),values.get(id,CONTROLS[id][0]))

static func seek(glyph:MeshInstance3D,elapsed:float,duration:float) -> void:
	glyph.material_override.set_shader_parameter("phase",clampf(elapsed/maxf(.001,duration),0.,1.))
