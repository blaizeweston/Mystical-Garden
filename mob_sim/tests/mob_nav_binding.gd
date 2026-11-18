extends SceneTree
## Exercises every method the Godot binding exposes on a real map.

const Battlefield = preload("res://battlefield.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const DT := 1.0 / 60.0

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	failures += int(not condition)


func run() -> void:
	check(NavWorld.ensure_loaded(), "the extension loads")
	var field = Battlefield.new()
	field.configure(0, 5, 11)
	var world: RefCounted = NavWorld.create(2, 1)
	check(world != null, "a world can be created")
	check(NavWorld.bake(world, field) == OK, "a real map bakes")
	var start: Vector3 = field.entry
	var goal: Vector3 = field.advance
	check(world.clearance(start.x, start.z) > 0.0, "clearance reads the entry as walkable")
	check(world.set_targets(PackedFloat32Array([goal.x, goal.z])) == OK, "targets are accepted")
	check(world.set_targets(PackedFloat32Array([goal.x])) != OK, "a partial target is refused")
	var row := PackedFloat32Array([1.0, start.x, start.z, 2.2, 0.34, 0.5, 0.0, float(NavWorld.Mode.SEEK), 0.0, 0.0])
	check(world.load_agents(row) == OK, "agents are accepted")
	check(world.load_agents(row.slice(0, 9)) != OK, "a partial agent row is refused")
	check(world.tick(DT) == OK, "a tick runs")
	check(world.field_solves() >= 1, "a flow field was solved")
	check(world.path_cost(0, start.x, start.z) > 0.0, "the exit is reachable from the entry")
	check(world.line_clear(start.x, start.z, start.x, start.z, 0.34) == 1, "a point sees itself")
	for i in 120:
		world.tick(DT)
	var moved: PackedFloat32Array = world.positions()
	check(moved.size() == 2 and Vector2(moved[0], moved[1]).distance_to(Vector2(start.x, start.z)) > 3.0, "the agent walks")
	var command := PackedFloat32Array([1.0, 2.2, 0.5, 0.0, float(NavWorld.Mode.HOLD), 0.0, 0.0])
	check(world.command_agents(command) == OK, "commands are accepted")
	check(world.command_agents(command.slice(0, 6)) != OK, "a partial command is refused")
	var hash_before: int = world.state_hash()
	for i in 30:
		world.tick(DT)
	check(world.state_hash() == hash_before, "a held agent keeps the same state hash")
	print("PASSED" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)
