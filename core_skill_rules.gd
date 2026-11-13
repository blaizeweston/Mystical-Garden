extends RefCounted

const Parts = preload("res://weapon_parts.gd")
const Classes = preload("res://class_catalog.gd")
# Delivery belongs to the weapon. The Core chooses the effect at its destination.
# Seed Lance travels farther than effects placed on the ground.
const WEAPON_DELIVERY := {
	"blade":    {"kind": "ground", "range": 2.6, "lance_range": 5.6},
	"spear":    {"kind": "ground", "range": 3.3, "lance_range": 6.2},
	"hammer":   {"kind": "ground", "range": 2.2, "lance_range": 4.8},
	"staff":    {"kind": "seed",   "range": 5.2, "lance_range": 6.6},
	"wand":     {"kind": "seed",   "range": 4.4, "lance_range": 5.5},
	"orb":      {"kind": "seed",   "range": 5.7, "lance_range": 7.0},
	"bow":      {"kind": "arrow",  "range": 5.8, "lance_range": 7.6},
	"crossbow": {"kind": "bolt",   "range": 5.4, "lance_range": 7.0},
	"ring":     {"kind": "seed",   "range": 4.2, "lance_range": 5.8},
	"knives":   {"kind": "ground", "range": 2.1, "lance_range": 4.5},
	"scythe":   {"kind": "ground", "range": 2.9, "lance_range": 5.6},
	"whip":     {"kind": "ground", "range": 3.6, "lance_range": 6.0},
	"bell":     {"kind": "ground", "range": 2.6, "lance_range": 5.2},
	"censer":   {"kind": "ground", "range": 2.9, "lance_range": 5.5},
	"fan":      {"kind": "seed",   "range": 4.4, "lance_range": 5.8},
}
const DELIVERY_SHAPES := {"ground": "", "arrow": "arrow", "bolt": "bolt", "seed": "orb"}
const Catalog = preload("res://core_skill_catalog.gd")
const Variants = preload("res://core_weapon_variants.gd")
const Balance = preload("res://core_skill_balance.gd")
static var RULES: Array = Catalog.SKILLS
static var MODIFIERS: Array = Catalog.INTERACTIONS
const Seeds = preload("res://seed_catalog.gd")
const TUNING_LIMITS := {
	"line_trap": {"radius": [.08,.7], "half_length": [.6,4.0], "root_ms": [100,4500], "quake_reach": [.1,2.0], "trip_pull": [.1,2.0]},
	"swept_projectile": {"radius": [.06,.34], "root_ms": [0,4000], "mark_ms": [100,9000], "mark_damage": [.1,6],
		"chain_range": [1,4], "chain_targets": [1,3], "chain_root_ms": [100,1500], "mark_root_ms": [100,1800]},
	"ground_sequence": {"radius": [.5,3.6], "ward_ms": [100,3500], "ward_on_hit_ms": [100,3500],
		"field_ms": [100,6000], "inner_root_ms": [100,2000], "bite_bonus": [.1,3], "rearm_ms": [100,2000],
		"contact_ward_ms": [100,3000], "block_stagger_ms": [100,1500], "root_bonus_ms": [100,900], "heal_bonus": [.1,1], "displacement_bonus": [.1,.7], "siphon_cap": [1,3],
		"burst_radius": [.5,2.5], "death_heal": [.1,2], "mark_ms": [100,6500], "link_root_ms": [100,1600],
		"opening_stagger_ms": [100,900], "root_on_damage_ms": [100,1600], "root_on_interrupt_ms": [100,1600]},
	"ground_burst": {"radius": [.2,3.0], "stagger_ms": [100,1800], "area_guard_ms": [100,3500]},
	"anchor_beam": {"radius": [.06,.34], "root_ms": [100,4000], "lifetime_ms": [100,9000], "beam_range": [1.0,9.0], "beam_damage": [.1,3]},
}

static var WEAPON_FORMS := weapon_forms(Classes.DEFINITIONS)


static func weapon_forms(classes: Array) -> Dictionary:
	var result := {}
	for definition in classes:
		for weapon in definition.weapons:
			result[weapon.id] = weapon.visual
	return result


static func tags(part: int) -> Array:
	if not Parts.is_plant(part) and not Parts.is_monster(part):
		return []
	var result: Array = Parts.DEFINITIONS[part].tags.duplicate()
	var signature: String = signature_for(part).get("tag", "")
	if not signature.is_empty() and not result.has(signature):
		result.append(signature)
	return result


static func signature_for(part: int) -> Dictionary:
	if not Parts.is_plant(part):
		return {}
	var species := Parts.plant_source(part)
	if species < 0 or species >= Seeds.DEFINITIONS.size():
		return {}
	return Catalog.SIGNATURES.get(Seeds.DEFINITIONS[species].id, {})


static func skill_by_id(skill_id: String) -> Dictionary:
	for rule in RULES:
		if rule.id == skill_id:
			return rule
	return {}


static func describe(skill: Dictionary, cards: Array = []) -> String:
	if skill.is_empty():
		return ""
	var heading: String = skill.name
	if skill.has("variant_name"):
		heading += " · " + str(skill.variant_name)
	var lines: Array[String] = [heading, "%s %s %.1fs cooldown." % [
		skill.description, skill.trigger_description, float(skill.cooldown_ms) / 1000.0,
	]]
	if skill.has("chain_targets"):
		lines.append("Jumps · %d · %.1f m per jump." % [int(skill.chain_targets), float(skill.chain_range)])
	elif skill.has("burst_radius"):
		lines.append("Watch radius · %.1f m. Corpse burst · %.1f m." % [float(skill.radius), float(skill.burst_radius)])
	elif skill.has("mark_ms") and not Balance.Preview.enabled:
		lines.append("%s · %d damage · %.1fs window." % ["Link" if skill.mechanic == "ground_sequence" else "Mark burst", int(skill.mark_damage), float(skill.mark_ms) / 1000.0])
	elif skill.mechanic == "anchor_beam":
		lines.append("Beam reach · %.1f m." % float(skill.beam_range))
	if skill.mechanic == "ground_sequence" and not skill.has("burst_radius"):
		if skill.get("targeting") != "self":
			lines.append("Cast reach · %.1f m." % float(skill.range))
		if skill.get("footprint") == "wave":
			lines.append("Wave width · %.1f m." % float(skill.radius))
		if skill.has("field_ms") or skill.has("trap_ms"):
			var duration := int(skill.get("field_ms", skill.get("trap_ms", 0)))
			lines.append("Duration · %s." % (Balance.seconds(duration) if Balance.Preview.enabled else "%.1fs" % (duration / 1000.0)))
		if skill.has("retreat_distance"):
			lines.append("Backstep · up to %.1f m." % float(skill.retreat_distance))
	if Balance.Preview.enabled:
		lines.append_array(Balance.effect_lines(skill))
	for modifier in skill.modifiers:
		lines.append(str(modifier.text))
	for card in cards:
		lines.append(str(card))
	return "\n".join(lines)


static func resolve(weapon_id: String, slots: Array, graft: int) -> Dictionary:
	var core := int(slots[0]) if not slots.is_empty() else 0
	var core_tags := tags(core) if Parts.is_plant(core) else []
	var signature := signature_for(core)
	var primary: String = signature.get("tag", "")
	var rule := skill_by_id(signature.get("skill", ""))
	core_tags.erase(primary)
	var build := {
		"primary": primary,
		"secondary": core_tags,
		"form": tags(int(slots[1])) if slots.size() > 1 and Parts.is_plant(int(slots[1])) else [],
		"catalyst": tags(int(slots[2])) if slots.size() > 2 and Parts.is_plant(int(slots[2])) else [],
		"graft": tags(graft) if Parts.is_monster(graft) else [],
		"skill": {},
	}
	var form: String = WEAPON_FORMS.get(weapon_id, "")
	var delivery: Dictionary = WEAPON_DELIVERY.get(form, {})
	if rule.is_empty() or delivery.is_empty():
		return build
	var profile := rule.duplicate()
	profile.erase("delivery_text")
	profile.erase("range_key")
	profile.weapon_form = form
	profile.delivery = delivery.kind
	profile.projectile = DELIVERY_SHAPES[delivery.kind]
	profile.range = delivery[rule.range_key]
	profile.description = "" if rule.get("footprint") == "wave" else rule.delivery_text[delivery.kind]
	Variants.apply(profile)
	profile.modifiers = []
	for slot in ["secondary", "form", "catalyst", "graft"]:
		for modifier in MODIFIERS:
			if modifier.skill != profile.id or modifier.slot != slot or (modifier.has("forms") and form not in modifier.forms):
				continue
			if modifier.tag in build[slot]:
				profile.merge(modifier.values, true)
				profile.modifiers.append({"id": modifier.id, "text": modifier.text})
				break
	build.skill = profile
	return build


static func player_build(player: Dictionary) -> Dictionary:
	var c := clampi(int(player.get("frame", 0)), 0, Classes.DEFINITIONS.size() - 1)
	var weapons: Array = Classes.DEFINITIONS[c].weapons
	var weapon: Dictionary = weapons[clampi(int(player.get("weapon_kind", 0)), 0, weapons.size() - 1)]
	return resolve(weapon.id, [player.get("weapon", 0), player.get("secondary", 0), player.get("catalyst", 0)], int(player.get("graft_part", 0)))


static func valid_slot_tag(tag: String, slot: String) -> bool:
	if slot == "primary":
		return Catalog.SIGNATURES.values().any(func(entry): return entry.tag == tag)
	for part in range(1, Parts.DEFINITIONS.size()):
		if Parts.is_monster(part) == (slot == "graft") and tags(part).has(tag):
			return true
	return false


static func valid_tuning(rule: Dictionary, values: Dictionary) -> bool:
	var limits: Dictionary = TUNING_LIMITS.get(rule.get("mechanic", ""), {})
	for key in values:
		var value = values[key]
		if key == "color" and value is String and Color.html_is_valid(value):
			continue
		if key in ["extra_phase", "graft_phase"] and rule.get("mechanic") == "ground_sequence" and not rule.has("death_window_ms") and valid_phase(value) and int(value.delay) > 0 and not value.get("pair", false):
			continue
		if not limits.has(key) or not (value is int or value is float) or not is_finite(float(value)):
			return false
		if float(value) < float(limits[key][0]) or float(value) > float(limits[key][1]):
			return false
		if (key.ends_with("_ms") or key in ["chain_targets","siphon_cap"]) and not is_equal_approx(float(value), roundf(float(value))):
			return false
		if key in ["lifetime_ms", "mark_ms"] and int(value) >= int(rule.cooldown_ms):
			return false
	return not values.is_empty()


static func valid_phase(phase) -> bool:
	if not phase is Dictionary or not phase.get("delay") is int or int(phase.delay) < 0 or int(phase.delay) > 6000:
		return false
	if not phase.keys().all(func(key): return key in ["delay", "enemy", "ally", "siphon", "pair", "reflected"]):
		return false
	var enemy := {"damage": [.1,6], "root_ms": [100,2600], "stagger_ms": [100,1500], "interrupt_ms": [100,1600], "displace": [-2,2], "brittle": [1,2], "only_winding": [true], "windup_damage": [.1,4]}
	var ally := {"heal": [.1,2], "guard_ms": [100,3500], "cleanse": [true]}
	for section in [["enemy", enemy], ["ally", ally]]:
		if not phase.has(section[0]):
			continue
		var effects = phase[section[0]]
		var bounds: Dictionary = section[1]
		if not effects is Dictionary or effects.is_empty():
			return false
		for key in effects:
			var value = effects[key]
			if not bounds.has(key):
				return false
			var limit: Array = bounds[key]
			if limit.size() == 1:
				if value != true: return false
			elif not (value is int or value is float) or not is_finite(float(value)) or value < limit[0] or value > limit[1]:
				return false
	if phase.has("reflected") and phase.reflected != true:
		return false
	if phase.has("siphon") and (not phase.get("enemy", {}).has("damage") or phase.siphon not in [1,2,3]):
		return false
	return phase.has("enemy") or phase.has("ally") or phase.get("pair", false)


static func errors(classes: Array) -> Array[String]:
	var result: Array[String] = []
	var ids := {}
	var icons := {}
	var weapons := weapon_forms(classes)
	var motion := preload("res://weapon_motion.gd")
	for weapon_id in weapons:
		var form: String = weapons[weapon_id]
		var delivery: Dictionary = WEAPON_DELIVERY.get(form, {})
		if delivery.is_empty() or not DELIVERY_SHAPES.has(delivery.kind) or not motion.PROFILES.has(form):
			result.append("Missing Core delivery for " + str(weapon_id))
			continue
		if (delivery.kind != "ground") != motion.is_projectile(form) or RULES.any(func(rule): return float(delivery.get(rule.range_key, 0)) <= .85):
			result.append("Invalid Core delivery for " + str(weapon_id))
	for rule in RULES:
		if str(rule.id).is_empty() or ids.has(rule.id):
			result.append("Empty or duplicate Core skill ID " + str(rule.id))
		ids[rule.id] = true
		if icons.has(rule.icon) or not ResourceLoader.exists(rule.icon, "Texture2D"):
			result.append("Missing or shared Core icon for " + str(rule.id))
		icons[rule.icon] = true
		if DELIVERY_SHAPES.keys().any(func(kind): return str(rule.delivery_text.get(kind, "")).is_empty()):
			result.append("Core skill requires delivery text " + str(rule.id))
		if rule.cooldown_ms <= 0 or rule.radius <= 0:
			result.append("Invalid Core skill timing or width for " + str(rule.id))
		match rule.mechanic:
			"line_trap":
				if rule.lifetime_ms <= 0 or rule.cooldown_ms <= rule.lifetime_ms or rule.root_ms <= 0 or rule.half_length <= 0:
					result.append("Invalid trap timing or footprint " + str(rule.id))
			"swept_projectile":
				var contact: String = rule.get("contact", "damage")
				if rule.speed <= 0 or int(rule.targets) not in [1, 2, 3] or rule.radius > .34:
					result.append("Invalid projectile travel or hit limit " + str(rule.id))
				if contact == "strike_mark":
					if rule.targets != 1 or rule.mark_ms <= 0 or rule.mark_ms >= rule.cooldown_ms or rule.mark_damage <= 0:
						result.append("Invalid strike mark " + str(rule.id))
				elif contact == "chain":
					if int(rule.targets) != 1 or int(rule.get("chain_targets", 0)) not in [1,2,3] or not valid_tuning(rule, {"chain_range": rule.get("chain_range", 0)}) or int(rule.get("damage", 0)) <= 0:
						result.append("Invalid chain projectile " + str(rule.id))
				elif contact != "damage" or int(rule.get("damage", 0)) <= 0:
					result.append("Invalid projectile contact " + str(rule.id))
			"ground_burst":
				if rule.stagger_ms <= 0 or int(rule.targets) not in [1, 2, 3] or rule.radius > 3.0:
					result.append("Invalid ground burst duration or footprint " + str(rule.id))
			"ground_sequence":
				var phases: Array = rule.get("phases", [])
				if phases.is_empty() or phases.size() > 4 or not phases.all(valid_phase) or not valid_tuning(rule, {"radius": rule.radius}) or int(rule.targets) not in [1,2,3,4]:
					result.append("Invalid Core sequence " + str(rule.id))
				if rule.has("death_window_ms") and (int(rule.death_window_ms) not in range(100,6001) or not valid_tuning(rule, {"burst_radius": rule.get("burst_radius", 0)})):
					result.append("Invalid Core death trigger " + str(rule.id))
			"anchor_beam":
				if rule.root_ms <= 0 or rule.beam_range <= .85 or rule.lifetime_ms <= 0 or rule.cooldown_ms <= rule.lifetime_ms or int(rule.targets) not in [1, 2, 3] or rule.radius > .34:
					result.append("Invalid anchor beam duration or footprint " + str(rule.id))
			_:
				result.append("Unknown Core mechanic " + str(rule.mechanic))
	for skill_id in Variants.PROFILES:
		var rule := skill_by_id(skill_id)
		if rule.get("mechanic") != "ground_sequence":
			result.append("Positional variant needs a ground sequence: " + skill_id)
			continue
		var pair: Dictionary = Variants.PROFILES[skill_id]
		var phases: Array = rule.get("phases", [])
		if phases.is_empty() or not phases[0] is Dictionary:
			result.append("Positional variant needs a valid opening phase: " + skill_id)
			continue
		var opening: Dictionary = phases[0]
		for style in ["melee", "ranged"]:
			var variant: Dictionary = pair.get(style, {})
			var movement: String = variant.get("movement", "")
			if str(variant.get("variant_name", "")).is_empty() or movement not in ["", "approach", "retreat"] or (variant.has("targeting") and (style != "melee" or variant.targeting != "self" or not movement.is_empty())):
				result.append("Invalid %s variant for %s" % [style, skill_id])
			var retreat := float(variant.get("retreat_distance", 0.0))
			if (movement == "retreat" and not (retreat > 0.0 and retreat <= 3.0)) or (not movement.is_empty() and int(opening.get("delay", -1)) != 0):
				result.append("Invalid movement variant for " + skill_id)
			var displacement := absf(float(variant.get("opening_displace", 0.0)))
			if variant.has("opening_displace") and (not opening.get("enemy", {}).has("displace") or not (displacement > 0.0 and displacement <= 2.0)):
				result.append("Invalid displacement variant for " + skill_id)
	var signatures := {}
	var used_skills := {}
	for species in Catalog.SIGNATURES:
		var signature: Dictionary = Catalog.SIGNATURES[species]
		if Seeds.index_of(species) < 0 or not ids.has(signature.skill) or str(signature.tag).is_empty() or signatures.has(signature.tag):
			result.append("Invalid or duplicate Core signature for " + str(species))
		signatures[signature.tag] = true
		used_skills[signature.skill] = true
	for skill_id in ids:
		if not used_skills.has(skill_id):
			result.append("Core skill has no species signature " + str(skill_id))
	var modifiers := {}
	var predicates := {}
	var authored_tags: Dictionary = signatures.duplicate()
	for modifier in MODIFIERS:
		var key := str([modifier.skill, modifier.slot, modifier.tag, modifier.get("forms", [])])
		var rule := skill_by_id(modifier.skill)
		if modifiers.has(modifier.id) or predicates.has(key) or rule.is_empty() or modifier.slot not in ["secondary", "form", "catalyst", "graft"] or not valid_slot_tag(modifier.tag, modifier.slot) or modifier.get("forms", []).any(func(form): return not WEAPON_DELIVERY.has(form)) or not valid_tuning(rule, modifier.values):
			result.append("Invalid or duplicate Core modifier " + str(modifier.id))
		modifiers[modifier.id] = true
		predicates[key] = true
		if modifier.slot != "graft":
			authored_tags[modifier.tag] = true
	for seed in Seeds.DEFINITIONS:
		if not Catalog.SIGNATURES.has(seed.id):
			result.append("Missing Core signature for " + str(seed.id))
		for tag in seed.tags:
			if not authored_tags.has(tag):
				result.append("Plant tag has no authored Core role: " + str(tag))
	return result
