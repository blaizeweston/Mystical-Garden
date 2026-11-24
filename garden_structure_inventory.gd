extends RefCounted
## The Garden owns one record per structure. Removal retires its monotonically allocated ID.
const Catalog = preload("res://garden_structure_catalog.gd")
const Items = preload("res://item_catalog.gd")
const OLD_PRICES := {"plot_4":2,"plot_5":3,"plot_6":4,"plot_7":5,"plot_8":6,"plot_9":7}

static func new_garden(beds := 3) -> Dictionary:
	var inventory := {"version":1,"revision":0,"next_id":1,"instances":{}, "legacy_clearing":false}
	for slot in beds:
		var id := add(inventory,"bed",{})
		var at: Vector3 = Catalog.ORIGINAL_BEDS[slot]
		place(inventory.instances[id],Vector2(at.x,at.z),0.0,slot)
	var altar := add(inventory,"altar",{})
	place(inventory.instances[altar],Vector2(Catalog.ORIGINAL_ALTAR.x,Catalog.ORIGINAL_ALTAR.z),0.0,-1)
	return inventory

static func add(inventory: Dictionary, kind: String, payment: Dictionary) -> int:
	var id: int = inventory.next_id
	inventory.next_id += 1
	inventory.instances[id] = {"kind":kind,"placed":false,"at":Vector2.ZERO,"yaw":0.0,"slot":-1,"paid":payment.duplicate(true)}
	inventory.revision += 1
	return id

static func place(entry: Dictionary, at: Vector2, yaw: float, slot: int) -> void:
	entry.placed = true
	entry.at = at
	entry.yaw = yaw
	entry.slot = slot

static func grant_research(inventory: Dictionary, research: String) -> void:
	for kind: String in Catalog.DEFINITIONS:
		var definition: Dictionary = Catalog.DEFINITIONS[kind]
		if definition.get("research","") != research: continue
		if not definition.get("repeatable",false):
			for entry: Dictionary in inventory.instances.values():
				if entry.kind == kind: return
		add(inventory,kind,{})
		return

static func migrate(layout: Dictionary, crops: Array, research: Array, historical: Dictionary) -> Dictionary:
	var inventory := new_garden(crops.size() if layout.is_empty() else 3)
	inventory.legacy_clearing = true
	inventory.legacy_prop_beds = mini(crops.size(),Catalog.ORIGINAL_BEDS.size())
	if not layout.is_empty():
		inventory.instances.clear()
		inventory.next_id = layout.next_id
		for row: Array in layout.buildings:
			inventory.instances[row[0]] = {"kind":row[1],"placed":true,"at":row[2],"yaw":row[3],"slot":row[4] if row[1]=="bed" else -1,"paid":{}}
	var permits := 0
	for old_id in OLD_PRICES:
		if old_id in historical.get("unlocked",[]) or old_id in historical.get("paid",[]): permits += 1
	for unused in maxi(0,permits - (crops.size()-3)): add(inventory,"bed",{})
	for kind in ["study","archive"]:
		if Catalog.DEFINITIONS[kind].research in research and not inventory.instances.values().any(func(e):return e.kind==kind):
			add(inventory,kind,{})
	return inventory

static func valid_payment(payment: Dictionary) -> bool:
	if not payment.get("energy") is int or payment.energy < 0 or not payment.get("materials") is Dictionary: return false
	for item in payment.materials:
		if not item is String or not payment.materials[item] is int or payment.materials[item] <= 0: return false
		var part: int = Items.get_item(item).get("legacy_part",-1)
		if part < 0 or Items.part_id(part) != item: return false
	return payment.energy > 0 or not payment.materials.is_empty()

static func valid(data: Variant, crops: Array) -> bool:
	if not data is Dictionary or data.get("version")!=1 or not data.get("instances") is Dictionary:
		return false
	if not data.get("next_id") is int or data.next_id < 1 or not data.get("revision") is int or data.revision < 0:
		return false
	if not data.get("legacy_clearing") is bool or crops.size()<3: return false
	if not data.get("legacy_prop_beds",3) is int or data.get("legacy_prop_beds",3) not in range(3,10): return false
	var slots := {}
	var altars := 0
	for id in data.instances:
		var entry: Variant = data.instances[id]
		if not id is int or id < 1 or id >= data.next_id or not entry is Dictionary or not Catalog.DEFINITIONS.has(entry.get("kind")): return false
		if not entry.get("placed") is bool or not entry.get("at") is Vector2 or not entry.at.is_finite(): return false
		if not entry.get("yaw") is float or not is_finite(entry.yaw): return false
		if not entry.get("slot") is int or not entry.get("paid") is Dictionary: return false
		if not entry.paid.is_empty():
			if not Catalog.DEFINITIONS[entry.kind].get("repeatable",false) or not valid_payment(entry.paid): return false
		if entry.slot in [0,1,2] and not entry.paid.is_empty(): return false
		if entry.kind=="altar": altars += 1
		if entry.kind!="bed" and entry.slot!=-1: return false
		if entry.slot == -1:
			if entry.kind=="bed" and entry.placed: return false
		elif entry.slot < 0 or entry.slot >= crops.size() or slots.has(entry.slot): return false
		else:
			slots[entry.slot] = entry.placed
	for i in crops.size():
		if i < 3 and not slots.has(i): return false
		if crops[i].species >= 0 and not slots.get(i,false): return false
	return altars == 1
