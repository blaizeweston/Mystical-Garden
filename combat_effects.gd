extends Node3D
const CoreVisuals = preload("res://core_skill_visuals.gd")
const Ranger = preload("res://ranger_combat.gd")
const EnemyFeedback = preload("res://enemy_move_feedback.gd")
var stage: Node3D
const Contacts = preload("res://contact_particles.gd")
const Delivery = preload("res://weapon_delivery_visuals.gd")
const Affinities = preload("res://affinity_glyphs.gd")
const Payoffs=preload("res://build_payoff_visuals.gd")
var overlap_layout:Dictionary={}
const ClassArt = preload("res://class_release_visuals.gd")
const Astral = preload("res://astral_visuals.gd")
const Shelter = preload("res://shelter_visuals.gd")
const VisualPreferences = preload("res://visual_preferences.gd")
var local_graphics := VisualPreferences.normalize({})
var affinity_art := {}
var affinity_overrides := {}
var motion_overrides := {}
var contact_overrides := {}
const IMPACT_EMISSION := 0.65
var impact_emission := IMPACT_EMISSION
var preview_effects: Array[Dictionary] = []
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

func apply_local_visuals(prefs: Dictionary) -> void:
 local_graphics = prefs
 feedback.damage_numbers = prefs.damage_numbers
 feedback.routine_captions = prefs.captions
 set_affinity_tuning(affinity_art)

func set_affinity_tuning(art:Dictionary) -> void:
 affinity_art=art
 var values:=art.duplicate()
 if local_graphics.spectral != 1.0:
  values["spirit.veil"]=maxf(0.15,float(art.get("spirit.veil",Astral.CONTROLS["spirit.veil"][0]))*float(local_graphics.spectral))
 if values==affinity_overrides:return
 affinity_overrides=values
 statuses.settings=values
 for hint in hints.values():
  if hint.has("astral"):Astral.configure(hint.astral,values)
  for plant in hint.get("plants",[]): Affinities.configure(plant,values)
 for effect in active.values():
  if effect.has("build_payoff"):Payoffs.configure(effect.build_payoff,values)
  if effect.has("class_release"):ClassArt.configure(effect.class_release,values)
  if effect.has("astral"):Astral.configure(effect.astral,values)
  if effect.has("shelter"):Shelter.configure(effect.shelter,values)
  for key in ["petals","mist","payoff"]:
   if effect.has(key):Affinities.configure(effect[key],values)
 for item in statuses.active.values():
  if item.has("astral"):Astral.configure(item.astral,values)
  if item.has("shelter"):Shelter.configure(item.shelter,values)
  if item.has("mark"):Affinities.configure(item.mark,values)

func material(color: Color, emission := IMPACT_EMISSION) -> StandardMaterial3D:
 var result:=StandardMaterial3D.new();result.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;result.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;result.cull_mode=BaseMaterial3D.CULL_DISABLED;result.vertex_color_use_as_albedo=true;result.albedo_color=color;result.emission_enabled=true;result.emission=color;result.emission_energy_multiplier=emission;return result
func visual(color: Color, emission := IMPACT_EMISSION) -> Dictionary:
 var root:=Node3D.new();add_child(root);root.position=stage.WILD_OFFSET
 var mesh:=MeshInstance3D.new();root.add_child(mesh);mesh.mesh=ImmediateMesh.new();mesh.material_override=material(color,emission);mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return {"root":root,"mesh":mesh,"age":0.0}
func sync(events: Array,telegraphs: Array,key: String,world_position: Vector3,radius: float=6.8) -> void:
 if key!=floor_key: clear();floor_key=key
 observer=world_position;sight=radius
 feedback.observer=world_position;feedback.sight=radius
 statuses.observer=world_position;statuses.sight=radius
 for event in events:
  if event.kind=="audio":continue
  if seen.has(event.id): continue
  seen[event.id]=true
  if event.kind in ["status","status_end"]:statuses.consume(event);continue
  if event.kind=="windup":continue
  # Field hints own these visuals. A spent charge already has its resolved discharge.
  if (event.kind=="field" and event.shape=="gravity_well") or (event.kind=="link" and event.shape=="storm_charge"):continue
  if event.kind=="projectile_end":
   var ended:=int(event.shape)
   seen[ended]=true
   if active.has(ended):
    active[ended].root.hide()
    active[ended].root.queue_free()
    active.erase(ended)
   continue
  if event.kind=="field_end":
   var ended:=int(event.shape)
   if active.has(ended): active[ended].root.queue_free();active.erase(ended)
   continue
  if event.kind=="impact" and event.shape=="hit" and int(event.get("amount",0))<=0: continue
  if float(event.get("age",0))>=float(event.duration): continue
  if event.kind=="impact" and event.shape=="heal":
   var at:=point(event.to)
   if at.distance_to(observer)<=sight:feedback.confirmed(event,at)
   if event.get("form","") not in ["water_heal","vital_heal"] or event.get("amount",0)<=0:continue
  var at:=point(event.to)
  var visible_hit:=at.distance_to(observer)<=sight
  if event.kind=="ability" and event.shape=="ember_trail":
   # The field snapshot owns the rooted trail, including when joining mid-cast.
   if visible_hit and not str(event.get("label","")).is_empty():
    feedback.text_at(str(event.label),at,Color("#bcebdd"),int(event.id),true)
   continue
  var family:=Contacts.kind(event)
  if event.kind=="impact" and event.shape!="heal" and visible_hit:
   var flash:=float(contact_overrides.get("impact.flash",Contacts.DEFAULTS["impact.flash"])) if family=="impact" else 1.0
   if event.get("damage_cue")=="storm_arc":flash*=.16
   feedback.confirmed(event,at,0.0 if event.get("damage_cue","") in ["frost_rupture","burn_tick","bleed_tick"] else flash * float(local_graphics.flash))
  # The rupture already supplies the contact visual; its damage receipt still shows HP.
  if event.get("damage_cue","") in ["frost_rupture","burn_tick","bleed_tick","storm_arc"]:continue
  var age:=float(event.get("age",0))
  var effect: Dictionary
  if not family.is_empty():
   if age>=float(contact_overrides.get(family+".lifetime",Contacts.DEFAULTS[family+".lifetime"])):continue
   var strike:=point(event.strike_point) if event.has("strike_point") else at
   effect=Contacts.create(self,family,stage.WILD_OFFSET+strike,strike-point(event.from),event.get("form",""),int(event.id),VisualPreferences.contact(contact_overrides,family,local_graphics),impact_emission,event.has("strike_point"))
  elif Payoffs.accepts(event):
   var root:=Node3D.new()
   add_child(root)
   root.position=stage.WILD_OFFSET
   effect={"root":root,"build_payoff":Payoffs.create(root,event.shape,point(event.from),at,event.reach,affinity_overrides)}
  elif ClassArt.accepts(event):
   var root:=Node3D.new()
   add_child(root)
   root.position=stage.WILD_OFFSET
   effect={"root":root,"class_release":ClassArt.create(root,event.shape,point(event.from),at,event.reach,event,affinity_overrides)}
  elif event.kind in ["link","ability"] and event.shape in Astral.RECEIPTS:
   var root:=Node3D.new()
   add_child(root)
   root.position=stage.WILD_OFFSET
   var start:=point(event.from)
   var path:=at-start
   var body:Dictionary=stage.spectral_body(int(event.combo)) if event.shape in Astral.BODIES else {}
   if not body.is_empty():
    if path.length_squared()>.001:body.yaw=atan2(path.x,path.z)
    body.clip=event.get("clip","")
    if event.shape=="mirrorstep_attack":body.reach=event.reach
   var extent:=float(event.reach)
   if event.shape=="void_pulse" and event.get("form")=="compression":extent=.55
   effect={"root":root,"astral":Astral.create(root,event.shape,start,path,extent,int(event.id),affinity_overrides,event.get("form",""),body)}
  else:
   var art:String=event.shape if event.shape in Shelter.RECEIPTS and event.kind in ["projectile","ability","link"] else ""
   if event.kind=="impact" and event.shape=="heal":art=event.form
   if art=="wood_burst" and event.get("form","")=="wood_spent":art="wood_spent"
   if not art.is_empty():
    var root:=Node3D.new()
    add_child(root)
    root.position=stage.WILD_OFFSET
    var origin:=point(event.from)
    var extent:=float(event.reach)
    if art=="wood_fragment":extent=origin.distance_to(at)
    if event.kind=="impact":extent=.55
    effect={"root":root,"shelter":Shelter.create(root,art,origin,extent,at-origin,int(event.id),affinity_overrides),"art":art}
   else:
    effect=visual(Color(event.color), impact_emission if event.kind=="impact" else IMPACT_EMISSION)
   if event.kind=="ability" and event.shape in ["frost_open","frost_close"]:
    var phase: String="open" if event.shape=="frost_open" else "close"
    effect.petals=Affinities.create(effect.root,phase,at,Vector2.ONE*float(event.reach),0.,0,affinity_overrides)
    effect.mesh.hide()
   elif event.kind=="ability" and event.shape in ["flashover","wildfire","hemorrhagic_rupture"]:
    # The existing area cue owns the real radius. This burst stays at the source.
    effect.payoff=Affinities.create(effect.root,event.shape,at+Vector3.UP*.35,Vector2.ONE*.56,0.,int(event.id),affinity_overrides)
  effect.event=event
  effect.age=age
  if event.kind=="proc" and visible_hit:
   var display_name: String={"mark_break":"Mark triggered","core_mark_burst":"Core Mark burst","shatter":"Shatter!","suppress":"Interrupted","echo":"Echo","link":"Linked hit","chorus":"Chorus","counter":"Counter!","brace":"Braced","momentum":"Death charge","pierce":"Pierced","punish":"Wind-up punished","siphon":"Life restored"}.get(str(event.shape),str(event.shape).capitalize())
   feedback.proc_caption(display_name,at,Color(event.color),int(event.id),motion_overrides.get("text.detail",Delivery.CONTROLS["text.detail"][0])>0)
  if event.kind=="enemy_release" and visible_hit:
   if event.shape=="pulled":feedback.text_at("Pulled",point(event.to),Color(event.color),int(event.id),true,3.45)
   elif event.shape=="restored" and int(event.reach)>0:feedback.text_at("+%d"%int(event.reach),point(event.to),Color(event.color),int(event.id))
   elif event.shape=="trophy":feedback.text_at("Trophy stolen",point(event.to),Color(event.color),int(event.id),true)
  var phase_caption: bool=event.shape in ["harvest_spend","rift_shear","wraithcast","frost_close","ironbark","vital_bloom","wood_splinters","riptide_return","tidal_ring_return"] and motion_overrides.get("text.detail",Delivery.CONTROLS["text.detail"][0])==0
  if event.kind=="ability" and visible_hit and not phase_caption and not str(event.get("label",event.shape)).is_empty():
   if event.shape=="shatterwave":
    feedback.proc_caption("Shatterwave",at,Color("#d1e7ef"),int(event.id),motion_overrides.get("text.detail",0)>0,16.)
   elif event.shape in ["tidal_ring","riptide"]:
    feedback.proc_caption(str(event.get("label",event.shape)),at,Color("#bcebdd"),int(event.id),motion_overrides.get("text.detail",Delivery.CONTROLS["text.detail"][0])>0)
   elif family!="rupture" or contact_overrides.get("rupture.repeat_labels",0)>0 or not feedback.recent_rupture_near(at):
    feedback.text_at(str(event.get("label",event.shape)),at,Color("#bcebdd"),int(event.id),true)
    if family=="rupture":feedback.labels.back().rupture_at=at
  if event.kind=="subclass_release" and visible_hit and not str(event.get("label","")).is_empty():
   feedback.text_at(event.label,point(event.to),Color(event.color),int(event.id),true)
  if event.kind=="field" and event.shape not in [Ranger.CORRIDOR,Ranger.ESCAPE]:
   var species: String={"growth_zone":"whispervine","tide_zone":"tide_lily","decoy_zone":"dream_poppy","luring_snare_zone":"dream_poppy"}.get(str(event.shape),"whispervine")
   var plant_index: int=preload("res://seed_catalog.gd").index_of(species)
   if plant_index>=0:
    var growth: Node3D=stage.build_crop(plant_index,2,false)
    growth.reparent(effect.root,false);growth.position=point(event.to);effect.growth=growth
  if event.kind=="projectile" and not effect.has("shelter"): mount_projectile_glyph(effect,event)
  if active.size()>=80:
   var old=active.keys()[0];active[old].root.queue_free();active.erase(old)
  active[event.id]=effect
  pose(effect)
 while seen.size()>2048:seen.erase(seen.keys()[0])
 var layout:Dictionary={}
 var keep: Array=[]
 for warning in telegraphs:
  if warning.role in ["memory_growth","glasscap_feint"]:continue
  keep.append(warning.id)
  if not hints.has(warning.id): hints[warning.id]=visual(Color("#ffa766"))
  var hint: Dictionary=hints[warning.id];hint.event=warning;draw_hint(hint)
  if hint.has("astral"):layout[warning.id]=hint.astral.position
 for id in hints.keys():
  if not keep.has(id): hints[id].root.queue_free();hints.erase(id)
 if layout!=overlap_layout:
  Payoffs.assign_overlaps(hints,layout)
  overlap_layout=layout
## Presentation only. These IDs live outside the replicated event sequence.
func preview_skill_impact(skill: Dictionary, from: Vector3, to: Vector3, wild: bool, emission: float, form: String, values: Dictionary) -> void:
 for previous in preview_effects: previous.root.queue_free()
 preview_effects.clear()
 for kind in ["ability","impact"]:
  var color := Color(skill.color)
  var offset: Vector3=stage.WILD_OFFSET if wild else Vector3.ZERO
  var effect: Dictionary
  if kind=="impact":
   effect=Contacts.create(self,"impact",offset+to,to-from,form,17,values,emission)
  else:
   effect=visual(color)
   effect.root.position=offset
  effect.event={"id":-1,"kind":kind,"shape":skill.mode if kind=="ability" else "hit","duration":effect.get("life",.8),"from":[from.x,from.y,from.z],"to":[to.x,to.y,to.z],"reach":maxf(.8,skill.get("radius",1.2)),"color":color}
  effect.preview=true
  preview_effects.append(effect)
  pose(effect)
func clear() -> void:
 for preview in preview_effects: preview.root.queue_free()
 preview_effects.clear()
 for collection in [active,hints]:
  for effect in collection.values(): effect.root.queue_free()
  collection.clear()
 overlap_layout.clear()
 seen.clear()
 feedback.clear()
 statuses.clear()
func point(values: Array) -> Vector3:
 return Vector3(values[0],values[1],values[2])
func ribbon(mesh: ImmediateMesh,a: Vector3,b: Vector3,width: float) -> void:
 var side: Vector3=(b-a).cross(Vector3.UP).normalized()*width*.5
 if side.length_squared()<.00001: side=Vector3.RIGHT*width*.5
 for vertex in [a-side,a+side,b+side,a-side,b+side,b-side]: mesh.surface_add_vertex(vertex)
func mount_projectile_glyph(effect: Dictionary,event: Dictionary) -> void:
 if event.get("form","")==event.shape and event.shape in ["orb","ring"]:
  var held_scale := preload("res://plant_polearms.gd").SCALE if event.has("weapon_release") else 0.0
  var model:=preload("res://plant_weapon_models.gd").in_flight(event.shape,float(event.projectile_radius),held_scale)
  effect.root.add_child(model)
  effect.glyph=model
 elif event.shape in ["spell","needle","orb","ring"]:
  var glyph:=MeshInstance3D.new();effect.root.add_child(glyph)
  if event.shape=="ring":
   var ring:=TorusMesh.new();ring.inner_radius=.14;ring.outer_radius=.22;ring.rings=12;ring.ring_segments=8;glyph.mesh=ring
  else:
   var sphere:=SphereMesh.new();sphere.radius=float(event.get("projectile_radius",.1));sphere.height=sphere.radius*2;sphere.radial_segments=8;sphere.rings=4;glyph.mesh=sphere
  glyph.material_override=material(Color(event.color));glyph.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;effect.glyph=glyph

func circle(mesh: ImmediateMesh,center: Vector3,radius: float,width: float=.06) -> void:
 for i in 40:
  var first:=i*TAU/40.0;var second:=(i+1)*TAU/40.0
  ribbon(mesh,center+Vector3(cos(first),0,sin(first))*radius,center+Vector3(cos(second),0,sin(second))*radius,width)
func pose(effect: Dictionary) -> void:
 var event: Dictionary=effect.event
 if effect.has("class_release") or effect.has("build_payoff"):
  var start:=point(event.from)
  var end:=point(event.to)
  var nearest:=start if start.is_equal_approx(end) else Geometry3D.get_closest_point_to_segment(observer,start,end)
  effect.root.visible=nearest.distance_to(observer)<=sight+float(event.reach)
  if effect.has("build_payoff"):Payoffs.seek(effect.build_payoff,effect.age,event.duration)
  else:ClassArt.seek(effect.class_release,effect.age,event.duration)
  return
 if effect.has("astral"):
  var start:=point(event.from)
  var end:=point(event.to)
  var near:=start if start.is_equal_approx(end) else Geometry3D.get_closest_point_to_segment(observer,start,end)
  var present:bool=event.shape not in Astral.BODIES or stage.avatar_models.get(int(event.combo),{}).get("living_in_wilds",false)
  effect.root.visible=present and near.distance_to(observer)<=sight+float(event.reach)
  if effect.root.visible and event.shape in ["storm_arc","storm_burst"]:
   # Clip the original filaments in glyph space. A hidden contact has no visible spark, even at the edge.
   var offset:=observer-start
   var surface:ShaderMaterial=effect.astral.material_override
   surface.set_shader_parameter("storm_sight",Vector3(offset.x,offset.z,sight))
   surface.set_shader_parameter("show_contact",end.distance_to(observer)<=sight)
  Astral.seek(effect.astral,effect.age,event.duration)
  return
 if effect.has("shelter"):
  var start:=point(event.from)
  var end:=point(event.to)
  var travel:bool=effect.art in Shelter.TRAVEL
  var age:float=effect.age+int(event.get("core_phase",0))*.001
  var progress:=clampf(age/float(event.duration),0.,1.)
  effect.shelter.position=start.lerp(end,progress) if travel else start
  if effect.art=="wood_fragment":effect.shelter.position=end
  var center:Vector3=effect.shelter.position
  if effect.art in ["riptide","riptide_return","tidal_ring","tidal_ring_return"] and not stage.avatar_models.get(int(event.combo),{}).get("living_in_wilds",false):
   effect.root.hide()
   return
  effect.root.visible=progress<1. and center.distance_to(observer)<=sight+(float(event.reach) if effect.art not in ["water_heal","vital_heal"] else .5)
  Shelter.seek(effect.shelter,age,event.duration)
  return
 if effect.has("payoff"):Affinities.seek(effect.payoff,effect.age,float(event.duration)-float(effect.age))
 if effect.has("petals"):
  Affinities.seek(effect.petals,effect.age,float(event.duration)-float(effect.age))
  effect.root.visible=point(event.to).distance_to(observer)<=sight+float(event.reach)
  return
 if effect.has("family"):
  Contacts.pose(effect,effect.age)
  effect.root.visible=effect.has("preview") or point(event.to).distance_to(observer)<=sight
  return
 if event.kind=="projectile" and event.has("weapon_release") and not effect.has("visual_from"):
  var origin: Vector3=stage.weapon_release_point(event)
  if not origin.is_finite():effect.root.visible=false;return
  effect.visual_from=origin-stage.WILD_OFFSET
  effect.visual_to=point(event.to)+Vector3.UP*float(event.get("height",1.05))
 var mesh: ImmediateMesh=effect.mesh.mesh;mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 var t:=clampf(float(effect.age)/float(event.duration),0,1)
 var from:=point(event.from);var to:=point(event.to)
 if event.kind=="swing" and event.has("owner"):
  if not effect.has("frozen_from"):
   var owner_context: Node3D=stage.avatars.get(int(event.owner))
   if is_instance_valid(owner_context):
    var shift: Vector3=owner_context.position-stage.WILD_OFFSET-from;from+=shift;to+=shift
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
  Delivery.projectile(self,mesh,effect,from,to,t,motion_overrides.get("projectile.tail",Delivery.CONTROLS["projectile.tail"][0]))
 elif event.kind=="dodge":
  Delivery.foot_scuff(mesh,from,to,t,motion_overrides.get("dodge.dust",Delivery.CONTROLS["dodge.dust"][0]))
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
  var family:=preload("res://combat_feedback.gd").family(str(event.shape));var reach:=clampf(float(event.reach),.8,8)
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
  var lash:=preload("res://weapon_contact.gd").lash_path(shape,from,to)
  if not lash.is_empty():
   var polygon:=PackedVector2Array()
   for vertex in outline:polygon.append(Vector2(vertex.x,vertex.z))
   for i in Geometry2D.triangulate_polygon(polygon):mesh.surface_add_vertex(outline[i]+Vector3.UP*.09)
  else:
   for i in outline.size():
    for vertex in [center,outline[i],outline[(i+1)%outline.size()]]:mesh.surface_add_vertex(vertex+Vector3.UP*.09)
  mesh.surface_set_color(Color(1,1,1,.53))
  for i in outline.size():ribbon(mesh,outline[i]+Vector3.UP*.10,outline[(i+1)%outline.size()]+Vector3.UP*.10,.045)
  if not lash.is_empty():
   for i in range(1,lash.size()):ribbon(mesh,lash[i-1]+Vector3.UP*.10,lash[i]+Vector3.UP*.10,.035)
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
 if event.kind=="dodge":color.a=1.
 if event.kind=="impact":
  color=Color("#fff2ce") if event.shape!="hurt" else Color("#ff957d")
  # Compatibility draws this unshaded material from albedo. Keep its original
  # appearance at the production emission and show experimental energy changes.
  if not is_equal_approx(surface.emission_energy_multiplier,IMPACT_EMISSION):
   var intensity: float=(1.0+surface.emission_energy_multiplier)/(1.0+IMPACT_EMISSION)
   color=Color(color.r*intensity,color.g*intensity,color.b*intensity)
  color.a=(1-clampf(float(effect.age)/.2,0,1))*.95
 if event.kind=="swing" and event.has("pattern"):
  var contact:=float(event.get("contact",.42));var band:=.12
  color.a*=smoothstep(contact-band,contact,t)*(1-smoothstep(contact,contact+.26,t))
 surface.albedo_color=color
 effect.root.visible=effect.has("preview") or Geometry3D.get_closest_point_to_segment(observer,from,to).distance_to(observer)<=sight
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
 if event.role=="spirit_image" or (event.role=="core_field" and event.get("skill")=="gravity_well"):
  if not hint.has("astral"):
   var art:String="singularity" if event.get("form")=="singularity" else event.skill
   var body:Dictionary=stage.spectral_body(int(event.owner)) if event.role=="spirit_image" else {}
   if event.role=="spirit_image" and body.is_empty():return
   body.yaw=event.get("yaw",0.)
   hint.astral=Astral.create(hint.root,art,point(event.from),Vector3.ZERO,event.radius,str(event.id).hash(),affinity_overrides,event.get("form",""),body)
  hint.phase_anchor=maxf(0.,event.get("core_phase",0)*.001)
  hint.ttl_anchor=float(event.remaining)
  hint.age=clampf(hint.age,hint.phase_anchor,hint.phase_anchor+.10)
  hint.root.visible=point(event.from).distance_to(observer)<=sight+float(event.radius)
  Astral.seek(hint.astral,hint.age,hint.phase_anchor+hint.ttl_anchor)
  return
 if event.role=="core_field" and event.get("skill","") in ["ember_wake","thorn_line"] and not event.get("core_shapes",[]).is_empty():
  if not hint.has("plants"):
   hint.plants=[]
   var boundary:ImmediateMesh=hint.mesh.mesh
   boundary.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
   for shape in event.core_shapes:
    hint.plants.append(Affinities.field(hint.root,event.skill,shape,str(event.id).hash(),affinity_overrides))
    CoreVisuals.outline(self,boundary,shape,.027)
   boundary.surface_end()
   var edge:StandardMaterial3D=hint.mesh.material_override
   edge.albedo_color=Color(event.color,.34)
   edge.emission_enabled=false
  # Interpolate briefly between snapshots. An unchanged or paused field keeps its phase.
  hint.phase_anchor=maxf(0.,event.get("core_phase",0)*.001)
  hint.ttl_anchor=float(event.remaining)
  hint.age=clampf(hint.age,hint.phase_anchor,hint.phase_anchor+.10)
  hint.left=clampf(hint.get("left",hint.ttl_anchor),maxf(0.,hint.ttl_anchor-.10),hint.ttl_anchor)
  hint.root.visible=point(event.to).distance_to(observer)<=sight+float(event.radius)
  for plant in hint.plants: Affinities.seek(plant,hint.age,hint.left)
  return
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
  var motion_step:=fposmod(Time.get_ticks_msec()*.002,1.0)
  for index in 3:
   var tip:=from.lerp(to,(index+motion_step)/3.0)+Vector3.UP*.24
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
   var remaining_distance:=float(event.remaining)
   if not hint.has("total"):hint.total=maxf(.1,remaining_distance)
   CoreVisuals.draw(self,mesh,event,to,1.0-clampf(remaining_distance/float(hint.total),0,1),true)
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
   var motion_step:=from+ray*float(index)*.45
   ribbon(mesh,motion_step+side,motion_step+side+ray*.23,.025)
   ribbon(mesh,motion_step-side,motion_step-side+ray*.23,.025)
   if index%3==0:
    var star:=motion_step+Vector3.UP*.17
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
  Delivery.danger_marks(self,mesh,from,forward,span_value,radius,5)
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
  if role in ["artillery","snare","stomp","swipe"]: Delivery.danger_marks(self,mesh,center,Vector3.FORWARD,TAU,radius,10)
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
 var effect_material:=hint.mesh.material_override as StandardMaterial3D
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
 color.a=.8+.12*sin(float(Time.get_ticks_msec())*.012);effect_material.albedo_color=color;effect_material.emission=color
 hint.root.visible=Geometry3D.get_closest_point_to_segment(observer,from,to).distance_to(observer)<=sight+radius
func step(delta: float) -> void:
 for i in range(preview_effects.size()-1,-1,-1):
  var effect: Dictionary=preview_effects[i]
  effect.age+=delta
  if effect.age>=float(effect.event.duration): effect.root.queue_free();preview_effects.remove_at(i)
  else: pose(effect)
 feedback.step(delta)
 statuses.step(delta)
 for hint in hints.values():
  if hint.has("astral") and hint.root.visible:
   hint.age=minf(hint.phase_anchor+.10,float(hint.age)+delta)
   Astral.seek(hint.astral,hint.age,hint.phase_anchor+hint.ttl_anchor)
  if hint.has("plants") and hint.root.visible:
   hint.age=minf(hint.phase_anchor+.10,float(hint.age)+delta)
   hint.left=maxf(maxf(0.,hint.ttl_anchor-.10),float(hint.left)-delta)
   for plant in hint.plants: Affinities.seek(plant,hint.age,hint.left)
 for id in active.keys():
  var effect: Dictionary=active[id];effect.age+=delta
  if effect.age>=float(effect.get("life",effect.event.duration)): effect.root.queue_free();active.erase(id)
  else: pose(effect)
func _process(delta: float) -> void:
 step(delta)


