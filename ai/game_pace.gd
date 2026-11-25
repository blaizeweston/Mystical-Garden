extends RefCounted
## The game's floor scaling of mob speed, wind-ups and recovery (combat_director.gd speed, windup and recovery),
## as the scales a training spawn request takes. Training reads the same balance values (assets/content/
## balance.json "combat") so mobs train at the pace they will have in the game. ai/tests/training_checks.gd
## compares these against combat_director.gd on a stand-in game for every floor.
##
## The game's 420 ms floors on wind-up and recovery are not applied here: every catalog wind-up and recovery is
## long enough that the floor scaling never reaches them.

const GameBalance = preload("res://game_balance.gd")


## The factor a species' base speed is multiplied by on this floor: the game's multiplier and per-floor growth,
## with its speed cap applied to the scaled speed.
static func speed_scale(base_speed: float, floor_number: int) -> float:
	if base_speed <= 0.0:
		return 1.0
	var combat: Dictionary = GameBalance.values.combat
	var growth := minf(0.5, (floor_number - 1) * float(combat.speed_per_floor))
	return minf(float(combat.speed_cap), base_speed * (float(combat.speed_multiplier) + growth)) / base_speed


## Wind-ups shorten by 0.7% a floor, to at most 22% shorter.
static func windup_scale(floor_number: int) -> float:
	return maxf(0.78, 0.98 - (floor_number - 1) * 0.007)


## Recovery shortens by 0.8% a floor, to at most 28% shorter.
static func recovery_scale(floor_number: int) -> float:
	return maxf(0.72, 0.92 - (floor_number - 1) * 0.008)
