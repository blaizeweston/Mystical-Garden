extends RefCounted
## Native spell/trap/graft execution. The timeline owns its records; existing
## hit, vitals, status and class owners resolve their respective outcomes.
const Traits=preload("res://combat_traits.gd")
const Grafts=preload("res://native_grafts.gd")
const Ranger=preload("res://ranger_combat.gd")
const OutgoingHits=preload("res://outgoing_hits.gd")
const HitSession=preload("res://network_session.gd")
const PlayerLifecycle=preload("res://player_lifecycle.gd")
const Conditions=preload("res://player_hit_conditions.gd")
const Protection=preload("res://player_protection.gd")
const Preview=preload("res://combat_balance_preview.gd")
var _world: WeakRef
func _init(world: Node) -> void:_world=weakref(world)
func _current() -> Node:
 var world: Node=_world.get_ref()
 return world if is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() else null

func source_current(event: Dictionary) -> bool:
 var world:=_current()
 if world==null:return false
 var p: Dictionary=world.players.get(int(event.get("owner",0)),{})
 if int(event.get("epoch",-1))!=world.participation.epoch() or not PlayerLifecycle.matches(p,int(event.get("life",-1))) or not world.Life.alive(p):return false
 if event.has("binding") and not world.network_session.matches(int(event.owner),int(event.binding)):return false
 return not event.has("graft_source") or PlayerLifecycle.matches(p,int(event.graft_source.life))

func end(event: Dictionary) -> void:
 var world:=_current()
 if world!=null:Traits.end_zone(world,event)

func route(event: Dictionary,now: int) -> void:
 var world:=_current()
 if world!=null:Ranger.tick_route(world,event,now)

func prepare(now: int) -> void:
 var world:=_current()
 if world==null:return
 for p in world.players.values():
  if not world.Life.alive(p): continue
  var last: Vector3=p.get("still_point",p.pos)
  if p.pos.distance_to(last)>.05: p.still_since=now;p.still_point=p.pos
  elif not p.has("still_since"): p.still_since=now;p.still_point=p.pos
func hit(event: Dictionary,now: int) -> void:
 var world:=_current()
 if world==null or not source_current(event):return
 var p: Dictionary=world.players[event.owner]
 if event.has("graft_source"):
  Grafts.resolve_queued(world,p,event,now)
  return
 if Traits.valid_target(world,int(event.target),int(event.token)):
  var point: Vector3=world.enemy_position(int(event.target))
  var origin: Vector3 = p.pos
  if world.battlefield.clear_line(origin,point):
   if event.has("visual"):preload("res://combat_status.gd").proc(world,str(event.visual),event.get("origin",p.pos),point,int(event.target))
   if event.stats.has("cr02_action"):
    preload("res://combat_action_events.gd").contact(world,event.stats,int(event.target),now)
   if not source_current(event):return
   if Traits.valid_target(world,int(event.target),int(event.token)):
    OutgoingHits.hit_world(world, HitSession.peer_for(p), int(event.target), origin, event.stats, now)
   if world.encounter_cleared(): world.finish_combat(int(event.owner),point)
func pulse(event: Dictionary,now: int) -> void:
 var world:=_current()
 if world==null or not source_current(event):return
 var p: Dictionary=world.players[event.owner]
 if event.kind=="snare":
  Traits.trip_snare(world,p,event,now);return
 event.next=now+1000
 if event.kind=="tide" or event.kind=="sanctuary":
  var heal_hp:=Preview.roll_heal(Preview.authored_amount(float(event.power)),Preview.HEAL_TICK_SPREAD_HP)
  for ally in world.players.values():
   if not world.Life.alive(ally) or ally.pos.distance_to(event.position)>float(event.radius) or not world.battlefield.clear_line(event.position,ally.pos): continue
   world.Life.Sustain.restore(world,ally,heal_hp,event.kind);ally[Conditions.STATE] = ally[Conditions.STATE].cleanse_slow()
   if event.ward: ally[Protection.STATE] = ally[Protection.STATE].grant(now+800,1,Time.get_ticks_msec(),world.participation.epoch())
 elif event.kind in ["growth","cinder"]:
  var targets: Array[int]=world.skill_area_targets(event.position,float(event.radius),event.position)
  for target in targets:
   var hit: Dictionary={"damage":Preview.authored_amount(float(event.power)),"trait_secondary":true}
   if event.has("graft_source"):
    hit=Grafts.secondary_stats(float(event.power))
   elif event.get("native_weaver_bloom",false):
    hit.core_hit=true
   var before: int = world.encounter.hp(target)
   OutgoingHits.hit_world(world, HitSession.peer_for(p), target, event.position, hit, now)
   if event.has("weaver_pressure"):
    var after: int = world.encounter.hp(target)
    if after < before: preload("res://weaver_combat.gd").field_contact(world,p,event)
   var source: RefCounted=event.get("class_field")
   if source!=null:
    source.publish(world,"class_field_contact","pulse",preload("res://weapon_contact.gd").token(world,target),now,{"enemy":target})
  if not targets.is_empty() and world.encounter_cleared(): world.finish_combat(int(event.owner),event.position)
