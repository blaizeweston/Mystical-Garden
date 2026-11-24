extends RefCounted
const Catalog = preload("res://heart_catalog.gd")
const VERSION := 4
const Structures = preload("res://garden_structure_inventory.gd")
var unlocked: Array = ["heart"]
var spent := 0
var offered: Array = []

func has(id: String) -> bool:
	return unlocked.has(id)

func serialize() -> Dictionary:
	return {"version": VERSION, "unlocked": unlocked.duplicate(), "spent": spent, "offered": offered.duplicate()}

func restore(data: Dictionary) -> void:
	unlocked.assign(data.unlocked)
	spent = data.spent
	offered.assign(data.offered)

func load_state(file: ConfigFile, owner: RefCounted) -> bool:
	var data: Dictionary = file.get_value("heart", "state", {})
	var legacy := data.is_empty() or int(data.get("version", 0)) == 0
	unlocked = ["heart"]
	spent = maxi(0, data.spent) if data.get("spent") is int else 0
	offered.clear()
	if data.get("unlocked") is Array:
		for id in data.unlocked:
			if id is String: unlock_direct(id)
	if data.get("offered") is Array:
		for part in data.offered:
			if part is int and owner.Parts.is_monster(part) and not offered.has(part):
				offered.append(part)
	if data.get("version") in [1, 2] and data.get("paid") is Array:
		var receipts: Array = []
		var retained_cost := 0
		for id in data.paid:
			if id is String and (Catalog.enabled(id) or Structures.OLD_PRICES.has(id)) and not receipts.has(id):
				receipts.append(id)
				retained_cost += int(Structures.OLD_PRICES.get(id, Catalog.get_node(id).get("insight",0)))
				unlock_direct(id)
		# Historic purchases recorded IDs and an aggregate debit. Leave every
		# supported purchase funded and return only evidenced retired spending.
		var retired_cost := 5 * int(data.paid.has("infusion")) + 6 * int(data.paid.has("rift_hook")) + 12 * int(data.paid.has("perfect_recollection"))
		spent -= clampi(spent - retained_cost, 0, retired_cost)
	if legacy:
		if file.get_value("garden", "studying_flowering", false) == true: unlock_direct("flowering")
		# Pre-tree completion may establish earned, still-supported research and guardian memories.
		var old_discovery: bool=file.get_value("garden","rift_hook_discovered",false)==true
		var restored: bool=owner.flowering_unlocked and old_discovery and owner.veilcap_discovered and owner.knowledge>=owner.Campaign.FULL_KNOWLEDGE and owner.campaign.memories_complete()
		var old_ending: Variant = file.get_value("campaign", "ending", 0)
		if restored or (old_ending is int and old_ending in [1, 2]):
			for id in Catalog.required_core(): unlock_direct(id)
			for id in ["memory_grove","memory_mire","memory_hollow"]: unlock_direct(id)
	if int(data.get("version",0)) < VERSION:
		for id in Structures.OLD_PRICES:
			if id in data.get("paid",[]) or id in data.get("unlocked",[]) or owner.plots.size()>3:
				unlock_direct("cultivation_grounds")
				break
	sync_legacy(owner)
	return legacy

func unlock_direct(id: String) -> void:
	if not has(id) and not Catalog.get_node(id).is_empty(): unlocked.append(id)

func sync_legacy(owner: RefCounted) -> void:
	if owner.flowering_unlocked: unlock_direct("flowering")
	owner.flowering_unlocked = has("flowering")
	sync_memories(owner)

func sync_memories(owner: RefCounted) -> void:
	if not has("living_archive"): return
	for node in Catalog.DEFINITIONS:
		if node.has("memory") and int(owner.campaign.memories[int(node.memory)])>=int(owner.Campaign.MEMORY_REQUIREMENTS[int(node.memory)]):
			unlock_direct(node.id)

func available_insight(owner: RefCounted) -> int:
	return maxi(0,int(owner.knowledge)-spent)

func requirements(owner: RefCounted,id: String) -> String:
	var node:=Catalog.get_node(id)
	if node.is_empty(): return "Unknown memory."
	if has(id): return "Already restored."
	if node.has("memory"): return "Restore this memory through repeated guardian expeditions."
	for parent in node.parents:
		if not has(parent): return "Requires "+str(Catalog.get_node(parent).name)+"."
	if available_insight(owner)<int(node.insight): return "Need %d available Knowledge."%int(node.insight)
	return ""

func purchase(owner: RefCounted, id: String) -> String:
	var refusal := requirements(owner, id)
	if not refusal.is_empty(): return refusal
	var node := Catalog.get_node(id)
	spent += int(node.insight)
	complete(owner, id)
	return "%s unlocked." % node.name

func complete(owner: RefCounted, id: String) -> void:
	var node := Catalog.get_node(id)
	if node.is_empty() or has(id): return
	unlock_direct(id)
	Structures.grant_research(owner.structures,id)
	if id == "flowering": owner.flowering_unlocked = true
	sync_memories(owner)

func clearing_bonus() -> int:
	var result:=0
	for id in ["clearing_1","clearing_2","clearing_3"]:
		result+=int(has(id))
	return result

func growth_multiplier() -> float:
	return 1.4 if has("nursery") else 1.2 if has("irrigation") else 1.0

# Recollection milestones use whole completed memories.
@warning_ignore_start("integer_division")
func phase(owner: RefCounted) -> int:
	var memories:=0
	var total:=0
	for count in owner.campaign.memories: memories+=int(count)
	for count in owner.Campaign.MEMORY_REQUIREMENTS: total+=int(count)
	if has("living_archive") and memories>=total/2: return 4
	if unlocked.size()>=8 and owner.knowledge>=50: return 3
	if unlocked.size()>=4 and owner.knowledge>=20: return 2
	if has("flowering") or owner.plots.size()>3 or owner.knowledge>=8: return 1
	return 0

@warning_ignore_restore("integer_division")
func snapshot(owner: RefCounted) -> Dictionary:
	sync_legacy(owner)
	var result:=serialize()
	result["phase"]=phase(owner)
	result["insight"]=available_insight(owner)
	result["knowledge_available"]=available_insight(owner)
	result["clearing"]=clearing_bonus()
	return result
