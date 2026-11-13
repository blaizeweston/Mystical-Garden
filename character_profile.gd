extends RefCounted
var require_guarded_access := false
const SaveBatch=preload("res://save_batch.gd")

const ContentIDs=preload("res://content_ids.gd")
var needs_content_backup:=false
const Classes = preload("res://class_catalog.gd")
const Parts = preload("res://weapon_parts.gd")
const Seeds = preload("res://seed_catalog.gd")

static var LEVEL_THRESHOLDS: Array=preload("res://game_balance.gd").levels()

var path := "user://character.cfg"
var data := blank()
var identity := Crypto.new().generate_random_bytes(16).hex_encode()


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
	return {"name":"Wanderer","xp":xp,"xp_tenths":[0,0,0,0,0],"plants":Seeds.counts(),"monsters":monsters,"traits":traits,"appearance":preload("res://character_appearance.gd").DEFAULT.duplicate(),"upgrades":upgrades,"active_class":0,"loadouts":loadouts,"quarantine":{}}


static func normalize(source: Dictionary) -> Dictionary:
	var result := blank()
	result.name=clean_name(str(source.get("name","Wanderer")))
	result.quarantine=source.get("quarantine",{}).duplicate(true) if source.get("quarantine",{}) is Dictionary else {}
	for field in ["xp","plants","monsters"]:
		var incoming = source.get(field)
		if not incoming is Array:
			continue
		for i in mini(incoming.size(), result[field].size()):
			if incoming[i] is int:
				var maximum: int = [3, 2, 2, 2, 2][i] if field == "appearance" else 2 if field == "traits" else 9999
				result[field][i] = clampi(incoming[i], 0, maximum)
	var fractions=source.get("xp_tenths",[])
	if fractions is Array:
		for i in mini(fractions.size(),result.xp_tenths.size()):
			if fractions[i] is int: result.xp_tenths[i]=clampi(fractions[i],0,9)
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
			var new_tree:=(mask>>Classes.Warden.OFFSET)!=0
			for i in range(Classes.Warden.OFFSET if new_tree else 0,Classes.all_nodes(c).size() if new_tree else Classes.DEFINITIONS[c].nodes.size()):
				if not mask&(1<<i):continue
				var allowed:=Classes.can_learn(result,c,i,rank) if new_tree else Classes.can_learn_legacy(result,c,i,rank)
				if allowed:result.upgrades[c]|=1<<i
		if saved_loadouts is Array and c<saved_loadouts.size() and saved_loadouts[c] is Dictionary:
			var data: Dictionary=saved_loadouts[c]
			result.loadouts[c].weapon=clampi(int(data.get("weapon",0)) if data.get("weapon",0) is int else 0,0,Classes.DEFINITIONS[c].weapons.size()-1)
			var parts=data.get("parts",[])
			if parts is Array:
				for slot in mini(3,parts.size()):
					var part:=int(parts[slot]) if parts[slot] is int else 0
					result.loadouts[c].parts[slot]=part if Parts.is_plant(part) else 0
	return result


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
		var saved_id = file.get_value("character", "identity", "")
		if saved_id is String and valid_identity(saved_id):
			identity = saved_id
		var saved = file.get_value("character", "progress", {})
		needs_content_backup=not file.has_section("content")
		data = normalize(ContentIDs.profile(saved,file.get_value("content","manifest",ContentIDs.legacy()))) if saved is Dictionary else blank()
	return result


static func valid_identity(value: String) -> bool:
	return value.length() == 32 and value.is_valid_hex_number(false)


func save_profile() -> Error:
	if SaveBatch.guarded_active():
		return load("res://persistence_operations.gd").stage_serializer(self, _serialize_save)
	if require_guarded_access:
		return ERR_UNAUTHORIZED
	return _serialize_save()

func save_profile_guarded() -> Dictionary:
	if require_guarded_access:
		return {"error": ERR_UNAUTHORIZED, "ran": false, "reason": "session_context_required"}
	return load("res://persistence_operations.gd").run_serializers([self], path, save_profile)

func migration_backup_paths() -> PackedStringArray:
	return PackedStringArray([path + ".pre-content-v2.bak"])

func _migration_backup(target: String, guarded: bool) -> Error:
	if guarded:
		return load("res://persistence_operations.gd").backup_serializer(path, target)
	return OK if FileAccess.file_exists(target) else DirAccess.copy_absolute(path, target)

func _serialize_save(stage := Callable()) -> Error:
	if needs_content_backup and FileAccess.file_exists(path):
		var copied := _migration_backup(path + ".pre-content-v2.bak", stage.is_valid())
		if copied != OK:
			return copied
		if not stage.is_valid():
			needs_content_backup = false
	var file := ConfigFile.new()
	file.set_value("content","manifest",ContentIDs.manifest())
	file.set_value("character", "progress", data)
	file.set_value("character", "identity", identity)
	var bytes := file.encode_to_text().to_utf8_buffer()
	return (stage.call(path, bytes) if stage.is_valid() else SaveBatch.write(path, bytes))
