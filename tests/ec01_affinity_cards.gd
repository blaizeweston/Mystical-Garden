extends SceneTree

const Rules = preload("res://combat_ruleset.gd")
const Cards = preload("res://affinity_cards.gd")
const Catalog = preload("res://affinity_card_catalog.gd")
const Build = preload("res://affinity_build.gd")
const Events = preload("res://combat_action_events.gd")
const Clock = preload("res://affinity_time.gd")
const Core = preload("res://core_combat.gd")
const Frost = preload("res://frost_combat.gd")
const Aim = preload("res://ability_aim.gd")
const Footprint = preload("res://core_footprint.gd")
const FOCUSES := ["vanguard","bloomcaller","snarekeeper","blood_harvester","lifekeeper"]
const CLASS_CARDS := ["quake_impact","nova_impact","snare_root_time","siphon_impact","chime_ward_time"]
const STARTER_CARDS := ["ordinary_weapon_damage","ordinary_weapon_interval","run_health","run_dodge_recovery"]
var game: Node
var player: Dictionary
var ally: Dictionary
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL EC01: ",label)


func focus(class_id: int) -> void:
	player.frame = class_id
	player.character = game.Character.blank()
	var tree: RefCounted = game.Classes.connected_tree(class_id)
	player.character[tree.profile_key] = tree.state([FOCUSES[class_id]])


func reset(class_id := 0) -> void:
	game.combat_epoch += 1
	game.encounter_number = 1
	game.destination = game.Campaign.GROVE
	game.enemy_hp = 400
	game.enemy_pos = Vector3(0,0,-1.2)
	game.enemy_mutations = 0
	game.enemy_winding_up = false
	game.boss_kind = -1
	game.rooted_until = 0
	game.checkpoint_pending = false
	game.checkpoint_ready.clear()
	game.deepest_milestone = 0
	for records: Array in [game.scouts,game.trait_events,game.projectile_queue,game.combat_events,game.pending_kill_rewards]:
		records.clear()
	game.leader_brain.clear()
	game.enemy_traits.clear()
	game.battlefield = preload("res://battlefield.gd").new()
	game.battlefield.configure(0,1)
	game.battlefield.barriers.clear()
	game.set_meta(Clock.CLOCK,0.0)
	game.remove_meta(Rules.Thorn.FIELDS)
	Core.reset(game)
	for p: Dictionary in [player,ally]:
		Cards.clear(p)
		for key in [Rules.Wood.GRANTS,Rules.Spirit.STRIDES,Rules.Vital.SOURCES,Rules.Vital.BONUS,"affinity_ward_claims",
				Rules.Storm.FORM_READY,Rules.Void.FORM_READY,Rules.Wood.FORM_READY,"subclass_follow","warden_block"]:
			p.erase(key)
		for key in ["weapon","secondary","catalyst","graft_part","lost_health","guard_until","guard_charges",
				"strike_at","skill_at","skill_two_at","dodge_at","cast_until","core_ready_at","core_cast_until","spent","essence_sparks","last_offer"]:
			p[key] = 0
		p.pos = Vector3.ZERO
		p.wild = true
		p.fallen = false
		p.profile_ready = true
		p.mouse_aim = false
		p.facing = Vector3.FORWARD
		p.hp = 80.0
		p.max_hp = 100
	focus(class_id)


func material(family: String) -> int:
	for index: int in range(1, game.Parts.DEFINITIONS.size()):
		if Build.Affinities.for_part(index).get("primary_affinity") == family:
			return index
	return 0


func effect(id: String, rank := 0) -> int:
	var definition: Dictionary = Catalog.DEFINITIONS[id]
	return definition.fixed if definition.policy == "unique" else definition.values[rank]


func grant_fixture_copy(id: String, rank := 0) -> int:
	var definition: Dictionary = Catalog.DEFINITIONS[id]
	var contribution := effect(id,rank)
	var run_state := Cards.state(player)
	run_state.copies.append({"id":id,"amount":contribution,
		"rarity":"" if definition.policy == "unique" else Catalog.RARITIES[rank], "floor":game.encounter_number,
		"acquisition_id":run_state.copies.size()+1})
	run_state.totals[id] = Cards.amount(player,id)+contribution
	return contribution


func at_checkpoint(floor_number: int) -> void:
	game.encounter_number = floor_number
	game.enemy_hp = 0
	game.scouts.clear()
	game.encounter_rewarded = true
	game.checkpoint_ready.clear()
	game.checkpoint_pending = true
	for p: Dictionary in [player,ally]:
		p.pos = game.battlefield.advance


func action(revision: int, choice: String) -> void:
	game.garden_action(1,game.affinity_checkpoint_action(revision,choice))


func verify_offers() -> void:
	reset()
	for class_id in FOCUSES.size():
		focus(class_id)
		var available := Cards.eligible(player,game.weapon_stats(player),game.DODGE_COOLDOWN_MS)
		check(available.size()==(6 if class_id==1 else 5) and CLASS_CARDS[class_id] in available and STARTER_CARDS.all(func(id):return id in available),
			"level-one class %d with empty slots has real options: %s" % [class_id,available])
	var curve := Catalog.rise(1)
	check(curve==[78.0,18.0,3.0,1.0] and Catalog.rise(1_000)==Catalog.rise(90)
		and Catalog.rise(7)[3]>curve[3],"rarity interpolates and remains available at endless depth")
	var capped_stats: Dictionary = game.weapon_stats(player)
	capped_stats.interval = Cards.STRIKE_MIN_MS
	check("ordinary_weapon_interval" not in Cards.eligible(player,capped_stats,game.DODGE_COOLDOWN_MS),
		"an ordinary weapon already at the real interval floor cannot be offered a zero-effect card")
	game.encounter_number = 90
	var mixed := false
	for seed_value in range(1,16):
		player.upgrade_seed = seed_value
		var drawn := Cards.roll(game,player,game.weapon_stats(player))
		if drawn.any(func(copy):return copy.rarity!=drawn[0].rarity):
			mixed = true
			break
	check(mixed,"one offer can show different independently rolled rarities")
	at_checkpoint(3)
	game.present_checkpoint_cards(1)
	var run_state := Cards.state(player)
	var original: Dictionary = run_state.offer.duplicate(true)
	check(original.cards.size()==3 and game.checkpoint_offer_revision==original.revision and game.run_wallet(player)==0,
		"three owner options are offered at zero Essence")
	game.present_checkpoint_cards(1)
	check(original==run_state.offer,"opening again preserves identities, rarities and revision")
	action(original.revision,"reroll")
	check(original==run_state.offer and player.spent==0,"insufficient currency changes nothing")
	player.essence_sparks = 48
	for cost in [2,4,6]:
		var before: Dictionary = run_state.offer
		var wallet: int = game.run_wallet(player)
		action(before.revision,"reroll")
		var after: Dictionary = run_state.offer
		check(after.revision>before.revision and game.run_wallet(player)==wallet-cost
			and after.cards.any(func(card): return not before.cards.any(func(old): return old.id==card.id)),
			"paid replacement changes the offer set and debits %d" % cost)
		action(before.revision,"reroll")
		action(before.revision,"0")
		check(after==run_state.offer and game.run_wallet(player)==wallet-cost and run_state.copies.is_empty(),
			"stale selection and reroll cannot mutate current offer")
	var offered: Dictionary = run_state.offer.cards[0]
	var profile: Dictionary = player.character.duplicate(true)
	var rev: int = run_state.offer.revision
	action(rev,"0")
	action(rev,"1")
	check(run_state.copies.size()==1 and run_state.copies[0].acquisition_id==rev and run_state.copies[0].rarity==offered.rarity
		and game.run_wallet(player)==0 and run_state.offer.closed and player.character==profile,
		"selection at zero costs nothing and duplicate selection cannot affect state or profile")
	at_checkpoint(6)
	var next := Cards.open(game,player,game.weapon_stats(player))
	check(next.cards.size()==3 and next.revision>rev and Cards.reroll_cost(next)==2 and run_state.copies.size()==1,
		"new checkpoint resets escalation and preserves the acquired copy")
	action(next.revision,"skip")
	check(run_state.copies.size()==1 and next.closed,"skip uses only this checkpoint")
	reset()
	at_checkpoint(3)
	player.essence_sparks = 80
	for _copy in 4:
		grant_fixture_copy("ordinary_weapon_damage")
		grant_fixture_copy("run_health")
	var braked := Cards.open(game,player,game.weapon_stats(player))
	check(braked.cards.size()==3,"remaining legal pool fits exactly one offer")
	action(braked.revision,"reroll")
	check(Cards.state(player).offer==braked and player.spent==0,"no valid replacement leaves wallet and revision intact")

	reset()
	player.weapon = material("fire")
	for index in 3:
		at_checkpoint(3*(index+1))
		var grade := 3 if index==2 else 0
		var option := {"id":"ember_impact","rarity":Catalog.RARITIES[grade],"amount":effect("ember_impact",grade)}
		var offer := Cards.new_offer(game,[option],0)
		Cards.state(player).offer = offer
		action(offer.revision,"0")
	var copies: Array = Cards.state(player).copies
	check(copies.size()==3 and copies[0].amount==2 and copies[1].amount==2 and copies[2].amount==5
		and Cards.amount(player,"ember_impact")==9 and copies[0].acquisition_id!=copies[1].acquisition_id,
		"real acquisition keeps Common + Common + Epic contributions rather than upgrading earlier copies")
	player.weapon = 0
	player.secondary = material("fire")
	var ordinary_fire := source_event("form","fire","weapon_contact",Time.get_ticks_msec())
	check(ordinary_fire.potency()==Build.for_player(player).form.potency_profile.values,
		"same-family Form never inherits a Core-only copy")
	check(Cards.project_owned(player,game.weapon_stats(player),game.DODGE_COOLDOWN_MS)[0].reason=="Equip a Fire Core.",
		"matching the wrong slot leaves Core copies owned and inactive")
	player.weapon = player.secondary
	check(Cards.project_owned(player,game.weapon_stats(player),game.DODGE_COOLDOWN_MS)[0].applied==9,
		"returning to the required slot reactivates all three copies")
	reset()
	for index in int(Catalog.PLAYTEST.acquisition_limit):
		grant_fixture_copy(STARTER_CARDS[index%STARTER_CARDS.size()])
	at_checkpoint(60)
	var limit := Cards.view(game,player,false)
	check(limit.exhausted and limit.choices.is_empty() and not limit.reroll_enabled,"test cap has explicit exhausted state")
	action(limit.revision,"skip")
	check(game.checkpoint_ready.get(1)==60,"exhausted floor 60 can still ready the Gate")
	game.checkpoint_ready[2] = 60
	check(game._use_checkpoint(1,true) and game.encounter_number==61,"travel continues past floor 60 with exhausted budget")
	player.spent = 7
	ally.essence_sparks = 8
	ally.spent = 2
	grant_fixture_copy("run_health")
	game.abandon_run(2,ally)
	check(ally.spent==0 and game.run_wallet(ally)==0 and not ally.has(Cards.STATE) and player.wild,
		"partial party return zeroes detached wallet while the companion remains")
	at_checkpoint(66)
	check(game._use_checkpoint(1,false) and not player.has(Cards.STATE) and game.run_wallet(player)==0,"extraction clears run ownership and purse")
	reset()
	grant_fixture_copy("run_health")
	player.essence_sparks=60
	check(game.finish_failed_expedition() and not player.has(Cards.STATE) and game.run_wallet(player)==0,"wipe clears run ownership and purse")


func source_event(scope: String, family: String, channel: String, now: int) -> RefCounted:
	player[{"core":"weapon","form":"secondary","catalyst":"catalyst"}[scope]] = material(family)
	var build := Build.for_player(player)
	var part: Dictionary = build[scope]
	return Events.begin(game,1,scope,part,part.potency_profile.values,[channel],now+15000)


func verify_core() -> void:
	for setup in [["frost","rime_opening"],["fire","ember_impact"],["vital","vital_bloom_time"],
			["thorn","thorn_line_bleed"],["wood","ironbark_time"],["storm","chain_spark_power"],
			["spirit","phantom_stride_time"],["void","gravity_collapse"]]:
		reset()
		var family: String = setup[0]
		var bonus := grant_fixture_copy(setup[1],3)
		var now := Time.get_ticks_msec()
		var event := source_event("core",family,"core_action",now)
		check(setup[1] in Cards.eligible(player,game.weapon_stats(player),game.DODGE_COOLDOWN_MS),"resolved Core offer "+family)
		var baseline: Dictionary = Build.for_player(player).core.potency_profile.values
		var data := {"enemy":-1,"center":game.enemy_pos, "origin":player.pos, "point":game.enemy_pos,
			"recipients":[1],"start":player.pos,"shapes":[Footprint.area(game.enemy_pos,1.0)]}
		match family:
			"frost":
				Frost.bloom_phase(game,{"center":game.enemy_pos,"owner":1,"affinity_action":event},"open",2,now)
				check(game.enemy_hp==400-Frost.Balance.BLOOM_OPEN_HP-bonus
					and game.leader_brain[Frost.BRITTLE].stacks.size()==2
					and game.leader_brain[Frost.BRITTLE].stacks[0].hp==baseline.rupture_hp,"Frost opening improves damage alone")
			"fire":
				event.publish(game,"core_action","test","leader",now,data)
				check(game.enemy_hp==400-baseline.impact_hp-baseline.tick_hp-bonus,"Ember Wake impact leaves burn intensity unchanged")
			"vital":
				event.publish(game,"core_action","test","",now,data)
				var vitality: Dictionary = player[Rules.Vital.SOURCES]["1/core"]
				check(vitality.until==Rules.Vital.DURATIONS.core+bonus and vitality.regen_per_second==baseline.regen_per_second,"Vital Core extends only grant duration")
			"thorn":
				event.publish(game,"core_action","test","",now,data)
				Clock.advance(game,.74)
				Rules.Thorn.tick(game,Clock.now(game),now+740)
				var field: Dictionary = game.get_meta(Rules.Thorn.FIELDS)[0]
				check(game.enemy_hp==400-baseline.tick_hp-bonus and field.slow==baseline.slow
					and field.until==Rules.Thorn.LIFETIME.core,"Thorn Line only increases Bleed ticks")
			"wood":
				event.publish(game,"core_action","test","",now,data)
				var bark: Dictionary = player[Rules.Wood.GRANTS][0]
				check(bark.until==Rules.Wood.CORE_MS+bonus and bark.admitted==baseline.core_capacity,"Ironbark extends only armor duration")
			"storm":
				event.publish(game,"core_action","test","leader",now,data)
				check(game.enemy_hp==400-baseline.initial-bonus,"Chain Spark uses its improved base damage")
			"spirit":
				event.publish(game,"core_action","test","",now,data)
				check(player[Rules.Spirit.STRIDES]["1/core"].until==Rules.Spirit.STRIDE_MS+bonus
					and player[Rules.Spirit.STRIDES]["1/core"].speed==baseline.speed,"Phantom Step extends stride without speed change")
			"void":
				event.publish(game,"core_action","collapse","",now,data)
				check(game.enemy_hp==400-baseline.collapse-bonus and game.enemy_pos==data.center,"Gravity Well modifies collapse damage alone")


func verify_dew_shelter() -> void:
	reset()
	var water := material("water")
	player.weapon = water
	player.catalyst = material("fire")
	var baseline: Dictionary = Build.for_player(player).core.potency_profile.values
	ally.pos = Vector3(0,0,-1.3)
	at_checkpoint(3)
	var option := {"id":"dew_shelter","rarity":"","amount":effect("dew_shelter")}
	var offer := Cards.new_offer(game,[option],0)
	Cards.state(player).offer = offer
	action(offer.revision,"0")
	check("dew_shelter" not in Cards.eligible(player,game.weapon_stats(player),game.DODGE_COOLDOWN_MS),"claimed Dew Shelter is withheld at later offers")
	var bonus := grant_fixture_copy("dewfall_impact",3)
	game.enemy_hp = 400
	player.pos = Vector3.ZERO
	ally.pos = Vector3(0,0,-1.3)
	var now := Time.get_ticks_msec()
	ally.slow_until = now+5000
	ally.hp = ally.max_hp
	game.garden_action(1,Core.request(game,player,Vector2.UP,1.5))
	var cast: Dictionary = game.get_meta(Core.STATE,{}).get(1,{})
	if cast.is_empty():
		check(false,"Dewfall starts from a real B request")
		return
	Core.tick(game,cast.armed)
	Clock.advance(game,.40)
	Core.tick(game,int(cast.armed)+400)
	var expiry: int = ally.guard_until
	check(expiry==int(cast.armed)+1600 and ally.guard_charges==1 and ally.slow_until==0 and ally.hp==ally.max_hp
		and game.enemy_hp==400-baseline.impact_hp-bonus,"Dewfall grants one 1.2s Ward on a real living ally contact")
	Clock.advance(game,.12)
	Core.tick(game,int(cast.armed)+520)
	check(ally.guard_until==expiry and ally.guard_charges==1,"same wave cannot renew or add an ally Ward")
	var recorded: Array = []
	game.set_meta(Events.RECORD,func(entry):recorded.append(entry))
	game.apply_enemy_hit(1,player,int(cast.armed)+520,1.0,0,game.enemy_pos)
	check(player.guard_charges==0 and recorded.is_empty(),"Dew Shelter blocks as a native Ward with no Catalyst response")
	game.remove_meta(Events.RECORD)


func verify_form_and_catalyst() -> void:
	for family in ["fire","wood","storm","void"]:
		reset()
		var cards_by_family := {"fire":"burning_strikes_heat","wood":"splinter_sharpness","storm":"arc_recharge","void":"drawing_pressure"}
		var bonus := grant_fixture_copy(cards_by_family[family],3)
		var now := Time.get_ticks_msec()
		var event := source_event("form",family,"weapon_contact",now)
		var plain: Dictionary = Build.for_player(player).form.potency_profile.values
		var scout: Dictionary = game.make_scout(1,Vector3(0,0,-1.9),0,0)
		scout.hp = 400
		game.scouts.append(scout)
		Events.contact(game,{Events.CONTEXT:event},-1,now,false,game.enemy_pos,Vector3.FORWARD)
		match family:
			"fire": check(game.enemy_hp==400-plain.tick_hp-bonus,"Fire Form improves Burning applied by the hit")
			"wood": check(game.enemy_hp==400-plain.impact_hp and scout.hp==400-plain.fragment_hp-bonus,"Wood Form improves only fragment damage")
			"storm": check(player[Rules.Storm.FORM_READY]==Rules.Storm.FORM_INTERVAL-bonus and game.enemy_hp==400-plain.arc,"Storm Form reduces only trigger interval")
			"void": check(game.enemy_hp==400-plain.form_hp-bonus,"Void Form increases compression damage")
	for family in ["fire","water","vital","wood"]:
		reset()
		var cards_by_family := {"fire":"catalyst_ember_heat","water":"catalyst_drench_time",
			"vital":"catalyst_vital_regen","wood":"catalyst_bark_time"}
		var bonus := grant_fixture_copy(cards_by_family[family],3)
		player.catalyst = material(family)
		var plain: Dictionary = Build.for_player(player).catalyst.potency_profile.values
		check(cards_by_family[family] in Cards.eligible(player,game.weapon_stats(player),game.DODGE_COOLDOWN_MS),"working Catalyst mapping eligible for "+family)
		game.use_class_skill(1,player,1)
		match family:
			"fire": check(game.leader_brain[Rules.Fire.BURNING]["1/catalyst"].hp==plain.tick_hp+bonus,"Fire Catalyst uses source-owned upgraded burn")
			"water": check(game.leader_brain[Rules.Water.DRENCHED]["1/catalyst"].until==Rules.Water.DURATION_MS+bonus,"Water Catalyst extends only Drenched")
			"vital": check(player[Rules.Vital.SOURCES]["1/catalyst"].regen_per_second==plain.regen_per_second+bonus
				and player[Rules.Vital.SOURCES]["1/catalyst"].bonus_hp==plain.bonus_hp,"Vital Catalyst adds regen without adding maximum health")
			"wood": check(player[Rules.Wood.GRANTS][0].until==Rules.Wood.CATALYST_MS+bonus and player[Rules.Wood.GRANTS][0].admitted==plain.catalyst_capacity,"Wood Catalyst extends only existing Bark Armor")


func class_hit(class_id: int, upgraded: bool) -> int:
	reset(class_id)
	if upgraded:
		grant_fixture_copy(CLASS_CARDS[class_id],3)
	game.use_class_skill(1,player,1)
	return 400-game.enemy_hp


func verify_native() -> void:
	for class_id in [0,1,3]:
		var baseline := class_hit(class_id,false)
		check(baseline>0 and class_hit(class_id,true)==baseline+effect(CLASS_CARDS[class_id],3),
			"real native R for class %d consumes its card damage alone" % class_id)
	reset(2)
	var bonus := grant_fixture_copy("snare_root_time",3)
	var base_skill: Dictionary = Build.for_player(player).class_skills[1].native_skill
	game.use_class_skill(1,player,1)
	var trap: Dictionary = game.trait_events.front()
	game.enemy_pos = trap.position
	var trip: int = trap.next
	game.Traits.tick(game,trip)
	check(game.rooted_until==trip+int(base_skill.bind)+bonus and game.enemy_hp<400,"real Bramble Snare gains only root duration at contact")
	reset(4)
	bonus = grant_fixture_copy("chime_ward_time",3)
	base_skill = Build.for_player(player).class_skills[1].native_skill
	var earliest := Time.get_ticks_msec()+int(base_skill.duration)+bonus
	game.use_class_skill(1,player,1)
	check(ally.guard_until>=earliest and ally.guard_until<=Time.get_ticks_msec()+int(base_skill.duration)+bonus
		and ally.guard_charges==int(base_skill.charges),"Warding Chime gives longer native Ward with the same charges")
	reset()
	var plain_stats: Dictionary = game.weapon_stats(player)
	var faster := grant_fixture_copy("ordinary_weapon_interval",3)
	var hit_gain := grant_fixture_copy("ordinary_weapon_damage",3)
	var before := Time.get_ticks_msec()
	game.strike_enemy(1,player,player.pos)
	var attack: Dictionary = game.projectile_queue.front()
	check(int(attack.stats.interval)==int(plain_stats.interval)-faster and is_equal_approx(float(attack.stats.damage),float(plain_stats.damage)+float(hit_gain)/10.0)
		and player.strike_at>=before+int(plain_stats.interval)-faster,"ordinary strike commits with both weapon cards")
	game.update_projectiles(int(attack.due)+1)
	check(game.enemy_hp==400-int(attack.stats.preview_strike_hp),"the improved ordinary roll is applied on a real weapon contact")
	var recovery := grant_fixture_copy("run_dodge_recovery",3)
	before = Time.get_ticks_msec()
	game.dodge_player(1,Vector2.RIGHT)
	check(player.dodge_at>=before+game.DODGE_COOLDOWN_MS-recovery
		and player.dodge_at<=Time.get_ticks_msec()+game.DODGE_COOLDOWN_MS-recovery,"real dodge timer consumes General recovery")
	var old_hp: float = player.hp
	at_checkpoint(3)
	var extra_health := effect("run_health",3)
	var offer := Cards.new_offer(game,[{"id":"run_health","rarity":"Epic","amount":extra_health}],0)
	Cards.state(player).offer = offer
	action(offer.revision,"0")
	check(player.max_hp==100+extra_health and game.Life.maximum(game,player)==player.max_hp
		and player.hp==old_hp,"acquiring General max health changes the actual maximum without immediate heal")


func verify_echo() -> void:
	reset(1)
	grant_fixture_copy("echoing_growth")
	check("echoing_growth" not in Cards.eligible(player,game.weapon_stats(player),game.DODGE_COOLDOWN_MS),"Weaver Unique cannot return after acquisition")
	game.garden_action(1,Aim.request(game,player,0,Vector2.UP,1.3))
	var bloom: Dictionary = game.trait_events.front()
	game.enemy_pos = bloom.position
	var other: Dictionary = game.make_scout(1,bloom.position+Vector3(.55,0,0),0,0)
	other.hp = 400
	game.scouts.append(other)
	var prior: int = game.enemy_hp
	player.cast_until=0
	var now := Time.get_ticks_msec()
	game.use_class_skill(1,player,1)
	var skill: Dictionary = Build.for_player(player).class_skills[1].native_skill
	var wanted: int = game.Life.Preview.effect_hp(skill.damage)
	check(game.enemy_hp==prior-wanted-10 and other.hp==400-wanted-10,"real Nova in Bloom deals one flat 10 HP pulse per target")
	check(not game.leader_brain.has("marked_until") and not other.has("marked_until")
		and game.rooted_until<=now+int(skill.get("bind",0))+30,"additional pulse does not reproduce Mark or extra control")


func verify_authoring() -> void:
	check(Catalog.DEFINITIONS.size()==28,"authored catalog count")
	for id: String in Catalog.DEFINITIONS:
		var definition: Dictionary = Catalog.DEFINITIONS[id]
		var consumer: Script = load(definition.consumer[0])
		var exists := consumer != null and consumer.get_script_method_list().any(func(method):return str(method.name)==definition.consumer[1])
		check(not str(definition.trigger).is_empty() and exists,"%s identifies its trigger and executable consumer" % id)


func verify_presentation() -> void:
	reset(1)
	var honed := "ordinary_weapon_damage"
	grant_fixture_copy(honed, 0)
	grant_fixture_copy(honed, 0)
	grant_fixture_copy(honed, 1)
	at_checkpoint(3)
	var offer := Cards.state(player)
	offer.offer = Cards.new_offer(game,[{"id":honed,"amount":3,"rarity":"Rare"}],0)
	var choice: Dictionary = Cards.view(game,player,false).choices[0]
	check(choice.description == "Basic attacks gain +3 damage." and choice.scope == "Weapon"
		and choice.preview == "Acquired: 3 copies (+4 damage) → 4 copies (+7 damage)"
		and "2 Common, 1 Uncommon" in choice.detail,"picker uses each actual copy and reports the effective next total")
	var projected := Cards.project_owned(player,game.weapon_stats(player),game.DODGE_COOLDOWN_MS)
	var group: Dictionary = Cards.owned_rows(projected)[0]
	check(group.title == "Honed Strikes ×3" and "2 Common, 1 Uncommon · Weapon" in group.summary
		and "Damage bonus: +4 damage" in group.summary and "Uncommon · +2 damage" in group.tooltip
		and projected[0].applied == 4,"the grouped Tab summary uses the same contribution consumed by combat")
	game.present_checkpoint_cards(1)
	var face: VBoxContainer = game.checkpoint_cards.get_child(0).get_child(0)
	var info := face.get_child(3) as Button
	info.button_pressed = true
	var face_description := face.get_child(2).get_child(0) as Label
	check("Weapon · Rare" == face.get_child(1).text and "2 Common, 1 Uncommon" in face_description.text,
		"the rooted card face shows scope, and its Details button reveals acquired contributions")
	game.toggle_overlay(null)
	var tab: Control = game.overlay.get_node("RunSummary")
	tab.refresh(player)
	var tab_group: VBoxContainer = tab.grouped_cards.get_child(0)
	tab_group.get_child(0).button_pressed = true
	check(tab.grouped_cards.get_child_count() == 1 and "Honed Strikes ×3" == tab_group.get_child(0).text
		and "Uncommon · +2 damage" in tab_group.get_child(2).text and tab_group.get_child(2).visible,
		"the real Tab view groups copies and exposes individual contributions")
	player.catalyst = material("water")
	grant_fixture_copy("catalyst_drench_time")
	offer.offer = Cards.new_offer(game,[{"id":"catalyst_drench_time","amount":250,"rarity":"Common"}],0)
	choice = Cards.view(game,player,false).choices[0]
	check(choice.preview == "Duration bonus: +0.25 s → +0.50 s" and "by 0.25 seconds" in choice.description,
		"picker presents the exact status duration extension")
	player.catalyst = 0
	var inactive: Dictionary = Cards.owned_rows(Cards.project_owned(player,game.weapon_stats(player),game.DODGE_COOLDOWN_MS))[1]
	check("Duration bonus: +0.25 s · Active: +0 s" in inactive.summary
		and "Equip a Water Catalyst" in inactive.summary,"unequipped card stays owned with its real inactive reason")
	for species in game.Seeds.DEFINITIONS.size():
		var seed: Dictionary = game.Seeds.DEFINITIONS[species]
		var plant := Build.planting_description(species,true)
		var actual := Build.for_player(player)
		var core := Build.slot_preview(actual,"core",int(seed.part))
		check("Ordinary:" in plant and "Refined:" in plant and str(core.summary).get_slice("\n",1).get_slice(" · ",0) in plant
			and Build.planting_description(species,false) == game.Seeds.modifier_text(species),
			"planting and Core share the family identity for %s, and preserve legacy text" % seed.id)
		for slot_name: String in Build.SLOTS:
			var ordinary := Build.slot_preview(actual,slot_name,int(seed.part))
			var refined := Build.slot_preview(actual,slot_name,game.Parts.rare_part(species))
			check("Ordinary" in ordinary.summary and "Refined" in refined.summary
				and ("possible upgrade cards" in ordinary.detail or Build.Affinities.for_part(int(seed.part)).supporting_affinities.is_empty()),
				"%s shows actual %s quality and supporting-affinity semantics" % [seed.id,slot_name])

	var seeds: Array = game.Seeds.counts()
	var dewcap: int = game.Seeds.index_of("dewcap")
	seeds[dewcap] = 2
	game.planting_view.begin(0,seeds)
	game.planting_view.grid.get_child(0).pressed.emit()
	check("Water primary affinity · Dewfall" in game.planting_view.details.text
		and "Base growth" in game.planting_view.details.text,"the actual planting panel explains affinity while preserving cultivation details")

	var thorn := material("thorn")
	var weaver_catalyst := Build.slot_preview(Build.for_player(player),"catalyst",thorn)
	focus(0)
	var warden_catalyst := Build.slot_preview(Build.for_player(player),"catalyst",thorn)
	check("Cultivate Bloom" in weaver_catalyst.summary and "Spore Nova" in weaver_catalyst.summary
		and "Thorn Counter · After an actual block" in warden_catalyst.summary and "Root Quake" in warden_catalyst.summary,
		"the same Catalyst distinguishes native class abilities and their triggers before equipping it")
	player.wild = false
	player.pos = game.stage.gate_position()
	game.progress.add_parts(thorn,2)
	var panel: Control = game.loadout_view
	panel.refresh()
	var picker: OptionButton = panel.slots[0]
	var option := picker.get_item_index(thorn)
	if option >= 0:
		picker.select(option)
		picker.item_selected.emit(option)
		check(player.prepared == 0 and "Preview" in panel.slot_summaries[0].text
			and "Thorn Line" in panel.slot_summaries[0].text,"browsing a real material does not equip it")
		panel.slot_equip_buttons[0].pressed.emit()
		check(player.prepared == thorn and not panel.slot_summaries[0].text.begins_with("Preview"),
			"explicit Equip uses the normal transaction and retains the summary")
	else:
		check(false,"Thorn material is available in the real Gate panel")


func verify_attack_speed() -> void:
	var card_id := "ordinary_weapon_interval"
	var grafts = preload("res://expedition_grafts.gd")
	for scenario: Dictionary in [
		{"frame":2, "weapon":1, "base":1150, "ranks":[0,0], "applied":65},
		{"frame":0, "weapon":0, "base":380, "ranks":[0,2], "applied":65},
		{"frame":3, "weapon":0, "base":320, "ranks":[3,0], "applied":5},
	]:
		reset(scenario.frame)
		player.weapon_kind = scenario.weapon
		if scenario.frame == 0:
			player.character.upgrades[0] = 1 << 5  # Historical Quake Resonance subtracts 70 ms.
		player[grafts.STATE] = grafts.Ledger.new(1)
		player.pos = game.battlefield.graft
		var trophy: int = game.Parts.monster_part(0)
		player.carried_parts[trophy] = 2
		for improvement in [{"floor":8, "id":"strike"}, {"floor":16, "id":"cooldown"}]:
			game.encounter_number = improvement.floor
			var altar: Dictionary = grafts.owner_details(player, game.encounter_number)
			game.garden_action(1, grafts.request(altar, improvement.id, "monster_0"))
		check(player.carried_parts[trophy] == 0 and grafts.owner_details(player, 16).revision == 2,
			"the attack speed fixture acquires grafts through real purchases")
		game.toggle_overlay(null)
		var previous: Array[int] = []
		for rank: int in scenario.ranks:
			previous.append(grant_fixture_copy(card_id, rank))
		at_checkpoint(18)
		var stats: Dictionary = game.weapon_stats(player)
		var current_ms: int = scenario.base - previous[0] - previous[1]
		var next_ms: int = current_ms - scenario.applied
		check(int(stats.interval) == scenario.base, "%s resolves its native weapon and learned speed" % stats.name)

		var old_copies := Cards.state(player).copies as Array
		var offer := Cards.new_offer(game,[{"id":card_id, "rarity":"Epic", "amount":scenario.applied}],0)
		Cards.state(player).offer = offer
		var view := Cards.view(game, player, false)
		var choice: Dictionary = view.choices[0]
		var before_speed := "%.2f" % (1000.0 / current_ms)
		var after_speed := "%.2f" % (1000.0 / next_ms)
		var preview := "Attack speed: %s → %s attacks/sec" % [before_speed, after_speed]
		check(choice.enabled and choice.description == "Increases basic attack speed." and choice.preview == preview,
			"Light Grip shows the resolved rate before and after for " + stats.name)
		check("between basic attacks" in choice.detail and Catalog.RARITIES[scenario.ranks[0]] in choice.detail
			and Catalog.RARITIES[scenario.ranks[1]] in choice.detail and "0.23 s" not in choice.detail,
			"Details show the acquired rarities and exact contributions without engine limits")
		game.present_checkpoint_cards(1)
		var face: VBoxContainer = game.checkpoint_cards.get_child(0).get_child(0)
		var face_text: String = face.get_child(2).get_child(0).text
		check(face.get_child(1).text == "Weapon · Epic" and preview in face_text and "minimum" not in face_text.to_lower()
			and "cooldown" not in face_text.to_lower(), "the rooted card face shows rate and omits technical limits")

		var tab: Control = game.overlay.get_node("RunSummary")
		tab.refresh(player)
		var summary := tab.shown as Dictionary
		var before_row := func(row) -> bool:
			return row[0]=="Attack speed" and row[1]==before_speed+" attacks/sec" and "4.35 attacks/sec" in row[2]
		check(summary.totals.any(before_row), "Tab shows the pre-purchase rate and its maximum in a tooltip")
		action(view.revision, "0")
		game.toggle_overlay(null)
		var wanted := previous.duplicate()
		wanted.append(int(scenario.applied))
		check(old_copies.map(func(copy):return copy.amount) == wanted and player.spent == 0,
			"the purchase keeps each original contribution and commits the displayed clipped amount for free")
		tab.refresh(player)
		summary = tab.shown
		check(summary.totals.any(func(row):return row[0]=="Attack speed" and row[1]==after_speed+" attacks/sec")
			and summary.totals.any(func(row):return row[0]=="Dodge cooldown" and " s" in row[1] and "0.35 s" in row[2])
			and summary.totals.any(func(row):return row[0].ends_with(" cooldown") and "class ability cooldown is 1.8 s" in row[2]),
			"Tab matches the post-purchase rate and keeps skill and dodge cooldown limits in seconds")
		var rate_label := func(label) -> bool:
			return label.text==after_speed+" attacks/sec" and "Maximum attack speed" in label.tooltip_text
		check(tab.totals.get_children().any(rate_label), "the real Tab panel keeps the cap in the stat tooltip")
		game.loadout_view.refresh()
		var equipment: String = game.loadout_view.description.text
		check("Attack speed: "+after_speed+" attacks/sec" in equipment and "Class ability cooldown −0.25 s" in equipment,
			"equipment matches the post-purchase attack rate and formats its graft cooldown in seconds")
		game.enemy_hp = 400
		game.enemy_pos = game.battlefield.advance + Vector3.FORWARD
		var now := Time.get_ticks_msec()
		game.strike_enemy(1,player,player.pos)
		var queued: Dictionary = game.projectile_queue.back()
		check(int(queued.stats.interval) == next_ms and player.strike_at >= now+next_ms
			and player.strike_at <= Time.get_ticks_msec()+next_ms and is_equal_approx(float(queued.stats.damage),float(stats.damage)+0.3),
			"the actual basic attack uses the existing timer formula alongside graft damage")
		var count: int = game.projectile_queue.size()
		game.strike_enemy(1,player,player.pos)
		check(game.projectile_queue.size() == count, "the attack timer still rejects an immediate second launch")
		if next_ms == Cards.STRIKE_MIN_MS:
			check(not Cards.eligible(player,game.weapon_stats(player),game.DODGE_COOLDOWN_MS).has(card_id)
				and not Cards.roll(game,player,game.weapon_stats(player)).any(func(option):return option.id==card_id),
				"Light Grip leaves the pool at the interval floor before its copy limit is reached")
		player.erase(grafts.STATE)

	var definition: Dictionary = Catalog.DEFINITIONS[card_id]
	var almost_capped := Cards.choice_view(definition,{"amount":1},[],0,"",231)
	check(almost_capped.preview == "Attack speed: 4.33 → 4.35 attacks/sec",
		"a one-millisecond effective improvement remains visible")
	var dodge: Dictionary = Catalog.DEFINITIONS.run_dodge_recovery
	check(Catalog.effect_text(dodge,45) == "Reduces your dodge cooldown by 0.045 seconds."
		and Catalog.contribution_label(Catalog.DEFINITIONS.arc_recharge) == "Arc trigger interval reduction",
		"dodge uses cooldown terminology and Form's arc trigger keeps its own label")


func run() -> void:
	game = preload("res://world.tscn").instantiate()
	game.set_meta(Rules.META,Rules.ID)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.add_player(2)
	player = game.players[1]
	ally = game.players[2]
	verify_offers()
	verify_core()
	verify_dew_shelter()
	verify_form_and_catalyst()
	verify_native()
	verify_echo()
	verify_authoring()
	verify_presentation()
	verify_attack_speed()
	if failures==0:
		print("PASS: EC01 all 28 real card consumers and offer/lifecycle contracts (%d checks)" % checks)
	quit(int(failures>0))
