extends RefCounted
## Loads the native navigation extension and bakes it from a configured Battlefield.
## The Battlefield is only read. Nothing here changes current enemy behaviour.

const EXTENSION := "res://mob_sim/mob_nav.gdextension"
const CLASS_NAME := &"MobNavWorld"
const FLOOR_CELL := 0.5
const ORIGIN := Vector2(-31.0, -30.0)
const FLOOR_SIZE := Vector2i(124, 120)

const NEAREST_TARGET := -1
enum Mode { HOLD, SEEK, FLEE, DIRECT }


static func ensure_loaded() -> bool:
	if ClassDB.class_exists(CLASS_NAME):
		return true
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
	mask.resize(FLOOR_SIZE.x * FLOOR_SIZE.y)
	var offset := Vector2i(roundi(ORIGIN.x / FLOOR_CELL), roundi(ORIGIN.y / FLOOR_CELL))
	if field.procedural and field.surface != null:
		for cell: Vector2i in field.surface.cells:
			var local: Vector2i = cell - offset
			if local.x >= 0 and local.y >= 0 and local.x < FLOOR_SIZE.x and local.y < FLOOR_SIZE.y:
				mask[local.x + local.y * FLOOR_SIZE.x] = 1
		return mask
	var region: Rect2i = field.REGION
	var low := Vector2(region.position) - Vector2.ONE * 0.5
	var high := Vector2(region.end) - Vector2.ONE * 0.5
	for z in FLOOR_SIZE.y:
		for x in FLOOR_SIZE.x:
			var corner := ORIGIN + Vector2(x, z) * FLOOR_CELL
			if corner.x >= low.x and corner.y >= low.y and corner.x + FLOOR_CELL <= high.x and corner.y + FLOOR_CELL <= high.y:
				mask[x + z * FLOOR_SIZE.x] = 1
	return mask


static func barrier_rects(field: RefCounted) -> PackedFloat32Array:
	var rects := PackedFloat32Array()
	for rect: Rect2 in field.barriers:
		rects.append_array(PackedFloat32Array([rect.position.x, rect.position.y, rect.end.x, rect.end.y]))
	return rects


static func bake(world: RefCounted, field: RefCounted) -> int:
	return world.bake(FLOOR_SIZE.x, FLOOR_SIZE.y, ORIGIN.x, ORIGIN.y, floor_mask(field), barrier_rects(field))
