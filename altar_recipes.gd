extends RefCounted
const Items=preload("res://item_catalog.gd")
const Seeds=preload("res://seed_catalog.gd")
static var definitions: Array=[]
static func key(mode: String,first: String,second: String) -> String:
 var inputs: Array=[first,second];inputs.sort()
 return mode+"|"+"|".join(inputs)
static func all() -> Array:
 if not definitions.is_empty(): return definitions
 for species in Seeds.DEFINITIONS.size():
  var plant_definition: Dictionary=Seeds.DEFINITIONS[species]
  if plant_definition.parents.size()!=2: continue
  var first:=int(plant_definition.parents[0]);var second:=int(plant_definition.parents[1])
  for mode in ["seeds","parts"]:
   if mode=="seeds" and Seeds.wild_only(species): continue
   var inputs: Array=[Items.seed_id(first),Items.seed_id(second)] if mode=="seeds" else [Items.part_id(int(Seeds.DEFINITIONS[first].part)),Items.part_id(int(Seeds.DEFINITIONS[second].part))]
   var output: String=Items.seed_id(species) if mode=="seeds" else Items.part_id(int(plant_definition.part))
   definitions.append({"id":key(mode,inputs[0],inputs[1]),"mode":mode,"inputs":inputs,"output":output,"quantity":1})
 for species in Seeds.DEFINITIONS.size():
  var base:=Items.part_id(int(Seeds.DEFINITIONS[species].part));var refined:=Items.part_id(Items.Parts.rare_part(species));var recipe_id:=key("parts",base,base)
  if not refined.is_empty() and (Items.RARITIES.find(Items.get_item(refined).rarity)>Items.RARITIES.find(Items.get_item(base).rarity) or (int(Seeds.DEFINITIONS[species].tier)==5 and base!=refined)) and not definitions.any(func(entry):return entry.id==recipe_id): definitions.append({"id":recipe_id,"mode":"parts","inputs":[base,base],"output":refined,"quantity":1})
 var extra=JSON.parse_string(FileAccess.get_file_as_string("res://assets/altar/additional_recipes.json"))
 if extra is Array:
  for entry in extra:
   if not entry is Dictionary or entry.get("mode","") not in ["seeds","parts"] or not entry.get("inputs") is Array or entry.inputs.size()!=2: continue
   if Items.get_item(str(entry.get("output",""))).is_empty(): continue
   var valid:=true
   for id in entry.inputs: valid=valid and not Items.get_item(str(id)).is_empty()
   if not valid: continue
   var category: String="seed" if entry.mode=="seeds" else "plant_part"
   var output:=Items.get_item(entry.output)
   if entry.mode=="seeds" and (not output.has("legacy_seed") or Seeds.wild_only(output.legacy_seed)): continue
   if output.category!=category or entry.output=="unidentified_seed": continue
   for id in entry.inputs:
    var ingredient:=Items.get_item(str(id))
    valid=valid and ingredient.category==category and id!="unidentified_seed"
    if entry.mode=="parts": valid=valid and Items.RARITIES.find(output.rarity)>Items.RARITIES.find(ingredient.rarity)
   var recipe_id:=key(entry.mode,str(entry.inputs[0]),str(entry.inputs[1]))
   for existing in definitions: valid=valid and existing.id!=recipe_id
   if valid: definitions.append({"id":recipe_id,"mode":entry.mode,"inputs":entry.inputs,"output":entry.output,"quantity":1})
 return definitions
static func find(mode: String,first: String,second: String) -> Dictionary:
 var wanted:=key(mode,first,second)
 for recipe in all():
  if recipe.id==wanted: return recipe
 return {}
