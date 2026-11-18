extends Node

const Participation = preload("res://expedition_participation.gd")
# Presentation only. The host commits research; each viewer acknowledges their own scene.
const Service=preload("res://garden_growth_service.gd")
const Layout=preload("res://garden_layout.gd")
const DURATION:=8.8
var game: Node
var force_playback:=false
var event: Dictionary={}
var elapsed:=0.0
var target:=Vector3.ZERO
var tip:=Vector3.ZERO
var layer: CanvasLayer
var curtain: Control
var caption: Label
var root_mesh: MeshInstance3D
var glow: MeshInstance3D
var restored: Dictionary={}
var waiting_sequence:=-1
var retry:=0.0
var mesh_step:=-1
var hud_layers: Dictionary={}
var world_labels: Dictionary={}
var source_context:=""
func context() -> String:
 return str(game.network_session.role()=="Guest")+":"+str(game.local_player_id())
func _ready() -> void:
 layer=CanvasLayer.new();layer.layer=40;add_child(layer)
 curtain=Control.new();curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);curtain.mouse_filter=Control.MOUSE_FILTER_STOP;layer.add_child(curtain);curtain.hide()
 for bottom in [false,true]:
  var bar:=ColorRect.new();curtain.add_child(bar);bar.color=Color(0.025,.035,.025,.88);bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
  bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE);bar.offset_top=-72 if bottom else 0;bar.offset_bottom=0 if bottom else 46
 caption=Label.new();curtain.add_child(caption);caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);caption.offset_top=-65;caption.offset_bottom=-15;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.add_theme_font_size_override("font_size",23);caption.modulate=Color("#e4dab5")
 var skip:=Button.new();curtain.add_child(skip);skip.text="Skip · Esc";skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);skip.offset_left=-140;skip.offset_right=-18;skip.offset_top=7;skip.offset_bottom=39;skip.pressed.connect(func():finish(true))
 root_mesh=MeshInstance3D.new();root_mesh.name="GrowingGardenRoot";game.stage.add_child(root_mesh);root_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root_mesh.material_override=preload("res://garden_scenery.gd").root_material();root_mesh.hide()
 glow=MeshInstance3D.new();game.stage.add_child(glow);var seed:=SphereMesh.new();seed.radius=.11;seed.height=.22;glow.mesh=seed
 var light:=StandardMaterial3D.new();light.albedo_color=Color("#d7e7ae");light.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;light.no_depth_test=true;light.emission_enabled=true;light.emission=Color("#a4cd8e");light.emission_energy_multiplier=2.5;glow.material_override=light;glow.hide()
func destination(value: Dictionary) -> Vector3:
 match value.get("kind",""):
  "zone":return Layout.zone(str(value.get("zone",""))).get("reveal",{}).get("position",game.Stage.HEART)
  "return":return Layout.Catalog.point(str(value.get("point",""))).get("position",game.Stage.HEART)
  "bed":return game.Stage.PLOTS[clampi(int(value.get("slot",0)),0,game.Stage.PLOTS.size()-1)]
  "spring":
   for point in Layout.Catalog.POINTS:
    if point.parent==value.get("zone") and point.get("visual","")=="spring":return point.position
   return Layout.zone(str(value.get("zone",""))).get("water",{}).get("position",game.Stage.HEART)
  "station":return game.Stage.HEART_STATIONS.get(str(value.get("station","")),game.Stage.HEART)
  "clearing":return Vector3(-game.stage.garden_extent*.72,0,2.0)
 return game.Stage.HEART
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
  var end:=destination(value);var amount:=forming if not event.is_empty() and value.sequence==event.sequence else 0.0
  if value.get("kind")=="clearing":
   remember(game.stage.garden_disc)
   var radius:=11.5+lerpf(float(value.get("from_level",0)),float(value.get("to_level",0)),smoothstep(0,1,amount))*1.05
   game.stage.garden_disc.scale=Vector3(radius,1,radius)
  for model in game.stage.garden_edge.get_children()+game.stage.garden_beds.get_children():
   var route: bool=model.has_meta("garden_route_target") and model.get_meta("garden_route_target").distance_to(end)<.25
   var bed: bool=value.get("kind")=="bed" and model.has_meta("garden_plot_position") and model.get_meta("garden_plot_position").distance_to(end)<.25
   var water: bool=value.get("kind")=="spring" and model.has_meta("garden_water_position") and model.get_meta("garden_water_position").distance_to(Layout.zone(str(value.get("zone",""))).get("water",{}).get("position",Vector3.INF))<.25
   if route or bed or water:
    remember(model);model.visible=amount>0.001
    if bed or water:model.scale=Vector3.ONE*maxf(.001,smoothstep(0,1,amount))
  if value.get("kind")=="station" and game.stage.heart_stations.has(value.get("station")):
   var station: Node3D=game.stage.heart_stations[value.station];remember(station);station.visible=amount>.001;station.scale=Vector3.ONE*maxf(.001,amount)
  if value.get("kind") in ["spring","zone"]:
   if amount<.6:hidden_zones.append(value.zone)
   for point in Layout.Catalog.POINTS:
    if point.parent!=value.zone:continue
    var model: Node3D=get_parent().points[point.id];remember(model);model.visible=model.visible and amount>.6
 game.stage.set_meta("garden_growth_hidden_zones",hidden_zones)
func begin(value: Dictionary) -> void:
 event=value.duplicate(true);elapsed=0;mesh_step=-1;target=destination(event);tip=game.Stage.HEART;source_context=context()
 game.set_meta("garden_cinematic_active",true);curtain.show();root_mesh.show();glow.show()
 preload("res://event_audio.gd").play_research(game,value)
 var growth_range:=preload("res://heart_growth_visuals.gd").counts(event,Service.projection(game,game.local_player_id()).get("pending",[]),game.stage.heart_unlocked)
 preload("res://heart_growth_visuals.gd").animate(game.stage,growth_range,0)
 for child in game.get_children():
  if child is CanvasLayer:hud_layers[child]=child.visible;child.hide()
 for label in game.stage.find_children("*","Label3D",true,false):world_labels[label]=label.visible
 preload("res://diagnostic_journal.gd").event("garden","growth_scene_started",{"technology":event.get("technology",""),"sequence":event.sequence,"kind":event.kind})
func animate(time: float) -> void:
 elapsed=time
 var travel:=clampf((time-1.5)/4.0,0,1);var form:=clampf((time-5.5)/1.6,0,1);var returning:=smoothstep(7.2,DURATION,time)
 tip=root_point(game.Stage.HEART,target,travel)
 var home: Vector3=game.Stage.garden_camera_target(game.players.get(game.local_player_id(),{}).get("pos",game.Stage.SPAWN),game.stage.garden_extent)
 var growth_model=preload("res://heart_growth_visuals.gd")
 var growth_range: Vector2i=growth_model.counts(event,Service.projection(game,game.local_player_id()).get("pending",[]),game.stage.heart_unlocked)
 growth_model.animate(game.stage,growth_range,clampf(time/1.5,0,1))
 var heart_focus: Vector3=game.Stage.HEART+Vector3.UP*growth_model.height(lerpf(growth_range.x,growth_range.y,clampf(time/1.5,0,1)))*.38
 var tracked: Vector3=heart_focus.lerp(tip,smoothstep(1.0,1.6,time))
 game.stage.set_meta("garden_growth_camera",{"target":tracked.lerp(home,returning),"size":lerpf(10.0,16.5,returning)})
 game.stage.set_meta("garden_growth_phase",int(event.get("from_phase",0)) if time<1.0 else int(event.get("to_phase",0)))
 if is_instance_valid(game.stage.heart_tree):
  var beat:=sin(clampf(time/1.5,0,1)*PI)*.12
  game.stage.heart_tree.scale=Vector3.ONE*game.stage.heart_size*(1.0+beat)
 caption.text=str(event.get("name","The Garden grows"))+" · "+("The Heart stirs" if time<1.5 else "Roots reach outward" if time<5.5 else ("A returning light takes root" if event.get("kind","")=="return" else "New ground takes shape"))
 root_mesh.visible=travel>0.001;glow.visible=travel>0.001 and form<1;glow.position=tip+Vector3.UP*.09;glow.scale=Vector3.ONE*(1.0+sin(time*7)*.12)
 var step:=int(travel*120)
 if travel>0.001 and step!=mesh_step:
  mesh_step=step
  var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  for strand in 3:
   var points: Array[Vector3]=[];var side: Vector3=(target-game.Stage.HEART).normalized().cross(Vector3.UP)
   for index in 49:
    var t:=travel*index/48.0;points.append(root_point(game.Stage.HEART,target,t)+side*sin(t*6.5+strand*2.1)*.06*(1-t))
   game.stage.root_tube(surface,points,.105-strand*.026,.007)
  root_mesh.mesh=surface.commit()
 var data:=Service.projection(game,game.local_player_id());conceal(data.get("pending",[]),form)
 for label in game.stage.find_children("*","Label3D",true,false):
  if not world_labels.has(label):world_labels[label]=label.visible
  label.hide()
func restore_interface() -> void:
 for hud in hud_layers:
  if is_instance_valid(hud):hud.visible=hud_layers[hud]
 for label in world_labels:
  if is_instance_valid(label):label.visible=world_labels[label]
 hud_layers.clear();world_labels.clear()
func finish(acknowledge: bool) -> void:
 if event.is_empty():return
 var growth_model=preload("res://heart_growth_visuals.gd")
 var settled: int=growth_model.counts(event,Service.projection(game,game.local_player_id()).get("pending",[]),game.stage.heart_unlocked).y
 growth_model.hold(game.stage,settled)
 var sequence:=int(event.sequence);event={};restore_visuals();restore_interface();curtain.hide();root_mesh.hide();glow.hide()
 game.set_meta("garden_cinematic_active",false)
 for key in ["garden_growth_camera","garden_growth_phase","garden_growth_hidden_zones"]:game.stage.remove_meta(key)
 if acknowledge:
  waiting_sequence=sequence;retry=1;game.send_garden_action("growth_ack:"+str(sequence))
 preload("res://diagnostic_journal.gd").event("garden","growth_scene_finished",{"sequence":sequence,"acknowledged":acknowledge})
func _input(input: InputEvent) -> void:
 if not event.is_empty() and input.is_action_pressed("session_menu"):
  finish(true);get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
 if DisplayServer.get_name()=="headless" and not force_playback:return
 if game.persistence_session.is_blocked():
  if not event.is_empty():finish(false)
  return
 var id: int=game.local_player_id();var player: Dictionary=game.players.get(id,{})
 if player.is_empty():
  if not event.is_empty():finish(false)
  return
 var data:=Service.projection(game,id);var pending: Array=data.get("pending",[])
 var safe: bool=not Participation.is_wild(player) and data.get("ready",false) and game.network_session.role()!="Connecting"
 if not event.is_empty():
  if not safe or source_context!=context():finish(false);return
  animate(elapsed+delta)
  if elapsed>=DURATION:finish(true)
  return
 if not safe or pending.is_empty():
  restore_visuals();game.stage.remove_meta("garden_growth_phase");game.stage.remove_meta("garden_growth_hidden_zones");preload("res://heart_growth_visuals.gd").clear(game.stage);return
 if waiting_sequence==int(pending[0].sequence):
  retry-=delta
  if retry<=0:retry=1;game.send_garden_action("growth_ack:"+str(waiting_sequence))
  return
 waiting_sequence=-1
 if game.has_meta(&"experimental_terrain") or not game.app_settings.values.get("garden_cinematics",true) or not game.app_settings.values.get("ambient_motion",true):
  preload("res://event_audio.gd").play_research(game,pending[0])
  waiting_sequence=int(pending[0].sequence);retry=1;game.send_garden_action("growth_ack:"+str(waiting_sequence));return
 preload("res://heart_growth_visuals.gd").hold(game.stage,preload("res://heart_growth_visuals.gd").counts(pending[0],pending,game.stage.heart_unlocked).x)
 game.stage.set_meta("garden_growth_phase",int(pending[0].get("from_phase",0)));conceal(pending)
 if not game.ui.is_overlay_open() and not game.settings_dialog.visible:begin(pending[0])
func _exit_tree() -> void:
 restore_visuals();restore_interface()
 if is_instance_valid(game):game.set_meta("garden_cinematic_active",false)
 if is_instance_valid(game.stage):
  for key in ["garden_growth_camera","garden_growth_phase","garden_growth_hidden_zones","garden_growth_heart"]:game.stage.remove_meta(key)
 if is_instance_valid(root_mesh):root_mesh.queue_free()
 if is_instance_valid(glow):glow.queue_free()
