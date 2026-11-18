extends RefCounted

const Participation = preload("res://expedition_participation.gd")
## Card views and combat effects. Entries are authored in the affinity catalog.
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const Catalog = preload("res://affinity_card_catalog.gd")
const CardState = preload("res://affinity_card_ledger.gd")
const Ledger = CardState.Ledger
const Journal = preload("res://diagnostic_journal.gd")
const Preview = preload("res://combat_balance_preview.gd")
const STATE := "affinity_cards"
const SERIAL := &"affinity_offer_serial"
const COMMAND := "affinity_checkpoint_"
const STRIKE_MIN_MS := CardState.STRIKE_MIN_MS
const DODGE_MIN_MS := CardState.DODGE_MIN_MS


static func clear(player: Dictionary) -> void:
	player.erase(STATE)


# Read adapter for existing actor consumers. The ledger owns the records.
static func ledger(player: Dictionary) -> Ledger:
	return player.get(STATE) if Participation.is_wild(player) else null


static func totals(player: Dictionary) -> Dictionary:
	var run := ledger(player)
	return run.totals() if run != null else {}


static func amount(player: Dictionary, card_id: String) -> int:
	var run := ledger(player)
	return run.amount(card_id) if run != null else 0


static func completed_floor(player: Dictionary) -> int:
	var run := ledger(player)
	return run.completed_floor() if run != null else 0


static func project_owned(player: Dictionary, stats: Dictionary, dodge_base: int) -> Array:
	var run := ledger(player)
	return run.project_owned(stats, dodge_base) if run != null else []


static func attack_interval(interval_ms: int, reduction_ms: int) -> int:
	return maxi(STRIKE_MIN_MS, interval_ms - reduction_ms)


static func checkpoint_view(run: Ledger, stats: Dictionary, dodge_base: int, essence: int, waiting: bool) -> Dictionary:
	var offer := run.offer()
	var result := {
		"affinity_offer": true, "revision": offer.revision, "choices": [], "closed": offer.closed,
		"exhausted": run.exhausted(), "acquired": run.count(), "limit": Catalog.PLAYTEST.acquisition_limit,
		"reroll_cost": 0, "reroll_enabled": false, "reroll_reason": "",
	}
	if bool(offer.closed) or bool(result.exhausted) or waiting:
		return result
	for index in offer.cards.size():
		var option: Dictionary = offer.cards[index]
		var definition: Dictionary = Catalog.DEFINITIONS[option.id]
		var reason := run.option_refusal(option, stats, dodge_base)
		var limit := Ledger.parameter_limit(definition, stats, dodge_base)
		var active := mini(limit, run.amount(option.id)) if Ledger.requirement(definition, stats.affinity_build).is_empty() else 0
		var choice := choice_view(definition, option, run.copies_for(option.id), active, reason, int(stats.interval))
		choice.merge({"choice": index, "id": option.id, "title": definition.title,
			"rarity": option.rarity, "scope": str(definition.scope).capitalize(), "unique": definition.policy == "unique",
			"enabled": reason.is_empty(), "cost": 0})
		result.choices.append(choice)
	var cost := run.reroll_cost()
	result.reroll_cost = cost
	if cost > 0:
		var replacement := run.can_replace_offer(stats, dodge_base)
		result.reroll_enabled = replacement and essence >= cost
		if not replacement:
			result.reroll_reason = "No different full offer is available."
		elif not result.reroll_enabled:
			result.reroll_reason = "Not enough Essence to reroll."
	else:
		result.reroll_reason = "All rerolls used for this checkpoint."
	return result


static func applied_totals(copies: Array) -> Dictionary:
	var result := {}
	for copy: Dictionary in copies:
		result[copy.id] = copy.applied
	return result


static func rarity_mix(copies: Array) -> String:
	var counts := {}
	for copy: Dictionary in copies:
		counts[copy.rarity] = int(counts.get(copy.rarity, 0)) + 1
	var labels: PackedStringArray = []
	for rarity_name: String in Catalog.RARITIES:
		if counts.has(rarity_name):
			labels.append("%d %s" % [counts[rarity_name], rarity_name])
	return ", ".join(labels)


static func copy_total(copies: Array) -> int:
	var total := 0
	for copy: Dictionary in copies:
		total += int(copy.amount)
	return total


static func copy_list(definition: Dictionary, copies: Array) -> String:
	if copies.is_empty():
		return "No copies acquired."
	var lines: PackedStringArray = [rarity_mix(copies)]
	for copy: Dictionary in copies:
		lines.append("%s · %s · Floor %d" % [copy.rarity, Catalog.contribution(definition, int(copy.amount)), int(copy.floor)])
	return "\n".join(lines)


static func detail_text(definition: Dictionary) -> String:
	var needs: Dictionary = definition.requires
	var lines: PackedStringArray = []
	if needs.has("family"):
		lines.append("Requires %s %s." % [str(needs.family).capitalize(), str(definition.scope).capitalize()])
	elif needs.has("class"):
		lines.append("Requires %s and %s." % [str(needs["class"]).capitalize(), needs.skill])
	lines.append(definition.detail)
	if definition.policy == "unique":
		lines.append("One acquisition per expedition.")
	else:
		lines.append("Up to %d useful copies. Each copy keeps its offered rarity and contribution." % int(definition.limit))
	return "\n".join(lines)


static func choice_view(definition: Dictionary, option: Dictionary, owned: Array, active: int, reason: String, interval_ms: int) -> Dictionary:
	var amount_offered: int = int(option.amount)
	var description := Catalog.effect_text(definition, amount_offered)
	var preview := ""
	var detail := detail_text(definition)
	if definition.policy == "stackable":
		var total := copy_total(owned)
		var current := Catalog.contribution(definition, active)
		if reason.is_empty():
			var combined := Catalog.contribution(definition, active + amount_offered)
			var count := owned.size()
			if definition.parameter == "strike_interval":
				var before := attack_interval(interval_ms, active)
				var after := attack_interval(interval_ms, active + amount_offered)
				preview = "Attack speed: %s → %s attacks/sec" % [Preview.attack_speed(before), Preview.attack_speed(after)]
			elif definition.parameter == "strike_damage":
				preview = "Acquired: %d %s (%s) → %d %s (%s)" % [
					count, "copy" if count == 1 else "copies", current,
					count + 1, "copy" if count == 0 else "copies", combined]
			else:
				preview = "%s: %s → %s" % [Catalog.contribution_label(definition), current, combined]
		detail += "\n\nCurrently active: " + current
		if active != total:
			detail += " · Total owned: " + Catalog.contribution(definition, total)
		detail += "\n" + copy_list(definition, owned)
	if not reason.is_empty():
		preview = reason
	return {"description": description, "preview": preview, "detail": detail}


static func owned_rows(copies: Array) -> Array:
	var by_id := {}
	for copy: Dictionary in copies:
		if not by_id.has(copy.id):
			by_id[copy.id] = []
		by_id[copy.id].append(copy)
	var rows: Array = []
	for id: String in by_id:
		var group: Array = by_id[id]
		var first: Dictionary = group[0]
		var definition: Dictionary = Catalog.DEFINITIONS[id]
		var scope := str(definition.scope).capitalize()
		var unique: bool = definition.policy == "unique"
		var reason: String = first.reason
		var summary := "Unique · " + scope if unique else rarity_mix(group) + " · " + scope
		var total := copy_total(group)
		var applied := int(first.applied)
		if unique:
			summary += "\n" + Catalog.effect_text(definition, total)
		else:
			summary += "\n%s: %s" % [Catalog.contribution_label(definition), Catalog.contribution(definition, total)]
			if definition.scope in ["core", "form", "catalyst", "class"] or applied != total:
				summary += " · Active: " + Catalog.contribution(definition, applied)
		if not reason.is_empty():
			summary += "\nInactive: " + reason
		var detail := detail_text(definition)
		if not unique:
			detail += "\n\n" + copy_list(definition, group)
		rows.append({"id": id, "title": definition.title if unique else "%s ×%d" % [definition.title, group.size()],
			"summary": summary, "tooltip": detail})
	return rows


static func affinity_potency(player: Dictionary, source: String, material: Dictionary, potency: Dictionary) -> void:
	if source not in ["core", "form", "catalyst"]:
		return
	var contributions := totals(player)
	for id: String in contributions:
		var definition: Dictionary = Catalog.DEFINITIONS[id]
		if definition.scope != source:
			continue
		var requires: Dictionary = definition.requires
		if material.get("primary_affinity") != requires.family:
			continue
		if source == "core" and material.get("affinity_core_skill_id") != requires.skill:
			continue
		if source == "form" and material.get("behavior") != requires.behavior:
			continue
		var parameter: String = definition.parameter
		potency[parameter] = int(potency.get(parameter, 0)) + int(contributions[id])


static func tune_class(player: Dictionary, skill: Dictionary, build: Dictionary, scale: int) -> void:
	if int(skill.slot) != 1:
		return
	var contributions := totals(player)
	for id: String in contributions:
		var definition: Dictionary = Catalog.DEFINITIONS[id]
		if definition.scope != "class" or not Ledger.requirement(definition, build).is_empty():
			continue
		var parameter: String = definition.parameter
		var contribution := int(contributions[id])
		if parameter == "damage":
			skill.damage = float(skill.damage) + float(contribution) / scale
		else:
			skill[parameter] = int(skill.get(parameter, 0)) + contribution


static func bloom_echo_source(game: Node, player: Dictionary, skill: Dictionary, now: int) -> Dictionary:
	if int(skill.get("bloom_echo_hp", 0)) <= 0 or skill.get("bloom_echo_spent", false):
		return {}
	var owner: int = game.Traits.player_id(game, player)
	for field: Dictionary in game.trait_events:
		if field.get("native_weaver_bloom", false) and int(field.owner) == owner \
				and int(field.epoch) == int(game.participation.epoch()) and int(field.until) > now \
				and PlayerLifecycle.matches(player,int(field.get("life",-1))):
			return field
	return {}


static func bloom_contains(game: Node, bloom: Dictionary, target: int) -> bool:
	var point: Vector3 = game.enemy_position(target)
	return point.distance_to(bloom.position) <= float(bloom.radius) and game.battlefield.clear_line(bloom.position, point)


static func bloom_echo(game: Node, player: Dictionary, bloom: Dictionary, skill: Dictionary, now: int) -> void:
	if int(game.participation.epoch()) != int(bloom.epoch) or not game.Life.alive(player):
		return
	skill.bloom_echo_spent = true
	var hp: int = skill.bloom_echo_hp
	var point: Vector3 = bloom.position
	var targets: Array[int] = game.skill_area_targets(point, float(bloom.radius), point)
	game.emit_combat_event("ability", "bloom_echo", point, point, .5, Color("#b5c775"), float(bloom.radius), bloom.owner,
		{"label": "Echoing Growth"})
	for target in targets:
		if game.persistence_session.is_blocked():
			break
		game.apply_weapon_hit(player, target, point,
			{"damage": 0.0, "affinity_hp": hp, "trait_secondary": true, "core_hit": true, "knockback": -.35}, now)
	Journal.event("combat", "affinity_bloom_echo", {"actor": bloom.owner, "field": bloom.visual_id,
		"epoch": bloom.epoch, "hp": hp, "targets": targets})
