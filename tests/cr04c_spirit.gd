extends SceneTree

const Spirit=preload("res://spirit_affinity.gd")
const Events=preload("res://combat_action_events.gd")
const Builds=preload("res://affinity_build.gd")
const Mode=preload("res://combat_ruleset.gd")
const Core=preload("res://core_combat.gd")
const Clock=preload("res://affinity_time.gd")
var failed:=false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok: failed=true; printerr("FAIL Spirit: ",label)

func action(game: Node, slot: String, part: int, channels: Array, id:=1) -> RefCounted:
	var material := Builds.slot(slot,part)
	return Events.begin(game,id,slot,material,material.potency_profile.values,channels,Time.get_ticks_msec()+10000)

func run() -> void:
	var game:=preload("res://world.tscn").instantiate()
	game.set_meta(Mode.META,Mode.ID)
	game.progress.path="user://cr04c-spirit/garden.cfg"
	game.local_character.path="user://cr04c-spirit/player.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var p: Dictionary=game.players[1]
	p.wild=true
	p.profile_ready=true
	p.pos=Vector3.ZERO
	p.weapon=game.Items.get_item("part_10").legacy_part
	game.enemy_hp=100
	game.enemy_pos=Vector3(-1.5,0,0)
	game.enemy_engaged=true
	game.leader_brain.target=1
	game.scouts.clear()
	var waiting: Dictionary=game.make_scout(0,Vector3(-1.1,0,0),1)
	waiting.engaged=true;waiting.target=1;waiting.windup=Time.get_ticks_msec()+1500
	game.scouts.append(waiting)
	var ordinary: int=p.weapon
	var refined: int=game.Items.get_item("plant_part_rare_ghost_fern").legacy_part
	Core.command(game,1,p,Core.request(game,p,Vector2.RIGHT))
	check(Vector3(p.pos).x>1.9 and is_equal_approx(Spirit.scale(p,0),1.2),"melee Core moves in chosen direction and grants speed")
	check(Spirit.diversion(game,game.leader_brain,1)==Vector3.ZERO and not waiting.has(Spirit.TRACE),"real pursuer diverted around represented player; committed scout unaffected")
	var resist: int=game.leader_brain[Spirit.RESIST]
	Clock.advance(game,.81)
	check(not Spirit.diversion(game,game.leader_brain,1).is_finite(),"normal pursuit returns on expiry")
	var tr:=action(game,"catalyst",refined,["actual_block"])
	tr.publish(game,"actual_block","block","1",Time.get_ticks_msec(),{"recipient":1,"center":Vector3.ZERO})
	check(not game.leader_brain.has(Spirit.TRACE) and game.leader_brain[Spirit.RESIST]==resist,"enemy resists repeated diversion")
	check(is_equal_approx(Spirit.scale(p,Clock.now(game)),1.29),"strongest source controls stride")
	p.frame=2;p.weapon_kind=0;p.core_ready_at=0;p.cast_until=0;p.core_cast_until=0
	p.pos=Vector3.ZERO
	Core.command(game,1,p,Core.request(game,p,Vector2.RIGHT))
	check(Vector3(p.pos).x>1.9,"Bow Core uses the same chosen direction and range")
	p.core_ready_at=0;p.cast_until=0;p.core_cast_until=0
	p.pos=Vector3.ZERO;game.enemy_pos=Vector3(.42,0,0)
	Core.command(game,1,p,Core.request(game,p,Vector2.RIGHT))
	check(p.pos==Vector3.ZERO and p.core_ready_at==0,"actor obstruction refuses before cooldown")
	game.enemy_pos=Vector3(-1,0,0)
	var now:=Time.get_ticks_msec()
	var f:=action(game,"form",ordinary,["weapon_contact"])
	var old:=action(game,"native_weapon",ordinary,["weapon_contact"])
	var old_stats: Dictionary={Events.CONTEXT:old}
	Spirit.launch(game,p,old_stats,1)
	Events.contact(game,{Events.CONTEXT:f},-1,now,false,game.enemy_pos)
	p.pos=Vector3(8,0,0) # Enemy-driven displacement carries no voluntary hook.
	Spirit.movement(game,p,Vector3(8,0,0),Vector3(8.25,0,0))
	check(p[Spirit.FOLLOW].phase=="prepared","forced movement cannot qualify follow-up")
	Spirit.movement(game,p,Vector3(8.25,0,0),Vector3(9,0,0))
	check(p[Spirit.FOLLOW].phase=="ready","qualifying voluntary movement readies follow-up")
	Events.contact(game,old_stats,-1,now,false,game.enemy_pos)
	check(game.enemy_hp==100 and p[Spirit.FOLLOW].phase=="ready","older in-flight attack cannot receive a bonus")
	var volley:=action(game,"native_weapon",ordinary,["weapon_contact"])
	var competing:=action(game,"native_weapon",ordinary,["weapon_contact"])
	var stats: Dictionary={Events.CONTEXT:volley}
	var other: Dictionary={Events.CONTEXT:competing}
	var until: int=p[Spirit.FOLLOW].until
	Spirit.launch(game,p,stats,3)
	Spirit.launch(game,p,other,1)
	Spirit.finish(game,p,stats)
	Events.contact(game,other,-1,now,false,game.enemy_pos)
	Spirit.finish(game,p,stats)
	check(game.enemy_hp==100 and p[Spirit.FOLLOW].phase=="claimed","several in-flight attacks cannot steal claim; partial volley miss is inconclusive")
	Spirit.finish(game,p,stats)
	check(p[Spirit.FOLLOW].phase=="ready" and p[Spirit.FOLLOW].until==until,"full miss reopens the same original opportunity")
	var next:=action(game,"native_weapon",ordinary,["weapon_contact"])
	var next_stats: Dictionary={Events.CONTEXT:next}
	Spirit.launch(game,p,next_stats,1)
	Events.contact(game,next_stats,-1,now,false,game.enemy_pos)
	Events.contact(game,next_stats,-1,now,false,game.enemy_pos)
	check(game.enemy_hp==87 and not p.has(Spirit.FOLLOW),"next contact spends one follow-up")
	Clock.advance(game,5.0);Spirit.tick(game,Clock.now(game))
	check(is_equal_approx(Spirit.scale(p,Clock.now(game)),1.0),"independent expiration returns native movement")
	game.queue_free()
	await process_frame
	if not failed: print("PASS: directional step, blocked refusal, live pursuit trace, stride sources and projectile ownership")
	quit(int(failed))
