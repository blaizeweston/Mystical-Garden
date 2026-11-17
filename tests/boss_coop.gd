extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Lairs=preload("res://boss_lair_fights.gd")
const Routes=preload("res://boss_lair_routes.gd")
const Orchard=preload("res://orchard_moves.gd")
const Phases=preload("res://boss_phase_fights.gd")
const Nest=preload("res://boss_nest_layout.gd")
var game: Node
var role: String
var base: String
var failed=false
func check(ok: bool,message: String) -> void:
 if not ok: failed=true;printerr("FAIL boss co-op ",role,": ",message)
func mark(key: String) -> void:
 var file=FileAccess.open(base+"-"+key,FileAccess.WRITE);file.store_string("ok")
func marked(key: String) -> bool: return FileAccess.file_exists(base+"-"+key)
func until(predicate: Callable) -> bool:
 var deadline=Time.get_ticks_msec()+20000
 while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
 return predicate.call()
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 role=OS.get_cmdline_user_args()[0];base="res://.godot/boss-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role+".cfg";game.local_character.path=game.progress.path+".character";game.guest_character.path=game.progress.path+".guest";root.add_child(game)
 if role=="host": await host_run()
 else: await guest_run()
 game.queue_free();await process_frame
 if not failed: print("PASS: boss co-op ",role," four synchronized lairs, boss previews and growths, safe geometry, private rewards and modern build projections")
 quit(1 if failed else 0)
func host_run() -> void:
 check(SessionCase.World.host(game)==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return SessionCase.Session.ready_for(p))):
  check(false,"guest registers");return
 var id=int(game.players.keys()[1]);var p: Dictionary=game.players[id]
 for kind in range(20,24):
  ExpeditionCase.set_world(game, {"destination": 0});ExpeditionCase.set_world(game, {"encounter_number": 20+kind-20});ExpeditionCase.set_world(game, {"depth": kind-19});ExpeditionCase.set_world(game, {"map_seed": 91661+kind})
  game.wild_item_drops.clear();game.boss_floors[str(game.participation.floor())]=kind;game.used_bosses.append(kind);game.reset_encounter();game.encounter.clear_scouts();game.tactics.stagger_until=Time.get_ticks_msec()+60000
  for player in game.players.values(): ExpeditionCase.set_membership(game, player, true);player[PlayerLifecycle.STATE] = player[PlayerLifecycle.STATE].clear_inactive();player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(100);player.pos=Vector3(0,0,1)
  check(await until(func():return marked("view-"+str(kind))),"guest receives boss presentation "+str(kind))
  if Routes.supports(kind):await host_lair(kind,id)
  if kind==Phases.NEST:await host_nest(id)
  if kind==Phases.BLOOM:await host_memory(id)
  var entry: Dictionary=game.Enemies.get_kind(kind);var chance: float=entry.trophy_chance;entry.trophy_chance=1.0
  game.encounter.set_hp(-1, 0);game.encounter_rewarded=true
  game.record_enemy_death(-1,p.pos,p.pos);check(game.flush_kill_rewards(),"boss kill commits")
  entry.trophy_chance=chance
  check(await until(func():return marked("loot-"+str(kind))),"guest sees owner-only boss loot")
  var own: Array=game.inventory_floor_snapshot(game.players[1]);var guest: Array=game.inventory_floor_snapshot(p)
  check(own.size()==2 and guest.size()==2 and own[0].id!=guest[0].id,"independent trophy and seed for both peers")
  for drop in guest:game.pickup_inventory_drop(id,p,drop.id)
  check(p.carried_parts[game.Parts.monster_part(kind)]>0 and int(p.carried_items.get("boss_mystery_seed",0))>0,"authority credits guest pickup")
  mark("picked-"+str(kind))
  check(await until(func():return marked("next-"+str(kind))),"guest confirms pickup")
 mark("done");check(await until(func():return game.players.size()==1),"guest disconnects normally");SessionCase.World.leave(game,"Boss fixture complete")
func host_lair(kind: int, id: int) -> void:
 var now:=Time.get_ticks_msec()
 game.tactics.boss_phase=1
 game.battlefield.configure(game.participation.route(),game.participation.depth(),game.participation.seed(),kind,1)
 game.tactics.position=Vector3.ZERO
 var player: Dictionary=game.players[id]
 var mode: String="root_sweep" if kind==Routes.ORCHARD else "grasping_pool"
 var layout:=Routes.crossings(game.participation.seed())
 player.pos=Vector3(0,0,12.4) if kind==Routes.ORCHARD else Routes.bank(layout,1,.7)
 game.players[1].pos=Vector3(0,0,2) if kind==Routes.ORCHARD else Routes.bank(layout,0,.7)
 game.tactics.memory.lair_tracks={id:{"outer":8,"streak":8,"point":player.pos,"lane":1}}
 check(Lairs.commit(game,mode,id,now),"host commits the adapted move")
 var plan: Dictionary=game.tactics.memory.lair_plan
 check(not plan.variant.is_empty(),"host has an adapted footprint")
 var escape:=Lairs.escape(game,plan,player.pos,now)
 game.tactics.strike_at=now+18000
 check(await until(func():return marked("warning-"+str(kind))),"guest received committed warning")
 player.pos=escape
 game.Bosses.resolve(game,Time.get_ticks_msec())
 check(await until(func():return marked("release-"+str(kind))),"guest received the actual strike state")
 check(PlayerVitals.current_hp(player)==100,"safe route also works for guest on host authority")
 player.pos=Vector3(0,0,1)
 if kind==Routes.ORCHARD:
  game.players[1].pos=player.pos
  now=Time.get_ticks_msec()
  check(Lairs.commit(game,"root_cage",id,now),"host commits the root cage")
  plan=game.tactics.memory.lair_plan
  game.tactics.strike_at=now+18000
  check(await until(func():return marked("cage-warning")),"guest receives the cage and its gaps")
  player.pos=Lairs.escape(game,plan,player.pos,now)
  var cage_damage: int=game.Life.Preview.effect_hp(game.Director.Balance.boss_hit(game,game.Enemies.get_kind(kind),"root_cage"))
  game.Bosses.resolve(game,Time.get_ticks_msec())
  check(PlayerVitals.current_hp(player)==100 and PlayerVitals.current_hp(game.players[1])==100-cage_damage,"authority respects the gap while striking the center")
  check(await until(func():return marked("cage-release")),"guest sees the committed impact")

func guest_lair(kind: int, id: int) -> void:
 var warning_role: String="orchard_sweep" if kind==Routes.ORCHARD else "lair_zone"
 var player: Dictionary=game.players[id]
 var arrived:=await until(func():
  return game.stage.visual_field.boss_phase==1 and game.players[id].get("attack_hints",[]).any(func(h):return h.role==warning_role))
 check(arrived,"guest sees the adapted warning and lair phase")
 if not arrived:
  mark("warning-"+str(kind))
  mark("release-"+str(kind))
  return
 player=game.players[id]
 var hint: Dictionary=player.attack_hints.filter(func(h):return h.role==warning_role)[0]
 var point:=Vector3(hint.to[0],0,hint.to[2])
 var field: RefCounted=game.stage.visual_field
 if kind==Routes.ORCHARD:
  check(hint.inner>8.0 and hint.radius>17.0 and hint.cue=="Outer roots","guest receives the sweep's safe interior")
  var at:=point.normalized()*7.9
  check(field.clear_line(point,at,.34),"visible retreat is also clear in guest collision")
 else:
  var layout:=Routes.crossings(game.participation.seed())
  var first:=Routes.bank(layout,0,layout.bars[0])
  var second:=Routes.bank(layout,0,layout.bars[1])
  check(hint.lair=="water" and hint.cue=="Causeway flooding" and Routes.dry_lane(layout,point)==1,"guest sees the named bank and flooded footprint")
  check(field.clear_line(first,second,.34),"alternate causeway is navigable on guest")
 mark("warning-"+str(kind))
 if kind==Routes.ORCHARD:
  check(await until(func():return game.combat_visuals.statuses.active.values().any(func(status):return status.label.text=="Uprooting")),"guest sees the uprooting window")
 else:
  check(await until(func():return game.players[id].get("attack_hints",[]).any(func(h):
   return h.role=="hazard" and h.get("active",false) and h.get("lair","")=="water" and h.to==hint.to and h.radius==hint.radius)),"guest's active tide matches its warning")
 mark("release-"+str(kind))
 if kind==Routes.ORCHARD:
  await guest_cage(id)


func guest_cage(id: int) -> void:
 var warning := func(h):return h.role=="orchard_cage"
 var arrived:=await until(func():return game.players[id].get("attack_hints",[]).any(warning))
 check(arrived,"guest sees the cage warning")
 if not arrived:
  mark("cage-warning")
  mark("cage-release")
  return
 var hint: Dictionary=game.players[id].attack_hints.filter(warning)[0]
 var center:=Vector3(hint.from[0],0,hint.from[2])
 var direction:=(Vector3(hint.to[0],0,hint.to[2])-center).normalized()
 var field: RefCounted=game.stage.visual_field
 for side in [-1,1]:
  var exit: Vector3=center+direction*(2.8*side)
  check(field.clear_line(center,exit,.34) and not Orchard.inside_cage(center,direction,exit,hint.radius,hint.inner,hint.span,.32),"guest sees a walkable gap")
 check(await until(func():return game.combat_visuals.hints.has(hint.id)),"guest renderer creates the cage hint")
 mark("cage-warning")
 check(await until(func():return game.combat_visuals.active.values().any(func(effect):
  var event: Dictionary=effect.event
  if event.shape!="orchard_cage":return false
  var impact_center:=Vector3(event.from[0],event.from[1],event.from[2])
  var impact_axis:=(Vector3(event.to[0],event.to[1],event.to[2])-impact_center).normalized()
  return impact_center.is_equal_approx(center) and impact_axis.is_equal_approx(direction) and is_equal_approx(event.reach,hint.radius) and is_equal_approx(event.width,hint.inner) and is_equal_approx(event.span,hint.span)
 )),"guest renders the locked cage impact")
 mark("cage-release")

func host_nest(id: int) -> void:
 var now:=Time.get_ticks_msec()
 game.tactics.position=Vector3(0,0,5)
 var player: Dictionary=game.players[id]
 var rib: Rect2=Nest.ribs(1)[0]
 player.pos=Vector3(rib.get_center().x,0,rib.position.y+.22)
 check(not game.battlefield.occupied(player.pos,.34),"guest starts on the future rib, on current clear ground")
 game.tactics.memory.nursery_pressure=2
 Phases.advance_phase(game,1,now)
 game.tactics.memory.nest_shift.until=now+18000
 check(await until(func():return marked("rib-preview")),"guest sees future ribs")
 game.tactics.memory.nest_shift.until=0
 Phases.advance_phase(game,1,Time.get_ticks_msec())
 check(game.tactics.boss_phase==0 and game.tactics.memory.nest_shift.grace,"occupied guest gets a grace period")
 check(await until(func():return marked("rib-grace")),"guest receives the grace cue")
 game.tactics.memory.nest_shift.until=0
 Phases.advance_phase(game,1,Time.get_ticks_msec())
 check(not game.battlefield.occupied(player.pos,.34) and PlayerVitals.current_hp(player)==100,"authority relocates the guest safely")
 check(await until(func():return marked("nest-phase")),"guest receives the committed new collision layout")
 player.pos=Vector3(0,0,7)
 game.players[1].pos=Vector3(0,0,7)
 check(Phases.commit(game,"brood_call",id,Time.get_ticks_msec()),"both exits are available after shift")
 game.tactics.strike_at=Time.get_ticks_msec()+18000
 check(await until(func():return marked("nest-hatches")),"guest sees both hatches")
 game.Bosses.resolve(game,Time.get_ticks_msec())
 check(await until(func():return marked("nest-brood")),"guest sees the spawned brood")
 game.encounter.clear_scouts()
 player.pos=Vector3(0,0,1)

func guest_nest(id: int) -> void:
 check(await until(func():return game.players[id].get("attack_hints",[]).any(func(h):return h.role=="nursery_rib")),"guest receives rib preview")
 var ribs:=Nest.ribs(1)
 var rect: Rect2=ribs[0]
 var preview: Array=game.players[id].get("attack_hints",[]).filter(func(h):return h.role=="nursery_rib")
 check(preview.size()==6 and preview[0].bounds==[rect.position.x,rect.position.y,rect.size.x,rect.size.y] and game.stage.visual_field.boss_phase==0,"guest sees future bounds while old collision remains live")
 mark("rib-preview")
 check(await until(func():return game.players[id].get("attack_hints",[]).any(func(h):return h.get("cue","")=="Ribs held open")),"guest sees the grace cue")
 mark("rib-grace")
 check(await until(func():return game.tactics.boss_phase==1 and game.stage.visual_field.boss_phase==1 and not game.stage.visual_field.occupied(game.players[id].pos,.34)),"guest position and collision agree after the shift")
 check(game.stage.visual_field.barriers==ribs,"guest collision matches all previewed ribs")
 mark("nest-phase")
 check(await until(func():return game.players[id].get("attack_hints",[]).filter(func(h):return h.role=="nursery_exit").size()==2),"guest receives the two committed hatch points")
 mark("nest-hatches")
 check(await until(func():return game.stage.support_models.filter(func(model):return model.visible).size()>=2),"guest receives both offspring")
 mark("nest-brood")

func host_memory(id: int) -> void:
 game.tactics.position=Vector3(0,0,2)
 game.players[id].pos=Vector3(0,0,7.4)
 game.players[1].pos=Vector3(0,0,7.4)
 game.progress.wilds_memory.score={"choke":15,"burst":8}
 Phases.advance_phase(game,0,Time.get_ticks_msec())
 game.tactics.memory.memory_growth.preview_until=Time.get_ticks_msec()+18000
 check(await until(func():return marked("memory-growth")),"guest sees one growth from host history")
 game.tactics.memory.memory_growth.preview_until=0
 check(Phases.commit(game,"memory_lance",id,Time.get_ticks_msec()),"host locks remembered split attack")
 game.tactics.strike_at=Time.get_ticks_msec()+18000
 check(await until(func():return marked("memory-lanes")),"guest sees both lanes")
 game.Bosses.resolve(game,Time.get_ticks_msec())
 check(await until(func():return marked("memory-exposed")),"guest sees the memory punish window")
 check(PlayerVitals.current_hp(game.players[id])==100,"middle gap is safe on the authority")
 game.tactics.memory.lair_open.until=0
 game.progress.wilds_memory.score={"burst":16}
 Phases.advance_phase(game,1,Time.get_ticks_msec())
 check(await until(func():return marked("memory-crown")),"guest sees the new phase growth replace the old growth")
 game.players[id].pos=Vector3(0,0,1)

func guest_memory(id: int) -> void:
 check(await until(func():return game.stage.foe_model.get("memory_key","")=="choke:0"),"guest renders the host's forked growth")
 var model: Node3D=game.stage.foe_model.model
 check(model.get_node_or_null("MemoryGrowth")!=null,"forked growth is attached to the visible model")
 mark("memory-growth")
 check(await until(func():return game.players[id].get("attack_hints",[]).filter(func(h):return h.role=="charge" and h.get("lair","")=="memory").size()==2),"guest gets both split rend footprints")
 mark("memory-lanes")
 check(await until(func():return game.combat_visuals.statuses.active.values().any(func(s):return s.label.text=="Memory exposed")),"guest gets the exposed status")
 mark("memory-exposed")
 check(await until(func():return game.tactics.boss_phase==1 and game.stage.foe_model.get("memory_key","")=="burst:1"),"guest shows the spore crown in phase one")
 check(model.get_children().filter(func(node):return node.name=="MemoryGrowth").size()==1,"only one phase growth stays on the model")
 mark("memory-crown")

func guest_run() -> void:
 game.guest_character.data.name="Boss guest";game.guest_character.save_profile();check(SessionCase.World.join(game)==OK,"guest connects")
 if not await until(func():return game.network_session.role()=="Guest" and not game.client_details.is_empty()): check(false,"guest accepted");return
 var id=game.multiplayer.get_unique_id()
 for kind in range(20,24):
  check(await until(func():return game.tactics.boss_kind==kind and game.stage.visual_field.boss_kind==kind),"shared boss map/weapon descriptor "+str(kind))
  var field=load("res://battlefield.gd").new();field.configure(0,game.participation.depth(),game.participation.seed(),kind,0)
  check(field.clearings==game.stage.visual_field.clearings and field.barriers==game.stage.visual_field.barriers,"same visible terrain as host")
  var p: Dictionary=game.players[id]
  check(not p.get("weapon_stats",{}).get("affinity_build",{}).is_empty(),"authoritative modern build arrives")
  check(game.encounter_health()==int(game.players[id].enemy_max_hp),"guest boss maximum health matches host party scaling")
  mark("view-"+str(kind))
  if Routes.supports(kind):await guest_lair(kind,id)
  if kind==Phases.NEST:await guest_nest(id)
  if kind==Phases.BLOOM:await guest_memory(id)
  check(await until(func():return game.players[id].get("ground_items",[]).size()==2),"guest sees private ancient seed and trophy")
  var drops: Array=game.players[id].get("ground_items",[])
  check(drops.any(func(d):return d.item=="boss_mystery_seed") and drops.any(func(d):return d.item==game.Items.part_id(game.Parts.monster_part(kind))),"correct species rewards")
  check(drops.all(func(d):return not d.has("seeds")),"unknown species not sent to guest")
  mark("loot-"+str(kind))
  check(await until(func():return marked("picked-"+str(kind)) and game.players[id].get("bag",{}).get("carry",[]).any(func(s):return s.item=="boss_mystery_seed")),"pickup synchronizes carried inventory")
  mark("next-"+str(kind))
 check(await until(func():return marked("done")),"host finishes");SessionCase.World.leave(game,"Boss fixture complete")
