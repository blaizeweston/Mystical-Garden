extends SceneTree
## Source/definition contract: private implementation edits are not wire changes.
const Contract = preload("res://network_contract.gd")
const Settings = preload("res://network_settings.gd")
const Snapshot = preload("res://world_snapshot.gd")
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL network contract: ",message)

func run() -> void:
	var script: Script = load("res://game.gd")
	var methods: Array = script.get_script_method_list()
	var signature := Contract.signature(methods)
	check(not signature.is_empty() and signature.begins_with("session-1/"),"actual Game satisfies explicit versioned contract")
	check(Settings.PROTOCOL == 41 and Snapshot.PAYLOAD_BUDGET == 1200,"snapshot transport remains protocol 41 with its existing payload budget")
	check(Contract.CAPABILITIES.get("terrain_actor_motion") == preload("res://assets/terrain_m02/terrain_actor_motion.gd").VERSION,
		"shared movement semantics participate in the existing compatibility handshake")
	check(Contract.CAPABILITIES.get("character_appearance") == preload("res://character_appearance.gd").VERSION,
		"expanded cosmetic fields require matching appearance semantics without changing protocol 41")
	var private_edit := methods.duplicate(true)
	private_edit.append({"name":"private_refactor_example","args":[],"default_args":[],"return":{"type":TYPE_INT}})
	check(Contract.signature(private_edit) == signature,"a new private method does not change multiplayer compatibility")
	private_edit.reverse()
	check(Contract.signature(private_edit) == signature,"reflection ordering does not select a contract")
	var missing: Array = methods.filter(func(method): return method.name != "register_character")
	check(Contract.signature(missing).is_empty(),"a missing RPC is rejected")
	var wrong_type := methods.duplicate(true)
	for method: Dictionary in wrong_type:
		if method.name == "request_action": method.args[0].type = TYPE_STRING
	check(Contract.signature(wrong_type).is_empty(),"an incompatible RPC argument type is rejected")
	var wrong_arity := methods.duplicate(true)
	for method: Dictionary in wrong_arity:
		if method.name == "receive_vitals": method.args.append({"type":TYPE_INT})
	check(Contract.signature(wrong_arity).is_empty(),"an incompatible argument count is rejected")
	var wrong_optional := methods.duplicate(true)
	for method: Dictionary in wrong_optional:
		if method.name == "register_character": method.default_args = []
	check(Contract.signature(wrong_optional).is_empty(),"optional argument count is validated")
	var changed_default := methods.duplicate(true)
	for method: Dictionary in changed_default:
		if method.name == "register_character": method.default_args[1] = 999
	check(not Contract.signature(changed_default).is_empty() and Contract.signature(changed_default) != signature,
		"changed RPC default semantics require matching compatibility")
	# Reflection does not expose RPC sender/channel metadata. Keep the authored
	# table tied to actual source annotations so a transport edit cannot be hidden.
	var rpc := RegEx.new()
	check(rpc.compile('(?m)^@rpc\\("([^"]+)",\\s*"call_remote",\\s*"([^"]+)"(?:,\\s*([0-9]+))?\\)\\r?\\nfunc (\\w+)\\(') == OK,"RPC annotation matcher compiles")
	var found := {}
	for match in rpc.search_all(FileAccess.get_file_as_string("res://game.gd")):
		var name := match.get_string(4)
		found[name] = true
		check(Contract.RPCS.has(name),"RPC is explicitly covered: "+name)
		if not Contract.RPCS.has(name): continue
		var definition: Dictionary = Contract.RPCS[name]
		var channel := 0 if match.get_string(3).is_empty() else int(match.get_string(3))
		check(definition.sender == match.get_string(1) and definition.delivery == match.get_string(2)
			and int(definition.channel) == channel,"sender, delivery and channel agree for "+name)
	check(found.size() == Contract.RPCS.size() and found.size() == 25,"all current RPCs are covered once")
	var scene_source := FileAccess.get_file_as_string("res://world.tscn")
	check(('[node name="'+Contract.RPC_NODE+'" type="Node3D"]') in scene_source,"RPC root NodePath is preserved")
	if not failed: print("PASS: explicit network RPC contract, private-method independence, signature incompatibility and protocol-41 schema")
	quit(1 if failed else 0)
