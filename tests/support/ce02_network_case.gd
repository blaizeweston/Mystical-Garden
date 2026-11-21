extends RefCounted
## Explicit runtime setup only; real RPCs, identity and owner details remain authoritative.
const Cards=preload("res://affinity_cards.gd")
const Catalog=preload("res://affinity_card_catalog.gd")
const Build=preload("res://affinity_build.gd")
const Events=preload("res://combat_action_events.gd")
const Core=preload("res://core_combat.gd")
const Active=preload("res://card_active_actions.gd")
static func host(test: RefCounted,game: Node,guests: Array) -> bool:
 var family: String=test.ce02_family
 var actors: Array=[1]+guests
 var saved:={}
 var part:=0
 for index in range(1,Build.Materials.DEFINITIONS.size()):
  if Build.Affinities.for_part(index).get("primary_affinity")==family:part=index;break
 var ids: Array={"thorn":["sanguine_growth","bloodletting"],"frost":["crystalline_fracture","avalanche","shatterwave"]}.get(family,[])
 for peer in actors:
  var p: Dictionary=game.players[peer]
  saved[peer]=[p.weapon,p.secondary,p.catalyst,p.get(Cards.STATE)]
  p.weapon=part;p.secondary=part;p.catalyst=part
  var copies: Array[Dictionary]=[]
  for id in ids:
   var d: Dictionary=Catalog.DEFINITIONS[id]
   copies.append({"id":id,"amount":d.get("fixed",0) if d.policy=="unique" else d.values[0],"rarity":"" if d.policy=="unique" else "Common","floor":game.participation.floor(),"acquisition_id":1000+peer*10+copies.size()})
  p[Cards.STATE]=Cards.Ledger.new(copies)
 var now:=preload("res://combat_clock.gd").now()
 var body: Dictionary=game.tactics.memory
 var thorn=load("res://thorn_affinity.gd")
 body.erase(thorn.BLEED)
 game.encounter.set_hp(-1,10000)
 for peer in actors:
  var build: Dictionary=game.combat_build(game.players[peer]).affinity_build()
  var material: Dictionary=build.core
  var event=Events.begin(game,peer,"core",material,material.potency_profile.values,["core_action"],now+30000)
  if family=="thorn":thorn.patch(game,event,game.tactics.position,1.0,now)
  else:load("res://frost_combat.gd").apply(game,event,-1,2,now)
  game.players[peer].core_ready_at=0;game.players[peer].core_cast_until=0;game.players[peer].cast_until=0
 if family=="thorn" and not test.check(body.get(thorn.BLEED,{}).get("contributors",{}).size()==actors.size(),"CE02 contributors share one owner-scaled Bleed"):return false
 for peer in guests:test.mark("ce02-start-"+str(peer),family)
 if not test.check(await test.until(func():return guests.all(func(peer):return test.read("ce02-seen-"+str(peer))=="ok")),"all guests receive acquired CE02 cards and additional action data"):return false
 var before:int=game.enemy_health()
 for peer in guests:test.mark("ce02-cast-"+str(peer))
 if not test.check(await test.until(func():return guests.all(func(peer):return game.players[peer].has(Active.STATE) if family=="thorn" else int(game.players[peer].get("core_ready_at",0))>now)),"guest Bloodletting requests pass host identity and ownership checks"):return false
 if not test.check(await test.until(func():return game.enemy_health()<before),"host resolves guest card-enhanced damage after actual cast release"):return false
 for peer in guests:test.mark("ce02-accepted-"+str(peer))
 if not test.check(await test.until(func():return guests.all(func(peer):return test.read("ce02-finished-"+str(peer))=="ok")),"guests see host cooldown feedback after duplicate requests"):return false
 if family!="thorn" and not test.check(await test.until(func():return game.effect_timeline.core_records().is_empty()),"all card-enhanced Core phases finish before fixture cleanup"):return false
 for peer in actors:
  var p: Dictionary=game.players[peer]
  p.weapon=saved[peer][0];p.secondary=saved[peer][1];p.catalyst=saved[peer][2]
  Cards.clear(p)
  if saved[peer][3]!=null:p[Cards.STATE]=saved[peer][3]
 if game.has_meta(thorn.FIELDS):game.remove_meta(thorn.FIELDS)
 body.erase(thorn.BLEED);body.erase("affinity_brittle")
 Core.reset(game)
 test.mark("ce02-done")
 return not test.failed
static func guest(test: RefCounted,game: Node,peer: int) -> bool:
 if not test.check(await test.until(func():return not test.read("ce02-start-"+str(peer)).is_empty()),"CE02 episode begins"):return false
 var family: String=test.ce02_family
 var unique: String={"thorn":"bloodletting","frost":"avalanche"}[family]
 var local: Dictionary=game.players[peer]
 if not test.check(await test.until(func():return game.players.get(peer,{}).get("affinity_run_cards",[]).any(func(row):return row.id==unique) and (family!="thorn" or game.players.get(peer,{}).get("card_actions_state",[]).any(func(row):return row.id=="bloodletting"))),"guest receives unique acquisition and additional skill-bar action"):return false
 test.mark("ce02-seen-"+str(peer))
 if not test.check(await test.until(func():return test.read("ce02-cast-"+str(peer))=="ok"),"host requests actual extra-action input"):return false
 local=game.players[peer]
 var offset: Vector3=game.tactics.position-local.pos
 var request:=Active.request(game,local,"bloodletting",Vector2(offset.x,offset.z).normalized(),100000+peer) if family=="thorn" else Core.request(game,local,Vector2(offset.x,offset.z).normalized(),1.1)
 game.send_garden_action(request);game.send_garden_action(request)
 if not test.check(await test.until(func():return test.read("ce02-accepted-"+str(peer))=="ok" and (game.players.get(peer,{}).get("card_actions_state",[]).any(func(row):return row.id=="bloodletting" and row.remaining>0) if family=="thorn" else float(game.players.get(peer,{}).get("core_state",{}).get("remaining",0))>0)),"duplicate input yields one host-owned cooldown"):return false
 test.mark("ce02-finished-"+str(peer))
 return test.check(await test.until(func():return test.read("ce02-done")=="ok"),"CE02 fixture restores equipment before normal floor progression")
