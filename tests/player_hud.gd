extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const Cooldowns = preload("res://player_cooldowns.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const Icons = preload("res://class_skill_icons.gd")
const Summary = preload("res://run_summary_panel.gd")
var failed := false
func check(condition: bool, message: String):
	if not condition:
		failed = true
		printerr("FAIL: ", message)
func _initialize():
	preload("res://combat_balance_preview.gd").enabled = false
	call_deferred("run")
func run():
	var game = load("res://world.tscn").instantiate()
	game.progress.path = "res://.godot/check_hud_" + Crypto.new().generate_random_bytes(8).hex_encode() + ".cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var p: Dictionary = game.players[1]
	p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(1)
	ExpeditionCase.set_membership(game, p, true)
	p.frame = 1
	p.carried_seeds.assign([0, 1, 1])
	p.pouch = true
	p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.DODGE, Time.get_ticks_msec() + 3000)
	p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, Time.get_ticks_msec() + 3000)
	p.carried_parts[1] = 2
	game.seed_reserve(p).parts[1] = 4
	game.progress.parts[0] = 7
	game._process(.016)
	var hud = game.player_hud
	check(hud.heart_icons.size() == 4 and hud.state.hp == 1, "four heart textures reflect player health")
	check(hud.state.carried == 3 and hud.state.pouch, "satchel reflects carried and protected loot")
	check(not hud.state.skill_ready and not hud.state.dodge_ready, "ability slots reflect cooldown readiness")
	var model = preload("res://inventory_model.gd")
	var items = preload("res://item_catalog.gd")
	check(int(model.counts(game,p,"carry").get(items.part_id(1),0))==2, "Wilds inventory reads carried components")
	ExpeditionCase.set_membership(game, p, false)
	check(int(model.counts(game,p,"stash").get(items.part_id(1),0))==4 and int(model.counts(game,p,"shared").get(items.part_id(int(game.Seeds.DEFINITIONS[0].part)),0))==7, "Garden inventory separates personal and shared materials")
	ExpeditionCase.set_membership(game, p, true)
	var private_state: Dictionary = game.player_snapshot(1)[1]
	check(private_state.reserve_parts[1] == 4 and not private_state.dodge_ready, "private multiplayer snapshot supplies HUD data")
	var stranger: Dictionary = game.player_snapshot(999)[1]
	check(not stranger.has("reserve_parts"), "personal inventory stays private")
	game.toggle_overlay(game.pack_menu)
	check(game.pack_menu.visible and not game.inventory.visible and game.inventory_view != null and game.inventory_view.is_visible_in_tree(), "I opens the illustrated inventory")
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	var panel: PanelContainer = game.overlay.get_node("RunSummary")
	game._input(tab)
	check(game.pack_menu.visible and not panel.visible, "Tab leaves other open menus in place")
	game.toggle_overlay(null)
	ExpeditionCase.set_membership(game, p, false)
	game._input(tab)
	check(not panel.visible, "Tab is reserved for the expedition summary in the Wilds")
	ExpeditionCase.set_membership(game, p, true)
	p.frame=0
	p.character.upgrades[0] = 1 << (game.Classes.Warden.OFFSET + 1)
	game._process(.016)
	check(hud.state.skill_names[0]=="Root Anchor" and Icons.icon(hud.state.skill_names[0])!=Icons.icon("Guard"), "the HUD switches to the unlocked subclass icon")
	check_icons(game)

	var before: Dictionary = game.weapon_stats(p)
	p.run_upgrades = {"power":2, "reach":2, "tempo":1, "rift_hook":1}
	p.power = 2
	var current: Dictionary = game.weapon_stats(p)
	var projection := Summary.project(game,p,current)
	var reach: Array = projection.totals.filter(func(row): return row[0]=="Reach")
	check(reach.size()==1 and is_equal_approx(float(current.reach)-float(before.reach),.6)
		and reach[0][1].contains("+0.6 m"), "repeatable cards are summed into one reach row")
	check(projection.totals[0][1].contains("+2") and projection.bonuses.contains("Wind-up hits refresh your dodge"), "strike power and unique behavior are included")
	game._input(tab)
	check(panel.visible and panel.cards.item_count==4, "Tab opens the local summary with one entry per upgrade")
	var card_index: int = projection.cards.find_custom(func(card): return card.title.begins_with("Reaching Roots"))
	check(card_index >= 0 and panel.cards.get_item_tooltip(card_index).contains("Extend the reach")
		and panel.cards.get_item_tooltip(card_index).contains("Rank 2"), "purchased card tooltip shows its effect and rank")
	game._input(tab)
	check(not panel.visible and not game.overlay.visible, "Tab closes the summary")
	await process_frame
	if not failed: print("PASS: textured health, ability states, resources and private inventory HUD")
	quit(1 if failed else 0)


func check_icons(game: Node) -> void:
	var names := {}
	for definition in game.Classes.DEFINITIONS:
		for skill in definition.skills.base + definition.skills.replace:
			names[skill.name] = true
		for node in definition.nodes:
			var values: Dictionary = node.get("skill_change",{}).get("values",{})
			if values.has("name"):
				names[values.name] = true
	for focus in game.Classes.Warden.FOCUSES.values():
		names[focus.name] = true
	for group in game.Classes.Subclasses.FOCUSES:
		for focus in group:
			names[focus.name] = true
	var regions := {}
	for skill_name in names:
		var texture := Icons.icon(skill_name) as AtlasTexture
		check(texture != null and not regions.has(texture.region), "distinct imported icon for " + skill_name)
		if texture != null:
			regions[texture.region] = true
	check(names.size()==Icons.cells.size(), "icon atlas matches the complete class skill roster")
