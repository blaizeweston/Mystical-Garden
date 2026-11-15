extends RefCounted
const Parts=preload("res://weapon_parts.gd")
const Classes=preload("res://class_catalog.gd")
const CoreRules=preload("res://core_skill_rules.gd")
const CORE_BEHAVIORS := {"thorn_fork": "thorn_line", "thorn_rebate": "thorn_line"}
const FOURTH_CHANCE:=0.08
const RARITY_WEIGHT: Dictionary={"Common":1.0,"Uncommon":0.55,"Rare":0.18,"Epic":0.06}
static var definitions: Array=[]
static func all() -> Array:
 if definitions.is_empty():
  definitions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/upgrades/checkpoint_upgrades.json"))
  for entry in definitions:
   for field in ["classes","grafts","plant_parts"]:
    if not entry.has(field): continue
    var converted: Array=[]
    for value in entry[field]: converted.append(int(value))
    entry[field]=converted
  definitions.append_array(CoreRules.Catalog.Expansion.cards())
  definitions.append_array(Classes.Warden.cards())
  definitions.append_array(Classes.Subclasses.cards())
 return definitions
static func get_upgrade(id: String) -> Dictionary:
 for entry in all():
  if entry.id==id: return entry
 return {}
static func context(player: Dictionary) -> Dictionary:
 var class_id:=clampi(int(player.get("frame",0)),0,Classes.DEFINITIONS.size()-1)
 var weapon_id:=clampi(int(player.get("weapon_kind",0)),0,Classes.DEFINITIONS[class_id].weapons.size()-1)
 var plant_tags: Array=[];var tags: Array=[];var plant_weights: Dictionary={};var plants: Array=[]
 var slots: Array=[player.get("weapon",0),player.get("secondary",0),player.get("catalyst",0)]
 for index in 3:
  var part:=int(slots[index])
  if not Parts.is_plant(part): continue
  plants.append(part)
  for tag in Parts.DEFINITIONS[part].get("tags",[]):
   if not plant_tags.has(tag): plant_tags.append(tag)
   if not tags.has(tag): tags.append(tag)
   plant_weights[tag]=float(plant_weights.get(tag,0))+[2.0,1.0,0.8][index]
 var graft:=int(player.get("graft_part",0));var graft_tags: Array=[];var monster: int=-1
 if Parts.is_monster(graft):
  monster=int(Parts.DEFINITIONS[graft].monster)
  graft_tags=Parts.DEFINITIONS[graft].tags.duplicate()
  for tag in graft_tags:
   if not tags.has(tag): tags.append(tag)
 var weapon: String=Classes.DEFINITIONS[class_id].weapons[weapon_id].id
 return {"class":class_id,"weapon":weapon,"plant_tags":plant_tags,"plant_weights":plant_weights,"plants":plants,"graft":monster,"graft_tags":graft_tags,"tags":tags,"core":CoreRules.resolve(weapon,slots,graft)}
static func requirement(entry: Dictionary,player: Dictionary,ctx: Dictionary={}) -> String:
 if preload("res://combat_ruleset.gd").uses_affinities(player):
  if not preload("res://combat_ruleset.gd").COMPATIBLE_CARDS.has(entry.get("id", "")):
   return preload("res://combat_ruleset.gd").EMPTY_CARDS
 if entry.is_empty(): return "Unknown upgrade."
 if ctx.is_empty(): ctx=context(player)
 if entry.has("focus") and Classes.focus_id(player.get("character",{}),int(player.get("frame",0)))!=entry.focus:
  return "Requires "+Classes.focus_name(entry.focus)+"."
 var required_core: Dictionary=entry.get("core",entry.get("class_core",{}))
 if not required_core.is_empty():
  var build: Dictionary=ctx.core
  if build.skill.get("id","")!=required_core.skill: return "Requires "+core_name(required_core.skill)+"."
  for slot in required_core.get("slots",{}):
   var available: Array=[build.primary] if slot=="primary" else build.get(slot,[])
   for tag in required_core.slots[slot]:
    if not available.has(tag): return "Requires %s in %s."%[str(tag).capitalize(),"the Core" if slot in ["primary","secondary"] else "the "+str(slot).capitalize()+" slot"]
 if entry.has("classes") and not entry.classes.has(ctx["class"]): return "Requires its class."
 if entry.has("skill_modes_any"):
  var matches:=false
  for slot in 2:
   var mode: String=preload("res://skill_catalog.gd").resolve(int(ctx["class"]),slot,player.get("character",{})).mode
   matches=matches or entry.skill_modes_any.has(mode)
  if not matches: return "Requires a compatible class skill."
 if entry.has("weapons") and not entry.weapons.has(ctx.weapon): return "Requires its weapon."
 if entry.has("grafts") and not entry.grafts.has(ctx.graft): return "Requires the matching monster graft."
 for pair in [["plant_tags",ctx.plant_tags],["graft_tags",ctx.graft_tags],["all_tags",ctx.tags],["plant_parts",ctx.plants]]:
  for needed in entry.get(pair[0],[]):
   if not pair[1].has(needed): return "Your weapon no longer meets the requirements."
 var rank:=int(player.get("run_upgrades",{}).get(entry.id,0))
 if int(entry.max_rank)>0 and rank>=int(entry.max_rank): return "Maximum rank reached."
 return ""
static func weight(entry: Dictionary,player: Dictionary,floor_number: int,ctx: Dictionary={}) -> float:
 if ctx.is_empty(): ctx=context(player)
 if not requirement(entry,player,ctx).is_empty(): return 0.0
 var value: float=float(entry.weight)*float(RARITY_WEIGHT.get(entry.rarity,0.0))
 if entry.has("classes"): value*=3.3
 if entry.has("weapons"): value*=3.8
 if entry.has("grafts"): value*=4.0
 if entry.has("graft_tags"): value*=2.8
 if entry.has("plant_tags"):
  var affinity:=0.0
  for tag in entry.plant_tags: affinity+=float(ctx.plant_weights.get(tag,0))
  value*=1.5+minf(2.0,affinity*.4)
 if entry.has("all_tags") or entry.has("plant_parts"): value*=3.0
 if entry.rarity=="Rare": value*=1.0+clampf((floor_number-5)/50.0,0,1)
 if entry.rarity=="Epic": value*=1.0+clampf((floor_number-5)/50.0,0,2)
 return value/(1.0+.35*int(player.get("run_upgrades",{}).get(entry.id,0)))
static func pool(player: Dictionary,floor_number: int) -> Array:
 if preload("res://combat_ruleset.gd").uses_affinities(player): return []
 var result: Array=[]
 var ctx:=context(player)
 for entry in all():
  var chance:=weight(entry,player,floor_number,ctx)
  if chance>0: result.append({"id":entry.id,"weight":chance,"cost":int(entry.cost),"core":entry.has("core"),"branch":entry.has("class_behavior")})
 return result
static func roll(player: Dictionary,floor_number: int,seed_value: int,wallet: int) -> Array:
 var random:=RandomNumberGenerator.new()
 random.seed=seed_value ^ (floor_number*1103515245)
 var candidates:=pool(player,floor_number)
 var count:=4 if random.randf()<FOURTH_CHANCE else 3
 var result: Array=[]
 var branch_offered:=false
 for slot in count:
  var choices: Array=candidates
  if slot==0 or (slot==1 and branch_offered):
   var affordable:=candidates.filter(func(choice):return int(choice.cost)<=wallet)
   if not affordable.is_empty():
    var branch:=affordable.filter(func(choice):return choice.branch) if slot==0 else []
    var built_for_weapon:=affordable.filter(func(choice):return choice.core)
    choices=branch if not branch.is_empty() else built_for_weapon if not built_for_weapon.is_empty() else affordable
    if slot==0:branch_offered=not branch.is_empty()
  elif slot==2 and branch_offered:
   var flex:=candidates.filter(func(choice):return not choice.core and not choice.branch)
   if not flex.is_empty():choices=flex
  var total:=0.0
  for choice in choices: total+=float(choice.weight)
  if total<=0: break
  var sample:=random.randf()*total
  var selected: Dictionary=choices.back()
  for choice in choices:
   sample-=float(choice.weight)
   if sample<=0: selected=choice;break
  result.append(selected.id)
  for i in candidates.size():
   if candidates[i].id==selected.id: candidates.remove_at(i);break
 return result
static func effects(player: Dictionary) -> Dictionary:
 var result: Dictionary={}
 for id in preload("res://combat_ruleset.gd").legacy_ranks(player):
  var entry:=get_upgrade(id)
  if entry.is_empty(): continue
  var ranks:=int(player.run_upgrades[id])
  for key in entry.effects:
   if key in ["power","technique","rift_hook"]: continue
   result[key]=float(result.get(key,0))+float(entry.effects[key])*ranks
 return result
static func effect_text(entry: Dictionary) -> String:
 var lines: Array[String]=[]
 var preview:=CoreRules.Balance.Preview.enabled
 for key in entry.effects:
  var value: float=entry.effects[key]
  if key=="power":
   if preview: lines.append("+%d HP strike damage"%CoreRules.Balance.Preview.effect_hp(value))
   else: lines.append("+%d strike damage"%int(value))
  elif key=="technique": lines.append("+%d Core technique rank"%int(value))
  elif key=="rift_hook": lines.append("Wind-up hits refresh your dodge.")
  elif key=="cooldown" and value<0: lines.append("%dms slower strikes"%abs(int(value)))
  else: lines.append(Classes.effect_text({key:int(value) if is_equal_approx(value,roundf(value)) else value},preview))
 if preview:
  var core: Dictionary=entry.get("core",{})
  lines.append_array(CoreRules.Balance.tuning_lines(entry.get("core_tuning",{}),core.get("skill","")))
  var punish:=float(entry.get("effect",{}).get("punish",0))
  if punish>0.0: lines.append("+"+CoreRules.Balance.hp(punish)+" against enemies winding up")
 return "\n".join(lines)
static func source_text(entry: Dictionary,player: Dictionary) -> String:
 var sources: Array[String]=[]
 if entry.has("focus"):sources.append(Classes.focus_name(entry.focus))
 var required_core: Dictionary=entry.get("core",entry.get("class_core",{}))
 if not required_core.is_empty():
  sources.append(core_name(required_core.skill))
  for slot in ["form","catalyst","graft"]:
   var tags: Array=required_core.get("slots",{}).get(slot,[])
   if not tags.is_empty(): sources.append(", ".join(tags).capitalize()+" "+slot.capitalize())
 if entry.has("classes"): sources.append(Classes.DEFINITIONS[int(player.frame)].name)
 if entry.has("skill_modes_any"): sources.append("Equipped skill")
 if entry.has("weapons"): sources.append(Classes.DEFINITIONS[int(player.frame)].weapons[int(player.weapon_kind)].name)
 if entry.has("plant_tags"): sources.append("Plant: "+", ".join(entry.plant_tags))
 if entry.has("graft_tags"): sources.append("Graft: "+", ".join(entry.graft_tags))
 if entry.has("grafts"): sources.append("Graft: "+str(Parts.MONSTER_DEFINITIONS[int(entry.grafts[0])].name))
 if entry.has("all_tags") or entry.has("plant_parts"): sources.append("Linked affinities")
 return " · ".join(sources) if not sources.is_empty() else "Weapon fundamentals"


static func core_name(skill_id: String) -> String:
 for rule in CoreRules.RULES:
  if rule.id==skill_id: return rule.name
 return skill_id


static func core_cards(player: Dictionary,skill_id: String) -> Array[Dictionary]:
 var result: Array[Dictionary]=[]
 for id in preload("res://combat_ruleset.gd").legacy_ranks(player):
  if int(player.run_upgrades[id])<=0: continue
  var entry:=get_upgrade(id)
  if entry.get("core",{}).get("skill","")==skill_id: result.append(entry)
 result.sort_custom(func(a,b): return a.id<b.id)
 return result


static func core_card_lines(player: Dictionary,skill_id: String) -> Array:
 return core_cards(player,skill_id).map(func(card): return card.name+" · "+card.description)


static func core_behaviors(player: Dictionary,skill_id: String) -> Array[String]:
 var result: Array[String]=[]
 for card in core_cards(player,skill_id):
  if card.has("behavior") and not result.has(card.behavior): result.append(card.behavior)
 result.sort()
 return result


static func tune_core(player: Dictionary, skill: Dictionary) -> void:
 if skill.is_empty(): return
 for card in core_cards(player,skill.id):
  skill.merge(card.get("core_tuning",{}),true)


static func core_errors(entry: Dictionary) -> Array[String]:
 var result: Array[String]=[]
 if not entry.has("behavior") and not entry.has("core"): return result
 var requirement_data: Dictionary=entry.get("core",{})
 var skill_id: String=requirement_data.get("skill","")
 var rule := CoreRules.skill_by_id(skill_id)
 var behavior: bool = entry.has("behavior") and CORE_BEHAVIORS.get(entry.behavior)==skill_id
 var tuning: bool = entry.has("core_tuning") and CoreRules.valid_tuning(rule,entry.core_tuning)
 if rule.is_empty() or behavior==tuning or int(entry.max_rank)!=1:
  result.append("Invalid Core effect for card "+str(entry.id))
 var slots: Dictionary=requirement_data.get("slots",{})
 for slot in slots:
  if slot not in ["primary","secondary","form","catalyst","graft"] or not slots[slot] is Array or slots[slot].is_empty():
   result.append("Invalid Core slot requirement for "+str(entry.id))
   continue
  for tag in slots[slot]:
   if not (tag is String and CoreRules.valid_slot_tag(tag,slot)):
    result.append("Unknown Core card tag for "+str(entry.id))
 return result
