extends RefCounted
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const Ranger=preload("res://ranger_combat.gd")
const Reaper=preload("res://reaper_combat.gd")
const Grafts=preload("res://native_grafts.gd")
const Preview=preload("res://combat_balance_preview.gd")
# Bounded, authored effect vocabulary shared by plant slots, skills and cards.
const KEYS: Array=["brittle","shatter_damage","brace","mark_damage","echo","echo_redirect","death_charge","tide_pool","pool_ward","pool_radius","suppress","decoy","decoy_duration","link","link_damage","link_brittle","counter_damage","counter_stagger","ward_on_block","directional_guard","spread_bind","growth_field","precision","trap_power","reaper_momentum","veil_mark","protect_growth","omen","loot_attract","cinder_trail","chorus_pulse","pierce"]
static func target_state(game: Node,target: int) -> Dictionary:
 if target==-1: return game.enemy_traits
 if not game.scouts[target].has("traits"): game.scouts[target].traits={}
 return game.scouts[target].traits
static func player_id(game: Node,p: Dictionary) -> int:
 for id in game.players:
  if is_same(game.players[id],p): return int(id)
 return 0
static func valid_target(game: Node,target: int,token: int=-1) -> bool:
 if target==-1: return game.enemy_hp>0
 return target>=0 and target<game.scouts.size() and int(game.scouts[target].hp)>0 and (token<0 or int(game.scouts[target].get("spawn_token",0))==token)
static func other_target(game: Node,target: int,point: Vector3) -> int:
 var result:=-2;var distance:=3.0
 for candidate in range(-1,game.scouts.size()):
  if candidate==target or not valid_target(game,candidate): continue
  var at: Vector3=game.enemy_position(candidate);var length:=point.distance_to(at)
  if length<distance and game.battlefield.clear_line(point,at): result=candidate;distance=length
 return result
static func augment_hit(game: Node,p: Dictionary,target: int,stats: Dictionary,now: int,graft_contact: Dictionary={}) -> Dictionary:
 var hit:=stats.duplicate(true);var state:=target_state(game,target)
 var secondary: bool=hit.get("trait_secondary",false)
 var damage:=Preview.authored_amount(float(hit.damage))
 if now<int(p.get("prepared_mark_until",0)):
  hit.mark_damage=maxf(1.0,float(hit.get("mark_damage",0)));p.prepared_mark_until=0
 if float(hit.get("brittle",0))>0 and not p.has("combat_ruleset"):
  var stacks:=int(state.get("brittle",0)) if now<int(state.get("brittle_until",0)) else 0
  stacks+=maxi(1,roundi(float(hit.brittle)))
  if stacks>=3:
   var shatter:=float(hit.get("shatter_damage",2))
   damage+=maxf(.1,shatter) if Preview.enabled else maxi(1,roundi(shatter))
   stacks=0
   preload("res://combat_status.gd").proc(game,"shatter",game.enemy_position(target),game.enemy_position(target),target)
   preload("res://core_skill_effects.gd").shatter_rime(game,state,target,now)
   var at: Vector3=game.enemy_position(target)
   game.emit_combat_event("impact","spark",at,at,.35,Color("#9ed6e5"),1,0)
  state.brittle=stacks;state.brittle_until=now+4000
 var was_marked: bool=now<int(state.get("marked_until",0))
 var omen_triggered: bool=was_marked and float(hit.get("omen",0))>0 and (game.enemy_winding_up if target==-1 else int(game.scouts[target].windup)>0)
 if omen_triggered:
  damage+=mini(3,roundi(float(hit.omen))+1)
 if was_marked:
  damage+=maxf(0.0,float(hit.get("mark_damage",0))) if Preview.enabled else maxi(0,roundi(float(hit.get("mark_damage",0))))
 if was_marked and (float(hit.get("mark_damage",0))>0 or (float(hit.get("precision",0))>0 and not secondary) or omen_triggered):
  state.marked_until=0
  preload("res://combat_status.gd").proc(game,"mark_break",game.enemy_position(target),game.enemy_position(target),target)
 elif not was_marked and float(hit.get("mark_damage",0))>0:state.marked_until=now+4000
 if not secondary:
  if now<int(p.get("counter_until",0)):
   preload("res://combat_status.gd").proc(game,"counter",p.pos,game.enemy_position(target),target)
   damage+=Preview.authored_amount(float(p.get("counter_power",1)));hit.stagger=float(hit.get("stagger",0))+float(hit.get("counter_stagger",0));p.counter_until=0
  if float(hit.get("brace",0))>0 and now-int(p.get("still_since",now))>=500:
   damage+=mini(2,maxi(1,roundi(float(hit.brace))))
   preload("res://combat_status.gd").proc(game,"brace",p.pos,game.enemy_position(target),target)
  if float(hit.get("precision",0))>0 and was_marked:
   damage+=1
  if float(hit.get("reaper_momentum",0))>0:
   var charges := int(p.get("grave_charges",0))
   if not graft_contact.is_empty() and graft_contact.sources.any(func(source): return source.effects.has("death_charge")):
    charges += Grafts.graft_charges(p)
   damage+=mini(2,charges)
  if int(p.get("grave_charges",0))>0 and Reaper.spends_class_charge(p,hit):
   damage+=1;p.grave_charges-=1
   preload("res://combat_status.gd").proc(game,"momentum",p.pos,game.enemy_position(target),target)
 if float(hit.get("suppress",0))>0 and now>=int(state.get("silence_ready",0)):
  var winding: bool=game.enemy_winding_up if target==-1 else int(game.scouts[target].windup)>0
  if winding:
   state.silence_ready=now+4000;hit.was_winding=true
   hit.rite_suppressed=true
   preload("res://combat_status.gd").proc(game,"suppress",p.pos,game.enemy_position(target),target)
   if target==-1: game.enemy_winding_up=false;game.enemy_attack_mode="";game.active_radius=0;game.enemy_ready_at=now+700
   else: game.scouts[target].windup=0;game.scouts[target].ready=now+700
   hit.stagger=float(hit.get("stagger",0))+250+mini(300,roundi(float(hit.suppress)*100))
 hit.damage=damage if Preview.enabled else int(damage)
 return hit
static func queue_hit(game: Node,p: Dictionary,target: int,stats: Dictionary,now: int,delay: int,carry: bool,origin: Vector3=Vector3.INF,visual: String="",graft_source: Dictionary={}) -> void:
 if target==-2 or game.trait_events.size()>=24: return
 var hit: Dictionary=stats.duplicate(true) if carry else {"reach":stats.get("reach",2.0)}
 var amount:=Preview.followup_amount(stats,carry,visual=="chorus")
 hit.damage=amount if Preview.enabled else int(amount)
 if carry and float(stats.get("link_brittle",0))>0:
  hit.brittle=float(hit.get("brittle",0))+float(stats.link_brittle)
 if not carry and float(stats.get("mark_damage",0))>0: hit.mark_damage=float(stats.mark_damage)
 hit.trait_secondary=true
 if not graft_source.is_empty(): hit.core_hit=true
 game.trait_events.append({"kind":"hit","epoch":game.combat_epoch,"owner":player_id(game,p),"life":PlayerLifecycle.generation(p),"target":target,"token":-1 if target==-1 else int(game.scouts[target].get("spawn_token",0)),"due":now+delay,"stats":hit,"visual":visual if not visual.is_empty() else "link" if carry else "echo","origin":p.pos if origin==Vector3.INF else origin})
 if not graft_source.is_empty(): game.trait_events.back().graft_source=graft_source
static func zone(game: Node,p: Dictionary,kind: String,point: Vector3,radius: float,duration: int,power: float,now: int,ward: bool=false,class_field: RefCounted=null,graft_source: Dictionary={}) -> Dictionary:
 if game.trait_events.size()>=24: return {}
 var id:=player_id(game,p)
 for event in game.trait_events.duplicate():
  if event.kind==kind and int(event.owner)==id and event.has("graft_source")==not graft_source.is_empty():
   end_zone(game,event);game.trait_events.erase(event)
 game.trait_events.append({"kind":kind,"epoch":game.combat_epoch,"owner":id,"life":PlayerLifecycle.generation(p),"position":point,"radius":radius,"until":now+duration,"next":now,"power":power,"ward":ward})
 if class_field!=null: game.trait_events.back().class_field=class_field
 if not graft_source.is_empty(): game.trait_events.back().graft_source=graft_source
 var color:=Color("#e7a15f") if kind=="cinder" else Color("#88d7de") if kind=="tide" else Color("#d9a4c3") if kind=="decoy" else Color("#97c978")
 game.emit_combat_event("field",kind+"_zone",point,point,duration/1000.0,color,radius,0)
 game.trait_events.back().visual_id=game.combat_event_serial
 return game.trait_events.back()
static func after_hit(game: Node,p: Dictionary,target: int,stats: Dictionary,now: int,killed: bool) -> void:
 if stats.get("trait_secondary",false): return
 var point: Vector3=game.enemy_position(target)
 if killed and (target==-1 or not game.scouts[target].get("summoned",false)) and float(stats.get("death_charge",0))>0 and Reaper.spends_class_charge(p,stats):
  var graft_charges := Grafts.graft_charges(p)
  p.grave_charges=mini(Grafts.DEATH_CHARGE_CAP-graft_charges,int(p.get("grave_charges",0))+maxi(1,roundi(float(stats.death_charge))))
 if float(stats.get("chorus_pulse",0))>0:
  p.chorus_contacts=int(p.get("chorus_contacts",0))+1
  if p.chorus_contacts>=4:
   p.chorus_contacts=0
   for candidate in range(-1,game.scouts.size()):
    if candidate!=target and valid_target(game,candidate) and game.enemy_position(candidate).distance_to(point)<=3.2 and game.battlefield.clear_line(point,game.enemy_position(candidate)):
     var pulse: Dictionary=stats.duplicate();pulse.damage=Preview.proc_amount(float(stats.chorus_pulse),1,3);queue_hit(game,p,candidate,pulse,now,180,false,point,"chorus")
 if float(stats.get("cinder_trail",0))>0 and now>=int(p.get("cinder_ready",0)):
  p.cinder_ready=now+4000
  zone(game,p,"cinder",point,1.8,2600,Preview.proc_amount(float(stats.cinder_trail),1,3),now)
 if float(stats.get("echo",0))>0:
  p.echo_charge=int(p.get("echo_charge",0))+maxi(1,roundi(float(stats.echo)))
  if p.echo_charge>=3:
   p.echo_charge=0
   var destination:=other_target(game,target,point) if float(stats.get("echo_redirect",0))>0 else target
   if destination==-2 or not valid_target(game,destination): destination=other_target(game,target,point)
   queue_hit(game,p,destination,stats,now,240,false,point)
 if float(stats.get("link",0))>0 and now>=int(p.get("link_ready",0)):
  p.link_ready=now+120
  var other:=other_target(game,target,point)
  queue_hit(game,p,other,stats,now,140,true,point)
 if float(stats.get("tide_pool",0))>0 and now>=int(p.get("tide_ready",0)):
  p.tide_ready=now+4500
  zone(game,p,"tide",point,1.6+float(stats.get("pool_radius",0)),2400,game.Life.Sustain.pool_points(Preview.proc_amount(float(stats.tide_pool),1,2)),now,float(stats.get("pool_ward",0))>0)
 if float(stats.get("decoy",0))>0 and now>=int(p.get("decoy_ready",0)):
  p.decoy_ready=now+6000
  var facing: Vector3=p.get("facing",Vector3.FORWARD)
  var at: Vector3=game.battlefield.dash(p.pos,p.pos+facing.rotated(Vector3.UP,1.1)*2.5)
  zone(game,p,"decoy",at,1.0,2200+mini(1600,roundi(float(stats.get("decoy_duration",0))+float(stats.decoy)*300)),0,now)
static func decoy_point(game: Node,id: int) -> Vector3:
 var cast: Dictionary=game.get_meta("core_combat",{}).get(id,{})
 if not cast.is_empty() and cast.grown and cast.skill.has("decoy_ms") and int(cast.epoch)==game.combat_epoch and Time.get_ticks_msec()<int(cast.sequence_at)+int(cast.skill.decoy_ms):
  var player: Dictionary=game.players.get(id,{})
  if game.Life.alive(player) and PlayerLifecycle.matches(player,int(cast.life)): return cast.center
 for event in game.trait_events:
  if int(event.get("owner",0))!=id or not event_in_current_life(game,event): continue
  if event.kind=="snare" and Time.get_ticks_msec()<int(event.get("ranger_decoy_until",0)) and Ranger.source_live(game,event):
   return event.position
  if event.kind=="decoy" and Time.get_ticks_msec()<int(event.until): return event.position
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
 var placed := {"kind":"snare","epoch":game.combat_epoch,"owner":owner,"life":PlayerLifecycle.generation(p),
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
 var targets:=entrants.duplicate() if skill.mode=="subclass" else spread_targets(game,p,entrants,skill,event.stats).duplicate()
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
 return int(event.get("epoch",-1))==game.combat_epoch and PlayerLifecycle.matches(owner,int(event.get("life",-1)))

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
    else:
     hit.mark_damage=1
    var before: int = game.enemy_hp if target==-1 else int(game.scouts[target].hp)
    game.apply_weapon_hit(p,target,event.position,hit,now)
    if event.has("weaver_pressure"):
     var after: int = game.enemy_hp if target==-1 else int(game.scouts[target].hp)
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
  if Preview.enabled and key=="tide_pool" and resolved:
   value=Preview.heal_label(preload("res://expedition_sustain.gd").pool_points(Preview.proc_amount(amount,1,2)),Preview.HEAL_TICK_SPREAD_HP)+" per pulse"
  elif Preview.enabled and Preview.COMPONENT_HP_LABELS.has(key):
   value="%d HP"%Preview.effect_hp(amount)
  lines.append("%s: %s"%[labels.get(key,key.replace("_"," ").capitalize()),value])
 return "\n".join(lines)

static func try_brace(game: Node,p: Dictionary,now: int) -> bool:
 if p.has("combat_ruleset"):return false
 if now<int(p.get("brace_block_ready",0)) or now-int(p.get("still_since",now))<500: return false
 if float(game.weapon_stats(p).get("brace",0))<=0: return false
 preload("res://combat_status.gd").proc(game,"brace",p.pos,p.pos)
 p.brace_block_ready=now+4000;game.tell(player_id(game,p),"Ironroot absorbed the impact. Rebrace before the next committed strike.")
 return true

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
 if float(stats.get("ward_on_block",0))>0:
  for ally in game.players.values():
   if not is_same(ally,p) and game.Life.alive(ally) and ally.pos.distance_to(p.pos)<=3.0 and game.battlefield.clear_line(p.pos,ally.pos): game.grant_guard(ally,now+800,1)
 if int(p.get("frame",-1))==0:
  preload("res://warden_combat.gd").block_effects(game,p,now)
static func skill_cast(game: Node,p: Dictionary,skill: Dictionary,stats: Dictionary,point: Vector3,now: int) -> void:
 if skill.has("field"):
  var balance=preload("res://class_skill_balance.gd")
  var duration: int=balance.duration(skill,stats,"field_duration",2400) if Preview.enabled else int(skill.get("field_duration",2400))
  zone(game,p,str(skill.field),point,float(skill.get("radius",2.0)),duration,balance.field_power(skill),now,bool(skill.get("field_ward",false)),
   preload("res://combat_action_events.gd").field_action(stats))
 if not skill.has("field") and float(stats.get("growth_field",0))>0 and str(skill.mode)!="bloom_detonate":
  zone(game,p,"growth",point,2.0,2600+mini(1000,roundi(float(stats.growth_field)*250)),mini(2,maxi(1,roundi(float(stats.growth_field)))),now)
 if not skill.has("field") and float(stats.get("protect_growth",0))>0 and str(skill.mode) in ["heal","sanctuary"]:
  var balance=preload("res://class_skill_balance.gd")
  zone(game,p,"tide",point,3.0,2600,balance.field_power({"field":"tide","mode":skill.mode}),now,true)
 if skill.get("cleanse",false):
  for ally in game.players.values():
   if game.Life.alive(ally) and ally.pos.distance_to(p.pos)<=float(skill.get("radius",4)) and game.battlefield.clear_line(p.pos,ally.pos): ally.slow_until=0
 if float(stats.get("veil_mark",0))>0 and str(skill.mode) in ["windstep","reap","harvest"]: p.prepared_mark_until=now+3000

static func tune_skill(skill: Dictionary,stats: Dictionary) -> Dictionary:
 var result:=skill.duplicate(true)
 if result.get("field","")=="growth" and float(stats.get("growth_field",0))>0:
  result.field_duration=int(result.get("field_duration",2400))+mini(1500,roundi(float(stats.growth_field)*250))
  result.field_power=int(result.get("field_power",1))+mini(1,maxi(0,roundi(float(stats.growth_field))-1))
 if result.get("field","")=="tide" and float(stats.get("protect_growth",0))>0:
  result.field_duration=int(result.get("field_duration",2400))+mini(1500,roundi(float(stats.protect_growth)*300))
 if str(result.mode) in ["bind","strangle","snare","snare_field"] and float(stats.get("trap_power",0))>0:
  result.bind=int(result.get("bind",0))+mini(900,roundi(float(stats.trap_power)*300))
  result.damage=Preview.authored_amount(float(result.get("damage",0)))+ (minf(2.0,float(stats.trap_power)) if Preview.enabled else mini(2,roundi(float(stats.trap_power))))
 return result
static func spread_targets(game: Node,p: Dictionary,targets: Array[int],skill: Dictionary,stats: Dictionary) -> Array[int]:
 if targets.is_empty() or float(stats.get("spread_bind",0))<=0 or not (skill.has("bind") or str(skill.mode) in ["bind","strangle"]): return targets
 var result: Array[int]=targets.duplicate()
 for target in targets:
  var extra:=other_target(game,target,game.enemy_position(target))
  if extra!=-2 and not result.has(extra) and game.battlefield.clear_line(p.pos,game.enemy_position(extra)): result.append(extra)
  if result.size()>=targets.size()+mini(2,maxi(1,roundi(float(stats.spread_bind)))): break
 return result
static func detonation_targets(game: Node,p: Dictionary,radius: float) -> Array[int]:
 var targets: Array[int]=[];var id:=player_id(game,p)
 for event in game.trait_events.duplicate():
  if event.kind!="growth" or event.owner!=id or not event_in_current_life(game,event): continue
  for target in game.skill_area_targets(event.position,radius,event.position):
   if not targets.has(target): targets.append(target)
  end_zone(game,event);game.trait_events.erase(event)
 return targets
static func has_growth(game: Node,p: Dictionary) -> bool:
 var id:=player_id(game,p)
 return game.trait_events.any(func(e):return e.kind=="growth" and e.owner==id and event_in_current_life(game,e))
static func defer_skill(game: Node,p: Dictionary,targets: Array[int],skill: Dictionary,stats: Dictionary,now: int) -> void:
 for target in targets:
  if game.trait_events.size()>=24: break
  var hit:=stats.duplicate(true);hit.damage=Preview.authored_amount(float(skill.damage))+preload("res://combat_ruleset.gd").legacy_power(p);hit.trait_secondary=true
  game.trait_events.append({"kind":"hit","owner":player_id(game,p),"epoch":game.combat_epoch,"life":PlayerLifecycle.generation(p),"target":target,"token":-1 if target==-1 else int(game.scouts[target].get("spawn_token",0)),"due":now+int(skill.get("delay",700)),"stats":hit})

static func end_zone(game: Node,event: Dictionary) -> void:
 if event.has("ranger_route"): Ranger.end_route(game,event)
 if event.has("visual_id"):
  var point: Vector3=event.get("position",Vector3.ZERO)
  game.emit_combat_event("field_end",str(event.visual_id),point,point,.15,Color.WHITE,0,0)
