extends RefCounted

const Session = preload("res://network_session.gd")

const Participation = preload("res://expedition_participation.gd")
const Items=preload("res://item_catalog.gd")
const POUCH_SLOTS:=1
const SHARED_OWNER:="__shared_garden_inventory__"
static func reserve(game: Node,player: Dictionary,bucket: String) -> Dictionary:
 return game.progress.reserve(SHARED_OWNER) if bucket=="shared" else game.seed_reserve(player)
static func extras(game: Node,player: Dictionary,bucket: String) -> Dictionary:
 if bucket!="shared":return extra_stash(game,player)
 if not game.progress.item_stashes.has(SHARED_OWNER):game.progress.item_stashes[SHARED_OWNER]={}
 return game.progress.item_stashes[SHARED_OWNER]
static func extra_stash(game,player: Dictionary) -> Dictionary:
 var owner: String=Session.inventory_owner(player)
 if not game.progress.item_stashes.has(owner): game.progress.item_stashes[owner]={}
 return game.progress.item_stashes[owner]
static func normalize_pouch(player: Dictionary) -> void:
 if not player.has("safe_items"): player.safe_items=[]
 if player.get("pouch",false) and player.safe_items.is_empty() and not player.carried_seeds.is_empty():
  var species_id: int=player.carried_seeds.pop_front()
  player.safe_items.append({"item":"unidentified_seed","quantity":1,"seeds":[species_id]})
 player.pouch=not player.safe_items.is_empty()
static func counts(game,player: Dictionary,bucket: String) -> Dictionary:
 var result: Dictionary={}
 if bucket=="pouch":
  if not player.get("safe_items",[]).is_empty():
   for stack in player.safe_items: result[stack.item]=int(result.get(stack.item,0))+int(stack.quantity)
  elif player.get("pouch",false) and not player.carried_seeds.is_empty(): result.unidentified_seed=1
  return result
 var wild: bool=Participation.is_wild(player)
 if (wild and bucket not in ["carry"]) or (not wild and bucket not in ["stash","shared"]): return result
 if bucket=="carry":
  result.unidentified_seed=player.carried_seeds.size()-int(player.get("pouch",false) and player.get("safe_items",[]).is_empty() and not player.carried_seeds.is_empty())
  for part in range(1,game.Parts.DEFINITIONS.size()):
   if int(player.carried_parts[part])>0: result[Items.part_id(part)]=int(player.carried_parts[part])
  result.merge(player.get("carried_items",{}),true)
 elif bucket=="stash":
  var inventory_reserve: Dictionary=game.seed_reserve(player)
  result.unidentified_seed=inventory_reserve.unknown.size()
  for species_id in inventory_reserve.stock.size():
   if int(inventory_reserve.stock[species_id])>0: result[Items.seed_id(species_id)]=int(inventory_reserve.stock[species_id])
  for part in range(1,game.Parts.DEFINITIONS.size()):
   if int(inventory_reserve.parts[part])>0: result[Items.part_id(part)]=int(inventory_reserve.parts[part])
  result.merge(extra_stash(game,player),true)
 else:
  var seeds: Dictionary=reserve(game,player,bucket)
  result.unidentified_seed=seeds.unknown.size()
  for species_id in seeds.stock.size():
   if int(seeds.stock[species_id])>0:result[Items.seed_id(species_id)]=int(seeds.stock[species_id])
  result.merge(extras(game,player,bucket),true)
  for part in range(1,game.Parts.DEFINITIONS.size()):
   if game.progress.part_count(part)>0: result[Items.part_id(part)]=game.progress.part_count(part)
 return result
static func stacks(values: Dictionary,bucket: String) -> Array:
 var result: Array=[]
 for id in values:
  var definition:=Items.get_item(id)
  if definition.is_empty(): continue
  var remaining:=int(values[id]);var ordinal:=0
  while remaining>0:
   var amount:=mini(remaining,int(definition.stack_limit))
   result.append({"item":id,"quantity":amount,"bucket":bucket,"key":"%s|%s|%d"%[bucket,id,ordinal]})
   remaining-=amount;ordinal+=1
 return result
static func snapshot(game,player: Dictionary) -> Dictionary:
 var wild: bool=Participation.is_wild(player)
 var result: Dictionary={"wild":wild,"carry":[],"stash":[],"shared":[],"pouch":[],"equipment":[player.get("weapon",0),player.get("secondary",0),player.get("catalyst",0)] if wild else [player.get("prepared",0),player.get("prepared_secondary",0),player.get("prepared_catalyst",0)]}
 for bucket in (["carry","pouch"] if wild else ["stash","shared"]): result[bucket]=stacks(counts(game,player,bucket),bucket)
 return result
static func take(game,player: Dictionary,bucket: String,id: String,amount: int,protect: bool=true) -> Dictionary:
 normalize_pouch(player)
 var definition:=Items.get_item(id)
 if definition.is_empty() or amount<=0 or amount>int(definition.stack_limit) or int(counts(game,player,bucket).get(id,0))<amount: return {}
 if protect and definition.has("legacy_part") and not Participation.is_wild(player):
  var part:=int(definition.legacy_part)
  if bucket=="shared" and amount>game.LoadoutMaterials.shared_free(game,part):return {}
  if bucket=="stash" and game.LoadoutMaterials.claimed(game,player) and int(counts(game,player,bucket).get(id,0))-amount<mini(int(game.seed_reserve(player).parts[part]),game.LoadoutMaterials.demand(player,part)):return {}
 var stack: Dictionary={"item":id,"quantity":amount}
 if bucket=="pouch":
  var held: Dictionary=player.safe_items[0]
  if id=="unidentified_seed": stack.seeds=held.seeds.slice(0,amount);held.seeds=held.seeds.slice(amount)
  held.quantity-=amount
  if held.quantity==0: player.safe_items.clear()
  player.pouch=not player.safe_items.is_empty()
 elif id=="unidentified_seed":
  var seeds: Array=player.carried_seeds if bucket=="carry" else reserve(game,player,bucket).unknown
  stack.seeds=seeds.slice(0,amount)
  for i in amount: seeds.pop_front()
 elif definition.has("legacy_part"):
  var part:=int(definition.legacy_part)
  if bucket=="carry": player.carried_parts[part]-=amount
  elif bucket=="stash": game.seed_reserve(player).parts[part]-=amount
  else: game.progress.add_parts(part,-amount)
 elif definition.has("legacy_seed") and bucket in ["stash","shared"]: reserve(game,player,bucket).stock[int(definition.legacy_seed)]-=amount
 else:
  var values: Dictionary=player.get("carried_items",{}) if bucket=="carry" else extras(game,player,bucket)
  values[id]=int(values.get(id,0))-amount
  if int(values[id])<=0: values.erase(id)
 return stack
static func put(game,player: Dictionary,bucket: String,stack: Dictionary) -> void:
 var id:=str(stack.item);var amount:=int(stack.quantity);var definition:=Items.get_item(id)
 if bucket=="pouch":
  if player.safe_items.is_empty(): player.safe_items.append(stack.duplicate(true))
  else:
   player.safe_items[0].quantity+=amount
   if id=="unidentified_seed": player.safe_items[0].seeds.append_array(stack.seeds)
  player.pouch=true
 elif id=="unidentified_seed":
  var seeds: Array=player.carried_seeds if bucket=="carry" else reserve(game,player,bucket).unknown
  seeds.append_array(stack.seeds)
 elif definition.has("legacy_part"):
  var part:=int(definition.legacy_part)
  if bucket=="carry": player.carried_parts[part]+=amount
  elif bucket=="stash": game.seed_reserve(player).parts[part]+=amount
  else: game.progress.add_parts(part,amount)
 elif definition.has("legacy_seed") and bucket in ["stash","shared"]: reserve(game,player,bucket).stock[int(definition.legacy_seed)]+=amount
 else:
  if not player.has("carried_items"): player.carried_items={}
  var values: Dictionary=player.carried_items if bucket=="carry" else extras(game,player,bucket)
  values[id]=int(values.get(id,0))+amount
static func transfer(game,player: Dictionary,source: String,target: String,id: String,amount: int) -> String:
 normalize_pouch(player)
 if source==target: return ""
 if Participation.is_wild(player):
  if source not in ["carry","pouch"] or target not in ["carry","pouch"]: return "Garden storage is unavailable in the Wilds."
 else:
  if source not in ["stash","shared"] or target not in ["stash","shared"]: return "The safe pouch is used during expeditions."
 var definition:=Items.get_item(id)
 if definition.is_empty(): return "Unknown item."
 if target=="shared" and not definition.has("legacy_part") and definition.get("category","")!="seed": return "Shared Garden storage accepts seeds and crafting parts."
 if target=="pouch":
  if not bool(definition.get("pouch_allowed",true)): return "This item cannot fit in the safe pouch."
  var held: Array=player.safe_items
  if not held.is_empty() and (held[0].item!=id or int(held[0].quantity)+amount>int(definition.stack_limit)): return "The pouch holds one stack. Remove it or free space first."
 var stack:=take(game,player,source,id,amount)
 if stack.is_empty(): return "That stack changed or is reserved for a weapon. Clear the relevant gate slots and retry."
 put(game,player,target,stack)
 if not Participation.is_wild(player) and not preload("res://save_batch.gd").guarded_active() and game.progress.save_garden()!=OK:
  var restored:=take(game,player,target,id,amount,false);put(game,player,source,restored)
  return "Could not save the transfer. Items were returned."
 return "Moved %d %s."%[amount,definition.name]
static func bank_safe(game,player: Dictionary) -> int:
 normalize_pouch(player)
 game.garden_commands.protected_return(preload("res://garden_return_service.gd").Member.new(str(player.get("garden_run_actor","")),str(player.get("garden_run_id","")),preload("res://expedition_participation.gd").is_wild(player)),player.get("safe_items",[]).duplicate(true))
 var total:=0
 for stack in player.safe_items:
  put(game,player,"stash",stack)
  total+=int(stack.quantity)
 player.safe_items.clear();player.pouch=false
 return total
static func bank_extra(game,player: Dictionary) -> void:
 game.garden_commands.extra_return(preload("res://garden_return_service.gd").Member.new(str(player.get("garden_run_actor","")),str(player.get("garden_run_id","")),preload("res://expedition_participation.gd").is_wild(player)),int(player.get("carried_items",{}).get("boss_mystery_seed",0))>0)
 for id in player.get("carried_items",{}): put(game,player,"stash",{"item":id,"quantity":int(player.carried_items[id])})
 player.carried_items={}
static func clean_ground(value) -> Array:
 var result: Array=[]
 if not value is Array: return result
 for entry in value:
  if not entry is Dictionary or not entry.get("id") is String or not entry.get("stack") is Dictionary: continue
  var stack: Dictionary=entry.stack
  var definition:=Items.get_item(str(stack.get("item","")))
  if definition.is_empty() or not stack.get("quantity") is int or int(stack.quantity)<=0 or int(stack.quantity)>int(definition.stack_limit): continue
  var position=entry.get("position")
  if not position is Array or position.size()!=3: continue
  var valid:=true
  for number in position: valid=valid and (number is int or number is float) and is_finite(float(number)) and absf(float(number))<=1000
  if not valid: continue
  if stack.item=="unidentified_seed":
   if not stack.get("seeds") is Array or stack.seeds.size()!=int(stack.quantity): continue
   for species_id in stack.seeds: valid=valid and species_id is int and species_id>=0 and species_id<Items.Seeds.DEFINITIONS.size()
  if valid: result.append(entry.duplicate(true))
 return result
