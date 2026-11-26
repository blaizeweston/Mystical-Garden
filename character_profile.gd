extends RefCounted
var require_guarded_access := false
const SaveBatch=preload("res://save_batch.gd")

const ContentIDs=preload("res://content_ids.gd")
var needs_content_backup:=false
const Classes = preload("res://class_catalog.gd")
const Experience = preload("res://class_experience.gd")
const ConnectedWarden = preload("res://warden_connected_tree.gd")
const ConnectedWeaver = preload("res://weaver_connected_tree.gd")
const ConnectedTree = preload("res://connected_class_tree.gd")
const Parts = preload("res://weapon_parts.gd")
const Seeds = preload("res://seed_catalog.gd")

static var LEVEL_THRESHOLDS: Array=preload("res://game_balance.gd").levels()

var path := "user://character.cfg"
var data := blank()
var identity := Crypto.new().generate_random_bytes(16).hex_encode()
const Archive = preload("res://living_archive.gd")
var archive_visits: Dictionary = {}
var projection_receipts: Dictionary = {}
const Custody=preload("res://inventory_custody.gd")
var inventory_custody: Dictionary = {}
var needs_custody_backup:=false
## Private rejoin credentials for hosts visited with this character.
var rejoin_ticket := {}


static func blank() -> Dictionary:
	var xp: Array=[]
	var traits: Array=[]
	var upgrades: Array=[]
	var loadouts: Array=[]
	for c in Classes.DEFINITIONS.size():
		xp.append(0)
		traits.append(0)
		upgrades.append(0)
		loadouts.append({"weapon":0,"parts":[0,0,0]})
	var monsters: Array=[]
	monsters.resize(Parts.MONSTER_DEFINITIONS.size())
	monsters.fill(0)
	return {"name":"Wanderer","xp":xp,Experience.VERSION_KEY:Experience.VERSION,"plants":Seeds.counts(),"monsters":monsters,"traits":traits,"appearance":preload("res://character_appearance.gd").DEFAULT.duplicate(),"upgrades":upgrades,"active_class":0,"loadouts":loadouts,"quarantine":{}}


static func normalize(source: Dictionary) -> Dictionary:
	var result := blank()
	var slice: Variant = source.get("archive_slice")
	if slice is Dictionary and Archive.valid_id(slice.get("origin")) and Archive.valid_totals(slice.get("totals")):
		result.archive_slice = {"origin":slice.origin,"totals":slice.totals.duplicate()}
	result.name=clean_name(str(source.get("name","Wanderer")))
	result.quarantine=source.get("quarantine",{}).duplicate(true) if source.get("quarantine",{}) is Dictionary else {}
	for c in result.xp.size():
		result.xp[c] = Experience.value(source, c)
	for field in ["plants","monsters"]:
		var incoming = source.get(field)
		if not incoming is Array:
			continue
		for i in mini(incoming.size(), result[field].size()):
			if incoming[i] is int:
				result[field][i] = clampi(incoming[i], 0, 9999)
	result.appearance=preload("res://character_appearance.gd").normalize(source.get("appearance",[]))
	# Retired affinity slots stay zero for compatibility with existing profiles.
	result.traits.fill(0)
	result.active_class=clampi(int(source.get("active_class",0)) if source.get("active_class",0) is int else 0,0,Classes.DEFINITIONS.size()-1)
	var saved_upgrades=source.get("upgrades",[])
	var saved_loadouts=source.get("loadouts",[])
	for c in Classes.DEFINITIONS.size():
		if saved_upgrades is Array and c<saved_upgrades.size() and saved_upgrades[c] is int:
			var mask:=maxi(0,int(saved_upgrades[c]))
			var rank:=level(result.xp[c])
			var supported_bits := (1 << Classes.all_nodes(c).size()) - 1
			var active_mask := mask & supported_bits
			var new_tree := (active_mask >> Classes.Warden.OFFSET) != 0
			var retained := mask & ~supported_bits
			if new_tree:
				retained |= active_mask & Classes.Warden.LEGACY_MASK
			if retained != 0:
				var retained_masks: Dictionary = result.quarantine.get("learned_class_masks", {}) if result.quarantine.get("learned_class_masks", {}) is Dictionary else {}
				var class_key: String = Classes.DEFINITIONS[c].id
				retained_masks[class_key] = int(retained_masks.get(class_key, 0)) | retained
				result.quarantine.learned_class_masks = retained_masks
			for i in range(Classes.Warden.OFFSET if new_tree else 0,Classes.all_nodes(c).size() if new_tree else Classes.DEFINITIONS[c].nodes.size()):
				if not mask&(1<<i):continue
				var allowed:=Classes.can_learn(result,c,i,rank) if new_tree else Classes.can_learn_legacy(result,c,i,rank)
				if allowed:result.upgrades[c]|=1<<i
		if saved_loadouts is Array and c<saved_loadouts.size() and saved_loadouts[c] is Dictionary:
			var profile_data: Dictionary=saved_loadouts[c]
			result.loadouts[c].weapon=clampi(int(profile_data.get("weapon",0)) if profile_data.get("weapon",0) is int else 0,0,Classes.DEFINITIONS[c].weapons.size()-1)
			var parts=profile_data.get("parts",[])
			if parts is Array:
				for slot in mini(3,parts.size()):
					var part:=int(parts[slot]) if parts[slot] is int else 0
					result.loadouts[c].parts[slot]=part if Parts.is_plant(part) else 0
	for key in [ConnectedWarden.PROFILE_KEY,ConnectedWeaver.PROFILE_KEY,Classes.Ranger.PROFILE_KEY,Classes.Reaper.PROFILE_KEY,Classes.Oracle.PROFILE_KEY,ConnectedTree.MIGRATION_KEY]:
		if source.has(key):
			var progression: Variant = source[key]
			result[key] = progression.duplicate(true) if progression is Dictionary or progression is Array else progression
	return result


## Explicit Heart refund only. Ordinary load preserves historical investments unchanged.
## The archive protects original bits; the marker grants access to the current tree, not old effects.
static func refund_historical_class(source: Dictionary, class_id: int) -> Dictionary:
	var tree := Classes.connected_tree(class_id)
	if tree == null or not Experience.supported(source):
		return {"error":ERR_INVALID_DATA}
	if tree.eligible(source):
		return {"error":OK,"profile":source.duplicate(true),"changed":false,"level":tree.level(source)}
	if not tree.valid(source):
		return {"error":ERR_INVALID_DATA}
	var upgrades: Variant = source.get("upgrades")
	var quarantine: Variant = source.get("quarantine",{})
	var migrations: Variant = source.get(ConnectedTree.MIGRATION_KEY,{})
	if not upgrades is Array or class_id >= upgrades.size() or not upgrades[class_id] is int \
		or not quarantine is Dictionary or not migrations is Dictionary:
		return {"error":ERR_INVALID_DATA}
	if migrations.has(tree.class_key) and migrations[tree.class_key] != ConnectedTree.MIGRATION_VERSION:
		return {"error":ERR_INVALID_DATA}
	var archived: Variant = quarantine.get("learned_class_masks",{})
	if not archived is Dictionary or (archived.has(tree.class_key) and not archived[tree.class_key] is int):
		return {"error":ERR_INVALID_DATA}
	var result := source.duplicate(true)
	result.quarantine = quarantine.duplicate(true)
	result.quarantine.learned_class_masks = archived.duplicate(true)
	result.quarantine.learned_class_masks[tree.class_key] = int(archived.get(tree.class_key,0)) | int(upgrades[class_id])
	result.upgrades[class_id] = 0
	result[ConnectedTree.MIGRATION_KEY] = migrations.duplicate(true)
	result[ConnectedTree.MIGRATION_KEY][tree.class_key] = ConnectedTree.MIGRATION_VERSION
	result[tree.profile_key] = tree.state([])
	var xp := []
	for index in Classes.DEFINITIONS.size():
		xp.append(Experience.value(source,index))
	result.xp = xp
	result[Experience.VERSION_KEY] = Experience.VERSION
	result.erase("xp_tenths")
	return {"error":OK,"profile":result,"changed":true,"level":tree.level(result)}


static func clean_name(value: String) -> String:
	var result:=""
	for letter in value.strip_edges():
		if letter.unicode_at(0)>=32 and letter.unicode_at(0)!=127: result+=letter
	return result.left(24)

static func level(xp: int) -> int:
	var rank := 1
	for i in range(1, LEVEL_THRESHOLDS.size()):
		if xp < LEVEL_THRESHOLDS[i]:
			break
		rank += 1
	return rank


func load_profile(recover_interrupted: bool=true) -> Error:
	if recover_interrupted:
		if SaveBatch.guarded_active():
			return load("res://persistence_operations.gd").read_serializer(self, _read_profile)
		if require_guarded_access:
			return ERR_UNAUTHORIZED
		var recovery := SaveBatch.recover(path)
		if recovery != OK:
			return recovery
	return _read_profile()

func load_profile_guarded() -> Dictionary:
	return load("res://persistence_operations.gd").load_serializer(path, _read_profile)

func _read_profile() -> Error:
	var file := ConfigFile.new()
	var result := file.load(path)
	if result == OK:
		var custody: Variant=file.get_value("character","inventory_custody",{})
		if not Custody.valid_profile(custody):return ERR_INVALID_DATA
		inventory_custody=custody
		needs_custody_backup=not file.has_section_key("character","inventory_custody")
		var receipts: Variant = file.get_value("character", "projection_receipts", {})
		if not load("res://guest_profile_projection.gd").valid_receipts(receipts):
			return ERR_INVALID_DATA
		var saved = file.get_value("character", "progress", {})
		if saved is Dictionary and not Experience.supported(saved):
			return ERR_INVALID_DATA
		var saved_id = file.get_value("character", "identity", "")
		if saved_id is String and valid_identity(saved_id):
			identity = saved_id
		needs_content_backup=not file.has_section("content")
		data = normalize(ContentIDs.profile(saved,file.get_value("content","manifest",ContentIDs.legacy()))) if saved is Dictionary else blank()
		var visits: Variant = file.get_value("character","archive_visits",{})
		if not Archive.valid_visits(visits): return ERR_INVALID_DATA
		archive_visits = visits
		var ticket: Variant = file.get_value("character","rejoin_ticket",{})
		rejoin_ticket = ticket if ticket is Dictionary else {}
		projection_receipts = receipts
	return result


static func valid_identity(value: String) -> bool:
	return value.length() == 32 and value.is_valid_hex_number(false)


func save_profile() -> Error:
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

func save_profile_guarded() -> Dictionary:
	if require_guarded_access:
		return {"error": ERR_UNAUTHORIZED, "ran": false, "reason": "session_context_required"}
	return load("res://persistence_operations.gd").run_serializers([self], path, save_profile)

func migration_backup_paths() -> PackedStringArray:
	return PackedStringArray([path + ".pre-content-v2.bak",path + ".pre-portable-inventory-v1.bak"])

func confirm_migration(saved_path: String) -> void:
	if path == saved_path:
		needs_content_backup = false
		if not inventory_custody.is_empty():needs_custody_backup=false

func _migration_backup(target: String, guarded: bool) -> Error:
	if guarded:
		return load("res://persistence_operations.gd").backup_serializer(path, target)
	if DirAccess.dir_exists_absolute(target):
		return ERR_FILE_CANT_WRITE
	return OK if FileAccess.file_exists(target) else DirAccess.copy_absolute(path, target)

func _serialize_save(stage := Callable()) -> Error:
	if require_guarded_access or SaveBatch.guarded_active():
		var operations = load("res://persistence_operations.gd")
		if not operations.authorizes_serializer(self, stage):
			return SaveBatch.record_serializer_error(ERR_UNAUTHORIZED, path)
	if not Experience.current(data) or not Custody.valid_profile(inventory_custody):
		return ERR_INVALID_DATA
	if needs_content_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-content-v2.bak", stage.is_valid())
		if copied != OK:
			return copied
	if needs_custody_backup and not inventory_custody.is_empty() and FileAccess.file_exists(path):
		var copied := _migration_backup(path+".pre-portable-inventory-v1.bak",stage.is_valid())
		if copied!=OK:return copied
	var file := ConfigFile.new()
	file.set_value("content","manifest",ContentIDs.manifest())
	if not archive_visits.is_empty(): file.set_value("character","archive_visits",archive_visits)
	file.set_value("character", "progress", data)
	file.set_value("character", "identity", identity)
	if not rejoin_ticket.is_empty(): file.set_value("character","rejoin_ticket",rejoin_ticket)
	if not projection_receipts.is_empty():
		file.set_value("character", "projection_receipts", projection_receipts)
	if not inventory_custody.is_empty():
		file.set_value("character","inventory_custody",inventory_custody)
	var bytes := file.encode_to_text().to_utf8_buffer()
	return (stage.call(path, bytes) if stage.is_valid() else SaveBatch.write(path, bytes))
