extends SceneTree
const Effects = preload("res://enemy_affinity_effects.gd")
## Actual definitions/handlers; future-potency fixtures are labelled separately
## from attainable 12-card/six-graft builds. No invented card definitions.
const Events = preload("res://combat_action_events.gd")
const Build = preload("res://affinity_build.gd")
const Thorn = preload("res://thorn_affinity.gd")
const Frost = preload("res://frost_combat.gd")
const Fire = preload("res://fire_combat.gd")
const Water = preload("res://water_combat.gd")
const Wood = preload("res://wood_affinity.gd")
const Vital = preload("res://vital_combat.gd")
const Sources = preload("res://affinity_status_source.gd")
const Vitals = preload("res://player_vitals.gd")
const Life = preload("res://player_lifecycle.gd")
const Clock = preload("res://affinity_time.gd")
const Cards = preload("res://affinity_cards.gd")
const Catalog = preload("res://affinity_card_catalog.gd")
const Grafts = preload("res://expedition_grafts.gd")
const Resolved = preload("res://resolved_combat_build.gd")
const Expedition = preload("res://tests/support/expedition_case.gd")
var game: Node
var failed := false
var serial := 0

func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failed=true;printerr("FAIL affinity scaling: ",message)

func reset() -> void:
	game.encounter.set_hp(-1,10000000)
	game.encounter.clear_scouts()
	game.tactics.memory.clear()
	game.tactics.position=Vector3(0,0,-1)
	game.tactics.boss_kind=-1
	game.enemy_mutations=0
	game.set_meta(Clock.CLOCK,0.0)
	if game.has_meta(Thorn.FIELDS): game.remove_meta(Thorn.FIELDS)
	for p: Dictionary in game.players.values():
		p.erase(Cards.STATE);p.erase(Grafts.STATE)
		Wood.clear(p);Vital.clear(game,p)
		p.weapon=0;p.secondary=0;p.catalyst=0;p.weapon_kind=0;p.frame=2
		p.character=game.Character.blank()
		var tree=game.Classes.connected_tree(2)
		p.character[tree.profile_key]=tree.state(["wildstalker"])
		p[Life.STATE]=Life.start_life()
		p[Vitals.STATE]=Vitals.Health.new(100.0,100)
		p.pos=Vector3.ZERO

func equip(p: Dictionary, item: String) -> void:
	var part: int=game.Items.get_item(item).legacy_part
	p.weapon=part;p.secondary=part;p.catalyst=part

func copies(p: Dictionary, ids: Array) -> void:
	var records: Array[Dictionary]=[]
	for id: String in ids:
		var definition: Dictionary=Catalog.DEFINITIONS[id]
		for _index in 4:
			serial+=1
			records.append({"id":id,"amount":definition.values[3],"rarity":"Epic","floor":1,"acquisition_id":serial})
	check(records.size()<=int(Catalog.PLAYTEST.acquisition_limit),"specialized fixture respects current acquisition budget")
	p[Cards.STATE]=Cards.Ledger.new(records)

func six_grafts(p: Dictionary) -> void:
	var owner := Grafts.Ledger.new(serial+1000)
	p[Grafts.STATE]=owner
	var carried: Array=game.Parts.empty_counts()
	var trophy: int=game.Items.get_item("monster_0").legacy_part
	carried[trophy]=6
	for index in 6:
		var altar_floor: int=(index+1)*game.EncounterConfig.GRAFT_INTERVAL
		var plan := owner.plan_purchase({"run":owner.identity(),"floor":altar_floor,"revision":index,"id":"health","item":"monster_0"},
			altar_floor,carried,game.combat_build(p).graft_value_resolver(game.MAX_HEALTH,0,0))
		check(plan.has("ledger"),"actual graft rules admit each of six distinct-altar health purchases")
		if not plan.has("ledger"): return
		carried[trophy]-=int(plan.cost)
		owner=plan.ledger;p[Grafts.STATE]=owner
	check(owner.details(6*game.EncounterConfig.GRAFT_INTERVAL).copies.size()==6 and carried[trophy]==0,"six graft receipts consume six trophies without changing the purchase budget")

func action(peer: int, slot: String, overrides: Dictionary = {}) -> RefCounted:
	var p: Dictionary=game.players[peer]
	var part: Dictionary=game.combat_build(p).affinity_build()[slot]
	var base: Dictionary=part.potency_profile.values.duplicate(true)
	base.merge(overrides,true)
	return Events.begin(game,peer,slot,part,base,["core_action","weapon_contact","class_contact"],Time.get_ticks_msec()+1000000)

func run() -> void:
	game=load("res://world.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false)
	game.battlefield.configure(0,1,0)
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
	for id in [2,3,4]: game.add_player(id)
	for p in game.players.values(): Expedition.set_membership(game,p,true)
	verify_thorn()
	verify_frost()
	verify_fire()
	verify_wood()
	verify_water()
	verify_vital()
	check(Catalog.DEFINITIONS.size()>=28 and Catalog.PLAYTEST.acquisition_limit==12 and Grafts.PLAYTEST.purchase_limit==6,
		"catalog and global playtest budgets remain unchanged")
	game.queue_free();await process_frame
	if not failed: print("PASS: affinity baselines, real specialized builds, uncapped intensity/capacity, resolved UI, future potency, mitigation and lifecycle")
	quit(int(failed))

func verify_thorn() -> void:
	reset()
	var p: Dictionary=game.players[1]
	equip(p,"part_1")
	var now := Time.get_ticks_msec()
	Thorn.patch(game,action(1,"core"),game.tactics.position,1.0,now)
	var wound: Dictionary=Effects.read(game,-1)[Thorn.BLEED]
	check(Thorn.cap_units(wound)==12000 and Thorn.potency_units(wound)==3000,"solo baseline is a build-derived 12 cap with 25 percent initial buildup")
	copies(p,["thorn_line_bleed","ordinary_weapon_damage","ordinary_weapon_interval"])
	var resolved: Resolved.Snapshot=game.combat_build(p)
	var live: Dictionary=resolved.affinity_build()
	check(live.core.potency_profile.values.tick_hp==12 and live.core.resolved_potency.personal_cap_hp==28
		and live.form.resolved_potency.personal_cap_hp==28 and live.catalyst.resolved_potency.personal_cap_hp==28,
		"baseline stays authoritative while all three slots resolve one 28 cap with four real Epic copies")
	var projected: Array=Cards.ledger(p).project_owned(game.weapon_stats(p),game.DODGE_COOLDOWN_MS)
	var received := Resolved.Snapshot.new(game.weapon_stats(p),Cards.applied_totals(projected))
	check(received.affinity_potency("form").personal_cap_hp==28,
		"guest reconstruction from unchanged owner details produces the same cap without applying cards twice")
	p.weapon=int(game.Items.get_item("part_8").legacy_part)
	var inactive: Array=Cards.ledger(p).project_owned(game.weapon_stats(p),game.DODGE_COOLDOWN_MS)
	check(game.combat_build(p).affinity_potency("form").personal_cap_hp==12
		and inactive.any(func(copy):return copy.id=="thorn_line_bleed" and copy.applied==0 and not str(copy.reason).is_empty()),
		"equipment-dependent cap contributions become inactive with an explicit reason")
	p.weapon=int(game.Items.get_item("part_1").legacy_part)
	check(game.combat_build(p).affinity_potency("form").personal_cap_hp==28 and Cards.ledger(p).count()==12,
		"restoring the required Core reactivates the same owned contributions")
	check(Thorn.potency_units(wound)==3000,"acquiring potency cannot fill an existing wound for free")
	check(resolved.core_skill().tooltip.contains("28.00") and Build.slot_preview(live,"form",p.secondary).detail.contains("28.00")
		and game.inventory_ui_data().affinity_build.core.resolved_potency.personal_cap_hp==28,
		"Core, Form and inventory presentation expose the same resolved potency")
	Thorn.patch(game,action(1,"core"),game.tactics.position,1.0,now)
	check(Thorn.potency_units(wound)==3000,"a stronger replacement cannot bypass the existing application interval")
	Thorn.tick(game,Clock.advance(game,1.001),now)
	check(Thorn.cap_units(wound)==28000 and Thorn.potency_units(wound)==10000,"new cap requires a new eligible 7-damage contribution, not rescaling prior buildup")
	equip(game.players[2],"part_1")
	Thorn.patch(game,action(2,"core"),game.tactics.position,1.0,now)
	check(Thorn.cap_units(wound)==40000 and Thorn.potency_units(wound)==13000,"weaker player adds its own cap and buildup without weakening the specialist")
	reset()
	for id in [1,2,3,4]:
		equip(game.players[id],"part_5")
		copies(game.players[id],["thorn_line_bleed","ordinary_weapon_damage","ordinary_weapon_interval"])
		Thorn.patch(game,action(id,"core"),game.tactics.position,1.0,now)
	for _step in 4: Thorn.tick(game,Clock.advance(game,1.001),now)
	wound=Effects.read(game,-1)[Thorn.BLEED]
	check(Thorn.cap_units(wound)==136000 and Thorn.potency_units(wound)==136000,"four current specialized players build one 136-damage shared tick")
	game.players[4][Life.STATE]=Life.start_life()
	Thorn.tick(game,Clock.now(game),now)
	check(Thorn.cap_units(wound)==102000,"revival removes exactly the stale contributor's upgraded cap")
	print("SCALING_THORN baseline_cap=18 epic_cap=34 four_player_cap=136 tick_ms=900")

func verify_frost() -> void:
	reset()
	for id in [1,2]: equip(game.players[id],"plant_part_rare_frostbell")
	copies(game.players[1],["rime_opening","ordinary_weapon_damage","ordinary_weapon_interval"])
	check(game.combat_build(game.players[1]).core_skill().tooltip.contains("29 HP")
		and action(1,"core").potency().personal_cap_hp==21,"current Rime cards increase opening damage, not an undocumented shatter bonus")
	var now := Time.get_ticks_msec()
	Frost.apply(game,action(1,"form",{"max_shatter_hp":90}),-1,1,now)
	Frost.apply(game,action(2,"form",{"max_shatter_hp":120}),-1,1,now)
	check(Effects.read(game,-1)[Frost.BRITTLE].stacks[0].numerator==90000,"future-potency fixture freezes the earlier stack's exact numerator")
	Frost.apply(game,action(1,"form",{"max_shatter_hp":300}),-1,1,now)
	check(game.enemy_health()==10000000-170 and not Effects.read(game,-1).has(Frost.BRITTLE)
		and not Frost.rooted(game.tactics.memory,now),"90/3 + 120/3 + 300/3 ruptures for 170 once, with no baseline root or fixed shatter ceiling")
	print("SCALING_FROST current_refined_max=21 future_input_max=300 mixed_rupture=170 threshold=3")

func fire_sample(heavy: bool, party: int) -> Dictionary:
	reset()
	for id in range(1,party+1):
		equip(game.players[id],"plant_part_rare_ember_fern")
		if heavy: copies(game.players[id],["burning_strikes_heat","catalyst_ember_heat","ordinary_weapon_interval"])
	var p: Dictionary=game.players[1]
	var interval: int=game.combat_build(p).basic_stats().interval
	check(action(1,"form").potency().stack_bonus==(20 if heavy else 4),"sustained sample includes actual equipped Form rarity and acquired stack copies")
	var next_attack := 0
	var measure_hp := 0
	var maximum := 0
	var now := Time.get_ticks_msec()
	for at in range(0,30001,10):
		game.set_meta(Clock.CLOCK,float(at))
		Fire.tick(game,at,now+at)
		if at>=next_attack:
			for id in range(1,party+1): action(id,"form").publish(game,"weapon_contact","hit","leader",now+at,{"enemy":-1})
			next_attack+=interval
		maximum=maxi(maximum,Fire.count(Effects.read(game,-1).get(Fire.BURNING,{})))
		if at==20000: measure_hp=game.enemy_health()
	var before: int=game.enemy_health()
	Fire.tick(game,30000,now+30000)
	check(game.enemy_health()==before,"repeated same-time tick cannot replay specialized Burning")
	var result := {"players":party,"heavy":heavy,"interval_ms":interval,"stacks_applied":action(1,"form").potency().stack_bonus+Fire.APPLICATION_STACKS.form,
		"peak_stacks":maximum,"final_stacks":Fire.count(Effects.read(game,-1).get(Fire.BURNING,{})),"dot_dps_last_10s":(measure_hp-game.enemy_health())/10.0}
	print("SCALING_FIRE ",JSON.stringify(result))
	return result

func verify_fire() -> void:
	var baseline := fire_sample(false,1)
	var specialist := fire_sample(true,1)
	var party := fire_sample(true,4)
	check(specialist.peak_stacks>96 and specialist.dot_dps_last_10s>baseline.dot_dps_last_10s,
		"the real specialized loadout retains extra application and attack-speed value above 96")
	check(party.final_stacks>specialist.final_stacks*3 and party.dot_dps_last_10s>specialist.dot_dps_last_10s*3,
		"four maintained specialists sustain substantially more than one without sublinear suppression")
	check(Fire.decay_amount(1000000000)==100000000,"large intensity decays in one integer calculation, not one operation per stack")
	game.players[4][Life.STATE]=Life.start_life()
	Fire.tick(game,30000,Time.get_ticks_msec())
	check(Effects.read(game,-1)[Fire.BURNING].contributors.size()==3,"stale upgraded Burning source retires after revival")
	reset()
	equip(game.players[1],"part_6")
	Fire.ignite(game,action(1,"form",{"stack_bonus":100000000000000000}),-1,Time.get_ticks_msec())
	check(not Effects.read(game,-1).has(Fire.BURNING),"an unrepresentable milli-HP product is refused without installing invalid Burning")

func verify_wood() -> void:
	reset()
	var p: Dictionary=game.players[1]
	equip(p,"part_17")
	Wood.grant(game,action(1,"core"),1,"core")
	check(Wood.capacity(Wood.live_grants(p,0))==30 and Wood.absorption_plan(p,100,0).absorbed==30,"baseline solo Bark retains 30 finite protection")
	Wood.clear(p)
	equip(p,"plant_part_rare_ironroot")
	copies(p,["ironbark_time","catalyst_bark_time","ordinary_weapon_interval"])
	six_grafts(p)
	Wood.grant(game,action(1,"core"),1,"core")
	Wood.grant(game,action(1,"catalyst"),1,"class")
	check(Wood.capacity(Wood.live_grants(p,0))==58,"one specialized player combines full Core and Catalyst grants above 48")
	game.set_meta(Clock.CLOCK,8000.0)
	Wood.grant(game,action(1,"core"),1,"core")
	Wood.grant(game,action(1,"catalyst"),1,"class")
	check(Wood.capacity(Wood.live_grants(p,8000))==98 and game.combat_build(p).core_skill().tooltip.contains("8.8 s"),
		"real duration cards allow a new eight-second Core cast to overlap its 8.8-second predecessor")
	var plan := Wood.absorption_plan(p,100,8000)
	check(plan.absorbed==40,"specialization increases endurance while an unblocked hit still loses only 40 percent")
	Wood.consume(p,plan)
	check(Wood.capacity(Wood.live_grants(p,8000))==58,"consumption spends actual grant capacity")
	Wood.clear(p)
	check(Wood.grant(game,action(1,"core",{"core_capacity":1000000}),1,"future")==1000000,
		"a future-capacity fixture admits a million protection without introducing invulnerability")
	var count: int=p[Wood.GRANTS].size()
	check(Wood.grant(game,action(1,"core",{"core_capacity":Sources.MAX_INTEGER}),1,"invalid")==0 and p[Wood.GRANTS].size()==count,
		"unrepresentable totals are refused rather than wrapping or clipping a valid pool")
	print("SCALING_WOOD baseline_capacity=30 current_specialist_overlap=98 incoming_hp=100 specialist_absorbed=40")

func verify_water() -> void:
	reset()
	for id in [1,2]: equip(game.players[id],"part_8")
	var strong := action(1,"form",{"saturation_bonus":70,"surge_hp":18,"surge_width_cm":330})
	Water.drench(game,strong,-1)
	game.encounter.register_scout(game.make_scout(0,Vector3(3.5,0,-1),1))
	game.encounter.set_hp(0,1000)
	Water.drench(game,action(2,"form"),-1)
	drain_water()
	check(game.enemy_health()==10000000-16 and game.encounter.hp(0)==985
		and Effects.read(game,-1)[Water.DRENCHED].saturation==0,"85 strong and 15 ordinary pressure preserve frozen 16 total damage; only the wide strong share hits the side target")
	Clock.advance(game,2.0)
	Water.drench(game,action(2,"form"),-1)
	Water.tick(game,Clock.advance(game,2.3))
	Water.drench(game,action(2,"form",{"saturation_bonus":205}),-1)
	drain_water()
	check(Effects.read(game,-1)[Water.DRENCHED].saturation==35 and game.enemy_health()==10000000-28
		and game.encounter.hp(0)==985,"expired enhancement ends independently; two baseline Surges retain 35 overflow and normal radius")
	check(is_equal_approx(Water.reduction(Effects.read(game,-1).get(Water.DRENCHED,{}),Clock.now(game)),.18),"offensive scaling does not stack Drenched defense")
	print("SCALING_WATER baseline_surge_hp=6 future_input_hp=18 future_half_width_m=4 overflow=35 threshold=100")
	reset()
	var p: Dictionary=game.players[1]
	equip(p,"plant_part_rare_dewcap")
	copies(p,["dewfall_impact","catalyst_drench_time","ordinary_weapon_interval"])
	var live: Dictionary=game.combat_build(p).affinity_build()
	check(live.core.resolved_potency.impact_hp==31 and live.catalyst.resolved_potency.impact_hp==11
		and Build.slot_preview(live,"catalyst",p.catalyst).detail.contains("7.0 s"),
		"current Water cards resolve in their own slots and the tooltip includes the real seven-second Drenched duration")
	Water.drench(game,action(1,"catalyst"),-1)
	check(Effects.read(game,-1)[Water.DRENCHED].sources.values()[0].until==7000,
		"current Water duration copies reach the actual consumer once")

func verify_vital() -> void:
	reset()
	var p: Dictionary=game.players[1]
	equip(p,"plant_part_rare_lantern_moss")
	var base_native: int=game.Life.native_maximum(game,p)
	copies(p,["catalyst_vital_regen","vital_bloom_time","run_health"])
	six_grafts(p)
	var native: int=game.Life.native_maximum(game,p)
	check(native==base_native+66,"six real health grafts and four Hardy Frame copies remain separate non-Vital contributions")
	p[Vitals.STATE]=Vitals.Health.new(native-50,native)
	var cast := action(1,"catalyst")
	Vital.grant(game,cast,1,0)
	check(p[Vitals.STATE].hp()==native-50 and p[Vitals.STATE].max_hp()==native+18,
		"a grown health capacity does not heal on grant")
	Vital.tick(game,Clock.advance(game,1.0))
	check(p[Vitals.STATE].hp()==native-29 and game.combat_build(p).affinity_potency("catalyst").regen_per_second==21,
		"four real Epic Greening Chime copies restore 21 HP on one shared tick")
	p[Vitals.STATE]=p[Vitals.STATE].refilled()
	var plan := Vital.harvest_plan(p[Vitals.STATE],false,.5,2.5)
	check(plan.spent_hp==18 and plan.damage_hp==45 and plan.health_after.max_hp()==native+18,
		"future Harvest efficiency improves output from actual filled bonus HP without spending normal HP")
	p[Vitals.STATE]=plan.health_after
	Vital.tick(game,Clock.advance(game,1.0))
	check(p[Vitals.STATE].hp()==native+18 and p[Vitals.STATE].native_max_hp()==native,"regeneration replenishes spent bonus HP without recursively increasing native capacity")
	Vital.grant(game,action(1,"core",{"bonus_hp":180,"regen_per_second":50}),1,Clock.now(game))
	check(p[Vitals.STATE].temporary_hp()==180 and p[Vitals.STATE].hp()==native+18,"future growth potency is not clamped to its refined baseline or immediately filled")
	Vital.tick(game,Clock.advance(game,1.0))
	check(p[Vitals.STATE].hp()==native+68,"stronger future regeneration remains effective on its original cadence")
	Expedition.set_world(game,{"combat_epoch":game.participation.epoch()+1})
	Vital.tick(game,Clock.now(game))
	Fire.tick(game,Clock.now(game),Time.get_ticks_msec())
	check(not p.has(Vital.SOURCES) and Vitals.temporary_hp(p)==0,"floor identity changes retire upgraded recipient effects")
	print("SCALING_VITAL current_bonus_hp=18 baseline_regen=5 epic_regen=21 future_bonus_hp=180 future_regen=50 harvest_efficiency=2.5")

func drain_water() -> void:
	var records: Array=game.effect_timeline.native_records().filter(func(row):return row.kind=="water_tide")
	if records.is_empty():return
	var start: int=records[0].waves[0].start
	for offset in [0,225,451,675,901]:game.effect_timeline.advance_native(game.native_effects_world,start+offset)
