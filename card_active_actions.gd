extends RefCounted
## Card-granted instant actions use the existing reliable action RPC and combat resolver.
## This is not a second card ledger: acquisition remains in AffinityCards.
const Catalog = preload("res://affinity_card_catalog.gd")
const Cards = preload("res://affinity_cards.gd")
const Core = preload("res://core_combat.gd")
const Session = preload("res://network_session.gd")
const PREFIX := "card_cast:"
const STATE := "card_active_state"
const INPUTS := ["card_active_one","card_active_two","card_active_three","card_active_four"]
const CARD_GRANTS := {"bloodletting_unlock":{"method":"command","capability":{"producer":"card","id":"bloodletting","recipient":"enemy"}}}
static var _request_serial := 0

static func actions(player: Dictionary) -> Array[String]:
 var result: Array[String]=[]
 var ledger=Cards.ledger(player)
 if ledger==null:return result
 for copy in ledger.copies():
  if Catalog.DEFINITIONS[copy.id].get("active",false) and not result.has(copy.id):result.append(copy.id)
 return result

static func request(game: Node, player: Dictionary, id: String, aim: Vector2, sequence := 0) -> String:
 var stamp:=Core.cast_key(game,player)
 if stamp.is_empty():return ""
 if sequence==0:
  _request_serial=maxi(_request_serial+1,Time.get_ticks_usec())
  sequence=_request_serial
 return PREFIX+"%s:%s:%d:%s:%s" % [stamp,id,sequence,aim.x,aim.y]

static func input_event(game: Node, event: InputEvent) -> bool:
 if not event.is_pressed() or event.is_echo():return false
 var player: Dictionary=game.players.get(game.multiplayer.get_unique_id(),{})
 if not preload("res://ability_aim.gd").available(game,player,0):return false
 var rows: Array=owner_state(game,player) if game.multiplayer.is_server() else player.get("card_actions_state",[])
 for index in INPUTS.size():
  if not event.is_action_pressed(INPUTS[index]):continue
  if index<rows.size():
   var aim:=Core.local_aim(game,player)
   game.send_garden_action(request(game,player,rows[index].id,aim.direction))
  return true
 return false

static func command(game: Node, peer: int, player: Dictionary, action: String) -> void:
 if not game.multiplayer.is_server() or not game.Life.alive(player) or game.encounter_cleared() or game.persistence_session.is_blocked() or not game.network_session.ready(peer) or Session.peer_for(player)!=peer:return
 var fields:=action.split(":")
 var stamp:=Core.cast_key(game,player)
 if fields.size()!=6 or stamp.is_empty() or fields[1]!=stamp or not fields[3].is_valid_int() or not fields[4].is_valid_float() or not fields[5].is_valid_float():return
 var id: String=fields[2]
 if not actions(player).has(id):return
 var definition: Dictionary=Catalog.DEFINITIONS[id]
 if not Cards.Ledger.requirement(definition,game.combat_build(player).affinity_build()).is_empty():return
 var sequence:=int(fields[3])
 var aim:=Vector2(float(fields[4]),float(fields[5]))
 if sequence<=0 or not aim.is_finite() or aim.length_squared()<.01 or absf(aim.x)>1.001 or absf(aim.y)>1.001:return
 var prior: Dictionary=player.get(STATE,{})
 var state: Dictionary=prior.duplicate(true) if prior.get("stamp")==stamp else {"stamp":stamp,"actions":{}}
 var ready: Dictionary=state.actions.get(id,{})
 var now:=preload("res://combat_clock.gd").now()
 if sequence<=int(ready.get("sequence",0)) or now<int(ready.get("ready",0)):return
 if id!="bloodletting":return # Future active cards require an implemented dispatch.
 var thorn=load("res://thorn_affinity.gd")
 var tuning: Dictionary=definition.tuning
 var forward:=Vector3(aim.x,0,aim.y).normalized()
 var target:=-2
 var best:=-INF
 for victim in range(-1,game.encounter.scout_count()):
  if not game.encounter.alive(victim):continue
  var point: Vector3=game.enemy_position(victim)
  var offset: Vector3=point-player.pos
  if offset.length()>float(tuning.range_m) or not game.battlefield.combat_sight(player.pos,point):continue
  var body: Dictionary=load("res://frost_combat.gd").body(game,victim)
  var bleed: Dictionary=body.get(thorn.BLEED,{})
  if bleed.is_empty():continue
  thorn.prune(game,bleed,load("res://affinity_time.gd").now(game))
  if thorn.potency_units(bleed)<=0:continue
  var dot:=offset.normalized().dot(forward) if offset.length()>.001 else 1.0
  if dot<float(tuning.min_aim_dot):continue
  var score:=dot*100.0-offset.length()
  if score>best:best=score;target=victim
 if target== -2:return
 var bleed: Dictionary=load("res://frost_combat.gd").body(game,target)[thorn.BLEED]
 var hp:=roundi(float(thorn.potency_units(bleed))*float(tuning.damage_percent)/(100.0*thorn.Sources.UNITS_PER_HP))
 if hp<=0:return
 state.actions[id]={"sequence":sequence,"ready":now+int(tuning.cooldown_ms)}
 player[STATE]=state # Claim before damage/death callbacks; rollback snapshots this dictionary.
 var point: Vector3=game.enemy_position(target)
 game.emit_combat_event("ability",id,player.pos,point,.5,thorn.COLOR,0.3,peer,{"label":definition.title})
 load("res://outgoing_hits.gd").affinity_world(game,peer,target,hp,now,thorn.COLOR,true)
 preload("res://diagnostic_journal.gd").event("combat","card_active_cast",{"actor":peer,"card":id,"target":target,"hp":hp,"sequence":sequence})
 if game.encounter_cleared():game.finish_combat(peer,point)

static func owner_state(game: Node, player: Dictionary) -> Array:
 var result:=[]
 var stamp:=Core.cast_key(game,player)
 if stamp.is_empty():return result
 var state: Dictionary=player.get(STATE,{})
 var now:=preload("res://combat_clock.gd").now()
 for id in actions(player):
  var definition: Dictionary=Catalog.DEFINITIONS[id]
  var ready:=0 if state.get("stamp")!=stamp else int(state.get("actions",{}).get(id,{}).get("ready",0))
  result.append({"id":id,"name":definition.title,"remaining":maxf(0,(ready-now)/1000.0),"tooltip":definition.detail})
 return result

static func hud_state(game: Node, player: Dictionary) -> Array:
 if game.multiplayer.is_server():return owner_state(game,player)
 if game.guest_replication.details_key()!=str([game.participation.route(),game.participation.floor(),game.participation.seed()]):return []
 var result: Array=player.get("card_actions_state",[]).duplicate(true)
 var age: float=game.guest_replication.details_age_ms(preload("res://combat_clock.gd").now())/1000.0
 for row in result:row.remaining=maxf(0,float(row.remaining)-age)
 return result
