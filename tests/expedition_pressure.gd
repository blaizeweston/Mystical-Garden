extends SceneTree

const PlayerVitals = preload("res://player_vitals.gd")
const Pressure=preload("res://expedition_pressure.gd")
var failed:=false
var game: Node
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL reinforcement pressure: ",message)
func _initialize() -> void:
 preload("res://combat_balance_preview.gd").enabled = false
 call_deferred("run")
func reset_floor(seed_value: int=91273) -> void:
 game.session="Solo";game.difficulty_cycle=1;game.encounter_number=19;game.destination=0;game.depth=1;game.map_seed=seed_value;game.reset_encounter()
 for p in game.players.values():p.wild=true;p.fallen=false;p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10);p.pos=game.battlefield.entry
 game.scouts.clear();game.enemy_hp=10
func warn(now: int) -> Array:
 game.pressure_at=now;game.update_pressure(now)
 return Pressure.hints(game,now)
func run() -> void:
 game=load("res://world.tscn").instantiate()
 var folder:="user://release-fixtures/pressure-"+Crypto.new().generate_random_bytes(8).hex_encode()
 DirAccess.make_dir_recursive_absolute(folder)
 game.progress.path=folder+"/world.cfg";game.local_character.path=folder+"/character.cfg";game.guest_character.path=folder+"/guest.cfg"
 root.add_child(game);game.set_process(false);game.set_physics_process(false)
 reset_floor()
 var p: Dictionary=game.players[1];var rng_state: int=game.rng.state
 game.update_pressure(1000)
 check(game.pressure_at==36000 and PlayerVitals.current_hp(p)==10,"first warning waits 35 seconds and never damages")
 var hints:=warn(36000)
 check(hints.size()==1 and hints[0].role=="reinforcement" and hints[0].remaining==3.0,"first wave announces exact location for three seconds")
 check(game.attack_hints_snapshot().any(func(h):return h.role=="reinforcement"),"warning uses replicated attack hint channel")
 game.combat_visuals.sync([],hints,"pressure-test",game.leader_brain.pressure.pending[0].pos)
 var visual: Dictionary=game.combat_visuals.hints[hints[0].id]
 check(visual.root.visible and visual.label.text.contains("Reinforcements") and visual.mesh.mesh.get_surface_count()>0,"spawn marker has a visible countdown label and ground ring")
 game.combat_visuals.sync([],[],"pressure-test",p.pos)
 check(game.combat_visuals.hints.is_empty(),"cancelled markers leave no residual graphics")
 game.update_pressure(38999)
 check(game.scouts.is_empty() and PlayerVitals.current_hp(p)==10,"warning itself cannot hit or spawn early")
 game.update_pressure(39000);game.update_pressure(39000)
 check(game.scouts.size()==1 and PlayerVitals.current_hp(p)==10,"due wave spawns once without health loss")
 if not game.scouts.is_empty():
  var scout: Dictionary=game.scouts[0]
  check(scout.pos.distance_to(p.pos)>=Pressure.SAFE_DISTANCE and not game.battlefield.occupied(scout.pos,.5),"arrival stays on floor and away from player")
  check(scout.engaged and scout.ready==39700 and scout.stagger_until==39700,"arrival has combat grace before normal attacks")
  check(scout.summoned and not game.Enemies.is_support(scout.kind) and not game.Enemies.get_kind(scout.kind).get("boss",false),"non-support reinforcement uses existing non-farmable summon rules")
  check(game.rng.state==rng_state,"pressure planning leaves combat/loot RNG untouched")
  var before: int=game.encounter_kills.size();var records: int=game.encounter_kill_records.size()
  game.record_enemy_death(0,scout.pos,p.pos)
  check(game.encounter_kills.size()==before and game.encounter_kill_records.size()==records,"repeatable arrivals cannot farm progression or learning records")
 check(game.rng.state==rng_state,"pressure planning leaves combat/loot RNG untouched")
 reset_floor();hints=warn(1000)
 check(not hints.is_empty(),"unsafe-arrival fixture has a planned site")
 if not hints.is_empty():
  p.pos=game.leader_brain.pressure.pending[0].pos
  game.update_pressure(4000)
  check(game.scouts.is_empty() and PlayerVitals.current_hp(p)==10,"occupied warning cancels rather than spawning on player or moving to unwarned site")
 reset_floor();warn(1000);game.enemy_hp=0;game.update_pressure(4000)
 check(game.encounter_cleared() and game.scouts.is_empty() and game.pressure_at==0 and Pressure.hints(game).is_empty(),"clearing floor cancels pending wave and keeps exit open")
 for mode in ["early","boss","garden","fallen","guest"]:
  reset_floor()
  if mode=="early":game.difficulty_cycle=0
  elif mode=="boss":game.boss_kind=24
  elif mode=="garden":p.wild=false
  elif mode=="fallen":p.fallen=true;p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(0)
  else:game.session="Guest"
  game.update_pressure(1000);game.update_pressure(100000)
  check(game.scouts.is_empty() and PlayerVitals.current_hp(p)==(0 if mode=="fallen" else 10),"no pressure damage or arrivals in "+mode)
 reset_floor();game.add_player(2);game.players[2].profile_ready=true;game.players[2].wild=true;game.players[2].pos=p.pos
 for wave in range(1,17):
  game.scouts.clear();game.leader_brain.pressure={"wave":wave-1,"pending":[]}
  hints=warn(wave*100000)
  check(hints.size()<=4,"wave size bounded")
  game.update_pressure(wave*100000+3000)
  for scout in game.scouts:
   for player in game.players.values():check(scout.pos.distance_to(player.pos)>=Pressure.SAFE_DISTANCE,"arrival safe for every co-op player")
  check(game.scouts.size()<=Pressure.capacity(game) and Pressure.interval(30,wave)>=18000,"bounded escalation")
 reset_floor()
 for i in Pressure.capacity(game):game.scouts.append(game.make_scout(0,game.battlefield.leader,i))
 warn(1000);game.update_pressure(4000)
 check(game.scouts.size()==Pressure.capacity(game) and Pressure.hints(game).is_empty(),"full encounter does not overflow synchronized population")
 reset_floor()
 var corpse: Dictionary=game.make_scout(0,game.battlefield.leader,0);corpse.hp=0;game.scouts.append(corpse)
 var token: int=corpse.spawn_token
 warn(1000);game.update_pressure(4000)
 check(game.scouts.size()==1 and game.scouts[0].hp>0 and game.scouts[0].spawn_token>token,"dead slots reused with fresh identity")
 reset_floor();warn(1000);game.reset_encounter()
 check(Pressure.hints(game).is_empty() and game.pressure_at==0,"travel resets transient warnings")
 game.queue_free();await process_frame
 if not failed:print("PASS: avoidable reinforcement pressure, safe telegraphs, cancellation, escalation, authority, rewards and population bounds")
 quit(1 if failed else 0)
