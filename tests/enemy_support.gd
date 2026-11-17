extends SceneTree

const PlayerVitals = preload("res://player_vitals.gd")
const Attacks=preload("res://enemy_attack.gd")
const Support=preload("res://enemy_support.gd")
const Status=preload("res://combat_status.gd")
var failed:=false

func check(condition: bool, description: String) -> void:
 if not condition:
  failed=true
  printerr("FAIL enemy support: ",description)

func _initialize() -> void:
 preload("res://combat_balance_preview.gd").enabled = false
 call_deferred("run")

func run() -> void:
 var game=load("res://world.tscn").instantiate()
 game.progress.path="res://.godot/support-"+str(Time.get_ticks_usec())
 game.local_character.path=game.progress.path+".character"
 root.add_child(game)
 game.set_process(false)
 game.set_physics_process(false)
 game.battlefield.configure(0,1)
 game.battlefield.barriers.clear()
 game.boss_kind=-1
 game.enemy_hp=0
 game.encounter_number=12
 var player: Dictionary=game.players[1]
 player.wild=true
 player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(10)
 player.pos=Vector3(0,0,6)
 var now:=Time.get_ticks_msec()+100
 var grazer: Dictionary=game.make_scout(11,Vector3.ZERO,2)
 grazer.variant="planted_canopy"
 var escort: Dictionary=game.make_scout(0,Vector3(0,0,1.5),1)
 game.scouts.assign([grazer,escort])
 Attacks.lock(game,grazer,"stomp",player.pos,now+1200)
 check(not Support.shelter_source(game,1,escort.pos,player.pos,now).is_empty(),"canopy covers an ally from the front")
 check(Support.shelter_source(game,1,escort.pos,Vector3(0,0,-3),now).is_empty(),"attacking from behind bypasses planted canopy")
 Status.sync(game,now)
 check(Status.snapshot(game,now).any(func(event):return event.shape=="sheltered" and event.combo==1),"protected allies display Sheltered")
 check(game.attack_hints_snapshot().any(func(hint):return hint.role=="canopy_sector"),"canopy shows its facing")

 var bloom: Dictionary=game.make_scout(15,Vector3.ZERO,1)
 bloom.hp=3
 bloom.max_hp=9
 bloom.variant="long_tether"
 var corpse: Dictionary=game.make_scout(2,Vector3(0,0,6),2)
 corpse.hp=0
 var juvenile: Dictionary=game.make_scout(0,Vector3(1,0,0),3,0,0,true)
 juvenile.hp=0
 juvenile.summoned=true
 game.scouts.assign([bloom,corpse,juvenile,escort])
 Attacks.lock(game,bloom,"chant",bloom.pos,now+1300)
 check(bloom.attack.corpse.get("token",-1)==corpse.spawn_token,"long tether selects one natural corpse at lock")
 check(game.attack_hints_snapshot().any(func(hint):return hint.role=="corpse_tether" and is_equal_approx(hint.to[2],6)),"corpse tether reaches the selected site")
 game.scouts[1]=game.make_scout(0,corpse.pos,2)
 game.resolve_scout(bloom,game.Enemies.get_kind(15),now+1300)
 check(bloom.hp==3,"a replacement in the same slot cannot inherit a corpse tether")
 game.scouts[1]=corpse
 Attacks.lock(game,bloom,"chant",bloom.pos,now+2500)
 game.resolve_scout(bloom,game.Enemies.get_kind(15),now+2500)
 check(bloom.hp==5 and escort.haste_until>now+2500,"natural corpse pays once and hastens nearby fighters")
 Attacks.lock(game,bloom,"chant",bloom.pos,now+3200)
 check(bloom.attack.corpse.is_empty(),"no second cast can consume the same corpse")

 var mother: Dictionary=game.make_scout(9,Vector3.ZERO,2)
 mother.variant="split_nursery"
 game.scouts.assign([mother])
 Attacks.lock(game,mother,"brood",mother.pos,now+3600)
 var hatch: Array=mother.attack.hatch.duplicate()
 check(hatch.size()==2 and hatch[0].distance_to(hatch[1])>3,"split hatch shows two spaced exits")
 game.apply_weapon_hit(player,0,player.pos,{"damage":1,"stagger":170},now+3400)
 check(mother.windup==0 and game.scouts.size()==1,"a stagger attack can interrupt the birth from one angle")
 mother.pos=Vector3.ZERO
 Attacks.lock(game,mother,"brood",mother.pos,now+4800)
 player.pos=hatch[0]
 game.resolve_scout(mother,game.Enemies.get_kind(9),now+4800)
 check(mother.summons==1 and game.scouts[1].pos==hatch[1] and game.scouts[1].summoned,"occupying one hatch blocks just that child")

 var shepherd: Dictionary=game.make_scout(10,Vector3.ZERO,2)
 shepherd.variant="flank_command"
 escort.pos=Vector3(1,0,0)
 player.pos=Vector3(0,0,6)
 game.scouts.assign([shepherd,escort])
 Attacks.lock(game,shepherd,"shepherd",shepherd.pos,now+5100)
 check(shepherd.attack.has("flank"),"open terrain permits a flanking order")
 game.resolve_scout(shepherd,game.Enemies.get_kind(10),now+5100)
 check(escort.get("command_target",0)==1 and escort.has("command_via"),"one escort follows the marked alternate route")

 var lure: Dictionary=game.make_scout(12,Vector3.ZERO,2)
 lure.variant="side_lantern"
 player.pos=Vector3(0,0,4)
 player.hurt_until=0
 Attacks.lock(game,lure,"lure",player.pos,now+6200)
 var hint: Dictionary=Attacks.hints(lure.attack,0,.6)[0]
 check(absf(float(hint.anchor[0]))>1,"lure shows a separate pull origin")
 game.resolve_scout(lure,game.Enemies.get_kind(12),now+6200)
 check(absf(player.pos.x)>.1 and player.slow_until>now+6200,"pull follows the visible offset anchor")

 var choir: Dictionary=game.make_scout(19,Vector3.ZERO,2)
 choir.variant="split_chorus"
 game.scouts.assign([choir,escort])
 player.pos=Vector3(0,0,2)
 player.hurt_until=0
 player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(10)
 Attacks.lock(game,choir,"shepherd",player.pos,now+7200)
 game.resolve_scout(choir,game.Enemies.get_kind(19),now+7200)
 check(PlayerVitals.current_hp(player)==9 and choir.attack.cue=="Second beat","the second choir sector is signalled separately")
 player.pos=Vector3(-2,0,0)
 player.hurt_until=0
 game.resolve_scout(choir,game.Enemies.get_kind(19),now+7930)
 check(PlayerVitals.current_hp(player)==9 and choir.windup==0,"a safe sector persists after both beats")

 var thief: Dictionary=game.make_scout(16,Vector3.ZERO,2)
 thief.variant="edge_thief"
 game.scouts.assign([thief])
 var trophy: Dictionary={"id":"owned:99","owner":99,"stack":{"item":game.Items.part_id(game.Parts.monster_part(0)),"quantity":1},"position":[1.6,0,0]}
 game.wild_item_drops.assign([trophy])
 check(game.EnemyBehaviors.tick(game,thief,.016,now+8500) and thief.mode=="trophy_grab" and thief.windup>0,"trophy can be picked up before the visible rush")
 game.wild_item_drops.clear()
 game.resolve_scout(thief,game.Enemies.get_kind(16),now+9500)
 check(thief.get("stolen",[]).is_empty(),"a trophy already picked up is never recreated")
 check(not game.combat_events.any(func(e):return e.kind=="audio" and e.shape=="trophy_taken"),"a failed grab never plays the theft alert")
 thief.ready=0
 game.wild_item_drops.assign([trophy])
 game.EnemyBehaviors.tick(game,thief,.016,now+10500)
 game.resolve_scout(thief,game.Enemies.get_kind(16),now+11500)
 Status.sync(game,now+11500)
 check(Status.snapshot(game,now+11500).any(func(event):return event.shape=="trophy_carrier"),"thief displays the stolen trophy state")
 game.EnemyBehaviors.death(game,thief,thief.pos)
 check(game.wild_item_drops.size()==1 and game.wild_item_drops[0].owner==99 and game.wild_item_drops[0].id==trophy.id,"one drop returns with the original owner and identity")

 game.queue_free()
 await process_frame
 if not failed:print("PASS: canopy, corpse lock, hatch interruption, flank commands, anchored pull, choir beats and owned trophy recovery")
 quit(1 if failed else 0)
