extends SceneTree

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const Cooldowns = preload("res://player_cooldowns.gd")

const Weaver = preload("res://weaver_connected_tree.gd")
const Combat = preload("res://weaver_combat.gd")
const Improvements = preload("res://expedition_grafts.gd")
const Build = preload("res://affinity_build.gd")
const Events = preload("res://combat_action_events.gd")
const Profile = preload("res://character_profile.gd")
const Rules = preload("res://combat_ruleset.gd")
const Skills = preload("res://skill_catalog.gd")
const OFFENSE := ["thornbinder","twining_reach","branching_spores","barbed_nova","spore_pressure","bursting_spores"]
const BALANCED := ["bloomcaller","patient_spore","holding_threads","threaded_nova","spore_cycle","symbiotic_nova"]
const DEFENSE := ["silkwarden","silken_gift","clean_weave","sheltering_nova","protective_filaments","silken_canopy"]
const CROSS := ["thornbinder","patient_spore","holding_threads","sheltering_nova","protective_filaments","silken_canopy"]

var game: Node
var player: Dictionary
var ally: Dictionary
var events: Array = []
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL CT02: ",label)


func request(id: String) -> int:
	return Weaver.TREE.REQUEST_OFFSET + Weaver.TREE.nodes.find(Weaver.TREE.node(id))


func graph(path: Array, reached: Dictionary) -> void:
	if path.size() == 6:
		reached[path.back()] = true
		return
	var profile := Profile.blank()
	profile.xp[1] = Weaver.TREE.XP_THRESHOLDS[path.size()]
	profile[Weaver.PROFILE_KEY] = Weaver.TREE.state(path)
	for entry in Weaver.TREE.nodes:
		var follows := path.is_empty() or absi(int(Weaver.TREE.node(path.back()).lane)-int(entry.lane))<=1
		var should_learn: bool = int(entry.tier)==path.size() and follows
		check(Weaver.TREE.refusal(profile,request(entry.id)).is_empty()==should_learn,
			"host adjacency and earned tier for %s to %s" % [path,entry.id])
		if should_learn:
			graph(path+[entry.id],reached)


func profile_contract() -> void:
	var reached := {}
	graph([],reached)
	check(reached.size()==3 and Weaver.TREE.nodes.size()==18,"all three capstones and fifteen nodes are reachable")
	var old := Profile.blank()
	old.xp[1]=570
	old.upgrades[1]=1<<13
	var copy := Profile.normalize(old)
	check(copy==old and not Weaver.TREE.eligible(copy),"historical Weaver focus and XP survive normalization")
	var quarantine := Profile.blank()
	quarantine.quarantine.learned_class_masks = {"weaver":1<<30}
	check(not Weaver.TREE.eligible(quarantine),"unmapped historical bits keep their separate path")
	var legacy: Dictionary = Build.resolve(1,0,[0,0,0],0,copy)
	check(legacy.class_skills[0].native_skill.name=="Cultivate Bloom" and legacy.focus_id=="bloomcaller",
		"old Weaver investments keep their native focus in affinity combat")

	old.upgrades[1]=0
	old[Weaver.PROFILE_KEY]=Weaver.TREE.state(["silkwarden","silken_gift"])
	copy=Profile.normalize(old)
	check(copy==old and Skills.resolve(1,0,copy).name=="Rootbind" and Skills.resolve(1,0,copy,true).name=="Silk Shelter",
		"connected data stays versioned and ordinary combat resolves the historical kit")
	for invalid in [null,{"version":0,"path":[]},Weaver.TREE.state(["thornbinder","silken_gift"]),Weaver.TREE.state(CROSS)]:
		copy[Weaver.PROFILE_KEY]=invalid
		check(Profile.normalize(copy)[Weaver.PROFILE_KEY]==invalid
			and not Build.resolve(1,0,[0,0,0],0,copy).capabilities.class_actions,
			"invalid, disconnected or unearned progression is preserved and class casts refuse")


func choose(id: String) -> void:
	game.send_garden_action("learn_1_%d"%request(id))


func title_and_depart() -> bool:
	var title := preload("res://main_menu.tscn").instantiate()
	root.add_child(title)
	current_scene=title
	title.new_game()
	title.create_character("CT02 Weaver",1,preload("res://character_appearance.gd").DEFAULT)
	var deadline := Time.get_ticks_msec()+6500
	while current_scene==title and Time.get_ticks_msec()<deadline:
		await process_frame
	if current_scene==title:
		check(false,"real title admits isolated Weaver Garden")
		return false
	game=current_scene
	player=game.players[1]
	check(Rules.active(game) and game.has_meta(game.Transactions.SESSION),"guarded affinity world")
	player.pos=game.stage.gate_position()
	choose("patient_spore")
	check(Weaver.TREE.path(player.character).is_empty(),"host refuses a choice before the focus")
	var panel = game.progression_view
	panel.inspected_class=1
	panel.tabs.current_tab=2
	panel.refresh()
	check(panel.nodes.size()==19 and panel.nodes[1].label=="Thornbinder" and panel.nodes[1].available,
		"Weaver screen displays all choices with focus available")
	panel.chosen="class_1_%d"%request("thornbinder")
	panel.refresh()
	panel.learn_button.pressed.emit()
	choose("patient_spore")
	check(Weaver.TREE.path(player.character)==["thornbinder"],"UI selects the focus and host rejects unearned tier")
	player.character.xp[1]=2600
	choose("silken_gift")
	check(Weaver.TREE.path(player.character)==["thornbinder"],"host rejects an Offensive to Defensive jump")
	for index in range(1,CROSS.size()):
		choose(CROSS[index])
	choose("symbiotic_nova")
	choose("twining_reach")
	var config := ConfigFile.new()
	check(config.load(game.local_character.path)==OK
		and config.get_value("character","progress",{}).get(Weaver.PROFILE_KEY,{}).get("path",[])==CROSS
		and Weaver.TREE.path(player.character)==CROSS and player.character.upgrades[1]==0,
		"six guarded profile choices, no second capstone or backfill")
	check(Skills.resolve_in_world(game,1,0,player.character).name=="Interwoven Bind","crossing lanes keeps Thornbinder Q")
	player.pos=game.Stage.HEART
	game.send_garden_action("respec_1")
	check(Weaver.TREE.path(player.character).is_empty() and player.character.xp[1]==2600,"Heart respec preserves earned XP")
	for id in OFFENSE:
		choose(id)
	player.pos=game.stage.gate_position()
	game.map_rng.seed=16
	game.PartyTravel.request(game,1,"depart")
	deadline = Time.get_ticks_msec()+6500
	while (not player.wild or not game.stage._has_experimental_floor()) and Time.get_ticks_msec()<deadline:
		await process_frame
	check(player.wild and game.stage._has_experimental_floor(),"real generated Wilds departure")
	return player.wild and game.stage._has_experimental_floor()


func arena(path: Array) -> void:
	player.character[Weaver.PROFILE_KEY]=Weaver.TREE.state(path)
	player.pos=Vector3.ZERO
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(90)
	player.facing=Vector3.FORWARD
	player.catalyst=0
	player.weapon=0
	player.secondary=0
	player.graft_part=0
	game.encounter.set_hp(-1, 900)
	game.tactics.position=Vector3(0,0,-1.2)
	game.tactics.winding_up=false
	game.enemy_mutations=0
	game.enemy_traits.clear()
	game.tactics.memory.clear()
	game.encounter.clear_scouts()
	game.trait_events.clear()
	game.tactics.rooted_until=0
	for who in [ally,player]:
		who[PlayerVitals.STATE] = who[PlayerVitals.STATE].with_hp(90)
		who.wild=true
		who[Cooldowns.STATE] = who[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0).with_deadline(Cooldowns.R, 0)
		for key in ["cast_until","core_cast_until","guard_until","guard_charges","hurt_until","slow_until"]:
			who[key]=0
		for key in ["subclass_follow","weaver_pressure","weaver_nova_origin","weaver_filaments","warden_holdfast","affinity_ward_claims","weaver_capstone",
			"class_aim","class_aim_distance","prepared_mark_until"]:
			who.erase(key)
	ally.pos=Vector3(8,0,0)
	events.clear()


func scout(at: Vector3) -> Dictionary:
	var enemy: Dictionary=game.make_scout(0,at,game.encounter.scout_count()+1)
	enemy.hp=200
	game.encounter.register_scout(enemy)
	return enemy


func q(point := Vector3(0,0,-1.2)) -> void:
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
	player.class_aim=(point-Vector3(player.pos)).normalized()
	player.class_aim_distance=Vector3(player.pos).distance_to(point)
	game.use_class_skill(1,player,0)
	player.erase("class_aim")
	player.erase("class_aim_distance")


func r() -> void:
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.R, 0)
	game.use_class_skill(1,player,1)


func native_damage() -> int:
	arena([])
	r()
	return 900-game.enemy_health()


func offense(base: int) -> void:
	arena(OFFENSE)
	var tooltip := Skills.describe(Skills.resolve_in_world(game,1,1,player.character))
	check("one enemy it hits" in tooltip and not "damage to a nearby foe" in tooltip,
		"Barbed Nova preview describes a bonus to an existing native hit")
	var near := scout(Vector3(2.1,0,-1.2))
	var extra := scout(Vector3(-2.3,0,-1.2))
	q()
	var now := Time.get_ticks_msec()
	check(game.tactics.rooted_until>now and near.rooted_until>now and game.enemy_health()<900 and game.encounter.hp_for(near)<200,
		"Twining Reach expands Interwoven Bind's native circle")
	check(game.encounter.hp_for(extra)==190 and extra.get("rooted_until",0)==0,"two native contacts and one Branching Spores secondary")
	check(player.has("weaver_pressure") and player.has("subclass_follow"),"actual Q contact prepares both bonuses")
	game.encounter.clear_scouts()
	game.tactics.position=Vector3(8,0,0)
	r()
	check(player.has("subclass_follow") and not player.has("weaver_pressure") and not player.has("weaver_capstone"),
		"empty Nova keeps Barbed, spends Pressure and schedules no burst")
	game.tactics.position=Vector3(0,0,-1.2)
	var prior: int=game.enemy_health()
	r()
	check(prior-game.enemy_health()==base+10,"Barbed Nova boosts the only enemy struck")
	var burst: Dictionary=player.get("weaver_capstone",{})
	check(burst.get("kind")=="weaver_burst","one delayed burst")
	var by_burst := scout(burst.position+Vector3(.55,0,0))
	var native_root: int=game.tactics.rooted_until
	var before: int=game.enemy_health()
	Combat.tick(game,burst.due-1)
	check(game.enemy_health()==before and game.encounter.hp_for(by_burst)==200,"Bursting Spores waits 450 ms")
	var responses := events.size()
	Combat.tick(game,burst.due)
	Combat.tick(game,burst.due+1)
	check(before-game.enemy_health()==10 and game.encounter.hp_for(by_burst)==190 and responses==events.size()
		and game.tactics.rooted_until==native_root and by_burst.get("rooted_until",0)==0,
		"burst damages each eligible target once with no second root, Catalyst or graft response")

	arena(OFFENSE)
	game.tactics.position=Vector3(7,0,0)
	q(game.tactics.position)
	check(not player.has("weaver_pressure"),"a failed Q does not arm Pressure")
	game.tactics.position=Vector3(0,0,-1.2)
	near=scout(Vector3(1,0,-1.2))
	q()
	prior=game.enemy_health()
	var scout_before: int=game.encounter.hp_for(near)
	var floor_number: int = game.encounter_number
	var cast_position: Vector3 = player.pos
	player[Improvements.STATE] = Improvements.Ledger.new(1)
	game.encounter_number=8
	player.pos=game.battlefield.graft
	player.carried_parts[game.Parts.monster_part(17)]=1
	game.garden_action(1,Improvements.request(Improvements.owner_details(player, game.encounter_number),"cinder_field","monster_17"))
	check(Improvements.owner_details(player, game.encounter_number).copies.size()==1,"a real Cinder purchase is active for the Nova scope check")
	game.encounter_number=floor_number
	player.pos=cast_position
	r()
	player.erase(Improvements.STATE)
	check(prior-game.enemy_health()==base+15 and scout_before-game.encounter.hp_for(near)==base+5 and not player.has("native_graft_state"),
		"Pressure applies to every native hit and stacks with one Barbed bonus without starting a graft proc")
	arena(OFFENSE)
	q()
	game.trait_events.resize(24)
	r()
	check(player.get("weaver_capstone",{}).get("kind")=="weaver_burst" and game.trait_events.size()==24,
		"the existing generic queue limit leaves the one scheduled native burst available")
	var obsolete: Dictionary=player.weaver_capstone
	var prior_life: PlayerLifecycle.Life = player[PlayerLifecycle.STATE]
	player[PlayerLifecycle.STATE] = PlayerLifecycle.start_life()
	Combat.tick(game,obsolete.due)
	check(not player.has("weaver_capstone"),"new life invalidates scheduled native damage")
	player[PlayerLifecycle.STATE] = prior_life


func threaded_nova() -> void:
	var ability_names := {"thornbinder":"Interwoven Bind", "bloomcaller":"Cultivate Bloom", "silkwarden":"Silk Shelter"}
	for focus_id: String in ability_names:
		var path := BALANCED.duplicate()
		path[0] = focus_id
		for remaining in [0, 1200, 1900, 5000]:
			arena(path)
			var before := Time.get_ticks_msec()
			var original := before + int(remaining) if remaining > 0 else 0
			player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.R, original)
			q()
			var after := Time.get_ticks_msec()
			var expected := original - Weaver.THREAD_REFUND_MS
			var deadline := int(player[Cooldowns.STATE].deadline(Cooldowns.R))
			var correct := deadline == (expected if remaining > Weaver.THREAD_REFUND_MS else 0)
			if remaining == 1200:
				correct = deadline >= before and deadline <= after
			check(correct and int(player[Cooldowns.STATE].deadline(Cooldowns.Q)) > after and not player.has("subclass_follow"),
				"%s refunds running Nova timer with %d ms left and banks nothing" % [focus_id, remaining])
			var nova := Skills.resolve_in_world(game,1,1,player.character)
			check("Activating %s reduces Spore Nova's remaining cooldown by 1.7 seconds." % ability_names[focus_id] in nova.description,
				"%s appears by name in the active-timer description" % focus_id)

	arena(BALANCED)
	var original := Time.get_ticks_msec() + 5000
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.Q, original)
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.R, original)
	game.use_class_skill(1,player,0)
	check(player[Cooldowns.STATE].deadline(Cooldowns.R) == original and game.trait_events.is_empty(),"a refused focus cast cannot refund the Nova timer")
	arena(BALANCED)
	player.subclass_follow = {"lane":1,"epoch":game.combat_epoch,"life":PlayerLifecycle.generation(player)}
	var before := Time.get_ticks_msec()
	r()
	var cooldown := Skills.Balance.cooldown(Skills.resolve_in_world(game,1,1,player.character),game.weapon_stats(player))
	check(int(player[Cooldowns.STATE].deadline(Cooldowns.R)) >= before + cooldown and not player.has("subclass_follow"),
		"an old prepared discount is discarded without changing the newly assigned cooldown")


func balance(base: int) -> void:
	arena(BALANCED)
	var origin := Vector3(7,0,0)
	game.tactics.position=origin
	q(origin)
	var growth: Dictionary=game.trait_events[0]
	var now := Time.get_ticks_msec()
	check(growth.position.is_equal_approx(origin) and int(growth.until)-int(growth.next)==3000 and game.tactics.rooted_until>=now+600,
		"Patient Spore reaches seven metres and Holding Threads roots on release")
	game.enemy_traits.marked_until=now+4000
	var before: int=game.enemy_health()
	game.Traits.tick(game,growth.next)
	check(before-game.enemy_health()==10 and game.enemy_traits.marked_until==now+4000,
		"affinity Bloom pulse deals native damage and leaves an existing Mark untouched")
	game.enemy_traits.clear()
	game.Traits.tick(game,growth.next)
	check(not game.enemy_traits.has("marked_until"),"affinity Bloom cannot create a native Mark")
	player.pos=Vector3(2,0,0)
	player.catalyst=game.Items.get_item("plant_part_plant_frostbell").legacy_part
	var near := scout(Vector3(2,0,-1.2))
	var both := scout(Vector3(4.9,0,0))
	# Both rings overlap for the next cast. Bloom's original target only
	# becomes eligible through the second ring.
	game.tactics.position=Vector3(6.3,0,0)
	player.weaver_nova_origin.point=Vector3(5,0,0)
	var refund: int=player[Cooldowns.STATE].deadline(Cooldowns.Q)
	var before_relay: int=game.enemy_health()
	now=Time.get_ticks_msec()
	r()
	var nova := events.filter(func(e):return e.kind=="class_action" and e.details.adapter.begins_with("weaver/base/1"))
	check(before_relay-game.enemy_health()==base and game.encounter.hp_for(near)==200-base and game.encounter.hp_for(both)==200-base
		and game.tactics.rooted_until>now and both.rooted_until>now,"Symbiotic native region and overlapping region each apply one damage and root")
	check(nova.size()==1 and nova[0].details.center==player.pos and not nova[0].details.enemies.has(-1),
		"extra area leaves one caster-centered Catalyst response")
	var nova_cooldown := Skills.Balance.cooldown(Skills.resolve_in_world(game,1,1,player.character),game.weapon_stats(player))
	check(player[Cooldowns.STATE].deadline(Cooldowns.Q)==refund-1250 and absi(int(player[Cooldowns.STATE].deadline(Cooldowns.R))-now-nova_cooldown)<=50,
		"Spore Cycle refunds the active focus timer and the next Nova uses its full cooldown")
	check(not player.has("weaver_nova_origin") and not player.has("subclass_follow"),"consumed preparations stay consumed")

	for mode in ["expired","too far","obstructed","empty"]:
		arena(BALANCED)
		var point := Vector3(5.0 if mode!="too far" else 7.0,0,0)
		game.tactics.position=point
		q(point)
		if mode=="expired": player.weaver_nova_origin.until=Time.get_ticks_msec()
		if mode=="obstructed": game.battlefield.barriers.append(Rect2(2.2,-.45,.6,.9))
		if mode=="empty": game.tactics.position=Vector3(-7,0,0)
		refund=player[Cooldowns.STATE].deadline(Cooldowns.Q)
		r()
		check(game.enemy_health()==900 and player[Cooldowns.STATE].deadline(Cooldowns.Q)==refund,"%s origin adds no hit or Q recovery" % mode)
		game.battlefield.barriers.clear()

	for focus in ["thornbinder","silkwarden"]:
		var path := BALANCED.duplicate()
		path[0]=focus
		arena(path)
		game.tactics.position=Vector3(4.5,0,0)
		q(game.tactics.position)
		check(player.get("weaver_nova_origin",{}).get("point",Vector3.INF).is_equal_approx(game.tactics.position),
			"%s records its actual Q location" % focus)
		r()
		check(game.enemy_health()<900,"the recorded %s location remains usable beyond the caster circle" % focus)

	arena(["bloomcaller","patient_spore","branching_spores","barbed_nova","spore_pressure"])
	q()
	check(not player.has("weaver_pressure"),"casting an unrooted Bloom waits for actual damage")
	growth=game.trait_events[0]
	game.Traits.tick(game,growth.next)
	check(player.has("weaver_pressure") and not growth.has("weaver_pressure"),"first damaging pulse arms Pressure exactly once")
	r()
	game.Traits.tick(game,growth.next)
	check(not player.has("weaver_pressure"),"later pulses cannot rearm the same cast")

	arena([])
	game.remove_meta(Rules.META)
	player.erase("combat_ruleset")
	player.character.upgrades[1]=1<<13
	q()
	growth=game.trait_events[0]
	game.Traits.tick(game,growth.next)
	check(game.enemy_traits.has("marked_until"),"legacy Bloomcaller retains its original Mark behavior")
	game.set_meta(Rules.META,Rules.ID)
	player.combat_ruleset=Rules.ID
	player.character.upgrades[1]=0


func defense() -> void:
	arena(DEFENSE)
	ally.pos=Vector3(.6,0,-1.2)
	ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(45)
	player.catalyst=game.Items.get_item("plant_part_rare_frostbell").legacy_part
	var now := Time.get_ticks_msec()
	ally.slow_until=now+6000
	player.slow_until=now+6000
	q()
	var ally_claims: Array=ally.get("affinity_ward_claims",[])
	check(ally.guard_charges==1 and ally.guard_until-player.guard_until==600 and ally_claims.size()==1,
		"Silken Gift extends the lowest-HP Silk Shelter Ward with no redundant grant")
	var gift_tooltip := Skills.describe(Skills.resolve_in_world(game,1,0,player.character))
	check("0.6 s" in gift_tooltip and "2.0s" in gift_tooltip.replace(" ","") and ally.slow_until==0 and player.slow_until==0,
		"focus-specific tooltip and Clean Weave")
	check(game.tactics.rooted_until>now and ally.weaver_filaments.actor==1 and Combat.filaments_until(game,ally,now)>now,
		"native Silk root and source-owned Filaments")
	IncomingPlayerHit.resolve_world(game, 2, PlayerLifecycle.generation(ally), now+20, 4.0, 0, game.tactics.position)
	var blocks := events.filter(func(e):return e.kind=="actual_block")
	check(blocks.size()==1 and blocks[0].source_actor==1 and blocks[0].quality=="refined" and ally.guard_charges==0,
		"one actual block selects the extended source-owned Ward")
	ally.pos=Vector3(5,0,0)
	ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(90)
	ally.hurt_until=0
	IncomingPlayerHit.resolve_world(game, 2, PlayerLifecycle.generation(ally), now+40, 4.0)
	check(ally[PlayerVitals.STATE].hp()==55 and ally.pos==Vector3(5,0,0),"Filaments follows recipients and reduces actual direct damage to 35 of 40")
	ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(90)
	ally.hurt_until=0
	IncomingPlayerHit.resolve_world(game, 2, PlayerLifecycle.generation(ally), now+100, 4.0, 0, Vector3.INF, false)
	check(ally[PlayerVitals.STATE].hp()==50 and events.filter(func(e):return e.kind=="actual_block").size()==1,
		"Filaments does not mitigate hazards or emit a block")

	ally.guard_until=0
	ally.guard_charges=0
	r()
	var canopy: Dictionary=player.weaver_capstone
	check(canopy.kind=="weaver_canopy" and canopy.position==player.pos and canopy.recipients.has(1) and not canopy.recipients.has(2),
		"stationary Canopy covers living allies already in range")
	ally.pos=Vector3(2.9,0,0)
	var canopy_start: int=canopy.until-Weaver.CANOPY_MS
	Combat.tick(game,canopy_start+1)
	check(ally.guard_charges==1 and ally.guard_until==canopy_start+1+2500,"late arrival gets one traveling Ward")
	ally.pos=Vector3(5,0,0)
	ally.hurt_until=0
	IncomingPlayerHit.resolve_world(game, 2, PlayerLifecycle.generation(ally), canopy_start+40, 4.0)
	ally.pos=Vector3(1,0,0)
	Combat.tick(game,canopy_start+80)
	check(ally.guard_charges==0 and canopy.recipients.has(2),"consuming the Ward and re-entering does not grant it again")
	check(events.filter(func(e):return e.kind=="actual_block").size()==1,"unarmed Canopy Ward cannot fire a Catalyst response")
	var filaments_expiry: int=ally.weaver_filaments.until
	ally.hurt_until=0
	ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(90)
	IncomingPlayerHit.resolve_world(game, 2, PlayerLifecycle.generation(ally), filaments_expiry, 4.0)
	check(ally[PlayerVitals.STATE].hp()==50 and Combat.filaments_until(game,ally,filaments_expiry)==0,"Filaments ends at its exact expire time")
	Combat.tick(game,canopy.until)
	check(not player.has("weaver_capstone"),"Canopy expires on time")

	arena(DEFENSE.slice(0,4))
	ally.pos=Vector3(2.9,0,0)
	q()
	check(ally.guard_charges==0,"ally lies outside the Q ward circle")
	r()
	check(ally.guard_charges==1 and ally.guard_until>Time.get_ticks_msec(),"Sheltering Nova grants its independent prepared Ward")
	arena(["bloomcaller","silken_gift"])
	ally.pos=Vector3(0,0,-1.3)
	ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(30)
	q()
	check(ally.guard_charges==1 and player.guard_charges==0,"Silken Gift retains single-ally Ward for Bloomcaller")


func run() -> void:
	profile_contract()
	if not await title_and_depart():
		quit(1)
		return
	game.set_physics_process(false)
	game.battlefield.configure(0,1,0)
	game.battlefield.barriers.clear()
	game.tactics.boss_kind=-1
	game.add_player(2)
	ally=game.players[2]
	game.set_meta(Events.RECORD,func(event):events.append(event))
	var baseline := native_damage()
	offense(baseline)
	threaded_nova()
	balance(baseline)
	defense()
	print("CT02 checks: ",checks)
	if failures==0:
		print("PASS: connected Weaver progression and native spell effects")
	quit(int(failures>0))
