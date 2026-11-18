extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Cooldowns = preload("res://player_cooldowns.gd")

const Connected = preload("res://warden_connected_tree.gd")
const Warden = preload("res://warden_combat.gd")
const Profile = preload("res://character_profile.gd")
const Rules = preload("res://combat_ruleset.gd")
const Builds = preload("res://affinity_build.gd")
const Events = preload("res://combat_action_events.gd")
const Skills = preload("res://skill_catalog.gd")
const OFFENSE := ["vanguard","briar_rebound","pinning_quake","faultline_impact","quakefront","aftershock"]
const BALANCE := ["rootkeeper","deep_roots","ready_footing","living_rhythm","measured_guard","seismic_relay"]
const DEFENSE := ["bastion","shared_guard","clear_the_way","sheltering_quake","measured_guard","sanctuary_ground"]
const HOLDFAST := ["bastion","shared_guard","clear_the_way","sheltering_quake","holdfast","sanctuary_ground"]
var game: Node
var player: Dictionary
var events: Array = []
var failed := false
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failed = true
		printerr("FAIL CT01: ",label)


func request(id: String) -> int:
	return Connected.REQUEST_OFFSET+Connected.NODES.find(Connected.node(id))


func graph(selected: Array, reachable: Dictionary) -> void:
	if selected.size() == 6:
		reachable[selected.back()] = true
		return
	var profile := Profile.blank()
	profile.xp[0] = Connected.XP_THRESHOLDS[selected.size()]
	profile[Connected.PROFILE_KEY] = Connected.state(selected)
	for index in Connected.NODES.size():
		var node: Dictionary = Connected.NODES[index]
		var adjacent := selected.is_empty() or absi(int(Connected.node(selected.back()).lane)-index%3)<=1
		var allowed: bool = floori(index/3.0)==selected.size() and adjacent
		var result := Connected.refusal(profile,index+Connected.REQUEST_OFFSET)
		check(result.is_empty()==allowed,"earned tier and adjacent predecessor for %s → %s" % [selected,node.id])
		if allowed:
			graph(selected+[node.id],reachable)


func profiles() -> void:
	var reachable := {}
	graph([],reachable)
	check(Connected.NODES.size()==18 and reachable.size()==3,"three focuses, all fifteen tier nodes selectable, all three capstones reachable")
	check(Connected.XP_THRESHOLDS==[0,50,150,350,1400,2600],"Warden earns the same six levels at the exact ×10 thresholds")
	var legacy := Profile.blank()
	legacy.xp[0]=570
	legacy.upgrades[0]=1<<14
	legacy.upgrades[4]=1<<12
	var copied := Profile.normalize(legacy)
	check(copied==legacy and not Connected.eligible(copied),"historical investments and XP survive normalization")
	check(not Builds.resolve(0,0,[0,0,0],copied).capabilities.class_actions,
		"historical data is retained without executing retired class mechanics")
	var connected := Profile.blank()
	connected.xp[0]=2600
	connected[Connected.PROFILE_KEY]=Connected.state(["vanguard","deep_roots"])
	var normalized := Profile.normalize(connected)
	check(Connected.valid(normalized) and Connected.focus(normalized)=="vanguard" and normalized.upgrades[0]==0,
		"versioned stable IDs round trip separately from masks")
	check(Skills.resolve(0,0,normalized).name=="Thorn Counter",
		"one resolver executes the versioned starting focus")
	for invalid in [null, {"version":2,"path":["vanguard"]},{"version":1,"path":["vanguard","shared_guard"]}]:
		normalized[Connected.PROFILE_KEY]=invalid
		check(not Connected.valid(normalized) and not Builds.resolve(0,0,[0,0,0],normalized).capabilities.class_actions,
			"invalid connected data cannot execute class skills")
		check(Profile.normalize(normalized)[Connected.PROFILE_KEY]==invalid,"invalid data stays readable for review")


func choose(id: String) -> void:
	game.send_garden_action("learn_0_%d"%request(id))


func title_and_progression() -> bool:
	var menu := preload("res://main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu.new_game()
	menu.create_character("CT01 Warden",0,preload("res://character_appearance.gd").DEFAULT)
	var deadline := Time.get_ticks_msec()+6500
	while current_scene==menu and Time.get_ticks_msec()<deadline:
		await process_frame
	if current_scene==menu:
		check(false,"real title opens isolated guarded Garden")
		return false
	game=current_scene
	player=game.players[1]
	check(game.weapon_stats(game.players[1]).affinity_build.ruleset==Rules.ID and SessionCase.has_guarded_session(game),"real guarded affinity session")
	var old_catalog: Dictionary = game.progress.ContentIDs.manifest()
	old_catalog.erase(Profile.Experience.VERSION_KEY)
	old_catalog.levels = [0,5,15,35,70,140,260]
	check("Different game content" in SessionCase.World.admission_error(game,"a3".repeat(16),old_catalog,game.Network.PROTOCOL),
		"existing content admission refuses older XP units")
	player.pos=game.stage.gate_position()
	choose("briar_rebound")
	check(Connected.path(player.character).is_empty(),"a node cannot precede the focus")
	var panel = game.progression_view
	panel.inspected_class=0
	panel.tabs.current_tab=2
	panel.refresh()
	check((panel.nodes.size()==19 and panel.nodes[1].label=="Vanguard" and panel.nodes[1].available
		and panel.nodes[15].label=="Holdfast" and not panel.nodes[15].available),"class screen presents the 18 connected choices with tier gating")
	panel.chosen="class_0_%d"%request("vanguard")
	panel.refresh()
	check(not panel.learn_button.disabled,"Warden focus is selectable on the class screen")
	panel.learn_button.pressed.emit()
	check(Connected.path(player.character)==["vanguard"] and player.character.upgrades[0]==0,"level-one focus selected through host handler")
	choose("deep_roots")
	check(Connected.path(player.character)==["vanguard"],"unearned tier rejected")
	player.character.xp[0]=2600
	choose("shared_guard")
	check(Connected.path(player.character)==["vanguard"],"disconnected selection rejected by host")
	for id in ["deep_roots","ready_footing","sheltering_quake"]:
		choose(id)
	panel.refresh()
	check(panel.nodes[15].available,"Holdfast becomes selectable after the connected tier and level requirements")
	choose("holdfast")
	choose("sanctuary_ground")
	var saved := Connected.path(player.character).duplicate()
	choose("seismic_relay")
	choose("briar_rebound")
	check(saved.size()==6 and Connected.path(player.character)==saved and game.local_character.data[Connected.PROFILE_KEY].path==saved,
		"one node per level, one capstone, no backfill, locally committed")
	var config := ConfigFile.new()
	check(config.load(game.local_character.path)==OK and config.get_value("character","progress",{}).get(Connected.PROFILE_KEY,{}).get("path",[])==saved,
		"guarded profile serializer writes the versioned path")
	check(Skills.resolve_in_world(game,0,0,player.character).name=="Thorn Counter","crossing two lanes never replaces the starting Q")
	player.pos=game.Stage.HEART
	game.send_garden_action("respec_0")
	check(Connected.path(player.character).is_empty() and player.character.xp[0]==2600 and player.character.upgrades[0]==0,
		"existing Heart respec refunds selections while preserving earned XP")
	for id in OFFENSE:
		choose(id)
	check(Connected.path(player.character)==OFFENSE,"spent the same six selections after respec")
	player.pos=game.stage.gate_position()
	game.map_rng.seed=16
	game.PartyTravel.request(game,1,"depart")
	deadline = Time.get_ticks_msec()+6500
	while (not ExpeditionCase.is_wild(player) or not game.stage._has_experimental_floor()) and Time.get_ticks_msec()<deadline:
		await process_frame
	var departed: bool = ExpeditionCase.is_wild(player) and game.stage._has_experimental_floor()
	check(departed,"real guarded terrain expedition departure")
	return departed


func arena(path: Array) -> void:
	player.character[Connected.PROFILE_KEY]=Connected.state(path)
	player.pos=Vector3.ZERO
	player.facing=Vector3.FORWARD
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(90)
	player.catalyst=0
	player.weapon=0
	player.secondary=0
	game.encounter.set_hp(-1, 900)
	game.tactics.position=Vector3(0,0,-1.2)
	game.tactics.winding_up=false
	game.enemy_mutations=0
	game.enemy_traits.clear()
	game.tactics.memory.clear()
	game.encounter.clear_scouts()
	game.tactics.rooted_until=0
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0).with_deadline(Cooldowns.R, 0)
	for key in ["cast_until","core_cast_until","counter_until","counter_guard_until","front_guard_until",
			"guard_until","guard_charges","hurt_until","slow_until"]:
		player[key]=0
	for key in ["warden_block","warden_anchor","warden_relay","warden_aftershock","warden_sanctuary","warden_holdfast","affinity_ward_claims"]:
		player.erase(key)
	events.clear()


func block(recipient: int=1) -> int:
	var target: Dictionary=game.players[recipient]
	var now := Time.get_ticks_msec()
	IncomingPlayerHit.resolve_world(game, recipient, PlayerLifecycle.generation(target), now, 4.0, 0, Vector3(0,0,-2))
	return now


func offense() -> void:
	arena(OFFENSE)
	game.use_class_skill(1,player,1)
	var normal_damage: int=900-game.enemy_health()
	arena(OFFENSE)
	var scout: Dictionary=game.make_scout(0,Vector3(3.3,0,0),4)
	scout.hp=200
	game.encounter.register_scout(scout)
	var origin: Vector3=game.tactics.position
	game.use_class_skill(1,player,0)
	var now := block()
	check(player[PlayerVitals.STATE].hp()==90 and player.warden_block.blocked and game.tactics.position.distance_to(origin)>.7,
		"real block triggers Briar Rebound and preserves Thorn Counter")
	check(player.counter_until>now,"native Thorn Counter still primes its counter")
	# Isolate the Quake node's additive damage from Thorn Counter.
	player.counter_until=0
	game.use_class_skill(1,player,1)
	check(900-game.enemy_health()==normal_damage+10 and game.tactics.rooted_until>now and not game.enemy_traits.has("brittle_until"),
		"Pinning Quake roots and Faultline adds native damage without Brittle")
	check(game.encounter.hp_for(scout)<200,"Quakefront hits the scout at 3.3 m")
	var quakes := events.filter(func(event):return event.kind=="class_action" and str(event.details.adapter).begins_with("warden/"))
	check(quakes.size()==1 and is_equal_approx(float(quakes[0].details.radius),3.0),
		"the native area increase leaves the Catalyst area and activation count intact")
	game.tactics.position=Vector3(0,0,-1.1)
	var damage_before: int=game.enemy_health()
	var due: int=player.get("warden_aftershock",{}).get("due",0)
	Warden.tick(game,due-1)
	check(game.enemy_health()==damage_before and due>now,"Aftershock waits for its scheduled impact")
	var count := events.size()
	Warden.tick(game,due)
	Warden.tick(game,due+5)
	check(damage_before-game.enemy_health()==8 and events.size()==count and not player.has("warden_aftershock"),
		"Aftershock hits once without a new affinity contact or class activation")


func deep_roots() -> void:
	for path in [["rootkeeper"],["rootkeeper","deep_roots"]]:
		arena(path)
		game.use_class_skill(1,player,0)
		player.pos=Vector3(6,0,0)
		game.use_class_skill(1,player,1)
		var extended: bool = path.size()==2
		check((game.enemy_health()<900)==extended and player.skill_fx.pos.is_equal_approx(Vector3.ZERO if extended else player.pos),
			"Deep Roots permits the actual six-metre anchor Quake")
	arena(["vanguard","deep_roots"])
	game.use_class_skill(1,player,0)
	var now := block()
	check(player.counter_until==now+4750,"Deep Roots extends the earned Thorn Counter window")

	var ally: Dictionary=game.players[2]
	ally.pos=Vector3(0,0,-3.6)
	ExpeditionCase.set_membership(game, ally, true)
	for path in [["bastion"],["bastion","deep_roots"]]:
		arena(path)
		ally.guard_charges=0
		ally.guard_until=0
		game.use_class_skill(1,player,0)
		check((ally.guard_charges==1)==(path.size()==2),"Deep Roots changes actual Rootshield coverage")


func balance() -> void:
	arena(BALANCE)
	check(Skills.resolve_in_world(game,0,0,player.character).anchor_range==6.5,"Deep Roots extends native anchor reach")
	game.use_class_skill(1,player,0)
	var refund: int=player[Cooldowns.STATE].deadline(Cooldowns.Q)
	var expiry: int=player.warden_block.until
	Warden.tick(game,expiry+1)
	Warden.tick(game,expiry+2)
	check(player[Cooldowns.STATE].deadline(Cooldowns.Q)==refund-1250,"Measured Guard refunds unused Q once on actual expiry")
	arena(BALANCE)
	game.use_class_skill(1,player,0)
	player.pos=Vector3(2,0,0)
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.DODGE, Time.get_ticks_msec()+1800)
	var now := block()
	var before: int=player[Cooldowns.STATE].deadline(Cooldowns.Q)
	Warden.tick(game,player.warden_block.until+1)
	check(player[Cooldowns.STATE].deadline(Cooldowns.DODGE)==now and player[Cooldowns.STATE].deadline(Cooldowns.Q)==before,"Ready Footing restores dodge and a used Q gets no expiry refund")
	var scout: Dictionary=game.make_scout(0,Vector3(4.5,0,0),5)
	scout.hp=200
	game.encounter.register_scout(scout)
	player.pos=Vector3(-.5,0,0)
	game.use_class_skill(1,player,1)
	check(not player.has("warden_relay") and player.skill_fx.pos.is_equal_approx(Vector3(2,0,0)) and game.encounter.hp_for(scout)<200,
		"Seismic Relay directs native Quake and is spent once")
	check(player[Cooldowns.STATE].deadline(Cooldowns.Q)==before-1250,"Living Rhythm refunds Q after the prepared hit")


func defense() -> void:
	arena(DEFENSE)
	var ally: Dictionary=game.players[2]
	ally.pos=Vector3(1,0,1)
	ExpeditionCase.set_membership(game, ally, true)
	ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(90)
	ally.guard_charges=0
	ally.guard_until=0
	ally.erase("affinity_ward_claims")
	player.catalyst=game.Items.get_item("plant_part_rare_frostbell").legacy_part
	player.slow_until=Time.get_ticks_msec()+8000
	ally.slow_until=player.slow_until
	game.use_class_skill(1,player,0)
	check(ally.guard_charges==0,"ally behind Rootshield has no native Ward")
	var now := block()
	check(ally.guard_charges==1 and ally.guard_until==now+950 and player.slow_until==0 and ally.slow_until==0,
		"Shared Guard and Clear the Way affect the intended nearby ally")
	block(2)
	var block_events := events.filter(func(event):return event.kind=="actual_block")
	check(block_events.size()==1 and block_events[0].source_actor==1 and block_events[0].quality=="refined",
		"the original Q Ward keeps the Catalyst source, and Shared Guard does not reproc it")
	game.use_class_skill(1,player,1)
	check(ally.guard_charges==1 and ally.guard_until>now+1100,"Sheltering Quake grants new Guard after a prepared hit")
	ally.guard_charges=0
	ally.guard_until=0
	ally.hurt_until=0
	IncomingPlayerHit.resolve_world(game, 2, PlayerLifecycle.generation(ally), now+10, 4.0, 0, Vector3(0,0,-2))
	check(ally[PlayerVitals.STATE].hp()==60,"Sanctuary reduces a 40 HP direct attack by 25 percent")
	ally.hurt_until=0
	IncomingPlayerHit.resolve_world(game, 2, PlayerLifecycle.generation(ally), now+20, 4.0, 0, Vector3(0,0,-2), false)
	check(ally[PlayerVitals.STATE].hp()==20,"Sanctuary leaves environmental damage intact")
	arena(DEFENSE)
	ally.pos=Vector3(1,0,-1)
	ally.hurt_until=0
	ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(90)
	game.use_class_skill(1,player,0)
	block(2)
	var cooldown: int=player[Cooldowns.STATE].deadline(Cooldowns.Q)
	Warden.tick(game,player.warden_block.until+1)
	check(player[Cooldowns.STATE].deadline(Cooldowns.Q)==cooldown and not player.has("warden_sanctuary"),
		"ally Ward consumption counts against Measured Guard without replaying a Warden self-block response")
	arena(DEFENSE)
	ally.pos=Vector3(1,0,1)
	game.use_class_skill(1,player,0)
	block()
	ally.guard_charges=0
	ally.guard_until=0
	game.tactics.position=Vector3(0,0,-9)
	game.use_class_skill(1,player,1)
	check(game.enemy_health()==900 and ally.guard_charges==1 and player.warden_block.quake_used,
		"Sheltering Quake protects allies on an empty impact and spends its preparation")


func reset_holdfast_ally(ally: Dictionary, point: Vector3) -> void:
	ally.pos=point
	ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(90)
	ExpeditionCase.set_membership(game, ally, true)
	ally.guard_charges=0
	ally.guard_until=0
	ally.hurt_until=0
	ally.slow_until=0
	ally.erase("affinity_ward_claims")
	ally.erase("warden_holdfast")


func sample_damage(id: int, now: int, direct := true, amount := 4.0) -> int:
	var recipient: Dictionary=game.players[id]
	recipient.guard_charges=0
	recipient.guard_until=0
	recipient.hurt_until=0
	recipient[PlayerVitals.STATE] = recipient[PlayerVitals.STATE].with_hp(90)
	IncomingPlayerHit.resolve_world(game, id, PlayerLifecycle.generation(recipient), now, amount, 0, Vector3.ZERO, direct)
	return 90-int(recipient[PlayerVitals.STATE].hp())


func holdfast() -> void:
	arena(HOLDFAST.slice(0,5))
	game.add_player(3)
	game.add_player(4)
	var ally: Dictionary = game.players[2]
	var distant: Dictionary = game.players[3]
	var fallen: Dictionary = game.players[4]
	reset_holdfast_ally(ally,Vector3(1,0,-1))
	reset_holdfast_ally(distant,Vector3(6,0,0))
	reset_holdfast_ally(fallen,Vector3(1,0,1))
	fallen[PlayerLifecycle.STATE] = fallen[PlayerLifecycle.STATE].fall()
	player.catalyst=game.Items.get_item("plant_part_rare_frostbell").legacy_part
	game.use_class_skill(1,player,0)
	check(not player.has("warden_holdfast") and not ally.has("warden_holdfast"),"cast alone grants no Holdfast")
	var slowed_until := Time.get_ticks_msec()+4500
	ally.slow_until=slowed_until
	var now := block(2)
	check(ally.slow_until==slowed_until,"Holdfast itself neither roots nor cleanses an ally")
	var original: Dictionary = ally.get("warden_holdfast",{}).duplicate()
	check(Warden.holdfast_until(game,player,now)==now+2500 and original.get("until")==now+2500 and original.get("actor")==1
		and original.get("activation")==player.warden_block.activation,"ally's actual Q block grants one sourced Holdfast to caster and recipient")
	check(Warden.holdfast_until(game,distant,now)==0 and Warden.holdfast_until(game,fallen,now)==0,
		"Holdfast excludes distant and fallen allies")
	block()
	check(ally.get("warden_holdfast")==original,"the caster's second block of the same Q cannot refresh Holdfast")

	ally.pos=Vector3(6,0,0)
	var event_count := events.size()
	check(sample_damage(2,now+40)==34 and ally.pos==Vector3(6,0,0)
		and not ally.has("affinity_bark_grants") and ally.guard_charges==0 and ally.slow_until==0,
		"moving recipient takes 34 of 40 direct HP with no extra Ward, Bark or movement restriction")
	check(sample_damage(2,now+80,false)==40 and sample_damage(2,now+90,true,.1)==1 and events.size()==event_count,
		"environmental hits are unreduced and Holdfast cannot block a hit or produce a Catalyst event")

	distant.character.xp[0]=2600
	distant.character[Connected.PROFILE_KEY]=Connected.state(HOLDFAST.slice(0,5))
	game.use_class_skill(3,distant,0)
	var refresh := now+700
	IncomingPlayerHit.resolve_world(game, 3, PlayerLifecycle.generation(distant), refresh, 4, 0, distant.pos+Vector3.FORWARD)
	check(Warden.holdfast_until(game,ally,refresh)==refresh+2500 and ally.warden_holdfast.actor==3
		and sample_damage(2,refresh+30)==34,
		"a later Warden refreshes with its own source and the same 15 percent strength")
	check(sample_damage(2,refresh+2500)==40,"damage returns to full at the refreshed expiry")

	arena(HOLDFAST)
	reset_holdfast_ally(ally,Vector3(1,0,1))
	game.use_class_skill(1,player,0)
	now=block()
	check(sample_damage(2,now+30)==30,"Sanctuary and Holdfast overlap with only the stronger 25 percent reduction")
	ally.pos=Vector3(5,0,0)
	check(sample_damage(2,now+50)==34,"leaving Sanctuary keeps the recipient's Holdfast")
	ally.pos=Vector3(1,0,1)
	check(sample_damage(2,now+2600)==30 and sample_damage(2,now+3500)==40,
		"stationary Sanctuary remains after Holdfast expires and has its own expiration")


func run() -> void:
	profiles()
	if not await title_and_progression():
		quit(1)
		return
	game.set_physics_process(false)
	game.battlefield.configure(0,1,0)
	game.battlefield.barriers.clear()
	game.tactics.boss_kind=-1
	game.set_meta(Events.RECORD,func(event):events.append(event))
	offense()
	game.add_player(2)
	deep_roots()
	ExpeditionCase.set_membership(game, game.players[2], false)
	balance()
	defense()
	holdfast()
	print("CT01 checks: ",checks)
	if not failed:
		print("PASS: connected Warden progression and native combat effects")
	quit(int(failed))
