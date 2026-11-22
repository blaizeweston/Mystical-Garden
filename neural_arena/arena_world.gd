extends "res://game.gd"
## The Neural Arena: the real game world running in a sandbox with its own rounds, time controls and saves.

const ArenaMouse = preload("res://neural_arena/arena_mouse.gd")
const Bot = preload("res://neural_arena/arena_player_bot.gd")
const Bridge = preload("res://neural_arena/arena_mob_bridge.gd")
const Characters = preload("res://neural_arena/arena_characters.gd")
const Config = preload("res://neural_arena/arena_config.gd")
const GardenReturn = preload("res://garden_return_service.gd")
const Grafts = preload("res://expedition_grafts.gd")
const Hud = preload("res://neural_arena/arena_hud.gd")
const DarknessView = preload("res://neural_arena/arena_darkness_view.gd")

signal round_finished(result: Dictionary)

const TICK_SECONDS := 1.0 / CombatClock.TICKS_PER_SECOND
const CLOCK_START_MS := 100000
const BOT_PEER_BASE := 101
const CLEARED_PAUSE_TICKS := 150
const MAX_STEPS_PER_FRAME := 32
const WATCH_SPEEDS := [0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0]
const PLAY_SPEEDS := [0.25, 0.5, 1.0]
const SHARED_SPEEDS := [1.0]
const SANDBOX_ROOT := "user://neural_arena"

var config: Config
var bridge: Bridge
var bots: Dictionary = {}
## Set by the headless runner, which advances the fight itself.
var headless_driver := false
## Benchmark timing of bots, enemies and the whole step. Wall-clock reads never feed the simulation.
var profile := false
var profile_usec := PackedInt64Array([0, 0, 0])
var profile_ticks := 0
## True until the setup screen starts a session.
var awaiting_setup := true
var hud: CanvasLayer
var paused := false
var speed := 1.0
var round_running := false
var round_index := 0
var round_tick := 0
var total_ticks := 0
var last_result: Dictionary = {}
var results: Array[Dictionary] = []
## Set before the world enters the tree when the session should start without the setup screen.
var auto_start := false
var _restart_at := -1
var _step_budget := 0.0
var _sandbox := ""
var _party_share := 1.0
var _enemies_left := 0
var _enemies_defeated := 0
var _darkness_view := DarknessView.new()


func _ready() -> void:
	outgoing_contact_requested.connect(_observe_outgoing_contact)
	if config == null:
		config = Config.new()
	_prepare_sandbox()
	if config.session != Config.SessionKind.JOIN:
		CombatClock.begin_stepped(CLOCK_START_MS)
	# Holding the save batch open makes every game save refuse to write while the arena runs.
	SaveBatch.active = true
	mouse_controls = ArenaMouse.new()
	local_character.data = Characters.make(config.player_class, "Arena Host")
	super()
	rng.seed = config.map_seed
	map_rng.seed = config.map_seed
	players[HOST].character = local_character.data
	restore_class_loadout(players[HOST])
	status = ""
	tree_exiting.connect(_leave_sandbox)
	if headless_driver:
		set_process(false)
		set_physics_process(false)
		return
	_trim_session_menu()
	hud = Hud.new()
	hud.world = self
	add_child(hud)


func _prepare_sandbox() -> void:
	_sandbox = SANDBOX_ROOT.path_join("run_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_sandbox)
	progress.path = _sandbox.path_join("garden.cfg")
	local_character.path = _sandbox.path_join("character.cfg")
	guest_character.path = _sandbox.path_join("guest.cfg")
	character_storage_root = _sandbox.path_join("characters")


## Removes this run's temporary files. It only ever deletes inside the arena sandbox folder.
func _leave_sandbox() -> void:
	CombatClock.end_stepped()
	SaveBatch.active = false
	Life.Preview.strike_rng.randomize()
	Life.Preview.heal_rng.randomize()
	_release_bridge()
	var folder := DirAccess.open(_sandbox)
	if folder == null or not _sandbox.begins_with(SANDBOX_ROOT):
		return
	for file_name in folder.get_files():
		folder.remove(file_name)
	DirAccess.remove_absolute(_sandbox)


func _trim_session_menu() -> void:
	ui.configure_arena_menu(false,true)

func _handle_ui_request(command: String, data: Dictionary) -> void:
	if command == "arena_setup":
		ui.close_panels()
		hud.show_setup()
	else:
		super(command,data)


func is_guest_session() -> bool:
	return network_session.role() in ["Guest", "Connecting"]


func host_is_bot() -> bool:
	return config != null and config.mode == Config.Mode.WATCH and not is_guest_session()


func real_guest_count() -> int:
	return multiplayer.get_peers().size() if network_session.transport() != null else 0


## Fast-forward is only offered while nobody is playing in real time.
func allowed_speeds() -> Array:
	if real_guest_count() > 0 or config.session == Config.SessionKind.HOST:
		return SHARED_SPEEDS
	return WATCH_SPEEDS if config.mode == Config.Mode.WATCH else PLAY_SPEEDS


func set_speed(value: float) -> void:
	if allowed_speeds().has(value):
		speed = value


## Starts the chosen session. Joining waits for the host, which runs the fight.
func begin_session() -> void:
	awaiting_setup = false
	if config.session == Config.SessionKind.JOIN:
		guest_character.data = Characters.make(config.player_class, "Arena Guest")
		if _start_join() != OK:
			last_result = {"outcome": "connection_failed"}
		return
	if config.session == Config.SessionKind.HOST and network_session.role() == "Solo" and session_world.host(config.port) != OK:
		last_result = {"outcome": "hosting_failed"}
		return
	apply_config(config)


## Connects to an arena host. The temporary guest character is never read from or written to disk.
func _start_join() -> Error:
	var address := Network.address(config.address)
	if not Network.error(address, config.port).is_empty():
		status = Network.error(address, config.port)
		return ERR_INVALID_PARAMETER
	var result: Error = network_session.start_join(address, config.port, Time.get_ticks_msec())
	if result != OK:
		status = "Could not start the connection. Check the address and port."
		return result
	replication.clear_session()
	guest_replication.clear_session()
	net_motion.clear()
	participation.detach_all()
	players.clear()
	motions.clear()
	multiplayer.multiplayer_peer = network_session.transport()
	return OK


## Lets a guest join while a round is running, which the normal game only allows in the Garden.
@rpc("any_peer", "call_remote", "reliable")
func register_character(identity: String, profile: Dictionary, catalog: Dictionary = {}, protocol: int = 0) -> void:
	var held: Dictionary = participation.savepoint()
	var idle: Dictionary = participation.savepoint()
	for peer: int in idle.members:
		idle.members[peer].active = false
	participation.restore_savepoint(idle)
	super(identity, profile, catalog, protocol)
	participation.restore_savepoint(held)


## Applies new settings and starts a fresh round.
func apply_config(settings: Config) -> void:
	config = settings
	speed = minf(speed, float(allowed_speeds().back()))
	_sync_host_class()
	_sync_bots()
	start_round()


func _sync_host_class() -> void:
	if int(players[HOST].character.get("active_class", 0)) != config.player_class:
		local_character.data = Characters.make(config.player_class, "Arena Host")
		players[HOST].character = local_character.data
		restore_class_loadout(players[HOST])


## Keeps the computer-controlled party members in line with the chosen count.
func _sync_bots() -> void:
	var wanted := mini(config.bots, Config.MAX_PARTY - real_guest_count() - (0 if host_is_bot() else 1))
	var peers: Array[int] = []
	if host_is_bot():
		peers.append(HOST)
		wanted -= 1
	for index in maxi(0, wanted):
		peers.append(BOT_PEER_BASE + index)
	for peer: int in bots.keys():
		if peer not in peers:
			bots.erase(peer)
			if peer != HOST:
				network_session.release_peer(peer)
				participation.detach(peer)
				players.erase(peer)
				motions.erase(peer)
	for index in peers.size():
		if not bots.has(peers[index]):
			_add_bot(peers[index], index)


func _add_bot(peer: int, index: int) -> void:
	var class_id: int = config.player_class if peer == HOST else index % Characters.class_count()
	if peer != HOST:
		add_player(peer)
		if not players.has(peer):
			return
		var identity := "arena-bot-%d" % peer
		network_session.bind_character(peer, identity, network_session.binding(peer))
		players[peer].character = Characters.make(class_id, "Bot %s" % Characters.class_name_of(class_id))
		restore_class_loadout(players[peer])
	bots[peer] = Bot.new(self, peer, config.map_seed)


## Rebuilds the floor, the enemies and the party for a new round.
func start_round() -> void:
	round_index += 1
	round_tick = 0
	round_running = true
	_restart_at = -1
	rng.seed = config.map_seed + round_index
	Life.Preview.strike_rng.seed = config.map_seed + round_index
	Life.Preview.heal_rng.seed = config.map_seed + round_index + 1
	var saved: Dictionary = participation.savepoint()
	saved.world.destination = 0
	saved.world.depth = (config.floor_number - 1) % (ROUTE_ROOMS - 1) + 1
	saved.world.encounter_number = config.floor_number
	saved.world.difficulty_cycle = 0
	participation.restore_savepoint(saved)
	if not participation.active():
		participation.reset_run()
	boss_floors[str(config.floor_number)] = -1
	wild_item_drops.clear()
	reset_encounter(config.map_seed + round_index if config.generated_map else 0)
	_spawn_enemies()
	for peer: int in players:
		if Session.ready_for(players[peer], false):
			_prepare_player(peer)
	for bot: Bot in bots.values():
		bot.begin_round()
	_release_bridge()
	if not config.brain.is_empty() and Bridge.available():
		bridge = Bridge.new(self, config)
		if not bridge.begin_round(config.map_seed + round_index):
			last_result = {"outcome": "brain_failed", "detail": bridge.error}
			_release_bridge()


func _release_bridge() -> void:
	if bridge != null:
		bridge.release()
	bridge = null


func _spawn_enemies() -> void:
	encounter.clear_scouts()
	var elite_kind := _kind_index(config.elite)
	if elite_kind >= 0:
		enemy_kind = elite_kind
		encounter.set_hp(-1, encounter_health())
	else:
		encounter.set_hp(-1, 0)
	var slot := 0
	for label: String in config.enemies:
		var kind := _kind_index(label)
		for index in int(config.enemies[label]) if kind >= 0 else 0:
			if slot >= Config.MAX_ENEMIES:
				return
			var origin: Vector3 = battlefield.spawn_points[slot % battlefield.spawn_points.size()] if not battlefield.spawn_points.is_empty() else battlefield.leader
			var at: Vector3 = Director.spawn(self, origin, slot)
			if not at.is_finite():
				at = clear_spawn(origin)
			if not at.is_finite():
				continue
			var scout: Dictionary = make_scout(kind, at, slot + 1, current_mutations(kind, enemy_growth, participation.seed() + slot), enemy_growth)
			scout.engaged = true
			if encounter.register_scout(scout) >= 0:
				slot += 1


func _kind_index(label: String) -> int:
	if label.is_empty():
		return -1
	for kind in Enemies.all().size():
		var entry: Dictionary = Enemies.get_kind(kind)
		if str(entry.id) == label and not entry.get("boss", false):
			return kind
	return -1


## Gives one player a full, clean body at the arena entrance.
func _prepare_player(peer: int) -> void:
	var player: Dictionary = players[peer]
	if not participation.contains(peer):
		garden_commands.begin_returns()
		if not participation.enter(peer):
			return
		garden_commands.join_returns(peer)
	restore_class_loadout(player)
	player[PlayerLifecycle.STATE] = PlayerLifecycle.start_life()
	player[ExpeditionWallet.STATE] = ExpeditionWallet.Wallet.new()
	player[Cooldowns.STATE] = Cooldowns.Timers.new()
	var identity := int(get_meta(Grafts.SERIAL, 0)) + 1
	set_meta(Grafts.SERIAL, identity)
	player[Grafts.STATE] = Grafts.Ledger.new(identity)
	for key in ["lost_health", "grave_charges", "core_ready_at", "core_cast_until", "cast_until"]:
		player[key] = 0
	player.weapon = player.prepared
	player.secondary = player.prepared_secondary
	player.catalyst = player.prepared_catalyst
	player.pos = wild_entry(peer)
	player.still_point = player.pos
	player[WeaponActions.STATE] = WeaponActions.State.new()
	player[Protection.STATE] = Protection.State.new()
	player[Conditions.STATE] = Conditions.State.new()
	player.still_since = CombatClock.now()
	var health: PlayerVitals.Health = player[PlayerVitals.STATE]
	player[PlayerVitals.STATE] = health.with_native_max_hp(Life.native_maximum(self, player)).refilled()


## Draws the frame, then this round's darkness over it.
func _process(delta: float) -> void:
	super(delta)
	_darkness_view.apply(self)


func _physics_process(delta: float) -> void:
	if is_guest_session() or awaiting_setup:
		super(delta)
		return
	if headless_driver or paused:
		return
	_step_budget += speed
	var steps := mini(floori(_step_budget), MAX_STEPS_PER_FRAME)
	_step_budget -= steps
	for index in steps:
		step_once()


## Advances the fight by exactly one simulation tick.
func step_once() -> void:
	CombatClock.step()
	total_ticks += 1
	growth_clock = 0.0
	if _restart_at >= 0 and total_ticks >= _restart_at:
		start_round()
	_admit_new_peers()
	if round_running:
		round_tick += 1
		_record_round_state()
		var bots_began := Time.get_ticks_usec() if profile else 0
		for bot: Bot in bots.values():
			bot.act(CombatClock.now())
		if profile:
			profile_usec[0] += Time.get_ticks_usec() - bots_began
	var step_began := Time.get_ticks_usec() if profile else 0
	super._physics_process(TICK_SECONDS)
	if profile:
		profile_usec[2] += Time.get_ticks_usec() - step_began
		profile_ticks += 1
	if not round_running:
		return
	if not participation.active():
		_end_round("party_wiped")
	elif round_tick >= config.round_seconds * CombatClock.TICKS_PER_SECOND:
		_end_round("timeout")


func _admit_new_peers() -> void:
	if not round_running:
		return
	for peer: int in players:
		if Session.ready_for(players[peer], false) and not participation.contains(peer):
			_prepare_player(peer)


func _end_round(outcome: String) -> void:
	if not round_running:
		return
	round_running = false
	encounter_rewarded = true
	# A party wipe resets the floor at once, so a lost round reports the last tick it was still running.
	if outcome != "party_wiped":
		_record_round_state()
	last_result = {"round": round_index, "outcome": outcome, "seconds": snappedf(float(round_tick) / CombatClock.TICKS_PER_SECOND, 0.01),
		"enemies_left": _enemies_left, "enemies_defeated": _enemies_defeated,
		"party_health": 0.0 if outcome == "party_wiped" else snappedf(_party_share, 0.001), "brain": config.brain}
	results.append(last_result)
	round_finished.emit(last_result)
	if not config.auto_restart:
		return
	_restart_at = total_ticks + (CLEARED_PAUSE_TICKS if outcome == "enemies_cleared" and not headless_driver else 1)


func _record_round_state() -> void:
	var health := 0.0
	var maximum := 0.0
	for player: Dictionary in players.values():
		health += PlayerVitals.current_hp(player)
		maximum += PlayerVitals.maximum_hp(player)
	_party_share = health / maxf(1.0, maximum)
	_enemies_left = encounter.living_scout_count()
	_enemies_defeated = encounter_kills.size()


## A repeatable fingerprint of the fight, used to prove identical seeds replay identically.
func state_hash() -> int:
	var parts: Array = [round_index, round_tick]
	for slot in encounter.scout_count():
		parts.append(encounter.hp(slot))
		parts.append(encounter.scout(slot).pos)
	for peer: int in players:
		parts.append(players[peer].pos)
		parts.append(PlayerVitals.current_hp(players[peer]))
	return hash(parts)


func tick_enemies(delta: float, now: int) -> void:
	var began := Time.get_ticks_usec() if profile else 0
	if bridge == null:
		super(delta, now)
	else:
		LeaderBehavior.tick(self, delta, now)
		if round_running and participation.active():
			bridge.tick(now, delta)
	if profile:
		profile_usec[1] += Time.get_ticks_usec() - began


## Mean milliseconds per tick spent on player bots, enemies and the rest of the game step.
func profile_report() -> Dictionary:
	var ticks := maxi(1, profile_ticks)
	var bots_ms := profile_usec[0] / 1000.0 / ticks
	var enemies_ms := profile_usec[1] / 1000.0 / ticks
	var step_ms := profile_usec[2] / 1000.0 / ticks
	return {"bots": snappedf(bots_ms, 0.0001), "enemies": snappedf(enemies_ms, 0.0001),
		"other_game": snappedf(step_ms - enemies_ms, 0.0001), "total": snappedf(step_ms + bots_ms, 0.0001)}


func _observe_outgoing_contact(source_peer: int, target: int) -> void:
	if bridge != null:
		bridge.note_hit(target, source_peer)


## A headless run without guests skips the guest snapshot, which nobody would receive.
func send_expedition_state(delta: float, force := false) -> void:
	if not headless_driver or real_guest_count() > 0:
		super(delta, force)


func move_player(id: int, direction: Vector2, delta: float) -> void:
	super(id, bots[HOST].move_direction if id == HOST and host_is_bot() and bots.has(HOST) else direction, delta)


func finish_combat(_id: int, _loot_position: Vector3) -> void:
	_end_round("enemies_cleared")


func flush_kill_rewards() -> bool:
	return true


func save_local_character() -> bool:
	return true


func _queue_monster_reward(_spawn_token: String, _kind: int, _mask: int, _position: Vector3, _leader: bool, _summoned := false) -> bool:
	return true


func tell(id: int, message: String) -> void:
	if id == HOST or not bots.has(id):
		super(id, message)


func _act(id: int, strike: bool) -> void:
	if strike:
		super(id, strike)
	elif players.has(id) and Life.nearest(self, players[id]) != 0:
		revive_player(id, Life.nearest(self, players[id]))


func _unhandled_key_input(event: InputEvent) -> void:
	if not host_is_bot():
		super(event)


func request_main_menu() -> void:
	return_to_main_menu()


func return_to_main_menu(message: String = "") -> void:
	if returning_to_title:
		return
	returning_to_title = true
	_finish_title_return(message)
