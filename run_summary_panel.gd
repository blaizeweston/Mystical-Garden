extends PanelContainer

const Settings = preload("res://app_settings.gd")
const Skills = preload("res://skill_catalog.gd")
const Upgrades = preload("res://run_upgrade_catalog.gd")
const Traits = preload("res://combat_traits.gd")
const UI = preload("res://root_ui.gd")
const EXTRA_STATS := {
	"windup_damage": ["Wind-up damage", " hp", 1.0],
	"heal_on_kill": ["Health on kill", " hp", 1.0],
	"skill_heal": ["Class skill healing bonus", " HP", 1.0],
	"skill_duration": ["Class skill duration", " s", .001],
	"stagger": ["Hit stagger", " s", .001],
	"recovery": ["Enemy recovery", " s", .001],
	"knockback": ["Knockback", " m", 1.0],
	"pull": ["Pull", " m", 1.0],
	"graft_chance": ["Grafting chance", "%", 100.0],
}

var game: Node
var heading: Label
var totals: GridContainer
var bonuses: Label
var cards: ItemList
var empty_cards: Label
var close_button: Button
var shown: Dictionary
var next_refresh := 0


static func mount(world: Node) -> void:
	var panel = load("res://run_summary_panel.gd").new()
	panel.name = "RunSummary"
	panel.game = world
	panel.hide()
	world.overlay.add_child(panel)


static func handle_input(world: Node, event: InputEvent) -> bool:
	if not event.is_action_pressed("run_summary") or world.session == "Connecting" or world.returning_to_title:
		return false
	var panel: PanelContainer = world.overlay.get_node_or_null("RunSummary")
	if panel == null or (world.overlay.visible and not panel.visible):
		return false
	var player: Dictionary = world.players.get(world.local_player_id(), {})
	if not player.get("wild", false):
		return false
	world.toggle_overlay(panel)
	if panel.visible:
		panel.refresh(player)
		panel.close_button.grab_focus()
	return true


func _ready() -> void:
	add_theme_stylebox_override("panel", UI.root_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	heading = game.add_label(box, 22, UI.INK)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(columns)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	scroll.add_child(left)
	game.add_label(left, 16, UI.GREEN).text = "Combat stats"
	totals = GridContainer.new()
	totals.columns = 2
	totals.add_theme_constant_override("v_separation", 5)
	totals.add_theme_constant_override("h_separation", 16)
	left.add_child(totals)
	game.add_label(left, 16, UI.GREEN).text = "Unique bonuses"
	bonuses = game.add_label(left, 13, UI.INK)
	bonuses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	game.add_label(right, 16, UI.GREEN).text = "Expedition upgrades"
	empty_cards = game.add_label(right, 13, UI.MUTED)
	empty_cards.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cards = ItemList.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("v_separation", 8)
	right.add_child(cards)
	close_button = game.add_button(box, "Close", func(): game.toggle_overlay(null))
	get_viewport().size_changed.connect(fit)
	visibility_changed.connect(func(): set_process(is_visible_in_tree()))
	fit()
	set_process(false)


func fit() -> void:
	var room := get_viewport_rect().size - Vector2(36, 36)
	custom_minimum_size = Vector2(790, 530).min(room.max(Vector2.ZERO))


func _process(_delta: float) -> void:
	var player: Dictionary = game.players.get(game.local_player_id(), {})
	if not player.get("wild", false):
		game.toggle_overlay(null)
	elif Time.get_ticks_msec() >= next_refresh:
		refresh(player)


func refresh(player: Dictionary) -> void:
	next_refresh = Time.get_ticks_msec() + 200
	var stats: Dictionary
	if game.multiplayer.is_server():
		stats = game.weapon_stats(player)
	elif game.client_details_key == str([game.destination, game.encounter_number, game.map_seed]):
		stats = player.get("weapon_stats", {})
	var view := project(game, player, stats)
	var shortcut := Settings.hint("run_summary")
	close_button.text = "Close" if shortcut == "Unbound" else "Close · " + shortcut
	if view == shown and not heading.text.is_empty():
		return
	heading.text = "Expedition" if view.is_empty() else "Expedition · " + str(stats.name)
	if view.get("totals", []) != shown.get("totals", []) or heading.text == "Expedition":
		for child in totals.get_children():
			totals.remove_child(child)
			child.queue_free()
		for row in view.get("totals", []):
			var title: Label = game.add_label(totals, 13, UI.INK)
			title.text = row[0]
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			game.add_label(totals, 13, UI.INK).text = row[1]
	bonuses.text = view.get("bonuses", "No unique bonuses active.")
	if view.get("cards", []) != shown.get("cards", []):
		cards.clear()
		for card in view.cards:
			var index := cards.add_item(card.title)
			cards.set_item_tooltip(index, card.tooltip)
			cards.set_item_custom_fg_color(index, {"Rare": Color("#c5b8ee"), "Epic": Color("#e1b9e5"), "Mythic": Color("#efd189")}.get(card.rarity, UI.INK))
	empty_cards.visible = cards.item_count == 0
	cards.visible = cards.item_count > 0
	empty_cards.text = "Waiting for expedition details…" if view.is_empty() else "No upgrades purchased yet."
	shown = view


static func project(world: Node, player: Dictionary, stats: Dictionary) -> Dictionary:
	if stats.is_empty():
		return {}
	var rows: Array = []
	var class_id := int(player.frame)
	var base: Dictionary = world.Classes.DEFINITIONS[class_id].weapons[int(player.get("weapon_kind", 0))]
	var upgrades: Array = []
	var power := 0
	var rift_hook := false
	for entry in Upgrades.all():
		var rank := int(preload("res://combat_ruleset.gd").legacy_ranks(player).get(entry.id, 0))
		if rank <= 0:
			continue
		power += int(entry.effects.get("power", 0)) * rank
		rift_hook = rift_hook or entry.effects.has("rift_hook")
		var detail: String = Upgrades.effect_text(entry).strip_edges()
		var tooltip: String = entry.name + "\n" + entry.rarity + " · Rank " + str(rank)
		if not str(entry.description).is_empty():
			tooltip += "\n\n" + entry.description
		if not detail.is_empty():
			tooltip += "\n\n" + ("Per rank\n" if int(entry.max_rank) != 1 else "") + detail
		upgrades.append({"title": entry.name + ("  ×%d" % rank if rank > 1 else ""), "tooltip": tooltip, "rarity": entry.rarity})
	upgrades.sort_custom(func(a,b): return a.title.naturalnocasecmp_to(b.title) < 0)
	if world.multiplayer.is_server():
		power = 0 if player.has("combat_ruleset") else int(player.get("power", power))
	if stats.has("damage_min"):
		var band:=Vector2i(stats.damage_min,stats.damage_max)
		rows.append(["Strike damage", world.Life.Preview.range_label(band)+" HP"])
	else:
		rows.append(["Strike damage", compared(float(stats.damage) + power, base.damage)])
	rows.append(["Reach", compared(stats.reach, base.reach, " m")])
	rows.append(["Strike interval", compared(float(stats.interval)/1000.0, float(base.strike_ms)/1000.0, " s")])
	rows.append(["Weapon targets", compared(stats.targets, base.targets)])
	var base_hp: int=world.Life.Preview.hp(world.MAX_HEALTH)
	rows.append(["Max health", compared(player.get("max_hp", base_hp), base_hp, " HP" if world.Life.Preview.enabled else "")])
	rows.append(["Dodge cooldown", compared(maxi(350, world.DODGE_COOLDOWN_MS-int(stats.get("dodge_cooldown", 0)))/1000.0,
		world.DODGE_COOLDOWN_MS/1000.0, " s")])
	var profile: Dictionary = player.get("character", world.guest_character.data)
	for slot in 2:
		var skill := Skills.resolve_in_world(world, class_id, slot, profile)
		var duration := Skills.Balance.cooldown(skill,stats)
		rows.append([skill.name + " cooldown", decimal(duration/1000.0) + " s"])
	for key in EXTRA_STATS:
		var value := float(stats.get(key, 0))
		if key=="heal_on_kill" and world.Life.Preview.enabled:
			if value>0.0:
				rows.append(["Healing on kill",world.Life.Preview.heal_label(value)])
				var limit: int=world.Life.Sustain.KILL_BUDGET_HP
				rows.append(["Kill healing left this floor","%d / %d HP"%[int(stats.get("kill_heal_remaining",limit)),limit]])
			continue
		if key in ["windup_damage","heal_on_kill","skill_heal"]:
			value=float(world.Life.Preview.effect_hp(value))
		if not is_zero_approx(value):
			var spec: Array = EXTRA_STATS[key]
			rows.append([spec[0], ("+" if value > 0 else "−") + decimal(absf(value)*float(spec[2])) + spec[1]])
	var unique: Array = stats.get("interactions", []).duplicate()
	if world.Life.Preview.enabled:
		if world.destination!=world.Campaign.HEART:
			var boundary: bool=world.depth==world.ROUTE_ROOMS
			var cycle: int=world.difficulty_cycle+int(boundary and world.destination==world.Campaign.HOLLOW)
			var center: int=world.Life.Sustain.recovery_center_hp(boundary,cycle)
			rows.append(["Next gate recovery",world.Life.Preview.range_label(world.Life.Preview.heal_band(center))+" HP"])
		var core: Dictionary = stats.get("core_build", {}).get("skill", {})
		if not core.is_empty():
			rows.append([str(core.name) + " cooldown", decimal(float(core.cooldown_ms)/1000.0) + " s"])
			var resolved: Array[String] = Upgrades.CoreRules.Balance.effect_lines(core)
			if not resolved.is_empty():
				unique.push_front(str(core.name) + "\n" + "\n".join(resolved))
	if stats.pattern != base.pattern:
		unique.append("Attack pattern · " + str(stats.pattern).capitalize())
	var traits := {}
	for key in Traits.KEYS:
		if float(stats.get(key, 0)) > 0.0:
			traits[key] = snappedf(float(stats[key]), .01)
	var trait_text := Traits.describe(traits,true)
	if not trait_text.is_empty():
		unique.append(trait_text)
	if rift_hook:
		unique.append("Rift Hook · Wind-up hits refresh your dodge.")
	return {"totals": rows, "cards": upgrades, "bonuses": "\n".join(unique) if not unique.is_empty() else "No unique bonuses active."}


static func decimal(value: float) -> String:
	return ("%.2f" % value).rstrip("0").trim_suffix(".")


static func compared(total: float, base: float, unit: String = "") -> String:
	var delta := total-base
	var formatted := decimal(total) + unit
	if not is_zero_approx(delta):
		formatted += "  (%s%s)" % ["+" if delta > 0 else "−", decimal(absf(delta)) + unit]
	return formatted
