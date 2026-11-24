extends RefCounted
const Heart=preload("res://heart_catalog.gd")
const Places=preload("res://garden_interaction_catalog.gd")
# Garden levels count whole thirty-Knowledge bands.
@warning_ignore_start("integer_division")
static func level(knowledge: int,technologies: int) -> int:return mini(10,knowledge/30+technologies)
@warning_ignore_restore("integer_division")
static func enabled(zone: Dictionary,unlocked: Array) -> bool:
 for id in Places.requirements(zone):
  if not unlocked.has(id):return false
 return true
static func describe(id: String,before: Dictionary,after: Dictionary) -> Dictionary:
 var node:=Heart.get_node(id);var result: Dictionary={"technology":id,"name":node.get("name","The Garden grows"),"kind":"heart","from_phase":before.phase,"to_phase":after.phase,"from_level":before.level,"to_level":after.level}
 result.from_growth=preload("res://heart_growth_visuals.gd").count(before.tech);result.to_growth=preload("res://heart_growth_visuals.gd").count(after.tech)
 if node.has("clearing"):result.kind="clearing"
 elif id in ["seed_archive","monster_studies","living_archive"]:result.kind="station";result.station=id
 for zone in Places.ZONES:
  if zone.get("water_access",false) and not enabled(zone,before.tech) and enabled(zone,after.tech):result.kind="spring";result.zone=zone.id;result.name="The Garden shares its water"
 for zone in Places.ZONES:
  if zone.has("reveal") and not enabled(zone,before.tech) and enabled(zone,after.tech):result.kind="zone";result.zone=zone.id;result.name=zone.get("name","The Garden opens")
 return result
