extends SceneTree
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
 check(int(p[Spirit.SHADOWS][0].until)==now+4500 and int(p[Spirit.ECHOES][0].until)==now+3500,"Lingering Echoes extends each preparation's own base lifetime")
 check(g.weapon_attacks.try_start(g.weapon_attack_world,1,p.pos,now),"primary basic attack admits through existing executor")
 var queued: Array=g.weapon_attacks.views()
 check(queued.size()==3 and p.get(Spirit.ECHOES,[]).is_empty() and p[Spirit.SHADOWS].size()==2,"next basic attack releases all echoes simultaneously without consuming shadows")
 var original: Dictionary=queued.filter(func(row):return not row.stats.get("spirit_replica",false))[0]
 for echo in queued.filter(func(row):return row.stats.get("spirit_replica",false)):
  check(echo.release==original.release and echo.stats.affinity_hp==maxi(1,roundi(int(original.stats.preview_strike_hp)*.4)),"phantom release timing and captured weapon potency match the authored scale")
 g.weapon_attacks.advance(g.weapon_attack_world,now+2000)
 check(g.enemy_health()<1000000 and g.weapon_attacks.is_empty() and p.get(Spirit.ECHOES,[]).is_empty(),"real phantom attacks resolve without recursive copies")
 var skill: Dictionary=g.combat_build(p).class_skill(0)
 Replica.class_cast(g,1,skill,p.pos,g.tactics.position,float(skill.get("radius",2.0)),now,{"forward":Vector3.FORWARD,"endpoint":Vector3(0,0,-3)})
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
 # All real native Form owners receive scaled leaves through the same contact validation.
 for family in ["thorn","frost","fire","water","wood","storm","spirit","vital","void"]:
  reset();c.equip(1,family,["form"])
  var base:=c.action(1,"form");var q: Dictionary=base.potency();q.replica_scale=.4
  var clone: RefCounted=base.replicated(g,q,now)
  check(clone.publish(g,"weapon_contact","replica","leader",now,{"enemy":-1,"point":g.tactics.position,"origin":Vector3.ZERO,"forward":Vector3.FORWARD}),"validated scaled "+family+" Form leaf")
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
