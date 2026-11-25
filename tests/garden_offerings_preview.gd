extends SceneTree

const Preview = preload("res://assets/terrain_m02/terrain_preview.tscn")
const Items = preload("res://item_catalog.gd")
const Offerings = preload("res://assets/terrain_m02/garden_offerings.gd")
const Garden = preload("res://assets/terrain_m02/garden_expansion.gd")

var errors := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		errors += 1
		printerr("FAIL: ", label)

func run() -> void:
	var scene := Preview.instantiate()
	root.add_child(scene)
	await process_frame
	var view = scene.expansion
	var funds: Offerings = view.offerings
	var plant := _first_part(funds, "plant_part")
	var monster := _first_part(funds, "monster_part")
	check(plant == Items.part_id(Items.get_item(plant).legacy_part)
		and monster == Items.part_id(Items.get_item(monster).legacy_part)
		and Items.get_item(monster).monster_tags.size() > 0, "existing canonical part IDs and monster source")
	check(funds.quote({Items.seed_id(0): 1}).is_empty() and funds.quote({plant: -1}).is_empty()
		and funds.quote({plant: 1.5}).is_empty() and funds.quote({plant: funds.available(plant) + 1}).is_empty(),
		"reject seed, invalid quantities, and reserved stock")
	var rates := {"Common":Vector2i(2,1),"Uncommon":Vector2i(3,2),"Rare":Vector2i(4,3),"Epic":Vector2i(6,5),"Mythic":Vector2i(9,8)}
	var checked := {}
	for id: String in funds.items:
		var rarity: String = funds.items[id].rarity
		var single := funds.quote({id: 1})
		check(Vector2i(single.energy, single.knowledge)==rates[rarity], "both unit rewards for "+id)
		checked[rarity]=true
	check(checked.size()==5,"material catalog exercises all five rarities")
	var reserve_probe := Offerings.new()
	check(reserve_probe.offer(reserve_probe.quote({plant: reserve_probe.available(plant)}))
		and reserve_probe.inventory[plant] == reserve_probe.reserved[plant] and reserve_probe.available(plant) == 0,
		"using all available stock still leaves the reserved items intact")
	var small := {"cells": {1: true}}
	var large := {"cells": {1: true, 2: true, 3: true}}
	check(funds.expansion_cost(large, 0, 1) > funds.expansion_cost(small, 0, 1)
		and funds.expansion_cost(small, 16, 1) > funds.expansion_cost(small, 0, 1),
		"cost scales with newly usable cells and previously reclaimed land")
	view.open_offerings()
	var panel = view.offering_dialog
	_pick(panel, plant)
	panel.quantity.value = 1
	var original: int = funds.inventory[plant]
	var started := Time.get_ticks_usec()
	panel.confirm_offer.pressed.emit()
	panel.confirm_offer.pressed.emit()
	var ui_usec := Time.get_ticks_usec() - started
	check(funds.inventory[plant] == original - 1 and funds.energy == funds.unit_energy(plant),
		"actual dialog confirms a partial plant offering exactly once")
	var old_energy := funds.energy
	_pick(panel, monster)
	panel.quantity.value = 1
	check(panel.review.items == {monster: 1}, "monster-only quote")
	panel.confirm_offer.pressed.emit()
	check(funds.energy == old_energy + funds.unit_energy(monster), "monster-only energy accumulates")
	_pick(panel, plant)
	panel.quantity.value = 40
	_pick(panel, monster)
	panel.quantity.value = 45
	var quote: Dictionary = panel.review.duplicate(true)
	var forged := quote.duplicate(true)
	forged.energy += 1
	check(not funds.offer(forged) and funds.energy == old_energy + funds.unit_energy(monster),
		"reject inflated quote without spending")
	var monster_before: int = funds.inventory[monster]
	panel.confirm_offer.pressed.emit()
	check(funds.inventory[plant] == original - 41 and funds.inventory[monster] == monster_before - 45
		and funds.energy == old_energy + funds.unit_energy(monster) + quote.energy and not funds.offer(quote),
		"mixed offering consumes both stacks, even if the old quote is replayed")
	panel.hide()

	view.set_active(true)
	check(not view.active, "stored energy cannot bypass the Knowledge prerequisite")
	view.knowledge.grant_test_knowledge()
	check(view.knowledge.research("clearing_1") and view.knowledge.research("cultivation_grounds"),
		"existing research grants eligibility without changing the layout")
	var model = view.construction.model
	var id: int = model.commit("bed", Vector2(2.34, -4.58), 0.37, view.pawn)
	check(id > 0, "grow around an existing cultivation bed")
	if id == 0:
		quit(1)
		return
	model.records[id].state.crop = "moonleaf"
	var state: Garden = view.state
	var replay := Garden.new(state.terrain, state.layout, state.spacing, state.seed_value, roundi(state.extent / state.spacing))
	replay.construction_clearance = state.construction_clearance.duplicate(true)
	var sample_setup := PackedInt64Array()
	var sample_costs := PackedInt32Array()
	var initial_owned := state.owned.duplicate()
	var initial_balance := funds.energy
	for i in 6:
		view.set_active(true)
		var options := state.frontier_options()
		if options.is_empty():
			check(false, "six successive growth events fit the reference Garden")
			break
		var plan := options[0]
		var old_balance := funds.energy
		var cost := funds.expansion_cost(plan, state.reclaimed_cells, 1)
		check(funds.expansion_cost(plan, state.reclaimed_cells, 3) <= cost, "research can reduce cost")
		check(view.select_frontier(plan.sector) and str(cost) in view.status.text, "frontier exposes its cost")
		if i == 0:
			funds.energy = 0
			view.confirm_growth()
			check(state.revision == 0 and funds.energy == 0, "insufficient energy refuses the already-previewed expansion")
			funds.energy = old_balance
			view.cancel.pressed.emit()
			check(state.revision == 0 and funds.energy == old_balance, "cancel spends no energy")
			view.set_active(true)
			view.select_frontier(plan.sector)
			var fresh: Dictionary = view.preview
			view.preview = fresh.duplicate(true)
			view.preview.cells[Vector2i.ZERO] = &"soil"
			view.confirm_growth()
			check(state.revision == 0 and funds.energy == old_balance, "invalid changed preview consumes no energy")
			view.select_frontier(plan.sector)
		view.confirm_growth()
		view.confirm_growth()
		check(state.revision == i + 1 and funds.energy == old_balance - cost, "one expansion and one exact debit")
		view.finish_animation()
		check(replay.apply(replay.proposal(plan.sector)) and replay.owned == state.owned and replay.roots == state.roots,
			"deterministic reconstruction with the same ordered inputs")
		check(state.entrance_clear() and view.network.size() == state.revision
			and not view.barrier.walkable(Vector2(state.extent, 0)), "Gate, roots and enclosing barrier remain intact")
		sample_setup.append(int(view.last_metrics.get("setup_usec", 0)))
		sample_costs.append(cost)
	check(state.expansion_history.size() == 6 and state.revision == 6 and funds.energy < initial_balance,
		"tier one has no three-expansion lifetime cap")
	check(model.records[id].state.crop == "moonleaf" and model.records[id].at == Vector2(2.34, -4.58),
		"building ID, transform and crop are preserved")
	for cell in initial_owned:
		check(initial_owned[cell] == state.owned[cell], "ownership history remains intact")

	view.set_active(true)
	var limited := false
	for sector in Garden.DIRECTIONS.size():
		limited = limited or bool(state.proposal(sector, true).get("coverage_limited", false))
	check(limited and "generated terrain limit" in view.status.text, "terrain exhaustion is explained in the live preview")
	print("M16_METRICS ", JSON.stringify({"offering_ui_usec": ui_usec, "setup_usec": sample_setup,
		"expansion_costs": sample_costs, "reclaimed_cells": state.reclaimed_cells, "expansions": state.revision}))
	if errors == 0:
		print("PASS: existing part offerings, exact debits, and repeatable Garden growth")
	quit(int(errors > 0))

func _pick(panel, item: String) -> void:
	for index in panel.list.item_count:
		if panel.list.get_item_metadata(index) == item:
			panel.list.select(index)
			panel.list.item_selected.emit(index)
			return

func _first_part(model: Offerings, category: String) -> String:
	for id: String in model.items:
		if model.items[id].category == category:
			return id
	return ""
