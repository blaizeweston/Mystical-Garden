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

const Progression = preload("res://reaper_connected_tree.gd")
const Reaper = preload("res://reaper_combat.gd")
const Ranger = preload("res://ranger_combat.gd")
const Profile = preload("res://character_profile.gd")
const Skills = preload("res://skill_catalog.gd")
const Rules = preload("res://combat_ruleset.gd")
const Events = preload("res://combat_action_events.gd")
const Grafts = preload("res://native_grafts.gd")
const Improvements = preload("res://expedition_grafts.gd")
const Frost = preload("res://frost_combat.gd")
const Field = preload("res://battlefield.gd")
const Surface = preload("res://assets/terrain_m02/wilds_play_surface.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Core = preload("res://core_combat.gd")
const OFFENSE := ["blood_harvester","long_edge","rending_cut","barbed_siphon","deaths_due","feast_of_thorns"]
const FEAST := ["blood_harvester","long_edge","rending_cut","barbed_siphon","siphon_tempo","feast_of_thorns"]
const DANCE := ["veilwalker","lingering_veil","grave_grip","swift_siphon","siphon_tempo","veil_dance"]
const DEFENSE := ["gravekeeper","grave_ward","clear_the_veil","wake_ward","grave_offering","last_rites"]
const RITES := ["gravekeeper","grave_ward","clear_the_veil","wake_ward","siphon_tempo","last_rites"]

var game: Node
var player: Dictionary
var ally: Dictionary
var events: Array = []
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL CT04: ",description)

func verify_tree() -> void:
	var graph := Progression.TREE
	for previous in graph.nodes:
		var character := Profile.blank()
		character.xp[3]=2600
		var selected: Array = []
		for tier in int(previous.tier)+1:
			selected.append(graph.nodes[tier*3+int(previous.lane)].id)
		character[Progression.PROFILE_KEY]=graph.state(selected)
		for index in graph.nodes.size():
			var candidate: Dictionary = graph.nodes[index]
			var allowed: bool = candidate.tier==selected.size() and absi(candidate.lane-previous.lane)<=1
			check(graph.refusal(character,graph.REQUEST_OFFSET+index).is_empty()==allowed,"earned adjacent tier and one capstone")
	var current := Profile.blank()
	check(graph.learn(current,65).is_empty() and not graph.learn(current,67).is_empty(),"level one permits focus only")
	current.xp[3]=50
	check(graph.learn(current,67).is_empty() and Skills.resolve(3,0,current).name=="Veil Passage"
		and Skills.resolve(3,1,current).name=="Siphon Cut" and Profile.normalize(current)==current,
		"cross-lane path retains Q, R and versioned profile data")
	var old := Profile.blank()
	old.xp[3]=2600
	for bit in [0,2,4,6,9,11]:
		old.upgrades[3] |= 1 << bit
	check(Profile.normalize(old)==old and not graph.eligible(old),"historical learned mask and XP remain data without obsolete skill replacement execution")
	current[Progression.PROFILE_KEY]=graph.state(["gravekeeper","long_edge"])
	check(not graph.valid(current) and Profile.normalize(current)[Progression.PROFILE_KEY]==current[Progression.PROFILE_KEY],
		"incompatible connected data is preserved for review")

func prepare(nodes: Array, origin := Vector3.ZERO, target := Vector3(2,0,0)) -> void:
	ExpeditionCase.set_world(game, {"combat_epoch": game.participation.epoch() + (1)})
	game.battlefield = preload("res://battlefield.gd").new()
	game.remove_meta(Rules.Void.PENDING)
	game.encounter.clear_scouts()
	game.effect_timeline.clear_native()
	game.weapon_attacks.clear()
	game.combat_events.clear()
	game.enemy_traits.clear()
	game.tactics.memory.clear()
	game.monster_rewards = game.MonsterRewards.new()
	game.tactics.position=target
	game.encounter.set_hp(-1, 300)
	game.enemy_kind=0
	game.enemy_growth=0
	game.enemy_mutations=0
	game.tactics.rooted_until=0
	game.tactics.boss_kind=-1
	game.tactics.winding_up=false
	game.encounter_rewarded=false
	player.character=Profile.blank()
	player.character.xp[3]=2600
	player.character.active_class=3
	player.character[Progression.PROFILE_KEY]=Progression.TREE.state(nodes)
	player.frame=3
	player.pos=origin
	player.facing=Vector3.RIGHT
	player.class_aim=Vector3.RIGHT
	player.class_aim_distance=2.0
	player.aim_direction=Vector3.RIGHT
	player.mouse_aim=true
	player.weapon_kind=0
	player.weapon=0
	player.secondary=0
	player.catalyst=0
	player.graft_part=0
	player.grave_charges=0
	Grafts.clear(player)
	player.erase(Improvements.STATE)
	Rules.Spirit.clear(player)
	for peer in game.players:
		var recipient: Dictionary = game.players[peer]
		recipient[Cooldowns.STATE] = Cooldowns.Timers.new()
		recipient[Protection.STATE] = recipient[Protection.STATE].clear_expedition()
		recipient[Conditions.STATE] = recipient[Conditions.STATE].clear_all()
		for key in ["lost_health",
				"cast_until","core_ready_at","core_cast_until"]:
			recipient[key]=0
		recipient[WeaponActions.STATE] = recipient[WeaponActions.STATE].with_ready_at(0)
		recipient[Protection.STATE] = recipient[Protection.STATE].clear_guard()
		ExpeditionCase.set_membership(game, recipient, peer in [1,8])
		recipient[PlayerLifecycle.STATE] = recipient[PlayerLifecycle.STATE].clear_inactive()
		recipient[PlayerVitals.STATE] = PlayerVitals.Health.new(70.0 if peer==1 else 20.0,100)
		if peer!=1:
			recipient.pos=Vector3(-7,0,3)
	events.clear()

func cast(slot: int) -> void:
	ClassActions.cast_world(game, 1, slot)

func scout(point: Vector3, hp := 300, summoned := false) -> Dictionary:
	var foe: Dictionary = game.make_scout(0,point,game.encounter.scout_count()+1)
	foe.hp=hp
	foe.summoned=summoned
	game.encounter.register_scout(foe)
	return foe

func enqueue() -> Dictionary:
	player[WeaponActions.STATE] = player[WeaponActions.STATE].with_ready_at(0)
	WeaponCase.start(game,1,player.pos)
	return game.weapon_attacks.views().back()

func fire_melee() -> int:
	var shot := enqueue()
	WeaponCase.advance(game,int(shot.due))
	return int(shot.stats.preview_strike_hp)

func part(id: String) -> int:
	return game.Parts.DEFINITIONS.find_custom(func(entry):return entry.id==id)

func focuses() -> void:
	prepare(["blood_harvester","long_edge"],Vector3.ZERO,Vector3(3.1,0,0))
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(40)
	cast(0)
	check(game.enemy_health()==280 and player[PlayerVitals.STATE].hp()>=45 and player[PlayerVitals.STATE].hp()<=47,"Long Edge extends Blood Harvest and the native self-drain stays capped per contact")
	prepare(["blood_harvester","lingering_veil"])
	var added := scout(Vector3(1,0,1))
	var summoned := scout(Vector3(1,0,-1),300,true)
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(40)
	cast(0)
	check(game.enemy_health()==280 and game.encounter.hp_for(added)==280 and game.encounter.hp_for(summoned)==280 and player[PlayerVitals.STATE].hp()>=57 and player[PlayerVitals.STATE].hp()<=59,
		"Lingering Veil adds one counted drain contact, with summons ignored by native sustain")
	check("additional contact" in Skills.resolve(3,0,player.character).description,"Blood Harvest has its own tooltip")

	prepare(["veilwalker","lingering_veil"],Vector3.ZERO,Vector3(6.5,0,0))
	player.class_aim_distance=10.0
	cast(0)
	check(is_equal_approx(player.pos.x,6.05) and game.enemy_health()==280 and player.has(Reaper.MOMENTUM)
		and not game.enemy_traits.has("core_strike_mark"),"Veil Passage moves 6.05 m and arms self Momentum after native landing damage")
	check("maximum legal travel" in Skills.resolve(3,0,player.character).description,"Veilwalker tooltip explains travel")

	prepare(["gravekeeper","lingering_veil"])
	ally.pos=Vector3(0,0,2.9)
	var now := Time.get_ticks_msec()
	cast(0)
	check(game.enemy_health()==280 and ally[Protection.STATE].charge_count()==1 and ally[Protection.STATE].guard_until_ms()-now>=1900 and ally[Protection.STATE].guard_until_ms()-now<1960
		and player[Protection.STATE].charge_count()==0,"Lingering Veil gives the lowest ratio ally a 1.9 s Ward outside the damage cone")
	var info := Skills.describe(Skills.resolve(3,0,player.character))
	check("Grave Sweep" in info and "Ward by 0.5 s" in info and "1.9s" in info,"Gravekeeper tooltip states actual extended duration")
	prepare(["gravekeeper","grave_ward"])
	ally.pos=Vector3(0,0,1)
	cast(0)
	check(ally[Protection.STATE].charge_count()==2 and ally[Protection.STATE].claim_count()==1,"Grave Ward uses a single native grant for two charges on hit")
	now=Time.get_ticks_msec()
	IncomingPlayerHit.resolve_world(game, 8, PlayerLifecycle.generation(ally), now, 2)
	IncomingPlayerHit.resolve_world(game, 8, PlayerLifecycle.generation(ally), now+1, 2)
	check(ally[PlayerVitals.STATE].hp()==20 and ally[Protection.STATE].charge_count()==0,"both native charges block with no second activation")
	prepare(["gravekeeper","grave_ward"],Vector3.ZERO,Vector3(-2,0,0))
	cast(0)
	check(game.enemy_health()==300 and player[Protection.STATE].charge_count()==1 and player[Protection.STATE].claim_count()==1,
		"solo empty Grave Sweep still grants the learned one-charge Ward")
	prepare(["veilwalker","grave_ward"],Vector3.ZERO,Vector3(4,0,0))
	ally.pos=Vector3(2,0,1)
	cast(0)
	check(ally[Protection.STATE].charge_count()==1 and player[Protection.STATE].charge_count()==0,"Veilwalker Grave Ward uses the landing footprint")

func momentum() -> void:
	prepare(["veilwalker"],Vector3.ZERO,Vector3(2.7,0,0))
	var early := enqueue()
	cast(0)
	var before: int = game.enemy_health()
	WeaponCase.advance(game,int(early.due))
	check(before-game.enemy_health()==int(early.stats.preview_strike_hp) and player.has(Reaper.MOMENTUM),
		"a melee attack committed before Q cannot take Momentum even if it lands after the move")
	game.tactics.position=player.pos+Vector3.RIGHT
	player.aim_direction=Vector3.BACK
	var miss := enqueue()
	before=game.enemy_health()
	WeaponCase.advance(game,int(miss.due))
	check(game.enemy_health()==before and player.has(Reaper.MOMENTUM),"miss keeps the original preparation and contributes no damage")
	player.aim_direction=Vector3.RIGHT
	game.tactics.position=player.pos+Vector3.RIGHT
	var at := Time.get_ticks_msec()
	apply_frost(-1,at)
	Ranger.track(game,8,ally,-1,78,at)
	before=game.enemy_health()
	var roll := fire_melee()
	check(before-game.enemy_health()==roll+20 and not player.has(Reaper.MOMENTUM) and Frost.state(Frost.body(game,-1),at).stacks.size()==1
		and not game.enemy_traits.has(Ranger.PREY),"ordinary contact spends Momentum and Tracked Prey while preserving an independent Frost status")
	prepare(["veilwalker"],Vector3.ZERO,Vector3(2.7,0,0))
	cast(0)
	var expired := enqueue()
	player[Reaper.MOMENTUM].until=int(expired.due)
	before=game.enemy_health()
	WeaponCase.advance(game,int(expired.due))
	check(before-game.enemy_health()==int(expired.stats.preview_strike_hp),"Momentum must be valid at contact as well as commitment")

	prepare(["veilwalker"],Vector3.ZERO,Vector3(1,0,0))
	player.secondary=part("plant:ghost_fern")
	player.weapon=part("plant:ghost_fern")
	fire_melee()
	check(player.get(Rules.Spirit.FOLLOW,{}).get("phase")=="prepared","actual Spirit Form contact prepares Flowing Strikes")
	var action := Core.request(game,player,Vector2.RIGHT,2.2)
	game.garden_action(1,action)
	check(player.pos.x>0.1 and Reaper.ready(game,player,Reaper.MOMENTUM,Time.get_ticks_msec()).is_empty()
		and player.get(Rules.Spirit.FOLLOW,{}).get("phase")=="prepared",
		"Phantom Step neither creates native Momentum nor passes through the occupied melee lane (%s, %s, %s)"
		% [player.pos,player.get(Rules.Spirit.FOLLOW,{}).get("phase"),game.status])
	player.core_cast_until=0
	player.class_aim=Vector3.BACK
	player.class_aim_distance=1.5
	cast(0)
	check(player.has(Reaper.MOMENTUM) and player.get(Rules.Spirit.FOLLOW,{}).get("phase")=="ready","the actual Veil move readies Spirit separately")
	game.tactics.position=player.pos+Vector3.RIGHT
	player.aim_direction=Vector3.RIGHT
	before=game.enemy_health()
	roll=fire_melee()
	check(before-game.enemy_health()==roll+23 and not player.has(Reaper.MOMENTUM) and not player.has(Rules.Spirit.FOLLOW),
		"one ordinary strike spends the native +10 and the independent ordinary Spirit +13")
	prepare(["veilwalker"],Vector3.ZERO,Vector3(3,0,0))
	player.weapon_kind=1
	cast(0)
	var farther := scout(Vector3(3.7,0,.25))
	before=game.enemy_health()
	roll=fire_melee()
	check(before-game.enemy_health()==roll+10 and game.encounter.hp_for(farther)==300-roll,"one Momentum spend covers only the first eligible scythe contact")
	prepare(["veilwalker"],Vector3.ZERO,Vector3(2,0,0))
	player.class_aim_distance=.1
	cast(0)
	check(player.pos==Vector3.ZERO and player[Cooldowns.STATE].deadline(Cooldowns.Q)==0 and Reaper.ready(game,player,Reaper.MOMENTUM,Time.get_ticks_msec()).is_empty(),
		"refused movement produces no new Momentum or cooldown")
	prepare([])
	player.character.upgrades[3]=1<<13
	cast(0)
	check(not game.enemy_traits.has("core_strike_mark") and Reaper.ready(game,player,Reaper.MOMENTUM,Time.get_ticks_msec()).is_empty()
		and player[Cooldowns.STATE].deadline(Cooldowns.Q)==0,"historical branch investment refuses combat until explicit conversion")

func siphon_effects() -> void:
	prepare(OFFENSE.slice(0,4))
	cast(0)
	check(game.enemy_health()==270,"Rending Cut works against a single Q victim without an echo")
	game.tactics.position=Vector3(6,0,0)
	cast(1)
	check(player[Cooldowns.STATE].deadline(Cooldowns.R)==0 and player[Reaper.SIPHON].nodes==["barbed_siphon"],"refused R preserves the earned Barbed preparation")
	game.tactics.position=Vector3(2,0,0)
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(20)
	cast(1)
	check(game.enemy_health()==240 and player[PlayerVitals.STATE].hp()>=29 and player[PlayerVitals.STATE].hp()<=31 and not player.has(Reaper.SIPHON),"Barbed Siphon adds exactly 10 without multiplying the native drain")

	prepare(FEAST)
	player.catalyst=part("plant:frostbell")
	cast(0)
	var first := scout(Vector3(2.5,0,.2))
	var second := scout(Vector3(3,0,.2),10)
	var third := scout(Vector3(3.5,0,.2))
	apply_frost(0,Time.get_ticks_msec())
	Ranger.track(game,8,ally,0,78,Time.get_ticks_msec())
	var q_deadline: int = player[Cooldowns.STATE].deadline(Cooldowns.Q)
	var before := events.size()
	cast(1)
	var r_events := events.slice(before).filter(func(event):return event.kind=="class_action")
	check(game.enemy_health()==230 and game.encounter.hp_for(first)==290 and game.encounter.hp_for(second)==0 and game.encounter.hp_for(third)==300 and player.grave_charges==0,
		"Barbed and Feast stack on the primary, with only two nearest secondaries and no Death’s Due prerequisite")
	check(player[Cooldowns.STATE].deadline(Cooldowns.Q)==q_deadline-1250 and r_events.size()==1 and r_events[0].details.enemies==[-1]
		and Frost.state(first,Time.get_ticks_msec()).stacks.size()==1 and first.traits.has(Ranger.PREY),"Tempo and one actual Catalyst honor the native impact, secondaries leave independent Frost and Tracked Prey alone")
	prepare(OFFENSE)
	cast(0)
	first=scout(Vector3(2.5,0,1),1)
	second=scout(Vector3(3,0,1),1)
	cast(1)
	check(game.encounter.hp_for(first)==0 and game.encounter.hp_for(second)==0 and player.grave_charges==0,"secondary Feast kills cannot produce charges even with Death’s Due")

	prepare(DANCE,Vector3.ZERO,Vector3(2.9,0,0))
	cast(0)
	player.pos=Vector3.ZERO
	q_deadline=player[Cooldowns.STATE].deadline(Cooldowns.Q)
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.DODGE, Time.get_ticks_msec()+2000)
	var now := Time.get_ticks_msec()
	cast(1)
	check(is_equal_approx(player.pos.x,1.5) and game.enemy_health()==260 and player[Cooldowns.STATE].deadline(Cooldowns.DODGE)<=now+20
		and player[Cooldowns.STATE].deadline(Cooldowns.Q)==q_deadline-1250 and player[Cooldowns.STATE].deadline(Cooldowns.R)-now>=4800 and player[Cooldowns.STATE].deadline(Cooldowns.R)-now<4860,
		"Swift, Tempo and Veil Dance coexist and use native terrain movement before the R hit")
	prepare(DANCE,Vector3(-1.36,0,0),Vector3(1.15,0,0))
	var water := Shape.shape("river","water",PackedVector2Array([Vector2(-1,-4),Vector2(1,-4),Vector2(1,4),Vector2(-1,4)]))
	var boundary := Shape.shape("arena","arena",PackedVector2Array([Vector2(-8,-8),Vector2(8,-8),Vector2(8,8),Vector2(-8,8)]))
	var field := Field.new()
	field.ground=Surface.new({},{"masses":[],"rocks":[],"plants":[],"water":[water],"crossings":[],
		"boundary":{"playable":boundary,"water":[water],"rim":[]}},1.75)
	game.battlefield=field
	player.class_aim=Vector3.LEFT
	cast(0)
	player.pos=Vector3(-1.36,0,0)
	player.class_aim=Vector3.RIGHT
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.DODGE, Time.get_ticks_msec()+3000)
	now=Time.get_ticks_msec()
	cast(1)
	check(is_equal_approx(player.pos.x,-1.36) and game.enemy_health()==280 and player[Cooldowns.STATE].deadline(Cooldowns.DODGE)<=now+20
		and field.projectile_clear(player.pos,game.tactics.position,.03),"water stops Veil Dance but the legal Siphon Cut still recovers dodge")
	prepare(DANCE)
	cast(0)
	player.pos=Vector3.ZERO
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.DODGE, Time.get_ticks_msec()+2000)
	var paused_dodge: int=player[Cooldowns.STATE].deadline(Cooldowns.DODGE)
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[Rect2(.85,-1,.3,2)])
	cast(1)
	check(player.pos==Vector3.ZERO and player[Cooldowns.STATE].deadline(Cooldowns.DODGE)==paused_dodge and player[Cooldowns.STATE].deadline(Cooldowns.R)==0 and player.has(Reaper.SIPHON),
		"a solid-cover refusal preserves every Q preparation and cannot recover dodge")
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
	ExpeditionCase.set_world(game, {"combat_epoch": game.participation.epoch() + (1)})
	cast(1)
	check(player.pos==Vector3.ZERO and player[Cooldowns.STATE].deadline(Cooldowns.DODGE)==paused_dodge,"an old-floor Veil Dance preparation cannot move or reward the player")

func support() -> void:
	prepare(DEFENSE)
	ally.pos=Vector3(0,0,2.8)
	ally[Conditions.STATE] = ally[Conditions.STATE].with_slow_until(Time.get_ticks_msec()+3000)
	ally.unrelated_until=123456789
	cast(0)
	check(ally[PlayerVitals.STATE].hp()==28 and ally[Conditions.STATE].slow_until_ms()==0 and ally.unrelated_until==123456789,
		"Grave Offering heals for 8 and Clear the Veil clears only Slow")
	prepare(DEFENSE,Vector3.ZERO,Vector3(-2,0,0))
	ally.pos=Vector3(0,0,2.8)
	cast(0)
	check(ally[PlayerVitals.STATE].hp()==20 and ally[Protection.STATE].charge_count()==1,"empty valid Q wards, with no damage-triggered Offering heal")
	prepare(DANCE)
	var rooted := scout(Vector3(2,0,1))
	game.tactics.rooted_until=Time.get_ticks_msec()+4000
	var longest: int = game.tactics.rooted_until
	var now := Time.get_ticks_msec()
	cast(0)
	check(game.tactics.rooted_until==longest and rooted.rooted_until>=now+650 and rooted.rooted_until<now+700,
		"Grave Grip roots survivors without shortening a stronger existing root")

	prepare(RITES)
	var second: Dictionary=game.players[9]
	var third: Dictionary=game.players[10]
	for peer in [ally,second,third]:
		ExpeditionCase.set_membership(game, peer, true)
	ally.pos=Vector3(2,0,1)
	second.pos=Vector3(2,0,-1)
	third.pos=Vector3(3,0,-1)
	cast(0)
	cast(1)
	check(ally[PlayerVitals.STATE].hp()==26 and second[PlayerVitals.STATE].hp()==26 and third[PlayerVitals.STATE].hp()==20 and player[PlayerVitals.STATE].hp()>=79 and player[PlayerVitals.STATE].hp()<=81,
		"Last Rites functions without Grave Offering and selects only the first two visible lowest ratios")
	check(ally[Protection.STATE].charge_count()==2 and second[Protection.STATE].charge_count()==1 and third[Protection.STATE].charge_count()==1,
		"Wake Ward remains a distinct benefit without stacking onto the stronger native grant")
	prepare(RITES)
	ally.pos=Vector3(2,0,2.8)
	ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(1)
	second.pos=Vector3(2,0,1)
	ExpeditionCase.set_membership(game, second, true)
	second[PlayerLifecycle.STATE] = second[PlayerLifecycle.STATE].fall()
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[Rect2(1.6,1.7,.8,.8)])
	cast(0)
	cast(1)
	check(player[PlayerVitals.STATE].hp()>=85 and player[PlayerVitals.STATE].hp()<=87 and ally[PlayerVitals.STATE].hp()==1 and second[PlayerVitals.STATE].hp()==20 and ally[Protection.STATE].charge_count()==0,
		"a sole eligible Reaper gets 6 plus drain, with blocked and fallen recipients excluded")

func charges_and_void() -> void:
	prepare(OFFENSE)
	scout(Vector3(7,0,0))
	game.encounter.set_hp(-1, 1)
	cast(0)
	check(game.enemy_health()==0 and player.grave_charges==1,"immediate native Q earns a class charge without a graft")
	game.encounter.set_hp(-1, 300)
	player.weapon_kind=2
	var roll := fire_melee()
	check(game.enemy_health()==300-roll-10 and player.grave_charges==0,"ordinary extended melee spends one charge with no legacy Momentum bonus")
	game.encounter.set_hp(-1, 1)
	cast(1)
	check(game.enemy_health()==0 and player.grave_charges==1,"immediate native R earns a charge")

	prepare(OFFENSE,Vector3.ZERO,Vector3(1,0,0))
	scout(Vector3(7,0,0))
	player[Improvements.STATE] = Improvements.Ledger.new(1)
	ExpeditionCase.set_world(game, {"encounter_number": 8})
	player.pos=game.battlefield.graft
	player.carried_parts[part("monster:pallbearer")]=1
	game.garden_action(1,Improvements.request(Improvements.owner_details(player, game.participation.floor()),"funeral_charges","monster_15"))
	player.pos=Vector3.ZERO
	check(Improvements.owner_details(player, game.participation.floor()).copies.size()==1,"Funeral Petal is bought through the authoritative shrine")
	game.encounter.set_hp(-1, 1)
	fire_melee()
	check(player.grave_charges==1 and Grafts.graft_charges(player)==1,"both sources earn independent charges from one actual native kill")
	game.encounter.set_hp(-1, 300)
	game.tactics.position=Vector3.RIGHT
	roll=fire_melee()
	check(game.enemy_health()==300-roll-10 and player.grave_charges==0 and Grafts.graft_charges(player)==1,"class spends first with at most one +10 per contact")
	game.encounter.set_hp(-1, 300)
	game.tactics.position=Vector3.RIGHT
	roll=fire_melee()
	check(game.enemy_health()==300-roll-10 and Grafts.grave_count(player)==0,"graft spends its own charge once when the class pool is empty")
	player.grave_charges=2
	Grafts.counters(player,"monster:pallbearer").grave_charges=1
	game.tactics.position=Vector3.RIGHT
	game.encounter.set_hp(-1, 1)
	fire_melee()
	check(game.enemy_health()==0 and player.grave_charges==2 and Grafts.graft_charges(player)==1,
		"a killing contact refills its opened class slot at the shared cap")
	var expired := enqueue()
	ally.pos=player.pos
	game.Life.down(game,1,player)
	check(player.grave_charges==2 and not player.has(Grafts.STATE) and game.Life.revive(game,8,1),"revival keeps native class charges and clears the graft pool")
	game.encounter.set_hp(-1, 300)
	WeaponCase.advance(game,int(expired.due))
	check(game.enemy_health()==300 and player.grave_charges==2,"a queued attack from the prior life cannot spend the revived charge")
	game.reset_encounter()
	check(player.grave_charges==2 and not player.has(Grafts.STATE) and Improvements.owner_details(player, game.participation.floor()).copies[0].id=="funeral_charges",
		"floor reset retains class charges and acquired graft identity while clearing graft counters")
	ExpeditionCase.Transitions.return_member(game, player)
	check(Grafts.grave_count(player)==0,"expedition return clears both charge pools")

	prepare(OFFENSE)
	var summon := scout(Vector3(1,0,0),1,true)
	cast(0)
	check(game.encounter.hp_for(summon)==0 and Grafts.grave_count(player)==0,"summoned enemy deaths do not generate class charges (HP %s, charges %s)" % [game.encounter.hp_for(summon),Grafts.grave_count(player)])
	var victim := scout(Vector3(6,0,0),1)
	player.grave_charges=1
	preload("res://frost_combat.gd").damage(game,1,1,10,Time.get_ticks_msec())
	check(game.encounter.hp_for(victim)==0 and player.grave_charges==1,"Core and affinity secondary damage cannot spend or award native charges")

	prepare(["blood_harvester"])
	player.catalyst=part("plant:void_willow")
	player.graft_part=part("monster:lantern_lure")
	var current: Dictionary = game.weapon_stats(player)
	check(player.graft_part>0 and not current.has("pull"),"a retired single-slot graft cannot contribute pull in affinity combat")
	cast(0)
	check(game.enemy_health()<280 and game.has_meta(Rules.Void.PENDING),"Void response remains independent of the retired slot")

func run() -> void:
	verify_tree()
	game=preload("res://world.tscn").instantiate()

	game.progress.path="user://release-fixtures/ct04-garden.cfg"
	game.local_character.path="user://release-fixtures/ct04-character.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	player=game.players[1]
	for peer in [8,9,10]:
		game.add_player(peer)
	ally=game.players[8]
	player.frame=3
	game.set_meta(Events.RECORD,func(event):events.append(event))
	focuses()
	momentum()
	siphon_effects()
	support()
	charges_and_void()
	game.queue_free()
	await process_frame
	if failures==0:
		print("PASS: CT04 all fifteen nodes, three focuses, separate event ownership and compatibility (%d checks)" % checks)
	quit(int(failures>0))


func apply_frost(target: int, now: int) -> void:
	var material:=preload("res://affinity_build.gd").slot("form",game.Parts.index_of("plant:frostbell"))
	var event:=Events.begin(game,8,"form",material,material.potency_profile.values,["weapon_contact"],now+4000)
	check(event!=null,"independent Frost source has a valid current-life event")
	if event!=null:Frost.apply(game,event,target,1,now)
