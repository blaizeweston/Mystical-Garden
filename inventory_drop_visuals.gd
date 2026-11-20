extends Node

## Owns dropped-item models only. The integration port supplies detached facts.
signal refresh_requested
const Items=preload("res://item_catalog.gd")
var _stage: Node3D
var _facts: Dictionary={}
var models: Dictionary={}
var key: String=""
var elapsed:=0.0

func configure(stage: Node3D) -> void:
 _stage=stage

func present(facts: Dictionary) -> void:
 _facts=facts.duplicate(true)

func _process(delta: float) -> void:
 elapsed+=delta
 if elapsed<.2 or _stage==null: return
 elapsed=0
 refresh_requested.emit()
 if _facts.is_empty():return
 var wild:=bool(_facts.get("wild",false))
 var drops: Array=_facts.get("drops",[])
 var next_key:=str(wild)+str(drops)
 if next_key!=key:
  key=next_key
  for model in models.values(): model.queue_free()
  models.clear()
  for entry in drops:
   var values: Array=entry.position
   var node:=Node3D.new();_stage.add_child(node);node.position=Vector3(values[0],values[1],values[2])+(_stage.WILD_OFFSET if wild else Vector3.ZERO)
   var monster: bool=Items.get_item(str(entry.item)).get("category","")=="monster_part"
   var color: Color=Color("#62baff") if monster else Items.color(str(entry.item))
   var orb: MeshInstance3D=_stage.sphere(Vector3.ZERO,.17,color)
   orb.reparent(node,false);orb.position.y=.25
   var material:=orb.material_override as StandardMaterial3D
   material.emission_enabled=true;material.emission=color;material.emission_energy_multiplier=1.0 if monster else .35
   if monster:
    var ring:=MeshInstance3D.new();node.add_child(ring)
    var torus:=TorusMesh.new();torus.inner_radius=.23;torus.outer_radius=.28;torus.rings=24;torus.ring_segments=8;ring.mesh=torus;ring.position.y=.05;ring.material_override=material
    var beam:=OmniLight3D.new();node.add_child(beam);beam.position.y=.6;beam.light_color=color;beam.light_energy=.5;beam.omni_range=1.4;beam.shadow_enabled=false
   _stage.marker(Vector3(0,.65,0),"%s ×%d"%[Items.get_item(str(entry.item)).name,int(entry.quantity)],node)
   models[entry.id]=node
 for entry in drops:
  if models.has(entry.id):
   var values: Array=entry.position
   models[entry.id].visible=not wild or Vector3(values[0],values[1],values[2]).distance_to(_facts.observer)<=float(_facts.sight_radius)
func _exit_tree() -> void:
 for model in models.values():
  if is_instance_valid(model): model.queue_free()
