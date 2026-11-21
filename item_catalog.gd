extends RefCounted
const Seeds=preload("res://seed_catalog.gd")
const Parts=preload("res://weapon_parts.gd")
const MONSTER_PART_DESCRIPTION := "Spend at Grafting Altars on expedition reinforcements or eligible adaptations. One successful improvement per player at each altar. Selected monster parts are consumed on a successful purchase."
const RARITIES: Array=["Common","Uncommon","Rare","Epic","Mythic"]
const COLORS: Array=["#b8bca7","#88b963","#6dafe0","#b489db","#e0b25b"]
static var registry: Dictionary={}
static func all() -> Dictionary:
 if not registry.is_empty(): return registry
 registry["unidentified_seed"]={"id":"unidentified_seed","name":"Mysterious Seed","category":"seed","rarity":"Unknown","stack_limit":99,"tags":["unidentified"],"monster_tags":[],"icon":"","description":"Identify this seed at the Garden altar. Its species remains concealed.","pouch_allowed":true}
 registry["boss_mystery_seed"]={"id":"boss_mystery_seed","name":"Ancient Mystery Seed","category":"seed","rarity":"Epic","stack_limit":99,"tags":["unidentified","boss"],"monster_tags":[],"icon":"","description":"A rare threat sheltered this seed. Identify at the Garden altar: 25% Rare lineage, 55% Epic lineage, 20% Mythic lineage.","pouch_allowed":true}
 for i in Seeds.DEFINITIONS.size():
  var plant_definition: Dictionary=Seeds.DEFINITIONS[i]
  var item: Dictionary={"id":"seed_"+str(plant_definition.id),"name":str(plant_definition.name)+" Seed","category":"seed","rarity":plant_definition.rarity,"stack_limit":99,"tags":plant_definition.tags.duplicate(),"monster_tags":[],"legacy_seed":i,"icon":"res://assets/ui/seeds/"+str(plant_definition.id)+".png","description":Seeds.modifier_text(i),"pouch_allowed":true}
  registry[item.id]=item
 for part in range(1,Parts.DEFINITIONS.size()):
  var monster:=Parts.is_monster(part)
  var source:=Parts.plant_source(part)
  var id: String=str(Parts.DEFINITIONS[part].item_id)
  var rarity: String=str(Parts.DEFINITIONS[part].get("rarity","Uncommon")) if monster else str(Parts.DEFINITIONS[part].get("rarity",Seeds.DEFINITIONS[source].rarity))
  var entry: Dictionary={"id":id,"name":Parts.part_name(part),"category":"monster_part" if monster else "plant_part","rarity":rarity,"stack_limit":99,"tags":Parts.DEFINITIONS[part].get("tags",[]).duplicate(),"monster_tags":[],"legacy_part":part,"icon":"" if monster else "res://assets/ui/parts/"+str(Parts.DEFINITIONS[part].id).replace(":","_")+".svg","description":MONSTER_PART_DESCRIPTION if monster else "A plant material for crafting and Garden technologies.","pouch_allowed":true,"loot_weight":1.0}
  if monster:
   var enemies: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/enemies/catalog.json"))
   entry.monster_tags=[str(enemies[int(Parts.DEFINITIONS[part].monster)].id)]
  registry[id]=entry
 var custom=JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/custom_items.json"))
 if custom is Array:
  for entry in custom: register(entry)
 return registry
static func register(entry: Dictionary) -> bool:
 var id:=str(entry.get("id",""))
 if id.is_empty() or registry.has(id) or str(entry.get("name","")).is_empty(): return false
 if entry.get("category","") in ["plant_part","monster_part"]:
  var part:=Parts.index_of(str(entry.get("component","")))
  if part<1: return false
  entry=entry.duplicate(true);entry.legacy_part=part
 var clean: Dictionary={"category":"material","rarity":"Common","stack_limit":99,"tags":[],"monster_tags":[],"icon":"","description":"","pouch_allowed":true,"loot_weight":1.0}
 clean.merge(entry,true)
 clean.stack_limit=clampi(int(clean.stack_limit),1,9999)
 if not RARITIES.has(clean.rarity): clean.rarity="Common"
 registry[id]=clean
 return true
static func get_item(id: String) -> Dictionary:
 return all().get(id,{})
static func describe(item: Dictionary) -> String:
 var part:=int(item.get("legacy_part",0))
 if part>0 and part<Parts.DEFINITIONS.size():
  if Parts.is_monster(part):return MONSTER_PART_DESCRIPTION
  if Parts.is_plant(part):
   # Deferred to avoid a static Items/Seeds/Parts/affinity preload cycle.
   # Reuse the current family descriptions rather than duplicate their tunable values.
   return load("res://affinity_build.gd").material_description(part)
 return str(item.get("description",""))

static func seed_id(index: int) -> String:
 return "seed_"+str(Seeds.DEFINITIONS[index].id)
static func part_id(part: int) -> String:
 for entry in all().values():
  if int(entry.get("legacy_part",-1))==part: return entry.id
 return ""
static func color(id: String) -> Color:
 var index:=RARITIES.find(get_item(id).get("rarity","Unknown"))
 return Color(COLORS[index]) if index>=0 else Color("#baa475")
static func loot_candidates(monster_tags: Array) -> Array:
 var result: Array=[]
 for entry in all().values():
  var required: Array=entry.get("monster_tags",[])
  if required.is_empty() or float(entry.get("loot_weight",0))<=0: continue
  var matches:=true
  for tag in required: matches=matches and monster_tags.has(tag)
  if matches: result.append(entry.id)
 return result
static func clean_counts(value) -> Dictionary:
 var result: Dictionary={}
 if value is Dictionary:
  for id in value:
   if id is String and value[id] is int and value[id]>0 and not get_item(id).is_empty(): result[id]=mini(value[id],1000000)
 return result

