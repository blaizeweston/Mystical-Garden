extends SceneTree

const PlayerVitals = preload("res://player_vitals.gd")

const Core = preload("res://core_combat.gd")
const Rules = preload("res://core_skill_rules.gd")
const Variants = preload("res://core_weapon_variants.gd")

var game: Node
var player: Dictionary
var failed := false


func _initialize() -> void:
	preload("res://combat_balance_preview.gd").enabled = false
	call_deferred("run")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL Core weapon variants: ", detail)


func prepare(species: String, form: int) -> void:
	Core.reset(game)
	game.combat_events.clear()
	game.scouts.clear()
	game.enemy_traits.clear()
	game.enemy_kind = 0
	game.enemy_mutations = 0
	game.enemy_hp = 30
	game.enemy_pos = Vector3(0, 0, -3.5)
	game.enemy_winding_up = false
	game.rooted_until = 0
	game.battlefield.configure(0, 1, 0)
	game.battlefield.barriers.clear()
	player.pos = Vector3.ZERO
	player.wild = true
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(8)
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_native_max_hp(10)
	player.weapon = game.Parts.index_of("plant:" + species)
	player.weapon_kind = form
	player.core_ready_at = 0
	player.core_cast_until = 0
	player.cast_until = 0
	player.guard_until = 0
	player.guard_charges = 0
	player.run_upgrades.clear()


func cast(distance: float) -> Dictionary:
	var preview := Core.preview(game, player, game.battlefield, Vector3.FORWARD, distance)
	check(preview.valid, "resolved variant has a valid preview")
	game.garden_action(1, Core.request(game, player, Vector2.UP, distance))
	var active: Dictionary = game.get_meta(Core.STATE, {}).get(1, {})
	check(not active.is_empty(), "resolved variant reaches the host")
	return active


func shape(preview: Dictionary, kind: String) -> Dictionary:
	for entry in preview.get("shapes", []):
		if entry.kind == kind:
			return entry
	return {}


func run() -> void:
	game = load("res://world.tscn").instantiate()
	game.progress.path = "res://.godot/core-variants-" + str(Time.get_ticks_usec()) + ".cfg"
	game.local_character.path = game.progress.path + ".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	player = game.players[1]
	player.frame = game.Frames.ORACLE
	check_loadouts()
	check_phantom_step()
	check_gravity_and_ward()
	check_hush_and_decoy()
	check_riptide()
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: positional Core variants, hybrid loadouts, movement previews and six skill applications")
	quit(1 if failed else 0)


func check_loadouts() -> void:
	for species in game.Seeds.DEFINITIONS:
		var signature: Dictionary = Rules.Catalog.SIGNATURES[species.id]
		if not Variants.PROFILES.has(signature.skill):
			continue
		var part: int = game.Parts.rare_part(game.Seeds.index_of(species.id))
		var pair: Dictionary = Variants.PROFILES[signature.skill]
		for class_data in game.Classes.DEFINITIONS:
			for weapon in class_data.weapons:
				var build := Rules.resolve(weapon.id, [part], 0)
				var variant: Dictionary = pair.ranged if game.WeaponMotion.is_projectile(weapon.visual) else pair.melee
				check(build.primary == signature.tag and build.skill.id == signature.skill and build.skill.variant_name == variant.variant_name, "weapon determines the variant for %s / %s" % [weapon.name, species.id])
				check(Rules.describe(build.skill).contains(variant.variant_name), "hover names the active variant")
	player.wild = false
	player.prepared = game.Parts.index_of("plant:ghost_fern")
	for form in [0, 2]:
		player.weapon_kind = form
		game.loadout_view.refresh()
		var name := "Closing Step" if form == 0 else "Fading Step"
		check(game.loadout_view.core_preview_name.text == "Phantom Step · " + name, "the gate shows which variant this weapon crafts")


func check_phantom_step() -> void:
	prepare("ghost_fern", 0)
	player.run_upgrades["core_phantom_step"] = 1
	game.enemy_pos = Vector3(0, 0, -2)
	var preview := Core.preview(game, player, game.battlefield, Vector3.FORWARD, 2.0)
	var travel := shape(preview, "travel")
	check(travel.get("to") == Vector3(0, 0, -2) and shape(preview, "capsule").get("to") == travel.get("to"), "bell preview roots at the forward landing")
	var active := cast(2.0)
	Core.tick(game, active.armed)
	check(player.pos == travel.to and game.rooted_until > active.armed and player.guard_charges == 1, "Closing Step reaches the preview and keeps its card")

	prepare("ghost_fern", 2)
	player.run_upgrades["core_phantom_step"] = 1
	game.battlefield.barriers = [Rect2(-.45, .95, .9, .4)]
	preview = Core.preview(game, player, game.battlefield, Vector3.FORWARD, 3.5)
	travel = shape(preview, "travel")
	check(not travel.is_empty() and travel.to.z > 0 and travel.to.z < 1.7 and ((shape(preview, "capsule").from + shape(preview, "capsule").to) * .5).is_equal_approx(game.enemy_pos), "fan preview separates the root and the wall-clipped retreat")
	active = cast(3.5)
	Core.tick(game, active.release)
	check(player.pos == Vector3.ZERO and game.rooted_until == 0, "fan waits for its projectile to land")
	Core.tick(game, active.armed)
	check(player.pos == travel.to and game.rooted_until > active.armed and player.guard_charges == 1, "Fading Step roots remotely and backsteps to the preview")
	prepare("ghost_fern", 2)
	game.battlefield.barriers = [Rect2(-.45, game.Battlefield.CLEARANCE + .01, .9, .7)]
	preview = Core.preview(game, player, game.battlefield, Vector3.FORWARD, 3.5)
	check(shape(preview, "travel").is_empty() and not shape(preview, "capsule").is_empty(), "a fully blocked retreat keeps the root preview")
	active = cast(3.5)
	Core.tick(game, active.armed)
	check(player.pos == Vector3.ZERO and game.rooted_until > active.armed, "a blocked backstep still lands the remote root")


func check_gravity_and_ward() -> void:
	prepare("void_willow", 0)
	game.enemy_pos = Vector3(1, 0, 0)
	var active := cast(2.0)
	Core.tick(game, active.armed)
	Core.tick(game, active.armed + 750)
	check(active.center == Vector3.ZERO and absf(game.enemy_pos.x) < .3, "melee Gravity Well draws foes toward the caster's cast position")

	prepare("void_willow", 2)
	game.enemy_pos = Vector3(1, 0, -3.5)
	active = cast(3.5)
	Core.tick(game, active.armed)
	Core.tick(game, active.armed + 750)
	check(active.center == Vector3(0, 0, -3.5) and absf(game.enemy_pos.x) < .3 and game.enemy_pos.z < -3.0, "ranged Gravity Well draws foes into the remote zone")

	game.add_player(2)
	var ally: Dictionary = game.players[2]
	ally.wild = true
	ally.pos = Vector3(0, 0, -4)
	ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(8)
	for weapon in [0, 2]:
		prepare("ironroot", weapon)
		ally.guard_charges = 0
		ally.guard_until = 0
		var preview := Core.preview(game, player, game.battlefield, Vector3.FORWARD, 4.0)
		var plates := shape(preview, "strip")
		check((plates.from + plates.to) * .5 == (player.pos if weapon == 0 else ally.pos), "Ironbark previews personal or ally protection")
		active = cast(4.0)
		Core.tick(game, active.armed)
		check(player.guard_charges == int(weapon == 0) and ally.guard_charges == int(weapon == 2), "Ironbark wards the party member standing along the bark plates")
	game.players.erase(2)


func check_hush_and_decoy() -> void:
	for weapon in [0, 2]:
		prepare("hush_orchid", weapon)
		game.enemy_winding_up = true
		var active := cast(3.5)
		Core.tick(game, active.armed)
		check(game.enemy_winding_up == (weapon == 0), "Hush interrupts only windups inside its forward fan")

		prepare("dream_poppy", weapon)
		active = cast(3.5)
		Core.tick(game, active.armed)
		var decoy: Vector3 = game.Traits.decoy_point(game, 1)
		check(decoy == (Vector3.ZERO if weapon == 0 else Vector3(0, 0, -3.5)), "Dream Lure places its decoy at the chosen variant's focus")
		Core.tick(game, active.armed + 2000)
		check(game.Traits.decoy_point(game, 1) == Vector3.INF, "decoy targeting clears at detonation")


func check_riptide() -> void:
	for weapon in [0, 2]:
		prepare("tide_lily", weapon)
		game.enemy_pos = Vector3(.8, 0, -2)
		var active := cast(2.0)
		Core.tick(game, active.armed)
		check(is_equal_approx(game.enemy_pos.x,.8) and PlayerVitals.current_hp(player) == 8, "the wave starts at the caster and takes time to reach the target")
		Core.tick(game, active.armed + 700)
		check((game.enemy_pos.x < .8) == (weapon == 0), "the outgoing wave pulls in melee and pushes at range")
		check(PlayerVitals.current_hp(player) == 8, "the caster is outside the wave at the turn")
		Core.tick(game, active.armed + 1400)
		check(PlayerVitals.current_hp(player) == 9, "the wave heals once as it returns")
		var strokes: Array = game.combat_events.filter(func(event): return event.kind=="ability" and event.shape in ["riptide", "riptide_return"])
		check(strokes.size() == 2 and strokes[0].from == strokes[1].to and strokes[0].to == strokes[1].from, "the outward and return crests share the committed path")
