extends RefCounted
## Authoritative native focus Q definitions. Connected node values live beside each class runtime.
const Graph = preload("res://warden_tree.gd")
const Ranger = preload("res://ranger_connected_tree.gd")
const Reaper = preload("res://reaper_connected_tree.gd")
const Weaver = preload("res://weaver_connected_tree.gd")
const Oracle = preload("res://oracle_connected_tree.gd")
const FOCUSES := [
 [
  {
   "id": "thornbinder",
   "focus": "Thornbinder",
   "name": "Interwoven Bind",
   "mode": "subclass",
   "shape": "target",
   "visual": "weave",
   "color": "#99ce92",
   "description": "Root a visible foe and up to one nearby enemy.",
   "cooldown": 7600,
   "range": 5.6,
   "radius": 1.85,
   "bind": 1600,
   "damage": 1,
   "limit": 2
  },
  {
   "id": "bloomcaller",
   "focus": "Bloomcaller",
   "name": "Cultivate Bloom",
   "mode": "subclass",
   "shape": "ground",
   "visual": "bloom",
   "color": "#d8a2eb",
   "description": "Grow a bloom that pulses damage against enemies inside its circle.",
   "cooldown": 7600,
   "range": 6,
   "radius": 2.35,
   "field": "growth",
   "duration": 3000
  },
  {
   "id": "silkwarden",
   "focus": "Silkwarden",
   "name": "Silk Shelter",
   "mode": "subclass",
   "shape": "ground",
   "visual": "silk",
   "color": "#b4dfd0",
   "description": "Spin a shelter that roots enemies and wards allies inside it.",
   "cooldown": 7600,
   "range": 5.5,
   "radius": 2.45,
   "bind": 1000,
   "ward": true
  }
 ],
 [
  {
   "id": "wildstalker",
   "focus": "Wildstalker",
   "name": "Hunter’s Salvo",
   "mode": "subclass",
   "shape": "line",
   "visual": "salvo",
   "color": "#d8e59b",
   "description": "Pierce up to three enemies in a lane. Mark the first survivor for a follow-up hit.",
   "cooldown": 7600,
   "range": 8.5,
   "width": 0.62,
   "damage": 2,
   "limit": 3
  },
  {
   "id": "snarekeeper",
   "focus": "Snarekeeper",
   "name": "Luring Snare",
   "mode": "subclass",
   "shape": "ground",
   "visual": "snare",
   "color": "#a6d69d",
   "description": "Set a lingering snare with a decoy that draws nearby foes into its roots.",
   "cooldown": 7600,
   "range": 6,
   "radius": 2.35,
   "bind": 1250,
   "field": "decoy",
   "duration": 2700
  },
  {
   "id": "wayfarer",
   "focus": "Wayfarer",
   "name": "Briar Retreat",
   "mode": "subclass",
   "shape": "retreat",
   "visual": "retreat",
   "color": "#c2e6bc",
   "description": "Step away from your aim and leave a briar trap that roots enemies entering it.",
   "cooldown": 7600,
   "range": 4.1,
   "radius": 2.15,
   "bind": 1350
  }
 ],
 [
  {
   "id": "blood_harvester",
   "focus": "Blood Harvester",
   "name": "Blood Harvest",
   "mode": "subclass",
   "shape": "self",
   "visual": "harvest",
   "color": "#dc8d91",
   "description": "Sweep nearby enemies and recover health from the enemies hit.",
   "cooldown": 7600,
   "radius": 2.75,
   "damage": 2,
   "leech": true
  },
  {
   "id": "veilwalker",
   "focus": "Veilwalker",
   "name": "Veil Passage",
   "mode": "subclass",
   "shape": "dash",
   "visual": "veil",
   "color": "#bf9bed",
   "description": "Rush to the aimed location. Slash enemies at the landing point and mark the first survivor.",
   "cooldown": 7600,
   "range": 4.8,
   "radius": 2.15,
   "damage": 2
  },
  {
   "id": "gravekeeper",
   "focus": "Gravekeeper",
   "name": "Grave Sweep",
   "mode": "subclass",
   "shape": "cone",
   "visual": "grave",
   "color": "#d3bf9b",
   "description": "Sweep a wide arc. Hitting an enemy wards the most wounded nearby living ally.",
   "cooldown": 7600,
   "radius": 3.1,
   "span": 2.35,
   "damage": 2,
   "hit_ward": true
  }
 ],
 [
  {
   "id": "omenreader",
   "focus": "Omenreader",
   "name": "Foretell",
   "mode": "subclass",
   "shape": "ground",
   "visual": "omen",
   "color": "#efc788",
   "description": "Strike the aimed circle. Enemies already winding up take extra damage.",
   "cooldown": 7600,
   "range": 6.2,
   "radius": 2.4,
   "damage": 1,
   "punish": 1
  },
  {
   "id": "leykeeper",
   "focus": "Leykeeper",
   "name": "Guiding Bell",
   "mode": "subclass",
   "shape": "ground",
   "visual": "bell",
   "color": "#e7dbad",
   "description": "Pull enemies toward the chime and clear Slow from allies in its circle.",
   "cooldown": 7600,
   "range": 5.8,
   "radius": 2.6,
   "pull": 1.2,
   "cleanse": true
  },
  {
   "id": "lifekeeper",
   "focus": "Lifekeeper",
   "name": "Living Sanctuary",
   "mode": "subclass",
   "shape": "ground",
   "visual": "sanctuary",
   "color": "#a9d9b0",
   "description": "Heal living allies in the circle, then leave a pool that clears Slow.",
   "cooldown": 7600,
   "range": 5.4,
   "radius": 3,
   "heal": 1,
   "field": "tide",
   "field_power": 0,
   "duration": 3000
  }
 ]
]
const TITLES := [
 [
  [
   "Twining Reach",
   "Patient Spore",
   "Silken Gift"
  ],
  [
   "Branching Spores",
   "Holding Threads",
   "Clean Weave"
  ],
  [
   "Barbed Nova",
   "Threaded Nova",
   "Sheltering Nova"
  ]
 ],
 [
  [
   "Wider Pattern",
   "Long Draw",
   "Trail Ward"
  ],
  [
   "Splintershot",
   "Briar Tread",
   "Clear Trail"
  ],
  [
   "Barbed Snare",
   "Quick Reset",
   "Safe Passage"
  ]
 ],
 [
  [
   "Long Edge",
   "Lingering Veil",
   "Grave Ward"
  ],
  [
   "Second Cut",
   "Grave Grip",
   "Clear the Veil"
  ],
  [
   "Barbed Siphon",
   "Passing Echo",
   "Wake Ward"
  ]
 ],
 [
  [
   "Wide Omen",
   "Long Resonance",
   "Kindled Ward"
  ],
  [
   "Second Toll",
   "Anchored Ley",
   "Quiet Ground"
  ],
  [
   "Barbed Chime",
   "Quick Chime",
   "Shared Shelter"
  ]
 ]
]
const EFFECTS := [
	["Increase the skill’s circle, cone or shot width.", "Increase aim or travel range. Blood Harvest instead heals for one extra contact when hitting multiple enemies.", "Ward the most wounded ally in the skill’s footprint."],
	["A hit chains to one additional enemy near the impact.", "Briefly root enemies affected by the initial cast. Extend any roots it already applies.", "Clear Slow from allies in the skill’s footprint."],
	["Casting your subclass skill prepares your next second skill to damage one nearby foe.", "Casting your subclass skill prepares your next second skill to recharge sooner.", "Casting your subclass skill prepares your next second skill to ward nearby allies."]
]
static var NODES: Array = make_nodes()


static func make_nodes() -> Array:
	var result := []
	for c in FOCUSES.size():
		var rows := [[]]
		for entry in FOCUSES[c]:
			rows[0].append([entry.id,entry.focus,"Learn " + entry.name + "."])
		for tier in EFFECTS.size():
			var row := []
			for lane in Graph.LANES.size():
				row.append(["branch_%d_%d" % [tier+1,lane], TITLES[c][tier][lane], EFFECTS[tier][lane]])
			rows.append(row)
		result.append(Graph.make_nodes(rows))
	return result


static func focus(profile: Dictionary, class_id: int) -> Dictionary:
	var lane := lane_at(profile,class_id,0)
	return FOCUSES[class_id-1][lane] if lane >= 0 else {}


static func lane_at(profile: Dictionary, class_id: int, tier: int) -> int:
	var chosen := Graph.mask(profile,class_id)
	for lane in Graph.LANES.size():
		if chosen & (1 << (Graph.OFFSET + tier * Graph.LANES.size() + lane)):
			return lane
	return -1


static func skill(profile: Dictionary, class_id: int, slot: int, base: Dictionary) -> Dictionary:
	var tree := {1:Weaver.TREE,2:Ranger.TREE,3:Reaper.TREE,4:Oracle.TREE}[class_id] as RefCounted
	var selected: Array = tree.path(profile) if tree.eligible(profile) else []
	var entry: Dictionary = FOCUSES[class_id-1][tree.lane_at(selected,0)] if not selected.is_empty() else {}
	if entry.is_empty():
		return base
	var result := entry.duplicate(true) if slot == 0 else base
	result.subclass_focus = entry.id
	if class_id == 1:
		result.weaver_nodes = selected
		if slot == 0 and entry.id == "thornbinder":
			result.description = "Damage and root a visible foe and up to one nearby enemy."
		for tier in range(1,selected.size()):
			var node := Weaver.TREE.node(selected[tier])
			if (tier in [1,2,4] and slot == 0) or (tier >= 3 and slot == 1):
				result.description += "\n" + node.name + " · " + Weaver.description(node,entry.id,entry.name)
	elif class_id == 2:
		result.ranger_nodes = selected
		if slot == 0 and entry.id == "wildstalker":
			result.description = Ranger.PREY_DESCRIPTION
		if slot == 1 and selected.has("snarecraft"):
			result.radius = float(result.radius) + Ranger.CRAFT_RADIUS
			result.trap_ms = int(result.get("trap_ms",3800)) + Ranger.CRAFT_MS
		for tier in range(1,selected.size()):
			if ((tier <= 2 or tier == 4 or selected[tier] == "double_draw") if slot == 0 else
					(tier == 3 or selected[tier] in ["snarecraft","bramble_corridor","escape_route"])):
				var node := Ranger.TREE.node(selected[tier])
				result.description += "\n" + node.name + " · " + Ranger.description(node,entry.id,entry.name)
	elif class_id == Oracle.CLASS_ID:
		Oracle.configure_skill(result, selected, slot, entry.name)
	elif tree != null:
		result.reaper_nodes = selected
		if slot == 0 and entry.id == "veilwalker":
			result.description = Reaper.VEIL_DESCRIPTION
		for tier in range(1,selected.size()):
			var node := Reaper.TREE.node(selected[tier])
			var affects_q: bool = tier <= 2 or node.id == "grave_offering"
			if affects_q == (slot == 0):
				result.description += "\n" + node.name + " · " + Reaper.description(node,entry.id,entry.name)
	if slot != 0:
		result.subclass_follow_lane = -1
		if class_id == 1:
			var follow_lane := Weaver.TREE.lane_at(selected,3)
			result.subclass_follow_lane = follow_lane if follow_lane != 1 else -1
		return result
	var first: int = tree.lane_at(selected,1)
	if first == 0:
		if result.shape == "line":
			result.width += .24
		else:
			result.radius += .55
	if first == 1 and result.has("range"):
		result.range += 1.25
	result.first = first
	result.second = tree.lane_at(selected,2)
	if result.has("ranger_nodes"):
		result.ranger_support_radius = float(result.get("radius",2.0))
		if selected.has("trail_ward") or selected.has("clear_trail"):
			result.description += "\n%s support radius: %.2f m." % [entry.name,result.ranger_support_radius]
	return result


static func focus_name(id: String) -> String:
	for group in FOCUSES:
		for entry in group:
			if entry.id == id:
				return entry.focus
	return ""
