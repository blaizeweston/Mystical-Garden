extends RefCounted
## Water, Wood and Vital art. The host's receipt supplies position, travel, radius and age.
const PROGRAM = preload("res://assets/shaders/shelter_affinities.gdshader")
const MOTES = preload("res://assets/terrain_m02/garden_motes.svg")
const CONTROLS := {
	"water.opacity":[.78,.15,1.,.01,"Water opacity","α"],
	"water.crest":[1.,.5,1.6,.05,"Crest height","×"],
	"wood.grain":[.7,0.,1.,.05,"Bark grain contrast","×"],
	"wood.thickness":[1.,.6,1.4,.05,"Bark and splinter girth","×"],
	"vital.petals":[1.,.55,1.5,.05,"Petal lift","×"],
	"vital.pollen":[.72,0.,1.,.02,"Pollen visibility","α"]
}
const LABELS := {"water":"Water currents","wood":"Ironbark and splinters","vital":"Vital Bloom"}
const STATUS := ["drenched","bark_armor","vitality"]
const TRAVEL := ["dewfall","riptide","riptide_return"]
const RINGS := ["tidal_ring","tidal_ring_return","water_wash"]
const RECEIPTS := ["dewfall","riptide","riptide_return","tidal_ring","tidal_ring_return","water_wash","ironbark","wood_burst","wood_splinters","wood_fragment","bark_contact","vital_bloom","vital_ward"]
const PREVIEWS := ["dewfall","riptide","riptide_return","drenched","ironbark","bark_armor","bark_contact","wood_fragment","vital_bloom","vitality","vital_heal"]
const TITLES := ["Dewfall curtain","Tidal Return · outbound","Tidal Return · restorative","Drenched · saturation","Ironbark formation","Bark Armor · worn","Bark absorption","Splinter · contact line","Vital Bloom","Vitality · active","Applied regeneration"]
enum { CREST, DROP, PLATE, CHIP, PETAL, POLLEN, RIPPLE, FIBRE }
static var meshes := {}
var vertices := PackedVector3Array()
var uv := PackedVector2Array()
var tags := PackedVector2Array()

static func family(kind:String) -> String:
	if kind in RINGS or kind in ["dewfall","riptide","riptide_return","drenched","water_heal"]:return "water"
	if kind in ["ironbark","bark_armor","bark_contact","wood_fragment","wood_burst","wood_spent","wood_splinters"]:return "wood"
	return "vital"

func face(points:Array, coords:Array, role:int, variation:float) -> void:
	for index:int in points.size():
		vertices.append(points[index])
		uv.append(coords[index])
		tags.append(Vector2(role,variation))

func strip(a:Vector3,b:Vector3,c:Vector3,d:Vector3, role:int, variation:float, u:float, v:float) -> void:
	face([a,b,c,a,c,d],[Vector2(u,0),Vector2(v,0),Vector2(v,1),Vector2(u,0),Vector2(v,1),Vector2(u,1)],role,variation)

func particle(center:Vector3, role:int, seed_value:float) -> void:
	strip(center,center,center,center,role,seed_value,0.,1.)

func leaf(base:Vector3, axis:Vector3, side:Vector3, ridge:Vector3, role:int, seed_value:float) -> void:
	var middle:=base+axis*.48
	var outline:=[base,middle-side*.84,base+axis,middle+side]
	var local_uv:=[Vector2(.46,0),Vector2(0,.45),Vector2(.58,1),Vector2(1,.52)]
	for i in 4:
		var j:=(i+1)%4
		face([outline[i],outline[j],middle+ridge],[local_uv[i],local_uv[j],Vector2(.48,.51)],role,seed_value)

func water(kind:String) -> void:
	if kind in RINGS:
		for i in 48:
			var a:=Vector3.RIGHT.rotated(Vector3.UP,TAU*i/48.)
			var b:=Vector3.RIGHT.rotated(Vector3.UP,TAU*(i+1)/48.)
			strip(a,b,b*.96+Vector3.UP*.042,a*.96+Vector3.UP*.042,RIPPLE,.4,i/48.,(i+1)/48.)
	elif kind in ["drenched","water_heal"]:
		for i in 8:
			var pos:=Vector3.RIGHT.rotated(Vector3.UP,i*2.4)*(.24+.12*sin(i))
			particle(pos+Vector3.UP*.62,DROP,(i+.5)/8.)
	else:
		for band in 3:
			for i in 24:
				var u:=i/24.
				var v:=(i+1)/24.
				var a:=wave_point(u,band)
				var b:=wave_point(v,band)
				# A translucent folded sheet beneath the lip. Secondary surfaces skim the wake.
				if band==0:
					strip(Vector3(a.x,.065,a.z+.13),Vector3(b.x,.065,b.z+.13),b+Vector3.UP*.12,a+Vector3.UP*.12,CREST,0.,u,v)
				else:
					var edge:=Vector3(0,.045,-.075)
					strip(a,b,b+edge,a+edge,CREST,band*.33,u,v)
		for i in 16:
			particle(wave_point((i+.5)/16.,0)+Vector3.UP*.12,DROP,(i+.5)/16.)

func wave_point(u:float,band:int) -> Vector3:
	var x:=2.*u-1.
	return Vector3(x,.11+(.46-.11*band)*(1.-x*x)+.068*sin(u*13.+band),.32*x*x+.11*band)

func timber(kind:String) -> void:
	var flash:=kind in ["wood_burst","wood_spent","wood_splinters","wood_fragment","bark_contact"]
	var count:=1 if kind=="wood_fragment" else 5 if kind=="wood_splinters" else 8 if flash else 6
	for i in count:
		var seed_value:=(i+.5)/count
		var angle:=seed_value*TAU+.21
		if kind=="wood_splinters":angle=lerpf(-.52,.52,seed_value)
		var outward:=Vector3.FORWARD.rotated(Vector3.UP,angle)
		var side:=outward.cross(Vector3.UP)
		if kind=="wood_fragment":
			leaf(Vector3(0,.54,.22),Vector3(.015,.08,-.23),Vector3.RIGHT*.061,Vector3.UP*.047,CHIP,seed_value)
			for j in 3:
				var a:=Vector3(.022*sin(j),.56,j*.32+.08)
				var b:=Vector3(.021*cos(j),.58,j*.32+.29)
				strip(a-Vector3.RIGHT*.024,b-Vector3.RIGHT*.009,b+Vector3.RIGHT*.009,a+Vector3.RIGHT*.024,FIBRE,j*.31,0.,1.)
		elif flash:
			leaf(outward*(.23 if kind=="bark_contact" else .10)+Vector3.UP*.40,outward*.32+Vector3.UP*(.12+.19*sin(i*8.)),side*.074,Vector3.UP*.045,CHIP,seed_value)
		else:
			var base:=outward*(.38+.035*sin(i*2.))+Vector3.UP*(.44+.09*sin(i*7.))
			leaf(base,Vector3.UP*(.53+.14*sin(i*4.))+side*.09,side*.14,outward*.09,PLATE,seed_value)

# A broad rounded lip and a raised midrib distinguish soft petals from Frost facets.
func petal(base:Vector3,radial:Vector3,length:float,lift:float,width:float,seed_value:float) -> void:
	var side:=radial.cross(Vector3.UP)
	var previous:PackedVector3Array=[]
	for j in 8:
		var t:=j/7.
		var arch:=sin(t*PI)
		var belly:=pow(maxf(0.,arch),.58)*(.55+.65*t)
		var center:=base+radial*length*t+Vector3.UP*(lift*t+.095*arch)
		var roll:=Vector3.UP*(belly*.074)
		var rim:=PackedVector3Array([center-side*width*belly+roll,center+Vector3.UP*.025*arch,center+side*width*belly+roll])
		if j>0:
			for lane in 2:
				var l:=lane*.5
				var r:=l+.5
				var before:=(j-1)/7.
				face([previous[lane],previous[lane+1],rim[lane+1],previous[lane],rim[lane+1],rim[lane]],
					[Vector2(l,before),Vector2(r,before),Vector2(r,t),Vector2(l,before),Vector2(r,t),Vector2(l,t)],PETAL,seed_value)
		previous=rim

func flowers(kind:String) -> void:
	var bloom:=kind in ["vital_bloom","vital_ward"]
	for i in (10 if bloom else 4):
		var seed_value:=(i+.5)/(10. if bloom else 4.)
		var radial:=Vector3.RIGHT.rotated(Vector3.UP,i*2.39996)
		if kind!="vital_heal":
			var base:=radial*(.10 if bloom else .23)+Vector3.UP*.10
			petal(base,radial,(.52+.20*cos(i*2.1)) if bloom else .115,(.25+.20*sin(i*3.5)) if bloom else .20,.15 if bloom else .065,seed_value)
		particle(radial*(.48 if bloom else .24)+Vector3.UP*(.20 if bloom else .37),POLLEN,seed_value)

func build(kind:String) -> ArrayMesh:
	match family(kind):
		"wood": timber(kind)
		"water": water(kind)
		_: flowers(kind)
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_TEX_UV2]=tags
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

static func create(parent:Node3D, kind:String, at:Vector3, reach:float, heading:Vector3, seed_value:int, settings:Dictionary, strength:=1.) -> MeshInstance3D:
	if not meshes.has(kind):meshes[kind]=new().build(kind)
	var node:=MeshInstance3D.new()
	parent.add_child(node)
	node.position=at
	if heading.length_squared()>.00001:node.rotation.y=atan2(-heading.x,-heading.z)
	node.mesh=meshes[kind]
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bound:=maxf(2.,reach+1.)
	node.custom_aabb=AABB(Vector3(-bound,-1.,-bound),Vector3(2.*bound,4.,2.*bound))
	var mat:=ShaderMaterial.new()
	mat.shader=PROGRAM
	node.material_override=mat
	node.set_meta("shelter_kind",kind)
	mat.set_shader_parameter("atlas",MOTES)
	mat.set_shader_parameter("extent",reach)
	mat.set_shader_parameter("seed_offset",fposmod(seed_value*.618,1.))
	mat.set_shader_parameter("persistent",kind in STATUS)
	mat.set_shader_parameter("gentle",kind in ["riptide_return","tidal_ring_return","water_heal"])
	mat.set_shader_parameter("worn",kind=="bark_armor")
	mat.set_shader_parameter("local_drops",kind in ["drenched","water_heal"])
	mat.set_shader_parameter("burst",kind in ["wood_spent","wood_burst"])
	mat.set_shader_parameter("expend",kind=="wood_spent")
	mat.set_shader_parameter("still_chip",kind=="wood_fragment")
	mat.set_shader_parameter("bloom",kind in ["vital_bloom","vital_ward"])
	mat.set_shader_parameter("strength",strength)
	configure(node,settings)
	return node

static func configure(node:MeshInstance3D, settings:Dictionary) -> void:
	for id:String in CONTROLS:
		if id.begins_with(family(str(node.get_meta("shelter_kind")))+"."):
			node.material_override.set_shader_parameter(id.replace(".","_"),settings.get(id,CONTROLS[id][0]))

static func seek(node:MeshInstance3D, age:float, duration:float) -> void:
	node.material_override.set_shader_parameter("elapsed",age)
	node.material_override.set_shader_parameter("phase",clampf(age/maxf(.001,duration),0.,1.))
