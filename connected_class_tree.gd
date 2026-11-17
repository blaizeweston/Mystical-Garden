extends RefCounted
## Versioned profile paths and host-side selection rules shared by connected class trees.
const VERSION := 1
const MIGRATION_KEY := "connected_class_migrations"
const MIGRATION_VERSION := 1
const REQUEST_OFFSET := 64
const XP_THRESHOLDS := [0, 50, 150, 350, 1400, 2600]
const LANES := ["Offensive", "Balanced", "Defensive"]

var class_id: int
var class_key: String
var label: String
var profile_key: String
var nodes: Array[Dictionary]


func _init(id: int, key: String, title: String, field: String, rows: Array) -> void:
	class_id = id
	class_key = key
	label = title
	profile_key = field
	nodes = _make_nodes(rows)


func _make_nodes(rows: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tier in rows.size():
		for lane in LANES.size():
			var definition: Array = rows[tier][lane]
			var parents: Array[String] = []
			if tier > 0:
				for adjacent in range(maxi(0, lane - 1), mini(LANES.size(), lane + 2)):
					parents.append(rows[tier - 1][adjacent][0])
			result.append({"id":definition[0], "name":definition[1], "description":definition[2],
				"tier":tier, "level":tier + 1, "lane":lane, "parents":parents})
	return result


func eligible(profile: Dictionary) -> bool:
	var upgrades: Array = profile.get("upgrades",[])
	if class_id < upgrades.size() and int(upgrades[class_id]) != 0:
		return false
	var migrations: Variant = profile.get(MIGRATION_KEY,{})
	if not migrations is Dictionary or (migrations.has(class_key) and migrations[class_key] != MIGRATION_VERSION):
		return false
	var preserved: Variant = profile.get("quarantine",{}).get("learned_class_masks",{})
	if not preserved is Dictionary:
		return false
	return not preserved.has(class_key) or migrations.get(class_key) == MIGRATION_VERSION


func level(profile: Dictionary) -> int:
	var xp: Array = profile.get("xp", [0])
	var earned := int(xp[class_id]) if class_id < xp.size() else 0
	var result := 1
	for index in range(1, XP_THRESHOLDS.size()):
		if earned < XP_THRESHOLDS[index]:
			break
		result += 1
	return result


func node(id: Variant) -> Dictionary:
	for entry in nodes:
		if entry.id == id:
			return entry
	return {}


func valid(profile: Dictionary) -> bool:
	if not profile.has(profile_key):
		return true
	var state: Variant = profile[profile_key]
	if not state is Dictionary or not state.get("version") is int or state.get("version") != VERSION or not state.get("path") is Array:
		return false
	var selected: Array = state.path
	if selected.size() > level(profile):
		return false
	for index in selected.size():
		var entry := node(selected[index])
		if not selected[index] is String or entry.is_empty() or int(entry.tier) != index:
			return false
		if index > 0 and not entry.parents.has(selected[index - 1]):
			return false
	return true


func path(profile: Dictionary) -> Array:
	return profile[profile_key].path if profile.has(profile_key) and valid(profile) else []


func lane_at(selected: Array, tier: int) -> int:
	return int(node(selected[tier]).lane) if tier >= 0 and tier < selected.size() else -1


static func focus_text(text: String, ability: String) -> String:
	return text.replace("{focus}", ability if not ability.is_empty() else "your starting ability")


func focus(profile: Dictionary) -> String:
	var selected := path(profile)
	return "" if selected.is_empty() else str(selected[0])


func state(selected: Array) -> Dictionary:
	return {"version": VERSION, "path": selected}


func refusal(profile: Dictionary, request: int) -> String:
	if not eligible(profile):
		return "Refund this historical %s class at the Heart to activate its connected tree. Class XP is preserved." % label
	if not valid(profile):
		return "This character's connected %s data needs review before it can change." % label
	var index := request - REQUEST_OFFSET
	if index < 0 or index >= nodes.size():
		return "Select a node in the connected %s tree." % label
	var entry := nodes[index]
	var selected := path(profile)
	if entry.tier != selected.size():
		return "Select one node in the next tier."
	if level(profile) <= selected.size():
		return "Reach %s level %d for this selection." % [label, entry.level]
	if not selected.is_empty() and not entry.parents.has(selected.back()):
		return "Choose a node connected to your last selection."
	return ""


func learn(profile: Dictionary, request: int) -> String:
	var reason := refusal(profile, request)
	if not reason.is_empty():
		return reason
	var selected := path(profile).duplicate()
	selected.append(nodes[request - REQUEST_OFFSET].id)
	profile[profile_key] = state(selected)
	return ""
