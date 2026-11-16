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
		"description": "Rime Bloom's opening petals deal %s more damage to each enemy hit.",
	},
	"ember_impact": {
		"title": "Emberfront", "scope": "core", "policy": "stackable",
		"trigger": "First Ember Wake contact per enemy", "consumer": ["res://fire_combat.gd", "on_event"],
		"requires": {"family": "fire", "skill": "ember_wake"}, "parameter": "impact_hp",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Ember Wake deals %s more impact damage the first time it touches each enemy.",
	},
	"dewfall_impact": {
		"title": "Driving Rain", "scope": "core", "policy": "stackable",
		"trigger": "Dewfall curtain enemy contact", "consumer": ["res://water_combat.gd", "on_event"],
		"requires": {"family": "water", "skill": "dewfall"}, "parameter": "impact_hp",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Dewfall's curtain deals %s more damage to each enemy it hits.",
	},
	"vital_bloom_time": {
		"title": "Lingering Blossom", "scope": "core", "policy": "stackable",
		"trigger": "Vital Bloom grant", "consumer": ["res://vital_combat.gd", "grant"],
		"requires": {"family": "vital", "skill": "vital_bloom"}, "parameter": "duration_bonus_ms",
		"values": [250, 400, 550, 700], "unit": "ms", "limit": 4,
		"description": "Vitality granted by Vital Bloom lasts %s longer.",
	},
	"thorn_line_bleed": {
		"title": "Sawtooth Briars", "scope": "core", "policy": "stackable",
		"trigger": "Thorn Line growth and its Bleed ticks", "consumer": ["res://thorn_affinity.gd", "grow"],
		"requires": {"family": "thorn", "skill": "thorn_line"}, "parameter": "tick_hp",
		"values": [1, 2, 3, 4], "unit": "hp", "limit": 4,
		"description": "Bleed from Thorn Line deals %s more damage per tick.",
	},
	"ironbark_time": {
		"title": "Seasoned Ironbark", "scope": "core", "policy": "stackable",
		"trigger": "Ironbark armor grant", "consumer": ["res://wood_affinity.gd", "grant"],
		"requires": {"family": "wood", "skill": "ironbark"}, "parameter": "duration_bonus_ms",
		"values": [250, 400, 550, 700], "unit": "ms", "limit": 4,
		"description": "Bark Armor granted by Ironbark lasts %s longer if it still has capacity.",
	},
	"chain_spark_power": {
		"title": "Gathered Thunder", "scope": "core", "policy": "stackable",
		"trigger": "Chain Spark discharge on Core contact", "consumer": ["res://storm_affinity.gd", "on_event"],
		"requires": {"family": "storm", "skill": "chain_spark"}, "parameter": "initial",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Chain Spark starts with %s more damage. Subsequent jumps use that increased value with normal falloff.",
	},
	"phantom_stride_time": {
		"title": "Lingering Footfall", "scope": "core", "policy": "stackable",
		"trigger": "Phantom Step landing", "consumer": ["res://spirit_affinity.gd", "grant"],
		"requires": {"family": "spirit", "skill": "phantom_step"}, "parameter": "duration_bonus_ms",
		"values": [250, 400, 550, 700], "unit": "ms", "limit": 4,
		"description": "Spiritstride granted by a successful Phantom Step lasts %s longer.",
	},
	"gravity_collapse": {
		"title": "Crushing Center", "scope": "core", "policy": "stackable",
		"trigger": "Gravity Well collapse", "consumer": ["res://void_affinity.gd", "on_event"],
		"requires": {"family": "void", "skill": "gravity_well"}, "parameter": "collapse",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Gravity Well's collapse deals %s more damage to each enemy still inside.",
	},
	"burning_strikes_heat": {
		"title": "Hotter Embers", "scope": "form", "policy": "stackable",
		"trigger": "Burning Strikes weapon contact", "consumer": ["res://fire_combat.gd", "ignite"],
		"requires": {"family": "fire", "behavior": "burning_strikes"}, "parameter": "tick_hp",
		"values": [1, 2, 3, 4], "unit": "hp", "limit": 4,
		"description": "Burning Strikes deals %s more Burning damage per tick, including the first.",
	},
	"splinter_sharpness": {
		"title": "Jagged Splinters", "scope": "form", "policy": "stackable",
		"trigger": "Splintering Strikes fragment contact", "consumer": ["res://wood_affinity.gd", "splinters"],
		"requires": {"family": "wood", "behavior": "splintering_strikes"}, "parameter": "fragment_hp",
		"values": [1, 2, 3, 4], "unit": "hp", "limit": 4,
		"description": "Each Splintering Strikes fragment that hits a nearby secondary target deals %s more damage.",
	},
	"arc_recharge": {
		"title": "Quick Conduction", "scope": "form", "policy": "stackable",
		"trigger": "Arcing Strikes response on a weapon contact", "consumer": ["res://storm_affinity.gd", "on_event"],
		"requires": {"family": "storm", "behavior": "arcing_strikes"}, "parameter": "interval_reduction_ms",
		"values": [80, 120, 160, 200], "unit": "ms", "limit": 4,
		"description": "Arcing Strikes can trigger again %s sooner after a qualifying weapon hit.",
	},
	"drawing_pressure": {
		"title": "Heavy Compression", "scope": "form", "policy": "stackable",
		"trigger": "Drawing Strikes response on a weapon contact", "consumer": ["res://void_affinity.gd", "on_event"],
		"requires": {"family": "void", "behavior": "drawing_strikes"}, "parameter": "form_hp",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "A qualifying Drawing Strikes hit deals %s more compression damage.",
	},
	"catalyst_ember_heat": {
		"title": "Heart of Cinders", "scope": "catalyst", "policy": "stackable",
		"trigger": "Fire Catalyst response applies Burning", "consumer": ["res://fire_combat.gd", "ignite"],
		"requires": {"family": "fire", "responses": ["burn", "ember_burst", "recipient_ember_response", "self_ember_response"]},
		"parameter": "tick_hp", "values": [1, 2, 3, 4], "unit": "hp", "limit": 4,
		"description": "Burning applied by a Fire Catalyst response deals %s more damage per tick, including the first.",
	},
	"catalyst_drench_time": {
		"title": "Clinging Dew", "scope": "catalyst", "policy": "stackable",
		"trigger": "Water Catalyst response applies Drenched", "consumer": ["res://water_combat.gd", "drench"],
		"requires": {"family": "water", "responses": ["drench", "radial_wash", "healing_wash", "landing_wash"]},
		"parameter": "duration_bonus_ms", "values": [250, 400, 550, 700], "unit": "ms", "limit": 4,
		"description": "Drenched applied by a Water Catalyst response lasts %s longer.",
	},
	"catalyst_vital_regen": {
		"title": "Greening Chime", "scope": "catalyst", "policy": "stackable",
		"trigger": "Vital Catalyst grants Vitality", "consumer": ["res://vital_combat.gd", "grant"],
		"requires": {"family": "vital", "responses": ["self_vitality", "radial_vitality", "recipient_vitality", "landing_vitality"]},
		"parameter": "regen_per_second", "values": [1, 2, 3, 4], "unit": "hp", "limit": 4,
		"description": "Vitality granted by a Vital Catalyst response supplies %s more regeneration per second. The strongest active source applies.",
	},
	"catalyst_bark_time": {
		"title": "Enduring Bark", "scope": "catalyst", "policy": "stackable",
		"trigger": "Wood Catalyst grants Bark Armor", "consumer": ["res://wood_affinity.gd", "grant"],
		"requires": {"family": "wood", "responses": ["self_bark", "radial_splinters_and_bark", "recipient_bark", "landing_bark"]},
		"parameter": "duration_bonus_ms", "values": [250, 400, 550, 700], "unit": "ms", "limit": 4,
		"description": "Bark Armor granted by a Wood Catalyst response lasts %s longer if it still has capacity.",
	},
	"quake_impact": {
		"title": "Deep Fault", "scope": "class", "policy": "stackable",
		"trigger": "Native Root Quake hit", "consumer": ["res://game.gd", "apply_skill_targets"],
		"requires": {"class": "warden", "mode": "quake", "skill": "Root Quake"}, "parameter": "damage",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Each native Root Quake hit deals %s more damage.",
	},
	"nova_impact": {
		"title": "Heavy Spores", "scope": "class", "policy": "stackable",
		"trigger": "Native Spore Nova hit", "consumer": ["res://game.gd", "apply_skill_targets"],
		"requires": {"class": "weaver", "mode": "nova", "skill": "Spore Nova"}, "parameter": "damage",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Each native Spore Nova hit deals %s more damage.",
	},
	"snare_root_time": {
		"title": "Clinging Brambles", "scope": "class", "policy": "stackable",
		"trigger": "Bramble Snare trap contact", "consumer": ["res://combat_traits.gd", "trip_snare"],
		"requires": {"class": "ranger", "mode": "snare", "skill": "Bramble Snare"}, "parameter": "bind",
		"values": [150, 250, 350, 450], "unit": "ms", "limit": 4,
		"description": "Bramble Snare roots an eligible enemy it catches for %s longer.",
	},
	"siphon_impact": {
		"title": "Harvest Edge", "scope": "class", "policy": "stackable",
		"trigger": "Native Siphon Cut primary hit", "consumer": ["res://game.gd", "apply_skill_targets"],
		"requires": {"class": "reaper", "mode": "siphon", "skill": "Siphon Cut"}, "parameter": "damage",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Siphon Cut's primary hit deals %s more damage.",
	},
	"chime_ward_time": {
		"title": "Lasting Resonance", "scope": "class", "policy": "stackable",
		"trigger": "Warding Chime native Ward grant", "consumer": ["res://game.gd", "use_class_skill"],
		"requires": {"class": "oracle", "mode": "ward", "skill": "Warding Chime"}, "parameter": "ward_ms",
		"values": [100, 200, 300, 400], "unit": "ms", "limit": 4,
		"description": "Native Wards granted by Warding Chime last %s longer.",
	},
	"ordinary_weapon_damage": {
		"title": "Honed Strikes", "scope": "weapon", "policy": "stackable",
		"trigger": "Ordinary attack damage roll", "consumer": ["res://game.gd", "strike_enemy"],
		"requires": {"capability": "strike"}, "parameter": "strike_damage",
		"values": [1, 2, 3, 4], "unit": "hp", "limit": 4,
		"description": "Ordinary weapon attacks gain %s to their base damage roll before delivery and mitigation.",
	},
	"ordinary_weapon_interval": {
		"title": "Light Grip", "scope": "weapon", "policy": "stackable",
		"trigger": "Ordinary attack interval begins", "consumer": ["res://game.gd", "strike_enemy"],
		"requires": {"capability": "strike"}, "parameter": "strike_interval",
		"values": [20, 35, 50, 65], "unit": "ms", "limit": 4,
		"description": "Ordinary weapon attacks can be started %s sooner after an attack (230 ms minimum interval).",
	},
	"run_health": {
		"title": "Hardy Frame", "scope": "general", "policy": "stackable",
		"trigger": "Maximum health resolves for the current expedition", "consumer": ["res://expedition_life.gd", "native_maximum"],
		"requires": {}, "parameter": "max_hp", "values": [3, 5, 7, 9], "unit": "hp", "limit": 4,
		"description": "Gain %s maximum health for this expedition. Current health is unchanged on acquisition.",
	},
	"run_dodge_recovery": {
		"title": "Quick Footing", "scope": "general", "policy": "stackable",
		"trigger": "Dodge recovery begins", "consumer": ["res://game.gd", "dodge_player"],
		"requires": {}, "parameter": "dodge_interval", "values": [45, 70, 95, 120], "unit": "ms", "limit": 4,
		"description": "Recover %s sooner after a dodge (350 ms minimum recovery).",
	},
	"dew_shelter": {
		"title": "Dew Shelter", "scope": "core", "policy": "unique",
		"trigger": "Living ally touched by Dewfall", "consumer": ["res://water_combat.gd", "on_event"],
		"requires": {"family": "water", "skill": "dewfall"}, "parameter": "shelter_ward_ms",
		"fixed": 1200, "unit": "ms", "limit": 1,
		"description": "Dewfall grants a one-charge native Ward for %s to each living ally it touches, including you at its origin. Once per recipient per cast.",
	},
	"echoing_growth": {
		"title": "Echoing Growth", "scope": "class", "policy": "unique",
		"trigger": "Native Spore Nova hits inside the owner’s active Cultivate Bloom", "consumer": ["res://affinity_cards.gd", "bloom_echo"],
		"requires": {"class": "weaver", "mode": "nova", "skill": "Spore Nova", "focus": "bloomcaller", "q_field": "growth"},
		"parameter": "bloom_echo_hp", "fixed": 10, "unit": "hp", "limit": 1,
		"description": "When Spore Nova damages an enemy inside your active Cultivate Bloom, the bloom pulses once for %s secondary damage to eligible enemies in its field.",
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


static func amount_text(definition: Dictionary, value: int) -> String:
	if definition.unit == "hp":
		return "%d HP" % value
	return "%d ms" % value if value < 1000 else "%s s" % str(value / 1000.0)
