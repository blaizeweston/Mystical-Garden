extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const Cooldowns = preload("res://player_cooldowns.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const Icons = preload("res://class_skill_icons.gd")
const Summary = preload("res://run_summary_panel.gd")
const Cards = preload("res://affinity_cards.gd")
const Skills = preload("res://skill_catalog.gd")
var failed := false
func check(condition: bool, message: String):
	if not condition:
		failed = true
		printerr("FAIL: ", message)
func _initialize():
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
	var initial_tree=game.Classes.connected_tree(1)
	p.character[initial_tree.profile_key]=initial_tree.state(["bloomcaller"])
	p.carried_seeds.assign([0, 1, 1])
	p.pouch = true
	p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.DODGE, Time.get_ticks_msec() + 3000)
	p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, Time.get_ticks_msec() + 3000)
	p.carried_parts[1] = 2
	game.seed_reserve(p).parts[1] = 4
	game.progress.parts[0] = 7
	game._process(.016)
	var hud = UIFixture.control(game,"player_hud")
	check(hud.state.hp == 1 and hud.state.max_hp == 100 and hud.health_orb.hp == 1 and hud.health_pool.visible and hud.pool_vitals.text == "1 / 100 HP", "current health pool presents exact HP and native capacity")
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
	var inventory_action := InputEventAction.new()
	inventory_action.action = "pack_menu"
	inventory_action.pressed = true
	game._input(inventory_action)
	await process_frame
	check(UIFixture.control(game,"pack_menu").visible and UIFixture.control(game,"inventory_view") != null and UIFixture.control(game,"inventory_view").is_visible_in_tree(), "I opens the illustrated inventory")
	await check_inventory_affinity_slots(game,p)
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	var panel: PanelContainer = UIFixture.control(game,"summary_view")
	game._input(tab)
	check(UIFixture.control(game,"pack_menu").visible and not panel.visible, "Tab leaves other open menus in place")
	game.ui.close_panels()
	ExpeditionCase.set_membership(game, p, false)
	game._input(tab)
	check(not panel.visible, "Tab is reserved for the expedition summary in the Wilds")
	ExpeditionCase.set_membership(game, p, true)
	p.frame=0
	var warden_tree=game.Classes.connected_tree(0)
	p.character[warden_tree.profile_key]=warden_tree.state(["rootkeeper"])
	game._process(.016)
	check(hud.state.skill_names[0]=="Root Anchor" and Icons.icon(hud.state.skill_names[0])!=Icons.icon("Guard"), "the HUD switches to the unlocked subclass icon")
	check_icons(game)

	var before: Dictionary = Summary.project(game,p,game.weapon_stats(p))
	var copies: Array[Dictionary]=[
		{"id":"ordinary_weapon_damage","rarity":"Common","amount":1,"floor":3,"acquisition_id":1},
		{"id":"ordinary_weapon_damage","rarity":"Epic","amount":4,"floor":6,"acquisition_id":2},
		{"id":"ordinary_weapon_interval","rarity":"Uncommon","amount":35,"floor":9,"acquisition_id":3},
	]
	p[Cards.STATE]=Cards.Ledger.new(copies)
	var projection := Summary.project(game,p,game.weapon_stats(p))
	var speed_before: Array=before.totals.filter(func(row):return row[0]=="Attack speed")
	var speed_after: Array=projection.totals.filter(func(row):return row[0]=="Attack speed")
	check(speed_before.size()==1 and speed_after.size()==1 and speed_before[0][1]!=speed_after[0][1],"summary resolves the acquired attack-speed contribution")
	var damage_index: int=projection.cards.find_custom(func(card):return card.id=="ordinary_weapon_damage")
	check(damage_index>=0 and projection.cards[damage_index].summary.contains("+5 damage") and projection.cards[damage_index].tooltip.contains("Common") and projection.cards[damage_index].tooltip.contains("Epic"),"summary adds actual mixed-rarity copies without promotion")
	check(not projection.bonuses.contains("Wind-up hits refresh your dodge"),"retired card behavior is absent")
	game._input(tab)
	check(panel.visible and panel.grouped_cards.get_child_count()==2,"Tab opens one modern group per acquired identity")
	game._input(tab)
	check(not panel.visible and not game.ui.is_overlay_open(), "Tab closes the summary")
	await process_frame
	if not failed: print("PASS: current health pool, ability states, resources and private inventory HUD")
	quit(1 if failed else 0)


func check_icons(game: Node) -> void:
	var names := {}
	for class_id: int in game.Classes.DEFINITIONS.size():
		var tree=game.Classes.connected_tree(class_id)
		for focus: Dictionary in tree.nodes.filter(func(node):return int(node.tier)==0):
			var profile: Dictionary=game.Character.blank()
			profile[tree.profile_key]=tree.state([focus.id])
			for slot in 2:
				names[Skills.resolve(class_id,slot,profile).name]=true
	var regions := {}
	for skill_name in names:
		var texture := Icons.icon(skill_name) as AtlasTexture
		check(texture != null and not regions.has(texture.region), "distinct imported icon for active " + skill_name)
		if texture != null:
			regions[texture.region] = true
	# Older atlas cells remain reusable art; they are not executable skill coverage.
	check(names.size()==20,"icons cover fifteen starting-focus Q abilities and five common R abilities")


func check_inventory_affinity_slots(game: Node, player: Dictionary) -> void:
	var original: Array=[player.weapon,player.secondary,player.catalyst]
	player.weapon=game.Seeds.DEFINITIONS[game.Seeds.index_of("thorn_bloom")].part
	player.secondary=game.Seeds.DEFINITIONS[game.Seeds.index_of("ember_fern")].part
	player.catalyst=game.Seeds.DEFINITIONS[game.Seeds.index_of("dewcap")].part
	var panel=UIFixture.control(game,"inventory_view")
	panel.key=""
	panel.refresh()
	await process_frame
	check(UIFixture.control(game,"pack_menu").visible and panel.is_visible_in_tree() and panel.equipment.get_child_count()==3,"the actual open inventory presents all three affinity slots")
	check(not panel.state.has("core") and not panel.state.affinity_build.is_empty(),"inventory uses a local resolved affinity projection without the retired Core shape")
	check(panel.core_skill.visible and panel.core_skill.text=="Core skill · Thorn Line","inventory resolves the current Thorn Core ability label")
	var names: Array=["Thorn Line","Burning Strikes","Drenched"]
	var families: Array=["Thorn","Fire","Water"]
	for index in 3:
		var slot=panel.equipment.get_child(index)
		check(slot.tooltip_text.contains(families[index]) and slot.tooltip_text.contains(names[index]),"equipment tooltip describes its actual "+game.Weapons.SLOT_NAMES[index]+" effect")
		panel.select_entry(slot.entry)
		check(panel.details.text.contains(game.Weapons.SLOT_NAMES[index]) and panel.details.text.contains(names[index]),"selecting "+game.Weapons.SLOT_NAMES[index]+" shows its native affinity details")
	check(panel.equipment.get_child(2).tooltip_text.contains("Cultivate Bloom") and panel.equipment.get_child(2).tooltip_text.contains("Spore Nova"),"Catalyst tooltip names both resolved native class actions")
	player.weapon=original[0];player.secondary=original[1];player.catalyst=original[2]
	panel.key=""
	panel.refresh()
