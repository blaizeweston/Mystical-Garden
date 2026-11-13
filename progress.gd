extends RefCounted
const SaveBatch=preload("res://save_batch.gd")

const Heart = preload("res://heart_progress.gd")
const HeartCatalog = preload("res://heart_catalog.gd")
const ContentIDs=preload("res://content_ids.gd")
var content_quarantine: Dictionary={}
var needs_content_backup:=false
var heart := Heart.new()
var needs_heart_backup := false
var needs_research_backup := false
const InventoryModel=preload("res://inventory_model.gd")
var component_crafts: Dictionary={}
var shared_components: Dictionary={}
var character_records: Dictionary={}
var item_stashes: Dictionary={}
var ground_items: Array=[]
var needs_inventory_backup:=false
var altar_recipes: Dictionary={}
var needs_altar_backup:=false
var garden_interactions: Dictionary=preload("res://garden_interaction_state.gd").blank()

const Seeds = preload("res://seed_catalog.gd")
const Parts = preload("res://weapon_parts.gd")
const Campaign = preload("res://campaign.gd")

static var PLANT_NAMES: Array = Seeds.NAMES
static var ALTAR_PAIRS: Array = Seeds.PAIRS
const VEILCAP := 2

var path := "user://garden.cfg"
var unknown: Array = []
var stock: Array = Seeds.counts(0)
var guest_seeds := {}
var discoveries: Array = Seeds.counts(false)
var attempted_pairs: Array = []
var seed_history: Array = [-1, 0]
var personal_parts := Parts.empty_counts()
const MAX_PLOTS := 9
const GROWTH_TIMES := [0.0, 18.0, 45.0, 80.0]
var needs_plot_backup := false
var needs_growth_backup:=false
var plots: Array = [empty_plot(), empty_plot(), empty_plot()]
var planted: Array = Seeds.counts(false)
var research_points := 0
var studying_flowering := false
var flowering_unlocked := false
var flowering: Array = Seeds.counts(false)
var harvest_ready: Array = Seeds.counts(false)
var parts: Array = Seeds.counts(0)
var knowledge := 0
var campaign := Campaign.new()
const Learning=preload("res://wilds_learning.gd")
var wilds_memory: Dictionary=Learning.blank()
var burst_pressure := 0
var choke_pressure := 0
var adaptation_quiet := [0, 0]
var ranged_pressure := 0
var quiet_expeditions := 0
var monster_materials: Array = Parts.empty_counts()
var monster_crafts: Array = []
var briar_hooks := 0
var crafted_hook := false
var heartwood_barbs := 0
var crafted_heartwood := false
var rift_hook_discovered := false
var studying_rift_hook := false
var rift_research_points := 0
const RIFT_RESEARCH_COST := 4
var veilcap_discovered := false
var crafted: Array = Seeds.counts(false)
const INFUSION_KNOWLEDGE := 5
const FLOWERING_COST := 3


func load_garden(recover_interrupted: bool=true) -> Error:
	if recover_interrupted:
		if SaveBatch.guarded_active():
			return load("res://persistence_operations.gd").read_serializer(self, _read_garden)
		var recovery := SaveBatch.recover(path)
		if recovery != OK:
			return recovery
	return _read_garden()

func load_garden_guarded() -> Dictionary:
	return load("res://persistence_operations.gd").load_serializer(path, _read_garden)

func _read_garden() -> Error:
	ensure_storage()
	var file := ConfigFile.new()
	var result := file.load(path)
	if result != OK:
		return result
	needs_content_backup=not file.has_section("content")
	ContentIDs.remap_garden(file)
	content_quarantine=file.get_value("content","quarantine",{})
	unknown = []
	var saved_unknown = file.get_value("garden", "unknown", [])
	if saved_unknown is Array:
		for kind in saved_unknown:
			if kind is int and kind >= 0 and kind < PLANT_NAMES.size():
				unknown.append(kind)
	for i in PLANT_NAMES.size():
		var amount = file.get_value("garden", "stock_%d" % i, 0)
		stock[i] = maxi(amount, 0) if amount is int else 0
		planted[i] = file.get_value("garden", "planted_%d" % i, false) == true
		flowering[i] = file.get_value("garden", "flowering_%d" % i, false) == true
		harvest_ready[i] = file.get_value("garden", "ready_%d" % i, planted[i]) == true
		var saved_parts = file.get_value("garden", "parts_%d" % i, 0)
		parts[i] = maxi(saved_parts, 0) if saved_parts is int else 0
		crafted[i] = file.get_value("garden", "crafted_%d" % i, false) == true
	var saved_plots = file.get_value("garden", "plots_v2", false)
	plots.clear()
	needs_plot_backup = not (saved_plots is Array)
	if saved_plots is Array:
		for item in saved_plots.slice(0, MAX_PLOTS):
			if item is Dictionary:
				var species := clampi(int(item.get("species", -1)), -1, PLANT_NAMES.size() - 1)
				plots.append({"species": species, "age": maxf(0.0,float(item.get("age",0.0))),
					"stage": clampi(int(item.get("stage",0)),0,3), "flowering": bool(item.get("flowering", false)) if species >= 0 else false})
				if species>=0:
					plots[-1].care=preload("res://garden_crop_state.gd").restore(item.get("care",{}),species)
					preload("res://cultivation_growth.gd").restore(item,plots[-1])
	else:
		# Migrate the former species-specific beds without discarding planted crops.
		for i in 3:
			plots.append({"species": i if planted[i] else -1, "age": 80.0 if harvest_ready[i] else 18.0,
				"stage": 3 if harvest_ready[i] else 1, "flowering": bool(flowering[i])})
			if planted[i]:
				preload("res://garden_crop_state.gd").ensure(plots[-1])
				preload("res://cultivation_growth.gd").restore({},plots[-1])
	while plots.size() < 3:
		plots.append(empty_plot())
	needs_growth_backup=not saved_plots is Array or saved_plots.any(func(b):return b is Dictionary and int(b.get("species",-1))>=0 and int(b.get("growth_rules",1))<2)
	advance_growth(0.0)
	veilcap_discovered = file.get_value("garden", "veilcap_discovered", false) == true
	var saved_discoveries = file.get_value("garden", "seed_discoveries", [])
	attempted_pairs = file.get_value("garden", "seed_attempts", [])
	if not attempted_pairs is Array:
		attempted_pairs = []
	for i in PLANT_NAMES.size():
		discoveries[i] = (saved_discoveries is Array and i < saved_discoveries.size() and saved_discoveries[i] == true) or stock[i] > 0 or planted[i] or (not file.has_section("altar") and (crafted[i] or parts[i] > 0))
	discoveries[VEILCAP] = discoveries[VEILCAP] or veilcap_discovered
	personal_parts = normalized_reserve({"parts": file.get_value("garden", "personal_parts", [])}).parts
	seed_history = normalized_reserve({"history": file.get_value("garden", "seed_history", [])}).history
	var reserves = file.get_value("garden", "guest_seeds", {})
	guest_seeds.clear()
	if reserves is Dictionary:
		for key in reserves:
			if key is String and reserves[key] is Dictionary:
				guest_seeds[key] = normalized_reserve(reserves[key])
				for species in PLANT_NAMES.size():
					discoveries[species] = discoveries[species] or guest_seeds[key].stock[species] > 0
	var grafts=file.get_value("garden","monster_crafts",[])
	monster_crafts=[]
	if grafts is Array:
		for part in grafts:
			if part is int and Parts.is_monster(part) and not monster_crafts.has(part): monster_crafts.append(part)
	monster_materials = normalized_reserve({"parts":file.get_value("garden","monster_materials",[])}).parts
	var hooks = file.get_value("garden", "briar_hooks", 0)
	briar_hooks = maxi(hooks, 0) if hooks is int else 0
	crafted_hook = file.get_value("garden", "crafted_hook", false) == true
	var barbs = file.get_value("garden", "heartwood_barbs", 0)
	heartwood_barbs = maxi(0, barbs) if barbs is int else 0
	crafted_heartwood = file.get_value("garden", "crafted_heartwood", false) == true
	rift_hook_discovered = file.get_value("garden", "rift_hook_discovered", false) == true
	studying_rift_hook = not rift_hook_discovered and file.get_value("garden", "studying_rift_hook", false) == true
	var rift_points = file.get_value("garden", "rift_research_points", 0)
	rift_research_points = clampi(rift_points, 0, RIFT_RESEARCH_COST) if rift_points is int else 0
	campaign.load_state(file)
	wilds_memory=Learning.normalize(file.get_value("wilds","memory_v1",{}))
	var pressure = file.get_value("wilds", "ranged_pressure", 0)
	ranged_pressure = clampi(pressure, 0, 8) if pressure is int else 0
	burst_pressure = clampi(int(file.get_value("wilds", "burst_pressure", 0)), 0, 8)
	choke_pressure = clampi(int(file.get_value("wilds", "choke_pressure", 0)), 0, 8)
	var quiet_tactics = file.get_value("wilds", "adaptation_quiet", [0,0])
	if quiet_tactics is Array and quiet_tactics.size() == 2:
		adaptation_quiet = [clampi(int(quiet_tactics[0]),0,1), clampi(int(quiet_tactics[1]),0,1)]
	var quiet = file.get_value("wilds", "quiet_expeditions", 0)
	quiet_expeditions = clampi(quiet, 0, 1) if quiet is int else 0
	var saved_knowledge = file.get_value("garden", "knowledge", 0)
	knowledge = maxi(saved_knowledge, 0) if saved_knowledge is int else 0
	var points = file.get_value("garden", "research_points", 0)
	research_points = clampi(points, 0, FLOWERING_COST) if points is int else 0
	studying_flowering = file.get_value("garden", "studying_flowering", false) == true
	flowering_unlocked = file.get_value("garden", "flowering_unlocked", false) == true
	component_crafts=file.get_value("content","component_crafts",{})
	if not component_crafts is Dictionary: component_crafts={}
	shared_components=file.get_value("content","shared_components",{})
	if not shared_components is Dictionary: shared_components={}
	character_records=file.get_value("characters","records",{})
	if not character_records is Dictionary: character_records={}
	item_stashes={}
	var stashes=file.get_value("inventory","stashes",{})
	if stashes is Dictionary:
		for owner in stashes:
			if owner is String: item_stashes[owner]=InventoryModel.Items.clean_counts(stashes[owner])
	ground_items=InventoryModel.clean_ground(file.get_value("inventory","ground",[]))
	garden_interactions=preload("res://garden_interaction_state.gd").normalize(file.get_value("garden_interactions","state",{}))
	altar_recipes={}
	var recorded=file.get_value("altar","recipes",{})
	if recorded is Dictionary:
		for key in recorded:
			if key is String and recorded[key] is Dictionary and recorded[key].get("item") is String and not InventoryModel.Items.get_item(recorded[key].item).is_empty():
				altar_recipes[key]={"item":recorded[key].item,"success":recorded[key].get("success",false)==true}
	needs_altar_backup=not file.has_section("altar")
	if needs_altar_backup:
		for pair in attempted_pairs:
			if not pair is Array or pair.size()!=2 or not pair[0] is int or not pair[1] is int or pair[0]<0 or pair[1]<0 or pair[0]>=PLANT_NAMES.size() or pair[1]>=PLANT_NAMES.size(): continue
			var child:=Seeds.recipe(int(pair[0]),int(pair[1]))
			var inputs: Array=[InventoryModel.Items.seed_id(int(pair[0])),InventoryModel.Items.seed_id(int(pair[1]))];inputs.sort()
			var result_id: String
			if child>=0:
				if not discoveries[child]: continue
				result_id=InventoryModel.Items.seed_id(child)
			else:
				var first:=int(InventoryModel.Items.get_item(inputs[0]).legacy_seed)
				result_id=InventoryModel.Items.part_id(int(Seeds.DEFINITIONS[first].part))
			altar_recipes["seeds|"+"|".join(inputs)]={"item":result_id,"success":child>=0}
	needs_inventory_backup=not file.has_section("inventory")
	needs_heart_backup=heart.load_state(file,self)
	garden_interactions=preload("res://garden_growth_state.gd").initialize(garden_interactions,preload("res://garden_growth_state.gd").snapshot(self))
	garden_interactions=preload("res://garden_return_state.gd").initialize(garden_interactions)
	return OK


func save_garden() -> Error:
	if SaveBatch.guarded_active():
		return load("res://persistence_operations.gd").stage_serializer(self, _serialize_save)
	return _serialize_save()

func save_garden_guarded() -> Dictionary:
	var before := garden_interactions.duplicate(true)
	var outcome: Dictionary = load("res://persistence_operations.gd").run_serializers([self], path, save_garden)
	if outcome.ran and outcome.value.get("outcome") != null and outcome.value.outcome.outcome == SaveBatch.Outcome.ABORTED_RESTORED:
		garden_interactions = before
	return outcome

func migration_backup_paths() -> PackedStringArray:
	return PackedStringArray([path + ".pre-tier-growth-v2.bak", path + ".pre-timed-research-v2.bak", path + ".pre-content-v2.bak", path + ".pre-altar-v1.bak", path + ".pre-inventory-v1.bak", path + ".pre-heart-v1.bak", path + ".pre-plots-v2.bak"])

func _migration_backup(target: String, guarded: bool) -> Error:
	if guarded:
		return load("res://persistence_operations.gd").backup_serializer(path, target)
	return OK if FileAccess.file_exists(target) else DirAccess.copy_absolute(path, target)

func _serialize_save(stage := Callable()) -> Error:
	ensure_storage()
	if needs_growth_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-tier-growth-v2.bak", stage.is_valid())
		if copied != OK:
			return copied
		if not stage.is_valid():
			needs_growth_backup = false
	if needs_research_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-timed-research-v2.bak", stage.is_valid())
		if copied != OK:
			return copied
		if not stage.is_valid():
			needs_research_backup = false
	if needs_content_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-content-v2.bak", stage.is_valid())
		if copied != OK:
			return copied
		if not stage.is_valid():
			needs_content_backup = false
	if needs_altar_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-altar-v1.bak", stage.is_valid())
		if copied != OK:
			return copied
		if not stage.is_valid():
			needs_altar_backup = false
	if needs_inventory_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-inventory-v1.bak", stage.is_valid())
		if copied != OK:
			return copied
		if not stage.is_valid():
			needs_inventory_backup = false
	if needs_heart_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-heart-v1.bak", stage.is_valid())
		if copied != OK:
			return copied
		if not stage.is_valid():
			needs_heart_backup = false
	if needs_plot_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-plots-v2.bak", stage.is_valid())
		if copied != OK:
			return copied
		if not stage.is_valid():
			needs_plot_backup = false
	var file := ConfigFile.new()
	file.set_value("content","component_crafts",component_crafts)
	file.set_value("content","shared_components",shared_components)
	file.set_value("characters","records",character_records)
	file.set_value("content","manifest",ContentIDs.manifest())
	file.set_value("content","quarantine",content_quarantine)
	sync_plot_flags()
	file.set_value("altar","recipes",altar_recipes)
	file.set_value("inventory","stashes",item_stashes)
	file.set_value("inventory","ground",ground_items)
	var growth_state:=preload("res://garden_growth_state.gd").prepare(self)
	file.set_value("garden_interactions","state",growth_state)
	file.set_value("garden", "plots_v2", plots)
	file.set_value("garden", "unknown", unknown)
	file.set_value("garden", "guest_seeds", guest_seeds)
	file.set_value("garden", "seed_history", seed_history)
	file.set_value("garden", "personal_parts", personal_parts)
	file.set_value("garden", "research_points", research_points)
	file.set_value("garden", "seed_discoveries", discoveries)
	file.set_value("garden", "seed_attempts", attempted_pairs)
	file.set_value("garden", "knowledge", knowledge)
	file.set_value("heart","state",heart.serialize())
	campaign.write_state(file)
	file.set_value("wilds","memory_v1",wilds_memory)
	file.set_value("wilds", "ranged_pressure", ranged_pressure)
	file.set_value("wilds", "burst_pressure", burst_pressure)
	file.set_value("wilds", "choke_pressure", choke_pressure)
	file.set_value("wilds", "adaptation_quiet", adaptation_quiet)
	file.set_value("wilds", "quiet_expeditions", quiet_expeditions)
	file.set_value("garden","monster_crafts",monster_crafts)
	file.set_value("garden","monster_materials",monster_materials)
	file.set_value("garden", "briar_hooks", briar_hooks)
	file.set_value("garden", "crafted_hook", crafted_hook)
	file.set_value("garden", "heartwood_barbs", heartwood_barbs)
	file.set_value("garden", "crafted_heartwood", crafted_heartwood)
	file.set_value("garden", "rift_hook_discovered", rift_hook_discovered)
	file.set_value("garden", "studying_rift_hook", studying_rift_hook)
	file.set_value("garden", "rift_research_points", rift_research_points)
	file.set_value("garden", "veilcap_discovered", veilcap_discovered)
	file.set_value("garden", "studying_flowering", studying_flowering)
	file.set_value("garden", "flowering_unlocked", flowering_unlocked)
	for i in PLANT_NAMES.size():
		file.set_value("garden", "stock_%d" % i, stock[i])
		file.set_value("garden", "planted_%d" % i, planted[i])
		file.set_value("garden", "flowering_%d" % i, flowering[i])
		file.set_value("garden", "ready_%d" % i, harvest_ready[i])
		file.set_value("garden", "parts_%d" % i, parts[i])
		file.set_value("garden", "crafted_%d" % i, crafted[i])
	var bytes := file.encode_to_text().to_utf8_buffer()
	var saved: Error = (stage.call(path, bytes) if stage.is_valid() else SaveBatch.write(path, bytes))
	if saved==OK:garden_interactions=growth_state
	return saved


func remember_expedition(ranged_clears: int, burst_clears: int = 0, choke_clears: int = 0) -> void:
	var pressures := [burst_pressure, choke_pressure]
	var observations := [burst_clears, choke_clears]
	for i in 2:
		if observations[i] > 0:
			pressures[i] = mini(8, int(pressures[i]) + int(observations[i]))
			adaptation_quiet[i] = 0
		elif pressures[i] > 0:
			adaptation_quiet[i] += 1
			if adaptation_quiet[i] >= 2:
				pressures[i] -= 1
				adaptation_quiet[i] = 0
	burst_pressure = pressures[0]
	choke_pressure = pressures[1]
	if ranged_clears > 0:
		ranged_pressure = mini(8, ranged_pressure + ranged_clears)
		quiet_expeditions = 0
	elif ranged_pressure > 0:
		quiet_expeditions += 1
		if quiet_expeditions == 2:
			ranged_pressure -= 1
			quiet_expeditions = 0


func apply_milestone(depth: int) -> String:
	if depth == 0:
		return ""
	return advance_research(depth)


func advance_research(points: int) -> String:
	return heart.advance(self,points)


func discover_rift_hook() -> void:
	if not rift_hook_discovered:
		knowledge += 4
	rift_hook_discovered = true
	heart.unlock_direct("rift_hook")
	studying_rift_hook = false


func heart_restored() -> bool:
	return heart.has("perfect_recollection") and flowering_unlocked and veilcap_discovered and rift_hook_discovered and (
		knowledge >= Campaign.FULL_KNOWLEDGE and campaign.memories_complete())


func finale_available() -> bool:
	if not Campaign.LEGACY_ENDING_ENABLED: return false
	return campaign.ending == Campaign.UNFINISHED and heart_restored() and (
		not campaign.offshoots.has(Campaign.PENDING))


func pay_shortcut(cost: int, reserved: Array = []) -> Error:
	var total := 0
	for i in parts.size():
		total += maxi(0,int(parts[i])-(int(reserved[i]) if i<reserved.size() else 0))
	if total < cost:
		return ERR_UNAVAILABLE
	var before := parts.duplicate()
	var remaining := cost
	for i in parts.size():
		var spent := mini(maxi(0,int(parts[i])-(int(reserved[i]) if i<reserved.size() else 0)), remaining)
		parts[i] -= spent
		remaining -= spent
	var result := save_garden()
	if result != OK:
		parts.assign(before)
	return result


func part_count(part: int) -> int:
	if part<=0 or part>=Parts.DEFINITIONS.size() or Parts.DEFINITIONS[part].get("retired",false): return 0
	if Parts.DEFINITIONS[part].get("rare",false): return int(shared_components.get(Parts.DEFINITIONS[part].id,0))
	if Parts.is_monster(part) and part != Parts.HOOK:
		return int(monster_materials[part])
	match part:
		Parts.HOOK:
			return briar_hooks
		Parts.HEARTWOOD:
			return heartwood_barbs
	return int(parts[Seeds.species_for_part(part)])


func add_parts(part: int, count: int) -> void:
	if part<=0 or part>=Parts.DEFINITIONS.size() or Parts.DEFINITIONS[part].get("retired",false): return
	if Parts.DEFINITIONS[part].get("rare",false):
		var id: String=Parts.DEFINITIONS[part].id;shared_components[id]=maxi(0,int(shared_components.get(id,0))+count);return
	if Parts.is_monster(part) and part != Parts.HOOK:
		monster_materials[part] += count
		return
	match part:
		Parts.HOOK:
			briar_hooks += count
		Parts.HEARTWOOD:
			heartwood_barbs += count
		_:
			parts[Seeds.species_for_part(part)] += count


func record_part_craft(part: int) -> int:
	var seen: bool
	match part:
		Parts.HOOK:
			seen = crafted_hook
			crafted_hook = true
		Parts.HEARTWOOD:
			seen = crafted_heartwood
			crafted_heartwood = true
		_:
			seen = crafted[Seeds.species_for_part(part)]
			crafted[Seeds.species_for_part(part)] = true
	var id: String=Parts.DEFINITIONS[part].id
	if component_crafts.has(id): seen=bool(component_crafts[id])
	elif Parts.DEFINITIONS[part].get("rare",false): seen=false
	component_crafts[id]=true
	var gained := 1 if seen else 4
	knowledge += gained
	return gained


func reserve(owner: String) -> Dictionary:
	ensure_storage()
	if owner.is_empty():
		return {"unknown": unknown, "stock": stock, "parts": personal_parts, "history": seed_history}
	if not guest_seeds.has(owner):
		guest_seeds[owner] = normalized_reserve({})
	return guest_seeds[owner]


func normalized_reserve(source: Dictionary) -> Dictionary:
	var result := {"unknown": [], "stock": Seeds.counts(), "parts": Parts.empty_counts(), "history": [-1, 0]}
	var history = source.get("history")
	if history is Array and history.size() == 2 and history[0] is int and history[1] is int:
		result.history = [clampi(history[0], -1, PLANT_NAMES.size() - 1), clampi(history[1], 0, 2)]
	if source.get("parts") is Array:
		for part in range(1, mini(source.parts.size(), Parts.DEFINITIONS.size())):
			if source.parts[part] is int:
				result.parts[part] = maxi(0, source.parts[part])
	if source.get("unknown") is Array:
		for kind in source.unknown:
			if kind is int and kind >= 0 and kind < PLANT_NAMES.size():
				result.unknown.append(kind)
	if source.get("stock") is Array:
		for kind in mini(source.stock.size(), PLANT_NAMES.size()):
			if source.stock[kind] is int:
				result.stock[kind] = maxi(0, source.stock[kind])
	return result


func ensure_storage() -> void:
	for entry in [[stock, 0], [planted, false], [flowering, false], [harvest_ready, false], [parts, 0], [crafted, false], [discoveries, false]]:
		while entry[0].size() < PLANT_NAMES.size():
			entry[0].append(entry[1])

func discover(kind: int) -> bool:
	ensure_storage()
	if discoveries[kind]:
		return false
	discoveries[kind] = true
	knowledge += 4
	if kind == VEILCAP:
		veilcap_discovered = true
	return true

func breed(first: int, second: int, stock_for_player: Array) -> String:
	if first < 0 or second < 0 or first >= PLANT_NAMES.size() or second >= PLANT_NAMES.size() or stock_for_player.size() < PLANT_NAMES.size():
		return ""
	if stock_for_player[first] < (2 if first == second else 1) or stock_for_player[second] < 1:
		return ""
	stock_for_player[first] -= 1
	stock_for_player[second] -= 1
	var pair := [mini(first, second), maxi(first, second)]
	if not attempted_pairs.has(pair):
		attempted_pairs.append(pair)
	var child := Seeds.recipe(first, second)
	if child < 0:
		parts[first] += 1
		return "Incompatible seeds. Recovered one %s part. Clue: %s" % [PLANT_NAMES[first], next_seed_hint(first)]
	stock_for_player[child] += 1
	var fresh := discover(child)
	return ("%s %s. Recipe permanently recorded. One seed gained." % ["Discovered" if fresh else "Cultivated", PLANT_NAMES[child]])

func next_seed_hint(parent: int) -> String:
	for entry in Seeds.DEFINITIONS:
		if entry.parents.has(parent) and not discoveries[Seeds.NAMES.find(entry.name)]:
			return entry.hint
	return "Different species may share a hidden affinity. Try another lineage."

func experiment(choice: int, stock_for_player: Array) -> String:
	if choice < 0 or choice >= ALTAR_PAIRS.size():
		return ""
	# Legacy callers may provide a short array; expand without losing stock.
	while stock_for_player.size() < PLANT_NAMES.size():
		stock_for_player.append(0)
	var pair: Array = ALTAR_PAIRS[choice]
	return breed(int(pair[0]), int(pair[1]), stock_for_player)


func roll_seed(personal: Dictionary, carried: Array, bundle: Array, site: int, roll: float, encounter: int = 1) -> int:
	var moss_chance: float = [0.40, 0.68, 0.52][site]
	var kind := 1 if roll < moss_chance else 0
	if encounter >= 3:
		var candidates: Array[int] = []
		var weights: Array[float] = []
		var total := 0.0
		for i in Seeds.DEFINITIONS.size():
			var entry: Dictionary = Seeds.DEFINITIONS[i]
			if encounter < int(entry.wild_min):
				continue
			var weight: float = [70.0, 22.0, 6.0, 1.5, 0.25][int(entry.tier) - 1]
			weight *= 1.5 if int(entry.biome) == site else 1.0
			if personal.history[0] == i or bundle.has(i):
				weight *= 0.2
			total += weight
			candidates.append(i)
			weights.append(weight)
		var ticket := clampf(roll, 0.0, 0.999999) * total
		for n in candidates.size():
			ticket -= weights[n]
			if ticket < 0.0:
				kind = candidates[n]
				break
	for i in VEILCAP:
		if not planted[i] and personal.stock[i] == 0 and not personal.unknown.has(i) and not carried.has(i):
			kind = i
			break
	var history: Array = personal.history
	if encounter < 3 and history[0] == kind and history[1] >= 2:
		kind = 1 - kind
	if encounter < 3 and bundle.has(kind):
		kind = 1 - kind
	history[1] = mini(2, history[1] + 1) if history[0] == kind else 1
	history[0] = kind
	return kind


static func empty_plot() -> Dictionary:
	return {"species": -1, "age": 0.0, "stage": 0, "flowering": false}


func sync_plot_flags() -> void:
	ensure_storage()
	planted.fill(false)
	flowering.fill(false)
	harvest_ready.fill(false)
	for bed in plots:
		var kind := int(bed.species)
		if kind >= 0:
			planted[kind] = true
			flowering[kind] = flowering[kind] or bed.flowering
			harvest_ready[kind] = harvest_ready[kind] or bed.stage == 3


func advance_growth(seconds: float,in_wilds: bool=false) -> bool:
	var changed := false
	for bed in plots:
		if bed.species < 0:
			bed.stage = 0
			continue
		changed=preload("res://garden_crop_state.gd").ensure(bed) or changed
		if not preload("res://cultivation_growth.gd").supported(bed):continue
		preload("res://cultivation_growth.gd").initialize(bed)
		var base: float = Seeds.DEFINITIONS[int(bed.species)].grow_seconds
		var duration: float = preload("res://garden_crop_state.gd").duration(bed,base)
		var previous_age: float=bed.age
		bed.age = minf(duration, float(bed.age) + maxf(0,seconds) * preload("res://cultivation_growth.gd").rate(self,bed,in_wilds))
		changed=changed or int(previous_age/preload("res://cultivation_growth.gd").SAVE_WORK_INTERVAL)!=int(bed.age/preload("res://cultivation_growth.gd").SAVE_WORK_INTERVAL)
		var stage := 0
		for i in range(1, 4):
			if bed.age >= (duration if i==3 else GROWTH_TIMES[i] * base / 80.0):
				stage = i
		if stage!=bed.stage:preload("res://garden_crop_state.gd").bump(bed)
		changed = changed or stage != bed.stage
		bed.stage = stage
	sync_plot_flags()
	return changed


func expand_plot() -> Error:
	if plots.size()>=MAX_PLOTS: return ERR_UNAVAILABLE
	var id: String="plot_%d"%(plots.size()+1)
	if not heart.requirements(self,id).is_empty(): return ERR_UNAVAILABLE
	heart.start(self,id)
	return OK if heart.paid.has(id) or plots.size()==int(id.trim_prefix("plot_")) else ERR_CANT_CREATE


func offshoot_in_bed(slot: int) -> int:
	if not Campaign.LEGACY_ENDING_ENABLED: return -1
	return campaign.offshoot_beds.find(slot)
func plot_snapshot() -> PackedByteArray:
	var packed := PackedByteArray()
	for i in plots.size():
		var bed: Dictionary=plots[i];var offshoot:=offshoot_in_bed(i)
		packed.append(int(bed.species)+1)
		packed.append(3 if offshoot>=0 and campaign.offshoots[offshoot]==Campaign.MATURE else int(bed.stage))
		packed.append(int(bed.flowering)|((offshoot+1)<<2))
	return packed


static func decode_plots(packed: PackedByteArray) -> Array:
	var beds: Array = []
	for i in range(0, packed.size() - 2, 3):
		beds.append({"species": int(packed[i]) - 1, "stage": int(packed[i + 1]), "flowering": (packed[i+2]&1)!=0,"offshoot":((packed[i+2]>>2)&3)-1 if Campaign.LEGACY_ENDING_ENABLED else -1})
	return beds

func record_monster_graft(part: int) -> void:
	if not Parts.is_monster(part): return
	knowledge += 1 if monster_crafts.has(part) else 4
	if not monster_crafts.has(part): monster_crafts.append(part)
