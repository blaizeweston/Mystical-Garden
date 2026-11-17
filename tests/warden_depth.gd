extends SceneTree

const PlayerVitals = preload("res://player_vitals.gd")

const Cooldowns = preload("res://player_cooldowns.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL Warden depth: ",message)
func _initialize() -> void:
 preload("res://combat_balance_preview.gd").enabled = false
 call_deferred("run")
func build(game: Node,p: Dictionary,choices: Array) -> void:
 p.character=game.Character.blank();p.character.xp[0]=2600
 for index in choices:
  check(game.Classes.can_learn_legacy(p.character,0,index,7),"learned choice "+str(index));p.character.upgrades[0]|=1<<index
 p.frame=0;p.weapon_kind=0;p.weapon=game.Seeds.DEFINITIONS[15].part;p.secondary=0;p.catalyst=0;p.graft_part=game.Parts.HOOK;p.run_upgrades={};p.wild=true;p.fallen=false;p.pos=Vector3(0,0,-1);p[PlayerVitals.STATE] = PlayerVitals.Health.new(10, 10);p.power=0;p.technique=0;p.facing=Vector3.FORWARD
 p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0).with_deadline(Cooldowns.R, 0)
 for key in ["guard_until","front_guard_until","counter_guard_until","counter_until","hurt_until","brace_block_ready"]:p[key]=0
 game.battlefield.procedural=false;game.battlefield.barriers=[];game.scouts.clear();game.enemy_hp=100;game.enemy_pos=Vector3(0,0,-2);game.enemy_traits.clear();game.trait_events.clear();game.encounter_number=1
func run() -> void:
 var game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/warden-depth-"+str(Time.get_ticks_usec())+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1];game.add_player(2);var ally: Dictionary=game.players[2];ally.profile_ready=true;ally.wild=true;ally.pos=Vector3(.3,0,-1.7)
 build(game,p,[0,2,4,6,8,10])
 check(game.Classes.DEFINITIONS[0].nodes.size()==12 and game.Character.level(2600)==7,"twelve choices across seven levels")
 check(not game.Classes.can_learn(p.character,0,9,7) and not game.Classes.can_learn(p.character,0,11,7),"exclusive specialization branches")
 check(game.Skills.resolve(0,0,p.character).mode=="front_guard","Bastion changes the actual Q mode")
 game.use_class_skill(1,p);var now:=Time.get_ticks_msec()
 game.apply_enemy_hit(1,p,now,1,0,p.pos+Vector3.FORWARD)
 check(PlayerVitals.current_hp(p)==10 and p.guard_charges>0 and ally.guard_until>now,"front guard blocks and protects living ally")
 p.hurt_until=0;game.apply_enemy_hit(1,p,now+1,1,0,p.pos+Vector3.BACK)
 check(PlayerVitals.current_hp(p)==9,"directional shield leaves the rear exposed")
 var origin: Vector3=p.pos;game.move_player(1,Vector2.RIGHT,1.0)
 check(p.pos.distance_to(origin)<game.WALK_SPEED*.5,"root shield sacrifices mobility")
 p.pos=Vector3(0,0,-1);game.use_class_skill(1,p,1);check(game.trait_events.any(func(e):return e.kind=="tide" and e.ward),"Bastion R creates a warding field")
 ally.fallen=true;ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(0);game.Traits.tick(game,Time.get_ticks_msec()+1000);check(PlayerVitals.current_hp(ally)==0,"sanctuary does not revive fallen players")
 ally.fallen=false;ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(10)
 build(game,p,[1,3,5,7,9,11]);game.use_class_skill(1,p)
 game.apply_enemy_hit(1,p,Time.get_ticks_msec(),1,0,p.pos+Vector3.FORWARD)
 check(p.counter_until>0,"Vanguard successful guard primes counter")
 var before: int=game.enemy_hp;game.use_class_skill(1,p,1)
 check(game.enemy_hp<before-3 and p.counter_until==0,"charge consumes counter on actual hit with plant and monster stats")
 check(game.RunUpgrades.requirement(game.RunUpgrades.get_upgrade("link_frost_briar"),p).is_empty(),"Frostbell plus monster graft unlocks rare linking card")
 game.enemy_hp=0;game.encounter_number=6;p.pos=game.battlefield.advance;p[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new(10000, game.wallet_for(p).spent_essence());p.offer_floor=6;p.checkpoint_offers=["warden_guard_counter"]
 var mask: int=p.character.upgrades[0]
 check(game._buy_upgrade(1,p,0) and game.weapon_stats(p).counter_damage>=2,"real Wilds purchase augments class counter")
 check(p.character.upgrades[0]==mask and p.weapon==44 and p.graft_part==game.Parts.HOOK,"run purchase preserves learned choices, plant slots and graft")
 game.local_character.data=p.character;game.local_character.save_profile();var profile=game.Character.new();profile.path=game.local_character.path;profile.load_profile()
 check(profile.data.upgrades[0]==mask,"new branch choices survive save and normalization")
 game.progression_view.inspected_class=0
 var nodes: Array=game.progression_view.class_nodes()
 check(nodes.size()==13 and nodes.all(func(n):return n.position.y>=0),"all Warden nodes visible in scrollable tree")
 var tip: Dictionary=nodes.filter(func(n):return n.id=="class_0_11")[0]
 check(tip.parents==["class_0_9"],"tree draws actual specialization prerequisite")
 game.queue_free();await process_frame
 if not failed:print("PASS: Warden depth directional guard, counters, fields, plant/graft synergy, checkpoint purchase, branches and persistence")
 quit(1 if failed else 0)
