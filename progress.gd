extends RefCounted
var require_guarded_access := false
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
const Archive = preload("res://living_archive.gd")
var archive := Archive.fresh()
var character_records: Dictionary={}
var projection_origin := ""
## Present only after an explicit host Save & Quit. Consumed through the Garden transaction.
var suspended_expedition := {}
var item_stashes: Dictionary={}
var ground_items: Array=[]
var needs_inventory_backup:=false
var altar_recipes: Dictionary={}
var needs_altar_backup:=false
const GardenDevelopment = preload("res://garden_development_state.gd")
var garden_development: Dictionary = {}
var garden_development_error := ""
var garden_interactions: Dictionary=preload("res://garden_interaction_state.gd").blank()

const Seeds = preload("res://seed_catalog.gd")
const Parts = preload("res://weapon_parts.gd")
const Campaign = preload("res://campaign.gd")

static var PLANT_NAMES: Array = Seeds.NAMES
const VEILCAP := 2

var path := "user://garden.cfg"
var unknown: Array = []
var stock: Array = Seeds.counts(0)
var guest_seeds := {}
var discoveries: Array = Seeds.counts(false)
var attempted_pairs: Array = []
var seed_history: Array = [-1, 0]
var personal_parts := Parts.empty_counts()
const Structures = preload("res://garden_structure_inventory.gd")
var structures := Structures.new_garden()
var irrigation := preload("res://garden_irrigation.gd").new()
var needs_heart_economy_backup := false
var needs_cultivation_backup := false
var needs_irrigation_backup := false
var needs_construction_backup := false
const GROWTH_TIMES := [0.0, 18.0, 45.0, 80.0]
var needs_plot_backup := false
var needs_growth_backup:=false
var plots: Array = [empty_plot(), empty_plot(), empty_plot()]
var planted: Array = Seeds.counts(false)
var flowering: Array = Seeds.counts(false)
var harvest_ready: Array = Seeds.counts(false)
var parts: Array = Seeds.counts(0)
var knowledge := 0
var player_placed_beds := false
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
var veilcap_discovered := false
var crafted: Array = Seeds.counts(false)


func load_garden(recover_interrupted: bool=true) -> Error:
	if recover_interrupted:
		if SaveBatch.guarded_active():
			return load("res://persistence_operations.gd").read_serializer(self, _read_garden)
		if require_guarded_access:
			return ERR_UNAUTHORIZED
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
	var suspended: Variant = file.get_value("expedition", "suspended", {})
	if not suspended is Dictionary: return ERR_FILE_CORRUPT
	suspended_expedition = suspended
	var development: Variant = file.get_value("garden_development", "state", {})
	garden_development_error = GardenDevelopment.refusal(development)
	if not garden_development_error.is_empty():
		return ERR_FILE_CORRUPT
	garden_development = development.duplicate(true)
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
	var historic_crop_source := ""
	var saved_plots = file.get_value("garden", "plots_v2", false)
	plots.clear()
	needs_plot_backup = not (saved_plots is Array)
	if saved_plots is Array:
		for item in saved_plots:
			if item is Dictionary:
				var species := clampi(int(item.get("species", -1)), -1, PLANT_NAMES.size() - 1)
				plots.append({"species": species, "age": maxf(0.0,float(item.get("age",0.0))),
					"stage": clampi(int(item.get("stage",0)),0,3), "flowering": bool(item.get("flowering", false)) if species >= 0 else false})
				if species>=0:
					var saved_care: Variant = item.get("care",{})
					if (not saved_care is Dictionary or saved_care.is_empty()) and historic_crop_source.is_empty():
						historic_crop_source = file.encode_to_text().sha256_text()
					plots[-1].care=preload("res://garden_crop_state.gd").restore(saved_care,species,historic_crop_source+":"+str(plots.size()-1))
					preload("res://cultivation_growth.gd").restore(item,plots[-1])
	else:
		# Migrate the former species-specific beds without discarding planted crops.
		for i in 3:
			plots.append({"species": i if planted[i] else -1, "age": 80.0 if harvest_ready[i] else 18.0,
				"stage": 3 if harvest_ready[i] else 1, "flowering": bool(flowering[i])})
			if planted[i]:
				if historic_crop_source.is_empty(): historic_crop_source = file.encode_to_text().sha256_text()
				plots[-1].care=preload("res://garden_crop_state.gd").restore({},i,historic_crop_source+":"+str(i))
				preload("res://cultivation_growth.gd").restore({},plots[-1])
	while plots.size() < 3:
		plots.append(empty_plot())
	needs_growth_backup=not saved_plots is Array or saved_plots.any(func(b):return b is Dictionary and int(b.get("species",-1))>=0 and int(b.get("growth_rules",1))<2)
	veilcap_discovered = file.get_value("garden", "veilcap_discovered", false) == true
	var saved_discoveries = file.get_value("garden", "seed_discoveries", [])
	attempted_pairs = file.get_value("garden", "seed_attempts", [])
	if not attempted_pairs is Array:
		attempted_pairs = []
	for i in PLANT_NAMES.size():
		discoveries[i] = (saved_discoveries is Array and i < saved_discoveries.size() and saved_discoveries[i] == true) or stock[i] > 0 or planted[i] or (not file.has_section("altar") and not Seeds.wild_only(i) and (crafted[i] or parts[i] > 0))
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
	component_crafts=file.get_value("content","component_crafts",{})
	if not component_crafts is Dictionary: component_crafts={}
	shared_components=file.get_value("content","shared_components",{})
	if not shared_components is Dictionary: shared_components={}
	character_records=file.get_value("characters","records",{})
	if not character_records is Dictionary: character_records={}
	var origin: Variant = file.get_value("characters", "projection_origin", "")
	if not origin is String or (not origin.is_empty() and not load("res://guest_profile_projection.gd").valid_origin(origin)):
		return ERR_INVALID_DATA
	projection_origin = origin
	if file.has_section_key("archive","records"):
		var records: Variant = file.get_value("archive","records")
		if not Archive.valid(records): return ERR_INVALID_DATA
		archive = records
	else: archive = Archive.fresh(origin)
	var historical_ancient := not file.has_section_key("inventory","ancient_seed_format")
	item_stashes={}
	var stashes=file.get_value("inventory","stashes",{})
	if stashes is Dictionary:
		for owner in stashes:
			if owner is String: item_stashes[owner]=InventoryModel.Items.clean_counts(stashes[owner],historical_ancient)
	ground_items=InventoryModel.clean_ground(file.get_value("inventory","ground",[]),historical_ancient)
	garden_interactions=preload("res://garden_interaction_state.gd").normalize(file.get_value("garden_interactions","state",{}))
	altar_recipes={}
	var recorded=file.get_value("altar","recipes",{})
	if recorded is Dictionary:
		for key in recorded:
			if key is String and recorded[key] is Dictionary and recorded[key].get("item") is String and not InventoryModel.Items.get_item(recorded[key].item).is_empty():
				altar_recipes[key]={"item":recorded[key].item,"success":recorded[key].get("success",false)==true}
				if recorded[key].get("historical_success",false)==true: altar_recipes[key].historical_success=true
	needs_altar_backup=not file.has_section("altar")
	if needs_altar_backup:
		for pair in attempted_pairs:
			if not pair is Array or pair.size()!=2 or not pair[0] is int or not pair[1] is int or pair[0]<0 or pair[1]<0 or pair[0]>=PLANT_NAMES.size() or pair[1]>=PLANT_NAMES.size(): continue
			var child:=Seeds.lineage_child(int(pair[0]),int(pair[1]))
			if child>=0 and Seeds.wild_only(child): continue
			var inputs: Array=[InventoryModel.Items.seed_id(int(pair[0])),InventoryModel.Items.seed_id(int(pair[1]))];inputs.sort()
			var result_id: String
			if child>=0:
				if not discoveries[child]: continue
				result_id=InventoryModel.Items.seed_id(child)
			else:
				var first:=int(InventoryModel.Items.get_item(inputs[0]).legacy_seed)
				result_id=InventoryModel.Items.part_id(int(Seeds.DEFINITIONS[first].part))
			altar_recipes["seeds|"+"|".join(inputs)]={"item":result_id,"success":child>=0}
	garden_development_error = GardenDevelopment.refusal(garden_development, plots.size())
	if not garden_development_error.is_empty():
		return ERR_FILE_CORRUPT
	needs_inventory_backup=not file.has_section("inventory")
	var heart_data: Variant = file.get_value("heart", "state", {})
	if not heart_data is Dictionary or heart_data.get("version", 0) not in [0, 1, 2, 3, 4, 5, heart.VERSION]:
		garden_development_error = "Unsupported Heart research record."
		return ERR_FILE_CORRUPT
	needs_research_backup = heart_data.get("version") in [1, 2] or garden_development.get("version") == 1
	if garden_development.get("version") == 1:
		# A batch was removed only when its full Knowledge was paid. Energy
		# and material consumption were already durable on contribution.
		for batch in garden_development.queue: knowledge += int(batch.knowledge)
		garden_development.erase("queue")
		garden_development.version = 2
	needs_cultivation_backup = int(heart_data.get("version",0)) < 5
	needs_heart_economy_backup = int(heart_data.get("version",0)) < heart.VERSION
	needs_heart_backup=heart.load_state(file,self)
	needs_irrigation_backup = false
	needs_construction_backup = not file.has_section_key("construction","inventory")
	if needs_construction_backup:
		if plots.size() > Structures.Catalog.ORIGINAL_BEDS.size() or garden_development.get("version") == GardenDevelopment.VERSION:
			garden_development_error = "Missing construction ownership for saved beds or terrain."
			return ERR_FILE_CORRUPT
		structures = Structures.migrate(garden_development,plots,heart.unlocked,heart_data)
		if not garden_development.is_empty():
			garden_development.erase("buildings")
			garden_development.erase("next_id")
			garden_development.version = GardenDevelopment.VERSION
	else:
		var inventory: Variant = file.get_value("construction","inventory")
		needs_irrigation_backup = inventory is Dictionary and inventory.get("version") == 1
		if needs_irrigation_backup: inventory.version = 2
		if not Structures.valid(inventory,plots):
			garden_development_error = "Invalid saved construction inventory."
			return ERR_FILE_CORRUPT
		if needs_irrigation_backup and heart.has("irrigation"):
			Structures.grant_research(inventory,"irrigation")
		structures = inventory
	if int(heart_data.get("version", 0)) < 5:
		for tech in ["nursery","vital_roots","bud_sanctuary"]:
			if heart.has(tech): Structures.grant_research(structures,tech)
		garden_interactions.erase("conduit")
	if not Structures.valid(structures,plots):
		garden_development_error = "Historical structures and crop slots disagree."
		return ERR_FILE_CORRUPT
	advance_growth(0.0)
	garden_interactions=preload("res://garden_growth_state.gd").load_history(garden_interactions,self)
	garden_interactions=preload("res://garden_return_state.gd").initialize(garden_interactions)
	return OK


func save_garden() -> Error:
	if SaveBatch.guarded_active():
		return load("res://persistence_operations.gd").stage_serializer(self, _serialize_save)
	if require_guarded_access:
		return ERR_UNAUTHORIZED
	if SaveBatch.active and not SaveBatch.Legacy.held() and not SaveBatch.Legacy.fixture_path(path):
		return SaveBatch.record_serializer_error(ERR_UNAUTHORIZED, path)
	var error := SaveBatch.Legacy.run(PackedStringArray([path]), func(_plan): return _serialize_save(), migration_backup_paths())
	error = SaveBatch.record_serializer_error(error, path)
	if error == OK:
		SaveBatch.legacy_serializer_saved(self)
	return error

func save_garden_guarded() -> Dictionary:
	if require_guarded_access:
		return {"error": ERR_UNAUTHORIZED, "ran": false, "reason": "session_context_required"}
	var before := garden_interactions.duplicate(true)
	var outcome: Dictionary = load("res://persistence_operations.gd").run_serializers([self], path, save_garden)
	if outcome.ran and outcome.value.get("outcome") != null and outcome.value.outcome.outcome == SaveBatch.Outcome.ABORTED_RESTORED:
		garden_interactions = before
	return outcome

func migration_backup_paths() -> PackedStringArray:
	return PackedStringArray([path + ".pre-heart-economy-v6.bak", path + ".pre-cultivation-v5.bak", path + ".pre-irrigation-v2.bak", path + ".pre-construction-v1.bak", path + ".pre-tier-growth-v2.bak", path + ".pre-timed-research-v2.bak", path + ".pre-immediate-heart-v3.bak", path + ".pre-content-v2.bak", path + ".pre-altar-v1.bak", path + ".pre-inventory-v1.bak", path + ".pre-heart-v1.bak", path + ".pre-plots-v2.bak"])

func confirm_migration(saved_path: String) -> void:
	if path != saved_path:
		return
	needs_heart_economy_backup = false
	needs_cultivation_backup = false
	needs_irrigation_backup = false
	needs_construction_backup = false
	needs_growth_backup = false
	needs_research_backup = false
	needs_content_backup = false
	needs_altar_backup = false
	needs_inventory_backup = false
	needs_heart_backup = false
	needs_plot_backup = false

func _migration_backup(target: String, guarded: bool) -> Error:
	if guarded:
		return load("res://persistence_operations.gd").backup_serializer(path, target)
	if DirAccess.dir_exists_absolute(target):
		return ERR_FILE_CANT_WRITE
	return OK if FileAccess.file_exists(target) else DirAccess.copy_absolute(path, target)

func _serialize_save(stage := Callable()) -> Error:
	if not Structures.valid(structures,plots) or not garden_development_error.is_empty() or not GardenDevelopment.refusal(garden_development, plots.size()).is_empty():
		return SaveBatch.record_serializer_error(ERR_FILE_CORRUPT, path)
	if require_guarded_access or SaveBatch.guarded_active():
		var operations = load("res://persistence_operations.gd")
		if not operations.authorizes_serializer(self, stage):
			return SaveBatch.record_serializer_error(ERR_UNAUTHORIZED, path)
	ensure_storage()
	if needs_heart_economy_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-heart-economy-v6.bak", stage.is_valid())
		if copied != OK: return copied
	if needs_cultivation_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-cultivation-v5.bak", stage.is_valid())
		if copied != OK: return copied
	if needs_irrigation_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-irrigation-v2.bak", stage.is_valid())
		if copied != OK: return copied
	if needs_construction_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-construction-v1.bak", stage.is_valid())
		if copied != OK: return copied
	if needs_growth_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-tier-growth-v2.bak", stage.is_valid())
		if copied != OK:
			return copied
	if needs_research_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-immediate-heart-v3.bak", stage.is_valid())
		if copied != OK:
			return copied
	if needs_content_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-content-v2.bak", stage.is_valid())
		if copied != OK:
			return copied
	if needs_altar_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-altar-v1.bak", stage.is_valid())
		if copied != OK:
			return copied
	if needs_inventory_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-inventory-v1.bak", stage.is_valid())
		if copied != OK:
			return copied
	if needs_heart_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-heart-v1.bak", stage.is_valid())
		if copied != OK:
			return copied
	if needs_plot_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-plots-v2.bak", stage.is_valid())
		if copied != OK:
			return copied
	var file := ConfigFile.new()
	if not suspended_expedition.is_empty(): file.set_value("expedition","suspended",suspended_expedition)
	file.set_value("content","component_crafts",component_crafts)
	file.set_value("content","shared_components",shared_components)
	file.set_value("archive","records",archive)
	file.set_value("characters","records",character_records)
	if not projection_origin.is_empty():
		file.set_value("characters", "projection_origin", projection_origin)
	file.set_value("content","manifest",ContentIDs.manifest())
	file.set_value("content","quarantine",content_quarantine)
	sync_plot_flags()
	file.set_value("altar","recipes",altar_recipes)
	file.set_value("inventory","ancient_seed_format",1)
	file.set_value("inventory","stashes",item_stashes)
	file.set_value("inventory","ground",ground_items)
	var growth_state:=preload("res://garden_growth_state.gd").prepare(self)
	file.set_value("garden_interactions","state",growth_state)
	file.set_value("garden_development", "state", garden_development)
	file.set_value("construction","inventory",structures)
	file.set_value("garden", "plots_v2", plots)
	file.set_value("garden", "unknown", unknown)
	file.set_value("garden", "guest_seeds", guest_seeds)
	file.set_value("garden", "seed_history", seed_history)
	file.set_value("garden", "personal_parts", personal_parts)
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
	file.set_value("garden", "veilcap_discovered", veilcap_discovered)
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
	if SaveBatch.guarded_active(): return OK
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
			var species := Seeds.species_for_part(part)
			seen = species >= 0 and crafted[species]
			if species >= 0: crafted[species] = true
	var id: String=Parts.DEFINITIONS[part].id
	if component_crafts.has(id): seen=bool(component_crafts[id])
	elif Parts.DEFINITIONS[part].get("rare",false) or part == Seeds.DEFINITIONS[Seeds.index_of("crownroot")].part:
		# Crownroot shipped with component receipts. Older negative species indices
		# could mark the last legacy flag without ever crafting its ordinary part.
		seen=false
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

func next_seed_hint(parent: int) -> String:
	for i in Seeds.DEFINITIONS.size():
		var entry: Dictionary = Seeds.DEFINITIONS[i]
		if not Seeds.wild_only(i) and entry.parents.has(parent) and not discoveries[i]:
			return entry.hint
	return "Different species may share a hidden affinity. Try another lineage."

func roll_seed(personal: Dictionary, carried: Array, bundle: Array, site: int, roll: float, encounter: int = 1) -> int:
	var moss_chance: float = [0.40, 0.68, 0.52][site]
	var kind := 1 if roll < moss_chance else 0
	if encounter >= 3:
		var candidates: Array[int] = []
		var weights: Array[float] = []
		var total := 0.0
		for i in Seeds.DEFINITIONS.size():
			var entry: Dictionary = Seeds.DEFINITIONS[i]
			if encounter < int(entry.wild_min) or Seeds.wild_only(i):
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
	irrigation.resolve(structures,heart.unlocked)
	var changed := false
	for slot in plots.size():
		var bed: Dictionary = plots[slot]
		if bed.species < 0:
			bed.stage = 0
			continue
		changed=preload("res://garden_crop_state.gd").ensure(bed) or changed
		if not preload("res://cultivation_growth.gd").supported(bed):continue
		preload("res://cultivation_growth.gd").initialize(bed)
		var base: float = Seeds.DEFINITIONS[int(bed.species)].grow_seconds
		var care = preload("res://garden_crop_state.gd")
		var local: Dictionary = irrigation.effects.get(slot,{})
		var previous_age: float = bed.age
		var work := maxf(0,seconds) * preload("res://cultivation_growth.gd").rate(self,bed,in_wilds,local.has("watering"),local.get("growth",1.0))
		# A long tick can cross the bud window. Accept care at that boundary before clamping maturity.
		if local.has("care") and bed.stage < 3 and previous_age + work >= GROWTH_TIMES[2] * base / 80.0 and care.compatible(bed) and bed.care.choice == "":
			bed.stage = 2
			care.choose(bed,"preserve",care.crop_draw(bed),"deep_bud" if local.care >= 2 else "patient_bud")
			changed = true
		var duration: float = care.duration(bed,base)
		bed.age = minf(duration, previous_age + work)
		changed=changed or not in_wilds and int(previous_age/preload("res://cultivation_growth.gd").SAVE_WORK_INTERVAL)!=int(bed.age/preload("res://cultivation_growth.gd").SAVE_WORK_INTERVAL)
		var stage := 0
		for i in range(1, 4):
			if bed.age >= (duration if i==3 else GROWTH_TIMES[i] * base / 80.0):
				stage = i
		if stage!=bed.stage:preload("res://garden_crop_state.gd").bump(bed)
		changed = changed or stage != bed.stage
		bed.stage = stage
	sync_plot_flags()
	return changed


func plot_snapshot() -> PackedByteArray:
	var packed := PackedByteArray()
	for bed: Dictionary in plots:
		packed.append(int(bed.species)+1)
		packed.append(int(bed.stage))
		packed.append(int(bed.flowering))
	return packed


static func decode_plots(packed: PackedByteArray) -> Array:
	var beds: Array = []
	for i in range(0, packed.size() - 2, 3):
		beds.append({"species": int(packed[i]) - 1, "stage": int(packed[i + 1]), "flowering": (packed[i+2]&1)!=0})
	return beds
