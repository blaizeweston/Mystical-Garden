extends RefCounted
# Verified bank + later identification -> a world discovery, never a loot grant.
const DEFINITIONS: Array=[{
 "id":"lantern_homecoming","species":"lantern_moss","point":"heart_root_scar",
 "name":"A lantern brought home",
 "description":"A Lantern Moss seed carried home from the Wilds has been identified. Pale lights now gather beside the old root scar. The Heart answers them, a little out of rhythm.",
 "hint":"Inspect the old root scar south of the Heart. When the sheltered spring opens, watch how its water answers the roots.",
 "color":"#c3d5a1"
}]
static var signature: String=var_to_str(DEFINITIONS).sha256_text()
static func definition(id: String) -> Dictionary:
 for entry in DEFINITIONS:
  if entry.id==id:return entry
 return {}
static func errors() -> Array[String]:
 var result: Array[String]=[];var ids: Array=[]
 for entry in DEFINITIONS:
  if ids.has(entry.id) or str(entry.id).is_empty():result.append("Duplicate/empty return discovery")
  ids.append(entry.id)
  if preload("res://seed_catalog.gd").index_of(str(entry.species))<0:result.append("Unknown discovery species")
  if preload("res://garden_interaction_catalog.gd").point(str(entry.point)).is_empty():result.append("Unknown discovery anchor")
 return result
