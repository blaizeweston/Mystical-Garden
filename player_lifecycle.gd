extends RefCounted
## Host-owned player life identity and incapacitation. Each new life receives
## a fresh generation, including when a peer ID is reused. A fall suspends
## active actions. Already-accepted grants may retain that life until revival.

const Participation = preload("res://expedition_participation.gd")

const STATE := "player_lifecycle"
enum Phase { READY, DOWNED }

class Life extends RefCounted:
	static var _last_generation: int = 0

	var _generation: int
	var _phase: Phase

	func _init(life_generation: int, phase: Phase = Phase.READY) -> void:
		_generation = life_generation
		_phase = phase

	func generation() -> int:
		return _generation

	func fallen() -> bool:
		return _phase != Phase.READY

	func fall() -> Life:
		return self if _phase == Phase.DOWNED else Life.new(_generation, Phase.DOWNED)

	func clear_inactive() -> Life:
		return next_life() if fallen() else self

	static func reserve_generation(generation_id: int) -> void:
		_last_generation = maxi(_last_generation,generation_id)

	static func next_life() -> Life:
		_last_generation += 1
		return Life.new(_last_generation)

## Use at admission, expedition entry, revival and return to the Garden.
## Allocation deliberately never rolls back. The prior actor snapshot can
## restore its old generation without reusing one reserved by an aborted life.
static func start_life() -> Life:
	return Life.next_life()

static func generation(record: Dictionary) -> int:
	var life: Life = record.get(STATE)
	return life.generation() if life != null else -1

static func matches(record: Dictionary, captured_generation: int) -> bool:
	return captured_generation > 0 and generation(record) == captured_generation

## The participation owner supplies the existing post-return party hold.
## Guest presentation uses the existing detached fallen flag.
static func fallen(record: Dictionary) -> bool:
	var life: Life = record.get(STATE)
	return (life.fallen() or Participation.is_waiting(record)) if life != null else bool(record.get("fallen", false))
