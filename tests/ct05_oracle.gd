extends SceneTree
const WeaponCase = preload("res://tests/support/weapon_attack_case.gd")
const ClassActions = preload("res://native_class_actions.gd")
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const WeaponActions = preload("res://player_weapon_actions.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Cooldowns = preload("res://player_cooldowns.gd")

const Oracle = preload("res://oracle_combat.gd")
const Omens = preload("res://oracle_omens.gd")
const Progression = preload("res://oracle_connected_tree.gd")
const Profile = preload("res://character_profile.gd")
const Rules = preload("res://combat_ruleset.gd")
const Events = preload("res://combat_action_events.gd")
const Attacks = preload("res://enemy_attack.gd")
const Status = preload("res://combat_status.gd")
const RIGHT := ["lifekeeper","kindled_ward","quiet_ground","shared_shelter","merciful_chime","mercys_chorus"]
const MIDDLE := ["leykeeper","long_resonance","anchored_ley","quick_chime","omen_resonance","fates_refrain"]
const LEFT := ["leykeeper","wide_omen","verdicts_toll","barbed_chime","ritual_verdict","sentence_of_dawn"]

var game: Node
var caster: Dictionary
var ally: Dictionary
var checks := 0
var failures := 0
var events: Array = []


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL CT05: ",label)


func verify_graph() -> void:
	var graph := Progression.TREE
	for parent in graph.nodes:
		var profile := Profile.blank()
		profile.xp[4] = 2600
		var selected: Array = []
		for tier in int(parent.tier)+1:
			selected.append(graph.nodes[tier*3+int(parent.lane)].id)
		profile[graph.profile_key] = graph.state(selected)
		for index in graph.nodes.size():
			var candidate: Dictionary = graph.nodes[index]
			var permitted: bool = candidate.tier==selected.size() and absi(candidate.lane-parent.lane)<=1
			check(graph.refusal(profile,graph.REQUEST_OFFSET+index).is_empty()==permitted,"adjacency, progression and one capstone")
	var profile := Profile.blank()
	check(graph.learn(profile,65).is_empty() and not graph.learn(profile,67).is_empty(),"0 XP grants focus only")
	profile.xp[4] = 50
	check(graph.learn(profile,67).is_empty() and Profile.normalize(profile)==profile,"cross-lane choices persist in versioned profile")
	check(game.Skills.resolve(4,0,profile).name=="Guiding Bell" and game.Skills.resolve(4,1,profile).name=="Warding Chime","lane choice preserves focus and R")
	profile.xp[4] = 2600
	profile.upgrades[4] = 1 << 12
	check(Profile.normalize(profile)==profile and not graph.eligible(profile)
		and not preload("res://affinity_build.gd").resolve(4,0,[0,0,0],profile).capabilities.class_actions,
		"historical Oracle investment is retained without executing retired abilities")
	profile.upgrades[4] = 0
	profile[graph.profile_key] = graph.state(["omenreader","kindled_ward"])
	check(not graph.valid(profile) and Profile.normalize(profile)[graph.profile_key]==profile[graph.profile_key],"invalid paths retained for review")


func reset_field() -> void:
	ExpeditionCase.set_world(game, {"combat_epoch": game.participation.epoch() + (1)})
	game.battlefield = preload("res://battlefield.gd").new()
	game.encounter.clear_scouts()
	game.trait_events.clear()
	game.weapon_attacks.clear()
	game.combat_events.clear()
	game.enemy_traits.clear()
	game.tactics.memory.clear()
	game.monster_rewards = game.MonsterRewards.new()
	game.tactics.position = Vector3(2,0,0)
	game.encounter.set_hp(-1, 300)
	game.enemy_kind = 0
	game.enemy_mutations = 0
	game.tactics.boss_kind = -1
	game.tactics.winding_up = false
	game.tactics.ready_at = 0
	game.tactics.engaged = false
	game.tactics.haste_until = 0
	game.tactics.rooted_until = 0
	game.encounter_rewarded = false
	for id in game.players:
		var player: Dictionary = game.players[id]
		Oracle.clear(player)
		player[Protection.STATE] = player[Protection.STATE].clear_guard()
		player.erase("subclass_follow")
		player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0).with_deadline(Cooldowns.R, 0)
		player[Protection.STATE] = player[Protection.STATE].clear_expedition()
		player[Conditions.STATE] = player[Conditions.STATE].clear_all()
		for key in ["lost_health",
				"core_ready_at","core_cast_until","cast_until","weapon","secondary","catalyst","weapon_kind"]:
			player[key] = 0
		player[WeaponActions.STATE] = player[WeaponActions.STATE].with_ready_at(0)
		ExpeditionCase.set_membership(game, player, true)
		player[PlayerLifecycle.STATE] = player[PlayerLifecycle.STATE].clear_inactive()
		player[PlayerVitals.STATE] = PlayerVitals.Health.new(100.0,100)
		player.pos = Vector3.ZERO if id==1 else Vector3(-6,0,1)
		player.facing = Vector3.RIGHT
		player.aim_direction = Vector3.RIGHT
		player.class_aim = Vector3.RIGHT
		player.class_aim_distance = 1.0
		player.mouse_aim = true
	events.clear()


func prepare(path: Array) -> void:
	reset_field()
	caster.frame = 4
	caster.character = Profile.blank()
	caster.character.active_class = 4
	caster.character.xp[4] = Progression.Model.XP_THRESHOLDS[path.size()-1]
	caster.character[Progression.PROFILE_KEY] = Progression.TREE.state(path)


func entry_for_each_class() -> void:
	var build = preload("res://affinity_build.gd")
	var qs := ["Root Anchor","Cultivate Bloom","Luring Snare","Veil Passage","Guiding Bell"]
	var rs := ["Root Quake","Spore Nova","Bramble Snare","Siphon Cut","Warding Chime"]
	var original_binding := InputMap.action_get_events("class_skill")
	var rebound := InputEventKey.new()
	rebound.physical_keycode = KEY_K
	InputMap.action_erase_events("class_skill")
	InputMap.action_add_event("class_skill", rebound)
	var preview_effects := [
		["prime your next hit","plant an anchor","directional shield"],
		["Damage and root","pulses damage","roots enemies and wards allies"],
		["Tracked Prey","decoy","briar trap"],
		["recover health","2.7 s","most wounded nearby living ally"],
		["Foreboding","Guided Strike","Second Breath"],
	]
	caster.character=Profile.blank()
	for class_id in qs.size():
		reset_field()
		for player in game.players.values():
			ExpeditionCase.set_membership(game, player, false)
		check(game.participation.reset_run(),"fresh Garden fixture clears completed synthetic party holds")
		caster.prepared=0
		caster.prepared_secondary=0
		caster.prepared_catalyst=0
		caster.pos=game.stage.gate_position()
		game.garden_action(1,"class_%d"%class_id)
		check(caster.frame==class_id and caster.character.active_class==class_id,"changing to an unplayed class uses its own focus choice: "+game.status)
		var graph: RefCounted = game.Classes.connected_tree(class_id)
		check(graph.level(caster.character)==1 and caster.character.xp[class_id]==0
			and graph.focus(caster.character).is_empty() and not build.departure_refusal(caster).is_empty()
			and not ExpeditionCase.Transitions.admit(game, 1,caster),"fresh class requires an explicit starting focus")
		var before_preview: Dictionary = caster.character.duplicate(true)
		UIFixture.control(game,"loadout_view").refresh()
		check(UIFixture.control(game,"loadout_view").focus_options.visible and UIFixture.control(game,"loadout_view").depart_button.disabled,"starting focus is offered in crafting UI")
		for lane in preview_effects[class_id].size():
			var preview: Label = UIFixture.control(game,"loadout_view").focus_previews[lane]
			var candidate: Dictionary = before_preview.duplicate(true)
			candidate[graph.profile_key] = graph.state([graph.nodes[lane].id])
			var ability_name: String = game.Skills.resolve_in_world(game,class_id,0,candidate).name
			check(preview.visible and preview.text.begins_with(ability_name + " · ") and "cooldown" in preview.text
				and preview_effects[class_id][lane] in preview.text,"class %d lane %d shows its named starting ability and effect before learning" % [class_id,lane])
		check(caster.character==before_preview,"previewing focus choices leaves the actual profile untouched")
		UIFixture.control(game,"loadout_view").focus_buttons[1].pressed.emit()
		check(graph.path(caster.character).size()==1 and build.departure_refusal(caster).is_empty()
			and caster.character.xp[class_id]==0,"0 XP focus learns through actual host action: "+game.status)
		UIFixture.control(game,"loadout_view").refresh()
		check(not UIFixture.control(game,"loadout_view").focus_options.visible and not UIFixture.control(game,"loadout_view").depart_button.disabled,"chosen focus unlocks native departure")
		ExpeditionCase.set_membership(game, caster, true)
		caster.pos=Vector3.ZERO
		caster.erase("cast_until")
		caster.class_aim_distance=1.5
		check(game.Skills.resolve_in_world(game,class_id,0,caster.character).name==qs[class_id]
			and game.Skills.resolve_in_world(game,class_id,1,caster.character).name==rs[class_id],"native focused Q/R with three empty slots")
		ClassActions.cast_world(game, 1, 0)
		var benefits: Array[bool] = [caster.has("warden_anchor"),
			game.trait_events.any(func(field):return field.kind=="growth"),
			game.trait_events.any(func(field):return field.kind=="snare"),
			caster.has("reaper_veil_momentum"),caster.has(Omens.STATE)]
		check(int(caster[Cooldowns.STATE].deadline(Cooldowns.Q))>Time.get_ticks_msec() and benefits[class_id],"native starting Q applies its effect")
		game.tactics.position = caster.pos + Vector3(.7,0,0)
		ClassActions.cast_world(game, 1, 1)
		check(int(caster[Cooldowns.STATE].deadline(Cooldowns.R))>Time.get_ticks_msec(),"native R casts with no equipped parts")
	for class_id in qs.size():
		check(game.Classes.connected_tree(class_id).path(caster.character).size()==1,"switching classes preserves each chosen focus")
	InputMap.action_erase_events("class_skill")
	for event in original_binding:
		InputMap.action_add_event("class_skill", event)


func cast(slot: int) -> void:
	ClassActions.cast_world(game, 1, slot)


func enemy_hit(id: int, now: int, slow := 0, direct := true) -> void:
	var player: Dictionary = game.players[id]
	player[Conditions.STATE] = player[Conditions.STATE].clear_grace()
	preload("res://frost_combat.gd").with_attacker(game,-1,IncomingPlayerHit.resolve_world.bind(game, id, PlayerLifecycle.generation(player), now, 1.0, slow, Vector3.INF, direct))


func record(body: Dictionary, key: String, now: int, source := 0) -> Dictionary:
	return Omens.strongest(game,body,key,now,source)


func basic_omens() -> void:
	prepare(["omenreader"])
	game.tactics.winding_up=true
	cast(0)
	var now := Time.get_ticks_msec()
	check(game.enemy_health()==280 and not record(game.tactics.memory,Progression.FOREBODING,now).is_empty(),"wind-up punishment retained and surviving enemy gets Foreboding")
	check(game.enemy_traits.get("marked_until",0)==0,"native Omen does not apply a generic Mark")
	var foe: Dictionary = game.make_scout(0,Vector3(2,0,.3),11)
	game.encounter.register_scout(foe)
	Attacks.lock(game,foe,"swipe",caster.pos,now+500)
	caster[Cooldowns.STATE] = caster[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
	cast(0)
	check(not foe.attack.has(Omens.FOREBODING_MS) and not record(foe,Progression.FOREBODING,now).is_empty(),"already-started attack does not consume Foreboding")
	var old: Dictionary = foe.attack
	Omens.begin_attack(game,foe,old,now)
	check(not old.has(Omens.FOREBODING_MS),"same attack cannot collect a new curse")
	Attacks.lock(game,foe,"swipe",caster.pos,now+550)
	var base: int = game.Director.recovery(game,int(game.Enemies.get_kind(0).recovery))
	check(int(foe.attack.get(Omens.FOREBODING_MS,0))==350 and record(foe,Progression.FOREBODING,now).is_empty(),"next committed scout attack consumes Foreboding once")
	preload("res://scout_behavior.gd").release(game, foe,game.Enemies.get_kind(0),now+550)
	check(int(foe.ready)==now+550+base+350,"specific attack receives exact added recovery")
	prepare(["leykeeper"])
	ally.pos=Vector3(.2,0,0)
	ally[Conditions.STATE] = ally[Conditions.STATE].with_slow_until(Time.get_ticks_msec()+5000)
	cast(0)
	var timer := Time.get_ticks_msec()
	check(game.enemy_health()==300 and game.tactics.position.x<2.0 and ally[Conditions.STATE].slow_until_ms()==0
		and record(ally,Progression.GUIDED_STRIKE,timer).source==1 and caster.has(Omens.STATE),"Guiding Bell retains pull/cleanse and grants ally and self Portent")
	game.tactics.ready_at=timer+800
	var due := int(game.tactics.ready_at)
	WeaponCase.start(game,1,caster.pos)
	WeaponCase.advance(game,timer+550)
	check(game.enemy_health()<300 and game.tactics.ready_at==due+300 and record(caster,Progression.GUIDED_STRIKE,timer+550).is_empty(),"ordinary weapon contact consumes the Portent for 300 ms recovery")
	check(not record(ally,Progression.GUIDED_STRIKE,timer).is_empty(),"same cast keeps separate recipient opportunities")
	prepare(["lifekeeper"])
	ally.pos=Vector3(.5,0,0)
	caster[PlayerVitals.STATE] = caster[PlayerVitals.STATE].with_hp(50)
	cast(0)
	now=Time.get_ticks_msec()
	check(int(caster[PlayerVitals.STATE].hp()) in range(58,63) and game.trait_events.any(func(field):return field.kind=="tide" and field.power==0)
		and not record(ally,Progression.SECOND_BREATH,now).is_empty(),"Sanctuary keeps its opening heal/cleanse and grants full-health allies Second Breath")
	var entrant: Dictionary=game.players[9]
	entrant.pos=Vector3(.4,0,0)
	entrant[Conditions.STATE] = entrant[Conditions.STATE].with_slow_until(now+1800)
	game.Traits.tick(game,now+1)
	check(entrant[Conditions.STATE].slow_until_ms()==0 and record(entrant,Progression.SECOND_BREATH,now+1).is_empty(),"late entrant only receives field cleanse")
	IncomingPlayerHit.resolve_world(game, 8, PlayerLifecycle.generation(ally), now+10, 1.0, 0, Vector3.INF, false)
	check(ally[PlayerVitals.STATE].hp()==90 and not record(ally,Progression.SECOND_BREATH,now+10).is_empty(),"hazard hit does not spend the Blessing")
	game.Life.down(game,1,caster)
	Omens.grant(game,1,"lifekeeper",999,8,ally,Progression.SECOND_BREATH,3000,now+10)
	check(int(record(ally,Progression.SECOND_BREATH,now+10).cast)!=999,"fallen Oracle cannot issue fresh grants")
	enemy_hit(8,now+30)
	check(ally[PlayerVitals.STATE].hp()==86 and record(ally,Progression.SECOND_BREATH,now+30).is_empty(),"surviving recipient consumes 6 HP Blessing after caster falls")


func nodes_and_chime() -> void:
	prepare(LEFT)
	var skill: Dictionary = game.Skills.resolve_in_world(game,4,0,caster.character)
	check(is_equal_approx(float(skill.radius),3.15),"Wide Omen adds 0.55 m to the native Q")
	var foe: Dictionary = game.make_scout(0,Vector3(2.1,0,.2),22)
	game.encounter.register_scout(foe)
	var other_hp := int(game.encounter.hp_for(foe))
	cast(0)
	check(game.enemy_health()==290 and game.encounter.hp_for(foe)==other_hp,"Verdict's Toll adds exactly one native damage hit to Guiding Bell")
	var timer := Time.get_ticks_msec()
	WeaponCase.start(game,1,caster.pos)
	WeaponCase.advance(game,timer+500)
	var before := int(game.enemy_health())
	check(caster.has(Oracle.RITUAL) and before<290,"a close ordinary hit prepares Ritual Verdict")
	caster[Cooldowns.STATE] = caster[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
	cast(0)
	check(game.enemy_health()==before-20 and not caster.has(Oracle.RITUAL),"Ritual and Verdict share one Q target and consume once")
	cast(1)
	check(game.enemy_health()==before-45 and caster[Protection.STATE].charge_count()==1,"Sentence works on a Leykeeper, alongside Barbed Chime and native Ward")
	prepare(MIDDLE)
	skill=game.Skills.resolve_in_world(game,4,0,caster.character)
	check(is_equal_approx(float(skill.range),7.05),"Long Resonance adds 1.25 m")
	timer=Time.get_ticks_msec()
	cast(0)
	var omen := record(caster,Progression.GUIDED_STRIKE,timer)
	check(int(omen.get("until",0))>=timer+5500 and game.tactics.rooted_until>=timer+650,"Resonance extends only the Portent while Anchored Ley roots")
	cast(1)
	check(int(caster[Cooldowns.STATE].deadline(Cooldowns.R))-timer in range(5300,5330),"Quick Chime subtracts 1.7 seconds from R")
	for focus in Progression.FOCUS_OMENS:
		var path := MIDDLE.duplicate()
		path[0]=focus
		prepare(path)
		ally.pos=Vector3(.3,0,0)
		caster[PlayerVitals.STATE] = caster[PlayerVitals.STATE].with_hp(50)
		cast(0)
		var effect: String = Progression.FOCUS_OMENS[focus]
		var recipient: Dictionary = game.tactics.memory if focus=="omenreader" else ally
		timer=Time.get_ticks_msec()
		var original := record(recipient,effect,timer)
		var old_hp := int(caster[PlayerVitals.STATE].hp())
		var old_damage := int(game.enemy_health())
		var old_pos: Vector3 = game.tactics.position
		var zones: int = game.trait_events.size()
		cast(1)
		var repeated := record(recipient,effect,timer)
		check(not original.is_empty() and not repeated.is_empty() and repeated.cast!=original.cast
			and game.enemy_health()==old_damage and game.tactics.position==old_pos and caster[PlayerVitals.STATE].hp()==old_hp
			and game.trait_events.size()==zones,"Fate's Refrain bestows only the equipped focus Omen")
	prepare(RIGHT)
	ally.pos=Vector3(.3,0,0)
	caster[PlayerVitals.STATE] = caster[PlayerVitals.STATE].with_hp(50)
	ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(50)
	ally[Conditions.STATE] = ally[Conditions.STATE].with_slow_until(Time.get_ticks_msec()+5000)
	cast(0)
	timer=Time.get_ticks_msec()
	check(caster[Protection.STATE].charge_count()==1 and ally[Protection.STATE].charge_count()==0,"Kindled Ward tie selects the lower actor ID")
	check(ally[Conditions.STATE].slow_until_ms()==0 and not record(ally,Progression.QUIET_GROUND,timer).is_empty(),"Quiet Ground cleanses and grants one-use protection")
	cast(1)
	check(int(ally[Protection.STATE].guard_until_ms())-timer in range(2000,2030) and ally[Protection.STATE].charge_count()==1,"Shared Shelter extends the ordinary Ward without a second charge")
	var healed_from := int(ally[PlayerVitals.STATE].hp())
	enemy_hit(8,timer+25,1600)
	check(ally[PlayerVitals.STATE].hp()==healed_from+6 and ally[Conditions.STATE].slow_until_ms()==0 and not record(ally,Progression.QUIET_GROUND,timer+25).is_empty(),
		"Merciful Chime heals its actual block and leaves Quiet Ground intact")
	enemy_hit(8,timer+40,1600)
	check(ally[PlayerVitals.STATE].hp()==healed_from+4 and ally[Conditions.STATE].slow_until_ms()==0 and record(ally,Progression.MERCY,timer+40).is_empty()
		and not record(ally,Progression.SECOND_BREATH,timer+40).is_empty(),"strongest recovery wins once and Quiet Ground blocks the first Slow")
	enemy_hit(8,timer+800,1600)
	check(ally[PlayerVitals.STATE].hp()==healed_from and ally[Conditions.STATE].slow_until_ms()==timer+2400,"second hit spends remaining Breath and can apply Slow")
	var without_chime := int(ally[PlayerVitals.STATE].hp())
	ally[Protection.STATE] = ally[Protection.STATE].grant(Time.get_ticks_msec()+1600,1,Time.get_ticks_msec(),game.participation.epoch())
	enemy_hit(8,timer+820)
	check(ally[PlayerVitals.STATE].hp()==without_chime,"ordinary Ward from a different source does not heal")
	prepare(["omenreader","wide_omen","verdicts_toll","barbed_chime","ritual_verdict","sentence_of_dawn"])
	cast(0)
	before=int(game.enemy_health())
	cast(1)
	check(game.enemy_health()==before-35,"Sentence adds 10 HP to its own Foreboding target on the same hit")


func coexistence() -> void:
	prepare(["lifekeeper"])
	ally.pos=Vector3(.3,0,0)
	var other: Dictionary = game.players[9]
	other.frame=4
	other.character=Profile.blank()
	other.character[Progression.PROFILE_KEY]=Progression.TREE.state(["lifekeeper"])
	other.pos=Vector3(.4,0,0)
	cast(0)
	ClassActions.cast_world(game, 9, 0)
	var now := Time.get_ticks_msec()
	var breath := record(ally,Progression.SECOND_BREATH,now)
	check(int(breath.get("source",0))==1 and not record(ally,Progression.SECOND_BREATH,now,9).is_empty(),"two Oracle grants tie by actor ID")
	check(record(ally,Progression.SECOND_BREATH,now+3100).is_empty(),"expiry is exclusive")
	other.character[Progression.PROFILE_KEY]=Progression.TREE.state(["leykeeper"])
	other[Cooldowns.STATE] = other[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
	ClassActions.cast_world(game, 9, 0)
	check(not record(ally,Progression.GUIDED_STRIKE,now,9).is_empty() \
		and not record(ally,Progression.SECOND_BREATH,now,1).is_empty(),"different Omens from two Oracles coexist")
	Status.sync(game,now)
	check(game.combat_events_snapshot().any(func(e):return e.shape==Progression.SECOND_BREATH and e.combo==8),"detailed status advertises the accepted Blessing")
	enemy_hit(8,now+10)
	enemy_hit(8,now+250)
	check(ally[PlayerVitals.STATE].hp()==86 and record(ally,Progression.SECOND_BREATH,now+250,9).is_empty(),"overlapping copies grant one shared opportunity")
	ExpeditionCase.set_world(game, {"combat_epoch": game.participation.epoch() + (1)})
	check(record(caster,Progression.SECOND_BREATH,now+250).is_empty(),"floor identity invalidates former effects")
	prepare(LEFT)
	ally.pos=Vector3(.4,0,0)
	caster.catalyst=game.Parts.DEFINITIONS.find_custom(func(entry):return entry.id=="plant:void_willow")
	check(caster.catalyst>0,"actual Void material equipped with native Guiding Bell pull")
	var build := preload("res://affinity_build.gd").for_player(caster)
	var native: Dictionary=build.class_skills[0].native_displacement
	check(is_equal_approx(float(native.pull),1.2),"Leykeeper's authored pull stays authoritative with a Void Catalyst")
	cast(0)
	check(events.filter(func(row):return row.kind=="class_action" and row.source_actor==1).size()==1
		and events.all(func(row):return row.kind!="weapon_contact"),"native Q and its Omen produce one Catalyst action, without a Form hit")
	check(not game.has_meta(Rules.Void.PENDING),"Void does not enqueue a conflicting pull for Guiding Bell")


func run() -> void:
	game=preload("res://world.tscn").instantiate()
	game.progress.path="user://release-fixtures/ct05-garden.cfg"
	game.local_character.path="user://release-fixtures/ct05-character.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	caster=game.players[1]
	for peer in [8,9,10]:
		game.add_player(peer)
	ally=game.players[8]
	game.set_meta(Events.RECORD,func(row):events.append(row))
	verify_graph()
	entry_for_each_class()
	basic_omens()
	nodes_and_chime()
	coexistence()
	game.queue_free()
	await process_frame
	if failures==0:
		print("PASS: CT05 all fifteen nodes, five first-run focuses and native Omen ownership (%d checks)" % checks)
	quit(int(failures>0))
