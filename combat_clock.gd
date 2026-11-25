extends RefCounted
## The time source for combat rules. The live game always reads the real clock.
## The Neural Arena switches to fixed steps so fights can pause, slow down and run faster than real time.

const TICKS_PER_SECOND := 60

static var _stepped := false
static var _start_ms := 0
static var _ticks := 0
static var _resume_offset_ms := 0

static func resume_at(saved_ms: int) -> void:
	_resume_offset_ms = saved_ms - Time.get_ticks_msec()

static func reset_live() -> void:
	_resume_offset_ms = 0


# Fixed simulation ticks convert to whole milliseconds.
@warning_ignore_start("integer_division")
static func now() -> int:
	return _start_ms + _ticks * 1000 / TICKS_PER_SECOND if _stepped else Time.get_ticks_msec() + _resume_offset_ms


@warning_ignore_restore("integer_division")
static func is_stepped() -> bool:
	return _stepped


## Starts fixed-step time at the given millisecond value.
static func begin_stepped(start_ms: int) -> void:
	_stepped = true
	_start_ms = start_ms
	_ticks = 0


## Advances fixed-step time by one simulation tick.
static func step() -> void:
	_ticks += 1


## Returns combat to the real clock.
static func end_stepped() -> void:
	_stepped = false
	_ticks = 0
