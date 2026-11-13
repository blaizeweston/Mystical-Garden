extends RefCounted
# The location hierarchy is content; cross-system dependencies live in test_map.json.
const ZONES: Array=[
 {"id":"sanctuary","parent":"","requires":[]},
 {"id":"sheltered_spring","parent":"sanctuary","requires":["clearing_1","irrigation"],
  "footprint":Rect2(2.1,-3.0,6.5,7.2),"beds":["bed_1","bed_2"],
  "water":{"position":Vector3(6.6,0,-.15),"radius":1.05},
  "ambience":{"family":"moth","count":8,"range":11.0,"requires_point":"spring_water"}},
 {"id":"cultivation_terrace","parent":"sanctuary","requires":["clearing_2"],
  "name":"The cultivation terrace opens","footprint":Rect2(-8.6,-7.3,4.8,3.6),"beds":["bed_4"],"reveal":{"position":Vector3(-7,0,-5.5)}}
]
const POINTS: Array=[{
 "id":"heart_root_scar","parent":"sanctuary","observation":"old_root_scar",
 "name":"An old root scar","position":Vector3(-1.8,0,4.8),"range":1.55,
 "requires":[],"action":"observe","cue":"quiet_pulse",
 "description":"A smooth root has folded around an old seam. Pale sap glimmers beneath the bark. Its pulse follows the Heart, but a little too late.",
 "recorded":"You noticed the old scar. Whatever closed this wound left a trace in the living root.",
 "hint":"Record this trace in the Garden journal. Others tending this Garden will be able to read it."
},{
 "id":"spring_water","parent":"sheltered_spring","observation":"sheltered_water",
 "name":"The sheltered spring","position":Vector3(6.0,0,1.5),"range":1.45,
 "requires":[],"action":"observe","cue":"quiet_pulse","visual":"spring",
 "description":"Clear water gathers where the roots have loosened their hold. Small pale moths skim the banks. Beside the nearby beds, the water carries a faint warmth.",
 "recorded":"The spring has opened beneath the reaching roots. Its banks shelter the first two planting beds; any species may still grow there.",
 "hint":"Reaching Roots and Root Irrigation uncovered this water. Look at what grows together along its banks."
},{
 "id":"spring_weave","parent":"sheltered_spring","observation":"moss_whisper_resonance",
 "name":"A quiet resonance","position":Vector3(4.1,0,.45),"range":1.35,
 "requires":[],"action":"observe","cue":"quiet_pulse","visual":"relationship",
 "relationship":{"zone":"sheltered_spring","species":["lantern_moss","whispervine"],"stage":3},
 "clue_species":"lantern_moss",
 "description":"The mature moss and whispering vine answer one another across the damp soil. Fine roots hold a repeating pattern, like two small lights finding the same rhythm.",
 "recorded":"You recorded the resonance between mature Lantern Moss and Whispervine at the spring.",
 "hint":"Study the pattern before harvesting either plant. It may suggest a new use for familiar materials."
},{
 "id":"terrace_memory","parent":"cultivation_terrace","observation":"terrace_lineage",
 "name":"The cultivation terrace","position":Vector3(-7,0,-5.5),"range":1.5,
 "requires":[],"action":"observe","cue":"quiet_pulse","visual":"root_scar","clue_species":"whispervine",
 "description":"Weathered stones cradle a living channel. Old root grooves repeat the pattern of a familiar vine. The nearby bed remains open to every seed species.",
 "recorded":"You traced the old cultivation channels. The terrace remembers a refinement in the vine roots.",
 "hint":"Record the root pattern to find a use for familiar vine parts. The Heart may learn to redirect the water here."
}]
static var signature: String=var_to_str([ZONES,POINTS]).sha256_text()
static func point(id: String) -> Dictionary:
 for entry in POINTS:
  if entry.id==id:return entry
 return {}
static func requirements(entry: Dictionary) -> Array:
 var result: Array=entry.get("requires",[]).duplicate();var parent: String=entry.get("parent","");var seen: Array=[]
 while not parent.is_empty() and not seen.has(parent):
  seen.append(parent)
  var found:=false
  for zone in ZONES:
   if zone.id==parent:
    result.append_array(zone.get("requires",[]));parent=zone.get("parent","");found=true;break
  if not found:break
 return result
static func errors(points: Array=POINTS,zones: Array=ZONES) -> Array[String]:
 var result: Array[String]=[];var ids: Dictionary={};var parents: Dictionary={};var observations: Dictionary={}
 for zone in zones:
  var id: String=zone.get("id","")
  if id.is_empty() or ids.has(id):result.append("Duplicate/empty Garden zone: "+id)
  ids[id]=true;parents[id]=str(zone.get("parent",""))
 for id in parents:
  var visited: Array=[id];var parent: String=parents[id]
  while not parent.is_empty():
   if not parents.has(parent):result.append("Unknown parent: "+parent);break
   if visited.has(parent):result.append("Cyclic Garden hierarchy: "+id);break
   visited.append(parent);parent=parents[parent]
 for entry in points:
  var id: String=entry.get("id","")
  if id.is_empty() or ids.has(id):result.append("Duplicate/empty Garden point: "+id)
  ids[id]=true
  if not parents.has(entry.get("parent","")):result.append("Unknown point parent: "+id)
  var observation: String=entry.get("observation","")
  if observation.is_empty() or observations.has(observation):result.append("Duplicate/empty observation: "+id)
  observations[observation]=true
  if not entry.get("position") is Vector3 or not entry.position.is_finite():result.append("Invalid anchor: "+id)
  if not (entry.get("range") is float or entry.get("range") is int) or float(entry.range)<=0 or float(entry.range)>3:result.append("Invalid interaction range: "+id)
  if entry.get("action")!="observe" or entry.get("cue")!="quiet_pulse":result.append("Unsupported Garden action/cue: "+id)
  if entry.get("visual","root_scar") not in ["root_scar","spring","relationship"]:result.append("Unsupported Garden visual: "+id)
  if entry.has("relationship"):
   var condition: Dictionary=entry.relationship
   if not parents.has(condition.get("zone","")) or not condition.get("species") is Array or condition.get("stage",-1)!=3:result.append("Invalid plant relationship: "+id)
   for species in condition.get("species",[]):
    if preload("res://seed_catalog.gd").index_of(str(species))<0:result.append("Unknown relationship species: "+str(species))
  if entry.has("clue_species"):
   var species:=preload("res://seed_catalog.gd").index_of(str(entry.clue_species))
   if species<0:result.append("Unknown refinement species: "+id)
   else:
    var item:=preload("res://item_catalog.gd").part_id(int(preload("res://seed_catalog.gd").DEFINITIONS[species].part))
    if preload("res://altar_recipes.gd").find("parts",item,item).is_empty():result.append("Missing existing refinement: "+id)
  for key in ["name","description","recorded","hint"]:
   if not entry.get(key) is String or entry[key].is_empty():result.append("Missing "+key+": "+id)
  for tech in entry.get("requires",[]):
   if preload("res://heart_catalog.gd").get_node(str(tech)).is_empty():result.append("Unknown technology: "+str(tech))
 for zone in zones:
  if zone.has("water"):
   if not zone.get("footprint") is Rect2 or not zone.get("beds") is Array or not zone.water.get("position") is Vector3 or float(zone.water.get("radius",0))<=0:result.append("Invalid Garden zone footprint: "+str(zone.id))
   for bed in zone.get("beds",[]):
    if not str(bed).begins_with("bed_") or int(str(bed).trim_prefix("bed_")) not in range(1,10):result.append("Unknown stable bed ID: "+str(bed))
  if zone.has("ambience"):
   if zone.ambience.get("family","")!="moth" or not zone.ambience.get("count") is int or int(zone.ambience.count)<1 or int(zone.ambience.count)>8 or not ids.has(zone.ambience.get("requires_point","")):result.append("Invalid ambient family/budget: "+str(zone.id))
  for tech in zone.get("requires",[]):
   if preload("res://heart_catalog.gd").get_node(str(tech)).is_empty():result.append("Unknown zone technology: "+str(tech))
 return result
