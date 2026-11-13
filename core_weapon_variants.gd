extends RefCounted

# All forms use the base skill unless the Core has a positional variant.
const PROFILES := {
	"phantom_step": {
		"melee": {"variant_name": "Closing Step", "movement": "approach",
			"description": "Rush to the aimed spot along clear ground.",
			"trigger_description": "Roots enemies along the last stretch of the dash."},
		"ranged": {"variant_name": "Fading Step", "movement": "retreat", "retreat_distance": 1.7,
			"description": "Deliver a seed to the aimed spot and step back as it lands.",
			"trigger_description": "Roots enemies in a strip across the seed landing. Cover can shorten the backstep."},
	},
	"gravity_well": {
		"melee": {"variant_name": "Draw In", "targeting": "self",
			"description": "Open a well at your feet."},
		"ranged": {"variant_name": "Sinkhole"},
	},
	"ironbark": {
		"melee": {"variant_name": "Brace", "targeting": "self",
			"description": "Raise a warding line across your position."},
		"ranged": {"variant_name": "Shelter"},
	},
	"hush": {
		"melee": {"variant_name": "Quiet Fan", "targeting": "self",
			"description": "Cast a short fan of silence in front of you."},
		"ranged": {"variant_name": "Silencing Seed"},
	},
	"riptide": {
		"melee": {"variant_name": "Draw Tide", "opening_displace": -1.3,
			"trigger_description": "The outgoing wave pulls idle enemies toward you. The returning wave heals allies it crosses."},
		"ranged": {"variant_name": "Breakwater"},
	},
	"dream_lure": {
		"melee": {"variant_name": "Leave a Decoy", "targeting": "self",
			"description": "Leave a decoy at your feet, then reposition."},
		"ranged": {"variant_name": "Send a Decoy"},
	},
}


static func apply(skill: Dictionary) -> void:
	var pair: Dictionary = PROFILES.get(skill.id, {})
	if pair.is_empty():
		return
	var style := "melee" if skill.delivery == "ground" else "ranged"
	var variant: Dictionary = pair[style]
	skill.merge(variant, true)
	if skill.get("targeting") == "self":
		skill.range = 0.0
	if skill.has("opening_displace"):
		skill.phases = skill.phases.duplicate(true)
		skill.phases[0].enemy.displace = skill.opening_displace
		skill.erase("opening_displace")


static func travel(field: RefCounted, origin: Vector3, center: Vector3, forward: Vector3, skill: Dictionary) -> Vector3:
	match skill.get("movement", ""):
		"approach":
			return field.dash(origin, origin.move_toward(center, float(skill.range)))
		"retreat":
			return field.dash(origin, origin - forward * float(skill.retreat_distance))
	return origin
