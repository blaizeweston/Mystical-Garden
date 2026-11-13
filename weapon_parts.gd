extends RefCounted

enum { EMPTY, THORN, MOSS, VEIL, HOOK, HEARTWOOD }

const Seeds = preload("res://seed_catalog.gd")
const BASE_DEFINITIONS := [
 {
  "name": "Empty",
  "technique": "Faster strikes",
  "cooldown_step": 140
 },
 {
  "name": "Thorn Bloom",
  "technique": "Longer reach",
  "reach": 0.9,
  "reach_step": 0.6
 },
 {
  "name": "Lantern Moss",
  "technique": "Longer briar recovery",
  "recovery": 550,
  "recovery_step": 450
 },
 {
  "name": "Veilcap",
  "technique": "Stronger wind-up strike",
  "windup_damage": 1,
  "windup_damage_step": 1
 },
 {
  "name": "Briar Hook",
  "technique": "Stronger pull",
  "pull": 0.8,
  "pull_step": 0.3
 },
 {
  "name": "Heartwood Barb",
  "technique": "Faster strikes",
  "plant": 0,
  "damage": 1,
  "cooldown_step": 140
 }
]
const MONSTER_DEFINITIONS := [
 {
  "name": "Briar Hook",
  "tags": [
   "grasp",
   "thorn"
  ],
  "effects": {
   "pull": 0.8
  },
  "monster": 0,
  "rarity": "Common"
 },
 {
  "name": "Nightbloom Pollen",
  "tags": [
   "spore",
   "arcane"
  ],
  "effects": {
   "recovery": 650,
   "windup_damage": 1
  },
  "monster": 1,
  "rarity": "Uncommon"
 },
 {
  "name": "Gallhorn Antler",
  "tags": [
   "piercing",
   "force"
  ],
  "effects": {
   "reach": 0.7,
   "knockback": 0.3
  },
  "monster": 2,
  "rarity": "Uncommon"
 },
 {
  "name": "Cantor Bellcap",
  "tags": [
   "luminous",
   "spore"
  ],
  "effects": {
   "skill_cooldown": 900,
   "recovery": 300
  },
  "monster": 3,
  "rarity": "Rare"
 },
 {
  "name": "Thornmaw Fang",
  "tags": [
   "blood",
   "piercing"
  ],
  "effects": {
   "damage": 1,
   "cooldown": -120
  },
  "monster": 4,
  "rarity": "Common"
 },
 {
  "name": "Willow Sinew",
  "tags": [
   "grasp",
   "spirit"
  ],
  "effects": {
   "pull": 1.1,
   "reach": 0.3
  },
  "monster": 5,
  "rarity": "Rare"
 },
 {
  "name": "Orchid Sac",
  "tags": [
   "spore",
   "vital"
  ],
  "effects": {
   "heal_on_kill": 1,
   "recovery": 350
  },
  "monster": 6,
  "rarity": "Rare"
 },
 {
  "name": "Gravebud Husk",
  "tags": [
   "wood",
   "force"
  ],
  "effects": {
   "knockback": 0.65,
   "stagger": 90
  },
  "monster": 7,
  "rarity": "Epic"
 },
 {
  "name": "Wicker Sting",
  "tags": [
   "storm",
   "piercing"
  ],
  "effects": {
   "cooldown": 70,
   "windup_damage": 1
  },
  "monster": 8,
  "rarity": "Uncommon"
 },
 {
  "name": "Brood Heart",
  "tags": [
   "ancient",
   "spore"
  ],
  "effects": {
   "targets": 1,
   "recovery": 400
  },
  "monster": 9,
  "rarity": "Epic"
 },
 {
  "name": "Shepherd Knot",
  "tags": [
   "root",
   "chain"
  ],
  "effects": {
   "targets": 1,
   "recovery": 150
  },
  "monster": 10,
  "rarity": "Rare"
 },
 {
  "name": "Hollow Carapace",
  "tags": [
   "wood",
   "ward"
  ],
  "effects": {
   "max_health": 2,
   "knockback": 0.25
  },
  "monster": 11,
  "rarity": "Uncommon"
 },
 {
  "name": "Lure Bladder",
  "tags": [
   "water",
   "pull"
  ],
  "effects": {
   "pull": 0.65,
   "recovery": 180
  },
  "monster": 12,
  "rarity": "Uncommon"
 },
 {
  "name": "Burrowing Tendon",
  "tags": [
   "earth",
   "piercing"
  ],
  "effects": {
   "targets": 1,
   "reach": 0.6,
   "pierce": 1
  },
  "monster": 13,
  "rarity": "Rare"
 },
 {
  "name": "Silken Mycelium",
  "tags": [
   "spore",
   "link"
  ],
  "effects": {
   "link": 1
  },
  "monster": 14,
  "rarity": "Rare"
 },
 {
  "name": "Funeral Petal",
  "tags": [
   "death",
   "spirit"
  ],
  "effects": {
   "death_charge": 1
  },
  "monster": 15,
  "rarity": "Rare"
 },
 {
  "name": "Grasping Rootlet",
  "tags": [
   "grasp",
   "scavenge"
  ],
  "effects": {
   "loot_attract": 3.5
  },
  "monster": 16,
  "rarity": "Rare"
 },
 {
  "name": "Cinder Antler",
  "tags": [
   "ember",
   "force"
  ],
  "effects": {
   "cinder_trail": 1
  },
  "monster": 17,
  "rarity": "Rare"
 },
 {
  "name": "Prismatic Gill",
  "tags": [
   "crystal",
   "arcane"
  ],
  "effects": {
   "echo": 1,
   "echo_redirect": 1
  },
  "monster": 18,
  "rarity": "Rare"
 },
 {
  "name": "Chorus Node",
  "tags": [
   "resonance",
   "spirit"
  ],
  "effects": {
   "chorus_pulse": 1
  },
  "monster": 19,
  "rarity": "Rare"
 },
 {
  "name": "Orchard Heartwood",
  "tags": [
   "wood",
   "earth"
  ],
  "effects": {
   "brace": 1,
   "knockback": 0.5
  },
  "monster": 20,
  "rarity": "Epic"
 },
 {
  "name": "Congregation Pearl",
  "tags": [
   "tide",
   "spirit"
  ],
  "effects": {
   "tide_pool": 1,
   "pool_radius": 0.4
  },
  "monster": 21,
  "rarity": "Epic"
 },
 {
  "name": "Matriarch Spindle",
  "tags": [
   "spore",
   "link"
  ],
  "effects": {
   "link": 1,
   "spread_bind": 1
  },
  "monster": 22,
  "rarity": "Epic"
 },
 {
  "name": "Nameless Stigma",
  "tags": [
   "arcane",
   "resonance"
  ],
  "effects": {
   "echo": 1,
   "mark_damage": 1
  },
  "monster": 23,
  "rarity": "Epic"
 }
]
static var DEFINITIONS: Array = make_definitions()

static func make_definitions() -> Array:
 var legacy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/content/legacy_v1_manifest.json"))
 var enemies: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/enemies/catalog.json"))
 var entries: Dictionary={"empty":BASE_DEFINITIONS[0].duplicate(true),"rare:heartwood_barb":BASE_DEFINITIONS[HEARTWOOD].duplicate(true)}
 entries["rare:heartwood_barb"].plant=Seeds.index_of("thorn_bloom");entries["rare:heartwood_barb"].rarity="Rare";entries["rare:heartwood_barb"].tags=["wood","piercing"]
 for species in Seeds.DEFINITIONS.size():
  var seed: Dictionary=Seeds.DEFINITIONS[species];var id: String="plant:"+str(seed.id)
  var data: Dictionary=BASE_DEFINITIONS[int(seed.part)].duplicate(true) if int(seed.part)<BASE_DEFINITIONS.size() and int(seed.part) not in [HOOK,HEARTWOOD] else {"name":str(seed.name)+" part","technique":"Faster strikes"}
  data.merge(seed.effects,true);data.name=seed.get("part_name",data.name);data.plant=species;data.tags=seed.get("tags",["wood"]);entries[id]=data
 for i in MONSTER_DEFINITIONS.size():
  var entry: Dictionary=MONSTER_DEFINITIONS[i];var data: Dictionary={"name":entry.name,"monster":i,"tags":entry.tags,"technique":"Monster graft","rarity":entry.get("rarity","Uncommon")}
  data.merge(entry.effects,true);entries["monster:"+str(enemies[i].id)]=data
 # Rare harvest products share the same component template as ordinary parts.
 for species in Seeds.DEFINITIONS.size():
  var seed: Dictionary=Seeds.DEFINITIONS[species]
  if str(seed.id)=="thorn_bloom": continue
  var effects: Dictionary={}
  for key in seed.effects:
   if seed.effects[key] is int or seed.effects[key] is float: effects[key]=float(seed.effects[key])*(1.35 if float(seed.effects[key])>=0 else .85)
  var rarity: String=["Common","Uncommon","Rare","Epic","Mythic"][mini(4,int(seed.tier))]
  var data: Dictionary={"name":seed.get("refined_name","Pristine "+str(seed.name)+" material"),"plant":species,"tags":seed.tags.duplicate(),"technique":"Refined plant material","rare":true,"rarity":rarity}
  data.merge(effects,true);entries["rare:"+str(seed.id)]=data
 var custom=JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/custom_components.json"))
 if custom is Array:
  for entry in custom:
   if entry is Dictionary and entry.get("id") is String and not entries.has(entry.id) and entry.get("effects") is Dictionary and entry.get("plant") is String:
    var species:=Seeds.index_of(entry.plant)
    if species>=0:
     var data: Dictionary={"name":entry.get("name",entry.id),"plant":species,"tags":entry.get("tags",[]),"technique":"Custom component","rare":true,"rarity":entry.get("rarity","Rare")}
     data.merge(entry.effects,true);entries[entry.id]=data
 var order: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/content/part_order.json"))
 for id in entries:
  if not order.has(id): order.append(id)
 var result: Array=[]
 for id in order:
  var data: Dictionary=entries.get(id,{"name":"Retired component","technique":"Retired","retired":true}).duplicate(true)
  data.id=id
  if not data.has("tags"): data.tags=[]
  var historic: int=legacy.parts.find(id)
  data.item_id="monster_"+str(data.monster) if data.has("monster") else "part_"+str(historic) if historic>0 else "plant_part_"+str(id).replace(":","_")
  result.append(data)
 return result


static func is_monster(part: int) -> bool:
 return part>0 and part<DEFINITIONS.size() and DEFINITIONS[part].has("monster")

static func is_plant(part: int) -> bool:
 return part>0 and part<DEFINITIONS.size() and not is_monster(part) and not DEFINITIONS[part].get("retired",false)

static func monster_part(kind: int) -> int:
 for part in range(1,DEFINITIONS.size()):
  if is_monster(part) and int(DEFINITIONS[part].monster)==kind: return part
 return HOOK


static func empty_counts() -> Array:
 var counts: Array = []
 counts.resize(DEFINITIONS.size())
 counts.fill(0)
 return counts


static func plant_source(part: int) -> int:
 return int(DEFINITIONS[part].get("plant",-1)) if part>0 and part<DEFINITIONS.size() else -1


static func part_name(part: int) -> String:
 return str(DEFINITIONS[part].name) if part>=0 and part<DEFINITIONS.size() else "Unknown component"


static func effect(primary: int, secondary: int, attribute: String, technique: int) -> float:
 var core: Dictionary = DEFINITIONS[primary]
 return float(core.get(attribute, 0)) + float(DEFINITIONS[secondary].get(attribute, 0)) + (
  float(core.get(attribute + "_step", 0)) * technique
 )


static func has_rift_pair(primary: int, secondary: int) -> bool:
 return (primary == VEIL and secondary == HOOK) or (primary == HOOK and secondary == VEIL)


static func index_of(id: String) -> int:
 for i in DEFINITIONS.size():
  if str(DEFINITIONS[i].id)==id: return i
 return -1
static func rare_part(species: int) -> int:
 if species<0 or species>=Seeds.DEFINITIONS.size(): return -1
 return HEARTWOOD if str(Seeds.DEFINITIONS[species].id)=="thorn_bloom" else index_of("rare:"+str(Seeds.DEFINITIONS[species].id))
