extends RefCounted
## Presentation-only node lookup for fixture assertions and simulated clicks.
static func control(world: Node, control_id: String) -> Variant:
	var node_name := control_id.to_pascal_case()
	if control_id == "field_guide": node_name = "FieldGuide"
	var control := world.get_node("GameplayUI").find_child(node_name,true,false)
	assert(control != null,"Missing UI control: "+node_name)
	return control

## Hypothetical stat-band assertions use real owner facts, then override only
## the supplied stat snapshot. No production view accepts a mutable actor.
static func summary(world: Node, player: Dictionary, stats: Dictionary) -> Dictionary:
	var peer_id: int = world.Traits.player_id(world,player)
	var facts: Dictionary = world.run_summary_ui_data(peer_id)
	facts.stats = stats.duplicate(true)
	facts.copies = world.AffinityCards.project_owned(player,stats,world.DODGE_COOLDOWN_MS) if world.multiplayer.is_server() else player.get("affinity_run_cards",[]).duplicate(true)
	return preload("res://ui/gameplay/player_build_projection.gd").summary(facts)
