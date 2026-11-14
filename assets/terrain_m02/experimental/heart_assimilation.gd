extends RefCounted
## Session-owned FIFO studies. Work is expressed in the existing Heart research units.

const Items = preload("res://item_catalog.gd")
# Provisional playtest tuning: Knowledge and work seconds per part, by catalog rarity.
const VALUE := {
	"Common": Vector2i(1, 6),
	"Uncommon": Vector2i(2, 10),
	"Rare": Vector2i(3, 15),
	"Epic": Vector2i(4, 21),
	"Mythic": Vector2i(5, 29),
}

var queue: Array[Dictionary] = []

static func quote(items: Dictionary) -> Dictionary:
	var knowledge := 0
	var required := 0
	var names := PackedStringArray()
	var ids := items.keys()
	ids.sort()
	for id: String in ids:
		var item := Items.get_item(id)
		var value: Vector2i = VALUE.get(item.rarity, VALUE.Common)
		var count: int = items[id]
		knowledge += value.x * count
		required += value.y * count
		names.append("%d × %s" % [count, item.name])
	var description := ", ".join(names.slice(0, 3))
	if names.size() > 3:
		description += " and %d more" % (names.size() - 3)
	return {"knowledge": knowledge, "required": required, "done": 0.0, "name": description}

func add(items: Dictionary) -> void:
	queue.append(quote(items))

func plan(work: float) -> Dictionary:
	var next := queue.duplicate(true)
	var earned := 0
	while work > 0.0 and not next.is_empty():
		var study: Dictionary = next.front()
		var remaining: float = study.required - study.done
		if work < remaining:
			study.done += work
			break
		work -= remaining
		earned += int(study.knowledge)
		next.pop_front()
	return {"queue": next, "earned": earned}

func summary() -> Dictionary:
	var pending := 0
	for study: Dictionary in queue:
		pending += int(study.knowledge)
	return {"pending": pending, "waiting": maxi(0, queue.size() - 1),
		"active": {} if queue.is_empty() else queue.front()}
