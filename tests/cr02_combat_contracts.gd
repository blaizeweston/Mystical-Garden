extends SceneTree
const Protection = preload("res://player_protection.gd")

const WeaponActions = preload("res://player_weapon_actions.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Cooldowns = preload("res://player_cooldowns.gd")

const Rules = preload("res://combat_ruleset.gd")
const Build = preload("res://affinity_build.gd")
const Events = preload("res://combat_action_events.gd")
const Classes = preload("res://class_catalog.gd")
const Parts = preload("res://weapon_parts.gd")
const Cards = preload("res://affinity_cards.gd")
const CardDefinitions = preload("res://affinity_card_catalog.gd")
var failures := 0
var recorded: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL CR02: ", message)


func run() -> void:
	var profiles := check_mappings()
	var game: Node = preload("res://world.tscn").instantiate()

	game.settings_path = "user://cr02-settings.cfg"
	game.progress.path = "user://cr02-garden.cfg"
	game.local_character.path = "user://cr02-character.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_meta(Events.RECORD, func(event): recorded.append(event))
	var player: Dictionary = game.players[1]
	ExpeditionCase.set_membership(game, player, true)
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(30)
	player.pos = Vector3.ZERO
	game.encounter.set_hp(-1, 500)
	game.tactics.position = Vector3(0,0,-1)
	game.battlefield.configure(0,1,0)
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
	game.encounter.clear_scouts()
	var graph=Classes.connected_tree(0)
	player.character[graph.profile_key]=graph.state(["bastion"])
	player.weapon = game.Items.get_item("part_10").legacy_part
	var active: Dictionary = game.weapon_stats(player)
	var native := Build.native_stats(Build.resolve(0,0,[0,0,0],player.character))
	check(active.reach==native.reach and active.interval==native.interval and active.class_power==0 and not active.has("core_build"),"plant slots do not change native weapon stats or grant empty-Core haste")
	var ready_core: int=player.weapon
	player.weapon = -1
	player.secondary = -1
	player.catalyst = -1
	var timers: Array = [player[WeaponActions.STATE].ready_at_ms(),player[Cooldowns.STATE].deadline(Cooldowns.Q)]
	game.strike_enemy(1,player,player.pos)
	game.use_class_skill(1,player,0)
	game.garden_action(1,"core_cast:unavailable")
	check([player[WeaponActions.STATE].ready_at_ms(),player[Cooldowns.STATE].deadline(Cooldowns.Q)] == timers and game.projectile_queue.is_empty()
		and "invalid" in game.status, "invalid Form, Catalyst and Core do not execute")

	player.weapon = ready_core
	player.secondary = 0
	player.catalyst = 0
	game.use_class_skill(1,player,0)
	check(recorded.is_empty() and player[Protection.STATE].charge_count()==1, "connected Bastion activation grants native Rootshield only")
	var now := Time.get_ticks_msec()
	IncomingPlayerHit.resolve_world(game, 1, PlayerLifecycle.generation(player), now, 1)
	check(recorded.size()==1 and recorded[0].kind=="actual_block" and player[Protection.STATE].charge_count()==0,
		"actual connected Q block records its first consumption once")
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.R, 0)
	game.use_class_skill(1,player,1)
	check(recorded.size()==2 and recorded[1].kind=="class_action", "actual Root Quake emits one activation")

	player.facing = Vector3.FORWARD
	game.tactics.position = Vector3(0,0,-1)
	game.strike_enemy(1,player,player.pos)
	game.update_projectiles(Time.get_ticks_msec()+2000)
	check(recorded.size()==3 and recorded[2].kind=="weapon_contact"
		and recorded[2].source=="native_weapon", "native melee labels the real contact separately from the class action")

	# A scoped recording test, with an ally's refined potency snapshot.
	game.add_player(20)
	var potency := {"duration_ms": 600, "nested": {"bonus": 7}}
	var material := preload("res://plant_affinities.gd").for_part(Parts.HEARTWOOD)
	var source := Events.begin(game,20,"catalyst",material,potency,["periodic","secondary"],now+1000)
	var refresh := Events.begin(game,20,"catalyst",material,potency,["periodic"],now+1000)
	potency.nested.bonus=100
	check(source.publish(game,"periodic","pulse1","recipient1",now), "first pulse records")
	check(not source.publish(game,"periodic","pulse1","recipient1",now), "duplicate is refused")
	check(source.publish(game,"periodic","pulse1","recipient2",now), "same pulse may reach a second recipient")
	check(source.publish(game,"periodic","pulse2","recipient1",now), "distinct scheduled pulse remains valid")
	check(not source.publish(game,"weapon_contact","pulse2","recipient1",now), "secondary source cannot impersonate a direct hit")
	check(source.publish(game,"secondary","followup","recipient1",now), "explicit secondary event records")
	check(refresh.publish(game,"periodic","pulse1","recipient1",now), "separate activation records independently")
	var sample: Dictionary = recorded[-2]
	check(sample.potency.nested.bonus==7 and sample.source_actor==20 and sample.quality=="refined"
		and sample.stack_source==recorded[-1].stack_source and sample.activation!=recorded[-1].activation, "grant provenance survives, stack key excludes cast ID")
	check(not source.publish(game,"periodic","late","recipient1",now+1000), "expired response is refused")
	var one := Events.begin(game,20,"native_class",{}, {},["actual_block"],now+100,1)
	check(one.publish(game,"actual_block","ward","recipient1",now)
		and not one.publish(game,"actual_block","ward","recipient2",now), "charge scope is enforced")
	var ward := Events.begin(game,20,"native_class",{}, {},["actual_block"],now+1000)
	var life: Dictionary = game.players[20]
	life[PlayerLifecycle.STATE] = life[PlayerLifecycle.STATE].fall()
	check(ward.publish(game,"actual_block","retained","recipient1",now)
		and not source.publish(game,"periodic","downed","recipient1",now),"a downed source retains accepted defense and cannot publish offense")
	life[PlayerLifecycle.STATE] = PlayerLifecycle.start_life()
	check(not ward.publish(game,"actual_block","retired","recipient2",now)
		and not refresh.publish(game,"periodic","retired","recipient2",now),"retired life cannot publish defense or delayed offense")
	check_native_progression(game, player)
	check_runtime_focuses(game, player)
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: CR02 contracts across ",profiles," skill resolutions and event boundaries")
	quit(int(failures!=0))


func check_native_progression(game: Node, player: Dictionary) -> void:
	var character = preload("res://character_profile.gd")
	var profile: Dictionary = character.blank()
	profile.xp[0] = 5000
	profile.upgrades[0] = 1 | (1 << 50)
	profile = character.normalize(profile)
	check(profile.upgrades[0] == 1 and profile.quarantine.learned_class_masks.warden == 1 << 50
		and character.normalize(profile) == profile, "legacy investment and unknown learned bits survive normalization")
	profile.upgrades[0] = 0
	var graph=Classes.connected_tree(0)
	profile[graph.profile_key]=graph.state(["bastion"])
	player.character = profile
	var native: int = game.Life.native_maximum(game, player)
	var vital = preload("res://vital_combat.gd")
	var elapsed := 100
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_native_max_hp(native).with_hp(native - 2)
	var before: float = player[PlayerVitals.STATE].hp()
	var source := Events.begin(game,1,"form",{},vital.QUALITY.ordinary,["weapon_contact"],Time.get_ticks_msec()+5000)
	vital.grant(game,source,1,elapsed)
	var learned_hp: int=CardDefinitions.DEFINITIONS.run_health.values[0]
	var copies: Array[Dictionary]=[{"id":"run_health","rarity":"Common","amount":learned_hp,"floor":3,"acquisition_id":1}]
	player[Cards.STATE]=Cards.Ledger.new(copies)
	game.restore_class_loadout(player)
	check(player[PlayerVitals.STATE].max_hp() == native + learned_hp + vital.QUALITY.ordinary.bonus_hp and player[PlayerVitals.STATE].hp() == before,
		"current card capacity updates without free healing or baking in Vitality")
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].refilled()
	player[vital.NEXT] = elapsed + 10000
	vital.tick(game,elapsed + vital.DURATIONS.form)
	check(player[PlayerVitals.STATE].max_hp() == native + learned_hp and player[PlayerVitals.STATE].hp() == float(player[PlayerVitals.STATE].max_hp()),
		"Vitality expires to current native capacity and clamps current HP")
	var weapons := []
	for index in Classes.DEFINITIONS.size():
		var local := []
		for weapon_index in 3:
			var build := Build.resolve(index,weapon_index,[0,0,0],{})
			local.append(build.weapon_id)
			weapons.append(build.weapon_id)
		check(local.size() == 3 and local[0] != local[1] and local[0] != local[2] and local[1] != local[2],
			"three distinct native weapons for %s" % Classes.DEFINITIONS[index].id)
	check(weapons.size() == 15, "five native class rosters")


func check_runtime_focuses(game: Node, player: Dictionary) -> void:
	for class_id in range(1, 5):
		for lane in 3:
			ExpeditionCase.set_world(game, {"combat_epoch": game.participation.epoch() + (1)})
			recorded.clear()
			game.trait_events.clear()
			game.enemy_traits.clear()
			game.encounter.set_hp(-1, 10000)
			game.tactics.position = Vector3(0,0,-2.4)
			var profile: Dictionary = game.Character.blank()
			var graph=Classes.connected_tree(class_id)
			profile[graph.profile_key]=graph.state([graph.nodes[lane].id])
			player.character = profile
			player.frame = class_id
			player.pos = Vector3.ZERO
			player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(30)
			player.catalyst = Parts.HEARTWOOD
			player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
			player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.R, 0)
			player.core_cast_until = 0
			var build := Build.for_player(player)
			var adapter: Dictionary = build.class_skills[0]
			player.class_aim = Vector3.FORWARD
			player.class_aim_distance = 2.4
			game.use_class_skill(1,player,0)
			player.erase("class_aim")
			player.erase("class_aim_distance")
			check(player[Cooldowns.STATE].deadline(Cooldowns.Q)>0, "%s native Q casts through its adapter" % adapter.id)
			if adapter.trigger == "activation":
				check(recorded.any(func(event): return event.kind=="class_action" and event.details.adapter==adapter.id),
					"%s publishes its mapped event" % adapter.id)
			elif adapter.trigger == "block":
				check(recorded.is_empty() and player[Protection.STATE].charge_count()>0, "%s arms a genuine Ward" % adapter.id)
				IncomingPlayerHit.resolve_world(game, 1, PlayerLifecycle.generation(player), Time.get_ticks_msec(), 1)
				check(recorded.any(func(event): return event.kind=="actual_block"), "%s responds on consumption" % adapter.id)
			elif adapter.trigger == "contact":
				check(recorded.is_empty(), "%s has no grant-time response" % adapter.id)
				game.Traits.tick(game,Time.get_ticks_msec()+320)
				check(recorded.any(func(event): return event.kind=="class_contact"), "%s responds on trap contact" % adapter.id)


func check_mappings() -> int:
	var total := 0
	for class_id in Classes.DEFINITIONS.size():
		var graph=Classes.connected_tree(class_id)
		for lane in 3:
			var profile := preload("res://character_profile.gd").blank()
			profile[graph.profile_key]=graph.state([graph.nodes[lane].id])
			var build := Build.resolve(class_id,2,[Parts.THORN,Parts.MOSS,Parts.VEIL],profile)
			for adapter in build.class_skills:
				check(not adapter.is_empty() and adapter.responses.size()==9
					and not str(adapter.get("id","")).is_empty() and not adapter.response.is_empty(), "explicit adapter for %s focus %s" % [Classes.DEFINITIONS[class_id].id,graph.nodes[lane].id])
				total += 1
	var profile:=preload("res://character_profile.gd").blank()
	var graph=Classes.connected_tree(0)
	profile[graph.profile_key]=graph.state(["vanguard"])
	var base := Build.resolve(0,0,[Parts.THORN, Parts.MOSS, Parts.VEIL],profile)
	var refined := Build.resolve(0,0,[Parts.HEARTWOOD, Parts.MOSS, Parts.VEIL],profile)
	var other := Build.resolve(0,0,[Parts.THORN, Parts.VEIL, Parts.MOSS],profile)
	check(base.core.card_requirements==refined.core.card_requirements
		and base.core.affinity_core_skill_id==refined.core.affinity_core_skill_id
		and base.core.potency_profile.id!=refined.core.potency_profile.id, "quality retains identity and selects its own potency profile")
	check(base.core==other.core and base.form!=other.form and base.catalyst!=other.catalyst
		and Build.native_stats(base)==Build.native_stats(other), "plant slots are isolated from Core and native stats")
	check(not base.has("graft") and not base.core.card_requirements.has("graft"), "retired installed graft slot cannot satisfy plant requirements")
	return total
