extends RefCounted
## Concealed contents of the existing Ancient Mystery Seed item. Stable species IDs
## survive save/load and transfers. Only the pre-WF02 reader creates legacy units.
const Seeds = preload("res://seed_catalog.gd")
const ITEM := "boss_mystery_seed"
const LEGACY := "@pre_wf02"
const MAX_SAVED_QUANTITY := 1000000 # Same sanity bound as the original inventory reader.
const TIER_WEIGHTS := [0.0, 0.0, 25.0, 55.0, 20.0]

static func award(depth: int, random: RandomNumberGenerator) -> Dictionary:
 var pools := [[],[],[],[],[]]
 var highest := -1
 for species in Seeds.DEFINITIONS.size():
  var plant: Dictionary = Seeds.DEFINITIONS[species]
  if Seeds.wild_only(species) or depth < int(plant.wild_min): continue
  var tier := int(plant.tier)-1
  pools[tier].append(plant.id)
  highest = maxi(highest,tier)
 if highest < 0: return {}
 var weights := PackedFloat32Array(TIER_WEIGHTS)
 for tier in pools.size():
  if pools[tier].is_empty(): weights[tier]=0.0
 var chosen := highest if highest<2 else random.rand_weighted(weights)
 var pool: Array = pools[chosen]
 var species_id: String = pool[random.randi_range(0,pool.size()-1)]
 return {"item":ITEM,"quantity":1,"lineages":{species_id:1}}

static func clean(value: Variant, historical: bool=false) -> Dictionary:
 if historical and value is int and value>0: return {LEGACY:mini(value,MAX_SAVED_QUANTITY)}
 if not value is Dictionary: return {}
 var result := {}
 var remaining := MAX_SAVED_QUANTITY
 for key in value:
  if not key is String or not value[key] is int or value[key]<=0 or value[key]>remaining: return {}
  remaining-=value[key]
  if key!=LEGACY:
   var species := Seeds.index_of(key)
   if species<0 or Seeds.wild_only(species): return {}
  result[key]=value[key]
 return result

static func quantity(contents: Dictionary) -> int:
 var result := 0
 for amount: int in contents.values(): result+=amount
 return result

static func add(stock: Dictionary, contents: Dictionary) -> void:
 for key in contents: stock[key]=int(stock.get(key,0))+int(contents[key])

static func remove(stock: Dictionary, contents: Dictionary) -> void:
 for key in contents:
  stock[key]-=contents[key]
  if stock[key]==0: stock.erase(key)

static func take(stock: Dictionary, amount: int) -> Dictionary:
 var contents := {}
 var order := stock.keys()
 order.sort() # Stable even after moving a split stack or rolling back a deposit.
 for key in order:
  var count := mini(stock[key],amount)
  contents[key]=count
  amount-=count
  if amount==0: break
 remove(stock,contents)
 return contents
