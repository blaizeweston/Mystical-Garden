extends SceneTree
const Fights=preload("res://boss_phase_fights.gd")
const Nest=preload("res://boss_nest_layout.gd")
const Safety=preload("res://boss_lair_fights.gd")
const Status=preload("res://combat_status.gd")
var failed:=false

func check(ok: bool, message: String) -> void:
 if not ok:
  failed=true
  printerr("FAIL boss phase fights: ",message)

func _initialize() -> void:
 preload("res://combat_balance_preview.gd").enabled = false
 call_deferred("run")

func setup(game: Node, kind: int, stamp: int) -> void:
 game.map_seed=stamp
 game.destination=0
 game.depth=2
 game.encounter_number=15
 game.boss_kind=kind
 game.boss_phase=0
 game.boss_moves=0
 game.enemy_kind=kind
 game.enemy_pos=Vector3(0,0,4.7)
 game.enemy_hp=85
 game.enemy_ready_at=0
 game.enemy_stagger_until=0
 game.enemy_engaged=true
 game.enemy_winding_up=false
 game.enemy_hazards.clear()
 game.scouts.clear()
 game.leader_brain.clear()
 game.battlefield.configure(0,2,stamp,kind,0)

func crossing_occupant(field: RefCounted, rect: Rect2) -> Vector3:
 for z in [-.62,-.4,-.2,0.0,.25,.50,.62]:
  for x in [-1.2,-.8,-.4,0.0,.4,.8,1.2]:
   var point:=rect.get_center()+Vector2(x,z)
   var at:=Vector3(point.x,0,point.y)
   if not field.occupied(at,.4):return at
 return Vector3.INF

func check_nest(game: Node, player: Dictionary) -> void:
 var now:=Time.get_ticks_msec()+100
 setup(game,Fights.NEST,98117)
 player.pos=Vector3(0,0,7.0)
 check(Fights.commit(game,"brood_call",1,now),"opening hatch is committed")
 var base: Dictionary=game.leader_brain.phase_plan
 check(base.hatches.size()==1,"opening phase uses one entrance")
 var strike: int=game.enemy_strike_at
 game.Bosses.resolve(game,strike)
 check(game.scouts.size()==1 and game.scouts[0].summoned,"hatch creates a nonrewarding scout")
 for repetition in 2:
  var child: Dictionary=game.scouts[0]
  var current: int=strike+repetition*600
  game.apply_weapon_hit(player,0,player.pos,{"damage":2,"knockback":0},current)
  Fights.observe_brood(game,current)
  Fights.observe_brood(game,current+1)
  check(int(game.leader_brain.get("nursery_pressure",0))==repetition+1,"a defeated hatchling counts once near the same entrance")
  if repetition==0:
   Fights.commit(game,"brood_call",1,current+50)
   game.Bosses.resolve(game,current+75)
   strike=current+75
 check(game.monster_rewards.pending_count()==0,"killed brood never pays rewards")

 var original: Array=game.battlefield.barriers.duplicate()
 var upcoming:=Nest.ribs(1)
 player.pos=crossing_occupant(game.battlefield,upcoming[0])
 check(player.pos.is_finite(),"fixture finds a spot only occupied after the shift")
 var before: Vector3=player.pos
 var escort: Dictionary=game.make_scout(0,crossing_occupant(game.battlefield,upcoming[1]),1)
 game.scouts.append(escort)
 now=Time.get_ticks_msec()+7000
 check(Fights.advance_phase(game,1,now),"phase threshold starts a preview")
 check(game.boss_phase==0 and game.battlefield.barriers==original and player.pos==before,"old collision stays active during preview")
 var hints: Array=game.attack_hints_snapshot()
 check(hints.filter(func(h):return h.role=="nursery_rib").size()==6,"all six future ribs are displayed")
 check(hints.filter(func(h):return h.role=="nursery_site").size()==2,"phase preview displays the two nursery sites")
 var first: Rect2=upcoming[0]
 var warned: Dictionary=hints.filter(func(h):return h.role=="nursery_rib")[0]
 check(warned.bounds==[first.position.x,first.position.y,first.size.x,first.size.y],"warning matches exact future collision bounds")
 Fights.advance_phase(game,1,now+1950)
 check(game.boss_phase==0 and game.leader_brain.nest_shift.grace,"occupied ribs give a final grace period")
 Fights.advance_phase(game,1,now+2850)
 check(game.boss_phase==1 and game.battlefield.barriers==upcoming and game.battlefield.connected(),"future ribs become authority only after the grace")
 check(before.distance_to(player.pos)<=2.8 and not game.battlefield.occupied(player.pos,.34) and not game.battlefield.occupied(escort.pos,.34),"players and escorts move to nearby open ground")
 check(player.hp==10 and game.leader_brain.nursery_split,"shifting terrain is harmless and prior brood pressure opens the second site")
 game._process(.016)
 check(game.stage.get_meta("rendered_lair",Vector2i.ZERO)==Vector2i(Fights.NEST,1),"host redraws the new phase from its shared battlefield")

 game.scouts.clear()
 game.enemy_pos=Vector3(0,0,5)
 player.pos=Vector3(0,0,7)
 check(Fights.commit(game,"brood_call",1,now+3200),"both open exits are usable")
 var hatch: Array=game.leader_brain.phase_plan.hatches.duplicate()
 check(hatch.size()==2,"two hatch markers are committed")
 if hatch.size()!=2:return
 game.apply_weapon_hit(player,-1,player.pos,{"damage":1,"stagger":160},now+3400)
 check(game.scouts.is_empty() and not game.enemy_winding_up,"a heavy hit interrupts the hatch")
 Status.sync(game,now+3400)
 check(Status.snapshot(game,now+3400).any(func(event):return event.shape=="nursery_lull"),"nursery lull is displayed")
 Fights.commit(game,"brood_call",1,now+5500)
 player.pos=hatch[0]
 game.Bosses.resolve(game,now+7300)
 check(game.scouts.size()==1 and game.scouts[0].pos==hatch[1],"blocking one marked hatch leaves the other active")
 player.pos=Vector3(0,0,7)
 for attempt in 5:
  Fights.commit(game,"brood_call",1,now+8200+attempt*3800)
  game.Bosses.resolve(game,now+10000+attempt*3800)
 check(game.scouts.filter(func(child):return child.hp>0 and child.summoned).size()<=Fights.BROOD_LIMIT,"repeated casts respect the four-living-child cap")
 for phase in 3:
  game.battlefield.configure(0,2,game.map_seed,Fights.NEST,phase)
  check(game.battlefield.barriers==Nest.ribs(phase) and game.battlefield.connected() and game.battlefield.spawn_points.size()>=4,"phase keeps its actual ribs, routes and legal scout staging")

func check_bloom(game: Node, player: Dictionary) -> void:
 var now:=Time.get_ticks_msec()+100
 setup(game,Fights.BLOOM,77241)
 player.pos=Vector3(0,0,8)
 check(Fights.memory({"ranged":5,"choke":4,"burst":3,"kite":5},0).is_empty(),"varied or weak history yields baseline")
 check(Fights.memory({"ranged":7,"burst":11,"choke":8},0)=="burst","strongest supported memory wins")
 check(Fights.memory({"ranged":9,"burst":9},0)!=Fights.memory({"ranged":9,"burst":9},1),"tied evidence rotates deterministically by phase")
 game.progress.wilds_memory.score={"choke":12,"burst":9}
 check(Fights.advance_phase(game,0,now),"opening phase chooses a growth")
 check(game.leader_brain.memory_growth.id=="choke" and game.enemy_ready_at>=now+1450,"one growth is previewed before attacking")
 game.progress.wilds_memory.score={"burst":19}
 check(game.leader_brain.memory_growth.id=="choke","phase choice stays locked when history changes")
 var move_set: Array=[]
 for index in 3:
  game.boss_moves=index
  move_set.append(Fights.choice(game,"memory_lance"))
 game.boss_moves=0
 check(move_set==["remembered_rend","memory_lance","spore_constellation"],"a phase uses its signature and both other moves")
 var hints: Array=game.attack_hints_snapshot()
 check(hints.any(func(h):return h.role=="memory_growth" and h.growth=="choke") and hints.any(func(h):return h.get("cue","")=="Forked roots"),"forked growth and its name are published")
 game.enemy_pos=Vector3(0,0,2)
 check(Fights.commit(game,"memory_lance",1,now+1500),"signature replaces the opening base move")
 var plan: Dictionary=game.leader_brain.phase_plan
 check(plan.mode=="remembered_rend" and plan.variant=="choke" and plan.lanes.size()==2,"choke pressure creates two rend lanes")
 check(not Safety.covered(plan,player.pos,.15),"both lanes leave a central gap")
 if plan.lanes.size()!=2:return
 hints=game.attack_hints_snapshot().filter(func(h):return h.role=="charge")
 check(hints.size()==2 and hints[0].width>plan.lanes[0].width,"each damage lane has a padded warning")
 var strike: int=game.enemy_strike_at
 player.pos=plan.lanes[0].from.lerp(plan.lanes[0].to,.55)
 player.hp=10;player.hurt_until=0
 game.Bosses.resolve(game,strike)
 check(player.hp==10-int(game.Enemies.get_kind(Fights.BLOOM).damage),"crossing a displayed rend branch applies damage")
 check(game.Bosses.exposed(game,strike),"memory response opens a punish window")
 check(Fights.advance_phase(game,1,strike+2500),"next phase reads the newly strongest evidence")
 check(game.leader_brain.memory_growth.id=="burst","a new phase replaces the previous growth")
 player.pos=Vector3(0,0,7.0)
 player.hp=10;player.hurt_until=0
 check(Fights.commit(game,"remembered_rend",1,strike+4000),"burst response commits")
 plan=game.leader_brain.phase_plan
 check(plan.variant=="burst" and plan.areas.size()==3,"delayed constellation marks three bounded patches")
 strike=game.enemy_strike_at
 game.Bosses.resolve(game,strike)
 game.Bosses.tick_hazards(game,strike+349)
 check(player.hp==10,"constellation does not hit ahead of its announced pulse")
 game.Bosses.tick_hazards(game,strike+350)
 check(player.hp<10,"constellation hits at its announced time")
 game.enemy_hazards.clear()

 for style in ["ranged","kite"]:
  setup(game,Fights.BLOOM,77241)
  game.progress.wilds_memory.score={style:10}
  player.pos=Vector3(0,0,8)
  game.combat_velocity[1]=Vector3.RIGHT*3.5
  Fights.advance_phase(game,0,now)
  check(Fights.commit(game,"spore_constellation",1,now+1600),"lance adaptation commits")
  plan=game.leader_brain.phase_plan
  check(plan.mode=="memory_lance" and plan.lanes.size()==1 and plan.variant==style,"one authored lance for "+style)
  if style=="ranged":check(absf(plan.lanes[0].from.x)>1.0,"side lance starts at the visible offset")
  else:check(plan.lanes[0].to.x>1.0,"tracking lance leads movement")

func run() -> void:
 var game=load("res://world.tscn").instantiate()
 game.progress.path="res://.godot/phase-fights-"+str(Time.get_ticks_usec())
 game.local_character.path=game.progress.path+".character"
 root.add_child(game)
 game.set_process(false);game.set_physics_process(false)
 var player: Dictionary=game.players[1]
 player.wild=true;player.hp=10
 check_nest(game,player)
 check_bloom(game,player)
 game.queue_free()
 await process_frame
 if not failed:print("PASS: exact rib preview, safe transition with occupants, blocked and interruptible hatches, bounded unrewarded brood, one growth per phase, split gaps and timed memory damage")
 quit(1 if failed else 0)
