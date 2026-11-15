extends RefCounted
# Host-derived presentation state. Never stored in character/Garden saves.
const Warden = preload("res://warden_combat.gd")
const LABELS={"subclass_follow_ready":"Follow-up ready","warden_quake_ready":"Quake prepared","slow":"Slowed","guard":"Warded","counter":"Counter ready","prepared_mark":"Mark ready","grave":"Death charge","echo":"Echo charge","marked":"Marked","core_strike_mark":"Core Mark","crown_link":"Crownlink","brittle":"Brittle","burning":"Burning","bleeding":"Bleeding","thorn_slow":"Thorn growth","drenched":"Drenched","vitality":"Vitality","bark_armor":"Bark Armor","rooted":"Rooted","staggered":"Staggered","haste":"Hastened","bark_guard":"Bark Guard","sheltered":"Sheltered","trophy_carrier":"Carrying trophy","rallied":"Rallied","uprooting":"Uprooting","core_exposed":"Core exposed","nursery_lull":"Nursery lull","memory_exposed":"Memory exposed"}
const REFRESH_IN_PLACE := ["grave","echo","sheltered","trophy_carrier","subclass_follow_ready","burning","drenched","vitality","bark_armor","bleeding","thorn_slow"]
static func tint(kind: String) -> Color:
 if kind=="burning":return Color("#f29b57")
 if kind=="drenched":return Color("#82d7ec")
 return Color("#e6c079") if kind in ["guard","counter","grave","bark_guard","sheltered","trophy_carrier","cast_break"] else Color("#d8a2ed") if kind in ["marked","prepared_mark","echo","mark_break","core_strike_mark"] else Color("#95d7ed") if kind in ["brittle","slow","shatter"] else Color("#a6d695")
static func add(result: Dictionary,game: Node,kind: String,owner: int,enemy: bool,until: int,stacks: int,now: int) -> void:
 if until<=now or stacks<=0:return
 var token:=int(game.scouts[owner].get("spawn_token",0)) if enemy and owner>=0 else int(game.combat_epoch)
 var key: String="%s:%d:%d:%s"%[str(enemy),owner,token,kind]
 result[key]={"kind":kind,"owner":owner,"enemy":enemy,"until":until,"stacks":stacks,"token":token}
static func sync(game: Node,now: int) -> void:
 if not game.multiplayer.is_server() or game.SaveBatch.active:return
 var desired: Dictionary={}
 for id in game.players:
  var player: Dictionary=game.players[id]
  if player.has("affinity_ward_claims") and (int(player.get("guard_until",0))<=now or int(player.get("guard_charges",0))<=0):
   player.erase("affinity_ward_claims")
  if not game.Life.alive(player) or not player.get("wild",false):continue
  if player.has("affinity_vital_sources"):add(desired,game,"vitality",id,false,now+60000,1,now)
  if player.has("affinity_bark_grants"):add(desired,game,"bark_armor",id,false,now+60000,1,now)
  for pair in [["slow","slow_until"],["guard","guard_until"],["counter","counter_until"],["prepared_mark","prepared_mark_until"]]:
   add(desired,game,pair[0],id,false,int(player.get(pair[1],0)),1,now)
  if int(player.get("frame",-1))==0:
   add(desired,game,"warden_quake_ready",id,false,Warden.prepared_until(game,player,now),1,now)
  elif preload("res://subclass_combat.gd").follow_lane(game,player)>=0:
   add(desired,game,"subclass_follow_ready",id,false,now+60000,1,now)
  for pair in [["grave","grave_charges"],["echo","echo_charge"]]:
   add(desired,game,pair[0],id,false,now+60000,int(player.get(pair[1],0)),now)
 for target in range(-1,game.scouts.size()):
  if not game.expedition_active() or not game.Traits.valid_target(game,target):continue
  var state: Dictionary=game.enemy_traits if target==-1 else game.scouts[target].get("traits",{})
  add(desired,game,"marked",target,true,int(state.get("marked_until",0)),1,now)
  var core_mark:=preload("res://core_strike_mark.gd").active(game,state,now)
  add(desired,game,"crown_link" if core_mark.has("partner") else "marked" if core_mark.get("subclass",false) else "core_strike_mark",target,true,int(core_mark.get("until",0)),1,now)
  var root_until: int = game.rooted_until if target==-1 else int(game.scouts[target].get("rooted_until",0))
  if game.has_meta(&"combat_affinity_ruleset"):
   var frost = preload("res://frost_combat.gd")
   var body := frost.body(game,target)
   var brittle := frost.state(body,now)
   add(desired,game,"brittle",target,true,int(brittle.get("expires",0)),brittle.get("stacks",[]).size(),now)
   if not body.get("affinity_burning",{}).is_empty():add(desired,game,"burning",target,true,now+60000,1,now)
   if not body.get("affinity_bleed",{}).is_empty():add(desired,game,"bleeding",target,true,now+60000,1,now)
   if body.has("affinity_thorn_slow"):add(desired,game,"thorn_slow",target,true,now+60000,1,now)
   var elapsed: int=preload("res://affinity_time.gd").now(game)
   if preload("res://water_combat.gd").reduction(body,elapsed)>0.0:add(desired,game,"drenched",target,true,now+60000,1,now)
   root_until=maxi(root_until,int(body.get("frost_root_until",0)))
  else:
   add(desired,game,"brittle",target,true,int(state.get("brittle_until",0)),int(state.get("brittle",0)),now)
  add(desired,game,"rooted",target,true,root_until,1,now)
  add(desired,game,"staggered",target,true,game.enemy_stagger_until if target==-1 else int(game.scouts[target].get("stagger_until",0)),1,now)
  add(desired,game,"haste",target,true,game.enemy_haste_until if target==-1 else int(game.scouts[target].get("haste_until",0)),1,now)
  var actor: Dictionary=game.scouts[target] if target>=0 else game.leader_brain.get("elite",{})
  var point: Vector3=game.enemy_position(target)
  var support=preload("res://enemy_support.gd")
  var cover: Dictionary=support.shelter_source(game,target,point,point+Vector3.RIGHT,now,true)
  if not cover.is_empty():add(desired,game,"sheltered",target,true,now+60000,1,now)
  if not actor.get("stolen",[]).is_empty():add(desired,game,"trophy_carrier",target,true,now+60000,1,now)
  var command: Dictionary=game.leader_brain if target<0 else actor
  add(desired,game,"rallied",target,true,int(command.get("command_until",0)),1,now)
  if target==-1:
   var open: Dictionary=game.leader_brain.get("lair_open",{})
   if not open.is_empty():add(desired,game,open.kind,target,true,int(open.until),1,now)
  if actor.get("attack",{}).get("variant","")=="bark_guard":
   var until: int=int(actor.windup) if target>=0 else game.enemy_strike_at if game.enemy_winding_up else 0
   add(desired,game,"bark_guard",target,true,until,1,now)
 var epoch:=str(game.combat_epoch)
 var previous: Dictionary=game.get_meta("status_feedback",{}) if str(game.get_meta("status_epoch",""))==epoch else {}
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
 if str(game.get_meta("status_epoch",""))!=str(game.combat_epoch):return result
 for item in game.get_meta("status_feedback",{}).values():
  if now>=int(item.until):continue
  var event: Dictionary=item.event.duplicate(true)
  event.age=maxf(0,(now-int(event.born))/1000.0);event.erase("born");result.append(event)
 return result
static func proc(game: Node,kind: String,from: Vector3,to: Vector3,target: int=-2,reach: float=0.0) -> void:
 var height:=1.8+preload("res://enemy_hurtbox.gd").radius(game,target) if kind=="mark_break" and target>=-1 else .85
 game.emit_combat_event("proc",kind,from,to,.55,tint(kind),reach,target,{"height":height})


static func root(game: Node, target: int, until: int) -> void:
 preload("res://wilds_skill_tactics.gd").root_denied(game,target,Time.get_ticks_msec())
 if target == -1:
  game.rooted_until = maxi(game.rooted_until, until)
 else:
  game.scouts[target].rooted_until = maxi(int(game.scouts[target].rooted_until), until)
