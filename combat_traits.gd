extends RefCounted
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const Ranger=preload("res://ranger_combat.gd")
const Reaper=preload("res://reaper_combat.gd")
const Grafts=preload("res://native_grafts.gd")
const Preview=preload("res://combat_balance_preview.gd")
# Historical effect vocabulary remains for profile-schema validation only. Active native effects have explicit owners.
const KEYS: Array=["brittle","shatter_damage","brace","mark_damage","echo","echo_redirect","death_charge","tide_pool","pool_ward","pool_radius","suppress","decoy","decoy_duration","link","link_damage","link_brittle","counter_damage","counter_stagger","ward_on_block","directional_guard","spread_bind","growth_field","precision","trap_power","reaper_momentum","veil_mark","protect_growth","omen","loot_attract","cinder_trail","chorus_pulse","pierce"]
static func target_state(game: Node,target: int) -> Dictionary:
 if target==-1: return game.enemy_traits
 if not game.encounter.scout(target).has("traits"): game.encounter.scout(target).traits={}
 return game.encounter.scout(target).traits
static func player_id(game: Node,p: Dictionary) -> int:
 for id in game.players:
  if is_same(game.players[id],p): return int(id)
 return 0
static func valid_target(game: Node,target: int,token: int=-1) -> bool:
 return game.encounter.alive(target,token)
static func other_target(game: Node,target: int,point: Vector3) -> int:
 var result:=-2;var distance:=3.0
 for candidate in range(-1,game.encounter.scout_count()):
  if candidate==target or not valid_target(game,candidate): continue
  var at: Vector3=game.enemy_position(candidate);var length:=point.distance_to(at)
  if length<distance and game.battlefield.clear_line(point,at): result=candidate;distance=length
 return result
static func augment_hit(game: Node,p: Dictionary,target: int,stats: Dictionary,now: int,_graft_contact: Dictionary={}) -> Dictionary:
 var hit:=stats.duplicate(true)
 var damage:=Preview.authored_amount(float(hit.damage))
 if not hit.get("trait_secondary",false):
  if now<int(p.get("counter_until",0)):
   preload("res://combat_status.gd").proc(game,"counter",p.pos,game.enemy_position(target),target)
   damage+=Preview.authored_amount(float(p.get("counter_power",1)))
   p.counter_until=0
  if int(p.get("grave_charges",0))>0 and Reaper.spends_class_charge(p,hit):
   damage+=1;p.grave_charges-=1
   preload("res://combat_status.gd").proc(game,"momentum",p.pos,game.enemy_position(target),target)
 hit.damage=damage
 return hit

static func queue_hit(game: Node,p: Dictionary,target: int,stats: Dictionary,now: int,delay: int,carry: bool,origin: Vector3=Vector3.INF,visual: String="",graft_source: Dictionary={}) -> void:
 if target==-2 or game.trait_events.size()>=24: return
 var hit: Dictionary=stats.duplicate(true) if carry else {"reach":stats.get("reach",2.0)}
 var amount:=Preview.followup_amount(stats,carry,visual=="chorus")
 hit.damage=amount
 hit.trait_secondary=true
 if not graft_source.is_empty(): hit.core_hit=true
 game.trait_events.append({"kind":"hit","epoch":game.participation.epoch(),"owner":player_id(game,p),"life":PlayerLifecycle.generation(p),"target":target,"token":-1 if target==-1 else game.encounter.token(target),"due":now+delay,"stats":hit,"visual":visual if not visual.is_empty() else "link" if carry else "echo","origin":p.pos if origin==Vector3.INF else origin})
 if not graft_source.is_empty(): game.trait_events.back().graft_source=graft_source
static func zone(game: Node,p: Dictionary,kind: String,point: Vector3,radius: float,duration: int,power: float,now: int,ward: bool=false,class_field: RefCounted=null,graft_source: Dictionary={}) -> Dictionary:
 if game.trait_events.size()>=24: return {}
 var id:=player_id(game,p)
 for event in game.trait_events.duplicate():
  if event.kind==kind and int(event.owner)==id and event.has("graft_source")==not graft_source.is_empty():
   end_zone(game,event);game.trait_events.erase(event)
 game.trait_events.append({"kind":kind,"epoch":game.participation.epoch(),"owner":id,"life":PlayerLifecycle.generation(p),"position":point,"radius":radius,"until":now+duration,"next":now,"power":power,"ward":ward})
 if class_field!=null: game.trait_events.back().class_field=class_field
 if not graft_source.is_empty(): game.trait_events.back().graft_source=graft_source
 var color:=Color("#e7a15f") if kind=="cinder" else Color("#88d7de") if kind=="tide" else Color("#d9a4c3") if kind=="decoy" else Color("#97c978")
 game.emit_combat_event("field",kind+"_zone",point,point,duration/1000.0,color,radius,0)
 game.trait_events.back().visual_id=game.combat_event_serial
 return game.trait_events.back()
static func after_hit(game: Node,p: Dictionary,target: int,stats: Dictionary,_now: int,killed: bool) -> void:
 if stats.get("trait_secondary",false):return
 if killed and (target==-1 or not game.encounter.scout(target).get("summoned",false)) and float(stats.get("death_charge",0))>0 and Reaper.spends_class_charge(p,stats):
  var graft_charges := Grafts.graft_charges(p)
  p.grave_charges=mini(Grafts.DEATH_CHARGE_CAP-graft_charges,int(p.get("grave_charges",0))+maxi(1,roundi(float(stats.death_charge))))

static func decoy_point(game: Node,id: int) -> Vector3:
 for event in game.trait_events:
  if int(event.get("owner",0))!=id or not event_in_current_life(game,event): continue
  if event.kind=="snare" and preload("res://combat_clock.gd").now()<int(event.get("ranger_decoy_until",0)) and Ranger.source_live(game,event):
   return event.position
 return Vector3.INF
static func place_snare(game: Node,p: Dictionary,point: Vector3,skill: Dictionary,stats: Dictionary,now: int) -> Dictionary:
 var owner:=player_id(game,p)
 var replaced: Array = []
 for event in game.trait_events:
  if event.kind=="snare" and event.owner==owner and event.skill.get("slot",0)==skill.get("slot",0):
   replaced.append(event)
 if game.trait_events.size()-replaced.size()>=24: return {}
 for event in replaced:
  end_zone(game,event)
  game.trait_events.erase(event)
 var duration:=preload("res://class_skill_balance.gd").trap_duration(skill,stats)
 var radius:=float(skill.get("radius",1.05))
 var decoy: bool = skill.has("ranger_nodes") and skill.slot==0 and skill.subclass_focus=="snarekeeper"
 game.emit_combat_event("field","luring_snare_zone" if decoy else "snare_zone",point,point,duration/1000.,Color(skill.color),radius,0)
 var placed := {"kind":"snare","epoch":game.participation.epoch(),"owner":owner,"life":PlayerLifecycle.generation(p),
  "position":point,"radius":radius,"until":now+duration,"next":now+250,"skill":skill.duplicate(true),
  "stats":stats.duplicate(true),"seen":{},"visual_id":game.combat_event_serial}
 if decoy:
  placed.ranger_decoy_until = now+duration
 game.trait_events.append(placed)
 return placed

static func trip_snare(game: Node,p: Dictionary,event: Dictionary,now: int) -> void:
 var skill: Dictionary=event.skill
 var entrants: Array[int]=game.skill_area_targets(event.position,event.radius,event.position)
 var contact=preload("res://weapon_contact.gd")
 for target in entrants.duplicate():
  if event.seen.has(contact.token(game,target)):entrants.erase(target)
 var targets: Array[int]=entrants.duplicate()
 var ranger := skill.has("ranger_nodes")
 var corridor := Ranger.corridor_targets(game,event) if ranger else {}
 var endpoint_targets := targets.duplicate()
 for target in corridor:
  if not targets.has(target):
   targets.append(target)
 if targets.is_empty():return
 skill.effect_origin=event.position
 var trap_stats: Dictionary = event.stats.merged({"ranger_trap_contact":true},true)
 for target in targets:
  if not valid_target(game,target):continue
  var token: String=contact.token(game,target)
  if event.seen.has(token):continue
  event.seen[token]=true
  var victims: Array[int]=[target]
  var only_corridor := corridor.has(target) and not endpoint_targets.has(target)
  var origin: Vector3 = corridor[target] if only_corridor else event.position
  var chosen := Ranger.trap_hit(game,p,event,target,origin,entrants.has(target) or corridor.has(target),only_corridor,now) if ranger else skill
  if not only_corridor and event.stats.has("cr02_action"):
   preload("res://combat_action_events.gd").contact(game,event.stats,target,now,false,event.position)
  game.apply_skill_targets(p,victims,chosen,trap_stats,now)
  var at: Vector3=game.enemy_position(target)
  game.emit_combat_event("proc",skill.name,origin,at,.45,Color(skill.color),0.0,target)
  preload("res://diagnostic_journal.gd").event("combat","class_trap_contact",{"actor":event.owner,
   "skill":skill.name,"target":target,"target_token":token})
  if game.encounter_cleared():
   game.finish_combat(int(event.owner),at)
   return
 if not ranger and skill.mode=="subclass" and int(skill.get("second",-1))==0 and not event.get("echoed",false):
  event.echoed=true
  load("res://subclass_combat.gd").echo(game,p,event.position,targets,Color(skill.color),now)
  if game.encounter_cleared():game.finish_combat(int(event.owner),event.position)

static func event_in_current_life(game: Node,event: Dictionary) -> bool:
 var owner: Dictionary=game.players.get(int(event.get("owner",0)),{})
 return int(event.get("epoch",-1))==game.participation.epoch() and PlayerLifecycle.matches(owner,int(event.get("life",-1)))

static func tick(game: Node,now: int) -> void:
 for p in game.players.values():
  if not game.Life.alive(p): continue
  var last: Vector3=p.get("still_point",p.pos)
  if p.pos.distance_to(last)>.05: p.still_since=now;p.still_point=p.pos
  elif not p.has("still_since"): p.still_since=now;p.still_point=p.pos
 for event in game.trait_events.duplicate():
  if not event_in_current_life(game,event) or not game.Life.alive(game.players[event.owner]): end_zone(game,event);game.trait_events.erase(event);continue
  var p: Dictionary=game.players[event.owner]
  if event.has("graft_source") and not PlayerLifecycle.matches(p,int(event.graft_source.life)):
   end_zone(game,event);game.trait_events.erase(event);continue
  if event.kind=="hit":
   if now<int(event.due): continue
   game.trait_events.erase(event)
   if event.has("graft_source"):
    Grafts.resolve_queued(game,p,event,now)
    continue
   if valid_target(game,int(event.target),int(event.token)):
    var point: Vector3=game.enemy_position(int(event.target))
    var origin: Vector3 = p.pos
    if game.battlefield.clear_line(origin,point):
     if event.has("visual"):preload("res://combat_status.gd").proc(game,str(event.visual),event.get("origin",p.pos),point,int(event.target))
     if event.stats.has("cr02_action"):
      preload("res://combat_action_events.gd").contact(game,event.stats,int(event.target),now)
     if not event_in_current_life(game,event):continue
     if valid_target(game,int(event.target),int(event.token)):
      game.apply_weapon_hit(p,int(event.target),origin,event.stats,now)
     if game.encounter_cleared(): game.finish_combat(int(event.owner),point)
   continue
  if now>=int(event.until): end_zone(game,event);game.trait_events.erase(event);continue
  if event.has("ranger_route"): Ranger.tick_route(game,event,now)
  if now<int(event.next): continue
  if event.kind=="snare":
   trip_snare(game,p,event,now);continue
  event.next=now+1000
  if event.kind=="tide" or event.kind=="sanctuary":
   var heal_hp:=Preview.roll_heal(Preview.authored_amount(float(event.power)),Preview.HEAL_TICK_SPREAD_HP)
   for ally in game.players.values():
    if not game.Life.alive(ally) or ally.pos.distance_to(event.position)>float(event.radius) or not game.battlefield.clear_line(event.position,ally.pos): continue
    game.Life.Sustain.restore(game,ally,heal_hp,event.kind);ally.slow_until=0
    if event.ward: game.grant_guard(ally,now+800,1)
  elif event.kind in ["growth","cinder"]:
   var targets: Array[int]=game.skill_area_targets(event.position,float(event.radius),event.position)
   for target in targets:
    var hit: Dictionary={"damage":Preview.authored_amount(float(event.power)),"trait_secondary":true}
    if event.has("graft_source"):
     hit=Grafts.secondary_stats(float(event.power))
    elif event.get("native_weaver_bloom",false):
     hit.core_hit=true
    var before: int = game.encounter.hp(target)
    game.apply_weapon_hit(p,target,event.position,hit,now)
    if event.has("weaver_pressure"):
     var after: int = game.encounter.hp(target)
     if after < before: preload("res://weaver_combat.gd").field_contact(game,p,event)
    var source: RefCounted=event.get("class_field")
    if source!=null:
     source.publish(game,"class_field_contact","pulse",preload("res://weapon_contact.gd").token(game,target),now,{"enemy":target})
   if not targets.is_empty() and game.encounter_cleared(): game.finish_combat(int(event.owner),event.position)
static func describe(values: Dictionary,resolved: bool=false) -> String:
 var lines: Array[String]=[]
 var labels: Dictionary={"brittle":"Brittle buildup (3 stacks shatter, 4s window)","shatter_damage":"Shatter bonus damage","brace":"Braced impact after 0.5s stationary","mark_damage":"Mark damage (first contact marks; eligible follow-up consumes)","echo":"Echo charges/contact (3 releases a half-strength echo)","echo_redirect":"Redirect echoes to a nearby foe","death_charge":"Death charges per kill (max 3)","tide_pool":"Healing-pool potency (4.5s recovery)","pool_ward":"Healing pools grant brief wards","pool_radius":"Healing-pool radius bonus","suppress":"Timed wind-up interruption (4s enemy recovery)","decoy":"Decoy potency","decoy_duration":"Decoy duration bonus (ms)","link":"Contact links once to a nearby foe","link_damage":"Linked damage bonus","link_brittle":"Linked contact adds brittle","counter_damage":"Counter damage after guarding","counter_stagger":"Counter stagger (ms)","ward_on_block":"Guarded hits ward nearby living allies","directional_guard":"Directional guard; move at 40% while guarding","spread_bind":"Bind spreads to one nearby foe","growth_field":"Skill grows a damaging field","precision":"Extra damage exploiting a mark","trap_power":"Trap potency","reaper_momentum":"Death charges amplify committed strikes","veil_mark":"Evasive skills prepare a mark","protect_growth":"Healing grows a protective sanctuary","omen":"Marks punish enemy wind-ups"}
 for key in KEYS:
  var amount:=float(values.get(key,0))
  if amount<=0:continue
  var value:=str(values[key]).trim_suffix(".0")
  if key=="tide_pool" and resolved:
   value=Preview.heal_label(preload("res://expedition_sustain.gd").pool_points(Preview.proc_amount(amount,1,2)),Preview.HEAL_TICK_SPREAD_HP)+" per pulse"
  elif Preview.COMPONENT_HP_LABELS.has(key):
   value="%d HP"%Preview.effect_hp(amount)
  lines.append("%s: %s"%[labels.get(key,key.replace("_"," ").capitalize()),value])
 return "\n".join(lines)

static func guard_allows(p: Dictionary,origin: Vector3,now: int) -> bool:
 if now>=int(p.get("guard_until",0)): return false
 if now>=int(p.get("front_guard_until",0)) or origin==Vector3.INF: return true
 var direction: Vector3=origin-p.pos
 return direction.length_squared()<.01 or direction.normalized().dot(p.get("guard_face",Vector3.FORWARD))>=.15
static func blocked(game: Node,p: Dictionary,now: int) -> void:
 var stats: Dictionary=game.weapon_stats(p)
 if float(stats.get("counter_damage",0))>0 or now<int(p.get("counter_guard_until",0)):
  var balance=preload("res://class_skill_balance.gd")
  p.counter_until=now+balance.COUNTER_WINDOW_MS;p.counter_power=balance.counter_points(stats)
static func end_zone(game: Node,event: Dictionary) -> void:
 if event.has("ranger_route"): Ranger.end_route(game,event)
 if event.has("visual_id"):
  var point: Vector3=event.get("position",Vector3.ZERO)
  game.emit_combat_event("field_end",str(event.visual_id),point,point,.15,Color.WHITE,0,0)
