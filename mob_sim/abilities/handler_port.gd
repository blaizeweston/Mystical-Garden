extends RefCounted
## What ability handlers may ask of the world. The training simulation implements it in
## sim_handler_port.gd and the Neural Arena in neural_arena/arena_handler_port.gd.
## Positions are on the ground plane, x and z.


func tick() -> int:
	return 0


func line_clear(_from: Vector2, _to: Vector2, _clearance: float = 0.0) -> bool:
	return false


func position(_slot: int) -> Vector2:
	return Vector2.INF


func alive(_slot: int) -> bool:
	return false


func reach(_slot: int) -> float:
	return 0.0


## Living fighting allies (not supports) within radius of center with a clear line from it, nearest first.
func fighters(_slot: int, _center: Vector2, _radius: float) -> PackedInt32Array:
	return PackedInt32Array()


## Unconsumed corpses of non-summoned allies within radius with a clear line, nearest first, as
## dictionaries with an id and a point.
func corpses(_slot: int, _radius: float, _exclude: int = -1) -> Array:
	return []


func corpse_still_there(_id: int, _point: Vector2) -> bool:
	return false


func consume_corpse(_slot: int, _id: int) -> void:
	pass


## Heals a mob from a corpse and returns the health restored.
func heal_from_corpse(_slot: int, _spare: bool) -> int:
	return 0


func haste(_slot: int, _ms: int) -> void:
	pass


## Orders a mob onto a player for ms, walking via a route point first unless via is Vector2.INF.
func command(_slot: int, _player: int, _ms: int, _via: Vector2) -> void:
	pass


func player_position(_player: int) -> Vector2:
	return Vector2.INF


func hatch_safe(_point: Vector2) -> bool:
	return false


func hatch(_slot: int, _point: Vector2) -> bool:
	return false


## Per-mob scratch that lasts for the mob's life, for handler state such as a used cover step.
func memory(_slot: int) -> Dictionary:
	return {}


## Where the mob's last volley was stopped, or Vector2.INF.
func denied_aim(_slot: int) -> Vector2:
	return Vector2.INF


## The ally a Hollowback last failed to shelter, or -1.
func shelter_escort(_slot: int) -> int:
	return -1


func shelter_radius() -> float:
	return 0.0


## Moves a mob directly, as a canopy shift does.
func move(_slot: int, _to: Vector2) -> void:
	pass
