extends PanelContainer

const Participation = preload("res://expedition_participation.gd")

const Settings = preload("res://app_settings.gd")
const Skills = preload("res://skill_catalog.gd")
const Upgrades = preload("res://run_upgrade_catalog.gd")
const Traits = preload("res://combat_traits.gd")
const UI = preload("res://root_ui.gd")
const Cards = preload("res://affinity_cards.gd")
const Preview = preload("res://combat_balance_preview.gd")
const PlayerVitals = preload("res://player_vitals.gd")
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
var grouped_scroll: ScrollContainer
var grouped_cards: VBoxContainer
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
	if not Participation.is_wild(player):
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
	grouped_scroll = ScrollContainer.new()
	grouped_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grouped_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grouped_scroll.follow_focus = true
	right.add_child(grouped_scroll)
	grouped_cards = VBoxContainer.new()
	grouped_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grouped_cards.add_theme_constant_override("separation", 10)
	grouped_scroll.add_child(grouped_cards)
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
	if not Participation.is_wild(player):
		game.toggle_overlay(null)
	elif Time.get_ticks_msec() >= next_refresh:
		refresh(player)


func refresh(player: Dictionary) -> void:
	next_refresh = Time.get_ticks_msec() + 200
	var stats: Dictionary
	if game.multiplayer.is_server():
		stats = game.weapon_stats(player)
	elif game.client_details_key == str([game.participation.route(), game.participation.floor(), game.participation.seed()]):
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
			var value: Label = game.add_label(totals, 13, UI.INK)
			value.text = row[1]
			if row.size() > 2:
				for label: Label in [title, value]:
					label.tooltip_text = row[2]
					label.mouse_filter = Control.MOUSE_FILTER_PASS
	bonuses.text = view.get("bonuses", "No unique bonuses active.")
	var rows: Array = view.get("cards", [])
	if rows != shown.get("cards", []):
		cards.clear()
		for child in grouped_cards.get_children():
			grouped_cards.remove_child(child)
			child.queue_free()
		for card in rows:
			if card.has("summary"):
				add_grouped_card(card)
			else:
				var index := cards.add_item(card.title)
				cards.set_item_tooltip(index, card.tooltip)
				cards.set_item_custom_fg_color(index, {"Rare": Color("#c5b8ee"), "Epic": Color("#e1b9e5"), "Mythic": Color("#efd189")}.get(card.rarity, UI.INK))
	empty_cards.visible = rows.is_empty()
	cards.visible = cards.item_count > 0
	grouped_scroll.visible = grouped_cards.get_child_count() > 0
	empty_cards.text = "Waiting for expedition details…" if view.is_empty() else "No upgrades acquired yet."
	shown = view


func add_grouped_card(card: Dictionary) -> void:
	var group := VBoxContainer.new()
	grouped_cards.add_child(group)
	var title := Button.new()
	title.text = card.title
	title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.toggle_mode = true
	title.tooltip_text = card.tooltip
	group.add_child(title)
	var summary: Label = game.add_label(group, 13, UI.INK)
	summary.text = card.summary
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var details: Label = game.add_label(group, 13, UI.MUTED)
	details.text = card.tooltip
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.hide()
	title.toggled.connect(func(expanded: bool): details.visible = expanded)


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
	if stats.has("affinity_build"):
		var copies: Array = Cards.project_owned(player,stats,world.DODGE_COOLDOWN_MS) if world.multiplayer.is_server() else player.get("affinity_run_cards",[])
		upgrades = Cards.owned_rows(copies)
		var applied := Cards.applied_totals(copies)
		stats = stats.duplicate()
		world.Weapons.tune_affinity_basic(stats, applied)
		var weapon_band: Vector2i = world.Life.Preview.weapon_range(stats,0)
		stats.damage_min = weapon_band.x
		stats.damage_max = weapon_band.y
		stats.dodge_cooldown = int(stats.get("dodge_cooldown",0)) + int(applied.get("run_dodge_recovery",0))
	upgrades.sort_custom(func(a,b): return a.title.naturalnocasecmp_to(b.title) < 0)
	if world.multiplayer.is_server():
		power = 0 if player.has("combat_ruleset") else int(player.get("power", power))
	if stats.has("damage_min"):
		var band:=Vector2i(stats.damage_min,stats.damage_max)
		rows.append(["Damage", Preview.range_label(band)])
	else:
		rows.append(["Damage", compared(float(stats.damage) + power, base.damage)])
	rows.append(["Reach", compared(stats.reach, base.reach, " m")])
	rows.append(["Attack speed", Preview.attack_speed(int(stats.interval)) + " attacks/sec",
		"Maximum attack speed is %s attacks/sec." % Preview.attack_speed(Cards.STRIKE_MIN_MS)])
	rows.append(["Weapon targets", compared(stats.targets, base.targets)])
	var base_hp: int=world.Life.Preview.hp(world.MAX_HEALTH)
	rows.append(["Max HP", compared(PlayerVitals.maximum_hp(player, base_hp), base_hp, " HP" if world.Life.Preview.enabled else "")])
	var dodge_ms := maxi(Cards.DODGE_MIN_MS, world.DODGE_COOLDOWN_MS - int(stats.get("dodge_cooldown", 0)))
	rows.append(["Dodge cooldown", compared(dodge_ms / 1000.0, world.DODGE_COOLDOWN_MS / 1000.0, " s"),
		"Minimum dodge cooldown is %s s." % decimal(Cards.DODGE_MIN_MS / 1000.0)])
	var profile: Dictionary = player.get("character", world.guest_character.data)
	for slot in 2:
		var skill := Skills.resolve_in_world(world, class_id, slot, profile)
		var cooldown_ms := Skills.Balance.cooldown(skill,stats)
		rows.append([skill.name + " cooldown", decimal(cooldown_ms / 1000.0) + " s",
			"Minimum class ability cooldown is %s s." % decimal(Skills.Balance.COOLDOWN_MIN_MS / 1000.0)])
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
	if stats.has("affinity_build"):
		var grafts = preload("res://expedition_grafts.gd")
		var ledger: Dictionary = grafts.owner_details(player, world.participation.floor()) if world.multiplayer.is_server() else player.get("graft_improvements",{})
		if not ledger.is_empty():
			var names: Dictionary = grafts.REINFORCEMENTS.merged(grafts.ADAPTATIONS)
			var counts := {}
			for copy: Dictionary in ledger.copies:
				counts[copy.id] = int(counts.get(copy.id,0)) + 1
			unique.append("Grafting Altar · %d purchases remaining" % int(ledger.remaining))
			for id: String in counts:
				unique.append(str(names[id].name) + (" ×%d" % counts[id] if int(counts[id])>1 else ""))
	if world.Life.Preview.enabled:
		if world.participation.route()!=world.Campaign.HEART:
			var boundary: bool=world.participation.depth()==world.ROUTE_ROOMS
			var cycle: int=world.participation.cycle()+int(boundary and world.participation.route()==world.Campaign.HOLLOW)
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
