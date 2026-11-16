extends RefCounted
## The host owns phase decisions, move footprints and nursery placement.
const NEST := 22
const BLOOM := 23
const BROOD_LIMIT := 4
const HINT_BASE := -510000
const Nest = preload("res://boss_nest_layout.gd")
const Attacks = preload("res://enemy_attack.gd")
const Safety = preload("res://boss_lair_fights.gd")
const Support = preload("res://enemy_support.gd")
const MEMORIES := {
 "ranged":{"move":"memory_lance","cue":"Lance growth","attack":"Side lance"},
 "burst":{"move":"spore_constellation","cue":"Spore crown","attack":"Delayed constellation"},
 "choke":{"move":"remembered_rend","cue":"Forked roots","attack":"Split rend"},
 "kite":{"move":"memory_lance","cue":"Tracking eye","attack":"Leading lance"},
}

static func supports(kind: int) -> bool:
 return kind==NEST or kind==BLOOM

static func observe_brood(game: Node, now: int) -> void:
 for child in game.scouts:
  if child.hp>0 or not child.has("nursery_origin") or child.get("nursery_counted",false):continue
  child.nursery_counted=true
  if child.pos.distance_to(child.nursery_origin)<=2.65 and now-int(child.nursery_born)<=7500:
   game.leader_brain.nursery_pressure=int(game.leader_brain.get("nursery_pressure",0))+1

static func memory(scores: Dictionary, phase: int) -> String:
 var strongest:=5
 var chosen:=""
 var keys:=MEMORIES.keys()
 for offset in keys.size():
  var key: String=keys[(phase+offset)%keys.size()]
  var score:=int(scores.get(key,0))
  if score>strongest:
   strongest=score
   chosen=key
 return chosen

static func begin_growth(game: Node, phase: int, now: int) -> void:
 var scores: Dictionary=game.progress.wilds_memory.score
 var chosen:=memory(scores,phase)
 game.leader_brain.memory_growth={"id":chosen,"preview_until":now+1450,"first_move":int(game.boss_moves)}
 game.enemy_ready_at=maxi(game.enemy_ready_at,now+1450)
 game.Journal.event("combat","boss_memory_phase",{"species":"nameless","phase":phase,"response":chosen,"floor":game.encounter_number})

static func begin_nest(game: Node, phase: int, now: int) -> void:
 game.leader_brain.nest_shift={"phase":phase,"ribs":Nest.ribs(phase),"until":now+1950,"grace":false}
 game.Journal.event("combat","boss_nest_preview",{"species":"matriarch","phase":phase,"floor":game.encounter_number})

static func nest_occupants(game: Node, shift: Dictionary) -> Array:
 var occupants: Array=[{"at":game.enemy_pos,"leader":true}]
 for player in game.players.values():
  if game.Life.alive(player):occupants.append({"at":player.pos,"actor":player})
 for scout in game.scouts:
  if scout.hp>0:occupants.append({"at":scout.pos,"actor":scout})
 return occupants.filter(func(entry):return Nest.blocked(shift.ribs,entry.at,game.Battlefield.CLEARANCE+.04))

static func advance_phase(game: Node, wanted: int, now: int) -> bool:
 var exposure: Dictionary=game.leader_brain.get("lair_open",{})
 if game.boss_kind==BLOOM:
  var growth: Dictionary=game.leader_brain.get("memory_growth",{})
  if not growth.is_empty() and now<int(growth.preview_until):return true
  if growth.is_empty() or (wanted>game.boss_phase and int(game.boss_moves)>int(growth.first_move) and now>=int(exposure.get("until",0))):
   game.boss_phase=mini(wanted,game.boss_phase+1)
   begin_growth(game,game.boss_phase,now)
   return true
  return false
 var shift: Dictionary=game.leader_brain.get("nest_shift",{})
 if shift.is_empty():
  if wanted<=game.boss_phase or now<maxi(int(game.leader_brain.get("nest_retry_at",0)),int(exposure.get("until",0))):return false
  begin_nest(game,game.boss_phase+1,now)
  return true
 if now<int(shift.until):return true
 var occupants:=nest_occupants(game,shift)
 if not occupants.is_empty() and not shift.grace:
  shift.grace=true
  shift.until=now+900
  return true
 for entry in occupants:
  entry.exit=Nest.step_out(game.battlefield,shift.ribs,entry.at,game.Battlefield.CLEARANCE+.04)
  if not entry.exit.is_finite():
   game.leader_brain.erase("nest_shift")
   game.leader_brain.nest_retry_at=now+2200
   return false
 game.boss_phase=int(shift.phase)
 game.battlefield.configure(game.destination,game.depth,game.map_seed,game.boss_kind,game.boss_phase)
 for entry in occupants:
  if entry.get("leader",false):game.enemy_pos=entry.exit
  else:entry.actor.pos=entry.exit
 game.leader_brain.erase("nest_shift")
 game.leader_brain.nursery_split=game.boss_phase==2 or int(game.leader_brain.get("nursery_pressure",0))>=2
 game.enemy_ready_at=now+400
 game.Journal.event("combat","boss_nest_shift",{"species":"matriarch","phase":game.boss_phase,"floor":game.encounter_number,"nudged":occupants.size(),"split":game.leader_brain.nursery_split})
 return true

static func hatch_sites(game: Node, origin: Vector3, split: bool) -> Array[Vector3]:
 var result: Array[Vector3]=[]
 for at in Nest.exits(game.boss_phase,game.map_seed):
  if not game.battlefield.clear_line(origin,at,.48) or not Support.hatch_safe(game,at):continue
  result.append(at)
  if not split:break
 return result

static func lane(game: Node, from: Vector3, goal: Vector3, width: float, radius: float, travels: bool=false) -> Dictionary:
 var end: Vector3=game.battlefield.dash(from,goal)
 return {"from":from,"to":end,"width":width,"radius":radius,"travels":travels}

static func choice(game: Node, normal: String) -> String:
 var growth: Dictionary=game.leader_brain.get("memory_growth",{})
 if growth.is_empty() or growth.id.is_empty():return normal
 var signature: String=MEMORIES[growth.id].move
 var step:=posmod(int(game.boss_moves)-int(growth.first_move),3)
 if step==0:return signature
 var others: Array=game.Enemies.get_kind(BLOOM).moves.filter(func(move):return move!=signature)
 return str(others[step-1])

static func draft(game: Node, mode: String, target: int, adaptation: String) -> Dictionary:
 var origin: Vector3=game.enemy_pos
 var victim: Vector3=game.players[target].pos
 var forward:=Safety.direction(origin,victim)
 var tangent:=forward.cross(Vector3.UP)
 var plan: Dictionary={"mode":mode,"variant":adaptation,"cue":"","from":origin,"to":victim,"face":victim,
  "form":"","bank":-1,"windup":1650,"areas":[],"lanes":[],"hatches":[],"open":"","recovery":0}
 if game.boss_kind==NEST:
  match mode:
   "brood_call":
    plan.open="nursery_lull";plan.recovery=2150
    plan.cue="Brood hatching";plan.windup=1800
    var count: int=game.scouts.filter(func(child):return child.hp>0 and child.get("summoned",false)).size()
    if count<BROOD_LIMIT:
     plan.hatches=hatch_sites(game,origin,game.leader_brain.get("nursery_split",false) and count<BROOD_LIMIT-1)
     if plan.hatches.size()>1:plan.cue="Split hatch"
   "matriarch_lunge":
    plan.open="nursery_lull";plan.recovery=2150
    plan.cue="Matriarch lunge"
    plan.lanes.append(lane(game,origin,origin.move_toward(victim,7.0),1.0,1.55,true))
   "nest_reshape":
    plan.cue="Nursery swell"
    for offset in [-1.65,1.65]:
     var at:=origin+forward*3.35+tangent*float(offset)
     if game.battlefield.clear_line(origin,at,.55):
      plan.areas.append(Safety.area(at,1.12,"nest",160,1350))
  return plan
 plan.open="memory_exposed";plan.recovery=2400
 if not adaptation.is_empty():plan.cue=MEMORIES[adaptation].attack
 match mode:
  "memory_lance":
   if plan.cue.is_empty():plan.cue="Memory lance"
   var aim: Vector3=game.Director.predict(game,target,.34) if adaptation=="kite" else victim
   var start:=origin+tangent*(1.18 if game.boss_phase%2==0 else -1.18) if adaptation=="ranged" else origin
   if not game.battlefield.clear_line(origin,start,.45):
    start=origin;plan.variant="";plan.cue="Memory lance"
   plan.lanes.append(lane(game,start,start.move_toward(aim,9.5),.72,1.10))
  "remembered_rend":
   if adaptation=="choke":
    for side in [-1.0,1.0]:
     var start: Vector3=origin+tangent*side*1.7
     if game.battlefield.clear_line(origin,start,.48):
      var branch:=lane(game,start,start+forward*6.7+tangent*side*.55,.57,.88)
      if branch.from.distance_to(branch.to)>4.0:plan.lanes.append(branch)
    if plan.lanes.size()==2:return plan
    plan.lanes.clear()
    plan.variant=""
   plan.cue="Remembered rend"
   plan.lanes.append(lane(game,origin,origin+forward*5.9,1.25,1.25))
  "spore_constellation":
   if plan.cue.is_empty():plan.cue="Spore constellation"
   if adaptation=="burst":plan.windup=2000
   plan.areas.append(Safety.area(victim,1.45,"bloom_spores",350 if adaptation=="burst" else 0,370))
   if adaptation=="burst":
    for side in [-1.0,1.0]:
     var at: Vector3=victim+tangent*side*2.9+forward*.85
     if game.battlefield.clear_line(victim,at,.55):
      plan.areas.append(Safety.area(at,1.22,"bloom_spores",740,370))
 return plan

static func commit(game: Node, normal: String, target: int, now: int) -> bool:
 var move:=choice(game,normal) if game.boss_kind==BLOOM else normal
 var growth: Dictionary=game.leader_brain.get("memory_growth",{})
 var adaptation: String=growth.get("id","") if game.boss_kind==BLOOM and not growth.is_empty() and posmod(int(game.boss_moves)-int(growth.first_move),3)==0 else ""
 var plan:=draft(game,move,target,adaptation)
 if not Safety.safe_for_party(game,plan,now) and not adaptation.is_empty():plan=draft(game,move,target,"")
 while plan.areas.size()>maxi(0,32-game.enemy_hazards.size()):plan.areas.pop_back()
 if not Safety.safe_for_party(game,plan,now) or (plan.areas.is_empty() and plan.lanes.is_empty() and plan.hatches.is_empty()):
  game.boss_moves+=1
  game.enemy_ready_at=now+550
  return false
 game.leader_brain.phase_plan=plan
 game.enemy_attack_mode=move
 game.enemy_landing=plan.lanes[0].to if not plan.lanes.is_empty() else plan.to
 game.active_radius=plan.lanes[0].radius if not plan.lanes.is_empty() else 1.35
 game.enemy_winding_up=true
 game.enemy_strike_at=now+int(plan.windup)
 preload("res://oracle_omens.gd").begin_attack(game,game.leader_brain,plan,now)
 preload("res://event_audio.gd").enemy(game,plan,false)
 game.boss_moves+=1
 game.Journal.event("combat","boss_phase_move",{"species":game.Enemies.get_kind(game.boss_kind).id,"move":move,"variant":plan.variant,"phase":game.boss_phase,"floor":game.encounter_number})
 return true

static func open(game: Node, status: String, now: int, duration: int) -> void:
 var until:=now+duration
 game.leader_brain.lair_open={"kind":status,"until":until}
 game.enemy_ready_at=maxi(game.enemy_ready_at,until)

static func interrupt(game: Node, at: Vector3, now: int) -> bool:
 if game.boss_kind!=NEST or not game.enemy_winding_up or game.enemy_attack_mode!="brood_call":return false
 var plan: Dictionary=game.leader_brain.get("phase_plan",{})
 game.leader_brain.erase("phase_plan")
 game.enemy_winding_up=false
 open(game,"nursery_lull",now,1900)
 game.enemy_ready_at=preload("res://oracle_omens.gd").release_attack(game.leader_brain,plan,game.enemy_ready_at)
 game.emit_combat_event("proc","suppress",at,at,.55,Color("#e1be92"),0,-2)
 game.Journal.event("combat","boss_brood_interrupted",{"species":"matriarch","phase":game.boss_phase,"floor":game.encounter_number})
 return true

static func resolve(game: Node, plan: Dictionary, now: int, damage: float) -> void:
 if plan.is_empty():return
 var released: bool = not plan.areas.is_empty()
 for attack in plan.lanes:
  if not game.battlefield.clear_line(attack.from,attack.to,game.Battlefield.CLEARANCE):continue
  released=true
  if attack.travels:game.enemy_pos=attack.to
  game.hit_players_charge(attack.from,attack.to,attack.width,attack.radius,now,damage)
  var color:=Color("#baaceb") if game.boss_kind==BLOOM else Color("#c7bd88")
  game.emit_combat_event("swing","thrust",attack.from,attack.to,.36,color,Vector3(attack.from).distance_to(attack.to),0)
 for patch in plan.areas:
  game.Bosses.hazard(game,patch.point,patch.radius,now,patch.duration,patch.kind,patch.delay,damage,plan.get("mode",game.enemy_attack_mode))
 for at in plan.hatches:
  if not game.battlefield.clear_line(plan.from,at,.48) or not Support.spawn_brood_at(game,at):continue
  released=true
  for child in game.scouts:
   if int(child.spawn_token)!=int(game.scout_serial):continue
   child.nursery_origin=at;child.nursery_born=now;child.haste_until=now+1350
   child.mutations=int(child.mutations)|(game.Enemies.BARK if game.boss_phase==1 else game.Enemies.MOBILITY if game.boss_phase==2 else 0)
   break
  game.emit_combat_event("swing","pulse",at,at,.50,Color("#bfb58b"),.85,0)
 if released:preload("res://event_audio.gd").enemy(game,plan,true)
 if not str(plan.open).is_empty():open(game,plan.open,now,int(plan.recovery))


static func hints(game: Node, now: int) -> Array:
 var result: Array=[]
 if not supports(game.boss_kind) or game.enemy_hp<=0:return result
 var plan: Dictionary=game.leader_brain.get("phase_plan",{})
 if game.enemy_winding_up and not plan.is_empty():
  var remaining:=maxf(0.0,(game.enemy_strike_at-now)*.001)
  var style: String="memory" if game.boss_kind==BLOOM else "nursery"
  for attack in plan.lanes:
   var pad:=Attacks.CONTACT_PADDING
   var marker:=Attacks.warning(HINT_BASE-result.size(),"charge",attack.from,attack.to,attack.radius+pad,attack.width+pad,remaining)
   marker.lair=style;result.append(marker)
  for patch in plan.areas:
   var marker:=Attacks.warning(HINT_BASE-result.size(),"lair_zone",patch.point,patch.point,patch.radius,0.0,remaining+patch.delay*.001)
   marker.lair=style;result.append(marker)
  for at in plan.hatches:
   var marker:=Attacks.warning(HINT_BASE-result.size(),"nursery_exit",at,at,1.5,0.0,remaining)
   marker.lair=style;result.append(marker)
  if not result.is_empty():
   var first: Dictionary=result[0]
   var face: Vector3=plan.face
   first.actor=-1;first.pose=plan.mode;first.face=[face.x,0,face.z];first.cue=plan.cue
   first.variant=plan.variant
   var origin: Vector3=plan.from
   first.label_at=[origin.x,0,origin.z]
 var shift: Dictionary=game.leader_brain.get("nest_shift",{})
 if not shift.is_empty():
  var remaining:=maxf(0.0,(int(shift.until)-now)*.001)
  for index in shift.ribs.size():
   var rect: Rect2=shift.ribs[index]
   var center:=Vector3(rect.get_center().x,0,rect.get_center().y)
   var hint:=Attacks.warning(HINT_BASE-20-index,"nursery_rib",center,center,1.6,0.0,remaining)
   hint.bounds=[rect.position.x,rect.position.y,rect.size.x,rect.size.y]
   hint.lair="nursery";hint.next_phase=shift.phase
   result.append(hint)
  var candidates:=Nest.exits(int(shift.phase),game.map_seed)
  var split: bool=int(shift.phase)==2 or int(game.leader_brain.get("nursery_pressure",0))>=2
  for index in (2 if split else 1):
   var at: Vector3=candidates[index]
   var marker:=Attacks.warning(HINT_BASE-45-index,"nursery_site",at,at,.7,0.0,remaining)
   marker.lair="nursery";result.append(marker)
  var cue:=Attacks.warning(HINT_BASE-28,"lair_phase",game.enemy_pos,game.enemy_pos,1.5,0.0,remaining)
  cue.lair="nursery";cue.cue="Ribs held open" if shift.grace else "Nest shifting"
  cue.actor=-1;cue.pose="nest_shift"
  result.append(cue)
 var growth: Dictionary=game.leader_brain.get("memory_growth",{})
 if not growth.is_empty():
  var preview_until:=int(growth.preview_until)
  var at: Vector3=game.enemy_pos
  var state:=Attacks.warning(HINT_BASE-30,"memory_growth",at,at,.85,0.0,0.0)
  state.growth=growth.id;state.phase=game.boss_phase
  result.append(state)
  if preview_until>now:
   var marker:=Attacks.warning(HINT_BASE-31,"lair_phase",at,at,1.5,0.0,(preview_until-now)*.001)
   marker.lair="memory";marker.cue="Bloom stirring" if growth.id.is_empty() else MEMORIES[growth.id].cue
   marker.actor=-1;marker.pose="memory_phase"
   result.append(marker)
 var exposure: Dictionary=game.leader_brain.get("lair_open",{})
 if not exposure.is_empty() and now<int(exposure.until):
  var marker:=Attacks.warning(HINT_BASE-40,"lair_open",game.enemy_pos,game.enemy_pos,.9,0.0,(int(exposure.until)-now)*.001)
  marker.actor=-1;marker.pose=exposure.kind;marker.lair="open"
  result.append(marker)
 return result
