extends Node3D
const CoreVisuals = preload("res://core_skill_visuals.gd")
const Ranger = preload("res://ranger_combat.gd")
const EnemyFeedback = preload("res://enemy_move_feedback.gd")
var stage: Node3D
var active: Dictionary={}
var seen: Dictionary={}
var hints: Dictionary={}
var floor_key: String=""
var observer:=Vector3.ZERO
var sight:=6.8
var statuses=preload("res://status_feedback.gd").new()
var feedback=preload("res://combat_feedback.gd").new()
func _ready() -> void:
 feedback.stage=stage;add_child(feedback)
 statuses.stage=stage;add_child(statuses)

func material(color: Color) -> StandardMaterial3D:
 var result:=StandardMaterial3D.new();result.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;result.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;result.cull_mode=BaseMaterial3D.CULL_DISABLED;result.vertex_color_use_as_albedo=true;result.albedo_color=color;result.emission_enabled=true;result.emission=color;result.emission_energy_multiplier=.65;return result
func visual(color: Color) -> Dictionary:
 var root:=Node3D.new();add_child(root);root.position=stage.WILD_OFFSET
 var mesh:=MeshInstance3D.new();root.add_child(mesh);mesh.mesh=ImmediateMesh.new();mesh.material_override=material(color);mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return {"root":root,"mesh":mesh,"age":0.0}
func sync(events: Array,telegraphs: Array,key: String,position: Vector3,radius: float=6.8) -> void:
 if key!=floor_key: clear();floor_key=key
 observer=position;sight=radius
 feedback.observer=position;feedback.sight=radius
 statuses.observer=position;statuses.sight=radius
 for event in events:
  if event.kind=="audio":continue
  if seen.has(event.id): continue
  seen[event.id]=true
  if event.kind in ["status","status_end"]:statuses.consume(event);continue
  if event.kind=="windup":continue
  if event.kind=="projectile_end":
   var ended:=int(event.shape)
   if active.has(ended):active[ended].root.queue_free();active.erase(ended)
   continue
  if event.kind=="field_end":
   var ended:=int(event.shape)
   if active.has(ended): active[ended].root.queue_free();active.erase(ended)
   continue
  if float(event.get("age",0))>=float(event.duration): continue
  if event.kind=="impact" and event.shape=="heal":
   var at:=point(event.to)
   if at.distance_to(observer)<=sight:feedback.confirmed(event,at)
   continue
  if active.size()>=80:
   var old=active.keys()[0];active[old].root.queue_free();active.erase(old)
  var effect:=visual(Color(event.color));effect.event=event;effect.age=float(event.get("age",0))
  var visible_hit: bool=point(event.to).distance_to(observer)<=sight
  if event.kind=="impact" and visible_hit:feedback.confirmed(event,point(event.to))
  if event.kind=="proc" and visible_hit:
   var name: String={"mark_break":"Mark triggered","core_mark_burst":"Core Mark burst","shatter":"Shatter!","suppress":"Interrupted","echo":"Echo","link":"Linked hit","chorus":"Chorus","counter":"Counter!","brace":"Braced","momentum":"Death charge","pierce":"Pierced","punish":"Wind-up punished","siphon":"Life restored"}.get(str(event.shape),str(event.shape).capitalize())
   feedback.text_at(name,point(event.to),Color(event.color),int(event.id),true)
  if event.kind=="enemy_release" and visible_hit:
   if event.shape=="pulled":feedback.text_at("Pulled",point(event.to),Color(event.color),int(event.id),true,3.45)
   elif event.shape=="restored" and int(event.reach)>0:feedback.text_at("+%d"%int(event.reach),point(event.to),Color(event.color),int(event.id))
   elif event.shape=="trophy":feedback.text_at("Trophy stolen",point(event.to),Color(event.color),int(event.id),true)
  if event.kind=="ability" and visible_hit and not str(event.get("label",event.shape)).is_empty():feedback.text_at(str(event.get("label",event.shape)),point(event.to),Color("#bcebdd"),int(event.id),true)
  if event.kind=="subclass_release" and visible_hit and not str(event.get("label","")).is_empty():
   feedback.text_at(event.label,point(event.to),Color(event.color),int(event.id),true)
  if event.kind=="field" and event.shape not in [Ranger.CORRIDOR,Ranger.ESCAPE]:
   var species: String={"growth_zone":"whispervine","tide_zone":"tide_lily","decoy_zone":"dream_poppy","luring_snare_zone":"dream_poppy"}.get(str(event.shape),"whispervine")
   var plant_index: int=preload("res://seed_catalog.gd").index_of(species)
   if plant_index>=0:
    var growth: Node3D=stage.build_crop(plant_index,2,false)
    growth.reparent(effect.root,false);growth.position=point(event.to);effect.growth=growth
  if event.kind=="projectile" and event.get("form","")==event.shape and event.shape in ["orb","ring"]:
   var model:=preload("res://plant_weapon_models.gd").in_flight(event.shape,float(event.projectile_radius))
   effect.root.add_child(model)
   effect.glyph=model
  elif event.kind=="projectile" and event.shape in ["spell","needle","orb","ring"]:
   var glyph:=MeshInstance3D.new();effect.root.add_child(glyph)
   if event.shape=="ring":
    var ring:=TorusMesh.new();ring.inner_radius=.14;ring.outer_radius=.22;ring.rings=12;ring.ring_segments=8;glyph.mesh=ring
   else:
    var sphere:=SphereMesh.new();sphere.radius=float(event.get("projectile_radius",.1));sphere.height=sphere.radius*2;sphere.radial_segments=8;sphere.rings=4;glyph.mesh=sphere
   glyph.material_override=material(Color(event.color));glyph.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;effect.glyph=glyph
  active[event.id]=effect
  pose(effect)
 while seen.size()>2048:seen.erase(seen.keys()[0])
 var keep: Array=[]
 for warning in telegraphs:
  if warning.role in ["memory_growth","glasscap_feint"]:continue
  keep.append(warning.id)
  if not hints.has(warning.id): hints[warning.id]=visual(Color("#ffa766"))
  var hint: Dictionary=hints[warning.id];hint.event=warning;draw_hint(hint)
 for id in hints.keys():
  if not keep.has(id): hints[id].root.queue_free();hints.erase(id)
func clear() -> void:
 for collection in [active,hints]:
  for effect in collection.values(): effect.root.queue_free()
  collection.clear()
 seen.clear()
 feedback.clear()
 statuses.clear()
func point(values: Array) -> Vector3:
 return Vector3(values[0],values[1],values[2])
func ribbon(mesh: ImmediateMesh,a: Vector3,b: Vector3,width: float) -> void:
 var side: Vector3=(b-a).cross(Vector3.UP).normalized()*width*.5
 if side.length_squared()<.00001: side=Vector3.RIGHT*width*.5
 for vertex in [a-side,a+side,b+side,a-side,b+side,b-side]: mesh.surface_add_vertex(vertex)
func circle(mesh: ImmediateMesh,center: Vector3,radius: float,width: float=.06) -> void:
 for i in 40:
  var first:=i*TAU/40.0;var second:=(i+1)*TAU/40.0
  ribbon(mesh,center+Vector3(cos(first),0,sin(first))*radius,center+Vector3(cos(second),0,sin(second))*radius,width)
func pose(effect: Dictionary) -> void:
 var event: Dictionary=effect.event
 var mesh: ImmediateMesh=effect.mesh.mesh;mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 var t:=clampf(float(effect.age)/float(event.duration),0,1)
 var from:=point(event.from);var to:=point(event.to)
 if event.kind=="swing" and event.has("owner"):
  if not effect.has("frozen_from"):
   var owner: Node3D=stage.avatars.get(int(event.owner))
   if is_instance_valid(owner):
    var shift: Vector3=owner.position-stage.WILD_OFFSET-from;from+=shift;to+=shift
   if t>=float(event.get("contact",.42)):effect.frozen_from=from;effect.frozen_to=to
  else:from=effect.frozen_from;to=effect.frozen_to
 var direction: Vector3=(to-from).normalized()
 if direction.length_squared()<.001: direction=Vector3.FORWARD
 var side:=direction.cross(Vector3.UP).normalized()
 if event.kind=="subclass_release":
  preload("res://subclass_visuals.gd").release(self,mesh,event,from,to,t)
 elif event.kind=="enemy_release":
  EnemyFeedback.paint_release(self,mesh,event,from,to,t)
 elif event.kind=="proc":
  var center:=to+Vector3.UP*float(event.get("height",.85))
  if event.shape in ["link","echo","chorus"]:
   if from.distance_to(to)<.1:circle(mesh,center,.12+t*.55,.045)
   for i in 18:
    var u:=i/18.;var v:=(i+1)/18.
    ribbon(mesh,from.lerp(to,u)+Vector3.UP*(.85+sin(u*PI)*.35)+side*sin(u*TAU*2+t*TAU)*.08,from.lerp(to,v)+Vector3.UP*(.85+sin(v*PI)*.35)+side*sin(v*TAU*2+t*TAU)*.08,.05*(1-t)+.015)
  elif event.shape in ["mark_break","core_mark_burst","shatter"]:
   for i in 8:
    var a:=i*TAU/8.;var direction_out:=Vector3(cos(a),sin(a),0)
    ribbon(mesh,center+direction_out*(.12+t*.6),center+direction_out*(.25+t*.8),.05*(1-t)+.01)
  elif event.shape=="suppress":
   circle(mesh,center,.15+t*.5,.07)
   ribbon(mesh,center+Vector3(-.25,0,-.25),center+Vector3(.25,0,.25),.08)
  else:
   circle(mesh,to+Vector3.UP*.12,maxf(.3,float(event.reach))*t,.045)
 elif event.kind=="projectile":
  var at: Vector3=from.lerp(to,t)+Vector3.UP*float(event.get("height",1.05))
  ribbon(mesh,at-direction*(.40+.35*t),at,float(event.get("projectile_radius",.08)))
  if event.shape in ["arrow","bolt","petal"]:
   var tip: Vector3=at
   if event.shape=="petal":
    var radius:=float(event.get("projectile_radius",.10))
    for vertex in [tip,at-direction*.12+side*radius,at-direction*.32,tip,at-direction*.32,at-direction*.12-side*radius]:
     mesh.surface_add_vertex(vertex)
   else:
    for vertex in [tip,at-direction*.18+side*float(event.get("projectile_radius",.1)),at-direction*.18-side*float(event.get("projectile_radius",.1))]: mesh.surface_add_vertex(vertex)
   if event.shape=="arrow":
    for vertex in [at-direction*.32,at-direction*.47+side*.08,at-direction*.47-side*.08]: mesh.surface_add_vertex(vertex)
  if effect.has("glyph"):
   effect.glyph.position=at;effect.glyph.rotation.y=t*TAU*3
 elif event.kind=="field" and event.shape in [Ranger.CORRIDOR,Ranger.ESCAPE]:
  var width := float(event.reach)
  var lane_from := from+Vector3.UP*.055
  var lane_to := to+Vector3.UP*.055
  for sign_value in [-1.0,1.0]:
   var edge := side*width*float(sign_value)
   ribbon(mesh,lane_from+edge,lane_to+edge,.045)
  var count := maxi(1,ceili(from.distance_to(to)/.65))
  for index in count:
   var at := lane_from.lerp(lane_to,(index+.5)/count)
   if event.shape==Ranger.CORRIDOR:
    snare_roots(mesh,at,width*.73,4)
   else:
    var tip := at+direction*.22
    ribbon(mesh,at-side*.23,tip,.045)
    ribbon(mesh,at+side*.23,tip,.045)
 elif event.kind=="field":
  if effect.has("growth"): effect.growth.scale=Vector3.ONE*(minf(1.0,t*5.0)*minf(1.0,(1.0-t)*5.0)*.9+.1)
  circle(mesh,to+Vector3.UP*.05,float(event.get("reach",1.6)),.06)
  circle(mesh,to+Vector3.UP*.06,float(event.get("reach",1.6))*.65,.025)
  if event.shape in ["snare_zone","luring_snare_zone"]:
   snare_roots(mesh,to+Vector3.UP*.065,float(event.reach),8)
  if event.shape=="cinder_zone":
   for i in 16:
    var angle:=i*TAU/16.+t;var base:=to+Vector3(cos(angle),0,sin(angle))*float(event.reach)*(.3+.6*(i%3)/2.)
    ribbon(mesh,base+Vector3.UP*.1,base+Vector3.UP*(.3+.25*sin(t*TAU*4+i)),.05)
 elif event.kind=="ability" and event.has("core_shapes"):
  CoreVisuals.draw(self,mesh,event,to,t,false)
 elif event.kind=="ability" and event.shape in ["riptide","riptide_return"]:
  var crest:=from.lerp(to,t)+Vector3.UP*.09
  var width:=float(event.reach)
  for band in 3:
   var trail:=float(band)*.16
   for index in 18:
    var a:=index/9.0-1.0
    var b:=(index+1)/9.0-1.0
    var first:=crest+side*a*width-direction*(a*a*.32+trail)+Vector3.UP*(1-a*a)*.19
    var second:=crest+side*b*width-direction*(b*b*.32+trail)+Vector3.UP*(1-b*b)*.19
    ribbon(mesh,first,second,.15-float(band)*.035)
 elif event.kind=="ability" and event.shape in ["mirror_bloom","lantern_burst"]:
  var center:=to+Vector3.UP*.12
  var radius:=float(event.reach)
  var bloom:=smoothstep(0.0,.45,t)
  var points:=8 if event.shape=="mirror_bloom" else 12
  for index in points:
   var ray:=Vector3(cos(index*TAU/points),0,sin(index*TAU/points))
   var cross:=ray.cross(Vector3.UP)
   var tip:=center+ray*radius*bloom+Vector3.UP*(.18+.35*t)
   var middle:=center+ray*radius*bloom*.63
   var petal_width:=radius*(.20 if event.shape=="mirror_bloom" else .055)
   ribbon(mesh,center,middle+cross*petal_width,.055)
   ribbon(mesh,center,middle-cross*petal_width,.055)
   ribbon(mesh,middle+cross*petal_width,tip,.075)
   ribbon(mesh,middle-cross*petal_width,tip,.075)
 elif event.kind=="ability":
  var family:=feedback.family(str(event.shape));var reach:=clampf(float(event.reach),.8,8)
  var center:=to+Vector3.UP*.08;var spread:=smoothstep(0,.5,t)
  circle(mesh,center,reach*(.65+.35*spread),.085*(1-t)+.025)
  if family=="guard":
   for i in 12:
    var a:=i*TAU/12.;var base:=center+Vector3(cos(a),0,sin(a))*reach
    ribbon(mesh,base,base+Vector3.UP*(.35+.7*sin(t*PI)),.07)
   circle(mesh,center+Vector3.UP*.65,reach*.88,.04)
  elif family=="restore":
   circle(mesh,center,reach*.6,.05)
   for i in 10:
    var a:=i*TAU/10.+t*1.5;var base:=center+Vector3(cos(a),0,sin(a))*reach*.65
    ribbon(mesh,base+Vector3.UP*t*.6,base+Vector3.UP*(t*.6+.24),.075)
  elif family=="control":
   for i in 10:
    var a:=i*TAU/10.
    for j in 8:
     var u:=j/8.;var v:=(j+1)/8.
     var first:=a+.28*sin(u*PI)+t*.2;var second:=a+.28*sin(v*PI)+t*.2
     var start:=center+Vector3(cos(first)*reach*u,.25*sin(u*PI)*sin(t*PI),sin(first)*reach*u)
     var end:=center+Vector3(cos(second)*reach*v,.25*sin(v*PI)*sin(t*PI),sin(second)*reach*v)
     ribbon(mesh,start,end,.09*(1-u)+.025)
  elif family in ["travel","bolt"]:
   ribbon(mesh,from+Vector3.UP*.35,to+Vector3.UP*.35,.12*(1-t)+.03)
   for i in 6:
    var base:=from.lerp(to,(i+.5)/6.)+Vector3.UP*.35
    ribbon(mesh,base-side*.22-direction*.18,base+direction*.2,.06)
    ribbon(mesh,base+side*.22-direction*.18,base+direction*.2,.06)
  else:
   circle(mesh,center,reach*spread,.11*(1-t)+.03)
   for i in 10:
    var a:=i*TAU/10.;var ray:=Vector3(cos(a),.15,sin(a))
    ribbon(mesh,center+ray*reach*spread*.65,center+ray*reach*spread,.055)
 elif event.kind=="impact":
  var burst:=clampf(float(effect.age)/.2,0,1)
  for i in 7:
   var angle:=i*TAU/7.0
   var vector:=Vector3(cos(angle),.2,sin(angle))
   ribbon(mesh,to+Vector3.UP*.65+vector*(.08+burst*.35),to+Vector3.UP*.65+vector*(.18+burst*.6),.085*(1-burst))
 elif event.kind=="link" and event.shape=="blood_siphon":
  var front:=from.lerp(to,smoothstep(0,1,t))+Vector3.UP*.8
  ribbon(mesh,from+Vector3.UP*.8,front,.055)
  for i in 3:
   var node:=front-direction*i*.16+Vector3.UP*(.09+i*.07)
   ribbon(mesh,node-side*.08,node+side*.08,.1)
 elif event.kind=="link":
  for i in 12:
   var u:=i/12.;var v:=(i+1)/12.
   ribbon(mesh,from.lerp(to,u)+Vector3.UP*.8+side*sin(u*PI*4)*.06,from.lerp(to,v)+Vector3.UP*.8+side*sin(v*PI*4)*.06,.055)
 elif event.kind=="swing" and event.has("pattern"):
  var shape: Dictionary=event.duplicate();shape.reach=float(event.reach)
  var outline:=preload("res://weapon_contact.gd").outline(shape,from,to)
  var center:=from if event.pattern!="line" else from.lerp(to,.5)
  mesh.surface_set_color(Color(1,1,1,.12))
  for i in outline.size():
   for vertex in [center,outline[i],outline[(i+1)%outline.size()]]:mesh.surface_add_vertex(vertex+Vector3.UP*.09)
  mesh.surface_set_color(Color.WHITE)
  for i in outline.size():ribbon(mesh,outline[i]+Vector3.UP*.10,outline[(i+1)%outline.size()]+Vector3.UP*.10,.045)
  if event.pattern=="line":ribbon(mesh,from+Vector3.UP*.85,to+Vector3.UP*.85,float(event.width)*2)
  elif event.shape=="smoke" and event.pattern=="sweep":
   var reach:=float(event.reach)
   var angle:=lerpf(-float(event.span)*.5,float(event.span)*.5,clampf(t/float(event.get("contact",.5)),0,1))
   for index in 14:
    var u: float=index/14.0
    var a:=direction.rotated(Vector3.UP,angle-u*.7)
    var b:=direction.rotated(Vector3.UP,angle-(u+.072)*.7)
    var height:=.3+u*.45
    ribbon(mesh,from+a*reach*(.75+.15*u)+Vector3.UP*height,from+b*reach*(.75+.15*u)+Vector3.UP*(height+.03),.18-.10*u)
  elif event.shape=="pulse" and event.pattern=="radial":
   circle(mesh,from+Vector3.UP*.26,float(event.reach)*smoothstep(.2,.72,t),.11)
   circle(mesh,from+Vector3.UP*.42,float(event.reach)*smoothstep(.28,.8,t),.05)
 else:
  var reach:=clampf(float(event.get("reach",2.0)),1.0,8.0)
  if event.shape in ["arc","knife_arc","wide_arc"]:
   var span: float=float(event.get("span",2.7 if event.shape=="wide_arc" else 1.3 if event.shape=="knife_arc" else 1.9))
   var base:=atan2(direction.x,direction.z)
   var reverse: float=-1.0 if int(event.get("combo",0))%2==1 and event.shape=="knife_arc" else 1.0
   var end:=lerpf(-span*.5,span*.5,t)*reverse
   for i in 22:
    var a:=base+end-span*.50*i/22.0*reverse
    var b:=base+end-span*.50*(i+1)/22.0*reverse
    ribbon(mesh,from+Vector3(sin(a)*reach,.72,cos(a)*reach),from+Vector3(sin(b)*reach,.72,cos(b)*reach),.05+.12*(1-i/22.0))
  elif event.shape=="thrust":
   var extension:=smoothstep(.18,.42,t)*(1-smoothstep(.60,1,t))
   ribbon(mesh,from+Vector3.UP*.8,from+direction*reach*extension+Vector3.UP*.8,.09*(1-t)+.03)
  elif event.shape=="lash":
   var length:=sin(t*PI)*reach
   for i in 18:
    var u:=i/18.0;var v:=(i+1)/18.0
    var a:=from+direction*(length*u)+side*sin(u*PI*2+t*TAU)*.22*u+Vector3.UP*.65
    var b:=from+direction*(length*v)+side*sin(v*PI*2+t*TAU)*.22*v+Vector3.UP*.65
    ribbon(mesh,a,b,.065*(1-u)+.02)
  else:
   var center:=to+Vector3.UP*.06
   circle(mesh,center,(.25+t*2.0) if event.shape!="slam" else .3+t*1.5,.08*(1-t)+.02)
   if event.shape in ["pulse","smoke"]: circle(mesh,center,.2+t*1.25,.045)
 mesh.surface_end()
 var surface:=effect.mesh.material_override as StandardMaterial3D
 var color:=Color(event.color);color.a=.95 if event.kind=="projectile" else (1.0-t)*.9
 if event.shape in ["riptide","riptide_return"]:color.a=.85
 if event.kind=="impact":color=Color("#fff2ce") if event.shape!="hurt" else Color("#ff957d");color.a=(1-clampf(float(effect.age)/.2,0,1))*.95
 if event.kind=="swing" and event.has("pattern"):
  var contact:=float(event.get("contact",.42));var band:=.12
  color.a*=smoothstep(contact-band,contact,t)*(1-smoothstep(contact,contact+.26,t))
 surface.albedo_color=color
 effect.root.visible=Geometry3D.get_closest_point_to_segment(observer,from,to).distance_to(observer)<=sight
func snare_roots(mesh: ImmediateMesh, center: Vector3, radius: float, count: int) -> void:
 for index in count:
  var ray:=Vector3(cos(index*TAU/count),0,sin(index*TAU/count))
  var cross:=ray.cross(Vector3.UP)
  var fork:=center+ray*radius*.68+Vector3.UP*.1
  ribbon(mesh,center+ray*radius*.25,fork,.055)
  ribbon(mesh,fork,center+(ray*.93+cross*.22)*radius+Vector3.UP*.18,.045)
  ribbon(mesh,fork,center+(ray*.91-cross*.23)*radius,.035)


func draw_hint(hint: Dictionary) -> void:
 var event: Dictionary=hint.event
 var mesh: ImmediateMesh=hint.mesh.mesh;mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 var from:=point(event.from)+Vector3.UP*.055;var to:=point(event.to)+Vector3.UP*.055
 var role:=str(event.role);var radius:=float(event.radius)
 var hazard: Dictionary=EnemyFeedback.HAZARDS.get(event.get("hazard_kind",""),{})
 if role=="core_lured":
  var surface: StandardMaterial3D=hint.mesh.material_override
  surface.albedo_color=Color(event.color)
  surface.emission=surface.albedo_color
  var ray: Vector3=(to-from).normalized()
  var side:=ray.cross(Vector3.UP)
  var step:=fposmod(Time.get_ticks_msec()*.002,1.0)
  for index in 3:
   var tip:=from.lerp(to,(index+step)/3.0)+Vector3.UP*.24
   ribbon(mesh,tip-ray*.18+side*.10,tip,.05)
   ribbon(mesh,tip-ray*.18-side*.10,tip,.05)
  hint.root.visible=to.distance_to(observer)<=sight
  mesh.surface_end()
  return
 if role=="core_field":
  var surface: StandardMaterial3D=hint.mesh.material_override
  surface.albedo_color=Color(event.color)
  surface.emission=surface.albedo_color
  if event.has("core_shapes"):
   var remaining:=float(event.remaining)
   if not hint.has("total"):hint.total=maxf(.1,remaining)
   CoreVisuals.draw(self,mesh,event,to,1.0-clampf(remaining/float(hint.total),0,1),true)
   hint.root.visible=to.distance_to(observer)<=sight+radius
   mesh.surface_end()
   return
  circle(mesh,to,radius,.078)
  match str(event.get("skill","")):
   "moon_snare","spore_seal":
    snare_roots(mesh,to,radius,9 if event.skill=="moon_snare" else 6)
   "ember_wake":
    for index in 15:
     var ray:=Vector3(cos(index*TAU/15),0,sin(index*TAU/15))
     var base:=to+ray*radius*(.33+.13*(index%5))
     var length:=.16+.14*(1+sin(Time.get_ticks_msec()*.013+index))
     ribbon(mesh,base,base+Vector3.UP*length+ray*.07,.06)
   "mirror_bloom":
    for index in 4:
     var a:=index*PI*.5
     var b:=(index+1)*PI*.5
     ribbon(mesh,to+Vector3(cos(a),.03,sin(a))*radius*.65,to+Vector3(cos(b),.03,sin(b))*radius*.65,.055)
  var remaining:=float(event.remaining)
  if not hint.has("total"):hint.total=maxf(.1,remaining)
  for index in maxi(1,roundi(32*clampf(remaining/float(hint.total),0,1))):
   var a:=float(index)*TAU/32.0
   var b:=float(index+1)*TAU/32.0
   ribbon(mesh,to+Vector3(cos(a),.015,sin(a))*radius*.82,to+Vector3(cos(b),.015,sin(b))*radius*.82,.065)
  if event.get("decoy",false):
   for index in 4:
    var a:=float(index)*TAU/4.0
    var b:=float(index+1)*TAU/4.0
    ribbon(mesh,to+Vector3(cos(a),.08,sin(a))*.48,to+Vector3(cos(b),.08,sin(b))*.48,.12)
  hint.root.visible=to.distance_to(observer)<=sight+radius
  mesh.surface_end()
  return
 if role=="core_thorns":
  preload("res://core_thorn_visual.gd").draw(self,hint,mesh,from,to,radius)
  mesh.surface_end()
  return
 if role=="core_anchor":
  var at:=from+Vector3.UP*.28
  circle(mesh,from,radius,.042)
  var ray: Vector3=(to-from).normalized()
  var side:=ray.cross(Vector3.UP)*float(event.get("width",.21))
  for index in maxi(0,floori(from.distance_to(to)/.45)):
   var step:=from+ray*float(index)*.45
   ribbon(mesh,step+side,step+side+ray*.23,.025)
   ribbon(mesh,step-side,step-side+ray*.23,.025)
   if index%3==0:
    var star:=step+Vector3.UP*.17
    ribbon(mesh,star-Vector3.UP*.15,star+Vector3.UP*.15,.057)
    ribbon(mesh,star-side*.76,star+side*.76,.042)
  for i in 4:
   var axis:=Vector3(cos(i*PI*.5),0,sin(i*PI*.5))
   ribbon(mesh,at,at+axis*.32,.06)
  var surface: StandardMaterial3D=hint.mesh.material_override
  surface.albedo_color=Color(event.color)
  surface.emission=surface.albedo_color
  hint.root.visible=from.distance_to(observer)<=sight
  mesh.surface_end()
  return
 if role=="charge":
  var direction: Vector3=(to-from).normalized();var side:=direction.cross(Vector3.UP).normalized()
  var width:=float(event.get("width",.85))
  ribbon(mesh,from-side*width,to-side*width,.055);ribbon(mesh,from+side*width,to+side*width,.055)
  var count:=maxi(2,ceili(from.distance_to(to)/.8))
  for i in count:
   var center:=from.lerp(to,(i+.5)/count)
   var tip:=center+direction*.23
   ribbon(mesh,center-direction*.15+side*.24,tip,.085)
   ribbon(mesh,center-direction*.15-side*.24,tip,.085)
  circle(mesh,from,width,.055)
  circle(mesh,to,maxf(radius,width),.085)
 elif role in ["nursery_rib","nursery_exit","nursery_site"]:
  preload("res://boss_phase_visuals.gd").draw_warning(self,mesh,event,to)
 elif not hazard.is_empty():
  EnemyFeedback.paint_hazard(self,mesh,event.hazard_kind,to,radius,event.active)
 elif role in ["orchard_sweep","orchard_cage","orchard_anchor","lair_zone","lair_phase","lair_open"] or (role=="hazard" and event.has("lair")):
  preload("res://boss_lair_visuals.gd").draw_warning(self,mesh,event,from,to)
 elif role in ["enemy_sweep","canopy_sector"]:
  var aim:=point(event.face)+Vector3.UP*.055
  var forward: Vector3=(aim-from).normalized()
  if forward.is_zero_approx():forward=Vector3.FORWARD
  var span_value:=float(event.span)
  ribbon(mesh,from,from+forward.rotated(Vector3.UP,span_value*.5)*radius,.06)
  ribbon(mesh,from,from+forward.rotated(Vector3.UP,-span_value*.5)*radius,.06)
  for i in 24:
   var a:=forward.rotated(Vector3.UP,span_value*(i/24.0-.5))
   var b:=forward.rotated(Vector3.UP,span_value*((i+1)/24.0-.5))
   ribbon(mesh,from+a*radius,from+b*radius,.07)
 elif role in ["corpse_tether","trophy_grab","rally_link","hatch","aftershock"]:
  var direction: Vector3=(to-from).normalized()
  if role in ["corpse_tether","trophy_grab","rally_link"]:
   for i in 9:
    ribbon(mesh,from.lerp(to,i/9.0),from.lerp(to,(i+.65)/9.0),.055)
  if role!="rally_link" or from.distance_to(to)<.05:
   circle(mesh,to,radius,.075)
   if role in ["hatch","aftershock"]:circle(mesh,to,radius*.58,.035)
  if role=="trophy_grab":
   var side:=direction.cross(Vector3.UP)
   ribbon(mesh,to-direction*.4+side*.25,to,.055)
   ribbon(mesh,to-direction*.4-side*.25,to,.055)
 elif role=="burrow":
  var via:=point(event.via)+Vector3.UP*.055 if event.has("via") else from.lerp(to,.5)
  for leg in [[from,via],[via,to]]:
   for i in 8:
    var a: Vector3=leg[0].lerp(leg[1],i/8.0)
    var b: Vector3=leg[0].lerp(leg[1],(i+.55)/8.0)
    ribbon(mesh,a,b,.06)
  circle(mesh,to,radius,.09)
  circle(mesh,to,radius*.55,.035)
 elif role=="canopy":
  circle(mesh,to,radius,.044)
  circle(mesh,to,radius*.91,.028)
 elif event.get("field",false):
  circle(mesh,to,radius,.085)
  circle(mesh,to,radius*.68,.04)
  for i in 6:
   var angle:=TAU*i/6.0
   var offset:=Vector3(cos(angle),0,sin(angle))*radius
   ribbon(mesh,to+offset*.43,to+offset*.55,.06)
 elif role in ["pounce","vault"]:
  for i in 8:
   var u:=i/8.0;var v:=(i+.5)/8.0
   ribbon(mesh,from.lerp(to,u),from.lerp(to,v),.05)
  circle(mesh,to,radius,.065);circle(mesh,to,radius*.65,.035)
 else:
  var center: Vector3=from if role in ["swipe","stomp","chant","shepherd","brood","desperate"] else to
  circle(mesh,center,.36 if role=="brood" else radius,.045 if role=="brood" else .065)
  if role in ["artillery","snare","stomp","chant","shepherd","lure"]: circle(mesh,center,radius*.72,.04)
  if role in ["volley","artillery","snare","lure"]:
   var anchor:=point(event.anchor)+Vector3.UP*.055 if event.has("anchor") else from
   ribbon(mesh,from,anchor,.05)
   ribbon(mesh,anchor,to,.045)
   if role=="lure":
    var forward: Vector3=(anchor-to).normalized()
    var side:=forward.cross(Vector3.UP)
    var tip:=to+forward*minf(radius,to.distance_to(anchor)*.65)
    ribbon(mesh,tip-forward*.32+side*.23,tip,.07)
    ribbon(mesh,tip-forward*.32-side*.23,tip,.07)
    circle(mesh,anchor,.31,.055)
   for axis in [Vector3.RIGHT,Vector3.FORWARD]: ribbon(mesh,center-axis*radius*1.15,center+axis*radius*1.15,.045)
 if event.has("remaining") and role not in ["enemy_sweep","ember_preview","canopy_sector","rally_link","corpse_tether","hatch","aftershock","brood","canopy","orchard_sweep","orchard_cage","orchard_anchor","lair_phase","lair_open","nursery_rib","nursery_site"]:
  var remaining:=maxf(0,float(event.remaining))
  if not hint.has("total") or remaining>float(hint.total)+.15:hint.total=maxf(.1,remaining)
  var progress:=clampf(1-remaining/float(hint.total),0,1)
  var center:=to if role in ["charge","pounce","vault","burrow","artillery","snare","volley","lure"] else from
  for i in maxi(1,roundi(progress*40)):
   var a: float=-PI*.5+i*TAU/40.;var b: float=a+TAU/40.
   ribbon(mesh,center+Vector3(cos(a),.012,sin(a))*radius*.92,center+Vector3(cos(b),.012,sin(b))*radius*.92,.13)
 mesh.surface_end()
 var material:=hint.mesh.material_override as StandardMaterial3D
 var color:=Color("#96d278") if role in ["chant","shepherd"] else Color("#ff9462")
 if role=="reinforcement":color=Color("#9ce1ff")
 if role=="burrow":color=Color("#e6be83")
 if role=="ember_preview":color=Color("#e5683f")
 if role in ["hatch","canopy_sector","rally_link"]:color=Color("#abd98e")
 if role in ["corpse_tether","trophy_grab"]:color=Color("#eac894")
 if role=="aftershock":color=Color("#f9c675")
 if event.get("field",false):color=Color("#d2a6ee")
 if role=="canopy":color=Color("#8ab58b")
 var cue: String=event.get("cue","")
 if role=="reinforcement":cue="Reinforcements\n%.1fs" % maxf(0,float(event.get("remaining",0)))
 if not cue.is_empty():
  if not hint.has("label"):
   var label:=Label3D.new();hint.root.add_child(label);hint.label=label
   label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font_size=26;label.pixel_size=.008;label.outline_size=10
   label.no_depth_test=true
  hint.label.position=(to+Vector3.UP*1.25) if role=="reinforcement" else (from+Vector3.UP*2.65)
  if role=="canopy" or not hazard.is_empty():hint.label.position=to+Vector3.UP*1.25
  if role in ["orchard_sweep","orchard_cage"]:hint.label.position=to+Vector3.UP*.95
  elif role=="lair_zone":hint.label.position=to+Vector3.UP*1.2
  elif event.has("lair"):hint.label.position=from+Vector3.UP*3.45
  if event.has("label_at"):hint.label.position=point(event.label_at)+Vector3.UP*(4.65 if event.lair=="memory" else 3.65)
  elif role=="lair_phase" and event.get("lair","")=="memory":hint.label.position=from+Vector3.UP*4.85
  hint.label.text=cue
  hint.label.show()
 elif hint.has("label"):hint.label.hide()
 if role=="hazard" and event.get("active",false): color=Color("#d44f45")
 match event.get("lair",""):
  "water":color=Color("#d9f9ff") if event.get("active",false) else Color("#72d1ef")
  "root":color=Color("#e58653") if event.get("active",false) else Color("#f0bd78")
  "fruit":color=Color("#f78c51") if event.get("active",false) else Color("#e8c571")
  "open":color=Color("#c7df8b")
  "nursery":color=Color("#eab284") if event.get("active",false) else Color("#c7bd88")
  "memory":color=Color("#f59cf2") if event.get("active",false) else Color("#b7a7fb")
 if role=="nursery_exit":color=Color("#afc994")
 if not hazard.is_empty():color=Color(hazard.active if event.active else hazard.warning)
 color.a=.8+.12*sin(float(Time.get_ticks_msec())*.012);material.albedo_color=color;material.emission=color
 hint.root.visible=Geometry3D.get_closest_point_to_segment(observer,from,to).distance_to(observer)<=sight+radius
func step(delta: float) -> void:
 feedback.step(delta)
 statuses.step(delta)
 for id in active.keys():
  var effect: Dictionary=active[id];effect.age+=delta
  if effect.age>=float(effect.event.duration): effect.root.queue_free();active.erase(id)
  else: pose(effect)
func _process(delta: float) -> void:
 step(delta)


