extends SceneTree
const Case=preload("res://tests/support/affinity_card_case.gd")
const Thorn=preload("res://thorn_affinity.gd")
const Sources=preload("res://affinity_status_source.gd")
const Active=preload("res://card_active_actions.gd")
var c:=Case.new()
var failed:=false
var checks:=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if not ok:failed=true;printerr("FAIL CE02 Thorn: ",label)
func run():
 c.create(self)
 var g: Node=c.game
 var settings:=preload("res://app_settings.gd").defaults()
 check(settings.bindings.card_active_three.is_empty() and settings.bindings.card_active_four.is_empty(),"optional action slots preserve the existing C/V Garden shortcuts")
 var now:=preload("res://combat_clock.gd").now()
 c.equip(1,"thorn")
 c.own(1,["bramble_density","sanguine_growth","sanguine_growth","unclosing_wounds"])
 var event:=c.action(1,"core")
 check(event.potency().personal_cap_hp==16,"two Growth copies add four to the one personal cap, not twelve across slots")
 Thorn.patch(g,event,g.tactics.position,1.0,now)
 var status: Dictionary=g.tactics.memory[Thorn.BLEED]
 var row: Dictionary=status.contributors.values()[0]
 check(row.amount==4800 and row.cap==16000 and row.until==4750,"Density increases actual application to 30 percent; duration extends only the contribution")
 c.own(1,["creeping_briars","creeping_briars"])
 check(is_equal_approx(float(g.combat_build(g.players[1]).core_skill().radius),Thorn.CORE_HALF_LENGTH+.4),"coverage extends the actual Core skill and preview input")
 c.reset();c.equip(1,"thorn",["form"])
 c.own(1,["serrated_edge","opening_wound","relentless_cuts"])
 var hit:=c.action(1,"form")
 hit.publish(g,"weapon_contact","one","leader",now,{"enemy":-1})
 status=g.tactics.memory[Thorn.BLEED]
 var first:=Thorn.potency_units(status)
 check(first==2040,"native patch plus first direct and opening application accumulate together")
 hit.publish(g,"weapon_contact","one","leader",now,{"enemy":-1})
 check(Thorn.potency_units(status)==first,"duplicate publication cannot apply the bonuses twice")
 c.action(1,"form").publish(g,"weapon_contact","two","leader",now,{"enemy":-1})
 check(Thorn.potency_units(status)==first+480,"same-target second hit adds direct plus streak but no second opening")
 c.reset();c.equip(1,"thorn",["catalyst"])
 c.own(1,["crimson_conduit","barbed_momentum"])
 Thorn.patch(g,c.action(1,"catalyst"),g.tactics.position,1.0,now)
 check(g.players[1].has(Thorn.MOMENTUM),"a real Catalyst victim prepares Momentum")
 var attack:={}
 Thorn.capture_attack(g,g.players[1],attack,now)
 var direct:=c.action(1,"catalyst")
 check(Thorn.ordinary_bonus(direct,attack)==3 and Thorn.ordinary_bonus(direct,attack)==0,"captured attack bonus applies at most once")
 check(not g.players[1].has(Thorn.MOMENTUM),"launch spends the preparation even before a hit")
 c.reset();c.equip(1,"thorn");c.equip(2,"thorn")
 c.own(1,["hemorrhagic_rupture"]);c.own(2,["hemorrhagic_rupture"])
 for peer in [1,2]:
  var e:=c.action(peer,"core")
  Thorn.patch(g,e,g.tactics.position,1.0,now)
 for index in 2:Thorn.tick(g,c.Clock.advance(g,1.01),now)
 var victim:=c.scout(Vector3(1,0,-2))
 var before:int=g.encounter.hp(victim)
 var death_status: Dictionary=g.tactics.memory[Thorn.BLEED]
 var death_token: int=death_status.token
 death_status.token=death_token+100
 Thorn.on_death(g,-1,now)
 check(g.encounter.hp(victim)==before,"stale enemy identity cannot produce a Bleed death burst")
 death_status.token=death_token
 g.encounter.set_hp(-1,1)
 preload("res://outgoing_hits.gd").affinity_world(g,1,-1,1,now,Thorn.COLOR)
 var after:int=g.encounter.hp(victim)
 Thorn.on_death(g,-1,now)
 check(after<before and g.encounter.hp(victim)==after,"one shared heavily-Bleeding target produces one burst even with two owners")
 c.reset();c.equip(1,"thorn");c.own(1,["bloodletting"])
 Thorn.patch(g,c.action(1,"core"),g.tactics.position,1.0,now)
 status=g.tactics.memory[Thorn.BLEED]
 var amount:=Thorn.potency_units(status)
 var before_hp:int=g.enemy_health()
 var request:=Active.request(g,g.players[1],"bloodletting",Vector2(0,-1),100)
 check(not request.is_empty(),"real session, world and life supply an action identity")
 var current_token: int=status.token
 status.token=current_token+100
 Active.command(g,1,g.players[1],request)
 check(g.enemy_health()==before_hp and not g.players[1].has(Active.STATE),"stale enemy identity cannot authorize Bloodletting")
 status.token=current_token
 Active.command(g,1,g.players[1],request)
 check(g.enemy_health()==before_hp-6 and Thorn.potency_units(status)==amount,"Bloodletting damages without consuming shared Bleed")
 Active.command(g,1,g.players[1],request)
 check(g.enemy_health()==before_hp-6,"duplicate action cannot damage twice")
 check(Active.owner_state(g,g.players[1]).size()==1,"additional action has skill-bar cooldown data")
 var saved: Dictionary=g.players[1][Active.STATE].duplicate(true)
 g.players[1][Active.STATE].actions.bloodletting.ready=0
 Active.command(g,1,g.players[1],request)
 check(g.enemy_health()==before_hp-6,"a replay remains rejected after cooldown is readied")
 g.players[1][Active.STATE]=saved
 c.Cards.clear(g.players[1])
 check(not g.players[1].has(Active.STATE) and Active.actions(g.players[1]).is_empty(),"expedition card cleanup retires additional actions and cooldown state")
 c.Expedition.set_world(g,{"combat_epoch":2})
 Active.command(g,1,g.players[1],request)
 check(g.enemy_health()==before_hp-6,"old-floor action identity is rejected")
 g.queue_free();await process_frame
 if not failed:print("PASS: CE02 Thorn ",checks," scaling, owner attribution, buildup, rupture and extra-action checks")
 quit(int(failed))
