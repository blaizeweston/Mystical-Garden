extends RefCounted
## Expedition-only card state. Entries are authored in the affinity catalog.
const Catalog = preload("res://affinity_card_catalog.gd")
const Gate = preload("res://gate_interaction.gd")
const Journal = preload("res://diagnostic_journal.gd")
const STATE := "affinity_cards"
const SERIAL := &"affinity_offer_serial"
const COMMAND := "affinity_checkpoint_"
const STRIKE_MIN_MS := 230
const DODGE_MIN_MS := 350


static func clear(player: Dictionary) -> void:
	player.erase(STATE)


static func state(player: Dictionary) -> Dictionary:
	if not player.has(STATE):
		player[STATE] = {"copies": [], "totals": {}, "offer": {}}
	return player[STATE]


static func totals(player: Dictionary) -> Dictionary:
	if not player.get("wild", false):
		return {}
	return player.get(STATE, {}).get("totals", {})


static func amount(player: Dictionary, card_id: String) -> int:
	return int(totals(player).get(card_id, 0))


static func requirement(definition: Dictionary, build: Dictionary) -> String:
	var requires: Dictionary = definition.requires
	var scope: String = definition.scope
	if scope in ["core", "form", "catalyst"]:
		var part: Dictionary = build.get(scope, {})
		var family: String = requires.family
		if part.get("state") != "ready" or part.get("primary_affinity") != family:
			return "Equip a %s %s." % [family.capitalize(), scope.capitalize()]
		match scope:
			"core":
				if part.get("affinity_core_skill_id") != requires.skill:
					return "Requires its supported Core skill."
			"form":
				if part.get("behavior") != requires.behavior:
					return "Requires its supported Form behavior."
			"catalyst":
				if not build.capabilities.class_actions or not build.class_skills.any(func(adapter):
					return adapter.get("response", "") in requires.responses):
					return "Requires a class skill that uses this Catalyst response."
	elif scope == "class":
		if build.get("class_id") != requires["class"]:
			return "Requires " + str(requires["class"]).capitalize() + "."
		var skills: Array = build.class_skills
		var ability: Dictionary = skills[1].get("native_skill", {})
		if not build.capabilities.class_actions or ability.get("variant") != "base" \
				or ability.get("mode") != requires.mode or ability.get("name") != requires.skill:
			return "Requires native " + str(requires.skill) + "."
		if requires.has("focus"):
			if build.focus_id != requires.focus or skills[0].get("native_skill", {}).get("field") != requires.q_field:
				return "Requires the Bloomcaller starting focus and Cultivate Bloom."
	elif scope == "weapon" and not build.get("capabilities", {}).get(requires.capability, false):
		return "Requires a functioning ordinary weapon attack."
	return ""


static func parameter_limit(definition: Dictionary, stats: Dictionary, dodge_base: int) -> int:
	match definition.parameter:
		"strike_interval":
			return maxi(0, int(stats.interval) - STRIKE_MIN_MS)
		"dodge_interval":
			return maxi(0, dodge_base - int(stats.get("dodge_cooldown", 0)) - DODGE_MIN_MS)
	return 2147483647


static func headroom(definition: Dictionary, stats: Dictionary, dodge_base: int, owned: int) -> int:
	return maxi(0, parameter_limit(definition, stats, dodge_base) - owned)


static func refusal(player: Dictionary, card_id: String, stats: Dictionary, dodge_base: int) -> String:
	var definition: Dictionary = Catalog.DEFINITIONS[card_id]
	var reason := requirement(definition, stats.affinity_build)
	if not reason.is_empty():
		return reason
	var copies: Array = player.get(STATE, {}).get("copies", [])
	if copies.filter(func(copy): return copy.id == card_id).size() >= int(definition.limit):
		return "Already acquired this Unique." if definition.policy == "unique" else "Maximum useful copies reached."
	if headroom(definition, stats, dodge_base, amount(player, card_id)) == 0:
		return "The current build has reached this effect's limit."
	return ""


static func eligible(player: Dictionary, stats: Dictionary, dodge_base: int) -> Array[String]:
	var result: Array[String] = []
	for id: String in Catalog.DEFINITIONS:
		if refusal(player, id, stats, dodge_base).is_empty():
			result.append(id)
	return result


static func rarity(random: RandomNumberGenerator, floor_number: int) -> int:
	var weights := Catalog.rise(floor_number)
	var roll := random.randf() * 100.0
	for index in weights.size():
		roll -= weights[index]
		if roll < 0.0:
			return index
	return weights.size() - 1


static func roll(game: Node, player: Dictionary, stats: Dictionary, prior: Dictionary = {}) -> Array:
	var available := eligible(player, stats, game.DODGE_COOLDOWN_MS)
	var size: int = Catalog.PLAYTEST.offer_size
	var floor_number: int = game.encounter_number
	var rerolls := 0 if prior.is_empty() else int(prior.rerolls) + 1
	var random := RandomNumberGenerator.new()
	random.seed = hash([player.upgrade_seed, floor_number, rerolls])
	var selected: Array[String] = []
	if not prior.is_empty():
		var old_ids: Array = prior.cards.map(func(card): return card.id)
		var replacements := available.filter(func(id): return not old_ids.has(id))
		if available.size() < size or replacements.is_empty():
			return []
		var replacement: String = replacements[random.randi_range(0, replacements.size() - 1)]
		selected.append(replacement)
		available.erase(replacement)
	while selected.size() < size and not available.is_empty():
		var index := random.randi_range(0, available.size() - 1)
		selected.append(available.pop_at(index))
	# Every card identity is selected before the first rarity roll.
	var options: Array = []
	for card_id in selected:
		var definition: Dictionary = Catalog.DEFINITIONS[card_id]
		var unique: bool = definition.policy == "unique"
		var grade := -1 if unique else rarity(random, floor_number)
		var offered: int = definition.fixed if unique else definition.values[grade]
		var contribution := mini(offered, headroom(definition, stats, game.DODGE_COOLDOWN_MS, amount(player, card_id)))
		options.append({"id": card_id, "rarity": "" if unique else Catalog.RARITIES[grade], "amount": contribution})
	return options


static func new_offer(game: Node, options: Array, rerolls: int) -> Dictionary:
	var serial := int(game.get_meta(SERIAL, 0)) + 1
	game.set_meta(SERIAL, serial)
	return {"floor": game.encounter_number, "revision": serial, "rerolls": rerolls, "cards": options, "closed": false}


static func open(game: Node, player: Dictionary, stats: Dictionary) -> Dictionary:
	var run := state(player)
	var offer: Dictionary = run.offer
	if int(offer.get("floor", 0)) != int(game.encounter_number):
		var options := [] if exhausted(run) else roll(game, player, stats)
		offer = new_offer(game, options, 0)
		run.offer = offer
	return offer


static func exhausted(run: Dictionary) -> bool:
	return run.copies.size() >= int(Catalog.PLAYTEST.acquisition_limit)


static func reroll_cost(offer: Dictionary) -> int:
	var costs: Array = Catalog.PLAYTEST.reroll_costs
	return int(costs[offer.rerolls]) if int(offer.rerolls) < costs.size() else 0


static func option_refusal(game: Node, player: Dictionary, option: Dictionary, stats: Dictionary) -> String:
	var id: String = option.id
	var reason := refusal(player, id, stats, game.DODGE_COOLDOWN_MS)
	if not reason.is_empty():
		return reason
	if int(option.amount) > headroom(Catalog.DEFINITIONS[id], stats, game.DODGE_COOLDOWN_MS, amount(player, id)):
		return "This copy no longer fits the current build's effect limit."
	return ""


static func view(game: Node, player: Dictionary, waiting: bool) -> Dictionary:
	var stats: Dictionary = game.weapon_stats(player)
	var offer := open(game, player, stats)
	var run := state(player)
	var result := {
		"affinity_offer": true, "revision": offer.revision, "choices": [], "closed": offer.closed,
		"exhausted": exhausted(run), "acquired": run.copies.size(), "limit": Catalog.PLAYTEST.acquisition_limit,
		"reroll_cost": 0, "reroll_enabled": false, "reroll_reason": "",
	}
	if bool(offer.closed) or bool(result.exhausted) or waiting:
		return result
	for index in offer.cards.size():
		var option: Dictionary = offer.cards[index]
		var definition: Dictionary = Catalog.DEFINITIONS[option.id]
		var reason := option_refusal(game, player, option, stats)
		var owned := amount(player, option.id)
		var description: String = definition.description % Catalog.amount_text(definition, int(option.amount))
		if definition.policy == "stackable":
			description += "\n\nAcquired: %s · With this copy: %s" % [
				Catalog.amount_text(definition, owned), Catalog.amount_text(definition, owned + int(option.amount))]
		if not reason.is_empty():
			description += "\n\n" + reason
		result.choices.append({"choice": index, "id": option.id, "title": definition.title,
			"rarity": option.rarity, "scope": str(definition.scope).capitalize(), "unique": definition.policy == "unique",
			"description": description, "enabled": reason.is_empty(), "cost": 0})
	var cost := reroll_cost(offer)
	result.reroll_cost = cost
	if cost > 0:
		var pool := eligible(player, stats, game.DODGE_COOLDOWN_MS)
		var prior: Array = offer.cards.map(func(card): return card.id)
		var replacement := pool.size() >= int(Catalog.PLAYTEST.offer_size) and pool.any(func(id): return not prior.has(id))
		result.reroll_enabled = replacement and game.run_wallet(player) >= cost
		if not replacement:
			result.reroll_reason = "No different full offer is available."
		elif not result.reroll_enabled:
			result.reroll_reason = "Not enough Essence to reroll."
	else:
		result.reroll_reason = "All rerolls used for this checkpoint."
	return result


static func command(game: Node, actor: int, player: Dictionary, action: String) -> void:
	if not game.multiplayer.is_server() or not game.Life.alive(player) or not game.checkpoint_pending \
			or not game.upgrade_checkpoint_open() or int(game.checkpoint_ready.get(actor, 0)) == int(game.encounter_number) \
			or player.pos.distance_to(game.battlefield.advance) > Gate.RANGE:
		return
	var fields := action.trim_prefix(COMMAND).split("_")
	if fields.size() != 2 or not fields[0].is_valid_int():
		return
	var run: Dictionary = player.get(STATE, {})
	var offer: Dictionary = run.get("offer", {})
	if offer.is_empty() or int(offer.floor) != int(game.encounter_number) or int(fields[0]) != int(offer.revision):
		game.present_checkpoint_cards(actor)
		return
	var choice := fields[1]
	if choice == "skip":
		close_choice(game, actor, player, offer)
		return
	if bool(offer.closed) or exhausted(run):
		return
	var stats: Dictionary = game.weapon_stats(player)
	if choice == "reroll":
		var cost := reroll_cost(offer)
		if cost <= 0 or game.run_wallet(player) < cost:
			game.present_checkpoint_cards(actor)
			return
		var options := roll(game, player, stats, offer)
		if options.is_empty():
			game.tell(actor, "No different eligible offer is available.")
			game.present_checkpoint_cards(actor)
			return
		var replacement := new_offer(game, options, int(offer.rerolls) + 1)
		player.spent += cost
		run.offer = replacement
		Journal.event("combat", "affinity_card_reroll", {"actor": actor, "floor": game.encounter_number,
			"revision": replacement.revision, "cost": cost, "rerolls": replacement.rerolls})
		game.present_checkpoint_cards(actor)
	elif choice.is_valid_int() and int(choice) >= 0 and int(choice) < offer.cards.size():
		var option: Dictionary = offer.cards[int(choice)]
		var reason := option_refusal(game, player, option, stats)
		if not reason.is_empty():
			game.tell(actor, reason)
			game.present_checkpoint_cards(actor)
			return
		var copy := option.duplicate()
		copy.acquisition_id = offer.revision
		copy.floor = offer.floor
		run.copies.append(copy)
		run.totals[copy.id] = amount(player, copy.id) + int(copy.amount)
		if copy.id == "run_health":
			player.max_hp = game.Life.maximum(game, player)
		Journal.event("combat", "affinity_card_acquired", {"actor": actor, "floor": copy.floor,
			"acquisition": copy.acquisition_id, "card": copy.id, "rarity": copy.rarity, "amount": copy.amount})
		game.tell(actor, "%s acquired for this expedition." % Catalog.DEFINITIONS[copy.id].title)
		close_choice(game, actor, player, offer)


static func close_choice(game: Node, actor: int, player: Dictionary, offer: Dictionary) -> void:
	offer.closed = true
	player.last_offer = game.encounter_number
	game.mark_checkpoint_ready(actor)


static func project_owned(player: Dictionary, stats: Dictionary, dodge_base: int) -> Array:
	var copies: Array = player.get(STATE, {}).get("copies", [])
	if copies.is_empty() or not player.get("wild", false):
		return []
	var result: Array = []
	for source: Dictionary in copies:
		var copy := source.duplicate()
		var definition: Dictionary = Catalog.DEFINITIONS[copy.id]
		copy.reason = requirement(definition, stats.affinity_build)
		copy.total = amount(player, copy.id)
		copy.applied = mini(int(copy.total), parameter_limit(definition, stats, dodge_base)) if copy.reason.is_empty() else 0
		if int(copy.applied) == 0 and copy.reason.is_empty():
			copy.reason = "The current build has reached this effect's limit."
		result.append(copy)
	return result


static func owned_rows(copies: Array) -> Array:
	var rows: Array = []
	for copy: Dictionary in copies:
		var definition: Dictionary = Catalog.DEFINITIONS[copy.id]
		var unique: bool = definition.policy == "unique"
		var grade: String = "Unique" if unique else copy.rarity
		var scope: String = str(definition.scope).capitalize()
		var label := "%s · %s · %s" % [definition.title, grade, scope]
		var description: String = definition.description % Catalog.amount_text(definition, int(copy.amount))
		if not unique:
			description += "\nAcquired total: " + Catalog.amount_text(definition, int(copy.total))
			if int(copy.applied) != int(copy.total):
				description += " · Applied: " + Catalog.amount_text(definition, int(copy.applied))
		if not str(copy.reason).is_empty():
			label += " · Inactive"
			description += "\nInactive: " + str(copy.reason)
		rows.append({"title": label, "tooltip": "%s\n%s" % [label, description], "rarity": grade})
	return rows


static func affinity_potency(player: Dictionary, source: String, material: Dictionary, potency: Dictionary) -> void:
	if source not in ["core", "form", "catalyst"]:
		return
	for id: String in totals(player):
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
		potency[parameter] = int(potency.get(parameter, 0)) + amount(player, id)


static func tune_class(player: Dictionary, skill: Dictionary, build: Dictionary, scale: int) -> void:
	if int(skill.slot) != 1:
		return
	for id: String in totals(player):
		var definition: Dictionary = Catalog.DEFINITIONS[id]
		if definition.scope != "class" or not requirement(definition, build).is_empty():
			continue
		var parameter: String = definition.parameter
		var contribution := amount(player, id)
		if parameter == "damage":
			skill.damage = float(skill.damage) + float(contribution) / scale
		else:
			skill[parameter] = int(skill.get(parameter, 0)) + contribution


static func ordinary_weapon(player: Dictionary, stats: Dictionary, scale: int) -> void:
	stats.damage = float(stats.damage) + float(amount(player, "ordinary_weapon_damage")) / scale
	stats.interval = maxi(STRIKE_MIN_MS, int(stats.interval) - amount(player, "ordinary_weapon_interval"))


static func bloom_echo_source(game: Node, player: Dictionary, skill: Dictionary, now: int) -> Dictionary:
	if int(skill.get("bloom_echo_hp", 0)) <= 0 or skill.get("bloom_echo_spent", false):
		return {}
	var owner: int = game.Traits.player_id(game, player)
	for field: Dictionary in game.trait_events:
		if field.get("native_weaver_bloom", false) and int(field.owner) == owner \
				and int(field.epoch) == int(game.combat_epoch) and int(field.until) > now \
				and int(field.get("bloom_life", -1)) == int(player.get("lost_health", 0)):
			return field
	return {}


static func bloom_contains(game: Node, bloom: Dictionary, target: int) -> bool:
	var point: Vector3 = game.enemy_position(target)
	return point.distance_to(bloom.position) <= float(bloom.radius) and game.battlefield.clear_line(bloom.position, point)


static func bloom_echo(game: Node, player: Dictionary, bloom: Dictionary, skill: Dictionary, now: int) -> void:
	if int(game.combat_epoch) != int(bloom.epoch) or not game.Life.alive(player):
		return
	skill.bloom_echo_spent = true
	var hp: int = skill.bloom_echo_hp
	var point: Vector3 = bloom.position
	var targets: Array[int] = game.skill_area_targets(point, float(bloom.radius), point)
	game.emit_combat_event("ability", "bloom_echo", point, point, .5, Color("#b5c775"), float(bloom.radius), bloom.owner,
		{"label": "Echoing Growth"})
	for target in targets:
		if game.get_meta(game.Transactions.PENDING, false):
			break
		game.apply_weapon_hit(player, target, point,
			{"damage": 0.0, "affinity_hp": hp, "trait_secondary": true, "core_hit": true, "knockback": -.35}, now)
	Journal.event("combat", "affinity_bloom_echo", {"actor": bloom.owner, "field": bloom.visual_id,
		"epoch": bloom.epoch, "hp": hp, "targets": targets})
