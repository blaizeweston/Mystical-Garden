extends RefCounted
## One admitted Saturation threshold, split into source-weighted moving tides.
## CombatEffectTimeline owns the record; these functions only plan/advance it.
const Sources=preload("res://affinity_status_source.gd")
const Vitals=preload("res://player_vitals.gd")
const Protection=preload("res://player_protection.gd")
const Outgoing=preload("res://outgoing_hits.gd")
const Catalog=preload("res://affinity_card_catalog.gd")
const Clock=preload("res://combat_clock.gd")
const COLOR:=Color("#82d7ec")
const PHASE_MS:=450
const RETURN_WIDTH_SCALE:=.70
const BASE_WIDTH:=.70
const BASE_PUSH:=.20
const VERSION_DATA:=[PHASE_MS,RETURN_WIDTH_SCALE,BASE_WIDTH,BASE_PUSH]

static func living_source(game: Node, source: Dictionary) -> bool:
 return Sources.current(game,source) and game.Life.alive(game.players.get(int(source.actor),{}))

## Largest-remainder allocation preserves the single event's total after rounding.
## Four small contributors never receive four independently rounded full Surges.
# Source-weighted shares and tide phases retain deterministic integer truncation.
@warning_ignore_start("integer_division")
static func allocate(rows: Array, parameter: String) -> void:
 var total:=0
 var assigned:=0
 for row: Dictionary in rows:
  total+=int(row[parameter+"_units"])
  row[parameter]=int(row[parameter+"_units"])/1000
  assigned+=int(row[parameter])
 var sorted:=rows.duplicate()
 sorted.sort_custom(func(a,b):
  var ar:=int(a[parameter+"_units"])%1000
  var br:=int(b[parameter+"_units"])%1000
  return ar>br or (ar==br and int(a.source.actor)<int(b.source.actor)))
 for index in maxi(0,roundi(total/1000.0)-assigned):sorted[index%sorted.size()][parameter]+=1

@warning_ignore_restore("integer_division")
# Source-weighted shares and tide phases retain deterministic integer truncation.
@warning_ignore_start("integer_division")
static func admit(game: Node, target: int, status: Dictionary, now: int) -> bool:
 var water=load("res://water_combat.gd")
 var threshold: int=water.SATURATION_THRESHOLD
 var queue: Array=status.pressure.duplicate(true)
 var needed:=threshold
 var by_owner:={}
 for credit: Dictionary in queue:
  if needed<=0:break
  var taken:=mini(needed,int(credit.amount))
  credit.amount-=taken;needed-=taken
  var key:=Sources.key(credit.source)
  if not by_owner.has(key):
   by_owner[key]={"source":credit.source.duplicate(true),"damage_units":0,"heal_units":0,"weight":0,
    "width":BASE_WIDTH,"push":BASE_PUSH,"ward_ms":0,"focus_percent":0,"monsoon":false}
  var row: Dictionary=by_owner[key]
  var p: Dictionary=credit.potency
  row.damage_units+=taken*int(p.get("surge_hp",water.SURGE_HP))*Sources.UNITS_PER_HP/threshold
  row.heal_units+=taken*int(p.get("surge_heal_hp",water.SURGE_HEAL_HP))*Sources.UNITS_PER_HP/threshold
  row.weight+=taken
  row.width=maxf(row.width,BASE_WIDTH+int(p.get("surge_width_cm",0))/100.0)
  row.push=maxf(row.push,BASE_PUSH+int(p.get("surge_push_cm",0))/100.0)
  row.ward_ms=maxi(row.ward_ms,int(p.get("surge_ward_ms",0)))
  row.focus_percent=maxi(row.focus_percent,int(p.get("focus_percent",0)))
  row.monsoon=row.monsoon or int(p.get("monsoon_unlock",0))>0
 if needed>0:return false
 var rows: Array=by_owner.values()
 rows.sort_custom(func(a,b):return int(a.source.actor)<int(b.source.actor))
 for row: Dictionary in rows:
  if not living_source(game,row.source):return false
  var player: Dictionary=game.players[row.source.actor]
  var prep: Dictionary=player.get(water.REFRESH,{})
  if not prep.is_empty() and prep.get("source",{}).get("life")==row.source.life and Sources.current(game,prep.source) and now<int(prep.until):
   row.heal_units+=int(row.weight)*int(prep.hp)*Sources.UNITS_PER_HP/threshold
 allocate(rows,"damage");allocate(rows,"heal")
 var destination: Vector3=game.enemy_position(target)
 var waves:=[]
 var ring_groups:={}
 var maximum:=now+PHASE_MS*2+1
 for row: Dictionary in rows:
  var origin: Vector3=game.players[row.source.actor].pos
  var end: Vector3=game.battlefield.projectile_endpoint(origin,destination,float(row.width))
  row.merge({"origin":origin,"end":end,"start":now,"previous":origin,"damaged":{},"healed":{},"ring":false,
   "target":target,"target_token":game.encounter.spawn_identity(target)},true)
  waves.append(row)
  if row.monsoon:
   var tuning: Dictionary=Catalog.DEFINITIONS.monsoon.tuning
   for index in int(tuning.waves):
    var ring: Dictionary=row.duplicate(true)
    ring.merge({"ring":true,"origin":end,"end":end,"radius":float(tuning.radius_m)+float(row.width)-BASE_WIDTH,
     "start":now+PHASE_MS+int(tuning.gap_ms)*(index+1),"damage_units":roundi(row.damage_units*float(tuning.share_percent)/100.0),
     "heal_units":roundi(row.heal_units*float(tuning.share_percent)/100.0),"damaged":{},"healed":{},"previous_radius":0.0},true)
    waves.append(ring)
    if not ring_groups.has(index):ring_groups[index]=[]
    ring_groups[index].append(ring)
    maximum=maxi(maximum,int(ring.start)+2*PHASE_MS+1)
 for group: Array in ring_groups.values():
  allocate(group,"damage");allocate(group,"heal")
 var record: Dictionary=game.effect_timeline.schedule_native({"kind":"water_tide","owner":rows[0].source.actor,
  "epoch":game.participation.epoch(),"life":rows[0].source.life,"next":now,"until":maximum,"waves":waves})
 if record.is_empty():return false # Leave pressure and earned preparation untouched.
 status.pressure=queue.filter(func(row):return int(row.amount)>0)
 status.saturation-=threshold
 for row: Dictionary in rows:game.players[row.source.actor].erase(water.REFRESH)
 var contributions:=rows.map(func(row):return {"actor":row.source.actor,"activation":row.source.activation,"pressure":row.weight,"damage_hp":row.damage,"healing_hp":row.heal})
 preload("res://diagnostic_journal.gd").event("combat","water_tidal_return",{"target":target,"contributors":contributions,"waves":waves.size(),"threshold":threshold})
 return true

@warning_ignore_restore("integer_division")
static func current(game: Node, record: Dictionary) -> bool:
 return game.multiplayer.is_server() and int(record.epoch)==game.participation.epoch() and record.waves.any(func(wave):return living_source(game,wave.source))

static func contact(game: Node, wave: Dictionary, point: Vector3, previous: Vector3, current_point: Vector3, radius: float, returning: bool) -> bool:
 if wave.ring:
  var distance: float=wave.origin.distance_to(point)
  var low:=minf(float(wave.get("previous_radius",0)),radius)
  var high:=maxf(float(wave.get("previous_radius",0)),radius)
  return distance>=maxf(0,low-.25) and distance<=high+.25 and game.battlefield.combat_sight(wave.origin,point)
 var width:=float(wave.width)*(RETURN_WIDTH_SCALE if returning else 1.0)
 var nearest:=Geometry3D.get_closest_point_to_segment(point,previous,current_point)
 return point.distance_to(nearest)<=width and game.battlefield.combat_sight(nearest,point)

# Source-weighted shares and tide phases retain deterministic integer truncation.
@warning_ignore_start("integer_division")
static func advance(game: Node, record: Dictionary, now: int) -> void:
 for wave: Dictionary in record.waves:
  if not living_source(game,wave.source) or now<int(wave.start):continue
  var age:=now-int(wave.start)
  var returning:=age>=PHASE_MS
  var phase:=mini(1,int(age/PHASE_MS))
  var fraction:=clampf(float(age-phase*PHASE_MS)/PHASE_MS,0,1)
  # Crossing the turn in one frame still resolves the final outward segment.
  if returning and not wave.get("turned",false):
   resolve_segment(game,wave,wave.previous,wave.end,float(wave.get("radius",0)),false,now)
   wave.turned=true;wave.previous=wave.end;wave.previous_radius=float(wave.get("radius",0))
  var point: Vector3=wave.end.lerp(wave.origin,fraction) if returning else wave.origin.lerp(wave.end,fraction)
  var radius:=float(wave.get("radius",0))*(1-fraction if returning else fraction)
  if not wave.get("shown_"+str(phase),false):
   wave["shown_"+str(phase)]=true
   var shape: String=("tidal_ring_return" if returning else "tidal_ring") if wave.ring else ("riptide_return" if returning else "riptide")
   var visible_width:=float(wave.get("radius",wave.width))*(RETURN_WIDTH_SCALE if returning and not wave.ring else 1.0)
   game.emit_combat_event("ability",shape,wave.origin if not returning else wave.end,wave.end if not returning else wave.origin,PHASE_MS/1000.0,COLOR,visible_width,wave.source.actor,{"label":"Monsoon return" if returning and wave.ring else "Restorative tide" if returning else "Monsoon" if wave.ring else "Tidal Return"})
  resolve_segment(game,wave,wave.previous,point,radius,returning,now)
  wave.previous=point;wave.previous_radius=radius
 record.next=now+1

@warning_ignore_restore("integer_division")
static func resolve_segment(game: Node, wave: Dictionary, previous: Vector3, point: Vector3, radius: float, returning: bool, now: int) -> void:
 if returning:
  for peer in game.Life.living_ids(game):
   var player: Dictionary=game.players[peer]
   if wave.healed.has(peer) or not contact(game,wave,player.pos,previous,point,radius,true):continue
   wave.healed[peer]=true
   game.Life.Sustain.restore(game,player,int(wave.heal),"tidal_return/"+str(wave.source.actor),-1,wave.source.actor)
   load("res://water_combat.gd").cleanse(player)
   if int(wave.ward_ms)>0:player[Protection.STATE]=player[Protection.STATE].grant(now+int(wave.ward_ms),1,Time.get_ticks_msec(),game.participation.epoch())
  return
 for target in range(-1,game.encounter.scout_count()):
  if game.persistence_session.is_blocked() or not living_source(game,wave.source):return
  if not game.encounter.alive(target):continue
  var token: int=game.encounter.spawn_identity(target)
  var key:=str([target,token])
  var at: Vector3=game.enemy_position(target)
  if wave.damaged.has(key) or not contact(game,wave,at,previous,point,radius,false):continue
  wave.damaged[key]=true
  var hp:=int(wave.damage)
  if target==int(wave.target) and token==int(wave.target_token):hp=roundi(hp*(1+float(wave.focus_percent)/100.0))
  if hp<=0:continue
  Outgoing.hit_world(game,int(wave.source.actor),target,wave.origin,{"stat_affinity":"Surge","damage":0.0,"affinity_hp":hp,"trait_secondary":true,"core_hit":true,"card_secondary":true,"knockback":float(wave.push)-Outgoing.NATIVE_PUSH_METRES},now)
