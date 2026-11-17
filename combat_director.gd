extends RefCounted
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const Balance=preload("res://enemy_balance.gd")
static func config() -> Dictionary:
 return preload("res://game_balance.gd").values.combat
static func party_size(game: Node) -> int:
 var count:=0
 for p in game.players.values():
  if p.get("profile_ready",false) and (p.wild or not game.expedition_active()) and not PlayerLifecycle.fallen(p): count+=1
 return maxi(1,count)
static func scout_count(game: Node) -> int:
 if game.destination==game.Campaign.HEART: return mini(game.EncounterConfig.MAX_SCOUTS,4+2*(party_size(game)-1))
 var c:=config()
 var additional:=Balance.extra_scouts(int(c.coop_extra_scouts))*(party_size(game)-1)
 var limit=mini(game.EncounterConfig.MAX_SCOUTS,game.EncounterConfig.SOLO_SCOUT_LIMIT+additional)
 return mini(limit,int(c.base_scouts)+(game.encounter_number-1)/int(c.floors_per_extra_scout)+game.destination+mini(game.difficulty_cycle,3)+additional)
static func health(game: Node,base: int,leader: bool) -> int:
 var c:=config();var increase: int=(game.encounter_number-1)/int(c.floors_per_leader_hp if leader else c.floors_per_scout_hp)
 var value: int=base+increase+game.difficulty_cycle
 var extra_health:=float(c.coop_hp_multiplier-1.0)+minf(float(c.coop_hp_depth_cap),(game.encounter_number-1)*float(c.coop_hp_per_floor))
 var multiplier:=1.0+extra_health*(maxi(1,game.encounter_party_size)-1)
 return game.Life.Vitals.enemy_capacity(value,multiplier,game.Life.Preview.scale())
static func speed(game: Node,base: float) -> float:
 return minf(float(config().speed_cap),base*(float(config().speed_multiplier)+minf(.5,(game.encounter_number-1)*float(config().speed_per_floor))))
static func windup(game: Node,base: int) -> int:
 return maxi(int(config().minimum_windup_ms),roundi(base*maxf(.78,.98-(game.encounter_number-1)*.007)))
static func recovery(game: Node,base: int) -> int:
 return maxi(420,roundi(base*maxf(.72,.92-(game.encounter_number-1)*.008)))
static func spawn(game: Node,origin: Vector3,index: int) -> Vector3:
 for attempt in 32:
  var angle: float=(index+attempt)*2.39996
  var radius: float=0.0 if attempt==0 else 1.0+attempt*.35
  var candidate: Vector3=game.clear_spawn(origin+Vector3(cos(angle),0,sin(angle))*radius)
  if not candidate.is_finite() or candidate.distance_to(game.battlefield.entry)<float(config().spawn_entry_clearance) or game.battlefield.occupied(candidate,.4): continue
  if index>=0 and candidate.distance_to(game.tactics.position)<1.25: continue
  var clear:=true
  for slot in game.encounter.scout_count():
   if candidate.distance_to(game.encounter.position(slot))<1.15: clear=false;break
  if clear: return candidate
 return Vector3.INF
static func alert(game: Node,origin: Vector3) -> void:
 var radius: float=config().group_alert_radius
 if game.encounter.hp(-1)>0 and game.tactics.position.distance_to(origin)<=radius and game.battlefield.clear_line(origin,game.tactics.position): game.tactics.engaged=true
 for slot in game.encounter.scout_count():
  var mob: Dictionary=game.encounter.scout(slot)
  if game.encounter.hp(slot)>0 and mob.pos.distance_to(origin)<=radius and game.battlefield.clear_line(origin,mob.pos): mob.engaged=true
static func target(game: Node,origin: Vector3,agent: Dictionary,now: int) -> int:
 var commanded: int=agent.get("command_target",0)
 if now<int(agent.get("command_until",0)) and game.players.has(commanded) and game.players[commanded].wild and not PlayerLifecycle.fallen(game.players[commanded]) and PlayerVitals.current_hp(game.players[commanded])>0:return commanded
 var previous: int=agent.get("target",0)
 if game.players.has(previous) and game.players[previous].wild and PlayerVitals.current_hp(game.players[previous])>0 and now<int(agent.get("target_until",0)): return previous
 var best:=INF;var selected:=0
 for id in game.players:
  var p: Dictionary=game.players[id]
  if not p.wild or PlayerLifecycle.fallen(p) or PlayerVitals.current_hp(p)<=0: continue
  var assigned:=0
  for slot in game.encounter.scout_count():
   var other: Dictionary=game.encounter.scout(slot)
   if not is_same(other,agent) and game.encounter.hp(slot)>0 and other.engaged and int(other.get("target",0))==id: assigned+=1
  var threat: float=maxf(0,float(game.combat_threat.get(id,0)))
  var score: float=origin.distance_to(p.pos)+minf(3.0,assigned*1.4)-minf(2.5,threat*.12)+(0.0 if game.battlefield.clear_line(origin,p.pos) else 3.0)
  if id==previous: score-=1.1
  if score<best: best=score;selected=id
 agent.target=selected;agent.target_until=now+850;return selected
static func predict(game: Node,id: int,lead: float) -> Vector3:
 var decoy: Vector3=game.Traits.decoy_point(game,id)
 if decoy!=Vector3.INF: return decoy
 var p: Dictionary=game.players[id];var velocity: Vector3=game.combat_velocity.get(id,Vector3.ZERO)
 var aim: Vector3=p.pos+velocity.limit_length(6.0)*clampf(lead,0,.35)
 return aim if not game.battlefield.occupied(aim,.35) and game.battlefield.clear_line(p.pos,aim) else p.pos
static func trophy_chance(floor_number: int,guardian: bool,adapted: bool) -> float:
 var c:=config()
 return minf(float(c.trophy_cap),float(c.trophy_chance)+minf(float(c.trophy_depth_cap),(floor_number-1)*float(c.trophy_depth_step))+(float(c.trophy_guardian_bonus) if guardian else 0.0)+(float(c.trophy_adapted_bonus) if adapted else 0.0))

static func pursuit(game: Node,id: int,route: int) -> Vector3:
 var angle: float=route*2.39996
 var flank:=Vector3(cos(angle),0,sin(angle))*.65
 var decoy: Vector3=game.Traits.decoy_point(game,id)
 if decoy!=Vector3.INF:
  return decoy+flank if game.battlefield.clear_line(decoy,decoy+flank,.4) else decoy
 var center: Vector3=predict(game,id,.12)
 var goal: Vector3=center+flank
 return goal if not game.battlefield.occupied(goal,.4) and game.battlefield.clear_line(game.players[id].pos,goal) else game.players[id].pos
static func navigate(game: Node,from: Vector3,to: Vector3,distance: float,route: int=0) -> Vector3:
 var desired: Vector3=game.battlefield.navigate(from,to,distance,route)
 var repel:=Vector3.ZERO
 var positions: Array=[game.tactics.position] if game.encounter.hp(-1)>0 else []
 for slot in game.encounter.scout_count():
  if game.encounter.hp(slot)>0: positions.append(game.encounter.position(slot))
 for position in positions:
  var offset: Vector3=from-position;var length:=offset.length()
  if length>.001 and length<.85: repel+=offset.normalized()*(.85-length)/.85
 return game.battlefield.slide(from,desired+repel.limit_length(1.0)*distance*.65) if not repel.is_zero_approx() else desired
