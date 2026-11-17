extends RefCounted

const Ruleset = preload("res://combat_ruleset.gd")
const Affinities = preload("res://plant_affinities.gd")
const Catalyst = preload("res://catalyst_adapters.gd")
const Classes = preload("res://class_catalog.gd")
const Skills = preload("res://skill_catalog.gd")
const WeaponRules = preload("res://weapon_system.gd")
const Delivery = preload("res://core_skill_rules.gd")
const SLOTS := ["core", "form", "catalyst"]
const Materials = preload("res://weapon_parts.gd")
const Seeds = preload("res://seed_catalog.gd")
const Preview = preload("res://combat_balance_preview.gd")

# The legacy Frost consumers are separate from the source-owned affinity
# rupture system. Preserve learned nodes, with their other effects intact.
const RESTRICTED_CLASS_EFFECTS := {
	"shatter_damage": "Legacy Shatter bonuses are pending a source-ownership decision for Frost rupture.",
}
const RESTRICTED_NODES := {
	"cracking_roots": "Cracking Roots is pending a decision on native Brittle grants in the affinity ruleset.",
}

static func class_effects_text(effects: Dictionary) -> String:
	var active := effects.duplicate()
	var lines: Array[String] = []
	for key in RESTRICTED_CLASS_EFFECTS:
		if active.erase(key):
			lines.append(RESTRICTED_CLASS_EFFECTS[key])
	var description := Classes.effect_text(active, Preview.enabled)
	if not description.is_empty():
		lines.push_front(description)
	return "\n".join(lines)


static func slot(name: String, part: int) -> Dictionary:
	var identity := Affinities.for_part(part)
	if identity.is_empty():
		return {"state": "empty" if part == 0 else "invalid", "executable": part == 0 and name != "core"}
	identity.executable = Ruleset.FAMILIES.has(identity.primary_affinity)
	identity.state = "ready" if identity.executable else "pending"
	identity.potency_profile = {
		"id": "%s/%s/%s" % [name, identity.primary_affinity, identity.quality],
		"values": Ruleset.FAMILIES[identity.primary_affinity].QUALITY[identity.quality].duplicate() if identity.executable else {},
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
	var tree := Classes.connected_tree(class_id)
	var connected := tree != null and tree.eligible(profile)
	var focus := tree.focus(profile) if connected else Classes.focus_id(profile, class_id)
	var result := {
		"ruleset": Ruleset.ID, "class_id": frame.id, "focus_id": focus,
		"weapon_id": weapon.id, "native_weapon": weapon.duplicate(true),
		"native_class_effects": Classes.bonuses(profile, class_id),
		"core": slot("core", int(slots[0])), "form": slot("form", int(slots[1])),
		"catalyst": slot("catalyst", int(slots[2])), "graft": {}, "class_skills": [],
		"capabilities": {"native_weapon": true, "native_class_skills": not connected or tree.valid(profile), "affinity_effects": false},
	}
	# The weapon supplies presentation/placement. Old species-specific melee
	# movement overrides are deliberately excluded.
	result.core.delivery = Delivery.WEAPON_DELIVERY.get(weapon.visual, {}).duplicate()
	result.form.behavior = Ruleset.FORMS.get(result.form.get("primary_affinity"), "")
	result.graft = Ruleset.Grafts.resolve(graft)
	var native_pull := float(result.native_class_effects.get("pull",0)) + float(result.graft.get("native_effects",{}).get("pull",0))
	for index in 2:
		var skill := Skills.resolve(class_id, index, profile, connected)
		var adapter := Catalyst.resolve(class_id, index, profile, skill)
		if not adapter.is_empty():
			adapter.response = adapter.responses.get(result.catalyst.get("primary_affinity"), "")
			if class_id == Classes.Reaper.TREE.class_id and connected and native_pull > 0.0:
				adapter.native_displacement.pull = native_pull
				adapter.conflict = "Native weapon or graft pull takes priority over Catalyst displacement."
			elif class_id == Classes.Oracle.CLASS_ID and connected and native_pull > 0.0 and int(skill.slot) == 0 and skill.get("subclass_focus","") == "omenreader":
				adapter.native_displacement.pull = native_pull
				adapter.conflict = "Native graft pull takes priority over Catalyst displacement."
		result.class_skills.append(adapter)
	result.capabilities.affinity_effects = [result.core, result.form, result.catalyst].any(func(part): return part.state == "ready")
	result.capabilities.strike = result.form.executable
	result.capabilities.core_action = result.core.executable
	result.capabilities.class_actions = result.capabilities.native_class_skills and result.catalyst.executable and result.class_skills.all(func(adapter): return not adapter.is_empty())
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
	if stats.has("pierce"):
		stats.pattern = "line"
	var procs: Dictionary = build.graft.get("procs", {})
	if procs.has("spread_bind"):
		stats.spread_bind = float(stats.get("spread_bind", 0)) + float(procs.spread_bind)
	var graft_text := Ruleset.Grafts.describe(build.graft)
	if not graft_text.is_empty():
		stats.interactions.append(graft_text)
	# Legacy Shatter has no approved native source in affinity Frost.
	for effect in RESTRICTED_CLASS_EFFECTS:
		stats.erase(effect)
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
	if name == "catalyst" and not build.capabilities.native_class_skills:
		return "This character's connected %s data needs review." % str(build.class_id).capitalize()
	var part: Dictionary = build[name]
	if part.executable:
		return ""
	if part.state == "empty":
		return "Equip a supported Core material to cast its family skill."
	if part.state == "invalid":
		return "%s material is invalid." % name.capitalize()
	return "%s %s is pending implementation." % [str(part.primary_affinity).capitalize(), name.capitalize()]


static func starting_tree(class_id: int, profile: Dictionary) -> RefCounted:
	var tree := Classes.connected_tree(class_id)
	return tree if tree != null and tree.eligible(profile) and tree.valid(profile) and tree.focus(profile).is_empty() else null


static func departure_refusal(player: Dictionary) -> String:
	var tree := starting_tree(int(player.get("frame",0)), player.get("character",{}))
	if tree != null:
		return "Choose your level 1 %s starting focus at the Wilds Gate." % tree.label
	var build := for_player(player, true)
	if not build.capabilities.native_class_skills:
		return refusal(build, "catalyst")
	for name in ["core", "form", "catalyst"]:
		if build[name].state != "empty":
			var reason := refusal(build, name)
			if not reason.is_empty():
				return reason + " Equip a supported material or leave the slot empty."
	return ""


const RESPONSE_TEXT := {
	"brittle": "applies Brittle",
	"brittle_burst": "applies Brittle to nearby enemies",
	"recipient_frost_response": "lets healed allies answer their next survived enemy hit with Brittle",
	"self_frost_response": "lets you answer your next survived enemy hit with Brittle",
	"burn": "sets enemies Burning",
	"ember_burst": "damages nearby enemies and sets them Burning",
	"recipient_ember_response": "lets healed allies burn the enemy behind their next survived hit",
	"self_ember_response": "lets you burn the enemy behind your next survived hit",
	"drench": "Drenches enemies",
	"radial_wash": "Drenches nearby enemies and clears ordinary Slow from nearby allies",
	"healing_wash": "Drenches enemies and clears ordinary Slow from allies near the heal",
	"landing_wash": "Drenches enemies and clears ordinary Slow from allies near your landing",
	"self_vitality": "grants you Vitality on an offensive hit",
	"radial_vitality": "grants Vitality to the protected player and nearby living allies",
	"recipient_vitality": "grants Vitality to healed allies",
	"landing_vitality": "grants you Vitality at landing",
	"growth": "grows brambles at the impact",
	"lingering_thicket": "grows a thicket around the protected player",
	"protective_growth": "grows brambles at the heal",
	"departure_growth": "grows brambles where you moved from",
	"self_bark": "grants you Bark Armor on an offensive hit",
	"radial_splinters_and_bark": "grants Bark Armor and releases splinters around the protected player",
	"recipient_bark": "grants Bark Armor to healed allies",
	"landing_bark": "grants you Bark Armor at landing",
	"discharge": "releases one electrical discharge",
	"radial_discharge": "deals electrical damage around the protected player",
	"recipient_charge": "grants healed allies a Storm Charge for their next qualifying basic attack hit",
	"landing_discharge": "releases an electrical burst at landing",
	"self_stride": "grants you Spiritstride",
	"radial_stride_and_trace": "grants nearby allies Spiritstride and leaves a trace of the protected player",
	"recipient_stride": "grants healed allies Spiritstride",
	"departure_trace_and_landing_stride": "leaves a trace on departure and grants you Spiritstride at landing",
	"compression": "damages and draws in enemies at the effect location",
	"radial_repulsion": "damages and pushes enemies away from the protected player",
	"healing_repulsion": "damages and pushes enemies away from the heal",
	"landing_repulsion": "damages and pushes enemies away from your landing",
}


static func support_text(material: Dictionary) -> String:
	var names: PackedStringArray = []
	for support: String in material.supporting_affinities:
		names.append(support.capitalize())
	if names.is_empty():
		return ""
	return "Supporting affinities for possible upgrade cards: " + ", ".join(names) + "."


static func planting_description(species: int, affinity_mode: bool) -> String:
	if not affinity_mode:
		return Seeds.modifier_text(species)
	var ordinary_id: int = Seeds.DEFINITIONS[species].part
	var refined_id := Materials.rare_part(species)
	var material := slot("core", ordinary_id)
	if material.state != "ready":
		return "Affinity information is unavailable for this species."
	var family: String = material.primary_affinity
	var core: String = Ruleset.FAMILIES[family].description("core",material.quality).get_slice(" · ",0)
	var text := "%s primary affinity · %s (Core)\nOrdinary: %s · Refined: %s" % [
		family.capitalize(), core, Materials.part_name(ordinary_id), Materials.part_name(refined_id)]
	var supports := support_text(material)
	return text + "\n" + supports if not supports.is_empty() else text


static func slot_preview(build: Dictionary, name: String, part_id: int) -> Dictionary:
	var material := slot(name, part_id)
	if material.state == "empty":
		var empty := {
			"core": "Empty · Equip a plant part to use a Core skill.",
			"form": "Empty · Basic attacks use your weapon's native effects.",
			"catalyst": "Empty · Class abilities use their native effects.",
		}
		return {"summary": empty[name], "detail": ""}
	if material.state != "ready":
		return {"summary": "%s material is unavailable." % name.capitalize(), "detail": ""}
	var family: String = material.primary_affinity
	var header := "%s · %s" % [family.capitalize(), str(material.quality).capitalize()]
	var authored: String = Ruleset.FAMILIES[family].description(name, material.quality)
	authored = authored.replace("direct weapon contacts", "direct basic attack hits").replace("Direct weapon contacts", "Direct basic attack hits").replace("direct weapon attack", "basic attack").replace("eligible weapon hit", "eligible basic attack hit").replace("maximum HP", "Max HP")
	var summary := header + "\n" + authored.get_slice("\n", 0)
	var detail := authored
	match name:
		"core":
			var candidate := build.duplicate()
			material.delivery = build.core.delivery
			candidate.core = material
			var skill := core_skill(candidate)
			var aim: String = "Centered on you." if skill.targeting == "self" else "Moves in your aimed direction." if family == "spirit" else {
				"ground": "Aim on the ground.", "arrow": "Arrow aiming.", "bolt": "Bolt aiming.", "seed": "Seed aiming.",
			}[skill.delivery]
			detail += "\n" + aim
		"form":
			if family == "void":
				var native := native_stats(build)
				if float(native.get("knockback",0.0))>0.0 or float(native.get("pull",0.0))>0.0:
					detail += "\nDrawing Strikes still adds damage when your native displacement takes priority."
		"catalyst":
			summary = header
			if not build.capabilities.native_class_skills:
				return {"summary": summary + "\nThis class path is unavailable.", "detail": support_text(material)}
			var notes: PackedStringArray = []
			for adapter in build.class_skills:
				if adapter.is_empty():
					continue
				var response: String = adapter.responses.get(family, "")
				if not RESPONSE_TEXT.has(response):
					continue
				var trigger: String = {"block": "After an actual block, ", "contact": "On contact, "}.get(adapter.trigger, "")
				var effect: String = trigger + RESPONSE_TEXT[response]
				if trigger.is_empty():
					effect = effect.left(1).to_upper() + effect.substr(1)
				summary += "\n%s · %s." % [adapter.native_skill.name, effect]
				if family == "void" and not str(adapter.conflict).is_empty() and not notes.has(adapter.conflict):
					notes.append(adapter.conflict)
			if not notes.is_empty():
				detail += "\n" + "\n".join(notes)
	var supports := support_text(material)
	if not supports.is_empty():
		detail += "\n" + supports
	return {"summary": summary, "detail": detail}


static func core_skill(build: Dictionary) -> Dictionary:
	var core: Dictionary = build.get("core", {})
	if core.get("state") != "ready":
		return {}
	var family: String = core.primary_affinity
	var balance = Ruleset.FAMILIES[family]
	var delivery: Dictionary = core.delivery
	var profile: Array = {
		"frost": ["Rime Bloom", "rime_bloom", "#97dfff", Ruleset.Frost.BLOOM_RADIUS, 2500, Ruleset.Frost.BLOOM_COOLDOWN_MS],
		"fire": ["Ember Wake", "ember_wake", "#f29b57", Ruleset.Fire.HALF_LENGTH, Ruleset.Fire.FIELD_MS + 750, Ruleset.Fire.COOLDOWN_MS],
		"water": ["Dewfall", "dewfall", "#82d7ec", Ruleset.Water.WAVE_RADIUS, Ruleset.Water.WAVE_MS + 750, Ruleset.Water.COOLDOWN_MS],
		"vital": ["Vital Bloom", "worldbloom", "#abd785", Ruleset.Vital.CORE_RADIUS, 750, Ruleset.Vital.COOLDOWN_MS],
		"thorn": ["Thorn Line", "thorn_line", "#a7bf67", Ruleset.Thorn.CORE_HALF_LENGTH, 750, Ruleset.Thorn.CORE_COOLDOWN_MS],
		"wood": ["Ironbark", "ironbark", "#e1b778", Ruleset.Wood.CORE_RADIUS, 750, Ruleset.Wood.COOLDOWN_MS],
		"storm": ["Chain Spark", "chain_spark", "#e3d184", .12, 750, Ruleset.Storm.CORE_CD],
		"spirit": ["Phantom Step", "phantom_step", "#bdafe8", .34, 750, Ruleset.Spirit.CORE_CD],
		"void": ["Gravity Well", "gravity_well", "#ad8bcb", Ruleset.Void.CORE_RADIUS, 2000, Ruleset.Void.CORE_CD],
	}[family]
	return {"id": core.affinity_core_skill_id, "name": profile[0],
		"icon": "res://assets/ui/core_skills/%s.png" % profile[1], "mechanic": "swept_projectile" if family=="storm" and delivery.kind!="ground" else "ground_sequence",
		"affinity_family": family, "material": core, "color": profile[2],
		"targeting": "self" if family in ["vital","wood"] else "ground",
		"weapon_form": build.native_weapon.visual, "delivery": "ground" if family=="spirit" else delivery.kind,
		"projectile": Delivery.DELIVERY_SHAPES[delivery.kind], "speed": 17.0, "range": Ruleset.Spirit.STEP_DISTANCE if family=="spirit" else 0.0 if family in ["vital","wood"] else delivery.range,
		"radius": profile[3], "width": Ruleset.Thorn.CORE_WIDTH if family == "thorn" else Ruleset.Fire.WIDTH, "lifetime_ms": profile[4], "cooldown_ms": profile[5],
		"tooltip": balance.description("core", core.quality), "modifiers": []}
