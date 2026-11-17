extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Lairs=preload("res://boss_lair_fights.gd")
const Routes=preload("res://boss_lair_routes.gd")
const Orchard=preload("res://orchard_moves.gd")
const Status=preload("res://combat_status.gd")
var failed:=false

func check(ok: bool, message: String) -> void:
 if not ok:
  failed=true
  printerr("FAIL boss lairs: ",message)

func _initialize() -> void:
 preload("res://combat_balance_preview.gd").enabled = false
 call_deferred("run")

func build(game: Node, kind: int, stamp: int) -> void:
 ExpeditionCase.set_world(game, {"map_seed": stamp})
 game.tactics.boss_kind=kind
 game.tactics.boss_phase=1
 game.tactics.boss_moves=0
 game.enemy_kind=kind
 game.tactics.position=Vector3(0,0,2)
 game.encounter.set_hp(-1, 80)
 game.tactics.ready_at=0
 game.tactics.engaged=true
 game.tactics.winding_up=false
 game.enemy_hazards.clear()
 game.encounter.clear_scouts()
 game.tactics.memory.clear()
 game.battlefield.configure(0,2,stamp,kind,1)

func run() -> void:
 var game=load("res://world.tscn").instantiate()
 game.progress.path="res://.godot/boss-lairs-"+str(Time.get_ticks_usec())
 game.local_character.path=game.progress.path+".character"
 root.add_child(game)
 game.set_process(false)
 game.set_physics_process(false)
 ExpeditionCase.set_world(game, {"encounter_number": 16})
 var player: Dictionary=game.players[1]
 ExpeditionCase.set_membership(game, player, true)
 player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(10)
 var now:=Time.get_ticks_msec()+200
 var anchor_sites: Dictionary={}
 var bank_layouts: Dictionary={}
 for stamp in range(17,41):
  build(game,Routes.ORCHARD,stamp*41)
  player.pos=Vector3(0,0,12.5).rotated(Vector3.UP,stamp*TAU/24.)
  var normal:=Lairs.draft(game,"root_sweep",1,false)
  check(normal.inner<2 and normal.anchor.distance_to(normal.from)>1.0,"normal roots plant near the boss")
  var initial: Vector3=player.pos
  for sample in 9:
   player.pos=initial.rotated(Vector3.UP,sample*.048)
   Lairs.observe(game,now+sample*Lairs.SAMPLE_MS)
  check(Lairs.adaptive(game,1,"outer"),"sustained outer movement is observed during the fight")
  check(Lairs.commit(game,"root_sweep",1,now+3600),"outer root can commit on an open lair")
  var plan: Dictionary=game.tactics.memory.lair_plan
  anchor_sites[plan.anchor]=true
  var retreat:=Lairs.escape(game,plan,player.pos,now)
  check(plan.variant=="outer_anchor" and retreat.is_finite() and retreat.length()<float(plan.inner),"outer arc leaves a reachable interior path")
  check(game.battlefield.clear_line(player.pos,retreat,game.Battlefield.CLEARANCE),"interior path passes player collision")
  var hints: Array=game.attack_hints_snapshot()
  check(hints.size()==2 and hints[0].role=="orchard_sweep" and hints[1].role=="orchard_anchor","one real sector and one planted anchor")
  if hints.size()==2:
   check(hints[0].radius==plan.radius and hints[0].inner==plan.inner and hints[0].span==plan.span,"sweep warning is the authoritative footprint")
  var locked: Vector3=game.tactics.position
  game.apply_weapon_hit(player,-1,player.pos,{"damage":1,"knockback":5.0},now)
  check(game.tactics.position==locked,"weapon hits keep the committed cast origin")
  player.pos=retreat
  player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(10)
  player.hurt_until=0
  game.Bosses.resolve(game,game.tactics.strike_at)
  var strike: int=game.tactics.strike_at
  check(PlayerVitals.current_hp(player)==10 and game.Bosses.exposed(game,strike),"interior retreat avoids the strike and opens the uprooting window")
  Status.sync(game,strike)
  check(Status.snapshot(game,strike).any(func(event):return event.shape=="uprooting"),"uprooting is displayed")
  var before: int=game.enemy_health()
  game.apply_weapon_hit(player,-1,player.pos,{"damage":1},strike+100)
  check(game.enemy_health()==before-2 and not game.Bosses.exposed(game,strike+2800),"uprooting gives exactly one bonus damage during the window")
  if stamp==17:
   player.pos=plan.from+Lairs.direction(plan.from,plan.face)*12
   game.tactics.memory.lair_plan=plan
   player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(10);player.hurt_until=0
   game.Bosses.resolve(game,strike+3000)
   check(PlayerVitals.current_hp(player)==8,"standing inside the outer sweep takes the expected damage")

  build(game,Routes.DROWNED,stamp*313)
  var layout:=Routes.crossings(game.participation.seed())
  bank_layouts[layout.banks[0]]=true
  player.pos=Routes.bank(layout,stamp%2,.9)
  for index in 9:
   Lairs.observe(game,now+index*Lairs.SAMPLE_MS)
  check(Lairs.adaptive(game,1,"bank"),"repeated dry-lane use is observed during the fight")
  check(Lairs.commit(game,"grasping_pool",1,now+4000),"favored bank can be marked")
  plan=game.tactics.memory.lair_plan
  check(plan.variant=="flood_bank" and plan.areas.size()==2,"a planned flood affects one dry bank")
  check(Lairs.other_bank_open(game,plan,now+4000),"both crossbars connect through the alternate bank")
  retreat=Lairs.escape(game,plan,player.pos,now+4000)
  check(retreat.is_finite() and Routes.dry(layout,retreat),"the threatened player can reach dry ground")
  hints=game.attack_hints_snapshot()
  check(hints.size()==2 and hints[0].lair=="water" and hints[0].radius==plan.areas[0].radius,"flood previews its actual footprint and water style")
  strike=game.tactics.strike_at
  game.Bosses.resolve(game,strike)
  check(game.enemy_hazards.size()==2 and game.enemy_hazards[0].point==plan.areas[0].point and game.enemy_hazards[1].activate==strike+400,"the host schedules the two marked waves at the promised times")
  player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(10);player.hurt_until=0;player.pos=retreat
  game.Bosses.tick_hazards(game,strike)
  check(PlayerVitals.current_hp(player)==10,"the alternate route stays harmless when the water rises")
  game.enemy_hazards.clear()
  player.pos=Vector3(0,0,4.4)
  check(Lairs.commit(game,"drowned_surge",1,strike+3000),"Drowned locks the surge")
  plan=game.tactics.memory.lair_plan
  hints=game.attack_hints_snapshot()
  check(hints.size()==1 and hints[0].width>plan.width and hints[0].pose=="drowned_surge","surge warning includes collision padding and pose")
  player.pos=Vector3(3.5,0,4.4)
  game.Bosses.resolve(game,game.tactics.strike_at)
  check(game.tactics.position==plan.to and PlayerVitals.current_hp(player)==10 and game.tactics.memory.lair_open.kind=="core_exposed","surge stays locked while the player sidesteps and the core opens")
 check(anchor_sites.size()>15 and bank_layouts.size()>4,"multiple seeds move the arena landmarks")
 orchard_pressure(game,now)
 ExpeditionCase.remove_actor(game, 2)
 ExpeditionCase.remove_actor(game, 3)
 ExpeditionCase.remove_actor(game, 4)

 build(game,Routes.DROWNED,7713)
 player.pos=Routes.bank(Routes.crossings(game.participation.seed()),1,0.0)
 game.tactics.memory.lair_tracks={1:{"streak":9}}
 var blocked:=Routes.bank(Routes.crossings(game.participation.seed()),0,1.0)
 game.Bosses.hazard(game,blocked,1.4,now,2200,"lair_tide",0)
 check(Lairs.commit(game,"grasping_pool",1,now),"base pool still commits with a blocked alternate crossing")
 check(game.tactics.memory.lair_plan.variant.is_empty(),"adaptation falls back when the other bank is unsafe")
 game.tactics.winding_up=false
 game.enemy_hazards.clear()
 game.tactics.boss_phase=0
 game.encounter.set_hp(-1, ceili(game.encounter_health()*.4))
 game.tactics.stagger_until=0
 game.tactics.ready_at=0
 game.tactics.memory.erase("lair_tracks")
 game.Bosses.tick(game,.016,Time.get_ticks_msec())
 check(game.tactics.boss_phase==1 and not game.tactics.winding_up,"phase change previews before the next attack")
 check(game.attack_hints_snapshot().any(func(hint):return hint.role=="lair_phase" and hint.cue=="Tide rising"),"phase cue is included in public warnings")

 game.queue_free()
 await process_frame
 if not failed:print("PASS: seeded Orchard and Drowned arenas, expanded Orchard moves, distant fruit, four-player cage escapes, phase rotation and finite vulnerability")
 quit(1 if failed else 0)


func orchard_pressure(game: Node, now: int) -> void:
 var player: Dictionary=game.players[1]
 for id in range(2,5):
  game.add_player(id)
  ExpeditionCase.set_membership(game, game.players[id], true)
  game.players[id].profile_ready=true
 for stamp in range(17,41):
  build(game,Routes.ORCHARD,stamp*73)
  game.tactics.boss_phase=2
  game.battlefield.configure(0,2,game.participation.seed(),Routes.ORCHARD,2)
  game.tactics.position=Vector3(0,0,1).rotated(Vector3.UP,stamp*.2)
  player.pos=Vector3(0,0,7.5).rotated(Vector3.UP,stamp*.2)
  var sweep:=Lairs.draft(game,"root_sweep",1,false)
  var axis:=Lairs.direction(sweep.from,sweep.to)
  var swept: Vector3=sweep.from+axis.rotated(Vector3.UP,1.45)*8.0
  check(Lairs.covered(sweep,swept) and sweep.open.is_empty(),"deep sweep threatens a wider flank and links to its follow-up")
  var march:=Lairs.draft(game,"orchard_march",1,false)
  var march_side:=axis.cross(Vector3.UP)
  var mid: Vector3=march.from.lerp(march.to,.5)
  check(Lairs.covered(march,mid+march_side*2.25) and not Lairs.covered(march,mid+march_side*2.9),"march has a wide lane and a readable sidestep")
  check(Lairs.covered(march,march.to+axis*3.2) and not Lairs.covered(march,march.to+axis*3.55),"march landing has its own wider footprint")

  var fruit:=Lairs.draft(game,"falling_fruit",1,false)
  check(fruit.areas.size()==2 and fruit.areas[0].radius>game.DODGE_DISTANCE and fruit.areas[1].delay==450,"fruit pressures the range of a single dodge and marks an offset follow-up")
  check(Lairs.escape(game,fruit,player.pos,now).is_finite(),"a deliberate route exits both fruit warnings")
  for id in range(2,5):
   game.players[id].pos=player.pos+Vector3.RIGHT.rotated(Vector3.UP,id*1.7)*2.75

  check(Lairs.commit(game,"root_cage",1,now),"root cage can commit with four living players")
  var cage: Dictionary=game.tactics.memory.lair_plan
  var gap_axis:=Lairs.direction(cage.from,cage.to)
  var gap_distance:=3.0
  var first: Vector3=cage.from+gap_axis*gap_distance
  var second: Vector3=cage.from-gap_axis*gap_distance
  var dangerous: Vector3=cage.from+gap_axis.cross(Vector3.UP)*gap_distance
  check(not Lairs.covered(cage,first,.32) and not Lairs.covered(cage,second,.32),"both opposite gaps remain open with player clearance")
  check(Lairs.covered(cage,dangerous) and Lairs.covered(cage,cage.from),"cage threatens the sides and the starting point")
  for member in game.players.values():
   if Lairs.covered(cage,member.pos,.25):
    check(Lairs.escape(game,cage,member.pos,now).is_finite(),"committed cage has an escape for every threatened party member")
   member[PlayerVitals.STATE] = member[PlayerVitals.STATE].with_hp(10)
   member.hurt_until=0
  var hint: Dictionary=game.attack_hints_snapshot().filter(func(h):return h.role=="orchard_cage")[0]
  check(hint.inner==cage.inner and hint.radius==cage.radius and hint.span==cage.span,"cage warning carries the committed safe gap geometry")
  player.pos=first
  game.players[2].pos=second
  game.players[3].pos=dangerous
  game.players[4].pos=cage.from
  game.Bosses.resolve(game,game.tactics.strike_at)
  check(PlayerVitals.current_hp(player)==10 and PlayerVitals.current_hp(game.players[2])==10 and PlayerVitals.current_hp(game.players[3])==8 and PlayerVitals.current_hp(game.players[4])==8,"the host damages only the marked cage area")
  var release: Dictionary=game.combat_events.back()
  check(release.shape=="orchard_cage" and release.reach==hint.radius and release.width==hint.inner and release.span==hint.span,"cage impact uses the warning footprint")

 for id in range(2,5):
  ExpeditionCase.set_membership(game, game.players[id], false)
 build(game,Routes.ORCHARD,9143)
 player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(10)
 player.pos=Vector3(0,0,14.5)
 game.tactics.stagger_until=0
 game.encounter.set_hp(-1, ceili(game.encounter_health()*.5))
 game.Bosses.tick(game,.016,now)
 check(game.tactics.winding_up and game.tactics.attack_mode=="falling_fruit","Orchard can mark a player well beyond the old 5m cast range")
 check(game.tactics.memory.lair_plan.areas[0].point==player.pos,"distant fruit locks the target position")
 game.tactics.winding_up=false
 game.tactics.ready_at=0
 game.tactics.boss_moves=5
 game.tactics.boss_phase=0
 game.encounter.set_hp(-1, ceili(game.encounter_health()*.25))
 player.pos=Vector3(0,0,6)
 game.Bosses.tick(game,.016,now)
 check(game.tactics.boss_phase==2 and game.tactics.memory.orchard_phase_start==5 and not game.tactics.winding_up,"the phase cue precedes the new rotation")
 var cast_time:=now+1100
 for move in Orchard.LATE_ROTATION:
  game.enemy_hazards.clear()
  game.Bosses.tick(game,.016,cast_time)
  check(game.tactics.winding_up and game.tactics.attack_mode==move,"late rotation commits "+move)
  if not game.tactics.winding_up:
   break
  var plan: Dictionary=game.tactics.memory.lair_plan
  var strike: int=game.tactics.strike_at
  game.Bosses.resolve(game,strike)
  if move in ["root_sweep","falling_fruit"]:
   check(game.tactics.ready_at-strike<600,"late pressure follows quickly after "+move)
  if move=="orchard_march":
   check(game.Bosses.exposed(game,strike) and game.tactics.ready_at-strike>=2700,"march still exposes a punish window")
  player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(10)
  player.hurt_until=0
  cast_time=game.tactics.ready_at
