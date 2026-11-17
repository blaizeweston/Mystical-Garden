extends RefCounted
const Composition=preload("res://wilds_composition.gd")
const Balance=preload("res://enemy_balance.gd")
## Transient host encounter pressure. Never applies damage or consumes loot RNG.
const WARNING_MS := 3000
const SAFE_DISTANCE := 6.0
static func interval(cycle: int, wave: int) -> int:
 if Balance.Preview.enabled:return Balance.pressure_interval(cycle,wave)
 return maxi(18000,35000-maxi(0,cycle-1)*2000-wave*1500)
static func capacity(game: Node) -> int:
 return mini(game.EncounterConfig.MAX_SCOUTS,game.EncounterConfig.SOLO_SCOUT_LIMIT+Balance.extra_scouts(int(game.Director.config().coop_extra_scouts))*(game.Director.party_size(game)-1))
static func living(game: Node) -> int:
 return game.encounter.living_scout_count()
static func safe(game: Node,at: Vector3) -> bool:
 if not at.is_finite() or game.battlefield.occupied(at,.5):return false
 if at.distance_to(game.battlefield.entry)<3 or at.distance_to(game.battlefield.advance)<3:return false
 for player in game.players.values():
  if game.Life.alive(player) and player.pos.distance_to(at)<SAFE_DISTANCE:return false
 if game.encounter.hp(-1)>0 and at.distance_to(game.enemy_pos)<1.5:return false
 for slot in game.encounter.scout_count():
  if game.encounter.hp(slot)>0 and game.encounter.position(slot).distance_to(at)<1.5:return false
 return true
static func plan(game: Node,wave: int) -> Array:
 var result: Array=[];var pool: Array[int]=[]
 for kind in game.Enemies.all().size():
  var definition: Dictionary=game.Enemies.get_kind(kind)
  if not definition.get("boss",false) and not game.Enemies.is_support(kind) and game.Enemies.in_biome(definition,game.destination) and game.encounter_number>=int(definition.unlock):pool.append(kind)
 if pool.is_empty():return result
 var rng:=RandomNumberGenerator.new();rng.seed=int(game.map_seed)+wave*104729
 var desired:=mini(4,1+(wave-1)/2+mini(1,game.difficulty_cycle/3)+(game.Director.party_size(game)-1)/2)
 desired=mini(desired,capacity(game)-living(game))
 var sites: Array=game.battlefield.spawn_points.duplicate()
 while not sites.is_empty() and result.size()<desired:
  var at: Vector3=sites.pop_at(rng.randi_range(0,sites.size()-1))
  if not safe(game,at):continue
  var separated:=true
  for other in result:
   if at.distance_to(other.pos)<2:separated=false
  if separated:
   var previous: int=game.enemy_kind if result.is_empty() else result.back().kind
   result.append({"pos":at,"kind":Composition.reinforcement(game,pool,at,rng,previous)})
 return result
static func tick(game: Node,now: int) -> void:
 if game.session=="Guest":return
 if game.difficulty_cycle<=0 or game.boss_kind>=0 or game.destination==game.Campaign.HEART or game.Life.living_ids(game).is_empty() or game.encounter_cleared():
  game.leader_brain.erase("pressure");game.pressure_at=0;return
 if not game.leader_brain.has("pressure"):game.leader_brain.pressure={"wave":0,"pending":[]}
 var state: Dictionary=game.leader_brain.pressure
 if Balance.Preview.enabled and int(state.get("spawned_waves",0))>=Balance.pressure_limit(game.difficulty_cycle):
  game.pressure_at=0;return
 if game.pressure_at==0:game.pressure_at=now+interval(game.difficulty_cycle,0);return
 if now<game.pressure_at:return
 if state.pending.is_empty():
  state.wave+=1;state.pending=plan(game,int(state.wave))
  game.pressure_at=now+(WARNING_MS if not state.pending.is_empty() else interval(game.difficulty_cycle,int(state.wave)))
  if not state.pending.is_empty():
   game.status="Corruption stirs! Reinforcements emerge in 3 seconds."
   game.Journal.event("combat","pressure_warning",{"wave":state.wave,"count":state.pending.size(),"floor":game.encounter_number})
  return
 var spawned:=0;var skipped:=0
 for entry in state.pending:
  if living(game)>=capacity(game) or not safe(game,entry.pos):skipped+=1;continue
  var slot: int=game.encounter.first_open_scout_slot()
  if slot>=game.EncounterConfig.MAX_SCOUTS:skipped+=1;continue
  var growth: int=game.Enemies.tier(game.encounter_number,game.difficulty_cycle)
  var scout: Dictionary=game.make_scout(int(entry.kind),entry.pos,slot,game.current_mutations(int(entry.kind),growth,int(state.wave)*17+slot),growth)
  scout.engaged=true;scout.ready=now+700;scout.stagger_until=now+700;scout.summoned=true
  if Balance.Preview.enabled:
   scout.max_hp=Balance.reinforcement_hp(int(scout.max_hp));scout.hp=scout.max_hp
  if game.encounter.register_scout(scout,slot)>=0:spawned+=1
  else:skipped+=1
 if Balance.Preview.enabled and spawned>0:state.spawned_waves=int(state.get("spawned_waves",0))+1
 state.pending=[];game.pressure_at=now+interval(game.difficulty_cycle,int(state.wave))
 game.Journal.event("combat","pressure_reinforcements",{"wave":state.wave,"spawned":spawned,"unsafe_or_full":skipped,"floor":game.encounter_number})
static func hints(game: Node,now: int=-1) -> Array:
 var result: Array=[]
 if game.encounter_cleared() or not game.leader_brain.has("pressure"):return result
 if now<0:now=Time.get_ticks_msec()
 var state: Dictionary=game.leader_brain.pressure
 for index in state.pending.size():
  var at: Vector3=state.pending[index].pos
  result.append({"id":-900000-int(state.wave)*10-index,"role":"reinforcement","from":[at.x,0,at.z],"to":[at.x,0,at.z],"radius":1.1,"remaining":maxf(0,(game.pressure_at-now)/1000.0)})
 return result
