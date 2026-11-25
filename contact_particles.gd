extends RefCounted
## Analytically animated, target-local geometry. One draw per burst, no particle nodes.
const PROGRAM = preload("res://assets/shaders/contact_fragments.gdshader")
const Motion = preload("res://weapon_motion.gd")
const DEFAULTS := {
	"impact.count": 6, "impact.size": 1.0, "impact.speed": 3.8, "impact.lifetime": 0.19,
	"impact.flash": 0.32, "impact.hue": 39.0,
	"rupture.count": 9, "rupture.size": 1.0, "rupture.speed": 3.0, "rupture.lifetime": 0.34,
	"rupture.flash": 0.70, "rupture.hue": 195.0, "rupture.repeat_labels": 0,
}
static var meshes := {}

static func kind(event: Dictionary) -> String:
	if event.kind == "ability" and event.shape == "frost_rupture":
		return "rupture"
	if event.kind == "impact" and event.shape == "hit" and event.get("amount",0) > 0 and Motion.PROFILES.has(event.get("form","")):
		return "impact"
	return ""

static func geometry(frost: bool, count: int) -> ArrayMesh:
	var key := Vector2i(int(frost),count)
	if meshes.has(key):
		return meshes[key]
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var tags := PackedVector2Array()
	var glints := 3
	var dust := 4 if frost else 0
	for index in count + glints + dust:
		var role := int(frost) if index < count else (2 if index < count + glints else 3)
		# An asymmetric two-ended splinter with three flat facets on either side.
		var rim := [Vector3(-0.15,1,0), Vector3(-0.35,-0.6,0.82), Vector3(-0.3,-0.5,-0.78)]
		for side in 3:
			var edge: Vector3 = rim[side]
			var next: Vector3 = rim[(side+1)%3]
			for vertex: Vector3 in [Vector3(1,0,0),edge,next,Vector3(-0.65,0,0),next,edge]:
				vertices.append(vertex)
				tags.append(Vector2(index,role))
				var shade := [0.60,0.85,1.0][side] as float
				colors.append(Color(shade,shade,shade))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=tags
	arrays[Mesh.ARRAY_COLOR]=colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.custom_aabb=AABB(Vector3(-5,-5,-5),Vector3(10,10,10))
	meshes[key]=mesh
	return mesh

static func create(parent: Node3D, family: String, at: Vector3, incoming: Vector3, form: String,
		sequence: int, values: Dictionary, emission: float, surface_known := false) -> Dictionary:
	var frost := family == "rupture"
	var prefix := family + "."
	var count := int(values.get(prefix+"count",DEFAULTS[prefix+"count"]))
	var material := ShaderMaterial.new()
	material.shader=PROGRAM
	var life := float(values.get(prefix+"lifetime",DEFAULTS[prefix+"lifetime"]))
	material.set_shader_parameter("lifetime",life)
	material.set_shader_parameter("fragment_count",float(count))
	material.set_shader_parameter("speed",values.get(prefix+"speed",DEFAULTS[prefix+"speed"]))
	material.set_shader_parameter("size_scale",values.get(prefix+"size",DEFAULTS[prefix+"size"]))
	material.set_shader_parameter("flash_strength",values.get(prefix+"flash",DEFAULTS[prefix+"flash"]))
	material.set_shader_parameter("sequence",posmod(sequence,251))
	var direction := Vector3(incoming.x,0,incoming.z).normalized()
	var spread := 1.45 if Motion.is_projectile(form) else 2.65
	if not frost:
		# Heavy wood sheds broader flecks. Points and light alternating cuts
		# produce a narrow recoil without another flash or damage event.
		var shape: Vector2={"hammer":Vector2(.90,1.40),"knives":Vector2(.67,.68),"spear":Vector2(1.12,.72),"bow":Vector2(.92,.65),"crossbow":Vector2(.81,1.07),"whip":Vector2(.82,.72)}.get(form,Vector2.ONE)
		material.set_shader_parameter("splinter_shape",shape)
		if form in ["spear","knives"]: spread=1.65
	if direction.is_zero_approx():
		direction=Vector3.RIGHT
		spread=TAU
	material.set_shader_parameter("spread",spread)
	material.set_shader_parameter("energy",0.65 if frost else emission)
	var hue := float(values.get(prefix+"hue",DEFAULTS[prefix+"hue"]))
	material.set_shader_parameter("tint",Color.from_hsv(hue/360.0,0.46 if frost else 0.62,0.97))
	var glyph := MeshInstance3D.new()
	glyph.mesh=geometry(frost,count)
	glyph.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glyph.material_override=material
	parent.add_child(glyph)
	glyph.position=at + Vector3.UP * (0.98 if frost else 0.83)
	if not frost and not surface_known and not incoming.is_zero_approx():
		# Show the first contact at the near surface of the body before the flecks travel on.
		glyph.position-=direction*0.24
	glyph.rotation.y=-atan2(direction.z,direction.x)
	return {"root":glyph,"mesh":glyph,"material":material,"family":family,"life":life,"age":0.0}

static func pose(burst: Dictionary, age: float) -> void:
	burst.material.set_shader_parameter("elapsed",age)
