extends RefCounted
## Loads the native navigation extension and bakes it from a configured Battlefield.
## The Battlefield is only read. Nothing here changes current enemy behaviour.

const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
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


## One byte per floor cell where a flyer may be: anywhere a walker may be (floor is floor_mask's result),
## and also over water and low obstacles, which block walking but not flight or sight. Only tall cover, the
## cover that stops shots, the arena edge and the barriers (added by the core) stop flyers. Each piece of
## cover marks only the cells inside its own bounds, so the cost follows the cover, not the map.
static func air_mask(field: RefCounted, floor: PackedByteArray) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(FLOOR_SIZE.x*FLOOR_SIZE.y)
	var ground: RefCounted = field.ground
	var outline: PackedVector2Array = ground.arena_outline
	for z in FLOOR_SIZE.y:
		for x in FLOOR_SIZE.x:
			var center := ORIGIN+(Vector2(x,z)+Vector2.ONE*.5)*FLOOR_CELL
			var inside: bool
			if outline.is_empty():
				inside = ground.cells.has(Grid.world_to_cell(center, ground.spacing))
			else:
				inside = Geometry2D.is_point_in_polygon(center, outline)
			mask[x+z*FLOOR_SIZE.x]=int(inside or floor[x+z*FLOOR_SIZE.x]!=0)
	var margin := FLOOR_CELL*sqrt(2.0)*.5
	for feature: Dictionary in ground.projectile_cover:
		var bounds: Rect2 = Rect2(feature.bounds).grow(margin)
		var low := Vector2i(((bounds.position-ORIGIN)/FLOOR_CELL).floor()).max(Vector2i.ZERO)
		var high := Vector2i(((bounds.end-ORIGIN)/FLOOR_CELL).ceil()).min(FLOOR_SIZE)
		for z in range(low.y, high.y):
			for x in range(low.x, high.x):
				var at := x+z*FLOOR_SIZE.x
				if mask[at]!=0 and floor[at]==0 and Shape.signed_distance(feature, ORIGIN+(Vector2(x,z)+Vector2.ONE*.5)*FLOOR_CELL) <= margin:
					mask[at]=0
	return mask


static func barrier_rects(field: RefCounted) -> PackedFloat32Array:
	var rects := PackedFloat32Array()
	for rect: Rect2 in field.barriers:
		rects.append_array(PackedFloat32Array([rect.position.x, rect.position.y, rect.end.x, rect.end.y]))
	return rects


## Bakes the ground layer, then the air layer, which also carries sight. Returns the ground bake's status;
## a failed air bake leaves flyers walking and sight on the ground layer.
static func bake(world: RefCounted, field: RefCounted) -> int:
	var floor := floor_mask(field)
	var status: int = world.bake(FLOOR_SIZE.x, FLOOR_SIZE.y, ORIGIN.x, ORIGIN.y, floor, barrier_rects(field))
	if status == OK and world.bake_air(air_mask(field, floor)) != OK:
		push_error("The air layer could not be baked, so flyers walk and sight follows the ground.")
	return status
