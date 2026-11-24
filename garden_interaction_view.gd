extends Node

# Read-only rendering and intent submission. Never mutates Garden progression.
const Catalog=preload("res://garden_interaction_catalog.gd")
signal refresh_requested(kind: String, selection: Dictionary)
signal interfaces_requested
signal requested(command: String, data: Dictionary)
var _stage: Node3D
var _ui: CanvasLayer
var _facts: Dictionary={}
func configure(stage: Node3D, ui: CanvasLayer) -> void:
 _stage=stage;_ui=ui
func present_feature(kind: String, facts: Dictionary) -> void:
 match kind:
  "interaction":_facts=facts.duplicate(true)
  "crop":get_node("Crops").present(facts)
  "station":station_controls.present(facts)
  "return":get_node("ReturnLife").present(facts)
  "ambience":get_node("Ambience").present(facts)
  "cinematic":get_node("GrowthScenes").present(facts)
func refresh_feature(kind: String, selection: Dictionary={}) -> void:
 if kind=="return":selection={"context":projection_context}
 refresh_requested.emit(kind,selection)
func capture_interfaces(layers: Array) -> void:
 get_node("GrowthScenes").capture_interfaces(layers)
func flower_shortcut() -> void:
 get_node("Crops").flower_shortcut()
var panel: PanelContainer
var title: Label
var description: Label
var journal: Label
var observe: Button
var station_panel: PanelContainer
var station_controls: Control
var points: Dictionary={}
var selected: String=""
var focus_serial:=-1
var cue_revision:=-1
var cue_until:=0
var pending:=false
var requested_at:=0
var projection_context:=""
var availability_baseline:=false
var structure_revision:=-1
func _ready() -> void:
 panel=_ui.create_overlay_panel(Color("#14262b"),Vector2(22,20));panel.set_meta("garden_interaction_panel",true);panel.hide()
 var box:=VBoxContainer.new();box.custom_minimum_size=Vector2(470,260);box.add_theme_constant_override("separation",14);panel.add_child(box)
 title=Label.new();title.add_theme_font_size_override("font_size",23);box.add_child(title)
 description=Label.new();description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.custom_minimum_size=Vector2(470,80);box.add_child(description)
 observe=Button.new();observe.text="Record observation";box.add_child(observe);observe.pressed.connect(record)
 station_panel=_ui.create_overlay_panel(Color("#14262b"),Vector2(22,20))
 station_panel.set_meta("garden_interaction_panel",true);station_panel.hide()
 station_controls=preload("res://garden_care_panel.gd").new()
 station_controls.configure(_ui)
 station_controls.refresh_requested.connect(func(station: String):refresh_feature("station",{"station":station}))
 station_controls.requested.connect(requested.emit)
 station_panel.add_child(station_controls)
 journal=Label.new();journal.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;journal.custom_minimum_size=Vector2(470,80);box.add_child(journal)
 var close:=Button.new();close.text="Close · Esc";box.add_child(close);close.pressed.connect(func():_ui.close_panels())
 for definition in Catalog.POINTS:points[definition.id]=build_point(definition)
 var scenes=preload("res://garden_growth_view.gd").new()
 scenes.name="GrowthScenes";scenes.configure(_stage,points)
 scenes.refresh_requested.connect(func():refresh_feature("cinematic"))
 scenes.interfaces_requested.connect(interfaces_requested.emit)
 scenes.requested.connect(requested.emit)
 add_child(scenes)
 _ui.bind_cinematic(scenes)
 var crops=preload("res://garden_crop_view.gd").new();crops.configure(_stage,_ui);crops.name="Crops"
 crops.refresh_requested.connect(func():refresh_feature("crop"));crops.requested.connect(requested.emit);add_child(crops)
 var returns=preload("res://garden_return_view.gd").new();returns.configure(_stage,points,scenes);returns.name="ReturnLife"
 returns.refresh_requested.connect(func():refresh_feature("return"));add_child(returns)
 var ambience=preload("res://garden_ambience.gd").new();ambience.configure(_stage);ambience.name="Ambience"
 ambience.refresh_requested.connect(func():refresh_feature("ambience"));add_child(ambience)
func build_point(definition: Dictionary) -> Node3D:
 var root:=Node3D.new();root.name=definition.id;_stage.add_child(root);root.position=definition.position;root.visible=false
 var roots:=MeshInstance3D.new();roots.name="Roots";root.add_child(roots);roots.mesh=_point_mesh(definition)
 var bark:=ShaderMaterial.new();bark.shader=preload("res://assets/shaders/root_bark.gdshader");roots.material_override=bark
 var scar:=MeshInstance3D.new();scar.name="Scar";root.add_child(scar)
 var shape:=SphereMesh.new();shape.radius=.13;shape.height=.32;shape.radial_segments=24;shape.rings=12;scar.mesh=shape;scar.position=Vector3(0,.23,0);scar.scale=Vector3(1,.7,.52)
 var material:=StandardMaterial3D.new();material.albedo_color=Color("#bbd1a0");material.emission_enabled=true;material.emission=Color("#93bda0");material.emission_energy_multiplier=.3;material.roughness=.8;scar.material_override=material
 var label:=Label3D.new();label.name="Hint";root.add_child(label);label.position.y=1.6;label.text=definition.name;label.font_size=28;label.pixel_size=.007;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.modulate=Color("#d2dec0");label.visible=false
 return root
func record() -> void:
 if selected.is_empty() or pending:return
 refresh_feature("interaction")
 var data: Dictionary=_facts.get("data",{})
 pending=true;requested_at=Time.get_ticks_msec();observe.disabled=true
 var request: Dictionary={"point":selected,"action":"observe","revision":int(data.get("revision",0)),"request":Crypto.new().generate_random_bytes(12).hex_encode()}
 requested.emit("garden_action",{"action":"garden:"+JSON.stringify(request)})
func _process(_delta: float) -> void:
 if not is_instance_valid(_stage):return
 refresh_feature("interaction")
 var current_revision: int=int(_facts.get("structure_revision",-1))
 if current_revision!=structure_revision:
  structure_revision=current_revision
  for definition in Catalog.POINTS:
   if definition.get("visual","")=="relationship":points[definition.id].get_node("Roots").mesh=_point_mesh(definition)
 if _facts.is_empty():return
 var data: Dictionary=_facts.get("data",{});var wild: bool=_facts.get("wild",false)
 var context: String=_facts.get("context","")
 if context!=projection_context:
  projection_context=context;cue_revision=-1;cue_until=0;focus_serial=-1;pending=false;availability_baseline=false
 var nearest: String=_facts.get("nearest","")
 var revision:=int(data.get("revision",0))
 # Establish a baseline on join. Snapshots restore state without replaying cues.
 if data.get("version",0)==1:
  if cue_revision<0:cue_revision=revision
  elif revision>cue_revision:cue_revision=revision;cue_until=Time.get_ticks_msec()+1800
 for point_id in points:
  var model: Node3D=points[point_id]
  var available: bool=data.get("version",0)==1 and data.get("available",[]).has(point_id)
  if available and point_id=="spring_water" and _facts.get("development",false):
   model.position=_facts.point_positions[point_id]
  if available and not model.get_meta("available",false) and availability_baseline:model.set_meta("reveal_at",Time.get_ticks_msec())
  model.set_meta("available",available);model.visible=not wild and available
  var reveal:=clampf((Time.get_ticks_msec()-int(model.get_meta("reveal_at",-10000)))/1100.0,0,1)
  model.scale=Vector3.ONE*lerpf(.10,1.0,reveal*reveal*(3-2*reveal)) if _facts.get("motion",true) else Vector3.ONE
  model.get_node("Hint").visible=nearest==point_id and not _ui.is_overlay_open() and _facts.get("position",Vector3.INF).distance_to(model.position)>1.0
  var scar: MeshInstance3D=model.get_node("Scar")
  var pulse:=.20+.12*(.5+.5*sin(Time.get_ticks_msec()/700.0))
  if Time.get_ticks_msec()<cue_until and data.get("latest",{}).get("point","")==point_id:pulse+=.9
  scar.material_override.emission_energy_multiplier=pulse
 if data.get("version",0)==1:availability_baseline=true
 if wild or not _facts.get("present",false):
  if panel.visible or station_panel.visible:_ui.close_panels()
  return
 var focus: Dictionary=data.get("focus",{})
 if int(focus.get("serial",0))!=focus_serial:
  focus_serial=int(focus.get("serial",0))
  var target: String=str(focus.get("point",""))
  if _facts.get("near_stations",[]).has(target):
   station_controls.open(target)
   if not station_panel.visible:_ui.toggle_external(station_panel)
  var definition:=Catalog.point(target)
  if not definition.is_empty() and nearest==definition.id:
   selected=definition.id;pending=false
   if not panel.visible:_ui.toggle_external(panel)
 if station_panel.visible:
  if not _facts.get("near_stations",[]).has(station_controls.station):_ui.close_panels()
  else:station_controls.refresh()
 if panel.visible and _ui.is_overlay_open():
  var definition:=Catalog.point(selected)
  if definition.is_empty():_ui.close_panels();return
  var recorded: bool=data.get("observations",[]).has(definition.observation)
  if recorded or Time.get_ticks_msec()-requested_at>1500:pending=false
  title.text=definition.name;description.text=definition.description
  var return_note:=preload("res://garden_return_service.gd").note(data.get("returns",{}),selected)
  if not return_note.is_empty():description.text+="\n\n"+return_note
  observe.text="Recorded in this Garden" if recorded else "Recording…" if pending else "Record observation"
  observe.disabled=recorded or pending or nearest!=selected
  var clue: String=data.get("clues",{}).get(definition.observation,"") if recorded else ""
  journal.text=(definition.recorded if recorded else definition.hint)+("\n\n"+clue if not clue.is_empty() else "")+"\n\nGarden observations · %d recorded"%data.get("observations",[]).size()
func context_prompt() -> String:
 var crop_prompt: String=get_node("Crops").context_prompt()
 refresh_feature("interaction")
 var station: String=_facts.get("nearest_station","")
 if not station.is_empty() and not _ui.is_overlay_open():
  return "%s  Use %s"%[preload("res://app_settings.gd").hint("interact"),station_controls.label(station)]
 var data: Dictionary=_facts.get("data",{})
 var point_id: String=_facts.get("nearest","")
 if not point_id.is_empty() and not _ui.is_overlay_open():
  var action: String="Inspect "+Catalog.point(point_id).name
  if point_id=="spring_water" and not data.get("cultivation",{}).get("spring_water",false):
   action="Fill watering vessel"
  return "%s  %s"%[preload("res://app_settings.gd").hint("interact"),action]
 return crop_prompt
func _exit_tree() -> void:
 for point in points.values():
  if is_instance_valid(point):point.queue_free()

func _point_mesh(definition: Dictionary) -> ArrayMesh:
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for branch in 5:
  var path: Array[Vector3]=[];var angle:=branch*TAU/5
  for step in 25:
   var t:=step/24.0;var radius:=lerpf(.63,.12,t)
   path.append(Vector3(cos(angle+t*.8)*radius,.025+sin(t*PI*.85)*.25,sin(angle+t*.8)*radius))
  _stage.root_tube(surface,path,.045,.012)
 if definition.get("visual","")=="relationship":
  for index in preload("res://garden_layout.gd").zone_beds(definition.relationship.zone,_stage.bed_positions().size()):
   var path: Array[Vector3]=[]
   var bed: Vector3=_stage.bed_position(index)
   if not bed.is_finite():continue
   var end: Vector3=bed-definition.position
   for step in 25:
    var t:=step/24.0;path.append(end*t+Vector3(sin(t*PI*3)*.10,.04+sin(t*PI)*.05,0))
   _stage.root_tube(surface,path,.045,.006)
 return surface.commit()
