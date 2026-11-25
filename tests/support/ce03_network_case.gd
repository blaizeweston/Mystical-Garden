extends RefCounted
const Effects = preload("res://enemy_affinity_effects.gd")
## Explicit runtime setup only; real RPCs, identity and owner details remain authoritative.
const Cards=preload("res://affinity_cards.gd")
const Catalog=preload("res://affinity_card_catalog.gd")
const Build=preload("res://affinity_build.gd")
const Events=preload("res://combat_action_events.gd")
const Core=preload("res://core_combat.gd")
const Active=preload("res://card_active_actions.gd")
static func host(test: RefCounted,game: Node,guests: Array) -> bool:
 var family: String=test.ce03_family
 var actors: Array=[1]+guests
 var saved:={}
 var part:=0
 for index in range(1,Build.Materials.DEFINITIONS.size()):
  if Build.Affinities.for_part(index).get("primary_affinity")==family:part=index;break
 var ids: Array={"water":["gathering_clouds","restorative_surge","monsoon"],"wood":["thickened_growth","bursting_canopy","splinterburst"],"vital":["verdant_reserve","flourishing_assault","harvest"]}.get(family,[])
 for peer in actors:
  var p: Dictionary=game.players[peer]
  saved[peer]=[p.weapon,p.secondary,p.catalyst,p.get(Cards.STATE),p.pos]
  if family in ["wood","vital"]:p.pos=game.battlefield.dash(game.tactics.position,game.tactics.position+Vector3((actors.find(peer)-1)*.25,0,1.0))
  p.weapon=part;p.secondary=part;p.catalyst=part
  var copies: Array[Dictionary]=[]
  for id in ids:
   var d: Dictionary=Catalog.DEFINITIONS[id]
   copies.append({"id":id,"amount":d.get("fixed",0) if d.policy=="unique" else d.values[0],"rarity":"" if d.policy=="unique" else "Common","floor":game.participation.floor(),"acquisition_id":1000+peer*10+copies.size()})
  p[Cards.STATE]=Cards.Ledger.new(copies)
 var now:=preload("res://combat_clock.gd").now()
 var effects := Effects.edit(game,-1)
 var thorn=load("res://thorn_affinity.gd")
 effects.erase(thorn.BLEED)
 game.encounter.set_hp(-1,10000)
 for peer in actors:
  var build: Dictionary=game.combat_build(game.players[peer]).affinity_build()
  var material: Dictionary=build.core
  var event=Events.begin(game,peer,"core",material,material.potency_profile.values,["core_action"],now+30000)
  if family=="water":
   load("res://water_combat.gd").drench(game,event,-1)
   load("res://water_combat.gd").drench(game,event,-1)
  elif family=="wood":load("res://wood_affinity.gd").grant(game,event,peer,"fixture-core")
  elif family=="vital":
   load("res://vital_combat.gd").grant(game,event,peer,load("res://affinity_time.gd").now(game))
   var p: Dictionary=game.players[peer]
   p[preload("res://player_vitals.gd").STATE]=p[preload("res://player_vitals.gd").STATE].refilled()
   p[preload("res://player_weapon_actions.gd").STATE]=p[preload("res://player_weapon_actions.gd").STATE].with_ready_at(0)
  game.players[peer].core_ready_at=0;game.players[peer].core_cast_until=0;game.players[peer].cast_until=0
 for peer in guests:test.mark("ce03-start-"+str(peer),family)
 if not test.check(await test.until(func():return guests.all(func(peer):return test.read("ce03-seen-"+str(peer))=="ok")),"all guests receive acquired CE03 cards and additional action data"):return false
 var before:int=game.enemy_health()
 for peer in guests:test.mark("ce03-cast-"+str(peer))
 if not test.check(await test.until(func():return guests.all(func(peer):return game.players[peer].has(Active.STATE) if family in ["wood","vital"] else int(game.players[peer].get("core_ready_at",0))>now)),"guest Splinterburst requests pass host identity and ownership checks"):return false
 if family=="vital":
  for peer in guests:test.mark("ce03-attack-"+str(peer))
  if not test.check(await test.until(func():return game.weapon_attacks.views().any(func(row):return guests.has(row.player) and float(row.stats.get("vital_spent_hp",0))>0)),"real guest ordinary attack spends Harvest once at host launch"):return false
 if not test.check(await test.until(func():return game.enemy_health()<before),"host resolves guest card-enhanced damage after actual cast release"):return false
 for peer in guests:test.mark("ce03-accepted-"+str(peer))
 if not test.check(await test.until(func():return guests.all(func(peer):return test.read("ce03-finished-"+str(peer))=="ok")),"guests see host cooldown feedback after duplicate requests"):return false
 if family=="water" and not test.check(await test.until(func():return game.effect_timeline.core_records().is_empty()),"all card-enhanced Core phases finish before fixture cleanup"):return false
 if family=="water" and not await allied_return(test,game,guests):return false
 for peer in actors:
  var p: Dictionary=game.players[peer]
  p.weapon=saved[peer][0];p.secondary=saved[peer][1];p.catalyst=saved[peer][2];p.pos=saved[peer][4]
  if family=="wood":load("res://wood_affinity.gd").clear(p)
  if family=="vital":load("res://vital_combat.gd").clear(game,p)
  Cards.clear(p)
  if saved[peer][3]!=null:p[Cards.STATE]=saved[peer][3]
 if game.has_meta(thorn.FIELDS):game.remove_meta(thorn.FIELDS)
 effects.erase("affinity_drenched");game.effect_timeline.clear_native();effects.erase(thorn.BLEED);effects.erase("affinity_brittle");effects.erase("affinity_burning");effects.erase("fire_flashover_ready");effects.erase("fire_wildfire_ready")
 Core.reset(game)
 test.mark("ce03-done")
 return not test.failed
# A single donor funds the tide. All guests stand on its return path with missing HP.
static func allied_return(test:RefCounted,game:Node,guests:Array) -> bool:
 var water=preload("res://water_combat.gd")
 var vitals=preload("res://player_vitals.gd")
 var donor:Dictionary=game.players[1]
 if not test.check(await test.until(func():return game.effect_timeline.native_records().all(func(row):return row.kind!="water_tide")),"earlier Water contributions finish"):return false
 var old_health:={}
 var serial:int=game.combat_event_serial
 donor.pos=game.battlefield.dash(game.tactics.position,game.tactics.position+Vector3.RIGHT*1.3)
 for peer in guests:
  var ally:Dictionary=game.players[peer]
  ally.pos=donor.pos
  old_health[peer]=ally[vitals.STATE]
  ally[vitals.STATE]=ally[vitals.STATE].with_hp(maxi(1,ally[vitals.STATE].max_hp()-24))
  test.mark("tide-ready-"+str(peer),str(serial))
 if not test.check(await test.until(func():return guests.all(func(peer):return test.read("tide-watching-"+str(peer))=="ok")),"all recipients are watching the incoming return"):return false
 Effects.edit(game,-1).erase(water.DRENCHED)
 var material:Dictionary=game.combat_build(donor).affinity_build().core
 for i in 3:
  var action=Events.begin(game,1,"core",material,material.potency_profile.values,["core_action"],preload("res://combat_clock.gd").now()+30000)
  water.drench(game,action,-1)
 var records:Array=game.effect_timeline.native_records().filter(func(row):return row.kind=="water_tide")
 if not test.check(not records.is_empty() and records[0].waves.all(func(wave):return wave.source.actor==1),"return waves belong to their sole donor"):return false
 var healed:={}
 if not test.check(await test.until(func():
  for event in game.combat_events:
   if event.id>serial and event.get("form","")=="water_heal" and event.get("amount",0)>0:healed[int(event.combo)]=true
  return guests.all(func(peer):return healed.has(peer) and test.read("tide-restored-"+str(peer))=="ok")),"every guest rendered a new host-confirmed healing receipt"):return false
 for peer in guests:
  var ally:Dictionary=game.players[peer]
  ally[vitals.STATE]=old_health[peer]
 return true

static func guest(test: RefCounted,game: Node,peer: int) -> bool:
 if not test.check(await test.until(func():return not test.read("ce03-start-"+str(peer)).is_empty()),"CE03 episode begins"):return false
 var family: String=test.ce03_family
 var unique: String={"water":"monsoon","wood":"splinterburst","vital":"harvest"}[family]
 var local: Dictionary=game.players[peer]
 if not test.check(await test.until(func():return game.players.get(peer,{}).get("affinity_run_cards",[]).any(func(row):return row.id==unique) and (family=="water" or game.players.get(peer,{}).get("card_actions_state",[]).any(func(row):return row.id==unique))),"guest receives unique acquisition and additional skill-bar action"):return false
 var renderer=preload("res://tests/support/world_presentation_case.gd").component(game,"combat")
 var status:String={"water":"drenched","wood":"bark_armor","vital":"vitality"}[family]
 if not test.check(await test.until(func():return renderer.statuses.active.values().any(func(item):
  return item.event.shape==status and item.has("shelter") and is_instance_valid(item.shelter) and (family=="water" or item.event.combo==peer))),"guest projects the host's "+status+" onto the affected actor"):return false
 test.mark("ce03-seen-"+str(peer))
 if not test.check(await test.until(func():return test.read("ce03-cast-"+str(peer))=="ok"),"host requests actual extra-action input"):return false
 local=game.players[peer]
 var offset: Vector3=game.tactics.position-local.pos
 var request:=Active.request(game,local,unique,Vector2(offset.x,offset.z).normalized(),100000+peer) if family in ["wood","vital"] else Core.request(game,local,Vector2(offset.x,offset.z).normalized(),1.1)
 game.send_garden_action(request);game.send_garden_action(request)
 if family=="vital":
  if not test.check(await test.until(func():return test.read("ce03-attack-"+str(peer))=="ok"),"host accepted Harvest toggle before ordinary attack"):return false
  game.send_action(true)
 if not test.check(await test.until(func():return test.read("ce03-accepted-"+str(peer))=="ok" and (game.players.get(peer,{}).get("card_actions_state",[]).any(func(row):return row.id==unique and (bool(row.get("active",false)) if family=="vital" else row.remaining>0)) if family in ["wood","vital"] else float(game.players.get(peer,{}).get("core_state",{}).get("remaining",0))>0)),"duplicate input yields one host-owned cooldown"):return false
 test.mark("ce03-finished-"+str(peer))
 if family=="water":
  if not test.check(await test.until(func():return test.read("tide-ready-"+str(peer)).is_valid_int()),"guest ready to observe allied restoration"):return false
  var before:=int(test.read("tide-ready-"+str(peer)))
  test.mark("tide-watching-"+str(peer))
  if not test.check(await test.until(func():return renderer.active.values().any(func(e):
   return e.get("art","")=="water_heal" and e.event.combo==peer and e.event.id>before and e.event.amount>0)),"returning Water renders the applied heal on this guest"):return false
  test.mark("tide-restored-"+str(peer))
 return test.check(await test.until(func():return test.read("ce03-done")=="ok"),"CE03 fixture restores equipment before normal floor progression")
