extends RefCounted
## Combat cues describe committed actions. They share the expedition cue voice budget.

const ENEMY_MOVES := {
	"charge":"charge", "pounce":"leap", "vault":"leap", "burrow":"burrow",
	"stomp":"heavy", "swipe":"heavy", "skirmish":"leap", "desperate":"heavy",
	"volley":"ranged", "artillery":"ranged", "snare":"ranged", "lure":"support",
	"brood":"support", "chant":"support", "shepherd":"support", "canopy_shift":"support",
	"root_sweep":"heavy", "orchard_march":"charge", "falling_fruit":"ranged", "root_cage":"heavy",
	"drowned_surge":"charge", "tidal_ring":"heavy", "grasping_pool":"ranged",
	"brood_call":"support", "nest_reshape":"support", "matriarch_lunge":"leap",
	"memory_lance":"ranged", "spore_constellation":"ranged", "remembered_rend":"heavy",
}
const MOVE_VARIANTS := {"antler_hook":"hook", "deep_seam":"burrow", "bent_seam":"burrow"}
const WEAPON_FAMILIES := {
	"blade":"blade", "knives":"blade", "scythe":"blade", "whip":"blade", "spear":"thrust",
	"hammer":"heavy", "bow":"bow", "crossbow":"bow", "fan":"bow", "bell":"chime",
	"censer":"magic", "orb":"magic", "wand":"magic", "staff":"magic", "ring":"magic",
}
const PROC_CUES := {
	"mark_break":"combat_mark", "core_mark_burst":"combat_mark", "shatter":"combat_shatter",
	"suppress":"combat_interrupt", "stopped":"combat_interrupt",
}


static func enemy(attack: Dictionary, release: bool) -> String:
	var family: String = MOVE_VARIANTS.get(attack.get("variant",""), "")
	if family.is_empty():
		var mode: String = attack.get("mode","")
		family = ENEMY_MOVES.get(attack.get("role",""), ENEMY_MOVES.get(mode,""))
	if family.is_empty():
		return ""
	return "enemy_%s_%s" % [family, "release" if release else "windup"]


static func weapon(form: String, contact: bool) -> String:
	return "weapon_%s_%s" % [WEAPON_FAMILIES.get(form,"magic"), "hit" if contact else "release"]


static func presentation(event: Dictionary) -> String:
	match event.kind:
		"impact":
			match event.shape:
				"hit": return weapon(event.get("form","magic"),true)
				"hurt": return "combat_hurt"
				"block": return "combat_block"
		"subclass_release":
			if not str(event.get("label","")).is_empty():
				return "combat_cast"
		"proc":
			return PROC_CUES.get(event.shape,"")
	return ""


static func definitions() -> Dictionary:
	var result := {}
	for family in ["charge","hook","leap","burrow","heavy","ranged","support"]:
		var danger: bool = family in ["charge","hook","burrow"]
		var range_value := 12.5 if danger else 9.5
		result["enemy_"+family+"_windup"] = cue("enemy_"+family+"_windup",5 if danger else 4,-11.5,range_value,180,.65)
		result["enemy_"+family+"_release"] = cue("enemy_"+family+"_release",4 if danger else 3,-13.0,range_value,145,.45)
	for family in ["blade","thrust","heavy","bow","chime","magic"]:
		result["weapon_"+family+"_release"] = cue("weapon_"+family+"_release",1,-18.5,8.0,95,.34)
		result["weapon_"+family+"_hit"] = cue("weapon_"+family+"_hit",2,-15.5,8.5,105,.40)
	result["combat_cast"] = cue("combat_cast",2,-16.0,8.5,120,.40)
	result["combat_block"] = cue("combat_block",3,-13.0,9.0,120,.48)
	result["combat_hurt"] = cue("combat_hurt",3,-12.5,9.0,120,.48)
	result["combat_mark"] = cue("combat_mark",3,-14.5,8.5,130,.48)
	result["combat_shatter"] = cue("combat_shatter",3,-14.0,8.5,130,.48)
	result["combat_interrupt"] = cue("combat_interrupt",3,-14.0,8.5,130,.48)
	return result


static func cue(sample: String, priority: int, gain: float, distance: float, repeat_ms: int, max_age: float) -> Dictionary:
	return {"samples":[sample],"wild":true,"priority":priority,"gain":gain,"range":distance,
		"repeat_ms":repeat_ms,"max_age":max_age}
