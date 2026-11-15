extends RefCounted

const Ruleset = preload("res://combat_ruleset.gd")
const Affinities = preload("res://plant_affinities.gd")
const Catalyst = preload("res://catalyst_adapters.gd")
const Classes = preload("res://class_catalog.gd")
const Skills = preload("res://skill_catalog.gd")
const Parts = preload("res://weapon_parts.gd")
const WeaponRules = preload("res://weapon_system.gd")
const Delivery = preload("res://core_skill_rules.gd")
const Preview = preload("res://combat_balance_preview.gd")

static func slot(name: String, part: int) -> Dictionary:
	var identity := Affinities.for_part(part)
	if identity.is_empty():
		return {"state": "empty" if part == 0 else "invalid", "executable": part == 0 and name != "core"}
	identity.executable = identity.primary_affinity == "frost"
	identity.state = "ready" if identity.executable else "pending"
	identity.potency_profile = {
		"id": "%s/%s/%s" % [name, identity.primary_affinity, identity.quality],
		"values": Ruleset.Frost.QUALITY[identity.quality].duplicate() if identity.executable else {},
	}
	identity.card_requirements = {
		"slot": name, "primary_affinity": identity.primary_affinity,
		"supporting_affinities": identity.supporting_affinities.duplicate(),
	}
	return identity


static func resolve(class_id: int, weapon_index: int, slots: Array, graft: int, profile: Dictionary) -> Dictionary:
	class_id = clampi(class_id, 0, Classes.DEFINITIONS.size() - 1)
	var frame: Dictionary = Classes.DEFINITIONS[class_id]
	var weapon: Dictionary = frame.weapons[clampi(weapon_index, 0, frame.weapons.size() - 1)]
	var result := {
		"ruleset": Ruleset.ID, "class_id": frame.id, "focus_id": Classes.focus_id(profile, class_id),
		"weapon_id": weapon.id, "native_weapon": weapon.duplicate(true),
		"native_class_effects": Classes.bonuses(profile, class_id),
		"core": slot("core", int(slots[0])), "form": slot("form", int(slots[1])),
		"catalyst": slot("catalyst", int(slots[2])), "graft": {}, "class_skills": [],
		"capabilities": {"native_weapon": true, "native_class_skills": true, "affinity_effects": false},
	}
	# The weapon supplies presentation/placement. Old species-specific melee
	# movement overrides are deliberately excluded.
	result.core.delivery = Delivery.WEAPON_DELIVERY.get(weapon.visual, {}).duplicate()
	result.form.behavior = Ruleset.FORMS.get(result.form.get("primary_affinity"), "")
	for index in 2:
		var skill := Skills.resolve(class_id, index, profile)
		var adapter := Catalyst.resolve(class_id, index, profile, skill)
		if not adapter.is_empty():
			adapter.response = adapter.responses.get(result.catalyst.get("primary_affinity"), "")
		result.class_skills.append(adapter)
	result.capabilities.affinity_effects = [result.core, result.form, result.catalyst].any(func(part): return part.state == "ready")
	result.capabilities.strike = result.form.executable
	result.capabilities.core_action = result.core.executable
	result.capabilities.class_actions = result.catalyst.executable and result.class_skills.all(func(adapter): return not adapter.is_empty())
	if Parts.is_monster(graft):
		var entry: Dictionary = Parts.DEFINITIONS[graft]
		var native := {}
		var pending := {}
		var effects: Dictionary = Parts.MONSTER_DEFINITIONS[int(entry.monster)].effects
		for key in effects:
			if key in Ruleset.NATIVE_GRAFT_STATS:
				native[key] = effects[key]
			else:
				pending[key] = effects[key]
		result.graft = {"item_id": entry.item_id, "component_id": entry.id, "native_effects": native, "pending_effects": pending}
	return result


static func for_player(player: Dictionary, prepared := false) -> Dictionary:
	var fields := ["prepared", "prepared_secondary", "prepared_catalyst"] if prepared else ["weapon", "secondary", "catalyst"]
	var parts := fields.map(func(field): return int(player.get(field, 0)))
	return resolve(int(player.get("frame", 0)), int(player.get("weapon_kind", 0)), parts,
		0 if prepared else int(player.get("graft_part", 0)), player.get("character", {}))


static func native_stats(build: Dictionary) -> Dictionary:
	var stats: Dictionary = build.native_weapon.duplicate(true)
	stats.merge({"cooldown": 0.0, "tags": [], "interactions": [], "core_build": {}})
	WeaponRules.add_effects(stats, build.native_class_effects)
	WeaponRules.add_effects(stats, build.graft.get("native_effects", {}))
	# Legacy passive Frost is retained in the resolved native metadata for CR05.
	stats.erase("brittle")
	stats.erase("shatter_damage")
	stats.erase("link_brittle")
	for key in ["cooldown", "recovery", "stagger", "skill_cooldown", "skill_duration", "dodge_cooldown", "windup_damage"]:
		if stats.has(key) and (key != "windup_damage" or not Preview.enabled):
			stats[key] = roundi(float(stats[key]))
	stats.targets = clampi(int(stats.targets), 1, 5)
	if stats.targets > 1 and stats.pattern == "single":
		stats.pattern = "sweep" if build.class_id in ["warden", "reaper"] else "chain"
	stats.damage = maxf(1.0, float(stats.damage)) if Preview.enabled else maxi(1, roundi(float(stats.damage)))
	stats.heal_on_kill = Preview.capped_amount(float(stats.get("heal_on_kill", 0)), 2)
	stats.skill_heal = Preview.capped_amount(float(stats.get("skill_heal", 0)), 3)
	stats.max_health = Preview.capped_amount(float(stats.get("max_health", 0)), 4)
	stats.interval = maxi(230, int(stats.strike_ms) - int(stats.cooldown))
	return stats


static func refusal(build: Dictionary, name: String) -> String:
	var part: Dictionary = build[name]
	if part.executable:
		return ""
	if part.state == "empty":
		return "Equip Chiming Sepal or Crystalline Bellheart in Core to use Rime Bloom."
	if part.state == "invalid":
		return "%s material is invalid." % name.capitalize()
	return "%s %s is pending implementation." % [str(part.primary_affinity).capitalize(), name.capitalize()]


static func departure_refusal(player: Dictionary) -> String:
	var build := for_player(player, true)
	for name in ["core", "form", "catalyst"]:
		if build[name].state != "empty":
			var reason := refusal(build, name)
			if not reason.is_empty():
				return reason + " Equip Frostbell or leave the slot empty."
	return ""


static func describe(build: Dictionary) -> String:
	var lines: Array[String] = ["Affinity development mode · " + str(build.native_weapon.name)]
	for name in ["core", "form", "catalyst"]:
		var part: Dictionary = build[name]
		var summary := "Empty" if name == "core" else "Native only"
		if part.state == "ready":
			summary = Ruleset.Frost.description(name, part.quality) + "\nWater support is reserved for future cards."
		elif part.state != "empty":
			summary = refusal(build, name)
			if part.state == "pending":
				summary += " Support: " + ", ".join(part.supporting_affinities) + " · " + part.quality.capitalize()
		lines.append("%s · %s" % [name.capitalize(), summary])
	if not build.graft.get("pending_effects", {}).is_empty():
		lines.append("Graft · Native weapon modifiers available. Special graft effects are pending.")
	return "\n".join(lines)


static func frost_core(build: Dictionary) -> Dictionary:
	var core: Dictionary = build.get("core", {})
	if core.get("state") != "ready":
		return {}
	var balance = Ruleset.Frost
	var delivery: Dictionary = core.delivery
	return {"id": core.affinity_core_skill_id, "name": "Rime Bloom",
		"icon": "res://assets/ui/core_skills/rime_bloom.png", "mechanic": "ground_sequence",
		"frost_family": true, "material": core, "color": "#97dfff",
		"weapon_form": build.native_weapon.visual, "delivery": delivery.kind,
		"projectile": Delivery.DELIVERY_SHAPES[delivery.kind], "range": delivery.range,
		"radius": balance.BLOOM_RADIUS, "lifetime_ms": 2500, "cooldown_ms": balance.BLOOM_COOLDOWN_MS,
		"tooltip": balance.description("core", core.quality), "modifiers": []}
