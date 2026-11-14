extends RefCounted
## The local lab is the sole completion authority. A future multiplayer host owns
## these decisions; discovery and presentation are independent of completion.

const Surface = preload("res://assets/terrain_m02/wilds_play_surface.gd")
const SIGHT := 5.2
const STRIKE := 1.65
const GATE_REACH := 1.95

var surface: Surface
var position: Vector2
var gate: Vector2
var encounters: Array[Dictionary] = []
var gate_discovered := false
var finished := false
var ready := false

func _init(play_surface: Surface) -> void:
	surface = play_surface
	var graph: Dictionary = surface.layout.trail_network
	position = graph.nodes.arrival
	gate = graph.nodes.exit_gate
	var reachable := surface.reachable_nodes()
	if not reachable.has("terrace") or not reachable.has("exit_gate"):
		return
	for room in ["terrace", "exit_gate"]:
		var center: Vector2 = graph.nodes[room]
		var toward_entry := (graph.nodes.west_bank as Vector2) - center
		var bearing := toward_entry.normalized() if room == "exit_gate" else toward_entry.normalized().orthogonal()
		if not _reserve(room + "_1", center, bearing * 1.13):
			return
		if room == "terrace" and not _reserve(room + "_2", center, -bearing * 1.10):
			return
	ready = true

func _reserve(id: String, center: Vector2, offset: Vector2) -> bool:
	# A required marker and its approach fit inside the protected room. The
	# shared room center gives a reachable point within strike range of each.
	var at := center + offset
	if not surface.travel(center, at).is_equal_approx(at) or not surface.clear_line(center, at):
		return false
	encounters.append({"id": id, "position": at, "approach": center, "cleared": false})
	return true

func gate_active() -> bool:
	return ready and remaining() == 0

func remaining() -> int:
	var count := 0
	for enemy in encounters:
		count += int(not enemy.cleared)
	return count

func move(delta: Vector2) -> void:
	if not ready or finished:
		return
	position = surface.slide(position, delta)
	observe()

func observe() -> void:
	if position.distance_to(gate) <= SIGHT and surface.clear_line(position, gate):
		gate_discovered = true

func strike() -> String:
	if not ready or finished:
		return ""
	var closest := {}
	var distance := STRIKE
	for enemy in encounters:
		if enemy.cleared:
			continue
		var gap := position.distance_to(enemy.position)
		if gap <= distance and surface.clear_line(position, enemy.position):
			distance = gap
			closest = enemy
	if closest.is_empty():
		return ""
	closest.cleared = true
	return closest.id

func use_gate() -> bool:
	if not gate_active() or not gate_discovered or finished or position.distance_to(gate) > GATE_REACH:
		return false
	if not surface.clear_line(position, gate):
		return false
	finished = true
	return true
