extends RefCounted
## Presentation-only node lookup for fixture assertions and simulated clicks.
static func control(world: Node, control_id: String) -> Variant:
	var node_name := control_id.to_pascal_case()
	if control_id == "field_guide": node_name = "FieldGuide"
	var control := world.get_node("GameplayUI").find_child(node_name,true,false)
	assert(control != null,"Missing UI control: "+node_name)
	return control
