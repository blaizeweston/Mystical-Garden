extends RefCounted
## Only host-owned combat value classes are admitted. Preserve shared action objects
## across pending projectiles, fields and wards without serializing engine objects.
const Life = preload("res://player_lifecycle.gd").Life
const Health = preload("res://player_vitals.gd").Health
const Wallet = preload("res://expedition_wallet.gd").Wallet
const Grafts = preload("res://expedition_grafts.gd").Ledger
const Cards = preload("res://affinity_card_ledger.gd").Ledger
const Ward = preload("res://player_protection.gd").WardClaim
const TYPES = [Life, Health, Wallet, Grafts, Cards, Ward, preload("res://player_protection.gd").State,
	preload("res://player_weapon_actions.gd").State, preload("res://player_hit_conditions.gd").State,
	preload("res://player_cooldowns.gd").Timers, preload("res://combat_action_events.gd")]
var error := ""
var _index := {}
var _values := []
var _objects := []

func encode(root: Dictionary) -> PackedByteArray:
	var data: Variant = _pack(root)
	if not error.is_empty(): return PackedByteArray()
	return var_to_bytes({"version":1,"root":data,"objects":_values})

func _pack(value: Variant) -> Variant:
	if value is Object:
		var kind := TYPES.find(value.get_script())
		if kind < 0:
			error = "Unsupported expedition component."
			return null
		var id: int = value.get_instance_id()
		if not _index.has(id):
			_index[id] = _values.size()
			var entry := {"kind":kind,"fields":{},"meta":{}}
			_values.append(entry)
			for prop in value.get_property_list():
				if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
					entry.fields[prop.name] = _pack(value.get(prop.name))
			for key in value.get_meta_list():
				entry.meta[key] = _pack(value.get_meta(key))
		return {"@object":_index[id]}
	if value is Dictionary:
		var result := {}
		for key in value:
			if typeof(key) in [TYPE_OBJECT,TYPE_CALLABLE,TYPE_SIGNAL] or key in ["@object","@array"]:
				error = "Invalid expedition key."
				return null
			result[key] = _pack(value[key])
		return result
	if value is Array:
		var result := []
		for child in value: result.append(_pack(child))
		if value.is_typed():
			return {"@array":value.get_typed_builtin(),"script_type":TYPES.find(value.get_typed_script()),"items":result}
		return result
	if typeof(value) in [TYPE_CALLABLE,TYPE_SIGNAL,TYPE_RID]:
		error = "Expedition contains a live engine handle."
		return null
	return value

func decode(data: PackedByteArray) -> Dictionary:
	var packet: Variant = bytes_to_var(data)
	if not packet is Dictionary or packet.get("version") != 1 or not packet.get("root") is Dictionary or not packet.get("objects") is Array: return {}
	for entry in packet.objects:
		if not entry is Dictionary or not entry.get("kind") is int or entry.kind < 0 or entry.kind >= TYPES.size() or not entry.get("fields") is Dictionary or not entry.get("meta") is Dictionary: return {}
		match TYPES[entry.kind]:
			Life: _objects.append(Life.new(0))
			Health: _objects.append(Health.new(0,0))
			Grafts: _objects.append(Grafts.new(0))
			Ward: _objects.append(Ward.new(null,{},0,0,0))
			_: _objects.append(TYPES[entry.kind].new())
	for i in _objects.size():
		var object: Object = _objects[i]
		var entry: Dictionary = packet.objects[i]
		# Only script data properties on the known local class can be restored.
		for prop in object.get_property_list():
			if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
			if not entry.fields.has(prop.name): return {}
			var field: Variant = _unpack(entry.fields[prop.name])
			if not error.is_empty(): return {}
			object.set(prop.name,field)
		for key in entry.meta: object.set_meta(key,_unpack(entry.meta[key]))
		if object is Life: Life.reserve_generation(object.generation())
	var result: Variant = _unpack(packet.root)
	return result if error.is_empty() and result is Dictionary else {}

func _unpack(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("@object"):
			var index: Variant = value["@object"]
			if index is int and index >= 0 and index < _objects.size(): return _objects[index]
			error = "Unknown expedition component."
			return null
		if value.has("@array"):
			var kind: int = value["@array"]
			var result := []
			for item in value.items: result.append(_unpack(item))
			if kind == TYPE_OBJECT:
				if value.script_type < 0 or value.script_type >= TYPES.size():
					error = "Unknown expedition list type."
					return null
				return Array(result,kind,&"RefCounted",TYPES[value.script_type])
			return Array(result,kind,&"",null)
		var result := {}
		for key in value: result[key] = _unpack(value[key])
		return result
	if value is Array:
		var result := []
		for item in value: result.append(_unpack(item))
		return result
	return value
