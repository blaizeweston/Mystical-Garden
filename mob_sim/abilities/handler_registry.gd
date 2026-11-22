extends RefCounted
## Maps each handler name used in mob_sim/data/abilities.json to the class that implements it.
## tests/mob_handler_checks.gd proves this list and DefinitionLoader.HANDLERS name the same handlers.

const Handler = preload("res://mob_sim/abilities/ability_handler.gd")

const SCRIPTS := {
	"antiphon": preload("res://mob_sim/abilities/anchored_rite.gd"),
	"echo_toll": preload("res://mob_sim/abilities/anchored_rite.gd"),
	"brood_hatch": preload("res://mob_sim/abilities/brood_hatch.gd"),
	"scattered_hatch": preload("res://mob_sim/abilities/brood_hatch.gd"),
	"canopy_shift": preload("res://mob_sim/abilities/canopy_shift.gd"),
	"choir_pulse": preload("res://mob_sim/abilities/choir_pulse.gd"),
	"corpse_tether": preload("res://mob_sim/abilities/corpse_tether.gd"),
	"cover_first": preload("res://mob_sim/abilities/cover_first.gd"),
	"cutoff_aim": preload("res://mob_sim/abilities/aim_adjust.gd"),
	"denied_aim": preload("res://mob_sim/abilities/aim_adjust.gd"),
	"side_anchor": preload("res://mob_sim/abilities/aim_adjust.gd"),
	"learned_approach": preload("res://mob_sim/abilities/learned_approach.gd"),
	"shepherd_command": preload("res://mob_sim/abilities/shepherd_command.gd"),
	"relay_order": preload("res://mob_sim/abilities/shepherd_command.gd"),
	"side_approach": preload("res://mob_sim/abilities/side_approach.gd"),
	"boss_plan": preload("res://mob_sim/abilities/host_behaviour.gd"),
	"flank_route": preload("res://mob_sim/abilities/host_behaviour.gd"),
	"glass_feint": preload("res://mob_sim/abilities/host_behaviour.gd"),
	"planted_canopy": preload("res://mob_sim/abilities/host_behaviour.gd"),
	"seam_route": preload("res://mob_sim/abilities/host_behaviour.gd"),
	"shelter": preload("res://mob_sim/abilities/host_behaviour.gd"),
	"trophy_grab": preload("res://mob_sim/abilities/host_behaviour.gd"),
}

var _instances := {}


## The handler for a compiled ability row, or null when the row has none.
func for_row(tables, row: int) -> Handler:
	if row < 0 or tables.row_handler[row] < 0:
		return null
	var name: String = tables.handler_names[tables.row_handler[row]]
	if not _instances.has(name):
		_instances[name] = SCRIPTS[name].new() if SCRIPTS.has(name) else null
	return _instances[name]
