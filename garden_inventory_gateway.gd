extends RefCounted
# Availability/preview contract. Payments still use InventoryModel.take in the
# consumer's existing transaction; this never maintains its own quantities/claims.
const Model=preload("res://inventory_model.gd")
static func available(game: Node,player: Dictionary,source: String,item: String) -> int:
 if player.get("wild",false) or source not in ["stash","shared"]:return 0
 var amount:=int(Model.counts(game,player,source).get(item,0));var definition:=Model.Items.get_item(item)
 if definition.has("legacy_part"):
  var part:=int(definition.legacy_part)
  if source=="shared":amount=mini(amount,game.LoadoutMaterials.shared_free(game,part))
  elif game.LoadoutMaterials.claimed(game,player):amount-=mini(amount,game.LoadoutMaterials.demand(player,part))
 return maxi(0,amount)
static func plan(game: Node,player: Dictionary,costs: Array) -> Dictionary:
 var needed: Dictionary={};var lines: Array=[]
 for cost in costs:
  if not cost is Dictionary or not cost.get("item") is String or cost.get("source","") not in ["stash","shared"] or not cost.get("quantity") is int or int(cost.quantity)<=0 or Model.Items.get_item(cost.item).is_empty():return {"ok":false,"lines":[],"reason":"Invalid Garden offering."}
  var key: String=cost.source+"|"+cost.item
  if not needed.has(key):needed[key]={"item":cost.item,"source":cost.source,"quantity":0}
  needed[key].quantity+=int(cost.quantity)
 var ok:=true
 for key in needed:
  var line: Dictionary=needed[key].duplicate();line.available=available(game,player,line.source,line.item);ok=ok and line.quantity<=line.available;lines.append(line)
 return {"ok":ok,"lines":lines,"reason":"" if ok else "Not enough unreserved items. Clear the relevant gate slots or choose another offering."}
