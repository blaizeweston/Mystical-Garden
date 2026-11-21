extends RefCounted
## Explicit runtime setup only; real RPCs, identity and owner details remain authoritative.
const Cards=preload("res://affinity_cards.gd")
const Catalog=preload("res://affinity_card_catalog.gd")
const Build=preload("res://affinity_build.gd")
const Events=preload("res://combat_action_events.gd")
const Core=preload("res://core_combat.gd")
const Active=preload("res://card_active_actions.gd")
static func host(test: RefCounted,game: Node,guests: Array) -> bool:
 var family: String=test.ce04_family
 if family=="spirit":return await spirit_host(test,game,guests)
 var actors: Array=[1]+guests
 var saved:={}
 var part:=0
 for index in range(1,Build.Materials.DEFINITIONS.size()):
  if Build.Affinities.for_part(index).get("primary_affinity")==family:part=index;break
 var ids: Array={"storm":["extended_circuit","grounded_current","conductor"]}.get(family,[])
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
 var body: Dictionary=game.tactics.memory
 var thorn=load("res://thorn_affinity.gd")
 body.erase(thorn.BLEED)
 game.encounter.set_hp(-1,10000)
 for peer in actors:
  var build: Dictionary=game.combat_build(game.players[peer]).affinity_build()
  var material: Dictionary=build.core
  var event=Events.begin(game,peer,"core",material,material.potency_profile.values,["core_action"],now+30000)
  if family=="storm":load("res://storm_affinity.gd").discharge(game,peer,-1,game.players[peer].pos,game.tactics.position,int(event.potency().initial),2+int(event.potency().get("extra_jumps",0)),now,event.potency(),load("res://affinity_status_source.gd").capture(event))
  game.players[peer].core_ready_at=0;game.players[peer].core_cast_until=0;game.players[peer].cast_until=0
 for peer in guests:test.mark("ce04-start-"+str(peer),family)
 if not test.check(await test.until(func():return guests.all(func(peer):return test.read("ce04-seen-"+str(peer))=="ok")),"all guests receive acquired CE04 cards and additional action data"):return false
 var before:int=game.enemy_health()
 for peer in guests:test.mark("ce04-cast-"+str(peer))
 if not test.check(await test.until(func():return guests.all(func(peer):return game.players[peer].has(Active.STATE) if family in ["wood","vital"] else int(game.players[peer].get("core_ready_at",0))>now)),"guest Splinterburst requests pass host identity and ownership checks"):return false
 if family=="vital":
  for peer in guests:test.mark("ce04-attack-"+str(peer))
  if not test.check(await test.until(func():return game.weapon_attacks.views().any(func(row):return guests.has(row.player) and float(row.stats.get("vital_spent_hp",0))>0)),"real guest ordinary attack spends Harvest once at host launch"):return false
 if not test.check(await test.until(func():return game.enemy_health()<before),"host resolves guest card-enhanced damage after actual cast release"):return false
 for peer in guests:test.mark("ce04-accepted-"+str(peer))
 if not test.check(await test.until(func():return guests.all(func(peer):return test.read("ce04-finished-"+str(peer))=="ok")),"guests see host cooldown feedback after duplicate requests"):return false
 if family=="storm" and not test.check(await test.until(func():return game.effect_timeline.core_records().is_empty()),"all card-enhanced Core phases finish before fixture cleanup"):return false
 for peer in actors:
  var p: Dictionary=game.players[peer]
  p.weapon=saved[peer][0];p.secondary=saved[peer][1];p.catalyst=saved[peer][2];p.pos=saved[peer][4]
  if family=="wood":load("res://wood_affinity.gd").clear(p)
  if family=="vital":load("res://vital_combat.gd").clear(game,p)
  Cards.clear(p)
  if saved[peer][3]!=null:p[Cards.STATE]=saved[peer][3]
 if game.has_meta(thorn.FIELDS):game.remove_meta(thorn.FIELDS)
 body.erase("affinity_drenched");game.effect_timeline.clear_native();body.erase(thorn.BLEED);body.erase("affinity_brittle");body.erase("affinity_burning");body.erase("fire_flashover_ready");body.erase("fire_wildfire_ready")
 Core.reset(game)
 test.mark("ce04-done")
 return not test.failed
static func guest(test: RefCounted,game: Node,peer: int) -> bool:
 if not test.check(await test.until(func():return not test.read("ce04-start-"+str(peer)).is_empty()),"CE04 episode begins"):return false
 var family: String=test.ce04_family
 if family=="spirit":return await spirit_guest(test,game,peer)
 var unique: String={"storm":"conductor"}[family]
 var local: Dictionary=game.players[peer]
 if not test.check(await test.until(func():return game.players.get(peer,{}).get("affinity_run_cards",[]).any(func(row):return row.id==unique) and (family=="storm" or game.players.get(peer,{}).get("card_actions_state",[]).any(func(row):return row.id==unique))),"guest receives unique acquisition and additional skill-bar action"):return false
 test.mark("ce04-seen-"+str(peer))
 if not test.check(await test.until(func():return test.read("ce04-cast-"+str(peer))=="ok"),"host requests actual extra-action input"):return false
 local=game.players[peer]
 var offset: Vector3=game.tactics.position-local.pos
 var request:=Active.request(game,local,unique,Vector2(offset.x,offset.z).normalized(),100000+peer) if family in ["wood","vital"] else Core.request(game,local,Vector2(offset.x,offset.z).normalized(),1.1)
 game.send_garden_action(request);game.send_garden_action(request)
 if family=="vital":
  if not test.check(await test.until(func():return test.read("ce04-attack-"+str(peer))=="ok"),"host accepted Harvest toggle before ordinary attack"):return false
  game.send_action(true)
 if not test.check(await test.until(func():return test.read("ce04-accepted-"+str(peer))=="ok" and (game.players.get(peer,{}).get("card_actions_state",[]).any(func(row):return row.id==unique and (bool(row.get("active",false)) if family=="vital" else row.remaining>0)) if family in ["wood","vital"] else float(game.players.get(peer,{}).get("core_state",{}).get("remaining",0))>0)),"duplicate input yields one host-owned cooldown"):return false
 test.mark("ce04-finished-"+str(peer))
 return test.check(await test.until(func():return test.read("ce04-done")=="ok"),"CE04 fixture restores equipment before normal floor progression")


static func spirit_host(test: RefCounted,game: Node,guests: Array) -> bool:
 var spirit=load("res://spirit_affinity.gd")
 var cooldowns=load("res://player_cooldowns.gd")
 var actions=load("res://player_weapon_actions.gd")
 var actors: Array=[1]+guests
 var saved:={}
 var part:=0
 for index in range(1,Build.Materials.DEFINITIONS.size()):
  if Build.Affinities.for_part(index).get("primary_affinity")=="spirit":part=index;break
 var ids: Array=["stored_momentum","fleet_recovery","mirrorstep","wraithcast"]
 for peer in actors:
  var p: Dictionary=game.players[peer]
  saved[peer]={"weapon":p.weapon,"secondary":p.secondary,"catalyst":p.catalyst,"frame":p.frame,"kind":p.weapon_kind,"character":p.character.duplicate(true),"cards":p.get(Cards.STATE),"pos":p.pos,"timers":p[cooldowns.STATE],"actions":p[actions.STATE]}
  p.weapon=part;p.secondary=part;p.catalyst=part;p.frame=2;p.weapon_kind=0
  var tree=game.Classes.connected_tree(2);p.character[tree.profile_key]=tree.state(["wildstalker"])
  p.pos=game.battlefield.dash(game.tactics.position,game.tactics.position+Vector3(0,0,1.5));p.facing=Vector3.FORWARD
  p[cooldowns.STATE]=cooldowns.Timers.new();p[actions.STATE]=actions.State.new();p.cast_until=0;p.core_cast_until=0
  var copies: Array[Dictionary]=[]
  for id in ids:
   var d: Dictionary=Catalog.DEFINITIONS[id]
   copies.append({"id":id,"amount":d.get("fixed",0) if d.policy=="unique" else d.values[0],"rarity":"" if d.policy=="unique" else "Common","floor":game.participation.floor(),"acquisition_id":2000+peer*10+copies.size()})
  p[Cards.STATE]=Cards.Ledger.new(copies)
 game.encounter.set_hp(-1,100000)
 for peer in guests:test.mark("ce04-start-"+str(peer),"spirit")
 if not test.check(await test.until(func():return guests.all(func(peer):return test.read("ce04-seen-"+str(peer))=="ok")),"all guests receive Mirrorstep, Wraithcast and two native dash charges"):return false
 game.dodge_player(1,Vector2.RIGHT);game.dodge_player(1,Vector2.LEFT)
 for peer in guests:test.mark("ce04-dash-"+str(peer))
 if not test.check(await test.until(func():return actors.all(func(peer):return game.players[peer].get(spirit.ECHOES,[]).size()==2 and game.players[peer].get(spirit.SHADOWS,[]).size()==2)),"independent real guest dashes create two echoes and two departure shadows per actor"):return false
 for peer in guests:test.mark("ce04-copy-"+str(peer))
 game.weapon_attacks.try_start(game.weapon_attack_world,1,game.players[1].pos,load("res://combat_clock.gd").now())
 load("res://native_class_actions.gd").cast_world(game,1,0)
 if not test.check(await test.until(func():return actors.all(func(peer):return game.players[peer].get(spirit.ECHOES,[]).is_empty() and game.players[peer].get(spirit.SHADOWS,[]).is_empty() and game.players[peer][cooldowns.STATE].deadline(cooldowns.Q)>0)),"basic attacks and compatible native Q independently consume their own preparations"):return false
 if not test.check(await test.until(func():return game.enemy_health()<100000 and game.weapon_attacks.is_empty()),"host resolves all primary and phantom attacks without stranded work"):return false
 for peer in guests:test.mark("ce04-accepted-"+str(peer))
 if not test.check(await test.until(func():return guests.all(func(peer):return test.read("ce04-finished-"+str(peer))=="ok")),"guests see host cooldown and independent passive counts"):return false
 for peer in actors:
  var p: Dictionary=game.players[peer];var old: Dictionary=saved[peer]
  spirit.clear(p);Cards.clear(p)
  p.weapon=old.weapon;p.secondary=old.secondary;p.catalyst=old.catalyst;p.frame=old.frame;p.weapon_kind=old.kind;p.character=old.character;p.pos=old.pos
  p[cooldowns.STATE]=old.timers;p[actions.STATE]=old.actions
  if old.cards!=null:p[Cards.STATE]=old.cards
 test.mark("ce04-done")
 return not test.failed

static func spirit_guest(test: RefCounted,game: Node,peer: int) -> bool:
 if not test.check(await test.until(func():return game.players.get(peer,{}).get("affinity_run_cards",[]).any(func(row):return row.id=="wraithcast") and int(game.players.get(peer,{}).get("dodge_state",{}).get("capacity",0))==2),"guest receives authoritative two-charge capacity and both passive acquisitions"):return false
 test.mark("ce04-seen-"+str(peer))
 if not test.check(await test.until(func():return test.read("ce04-dash-"+str(peer))=="ok"),"host admits actual dash input"):return false
 game.request_dodge.rpc_id(1,Vector2.RIGHT);game.request_dodge.rpc_id(1,Vector2.LEFT)
 if not test.check(await test.until(func():return test.read("ce04-copy-"+str(peer))=="ok"),"host observes both departure-position preparations"):return false
 game.send_action(true)
 game.send_garden_action("class_skill");game.send_garden_action("class_skill")
 if not test.check(await test.until(func():return test.read("ce04-accepted-"+str(peer))=="ok" and not game.players.get(peer,{}).get("skill_ready",true) and int(game.players.get(peer,{}).get("spirit_prepared",{}).get("shadows",-1))==0),"guest receives one Q cooldown and cleared shadows after duplicate class input"):return false
 test.mark("ce04-finished-"+str(peer))
 return test.check(await test.until(func():return test.read("ce04-done")=="ok"),"Spirit fixture restores before card/graft/floor/extraction checks")
