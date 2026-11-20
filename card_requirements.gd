extends RefCounted
## Pure AND/OR and identity matching over detached eligibility facts.
## No Game, actor records, RNG, transactions or mutable acquisition state.
const SLOTS := ["core", "form", "catalyst"]
const CAPABILITY_FIELDS := ["producer", "id", "slot", "recipient", "target_scope", "mode", "field"]
const MAX_DEPTH := 16 # Authored expression safety, never a gameplay power limit.


static func validate(expression: Variant, known: Dictionary, depth := 0) -> String:
	if depth > MAX_DEPTH: return "Requirement nesting exceeds the content safety limit."
	if not expression is Dictionary or expression.size() != 1:
		return "A requirement must contain exactly one predicate."
	var op: Variant = expression.keys()[0]
	var value: Variant = expression[op]
	match op:
		"all", "any":
			if not value is Array or (op == "any" and value.is_empty()): return "%s requires a list of predicates." % op
			for child in value:
				var error := validate(child, known, depth + 1)
				if not error.is_empty(): return error
		"class", "focus", "weapon":
			if not value is String or not known.get(op, []).has(value): return "Unknown %s ID: %s." % [op, str(value)]
		"node":
			if not value is Dictionary or not _keys(value, ["class", "id"]) or value.size() != 2:
				return "A node requires its class and stable ID."
			if not known.nodes.get(value.get("class"), []).has(value.get("id")): return "Unknown connected node: %s." % str(value)
		"plant":
			return _validate_plant(value, known)
		"distinct_slots":
			if not value is Array or value.is_empty() or value.size() > SLOTS.size(): return "Distinct slots needs one to three plant patterns."
			for pattern in value:
				var error := _validate_plant(pattern, known)
				if not error.is_empty(): return error
		"capability":
			if not value is Dictionary or not _keys(value, CAPABILITY_FIELDS) or not value.has("producer") or not value.has("id"):
				return "A capability requires an actual producer and ID."
			for key in value:
				if not value[key] is String or value[key].is_empty(): return "Capability selectors must be nonempty strings."
			if not known.capabilities.get(value.producer, []).has(value.id): return "Unknown capability: %s/%s." % [value.producer, value.id]
			if value.has("slot") and value.slot not in SLOTS + ["q", "r", "weapon"]: return "Unknown capability slot: " + value.slot
			if value.has("recipient") and not known.recipients.has(value.recipient): return "Unknown recipient selector: " + value.recipient
			if value.has("target_scope") and not known.recipients.has(value.target_scope): return "Unknown native target scope: " + value.target_scope
			if value.has("mode") and not known.modes.has(value.mode): return "Unknown native action mode: " + value.mode
			if value.has("field") and not known.fields.has(value.field): return "Unknown native field: " + value.field
		"owned":
			if not value is Dictionary or not _keys(value, ["kind", "id", "count"]): return "Invalid acquisition requirement."
			if value.get("kind") not in ["card", "graft"] or not value.get("id") is String:
				return "An acquisition requires card/graft kind and a stable ID."
			if not known.owned[value.kind].has(value.id): return "Unknown acquired %s: %s." % [value.kind, value.id]
			if not value.get("count", 1) is int or int(value.get("count", 1)) < 1: return "Acquired copy count must be a positive integer."
		_:
			return "Unsupported requirement predicate: " + str(op)
	return ""


static func refusal(expression: Variant, facts: Dictionary, known: Dictionary) -> String:
	var error := validate(expression, known)
	return error if not error.is_empty() else _refusal(expression, facts)


static func _refusal(expression: Dictionary, facts: Dictionary) -> String:
	var op: String = expression.keys()[0]
	var value: Variant = expression[op]
	match op:
		"all":
			for child in value:
				var error := _refusal(child, facts)
				if not error.is_empty(): return error
			return ""
		"any":
			var reasons: PackedStringArray = []
			for child in value:
				var error := _refusal(child, facts)
				if error.is_empty(): return ""
				reasons.append(error)
			return "Requires one alternative: " + " / ".join(reasons)
		"class", "focus", "weapon":
			if facts.get(op) == value: return ""
		"node":
			if facts.get("class") == value["class"] and facts.nodes.has(value.id): return ""
		"plant":
			if facts.plants.any(func(plant): return _plant_matches(value, plant)): return ""
			if value.has("primary_affinity") and value.get("slot", "any") in SLOTS:
				return "Equip a %s %s." % [str(value.primary_affinity).capitalize(), str(value.slot).capitalize()]
		"distinct_slots":
			if _assign_slots(value, facts.plants, [], 0): return ""
		"capability":
			if facts.capabilities.any(func(cap): return _matches(value, cap)): return ""
		"owned":
			if int(facts.owned[value.kind].get(value.id, 0)) >= int(value.get("count", 1)): return ""
	return "Requires " + describe(expression) + "."


static func _validate_plant(pattern: Variant, known: Dictionary) -> String:
	if not pattern is Dictionary or pattern.is_empty() or not _keys(pattern, ["slot", "primary_affinity", "supporting_affinities", "tags_all", "tags_any"]):
		return "Unsupported plant pattern; tags have only primary and unordered supporting roles."
	if pattern.get("slot", "any") not in SLOTS + ["any"]: return "Unknown plant slot."
	if pattern.has("primary_affinity") and not known.primary.has(pattern.primary_affinity): return "Unknown primary affinity."
	for key in ["supporting_affinities", "tags_all", "tags_any"]:
		if not pattern.has(key): continue
		var tags: Variant = pattern[key]
		if not tags is Array or tags.is_empty(): return key + " must be a nonempty tag list."
		var seen := []
		for tag in tags:
			if not tag is String or not known.tags.has(tag) or seen.has(tag): return "Unknown or duplicate plant tag: " + str(tag)
			seen.append(tag)
	return ""


static func _plant_matches(pattern: Dictionary, plant: Dictionary) -> bool:
	if pattern.get("slot", "any") != "any" and pattern.slot != plant.slot: return false
	if pattern.has("primary_affinity") and pattern.primary_affinity != plant.primary_affinity: return false
	var supports: Array = plant.supporting_affinities
	var tags: Array = [plant.primary_affinity] + supports
	return pattern.get("supporting_affinities", []).all(func(tag): return supports.has(tag)) \
		and pattern.get("tags_all", []).all(func(tag): return tags.has(tag)) \
		and (not pattern.has("tags_any") or pattern.tags_any.any(func(tag): return tags.has(tag)))


static func _assign_slots(patterns: Array, plants: Array, used: Array, index: int) -> bool:
	if index == patterns.size(): return true
	for plant: Dictionary in plants:
		if used.has(plant.slot) or not _plant_matches(patterns[index], plant): continue
		if _assign_slots(patterns, plants, used + [plant.slot], index + 1): return true
	return false


static func _matches(selectors: Dictionary, value: Dictionary) -> bool:
	for key in selectors:
		if value.get(key) != selectors[key]: return false
	return true


static func _keys(value: Dictionary, allowed: Array) -> bool:
	return value.keys().all(func(key): return allowed.has(key))


static func describe(expression: Dictionary) -> String:
	if expression.size() != 1: return "valid requirements"
	var op: String = expression.keys()[0]
	var value: Variant = expression[op]
	match op:
		"all", "any":
			var labels: PackedStringArray = []
			for child in value: labels.append(describe(child))
			return (" and " if op == "all" else " or ").join(labels)
		"class", "focus", "weapon": return "%s %s" % [str(value).replace("_", " "), op]
		"node": return "%s node %s" % [value["class"], value.id.replace("_", " ")]
		"plant":
			var labels: PackedStringArray = []
			if value.has("primary_affinity"): labels.append(str(value.primary_affinity).capitalize() + " primary")
			for key in ["supporting_affinities", "tags_all", "tags_any"]:
				if value.has(key): labels.append(key.replace("_", " ") + ": " + ", ".join(value[key]))
			return "%s plant (%s)" % [str(value.get("slot", "any")).capitalize(), "; ".join(labels)]
		"distinct_slots": return "the listed plant tags in different equipment slots"
		"capability": return "%s %s action%s" % [value.producer, value.id.replace("_", " "), " for " + value.recipient if value.has("recipient") else ""]
		"owned": return "%d acquired %s %s" % [int(value.get("count", 1)), value.kind, value.id.replace("_", " ")]
	return "supported requirements"
