extends Node
var game: Node
var models: Dictionary={}
var key: String=""
var elapsed:=0.0
func _process(delta: float) -> void:
 elapsed+=delta
 if elapsed<.2 or game==null: return
 elapsed=0
 var player: Dictionary=game.players.get(game.local_player_id(),{})
 if player.is_empty(): return
 var drops: Array=game.inventory_floor_snapshot(player) if game.multiplayer.is_server() else player.get("ground_items",[])
 var next_key:=str(player.get("wild",false))+str(drops)
 if next_key!=key:
  key=next_key
  for model in models.values(): model.queue_free()
  models.clear()
  for entry in drops:
   var values: Array=entry.position
   var node:=Node3D.new();game.stage.add_child(node);node.position=Vector3(values[0],values[1],values[2])+(game.stage.WILD_OFFSET if player.get("wild",false) else Vector3.ZERO)
   node.set_meta("drop_position",Vector3(values[0],values[1],values[2]))
   var monster: bool=game.Items.get_item(str(entry.item)).get("category","")=="monster_part"
   var color: Color=Color("#62baff") if monster else game.Items.color(str(entry.item))
   var orb: MeshInstance3D=game.stage.sphere(Vector3.ZERO,.17,color)
   orb.reparent(node,false);orb.position.y=.25
   var material:=orb.material_override as StandardMaterial3D
   material.emission_enabled=true;material.emission=color;material.emission_energy_multiplier=1.0 if monster else .35
   if monster:
    var ring:=MeshInstance3D.new();node.add_child(ring)
    var torus:=TorusMesh.new();torus.inner_radius=.23;torus.outer_radius=.28;torus.rings=24;torus.ring_segments=8;ring.mesh=torus;ring.position.y=.05;ring.material_override=material
    var beam:=OmniLight3D.new();node.add_child(beam);beam.position.y=.6;beam.light_color=color;beam.light_energy=.5;beam.omni_range=1.4;beam.shadow_enabled=false
   game.stage.marker(Vector3(0,.65,0),"%s ×%d"%[game.Items.get_item(str(entry.item)).name,int(entry.quantity)],node)
   models[entry.id]=node
 for entry in drops:
  if models.has(entry.id): models[entry.id].visible=not player.get("wild",false) or Vector3(models[entry.id].get_meta("drop_position")).distance_to(game.players.get(game.spectator_view.target_id if player.get("fallen",false) and game.spectator_view.target_id!=0 else game.local_player_id(),player).pos)<=game.exploration.SIGHT
func _exit_tree() -> void:
 for model in models.values():
  if is_instance_valid(model): model.queue_free()
