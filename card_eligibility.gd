extends RefCounted
## Detached facts from executable build contracts and existing acquisition owners.
## Capability IDs are real skill/Form/adapter IDs, not inferred botanical effects.
const Requirements = preload("res://card_requirements.gd")
const Catalog = preload("res://affinity_card_catalog.gd")
const Classes = preload("res://class_catalog.gd")
const Plants = preload("res://plant_affinities.gd")
const Rules = preload("res://combat_ruleset.gd")
const Grafts = preload("res://expedition_grafts.gd")
static var _known := {}
static var _catalog_issues := {}
static var _checked_catalog := false
static var _consumer_contracts := {}


static func schema() -> Dictionary:
	if not _known.is_empty(): return _known
	var result := {"class":[], "focus":[], "weapon":[], "nodes":{}, "primary":Plants.CORE_SKILL_BY_PRIMARY.keys(),
		"tags":Plants.CORE_SKILL_BY_PRIMARY.keys() + Plants.SUPPORTING_ONLY,
		"capabilities":{"replica":["wraithcast_skill"], "weapon":["strike"], "core":Plants.CORE_SKILL_BY_PRIMARY.values(), "form":Rules.FORMS.values(), "class":[], "catalyst":[], "card":[], "graft":Grafts.ADAPTATIONS.keys()},
		"recipients":["enemy"], "modes":[], "fields":[], "owned":{"card":Catalog.DEFINITIONS.keys(), "graft":Grafts.REINFORCEMENTS.keys() + Grafts.ADAPTATIONS.keys()}}
	for index in Classes.DEFINITIONS.size():
		var frame: Dictionary = Classes.DEFINITIONS[index]
		result["class"].append(frame.id)
		for weapon: Dictionary in frame.weapons: result.weapon.append(weapon.id)
		var tree: RefCounted = Classes.connected_tree(index)
		result.nodes[frame.id] = tree.nodes.map(func(node): return node.id)
		for node: Dictionary in tree.nodes:
			if int(node.tier) == 0: result.focus.append(node.id)
		var actions: Array = frame.skills.base.duplicate()
		if index == 0: actions.append_array(Classes.Warden.FOCUSES.values())
		else: actions.append_array(Classes.Subclasses.FOCUSES[index - 1])
		for skill: Dictionary in actions:
			_add(result.capabilities["class"], str(skill.name))
			_add(result.modes, str(skill.mode))
			if skill.has("field"): _add(result.fields, str(skill.field))
	for row: Array in Rules.Catalyst.ADAPTERS.values(): _add(result.recipients, str(row[2]))
	for responses: Dictionary in Rules.Catalyst.RESPONSES.values():
		for id: String in responses.values(): _add(result.capabilities.catalyst, id)
	_add(result.capabilities.catalyst,Rules.Void.CLASS_PULL_CAPABILITY)
	for definition: Dictionary in Catalog.DEFINITIONS.values():
		for cap: Dictionary in verified_grants(definition).get("capabilities", []):
			_add(result.capabilities.card, cap.id)
			if cap.has("recipient"): _add(result.recipients, cap.recipient)
	_known = _freeze(result)
	return _known


static func facts(build: Dictionary, card_counts: Variant = null) -> Dictionary:
	var counts: Dictionary = build.get("card_counts", {}) if card_counts == null else card_counts
	var improvements: Dictionary = build.get("improvements", {})
	var graft_counts: Dictionary = improvements.get("owned", {}).duplicate(true)
	for id: String in improvements.get("adaptations", []):
		if not graft_counts.has(id): graft_counts[id] = 1
	var result := {"class":build.get("class_id", ""), "focus":build.get("focus_id", ""), "weapon":build.get("weapon_id", ""),
		"nodes":build.get("selected_nodes", []).duplicate(), "plants":[], "capabilities":[],
		"owned":{"card":counts.duplicate(), "graft":graft_counts}}
	if build.get("capabilities", {}).get("strike", false):
		result.capabilities.append({"producer":"weapon", "id":"strike", "slot":"weapon", "recipient":"enemy"})
	for slot: String in Requirements.SLOTS:
		var part: Dictionary = build.get(slot, {})
		if part.get("state") != "ready" or not part.get("executable", false): continue
		result.plants.append({"slot":slot, "primary_affinity":part.primary_affinity, "supporting_affinities":part.supporting_affinities.duplicate()})
		if slot == "core" and Plants.CORE_SKILL_BY_PRIMARY.get(part.primary_affinity) == part.get("affinity_core_skill_id"):
			result.capabilities.append({"producer":"core", "id":part.affinity_core_skill_id, "slot":slot})
		elif slot == "form" and Rules.FORMS.get(part.primary_affinity) == part.get("behavior"):
			result.capabilities.append({"producer":"form", "id":part.behavior, "slot":slot})
	if build.get("capabilities", {}).get("class_actions", false):
		for adapter: Dictionary in build.get("class_skills", []):
			var skill: Dictionary = adapter.get("native_skill", {})
			if skill.is_empty(): continue
			var slot := "q" if int(adapter.slot) == 0 else "r"
			var cap := {"producer":"class", "id":str(skill.name), "slot":slot, "mode":str(skill.mode), "target_scope":str(adapter.recipients)}
			if skill.has("field"): cap.field = str(skill.field)
			result.capabilities.append(cap)
			var response: String = adapter.get("response", "")
			if not response.is_empty() and build.get("catalyst", {}).get("state") == "ready":
				# Native footprint is not necessarily the response's recipient (e.g.
				# self_bark follows an enemy hit). Preserve that distinction explicitly.
				result.capabilities.append({"producer":"catalyst", "id":response, "slot":"catalyst", "target_scope":str(adapter.recipients)})
				if Rules.Void.class_pull_supported(adapter):result.capabilities.append({"producer":"catalyst","id":Rules.Void.CLASS_PULL_CAPABILITY,"slot":"catalyst","target_scope":str(adapter.recipients)})
	for id: String in improvements.get("adaptations", []):
		if Grafts.ADAPTATIONS.has(id): result.capabilities.append({"producer":"graft", "id":id})
	if load("res://spirit_replicas.gd").build_supported(build):result.capabilities.append({"producer":"replica","id":"wraithcast_skill"})
	# Resolve only real owned grants, never hypothetical future acquisitions.
	# Repeated passes allow an earlier acquired capability to enable another;
	# catalog cycle validation prevents circular bootstrap.
	for _pass in counts.size():
		var changed := false
		for id: String in counts:
			if int(counts[id]) <= 0 or not Catalog.DEFINITIONS.has(id): continue
			var definition: Dictionary = Catalog.DEFINITIONS[id]
			if not Requirements.refusal(definition.requires, result, schema()).is_empty(): continue
			for cap: Dictionary in verified_grants(definition).get("capabilities", []):
				if not result.capabilities.has(cap): result.capabilities.append(cap); changed = true
		if not changed: break
	return _freeze(result)


static func requirement(definition: Dictionary, build: Dictionary, card_counts: Variant = null) -> String:
	var grant := verified_grants(definition)
	if not grant.get("error", "").is_empty(): return grant.error
	return Requirements.refusal(definition.get("requires"), facts(build, card_counts), schema())


## The real effect consumer advertises the parameter it reads and capability
## it implements. A declaration alone, or merely an existing method, is insufficient.
static func verified_grants(definition: Dictionary) -> Dictionary:
	var requested: Variant = definition.get("grants", [])
	if not requested is Array: return {"error":"Card grants must be a list of implemented capability IDs."}
	var consumer: Variant = definition.get("consumer", [])
	if not consumer is Array or consumer.size() != 2 or not consumer[0] is String or not consumer[1] is String or not ResourceLoader.exists(consumer[0]):
		return {"error":"Missing card effect consumer."}
	var key: String = str(consumer)
	if not _consumer_contracts.has(key):
		var resource := load(consumer[0])
		if not resource is Script:
			return {"error":"Card effect consumer must be a Script: " + str(consumer)}
		var script := resource as Script
		if not script.get_script_method_list().any(func(method): return str(method.name) == consumer[1]):
			return {"error":"Unknown card effect consumer: " + str(consumer)}
		_consumer_contracts[key] = script.get_script_constant_map().get("CARD_GRANTS", {}).duplicate(true)
	if requested.is_empty(): return {"capabilities":[]}
	var contract: Dictionary = _consumer_contracts[key]
	var entry: Dictionary = contract.get(definition.get("parameter", ""), {})
	var result: Array[Dictionary] = []
	for id in requested:
		if not id is String or result.any(func(cap): return cap.id == id) or entry.get("method") != consumer[1] or entry.get("capability", {}).get("id") != id:
			return {"error":"Unverified capability grant: " + str(id)}
		result.append(entry.capability.duplicate(true))
	return {"capabilities":result}


static func catalog_errors(definitions: Dictionary = Catalog.DEFINITIONS) -> Dictionary:
	var known := schema().duplicate(true)
	known.owned.card = definitions.keys()
	var issues := {}
	var providers := {}
	for id: String in definitions:
		var grant := verified_grants(definitions[id])
		if not grant.get("error", "").is_empty(): issues[id] = grant.error
		var definition: Dictionary = definitions[id]
		var amounts: Variant = [definition.get("fixed", 0)] if definition.get("policy") == "unique" else definition.get("values", [])
		if not amounts is Array or amounts.is_empty() or not amounts.all(func(amount): return amount is int and amount > 0):
			issues[id] = "Every offered rarity or fixed unlock needs a positive contribution."
		for cap: Dictionary in grant.get("capabilities", []):
			_add(known.capabilities.card, cap.id)
			if providers.has(cap.id) and providers[cap.id] != id:
				issues[id] = "Duplicate capability grant provider: " + cap.id
				issues[providers[cap.id]] = issues[id]
			else: providers[cap.id] = id
	var graph := {}
	for id: String in definitions:
		var error := Requirements.validate(definitions[id].get("requires"), known)
		if not error.is_empty(): issues[id] = error
		graph[id] = []
		_dependencies(definitions[id].get("requires", {}), providers, graph[id])
	var visited := {}
	for id: String in graph:
		if _cycle(id, graph, visited): issues[id] = "Circular card capability/acquisition dependency."
	return issues


static func catalog_refusal(id: String) -> String:
	if not _checked_catalog:
		_catalog_issues = catalog_errors()
		_checked_catalog = true
		for bad_id: String in _catalog_issues:
			preload("res://diagnostic_journal.gd").event("content", "card_requirement_rejected", {"card":bad_id, "reason":_catalog_issues[bad_id]})
	return _catalog_issues.get(id, "")


static func _dependencies(expression: Variant, providers: Dictionary, result: Array, depth := 0) -> void:
	if depth > Requirements.MAX_DEPTH or not expression is Dictionary or expression.size() != 1: return
	if expression.has("all") or expression.has("any"):
		var children: Variant = expression.get("all", expression.get("any"))
		if children is Array:
			for child in children: _dependencies(child, providers, result, depth + 1)
	elif expression.has("capability") and expression.capability is Dictionary:
		var cap: Dictionary = expression.capability
		if cap.get("producer") == "card" and providers.has(cap.get("id")): _add(result, providers[cap.id])
	elif expression.has("owned") and expression.owned is Dictionary and expression.owned.get("kind") == "card":
		_add(result, expression.owned.get("id", ""))


static func _cycle(id: String, graph: Dictionary, visited: Dictionary) -> bool:
	var state := int(visited.get(id, 0))
	if state != 0: return state != 2
	visited[id] = 1
	for next: String in graph.get(id, []):
		if _cycle(next, graph, visited): visited[id] = 3; return true
	visited[id] = 2
	return false


static func _add(values: Array, value: String) -> void:
	if not values.has(value): values.append(value)


static func _freeze(value: Variant) -> Variant:
	if value is Dictionary:
		for key in value: _freeze(value[key])
		value.make_read_only()
	elif value is Array:
		for child in value: _freeze(child)
		value.make_read_only()
	return value
