extends RefCounted
# Optional behavior hooks extend the common actor without forking damage/reward rules.
const Support = preload("res://enemy_support.gd")
const Attacks = preload("res://enemy_attack.gd")
const Hits = preload("res://enemy_attack_hits.gd")
const Feedback = preload("res://enemy_move_feedback.gd")
const Thief = preload("res://thief_escape.gd")
const Glasscap = preload("res://glasscap_feint.gd")

static func tick(game: Node, scout: Dictionary, delta: float, now: int) -> bool:
 if scout.kind==Glasscap.KIND:return Glasscap.holding(game,scout,now)
 if scout.kind!=Thief.KIND or scout.windup>0:return false
 if not scout.get("stolen",[]).is_empty():
  Thief.tick(game,scout,delta,now)
  return true
 if now<int(scout.ready) or now<int(scout.rooted_until) or now<int(scout.stagger_until):return false
 var learned: bool=not Attacks.SkillResponses.ready_profile(game,scout).is_empty()
 for drop in game.wild_item_drops:
  if game.Items.get_item(str(drop.stack.item)).get("category","")!="monster_part":continue
  var at:=Vector3(drop.position[0],0,drop.position[2])
  var distance: float=scout.pos.distance_to(at)
  if distance>=7 or not game.battlefield.clear_line(scout.pos,at):continue
  var edge: bool=scout.get("variant","")=="edge_thief"
  var ordinary_reach:=2.3 if edge else 1.15
  var extended: bool=learned and distance<=Attacks.SkillResponses.GRAB_REACH and game.battlefield.clear_line(scout.pos,at,game.Battlefield.CLEARANCE)
  if distance<=ordinary_reach or extended:
   scout.drop_target=drop.id
   Attacks.lock(game,scout,"trophy_grab",at,now+(930 if edge else 680))
  else:
   var forward: Vector3=(at-scout.pos).normalized()
   var side: Vector3=forward.cross(Vector3.UP)*(1.0 if int(scout.route)%2==0 else -1.0)
   var approach:=at+side*1.4
   var goal: Vector3=approach if edge and distance>3 and game.battlefield.clear_line(scout.pos,approach,.45) else at
   scout.pos=game.Director.navigate(game,scout.pos,goal,2.5*delta)
  return true
 return false

static func support_target(game: Node, scout: Dictionary, _allies: Array, anchor: Vector3, speed: float, delta: float, now: int) -> bool:
 var target: int=game.Director.target(game,scout.pos,scout,now)
 if target==0:return false
 scout.cast_target=target
 var victim: Vector3=game.players[target].pos
 if scout.kind==15 and Support.tether_target(game,scout).ref.is_empty():
  scout.ready=now+400
  return true
 if scout.kind==3 and scout.get("variant","")=="covered_bell" and not scout.get("covered_once",false):
  if not scout.has("cover_goal"):
   var goal: Vector3=anchor+(anchor-victim).normalized()*1.6
   if not game.battlefield.clear_line(scout.pos,goal,.45):scout.covered_once=true;return false
   scout.cover_goal=goal
   scout.cover_until=now+750
  if scout.pos.distance_to(scout.cover_goal)>.18 and now<int(scout.cover_until) and now>=int(scout.rooted_until):
   scout.pos=game.battlefield.slide(scout.pos,scout.pos.move_toward(scout.cover_goal,speed*delta))
   return true
  scout.covered_once=true
 return false

static func telegraph(game: Node,scout: Dictionary,_now: int) -> void:
 Glasscap.prepare(game,scout)
static func _hit_window(game: Node, scout: Dictionary, window: Hits.HitWindow) -> Hits.HitWindow:
 if window != null: return window
 var slot: int = -1 if scout.get("gate_elite", false) else game.encounter.scout_slot(scout)
 return Hits.for_world(game, slot)

static func resolve(game: Node,scout: Dictionary,attack: Dictionary,now: int,window: Hits.HitWindow = null) -> bool:
 var kind:=int(scout.kind)
 var commitment: Dictionary = attack.get(Attacks.SCOUT_COMMIT,{})
 if attack.mode=="canopy_shift":
  Attacks.SkillResponses.resolve_canopy(game,scout,attack,now)
  return true
 if attack.get("variant")=="glass_crossfire":
  var spots: Array=attack.spots.filter(func(point):return game.battlefield.projectile_clear(attack.from,point))
  if spots.is_empty():return true
  preload("res://event_audio.gd").enemy(game,attack,true)
  var hits := _hit_window(game,scout,window)
  for point in spots:
   Feedback.release(game,"burst",attack.from,point,attack.spot_radius,Color("#b9e6f6"))
   hits.area(point,attack.spot_radius,now,game.Director.Balance.scout_hit(game,game.Enemies.get_kind(kind),scout),0,true,true)
  Glasscap.release(game,scout,now)
  return true
 if kind==17 and attack.mode=="charge":
  for at in attack.trail:game.Bosses.hazard(game,at,.85,now,2500,"ember",800,1.0,"",commitment)
  return true
 if kind==14 and attack.mode=="snare":
  if not attack.spots.is_empty():preload("res://event_audio.gd").enemy(game,attack,true)
  for point in attack.spots:game.Bosses.hazard(game,point,attack.spot_radius,now,2300,"web",750,1.0,"",commitment)
  return true
 if kind==5 and attack.mode=="snare" and not attack.spots.is_empty():
  if attack.spots.any(func(point):return game.battlefield.clear_line(attack.from,point)):
   preload("res://event_audio.gd").enemy(game,attack,true)
  var hits := _hit_window(game,scout,window)
  for point in attack.spots:
   if game.battlefield.clear_line(attack.from,point):
    if attack.get("variant")=="forked_roots":Feedback.release(game,"burst",attack.from,point,attack.spot_radius)
    hits.area(point,attack.spot_radius,now,game.Director.Balance.scout_hit(game,game.Enemies.get_kind(kind),scout),1600)
  return true
 if kind==6 and attack.mode=="artillery":
  if attack.patches.any(func(point):return game.battlefield.clear_line(attack.from,point)):
   preload("res://event_audio.gd").enemy(game,attack,true)
  for i in attack.patches.size():
   var point: Vector3=attack.patches[i]
   if game.battlefield.clear_line(attack.from,point):
    game.Bosses.hazard(game,point,attack.radius,now,1650,"spores",650+i*450,1.0,"",commitment)
  return true
 match attack.mode:
  "brood":
   Support.resolve_brood(game,scout,attack,now)
   return true
  "chant":
   if kind==3 and attack.get("variant")==Support.Tactics.ECHO_TOLL:
    Support.resolve_echo_toll(game,scout,attack,now)
    return true
   if kind==15:
    Support.resolve_corpse(game,scout,attack,now)
    return true
  "shepherd":
   if kind==19:Support.resolve_choir(game,scout,attack,now)
   else:Support.resolve_shepherd(game,attack,now)
   return true
  "trophy_grab":
   for drop in game.wild_item_drops:
    var grab_reach:=float(attack.get("grab_reach",2.4))
    if attack.get("learned",false) and not Attacks.SkillResponses.move_still_valid(scout,attack,now):break
    if drop.id!=attack.get("drop_id","") or not game.battlefield.clear_line(scout.pos,attack.to) or scout.pos.distance_to(attack.to)>grab_reach:continue
    if attack.get("learned",false):
     var point:=Vector3(drop.position[0],0,drop.position[2])
     if not point.is_equal_approx(attack.to):continue
    scout.pos=game.battlefield.dash(scout.pos,attack.to)
    if scout.pos.distance_to(attack.to)>.25:break
    if not Thief.steal(game,scout,drop,now):break
    if attack.get("learned",false):Feedback.release(game,"trophy",attack.from,attack.to,0.0,Color("#eac894"))
    break
   return true
 if attack.has("follow") and game.battlefield.clear_line(attack.from,attack.follow.point):
  game.Bosses.hazard(game,attack.follow.point,attack.follow.radius,now,220,"aftershock",attack.follow.delay,1.0,"",commitment)
 return false

static func interrupt(game: Node, actor: Dictionary, at: Vector3, now: int) -> bool:
 if not Support.interruptible(actor.get("attack",{})) and not (actor.kind==7 and actor.mode=="stomp"):return false
 preload("res://wilds_skill_tactics.gd").interrupted(game,actor,"stagger")
 actor.windup=0
 var body: Dictionary=game.tactics.memory if actor.get("gate_elite",false) else actor
 actor.ready=preload("res://oracle_omens.gd").release_attack(body,actor.get("attack",{}),now+1100)
 actor.erase("attack")
 actor.erase("repeat")
 game.emit_combat_event("proc","suppress",at,at,.5,Color("#f1d28d"),0,-2)
 game.Journal.event("combat","enemy_cast_interrupted",{"species":game.Enemies.get_kind(actor.kind).id,"actor":game.encounter.token_for(actor),"move":actor.mode,"floor":game.participation.floor()})
 return true

static func death(game: Node,scout: Dictionary,point: Vector3) -> void:
 Thief.recover(game,scout,point)
