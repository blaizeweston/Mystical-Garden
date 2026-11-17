extends RefCounted
## Absolute combat amounts have a scale. Counts, times, distances and ratios keep their authored units.

const LIVE_HP_PER_POINT := 1
const PROTOTYPE_HP_PER_POINT := 10
const REVIVE_POINTS := 2
const BURST_POINTS := 3
const RANGED_MINIMUM_POINTS := 2


static func points(authored_points: int, hp_per_point: int = LIVE_HP_PER_POINT) -> int:
	return authored_points * hp_per_point


static func maximum(base_hp: int, bonus_hp: int, lost_hp: int, hp_per_point: int = LIVE_HP_PER_POINT) -> int:
	return maxi(points(REVIVE_POINTS, hp_per_point), base_hp + bonus_hp - lost_hp)


static func can_revive(max_hp: int, hp_per_point: int = LIVE_HP_PER_POINT) -> bool:
	var cost := points(REVIVE_POINTS, hp_per_point)
	return max_hp - cost >= cost


static func damage_taken(health: int, amount: int) -> int:
	return mini(maxi(0, health), maxi(0, amount))


static func floor_recovery(biome_boundary: bool, hp_per_point: int = LIVE_HP_PER_POINT) -> int:
	return points(2 if biome_boundary else 1, hp_per_point)


static func enemy_capacity(base_points: int, party_multiplier: float, hp_per_point: int = LIVE_HP_PER_POINT) -> int:
	# Preserve the shipped ceiling before converting. Scaling first changes co-op hit counts.
	return points(maxi(1, ceili(base_points * party_multiplier)), hp_per_point)


static func armored_damage(amount: int, hp_per_point: int = LIVE_HP_PER_POINT) -> int:
	return maxi(hp_per_point, amount - hp_per_point)


static func counts_as_burst(damage: int, hp_per_point: int = LIVE_HP_PER_POINT) -> bool:
	return damage >= points(BURST_POINTS, hp_per_point)


static func counts_as_ranged(ranged_damage: int, total_damage: int, hp_per_point: int = LIVE_HP_PER_POINT) -> bool:
	return ranged_damage >= points(RANGED_MINIMUM_POINTS, hp_per_point) and ranged_damage * 3 >= total_damage * 2


static func threat_from_hit(damage: int, hp_per_point: int = LIVE_HP_PER_POINT) -> float:
	return float(damage) / hp_per_point


static func boss_phase(health: int, max_hp: int) -> int:
	return 2 if health <= max_hp * .30 else 1 if health <= max_hp * .65 else 0
