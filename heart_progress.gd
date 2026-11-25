extends RefCounted
const Catalog = preload("res://heart_catalog.gd")
const VERSION := 6
const RETIRED_COSTS := {"clearing_2":5, "clearing_3":8, "spore_bench":5, "living_archive":8}
const REMEMBRANCES := ["memory_grove", "memory_mire", "memory_hollow"]
# Prices recorded by versions 1–2. Repricing the live catalog cannot change old debits.
const EARLY_COSTS := {"heart":0,"flowering":0,"irrigation":4,"nursery":6,"seed_archive":5,
	"monster_studies":4,"checkpoint_deposit":8,"clearing_1":3,"living_conduit":6}
const STAGE_THRESHOLDS := [0, 4, 12, 24, 40]
const Structures = preload("res://garden_structure_inventory.gd")
var unlocked: Array = ["heart"]
var spent := 0
var offered: Array = []
var frontier_discount_steps := 0
var decoded := [false, false, false]
var historical_stage := 0
var historical_scale := 0

func has(id: String) -> bool:
	return unlocked.has(id)

func serialize() -> Dictionary:
	return {"version": VERSION, "unlocked": unlocked.duplicate(), "spent": spent, "offered": offered.duplicate(),
		"frontier_discount_steps":frontier_discount_steps,"decoded":decoded.duplicate(),
		"historical_stage":historical_stage,"historical_scale":historical_scale}

func restore(data: Dictionary) -> void:
	unlocked.assign(data.unlocked)
	spent = data.spent
	offered.assign(data.offered)
	_load_heritage(data)

func _load_heritage(data: Dictionary) -> void:
	frontier_discount_steps = clampi(int(data.get("frontier_discount_steps",0)),0,2)
	historical_stage = clampi(int(data.get("historical_stage",0)),0,4)
	historical_scale = clampi(int(data.get("historical_scale",0)),0,38)
	var flags: Array = data.get("decoded",[])
	for i in decoded.size(): decoded[i] = i < flags.size() and flags[i] == true

func load_state(file: ConfigFile, owner: RefCounted) -> bool:
	var data: Dictionary = file.get_value("heart", "state", {})
	var legacy := data.is_empty() or int(data.get("version", 0)) == 0
	unlocked = ["heart"]
	spent = maxi(0, data.spent) if data.get("spent") is int else 0
	offered.clear()
	_load_heritage(data)
	var historical: Array = data.get("unlocked",[]).duplicate() if data.get("unlocked") is Array else []
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
		var retired_cost := 0
		for id in data.paid:
			if not id is String or receipts.has(id): continue
			receipts.append(id)
			if not historical.has(id): historical.append(id)
			if RETIRED_COSTS.has(id):
				retired_cost += int(RETIRED_COSTS[id])
			elif id in ["infusion","rift_hook","perfect_recollection"]:
				retired_cost += int({"infusion":5,"rift_hook":6,"perfect_recollection":12}[id])
			else:
				retained_cost += int(Structures.OLD_PRICES.get(id, EARLY_COSTS.get(id,0)))
				unlock_direct(id)
		spent -= clampi(spent - retained_cost, 0, retired_cost)
	if legacy:
		# Pre-tree completion may establish earned, still-supported research and guardian memories.
		var old_discovery: bool=file.get_value("garden","rift_hook_discovered",false)==true
		var restored: bool=file.get_value("garden","flowering_unlocked",false) == true and old_discovery and owner.veilcap_discovered and owner.knowledge>=owner.Campaign.FULL_KNOWLEDGE and owner.campaign.memories_complete()
		var old_ending: Variant = file.get_value("campaign", "ending", 0)
		if restored or (old_ending is int and old_ending in [1, 2]):
			for id in Catalog.required_core(): unlock_direct(id)
			historical.append_array(Catalog.required_core() + RETIRED_COSTS.keys() + REMEMBRANCES)
	if int(data.get("version",0)) < 4:
		for id in Structures.OLD_PRICES:
			if id in data.get("paid",[]) or id in data.get("unlocked",[]) or owner.plots.size()>3:
				unlock_direct("cultivation_grounds")
				break
	if int(data.get("version", 0)) < 5:
		if has("nursery"): unlock_direct("vital_roots")
		if "living_conduit" in data.get("unlocked", []) or (data.get("version") in [1,2] and "living_conduit" in data.get("paid", [])):
			unlock_direct("bud_sanctuary")
			unlock_direct("bud_sanctuary_effectiveness")
	if int(data.get("version",0)) < VERSION:
		_migrate_heritage(owner, historical)
	sync_memories(owner)
	return legacy

func _migrate_heritage(owner: RefCounted, historical: Array) -> void:
	if "clearing_3" in historical: frontier_discount_steps = 2
	elif "clearing_2" in historical: frontier_discount_steps = 1
	for i in REMEMBRANCES.size(): decoded[i] = historical.has(REMEMBRANCES[i])
	# Reconstruct the last visible HG05 phase once, including automatically decoded entries.
	var previous := unlocked.duplicate()
	for id in RETIRED_COSTS.keys() + REMEMBRANCES:
		if historical.has(id) and not previous.has(id): previous.append(id)
	var memories := 0
	for i in decoded.size():
		memories += int(owner.campaign.memories[i])
		if previous.has("living_archive") and owner.campaign.memories[i] >= owner.Campaign.MEMORY_REQUIREMENTS[i] and not previous.has(REMEMBRANCES[i]):
			previous.append(REMEMBRANCES[i])
	historical_scale = maxi(0,previous.size()-1)
	if previous.has("living_archive") and memories >= 24: historical_stage = 4
	elif previous.size() >= 8 and owner.knowledge >= 50: historical_stage = 3
	elif previous.size() >= 4 and owner.knowledge >= 20: historical_stage = 2
	elif owner.plots.size() > 3 or owner.knowledge >= 8: historical_stage = 1

func unlock_direct(id: String) -> void:
	if not has(id) and not Catalog.get_node(id).is_empty(): unlocked.append(id)

func sync_legacy(owner: RefCounted) -> void:
	sync_memories(owner)

func sync_memories(owner: RefCounted) -> void:
	for i in decoded.size():
		if owner.campaign.memories[i] >= owner.Campaign.MEMORY_REQUIREMENTS[i]: decoded[i] = true

func available_insight(owner: RefCounted) -> int:
	return maxi(0,int(owner.knowledge)-spent)

func requirements(owner: RefCounted,id: String) -> String:
	var node:=Catalog.get_node(id)
	if node.is_empty(): return "Unknown memory."
	if has(id): return "Already restored."
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
	if id.ends_with("_coverage") or id.ends_with("_effectiveness"):
		owner.structures.revision += 1
	sync_memories(owner)

func clearing_bonus() -> int:
	return 1 + frontier_discount_steps if has("clearing_1") else 0

func development(owner: RefCounted) -> int:
	var additions := maxi(0,owner.structures.instances.size() - 4)
	return unlocked.size() - 1 + additions + 2 * int(owner.garden_development.get("revision",0))

func phase(owner: RefCounted) -> int:
	var points := development(owner)
	var stage := historical_stage
	for i in STAGE_THRESHOLDS.size():
		if points >= STAGE_THRESHOLDS[i]: stage = maxi(stage,i)
	return stage

func snapshot(owner: RefCounted) -> Dictionary:
	sync_legacy(owner)
	var result:=serialize()
	result["phase"]=phase(owner)
	result["development"]=maxi(historical_scale,development(owner))
	result["insight"]=available_insight(owner)
	result["knowledge_available"]=available_insight(owner)
	result["clearing"]=clearing_bonus()
	return result
