extends RefCounted
## One host-owned ledger per expedition participant. Install a successor only
## after accepting a transition. Guarded rollback can keep the prior reference.
const Catalog = preload("res://affinity_card_catalog.gd")
const STRIKE_MIN_MS := 230
const DODGE_MIN_MS := 350


class Ledger extends RefCounted:
	var _copies: Array[Dictionary]
	var _offer: Dictionary
	var _completed_floor: int

	func _init(copies: Array[Dictionary] = [], offer: Dictionary = {}, completed_floor: int = 0) -> void:
		_copies = copies.duplicate(true)
		_offer = offer.duplicate(true)
		_offer.erase("closed")
		_completed_floor = completed_floor

	func offer() -> Dictionary:
		if _offer.is_empty():
			return {}
		var result := _offer.duplicate(true)
		result.closed = _is_closed()
		return result

	func copies() -> Array[Dictionary]:
		return _copies.duplicate(true)

	func copies_for(card_id: String) -> Array[Dictionary]:
		return _copies.filter(func(copy): return copy.id == card_id).duplicate(true)

	func completed_floor() -> int:
		return _completed_floor

	func count() -> int:
		return _copies.size()

	func exhausted() -> bool:
		return count() >= int(Catalog.PLAYTEST.acquisition_limit)

	func amount(card_id: String) -> int:
		var result := 0
		for copy in _copies:
			if copy.id == card_id:
				result += int(copy.amount)
		return result

	func totals() -> Dictionary:
		var result := {}
		for copy in _copies:
			result[copy.id] = int(result.get(copy.id, 0)) + int(copy.amount)
		return result

	func open_offer(floor_number: int, revision: int, seed_value: int, stats: Dictionary, dodge_base: int) -> Ledger:
		if int(_offer.get("floor", 0)) == floor_number:
			return self
		var options := [] if exhausted() else roll(seed_value, floor_number, stats, dodge_base)
		return Ledger.new(_copies, _make_offer(floor_number, revision, options, 0), _completed_floor)

	# A refused operation cannot change the current ledger or authorize a debit.
	func plan_choice(floor_number: int, revision: int, choice: String, next_revision: int,
			seed_value: int, essence: int, stats: Dictionary, dodge_base: int) -> Dictionary:
		if _offer.is_empty() or int(_offer.floor) != floor_number or int(_offer.revision) != revision:
			return {"refresh": true}
		# Readiness can be cleared on fall. Skip can acknowledge a closed offer.
		if choice == "skip":
			return {"ledger": Ledger.new(_copies, _offer, floor_number), "ready": true}
		if _is_closed() or exhausted():
			return {}
		if choice == "reroll":
			return _plan_reroll(floor_number, next_revision, seed_value, essence, stats, dodge_base)
		if not choice.is_valid_int() or int(choice) < 0 or int(choice) >= _offer.cards.size():
			return {}
		var option: Dictionary = _offer.cards[int(choice)]
		var reason := option_refusal(option, stats, dodge_base)
		if not reason.is_empty():
			return {"refresh": true, "message": reason}
		var copy := option.duplicate()
		copy.acquisition_id = _offer.revision
		copy.floor = floor_number
		var next_copies := _copies.duplicate()
		next_copies.append(copy)
		return {"ledger": Ledger.new(next_copies, _offer, floor_number), "copy": copy, "ready": true,
			"message": "%s acquired for this expedition." % Catalog.DEFINITIONS[copy.id].title}

	func _plan_reroll(floor_number: int, revision: int, seed_value: int, essence: int,
			stats: Dictionary, dodge_base: int) -> Dictionary:
		var cost := reroll_cost()
		if cost <= 0 or essence < cost:
			return {"refresh": true}
		var options := roll(seed_value, floor_number, stats, dodge_base, true)
		if options.is_empty():
			return {"refresh": true, "message": "No different eligible offer is available."}
		var rerolls := int(_offer.rerolls) + 1
		var next := Ledger.new(_copies, _make_offer(floor_number, revision, options, rerolls), _completed_floor)
		return {"ledger": next, "cost": cost, "rerolls": rerolls, "refresh": true}

	static func _make_offer(floor_number: int, revision: int, options: Array, rerolls: int) -> Dictionary:
		return {"floor": floor_number, "revision": revision, "rerolls": rerolls, "cards": options}

	func _is_closed() -> bool:
		return not _offer.is_empty() and int(_offer.floor) == _completed_floor

	func reroll_cost() -> int:
		var costs: Array = Catalog.PLAYTEST.reroll_costs
		var rerolls := int(_offer.rerolls)
		return int(costs[rerolls]) if rerolls < costs.size() else 0

	func can_replace_offer(stats: Dictionary, dodge_base: int) -> bool:
		return not _replacement_ids(eligible(stats, dodge_base)).is_empty()

	func _replacement_ids(available: Array[String]) -> Array[String]:
		if available.size() < int(Catalog.PLAYTEST.offer_size):
			return []
		var old_ids: Array = _offer.cards.map(func(card): return card.id)
		return available.filter(func(id): return not old_ids.has(id))

	func _refusal(card_id: String, stats: Dictionary, dodge_base: int) -> String:
		var definition: Dictionary = Catalog.DEFINITIONS[card_id]
		var reason := requirement(definition, stats.affinity_build)
		if not reason.is_empty():
			return reason
		if _copies.filter(func(copy): return copy.id == card_id).size() >= int(definition.limit):
			return "Already acquired this Unique." if definition.policy == "unique" else "Maximum useful copies reached."
		if headroom(definition, stats, dodge_base, amount(card_id)) == 0:
			return "The current build has reached this effect's limit."
		return ""

	func eligible(stats: Dictionary, dodge_base: int) -> Array[String]:
		var result: Array[String] = []
		for id: String in Catalog.DEFINITIONS:
			if _refusal(id, stats, dodge_base).is_empty():
				result.append(id)
		return result

	func option_refusal(option: Dictionary, stats: Dictionary, dodge_base: int) -> String:
		var id: String = option.id
		var reason := _refusal(id, stats, dodge_base)
		if not reason.is_empty():
			return reason
		if int(option.amount) > headroom(Catalog.DEFINITIONS[id], stats, dodge_base, amount(id)):
			return "This copy no longer fits the current build's effect limit."
		return ""

	func project_owned(stats: Dictionary, dodge_base: int) -> Array:
		var result: Array = []
		for source in _copies:
			var copy := source.duplicate()
			var definition: Dictionary = Catalog.DEFINITIONS[copy.id]
			copy.reason = requirement(definition, stats.affinity_build)
			copy.total = amount(copy.id)
			copy.applied = mini(int(copy.total), parameter_limit(definition, stats, dodge_base)) if copy.reason.is_empty() else 0
			if int(copy.applied) == 0 and copy.reason.is_empty():
				copy.reason = "The current build has reached this effect's limit."
			result.append(copy)
		return result

	func roll(seed_value: int, floor_number: int, stats: Dictionary, dodge_base: int, reroll := false) -> Array:
		var available := eligible(stats, dodge_base)
		var size: int = Catalog.PLAYTEST.offer_size
		var rerolls := int(_offer.rerolls) + 1 if reroll else 0
		var random := RandomNumberGenerator.new()
		random.seed = hash([seed_value, floor_number, rerolls])
		var selected: Array[String] = []
		if reroll:
			var replacements := _replacement_ids(available)
			if replacements.is_empty():
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
			var grade := -1 if unique else _rarity(random, floor_number)
			var offered: int = definition.fixed if unique else definition.values[grade]
			var contribution := mini(offered, headroom(definition, stats, dodge_base, amount(card_id)))
			options.append({"id": card_id, "rarity": "" if unique else Catalog.RARITIES[grade], "amount": contribution})
		return options


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
			return "Requires a functioning basic attack."
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


	static func _rarity(random: RandomNumberGenerator, floor_number: int) -> int:
		var weights := Catalog.rise(floor_number)
		var roll := random.randf() * 100.0
		for index in weights.size():
			roll -= weights[index]
			if roll < 0.0:
				return index
		return weights.size() - 1
