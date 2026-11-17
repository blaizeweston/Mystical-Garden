extends RefCounted
## Host-owned, expedition-only reinforcement and adaptation purchases.
const STATE := "expedition_grafts"
const SERIAL := &"graft_run_serial"
const COMMAND := "graft_buy:"
const Parts = preload("res://weapon_parts.gd")
const Items = preload("res://item_catalog.gd")
const Enemies = preload("res://enemy_catalog.gd")
const Cards = preload("res://affinity_cards.gd")
const Balance = preload("res://class_skill_balance.gd")
const Journal = preload("res://diagnostic_journal.gd")

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


static func run(player: Dictionary) -> Dictionary:
	return player.get(STATE, {}) if player.get("wild", false) else {}


static func begin(game: Node, player: Dictionary) -> void:
	var identity := int(game.get_meta(SERIAL, 0)) + 1
	game.set_meta(SERIAL, identity)
	player[STATE] = {"run": identity, "copies": []}


static func clear(player: Dictionary) -> void:
	player.erase(STATE)


static func used_here(copies: Array, floor_number: int) -> bool:
	return copies.any(func(copy): return copy.floor == floor_number)


static func resolution(player: Dictionary) -> Dictionary:
	var bonuses := {}
	var adaptations := []
	for copy: Dictionary in run(player).get("copies", []):
		var id: String = copy.id
		if REINFORCEMENTS.has(id):
			var definition: Dictionary = REINFORCEMENTS[id]
			var stat: String = definition.stat
			bonuses[stat] = mini(int(definition.cap), int(bonuses.get(stat,0)) + int(definition.amount))
		elif ADAPTATIONS.has(id):
			adaptations.append(ADAPTATIONS[id].source)
	return {"bonuses":bonuses, "adaptations":adaptations}


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


static func owner_details(game: Node, player: Dictionary) -> Dictionary:
	var ledger := run(player)
	if ledger.is_empty():
		return {}
	var copies: Array = ledger.copies
	return {"run":ledger.run, "floor":game.encounter_number, "revision":copies.size(),
		"remaining":maxi(0, int(PLAYTEST.purchase_limit) - copies.size()),
		"used":used_here(copies, game.encounter_number), "limit":PLAYTEST.purchase_limit,
		"copies":copies.duplicate(true)}


static func effective(game: Node, player: Dictionary) -> Dictionary:
	var stats: Dictionary = game.weapon_stats(player)
	var skills := []
	for adapter: Dictionary in stats.affinity_build.class_skills:
		var skill: Dictionary = adapter.get("native_skill", {})
		if not skill.is_empty():
			skills.append({"name":skill.name, "time":Balance.cooldown(skill,stats)})
	game.Weapons.tune_affinity_basic(stats, Cards.totals(player))
	return {"damage":Balance.Preview.weapon_range(stats,0), "health":game.Life.maximum(game,player),
		"reach":roundi(float(stats.reach)*100.0), "cooldown":skills}


static func proposed(player: Dictionary, floor_number: int, id: String, item: String) -> Dictionary:
	var candidate := player.duplicate()
	var ledger := run(player).duplicate(true)
	ledger.copies.append({"id":id, "item":item, "floor":floor_number, "serial":ledger.copies.size()+1})
	candidate[STATE] = ledger
	return candidate


static func timing(milliseconds: int) -> String:
	return ("%.3f" % (milliseconds / 1000.0)).rstrip("0").trim_suffix(".") + " s"


static func change_text(stat: String, before: Variant, after: Variant) -> String:
	if stat == "cooldown":
		var rows: PackedStringArray = []
		for index in before.size():
			rows.append("%s  %s → %s" % [before[index].name, timing(before[index].time), timing(after[index].time)])
		return "\n".join(rows)
	if stat == "reach":
		return "Reach  %.2f → %.2f m" % [before / 100.0, after / 100.0]
	if stat == "damage":
		return "Basic attack damage  %s → %s" % [Balance.Preview.range_label(before), Balance.Preview.range_label(after)]
	return "Max HP  %d → %d" % [before, after]


static func option_quote(game: Node, player: Dictionary, id: String, before: Dictionary, item := "") -> Dictionary:
	var result := {"reason":"", "values":"", "candidate":{}}
	if ADAPTATIONS.has(id):
		if run(player).copies.any(func(copy): return copy.id == id):
			result.reason = "Already acquired this expedition."
		return result
	var stat: String = REINFORCEMENTS[id].stat
	var candidate := proposed(player, game.encounter_number, id, item)
	var after := effective(game, candidate)
	result.values = change_text(stat, before[stat], after[stat])
	if before[stat] == after[stat]:
		result.reason = "Your build is at this improvement's effective limit."
	result.candidate = candidate
	result.health = after.health
	return result


static func material_part(item: String, ordinary: bool) -> int:
	var part := int(Items.get_item(item).get("legacy_part", 0))
	if not Parts.is_monster(part) or Parts.DEFINITIONS[part].item_id != item:
		return 0
	if ordinary and Enemies.get_kind(int(Parts.DEFINITIONS[part].monster)).get("boss", false):
		return 0
	return part


static func material_row(player: Dictionary, part: int) -> Dictionary:
	return {"id":Parts.DEFINITIONS[part].item_id, "name":Parts.part_name(part),
		"carried":int(player.carried_parts[part]), "cost":PLAYTEST.cost}


static func view(game: Node, player: Dictionary) -> Dictionary:
	var data := owner_details(game,player)
	if data.is_empty():
		return {}
	data.status = player.get("graft_message", "")
	data.options = []
	data.materials = []
	for part in range(1, Parts.DEFINITIONS.size()):
		if int(player.carried_parts[part]) > 0 and Parts.is_monster(part) and not Enemies.get_kind(Parts.DEFINITIONS[part].monster).get("boss",false):
			data.materials.append(material_row(player,part))
	var current := effective(game,player)
	for id in REINFORCEMENTS.keys() + ADAPTATIONS.keys():
		var unique := ADAPTATIONS.has(id)
		var definition: Dictionary = ADAPTATIONS[id] if unique else REINFORCEMENTS[id]
		var quote := option_quote(game,player,id,current)
		var count := (data.copies as Array).filter(func(copy): return copy.id == id).size()
		var row := {"id":id, "name":definition.name, "unique":unique, "text":definition.text, "detail":definition.detail,
			"values":quote.values, "reason":quote.reason, "count":count}
		if unique:
			row.material = material_row(player,material_part(definition.item,false))
		data.options.append(row)
	return data


static func request(data: Dictionary, id: String, material: String) -> String:
	return COMMAND + JSON.stringify({"run":data.run, "floor":data.floor, "revision":data.revision, "id":id, "item":material})


static func purchase(game: Node, actor: int, player: Dictionary, action: String) -> String:
	if not game.multiplayer.is_server() or not game.has_meta(&"combat_affinity_ruleset") or not game.Transactions.session_writable(game) \
			or not game.Life.alive(player) or not player.get("profile_ready", false) or not is_same(game.players.get(actor,{}),player):
		return "This graft purchase is unavailable."
	if not game.at_graft_altar(player) or not game.travel_kind.is_empty():
		return "Use the current Grafting Altar before leaving the floor."
	var parser := JSON.new()
	if parser.parse(action.trim_prefix(COMMAND)) != OK or not parser.data is Dictionary:
		return "That graft request is invalid."
	var request_data: Dictionary = parser.data
	for field in ["run", "floor", "revision"]:
		var value: Variant = request_data.get(field)
		if not (value is int or value is float) or not is_finite(float(value)) or floorf(float(value)) != float(value):
			return "That graft request is invalid."
	if not request_data.get("id") is String or not request_data.get("item") is String:
		return "That graft request is invalid."
	var ledger := run(player)
	if ledger.is_empty() or request_data.get("run") != ledger.run or request_data.get("floor") != game.encounter_number:
		return "That altar offer expired. Check the current choices."
	var copies: Array = ledger.copies
	if used_here(copies,game.encounter_number):
		return "You already used this altar."
	if request_data.get("revision") != copies.size():
		return "Your improvements changed. Review the current choices."
	if copies.size() >= int(PLAYTEST.purchase_limit):
		return "You used all graft purchases for this expedition."
	var id := str(request_data.get("id",""))
	var item := str(request_data.get("item",""))
	var unique := ADAPTATIONS.has(id)
	if not unique and not REINFORCEMENTS.has(id):
		return "That improvement is unavailable."
	if unique and item != ADAPTATIONS[id].item:
		return "This adaptation needs its matching trophy."
	var part := material_part(item,not unique)
	if part == 0 or int(player.carried_parts[part]) < int(PLAYTEST.cost):
		return "You need the selected trophy in your carried inventory."
	var quote := option_quote(game,player,id,{} if unique else effective(game,player),item)
	if not str(quote.reason).is_empty():
		return quote.reason

	# Stage all run-owned changes before publishing a successful result. This
	# purchase has no persistent participants, save write, or reward roll.
	var candidate: Dictionary = proposed(player,game.encounter_number,id,item) if unique else quote.candidate
	var carry: Array = player.carried_parts.duplicate()
	carry[part] = int(carry[part]) - int(PLAYTEST.cost)
	player.carried_parts = carry
	player[STATE] = candidate[STATE]
	if id == "health":
		player.max_hp = quote.health
	var definition: Dictionary = ADAPTATIONS[id] if unique else REINFORCEMENTS[id]
	Journal.event("grafting","improvement_acquired",{"actor":actor,"run":ledger.run,"floor":game.encounter_number,
		"serial":(player[STATE].copies as Array).size(),"improvement":id,"item":item,"quantity":PLAYTEST.cost})
	return "%s acquired for this expedition." % definition.name
