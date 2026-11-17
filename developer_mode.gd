extends RefCounted

const Slots = preload("res://save_slots.gd")
const Catalog = preload("res://heart_catalog.gd")
const Growth = preload("res://garden_growth_state.gd")
const Journal = preload("res://diagnostic_journal.gd")
const Inventory = preload("res://inventory_model.gd")
const Transactions = preload("res://game_transaction.gd")
const GuardedSession = preload("res://guarded_title_session.gd")
const MATERIAL_STOCK := 25
const SEED_STOCK := 5
const WORLD_META := &"developer_garden"


static func is_test_garden(game: Node) -> bool:
	return game.has_meta(WORLD_META)


static func is_solo(game: Node) -> bool:
	return game != null and "session" in game and "online_peer" in game \
		and game.network_session.role() == "Solo" and game.network_session.transport() == null and game.multiplayer.is_server() \
		and game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer


static func can_edit(game: Node) -> bool:
	return is_test_garden(game) and is_solo(game) and game.app_settings.values.get("developer_mode",false) \
		and not game.participation.active() and not game.returning_to_title \
		and not game.get_meta("garden_cinematic_active",false) and Transactions.session_writable(game)


static func open_garden(menu: Node, reset: bool, digests := {}) -> Error:
	if menu.transitioning or not menu.content_valid or not menu.app_settings.values.get("developer_mode",false):
		return ERR_UNAUTHORIZED
	if menu.production_route and not menu.production_backend_ready:
		return ERR_UNAVAILABLE
	if menu.guarded_persistence:
		var result := _open_guarded(menu, reset, digests)
		if not GuardedSession.completed(result):
			menu.notice.text = GuardedSession.notice(result)
		return result.error
	var slots := Slots.new()
	slots.root_path = menu.storage.root_path.path_join("developer-garden")
	var error := slots.prepare(false)
	if error != OK:
		return error
	if reset or not FileAccess.file_exists(slots.paths(0).garden):
		error = slots.new_game(0,reset)
		if error != OK:
			return error
	error = slots.claim(0)
	if error != OK:
		return error
	var paths := slots.paths(0)
	var world: Node = load("res://world.tscn").instantiate()
	world.set_meta(WORLD_META,{"root":menu.storage.root_path,"slot":menu.selected,"character":menu.selected_character})
	world.settings_path = menu.settings_path
	world.slot_storage_root = slots.root_path
	world.active_slot = 0
	world.slot_claimed = true
	world.progress.path = paths.garden
	world.local_character.path = paths.character
	world.guest_character.path = paths.character
	menu.transitioning = true
	menu.get_tree().root.add_child(world)
	menu.get_tree().current_scene = world
	menu.queue_free()
	return OK

static func reset_snapshot(menu: Node) -> Dictionary:
	var slots := _guarded_slots(menu)
	var location: Dictionary = slots.paths(0)
	var digests := {}
	for path in [location.garden, location.character]:
		var info := GuardedSession.garden_summary(path) if path == location.garden else GuardedSession.character_summary(path)
		if info.state not in ["healthy", "empty"]:
			return {}
		digests[path] = info.digest if info.state == "healthy" else "absent"
	return digests

static func _guarded_slots(menu: Node) -> RefCounted:
	var slots := Slots.new()
	slots.root_path = menu.storage.root_path.path_join("developer-garden")
	return slots

static func _open_guarded(menu: Node, reset: bool, digests: Dictionary) -> Dictionary:
	var slots := _guarded_slots(menu)
	var location: Dictionary = slots.paths(0)
	var garden := GuardedSession.garden_summary(location.garden)
	if garden.state not in ["healthy", "empty"]:
		return GuardedSession.Ops.management_result(ERR_BUSY, garden.state, garden.state)
	var character := GuardedSession.character_summary(location.character)
	if character.state not in ["healthy", "empty"]:
		return GuardedSession.Ops.management_result(ERR_BUSY, character.state, character.state)
	if reset or garden.state == "empty":
		if reset and digests.is_empty():
			return GuardedSession.Ops.management_result(ERR_UNAUTHORIZED, "stale_replacement_confirmation")
		var created := GuardedSession.outcome(slots.new_game_guarded(0, reset, digests))
		if not GuardedSession.completed(created):
			return created
		garden = GuardedSession.garden_summary(location.garden)
		character = GuardedSession.character_summary(location.character)
	var world: Node = load("res://world.tscn").instantiate()
	world.set_meta(WORLD_META, {"root": menu.storage.root_path, "slot": menu.selected, "character": menu.selected_character})
	world.settings_path = menu.settings_path
	world.slot_storage_root = slots.root_path
	world.active_slot = 0
	world.progress.path = location.garden
	world.local_character.path = location.character
	world.guest_character.path = location.character
	var owner := GuardedSession.new()
	var result := owner.start(world, slots, 0, garden.digest, null, -1, character.digest)
	if not GuardedSession.completed(result):
		world.free()
		return result
	world.slot_claimed = true
	menu.transitioning = true
	if menu.settings_dialog.visible: menu.settings_dialog.exclusive = false
	menu.get_tree().root.add_child(world)
	menu.get_tree().current_scene = world
	menu.queue_free()
	return result


static func grant_resources(game: Node) -> String:
	if not can_edit(game):
		return "Developer tools are available in the single-player Developer Garden."
	var details := {}
	var result := Transactions.run_gameplay(game, Transactions.Scope.GARDEN, _grant_resources.bind(game,details), false)
	if result.completed and not details.is_empty(): Journal.event("developer","resources_granted",details)
	return Transactions.feedback(result, "Could not save the developer action.")

static func _grant_resources(game: Node, details: Dictionary) -> String:
	var progress: RefCounted = game.progress
	var old_knowledge: int = progress.knowledge
	var old_parts: Array = progress.parts.duplicate()
	var old_stock: Array = progress.stock.duplicate()
	progress.knowledge += 100
	for species in range(3):
		progress.parts[species] += 25
		progress.stock[species] += 5
	if not preload("res://save_batch.gd").guarded_active() and progress.save_garden() != OK:
		progress.knowledge = old_knowledge
		progress.parts.assign(old_parts)
		progress.stock.assign(old_stock)
		return "Could not save the developer resources."
	details.merge({"knowledge":100,"parts_per_starter":25,"seeds_per_starter":5})
	return "Added 100 Knowledge. Each starter species gains 25 parts and 5 seeds."


static func stock_materials(game: Node) -> String:
	if not can_edit(game):
		return "Developer tools are available in the single-player Developer Garden."
	var details := {}
	var result := Transactions.run_gameplay(game, Transactions.Scope.GARDEN, _stock_materials.bind(game,details), false)
	if result.completed and not details.is_empty(): Journal.event("developer","materials_stocked",details)
	return Transactions.feedback(result, "Could not save the developer action.")

static func _stock_materials(game: Node, details: Dictionary) -> String:
	if not game.players.has(game.HOST):
		return "Developer tools are available in the single-player Developer Garden."
	var player: Dictionary = game.players[game.HOST]
	var progress: RefCounted = game.progress
	var before := Transactions.snapshot(progress)
	var added := 0
	for part in range(1, game.Parts.DEFINITIONS.size()):
		if not (game.Parts.is_plant(part) or game.Parts.is_monster(part)):
			continue
		var missing := MATERIAL_STOCK - int(progress.part_count(part))
		if missing > 0:
			progress.add_parts(part, missing)
			added += missing

	var stash := Inventory.counts(game, player, "stash")
	for item in Inventory.Items.all().values():
		if item.category not in ["seed", "material"] or item.has("legacy_part"):
			continue
		var current := int(stash.get(item.id, 0))
		var minimum := SEED_STOCK if item.category == "seed" else MATERIAL_STOCK
		var missing := minimum - current
		if missing <= 0:
			continue
		var stack := {"item": item.id, "quantity": missing}
		if item.id == "unidentified_seed":
			var species_count: int = game.Seeds.DEFINITIONS.size()
			stack.seeds = range(current, minimum).map(func(index): return index % species_count)
		Inventory.put(game, player, "stash", stack)
		added += missing

	if added == 0:
		return "Material stocks are already full."
	if not preload("res://save_batch.gd").guarded_active() and progress.save_garden() != OK:
		Transactions.restore(progress, before)
		return "Could not save the material stock."
	details.merge({"quantity_added":added,"part_minimum":MATERIAL_STOCK,"seed_minimum":SEED_STOCK})
	return "Materials stocked. Crafting parts are in shared storage and seeds are in your stash."


static func finish_research(game: Node) -> String:
	if not can_edit(game):
		return "Developer tools are available in the single-player Developer Garden."
	var progress: RefCounted = game.progress
	var project: String = progress.heart.active
	if project.is_empty():
		return "Start research at the Heart first."
	var result := Transactions.run_gameplay(game, Transactions.Scope.GARDEN,
		progress.heart.tick.bind(progress,progress.heart.duration(project),false), false)
	if result.completed: Journal.event("developer","finish_research",{"tech":project,"unlocked":progress.heart.has(project)})
	return Transactions.feedback(result, "Research could not be saved.")


static func available_tech(game: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tech in Catalog.DEFINITIONS:
		if tech.id != "heart" and Catalog.enabled(tech.id) and not tech.has("memory") and not game.progress.heart.has(tech.id):
			result.append(tech)
	return result


static func collect_path(heart: RefCounted, id: String, pending: Array[String]) -> bool:
	if heart.has(id) or pending.has(id):
		return true
	var node := Catalog.get_node(id)
	if node.is_empty() or not Catalog.enabled(id) or node.has("memory"):
		return false
	for parent in node.parents:
		if not collect_path(heart,parent,pending):
			return false
	pending.append(id)
	return true


static func test_unlock(game: Node, id: String) -> String:
	if not can_edit(game):
		return "Developer tools are available in the single-player Developer Garden."
	var details := {}
	var result := Transactions.run_gameplay(game, Transactions.Scope.GARDEN, _test_unlock.bind(game,id,details), false)
	if result.completed and not details.is_empty(): Journal.event("developer","test_unlock",details)
	return Transactions.feedback(result, "Could not save the developer action.")

static func _test_unlock(game: Node, id: String, details: Dictionary) -> String:
	var progress: RefCounted = game.progress
	var path: Array[String] = []
	if progress.heart.has(id) or not collect_path(progress.heart,id,path) or path.is_empty():
		return "Choose an available Garden technology."
	var before: Dictionary = progress.heart.capture(progress)
	var old_discoveries: Array = progress.discoveries.duplicate()
	var old_veilcap: bool = progress.veilcap_discovered
	var old_growth: Dictionary = progress.garden_interactions.duplicate(true)
	for tech in path:
		var node := Catalog.get_node(tech)
		if node.get("fact","") == "veilcap":
			progress.discover(progress.VEILCAP)
		progress.knowledge = maxi(progress.knowledge,int(node.knowledge))
		if tech == id:
			# Treat the prerequisite path as the starting Garden for this reveal.
			var baseline := Growth.snapshot(progress)
			progress.garden_interactions = Growth.initialize(progress.garden_interactions,baseline)
			progress.garden_interactions.growth.baseline = baseline
		progress.heart.complete(progress,tech)
	if not preload("res://save_batch.gd").guarded_active() and progress.save_garden() != OK:
		progress.heart.rollback(progress,before)
		progress.discoveries.assign(old_discoveries)
		progress.veilcap_discovered = old_veilcap
		progress.garden_interactions = old_growth
		return "Could not save the developer unlock."
	details.merge({"tech":id,"prerequisites":path.slice(0,-1)})
	return "%s restored." % Catalog.get_node(id).name
