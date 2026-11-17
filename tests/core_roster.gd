extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")

const Core = preload("res://core_combat.gd")
const Rules = preload("res://core_skill_rules.gd")
const Footprint = preload("res://core_footprint.gd")
const Cards = preload("res://run_upgrade_catalog.gd")

var failed := false


func _initialize() -> void:
	preload("res://combat_balance_preview.gd").enabled = false
	call_deferred("run")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL Core roster: ", detail)


func arena(game: Node, player: Dictionary, species: String) -> void:
	Core.reset(game)
	game.encounter.clear_scouts()
	game.enemy_traits.clear()
	game.enemy_death_events.clear()
	game.encounter.set_hp(-1, 30)
	game.enemy_kind = 0
	game.enemy_mutations = 0
	game.tactics.winding_up = false
	game.tactics.stagger_until = 0
	game.tactics.rooted_until = 0
	game.tactics.position = Vector3(0, 0, -2)
	game.tactics.memory.clear()
	game.tactics.boss_kind = -1
	game.encounter_rewarded = false
	game.battlefield.configure(0, 1, 0)
	game.battlefield.barriers.clear()
	player.pos = Vector3.ZERO
	player.facing = Vector3.FORWARD
	player.weapon = game.Parts.index_of("plant:" + species)
	player.secondary = 0
	player.catalyst = 0
	player.graft_part = 0
	ExpeditionCase.set_membership(game, player, true)
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(8)
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_native_max_hp(10)
	player.core_ready_at = 0
	player.core_cast_until = 0
	player.cast_until = 0
	player.guard_until = 0
	player.guard_charges = 0
	player.erase("ironbark_ward")
	player.slow_until = 0
	player.run_upgrades.clear()


func cast(game: Node, player: Dictionary) -> Dictionary:
	var profile := Core.equipped(player)
	var preview := Core.preview(game, player, game.battlefield, Vector3.FORWARD, 2.0)
	var expected_shapes := 1 if profile.get("targeting") == "self" else 2
	check(preview.valid and preview.shapes.size() >= expected_shapes, profile.name + " has a target preview")
	game.garden_action(1, Core.request(game, player, Vector2.UP, 2.0))
	var live: Dictionary = game.get_meta(Core.STATE, {}).get(1, {})
	check(not live.is_empty(), profile.name + " casts using authoritative aim")
	return live


func run() -> void:
	var game: Node = load("res://world.tscn").instantiate()
	game.progress.path = "res://.godot/core-roster-" + str(Time.get_ticks_usec()) + ".cfg"
	game.local_character.path = game.progress.path + ".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var player: Dictionary = game.players[1]
	var icons := {}
	var signatures := {}
	for seed in game.Seeds.DEFINITIONS:
		var part: int = game.Parts.index_of("plant:" + seed.id)
		var refined: int = game.Parts.rare_part(game.Seeds.index_of(seed.id))
		var starter := Rules.resolve("0_0", [part], 0)
		check(not starter.skill.is_empty(), "Core exists for " + seed.id)
		if starter.skill.is_empty(): continue
		check(not icons.has(starter.skill.icon) and not signatures.has(starter.primary), "unique Core icon and primary for " + seed.id)
		icons[starter.skill.icon] = true
		signatures[starter.primary] = true
		for definition in game.Classes.DEFINITIONS:
			for weapon in definition.weapons:
				var normal := Rules.resolve(weapon.id, [part], 0)
				var rare := Rules.resolve(weapon.id, [refined], 0)
				check(normal.skill.id == starter.skill.id and rare.skill.id == normal.skill.id and rare.primary == normal.primary, "ordinary and refined parts work on " + weapon.name + " / " + seed.id)
		if Cards.get_upgrade("core_" + starter.skill.id).is_empty(): continue
		arena(game, player, seed.id)
		var id: String = "core_" + starter.skill.id
		var card := Cards.get_upgrade(id)
		check(Cards.requirement(card, player).is_empty() and Cards.roll(player, 3, 33, 8)[0] == id, "compatible checkpoint offers " + card.name)
		player.run_upgrades[id] = 1
		var fixture := prepare_effect(game, player, starter.skill.id)
		var live := cast(game, player)
		if live.is_empty(): continue
		check(game.weapon_stats(player).core_build.skill.get("cards", []).size() == 1 and live.skill.has(card.core_tuning.keys()[0]), "card tunes the same profile the cast and HUD use")
		if live.skill.id == "dewfall":
			player.pos = live.center
		Core.tick(game, live.armed)
		render_fx(game, live.skill.id)
		if live.skill.id == "worldbloom":
			player.pos = live.center
		if live.skill.id == "ironbark":
			check(game.tactics.stagger_until == 0 and player.guard_charges == 1, "Hold Ground waits for a real block")
			IncomingPlayerHit.resolve_world(game, 1, PlayerLifecycle.generation(player), live.armed + 200, 1, 0, game.tactics.position)
		if live.skill.id == "grave_lantern":
			var corpse: Dictionary = game.make_scout(0, Vector3(.8, 0, -2), 1)
			corpse.hp = 0
			game.encounter.register_scout(corpse)
			game.record_enemy_death(0, corpse.pos, player.pos)
			player.pos = Vector3(0, 0, -2)
		for elapsed in [400, 650, 900, 1200, 1600, 1900, 2600, 4000, 6200]:
			Core.tick(game, live.armed + elapsed)
			render_fx(game, live.skill.id)
		verify_effect(game, player, live, fixture)
		check(not game.has_meta(Core.STATE), "cast expires cleanly: " + seed.id)

	check(icons.size() == game.Seeds.DEFINITIONS.size() and signatures.size() == icons.size(), "all species have a unique active and icon")
	arena(game, player, "ember_fern")
	player.run_upgrades["core_ember_wake"] = 1
	var ember := cast(game, player)
	var start: int = ember.armed
	Core.tick(game, start)
	check(game.enemy_health() == 29 and Core.hints(game)[0].role == "core_field", "Ember Wake burns immediately and shows the field")
	Core.tick(game, start + 850)
	game.tactics.position = Vector3(4, 0, -2)
	Core.tick(game, start + 1700)
	check(game.enemy_health() == 28, "leaving the embers avoids the pulse")
	game.tactics.position = Vector3(0, 0, -2)
	Core.tick(game, start + 2550)
	check(game.enemy_health() == 27 and not Core.hints(game).is_empty(), "Banked Coals keeps the trail live for a late entrant")
	Core.tick(game, start + 2750)
	check(Core.hints(game).is_empty(), "the extended trail clears on expiration")
	check_contact_shapes(game, player)
	check_final_grave(game, player)

	arena(game, player, "storm_reed")
	player.run_upgrades["core_chain_spark"] = 1
	var second: Dictionary = game.make_scout(0, Vector3(1.75, 0, -2), 1)
	var third: Dictionary = game.make_scout(0, Vector3(3.5, 0, -2), 2)
	var last: Dictionary = game.make_scout(0, Vector3(5.25, 0, -2), 3)
	game.encounter.clear_scouts();game.encounter.register_scout(second);game.encounter.register_scout(third);game.encounter.register_scout(last)
	var spark := cast(game, player)
	Core.tick(game, spark.armed)
	check(game.enemy_health() == 28 and game.encounter.hp_for(second) == second.max_hp - 1 and game.encounter.hp_for(third) == third.max_hp - 1 and game.encounter.hp_for(last) == last.max_hp, "Chain Spark visits two distinct neighbors at most")
	check(second.rooted_until > spark.armed and third.rooted_until > spark.armed and last.rooted_until == 0, "Grounded Current roots jumps only")
	arena(game, player, "thorn_bloom")
	var near := Core.aim_cast(game.battlefield, player.pos, Vector3.FORWARD, Core.equipped(player), .8)
	check(not near.is_empty() and near.center.is_equal_approx(Vector3.FORWARD*.8), "Thorn Line stays at the near cursor")
	arena(game, player, "moon_lotus")
	game.tactics.position = Vector3(4, 0, -2)
	var moon := cast(game, player)
	Core.tick(game, moon.armed)
	Core.tick(game, moon.armed + 800)
	check(game.tactics.rooted_until == 0 and Core.hints(game).size() == 1, "empty snare stays armed")
	game.tactics.position = moon.center
	Core.tick(game, moon.armed + 2300)
	check(game.tactics.rooted_until > moon.armed + 2300 and game.enemy_health() == 28, "a late entrant is damaged and rooted")
	Core.tick(game, moon.armed + 3000)
	check(game.enemy_health() == 28, "an enemy triggers the same trap only once")
	Core.tick(game, moon.expires)
	check(Core.hints(game).is_empty(), "snare expires on schedule")
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: Core roster, delivery, cards and pilot effects")
	quit(1 if failed else 0)


func prepare_effect(game: Node, player: Dictionary, skill_id: String) -> Dictionary:
	if skill_id in ["gravity_well", "sun_pillar", "riptide", "eclipse_maw"]:
		game.tactics.position.x = 1.0
	if skill_id == "mirror_bloom":
		game.encounter.register_scout(game.make_scout(0, Vector3(0, 0, 2), 1))
	if skill_id == "ironbark":
		game.tactics.position.z = -.9
	if skill_id == "hush":
		game.tactics.winding_up = true
	if skill_id == "dewfall":
		player.slow_until = Time.get_ticks_msec() + 8000
	if skill_id == "crownlink":
		game.encounter.register_scout(game.make_scout(0, Vector3(.8, 0, -2), 1))
	return {"origin": game.tactics.position}


func verify_effect(game: Node, player: Dictionary, live: Dictionary, fixture: Dictionary) -> void:
	var elapsed: int = live.armed
	match live.skill.id:
		"spore_seal":
			check(game.tactics.rooted_until > elapsed + 750 and game.enemy_health() == 30, "Spore Seal roots without damaging")
		"dewfall":
			check(PlayerVitals.current_hp(player) == 9 and player.slow_until == 0 and player.guard_charges == 1, "Dewfall cleanses and wards on upgrade")
		"blood_siphon":
			check(PlayerVitals.current_hp(player) == 9 and game.enemy_health() == 28 and player.guard_charges == 1, "Blood Siphon heals for a hit and grants its purchased ward")
		"phantom_step":
			check(player.pos.is_equal_approx(live.center) and game.tactics.rooted_until > elapsed and player.guard_charges == 1, "Phantom Step relocates and roots on arrival")
		"moon_snare":
			check(game.enemy_health() == 28 and game.tactics.rooted_until > elapsed + 650, "Moon Snare roots a foe even without a windup")
		"gravity_well":
			check(game.tactics.position.distance_to(live.center) < Vector3(fixture.origin).distance_to(live.center) and game.tactics.rooted_until > elapsed + 400, "Gravity Well draws enemies inward and roots inside the inner ring")
		"sun_pillar":
			check(game.tactics.position.x > fixture.origin.x and game.enemy_health() == 26 and game.tactics.stagger_until > elapsed + 1600, "Sun Pillar pushes outward before the afterlight")
		"eclipse_maw":
			check(game.tactics.position.x < fixture.origin.x and game.enemy_health() == 26 and PlayerVitals.current_hp(player) == 8, "Eclipse Maw draws enemies to the seam and bites once")
		"worldbloom":
			check(game.tactics.rooted_until > elapsed and PlayerVitals.current_hp(player) == 10 and player.guard_charges == 1, "Worldbloom holds enemies and restores allies in stages")
		"rime_bloom":
			check(game.enemy_health() == 28 and game.enemy_traits.brittle == 0 and game.tactics.rooted_until > elapsed + 720, "Snap Frost shatters the Brittle stacks")
		"ironbark":
			check(PlayerVitals.current_hp(player) == 8 and player.guard_charges == 0 and game.tactics.stagger_until > elapsed + 200, "Ironbark consumes the ward and staggers nearby enemies on a block")
		"mirror_bloom":
			check(game.enemy_health() == 27 and game.encounter.hp(0) == game.encounter.scout(0).max_hp - 2, "Mirror Bloom reflects through the caster and the third bloom returns to the original spot")
		"grave_lantern":
			check(game.enemy_health() == 26 and PlayerVitals.current_hp(player) == 9, "Grave Lantern reacts once to a new nearby death")
		"riptide":
			check(game.enemy_health() == 30 and absf(game.tactics.position.x) < .05 and PlayerVitals.current_hp(player) == 9, "melee Riptide draws enemies toward the impact and heals")
		"hush":
			check(not game.tactics.winding_up and game.enemy_health() == 30, "Hush cancels a lesser enemy windup")
		"dream_lure":
			check(game.enemy_health() == 27 and game.tactics.rooted_until > elapsed + 2000 and player.guard_charges == 1, "Dream Lure bursts and its card wards nearby allies")
		"crownlink":
			var partner: Dictionary = game.encounter.scout(0)
			var now: int = live.armed + 250
			game.apply_weapon_hit(player, -1, player.pos, {"damage": 1}, now)
			check(game.encounter.hp_for(partner) == partner.max_hp - 2 and partner.rooted_until > now, "Crownlink shares and roots on a direct hit")
			game.apply_weapon_hit(player, -1, player.pos, {"damage": 1}, now + 1)
			check(game.encounter.hp_for(partner) == partner.max_hp - 2, "Crownlink consumes both ends once")


func check_contact_shapes(game: Node, player: Dictionary) -> void:
	arena(game, player, "sun_spire")
	game.tactics.position = Vector3(1, 0, -3)
	var scout: Dictionary = game.make_scout(0, Vector3(0, 0, -2), 1)
	game.encounter.register_scout(scout)
	var before: int = game.encounter.hp_for(scout)
	var live := cast(game, player)
	Core.tick(game, live.armed)
	Core.tick(game, live.armed + 900)
	check(game.enemy_health() == 30 and game.encounter.hp_for(scout) == maxi(0, before - 4), "Sun Pillar misses between rays and damages the intersection only once")

	arena(game, player, "veilcap")
	player.run_upgrades["core_spore_seal"] = 1
	var other: Dictionary = game.make_scout(0, Vector3(4, 0, -2), 1)
	game.encounter.register_scout(other)
	live = cast(game, player)
	Core.tick(game, live.armed)
	Core.tick(game, live.armed + 750)
	check(live.shapes.size() == 3 and game.tactics.rooted_until > live.armed + 750, "Spore Seal has three individually armed plates")
	other.pos = live.center
	Core.tick(game, live.armed + 1200)
	check(other.rooted_until == 0, "a spent seal cannot catch a second target until it regrows")
	Core.tick(game, live.armed + 1600)
	check(other.rooted_until > live.armed + 1600, "Double Seal rearms that plate for a new enemy")

	arena(game, player, "frostbell")
	player.run_upgrades["core_rime_bloom"] = 1
	var late: Dictionary = game.make_scout(0, Vector3(4, 0, -2), 1)
	game.encounter.register_scout(late)
	live = cast(game, player)
	Core.tick(game, live.armed)
	game.tactics.position.x = 4
	late.pos = live.center
	Core.tick(game, live.armed + 720)
	check(game.enemy_health() == 28 and game.encounter.hp_for(late) == late.max_hp and late.rooted_until == 0, "Snap Frost follows the original targets without hitting new entrants")

	arena(game, player, "moon_lotus")
	live = cast(game, player)
	Core.tick(game, live.armed)
	check(not Footprint.reaches(game.battlefield, live.shapes, live.center - Vector3.FORWARD * 1.1, live.center), "Moon Snare has a safe gap behind the crescent")


func check_final_grave(game: Node, player: Dictionary) -> void:
	arena(game, player, "gravemoss")
	player.run_upgrades["core_grave_lantern"] = 1
	var live := cast(game, player)
	Core.tick(game, live.armed)
	game.encounter.set_hp(-1, 0)
	player.pos = live.center
	game.record_enemy_death(-1, live.center, player.pos)
	Core.tick(game, live.armed + 100)
	check(PlayerVitals.current_hp(player) == 9 and not game.has_meta(Core.STATE), "Last Light heals when the final enemy dies inside the watch")


func render_fx(game: Node, skill_id: String) -> void:
	game.combat_visuals.sync(game.combat_events_snapshot(), Core.hints(game), skill_id, Vector3.ZERO)
	game.combat_visuals.step(.10)
