extends SceneTree
## Compares the game's own enemy AI with the framework's scripted brain on identical rounds: the same
## species, map seeds, floor and bots. Everything is measured from the game's own enemy records and the
## players' health, so both brains are measured the same way.
##
## Each roster is several of one species plus the same two Rootbound escorts. Per species and brain it
## reports wind-ups started per enemy-minute alive and the mean time to kill, read from the enemy records,
## and per roster the party's health lost per minute and the rounds cleared or lost. The game does not
## record which enemy dealt a hit, so damage is measured for the whole roster rather than per enemy.
##
## godot --headless --path . --script res://neural_arena/tests/arena_compare.gd -- --seeds=3 --seconds=45
## Optional: --species=rootbound,wasp --bots=1 --count=5 --out=user://compare.json

const Catalog = preload("res://enemy_catalog.gd")
const Config = preload("res://neural_arena/arena_config.gd")
const Entry = preload("res://neural_arena/arena_entry.gd")
const PlayerVitals = preload("res://player_vitals.gd")

const ESCORT := "rootbound"
const BRAINS := [Config.GAME_AI, Config.SCRIPTED_BRAIN]
const TICK_GUARD := 60 * 600

var seeds := 3
var seconds := 45
var only := PackedStringArray()
var out_path := ""
var bots := 1
var count := 5


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	for argument in OS.get_cmdline_user_args():
		var value := argument.get_slice("=", 1)
		if argument.begins_with("--seeds="):
			seeds = maxi(1, value.to_int())
		elif argument.begins_with("--seconds="):
			seconds = maxi(10, value.to_int())
		elif argument.begins_with("--species="):
			only = value.split(",", false)
		elif argument.begins_with("--out="):
			out_path = value
		elif argument.begins_with("--bots="):
			bots = clampi(value.to_int(), 1, 4)
		elif argument.begins_with("--count="):
			count = clampi(value.to_int(), 1, 12)
	var report := {}
	for brain: String in BRAINS:
		report[_brain_name(brain)] = await _run_brain(brain)
	var rows := _rows(report)
	for row in rows:
		print("COMPARE ", JSON.stringify(row))
	if not out_path.is_empty():
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"seeds": seeds, "seconds": seconds, "rows": rows}, "\t"))
	quit(0)


static func _brain_name(brain: String) -> String:
	return "legacy" if brain == Config.GAME_AI else "scripted"


func _species() -> PackedStringArray:
	if not only.is_empty():
		return only
	var labels := PackedStringArray()
	for kind in Catalog.all().size():
		var entry: Dictionary = Catalog.get_kind(kind)
		if not entry.get("boss", false):
			labels.append(str(entry.id))
	return labels


func _run_brain(brain: String) -> Dictionary:
	var world: Node = load(Entry.WORLD_SCENE).instantiate()
	world.set_script(load(Entry.WORLD_SCRIPT))
	world.name = Entry.WORLD_NAME
	world.config = _config(brain, ESCORT, 1)
	world.headless_driver = true
	root.add_child(world)
	world.begin_session()
	var totals := {}
	for label in _species():
		for seed_value in seeds:
			var config := _config(brain, label, 101 + seed_value * 37)
			var before: int = world.results.size()
			world.apply_config(config)
			var round_stats := _play(world, before, label)
			_merge(totals, round_stats)
	world.queue_free()
	await process_frame
	return totals


func _config(brain: String, label: String, seed_value: int) -> Config:
	var config := Config.new()
	config.brain = brain
	config.bots = bots
	config.floor_number = 12
	config.round_seconds = seconds
	config.map_seed = seed_value
	config.auto_restart = false
	config.enemies = {label: count} if label == ESCORT else {label: count, ESCORT: 2}
	return config


## Plays one round and returns per-kind statistics.
func _play(world: Node, before: int, label: String) -> Dictionary:
	var tracked := {}
	var previous := {}
	var stats := {}
	var lost_total := 0.0
	var tick := 0
	while world.results.size() == before and tick < TICK_GUARD:
		world.step_once()
		tick += 1
		for slot in world.encounter.scout_count():
			var scout: Dictionary = world.encounter.scout(slot)
			if scout.is_empty():
				continue
			var token: int = world.encounter.token(slot)
			var alive: bool = world.encounter.alive(slot)
			var record: Dictionary = tracked.get(token, {})
			if record.is_empty():
				if not alive:
					continue
				record = {"kind": str(Catalog.get_kind(int(scout.kind)).id), "born": tick, "died": -1, "winding": false, "windups": 0}
				tracked[token] = record
			var winding: bool = alive and int(scout.get("windup", 0)) > 0
			if winding and not record.winding:
				record.windups += 1
			record.winding = winding
			if not alive and record.died < 0:
				record.died = tick
		for peer: int in world.players:
			var health: float = PlayerVitals.current_hp(world.players[peer])
			lost_total += maxf(0.0, float(previous.get(peer, health)) - health)
			previous[peer] = health
	var result: Dictionary = world.results.back() if world.results.size() > before else {}
	for record: Dictionary in tracked.values():
		var entry: Dictionary = stats.get(record.kind, {"enemy_seconds": 0.0, "windups": 0, "deaths": 0, "lifetime": 0.0})
		var end_tick: int = record.died if record.died >= 0 else tick
		entry.enemy_seconds += (end_tick - record.born) / 60.0
		entry.windups += record.windups
		if record.died >= 0:
			entry.deaths += 1
			entry.lifetime += (record.died - record.born) / 60.0
		stats[record.kind] = entry
	var outcome := {"rounds": 1, "seconds": tick / 60.0, "cleared": int(result.get("outcome", "") == "enemies_cleared"),
		"wiped": int(result.get("outcome", "") == "party_wiped"), "damage": lost_total}
	stats["_roster_" + label] = outcome
	stats["_round"] = outcome.duplicate()
	return stats


static func _merge(totals: Dictionary, round_stats: Dictionary) -> void:
	for kind in round_stats:
		var into: Dictionary = totals.get(kind, {})
		for key in round_stats[kind]:
			into[key] = into.get(key, 0) + round_stats[kind][key]
		totals[kind] = into


func _rows(report: Dictionary) -> Array:
	var rows := []
	var labels := Array(_species())
	labels.append("_round")
	for label in labels:
		var row := {"species": label}
		for brain_name in report:
			var entry: Dictionary = report[brain_name].get(label, {})
			if label == "_round":
				row[brain_name] = entry
				continue
			var minutes := maxf(0.001, float(entry.get("enemy_seconds", 0.0)) / 60.0)
			var roster: Dictionary = report[brain_name].get("_roster_" + label, {})
			var round_minutes := maxf(0.001, float(roster.get("seconds", 0.0)) / 60.0)
			row[brain_name] = {
				"enemy_minutes": snappedf(minutes, 0.01),
				"windups_per_min": snappedf(float(entry.get("windups", 0)) / minutes, 0.1),
				"time_to_kill": snappedf(float(entry.get("lifetime", 0.0)) / maxf(1.0, float(entry.get("deaths", 0))), 0.1),
				"deaths": int(entry.get("deaths", 0)),
				"roster_damage_per_min": snappedf(float(roster.get("damage", 0.0)) / round_minutes, 0.1),
				"round_seconds": snappedf(float(roster.get("seconds", 0.0)) / maxf(1.0, float(roster.get("rounds", 0))), 0.1),
				"cleared": int(roster.get("cleared", 0)),
				"wiped": int(roster.get("wiped", 0)),
			}
		rows.append(row)
	return rows
