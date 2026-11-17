extends SceneTree

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")

const Cooldowns = preload("res://player_cooldowns.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL class depth: ",message)
func _initialize() -> void: call_deferred("run")
func arena(game: Node,p: Dictionary,c: int,right: bool=false) -> void:
 p.character=game.Character.blank();p.character.active_class=c;p.character.xp[c]=2600
 for index in ([1,3,5,7,9,11] if right else [0,2,4,6,8,10]):
  check(game.Classes.can_learn_legacy(p.character,c,index,7),"learn valid branch "+str(c)+":"+str(index));p.character.upgrades[c]|=1<<index
 p.frame=c;p.weapon_kind=0;p.weapon=0;p.secondary=0;p.catalyst=0;p.graft_part=0;p.run_upgrades={};p.wild=true;p[PlayerLifecycle.STATE] = p[PlayerLifecycle.STATE].clear_inactive();p.pos=Vector3(0,0,-1.5);p[PlayerVitals.STATE] = PlayerVitals.Health.new(5, 10);p.power=0;p.technique=0;p.facing=Vector3.FORWARD;p.lost_health=0
 p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0).with_deadline(Cooldowns.R, 0)
 for key in ["guard_until","front_guard_until","counter_guard_until","counter_until","hurt_until","brace_block_ready","grave_charges","prepared_mark_until","decoy_ready"]:p[key]=0
 game.battlefield.procedural=false;game.battlefield.barriers=[];game.encounter.clear_scouts();game.encounter.set_hp(-1, 100);game.enemy_pos=Vector3.ZERO;game.enemy_mutations=0;game.enemy_winding_up=false;game.enemy_traits.clear();game.trait_events.clear();game.encounter_number=1;game.combat_epoch+=1
 var scout: Dictionary=game.make_scout(0,Vector3(.6,0,.2),0);scout.hp=100;game.encounter.register_scout(scout)
func run() -> void:
 var game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/class-depth-"+str(Time.get_ticks_usec())+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1]
 for c in 5:
  check(game.Classes.DEFINITIONS[c].nodes.size()==12 and game.Classes.DEFINITIONS[c].specializations.size()==2,"twelve meaningful choices and two directions "+str(c))
  for right in [false,true]:
   arena(game,p,c,right)
   var norm: Dictionary=game.Character.normalize(p.character)
   check(norm.upgrades[c]==p.character.upgrades[c],"choice normalization "+str(c))
   game.progression_view.inspected_class=c
   var nodes: Array=game.progression_view.class_nodes()
   check(nodes.size()==13 and nodes.all(func(n):return n.position.y>=0),"entire six-row tree is on canvas "+str(c))
 # Weaver Rootbinder spreads root state to real enemies.
 arena(game,p,1);game.use_class_skill(1,p,0)
 check(game.rooted_until>Time.get_ticks_msec() and game.encounter.scout(0).rooted_until>Time.get_ticks_msec(),"Rootbinder links restraints")
 arena(game,p,1,true);game.use_class_skill(1,p,1)
 check(p[Cooldowns.STATE].deadline(Cooldowns.R)==0,"Bloom Detonation without a bloom preserves cooldown")
 game.use_class_skill(1,p,0);check(game.Traits.has_growth(game,p),"Bloomcaller cultivates an actual field")
 var hp: int=game.enemy_health();game.Traits.tick(game,Time.get_ticks_msec()+100)
 check(game.enemy_health()<hp,"cultivated field pulses damage")
 hp=game.enemy_health();game.use_class_skill(1,p,1)
 check(game.enemy_health()<hp and not game.Traits.has_growth(game,p) and game.combat_events.any(func(e):return e.kind=="field_end"),"detonation consumes growth, cancels its model and damages foes")
 # Ranger precision requires a previous mark; the alternate path creates lures and traps.
 arena(game,p,2);game.use_class_skill(1,p,0)
 check(game.enemy_traits.get("marked_until",0)>Time.get_ticks_msec(),"Wildstalker salvo marks")
 var old: Vector3=p.pos;game.use_class_skill(1,p,1)
 check(p.pos.distance_to(old)>.1 and p.prepared_mark_until>Time.get_ticks_msec(),"Wildstalker retreat repositions and prepares follow-up")
 arena(game,p,2,true);game.use_class_skill(1,p,0)
 check(game.Traits.decoy_point(game,1)!=Vector3.INF,"Snarekeeper shot lures pursuit")
 game.use_class_skill(1,p,1)
 check(game.rooted_until>Time.get_ticks_msec() and game.Traits.has_growth(game,p),"Snarekeeper lattice roots and creates damaging terrain")
 # Reaper movement and queued marks resolve through authoritative hit handling.
 arena(game,p,3);game.use_class_skill(1,p,0);game.update_projectiles(Time.get_ticks_msec()+1000)
 check(p[Cooldowns.STATE].deadline(Cooldowns.Q)>0 and game.enemy_health()<100,"Blood Harvester commits a damaging approach")
 game.use_class_skill(1,p,1);check(PlayerVitals.current_hp(p)>5 and game.enemy_health()<100,"Blood Harvester earns healing from nearby victims")
 arena(game,p,3,true);game.use_class_skill(1,p,0)
 check(p.prepared_mark_until>Time.get_ticks_msec(),"Veilwalker passage prepares a mark")
 game.enemy_traits.clear();hp=game.enemy_health();game.use_class_skill(1,p,1)
 check(game.enemy_health()==hp and game.trait_events.any(func(e):return e.kind=="hit"),"Requiem waits before striking")
 game.Traits.tick(game,Time.get_ticks_msec()+1000)
 check(game.enemy_health()<hp,"Requiem's delayed mark resolves actual damage")
 game.add_player(2);var ally: Dictionary=game.players[2];ally.profile_ready=true;ally.wild=true;ally[PlayerLifecycle.STATE] = ally[PlayerLifecycle.STATE].clear_inactive();ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(4);ally.pos=Vector3(.3,0,-1)
 arena(game,p,4);game.use_class_skill(1,p,0)
 check(PlayerVitals.current_hp(ally)>4 and ally.guard_until>Time.get_ticks_msec() and game.trait_events.any(func(e):return e.kind=="tide"),"Lifekeeper places protection and healing")
 ally.slow_until=Time.get_ticks_msec()+4000;game.use_class_skill(1,p,1);check(ally.slow_until==0,"Lifekeeper bower cleanses")
 arena(game,p,4,true);game.use_class_skill(1,p,0);check(game.enemy_traits.get("marked_until",0)>Time.get_ticks_msec(),"Omenreader foretells enemy vulnerability")
 game.enemy_winding_up=true;hp=game.enemy_health();game.use_class_skill(1,p,1)
 check(hp-game.enemy_health()>=5,"Omenreader punishes marked wind-up")
 # Every class has new eligible cards; purchases augment rather than replace learned skills.
 for c in 5:
  arena(game,p,c);game.encounter.set_hp(-1, 0);game.encounter.clear_scouts();game.encounter_number=6;p.pos=game.battlefield.advance;p[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new(10000, game.wallet_for(p).spent_essence());p.offer_floor=6;p.last_offer=0
  var candidates: Array=game.RunUpgrades.all().filter(func(e):return e.id.begins_with(["warden_","weaver_","ranger_","reaper_","oracle_"][c]))
  check(candidates.size()==4,"four new class behavior cards "+str(c))
  p.checkpoint_offers=[candidates[0].id];var mask: int=p.character.upgrades[c]
  check(game._buy_upgrade(1,p,0) and p.character.upgrades[c]==mask,"real class card purchase preserves specialization "+str(c))
 arena(game,p,2)
 check(not game.RunUpgrades.requirement(game.RunUpgrades.get_upgrade("ranger_trap"),p).is_empty(),"trap-only card excluded when both equipped skills lack traps")
 arena(game,p,1,true)
 check(not game.RunUpgrades.requirement(game.RunUpgrades.get_upgrade("weaver_spread"),p).is_empty(),"bind-only card excluded from pure bloom skills")
 arena(game,p,4,true)
 check(not game.RunUpgrades.requirement(game.RunUpgrades.get_upgrade("oracle_bower"),p).is_empty(),"healing-only card excluded from Omenreader damage kit")
 check(load("res://content_validator.gd").validate().is_empty(),"all class/effect content validates")
 game.queue_free();await process_frame
 if not failed:print("PASS: all five deeper classes, both specialization paths, actual abilities, branch persistence, trees and Wilds purchases")
 quit(1 if failed else 0)
