extends SceneTree
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const WeaponActions = preload("res://player_weapon_actions.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const Cooldowns = preload("res://player_cooldowns.gd")

const Progression = preload("res://ranger_connected_tree.gd")
const Ranger = preload("res://ranger_combat.gd")
const Frost = preload("res://frost_combat.gd")
const Rules = preload("res://combat_ruleset.gd")
const Profile = preload("res://character_profile.gd")
const Skills = preload("res://skill_catalog.gd")
const Aim = preload("res://ability_aim.gd")
const Events = preload("res://combat_action_events.gd")
const Field = preload("res://assets/terrain_m02/experimental/experiment_wilds.gd")
const Surface = preload("res://assets/terrain_m02/wilds_play_surface.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const OFFENSE := ["wildstalker","wider_pattern","splinter_ambush","barbed_snare","follow_through","double_draw"]
const BALANCED := ["snarekeeper","long_draw","briar_tread","quick_reset","snarecraft","bramble_corridor"]
const DEFENSE := ["wayfarer","trail_ward","clear_trail","safe_passage","fleetfoot","escape_route"]

var game: Node
var ranger: Dictionary
var ally: Dictionary
var events: Array = []
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL CT03: ",message)

func verify_tree() -> void:
	var tree := Progression.TREE
	for previous in tree.nodes:
		var profile := Profile.blank()
		profile.xp[2] = 2600
		var path: Array = []
		for tier in int(previous.tier)+1:
			path.append(tree.nodes[tier*3+int(previous.lane)].id)
		profile[Progression.PROFILE_KEY] = tree.state(path)
		for index in tree.nodes.size():
			var option: Dictionary = tree.nodes[index]
			var allowed: bool = option.tier == path.size() and absi(option.lane-previous.lane)<=1
			check(tree.refusal(profile,tree.REQUEST_OFFSET+index).is_empty()==allowed,"adjacent earned tier, no return or seventh selection")
	var fresh := Profile.blank()
	check(tree.learn(fresh,66).is_empty() and not tree.learn(fresh,68).is_empty(),"focus is earned at level one, next tier requires XP")
	fresh.xp[2]=50
	check(tree.learn(fresh,68).is_empty() and Skills.resolve(2,0,fresh).name=="Briar Retreat"
		and Skills.resolve(2,1,fresh).name=="Bramble Snare","cross-lane choice preserves the original Q and R")
	check(Profile.normalize(fresh)==fresh and Skills.resolve(2,0,fresh).name=="Briar Retreat","one versioned path preserves the chosen starting Q")
	var old := Profile.blank()
	old.xp[2]=570
	old.upgrades[2]=1<<12
	check(Profile.normalize(old)==old and not tree.eligible(old),"historical focus investments and XP remain intact without legacy Mark execution")
	fresh[Progression.PROFILE_KEY] = tree.state(["wayfarer","wider_pattern"])
	check(not tree.valid(fresh) and Profile.normalize(fresh)[Progression.PROFILE_KEY]==fresh[Progression.PROFILE_KEY],
		"invalid connected data is retained for review")

func prepare(path: Array, origin := Vector3.ZERO, enemy := Vector3(2,0,0)) -> void:
	ExpeditionCase.set_world(game, {"combat_epoch": game.participation.epoch() + (1)})
	game.battlefield = preload("res://battlefield.gd").new()
	game.encounter.clear_scouts()
	game.trait_events.clear()
	game.projectile_queue.clear()
	game.combat_events.clear()
	game.enemy_traits.clear()
	game.tactics.position = enemy
	game.encounter.set_hp(-1, 300)
	game.enemy_kind = 0
	game.enemy_growth = 0
	game.enemy_mutations = 0
	game.tactics.rooted_until = 0
	game.tactics.winding_up = false
	game.encounter_rewarded = false
	ranger.character = Profile.blank()
	ranger.character.xp[2] = 2600
	ranger.character[Progression.PROFILE_KEY] = Progression.TREE.state(path)
	ranger.pos = origin
	ranger.facing = Vector3.RIGHT
	ranger.class_aim = Vector3.RIGHT
	ranger.class_aim_distance = 5.0
	ranger.aim_direction = Vector3.RIGHT
	ranger.mouse_aim = false
	ranger[Protection.STATE] = ranger[Protection.STATE].clear_expedition()
	ranger.weapon_kind = 0
	ranger.weapon = 0
	ranger.secondary = 0
	ranger.catalyst = 0
	ranger[PlayerVitals.STATE] = PlayerVitals.Health.new(70.0,90)
	ranger[PlayerLifecycle.STATE] = ranger[PlayerLifecycle.STATE].clear_inactive()
	ranger[Cooldowns.STATE] = ranger[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
	ranger[Cooldowns.STATE] = ranger[Cooldowns.STATE].with_deadline(Cooldowns.R, 0)
	ranger[WeaponActions.STATE] = ranger[WeaponActions.STATE].with_ready_at(0)
	ranger.cast_until = 0
	ally.pos = Vector3(-8,0,2)
	ally[Protection.STATE] = ally[Protection.STATE].clear_expedition()
	ally[PlayerVitals.STATE] = PlayerVitals.Health.new(20.0,90)
	ally[PlayerLifecycle.STATE] = ally[PlayerLifecycle.STATE].clear_inactive()
	events.clear()

func cast(slot: int) -> void:
	game.use_class_skill(game.HOST,ranger,slot)

func trap(slot: int) -> Dictionary:
	for event in game.trait_events:
		if event.kind == "snare" and event.owner == game.HOST and event.skill.slot == slot:
			return event
	return {}

func scout(point: Vector3) -> Dictionary:
	var foe: Dictionary = game.make_scout(0,point,game.encounter.scout_count()+1)
	foe.hp = 300
	game.encounter.register_scout(foe)
	return foe

func tracked_and_offense() -> void:
	prepare(OFFENSE)
	var second := scout(Vector3(4,0,.34))
	var first_skill := Skills.resolve(2,0,ranger.character)
	check(first_skill.name=="Hunter’s Salvo" and is_equal_approx(first_skill.width,.86) and first_skill.limit==3,"Wider Pattern keeps the Salvo cap")
	cast(0)
	check(game.enemy_health()==270 and game.encounter.hp_for(second)==280,"Splinter Ambush adds 10 HP to only the first damaged Salvo target")
	var prey: Dictionary = game.enemy_traits.get(Ranger.PREY,{})
	check(prey.get("owner")==game.HOST and not game.Traits.target_state(game,0).has(Ranger.PREY)
		and ranger.has(Ranger.FOLLOW) and ranger.has(Ranger.DOUBLE),"Salvo tracks one survivor and prepares both timed effects")
	if prey.is_empty():
		return
	var now := int(prey.until)-Progression.PREY_MS
	apply_frost(-1,now)
	check(not Ranger.track(game,game.HOST,ranger,-1,100,now+1) and Frost.state(Frost.body(game,-1),now).stacks.size()==1,
		"another preparation cannot overwrite Tracked Prey or an independent botanical status")
	game.apply_weapon_hit(ally,-1,ally.pos,{"damage":0.0,"affinity_hp":3,"knockback":-.35,"core_hit":true,"trait_secondary":true},now)
	check(game.enemy_traits.has(Ranger.PREY) and Frost.state(Frost.body(game,-1),now).stacks.size()==1,"secondary damage cannot consume Tracked Prey or the independent Frost status")
	game.apply_weapon_hit(ally,-1,ally.pos,{"damage":1.0,"knockback":-.35,"ranger_direct_hit":true},now+2)
	check(game.enemy_health()==247 and not game.enemy_traits.has(Ranger.PREY) and Frost.state(Frost.body(game,-1),now).stacks.size()==1,
		"one ally direct hit consumes Tracked Prey without consuming the independent Frost status")
	game.apply_weapon_hit(ally,-1,ally.pos,{"damage":1.0,"knockback":-.35,"ranger_direct_hit":true},now+3)
	check(game.enemy_health()==237,"the consumed prey adds damage only once")
	check(Ranger.track(game,game.HOST,ranger,-1,101,now) and Ranger.active_prey(game,game.enemy_traits,now+2700).is_empty(),
		"Tracked Prey expires after 2.7 seconds")

	check(ranger.has(Ranger.SNARE),"Q prepares Barbed Snare")
	for index in 24:
		game.trait_events.append({"kind":"hit"})
	cast(1)
	check(trap(1).is_empty() and ranger.has(Ranger.SNARE) and ranger[Cooldowns.STATE].deadline(Cooldowns.R)==0 and "could not be set" in game.status,
		"full queue refuses R and preserves its preparation and cooldown")
	game.trait_events.clear()
	game.tactics.position = Vector3(5,0,0)
	cast(1)
	var placed := trap(1)
	check(not placed.is_empty() and not ranger.has(Ranger.SNARE) and game.enemy_health()==237,"placing Barbed Snare does not deal damage")
	if not placed.is_empty():
		game.Traits.tick(game,int(placed.next))
		game.Traits.tick(game,int(placed.next)+50)
		check(game.enemy_health()==217 and not placed.has("ranger_bonus_hp"),"first actual R contact gets the bonus only once")

	for weapon in 3:
		prepare(OFFENSE,Vector3.ZERO,Vector3(2.6,0,0))
		ranger.weapon_kind = weapon
		ranger.secondary = 11
		cast(0)
		game.strike_enemy(game.HOST,ranger,ranger.pos)
		check(not game.projectile_queue.is_empty(),"ordinary attack queued from weapon %d" % weapon)
		if game.projectile_queue.is_empty():
			continue
		var main: Dictionary = game.projectile_queue.front()
		var rolled: int = main.stats.preview_strike_hp
		game.update_projectiles(int(main.release))
		var extras: Array = game.projectile_queue.filter(func(shot):return shot.get("ranger_secondary",false))
		check(extras.size()==1 and main.get("ranger_follow_hp")==10 and not ranger.has(Ranger.DOUBLE) and not ranger.has(Ranger.FOLLOW)
			and not extras[0].has("ranger_follow_hp") and extras[0].stats.affinity_hp==roundi(rolled*.5)
			and not extras[0].stats.has(Events.CONTEXT) and extras[0].remaining==1 and extras[0].aim==main.aim,
			"both bonuses captured at launch, half original roll and isolated second projectile for weapon %d" % weapon)
		var before: int = game.enemy_health()
		game.update_projectiles(int(main.due)+1)
		check(game.enemy_health()<before and events.filter(func(item):return item.kind=="weapon_contact").size()==1,
			"only the original projectile publishes direct Form contact")
	prepare(OFFENSE)
	cast(0)
	ranger.mouse_aim = true
	ranger.aim_direction = Vector3.LEFT
	game.strike_enemy(game.HOST,ranger,ranger.pos)
	if not game.projectile_queue.is_empty():
		var main: Dictionary = game.projectile_queue.front()
		var before: int = game.enemy_health()
		game.update_projectiles(int(main.release))
		game.update_projectiles(int(main.release)+2000)
		check(game.enemy_health()==before and not ranger.has(Ranger.FOLLOW) and not ranger.has(Ranger.DOUBLE),"miss spends both launched preparations")
	prepare(OFFENSE)
	cast(0)
	game.strike_enemy(game.HOST,ranger,ranger.pos)
	if not game.projectile_queue.is_empty():
		var main: Dictionary = game.projectile_queue.front()
		game.update_projectiles(int(main.release)+6500)
		check(not main.has("ranger_follow_hp") and not ranger.has(Ranger.DOUBLE)
			and game.combat_events.filter(func(e):return e.kind=="projectile").size()==1,
			"preparations expire before an ordinary launch even if a shot is already queued")

func balanced_and_corridor() -> void:
	prepare(BALANCED,Vector3.ZERO,Vector3(5,0,0))
	var q := Skills.resolve(2,0,ranger.character)
	check(q.name=="Luring Snare" and is_equal_approx(q.range,7.25),"Long Draw extends native placement by 1.25 m")
	cast(0)
	var bait := trap(0)
	check(not bait.is_empty() and game.Traits.decoy_point(game,1)==bait.position and bait.skill.bind==1900,
		"Snarekeeper atomically sets its actual lure and extended Q root")
	var corridor_enemy := scout(Vector3(2,0,0))
	var r := Skills.resolve(2,1,ranger.character)
	var preview := Aim.footprint(game,ranger,game.battlefield,1,Vector3.RIGHT,5.0)
	check(is_equal_approx(r.radius,1.45) and Skills.Balance.trap_duration(r,{})==4800
		and preview.shapes.any(func(s):return s.kind=="area" and is_equal_approx(s.radius,1.45)),
		"Snarecraft changes the actual radius and lifetime in the preview")
	var stamp := Time.get_ticks_msec()
	cast(1)
	var placed := trap(1)
	check(not placed.is_empty() and is_equal_approx(placed.radius,1.45) and placed.until-placed.next == 4550
		and ranger[Cooldowns.STATE].deadline(Cooldowns.R)-stamp>=4800 and ranger[Cooldowns.STATE].deadline(Cooldowns.R)-stamp<4900,
		"Quick Reset and Snarecraft apply to the single real R record")
	if not placed.is_empty():
		var tick_at: int = placed.next
		if not bait.is_empty():
			game.trait_events.erase(bait)
		game.Traits.tick(game,tick_at)
		game.Traits.tick(game,tick_at+16)
		check(game.enemy_health()==290 and game.encounter.hp_for(corridor_enemy)==290 and placed.seen.size()==2
			and game.tactics.rooted_until==tick_at+1300 and corridor_enemy.rooted_until==tick_at+1300,
			"one native hit and root per enemy across corridor and endpoint")
		check(events.filter(func(item):return item.kind=="class_contact").size()==1,
			"only the original trap footprint publishes its normal Catalyst contact")

	prepare(["snarekeeper","wider_pattern","splinter_ambush","barbed_snare"],Vector3.ZERO,Vector3(5,0,0))
	cast(0)
	bait = trap(0)
	check(game.enemy_health()==300 and not bait.is_empty(),"Q trap placement spends no Splinter damage")
	if not bait.is_empty():
		game.Traits.tick(game,int(bait.next))
		check(game.enemy_health()==290 and bait.ranger_caught,"actual Q trap contact deals the one native Splinter hit")

	prepare(BALANCED,Vector3(-4,0,0),Vector3(3.5,0,0))
	var water := Shape.shape("river","water",PackedVector2Array([Vector2(-1,-7),Vector2(1,-7),Vector2(1,7),Vector2(-1,7)]))
	var bounds := Shape.shape("arena","arena",PackedVector2Array([Vector2(-8,-7),Vector2(8,-7),Vector2(8,7),Vector2(-8,7)]))
	var field := Field.new()
	field.ground = Surface.new({},{"masses":[],"rocks":[],"plants":[],"water":[water],"crossings":[],
		"boundary":{"playable":bounds,"water":[water],"rim":[]}},1.75)
	game.battlefield = field
	ranger.class_aim_distance=8.0
	cast(1)
	placed=trap(1)
	check(field.projectile_clear(Vector3(-4,0,0),Vector3(3,0,0),.1) and not placed.is_empty()
		and placed.get("ranger_route",{}).get("to",Vector3.INF).x < -1.75,
		"the projectile crosses water but the supported root corridor stops short")
	var legacy := preload("res://battlefield.gd").new()
	legacy.barriers.assign([Rect2(-2.5,-1.0,.25,2.0)])
	var before_wall := Ranger.corridor(legacy,Vector3(-4,0,0),Vector3(3,0,0))
	check(not before_wall.is_empty() and before_wall.to.x < -3.25,"Brambles stop at the full-width solid cover margin")

func defense_and_route() -> void:
	prepare(DEFENSE)
	ally.pos = Vector3(-4.1,0,1)
	var departure_ally := scout(Vector3.ZERO)
	ally[Conditions.STATE] = ally[Conditions.STATE].with_slow_until(Time.get_ticks_msec()+4000)
	ally.other_status = 99
	cast(0)
	var briar := trap(0)
	check(is_equal_approx(ranger.pos.x,-4.1) and not briar.is_empty() and briar.position==Vector3.ZERO
		and ally[Protection.STATE].charge_count()==1 and ally[Conditions.STATE].slow_until_ms()==0 and ally.other_status==99 and ranger[Protection.STATE].charge_count()==0,
		"valid retreat leaves its trap at departure, then wards and cleanses at landing")
	check(is_equal_approx(Ranger.speed_scale(game,ranger,Time.get_ticks_msec()),1.15)
		and is_equal_approx(game.player_snapshot(8,false)[1].motion_scale,1.15),"Fleetfoot uses the real replicated movement multiplier")
	if not briar.is_empty():
		game.Traits.tick(game,int(briar.next))
		check(departure_ally.rooted_until>0 and game.encounter.hp_for(departure_ally)==300,"Briar Retreat uses its native root without extra damage")
	var q_time: int = ranger[Cooldowns.STATE].deadline(Cooldowns.Q)
	ranger.class_aim_distance=0.05
	ranger[Cooldowns.STATE] = ranger[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
	cast(0)
	check(q_time>0 and ranger[Cooldowns.STATE].deadline(Cooldowns.Q)==0 and ranger.pos.x < -4,"invalid retreat spends no cooldown or movement")
	ally.pos = Vector3(1.05,0,1.75)
	ally[Protection.STATE] = ally[Protection.STATE].clear_expedition()
	ranger.class_aim_distance=5.0
	cast(1)
	var placed := trap(1)
	check(not placed.is_empty() and ally[Protection.STATE].charge_count()==1 and not ranger.has(Ranger.SNARE),"Safe Passage grants the placement Ward once")
	if placed.is_empty() or not placed.has("ranger_route"):
		check(false,"Escape Route visual and support are attached to the accepted trap")
		return
	var route: Dictionary = placed.ranger_route
	var now := Time.get_ticks_msec()
	ally.pos = Vector3(-2,0,0)
	Ranger.tick_route(game,placed,now)
	var grant: Dictionary = ally.get(Ranger.SPEEDS,{}).get("escape/1",{})
	check(not grant.is_empty() and is_equal_approx(Ranger.speed_scale(game,ally,now),1.2),"ally gains movement speed on entering the route")
	ally.pos = Vector3(-8,0,2)
	Ranger.tick_route(game,placed,now+400)
	ally.pos = Vector3(-2,0,0)
	Ranger.tick_route(game,placed,now+700)
	check(ally[Ranger.SPEEDS]["escape/1"].until==grant.get("until")
		and Ranger.speed_scale(game,ally,now+2100)==1.0,"one grant per ally, without refresh on re-entry")
	var replacement := ally.duplicate(true)
	replacement.erase(Ranger.SPEEDS)
	ExpeditionCase.remove_actor(game, 8)
	ExpeditionCase.install_actor(game, 9, replacement)
	Ranger.tick_route(game,placed,now+710)
	check(not replacement.has(Ranger.SPEEDS),"same character cannot claim one route twice through a new connection")
	ExpeditionCase.remove_actor(game, 9)
	ExpeditionCase.install_actor(game, 8, ally)
	ranger[PlayerLifecycle.STATE] = PlayerLifecycle.start_life()
	game.Traits.tick(game,now+50)
	check(trap(1).is_empty() and Ranger.speed_scale(game,ally,now+50)==1.0 and not placed.has("ranger_route"),
		"owner life change removes the route and its remaining grants")
	prepare(DEFENSE)
	for index in 24:
		game.trait_events.append({"kind":"hit"})
	cast(0)
	check(ranger.pos==Vector3.ZERO and ranger[Cooldowns.STATE].deadline(Cooldowns.Q)==0 and Ranger.speed_scale(game,ranger,Time.get_ticks_msec())==1.0
		and "Could not set" in game.status,"full queue refuses the retreat before motion, Ward or speed")

func run() -> void:
	verify_tree()
	game = preload("res://world.tscn").instantiate()

	game.progress.path = "user://release-fixtures/ct03-garden.cfg"
	game.local_character.path = "user://release-fixtures/ct03-character.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	ranger = game.players[1]
	game.add_player(8)
	ally=game.players[8]
	SessionCase.set_identity(game, ally, "other-character")
	ranger.frame=2
	for actor in [ranger,ally]:
		ExpeditionCase.set_membership(game, actor, true)
		SessionCase.set_ready(game, actor, true)

	game.set_meta(Events.RECORD,func(event):events.append(event))
	tracked_and_offense()
	balanced_and_corridor()
	defense_and_route()
	game.free()
	if failures==0:print("PASS: CT03 all fifteen nodes, three focuses, versioned paths and combat outcomes (%d checks)" % checks)
	quit(int(failures!=0))


func apply_frost(target: int, now: int) -> void:
	var material:=preload("res://affinity_build.gd").slot("form",game.Parts.index_of("plant:frostbell"))
	var event:=Events.begin(game,8,"form",material,material.potency_profile.values,["weapon_contact"],now+4000)
	check(event!=null,"independent Frost source has a valid current-life event")
	if event!=null:Frost.apply(game,event,target,1,now)
