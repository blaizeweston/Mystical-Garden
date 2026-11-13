extends Node
const Policy=preload("res://garden_conduit.gd")
var game: Node
var info: Label
var choices: Array[Button]=[]
var channels: MeshInstance3D
func _ready() -> void:
 var view=get_parent();var root: Node3D=view.points[Policy.POINT]
 # A low, broken retaining ring. Nothing here blocks a bed or the approach.
 for index in 13:
  var stone:=MeshInstance3D.new();root.add_child(stone);stone.mesh=SphereMesh.new()
  stone.mesh.radius=.23;stone.mesh.height=.30;stone.mesh.radial_segments=12;stone.mesh.rings=6
  var angle:=.15+index*PI/11;stone.position=Vector3(cos(angle)*1.0,.02,sin(angle)*.8);stone.scale=Vector3(1.2,.5+fmod(index*.37,.4),.65);stone.rotation.y=angle
  var material:=StandardMaterial3D.new();material.albedo_color=Color("#787767");material.roughness=.97;stone.material_override=material
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for strand in 3:
  var path: Array[Vector3]=[]
  for index in 33:
   var t:=index/32.0;path.append(Vector3((t-.5)*1.5,.055,sin(t*PI*2+strand)*.16+(strand-1)*.13))
  game.stage.root_tube(surface,path,.025,.008)
 channels=MeshInstance3D.new();root.add_child(channels);channels.mesh=surface.commit()
 var sap:=StandardMaterial3D.new();sap.emission_enabled=true;sap.emission_energy_multiplier=.25;sap.roughness=.7;channels.material_override=sap
 var box: VBoxContainer=view.panel.get_child(0)
 info=Label.new();info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(info);box.move_child(info,box.get_child_count()-2)
 var row:=HBoxContainer.new();box.add_child(row);box.move_child(row,box.get_child_count()-2)
 for entry in Policy.MODES:
  var button:=Button.new();button.text=entry.name;row.add_child(button);choices.append(button)
  button.pressed.connect(func():
   var data:=Policy.projection(game,game.local_player_id())
   game.send_garden_action("garden:"+JSON.stringify({"point":Policy.POINT,"action":"configure_conduit","request":Crypto.new().generate_random_bytes(8).hex_encode(),"revision":data.get("revision",-1),"mode":entry.id})))
func _process(_delta: float) -> void:
 var data:=Policy.projection(game,game.local_player_id());var entry:=Policy.mode(str(data.get("mode","")))
 var active: bool=data.get("unlocked",false) and not entry.is_empty()
 channels.visible=active
 if active:channels.material_override.albedo_color=entry.color;channels.material_override.emission=entry.color
 var inspecting: bool=get_parent().panel.visible and get_parent().selected==Policy.POINT
 info.visible=inspecting
 choices[0].get_parent().visible=inspecting and active
 if not inspecting:return
 var lines: Array[String]=[]
 for setting in Policy.MODES:
  var policy:=preload("res://garden_crop_catalog.gd").definition(setting.policy)
  lines.append("%s: +%d%% growing time, +%d rare-chance points (cap %d%%)."%[setting.name,roundi(policy.delay_fraction*100),roundi(policy.rare_bonus*100),roundi(policy.rare_cap*100)])
 var beds: String=", ".join(Policy.Layout.zone(Policy.ZONE).beds.map(func(id):return str(id).replace("bed_","Bed ")))
 info.text="Research the Living Water Conduit at the Heart." if not active else "Current: %s · %s · new plantings only.\n%s\n%s"%[entry.name,beds,"\n".join(lines),"The host controls the flow." if not data.get("host",false) else "Free to switch. Applies to new crops."]
 for index in choices.size():choices[index].disabled=not data.get("host",false) or data.get("mode","")==Policy.MODES[index].id
