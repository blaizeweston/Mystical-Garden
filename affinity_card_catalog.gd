extends RefCounted
## EC01 authoring. Values are in HP or milliseconds and apply only at the named consumer.
const RARITIES := ["Common", "Uncommon", "Rare", "Epic"]
const PLAYTEST := {
	"offer_size": 3,
	"acquisition_limit": 12,
	"reroll_costs": [2, 4, 6],
	"rarity_curve": [
		[1, [78, 18, 3, 1]],
		[18, [64, 25, 8, 3]],
		[42, [52, 30, 13, 5]],
		[90, [42, 32, 18, 8]],
	],
}

const DEFINITIONS := {
	"rime_opening": {
		"title": "Sharpened Petals", "scope": "core", "policy": "stackable",
		"trigger": "Opening petal contact", "consumer": ["res://frost_combat.gd", "bloom_phase"],
		"requires": {"family": "frost", "skill": "rime_bloom"}, "parameter": "opening_bonus_hp",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Rime Bloom's opening petals deal +%s damage.",
		"detail": "Applies to each enemy hit by the opening petals. Closing petals and Brittle keep their usual effects.",
	},
	"ember_impact": {
		"title": "Emberfront", "scope": "core", "policy": "stackable",
		"trigger": "First Ember Wake contact per enemy", "consumer": ["res://fire_combat.gd", "on_event"],
		"requires": {"family": "fire", "skill": "ember_wake"}, "parameter": "impact_hp",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Ember Wake deals +%s damage on first contact with each enemy.",
		"detail": "The bonus belongs to the trail's first impact on each enemy. Burning ticks keep their usual damage.",
	},
	"dewfall_impact": {
		"title": "Driving Rain", "scope": "core", "policy": "stackable",
		"trigger": "Dewfall curtain enemy contact", "consumer": ["res://water_combat.gd", "on_event"],
		"requires": {"family": "water", "skill": "dewfall"}, "parameter": "impact_hp",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Dewfall deals +%s damage to each enemy its curtain hits.",
		"detail": "The bonus applies to enemy contact. Drenched and Slow cleansing keep their usual effects.",
	},
	"vital_bloom_time": {
		"title": "Lingering Blossom", "scope": "core", "policy": "stackable",
		"trigger": "Vital Bloom grant", "consumer": ["res://vital_combat.gd", "grant"],
		"requires": {"family": "vital", "skill": "vital_bloom"}, "parameter": "duration_bonus_ms",
		"values": [250, 400, 550, 700], "unit": "ms", "limit": 4,
		"description": "Extends the duration of Vitality granted by Vital Bloom by %s seconds.",
		"detail": "Vitality's Max HP and regeneration values stay the same. Each benefit uses its strongest active source.",
	},
	"thorn_line_bleed": {
		"title": "Sawtooth Briars", "scope": "core", "policy": "stackable",
		"trigger": "Thorn Line growth and its Bleed ticks", "consumer": ["res://thorn_affinity.gd", "grow"],
		"requires": {"family": "thorn", "skill": "thorn_line"}, "parameter": "tick_hp",
		"values": [1, 2, 3, 4], "unit": "hp", "limit": 4,
		"description": "Thorn Line's Bleed deals +%s damage per tick.",
		"detail": "Applies to Bleed from Thorn Line brambles. The tick interval, slow and lingering time stay the same.",
	},
	"ironbark_time": {
		"title": "Seasoned Ironbark", "scope": "core", "policy": "stackable",
		"trigger": "Ironbark armor grant", "consumer": ["res://wood_affinity.gd", "grant"],
		"requires": {"family": "wood", "skill": "ironbark"}, "parameter": "duration_bonus_ms",
		"values": [250, 400, 550, 700], "unit": "ms", "limit": 4,
		"description": "Extends the duration of Ironbark's Bark Armor by %s seconds while it has capacity.",
		"detail": "Armor still ends when it is depleted. Absorption and armor capacity stay the same.",
	},
	"chain_spark_power": {
		"title": "Gathered Thunder", "scope": "core", "policy": "stackable",
		"trigger": "Chain Spark discharge on Core contact", "consumer": ["res://storm_affinity.gd", "on_event"],
		"requires": {"family": "storm", "skill": "chain_spark"}, "parameter": "initial",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Chain Spark starts with +%s damage. Later jumps use the increased damage with normal falloff.",
		"detail": "Requires a valid first hit. The maximum number of jumps and their range stay the same.",
	},
	"phantom_stride_time": {
		"title": "Lingering Footfall", "scope": "core", "policy": "stackable",
		"trigger": "Phantom Step landing", "consumer": ["res://spirit_affinity.gd", "grant"],
		"requires": {"family": "spirit", "skill": "phantom_step"}, "parameter": "duration_bonus_ms",
		"values": [250, 400, 550, 700], "unit": "ms", "limit": 4,
		"description": "Extends the duration of Phantom Step's Spiritstride by %s seconds.",
		"detail": "Granted after a successful step. Travel distance, speed bonus and trace duration stay the same.",
	},
	"gravity_collapse": {
		"title": "Crushing Center", "scope": "core", "policy": "stackable",
		"trigger": "Gravity Well collapse", "consumer": ["res://void_affinity.gd", "on_event"],
		"requires": {"family": "void", "skill": "gravity_well"}, "parameter": "collapse",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Gravity Well's collapse deals +%s damage to each enemy still inside.",
		"detail": "Applies to the single collapse following the gathering phase. Gathering strength stays the same.",
	},
	"burning_strikes_heat": {
		"title": "Hotter Embers", "scope": "form", "policy": "stackable",
		"trigger": "Burning Strikes weapon contact", "consumer": ["res://fire_combat.gd", "ignite"],
		"requires": {"family": "fire", "behavior": "burning_strikes"}, "parameter": "tick_hp",
		"values": [1, 2, 3, 4], "unit": "hp", "limit": 4,
		"description": "Burning Strikes deals +%s Burning damage per tick, including the first.",
		"detail": "Your qualifying basic attack hits apply Burning to the enemies they hit. The duration and tick interval stay the same.",
	},
	"splinter_sharpness": {
		"title": "Jagged Splinters", "scope": "form", "policy": "stackable",
		"trigger": "Splintering Strikes fragment contact", "consumer": ["res://wood_affinity.gd", "splinters"],
		"requires": {"family": "wood", "behavior": "splintering_strikes"}, "parameter": "fragment_hp",
		"values": [1, 2, 3, 4], "unit": "hp", "limit": 4,
		"description": "Splintering Strikes fragments deal +%s damage to nearby secondary targets.",
		"detail": "Fragments travel in a clear forward fan after a qualifying basic attack hit. The initial hit and trigger interval stay the same.",
	},
	"arc_recharge": {
		"title": "Quick Conduction", "scope": "form", "policy": "stackable",
		"trigger": "Arcing Strikes response on a weapon contact", "consumer": ["res://storm_affinity.gd", "on_event"],
		"requires": {"family": "storm", "behavior": "arcing_strikes"}, "parameter": "interval_reduction_ms",
		"values": [80, 120, 160, 200], "unit": "ms", "limit": 4,
		"description": "Arcing Strikes can trigger again %s seconds sooner after a qualifying hit.",
		"detail": "The next eligible basic attack hit triggers the arc when it is ready. Misses spend no trigger.",
	},
	"drawing_pressure": {
		"title": "Heavy Compression", "scope": "form", "policy": "stackable",
		"trigger": "Drawing Strikes response on a weapon contact", "consumer": ["res://void_affinity.gd", "on_event"],
		"requires": {"family": "void", "behavior": "drawing_strikes"}, "parameter": "form_hp",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Drawing Strikes deals +%s compression damage on its first qualifying basic attack hit.",
		"detail": "Draw strength and the trigger interval stay the same. Valid damage still applies when the target resists movement.",
	},
	"catalyst_ember_heat": {
		"title": "Heart of Cinders", "scope": "catalyst", "policy": "stackable",
		"trigger": "Fire Catalyst response applies Burning", "consumer": ["res://fire_combat.gd", "ignite"],
		"requires": {"family": "fire", "responses": ["burn", "ember_burst", "recipient_ember_response", "self_ember_response"]},
		"parameter": "tick_hp", "values": [1, 2, 3, 4], "unit": "hp", "limit": 4,
		"description": "Burning applied by your Fire Catalyst deals +%s damage per tick, including the first.",
		"detail": "Uses the Burning applied by your mapped class-ability response. Burst impact damage and Burning duration stay the same.",
	},
	"catalyst_drench_time": {
		"title": "Clinging Dew", "scope": "catalyst", "policy": "stackable",
		"trigger": "Water Catalyst response applies Drenched", "consumer": ["res://water_combat.gd", "drench"],
		"requires": {"family": "water", "responses": ["drench", "radial_wash", "healing_wash", "landing_wash"]},
		"parameter": "duration_bonus_ms", "values": [250, 400, 550, 700], "unit": "ms", "limit": 4,
		"description": "Extends the duration of Drenched applied by your Water Catalyst by %s seconds.",
		"detail": "Applies when your mapped class-ability response Drenches an enemy. The amount of attack damage reduction stays the same.",
	},
	"catalyst_vital_regen": {
		"title": "Greening Chime", "scope": "catalyst", "policy": "stackable",
		"trigger": "Vital Catalyst grants Vitality", "consumer": ["res://vital_combat.gd", "grant"],
		"requires": {"family": "vital", "responses": ["self_vitality", "radial_vitality", "recipient_vitality", "landing_vitality"]},
		"parameter": "regen_per_second", "values": [1, 2, 3, 4], "unit": "hp", "limit": 4,
		"description": "Vitality granted by your Vital Catalyst restores +%s HP per second.",
		"detail": "The strongest active regeneration source applies. Max HP and Vitality's duration stay the same.",
	},
	"catalyst_bark_time": {
		"title": "Enduring Bark", "scope": "catalyst", "policy": "stackable",
		"trigger": "Wood Catalyst grants Bark Armor", "consumer": ["res://wood_affinity.gd", "grant"],
		"requires": {"family": "wood", "responses": ["self_bark", "radial_splinters_and_bark", "recipient_bark", "landing_bark"]},
		"parameter": "duration_bonus_ms", "values": [250, 400, 550, 700], "unit": "ms", "limit": 4,
		"description": "Extends the duration of Bark Armor granted by your Wood Catalyst by %s seconds while it has capacity.",
		"detail": "Armor still ends when depleted. Absorption and armor capacity stay the same.",
	},
	"quake_impact": {
		"title": "Deep Fault", "scope": "class", "policy": "stackable",
		"trigger": "Native Root Quake hit", "consumer": ["res://outgoing_hits.gd", "skill_targets"],
		"requires": {"class": "warden", "mode": "quake", "skill": "Root Quake"}, "parameter": "damage",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Root Quake deals +%s damage per hit.",
		"detail": "Applies to Root Quake's native hits. Aftershock and Catalyst damage stay the same.",
	},
	"nova_impact": {
		"title": "Heavy Spores", "scope": "class", "policy": "stackable",
		"trigger": "Native Spore Nova hit", "consumer": ["res://outgoing_hits.gd", "skill_targets"],
		"requires": {"class": "weaver", "mode": "nova", "skill": "Spore Nova"}, "parameter": "damage",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Spore Nova deals +%s damage per hit.",
		"detail": "Applies to Spore Nova's native hits, including valid hits in Symbiotic Nova's bonus area. Secondary bursts stay the same.",
	},
	"snare_root_time": {
		"title": "Clinging Brambles", "scope": "class", "policy": "stackable",
		"trigger": "Bramble Snare trap contact", "consumer": ["res://combat_traits.gd", "trip_snare"],
		"requires": {"class": "ranger", "mode": "snare", "skill": "Bramble Snare"}, "parameter": "bind",
		"values": [150, 250, 350, 450], "unit": "ms", "limit": 4,
		"description": "Extends the duration of Bramble Snare's roots by %s seconds.",
		"detail": "The trap must catch an enemy that can be rooted. Trap lifetime and damage stay the same.",
	},
	"siphon_impact": {
		"title": "Harvest Edge", "scope": "class", "policy": "stackable",
		"trigger": "Native Siphon Cut primary hit", "consumer": ["res://outgoing_hits.gd", "skill_targets"],
		"requires": {"class": "reaper", "mode": "siphon", "skill": "Siphon Cut"}, "parameter": "damage",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Siphon Cut's primary hit deals +%s damage.",
		"detail": "Applies to the primary victim. Siphon Cut's native healing and secondary hits stay the same.",
	},
	"chime_ward_time": {
		"title": "Lasting Resonance", "scope": "class", "policy": "stackable",
		"trigger": "Warding Chime native Ward grant", "consumer": ["res://native_class_actions.gd", "cast"],
		"requires": {"class": "oracle", "mode": "ward", "skill": "Warding Chime"}, "parameter": "ward_ms",
		"values": [100, 200, 300, 400], "unit": "ms", "limit": 4,
		"description": "Extends the duration of Warding Chime's native Wards by %s seconds.",
		"detail": "Applies to eligible recipients of Warding Chime. Ward charges and Catalyst responses stay the same.",
	},
	"ordinary_weapon_damage": {
		"title": "Honed Strikes", "scope": "weapon", "policy": "stackable",
		"trigger": "Ordinary attack damage roll", "consumer": ["res://weapon_attack_world.gd", "capture_attack"],
		"requires": {"capability": "strike"}, "parameter": "strike_damage",
		"values": [1, 2, 3, 4], "unit": "hp", "limit": 4,
		"description": "Basic attacks gain +%s damage.",
		"detail": "Adds to the damage roll before attack delivery and mitigation. Applies to the weapon roll used by basic attacks.",
	},
	"ordinary_weapon_interval": {
		"title": "Light Grip", "scope": "weapon", "policy": "stackable",
		"trigger": "Ordinary attack interval begins", "consumer": ["res://weapon_attack_world.gd", "capture_attack"],
		"requires": {"capability": "strike"}, "parameter": "strike_interval",
		"values": [20, 35, 50, 65], "unit": "ms", "limit": 4,
		"description": "Increases basic attack speed.",
		"detail": "Copies add their reductions to the time between basic attacks. The displayed attack speed comes from the resulting interval.",
	},
	"run_health": {
		"title": "Hardy Frame", "scope": "general", "policy": "stackable",
		"trigger": "Maximum health resolves for the current expedition", "consumer": ["res://expedition_life.gd", "native_maximum"],
		"requires": {}, "parameter": "max_hp", "values": [3, 5, 7, 9], "unit": "hp", "limit": 4,
		"description": "Gain %s Max HP for this expedition. Current health is unchanged on acquisition.",
		"detail": "Adds to your expedition Max HP. This upgrade ends when you leave the expedition.",
	},
	"run_dodge_recovery": {
		"title": "Quick Footing", "scope": "general", "policy": "stackable",
		"trigger": "Dodge recovery begins", "consumer": ["res://game.gd", "dodge_player"],
		"requires": {}, "parameter": "dodge_interval", "values": [45, 70, 95, 120], "unit": "ms", "limit": 4,
		"description": "Reduces your dodge cooldown by %s seconds.",
		"detail": "Shortens the cooldown assigned by a dodge. Dodge distance and movement rules stay the same.",
	},
	"dew_shelter": {
		"title": "Dew Shelter", "scope": "core", "policy": "unique",
		"trigger": "Living ally touched by Dewfall", "consumer": ["res://water_combat.gd", "on_event"],
		"requires": {"family": "water", "skill": "dewfall"}, "parameter": "shelter_ward_ms",
		"fixed": 1200, "unit": "ms", "limit": 1,
		"description": "Dewfall gives living allies it touches a one-charge Ward for %s seconds.",
		"detail": "You qualify at Dewfall's origin. Each living recipient can receive one Ward per cast. Dewfall damage, Drenched and Slow cleansing keep their usual effects. The Ward grants no extra Catalyst response.",
	},
	"echoing_growth": {
		"title": "Echoing Growth", "scope": "class", "policy": "unique",
		"trigger": "Native Spore Nova hits inside the owner’s active Cultivate Bloom", "consumer": ["res://affinity_cards.gd", "bloom_echo"],
		"requires": {"class": "weaver", "mode": "nova", "skill": "Spore Nova", "focus": "bloomcaller", "q_field": "growth"},
		"parameter": "bloom_echo_hp", "fixed": 10, "unit": "hp", "limit": 1,
		"description": "When Spore Nova damages an enemy in your Cultivate Bloom, the bloom deals %s secondary damage to eligible enemies inside.",
		"detail": "Requires Bloomcaller and your own active Cultivate Bloom. The extra pulse happens at most once per Nova. It applies no extra roots or Marks, and triggers no Catalyst, Form, graft or other secondary effects.",
	},
}


static func rise(floor_number: int) -> Array[float]:
	var curve: Array = PLAYTEST.rarity_curve
	var left: Array = curve.front()
	for right: Array in curve.slice(1):
		if floor_number <= int(right[0]):
			var fraction := clampf(float(floor_number - int(left[0])) / float(int(right[0]) - int(left[0])), 0.0, 1.0)
			var blended: Array[float] = []
			for index in RARITIES.size():
				blended.append(lerpf(float(left[1][index]), float(right[1][index]), fraction))
			return blended
		left = right
	var tail: Array[float] = []
	tail.assign(left[1])
	return tail


static func effect_text(definition: Dictionary, value: int) -> String:
	var text: String = definition.description
	if "%s" not in text:
		return text
	var number := str(value) if definition.unit == "hp" else ("%.3f" % (value / 1000.0)).rstrip("0").trim_suffix(".")
	return text % number


static func contribution_label(definition: Dictionary) -> String:
	match definition.parameter:
		"max_hp": return "Max HP bonus"
		"regen_per_second": return "Regeneration bonus"
		"strike_interval": return "Basic attack timing"
		"interval_reduction_ms": return "Arc trigger interval reduction"
		"dodge_interval": return "Dodge cooldown reduction"
	return "Duration bonus" if definition.unit == "ms" else "Damage bonus"


static func contribution(definition: Dictionary, value: int) -> String:
	match definition.parameter:
		"regen_per_second": return "+%d HP/s" % value
		"max_hp": return "+%d Max HP" % value
		"strike_interval": return "%s s less between basic attacks" % ("%.3f" % (value / 1000.0)).rstrip("0").trim_suffix(".")
	if definition.unit == "hp":
		return "+%d damage" % value
	if value == 0:
		return "+0 s"
	var seconds := ("%.2f" if value % 10 == 0 else "%.3f") % (value / 1000.0)
	return "+%s s" % seconds
