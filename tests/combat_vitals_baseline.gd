extends SceneTree

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
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: live and projected HP, capacity, co-op rounding, damage, regeneration, threat, learning, phase thresholds and vitals revisions")
	quit(1 if failed else 0)


func check_live_capacity(game: Node) -> void:
	var player: Dictionary = game.players[1]
	check(player.hp == 10 and game.Life.maximum(game, player) == 10, "shipped player capacity")
	var samples := [
		# Global floor, biome, local depth, corruption loops, solo elite HP, four-player elite HP.
		[1, 0, 1, 0, 4, 8],
		[6, 0, 6, 0, 12, 27],
		[18, 2, 6, 0, 17, 48],
		[19, 0, 1, 1, 12, 34],
		[37, 0, 1, 2, 23, 65],
	]
	game.boss_kind = -1
	for sample in samples:
		game.encounter_number = sample[0]
		game.destination = sample[1]
		game.depth = sample[2]
		game.difficulty_cycle = sample[3]
		game.encounter_party_size = 1
		check(game.encounter_health() == sample[4], "solo gate elite at floor %d" % sample[0])
		game.encounter_party_size = 4
		check(game.encounter_health() == sample[5], "four-player gate elite at floor %d" % sample[0])
	game.boss_kind = game.Bosses.Lair.Routes.ORCHARD
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
		var player := {"hp": Vitals.points(2, scale), "max_hp": full}
		check(Vitals.heal(player, Vitals.floor_recovery(false, scale)) == scale, "ordinary floor recovery")
		check(Vitals.heal(player, Vitals.floor_recovery(true, scale)) == 2 * scale, "biome recovery")
		check(Vitals.damage_taken(Vitals.points(2, scale), Vitals.points(3, scale)) == Vitals.points(2, scale), "overkill reports applied damage")
		check(Vitals.damage_taken(full, 0) == 0, "zero damage stays zero")
		check(Vitals.armored_damage(Vitals.points(3, scale), scale) == Vitals.points(2, scale), "armor reduction has the same strength")
		check(Vitals.armored_damage(scale, scale) == scale, "armor keeps the shipped minimum for a hit")
	var revived := {"hp": 20, "max_hp": 80}
	check(Vitals.heal(revived, 4) == 4 and revived.hp == 24, "first fine-grained tick")
	check(Vitals.heal(revived, 4) == 4 and revived.hp == 28, "second fine-grained tick")
	revived.hp = 79
	check(Vitals.heal(revived, 4) == 1 and revived.hp == 80, "overheal respects revival capacity")
	check(Vitals.heal(revived, 4) == 0, "full pool reports no healing")


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


func check_network_vitals(game: Node) -> void:
	var player: Dictionary = game.players[1]
	player.hp = 20
	player.max_hp = 80
	player.lost_health = 20
	var view := View.new()
	var previous: Dictionary = game.player_snapshot(1, false)[1]
	view.merge_health(1, previous)
	Vitals.heal(player, 4)
	game.net_view.observe(game)
	var healed: Dictionary = game.player_snapshot(1, false)[1]
	view.merge_health(1, healed)
	view.merge_health(1, previous)
	check(previous.hp == 24 and previous.max_hp == 80 and previous.lost_health == 20, "older snapshot cannot undo fine-grained healing or revival loss")
	check(not view.flash_until.has(1), "healing alone does not look like damage")
