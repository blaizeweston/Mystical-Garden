extends RefCounted
## Integration at the existing guarded session/settlement boundary.
const State=preload("res://inventory_custody.gd")
const Tx=preload("res://game_transaction.gd")
const Batch=preload("res://save_batch.gd")
const Journal=preload("res://diagnostic_journal.gd")
const Network=preload("res://network_settings.gd")
const Session=preload("res://network_session.gd")
const Participation=preload("res://expedition_participation.gd")

static func origin(game) -> String:
 return game.progress.archive.origin

static func refused(game,message: String) -> bool:
 game.status=message
 return false

static func fail_serializer(path: String) -> bool:
 Batch.record_serializer_error(ERR_INVALID_DATA,path)
 return false

static func local_enter(game,assign_host: bool) -> bool:
 if not game.portable_inventory:return true
 if not game.persistence_session.is_guarded():return refused(game,"Portable inventory requires guarded save access.")
 var profile=game.local_character
 var garden=game.progress
 if State.locked(profile.inventory_custody):
  var lock: Dictionary=profile.inventory_custody
  if lock.origin!=origin(game):return refused(game,"Your personal inventory is held by another Garden. Reconnect to that Garden before playing elsewhere.")
  if lock.endpoint!="":return refused(game,"Your outstanding inventory belongs to a remote visit. Reconnect to the original host.")
  if not State.active(garden,profile.identity) or not State.matches(garden.personal_custody[profile.identity],lock):return refused(game,"This Garden does not have the matching inventory custody record. Recover the saves before playing.")
  return true
 if State.needs_host_assignment(garden) and not assign_host:
  return refused(game,"Assign the historical Garden personal reserve to a character before entering.")
 var lock:=State.checkout(profile.inventory_custody,origin(game),"")
 if lock.is_empty():return refused(game,"Could not establish a new personal inventory custody.")
 var saved:=Tx.run_gameplay(game,Tx.Scope.PAIR,func():
  if State.admit(garden,profile.identity,lock,assign_host)!="active":return fail_serializer(garden.path)
  profile.inventory_custody=lock
  return true)
 if not Tx.committed(saved.persistence) or saved.value!=true:return refused(game,Tx.feedback_text(game,"Could not check inventory into this Garden."))
 Journal.event("save","inventory_custody_enter",{"character":profile.identity,"origin":origin(game),"sequence":lock.sequence})
 return game.persistence_session.can_write()

static func local_release(game) -> bool:
 if not game.portable_inventory:return true
 var profile=game.local_character
 var garden=game.progress
 if not State.locked(profile.inventory_custody):return true
 var lock: Dictionary=profile.inventory_custody
 if lock.origin!=origin(game) or lock.endpoint!="" or not State.active(garden,profile.identity) or not State.matches(garden.personal_custody[profile.identity],lock):
  return refused(game,"Inventory custody conflicts with this Garden. Recover the original saves.")
 # The expedition owner must finish or explicitly suspend before attempting
 # to transfer the reserve. A saved fight retains its current custody.
 if game.participation.active() or not game.parked_explorers.is_empty() or not garden.suspended_expedition.is_empty():return true
 var saved:=Tx.run_gameplay(game,Tx.Scope.PAIR,func():
  var returned:=State.release(garden,profile.identity)
  var next:=State.accept_return(lock,origin(game),returned)
  if next.is_empty() or not State.close_return(garden,profile.identity,returned):return fail_serializer(garden.path)
  profile.inventory_custody=next
  return true)
 if not Tx.committed(saved.persistence) or saved.value!=true:return refused(game,Tx.feedback_text(game,"Could not return personal inventory."))
 Journal.event("save","inventory_custody_return",{"character":profile.identity,"origin":origin(game),"sequence":lock.sequence})
 return true

static func local_owner(game,player: Dictionary) -> String:
 if game.portable_inventory and Session.peer_for(player)==game.HOST:return game.local_character.identity
 return Session.inventory_owner(player)

static func guest_lock(game,destination: String,endpoint: String,ticket: String) -> bool:
 var profile=game.guest_character
 var state: Dictionary=profile.inventory_custody
 if State.locked(state):
  if state.origin!=destination or state.endpoint=="":return refused(game,"Your inventory is locked to another Garden. Reconnect there before visiting.")
  # A stable Garden origin is the custody key; an address can change.
  if profile.rejoin_ticket.get(endpoint,"")==ticket:return true
  var saved_ticket:=Tx.run_gameplay(game,Tx.Scope.CUSTODY_CONNECTING,func():
   profile.rejoin_ticket[endpoint]=ticket
   return true)
  return Tx.committed(saved_ticket.persistence) and saved_ticket.value==true and game.persistence_session.can_write()
 var next:=State.checkout(state,destination,endpoint)
 if next.is_empty():return refused(game,"Could not establish portable inventory custody.")
 var saved:=Tx.run_gameplay(game,Tx.Scope.CUSTODY_CONNECTING,func():
  profile.inventory_custody=next
  profile.rejoin_ticket[endpoint]=ticket
  return true)
 if not Tx.committed(saved.persistence) or saved.value!=true:return refused(game,Tx.feedback_text(game,"Could not lock personal inventory before visiting."))
 Journal.event("save","inventory_custody_checkout",{"origin":destination,"sequence":next.sequence})
 return game.persistence_session.can_write()

static func request_exit(game,intent: int) -> bool:
 if not game.portable_inventory or game.network_session.role()!="Guest" or game.has_meta(&"custody_disconnected") or not State.locked(game.guest_character.inventory_custody):return false
 if not game.persistence_session.can_write():return false
 var transport: ENetMultiplayerPeer=game.network_session.transport()
 if transport==null or transport.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:return false
 if Participation.is_wild(game.players.get(game.local_player_id(),{})):return false
 game.custody_exit_intent=intent
 game.send_garden_action("custody_return")
 game.status="Returning personal inventory. Waiting for the host's committed receipt."
 return true

static func return_envelope(game,identity: String) -> Dictionary:
 var record: Dictionary=game.progress.personal_custody.get(identity,{})
 if record.get("state")!="returned":return {}
 return {"custody_return":origin(game),"custody_record":record.duplicate(true)}

## A ready participant in the Garden may release their inventory. After
## commitment the binding refuses further gameplay before publishing the receipt.
static func host_release(game,peer: int,expected_binding: int=0) -> void:
 if not game.portable_inventory or not game.persistence_session.can_write():return
 var player: Dictionary=game.players.get(peer,{})
 var id:=Session.identity_for(player)
 if player.is_empty() or id.is_empty() or Session.peer_for(player)!=peer or peer==game.HOST:return
 if Participation.is_wild(player) or game.parked_explorers.has(id) or game.departure_settlement.blocks_admission(id):
  game.tell(peer,"Finish your current expedition settlement before returning personal inventory.");return
 var binding: int=game.network_session.binding(peer)
 if expected_binding>0 and binding!=expected_binding:return
 if not State.active(game.progress,id):
  var repeated:=return_envelope(game,id)
  if not repeated.is_empty():game.receive_character.rpc_id(peer,repeated)
  return
 if not Session.ready_for(player):return
 if player.get("projection_delivery",{}).get("state") not in ["committed","cleanup_pending"]:
  player.custody_release_requested=true
  game.send_committed_profile(peer)
  game.tell(peer,"Waiting for the last character update before returning personal inventory.")
  return
 var saved:=Tx.run_gameplay(game,Tx.Scope.GARDEN,func():
  if State.release(game.progress,id).is_empty():return fail_serializer(game.progress.path)
  return true)
 if not Tx.committed(saved.persistence):
  game.tell(peer,Tx.feedback_text(game,"Your inventory could not be returned. Reconnect to recover it."))
  return
 game.network_session.reject(peer,binding)
 game.PartyTravel.cancel(game,"A participant is returning home.")
 var envelope:=return_envelope(game,id)
 if not envelope.is_empty() and game.network_session.matches(peer,binding):
  game.receive_character.rpc_id(peer,envelope)
 Journal.event("save","inventory_custody_release",{"character":id,"origin":origin(game),"sequence":envelope.get("custody_record",{}).get("sequence",0)})

static func host_release_all(game) -> void:
 # Graceful host closure offers every settled visitor a return. If transport
 # ends before delivery, their receipt remains available at the same Garden.
 for peer: int in game.players.keys():
  if peer!=game.HOST and Session.ready_for(game.players[peer],false):host_release(game,peer)

static func accept_guest_return(game,envelope: Dictionary,connecting: bool) -> bool:
 var profile=game.guest_character
 var destination: Variant=envelope.get("custody_return")
 var record: Variant=envelope.get("custody_record")
 if not destination is String or not record is Dictionary:return false
 var lock: Dictionary=profile.inventory_custody
 var next:=State.accept_return(lock,destination,record)
 if next.is_empty():return false
 if not game.persistence_session.can_write():return false
 var scope:=Tx.Scope.CUSTODY_CONNECTING if connecting else Tx.Scope.GUEST_PROFILE
 var saved:=Tx.run_gameplay(game,scope,func():
  profile.inventory_custody=next
  return true)
 if not Tx.committed(saved.persistence):
  game.status=Tx.feedback_text(game,"Inventory return is unresolved. Reconnect to the same Garden.")
  return false
 game.custody_return_origin=destination
 if connecting or game.custody_exit_intent==Session.Exit.NONE:game.custody_exit_intent=Session.Exit.TITLE
 game.status="Personal inventory returned to your character."
 game.request_garden_action.rpc_id(game.HOST,"custody_ack:%s:%d:%s:%s"%[destination,record.sequence,record.token,record.returned])
 Journal.event("save","inventory_custody_received",{"origin":destination,"sequence":record.sequence})
 # The acknowledgment only compacts the host's already nonspendable receipt.
 # If it is lost, the confirmed home profile is still safe to use.
 var weak: WeakRef=weakref(game)
 game.get_tree().create_timer(1.0).timeout.connect(func():
  var current=weak.get_ref()
  if is_instance_valid(current) and current.custody_return_origin==destination and current.guest_character.inventory_custody.get("state")=="home":
   finish_return(current,current.custody_exit_intent))
 return true

static func host_ack(game,peer: int,action: String) -> void:
 if not game.portable_inventory or not game.persistence_session.can_write():return
 var player: Dictionary=game.players.get(peer,{})
 if player.is_empty() or Session.peer_for(player)!=peer:return
 var id: String=player.get("custody_recovery_identity",Session.identity_for(player))
 var fields:=action.split(":")
 if fields.size()!=5 or fields[1]!=origin(game) or not fields[2].is_valid_int() or not State.hex_id(fields[3],64) or not State.hex_id(fields[4],64):return
 var record: Dictionary=game.progress.personal_custody.get(id,{})
 if record.get("sequence")!=int(fields[2]) or record.get("token")!=fields[3]:return
 if record.get("state")=="returned" and record.returned==fields[4]:
  var saved:=Tx.run_gameplay(game,Tx.Scope.GARDEN,func():return State.close_return(game.progress,id,record))
  if not Tx.committed(saved.persistence) or saved.value!=true:return
 elif record.get("state")!="closed":return
 # Publish only an acknowledgment, never another inventory payload.
 var reply: Dictionary={"custody_acknowledged":fields[1],"sequence":int(fields[2])}
 if player.has("custody_recovery_identity"):game.connection_accepted.rpc_id(peer,reply)
 else:game.receive_character.rpc_id(peer,reply)

static func finish_return(game,intent: int) -> void:
 if not is_instance_valid(game) or game.returning_to_title:return
 if intent==Session.Exit.APPLICATION:
  game.persistence_session.begin_shutdown()
  game.session_world.offline()
  game.release_slot()
  game.get_tree().quit()
 else:game.return_to_main_menu("Personal inventory returned to your character.")
