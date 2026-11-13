extends RefCounted
const Seeds=preload("res://seed_catalog.gd")
const Parts=preload("res://weapon_parts.gd")
const Classes=preload("res://class_catalog.gd")
const Enemies=preload("res://enemy_catalog.gd")
const SCHEMA:=2
static var manifest_cache: Dictionary={}
static var legacy_cache: Dictionary={}
static func legacy() -> Dictionary:
 if legacy_cache.is_empty(): legacy_cache=JSON.parse_string(FileAccess.get_file_as_string("res://assets/content/legacy_v1_manifest.json"))
 return legacy_cache.duplicate(true)
static func manifest() -> Dictionary:
 if not manifest_cache.is_empty(): return manifest_cache.duplicate(true)
 var result: Dictionary={"version":SCHEMA,"levels":preload("res://game_balance.gd").levels(),"seeds":Seeds.DEFINITIONS.map(func(e):return str(e.id)),"parts":Parts.DEFINITIONS.map(func(e):return str(e.id)),"classes":Classes.DEFINITIONS.map(func(e):return str(e.id)),"enemies":Enemies.all().map(func(e):return str(e.id)),"weapons":{},"nodes":{}}
 for index in Classes.DEFINITIONS.size():
  var c: Dictionary=Classes.DEFINITIONS[index]
  result.weapons[c.id]=c.weapons.map(func(e):return str(e.id))
  result.nodes[c.id]=Classes.all_nodes(index).map(func(e):return str(e.id))
 manifest_cache=result.duplicate(true)
 return result
static func valid_manifest(value) -> bool:
 if not value is Dictionary: return false
 for field in ["seeds","parts","classes","enemies"]:
  if not value.get(field) is Array: return false
  var seen: Array=[]
  for id in value[field]:
   if not id is String or id.is_empty() or seen.has(id): return false
   seen.append(id)
 for field in ["weapons","nodes"]:
  if not value.get(field) is Dictionary: return false
  for ids in value[field].values():
   if not ids is Array: return false
 return true
static func shifted(values,old: Array,current: Array,zero,quarantine: Dictionary,label: String) -> Array:
 var result: Array=[];result.resize(current.size());result.fill(zero)
 if not values is Array: return result
 for i in mini(values.size(),old.size()):
  var next:=current.find(old[i])
  if next>=0: result[next]=values[i]
  elif values[i]!=zero: quarantine[label+":"+str(old[i])]=values[i]
 return result
static func indices(values,old: Array,current: Array,quarantine: Dictionary,label: String) -> Array:
 var result: Array=[]
 if not values is Array: return result
 for value in values:
  if not (value is int or value is float): continue
  var index:=int(value);var id: String=str(old[index]) if index>=0 and index<old.size() else "invalid:"+str(index)
  var next:=current.find(id)
  if next>=0: result.append(next)
  else: quarantine[label+":"+id]=int(quarantine.get(label+":"+id,0))+1
 return result
static func reserve(data: Dictionary,old: Dictionary,current: Dictionary,q: Dictionary,label: String) -> Dictionary:
 var result:=data.duplicate(true)
 result.stock=shifted(data.get("stock",[]),old.seeds,current.seeds,0,q,label+" stock")
 result.parts=shifted(data.get("parts",[]),old.parts,current.parts,0,q,label+" parts")
 result.unknown=indices(data.get("unknown",[]),old.seeds,current.seeds,q,label+" unknown")
 var history: Array=data.get("history",[-1,0]);var mapped:=indices([history[0]],old.seeds,current.seeds,{},"history") if history.size()==2 and int(history[0])>=0 else []
 result.history=[mapped[0] if not mapped.is_empty() else -1,history[1] if history.size()==2 else 0]
 return result
static func remap_garden(file: ConfigFile) -> void:
 var old=file.get_value("content","manifest",legacy());var current:=manifest()
 var invalid_manifest=old if not valid_manifest(old) else null
 if invalid_manifest!=null: old=legacy()
 var q: Dictionary=file.get_value("content","quarantine",{})
 if not q is Dictionary: q={}
 if invalid_manifest!=null: q["invalid_manifest"]=invalid_manifest
 for prefix in ["stock","parts","crafted","planted","flowering","ready"]:
  var values: Array=[]
  for i in old.seeds.size(): values.append(file.get_value("garden",prefix+"_"+str(i),false if prefix in ["crafted","planted","flowering","ready"] else 0))
  var mapped:=shifted(values,old.seeds,current.seeds,false if prefix in ["crafted","planted","flowering","ready"] else 0,q,prefix)
  for i in maxi(old.seeds.size(),current.seeds.size()):
   if file.has_section_key("garden",prefix+"_"+str(i)): file.erase_section_key("garden",prefix+"_"+str(i))
  for i in mapped.size(): file.set_value("garden",prefix+"_"+str(i),mapped[i])
 file.set_value("garden","unknown",indices(file.get_value("garden","unknown",[]),old.seeds,current.seeds,q,"unknown"))
 file.set_value("garden","seed_discoveries",shifted(file.get_value("garden","seed_discoveries",[]),old.seeds,current.seeds,false,q,"discoveries"))
 for field in ["personal_parts","monster_materials"]: file.set_value("garden",field,shifted(file.get_value("garden",field,[]),old.parts,current.parts,0,q,field))
 file.set_value("garden","monster_crafts",indices(file.get_value("garden","monster_crafts",[]),old.parts,current.parts,q,"monster crafts"))
 var owner:=reserve({"history":file.get_value("garden","seed_history",[-1,0])},old,current,q,"owner")
 file.set_value("garden","seed_history",owner.history)
 var guests=file.get_value("garden","guest_seeds",{})
 if guests is Dictionary:
  for id in guests:
   if guests[id] is Dictionary: guests[id]=reserve(guests[id],old,current,q,"guest "+str(id))
  file.set_value("garden","guest_seeds",guests)
 var beds=file.get_value("garden","plots_v2",false)
 if beds is Array:
  for bed in beds:
   if bed is Dictionary and int(bed.get("species",-1))>=0:
    var mapped:=indices([bed.species],old.seeds,current.seeds,q,"planted")
    bed.species=mapped[0] if not mapped.is_empty() else -1
  file.set_value("garden","plots_v2",beds)
 var pairs=file.get_value("garden","seed_attempts",[])
 if pairs is Array:
  var mapped: Array=[]
  for pair in pairs:
   var next:=indices(pair,old.seeds,current.seeds,q,"recipe parents")
   if next.size()==2: mapped.append(next)
  file.set_value("garden","seed_attempts",mapped)
 var heart=file.get_value("heart","state",{})
 if heart is Dictionary and heart.has("offered"):
  heart.offered=indices(heart.offered,old.parts,current.parts,q,"offered");file.set_value("heart","state",heart)
 file.set_value("content","manifest",current);file.set_value("content","quarantine",q)
static func profile(source: Dictionary,old) -> Dictionary:
 var current:=manifest();var result:=source.duplicate(true);var q: Dictionary=source.get("quarantine",{}).duplicate(true) if source.get("quarantine",{}) is Dictionary else {}
 if not valid_manifest(old): q["invalid_manifest"]=old;old=legacy()
 for pair in [["xp","classes"],["plants","seeds"],["monsters","enemies"]]: result[pair[0]]=shifted(source.get(pair[0],[]),old[pair[1]],current[pair[1]],0,q,pair[0])
 var old_levels: Array=old.get("levels",[0,3,7,12,20]);var new_levels: Array=current.levels
 if old_levels!=new_levels:
  for c in result.xp.size():
   var xp:=int(result.xp[c]);var rank:=0
   for i in range(1,old_levels.size()):
    if xp>=int(old_levels[i]): rank=i
   if rank>=new_levels.size(): rank=new_levels.size()-1
   var fraction:=0.
   if rank<old_levels.size()-1: fraction=clampf((xp-float(old_levels[rank]))/maxf(1,float(old_levels[rank+1])-float(old_levels[rank])),0,.999)
   result.xp[c]=int(new_levels[rank])+roundi(fraction*(float(new_levels[mini(rank+1,new_levels.size()-1)])-float(new_levels[rank])))
 var active:=indices([source.get("active_class",0)],old.classes,current.classes,q,"active class");result.active_class=active[0] if not active.is_empty() else 0
 var loadouts: Array=[];var learned: Array=[]
 for c in current.classes.size():
  var id: String=str(current.classes[c]);var index: int=old.classes.find(id);var loadout: Dictionary={"weapon":0,"parts":[0,0,0]};var mask:=0
  if index>=0:
   var saved=source.get("loadouts",[])
   if saved is Array and index<saved.size() and saved[index] is Dictionary:
    var entry: Dictionary=saved[index];var mapped:=indices([entry.get("weapon",0)],old.weapons.get(id,[]),current.weapons[id],q,"weapon "+id)
    loadout.weapon=mapped[0] if not mapped.is_empty() else 0
    for part in mini(3,entry.get("parts",[]).size()):
     var converted:=indices([entry.parts[part]],old.parts,current.parts,q,"loadout "+id)
     loadout.parts[part]=converted[0] if not converted.is_empty() else 0
   var upgrades=source.get("upgrades",[])
   if upgrades is Array and index<upgrades.size():
    var old_nodes: Array=old.nodes.get(id,[])
    for i in old_nodes.size():
     if int(upgrades[index]) & (1<<i):
      var node: int=current.nodes[id].find(old_nodes[i])
      if node>=0: mask|=1<<node
      else: q["node "+id+":"+str(old_nodes[i])]=true
  loadouts.append(loadout);learned.append(mask)
 result.loadouts=loadouts;result.upgrades=learned;result.quarantine=q
 return result

