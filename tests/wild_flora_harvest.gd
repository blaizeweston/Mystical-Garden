extends "res://tests/guarded_expedition.gd"
## Full-route seed custody through the guarded host, existing inventory and altar.
const Flora = preload("res://wild_flora.gd")

# Baseline control for paired real floor generation; skip only specimen creation.
class NoSpecimen extends Flora:
	func begin(_key: String, _generate: Callable) -> void:
		pass

func run() -> void:
	if not start_save_set():
		quit(1)
		return
	var actor: Dictionary = world.players[1]
	var reserve: Dictionary = world.seed_reserve(actor)
	var points: int = world.progress.knowledge
	var first := enter_fresh(actor)
	if first.is_empty():
		quit(1)
		return
	check(not world.harvest_wild_flora(1, first.identity), "range checked on host at entrance")
	actor.pos = first.position
	var active_life = actor[PlayerLifecycle.STATE]
	actor[PlayerLifecycle.STATE] = active_life.fall()
	check(not world.harvest_wild_flora(1, first.identity), "fallen character cannot harvest")
	actor[PlayerLifecycle.STATE] = active_life
	var original: Array = actor.carried_seeds
	var locked: Array = []
	locked.make_read_only()
	actor.carried_seeds = locked
	check(not world.harvest_wild_flora(1, first.identity) and not world.wild_flora_view(1).claimed, "failed inventory admission leaves harvest available")
	actor.carried_seeds = original
	check(not world.encounter_cleared(), "live enemies present at harvest")
	world.send_action(false)
	check(actor.carried_seeds == [first.species] and world.wild_flora_view(1).claimed, "E awards exactly the selected hidden species")
	var projected: Dictionary = world.wild_flora_view(1)
	projected.species = -1
	check(world.wild_flora_view(1).species == first.species, "detached species projection")
	check(not world.harvest_wild_flora(1, first.identity), "duplicate request rejected")
	check(world.progress.knowledge == points and not world.progress.discoveries[first.species], "no discovery or Knowledge at harvest")
	world.reset_encounter(world.participation.seed())
	check(world.wild_flora_view(1).claimed and world.wild_flora_view(1).position == first.position, "same-floor reconstruction preserves the claim and position")
	clear_floor(actor, 1)
	world.set_meta(&"guarded_gameplay_test_fault", fail_stage)
	world.expedition_transitions.checkpoint(1, true)
	world.remove_meta(&"guarded_gameplay_test_fault")
	check(world.participation.floor() == 1 and world.wild_flora_view(1).claimed and actor.carried_seeds == [first.species], "failed floor transition restores original specimen, claim and cargo")
	world.expedition_transitions.checkpoint(1, true)
	var second: Dictionary = world.wild_flora_view(1)
	check(not second.is_empty() and second.species == 1 and second.identity != first.identity, "Moss available on the second encounter")
	if second.is_empty():
		quit(1)
		return
	actor.pos = second.position
	check(not world.harvest_wild_flora(1, first.identity), "old-floor intent cannot collect new specimen")
	check(world.harvest_wild_flora(1, second.identity) and actor.carried_seeds == [0,1], "second starter collected")
	clear_floor(actor, 6)
	world.expedition_transitions.checkpoint(1, false)
	check(not world.participation.active() and reserve.unknown == [0,1] and reserve.stock[0] == 0 and reserve.stock[1] == 0, "extraction delivers the two unidentified species")
	check(world.wild_flora_view(1).is_empty() and world.wild_flora.savepoint().specimen.is_empty(), "floor discarded at extraction")
	actor.pos = world.stage.altar_position()
	var before_identify: int = world.progress.knowledge
	world.garden_action(1, "altar_identify")
	world.garden_action(1, "altar_identify")
	check(reserve.stock[0] == 1 and reserve.stock[1] == 1 and reserve.unknown.is_empty(), "altar identifies both exact harvested species")
	check(world.progress.knowledge == before_identify + 8, "shared first discoveries award four Knowledge each")
	var available: Callable = world.InventoryModel.garden_or_party_has_seed.bind(world.progress, world.players)
	check(Flora.starter(1, available) == -1 and Flora.starter(2, available) == -1, "established Garden uses ordinary rolls")
	# Use fresh Garden data per case, with real specimen seeds passing through real settlement.
	reserve.stock.fill(0)
	world.progress.discoveries.fill(false)
	var banked := enter_fresh(actor)
	if not banked.is_empty():
		actor.pos = banked.position
		check(world.harvest_wild_flora(1, banked.identity), "new expedition has its own claim")
		clear_floor(actor, 3)
		world.progress.heart.unlocked.append("checkpoint_deposit")
		world.bank_checkpoint_item(1, actor, "deposit_seed_0")
		check(reserve.unknown == [banked.species] and actor.carried_seeds.is_empty(), "courier banks the exact species")
		world.expedition_transitions.abandon(1)
		check(reserve.unknown == [banked.species] and not world.participation.active(), "courier delivery survives abandonment once")
	reserve.unknown.clear()
	var lost := enter_fresh(actor)
	if not lost.is_empty():
		actor.pos = lost.position
		world.harvest_wild_flora(1, lost.identity)
		world.expedition_transitions.abandon(1)
		check(reserve.unknown.is_empty() and actor.carried_seeds.is_empty(), "unbanked specimen is forfeited")
	var kept := enter_fresh(actor)
	if not kept.is_empty():
		actor.pos = kept.position
		world.harvest_wild_flora(1, kept.identity)
		world.InventoryModel.transfer(world, actor, "carry", "pouch", "unidentified_seed", 1)
		clear_floor(actor, 1)
		world.expedition_transitions.checkpoint(1, true)
		var other: Dictionary = world.wild_flora_view(1)
		if not other.is_empty():
			actor.pos = other.position
			world.harvest_wild_flora(1, other.identity)
		check(actor.carried_seeds == [1], "unprotected second seed before wipe")
		actor[PlayerLifecycle.STATE] = actor[PlayerLifecycle.STATE].fall()
		check(world.expedition_transitions.finish_failed(), "wipe settlement commits")
		check(reserve.unknown == [kept.species] and actor.carried_seeds.is_empty() and actor.safe_items.is_empty(), "only pouched species recovered from wipe")
	verify_spawn_equivalence(actor, reserve)
	close_world()
	await process_frame
	if not failed:
		print("PASS: shared starter specimens, host admission, floor rollback, immutable carry, extraction, altar, courier, abandonment and wipe")
	quit(int(failed))

func enter_fresh(actor: Dictionary) -> Dictionary:
	actor.pos = world.stage.gate_position()
	world.expedition_transitions.enter(1)
	var specimen: Dictionary = world.wild_flora_view(1)
	check(world.participation.contains(1) and not specimen.is_empty() and specimen.species == 0 and not specimen.claimed, "fresh Thorn Bloom on entry")
	return specimen

func verify_spawn_equivalence(actor: Dictionary, reserve: Dictionary) -> void:
	var participation_before: Dictionary = world.participation.savepoint()
	reserve.unknown.clear()
	reserve.stock.fill(0)
	world.progress.discoveries.fill(false)
	ExpeditionCase.set_membership(world, actor, true)
	var natural: Flora = world.wild_flora
	var control := NoSpecimen.new()
	var placements := 0
	var members := 0
	var starters := 0
	for biome in 3:
		for floor_number: int in [1, 2, 7, 17, 32, 52, 61]:
			ExpeditionCase.set_world(world, {"destination": biome, "depth": 1 + (floor_number - 1) % 6,
				"encounter_number": floor_number})
			world.rng.seed = 18133 + floor_number
			world.map_rng.seed = 731 + biome * 719 + floor_number * 31
			var before_combat: int = world.rng.state
			var before_map: int = world.map_rng.state
			world.wild_flora = control
			world.start_encounter()
			var expected := formation()
			var next_combat: int = world.rng.state
			var next_map: int = world.map_rng.state
			world.wild_flora = natural
			natural.clear()
			world.rng.state = before_combat
			world.map_rng.state = before_map
			world.start_encounter()
			check(formation() == expected and world.rng.state == next_combat and world.map_rng.state == next_map,
				"same post-formation enemy positions, kinds and RNG on floor %d biome %d" % [floor_number, biome])
			members += expected.size()
			var specimen: Dictionary = world.wild_flora_view(1)
			if floor_number <= 2:
				check(specimen.get("species", -1) == floor_number - 1, "introductory species always fits live encounter")
				starters += int(not specimen.is_empty())
			if not specimen.is_empty():
				placements += 1
				for enemy: Array in expected:
					check(specimen.position.distance_to(enemy[1]) >= 2.0, "live enemy clearance after formation")
	world.participation.restore_savepoint(participation_before)
	natural.clear()
	print("FLORA_LIVE floors=21 members=", members, " placed=", placements, " forced_starters=", starters)

func formation() -> Array:
	var result := [[world.enemy_kind, world.tactics.position]]
	for slot in world.encounter.scout_count():
		result.append([world.encounter.scout(slot).kind, world.encounter.position(slot)])
	return result
