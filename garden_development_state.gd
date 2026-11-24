extends RefCounted
## Versioned save projection, not a second live Garden owner.
## Positions/radii are metres, yaw is radians.
const VERSION := 3
const SEED := 117
const RADIUS := 14 # Authored inner habitat.
const FRONTIER_RADIUS := 26
const STARTING_MARGIN_M := 0.85
const SPACING := 1.75
const Structures = preload("res://garden_structure_catalog.gd")

static func refusal(value: Variant, plot_count: int = -1) -> String:
	if not value is Dictionary:
		return "Garden development must be a record."
	if value.is_empty():
		return "" # An older Garden has not saved construction yet.
	if value.get("version") not in [1, 2, VERSION]:
		return "Unsupported Garden layout version."
	if value.get("seed") != SEED or value.get("radius") != RADIUS or value.get("spacing") != SPACING:
		return "Garden layout belongs to a different terrain generation."
	for key in ["revision", "layout_revision", "reclaimed_cells", "energy"]:
		if not value.get(key) is int or value[key] < 0:
			return "Invalid Garden %s." % key
	if not _polygon(value.get("outline"), 3):
		return "Invalid Garden clearing boundary."
	if not value.get("owned") is Dictionary or value.owned.is_empty():
		return "Missing reclaimed Garden cells."
	for cell in value.owned:
		if not cell is Vector2i or not value.owned[cell] is int or value.owned[cell] < 0 or value.owned[cell] > value.revision:
			return "Invalid reclaimed Garden cell."
	if not value.get("growth") is Array or value.growth.size() != value.revision:
		return "Invalid Garden expansion history."
	for sector in value.growth:
		if not sector is int or sector < 0 or sector >= 8:
			return "Invalid Garden frontier."
	if not value.get("root_paths") is Array or not value.get("roots") is Array or value.roots.size() != value.revision or value.root_paths.size() != value.revision:
		return "Invalid Garden root history."
	for path in value.root_paths:
		if not _polygon(path, 2):
			return "Invalid Garden root path."
	for root in value.roots:
		if not _root(root):
			return "Invalid Garden root geometry."
	if value.version == VERSION:
		return "Obsolete construction data in modern terrain." if value.has("buildings") or value.has("next_id") or value.has("queue") else ""
	var buildings: Variant = value.get("buildings")
	if not buildings is Array or not value.get("next_id") is int:
		return "Missing Garden structures."
	var ids := {}
	var plots := {}
	var altars := 0
	for entry in buildings:
		if not entry is Array or entry.size() != 5:
			return "Invalid Garden structure record."
		if not entry[0] is int or entry[0] <= 0 or ids.has(entry[0]) or entry[0] >= value.next_id:
			return "Invalid or repeated Garden structure identity."
		ids[entry[0]] = true
		if not entry[1] is String or not Structures.DEFINITIONS.has(entry[1]) or not entry[2] is Vector2 or not _point(entry[2]) or not _number(entry[3]):
			return "Invalid Garden structure kind or position."
		if entry[1] == "bed":
			if not entry[4] is int or entry[4] < 0 or entry[4] >= 9 or plots.has(entry[4]):
				return "Invalid or repeated crop-slot placement."
			plots[entry[4]] = true
		elif entry[4] != null:
			return "A station cannot own a crop slot."
		if entry[1] == "altar":
			altars += 1
	if altars != 1 or plots.size() < 3 or (plot_count >= 0 and plots.size() != plot_count):
		return "Saved structures do not match the Garden's owned beds and altar."
	for index in plots.size():
		if not plots.has(index):
			return "Missing crop-slot placement."
	if value.version == 2:
		return "Unexpected historical Heart queue." if value.has("queue") else ""
	# Only version 1 carried unpaid Knowledge batches.
	if not value.get("queue") is Array or value.queue.size() > 32:
		return "Invalid Heart study queue."
	for study in value.queue:
		if not study is Dictionary or not study.get("knowledge") is int or study.knowledge <= 0 or not study.get("required") is int or study.required <= 0:
			return "Invalid Heart study reward."
		if not _number(study.get("done")) or study.done < 0.0 or study.done >= study.required or not study.get("name") is String:
			return "Invalid Heart study progress."
	return ""

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _point(value: Vector2) -> bool:
	return value.is_finite() and value.length() <= RADIUS * SPACING * 3.0

static func _polygon(value: Variant, minimum: int) -> bool:
	if not value is PackedVector2Array or value.size() < minimum:
		return false
	for point in value:
		if not _point(point):
			return false
	return true

static func _points3(value: Variant) -> bool:
	if not value is Array or value.size() < 2:
		return false
	for point in value:
		if not point is Vector3 or not point.is_finite() or not _point(Vector2(point.x, point.z)):
			return false
	return true

static func _root(value: Variant) -> bool:
	if not value is Dictionary or not _points3(value.get("main")) or not _number(value.get("radius")) or value.radius <= 0.0:
		return false
	if not value.get("socket") is int or value.socket < 0 or value.socket >= 6 or not value.get("connection") is Dictionary or not value.get("branches") is Array:
		return false
	for branch in value.branches:
		if not branch is Dictionary or not _points3(branch.get("points")) or not _number(branch.get("radius")) or branch.radius <= 0.0 or not branch.get("join") is int:
			return false
	return true
