extends RefCounted
## The first twelve Warden bits belong to the original tree. New IDs append after them.
const Connected = preload("res://warden_connected_tree.gd")
const OFFSET := 12
const LEGACY_MASK := (1 << OFFSET) - 1
const LANES := ["Offense", "Control", "Defense"]
const COLORS := ["#df9e76", "#c9bb7b", "#a7c88e"]
const ROW_LEVELS := [1, 2, 4, 7]
const FOCUSES := {
	"vanguard": {"name": "Thorn Counter", "mode": "counter_guard", "cooldown": 5600,
		"duration": 1300, "charges": 1, "color": "#d69a6a",
		"description": "Block an attack to prime your next hit. A weapon strike or Root Quake can spend the counter."},
	"rootkeeper": {"name": "Root Anchor", "mode": "guard", "cooldown": 8000,
		"duration": 1050, "charges": 1, "anchor_range": 5.0, "anchor_lifetime": 11000, "color": "#c8be81",
		"description": "Guard yourself and plant an anchor at your feet. Root Quake can travel to the anchor while it is in clear reach."},
	"bastion": {"name": "Rootshield", "mode": "front_guard", "cooldown": 6500,
		"duration": 1750, "charges": 1, "radius": 3.1, "color": "#a4c789",
		"description": "Raise a directional shield. Allies in front gain a ward. You move more slowly while the shield is raised."},
}
const ROWS := [
	[["vanguard", "Vanguard", "Learn Thorn Counter."],
	 ["rootkeeper", "Rootkeeper", "Learn Root Anchor."],
	 ["bastion", "Bastion", "Learn Rootshield."]],
	[["briar_rebound", "Briar Rebound", "Your first block with the subclass skill pushes up to two nearby idle enemies away."],
	 ["deep_roots", "Deep Roots", "Extend the counter window, anchor reach, or shield coverage of your subclass skill."],
	 ["shared_bark", "Shared Bark", "Your first block with the subclass skill wards the nearest ally in reach. When alone, renew your own ward briefly."]],
	[["pinning_quake", "Pinning Quake", "After a subclass block, your next Root Quake that hits briefly roots up to two surviving lesser foes."],
	 ["ready_footing", "Ready Footing", "Your first block with the subclass skill refreshes a recovering dodge."],
	 ["clear_the_way", "Clear the Way", "Your first block with the subclass skill clears Slowed from you and nearby living allies."]],
	[["cracking_roots", "Cracking Roots", "Your first block with the subclass skill makes one nearby lesser enemy Brittle."],
	 ["living_rhythm", "Living Rhythm", "After a subclass block, your next Root Quake that hits brings the subclass skill back sooner."],
	 ["sheltering_quake", "Sheltering Quake", "After a subclass block, your next Root Quake that hits wards living allies in its circle."]],
]
const CARDS := [
	{"id": "vanguard_briar_wake", "name": "Briar Wake", "focus": "vanguard", "class_behavior": "briar_wake",
	 "description": "After a Thorn Counter block, the next Root Quake that hits lashes one additional foe outside its circle."},
	{"id": "rootkeeper_second_growth", "name": "Second Growth", "focus": "rootkeeper", "class_behavior": "second_growth",
	 "description": "The first Root Quake cast through your anchor leaves it rooted for a second Quake."},
	{"id": "bastion_thorn_shelter", "name": "Thorn Shelter", "focus": "bastion", "class_behavior": "thorn_shelter",
	 "class_core": {"skill": "thorn_line", "slots": {"catalyst": ["force"]}},
	 "description": "After a Rootshield block, trip your Thorn Line with Root Quake to ward living allies beside the trap."},
]

static var NODES: Array[Dictionary] = make_nodes()

static func make_nodes(rows: Array = ROWS) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in rows.size():
		for lane in LANES.size():
			var entry: Array = rows[row][lane]
			var parents: Array[String] = []
			if row > 0:
				for adjacent in range(maxi(0,lane-1),mini(LANES.size(),lane+2)):
					parents.append(rows[row-1][adjacent][0])
			result.append({"id": entry[0], "name": entry[1], "description": entry[2], "tier": row,
				"level": ROW_LEVELS[row], "lane": lane, "parents": parents, "effects": {}})
	return result


static func mask(profile: Dictionary, class_id: int = 0) -> int:
	var upgrades: Array = profile.get("upgrades", [])
	return int(upgrades[class_id]) if class_id < upgrades.size() else 0


static func legacy(profile: Dictionary, class_id: int = 0) -> bool:
	var chosen := mask(profile,class_id)
	return (chosen & LEGACY_MASK) != 0 and (chosen >> OFFSET) == 0


static func focus(profile: Dictionary) -> String:
	var chosen := mask(profile)
	for lane in LANES.size():
		if chosen & (1 << (OFFSET+lane)):
			return ROWS[0][lane][0]
	return ""


static func focus_name(id: String) -> String:
	for node in NODES.slice(0, LANES.size()):
		if node.id == id:
			return node.name
	return ""


static func learned(profile: Dictionary, id: String, class_id: int = 0, nodes: Array = NODES) -> bool:
	var chosen := mask(profile,class_id)
	for index in nodes.size():
		if nodes[index].id == id:
			return bool(chosen & (1 << (OFFSET+index)))
	return false


static func modifiers(profile: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var chosen := mask(profile)
	for i in range(LANES.size(), NODES.size()):
		if chosen & (1 << (OFFSET+i)):
			result.append(NODES[i])
	return result


static func points(profile: Dictionary, level: int, class_id: int = 0) -> int:
	var count := 0
	for row in ROW_LEVELS:
		count += int(level >= row)
	var chosen := mask(profile,class_id)
	for i in NODES.size():
		count -= int(bool(chosen & (1 << (OFFSET+i))))
	return maxi(0,count)


static func can_learn(profile: Dictionary, index: int, level: int, class_id: int = 0, nodes: Array = NODES) -> bool:
	if index < OFFSET or index >= OFFSET+nodes.size() or legacy(profile,class_id):
		return false
	var node: Dictionary = nodes[index-OFFSET]
	var chosen := mask(profile,class_id)
	if level < int(node.level) or points(profile,level,class_id) == 0:
		return false
	var row_bits := ((1 << LANES.size())-1) << (OFFSET+int(node.tier)*LANES.size())
	if (chosen & row_bits) != 0:
		return false
	return node.parents.is_empty() or node.parents.any(func(id): return learned(profile,id,class_id,nodes))


static func skill(profile: Dictionary, slot: int, base: Dictionary, connected := false) -> Dictionary:
	var id := Connected.focus(profile) if connected else focus(profile)
	if id.is_empty():
		return base
	var result: Dictionary = FOCUSES[id].duplicate(true) if slot == 0 else base
	result.warden_focus = id
	var chosen := Connected.path(profile) if connected else []
	var deep := chosen.has("deep_roots") if connected else learned(profile,"deep_roots")
	if connected and slot == 1:
		if chosen.has("quakefront"):
			result.warden_catalyst_radius = result.radius
			result.radius += Connected.QUAKEFRONT_RADIUS
		if chosen.has("seismic_relay"):
			result.warden_relay = true
	if id == "rootkeeper":
		result.anchor_range = float(FOCUSES[id].anchor_range) + (1.5 if deep else 0.0)
		if slot == 0:
			result.description += "\nAnchor reach %.1f m." % result.anchor_range
		else:
			result.description += "\nA reachable Root Anchor becomes the center of the Quake."
	if slot == 0 and deep:
		if id == "vanguard": result.counter_window_bonus = 1250
		if id == "bastion": result.radius += .8
	var selected_nodes := modifiers(profile)
	if connected:
		selected_nodes = []
		for index in range(1, chosen.size()):
			selected_nodes.append(Connected.node(chosen[index]))
	for node in selected_nodes:
		var about_quake: bool = node.id in ["pinning_quake","living_rhythm","sheltering_quake",
			"faultline_impact","quakefront","aftershock","seismic_relay"]
		if (slot == 1) == about_quake:
			var detail: String = preload("res://warden_connected_tree.gd").description(node,id,FOCUSES[id].name) if connected else node.description
			result.description += "\n" + node.name + " · " + detail
	return result


static func cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card in CARDS:
		var entry: Dictionary = card.duplicate(true)
		entry.merge({"classes":[0], "rarity":"Rare", "cost":4, "weight":2.2, "max_rank":1, "effects":{}})
		result.append(entry)
	return result


static func card_lines(player: Dictionary, slot: int) -> String:
	if int(player.get("frame", -1)) != 0 or player.has("combat_ruleset"):
		return ""
	var lines: Array[String] = []
	for card in CARDS:
		if int(player.get("run_upgrades", {}).get(card.id,0)) > 0 and ((card.class_behavior == "second_growth") == (slot == 0)):
			lines.append(card.name + " · " + card.description)
	return "\n".join(lines)
