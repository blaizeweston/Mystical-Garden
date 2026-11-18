extends RefCounted
## Simulation time in whole ticks. Mob timers never read the wall clock.

const TICKS_PER_SECOND := 60
const DT := 1.0 / TICKS_PER_SECOND

var tick := 0


func advance() -> void:
	tick += 1


static func from_ms(milliseconds: float) -> int:
	return ceili(milliseconds * TICKS_PER_SECOND / 1000.0 - 0.000001)


static func to_seconds(ticks: int) -> float:
	return ticks * DT
