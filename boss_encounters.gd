extends RefCounted
# Expedition-only threats. Decisions are cached by encounter and survive combat resets.
const FIRST_FLOOR=10
const CHANCE=0.025
const Catalog=preload("res://enemy_catalog.gd")
const Lair=preload("res://boss_lair_fights.gd")
const Phases=preload("res://boss_phase_fights.gd")
const Orchard=preload("res://orchard_moves.gd")
static func choose(floor_number: int,site: int,seed_value: int,used: Array) -> int:
 if site>=3 or floor_number<FIRST_FLOOR: return -1
 var preview=preload("res://combat_balance_preview.gd")
 if preview.playtest and floor_number==preview.ORCHARD_FLOOR and not used.has(Lair.Routes.ORCHARD):
  return Lair.Routes.ORCHARD
 var random=RandomNumberGenerator.new();random.seed=seed_value+floor_number*104729
 if random.randf()>=CHANCE: return -1
 var pool: Array=[]
 for kind in Catalog.all().size():
  if Catalog.get_kind(kind).get("boss",false) and not used.has(kind): pool.append(kind)
 return -1 if pool.is_empty() else int(pool[random.randi_range(0,pool.size()-1)])
static func prepare(game: Node) -> void:
 var key=str(game.encounter_number)
 if not game.boss_floors.has(key):
  var kind=choose(game.encounter_number,game.destination,game.map_seed,game.used_bosses)
  game.boss_floors[key]=kind
  if kind>=0: game.used_bosses.append(kind)
 game.boss_kind=int(game.boss_floors[key]) if game.destination<3 else -1
 game.boss_phase=0;game.boss_moves=0;game.enemy_hazards.clear()
static func phase(game: Node) -> int:
 return game.Life.Vitals.boss_phase(game.enemy_hp,game.encounter_health())
static func tick(game: Node,delta: float,now: int) -> void:
 if game.enemy_hp<=0: return
 var lair:=Lair.Routes.supports(game.boss_kind)
 if lair and game.enemy_engaged:Lair.observe(game,now)
 if game.boss_kind==Phases.NEST:Phases.observe_brood(game,now)
 if game.enemy_winding_up:
  if now>=game.enemy_strike_at:
   if game.has_meta(&"combat_affinity_ruleset"):
    preload("res://frost_combat.gd").with_attacker(game,-1,resolve.bind(game,now))
   else: resolve(game,now)
  return
 if now<game.enemy_stagger_until: return
 var target=game.Director.target(game,game.enemy_pos,game.leader_brain,now)
 if target==0: return
 var victim: Vector3=game.players[target].pos
 if not game.enemy_engaged and game.enemy_pos.distance_to(victim)>12: return
 game.enemy_engaged=true
 var definition: Dictionary=game.Enemies.get_kind(game.boss_kind)
 var next_phase=phase(game)
 if Phases.supports(game.boss_kind):
  if Phases.advance_phase(game,next_phase,now):return
 elif next_phase!=game.boss_phase:
  game.boss_phase=next_phase
  if lair:Lair.begin_phase(game,next_phase,now)
 if now<game.enemy_ready_at: return
 var next_move: String=definition.moves[game.boss_moves%definition.moves.size()]
 var reach:=float(definition.range)
 var distance: float=game.enemy_pos.distance_to(victim)
 var remote_lair_cast:=lair and next_move=="grasping_pool" and Lair.adaptive(game,target,"bank")
 if game.boss_kind==Lair.Routes.ORCHARD:
  next_move=Orchard.next_move(definition.moves,game.boss_phase,game.boss_moves,int(game.leader_brain.get("orchard_phase_start",0)))
  remote_lair_cast=next_move=="root_sweep" and Lair.adaptive(game,target,"outer")
  if not remote_lair_cast and distance>Orchard.reach(next_move,game.boss_phase):
   next_move="falling_fruit"
  reach=Orchard.reach(next_move,game.boss_phase)
 if not remote_lair_cast and distance>reach and (now>=game.rooted_until or game.boss_kind==Lair.Routes.ORCHARD):
  if now>=game.rooted_until:
   game.enemy_pos=game.Director.navigate(game,game.enemy_pos,victim,float(definition.speed)*delta*preload("res://frost_combat.gd").motion_scale(game.leader_brain,now,true))
  return
 if lair:
  if not Lair.commit(game,next_move,target,now) and game.boss_kind==Lair.Routes.ORCHARD and next_move!="falling_fruit" and distance<=Orchard.reach("falling_fruit",game.boss_phase):
   Lair.commit(game,"falling_fruit",target,now)
  return
 if Phases.supports(game.boss_kind):
  Phases.commit(game,next_move,target,now)
static func hazard(game: Node,point: Vector3,radius: float,now: int,duration: int,kind: String,delay: int=900,damage: float=1.0,boss_move: String="") -> void:
 var reserved:=0
 if game.enemy_winding_up and game.enemy_hp>0:
  var plan: Dictionary=game.leader_brain.get("lair_plan",game.leader_brain.get("phase_plan",{}))
  reserved=plan.get("areas",[]).size()
 if game.enemy_hazards.size()>=32-reserved: return
 game.enemy_hazard_serial+=1
 var hit: float=game.Director.Balance.hazard_hit(game,kind,damage,boss_move)
 game.enemy_hazards.append({"id":game.enemy_hazard_serial,"point":point,"radius":radius,"activate":now+delay,"until":now+delay+duration,"next":now+delay,"kind":kind,"damage":hit})
static func resolve(game: Node,now: int) -> void:
 var damage: float=game.Director.Balance.boss_hit(game,game.Enemies.get_kind(game.boss_kind),game.enemy_attack_mode)
 game.enemy_winding_up=false
 var recovery:=maxi(900,int(game.Enemies.get_kind(game.boss_kind).recovery)-game.boss_phase*250)
 if game.boss_kind==Lair.Routes.ORCHARD:
  var orchard_plan: Dictionary=game.leader_brain.get("lair_plan",{})
  recovery=int(orchard_plan.get("follow_ms",recovery))
 game.enemy_ready_at=now+recovery+game.moss_recovery_bonus
 game.moss_recovery_bonus=0
 var plan: Dictionary=game.leader_brain.get("lair_plan",game.leader_brain.get("phase_plan",{}))
 var epoch: int=game.combat_epoch
 if Lair.Routes.supports(game.boss_kind):
  game.leader_brain.erase("lair_plan")
  Lair.resolve(game,plan,now,damage)
 elif Phases.supports(game.boss_kind):
  game.leader_brain.erase("phase_plan")
  Phases.resolve(game,plan,now,damage)
 if epoch==game.combat_epoch:
  game.enemy_ready_at=preload("res://oracle_omens.gd").release_attack(game.leader_brain,plan,game.enemy_ready_at)

static func tick_hazards(game: Node,now: int) -> void:
 if game.enemy_hp<=0 and game.boss_kind>=0: game.enemy_hazards.clear();return
 for entry in game.enemy_hazards.duplicate():
  if now>=int(entry.until): game.enemy_hazards.erase(entry);continue
  if now<int(entry.next): continue
  entry.next=now+1000
  game.hit_players(entry.point,float(entry.radius),now,float(entry.damage),700 if str(entry.kind) in ["nest","lair_pool","web"] else 0,false)
static func hints(game: Node) -> Array:
 var now:=Time.get_ticks_msec()
 var result:=Lair.hints(game,now)
 result.append_array(Phases.hints(game,now))
 for entry in game.enemy_hazards:
  var at: Vector3=entry.point
  var hint: Dictionary={"id":-1000-int(entry.id),"role":"hazard","from":[at.x,0,at.z],"to":[at.x,0,at.z],"radius":entry.radius,"active":now>=int(entry.activate)}
  if str(entry.kind).begins_with("lair_"):
   hint.lair="water" if entry.kind in ["lair_tide","lair_pool"] else "root"
   if entry.kind==Lair.FRUIT_KIND:hint.lair="fruit"
   if not hint.active:hint.remaining=maxf(0.0,(int(entry.activate)-now)*.001)
  if entry.kind=="nest" or entry.kind=="bloom_spores":
   hint.lair="memory" if entry.kind=="bloom_spores" else "nursery"
   if not hint.active:hint.remaining=maxf(0.0,(int(entry.activate)-now)*.001)
  var regular: Dictionary=preload("res://enemy_move_feedback.gd").HAZARDS.get(entry.kind,{})
  if not regular.is_empty():
   hint.hazard_kind=entry.kind
   if not hint.active:
    hint.cue=regular.label
    hint.remaining=maxf(0.0,(int(entry.activate)-now)*.001)
  result.append(hint)
 return result
static func owns_warnings(kind: int) -> bool:
 return Lair.Routes.supports(kind) or Phases.supports(kind)

static func exposed(game: Node, now: int) -> bool:
 return owns_warnings(game.boss_kind) and now<int(game.leader_brain.get("lair_open",{}).get("until",0))

static func seed_species(random: RandomNumberGenerator) -> int:
 # Roll tier first: high tiers do not get diluted when low-tier content grows.
 var roll=random.randf();var tier=3 if roll<.25 else 4 if roll<.8 else 5
 var seeds: Array=preload("res://seed_catalog.gd").DEFINITIONS
 var pool: Array=[]
 for i in seeds.size():
  if int(seeds[i].tier)==tier: pool.append(i)
 return int(pool[random.randi_range(0,pool.size()-1)]) if not pool.is_empty() else 0

static func warning_width(game: Node) -> float:
 if game.enemy_attack_mode=="memory_lance": return .8+(.7 if game.enemy_mutations&game.Enemies.REACH else 0)
 if game.enemy_attack_mode in ["root_sweep","remembered_rend"]: return 1.1+game.boss_phase*.2
 return 1.2
static func warning_radius(game: Node) -> float:
 if game.enemy_attack_mode=="memory_lance":return 1.4
 if game.enemy_attack_mode in ["root_sweep","remembered_rend"]:return game.active_radius*.5
 if game.enemy_attack_mode in ["orchard_march","drowned_surge","matriarch_lunge"]:return game.active_radius*.7
 return game.active_radius
