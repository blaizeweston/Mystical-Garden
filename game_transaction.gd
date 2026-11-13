extends RefCounted
const Batch=preload("res://save_batch.gd")
static func snapshot(object: Object) -> Dictionary:
 var result: Dictionary={}
 for property in object.get_property_list():
  if not (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE): continue
  var value=object.get(property.name)
  if value is Array or value is Dictionary: result[property.name]=value.duplicate(true)
  elif value is int or value is float or value is bool or value is String or value is Vector3: result[property.name]=value
 return result
static func restore_dict(current: Dictionary,value: Dictionary) -> void:
 for key in current.keys():
  if not value.has(key): current.erase(key)
 for key in value:
  if current.get(key) is Dictionary and value[key] is Dictionary: restore_dict(current[key],value[key])
  elif current.get(key) is Array and value[key] is Array: current[key].assign(value[key])
  else: current[key]=value[key].duplicate(true) if value[key] is Dictionary or value[key] is Array else value[key]
static func restore(object: Object,state: Dictionary) -> void:
 for key in state:
  var current=object.get(key);var value=state[key]
  if current is Array and value is Array: current.assign(value)
  elif current is Dictionary and value is Dictionary: restore_dict(current,value)
  else: object.set(key,value)
static func run(game: Node,action: Callable):
 if Batch.guarded_active():
  return action.call() if _owner == game else false
 if Batch.active: return action.call()
 var diagnostic_transaction=preload("res://diagnostic_journal.gd").event("save","transaction_begin",{"operation":action.get_method()})
 var world:=snapshot(game.progress);var heart: Dictionary=game.progress.heart.serialize();var campaign:=snapshot(game.progress.campaign)
 var state:=snapshot(game);state.erase("players");var local: Dictionary=game.local_character.data.duplicate(true);var guest: Dictionary=game.guest_character.data.duplicate(true)
 var players: Dictionary=game.players.duplicate(true)
 game.transaction_publishes.clear();Batch.begin(game.progress.path)
 var result=action.call()
 # All persistent world mutations and the local character form one commit.
 game.progress.save_garden()
 if game.players.has(game.HOST): game.local_character.data=game.players[game.HOST].character
 if game.session!="Guest": game.local_character.save_profile()
 var error:=Batch.commit()
 if error!=OK:
  preload("res://diagnostic_journal.gd").event("save","transaction_rollback",{"error":error,"transaction_seq":diagnostic_transaction},"error")
  preload("res://game_metrics.gd").flush(false)
  preload("res://game_metrics.gd").record("save_rollback",{"error":error})
  restore(game.progress,world);game.progress.heart.restore(heart);restore(game.progress.campaign,campaign)
  restore(game,state)
  for id in players:
   if not game.players.has(id): game.players[id]=players[id].duplicate(true)
   else: restore_dict(game.players[id],players[id])
  game.local_character.data=game.players[game.HOST].character if game.players.has(game.HOST) else local
  game.guest_character.data=guest
  game.transaction_publishes.clear();game.status="Could not save this action. Nothing was consumed; please retry."
  return false
 preload("res://diagnostic_journal.gd").event("save","transaction_committed",{"transaction_seq":diagnostic_transaction})
 preload("res://game_metrics.gd").flush(true)
 # Presentation confirms only committed outcomes; a rollback must not show damage.
 if game.online_peer!=null and game.multiplayer.is_server():
  for source in game.combat_events:
   if int(source.id)<=int(state.get("combat_event_serial",0)):continue
   var event: Dictionary=source.duplicate();event.erase("born");event.age=maxf(0,(Time.get_ticks_msec()-int(source.born))/1000.0)
   game.receive_combat_event.rpc(event,str([game.destination,game.encounter_number,game.map_seed]))
 var publishes: Array=game.transaction_publishes.duplicate();game.transaction_publishes.clear()
 for id in publishes:
  if id!=game.HOST and game.players.has(id) and game.online_peer!=null: game.receive_character.rpc_id(id,game.players[id].character)
 return result

# Opt-in entry used by integration fixtures. The legacy dispatcher stays on
# run() until the production cutover and caller publication audit are complete.
static var _owner: Node

static func run_guarded(game: Node, action: Callable, publish := Callable()) -> Dictionary:
 return _run_guarded(game, action, publish)

static func _run_guarded(game: Node, action: Callable, publish: Callable, fault := Callable()) -> Dictionary:
 if not Thread.is_main_thread() or not is_instance_valid(game) or not action.is_valid():
  return {"error": ERR_INVALID_PARAMETER, "ran": false, "reason": "invalid_transaction"}
 if _owner != null:
  if _owner != game or publish.is_valid() or not Batch.guarded_active():
   return {"error": ERR_BUSY, "ran": false, "reason": "foreign_nested_transaction"}
  return {"error": OK, "ran": true, "nested": true, "value": action.call()}
 if game.has_meta("guarded_persistence_pending"):
  return {"error": ERR_BUSY, "ran": false, "reason": "guarded_persistence_pending"}

 var serializers := [game.progress]
 if game.session != "Guest":
  serializers.append(game.local_character)
 var captured := {}
 var operations = load("res://persistence_operations.gd")
 var boundary: Dictionary = operations.run_serializers(serializers, game.progress.path, func():
  captured.world = snapshot(game.progress)
  captured.heart = game.progress.heart.serialize()
  captured.campaign = snapshot(game.progress.campaign)
  captured.game = snapshot(game)
  captured.game.erase("players")
  captured.players = game.players.duplicate(true)
  captured.local = snapshot(game.local_character)
  captured.guest = snapshot(game.guest_character)
  captured.rng = game.rng.state
  game.transaction_publishes.clear()
  _owner = game
  var value: Variant = action.call()
  game.progress.save_garden()
  if game.players.has(game.HOST):
   game.local_character.data = game.players[game.HOST].character
  if game.session != "Guest":
   game.local_character.save_profile()
  _owner = null
  return value, fault)
 var execution: Variant = boundary.get("value")
 var finalized: Batch.Finalization = execution.get("outcome") if execution is Dictionary else null
 if finalized == null:
  if boundary.state == "pending_recovery" or (execution is Dictionary and execution.get("reason") == "unresolved_transaction"):
   game.set_meta("guarded_persistence_pending", true)
  return boundary

 match finalized.outcome:
  Batch.Outcome.ABORTED_RESTORED:
   if execution.action_ran:
    _restore_guarded(game, captured)
  Batch.Outcome.UNCERTAIN:
   game.transaction_publishes.clear()
 if finalized.write_blocked or boundary.release_error != OK:
  game.set_meta("guarded_persistence_pending", true)
 if finalized.outcome in [Batch.Outcome.COMMITTED, Batch.Outcome.COMMITTED_CLEANUP_PENDING] and publish.is_valid():
  publish.call(execution.value)
 return boundary

static func _restore_guarded(game: Node, captured: Dictionary) -> void:
 restore(game.progress, captured.world)
 game.progress.heart.restore(captured.heart)
 restore(game.progress.campaign, captured.campaign)
 restore(game, captured.game)
 restore_dict(game.players, captured.players)
 restore(game.local_character, captured.local)
 restore(game.guest_character, captured.guest)
 if game.players.has(game.HOST):
  game.local_character.data = game.players[game.HOST].character
 game.rng.state = captured.rng