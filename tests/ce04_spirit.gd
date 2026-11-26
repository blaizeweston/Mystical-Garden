extends SceneTree
const Effects = preload("res://enemy_affinity_effects.gd")
const Case=preload("res://tests/support/affinity_card_case.gd")
const Spirit=preload("res://spirit_affinity.gd")
const Replica=preload("res://spirit_replicas.gd")
const Cooldowns=preload("res://player_cooldowns.gd")
const Actions=preload("res://player_weapon_actions.gd")
const Clock=preload("res://combat_clock.gd")
const Events=preload("res://combat_action_events.gd")
const Native=preload("res://native_class_actions.gd")
const Life=preload("res://player_lifecycle.gd")
var c:=Case.new()
var failed:=false
var checks:=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if not ok:failed=true;printerr("FAIL CE04 Spirit: ",label)
func reset():
 c.reset();c.game.combat_events.clear();c.game.weapon_attacks.clear();c.game.effect_timeline.clear_native();c.game.effect_timeline.clear_cores()
 for p in c.game.players.values():
  load("res://wood_affinity.gd").clear(p);load("res://vital_combat.gd").clear(c.game,p)
  Spirit.clear(p);p[Cooldowns.STATE]=Cooldowns.Timers.new();p[Actions.STATE]=Actions.State.new()
  p.cast_until=0;p.core_cast_until=0;p.core_ready_at=0;p.mouse_aim=false
func run():
 c.create(self)
 var g: Node=c.game
 var p: Dictionary=g.players[1]
 var now:=Clock.now()
 var empty:=Cooldowns.Timers.new()
 var charges:=empty.configure_dodge(3,1000).start(Cooldowns.DODGE,1000,2200).start(Cooldowns.DODGE,1000,2200).start(Cooldowns.DODGE,1000,2200)
 check(charges.dodge_projection(1000).available==0 and not charges.ready(Cooldowns.DODGE,3199),"three stored charges spend consecutively but share one recovery deadline")
 check(charges.dodge_projection(3200).available==1 and charges.dodge_projection(5400).available==2 and charges.dodge_projection(7600).available==3,"spent charges recover sequentially, never three at once")
 check(empty.dodge_projection(1000).available==1 and charges.start(Cooldowns.DODGE,1000,2200).dodge_projection(1000).available==0,"immutable prior state survives refused extra spending")
 var single:=empty.start(Cooldowns.DODGE,1000,2200).ready_by(Cooldowns.DODGE,1100)
 check(single.ready(Cooldowns.DODGE,1100) and single.deadline(Cooldowns.DODGE)==1100,"last restored charge preserves native class restoration timestamp")
 var refund:=charges.ready_by(Cooldowns.DODGE,1100)
 check(refund.dodge_projection(1100).available==1 and refund.dodge_projection(3300).available==2,"native instant-dodge restoration restores one charge and preserves sequential recovery")
 check(charges.start(Cooldowns.Q,1200,500).dodge_projection(3200).available==1,"Q/R updates preserve all dash state")
 check(charges.with_deadline(Cooldowns.DODGE,0).dodge_projection(1200).available==3,"lifecycle reset restores capacity without duplicating timers")
 reset();c.equip(1,"spirit");c.own(1,["stored_momentum","fleet_recovery","run_dodge_recovery"])
 var resolved=g.combat_build(p)
 check(g.DODGE_COOLDOWN_MS==2200 and resolved.dodge_capacity()==2 and resolved.dodge_ms(2200)==1539,"baseline 850 to 2200; Quick Footing 45 ms stays flat then 40% efficiency resolves 1539 ms")
 var before: Vector3=p.pos
 g.dodge_player(1,Vector2.RIGHT);g.dodge_player(1,Vector2.LEFT)
 check(p[Cooldowns.STATE].dodge_projection(Clock.now()).available==0 and Vector3(p.pos).is_equal_approx(before),"stored dashes use real native movement consecutively")
 var until: int=p[Cooldowns.STATE].deadline(Cooldowns.DODGE)
 g.dodge_player(1,Vector2.RIGHT)
 check(p.pos==before and p[Cooldowns.STATE].deadline(Cooldowns.DODGE)==until,"empty charges refuse without changing position or recovery")
 reset();c.equip(1,"spirit");c.own(1,["far_step","persistent_traces","untethered_motion"])
 check(is_equal_approx(float(g.combat_build(p).core_skill().range),2.45),"Phantom Step range resolves card travel")
 var core=load("res://core_combat.gd")
 core.command(g,1,p,core.request(g,p,Vector2.RIGHT))
 check(Vector3(p.pos).x>2.4,"real Core follows tuned travel instead of the old constant")
 reset();c.equip(1,"spirit",["form"]);c.own(1,["ghostcut","flowing_edge","spectral_tempo"])
 var event:=c.action(1,"form")
 event.publish(g,"weapon_contact","first","leader",now,{"enemy":-1})
 var live: Dictionary=p[Spirit.STRIDES].values()[0]
 check(int(p[Spirit.FOLLOW].damage)==15 and int(live.until)==Spirit.STRIDE_MS+150,"Ghostcut boosts native follow-up; Flowing Edge extends live stride once")
 Spirit.voluntary(g,1,Vector3.ZERO,Vector3.RIGHT,now)
 check(Spirit.tempo_percent(g,p,now)==6,"legal movement provides actual temporary basic speed")
 reset();c.equip(1,"spirit");c.own(1,["stored_momentum","spectral_tempo","mirrorstep"])
 Clock.begin_stepped(10000)
 g.dodge_player(1,Vector2.RIGHT)
 check(Spirit.tempo_percent(g,p,10000)==6 and p[Spirit.ECHOES].size()==1,"first accepted dodge prepares speed and an echo immediately")
 for tick in 30:Clock.step()
 g.dodge_player(1,Vector2.LEFT)
 check(Spirit.tempo_percent(g,p,10500)==12 and p[Spirit.ECHOES].size()==2,"second accepted dodge adds its own stack without waiting for a proc cooldown")
 g.dodge_player(1,Vector2.RIGHT)
 check(Spirit.tempo_percent(g,p,10500)==12 and p[Spirit.ECHOES].size()==2,"refused dodge creates no new preparations")
 core.command(g,1,p,core.request(g,p,Vector2.RIGHT))
 check(Spirit.tempo_percent(g,p,10500)==18 and p[Spirit.ECHOES].size()==3,"same-tick Phantom Step adds another independent stack and echo without a dodge charge")
 var base_interval:int=g.combat_build(p).basic_stats().interval
 check(g.weapon_attack_world.capture_attack(1,10500).interval==maxi(c.Cards.STRIKE_MIN_MS,roundi(base_interval/1.18)),
  "the real basic-attack snapshot consumes the combined movement speed bonus")
 check(Spirit.tempo_percent(g,p,12000)==12 and Spirit.tempo_percent(g,p,12499)==12
  and Spirit.tempo_percent(g,p,12500)==0,"each speed stack expires exactly two seconds after its own movement")
 check(Spirit.hints(g,13000).size()==2 and Spirit.hints(g,13500).is_empty(),"Mirrorstep echoes expire independently after three seconds")
 var tempo_source: Dictionary=p[Spirit.ECHOES][0]
 p[Spirit.TEMPO]={"source":tempo_source,"until":11500,"percent":6}
 check(Spirit.tempo_percent(g,p,10500)==6,"historical suspended single speed preparation remains active")
 Spirit.voluntary(g,1,Vector3.ZERO,Vector3.RIGHT,10500)
 check(Spirit.tempo_percent(g,p,10500)==12 and Spirit.tempo_percent(g,p,11500)==6,
  "a restored single preparation can accumulate and expire independently alongside new movement")
 Spirit.prune_preparations(g,p,12500)
 check(Spirit.tempo_percent(g,p,12500)==0,"expired movement speed preparations are cleared")
 Clock.end_stepped()
 reset();c.equip(1,"spirit");c.own(1,["veiled_casting","flowing_invocation","wraiths_followthrough","evasive_spirit"])
 event=c.action(1,"catalyst")
 event.publish(g,"class_action","offense","",now,{"response":"self_stride","enemies":[-1]})
 check(is_equal_approx(Spirit.scale(p,0),1.23) and Spirit.claim_recovery(g,p,now)==20 and Spirit.claim_recovery(g,p,now)==0,"real compatible Catalyst grants improved stride and one recovery preparation")
 var stats: Dictionary={Events.CONTEXT:c.action(1,"form")}
 Spirit.basic_launch(g,p,stats,now)
 check(Spirit.ordinary_bonus(stats[Events.CONTEXT],stats)==2 and Spirit.ordinary_bonus(stats[Events.CONTEXT],stats)==0,"offensive class follow-through applies to one ordinary contact only")
 Spirit.voluntary(g,1,Vector3.ZERO,Vector3.RIGHT,now)
 check(Spirit.direct_damage(g,p,100,now)==96 and Spirit.direct_damage(g,p,100,now+1001)==100,"direct mitigation is finite protection without invulnerability")
 reset();c.equip(1,"spirit");c.own(1,["mirrorstep","wraithcast","lingering_echoes"])
 Spirit.voluntary(g,1,Vector3.ZERO,Vector3.RIGHT,now)
 Spirit.voluntary(g,1,Vector3(.1,0,0),Vector3(1.1,0,0),now+10)
 check(p[Spirit.ECHOES].size()==2 and p[Spirit.SHADOWS].size()==2 and p[Spirit.SHADOWS][0].point==Vector3.ZERO,"each movement prepares both independent families at departure positions")
 var images:=Spirit.hints(g,now+10)
 check(images.size()==4 and images.map(func(h):return h.id).count(images[0].id)==1 and images.all(func(h):return h.owner==1),"each echo and shadow projects one owned departure position")
 check(int(p[Spirit.SHADOWS][0].until)==now+4500 and int(p[Spirit.ECHOES][0].until)==now+3500,"Lingering Echoes extends each preparation's own base lifetime")
 check(g.weapon_attacks.try_start(g.weapon_attack_world,1,p.pos,now),"primary basic attack admits through existing executor")
 var queued: Array=g.weapon_attacks.views()
 check(queued.size()==3 and p.get(Spirit.ECHOES,[]).is_empty() and p[Spirit.SHADOWS].size()==2,"next basic attack releases all echoes simultaneously without consuming shadows")
 check(Spirit.hints(g,now+10).all(func(h):return h.skill=="wraithcast_shadow") and g.combat_events.filter(func(e):return e.shape=="mirrorstep_attack").size()==2,"accepted replicas consume exactly their own prepared images")
 var original: Dictionary=queued.filter(func(row):return not row.stats.get("spirit_replica",false))[0]
 for echo in queued.filter(func(row):return row.stats.get("spirit_replica",false)):
  check(echo.release==original.release and echo.stats.affinity_hp==maxi(1,roundi(int(original.stats.preview_strike_hp)*.4)),"phantom release timing and captured weapon potency match the authored scale")
 g.weapon_attacks.advance(g.weapon_attack_world,int(original.release))
 for echo in g.weapon_attacks.views().filter(func(row):return row.stats.get("spirit_replica",false)):
  var expected: Dictionary=g.weapon_attack_world.projectile_path(echo.stats.spirit_origin,Vector3.FORWARD,echo.form,float(echo.stats.reach))
  check(Vector3(echo.origin).is_equal_approx(expected.from),"phantom projectile applies its native muzzle offset once from the fixed echo position")
 g.weapon_attacks.advance(g.weapon_attack_world,now+2000)
 check(g.enemy_health()<1000000 and g.weapon_attacks.is_empty() and p.get(Spirit.ECHOES,[]).is_empty(),"real phantom attacks resolve without recursive copies")
 var skill: Dictionary=g.combat_build(p).class_skill(0)
 Replica.class_cast(g,1,skill,p.pos,g.tactics.position,float(skill.get("radius",2.0)),now,{"forward":Vector3.FORWARD,"endpoint":Vector3(0,0,-3)})
 check(Spirit.hints(g,now+10).is_empty(),"released shadows disappear from the current manifest")
 check(p.get(Spirit.SHADOWS,[]).is_empty(),"compatible skill consumes every shadow once")
 var hp:int=g.enemy_health()
 Replica.class_cast(g,1,skill,p.pos,g.tactics.position,2.0,now)
 check(g.enemy_health()==hp,"replayed replica callback cannot repeat already consumed effects")
 reset();c.equip(1,"spirit");c.own(1,["mirrorstep","wraithcast"])
 Spirit.voluntary(g,1,Vector3.ZERO,Vector3.RIGHT,now)
 Spirit.voluntary(g,1,Vector3.RIGHT,Vector3.RIGHT*2,now+1000)
 Spirit.prune_preparations(g,p,now+4100)
 check(p[Spirit.SHADOWS].size()==1 and p[Spirit.SHADOWS][0].point==Vector3.RIGHT,"shadows expire independently rather than refreshing the group")
 p[Life.STATE]=Life.start_life()
 Spirit.prune_preparations(g,p,now+1100)
 check(p[Spirit.SHADOWS].is_empty() and p[Spirit.ECHOES].is_empty(),"previous life cannot retain or release preparations")
 reset();c.equip(1,"spirit");c.own(1,["wraithcast"])
 g.dodge_player(1,Vector2.RIGHT)
 check(p[Spirit.SHADOWS][0].point==Vector3.ZERO and Vector3(p.pos).x>2.7,"real dodge creates shadow at departure, never destination")
 p.pos=Vector3.ZERO;p.facing=Vector3.FORWARD
 Native.cast_world(g,1,0)
 check(p.get(Spirit.SHADOWS,[]).is_empty() and p[Cooldowns.STATE].deadline(Cooldowns.Q)>now,"accepted real class action consumes Wraithcast without extra Q cooldown")
 # Actual compatibility drives Wraithcast offers, never a Spirit tag alone.
 reset();c.equip(1,"spirit",["core"])
 var eligibility=load("res://card_eligibility.gd")
 var tree=g.Classes.connected_tree(2);p.character[tree.profile_key]=tree.state(["snarekeeper"])
 check(not eligibility.requirement(c.Catalog.DEFINITIONS.wraithcast,g.combat_build(p).affinity_build()).is_empty(),"trap-only class plus movement-only Core cannot receive an unusable Wraithcast")
 c.equip(1,"vital",["core"]);c.equip(1,"spirit",["form"])
 check(not eligibility.requirement(c.Catalog.DEFINITIONS.wraithcast,g.combat_build(p).affinity_build()).is_empty(),"weaker strongest-source Vital copies alone cannot qualify a solo trap-only build")
 c.equip(1,"spirit",["core"]);p.frame=4;p.weapon_kind=0
 var quiet=g.Classes.connected_tree(4);p.character[quiet.profile_key]=quiet.state(["leykeeper"])
 check(not eligibility.requirement(c.Catalog.DEFINITIONS.wraithcast,g.combat_build(p).affinity_build()).is_empty(),"a weaker duplicate Ward alone cannot qualify a solo control-only build")
 p.frame=2;p.weapon_kind=0
 p.character[tree.profile_key]=tree.state(["wildstalker"])
 check(eligibility.requirement(c.Catalog.DEFINITIONS.wraithcast,g.combat_build(p).affinity_build()).is_empty(),"actual direct class ability qualifies Wraithcast without an offensive Core")
 for family in ["storm","wood","vital"]:
  reset();c.equip(1,family,["core"]);c.equip(1,"spirit",["form"]);c.own(1,["wraithcast"])
  Spirit.voluntary(g,1,Vector3.ZERO,Vector3.RIGHT,now)
  core.command(g,1,p,core.request(g,p,Vector2.UP))
  check(p.get(Spirit.SHADOWS,[]).is_empty() and int(p.core_ready_at)>now,"actual compatible "+family+" Core consumes one shadow with one native cooldown")
  if family=="storm":check(g.enemy_health()==999991,"Chain Spark phantom uses captured 40% damage and real weapon contact geometry")
  if family=="wood":check(load("res://wood_affinity.gd").capacity(load("res://wood_affinity.gd").live_grants(p,0))==12,"Ironbark phantom supplies scaled real protection")
  if family=="vital":check(load("res://player_vitals.gd").maximum_hp(p)==105 and load("res://player_vitals.gd").current_hp(p)==100,"Vital Bloom phantom scales capacity and grants no instant healing")
 reset();c.equip(1,"storm",["core"]);c.equip(1,"spirit",["form"])
 c.own(1,["wraithcast","conductor","grounded_current","mirrorstep"])
 Spirit.voluntary(g,1,Vector3.ZERO,Vector3.RIGHT,now)
 core.command(g,1,p,core.request(g,p,Vector2.UP))
 check(g.enemy_health()==999985,"Wraithcast retains Grounded Current and finite Conductor return at its reduced damage: twelve plus three")
 check(p.get(Spirit.SHADOWS,[]).is_empty() and p[Spirit.ECHOES].size()==1,"multiple Unique interaction consumes only its original shadow and creates no recursive phantom")
 reset();p.frame=3;p.weapon_kind=0
 var reaper_tree=g.Classes.connected_tree(3);p.character[reaper_tree.profile_key]=reaper_tree.state(["veilwalker"])
 c.equip(1,"spirit",["form"]);c.own(1,["wraithcast"])
 var vitals=load("res://player_vitals.gd")
 p[vitals.STATE]=p[vitals.STATE].with_hp(50)
 var ally: Dictionary=g.players[2];ally[vitals.STATE]=ally[vitals.STATE].with_hp(50);ally.pos=Vector3.ZERO
 Spirit.voluntary(g,1,Vector3.ZERO,Vector3.RIGHT,now)
 p.pos=Vector3.RIGHT
 var siphon: Dictionary=g.combat_build(p).class_skill(1)
 Replica.class_cast(g,1,siphon,p.pos,g.tactics.position,2.7,now)
 check(g.enemy_health()==999992 and p.get(Spirit.SHADOWS,[]).is_empty(),"Siphon Cut shadow reproduces eight damage at native validated range")
 check(vitals.current_hp(p)==50 and vitals.current_hp(ally)==50,"damage-only Siphon replica cannot turn native self-drain into party healing")
 check(p[Cooldowns.STATE].deadline(Cooldowns.R)==0,"leaf skill copy does not assign another native cooldown")
 # All real native Form owners receive scaled leaves through the same contact validation.
 for family in ["thorn","frost","fire","water","wood","storm","spirit","vital","void"]:
  reset();c.equip(1,family,["form"])
  var base:=c.action(1,"form");var q: Dictionary=base.potency();q.replica_scale=.4
  var clone: RefCounted=base.replicated(g,q,now)
  check(clone.publish(g,"weapon_contact","replica","leader",now,{"enemy":-1,"point":g.tactics.position,"origin":Vector3.ZERO,"forward":Vector3.FORWARD}),"validated scaled "+family+" Form leaf")
 reset();c.equip(1,"spirit",["form"]);c.own(1,["spectral_tempo","spectral_tempo"])
 var capped_stats: Dictionary=g.combat_build(p).weapon_base_stats();capped_stats.interval=258
 check(not p[c.Cards.STATE].eligible(capped_stats,2200).has("spectral_tempo"),"fixed Spirit tempo excludes copies that cannot improve actual rounded timing")
 c.own(1,["spectral_tempo"])
 var partial_seen:=false
 for seed_value in 12:
  for option in p[c.Cards.STATE].roll(seed_value,3,capped_stats,2200):
   if option.id=="spectral_tempo":partial_seen=true;check(option.amount==6,"last useful tempo copy retains only actual remaining contribution")
 check(partial_seen,"headroom-aware offers still contain a useful partial contribution")
 reset();c.equip(1,"water",["form"]);c.equip(1,"spirit",["core"]);c.own(1,["mirrorstep","rolling_current","refreshing_strikes"])
 var water=load("res://water_combat.gd")
 var water_event:=c.action(1,"form")
 var water_q: Dictionary=water_event.potency();water_q.replica_scale=.4
 var water_copy: RefCounted=water_event.replicated(g,water_q,now)
 water_copy.publish(g,"weapon_contact","echo","leader",now,{"enemy":-1,"point":g.tactics.position,"origin":Vector3.ZERO})
 check(not p.has(water.SEQUENCE) and not p.has(water.REFRESH) and int(Effects.read(g,-1)[water.DRENCHED].saturation)==6,"phantom applies six real Saturation without advancing ordinary hit sequences or preparing restoration")
 # The real queue keeps each class weapon's radial/sweep/projectile pattern.
 for frame in 5:
  for weapon in g.Classes.DEFINITIONS[frame].weapons.size():
   reset();p.frame=frame;p.weapon_kind=weapon
   var native_tree=g.Classes.connected_tree(frame)
   p.character[native_tree.profile_key]=native_tree.state([["vanguard","bloomcaller","wildstalker","veilwalker","omenreader"][frame]])
   c.equip(1,"spirit",["form"]);c.own(1,["mirrorstep"])
   Spirit.voluntary(g,1,Vector3.ZERO,Vector3.RIGHT,now)
   check(g.weapon_attacks.try_start(g.weapon_attack_world,1,p.pos,now),"real primary and phantom pattern admits "+str(frame)+"/"+str(weapon))
   check(g.weapon_attacks.views().size()==2,"one phantom uses the same initial weapon pattern for "+str(frame)+"/"+str(weapon))
   g.weapon_attacks.advance(g.weapon_attack_world,now+3000)
   check(g.weapon_attacks.is_empty(),"melee/projectile/volley copy completes "+str(frame)+"/"+str(weapon))
 check(c.Catalog.contribution(c.Catalog.DEFINITIONS.stored_momentum,2)=="+2 dash charges","stored capacity is labeled as dash charges rather than chain targets")
 # Four players, no phantom actor instances or gameplay-count ceiling.
 reset()
 var prepared_us:=0
 var admitted_us:=0
 for peer in [1,2,3,4]:
  c.equip(peer,"spirit");c.own(peer,["mirrorstep","wraithcast"])
  var began:=Time.get_ticks_usec()
  for index in 32:Spirit.voluntary(g,peer,Vector3.ZERO,Vector3.RIGHT,now)
  prepared_us+=Time.get_ticks_usec()-began
  check(g.players[peer][Spirit.ECHOES].size()==32 and g.players[peer][Spirit.SHADOWS].size()==32,"four-player preparations preserve all 32 valid echoes and shadows")
  began=Time.get_ticks_usec()
  check(g.weapon_attacks.try_start(g.weapon_attack_world,peer,g.players[peer].pos,now),"four-player phantom launch")
  admitted_us+=Time.get_ticks_usec()-began
 check(g.players.size()==4 and g.weapon_attacks.pending_count()==132,"128 echoes reuse lightweight queue entries, never duplicate player actors")
 var release_started:=Time.get_ticks_usec()
 g.weapon_attacks.advance(g.weapon_attack_world,now+2000)
 print("CE04 Spirit performance: 4 players / 128 echoes / 128 shadows; prepare ",prepared_us/1000.0," ms; admit ",admitted_us/1000.0," ms; resolve ",(Time.get_ticks_usec()-release_started)/1000.0," ms")
 check(g.weapon_attacks.is_empty(),"four-player phantom combat finishes all copied patterns")
 g.queue_free();await process_frame
 if not failed:print("PASS: CE04 Spirit ",checks," charge, movement, replica and lifecycle checks")
 quit(int(failed))
