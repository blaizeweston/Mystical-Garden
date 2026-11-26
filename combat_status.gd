extends RefCounted
const Effects = preload("res://enemy_affinity_effects.gd")
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const Participation = preload("res://expedition_participation.gd")
# Host-derived presentation state. Never stored in character/Garden saves.
const Fire = preload("res://fire_combat.gd")
const Water = preload("res://water_combat.gd")
# Display-only numeric values coalesce at the existing detail cadence.
const SHARED_DISPLAY_MS := 250
const Warden = preload("res://warden_combat.gd")
const Ranger = preload("res://ranger_combat.gd")
const Reaper = preload("res://reaper_combat.gd")
const Oracle = preload("res://oracle_combat.gd")
const LABELS={"oracle_foreboding":"Foreboding","oracle_guided_strike":"Guided Strike","oracle_second_breath":"Second Breath","oracle_quiet_ground":"Quiet Ground","oracle_mercy":"Portent of Mercy","oracle_ritual_verdict":"Ritual Verdict ready","oracle_chime_prepared":"Chime prepared","reaper_veil_momentum":"Veil Momentum","reaper_siphon_prepared":"Siphon Cut prepared","ranger_tracked_prey":"Tracked Prey","ranger_follow_through":"Follow-Through ready","ranger_double_draw":"Double Draw ready","spirit_stride":"Spiritstride","spirit_prepared":"Spirit follow-up prepared","spirit_ready":"Spirit follow-up ready","storm_charge":"Storm Charge","subclass_follow_ready":"Follow-up ready","warden_quake_ready":"Quake prepared","holdfast":"Holdfast","protective_filaments":"Protective Filaments","slow":"Slowed","guard":"Warded","counter":"Counter ready","prepared_mark":"Mark ready","grave":"Death charge","echo":"Echo charge","marked":"Marked","core_strike_mark":"Core Mark","crown_link":"Crownlink","brittle":"Brittle","burning":"Burning","bleeding":"Bleeding","thorn_slow":"Thorn growth","drenched":"Drenched","vitality":"Vitality","bark_armor":"Bark Armor","rooted":"Rooted","staggered":"Staggered","haste":"Hastened","bark_guard":"Bark Guard","sheltered":"Sheltered","trophy_carrier":"Carrying trophy","rallied":"Rallied","uprooting":"Uprooting","core_exposed":"Core exposed","nursery_lull":"Nursery lull","memory_exposed":"Memory exposed"}
const REFRESH_IN_PLACE := ["spirit_stride","spirit_prepared","spirit_ready","storm_charge","grave","echo","sheltered","trophy_carrier","subclass_follow_ready","reaper_siphon_prepared","oracle_chime_prepared","burning","drenched","vitality","bark_armor","bleeding","thorn_slow"]
static func affinity_feedback(game: Node, player: Dictionary) -> String:
 var elapsed:=preload("res://affinity_time.gd").now(game)
 var lines: PackedStringArray=[]
 var charge: Dictionary=player.get("affinity_storm_charge",{})
 if int(charge.get("until",0))>elapsed:
  lines.append("Storm Charge %.1fs"%((int(charge.until)-elapsed)/1000.0))
 var follow: Dictionary=player.get("affinity_spirit_follow",{})
 if int(follow.get("until",0))>elapsed:
  var phase: String=follow.phase
  lines.append("Spirit follow-up %s · %.1fs"%[phase,(int(follow.until)-elapsed)/1000.0])
 return "  ·  ".join(lines)
static func tint(kind: String) -> Color:
 if kind==Ranger.PREY:return Ranger.PREY_COLOR
 if kind==Oracle.Progression.FOREBODING:return Color("#c899eb")
 if kind.begins_with("oracle_"):return Color("#ead68d")
 if kind=="burning":return Color("#f29b57")
 if kind=="drenched":return Color("#82d7ec")
 return Color("#e6c079") if kind in ["guard","counter","grave","bark_guard","sheltered","trophy_carrier","cast_break"] else Color("#d8a2ed") if kind in ["marked","prepared_mark","echo","mark_break","core_strike_mark"] else Color("#95d7ed") if kind in ["brittle","slow","shatter"] else Color("#a6d695")
static func add(result: Dictionary,game: Node,kind: String,owner: int,enemy: bool,until: int,stacks: int,now: int) -> void:
 if until<=now or stacks<0 or (stacks==0 and kind!="drenched"):return
 var token: int=game.encounter.token(owner) if enemy and owner>=0 else int(game.participation.epoch())
 var key: String="%s:%d:%d:%s"%[str(enemy),owner,token,kind]
 result[key]={"kind":kind,"owner":owner,"enemy":enemy,"until":until,"stacks":stacks,"token":token}
static func sync(game: Node,now: int) -> void:
 if not game.multiplayer.is_server() or game.SaveBatch.active:return
 var desired: Dictionary={}
 for id in game.players:
  var player: Dictionary=game.players[id]
  player[Protection.STATE] = player[Protection.STATE].expire_claims(now)
  if not game.Life.alive(player) or not Participation.is_wild(player):continue
  if player.has(Oracle.Omens.STATE):
   var omens:=Oracle.Omens.indicators(game,player,now)
   for omen in omens: add(desired,game,omen,id,false,int(omens[omen]),1,now)
  if player.has(Oracle.RITUAL):
   add(desired,game,Oracle.RITUAL,id,false,Oracle.prepared_until(game,player,Oracle.RITUAL,now),1,now)
  if player.has(Oracle.CHIME) and Oracle.prepared_until(game,player,Oracle.CHIME,now)>0:
   add(desired,game,Oracle.CHIME,id,false,now+60000,1,now)
  if player.has("affinity_vital_sources"):add(desired,game,"vitality",id,false,now+60000,1,now)
  var charge: Dictionary=player.get("affinity_storm_charge",{})
  if not charge.is_empty():
   var remaining: int=int(charge.until)-preload("res://affinity_time.gd").now(game)
   add(desired,game,"storm_charge",id,false,now+remaining,1,now)
  var spirit = preload("res://spirit_affinity.gd")
  var follow: Dictionary=player.get(spirit.FOLLOW,{})
  if not follow.is_empty() or player.has(spirit.STRIDES):
   var elapsed: int=preload("res://affinity_time.gd").now(game)
   if not follow.is_empty() and follow.phase!="claimed":
    add(desired,game,"spirit_"+str(follow.phase),id,false,now+int(follow.until)-elapsed,1,now)
   if spirit.scale(player,elapsed)>1.0:
    add(desired,game,"spirit_stride",id,false,now+60000,1,now)
  if player.has("affinity_bark_grants"):
   var wood=preload("res://wood_affinity.gd")
   var remaining:int=wood.capacity(wood.live_grants(player,preload("res://affinity_time.gd").now(game)))
   if remaining>0:add(desired,game,"bark_armor",id,false,now+60000,remaining,now)
  add(desired,game,"holdfast",id,false,Warden.holdfast_until(game,player,now),1,now)
  add(desired,game,"protective_filaments",id,false,preload("res://weaver_combat.gd").filaments_until(game,player,now),1,now)
  add(desired,game,"slow",id,false,player[Conditions.STATE].slow_until_ms(),1,now)
  add(desired,game,"guard",id,false,player[Protection.STATE].guard_until_ms(),1,now)
  add(desired,game,"counter",id,false,player[Protection.STATE].counter_until_ms(),1,now)
  if int(player.get("frame",-1))==0:
   add(desired,game,"warden_quake_ready",id,false,Warden.prepared_until(game,player,now),1,now)
  elif preload("res://subclass_combat.gd").follow_lane(game,player)>=0:
   add(desired,game,"subclass_follow_ready",id,false,now+60000,1,now)
  if player.has(Reaper.MOMENTUM):
   var momentum := Reaper.ready(game,player,Reaper.MOMENTUM,now)
   add(desired,game,Reaper.MOMENTUM,id,false,int(momentum.get("until",0)),1,now)
  if player.has(Reaper.SIPHON) and not Reaper.ready(game,player,Reaper.SIPHON,now).is_empty():
   add(desired,game,Reaper.SIPHON,id,false,now+60000,1,now)
  for preparation in [Ranger.FOLLOW,Ranger.DOUBLE]:
   if player.has(preparation):
    add(desired,game,preparation,id,false,Ranger.prepared_until(game,player,preparation,now),1,now)
  var grafts = preload("res://native_grafts.gd")
  var grave_charges := int(player.get("grave_charges",0)) + grafts.graft_charges(player)
  add(desired,game,"grave",id,false,now+60000,grave_charges,now)
  var echo_charge := int(grafts.counters(player,"monster:glasscap").get("echo_charge",0))
  add(desired,game,"echo",id,false,now+60000,echo_charge,now)
 for target in range(-1,game.encounter.scout_count()):
  if not game.participation.active() or not game.Traits.valid_target(game,target):continue
  var omen_target:=Oracle.Omens.enemy_body(game,target)
  if omen_target.has(Oracle.Omens.STATE):
   var omens:=Oracle.Omens.indicators(game,omen_target,now)
   for omen in omens: add(desired,game,omen,target,true,int(omens[omen]),1,now)
  var state: Dictionary=game.enemy_traits if target==-1 else game.encounter.scout(target).get("traits",{})
  if state.has(Ranger.PREY):
   var prey := Ranger.active_prey(game,state,now)
   add(desired,game,Ranger.PREY,target,true,int(prey.get("until",0)),1,now)
  var root_until: int = game.tactics.rooted_until if target==-1 else int(game.encounter.scout(target).get("rooted_until",0))
  var frost = preload("res://frost_combat.gd")
  var body := Effects.read(game,target)
  var brittle := frost.active_brittle(body,now)
  add(desired,game,"brittle",target,true,int(brittle.get("expires",0)),brittle.get("stacks",[]).size(),now)
  if not body.get("affinity_burning",{}).is_empty():add(desired,game,"burning",target,true,now+60000,Fire.count(body[Fire.BURNING]),now)
  if not body.get("affinity_bleed",{}).is_empty():add(desired,game,"bleeding",target,true,now+60000,1,now)
  if body.has("affinity_thorn_slow"):add(desired,game,"thorn_slow",target,true,now+60000,1,now)
  var elapsed: int=preload("res://affinity_time.gd").now(game)
  if Water.reduction(body.get(Water.DRENCHED,{}),elapsed)>0.0:add(desired,game,"drenched",target,true,now+60000,int(body[Water.DRENCHED].saturation),now)
  root_until=maxi(root_until,int(body.get("frost_root_until",0)))
  add(desired,game,"rooted",target,true,root_until,1,now)
  add(desired,game,"staggered",target,true,game.tactics.stagger_until if target==-1 else int(game.encounter.scout(target).get("stagger_until",0)),1,now)
  add(desired,game,"haste",target,true,game.tactics.haste_until if target==-1 else int(game.encounter.scout(target).get("haste_until",0)),1,now)
  var actor: Dictionary=game.encounter.scout(target) if target>=0 else game.encounter.leader_tactics()
  var point: Vector3=game.enemy_position(target)
  var support=preload("res://enemy_support.gd")
  var cover: Dictionary=support.shelter_source(game,target,point,point+Vector3.RIGHT,now,true)
  if not cover.is_empty():add(desired,game,"sheltered",target,true,now+60000,1,now)
  if not actor.get("stolen",[]).is_empty():add(desired,game,"trophy_carrier",target,true,now+60000,1,now)
  var command: Dictionary=game.tactics.memory if target<0 else actor
  add(desired,game,"rallied",target,true,int(command.get("command_until",0)),1,now)
  if target==-1:
   var open: Dictionary=game.tactics.memory.get("lair_open",{})
   if not open.is_empty():add(desired,game,open.kind,target,true,int(open.until),1,now)
  if actor.get("attack",{}).get("variant","")=="bark_guard":
   var until: int=int(actor.windup) if target>=0 else game.tactics.strike_at if game.tactics.winding_up else 0
   add(desired,game,"bark_guard",target,true,until,1,now)
 var epoch:=str(game.participation.epoch())
 var previous: Dictionary=game.get_meta("status_feedback",{}) if str(game.get_meta("status_epoch",""))==epoch else {}
 # Only the projection is delayed; combat status amounts/cadence stay authoritative.
 for key in desired:
  if previous.has(key) and desired[key].kind in ["burning","drenched"] and now-int(previous[key].event.born)<SHARED_DISPLAY_MS:
   desired[key].stacks=previous[key].stacks
 for key in previous:
  if not desired.has(key) or desired[key].stacks!=previous[key].stacks or (desired[key].kind not in REFRESH_IN_PLACE and desired[key].until!=previous[key].until) or now-int(previous[key].event.born)>=55000:
   game.emit_combat_event("status_end",str(previous[key].event.id),Vector3.ZERO,Vector3.ZERO,.3,Color.WHITE,0,0)
 for key in desired:
  var item: Dictionary=desired[key]
  if previous.has(key) and item.stacks==previous[key].stacks and ((item.kind in REFRESH_IN_PLACE and now-int(previous[key].event.born)<55000) or item.until==previous[key].until):
   item.event=previous[key].event
   continue
  var at: Vector3=game.enemy_position(item.owner) if item.enemy else game.players[item.owner].pos
  var height:=1.8+preload("res://enemy_hurtbox.gd").radius(game,item.owner) if item.enemy else 2.35
  if item.kind in ["uprooting","core_exposed","nursery_lull","memory_exposed"]:height=maxf(height,4.55)
  game.emit_combat_event("status",item.kind,at,at,maxf(.1,(item.until-now)/1000.0),tint(item.kind),item.stacks,item.owner,{"form":"enemy" if item.enemy else "player","height":height,"target_token":item.token})
  item.event=game.combat_events.back().duplicate(true)
 game.set_meta("status_feedback",desired);game.set_meta("status_epoch",epoch)
static func snapshot(game: Node,now: int) -> Array:
 var result: Array=[]
 if str(game.get_meta("status_epoch",""))!=str(game.participation.epoch()):return result
 for item in game.get_meta("status_feedback",{}).values():
  if now>=int(item.until):continue
  var event: Dictionary=item.event.duplicate(true)
  event.age=maxf(0,(now-int(event.born))/1000.0);event.erase("born");result.append(event)
 return result
static func proc(game: Node,kind: String,from: Vector3,to: Vector3,target: int=-2,reach: float=0.0,source: String="") -> void:
 var height:=1.8+preload("res://enemy_hurtbox.gd").radius(game,target) if kind=="mark_break" and target>=-1 else .85
 var art:={"height":height}
 if not source.is_empty():art.form=source
 game.emit_combat_event("proc",kind,from,to,.55,tint(kind),reach,target,art)


static func root(game: Node, target: int, until: int) -> void:
 preload("res://wilds_skill_tactics.gd").root_denied(game,target,preload("res://combat_clock.gd").now())
 if target == -1:
  game.tactics.rooted_until = maxi(game.tactics.rooted_until, until)
 else:
  game.encounter.scout(target).rooted_until = maxi(int(game.encounter.scout(target).rooted_until), until)
