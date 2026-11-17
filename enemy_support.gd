extends RefCounted
## Host-owned support intent. References use spawn tokens so a recycled slot cannot inherit a cast.
const Catalog = preload("res://enemy_catalog.gd")
const Geometry = preload("res://attack_geometry.gd")
const Tactics = preload("res://wilds_skill_tactics.gd")
const Feedback = preload("res://enemy_move_feedback.gd")
const CANOPY_SPAN := 2.7
const CHOIR_SPAN := 2.05
const INTERRUPTIBLE := ["corpse_tether", "brood", "chant", "shepherd", "choir", "lure", "trophy_grab"]

static func interruptible(attack: Dictionary) -> bool:
 return str(attack.get("role","")) in INTERRUPTIBLE or (attack.get("mode","")=="shepherd" and (attack.get("variant")==Tactics.ANTIPHON or attack.get("cue","") in ["Split chorus","Second beat"]))

static func visible_allies(game: Node, actor: Dictionary, origin: Vector3, radius: float) -> Array:
 var result: Array=[]
 for entry in load("res://enemy_formation.gd").allies(game, actor):
  if origin.distance_to(entry.pos)>radius or not game.battlefield.clear_line(origin,entry.pos):continue
  var slot: int=entry.index
  var token: int=game.combat_epoch if slot<0 else game.encounter.token(slot)
  result.append({"slot":slot,"token":token,"point":entry.pos})
 return result

static func live_ally(game: Node, ref: Dictionary) -> bool:
 var slot: int=ref.slot
 if slot<0:return game.encounter.hp(-1)>0 and ref.token==game.combat_epoch
 return game.encounter.alive(slot,ref.token)

static func lock_rite_anchor(attack: Dictionary, anchor: Dictionary, response: String, radius: float) -> void:
 attack.rite_anchor=anchor
 attack.variant=response
 attack.cue=Tactics.RESPONSES[response].cue
 attack.radius=radius

static func anchored_rite_intact(game: Node, actor: Dictionary, ref: Dictionary) -> bool:
 if not live_ally(game,ref):return false
 var position: Vector3=game.enemy_position(ref.slot)
 var reach:=Catalog.radius(int(actor.kind),int(actor.mutations))
 return position.distance_squared_to(ref.point)<=.64 and position.distance_to(actor.pos)<=reach and game.battlefield.clear_line(actor.pos,position)

static func corpse(game: Node, actor: Dictionary, radius: float, exclude: int=-1) -> Dictionary:
 var origin: Vector3=actor.pos
 var best:=radius
 var result: Dictionary={}
 for slot in game.encounter.scout_count():
  var dead: Dictionary=game.encounter.scout(slot)
  var token: int=game.encounter.token(slot)
  if game.encounter.hp(slot)>0 or dead.get("escaped",false) or dead.get("summoned",false) or token==exclude or actor.get("consumed_corpses",[]).has(token):continue
  var distance:=origin.distance_to(dead.pos)
  if distance>best or not game.battlefield.clear_line(origin,dead.pos):continue
  best=distance
  result={"token":token,"point":dead.pos}
 return result

static func tether_target(game: Node, actor: Dictionary) -> Dictionary:
 if actor.has("disrupted_corpse") and Tactics.retry_available(game,actor,Tactics.SPARE_TETHER):
  var spare:=corpse(game,actor,7.0,int(actor.disrupted_corpse))
  if not spare.is_empty():return {"ref":spare,"response":Tactics.SPARE_TETHER,"cue":Tactics.RESPONSES[Tactics.SPARE_TETHER].cue}
 var prey:=corpse(game,actor,5.0)
 if prey.is_empty() and actor.get("variant","")=="long_tether":
  return {"ref":corpse(game,actor,7.0),"response":"","cue":"Long tether"}
 return {"ref":prey,"response":"","cue":"Corpse tether"}

static func brood_sites(game: Node, origin: Vector3, count: int) -> Array[Vector3]:
 var result: Array[Vector3]=[]
 for offset in [Vector3(1.9,0,.8),Vector3(-1.9,0,.8),Vector3(0,0,-2.3),Vector3(0,0,2.3)]:
  var at: Vector3=origin+offset
  if not game.battlefield.clear_line(origin,at,.45) or not hatch_safe(game,at):continue
  result.append(at)
  if result.size()>=count:break
 return result

static func scattered_sites(game: Node, origin: Vector3) -> Array[Vector3]:
 for axis in [Vector3.RIGHT, Vector3.FORWARD, Vector3(1,0,1).normalized(), Vector3(1,0,-1).normalized()]:
  var first: Vector3=origin+axis*3.35
  var second: Vector3=origin-axis*3.35
  if game.battlefield.clear_line(origin,first,.45) and game.battlefield.clear_line(origin,second,.45) and hatch_safe(game,first) and hatch_safe(game,second):
   return [first,second]
 return []

static func hatch_safe(game: Node, at: Vector3) -> bool:
 if game.battlefield.occupied(at,.4):return false
 var nearby: int=game.nearest_wild_player(at)
 if nearby!=0 and game.players[nearby].pos.distance_to(at)<1.5:return false
 for slot in game.encounter.scout_count():
  if game.encounter.hp(slot)>0 and game.encounter.position(slot).distance_to(at)<1.1:return false
 return true

static func shelter_source(game: Node, target: int, at: Vector3, from: Vector3, now: int, coverage_only: bool=false) -> Dictionary:
 if game.encounter.hp(-1)>0 and target!=-1 and game.enemy_kind==11:
  var leader: Dictionary=game.encounter.leader_tactics()
  if covers(game,leader,game.tactics.position,at,from,now,coverage_only):return {"actor":-1}
 for index in game.encounter.scout_count():
  var grazer: Dictionary=game.encounter.scout(index)
  if index==target or game.encounter.hp(index)<=0 or int(grazer.kind)!=11:continue
  if covers(game,grazer,grazer.pos,at,from,now,coverage_only):return {"actor":index}
 return {}

static func observe_shelter_break(game: Node, target: int, before: Vector3, after: Vector3, now: int) -> void:
 if not game.multiplayer.is_server() or before.distance_squared_to(after)<.55*.55:return
 var cover:=shelter_source(game,target,before,before,now,true)
 if cover.is_empty():return
 var slot: int=cover.actor
 var grazer: Dictionary=game.encounter.leader_tactics() if slot<0 else game.encounter.scout(slot)
 if grazer.is_empty() or grazer.get("summoned",false) or grazer.get("shelter_break_epoch",-1)==game.combat_epoch:return
 var origin: Vector3=game.enemy_position(slot)
 if covers(game,grazer,origin,after,after,now,true):return
 var token: int=game.combat_epoch if target<0 else game.encounter.token(target)
 grazer.shelter_break_epoch=game.combat_epoch
 grazer.shelter_escort={"slot":target,"token":token,"point":after}
 Tactics.record(game,Tactics.SHELTER_BREAK,{"species":Catalog.get_kind(11).id,"target_token":game.encounter.token_for(grazer),"escort_token":token})
 game.emit_combat_event("proc","shelter_broken",before,after,.55,Color("#f0cb97"),0,target)

static func covers(game: Node, actor: Dictionary, origin: Vector3, at: Vector3, from: Vector3, now: int, coverage_only: bool) -> bool:
 var planted: Dictionary=actor.get("attack",{})
 var directional: bool=planted.get("variant","")=="planted_canopy" and int(actor.get("windup",0))>now
 var center: Vector3=planted.from if directional else origin
 var radius:=float(Catalog.get_kind(11).shelter_radius)
 if center.distance_to(at)>radius or not game.battlefield.clear_line(center,at):return false
 if not directional:return true
 var forward: Vector3=(Vector3(planted.face)-center).normalized()
 var limit:=cos(CANOPY_SPAN*.5)
 return (coverage_only or forward.dot((from-center).normalized())>=limit) and (at.distance_to(center)<.1 or forward.dot((at-center).normalized())>=limit)

static func decorate_plan(game: Node, actor: Dictionary, attack: Dictionary, target: Vector3) -> void:
 var origin: Vector3=attack.from
 match int(actor.kind):
  3:
   if attack.mode=="chant":
    attack.cue="Covered bell" if actor.get("covered_once",false) and not actor.get("covered_cast",false) else "Haste"
    var allies:=visible_allies(game,actor,origin,attack.radius)
    attack.rite_has_ally=not allies.is_empty()
    if not allies.is_empty() and Tactics.retry_available(game,actor,Tactics.ECHO_TOLL):
     var anchor: Dictionary=allies.back()
     if origin.distance_squared_to(anchor.point)>=1.0:
      lock_rite_anchor(attack,anchor,Tactics.ECHO_TOLL,2.35)
  4:
   if actor.get("gate_elite",false) and attack.mode=="pounce":
    attack.radius+=.18
    attack.cue="Heavy landing" if actor.variant.is_empty() else "Long pounce"
  7:
   if attack.mode=="stomp":
    attack.recovery_bonus=560
    if attack.variant=="fault_stomp":
     var direction: Vector3=(target-origin).normalized()
     var side:=direction.cross(Vector3.UP)
     var at:=origin+direction*2.6+side*(1.25 if int(actor.route)%2==0 else -1.25)
     if not direction.is_zero_approx() and game.battlefield.clear_line(origin,at,.5):
      attack.follow={"point":at,"radius":1.45,"delay":900}
      attack.cue="Aftershock"
     else:attack.cue=""
  9:
   if attack.mode=="brood":
    var count:=mini(2,4-count_elite_brood(game)) if actor.get("gate_elite",false) else mini(2-int(actor.summons),2 if attack.variant=="split_nursery" else 1)
    var can_scatter: bool=(count>=2 if actor.get("gate_elite",false) else int(actor.summons)==0)
    if can_scatter and Tactics.eligible(game,actor,Tactics.SCATTER):
     var sites:=scattered_sites(game,origin)
     if sites.size()==2:
      attack.hatch=sites
      attack.variant=Tactics.SCATTER
      attack.cue=Tactics.RESPONSES[Tactics.SCATTER].cue
      return
    attack.hatch=brood_sites(game,origin,count) if count>0 else []
    attack.cue=("Split hatch" if attack.hatch.size()>1 else "Hatch") if not attack.hatch.is_empty() else ""
  10:
   if attack.mode=="shepherd":
    attack.command=actor.get("cast_target",game.nearest_wild_player(origin))
    attack.escorts=visible_allies(game,actor,origin,attack.radius)
    attack.cue="Rally"
    var relay: bool=int(actor.get("rite_disrupted_epoch",-1))==game.combat_epoch and Tactics.eligible(game,actor,Tactics.RELAY)
    if (relay or attack.variant=="flank_command") and game.players.has(attack.command):
     var victim: Vector3=game.players[attack.command].pos
     for ally in attack.escorts:
      if ally.slot<0:continue
      var route:=preload("res://enemy_variants.gd").seam(game,ally.point,victim,int(actor.route))
      if not route.is_finite():continue
      attack.flank={"escort":ally,"via":route}
      attack.cue="Flank order"
      if relay:
       attack.escorts=[ally]
       attack.variant=Tactics.RELAY
       attack.cue=Tactics.RESPONSES[Tactics.RELAY].cue
      break
  11:
   if attack.mode=="stomp" and attack.variant=="planted_canopy" and target.distance_to(origin)>.05:attack.cue="Planted canopy"
   elif attack.variant=="planted_canopy":attack.variant="";attack.cue=""
  12:
   if attack.mode=="lure":
    attack.anchor=origin
    if attack.variant=="side_lantern":
     var side: Vector3=(target-origin).normalized().cross(Vector3.UP)
     var at:=origin+side*(1.7 if int(actor.route)%2==0 else -1.7)
     if game.battlefield.clear_line(origin,at,.5) and game.battlefield.clear_line(at,target):attack.anchor=at
     else:attack.cue=""
  15:
   if attack.mode=="chant":
    var tether:=tether_target(game,actor)
    var prey: Dictionary=tether.ref
    attack.cue=tether.cue
    attack.corpse=prey
    attack.role="corpse_tether"
    if not prey.is_empty():attack.to=prey.point
    if tether.response==Tactics.SPARE_TETHER:
     attack.variant=Tactics.SPARE_TETHER
     attack.escorts=visible_allies(game,actor,origin,attack.radius).slice(0,1)
  16:
   if attack.mode=="trophy_grab":
    attack.to=target
    attack.drop_id=actor.get("drop_target","")
    attack.role="trophy_grab"
    attack.cue="Loot grab"
  19:
   if attack.mode=="shepherd":
    attack.role="choir"
    attack.cue="Choir pulse"
    var allies:=visible_allies(game,actor,origin,attack.radius)
    attack.rite_has_ally=not allies.is_empty()
    if Tactics.retry_available(game,actor,Tactics.ANTIPHON):
     const ANTIPHON_RADIUS:=3.3
     for ref in allies:
      var distance: float=Vector3(ref.point).distance_squared_to(target)
      if origin.distance_squared_to(ref.point)<1.0 or distance<.16 or distance>ANTIPHON_RADIUS*ANTIPHON_RADIUS or not game.battlefield.clear_line(ref.point,target):continue
      lock_rite_anchor(attack,ref,Tactics.ANTIPHON,ANTIPHON_RADIUS)
      attack.role="enemy_sweep"
      attack.span=CHOIR_SPAN
      return
    if attack.variant=="split_chorus":
     attack.role="enemy_sweep"
     attack.span=CHOIR_SPAN
     attack.cue="Split chorus"

static func count_elite_brood(game: Node) -> int:
 var count:=0
 for slot in game.encounter.scout_count():
  if game.encounter.hp(slot)>0 and game.encounter.scout(slot).get("elite_brood",false):count+=1
 return count

static func spawn_brood_at(game: Node, position: Vector3, from_broodmother: bool=false) -> int:
 if not hatch_safe(game,position):return -1
 var slot: int=game.encounter.first_open_scout_slot()
 if slot>=game.EncounterConfig.MAX_SCOUTS:return -1
 var child: Dictionary=game.make_scout(0,position,slot+1,0,0,true)
 child.summoned=true
 if from_broodmother:child.broodmother_spawn=true
 return game.encounter.register_scout(child,slot)

static func resolve_brood(game: Node, actor: Dictionary, attack: Dictionary, now: int) -> void:
 var audible_release:=false
 for at in attack.get("hatch",[]):
  if attack.get("variant")==Tactics.SCATTER and not game.battlefield.clear_line(actor.pos,at,.45):continue
  if attack.get("variant")==Tactics.SCATTER:
   var player: int=game.nearest_wild_player(at)
   if player!=0 and game.players[player].pos.distance_to(at)<1.5:
    game.emit_combat_event("proc","hatch_blocked",at,at,.55,Color("#f0cb97"),0,-2)
    continue
  var slot:=spawn_brood_at(game,at,int(actor.kind)==9)
  if slot>=0:
   if not audible_release:
    preload("res://event_audio.gd").enemy(game,attack,true)
    audible_release=true
   actor.summons+=1
   if actor.get("gate_elite",false):game.encounter.scout(slot).elite_brood=true
   game.emit_combat_event("swing","pulse",at,at,.55,Color("#c2e394"),.8,0)
 if attack.get("hatch",[]).is_empty():actor.ready=now+650

static func grant_haste(game: Node, ref: Dictionary, until: int) -> void:
 if ref.slot<0:game.tactics.haste_until=maxi(game.tactics.haste_until,until)
 else:
  var ally: Dictionary=game.encounter.scout(ref.slot)
  ally.haste_until=maxi(int(ally.haste_until),until)

static func resolve_echo_toll(game: Node, actor: Dictionary, attack: Dictionary, now: int) -> void:
 var anchor: Dictionary=attack.rite_anchor
 if not anchored_rite_intact(game,actor,anchor):return
 preload("res://event_audio.gd").enemy(game,attack,true)
 var center: Vector3=anchor.point
 var allies:=visible_allies(game,actor,center,attack.radius)
 allies.sort_custom(func(a,b):return center.distance_squared_to(a.point)<center.distance_squared_to(b.point))
 for ally in allies.slice(0,2):grant_haste(game,ally,now+2200)
 Feedback.release(game,"burst",center,center,attack.radius,Feedback.SUPPORT)

static func resolve_corpse(game: Node, actor: Dictionary, attack: Dictionary, now: int) -> void:
 var ref: Dictionary=attack.get("corpse",{})
 var actor_slot: int=game.encounter.scout_slot(actor)
 if ref.is_empty() or actor_slot<0 or not game.encounter.alive(actor_slot):return
 for slot in game.encounter.scout_count():
  var dead: Dictionary=game.encounter.scout(slot)
  if game.encounter.token(slot)!=ref.token or game.encounter.hp(slot)>0 or dead.get("escaped",false) or dead.get("summoned",false):continue
  if actor.pos.distance_to(ref.point)>7.0 or not game.battlefield.clear_line(actor.pos,ref.point) or actor.get("consumed_corpses",[]).has(ref.token):return
  if not actor.has("consumed_corpses"):actor.consumed_corpses=[]
  actor.consumed_corpses.append(ref.token)
  preload("res://event_audio.gd").enemy(game,attack,true)
  var spare: bool=attack.get("variant")==Tactics.SPARE_TETHER
  var health_before: int=game.encounter.hp(actor_slot)
  var healed_hp:=mini(int(actor.get("max_hp",health_before)),health_before+game.Director.Balance.corpse_heal(game,actor,spare))
  game.encounter.set_hp(actor_slot,healed_hp)
  if spare or game.Life.Preview.enabled:
   Feedback.release(game,"restored",ref.point,actor.pos,healed_hp-health_before,Feedback.SUPPORT)
  if spare:
   for ally in attack.get("escorts",[]):
    if not live_ally(game,ally):continue
    var position: Vector3=game.enemy_position(ally.slot)
    if position.distance_to(actor.pos)<=float(attack.radius) and game.battlefield.clear_line(actor.pos,position):
     grant_haste(game,ally,now+2000)
  else:
   for ally in visible_allies(game,actor,attack.from,attack.radius):
    if ally.slot<0:game.tactics.haste_until=now+3000
    else:game.encounter.scout(ally.slot).haste_until=now+3000
  game.emit_combat_event("swing","pulse",ref.point,actor.pos,.55,Color("#d1bd98"),.75,0)
  return

static func resolve_shepherd(game: Node, attack: Dictionary, now: int) -> void:
 var target: int=attack.get("command",0)
 if not game.players.has(target) or not game.Life.alive(game.players[target]):return
 var audible_release:=false
 for ref in attack.get("escorts",[]):
  if not live_ally(game,ref):continue
  var point: Vector3=game.enemy_position(ref.slot)
  if point.distance_to(attack.from)>attack.radius or not game.battlefield.clear_line(attack.from,point):continue
  var ally: Dictionary=game.tactics.memory if ref.slot<0 else game.encounter.scout(ref.slot)
  if attack.get("variant")==Tactics.RELAY:
   if now<int(ally.get("rooted_until",0)) or not game.battlefield.clear_line(point,attack.flank.via,.45):continue
  if not audible_release:
   preload("res://event_audio.gd").enemy(game,attack,true)
   audible_release=true
  ally.command_target=target
  ally.command_until=now+2600
  if ref.slot>=0:ally.engaged=true
  else:game.tactics.engaged=true
  ally.erase("command_via")
  var flank: Dictionary=attack.get("flank",{})
  if not flank.is_empty() and flank.escort.token==ref.token and flank.escort.slot==ref.slot and game.battlefield.clear_line(point,flank.via,.45):
   ally.command_via=flank.via
  game.emit_combat_event("swing","pulse",attack.from,point,.35,Color("#b4d9ad"),.42,0)

static func resolve_choir(game: Node, actor: Dictionary, attack: Dictionary, now: int) -> void:
 var damage: float=game.Director.Balance.scout_hit(game,game.Enemies.get_kind(int(actor.kind)),actor) if game.Life.Preview.enabled else 1.0
 if attack.get("variant")==Tactics.ANTIPHON:
  var anchor: Dictionary=attack.rite_anchor
  if anchored_rite_intact(game,actor,anchor):
   preload("res://event_audio.gd").enemy(game,attack,true)
   Feedback.release(game,"sector",anchor.point,attack.face,attack.radius,Feedback.THREAT,0.0,attack.span)
   hit_choir_sector(game,anchor.point,attack,now,damage)
  return
 if visible_allies(game,actor,attack.from,attack.radius).is_empty():return
 preload("res://event_audio.gd").enemy(game,attack,true)
 if attack.span<=0:
  game.hit_players(attack.from,attack.radius,now,damage,500)
  return
 hit_choir_sector(game,attack.from,attack,now,damage)
 if not attack.get("second_beat",false):
  var face: Vector3=attack.face-attack.from
  attack.face=attack.from+face.rotated(Vector3.UP,2.3)
  attack.second_beat=true
  attack.cue="Second beat"
  actor.attack=attack
  actor.windup=now+730
  preload("res://event_audio.gd").enemy(game,attack,false)

static func hit_choir_sector(game: Node, origin: Vector3, attack: Dictionary, now: int, damage: float) -> void:
 for id in game.players:
  var player: Dictionary=game.players[id]
  if game.Life.alive(player) and Geometry.accepts_sector(origin,attack.face,player.pos,0.0,attack.radius,attack.span) and game.battlefield.clear_line(origin,player.pos):
   game.apply_enemy_hit(id,player,now,damage,500,origin)
