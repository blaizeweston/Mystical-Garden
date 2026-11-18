extends Node

const Participation = preload("res://expedition_participation.gd")
# A read-only crop inspector and cosmetic bud; all commands use the Garden route.
const Service=preload("res://garden_crop_service.gd")
const Catalog=preload("res://garden_crop_catalog.gd")
const Growth=preload("res://cultivation_growth.gd")
var game: Node
var panel: PanelContainer
var title: Label
var description: Label
var outcome: Label
var preserve: Button
var leave: Button
var flower: Button
var water: Button
var quick_water: Button
var harvest: Button
var icon: TextureRect
var markers: Dictionary={}
var slot:=-1
var serial:=-1
var context:=""
var waiting_until:=0
var last_request:=""
var last_bed: Dictionary={}
var wet_marks: Dictionary={}
var water_seen: Dictionary={}
func _ready() -> void:
 panel=game.ui.create_overlay_panel(Color("#14262b"),Vector2(24,20));panel.set_meta("garden_interaction_panel",true);panel.hide()
 var box:=VBoxContainer.new();box.custom_minimum_size=Vector2(570,350);box.add_theme_constant_override("separation",14);panel.add_child(box)
 title=Label.new();title.add_theme_font_size_override("font_size",23);box.add_child(title)
 var row:=HBoxContainer.new();box.add_child(row)
 icon=TextureRect.new();icon.custom_minimum_size=Vector2(64,64);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(icon)
 description=Label.new();description.custom_minimum_size=Vector2(490,85);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;row.add_child(description)
 outcome=Label.new();outcome.custom_minimum_size=Vector2(570,100);outcome.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(outcome)
 preserve=button(box,"Preserve the bud · more time, richer harvest","preserve_bud")
 leave=button(box,"Let it grow normally","leave_bud")
 water=button(box,"Water from the spring · 25% faster until harvest","water_crop")
 flower=button(box,"Harvest 2 seeds instead of parts","flower_crop")
 harvest=button(box,"Harvest crafting parts","harvest_crop")
 quick_water=Button.new()
 quick_water.text="Water plant"
 quick_water.tooltip_text="Use one vessel of spring water for 25% faster growth."
 quick_water.focus_mode=Control.FOCUS_NONE
 game.ui.mount_prompt_control(quick_water)
 quick_water.hide()
 quick_water.pressed.connect(water_nearby)
 var close:=Button.new();close.text="Close · Esc";box.add_child(close);close.pressed.connect(func():game.ui.close_panels())
func button(parent: Node,text: String,action: String) -> Button:
 var result:=Button.new();result.text=text;parent.add_child(result);result.pressed.connect(func():submit(action));return result
static func request(bed: Dictionary,action: String) -> Dictionary:
 return {"point":"bed_%d"%(int(bed.slot)+1),"action":action,"cycle":bed.cycle,"revision":int(bed.revision),"stage":int(bed.stage),"request":Crypto.new().generate_random_bytes(12).hex_encode()}
static func flower_shortcut(owner_game: Node) -> void:
 var player: Dictionary=owner_game.players.get(owner_game.local_player_id(),{});var nearby: int=owner_game.nearby_plot(player.get("pos",Vector3.INF))
 for bed in Service.projection(owner_game,owner_game.local_player_id()).get("beds",[]):
  if int(bed.slot)==nearby and bed.get("compatible",false):owner_game.send_garden_action("garden:"+JSON.stringify(request(bed,"flower_crop")));return
func submit(action: String) -> void:
 if last_bed.is_empty() or Time.get_ticks_msec()<waiting_until:return
 last_request=action;waiting_until=Time.get_ticks_msec()+1200
 game.send_garden_action("garden:"+JSON.stringify(request(last_bed,action)))
func marker(index: int) -> Node3D:
 var root:=Node3D.new();root.name="CropBud%d"%index;game.stage.add_child(root);root.position=game.stage.bed_position(index)+Vector3(.28,.72,.08)
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);var path: Array[Vector3]=[]
 for step in 17:
  var t:=step/16.0;path.append(Vector3(-.12*sin(t*PI),-.45+t*.40,0))
 game.stage.root_tube(surface,path,.028,.012)
 var stem:=MeshInstance3D.new();root.add_child(stem);stem.mesh=surface.commit();var bark:=ShaderMaterial.new();bark.shader=preload("res://assets/shaders/root_bark.gdshader");stem.material_override=bark
 for petal in 5:
  var bud:=MeshInstance3D.new();root.add_child(bud);var shape:=SphereMesh.new();shape.radius=.095;shape.height=.27;shape.radial_segments=16;shape.rings=8;bud.mesh=shape
  var angle:=petal*TAU/5;bud.position=Vector3(cos(angle)*.038,0,sin(angle)*.038);bud.rotation=Vector3(sin(angle)*.25,angle,cos(angle)*.25)
  var material:=StandardMaterial3D.new();material.albedo_color=Color("#d1c493");material.emission_enabled=true;material.emission=Color("#98af76");material.emission_energy_multiplier=.3;material.roughness=.65;bud.material_override=material
 return root
func _process(_delta: float) -> void:
 var id: int=game.local_player_id();var p: Dictionary=game.players.get(id,{})
 var data:=Service.projection(game,id);var outer: Dictionary=get_parent().Service.projection(game,id)
 var next_context:=str([game.network_session.role(),id,outer.get("epoch","")])
 if next_context!=context:
  context=next_context;serial=-1;slot=-1;waiting_until=0;last_bed={};water_seen.clear()
  if panel.visible:game.ui.close_panels()
 var valid: bool=data.get("version",0)==2 and data.get("catalog","")==Catalog.signature
 var beds: Array=data.get("beds",[]) if valid else []
 var present: Array=[]
 for bed in beds:
  var index:=int(bed.slot);present.append(index)
  update_water(bed,p)
  var visible: bool=not Participation.is_wild(p) and (bed.get("available",false) or bed.get("preserved",false)) and p.get("pos",Vector3.INF).distance_to(game.stage.bed_position(index))<14 and not game.get_meta("garden_cinematic_active",false)
  if visible and not markers.has(index):markers[index]=marker(index)
  if markers.has(index):
   var model: Node3D=markers[index];model.visible=visible
   if game.has_meta(&"experimental_terrain"):model.position=game.stage.bed_position(index)+Vector3(.28,.72,.08)
   var pulse:=1.0+.045*sin(Time.get_ticks_msec()/650.0) if game.app_settings.values.get("ambient_motion",true) else 1.0
   model.scale=Vector3.ONE*pulse*(1.0 if bed.get("preserved",false) else .78)
 for index in markers:
  if not present.has(index):markers[index].hide()
 for index in wet_marks:
  if not present.has(index):wet_marks[index].hide();water_seen.erase(index)
 if p.is_empty() or Participation.is_wild(p) or not valid:
  if panel.visible:game.ui.close_panels()
  return
 var focus: Dictionary=data.get("focus",{})
 if int(focus.get("serial",0))!=serial:
  serial=int(focus.get("serial",0));slot=int(focus.get("slot",-1))
  if slot>=0 and not game.ui.is_overlay_open():game.ui.toggle_external(panel)
 if not panel.visible:return
 var matching: Array=beds.filter(func(b):return int(b.slot)==slot)
 if matching.is_empty() or p.pos.distance_to(game.stage.bed_position(slot))>1.85:
  game.ui.close_panels();return
 var bed: Dictionary=matching[0]
 if bed.get("revision",0)!=last_bed.get("revision",-1) or bed.get("stage",0)!=last_bed.get("stage",0):waiting_until=0
 last_bed=bed.duplicate(true)
 var definition: Dictionary=game.Seeds.DEFINITIONS[int(bed.species)]
 title.text="%s · BED %d"%[definition.name,slot+1]
 icon.texture=load("res://assets/ui/seeds/"+str(definition.id)+".png")
 var policy:=Catalog.definition(str(bed.get("opportunity","")))
 description.text="%s · %s\n%s"%[["Seed","Sprout","Young plant","Ready to harvest"][int(bed.stage)],"Harvest parts or seeds when mature",str(policy.get("description","This crop grows at its normal pace.")) if bed.get("available",false) else "Ready to harvest." if int(bed.stage)==3 else "A preserved bud is developing." if bed.get("preserved",false) else "Growing."]
 outcome.text="Ready now · choose parts or seeds." if int(bed.stage)==3 else "Harvest in %s · %.2f× growth."%[Growth.time_text(float(bed.remaining)),float(bed.get("growth_rate",1))]
 if int(bed.stage)<3:outcome.text+="\nGarden: %s · Wilds: %s (2× growth)."%[Growth.time_text(float(bed.garden_remaining)),Growth.time_text(float(bed.wild_remaining))]
 outcome.text+="\nHarvest: 1 %s (shared). Rare %s: %d%% chance."%[game.Parts.part_name(int(definition.part)),game.Parts.part_name(game.Parts.rare_part(int(bed.species))),roundi(float(bed.chance)*100)]
 if bed.get("available",false):outcome.text+="\nPreserve: %s longer; rare-part chance rises from %d%% to %d%%."%[Growth.time_text(float(bed.extra_seconds)),roundi(float(bed.base_chance)*100),roundi(float(bed.preserve_chance)*100)]
 elif bed.get("preserved",false):outcome.text+="\nHarvesting seeds forfeits the rare-part bonus."
 if bed.get("watered",false):outcome.text+="\nWatered · 25% faster for this crop."
 elif not bed.get("spring_ready",false):outcome.text+="\nUnlock the sheltered spring to water crops."
 if bed.get("flower_enabled",false):outcome.text+="\nSeed harvest · 2 seeds instead of parts."
 var pending:=Time.get_ticks_msec()<waiting_until
 preserve.visible=bed.get("available",false);leave.visible=preserve.visible;preserve.disabled=pending;leave.disabled=pending
 var has_water: bool=data.get("spring_water",false)
 water.visible=bed.get("water_available",false);water.disabled=pending or not has_water
 water.text="Water crop · 25% faster until harvest" if has_water else "Fill your watering vessel at the sheltered spring"
 flower.visible=bed.get("compatible",false) and bed.get("flower_enabled",false);flower.disabled=pending or int(bed.stage)<3
 flower.text="Harvest 2 seeds instead of parts" if int(bed.stage)==3 else "Seed harvest · available when mature"
 harvest.visible=int(bed.stage)==3;harvest.disabled=pending
func nearby_crop(player: Dictionary,data: Dictionary) -> Dictionary:
 if player.is_empty() or Participation.is_wild(player) or game.ui.is_overlay_open() or game.get_meta("garden_cinematic_active",false):
  return {}
 var nearby: int=game.nearby_plot(player.get("pos",Vector3.INF))
 for bed in data.get("beds",[]):
  if int(bed.slot)==nearby and int(bed.stage)<3:return bed
 return {}
func water_nearby() -> void:
 var id: int=game.local_player_id()
 var data:=Service.projection(game,id)
 var bed:=nearby_crop(game.players.get(id,{}),data)
 if not data.get("spring_water",false) or not bed.get("water_available",false):return
 game.send_garden_action("garden:"+JSON.stringify(request(bed,"water_crop")))
func context_prompt(player: Dictionary) -> String:
 var data:=Service.projection(game,game.local_player_id())
 var bed:=nearby_crop(player,data)
 quick_water.visible=data.get("spring_water",false) and bed.get("water_available",false)
 if bed.is_empty():return ""
 return "%s  Inspect %s%s"%[preload("res://app_settings.gd").hint("interact"),game.Seeds.NAMES[int(bed.species)]," · unusual bud" if bed.get("available",false) else " · bud preserved" if bed.get("preserved",false) else ""]
func update_water(bed: Dictionary,player: Dictionary) -> void:
 var index:=int(bed.slot);var wet: bool=bed.get("watered",false)
 var before: Dictionary=water_seen.get(index,{})
 if wet and not wet_marks.has(index):
  var root:=Node3D.new();root.name="WateredBed%d"%index;game.stage.add_child(root);root.position=game.stage.bed_position(index)
  var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);var points: Array[Vector3]=[]
  for step in 49:
   var angle:=step*TAU/48;points.append(Vector3(cos(angle)*.83,.071,sin(angle)*.83))
  game.stage.root_tube(surface,points,.025,.025)
  var soil:=MeshInstance3D.new();root.add_child(soil);soil.mesh=surface.commit();var damp:=StandardMaterial3D.new();damp.albedo_color=Color("#264037");damp.roughness=.5;soil.material_override=damp
  for drop in 5:
   var model:=MeshInstance3D.new();model.name="Drop%d"%drop;root.add_child(model);var shape:=SphereMesh.new();shape.radius=.025;shape.height=.075;model.mesh=shape;model.hide()
   var water_material:=StandardMaterial3D.new();water_material.albedo_color=Color("#8dc9d5");water_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;model.material_override=water_material
  wet_marks[index]=root
 if wet_marks.has(index):
  var root: Node3D=wet_marks[index]
  if game.has_meta(&"experimental_terrain"):root.position=game.stage.bed_position(index)
  if wet and not before.is_empty() and before.get("cycle")==bed.cycle and not before.get("watered",false):root.set_meta("splash_at",Time.get_ticks_msec())
  root.visible=wet and not Participation.is_wild(player) and not game.get_meta("garden_cinematic_active",false) and player.get("pos",Vector3.INF).distance_to(root.position)<14
  var time:=float(Time.get_ticks_msec()-int(root.get_meta("splash_at",-10000)))/900.0
  for drop in 5:
   var model: MeshInstance3D=root.get_node("Drop%d"%drop);model.visible=time>=0 and time<1 and game.app_settings.values.get("ambient_motion",true)
   var angle:=drop*TAU/5;model.position=Vector3(cos(angle)*.5,.85-time*.72,sin(angle)*.5);model.scale=Vector3.ONE*clampf(1-time,0,1)
 water_seen[index]={"cycle":bed.cycle,"watered":wet}
func _exit_tree() -> void:
 for model in markers.values():
  if is_instance_valid(model):model.queue_free()
 for model in wet_marks.values():
  if is_instance_valid(model):model.queue_free()
