extends RefCounted
## In-memory adapter for the terrain lab. Research grants permission only.
signal changed

const Catalog = preload("res://heart_catalog.gd")
const Layout = preload("res://garden_layout.gd")
const Interactions = preload("res://garden_interaction_catalog.gd")
const STARTER_BEDS := 3

var unlocked := {"heart": true}
var knowledge := 0
var spent := 0
var sandbox := false
var _research_nodes: Array

func _init() -> void:
	_research_nodes = _resolve_research()

func relevant_research() -> Array:
	return _research_nodes

func _resolve_research() -> Array:
	var relevant := {"seed_archive": true, "monster_studies": true}
	for id: String in Interactions.requirements(Layout.zone("sheltered_spring")):
		relevant[id] = true
	for node: Dictionary in Catalog.DEFINITIONS:
		if node.has("plots") or node.has("clearing"):
			relevant[node.id] = true
	# Figure out the prerequisite closure before displaying catalog order.
	for id: String in relevant.keys():
		_add_parents(id, relevant)
	return Catalog.DEFINITIONS.filter(func(node: Dictionary): return node.id != "heart" and relevant.has(node.id))

func _add_parents(id: String, relevant: Dictionary) -> void:
	for parent: String in Catalog.get_node(id).parents:
		if not relevant.has(parent):
			relevant[parent] = true
			_add_parents(parent, relevant)

func grant_test_knowledge() -> void:
	knowledge += 10
	changed.emit()

func set_sandbox(enabled: bool) -> void:
	sandbox = enabled
	changed.emit()

func available_knowledge() -> int:
	return knowledge - spent

func research_refusal(id: String) -> String:
	var node := Catalog.get_node(id)
	if node.is_empty() or not Catalog.enabled(id) or not _research_nodes.has(node):
		return "This research is outside the terrain lab."
	if unlocked.has(id):
		return "Already researched."
	for parent: String in node.parents:
		if not unlocked.has(parent):
			return "Requires %s." % Catalog.get_node(parent).name
	if knowledge < int(node.knowledge):
		return "Requires %d lifetime Knowledge." % node.knowledge
	if available_knowledge() < int(node.insight):
		return "Requires %d available Knowledge." % node.insight
	return ""

func research(id: String) -> bool:
	if not research_refusal(id).is_empty():
		return false
	spent += int(Catalog.get_node(id).insight)
	unlocked[id] = true
	changed.emit()
	return true

func clearing_tier() -> int:
	return _highest_unlocked("clearing", 0)

func construction_requirements(kind: String) -> Array:
	match kind:
		"bed": return ["plot_4"]
		"study": return ["monster_studies"]
		"archive": return ["seed_archive"]
	return []

func locked_reason(kind: String) -> String:
	if sandbox:
		return ""
	var names := PackedStringArray()
	for id: String in construction_requirements(kind):
		if not unlocked.has(id):
			names.append(Catalog.get_node(id).name)
	return "Research %s in Knowledge first." % " and ".join(names) if not names.is_empty() else ""

func construction_refusal(kind: String, records: Dictionary) -> String:
	var reason := locked_reason(kind)
	if not reason.is_empty():
		return reason
	if kind == "study":
		for record: Dictionary in records.values():
			if record.kind == "study":
				return "The Field study is already built. Select it in Move mode."
	if kind == "bed" and not sandbox and bed_count(records) >= extra_bed_limit():
		return "All unlocked bed spaces are used. Research the next Garden Bed or relocate an existing bed."
	return ""

func bed_count(records: Dictionary) -> int:
	var built := 0
	for record: Dictionary in records.values():
		if record.kind == "bed":
			built += 1
	return built

func extra_bed_limit() -> int:
	return _highest_unlocked("plots", STARTER_BEDS) - STARTER_BEDS

func _highest_unlocked(field: String, baseline: int) -> int:
	var result := baseline
	for id: String in unlocked:
		result = maxi(result, int(Catalog.get_node(id).get(field, baseline)))
	return result
