extends RefCounted

const ID := "plant-affinity-cr04a-water"
const FLAG := "--combat-affinities"
const META := &"combat_affinity_ruleset"
const PLAYER_KEY := "combat_ruleset"
const EMPTY_CARDS := "No compatible affinity cards in this development build. You can continue at the Gate."
const MISMATCH := "Combat ruleset mismatch. Host and guest must launch with the same combat mode and definitions."
const COMPATIBLE_CARDS := {}
const Frost = preload("res://frost_balance.gd")
const Fire = preload("res://fire_combat.gd")
const Water = preload("res://water_combat.gd")
const FAMILIES := {"frost": Frost, "fire": Fire, "water": Water}
const Experiment = preload("res://assets/terrain_m02/experimental/experiment_mode.gd")
const Playtest = preload("res://playtest_storage.gd")
const Plants = preload("res://plant_affinities.gd")
const Catalyst = preload("res://catalyst_adapters.gd")
const Classes = preload("res://class_catalog.gd")
const Parts = preload("res://weapon_parts.gd")
const Delivery = preload("res://core_skill_rules.gd")

# Native numerical graft modifiers that already have native weapon or class consumers.
# Graft procs and legacy card behavior need their own CR05 compatibility review.
const NATIVE_GRAFT_STATS := [
	"reach", "damage", "cooldown", "recovery", "pull", "knockback", "stagger",
	"windup_damage", "targets", "heal_on_kill", "max_health", "skill_cooldown",
]
const FORMS := {"frost":"brittle_strikes", "fire":"burning_strikes", "water":"drenching_strikes",
	"vital":"vital_strikes", "thorn":"barbed_strikes", "wood":"splintering_strikes",
	"storm":"arcing_strikes", "spirit":"flowing_strikes", "void":"drawing_strikes"}


# This signature is exchanged only for the development ruleset. Bump the
# ruleset ID when authoritative behavior changes, even with identical data.
static var definition_signature := JSON.stringify([
	Plants.BY_SPECIES, Plants.CORE_SKILL_BY_PRIMARY, Plants.SUPPORTING_ONLY,
	Catalyst.KITS, Catalyst.FOCUS_Q, Catalyst.ADAPTERS, Catalyst.RESPONSES, Catalyst.CONFLICTS,
	Classes.DEFINITIONS, Classes.Warden.FOCUSES, Classes.Subclasses.FOCUSES,
	Parts.MONSTER_DEFINITIONS, Delivery.WEAPON_DELIVERY, NATIVE_GRAFT_STATS, FORMS, COMPATIBLE_CARDS, Frost.VERSION_DATA, Fire.VERSION_DATA, Water.VERSION_DATA,
]).sha256_text()


static func requested() -> bool:
	return OS.has_feature("editor") and not Playtest.retail() and FLAG in OS.get_cmdline_user_args()


static func verified() -> bool:
	return requested() and Experiment.verified()


static func active(world: Node) -> bool:
	return world.get_meta(META, "") == ID


static func network_identity(world: Node) -> String:
	return ID + "/" + definition_signature if active(world) else ""


static func uses_affinities(player: Dictionary) -> bool:
	return player.get(PLAYER_KEY) == ID


static func legacy_ranks(player: Dictionary) -> Dictionary:
	return {} if uses_affinities(player) else player.get("run_upgrades", {})


static func legacy_power(player: Dictionary) -> int:
	return 0 if uses_affinities(player) else int(player.get("power", 0))
