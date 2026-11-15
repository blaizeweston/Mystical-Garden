extends RefCounted
## Each row defines a class. Each focus owns its skill, release style and checkpoint card.
const Graph = preload("res://warden_tree.gd")
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
   "limit": 2,
   "card": {
    "id": "thornbinder_signature",
    "name": "Tangled Canopy",
    "description": "Bind reaches two additional enemies in its circle.",
    "classes": [
     1
    ],
    "focus": "thornbinder",
    "class_behavior": "subclass",
    "effect": {
     "extra": 2
    },
    "rarity": "Rare",
    "cost": 4,
    "weight": 2.2,
    "max_rank": 1,
    "effects": {}
   }
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
   "duration": 3000,
   "card": {
    "id": "bloomcaller_signature",
    "name": "Sheltering Bloom",
    "description": "Casting the bloom also wards allies inside its circle.",
    "classes": [
     1
    ],
    "focus": "bloomcaller",
    "class_behavior": "subclass",
    "effect": {
     "ward": true
    },
    "rarity": "Rare",
    "cost": 4,
    "weight": 2.2,
    "max_rank": 1,
    "effects": {}
   }
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
   "ward": true,
   "card": {
    "id": "silkwarden_signature",
    "name": "Clear the Web",
    "description": "Casting Silk Shelter cleanses Slow from allies inside.",
    "classes": [
     1
    ],
    "focus": "silkwarden",
    "class_behavior": "subclass",
    "effect": {
     "cleanse": true
    },
    "rarity": "Rare",
    "cost": 4,
    "weight": 2.2,
    "max_rank": 1,
    "effects": {}
   }
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
   "limit": 3,
   "marks": 1,
   "card": {
    "id": "wildstalker_signature",
    "name": "Two on the Trail",
    "description": "Mark a second survivor in the shot lane.",
    "classes": [
     2
    ],
    "focus": "wildstalker",
    "class_behavior": "subclass",
    "effect": {
     "marks": 1
    },
    "rarity": "Rare",
    "cost": 4,
    "weight": 2.2,
    "max_rank": 1,
    "effects": {}
   }
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
   "duration": 2700,
   "card": {
    "id": "snarekeeper_signature",
    "name": "Baited Thorns",
    "description": "The decoy also leaves a damaging thorn patch.",
    "classes": [
     2
    ],
    "focus": "snarekeeper",
    "class_behavior": "subclass",
    "effect": {
     "thorn_patch": true
    },
    "rarity": "Rare",
    "cost": 4,
    "weight": 2.2,
    "max_rank": 1,
    "effects": {}
   }
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
   "bind": 1350,
   "card": {
    "id": "wayfarer_signature",
    "name": "Covered Tracks",
    "description": "Gain a ward at your landing point.",
    "classes": [
     2
    ],
    "focus": "wayfarer",
    "class_behavior": "subclass",
    "effect": {
     "landing_ward": true
    },
    "rarity": "Rare",
    "cost": 4,
    "weight": 2.2,
    "max_rank": 1,
    "effects": {}
   }
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
   "leech": true,
   "card": {
    "id": "blood_harvester_signature",
    "name": "Reap the Fallen",
    "description": "Killing an enemy with the sweep primes bonus damage on your next weapon hit.",
    "classes": [
     3
    ],
    "focus": "blood_harvester",
    "class_behavior": "subclass",
    "effect": {
     "grave": true
    },
    "rarity": "Rare",
    "cost": 4,
    "weight": 2.2,
    "max_rank": 1,
    "effects": {}
   }
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
   "damage": 2,
   "marks": 1,
   "card": {
    "id": "veilwalker_signature",
    "name": "Through the Veil",
    "description": "Enemies at the landing point are briefly rooted.",
    "classes": [
     3
    ],
    "focus": "veilwalker",
    "class_behavior": "subclass",
    "effect": {
     "bind": 900
    },
    "rarity": "Rare",
    "cost": 4,
    "weight": 2.2,
    "max_rank": 1,
    "effects": {}
   }
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
   "hit_ward": true,
   "card": {
    "id": "gravekeeper_signature",
    "name": "Grave Chorus",
    "description": "A successful sweep wards all nearby living allies.",
    "classes": [
     3
    ],
    "focus": "gravekeeper",
    "class_behavior": "subclass",
    "effect": {
     "party_hit_ward": true
    },
    "rarity": "Rare",
    "cost": 4,
    "weight": 2.2,
    "max_rank": 1,
    "effects": {}
   }
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
   "punish": 1,
   "card": {
    "id": "omenreader_signature",
    "name": "Sentence of Dawn",
    "description": "Foretell deals more damage to enemies winding up.",
    "classes": [
     4
    ],
    "focus": "omenreader",
    "class_behavior": "subclass",
    "effect": {
     "punish": 1
    },
    "rarity": "Rare",
    "cost": 4,
    "weight": 2.2,
    "max_rank": 1,
    "effects": {}
   }
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
   "cleanse": true,
   "card": {
    "id": "leykeeper_signature",
    "name": "Hushed Chime",
    "description": "Root enemies briefly after the pull.",
    "classes": [
     4
    ],
    "focus": "leykeeper",
    "class_behavior": "subclass",
    "effect": {
     "bind": 750
    },
    "rarity": "Rare",
    "cost": 4,
    "weight": 2.2,
    "max_rank": 1,
    "effects": {}
   }
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
   "duration": 3000,
   "card": {
    "id": "lifekeeper_signature",
    "name": "Bower of Light",
    "description": "Grant a ward to living allies inside when the sanctuary opens.",
    "classes": [
     4
    ],
    "focus": "lifekeeper",
    "class_behavior": "subclass",
    "effect": {
     "ward": true
    },
    "rarity": "Rare",
    "cost": 4,
    "weight": 2.2,
    "max_rank": 1,
    "effects": {}
   }
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
	var entry := focus(profile,class_id)
	if entry.is_empty():
		return base
	var result := entry.duplicate(true) if slot == 0 else base
	result.subclass_focus = entry.id
	for tier in range(1,4):
		var lane := lane_at(profile,class_id,tier)
		if lane < 0:
			continue
		if (tier == 3) == (slot == 1):
			result.description += "\n" + TITLES[class_id-1][tier-1][lane] + " · " + EFFECTS[tier-1][lane]
	if slot != 0:
		result.subclass_follow_lane = lane_at(profile,class_id,3)
		return result
	var first := lane_at(profile,class_id,1)
	if first == 0:
		if result.shape == "line":
			result.width += .24
		else:
			result.radius += .55
	if first == 1 and result.has("range"):
		result.range += 1.25
	result.first = first
	result.second = lane_at(profile,class_id,2)
	return result


static func cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for group in FOCUSES:
		for entry in group:
			result.append(entry.card)
	return result


static func focus_name(id: String) -> String:
	for group in FOCUSES:
		for entry in group:
			if entry.id == id:
				return entry.focus
	return ""


static func card_lines(player: Dictionary, slot: int) -> String:
	if slot != 0 or int(player.get("frame",0)) == 0 or player.has("combat_ruleset"):
		return ""
	var entry := focus(player.get("character",{}),int(player.frame))
	if entry.is_empty() or int(player.get("run_upgrades",{}).get(entry.card.id,0)) == 0:
		return ""
	return entry.card.name + " · " + entry.card.description
