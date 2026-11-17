extends SceneTree

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")
const PlayerVitals = preload("res://player_vitals.gd")

const Vitals = preload("res://combat_vitals.gd")
const View = preload("res://network_presentation.gd")
const SCALE := Vitals.PROTOTYPE_HP_PER_POINT

var failed := false


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL combat vitals: ", message)


func _initialize() -> void:
	preload("res://combat_balance_preview.gd").enabled = false
	call_deferred("run")


func run() -> void:
	var game: Node = load("res://world.tscn").instantiate()
	var fixture := "res://.godot/vitals-baseline-" + Crypto.new().generate_random_bytes(8).hex_encode()
	game.progress.path = fixture + ".cfg"
	game.local_character.path = fixture + ".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	check_live_capacity(game)
	check_amounts()
	check_learning_and_phase()
	check_network_vitals(game)
	check_guard_and_brace(game)
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: live and projected HP, capacity, co-op rounding, damage, regeneration, threat, learning, phase thresholds and vitals revisions")
	quit(1 if failed else 0)


func check_live_capacity(game: Node) -> void:
	var player: Dictionary = game.players[1]
	check(PlayerVitals.current_hp(player) == 10.0 and game.Life.maximum(game, player) == 10
		and not player.has("hp") and not player.has("max_hp"), "shipped player capacity has one authoritative owner")
	var samples := [
		# Global floor, biome, local depth, corruption loops, solo elite HP, four-player elite HP.
		[1, 0, 1, 0, 4, 8],
		[6, 0, 6, 0, 12, 27],
		[18, 2, 6, 0, 17, 48],
		[19, 0, 1, 1, 12, 34],
		[37, 0, 1, 2, 23, 65],
	]
	game.tactics.boss_kind = -1
	for sample in samples:
		game.encounter_number = sample[0]
		game.destination = sample[1]
		game.depth = sample[2]
		game.difficulty_cycle = sample[3]
		game.encounter_party_size = 1
		check(game.encounter_health() == sample[4], "solo gate elite at floor %d" % sample[0])
		game.encounter_party_size = 4
		check(game.encounter_health() == sample[5], "four-player gate elite at floor %d" % sample[0])
	game.tactics.boss_kind = game.Bosses.Lair.Routes.ORCHARD
	game.encounter_number = 10
	game.difficulty_cycle = 0
	game.encounter_party_size = 1
	check(game.encounter_health() == 61, "solo floor 10 Orchard")
	game.encounter_party_size = 4
	check(game.encounter_health() == 146, "four-player floor 10 Orchard")
	check(Vitals.enemy_capacity(61, 2.386, SCALE) == 1460, "convert Orchard after its original co-op ceiling")
	check(Vitals.enemy_capacity(3, 1.90, SCALE) == 60, "ordinary scout keeps the shipped co-op ceiling")


func check_amounts() -> void:
	for scale in [Vitals.LIVE_HP_PER_POINT, SCALE]:
		var full := Vitals.points(10, scale)
		var sacrifice := Vitals.points(Vitals.REVIVE_POINTS, scale)
		check(Vitals.maximum(full, 0, 0, scale) == full, "starting pool scales")
		check(Vitals.maximum(full, 0, sacrifice, scale) == full - sacrifice, "capacity after a revival")
		check(Vitals.maximum(full, sacrifice, sacrifice, scale) == full, "a health bonus and loss compose once")
		check(Vitals.can_revive(2 * sacrifice, scale) and not Vitals.can_revive(sacrifice, scale), "last capacity segment is protected")
		var player := PlayerVitals.Health.new(Vitals.points(2, scale), full)
		var ordinary := player.healed(Vitals.floor_recovery(false, scale))
		var biome := ordinary.healed(Vitals.floor_recovery(true, scale))
		check(ordinary.hp() - player.hp() == scale, "ordinary floor recovery")
		check(biome.hp() - ordinary.hp() == 2 * scale, "biome recovery")
		check(Vitals.damage_taken(Vitals.points(2, scale), Vitals.points(3, scale)) == Vitals.points(2, scale), "overkill reports applied damage")
		check(Vitals.damage_taken(full, 0) == 0, "zero damage stays zero")
		check(Vitals.armored_damage(Vitals.points(3, scale), scale) == Vitals.points(2, scale), "armor reduction has the same strength")
		check(Vitals.armored_damage(scale, scale) == scale, "armor keeps the shipped minimum for a hit")
	var revived := PlayerVitals.Health.new(20.0, 80)
	var first_tick := revived.healed(4)
	var second_tick := first_tick.healed(4)
	check(revived.hp() == 20.0 and first_tick.hp() == 24.0, "first fine-grained tick leaves its input unchanged")
	check(second_tick.hp() == 28.0, "second fine-grained tick")
	var almost_full := revived.with_hp(79.0)
	var full_revival := almost_full.healed(4)
	check(full_revival.hp() - almost_full.hp() == 1.0 and full_revival.hp() == 80.0, "overheal respects revival capacity")
	check(full_revival.healed(4).hp() == full_revival.hp(), "full pool reports no healing")
	var vital := full_revival.with_capacity(80, 12)
	check(vital.hp() == 80.0 and vital.native_max_hp() == 80 and vital.temporary_hp() == 12 and vital.max_hp() == 92,
		"temporary capacity changes the ceiling without healing")
	var expired := vital.healed(12).with_capacity(80, 0)
	check(expired.hp() == 80.0 and expired.max_hp() == 80 and vital.max_hp() == 92, "expiry clamps HP without mutating the prior owner")


func check_learning_and_phase() -> void:
	for scale in [Vitals.LIVE_HP_PER_POINT, SCALE]:
		check(not Vitals.counts_as_burst(Vitals.points(3, scale) - 1, scale), "burst minimum excludes a hit just below threshold")
		check(Vitals.counts_as_burst(Vitals.points(3, scale), scale), "burst minimum is inclusive")
		check(not Vitals.counts_as_ranged(scale, scale, scale), "ranged evidence needs a minimum")
		check(Vitals.counts_as_ranged(2 * scale, 3 * scale, scale), "two thirds ranged qualifies")
		check(not Vitals.counts_as_ranged(2 * scale, 4 * scale, scale), "half ranged does not qualify")
		check(is_equal_approx(Vitals.threat_from_hit(3 * scale, scale), 3.0), "threat keeps its original weight")
		var hp := Vitals.points(100, scale)
		check(Vitals.boss_phase(Vitals.points(66, scale), hp) == 0, "above first phase")
		check(Vitals.boss_phase(Vitals.points(65, scale), hp) == 1, "65 percent starts phase one")
		check(Vitals.boss_phase(Vitals.points(30, scale), hp) == 2, "30 percent starts phase two")


func check_guard_and_brace(game: Node) -> void:
	var player: Dictionary = game.players[1]
	var initial: PlayerVitals.Health = player[PlayerVitals.STATE]
	player.wild = true
	player.weapon = game.Seeds.DEFINITIONS[16].part
	player.still_since = 1000
	player.guard_until = 4000
	player.guard_charges = 1
	var life := PlayerLifecycle.generation(player)
	var blocked := IncomingPlayerHit.resolve_world(game, 1, life, 1600, 1.0)
	check(blocked.kind == IncomingPlayerHit.Outcome.BLOCKED and blocked.applied_hp == 0
		and is_same(player[PlayerVitals.STATE],initial) and player.guard_charges==0
		and int(player.get("brace_block_ready",0))==0,"Guard blocks before Brace can spend its response")
	var braced := IncomingPlayerHit.resolve_world(game, 1, life, 2000, 1.0)
	check(braced.kind == IncomingPlayerHit.Outcome.BRACED
		and is_same(player[PlayerVitals.STATE],initial) and player.brace_block_ready==6000,
		"Brace absorbs the next guarded-player hit without replacing health")
	var damage := IncomingPlayerHit.resolve_world(game, 1, life, 2100, 1.0)
	check(damage.kind == IncomingPlayerHit.Outcome.DAMAGED and damage.applied_hp == 1
		and damage.damage_recorded and PlayerVitals.current_hp(player)==initial.hp()-1.0,
		"the next unmitigated hit reaches the health owner and reports the applied HP loss")
	var sequence := int(player.damage_seq)
	var simultaneous := IncomingPlayerHit.resolve_world(game, 1, life, 2100, 1.0, 600)
	check(simultaneous.kind == IncomingPlayerHit.Outcome.GRACE and int(player.damage_seq) == sequence
		and int(player.get("slow_until", 0)) == 0, "a second hit at the same instant spends neither HP nor a status")
	var stale := IncomingPlayerHit.resolve_world(game, 1, life - 1, 4000, 5.0)
	check(stale.kind == IncomingPlayerHit.Outcome.REJECTED and int(player.damage_seq) == sequence
		and PlayerVitals.current_hp(player) == initial.hp()-1.0, "the host rejects a contact against a prior life")
	player.wild = false
	player[PlayerVitals.STATE] = initial


func check_network_vitals(game: Node) -> void:
	var player: Dictionary = game.players[1]
	player[PlayerVitals.STATE] = PlayerVitals.Health.new(20.0, 80)
	var life_generation := PlayerLifecycle.generation(player)
	player.lost_health = 20
	check(PlayerLifecycle.matches(player,life_generation) and not player.has("fallen"),
		"injury is independent of the authoritative lifecycle generation")
	var view := View.new()
	var previous: Dictionary = game.player_snapshot(1, false)[1]
	view.merge_health(1, previous)
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].healed(4)
	game.net_view.observe(game)
	var healed: Dictionary = game.player_snapshot(1, false)[1]
	view.merge_health(1, healed)
	view.merge_health(1, previous)
	check(previous.hp == 24 and previous.max_hp == 80 and previous.lost_health == 20 and previous.has("fallen")
		and not previous.has(PlayerLifecycle.STATE), "older snapshot cannot undo healing, and guests receive scalar lifecycle projections")
	check(not view.flash_until.has(1), "healing alone does not look like damage")
