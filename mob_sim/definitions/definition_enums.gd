extends RefCounted
## Closed vocabularies for enemy definitions. Data files use the lowercase names.
## The compiler turns every name into its integer so the tick never compares strings.

enum Slot { BASIC, SIGNATURE, COUNTER, SPECIAL }
enum Delivery { MELEE, AIMED, LEAP, RITE, SUMMON, GRAB, PULL }
enum Target { ENEMY, ALLY, CORPSE, DROP, SELF }
enum Sight { NONE, CLEAR, COMBAT }
enum Shape { CIRCLE, SECTOR, LINE, BENT_LINE, SPOTS, TRAIL }
enum Anchor { TARGET, SELF, LANDING }
enum Effect { DAMAGE, ROOT, HAZARD, HASTE_ALLIES, SUMMON, PULL, REPEAT, HEAL, COMMAND, STEAL, DECOY, GUARD }
enum Hazard { NONE, WEB, SPORES, EMBER, AFTERSHOCK }
enum Evidence { NONE, RANGED, LATE, CHOKE, BURST, KITE, CAST_DENIAL, ROUTE_DENIAL, SHELTER_BREAK, AREA_PRESSURE }
enum Layer { GROUND, AIR }
enum Movement { VAULT, DODGE }

const SLOTS := 4
const NO_ABILITY := -1

## Name tables in enum order. Index i holds the data-file name of value i.
const SLOT_NAMES := ["basic", "signature", "counter", "special"]
const DELIVERY_NAMES := ["melee", "aimed", "leap", "rite", "summon", "grab", "pull"]
const TARGET_NAMES := ["enemy", "ally", "corpse", "drop", "self"]
const SIGHT_NAMES := ["none", "clear", "combat"]
const SHAPE_NAMES := ["circle", "sector", "line", "bent_line", "spots", "trail"]
const ANCHOR_NAMES := ["target", "self", "landing"]
const EFFECT_NAMES := ["damage", "root", "hazard", "haste_allies", "summon", "pull", "repeat", "heal", "command", "steal", "decoy", "guard"]
const HAZARD_NAMES := ["none", "web", "spores", "ember", "aftershock"]
const EVIDENCE_NAMES := ["none", "ranged", "late", "choke", "burst", "kite", "cast_denial", "route_denial", "shelter_break", "area_pressure"]
const LAYER_NAMES := ["ground", "air"]
const MOVEMENT_NAMES := ["vault", "dodge"]


## Returns the enum value for a data-file name, or -1 when the name is unknown.
static func value_of(names: Array, name: String) -> int:
	return names.find(name)
