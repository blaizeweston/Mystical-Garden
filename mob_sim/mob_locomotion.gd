extends RefCounted
## The only code that moves mobs. Executors request movement here and the native core performs it.

const Clock = preload("res://mob_sim/mob_clock.gd")
const Contract = preload("res://mob_sim/mob_contract.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Party = preload("res://mob_sim/mob_party.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Species = preload("res://mob_sim/mob_species.gd")

const STRIDE := 7
const AT_ACTIVE := 0
const AT_SPEED := 1
const AT_STOP := 2
const AT_TARGET := 3
const AT_MODE := 4
const AT_OFFSET_X := 5
const AT_OFFSET_Z := 6
const AGENT_ROW := 10
const CLEAR_BODY := 0.46
const GOAL_CELL := 2.0
const HASTE_SCALE := 1.22

var world: RefCounted
var pool: Pool
var party: Party
var players := 0
var goal_count := 0
var commands := PackedFloat32Array()
var targets := PackedFloat32Array()
var _goal_key := PackedInt64Array()
var _goal_used := PackedInt32Array()
var _tick := 0


func _init(mob_pool: Pool, mob_party: Party, contract: Contract) -> void:
	pool = mob_pool
	party = mob_party
	players = contract.players
	goal_count = int(contract.rules.goal_fields)
	world = NavWorld.create(pool.capacity, players + goal_count)
	commands.resize(pool.capacity * STRIDE)
	commands.fill(0.0)
	targets.resize((players + goal_count) * 2)
	targets.fill(0.0)
	_goal_key.resize(goal_count)
	_goal_key.fill(-1)
	_goal_used.resize(goal_count)
	_goal_used.fill(-1)


## Prepares the map. Every slot starts empty.
func bake(field: RefCounted) -> int:
	if world == null:
		return ERR_UNAVAILABLE
	var status: int = NavWorld.bake(world, field)
	if status != OK:
		return status
	var rows := PackedFloat32Array()
	rows.resize(pool.capacity * AGENT_ROW)
	rows.fill(0.0)
	status = world.load_agents(rows)
	return status if status != OK else world.set_targets(targets)


func place(slot: int) -> void:
	world.place_agents(PackedFloat32Array([slot, pool.xz[slot * 2], pool.xz[slot * 2 + 1], Species.BODY_RADIUS, 1.0]))
	commands[slot * STRIDE + AT_ACTIVE] = 1.0
	hold(slot)


func remove(slot: int) -> void:
	world.place_agents(PackedFloat32Array([slot, pool.xz[slot * 2], pool.xz[slot * 2 + 1], Species.BODY_RADIUS, 0.0]))
	commands[slot * STRIDE + AT_ACTIVE] = 0.0


func hold(slot: int) -> void:
	commands[slot * STRIDE + AT_MODE] = NavWorld.Mode.HOLD


## The tick of the last step. Goal fields are stamped with it.
func last_step_tick() -> int:
	return _tick


func is_holding(slot: int) -> bool:
	return commands[slot * STRIDE + AT_MODE] == NavWorld.Mode.HOLD


func seek_player(slot: int, player: int, offset: Vector2, stop: float) -> void:
	var at := slot * STRIDE
	commands[at + AT_STOP] = stop
	commands[at + AT_TARGET] = player
	commands[at + AT_MODE] = NavWorld.Mode.SEEK
	commands[at + AT_OFFSET_X] = offset.x
	commands[at + AT_OFFSET_Z] = offset.y


func flee_from(slot: int, player: int) -> void:
	var at := slot * STRIDE
	commands[at + AT_TARGET] = player
	commands[at + AT_MODE] = NavWorld.Mode.FLEE


## Walks straight when the way is clear and otherwise shares a route field with nearby goals.
func go_to(slot: int, x: float, z: float, stop: float) -> void:
	var at := slot * STRIDE
	commands[at + AT_STOP] = stop
	if world.line_clear(pool.xz[slot * 2], pool.xz[slot * 2 + 1], x, z, CLEAR_BODY) != 0:
		commands[at + AT_MODE] = NavWorld.Mode.DIRECT
		commands[at + AT_OFFSET_X] = x
		commands[at + AT_OFFSET_Z] = z
		return
	var field := _goal_field(x, z)
	commands[at + AT_TARGET] = field
	commands[at + AT_MODE] = NavWorld.Mode.SEEK
	commands[at + AT_OFFSET_X] = x - targets[field * 2]
	commands[at + AT_OFFSET_Z] = z - targets[field * 2 + 1]


## Moves a mob along a straight line for dashes and pulls, stopping at the first wall.
func displace(slot: int, x: float, z: float) -> void:
	world.displace_agents(PackedFloat32Array([slot, x, z]))
	pool.xz = world.positions()


func step(tick: int) -> void:
	_tick = tick
	for slot in pool.active:
		commands[slot * STRIDE + AT_SPEED] = pool.speed[slot] * _speed_scale(slot, tick)
	for player in players:
		targets[player * 2] = party.x[player]
		targets[player * 2 + 1] = party.z[player]
	world.set_targets(targets)
	world.command_agents(commands)
	world.tick(Clock.DT)
	pool.xz = world.positions()


func _speed_scale(slot: int, tick: int) -> float:
	if pool.windup_until[slot] > 0 or tick < pool.stun_until[slot] or tick < pool.root_until[slot]:
		return 0.0
	var scale := pool.slow_scale[slot] if tick < pool.slow_until[slot] else 1.0
	return scale * HASTE_SCALE if tick < pool.haste_until[slot] else scale


func _goal_field(x: float, z: float) -> int:
	var cell := Vector2i(floori(x / GOAL_CELL), floori(z / GOAL_CELL))
	var key := (cell.x + 32768) * 65536 + (cell.y + 32768)
	var oldest := 0
	for index in goal_count:
		if _goal_key[index] == key:
			_goal_used[index] = _tick
			return players + index
		if _goal_used[index] < _goal_used[oldest]:
			oldest = index
	_goal_key[oldest] = key
	_goal_used[oldest] = _tick
	var field := players + oldest
	targets[field * 2] = (cell.x + 0.5) * GOAL_CELL
	targets[field * 2 + 1] = (cell.y + 0.5) * GOAL_CELL
	return field
