extends RefCounted
const Conditions = preload("res://player_hit_conditions.gd")

const SHARED_STATUS_VERSION := 2
const ID := "modern-gameplay-1"
const MISMATCH := "Combat ruleset mismatch. Host and guest require the same modern gameplay version and definitions."
const Cards = preload("res://affinity_card_catalog.gd")
const Frost = preload("res://frost_balance.gd")
const Fire = preload("res://fire_combat.gd")
const Water = preload("res://water_combat.gd")
const Vital = preload("res://vital_combat.gd")
const Thorn = preload("res://thorn_affinity.gd")
const Wood = preload("res://wood_affinity.gd")
const Storm = preload("res://storm_affinity.gd")
const Spirit = preload("res://spirit_affinity.gd")
const Void = preload("res://void_affinity.gd")
const FAMILIES := {"frost": Frost, "fire": Fire, "water": Water, "vital": Vital, "thorn": Thorn, "wood": Wood, "storm": Storm, "spirit": Spirit, "void": Void}
const Plants = preload("res://plant_affinities.gd")
const Catalyst = preload("res://catalyst_adapters.gd")
const Classes = preload("res://class_catalog.gd")
const ConnectedWarden = preload("res://warden_connected_tree.gd")
const Parts = preload("res://weapon_parts.gd")
const Delivery = preload("res://core_skill_rules.gd")

const Grafts = preload("res://native_grafts.gd")
const Improvements = preload("res://expedition_grafts.gd")
const FORMS := {"frost":"brittle_strikes", "fire":"burning_strikes", "water":"drenching_strikes",
	"vital":"vital_strikes", "thorn":"barbed_strikes", "wood":"splintering_strikes",
	"storm":"arcing_strikes", "spirit":"flowing_strikes", "void":"drawing_strikes"}


# All peers must agree on modern gameplay definitions and behavior version.
static var definition_signature := JSON.stringify([
	SHARED_STATUS_VERSION, Plants.BY_SPECIES, Plants.CORE_SKILL_BY_PRIMARY, Plants.SUPPORTING_ONLY, Conditions.rules_contract(),
	Catalyst.KITS, Catalyst.FOCUS_Q, Catalyst.ADAPTERS, Catalyst.RESPONSES, Catalyst.CONFLICTS,
	Classes.DEFINITIONS, Classes.Warden.FOCUSES, Classes.Subclasses.FOCUSES, ConnectedWarden.VERSION_DATA, Classes.Weaver.VERSION_DATA, Classes.Ranger.VERSION_DATA, Classes.Reaper.VERSION_DATA, Classes.Oracle.VERSION_DATA,
	Parts.MONSTER_DEFINITIONS, Delivery.WEAPON_DELIVERY, Grafts.PROC_KEYS, Grafts.TIMING, Grafts.DEATH_CHARGE_CAP, Grafts.VERSION_DATA, Improvements.PLAYTEST, Improvements.REINFORCEMENTS, Improvements.ADAPTATIONS, FORMS, Cards.DEFINITIONS, Cards.PLAYTEST, Frost.VERSION_DATA, Fire.VERSION_DATA, Water.VERSION_DATA, Vital.VERSION_DATA, Thorn.VERSION_DATA, Wood.VERSION_DATA, Storm.VERSION_DATA, Spirit.VERSION_DATA, Void.VERSION_DATA,
]).sha256_text()


# Sole gameplay contract. Terrain and save isolation are selected independently.
static func network_identity(_world: Node) -> String:
	return ID + "/" + definition_signature
