extends RefCounted
## Owns the current leader's tactical state. The roster owns membership and HP.
## On a guest, accepted frames update the presentation fields through project().
## Times are absolute host milliseconds unless the caller is drawing a guest view.

var _attacking_slot := -2 # -1 is the leader, -2 means no direct enemy attack.
var position: Vector3
var engaged := false
var attack_mode := ""
var landing := Vector3.ZERO
var winding_up := false
var strike_at := 0
var ready_at := 0
var stagger_until := 0
var rooted_until := 0
var haste_until := 0
var longlimb := false
var active_radius := 0.0
var recovery_bonus := 0
var boss_kind := -1
var boss_phase := 0
var boss_moves := 0

# Specialized plans, adaptation memory and timed leader effects.
# Elite attack tactics belong to the roster's existing leader member.
var memory: Dictionary = {}


func _init(spawn: Vector3 = Vector3.ZERO) -> void:
	position = spawn


## Reaction callbacks observe the attacker only during synchronous resolution.
## Preserve the outer attacker when a specialist invokes a nested contact.
func resolve_attack_from(slot: int, action: Callable) -> void:
	var previous := _attacking_slot
	_attacking_slot = slot
	action.call()
	_attacking_slot = previous


func attacking_slot() -> int:
	return _attacking_slot


func reset_approach() -> void:
	engaged = false
	stagger_until = 0
	attack_mode = ""


func reset_attack(reach_mutation: bool) -> void:
	longlimb = reach_mutation
	active_radius = 0.0
	winding_up = false
	ready_at = 0
	rooted_until = 0
	recovery_bonus = 0


func begin_boss(kind: int) -> void:
	boss_kind = kind
	boss_phase = 0
	boss_moves = 0


func begin_attack(mode: String, due_at: int, radius: float) -> void:
	attack_mode = mode
	strike_at = due_at
	active_radius = radius
	winding_up = true


func stop_attack() -> void:
	attack_mode = ""
	winding_up = false


func extend_root(until: int) -> void:
	rooted_until = maxi(rooted_until, until)


func project(point: Vector3, winding: bool, reach_mutation: bool,
		endpoint: Vector3, mode: String, kind: int, phase: int, radius: float) -> void:
	position = point
	winding_up = winding
	longlimb = reach_mutation
	landing = endpoint
	attack_mode = mode
	boss_kind = kind
	boss_phase = phase
	active_radius = radius
