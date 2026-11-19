extends RefCounted
## Loads the native navigation extension and bakes it from a configured Battlefield.
## The Battlefield is only read. Nothing here changes current enemy behaviour.

const EXTENSION := "res://mob_sim/mob_nav.gdextension"
const CLASS_NAME := &"MobNavWorld"
const WINDOWS_LIBRARY := "res://mob_sim/bin/mob_nav.dll"
const FLOOR_CELL := 0.5
const ORIGIN := Vector2(-31.0, -30.0)
const FLOOR_SIZE := Vector2i(124, 120)

const NEAREST_TARGET := -1
enum Mode { HOLD, SEEK, FLEE, DIRECT }


static func ensure_loaded() -> bool:
	if ClassDB.class_exists(CLASS_NAME):
		return true
	# The backend is optional in source checkouts; report unavailability without engine load errors.
	if OS.get_name()=="Windows" and not FileAccess.file_exists(WINDOWS_LIBRARY): return false
	var status := GDExtensionManager.load_extension(EXTENSION)
	if status != GDExtensionManager.LOAD_STATUS_OK and status != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		return false
	return ClassDB.class_exists(CLASS_NAME)


static func create(max_agents: int, max_targets: int) -> RefCounted:
	if not ensure_loaded():
		return null
	var world: RefCounted = ClassDB.instantiate(CLASS_NAME)
	return world if world != null and world.initialize(max_agents, max_targets) == OK else null


## One byte per half-unit floor cell, matching the Battlefield's own floor test.
static func floor_mask(field: RefCounted) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(FLOOR_SIZE.x*FLOOR_SIZE.y)
	for z in FLOOR_SIZE.y:
		for x in FLOOR_SIZE.x:
			var center := ORIGIN+(Vector2(x,z)+Vector2.ONE*.5)*FLOOR_CELL
			mask[x+z*FLOOR_SIZE.x]=int(not field.occupied(Vector3(center.x,0,center.y),FLOOR_CELL*sqrt(2.0)*.5))
	return mask


static func barrier_rects(field: RefCounted) -> PackedFloat32Array:
	var rects := PackedFloat32Array()
	for rect: Rect2 in field.barriers:
		rects.append_array(PackedFloat32Array([rect.position.x, rect.position.y, rect.end.x, rect.end.y]))
	return rects


static func bake(world: RefCounted, field: RefCounted) -> int:
	return world.bake(FLOOR_SIZE.x, FLOOR_SIZE.y, ORIGIN.x, ORIGIN.y, floor_mask(field), barrier_rects(field))
