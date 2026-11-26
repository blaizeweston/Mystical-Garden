extends RefCounted
## Local display preferences. Artistic baselines stay with the effects that own them.
const SurfaceArt = preload("res://assets/terrain_m02/wilds_surface_art.gd")
const Contacts = preload("res://contact_particles.gd")
const LEVELS := {
	"Low": {"shadows":0, "air":0.0, "mist":0.35},
	"Medium": {"shadows":1, "air":0.55, "mist":0.7},
	"High": {"shadows":2, "air":1.0, "mist":1.0},
	"Ultra": {"shadows":2, "air":1.4, "mist":1.25},
}
const COMFORT := {"flash":1.0, "fragments":1.0, "spectral":1.0, "damage_numbers":true, "captions":true, "reduced_motion":false}

static func normalize(raw: Variant) -> Dictionary:
	var values: Dictionary = raw if raw is Dictionary else {}
	var level := str(values.get("level","High"))
	if not LEVELS.has(level) and level != "Custom": level = "High"
	var quality: Dictionary = LEVELS.get(level, LEVELS.High).duplicate()
	if level == "Custom":
		if values.get("shadows") is int: quality.shadows = clampi(values.shadows, 0, 2)
		for key in ["air","mist"]:
			quality[key] = bounded(values, key, 1.0, 0.0, 1.5)
	quality.level = level
	for key in ["flash","fragments","spectral"]:
		var minimum := 0.0 if key == "flash" else 0.4
		quality[key] = bounded(values, key, COMFORT[key], minimum, 1.0)
	for key in ["damage_numbers","captions","reduced_motion"]:
		quality[key] = values[key] if values.get(key) is bool else COMFORT[key]
	return quality

static func bounded(values: Dictionary, key: String, fallback: float, low: float, high: float) -> float:
	var value: Variant = values.get(key)
	if (value is float or value is int) and is_finite(float(value)):
		return clampf(float(value), low, high)
	return fallback

static func wilds(art: Dictionary, prefs: Dictionary) -> Dictionary:
	var result := art.duplicate()
	var motion := 0.2 if prefs.reduced_motion else 1.0
	for pair in [["wilds.sway",motion],["wilds.water_motion",motion],["wilds.motes",0.0 if prefs.reduced_motion else prefs.air],["wilds.mist",prefs.mist]]:
		var id: String = pair[0]
		var factor: float = pair[1]
		if not is_equal_approx(factor,1.0):
			var spec: Array = SurfaceArt.CONTROLS[id]
			result[id] = clampf(art.get(id,spec[0])*factor, spec[1], spec[2])
	return result

static func contact(art: Dictionary, family: String, prefs: Dictionary) -> Dictionary:
	if prefs.flash == 1.0 and prefs.fragments == 1.0: return art
	var result := art.duplicate()
	var flash := family + ".flash"
	var count := family + ".count"
	result[flash] = float(art.get(flash,Contacts.DEFAULTS[flash])) * float(prefs.flash)
	result[count] = maxi(1, roundi(float(art.get(count,Contacts.DEFAULTS[count])) * float(prefs.fragments)))
	return result
