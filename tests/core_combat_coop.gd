extends SceneTree

const Core = preload("res://core_combat.gd")
var game: Node
var role: String
var base: String
var failed := false


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL core co-op ", role, ": ", message)


func signal_file(key: String, value: String = "ok") -> void:
	var file := FileAccess.open(base + "-" + key, FileAccess.WRITE)
	file.store_string(value)


func marked(key: String) -> bool:
	return FileAccess.file_exists(base + "-" + key)


func until(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 14000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return condition.call()


func _initialize() -> void:
	preload("res://combat_balance_preview.gd").enabled = false
	call_deferred("run")


func run() -> void:
	role = OS.get_cmdline_user_args()[0]
	base = "res://.godot/core-net-" + OS.get_cmdline_user_args()[1]
	game = load("res://world.tscn").instantiate()
	game.progress.path = base + role + ".cfg"
	game.local_character.path = base + role + ".character"
	game.guest_character.path = base + role + ".guest"
	root.add_child(game)
	if role == "host":
		await host_run()
	else:
		await guest_run()
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: Core co-op ", role, " craft, arrow, persistent thorns, revival, checkpoint purchase, party ready and Quickroot replication")
	quit(1 if failed else 0)


func host_run() -> void:
	check(game.host_game() == OK, "host opens")
	if not await until(func(): return game.players.size() == 2 and game.players.values().all(func(p): return p.profile_ready)):
		check(false, "guest registers")
		return
	var id: int = game.players.keys().filter(func(peer): return peer != 1)[0]
	var host: Dictionary = game.players[1]
	var guest: Dictionary = game.players[id]
	host.pos = game.Stage.GATE
	guest.pos = game.Stage.GATE
	game.progress.parts.fill(0)
	game.progress.parts[0] = 1
	if not await until(func(): return guest.frame == game.Frames.RANGER and guest.prepared == game.Parts.THORN and marked("preview")):
		check(false, "guest prepared Ranger with Thorn Bloom")
		return
	game.enter_wilds(1, host)
	if not await until(func(): return host.wild and guest.wild):
		check(false, "both players ready and depart")
		return
	check(game.encounter_number == 1 and guest.weapon == game.Parts.THORN and game.progress.parts[0] == 0, "Ranger crafts and consumes the part on floor one")
	var aim := aim_for(guest)
	if aim.is_zero_approx():
		check(false, "generated arena has legal Ranger ground")
		return
	var direction := Vector3(aim.x, 0, aim.y)
	var original := Core.request(game, guest, aim)
	signal_file("aim", JSON.stringify([aim.x, aim.y]))
	if not await until(func(): return game.get_meta(Core.STATE, {}).has(id)):
		check(false, "guest key reaches the host")
		return
	var line: Dictionary = game.get_meta(Core.STATE)[id]
	var cooldown: int = guest.core_ready_at
	check(line.skill.delivery == "arrow" and line.armed > line.release, "line waits for seed arrow landing")
	check(game.attack_animation_snapshot(guest).clip == "Attack_bow", "guest uses bow animation")
	check(not game.player_snapshot(1)[id].has("core_state") and not game.player_snapshot(id, false)[id].has("core_state"), "cooldown is owner-scoped")
	if not await until(func(): return marked("line-seen")):
		check(false, "guest sees projectile and committed terrain geometry")
		return
	var visible: Array = Core.hints(game)
	check(visible.size() == 1 and visible[0].from == [line.from.x, 0, line.from.z] and visible[0].to == [line.to.x, 0, line.to.z], "replicated endpoints match authoritative line")
	var before_hp: int = game.enemy_health()
	game.enemy_pos = line.center + direction * .08
	if not await until(func(): return game.enemy_health() < before_hp and marked("tripped")):
		check(false, "first crossing deals damage and replicates the callout")
		return
	check(Core.hints(game).size()==1 and guest.core_ready_at == cooldown, "the persistent line and owner cooldown survive a hit")
	Core.tick(game,line.expires)

	# Down the caster while the second arrow is airborne.
	guest.core_ready_at = 0
	guest.core_cast_until = 0
	game.garden_action(id, original)
	if not game.get_meta(Core.STATE, {}).has(id):
		check(false, "second cast queued for death test")
		return
	var in_flight: Dictionary = game.get_meta(Core.STATE)[id]
	check(await until(func(): return in_flight.released and not in_flight.grown), "second arrow is airborne")
	cooldown = guest.core_ready_at
	host.pos = guest.pos
	game.Life.down(game, id, guest)
	Core.tick(game, Time.get_ticks_msec())
	check(Core.hints(game).is_empty() and not game.has_meta(Core.STATE), "death cancels pending arrow and terrain")
	check(game.Life.revive(game, 1, id), "teammate revives the Ranger")
	check(guest.core_ready_at == cooldown and guest.lost_health == 2, "revival preserves active cooldown")
	guest.core_ready_at = 0
	guest.core_cast_until = 0
	game.garden_action(id, original)
	check(int(guest.core_ready_at) == 0 and not game.has_meta(Core.STATE), "pre-revival request cannot cast in a new life")
	game.encounter_number = 3
	game.deepest_milestone = 3
	game.encounter.set_hp(-1, 0)
	game.encounter.clear_scouts()
	host.pos = game.battlefield.advance
	guest.pos = game.battlefield.advance
	game.use_checkpoint(1, true)
	game.choose_checkpoint_card(1, host, -1)
	if not await until(func(): return int(guest.run_upgrades.get("quickroot", 0)) == 1):
		check(false, "guest buys Quickroot at the third gate")
		return
	check(game.wallet_for(guest).spent_essence() == 6 and game.wallet_for(host).spent_essence() == 0 and host.run_upgrades.is_empty() and game.encounter_number == 3, "purchase spends only the guest's essence and does not move the party")
	game.use_checkpoint(1, true)
	if not await until(func(): return game.encounter_number == 4):
		check(false, "party advances after both confirmations")
		return
	aim = aim_for(guest)
	if aim.is_zero_approx():
		check(false, "fourth floor has legal ground")
		return
	signal_file("quick-aim", JSON.stringify([aim.x, aim.y]))
	if not await until(func(): return game.get_meta(Core.STATE, {}).get(id, {}).get("grown", false)):
		check(false, "guest grows a new line with purchased behavior")
		return
	var quick: Dictionary = game.get_meta(Core.STATE)[id]
	var before: int = guest.core_ready_at
	game.enemy_pos = quick.center
	check(await until(func(): return guest.core_ready_at == before - 3000 and marked("quick-seen")), "early trip refunds and replicates the guest's cooldown")
	signal_file("done")
	check(await until(func(): return game.players.size() == 1), "guest disconnects")


func aim_for(guest: Dictionary) -> Vector2:
	game.encounter.clear_scouts()
	game.enemy_stagger_until = Time.get_ticks_msec() + 60000
	game.enemy_winding_up = false
	game.encounter.set_hp(-1, 80)
	var direction := Vector3.ZERO
	var placement := {}
	for point in [guest.pos, game.battlefield.leader, game.battlefield.advance]:
		guest.pos = point
		for i in 36:
			var candidate := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 36.0)
			placement = Core.placement(game.battlefield, guest.pos, candidate, Core.equipped(guest))
			if not placement.is_empty():
				direction = candidate
				break
		if not placement.is_empty():
			break
	if placement.is_empty():
		return Vector2.ZERO
	game.enemy_pos = placement.center - direction * .48
	return Vector2(direction.x, direction.z)



func guest_run() -> void:
	game.guest_character.save_profile()
	check(game.join_game() == OK, "guest connects")
	var id := game.multiplayer.get_unique_id()
	if not await until(func(): return game.session == "Guest" and not game.client_details.is_empty() and game.players.get(id, {}).get("pos", Vector3.INF).distance_to(game.Stage.GATE) < 1.0):
		check(false, "guest sees the Garden gate")
		return
	game.send_garden_action("class_%d" % game.Frames.RANGER)
	if not await until(func(): return int(game.players[id].frame) == game.Frames.RANGER):
		check(false, "Ranger selected")
		return
	game.send_garden_action("loadpart_0_1")
	if not await until(func(): return game.players[id].get("weapon_stats", {}).get("core_build", {}).get("skill", {}).get("delivery") == "arrow"):
		check(false, "prepared build arrives from host")
		return
	game.loadout_view.refresh()
	check(game.loadout_view.description.text.contains("seed arrow"), "guest bench previews ranged delivery")
	signal_file("preview")
	if not await until(func(): return game.party_travel_state().get("kind") == "depart"):
		check(false, "host requests travel")
		return
	game.send_travel_ready(false)
	if not await until(func(): return game.players[id].get("wild", false) and marked("aim") and not game.player_hud.state.get("core", {}).is_empty()):
		check(false, "Ranger reaches the Wilds with ready Core HUD")
		return
	var aim: Array = JSON.parse_string(FileAccess.get_file_as_string(base + "-aim"))
	game.players[id].facing = Vector3(aim[0], 0, aim[1])
	var press := InputEventKey.new()
	press.physical_keycode = KEY_B
	press.pressed = true
	game._unhandled_key_input(press)
	var aim_preview = preload("res://ability_aim.gd").active(game)
	check(aim_preview != null and aim_preview.drawing.get_surface_count() == 1 and game.player_hud.state.core.remaining <= 0, "guest sees a preview without sending a cast")
	press.pressed = false
	game._input(press)
	if not await until(func(): return game.received_combat_events.any(func(entry): return entry.event.kind == "projectile" and entry.event.shape == "arrow")):
		check(false, "seed arrow replicates")
		return
	var line_seen := func(): return game.combat_visuals.hints.values().any(func(hint): return hint.event.role == "core_thorns")
	if not await until(line_seen):
		check(false, "guest renders thorn line")
		return
	check(game.player_hud.state.core.remaining > 0 and not game.players[1].has("core_state"), "only guest sees own cooldown")
	signal_file("line-seen")
	check(await until(func(): return game.received_combat_events.any(func(entry): return entry.event.kind == "proc" and entry.event.shape == "Thorns tripped") and line_seen.call()), "the hit callout arrives while the line is still visible")
	signal_file("tripped")
	if not await until(func(): return game.checkpoint_menu.visible and game.checkpoint_cards.get_child_count() >= 3):
		check(false, "third gate displays choices to the guest")
		return
	var first: Node = game.checkpoint_cards.get_child(0)
	var labels := first.find_children("*", "Label", true, false)
	check(labels.any(func(label): return label.text == "Quickroot") and labels.any(func(label): return label.text.contains("recover 3 seconds")), "affordable compatible card and behavior reach the guest")
	game.send_garden_action("checkpoint_choice_0")
	if not await until(func(): return not game.checkpoint_menu.visible and game.party_travel_state().get("kind") == "advance"):
		check(false, "guest can confirm after purchase")
		return
	game.send_travel_ready(false)
	if not await until(func(): return game.encounter_number == 4 and marked("quick-aim") and game.player_hud.state.get("core", {}).get("remaining", 99) < .01):
		check(false, "party reaches floor four with an available Core")
		return
	aim = JSON.parse_string(FileAccess.get_file_as_string(base + "-quick-aim"))
	game.send_garden_action(Core.request(game, game.players[id], Vector2(aim[0], aim[1])))
	var quick_seen := func(): return game.received_combat_events.any(func(entry): return entry.event.shape == "Quickroot")
	check(await until(func(): return quick_seen.call() and game.player_hud.state.get("core", {}).get("remaining", 99) < 5.5), "guest sees Quickroot feedback and the reduced cooldown")
	signal_file("quick-seen")
	check(await until(func(): return marked("done")), "host verifies purchase and reduced cooldown")
	game.leave_game("Core co-op fixture")
