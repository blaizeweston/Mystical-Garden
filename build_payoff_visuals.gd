extends RefCounted
## Draw only the accepted receipt, including its actual endpoints and area.
const SHADER=preload("res://assets/shaders/build_payoff.gdshader")
const CONTROLS:={"payoff.ink":[.85,.25,1.,.01,"Payoff stroke opacity","α"],"payoff.edge":[1.,.5,1.5,.05,"Payoff stroke width","×"]}
const PREVIEWS:=["avalanche_stack","shatterwave","bloodletting","harvest_spend","bloom_echo","link","echo","chorus"]
const TITLES:=["Avalanche · propagated stack","Shatterwave · area discharge","Bloodletting · aimed cut","Harvest · bonus health spent","Echoing Growth · bloom pulse","Silken Mycelium · link","Prismatic Gill · echo","Chorus Node · contact"]
const STYLES:={"avalanche_stack":0,"shatterwave":1,"bloodletting":2,"harvest_spend":3,"bloom_echo":4,"link":5,"echo":6,"chorus":7}
const LINKS:=["avalanche_stack","link","echo","chorus"]

static func accepts(event:Dictionary)->bool:
	if event.kind=="proc":return event.get("form","")=="adaptation" and event.shape in ["link","echo","chorus"]
	if event.kind=="link":return event.shape=="avalanche_stack"
	return event.kind=="ability" and event.shape in ["shatterwave","bloodletting","harvest_spend","bloom_echo"]

static func create(parent:Node3D,kind:String,start:Vector3,end:Vector3,radius:float,values:Dictionary)->MeshInstance3D:
	var glyph:=MeshInstance3D.new()
	glyph.mesh=preload("res://class_release_visuals.gd").stroke_mesh()
	glyph.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glyph.set_meta("payoff_kind",kind)
	var path:=end-start if kind in LINKS else Vector3.ZERO
	var bounds:=Vector3.ONE*(maxf(radius,1.)+1.2)
	glyph.custom_aabb=AABB(Vector3.ZERO.min(path)-bounds,path.abs()+bounds*2.)
	glyph.position=start if kind in LINKS else end
	var mat:=ShaderMaterial.new()
	mat.shader=SHADER
	mat.set_shader_parameter("style",STYLES[kind])
	mat.set_shader_parameter("path",path)
	mat.set_shader_parameter("extent",radius)
	glyph.material_override=mat
	parent.add_child(glyph)
	configure(glyph,values)
	return glyph

static func configure(glyph:MeshInstance3D,values:Dictionary)->void:
	for id:String in CONTROLS:
		glyph.material_override.set_shader_parameter(id.replace(".","_"),values.get(id,CONTROLS[id][0]))

static func seek(glyph:MeshInstance3D,elapsed:float,duration:float)->void:
	glyph.material_override.set_shader_parameter("phase",clampf(elapsed/maxf(duration,.001),0.,1.))

## Co-located voices share one caption. Each actual preparation retains its own body.
## Field rims and orbits keep full visibility. Only overlapping dark centers are attenuated.
static func assign_overlaps(hints:Dictionary,layout:Dictionary)->void:
	var images:={}
	var wells:=[]
	for id in layout:
		var glyph:MeshInstance3D=hints[id].astral
		if glyph.get_meta("astral_kind") in ["gravity_well","singularity"]:
			wells.append(glyph)
		else:
			var group:Array=images.get_or_add(glyph.position,[])
			group.append(glyph)
	for field:MeshInstance3D in wells:
		var count:=1
		for other:MeshInstance3D in wells:
			if other!=field and field.position.distance_to(other.position)<.12*(float(field.material_override.get_shader_parameter("extent"))+float(other.material_override.get_shader_parameter("extent"))):count+=1
		field.material_override.set_shader_parameter("core_weight",1./count)
	for group:Array in images.values():
		var echoes:=group.filter(func(glyph):return glyph.get_meta("astral_kind")=="mirrorstep").size()
		var shadows:=group.size()-echoes
		for index in group.size():
			var glyph:MeshInstance3D=group[index]
			var caption:=glyph.get_node_or_null("PreparationCount") as Label3D
			if index!=0 or group.size()<2:
				if caption!=null:caption.hide()
				continue
			if caption==null:
				caption=Label3D.new()
				caption.name="PreparationCount"
				caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
				caption.font_size=30
				caption.pixel_size=.006
				caption.outline_size=6
				caption.modulate=Color("#c5dcde")
				caption.position.y=1.91
				glyph.add_child(caption)
			var words:=PackedStringArray()
			if echoes:words.append("%d %s"%[echoes,"echo" if echoes==1 else "echoes"])
			if shadows:words.append("%d %s"%[shadows,"shadow" if shadows==1 else "shadows"])
			caption.text=" · ".join(words)
			caption.show()
