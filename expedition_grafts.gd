extends RefCounted
## The host's per-player ledger owns all purchased expedition improvements.
const STATE := "expedition_grafts"
const SERIAL := &"graft_run_serial"
const COMMAND := "graft_buy:"
const EXPIRED := "That altar offer expired. Check the current choices."
const Parts = preload("res://weapon_parts.gd")
const Items = preload("res://item_catalog.gd")
const Enemies = preload("res://enemy_catalog.gd")
const Balance = preload("res://class_skill_balance.gd")

const PLAYTEST := {"purchase_limit": 6, "cost": 1}
const REINFORCEMENTS := {
	"strike": {"name":"Honed Edge", "stat":"damage", "amount":3, "cap":12,
		"text":"Add 3 damage to your basic attack roll.", "detail":"Applies before weapon delivery and mitigation. The graft bonus is capped at +12 damage. It stacks with active weapon cards."},
	"health": {"name":"Reinforced Frame", "stat":"health", "amount":5, "cap":40,
		"text":"Gain up to 5 Max HP without healing.", "detail":"Shares the +40 HP native capacity limit with other native bonuses. Existing revive loss and separately sourced health effects still apply."},
	"cooldown": {"name":"Quickened Ritual", "stat":"cooldown", "amount":250, "cap":900,
		"text":"Start native class ability cooldowns up to 0.25 s shorter.", "detail":"Up to 0.9 s total from grafting. A timer already running keeps its deadline."},
	"reach": {"name":"Extended Reach", "stat":"reach", "amount":20, "cap":60,
		"text":"Extend basic attack reach by 0.20 m.", "detail":"Up to +0.60 m from grafting. Applies to the weapon’s real hit geometry and projectile range. Cover still applies."},
}
const ADAPTATIONS := {
	"silken_link": {"name":"Silken Mycelium", "item":"monster_14", "source":"monster:spore_widow",
		"text":"A basic hit links to a nearby visible enemy for half your strike roll.",
		"detail":"One other target within 3 m. Damage lands after 0.14 s, with at least 0.12 s between accepted links."},
	"prismatic_echo": {"name":"Prismatic Gill", "item":"monster_18", "source":"monster:glasscap",
		"text":"Every third qualifying basic hit primes an Echo against another enemy.",
		"detail":"One visible target within 3 m takes half your strike roll after 0.24 s. An Echo stays ready until it finds a target and a queue slot."},
	"chorus_pulse": {"name":"Chorus Node", "item":"monster_19", "source":"monster:root_choir",
		"text":"Every fourth qualifying basic hit primes a pulse for 10 damage to nearby enemies.",
		"detail":"After 0.18 s, the pulse strikes each other eligible enemy within 3.2 m of impact and in clear sight. One pulse stays ready until it can be scheduled."},
	"funeral_charges": {"name":"Funeral Petal", "item":"monster_15", "source":"monster:pallbearer",
		"text":"Earn a Death Charge on an eligible basic-attack kill. Spend one on a qualifying hit for +10 damage.",
		"detail":"One shared limit of three with Reaper’s Death’s Due. Class charges spend first. The graft’s charges reset when you fall or change floors. Summoned enemies grant no charges."},
	"cinder_field": {"name":"Cinder Antler", "item":"monster_17", "source":"monster:ashen_hart",
		"text":"A qualifying basic hit grows a field that deals 10 damage per pulse.",
		"detail":"A 1.8 m field lasts 2.6 s and pulses once per second. One active graft field per player, with at least 4 s between accepted fields."},
	"rootlet_attraction": {"name":"Grasping Rootlet", "item":"monster_16", "source":"monster:graft_thief",
		"text":"After the floor is cleared, draw available loose loot within 3.5 m.",
		"detail":"Requires clear ground between you and the item. Personal drops retain their owner. You still pick up the loot."},
}


class Ledger extends RefCounted:
	# Only accepting a purchase creates a successor. Save rollback can restore
	# the prior player slot by reference because that ledger never changes.
	var _identity: int
	var _receipts: Array[Dictionary] = []

	func _init(identity: int) -> void:
		_identity = identity

	func identity() -> int:
		return _identity

	func _used_at(floor_number: int) -> bool:
		return _receipts.any(func(receipt): return receipt.floor == floor_number)

	func details(floor_number: int) -> Dictionary:
		return {"run":_identity, "floor":floor_number, "revision":_receipts.size(),
			"remaining":maxi(0, int(PLAYTEST.purchase_limit) - _receipts.size()),
			"used":_used_at(floor_number), "limit":PLAYTEST.purchase_limit,
			"copies":_receipts.duplicate(true)}

	func resolution() -> Dictionary:
		var result := {"bonuses":{}, "adaptations":[]}
		for receipt in _receipts:
			_apply_improvement(result, receipt.id)
		return result

	func _quote(id: String, before: Dictionary, project_stats: Callable) -> Dictionary:
		if ADAPTATIONS.has(id):
			var owned := _receipts.any(func(receipt): return receipt.id == id)
			return {"reason":"Already acquired this expedition." if owned else "", "values":""}
		var projected := resolution()
		_apply_improvement(projected, id)
		var after: Dictionary = project_stats.call(projected)
		var stat: String = REINFORCEMENTS[id].stat
		var reason := "Your build is at this improvement's effective limit." if before[stat] == after[stat] else ""
		return {"reason":reason, "values":_change_text(stat, before[stat], after[stat]), "health":after.health}

	func altar_view(floor_number: int, carried: Array, status: String, project_stats: Callable) -> Dictionary:
		var data := details(floor_number)
		data.status = status
		data.options = []
		data.materials = []
		for part in range(1, Parts.DEFINITIONS.size()):
			if int(carried[part]) > 0 and Parts.is_monster(part) and not Enemies.get_kind(Parts.DEFINITIONS[part].monster).get("boss",false):
				data.materials.append(_material_row(part, int(carried[part])))
		var current: Dictionary = project_stats.call(resolution())
		for id in REINFORCEMENTS.keys() + ADAPTATIONS.keys():
			var unique := ADAPTATIONS.has(id)
			var definition: Dictionary = ADAPTATIONS[id] if unique else REINFORCEMENTS[id]
			var quote := _quote(id, current, project_stats)
			var count := _receipts.filter(func(receipt): return receipt.id == id).size()
			var row := {"id":id, "name":definition.name, "unique":unique, "text":definition.text, "detail":definition.detail,
				"values":quote.values, "reason":quote.reason, "count":count}
			if unique:
				var part := _material_part(definition.item, false)
				row.material = _material_row(part, int(carried[part]))
			data.options.append(row)
		return data

	# An accepted plan carries all data the host needs for one synchronous
	# trophy debit and ledger replacement. A refused plan carries only feedback.
	func plan_purchase(request_data: Dictionary, floor_number: int, carried: Array, project_stats: Callable) -> Dictionary:
		if request_data.run != _identity or request_data.floor != floor_number:
			return {"message":EXPIRED}
		if _used_at(floor_number):
			return {"message":"You already used this altar."}
		if request_data.revision != _receipts.size():
			return {"message":"Your improvements changed. Review the current choices."}
		if _receipts.size() >= int(PLAYTEST.purchase_limit):
			return {"message":"You used all graft purchases for this expedition."}
		var id: String = request_data.id
		var item: String = request_data.item
		var unique := ADAPTATIONS.has(id)
		if not unique and not REINFORCEMENTS.has(id):
			return {"message":"That improvement is unavailable."}
		if unique and item != ADAPTATIONS[id].item:
			return {"message":"This adaptation needs its matching trophy."}
		var part := _material_part(item, not unique)
		if part == 0 or int(carried[part]) < int(PLAYTEST.cost):
			return {"message":"You need the selected trophy in your carried inventory."}
		var current: Dictionary = {} if unique else project_stats.call(resolution())
		var quote := _quote(id, current, project_stats)
		if not str(quote.reason).is_empty():
			return {"message":quote.reason}

		var receipt := {"id":id, "item":item, "floor":floor_number, "serial":_receipts.size()+1}
		var next := Ledger.new(_identity)
		next._receipts.assign(_receipts)
		next._receipts.append(receipt)
		var definition: Dictionary = ADAPTATIONS[id] if unique else REINFORCEMENTS[id]
		var result := {"ledger":next, "receipt":receipt.duplicate(), "part":part, "cost":PLAYTEST.cost,
			"message":"%s acquired for this expedition." % definition.name}
		if id == "health":
			result.health = quote.health
		return result


	static func _apply_improvement(result: Dictionary, id: String) -> void:
		if REINFORCEMENTS.has(id):
			var definition: Dictionary = REINFORCEMENTS[id]
			var stat: String = definition.stat
			var bonuses: Dictionary = result.bonuses
			bonuses[stat] = mini(int(definition.cap), int(bonuses.get(stat, 0)) + int(definition.amount))
		elif ADAPTATIONS.has(id):
			result.adaptations.append(ADAPTATIONS[id].source)


	static func _timing(milliseconds: int) -> String:
		return ("%.3f" % (milliseconds / 1000.0)).rstrip("0").trim_suffix(".") + " s"


	static func _change_text(stat: String, before: Variant, after: Variant) -> String:
		if stat == "cooldown":
			var rows: PackedStringArray = []
			for index in before.size():
				rows.append("%s  %s → %s" % [before[index].name, _timing(before[index].time), _timing(after[index].time)])
			return "\n".join(rows)
		if stat == "reach":
			return "Reach  %.2f → %.2f m" % [before / 100.0, after / 100.0]
		if stat == "damage":
			return "Basic attack damage  %s → %s" % [Balance.Preview.range_label(before), Balance.Preview.range_label(after)]
		return "Max HP  %d → %d" % [before, after]


	static func _material_part(item: String, ordinary: bool) -> int:
		var part := int(Items.get_item(item).get("legacy_part", 0))
		if not Parts.is_monster(part) or Parts.DEFINITIONS[part].item_id != item:
			return 0
		if ordinary and Enemies.get_kind(int(Parts.DEFINITIONS[part].monster)).get("boss", false):
			return 0
		return part


	static func _material_row(part: int, carried: int) -> Dictionary:
		return {"id":Parts.DEFINITIONS[part].item_id, "name":Parts.part_name(part),
			"carried":carried, "cost":PLAYTEST.cost}


static func active_ledger(player: Dictionary) -> Ledger:
	return player.get(STATE) if player.get("wild", false) else null


static func run_identity(player: Dictionary) -> int:
	var ledger := active_ledger(player)
	return ledger.identity() if ledger != null else -1


static func owner_details(player: Dictionary, floor_number: int) -> Dictionary:
	var ledger := active_ledger(player)
	return ledger.details(floor_number) if ledger != null else {}


static func tune_native(stats: Dictionary, improvements: Dictionary) -> void:
	var bonuses: Dictionary = improvements.get("bonuses", {})
	if bonuses.has("health"):
		stats.max_health = float(stats.get("max_health", 0)) + float(bonuses.health) / Balance.Preview.scale()
	if bonuses.has("cooldown"):
		stats.skill_cooldown = int(stats.get("skill_cooldown", 0)) + int(bonuses.cooldown)
	if "monster:graft_thief" in improvements.get("adaptations", []):
		stats.loot_attract = 3.5


static func tune_basic(stats: Dictionary) -> void:
	var bonuses: Dictionary = stats.get("affinity_build", {}).get("improvements", {}).get("bonuses", {})
	stats.damage = float(stats.damage) + float(bonuses.get("damage", 0)) / Balance.Preview.scale()
	stats.reach = float(stats.reach) + float(bonuses.get("reach", 0)) / 100.0


static func request(data: Dictionary, id: String, material: String) -> String:
	return COMMAND + JSON.stringify({"run":data.run, "floor":data.floor, "revision":data.revision, "id":id, "item":material})


static func decode_request(action: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(action.trim_prefix(COMMAND)) != OK or not parser.data is Dictionary:
		return {}
	var request_data: Dictionary = parser.data
	for field in ["run", "floor", "revision"]:
		var value: Variant = request_data.get(field)
		if not (value is int or value is float) or not is_finite(float(value)) or floorf(float(value)) != float(value):
			return {}
	if not request_data.get("id") is String or not request_data.get("item") is String:
		return {}
	return request_data
