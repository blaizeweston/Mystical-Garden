extends SceneTree
const Conditions = preload("res://player_hit_conditions.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")
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

	game.progress.path="user://cr04c-spirit/garden.cfg"
	game.local_character.path="user://cr04c-spirit/player.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var p: Dictionary=game.players[1]
	ExpeditionCase.set_membership(game, p, true)
	SessionCase.set_ready(game, p, true)
	p.pos=Vector3.ZERO
	p.weapon=game.Items.get_item("part_10").legacy_part
	game.encounter.set_hp(-1, 100)
	game.tactics.position=Vector3(-1.5,0,0)
	game.tactics.engaged=true
	game.tactics.memory.target=1
	game.encounter.clear_scouts()
	var waiting: Dictionary=game.make_scout(0,Vector3(-1.1,0,0),1)
	waiting.engaged=true;waiting.target=1;waiting.windup=Time.get_ticks_msec()+1500
	game.encounter.register_scout(waiting)
	var ordinary: int=p.weapon
	var refined: int=game.Items.get_item("plant_part_rare_ghost_fern").legacy_part
	Core.command(game,1,p,Core.request(game,p,Vector2.RIGHT))
	check(Vector3(p.pos).x>1.9 and is_equal_approx(Spirit.scale(p,0),1.2),"melee Core moves in chosen direction and grants speed")
	check(Spirit.diversion(game,game.tactics.memory,1)==Vector3.ZERO and not waiting.has(Spirit.TRACE),"real pursuer diverted around represented player; committed scout unaffected")
	var resist: int=game.tactics.memory[Spirit.RESIST]
	Clock.advance(game,.81)
	check(not Spirit.diversion(game,game.tactics.memory,1).is_finite(),"normal pursuit returns on expiry")
	var tr:=action(game,"catalyst",refined,["actual_block"])
	tr.publish(game,"actual_block","block","1",Time.get_ticks_msec(),{"recipient":1,"center":Vector3.ZERO})
	check(not game.tactics.memory.has(Spirit.TRACE) and game.tactics.memory[Spirit.RESIST]==resist,"enemy resists repeated diversion")
	check(is_equal_approx(Spirit.scale(p,Clock.now(game)),1.29),"strongest source controls stride")
	p.frame=2;p.weapon_kind=0;p.weapon=refined;p.core_ready_at=0;p.cast_until=0;p.core_cast_until=0
	p.pos=Vector3.ZERO
	Core.command(game,1,p,Core.request(game,p,Vector2.RIGHT))
	check(is_equal_approx(Vector3(p.pos).x,Spirit.STEP_DISTANCE) and is_equal_approx(Spirit.scale(p,Clock.now(game)),1.29),"refined Bow Core keeps travel distance and uses higher speed")
	p.core_ready_at=0;p.cast_until=0;p.core_cast_until=0
	p.pos=Vector3.ZERO;game.tactics.position=Vector3(.42,0,0)
	Core.command(game,1,p,Core.request(game,p,Vector2.RIGHT))
	check(p.pos==Vector3.ZERO and p.core_ready_at==0,"actor obstruction refuses before cooldown")
	game.tactics.position=Vector3(-1,0,0)
	var now:=Time.get_ticks_msec()
	var f:=action(game,"form",ordinary,["weapon_contact"])
	var old:=action(game,"native_weapon",ordinary,["weapon_contact"])
	var old_stats: Dictionary={Events.CONTEXT:old}
	Spirit.launch(game,p,old_stats,1)
	Events.contact(game,{Events.CONTEXT:f},-1,now,false,game.tactics.position)
	p.pos=Vector3(8,0,0) # Enemy-driven displacement carries no voluntary hook.
	Spirit.movement(game,p,Vector3(8,0,0),Vector3(8.25,0,0))
	check(p[Spirit.FOLLOW].phase=="prepared","forced movement cannot qualify follow-up")
	Spirit.movement(game,p,Vector3(8.25,0,0),Vector3(9,0,0))
	check(p[Spirit.FOLLOW].phase=="ready","qualifying voluntary movement readies follow-up")
	Events.contact(game,old_stats,-1,now,false,game.tactics.position)
	check(game.enemy_health()==100 and p[Spirit.FOLLOW].phase=="ready","older in-flight attack cannot receive a bonus")
	var volley:=action(game,"native_weapon",ordinary,["weapon_contact"])
	var competing:=action(game,"native_weapon",ordinary,["weapon_contact"])
	var stats: Dictionary={Events.CONTEXT:volley}
	var other: Dictionary={Events.CONTEXT:competing}
	var until: int=p[Spirit.FOLLOW].until
	Spirit.launch(game,p,stats,3)
	Spirit.launch(game,p,other,1)
	Spirit.finish(game,p,stats)
	Events.contact(game,other,-1,now,false,game.tactics.position)
	Spirit.finish(game,p,stats)
	check(game.enemy_health()==100 and p[Spirit.FOLLOW].phase=="claimed","several in-flight attacks cannot steal claim; partial volley miss is inconclusive")
	Spirit.finish(game,p,stats)
	check(p[Spirit.FOLLOW].phase=="ready" and p[Spirit.FOLLOW].until==until,"full miss reopens the same original opportunity")
	var next:=action(game,"native_weapon",ordinary,["weapon_contact"])
	var next_stats: Dictionary={Events.CONTEXT:next}
	Spirit.launch(game,p,next_stats,1)
	Events.contact(game,next_stats,-1,now,false,game.tactics.position)
	Events.contact(game,next_stats,-1,now,false,game.tactics.position)
	check(game.enemy_health()==87 and not p.has(Spirit.FOLLOW),"next contact spends one follow-up")
	Clock.advance(game,2.0)
	var sharp:=action(game,"form",refined,["weapon_contact"])
	Events.contact(game,{Events.CONTEXT:sharp},-1,now,false,game.tactics.position)
	Spirit.movement(game,p,p.pos,Vector3(p.pos)+Vector3.RIGHT)
	var attack:=action(game,"native_weapon",refined,["weapon_contact"])
	var bonus: Dictionary={Events.CONTEXT:attack}
	Spirit.launch(game,p,bonus,1)
	Events.contact(game,bonus,-1,now,false,game.tactics.position)
	check(game.enemy_health()==69,"refined Form grants a stronger follow-up")
	Spirit.clear(p)
	var common:=action(game,"catalyst",ordinary,["class_action"])
	common.publish(game,"class_action","heal","",now,{"response":"recipient_stride","recipients":[1]})
	check(is_equal_approx(Spirit.scale(p,Clock.now(game)),1.2),"ordinary healing grants its own speed")
	p.pos=Vector3.ZERO
	p[Conditions.STATE] = p[Conditions.STATE].with_slow_until(Time.get_ticks_msec()+2000)
	game.move_player(1,Vector2.RIGHT,.1)
	check(is_equal_approx(Vector3(p.velocity).length(),game.WALK_SPEED*.60*1.20),"Spiritstride stacks multiplicatively with native Slow without cleansing it")
	Clock.advance(game,5.0);Spirit.tick(game,Clock.now(game))
	check(is_equal_approx(Spirit.scale(p,Clock.now(game)),1.0),"independent expiration returns native movement")
	game.add_player(2)
	var ally: Dictionary=game.players[2]
	ExpeditionCase.set_membership(game, ally, true);ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(100);ally.pos=Vector3.ZERO
	game.tactics.position=Vector3(-1,0,0)
	game.tactics.memory.target=2
	var ward:=action(game,"catalyst",refined,["actual_block"])
	ward.publish(game,"actual_block","ally","2",Time.get_ticks_msec(),{"recipient":2,"center":ally.pos})
	check(game.tactics.memory.get(Spirit.TRACE,{}).get("represented")==2
		and game.tactics.memory.get(Spirit.TRACE,{}).get("actor")==1
		and is_equal_approx(Spirit.scale(ally,Clock.now(game)),1.29),"Spirit Ward owns source potency and represents the protected ally")
	game.queue_free()
	await process_frame
	if not failed: print("PASS: directional step, blocked refusal, live pursuit trace, stride sources and projectile ownership")
	quit(int(failed))
