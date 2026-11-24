extends RefCounted

enum { GROVE, MIRE, HOLLOW }
const BIOME_COUNT := HOLLOW + 1

const NAMES := ["The Outer Grove", "The Sable Mire", "The Hollow Below"]
const SHORTCUT_COST := [0, 2, 4]
const MEMORY_REQUIREMENTS := [12, 16, 20]
const FULL_KNOWLEDGE := 120

var cleared: Array = [false, false, false]
var best_clear := 0
var best_extraction := 0
var memories: Array = [0, 0, 0]


func available(site: int) -> bool:
	if site == GROVE:
		return true
	return site > GROVE and site < BIOME_COUNT and cleared[site - 1]


func record_guardian_memories(guardians: int,counts: Array=[]) -> void:
	for site in BIOME_COUNT:
		if (guardians & (1 << site)) != 0:
			memories[site] = mini(memories[site] + (int(counts[site]) if site<counts.size() else 1), MEMORY_REQUIREMENTS[site])


func memories_complete() -> bool:
	return memories == MEMORY_REQUIREMENTS


func record_clear(site: int) -> bool:
	if site < 0 or site >= BIOME_COUNT or cleared[site]:
		return false
	cleared[site] = true
	return true


func record_expedition(cleared_depth: int, extracted: bool) -> void:
	best_clear = maxi(best_clear, cleared_depth)
	if extracted:
		best_extraction = maxi(best_extraction, cleared_depth)


func load_state(file: ConfigFile) -> void:
	for i in cleared.size():
		cleared[i] = file.get_value("campaign", "cleared_%d" % i, false) == true
		var learned = file.get_value("campaign", "memory_%d" % i, int(cleared[i]))
		memories[i] = clampi(learned, 0, MEMORY_REQUIREMENTS[i]) if learned is int else 0
	var deepest = file.get_value("campaign", "best_clear", 0)
	var banked = file.get_value("campaign", "best_extraction", 0)
	best_clear = maxi(0, deepest) if deepest is int else 0
	best_extraction = maxi(0, banked) if banked is int else 0


func write_state(file: ConfigFile) -> void:
	for i in cleared.size():
		file.set_value("campaign", "cleared_%d" % i, cleared[i])
		file.set_value("campaign", "memory_%d" % i, memories[i])
	file.set_value("campaign", "best_clear", best_clear)
	file.set_value("campaign", "best_extraction", best_extraction)
