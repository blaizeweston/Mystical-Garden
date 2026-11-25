extends RefCounted
## Local cosmetic batches. Geometry is shared by silhouette, with one playback clock per instance.
const PROGRAM = preload("res://assets/shaders/affinity_growth.gdshader")
const MASKS = preload("res://assets/shaders/affinity_masks.svg")
const CONTROLS := {
	"fire.height":[1.,.45,1.65,.05,"Flame height","×"],
	"fire.flicker":[1.,.35,2.,.05,"Flame motion","×"],
	"fire.smoke":[.23,0.,.6,.01,"Smoke opacity","α"],
	"fire.embers":[1.,.4,1.8,.05,"Ember lift speed","×"],
	"frost.petals":[1.,.55,1.5,.05,"Crystal petal height","×"],
	"frost.mist":[.45,0.,1.,.05,"Suspended frost opacity","α"],
	"thorn.bark":[1.,.55,1.75,.05,"Bramble girth","×"],
	"thorn.spines":[1.,.55,1.65,.05,"Thorn height","×"],
	"affinity.status":[.84,0.,1.,.02,"Target markings","α"]
}
const LABELS := {"fire":"Ember Wake","frost":"Rime Bloom","thorn":"Thorn growth","affinity":"Affinity status"}
const OPEN_SECONDS := preload("res://frost_balance.gd").BLOOM_DELAY_MS / 1000.
const PHASES := ["fire","thorn","patch","open","close","burning","brittle","bleeding","mist","flashover","wildfire","hemorrhagic_rupture"]
const STATUS := ["burning","brittle","bleeding"]
const BARK := 0
const FLAME := 1
const SMOKE := 2
const EMBER := 3
const ICE := 4
const MIST := 5
const SPINE := 6
const SAP := 7
const RIM := 8
static var shapes := {}
var vertices := PackedVector3Array()
var tags := PackedVector2Array()
var uv := PackedVector2Array()
var colors := PackedColorArray()

func triangle(a:Vector3,b:Vector3,c:Vector3, role:int, variation:float, tint:Color) -> void:
	for point in [a,b,c]:
		vertices.append(point)
		tags.append(Vector2(role,variation))
		uv.append(Vector2.ZERO)
		colors.append(tint)

func mote(center:Vector3, role:int, variation:float, tint:Color) -> void:
	for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(1,0)]:
		vertices.append(center)
		uv.append(corner)
		tags.append(Vector2(role,variation))
		colors.append(tint)

func stem(a:Vector3,b:Vector3,width:float,taper:float,shade:Color) -> void:
	var side := (b-a).cross(Vector3.UP).normalized()
	var arch := Vector3.UP*.72
	for pair in [[side,arch],[arch,-side],[-side,side]]:
		var left:Vector3=pair[0]
		var right:Vector3=pair[1]
		var tint:=shade.darkened(.22 if left==arch else 0.)
		triangle(a+left*width,b+left*taper,b+right*taper,BARK,0.,tint)
		triangle(a+left*width,b+right*taper,a+right*width,BARK,0.,tint)
		var start:=uv.size()-6
		var centers:=[a,b,b,a,b,a]
		for corner in 6:
			var offset:Vector3=vertices[start+corner]-centers[corner]
			uv[start+corner]=Vector2(offset.x,offset.z)

func roots(patch:bool, fire:bool) -> void:
	var leaf_color:=Color("#9d8756")
	var bark:=Color("#50352e") if fire else Color("#536239")
	for strand in (6 if patch else 3):
		var angle:=strand*TAU/6.+.32
		var ray:=Vector3(cos(angle),0,sin(angle))
		var side:=ray.cross(Vector3.UP)
		var last:=Vector3.ZERO
		for i in 15:
			var u:=i/14.
			var wave:=sin(u*10.+strand*3.4)+.36*sin(u*21.-strand)
			var p:=ray*(.92*u)+side*.13*wave*u if patch else Vector3(2.*u-1.,0,(strand-1.)*.38+wave*.17)
			p.y=.065+.095*absf(sin(i*.51+strand*2.6))
			if i>0:
				var weight:=.046 if fire else .061
				stem(last,p,weight*(1.-.48*u),weight*(.96-.49*u),bark)
				if i%2==1:
					var branch:Vector3=(side if patch else Vector3.BACK)*(1. if (i+strand)%4<2 else -1.)
					var joint:=p+branch*(.10 if patch else .15)+Vector3.UP*.10
					var bend:=(p-last).normalized()
					var tip:=joint+branch*.10+Vector3.UP*(.12 if fire else .21+.08*sin(strand+i))+bend*.12
					stem(p,joint,.043,.027,bark)
					if not fire and i%4==1:
						var mid:=joint+branch*.12+bend*.065
						triangle(joint,mid+bend*.055,mid+branch*.13+Vector3.UP*.065,SPINE,u,Color("#738346"))
					triangle(joint-Vector3.RIGHT*.048,joint+Vector3.RIGHT*.048,tip,SPINE,u,bark if fire else leaf_color)
					triangle(joint+Vector3.BACK*.056,joint-Vector3.BACK*.056,tip,SPINE,u,bark.darkened(.16))
			last=p

func petals(kind:String) -> void:
	if kind!="brittle":
		# Short icy seams mark the admitted radius through the gaps in the petals.
		for sector in 11:
			for cut in 3:
				var start:=TAU*(sector+(cut+.25)*.19)/11.
				var end:=start+TAU*.19/11.
				var a:=Vector3(cos(start),.055,sin(start))
				var b:=Vector3(cos(end),.055,sin(end))
				var shade:=Color("#a6cbd0")
				triangle(a,b,b*.982,RIM,0.,shade)
				triangle(a,b*.982,a*.982,RIM,0.,shade)
	var count:=2 if kind=="brittle" else 11
	for i in count:
		var angle:=i*2.39996+.4
		var ray:=Vector3(cos(angle),0,sin(angle))
		var side:=ray.cross(Vector3.UP)
		var long:=.65+.31*fposmod(i*.618+.71,1.)
		var base:=ray*.11+Vector3.UP*.12
		var ridge:=ray*long*.56+Vector3.UP*.52
		var left:=ray*long*.60+side*.095+Vector3.UP*.30
		var right:=ray*long*.57-side*.075+Vector3.UP*.29
		var tip:=ray*long+Vector3.UP*(.33+.24*fposmod(i*.31,1.))
		var index:=float(i)
		triangle(base,left,ridge,ICE,index,Color("#598a9f"))
		triangle(base,ridge,right,ICE,index,Color("#b3d9db"))
		triangle(left,tip,ridge,ICE,index,Color("#aed5df"))
		triangle(right,ridge,tip,ICE,index,Color("#c9e1e3"))

func build(kind:String) -> ArrayMesh:
	var rng:=RandomNumberGenerator.new()
	rng.seed=72431 # Private composition seed, independent of combat and terrain.
	if kind in ["fire","thorn","patch"]: roots(kind=="patch",kind=="fire")
	if kind in ["open","close","brittle"]: petals(kind)
	var roles:Array={
		"fire":[[FLAME,25],[EMBER,19],[SMOKE,8]],"burning":[[FLAME,3],[EMBER,4]],
		"flashover":[[FLAME,5],[EMBER,8]],"wildfire":[[EMBER,9]],"hemorrhagic_rupture":[[SAP,7]],
		"bleeding":[[SAP,5]],"open":[[MIST,9]],"close":[[MIST,9]],"mist":[[MIST,7]]
	}.get(kind,[])
	for group in roles:
		for i in int(group[1]):
			var p:=Vector3(rng.randf_range(-.95,.95),.10,rng.randf_range(-.72,.72))
			if kind!="fire":
				var r:=sqrt(rng.randf())*(.46 if kind=="mist" else .8)
				p=Vector3(cos(i*2.4)*r,rng.randf_range(.10,.47),sin(i*2.4)*r)
			if kind in STATUS:
				var radial:=.78+.18*rng.randf()
				p.x=cos(i*2.4)*radial
				p.z=sin(i*2.4)*radial
			mote(p,group[0],rng.randf(),Color.WHITE)
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_TEX_UV2]=tags
	arrays[Mesh.ARRAY_COLOR]=colors
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

static func create(parent:Node3D,kind:String,at:Vector3,extent:Vector2,angle:float,seed_value:int,settings:Dictionary,stacks:=1) -> MeshInstance3D:
	if not shapes.has(kind): shapes[kind]=new().build(kind)
	var node:=MeshInstance3D.new()
	node.name="Affinity_"+kind
	node.mesh=shapes[kind]
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=ShaderMaterial.new()
	material.shader=PROGRAM
	material.set_shader_parameter("masks",MASKS)
	material.set_shader_parameter("effect",PHASES.find(kind))
	material.set_shader_parameter("extent",extent)
	material.set_shader_parameter("variation",posmod(seed_value,127)*.013)
	material.set_shader_parameter("stacks",clampi(stacks,1,2))
	node.material_override=material
	configure(node,settings)
	parent.add_child(node)
	node.position=at
	node.rotation.y=angle
	# Cover shader displacement even on thin lanes or terrain-clipped ends.
	node.custom_aabb=AABB(Vector3(-extent.x-1,-.6,-extent.y-1),Vector3(2.*extent.x+2,3.6,2.*extent.y+2))
	return node

static func configure(node:MeshInstance3D,settings:Dictionary) -> void:
	for key:String in CONTROLS:
		node.material_override.set_shader_parameter(key.replace(".","_"),settings.get(key,CONTROLS[key][0]))

static func seek(node:MeshInstance3D,age:float,remaining:float) -> void:
	node.material_override.set_shader_parameter("elapsed",maxf(age,0.))
	node.material_override.set_shader_parameter("remaining",maxf(remaining,0.))

static func field(parent:Node3D,skill:String,shape:Dictionary,seed_value:int,settings:Dictionary) -> MeshInstance3D:
	if shape.kind=="area":
		var center:=Vector3(shape.at[0],shape.at[1],shape.at[2])
		return create(parent,"patch",center,Vector2.ONE*float(shape.radius),0.,seed_value,settings)
	var start:=Vector3(shape.from[0],shape.from[1],shape.from[2])
	var end:=Vector3(shape.to[0],shape.to[1],shape.to[2])
	var axis:=end-start
	return create(parent,"fire" if skill=="ember_wake" else "thorn",(start+end)*.5,Vector2(axis.length()*.5,float(shape.width)),-atan2(axis.z,axis.x),seed_value,settings)
