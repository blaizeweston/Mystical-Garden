extends SceneTree
## Records second-by-second traces of seeded evaluation fights, to see why fights stall until their time limit.
## It plays the same episodes as ai/evaluate_policies.gd (same settings, seed and brain choice) and writes one
## JSON line per kept fight: its report plus a trace. ai/training/stall_trace_summary.py reads the lines.
##
## godot --headless --path <project> --script res://ai/stall_trace.gd -- --policy <policy.bin> --seed <n>
##   --episodes <n> --out <traces.jsonl> [--scripted] [--all] [--every <seconds>] [--episodes-file <settings.json>]
##
## --all     keeps every fight; by default only fights that reached their time limit.
## --every   seconds between samples (default 1).
##
## Each sample ("trace" entries) holds:
## - t: seconds into the fight; taken, dealt: the party's running damage taken and dealt;
## - mobs: one row per living mob: [slot, species, x, z, behaviour, target player (-1 none), knows target,
##   sees a standing player, seconds since its target was last sensed (-1), metres from where it remembers the
##   target to where the target is (-1), metres to that remembered point (-1), metres to the nearest standing
##   player, health fraction, engaged, light at the mob, movement command (NavWorld.Mode), command speed,
##   winding up, stunned, rooted, route cost along the field it seeks (-1: unreachable, -2: not seeking)];
## - players: one row per player: [x, z, mode (StandIns.MODE_NAMES or "down"), health fraction, target mob slot
##   (-1), sees any living mob, light at the player, metres since the last sample].
## The header line ("legend") names the species and behaviours. Reading only: nothing here changes a fight, and
## nothing is written to a run folder.

const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Recorder = preload("res://ai/rollout_recorder.gd")
const Schema = preload("res://ai/mob_schema.gd")
const EvalEnv = preload("res://ai/evaluation_env.gd")
const Clock = preload("res://mob_sim/mob_clock.gd")
const StandIns = preload("res://ai/stand_in_party.gd")
const Loco = preload("res://mob_sim/mob_locomotion.gd")

const SETTINGS_PATH := "res://ai/training/training.json"
const LOCAL_SETTINGS_PATH := "res://ai/training/training.local.json"

var policy_path := ""
var out_path := ""
var seed_value := 1
var episode_count := 0
var scripted := false
var keep_all := false
var every_s := 1.0
var episodes_file := ""

var _env: EvalEnv
var _trace: Array = []
var _every_steps := 60
var _last_player: Array[Vector2] = []


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	if not _parse_arguments():
		printerr("Usage: --script res://ai/stall_trace.gd -- --policy <file> --seed <n> --episodes <n> --out <file> [--scripted] [--all]")
		return 2
	if not NavWorld.ensure_loaded():
		printerr("The native extension did not load.")
		return 2
	var schema := Schema.new()
	if not schema.errors.is_empty():
		printerr("The schema has errors: ", schema.errors)
		return 2
	var settings := _settings()
	if settings.is_empty():
		printerr("Could not read ", SETTINGS_PATH)
		return 2
	if not episodes_file.is_empty():
		var frozen: Variant = JSON.parse_string(FileAccess.get_file_as_string(episodes_file))
		if not frozen is Dictionary or not frozen.get("episodes") is Dictionary:
			printerr("Could not read the episode settings in ", episodes_file)
			return 2
		settings.episodes = frozen.episodes
	var weights := FileAccess.get_file_as_bytes(policy_path)
	if weights.size() < 72 or weights.slice(8, 72).get_string_from_ascii() != schema.hash_hex:
		printerr("The policy %s does not fit this schema." % policy_path)
		return 2
	var recorder := Recorder.new(schema)
	_env = EvalEnv.new(schema, recorder, settings.episodes.duplicate(true), seed_value)
	_env.use_scripted = scripted
	_env.snapshot = true
	_env.set_policy(weights, 1)
	_every_steps = maxi(EvalEnv.SAMPLE_TICKS, int(round(every_s * Clock.TICKS_PER_SECOND / EvalEnv.SAMPLE_TICKS)) * EvalEnv.SAMPLE_TICKS)
	_env.on_sample = _sample
	var out := FileAccess.open(out_path + ".tmp", FileAccess.WRITE)
	if out == null:
		printerr("Could not write ", out_path)
		return 2
	var code := 0
	var kept := 0
	var wrote_legend := false
	for index in episode_count:
		_trace = []
		_last_player.clear()
		var report := _env.run_episode()
		if report.is_empty():
			printerr("Episode failed: ", _env.error)
			code = 1
			break
		if not wrote_legend:
			out.store_line(JSON.stringify({"legend": {"species": Array(_env.sim.species.ids), "behaviours": Array(_env.sim.contract.names),
				"modes": StandIns.MODE_NAMES, "every_s": float(_every_steps) / Clock.TICKS_PER_SECOND, "scripted": scripted, "seed": seed_value}}))
			wrote_legend = true
		if not keep_all and report.outcome != "timeout":
			continue
		report["seed"] = seed_value
		report["index"] = index
		report["classes"] = Array(_env.party.classes)
		report["trace"] = _trace
		out.store_line(JSON.stringify(report))
		kept += 1
	out.close()
	_env.close()
	if code != 0:
		DirAccess.remove_absolute(out_path + ".tmp")
		return code
	if Recorder.rename_retrying(out_path + ".tmp", out_path) != OK:
		printerr("Could not finish ", out_path)
		return 1
	print("Traced %d of %d episodes (%s, seed %d)" % [kept, episode_count, "scripted" if scripted else "policy", seed_value])
	return 0


func _sample(step: int) -> void:
	if step % _every_steps != 0:
		return
	var sim = _env.sim
	var pool = sim.pool
	var perception = sim.perception
	var nav = perception.nav
	var loco = sim.locomotion
	var party: StandIns = _env.party
	var players: int = sim.contract.players
	var now: int = sim.clock.tick
	var mobs := []
	for slot in pool.active:
		var at := Vector2(pool.xz[slot * 2], pool.xz[slot * 2 + 1])
		var nearest := INF
		var sees := false
		for player in party.count:
			if party.down[player] != 0:
				continue
			nearest = minf(nearest, at.distance_to(party.position[player]))
			sees = sees or perception.sees(slot, player)
		var target: int = int(pool.enemy_target[slot]) - 1
		var knows := false
		var age := -1.0
		var error := -1.0
		var to_memory := -1.0
		if target >= 0 and target < players:
			var cell: int = slot * players + target
			knows = perception.knows(slot, target)
			if perception.seen_tick[cell] >= 0:
				var memory := Vector2(perception.seen_x[cell], perception.seen_z[cell])
				age = Clock.to_seconds(now - perception.seen_tick[cell])
				to_memory = at.distance_to(memory)
				if target < party.count:
					error = memory.distance_to(party.position[target])
		mobs.append([slot, int(pool.species[slot]), snappedf(at.x, 0.1), snappedf(at.y, 0.1), int(pool.behaviour[slot]), target, int(knows),
			int(sees), snappedf(age, 0.1), snappedf(error, 0.1), snappedf(to_memory, 0.1), snappedf(nearest, 0.1) if nearest < INF else -1.0,
			snappedf(pool.hp[slot] / maxf(1.0, pool.max_hp[slot]), 0.01), int(pool.engaged[slot]), snappedf(nav.sense_light_at(at.x, at.y), 0.01),
			int(loco.commands[slot * Loco.STRIDE + Loco.AT_MODE]), snappedf(loco.commands[slot * Loco.STRIDE + Loco.AT_SPEED], 0.01),
			int(pool.windup_until[slot] > 0), int(pool.stun_until[slot] > now), int(pool.root_until[slot] > now),
			_route_cost(loco, slot, at)])
	var rows := []
	for player in party.count:
		var at: Vector2 = party.position[player]
		var sees_mob := false
		if party.down[player] == 0:
			for slot in pool.active:
				if perception.player_sees(at, Vector2(pool.xz[slot * 2], pool.xz[slot * 2 + 1])):
					sees_mob = true
					break
		var moved := 0.0
		if player < _last_player.size():
			moved = at.distance_to(_last_player[player])
			_last_player[player] = at
		else:
			_last_player.append(at)
		rows.append([snappedf(at.x, 0.1), snappedf(at.y, 0.1), "down" if party.down[player] != 0 else StandIns.MODE_NAMES[party.mode[player]],
			snappedf(party.hp[player] / maxf(1.0, party.max_hp[player]), 0.01), int(party.target[player]), int(sees_mob),
			snappedf(nav.sense_light_at(at.x, at.y), 0.01), snappedf(moved, 0.1)])
	_trace.append({"t": snappedf(float(step) / Clock.TICKS_PER_SECOND, 0.1), "taken": snappedf(party.damage_taken, 0.1),
		"dealt": snappedf(party.damage_dealt, 0.1), "mobs": mobs, "players": rows})


## The route cost from the mob to the goal of the field its movement command seeks; -2 when it is not seeking.
func _route_cost(loco, slot: int, at: Vector2) -> float:
	var row: int = slot * Loco.STRIDE
	if int(loco.commands[row + Loco.AT_MODE]) != NavWorld.Mode.SEEK:
		return -2.0
	return snappedf(loco.world.path_cost(int(loco.commands[row + Loco.AT_TARGET]), at.x, at.y), 0.1)


func _settings() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if not parsed is Dictionary:
		return {}
	var settings: Dictionary = parsed
	if FileAccess.file_exists(LOCAL_SETTINGS_PATH):
		var local: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOCAL_SETTINGS_PATH))
		if local is Dictionary:
			for key: String in local:
				if local[key] is Dictionary and settings.get(key) is Dictionary:
					settings[key].merge(local[key], true)
				else:
					settings[key] = local[key]
	return settings


func _parse_arguments() -> bool:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		var value: String = args[index + 1] if index + 1 < args.size() else ""
		match args[index]:
			"--policy":
				policy_path = value
			"--out":
				out_path = value
			"--seed":
				seed_value = int(value)
			"--episodes":
				episode_count = int(value)
			"--scripted":
				scripted = true
			"--all":
				keep_all = true
			"--every":
				every_s = float(value)
			"--episodes-file":
				episodes_file = value
	return not policy_path.is_empty() and not out_path.is_empty() and episode_count > 0
