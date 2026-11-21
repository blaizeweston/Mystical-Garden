extends Node3D
# Independent, short-lived visual bodies. They never participate in combat or collision.
const LIFETIME:=2.1
const MAX_CORPSES:=24
var stage: Node3D
var corpses: Dictionary={}
var seen: Dictionary={}
var floor_key: String=""
var observer:=Vector3.ZERO
var sight:=6.8
func sync(events: Array,key: String,world_position: Vector3,radius: float=6.8) -> void:
 if key!=floor_key:
  clear();floor_key=key
 observer=world_position;sight=radius
 for event in events:
  var id:=int(event.get("id",-1))
  if id<0 or seen.has(id): continue
  seen[id]=true
  if float(event.get("age",0))>=LIFETIME: continue
  spawn_body(event)
func clear() -> void:
 for body in corpses.values():
  if is_instance_valid(body.root): body.root.queue_free()
 corpses.clear();seen.clear()
func spawn_body(event: Dictionary) -> void:
 if corpses.size()>=MAX_CORPSES:
  var oldest=corpses.keys()[0];corpses[oldest].root.queue_free();corpses.erase(oldest)
 var root:=Node3D.new();add_child(root)
 var values: Array=event.position
 root.position=stage.WILD_OFFSET+Vector3(values[0],values[1],values[2])
 var vector: Array=event.get("direction",[0,0,1])
 var direction:=Vector3(vector[0],0,vector[2]).normalized()
 if direction.length_squared()<.001: direction=Vector3.FORWARD
 root.rotation.y=atan2(direction.x,direction.z)
 root.scale=Vector3.ONE*float(event.get("scale",1.0))
 var actor: Dictionary={};stage.ensure_enemy(root,actor,int(event.code))
 var definition: Dictionary=stage.Enemies.get_kind(int(actor.kind))
 var surfaces: Array=[]
 for mesh in actor.model.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh==null: continue
  var override=mesh.material_override
  if override is StandardMaterial3D:
   var material: StandardMaterial3D=override.duplicate()
   material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.emission_enabled=false
   mesh.material_override=material;surfaces.append({"material":material,"color":material.albedo_color})
  else:
   for index in mesh.mesh.get_surface_count():
    var original=mesh.get_active_material(index)
    if not original is StandardMaterial3D: continue
    var material: StandardMaterial3D=original.duplicate()
    material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.emission_enabled=false
    mesh.set_surface_override_material(index,material);surfaces.append({"material":material,"color":material.albedo_color})
 var spores: Array=[]
 for index in 6:
  var mote: MeshInstance3D=stage.sphere(Vector3.ZERO,.025,Color(definition.glow).lightened(.2))
  mote.reparent(root,false);spores.append(mote)
 var size_value: float=(.65 if int(actor.mask)&stage.Enemies.JUVENILE else 1.0)*(1.0+int(actor.growth)*.07)
 var body: Dictionary={"root":root,"actor":actor,"age":float(event.get("age",0)),"gait":str(definition.motion),"materials":surfaces,"spores":spores,"grow":size_value,"direction":direction,"start":root.position}
 corpses[int(event.id)]=body
 pose(body)
func pose(body: Dictionary) -> void:
 var time:=float(body.age)
 var collapse:=clampf(time/.65,0,1);collapse=1.0-pow(1.0-collapse,3)
 var fade:=1.0-clampf((time-.95)/(LIFETIME-.95),0,1)
 var actor: Dictionary=body.actor
 var model: Node3D=actor.model
 var bob:=sin(minf(1.0,time/.28)*PI)*.08
 var wilt: bool=body.gait=="sway"
 var flyer: bool=body.gait=="hover"
 model.rotation=Vector3(collapse*(.55 if wilt else 1.15 if flyer else 1.35),0,collapse*(.20 if wilt else -.65 if flyer else .16))
 model.position.y=(.2*(1-collapse) if flyer else bob)-.10*collapse
 var y:=lerpf(1.0,.23 if wilt else .5 if body.gait=="crawl" else .78,collapse)
 model.scale=Vector3(lerpf(1.0,1.13 if wilt else 1.0,collapse),y,1.0)*float(body.grow)
 body.root.position=body.start+body.direction*(.3*collapse)
 for index in actor.legs.size():
  actor.legs[index].rotation.x=collapse*(.65+index*.045)
  if flyer: actor.legs[index].rotation.z=collapse*(.8 if index%2==0 else -.8)
 for entry in body.materials:
  var color: Color=entry.color
  color=color.lerp(Color("#45473a"),clampf(time*.8,0,.65));color.a=fade
  entry.material.albedo_color=color
 for index in body.spores.size():
  var mote: Node3D=body.spores[index]
  var angle: float=index*TAU/6
  var rise:=clampf((time-.18)/.85,0,1)
  mote.position=Vector3(cos(angle)*(.15+rise*.38),.25+rise*(.35+index*.05),sin(angle)*(.15+rise*.38))
  mote.scale=Vector3.ONE*maxf(.001,sin(rise*PI)*fade)
 body.root.visible=body.root.position.distance_to(stage.WILD_OFFSET+observer)<=sight
func step(delta: float) -> void:
 for id in corpses.keys():
  var body: Dictionary=corpses[id]
  body.age+=delta
  if float(body.age)>=LIFETIME:
   body.root.queue_free();corpses.erase(id)
  else: pose(body)
func _process(delta: float) -> void:
 step(delta)

