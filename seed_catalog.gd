extends RefCounted
# Data template: stable id, lineage, rarity, Wilds depth, growth, appearance and crafting effects.
# Append entries; do not reorder published species/part IDs.
const DEFINITIONS := [
 {
  "id": "thorn_bloom",
  "name": "Thorn Bloom",
  "tier": 1,
  "rarity": "Common",
  "parents": [],
  "wild_min": 1,
  "biome": 0,
  "color": "#b96570",
  "form": "flower",
  "hint": "A thorned stem reaches beyond its roots.",
  "legacy_grow_seconds": 80,
  "grow_seconds": 300,
  "part": 1,
  "effects": {
   "reach": 0.9,
   "reach_step": 0.6
  },
  "tags": [
   "piercing",
   "thorn"
  ]
 },
 {
  "id": "lantern_moss",
  "name": "Lantern Moss",
  "tier": 1,
  "rarity": "Common",
  "parents": [],
  "wild_min": 1,
  "biome": 1,
  "color": "#c3ce72",
  "form": "moss",
  "hint": "Soft light delays the corruption after a strike.",
  "legacy_grow_seconds": 80,
  "grow_seconds": 300,
  "part": 2,
  "effects": {
   "recovery": 550,
   "recovery_step": 450
  },
  "tags": [
   "vital",
   "luminous"
  ]
 },
 {
  "id": "veilcap",
  "name": "Veilcap",
  "tier": 2,
  "rarity": "Uncommon",
  "parents": [
   0,
   1
  ],
  "wild_min": 6,
  "biome": 2,
  "color": "#a58abb",
  "form": "cap",
  "hint": "Thorns sheltering lantern light may grow a veil.",
  "legacy_grow_seconds": 80,
  "grow_seconds": 720,
  "part": 3,
  "effects": {
   "windup_damage": 1,
   "windup_damage_step": 1
  },
  "tags": [
   "arcane",
   "spore"
  ]
 },
 {
  "id": "ember_fern",
  "name": "Ember Fern",
  "tier": 1,
  "rarity": "Common",
  "parents": [],
  "wild_min": 3,
  "biome": 0,
  "color": "#e38b48",
  "form": "fern",
  "hint": "Warm spores gather beyond the first encounters.",
  "legacy_grow_seconds": 80,
  "grow_seconds": 300,
  "part": 6,
  "effects": {
   "damage": 1,
   "cooldown": -120,
   "cooldown_step": 90
  },
  "tags": [
   "fire",
   "volatile"
  ]
 },
 {
  "id": "cinder_vine",
  "name": "Cinder Vine",
  "tier": 2,
  "rarity": "Uncommon",
  "parents": [
   0,
   3
  ],
  "wild_min": 8,
  "biome": 1,
  "color": "#c85b3c",
  "form": "vine",
  "hint": "A reaching thorn may learn to carry embers.",
  "legacy_grow_seconds": 105,
  "grow_seconds": 720,
  "part": 7,
  "effects": {
   "reach": 0.5,
   "damage": 1,
   "cooldown": -100,
   "reach_step": 0.3
  },
  "tags": [
   "fire",
   "piercing"
  ]
 },
 {
  "id": "dewcap",
  "name": "Dewcap",
  "tier": 2,
  "rarity": "Uncommon",
  "parents": [
   1,
   3
  ],
  "wild_min": 8,
  "biome": 2,
  "color": "#77bac3",
  "form": "cap",
  "hint": "Lantern light cools the ember into morning dew.",
  "legacy_grow_seconds": 105,
  "grow_seconds": 720,
  "part": 8,
  "effects": {
   "recovery": 300,
   "cooldown": 70,
   "cooldown_step": 60
  },
  "tags": [
   "water",
   "vital"
  ]
 },
 {
  "id": "bloodbriar",
  "name": "Bloodbriar",
  "tier": 3,
  "rarity": "Rare",
  "parents": [
   0,
   4
  ],
  "wild_min": 16,
  "biome": 0,
  "color": "#b63e64",
  "form": "vine",
  "hint": "Feed a burning vine the patience of another thorn.",
  "legacy_grow_seconds": 130,
  "grow_seconds": 1500,
  "part": 9,
  "effects": {
   "damage": 1,
   "heal_on_kill": 1,
   "cooldown": -140,
   "cooldown_step": 90
  },
  "tags": [
   "blood",
   "vital"
  ]
 },
 {
  "id": "ghost_fern",
  "name": "Ghost Fern",
  "tier": 3,
  "rarity": "Rare",
  "parents": [
   1,
   2
  ],
  "wild_min": 16,
  "biome": 1,
  "color": "#93c7b1",
  "form": "fern",
  "hint": "A veil may shelter the oldest lantern light.",
  "legacy_grow_seconds": 130,
  "grow_seconds": 1500,
  "part": 10,
  "effects": {
   "reach": 0.4,
   "recovery": 850,
   "recovery_step": 200
  },
  "tags": [
   "spirit",
   "control"
  ]
 },
 {
  "id": "storm_reed",
  "name": "Storm Reed",
  "tier": 3,
  "rarity": "Rare",
  "parents": [
   4,
   5
  ],
  "wild_min": 18,
  "biome": 2,
  "color": "#8cafe1",
  "form": "reed",
  "hint": "Steam rises where the burning vine meets dew.",
  "legacy_grow_seconds": 130,
  "grow_seconds": 1500,
  "part": 11,
  "effects": {
   "cooldown": 100,
   "knockback": 0.65,
   "cooldown_step": 45
  },
  "tags": [
   "storm",
   "force"
  ]
 },
 {
  "id": "moon_lotus",
  "seed_acquisition": "wild_only",
  "name": "Moon Lotus",
  "tier": 3,
  "rarity": "Rare",
  "parents": [
   2,
   5
  ],
  "wild_min": 18,
  "biome": 0,
  "color": "#c2b7eb",
  "form": "lotus",
  "hint": "A veiled cap opens where the dew settles.",
  "legacy_grow_seconds": 130,
  "grow_seconds": 1500,
  "part": 12,
  "effects": {
   "windup_damage": 2,
   "recovery": 400,
   "windup_damage_step": 1
  },
  "tags": [
   "lunar",
   "arcane"
  ]
 },
 {
  "id": "star_orchid",
  "seed_acquisition": "wild_only",
  "name": "Star Orchid",
  "tier": 4,
  "rarity": "Epic",
  "parents": [
   6,
   7
  ],
  "wild_min": 31,
  "biome": 1,
  "color": "#edc984",
  "form": "flower",
  "hint": "Blood and a ghost may nurture a distant star.",
  "legacy_grow_seconds": 155,
  "grow_seconds": 3000,
  "part": 13,
  "effects": {
   "damage": 1,
   "reach": 1.1,
   "cooldown": -170,
   "reach_step": 0.35
  },
  "tags": [
   "radiant",
   "piercing"
  ]
 },
 {
  "id": "void_willow",
  "name": "Void Willow",
  "tier": 4,
  "rarity": "Epic",
  "parents": [
   7,
   9
  ],
  "wild_min": 31,
  "biome": 2,
  "color": "#8671b7",
  "form": "willow",
  "hint": "A ghost watches the moon reflected in an empty pool.",
  "legacy_grow_seconds": 155,
  "grow_seconds": 3000,
  "part": 14,
  "effects": {
   "pull": 1.2,
   "windup_damage": 2,
   "cooldown": -140,
   "pull_step": 0.25
  },
  "tags": [
   "void",
   "control"
  ]
 },
 {
  "id": "sun_spire",
  "seed_acquisition": "wild_only",
  "name": "Sun Spire",
  "tier": 4,
  "rarity": "Epic",
  "parents": [
   6,
   8
  ],
  "wild_min": 35,
  "biome": 0,
  "color": "#f2ad55",
  "form": "reed",
  "hint": "A blood-fed storm reaches for a sun.",
  "legacy_grow_seconds": 155,
  "grow_seconds": 3000,
  "part": 15,
  "effects": {
   "damage": 2,
   "knockback": 0.4,
   "cooldown": -200,
   "cooldown_step": 70
  },
  "tags": [
   "fire",
   "radiant"
  ]
 },
 {
  "id": "eclipse_root",
  "name": "Eclipse Root",
  "tier": 5,
  "rarity": "Mythic",
  "parents": [
   10,
   11
  ],
  "wild_min": 51,
  "biome": 1,
  "color": "#cf82bf",
  "form": "willow",
  "hint": "A star falls beneath the shadow of the willow.",
  "legacy_grow_seconds": 180,
  "grow_seconds": 5400,
  "part": 16,
  "effects": {
   "reach": 0.6,
   "recovery": 700,
   "heal_on_kill": 1,
   "cooldown": -240,
   "recovery_step": 200
  },
  "tags": [
   "void",
   "blood"
  ]
 },
 {
  "id": "worldseed",
  "name": "Worldseed",
  "tier": 5,
  "rarity": "Mythic",
  "parents": [
   11,
   12
  ],
  "wild_min": 56,
  "biome": 2,
  "color": "#c2d58c",
  "form": "lotus",
  "hint": "The empty willow shelters the last light of the spire.",
  "legacy_grow_seconds": 180,
  "grow_seconds": 5400,
  "part": 17,
  "effects": {
   "windup_damage": 3,
   "stagger": 180,
   "knockback": 0.8,
   "cooldown": -180,
   "cooldown_step": 60
  },
  "tags": [
   "ancient",
   "force"
  ]
 },
 {
  "id": "frostbell",
  "name": "Frostbell",
  "tier": 3,
  "rarity": "Rare",
  "parents": [
   1,
   5
  ],
  "wild_min": 20,
  "biome": 1,
  "color": "#9ed6e5",
  "form": "bell",
  "hint": "Lantern light gathers dew until its flowers ring with frost.",
  "legacy_grow_seconds": 140,
  "grow_seconds": 1500,
  "part": 44,
  "effects": {
   "brittle": 1,
   "shatter_damage": 2,
   "cooldown": -100
  },
  "tags": [
   "frost",
   "water"
  ],
  "behavior": "Hits build brittle for 4 seconds. Three stacks shatter for bonus damage. Slower swings reward repeated contact.",
  "part_name": "Chiming Sepal",
  "refined_name": "Crystalline Bellheart"
 },
 {
  "id": "ironroot",
  "name": "Ironroot",
  "tier": 2,
  "rarity": "Uncommon",
  "parents": [
   3,
   3
  ],
  "wild_min": 10,
  "biome": 0,
  "color": "#8e9b8e",
  "form": "root",
  "hint": "Embers entwine until their roots grow heavy.",
  "legacy_grow_seconds": 130,
  "grow_seconds": 720,
  "part": 46,
  "effects": {
   "brace": 1,
   "stagger": 90,
   "cooldown": -140
  },
  "tags": [
   "brace",
   "wood"
  ],
  "behavior": "Stand still for 0.5s to brace. Your next weapon hit deals extra damage. Blocks one hit every 4s.",
  "part_name": "Banded Root",
  "refined_name": "Ironwood Core"
 },
 {
  "id": "whispervine",
  "name": "Whispervine",
  "tier": 3,
  "rarity": "Rare",
  "parents": [
   0,
   2
  ],
  "wild_min": 18,
  "biome": 0,
  "color": "#a6bf8d",
  "form": "whisper",
  "hint": "A thorn shelters the silent veil.",
  "legacy_grow_seconds": 155,
  "grow_seconds": 1500,
  "part": 48,
  "effects": {
   "mark_damage": 1,
   "reach": 0.25
  },
  "tags": [
   "mark",
   "spirit"
  ],
  "behavior": "First contact marks for 4 seconds. Further contacts exploit the mark for extra damage.",
  "part_name": "Listening Tendril",
  "refined_name": "Whisper Nerve"
 },
 {
  "id": "mirror_mint",
  "seed_acquisition": "wild_only",
  "name": "Mirror Mint",
  "tier": 3,
  "rarity": "Rare",
  "parents": [
   2,
   4
  ],
  "wild_min": 22,
  "biome": 2,
  "color": "#b6d8cf",
  "form": "mirror",
  "hint": "A veil reflects the last cinder.",
  "legacy_grow_seconds": 155,
  "grow_seconds": 1500,
  "part": 50,
  "effects": {
   "echo": 1,
   "cooldown": -100
  },
  "tags": [
   "echo",
   "arcane"
  ],
  "behavior": "Every third contact echoes once after a short delay at half strength. Echoes cannot echo themselves.",
  "part_name": "Silvered Leaf",
  "refined_name": "Prismatic Frond"
 },
 {
  "id": "gravemoss",
  "name": "Gravemoss",
  "tier": 3,
  "rarity": "Rare",
  "parents": [
   1,
   4
  ],
  "wild_min": 24,
  "biome": 2,
  "color": "#b5b4a0",
  "form": "grave",
  "hint": "Cinders rest beneath a lantern-lit moss.",
  "legacy_grow_seconds": 155,
  "grow_seconds": 1500,
  "part": 52,
  "effects": {
   "death_charge": 1,
   "cooldown": -90
  },
  "tags": [
   "grave",
   "blood"
  ],
  "behavior": "Natural killing blows store up to three death charges. A later hit consumes one for extra damage.",
  "part_name": "Grave Filament",
  "refined_name": "Funeral Spore"
 },
 {
  "id": "tide_lily",
  "name": "Tide Lily",
  "tier": 3,
  "rarity": "Rare",
  "parents": [
   3,
   5
  ],
  "wild_min": 24,
  "biome": 1,
  "color": "#79bed2",
  "form": "tide",
  "hint": "Warm fronds drink the gathered dew.",
  "legacy_grow_seconds": 155,
  "grow_seconds": 1500,
  "part": 54,
  "effects": {
   "tide_pool": 1,
   "damage": -0.3
  },
  "tags": [
   "tide",
   "water"
  ],
  "behavior": "Contact creates a brief healing pool with a 4.5s recovery. Living allies in the pool recover and cleanse slowing roots.",
  "part_name": "Dew Chalice",
  "refined_name": "Pearl Stamen"
 },
 {
  "id": "hush_orchid",
  "name": "Hush Orchid",
  "tier": 4,
  "rarity": "Epic",
  "parents": [
   7,
   15
  ],
  "wild_min": 38,
  "biome": 2,
  "color": "#63567e",
  "form": "hush",
  "hint": "A ghostly fern listens to crystalline bells.",
  "legacy_grow_seconds": 180,
  "grow_seconds": 3000,
  "part": 56,
  "effects": {
   "suppress": 1,
   "cooldown": -150
  },
  "tags": [
   "hush",
   "arcane"
  ],
  "behavior": "A precisely timed contact interrupts an enemy wind-up. Each enemy resists another interruption for 4 seconds.",
  "part_name": "Silent Petal",
  "refined_name": "Hollow Throat"
 },
 {
  "id": "dream_poppy",
  "name": "Dream Poppy",
  "tier": 4,
  "rarity": "Epic",
  "parents": [
   6,
   18
  ],
  "wild_min": 40,
  "biome": 1,
  "color": "#d19bb6",
  "form": "dream",
  "hint": "Blood-red thorns reach for a mirrored leaf.",
  "legacy_grow_seconds": 180,
  "grow_seconds": 3000,
  "part": 58,
  "effects": {
   "decoy": 1,
   "damage": -0.3,
   "cooldown": -80
  },
  "tags": [
   "dream",
   "spirit"
  ],
  "behavior": "Contact grows a short-lived decoy away from you. Foes pursuing you are drawn toward it; it cannot deal damage.",
  "part_name": "Dream Pollen",
  "refined_name": "Lucid Capsule"
 },
 {
  "id": "crownroot",
  "seed_acquisition": "wild_only",
  "name": "Crownroot",
  "tier": 5,
  "rarity": "Mythic",
  "parents": [
   21,
   22
  ],
  "wild_min": 60,
  "biome": 2,
  "color": "#cfbd82",
  "form": "crown",
  "hint": "Silence and dreams entwine around an empty crown.",
  "legacy_grow_seconds": 205,
  "grow_seconds": 5400,
  "part": 60,
  "effects": {
   "link": 1,
   "cooldown": -200
  },
  "tags": [
   "link",
   "ancient"
  ],
  "behavior": "Links a contact to a nearby second enemy at reduced strength. Linked hits may carry brittle or marks but cannot branch again.",
  "part_name": "Woven Root",
  "refined_name": "Sovereign Knot"
 }
]
static var NAMES: Array = make_names()

static func make_names() -> Array:
 var result: Array = []
 for entry in DEFINITIONS:
  result.append(entry.name)
 return result

static func counts(value = 0) -> Array:
 var result: Array = []
 result.resize(DEFINITIONS.size())
 result.fill(value)
 return result

static func species_for_part(part: int) -> int:
 for i in DEFINITIONS.size():
  if int(DEFINITIONS[i].part) == part:
   return i
 return -1

## Absent acquisition restrictions allow both mystery pools and compatible seed recipes.
static func wild_only(species: int) -> bool:
 return DEFINITIONS[species].get("seed_acquisition", "") == "wild_only"

## Pre-altar save conversion needs the historical parentage, including retired pairs.
static func lineage_child(first: int, second: int) -> int:
 for i in DEFINITIONS.size():
  var parents: Array = DEFINITIONS[i].parents
  if parents.size() == 2 and ((parents[0] == first and parents[1] == second) or (parents[0] == second and parents[1] == first)):
   return i
 return -1

static func modifier_text(kind: int) -> String:
 # Deferred presentation load avoids the foundational Seeds/Parts/Items preload cycle.
 # Reuse affinity descriptions; gameplay tuning stays in the family definitions.
 return load("res://affinity_build.gd").planting_description(kind)

static func index_of(id: String) -> int:
 for i in DEFINITIONS.size():
  if str(DEFINITIONS[i].id)==id: return i
 return -1

