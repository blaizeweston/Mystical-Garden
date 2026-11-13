extends RefCounted
const State=preload("res://garden_return_state.gd")
const Catalog=preload("res://garden_return_catalog.gd")
static func state(game: Node) -> Dictionary:
 var root: Dictionary=game.progress.garden_interactions
 if root.get("version",1)!=1:return {}
 if not root.has("returns"):game.progress.garden_interactions=State.initialize(root)
 var value=game.progress.garden_interactions.get("returns",{})
 return value if State.usable(value) else {}
static func begin(game: Node) -> void:
 var value:=state(game)
 if not value.is_empty():State.begin(value)
static func join(game: Node,id: int,player: Dictionary) -> void:
 var value:=state(game)
 if value.is_empty() or value.active.is_empty():return
 var actor: String=game.local_character.identity if id==game.HOST else str(player.get("seed_owner",""))
 if actor.is_empty():actor="peer:"+str(id)
 State.join(value,actor);player.garden_run_actor=actor;player.garden_run_id=value.active.id
static func bank(game: Node,player: Dictionary,seeds: Array,source: String,ancient: bool=false) -> void:
 if not player.get("wild",false):return
 var value:=state(game)
 if value.is_empty():return
 var stable: Array=[]
 for species in seeds:
  if species is int and species>=0 and species<game.Seeds.DEFINITIONS.size():stable.append(str(game.Seeds.DEFINITIONS[species].id))
 if stable.is_empty() and not ancient:return
 State.credit(value,str(player.get("garden_run_actor","")),str(player.get("garden_run_id","")),source,stable,ancient)
static func protected_items(game: Node,player: Dictionary) -> void:
 var seeds: Array=[];var ancient:=false
 for stack in player.get("safe_items",[]):
  if stack.get("item","")=="unidentified_seed":seeds.append_array(stack.get("seeds",[]))
  elif stack.get("item","")=="boss_mystery_seed":ancient=true
 bank(game,player,seeds,"protected",ancient)
static func extras(game: Node,player: Dictionary) -> void:
 bank(game,player,[],"ancient_extract",int(player.get("carried_items",{}).get("boss_mystery_seed",0))>0)
static func outcome(game: Node,player: Dictionary,status: String) -> void:
 var value:=state(game)
 if not value.is_empty():State.outcome(value,str(player.get("garden_run_actor","")),str(player.get("garden_run_id","")),status)
static func member_left(game: Node,player: Dictionary) -> void:
 if not player.get("wild",false):return
 preload("res://game_transaction.gd").run(game,func():outcome(game,player,"disconnected");return true)
static func identified(game: Node,species: int,ancient: bool=false) -> void:
 var value:=state(game)
 if value.is_empty() or species<0 or species>=game.Seeds.DEFINITIONS.size():return
 State.identify(value,str(game.Seeds.DEFINITIONS[species].id),ancient)
static func projection(game: Node,id: int) -> Dictionary:
 if not game.multiplayer.is_server():return game.players.get(id,{}).get("garden_interactions",{}).get("returns",{})
 var value=game.progress.garden_interactions.get("returns",{});var entries: Array=[]
 if game.progress.garden_interactions.get("version",1)!=1 or not State.usable(value):return {}
 for definition in Catalog.DEFINITIONS:
  if value.discoveries.has(definition.id):entries.append(definition.duplicate(true))
 return {"version":1,"catalog":Catalog.signature,"entries":entries}
static func known(data: Dictionary,id: String) -> bool:
 return data.get("version",0)==1 and data.get("catalog","")==Catalog.signature and data.get("entries",[]).any(func(e):return e.get("id","")==id)
static func note(data: Dictionary,point: String) -> String:
 var lines: Array[String]=[]
 for entry in data.get("entries",[]):
  if entry.get("point","")==point:lines.append(str(entry.description)+"\n"+str(entry.hint))
 return "\n\n".join(lines)
