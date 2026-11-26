extends RefCounted
const Items=preload("res://item_catalog.gd")
const Model=preload("res://inventory_model.gd")
const Recipes=preload("res://altar_recipes.gd")
static func clean_draft(value) -> Array:
 var result: Array=[{},{}]
 if not value is Array or value.size()!=2: return result
 for index in 2:
  var entry=value[index]
  if not entry is Dictionary or not entry.get("item") is String or entry.get("source","") not in ["stash","shared"]: continue
  var item:=Items.get_item(entry.item)
  if item.is_empty() or item.category not in ["seed","plant_part"] or entry.item in ["unidentified_seed","boss_mystery_seed"]: continue
  result[index]={"item":str(entry.item),"source":str(entry.source)}
 return result
static func mode_for(draft: Array) -> String:
 return "seeds" if Items.get_item(str(draft[0].get("item",""))).get("category","")=="seed" else "parts"
static func validate(game,player: Dictionary,draft: Array) -> String:
 if not game.at_garden_altar(player): return "Visit the Garden altar to make an offering."
 if draft[0].is_empty() or draft[1].is_empty(): return "Place one item in each sacrifice slot."
 var first:=Items.get_item(draft[0].item);var second:=Items.get_item(draft[1].item)
 if first.category!=second.category: return "Use two seeds or two plant parts."
 if first.category not in ["seed","plant_part"]: return "Only seeds and plant parts can be sacrificed here."
 var costs: Array=[]
 for entry in draft:costs.append({"item":entry.item,"source":entry.source,"quantity":1})
 if not preload("res://garden_inventory_gateway.gd").plan(game,player,costs).ok:return "Not enough available items for both slots."
 return ""
static func salvage(draft: Array) -> String:
 var first: Dictionary=draft[0] if str(draft[0].item)<str(draft[1].item) else draft[1]
 var item:=Items.get_item(str(first.item))
 if item.category=="seed" and item.has("legacy_seed"): return Items.part_id(int(Items.Seeds.DEFINITIONS[int(item.legacy_seed)].part))
 return first.item
# Salvage uses the lexically first parent; the other seed returns to the acting reserve.
static func conserved_parent(draft: Array) -> String:
 return str(draft[0].item) if str(draft[0].item) > str(draft[1].item) else str(draft[1].item)

static func recipe_key(draft: Array) -> String:
 return Recipes.key(mode_for(draft),draft[0].item,draft[1].item)
static func output_bucket(draft: Array) -> String:
 return "shared" if draft.any(func(ingredient):return ingredient.get("source","")=="shared") else "stash"
static func output_note(draft: Array) -> String:
 var shared:=output_bucket(draft)=="shared"
 if shared and draft.any(func(ingredient):return ingredient.get("source","")=="stash"):
  return "Mixed sources: personal ingredients are sacrificed and all results enter shared Garden storage."
 return "Results enter shared Garden storage." if shared else "Results enter your personal stash."
static func recorded_seed_species(progress) -> Array:
 var species: Array = []
 for recipe in Recipes.all():
  if recipe.mode=="seeds" and progress.altar_recipes.get(recipe.id,{}).get("item","")==recipe.output and progress.altar_recipes[recipe.id].get("success",false):
   species.append(Items.get_item(recipe.output).legacy_seed)
 return species

static func preview(game,player: Dictionary,draft: Array) -> Dictionary:
 var reason:=validate(game,player,draft)
 var affordable:=reason.is_empty()
 if not affordable and reason!="Not enough available items for both slots.": return {"known":false,"item":"","can_combine":false,"text":reason}
 var recipe:=Recipes.find(mode_for(draft),draft[0].item,draft[1].item)
 var entry: Dictionary=game.progress.altar_recipes.get(recipe_key(draft),{})
 var recorded: bool=(not entry.is_empty() and not entry.get("success",false)) if recipe.is_empty() else (entry.get("success",false) and entry.get("item","")==recipe.output)
 if not recorded and not recipe.is_empty() and recipe.mode=="parts":
  # Material previews historically recognize an output already in storage.
  recorded=int(Model.counts(game,player,"stash").get(recipe.output,0))+int(Model.counts(game,player,"shared").get(recipe.output,0))>0
 if not recorded: return {"known":false,"item":"","can_combine":affordable,"text":("Unknown result. Sacrifice to discover it." if affordable else reason)+"\n"+output_note(draft)}
 var output: String=recipe.output if not recipe.is_empty() else salvage(draft)
 var text: String="Known result: "+str(Items.get_item(output).name)+" · "+str(Items.get_item(output).rarity)+(". Returns salvaged materials." if recipe.is_empty() else ". Produces one item.")
 if recipe.is_empty() and mode_for(draft)=="seeds" and game.progress.heart.has("seed_conservation"):
  text+=" Returns one "+str(Items.get_item(conserved_parent(draft)).name)+"."
 if not affordable: text+="\n"+reason
 text+="\n"+output_note(draft)
 return {"known":true,"item":output,"can_combine":affordable,"text":text}
static func capture(game,player: Dictionary) -> Dictionary:
 var reserve: Dictionary=game.seed_reserve(player);var g=game.progress
 return {"archive":g.archive.duplicate(true),"garden_interactions":g.garden_interactions.duplicate(true),"rng_state":game.rng.state,"stock":reserve.stock.duplicate(),"unknown":reserve.unknown.duplicate(),"personal":reserve.parts.duplicate(),"shared":g.parts.duplicate(),"shared_reserve":Model.reserve(game,player,"shared").duplicate(true),"barbs":g.heartwood_barbs,"extras":g.item_stashes.duplicate(true),"discoveries":g.discoveries.duplicate(),"knowledge":g.knowledge,"veilcap":g.veilcap_discovered,"attempts":g.attempted_pairs.duplicate(true),"recipes":g.altar_recipes.duplicate(true)}
static func restore(game,player: Dictionary,before: Dictionary) -> void:
 var reserve: Dictionary=game.seed_reserve(player);var g=game.progress
 if before.has("archive"):g.archive=before.archive.duplicate(true)
 if before.has("garden_interactions"):g.garden_interactions=before.garden_interactions.duplicate(true)
 if before.has("rng_state"): game.rng.state=before.rng_state
 reserve.stock.assign(before.stock);reserve.unknown.assign(before.unknown);reserve.parts.assign(before.personal)
 var communal:=Model.reserve(game,player,"shared")
 communal.stock.assign(before.shared_reserve.stock);communal.unknown.assign(before.shared_reserve.unknown)
 g.parts.assign(before.shared);g.heartwood_barbs=before.barbs;g.item_stashes=before.extras.duplicate(true)
 g.discoveries.assign(before.discoveries);g.knowledge=before.knowledge;g.veilcap_discovered=before.veilcap
 g.attempted_pairs=before.attempts.duplicate(true);g.altar_recipes=before.recipes.duplicate(true)
static func combine(game,player: Dictionary,draft: Array,effects = null) -> String:
 var reason:=validate(game,player,draft)
 if not reason.is_empty(): return reason
 var before:=capture(game,player)
 for ingredient in draft:
  var taken:=Model.take(game,player,ingredient.source,ingredient.item,1)
  if taken.is_empty(): restore(game,player,before);return "The offering changed. Nothing was consumed."
 var mode:=mode_for(draft)
 var key:=recipe_key(draft)
 var recipe:=Recipes.find(mode,draft[0].item,draft[1].item)
 var fresh: bool=not game.progress.altar_recipes.has(key)
 var output: String=recipe.output if not recipe.is_empty() else salvage(draft)
 var destination:=output_bucket(draft)
 Model.put(game,player,destination,{"item":output,"quantity":1})
 var message: String
 if not recipe.is_empty():
  var item:=Items.get_item(output)
  if item.has("legacy_seed"):
   var peer: int = game.Session.peer_for(player)
   game.Progress.Archive.activity(game.progress.archive,game._kill_reward_identity(peer,player),{"crosses":1})
   game.progress.discover(int(item.legacy_seed))
   if fresh: game.progress.knowledge+=2
  elif fresh: game.progress.knowledge+=4
  message=("Discovered " if fresh else "Created ")+str(item.name)+". One added to "+("shared Garden storage." if destination=="shared" else "your personal stash.")
 else:
  var item:=Items.get_item(draft[0].item)
  var source: int=int(item.get("legacy_seed",Items.Seeds.species_for_part(int(item.get("legacy_part",0)))))
  message="The offering did not bind. Recovered one %s. Clue: %s"%[Items.get_item(output).name,game.progress.next_seed_hint(source)]
  if mode=="seeds" and game.progress.heart.has("seed_conservation"):
   var parent:=Items.get_item(conserved_parent(draft))
   Model.put(game,player,destination,{"item":parent.id,"quantity":1})
   message+=" Conserved one "+str(parent.name)+"."
  message+=" "+output_note(draft)
 var prior: Dictionary=game.progress.altar_recipes.get(key,{})
 game.progress.altar_recipes[key]={"item":output,"success":not recipe.is_empty()}
 if mode=="seeds" and recipe.is_empty() and (prior.get("success",false) or prior.get("historical_success",false)):
  game.progress.altar_recipes[key].historical_success=true
 if mode=="seeds":
  var a:=int(Items.get_item(draft[0].item).get("legacy_seed",-1));var b:=int(Items.get_item(draft[1].item).get("legacy_seed",-1))
  if a>=0 and b>=0:
   var pair: Array=[mini(a,b),maxi(a,b)]
   if not game.progress.attempted_pairs.has(pair): game.progress.attempted_pairs.append(pair)
 if not preload("res://save_batch.gd").guarded_active() and game.progress.save_garden()!=OK:
  restore(game,player,before)
  return "Could not save the offering. All ingredients and Knowledge were returned."
 if mode=="seeds" and not recipe.is_empty():
  var peer: int=game.Session.peer_for(player)
  game.record_character(peer,player)
  if effects != null and peer != game.HOST: effects.append(game.send_committed_profile.bind(peer))
 var report := func(): preload("res://diagnostic_journal.gd").event("altar","offering_saved",{"inputs":draft,"output":output,"success":not recipe.is_empty(),"fresh":fresh})
 if effects != null: effects.append(report)
 elif not preload("res://save_batch.gd").guarded_active(): report.call()
 return message
static func ancient_count(game,player: Dictionary,source: String="stash") -> int:
 return Model.Ancient.quantity(Model.extras(game,player,source).get(Model.Ancient.ITEM,{}))
static func identify_ancient(game,player: Dictionary,source: String="stash") -> int:
 var stack:=Model.take(game,player,source,"boss_mystery_seed",1)
 if stack.is_empty(): return -1
 var lineage: String=stack.lineages.keys()[0]
 var species:=preload("res://boss_encounters.gd").historical_seed_species(game.rng) if lineage==Model.Ancient.LEGACY else Items.Seeds.index_of(lineage)
 Model.reserve(game,player,source).stock[species]+=1;game.progress.discover(species)
 preload("res://garden_return_service.gd").identified(game.progress,species,true)
 return species
static func identify(game,player: Dictionary,source: String="stash") -> String:
 if source not in ["stash","shared"]:return "Invalid storage."
 if not game.at_garden_altar(player): return "Visit the Garden altar to identify seeds."
 var reserve: Dictionary=Model.reserve(game,player,source)
 if reserve.unknown.is_empty() and ancient_count(game,player,source)==0: return "Bring a mysterious seed to identify."
 var before:=capture(game,player)
 var species: int
 if ancient_count(game,player,source)>0: species=identify_ancient(game,player,source)
 else:
  species=reserve.unknown.pop_front();reserve.stock[species]+=1;game.progress.discover(species)
  preload("res://garden_return_service.gd").identified(game.progress,species)
 if not preload("res://save_batch.gd").guarded_active() and game.progress.save_garden()!=OK:
  restore(game,player,before);return "Could not save identification. The seed was returned."
 return "Identified %s."%Items.Seeds.NAMES[species]
static func identify_all(game,player: Dictionary,source: String="stash") -> String:
 if source not in ["stash","shared"]:return "Invalid storage."
 if not game.at_garden_altar(player): return "Visit the Garden altar to identify seeds."
 var reserve: Dictionary=Model.reserve(game,player,source)
 if reserve.unknown.is_empty() and ancient_count(game,player,source)==0: return "No mysterious seeds remain."
 var before:=capture(game,player);var total: int=reserve.unknown.size()+ancient_count(game,player,source);var discovered:=0
 var prior: int=game.progress.discoveries.count(true)
 while ancient_count(game,player,source)>0: identify_ancient(game,player,source)
 for species in reserve.unknown:
  reserve.stock[species]+=1
  if not game.progress.discoveries[species]: discovered+=1
  game.progress.discover(species)
  preload("res://garden_return_service.gd").identified(game.progress,int(species))
 reserve.unknown.clear()
 discovered=game.progress.discoveries.count(true)-prior
 if not preload("res://save_batch.gd").guarded_active() and game.progress.save_garden()!=OK:
  restore(game,player,before);return "Could not save identification. All mysterious seeds were returned."
 return "Identified all %d seeds · %d newly discovered species."%[total,discovered]
static func snapshot(game,player: Dictionary,draft: Array,revision: int) -> Dictionary:
 var bag:=Model.snapshot(game,player)
 var recorded: Array=[]
 for recipe in Recipes.all():
  if not game.progress.altar_recipes.get(recipe.id,{}).get("success",false): continue
  recorded.append({"mode":recipe.mode,"inputs":recipe.inputs,"output":recipe.output,"name":Items.get_item(recipe.output).name})
 return {"species_total":Items.Seeds.DEFINITIONS.size(),"species_known":game.progress.discoveries.count(true),"recipes":recorded,"draft":draft,"revision":revision,"stash":bag.stash,"shared":bag.shared,"unknown":game.seed_reserve(player).unknown.size()+ancient_count(game,player),"shared_unknown":Model.reserve(game,player,"shared").unknown.size()+ancient_count(game,player,"shared"),"preview":preview(game,player,draft),"message":player.get("altar_message","Drag one seed or plant part into each slot. Nothing is consumed until you confirm.")}
