extends RefCounted
## Native preview HP for encounter populations and enemy attacks. The legacy path uses authored points.
const Preview = preload("res://combat_balance_preview.gd")
const Config = preload("res://encounter_config.gd")
const Catalog = preload("res://enemy_catalog.gd")
const PRIMARY_HAZARD_MOVES := ["falling_fruit","tidal_ring","grasping_pool","spore_constellation"]
const FIRST_BOSS_FLOOR := 10
static var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/enemies/preview_scaling.json"))


static func party_factor(profile: Dictionary, floor_offset: int, party: int) -> float:
	var per_peer := float(profile.coop_per_peer)
	per_peer += minf(float(profile.get("coop_depth_cap",0)), floor_offset * float(profile.get("coop_depth_per_floor",0)))
	return 1.0 + per_peer * (maxi(1,party)-1)


static func scout_hp(definition: Dictionary, floor_number: int, cycle: int, tier: int, party: int, juvenile: bool = false) -> int:
	var floor_offset := maxi(0,floor_number-1)
	if juvenile:
		var hatch: Dictionary = tuning.juvenile
		var base := float(hatch.hp) + floor_offset * float(hatch.hp_per_floor) + cycle * float(hatch.hp_per_loop)
		return roundi(base * party_factor(hatch,floor_offset,party))
	var profile: Dictionary = tuning.regular
	var base := float(definition.preview_hp) + floor_offset * float(profile.hp_per_floor)
	base += tier * float(profile.hp_per_tier) + cycle * float(profile.hp_per_loop)
	return roundi(base * party_factor(profile,floor_offset,party))


static func elite_hp(definition: Dictionary, floor_number: int, depth: int, cycle: int, party: int) -> int:
	var profile: Dictionary = tuning.elite
	var floor_offset := maxi(0,floor_number-1)
	var base := float(definition.preview_hp) * float(profile.hp_multiplier) + floor_offset * float(profile.hp_per_floor)
	base += (depth-1) * float(profile.hp_per_biome_step) + cycle * float(profile.hp_per_loop)
	base += cycle * cycle * float(profile.hp_per_loop_squared)
	if depth==Config.BIOME_LENGTH:
		base += float(profile.biome_end_hp)
	return roundi(base * party_factor(profile,floor_offset,party))


static func boss_hp(definition: Dictionary, floor_number: int, cycle: int, party: int) -> int:
	var profile: Dictionary = tuning.boss
	var floor_offset := maxi(0,floor_number-FIRST_BOSS_FLOOR)
	var base := float(definition.preview_hp) + floor_offset * float(profile.hp_per_floor) + cycle * float(profile.hp_per_loop)
	return roundi(base * party_factor(profile,floor_offset,party))


static func authored_hit(hp: int) -> float:
	return float(hp) / Preview.scale()


static func scout_hit(game: Node, definition: Dictionary, scout: Dictionary) -> float:
	if not Preview.enabled or game.destination==game.Campaign.HEART:
		return int(definition.damage)+game.difficulty_cycle/2
	var floor_offset := maxi(0,int(game.encounter_number)-1)
	var profile: Dictionary = tuning.juvenile if int(scout.get("mutations",0)) & Catalog.JUVENILE else tuning.regular
	var base := float(profile.get("hit_hp",definition.preview_hit_hp))
	var amount := base + floor_offset * float(profile.hit_per_floor) + int(game.difficulty_cycle) * float(profile.hit_per_loop)
	if scout.get("gate_elite",false):
		amount *= float(tuning.elite.hit_multiplier)
		if game.depth==Config.BIOME_LENGTH:
			amount += float(tuning.elite.biome_end_hit_hp)
	return authored_hit(roundi(amount))


static func boss_hit(game: Node, definition: Dictionary, move: String) -> float:
	if not Preview.enabled:
		return int(definition.damage)+int(game.difficulty_cycle)/3
	var profile: Dictionary = tuning.boss
	var floor_offset := maxi(0,int(game.encounter_number)-FIRST_BOSS_FLOOR)
	var amount := float(definition.preview_hit_hp) + floor_offset * float(profile.hit_per_floor)
	amount += int(game.difficulty_cycle) * float(profile.hit_per_loop) + int(game.tactics.boss_phase) * float(profile.hit_per_phase)
	amount += float(tuning.boss_move_bonus_hp.get(move,0))
	return authored_hit(roundi(amount))


static func hazard_hit(game: Node, kind: String, damage: float, boss_move: String) -> float:
	if not Preview.enabled or game.destination==game.Campaign.HEART:
		return damage
	if not boss_move.is_empty():
		var ratio: float = tuning.boss.main_hazard_ratio if boss_move in PRIMARY_HAZARD_MOVES else tuning.boss.followup_hazard_ratio
		return authored_hit(maxi(1,roundi(Preview.effect_hp(damage)*ratio)))
	var profile: Dictionary = tuning.hazards
	var base: float = profile.base_hp.get(kind,Preview.effect_hp(damage))
	return authored_hit(roundi(base+maxi(0,int(game.encounter_number)-1)*float(profile.hit_per_floor)+int(game.difficulty_cycle)*float(profile.hit_per_loop)))


static func corpse_heal(game: Node, actor: Dictionary, spare: bool) -> int:
	var center := Preview.hp(1 if spare else 2)
	if Preview.enabled:
		center += mini(int(tuning.corpse_depth_bonus_cap), roundi(maxi(0,int(game.encounter_number)-1)*float(tuning.corpse_depth_hp_per_floor)))
		var cap := maxi(1,floori(float(actor.get("max_hp",game.encounter.hp_for(actor)))*float(tuning.corpse_hp_fraction)))
		return mini(cap,Preview.roll_heal_hp(mini(center,cap)))
	return center


static func armor(amount: int) -> int:
	return maxi(1,roundi(amount*float(tuning.armor_damage_ratio))) if amount>0 else 0


static func exposed_bonus(amount: int) -> int:
	if not Preview.enabled:
		return Preview.hp(1)
	return maxi(int(tuning.boss.exposed_minimum_bonus_hp),roundi(amount*float(tuning.boss.exposed_bonus_ratio)))


static func extra_scouts(legacy: int) -> int:
	return int(tuning.coop_extra_scouts) if Preview.enabled else legacy


static func boss_escorts(game: Node, available: int) -> int:
	if not Preview.enabled:
		return mini(4,available)
	var adds := 1 if Catalog.get_kind(game.tactics.boss_kind).id=="matriarch" else 2
	return mini(available,adds+mini(2,int(game.encounter_party_size)-1))


static func pressure_interval(cycle: int, wave: int) -> int:
	var policy: Dictionary = tuning.reinforcements
	return maxi(int(policy.minimum_interval_ms),int(policy.start_ms)-maxi(0,cycle-1)*int(policy.per_loop_ms)-wave*int(policy.per_wave_ms))


static func pressure_limit(cycle: int) -> int:
	var policy: Dictionary = tuning.reinforcements
	return mini(int(policy.maximum_wave_limit),int(policy.starting_wave_limit)+maxi(0,cycle-1))


static func reinforcement_hp(regular_hp: int) -> int:
	return maxi(1,roundi(regular_hp*float(tuning.reinforcements.hp_multiplier)))


static func trace_encounter(game: Node, desired: int) -> void:
	if not Preview.enabled or not game.expedition_active():
		return
	var pack_hp := 0
	for slot in game.encounter.scout_count():
		pack_hp += int(game.encounter.scout(slot).max_hp)
	game.Journal.event("combat","encounter_balance",{"floor":game.encounter_number,"loop":game.difficulty_cycle,
		"party_size":game.encounter_party_size,"leader_species":Catalog.get_kind(game.enemy_kind).id,
		"leader_hp":game.encounter.hp(-1),"boss":game.tactics.boss_kind>=0,"scout_budget":desired,"scouts":game.encounter.scout_count(),"scout_hp":pack_hp})


static func errors(definitions: Array) -> Array[String]:
	var result: Array[String] = []
	for definition in definitions:
		for key in ["preview_hp","preview_hit_hp"]:
			var value = definition.get(key,0)
			if not (value is int or value is float) or not is_finite(float(value)) or float(value)<1.0 or float(value)!=floorf(float(value)):
				result.append("Enemy %s needs positive integer %s." % [definition.id,key])
	for group in ["regular","elite","boss","juvenile","hazards","reinforcements"]:
		if not tuning.get(group) is Dictionary:
			result.append("Missing enemy preview tuning group "+group)
	return result
