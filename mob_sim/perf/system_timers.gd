extends RefCounted
## Time spent in each simulation system, in microseconds. Off by default.
## Reading the wall clock here is diagnostics only: it never feeds back into the simulation,
## so enabling it cannot change results, only add a few microseconds per tick.

enum System { PERCEPTION, DECISION, EXECUTORS, ABILITIES, MOVEMENT }

const NAMES := ["perception", "decision", "executors", "abilities", "movement"]

var enabled := false
var ticks := 0
var spent_usec := PackedInt64Array()
var slowest_tick_usec := 0
var _tick_started := 0
var _mark := 0


func _init() -> void:
	reset()


func reset() -> void:
	ticks = 0
	slowest_tick_usec = 0
	spent_usec.resize(NAMES.size())
	spent_usec.fill(0)


func begin_tick() -> void:
	_tick_started = Time.get_ticks_usec()
	_mark = _tick_started


## Charges the time since the previous mark to one system.
func lap(system: System) -> void:
	var now := Time.get_ticks_usec()
	spent_usec[system] += now - _mark
	_mark = now


func end_tick() -> void:
	ticks += 1
	slowest_tick_usec = maxi(slowest_tick_usec, _mark - _tick_started)


## Mean milliseconds per tick for each system, plus the total and the slowest tick.
func report() -> Dictionary:
	var result := {}
	var total := 0
	for index in NAMES.size():
		total += spent_usec[index]
		result[NAMES[index]] = snappedf(spent_usec[index] / 1000.0 / maxi(1, ticks), 0.0001)
	result["total"] = snappedf(total / 1000.0 / maxi(1, ticks), 0.0001)
	result["slowest"] = snappedf(slowest_tick_usec / 1000.0, 0.001)
	result["ticks"] = ticks
	return result
