extends RefCounted
const Batch=preload("res://save_batch.gd")
const Session = preload("res://guarded_title_session.gd")
const MonsterRewards = preload("res://monster_rewards.gd")
const EncounterRoster = preload("res://encounter_roster.gd")
const EnemyTactics = preload("res://enemy_tactics.gd")
const ExpeditionParticipation = preload("res://expedition_participation.gd")

static func snapshot(object: Object, skip_property: StringName = &"") -> Dictionary:
 var result: Dictionary={}
 for property in object.get_property_list():
  if property.name == skip_property or not (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE): continue
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
static func run(game: Node,action: Callable, verdict := {}):
 if game.persistence_session.is_blocked():
  verdict.error = ERR_BUSY
  game.status = game.persistence_session.pending_notice()
  return false
 if game.persistence_session.is_guarded():
  if game.persistence_session.can_write():
   game.status = "This action is unavailable in the guarded session."
  return false
 if Batch.guarded_active():
  return action.call() if _owner == game else false
 if Batch.active:
  var nested: Variant = action.call()
  verdict.error = Batch.failure
  return nested
 var paths := PackedStringArray([game.progress.path])
 var auxiliary: PackedStringArray = game.progress.migration_backup_paths()
 if game.network_session.role() != "Guest":
  paths.append(game.local_character.path)
  auxiliary.append_array(game.local_character.migration_backup_paths())
 return _run_legacy(game, action, verdict, paths, auxiliary)

static func _run_legacy(game: Node, action: Callable, verdict: Dictionary, paths: PackedStringArray, auxiliary: PackedStringArray) -> Variant:
 var diagnostic_transaction=preload("res://diagnostic_journal.gd").event("save","transaction_begin",{"operation":action.get_method()})
 var world:=snapshot(game.progress);var heart: Dictionary=game.progress.heart.serialize();var campaign:=snapshot(game.progress.campaign)
 var state:=snapshot(game,&"players");var local:=snapshot(game.local_character);var guest:=snapshot(game.guest_character)
 var players: Dictionary=game.players.duplicate(true)
 var rng_state: int = game.rng.state
 var rewards: MonsterRewards = game.get("monster_rewards")
 var statistics: RefCounted = game.get("expedition_statistics")
 var statistics_snapshot: Dictionary = statistics.savepoint() if statistics != null else {}
 var reward_savepoint: Dictionary = rewards.savepoint() if rewards != null else {}
 var encounter: EncounterRoster = game.get("encounter")
 var encounter_savepoint := encounter.savepoint() if encounter != null else {}
 var tactics: EnemyTactics = game.get("tactics")
 var tactics_savepoint := snapshot(tactics) if tactics != null else {}
 var participation: ExpeditionParticipation = game.get("participation")
 var participation_savepoint := participation.savepoint() if participation != null else {}
 var expedition_snapshot: Dictionary
 if game.has_method("snapshot_expedition_runtime"):
  expedition_snapshot = game.snapshot_expedition_runtime()
 else:
  expedition_snapshot = {"weapons":game.weapon_attacks.savepoint(), "effects":game.effect_timeline.savepoint()}
 var execution := {}
 var gate_error := Batch.Legacy.run(paths, func(_plan):
  var begin_error := Batch.begin(game.progress.path)
  if begin_error != OK: return begin_error
  game.transaction_publishes.clear()
  _owner = game
  execution.value = action.call()
  _owner = null
  Batch.record_serializer_error(game.progress.save_garden(), game.progress.path)
  if game.players.has(game.HOST):
   game.local_character.data = game.players[game.HOST].character
   _archive_host_profile(game)
  if game.network_session.role() != "Guest": Batch.record_serializer_error(game.local_character.save_profile(), game.local_character.path)
  execution.outcome = Batch.commit()
  return OK, auxiliary)
 if not execution.has("outcome"):
  verdict.error = gate_error
  game.status = "Save unavailable. Your save files were preserved."
  return false
 var final: Batch.Finalization = execution.outcome
 var boundary := {"value":execution, "error":gate_error, "release_error":gate_error, "state":"finalized", "reason":final.phase}
 verdict.persistence = boundary
 game.persistence_session.record_finalization(boundary)
 var notice: String = _report(game, boundary)
 verdict.error = OK
 if final.outcome == Batch.Outcome.UNCERTAIN:
  verdict.error = final.original_error if final.original_error != OK else final.recovery_error
  if statistics != null: statistics.hold_uncertain()
  if rewards != null: rewards.finish_settlement(MonsterRewards.Result.UNCERTAIN)
  game.transaction_publishes.clear()
  preload("res://game_metrics.gd").flush(false)
  game.status = notice
  return false
 if final.outcome == Batch.Outcome.ABORTED_RESTORED:
  var error := final.original_error
  verdict.error = error
  preload("res://diagnostic_journal.gd").event("save","transaction_rollback",{"error":error,"transaction_seq":diagnostic_transaction},"error")
  preload("res://game_metrics.gd").flush(false)
  preload("res://game_metrics.gd").record("save_rollback",{"error":error})
  restore(game.progress,world);game.progress.heart.restore(heart);restore(game.progress.campaign,campaign)
  restore(game,state)
  if statistics != null: statistics.restore_savepoint(statistics_snapshot)
  if encounter != null:
   encounter.restore_savepoint(encounter_savepoint)
  if tactics != null:
   restore(tactics,tactics_savepoint)
  if participation != null:
   participation.restore_savepoint(participation_savepoint)
  if rewards != null:
   rewards.restore_savepoint(reward_savepoint)
  for id in players:
   if not game.players.has(id): game.players[id]=players[id].duplicate(true)
   else: restore_dict(game.players[id],players[id])
  restore(game.local_character,local)
  restore(game.guest_character,guest)
  if game.players.has(game.HOST): game.local_character.data=game.players[game.HOST].character
  if game.has_method("restore_expedition_runtime"):
   game.restore_expedition_runtime(expedition_snapshot)
  else:
   game.weapon_attacks.restore_savepoint(expedition_snapshot.weapons)
   game.effect_timeline.restore_savepoint(expedition_snapshot.effects)
  game.rng.state=rng_state
  game.transaction_publishes.clear()
  game.status = notice
  return false
 if rewards != null:
  rewards.finish_settlement(MonsterRewards.Result.CLEANUP_PENDING if final.write_blocked or gate_error != OK else MonsterRewards.Result.COMMITTED)
 preload("res://diagnostic_journal.gd").event("save","transaction_committed",{"transaction_seq":diagnostic_transaction})
 preload("res://game_metrics.gd").flush(true)
 # Presentation confirms only committed outcomes; a rollback must not show damage.
 if game.network_session.transport()!=null and game.multiplayer.is_server():
  for source in game.combat_events:
   if int(source.id)<=int(state.get("combat_event_serial",0)):continue
   var event: Dictionary=source.duplicate();event.erase("born");event.age=maxf(0,(preload("res://combat_clock.gd").now()-int(source.born))/1000.0)
   game.receive_combat_event.rpc(event,str([game.participation.route(),game.participation.floor(),game.participation.seed()]))
 if statistics != null: game.publish_expedition_results()
 var publishes: Array=game.transaction_publishes.duplicate();game.transaction_publishes.clear()
 for publication in publishes:
  if publication is Callable:
   publication.call()
  elif publication != game.HOST and game.players.has(publication) and game.network_session.transport() != null:
   game.receive_character.rpc_id(publication,game.players[publication].character)
 if not notice.is_empty(): game.status = notice
 return execution.value

const CLEANUP_NOTICE := Session.CLEANUP_NOTICE
enum Scope { LEGACY, GARDEN, PROFILE, PAIR, GUEST_PROFILE }

static var _owner: Node
static var _participants: Array = []

## Remote settlement notices share the ordinary root's post-commit queue
## with profile updates. Raw staging (including the arena) has no such root.
static func queue_legacy_notice(game: Node, id: int, message: String) -> bool:
 if _owner != game or not Batch.active: return false
 game.transaction_publishes.append(game.tell.bind(id,message))
 return true

static func committed(boundary: Dictionary) -> bool:
 var execution: Variant = boundary.get("value")
 var final: Batch.Finalization = execution.get("outcome") if execution is Dictionary else null
 return final != null and final.outcome in [Batch.Outcome.COMMITTED, Batch.Outcome.COMMITTED_CLEANUP_PENDING]

static func feedback_text(game: Node, message: String) -> String:
 var pending: String = game.persistence_session.pending_notice()
 if pending.is_empty() or message == pending or message.ends_with("\n" + pending): return message
 return pending if message.is_empty() else message + "\n" + pending

static func feedback(result: Dictionary, fallback: String) -> String:
 if result.completed and result.value is String:
  return result.value
 return fallback if result.notice.is_empty() else result.notice

# Keep the existing boundary and typed finalization available to callers.
# Gameplay completion and the recovery notice can coexist.
static func run_gameplay(game: Node, scope: Scope, action: Callable, legacy_transaction := true) -> Dictionary:
 if not game.persistence_session.is_guarded():
  if game.persistence_session.is_blocked():
   return {"completed":false, "value":false, "notice":game.persistence_session.pending_notice(), "persistence":{}}
  var verdict := {}
  var value: Variant = run(game, action, verdict) if legacy_transaction else action.call()
  var boundary: Dictionary = verdict.get("persistence", {})
  var saved: bool = committed(boundary) if not boundary.is_empty() else verdict.get("error", OK) == OK
  return {"completed":saved, "value":value, "notice":game.persistence_session.pending_notice() if saved else game.status, "persistence":boundary}
 return _guarded_gameplay_result(game, scope, action)

## This fixed operation can change only crop state and its serialized
## Garden projection. General Garden commands may also change actors and rewards.
static func save_growth_checkpoint(game: Node, updated_plots: Array) -> String:
 var advance := func():
  game.progress.plots.assign(updated_plots)
  game.progress.sync_plot_flags()
  return ""
 return feedback(_guarded_gameplay_result(game, Scope.GARDEN, advance, true), "Growth could not be saved.")

static func _guarded_gameplay_result(game: Node, scope: Scope, action: Callable, growth_only := false) -> Dictionary:
 if _owner != null:
  return {"completed": false, "value": null, "notice": "Save operation is already in progress.",
   "persistence": _refusal(ERR_BUSY, "nested_gameplay_operation", "busy")}
 # The existing fault callback is available to disposable headless fixtures.
 var fault: Callable = game.get_meta(&"guarded_gameplay_test_fault", Callable()) if DisplayServer.get_name() == "headless" else Callable()
 var boundary: Dictionary = _run_guarded(game, action, Callable(), fault, scope, growth_only)
 var execution: Variant = boundary.get("value")
 var confirmed := committed(boundary)
 return {"completed": confirmed and boundary.error == OK, "value": execution.value if confirmed else null,
  "notice": _report(game, boundary), "persistence": boundary}

static func _report(game: Node, boundary: Dictionary) -> String:
 var execution: Variant = boundary.get("value")
 var final: Batch.Finalization = execution.get("outcome") if execution is Dictionary else null
 var outcome_feedback: Dictionary = game.persistence_session.finalization_feedback(boundary)
 var notice: String = outcome_feedback.notice
 if outcome_feedback.clear_status: game.status = ""
 elif outcome_feedback.set_status: game.status = notice
 if not notice.is_empty():
  preload("res://diagnostic_journal.gd").event("save", "guarded_gameplay_result" if game.persistence_session.is_guarded() else "legacy_gameplay_result", {
   "reason": boundary.reason, "state": boundary.state, "error": boundary.error,
   "outcome": Batch.Outcome.keys()[final.outcome] if final != null else "",
   "phase": final.phase if final != null else "", "attempt": final.attempt_id if final != null else "",
   "original_error": final.original_error if final != null else OK,
   "recovery_error": final.recovery_error if final != null else OK,
   "cleanup_error": final.cleanup_error if final != null else OK,
  })
 return notice

static func run_guarded(game: Node, action: Callable, publish := Callable(), scope := Scope.LEGACY) -> Dictionary:
 return _run_guarded(game, action, publish, Callable(), scope)

static func _run_guarded(game: Node, action: Callable, publish: Callable, fault := Callable(), scope := Scope.LEGACY, growth_only := false) -> Dictionary:
 if not Thread.is_main_thread() or not is_instance_valid(game) or not action.is_valid():
  return _refusal(ERR_INVALID_PARAMETER, "invalid_transaction")
 var owner: RefCounted = game.persistence_session if game.persistence_session.is_guarded() else null
 if owner != null and scope == Scope.LEGACY:
  return _refusal(ERR_UNAUTHORIZED, "explicit_gameplay_scope_required")
 if owner == null and scope != Scope.LEGACY:
  return _refusal(ERR_UNAUTHORIZED, "gameplay_session_required")
 if game.persistence_session.is_blocked():
  return _refusal(ERR_BUSY, "guarded_persistence_pending", "pending_recovery")
 if game.persistence_session.is_stopping():
  return _refusal(ERR_UNAUTHORIZED, "guarded_session_stopping")
 var serializers := _serializers(game, scope)
 if serializers.is_empty():
  return _refusal(ERR_UNAUTHORIZED, "unowned_participant")
 if _owner != null:
  if _owner != game or publish.is_valid() or fault.is_valid() or not Batch.guarded_active():
   return _refusal(ERR_BUSY, "foreign_nested_transaction")
  for serializer in serializers:
   if not _participants.has(serializer) or (owner != null and not owner.authorizes(serializer.path)):
    Batch.reject_guarded_serializer(ERR_UNAUTHORIZED, serializer.path)
    return _refusal(ERR_UNAUTHORIZED, "nested_participant_refused")
  return {"error": OK, "ran": true, "nested": true, "value": action.call()}

 var captured := {}
 var rewards: MonsterRewards = null if growth_only else game.get("monster_rewards")
 var operations = load("res://persistence_operations.gd")
 var anchor: String = serializers[0].path
 var capture_gameplay := func():
  if game.get("expedition_statistics") != null: captured.statistics = game.expedition_statistics.savepoint()
  captured.world = snapshot(game.progress)
  captured.heart = game.progress.heart.serialize()
  captured.campaign = snapshot(game.progress.campaign)
  captured.game = snapshot(game, &"players")
  captured.players = game.players.duplicate(true)
  captured.local = snapshot(game.local_character)
  captured.guest = snapshot(game.guest_character)
  captured.rng = game.rng.state
  if rewards != null:
   captured.monster_rewards = rewards.savepoint()
  var encounter: EncounterRoster = game.get("encounter")
  if encounter != null:
   captured.encounter = encounter.savepoint()
  var tactics: EnemyTactics = game.get("tactics")
  if tactics != null:
   captured.tactics = snapshot(tactics)
  var participation: ExpeditionParticipation = game.get("participation")
  if participation != null:
   captured.participation = participation.savepoint()
  if game.has_method("snapshot_expedition_runtime"):
   captured.expedition = game.snapshot_expedition_runtime()
 var action_and_save := func():
  if growth_only:
   captured.growth = game.progress.plots.duplicate(true)
   # The serializer installs a new detached growth/reveal projection after staging.
   captured.interactions = game.progress.garden_interactions
  else:
   capture_gameplay.call()
   game.transaction_publishes.clear()
  _owner = game
  _participants = serializers
  var value: Variant = action.call()
  if owner != null and not owner.owns_leases():
   Batch.reject_guarded_serializer(ERR_UNAUTHORIZED, anchor)
  else:
   for serializer in serializers:
    if serializer == game.progress:
     Batch.record_serializer_error(serializer.save_garden(), serializer.path)
    else:
     if serializer == game.local_character and game.players.has(game.HOST):
      game.local_character.data = game.players[game.HOST].character
      _archive_host_profile(game)
     Batch.record_serializer_error(serializer.save_profile(), serializer.path)
  _participants = []
  _owner = null
  return value
 var boundary: Dictionary
 if owner == null:
  boundary = operations.run_serializers(serializers, anchor, action_and_save, fault)
 else:
  var scope_data: Dictionary = operations._serializer_scope(serializers)
  if scope_data.is_empty():
   return _refusal(ERR_INVALID_PARAMETER, "duplicate_serializer_path")
  for path: String in scope_data.paths:
   if not owner.authorizes(path):
    return _refusal(ERR_UNAUTHORIZED, "stale_session_lease" if not owner.owns_leases() else "unowned_participant")
  var metadata_scratch := PackedStringArray()
  for path: String in scope_data.paths:
   var metadata: String = operations.Layout.deletion_metadata(path, operations.Layout.directories())
   if not metadata.is_empty() and not metadata_scratch.has(metadata + ".tmp"):
    metadata_scratch.append(metadata + ".tmp")
  boundary = operations.run_management(scope_data.paths, scope_data.auxiliary + metadata_scratch, func(context):
   for path: String in scope_data.paths:
    if not owner.authorizes(path):
     return _refusal(ERR_UNAUTHORIZED, "stale_session_lease")
   for scratch in metadata_scratch:
    if FileAccess.file_exists(scratch):
     return _refusal(ERR_BUSY, "metadata_publication_pending", "pending_recovery")
   return operations.commit_serializers(context, serializers, anchor, action_and_save, fault))
 var execution: Variant = boundary.get("value")
 var finalized: Batch.Finalization = execution.get("outcome") if execution is Dictionary else null
 if finalized == null:
  if execution is Dictionary and not execution.get("ran", false):
   var release_error: Error = boundary.release_error
   boundary = _refusal(execution.get("error", ERR_BUG), execution.get("reason", "transaction_refused"),
    "pending_recovery" if execution.get("reason") == "unresolved_transaction" else execution.get("state", "invalid"))
   boundary.release_error = release_error
  if captured.has("statistics"): game.expedition_statistics.hold_uncertain()
  if not captured.is_empty():
   if rewards != null: rewards.finish_settlement(MonsterRewards.Result.UNCERTAIN)
   if not growth_only: game.transaction_publishes.clear()
   boundary.state = "unresolved"
   boundary.reason = "missing_gameplay_finalization"
   if boundary.error == OK: boundary.error = ERR_BUG
  game.persistence_session.record_finalization(boundary)
  return boundary

 match finalized.outcome:
  Batch.Outcome.ABORTED_RESTORED:
   if execution.action_ran:
    if growth_only:
     game.progress.plots.assign(captured.growth)
     game.progress.sync_plot_flags()
     game.progress.garden_interactions = captured.interactions
    else:
     _restore_guarded(game, captured)
  Batch.Outcome.UNCERTAIN:
   if captured.has("statistics"): game.expedition_statistics.hold_uncertain()
   if rewards != null:
    rewards.finish_settlement(MonsterRewards.Result.UNCERTAIN)
   if not growth_only: game.transaction_publishes.clear()
  Batch.Outcome.COMMITTED, Batch.Outcome.COMMITTED_CLEANUP_PENDING:
   if rewards != null:
    var cleanup: bool = finalized.outcome == Batch.Outcome.COMMITTED_CLEANUP_PENDING or finalized.write_blocked or boundary.release_error != OK
    rewards.finish_settlement(MonsterRewards.Result.CLEANUP_PENDING if cleanup else MonsterRewards.Result.COMMITTED)
 game.persistence_session.record_finalization(boundary)
 if committed(boundary):
  if publish.is_valid(): publish.call(execution.value)
  if captured.has("statistics"): game.publish_expedition_results()
 return boundary

## Mirror only this character's authoritative Garden slice on an existing local
## profile write. Garden-only operations remain recoverable from the Garden.
static func _archive_host_profile(game: Node) -> void:
 var identity: String = game.local_character.identity
 var state: Dictionary = game.progress.archive
 if state.characters.has(identity):
  game.local_character.archive_visits[state.origin] = state.characters[identity].duplicate()

static func _serializers(game: Node, scope: Scope) -> Array:
 match scope:
  Scope.GARDEN: return [game.progress] if game.network_session.role() in ["Solo", "Host"] else []
  Scope.PROFILE: return [game.local_character] if game.network_session.role() in ["Solo", "Host"] else []
  Scope.PAIR: return [game.progress, game.local_character] if game.network_session.role() in ["Solo", "Host"] else []
  Scope.GUEST_PROFILE: return [game.guest_character] if game.network_session.role() == "Guest" else []
 return [game.progress] if game.network_session.role() == "Guest" else [game.progress, game.local_character]

static func _refusal(error: Error, reason: String, state := "invalid") -> Dictionary:
 return {"error": error, "state": state, "ran": false, "reason": reason, "release_error": OK, "value": null}

static func _restore_guarded(game: Node, captured: Dictionary) -> void:
 restore(game.progress, captured.world)
 game.progress.heart.restore(captured.heart)
 restore(game.progress.campaign, captured.campaign)
 restore(game, captured.game)
 if captured.has("statistics"): game.expedition_statistics.restore_savepoint(captured.statistics)
 if captured.has("encounter"):
  game.encounter.restore_savepoint(captured.encounter)
 if captured.has("tactics"):
  restore(game.tactics,captured.tactics)
 if captured.has("participation"):
  game.participation.restore_savepoint(captured.participation)
 if captured.has("monster_rewards"):
  game.monster_rewards.restore_savepoint(captured.monster_rewards)
 restore_dict(game.players, captured.players)
 restore(game.local_character, captured.local)
 restore(game.guest_character, captured.guest)
 if game.players.get(game.HOST, {}).has("character"):
  game.local_character.data = game.players[game.HOST].character
 game.rng.state = captured.rng
 if captured.has("expedition"):
  game.restore_expedition_runtime(captured.expedition)
