extends SceneTree
## Shared-status contracts use actual family handlers, event admission and HP.
const Events = preload("res://combat_action_events.gd")
const Build = preload("res://affinity_build.gd")
const Thorn = preload("res://thorn_affinity.gd")
const Frost = preload("res://frost_combat.gd")
const Fire = preload("res://fire_combat.gd")
const Water = preload("res://water_combat.gd")
const Vital = preload("res://vital_combat.gd")
const Wood = preload("res://wood_affinity.gd")
const Protection = preload("res://player_protection.gd")
const Conditions = preload("res://player_hit_conditions.gd")
const Vitals = preload("res://player_vitals.gd")
const Clock = preload("res://affinity_time.gd")
const Sources = preload("res://affinity_status_source.gd")
const Life = preload("res://player_lifecycle.gd")
const Expedition = preload("res://tests/support/expedition_case.gd")
var game: Node
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed=true
		printerr("FAIL shared affinity: ",message)

func reset() -> void:
	game.effect_timeline.clear_native()
	game.encounter.set_hp(-1,10000)
	game.encounter.clear_scouts()
	game.tactics.memory.clear()
	game.tactics.position=Vector3(0,0,-1)
	game.tactics.boss_kind=-1
	game.set_meta(Clock.CLOCK,0.0)
	if game.has_meta(Thorn.FIELDS): game.remove_meta(Thorn.FIELDS)
	for player in game.players.values():
		player.weapon=0;player.secondary=0;player.catalyst=0

func event(peer: int, slot: String, item: String, overrides: Dictionary = {}) -> RefCounted:
	var material := Build.slot(slot,int(game.Items.get_item(item).legacy_part))
	var potency: Dictionary=material.potency_profile.values.duplicate(true)
	potency.merge(overrides,true)
	return Events.begin(game,peer,slot,material,potency,["core_action","weapon_contact","class_contact"],0x7fffffffffffffff)

func run() -> void:
	game=load("res://world.tscn").instantiate()
	root.add_child(game)
	game.set_process(false);game.set_physics_process(false)
	game.battlefield.configure(0,1,0)
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
	for peer in [2,3,4]: game.add_player(peer)
	for player in game.players.values():
		Expedition.set_membership(game,player,true)
		player.pos=Vector3.ZERO
	verify_materials()
	verify_roster_attachment()
	verify_frost()
	verify_bleed()
	verify_burning()
	verify_water()
	verify_wood()
	verify_vital()
	verify_statistics()
	game.queue_free()
	await process_frame
	if not failed: print("PASS: shared affinity status buildup, frozen contributions, cadence, four contributors, expiry and stale identities")
	quit(int(failed))

func verify_statistics() -> void:
	reset()
	var now := Time.get_ticks_msec()
	var run_id: int = game.participation.run_id()
	for peer in game.players:
		if peer != 1: Expedition.Sessions.set_identity(game,game.players[peer],"stats-fixture-"+str(peer))
		game.expedition_statistics.admit(run_id,game.expedition_stat_identity(peer),str(peer),"Warden",1,now)
	var at: Vector3 = game.tactics.position
	Thorn.patch(game,event(1,"core","part_1"),at,1.0,now)
	Thorn.patch(game,event(2,"core","part_5"),at,1.0,now)
	Thorn.tick(game,Clock.advance(game,.9),now)
	var bleed_hp: int = 10000-game.enemy_health()
	reset()
	for peer in [1,2,3,4]: Fire.ignite(game,event(peer,"form","part_6"),-1,now)
	Fire.tick(game,Clock.advance(game,.25),now)
	reset()
	var recipient: Dictionary = game.players[2]
	recipient[Vitals.STATE] = recipient[Vitals.STATE].with_hp(70)
	Water.drench(game,event(1,"core","part_8"),-1)
	for index in 2: Water.drench(game,event(2,"catalyst","part_8"),-1)
	drain_water()
	var owner: String = game.expedition_stat_identity(1)
	game.expedition_statistics.finish(run_id,owner,"Extraction",now)
	game.expedition_statistics.publishable()
	var report: Dictionary = game.expedition_statistics.result_for(owner)
	var rows: Array = report.players
	check(bleed_hp>0 and is_equal_approx(rows[0].affinity.Bleed,bleed_hp*.4) and is_equal_approx(rows[1].affinity.Bleed,bleed_hp*.6),"Bleed tick credits actual accumulated 3:4.5 potency")
	check(rows[0].affinity.Burning==2 and rows.slice(1).all(func(row):return row.affinity.Burning==1),"immediate personal Fire tick plus one shared tick")
	check(rows[0].affinity.Surge+rows[1].affinity.Surge==6 and rows[0].healing>0 and rows[1].healing>0,"returning and outbound tides credit both real sources")

func verify_frost() -> void:
	reset()
	var ordinary := "plant_part_plant_frostbell"
	var now := Time.get_ticks_msec()
	var first := event(1,"core",ordinary,{"max_shatter_hp":9})
	var second := event(2,"form",ordinary,{"max_shatter_hp":12})
	Frost.apply(game,first,-1,2,now)
	var partial := Frost.state(game.tactics.memory,now)
	check(partial.stacks.size()==2 and partial.stacks[0].numerator==9000,
		"two stacks freeze thirds of the first player's maximum")
	check(is_equal_approx(Frost.motion_scale(game.tactics.memory,now),.84),"two stacks preserve their native slowing progression")
	Frost.apply(game,second,-1,1,now)
	check(game.enemy_health()==9990 and Frost.state(game.tactics.memory,now).is_empty(),"9/3 + 9/3 + 12/3 ruptures once for 10")
	check(not Frost.rooted(game.tactics.memory,now),"baseline rupture grants no root")
	Frost.apply(game,event(1,"core",ordinary,{"max_shatter_hp":10}),-1,2,now)
	Frost.apply(game,event(2,"form",ordinary,{"max_shatter_hp":12}),-1,1,now)
	check(game.enemy_health()==9979,"fractional thirds round once at final rupture: 32/3 becomes 11")
	Frost.apply(game,first,-1,1,now)
	game.players[1][Life.STATE]=Life.start_life()
	Frost.tick(game,now+1)
	check(not game.tactics.memory.has(Frost.BRITTLE),"previous-life stack cannot join a later rupture")
	Frost.apply(game,first,-1,3,now+2)
	check(game.enemy_health()==9979,"a stale source cannot reapply stacks")

func verify_bleed() -> void:
	reset()
	var now := Time.get_ticks_msec()
	var at: Vector3=game.tactics.position
	for slot in ["core","form","catalyst"]:
		Thorn.patch(game,event(1,slot,"part_1"),at,1.0,now)
	var status: Dictionary=game.tactics.memory[Thorn.BLEED]
	check(status.contributors.size()==1 and Thorn.cap_units(status)==12000,
		"Core/Form/Catalyst share one player cap, counted once")
	check(Thorn.potency_units(status)==7200,"slot applications add 25%, 10% and 25% to one buildup")
	Thorn.patch(game,event(2,"core","part_5"),at,1.0,now)
	check(status.contributors.size()==2 and Thorn.cap_units(status)==30000,
		"mixed ordinary/refined contributors add their individual caps")
	var before: int=game.enemy_health()
	Thorn.tick(game,Clock.advance(game,.9),now)
	check(game.enemy_health()==before-11 and int(status.remainder)==700,
		"one aggregate tick carries fractional damage instead of rounding each source")
	var after: int=game.enemy_health()
	Thorn.tick(game,Clock.now(game),now)
	check(game.enemy_health()==after,"repeating the same tick cannot damage again")
	reset()
	for peer in [1,2,3,4]: Thorn.patch(game,event(peer,"core","part_1"),at,1.0,now)
	for index in 4: Thorn.tick(game,Clock.advance(game,1.01),now)
	status=game.tactics.memory[Thorn.BLEED]
	check(status.contributors.size()==4 and Thorn.cap_units(status)==48000 and Thorn.potency_units(status)==48000,
		"four players build one effect to the sum of their four caps")
	var key := Sources.key(Sources.capture(event(4,"core","part_1")))
	game.network_session.release_peer(4)
	Thorn.tick(game,Clock.advance(game,.01),now)
	check(not status.contributors.has(key) and Thorn.cap_units(status)==36000,
		"disconnect removes that contributor without transferring its cap")
	Thorn.tick(game,Clock.advance(game,15.0),now)
	check(not game.tactics.memory.has(Thorn.BLEED) and not game.has_meta(Thorn.FIELDS),
		"expired fields and all accumulated contributions retire")
	var link = game.network_session.admit_peer(4,Time.get_ticks_msec())
	game.players[4][preload("res://network_session.gd").STATE]=link
	check(game.network_session.bind_character(4,"shared-fixture-four",game.network_session.binding(4)),
		"a new connection can be installed without inheriting old contributions")

func verify_burning() -> void:
	reset()
	var now := Time.get_ticks_msec()
	for peer in [1,2,3,4]:
		var fire := event(peer,"form","part_6")
		fire.publish(game,"weapon_contact","hit","leader",now,{"enemy":-1})
	var status: Dictionary=game.tactics.memory[Fire.BURNING]
	check(status.contributors.size()==4 and Fire.count(status)==32,"four players add to one shared Burning intensity")
	check(game.enemy_health()==9999,"only the first admission starts the shared immediate tick")
	Fire.tick(game,Clock.advance(game,.25),now)
	check(game.enemy_health()==9995,"32 eighth-HP stacks deal one shared 4 HP tick")
	var hp: int=game.enemy_health()
	Fire.tick(game,Clock.now(game),now)
	check(game.enemy_health()==hp,"duplicate Burning update cannot replay a tick")
	Fire.tick(game,Clock.advance(game,.25),now)
	check(Fire.count(status)==24 and game.enemy_health()==hp-3,"eight stacks decay before the same-time tick")
	Fire.tick(game,Clock.advance(game,3.5),now)
	check(not game.tactics.memory.has(Fire.BURNING),"unmaintained intensity expires and removes its contributors")
	reset()
	var boost := event(1,"form","part_6",{"stack_bonus":100})
	Fire.ignite(game,boost,-1,now)
	check(Fire.count(game.tactics.memory[Fire.BURNING])==108,"a valid application exceeds the former 96-stack ceiling without clipping")
	game.players[1][Life.STATE]=Life.start_life()
	Fire.tick(game,0,now)
	check(not game.tactics.memory.has(Fire.BURNING),"revival rejects Burning from the previous source life")

func verify_water() -> void:
	reset()
	var now := Time.get_ticks_msec()
	var water := event(1,"core","part_8")
	var other := event(2,"catalyst","part_8")
	var ally: Dictionary=game.players[2]
	ally[Conditions.STATE]=ally[Conditions.STATE].with_slow_until(now+3000)
	ally[Vitals.STATE]=ally[Vitals.STATE].with_hp(70)
	var before_hp: float=ally[Vitals.STATE].hp()
	Water.drench(game,water,-1)
	Water.drench(game,other,-1)
	Water.drench(game,other,-1)
	var status: Dictionary=game.tactics.memory[Water.DRENCHED]
	drain_water()
	check(status.saturation==0 and game.enemy_health()==9994,"40 + 30 + 30 pressure funds one weighted six-damage Tidal Return")
	check(ally[Conditions.STATE].slow_until_ms()==0 and ally[Vitals.STATE].hp()==before_hp+6,"returning shares cleanse ordinary Slow and total six healing")
	var charged := event(2,"form","part_8",{"saturation_bonus":205})
	Water.drench(game,charged,-1)
	check(game.effect_timeline.native_count()==2,"220 pressure admits two complete tide events")
	drain_water()
	check(status.saturation==20 and game.enemy_health()==9982,"220 Saturation resolves two more Surges and preserves 20 overflow")
	check(game.effect_timeline.native_count()==0,"completed weighted wave events retire; secondary hits add no pressure")
	check(is_equal_approx(Water.reduction(game.tactics.memory,0),.18),"several Water sources do not add defensive reductions")
	var display := preload("res://combat_status.gd")
	var display_now:=Time.get_ticks_msec()
	display.sync(game,display_now)
	var water_icon: Array=display.snapshot(game,display_now).filter(func(row):return row.shape=="drenched")
	check(water_icon.size()==1 and int(water_icon[0].reach)==20,"one existing status record projects the shared Saturation meter")
	var serial: int=game.combat_event_serial
	Water.drench(game,water,-1)
	display.sync(game,display_now+10)
	check(status.saturation==60 and game.combat_event_serial==serial,"presentation coalescing never delays authoritative Saturation or emits per-frame updates")
	display.sync(game,display_now+260)
	water_icon=display.snapshot(game,display_now+260).filter(func(row):return row.shape=="drenched")
	check(water_icon.size()==1 and int(water_icon[0].reach)==60,"the existing detailed status path publishes the current meter at its bounded cadence")
	reset()
	Water.drench(game,event(1,"form","plant_part_rare_dewcap"),-1)
	Clock.advance(game,2.0)
	Water.drench(game,event(1,"form","part_8"),-1)
	check(is_equal_approx(Water.reduction(game.tactics.memory,2000),.30),"a weaker application in the same slot cannot overwrite the stronger one")
	Water.tick(game,Clock.advance(game,2.3))
	check(is_equal_approx(Water.reduction(game.tactics.memory,4300),.18),"weaker duration survives without prolonging stronger protection")
	Water.tick(game,Clock.advance(game,3.0))
	check(not game.tactics.memory.has(Water.DRENCHED),"Saturation retires when Drenched has no remaining valid source")


func verify_wood() -> void:
	reset()
	var recipient: Dictionary=game.players[1]
	Wood.clear(recipient)
	check(Wood.grant(game,event(1,"core","part_17"),1,"core")==30,"ordinary Wood Core admits 30 Bark")
	check(Wood.grant(game,event(2,"catalyst","part_17"),1,"ally")==12,"another provider adds capacity rather than replacing it")
	check(Wood.grant(game,event(3,"catalyst","plant_part_rare_ironroot"),1,"ally")==18,
		"a refined provider adds its full capacity above the former shared 48 cap")
	check(Wood.grant(game,event(4,"catalyst","part_17"),1,"full")==12 and Wood.capacity(Wood.live_grants(recipient,0))==72,
		"another provider adds capacity without increasing the absorption percentage")
	var hp: float=recipient[Vitals.STATE].hp()
	var plan := Wood.absorption_plan(recipient,10,0)
	check(plan.absorbed==4 and not plan.depleted and plan.damage==0,"Bark preserves 40 percent partial absorption, not a whole-hit block")
	Wood.consume(recipient,plan)
	check(Wood.grant(game,event(4,"catalyst","part_17"),1,"refill")==12 and Wood.capacity(Wood.live_grants(recipient,0))==80 and recipient[Vitals.STATE].hp()==hp,
		"a later source adds its full independently expiring capacity without healing")
	Wood.tick(game,Clock.advance(game,4.3))
	check(Wood.capacity(Wood.live_grants(recipient,Clock.now(game)))==30,"each provider keeps its own expiration; Catalyst does not extend Core")
	Wood.tick(game,Clock.advance(game,2.0))
	check(not recipient.has(Wood.GRANTS),"expired Bark grants retire completely")

func verify_vital() -> void:
	reset()
	var recipient: Dictionary=game.players[1]
	Vital.clear(game,recipient)
	var original := Vitals.Health.new(108.0,100,12)
	var plan := Vital.harvest_plan(original)
	check(plan.accepted and plan.spent_hp==8.0 and plan.damage_hp==8 and plan.health_after.hp()==100.0
		and plan.health_after.max_hp()==112 and original.hp()==108.0,
		"Harvest quotes spend filled bonus HP, preserve capacity and leave the prior immutable value intact")
	plan=Vital.harvest_plan(Vitals.Health.new(105.5,100,12))
	check(plan.spent_hp==5.5 and plan.damage_hp==6,"fractional spending rounds damage once at the final boundary")
	plan=Vital.harvest_plan(Vitals.Health.new(80.0,100,18))
	check(not plan.accepted and plan.spent_hp==0.0 and plan.health_after.hp()==80.0,"baseline Harvest never spends normal HP")
	plan=Vital.harvest_plan(Vitals.Health.new(118.0,100,18),true)
	check(plan.spent_hp==68.0 and plan.health_after.hp()==50.0 and plan.health_after.max_hp()==118,
		"the optional future modifier supports a native-capacity safety floor without a card or automatic activation")
	check(not Vital.harvest_plan(original,false,.5,0.0).accepted
		and not Vital.harvest_plan(Vitals.Health.new(100.1,100,12)).accepted,
		"invalid or zero-useful-damage quotes cannot charge health")
	recipient[Vitals.STATE]=Vitals.Health.new(100.0,100)
	Vital.grant(game,event(1,"core","part_2"),1,0)
	check(recipient[Vitals.STATE].hp()==100.0 and recipient[Vitals.STATE].max_hp()==112,"Vital capacity never grants free healing")
	Vital.tick(game,Clock.advance(game,1.0))
	check(recipient[Vitals.STATE].hp()==103.0,"existing regeneration fills bonus capacity")
	var protection: RefCounted=recipient[Protection.STATE]
	var hit_seq: int=recipient.damage_seq
	var events: int=game.combat_event_serial
	plan=Vital.harvest_plan(recipient[Vitals.STATE])
	recipient[Vitals.STATE]=plan.health_after # Deliberate fixture commit, not a new gameplay control.
	check(recipient[Vitals.STATE].hp()==100.0 and recipient[Protection.STATE]==protection
		and recipient.damage_seq==hit_seq and game.combat_event_serial==events,
		"resource spending issues no incoming-hit, Ward, class, Catalyst or damage-reactive event")
	Vital.tick(game,Clock.advance(game,1.0))
	check(recipient[Vitals.STATE].hp()==103.0 and recipient[Vitals.STATE].max_hp()==112,"regeneration can replenish spent bonus HP")
	reset()
	Vital.clear(game,recipient)
	recipient[Vitals.STATE]=Vitals.Health.new(110.0,100,18)
	Vital.grant(game,event(2,"core","plant_part_rare_lantern_moss"),1,0)
	Clock.advance(game,2.0)
	Vital.grant(game,event(2,"core","part_2"),1,2000)
	check(recipient[Vitals.STATE].temporary_hp()==18,"a weak reapplication cannot replace stronger Vital capacity")
	Vital.tick(game,Clock.advance(game,3.6))
	check(recipient[Vitals.STATE].temporary_hp()==12 and recipient[Vitals.STATE].hp()<=112,
		"strong capacity expires on its own deadline; weak capacity survives and HP clamps")
	game.players[2][Life.STATE]=Life.start_life()
	Vital.tick(game,Clock.advance(game,.4))
	check(recipient[Vitals.STATE].temporary_hp()==12,"accepted recipient-owned protection finishes after provider life changes")
	recipient[Life.STATE]=Life.start_life()
	Vital.tick(game,Clock.now(game))
	check(not recipient.has(Vital.SOURCES) and recipient[Vitals.STATE].temporary_hp()==0,"a new recipient life cannot inherit previous-life Vitality")


func verify_roster_attachment() -> void:
	reset()
	var now := Time.get_ticks_msec()
	Frost.apply(game,event(1,"form","plant_part_plant_frostbell",{"max_shatter_hp":9}),-1,2,now)
	var token: int=game.encounter.spawn_identity(-1)
	game.encounter.register_leader_tactics(game.make_scout(0,game.tactics.position,0))
	Frost.apply(game,event(2,"form","plant_part_plant_frostbell",{"max_shatter_hp":12}),-1,1,now)
	check(game.encounter.spawn_identity(-1)==token and game.enemy_health()==9990,
		"late tactical-body attachment keeps two accepted stacks for the same enemy's mixed 10 HP rupture")


func verify_materials() -> void:
	var materials: Dictionary=preload("res://tests/support/shared_affinity_network_case.gd").MATERIALS
	for family: String in materials:
		for index in materials[family].size():
			var item: Dictionary=game.Items.get_item(materials[family][index])
			check(item.has("legacy_part"),"network fixture material exists: "+materials[family][index])
			if item.has("legacy_part"):
				var slot := Build.slot("core",int(item.legacy_part))
				check(slot.primary_affinity==family and slot.quality==("ordinary" if index==0 else "refined"),
					"network fixture materials have the stated family and quality")

func drain_water() -> void:
	var records: Array=game.effect_timeline.native_records()
	if records.is_empty():return
	var start: int=records[0].waves[0].start
	for offset in [0,225,451,675,901]:game.effect_timeline.advance_native(game.native_effects_world,start+offset)
