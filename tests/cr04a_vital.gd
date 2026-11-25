extends SceneTree
const Effects = preload("res://enemy_affinity_effects.gd")
const WeaponEventCase = preload("res://tests/support/weapon_event_case.gd")
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

const Rules = preload("res://combat_ruleset.gd")
const Vital = preload("res://vital_combat.gd")
const Water = preload("res://water_combat.gd")
const Fire = preload("res://fire_combat.gd")
const Clock = preload("res://affinity_time.gd")
const Events = preload("res://combat_action_events.gd")
const Builds = preload("res://affinity_build.gd")
const Core = preload("res://core_combat.gd")
const Aim = preload("res://ability_aim.gd")
var failed := false
var game: Node


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL Vital: ",label)


func event(id: int, slot: String, item: String, channel: String, now: int) -> RefCounted:
	var affinity := Builds.slot(slot,game.Items.get_item(item).legacy_part)
	return Events.begin(game,id,slot,affinity,affinity.potency_profile.values,[channel],now+15000)


func reset(p: Dictionary, ally: Dictionary) -> void:
	game.encounter.set_hp(-1, 500)
	game.enemy_mutations=0
	game.tactics.boss_kind=-1
	game.tactics.position=Vector3(0,0,-1.25)
	game.tactics.winding_up=false
	game.tactics.memory.clear()
	game.encounter.clear_scouts()
	game.weapon_attacks.clear()
	Core.reset(game)
	game.set_meta(Clock.CLOCK,0.0)
	for player in [p,ally]:
		Vital.clear(game,player)
		preload("res://oracle_combat.gd").clear(player)
		player[Protection.STATE] = player[Protection.STATE].clear_guard()
		ExpeditionCase.set_membership(game, player, true)
		player[PlayerLifecycle.STATE] = player[PlayerLifecycle.STATE].clear_inactive()
		player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(60)
		player.lost_health=0
		player.pos=Vector3.ZERO
		player.frame=0
		player.character=game.Character.blank()
		var tree=game.Classes.connected_tree(0)
		player.character[tree.profile_key]=tree.state(["rootkeeper"])
		player.weapon=0
		player.secondary=0
		player.catalyst=0
		player[Protection.STATE] = player[Protection.STATE].clear_expedition()
		player[WeaponActions.STATE] = player[WeaponActions.STATE].with_ready_at(0)
		player.cast_until=0
		player.core_cast_until=0
		player.core_ready_at=0
		player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
		player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.R, 0)
		player[Conditions.STATE] = player[Conditions.STATE].clear_grace()
		player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_native_max_hp(game.Life.native_maximum(game,player))


func source_until(player: Dictionary, actor: int, slot: String, fallback: int = 0) -> int:
	for source: Dictionary in player.get(Vital.SOURCES,{}).values():
		if int(source.actor)==actor and source.slot==slot: return int(source.until)
	return fallback


func run() -> void:
	game=preload("res://world.tscn").instantiate()

	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.battlefield.configure(0,1,0)
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
	game.add_player(2)
	game.add_player(3)
	var player: Dictionary=game.players[1]
	var ally: Dictionary=game.players[2]
	var fallen: Dictionary=game.players[3]
	ExpeditionCase.set_membership(game, fallen, true)
	fallen[PlayerLifecycle.STATE] = fallen[PlayerLifecycle.STATE].fall()
	fallen[PlayerVitals.STATE] = fallen[PlayerVitals.STATE].with_hp(0)
	for pair in [["part_2","plant_part_rare_lantern_moss"],["part_9","plant_part_rare_bloodbriar"],["plant_part_plant_gravemoss","plant_part_rare_gravemoss"]]:
		for item in pair:
			for slot in ["core","form","catalyst"]:
				var material:=Builds.slot(slot,game.Items.get_item(item).legacy_part)
				check(material.executable and material.affinity_core_skill_id=="vital_bloom",item+" maps to Vital Bloom for "+slot)
	for item in ["part_2","plant_part_rare_lantern_moss"]:
		var part: int=game.Items.get_item(item).legacy_part
		var q: Dictionary=Builds.slot("core",part).potency_profile.values
		var now:=Time.get_ticks_msec()
		reset(player,ally)
		var native: int=player[PlayerVitals.STATE].max_hp()
		player.weapon=part
		game.encounter.set_hp(-1, 0)
		ally.pos=Vector3(1,0,0)
		var pressed := InputEventKey.new()
		pressed.physical_keycode=KEY_B
		pressed.pressed=true
		game._unhandled_key_input(pressed)
		var controller = Aim.active(game)
		check(controller != null and controller.slot == 2 and controller.drawing.get_surface_count() == 1,"pressing B after clear shows Vital Bloom preview")
		pressed.pressed=false
		game._input(pressed)
		check(not Aim.available(game,player,0),"class actions still stop after clear")
		var cast: Dictionary=game.effect_timeline.core_records().get(1,{})
		check(not cast.is_empty(),"real Core can grant recovery between encounters")
		if not cast.is_empty():
			var before_grant:int=game.combat_event_serial
			Core.tick(game,cast.armed)
			check(not game.combat_events.any(func(e):return e.id>before_grant and e.shape=="heal"),"a capacity grant never displays healing")
			check(player[PlayerVitals.STATE].max_hp()==native+q.bonus_hp and player[PlayerVitals.STATE].hp()==60 and ally[PlayerVitals.STATE].max_hp()==int(game.Life.native_maximum(game,ally))+q.bonus_hp,
				"capacity goes to living allies without instant heal")
			check(fallen[PlayerVitals.STATE].hp()==0 and not fallen.has(Vital.SOURCES),"Bloom never revives a fallen ally")
			ally.pos=Vector3(8,0,0)
			Vital.tick(game,Clock.advance(game,1.0))
			check(player[PlayerVitals.STATE].hp()==60+q.regen_per_second and ally[PlayerVitals.STATE].hp()==60+q.regen_per_second,"recipient carries regeneration beyond the original area")
			for recipient in [1,2]:
				check(game.combat_events.filter(func(e):return e.id>before_grant and e.shape=="heal" and e.get("form","")=="vital_heal" and e.combo==recipient and e.amount==q.regen_per_second).size()==1,"one applied regeneration receipt per healed character")
			check(not game.effect_timeline.core_records().has(1),"native cast released once")
		reset(player,ally)
		player.secondary=part
		player.facing=Vector3.FORWARD
		var replay_context := WeaponEventCase.start(game,1,player.pos)
		var shot: Dictionary=game.weapon_attacks.views().front()
		WeaponCase.advance(game,int(shot.due)+1)
		check(player[PlayerVitals.STATE].temporary_hp()==q.bonus_hp and player[PlayerVitals.STATE].hp()==60 and not ally.has(Vital.SOURCES),
			"real weapon contact grants self capacity without a lifesteal heal")
		game.encounter.register_scout(game.make_scout(0,Vector3(1,0,-1.25),0))
		var applied_until: int=source_until(player,1,"form",0)
		Clock.advance(game,.4)
		Events.contact(game,replay_context,0,now)
		Events.contact(game,replay_context,-1,now)
		Events.contact(game,replay_context,0,now,true)
		check(source_until(player,1,"form",-1)==applied_until,"multi-target, duplicate and secondary contacts don't refresh the same attack")
		reset(player,ally)
		player.catalyst=part
		ClassActions.cast_world(game, 1, 1)
		check(player[PlayerVitals.STATE].temporary_hp()==q.bonus_hp,"native offensive class hit grants self Vitality")
		reset(player,ally)
		player.catalyst=part
		player.frame=4
		var oracle=game.Classes.connected_tree(4)
		player.character[oracle.profile_key]=oracle.state(["lifekeeper"])
		player.class_aim=Vector3.FORWARD
		player.class_aim_distance=0.0
		ClassActions.cast_world(game, 1, 0)
		player.erase("class_aim")
		player.erase("class_aim_distance")
		check(ally[PlayerVitals.STATE].temporary_hp()==q.bonus_hp and ally[PlayerVitals.STATE].hp()>60,"native Oracle heal remains intact and grants recipient Vitality")
		var duration: int=source_until(ally,1,"catalyst",0)
		game.effect_timeline.advance_native(game.native_effects_world,now+1500)
		check(source_until(ally,1,"catalyst",-1)==duration,"native Sanctuary updates do not grant fresh Vitality")

	reset(player,ally)
	player.frame=1
	var weaver=game.Classes.connected_tree(1)
	player.character[weaver.profile_key]=weaver.state(["bloomcaller"])
	player.class_aim=Vector3.FORWARD
	player.class_aim_distance=0.0
	player.catalyst=int(game.Items.get_item("part_2").legacy_part)
	game.tactics.position=Vector3(9,0,0)
	ClassActions.cast_world(game, 1, 0)
	check(not player.has(Vital.SOURCES),"empty Cultivate Bloom creates no Vitality on placement")
	var pulse_at:=Time.get_ticks_msec()+1
	game.tactics.position=Vector3(0,0,-1)
	game.effect_timeline.advance_native(game.native_effects_world,pulse_at)
	check(player[PlayerVitals.STATE].temporary_hp()==12,"first actual Cultivate Bloom pulse grants Vitality")
	Clock.advance(game,.4)
	game.effect_timeline.advance_native(game.native_effects_world,pulse_at+1000)
	check(source_until(player,1,"catalyst",0)==Vital.DURATIONS.catalyst,"periodic hits cannot re-grant the class response")
	player.erase("class_aim")
	player.erase("class_aim_distance")
	game.effect_timeline.clear_native()

	reset(player,ally)
	var now:=Time.get_ticks_msec()
	var strong := event(1,"form","plant_part_rare_lantern_moss","weapon_contact",now)
	strong.publish(game,"weapon_contact","hit","leader",now,{"enemy":-1})
	var weak := event(2,"core","part_2","core_action",now)
	Clock.advance(game,.4)
	weak.publish(game,"core_action","bloom","",now,{"center":ally.pos,"recipients":[1]})
	Clock.advance(game,.4)
	var refresh := event(1,"form","plant_part_rare_lantern_moss","weapon_contact",now)
	refresh.publish(game,"weapon_contact","hit","leader",now,{"enemy":-1})
	check(player[PlayerVitals.STATE].hp()==60 and player.get(Vital.NEXT)==1000,"overlap and repeated hits do not add or postpone healing")
	Vital.tick(game,Clock.advance(game,.2))
	check(player[PlayerVitals.STATE].hp()==65 and player[PlayerVitals.STATE].temporary_hp()==18,"strongest active rate heals on original tick")
	IncomingPlayerHit.apply_health_loss(game, 1, PlayerLifecycle.generation(player), 4)
	Vital.tick(game,Clock.advance(game,1.0))
	check(player[PlayerVitals.STATE].hp()==66,"damage does not cancel regen")
	player.lost_health=10
	var base: int=game.Life.native_maximum(game,player)
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_native_max_hp(base)
	check(player[PlayerVitals.STATE].max_hp()==base+18,"native capacity change preserves temporary contribution")
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].refilled()
	Vital.tick(game,Clock.advance(game,2.0))
	check(player[PlayerVitals.STATE].max_hp()==base+12 and player[PlayerVitals.STATE].hp()==base+12,"short refined capacity expires and clamps to surviving ordinary cap")
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(55)
	Vital.tick(game,Clock.advance(game,2.0))
	check(player[PlayerVitals.STATE].max_hp()==base and player[PlayerVitals.STATE].hp()>=55 and not player.has(Vital.SOURCES),"capacity expiry retains health below native cap")
	var protected_hp: float=player[PlayerVitals.STATE].hp()
	var ward := Events.class_start(game,2,{"trigger":"block"},now,Builds.slot("catalyst",game.Items.get_item("plant_part_rare_gravemoss").legacy_part))
	var adapter := {"trigger":"block", "limit":"recipient", "id":"vital_fixture"}
	Events.grant_ward(game,player,now+29000,1,ward,adapter,now)
	IncomingPlayerHit.resolve_world(game, 1, PlayerLifecycle.generation(player), now+1, 1.0, 0, game.tactics.position)
	check(player[PlayerVitals.STATE].hp()==protected_hp and player[PlayerVitals.STATE].temporary_hp()==18 and ally[PlayerVitals.STATE].temporary_hp()==18,
		"refined ally Ward grants radial Vitality using the granting Catalyst")
	game.Life.down(game,2,ally)
	check(not ally.has(Vital.SOURCES) and ally[PlayerVitals.STATE].hp()==0,"fall clears Vitality without revival")
	game.reset_encounter()
	check(not player.has(Vital.SOURCES) and player[PlayerVitals.STATE].temporary_hp()==0,"floor turnover clears temporary state and capacity")
	await verify_pause(player,ally)
	benchmark(player,ally)
	game.queue_free()
	await process_frame
	if not failed: print("PASS: Vital capacity, regen, native damage, class/weapon/Core delivery, pause and floor lifecycle")
	quit(int(failed))


func verify_pause(player: Dictionary, ally: Dictionary) -> void:
	reset(player,ally)
	var now:=Time.get_ticks_msec()
	var grant := event(1,"core","part_2","core_action",now)
	grant.publish(game,"core_action","bloom","",now,{"center":player.pos,"recipients":[1]})
	paused=true
	game.set_physics_process(true)
	await create_timer(.15,true).timeout
	game.set_physics_process(false)
	paused=false
	check(Clock.now(game)==0 and player[PlayerVitals.STATE].hp()==60 and player[PlayerVitals.STATE].temporary_hp()==12,"paused engine frames don't spend combat-time or grant ticks")


func benchmark(player: Dictionary, ally: Dictionary) -> void:
	reset(player,ally)
	game.add_player(4)
	for id in [3,4]:
		ExpeditionCase.set_membership(game, game.players[id], true)
		game.players[id][PlayerLifecycle.STATE] = game.players[id][PlayerLifecycle.STATE].clear_inactive()
		game.players[id][PlayerVitals.STATE] = game.players[id][PlayerVitals.STATE].with_hp(70)
	var now:=Time.get_ticks_msec()
	var burns: Array = []
	var waters: Array = []
	for id in range(1,5):
		burns.append(event(id,"form","part_6","weapon_contact",now))
		waters.append(event(id,"form","part_8","weapon_contact",now))
		var grant := event(id,"core","part_2","core_action",now)
		grant.publish(game,"core_action","bloom","",now,{"center":Vector3.ZERO,"recipients":[1,2,3,4]})
	for index in 12:
		var scout: Dictionary=game.make_scout(0,Vector3(0,0,-2),index)
		scout.hp=10000
		game.encounter.register_scout(scout)
		for source in burns:
			Fire.ignite(game,source,index,now)
		for source in waters:
			Water.drench(game,source,index)
	var count:=150
	var started:=Time.get_ticks_usec()
	for frame in count:
		var elapsed:=Clock.advance(game,1.0/60.0)
		Fire.tick(game,elapsed,now)
		Vital.tick(game,elapsed)
		for scout in game.encounter.scout_tactics(): Water.reduction(Effects.from_body(scout).get(Water.DRENCHED,{}),elapsed)
	print("CR04A effect update (four players, 12 enemies, four sources per effect, 150 steps): ",float(Time.get_ticks_usec()-started)/count," us/step")
