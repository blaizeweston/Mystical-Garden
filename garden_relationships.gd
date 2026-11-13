extends RefCounted
const Layout=preload("res://garden_layout.gd")
const Seeds=preload("res://seed_catalog.gd")
const Items=preload("res://item_catalog.gd")
const Recipes=preload("res://altar_recipes.gd")
static func matches(game: Node,definition: Dictionary) -> bool:
 if not definition.has("relationship"):return true
 var condition: Dictionary=definition.relationship;var found: Array=[]
 for index in Layout.zone_beds(str(condition.zone),game.progress.plots.size()):
  var bed: Dictionary=game.progress.plots[index]
  if int(bed.species)>=0 and int(bed.stage)>=int(condition.stage):found.append(str(Seeds.DEFINITIONS[int(bed.species)].id))
 for species in condition.species:
  var index:=found.find(species)
  if index<0:return false
  found.remove_at(index)
 return true
static func clue(game: Node,definition: Dictionary) -> String:
 if not definition.has("clue_species"):return ""
 var species:=Seeds.index_of(str(definition.clue_species))
 if species<0:return ""
 var ingredient:=Items.part_id(int(Seeds.DEFINITIONS[species].part))
 var recipe:=Recipes.find("parts",ingredient,ingredient)
 if recipe.is_empty():return ""
 var name: String=Items.get_item(ingredient).name
 var known: bool=game.progress.altar_recipes.has(recipe.id)
 return ("You already know this refinement. " if known else "The pattern suggests a refinement: ")+"combine two %s crafting parts in the Plant Parts tab at the Garden Altar. Take the resulting component to the Wilds gate and try it in a weapon."%name
