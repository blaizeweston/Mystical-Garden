extends RefCounted

enum { GROVE, MIRE, HOLLOW, HEART }
enum { DORMANT, PENDING, GROWING, MATURE, HARVESTED }
enum { UNFINISHED, SEED, CORRUPTION }

const LEGACY_ENDING_ENABLED := false # Serialized fields remain for old-save compatibility.

const NAMES := ["The Outer Grove", "The Sable Mire", "The Hollow Below", "The Heart's Last Root"]
const ENEMIES := ["Corrupted Briar", "Mire Stalker", "Hollow Thorn", "Awakened Heart"]
const GUARDIANS := ["Grove Keeper", "Mire Sentinel", "Hollow Watcher"]
const OFFSHOOTS := ["Pale Root", "Lantern Bud", "Hollow Seedling"]
const MATURE_REQUIRED := 2
const FINAL_HP := 18
const SHORTCUT_COST := [0, 2, 4]
const MEMORY_REQUIREMENTS := [12, 16, 20]
const FULL_KNOWLEDGE := 120

var cleared: Array = [false, false, false]
var offshoots: Array = [DORMANT, DORMANT, DORMANT]
var offshoot_beds: Array=[-1,-1,-1]
var offshoot_progress: Array=[0,0,0]
var ending: int = UNFINISHED
var best_clear := 0
var best_extraction := 0
var memories: Array = [0, 0, 0]


func available(site: int) -> bool:
	if site == GROVE:
		return true
	return site > GROVE and site < HEART and cleared[site - 1]


func record_guardian_memories(guardians: int,counts: Array=[]) -> void:
	for site in HEART:
		if (guardians & (1 << site)) != 0:
			memories[site] = mini(memories[site] + (int(counts[site]) if site<counts.size() else 1), MEMORY_REQUIREMENTS[site])


func memories_complete() -> bool:
	return memories == MEMORY_REQUIREMENTS


func record_clear(site: int) -> bool:
	if cleared[site]:
		return false
	cleared[site] = true
	if LEGACY_ENDING_ENABLED: offshoots[site] = PENDING
	return true


func advance_growth() -> void:
	if not LEGACY_ENDING_ENABLED: return
	for i in offshoots.size():
		if offshoots[i] == GROWING:
			offshoot_progress[i]+=1
			if offshoot_progress[i]>=int(preload("res://game_balance.gd").get_value("offshoot_expeditions",3)): offshoots[i]=MATURE


func finish() -> void:
	if not LEGACY_ENDING_ENABLED: return
	if ending == UNFINISHED:
		ending = SEED if offshoots.count(MATURE) >= MATURE_REQUIRED else CORRUPTION


func record_expedition(cleared_depth: int, extracted: bool) -> void:
	best_clear = maxi(best_clear, cleared_depth)
	if extracted:
		best_extraction = maxi(best_extraction, cleared_depth)


func load_state(file: ConfigFile) -> void:
	for i in cleared.size():
		cleared[i] = file.get_value("campaign", "cleared_%d" % i, false) == true
		var state = file.get_value("campaign", "offshoot_%d" % i, PENDING if cleared[i] and LEGACY_ENDING_ENABLED else DORMANT)
		offshoots[i] = clampi(state, PENDING if LEGACY_ENDING_ENABLED else DORMANT, HARVESTED) if cleared[i] and state is int else DORMANT
		offshoot_beds[i]=int(file.get_value("campaign","offshoot_bed_%d"%i,-1))
		offshoot_progress[i]=int(file.get_value("campaign","offshoot_progress_%d"%i,2 if offshoots[i]==GROWING else 0))
		var learned = file.get_value("campaign", "memory_%d" % i, int(cleared[i]))
		memories[i] = clampi(learned, 0, MEMORY_REQUIREMENTS[i]) if learned is int else 0
	var deepest = file.get_value("campaign", "best_clear", 0)
	var banked = file.get_value("campaign", "best_extraction", 0)
	best_clear = maxi(0, deepest) if deepest is int else 0
	best_extraction = maxi(0, banked) if banked is int else 0
	var saved = file.get_value("campaign", "ending", UNFINISHED)
	ending = clampi(saved, UNFINISHED, CORRUPTION) if saved is int else UNFINISHED


func write_state(file: ConfigFile) -> void:
	for i in cleared.size():
		file.set_value("campaign", "cleared_%d" % i, cleared[i])
		file.set_value("campaign", "offshoot_%d" % i, offshoots[i])
		file.set_value("campaign","offshoot_bed_%d"%i,offshoot_beds[i])
		file.set_value("campaign","offshoot_progress_%d"%i,offshoot_progress[i])
		file.set_value("campaign", "memory_%d" % i, memories[i])
	file.set_value("campaign", "ending", ending)
	file.set_value("campaign", "best_clear", best_clear)
	file.set_value("campaign", "best_extraction", best_extraction)
