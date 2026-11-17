extends RefCounted
## Deterministic encounters select from the existing biome and unlock catalog.
const Catalog=preload("res://enemy_catalog.gd")
const PURSUIT=["swipe","charge","pounce","skirmish","stomp"]
const CONTROL=["volley","artillery","snare"]
const PREFERRED={
 "swipe":[12,3,5,14],
 "charge":[3,10,11,18],
 "pounce":[11,3,1,15],
 "skirmish":[10,11,1,19],
 "stomp":[1,12,3,15],
 "volley":[0,11,8,10],
 "artillery":[4,11,0,15],
 "snare":[0,2,8,10],
 "brood":[1,11,4,19],
}

static func roster(game: Node, count: int) -> Array[int]:
 var roles: Array[int]=[]
 if count<=0:return roles
 var floor_number: int=game.participation.floor()
 var site: int=game.participation.route()
 if game.tactics.boss_kind>=0 or site==game.Campaign.HEART:
  for i in count:roles.append(Catalog.choose(site if site<game.Campaign.HEART else game.Campaign.HOLLOW,floor_number,i,game.participation.seed()))
  return roles
 var pool:=eligible(site,floor_number)
 var primary: Dictionary=Catalog.get_kind(game.enemy_kind)
 var options: Array=PREFERRED.get(primary.role,[])
 var fighters: Array[int]=[]
 var ranged: Array[int]=[]
 var partners: Array[int]=[]
 for kind in pool:
  var role: String=Catalog.get_kind(kind).role
  if role in PURSUIT:fighters.append(kind)
  if role in CONTROL:ranged.append(kind)
  if options.has(kind) and kind!=game.enemy_kind:partners.append(kind)
 var rng:=RandomNumberGenerator.new()
 rng.seed=int(game.participation.seed())+site*8191+floor_number*103
 # Keep a frontline combatant in the pack even with a support or caster modifier.
 roles.append(pick(fighters,rng,game.enemy_kind))
 if count==1:return roles
 var partner:=pick(partners,rng,roles[0]) if not partners.is_empty() else pick(ranged,rng,game.enemy_kind)
 roles.append(partner)
 # Additional positions reinforce the same fight before another modifier can enter.
 for index in range(2,count):
  var field:=ranged if index%3==2 and floor_number>=4 and not ranged.is_empty() else fighters
  var chosen:=pick(field,rng,roles.back())
  roles.append(chosen)
 if floor_number>=10 and count>=6 and game.encounter_party_size>=2:
  var deep: Array[int]=[]
  for kind in partners:
   if kind!=partner and Catalog.is_support(kind):deep.append(kind)
  if not deep.is_empty() and not Catalog.is_support(partner):roles[count-1]=pick(deep,rng,-1)
 return roles

static func eligible(site: int, floor_number: int) -> Array[int]:
 var result: Array[int]=[]
 for kind in Catalog.all().size():
  var definition:=Catalog.get_kind(kind)
  if not definition.get("boss",false) and floor_number>=int(definition.unlock) and Catalog.in_biome(definition,site):
   result.append(kind)
 return result

static func pick(options: Array[int], rng: RandomNumberGenerator, avoid: int) -> int:
 if options.is_empty():return 0
 var candidates:=options.duplicate()
 if candidates.size()>1:candidates.erase(avoid)
 return candidates[rng.randi_range(0,candidates.size()-1)]

static func partner_position(game: Node, at: Vector3) -> bool:
 return at.distance_to(game.battlefield.entry)>=5.0 and at.distance_to(game.battlefield.advance)>=2.4 and not game.battlefield.occupied(at,.5)

static func companion_spawn(game: Node, route: int) -> Vector3:
 for distance in [3.8,4.8,5.8]:
  for step in 8:
   var angle: float=(step+posmod(int(game.participation.seed()),8))*TAU/8.0
   var at: Vector3=game.tactics.position+Vector3(cos(angle),0,sin(angle))*distance
   if not partner_position(game,at) or not game.battlefield.clear_line(game.tactics.position,at,.45):continue
   var position: Vector3=game.Director.spawn(game,at,route)
   if position.is_finite() and position.distance_to(at)<.15:return position
 return Vector3.INF

static func reinforcement(game: Node, pool: Array[int], at: Vector3, rng: RandomNumberGenerator, previous: int) -> int:
 var choices: Array[int]=[]
 var open: bool=not game.battlefield.procedural or game.battlefield.floor_distance(at)>=2.5
 for kind in pool:
  var role: String=Catalog.get_kind(kind).role
  if role in PURSUIT or (open and role in CONTROL):choices.append(kind)
 return pick(choices if not choices.is_empty() else pool,rng,previous)
