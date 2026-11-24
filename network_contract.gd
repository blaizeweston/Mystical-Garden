extends RefCounted
## The compatibility boundary is the network API, not every private Game method.
## Update the authored capability version when its behavior/schema changes.
## RPC entry points stay on the MysticalGarden scene node for protocol 41.

const Snapshot = preload("res://world_snapshot.gd")
const Settings = preload("res://network_settings.gd")
const ActionIdentity = preload("res://network_action_identity.gd")
const ActorMotion = preload("res://assets/terrain_m02/terrain_actor_motion.gd")
const VERSION := 1
const RPC_NODE := "MysticalGarden"
const CAPABILITIES := {
	"garden_growth_events": preload("res://garden_growth_state.gd").NETWORK_VERSION,
	"character_appearance": preload("res://character_appearance.gd").VERSION,
	"terrain_actor_motion": ActorMotion.VERSION,
	"session_admission": 1,
	"owner_details_binding": 1,
	"action_identity": ActionIdentity.VERSION,
	"native_class_request": 1,
	"guest_profile_projection": 1,
	"expedition_travel_consent": 1,
	"expedition_abandonment_forfeiture": 1,
	"wild_flora_harvest": 1,
	"botanical_acquisition": 2,
	"immediate_heart_research": 1,
	"structure_inventory": 2,
}

## Authored sender, transport/channel, ordered argument types and optional count.
## The focused contract test also compares the actual RPC annotations with this
## table. Reflection validates these signatures in source and compiled exports.
const RPCS := {
	"register_character": {"sender":"any_peer", "delivery":"reliable", "channel":0, "args":[TYPE_STRING,TYPE_DICTIONARY,TYPE_DICTIONARY,TYPE_INT], "optional":2},
	"request_garden_action": {"sender":"any_peer", "delivery":"reliable", "channel":0, "args":[TYPE_STRING], "optional":0},
	"request_action": {"sender":"any_peer", "delivery":"reliable", "channel":0, "args":[TYPE_BOOL], "optional":0},
	"request_wild_flora": {"sender":"any_peer", "delivery":"reliable", "channel":0, "args":[TYPE_STRING,TYPE_STRING], "optional":0},
	"request_dodge": {"sender":"any_peer", "delivery":"reliable", "channel":0, "args":[TYPE_VECTOR2], "optional":0},
	"submit_motion": {"sender":"any_peer", "delivery":"unreliable_ordered", "channel":0, "args":[TYPE_VECTOR2], "optional":0},
	"submit_movement": {"sender":"any_peer", "delivery":"unreliable_ordered", "channel":3, "args":[TYPE_ARRAY,TYPE_STRING], "optional":0},
	"submit_combat": {"sender":"any_peer", "delivery":"unreliable_ordered", "channel":1, "args":[TYPE_VECTOR2,TYPE_BOOL], "optional":0},
	"receive_expedition_result": {"sender":"authority", "delivery":"reliable", "channel":0, "args":[TYPE_STRING,TYPE_STRING,TYPE_INT,TYPE_DICTIONARY], "optional":0},
	"receive_character": {"sender":"authority", "delivery":"reliable", "channel":0, "args":[TYPE_DICTIONARY], "optional":0},
	"receive_message": {"sender":"authority", "delivery":"reliable", "channel":0, "args":[TYPE_STRING], "optional":0},
	"receive_state": {"sender":"authority", "delivery":"unreliable_ordered", "channel":4, "args":[TYPE_PACKED_BYTE_ARRAY], "optional":0},
	"receive_details": {"sender":"authority", "delivery":"reliable", "channel":1, "args":[TYPE_PACKED_BYTE_ARRAY,TYPE_PACKED_BYTE_ARRAY,TYPE_ARRAY,TYPE_STRING], "optional":0},
	"receive_combat_event": {"sender":"authority", "delivery":"reliable", "channel":2, "args":[TYPE_DICTIONARY,TYPE_STRING], "optional":0},
	"receive_vitals": {"sender":"authority", "delivery":"reliable", "channel":2, "args":[TYPE_DICTIONARY], "optional":0},
	"connection_accepted": {"sender":"authority", "delivery":"reliable", "channel":0, "args":[TYPE_DICTIONARY], "optional":0},
	"connection_rejected": {"sender":"authority", "delivery":"reliable", "channel":0, "args":[TYPE_STRING], "optional":0},
	"open_heart_tree": {"sender":"authority", "delivery":"reliable", "channel":0, "args":[], "optional":0},
	"show_checkpoint_deposit": {"sender":"authority", "delivery":"reliable", "channel":0, "args":[], "optional":0},
	"open_gate_preparation": {"sender":"authority", "delivery":"reliable", "channel":0, "args":[], "optional":0},
	"close_run_flow_panel": {"sender":"authority", "delivery":"reliable", "channel":0, "args":[], "optional":0},
	"open_checkpoint_cards": {"sender":"authority", "delivery":"reliable", "channel":0, "args":[TYPE_ARRAY,TYPE_INT,TYPE_INT,TYPE_BOOL], "optional":0},
	"open_graft_menu": {"sender":"authority", "delivery":"reliable", "channel":0, "args":[TYPE_DICTIONARY], "optional":0},
	"open_garden_altar": {"sender":"authority", "delivery":"reliable", "channel":0, "args":[TYPE_DICTIONARY], "optional":0},
	"update_garden_altar": {"sender":"authority", "delivery":"reliable", "channel":0, "args":[TYPE_DICTIONARY], "optional":0},
	"open_planting_picker": {"sender":"authority", "delivery":"reliable", "channel":0, "args":[TYPE_INT,TYPE_ARRAY], "optional":0},
	"close_planting_picker": {"sender":"authority", "delivery":"reliable", "channel":0, "args":[], "optional":0},
}

static func signature(methods: Array) -> String:
	var actual := {}
	for method: Dictionary in methods:
		var name := str(method.name)
		if RPCS.has(name): actual[name] = method
	var names := RPCS.keys()
	names.sort()
	var entries: Array = []
	for name: String in names:
		if not actual.has(name): return ""
		var method: Dictionary = actual[name]
		var specification: Dictionary = RPCS[name]
		var arguments: Array = method.args
		var defaults: Array = method.get("default_args", [])
		if arguments.size() != specification.args.size() or defaults.size() != int(specification.optional) \
				or int(method.return.type) != TYPE_NIL:
			return ""
		for index in arguments.size():
			if int(arguments[index].type) != int(specification.args[index]): return ""
		# Parameter names and unrelated private methods are not wire semantics.
		entries.append([name,specification,defaults])
	var snapshot_schema := [Settings.PROTOCOL,Snapshot.SCHEMA,Snapshot.HEADER,
		Snapshot.CAMPAIGN_WORDS,Snapshot.PLAYER_BYTES,Snapshot.SCOUT_BYTES,
		Snapshot.PAYLOAD_BUDGET,Settings.MAX_PLAYERS]
	return "session-%d/" % VERSION + JSON.stringify([RPC_NODE,CAPABILITIES,snapshot_schema,entries]).sha256_text()
