extends RefCounted
## A cast is committed once by the host. The same shapes drive warnings and damage.
const Routes = preload("res://boss_lair_routes.gd")
const Attacks = preload("res://enemy_attack.gd")
const Orchard = preload("res://orchard_moves.gd")
const Feedback = preload("res://enemy_move_feedback.gd")
const SAMPLE_MS := 400
const HINT_BASE := -500000
const TIDE_KIND := "lair_tide"
const POOL_KIND := "lair_pool"
const ANCHOR_KIND := "lair_roots"
const FRUIT_KIND := "lair_fruit"

static func observe(game: Node, now: int) -> void:
 var brain: Dictionary=game.tactics.memory
 if now<int(brain.get("lair_sample_at",0)):return
 brain.lair_sample_at=now+SAMPLE_MS
 var tracks: Dictionary=brain.get("lair_tracks",{})
 for id in tracks.keys():
  if not game.players.has(id) or not game.Life.alive(game.players[id]):tracks.erase(id)
 for id in game.players:
  var player: Dictionary=game.players[id]
  if not game.Life.alive(player):continue
  var at: Vector3=player.pos
  var old: Dictionary=tracks.get(id,{"point":at,"lane":-1,"streak":0,"outer":0})
  var lane:=Routes.dry_lane(Routes.crossings(game.map_seed),at) if game.tactics.boss_kind==Routes.DROWNED else -1
  var travel: float=at.distance_to(old.point)
  var outer: bool= game.tactics.boss_kind==Routes.ORCHARD and at.length()>=9.5 and travel>=.28 and travel<=3.2 and at.distance_to(game.tactics.position)>4.0
  tracks[id]={"point":at,"lane":lane,
   "streak":mini(12,int(old.streak)+1) if lane>=0 and old.lane==lane and travel<1.1 else 0,
   "outer":mini(12,int(old.outer)+1) if outer else maxi(0,int(old.outer)-1)}
 brain.lair_tracks=tracks

static func begin_phase(game: Node, next: int, now: int) -> void:
 if game.tactics.boss_kind==Routes.ORCHARD:
  game.tactics.memory.orchard_phase_start=game.tactics.boss_moves
 game.tactics.memory.lair_phase_until=now+1100
 game.tactics.ready_at=maxi(game.tactics.ready_at,now+1100)
 game.Journal.event("combat","boss_lair_phase",{"species":game.Enemies.get_kind(game.tactics.boss_kind).id,"phase":next,"floor":game.encounter_number})

static func adaptive(game: Node, target: int, style: String) -> bool:
 if game.tactics.boss_phase<=0:return false
 var track: Dictionary=game.tactics.memory.get("lair_tracks",{}).get(target,{})
 var tactic: String="kite" if style=="outer" else "ranged"
 var remembered: int=int(game.progress.wilds_memory.score.get(tactic,0))
 return int(track.get("outer" if style=="outer" else "streak",0)) >= (4 if remembered>=6 else 7)

static func direction(from: Vector3, to: Vector3) -> Vector3:
 var aim:=to-from
 return aim.normalized() if aim.length_squared()>.02 else Vector3.FORWARD

static func area(point: Vector3, radius: float, kind: String, delay: int, duration: int) -> Dictionary:
 return {"point":point,"radius":radius,"kind":kind,"delay":delay,"duration":duration}

static func draft(game: Node, mode: String, target: int, adapted: bool) -> Dictionary:
 var victim: Vector3=game.players[target].pos
 var origin: Vector3=game.tactics.position
 var facing:=direction(origin,victim)
 var phase: int=game.tactics.boss_phase
 var result := {"mode":mode,"variant":"","origin":origin,"from":origin,"to":victim,"face":victim,
  "form":"","cue":"","radius":0.0,"inner":0.0,"span":0.0,"width":0.0,"areas":[],
  "anchor":Vector3.INF,"open":"","recovery":0,"windup":1700,"bank":-1}
 match mode:
  "root_sweep":
   result.form="sweep";result.cue="Root sweep";result.radius=Orchard.reach(mode,phase);result.inner=1.35;result.span=2.55+phase*.30
   result.to=origin+facing*3.0
   result.anchor=game.battlefield.dash(origin,origin+facing*2.8)
   result.open="uprooting";result.recovery=2700
   if adapted:
    var angle:=atan2(victim.z,victim.x)
    var lattice:=TAU/16.0
    var offset:=Routes.orchard_angle(game.map_seed)
    var anchor_angle:=roundf((angle-offset)/lattice)*lattice+offset
    var ray:=Vector3(cos(anchor_angle),0,sin(anchor_angle))
    result.from=Vector3.ZERO;result.to=ray*13.2;result.face=result.to;result.anchor=result.to
    result.radius=17.8;result.inner=8.65;result.span=1.52;result.windup=2300
    result.variant="outer_anchor";result.cue="Outer roots"
   elif phase>0:
    result.open="";result.follow_ms=350
  "orchard_march","drowned_surge":
   var march:=mode=="orchard_march"
   result.form="charge";result.width=1.65+phase*.22 if march else .92
   result.radius=2.2+phase*.35 if march else 1.45
   var stride:=10.0+phase*.55 if march else 8.0
   result.to=game.battlefield.dash(origin,origin.move_toward(victim,stride))
   result.cue="Orchard march" if mode=="orchard_march" else "Tidal surge"
   result.open="uprooting" if mode=="orchard_march" else "core_exposed"
   result.recovery=2700
   if mode=="orchard_march" and origin.distance_to(result.to)>3.8:
    result.areas.append(area(origin.lerp(result.to,.35),1.05,ANCHOR_KIND,450,2000))
  "falling_fruit":
   result.cue="Falling fruit"
   result.areas.append(area(victim,2.7+phase*.32,FRUIT_KIND,0,260))
   if phase>0:
    result.follow_ms=520
    var side:=facing.cross(Vector3.UP)
    if (game.tactics.boss_moves+phase)%2!=0:side=-side
    for ray in [side,-side]:
     var extra: Vector3=victim+ray*4.05
     if game.battlefield.occupied(extra,.65):continue
     result.areas.append(area(extra,1.9+phase*.12,FRUIT_KIND,450,260))
     break
  "root_cage":
   result.form="cage";result.cue="Root cage";result.from=victim
   result.radius=5.8+phase*.55;result.inner=1.25;result.span=.37-phase*.035
   result.windup=1850 if phase==1 else 1700
   result.to=victim+facing.rotated(Vector3.UP,.84 if game.tactics.boss_moves%2==0 else -.84)
  "tidal_ring","grasping_pool":
   var layout:=Routes.crossings(game.map_seed)
   var bank_index:=0 if victim.x<float(layout.center) else 1
   if mode=="tidal_ring":
    result.cue="Tidal relay";result.bank=bank_index
    var step:=3.6 if victim.z<3.0 else -3.6
    var first:=Routes.bank(layout,bank_index,clampf(victim.z,-7.4,7.4))
    var second:=Routes.bank(layout,bank_index,first.z+step)
    result.areas.append(area(first,1.65,TIDE_KIND,0,430))
    if first.distance_to(second)>=2.25:result.areas.append(area(second,1.65,TIDE_KIND,520,430))
   elif adapted and Routes.dry_lane(layout,victim)>=0:
    result.cue="Causeway flooding";result.variant="flood_bank";result.bank=bank_index;result.windup=2300
    var first:=Routes.bank(layout,bank_index,clampf(victim.z,-6.4,7.2))
    var step:=2.9 if first.z<2.0 else -2.9
    result.areas.append(area(first,2.05,TIDE_KIND,0,2100))
    result.areas.append(area(Routes.bank(layout,bank_index,first.z+step),1.65,TIDE_KIND,400,1600))
   else:
    result.cue="Grasping pool"
    result.areas.append(area(victim,1.55,POOL_KIND,0,1600))
 return result

static func inside_sweep(plan: Dictionary, at: Vector3, buffer: float=0.0) -> bool:
 var offset: Vector3=at-plan.from
 var distance:=offset.length()
 if distance<.001 or distance<maxf(0.0,float(plan.inner)-buffer) or distance>float(plan.radius)+buffer:return false
 return direction(plan.from,plan.face).dot(offset/distance)>=cos(float(plan.span)*.5+buffer/maxf(distance,.5))

static func covered(plan: Dictionary, at: Vector3, buffer: float=0.0) -> bool:
 if plan.form=="sweep" and inside_sweep(plan,at,buffer):return true
 if plan.form=="cage":
  return Orchard.inside_cage(plan.from,direction(plan.from,plan.to),at,plan.radius,plan.inner,plan.span,buffer)
 if plan.form=="charge":
  var nearest:=Geometry3D.get_closest_point_to_segment(at,plan.from,plan.to)
  if at.distance_to(nearest)<=float(plan.width)+Attacks.CONTACT_PADDING+buffer or at.distance_to(plan.to)<=float(plan.radius)+Attacks.CONTACT_PADDING+buffer:return true
 for attack in plan.get("lanes",[]):
  var nearest:=Geometry3D.get_closest_point_to_segment(at,attack.from,attack.to)
  if at.distance_to(nearest)<=float(attack.width)+Attacks.CONTACT_PADDING+buffer or at.distance_to(attack.to)<=float(attack.radius)+Attacks.CONTACT_PADDING+buffer:return true
 for zone in plan.areas:
  if at.distance_to(zone.point)<=float(zone.radius)+buffer:return true
 return false

static func crosses_live_hazard(game: Node, from: Vector3, to: Vector3, now: int) -> bool:
 for hazard in game.enemy_hazards:
  if int(hazard.until)<=now:continue
  var nearest:=Geometry3D.get_closest_point_to_segment(hazard.point,from,to)
  if nearest.distance_to(hazard.point)<float(hazard.radius)+.26:return true
 return false

static func escape(game: Node, plan: Dictionary, at: Vector3, now: int) -> Vector3:
 var layout:=Routes.crossings(game.map_seed)
 var candidates: Array[Vector3]=[]
 if plan.variant=="outer_anchor":
  var inward:=at.normalized()*7.9
  candidates.assign([inward,inward.rotated(Vector3.UP,.18),inward.rotated(Vector3.UP,-.18)])
 elif plan.form=="cage":
  candidates.append_array(Orchard.cage_exits(plan,at))
 elif plan.form=="sweep":
  var inward:=direction(plan.from,at)*maxf(0.0,float(plan.inner)-.48)
  candidates.append(plan.from+inward)
 elif plan.bank>=0 and game.tactics.boss_kind==Routes.DROWNED:
  var other:=1-int(plan.bank)
  for z in layout.bars:
   candidates.append(Vector3(lerpf(float(layout.center),float(layout.banks[other]),.30),0,float(z)))
  candidates.append(Routes.bank(layout,other,at.z))
  # Retreating along the same bank to an unmarked section also reaches the dry network.
  for offset in [-4.3,4.3,-5.8,5.8]:
   candidates.append(Routes.bank(layout,int(plan.bank),at.z+offset))
 if plan.variant not in ["outer_anchor","flood_bank"]:
  for radius in [2.8,4.3,5.6]:
   for step in 10:
    var angle:=step*TAU/10.0
    candidates.append(at+Vector3(cos(angle),0,sin(angle))*radius)
 for candidate in candidates:
  if at.distance_to(candidate)>float(plan.windup)*.0034 or covered(plan,candidate,.32):continue
  if not game.battlefield.clear_line(at,candidate,game.Battlefield.CLEARANCE):continue
  if not crosses_live_hazard(game,at,candidate,now):return candidate
 return Vector3.INF

static func other_bank_open(game: Node, plan: Dictionary, now: int) -> bool:
 if plan.bank<0:return true
 var layout:=Routes.crossings(game.map_seed)
 var other:=1-int(plan.bank)
 var first:=Routes.bank(layout,other,layout.bars[0])
 var second:=Routes.bank(layout,other,layout.bars[1])
 if not game.battlefield.clear_line(first,second,game.battlefield.CLEARANCE):return false
 if crosses_live_hazard(game,first,second,now):return false
 for step in 13:
  if covered(plan,first.lerp(second,step/12.0),.35):return false
 return true

static func safe_for_party(game: Node, plan: Dictionary, now: int) -> bool:
 if not other_bank_open(game,plan,now):return false
 for player in game.players.values():
  if game.Life.alive(player) and covered(plan,player.pos,.25) and not escape(game,plan,player.pos,now).is_finite():return false
 return true

static func commit(game: Node, mode: String, target: int, now: int) -> bool:
 var want_variant := (mode=="root_sweep" and adaptive(game,target,"outer")) or (mode=="grasping_pool" and adaptive(game,target,"bank"))
 var plan:=draft(game,mode,target,want_variant)
 if want_variant and (not covered(plan,game.players[target].pos) or not safe_for_party(game,plan,now)):
  plan=draft(game,mode,target,false)
 while plan.areas.size()>maxi(0,32-game.enemy_hazards.size()):plan.areas.pop_back()
 if not safe_for_party(game,plan,now):
  if plan.areas.size()>1:plan.areas.pop_back()
  elif plan.form=="cage":
   var axis:=direction(plan.from,plan.to)
   for turn in [PI*.25,PI*.5,PI*.75]:
    plan.to=plan.from+axis.rotated(Vector3.UP,turn)
    if safe_for_party(game,plan,now):break
 if not safe_for_party(game,plan,now) or (plan.form.is_empty() and plan.areas.is_empty()):
  game.tactics.ready_at=now+450
  return false
 game.tactics.memory.lair_plan=plan
 game.tactics.attack_mode=mode
 game.tactics.landing=plan.to
 game.tactics.active_radius=plan.radius
 game.tactics.strike_at=now+int(plan.windup)
 game.tactics.winding_up=true
 preload("res://oracle_omens.gd").begin_attack(game,game.tactics.memory,plan,now)
 preload("res://event_audio.gd").enemy(game,plan,false)
 game.tactics.boss_moves+=1
 game.Journal.event("combat","boss_lair_move",{"species":game.Enemies.get_kind(game.tactics.boss_kind).id,"move":mode,"variant":plan.variant,"phase":game.tactics.boss_phase,"floor":game.encounter_number,"areas":plan.areas.size()})
 return true

static func resolve(game: Node, plan: Dictionary, now: int, damage: float) -> void:
 if plan.is_empty():return
 var charge_clear: bool = plan.form=="charge" and game.battlefield.clear_line(plan.from,plan.to,game.Battlefield.CLEARANCE)
 if plan.form in ["sweep","cage"] or charge_clear or not plan.areas.is_empty():
  preload("res://event_audio.gd").enemy(game,plan,true)
 if plan.form in ["sweep","cage"]:
  for id in game.players:
   var player: Dictionary=game.players[id]
   if game.Life.alive(player) and covered(plan,player.pos) and game.battlefield.clear_line(plan.from,player.pos):
    game.apply_enemy_hit(id,player,now,damage,0,plan.from)
 elif charge_clear:
  game.tactics.position=plan.to
  preload("res://enemy_attack_hits.gd").for_world(game,-1).charge(plan.from,plan.to,plan.width,plan.radius,now,damage)
 for zone in plan.areas:
  game.Bosses.hazard(game,zone.point,zone.radius,now,int(zone.duration),zone.kind,int(zone.delay),damage,plan.get("mode",game.tactics.attack_mode))
 if not str(plan.open).is_empty():
  var until:=now+int(plan.recovery)
  game.tactics.memory.lair_open={"kind":plan.open,"until":until}
  game.tactics.ready_at=maxi(game.tactics.ready_at,until)
 var root_color:=Color("#dc9a61")
 match plan.form:
  "sweep","cage":
   Feedback.release(game,"orchard_"+plan.form,plan.from,plan.to,plan.radius,root_color,plan.inner,plan.span)
  "charge":
   if charge_clear:
    var color:=Color("#8dd9dc") if game.tactics.boss_kind==Routes.DROWNED else root_color
    if game.tactics.boss_kind==Routes.DROWNED:
     game.emit_combat_event("swing","pulse",plan.from,plan.to,.42,color,1.6,0)
    else:
     Feedback.release(game,"lane",plan.from,plan.to,float(plan.radius)+Attacks.CONTACT_PADDING,color,float(plan.width)+Attacks.CONTACT_PADDING)

static func hints(game: Node, now: int) -> Array:
 var result: Array=[]
 if not Routes.supports(game.tactics.boss_kind) or game.encounter.hp(-1)<=0:return result
 var plan: Dictionary=game.tactics.memory.get("lair_plan",{})
 if game.tactics.winding_up and not plan.is_empty():
  var remaining:=maxf(0.0,(game.tactics.strike_at-now)*.001)
  var style: String="water" if game.tactics.boss_kind==Routes.DROWNED else "root"
  if not plan.form.is_empty():
   var role: String="charge" if plan.form=="charge" else "orchard_"+plan.form
   var padding:=Attacks.CONTACT_PADDING if role=="charge" else 0.0
   var main:=Attacks.warning(HINT_BASE,role,plan.from,plan.to,float(plan.radius)+padding,float(plan.width)+padding,remaining)
   var face: Vector3=plan.face
   main.inner=plan.inner;main.span=plan.span;main.face=[face.x,0,face.z]
   main.interior_escape=plan.form=="sweep"
   main.actor=-1;main.pose=plan.mode;main.lair=style;main.cue=plan.cue
   result.append(main)
  if plan.anchor.is_finite():
   var plant:=Attacks.warning(HINT_BASE-1,"orchard_anchor",plan.origin,plan.anchor,1.0,0.0,remaining)
   plant.lair="root";result.append(plant)
  for index in plan.areas.size():
   var zone: Dictionary=plan.areas[index]
   var marker:=Attacks.warning(HINT_BASE-10-index,"lair_zone",zone.point,zone.point,zone.radius,0.0,remaining+float(zone.delay)*.001)
   marker.lair="water" if zone.kind in [TIDE_KIND,POOL_KIND] else "root"
   if zone.kind==FRUIT_KIND:
    marker.lair="fruit"
    if index>0:marker.cue="Second drop"
   if result.is_empty():
    marker.actor=-1
    var face: Vector3=plan.face
    marker.face=[face.x,0,face.z];marker.pose=plan.mode;marker.cue=plan.cue
   result.append(marker)
 var phase_until: int=game.tactics.memory.get("lair_phase_until",0)
 if phase_until>now:
  var phase_cue:=Attacks.warning(HINT_BASE-20,"lair_phase",game.tactics.position,game.tactics.position,1.6,0.0,(phase_until-now)*.001)
  phase_cue.cue="Tide rising" if game.tactics.boss_kind==Routes.DROWNED else "Roots deepen"
  phase_cue.lair="water" if game.tactics.boss_kind==Routes.DROWNED else "root"
  result.append(phase_cue)
 var open: Dictionary=game.tactics.memory.get("lair_open",{})
 if int(open.get("until",0))>now:
  var state:=Attacks.warning(HINT_BASE-21,"lair_open",game.tactics.position,game.tactics.position,.9,0.0,(int(open.until)-now)*.001)
  state.actor=-1;state.pose=open.kind;state.lair="open"
  result.append(state)
 return result
