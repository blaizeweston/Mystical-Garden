extends RefCounted
## Shared, deterministic combat values. Definitions remain in their content files.
## Snapshots contain no actor, timers, RNG, health balance, or activation identity.
## The bounded cache accepts explicit build facts, never Game or a player record.
const Build = preload("res://affinity_build.gd")
const Skills = preload("res://skill_catalog.gd")
const Weapons = preload("res://weapon_system.gd")
const Cards = preload("res://affinity_cards.gd")
const CardState = preload("res://affinity_card_ledger.gd")
const Grafts = preload("res://expedition_grafts.gd")
const Preview = preload("res://combat_balance_preview.gd")
# Four players may each inspect active and prepared equipment. Eviction only
# discards reproducible values; it never discards gameplay state or effects.
const MAX_CACHED_BUILDS := 8

class Snapshot extends RefCounted:
	var _build: Dictionary
	var _native: Dictionary
	var _weapon_base: Dictionary
	var _basic: Dictionary
	var _cards: Dictionary
	var _core: Dictionary
	var _skills: Array[Dictionary] = []
	var _tooltips: Array = []

	func _init(native_stats: Dictionary, contributions: Dictionary) -> void:
		var values := native_stats.duplicate(true)
		_build = _freeze(values.get("affinity_build", {}))
		values.erase("affinity_build")
		_native = _freeze(values)
		_cards = _freeze(contributions.duplicate(true)) if not _build.is_empty() else {}
		_core = _freeze(Build.core_skill(_build))
		_weapon_base = _basic_values({})
		_basic = _basic_values(_cards)
		for adapter: Dictionary in _build.get("class_skills", []):
			var skill: Dictionary = adapter.get("native_skill", {}).duplicate(true)
			if not skill.is_empty():
				Cards.tune_class_contributions(skill, _build, _cards, Preview.scale())
			_skills.append(_freeze(skill))
		_skills.make_read_only()

	static func from_build(build: Dictionary, contributions: Dictionary) -> Snapshot:
		var native := Build.native_stats(build)
		native.affinity_build = build
		native.class_power = 0
		_damage_band(native)
		return Snapshot.new(native, contributions)

	func affinity_build() -> Dictionary:
		return _build.duplicate(true)

	## Native class/defense context deliberately excludes basic-only damage/reach.
	## The returned native shape is also the existing reliable network projection.
	func native_stats() -> Dictionary:
		return _stats_view(_native)

	## Card eligibility/headroom is evaluated before existing card contributions.
	func weapon_base_stats() -> Dictionary:
		return _stats_view(_weapon_base)

	func basic_stats() -> Dictionary:
		return _stats_view(_basic)

	func class_skill(slot: int) -> Dictionary:
		return _skills[slot].duplicate(true) if slot >= 0 and slot < _skills.size() else {}

	func class_skills() -> Array:
		return _skills.duplicate(true)

	func tooltips() -> Array:
		# Formatting is lazy: a prospective graft quote needs numbers, not text.
		if _tooltips.is_empty() and not _skills.is_empty():
			_tooltips = Skills.resolved_tooltips(_skills, _native, {})
		return _tooltips.duplicate()

	func core_skill() -> Dictionary:
		return _core.duplicate(true)

	func refusal(slot: String) -> String:
		return Build.refusal(_build, slot)

	func dodge_ms(base_ms: int) -> int:
		return maxi(Cards.DODGE_MIN_MS, base_ms - int(_native.get("dodge_cooldown", 0)) - int(_cards.get("run_dodge_recovery", 0)))

	func graft_value_resolver(base_health: int, lost_health: int, temporary_health: int) -> Callable:
		return _graft_values.bind(base_health, lost_health, temporary_health)

	func _graft_values(improvements: Dictionary, base_health: int, lost_health: int, temporary_health: int) -> Dictionary:
		var build := _build.duplicate(true)
		build.improvements = improvements
		var candidate := Snapshot.from_build(build, _cards)
		var skills := []
		for skill: Dictionary in candidate._skills:
			if not skill.is_empty(): skills.append({"name":skill.name, "time":Skills.Balance.cooldown(skill, candidate._native)})
		var health := Preview.maximum_health(base_health, float(candidate._native.get("max_health", 0)), lost_health, int(_cards.get("run_health", 0))) + temporary_health
		return {"damage":Preview.weapon_range(candidate._basic, 0), "health":health,
			"reach":roundi(float(candidate._basic.reach) * 100.0), "cooldown":skills}

	func _basic_values(contributions: Dictionary) -> Dictionary:
		var values := _native.duplicate(true)
		if not _build.is_empty():
			values.affinity_build = _build
			Weapons.tune_affinity_basic(values, contributions)
			_damage_band(values)
			values.erase("affinity_build")
		return _freeze(values)

	func _stats_view(values: Dictionary) -> Dictionary:
		var result := values.duplicate(true)
		if not _build.is_empty(): result.affinity_build = _build.duplicate(true)
		return result

	static func _damage_band(values: Dictionary) -> void:
		var band := Preview.weapon_range(values, 0)
		values.damage_min = band.x
		values.damage_max = band.y

	static func _freeze(value: Variant) -> Variant:
		if value is Dictionary:
			for key in value: _freeze(value[key])
			value.make_read_only()
		elif value is Array:
			for child in value: _freeze(child)
			value.make_read_only()
		return value

class Entry extends RefCounted:
	var _key: Dictionary
	var _snapshot: Snapshot

	func _init(key: Dictionary, snapshot: Snapshot) -> void:
		_key = key.duplicate(true)
		_snapshot = snapshot

	func matches(key: Dictionary) -> bool:
		return _key == key

	func snapshot() -> Snapshot:
		return _snapshot

class Cache extends RefCounted:
	var _entries: Array[Entry] = []
	var _compilations := 0

	func resolve(class_id: int, weapon_index: int, parts: Array, class_profile: Dictionary,
			cards: CardState.Ledger, grafts: Grafts.Ledger, active: bool) -> Snapshot:
		var key := {"class":class_id, "weapon":weapon_index, "parts":parts,
			"profile":class_profile, "cards":cards, "grafts":grafts, "active":active}
		for entry in _entries:
			if entry.matches(key): return entry.snapshot()
		var build := Build.resolve(class_id, weapon_index, parts, key.profile)
		if active: build.improvements = grafts.resolution() if grafts != null else {"bonuses":{}, "adaptations":[]}
		return _remember(key, Snapshot.from_build(build, cards.totals() if cards != null else {}))

	func received(native_stats: Dictionary, contributions: Dictionary) -> Snapshot:
		var key := {"received":native_stats, "cards":contributions}
		for entry in _entries:
			if entry.matches(key): return entry.snapshot()
		return _remember(key, Snapshot.new(native_stats, contributions))

	func _remember(key: Dictionary, snapshot: Snapshot) -> Snapshot:
		if _entries.size() == MAX_CACHED_BUILDS: _entries.pop_front()
		_entries.append(Entry.new(key, snapshot))
		_compilations += 1
		return snapshot

	func entry_count() -> int:
		return _entries.size()

	func compilation_count() -> int:
		return _compilations
