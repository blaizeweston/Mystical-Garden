extends RefCounted

const Session = preload("res://network_session.gd")

const Participation = preload("res://expedition_participation.gd")
# Choices reserve materials for this weapon, without consuming stash until departure.
const FIELDS: Array=["prepared","prepared_secondary","prepared_catalyst"]
static func choices(player: Dictionary) -> Array:
 return FIELDS.map(func(field):return int(player.get(field,0)))
static func remaining(counts: Array,selected: Array,slot: int,part: int) -> int:
 if part==0:return 1
 if part<0 or part>=counts.size():return 0
 var count:=int(counts[part])
 for other in selected.size():
  if other!=slot and int(selected[other])==part:count-=1
 return maxi(0,count)
static func reconcile(player: Dictionary,counts: Array) -> bool:
 var selected: Array=[0,0,0];var changed:=false
 for slot in FIELDS.size():
  var part:=int(player.get(FIELDS[slot],0))
  if part>0 and remaining(counts,selected,slot,part)<=0:
   player[FIELDS[slot]]=0;changed=true
  else:selected[slot]=part
 return changed

static func demand(player: Dictionary,part: int) -> int:
 return choices(player).count(part)+int(player.get("cargo_plan",[])[part] if part<player.get("cargo_plan",[]).size() else 0)
static func claimed(game: Node,player: Dictionary) -> bool:
 return not Participation.is_wild(player) and player.get("loadout_reserving",false) and not Session.rejecting_for(player)
static func shared_free(game: Node,part: int,except_player: Dictionary={}) -> int:
 var free: int=game.progress.part_count(part)
 for other in game.players.values():
  if is_same(other,except_player) or not claimed(game,other):continue
  free-=maxi(0,demand(other,part)-int(game.seed_reserve(other).parts[part]))
 return maxi(0,free)
static func available(game: Node,player: Dictionary) -> Array:
 var result: Array=game.Parts.empty_counts();var personal: Array=game.seed_reserve(player).parts
 for part in range(1,result.size()):result[part]=int(personal[part])+shared_free(game,part,player)
 return result

## Pure departure planning. Part counts are whole items; reserved counts use
## plant species IDs. Nothing is consumed and returned arrays do not alias inputs.
static func departure_plan(selected: Array, cargo: Array, available_parts: Array, personal: Array) -> Dictionary:
 var parts = preload("res://weapon_parts.gd")
 var needed: Array = parts.empty_counts()
 for part in selected:
  if part != 0 and not parts.is_plant(part): return {"error":"Only plant materials fit the first three slots."}
  needed[part] += 1
 for part in range(1,needed.size()):
  needed[part] += int(cargo[part])
  if int(available_parts[part]) < int(needed[part]):
   return {"error":"Not enough %s for the loadout and cargo." % parts.part_name(part)}
 var reserved: Array = preload("res://seed_catalog.gd").counts()
 for part in range(1,needed.size()):
  if parts.is_plant(part) and part != parts.HEARTWOOD:
   reserved[parts.plant_source(part)] += maxi(0,int(needed[part])-int(personal[part]))
 for part in selected:
  if part != parts.EMPTY and int(available_parts[part]) == 0:
   return {"error":"%s is unavailable. Change the slot at the Wilds gate." % parts.part_name(part)}
 return {"error":"", "needed":needed, "reserved":reserved}
