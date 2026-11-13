extends RefCounted

const Classes = preload("res://class_catalog.gd")
enum { WARDEN, CASTER, RANGER, REAPER, ORACLE }
static var DEFINITIONS: Array = Classes.FRAMES

const GUARD_MS := 1150
const BIND_MS := 1650
const BIND_RANGE := 5.0
