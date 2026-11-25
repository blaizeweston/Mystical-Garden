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
	world.InventoryModel.put(world,actor,"carry",{"item":"boss_mystery_seed","quantity":1,"lineages":{"ghost_fern":1}})
	clear_floor(actor, 6)
	world.expedition_transitions.checkpoint(1, false)
	check(world.progress.archive.garden.get("wild")==2 and world.progress.archive.garden.get("extracts")==1,"two accepted specimens and one successful expedition enter the Archive")
	check(not world.participation.active() and reserve.unknown == [0,1] and reserve.stock[0] == 0 and reserve.stock[1] == 0, "extraction delivers the two unidentified species")
	check(world.wild_flora_view(1).is_empty() and world.wild_flora.savepoint().specimen.is_empty(), "floor discarded at extraction")
	var extracted: Dictionary=world.InventoryModel.take(world,actor,"stash","boss_mystery_seed",1)
	check(extracted.get("lineages",{})=={"ghost_fern":1},"extraction retains fixed Ancient contents")
	actor.pos = world.stage.altar_position()
	var before_identify: int = world.progress.knowledge
	world.send_altar_action("identify",[],1)
	world.send_altar_action("identify",[],1)
	check(reserve.unknown==[1],"duplicate identification leaves second seed concealed")
	world.send_altar_action("identify",[],2)
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
		ExpeditionCase.returning_root(world,actor,"return-seed")
		world.garden_action(1,ExpeditionCase.deposit_request(world,actor,"unidentified_seed"))
		check(reserve.unknown == [banked.species] and actor.carried_seeds.is_empty(), "courier banks the exact species")
		clear_floor(actor,6)
		world.InventoryModel.put(world,actor,"carry",{"item":"boss_mystery_seed","quantity":2,"lineages":{"ironroot":2}})
		ExpeditionCase.returning_root(world,actor,"return-ancient")
		var deposit := ExpeditionCase.deposit_request(world,actor,"boss_mystery_seed")
		var original_position: Vector3=actor.pos
		actor.pos+=Vector3.RIGHT*4
		world.garden_action(1,deposit)
		actor.pos=original_position
		actor[PlayerLifecycle.STATE]=actor[PlayerLifecycle.STATE].fall()
		world.garden_action(1,deposit)
		actor[PlayerLifecycle.STATE]=PlayerLifecycle.start_life()
		world.garden_action(1,deposit)
		check(world.can_use_returning_root(actor) and world.InventoryModel.counts(world,actor,"carry").get("boss_mystery_seed")==2,"distance, fallen state and prior life all refuse with no debit")
		deposit=ExpeditionCase.deposit_request(world,actor,"boss_mystery_seed")
		world.garden_action(1,deposit)
		world.garden_action(1,deposit)
		world.expedition_transitions.abandon(1)
		check(world.InventoryModel.extra_stash(world,actor).get("boss_mystery_seed",{})=={"ironroot":1} and actor.carried_items.is_empty(),"exactly one courier Ancient survives abandonment")
		check(reserve.unknown == [banked.species] and not world.participation.active(), "courier delivery survives abandonment once")
	reserve.unknown.clear()
	var lost := enter_fresh(actor)
	if not lost.is_empty():
		actor.pos = lost.position
		world.harvest_wild_flora(1, lost.identity)
		world.expedition_transitions.abandon(1)
		check(reserve.unknown.is_empty() and actor.carried_seeds.is_empty(), "unbanked specimen is forfeited")
		check(world.progress.archive.garden.get("wild")==4 and world.progress.archive.garden.get("roots")==2,"forfeited loot still counts as harvested, duplicated root requests count only accepted units")
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
		check(world.progress.archive.garden.get("wipes")==1 and world.progress.archive.garden.get("extracts")==1,"one wiped expedition does not count as extraction")
		check(reserve.unknown == [kept.species] and actor.carried_seeds.is_empty() and actor.safe_items.is_empty(), "only pouched species recovered from wipe")
	verify_spawn_equivalence(actor, reserve)
	verify_gathering(actor)
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

func verify_gathering(actor: Dictionary) -> void:
	var original_membership: Dictionary=world.participation.savepoint()
	ExpeditionCase.set_membership(world,actor,true)
	var before: int=world.progress.knowledge
	var character: String=world._kill_reward_identity(1,actor)
	for id in ["careful_gathering","wild_harvest","refined_gathering","botanical_awareness","root_resonance"]:
		world.progress.heart.unlocked.append(id)
	var species: int=world.Seeds.index_of("moon_lotus")
	var ordinary: int=world.Seeds.DEFINITIONS[species].part
	var refined: int=world.Parts.rare_part(species)
	world.progress.discoveries[species]=false
	var observed: Dictionary={}
	for i in 180:
		var key: String="gather/%d"%i
		var extra:=Flora.bonus_roll(key,character,"seed")<0.25
		var rare:=Flora.bonus_roll(key,character,"refined")<0.15
		var outcome: String=str([extra,rare])
		if observed.has(outcome): continue
		observed[outcome]=true
		world.wild_flora.begin(key,func():return {"species":species,"position":actor.pos})
		var plant: Dictionary=world.wild_flora_view(1)
		check(plant.resonance and Flora.aware(plant,actor.pos+Vector3.RIGHT*6,func(_a,_b):return true),"unfamiliar and within inclusive six metres")
		check(not Flora.aware(plant,actor.pos+Vector3.RIGHT*6.01,func(_a,_b):return true) and not Flora.aware(plant,actor.pos,func(_a,_b):return false),"range and occlusion suppress awareness")
		var parts: Array=actor.carried_parts
		var seeds: Array=actor.carried_seeds.duplicate()
		var ordinary_before: int=parts[ordinary]
		var rare_before: int=parts[refined]
		var locked:=parts.duplicate()
		locked.make_read_only()
		actor.carried_parts=locked
		check(not world.harvest_wild_flora(1,key) and not world.wild_flora_view(1).claimed and actor.carried_seeds==seeds,"rejected bundle credits nothing")
		actor.carried_parts=parts
		check(world.harvest_wild_flora(1,key) and not world.harvest_wild_flora(1,key),"retry claims once")
		check(actor.carried_seeds.slice(seeds.size())==([species,species] if extra else [species]) and parts[ordinary]==ordinary_before+1 and parts[refined]==rare_before+int(rare),"exact deterministic species and part bundle")
		check(not Flora.aware(world.wild_flora_view(1),actor.pos,func(_a,_b):return true),"claimed plant no longer indicated")
	check(observed.size()==4 and before==world.progress.knowledge and not world.progress.discoveries[species],"independent bonus outcomes, no permanent discovery")
	world.progress.discoveries[species]=true
	check(not world.wild_flora_view(1).resonance,"shared Garden discovery suppresses resonance")
	world.participation.restore_savepoint(original_membership)
