extends SceneTree
const WeaponCase = preload("res://tests/support/weapon_attack_case.gd")
const ClassActions = preload("res://native_class_actions.gd")
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const WeaponActions = preload("res://player_weapon_actions.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Cooldowns = preload("res://player_cooldowns.gd")

const Rules=preload("res://combat_ruleset.gd")
const Core=preload("res://core_combat.gd")
const Builds=preload("res://affinity_build.gd")
const Events=preload("res://combat_action_events.gd")
const Wood=preload("res://wood_affinity.gd")
const Thorn=preload("res://thorn_affinity.gd")
const Clock=preload("res://affinity_time.gd")
const Frost=preload("res://frost_combat.gd")
const Water=preload("res://water_combat.gd")
const Vital=preload("res://vital_combat.gd")
var game: Node
var failed:=false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failed=true
		printerr("FAIL Wood: ",label)

func event(id: int, slot: String, item: String, channels: Array = ["core_action"]) -> RefCounted:
	var material:=Builds.slot(slot,game.Items.get_item(item).legacy_part)
	return Events.begin(game,id,slot,material,material.potency_profile.values,channels,Time.get_ticks_msec()+30000)

func available(player: Dictionary) -> int:
	return Wood.capacity(Wood.live_grants(player,Clock.now(game)))

func hit(p: Dictionary, id: int, hp: int, now: int) -> void:
	p[Conditions.STATE] = p[Conditions.STATE].clear_grace()
	IncomingPlayerHit.resolve_world(game, id, PlayerLifecycle.generation(p), now, float(hp)/game.Life.Preview.scale(), 0, game.tactics.position)

func burst_count() -> int:
	return game.combat_events.filter(func(row):return row.shape=="wood_burst").size()

func reset() -> void:
	game.encounter.set_hp(-1, 500)
	game.tactics.position=Vector3(0,0,-1.0)
	game.enemy_mutations=0
	game.tactics.boss_kind=-1
	game.tactics.winding_up=false
	game.tactics.memory.clear()
	game.encounter.clear_scouts()
	game.weapon_attacks.clear()
	game.trait_events.clear()
	game.combat_events.clear()
	Core.reset(game)
	game.set_meta(Clock.CLOCK,0.0)
	for p in game.players.values():
		Wood.clear(p)
		preload("res://oracle_combat.gd").clear(p)
		Vital.clear(game,p)
		ExpeditionCase.set_membership(game, p, true)
		p[PlayerLifecycle.STATE] = p[PlayerLifecycle.STATE].clear_inactive()
		p.lost_health=0
		p.pos=Vector3.ZERO
		p[PlayerVitals.STATE] = PlayerVitals.Health.new(250.0,250)
		p.frame=0
		p.character=game.Character.blank()
		var tree=game.Classes.connected_tree(0)
		p.character[tree.profile_key]=tree.state(["rootkeeper"])
		p.weapon=0
		p.secondary=0
		p.catalyst=0
		p.facing=Vector3.FORWARD
		p.core_ready_at=0
		p.core_cast_until=0
		p.cast_until=0
		p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0)
		p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
		p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.R, 0)
		p[Conditions.STATE] = p[Conditions.STATE].clear_grace()
		p[Protection.STATE] = p[Protection.STATE].clear_expedition()
		p[Protection.STATE] = p[Protection.STATE].clear_guard()
		p[Protection.STATE] = p[Protection.STATE].clear_guard()

func run() -> void:
	game=preload("res://world.tscn").instantiate()

	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.battlefield.configure(0,1,0)
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
	for id in [2,3,4]: game.add_player(id)
	var p: Dictionary=game.players[1]
	var ally: Dictionary=game.players[2]
	for item in ["part_17","plant_part_rare_worldseed","plant_part_plant_ironroot","plant_part_rare_ironroot"]:
		var part: int=game.Items.get_item(item).legacy_part
		for slot in ["core","form","catalyst"]:
			var material:=Builds.slot(slot,part)
			check(material.executable and material.affinity_core_skill_id=="ironbark",item+" resolves to Wood")
	var now:=Time.get_ticks_msec()
	for item in ["plant_part_plant_ironroot","plant_part_rare_ironroot"]:
		reset()
		var part: int=game.Items.get_item(item).legacy_part
		var q: Dictionary=Builds.slot("core",part).potency_profile.values
		p.weapon=part
		game.garden_action(1,Core.request(game,p,Vector2.UP))
		var cast: Dictionary=game.get_meta(Core.STATE,{}).get(1,{})
		check(not cast.is_empty(),"real Core B starts Ironbark")
		if not cast.is_empty():
			Core.tick(game,cast.armed)
			check(available(p)==q.core_capacity and available(ally)==q.core_capacity and p[Protection.STATE].charge_count()==0 and p[PlayerVitals.STATE].hp()==250 and p[PlayerVitals.STATE].max_hp()==250,"Ironbark carries finite armor without Ward, heal or Vital bonus")
			ally.pos=Vector3(8,0,0)
			check(available(ally)==q.core_capacity,"recipient carries armor out of the area")
		reset()
		game.Life.Preview.strike_rng.seed=25
		var base:=strike(p)
		reset()
		p.secondary=part
		game.Life.Preview.strike_rng.seed=25
		var bonus:=strike(p)
		check(bonus-base==q.impact_hp and available(p)==0,"real Form contact adds its exact bonus against one enemy without granting bark")
		reset()
		p.secondary=part
		var ahead: Vector3=game.tactics.position+Vector3.FORWARD*1.75
		game.encounter.register_scout(game.make_scout(0,ahead,1))
		game.encounter.register_scout(game.make_scout(0,ahead+Vector3.RIGHT*.5,2))
		game.encounter.register_scout(game.make_scout(0,ahead-Vector3.RIGHT*.7,3))
		game.encounter.register_scout(game.make_scout(0,game.tactics.position+Vector3.RIGHT*1.6,4))
		for slot in game.encounter.scout_count(): game.encounter.set_hp(slot,100)
		strike(p)
		var struck: int=game.encounter.scout_views().filter(func(scout):return scout.hp<100).size()
		check(struck==2 and game.encounter.hp(3)==100 and game.encounter.scout_views().any(func(scout):return scout.hp==100-q.fragment_hp),"forward fan hits no more than two nearby additional targets and excludes side targets")
		check(game.combat_events.filter(func(row):return row.shape=="wood_splinters").size()==1,"one attack releases the fan once")
		reset()
		p.secondary=part
		game.encounter.register_scout(game.make_scout(0,Vector3(0,0,-2.4),1))
		game.encounter.set_hp(0, 100)
		preload("res://tests/support/terrain_case.gd").add_wall(game.battlefield,Rect2(-.36,-1.92,.72,.36))
		strike(p)
		check(game.encounter.hp(0)==100 and game.enemy_health()<500,"fragment fan respects cover behind the valid first contact")
		preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
		reset()
		p.catalyst=part
		ClassActions.cast_world(game, 1, 1)
		check(available(p)==q.catalyst_capacity and available(ally)==0,"native offensive class hit gives one self grant")
		reset()
		p.frame=4
		var oracle=game.Classes.connected_tree(4)
		p.character[oracle.profile_key]=oracle.state(["lifekeeper"])
		p.class_aim=Vector3.FORWARD
		p.class_aim_distance=0.0
		p.catalyst=part
		ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(50)
		ClassActions.cast_world(game, 1, 0)
		p.erase("class_aim")
		p.erase("class_aim_distance")
		check(available(ally)==q.catalyst_capacity and ally[PlayerVitals.STATE].hp()>50,"real Living Sanctuary retains opening healing and gives one Bark grant to each living recipient")
		game.Traits.tick(game,now+1500)
		check(available(ally)==q.catalyst_capacity,"native Sanctuary updates do not grant more Bark")

	test_absorption(p,now)
	await verify_pause(p)
	benchmark()
	game.queue_free()
	await process_frame
	if not failed:print("PASS: Wood mappings, real slots, armor ordering and attribution, cross-effects, pause and lifecycle")
	quit(int(failed))

func strike(p: Dictionary) -> int:
	var hp_before: int=game.enemy_health()
	WeaponCase.start(game,1,p.pos)
	var shot: Dictionary=game.weapon_attacks.views().front()
	WeaponCase.advance(game,int(shot.due)+1)
	return hp_before-int(game.enemy_health())

func mixture() -> void:
	Wood.grant(game,event(1,"core","part_17"),1,"core")
	Wood.grant(game,event(2,"catalyst","plant_part_rare_ironroot"),1,"support")

func test_absorption(p: Dictionary, now: int) -> void:
	reset()
	mixture()
	var extra:=event(3,"core","part_17")
	check(Wood.grant(game,extra,1,"core")==0 and available(p)==48,"full recipient rejects grant")
	p[Protection.STATE] = p[Protection.STATE].grant(now+15000,1,Time.get_ticks_msec(),game.participation.epoch())
	hit(p,1,50,now)
	check(p[PlayerVitals.STATE].hp()==250 and available(p)==48,"native Ward prevents the hit before Bark")
	p[Protection.STATE] = p[Protection.STATE].clear_guard()
	hit(p,1,50,now)
	check(p[PlayerVitals.STATE].hp()==220 and available(p)==28 and p[Wood.GRANTS].size()==1 and p[Wood.GRANTS][0].actor==1 and burst_count()==0,
		"40% absorption spends earliest expiry first and a single exhausted grant does not burst")
	check(Wood.grant(game,extra,1,"core")==0,"a rejected grant cannot replay after capacity becomes available")
	var topup:=event(4,"core","plant_part_rare_worldseed")
	check(Wood.grant(game,topup,1,"core")==20 and p[Wood.GRANTS].back().admitted==20,"only available capacity is admitted")
	check(Wood.grant(game,topup,1,"core")==0,"admitted grant identity cannot duplicate")

	reset()
	mixture()
	var plan:=Wood.absorption_plan(p,120,Clock.now(game))
	check(plan.damage==12 and plan.owner==1 and plan.shares[0].actor==2 and plan.shares[0].hp==18 and plan.shares[1].hp==30,
		"breaking hit uses weighted damage and largest-share owner")
	hit(p,1,120,now)
	check(p[PlayerVitals.STATE].hp()==178 and available(p)==0 and game.enemy_health()==488 and burst_count()==1,"overflow reaches HP and the breaking hit lands one burst")
	IncomingPlayerHit.resolve_world(game, 1, PlayerLifecycle.generation(p), now, 12.0, 0, game.tactics.position)
	check(p[PlayerVitals.STATE].hp()==178 and burst_count()==1,"duplicate protected damage event does not debit or burst again")
	Wood.grant(game,event(2,"catalyst","part_17"),1,"support")
	hit(p,1,30,now)
	check(available(p)==0 and p[PlayerVitals.STATE].hp()==160 and burst_count()==1,"rapid replacement depletes without a new burst")
	Clock.advance(game,1.35)
	Wood.grant(game,event(2,"catalyst","part_17"),1,"support")
	hit(p,1,30,now)
	check(burst_count()==2,"a later breaking hit may respond after the interval")

	reset()
	Wood.grant(game,event(1,"catalyst","part_17"),1,"support")
	Wood.grant(game,event(2,"catalyst","plant_part_rare_ironroot"),1,"support")
	var tie:=Wood.absorption_plan(p,50,0)
	check(tie.shares[0].actor==1 and tie.shares[0].hp==12 and tie.shares[1].hp==8,"expiry ties spend stable host grant order")
	reset()
	Wood.grant(game,event(2,"catalyst","part_17"),1,"support")
	Wood.grant(game,event(1,"catalyst","part_17"),1,"support")
	var equal_share:=Wood.absorption_plan(p,60,Clock.now(game))
	check(equal_share.owner==2 and equal_share.damage==10,"equal absorbed shares award the earliest host grant damage credit")
	reset()
	mixture()
	Wood.tick(game,Clock.advance(game,4.3))
	check(available(p)==30 and p[PlayerVitals.STATE].hp()==250 and burst_count()==0,"earlier grant expires independently with no damage or burst")
	Wood.tick(game,Clock.advance(game,1.8))
	check(not p.has(Wood.GRANTS) and p[PlayerVitals.STATE].hp()==250 and burst_count()==0,"full expiry never acts as a break")
	mixture()
	var drench:=event(2,"form","plant_part_rare_dewcap",["weapon_contact"])
	Water.drench(game,drench,-1)
	Frost.with_attacker(game,-1,hit.bind(p,1,50,now))
	check(p[PlayerVitals.STATE].hp()==229 and available(p)==34,"Drenched reduces the hostile hit before Bark absorption")
	var paid: int=available(p)
	IncomingPlayerHit.apply_health_loss(game, 1, PlayerLifecycle.generation(p), 10)
	check(available(p)==paid and p[PlayerVitals.STATE].hp()==219,"native direct cost path does not consume Bark")
	var vital:=event(2,"core","part_2")
	vital.publish(game,"core_action","bloom","",now,{"center":p.pos,"recipients":[1]})
	check(available(p)==paid and p[PlayerVitals.STATE].temporary_hp()==12,"temporary max HP and Bark capacity are separate")

	reset()
	var guard: Dictionary={"id":"fixture","trigger":"block","limit":"recipient"}
	var frost:=event(2,"catalyst","plant_part_rare_frostbell",["actual_block"])
	var wood:=event(3,"catalyst","plant_part_rare_ironroot",["actual_block"])
	Events.grant_ward(game,p,now+10000,1,frost,guard,now)
	Events.grant_ward(game,p,now+12000,2,wood,guard,now)
	hit(p,1,40,now)
	check(available(p)==0 and Frost.state(game.tactics.memory,now).get("stacks",[]).size()==1,"earliest mixed Ward uses its Frost source")
	hit(p,1,40,now)
	check(available(p)==18 and p[PlayerVitals.STATE].hp()==250 and burst_count()==1 and game.enemy_health()==488,"next Ward gives granting Wood quality and radial damage")
	hit(p,1,50,now)
	check(available(p)==0 and burst_count()==1 and p[PlayerVitals.STATE].hp()==218,"Wood Ward and Bark break share one recipient interval")
	Wood.grant(game,wood,1,"fixture-new-grant")
	game.reset_encounter()
	check(available(p)==0 and not p.has(Wood.BURST_READY),"floor turnover clears armor and interval")

func verify_pause(p: Dictionary) -> void:
	reset()
	mixture()
	paused=true
	game.set_physics_process(true)
	await create_timer(.15,true).timeout
	game.set_physics_process(false)
	paused=false
	check(Clock.now(game)==0 and available(p)==48,"paused gameplay preserves armor lifetime")
	game.Life.down(game,1,p)
	check(available(p)==0 and p[PlayerVitals.STATE].hp()==0 and burst_count()==0,"death cleans up protection without a burst")

func benchmark() -> void:
	reset()
	var now:=Time.get_ticks_msec()
	for index in 12:
		var scout: Dictionary=game.make_scout(0,Vector3(.1*(index%6),0,-1.0-.1*index),index)
		scout.hp=20000
		game.encounter.register_scout(scout)
	for id in [1,2,3,4]:
		var thorn:=event(id,"form","part_1",["weapon_contact"])
		thorn.publish(game,"weapon_contact","sample","leader",now,{"point":game.tactics.position,"enemy":-1})
		Wood.grant(game,event(id,"core","part_17"),id,"core")
	var started:=Time.get_ticks_usec()
	for index in 150:
		var elapsed:=Clock.advance(game,1.0/60)
		Thorn.tick(game,elapsed,now)
		Wood.tick(game,elapsed)
		Wood.absorption_plan(game.players[1+index%4],40,elapsed)
	print("CR04B effect sample four players, 12 scouts, four Thorn fields, one Bark hit plan per step: ",float(Time.get_ticks_usec()-started)/150.0," us/step")
