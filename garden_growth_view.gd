extends Node

# Presentation only. The host commits research; each viewer acknowledges their own scene.
const Stage=preload("res://stage.gd")
const Layout=preload("res://garden_layout.gd")
const DURATION:=8.8
const FORM_START_SECONDS:=5.5
const FORM_DURATION_SECONDS:=1.6
const ACK_RETRY_SECONDS:=1.0
signal refresh_requested
signal interfaces_requested
signal requested(command: String, data: Dictionary)
var _stage: Node3D
var _points: Dictionary={}
var _facts: Dictionary={}
var _interface_layers: Array[CanvasLayer]=[]
var force_playback:=false
var _event: Dictionary={}
## Detached inspection; no caller receives writable playback state.
var event: Dictionary:
 get: return _event.duplicate(true)
var elapsed: float:
 get: return _elapsed
var _elapsed:=0.0
var target:=Vector3.ZERO
var tip:=Vector3.ZERO
var layer: CanvasLayer
var curtain: Control
var caption: Label
var root_mesh: MeshInstance3D
var glow: MeshInstance3D
var restored: Dictionary={}
var _waiting_sequence:=-1
var _retry:=0.0
var mesh_step:=-1
var hud_layers: Dictionary={}
var world_labels: Dictionary={}
var _source_context:=""
## Only presentation nodes cross this boundary; never Game or mutable actors.
func configure(stage: Node3D, points: Dictionary) -> void:
 _stage=stage;_points=points.duplicate()
func present(facts: Dictionary) -> void:
 _facts=facts.duplicate(true)
func capture_interfaces(layers: Array) -> void:
 _interface_layers.assign(layers)
func is_active() -> bool:
 return not _event.is_empty()
func discovery_progress(discovery: String) -> float:
 return clampf((_elapsed-FORM_START_SECONDS)/FORM_DURATION_SECONDS,0,1) if _event.get("discovery","")==discovery else 0.0
func context() -> String:
 return str(_facts.get("context",""))
func _ready() -> void:
 layer=CanvasLayer.new();layer.layer=40;add_child(layer)
 curtain=Control.new();curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);curtain.mouse_filter=Control.MOUSE_FILTER_STOP;layer.add_child(curtain);curtain.hide()
 for bottom in [false,true]:
  var bar:=ColorRect.new();curtain.add_child(bar);bar.color=Color(0.025,.035,.025,.88);bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
  bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE);bar.offset_top=-72 if bottom else 0;bar.offset_bottom=0 if bottom else 46
 caption=Label.new();curtain.add_child(caption);caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);caption.offset_top=-65;caption.offset_bottom=-15;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.add_theme_font_size_override("font_size",23);caption.modulate=Color("#e4dab5")
 var skip:=Button.new();curtain.add_child(skip);skip.text="Skip · Esc";skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);skip.offset_left=-140;skip.offset_right=-18;skip.offset_top=7;skip.offset_bottom=39;skip.pressed.connect(func():finish(true))
 root_mesh=MeshInstance3D.new();root_mesh.name="GrowingGardenRoot";_stage.add_child(root_mesh);root_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root_mesh.material_override=preload("res://garden_scenery.gd").root_material();root_mesh.hide()
 glow=MeshInstance3D.new();_stage.add_child(glow);var seed:=SphereMesh.new();seed.radius=.11;seed.height=.22;glow.mesh=seed
 var light:=StandardMaterial3D.new();light.albedo_color=Color("#d7e7ae");light.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;light.no_depth_test=true;light.emission_enabled=true;light.emission=Color("#a4cd8e");light.emission_energy_multiplier=2.5;glow.material_override=light;glow.hide()
func destination(value: Dictionary) -> Vector3:
 match value.get("kind",""):
  "zone":return Layout.zone(str(value.get("zone",""))).get("reveal",{}).get("position",Stage.HEART)
  "return":return Layout.Catalog.point(str(value.get("point",""))).get("position",Stage.HEART)
  "bed":return finite_destination(_stage.bed_position(int(value.get("slot",0))))
  "spring":
   for point in Layout.Catalog.POINTS:
    if point.parent==value.get("zone") and point.get("visual","")=="spring":return point.position
   return Layout.zone(str(value.get("zone",""))).get("water",{}).get("position",Stage.HEART)
  "station":return finite_destination(_stage.station_position(str(value.get("station",""))))
  "clearing":return Vector3(-_stage.garden_extent*.72,0,2.0)
 return Stage.HEART
static func root_point(origin: Vector3,end: Vector3,t: float) -> Vector3:
 var point:=origin.lerp(end,t);point.x+=sin(t*TAU)*.23;point.y=.055
 return point
func remember(model: Node3D) -> void:
 if not restored.has(model):restored[model]={"visible":model.visible,"scale":model.scale}
func restore_visuals() -> void:
 for model in restored:
  if is_instance_valid(model):model.visible=restored[model].visible;model.scale=restored[model].scale
 restored.clear()
func conceal(pending: Array,forming: float=0.0) -> void:
 restore_visuals()
 var hidden_zones: Array=[]
 for value in pending:
  var end:=destination(value);var amount:=forming if not _event.is_empty() and value.sequence==_event.sequence else 0.0
  for model in _stage.garden_edge.get_children()+_stage.garden_beds.get_children():
   var route: bool=model.has_meta("garden_route_target") and model.get_meta("garden_route_target").distance_to(end)<.25
   var bed: bool=value.get("kind")=="bed" and model.has_meta("garden_plot_position") and model.get_meta("garden_plot_position").distance_to(end)<.25
   var water: bool=value.get("kind")=="spring" and model.has_meta("garden_water_position") and model.get_meta("garden_water_position").distance_to(Layout.zone(str(value.get("zone",""))).get("water",{}).get("position",Vector3.INF))<.25
   if route or bed or water:
    remember(model);model.visible=amount>0.001
    if bed or water:model.scale=Vector3.ONE*maxf(.001,smoothstep(0,1,amount))
  if value.get("kind")=="station" and _stage.heart_stations.has(value.get("station")):
   var station: Node3D=_stage.heart_stations[value.station];remember(station);station.visible=amount>.001;station.scale=Vector3.ONE*maxf(.001,amount)
  if value.get("kind") in ["spring","zone"]:
   if amount<.6:hidden_zones.append(value.zone)
   for point in Layout.Catalog.POINTS:
    if point.parent!=value.zone:continue
    var model: Node3D=_points[point.id];remember(model);model.visible=model.visible and amount>.6
 _stage.set_meta("garden_growth_hidden_zones",hidden_zones)
func begin(value: Dictionary) -> void:
 refresh_requested.emit()
 _event=value.duplicate(true);_elapsed=0;mesh_step=-1;target=destination(_event);tip=Stage.HEART;_source_context=context()
 curtain.show();root_mesh.show();glow.show()
 requested.emit("research_audio",value.duplicate(true))
 var growth_range:=preload("res://heart_growth_visuals.gd").counts(_event,_facts.get("pending",[]),_stage.heart_unlocked)
 preload("res://heart_growth_visuals.gd").animate(_stage,growth_range,0)
 interfaces_requested.emit()
 for child in _interface_layers:
  if is_instance_valid(child):hud_layers[child]=child.visible;child.hide()
 for label in _stage.find_children("*","Label3D",true,false):world_labels[label]=label.visible
 preload("res://diagnostic_journal.gd").event("garden","growth_scene_started",{"technology":_event.get("technology",""),"sequence":_event.sequence,"kind":_event.kind})
func animate(time: float) -> void:
 _elapsed=time
 var travel:=clampf((time-1.5)/4.0,0,1);var form:=clampf((time-FORM_START_SECONDS)/FORM_DURATION_SECONDS,0,1);var returning:=smoothstep(7.2,DURATION,time)
 tip=root_point(Stage.HEART,target,travel)
 var home: Vector3=Stage.garden_camera_target(_facts.get("player_position",Stage.SPAWN),_stage.garden_extent)
 var growth_model=preload("res://heart_growth_visuals.gd")
 var growth_range: Vector2i=growth_model.counts(_event,_facts.get("pending",[]),_stage.heart_unlocked)
 growth_model.animate(_stage,growth_range,clampf(time/1.5,0,1))
 var heart_focus: Vector3=Stage.HEART+Vector3.UP*growth_model.height(lerpf(growth_range.x,growth_range.y,clampf(time/1.5,0,1)))*.38
 var tracked: Vector3=heart_focus.lerp(tip,smoothstep(1.0,1.6,time))
 _stage.set_meta("garden_growth_camera",{"target":tracked.lerp(home,returning),"size":lerpf(10.0,16.5,returning)})
 _stage.set_meta("garden_growth_phase",int(_event.get("from_phase",0)) if time<1.0 else int(_event.get("to_phase",0)))
 if is_instance_valid(_stage.heart_tree):
  var beat:=sin(clampf(time/1.5,0,1)*PI)*.12
  _stage.heart_tree.scale=Vector3.ONE*_stage.heart_size*(1.0+beat)
 caption.text=str(_event.get("name","The Garden grows"))+" · "+("The Heart stirs" if time<1.5 else "Roots reach outward" if time<FORM_START_SECONDS else ("A returning light takes root" if _event.get("kind","")=="return" else "New ground takes shape"))
 root_mesh.visible=travel>0.001;glow.visible=travel>0.001 and form<1;glow.position=tip+Vector3.UP*.09;glow.scale=Vector3.ONE*(1.0+sin(time*7)*.12)
 var step:=int(travel*120)
 if travel>0.001 and step!=mesh_step:
  mesh_step=step
  var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  for strand in 3:
   var points: Array[Vector3]=[];var side: Vector3=(target-Stage.HEART).normalized().cross(Vector3.UP)
   for index in 49:
    var t:=travel*index/48.0;points.append(root_point(Stage.HEART,target,t)+side*sin(t*6.5+strand*2.1)*.06*(1-t))
   _stage.root_tube(surface,points,.105-strand*.026,.007)
  root_mesh.mesh=surface.commit()
 conceal(_facts.get("pending",[]),form)
 for label in _stage.find_children("*","Label3D",true,false):
  if not world_labels.has(label):world_labels[label]=label.visible
  label.hide()
func restore_interface() -> void:
 for hud in hud_layers:
  if is_instance_valid(hud):hud.visible=hud_layers[hud]
 for label in world_labels:
  if is_instance_valid(label):label.visible=world_labels[label]
 hud_layers.clear();world_labels.clear()
func finish(acknowledge: bool) -> void:
 if _event.is_empty():return
 refresh_requested.emit()
 var growth_model=preload("res://heart_growth_visuals.gd")
 var settled: int=growth_model.counts(_event,_facts.get("pending",[]),_stage.heart_unlocked).y
 growth_model.hold(_stage,settled)
 var sequence:=int(_event.sequence);_event={};restore_visuals();restore_interface();curtain.hide();root_mesh.hide();glow.hide()
 for key in ["garden_growth_camera","garden_growth_phase","garden_growth_hidden_zones"]:_stage.remove_meta(key)
 if acknowledge:
  _waiting_sequence=sequence;_retry=ACK_RETRY_SECONDS;requested.emit("garden_action",{"action":"growth_ack:"+str(sequence)})
 preload("res://diagnostic_journal.gd").event("garden","growth_scene_finished",{"sequence":sequence,"acknowledged":acknowledge})
func _input(input: InputEvent) -> void:
 if not _event.is_empty() and input.is_action_pressed("session_menu"):
  finish(true);get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
 if DisplayServer.get_name()=="headless" and not force_playback:return
 refresh_requested.emit()
 if bool(_facts.get("blocked",false)):
  if not _event.is_empty():finish(false)
  return
 if not bool(_facts.get("player_present",false)):
  if not _event.is_empty():finish(false)
  return
 var pending: Array=_facts.get("pending",[])
 var safe: bool=_facts.get("safe",false)
 if not _event.is_empty():
  if not safe or _source_context!=context():finish(false);return
  animate(_elapsed+delta)
  if _elapsed>=DURATION:finish(true)
  return
 if not safe or pending.is_empty():
  restore_visuals();_stage.remove_meta("garden_growth_phase");_stage.remove_meta("garden_growth_hidden_zones");preload("res://heart_growth_visuals.gd").clear(_stage);return
 if _waiting_sequence==int(pending[0].sequence):
  _retry-=delta
  if _retry<=0:_retry=ACK_RETRY_SECONDS;requested.emit("garden_action",{"action":"growth_ack:"+str(_waiting_sequence)})
  return
 _waiting_sequence=-1
 if bool(_facts.get("skip_playback",false)):
  requested.emit("research_audio",pending[0].duplicate(true))
  _waiting_sequence=int(pending[0].sequence);_retry=ACK_RETRY_SECONDS;requested.emit("garden_action",{"action":"growth_ack:"+str(_waiting_sequence)});return
 preload("res://heart_growth_visuals.gd").hold(_stage,preload("res://heart_growth_visuals.gd").counts(pending[0],pending,_stage.heart_unlocked).x)
 _stage.set_meta("garden_growth_phase",int(pending[0].get("from_phase",0)));conceal(pending)
 if bool(_facts.get("can_start",false)):begin(pending[0])
func _exit_tree() -> void:
 restore_visuals();restore_interface()
 _event.clear()
 if is_instance_valid(_stage):
  for key in ["garden_growth_camera","garden_growth_phase","garden_growth_hidden_zones","garden_growth_heart"]:_stage.remove_meta(key)
 if is_instance_valid(root_mesh):root_mesh.queue_free()
 if is_instance_valid(glow):glow.queue_free()

func finite_destination(position: Vector3) -> Vector3:
 return position if position.is_finite() else Stage.HEART
