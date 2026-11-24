extends RefCounted
## One host-owned ledger per expedition participant. Install a successor only
## after accepting a transition. Guarded rollback can keep the prior reference.
const Catalog = preload("res://affinity_card_catalog.gd")
const Eligibility = preload("res://card_eligibility.gd")
const STRIKE_MIN_MS := 230
const DODGE_MIN_MS := 350


class Ledger extends RefCounted:
	var _copies: Array[Dictionary]
	var _offer: Dictionary
	var _completed_floor: int

	func _init(acquired_copies: Array[Dictionary] = [], checkpoint_offer: Dictionary = {}, completed_checkpoint: int = 0) -> void:
		_copies = acquired_copies.duplicate(true)
		_offer = checkpoint_offer.duplicate(true)
		_offer.erase("closed")
		_completed_floor = completed_checkpoint

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

	## Derived read-only facts; the copy receipts above remain the sole authority.
	func counts() -> Dictionary:
		var result := {}
		for copy in _copies:
			result[copy.id] = int(result.get(copy.id, 0)) + 1
		return result

	func has_offer_for(floor_number: int) -> bool:
		return not _offer.is_empty() and int(_offer.floor) == floor_number

	func open_offer(floor_number: int, revision: int, seed_value: int, stats: Dictionary, dodge_base: int) -> Ledger:
		if has_offer_for(floor_number):
			return self
		var options := [] if exhausted() else roll(seed_value, floor_number, stats, dodge_base)
		return Ledger.new(_copies, _make_offer(floor_number, revision, options, 0), _completed_floor)

	# A refused operation cannot change the current ledger or authorize a debit.
	func plan_choice(floor_number: int, revision: int, choice: String, next_revision: int,
			seed_value: int, essence: int, stats: Dictionary, dodge_base: int) -> Dictionary:
		if not has_offer_for(floor_number) or int(_offer.revision) != revision:
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
		var old_ids: Array = _offer.cards.map(func(card): return card.id)
		return available.filter(func(id): return not old_ids.has(id))

	func _refusal(card_id: String, stats: Dictionary, dodge_base: int, facts: Dictionary) -> String:
		var reason := Eligibility.catalog_requirement(card_id, facts)
		if not reason.is_empty():
			return reason
		var definition: Dictionary = Catalog.DEFINITIONS[card_id]
		if definition.parameter == "tempo_percent" and not _speed_headroom(stats):
			return "Basic attacks already have no attack-speed headroom."
		if int(facts.owned.card.get(card_id, 0)) >= int(definition.limit):
			return "Already acquired this Unique." if definition.policy == "unique" else "Maximum useful copies reached."
		if _effective_headroom(definition,stats,dodge_base,amount(card_id))==0:
			return "The current build has reached this effect's limit."
		return ""

	func eligible(stats: Dictionary, dodge_base: int) -> Array[String]:
		var result: Array[String] = []
		var facts := Eligibility.facts(stats.affinity_build, counts())
		for id: String in Catalog.DEFINITIONS:
			if _refusal(id, stats, dodge_base, facts).is_empty():
				result.append(id)
		return result

	func option_refusal(option: Dictionary, stats: Dictionary, dodge_base: int) -> String:
		var id: String = option.id
		var facts := Eligibility.facts(stats.affinity_build, counts())
		var reason := _refusal(id, stats, dodge_base, facts)
		if not reason.is_empty():
			return reason
		if int(option.amount)>_effective_headroom(Catalog.DEFINITIONS[id],stats,dodge_base,amount(id)):
			return "This copy no longer fits the current build's effect limit."
		return ""

	func _fixed_tempo_limit(stats: Dictionary) -> int:
		var interval:=maxi(STRIKE_MIN_MS,int(stats.interval)-amount("ordinary_weapon_interval"))
		# First integer percentage whose rounded interval reaches the existing floor.
		return maxi(0,floori(100.0*(interval/(STRIKE_MIN_MS+0.5)-1.0))+1)

	func _effective_headroom(definition: Dictionary,stats: Dictionary,dodge_base: int,owned: int) -> int:
		if definition.get("tuning",{}).get("fixed_tempo",false):return maxi(0,_fixed_tempo_limit(stats)-owned)
		return headroom(definition,stats,dodge_base,owned)

	func _speed_headroom(stats: Dictionary) -> bool:
		return int(stats.interval)-amount("ordinary_weapon_interval") > STRIKE_MIN_MS

	func project_owned(stats: Dictionary, dodge_base: int) -> Array:
		var result: Array = []
		if _copies.is_empty(): return result
		var facts := Eligibility.facts(stats.affinity_build, counts())
		for source in _copies:
			var copy := source.duplicate()
			var definition: Dictionary = Catalog.DEFINITIONS[copy.id]
			copy.reason = Eligibility.catalog_requirement(copy.id, facts)
			if definition.parameter == "tempo_percent" and not _speed_headroom(stats): copy.reason = "Basic attacks already have no attack-speed headroom."
			copy.total = amount(copy.id)
			copy.applied = mini(int(copy.total),_fixed_tempo_limit(stats) if definition.get("tuning",{}).get("fixed_tempo",false) else parameter_limit(definition, stats, dodge_base)) if copy.reason.is_empty() else 0
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
			var contribution:=mini(offered,_effective_headroom(definition,stats,dodge_base,amount(card_id)))
			options.append({"id": card_id, "rarity": "" if unique else Catalog.RARITIES[grade], "amount": contribution})
		return options


	static func requirement(definition: Dictionary, build: Dictionary, card_counts: Variant = null) -> String:
		return Eligibility.requirement(definition, build, card_counts)


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
		var random_draw := random.randf() * 100.0
		for index in weights.size():
			random_draw -= weights[index]
			if random_draw < 0.0:
				return index
		return weights.size() - 1
