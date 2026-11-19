extends SceneTree
## One side of the multiplayer check. Started twice by run_net_check.ps1, once as host and once as guest.

const Config = preload("res://neural_arena/arena_config.gd")
const Entry = preload("res://neural_arena/arena_entry.gd")
const PlayerVitals = preload("res://player_vitals.gd")

const TIME_LIMIT_MS := 45000
const REQUIRED_SECONDS := 8.0
const GUEST_CLASS := 2

var world: Node
var guest_class := -1
var role := ""
var started_at := 0
var joined_at := -1
var start_position := Vector3.INF
var moved := false
var saw_enemies := false
var saw_enemy_motion := false
var enemy_starts := {}
var enemy_context := ""


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	role = "host" if "host" in arguments else "guest"
	var config := Config.new()
	config.apply_arguments(arguments)
	for argument in arguments:
		if argument.begins_with("--port="):
			config.port = argument.get_slice("=", 1).to_int()
	config.session = Config.SessionKind.HOST if role == "host" else Config.SessionKind.JOIN
	config.mode = Config.Mode.PLAY
	config.bots = 1 if role == "host" else 0
	config.player_class = 0 if role == "host" else GUEST_CLASS
	config.enemies = {"rootbound": 4, "nightbloom": 2}
	config.round_seconds = 600
	config.brain = "res://ai/training/out/policy.bin"
	world = Entry.launch(self, config, true)
	started_at = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_at < TIME_LIMIT_MS:
		await process_frame
		if role == "host":
			_observe_host()
		else:
			_observe_guest()
		if joined_at >= 0 and (Time.get_ticks_msec() - joined_at) / 1000.0 >= REQUIRED_SECONDS:
			break
	_finish()


func _observe_host() -> void:
	for peer: int in world.players:
		if _is_guest(peer) and world.participation.contains(peer):
			guest_class = int(world.players[peer].frame)
			if joined_at < 0:
				joined_at = Time.get_ticks_msec()


func _is_guest(peer: int) -> bool:
	return peer != world.HOST and not world.bots.has(peer)


func _observe_guest() -> void:
	if world.network_session.role() != "Guest":
		return
	var id: int = world.multiplayer.get_unique_id()
	var player: Dictionary = world.players.get(id, {})
	if player.is_empty() or not world.Life.alive(player):
		return
	if joined_at < 0:
		joined_at = Time.get_ticks_msec()
		start_position = player.pos
	Input.action_press("right")
	moved = moved or player.pos.distance_to(start_position) > 0.8
	var context := str([world.participation.epoch(),world.participation.floor(),world.participation.seed()])
	if context!=enemy_context:
		enemy_context=context
		enemy_starts.clear()
	# An untrained policy may hold one enemy still. Observe every living slot;
	# a new floor cannot masquerade as motion of a previous round's enemy.
	var pack: PackedFloat32Array = world.guest_replication.scouts()
	for slot in pack.size()/world.PACK_STRIDE:
		var offset: int=slot*world.PACK_STRIDE
		if pack[offset+2]<=0:continue
		saw_enemies=true
		var at := Vector3(pack[offset],0.0,pack[offset+1])
		if not enemy_starts.has(slot):enemy_starts[slot]=at
		saw_enemy_motion=saw_enemy_motion or at.distance_to(enemy_starts[slot])>.5


func _finish() -> void:
	var result := {"role": role, "joined": joined_at >= 0, "session": world.network_session.role(), "status": str(world.status),
		"peers": world.multiplayer.get_peers(), "players": world.players.keys(), "last": world.last_result}
	if role == "guest":
		result.merge({"moved": moved, "saw_enemies": saw_enemies, "saw_enemy_motion": saw_enemy_motion,
			"class": int(world.players.get(world.multiplayer.get_unique_id(), {}).get("frame", -1))})
	else:
		result.merge({"rounds": world.round_index, "party": world.participation.participants().size(),
			"speeds": world.allowed_speeds(), "guest_class": guest_class})
	print("NET_RESULT ", JSON.stringify(result))
	var passed: bool = joined_at >= 0 and (guest_class == GUEST_CLASS if role == "host" else moved and saw_enemies and saw_enemy_motion)
	world.return_to_main_menu()
	await process_frame
	quit(0 if passed else 1)
