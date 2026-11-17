extends RefCounted

const Session = preload("res://network_session.gd")

const Participation = preload("res://expedition_participation.gd")
const Tx=preload("res://game_transaction.gd")
const State=preload("res://garden_growth_state.gd")
static func identity(game: Node,id: int) -> String:
 return game.local_character.identity if id==game.HOST else str(Session.inventory_owner(game.players.get(id,{})))
static func register(game: Node,id: int) -> bool:
 if not game.multiplayer.is_server() or not game.players.has(id) or not Session.ready_for(game.players[id],false):return false
 # A title-screen guest has no local world to initialize or save.
 if game.network_session.joined_from_title() and not game.slot_claimed:return false
 var who:=identity(game,id)
 if who.is_empty(): return false
 var growth: Variant=game.progress.garden_interactions.get("growth")
 if growth is Dictionary and growth.get("seen") is Dictionary and growth.seen.has(who): return true
 var result=Tx.run_gameplay(game,Tx.Scope.PAIR,register_receipt.bind(game,who))
 return (result.completed or Tx.committed(result.persistence)) and result.value==true

# Registration also runs inside the host's guarded admission transaction.
static func register_receipt(game: Node,who: String) -> bool:
 var data:=State.initialize(game.progress.garden_interactions,State.snapshot(game.progress))
 if who.is_empty() or data.get("version",1)!=1 or not data.get("growth") is Dictionary or data.growth.get("version",0)!=1 or not data.growth.get("seen") is Dictionary:return false
 if not data.growth.seen.has(who): data.growth.seen[who]=int(data.growth.sequence)
 game.progress.garden_interactions=data
 return true
static func projection(game: Node,id: int) -> Dictionary:
 if not game.multiplayer.is_server():return game.players.get(id,{}).get("garden_interactions",{}).get("growth",{})
 if game.progress.garden_interactions.get("version",1)!=1:return {}
 var raw=game.progress.garden_interactions.get("growth",{})
 if not raw is Dictionary or raw.get("version",0)!=1 or not raw.get("seen") is Dictionary or not raw.get("events") is Array:return {}
 var data: Dictionary=raw
 var who:=identity(game,id);var pending: Array=[];var seen: int=int(data.get("seen",{}).get(who,int(data.get("sequence",0))))
 for event in data.get("events",[]):
  if event is Dictionary and int(event.get("sequence",0))>seen:pending.append(event.duplicate(true))
 return {"version":1,"pending":pending,"history":data.get("events",[]).duplicate(true),"seen":seen,"ready":not game.participation.active() and game.participation.travel_kind().is_empty()}
static func acknowledge(game: Node,id: int,payload: String) -> bool:
 if not game.multiplayer.is_server() or not game.players.has(id) or not Session.ready_for(game.players[id],false) or Participation.is_wild(game.players[id]) or not payload.is_valid_int():return false
 var projection_data:=projection(game,id);var sequence:=int(payload)
 if sequence<=int(projection_data.get("seen",0)):return true
 if projection_data.get("pending",[]).is_empty() or int(projection_data.pending[0].sequence)!=sequence:return false
 var result:=Tx.run_gameplay(game,Tx.Scope.PAIR,func():
  game.progress.garden_interactions.growth.seen[identity(game,id)]=sequence
  return true)
 if result.completed and result.value==true:
  preload("res://diagnostic_journal.gd").event("garden","growth_acknowledged",{"actor":id,"sequence":sequence})
 elif not result.notice.is_empty():
  game.tell(id,result.notice)
 return (result.completed or Tx.committed(result.persistence)) and result.value==true
